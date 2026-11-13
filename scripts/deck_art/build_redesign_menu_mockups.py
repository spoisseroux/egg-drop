"""Menu and round-look redesign mockups for UI-SPEC-REDESIGN-MENUS-2026-11-12.md.

Run: python scripts/deck_art/build_redesign_menu_mockups.py

Output: artifacts/redesign-2026-11-12/menus/. Every picture is 1:1 (one image pixel = one Roblox offset pixel) at
desktop 1920x1080 and phone 812x354, plus an "@2x" file of the same drawing for zooming.
Desktop menus are the 848x608 Kit panel at UIScale 1.2 (what a 1080p window gets). Phone menus are the Compact sheet,
which starts at kh + 2 = 60 px, under the Roblox controls (as built 2026-11-12).
Concept drawings from the spec's numbers, not Studio captures. The pet and egg art are existing renders.
"""
from __future__ import annotations

import math

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import build_compact_frame_mockups as F
import build_compact_mockups as C
import build_mockups as M
from build_compact_mockups import ASPECT, BEZEL, fit, kit_theme, masked_gradient, roblox_bar
from build_mockups import PLATES, STROKE, button, card, chip, deck_thumb, hints, label, screen_round, backdrop, to_hex_rgba
from build_shell import PAD, compose_deck
from common import ROOT, Cv, gradient, hx, icon, mix, ramp, rounded_mask, star_pts, ui_theme, DANGER, STAR

OUT = ROOT / "artifacts" / "redesign-2026-11-12" / "menus"
DS = 1.2                      # desktop UIScale of the 848x608 panel at 1920x1080
PW, PH = 812, 354             # phone root
TOP = 60                      # sheet / glass top on a phone (kh + 2)
AMBER = "#FFB02E"
PINK = "#FF9EC4"              # the pet's Secondary colour in these mockups

# ------------------------------------------------------------------ art inputs
def _pet():
    im = Image.open(ROOT / "artifacts" / "scope-2026-11-12" / "raw" / "raw-bare-front.png").convert("RGB")
    key = im.copy()
    for xy in ((0, 0), (im.width - 1, 0), (0, im.height - 1), (im.width - 1, im.height - 1)):
        ImageDraw.floodfill(key, xy, (255, 0, 255), thresh=26)
    a = np.asarray(key)
    mask = Image.fromarray((~((a[..., 0] == 255) & (a[..., 1] == 0) & (a[..., 2] == 255)) * 255).astype(np.uint8))
    mask = mask.filter(ImageFilter.MinFilter(5)).filter(ImageFilter.GaussianBlur(1.6))
    out = im.convert("RGBA")
    out.putalpha(mask)
    return out.crop(mask.getbbox())


def _eggs():
    atlas = Image.open(ROOT / "art" / "device-hatch-play-2026-11-09" / "registered-eggs-atlas.png").convert("RGBA")
    out = {}
    for kind, col in (("companion", 0), ("hue", 1), ("material", 2), ("toy", 3), ("feature", 4)):
        cell = atlas.crop((col * 384, 0, col * 384 + 384, 384))
        out[kind] = cell.crop(cell.getbbox())
    return out


PET, EGG = _pet(), _eggs()


def pet(cv, cx, cy, h):
    w = h * PET.width / PET.height
    im = PET.resize((round(w * cv.z), round(h * cv.z)), Image.LANCZOS)
    cv.ell(cx, cy + h * .49, w * .34, h * .045, fill=(0, 0, 0, 70))
    cv.paste(im, (cx - w / 2) * cv.z, (cy - h / 2) * cv.z, raw=True)


def egg3d(cv, kind, cx, cy, h, th):
    """The hatch preview: the egg mid-wobble on a turntable. Runtime: a spinning ViewportFrame model."""
    src = EGG[kind]
    w = h * src.width / src.height
    z = cv.z
    cv.ell(cx, cy + h * .50, w * .46, h * .07, fill=(0, 0, 0, 96))
    box = [(cx - w * .62) * z, (cy + h * .50 - h * .10) * z, (cx + w * .62) * z, (cy + h * .50 + h * .10) * z]
    cv.d.arc(box, 20, 160, fill=th["accent"][:3] + (150,), width=max(1, round(1.6 * z)))
    cv.poly([(cx - w * .60, cy + h * .50 + h * .012), (cx - w * .52, cy + h * .50 + h * .075), (cx - w * .47, cy + h * .50 + h * .01)], th["accent"][:3] + (170,))
    base = src.resize((round(w * z), round(h * z)), Image.LANCZOS)
    ghost = base.rotate(7, Image.BICUBIC, expand=True)
    ghost.putalpha(ghost.getchannel("A").point(lambda v: int(v * .22)))
    cv.paste(ghost, cx * z - ghost.width / 2 + w * .05 * z, cy * z - ghost.height / 2, raw=True)
    main = base.rotate(-8, Image.BICUBIC, expand=True)
    cv.paste(main, cx * z - main.width / 2, cy * z - main.height / 2, raw=True)
    for sx in (-1, 1):                                    # wobble ticks
        for i, (dy, ln) in enumerate(((-.22, .07), (-.05, .10), (.12, .07))):
            x0 = cx + sx * (w * .62 + i % 2 * w * .04)
            cv.line([(x0, cy + h * dy), (x0 + sx * w * ln, cy + h * (dy - .03))], (255, 255, 255, 110), 1.8)


# ------------------------------------------------------------------ small icons (24 grid)
def ico(cv, name, cx, cy, s=24, color=(243, 244, 246, 255)):
    u = s / 24
    w = 2 * u
    P = lambda x, y: (cx + (x - 12) * u, cy + (y - 12) * u)
    L = lambda pts, ww=w: cv.line([P(*p) for p in pts], color, ww)
    if name == "paw":
        cv.ell(*P(12, 15.5), 5.4 * u, 4.4 * u, fill=color)
        for x, y in ((5, 10.5), (9.4, 6), (14.6, 6), (19, 10.5)):
            cv.ell(*P(x, y), 2.3 * u, 2.7 * u, fill=color)
    elif name == "shirt":
        cv.poly([P(*p) for p in ((3.5, 8.5), (9, 4), (12, 7), (15, 4), (20.5, 8.5), (17.8, 12), (16.2, 10.8), (16.2, 20), (7.8, 20), (7.8, 10.8), (6.2, 12))], color)
    elif name == "wand":
        L([(5, 19), (13.5, 10.5)], 2.6 * u)
        cv.poly(star_pts(*P(17, 7), 5.6 * u, .34, 0)[::1] if False else _spark(*P(17, 7), 5.6 * u), color)
        cv.poly(_spark(*P(8, 6.5), 2.6 * u), color)
        cv.poly(_spark(*P(19.5, 16), 2.2 * u), color)
    elif name == "drop":
        pts = [P(12, 3)] + [(cx + 6.6 * u * math.cos(math.radians(a)), cy + 2.4 * u + 6.6 * u * math.sin(math.radians(a))) for a in range(-35, 216, 10)]
        cv.poly(pts, color)
    elif name == "sparkle":
        cv.poly(_spark(*P(11, 12.5), 8.5 * u), color)
        cv.poly(_spark(*P(19, 5.5), 3.2 * u), color)
    elif name == "sphere":
        cv.ell(cx, cy, 8.4 * u, stroke=color, sw=w)
        cv.arc(cx, cy, 5 * u, 190, 275, color, w)
    elif name == "ball":
        cv.ell(cx, cy, 8.4 * u, stroke=color, sw=w)
        cv.arc(cx - 10.5 * u, cy, 9 * u, -46, 46, color, w)
        cv.arc(cx + 10.5 * u, cy, 9 * u, 134, 226, color, w)
    elif name == "none":
        cv.ell(cx, cy, 8.4 * u, stroke=color, sw=w)
        L([(6.3, 17.7), (17.7, 6.3)])
    elif name == "snowflake":
        for a in (90, 30, 150):
            dx, dy = 8.6 * u * math.cos(math.radians(a)), 8.6 * u * math.sin(math.radians(a))
            cv.line([(cx - dx, cy - dy), (cx + dx, cy + dy)], color, 2.6 * u)
    elif name == "ring":
        cv.ell(cx, cy, 7.2 * u, stroke=color, sw=3.4 * u)
    elif name == "pebble":
        cv.poly([(cx + (8.6 + 1.2 * math.sin(3 * t)) * u * math.cos(t), cy + (6.6 + .8 * math.cos(2 * t)) * u * math.sin(t)) for t in np.linspace(0, 2 * math.pi, 40)], color)
    elif name == "pattern":
        cv.rr(cx - 9 * u, cy - 7 * u, 18 * u, 14 * u, 3 * u, stroke=color, sw=w)
        for yy in (10, 14):
            cv.arc(*P(9, yy + 2.2), 2.6 * u, 200, 340, color, 1.6 * u)
            cv.arc(*P(15, yy + 2.2), 2.6 * u, 200, 340, color, 1.6 * u)
    elif name == "chev":
        L([(9, 6), (15, 12), (9, 18)], 2.4 * u)
    else:
        icon(cv, name, cx, cy, s, color, accent=color)


def _spark(cx, cy, r):
    return [(cx + (r if i % 2 == 0 else r * .30) * math.cos(math.radians(i * 45 - 90)), cy + (r if i % 2 == 0 else r * .30) * math.sin(math.radians(i * 45 - 90))) for i in range(8)]


def charm(cv, name, cx, cy, s):
    """A floating charm in the pet's Secondary colour."""
    cv.shadow(cx - s / 2, cy - s / 2, s, s, s / 2, blur=s * .4, color=hx(PINK, 90), dy=0)
    cv.refresh()
    ico(cv, name, cx, cy, s, hx(PINK))


# ------------------------------------------------------------------ shared components
def header(cv, xl, xr, cy, title, th, hh, tsize, stars=128, eyebrow=None, ey=0):
    """THE shared header: title left; Stars capsule and back circle right, both `hh` high, 8 apart."""
    bx = xr - hh
    cv.shadow(bx, cy - hh / 2, hh, hh, hh / 2, blur=7, color=(0, 0, 0, 100), dy=3)
    cv.rr(bx, cy - hh / 2, hh, hh, hh / 2, fill=(21, 23, 27, 235))
    cv.rr(bx, cy - hh / 2, hh, hh, hh / 2, stroke=(255, 255, 255, 60), sw=1.5)
    icon(cv, "back", bx + hh / 2, cy, hh * .5, (243, 244, 246, 255), w=hh * .052)
    fs = 18 if hh >= 44 else 15
    s = f"{stars:,}"
    star = round(hh * .5)
    w = round(cv.tw(s, "monob", fs) + hh * .40 + star + 8 + hh * .42)
    wx = bx - 8 - w
    cv.rr(wx, cy - hh / 2, w, hh, hh / 2, fill=th["well"])
    cv.rr(wx, cy - hh / 2, w, hh, hh / 2, stroke=STROKE, sw=1)
    icon(cv, "star", wx + hh * .40 + star / 2, cy, star)
    cv.text(wx + w - hh * .42, cy + .5, s, "monob", fs, th["text"], "rm")
    if eyebrow:
        label(cv, xl, ey, eyebrow, th)
    cv.text(xl, cy + (4 if eyebrow else 0), title, "b", tsize, th["text"], "lm")
    return wx


def itabs(cv, x, y, w, h, items, sel, th, size):
    """Kit.tabs with an icon before each label."""
    cv.rr(x, y, w, h, h / 2, fill=th["well"])
    cv.rr(x, y, w, h, h / 2, stroke=STROKE, sw=1)
    seg = (w - 8) / len(items)
    for i, (ic, name) in enumerate(items):
        sx = x + 4 + i * seg
        col = th["ink"] if i == sel else th["soft"]
        if i == sel:
            cv.rr(sx, y + 4, seg, h - 8, (h - 8) / 2, fill=th["accent"])
        isz = size + 4
        tw = cv.tw(name, "b", size)
        x0 = sx + (seg - (isz + 7 + tw)) / 2
        assert x0 >= sx + 6, ("icon tab does not fit", name, seg)
        ico(cv, ic, x0 + isz / 2, y + h / 2, isz, col)
        cv.text(x0 + isz + 7, y + h / 2 + .5, name, "b", size, col, "lm")


def tile(cv, x, y, w, h, th, name, status, scol, draw, focus=False, nsize=14, ssize=13, sbold=False):
    cv.rr(x, y, w, h, 12, fill=th["selected"] if focus else th["raised"])
    cv.rr(x, y, w, h, 12, stroke=th["accent"] if focus else STROKE, sw=2 if focus else 1)
    side = h - 20
    cv.rr(x + 10, y + 10, side, side, 10, fill=th["well"])
    cv.rr(x + 10, y + 10, side, side, 10, stroke=STROKE, sw=1)
    draw(x + 10, y + 10, side)
    tx = x + 10 + side + 12
    cv.text(tx, y + h / 2 - 10, fit(cv, name, w - (tx - x) - 8, "b", nsize), "b", nsize, th["text"], "lm")
    if sbold:
        cv.text(tx, y + h / 2 + 11, status.upper(), "b", max(12, ssize - 1), scol, "lm", tracking=.6)
    else:
        cv.text(tx, y + h / 2 + 11, status, "r", ssize, scol, "lm")
    if focus:
        cv.glow_ring(x - 4, y - 4, w + 8, h + 8, 16)


def well(cv, x, y, w, h, th, r=12):
    cv.rr(x, y, w, h, r, fill=th["well"])
    cv.grad_rr(x, y, w, h, r, [(0, th["accent"][:3] + (0,)), (1, th["accent"][:3] + (22,))])
    cv.rr(x, y, w, h, r, stroke=STROKE, sw=1)
    cv.refresh()


def dpanel(th):
    cv = Cv(848, 608, z=DS * 2, bg=th["panel"])
    cv.paste(gradient(cv.im.width, cv.im.height, [(0, (255, 255, 255, 8)), (1, (0, 0, 0, 30))]), 0, 0, raw=True)
    return cv


def psheet(th, title, stars=128):
    """Phone: the Compact menu sheet from y 60 with the shared header (capsule and back both 36)."""
    cv = F.plate_canvas(PW, PH, th)
    h = PH - TOP
    cv.shadow(6, TOP + 6, PW - 12, h - 12, 18, blur=8, color=(0, 0, 0, 150), dy=3, spread=2)
    cv.rr(6, TOP + 6, PW - 12, h - 12, 18, fill=BEZEL)
    cv.rr(8, TOP + 8, PW - 16, h - 16, 16, fill=th["panel"])
    cv.paste(masked_gradient(PW - 16, h - 16, 16, cv.z), 8 * cv.z, (TOP + 8) * cv.z, raw=True)
    cv.rr(8, TOP + 8, PW - 16, h - 16, 16, stroke=STROKE, sw=1)
    cv.line([(20, TOP + 60), (PW - 20, TOP + 60)], (255, 255, 255, 18), 1, False)
    header(cv, 24, PW - 20, TOP + 34, title, th, 36, 20, stars)
    roblox_bar(cv)
    return cv


def save_desktop(cv, th, name):
    for s in (1, 2):
        out = Cv(1920, 1080, z=s, bg=(0, 0, 0, 255))
        out.paste(backdrop(1920, 1080, th).resize((1920 * s, 1080 * s), Image.BILINEAR), 0, 0, raw=True)
        out.rr(0, 0, 1920, 1080, 0, fill=(0, 0, 0, 96))
        w, h = round(848 * DS), round(608 * DS)
        x, y = (1920 - w) // 2, (1080 - h) // 2
        out.shadow(x, y, w, h, 36, blur=30, color=(0, 0, 0, 150), dy=14)
        part = cv.im.resize((w * s, h * s), Image.LANCZOS).convert("RGBA")
        part.putalpha(rounded_mask(w * s, h * s, 36 * s, 2))
        out.paste(part, x * s, y * s, raw=True)
        out.rr(x, y, w, h, 36, stroke=(255, 255, 255, 40), sw=1)
        OUT.mkdir(parents=True, exist_ok=True)
        out.im.convert("RGB").save(OUT / f"{name}-desktop-1920x1080{'@2x' if s == 2 else ''}.png")


def save_phone(cv, name):
    OUT.mkdir(parents=True, exist_ok=True)
    cv.out().convert("RGB").save(OUT / f"{name}-phone-812x354.png")
    cv.im.resize((PW * 2, PH * 2), Image.LANCZOS).convert("RGB").save(OUT / f"{name}-phone-812x354@2x.png")


# ------------------------------------------------------------------ 01 Companions hub
HUB = (("paw", "Pets", "Choose who follows you around the garden", "Zivvi", False),
       ("shirt", "Wardrobe", "Hats, shirts and more, bought with Stars", "3 owned", False),
       ("wand", "Customize", "Hue, charm, materials and toys", "1 new item", True))


def hub_desktop(th, focus=2):
    cv = dpanel(th)
    header(cv, 24, 824, 44, "Companions", th, 44, 26, eyebrow="Garden", ey=14)
    card(cv, 24, 84, 328, 452, th)
    well(cv, 40, 100, 296, 248, th)
    pet(cv, 180, 226, 214)
    charm(cv, "snowflake", 278, 150, 30)
    cv.text(40, 380, "Zivvi", "b", 24, th["text"], "lm")
    chip(cv, 336, 367, "Following", th["well"], th["accent"], 26, anchor="r", stroke=STROKE)
    for i, (k, v) in enumerate((("Wearing", "Nothing yet"), ("Charm", "Snowflake"), ("Finish", "Gloss"), ("Toy", "Ball"))):
        y = 418 + i * 28
        cv.text(40, y, k, "r", 14, th["soft"], "lm")
        cv.text(336, y, v, "m", 14, th["text"], "rm")
        if i < 3:
            cv.line([(40, y + 14), (336, y + 14)], (255, 255, 255, 14), 1, False)
    for i, (ic, title, desc, val, new) in enumerate(HUB):
        x, y, w, h = 368, 84 + i * 156, 456, 140
        f = i == focus
        cv.rr(x, y, w, h, 14, fill=th["selected"] if f else th["raised"])
        cv.rr(x, y, w, h, 14, stroke=th["accent"] if f else STROKE, sw=2 if f else 1)
        cv.ell(x + 60, y + 70, 36, fill=th["accent"] if f else th["well"])
        if not f:
            cv.ell(x + 60, y + 70, 36, stroke=STROKE, sw=1)
        ico(cv, ic, x + 60, y + 70, 36, th["ink"] if f else th["text"])
        cv.text(x + 116, y + 48, title, "b", 22, th["text"], "lm")
        cv.text(x + 116, y + 76, desc, "r", 15, th["soft"], "lm")
        if new:
            cv.ell(x + 121, y + 103, 4, fill=STAR)
        cv.text(x + 116 + (14 if new else 0), y + 103, val.upper(), "b", 12, th["star"] if new else th["dim"], "lm", tracking=.6)
        ico(cv, "chev", x + w - 30, y + 70, 22, th["text"] if f else th["soft"])
        if f:
            cv.glow_ring(x - 4, y - 4, w + 8, h + 8, 18)
    hints(cv, 24, 572, [("+", "Browse"), ("A", "Open"), ("B", "Back")], th, right="Changes save as you make them.")
    return cv


def hub_phone(th, focus=2):
    cv = psheet(th, "Companions")
    card(cv, 20, 124, 200, 210, th)
    well(cv, 32, 136, 176, 130, th)
    pet(cv, 116, 202, 112)
    charm(cv, "snowflake", 172, 160, 18)
    cv.text(32, 286, "Zivvi", "b", 18, th["text"], "lm")
    cv.text(32, 310, "Following you", "r", 12, th["soft"], "lm")
    for i, (ic, title, desc, val, new) in enumerate(HUB):
        x, y, w, h = 232, 124 + i * 73, 560, 64
        f = i == focus
        cv.rr(x, y, w, h, 12, fill=th["selected"] if f else th["raised"])
        cv.rr(x, y, w, h, 12, stroke=th["accent"] if f else STROKE, sw=2 if f else 1)
        cv.ell(x + 36, y + 32, 22, fill=th["accent"] if f else th["well"])
        if not f:
            cv.ell(x + 36, y + 32, 22, stroke=STROKE, sw=1)
        ico(cv, ic, x + 36, y + 32, 24, th["ink"] if f else th["text"])
        cv.text(x + 72, y + 22, title, "b", 16, th["text"], "lm")
        cv.text(x + 72, y + 43, desc, "r", 12, th["soft"], "lm")
        vw = cv.text(x + w - 40, y + 32.5, val.upper(), "b", 12, th["star"] if new else th["soft"], "rm", tracking=.6)
        if new:
            cv.ell(x + w - 40 - vw - 9, y + 32, 3.5, fill=STAR)
        ico(cv, "chev", x + w - 22, y + 32, 18, th["text"] if f else th["soft"])
    return cv


# ------------------------------------------------------------------ 02 Customize (Charm tab)
TABS = (("drop", "Hue"), ("sparkle", "Charm"), ("sphere", "Materials"), ("ball", "Toys"))
CHARMS = (("none", "None", "No charm", "soft", False), ("snowflake", "Snowflake", "Wearing", "accent", True),
          ("ring", "Ring", "Free", "soft", False), ("pebble", "Pebble", "Free", "soft", False))


def _charm_swatch(cv, th, name):
    def draw(x, y, side):
        if name == "none":
            ico(cv, "none", x + side / 2, y + side / 2, side * .58, th["soft"])
        else:
            ico(cv, name, x + side / 2, y + side / 2, side * .58, hx(PINK))
    return draw


def customize_desktop(th, focus=2):
    cv = dpanel(th)
    header(cv, 24, 824, 44, "Customize", th, 44, 26, eyebrow="Companions", ey=14)
    itabs(cv, 24, 84, 800, 44, TABS, 1, th, 16)
    card(cv, 24, 144, 328, 392, th)
    well(cv, 40, 160, 296, 196, th)
    pet(cv, 178, 258, 172)
    charm(cv, CHARMS[focus][0], 266, 200, 34)
    cv.text(40, 386, CHARMS[focus][1], "b", 24, th["text"], "lm")
    chip(cv, 336, 373, "Free", th["well"], hx("#9BE3A8"), 26, anchor="r", stroke=STROKE)
    cv.text(40, 414, "Floats beside Zivvi in its Secondary colour", "r", 14, th["soft"], "lm")
    cv.text(40, 438, "Trying it on. Not saved yet.", "r", 14, th["soft"], "lm")
    button(cv, 40, 464, 288, 56, "Wear", th, "primary", key="A")
    for i, (ic, name, st, col, bold) in enumerate(CHARMS):
        x, y = 371 + (i % 2) * 229, 147 + (i // 2) * 108
        tile(cv, x, y, 217, 96, th, name, st, th[col], _charm_swatch(cv, th, ic), i == focus, 16, 14, bold)
    card(cv, 371, 372, 446, 72, th, "well")
    ico(cv, "drop", 403, 408, 24, hx(PINK))
    cv.text(428, 398, "Charms take Zivvi's Secondary colour.", "m", 14, th["text"], "lm")
    cv.text(428, 419, "Change it on the Hue tab.", "r", 14, th["soft"], "lm")
    hints(cv, 24, 572, [("+", "Browse"), ("LB", "Tab"), ("A", "Wear"), ("B", "Back")], th, right="Charms are free.")
    return cv


def customize_phone(th, focus=2):
    cv = psheet(th, "Customize")
    itabs(cv, 20, 124, 528, 36, TABS, 1, th, 14)
    card(cv, 560, 124, 232, 210, th)
    well(cv, 572, 136, 208, 86, th)
    pet(cv, 666, 180, 76)
    charm(cv, CHARMS[focus][0], 712, 158, 20)
    cv.text(572, 240, CHARMS[focus][1], "b", 18, th["text"], "lm")
    chip(cv, 780, 229, "Free", th["well"], hx("#9BE3A8"), 22, anchor="r", stroke=STROKE, size=12)
    cv.text(572, 261, "In Zivvi's Secondary colour", "r", 12, th["soft"], "lm")
    button(cv, 572, 278, 208, 44, "Wear", th, "primary", size=16)
    for i, (ic, name, st, col, bold) in enumerate(CHARMS):
        x, y = 23 + (i % 2) * 264, 175 + (i // 2) * 72
        tile(cv, x, y, 258, 64, th, name, st, th[col], _charm_swatch(cv, th, ic), i == focus, 14, 13, bold)
    return cv


# ------------------------------------------------------------------ 03 Hatch eggs
EGGS = (("toy", "Toy Egg", 8, "A toy to carry and chase", "Something is rattling around in here. Hatches one toy your pet can carry and play with.",
         "1 toy per egg", (("Ball", "1 in 3"), ("Bone", "1 in 3"), ("Sparkler", "1 in 3"))),
        ("material", "Material Egg", 16, "A new body finish", "", "", ()),
        ("hue", "Hue Egg", 8, "Fruit that shifts colour", "", "", ()))


def hatch_desktop(th, sel=0):
    cv = dpanel(th)
    header(cv, 24, 824, 44, "Hatch eggs", th, 44, 26, eyebrow="Garden", ey=14)
    for i, (kind, name, cost, sub, *_) in enumerate(EGGS):
        x, y, w, h = 24, 84 + i * 84, 328, 72
        f = i == sel
        cv.rr(x, y, w, h, 14, fill=th["selected"] if f else th["raised"])
        cv.rr(x, y, w, h, 14, stroke=th["accent"] if f else STROKE, sw=2 if f else 1)
        cv.text(x + 20, y + 26, name, "b", 18, th["text"], "lm")
        cv.text(x + 20, y + 50, sub, "r", 14, th["soft"], "lm")
        tw = cv.text(x + w - 20, y + 36.5, str(cost), "monob", 18, th["star"], "rm")
        icon(cv, "star", x + w - 20 - tw - 15, y + 36, 18)
        if f:
            cv.glow_ring(x - 4, y - 4, w + 8, h + 8, 18)
    cv.wrap(28, 348, "Every egg lists its exact odds before you hatch it.", 320, "r", 14, th["dim"], 19, 2)
    kind, name, cost, _, desc, per, odds = EGGS[sel]
    card(cv, 368, 84, 456, 452, th)
    well(cv, 384, 100, 424, 152, th)
    egg3d(cv, kind, 596, 170, 116, th)
    cv.text(384, 280, name, "b", 24, th["text"], "lm")
    chip(cv, 808, 267, str(cost), mix(th["well"], STAR, .14), hx(STAR), 26, "star", anchor="r")
    cv.wrap(384, 298, desc, 424, "r", 15, th["soft"], 20, 2)
    label(cv, 384, 352, "Odds", th)
    label(cv, 808, 352, per, th, anchor="ra")
    for i, (n, o) in enumerate(odds):
        y = 372 + i * 28
        cv.rr(384, y, 424, 24, 6, fill=th["well"])
        cv.text(396, y + 12.5, n, "r", 15, th["text"], "lm")
        cv.text(796, y + 12.5, o, "monob", 15, th["text"], "rm")
    button(cv, 384, 464, 424, 56, f"Hatch  {cost}", th, "primary", key="A", ico="star")
    hints(cv, 24, 572, [("+", "Browse"), ("A", "Hatch"), ("B", "Back")], th, right="Fixed odds. Shown before you pay.")
    return cv


def hatch_phone(th, sel=0):
    cv = psheet(th, "Hatch eggs")
    for i, (kind, name, cost, sub, *_) in enumerate(EGGS):
        x, y, w, h = 20, 124 + i * 64, 220, 56
        f = i == sel
        cv.rr(x, y, w, h, 12, fill=th["selected"] if f else th["raised"])
        cv.rr(x, y, w, h, 12, stroke=th["accent"] if f else STROKE, sw=2 if f else 1)
        cv.text(x + 14, y + 19, name, "b", 15, th["text"], "lm")
        cv.text(x + 14, y + 39, sub, "r", 12, th["soft"], "lm")
        tw = cv.text(x + w - 14, y + 19.5, str(cost), "monob", 15, th["star"], "rm")
        icon(cv, "star", x + w - 14 - tw - 12, y + 19, 15)
    cv.text(24, 322, "Odds shown before you hatch", "r", 12, th["soft"], "lm")
    kind, name, cost, _, desc, per, odds = EGGS[sel]
    card(cv, 252, 124, 540, 210, th)
    well(cv, 264, 136, 150, 186, th)
    egg3d(cv, kind, 339, 222, 104, th)
    cv.text(428, 149, name, "b", 18, th["text"], "lm")
    chip(cv, 780, 138, str(cost), mix(th["well"], STAR, .14), hx(STAR), 22, "star", anchor="r", size=12)
    cv.wrap(428, 164, desc, 352, "r", 12, th["soft"], 16, 2)
    label(cv, 428, 203, "Odds", th, size=12)
    label(cv, 780, 203, per, th, anchor="ra", size=12)
    for i, (n, o) in enumerate(odds):
        y = 219 + i * 18
        cv.text(428, y + 9, n, "r", 13, th["text"], "lm")
        cv.text(780, y + 9, o, "monob", 13, th["text"], "rm")
        if i:
            cv.line([(428, y), (780, y)], (255, 255, 255, 16), 1, False)
    button(cv, 428, 278, 352, 44, f"Hatch  {cost}", th, "primary", size=16, ico="star")
    return cv


# ------------------------------------------------------------------ 04 / 05 Deck style
DTABS = (("faceplate", "Faceplates"), ("pattern", "Backgrounds"))
OWNED = ("sherbet", "stone", "ice", "brick", "moss", "honey", "aqua_pop")
TIERCOL = {"starter": "#C3C8D0", "common": "#9BE3A8", "rare": "#8CC8FF", "showcase": "#E6B3FF"}


def _plate_status(cv, th, pid, x, y, have=128, equipped="sherbet"):
    q = PLATES[pid]
    if pid == equipped:
        cv.text(x, y, "EQUIPPED", "b", 12, th["accent"], "lm", tracking=.6)
    elif pid in OWNED:
        icon(cv, "check", x + 6, y, 14, th["soft"])
        cv.text(x + 17, y, "Owned", "r", 12, th["soft"], "lm")
    elif q["tier"] == "starter":
        icon(cv, "lock", x + 6, y, 14, th["soft"])
        cv.text(x + 17, y, "Win 10", "r", 12, th["soft"], "lm")
    else:
        ok = q["priceStars"] <= have
        icon(cv, "star", x + 6, y - .5, 14, accent=STAR if ok else "#959BA5")
        cv.text(x + 17, y + .5, str(q["priceStars"]), "monob", 13, th["star"] if ok else th["soft"], "lm")


def faceplates_desktop(th, sel="aurora_glass"):
    cv = dpanel(th)
    header(cv, 24, 824, 44, "Deck style", th, 44, 26, eyebrow="Pocket Deck", ey=14)
    itabs(cv, 24, 84, 800, 44, DTABS, 0, th, 16)
    p = PLATES[sel]
    card(cv, 24, 144, 328, 392, th)
    t = deck_thumb(sel, 288)
    cv.paste(t, 44, 158)
    yb = 158 + t.height
    cv.text(40, yb + 22, p["name"], "b", 24, th["text"], "lm")
    chip(cv, 336, yb + 9, p["tier"], th["well"], hx(TIERCOL[p["tier"]]), 26, anchor="r", stroke=STROKE)
    cv.text(40, yb + 50, p["finish"].capitalize() + " finish. Tints your menus.", "r", 14, th["soft"], "lm")
    pt = ui_theme(p["accent"], p["deep"])
    cv.rr(40, yb + 68, 288, 40, 10, fill=pt["panel"])
    cv.rr(40, yb + 68, 288, 40, 10, stroke=STROKE, sw=1)
    cv.rr(48, yb + 75, 92, 26, 8, fill=pt["accent"])
    cv.text(94, yb + 88.5, "Primary", "b", 13, pt["ink"], "mm")
    cv.rr(154, yb + 85, 120, 6, 3, fill=pt["well"])
    cv.rr(154, yb + 85, 74, 6, 3, fill=pt["accent"])
    icon(cv, "star", 304, yb + 88, 16)
    button(cv, 40, 464, 288, 56, f"Buy  {p['priceStars']}", th, "primary", key="A", ico="star")
    for i, pid in enumerate(PLATES):
        x, y = 371 + (i % 4) * 114, 147 + (i // 4) * 98
        f = pid == sel
        cv.rr(x, y, 104, 88, 12, fill=th["selected"] if f else th["raised"])
        cv.rr(x, y, 104, 88, 12, stroke=th["accent"] if f else STROKE, sw=2 if f else 1)
        cv.paste(deck_thumb(pid, 88), x + 8, y + 5)
        cv.text(x + 8, y + 59, fit(cv, PLATES[pid]["name"], 90, "b", 12), "b", 12, th["text"], "lm")
        _plate_status(cv, th, pid, x + 8, y + 75)
        if f:
            cv.glow_ring(x - 4, y - 4, 112, 96, 16)
    hints(cv, 24, 572, [("+", "Browse"), ("LB", "Tab"), ("A", "Buy or equip"), ("B", "Back")], th, right="Fixed prices. No random plates.")
    return cv


def faceplates_phone(th, sel="aqua_pop"):
    cv = psheet(th, "Deck style")
    itabs(cv, 20, 124, 528, 36, DTABS, 0, th, 14)
    p = PLATES[sel]
    card(cv, 560, 124, 232, 210, th)
    t = deck_thumb(sel, 164)
    cv.paste(t, 594, 131)
    cv.text(572, 240, fit(cv, p["name"], 130, "b", 18), "b", 18, th["text"], "lm")
    chip(cv, 780, 229, p["tier"], th["well"], hx(TIERCOL[p["tier"]]), 22, anchor="r", stroke=STROKE, size=12)
    cv.text(572, 261, p["finish"].capitalize() + " finish", "r", 12, th["soft"], "lm")
    button(cv, 572, 278, 208, 44, "Equip", th, "primary", size=16)
    ids = [i for i in PLATES][3:9]
    for i, pid in enumerate(ids):
        x, y = 23 + (i % 3) * 175, 175 + (i // 3) * 72
        f = pid == sel
        cv.rr(x, y, 169, 64, 12, fill=th["selected"] if f else th["raised"])
        cv.rr(x, y, 169, 64, 12, stroke=th["accent"] if f else STROKE, sw=2 if f else 1)
        cv.paste(deck_thumb(pid, 72), x + 8, y + 12)
        cv.text(x + 88, y + 23, fit(cv, PLATES[pid]["name"], 74, "b", 12), "b", 12, th["text"], "lm")
        _plate_status(cv, th, pid, x + 88, y + 42, equipped="sherbet")
    cv.rr(544, 178, 4, 150, 2, fill=(255, 255, 255, 20))
    cv.rr(544, 208, 4, 56, 2, fill=(255, 255, 255, 110))
    return cv


BGS = (("seed", "Canopy", "In use", "accent", True, None), ("ripple", "Creek", "Earned", "soft", False, "check"),
       ("lantern", "Lantern", "Reach Rank II", "soft", False, "lock"))


def _bg_swatch(cv, th, kind):
    def draw(x, y, side):
        pattern(cv, (x + 1, y + 1, side - 2, side - 2), kind, th, 9, alpha=70, scale=.62)
    return draw


def _mini_lcd(cv, x, y, w, h, th, kind):
    """Preview: the chosen pattern where it will show, behind the board on the deck screen."""
    cv.rr(x, y, w, h, 12, fill=th["panel"])
    cv.rr(x, y, w, h, 12, stroke=STROKE, sw=1)
    bh = h - 16
    bw = round(bh * ASPECT)
    bx = x + (w - bw) // 2
    for sx in (x + 8, bx + bw + 8):
        cw = bx - x - 16
        for i, hh in enumerate((.20, .34, .30)):
            yy = y + 8 + sum((.20, .34, .30)[:i]) * (bh - 12) + i * 6
            cv.rr(sx, yy, cw, hh * (bh - 12), 6, fill=th["raised"])
    board(cv, (bx, y + 8, bw, bh), th, "after", kind, 0, mini=True)


def backgrounds_desktop(th, focus=1):
    cv = dpanel(th)
    header(cv, 24, 824, 44, "Deck style", th, 44, 26, eyebrow="Pocket Deck", ey=14)
    itabs(cv, 24, 84, 800, 44, DTABS, 1, th, 16)
    kind, name, st, col, bold, ic = BGS[focus]
    card(cv, 24, 144, 328, 392, th)
    _mini_lcd(cv, 40, 160, 296, 196, th, kind)
    cv.text(40, 386, name, "b", 24, th["text"], "lm")
    chip(cv, 336, 373, "Earned", th["well"], hx("#9BE3A8"), 26, anchor="r", stroke=STROKE)
    cv.text(40, 414, "A pattern on the screen, behind the board", "r", 14, th["soft"], "lm")
    cv.text(40, 438, "From the High Roller trial", "r", 14, th["soft"], "lm")
    button(cv, 40, 464, 288, 56, "Use", th, "primary", key="A")
    for i, (k, n, s, c, b, _) in enumerate(BGS):
        x, y = 371 + (i % 2) * 229, 147 + (i // 2) * 108
        tile(cv, x, y, 217, 96, th, n, s, th[c], _bg_swatch(cv, th, k), i == focus, 16, 14, b)
    card(cv, 371, 372, 446, 72, th, "well")
    ico(cv, "pattern", 403, 408, 26, th["accent"])
    cv.text(428, 398, "Shows on every device, phone included.", "m", 14, th["text"], "lm")
    cv.text(428, 419, "Earned by playing. Never sold.", "r", 14, th["soft"], "lm")
    hints(cv, 24, 572, [("+", "Browse"), ("LB", "Tab"), ("A", "Use"), ("B", "Back")], th, right="Backgrounds are earned, not bought.")
    return cv


def backgrounds_phone(th, focus=1):
    cv = psheet(th, "Deck style")
    itabs(cv, 20, 124, 528, 36, DTABS, 1, th, 14)
    kind, name, *_ = BGS[focus]
    card(cv, 560, 124, 232, 210, th)
    _mini_lcd(cv, 572, 134, 208, 92, th, kind)
    cv.text(572, 243, name, "b", 18, th["text"], "lm")
    chip(cv, 780, 232, "Earned", th["well"], hx("#9BE3A8"), 22, anchor="r", stroke=STROKE, size=12)
    cv.text(572, 263, "Behind the board, on every device", "r", 12, th["soft"], "lm")
    button(cv, 572, 278, 208, 44, "Use", th, "primary", size=16)
    for i, (k, n, s, c, b, _) in enumerate(BGS):
        x, y = 23 + (i % 2) * 264, 175 + (i // 2) * 72
        tile(cv, x, y, 258, 64, th, n, s, th[c], _bg_swatch(cv, th, k), i == focus, 14, 13, b)
    return cv


# ------------------------------------------------------------------ the board
def sub_layer(cv, rect, r, fn):
    """Draw with fn(sub canvas in local px) and paste it clipped to the rounded rect."""
    x, y, w, h = rect
    sub = Cv(w, h, z=cv.z)
    fn(sub)
    a = sub.im.getchannel("A")
    m = rounded_mask(sub.im.width, sub.im.height, round(r * cv.z), 1)
    sub.im.putalpha(Image.fromarray(np.minimum(np.asarray(a), np.asarray(m))))
    cv.paste(sub.im, x * cv.z, y * cv.z, raw=True)


def pattern(cv, rect, kind, th, r, alpha=20, scale=1.0):
    """Deck background pattern: Canopy (seed), Creek (ripple), Lantern. One tone, the plate accent."""
    x, y, w, h = rect
    col = mix(th["accent"], "#FFFFFF", .25)[:3] + (alpha,)

    def draw(s):
        step = 40 * scale
        for j in range(-1, int(h / (step * .8)) + 2):
            for i in range(-1, int(w / step) + 2):
                px = i * step + (step / 2 if j % 2 else 0) + step * .3
                py = j * step * .8 + step * .3
                if kind == "seed":
                    for k, (dx, dy) in enumerate(((0, 0), (7 * scale, 3 * scale))):
                        a = math.radians(-58)
                        ln = 5.5 * scale
                        s.line([(px + dx - ln * math.cos(a), py + dy - ln * math.sin(a)), (px + dx + ln * math.cos(a), py + dy + ln * math.sin(a))], col, 5 * scale)
                elif kind == "ripple":
                    for k in range(3):
                        s.arc(px, py + 10 * scale, (6 + k * 6) * scale, 215, 325, col, 1.8 * scale)
                else:
                    s.line([(px, py - 11 * scale), (px, py - 6 * scale)], col, 1.2 * scale, False)
                    s.rr(px - 5 * scale, py - 6 * scale, 10 * scale, 13 * scale, 4 * scale, fill=col)
                    s.rr(px - 3 * scale, py - 8 * scale, 6 * scale, 2.4 * scale, 1, fill=col)
                    s.rr(px - 3 * scale, py + 6.6 * scale, 6 * scale, 2.4 * scale, 1, fill=col)
    sub_layer(cv, rect, r, draw)


VIVID = [("#2E8BFF", "#0A3FD6", "#8FE1FF"), ("#FF8A1A", "#E0400A", "#FFD45C"), ("#22E06A", "#04963F", "#B4FF7A"),
         ("#FF4DA6", "#C4126F", "#FFB0DC"), ("#A66BFF", "#5B21D6", "#E3C8FF")]
OLD = [("#29ADFF", "#1D2B53"), ("#FFA300", "#AB5236"), ("#00E436", "#008751"), ("#FF77A8", "#7E2553"), ("#FFEC27", "#AB5236")]
MARK = ["I", "II", "III", "IV", "V"]


def egg_old(cv, cx, cy, r, tier):
    """As built: flat PICO-8 body inside a dark rim ring."""
    body, rim = OLD[tier - 1]
    cv.ell(cx, cy, r, fill=rim)
    cv.ell(cx, cy, r - max(1.6, r * .14), fill=body)
    cv.rr(cx - r * .42, cy - r * .5, r * .42, max(1.5, r * .16), 1, fill=(255, 241, 232, 255))
    if r >= 12:
        cv.text(cx, cy + r * .1, MARK[tier - 1], "b", max(12, r * .7), (0, 0, 0, 230), "mm")


def egg_vivid(cv, cx, cy, r, tier, glow=1.0, hint=False):
    """Proposed: saturated glossy body, no ring. Its own colour blooms on the dark well; a motif per tier."""
    base, deep, light = VIVID[tier - 1]
    z = cv.z
    g = r * (1.5 if hint else 1.28)
    cv.shadow(cx - g, cy - g, g * 2, g * 2, g, blur=r * (.9 if hint else .55), color=hx(light if hint else base, int((150 if hint else 80) * glow)), dy=0)
    d = int(r * 2 * z) + 4
    ys, xs = np.mgrid[0:d, 0:d].astype(np.float32)
    c = d / 2
    dist = np.sqrt((xs - c) ** 2 + (ys - c) ** 2) / (r * z)
    lit = np.clip(1 - np.sqrt((xs - c * 0.70) ** 2 + (ys - c * 0.58) ** 2) / (r * z * 1.5), 0, 1)
    arr = ramp(lit, [(0, hx(deep)), (0.42, hx(base)), (0.78, mix(base, light, .7)), (1, mix(light, "#FFFFFF", .5))]).astype(np.float32)
    bounce = np.clip((dist - .72) / .28, 0, 1) * np.clip((ys - c) / (r * z), 0, 1)       # rim light from below
    arr[..., :3] += (np.array(hx(light)[:3], dtype=np.float32) - arr[..., :3]) * (bounce * .55)[..., None]
    arr[..., 3] = np.clip((1 - dist) * r * z * 0.9, 0, 1) * 255
    cv.paste(Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA"), cx * z - d / 2, cy * z - d / 2, raw=True)
    m = (255, 255, 255, 58)
    if tier == 2:
        cv.arc(cx, cy + r * 1.05, r * 1.25, 238, 302, m, r * .16)
        cv.arc(cx, cy + r * 1.45, r * 1.25, 246, 294, m, r * .12)
    elif tier == 3:
        for dx, dy, k in ((.42, .30, .13), (-.30, .48, .10), (.10, .62, .08), (.55, -.12, .08)):
            cv.ell(cx + r * dx, cy + r * dy, r * k, fill=m)
    elif tier == 4:
        cv.poly(star_pts(cx + r * .30, cy + r * .40, r * .30), m)
        cv.poly(star_pts(cx - r * .38, cy + r * .50, r * .15), m)
    elif tier == 5:
        for a in range(0, 360, 45):
            cv.ell(cx + r * .64 * math.cos(math.radians(a + 20)), cy + r * .64 * math.sin(math.radians(a + 20)), r * .07, fill=(255, 255, 255, 110))
    cv.ell(cx - r * .34, cy - r * .44, r * .30, r * .17, fill=(255, 255, 255, 215))
    cv.ell(cx - r * .60, cy - r * .12, r * .07, fill=(255, 255, 255, 170))
    if r >= 12:
        fs = max(12, r * .82)
        cv.text(cx + .6, cy + r * .10 + 1.2, MARK[tier - 1], "xb", fs, hx(deep, 200), "mm")
        cv.text(cx, cy + r * .10, MARK[tier - 1], "xb", fs, (255, 255, 255, 255), "mm")
    if hint:                                              # the match hint: sparkles, not a ring
        for dx, dy, k in ((.95, -.75, .26), (-1.0, -.55, .18)):
            cv.poly(_spark(cx + r * dx, cy + r * dy, max(2.5, r * k)), (255, 255, 255, 235))


STACK = ((48, 544, 34, 3), (112, 552, 26, 2), (160, 556, 22, 1), (214, 540, 38, 4), (282, 552, 26, 2), (300, 500, 22, 1),
         (72, 486, 26, 2), (128, 502, 22, 1), (168, 510, 22, 1), (250, 478, 26, 2), (104, 444, 22, 1), (196, 468, 22, 1))
TALL = ((60, 420, 26, 2), (150, 430, 34, 3), (228, 418, 26, 2), (290, 440, 22, 1), (100, 372, 22, 1), (190, 370, 26, 2), (262, 372, 22, 1),
        (140, 322, 26, 2), (220, 318, 22, 1), (72, 328, 22, 1), (176, 268, 26, 2), (120, 276, 22, 1), (236, 272, 22, 1),
        (150, 222, 22, 1), (204, 220, 26, 2), (178, 172, 22, 1))


def board(cv, rect, th, style="after", bg="seed", danger=0, mini=False, hint=True):
    """style 'before' = as built (approximated), 'after' = proposal. danger: 0 calm, 1 warning (3 s), 2 last second."""
    bx, by, bw, bh = rect
    sx, s = bw / 338, bh / 584
    r = max(4, 12 * s)
    line_y = by + 200 * s
    eggs = STACK + (TALL if danger else ())
    ax = bx + 196 * sx
    if style == "before":
        cv.rr(bx, by, bw, bh, r, fill=th["well"])
        for gy in range(1, 12):
            cv.line([(bx + 8, by + gy * bh / 12), (bx + bw - 8, by + gy * bh / 12)], (255, 255, 255, 7), 1, False)
        cv.rr(bx + 1, by + 1, bw - 2, bh - 2, r, stroke=hx("#E8B93A"), sw=max(1.5, 3 * s))          # the yellow frame
        cv.line([(bx + 6, line_y), (bx + bw - 6, line_y)], hx("#FF004D", 255 if danger else 130), max(1, 2 * s), False)
        if danger:
            cv.text(bx + 10, by + 14, "CLEAR THE LINE", "b", 12, hx("#FF5A6E"), "lm")
            cv.rr(bx + bw - 10, by + 8, 4, bh * .22, 2, fill=(14, 15, 18, 255))
            cv.rr(bx + bw - 10, by + 8 + bh * .09, 4, bh * .13, 2, fill=hx("#FF004D"))
        for i in range(7):
            cv.ell(ax, by + (104 + i * 30) * s, 1.6, fill=(255, 255, 255, 60))
        egg_old(cv, ax, by + 52 * s, 22 * s, 1)
        for x, y, rr_, t in eggs:
            egg_old(cv, bx + x * sx, by + y * s, rr_ * s, t)
        x, y, rr_, _ = STACK[8]
        cv.ell(bx + x * sx, by + y * s, rr_ * s + 4, stroke=hx("#FFA300", 200), sw=2)                  # MatchHint ring
        return
    # ---- after: no frame, no rings
    top, bot = mix(th["well"], th["accent"], .07), mix(th["well"], "#000000", .35)
    cv.grad_rr(bx, by, bw, bh, r, [(0, top), (.55, th["well"]), (1, bot)])
    if bg:
        pattern(cv, rect, bg, th, r, alpha=16 if not mini else 34, scale=max(.5, s * 1.25) if not mini else .5)
    k = 46 * s                                             # the banks: a lighter step, not an outline
    edge = mix(th["well"], "#FFFFFF", .09)
    cv.poly([(bx, by + bh - k - r), (bx + k + r, by + bh), (bx + r, by + bh), (bx, by + bh - r)], edge)
    cv.poly([(bx + bw, by + bh - k - r), (bx + bw - k - r, by + bh), (bx + bw - r, by + bh), (bx + bw, by + bh - r)], edge)
    cv.grad_rr(bx, by, bw, min(bh, 26 * s + 6), r, [(0, (0, 0, 0, 70)), (1, (0, 0, 0, 0))])     # the screen sits in
    cv.refresh()
    tone = hx(AMBER) if danger == 1 else hx(DANGER)
    if danger:
        hz = gradient(round(bw * cv.z), round((line_y - by) * cv.z), [(0, tone[:3] + (0,)), (1, tone[:3] + (70 if danger == 1 else 110,))])
        hz.putalpha(Image.fromarray(np.minimum(np.asarray(hz.getchannel("A")), np.asarray(rounded_mask(hz.width, hz.height + round(r * cv.z), round(r * cv.z), 1).crop((0, 0, hz.width, hz.height))))))
        cv.paste(hz, bx * cv.z, by * cv.z, raw=True)
    if not mini:
        for i in range(7):
            cv.ell(ax, by + (104 + i * 30) * s, max(1.2, 1.8 * s), fill=(255, 255, 255, 70 - i * 6))
        egg_vivid(cv, ax, by + 52 * s, 22 * s, 1)
        cv.poly([(ax - 6, by + 5), (ax + 6, by + 5), (ax, by + 13)], th["accent"])
    for n, (x, y, rr_, t) in enumerate(eggs):
        egg_vivid(cv, bx + x * sx, by + y * s, rr_ * s, t, hint=hint and not mini and not danger and n == 8)
    if mini:
        return
    if not danger:                                         # calm: a quiet dashed line with its name
        n = int((bw - 16) // 14)
        for i in range(n):
            cv.line([(bx + 8 + i * 14, line_y), (bx + 15 + i * 14, line_y)], (255, 255, 255, 62), 1.5, False)
        tw = cv.tw("FILL LINE", "b", 12, .6)
        cv.rr(bx + bw - tw - 22, line_y - 24, tw + 14, 18, 9, fill=mix(th["well"], "#000000", .2)[:3] + (220,))
        cv.text(bx + bw - 15, line_y - 14.5, "FILL LINE", "b", 12, th["soft"], "rm", tracking=.6)
        return
    left = .72 if danger == 1 else .24                     # the line is the timer: it drains toward the middle
    cv.line([(bx + 8, line_y), (bx + bw - 8, line_y)], tone[:3] + (70,), 2, False)
    half = (bw - 16) / 2 * left
    cv.shadow(bx + bw / 2 - half, line_y - 2, half * 2, 4, 2, blur=6, color=tone[:3] + (190,), dy=0)
    cv.rr(bx + bw / 2 - half, line_y - 2, half * 2, 4, 2, fill=tone)
    t1, t2 = "Stack too high", ("Merge to clear · 3s" if danger == 1 else "Merge now · 1s")
    cw = max(cv.tw(t1, "b", 13), cv.tw(t2, "r", 12)) + 20 + 30
    assert cw <= bw - 8, ("danger chip does not fit the board", cw, bw)
    cx0, cy0, ch = bx + (bw - cw) / 2, line_y - 46, 40
    cv.shadow(cx0, cy0, cw, ch, 12, blur=8, color=(0, 0, 0, 170), dy=2)
    cv.rr(cx0, cy0, cw, ch, 12, fill=mix("#101216", tone, .16)[:3] + (242,))
    cv.rr(cx0, cy0, cw, ch, 12, stroke=tone, sw=1.5)
    cv.ell(cx0 + 21, cy0 + 20, 12, stroke=tone[:3] + (70,), sw=2.5)
    cv.arc(cx0 + 21, cy0 + 20, 12, -90, -90 + 360 * left, tone, 2.5)
    cv.text(cx0 + 21, cy0 + 20.5, "3" if danger == 1 else "1", "monob", 13, (255, 255, 255, 255), "mm")
    cv.text(cx0 + 40, cy0 + 13, t1, "b", 13, (255, 255, 255, 255), "lm")
    cv.text(cx0 + 40, cy0 + 28, t2, "r", 12, mix(tone, "#FFFFFF", .55), "lm")


# ------------------------------------------------------------------ round screens
def _vivid_ball(cv, cx, cy, r, tier, label=True):
    egg_vivid(cv, cx, cy, r, tier, glow=.6)


def round_desktop(th, name, bg="seed", danger=0):
    old, M.egg_ball = M.egg_ball, _vivid_ball            # Next / Then use the same eggs as the board
    lcd = screen_round(th, "hard")
    M.egg_ball = old
    lcd.rr(250, 8, 348, 592, 0, fill=th["panel"])
    lcd.paste(gradient(348 * 4, 592 * 4, [(0, (255, 255, 255, 8)), (1, (0, 0, 0, 30))]), 250 * 4, 8 * 4, raw=True)
    board(lcd, (255, 12, 338, 584), th, "after", bg, danger)
    p = th["plate"]
    for s in (1, 2):
        out = backdrop(1920, 1080, th).resize((1920 * s, 1080 * s), Image.BILINEAR)
        deck = compose_deck(Image.open(ROOT / "assets" / "deck" / "faceplates" / p["texture"]), accent=p["accent"], ink=p["ink"], band_tint=p["band"]["tint"], k=float(s),
                            lcd=lcd.im, lcd_fill=to_hex_rgba(th["panel"]), engrave=(p["engrave"]["color"], p["engrave"]["opacity"]))
        out.alpha_composite(deck, (round(((1920 - 1600) // 2 - PAD) * s), round(((1080 - 800) // 2 + 10 - PAD) * s)))
        OUT.mkdir(parents=True, exist_ok=True)
        out.convert("RGB").save(OUT / f"{name}-desktop-1920x1080{'@2x' if s == 2 else ''}.png")


def round_phone(th, bg="seed", danger=0, style="after"):
    """812x354 as built: glass from y 60; left Score / Chain / Goals / Quests, right Next / Eggs / Difficulty / Win pays."""
    g = F.frame_geometry(PW, PH)
    SW = g["SW"]
    cv = F.plate_canvas(PW, PH, th)
    F.glass(cv, (SW, TOP, PW - 2 * SW, PH - TOP - 4))
    F.screen_fill(cv, (SW + 5, TOP + 5, PW - 2 * SW - 10, PH - TOP - 14), th)
    x0, y0, x1, y1 = SW + 8, TOP + 8, PW - SW - 8, PH - 12
    LH = y1 - y0
    bw = round(LH * ASPECT)
    bx = x0 + (x1 - x0 - bw) // 2
    L1, R0 = bx - 8, bx + bw + 8
    c, rc = L1 - x0, x1 - R0
    board(cv, (bx, y0, bw, LH), th, style, bg, danger)
    old = F.egg_ball
    if style == "after":
        F.egg_ball = _vivid_ball
    F.stat(cv, (x0, y0, c - 72, 44), th, "Score", "2,340")
    F.stat(cv, (L1 - 64, y0, 64, 44), th, "Chain", "×3")
    F.goals_card(cv, (x0, y0 + 52, c, 132), th, 34, False)
    F.handle(cv, (x0, y1 - 44, c, 44), th)
    F.next_card(cv, (R0, y0, rc, 64), th, True)
    F.row_card(cv, (R0, y0 + 72, rc, 44), th, "Eggs left", "14", vsize=18, sub="/24")
    F.difficulty_card(cv, (R0, y0 + 124, rc, 44), th, "hard")
    F.row_card(cv, (R0, y0 + 176, rc, 44), th, "Win pays", "9–12", "star", star=True)
    F.egg_ball = old
    F.shoulders(cv, g, th)
    roblox_bar(cv)
    return cv


def strip(items, name, th, caption_h=44, gap=20, scale=1):
    """Captioned boards side by side at desktop size (338x584)."""
    w, h = 338, 584
    for s in (1, 2):
        sheet = Cv(len(items) * (w + gap) + gap, h + caption_h + gap * 2, z=s, bg=th["panel"])
        for i, (cap, sub, kw) in enumerate(items):
            x = gap + i * (w + gap)
            sheet.text(x + 2, gap + 8, cap, "b", 16, th["text"], "lm")
            sheet.text(x + 2, gap + 28, sub, "r", 13, th["soft"], "lm")
            board(sheet, (x, gap + caption_h, w, h), th, **kw)
        OUT.mkdir(parents=True, exist_ok=True)
        sheet.im.convert("RGB").save(OUT / f"{name}{'@2x' if s == 2 else ''}.png")


def header_sheet(th):
    """00: the one header, at both sizes, on the screens that use it."""
    titles = (("Garden", "Companions"), ("Companions", "Wardrobe"), ("Pocket Deck", "Deck style"), ("Garden", "Hatch eggs"))
    for s in (1, 2):
        sheet = Cv(1060, 30 + len(titles) * 106 + 40 + len(titles) * 78 + 10, z=s * 2, bg=(16, 18, 22, 255))
        sheet.text(20, 20, "Desktop: 848 wide panel at UIScale 1.2. Stars capsule 44 high, back circle 44, 8 apart, both centred on y 44.", "b", 14, (230, 233, 238, 255), "lm")
        for i, (eb, t) in enumerate(titles):
            d = dpanel(th)
            header(d, 24, 824, 44, t, th, 44, 26, eyebrow=eb, ey=14, stars=(128, 128, 1280, 6)[i])
            d.line([(24, 79.5), (824, 79.5)], (255, 255, 255, 18), 1, False)
            part = d.im.crop((0, 0, d.im.width, round(80 * d.z))).resize((round(848 * DS) * s * 2, 96 * s * 2), Image.LANCZOS)
            sheet.paste(part, 20 * s * 2, (40 + i * 106) * s * 2, raw=True)
        y0 = 30 + len(titles) * 106 + 10
        sheet.text(20, y0 + 10, "Phone 812x354: sheet from y 60. Stars capsule 36 high, back circle 36 (hit area 44x44), 8 apart, centred on sheet y 34.", "b", 14, (230, 233, 238, 255), "lm")
        for i, (eb, t) in enumerate(titles):
            p = psheet(th, t, stars=(128, 128, 1280, 6)[i])
            part = p.im.crop((0, round(64 * p.z), p.im.width, round(124 * p.z))).resize((PW * s * 2, 60 * s * 2), Image.LANCZOS)
            sheet.paste(part, 20 * s * 2, (y0 + 30 + i * 78) * s * 2, raw=True)
        OUT.mkdir(parents=True, exist_ok=True)
        im = sheet.im if s == 2 else sheet.out()
        (im if s == 1 else sheet.im.resize((sheet.w * 2, sheet.h * 2), Image.LANCZOS)).convert("RGB").save(OUT / f"00-shared-header{'@2x' if s == 2 else ''}.png")


def main():
    th = kit_theme("sherbet")
    header_sheet(th)
    for name, d, p in (("01-companions-hub", hub_desktop, hub_phone), ("02-customize-charm", customize_desktop, customize_phone),
                       ("03-hatch-eggs", hatch_desktop, hatch_phone), ("04-deck-style-faceplates", faceplates_desktop, faceplates_phone),
                       ("05-deck-style-backgrounds", backgrounds_desktop, backgrounds_phone)):
        save_desktop(d(th), th, name)
        save_phone(p(th), name)
    # 06: the background where everyone can see it: on the screen, behind the board
    round_desktop(th, "06-background-in-screen-creek", "ripple")
    save_phone(round_phone(th, "ripple"), "06-background-in-screen-creek")
    strip([("Canopy", "Free. Seeds, the default.", dict(bg="seed")), ("Creek", "High Roller trial. Ripples.", dict(bg="ripple")),
           ("Lantern", "Rank II. Lanterns.", dict(bg="lantern")), ("Off (for comparison)", "A plain well.", dict(bg=None))], "06-background-patterns-on-board", th)
    # 07: round look
    strip([("Before: calm", "Yellow frame, ring on the match, dark rims.", dict(style="before")),
           ("Before: over the line", "Red line, red words, repeating blip.", dict(style="before", danger=1)),
           ("After: calm", "No frame, no rings. Vivid eggs. Named line.", dict()),
           ("After: warning", "Amber. Says what is wrong and how long.", dict(danger=1)),
           ("After: last second", "Red only now. The line has nearly drained.", dict(danger=2))], "07-round-board-before-after", th)
    round_desktop(th, "07-round-after-warning", "seed", 1)
    save_phone(round_phone(th, "seed", 0), "07-round-after-calm")
    save_phone(round_phone(th, "seed", 1), "07-round-after-warning")
    save_phone(round_phone(th, None, 0, "before"), "07-round-before")
    print("wrote", OUT)


if __name__ == "__main__":
    main()
