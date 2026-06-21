from collections.abc import Mapping
from pathlib import Path

from .answerer import compose_answer
from .chunker import chunk_documents
from .loader import load_corpus
from .models import Answer, Chunk
from .retriever import Retriever


class ContractRAG:
    def __init__(self, retriever: Retriever) -> None:
        self.retriever = retriever

    @classmethod
    def from_corpus(cls, path: Path) -> "ContractRAG":
        return cls(Retriever(chunk_documents(load_corpus(path))))

    @classmethod
    def from_chunks(cls, chunks: list[Chunk]) -> "ContractRAG":
        return cls(Retriever(chunks))

    def ask(
        self, query: str, filters: Mapping[str, str] | None = None
    ) -> Answer:
        return compose_answer(query, self.retriever.search(query, filters=filters))
