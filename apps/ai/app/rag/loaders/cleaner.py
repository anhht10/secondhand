"""
Text Cleaning, Metadata Inference, and Prompt-Injection Sanitization (`app.rag.loaders.cleaner`).
Ensures untrusted document content cannot inject system-level overrides into Agent prompts.
"""

import hashlib
import logging
import re
from typing import Optional

from app.rag.schemas import KnowledgeCategory

logger = logging.getLogger("remarket.ai.rag.cleaner")

# Adversarial prompt-injection patterns that attempt to hijack LLM system instructions
_INJECTION_PATTERNS: list[re.Pattern[str]] = [
    re.compile(
        r"(?i)\b(?:ignore|disregard|forget|bypass|override)\s+(?:all\s+)?(?:previous|prior|above|system|developer)\s+(?:instructions?|prompts?|rules?|directives?)[^\n.]*[.\n]?"
    ),
    re.compile(
        r"(?i)\byou\s+are\s+now\s+(?:in\s+developer\s+mode|an?\s+unrestricted|dan\b|free\s+from\s+rules)[^\n.]*[.\n]?"
    ),
    re.compile(r"(?i)<\s*/?\s*(?:system|instruction|developer_prompt|system_prompt)\s*>"),
    re.compile(r"(?i)\[\s*/?\s*INST\s*\]|<<\s*/?\s*SYS\s*>>"),
    re.compile(
        r"(?i)\b(?:system\s+override|new\s+system\s+prompt|act\s+as\s+system\s+administrator)\s*:[^\n]*"
    ),
]

_CONTROL_CHARS_RE = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]")
_MULTI_NEWLINE_RE = re.compile(r"\n{3,}")
_TRAILING_SPACE_RE = re.compile(r"[ \t]+\n")


def sanitize_and_clean_text(raw_text: str) -> tuple[str, int]:
    """
    Clean raw document text and neutralize adversarial prompt-injection directives.
    Returns `(cleaned_text, neutralized_injection_count)`.
    """
    if not raw_text:
        return "", 0

    text = raw_text.replace("\r\n", "\n").replace("\r", "\n")
    text = _CONTROL_CHARS_RE.sub("", text)

    injection_count = 0
    for pattern in _INJECTION_PATTERNS:
        matches = pattern.findall(text)
        if matches:
            injection_count += len(matches)
            text = pattern.sub("[REMOVED_UNTRUSTED_DIRECTIVE]", text)

    if injection_count > 0:
        logger.warning(
            "Sanitized %d potential prompt-injection pattern(s) from RAG document text.",
            injection_count,
        )

    text = _TRAILING_SPACE_RE.sub("\n", text)
    text = _MULTI_NEWLINE_RE.sub("\n\n", text)
    return text.strip(), injection_count


def compute_content_hash(cleaned_text: str) -> str:
    """Compute deterministic SHA-256 hex digest of cleaned document text."""
    return hashlib.sha256(cleaned_text.encode("utf-8")).hexdigest()


def infer_knowledge_category(
    *,
    explicit_category: Optional[str] = None,
    filename_or_source: str = "",
    title: str = "",
) -> KnowledgeCategory:
    """
    Resolve or infer the `KnowledgeCategory` from an explicit value, filename, or title.
    """
    if explicit_category:
        cleaned = explicit_category.strip().lower()
        for member in KnowledgeCategory:
            if member.value == cleaned:
                return member

    combined = f"{filename_or_source} {title}".lower()
    if any(k in combined for k in ("policy", "chinh-sach", "chính sách", "quy-dinh", "quy định")):
        return KnowledgeCategory.POLICY
    if any(k in combined for k in ("safety", "an-toan", "an toàn", "lua-dao", "lừa đảo")):
        return KnowledgeCategory.SAFETY_GUIDE
    if any(k in combined for k in ("inspection", "kiem-tra", "kiểm tra", "checklist", "test")):
        return KnowledgeCategory.INSPECTION_GUIDE
    if any(k in combined for k in ("condition", "tinh-trang", "tình trạng", "phan-loai", "grading")):
        return KnowledgeCategory.CONDITION_GRADING
    if any(k in combined for k in ("student", "sinh-vien", "sinh viên", "giao-dich", "ký túc xá")):
        return KnowledgeCategory.STUDENT_TRANSACTION
    if any(k in combined for k in ("platform", "huong-dan-su-dung", "sử dụng nền tảng", "usage")):
        return KnowledgeCategory.PLATFORM_GUIDE

    return KnowledgeCategory.GENERAL
