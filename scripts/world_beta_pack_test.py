"""world_beta_pack.py: the committed pack passes; a changed byte, a stale version or a live mount fails."""
import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import world_beta_pack as pack  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
FILES = [pack.PACK, pack.PROOF, pack.DATA, "default.project.json", "launch.project.json"]


class WorldBetaPackTest(unittest.TestCase):
    def copy(self):
        tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, tmp)
        for name in FILES:
            (tmp / name).parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, tmp / name)
        return tmp

    def test_committed_pack_passes(self):
        self.assertEqual(pack.check(ROOT), [])

    def test_a_changed_byte_fails(self):
        tmp = self.copy()
        data = bytearray((tmp / pack.PACK).read_bytes())
        data[-1] ^= 1
        (tmp / pack.PACK).write_bytes(bytes(data))
        self.assertTrue(any("bytes" in p for p in pack.check(tmp)))

    def test_a_stale_version_fails(self):
        tmp = self.copy()
        proof = json.loads((tmp / pack.PROOF).read_text())
        proof["version"] = "0000000000000000"
        (tmp / pack.PROOF).write_text(json.dumps(proof))
        self.assertTrue(any("version" in p for p in pack.check(tmp)))

    def test_live_never_mounts_it(self):
        tmp = self.copy()
        live = json.loads((tmp / "launch.project.json").read_text(encoding="utf-8-sig"))
        live["tree"]["ServerStorage"]["WorldBeta"] = {"$path": pack.PACK}
        (tmp / "launch.project.json").write_text(json.dumps(live))
        self.assertTrue(any("live" in p for p in pack.check(tmp)))


if __name__ == "__main__":
    unittest.main()
