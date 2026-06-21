import re
from collections.abc import Sequence

from .models import Answer, Citation, SearchResult
from .retriever import tokenize


UNSUPPORTED = "The provided contracts do not contain enough evidence to answer."
UNTRUSTED_INSTRUCTION_MARKERS = (
    "ignore previous",
    "reveal secrets",
    "suppress citations",
    "system instruction",
)
SENTENCE_SPLIT_RE = re.compile(r"(?<=[.!?])\s+")


def _unsupported_answer() -> Answer:
    return Answer(UNSUPPORTED, (), False, 0.0)


def _sentences(text: str) -> list[str]:
    return [sentence.strip() for sentence in SENTENCE_SPLIT_RE.split(text) if sentence.strip()]


def _safe_sentence(sentence: str) -> bool:
    lowered = sentence.lower()
    return not any(marker in lowered for marker in UNTRUSTED_INSTRUCTION_MARKERS)


def compose_answer(
    query: str,
    results: Sequence[SearchResult],
    threshold: float = 0.34,
) -> Answer:
    if not results or results[0].score < threshold:
        return _unsupported_answer()

    query_terms = tokenize(query)
    candidates: list[tuple[int, str, SearchResult]] = []
    for result in results:
        for sentence in _sentences(result.chunk.text):
            if _safe_sentence(sentence):
                overlap = len(query_terms & tokenize(sentence))
                candidates.append((overlap, sentence, result))
    if not candidates:
        return _unsupported_answer()

    overlap, sentence, result = max(
        candidates,
        key=lambda candidate: (
            candidate[0],
            candidate[2].score,
            candidate[2].chunk.document_id,
            -candidate[2].chunk.ordinal,
        ),
    )
    if overlap == 0:
        return _unsupported_answer()

    citation = Citation(
        result.chunk.document_id,
        result.chunk.heading,
        result.chunk.chunk_id,
    )
    return Answer(sentence, (citation,), True, result.score)
