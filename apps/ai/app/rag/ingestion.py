"""
RAG Document Ingestion Service (`app.rag.ingestion`).
Implements steps 1-6 of the RAG pipeline:
1. Document Loading (Markdown & PDF)
2. Text Cleaning & Prompt-Injection Sanitization
3. Metadata Extraction (`source`, `category`, `document_id`, `created_at`, `content_hash`)
4. Text Splitting (`MarkdownAwareTextSplitter`)
5. Embedding (`EmbeddingProviderProtocol` / `GeminiEmbeddingProvider`)
6. Vector Storage (`VectorStoreProtocol` / `ChromaVectorStore`) with:
   - Duplicate ingestion prevention (`content_hash` check -> `skipped_duplicate`)
   - Seamless document updates (`old_hash != new_hash` -> delete old chunks + upsert new -> `updated`)
   - Explicit document deletion (`delete_document(document_id)`)
"""

import logging
from pathlib import Path
from typing import Iterable, Optional

from app.core.config import Settings, get_settings
from app.rag.embeddings import EmbeddingProviderProtocol, GeminiEmbeddingProvider
from app.rag.loaders import load_document_from_file, load_documents_from_directory
from app.rag.schemas import (
    DocumentIngestionItemResult,
    IngestionSummaryReport,
    KnowledgeCategory,
    RawLoadedDocument,
)
from app.rag.splitters import MarkdownAwareTextSplitter
from app.rag.vectorstores import VectorStoreProtocol, create_vector_store

logger = logging.getLogger("remarket.ai.rag.ingestion")


class KnowledgeIngestionService:
    """
    Service responsible for loading, cleaning, splitting, embedding, deduplicating,
    updating, and deleting documents in the ReMarket RAG vector store.
    """

    def __init__(
        self,
        *,
        vector_store: Optional[VectorStoreProtocol] = None,
        embedding_provider: Optional[EmbeddingProviderProtocol] = None,
        splitter: Optional[MarkdownAwareTextSplitter] = None,
        settings: Optional[Settings] = None,
    ) -> None:
        self._settings = settings or get_settings()
        self._vector_store = vector_store or create_vector_store(self._settings)
        self._embedding_provider = embedding_provider or GeminiEmbeddingProvider(
            settings=self._settings
        )
        self._splitter = splitter or MarkdownAwareTextSplitter(
            chunk_size=self._settings.RAG_CHUNK_SIZE,
            chunk_overlap=self._settings.RAG_CHUNK_OVERLAP,
        )

    @property
    def vector_store(self) -> VectorStoreProtocol:
        return self._vector_store

    @property
    def embedding_provider(self) -> EmbeddingProviderProtocol:
        return self._embedding_provider

    @property
    def splitter(self) -> MarkdownAwareTextSplitter:
        return self._splitter

    def ingest_document(
        self,
        document: RawLoadedDocument,
        *,
        force_update: bool = False,
    ) -> DocumentIngestionItemResult:
        """
        Ingest a single `RawLoadedDocument` into the vector store.
        - If `document_id` already exists with the same `content_hash` and `force_update=False`,
          skips re-embedding and returns `status='skipped_duplicate'`.
        - If `document_id` exists with a different `content_hash` (or `force_update=True`),
          deletes previous chunks first and upserts the updated chunks (`status='updated'`).
        - Otherwise, embeds and stores the new chunks (`status='ingested'`).
        """
        doc_id = document.metadata.document_id
        new_hash = document.metadata.content_hash
        existing_hash = self._vector_store.get_document_content_hash(doc_id)

        if existing_hash is not None and existing_hash == new_hash and not force_update:
            logger.info(
                "Skipping duplicate RAG document document_id=%s hash=%s",
                doc_id,
                new_hash[:12],
            )
            return DocumentIngestionItemResult(
                document_id=doc_id,
                source=document.metadata.source,
                category=document.metadata.category.value,
                status="skipped_duplicate",
                chunks_count=0,
                content_hash=new_hash,
            )

        is_update = existing_hash is not None
        if is_update:
            deleted_count = self._vector_store.delete_document(doc_id)
            logger.info(
                "Updating existing RAG document document_id=%s removed_old_chunks=%d",
                doc_id,
                deleted_count,
            )

        chunks = self._splitter.split_document(document)
        if not chunks:
            return DocumentIngestionItemResult(
                document_id=doc_id,
                source=document.metadata.source,
                category=document.metadata.category.value,
                status="updated" if is_update else "ingested",
                chunks_count=0,
                content_hash=new_hash,
            )

        texts = [chunk.content for chunk in chunks]
        embeddings = self._embedding_provider.embed_documents(texts)
        upserted = self._vector_store.upsert_chunks(chunks, embeddings)

        status_label = "updated" if is_update else "ingested"
        logger.info(
            "Completed RAG document ingestion document_id=%s status=%s chunks=%d",
            doc_id,
            status_label,
            upserted,
        )
        return DocumentIngestionItemResult(
            document_id=doc_id,
            source=document.metadata.source,
            category=document.metadata.category.value,
            status=status_label,
            chunks_count=upserted,
            content_hash=new_hash,
        )

    def ingest_documents(
        self,
        documents: Iterable[RawLoadedDocument],
        *,
        force_update: bool = False,
    ) -> IngestionSummaryReport:
        """Ingest a batch of `RawLoadedDocument` objects and return an `IngestionSummaryReport`."""
        report = IngestionSummaryReport()
        for doc in documents:
            item_res = self.ingest_document(doc, force_update=force_update)
            report.documents.append(item_res)
            report.total_documents_processed += 1
            report.total_chunks_upserted += item_res.chunks_count
            if item_res.status == "ingested":
                report.ingested_count += 1
            elif item_res.status == "updated":
                report.updated_count += 1
            elif item_res.status == "skipped_duplicate":
                report.skipped_duplicate_count += 1
        return report

    def ingest_file(
        self,
        file_path: str | Path,
        *,
        category: Optional[str | KnowledgeCategory] = None,
        document_id: Optional[str] = None,
        source_override: Optional[str] = None,
        force_update: bool = False,
    ) -> DocumentIngestionItemResult:
        """Load and ingest a single `.md` or `.pdf` file."""
        doc = load_document_from_file(
            file_path,
            category=category,
            document_id=document_id,
            source_override=source_override,
        )
        return self.ingest_document(doc, force_update=force_update)

    def ingest_directory(
        self,
        directory_path: Optional[str | Path] = None,
        *,
        recursive: bool = True,
        force_update: bool = False,
    ) -> IngestionSummaryReport:
        """Load and ingest all `.md` and `.pdf` files from a knowledge base directory."""
        target_dir = Path(directory_path or self._settings.RAG_KNOWLEDGE_BASE_DIR)
        docs = load_documents_from_directory(target_dir, recursive=recursive)
        return self.ingest_documents(docs, force_update=force_update)

    def delete_document(self, document_id: str) -> int:
        """Delete all chunks associated with `document_id` from the vector store."""
        return self._vector_store.delete_document(document_id)
