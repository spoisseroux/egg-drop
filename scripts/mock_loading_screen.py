"""PIL mock of the join loading screen (src/first/LoadingScreen.client.lua) for art review.

Follows the script's layout maths (sizes by screen height, five pals on one baseline, checker under a
sky-coloured veil) with the packed sheet assets/ui/loading/loading-pals.png. Not a Roblox capture.

  python scripts/mock_loading_screen.py            # 1280x720 and 844x390 into artifacts/loading-screen-2026-11-25/
"""
import glob, math, os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

REPO = Path(__file__).resolve().parents[1]
OUT = REPO / "artifacts" / "loading-screen-2026-11-25"
SHEET = REPO / "assets" / "ui" / "loading" / "loading-pals.png"
CW, CH, BEAR, FEET, PALS, CENTRE = 204, 256, 0.726, 10 / 256, 5, 1.12   # as Sheet in LoadingScreen.client.lua
SKY = [(0, (0xF4, 0xA3, 0xBC)), (0.6, (0xFF, 0xC2, 0xA6)), (1, (0xFF, 0xE2, 0xB8))]
INK, STATUS = (0x8A, 0x3F, 0x5C), (0x6B, 0x30, 0x49)


def font(name, size):
    for path in sorted(glob.glob(os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions\*\content\fonts\\" + name))):
        return ImageFont.truetype(path, size)
    return ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", size)


def by(h, phone, hd, full):
    if h <= 720:
        return phone + (hd - phone) * min(1, max(0, (h - 390) / 330))
    return hd + (full - hd) * min(1, max(0, (h - 720) / 360))


def sky_at(t):
    for (a, ca), (b, cb) in zip(SKY, SKY[1:]):
        if t <= b:
            k = (t - a) / (b - a)
            return tuple(round(ca[i] + (cb[i] - ca[i]) * k) for i in range(3))
    return SKY[-1][1]


def mock(W, H, frames, progress, status, shift=0.4):
    im = Image.new("RGBA", (W, H))
    d = ImageDraw.Draw(im)
    for y in range(H):
        d.line([(0, y), (W, y)], fill=sky_at(y / (H - 1)))
    # Checker: 2x2 white squares per tile at .82 transparency, then the veil (sky colour, 1 -> .35 transparency).
    tile = math.floor(by(H, 32, 40, 48)); half = tile // 2; off = round(-tile + tile * shift)
    check = Image.new("RGBA", (W, H), (0, 0, 0, 0)); cd = ImageDraw.Draw(check)
    a = round(255 * (1 - 0.82))
    for ty in range(off, H, tile):
        for tx in range(off, W, tile):
            cd.rectangle([tx, ty, tx + half - 1, ty + half - 1], fill=(255, 255, 255, a))
            cd.rectangle([tx + half, ty + half, tx + tile - 1, ty + tile - 1], fill=(255, 255, 255, a))
    im.alpha_composite(check)
    veil = Image.new("RGBA", (W, H)); vd = ImageDraw.Draw(veil)
    for y in range(H):
        t = y / (H - 1)
        vd.line([(0, y), (W, y)], fill=sky_at(t) + (round(255 * (1 - (1 + (0.35 - 1) * t))),))
    im.alpha_composite(veil)
    # Column.
    cell_h = by(H, 112, 168, 215) / BEAR; cell_w = cell_h * CW / CH; step = math.floor(cell_w * 0.7)
    title_h = math.floor(by(H, 46, 84, 96)); gap = math.floor(by(H, 8, 10, 10)); row_h = math.floor(cell_h * CENTRE)
    width = math.floor(min(W * 0.92, 1000)); status_h = math.floor(by(H, 18, 22, 24))
    col_h = title_h + row_h + 14 + status_h + 3 * gap
    print(f"{W}x{H}: column {col_h} px tall, bear {round(cell_h * BEAR)} px, row {4 * step + round(cell_w * CENTRE)} px wide")
    y = (H - col_h) // 2; cx = W // 2
    f = font("FredokaOne-Regular.ttf", title_h)
    while d.textlength("Hatch a Handheld Pal", font=f) > width and f.size > 10:
        f = font("FredokaOne-Regular.ttf", f.size - 2)
    d = ImageDraw.Draw(im)
    stroke = 3 if H < 600 else 4
    ink_a = Image.new("RGBA", (W, H)); ImageDraw.Draw(ink_a).text((cx, y + title_h / 2), "Hatch a Handheld Pal", font=f, anchor="mm",
                                                                   fill=(255, 255, 255), stroke_width=stroke, stroke_fill=INK + (204,))
    im.alpha_composite(ink_a)
    y += title_h + gap
    sheet = Image.open(SHEET).convert("RGBA")
    base = y + row_h
    order = sorted(range(PALS), key=lambda i: -abs(i - 2))      # outer pals first, centre on top
    shadows = Image.new("RGBA", (W, H)); sd = ImageDraw.Draw(shadows)
    for i in range(PALS):
        k = CENTRE if i == 2 else 1
        x = cx + (i - 2) * step; sw = math.floor(cell_w * k * 0.34); sh = max(6, math.floor(cell_h * k * 0.06))
        sy = base - math.floor(cell_h * k * FEET)
        sd.ellipse([x - sw / 2, sy - sh / 2, x + sw / 2, sy + sh / 2], fill=INK + (round(255 * 0.2),))
    im.alpha_composite(shadows)
    for i in order:
        k = CENTRE if i == 2 else 1
        w, h = math.floor(cell_w * k), math.floor(cell_h * k)
        x = cx + (i - 2) * step
        bob = (math.sin((0.3 + i * 0.17) * math.pi * 2) * 0.5 + 0.5) * 4 * h / 230
        cell = sheet.crop((i * CW, frames[i] * CH, (i + 1) * CW, (frames[i] + 1) * CH)).resize((w, h), Image.LANCZOS)
        im.alpha_composite(cell, (round(x - w / 2), round(base - h - bob)))
    y = base + gap
    bar = min(math.floor(by(H, 300, 420, 420)), width)
    d = ImageDraw.Draw(im)
    track = Image.new("RGBA", (W, H)); td = ImageDraw.Draw(track)
    td.rounded_rectangle([cx - bar / 2, y, cx + bar / 2, y + 14], 7, fill=(0x0E, 0x0F, 0x12, round(255 * 0.45)))
    im.alpha_composite(track)
    d.rounded_rectangle([cx - bar / 2, y, cx - bar / 2 + bar * progress, y + 14], 7, fill=(0x76, 0xF6, 0xB0))
    y += 14 + gap
    d.text((cx, y + status_h / 2), status, font=font("BuilderSans-Bold.otf", status_h), anchor="mm", fill=STATUS)
    return im.convert("RGB")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for (w, h) in ((1280, 720), (844, 390)):
        path = OUT / f"mock-{w}x{h}.png"
        mock(w, h, [0, 1, 1, 0, 1], 0.58, "Fluffing the clouds\u2026").save(path)
        print("MOCK", path)
    # Both wave frames of every pal at their 720p size, out above in, on the sky's middle colour.
    sheet = Image.open(SHEET).convert("RGBA")
    ch = round(168 / BEAR); cw = round(ch * CW / CH)
    strip = Image.new("RGBA", (cw * PALS, ch * 2), sky_at(0.45) + (255,))
    for r in range(2):
        for i in range(PALS):
            cell = sheet.crop((i * CW, r * CH, (i + 1) * CW, (r + 1) * CH)).resize((cw, ch), Image.LANCZOS)
            strip.alpha_composite(cell, (i * cw, r * ch))
    strip.convert("RGB").save(OUT / "wave-frames-720p.png")
    print("FRAMES", OUT / "wave-frames-720p.png")
