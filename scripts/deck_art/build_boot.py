"""Pocket Deck boot animation: two sprite sheets, timing JSON, a storyboard and a GIF preview.

Run: python scripts/deck_art/build_boot.py
Frames are 212 x 152 pixel art (the LCD is 848 x 608 units, so 4 units per pixel, nearest-neighbour).
Two sheets with identical frame rects:
  boot-sheet-fixed.png  background, scan rows, gold egg, sparkles, white flash. Never tinted.
  boot-sheet-ink.png    white pixels for the scanline, wordmark and sub-line. Tint with the faceplate accent.
The wordmark and the sequence are original; there is no third-party logo, boot screen or jingle here.
"""
from __future__ import annotations

import json

from PIL import Image, ImageDraw

from common import ASSETS, MOCKUPS, Cv, hx, small_text_cells, wordmark_cells, WORD_H, WORD_W, TEXT, SOFT, DIM

OUT = ASSETS / "boot"
FW, FH = 212, 152
COLS, ROWS = 4, 6
PX = 3                                    # wordmark cell size in frame pixels
WX, WY = (FW - WORD_W * PX) // 2, 44      # resting wordmark position
BG, ROW = (12, 13, 16, 255), (19, 21, 27, 255)
GOLD, GOLD_D, GLINT = (255, 193, 77, 255), (224, 138, 30, 255), (255, 243, 196, 255)
WHITE = (255, 255, 255, 255)

# the O in POCKET, in frame pixels, when the wordmark is at rest
O_CELLS = [(c, r, k) for c, r, k in wordmark_cells() if k in ("egg", "glint")]
O_X = WX + min(c for c, _, _ in O_CELLS) * PX
O_Y = WY + min(r for _, r, _ in O_CELLS) * PX
EGG = ["..##..", ".####.", ".####.", "######", "######", "######", ".####."]
EGG_SQUASH = ["........", "........", "..####..", ".######.", "########", "########", ".######."]
EGG_STRETCH = [".##.", ".##.", "####", "####", "####", "####", "####", ".##."]


def new():
    return Image.new("RGBA", (FW, FH), (0, 0, 0, 0)), Image.new("RGBA", (FW, FH), (0, 0, 0, 0))


def lit(fixed, y0, y1):
    d = ImageDraw.Draw(fixed)
    d.rectangle([0, 0, FW, FH], fill=(4, 4, 6, 255))
    d.rectangle([0, y0, FW, y1], fill=BG)
    for y in range(y0, y1 + 1, 2):
        d.line([(0, y), (FW, y)], fill=ROW)


def cells(img, grid, x, y, col, glint_at=None, shade=True):
    d = ImageDraw.Draw(img)
    h = len(grid)
    for gy, line in enumerate(grid):
        for gx, ch in enumerate(line):
            if ch == "#":
                c = col
                if shade and col == GOLD and gy >= h - 2:
                    c = GOLD_D
                d.rectangle([x + gx * PX, y + gy * PX, x + gx * PX + PX - 1, y + gy * PX + PX - 1], fill=c)
    if glint_at:
        gx, gy = glint_at
        d.rectangle([x + gx * PX, y + gy * PX, x + gx * PX + PX - 1, y + gy * PX + PX - 1], fill=GLINT)


def wordmark(fixed, ink, dy, flash=False, squash=0):
    df, di = ImageDraw.Draw(fixed), ImageDraw.Draw(ink)
    for c, r, kind in wordmark_cells():
        x = WX + c * PX
        y = WY + dy + r * PX - (squash if r < 7 else 0) * 0 + (squash * (1 if r < 7 else 0))
        box = [x, y, x + PX - 1, y + PX - 1]
        if kind == "ink":
            (df if flash else di).rectangle(box, fill=WHITE)
        else:
            col = WHITE if flash else (GLINT if kind == "glint" else (GOLD_D if r >= 5 else GOLD))
            df.rectangle(box, fill=col)


def sparkle(fixed, x, y, stage):
    d = ImageDraw.Draw(fixed)
    arm = {1: 2, 2: 6, 3: 3}[stage]
    d.rectangle([x - 1, y - 1, x + 1, y + 1], fill=WHITE)
    for i in range(2, arm + 1):
        a = 255 if i < arm else 170
        for dx, dy in ((i, 0), (-i, 0), (0, i), (0, -i)):
            d.point((x + dx, y + dy), fill=(255, 255, 255, a))
            if i <= arm // 2:
                d.point((x + dx + (dy != 0), y + dy + (dx != 0)), fill=(255, 255, 255, a))
    if stage == 2:
        for dx, dy in ((3, 3), (-3, 3), (3, -3), (-3, -3)):
            d.point((x + dx, y + dy), fill=(255, 255, 255, 200))


def subline(ink, dither):
    pts, w = small_text_cells("EGG DROP")
    s = 2
    x0, y0 = (FW - w * s) // 2, WY + WORD_H * PX + 12
    d = ImageDraw.Draw(ink)
    for cx, cy in pts:
        for ax in range(s):
            for ay in range(s):
                X, Y = x0 + cx * s + ax, y0 + cy * s + ay
                if not dither or (X + Y) % 2 == 0:
                    d.point((X, Y), fill=(255, 255, 255, 200))


def dissolve(img, level):
    """Ordered 2x2 dither on 4 px blocks. level 1 removes half the blocks, level 2 three quarters."""
    px = img.load()
    order = {(0, 0): 0, (1, 1): 1, (1, 0): 2, (0, 1): 3}
    for y in range(FH):
        for x in range(FW):
            if order[((x // 4) % 2, (y // 4) % 2)] < level * 2 - (1 if level == 2 else 0) + (0 if level == 1 else 0):
                px[x, y] = (0, 0, 0, 0)


def build():
    frames, mid = [], FH // 2
    spark_a = (WX + WORD_W * PX + 4, WY - 4)
    spark_b = (WX - 7, WY + WORD_H * PX + 2)

    def add(ms, fn, note):
        f, i = new()
        fn(f, i)
        # ink never covers a foreground fixed pixel
        frames.append((f, i, ms, note))

    add(80, lambda f, i: ImageDraw.Draw(f).rectangle([0, 0, FW, FH], fill=(4, 4, 6, 255)), "glass black")

    def line(f, i, half):
        ImageDraw.Draw(f).rectangle([0, 0, FW, FH], fill=(4, 4, 6, 255))
        ImageDraw.Draw(i).rectangle([FW // 2 - half, mid - 1, FW // 2 + half, mid], fill=WHITE)
    add(50, lambda f, i: line(f, i, 30), "scanline starts")
    add(50, lambda f, i: line(f, i, FW), "scanline full width")

    def open_(f, i, h):
        lit(f, mid - h, mid + h)
        d = ImageDraw.Draw(i)
        d.rectangle([0, mid - h - 1, FW, mid - h], fill=WHITE)
        d.rectangle([0, mid + h, FW, mid + h + 1], fill=WHITE)
    add(50, lambda f, i: open_(f, i, 22), "wipe opens")
    add(50, lambda f, i: open_(f, i, 54), "wipe opens")
    add(50, lambda f, i: lit(f, 0, FH), "screen on")
    ex = O_X
    land = O_Y
    for ms, y in ((60, -6), (60, land - 46), (60, land - 20)):
        add(ms, lambda f, i, y=y: (lit(f, 0, FH), cells(f, EGG, ex, y, GOLD, (2, 2))), "egg falls")
    add(70, lambda f, i: (lit(f, 0, FH), cells(f, EGG_SQUASH, ex - PX, land, GOLD, (2, 3))), "egg lands and squashes")
    add(60, lambda f, i: (lit(f, 0, FH), cells(f, EGG_STRETCH, ex + PX, land - 2 * PX, GOLD, (1, 2))), "egg rebounds")

    def pop(f, i):
        lit(f, 0, FH)
        d = ImageDraw.Draw(f)
        cx, cy = ex + 3 * PX, land + 3 * PX
        for dx, dy in ((0, -14), (10, -10), (14, 0), (10, 10), (0, 14), (-10, 10), (-14, 0), (-10, -10)):
            d.rectangle([cx + dx - 1, cy + dy - 1, cx + dx + 1, cy + dy + 1], fill=GOLD)
        for dx, dy in ((0, -7), (7, 0), (0, 7), (-7, 0)):
            d.rectangle([cx + dx - 1, cy + dy - 1, cx + dx + 1, cy + dy + 1], fill=GLINT)
    add(70, pop, "egg pops")
    for ms, dy, note in ((50, -70, "wordmark drops in"), (50, -26, "wordmark drops in"), (60, 6, "wordmark lands (overshoot)"), (50, -3, "bounce up")):
        add(ms, lambda f, i, dy=dy: (lit(f, 0, FH), wordmark(f, i, dy)), note)
    add(60, lambda f, i: (lit(f, 0, FH), wordmark(f, i, 0, flash=True)), "white flash")
    add(70, lambda f, i: (lit(f, 0, FH), wordmark(f, i, 0), sparkle(f, *spark_a, 1)), "settles to the accent, sparkle")
    add(70, lambda f, i: (lit(f, 0, FH), wordmark(f, i, 0), sparkle(f, *spark_a, 2), subline(i, True)), "sparkle peak, sub-line dithers in")
    add(70, lambda f, i: (lit(f, 0, FH), wordmark(f, i, 0), sparkle(f, *spark_a, 3), sparkle(f, *spark_b, 1), subline(i, False)), "second sparkle")
    add(70, lambda f, i: (lit(f, 0, FH), wordmark(f, i, 0), sparkle(f, *spark_b, 2), subline(i, False)), "second sparkle peak")
    add(250, lambda f, i: (lit(f, 0, FH), wordmark(f, i, 0), subline(i, False)), "hold")
    for lvl in (1, 2):
        def fade(f, i, lvl=lvl):
            lit(f, 0, FH)
            wordmark(f, i, 0)
            subline(i, False)
            dissolve(f, lvl)
            dissolve(i, lvl)
        add(80, fade, "dither dissolve to the start screen")
    return frames


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    frames = build()
    assert len(frames) <= COLS * ROWS, len(frames)
    sheets = {"fixed": Image.new("RGBA", (FW * COLS, FH * ROWS), (0, 0, 0, 0)), "ink": Image.new("RGBA", (FW * COLS, FH * ROWS), (0, 0, 0, 0))}
    rows, t = [], 0
    for n, (f, i, ms, note) in enumerate(frames):
        x, y = (n % COLS) * FW, (n // COLS) * FH
        sheets["fixed"].paste(f, (x, y))
        sheets["ink"].paste(i, (x, y))
        rows.append({"index": n, "rect": [x, y, FW, FH], "startMs": t, "durationMs": ms, "note": note})
        t += ms
    sheets["fixed"].save(OUT / "boot-sheet-fixed.png")
    sheets["ink"].save(OUT / "boot-sheet-ink.png")
    land = next(r for r in rows if "lands (overshoot)" in r["note"])
    egg_land = next(r for r in rows if "egg lands" in r["note"])
    egg_pop = next(r for r in rows if "pops" in r["note"])
    hold = next(r for r in rows if r["note"] == "hold")
    doc = {
        "schema": 1, "name": "Pocket Deck boot", "totalMs": t,
        "frameSize": [FW, FH], "columns": COLS, "rows": ROWS, "frameCount": len(rows),
        "sheets": {"fixed": {"file": "boot-sheet-fixed.png", "tint": None, "z": 1},
                   "ink": {"file": "boot-sheet-ink.png", "tint": "faceplate accent (ImageColor3)", "z": 2}},
        "display": {
            "parent": "the LCD frame (rect lcd in assets/deck/shell/shell.json), above every screen, below glass-glare",
            "size": "UDim2.fromScale(1, 1): 212 x 152 art on the 848 x 608 LCD is exactly 4 units per pixel",
            "resampleMode": "Enum.ResamplerMode.Pixelated",
            "perFrame": "set ImageRectOffset = rect.xy and ImageRectSize = rect.wh on both ImageLabels at startMs; drive from one clock (os.clock), not chained task.wait, so a slow frame cannot stretch the boot",
            "end": "after the last frame hide both labels; the start screen is already laid out underneath and input goes live",
        },
        "sound": [
            {"cue": "deck_boot", "atMs": land["startMs"], "frame": land["index"], "required": True,
             "note": "the one boot sound: starts on the frame the wordmark lands. A short rising three-note chime (about 0.45 s) so its tail covers the flash and sparkles. Original; not any console's jingle."},
            {"cue": "drop", "atMs": egg_land["startMs"], "frame": egg_land["index"], "required": False, "note": "optional: the existing BoardAudio drop 'plip' at 60% volume"},
            {"cue": "merge_bubble", "atMs": egg_pop["startMs"], "frame": egg_pop["index"], "required": False, "note": "optional: the existing merge bubble at 60% volume"},
        ],
        "skip": {"fromMs": 150, "action": "any input jumps to the end: hide both labels, stop deck_boot with a 60 ms fade, input goes live"},
        "reducedEffects": {"show": hold["index"], "holdMs": 400, "sound": "deck_boot at 0 ms, normal volume", "note": "no motion: the finished logo, then hide"},
        "playsWhen": "only on a real arrival at the deck (first board or a deliberate garden to deck entry). Never over results, a menu or a replay. Reuse the existing Transition:owns token so a route change cancels pending frames and the sound.",
        "frames": rows,
    }
    (OUT / "boot-timing.json").write_text(json.dumps(doc, indent=1), newline="\n")

    # ---- review material
    accent = hx("#76F6B0")

    def comp(f, i, scale):
        base = Image.new("RGBA", (FW, FH), (12, 13, 16, 255))
        base.alpha_composite(f)
        ti = Image.new("RGBA", (FW, FH), accent[:3] + (0,))
        ti.putalpha(i.getchannel("A"))
        base.alpha_composite(ti)
        return base.resize((FW * scale, FH * scale), Image.NEAREST)

    cols = 6
    cw, chh = FW * 2 + 24, FH * 2 + 64
    cv = Cv(40 + cols * cw + 16, 130 + 4 * chh, z=1, bg=hx("#0B0C10"))
    cv.text(40, 28, "Pocket Deck boot: %d frames, %.2f s" % (len(rows), t / 1000), "xb", 36, TEXT)
    cv.text(40, 76, "Shown with the Scout accent. deck_boot starts at %d ms (frame %d, the wordmark lands). Any input from 150 ms skips." % (land["startMs"], land["index"]), "r", 19, SOFT)
    for n, (f, i, ms, note) in enumerate(frames):
        x, y = 40 + (n % cols) * cw, 120 + (n // cols) * chh
        cv.paste(comp(f, i, 2), x, y, raw=True)
        cv.rr(x, y, FW * 2, FH * 2, 0, stroke=(255, 255, 255, 40))
        cv.text(x, y + FH * 2 + 8, "%02d  %d ms  +%d" % (n, rows[n]["startMs"], ms), "monob", 15, TEXT)
        cv.text(x, y + FH * 2 + 30, note, "r", 15, DIM)
    MOCKUPS.mkdir(parents=True, exist_ok=True)
    cv.out().save(MOCKUPS / "boot-storyboard.png")
    gif = [comp(f, i, 3).convert("P", palette=Image.ADAPTIVE) for f, i, _, _ in frames]
    gif[0].save(MOCKUPS / "boot-preview.gif", save_all=True, append_images=gif[1:], duration=[ms for _, _, ms, _ in frames] + [], loop=0, disposal=2)
    print("boot frames", len(rows), "total ms", t, "deck_boot at", land["startMs"])


if __name__ == "__main__":
    main()
