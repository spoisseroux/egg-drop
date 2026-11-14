"""Collection book picture cards, as BookView.buildCards lays them out (v1 track D review).

Concept render, not a Studio capture: the grid of each page at 1:1 on the desktop pane
(488 px grid, 3 columns of 154 x 84; discoveries 2 columns) and on the 812 x 354 phone
sheet (536 px grid), with the house palette, Builder Sans 14 / 12 px names, owned cards
raised with a check, missing cards on the well with a silhouette (atlas) or a veil (live
balls and mini decks). Balls use the LCD mirror in build_round_items_mockups.

Run after build_book_atlas.py: python scripts/deck_art/build_book_mockup.py
Writes artifacts/v1-art/book-cards-desktop.png and book-cards-phone.png (each also @2x).
"""
from __future__ import annotations

import json
import os

from PIL import Image, ImageDraw

import build_round_items_mockups as R
from build_shell import PAD, compose_deck
from common import ASSETS, ROOT, font, hx

ART = ROOT / "artifacts" / "v1-art"
BOOK = ROOT / "assets" / "ui" / "book"
PANEL, RAISED, WELL, LINE = hx("#152525"), hx("#213335"), hx("#0D1818"), (141, 190, 172)
TEXT, SOFT, ACCENT, STARS, BOOKTINT = hx("#F3F4F6"), hx("#C3C8D0"), hx("#76F6B0"), hx("#FFC14D"), hx("#7FE0C8")
THUMB, WELL_H, NAME_H, GAP = 48, 52, 18, 8
CARD_H = 6 + WELL_H + 3 + NAME_H + 5

BALL_THEMES = [("gumdrops", "gumdrop", "Gumdrops"), ("gems", "gem", "Gems"), ("planets", "planet", "Planets"), ("kittens", "kitten", "Kittens")]
PLATES = ["aqua_pop", "lime_gel", "sorbet_sky", "liquid_chrome", "tidepool", "aurora_glass", "prism_flare", "night_orb"]
WEAR = [("beanie", "Pom Beanie"), ("sunhat", "Tiny Sun Hat"), ("flowercrown", "Flower Crown"), ("tee", "Stripy Tee"), ("hoodie", "Star Hoodie"),
        ("beads", "Pearl Beads"), ("bellcollar", "Bell Collar"), ("ring", "Little Hoops"), ("starstud", "Star Studs"), ("sparkle", "Sparkle Eyes"),
        ("sleepy", "Sleepy Eyes"), ("blep", "Blep"), ("heart", "Heart Tail")]
TOYS = [("toy:ball", "Ball"), ("toy:bone", "Bone"), ("toy:sparkler", "Sparkler"), ("finish:gloss", "Gloss"), ("finish:matte", "Matte")]
DISC = [("tier_five", "Make a tier V ball"), ("chain_five", "Chain 5 merges"), ("win_bank_pair", "Win a Bank pair field"),
        ("win_creek_crossing", "Win a Creek crossing field"), ("win_lantern_chain", "Win a Lantern chain field"),
        ("win_ripple_relay", "Win a Ripple relay field"), ("win_bank_bounce", "Win a Bank bounce field"),
        ("win_mirror_marks", "Win a Mirror marks field"), ("win_easy", "Win on Easy"), ("win_medium", "Win on Medium"), ("win_hard", "Win on Hard")]


def atlas_cell(sid, owned):
    doc = json.loads((BOOK / "book-atlas.json").read_text())
    atlas = Image.open(BOOK / "book-atlas.png")
    n = doc["slots"][sid] - 1
    col, row = n % doc["columns"], n // doc["columns"] + (0 if owned else doc["silhouetteRowOffset"])
    c = doc["cell"]
    im = atlas.crop((col * c, row * c, col * c + c, row * c + c)).resize((THUMB, THUMB), Image.LANCZOS)
    if not owned:
        tint = Image.new("RGBA", im.size, LINE + (0,))
        tint.putalpha(im.getchannel("A").point(lambda v: int(v * 0.55)))
        im = tint
    return im


def plate_thumb(pid, w):
    plates = {p["id"]: p for p in json.loads((ASSETS / "faceplates" / "faceplates.json").read_text())["faceplates"]}
    p = plates[pid]
    full = compose_deck(Image.open(ASSETS / "faceplates" / p["texture"]), accent=p["accent"], ink=p["ink"], band_tint=p["band"]["tint"], k=0.3,
                        engrave=(p["engrave"]["color"], p["engrave"]["opacity"]), shadow=False)
    m = round(PAD * 0.3)
    return full.crop((m, m, full.width - m, full.height - m)).resize((w, w // 2), Image.LANCZOS)


def ball_strip(theme, w, h, owned):
    sprites = [R.sprite(t, theme, "idle" if owned else "sleepy", px=1, pad=0, bloom=False) for t in (1, 3, 5)]
    total = sum(s.width for s in sprites)
    px = min((h - 4) / sprites[-1].height, (w - 12 - 8) / total)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    x = (w - (total * px + 8)) / 2
    for s in sprites:
        im = s.resize((max(1, round(s.width * px)), max(1, round(s.height * px))), Image.NEAREST)
        out.alpha_composite(im, (round(x), round(h - 2 - im.height)))
        x += im.width + 4
    return out


def grid(title, items, width, cols, phone, z=1):
    cw = (width - 8 - (cols - 1) * GAP) // cols
    rows = (len(items) + cols - 1) // cols
    H = 40 + rows * (CARD_H + GAP)
    im = Image.new("RGBA", (width * z, H * z), PANEL)
    d = ImageDraw.Draw(im)
    S = lambda v: round(v * z)
    d.text((0, S(8)), title, fill=TEXT, font=font("b", 18 * z))
    fn = font("r", (12 if phone else 14) * z)
    for i, it in enumerate(items):
        x, y = (i % cols) * (cw + GAP), 40 + (i // cols) * (CARD_H + GAP)
        owned = it["owned"]
        d.rounded_rectangle([S(x), S(y), S(x + cw), S(y + CARD_H)], S(10), fill=RAISED if owned else WELL,
                            outline=(BOOKTINT if owned and it.get("disc") else (255, 255, 255, 30)), width=S(2) if owned and it.get("disc") else max(1, z))
        ww = cw - 12
        d.rounded_rectangle([S(x + 6), S(y + 6), S(x + 6 + ww), S(y + 6 + WELL_H)], S(8), fill=WELL)
        pic = it["pic"](ww, WELL_H)
        if z != 1:
            pic = pic.resize((pic.width * z, pic.height * z), Image.NEAREST if it.get("pixel") else Image.LANCZOS)
        px_ = S(x + 6) + (S(ww) - pic.width) // 2
        py_ = S(y + 6) + (S(WELL_H) - pic.height) // 2
        im.alpha_composite(pic, (px_, py_))
        if not owned and it.get("veil"):
            veil = Image.new("RGBA", (S(ww), S(WELL_H)), WELL[:3] + (166,))
            m = Image.new("L", veil.size, 0)
            ImageDraw.Draw(m).rounded_rectangle([0, 0, veil.width - 1, veil.height - 1], S(8), fill=166)
            veil.putalpha(m)
            im.alpha_composite(veil, (S(x + 6), S(y + 6)))
            d = ImageDraw.Draw(im)
        name = it["name"]
        maxw = S(cw - 16 - (22 if owned else 0))
        while d.textlength(name, font=fn) > maxw and len(name) > 2:
            name = name[:-2] + "…"
        d.text((S(x + 8), S(y + 6 + WELL_H + 3 + NAME_H / 2)), name, fill=TEXT if owned else SOFT[:3] + (217,), font=fn, anchor="lm")
        if owned:
            cx, cy = S(x + cw - 14), S(y + 6 + WELL_H + 3 + NAME_H / 2)
            if it.get("disc"):
                R_ = S(7)
                from build_book_atlas import star
                star(d, cx, cy, R_, STARS, k=0.45)
            else:
                d.line([(cx - S(5), cy), (cx - S(1), cy + S(4)), (cx + S(6), cy - S(4))], fill=ACCENT, width=S(2.5), joint="curve")
    return im


def pages(phone, z=1):
    width = 536 if phone else 488
    cols = 3
    owned_balls = {"gumdrops", "planets"}
    out = []
    out.append(grid("Balls (live JellySprite balls, tiers I / III / V)", [
        {"name": n, "owned": tid in owned_balls, "veil": True, "pixel": True, "pic": (lambda w, h, t=th, o=tid in owned_balls: ball_strip(t, w, h, o))}
        for tid, th, n in BALL_THEMES], width, cols, phone, z))
    owned_plates = set(PLATES[:5])
    out.append(grid("Faceplates (Deck style mini deck)", [
        {"name": p.replace("_", " ").title(), "owned": p in owned_plates, "veil": True, "pic": (lambda w, h, p=p: plate_thumb(p, min(2 * (h - 4), w - 12)))}
        for p in PLATES], width, cols, phone, z))
    owned_w = {"beanie", "tee", "beads", "sparkle", "heart"}
    out.append(grid("Wardrobe (atlas: Bear renders)", [
        {"name": n, "owned": i in owned_w, "pic": (lambda w, h, i=i: atlas_cell("pip:" + i, i in owned_w))} for i, n in WEAR], width, cols, phone, z))
    owned_t = {"toy:ball", "finish:matte"}
    out.append(grid("Toys and finishes (atlas)", [
        {"name": n, "owned": i in owned_t, "pic": (lambda w, h, i=i: atlas_cell(i, i in owned_t))} for i, n in TOYS], width, cols, phone, z))
    owned_d = {"tier_five", "win_bank_pair", "win_easy", "win_medium"}
    out.append(grid("Discoveries (atlas badges)", [
        {"name": n, "owned": i in owned_d, "disc": True, "pic": (lambda w, h, i=i: atlas_cell(i, i in owned_d))} for i, n in DISC], width, 2, phone, z))
    W = max(p.width for p in out) + 48 * z
    H = sum(p.height for p in out) + 24 * z * (len(out) + 1)
    sheet = Image.new("RGBA", (W, H), hx("#0B0C10"))
    y = 24 * z
    for p in out:
        sheet.alpha_composite(p, (24 * z, y))
        y += p.height + 24 * z
    return sheet


def main():
    ART.mkdir(parents=True, exist_ok=True)
    for phone, name in ((False, "desktop"), (True, "phone")):
        pages(phone).save(ART / f"book-cards-{name}.png")
        pages(phone, 2).save(ART / f"book-cards-{name}@2x.png")
    print(ART)


if __name__ == "__main__":
    main()
