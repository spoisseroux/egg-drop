"""Egg Drop - World 1 mockup v2 ("Chime Cove"). New organic layout, built from code.

  blender --factory-startup -b --python artifacts/world1-mockup/v2/build_world_v2.py

Writes assets/art-source/environment/world1-mockup-v2.blend and v2/stats.json.
The garden is a kidney-shaped bowl described in polar form around the origin (no rectangle,
no v1 greybox): RIM(theta) is the edge of the walkable floor, wall_H(theta) the rock wall
behind it (zero where the garden is open to the sea).
Coordinates as v1: Blender (x, y, z) = Roblox (X, -Z, Y - 4); 1 unit = 1 stud.
"""
import bpy, bmesh, math, os, json, random, sys
from mathutils import Vector, Matrix, Euler

HERE = os.path.dirname(os.path.abspath(__file__))
exec(compile(open(os.path.join(HERE, 'world_lib.py'), encoding='utf-8').read(), 'world_lib.py', 'exec'))
REPO = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
ENV = os.path.join(REPO, 'assets', 'art-source', 'environment')
TEX = os.path.join(ENV, 'textures', 'v2')
OUT = os.path.join(ENV, 'world1-mockup-v2.blend')
BEAR = os.path.join(REPO, 'assets', 'garden-babies', 'bear.fbx')
rnd = random.Random(2026)
_ico_cache = {}
STATS = {}
WATER = -0.8          # stream + pools
SEA = -4.0            # the cove and open sea sit just below the lawn
SUN = Vector((-0.50, -0.45, 0.74)).normalized()


# ------------------------------------------------------------------ footprint (polar)
def angd(a, b):
    return (a - b + 180) % 360 - 180


def g(th, c, w):
    return math.exp(-(angd(th, c) / w) ** 2)


def RIM(th):
    """Radius of the garden floor at angle th (deg; 0 = east, 90 = south, 180 = west, 270 = north)."""
    return (89 + 36 * g(th, 32, 22)        # arrival peninsula (south-east)
            - 37 * g(th, 97, 17)           # the cove bites in from the south
            + 12 * g(th, 150, 22)          # knoll shoulder (south-west)
            + 22 * g(th, 187, 9)           # Blossom Point (west spit)
            - 9 * g(th, 232, 16)           # north-west pinch
            + 5 * g(th, 268, 14)           # grotto bay
            + 15 * g(th, 314, 19)          # falls basin (north-east)
            - 8 * g(th, 352, 12)
            + 3 * math.sin(math.radians(3 * th)) + 2 * math.sin(math.radians(7 * th + 40)))


def wall_env(th):
    t = th if th >= 100 else th + 360
    return S((t - 200) / 16) * S((378 - t) / 16)


def wall_H(th):
    return wall_env(th) * (15 + 30 * g(th, 318, 20) + 13 * g(th, 268, 15) + 6 * g(th, 226, 11) + 3 * math.sin(math.radians(th * 5)))


def polar(X, Z):
    return math.hypot(X, Z), math.degrees(math.atan2(Z, X)) % 360


def P(th, r):
    return r * math.cos(math.radians(th)), r * math.sin(math.radians(th))


# ------------------------------------------------------------------ layout data
FALLS_TH = 315
STREAM = chaikin([(60, -62), (44, -44), (30, -30), (20, -18), (12, -6), (3, 8), (5, 24), (0, 38), (-5, 50), (-7, 62), (-7, 80)], 3)
FALLS_POOL = (57, -58, 15, 13)
LILY = (13, -8, 11, 9)
SPUR = chaikin([(19, -96), (22, -72), (15, -54), (17, -42)], 2)
KNOLL = (-60, 50, 10.5, 9.0)       # X, Z, top radius, height
GROTTO_TH = 266
STATIONS = {
    'EggSpot': (-31, -11), 'CareMachine': (-17, -15), 'Workbench': (-46, -9),
    'BenchWest': (-43, 5), 'BenchEast': (-17, 5), 'ToyLawn': (-30, 17),
    'PicnicWest': (-58, 12), 'PicnicEast': (34, 46), 'CreekNook': (1, -33),
    'SpringRestWest': (49.5, 14), 'SpringRestEast': (54.5, 14), 'SpringBasin': (52, 3),
    'Spawn': (96, 66),
}
HATCH_TREE = (-36, -18)
HUB = (-30, -4)
CENTRE = (0.0, 0.0)
PADS = [(HUB[0], HUB[1], 25, 37), (52, 10, 10, 17), (96, 66, 7, 12), (1, -33, 5, 9), (34, 46, 5, 9), (-58, 12, 5, 9), (-97, -11, 6, 11), (4, 21, 4, 9)]
PATHS = {
    'Path_SpawnToHub': [(101, 70), (88, 60), (72, 47), (54, 45), (40, 33), (24, 35), (13, 23)],
    'Path_BridgeToHub': [(-5, 20), (-14, 13), (-20, 3)],
    'Path_HubToGrotto': [(-28, -22), (-24, -40), (-14, -58), (-7, -76)],
    'Path_HubToBlossomPoint': [(-44, -2), (-62, -4), (-80, -10), (-95, -11)],
    'Path_HubToKnoll': [(-38, 10), (-36, 20), (-40, 27), (-48, 36), (-56, 45), (-60, 50)],
    'Path_ToFalls': [(54, 45), (62, 28), (65, 6), (61, -14), (64, -32), (68, -44)],
    'Path_ToCove': [(-14, 13), (-16, 30), (-18, 44), (-16, 56)],
    'Path_ToNook': [(-18, -14), (-8, -24), (0, -31)],
}
LAMPS = [(70, 50), (30, 33), (-9, 23), (-12, -44), (-70, -3), (50, -10), (-22, 38)]
BRIDGE = (4, 21)


def height(X, Z):
    r, th = polar(X, Z)
    Rr = RIM(th); d = r - Rr
    h = .12 + .8 * fbm(X / 38, Z / 38, 3, 2)                       # pets: rises stay under 1 stud
    m = 0.0
    for px, pz, r0, r1 in PADS:
        dd = math.hypot(X - px, Z - pz)
        m = max(m, 1 - S((dd - r0) / (r1 - r0)))
    h *= (1 - m)
    h *= 1 - S((d + 6) / 6)                                        # settle to the rim line
    # --- water (stream winds from the falls pool to the cove; two pools on the way)
    for (px, pz, rx, rz), depth in ((FALLS_POOL, 3.0), (LILY, 2.4)):
        e = math.hypot((X - px) / rx, (Z - pz) / rz) + .14 * (fbm(X / 10, Z / 10, 31) - .5)
        if e < 1.3: h = h * S((e - .8) / .5) - depth * (1 - S((e - .45) / .55))
    h += 3.3 * gauss(X - LILY[0] - 1, Z - LILY[1] + 1, 3.4)        # lily islet
    ds = pdist(X, Z, STREAM)
    if ds < 9 and d < 26: h = h * S((ds - 4) / 5) - 2.3 * (1 - S((ds - 1.6) / 3.4))
    # --- outside the rim: rock wall, or open bank / beach down to the sea
    if d > 0:
        E = wall_env(th); H = wall_H(th)
        face = S(d / (5 + H * .2))
        back = S((d - 24) / (16 + H * .9))
        wh = H * face * (1 + .14 * (fbm(X / 16, Z / 16, 7) - .5) * 2) * (1 - back)
        lat = math.radians(angd(th, GROTTO_TH)) * Rr                # grotto corridor through the wall
        wh *= 1 - S((8.5 - abs(lat)) / 3) * S((19 - d) / 3)
        wopen = 9 + 26 * g(th, 97, 26) + 8 * g(th, 32, 14)          # wide sandy beach in the cove
        h += wh - 9 * back * E + (1 - E) * (-9) * S(d / wopen)
    # --- player-only high ground
    kx, kz, kr, kh = KNOLL
    dk = math.hypot(X - kx, Z - kz)
    if dk < 44:
        phi = math.degrees(math.atan2(Z - kz, X - kx))
        w = 5 + 27 * math.exp(-(angd(phi, -52) / 24) ** 2)          # the ramp falls toward the hub
        h += kh * S(1 - (dk - kr) / w)
    dsp = pdist(X, Z, SPUR)
    if dsp < 10: h += (8 + 6 * S((-48 - Z) / 40)) * S((9.5 - dsp) / 6)
    return max(h, -9.5)


def in_garden(X, Z, margin=0.0):
    r, th = polar(X, Z)
    return r < RIM(th) - margin


def pet_ok(X, Z):
    """Flat or gently rolling dry lawn inside the rim (what pets may walk)."""
    if not in_garden(X, Z, 2.5): return False
    h = height(X, Z)
    return -.05 < h < 1.2


# ------------------------------------------------------------------ scene
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene; scene.name = 'World1_Mockup_v2'; scene.unit_settings.system = 'NONE'
COL = {}
for nm in ['Ground', 'Walls_Rocks', 'Water', 'Landmarks', 'Stations', 'Props', 'Distant', 'Sky_Lighting', 'REF']:
    c = bpy.data.collections.new(nm); scene.collection.children.link(c); COL[nm] = c
MAT = {}
for n_, r_ in [('grass', .9), ('meadow', .9), ('dirt_path', .9), ('cliff_rock', .85), ('boulder_rock', .8), ('sand_pebble', .9),
               ('wood_plank', .7), ('bark', .85), ('foliage', .8), ('foliage_blossom', .8), ('stone_tile', .6)]:
    mat_tex(n_, n_, r_)
mat_tex('ground', 'ground_soft', .92)
mat_tex('water', 'water', rough=.1, alpha=.86, spec=.6, emit=.18)
mat_tex('waterfall', 'waterfall', rough=.3, emit=.35)
mat_unlit('sea', 'water', .35); mat_unlit('far_peak', 'far_peak'); mat_unlit('cloud'); mat_unlit('foam')
for nm, hx, kw in [('ph_white', '#FFFFFF', dict(rough=.3, coat=.3)), ('ph_aqua', '#35C7F5', dict(rough=.25, coat=.4)), ('ph_pink', '#FF6FAE', {}),
                   ('ph_yellow', '#FFD84A', {}), ('ph_mint', '#5FE89A', {}), ('ph_lilac', '#A88BFF', {}), ('canvas', '#FFF1CC', dict(rough=.8)),
                   ('stem', '#2FA83F', dict(rough=.8)), ('avatar_skin', '#F2D3B1', {}), ('avatar_shirt', '#F4573B', {}), ('avatar_pants', '#3B4C8C', {}),
                   ('cave_dark', '#101A33', dict(rough=1.0, spec=0.0))]:
    mat_flat(nm, lin(hx), **({'rough': .45} | kw))
mat_flat('glow_warm', lin('#FFD98A'), emit=1.4); mat_flat('glow_aqua', lin('#4FE6FF'), emit=1.3, rough=.2); mat_flat('glow_pink', lin('#FF7FD0'), emit=1.2, rough=.2)
mat_flat('bubble', lin('#D8F6FF'), rough=.05, alpha=.42, spec=1.0, emit=.25)
mat_flat('egg', lin('#FFF9F0'), rough=.3, coat=.5, vcol=True)
leaf_col = shade_top(.74, 1.10, .02)
C_GRASS_A = Vector(lin('#35BA3E')); C_GRASS_B = Vector(lin('#58D74F')); C_GRASS_HI = Vector(lin('#2FA83F'))
C_SAND = Vector(lin('#F7E6B2')); C_STONE = Vector(lin('#CDBFA4')); C_STONE_D = Vector(lin('#A99A80'))

# ================================================================== GROUND (regular 3-stud grid, vertex-coloured)
STEP = 3.0
X0, X1, Z0, Z1 = -186, 192, -177, 150
NXg = int((X1 - X0) / STEP); NZg = int((Z1 - Z0) / STEP)
Hg = [[height(X0 + i * STEP, Z0 + j * STEP) for i in range(NXg + 1)] for j in range(NZg + 1)]


def gcol(i, j):
    X = X0 + i * STEP; Z = Z0 + j * STEP; h = Hg[j][i]
    hx = Hg[j][min(i + 1, NXg)] - Hg[j][max(i - 1, 0)]; hz = Hg[min(j + 1, NZg)][i] - Hg[max(j - 1, 0)][i]
    nz = 1 / math.sqrt(1 + (hx / (2 * STEP)) ** 2 + (hz / (2 * STEP)) ** 2)
    r, th = polar(X, Z); d = r - RIM(th)
    n = fbm(X / 34, Z / 34, 77, 2)
    c = C_GRASS_A.lerp(C_GRASS_B, S((n - .3) / .4))
    if d > 8 and h > 3: c = c.lerp(C_GRASS_HI, .55)                 # wall tops: deeper green
    c = c.lerp(C_SAND, S((.15 - h) / .7))                           # shores, stream bed, beach
    rock = S((.90 - nz) / .12)
    c = c.lerp(C_STONE.lerp(C_STONE_D, S((.62 - nz) / .3) * .6), rock)
    if h < SEA: c = c.lerp(Vector(lin('#7FD8F2')), S((SEA - h) / 3) * .6)
    k = 1.0
    if 0 < d < 10 and wall_env(th) > .5 and h < 4: k = .86 + .14 * (d / 10)   # contact shade at wall foot
    return (c.x * k, c.y * k, c.z * k)


vid = {}; GV = []; GC = []; GF = []
def gv(i, j):
    if (i, j) not in vid:
        vid[(i, j)] = len(GV); GV.append(B(X0 + i * STEP, Hg[j][i], Z0 + j * STEP)); GC.append(gcol(i, j))
    return vid[(i, j)]
for j in range(NZg):
    for i in range(NXg):
        if max(Hg[j][i], Hg[j][i + 1], Hg[j + 1][i], Hg[j + 1][i + 1]) < SEA - 1.2: continue
        a, b, c, d = gv(i, j), gv(i + 1, j), gv(i + 1, j + 1), gv(i, j + 1)
        if (i + j) % 2: GF += [(a, d, c), (a, c, b)]
        else: GF += [(a, d, b), (b, d, c)]
me = bpy.data.meshes.new('Ground_Terrain'); me.from_pydata(GV, [], GF)
uvs = []; cols = []
for f in GF:
    p0, p1, p2 = (Vector(GV[t]) for t in f)
    steep = abs((p1 - p0).cross(p2 - p0).normalized().z) < .72
    for t in f:
        x, y, z = GV[t]
        uvs += ([(x * .7 - y * .7) / 24, z / 24] if steep else [x / 24, y / 24]); cols += [*GC[t], 1]
me.uv_layers.new(name='UVMap').data.foreach_set('uv', uvs)
me.color_attributes.new('Col', 'FLOAT_COLOR', 'CORNER').data.foreach_set('color', cols)
me.materials.append(MAT['ground']); me.polygons.foreach_set('use_smooth', [True] * len(GF)); me.update()
obj('Ground_Terrain', me, 'Ground')

for nm, pts in PATHS.items():
    ribbon(nm, pts, 5.6 if nm in ('Path_SpawnToHub', 'Path_BridgeToHub') else 4.0, lift=.14)
disc('Ground_HubPlaza', HUB[0], HUB[1], 14.5, 'dirt_path', 'Ground', lift=.13, segs=30, wob=.10, seed=3)
disc('Ground_ToyLawn', STATIONS['ToyLawn'][0], STATIONS['ToyLawn'][1], 7.5, 'meadow', 'Ground', lift=.10, segs=20, wob=.12, seed=5)
disc('Ground_SpringMeadow', 52, 11, 10.5, 'meadow', 'Ground', lift=.10, segs=22, wob=.12, seed=6)

# ================================================================== WALLS: big faceted crags
def crag_mesh(name, seed, chisel=13, grass=True):
    v, f = blob(2, seed, rough=.10, chisel=chisel)
    r = random.Random(seed); mb = MB()
    for face in f:
        p0, p1, p2 = (Vector(v[i]) for i in face)
        n = (p1 - p0).cross(p2 - p0).normalized()
        up = grass and n.z > .80
        j = 1 + .05 * (r.random() - .5) * 2
        if up: mb.add(v, [face], 1, col=(.95 * j, 1.0 * j, .95 * j), scale=.12)
        else:
            k = (.66 + .44 * (n.z * .5 + .5) + .10 * max(0, n.dot(SUN))) * j
            mb.add(v, [face], 0, col=(k * 1.02, k, k * .97), scale=.07)
    me = mb.build(name, ['cliff_rock', 'grass'])
    bm = bmesh.new(); bm.from_mesh(me); bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5); bm.to_mesh(me); bm.free()
    return me


CRAG = [crag_mesh('Crag_%d' % k, 800 + k) for k in range(6)]
CRAG_BARE = [crag_mesh('CragBare_%d' % k, 830 + k, chisel=11, grass=False) for k in range(3)]
ROCK = {}
rock_col = shade_top(.74, 1.08, .015)
for k in range(4):
    v, f = blob(2, 300 + k, rough=.16, chisel=8, squash=(1, 1, .85)); ROCK['big%d' % k] = MB().add(v, f, 0, colfn=rock_col, scale=.1).build('Rock_Big_%d' % k, ['boulder_rock'])
    v, f = blob(1, 340 + k, rough=.2, chisel=5, squash=(1, 1, .8)); ROCK['small%d' % k] = MB().add(v, f, 0, colfn=rock_col, scale=.14).build('Rock_Small_%d' % k, ['boulder_rock'])
for k in range(2): ROCK['mossy%d' % k] = CRAG[k]
ROCKN = [0]; CRAGN = [0]
for sc in ('Wall_Crags', 'Rocks_Shore', 'Rocks_Field'): subcol('Walls_Rocks', sc)


def crag(X, Z, w, top, base=None, coll='Wall_Crags', bare=False, dz=None):
    """A wall-scale faceted form: footprint ~w studs, top at height `top`."""
    base = min(height(X, Z), 0) - 2 if base is None else base
    hz = (top - base) / 2 / .93
    me = rnd.choice(CRAG_BARE if bare else CRAG); CRAGN[0] += 1
    return obj('Crag_%03d' % CRAGN[0], me, coll, X, base + hz * .93, Z, rot=rnd.uniform(0, 6.28),
               scale=(w / 2 * rnd.uniform(.9, 1.15), (dz or w) / 2 * rnd.uniform(.9, 1.15), hz), tilt=(rnd.uniform(-.08, .08), rnd.uniform(-.08, .08)))


th = 196.0
while th < 384:
    t = th % 360; H = wall_H(t); Rr = RIM(t)
    lat = abs(math.radians(angd(t, GROTTO_TH)) * Rr); fall = abs(math.radians(angd(t, FALLS_TH)) * Rr)
    if H > 3 and lat > 12 and fall > 9:
        w = rnd.uniform(15, 24) + H * .22
        X, Z = P(t, Rr + rnd.uniform(4.5, 8) + w * .12)
        crag(X, Z, w, H * rnd.uniform(.72, 1.02) + 1)                 # front row: the wall you see
        if rnd.random() < .7:
            X, Z = P(t + rnd.uniform(-2, 2), Rr + rnd.uniform(17, 24) + w * .2)
            crag(X, Z, w * 1.25, H * rnd.uniform(1.12, 1.45) + 4)     # back row: taller, overlapping
        if rnd.random() < .45 and H > 12:
            X, Z = P(t + rnd.uniform(-3, 3), Rr + rnd.uniform(.5, 2.5))
            crag(X, Z, rnd.uniform(7, 12), H * rnd.uniform(.22, .45), bare=rnd.random() < .5)   # low step at the foot
    th += math.degrees(rnd.uniform(9, 13) / Rr)
# wall ends step down into the sea as loose stacks
for t, n in ((196, 3), (384 % 360, 3)):
    for k in range(n):
        X, Z = P(t + (-1 if t > 100 else 1) * (4 + k * 5), RIM(t) + 6 + k * 3)
        crag(X, Z, 12 - k * 2.5, 7 - k * 2, base=SEA - 3)
# the spur: a low ridge of forms reaching into the garden
sp = resample(SPUR, 9)
for k, (X, Z) in enumerate(sp):
    crag(X + rnd.uniform(-2, 2), Z, rnd.uniform(13, 17), height(X, Z) + rnd.uniform(1.5, 4), base=-2)
# knoll skirt (not on the ramp side)
kx, kz, kr, kh = KNOLL
for a in range(0, 360, 34):
    if abs(angd(a, -52)) < 62: continue
    X = kx + math.cos(math.radians(a)) * (kr + 3.5); Z = kz + math.sin(math.radians(a)) * (kr + 3.5)
    crag(X, Z, rnd.uniform(9, 13), kh * rnd.uniform(.55, .9), base=min(height(X, Z), SEA) - 2, bare=rnd.random() < .4)

# shore stones: open rim, stream banks, pools
th = 20.0
while th < 198:
    Rr = RIM(th)
    if g(th, 97, 20) < .35 and abs(angd(th, 36)) > 9:
        X, Z = P(th, Rr + rnd.uniform(.5, 3))
        rock('Rocks_Shore', X, Z, rnd.uniform(2.2, 5.2), sink=.3)
    th += math.degrees(rnd.uniform(7, 13) / Rr)
rp = resample(STREAM, 8)
for k, (X, Z) in enumerate(rp):
    if not in_garden(X, Z, 4) or math.hypot(X - BRIDGE[0], Z - BRIDGE[1]) < 8: continue
    nx, nz = outward(rp, k); sgn = 1 if k % 2 else -1
    rock('Rocks_Shore', X + nx * 5.6 * sgn, Z + nz * 5.6 * sgn, rnd.uniform(1.4, 3.0), kind='small%d' % rnd.randrange(4), sink=.3)
for (px, pz, rx, rz), n in ((FALLS_POOL, 9), (LILY, 7)):
    for k in range(n):
        a = k / n * 6.283 + rnd.uniform(-.2, .2)
        X, Z = px + math.cos(a) * rx * 1.08, pz + math.sin(a) * rz * 1.08
        if pdist(X, Z, STREAM) < 6 or any(pdist(X, Z, p) < 4 for p in PATHS.values()): continue
        rock('Rocks_Shore', X, Z, rnd.uniform(1.8, 4.2), sink=.3)
for X, Z, sz in [(-66, -30, 4.5), (-63, -27, 2.2), (70, 8, 4), (24, 52, 3.6), (-30, 44, 3), (72, -20, 5), (-78, 26, 3.4)]:
    rock('Rocks_Field', X, Z, sz)

# ================================================================== WATER
def water_sheet_v2():
    step = 3.0; V = []; U = []; F = []; vidw = {}
    def vi(i, j):
        if (i, j) not in vidw:
            vidw[(i, j)] = len(V); V.append(B(i * step, WATER, j * step)); U.append((i * step / 14, -j * step / 14))
        return vidw[(i, j)]
    for i in range(-40, 40):
        for j in range(-40, 40):
            X, Z = i * step, j * step
            r, th_ = polar(X + 1.5, Z + 1.5)
            if r > RIM(th_) + 2.5: continue
            if min(height(X + a, Z + b) for a in (0, step) for b in (0, step)) < WATER + .2:
                F.append([vi(i, j), vi(i, j + 1), vi(i + 1, j + 1), vi(i + 1, j)])
    mb = MB(); mb.v = V
    for f in F:
        mb.f.append(f); mb.mi.append(0)
        for k in f: mb.uv.append(U[k]); mb.col.append((1, 1, 1, 1))
    obj('Water_StreamAndPools', mb.build('Water_StreamAndPools', ['water']), 'Water')


water_sheet_v2()
mb = MB(); V = [B(0, SEA, 0)]; U = [(0, 0)]; C = [lin('#3FCBF5')]; F = []
rings = [(185, '#3FCBF5'), (270, '#27A9F2'), (420, '#2A98EC'), (900, '#56B4F4'), (1800, '#9FD6FB'), (4200, '#D9F0FF')]
for r_, c_ in rings:
    for i in range(40):
        a = 2 * math.pi * i / 40
        V.append(B(math.cos(a) * r_, SEA, math.sin(a) * r_)); U.append((math.cos(a) * r_ / 40, -math.sin(a) * r_ / 40)); C.append(lin(c_))
for i in range(40):
    j = (i + 1) % 40; F.append([0, 1 + j, 1 + i])
    for k in range(len(rings) - 1):
        a = 1 + k * 40; F.append([a + i, a + j, a + 40 + j, a + 40 + i])
mb.v = V
for f in F:
    mb.f.append(f); mb.mi.append(0)
    for k in f: mb.uv.append(U[k]); mb.col.append((*C[k], 1))
obj('Water_Sea', mb.build('Water_Sea', ['sea']), 'Water')


def ribbon3(name, pts, widths, across, mat='waterfall', coll='Water'):
    """Falls ribbon: pts [(X, h, Z)] top->bottom, `across` = unit (x, z) direction of its width."""
    V = []; U = []; F = []; acc = 0
    for i, (X, h, Z) in enumerate(pts):
        if i: acc += math.dist(pts[i], pts[i - 1])
        for k in (-1, -.33, .33, 1):
            V.append(B(X + across[0] * k * widths[i] / 2, h, Z + across[1] * k * widths[i] / 2)); U.append((k * widths[i] / 12, -acc / 14))
    for i in range(len(pts) - 1):
        for k in range(3):
            a = i * 4 + k; F.append([a, a + 4, a + 5, a + 1]); F.append([a, a + 1, a + 5, a + 4])
    return obj(name, MB().add(V, F, 0, uvs=U).build(name, [mat]), coll)


# ================================================================== LANDMARKS
# ---- Tumble Falls (north-east massif) -> falls pool
fx, fz = math.cos(math.radians(FALLS_TH)), math.sin(math.radians(FALLS_TH))
Rf = RIM(FALLS_TH); Hf = wall_H(FALLS_TH); acr = (-fz, fx)
def fp(d, h): return (fx * (Rf + d), h, fz * (Rf + d))
ribbon3('Water_TumbleFalls_Upper', [fp(16, Hf + 3.5), fp(11.5, Hf + 3.0), fp(10.2, Hf - 3), fp(9.6, Hf * .62), fp(9.3, 15.5)], [8, 8.5, 9, 9.5, 10], acr)
ribbon3('Water_TumbleFalls_Lower', [fp(9.6, 16.2), fp(4.6, 15.8), fp(3.2, 12), fp(2.4, 5), fp(1.8, WATER)], [11, 11.5, 12, 13, 14], acr)
for nm, d, w, top, base, dzz in [('Landmark_TumbleShelf', 8.5, 20, 15.7, 2, 13), ('Landmark_FallsCrown', 15, 26, Hf + 2.6, 10, 16)]:
    o = crag(fx * (Rf + d), fz * (Rf + d), w, top, base=base, coll='Landmarks', bare=True, dz=dzz); o.name = nm; o.rotation_euler = (0, 0, math.atan2(-acr[1], acr[0]))
for side in (-1, 1):
    for lvl, (d, w, top) in enumerate([(5, 15, 13), (9, 17, 26), (13, 19, Hf * .95), (20, 24, Hf * 1.3)]):
        crag(fx * (Rf + d) + acr[0] * side * (12.5 + lvl * 1.5), fz * (Rf + d) + acr[1] * side * (12.5 + lvl * 1.5), w, top, coll='Landmarks')
mb = MB()
for k in range(9):
    v, f = blob(1, 90 + k, rough=.2, squash=(1.7, 1.3, .9), center=(rnd.uniform(-6.5, 6.5), rnd.uniform(-1.5, 1.5), .2)); mb.add(v, f, 0, col=(1, 1, 1))
o = obj('Water_TumbleFalls_Foam', mb.build('FallsFoam', ['foam']), 'Water', fx * (Rf - .5), WATER + .1, fz * (Rf - .5)); o.rotation_euler = (0, 0, math.atan2(-acr[1], acr[0]))

# ---- cove cascade: the stream steps down the beach into the sea
ce = min(resample(STREAM, 1), key=lambda p: abs(math.hypot(*p) - RIM(polar(*p)[1]) - 1))
ribbon3('Water_CoveCascade', [(ce[0], WATER, ce[1] - 2), (ce[0], WATER - .3, ce[1] + 1.5), (ce[0] - .3, -2.6, ce[1] + 5), (ce[0] - .5, SEA + .05, ce[1] + 9)], [6.5, 6.5, 7.5, 10], (1, 0))

# ---- Hatch Tree + lantern (moved with the hub)
hatch_tree()
for nm in ('Landmark_HatchTree', 'Landmark_HatchTree_Lantern'):
    o = bpy.data.objects[nm]; o.location.x += HATCH_TREE[0] + 3.4; o.location.y += -(HATCH_TREE[1] + 10.9)


# ---- Chime Arch (spawn gate on the arrival peninsula, square to the path)
def chime_arch_v2(X, Z, yaw):
    mb = MB(); pts = []; rad = []
    for k in range(17):
        a = math.pi * k / 16
        pts.append((-math.cos(a) * 9.2, .3 * math.sin(a * 2), math.sin(a) * 13.5 - 1.2 * (1 - math.sin(a))))
        rad.append(2.3 - .95 * math.sin(a) + .3 * vnoise(k * .9, 0, 8))
    v, f, uv = tube(pts, rad, sides=6, seed=11, wob=.16)
    mb.add(v, f, 0, uvs=[(a * .6, b * .35) for a, b in uv], colfn=shade_top(.74, 1.08, .015))
    for k, (dx, L, m) in enumerate([(-5.0, 2.0, 1), (-2.5, 2.9, 2), (0, 3.6, 3), (2.5, 2.6, 4), (5.0, 1.8, 5)]):
        top = 13.5 * math.sin(math.acos(max(-1, min(1, -dx / 9.2)))) - 2.0
        v, f = box(.06, .06, 1.6, (dx, 0, top - .6)); mb.add(v, f, 6)
        v, f, uv = lathe([(.26, top - 1.4 - L), (.26, top - 1.4)], 6, True, True); mb.add(v, f, m, uvs=uv, M=Matrix.Translation((dx, 0, 0)))
    me = mb.build('Landmark_ChimeArch', ['cliff_rock', 'ph_pink', 'ph_yellow', 'ph_lilac', 'ph_aqua', 'ph_mint', 'bark'])
    obj('Landmark_ChimeArch', me, 'Landmarks', X, height(X, Z), Z, rot=yaw)


ARCH = (85, 57.5)
pd = Vector((ARCH[0] - STATIONS['Spawn'][0], -(ARCH[1] - STATIONS['Spawn'][1]), 0)).normalized()
chime_arch_v2(ARCH[0], ARCH[1], math.atan2(pd.y, pd.x) + math.pi / 2)
for s in (-1, 1):
    rock('Landmarks', ARCH[0] + pd.y * s * 11, ARCH[1] + pd.x * s * 11, 4.2, kind='big%d' % (s + 1))

# ---- Glow Grotto: a real notch through the wall, roofed by two big forms
gx, gz = math.cos(math.radians(GROTTO_TH)), math.sin(math.radians(GROTTO_TH)); Rg = RIM(GROTTO_TH); gacr = (-gz, gx)
def gp(d, lat=0): return (gx * (Rg + d) + gacr[0] * lat, gz * (Rg + d) + gacr[1] * lat)
mb = MB(); V = []; F = []
for j, d in enumerate((1.5, 8, 15, 20)):
    for i in range(9):
        a = math.pi * i / 8; rr = (9.5, 9, 8, 5)[j]
        x, z = gp(d, -math.cos(a) * rr); V.append(B(x, math.sin(a) * rr * 1.25 - .5, z))
for j in range(3):
    for i in range(8):
        a = j * 9 + i; F.append([a, a + 1, a + 10, a + 9]); F.append([a, a + 9, a + 10, a + 1])
mb.add(V, F, 0)
obj('Landmark_GlowGrotto_Liner', mb.build('GrottoLiner', ['cave_dark']), 'Landmarks')
for lat, d, w, top, base in [(-13.5, 6, 15, 17, None), (13.5, 6, 15, 18, None), (0, 9, 30, 25, 11.5), (-6, 15, 22, 30, 12), (8, 17, 22, 28, 12)]:
    x, z = gp(d, lat); o = crag(x, z, w, top, base=base, coll='Landmarks', bare=base is not None, dz=16 if base else None)
    if base is not None: o.rotation_euler = (0, 0, math.atan2(-gacr[1], gacr[0]))
mb = MB(); r9 = random.Random(9)
for (lat, d, hh, m) in [(-6.5, 1, 3.4, 0), (-8, -3, 2.2, 1), (6.8, 2, 3.8, 0), (8, -2, 2.4, 1), (-4, 9, 4.6, 0), (4.5, 11, 5.0, 1), (0, 15, 6.0, 0), (-9.5, -6, 1.6, 1)]:
    v, f, uv = lathe([(hh * .2, -.4), (hh * .24, hh * .62), (0.02, hh)], 6)
    x, z = gp(d, lat)
    mb.add(v, f, m, uvs=uv, M=Matrix.Translation(B(x, 0, z)) @ Euler((r9.uniform(-.3, .3), r9.uniform(-.3, .3), r9.uniform(0, 3))).to_matrix().to_4x4())
obj('Landmark_GlowGrotto_Crystals', mb.build('GrottoCrystals', ['glow_aqua', 'glow_pink'], smooth=False), 'Landmarks')
li = bpy.data.lights.new('GrottoGlow', 'POINT'); li.energy = 1200; li.color = (.4, .95, 1.0); li.shadow_soft_size = 3
lo = bpy.data.objects.new('GrottoGlow', li); x, z = gp(11); lo.location = B(x, 5, z); COL['Landmarks'].objects.link(lo)

# ---- Pinwheel on the knoll (players climb the grassy ramp)
pinwheel(kx - 2, kz + 2)
r_ = bpy.data.objects['Landmark_Pinwheel_Rotor']; hubdir = Vector((HUB[0] - kx, -(HUB[1] - kz), 0)).normalized()
r_.rotation_euler = (0, .35, math.atan2(hubdir.y, hubdir.x) + math.pi / 2)
r_.location = Vector(B(kx - 2, height(kx - 2, kz + 2) + 25.2, kz + 2)) + hubdir * 1.5

# ---- Wobble Egg perched on the tip of the spur
prof = [(0.02, 0), (1.5, .5), (2.6, 1.7), (2.95, 3.1), (2.6, 4.7), (1.7, 6.0), (.7, 6.8), (.02, 7.0)]
v, f, uv = lathe(prof, 12)
def eggcol(p, n):
    k = .84 + .2 * (n[2] * .5 + .5)
    base = (1.0, .96, .9) if fbm(p[0] * 1.3 + 4, p[1] * 1.3 + p[2] * 1.7, 12, 2) < .56 else (.35, .75, 1.0)
    return (base[0] * k, base[1] * k, base[2] * k)
ex, ez = SPUR[-1][0], SPUR[-1][1] - 3
crag(ex, ez, 13, height(ex, ez) + 2.2, base=-2, coll='Landmarks', bare=True).name = 'Landmark_WobbleEgg_Perch'
obj('Landmark_WobbleEgg', MB().add(v, f, 0, uvs=uv, colfn=eggcol).build('WobbleEgg', ['egg']), 'Landmarks', ex, height(ex, ez) + 1.9, ez, scale=.8, tilt=(.13, -.1))

bubble_spring()

# ================================================================== VEGETATION + PROPS
TREE = {
    'round': tree_mesh('Tree_Round', 1, 5.5, .55, [(0, 0, 8.2, 3.6, .8), (2.1, .6, 6.9, 2.4, .8), (-1.9, -.8, 7.0, 2.5, .78), (.3, 1.6, 9.6, 2.2, .8)]),
    'tall': tree_mesh('Tree_Tall', 2, 8, .5, [(0, 0, 9.0, 2.9, .9), (.4, .3, 11.6, 2.3, .95), (-.2, -.3, 13.8, 1.6, 1.0)]),
    'blossom': tree_mesh('Tree_Blossom', 3, 5, .5, [(0, 0, 7.4, 3.4, .75), (2.3, -.5, 6.4, 2.3, .75), (-2.0, .9, 6.6, 2.4, .75)], foliage='foliage_blossom'),
}
v, f = blob(1, 77, rough=.25, squash=(1.5, 1.3, .85), flat_bottom=-.3); BUSH = MB().add(v, f, 0, colfn=leaf_col, scale=.2).build('Bush', ['foliage'])
v, f = blob(1, 78, rough=.25, squash=(1.3, 1.4, .8), flat_bottom=-.3); BUSH_B = MB().add(v, f, 0, colfn=leaf_col, scale=.2).build('Bush_Blossom', ['foliage_blossom'])
FLOWER = [flower_mesh('Flowers_A', ['stem', 'ph_white', 'ph_yellow', 'ph_pink']), flower_mesh('Flowers_B', ['stem', 'ph_lilac', 'ph_white', 'ph_yellow'])]
for sc in ('Trees', 'Bushes', 'Flowers', 'Lamps', 'Bridges'): subcol('Props', sc)
ALLPATH = [resample(chaikin(p, 2), 3) for p in PATHS.values()]


def clear_spot(X, Z, r=4.0):
    if not pet_ok(X, Z) or not in_garden(X, Z, 6): return False
    if any(pdist(X, Z, p) < r for p in ALLPATH): return False
    if any(math.hypot(X - sx, Z - sz) < r + 5 for sx, sz in STATIONS.values()): return False
    return math.hypot(X - HUB[0], Z - HUB[1]) > 21 and pdist(X, Z, STREAM) > 8


TREES = [(-62, -24, 1.15, 'round'), (-50, -42, 1.2, 'tall'), (-36, -52, 1.0, 'blossom'), (-70, -44, 1.1, 'round'), (-8, -48, 1.0, 'blossom'),
         (-76, 16, 1.0, 'tall'), (-66, 28, .95, 'blossom'), (-34, 38, 1.1, 'round'), (-28, 56, 1.0, 'tall'), (18, 44, 1.0, 'blossom'),
         (30, 60, 1.15, 'round'), (52, 56, .95, 'tall'), (66, 26, 1.1, 'round'), (74, 12, .9, 'blossom'), (38, 8, 1.0, 'round'),
         (72, -22, 1.15, 'tall'), (38, -62, 1.0, 'blossom'), (76, -40, 1.0, 'round'), (-12, 34, .9, 'blossom'), (100, 44, .95, 'round'),
         (-84, -30, 1.0, 'blossom'), (36, -16, .9, 'tall')]
for n, (X, Z, sc, kind) in enumerate(TREES):
    if height(X, Z) < 0: continue
    obj('Tree_%02d_%s' % (n + 1, kind), TREE[kind], 'Trees', X, height(X, Z), Z, rot=rnd.uniform(0, 6.28), scale=sc * rnd.uniform(.95, 1.1))
obj('Landmark_BlossomPointTree', TREE['blossom'], 'Landmarks', -100, height(-100, -15), -15, rot=.6, scale=1.7)
obj('Landmark_LilyIsletTree', TREE['blossom'], 'Landmarks', LILY[0] + 1, height(LILY[0] + 1, LILY[1] - 1) - .1, LILY[1] - 1, rot=2.1, scale=.7)
for nm, mesh_pick, count, r_clear, smin, smax, lift in (('Bush', lambda: BUSH_B if rnd.random() < .3 else BUSH, 26, 3.5, .9, 1.8, .2), ('Flowers', lambda: FLOWER[rnd.randrange(2)], 46, 2.6, .9, 1.5, 0)):
    placed = tries = 0
    while placed < count and tries < 6000:
        tries += 1
        X, Z = rnd.uniform(-110, 125), rnd.uniform(-100, 85)
        if not clear_spot(X, Z, r_clear): continue
        placed += 1
        obj('%s_%02d' % (nm, placed), mesh_pick(), 'Bushes' if nm == 'Bush' else 'Flowers', X, height(X, Z) + lift, Z, rot=rnd.uniform(0, 6.28), scale=rnd.uniform(smin, smax))

sx, sz = STATIONS['EggSpot']; station('Station_EggSpot_NestStone_PLACEHOLDER', sx, sz, b_nest, ['stone_tile', 'foliage', 'egg'], smooth=True, lift=.1)
sx, sz = STATIONS['CareMachine']; pad('Pad_CareMachine', sx, sz, 4.6); station('Station_CareMachine_PLACEHOLDER', sx, sz, b_care, ['ph_aqua', 'ph_white', 'ph_lilac', 'ph_pink', 'ph_yellow', 'glow_warm'], smooth=True, rot=-.5)
sx, sz = STATIONS['Workbench']; pad('Pad_Workbench', sx, sz, 4.6); station('Station_Workbench_PLACEHOLDER', sx, sz, lambda mb: b_table(mb, awning=True, back=True), ['wood_plank', 'bark', 'canvas'], rot=.45)
for nm, rt in (('BenchWest', math.pi - .7), ('BenchEast', math.pi + .7)):
    sx, sz = STATIONS[nm]; station('Station_%s_PLACEHOLDER' % nm, sx, sz, b_bench, ['wood_plank', 'bark'], rot=rt, lift=.05)
for nm in ('PicnicWest', 'PicnicEast'):
    sx, sz = STATIONS[nm]; pad('Pad_' + nm, sx, sz, 5.2); station('Station_%s_Table_PLACEHOLDER' % nm, sx, sz, b_picnic, ['wood_plank', 'bark'], rot=.4)
sx, sz = STATIONS['ToyLawn']; station('Station_ToyLawn_Toys_PLACEHOLDER', sx, sz + 1.5, b_toys, ['ph_white', 'ph_pink', 'ph_yellow', 'ph_mint', 'ph_lilac'], smooth=True, lift=.1)
sx, sz = STATIONS['CreekNook']; pad('Pad_CreekNook', sx, sz, 3.4); station('Station_CreekNook_RestCushion_PLACEHOLDER', sx, sz, lambda mb: b_cushion(mb), ['ph_pink'], smooth=True)
for nm, m in (('SpringRestWest', 'ph_lilac'), ('SpringRestEast', 'ph_mint')):
    sx, sz = STATIONS[nm]; station('Station_%s_Cushion_PLACEHOLDER' % nm, sx, sz, lambda mb: b_cushion(mb), [m], smooth=True, lift=.12)
sx, sz = STATIONS['Spawn']; station('Station_SpawnPad_PLACEHOLDER', sx, sz, b_spawn, ['stone_tile', 'ph_aqua'], smooth=True, lift=.05)
for nm, (sx, sz) in {'Pad_Future_A': (-48, -22), 'Pad_Future_B': (-13, -4)}.items(): pad(nm, sx, sz, 3.6)
bridge('Bridge_Main', BRIDGE[0], BRIDGE[1], 19, 6)
st_ = [p for p in resample(STREAM, 5) if 26 < p[0] < 40][:3]
for k, (X, Z) in enumerate(st_):                                  # stepping stones to the falls side (players)
    mb = MB(); v, f, uv = lathe([(2.2, -2.4), (2.4, .1), (2.0, .3)], 8, cap_top=True); mb.add(v, f, 0, uvs=uv)
    obj('Prop_SteppingStone_%d' % (k + 1), mb.build('SteppingStone', ['stone_tile']), 'Props', X, WATER + .25, Z, rot=k)
LAMP = lamp_mesh()
for k, (X, Z) in enumerate(LAMPS): obj('Lamp_%d' % (k + 1), LAMP, 'Lamps', X, height(X, Z), Z)

# ================================================================== DISTANT
HAZE = Vector(lin('#CFE9FF'))


def mountain_v2(name, X, Z, R, H, seed, snow=.56, base='#4F86D9', foot='#3FAE5A'):
    r = random.Random(seed); sides = 9; fr = [0, .22, .45, .66, .84, 1.0]
    haze = min(.70, .22 + math.hypot(X, Z) / 3000); V = []; ridge = r.uniform(0, 6.28)
    for j, t in enumerate(fr):
        rad = R * (1 - t) ** .85 + (R * .015 if j == len(fr) - 1 else 0)
        for i in range(sides):
            a = 2 * math.pi * i / sides + j * .25
            k = 1 + .34 * (r.random() - .5) + .22 * math.cos(2 * (a - ridge))
            V.append((math.cos(a) * rad * k, math.sin(a) * rad * k, SEA + H * t * (1 + .10 * (r.random() - .5)) - (30 if j == 0 else 0)))
    F = [[j * sides + i, j * sides + (i + 1) % sides, (j + 1) * sides + (i + 1) % sides, (j + 1) * sides + i] for j in range(len(fr) - 1) for i in range(sides)]
    bc = Vector(lin(base)); sn = Vector(lin('#FFFFFF')); gr = Vector(lin(foot))
    def colfn(p, n):
        t = (p[2] - SEA) / H
        c = gr.lerp(bc, S((t - .12) / .3)) if t < .45 else bc.lerp(sn, S((t - snow) / .10))
        c = c * (.80 + .28 * max(0, Vector(n).dot(SUN)))
        c = c.lerp(HAZE, haze * (1 - .45 * t)); return (c.x, c.y, c.z)
    me = MB().add(V, F, 0, colfn=colfn, scale=1 / 90).build(name, ['far_peak'])
    return obj(name, me, 'Distant', X, 0, Z)


for k, (X, Z, R_, H_) in enumerate([(-240, -520, 260, 330), (-20, -640, 320, 430), (210, -560, 250, 310), (430, -430, 290, 380), (-480, -360, 270, 290),
                                    (600, -160, 290, 340), (-680, -60, 300, 320), (700, 260, 280, 260), (-860, 480, 340, 280), (-420, 900, 380, 300),
                                    (40, 1150, 420, 340), (520, 960, 360, 280), (-1150, 100, 380, 380), (1050, 640, 400, 320)]):
    mountain_v2('Distant_Mountain_%02d' % (k + 1), X, Z, R_, H_, 500 + k)
for k in range(12):
    a = k / 12 * 6.283 + .2; d = rnd.uniform(430, 640)
    if 0.7 < a < 2.6: d += 330                                      # keep the sea open to the south
    mountain_v2('Distant_Foothill_%02d' % (k + 1), math.cos(a) * d, math.sin(a) * d, rnd.uniform(160, 240), rnd.uniform(80, 130), 700 + k, snow=1.5, base='#3FAE5A', foot='#52C45E')
for k, (X, Z, R_, H_, tr) in enumerate([(-30, 190, 20, 12, True), (120, 200, 26, 18, True), (-190, 110, 24, 24, True), (-150, 185, 12, 30, False), (40, 330, 36, 28, True), (210, 60, 16, 20, True)]):
    sea_stack('Distant_SeaStack_%d' % (k + 1), X, Z, R_, H_, tree=tr)
for k in range(18):
    a = k / 18 * 6.283 + rnd.uniform(-.1, .1); d = rnd.uniform(420, 1150)
    cloud('Distant_Cloud_%02d' % (k + 1), math.cos(a) * d, rnd.uniform(110, 330), math.sin(a) * d, rnd.uniform(38, 95), 900 + k)
for k, (X, hh, Z, sc) in enumerate([(-170, 130, 250, 26), (150, 150, -260, 30), (270, 110, 190, 24)]):
    cloud('Distant_Cloud_Near_%d' % (k + 1), X, hh, Z, sc, 950 + k)

# ================================================================== SKY + LIGHT
world = bpy.data.worlds.new('W1v2_Sky'); scene.world = world; world.use_nodes = True
nt = world.node_tree
for n in list(nt.nodes): nt.nodes.remove(n)
out = nt.nodes.new('ShaderNodeOutputWorld'); bg = nt.nodes.new('ShaderNodeBackground')
tc = nt.nodes.new('ShaderNodeTexCoord'); sep = nt.nodes.new('ShaderNodeSeparateXYZ'); rampn = nt.nodes.new('ShaderNodeValToRGB')
mp = nt.nodes.new('ShaderNodeMapRange'); mp.inputs[1].default_value = -1; mp.inputs[2].default_value = 1
nt.links.new(tc.outputs['Generated'], sep.inputs[0]); nt.links.new(sep.outputs['Z'], mp.inputs[0]); nt.links.new(mp.outputs[0], rampn.inputs[0])
cr = rampn.color_ramp
stops = [(.40, '#CDEBFF'), (.50, '#E8F6FF'), (.56, '#A6DAFF'), (.68, '#63B8FA'), (.85, '#3D9BF2'), (1.0, '#2C86E6')]
cr.elements[0].position = stops[0][0]; cr.elements[0].color = (*lin(stops[0][1]), 1)
cr.elements[1].position = stops[-1][0]; cr.elements[1].color = (*lin(stops[-1][1]), 1)
for p_, c_ in stops[1:-1]:
    e = cr.elements.new(p_); e.color = (*lin(c_), 1)
nt.links.new(rampn.outputs[0], bg.inputs[0]); bg.inputs[1].default_value = .85; nt.links.new(bg.outputs[0], out.inputs[0])
sun = bpy.data.lights.new('Sun', 'SUN'); sun.energy = 3.0; sun.color = (1.0, .96, .86)
try: sun.angle = math.radians(4)
except Exception: pass
so = bpy.data.objects.new('Sun', sun); so.rotation_euler = (-SUN).to_track_quat('-Z', 'Y').to_euler(); so.location = (0, 0, 120); COL['Sky_Lighting'].objects.link(so)
fill = bpy.data.lights.new('SkyFill', 'SUN'); fill.energy = .45; fill.color = (.7, .86, 1.0)
try: fill.use_shadow = False
except Exception: pass
fo = bpy.data.objects.new('SkyFill', fill); fo.rotation_euler = Vector((-.5, -.6, -.6)).to_track_quat('-Z', 'Y').to_euler(); fo.location = (20, 0, 120); COL['Sky_Lighting'].objects.link(fo)

# ================================================================== REF
avatar('REF_Avatar_5p5_Hub', HUB[0] + 5, HUB[1] + 4, rot=.4)
avatar('REF_Avatar_5p5_Arrival', 70, 40, rot=2.4)
avatar('REF_Avatar_5p5_Knoll', kx - 5, kz - 3, rot=1.2)
bear = import_bear()
if bear:
    root, parts, kb = bear
    bz = root.location.z - height(1.2, 7.6)
    def put(r2, X, Z, rot): r2.location = (X, -Z, bz + height(X, Z)); r2.rotation_euler = (0, 0, rot)
    put(root, HUB[0] + 1.5, HUB[1] + 5.5, -.35)
    def dup(name, X, Z, rot):
        r2 = bpy.data.objects.new(name, None); COL['REF'].objects.link(r2); mp_ = {}
        for o in parts:
            c = o.copy(); COL['REF'].objects.link(c); mp_[o] = c
        for o, c in mp_.items(): c.parent = mp_.get(o.parent, r2) if o.parent is not root else r2
        r2.scale = root.scale; put(r2, X, Z, rot)
    dup('REF_Bear_ToyLawn', -32, 21, .9); dup('REF_Bear_Spring', 53, 16, 2.6); dup('REF_Bear_Arrival', 67, 43, 2.0)

# ================================================================== CAMERAS
cam('Cam_01_Overview', (-150, 175, 250), (-8, -4, 12), 30)                 # identical to v1 for the side-by-side
cam('Cam_02_SpawnView', (100, height(100, 69) + 5.0, 69), (40, 11, 22), 20)
cam('Cam_03_Hub', (-16, 10, 22), (-33, 5.5, -12), 22)
cam('Cam_04_TumbleFalls', (36, 8, -22), (fx * (Rf + 6), 16, fz * (Rf + 6)), 22)
cam('Cam_05_Distant', (kx + 5, kh + 6.0, kz + 3), (40, -2, 130), 20)
cam('Cam_06_Scale', (HUB[0] + 7, 3.0, HUB[1] + 15), (HUB[0] + 2.5, 3.0, HUB[1] - 2), 30)
cam('Cam_07_GlowGrotto', (-24, 6.5, -44), (gx * (Rg + 4), 7, gz * (Rg + 4)), 24)
cam('Cam_08_Cove', (-30, 9, 30), (-4, 0, 66), 20)
cam('Cam_09_TopDownMap', (0, 420, 0), (0, 0, -.1), 50)
cam('Cam_10_KnollPinwheel', (-24, 7, 22), (kx, 16, kz), 22)
cam('Cam_11_ArrivalBack', (40, 14, 20), (86, 6, 60), 24)
scene.camera = bpy.data.objects['Cam_02_SpawnView']

for eng in ('BLENDER_EEVEE', 'BLENDER_EEVEE_NEXT'):
    try:
        scene.render.engine = eng; break
    except TypeError: continue
scene.render.resolution_x = 1600; scene.render.resolution_y = 900
try: scene.view_settings.view_transform = 'Standard'; scene.view_settings.look = 'None'
except Exception as e: print('view transform:', e)
for attr, val in (('taa_render_samples', 48), ('use_shadows', True), ('use_gtao', True), ('gtao_distance', 6.0)):
    try: setattr(scene.eevee, attr, val)
    except Exception: pass

# ================================================================== STATS
vis = 0; per = {}
for o in scene.objects:
    if o.type != 'MESH': continue
    t = tri_count(o.data); top = o.users_collection[0].name
    for pn in ('Walls_Rocks', 'Props'):
        if top in [c.name for c in COL[pn].children]: top = pn
    per[top] = per.get(top, 0) + t; vis += t
cell = 2.0; a_g = a_pet = 0
for i in range(-70, 70):
    for j in range(-70, 70):
        X, Z = (i + .5) * cell, (j + .5) * cell
        if in_garden(X, Z): a_g += cell * cell
        if pet_ok(X, Z): a_pet += cell * cell
main = resample(chaikin(PATHS['Path_SpawnToHub'], 3), 1) + resample(chaikin(PATHS['Path_BridgeToHub'], 3), 1)
walk = sum(math.dist(a, b) for a, b in zip(main, main[1:])) + math.dist(main[-1], HUB) - 14
V1_AREA = 241 * 200
stats = {'triangles_visible_total': vis, 'triangles_without_REF': vis - per.get('REF', 0), 'triangles_by_collection': per,
         'triangles_unique_mesh_data': sum(tri_count(m) for m in bpy.data.meshes if m.users),
         'garden_floor_area_sq_studs': round(a_g), 'v1_floor_area_sq_studs': V1_AREA, 'area_ratio_vs_v1': round(a_g / V1_AREA, 3),
         'pet_walkable_area_sq_studs': round(a_pet), 'garden_extent_studs': {'east_west': round(RIM(0) + RIM(180)), 'north_south': round(RIM(90) + RIM(270))},
         'spawn_to_hub_path_studs': round(walk), 'spawn_to_hub_seconds_at_16': round(walk / 16, 1),
         'stations': STATIONS, 'hatch_tree': HATCH_TREE, 'hub_centre': HUB, 'chime_arch': ARCH, 'bridge': BRIDGE, 'knoll_pinwheel': KNOLL[:2],
         'falls_foot': [round(fx * Rf, 1), round(fz * Rf, 1)], 'grotto_mouth': [round(gx * Rg, 1), round(gz * Rg, 1)], 'lamps': LAMPS,
         'station_heights': {k_: round(height(*v_), 3) for k_, v_ in STATIONS.items()},
         'origin_note': 'Blender (x,y,z) = Roblox (X, -Z, Y-4); 1 unit = 1 stud'}
json.dump(stats, open(os.path.join(HERE, 'stats.json'), 'w'), indent=1)
print('STATS', json.dumps({k_: v_ for k_, v_ in stats.items() if k_ not in ('stations', 'lamps')}))
bpy.ops.wm.save_as_mainfile(filepath=OUT, relative_remap=True)
try:
    for img in bpy.data.images:
        if img.filepath: img.filepath = bpy.path.relpath(img.filepath)
    bpy.ops.wm.save_mainfile()
except Exception as e: print('relpath:', e)
print('BUILD_OK', OUT)
