import re
from collections.abc import Iterable

from .models import Chunk, Document


HEADING_RE = re.compile(r"^#{1,6}\s+(.+?)\s*$")


def chunk_document(document: Document) -> list[Chunk]:
    chunks: list[Chunk] = []
    heading = document.title
    paragraph_lines: list[str] = []

    def flush() -> None:
        nonlocal paragraph_lines
        text = " ".join(line.strip() for line in paragraph_lines).strip()
        if text:
            ordinal = len(chunks)
            chunks.append(
                Chunk(
                    chunk_id=f"{document.document_id}:{ordinal:03d}",
                    document_id=document.document_id,
                    heading=heading,
                    text=text,
                    ordinal=ordinal,
                    metadata=dict(document.metadata),
                )
            )
        paragraph_lines = []

    for line in document.content.splitlines():
        match = HEADING_RE.match(line)
        if match:
            flush()
            heading = match.group(1).strip()
        elif not line.strip():
            flush()
        else:
            paragraph_lines.append(line)
    flush()
    return chunks


def chunk_documents(documents: Iterable[Document]) -> list[Chunk]:
    return [chunk for document in documents for chunk in chunk_document(document)]
