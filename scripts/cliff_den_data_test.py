"""CliffDenData is current: generated from the beta outputs and stamped against today's live WorldV7Data and walk map
(a live re-export without a beta rebuild makes it stale). Run: python scripts/cliff_den_data_test.py"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import cliff_den_data  # noqa: E402


class CliffDenDataCurrent(unittest.TestCase):
    def test_module_matches_the_beta_outputs_and_the_live_island(self):
        self.assertEqual(cliff_den_data.main(["--check"]), 0)


if __name__ == "__main__":
    unittest.main()
