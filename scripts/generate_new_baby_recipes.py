"""Rebuild the native roster data from Astra's reviewed local art exports."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/garden-babies/new-five-2026-11-09"
NAMES = ("tikket", "nuum", "vezzi", "kiprik", "nolli")


def module(data, description):
    return description + '\nreturn game:GetService("HttpService"):JSONDecode([=[' + json.dumps(data, separators=(",", ":")) + ']=])\n'


def main():
    recipes = {}
    maps = json.loads((SOURCE / "portraits.json").read_text(encoding="utf-8"))["maps"]
    for name in NAMES:
        recipe = json.loads((SOURCE / f"{name}-native.json").read_text(encoding="utf-8"))
        assert recipe["schema"] == 1 and recipe["axes"]["front"] == "+Z"
        assert len(maps[name]) == 13 and all(len(row) == 13 for row in maps[name])
        assert {"Body", "Head", "FootL", "FootR", "HandL", "HandR", "MouthO", "CharmDot"} <= {p["name"] for p in recipe["pieces"]}
        recipes[recipe["legacyId"]] = recipe
    (ROOT / "src/shared/NewBabyRigDefinitions.lua").write_text(module(recipes, "-- Astra-authored replacement babies; generated from the reviewed schema-1 native recipes."), encoding="utf-8")
    (ROOT / "src/shared/NewBabyPortraitDefinitions.lua").write_text(module(maps, "-- Astra-authored thirteen-pixel replacement silhouettes; stable profile IDs route in PetPortrait."), encoding="utf-8")
    print("Generated five semantic native rigs and five thirteen-pixel portraits.")


if __name__ == "__main__":
    main()
