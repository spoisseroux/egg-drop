"""QA-R2-LOOK 6: the ground flower patches redrawn to sit in the lawn (Fable, 2026-11-23).

Same generator, seeds and layouts as scripts/build_world_v7_dressing_art.py (so the placer and the patch sizes do not
change); only the paint changes:
  - the leaf rosettes take the GRADED lawn colour (the world pass grades W1_grass hue +4, S x.80, V x.70; the first
    patches were painted against the ungraded #2DA83A, which is why they glare), within +-12% value of it, 80% alpha;
  - no dark ink outline: a petal's rim is its own colour at 78% value, a leaf has no rim;
  - petals: saturation x.70 (cap .58), value x.86 (cap .86); no pure white (#FFFFFF -> #E2DFCB);
  - heads 85% of the size, 6 a patch instead of 8;
  - smooth 4x downsample from a 1024 render instead of nearest-neighbour blocks, and a soft alpha edge.
Writes flower_patch_<kind>.png (256 px, RGBA) and before-after.png beside this file. Uploads nothing.
Run: python artifacts/qa-2026-11-23-beta12/look/r2/draw_flower_patches_r2.py
"""
import colorsys, importlib.util, math, random
from pathlib import Path
from PIL import Image, ImageFilter

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
spec = importlib.util.spec_from_file_location("art", ROOT / "scripts" / "build_world_v7_dressing_art.py")
art = importlib.util.module_from_spec(spec); spec.loader.exec_module(art)

def rgb(h): return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))
def hexs(c): return "#%02X%02X%02X" % tuple(c)
def hsv(c): return colorsys.rgb_to_hsv(*(v / 255 for v in c))
def from_hsv(h, s, v): return tuple(round(max(0, min(1, x)) * 255) for x in colorsys.hsv_to_rgb(h % 1, s, v))

def grade_lawn(c):  # the world pass's W1_grass row
    h, s, v = hsv(c)
    return from_hsv(h + 4 / 360, s * .80, v * .70)

LAWN_RAW = rgb("#2DA83A")
LAWN = grade_lawn(LAWN_RAW)
LH, LS, LV = hsv(LAWN)
LEAF = {"leaf": from_hsv(LH, LS, LV * 1.06), "leaf_d": from_hsv(LH, LS * 1.05, LV * .90), "leaf_l": from_hsv(LH - 6 / 360, LS * .95, LV * 1.12)}
LEAF_ALPHA, HEAD_SCALE, HEADS = 204, .85, 6

def petal(c):
    h, s, v = hsv(c)
    if s < .12:  # whites: warm, never pure
        return from_hsv(52 / 360, .10 + s * .3, min(v * .886, .886))
    return from_hsv(h, min(s * .70, .58), min(v * .86, .86))

PAL = {k: (LEAF[k] if k in LEAF else petal(rgb(v))) for k, v in art.PAL.items()}
RIM = {k: (None if k in LEAF else tuple(round(x * .78) for x in PAL[k])) for k in PAL}

def patch(kind, seed):
    """art.patch with smaller, fewer heads; the same random stream order, so layouts stay in family."""
    rng = random.Random(seed)
    g = art.Grid()
    heads = []
    for _ in range(400):
        if len(heads) >= HEADS: break
        a, d = rng.uniform(0, math.tau), 22 * math.sqrt(rng.random())
        x, y = 32 + math.cos(a) * d, 32 + math.sin(a) * d
        s = rng.uniform(1.2, 1.6)
        if all(math.hypot(x - hx, y - hy) > 7.5 * max(s, hs) for hx, hy, hs, _ in heads):
            k = kind if rng.random() > .18 or kind == "daisy" else "daisy"
            heads.append((x, y, s, k))
    for x, y, s, _ in heads:
        for j in range(rng.randint(3, 5)):
            g.leaf(x, y, rng.uniform(0, math.tau), rng.uniform(5, 7.5) * s * .9, 1.5 * s * .9, "leaf_l" if j % 2 else "leaf", "leaf_d")
    for x, y, s, k in heads:
        art.head(g, k, x, y, s * HEAD_SCALE, rng)
    return g

def paint(g):
    G = art.G
    im = Image.new("RGBA", (G, G), (0, 0, 0, 0))
    for y in range(G):
        for x in range(G):
            col = g.c[y][x]
            if col:
                im.putpixel((x, y), PAL[col] + ((LEAF_ALPHA if col in LEAF else 255),))
                continue
            near = [g.c[y + dy][x + dx] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                    if 0 <= x + dx < G and 0 <= y + dy < G and g.c[y + dy][x + dx]]
            rims = [RIM[n] for n in near if RIM[n]]
            if rims: im.putpixel((x, y), rims[0] + (200,))
    # Smooth, not blocky: 16x nearest, a small blur, down to 256. Premultiplied so no dark fringe.
    big = im.resize((G * 16, G * 16), Image.NEAREST).convert("RGBa").filter(ImageFilter.GaussianBlur(5))
    return big.resize((256, 256), Image.LANCZOS).convert("RGBA")

def main():
    report = ["lawn raw %s -> graded %s (H %.0f S %.2f V %.2f)" % (hexs(LAWN_RAW), hexs(LAWN), LH * 360, LS, LV)]
    for k in art.PAL: report.append("%-9s %s -> %s" % (k, art.PAL[k], hexs(PAL[k])))
    sheet = Image.new("RGB", (len(art.KINDS) * 264 + 8, 2 * 264 + 8), LAWN)
    for i, kind in enumerate(art.KINDS):
        old = Image.open(ROOT / "assets" / "world" / "textures" / f"flower_patch_{kind}.png").convert("RGBA")
        new = paint(patch(kind, 7 + i * 31))
        new.save(HERE / f"flower_patch_{kind}.png")
        sheet.paste(old, (8 + i * 264, 8), old)
        sheet.paste(new, (8 + i * 264, 272), new)
    sheet.save(HERE / "before-after.png")
    (HERE / "palette.txt").write_text("\n".join(report) + "\n")
    print("\n".join(report))

if __name__ == "__main__":
    main()
