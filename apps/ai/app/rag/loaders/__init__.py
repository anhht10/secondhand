"""
Document Loaders Package (`app.rag.loaders`).
Provides unified loading for Markdown (`.md`, `.markdown`) and PDF (`.pdf`) documents.
"""

from pathlib import Path
from typing import Optional

from app.rag.loaders.cleaner import (
    compute_content_hash,
    infer_knowledge_category,
    sanitize_and_clean_text,
)
from app.rag.loaders.markdown_loader import MarkdownDocumentLoader
from app.rag.loaders.pdf_loader import PDFDocumentLoader
from app.rag.schemas import KnowledgeCategory, RawLoadedDocument

SUPPORTED_EXTENSIONS = frozenset({".md", ".markdown", ".pdf"})


def load_document_from_file(
    file_path: str | Path,
    *,
    category: Optional[str | KnowledgeCategory] = None,
    document_id: Optional[str] = None,
    source_override: Optional[str] = None,
) -> RawLoadedDocument:
    """Load a single Markdown or PDF file into a `RawLoadedDocument`."""
    path_obj = Path(file_path)
    ext = path_obj.suffix.lower()
    if ext in (".md", ".markdown"):
        return MarkdownDocumentLoader().load_file(
            path_obj,
            category=category,
            document_id=document_id,
            source_override=source_override,
        )
    if ext == ".pdf":
        return PDFDocumentLoader().load_file(
            path_obj,
            category=category,
            document_id=document_id,
            source_override=source_override,
        )
    raise ValueError(
        f"Unsupported document extension '{ext}' for file '{path_obj.name}'. "
        f"Supported extensions: {sorted(SUPPORTED_EXTENSIONS)}"
    )


def load_documents_from_directory(
    directory_path: str | Path,
    *,
    recursive: bool = True,
) -> list[RawLoadedDocument]:
    """Load all `.md`, `.markdown`, and `.pdf` documents from a directory in deterministic order."""
    dir_obj = Path(directory_path)
    if not dir_obj.exists() or not dir_obj.is_dir():
        raise FileNotFoundError(f"Knowledge base directory not found: {dir_obj}")

    pattern = "**/*" if recursive else "*"
    files = sorted(
        [
            p
            for p in dir_obj.glob(pattern)
            if p.is_file() and p.suffix.lower() in SUPPORTED_EXTENSIONS
        ],
        key=lambda p: p.as_posix(),
    )

    loaded: list[RawLoadedDocument] = []
    for file_path in files:
        rel_source = file_path.relative_to(dir_obj).as_posix()
        doc = load_document_from_file(file_path, source_override=rel_source)
        loaded.append(doc)
    return loaded


__all__ = [
    "SUPPORTED_EXTENSIONS",
    "MarkdownDocumentLoader",
    "PDFDocumentLoader",
    "load_document_from_file",
    "load_documents_from_directory",
    "sanitize_and_clean_text",
    "compute_content_hash",
    "infer_knowledge_category",
]
