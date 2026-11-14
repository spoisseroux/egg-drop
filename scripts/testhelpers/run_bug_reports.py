"""Run real Luau report specs with a local script stub for UICopy; no services."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
generated = ROOT / "build" / "reports-offline-uicopy.luau"
generated.parent.mkdir(exist_ok=True)
generated.write_text(
    "-- Generated offline wrapper; real source follows unchanged.\n"
    "local script={Parent={}}\n" + (ROOT / "src/shared/UICopy.lua").read_text(encoding="utf-8"),
    encoding="utf-8",
)
result = subprocess.run(
    [str(ROOT / "build/luau-cli/luau.exe"), "scripts/testhelpers/BugReportsOffline.luau"],
    cwd=ROOT,
)
raise SystemExit(result.returncode)
