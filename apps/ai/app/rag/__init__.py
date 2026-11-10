"""
ReMarket RAG System Package (`app.rag`).
"""

from app.rag.base import RetrieverProviderProtocol
from app.rag.embeddings import (
    EmbeddingProviderProtocol,
    GeminiEmbeddingProvider,
    normalize_vector,
    validate_embedding_model_name,
)
from app.rag.ingestion import KnowledgeIngestionService
from app.rag.loaders import (
    MarkdownDocumentLoader,
    PDFDocumentLoader,
    load_document_from_file,
    load_documents_from_directory,
    sanitize_and_clean_text,
)
from app.rag.pipelines import RAGPipeline, assemble_grounded_context
from app.rag.retrievers import SemanticKnowledgeRetriever
from app.rag.schemas import (
    DocumentIngestionItemResult,
    IngestionSummaryReport,
    KnowledgeCategory,
    RAGChunkMetadata,
    RAGDocumentChunk,
    RAGDocumentMetadata,
    RAGRetrievalResult,
    RAGRetrievedChunk,
    RAGSourceAttribution,
    RawLoadedDocument,
)
from app.rag.splitters import MarkdownAwareTextSplitter
from app.rag.vectorstores import (
    ChromaVectorStore,
    InMemoryVectorStore,
    VectorStoreProtocol,
    create_vector_store,
)

__all__ = [
    "RetrieverProviderProtocol",
    "KnowledgeCategory",
    "RAGDocumentMetadata",
    "RawLoadedDocument",
    "RAGChunkMetadata",
    "RAGDocumentChunk",
    "DocumentIngestionItemResult",
    "IngestionSummaryReport",
    "RAGSourceAttribution",
    "RAGRetrievedChunk",
    "RAGRetrievalResult",
    "MarkdownDocumentLoader",
    "PDFDocumentLoader",
    "load_document_from_file",
    "load_documents_from_directory",
    "sanitize_and_clean_text",
    "MarkdownAwareTextSplitter",
    "EmbeddingProviderProtocol",
    "GeminiEmbeddingProvider",
    "normalize_vector",
    "validate_embedding_model_name",
    "VectorStoreProtocol",
    "ChromaVectorStore",
    "InMemoryVectorStore",
    "create_vector_store",
    "KnowledgeIngestionService",
    "SemanticKnowledgeRetriever",
    "RAGPipeline",
    "assemble_grounded_context",
]
