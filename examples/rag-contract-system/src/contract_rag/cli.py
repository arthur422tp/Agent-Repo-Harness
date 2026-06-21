import argparse
import json
from pathlib import Path
from typing import Sequence

from .models import Answer
from .pipeline import ContractRAG


ROOT = Path(__file__).resolve().parents[2]


def answer_payload(answer: Answer) -> dict[str, object]:
    return {
        "text": answer.text,
        "supported": answer.supported,
        "confidence": answer.confidence,
        "citations": [
            {
                "document_id": citation.document_id,
                "heading": citation.heading,
                "chunk_id": citation.chunk_id,
            }
            for citation in answer.citations
        ],
    }


def evaluate_cases(cases_path: Path, corpus_path: Path) -> list[str]:
    try:
        cases = json.loads(cases_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"could not read evaluation cases {cases_path}: {exc}") from exc

    pipeline = ContractRAG.from_corpus(corpus_path)
    failures: list[str] = []
    for case in cases:
        answer = pipeline.ask(case["query"], case.get("filters") or None)
        actual_documents = sorted({citation.document_id for citation in answer.citations})
        expected_documents = sorted(case["expected_document_ids"])
        missing_terms = [term for term in case["required_terms"] if term.lower() not in answer.text.lower()]
        present_forbidden = [term for term in case["forbidden_terms"] if term.lower() in answer.text.lower()]
        if (
            actual_documents != expected_documents
            or missing_terms
            or present_forbidden
            or answer.supported is not case["expected_supported"]
        ):
            failures.append(
                f"{case['id']}: expected_documents={expected_documents} "
                f"actual_documents={actual_documents} missing_terms={missing_terms} "
                f"forbidden_terms={present_forbidden} supported={answer.supported}"
            )
    return failures


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(prog="contract-rag")
    commands = root.add_subparsers(dest="command", required=True)

    ask = commands.add_parser("ask", help="Ask a question about the contract corpus")
    ask.add_argument("query")
    ask.add_argument("--contract-type")
    ask.add_argument("--jurisdiction")

    commands.add_parser("eval", help="Run fixed evaluation cases")
    return root


def main(argv: Sequence[str] | None = None) -> int:
    args = parser().parse_args(argv)
    corpus_path = ROOT / "data" / "contracts"

    if args.command == "ask":
        filters = {
            key: value
            for key, value in {
                "contract_type": args.contract_type,
                "jurisdiction": args.jurisdiction,
            }.items()
            if value
        }
        answer = ContractRAG.from_corpus(corpus_path).ask(args.query, filters or None)
        print(json.dumps(answer_payload(answer), indent=2, sort_keys=True))
        return 0

    cases_path = ROOT / "evals" / "cases.json"
    failures = evaluate_cases(cases_path, corpus_path)
    if failures:
        for failure in failures:
            print(f"FAIL: {failure}")
        return 1

    cases = json.loads(cases_path.read_text(encoding="utf-8"))
    for case in cases:
        print(f"PASS: {case['id']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
