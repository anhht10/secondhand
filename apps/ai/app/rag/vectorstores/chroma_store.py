"""
Persistent ChromaDB Vector Store (`app.rag.vectorstores.chroma_store`).
Provides disk-persisted vector storage for the ReMarket RAG MVP when local MongoDB
(`mongo:7.0`) is used without MongoDB Atlas Vector Search.
"""

from pathlib import Path
from typing import Any, Optional

import chromadb
from chromadb.config import Settings as ChromaClientSettings

from app.rag.schemas import RAGChunkMetadata, RAGDocumentChunk, RAGRetrievedChunk
from app.rag.vectorstores.base import cosine_similarity_score


class ChromaVectorStore:
    """
    Persistent ChromaDB vector store supporting chunk upsert, deduplication by
    `content_hash`, document update/deletion, and cosine semantic search.
    """

    def __init__(
        self,
        *,
        persist_directory: str | Path = "./data/chroma",
        collection_name: str = "remarket_knowledge_base",
    ) -> None:
        self._persist_path = Path(persist_directory).resolve()
        self._persist_path.mkdir(parents=True, exist_ok=True)
        self._collection_name = collection_name

        self._client = chromadb.PersistentClient(
            path=str(self._persist_path),
            settings=ChromaClientSettings(anonymized_telemetry=False),
        )
        self._collection = self._client.get_or_create_collection(
            name=self._collection_name,
            metadata={"hnsw:space": "cosine"},
        )

    @property
    def store_type(self) -> str:
        return "chroma"

    @property
    def persist_directory(self) -> Path:
        return self._persist_path

    @property
    def collection_name(self) -> str:
        return self._collection_name

    def upsert_chunks(
        self,
        chunks: list[RAGDocumentChunk],
        embeddings: list[list[float]],
    ) -> int:
        """Upsert a list of `RAGDocumentChunk` items and their vectors into ChromaDB."""
        if not chunks:
            return 0
        if len(chunks) != len(embeddings):
            raise ValueError(
                f"Mismatch between chunks count ({len(chunks)}) and embeddings count ({len(embeddings)})."
            )

        ids = [c.chunk_id for c in chunks]
        documents = [c.content for c in chunks]
        metadatas: list[dict[str, Any]] = [c.metadata.to_flat_dict() for c in chunks]

        self._collection.upsert(
            ids=ids,
            embeddings=embeddings,
            documents=documents,
            metadatas=metadatas,
        )
        return len(chunks)

    def get_document_content_hash(self, document_id: str) -> Optional[str]:
        """
        Return the stored `content_hash` for `document_id` if already ingested,
        or None if `document_id` does not exist in the collection.
        """
        clean_id = document_id.strip()
        if not clean_id:
            return None
        res = self._collection.get(
            where={"document_id": clean_id},
            limit=1,
            include=["metadatas"],
        )
        metadatas = res.get("metadatas") or []
        if metadatas and isinstance(metadatas[0], dict):
            stored_hash = metadatas[0].get("content_hash")
            return str(stored_hash) if stored_hash else None
        return None

    def delete_document(self, document_id: str) -> int:
        """Delete all chunks belonging to `document_id` and return the number of deleted chunks."""
        clean_id = document_id.strip()
        if not clean_id:
            return 0
        existing = self._collection.get(
            where={"document_id": clean_id},
            include=[],
        )
        chunk_ids = list(existing.get("ids") or [])
        if not chunk_ids:
            return 0
        self._collection.delete(ids=chunk_ids)
        return len(chunk_ids)

    def similarity_search(
        self,
        query_embedding: list[float],
        *,
        top_k: int = 4,
        similarity_threshold: float = 0.0,
        category: Optional[str] = None,
    ) -> list[RAGRetrievedChunk]:
        """
        Execute semantic similarity search against ChromaDB and filter by `similarity_threshold`.
        """
        total_count = self._collection.count()
        if total_count == 0:
            return []

        where_filter: Optional[dict[str, Any]] = None
        if category and category.strip():
            where_filter = {"category": category.strip()}

        query_kwargs: dict[str, Any] = {
            "query_embeddings": [query_embedding],
            "n_results": min(max(1, top_k * 2), total_count),
            "include": ["documents", "metadatas", "distances", "embeddings"],
        }
        if where_filter is not None:
            query_kwargs["where"] = where_filter

        try:
            raw = self._collection.query(**query_kwargs)
        except Exception:
            # If category filter matched 0 items in Chroma, return empty list cleanly
            return []

        ids_list = (raw.get("ids") or [[]])[0]
        docs_list = (raw.get("documents") or [[]])[0]
        metas_list = (raw.get("metadatas") or [[]])[0]
        dists_list = (raw.get("distances") or [[]])[0]
        embs_list = (raw.get("embeddings") or [[]])[0]

        results: list[RAGRetrievedChunk] = []
        for idx, chunk_id in enumerate(ids_list):
            doc_text = docs_list[idx] if idx < len(docs_list) else ""
            raw_meta = metas_list[idx] if idx < len(metas_list) and metas_list[idx] else {}

            if embs_list is not None and idx < len(embs_list) and embs_list[idx] is not None:
                stored_vec = [float(x) for x in embs_list[idx]]
                sim_score = cosine_similarity_score(query_embedding, stored_vec)
            else:
                dist = float(dists_list[idx]) if idx < len(dists_list) else 1.0
                sim_score = max(0.0, min(1.0, 1.0 - dist))

            if sim_score < similarity_threshold:
                continue

            chunk_meta = RAGChunkMetadata(
                chunk_id=str(raw_meta.get("chunk_id") or chunk_id),
                document_id=str(raw_meta.get("document_id") or ""),
                source=str(raw_meta.get("source") or ""),
                category=str(raw_meta.get("category") or "general"),
                title=str(raw_meta.get("title") or ""),
                section=str(raw_meta.get("section") or ""),
                chunk_index=int(raw_meta.get("chunk_index", 0)),
                total_chunks=int(raw_meta.get("total_chunks", 1)),
                created_at=str(raw_meta.get("created_at") or ""),
                content_hash=str(raw_meta.get("content_hash") or ""),
            )
            results.append(
                RAGRetrievedChunk(
                    chunk_id=str(chunk_id),
                    content=str(doc_text or ""),
                    similarity_score=round(sim_score, 4),
                    metadata=chunk_meta,
                )
            )

        results.sort(key=lambda item: item.similarity_score, reverse=True)
        return results[: max(1, top_k)]

    def count_chunks(self) -> int:
        """Return total number of chunks currently stored in ChromaDB."""
        return int(self._collection.count())

    def list_document_ids(self) -> list[str]:
        """Return sorted list of unique `document_id` values in the collection."""
        if self._collection.count() == 0:
            return []
        res = self._collection.get(include=["metadatas"])
        metadatas = res.get("metadatas") or []
        doc_ids = {
            str(m["document_id"])
            for m in metadatas
            if isinstance(m, dict) and m.get("document_id")
        }
        return sorted(doc_ids)
