"""
Checkpointer & Conversation Memory Manager for ReMarket AI Service (`app.memory.checkpointer`).
Implements:
- LangGraph `MemorySaver` checkpointer management.
- Strict distinction between:
  1. Short-term Conversation Memory (`ConversationSessionRecord` bound to `thread_id`).
  2. Long-term User Memory (`UserLongTermMemoryRecord` bound to `user_id`).
- Authentication isolation: each conversation `thread_id` is bound to its `owner_user_id`
  (established from `VerifiedUserContext`). Users are strictly blocked from reading,
  continuing, or deleting another user's conversation (`SecurityViolationError` / HTTP 403).
- Sliding-window message trimming (`trim_conversation_messages`) to prevent unbounded growth.
"""

from datetime import datetime, timezone
import logging
from typing import Any, Optional

from langchain_core.messages import AnyMessage, SystemMessage
from langgraph.checkpoint.base import BaseCheckpointSaver
from langgraph.checkpoint.memory import MemorySaver
from pydantic import BaseModel, Field

from app.core.config import Settings, get_settings
from app.core.exceptions import ConversationNotFoundError, SecurityViolationError

logger = logging.getLogger("remarket.ai.memory.checkpointer")


class ConversationTurnEntry(BaseModel):
    """Serializable message entry stored in short-term conversation metadata."""

    role: str
    content: str
    timestamp: str = Field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )


class ConversationSessionRecord(BaseModel):
    """
    Short-term conversation memory record tied to a specific `conversation_id` (`thread_id`)
    and isolated by `owner_user_id`.
    """

    conversation_id: str
    owner_user_id: str = "anonymous"
    turns: list[ConversationTurnEntry] = Field(default_factory=list)
    last_matched_products: list[dict[str, Any]] = Field(default_factory=list)
    preferences: dict[str, Any] = Field(default_factory=dict)
    last_intent: Optional[str] = None
    created_at: str = Field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )
    updated_at: str = Field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )


class UserLongTermMemoryRecord(BaseModel):
    """
    Lightweight long-term user memory record (distinct from short-term `thread_id` state).
    Stores non-sensitive shopping preferences across threads for an authenticated user.
    """

    user_id: str
    preferred_categories: list[str] = Field(default_factory=list)
    typical_max_budget: Optional[float] = None
    preferred_location: Optional[str] = None
    updated_at: str = Field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )


def trim_conversation_messages(
    messages: list[AnyMessage],
    max_messages: int = 20,
) -> list[AnyMessage]:
    """
    Trim short-term message history to at most `max_messages` recent messages while
    always preserving the leading `SystemMessage` if present.
    """
    if len(messages) <= max_messages:
        return list(messages)

    if messages and isinstance(messages[0], SystemMessage):
        keep_tail = max(1, max_messages - 1)
        return [messages[0], *messages[-keep_tail:]]

    return list(messages[-max_messages:])


class CheckpointerManager:
    """
    Manages the LangGraph `MemorySaver` checkpointer AND enforces per-user conversation
    ownership isolation, history trimming, inspection, and deletion.
    """

    def __init__(self, settings: Optional[Settings] = None) -> None:
        self._settings = settings or get_settings()
        self._saver: Optional[MemorySaver] = None
        self._sessions: dict[str, ConversationSessionRecord] = {}
        self._long_term_memory: dict[str, UserLongTermMemoryRecord] = {}

    @property
    def backend_type(self) -> str:
        """Return the checkpointer backend identifier (e.g., 'memory')."""
        db_url = self._settings.CHECKPOINTER_DATABASE_URL.strip()
        return db_url.split("://")[0] if "://" in db_url else (db_url or "memory")

    def get_checkpointer(self) -> BaseCheckpointSaver:
        """Return the singleton checkpointer instance."""
        if self._saver is None:
            db_url = self._settings.CHECKPOINTER_DATABASE_URL.strip()
            logger.info(
                "Initializing LangGraph checkpointer (backend=%s)",
                db_url.split("://")[0],
            )
            self._saver = MemorySaver()
        return self._saver

    def verify_or_bind_session(
        self,
        conversation_id: str,
        user_id: Optional[str] = None,
    ) -> ConversationSessionRecord:
        """
        Verify that `user_id` is authorized to access `conversation_id`, or create and bind
        a new `ConversationSessionRecord` if `conversation_id` does not yet exist.
        Raises `SecurityViolationError` (HTTP 403) if another user owns the conversation.
        """
        clean_conv_id = conversation_id.strip()
        resolved_owner = (user_id or "").strip() or "anonymous"

        existing = self._sessions.get(clean_conv_id)
        if existing is not None:
            if existing.owner_user_id != resolved_owner:
                logger.warning(
                    "Blocked unauthorized conversation access conversation_id=%s owner=%s requester=%s",
                    clean_conv_id,
                    existing.owner_user_id,
                    resolved_owner,
                )
                raise SecurityViolationError(
                    "Access denied: You do not have permission to access another user's conversation."
                )
            return existing

        record = ConversationSessionRecord(
            conversation_id=clean_conv_id,
            owner_user_id=resolved_owner,
        )
        self._sessions[clean_conv_id] = record
        return record

    def update_session(
        self,
        conversation_id: str,
        *,
        user_id: Optional[str] = None,
        user_message: Optional[str] = None,
        assistant_message: Optional[str] = None,
        matched_products: Optional[list[dict[str, Any]]] = None,
        preferences: Optional[dict[str, Any]] = None,
        intent: Optional[str] = None,
    ) -> ConversationSessionRecord:
        """
        Update short-term conversation state and enforce sliding-window history limits.
        Also updates lightweight long-term user preferences if `user_id` is authenticated.
        """
        record = self.verify_or_bind_session(conversation_id, user_id)
        max_turns = max(4, self._settings.CONVERSATION_MAX_HISTORY_MESSAGES)

        if user_message:
            record.turns.append(
                ConversationTurnEntry(role="user", content=user_message)
            )
        if assistant_message:
            record.turns.append(
                ConversationTurnEntry(role="assistant", content=assistant_message)
            )
        if len(record.turns) > max_turns:
            record.turns = record.turns[-max_turns:]

        if matched_products is not None:
            record.last_matched_products = list(matched_products)

        if preferences:
            for k, v in preferences.items():
                if v is not None and v != "":
                    record.preferences[k] = v

        if intent:
            record.last_intent = intent

        record.updated_at = datetime.now(timezone.utc).isoformat()

        # Update lightweight long-term user memory if authenticated
        if user_id and user_id.strip() and preferences:
            lt_mem = self._long_term_memory.setdefault(
                user_id.strip(),
                UserLongTermMemoryRecord(user_id=user_id.strip()),
            )
            cat = preferences.get("category")
            if isinstance(cat, str) and cat and cat not in lt_mem.preferred_categories:
                lt_mem.preferred_categories.append(cat)
            budget = preferences.get("max_budget")
            if isinstance(budget, (int, float)) and budget > 0:
                lt_mem.typical_max_budget = float(budget)
            loc = preferences.get("location")
            if isinstance(loc, str) and loc:
                lt_mem.preferred_location = loc
            lt_mem.updated_at = record.updated_at

        return record

    def get_session(
        self,
        conversation_id: str,
        user_id: Optional[str] = None,
    ) -> ConversationSessionRecord:
        """
        Retrieve an existing `ConversationSessionRecord` after verifying ownership.
        Raises `ConversationNotFoundError` (404) if missing or `SecurityViolationError` (403) if owned by another user.
        """
        clean_conv_id = conversation_id.strip()
        existing = self._sessions.get(clean_conv_id)
        if existing is None:
            raise ConversationNotFoundError(
                f"Conversation '{clean_conv_id}' was not found."
            )
        resolved_requester = (user_id or "").strip() or "anonymous"
        if existing.owner_user_id != resolved_requester:
            raise SecurityViolationError(
                "Access denied: You do not have permission to view another user's conversation."
            )
        return existing

    def delete_session(
        self,
        conversation_id: str,
        user_id: Optional[str] = None,
    ) -> bool:
        """
        Delete an existing `ConversationSessionRecord` and purge its LangGraph checkpoint
        after verifying ownership.
        """
        session = self.get_session(conversation_id, user_id=user_id)
        del self._sessions[session.conversation_id]

        # Also purge from underlying MemorySaver storage if present
        if self._saver is not None and hasattr(self._saver, "storage"):
            storage_obj = getattr(self._saver, "storage", None)
            if isinstance(storage_obj, dict):
                storage_obj.pop(session.conversation_id, None)

        logger.info(
            "Deleted conversation session conversation_id=%s owner=%s",
            session.conversation_id,
            session.owner_user_id,
        )
        return True

    def get_long_term_user_memory(
        self, user_id: str
    ) -> Optional[UserLongTermMemoryRecord]:
        """Retrieve long-term user memory for an authenticated user if available."""
        return self._long_term_memory.get(user_id.strip())

    def reset(self) -> None:
        """Reset checkpointer and all in-memory sessions."""
        self._saver = None
        self._sessions.clear()
        self._long_term_memory.clear()


_checkpointer_manager: Optional[CheckpointerManager] = None


def get_checkpointer_manager(
    settings: Optional[Settings] = None,
) -> CheckpointerManager:
    """Return the shared CheckpointerManager singleton."""
    global _checkpointer_manager
    if _checkpointer_manager is None:
        _checkpointer_manager = CheckpointerManager(settings=settings or get_settings())
    return _checkpointer_manager


def reset_checkpointer_manager() -> None:
    """Reset the shared CheckpointerManager singleton."""
    global _checkpointer_manager
    if _checkpointer_manager is not None:
        _checkpointer_manager.reset()
    _checkpointer_manager = None
