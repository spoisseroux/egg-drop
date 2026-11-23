"""Draw the round 2 world maps (Fable, artifacts/world-pass-2026-11-22/reexport/LOOK-R2.md). Script-drawn, deterministic.

  assets/world/textures/aero/fall-white.png   256x512  clumped white streaks, uneven widths, about 70 percent cover;
                                                       the fall runs down image Y and tiles along it (Flow A)
  assets/world/textures/aero/fall-veil.png    256x512  thin strands and bead trails, about 25 percent cover (Flow B)
  assets/world/textures/aero/foam-streak.png  256x256  foam lines streaming out from the foot (the apron), along Y

On a Beam the image's Y runs along the beam's length; its width lies along the attachments' SecondaryAxis
(AeroFalls gives the kit's flow beams the sheet's t there, or they stand edge-on).
  assets/world/textures/aero/spray-soft.png   128x128  one soft, uneven spray blob with no outline (boil, splash)
  assets/world/textures/aero/speck.png         16x16   a droplet speck
  assets/world/textures/aero/roughness-92.png   8x8    flat grey 235: roughness .92 for the matte lime crowns

White on clear (RGB stays white under clear pixels, so no dark fringe); Beam and emitter Color tint them.

    python scripts/draw_aero_falls_textures.py           write them
    python scripts/draw_aero_falls_textures.py --check   fail when a committed map differs
"""
from __future__ import annotations

import io
import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from draw_world_textures import _streaks, _white  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "world" / "textures" / "aero"
SEED = 20261123


def _cover(a: np.ndarray, share: float) -> np.ndarray:
    """Scale so about `share` of the pixels are clearly visible (alpha over .25)."""
    level = np.quantile(a, 1 - share)
    return np.clip(a * (.25 / max(level, 1e-3)), 0, 1) if level > 0 else a


def _narrow(img: Image.Image, width: int) -> Image.Image:
    return img.resize((width, img.size[1]), Image.LANCZOS)


def fall_white() -> Image.Image:
    rng = random.Random(SEED + 1)
    a = _streaks(512, rng, (
        # count, width, length, peak, wobble, x range
        (9, .085, 1.7, .85, .016, .06, .94),   # broad clumps, longer than the tile: the sheet never shows a gap
        (18, .032, 1.05, 1.0, .010, .04, .96),  # strands
        (26, .011, .55, 1.0, .006, .03, .97),  # bright threads
    ), .05)
    return _narrow(_white(_cover(a, .70)), 256)


def fall_veil() -> Image.Image:
    rng = random.Random(SEED + 2)
    n = 512
    a = _streaks(n, rng, ((16, .006, .75, .9, .007, .05, .95), (10, .010, .40, .8, .005, .08, .92)), .08)
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float32)
    for _ in range(70):  # beads running down the trails
        cx, cy, r = rng.uniform(.06, .94) * n, rng.uniform(0, n), rng.uniform(2.2, 4.2)
        dy = np.abs(ys - cy)
        d = np.hypot(xs - cx, np.minimum(dy, n - dy)) / r
        a = np.maximum(a, np.clip(1.2 - d, 0, 1) * rng.uniform(.6, 1))
    return _narrow(_white(_cover(a, .25)), 256)


def foam_streak() -> Image.Image:
    rng = random.Random(SEED + 3)
    n = 256
    a = _streaks(n, rng, ((10, .04, .7, .75, .045, .08, .92), (20, .014, .45, 1.0, .035, .05, .95),
                          (26, .006, .25, .9, .02, .05, .95)), .18)
    return _white(np.clip(a, 0, 1))


def spray_soft() -> Image.Image:
    rng = random.Random(SEED + 4)
    n = 128
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float32)
    a = np.zeros((n, n), np.float32)
    for _ in range(7):
        ang, rad = rng.uniform(0, math.tau), rng.uniform(0, .16)
        cx, cy = (.5 + math.cos(ang) * rad) * n, (.5 + math.sin(ang) * rad) * n
        s = rng.uniform(.10, .19) * n
        a = np.maximum(a, rng.uniform(.55, .9) * np.exp(-((xs - cx) ** 2 + (ys - cy) ** 2) / (2 * s * s)))
    r = np.hypot(xs - n / 2, ys - n / 2) / (n / 2)
    return _white(a * np.clip((1 - r) / .25, 0, 1))  # clear before the square's edge


def speck() -> Image.Image:
    n = 16
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float32)
    r = np.hypot(xs - 7.5, ys - 7.5) / 7.5
    return _white(np.clip((1 - r) / .5, 0, 1) ** 1.5)


def roughness() -> Image.Image:
    return Image.new("RGB", (8, 8), (235, 235, 235))


MAPS = {"fall-white": fall_white, "fall-veil": fall_veil, "foam-streak": foam_streak, "spray-soft": spray_soft,
        "speck": speck, "roughness-92": roughness}


def png(img: Image.Image) -> bytes:
    buffer = io.BytesIO()
    img.save(buffer, format="PNG", optimize=True)
    return buffer.getvalue()


def main(argv) -> int:
    stale = []
    for name, draw in MAPS.items():
        data = png(draw())
        path = OUT / (name + ".png")
        if "--check" in argv:
            if not path.exists() or path.read_bytes() != data:
                stale.append(name)
            continue
        OUT.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        print("wrote", path.relative_to(ROOT))
    if stale:
        print("STALE:", ", ".join(stale))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
