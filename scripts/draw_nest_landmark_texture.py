"""The Sleepy Nest landmark's one 512 px texture (NEST-LANDMARK-LOOK, Fable 2026-11-24). Drawn from scratch with
numpy/PIL, fixed seed, no AI art: unglazed cream stoneware with an incised band of crescent moons and dots, a tide line
and two rim chips; leaf green with painted veins (and the duller awning leaf); the machine's collar lobe; deep garden
green; woven twig bark in the nest's four browns; straw; the peeled crook; paper moon with a sunflower edge; cord; a teal
quilt with cream squares, one sunflower star patch and a blanket-stitch edge; a coiled straw mat.

Atlas (pixel rectangles x0, y0, x1, y1; image y down). scripts/build_nest_landmark.py maps UVs into these (REGION):
  BOWL   (0, 0, 512, 128)     stoneware; u = half the way round (the bowl repeats it twice), v = 0 at the rim (1.75 up)
                              to 1 at the foot (0.35 up). The band is 1.0 to 1.35 up: 4 moons and 4 dots per half.
  TWIG   (0, 128, 256, 256)   bark along u; v 0..0.75 the plaited strands (v round the strand), v .75..1 loose twigs
                              (their last 8 percent of u is the pale snapped end)
  LEAF   (256, 128, 512, 192) leaf green, veins along u, underside darker in the lower half
  AWNING (256, 192, 512, 256) the same leaf one step duller (#63AD68)
  STRAW  (0, 256, 128, 384)   straw bed, fibres
  CROOK  (128, 256, 256, 320) peeled branch with bark patches, along u
  GREEN  (128, 320, 192, 384) deep garden green (feet)
  CORD   (192, 320, 224, 352) cord brown
  SUN    (224, 320, 256, 352) sunflower (the moon's edge faces)
  PAPER  (192, 352, 256, 384) paper cream
  MOON   (256, 256, 384, 384) planar: centre (320, 320), 128 px = 1 stud; the crescent painted where the mesh is
  COLLAR (384, 256, 512, 384) one leaf lobe per u (tip at 0 and 1, notch at .5), the machine's
  QUILT  (0, 384, 256, 512)   9 x 7 quilted squares (u across, v along the drape), stitch edge all round
  MAT    (256, 384, 384, 512) coiled straw: v = radius / 1.1 (rings), u round
  (384, 384, 512, 512)        spare (paper cream)

Run from the repository root:  python -I scripts/draw_nest_landmark_texture.py
Writes assets/world/nest-landmark/nest-landmark.png and nest-landmark-rough.png (64 px, same layout).
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "world", "nest-landmark", "nest-landmark.png")


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


CREAM, BAND_GROUND = hexrgb("#F4E8CF"), hexrgb("#E2D2B0")
GREEN = hexrgb("#38694A")
LEAF, LEAF_UNDER, AWNING = hexrgb("#6FBF73"), hexrgb("#4E9A5A"), hexrgb("#63AD68")
TWIGS, TWIG_SHADOW, SNAPPED = [hexrgb(c) for c in ("#6B4A2C", "#5A3D24", "#7D5A38", "#6B4A2C")], hexrgb("#3A2616"), hexrgb("#A47E50")
STRAW, STRAW_HI, STRAW_DARK = hexrgb("#B8974F"), hexrgb("#C9A560"), hexrgb("#8A6A3A")
CROOK, BARK = hexrgb("#A47E50"), hexrgb("#6B4A2B")
PAPER, SUN, CORD = hexrgb("#FFF3C4"), hexrgb("#FFC83C"), hexrgb("#8A6A3A")
TEAL, STITCH = hexrgb("#76ACA7"), hexrgb("#38694A")   # Fable R1 5: #6FB3AE rendered cyan; painted a step greyer
ALBEDO = .9   # the machine's lesson: cream reads white at noon, so the map holds it at .9

# The crescent (shared with build_nest_landmark.py): outer circle at the origin, the bite a circle to +x.
MOON_R, MOON_BITE_C, MOON_BITE_R = .5, (.325, .075), .45     # Fable R1 4: 1.0 tall, .75 wide
MOON_UV = 1.2                                                    # studs across the MOON region


def wrapped_noise(rng, w, h, cycles, octaves=8):
    y, x = np.mgrid[0:h, 0:w]
    x, y = x / w, y / h
    out = np.zeros((h, w))
    for _ in range(octaves):
        fx, fy = rng.integers(-cycles, cycles + 1, 2)
        if fx == 0 and fy == 0:
            fx = 1
        out += np.sin(2 * np.pi * (fx * x + fy * y) + rng.uniform(0, 2 * np.pi)) / math.hypot(fx, fy)
    return out / np.max(np.abs(out))


def blend(col, colour, mask):
    return col * (1 - mask[..., None]) + np.array(colour, float) * mask[..., None]


def bowl(img, rng):
    """u = half the circumference (about 7.4 studs at the band), v = 1.4 studs: ~69 x 91 px per stud."""
    w, h = 512, 128
    yy, xx = np.mgrid[0:h, 0:w] + .5
    height = 1.75 - yy / h * 1.4                              # studs up
    col = np.zeros((h, w, 3)) + np.array(CREAM, float)
    band = np.clip((.175 - np.abs(height - 1.175)) / .015, 0, 1)
    col = blend(col, BAND_GROUND, band)
    # Fine speckle (unglazed stoneware) and a soft darker tide line near the feet.
    speck = (rng.random((h, w)) < .035) * rng.uniform(.05, .16, (h, w))
    col = col * (1 - speck[..., None])
    col = col * (1 + .02 * wrapped_noise(rng, w, h, 12)[..., None])
    tide = np.clip(1 - np.abs(height - .62) / .12, 0, 1) * .08 + np.clip((.55 - height) / .2, 0, 1) * .07
    col = col * (1 - tide[..., None])
    # Band: 4 crescent moons and 4 dots per half, alternating, incised (a thin dark outline) and painted green.
    px_u, px_v = w / 7.4, h / 1.4                              # px per stud
    for k in range(8):
        cx = (k + .5) * w / 8
        cy = (1.75 - 1.175) * px_v
        dx, dy = (xx - cx) / px_u, (yy - cy) / px_v            # studs
        if k % 2 == 0:
            r = .145
            outer = np.hypot(dx, dy)
            bite = np.hypot(dx - .07, dy + .02)
            inside = (outer < r) & (bite > r * .82)
            edge = (np.abs(outer - r) < .012) & (bite > r * .82) | (np.abs(bite - r * .82) < .012) & (outer < r)
        else:
            d = np.hypot(dx, dy)
            inside = d < .06
            edge = np.abs(d - .06) < .012
        col = blend(col, GREEN, inside.astype(float) * .95)
        col = col * (1 - .25 * edge[..., None])
    # Two small rim chips (one per half would repeat: the bowl repeats the half twice, so one chip on the half = 2).
    for cx in (rng.uniform(60, 200),):
        d = np.hypot(xx - cx, (yy - 3) * 1.4)
        chip = np.clip(1 - d / 5, 0, 1)
        col = blend(col, hexrgb("#D9C9A6"), chip * .8)
    img[0:128, 0:512] = np.clip(col * ALBEDO, 0, 255)


def twig(img, rng):
    """Fable R1 3: strands #6B4A2C with #7D5A38 highlight grain; #3A2616 only in the narrow gaps between the plies
    (v near 0 and 1 round each strand); loose twigs the same browns with the pale snapped end."""
    w, h = 256, 128
    yy, xx = np.mgrid[0:h, 0:w] + .5
    strands = yy < 96
    base = np.array(hexrgb("#6B4A2C"), float)
    col = np.zeros((h, w, 3)) + base
    grain = np.clip(np.sin(yy * 1.9 + wrapped_noise(rng, w, h, 5) * 3) * 1.4 - .3, 0, 1)
    col = blend(col, hexrgb("#7D5A38"), grain * .85)
    col = blend(col, hexrgb("#5A3D24"), np.clip(-np.sin(yy * .7 + xx * .02) - .7, 0, 1) * 1.5 * .5)
    v = np.where(strands, yy / 96, (yy - 96) / 32)
    gap = np.clip((np.abs(v - .5) * 2 - .82) / .18, 0, 1)
    col = blend(col, TWIG_SHADOW, np.where(strands, gap, 0.0))
    snapped = (~strands) & (xx > w * .92)
    col[snapped] = np.array(SNAPPED, float)
    col *= 1 + .04 * wrapped_noise(rng, w, h, 9)[..., None]
    img[128:256, 0:256] = np.clip(col, 0, 255)


def leaf(img, rng, y0, colour):
    w, h = 256, 64
    v = np.arange(h)[:, None] / (h - 1)
    under = np.clip((v - .5) * 6, 0, 1)
    below = LEAF_UNDER if colour != AWNING else hexrgb("#5DA562")       # Fable R1 1: the awning is seen from below
    col = np.array(colour, float) * (1 - under[..., None]) + np.array(below, float) * under[..., None]
    col = np.repeat(col, w, 1)
    col = col * (1 + .03 * wrapped_noise(rng, w, h, 10)[..., None])
    yy, xx = np.mgrid[0:h, 0:w]
    for mid in (.25 * h, .75 * h):
        col = col * (1 - .12 * np.clip(1 - np.abs(yy - mid) / 1.2, 0, 1)[..., None])
        for k in range(8):
            x0 = k * 32 + 8
            for side in (-1, 1):
                d = np.abs((yy - mid) * side * 1.6 - (xx - x0) * .55)
                mask = (np.abs(yy - mid) < h * .22) & (xx > x0) & (np.sign(yy - mid) == side)
                col = col * (1 - .08 * (np.clip(1 - d / 1.2, 0, 1) * mask)[..., None])
    img[y0:y0 + 64, 256:512] = np.clip(col, 0, 255)


def straw(img, rng):
    w = h = 128
    yy, xx = np.mgrid[0:h, 0:w]
    col = np.zeros((h, w, 3)) + np.array(STRAW, float)
    for _ in range(260):                                       # fibres: short light and dark strokes in all directions
        x0, y0 = rng.uniform(0, w), rng.uniform(0, h)
        a, ln = rng.uniform(0, math.pi), rng.uniform(6, 18)
        c = STRAW_HI if rng.random() < .6 else STRAW_DARK
        for t in np.linspace(0, 1, int(ln)):
            x, y = int(x0 + math.cos(a) * ln * t) % w, int(y0 + math.sin(a) * ln * t) % h
            col[y, x] = np.array(c, float) * .7 + col[y, x] * .3
    col *= 1 + .04 * wrapped_noise(rng, w, h, 8)[..., None]
    du, dv = (xx + .5 - 64) / 128 * 2.8, (yy + .5 - 64) / 128 * 2.8
    dent = np.clip((1 - (du / .65) ** 2 - (dv / .55) ** 2) * 4, 0, 1)
    col = blend(col, STRAW_DARK, dent * .3)
    img[256:384, 0:128] = np.clip(col, 0, 255)


def crook(img, rng):
    w, h = 128, 64
    col = np.zeros((h, w, 3)) + np.array(CROOK, float)
    yy, xx = np.mgrid[0:h, 0:w]
    grain = .5 + .5 * np.sin(yy * 1.3 + wrapped_noise(rng, w, h, 4) * 2.5)
    col = col * (1 - .03 * grain[..., None])                          # Fable R1 1: peeled, light grain
    patches = wrapped_noise(rng, w, h, 4) > .7                        # bark patches only
    col = blend(col, BARK, patches * .9)
    img[256:320, 128:256] = np.clip(col, 0, 255)


def moon(img, rng):
    s = 128
    yy, xx = np.mgrid[0:s, 0:s] + .5
    x, y = (xx - 64) / 128 * MOON_UV, -(yy - 64) / 128 * MOON_UV  # studs, y up
    outer = np.hypot(x, y)
    bite = np.hypot(x - MOON_BITE_C[0], y - MOON_BITE_C[1])
    inside = (outer < MOON_R) & (bite > MOON_BITE_R)
    edge = ((MOON_R - outer < .03) | (bite - MOON_BITE_R < .03)) & inside
    col = np.zeros((s, s, 3)) + np.array(PAPER, float)
    col *= 1 + .025 * wrapped_noise(rng, s, s, 10)[..., None]      # paper fibre
    col = blend(col, SUN, edge.astype(float))
    img[256:384, 256:384] = np.clip(col, 0, 255)


def collar(img, rng):
    w = h = 128
    yy, xx = np.mgrid[0:h, 0:w] + .5
    u, v = xx / w, yy / h
    tip = np.cos(np.pi * 2 * u) * .5 + .5
    col = np.array(LEAF_UNDER, float) * (1 - tip[..., None]) + np.array(LEAF, float) * tip[..., None]
    col = col * (1 + .10 * np.clip(tip - .7, 0, 1)[..., None] / .3)
    notch = np.clip(1 - np.abs(u - .5) * w / 2.5, 0, 1)
    col = col * (1 - notch[..., None]) + np.array(LEAF_UNDER, float) * .8 * notch[..., None]
    for k in (.2, .35, .65, .8):
        d = np.abs((u - k) * w - (v - .5) * h * .4 * np.sign(k - .5))
        col = col * (1 - .08 * np.clip(1 - d / 1.2, 0, 1)[..., None])
    col *= 1 + .03 * wrapped_noise(rng, w, h, 6)[..., None]
    img[256:384, 384:512] = np.clip(col, 0, 255)


def quilt(img, rng):
    """9 x 7 squares; every third square cream; one sunflower star patch; quilting lines; blanket-stitch edge."""
    w, h = 256, 128
    yy, xx = np.mgrid[0:h, 0:w] + .5
    cu, cv = xx / w * 9, yy / h * 7
    i, j = cu.astype(int), cv.astype(int)
    col = np.zeros((h, w, 3)) + np.array(TEAL, float)
    col = blend(col, PAPER, ((i + j * 2) % 3 == 0).astype(float))
    # the star patch: cell (4, 2), a five-point star filling 80 percent of the square
    # quilting: soft darker lines on the square edges, a puff in the middle of each square
    du, dv = np.abs(cu - np.round(cu)), np.abs(cv - np.round(cv))
    col = col * (1 - .16 * np.clip(1 - np.minimum(du * w / 9, dv * h / 7) / 1.6, 0, 1)[..., None])
    puff = np.cos((cu % 1 - .5) * math.pi) * np.cos((cv % 1 - .5) * math.pi)
    col = col * (.93 + .1 * puff[..., None])
    col *= 1 + .03 * wrapped_noise(rng, w, h, 14)[..., None]                    # wool
    # Fable R1 5: the sunflower star on the front flap (u .5, v .9 of the drape), .35 across
    sw, sh = w / 4.2, h / 3.4                                  # px per stud across and along the drape
    cx, cy = .5 * w, .9 * h
    pts = []
    for k in range(10):
        a = -math.pi / 2 + k * math.pi / 5
        r = .175 if k % 2 == 0 else .075
        pts.append((cx + r * sw * math.cos(a), cy + r * sh * math.sin(a)))
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).polygon(pts, fill=255)
    col = blend(col, SUN, np.asarray(mask, float) / 255)
    # blanket stitch: a thin green edge with ticks .06 long every .15 (about 4 px long every 9 px)
    border = (xx < 1.6) | (xx > w - 1.6) | (yy < 1.6) | (yy > h - 1.6)
    ticks = (((xx < 4.5) | (xx > w - 4.5)) & (yy.astype(int) % 9 == 0)) | (((yy < 4.5) | (yy > h - 4.5)) & (xx.astype(int) % 9 == 0))
    col = blend(col, STITCH, (border | ticks).astype(float))
    img[384:512, 0:256] = np.clip(col, 0, 255)


def mat(img, rng):
    """Fable R1 9: coils in #C9A560 and #B8974F; #8A6A3A only as a thin line between them."""
    w = h = 128
    yy, xx = np.mgrid[0:h, 0:w] + .5
    phase = (yy / h * 9) % 1.0
    which = ((yy / h * 9).astype(int)) % 2
    col = np.where(which[..., None] == 0, np.array(STRAW_HI, float), np.array(STRAW, float))
    col = col * (.94 + .1 * np.sin(np.pi * phase)[..., None])                 # each coil rounded
    line = np.clip(1 - np.minimum(phase, 1 - phase) * h / 9 / 1.1, 0, 1)
    col = blend(col, STRAW_DARK, line * .9)
    wrap = .5 + .5 * np.sin(xx / w * 2 * math.pi * 40 + yy * .3)
    col = col * (1 - .05 * wrap[..., None])
    col *= 1 + .03 * wrapped_noise(rng, w, h, 8)[..., None]
    img[384:512, 256:384] = np.clip(col, 0, 255)


def main():
    rng = np.random.default_rng(2611)
    img = np.zeros((512, 512, 3)) + np.array(PAPER, float)
    bowl(img, rng)
    twig(img, rng)
    leaf(img, rng, 128, LEAF)
    leaf(img, rng, 192, AWNING)
    straw(img, rng)
    crook(img, rng)
    img[320:384, 128:192] = np.array(GREEN, float) * (1 + .03 * wrapped_noise(rng, 64, 64, 4)[..., None])
    img[320:352, 192:224] = CORD
    img[320:352, 224:256] = SUN
    img[352:384, 192:256] = PAPER
    moon(img, rng)
    collar(img, rng)
    quilt(img, rng)
    mat(img, rng)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    Image.fromarray(np.clip(img, 0, 255).round().astype(np.uint8), "RGB").save(OUT)
    # Roughness in the atlas's layout at 64 px (8 px = 64 atlas px): .85 (217) everywhere, the bowl .8 (204),
    # the quilt .9 (230).
    rough = np.full((64, 64), 217, np.uint8)
    rough[0:16, 0:64] = 204
    rough[48:64, 0:32] = 230
    Image.fromarray(rough, "L").save(os.path.join(os.path.dirname(OUT), "nest-landmark-rough.png"))
    # The moon's emissive mask (architect: the moon glows through its SurfaceAppearance's EmissiveStrength/Tint, which
    # game scripts can write; the mask itself is authored on the template). 256 px in the atlas's layout: white on the
    # crescent and its sunflower edge faces, black elsewhere (the cord does not glow).
    s = 256
    mask = np.zeros((s, s), np.uint8)
    k = s / 512
    yy, xx = np.mgrid[0:int(128 * k), 0:int(128 * k)] + .5
    x, y = (xx - 64 * k) / (128 * k) * MOON_UV, -(yy - 64 * k) / (128 * k) * MOON_UV
    inside = (np.hypot(x, y) < MOON_R + .01) & (np.hypot(x - MOON_BITE_C[0], y - MOON_BITE_C[1]) > MOON_BITE_R - .01)
    mask[int(256 * k):int(384 * k), int(256 * k):int(384 * k)] = inside * 255
    mask[int(320 * k):int(352 * k), int(224 * k):int(256 * k)] = 255            # SUN: the edge faces
    Image.fromarray(mask, "L").save(os.path.join(os.path.dirname(OUT), "nest-landmark-emissive.png"))
    print("wrote", os.path.relpath(OUT, ROOT), ", nest-landmark-rough.png and nest-landmark-emissive.png")


if __name__ == "__main__":
    main()
