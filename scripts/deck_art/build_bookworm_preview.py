"""Bookworm faceplate review sheet: the texture, the composed deck next to Honey (the plate it
replaces as a placeholder) and Scout, the shop tile size and a 48 px book thumbnail.

Run after build_faceplates.py: python scripts/deck_art/build_bookworm_preview.py
Writes artifacts/v1-art/bookworm-faceplate-preview.png
"""
from __future__ import annotations

import json

from PIL import Image

from build_shell import PAD, compose_deck
from common import ASSETS, ROOT, Cv, hx, ui_theme, TEXT, SOFT, DIM

OUT = ROOT / "artifacts" / "v1-art" / "bookworm-faceplate-preview.png"


def deck(p, k):
    tex = Image.open(ASSETS / "faceplates" / p["texture"])
    return compose_deck(tex, accent=p["accent"], ink=p["ink"], band_tint=p["band"]["tint"], k=k,
                        engrave=(p["engrave"]["color"], p["engrave"]["opacity"]))


def main():
    plates = {p["id"]: p for p in json.loads((ASSETS / "faceplates" / "faceplates.json").read_text())["faceplates"]}
    worm = plates["bookworm"]
    th = ui_theme(worm["accent"], worm["deep"])
    cv = Cv(1900, 1240, z=1, bg=hx("#0B0C10"))
    cv.text(40, 28, "Bookworm faceplate (collection book reward)", "xb", 36, TEXT)
    cv.text(40, 76, "Teal cloth-bound cover, blind-stamped double rule with a gold line, gold corner protectors, rust ribbon bookmark, paper band, gold-stamped wordmark.", "r", 19, SOFT)
    big = deck(worm, 0.62)
    cv.paste(big, 40 - PAD * 0.62 + 20, 120 - PAD * 0.62 + 10, raw=True)
    tex = Image.open(ASSETS / "faceplates" / worm["texture"]).resize((512, 249), Image.LANCZOS)
    cv.paste(tex, 1100, 140, raw=True)
    cv.text(1100, 400, "texture 1024 x 499 (shown at half size)", "r", 16, DIM)
    # tint chips
    cx, ty = 1100, 440
    cv.rr(cx, ty, 520, 48, 12, fill=th["panel"], stroke=(255, 255, 255, 36))
    for i, key in enumerate(("raised", "well", "selected")):
        cv.rr(cx + 10 + i * 90, ty + 10, 80, 28, 8, fill=th[key])
    cv.rr(cx + 290, ty + 10, 220, 28, 8, fill=th["accent"])
    cv.text(cx + 400, ty + 24, "Primary", "b", 16, th["ink"], "mm")
    cv.text(cx, ty + 60, f"accent {worm['accent']}  deep {worm['deep']}  band {worm['band']['tint']}  ui panel {worm['ui']['panel']}", "r", 16, DIM)
    # side by side at shop-pane size with honey and scout
    y = 640
    cv.text(40, y, "Next to Honey (old placeholder) and Scout, at the Deck style pane size", "b", 22, TEXT)
    for i, pid in enumerate(("bookworm", "honey", "sherbet")):
        d = deck(plates[pid], 0.30)
        cv.paste(d, 40 + i * 540 - PAD * 0.30 + 10, y + 40 - PAD * 0.30 + 10, raw=True)
        cv.text(60 + i * 540, y + 300, plates[pid]["name"], "b", 20, TEXT)
    # small sizes: shop tile (88 wide) and book thumbnail (48 tall well)
    y = 1000
    cv.text(40, y, "Shop tile (88 px wide) and collection book thumbnail (96 x 48)", "b", 22, TEXT)
    for i, pid in enumerate(("bookworm", "honey", "sherbet", "aqua_pop", "copperleaf")):
        full = deck(plates[pid], 0.30)
        crop = full.crop((round(PAD * .3), round(PAD * .3), full.width - round(PAD * .3), full.height - round(PAD * .3)))
        d = crop.resize((88, 44), Image.LANCZOS)
        cv.paste(d, 40 + i * 150, y + 50, raw=True)
        t = crop.resize((96, 48), Image.LANCZOS)
        cv.rr(900 + i * 150 - 6, y + 44, 108, 60, 10, fill=th["well"])
        cv.paste(t, 900 + i * 150, y + 50, raw=True)
    cv.out().save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
