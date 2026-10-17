"""
Request and Response schemas for `POST /ai/test-chat`.
"""

from typing import Optional
from pydantic import BaseModel, Field, field_validator


class TestChatRequest(BaseModel):
    """Input payload for invoking the foundational `START -> llm_node -> END` graph."""

    __test__ = False

    message: str = Field(
        ...,
        min_length=1,
        max_length=4000,
        description="User prompt or message to send through the LangGraph workflow",
    )
    thread_id: Optional[str] = Field(
        default=None,
        max_length=128,
        description="Optional conversation thread ID for multi-turn state persistence via LangGraph checkpointer",
    )
    system_prompt: Optional[str] = Field(
        default=None,
        max_length=2000,
        description="Optional system instruction prepended to a new thread",
    )

    @field_validator("message")
    @classmethod
    def validate_non_blank_message(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("message must not be blank or whitespace-only")
        return cleaned


class TestChatResponse(BaseModel):
    """Output payload returned by `POST /ai/test-chat`."""

    __test__ = False

    reply: str = Field(description="Generated assistant reply from Gemini via LangGraph")
    thread_id: str = Field(description="Resolved thread_id used for LangGraph checkpointer state")
    model: str = Field(description="Gemini model identifier used by the graph node")
    message_count: int = Field(
        ge=1,
        description="Total messages accumulated in this thread state after execution",
    )
    latency_ms: float = Field(
        ge=0.0,
        description="End-to-end graph execution latency in milliseconds",
    )
    request_id: str = Field(description="Correlation request ID")
