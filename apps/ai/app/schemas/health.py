"""
Health and Readiness schemas for ReMarket AI Service.
"""

from pydantic import BaseModel, Field


class HealthResponse(BaseModel):
    """Liveness response payload for GET /health."""

    status: str = Field(default="ok", description="Service liveness status")
    service: str = Field(default="remarket-ai-service", description="Service identifier")
    version: str = Field(default="0.2.0", description="AI service version")
    model: str = Field(description="Configured default Gemini model identifier")


class ReadinessResponse(BaseModel):
    """Readiness response payload for GET /health/ready."""

    status: str = Field(description="Readiness status: ready or degraded")
    service: str = Field(default="remarket-ai-service", description="Service identifier")
    gemini_configured: bool = Field(
        description="Whether GEMINI_API_KEY is present and non-empty"
    )
    graph_compiled: bool = Field(
        description="Whether the foundational LangGraph workflow compiled cleanly"
    )
    checkpointer_backend: str = Field(
        description="Active conversation state checkpointer backend"
    )
    vector_store_type: str = Field(
        description="Configured vector store type for RAG workflows"
    )
    model: str = Field(description="Configured default Gemini model identifier")
    embedding_model: str = Field(
        default="gemini-embedding-001",
        description="Configured dedicated Gemini embedding model identifier",
    )
    registered_tools_count: int = Field(
        default=6,
        description="Number of registered LangChain tools in ToolRegistry",
    )
