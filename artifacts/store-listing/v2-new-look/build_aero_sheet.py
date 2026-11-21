"""Contact sheet: the three Frutiger Aero faceplates on the Pocket Deck Slim shell, next to Aqua Pop.

Run after `python scripts/deck_art/build_faceplates.py cloud_glass lagoon dewy_meadow`:
    python artifacts/store-listing/v2-new-look/build_aero_sheet.py
Writes aero-faceplates.png beside this file. The deck is the repo's own shell mock-up (build_shell.compose_deck),
not a Studio capture: it shows the plate art, not the final in-game render.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "deck_art"))
from build_shell import PAD, compose_deck  # noqa: E402

SHOW = ["aqua_pop", "cloud_glass", "lagoon", "dewy_meadow"]
NOTE = {"aqua_pop": "existing, for comparison", "cloud_glass": "new: the ad hero", "lagoon": "new", "dewy_meadow": "new"}
K = 0.56
CW, CH = 1040, 640
PRICE = {"starter": 0, "common": 40, "rare": 100, "showcase": 250, "book": 0}   # the live ladder (DeckThemes.lua)


def font(name, px):
    for f in (name, "Nunito-Black.ttf", "arialbd.ttf"):
        try:
            return ImageFont.truetype(str(Path(r"C:\Windows\Fonts") / f), px)
        except OSError:
            pass
    return ImageFont.load_default()


def main():
    plates = {p["id"]: p for p in json.loads((ROOT / "assets/deck/faceplates/faceplates.json").read_text())["faceplates"]}
    W, H = CW * 2 + 80, CH * 2 + 150
    t = np.linspace(0, 1, H, dtype=np.float32)[:, None, None]
    top, bot = np.array([10, 107, 224], np.float32), np.array([111, 208, 255], np.float32)      # Dewdrop Sky field
    sheet = Image.fromarray(np.broadcast_to(top + (bot - top) * t, (H, W, 3)).astype(np.uint8), "RGB").convert("RGBA")
    d = ImageDraw.Draw(sheet)
    d.text((48, 30), "aero faceplates", font=font("Nunito-Black.ttf", 54), fill="#FFFFFF")
    d.text((50, 98), "three new Pocket Deck plates beside Aqua Pop. plate art on the shell mock-up, not a Studio capture.",
           font=font("Quicksand-Bold.ttf", 24), fill="#DDF1FF")
    for i, pid in enumerate(SHOW):
        p = plates[pid]
        x, y = 40 + (i % 2) * CW, 140 + (i // 2) * CH
        tex = Image.open(ROOT / "assets/deck/faceplates" / p["texture"])
        deck = compose_deck(tex, accent=p["accent"], ink=p["ink"], band_tint=p["band"]["tint"], k=K,
                            engrave=(p["engrave"]["color"], p["engrave"]["opacity"]))
        sheet.alpha_composite(deck, (round(x + (CW - deck.width) / 2), round(y - PAD * K + 28)))
        ty = y + 800 * K + 58
        d.text((x + 70, ty), p["name"].lower(), font=font("Nunito-Black.ttf", 40), fill="#FFFFFF")
        price = PRICE[p["tier"]]
        d.text((x + 72, ty + 52), f"{p['tier']} · {price} stars · {NOTE[pid]}", font=font("Quicksand-Bold.ttf", 24), fill="#DDF1FF")
    sheet.convert("RGB").save(HERE / "aero-faceplates.png")
    print("wrote", HERE / "aero-faceplates.png", sheet.size)


if __name__ == "__main__":
    main()
