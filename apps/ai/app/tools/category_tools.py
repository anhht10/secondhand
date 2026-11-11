"""
Category Domain Agent Tools (`app.tools.category_tools`).
Implements `get_product_categories` backed by `GET /api/v1/categories` on NestJS Backend.
"""

from typing import Any, Mapping, Optional

from langchain_core.tools import StructuredTool
from pydantic import BaseModel, Field, field_validator

from app.services.backend_client import (
    BackendClient,
    get_backend_client,
    run_async_safely,
)
from app.tools.base import ToolStrictInputModel, validate_object_id


class GetProductCategoriesInput(ToolStrictInputModel):
    """Input schema for `get_product_categories` tool."""

    parent_id: Optional[str] = Field(
        default=None,
        description=(
            "Optional filter: pass 'root' for top-level categories only, a 24-character hex "
            "MongoDB ObjectId for child categories of a specific parent, or omit to list all active categories."
        ),
    )

    @field_validator("parent_id")
    @classmethod
    def validate_parent_id(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return None
        cleaned = value.strip()
        if not cleaned:
            return None
        if cleaned.lower() in ("root", "null"):
            return "root"
        return validate_object_id(cleaned, "parent_id")


class CategoryToolItem(BaseModel):
    """Normalized active marketplace category item."""

    id: str
    name: str
    slug: str
    description: Optional[str] = None
    icon: Optional[str] = None
    parentId: Optional[str] = None
    isActive: bool = True
    sortOrder: int = 0


class CategoriesToolOutput(BaseModel):
    """Output schema for `get_product_categories` tool."""

    categories: list[CategoryToolItem] = Field(default_factory=list)
    total: int = 0
    parentFilter: Optional[str] = None


def normalize_category_item(raw: Mapping[str, Any]) -> CategoryToolItem:
    """Normalize a raw NestJS Category JSON object into `CategoryToolItem`."""
    cat_id = str(raw.get("id") or raw.get("_id") or "")
    raw_parent = raw.get("parentId")
    parent_id = str(raw_parent) if raw_parent is not None else None
    return CategoryToolItem(
        id=cat_id,
        name=str(raw.get("name") or ""),
        slug=str(raw.get("slug") or ""),
        description=raw.get("description"),
        icon=raw.get("icon"),
        parentId=parent_id,
        isActive=bool(raw.get("isActive", True)),
        sortOrder=int(raw.get("sortOrder", 0)),
    )


async def get_product_categories_async(
    parent_id: Optional[str] = None,
    *,
    client: Optional[BackendClient] = None,
) -> dict[str, Any]:
    """Execute `get_product_categories` asynchronously via `BackendClient`."""
    validated = GetProductCategoriesInput(parent_id=parent_id)
    backend = client or get_backend_client()
    response = await backend.list_categories(parent_id=validated.parent_id)

    raw_list = response.get("data")
    if not isinstance(raw_list, list):
        raw_list = []

    categories = [
        normalize_category_item(item)
        for item in raw_list
        if isinstance(item, Mapping) and bool(item.get("isActive", True))
    ]
    output = CategoriesToolOutput(
        categories=categories,
        total=len(categories),
        parentFilter=validated.parent_id,
    )
    return output.model_dump()


def build_category_tools(client: Optional[BackendClient] = None) -> list[StructuredTool]:
    """Build the `get_product_categories` LangChain `StructuredTool`."""

    def _categories_sync(parent_id: Optional[str] = None) -> dict[str, Any]:
        return run_async_safely(
            get_product_categories_async(parent_id=parent_id, client=client)
        )

    async def _categories_async(parent_id: Optional[str] = None) -> dict[str, Any]:
        return await get_product_categories_async(parent_id=parent_id, client=client)

    return [
        StructuredTool.from_function(
            func=_categories_sync,
            coroutine=_categories_async,
            name="get_product_categories",
            description=(
                "Retrieve all active product categories on ReMarket (including id, name, slug, "
                "description, icon, and parentId hierarchy)."
            ),
            args_schema=GetProductCategoriesInput,
        )
    ]


_default_category_tools = build_category_tools()
get_product_categories_tool = _default_category_tools[0]
get_product_categories = get_product_categories_tool
