"""Round items, smiley balls and ball themes: mockups for ROUND-ITEMS-AND-BALL-THEMES-SCOPE-2026-11-13.md.

Run: python scripts/deck_art/build_round_items_mockups.py [--stats]

Output: artifacts/round-items-2026-11-13/. Desktop pictures are the 848x608 deck LCD, 1:1 (plus an "@2x" file).
Phone pictures are the 812x354 root with the glass from y 60, under the Roblox controls.

Balls are NOT smooth vector art here. They are rasterised on the game's real 64x107 LCD grid with a Python
mirror of JellyLCD.shade(), then scaled up with nearest-neighbour, so every face is shown with the pixels it
would really get. --stats prints the span model (runs per row) and the colour-blind distances used in the scope.
Concept drawings, not Studio captures.
"""
from __future__ import annotations

import math
import sys

import numpy as np
from PIL import Image

import build_compact_frame_mockups as F
import build_mockups as M
import build_redesign_menu_mockups as R
from build_compact_mockups import ASPECT, fit, kit_theme, roblox_bar
from build_mockups import STROKE, button, card, chip, hints, label, progress, check_circle, segmented, glyph, diff_bars
from common import ROOT, Cv, gradient, hx, icon, mix, rounded_mask, DANGER, STAR

OUT = ROOT / "artifacts" / "round-items-2026-11-13"
PW, PH, TOP = 812, 354, 60
AMBER = "#FFB02E"

# ------------------------------------------------------------------ the LCD (mirrors JellyLCD.lua / BoardConfig.lua)
LCD_W = 64
LCD_H = round(LCD_W * 19.8 / 11.8)             # 107
UNIT = LCD_W / 11.8                            # LCD pixels per world unit
RADII = (0.72, 1.04, 1.43, 1.88, 2.35)
FLOOR = LCD_H - LCD_H * 0.4 / 19.8
LEFT = LCD_W * 0.4 / 11.8
BANK = 2.2 * LCD_H / 19.8
LINE = {"easy": 9.6, "medium": 8.6, "hard": 7.6}


def rpx(t):
    return RADII[t - 1] * UNIT


def world_y(y):
    return FLOOR - y * UNIT


VIVID = (("#2E8BFF", "#0A3FD6", "#8FE1FF"), ("#FF8A1A", "#E0400A", "#FFD45C"), ("#22E06A", "#04963F", "#B4FF7A"),
         ("#FF4DA6", "#C4126F", "#FFB0DC"), ("#A66BFF", "#5B21D6", "#E3C8FF"))

# id: name, shop tier, price, ramps (body, deep, light) x5, ink, face style, texture, one-line pitch, tier names
THEMES = {
    "smiley": dict(name="Smileys", tier="starter", price=0, ramps=VIVID, ink="#15102B", face="smiley", tex="none",
                   pitch="Crude little faces. The default.", names=("Blue", "Orange", "Green", "Pink", "Violet")),
    "plain": dict(name="Marbles", tier="starter", price=0, ramps=VIVID, ink="#15102B", face="none", tex="motif",
                  pitch="No faces. Glossy with a pattern each.", names=("Blue", "Orange", "Green", "Pink", "Violet")),
    "gumdrop": dict(name="Gumdrops", tier="common", price=20, ink="#3A2350", face="happy", tex="sugar",
                    ramps=(("#6FC2FF", "#2F7FE0", "#D4EEFF"), ("#FFB25E", "#E8742A", "#FFE6B8"), ("#6BE89C", "#1FAE62", "#D2FFD9"),
                           ("#FF86BE", "#DE3F8C", "#FFD6EA"), ("#BE9BFF", "#7C4BE6", "#EBDDFF")),
                    pitch="Pastel candy with a sugar skirt.", names=("Blueberry", "Apricot", "Mint", "Rose", "Lilac")),
    "gem": dict(name="Gems", tier="rare", price=40, ink="#0A0820", face="dots", tex="facet",
                ramps=(("#2F7BFF", "#0B2FB8", "#A9E4FF"), ("#FFA21F", "#C2500A", "#FFE58A"), ("#3BE89A", "#078A55", "#C2FFD8"),
                       ("#E8205F", "#9A0A44", "#FFB3CC"), ("#9A5BFF", "#4A16C4", "#E2CCFF")),
                pitch="Hard facets and a sparkle. Tiny eyes.", names=("Sapphire", "Topaz", "Emerald", "Ruby", "Amethyst")),
    "planet": dict(name="Planets", tier="rare", price=40, ink="#0F1022", face="sleepy", tex="planet",
                   ramps=(("#5F9BE8", "#27509E", "#C7E2FF"), ("#F2843A", "#A83C14", "#FFC98A"), ("#45E6B4", "#0B8A72", "#C6FFE8"),
                          ("#E2508F", "#96245F", "#FFD0E4"), ("#9B6BFF", "#48239E", "#DCC8FF")),
                   pitch="Craters, bands and a ring. They doze.", names=("Moon", "Mars", "Terra", "Giant", "Nebula")),
    "kitten": dict(name="Kittens", tier="showcase", price=80, ink="#1A1228", face="cat", tex="none", ears=True, ears_from=2,
                   ramps=(("#63A6F5", "#2A5FC2", "#CFE6FF"), ("#FF9A3C", "#D1560F", "#FFE0A8"), ("#4FD98A", "#149A52", "#CFFFD6"),
                          ("#FF7FB6", "#CC2F7C", "#FFD8EA"), ("#A77BFF", "#5A2BD0", "#E6D6FF")),
                   pitch="Ears, a pink nose and whiskers.", names=("Blue kitten", "Ginger", "Matcha", "Sakura", "Plum")),
}
ORDER = ("smiley", "plain", "gumdrop", "gem", "planet", "kitten")
OWNED = ("smiley", "plain", "gumdrop")
EQUIPPED = "smiley"

# ------------------------------------------------------------------ faces: pixel patterns on the LCD grid
# g: eye gap (pixels from the centre line to the inner eye column), ew x eh: eye size, ey: eye top row,
# ck: mouth corner column, my: mouth row. Rows and columns are whole LCD pixels around the ball's centre line.
FACE = {1: dict(g=1, ew=1, eh=1, ey=-1, ck=1, my=1), 2: dict(g=1, ew=1, eh=2, ey=-2, ck=1, my=1),
        3: dict(g=2, ew=2, eh=2, ey=-3, ck=2, my=1), 4: dict(g=2, ew=2, eh=3, ey=-4, ck=3, my=1),
        5: dict(g=3, ew=3, eh=3, ey=-5, ck=4, my=1)}
IDLE = {1: ("open", "smile"), 2: ("open", "smile"), 3: ("open", "grin"), 4: ("lidded", "smirk"), 5: ("open", "joy")}
EXPR = ("idle", "blink", "near", "merged", "danger", "last", "sleepy", "frozen")
EXPR_NAME = {"idle": "Idle", "blink": "Blink", "near": "About to merge", "merged": "Just merged", "danger": "Over the line",
             "last": "Last second", "sleepy": "Sleepy", "frozen": "Items open"}


def face_pixels(tier, expr="idle", style="smiley"):
    """-> [(dx, dy, tone)], dx measured from the centre line: left pixels are negative (-1 is the first one)."""
    f = FACE[tier]
    g, ew, eh, ey, ck, my = f["g"], f["ew"], f["eh"], f["ey"], f["ck"], f["my"]
    eyes, mouth = IDLE[tier]
    if style == "happy":
        eyes, mouth = "happy", "smile"
    elif style == "sleepy":
        eyes, mouth = "closed", "smile"
    elif style == "dots":
        eyes, mouth = "open", "none"
    elif style == "cat":
        eyes, mouth = "open", "cat"
    table = {"blink": ("closed", mouth), "near": ("wide", "o"), "merged": ("happy", "joy" if tier >= 3 else "smile"),
             "danger": ("wide", "frown"), "last": ("wide", "O"), "sleepy": ("closed", "none" if tier <= 2 else "dash"),
             "frozen": ("up", "o")}
    if expr != "idle":
        eyes, mouth = table[expr]
        if style == "dots" and expr not in ("near", "last", "danger", "merged"):
            mouth = "none"
        if style == "cat" and mouth in ("smile", "none", "dash"):
            mouth = "cat"
    px = []
    lcols = [-1 - k for k in range(g, g + ew)]           # left eye, inner -> outer
    rcols = [k for k in range(g, g + ew)]

    def both(k, dy, tone="ink"):
        px.append((-1 - k, dy, tone))
        px.append((k, dy, tone))

    for cols in (lcols, rcols):
        xs = sorted(cols)
        outer = xs[0] - 1 if xs[0] < 0 else xs[-1] + 1
        if eyes in ("open", "wide", "up"):
            top = ey - (1 if eyes in ("wide", "up") else 0)
            bottom = ey + eh - (1 if eyes == "up" else 0)
            for x in xs:
                for y in range(top, bottom):
                    px.append((x, y, "ink"))
            if ew >= 2:
                px.append((xs[0], top, "glint"))
        elif eyes == "closed":
            for x in xs + ([outer] if ew == 1 and tier > 1 else []):
                px.append((x, ey + eh - 1, "ink"))
        elif eyes == "happy":
            if ew == 1:
                px.append((xs[0], ey, "ink"))
                px.append((outer, ey + 1, "ink"))
            else:
                wide = sorted(xs + [outer])
                for i, x in enumerate(wide):
                    px.append((x, ey + (0 if 0 < i < len(wide) - 1 else 1), "ink"))
        elif eyes == "lidded":
            for x in sorted(xs + [outer]):
                px.append((x, ey + 1, "ink"))
            for x in xs:
                px.append((x, ey + 2, "ink"))
    if mouth == "smile":
        if tier == 1:
            both(0, my)
        else:
            both(ck, my)
            for k in range(ck):
                both(k, my + 1)
    elif mouth in ("grin", "joy"):
        for k in range(ck + 1):
            both(k, my)
        for k in range(ck):
            both(k, my + 1, "ink" if tier < 4 else "blush")
        if tier >= 4:
            for k in range(ck - 1):
                both(k, my + 2)
            both(ck - 1, my + 1)
    elif mouth == "smirk":
        for k in range(ck):
            both(k, my + 1)
        px.append((ck, my, "ink"))
    elif mouth == "frown":
        if tier == 1:
            both(0, my + 1)
        else:
            for k in range(ck):
                both(k, my + 1)
            both(ck, my + 2)
    elif mouth == "o":
        both(0, my)
        both(0, my + 1)
    elif mouth == "O":
        w = 1 if tier <= 2 else 2
        for k in range(w):
            for y in range(my, my + (2 if tier <= 2 else 3)):
                both(k, y)
    elif mouth == "dash":
        both(0, my + 1)
    elif mouth == "cat":
        both(0, my - (0 if tier > 1 else 0), "blush")
        if tier >= 2:
            both(1, my + 1)
        if tier >= 3:
            both(0, my + 2)
            both(2, my + 2 - 1)
    if expr == "last" and tier >= 2:                      # a sweat drop
        px.append((g + ew + 1, ey - 1, "glint"))
        px.append((g + ew + 1, ey, "light"))
    if tier == 5 and style in ("smiley", "happy", "cat") and expr in ("idle", "blink", "merged", "near"):
        for k in (6, 7):
            both(k, 0, "blush")
    return px


# ------------------------------------------------------------------ shading (mirror of JellyLCD.shade) and textures
RING = [(math.cos(k * math.pi / 3 + math.pi / 6) * .6, math.sin(k * math.pi / 3 + math.pi / 6) * .6) for k in range(6)]


def motif_at(kind, lx, ly):
    if kind == 2:
        return -0.06 < ly < 0.08 or 0.26 < ly < 0.38
    if kind == 3:
        return (lx - .34) ** 2 + (ly + .14) ** 2 < .014 or (lx + .16) ** 2 + (ly - .38) ** 2 < .014 or (lx - .42) ** 2 + (ly - .16) ** 2 < .01
    if kind == 4:
        return abs(lx - .3) + abs(ly + .02) < .15 or abs(lx + .12) + abs(ly - .4) < .12
    if kind == 5:
        return any((lx - a) ** 2 + (ly - b) ** 2 < .012 for a, b in RING)
    return False


def shade(theme, tier, lx, ly, q, lean):
    """-> role name. `lean` is the face-theme shading: one small glint, a deep crescent, a thin light crescent."""
    tex = theme["tex"]
    if tex == "facet":
        if ly < -.52:
            return "light"
        if lx + ly > .55:
            return "deep"
        if lx < -.42:
            return "lightmid"
        if abs(lx + .05) < .1 and abs(ly + .12) < .1 and tier >= 3:
            return "body"
        return "body"
    if lean:                                              # face themes: a clean field for the face, fewer tones per row
        if ((lx + .42) / .2) ** 2 + ((ly + .62) / .12) ** 2 < 1:
            return "glint"
        if tex == "sugar" and ly > .38:
            return "light" if (ly > .62 or q > .8) else "lightmid"
        if lx + ly > .62:
            return "deep"
        if tier >= 3 and q > .72 and ly > .45:
            return "light"
        if tex == "planet":
            if tier in (1, 2) and ((lx - .3) ** 2 + (ly - .2) ** 2 < .05 or (lx + .35) ** 2 + (ly - .45) ** 2 < .03):
                return "deep"
            if tier == 3 and ((lx + .3) ** 2 / .12 + (ly + .05) ** 2 / .05 < 1 or (lx - .25) ** 2 / .06 + (ly - .45) ** 2 / .03 < 1):
                return "light"
            if tier == 4 and (-.1 < ly < .04 or .34 < ly < .44 or -.6 < ly < -.52):
                return "lightmid"
            if tier == 5 and abs(ly - .12 - lx * .22) < .07:
                return "light"
            return "body"
        if lx + ly < -.95:
            return "light"
        return "body"
    if ((lx + .28) / .22) ** 2 + ((ly + .43) / .14) ** 2 < 1:
        return "glint"
    if ((lx + .1) / .07) ** 2 + ((ly + .64) / .07) ** 2 < 1:
        return "glint"
    if q > .72 and ly > .45:
        return "light"
    if lx + ly > .62:
        return "deep"
    if ((lx + .35) / .57) ** 2 + ((ly + .36) / .4) ** 2 < 1:
        return "light"
    if tex == "motif" and tier > 1 and motif_at(tier, lx, ly):
        return "motif"
    return "body"


def tones(theme, tier):
    body, deep, light = theme["ramps"][tier - 1]
    return {"body": hx(body), "deep": hx(deep), "light": hx(light), "glint": (255, 255, 255, 255), "motif": mix(body, "#FFFFFF", .23),
            "lightmid": mix(body, light, .5), "ink": hx(theme["ink"]), "blush": mix(body, "#FF3F7A", .62) if tier != 4 else mix(deep, "#FF3F7A", .3),
            "bloom": hx(body)[:3] + (77,), "prize": hx("#FFF3A6")}


class Lcd:
    """One frame of the board on the real grid. rgba holds the dynamic pixels; ids holds a tone id per pixel for the span model."""

    def __init__(self, w=LCD_W, h=LCD_H, clip=True):
        self.w, self.h, self.clip = w, h, clip
        self.rgba = np.zeros((h, w, 4), np.uint8)
        self.ids = np.zeros((h, w), np.int32)
        self._ids = {}

    def put(self, x, y, color, key):
        if not (0 <= x < self.w and 0 <= y < self.h):
            return
        if self.clip:
            inset = max(0, BANK - (FLOOR - (y + .5)))
            if x + .5 < LEFT + inset or x + .5 > self.w - LEFT - inset or y + .5 > FLOOR:
                return
        self.rgba[y, x] = color
        self.ids[y, x] = self._ids.setdefault(key, len(self._ids) + 1)

    def ball(self, cx, cy, tier, theme, expr="idle", faces=True, lean=None, bloom=True, shift=(0, 0), prize=False, r=None):
        th = THEMES[theme] if isinstance(theme, str) else theme
        tn = tones(th, tier)
        r = r or rpx(tier)
        lean = faces and th["face"] != "none" if lean is None else lean
        x0, x1, y0, y1 = int(cx - r * 1.4) - 1, int(cx + r * 1.4) + 2, int(cy - r * 1.4) - 1, int(cy + r * 1.4) + 2
        if bloom:
            for y in range(y0, y1):
                for x in range(x0, x1):
                    d2 = ((x + .5 - cx) ** 2 + (y + .5 - cy) ** 2) / (r * r)
                    if 1 < d2 <= 1.28 ** 2 and 0 <= x < self.w and 0 <= y < self.h and self.rgba[y, x, 3] == 0:
                        self.put(x, y, tn["bloom"], ("bloom", tier))
        if th.get("ears") and tier >= th.get("ears_from", 1):
            for side in (-1, 1):
                ex, yb, yt, hw = cx + side * .56 * r, cy - .6 * r, cy - 1.22 * r, .44 * r
                for y in range(int(yt) - 1, int(yb) + 1):
                    for x in range(int(ex - hw) - 1, int(ex + hw) + 2):
                        t = (y + .5 - yt) / (yb - yt)
                        if 0 <= t <= 1 and abs(x + .5 - ex) <= hw * t + .2:
                            inner = tier >= 3 and t > .45 and abs(x + .5 - ex) <= hw * t * .4
                            self.put(x, y, tn["blush" if inner else "body"], (theme if isinstance(theme, str) else "t", tier, "ear", inner))
        for y in range(y0, y1):
            for x in range(x0, x1):
                lx, ly = (x + .5 - cx) / r, (y + .5 - cy) / r
                q = lx * lx + ly * ly
                if q <= 1:
                    role = shade(th, tier, lx, ly, q, lean)
                    self.put(x, y, tn[role], (id(th), tier, role))
        ax, ay = round(cx) + shift[0], round(cy) + shift[1]
        if prize:                                            # a power-up ball: a twinkling star instead of a face
            for dx, dy in ((0, 0), (-1, 0), (1, 0), (0, -1), (0, 1)) + (((-2, 0), (2, 0), (0, -2), (0, 2)) if tier >= 2 else ()):
                self.put(ax + dx, ay + dy, tn["prize"], ("prize",))
            return
        if faces and th["face"] != "none":
            for dx, dy, tone in face_pixels(tier, expr, th["face"]):
                x, y = ax + dx, ay + dy
                if ((x + .5 - cx) ** 2 + (y + .5 - cy) ** 2) <= (r - .6) ** 2:
                    self.put(x, y, tn[tone], (id(th), tier, tone))

    def spans(self):
        """Runs of equal tone per row over the dynamic pixels: the span surface's demand for this frame."""
        n = 0
        for y in range(self.h):
            row = self.ids[y]
            prev = 0
            for v in row:
                if v != prev and v != 0:
                    n += 1
                prev = v
        return n

    def image(self, scale=None, size=None):
        im = Image.fromarray(self.rgba, "RGBA")
        if size:
            return im.resize(size, Image.NEAREST)
        return im.resize((self.w * scale, self.h * scale), Image.NEAREST)


def settle(drops):
    """Greedy packing: each (x, tier) falls straight down until it rests. Enough for a believable stack."""
    out = []
    for x, tier in drops:
        r = rpx(tier)
        x = min(max(x, LEFT + r), LCD_W - LEFT - r)
        y = FLOOR - r
        for inset_side in (x - r - LEFT, LCD_W - LEFT - x - r):       # the sloped banks
            if inset_side < BANK:
                y = min(y, FLOOR - r - (BANK - inset_side) * .75)
        for ox, oy, ot in out:
            ro = rpx(ot)
            dx = abs(x - ox)
            if dx < r + ro:
                y = min(y, oy - math.sqrt((r + ro) ** 2 - dx * dx))
        out.append((x, y, tier))
    return out


def heap(tiers, seed=3, width=LCD_W, floor=FLOOR, banks=True):
    """Lowest-fit packing: each ball takes the spot where it comes to rest lowest, like a settled tray."""
    out = []
    for n, tier in enumerate(tiers):
        r = rpx(tier)
        best = None
        xs = np.arange(LEFT + r, width - LEFT - r + .01, 1.0)
        for x in xs:
            y = floor - r
            for side in (x - r - LEFT, width - LEFT - x - r):
                if banks and side < BANK:
                    y = min(y, floor - r - (BANK - side) * .8)
            for ox, oy, ot in out:
                ro = rpx(ot)
                dx = abs(x - ox)
                if dx < r + ro:
                    y = min(y, oy - math.sqrt((r + ro) ** 2 - dx * dx))
            score = y + ((x * 7 + n * 13 + seed) % 5) * .35
            if best is None or score > best[0]:
                best = (score, x, y)
        out.append((best[1], best[2], tier))
    return out


CALM = heap((4, 3, 2, 3, 2, 1, 2, 1, 1, 2, 1, 1))
TALL = heap((5, 4, 3, 2, 4, 3, 2, 1, 2, 3, 1, 2, 1, 2, 1, 1, 2, 1, 1, 2, 1, 1, 1, 2, 1))
STRESS = heap((4, 3, 2, 3, 2, 1, 2, 1, 1, 2, 1, 1, 3, 2, 1, 1, 2, 1, 2, 1, 1, 2, 1, 1, 2, 1, 1, 1, 2, 1, 1, 1))


def draw_scene(scene, theme="smiley", faces=True, mode="calm", heat="hard", held=True, frozen=False, prize=None, lean=None, shiver=False):
    lcd = Lcd()
    line = world_y(LINE[heat])
    for i, (x, y, t) in enumerate(scene):
        over = y - rpx(t) < line
        expr = "idle"
        if frozen:
            expr = "frozen"
        elif mode == "danger":
            expr = "danger" if over or y - rpx(t) < line + 6 else ("idle" if i % 3 else "blink")
        elif mode == "last":
            expr = "last" if over or y - rpx(t) < line + 8 else "danger"
        elif i == 9:
            expr = "near"
        elif i in (6,):
            expr = "sleepy"
        elif i == 4:
            expr = "blink"
        sh = ((1, 0) if i % 2 else (-1, 0)) if (shiver and over and t >= 2) else (0, 0)
        lcd.ball(x, y, t, theme, expr, faces, lean, shift=sh, prize=(prize == i))
    if held:
        lcd.ball(LCD_W / 2 + 5, world_y(17.8) + 1, 1, theme, "frozen" if frozen else "idle", faces, lean)
    return lcd


# ------------------------------------------------------------------ flat UI pieces
def dot(cv, cx, cy, slot, tier, theme="smiley", ring=True):
    """THE icon rule: a flat circle in the tier's colour; its size steps with the tier inside a fixed slot. No numeral."""
    body, deep, _ = THEMES[theme]["ramps"][tier - 1]
    d = slot * (0.52, 0.64, 0.76, 0.88, 1.0)[tier - 1]
    cv.ell(cx, cy, d / 2, fill=hx(body))
    if ring:
        cv.ell(cx, cy, d / 2, stroke=mix(body, "#FFFFFF", .35), sw=max(1, slot * .05))
    return d


def sprite(tier, theme="smiley", expr="idle", px=4, faces=True, pad=2, prize=False, bloom=True):
    """One ball on its own tiny LCD, scaled by `px` screen pixels per LCD pixel (how Next / Then draw)."""
    r = rpx(tier)
    n = 2 * math.ceil(r * (1.3 if bloom else 1.0)) + pad * 2 + (4 if THEMES[theme].get("ears") else 0)
    lcd = Lcd(n, n, clip=False)
    lcd.ball(n / 2, n / 2 + (1 if THEMES[theme].get("ears") else 0), tier, theme, expr, faces, prize=prize, bloom=bloom)
    return lcd.image(px)


def paste_c(cv, im, cx, cy):
    z = cv.z
    im2 = im.resize((round(im.width * z), round(im.height * z)), Image.NEAREST)
    cv.paste(im2, round(cx * z - im2.width / 2), round(cy * z - im2.height / 2), raw=True)


def rich(cv, x, y, parts, width, th, size=15, key="m", color=None, lh=20, slot=16, theme="smiley"):
    """Wrapped text where ('ball', tier) and ('zone', name) are drawn inline. Returns the height used."""
    color = color or th["text"]
    cx, line = x, 0
    for p in parts:
        words = p.split(" ") if isinstance(p, str) else [p]
        for wd in words:
            if wd == "":
                continue
            w = cv.tw(wd, key, size) if isinstance(wd, str) else (slot + 2 if wd[0] == "ball" else 20)
            if cx > x and cx + w > x + width:
                cx, line = x, line + 1
            cy = y + line * lh + lh / 2
            if isinstance(wd, str):
                cv.text(cx, cy + .5, wd, key, size, color, "lm")
            elif wd[0] == "ball":
                dot(cv, cx + slot / 2, cy, slot, wd[1], theme)
            else:
                F.zone_glyph(cv, cx, cy, wd[1], th)
            cx += w + size * .28
    return (line + 1) * lh


ITEMS = {
    "swap": dict(name="Swap", fx="Next and Then trade places.", short="Next and Then trade.", col="#3CE0C8", rarity="Common"),
    "pop": dict(name="Pop", fx="Removes the highest ball. No points.", short="Removes the top ball.", col="#FFD84A", rarity="Common"),
    "mini": dict(name="Mini", fx="The held ball drops at half size until it merges.", short="Half size until it merges.", col="#8CF08A", rarity="Common"),
    "scope": dict(name="Scope", fx="Full aim line for your next 3 drops.", short="Full aim line, 3 drops.", col="#7CC8FF", rarity="Common"),
    "magnet": dict(name="Magnet", fx="Your next ball pulls its matches in.", short="Pulls its matches in.", col="#FF7A8C", rarity="Uncommon"),
    "bomb": dict(name="Bomb", fx="The held ball bursts on landing and clears a small circle.", short="Clears a small circle.", col="#FF9A3C", rarity="Rare"),
}


def item_icon(cv, kind, cx, cy, s, color=(255, 255, 255, 255)):
    u = s / 24
    w = 2.4 * u
    if kind == "swap":
        cv.arc(cx, cy, 7 * u, 200, 340, color, w)
        cv.arc(cx, cy, 7 * u, 20, 160, color, w)
        cv.poly([(cx + 9.8 * u, cy - 5.4 * u), (cx + 4.2 * u, cy - 4.4 * u), (cx + 8.4 * u, cy - .2 * u)], color)
        cv.poly([(cx - 9.8 * u, cy + 5.4 * u), (cx - 4.2 * u, cy + 4.4 * u), (cx - 8.4 * u, cy + .2 * u)], color)
    elif kind == "pop":
        cv.poly(R._spark(cx, cy, 10 * u), color)
        cv.ell(cx, cy, 3 * u, fill=(20, 22, 28, 255))
    elif kind == "mini":
        cv.ell(cx, cy, 3.2 * u, fill=color)
        for a in (45, 135, 225, 315):
            dx, dy = math.cos(math.radians(a)), math.sin(math.radians(a))
            cv.line([(cx + dx * 10 * u, cy + dy * 10 * u), (cx + dx * 6 * u, cy + dy * 6 * u)], color, w)
            cv.poly([(cx + dx * 4.6 * u, cy + dy * 4.6 * u), (cx + dx * 7.6 * u - dy * 2.6 * u, cy + dy * 7.6 * u + dx * 2.6 * u),
                     (cx + dx * 7.6 * u + dy * 2.6 * u, cy + dy * 7.6 * u - dx * 2.6 * u)], color)
    elif kind == "scope":
        for i in range(6):
            t = i / 5
            cv.ell(cx - 9 * u + t * 13 * u, cy - 8 * u + (t ** 2) * 13 * u, 1.3 * u, fill=color)
        cv.ell(cx + 5.5 * u, cy + 6 * u, 4.4 * u, stroke=color, sw=w * .8)
        cv.ell(cx + 5.5 * u, cy + 6 * u, 1.2 * u, fill=color)
    elif kind == "magnet":
        cv.arc(cx, cy - 1 * u, 6.2 * u, 180, 360, color, 4.6 * u)
        for sx in (-1, 1):
            cv.rr(cx + sx * 6.2 * u - 2.3 * u, cy - 1 * u, 4.6 * u, 6 * u, 0, fill=color)
            cv.rr(cx + sx * 6.2 * u - 2.3 * u, cy + 6 * u, 4.6 * u, 3.4 * u, 1, fill=(20, 22, 28, 255))
            cv.rr(cx + sx * 6.2 * u - 2.3 * u, cy + 6.6 * u, 4.6 * u, 2.8 * u, 1, fill=(255, 255, 255, 235))
    elif kind == "bomb":
        cv.ell(cx - 1 * u, cy + 2.5 * u, 7.4 * u, fill=color)
        cv.ell(cx - 3.6 * u, cy - .2 * u, 2 * u, fill=(20, 22, 28, 90))
        cv.line([(cx + 3.6 * u, cy - 4 * u), (cx + 7 * u, cy - 7.6 * u)], color, w)
        cv.poly(R._spark(cx + 8.4 * u, cy - 9 * u, 3.6 * u), (255, 240, 170, 255))


def capsule(cv, kind, cx, cy, d, th, focus=False, count=1, dim=1.0):
    """An item on the belt: a round toy capsule in the item's colour."""
    it = ITEMS[kind]
    col = hx(it["col"])
    a = int(255 * dim)
    if focus:
        cv.shadow(cx - d / 2, cy - d / 2, d, d, d / 2, blur=d * .22, color=col[:3] + (150,), dy=0)
    cv.ell(cx, cy, d / 2, fill=mix(th["raised"], it["col"], .30 if focus else .18)[:3] + (a,))
    cv.ell(cx, cy, d / 2, stroke=(col[:3] + (a,)) if focus else (255, 255, 255, int(60 * dim)), sw=2.5 if focus else 1.2)
    cv.arc(cx, cy, d / 2 - d * .09, 205, 300, (255, 255, 255, int(70 * dim)), max(1.5, d * .035))
    item_icon(cv, kind, cx, cy, d * .56, col[:3] + (a,))
    if count > 1:
        bw = cv.tw(f"×{count}", "monob", 13 if d >= 60 else 12) + 12
        bx, by = cx + d * .36 - bw / 2, cy + d * .36 - 9
        cv.rr(bx, by, bw, 18, 9, fill=(14, 15, 18, int(240 * dim)))
        cv.rr(bx, by, bw, 18, 9, stroke=(255, 255, 255, int(70 * dim)), sw=1)
        cv.text(bx + bw / 2, by + 9.5, f"×{count}", "monob", 13 if d >= 60 else 12, (255, 255, 255, a), "mm")


# ------------------------------------------------------------------ the board
def lcd_board(cv, rect, th, scene=CALM, theme="smiley", faces=True, mode="calm", heat="hard", bg="seed", marks=False, frozen=False,
              prize=None, guide=True, tag=True, old=False):
    """The well as built after the redesign, with the balls drawn on the real LCD grid. mode: calm | danger | last."""
    bx, by, bw, bh = rect
    s = bh / 584
    r = max(4, 12 * s)
    cv.grad_rr(bx, by, bw, bh, r, [(0, mix(th["well"], th["accent"], .07)), (.55, th["well"]), (1, mix(th["well"], "#000000", .35))])
    if bg:
        R.pattern(cv, rect, bg, th, r, alpha=16, scale=max(.5, s * 1.25))
    k = BANK / LCD_H * bh
    edge = mix(th["well"], "#FFFFFF", .09)
    cv.poly([(bx, by + bh - k - r), (bx + k + r, by + bh), (bx + r, by + bh), (bx, by + bh - r)], edge)
    cv.poly([(bx + bw, by + bh - k - r), (bx + bw - k - r, by + bh), (bx + bw - r, by + bh), (bx + bw, by + bh - r)], edge)
    cv.grad_rr(bx, by, bw, min(bh, 26 * s + 6), r, [(0, (0, 0, 0, 70)), (1, (0, 0, 0, 0))])
    cv.refresh()
    line_y = by + world_y(LINE[heat]) / LCD_H * bh
    danger = {"calm": 0, "danger": 1, "last": 2}[mode]
    tone = hx(AMBER) if danger == 1 else hx(DANGER)
    z = cv.z
    if danger:
        hz = gradient(round(bw * z), round((line_y - by) * z), [(0, tone[:3] + (0,)), (1, tone[:3] + (70 if danger == 1 else 110,))])
        hz.putalpha(Image.fromarray(np.minimum(np.asarray(hz.getchannel("A")), np.asarray(rounded_mask(hz.width, hz.height + round(r * z), round(r * z), 1).crop((0, 0, hz.width, hz.height))))))
        cv.paste(hz, bx * z, by * z, raw=True)
    lcd = draw_scene(scene, theme, faces, mode, heat, held=True, frozen=frozen, prize=prize, shiver=danger > 0)
    ax = bx + (LCD_W / 2 + 5 + .5) / LCD_W * bw
    if guide and not frozen:
        for i in range(6):
            cv.ell(ax + i * 1.2 * s, by + (104 + i * 30) * s, max(1.2, 1.8 * s), fill=(255, 255, 255, 70 - i * 8))
    cv.paste(lcd.image(size=(round(bw * z), round(bh * z))), round(bx * z), round(by * z), raw=True)
    cv.refresh()
    if marks:                                             # as built today: a tier numeral on every ball big enough
        for x, y, t in scene:
            rr_ = rpx(t) / LCD_W * bw
            if rr_ >= 12:
                px, py = bx + x / LCD_W * bw, by + y / LCD_H * bh
                cv.text(px + .6, py + rr_ * .1 + 1.2, R.MARK[t - 1], "xb", max(12, rr_ * .82), hx(VIVID[t - 1][1], 200), "mm")
                cv.text(px, py + rr_ * .1, R.MARK[t - 1], "xb", max(12, rr_ * .82), (255, 255, 255, 255), "mm")
    if not danger:
        n = int((bw - 16) // 14)
        for i in range(n):
            cv.line([(bx + 8 + i * 14, line_y), (bx + 15 + i * 14, line_y)], (255, 255, 255, 62), 1.5, False)
        if tag:
            tw = cv.tw("FILL LINE", "b", 12, .6)
            cv.rr(bx + bw - tw - 22, line_y - 24, tw + 14, 18, 9, fill=mix(th["well"], "#000000", .2)[:3] + (220,))
            cv.text(bx + bw - 15, line_y - 14.5, "FILL LINE", "b", 12, th["soft"], "rm", tracking=.6)
        return line_y
    left = .72 if danger == 1 else .24
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
    return line_y


# ------------------------------------------------------------------ the item carousel ("the belt")
BELT = (("magnet", 1), ("pop", 1), ("bomb", 1))


def carousel(cv, rect, th, big, small, pitch, touch=False, sel=1):
    """Sits in the air above the fill line, inside the board, so Next / Then and the stack stay visible."""
    x, y, w, h = rect
    cv.shadow(x, y, w, h, 14, blur=12, color=(0, 0, 0, 170), dy=4)
    cv.rr(x, y, w, h, 14, fill=mix(th["panel"], "#000000", .18)[:3] + (238,))
    cv.rr(x, y, w, h, 14, stroke=(255, 255, 255, 50), sw=1)
    cx = x + w / 2
    compact = h < 190
    label(cv, x + 12, y + (8 if compact else 12), "Items", th, size=12)
    label(cv, x + w - 12, y + (8 if compact else 12), f"{sum(c for _, c in BELT)} of 3", th, th["soft"], "ra", 12)
    cy = y + (28 if compact else 36) + big / 2
    cv.arc(cx, cy + pitch * 2.6, pitch * 2.75, 247, 293, (255, 255, 255, 34), 2)          # the belt: a shallow arc
    for i, (kind, n) in enumerate(BELT):
        off = i - sel
        if off:
            capsule(cv, kind, cx + off * pitch, cy + abs(off) * big * .09, small, th, False, n, dim=.72)
    kind, n = BELT[sel]
    capsule(cv, kind, cx, cy, big, th, True, n)
    cv.glow_ring(cx - big / 2 - 4, cy - big / 2 - 4, big + 8, big + 8, big / 2 + 4, color=(255, 255, 255, 255), width=2, glow=8, glow_alpha=70)
    for sx in (-1, 1) if not touch else ():               # browse chevrons (touch: swipe, or tap a neighbour)
        px = cx + sx * (w / 2 - 12)
        cv.line([(px - sx * 5, cy - 7), (px + sx * 2, cy), (px - sx * 5, cy + 7)], th["soft"], 2.2)
    it = ITEMS[kind]
    ny = cy + big / 2 + (12 if compact else 18)
    cv.text(cx, ny, it["name"], "b", 16 if compact else 20, th["text"], "mm")
    used = cv_wrap_c(cv, cx, ny + (10 if compact else 14), it["short" if compact else "fx"], w - 24, "r", 13 if compact else 14, th["soft"], 15 if compact else 18)
    if not touch:
        hy = y + h - 20
        items = [("<>", "Browse"), ("A", "Use"), ("B", "Close")]
        tw = sum(glyph_w(cv, k) + 6 + cv.tw(t, "r", 13) + 14 for k, t in items) - 14
        hx_ = cx - tw / 2
        for k, t in items:
            hx_ += glyph(cv, hx_, hy - 10, k, th, False, 20) + 6
            hx_ += cv.text(hx_, hy + .5, t, "r", 13, th["soft"], "lm") + 14
    else:
        cv.text(cx, y + h - 13, "Tap to use", "r", 12, th["dim"], "mm")
    return used


def glyph_w(cv, letter, size=20):
    return size if len(letter) == 1 else (size * 1.6 if letter in ("<>",) else cv.tw(letter, "b", size * .5, .5) + size * .7)


def cv_wrap_c(cv, cx, y, s, width, key, size, fill, lh):
    words, lines, cur = s.split(" "), [], ""
    for wd in words:
        t = (cur + " " + wd).strip()
        if cv.tw(t, key, size) <= width or not cur:
            cur = t
        else:
            lines.append(cur)
            cur = wd
    lines.append(cur)
    for i, ln in enumerate(lines):
        cv.text(cx, y + i * lh + lh / 2, ln, key, size, fill, "mm")
    return len(lines) * lh


def freeze_veil(cv, rect, r=12, alpha=120):
    x, y, w, h = rect
    cv.rr(x, y, w, h, r, fill=(6, 8, 12, alpha))


# ------------------------------------------------------------------ the round, desktop LCD 848x608
GOALS = ((["Merge", ("ball", 2), "+", ("ball", 2), "in the centre", ("zone", "center")], 2, 2),
         (["Make", ("ball", 3), "or bigger on the right", ("zone", "right")], 1, 2),
         (["Make a", ("ball", 4)], 0, 1))
QUESTS = ((["Win 2 rounds"], 1, 2), (["Chain 4 merges"], 3, 4), (["Make a", ("ball", 4), "on Hard"], 0, 1))


def round_desktop(th, mode="calm", belt=False, open_=False, theme="smiley", scene=None, marks=False, faces=True, old_text=False):
    cv = M.lcd(th)
    name, _, level, dcol, mult = M.DIFF["hard"]
    card(cv, 12, 12, 231, 96, th)
    label(cv, 26, 24, "Score", th)
    cv.text(26, 43, "2,340", "monob", 34, th["text"])
    cv.text(26, 84, "BEST 2,210", "mono", 13, th["dim"])
    card(cv, 12, 116, 231, 64, th)
    label(cv, 26, 128, "Chain", th)
    cv.text(26, 146, "×3", "monob", 22, th["text"])
    segmented(cv, 96, 152, 5, 3, th)
    card(cv, 12, 188, 231, 244, th)
    label(cv, 26, 200, "Goals", th)
    label(cv, 229, 200, "1/3", th, th["soft"], "ra")
    old_goals = ("Merge II in the centre", "Make III on RIGHT", "Make a tier IV")
    for i, (parts, c, g) in enumerate(GOALS):
        y = 224 + i * 68
        check_circle(cv, 37, y + 11, c >= g, th)
        if old_text:
            used = cv.wrap(58, y, old_goals[i], 172, "m", 16, th["soft"] if c >= g else th["text"], 19, 2)
        else:
            used = rich(cv, 58, y, parts, 172, th, 15, "m", th["soft"] if c >= g else th["text"], 22, 18, theme)
        progress(cv, 58, y + used + 6, 130, 6, c / g, th)
        cv.text(229, y + used + 9, f"{c}/{g}", "monob", 13, th["soft"], "rm")
    card(cv, 12, 440, 231, 156, th)
    label(cv, 26, 452, "Daily quests", th)
    old_q = ("Win 2 rounds", "Chain 4 merges", "Tier IV on Hard")
    for i, (parts, c, g) in enumerate(QUESTS):
        y = 474 + i * 38
        if old_text:
            cv.text(26, y + 4, old_q[i], "r", 14, th["text"])
        else:
            rich(cv, 26, y, parts, 160, th, 14, "r", th["text"], 22, 16, theme)
        cv.text(229, y + 5, f"{c}/{g}", "monob", 13, th["soft"], "ra")
        progress(cv, 26, y + 26, 203, 4, c / g, th)
    board = (255, 12, 338, 584)
    scene = scene or (TALL if mode != "calm" else CALM)
    lcd_board(cv, board, th, scene, theme, faces, mode, "hard", marks=marks, frozen=open_, prize=(None if marks or mode != "calm" else 7))
    rx = 605
    card(cv, rx, 12, 231, 120, th)
    label(cv, rx + 14, 24, "Next", th)
    label(cv, rx + 132, 24, "Then", th)
    if marks:
        M.egg_ball(cv, rx + 62, 84, 30, 2)
        M.egg_ball(cv, rx + 150, 88, 18, 1)
        M.egg_ball(cv, rx + 196, 88, 18, 3)
    else:
        paste_c(cv, sprite(1, theme, "frozen" if open_ else "idle", 6), rx + 62, 84)
        paste_c(cv, sprite(2, theme, "idle", 3), rx + 150, 88)
        paste_c(cv, sprite(1, theme, "blink", 3), rx + 196, 88)
    card(cv, rx, 140, 231, 64, th)
    label(cv, rx + 14, 152, "Eggs left", th)
    w = cv.text(rx + 14, 168, "14", "monob", 24, th["text"])
    cv.text(rx + 18 + w, 176, "/24", "mono", 15, th["dim"])
    progress(cv, rx + 100, 180, 117, 6, 14 / 24, th)
    card(cv, rx, 212, 231, 56, th)
    diff_bars(cv, rx + 16, 229, level, hx(dcol), th)
    cv.text(rx + 52, 240, name, "b", 20, th["text"], "lm")
    chip(cv, rx + 217, 227, f"×{mult}", mix(th["well"], STAR, .14), hx(STAR), 26, "star", anchor="r")
    card(cv, rx, 276, 231, 56, th)
    label(cv, rx + 14, 288, "Win pays", th)
    icon(cv, "star", rx + 150, 304, 22)
    cv.text(rx + 217, 304, "9-12", "monob", 22, th["star"], "rm")
    # Items: the belt, always visible; B opens it
    card(cv, rx, 340, 231, 104, th, st="selected" if open_ else "idle")
    label(cv, rx + 14, 352, "Items", th)
    gw = glyph(cv, rx + 217 - 22, 346, "B", th, False, 22)
    cv.text(rx + 217 - 22 - 6, 357.5, "Open", "r", 13, th["soft"], "rm")
    for i in range(3):
        sx = rx + 14 + i * 70
        cv.rr(sx, 378, 62, 54, 12, fill=th["well"])
        cv.rr(sx, 378, 62, 54, 12, stroke=STROKE, sw=1)
        if belt and i < len(BELT):
            kind, n = BELT[i]
            capsule(cv, kind, sx + 31, 405, 42, th, False, n)
        else:
            cv.ell(sx + 31, 405, 5, fill=(255, 255, 255, 26))
    card(cv, rx, 452, 231, 144, th)
    label(cv, rx + 14, 464, "Controls", th)
    for i, (k, t) in enumerate((("<>", "Aim"), ("A", "Drop"), ("B", "Items"), ("MENU", "Pause, restart, quit"))):
        y = 486 + i * 27
        glyph(cv, rx + 14, y, k, th, False, 22)
        cv.text(rx + 76, y + 11.5, t, "r", 14, th["soft"], "lm")
    if open_:
        for rect in ((12, 12, 231, 584),):
            cv.rr(*rect, 14, fill=(6, 8, 12, 70))
        freeze_veil(cv, board, 12, 105)
        cv.refresh()
        carousel(cv, (263, 22, 322, 248), th, 100, 64, 104)
        chip(cv, 255 + 169 + 46, 584 - 4, "Paused", (14, 15, 18, 235), th["text"], 24, anchor="r", stroke=STROKE, size=12)
    return cv


def save_lcd(cv, name):
    OUT.mkdir(parents=True, exist_ok=True)
    cv.out().convert("RGB").save(OUT / f"{name}.png")
    cv.im.resize((cv.w * 2, cv.h * 2), Image.LANCZOS).convert("RGB").save(OUT / f"{name}@2x.png")


# ------------------------------------------------------------------ the round, phone 812x354 (glass from y 60)
def phone_goals(cv, rect, th, theme):
    x, y, w, h = rect
    F.card(cv, rect, th)
    label(cv, x + 12, y + 8, "Goals 1/3", th, size=12)
    label(cv, x + w - 44, y + 8, "Chain", th, anchor="ra", size=12)
    cv.text(x + w - 12, y + 15, "×3", "monob", 13, th["text"], "rm")
    p = (h - 28) / 3
    rows = ((("ball", 2), "+", ("ball", 2), ("zone", "center")), (("ball", 3), "up", ("zone", "right")), (("ball", 4),))
    for i, (row, (_, c, g)) in enumerate(zip(rows, GOALS)):
        cy = y + 26 + p / 2 + i * p
        check_circle(cv, x + 20, cy, c >= g, th, 10)
        gx = x + 40
        for part in row:
            if part == "+":
                cv.text(gx, cy, "+", "b", 14, th["soft"], "lm")
                gx += 13
            elif part == "up":                               # "or bigger": a small up arrow, not a numeral
                cv.poly([(gx + 5, cy - 6), (gx + 10, cy + 1), (gx, cy + 1)], th["text"])
                cv.rr(gx + 3.5, cy, 3, 6, 1, fill=th["text"])
                gx += 16
            elif part[0] == "ball":
                dot(cv, gx + 10, cy, 20, part[1], theme)
                gx += 25
            else:
                F.zone_glyph(cv, gx + 2, cy, part[1], th)
                gx += 26
        cv.text(x + w - 12, cy + .5, f"{c}/{g}", "monob", 13, th["soft"], "rm")


def b_button(cv, cx, cy, d, th, kind=None, count=0, lit=False):
    """The touch item button under A: a small B with the front item in it. Hidden while the belt is empty."""
    p = th["plate"]
    F.well(cv, cx, cy + 1.5, d + 8)
    cv.paste(F.tint(F.button_base(d * 3), p["accent"]), (cx - d / 2) * 3, (cy - d / 2) * 3, raw=True)
    cv.paste(F.button_gloss(d * 3), (cx - d / 2) * 3, (cy - d / 2) * 3, raw=True)
    if kind:
        item_icon(cv, kind, cx, cy, d * .56, hx(p["ink"]))
    else:
        cv.text(cx, cy, "B", "xb", d * .46, p["ink"], "mm")
    if lit:
        cv.glow_ring(cx - d / 2 - 4, cy - d / 2 - 4, d + 8, d + 8, d / 2 + 4)
    if count:
        cv.ell(cx + d * .40, cy - d * .40, 10, fill=(14, 15, 18, 255))
        cv.ell(cx + d * .40, cy - d * .40, 10, stroke=(255, 255, 255, 110), sw=1.2)
        cv.text(cx + d * .40, cy - d * .40 + .5, str(count), "monob", 13, (255, 255, 255, 255), "mm")


def round_phone(th, mode="calm", belt=True, open_=False, theme="smiley"):
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
    board = (bx, y0, bw, LH)
    lcd_board(cv, board, th, TALL if mode != "calm" else CALM, theme, True, mode, "hard", frozen=open_, tag=bw >= 190, prize=7 if mode == "calm" else None)
    F.stat(cv, (x0, y0, c, 44), th, "Score", "2,340")
    phone_goals(cv, (x0, y0 + 52, c, 132), th, theme)
    F.handle(cv, (x0, y1 - 44, c, 44), th)
    F.card(cv, (R0, y0, rc, 64), th)
    label(cv, R0 + 12, y0 + 7, "Next", th, size=12)
    label(cv, R0 + 78, y0 + 7, "Then", th, size=12)
    paste_c(cv, sprite(1, theme, "frozen" if open_ else "idle", 4), R0 + 34, y0 + 40)
    paste_c(cv, sprite(2, theme, "idle", 2), R0 + 96, y0 + 42)
    paste_c(cv, sprite(1, theme, "blink", 2), R0 + 132, y0 + 42)
    F.row_card(cv, (R0, y0 + 72, rc, 44), th, "Eggs left", "14", vsize=18, sub="/24")
    F.difficulty_card(cv, (R0, y0 + 124, rc, 44), th, "hard")
    F.row_card(cv, (R0, y0 + 176, rc, 44), th, "Win pays", "9–12", "star", star=True)
    # belt strip: read-only on the screen; the button on the shoulder opens it
    by2 = y0 + 228
    F.card(cv, (R0, by2, rc, LH - 228), th)
    label(cv, R0 + 12, by2 + 7, "Items", th, size=12)
    for i in range(3):
        sx = R0 + 62 + i * 36
        cv.ell(sx + 14, by2 + 23, 14, fill=th["well"])
        cv.ell(sx + 14, by2 + 23, 14, stroke=STROKE, sw=1)
        if belt and i < len(BELT):
            item_icon(cv, BELT[i][0], sx + 14, by2 + 23, 17, hx(ITEMS[BELT[i][0]]["col"]))
    g["speaker"] = (g["speaker"][0], PH + 40)                 # the speaker seeds give way to the item button
    F.shoulders(cv, g, th)
    ax, ay = g["a"]
    bd = 58
    bcx, bcy = ax, ay + g["A"] / 2 + 14 + bd / 2 + 6
    assert bcy + bd / 2 + 6 <= PH - 6 and bd >= 44, ("item button does not fit under A", bcy)
    if belt:
        b_button(cv, bcx, bcy, bd, th, BELT[1][0], sum(n for _, n in BELT), lit=open_)
        cv.text(bcx, bcy + bd / 2 + 11, "ITEMS", "b", 11, hx(th["plate"]["engrave"]["color"], 150), "mm", tracking=1)
    if open_:
        cv.rr(x0, y0, c, LH, 10, fill=(6, 8, 12, 80))
        freeze_veil(cv, board, 6, 105)
        cv.refresh()
        assert y0 + 4 + 156 <= y0 + world_y(LINE["hard"]) / LCD_H * LH + 2, "carousel must stay above the fill line"
        carousel(cv, (bx + 3, y0 + 4, bw - 6, 156), th, 60, 42, 50, touch=True)
    roblox_bar(cv)
    return cv, (bcx, bcy, bd)


def save_phone(cv, name):
    OUT.mkdir(parents=True, exist_ok=True)
    cv.out().convert("RGB").save(OUT / f"{name}.png")
    cv.im.resize((PW * 2, PH * 2), Image.LANCZOS).convert("RGB").save(OUT / f"{name}@2x.png")


# ------------------------------------------------------------------ sheets
def sheet(w, h, th, z=2):
    return Cv(w, h, z=z, bg=(16, 18, 22, 255))


def board_strip(th):
    items = (("Today: calm", "A numeral on every ball that is big enough.", dict(faces=False, marks=True, theme="plain")),
             ("Smileys: calm", "No numerals. Size, colour and a face.", dict(prize=7)),
             ("Today: over the line", "Numerals; nothing reacts.", dict(faces=False, marks=True, theme="plain", mode="danger", scene=TALL)),
             ("Smileys: over the line", "Balls above the line look worried and tremble.", dict(mode="danger", scene=TALL)),
             ("Smileys: last second", "Everyone near the line panics.", dict(mode="last", scene=TALL)))
    w, h, gap, cap = 338, 584, 20, 48
    cv = sheet(len(items) * (w + gap) + gap, h + cap + gap * 2, th)
    for i, (t, sub, kw) in enumerate(items):
        x = gap + i * (w + gap)
        cv.text(x + 2, gap + 8, t, "b", 16, th["text"], "lm")
        cv.text(x + 2, gap + 28, sub, "r", 13, th["soft"], "lm")
        lcd_board(cv, (x, gap + cap, w, h), th, **kw)
    save_lcd(cv, "03-board-before-after")


def expression_sheet(th):
    px, cellw, cellh = 5, 176, 188
    left, top = 150, 64
    cv = sheet(left + len(EXPR) * cellw + 20, top + 5 * cellh + 150, th)
    cv.text(20, 22, "Faces on the real 64-pixel LCD (each square is one LCD pixel, shown 5x). Rows: the five sizes. Columns: what the face is reacting to.", "b", 15, th["text"], "lm")
    for j, e in enumerate(EXPR):
        cv.text(left + j * cellw + cellw / 2, 48, EXPR_NAME[e], "b", 14, th["soft"], "mm")
    notes = ("8 px: two dots and a 2-pixel mouth", "11 px: tall eyes, a small U", "16 px: 2x2 eyes with a glint, a grin",
             "20 px: sleepy lids and a smirk", "25 px: big eyes, open mouth, blush")
    for i in range(5):
        cy = top + i * cellh + cellh / 2
        dot(cv, 34, cy - 12, 26, i + 1)
        cv.text(56, cy - 12, THEMES["smiley"]["names"][i], "b", 14, th["text"], "lm")
        cv.wrap(20, cy + 6, notes[i], 120, "r", 12, th["dim"], 15, 3)
        for j, e in enumerate(EXPR):
            cx = left + j * cellw + cellw / 2
            cv.rr(cx - cellw / 2 + 4, cy - cellh / 2 + 4, cellw - 8, cellh - 8, 10, fill=th["well"])
            paste_c(cv, sprite(i + 1, "smiley", e, px), cx, cy)
    y = top + 5 * cellh + 14
    cv.text(20, y + 8, "The shiver: only the face moves, one LCD pixel, for two ticks. The body's pixels never change, so it costs no extra spans.", "b", 14, th["text"], "lm")
    for k, (sh, cap) in enumerate((((0, 0), "rest"), ((1, 0), "tick 1: +1 px"), ((-1, 0), "tick 2: -1 px"), ((0, 0), "rest"))):
        for n, t in enumerate((2, 4)):
            r = rpx(t)
            size = 2 * math.ceil(r * 1.3) + 4
            lcd = Lcd(size, size, clip=False)
            lcd.ball(size / 2, size / 2, t, "smiley", "danger", shift=sh)
            paste_c(cv, lcd.image(4), 80 + k * 150 + n * 660, y + 74)
        for n in range(2):
            cv.text(80 + k * 150 + n * 660, y + 128, cap, "r", 12, th["dim"], "mm")
    save_lcd(cv, "07-face-expressions")


def theme_strip(th):
    px = 5
    roww, left, top, rh = 176, 250, 60, 226
    cv = sheet(left + 5 * roww + 330, top + len(ORDER) * rh + 16, th)
    cv.text(20, 22, "Ball themes across the five sizes, on the real LCD grid (5x). Every theme keeps the same hue family per size.", "b", 15, th["text"], "lm")
    for j in range(5):
        cv.text(left + j * roww + roww / 2, 46, ("Smallest", "", "", "", "Biggest")[j], "b", 12, th["dim"], "mm")
    cv.text(left + 5 * roww + 24, 46, "ICON CIRCLES (goals, quests, results)", "b", 12, th["dim"], "lm", tracking=.5)
    for i, tid in enumerate(ORDER):
        t = THEMES[tid]
        cy = top + i * rh + rh / 2
        cv.rr(12, cy - rh / 2 + 6, cv.w - 24, rh - 12, 14, fill=th["panel"])
        cv.text(28, cy - 58, t["name"], "b", 22, th["text"], "lm")
        if t["price"]:
            icon(cv, "star", 36, cy - 28, 18)
            cv.text(50, cy - 27.5, str(t["price"]), "monob", 16, th["star"], "lm")
            chip(cv, 82, cy - 40, t["tier"], th["well"], hx(R.TIERCOL[t["tier"]]), 24, stroke=STROKE, size=12)
        else:
            chip(cv, 28, cy - 40, "Free", th["well"], hx(R.TIERCOL["starter"]), 24, stroke=STROKE, size=12)
        cv.wrap(28, cy - 4, t["pitch"], 200, "r", 14, th["soft"], 18, 3)
        cv.rr(left - 8, cy - rh / 2 + 12, 5 * roww + 4, rh - 24, 12, fill=th["well"])
        for j in range(5):
            paste_c(cv, sprite(j + 1, tid, "idle", px), left + j * roww + roww / 2 - 6, cy - 8)
            cv.text(left + j * roww + roww / 2 - 6, cy + rh / 2 - 22, t["names"][j], "r", 12, th["dim"], "mm")
        ix = left + 5 * roww + 24
        for j in range(5):
            dot(cv, ix + 16 + j * 40, cy - 22, 30, j + 1, tid)
        rich(cv, ix, cy + 6, ["Make", ("ball", 3), "or bigger"], 260, th, 15, "m", th["text"], 22, 18, tid)
        rich(cv, ix, cy + 34, ["Merge", ("ball", 2), "+", ("ball", 2)], 260, th, 15, "m", th["text"], 22, 18, tid)
    save_lcd(cv, "06-ball-themes-strip")


# ------------------------------------------------------------------ colour-blind check
CVD = {"Protan": ((0.152286, 1.052583, -0.204868), (0.114503, 0.786281, 0.099216), (-0.003882, -0.048116, 1.051998)),
       "Deutan": ((0.367322, 0.860646, -0.227968), (0.280085, 0.672501, 0.047413), (-0.011820, 0.042940, 0.968881)),
       "Tritan": ((1.255528, -0.076749, -0.178779), (-0.078411, 0.930809, 0.147602), (0.004733, 0.691367, 0.303900))}


def _lin(c):
    c = np.asarray(c[:3], float) / 255
    return np.where(c <= .04045, c / 12.92, ((c + .055) / 1.055) ** 2.4)


def _srgb(l):
    l = np.clip(l, 0, 1)
    return tuple(int(round(v * 255)) for v in np.where(l <= .0031308, l * 12.92, 1.055 * l ** (1 / 2.4) - .055))


def simulate(rgb, kind):
    return _srgb(np.asarray(CVD[kind]) @ _lin(rgb)) if kind in CVD else tuple(rgb[:3])


def lab(rgb):
    l = _lin(rgb)
    xyz = np.asarray(((.4124, .3576, .1805), (.2126, .7152, .0722), (.0193, .1192, .9505))) @ l / np.asarray((.95047, 1, 1.08883))
    f = np.where(xyz > .008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.asarray((116 * f[1] - 16, 500 * (f[0] - f[1]), 200 * (f[1] - f[2])))


def de(a, b):
    return float(np.linalg.norm(lab(a) - lab(b)))


def cvd_table():
    rows = []
    for tid in ORDER:
        bodies = [hx(r[0]) for r in THEMES[tid]["ramps"]]
        for kind in ("Normal", "Protan", "Deutan", "Tritan"):
            sim = [simulate(b, kind) for b in bodies]
            adj = min(de(sim[i], sim[i + 1]) for i in range(4))
            pairs = [(de(sim[i], sim[j]), i + 1, j + 1) for i in range(5) for j in range(i + 1, 5)]
            worst = min(pairs)
            rows.append((tid, kind, adj, worst))
    return rows


def cvd_sheet(th):
    kinds = ("Normal", "Protan", "Deutan", "Tritan")
    cv = sheet(1180, 96 + len(kinds) * 132, th)
    cv.text(20, 22, "Colour-blind check, Smileys theme. Left: the balls at board scale. Right: the icon circles, which also step in size.", "b", 15, th["text"], "lm")
    cv.text(20, 44, "Blue and Violet are the close pair without red-green vision; they are the smallest and biggest ball, so size separates them on the board and in the icon.", "r", 13, th["soft"], "lm")
    rows = {k: (a, w) for t, k, a, w in cvd_table() if t == "smiley"}
    for i, kind in enumerate(kinds):
        cy = 96 + i * 132 + 56
        cv.rr(12, cy - 60, cv.w - 24, 120, 12, fill=th["well"])
        cv.text(28, cy - 12, kind if kind != "Normal" else "Full colour", "b", 16, th["text"], "lm")
        a, wst = rows[kind]
        cv.text(28, cy + 10, f"closest neighbours dE {a:.0f}", "r", 12, th["dim"], "lm")
        cv.text(28, cy + 26, f"closest pair dE {wst[0]:.0f} ({'I II III IV V'.split()[wst[1] - 1]} / {'I II III IV V'.split()[wst[2] - 1]})", "r", 12, th["dim"], "lm")
        sim_theme = dict(THEMES["smiley"])
        sim_theme["ramps"] = tuple(tuple("#%02X%02X%02X" % simulate(hx(c), kind) for c in ramp) for ramp in THEMES["smiley"]["ramps"])
        x = 250
        for t in range(1, 6):
            r = rpx(t)
            size = 2 * math.ceil(r * 1.3) + 4
            lcd = Lcd(size, size, clip=False)
            lcd.ball(size / 2, size / 2, t, sim_theme)
            im = lcd.image(4)
            paste_c(cv, im, x + im.width / 2, cy)
            x += im.width + 6
        THEMES["_sim"] = sim_theme
        for t in range(1, 6):
            dot(cv, 840 + (t - 1) * 46, cy - 16, 34, t, "_sim")
        rich(cv, 800, cy + 14, ["Make", ("ball", 4), "or bigger", ("zone", "right")], 340, th, 15, "m", th["text"], 22, 18, "_sim")
        del THEMES["_sim"]
    save_lcd(cv, "08-colour-blind-check")


# ------------------------------------------------------------------ item set
def item_sheet(th):
    kinds = list(ITEMS)
    cv = sheet(20 + len(kinds) * 196, 250, th)
    cv.text(20, 22, "Candidate items. Recommended for v1: Swap, Pop, Magnet, Bomb. Mini and Scope wait.", "b", 15, th["text"], "lm")
    for i, k in enumerate(kinds):
        it = ITEMS[k]
        x = 20 + i * 196
        v1 = k in ("swap", "pop", "magnet", "bomb")
        cv.rr(x, 44, 180, 190, 14, fill=th["raised"] if v1 else th["panel"])
        cv.rr(x, 44, 180, 190, 14, stroke=STROKE, sw=1)
        capsule(cv, k, x + 90, 100, 76, th, v1, 1, dim=1 if v1 else .7)
        cv.text(x + 90, 158, it["name"], "b", 18, th["text"], "mm")
        cv_wrap_c(cv, x + 90, 170, it["fx"], 160, "r", 13, th["soft"], 16)
        chip(cv, x + 10, 52, "v1" if v1 else "later", th["well"], th["accent"] if v1 else th["dim"], 20, stroke=STROKE, size=11)
    save_lcd(cv, "09-item-set")


# ------------------------------------------------------------------ Deck style: Ball themes tab
DTABS = (("faceplate", "Faceplates"), ("pattern", "Backgrounds"), ("ballface", "Balls"))


def tab_ico(cv, name, cx, cy, s, color):
    if name == "ballface":
        u = s / 24
        cv.ell(cx, cy, 8.6 * u, stroke=color, sw=2 * u)
        cv.ell(cx - 3 * u, cy - 2 * u, 1.4 * u, fill=color)
        cv.ell(cx + 3 * u, cy - 2 * u, 1.4 * u, fill=color)
        cv.arc(cx, cy + .5 * u, 4.4 * u, 25, 155, color, 1.8 * u)
    else:
        _ico(cv, name, cx, cy, s, color)


_ico = R.ico
R.ico = tab_ico                                           # itabs draws through R.ico


def theme_status(cv, th, tid, x, y, have=128):
    t = THEMES[tid]
    if tid == EQUIPPED:
        cv.text(x, y, "IN USE", "b", 12, th["accent"], "lm", tracking=.6)
    elif tid in OWNED:
        icon(cv, "check", x + 6, y, 14, th["soft"])
        cv.text(x + 17, y, "Owned", "r", 12, th["soft"], "lm")
    else:
        ok = t["price"] <= have
        icon(cv, "star", x + 6, y - .5, 14, accent=STAR if ok else "#959BA5")
        cv.text(x + 17, y + .5, str(t["price"]), "monob", 13, th["star"] if ok else th["soft"], "lm")


def tier_row(cv, tid, cx, cy, px, gap=4, expr="idle"):
    ims = [sprite(t, tid, expr, px, pad=1, bloom=False) for t in range(1, 6)]
    if THEMES[tid].get("ears"):
        gap -= 4 * px / 2
    w = sum(im.width for im in ims) + gap * 4
    x = cx - w / 2
    for im in ims:
        paste_c(cv, im, x + im.width / 2, cy)
        x += im.width + gap
    return w


def mini_board(cv, rect, th, tid):
    """The theme where it will really show: a small live board."""
    x, y, w, h = rect
    cv.grad_rr(x, y, w, h, 10, [(0, mix(th["well"], th["accent"], .07)), (.6, th["well"]), (1, mix(th["well"], "#000000", .35))])
    cv.rr(x, y, w, h, 10, stroke=STROKE, sw=1)
    cv.refresh()
    cols = 64
    rows = round(cols * h / w)
    lcd = Lcd(cols, rows, clip=False)
    fl = rows - 1.5
    balls = heap((4, 3, 2, 3, 2, 1, 1, 2, 1, 1) if rows >= 34 else (3, 2, 3, 2, 1, 2, 1, 1), width=cols, floor=fl, banks=False)
    for i, (bx_, by_, t) in enumerate(balls):
        if by_ - rpx(t) > 2:
            lcd.ball(bx_, by_, t, tid, ("idle", "idle", "blink", "near", "idle", "sleepy")[i % 6])
    z = cv.z
    cv.paste(lcd.image(size=(round(w * z), round(h * z))), round(x * z), round(y * z), raw=True)
    cv.refresh()


def themes_desktop(th, sel="kitten"):
    cv = R.dpanel(th)
    R.header(cv, 24, 824, 44, "Deck style", th, 44, 26, eyebrow="Pocket Deck", ey=14)
    R.itabs(cv, 24, 84, 800, 44, DTABS, 2, th, 16)
    t = THEMES[sel]
    card(cv, 24, 144, 328, 392, th)
    mini_board(cv, (40, 160, 296, 176), th, sel)
    cv.text(40, 362, t["name"], "b", 24, th["text"], "lm")
    chip(cv, 336, 349, t["tier"], th["well"], hx(R.TIERCOL[t["tier"]]), 26, anchor="r", stroke=STROKE)
    cv.text(40, 390, t["pitch"], "r", 14, th["soft"], "lm")
    cv.text(40, 412, "Same sizes, same rules. Looks only.", "r", 14, th["dim"], "lm")
    for j in range(5):
        dot(cv, 56 + j * 34, 440, 26, j + 1, sel)
    cv.text(40 + 5 * 34 + 8, 440.5, "in goals and quests", "r", 13, th["dim"], "lm")
    button(cv, 40, 464, 288, 56, f"Buy  {t['price']}", th, "primary", key="A", ico="star")
    for i, tid in enumerate(ORDER):
        x, y = 371 + (i % 2) * 231, 147 + (i // 2) * 131
        f = tid == sel
        cv.rr(x, y, 222, 122, 12, fill=th["selected"] if f else th["raised"])
        cv.rr(x, y, 222, 122, 12, stroke=th["accent"] if f else STROKE, sw=2 if f else 1)
        cv.rr(x + 8, y + 8, 206, 70, 10, fill=th["well"])
        tier_row(cv, tid, x + 111, y + 43, 2, 0)
        cv.text(x + 12, y + 93, THEMES[tid]["name"], "b", 15, th["text"], "lm")
        theme_status(cv, th, tid, x + 12, y + 110)
        chip(cv, x + 212, y + 91, THEMES[tid]["tier"], th["well"], hx(R.TIERCOL[THEMES[tid]["tier"]]), 20, anchor="r", stroke=STROKE, size=11)
        if f:
            cv.glow_ring(x - 4, y - 4, 230, 130, 16)
    hints(cv, 24, 572, [("+", "Browse"), ("LB", "Tab"), ("A", "Buy or use"), ("B", "Back")], th, right="Fixed prices. Looks only, never an advantage.")
    return cv


def themes_phone(th, sel="gem"):
    cv = R.psheet(th, "Deck style")
    R.itabs(cv, 20, 124, 528, 36, DTABS, 2, th, 14)
    t = THEMES[sel]
    card(cv, 560, 124, 232, 210, th)
    mini_board(cv, (572, 134, 208, 84), th, sel)
    cv.text(572, 236, fit(cv, t["name"], 130, "b", 18), "b", 18, th["text"], "lm")
    chip(cv, 780, 225, t["tier"], th["well"], hx(R.TIERCOL[t["tier"]]), 22, anchor="r", stroke=STROKE, size=12)
    for j in range(5):
        dot(cv, 582 + j * 24, 259, 18, j + 1, sel)
    cv.text(700, 259.5, "in goals", "r", 12, th["dim"], "lm")
    button(cv, 572, 278, 208, 44, f"Buy  {t['price']}", th, "primary", size=16, ico="star")
    for i, tid in enumerate(ORDER):
        x, y = 23 + (i % 3) * 175, 175 + (i // 3) * 76
        f = tid == sel
        cv.rr(x, y, 169, 68, 12, fill=th["selected"] if f else th["raised"])
        cv.rr(x, y, 169, 68, 12, stroke=th["accent"] if f else STROKE, sw=2 if f else 1)
        cv.rr(x + 6, y + 6, 157, 34, 8, fill=th["well"])
        tier_row(cv, tid, x + 84, y + 23, 1, 5)
        cv.text(x + 10, y + 53, fit(cv, THEMES[tid]["name"], 84, "b", 13), "b", 13, th["text"], "lm")
        tw = 62 if tid == EQUIPPED else (60 if tid in OWNED else 40)
        theme_status(cv, th, tid, x + 169 - tw - 6, y + 53)
        if f:
            cv.glow_ring(x - 3, y - 3, 175, 74, 15)
    return cv


# ------------------------------------------------------------------ stats for the scope
def stats():
    print("LCD", LCD_W, "x", LCD_H, "| ball diameters in LCD px:", [round(rpx(t) * 2, 1) for t in range(1, 6)])
    print("fill line LCD rows:", {k: round(world_y(v), 1) for k, v in LINE.items()})
    print("\nSpan model (runs of equal tone per row; a Python mirror of shade(), not a Studio measurement)")
    for name, scene in (("calm 12 + held", CALM), ("tall 27 + held", TALL), ("stress 32 + held", STRESS)):
        today = draw_scene(scene, "plain", faces=False, lean=False).spans()
        naive = draw_scene(scene, "smiley", faces=True, lean=False).spans()
        lean = draw_scene(scene, "smiley", faces=True, lean=True).spans()
        row = [f"{name:18s} today(motifs) {today:5d} | faces, same shading {naive:5d} ({naive - today:+d}) | faces + lean small balls {lean:5d} ({lean - today:+d})"]
        for tid in ("gumdrop", "gem", "planet", "kitten"):
            row.append(f"{tid} {draw_scene(scene, tid).spans() - today:+d}")
        print("  " + " | ".join(row))
    print("\nPer ball, alone (spans incl. bloom): tier: today / faces naive / faces lean / worst expression")
    for t in range(1, 6):
        def one(theme, faces, lean, expr="idle"):
            l = Lcd(40, 40, clip=False)
            l.ball(20, 20, t, theme, expr, faces, lean)
            return l.spans()
        worst = max(one("smiley", True, True, e) for e in EXPR)
        print(f"  {t}: {one('plain', False, False)} / {one('smiley', True, False)} / {one('smiley', True, True)} / {worst}")
    print("\nColour distance between tier body colours (CIE76 dE). adj = closest neighbouring sizes, any = closest pair")
    for tid, kind, adj, worst in cvd_table():
        print(f"  {tid:8s} {kind:7s} adj {adj:5.1f}  any {worst[0]:5.1f} (tiers {worst[1]}, {worst[2]})")
    print("\nContrast of face ink on the body colour (WCAG ratio)")
    from common import contrast
    for tid in ORDER:
        if THEMES[tid]["face"] != "none":
            print(f"  {tid:8s}", [round(contrast(hx(THEMES[tid]['ink']), hx(r[0])), 1) for r in THEMES[tid]["ramps"]])


def main():
    th = kit_theme("sherbet")
    if "--stats" in sys.argv:
        stats()
        return
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    def want(n):
        return not only or any(n.startswith(o) for o in only)
    if want("01"):
        save_lcd(round_desktop(th, "calm", belt=True, open_=True), "01-item-carousel-desktop-848x608")
    if want("02"):
        cv, _ = round_phone(th, "calm", True, True)
        save_phone(cv, "02-item-carousel-phone-812x354")
    if want("03"):
        board_strip(th)
    if want("04"):
        save_lcd(round_desktop(th, "calm", belt=True), "04-round-circles-calm-desktop-848x608")
        save_lcd(round_desktop(th, "danger", belt=True), "04-round-circles-danger-desktop-848x608")
        save_lcd(round_desktop(th, "calm", belt=False, theme="plain", marks=True, faces=False, old_text=True), "04-round-today-desktop-848x608")
        cv, _ = round_phone(th, "calm", True, False)
        save_phone(cv, "04-round-circles-calm-phone-812x354")
        cv, _ = round_phone(th, "danger", True, False)
        save_phone(cv, "04-round-circles-danger-phone-812x354")
    if want("05"):
        save_lcd(themes_desktop(th), "05-deck-style-ball-themes-desktop-848x608")
        save_phone(themes_phone(th), "05-deck-style-ball-themes-phone-812x354")
    if want("06"):
        theme_strip(th)
    if want("07"):
        expression_sheet(th)
    if want("08"):
        cvd_sheet(th)
    if want("09"):
        item_sheet(th)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
