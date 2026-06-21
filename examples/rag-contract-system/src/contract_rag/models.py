from dataclasses import dataclass
from pathlib import Path
from typing import Mapping


@dataclass(frozen=True)
class Document:
    document_id: str
    title: str
    path: Path
    metadata: Mapping[str, str]
    content: str


@dataclass(frozen=True)
class Chunk:
    chunk_id: str
    document_id: str
    heading: str
    text: str
    ordinal: int
    metadata: Mapping[str, str]


@dataclass(frozen=True)
class SearchResult:
    chunk: Chunk
    score: float
    matched_terms: tuple[str, ...]


@dataclass(frozen=True)
class Citation:
    document_id: str
    heading: str
    chunk_id: str


@dataclass(frozen=True)
class Answer:
    text: str
    citations: tuple[Citation, ...]
    supported: bool
    confidence: float
