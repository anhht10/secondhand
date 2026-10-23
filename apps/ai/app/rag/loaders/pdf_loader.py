"""
PDF Document Loader (`app.rag.loaders.pdf_loader`).
Extracts text from `.pdf` files using `pypdf`, preserves page boundaries via
`## Page N` section markers, cleans text, and neutralizes prompt-injection patterns.
"""

from datetime import datetime, timezone
from io import BytesIO
from pathlib import Path
import re
from typing import Optional

from pypdf import PdfReader

from app.rag.loaders.cleaner import (
    compute_content_hash,
    infer_knowledge_category,
    sanitize_and_clean_text,
)
from app.rag.schemas import KnowledgeCategory, RAGDocumentMetadata, RawLoadedDocument


def _slugify_id(value: str) -> str:
    slug = re.sub(r"[^a-zA-Z0-9-]+", "-", value.strip().lower()).strip("-")
    return slug or "pdf-doc"


class PDFDocumentLoader:
    """Loads PDF documents from disk or bytes into `RawLoadedDocument`."""

    def load_file(
        self,
        file_path: str | Path,
        *,
        category: Optional[str | KnowledgeCategory] = None,
        document_id: Optional[str] = None,
        title: Optional[str] = None,
        source_override: Optional[str] = None,
    ) -> RawLoadedDocument:
        path_obj = Path(file_path)
        if not path_obj.exists() or not path_obj.is_file():
            raise FileNotFoundError(f"PDF file not found: {path_obj}")

        stat_mtime = datetime.fromtimestamp(
            path_obj.stat().st_mtime, tz=timezone.utc
        ).isoformat()
        pdf_bytes = path_obj.read_bytes()

        return self.load_from_bytes(
            pdf_bytes,
            source=source_override or path_obj.name,
            default_doc_id=document_id or _slugify_id(path_obj.stem),
            title=title or path_obj.stem.replace("-", " ").replace("_", " ").title(),
            category=category,
            default_created_at=stat_mtime,
        )

    def load_from_bytes(
        self,
        pdf_bytes: bytes,
        *,
        source: str,
        default_doc_id: Optional[str] = None,
        title: Optional[str] = None,
        category: Optional[str | KnowledgeCategory] = None,
        default_created_at: Optional[str] = None,
    ) -> RawLoadedDocument:
        reader = PdfReader(BytesIO(pdf_bytes))
        page_blocks: list[str] = []

        for idx, page in enumerate(reader.pages, start=1):
            extracted = (page.extract_text() or "").strip()
            if extracted:
                page_blocks.append(f"## Page {idx}\n\n{extracted}")

        raw_combined = "\n\n".join(page_blocks)
        cleaned_text, injection_count = sanitize_and_clean_text(raw_combined)

        resolved_title = title or Path(source).stem.replace("-", " ").replace("_", " ").title()
        if reader.metadata and getattr(reader.metadata, "title", None) and not title:
            meta_title = str(reader.metadata.title).strip()
            if meta_title:
                resolved_title = meta_title

        resolved_doc_id = default_doc_id or _slugify_id(Path(source).stem)
        explicit_cat = (
            category.value if isinstance(category, KnowledgeCategory) else category
        )
        resolved_category = infer_knowledge_category(
            explicit_category=explicit_cat,
            filename_or_source=source,
            title=resolved_title,
        )
        created_at = default_created_at or datetime.now(timezone.utc).isoformat()
        content_hash = compute_content_hash(cleaned_text)

        metadata = RAGDocumentMetadata(
            document_id=resolved_doc_id,
            source=source,
            category=resolved_category,
            title=resolved_title,
            created_at=created_at,
            content_hash=content_hash,
            file_type="pdf",
            sanitized_injection_patterns=injection_count,
        )
        return RawLoadedDocument(content=cleaned_text, metadata=metadata)
