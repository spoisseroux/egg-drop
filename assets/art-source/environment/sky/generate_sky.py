"""Egg Drop world 1: original stylised skyboxes (day + night), generated procedurally.

Run:  blender --factory-startup -b --python assets/art-source/environment/sky/generate_sky.py

Writes  sky/day/Sky_{Bk,Dn,Ft,Lf,Rt,Up}.png  and  sky/night/Sky_{...}.png   (1024 px, for Roblox Sky)
plus    sky/day/_equirect.png, sky/night/_equirect.png                        (2048 x 1024, used by the Blender scene)
and     sky/_preview.png                                                      (both skies as cross strips)

Everything is painted from a direction -> colour function (gradient, soft 3-tone clouds from 3D noise, sun glow /
moon + stars), so the six faces are seamless by construction. Directions are in ROBLOX axes (X right, Y up, Z back).
Face convention used here (verify once in Studio): each face is what you see looking along that axis with +Y up:
  Ft looks toward -Z, Bk toward +Z, Rt toward +X, Lf toward -X; Up has image-up = +Z, Dn has image-up = -Z.
"""
import os, math, numpy as np, bpy

OUT = os.path.dirname(os.path.abspath(__file__))
SUN_R = np.array([-.52, .70, .42]); SUN_R /= np.linalg.norm(SUN_R)        # matches the scene's key light
MOON_R = np.array([.42, .60, -.68]); MOON_R /= np.linalg.norm(MOON_R)


def hexc(h):
    h = h.lstrip('#'); return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)])


def ramp(t, xs, cols):
    cols = np.array([hexc(c) for c in cols]); t = np.clip(t, xs[0], xs[-1])
    return np.stack([np.interp(t, xs, cols[:, k]) for k in range(3)], -1)


def _hash(i, j, k, s):
    n = np.sin(i * 127.1 + j * 311.7 + k * 74.7 + s * 19.19) * 43758.5453
    return n - np.floor(n)


def noise3(x, y, z, s=0):
    i, j, k = np.floor(x), np.floor(y), np.floor(z)
    fx, fy, fz = x - i, y - j, z - k
    fx = fx * fx * (3 - 2 * fx); fy = fy * fy * (3 - 2 * fy); fz = fz * fz * (3 - 2 * fz)
    def L(a, b, t): return a + (b - a) * t
    return L(L(L(_hash(i, j, k, s), _hash(i + 1, j, k, s), fx), L(_hash(i, j + 1, k, s), _hash(i + 1, j + 1, k, s), fx), fy),
             L(L(_hash(i, j, k + 1, s), _hash(i + 1, j, k + 1, s), fx), L(_hash(i, j + 1, k + 1, s), _hash(i + 1, j + 1, k + 1, s), fx), fy), fz)


def fbm3(x, y, z, s=0, octs=4):
    t = 0; a = 1; tot = 0
    for o in range(octs):
        t = t + a * noise3(x, y, z, s + o * 7); tot += a; a *= .5; x, y, z = x * 2, y * 2, z * 2
    return t / tot


def sm(a, b, t):
    t = np.clip((t - a) / (b - a), 0, 1); return t * t * (3 - 2 * t)


def clouds(X, Y, Z, seed, scale=2.6):
    """Flattened puffs: noise sampled with Y stretched so shapes lie along the horizon. Returns mask 0..1 and a 3-tone shade."""
    n = fbm3(X * scale, Y * scale * 2.6, Z * scale, seed)
    lit = fbm3(X * scale + .35, Y * scale * 2.6 + .6, Z * scale, seed)                 # offset copy -> fake top light
    mask = sm(.53, .60, n)
    shade = np.round(np.clip(.55 + (lit - n) * 9 + (n - .55) * 2.2, 0, 1) * 2) / 2          # posterised: painted, not smoky
    return mask, shade


def sky(X, Y, Z, mode):
    d = np.sqrt(X * X + Y * Y + Z * Z); X, Y, Z = X / d, Y / d, Z / d
    if mode == 'day':
        col = ramp(Y, [-1, -.25, -.02, .03, .14, .38, .75, 1], ['#58B4F2', '#8FD3F8', '#D9F1F7', '#FFF3DC', '#9FE0FB', '#3FB8F6', '#1E96EE', '#1280E2'])
        m, sh = clouds(X, Y, Z, 3)
        band = np.clip(np.exp(-((Y - .16) / .20) ** 2) * 1.15 + .30 * sm(.0, .5, Y) + .55 * np.exp(-((Y + .22) / .18) ** 2), 0, 1.15)
        m = np.clip(m * band, 0, 1)
        ccol = ramp(sh, [0, .5, 1], ['#BFDDF6', '#E9F5FF', '#FFFFFF'])
        col = col * (1 - m[..., None]) + ccol * m[..., None]
        dot = np.clip(X * SUN_R[0] + Y * SUN_R[1] + Z * SUN_R[2], 0, 1)
        col = col + (dot ** 260)[..., None] * np.array([1.0, .95, .75]) + (dot ** 10)[..., None] * np.array([.10, .09, .05])
    else:
        col = ramp(Y, [-1, -.25, -.02, .03, .2, .5, 1], ['#141A48', '#232E6E', '#34468E', '#4A5CAE', '#2A3A86', '#18215C', '#0B1038'])
        m, sh = clouds(X, Y, Z, 11)
        band = np.clip(np.exp(-((Y - .14) / .18) ** 2) + .5 * np.exp(-((Y + .2) / .18) ** 2), 0, 1)
        m = np.clip(m * band, 0, 1) * .8
        ccol = ramp(sh, [0, .5, 1], ['#3B4A93', '#5B6DBB', '#8E9FE0'])
        col = col * (1 - m[..., None]) + ccol * m[..., None]
        dot = np.clip(X * MOON_R[0] + Y * MOON_R[1] + Z * MOON_R[2], 0, 1)
        col = col + (dot ** 90)[..., None] * np.array([.20, .24, .34])
        moon = sm(math.cos(math.radians(4.6)), math.cos(math.radians(4.2)), dot)
        col = col * (1 - moon[..., None]) + np.array([1.0, .97, .85]) * moon[..., None]
    return np.clip(col, 0, 1)


RNG = np.random.default_rng(77)
STARS = RNG.normal(size=(1500, 3)); STARS /= np.linalg.norm(STARS, axis=1)[:, None]
STARS = STARS[STARS[:, 1] > -.25]; STAR_B = RNG.uniform(.45, 1.0, len(STARS)); STAR_BIG = RNG.random(len(STARS)) < .12


def splat(img, px, py, b, big):
    h, w = img.shape[:2]
    for (x, y, bb, bg) in zip(px, py, b, big):
        x, y = int(x), int(y)
        if not (1 <= x < w - 1 and 1 <= y < h - 1): continue
        img[y, x] = np.maximum(img[y, x], np.array([1, 1, .92]) * bb)
        if bg:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)): img[y + dy, x + dx] = np.maximum(img[y + dy, x + dx], np.array([.8, .86, 1.0]) * bb * .7)


FACES = {  # name: (forward, right, up) in Roblox axes
    'Ft': ((0, 0, -1), (1, 0, 0), (0, 1, 0)), 'Bk': ((0, 0, 1), (-1, 0, 0), (0, 1, 0)),
    'Rt': ((1, 0, 0), (0, 0, 1), (0, 1, 0)), 'Lf': ((-1, 0, 0), (0, 0, -1), (0, 1, 0)),
    'Up': ((0, 1, 0), (1, 0, 0), (0, 0, 1)), 'Dn': ((0, -1, 0), (1, 0, 0), (0, 0, -1)),
}


def face(name, mode, n=1024):
    f, r, u = (np.array(v, float) for v in FACES[name])
    a = (np.arange(n) + .5) / n * 2 - 1
    A, Bv = np.meshgrid(a, -a)                                         # row 0 = top of the image
    D = f[None, None, :] + A[..., None] * r + Bv[..., None] * u
    img = sky(D[..., 0], D[..., 1], D[..., 2], mode)
    if mode == 'night':
        fd = STARS @ f; ok = fd > 1e-3
        pa = (STARS[ok] @ r) / fd[ok]; pb = (STARS[ok] @ u) / fd[ok]; inside = (np.abs(pa) < 1) & (np.abs(pb) < 1)
        moon_far = (STARS[ok][inside] @ MOON_R) < math.cos(math.radians(7))
        splat(img, ((pa[inside] + 1) / 2 * n)[moon_far], ((1 - pb[inside]) / 2 * n)[moon_far], STAR_B[ok][inside][moon_far], STAR_BIG[ok][inside][moon_far])
    return img


def equirect(mode, w=2048, h=1024):
    """Blender world mapping; Blender (x, y, z) = Roblox (X, -Z, Y)."""
    uu = (np.arange(w) + .5) / w; vv = 1 - (np.arange(h) + .5) / h
    U, V = np.meshgrid(uu, vv); lon = (U - .5) * 2 * np.pi; lat = (V - .5) * np.pi
    bx = -np.cos(lat) * np.cos(lon); by = np.cos(lat) * np.sin(lon); bz = np.sin(lat)
    img = sky(bx, bz, -by, mode)
    if mode == 'night':
        sx, sy, sz = STARS[:, 0], -STARS[:, 2], STARS[:, 1]              # to Blender axes
        su = np.arctan2(sy, -sx) / (2 * np.pi) + .5; sv = np.arctan2(sz, np.hypot(sx, sy)) / np.pi + .5
        far = (STARS @ MOON_R) < math.cos(math.radians(7))
        splat(img, (su * w)[far], ((1 - sv) * h)[far], STAR_B[far], STAR_BIG[far])
    return img


def save(path, rgb):
    h, w = rgb.shape[:2]
    px = np.concatenate([np.clip(rgb, 0, 1), np.ones((h, w, 1))], -1)[::-1].astype(np.float32)
    img = bpy.data.images.new('tmp', w, h, alpha=False); img.pixels.foreach_set(px.ravel())
    img.filepath_raw = path; img.file_format = 'PNG'; img.save(); bpy.data.images.remove(img)


strips = []
for mode in ('day', 'night'):
    os.makedirs(os.path.join(OUT, mode), exist_ok=True)
    imgs = {nm: face(nm, mode) for nm in FACES}
    for nm, im in imgs.items(): save(os.path.join(OUT, mode, 'Sky_%s.png' % nm), im)
    save(os.path.join(OUT, mode, '_equirect.png'), equirect(mode))
    small = {nm: im[::4, ::4] for nm, im in imgs.items()}; blank = np.ones_like(small['Ft'])
    strips.append(np.concatenate([np.concatenate([blank, small['Up'], blank, blank], 1),
                                  np.concatenate([small['Lf'], small['Ft'], small['Rt'], small['Bk']], 1),
                                  np.concatenate([blank, small['Dn'], blank, blank], 1)], 0))
save(os.path.join(OUT, '_preview.png'), np.concatenate(strips, 1))
print('SKY_OK')
