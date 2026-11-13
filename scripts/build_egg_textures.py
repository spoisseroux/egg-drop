"""Paint the egg ColorMaps (one per egg type), the shared RoughnessMap and the Star token maps.

Run with system Python (needs numpy + Pillow):
  python scripts/build_egg_textures.py

Every pattern is evaluated on the egg's 3D surface (texel -> point on the shell), so dots stay round and
nothing pinches at the poles or shows a seam at u = 0/1. The layout matches scripts/build_egg_models.py:
u runs round the egg (u = 0.5 is the front), v in [0.08, 1] runs bottom pole to top pole, and the strip
below v = 0.075 is the inside of the shell and its cut rim.

Outputs: assets/eggs/textures/egg-<type>-color.png (1024), egg-roughness.png (256),
star-color.png (512), star-roughness.png (64).
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import egg_types as E  # noqa: E402

REPO = Path(__file__).resolve().parents[1]
OUT = REPO / "assets" / "eggs" / "textures"
OUT.mkdir(parents=True, exist_ok=True)

SIZE = 1024
SS = 2                     # supersample factor
W = H = SIZE * SS


def rgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def lin(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


# ---------- texel -> surface ----------
xs = (np.arange(W) + 0.5) / W
ys = 1.0 - (np.arange(H) + 0.5) / H
U, V = np.meshgrid(xs, ys)
T = np.clip((V - E.UV_OUTER_V0) / (1 - E.UV_OUTER_V0), 0, 1)
PH = np.pi * T
RAD = (E.WIDTH / 2) * np.sin(PH) * (1 + E._K * np.cos(PH)) / E._RMAX
Z = (E.HEIGHT / 2) * (1 - np.cos(PH))
ANG = 2 * np.pi * (U - E.FRONT_U)
X = RAD * np.sin(ANG)
Y = -RAD * np.cos(ANG)
AA = 0.004  # anti-alias width in studs


def surf(u, t):
    r, z = E.profile(t)
    dx, dy = E.direction(u)
    return np.array([r * dx, r * dy, z])


def window(u, t, reach):
    """Row slice and column indices of the texels within `reach` studs of surface point (u, t)."""
    dt = reach / (math.pi * E.HEIGHT / 2 * 0.55) + 0.01
    v_hi = E.UV_OUTER_V0 + min(t + dt, 1) * (1 - E.UV_OUTER_V0)
    v_lo = E.UV_OUTER_V0 + max(t - dt, 0) * (1 - E.UV_OUTER_V0)
    y0, y1 = int((1 - v_hi) * H), int(math.ceil((1 - v_lo) * H))
    rmin = min(E.profile(max(t - dt, 0))[0], E.profile(min(t + dt, 1))[0])
    du = 1.0 if rmin < reach * 1.2 else min(1.0, reach * 1.6 / (2 * math.pi * rmin) + 0.01)
    if du >= 0.5:
        cols = np.arange(W)
    else:
        c = int(u * W)
        n = int(du * W)
        cols = np.arange(c - n, c + n + 1) % W
    return slice(max(y0, 0), min(y1, H)), cols


def blend(img, sl, cols, mask, color):
    sub = img[sl][:, cols]
    sub += (color - sub) * mask[..., None]
    img[sl, cols] = sub


def dot(img, u, t, radius, color, alpha=1.0, soft=AA):
    sl, cols = window(u, t, radius + soft)
    c = surf(u, t)
    d = np.sqrt((X[sl][:, cols] - c[0]) ** 2 + (Y[sl][:, cols] - c[1]) ** 2 + (Z[sl][:, cols] - c[2]) ** 2)
    blend(img, sl, cols, (1 - smooth(radius - soft, radius + soft, d)) * alpha, color)


def sparkle(img, u, t, radius, color, alpha=1.0, power=0.55):
    """Four-point star drawn in the surface's tangent plane."""
    sl, cols = window(u, t, radius * 1.1)
    c = surf(u, t)
    dx, dy = E.direction(u)
    east = np.array([-dy, dx, 0.0])
    nr, nz = E.profile_normal(t)
    north = np.array([-nz * dx, -nz * dy, nr])
    px, py, pz = X[sl][:, cols] - c[0], Y[sl][:, cols] - c[1], Z[sl][:, cols] - c[2]
    a = np.abs(px * east[0] + py * east[1]) / radius
    b = np.abs(px * north[0] + py * north[1] + pz * north[2]) / radius
    f = a ** power + b ** power
    blend(img, sl, cols, (1 - smooth(0.94, 1.06, f)) * alpha, color)


# ---------- 3D value noise ----------
_rng = np.random.default_rng(7)
_LAT = _rng.random((32, 32, 32))


def noise(px, py, pz):
    def f(p):
        i = np.floor(p).astype(int)
        w = p - i
        return i % 32, (i + 1) % 32, w * w * (3 - 2 * w)
    x0, x1, wx = f(px)
    y0, y1, wy = f(py)
    z0, z1, wz = f(pz)
    c00 = _LAT[x0, y0, z0] * (1 - wx) + _LAT[x1, y0, z0] * wx
    c10 = _LAT[x0, y1, z0] * (1 - wx) + _LAT[x1, y1, z0] * wx
    c01 = _LAT[x0, y0, z1] * (1 - wx) + _LAT[x1, y0, z1] * wx
    c11 = _LAT[x0, y1, z1] * (1 - wx) + _LAT[x1, y1, z1] * wx
    return (c00 * (1 - wy) + c10 * wy) * (1 - wz) + (c01 * (1 - wy) + c11 * wy) * wz


def fbm(scale, octaves=4, off=0.0):
    out, amp, tot = 0.0, 1.0, 0.0
    for o in range(octaves):
        s = scale * 2 ** o
        out = out + amp * noise(X * s + 11.3 + off + o * 5.1, Y * s + 4.7 + off, Z * s + 9.2 + off)
        tot += amp
        amp *= 0.5
    return out / tot


def scatter(n, rng, t_range=(0.06, 0.95), min_gap=0.0, avoid=None, tries=4000):
    """Random surface points, area-uniform, at least min_gap studs apart."""
    pts = []
    for _ in range(tries):
        if len(pts) >= n:
            break
        u, t = rng.random(), rng.uniform(*t_range)
        if rng.random() > E.profile(t)[0] / (E.WIDTH / 2):
            continue
        if avoid and avoid(u, t):
            continue
        p = surf(u, t)
        if all(np.linalg.norm(p - q[2]) >= min_gap for q in pts):
            pts.append((u, t, p))
    return [(u, t) for u, t, _ in pts]


def ring_band(center_t, half_width):
    """Mask of a band whose centre line is the profile parameter array/number center_t (studs wide)."""
    d = np.abs(T - center_t) * (math.pi * E.HEIGHT / 2) * np.maximum(np.sin(PH), 0.3)
    return 1 - smooth(half_width - AA, half_width + AA, d)


def fill(c):
    return np.broadcast_to(c, (H, W, 3)).copy()


def mix(img, color, mask):
    return img + (color - img) * mask[..., None]


# ---------- the five looks ----------
def paint_companion(t):
    blue, lime = rgb(t["accents"][0]), rgb(t["accents"][1])
    img = fill(rgb(t["base"]))
    ribbon_t = 0.285 + 0.022 * np.sin(6 * ANG)
    img = mix(img, rgb("#FFFFFF"), ring_band(ribbon_t, 0.072) * 0.9)
    img = mix(img, lime, ring_band(ribbon_t, 0.052))
    rng = np.random.default_rng(21)
    pts = scatter(15, rng, (0.40, 0.93), 0.27,
                  avoid=lambda u, tt: abs(tt - E.seam_t(u)) < 0.0)
    for i, (u, tt) in enumerate(pts):
        dot(img, u, tt, 0.078 + 0.035 * ((i * 37) % 5) / 4, blue)
    for u, tt in scatter(7, rng, (0.07, 0.19), 0.2):
        dot(img, u, tt, 0.055, blue)
    return img


def paint_toy(t):
    teal, coral, white = (rgb(c) for c in t["accents"])
    img = fill(rgb(t["base"]))
    for centre, phase, hw in ((0.33, 0.0, 0.050), (0.745, math.pi, 0.045)):
        line = centre + 0.055 * np.sin(4 * ANG + phase)
        img = mix(img, teal, ring_band(line, hw))
    for k in range(8):                      # belly row: coral, white, coral ...
        u = (k + 0.5) / 8
        tt = 0.535 - 0.05 * math.sin(4 * 2 * math.pi * (u - E.FRONT_U)) * 0.4
        if k % 2 == 0:
            dot(img, u, tt, 0.088, coral)
            dot(img, u - 0.006, tt + 0.012, 0.03, mix_c(coral, white, 0.55), 0.9)
        else:
            dot(img, u, tt, 0.045, white)
    for k in range(6):
        dot(img, (k + 0.25) / 6, 0.90, 0.036, white)
        dot(img, (k + 0.75) / 6, 0.145, 0.05, coral if k % 2 else white)
    return img


def mix_c(a, b, f):
    return a + (b - a) * f


def paint_material(t):
    base, light, deep = rgb(t["base"]), rgb(t["light"]), rgb(t["deep"])
    teal, blue = rgb(t["accents"][0]), rgb(t["accents"][1])
    warp = fbm(1.6, 4)
    cloud = fbm(2.6, 4, off=13.0)
    img = fill(base)
    img = mix(img, light, smooth(0.45, 0.8, cloud) * 0.55)
    img = mix(img, deep, smooth(0.55, 0.2, cloud) * 0.55)
    # pearly sheen: slow pink/mint drift
    img = mix(img, rgb("#FFD9EC"), smooth(0.4, 0.8, fbm(1.1, 2, off=31.0)) * 0.30)
    img = mix(img, rgb("#CFF6EE"), smooth(0.45, 0.85, fbm(1.3, 2, off=57.0)) * 0.30)

    def veins(freq, off, width):
        f = np.sin(np.pi * (warp * freq + Z * 2.1 + X * 1.3 + off + 0.9 * fbm(3.4, 3, off=off)))
        return 1 - smooth(0.0, width, np.abs(f))

    img = mix(img, teal, veins(5.0, 0.0, 0.26) * 0.95)
    img = mix(img, blue, veins(3.6, 1.7, 0.19) * 0.9)
    img = mix(img, rgb("#FFFFFF"), veins(7.0, 4.1, 0.06) * 0.8)
    img = mix(img, rgb("#FFE9A8"), veins(4.4, 2.9, 0.06) * 0.9)   # thin gold thread
    return img


def paint_hue(t):
    cols = [rgb(c) for c in t["accents"]]
    n = len(cols)
    s = (U * 2 + T * 1.55 + 0.045 * np.sin(2 * np.pi * 3 * T + 4 * ANG)) % 1.0 * n
    k = np.floor(s).astype(int) % n
    f = s - np.floor(s)
    pal = np.stack(cols)
    a, b = pal[k], pal[(k + 1) % n]
    edge = smooth(0.90, 1.0, f)
    img = a + (b - a) * edge[..., None]
    # glossy candy highlight down the middle of each ribbon and a white pinstripe on each join
    img = mix(img, rgb("#FFFFFF"), (1 - smooth(0.0, 0.22, np.abs(f - 0.42))) * 0.22)
    pin = 1 - smooth(0.018, 0.05, np.minimum(np.abs(f - 0.95), np.abs(f + 0.05)))
    img = mix(img, rgb("#FFFFFF"), pin * 0.95)
    return img


def paint_feature(t):
    base, deep, light = rgb(t["base"]), rgb(t["deep"]), rgb(t["light"])
    mint, white, lav = (rgb(c) for c in t["accents"])
    img = fill(base)
    img = mix(img, deep, smooth(0.50, 0.05, T) * 0.9)
    img = mix(img, light, smooth(0.62, 1.0, T) * 0.85)
    neb = fbm(2.2, 4, off=3.0)
    img = mix(img, rgb("#B06AD9"), smooth(0.5, 0.8, neb) * 0.55)
    img = mix(img, rgb("#4A86C9"), smooth(0.55, 0.85, fbm(1.8, 3, off=40.0)) * 0.30)
    rng = np.random.default_rng(5)
    for u, tt in scatter(520, rng, (0.03, 0.97)):                     # glitter
        c = (white, mint, lav)[rng.integers(3)]
        dot(img, u, tt, rng.uniform(0.006, 0.014), c, rng.uniform(0.6, 1.0), soft=0.003)
    stars = scatter(26, rng, (0.10, 0.90), 0.20)
    for i, (u, tt) in enumerate(stars):
        big = i % 3 == 0
        r = 0.135 if big else rng.uniform(0.06, 0.09)
        c = mint if i % 2 == 0 else white
        dot(img, u, tt, r * 0.55, c, 0.28, soft=r * 0.5)                 # soft halo
        sparkle(img, u, tt, r, c)
        sparkle(img, u, tt, r * 0.45, white, 0.9)
    return img


PAINT = {"companion": paint_companion, "toy": paint_toy, "material": paint_material,
         "hue": paint_hue, "feature": paint_feature}


def finish(img, t):
    """Shared finish: baked top light / bottom shade (spin-invariant), crack line, inner strip."""
    deep, light = rgb(t["deep"]), rgb(t["light"])
    img = mix(img, rgb("#FFFFFF"), smooth(0.55, 1.0, T) * 0.16)
    shade = smooth(0.42, 0.0, T)
    img = img * (1 - 0.16 * shade[..., None])
    img = mix(img, deep, shade * 0.18)
    # crack: a fine dark zig-zag with a bright lip above it, so it reads at 120 px
    ph = (U * E.TEETH) % 1.0
    seam = E.SEAM_T - E.SEAM_AMP_T * (1 - 2 * np.abs(ph * 2 - 1))
    d = (T - seam) * (math.pi * E.HEIGHT / 2) * np.sin(PH)
    dark = img * 0.42 + deep * 0.12
    img = mix(img, light, (1 - smooth(0.004, 0.012, np.abs(d - 0.022))) * 0.6)
    img = mix(img, dark, (1 - smooth(0.008, 0.014, np.abs(d))) * 0.9)
    # inside of the shell and the cut rim
    inner = rgb(t["inner"])
    strip = fill(inner)
    f = np.clip((V - E.UV_INNER_V[0]) / (E.UV_INNER_V[1] - E.UV_INNER_V[0]), 0, 1)
    strip = mix(strip, mix_c(inner, deep, 0.45), (1 - f) * 0.8)
    strip = mix(strip, mix_c(inner, rgb("#FFFFFF"), 0.6), smooth(0.054, 0.058, V))
    return np.where((V < 0.075)[..., None], strip, img)


def save(img, path, size=SIZE):
    arr = (np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8)
    im = Image.fromarray(arr, "RGB")
    if im.size != (size, size):
        im = im.resize((size, size), Image.LANCZOS)
    im.save(path, optimize=True)
    print("wrote", path.relative_to(REPO), im.size)


def build_eggs():
    for tid in E.ORDER:
        t = E.TYPES[tid]
        save(finish(PAINT[tid](t), t), OUT / f"egg-{tid}-color.png")
    # Shared RoughnessMap: glossy toy plastic outside, chalky inside.
    v = 1.0 - (np.arange(256) + 0.5) / 256
    col = np.where(v < 0.075, 0.78, 0.27)
    rough = np.repeat(col[:, None], 256, axis=1)
    Image.fromarray((rough * 255 + 0.5).astype(np.uint8), "L").convert("RGB").save(OUT / "egg-roughness.png")
    print("wrote", (OUT / "egg-roughness.png").relative_to(REPO))


def build_star():
    S = E.STAR
    n = 512 * SS
    c = (np.arange(n) + 0.5) / n
    uu, vv = np.meshgrid(c, 1 - c)
    px, pz = (uu - 0.5) * S["uvSpan"], (vv - 0.5) * S["uvSpan"]
    rho = np.hypot(px, pz)
    ang = np.arctan2(px, pz)                        # 0 = up, clockwise positive
    step = 2 * np.pi / 5
    tip = np.round(ang / step)
    rel = ang - tip * step                          # -36deg .. +36deg about the nearest tip
    side = np.where(rel >= 0, 1.0, -1.0)
    a = np.abs(rel)
    R, r = S["outerRadius"] * S["paintScale"], S["innerRadius"] * S["paintScale"]
    qx, qy = rho * np.cos(a), rho * np.sin(a)
    vx, vy = r * math.cos(step / 2) - R, r * math.sin(step / 2)
    dist = (vx * qy - vy * (qx - R)) / math.hypot(vx, vy)    # > 0 inside
    # facet brightness: each facet leans away from its tip ridge
    facing = tip * step + side * math.radians(78)
    light_dir = math.radians(-40)
    lam = 0.5 + 0.5 * np.cos(facing - light_dir)
    lam = lam * 0.82 + 0.18 * (0.5 - 0.5 * (px * 0.7 - pz * 0.7) / S["outerRadius"])
    ramp = [(0.0, rgb(S["deep"])), (0.38, rgb(S["mid"])), (0.72, rgb(S["gold"])), (1.0, rgb(S["light"]))]
    img = np.zeros((n, n, 3))
    for (x0, c0), (x1, c1) in zip(ramp, ramp[1:]):
        f = np.clip((lam - x0) / (x1 - x0), 0, 1)[..., None]
        img = np.where((lam >= x0)[..., None], c0 + (c1 - c0) * f, img)
    # soft ridges: a light line on every tip ridge, a slightly darker one in every valley
    ridge = 1 - smooth(0.0, 0.03, rho * np.sin(a))
    img = mix(img, rgb("#FFF6D0"), ridge * 0.55 * smooth(0.02, 0.12, rho))
    valley = 1 - smooth(0.0, 0.02, rho * np.sin(step / 2 - a))
    img = mix(img, rgb(S["deep"]), valley * 0.35)
    # bevel band just inside the edge: lit on the upper left, shaded on the lower right
    band = 1 - smooth(0.035, 0.06, dist)
    lit = 0.5 - 0.5 * (px * 0.7 - pz * 0.7) / S["outerRadius"]
    img = mix(img, rgb("#FFF3C4"), band * np.clip(lit, 0, 1) * 0.75)
    img = mix(img, rgb(S["deep"]), band * np.clip(1 - lit, 0, 1) * 0.55)
    img = mix(img, rgb(S["edge"]), 1 - smooth(-0.004, 0.004, dist))
    save(img, OUT / "star-color.png", 512)
    Image.new("RGB", (64, 64), (int(S["roughness"] * 255),) * 3).save(OUT / "star-roughness.png")
    print("wrote", (OUT / "star-roughness.png").relative_to(REPO))


if __name__ == "__main__":
    build_eggs()
    build_star()
