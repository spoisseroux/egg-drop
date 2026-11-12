"""Egg Drop world 1: seamless retro textures, generated procedurally.

Run:  blender -b --python assets/art-source/environment/textures/generate_textures.py
Writes small (64-128 px) tileable PNGs next to this script, plus _contact-sheet.png.
Everything is original: periodic value noise + wrapped Worley cells + palette ramps.
"""
import os, numpy as np, bpy

OUT = os.path.dirname(os.path.abspath(__file__))


def smooth(t):
    return t * t * (3 - 2 * t)


def tnoise(n, period, seed):
    """Tileable value noise, n x n, `period` lattice cells per tile."""
    rng = np.random.default_rng(seed)
    lat = rng.random((period, period))
    c = np.arange(n) / n * period
    i0 = np.floor(c).astype(int) % period
    i1 = (i0 + 1) % period
    f = smooth(c - np.floor(c))
    a = lat[np.ix_(i0, i0)]; b = lat[np.ix_(i0, i1)]
    c_ = lat[np.ix_(i1, i0)]; d = lat[np.ix_(i1, i1)]
    fx = f[None, :]; fy = f[:, None]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c_ * (1 - fx) + d * fx) * fy


def fbm(n, base, octs, seed, gain=0.5):
    out = np.zeros((n, n)); amp = 1.0; tot = 0.0
    for o in range(octs):
        out += amp * tnoise(n, base * 2 ** o, seed + o * 17); tot += amp; amp *= gain
    return out / tot


def worley(n, npts, seed, sx=1.0, sy=1.0):
    """Wrapped Worley: returns F1, F2 and nearest-cell id."""
    rng = np.random.default_rng(seed)
    pts = rng.random((npts, 2))
    y, x = np.mgrid[0:n, 0:n] / n
    dx = np.abs(x[..., None] - pts[:, 0]); dx = np.minimum(dx, 1 - dx) * sx
    dy = np.abs(y[..., None] - pts[:, 1]); dy = np.minimum(dy, 1 - dy) * sy
    d = np.sqrt(dx * dx + dy * dy)
    idx = np.argsort(d, axis=-1)
    f1 = np.take_along_axis(d, idx[..., :1], -1)[..., 0]
    f2 = np.take_along_axis(d, idx[..., 1:2], -1)[..., 0]
    return f1, f2, idx[..., 0]


def hexc(h):
    h = h.lstrip('#'); return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)])


def ramp(t, stops):
    """t in 0..1 -> rgb through evenly spaced hex stops."""
    cols = np.array([hexc(s) for s in stops]); xs = np.linspace(0, 1, len(stops))
    t = np.clip(t, 0, 1)
    return np.stack([np.interp(t, xs, cols[:, k]) for k in range(3)], -1)


def norm(a):
    return (a - a.min()) / (a.max() - a.min() + 1e-9)


def stamp(img, n, seed, count, cols, rmin, rmax, soft=False):
    """Wrapped little round stamps (pebbles / petals)."""
    rng = np.random.default_rng(seed)
    y, x = np.mgrid[0:n, 0:n]
    for _ in range(count):
        cx, cy = rng.random(2) * n; r = rng.uniform(rmin, rmax)
        col = hexc(cols[rng.integers(len(cols))])
        dx = np.abs(x - cx); dx = np.minimum(dx, n - dx)
        dy = np.abs(y - cy); dy = np.minimum(dy, n - dy)
        d = np.sqrt(dx * dx + dy * dy)
        m = d < r
        img[m] = col * (0.92 if soft else 1.0)
        img[d < r * 0.45] = np.clip(col * 1.06, 0, 1)
    return img


def srgb_to_linear(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def save(name, rgb, levels=28):
    n_y, n_x = rgb.shape[:2]
    rgb = np.clip(rgb, 0, 1)
    rgb = np.round(rgb * levels) / levels            # gentle posterise: the chunky retro step
    a = np.ones((n_y, n_x, 1))
    px = np.concatenate([rgb, a], -1)[::-1].astype(np.float32)
    img = bpy.data.images.new(name, n_x, n_y, alpha=False)   # byte image: values are display sRGB
    img.pixels.foreach_set(px.ravel())
    img.filepath_raw = os.path.join(OUT, name + '.png'); img.file_format = 'PNG'; img.save()
    return rgb


sheet = {}
N = 128

# 1 grass: fresh aero green, soft mottling + short blade flecks
g = fbm(N, 4, 4, 11); blades = tnoise(N, 64, 12); b2 = np.roll(blades, 1, 0)
t = 0.5 * g + 0.25 * norm(fbm(N, 16, 2, 13)) + 0.25 * ((blades > .62) & (b2 > .5))
sheet['grass'] = save('grass', ramp(norm(t), ['#4FB36C', '#62C777', '#7BD886', '#9BE79A', '#C4F3B0']))

# 2 meadow: lighter grass sprinkled with tiny pastel flowers
m = ramp(norm(0.6 * fbm(N, 4, 4, 21) + 0.4 * tnoise(N, 32, 22)), ['#63C482', '#7FD98F', '#A2EBA2', '#C9F6B8'])
m = stamp(m, N, 23, 26, ['#FFFFFF', '#FFF3A6', '#FFC6E0', '#CFE8FF'], 1.3, 2.3)
sheet['meadow'] = save('meadow', m)

# 3 dirt path: warm cream, packed, with fine pebbles
d = ramp(norm(0.7 * fbm(N, 4, 4, 31) + 0.3 * tnoise(N, 48, 32)), ['#D9BE93', '#E7D0A6', '#F1DFBB', '#F9EED3'])
d = stamp(d, N, 33, 34, ['#CDB08A', '#F7ECD6', '#C9B7A2'], 1.0, 2.6, soft=True)
sheet['dirt_path'] = save('dirt_path', d)

# 4 cliff rock: broad lavender strata with soft tall fractures and cream ledges (reads as cliff, not cobble)
y, x = np.mgrid[0:N, 0:N] / N
warp = fbm(N, 2, 3, 41) * 0.30
bands = norm(np.sin((y + warp) * 2 * np.pi * 3) * 0.5 + 0.5 + 0.35 * tnoise(N, 4, 44))
ledge = np.clip(np.sin((y + warp) * 2 * np.pi * 3 + 1.3), 0, 1) ** 6          # thin bright ledge lines
f1, f2, _ = worley(N, 9, 42, sx=1.6, sy=0.45)                                 # tall fracture cells
crack = np.clip(1 - (f2 - f1) * 20, 0, 1)
t = norm(0.6 * bands + 0.4 * fbm(N, 5, 4, 43))
c = ramp(t, ['#7E84BE', '#979BD0', '#B2B3E1', '#CECAED', '#F2EBEA'])
c = c * (1 - 0.09 * crack[..., None]) + ledge[..., None] * 0.10
sheet['cliff_rock'] = save('cliff_rock', c)

# 5 boulder rock: smoother pebble-stone, cooler, speckled
f1, f2, _ = worley(N, 26, 51)
t = norm(0.6 * fbm(N, 4, 4, 52) + 0.4 * norm(f1))
b = ramp(t, ['#8E96C8', '#A6ADDA', '#BFC4E8', '#DAD9F2', '#F3EEEE'])
b *= (1 - 0.18 * np.clip(1 - (f2 - f1) * 14, 0, 1)[..., None])
sheet['boulder_rock'] = save('boulder_rock', b)

# 6 sand + pebbles
s = ramp(norm(0.7 * fbm(N, 5, 4, 61) + 0.3 * tnoise(N, 64, 62)), ['#EAD9B0', '#F3E6C3', '#FBF2D8', '#FFFBEA'])
s = stamp(s, N, 63, 22, ['#C9CDE6', '#E3C9A8', '#FFFFFF', '#B9D8E8'], 1.5, 3.6, soft=True)
sheet['sand_pebble'] = save('sand_pebble', s)

# 7 water: bright aqua with caustic net
f1, f2, _ = worley(N, 14, 71)
caus = np.clip(1 - (f2 - f1) * 9, 0, 1) ** 2
t = norm(fbm(N, 3, 3, 72))
w = ramp(0.25 + 0.5 * t, ['#39B9E6', '#52CDEE', '#7BE0F2', '#A8F0F4'])
w = w + caus[..., None] * np.array([0.30, 0.22, 0.14])
sheet['water'] = save('water', w)

# 8 waterfall: vertical streaks (tiles both ways; scroll V in engine)
col = np.repeat(tnoise(N, 24, 81)[0:1, :], N, 0)            # per-column streak value
st = norm(0.65 * col + 0.35 * tnoise(N, 16, 83) * np.repeat(tnoise(N, 8, 82)[0:1, :], N, 0))
wf = ramp(st, ['#58C8EE', '#86DDF4', '#BCEFFA', '#FFFFFF', '#FFFFFF'])
sheet['waterfall'] = save('waterfall', wf)

# 9 wood planks: four boards per tile, honey wood
yy = (np.arange(N) / N * 4)
board = np.floor(yy).astype(int); edge = np.abs(yy - np.floor(yy) - 0.5) > 0.45
rngb = np.random.default_rng(91).random(4)
grain = tnoise(N, 4, 92) * 0.4 + np.repeat(tnoise(N, 32, 93)[:, 0:1], N, 1) * 0.6
t = norm(grain) * 0.7 + rngb[board][:, None] * 0.3
wd = ramp(t, ['#B98455', '#CC9A66', '#DDB07C', '#EBC694'])
wd[edge, :, :] *= 0.72
sheet['wood_plank'] = save('wood_plank', wd)

# 10 bark: vertical ridges
ridge = np.repeat(tnoise(N, 20, 101)[0:1, :], N, 0)
t = norm(0.6 * ridge + 0.4 * fbm(N, 4, 3, 102))
sheet['bark'] = save('bark', ramp(t, ['#7A5A48', '#8F6B55', '#A88467', '#C2A081']))

# 11 foliage: leafy clumps, minty
f1, f2, cid = worley(N, 34, 111)
shade = np.random.default_rng(112).random(34)[cid]
t = norm(0.55 * (1 - norm(f1)) + 0.25 * shade + 0.2 * fbm(N, 6, 3, 113))
sheet['foliage'] = save('foliage', ramp(t, ['#3FA877', '#55BF85', '#74D596', '#9BE8A6', '#CDF7BD']))

# 12 blossom foliage: same clumps in sherbet pink
sheet['foliage_blossom'] = save('foliage_blossom', ramp(t, ['#E88FB4', '#F3A6C4', '#FBC0D6', '#FFDCE8', '#FFF4F7']))

# 13 stone tile: pale cobbles for station pads / plaza
f1, f2, cid = worley(N, 20, 131)
shade = np.random.default_rng(132).random(20)[cid]
grout = np.clip(1 - (f2 - f1) * 22, 0, 1)
t = norm(0.5 * shade + 0.5 * fbm(N, 6, 3, 133))
stn = ramp(t, ['#D9DCEF', '#E6E7F5', '#F2F1FA', '#FFFDF8'])
stn = stn * (1 - 0.28 * grout[..., None])
sheet['stone_tile'] = save('stone_tile', stn)

# 14 far peak: soft snow-rock for distant mountains (64 px)
t = norm(fbm(64, 3, 4, 141))
sheet['far_peak'] = save('far_peak', ramp(t, ['#A9B8E6', '#BDC9EE', '#D3DBF5', '#EEF1FB']))

# contact sheet: each tile shown 2x2 so any seam would be visible
names = list(sheet); cols = 5; rows = (len(names) + cols - 1) // cols; cell = 256; pad = 6
S = np.ones((rows * (cell + pad) + pad, cols * (cell + pad) + pad, 3))
for i, nm in enumerate(names):
    im = sheet[nm]
    k = cell // (2 * im.shape[0])
    big = np.tile(np.kron(im, np.ones((k, k, 1))), (2, 2, 1))
    r, c0 = divmod(i, cols)
    y0 = pad + r * (cell + pad); x0 = pad + c0 * (cell + pad)
    S[y0:y0 + cell, x0:x0 + cell] = big
save('_contact-sheet', S, levels=255)
print('TEXTURES_OK', len(names))
