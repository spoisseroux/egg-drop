"""Contact sheet: every faceplate (16 shop plates + book-only Bookworm) on the Slim shell, with the UI tint each one produces.

Run after build_shell.py and build_faceplates.py: python scripts/deck_art/build_previews.py
"""
from __future__ import annotations

import json

from PIL import Image

from build_shell import PAD, compose_deck
from common import ASSETS, MOCKUPS, Cv, hx, icon, ui_theme, TEXT, SOFT, DIM, STAR

K = 0.40
CW, CH = 760, 520


def main():
    doc = json.loads((ASSETS / "faceplates" / "faceplates.json").read_text())
    plates = doc["faceplates"]
    rows = (len(plates) + 3) // 4
    cv = Cv(CW * 4 + 80, CH * rows + 150, z=1, bg=hx("#0B0C10"))
    cv.text(40, 30, f"Pocket Deck Slim: {len(plates)} faceplates", "xb", 40, TEXT)
    cv.text(40, 82, "Starter plates are the 8 existing deck styles. New plates cost 20 / 40 / 80 Stars (common / rare / showcase). The chip row is the UI tint each plate produces.", "r", 20, SOFT)
    for i, p in enumerate(plates):
        x, y = 40 + (i % 4) * CW, 130 + (i // 4) * CH
        tex = Image.open(ASSETS / "faceplates" / p["texture"])
        deck = compose_deck(tex, accent=p["accent"], ink=p["ink"], band_tint=p["band"]["tint"], k=K, engrave=(p["engrave"]["color"], p["engrave"]["opacity"]))
        cv.paste(deck, x + (CW - deck.width) / 2, y - PAD * K + 20, raw=True)
        th = ui_theme(p["accent"], p["deep"])
        ty = y + 800 * K + 44
        cv.text(x + 40, ty, p["name"], "b", 26, TEXT)
        tier = p["tier"].upper()
        label = tier if p["priceStars"] == 0 else f"{tier}  {p['priceStars']}"
        tw = cv.tw(label, "b", 15, 1) + (46 if p["priceStars"] else 24)
        cv.rr(x + CW - 40 - tw, ty + 2, tw, 30, 15, fill=th["raised"], stroke=(255, 255, 255, 36))
        if p["priceStars"]:
            icon(cv, "star", x + CW - 40 - tw + 20, ty + 17, 18)
        cv.text(x + CW - 40 - 12, ty + 17, label, "b", 15, hx(STAR) if p["priceStars"] else hx(DIM), "rm", tracking=1)
        # tint chips: panel, raised, well, accent button
        cx = x + 40
        cv.rr(cx, ty + 42, 330, 40, 12, fill=th["panel"], stroke=(255, 255, 255, 36))
        cv.rr(cx + 8, ty + 50, 70, 24, 8, fill=th["raised"])
        cv.rr(cx + 86, ty + 50, 70, 24, 8, fill=th["well"])
        cv.rr(cx + 164, ty + 50, 158, 24, 8, fill=th["accent"])
        cv.text(cx + 243, ty + 62, "Primary", "b", 15, th["ink"], "mm")
        cv.text(cx + 344, ty + 62, f"{p['accent']}  ·  {p['finish']}", "r", 16, DIM, "lm")
    MOCKUPS.mkdir(parents=True, exist_ok=True)
    cv.out().save(MOCKUPS / "faceplates-contact-sheet.png")
    scout = plates[0]
    compose_deck(Image.open(ASSETS / "faceplates" / scout["texture"]), accent=scout["accent"], ink=scout["ink"], k=0.64).save(ASSETS / "shell" / "preview-scout.png")


if __name__ == "__main__":
    main()
