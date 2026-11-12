"""Egg Drop world 1 (v4): hand-painted-style seamless textures, 256 px max. Standalone.

Run:  blender --factory-startup -b --python assets/art-source/environment/textures/v4/generate_textures_v4.py

Direction (v4): late-90s / early-2000s console look. Painted detail instead of noise:
brush strokes, drawn cracks with a light bevel, block seams, pebbles, and a carved trim sheet
with our OWN motifs (paw prints, stars, eggs, leaves, a zig-zag "hop" band). Everything tiles.
"""
import os, math, numpy as np, bpy

OUT = os.path.dirname(os.path.abspath(__file__))
N = 256


def smooth(t): return t * t * (3 - 2 * t)


def tnoise(n, period, seed):
    rng = np.random.default_rng(seed); lat = rng.random((period, period))
    c = np.arange(n) / n * period; i0 = np.floor(c).astype(int) % period; i1 = (i0 + 1) % period; f = smooth(c - np.floor(c))
    a = lat[np.ix_(i0, i0)]; b = lat[np.ix_(i0, i1)]; c_ = lat[np.ix_(i1, i0)]; d = lat[np.ix_(i1, i1)]
    fx = f[None, :]; fy = f[:, None]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c_ * (1 - fx) + d * fx) * fy


def soft(n, seed, base=2):
    a = tnoise(n, base, seed) * .6 + tnoise(n, base * 2, seed + 5) * .3 + tnoise(n, base * 4, seed + 9) * .1
    return (a - a.min()) / (a.max() - a.min() + 1e-9)


def worley(n, npts, seed, sx=1.0, sy=1.0):
    rng = np.random.default_rng(seed); pts = rng.random((npts, 2))
    y, x = np.mgrid[0:n, 0:n] / n
    dx = np.abs(x[..., None] - pts[:, 0]); dx = np.minimum(dx, 1 - dx) * sx
    dy = np.abs(y[..., None] - pts[:, 1]); dy = np.minimum(dy, 1 - dy) * sy
    d = np.sqrt(dx * dx + dy * dy); idx = np.argsort(d, axis=-1)
    return np.take_along_axis(d, idx[..., :1], -1)[..., 0], np.take_along_axis(d, idx[..., 1:2], -1)[..., 0], idx[..., 0]


def strokes(n, seed, count, lmin, lmax, ang, spread, taper=True):
    """Wrapped brush strokes -> coverage map 0..1 (each stroke fades toward its tip)."""
    rng = np.random.default_rng(seed); a = np.zeros((n, n))
    x0 = rng.random(count) * n; y0 = rng.random(count) * n; L = rng.integers(lmin, lmax + 1, count)
    th = ang + (rng.random(count) - .5) * 2 * spread
    for q in range(lmax):
        live = q < L
        xs = (x0 + np.cos(th) * q).astype(int) % n; ys = (y0 + np.sin(th) * q).astype(int) % n
        w = np.where(live, (1 - q / L) if taper else 1.0, 0.0)
        np.maximum.at(a, (ys, xs), w)
    return a


def hexc(h):
    h = h.lstrip('#'); return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)])


def ramp(t, stops):
    cols = np.array([hexc(s) for s in stops]); xs = np.linspace(0, 1, len(stops)); t = np.clip(t, 0, 1)
    return np.stack([np.interp(t, xs, cols[:, k]) for k in range(3)], -1)


def mix(a, b, m):
    return a * (1 - m[..., None]) + b * m[..., None]


def flat(col, shape=(N, N)):
    return np.ones((*shape, 3)) * hexc(col)


sheet = {}


def save(name, rgb, levels=64):
    n_y, n_x = rgb.shape[:2]
    rgb = np.round(np.clip(rgb, 0, 1) * levels) / levels
    px = np.concatenate([rgb, np.ones((n_y, n_x, 1))], -1)[::-1].astype(np.float32)
    img = bpy.data.images.new(name, n_x, n_y, alpha=False)
    img.pixels.foreach_set(px.ravel()); img.filepath_raw = os.path.join(OUT, name + '.png'); img.file_format = 'PNG'; img.save()
    if name[0] != '_': sheet[name] = rgb
    return rgb


UP = -math.pi / 2                                                     # image rows run downward: "up" strokes

# ---- grass: deep green base, painted blade strokes in three passes (uniform from afar, rich up close)
g = ramp(soft(N, 11, 3), ['#178A2C', '#1E9A31', '#27A736'])
g = mix(g, flat('#127A27'), .55 * strokes(N, 12, 2600, 5, 11, UP, .5))
g = mix(g, flat('#3BBF41'), .70 * strokes(N, 13, 3000, 5, 12, UP, .45))
g = mix(g, flat('#74DC55'), .75 * strokes(N, 14, 1100, 3, 7, UP, .4))
save('grass', g)
m = mix(g, flat('#2FB23C'), np.full((N, N), .25))
yy, xx = np.mgrid[0:N, 0:N]
rng = np.random.default_rng(23)
for _ in range(34):                                                   # little painted flowers: petals + centre
    cx, cy = rng.integers(0, N, 2); col = ['#FFFFFF', '#FFE45C', '#FF8FC4', '#BFA2FF'][rng.integers(4)]
    for k in range(5):
        a = k / 5 * 6.283; px_, py_ = (cx + 2.4 * math.cos(a)) % N, (cy + 2.4 * math.sin(a)) % N
        dx = np.minimum(np.abs(xx - px_), N - np.abs(xx - px_)); dy = np.minimum(np.abs(yy - py_), N - np.abs(yy - py_))
        m[dx * dx + dy * dy < 2.6] = hexc(col)
    dx = np.minimum(np.abs(xx - cx), N - np.abs(xx - cx)); dy = np.minimum(np.abs(yy - cy), N - np.abs(yy - cy))
    m[dx * dx + dy * dy < 2.2] = hexc('#FFB52E')
save('meadow', m)

# ---- neutral tile for vertex-coloured sand / rock ground
save('ground_soft', ramp(.6 * soft(N, 1) + .4 * strokes(N, 2, 900, 4, 9, 0, 3.14), ['#E2E2E2', '#F0F0F0', '#FFFFFF']))

# ---- rock: warm-grey / olive stone, big drawn cracks with a light bevel, fine secondary cracks, brushed mottling
f1, f2, cid = worley(N, 9, 42, sx=1.0, sy=1.25)
shade = np.random.default_rng(43).random(9)[cid]
wob = .012 * (tnoise(N, 16, 44) - .5)
crack = np.clip(1 - (f2 - f1 + wob) * 38, 0, 1)
bevel = np.clip(np.roll(np.roll(crack, 2, 0), 2, 1) - crack, 0, 1)
g1, g2, _ = worley(N, 34, 45)
fine = np.clip(1 - (g2 - g1) * 60, 0, 1) * (tnoise(N, 6, 46) > .55)
r = ramp(.45 * shade + .35 * soft(N, 47, 3) + .2 * strokes(N, 48, 1500, 6, 14, .3, .6), ['#8C8769', '#A19B7C', '#B6AF8E', '#CBC4A2'])
r = mix(r, flat('#5E5A45'), .85 * crack); r = mix(r, flat('#E3DDBF'), .55 * bevel); r = mix(r, flat('#77735A'), .45 * fine)
save('cliff_rock', r)
b = ramp(.6 * soft(N, 52, 3) + .4 * strokes(N, 53, 1400, 5, 12, .4, .8), ['#A8A283', '#BDB696', '#D1CAA9', '#E2DCC0'])
h1, h2, _ = worley(N, 16, 54); b = mix(b, flat('#7E795F'), .5 * np.clip(1 - (h2 - h1) * 46, 0, 1))
save('boulder_rock', b)

# ---- marble blocks: lilac-white / cream ashlar with seams (4 courses per tile, running bond)
ROWS, BW = 4, 128
yy, xx = np.mgrid[0:N, 0:N]
row = yy // (N // ROWS); xo = (xx + (row % 2) * (BW // 2)) % N; blk = row * 2 + xo // BW
tone = np.random.default_rng(61).random(ROWS * 2)[blk]
mb_ = ramp(.55 * tone + .45 * soft(N, 62, 3), ['#E9E1F0', '#F1EBF3', '#F7F2EC', '#FBF6E8'])
vein = np.abs(np.sin((2 * xx / N + yy / N + soft(N, 63) * 1.2) * 2 * np.pi)) ** .3
mb_ = mb_ * (1 - .05 * (1 - vein)[..., None])
sy_ = yy % (N // ROWS); sx_ = xo % BW
seam = (sy_ < 2) | (sx_ < 2); hi = ((sy_ >= 2) & (sy_ < 4)) | ((sx_ >= 2) & (sx_ < 4)); lo = (sy_ >= N // ROWS - 2) | (sx_ >= BW - 2)
mb_[lo] *= .93; mb_[hi] = np.clip(mb_[hi] * 1.035, 0, 1); mb_[seam] = hexc('#B3A9BF')
save('marble_block', mb_)

# ---- carved trim sheet: four 64 px bands, four 64 px cells each. Our own motifs.
CREAM, GOLD, GOLD_D, TEAL, TEAL_D = '#F6F0E4', '#EDBB45', '#B98A22', '#27B5AD', '#17857F'
tr = flat(CREAM) * (0.97 + .03 * soft(N, 71, 4))[..., None]
u = ((xx % 64) + .5) / 32 - 1; v = 1 - ((yy % 64) + .5) / 32          # cell coords, -1..1, v up
band = yy // 64; cell = xx // 64
def put(mask, col, where): tr[mask & where] = hexc(col)
def relief(shape_fn, where, fill, dark):
    put(shape_fn(1.0), dark, where); put(shape_fn(.80), fill, where)
def paw(s): return (((u / (.46 * s)) ** 2 + ((v + .22) / (.36 * s)) ** 2) < 1) | np.any([((u - a) ** 2 + (v - b_) ** 2) < (.165 * s) ** 2 for a, b_ in ((-.5, .22), (-.18, .5), (.18, .5), (.5, .22))], axis=0)
def star(s):
    th_ = np.arctan2(v, u) - math.pi / 2; rr = np.hypot(u, v)
    return rr < s * (.30 + .40 * np.abs(np.cos(2.5 * th_)) ** 2.2)
def egg(s): return ((u / (.44 * s * (1 - .16 * v))) ** 2 + ((v + .04) / (.60 * s)) ** 2) < 1
def leaf(s):
    c_, s_ = math.cos(.6), math.sin(.6); a = u * c_ + v * s_; b_ = -u * s_ + v * c_
    return (np.abs(b_) < .34 * s * (1 - (a / (.74 * s)) ** 2)) & (np.abs(a) < .74 * s)
relief(paw, (band == 0) & (cell % 2 == 0), GOLD, GOLD_D); relief(star, (band == 0) & (cell % 2 == 1), TEAL, TEAL_D)
relief(egg, (band == 2) & (cell % 2 == 0), TEAL, TEAL_D); relief(leaf, (band == 2) & (cell % 2 == 1), GOLD, GOLD_D)
put((np.abs(v) < .07) & ((u + .5) % 1.0 < .35), CREAM, (band == 2) & (cell % 2 == 0) & egg(.80))   # a stripe on the egg
zig = np.abs(v - (np.abs(((u + 1) % 1.0) - .5) * 1.6 - .4))           # band 1: zig-zag "hop" line with dots
put(zig < .13, TEAL_D, band == 1); put(zig < .08, TEAL, band == 1)
put(((((u + 1.25) % 1.0) - .5) ** 2 + (v - .52) ** 2) < .012, GOLD, band == 1); put(((((u + .75) % 1.0) - .5) ** 2 + (v + .56) ** 2) < .012, GOLD, band == 1)
for bnd in (0, 1, 2):                                                  # border rules on the carved bands
    yb = yy - bnd * 64
    tr[(band == bnd) & ((yb < 3) | (yb > 60))] = hexc('#CFC4D6'); tr[(band == bnd) & ((yb == 3) | (yb == 60))] = hexc(GOLD_D)
yb = yy - 192                                                          # band 3: plain moulding
mould = .94 + .06 * np.sin(yb / 64 * math.pi * 6)
tr[band == 3] = (flat('#F3ECE6') * mould[..., None])[band == 3]
save('marble_trim', tr)

# ---- pebble bed for the stream / pools (seen through clear water)
p1, p2, pid = worley(N, 70, 81)
pcol = np.array([hexc(c) for c in ('#D9C79A', '#C8B98F', '#B9B2A0', '#A9B7BE', '#E6D9B4', '#BFA982')])[np.random.default_rng(82).integers(0, 6, 70)[pid]]
gap = np.clip(1 - (p2 - p1) * 30, 0, 1); dome = np.clip(1 - p1 * 9, 0, 1)
pb = pcol * (.86 + .22 * dome[..., None]); pb = mix(pb, flat('#7C7458'), .8 * gap)
save('pebble_bed', pb)

# ---- water surface (the material is ~40% opaque): light cyan with a painted caustic net
c1, c2, _ = worley(N, 12, 91)
caus = np.clip(1 - (c2 - c1) * 12, 0, 1) ** 1.5
w = ramp(soft(N, 92), ['#35B6F5', '#4FC6FA', '#6FD6FD']); w = mix(w, flat('#F2FCFF'), .55 * caus)
save('water', w)
col = np.repeat(tnoise(N, 16, 101)[0:1, :], N, 0)
stv = .7 * col + .3 * tnoise(N, 8, 103) * np.repeat(tnoise(N, 8, 102)[0:1, :], N, 0); stv = (stv - stv.min()) / (stv.max() - stv.min())
wf = ramp(stv, ['#2FA9F6', '#63C8FC', '#B9E9FF', '#FFFFFF']); wf = mix(wf, flat('#FFFFFF'), .5 * strokes(N, 104, 500, 10, 26, math.pi / 2, .08))
save('waterfall', wf)

# ---- sand, path, wood, bark, foliage
s = ramp(.6 * soft(N, 111, 3) + .4 * strokes(N, 112, 1200, 4, 9, 0, 3.14), ['#EBD28E', '#F3DFA4', '#FAEBBC'])
q1, q2, _ = worley(N, 26, 113); s = mix(s, flat('#D9BD7A'), .5 * np.clip(1 - q1 * 22, 0, 1))
save('sand_pebble', s)
d = ramp(.55 * soft(N, 121, 3) + .45 * strokes(N, 122, 1600, 5, 11, 0, 3.14), ['#C99A58', '#D9AE6C', '#E7C283'])
q1, q2, _ = worley(N, 40, 123); d = mix(d, flat('#F1D9A6'), .75 * np.clip(1 - q1 * 26, 0, 1)); d = mix(d, flat('#A97C42'), .5 * np.clip(1 - (q2 - q1) * 40, 0, 1) * (tnoise(N, 5, 124) > .6))
save('dirt_path', d)
yb = yy % 64; brd = yy // 64
wd = ramp(.5 * np.repeat(tnoise(N, 12, 131)[:, 0:1], N, 1) + .2 * np.random.default_rng(132).random(4)[brd] + .3 * strokes(N, 133, 900, 14, 40, 0, .05), ['#9C5E2C', '#B27239', '#C68948', '#D69D5A'])
wd[(yb < 2)] = hexc('#6E3F1B'); wd[(yb >= 2) & (yb < 4)] = np.clip(wd[(yb >= 2) & (yb < 4)] * 1.12, 0, 1)
save('wood_plank', wd)
bk = ramp(.5 * np.repeat(tnoise(N, 14, 141)[0:1, :], N, 0) + .5 * strokes(N, 142, 1300, 10, 30, math.pi / 2, .12), ['#5E3A20', '#74492A', '#8B5A35', '#A26D43'])
save('bark', bk)
l1, l2, lid = worley(N, 46, 151)
lshade = np.random.default_rng(152).random(46)[lid]
lt = .5 * (1 - np.clip(l1 * 7, 0, 1)) + .3 * lshade + .2 * strokes(N, 153, 900, 4, 8, .8, 1.2)
save('foliage', ramp(lt, ['#147A27', '#1F9631', '#33B23D', '#55CC4B', '#86E263']))
save('foliage_blossom', ramp(lt, ['#E0508F', '#F06BA5', '#FA8CBB', '#FFB1D1', '#FFD6E6']))
save('stone_tile', mb_)
save('far_peak', np.ones((64, 64, 3)))

names = list(sheet); cols = 5; rows = (len(names) + cols - 1) // cols; cellp = 256; pad = 6
Sh = np.ones((rows * (cellp + pad) + pad, cols * (cellp + pad) + pad, 3))
for i, nm in enumerate(names):
    im = sheet[nm]; k = max(1, cellp // im.shape[0])
    big = np.kron(im, np.ones((k, k, 1)))[:cellp, :cellp]
    rr, c0 = divmod(i, cols)
    Sh[pad + rr * (cellp + pad):pad + rr * (cellp + pad) + cellp, pad + c0 * (cellp + pad):pad + c0 * (cellp + pad) + cellp] = big
save('_contact-sheet', Sh, levels=255)
print('TEXTURES_V4_OK', len(names))
