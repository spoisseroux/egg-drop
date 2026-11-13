"""Retro flat flower sprites for the garden (FEEL-ALIVE-DIRECTION-2026-11-13.md, section C).

Five original flowers drawn on a 32 x 32 pixel grid and exported at 2x
(64 x 64, the game asset; a 256 x 256 nearest-neighbour copy is the upload size), plus one 320 x 64 atlas and a review sheet.
Transparent PNG, hard pixel edges, a darker selective outline, no gradients.
Deterministic: python artifacts/feel-alive-2026-11-13/build_sprites.py
"""
import math
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
OUT = HERE / "sprites"
G = 32  # logical pixels

# World v7 palette (assets/world/world-v7-palette.json) plus one shade of each.
PAL = {
    "stem": "#2FA83F", "stem_d": "#1F8338", "leaf": "#5FE89A", "leaf_d": "#35BE6E",
    "white": "#FFFFFF", "white_d": "#D9E6F7",
    "yellow": "#FFD84A", "yellow_d": "#F2B62E",
    "pink": "#FF6FAE", "pink_d": "#E04C93", "pink_l": "#FFC9DC",
    "lilac": "#A88BFF", "lilac_d": "#7F63DE", "lilac_l": "#D4C6FF",
    "aqua": "#35C7F5", "aqua_d": "#1E9FD6", "aqua_l": "#B8ECFF",
    "cream": "#FFF3D6",
}
NAMES = ["daisy", "tulip", "bellflower", "buttercup", "starbloom"]


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


class Grid:
    def __init__(self):
        self.c = [[None] * G for _ in range(G)]

    def px(self, x, y, col):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < G and 0 <= y < G:
            self.c[y][x] = col

    def disc(self, cx, cy, r, col, ry=None):
        ry = ry or r
        for y in range(G):
            for x in range(G):
                if ((x - cx) / r) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                    self.c[y][x] = col

    def line(self, x0, y0, x1, y1, col, w=1):
        n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
        for i in range(n + 1):
            t = i / n
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            for dx in range(w):
                self.px(x + dx, y, col)

    def curve(self, pts, col, w=1):
        for a, b in zip(pts, pts[1:]):
            self.line(a[0], a[1], b[0], b[1], col, w)

    def leaf(self, x0, y0, x1, y1, col, shade, fat=1.6):
        """A leaf from the stem (x0, y0) to its tip (x1, y1)."""
        n = 24
        for i in range(n + 1):
            t = i / n
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            r = fat * math.sin(math.pi * t) ** 0.8
            for yy in range(int(y - r), int(y + r) + 1):
                self.px(x, yy, shade if yy > y + r * 0.2 else col)

    def image(self, scale=2):
        im = Image.new("RGBA", (G, G), (0, 0, 0, 0))
        # Selective outline: an empty pixel touching colour takes a dark tone of it.
        for y in range(G):
            for x in range(G):
                col = self.c[y][x]
                if col:
                    im.putpixel((x, y), rgb(PAL[col]) + (255,))
                    continue
                near = None
                for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < G and 0 <= yy < G and self.c[yy][xx]:
                        near = self.c[yy][xx]
                        break
                if near:
                    r, g, b = rgb(PAL[near])
                    green = near.startswith(("stem", "leaf"))
                    k = (0.34, 0.46, 0.36) if green else (0.42, 0.34, 0.5)
                    im.putpixel((x, y), (int(r * k[0]), int(g * k[1]), int(b * k[2]), 255))
        return im.resize((G * scale, G * scale), Image.NEAREST)


def stem(g, x, top, base=30, lean=0.0):
    for y in range(top, base + 1):
        t = (base - y) / max(base - top, 1)
        g.px(x + lean * t * t, y, "stem")
        g.px(x + lean * t * t + 1, y, "stem_d")


def daisy():
    g = Grid()
    stem(g, 15, 15)
    g.leaf(15, 24, 8, 19, "leaf", "leaf_d", 1.8)
    g.leaf(17, 26, 24, 22, "leaf", "leaf_d", 1.8)
    cx, cy = 15.5, 10.5
    for k in range(6):
        a = k / 6 * math.tau + math.pi / 6
        g.disc(cx + math.cos(a) * 6.0, cy + math.sin(a) * 6.0, 2.55, "white_d" if math.sin(a) > 0.35 else "white")
    g.disc(cx, cy, 3.3, "yellow")
    g.disc(cx + 0.9, cy + 1.0, 1.7, "yellow_d")
    g.px(cx - 1, cy - 1, "cream")
    return g


def tulip():
    g = Grid()
    stem(g, 15, 14)
    g.leaf(15, 29, 7, 15, "leaf", "leaf_d", 2.2)
    g.leaf(17, 29, 25, 17, "leaf", "leaf_d", 2.2)
    cx = 15.5
    g.disc(cx, 10.5, 6.2, "pink", ry=6.6)
    for y in range(2, 9):                       # three petal tips: cut two notches
        for x in range(G):
            for nx in (cx - 3.2, cx + 3.2):
                if abs(x - nx) <= (8 - y) * 0.42 and g.c[y][x]:
                    g.c[y][x] = None
    for y in range(G):                          # shade the right side
        for x in range(G):
            if g.c[y][x] == "pink" and x - cx > 2.4 + (y - 10) * 0.1:
                g.c[y][x] = "pink_d"
    g.line(cx - 3, 8, cx - 3, 13, "pink_l")
    g.px(cx - 2, 7, "pink_l")
    return g


def bellflower():
    g = Grid()
    pts = [(12, 30), (12, 22), (13, 14), (16, 8), (21, 5), (26, 6)]
    g.curve(pts, "stem", 1)
    g.curve([(p[0] + 1, p[1]) for p in pts[:3]], "stem_d", 1)
    g.curve([(13, 15), (11, 12), (9, 12)], "stem", 1)
    g.leaf(12, 28, 4, 25, "leaf", "leaf_d", 1.9)
    g.leaf(13, 27, 21, 25, "leaf", "leaf_d", 1.7)
    for bx, by, s in ((27.0, 11.5, 0.9), (19.0, 12.0, 0.9), (8.5, 17.5, 0.8)):
        g.line(bx, by - 6 * s, bx, by - 3 * s, "stem")
        g.disc(bx, by, 3.4 * s, "lilac", ry=3.6 * s)
        for x in range(int(bx - 5 * s), int(bx + 5 * s) + 1):    # flared lip
            if abs(x - bx) <= 4.2 * s:
                g.px(x, by + 3 * s, "lilac_d")
        for dx in (-3, 0, 3):
            g.px(bx + dx * s, by + 4 * s, "lilac_d")
        g.px(bx - 1.6 * s, by - 1.4 * s, "lilac_l")
        g.px(bx - 1.6 * s, by - 0.4 * s, "lilac_l")
        g.px(bx + 2 * s, by + 0.5 * s, "lilac_d")
        g.px(bx + 2 * s, by + 1.5 * s, "lilac_d")
    return g


def bloom5(g, cx, cy, r, col, shade, centre, centre_d=None, pr=None):
    pr = pr or r * 0.52
    for k in range(5):
        a = -math.pi / 2 + k / 5 * math.tau
        g.disc(cx + math.cos(a) * r, cy + math.sin(a) * r, pr, shade if math.sin(a) > 0.2 else col)
    g.disc(cx, cy, r * 0.42, centre)
    if centre_d:
        g.px(cx + 1, cy + 1, centre_d)


def buttercup():
    g = Grid()
    stem(g, 11, 13, lean=-1.0)
    stem(g, 20, 19, lean=2.0)
    g.leaf(12, 27, 5, 23, "leaf", "leaf_d", 1.7)
    g.leaf(20, 28, 27, 25, "leaf", "leaf_d", 1.6)
    g.leaf(15, 30, 16, 23, "leaf", "leaf_d", 1.3)
    bloom5(g, 10.5, 9.5, 4.6, "yellow", "yellow_d", "cream", "yellow_d", pr=2.5)
    bloom5(g, 22.5, 15.5, 3.6, "yellow", "yellow_d", "cream", "yellow_d", pr=2.0)
    return g


def starbloom():
    g = Grid()
    stem(g, 15, 13)
    g.leaf(15, 28, 8, 25, "leaf", "leaf_d", 1.6)
    g.leaf(17, 25, 24, 21, "leaf", "leaf_d", 1.6)
    cx, cy = 15.5, 9.5
    for k in range(5):                           # five pointed petals
        a = -math.pi / 2 + k / 5 * math.tau
        for i in range(0, 15):
            t = i / 14
            w = 2.3 * (1 - t) + 0.3
            x, y = cx + math.cos(a) * t * 8.2, cy + math.sin(a) * t * 8.2
            g.disc(x, y, w, "aqua_d" if (math.sin(a) > 0.2 and t > 0.25) else "aqua")
    g.disc(cx, cy, 2.6, "white")
    g.px(cx, cy, "yellow")
    g.px(cx + 1, cy, "yellow")
    g.px(cx, cy + 1, "yellow_d")
    g.px(cx + 1, cy + 1, "yellow_d")
    g.px(cx - 2, cy - 4, "aqua_l")
    g.px(cx - 2, cy - 5, "aqua_l")
    return g


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    grids = [daisy(), tulip(), bellflower(), buttercup(), starbloom()]
    atlas = Image.new("RGBA", (64 * len(grids), 64), (0, 0, 0, 0))
    for i, (name, g) in enumerate(zip(NAMES, grids)):
        im = g.image(2)
        im.save(OUT / f"flower_{name}_64.png")
        g.image(8).save(OUT / f"flower_{name}_256.png")   # crisp upload size (nearest-neighbour 8x)
        atlas.paste(im, (64 * i, 0))
    atlas.save(OUT / "flower_atlas_320x64.png")
    # Review sheet: 6x on day grass and night grass, plus 1x game size.
    sheet = Image.new("RGBA", (5 * 208 + 16, 2 * 208 + 96), (255, 255, 255, 255))
    for row, grass in enumerate(("#27A836", "#0F4A2C")):
        band = Image.new("RGBA", (sheet.width, 208), rgb(grass) + (255,))
        sheet.paste(band, (0, row * 208))
        for i, g in enumerate(grids):
            big = g.image(6)
            sheet.alpha_composite(big, (16 + i * 208, row * 208 + 8))
    strip = Image.new("RGBA", (sheet.width, 96), rgb("#27A836") + (255,))
    sheet.paste(strip, (0, 416))
    for k in range(13):
        sheet.alpha_composite(grids[(k * 3) % 5].image(2), (16 + k * 80, 416 + 16))
    sheet.convert("RGB").save(HERE / "01-flower-sprites-sheet.png")
    print("sprites ->", OUT)


if __name__ == "__main__":
    main()
