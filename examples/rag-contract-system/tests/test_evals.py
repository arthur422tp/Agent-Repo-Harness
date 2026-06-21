from pathlib import Path
import unittest

from contract_rag.cli import evaluate_cases


ROOT = Path(__file__).resolve().parents[1]


class EvaluationTests(unittest.TestCase):
    def test_all_fixed_cases_pass(self):
        failures = evaluate_cases(ROOT / "evals" / "cases.json", ROOT / "data" / "contracts")
        self.assertEqual(failures, [])


if __name__ == "__main__":
    unittest.main()
