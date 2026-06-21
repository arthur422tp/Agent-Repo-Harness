import re
from collections.abc import Iterable, Mapping

from .models import Chunk, SearchResult


TOKEN_RE = re.compile(r"[a-z0-9]+")
STOP_WORDS = {"a", "an", "is", "the", "to", "what", "who", "with"}


def tokenize(text: str) -> set[str]:
    return {token for token in TOKEN_RE.findall(text.lower()) if token not in STOP_WORDS}


class Retriever:
    def __init__(self, chunks: Iterable[Chunk]) -> None:
        self.chunks = tuple(chunks)

    def search(
        self,
        query: str,
        filters: Mapping[str, str] | None = None,
        top_k: int = 3,
    ) -> list[SearchResult]:
        query_terms = tokenize(query)
        if not query_terms:
            return []

        filters = filters or {}
        results: list[SearchResult] = []
        for chunk in self.chunks:
            if any(chunk.metadata.get(key) != value for key, value in filters.items()):
                continue
            chunk_terms = tokenize(f"{chunk.heading} {chunk.text}")
            matched_terms = tuple(sorted(query_terms & chunk_terms))
            if not matched_terms:
                continue
            results.append(
                SearchResult(
                    chunk=chunk,
                    score=len(matched_terms) / len(query_terms),
                    matched_terms=matched_terms,
                )
            )

        results.sort(
            key=lambda result: (
                -result.score,
                result.chunk.document_id,
                result.chunk.ordinal,
            )
        )
        return results[:top_k]
