"""
CLI Tool for ReMarket RAG Ingestion and Semantic Retrieval (`app.rag.cli`).

Usage examples:
  python -m app.rag.cli ingest --dir ./data/knowledge_base
  python -m app.rag.cli query --query "Cách phân loại tình trạng LIKE_NEW và GOOD" --top-k 3
  python -m app.rag.cli stats
  python -m app.rag.cli delete --doc-id remarket-policies
"""

import argparse
import json
from pathlib import Path
import sys
from typing import Optional

from app.core.config import get_settings
from app.rag.pipelines import RAGPipeline


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="python -m app.rag.cli",
        description="ReMarket RAG Knowledge Base Ingestion & Retrieval CLI",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    # ingest command
    ingest_parser = subparsers.add_parser(
        "ingest",
        help="Ingest Markdown (.md) and PDF (.pdf) documents into the vector store.",
    )
    ingest_parser.add_argument(
        "--dir",
        type=str,
        default=None,
        help="Directory containing knowledge base documents (default: RAG_KNOWLEDGE_BASE_DIR).",
    )
    ingest_parser.add_argument(
        "--file",
        type=str,
        default=None,
        help="Optional single .md or .pdf file to ingest instead of a directory.",
    )
    ingest_parser.add_argument(
        "--force",
        action="store_true",
        help="Force re-embedding even if document content_hash has not changed.",
    )

    # query command
    query_parser = subparsers.add_parser(
        "query",
        help="Execute semantic retrieval and assemble grounded context with citations.",
    )
    query_parser.add_argument(
        "--query",
        "-q",
        type=str,
        required=True,
        help="Search query text.",
    )
    query_parser.add_argument(
        "--top-k",
        type=int,
        default=None,
        help="Maximum number of retrieved chunks (default: RAG_DEFAULT_TOP_K).",
    )
    query_parser.add_argument(
        "--threshold",
        type=float,
        default=None,
        help="Minimum similarity threshold in [0.0..1.0] (default: RAG_SIMILARITY_THRESHOLD).",
    )
    query_parser.add_argument(
        "--category",
        type=str,
        default=None,
        help="Optional knowledge category filter (e.g. policy, safety_guide, condition_grading).",
    )

    # delete command
    delete_parser = subparsers.add_parser(
        "delete",
        help="Delete a document and all its chunks from the vector store by document_id.",
    )
    delete_parser.add_argument(
        "--doc-id",
        type=str,
        required=True,
        help="Target document_id to remove.",
    )

    # stats command
    subparsers.add_parser(
        "stats",
        help="Inspect vector store statistics and list ingested document IDs.",
    )

    return parser


def run_cli(
    argv: Optional[list[str]] = None,
    *,
    pipeline: Optional[RAGPipeline] = None,
) -> int:
    parser = build_arg_parser()
    args = parser.parse_args(argv)
    settings = get_settings()
    active_pipeline = pipeline or RAGPipeline(settings=settings)

    if args.command == "ingest":
        if args.file:
            res = active_pipeline.ingestion.ingest_file(
                Path(args.file),
                force_update=bool(args.force),
            )
            print(json.dumps(res.model_dump(), ensure_ascii=False, indent=2))
            return 0

        report = active_pipeline.ingestion.ingest_directory(
            directory_path=args.dir,
            force_update=bool(args.force),
        )
        print(json.dumps(report.model_dump(), ensure_ascii=False, indent=2))
        return 0

    if args.command == "query":
        result = active_pipeline.query(
            args.query,
            top_k=args.top_k,
            similarity_threshold=args.threshold,
            category=args.category,
        )
        print(json.dumps(result.model_dump(), ensure_ascii=False, indent=2))
        return 0

    if args.command == "delete":
        deleted_chunks = active_pipeline.ingestion.delete_document(args.doc_id)
        print(
            json.dumps(
                {
                    "document_id": args.doc_id,
                    "deleted_chunks": deleted_chunks,
                },
                ensure_ascii=False,
                indent=2,
            )
        )
        return 0

    if args.command == "stats":
        store = active_pipeline.vector_store
        doc_ids = store.list_document_ids()
        print(
            json.dumps(
                {
                    "store_type": store.store_type,
                    "total_chunks": store.count_chunks(),
                    "total_documents": len(doc_ids),
                    "document_ids": doc_ids,
                },
                ensure_ascii=False,
                indent=2,
            )
        )
        return 0

    return 1


if __name__ == "__main__":
    sys.exit(run_cli())
