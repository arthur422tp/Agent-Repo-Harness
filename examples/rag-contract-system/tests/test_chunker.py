import tempfile
import unittest
from pathlib import Path

from contract_rag.chunker import chunk_document
from contract_rag.loader import load_document


SAMPLE_DOCUMENT = """---
document_id: sample-001
title: Sample Agreement
contract_type: msa
jurisdiction: US
---
# Termination
Either party may terminate this Agreement with 30 days written notice.

## Effect
Accrued payment obligations survive termination.
"""


class ChunkerTest(unittest.TestCase):
    def write_document(self, content: str = SAMPLE_DOCUMENT) -> Path:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        path = Path(directory.name) / "sample.md"
        path.write_text(content, encoding="utf-8")
        return path

    def test_load_document_parses_metadata_and_preserves_content(self) -> None:
        document = load_document(self.write_document())

        self.assertEqual(document.document_id, "sample-001")
        self.assertEqual(document.metadata["contract_type"], "msa")
        self.assertIn("# Termination", document.content)

    def test_chunk_document_uses_headings_and_nonempty_text(self) -> None:
        chunks = chunk_document(load_document(self.write_document()))

        self.assertEqual([chunk.heading for chunk in chunks], ["Termination", "Effect"])
        self.assertEqual([chunk.ordinal for chunk in chunks], [0, 1])
        self.assertTrue(all(chunk.text for chunk in chunks))

    def test_chunk_document_is_deterministic(self) -> None:
        document = load_document(self.write_document())

        first = chunk_document(document)
        second = chunk_document(document)

        self.assertEqual(first, second)
        self.assertEqual(
            [chunk.chunk_id for chunk in first],
            ["sample-001:000", "sample-001:001"],
        )

    def test_missing_document_id_is_rejected(self) -> None:
        content = SAMPLE_DOCUMENT.replace("document_id: sample-001\n", "")

        with self.assertRaisesRegex(ValueError, "document_id"):
            load_document(self.write_document(content))


if __name__ == "__main__":
    unittest.main()
