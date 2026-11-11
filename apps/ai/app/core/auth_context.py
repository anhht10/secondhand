"""
Verified Authentication Context for ReMarket AI Service.
Enforces the security boundary that the AI Agent / LLM can NEVER self-assign
a user ID, role, or access token. User identity and permissions must always
be authenticated by the NestJS Backend and injected into the request context.
"""

from contextlib import contextmanager
from contextvars import ContextVar, Token
import re
from typing import Any, Iterator, Mapping, Optional

from pydantic import BaseModel, ConfigDict, Field, SecretStr, field_validator

from app.core.exceptions import SecurityViolationError
from app.core.logging import get_request_id

_OBJECT_ID_PATTERN = re.compile(r"^[0-9a-fA-F]{24}$")

# Fields that an LLM tool call is NEVER allowed to inject to spoof identity/permissions
FORBIDDEN_LLM_AUTH_FIELDS = frozenset(
    {
        "current_user_id",
        "acting_user_id",
        "authenticated_user_id",
        "override_user_id",
        "viewer_user_id",
        "auth_token",
        "bearer_token",
        "access_token",
        "jwt_token",
        "service_token",
        "is_admin",
        "role",
        "roles",
        "permissions",
    }
)


class VerifiedUserContext(BaseModel):
    """
    Immutable authentication context established by the HTTP boundary (NestJS -> FastAPI),
    never by LLM-generated tool arguments.
    """

    model_config = ConfigDict(frozen=True, extra="forbid")

    user_id: Optional[str] = Field(
        default=None,
        description="Verified MongoDB ObjectId of the authenticated user, or None for anonymous/guest.",
    )
    bearer_token: Optional[SecretStr] = Field(
        default=None,
        description="Verified Bearer JWT forwarded from NestJS Backend.",
    )
    roles: tuple[str, ...] = Field(
        default=("guest",),
        description="Verified roles assigned by Backend authentication.",
    )
    request_id: Optional[str] = Field(
        default=None,
        description="Correlation X-Request-ID for the current request.",
    )

    @field_validator("user_id")
    @classmethod
    def validate_user_id(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return None
        cleaned = value.strip()
        if not cleaned:
            return None
        if not _OBJECT_ID_PATTERN.match(cleaned):
            raise ValueError("Verified user_id must be a valid 24-character hex MongoDB ObjectId.")
        return cleaned

    @property
    def is_authenticated(self) -> bool:
        """Return True if a verified user_id or bearer_token is present."""
        return bool(self.user_id or self.raw_bearer_token)

    @property
    def raw_bearer_token(self) -> str:
        """Return the raw JWT string without 'Bearer ' prefix, or empty string."""
        if self.bearer_token is None:
            return ""
        raw = self.bearer_token.get_secret_value().strip()
        if raw.lower().startswith("bearer "):
            return raw[7:].strip()
        return raw


_anonymous_context = VerifiedUserContext()
_auth_ctx_var: ContextVar[VerifiedUserContext] = ContextVar(
    "verified_user_context",
    default=_anonymous_context,
)


def get_auth_context() -> VerifiedUserContext:
    """Return the active VerifiedUserContext for the current execution context."""
    return _auth_ctx_var.get()


def set_auth_context(ctx: VerifiedUserContext) -> Token[VerifiedUserContext]:
    """Bind a VerifiedUserContext into contextvars and return the reset token."""
    return _auth_ctx_var.set(ctx)


def reset_auth_context(token: Token[VerifiedUserContext]) -> None:
    """Restore the previous VerifiedUserContext using the provided token."""
    _auth_ctx_var.reset(token)


@contextmanager
def auth_context_scope(ctx: VerifiedUserContext) -> Iterator[VerifiedUserContext]:
    """Context manager that temporarily binds a VerifiedUserContext."""
    token = set_auth_context(ctx)
    try:
        yield ctx
    finally:
        reset_auth_context(token)


def extract_auth_context_from_headers(headers: Mapping[str, str]) -> VerifiedUserContext:
    """
    Construct a `VerifiedUserContext` from incoming HTTP headers sent by NestJS Backend.
    Recognizes `Authorization: Bearer <jwt>` and `X-Authenticated-User-Id` / `X-User-Id`.
    """
    normalized = {k.lower(): v for k, v in headers.items() if isinstance(v, str)}
    auth_header = normalized.get("authorization", "").strip()
    token_secret: Optional[SecretStr] = None
    if auth_header.lower().startswith("bearer "):
        raw_jwt = auth_header[7:].strip()
        if raw_jwt:
            token_secret = SecretStr(raw_jwt)

    raw_user_id = (
        normalized.get("x-authenticated-user-id")
        or normalized.get("x-user-id")
        or ""
    ).strip()
    valid_user_id: Optional[str] = (
        raw_user_id if _OBJECT_ID_PATTERN.match(raw_user_id) else None
    )

    roles: tuple[str, ...] = ("user",) if (valid_user_id or token_secret) else ("guest",)
    req_id = normalized.get("x-request-id") or get_request_id()

    return VerifiedUserContext(
        user_id=valid_user_id,
        bearer_token=token_secret,
        roles=roles,
        request_id=req_id,
    )


def assert_no_spoofed_auth_override(payload: Mapping[str, Any]) -> None:
    """
    Verify that an untrusted tool input dictionary does not contain any forbidden
    authentication or privilege override fields. Raises SecurityViolationError if found.
    """
    for key in payload.keys():
        if str(key).strip().lower() in FORBIDDEN_LLM_AUTH_FIELDS:
            raise SecurityViolationError(
                f"Security policy violation: Tool input cannot specify authentication field '{key}'. "
                "User identity and permissions are controlled exclusively by NestJS Backend."
            )
