"""
Structured Logging and Request ID Context Management for ReMarket AI Service.
Ensures API keys and sensitive tokens are never written to logs.
"""

from contextvars import ContextVar
from datetime import datetime, timezone
import json
import logging
import re
import sys
from typing import Any, Iterable, Optional, Union

from app.core.config import Settings

request_id_ctx_var: ContextVar[str] = ContextVar("request_id", default="-")

_QUERY_KEY_PATTERN = re.compile(r"([?&](?:key|api_key|token)=)([^&\s]+)", re.IGNORECASE)


def get_request_id() -> str:
    """Retrieve the current request ID from contextvars."""
    return request_id_ctx_var.get()


def set_request_id(request_id: str) -> None:
    """Set the current request ID in contextvars."""
    request_id_ctx_var.set(request_id)


class SecretRedactionFilter(logging.Filter):
    """Filter that scrubs configured secrets and API keys from log records."""

    def __init__(
        self,
        secrets: Optional[Iterable[str]] = None,
        secrets_to_redact: Optional[Iterable[str]] = None,
    ) -> None:
        super().__init__()
        combined = list(secrets or []) + list(secrets_to_redact or [])
        self._secrets = [
            s.strip()
            for s in combined
            if s and len(s.strip()) >= 6
        ]

    def _scrub(self, text: str) -> str:
        scrubbed = _QUERY_KEY_PATTERN.sub(r"\1***REDACTED***", text)
        for secret in self._secrets:
            if secret in scrubbed:
                scrubbed = scrubbed.replace(secret, "***REDACTED***")
        return scrubbed

    def filter(self, record: logging.LogRecord) -> bool:
        setattr(record, "request_id", get_request_id())
        if isinstance(record.msg, str):
            record.msg = self._scrub(record.msg)
        if record.args:
            if isinstance(record.args, tuple):
                record.args = tuple(
                    self._scrub(arg) if isinstance(arg, str) else arg
                    for arg in record.args
                )
            elif isinstance(record.args, dict):
                record.args = {
                    k: (self._scrub(v) if isinstance(v, str) else v)
                    for k, v in record.args.items()
                }
        return True


class StructuredJsonFormatter(logging.Formatter):
    """Outputs structured JSON log lines with timestamp, level, logger, request_id, and message."""

    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "request_id": getattr(record, "request_id", get_request_id()),
            "message": record.getMessage(),
        }
        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)
        return json.dumps(payload, ensure_ascii=False)


def configure_logging(
    settings_or_level: Union[Settings, str] = "INFO",
    secrets_to_redact: Optional[Iterable[str]] = None,
) -> None:
    """Configure root and application loggers with structured output and secret redaction."""
    if isinstance(settings_or_level, Settings):
        log_level = settings_or_level.LOG_LEVEL
        secrets = [
            settings_or_level.gemini_api_key_value,
            settings_or_level.backend_service_token_value,
        ]
    else:
        log_level = str(settings_or_level)
        secrets = list(secrets_to_redact or [])

    root_logger = logging.getLogger()
    root_logger.setLevel(getattr(logging, log_level.upper(), logging.INFO))

    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(StructuredJsonFormatter())
    handler.addFilter(SecretRedactionFilter(secrets=secrets))

    root_logger.handlers.clear()
    root_logger.addHandler(handler)
