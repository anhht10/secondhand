"""
Markdown- and Section-Aware Text Splitter (`app.rag.splitters.text_splitter`).
Splits `RawLoadedDocument` instances into `RAGDocumentChunk` items while preserving
heading context (`section`), character `chunk_size` and `chunk_overlap` bounds,
and complete document attribution metadata.
"""

import re
from typing import Iterable

from app.rag.schemas import RAGChunkMetadata, RAGDocumentChunk, RawLoadedDocument

_HEADING_LINE_RE = re.compile(r"^(#{1,3})\s+(.+)$")


class MarkdownAwareTextSplitter:
    """
    Splits cleaned document text into semantic chunks aligned with Markdown sections
    and paragraph boundaries, enforcing `chunk_size` and `chunk_overlap`.
    """

    def __init__(
        self,
        *,
        chunk_size: int = 800,
        chunk_overlap: int = 120,
    ) -> None:
        if chunk_size < 50:
            raise ValueError("chunk_size must be at least 50 characters.")
        if chunk_overlap < 0 or chunk_overlap >= chunk_size:
            raise ValueError("chunk_overlap must be >= 0 and strictly less than chunk_size.")
        self._chunk_size = chunk_size
        self._chunk_overlap = chunk_overlap

    @property
    def chunk_size(self) -> int:
        return self._chunk_size

    @property
    def chunk_overlap(self) -> int:
        return self._chunk_overlap

    def split_document(self, document: RawLoadedDocument) -> list[RAGDocumentChunk]:
        """Split a `RawLoadedDocument` into a list of `RAGDocumentChunk` objects."""
        text = document.content.strip()
        if not text:
            return []

        sections = self._split_into_sections(text, default_section=document.metadata.title)
        raw_chunks: list[tuple[str, str]] = []

        for section_title, section_body in sections:
            for piece in self._split_text_with_overlap(section_body):
                cleaned_piece = piece.strip()
                if cleaned_piece:
                    raw_chunks.append((section_title, cleaned_piece))

        total_chunks = len(raw_chunks)
        result: list[RAGDocumentChunk] = []

        for idx, (section_title, chunk_text) in enumerate(raw_chunks):
            chunk_id = f"{document.metadata.document_id}::chunk-{idx:04d}"
            chunk_meta = RAGChunkMetadata(
                chunk_id=chunk_id,
                document_id=document.metadata.document_id,
                source=document.metadata.source,
                category=document.metadata.category.value,
                title=document.metadata.title,
                section=section_title,
                chunk_index=idx,
                total_chunks=total_chunks,
                created_at=document.metadata.created_at,
                content_hash=document.metadata.content_hash,
            )
            result.append(
                RAGDocumentChunk(
                    chunk_id=chunk_id,
                    content=chunk_text,
                    metadata=chunk_meta,
                )
            )
        return result

    def split_documents(
        self, documents: Iterable[RawLoadedDocument]
    ) -> list[RAGDocumentChunk]:
        """Split multiple documents into chunks."""
        all_chunks: list[RAGDocumentChunk] = []
        for doc in documents:
            all_chunks.extend(self.split_document(doc))
        return all_chunks

    def _split_into_sections(
        self, text: str, default_section: str = "Overview"
    ) -> list[tuple[str, str]]:
        """Group document lines by H1/H2/H3 Markdown headings."""
        lines = text.split("\n")
        current_section = default_section or "Overview"
        current_lines: list[str] = []
        sections: list[tuple[str, str]] = []

        for line in lines:
            match = _HEADING_LINE_RE.match(line.strip())
            if match:
                body_so_far = "\n".join(current_lines).strip()
                if body_so_far:
                    sections.append((current_section, body_so_far))
                current_section = match.group(2).strip()
                current_lines = [line]
            else:
                current_lines.append(line)

        trailing_body = "\n".join(current_lines).strip()
        if trailing_body:
            sections.append((current_section, trailing_body))

        return sections

    def _split_text_with_overlap(self, text: str) -> list[str]:
        """Split a section's text into chunks <= `chunk_size` with `chunk_overlap`."""
        if len(text) <= self._chunk_size:
            return [text]

        paragraphs = [p.strip() for p in text.split("\n\n") if p.strip()]
        units: list[str] = []
        for para in paragraphs:
            if len(para) <= self._chunk_size:
                units.append(para)
            else:
                units.extend(self._split_oversized_paragraph(para))

        chunks: list[str] = []
        current = ""

        for unit in units:
            candidate = f"{current}\n\n{unit}".strip() if current else unit
            if len(candidate) <= self._chunk_size:
                current = candidate
            else:
                if current:
                    chunks.append(current)
                    overlap_prefix = (
                        current[-self._chunk_overlap :].lstrip()
                        if self._chunk_overlap > 0
                        else ""
                    )
                    if overlap_prefix and len(overlap_prefix) + len(unit) + 2 <= self._chunk_size:
                        current = f"{overlap_prefix}\n\n{unit}"
                    else:
                        current = unit
                else:
                    chunks.append(unit[: self._chunk_size])
                    current = ""

        if current:
            chunks.append(current)

        return chunks

    def _split_oversized_paragraph(self, paragraph: str) -> list[str]:
        """Split a single long paragraph by sentences or sliding window."""
        sentences = re.split(r"(?<=[.!?])\s+", paragraph)
        pieces: list[str] = []
        current = ""
        step = max(1, self._chunk_size - self._chunk_overlap)

        for sentence in sentences:
            if len(sentence) > self._chunk_size:
                if current:
                    pieces.append(current)
                    current = ""
                for start in range(0, len(sentence), step):
                    pieces.append(sentence[start : start + self._chunk_size])
                continue

            candidate = f"{current} {sentence}".strip() if current else sentence
            if len(candidate) <= self._chunk_size:
                current = candidate
            else:
                if current:
                    pieces.append(current)
                current = sentence

        if current:
            pieces.append(current)
        return pieces
