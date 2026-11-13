"""Round item icons (QA 2026-11-13 Q1 item 9): Swap, Pop, Bomb, Magnet.

House icon rules (UI-PERSONALITY T10): filled silhouettes, round ends, one highlight,
read at 20-24 px. Same shapes as the vector fallback in src/client/ItemIcons.lua.

Writes assets/ui/items/{swap,pop,bomb,magnet}.png, 128 x 128, transparent.
Run: python scripts/build_item_icons.py
Upload each, then put "rbxassetid://<id>" in src/shared/RoundItems.lua Items.IconImages.
Until then ItemIcons draws the vector version.
"""
import math
import os

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui", "items")
SIZE = 128
SS = 8
LIGHT = (243, 244, 246, 255)
INK = (14, 15, 18, 255)
SPARK = (255, 226, 122, 255)
COLORS = {"swap": "#3DDCC4", "pop": "#F5D54A", "bomb": "#FF9A3D", "magnet": "#FF6F8E"}


def hx(value, alpha=255):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4)) + (alpha,)


def mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


class Canvas:
    def __init__(self):
        self.img = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))

    def pill(self, cx, cy, w, h, color, rotation=0):
        """A rounded bar (scale units of the cell), rotated clockwise in degrees."""
        W, H = int(w * SIZE * SS), int(h * SIZE * SS)
        layer = Image.new("RGBA", (max(W, 1), max(H, 1)), (0, 0, 0, 0))
        ImageDraw.Draw(layer).rounded_rectangle([0, 0, W - 1, H - 1], radius=min(W, H) / 2, fill=color)
        layer = layer.rotate(-rotation, resample=Image.BICUBIC, expand=True)
        x = int(cx * SIZE * SS - layer.width / 2)
        y = int(cy * SIZE * SS - layer.height / 2)
        self.img.alpha_composite(layer, (x, y))

    def disc(self, cx, cy, d, color):
        self.pill(cx, cy, d, d, color)

    def save(self, name):
        os.makedirs(OUT, exist_ok=True)
        self.img.resize((SIZE, SIZE), Image.LANCZOS).save(os.path.join(OUT, name + ".png"))


def swap(cv, color, detail=True):
    for row in (0, 1):
        y = .35 if row == 0 else .65
        d = 1 if row == 0 else -1
        tip = .5 + d * .31
        cv.pill(.5 - d * .04, y, .58, .13, color)
        cv.pill(tip - d * .085, y - .085, .27, .13, color, d * 45)
        cv.pill(tip - d * .085, y + .085, .27, .13, color, -d * 45)
    if detail:
        cv.pill(.3, .35, .1, .05, LIGHT[:3] + (165,))


def pop(cv, color, detail=True):
    for i in range(4):
        cv.pill(.5, .5, .14, .86 if i % 2 == 0 else .66, color, i * 45)
    if detail:
        cv.disc(.5, .5, .43, color)
        cv.disc(.5, .5, .37, mix(color, LIGHT, .55))
        cv.disc(.43, .42, .1, LIGHT)
    else:
        cv.disc(.5, .5, .43, color)


def bomb(cv, color, detail=True):
    cv.disc(.45, .58, .66, color)
    cap = mix(color, INK, .45) if detail else color
    cv.pill(.66, .32, .2, .13, cap, 40)
    cv.pill(.76, .2, .05, .17, mix(color, INK, .6) if detail else color, 40)
    spark = SPARK if detail else color
    for r in (0, 90):
        cv.pill(.84, .12, .05, .22, spark, r)
    for r in (45, -45):
        cv.pill(.84, .12, .04, .14, spark, r)
    if detail:
        cv.pill(.32, .46, .14, .1, LIGHT[:3] + (180,), -30)


def magnet(cv, color, detail=True):
    cx, cy, r, t = .5, .56, .2, .2
    for x in (cx - r, cx + r):
        cv.pill(x, (.2 + cy) / 2, t, cy - .2, color)
        cv.pill(x, .21, t, .13, LIGHT if detail else color)
    for i in range(17):
        a = math.pi * i / 16
        cv.disc(cx + math.cos(a) * r, cy + math.sin(a) * r, t, color)
    if detail:
        cv.disc(cx - r - .02, cy + .08, .06, LIGHT[:3] + (165,))


def main():
    for name, fn in (("swap", swap), ("pop", pop), ("bomb", bomb), ("magnet", magnet)):
        color = hx(COLORS[name])
        cv = Canvas()
        sh = Canvas()
        fn(sh, (0, 0, 0, 70), False)
        cv.img.alpha_composite(sh.img, (0, int(SIZE * SS * .03)))
        fn(cv, color, True)
        cv.save(name)
        print("wrote", os.path.normpath(os.path.join(OUT, name + ".png")))


if __name__ == "__main__":
    main()
