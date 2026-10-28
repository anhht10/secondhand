"""
Tool Registry for ReMarket AI Service (`app.tools.registry`).
Manages registration, lookup, schema inspection, and safe invocation of
LangChain `BaseTool` / `StructuredTool` instances.
Enforces Phase 2 security policy:
- Only read-only marketplace tools are allowed in the default registry.
- Blocks registration of CRUD/mutation tools (create/update/delete product, price, status, or user account).
- Validates inputs and prevents LLM authentication spoofing before execution.
"""

from typing import Any, Iterable, Mapping, Optional

from langchain_core.tools import BaseTool

from app.core.auth_context import assert_no_spoofed_auth_override
from app.core.exceptions import SecurityViolationError
from app.services.backend_client import BackendClient
from app.tools.category_tools import build_category_tools
from app.tools.product_tools import build_product_tools
from app.tools.user_tools import build_user_tools

# Disallowed CRUD/mutation tool name prefixes in Phase 2
_FORBIDDEN_MUTATION_PREFIXES = (
    "create_",
    "update_",
    "delete_",
    "remove_",
    "patch_",
    "modify_",
    "change_price",
    "change_status",
    "set_price",
    "set_status",
)


class ToolRegistry:
    """Registry for managing and invoking LangChain tools available to LangGraph nodes."""

    def __init__(
        self,
        tools: Optional[Iterable[BaseTool]] = None,
        *,
        enforce_read_only: bool = True,
    ) -> None:
        self._tools: dict[str, BaseTool] = {}
        self._enforce_read_only = enforce_read_only
        for tool in tools or []:
            self.register(tool)

    def register(self, tool: BaseTool) -> None:
        """Register a LangChain `BaseTool` after verifying security policy."""
        name_lower = tool.name.strip().lower()
        if self._enforce_read_only and name_lower.startswith(_FORBIDDEN_MUTATION_PREFIXES):
            raise SecurityViolationError(
                f"Cannot register mutation tool '{tool.name}'. "
                "Phase 2 tools are strictly read-only and cannot perform CRUD on products or users."
            )
        self._tools[tool.name] = tool

    def register_many(self, tools: Iterable[BaseTool]) -> None:
        """Register multiple tools at once."""
        for tool in tools:
            self.register(tool)

    def get(self, name: str) -> BaseTool:
        """Retrieve a registered tool by name or raise KeyError."""
        if name not in self._tools:
            raise KeyError(f"Tool '{name}' is not registered in ToolRegistry.")
        return self._tools[name]

    def has(self, name: str) -> bool:
        """Return True if a tool with `name` is registered."""
        return name in self._tools

    def get_all(self) -> list[BaseTool]:
        """Return all registered tools in registration order."""
        return list(self._tools.values())

    def get_by_names(self, names: Iterable[str]) -> list[BaseTool]:
        """Return a subset of registered tools matching `names`."""
        return [self.get(name) for name in names]

    def list_names(self) -> list[str]:
        """Return the list of registered tool names."""
        return list(self._tools.keys())

    def invoke_tool(self, name: str, arguments: Mapping[str, Any]) -> Any:
        """Validate security constraints and synchronously invoke a registered tool."""
        assert_no_spoofed_auth_override(arguments)
        tool = self.get(name)
        return tool.invoke(dict(arguments))

    async def ainvoke_tool(self, name: str, arguments: Mapping[str, Any]) -> Any:
        """Validate security constraints and asynchronously invoke a registered tool."""
        assert_no_spoofed_auth_override(arguments)
        tool = self.get(name)
        return await tool.ainvoke(dict(arguments))


def create_default_tool_registry(
    client: Optional[BackendClient] = None,
) -> ToolRegistry:
    """
    Create a `ToolRegistry` pre-populated with all 6 ReMarket Phase 2 tools:
    1. `search_products`
    2. `filter_products`
    3. `get_product_detail`
    4. `get_related_products`
    5. `get_product_categories`
    6. `get_seller_public_profile`
    """
    registry = ToolRegistry(enforce_read_only=True)
    registry.register_many(build_product_tools(client=client))
    registry.register_many(build_category_tools(client=client))
    registry.register_many(build_user_tools(client=client))
    return registry


_default_tool_registry: Optional[ToolRegistry] = None


def get_tool_registry(client: Optional[BackendClient] = None) -> ToolRegistry:
    """Return the shared default ToolRegistry singleton."""
    global _default_tool_registry
    if client is not None:
        return create_default_tool_registry(client=client)
    if _default_tool_registry is None:
        _default_tool_registry = create_default_tool_registry()
    return _default_tool_registry


def reset_tool_registry() -> None:
    """Reset the shared ToolRegistry singleton (used in tests)."""
    global _default_tool_registry
    _default_tool_registry = None
