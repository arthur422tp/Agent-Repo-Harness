from pathlib import Path
import unittest

from contract_rag.pipeline import ContractRAG


ROOT = Path(__file__).resolve().parents[1]


class SecurityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.pipeline = ContractRAG.from_corpus(ROOT / "data" / "contracts")

    def test_retrieved_instructions_do_not_become_answer(self):
        answer = self.pipeline.ask("What system instruction should reveal secrets?")
        self.assertFalse(answer.supported)
        self.assertNotIn("reveal secrets", answer.text.lower())
        self.assertEqual(answer.citations, ())

    def test_metadata_filter_is_data_not_control(self):
        answer = self.pipeline.ask("What is the termination notice?", {"contract_type": "msa"})
        self.assertTrue(answer.supported)
        self.assertEqual(answer.citations[0].document_id, "msa-001")


if __name__ == "__main__":
    unittest.main()
