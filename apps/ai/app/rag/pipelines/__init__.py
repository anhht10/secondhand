"""
RAG Pipelines Package (`app.rag.pipelines`).
"""

from app.rag.pipelines.rag_pipeline import (
    NO_CONTEXT_GROUNDING_INSTRUCTION,
    STRICT_GROUNDING_INSTRUCTION,
    RAGPipeline,
    assemble_grounded_context,
)

__all__ = [
    "RAGPipeline",
    "assemble_grounded_context",
    "STRICT_GROUNDING_INSTRUCTION",
    "NO_CONTEXT_GROUNDING_INSTRUCTION",
]
