"""Egg Drop world 1 (v2): calm, saturated, seamless retro textures.

Run:  blender --factory-startup -b --python assets/art-source/environment/textures/v2/generate_textures_v2.py

v2 direction: each surface is close to one flat colour with large, soft, low-contrast
variation, so grass / path / stone / water / wood / blossom read apart at a glance.
ground_soft.png is a neutral near-white tile: the terrain multiplies it by vertex colour.
"""
import os, numpy as np, bpy

OUT = os.path.dirname(os.path.abspath(__file__))


def smooth(t):
    return t * t * (3 - 2 * t)


def tnoise(n, period, seed):
    rng = np.random.default_rng(seed)
    lat = rng.random((period, period))
    c = np.arange(n) / n * period
    i0 = np.floor(c).astype(int) % period; i1 = (i0 + 1) % period
    f = smooth(c - np.floor(c))
    a = lat[np.ix_(i0, i0)]; b = lat[np.ix_(i0, i1)]; c_ = lat[np.ix_(i1, i0)]; d = lat[np.ix_(i1, i1)]
    fx = f[None, :]; fy = f[:, None]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c_ * (1 - fx) + d * fx) * fy


def soft(n, seed, base=2):
    """Large soft blotches only (two low octaves)."""
    a = tnoise(n, base, seed) * .65 + tnoise(n, base * 2, seed + 5) * .35
    return (a - a.min()) / (a.max() - a.min() + 1e-9)


def worley(n, npts, seed, sx=1.0, sy=1.0):
    rng = np.random.default_rng(seed); pts = rng.random((npts, 2))
    y, x = np.mgrid[0:n, 0:n] / n
    dx = np.abs(x[..., None] - pts[:, 0]); dx = np.minimum(dx, 1 - dx) * sx
    dy = np.abs(y[..., None] - pts[:, 1]); dy = np.minimum(dy, 1 - dy) * sy
    d = np.sqrt(dx * dx + dy * dy); idx = np.argsort(d, axis=-1)
    f1 = np.take_along_axis(d, idx[..., :1], -1)[..., 0]; f2 = np.take_along_axis(d, idx[..., 1:2], -1)[..., 0]
    return f1, f2, idx[..., 0]


def hexc(h):
    h = h.lstrip('#'); return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)])


def ramp(t, stops):
    cols = np.array([hexc(s) for s in stops]); xs = np.linspace(0, 1, len(stops)); t = np.clip(t, 0, 1)
    return np.stack([np.interp(t, xs, cols[:, k]) for k in range(3)], -1)


def dots(img, n, seed, count, cols, rmin, rmax):
    rng = np.random.default_rng(seed); y, x = np.mgrid[0:n, 0:n]
    for _ in range(count):
        cx, cy = rng.random(2) * n; r = rng.uniform(rmin, rmax); col = hexc(cols[rng.integers(len(cols))])
        dx = np.abs(x - cx); dx = np.minimum(dx, n - dx); dy = np.abs(y - cy); dy = np.minimum(dy, n - dy)
        img[np.sqrt(dx * dx + dy * dy) < r] = col
    return img


def save(name, rgb, levels=40):
    n_y, n_x = rgb.shape[:2]
    rgb = np.round(np.clip(rgb, 0, 1) * levels) / levels
    px = np.concatenate([rgb, np.ones((n_y, n_x, 1))], -1)[::-1].astype(np.float32)
    img = bpy.data.images.new(name, n_x, n_y, alpha=False)
    img.pixels.foreach_set(px.ravel()); img.filepath_raw = os.path.join(OUT, name + '.png'); img.file_format = 'PNG'; img.save()
    return rgb


sheet = {}
N = 128
sheet['ground_soft'] = save('ground_soft', ramp(soft(N, 1), ['#E9E9E9', '#F4F4F4', '#FFFFFF']))
sheet['grass'] = save('grass', ramp(soft(N, 11), ['#39B844', '#45C54C', '#55D257']))
sheet['meadow'] = save('meadow', dots(ramp(soft(N, 21), ['#45C54C', '#55D257', '#69DC62']), N, 23, 16, ['#FFFFFF', '#FFE96B', '#FF9CC8'], 1.4, 2.2))
sheet['dirt_path'] = save('dirt_path', dots(ramp(soft(N, 31), ['#E3BC79', '#ECCA8B', '#F3D79E']), N, 33, 9, ['#D6AC68', '#F8E3B4'], 1.2, 2.2))
# stone: a few big flat-shaded facets with soft seams -> reads as planes, not grain
f1, f2, cid = worley(N, 7, 42, sx=1.0, sy=1.3)
shade = np.random.default_rng(43).random(7)[cid]
seam = np.clip(1 - (f2 - f1) * 26, 0, 1)
st = ramp(.7 * shade + .3 * soft(N, 44), ['#BFAF93', '#CDBFA5', '#DBCFB8', '#E6DCC8'])
sheet['cliff_rock'] = save('cliff_rock', st * (1 - .07 * seam[..., None]))
sheet['boulder_rock'] = save('boulder_rock', ramp(soft(N, 52), ['#D6CBB5', '#E2D9C6', '#EEE7D8']))
sheet['sand_pebble'] = save('sand_pebble', dots(ramp(soft(N, 61), ['#F3E0A8', '#F8EABD', '#FDF3D2']), N, 63, 8, ['#E9D197', '#FFFFFF'], 1.2, 2.0))
f1, f2, _ = worley(N, 9, 71)
caus = np.clip(1 - (f2 - f1) * 10, 0, 1) ** 2
sheet['water'] = save('water', ramp(soft(N, 72), ['#1996F0', '#27A6F6', '#3DB6FB']) + caus[..., None] * np.array([.10, .10, .06]))
col = np.repeat(tnoise(N, 12, 81)[0:1, :], N, 0)
stv = .75 * col + .25 * tnoise(N, 8, 83) * np.repeat(tnoise(N, 6, 82)[0:1, :], N, 0)
stv = (stv - stv.min()) / (stv.max() - stv.min())
sheet['waterfall'] = save('waterfall', ramp(stv, ['#3FB4FA', '#74CDFD', '#C4ECFF', '#FFFFFF']))
yy = np.arange(N) / N * 4; board = np.floor(yy).astype(int); edge = np.abs(yy - np.floor(yy) - .5) > .46
t = .6 * np.repeat(tnoise(N, 8, 93)[:, 0:1], N, 1) + .4 * np.random.default_rng(91).random(4)[board][:, None]
wd = ramp(t, ['#B26F36', '#C28246', '#D09456']); wd[edge, :, :] *= .78
sheet['wood_plank'] = save('wood_plank', wd)
sheet['bark'] = save('bark', ramp(.6 * np.repeat(tnoise(N, 10, 101)[0:1, :], N, 0) + .4 * soft(N, 102), ['#77492A', '#885733', '#99653E']))
f1, f2, cid = worley(N, 16, 111)
shade = np.random.default_rng(112).random(16)[cid]
t = .55 * (1 - f1 / f1.max()) + .45 * shade
sheet['foliage'] = save('foliage', ramp(t, ['#2BA23B', '#38B545', '#4CC852', '#66D962']))
sheet['foliage_blossom'] = save('foliage_blossom', ramp(t, ['#F2639E', '#F97DB1', '#FF9BC6', '#FFBEDB']))
f1, f2, cid = worley(N, 14, 131)
shade = np.random.default_rng(132).random(14)[cid]
sheet['stone_tile'] = save('stone_tile', ramp(shade, ['#E2DACB', '#ECE6DA', '#F5F1E8']) * (1 - .16 * np.clip(1 - (f2 - f1) * 22, 0, 1)[..., None]))
sheet['far_peak'] = save('far_peak', ramp(soft(64, 141), ['#EDEDED', '#F7F7F7', '#FFFFFF']))

names = list(sheet); cols = 5; rows = (len(names) + cols - 1) // cols; cell = 256; pad = 6
Sh = np.ones((rows * (cell + pad) + pad, cols * (cell + pad) + pad, 3))
for i, nm in enumerate(names):
    im = sheet[nm]; k = cell // (2 * im.shape[0])
    big = np.tile(np.kron(im, np.ones((k, k, 1))), (2, 2, 1))
    r, c0 = divmod(i, cols)
    Sh[pad + r * (cell + pad):pad + r * (cell + pad) + cell, pad + c0 * (cell + pad):pad + c0 * (cell + pad) + cell] = big
save('_contact-sheet', Sh, levels=255)
print('TEXTURES_V2_OK', len(names))
