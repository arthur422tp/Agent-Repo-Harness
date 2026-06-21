import unittest

from contract_rag.models import Chunk
from contract_rag.pipeline import ContractRAG


CHUNKS = [
    Chunk(
        chunk_id="msa:000",
        document_id="msa",
        heading="Termination",
        text="Either party may terminate with 30 days written notice.",
        ordinal=0,
        metadata={"contract_type": "msa", "jurisdiction": "US"},
    ),
    Chunk(
        chunk_id="dpa:000",
        document_id="dpa",
        heading="Breach",
        text="The processor must report a personal data breach within 72 hours.",
        ordinal=0,
        metadata={"contract_type": "dpa", "jurisdiction": "EU"},
    ),
]


class ContractRAGTest(unittest.TestCase):
    def setUp(self) -> None:
        self.rag = ContractRAG.from_chunks(CHUNKS)

    def test_termination_notice_answer_is_supported_and_cites_msa(self) -> None:
        answer = self.rag.ask("What is the termination notice period?")

        self.assertTrue(answer.supported)
        self.assertIn("30 days", answer.text)
        self.assertEqual(answer.citations[0].document_id, "msa")

    def test_breach_answer_honors_dpa_filter_and_cites_dpa(self) -> None:
        answer = self.rag.ask(
            "Who reports a data breach?",
            filters={"contract_type": "dpa"},
        )

        self.assertTrue(answer.supported)
        self.assertEqual(answer.citations[0].document_id, "dpa")

    def test_unsupported_query_returns_exact_fallback(self) -> None:
        answer = self.rag.ask("What is the employee vacation policy?")

        self.assertFalse(answer.supported)
        self.assertEqual(answer.citations, ())
        self.assertEqual(
            answer.text,
            "The provided contracts do not contain enough evidence to answer.",
        )


if __name__ == "__main__":
    unittest.main()
