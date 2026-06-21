import unittest

from contract_rag.models import Chunk
from contract_rag.retriever import Retriever


CHUNKS = [
    Chunk(
        chunk_id="msa-001:000",
        document_id="msa-001",
        heading="Termination",
        text="Either party may terminate with 30 days written notice.",
        ordinal=0,
        metadata={"contract_type": "msa", "jurisdiction": "US"},
    ),
    Chunk(
        chunk_id="dpa-001:000",
        document_id="dpa-001",
        heading="Breach Notification",
        text="The processor must report a personal data breach within 72 hours.",
        ordinal=0,
        metadata={"contract_type": "dpa", "jurisdiction": "EU"},
    ),
    Chunk(
        chunk_id="license-001:000",
        document_id="license-001",
        heading="Audit",
        text="The licensee receives 10 business days notice before an audit.",
        ordinal=0,
        metadata={"contract_type": "license", "jurisdiction": "US"},
    ),
]


class RetrieverTest(unittest.TestCase):
    def setUp(self) -> None:
        self.retriever = Retriever(CHUNKS)

    def test_termination_written_notice_ranks_msa_first(self) -> None:
        results = self.retriever.search("termination written notice")

        self.assertEqual(results[0].chunk.document_id, "msa-001")

    def test_contract_type_filter_returns_only_matching_dpa(self) -> None:
        results = self.retriever.search(
            "report data breach", filters={"contract_type": "dpa"}
        )

        self.assertEqual([result.chunk.document_id for result in results], ["dpa-001"])

    def test_repeated_notice_search_is_deterministic(self) -> None:
        first = self.retriever.search("notice")
        second = self.retriever.search("notice")

        self.assertEqual(first, second)


if __name__ == "__main__":
    unittest.main()
