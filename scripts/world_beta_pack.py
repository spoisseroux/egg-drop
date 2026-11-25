"""Bind the beta overlay pack (assets/world/WorldBeta.rbxm) to its proof and to CliffDenData; never sign one implicitly.

The pack is built in Studio Edit and exported (CLIFF-DEN-BUILD, artifacts/qa-2026-11-25-beta17); this check is the guard:

  python scripts/world_beta_pack.py --check

It fails unless
  * assets/world/world-beta-native.json names the pack and its exact bytes (length and sha256);
  * the proof's version is CliffDenData.version (a pack built from older outputs never ships: the server would also refuse
    it at start, CliffDenSwap.apply, but the live island would then silently stand on the beta);
  * the proof counts exactly the parts CliffDenData shows (every swap and pocket `show`);
  * default.project.json mounts ServerStorage.WorldBeta from the pack and launch.project.json never does (live).
"""
from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PACK = "assets/world/WorldBeta.rbxm"
PROOF = "assets/world/world-beta-native.json"
DATA = "src/shared/CliffDenData.lua"


def cliff_den_data(root: Path) -> dict:
    text = (root / DATA).read_text(encoding="utf-8")
    return json.loads(re.search(r"\[=\[(.*)\]=\]", text, re.S).group(1))


def shows(data: dict) -> set:
    return {p["show"] for p in data["swap"] + data["pocket"] if p.get("show")}


def check(root: Path = ROOT) -> list:
    problems = []
    proof = json.loads((root / PROOF).read_text(encoding="utf-8"))
    if proof.get("schemaVersion") != 1 or proof.get("nativePath") != PACK:
        problems.append("unknown proof schema or path")
    native = (root / PACK).read_bytes() if (root / PACK).is_file() else b""
    if len(native) != proof.get("nativeBytes") or hashlib.sha256(native).hexdigest() != proof.get("nativeSha256"):
        problems.append("WorldBeta.rbxm bytes differ from the proof")
    data = cliff_den_data(root)
    if proof.get("version") != data.get("version"):
        problems.append(f"proof version {proof.get('version')} is not CliffDenData.version {data.get('version')}")
    if proof.get("parts") != len(shows(data)):
        problems.append(f"proof counts {proof.get('parts')} parts, CliffDenData shows {len(shows(data))}")
    if data.get("pack") != "WorldBeta":
        problems.append("CliffDenData.pack is not WorldBeta")
    beta = json.loads((root / "default.project.json").read_text(encoding="utf-8-sig"))["tree"]["ServerStorage"]
    if beta.get("WorldBeta") != {"$path": PACK}:
        problems.append("default.project.json must mount ServerStorage.WorldBeta from the pack exactly")
    live = json.loads((root / "launch.project.json").read_text(encoding="utf-8-sig"))
    if PACK in json.dumps(live) or "WorldBeta" in json.dumps(live):
        problems.append("launch.project.json (live) must never mount the beta pack")
    return problems


def main(argv) -> int:
    if "--check" not in argv:
        print(__doc__)
        return 2
    problems = check()
    if problems:
        print("WorldBeta pack STALE:\n  " + "\n  ".join(problems))
        return 1
    print("WorldBeta pack PASS", json.loads((ROOT / PROOF).read_text(encoding="utf-8"))["nativeSha256"])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
