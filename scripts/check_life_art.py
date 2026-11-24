"""The publish gate for the garden life round 3 and nest textures (GARDEN-LIFE-NEST-BUILD-PLAN section 1).

    python scripts/check_life_art.py            fails (exit 1) on any problem, including an id still nil
    python scripts/check_life_art.py --draft    the same checks, but nil ids are listed, not failed
    python scripts/check_life_art.py r4 [--draft]   the beta 14 table instead: src/shared/LifeArtR4.lua (12 rows),
                                                    artifacts/qa-2026-11-23-beta14/look/, draw_garden_life_r4_textures.py

Reads src/shared/LifeArt.lua (one `key=f("file",id,fallback)` row a line) and checks:
  1. every file exists in artifacts/qa-2026-11-23-beta12/look/;
  2. every file is byte-identical to what scripts/draw_garden_life_r3_textures.py draws now (run into a temp folder);
  3. every id is an uploaded rbxassetid (none still nil), and no two rows share an id.
"""
from __future__ import annotations

import contextlib
import importlib.util
import io
import re
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "src/shared/LifeArt.lua"
LOOK = ROOT / "artifacts/qa-2026-11-23-beta12/look"
DRAW = ROOT / "scripts/draw_garden_life_r3_textures.py"
ROWS = 21
if "r4" in sys.argv:
    ART = ROOT / "src/shared/LifeArtR4.lua"
    LOOK = ROOT / "artifacts/qa-2026-11-23-beta14/look"
    DRAW = ROOT / "scripts/draw_garden_life_r4_textures.py"
    ROWS = 12
ROW = re.compile(r'^\s*(\w+)=f\("([^"]+)",(nil|"rbxassetid://\d+"),')


def rows() -> list[tuple[str, str, str | None]]:
    out = []
    for line in ART.read_text(encoding="utf-8").splitlines():
        match = ROW.match(line)
        if match:
            key, file, uid = match.groups()
            out.append((key, file, None if uid == "nil" else uid.strip('"')))
    return out


def drawn(names: list[str]) -> dict[str, bytes]:
    """Runs the draw script into a temp folder and returns the bytes of each named file."""
    spec = importlib.util.spec_from_file_location("draw_r3", DRAW)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    with tempfile.TemporaryDirectory() as temp:
        module.OUT = Path(temp)
        with contextlib.redirect_stdout(io.StringIO()):
            module.main()
        return {name: (Path(temp) / name).read_bytes() for name in names if (Path(temp) / name).exists()}


def main() -> int:
    draft = "--draft" in sys.argv
    table = rows()
    problems, pending = [], []
    if len(table) != ROWS:
        problems.append(f"{ART.name} has {len(table)} rows, want {ROWS}")
    for key, file, uid in table:
        if not (LOOK / file).exists():
            problems.append(f"{key}: {file} missing from {LOOK.relative_to(ROOT)}")
        if uid is None:
            pending.append(key)
    fresh = drawn([file for _, file, _ in table])
    for key, file, _ in table:
        if file not in fresh:
            problems.append(f"{key}: the draw script no longer makes {file}")
        elif (LOOK / file).exists() and (LOOK / file).read_bytes() != fresh[file]:
            problems.append(f"{key}: {file} differs from the draw script's output (redraw before uploading)")
    ids = [uid for _, _, uid in table if uid]
    if len(ids) != len(set(ids)):
        problems.append("two rows share an uploaded id")
    for line in problems:
        print("FAIL", line)
    if pending:
        print(("PENDING " if draft else "FAIL pending upload: ") + ", ".join(pending))
    ok = not problems and (draft or not pending)
    print("OK" if ok else "NOT READY", f"({len(table)} rows, {len(pending)} pending)")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
