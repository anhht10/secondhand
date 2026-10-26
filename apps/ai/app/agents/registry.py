"""
Graph & Agent Registry for ReMarket AI Service.
Manages compiled LangGraph workflows so graphs are compiled once and reused across requests.
"""

import logging
from typing import Optional
from langgraph.graph.state import CompiledStateGraph

from app.core.config import Settings, get_settings

logger = logging.getLogger("remarket.ai.agents.registry")


class GraphRegistry:
    """Central registry holding compiled LangGraph workflows by name."""

    def __init__(self, settings: Optional[Settings] = None) -> None:
        self._settings = settings or get_settings()
        self._graphs: dict[str, CompiledStateGraph] = {}

    def register(self, name: str, compiled_graph: CompiledStateGraph) -> None:
        """Register a compiled LangGraph instance."""
        self._graphs[name] = compiled_graph
        logger.info("Registered compiled LangGraph workflow name=%s", name)

    def get_test_chat_graph(self) -> CompiledStateGraph:
        """Return (and lazily compile if needed) the foundational `test_chat` graph."""
        if "test_chat" not in self._graphs:
            from app.graphs.test_chat_graph import compile_test_chat_graph

            compiled = compile_test_chat_graph(settings=self._settings)
            self._graphs["test_chat"] = compiled
        return self._graphs["test_chat"]

    def get_listing_graph(self) -> CompiledStateGraph:
        """Return (and lazily compile if needed) Agent 1 (`listing_graph`)."""
        if "listing_graph" not in self._graphs:
            from app.graphs.listing_graph import compile_listing_graph

            self._graphs["listing_graph"] = compile_listing_graph(settings=self._settings)
        return self._graphs["listing_graph"]

    def get_pricing_graph(self) -> CompiledStateGraph:
        """Return (and lazily compile if needed) Agent 2 (`pricing_graph`)."""
        if "pricing_graph" not in self._graphs:
            from app.graphs.pricing_graph import compile_pricing_graph

            self._graphs["pricing_graph"] = compile_pricing_graph(settings=self._settings)
        return self._graphs["pricing_graph"]

    def get_inspection_graph(self) -> CompiledStateGraph:
        """Return (and lazily compile if needed) Agent 3 (`inspection_graph`)."""
        if "inspection_graph" not in self._graphs:
            from app.graphs.inspection_graph import compile_inspection_graph

            self._graphs["inspection_graph"] = compile_inspection_graph(
                settings=self._settings
            )
        return self._graphs["inspection_graph"]

    def get_shopping_assistant_graph(self) -> CompiledStateGraph:
        """Return (and lazily compile if needed) Agent 4 (`shopping_assistant_graph`)."""
        if "shopping_assistant_graph" not in self._graphs:
            from app.graphs.shopping_assistant_graph import (
                compile_shopping_assistant_graph,
            )

            self._graphs["shopping_assistant_graph"] = compile_shopping_assistant_graph(
                settings=self._settings
            )
        return self._graphs["shopping_assistant_graph"]

    def get_supervisor_graph(self) -> CompiledStateGraph:
        """Return (and lazily compile if needed) the top-level `supervisor_graph`."""
        if "supervisor_graph" not in self._graphs:
            from app.graphs.supervisor_graph import compile_supervisor_graph

            self._graphs["supervisor_graph"] = compile_supervisor_graph(
                settings=self._settings
            )
        return self._graphs["supervisor_graph"]

    def list_registered_graphs(self) -> list[str]:
        """Return the list of registered graph names."""
        return list(self._graphs.keys())

    def clear(self) -> None:
        """Clear all cached graphs."""
        self._graphs.clear()


_registry_singleton: Optional[GraphRegistry] = None


def get_graph_registry(settings: Optional[Settings] = None) -> GraphRegistry:
    """Return the shared GraphRegistry singleton."""
    global _registry_singleton
    if settings is not None:
        return GraphRegistry(settings=settings)
    if _registry_singleton is None:
        _registry_singleton = GraphRegistry(settings=get_settings())
    return _registry_singleton


def reset_graph_registry() -> None:
    """Reset the shared GraphRegistry singleton."""
    global _registry_singleton
    if _registry_singleton is not None:
        _registry_singleton.clear()
    _registry_singleton = None
