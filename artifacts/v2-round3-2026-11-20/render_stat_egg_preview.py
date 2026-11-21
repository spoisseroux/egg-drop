"""Software preview of an egg ColorMap on the egg profile (no Blender): four yaw angles, plus the
flat map. Orthographic, one key light + ambient, a soft specular. Round 3, 2026-11-20.
  python artifacts/v2-round3-2026-11-20/render_stat_egg_preview.py [type ...]   (default: stat companion toy)
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "scripts"))
import egg_types as E  # noqa: E402

OUT = Path(__file__).resolve().parent
S = 420            # px per view (height); the egg is 1.3 studs tall
PX = S / 1.5


def view(tex, yaw_deg):
    w = int(1.15 * PX)
    xs = (np.arange(w) + 0.5 - w / 2) / PX
    zs = 1.4 - (np.arange(S) + 0.5) / PX
    X, Z = np.meshgrid(xs, zs)
    inside = (Z > 0) & (Z < E.HEIGHT)
    t = np.arccos(np.clip(1 - 2 * Z / E.HEIGHT, -1, 1)) / math.pi
    ph = math.pi * t
    r = (E.WIDTH / 2) * np.sin(ph) * (1 + E._K * np.cos(ph)) / E._RMAX
    inside &= np.abs(X) < r
    y = -np.sqrt(np.clip(r * r - X * X, 0, None))
    a = np.arctan2(X, -y) + math.radians(yaw_deg)
    u = (E.FRONT_U + a / (2 * math.pi)) % 1.0
    v = E.UV_OUTER_V0 + t * (1 - E.UV_OUTER_V0)
    th, tw = tex.shape[:2]
    col = tex[np.clip(((1 - v) * th).astype(int), 0, th - 1), np.clip((u * tw).astype(int), 0, tw - 1)]
    # normal: radial part from the profile slope
    e = 1e-3
    def prof(tt):
        p = math.pi * tt
        return (E.WIDTH / 2) * np.sin(p) * (1 + E._K * np.cos(p)) / E._RMAX, (E.HEIGHT / 2) * (1 - np.cos(p))
    r0, z0 = prof(np.clip(t - e, 0, 1)); r1, z1 = prof(np.clip(t + e, 0, 1))
    dr, dz = r1 - r0, z1 - z0
    n = np.hypot(dr, dz) + 1e-9
    nr, nz = dz / n, -dr / n
    rr = np.maximum(r, 1e-6)
    N = np.stack([nr * X / rr, nr * y / rr, nz], -1)
    L = np.array([-0.5, -0.6, 0.8]); L = L / np.linalg.norm(L)
    lam = np.clip((N * L).sum(-1), 0, 1)
    Hh = L + np.array([0, -1, 0]); Hh = Hh / np.linalg.norm(Hh)
    spec = np.clip((N * Hh).sum(-1), 0, 1) ** 60
    img = col * (0.62 + 0.46 * lam[..., None]) + 0.35 * spec[..., None]
    bg = np.array([0.086, 0.078, 0.227])     # ink #15143A
    out = np.where(inside[..., None], np.clip(img, 0, 1), bg)
    return (out * 255 + 0.5).astype(np.uint8)


def sheet(tid):
    tex = np.asarray(Image.open(REPO / "assets/eggs/textures" / f"egg-{tid}-color.png").convert("RGB")) / 255.0
    views = [view(tex, yaw) for yaw in (0, 60, 150, 240)]
    flat = np.asarray(Image.fromarray((tex * 255).astype(np.uint8)).resize((S, S), Image.LANCZOS))
    row = np.concatenate(views + [flat], axis=1)
    Image.fromarray(row).save(OUT / f"egg-{tid}-preview.png", optimize=True)
    print("wrote", OUT / f"egg-{tid}-preview.png")
    return row


if __name__ == "__main__":
    ids = sys.argv[1:] or ["stat", "companion", "toy"]
    rows = [sheet(t) for t in ids]
    if len(rows) > 1:
        Image.fromarray(np.concatenate(rows, axis=0)).save(OUT / "egg-stat-vs-others.png", optimize=True)
