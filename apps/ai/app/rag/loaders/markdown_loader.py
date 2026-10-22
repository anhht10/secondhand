"""
Markdown Document Loader (`app.rag.loaders.markdown_loader`).
Supports `.md` and `.markdown` files with optional YAML frontmatter extraction,
heading-based title extraction, text cleaning, and prompt-injection sanitization.
"""

from datetime import datetime, timezone
from pathlib import Path
import re
from typing import Optional

from app.rag.loaders.cleaner import (
    compute_content_hash,
    infer_knowledge_category,
    sanitize_and_clean_text,
)
from app.rag.schemas import KnowledgeCategory, RAGDocumentMetadata, RawLoadedDocument

_FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)
_H1_HEADING_RE = re.compile(r"^#\s+(.+)$", re.MULTILINE)


def _parse_simple_frontmatter(raw_text: str) -> tuple[dict[str, str], str]:
    """Extract simple `key: value` YAML frontmatter if present at the top of a Markdown file."""
    match = _FRONTMATTER_RE.match(raw_text)
    if not match:
        return {}, raw_text

    frontmatter_block = match.group(1)
    remaining_body = raw_text[match.end() :]
    parsed: dict[str, str] = {}
    for line in frontmatter_block.splitlines():
        if ":" in line:
            key, val = line.split(":", 1)
            clean_key = key.strip().lower()
            clean_val = val.strip().strip("\"'")
            if clean_key and clean_val:
                parsed[clean_key] = clean_val
    return parsed, remaining_body


def _slugify_id(value: str) -> str:
    slug = re.sub(r"[^a-zA-Z0-9-]+", "-", value.strip().lower()).strip("-")
    return slug or "doc"


class MarkdownDocumentLoader:
    """Loads Markdown documents from disk or raw text into `RawLoadedDocument`."""

    def load_file(
        self,
        file_path: str | Path,
        *,
        category: Optional[str | KnowledgeCategory] = None,
        document_id: Optional[str] = None,
        source_override: Optional[str] = None,
    ) -> RawLoadedDocument:
        path_obj = Path(file_path)
        if not path_obj.exists() or not path_obj.is_file():
            raise FileNotFoundError(f"Markdown file not found: {path_obj}")

        raw_text = path_obj.read_text(encoding="utf-8")
        stat_mtime = datetime.fromtimestamp(
            path_obj.stat().st_mtime, tz=timezone.utc
        ).isoformat()

        return self.load_from_string(
            raw_text,
            source=source_override or path_obj.name,
            default_doc_id=document_id or _slugify_id(path_obj.stem),
            category=category,
            default_created_at=stat_mtime,
        )

    def load_from_string(
        self,
        raw_text: str,
        *,
        source: str,
        default_doc_id: Optional[str] = None,
        category: Optional[str | KnowledgeCategory] = None,
        default_created_at: Optional[str] = None,
    ) -> RawLoadedDocument:
        frontmatter, body = _parse_simple_frontmatter(raw_text)
        cleaned_body, injection_count = sanitize_and_clean_text(body)

        # Resolve title from frontmatter or first H1 heading
        title = frontmatter.get("title", "")
        if not title:
            h1_match = _H1_HEADING_RE.search(cleaned_body)
            if h1_match:
                title = h1_match.group(1).strip()
            else:
                title = Path(source).stem.replace("-", " ").replace("_", " ").title()

        resolved_doc_id = (
            frontmatter.get("document_id")
            or frontmatter.get("id")
            or default_doc_id
            or _slugify_id(Path(source).stem)
        )
        explicit_cat = (
            category.value
            if isinstance(category, KnowledgeCategory)
            else (category or frontmatter.get("category"))
        )
        resolved_category = infer_knowledge_category(
            explicit_category=explicit_cat,
            filename_or_source=source,
            title=title,
        )
        created_at = (
            frontmatter.get("created_at")
            or default_created_at
            or datetime.now(timezone.utc).isoformat()
        )
        content_hash = compute_content_hash(cleaned_body)

        metadata = RAGDocumentMetadata(
            document_id=resolved_doc_id,
            source=source,
            category=resolved_category,
            title=title,
            created_at=created_at,
            content_hash=content_hash,
            file_type="markdown",
            sanitized_injection_patterns=injection_count,
        )
        return RawLoadedDocument(content=cleaned_body, metadata=metadata)
