"""Egg Drop - World 1 mockup v4 ("Chime Cove", floating). v3 layout; painted textures, crisp sun, clear water.

  blender --factory-startup -b --python artifacts/world1-mockup/v4/build_world_v4.py

Writes assets/art-source/environment/world1-mockup-v4.blend, v4/stats.json and v4/water-check.json.
Re-running OVERWRITES the .blend: once it has been hand-edited, treat the .blend as the source.
Footprint: RIM(theta) = edge of the walkable floor, wall_H(theta) = rock wall behind it, rim_out(theta) = outer
edge of the island. Coordinates: Blender (x, y, z) = Roblox (X, -Z, Y - 4); 1 unit = 1 stud.
"""
import bpy, bmesh, math, os, json, random, sys
from mathutils import Vector, Matrix, Euler

HERE = os.path.dirname(os.path.abspath(__file__))
exec(compile(open(os.path.join(HERE, 'world_lib.py'), encoding='utf-8').read(), 'world_lib.py', 'exec'))
REPO = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
ENV = os.path.join(REPO, 'assets', 'art-source', 'environment')
TEX = os.path.join(ENV, 'textures', 'v4')
OUT = os.path.join(ENV, 'world1-mockup-v4.blend')
BEAR = os.path.join(REPO, 'assets', 'garden-babies', 'bear.fbx')
rnd = random.Random(2026)
_ico_cache = {}
STATS = {}
WATER = -0.8          # stream + pools
SEA = -9.0            # no sea in v3: only the depth where the terrain skirt stops
SUN = Vector((-0.52, -0.42, 0.70)).normalized()


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
STREAM = chaikin([(64, -66), (46, -46), (30, -30), (20, -18), (12, -6), (3, 8), (5, 24), (0, 38), (-5, 50), (-7, 62), (-7, 80)], 3)
FALLS_POOL = (65, -65, 15, 13)
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
        e = math.hypot((X - px) / rx, (Z - pz) / rz)
        if e < 1.3: h = h * S((e - .9) / .4) - depth * (1 - S((e - .74) / .16))
    ds = pdist(X, Z, STREAM)
    if ds < 9 and d < 26: h = min(h, h * S((ds - 4.6) / 4.4) - 2.3 * (1 - S((ds - 3.2) / 1.4)))
    # --- outside the rim: rock wall, or open bank / beach down to the sea
    if d > 0:
        E = wall_env(th); H = wall_H(th)
        face = S(d / (5 + H * .2))
        back = S((d - 24) / (16 + H * .9))
        wh = H * face * (1 + .14 * (fbm(X / 16, Z / 16, 7) - .5) * 2) * (1 - back)
        lat = math.radians(angd(th, GROTTO_TH)) * Rr                # grotto corridor through the wall
        wh *= 1 - S((8.5 - abs(lat)) / 3) * S((19 - d) / 3)
        latf = math.radians(angd(th, FALLS_TH)) * Rr                # falls corridor: lower step, ledge, upper step (set back behind the rock face mesh)
        if abs(latf) < 11:
            prof = (17 * S((d - 2.5) / 3) + (H - 17) * S((d - 12) / 4)) * (1 - back)
            kf = S((11 - abs(latf)) / 3); wh = wh * (1 - kf) + prof * kf
        wopen = 6 + 5 * g(th, 97, 20)                               # a short bank, then the drop
        h += wh - 9 * back * E + (1 - E) * (-9) * S(d / wopen)
    if -4 < d < 7: h += (1 - wall_env(th)) * .65 * math.exp(-((d - 1.0) / 2.0) ** 2) * (1 - g(th, 97, 6))   # raised lip on the open edge
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
scene = bpy.context.scene; scene.name = 'World1_Mockup_v4'; scene.unit_settings.system = 'NONE'
COL = {}
for nm in ['Ground', 'Underside', 'Walls_Rocks', 'Water', 'Architecture', 'Landmarks', 'Stations', 'Props', 'Sky_Islets', 'Distant', 'Sky_Lighting', 'Cameras', 'REF']:
    c = bpy.data.collections.new(nm); scene.collection.children.link(c); COL[nm] = c
MAT = {}
for n_, r_ in [('grass', .9), ('meadow', .9), ('dirt_path', .9), ('cliff_rock', .85), ('boulder_rock', .8), ('sand_pebble', .9),
               ('wood_plank', .7), ('bark', .85), ('foliage', .8), ('foliage_blossom', .8), ('stone_tile', .6)]:
    mat_tex(n_, n_, r_)
mat_tex('ground', 'ground_soft', .92); mat_tex('pebble_bed', 'pebble_bed', .85)
mat_tex('marble', 'marble_block', .55, spec=.2); mat_tex('trim', 'marble_trim', .5, spec=.2); mat_flat('gold', lin('#F2B62E'), rough=.3, spec=.8, coat=.3); mat_flat('teal', lin('#12B0A8'), rough=.35, coat=.3)
MAT['stone_tile'] = MAT['marble']                                 # every pad, basin and plinth is marble in v3
TREE_LOG = {'moved': [], 'dropped': []}
mat_tex('water', 'water', rough=.05, alpha=.46, spec=1.0, emit=.10)
mat_tex('waterfall', 'waterfall', rough=.3, emit=.35)
mat_unlit('far_peak', 'far_peak'); mat_unlit('cloud'); mat_unlit('foam')
for nm, hx, kw in [('ph_white', '#FFFFFF', dict(rough=.3, coat=.3)), ('ph_aqua', '#35C7F5', dict(rough=.25, coat=.4)), ('ph_pink', '#FF6FAE', {}),
                   ('ph_yellow', '#FFD84A', {}), ('ph_mint', '#5FE89A', {}), ('ph_lilac', '#A88BFF', {}), ('canvas', '#FFF1CC', dict(rough=.8)),
                   ('stem', '#2FA83F', dict(rough=.8)), ('avatar_skin', '#F2D3B1', {}), ('avatar_shirt', '#F4573B', {}), ('avatar_pants', '#3B4C8C', {}),
                   ('cave_dark', '#101A33', dict(rough=1.0, spec=0.0))]:
    mat_flat(nm, lin(hx), **({'rough': .45} | kw))
mat_flat('glow_warm', lin('#FFD98A'), emit=1.4); mat_flat('glow_aqua', lin('#4FE6FF'), emit=1.3, rough=.2); mat_flat('glow_pink', lin('#FF7FD0'), emit=1.2, rough=.2)
mat_flat('bubble', lin('#D8F6FF'), rough=.05, alpha=.42, spec=1.0, emit=.25)
mat_flat('egg', lin('#FFF9F0'), rough=.3, coat=.5, vcol=True)
leaf_col = shade_top(.74, 1.10, .02)
C_GRASS_A = Vector(lin('#1E9A31')); C_GRASS_B = Vector(lin('#34B53C')); C_GRASS_HI = Vector(lin('#168A2B'))
C_SAND = Vector(lin('#F4E0A0')); C_STONE = Vector(lin('#BDB694')); C_STONE_D = Vector(lin('#8F8A6C'))

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
    edge = d > 2.0 and h < .4
    if edge: c = C_STONE.lerp(C_STONE_D, S(-h / 6))                 # the lip and the skirt below it are rock
    gcol.grass = S((.15 - h) / .7) < .5 and rock < .5 and not edge
    k = 1.0
    if 0 < d < 10 and wall_env(th) > .5 and h < 4: k = .86 + .14 * (d / 10)   # contact shade at wall foot
    return (c.x * k, c.y * k, c.z * k)


vid = {}; GV = []; GC = []; GF = []; GG = []
def gv(i, j):
    if (i, j) not in vid:
        vid[(i, j)] = len(GV); GV.append(B(X0 + i * STEP, Hg[j][i], Z0 + j * STEP)); GC.append(gcol(i, j)); GG.append(gcol.grass)
    return vid[(i, j)]
for j in range(NZg):
    for i in range(NXg):
        if max(Hg[j][i], Hg[j][i + 1], Hg[j + 1][i], Hg[j + 1][i + 1]) < -7.6: continue
        a, b, c, d = gv(i, j), gv(i + 1, j), gv(i + 1, j + 1), gv(i, j + 1)
        if (i + j) % 2: GF += [(a, d, c), (a, c, b)]
        else: GF += [(a, d, b), (b, d, c)]
me = bpy.data.meshes.new('Ground_Terrain'); me.from_pydata(GV, [], GF)
def tex_mean(mat):
    img = next(n for n in MAT[mat].node_tree.nodes if n.type == 'TEX_IMAGE').image
    px = list(img.pixels); n_ = len(px) // 4
    return Vector(tuple(lin_f(sum(px[k::4]) / n_) for k in range(3)))


def lin_f(x): return x / 12.92 if x <= .04045 else ((x + .055) / 1.055) ** 2.4


GRASS_MEAN = tex_mean('grass'); BED_MEAN = Vector((1, 1, 1))
uvs = []; cols = []; fmat = []
for f in GF:
    p0, p1, p2 = (Vector(GV[t]) for t in f)
    steep = abs((p1 - p0).cross(p2 - p0).normalized().z) < .72
    cx_ = (p0.x + p1.x + p2.x) / 3; cz_ = -(p0.y + p1.y + p2.y) / 3
    is_grass = all(GG[t] for t in f)
    is_bed = min(p0.z, p1.z, p2.z) < WATER - .1 and max(p0.z, p1.z, p2.z) < .2 and (in_garden(cx_, cz_, -2) or pdist(cx_, cz_, STREAM) < 6)
    is_grass = is_grass and not is_bed
    fmat.append(0 if is_grass else 2 if is_bed else 1)
    for t in f:
        x, y, z = GV[t]
        if is_grass:      # the painted grass tile carries the colour; the vertex colour only tints it (and fades it into sand / rock at the edges)
            uvs += [x / 14, y / 14]; c_ = GC[t]; cols += [min(2.2, c_[0] / GRASS_MEAN.x), min(1.6, c_[1] / GRASS_MEAN.y), min(2.2, c_[2] / GRASS_MEAN.z), 1]
        elif is_bed:
            uvs += [x / 9, y / 9]; k_ = .78 + .22 * S((z + 3.4) / 2.6); cols += [k_ * .74, k_ * .93, k_ * 1.12, 1]
        else:
            uvs += ([(x * .7 - y * .7) / 16, z / 16] if steep else [x / 16, y / 16]); cols += [*GC[t], 1]
me.uv_layers.new(name='UVMap').data.foreach_set('uv', uvs)
me.color_attributes.new('Col', 'FLOAT_COLOR', 'CORNER').data.foreach_set('color', cols)
for m_ in ('grass', 'ground', 'pebble_bed'): me.materials.append(MAT[m_])
me.polygons.foreach_set('material_index', fmat); me.polygons.foreach_set('use_smooth', [True] * len(GF)); me.update()
obj('Ground_Terrain', me, 'Ground')

for nm, pts in PATHS.items():
    ribbon(nm, pts, 5.6 if nm in ('Path_SpawnToHub', 'Path_BridgeToHub') else 4.0, lift=.14)
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
        if up: mb.add(v, [face], 1, col=(.95 * j, 1.0 * j, .95 * j), scale=1.3)
        else:
            k = (.66 + .44 * (n.z * .5 + .5) + .10 * max(0, n.dot(SUN))) * j; ms = .55 * S((n.z - .35) / .4) if grass else 0
            mb.add(v, [face], 0, col=(k * (1.02 - .42 * ms), k * (1 - .08 * ms), k * (.97 - .55 * ms)), scale=.62)
    me = mb.build(name, ['cliff_rock', 'grass'])
    bm = bmesh.new(); bm.from_mesh(me); bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5); bm.to_mesh(me); bm.free()
    return me


CRAG = [crag_mesh('Crag_%d' % k, 800 + k) for k in range(6)]
CRAG_BARE = [crag_mesh('CragBare_%d' % k, 830 + k, chisel=11, grass=False) for k in range(3)]
ROCK = {}
rock_col = shade_top(.74, 1.08, .015)
for k in range(4):
    v, f = blob(2, 300 + k, rough=.16, chisel=8, squash=(1, 1, .85)); ROCK['big%d' % k] = MB().add(v, f, 0, colfn=rock_col, scale=.5).build('Rock_Big_%d' % k, ['boulder_rock'])
    v, f = blob(1, 340 + k, rough=.2, chisel=5, squash=(1, 1, .8)); ROCK['small%d' % k] = MB().add(v, f, 0, colfn=rock_col, scale=.5).build('Rock_Small_%d' % k, ['boulder_rock'])
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
    if H > 3 and lat > 12 and fall > 21:
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

# rim stones in the balustrade gaps, stream banks, pools
BAL_ARCS = ((16, 31), (38, 60), (66, 86), (108, 126), (150, 172), (178, 198))
th = 20.0
while th < 198:
    Rr = RIM(th)
    if g(th, 97, 9) < .4 and not any(a0 - 1 <= th <= a1 + 1 for a0, a1 in BAL_ARCS):
        X, Z = P(th, Rr + rnd.uniform(.5, 3))
        rock('Rocks_Shore', X, Z, rnd.uniform(2.2, 5.2), sink=.3)
    th += math.degrees(rnd.uniform(7, 13) / Rr)
rp = resample(STREAM, 8)
for k, (X, Z) in enumerate(rp):
    if not in_garden(X, Z, 4) or math.hypot(X - BRIDGE[0], Z - BRIDGE[1]) < 8: continue
    nx, nz = outward(rp, k); sgn = 1 if k % 2 else -1
    rock('Rocks_Shore', X + nx * 7.0 * sgn, Z + nz * 7.0 * sgn, rnd.uniform(1.4, 2.6), kind='small%d' % rnd.randrange(4), sink=.3)
for (px, pz, rx, rz), n in ((FALLS_POOL, 9), (LILY, 7)):
    for k in range(n):
        a = k / n * 6.283 + rnd.uniform(-.2, .2)
        X, Z = px + math.cos(a) * rx * 1.24, pz + math.sin(a) * rz * 1.24
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
            d_w = r - RIM(th_)
            if d_w > 2.5 or (d_w > -4 and pdist(X + 1.5, Z + 1.5, STREAM) > 7): continue
            if min(height(X + a, Z + b) for a in (0, step) for b in (0, step)) < WATER + .2:
                F.append([vi(i, j), vi(i, j + 1), vi(i + 1, j + 1), vi(i + 1, j)])
    mb = MB(); mb.v = V
    for f in F:
        mb.f.append(f); mb.mi.append(0)
        for k in f: mb.uv.append(U[k]); mb.col.append((1, 1, 1, 1))
    obj('Water_StreamAndPools', mb.build('Water_StreamAndPools', ['water']), 'Water')


water_sheet_v2()

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


# ================================================================== ARCHITECTURE KIT (original classical pieces, marble + gold + teal)
for sc in ('Plaza', 'Colonnade', 'MarbleArch', 'Rotunda', 'Aqueduct', 'Balustrades', 'Statues_Urns', 'Ruins', 'Stairs', 'Bridge'): subcol('Architecture', sc)
MARBLE = ['marble', 'gold', 'teal']


def T(X, h, Z, yaw=0.0):
    return Matrix.Translation(B(X, h, Z)) @ Matrix.Rotation(yaw, 4, 'Z')


def yaw_of(dX, dZ):
    """Blender Z rotation that points local +X along world direction (dX, dZ)."""
    return math.atan2(-dZ, dX)


def trim_box(mb, L, D, Hh, row, M, mat):
    """Box whose four sides show one band of the carved trim sheet (row 0 paw/star, 1 zig-zag, 2 egg/leaf)."""
    v, f = box(L, D, Hh); uv = []
    for k, p in enumerate(v):
        face = k // 4; vv = (row_v(row)[0] + (p[2] / Hh + .5) * .25)
        if face in (2, 3): uv.append((p[0] / (4 * Hh), vv))
        elif face in (4, 5): uv.append((p[1] / (4 * Hh), vv))
        else: uv.append((p[0] / (4 * Hh), .02 + (p[1] / D + .5) * .2))
    mb.add(v, f, mat, uvs=uv, M=M)


def row_v(row): return (.75 - .25 * row, 1.0 - .25 * row)


def fix_normals(me):
    bm = bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm, faces=bm.faces); bm.to_mesh(me); bm.free(); return me


def repivot(o):
    """World-space-built mesh -> origin at the centre of its base."""
    me = o.data; xs = [v.co.x for v in me.vertices]; ys = [v.co.y for v in me.vertices]; zs = [v.co.z for v in me.vertices]
    piv = Vector(((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, min(zs)))
    me.transform(Matrix.Translation(-piv)); o.location = o.location + piv; return o


def flute(p, n):
    a = math.atan2(p[1], p[0]); k = (.94 if math.sin(a * 10) > 0 else 1.0) * (.9 + .12 * (n[2] * .5 + .5))
    return (k, k, k)


def column_parts(mb, h=9.0, r=.72, broken=None, M=None):
    top = h if broken is None else h * broken
    v, f = box(2.3, 2.3, .35, (0, 0, .175)); mb.add(v, f, 0, M=M, scale=.2)
    v, f, uv = lathe([(1.0, .35), (1.05, .55), (.86, .7), (.9, .85), (r, 1.0), (r * .9, top - (1.0 if broken is None else 0))], 10)
    mb.add(v, f, 0, uvs=uv, colfn=flute, M=M)
    if broken is None:
        v, f, uv = lathe([(r * .9, h - 1.0), (r * 1.0, h - .85), (r * .92, h - .7), (1.02, h - .42)], 10); mb.add(v, f, 1, uvs=uv, M=M)
        v, f = box(2.2, 2.2, .42, (0, 0, h - .21)); mb.add(v, f, 0, M=M, scale=.2)
    else:
        v, f, uv = lathe([(r * .9, top), (.02, top + .1)], 10); v = [(p[0], p[1], p[2] + p[0] * .45) for p in v]; mb.add(v, f, 0, uvs=uv, M=M)


def arch_ring(ri, ro, dp, n=18):
    """Half-ring in the local XZ plane (springing at z = 0), depth dp along Y. Clean quads, no sweep twist."""
    V = []; F = []
    for k in range(n + 1):
        a = math.pi * k / n; c, s_ = math.cos(a), math.sin(a)
        V += [(-c * ri, -dp / 2, s_ * ri), (-c * ri, dp / 2, s_ * ri), (-c * ro, -dp / 2, s_ * ro), (-c * ro, dp / 2, s_ * ro)]
    for k in range(n):
        a = k * 4; b = a + 4
        F += [[a, b, b + 1, a + 1], [a + 2, a + 3, b + 3, b + 2], [a, a + 2, b + 2, b], [a + 1, b + 1, b + 3, a + 3]]
    return V, F


def finish(name, mb, mats, coll, X=None, h=0, Z=None, rot=0, smooth=False, pivot=True):
    me = fix_normals(mb.build(name, mats, smooth=smooth))
    o = obj(name, me, coll) if X is None else obj(name, me, coll, X, h, Z, rot=rot)
    if X is None and pivot: repivot(o)
    return o


COLUMN = fix_normals((lambda mb: (column_parts(mb), mb)[1])(MB()).build('Column', MARBLE))
COLUMN_BROKEN = [fix_normals((lambda mb: (column_parts(mb, broken=b_), mb)[1])(MB()).build('Column_Broken_%d' % i, MARBLE)) for i, b_ in enumerate((.5, .28))]
v, f, uv = lathe([(.68, 0), (.68, 1.9)], 10, True, True); DRUM = fix_normals(MB().add(v, f, 0, uvs=uv, colfn=flute).build('Column_Drum', MARBLE))


def urn_mesh():
    mb = MB()
    v, f = box(1.6, 1.6, .9, (0, 0, .45)); mb.add(v, f, 0, scale=.2)
    v, f, uv = lathe([(.5, .9), (.6, 1.05), (.28, 1.3), (.8, 2.1), (.95, 2.7)], 8); mb.add(v, f, 0, uvs=uv)
    v, f, uv = lathe([(.95, 2.7), (.95, 2.95)], 8); mb.add(v, f, 1, uvs=uv)
    v, f, uv = lathe([(.95, 2.95), (.6, 3.4), (.78, 3.7), (.6, 3.7)], 8); mb.add(v, f, 0, uvs=uv)
    return fix_normals(mb.build('Urn', MARBLE, smooth=True))


def plush_statue_mesh():
    """A round, generic plush-toy figure on a pedestal (our own shape language, no real character)."""
    mb = MB()
    v, f = box(2.4, 2.4, .4, (0, 0, .2)); mb.add(v, f, 0, scale=.2)
    v, f = box(1.8, 1.8, 1.7, (0, 0, 1.25)); mb.add(v, f, 0, scale=.2)
    v, f = box(2.2, 2.2, .3, (0, 0, 2.25)); mb.add(v, f, 1)
    for (c, sq) in (((0, 0, 3.25), (.95, .9, .9)), ((0, -.05, 4.6), (.9, .85, .8)), ((-.62, 0, 5.3), (.3, .2, .3)), ((.62, 0, 5.3), (.3, .2, .3)),
                    ((-.85, -.3, 3.5), (.3, .3, .42)), ((.85, -.3, 3.5), (.3, .3, .42)), ((-.45, -.5, 2.6), (.36, .5, .28)), ((.45, -.5, 2.6), (.36, .5, .28))):
        v, f = blob(2, 0, rough=0, squash=sq, center=c); mb.add(v, f, 0, colfn=shade_top(.86, 1.04), scale=.2)
    return fix_normals(mb.build('Statue_Plush', MARBLE, smooth=True))


def egg_statue_mesh():
    mb = MB()
    v, f = box(2.2, 2.2, .4, (0, 0, .2)); mb.add(v, f, 0, scale=.2)
    v, f, uv = lathe([(.8, .4), (.7, .6), (.7, 1.9), (.95, 2.1)], 8); mb.add(v, f, 0, uvs=uv, colfn=flute)
    v, f, uv = lathe([(.95, 2.1), (.95, 2.3)], 8, cap_top=True); mb.add(v, f, 1, uvs=uv)
    v, f, uv = lathe([(.02, 2.3), (.5, 2.4), (.85, 2.9), (.92, 3.4), (.75, 3.95), (.45, 4.35), (.02, 4.5)], 10); mb.add(v, f, 0, uvs=uv, colfn=shade_top(.88, 1.04))
    return fix_normals(mb.build('Statue_Egg', MARBLE, smooth=True))


URN = urn_mesh(); STATUE = plush_statue_mesh(); EGGSTAT = egg_statue_mesh()
ARCHN = [0]


def kit(prefix, me, coll, X, Z, rot=0.0, scale=1.0, h=None, tilt=(0, 0)):
    ARCHN[0] += 1
    return obj('%s_%02d' % (prefix, ARCHN[0]), me, coll, X, (height(X, Z) if h is None else h), Z, rot=rot, scale=scale, tilt=tilt)


def balustrade(name, pts, coll='Balustrades'):
    """Marble balustrade along a world polyline: posts with gold caps, balusters, top + bottom rails."""
    pts = resample(pts, 2.4); mb = MB()
    for i, (X, Z) in enumerate(pts):
        h = height(X, Z) - .15
        if i % 4 == 0 or i == len(pts) - 1:
            v, f = box(.85, .85, 3.1, (0, 0, 1.55)); mb.add(v, f, 0, M=T(X, h, Z), scale=.2)
            v, f = box(1.05, 1.05, .25, (0, 0, 3.2)); mb.add(v, f, 1, M=T(X, h, Z))
        else:
            v, f, uv = lathe([(.24, .5), (.36, 1.0), (.2, 1.7), (.26, 2.3)], 5); mb.add(v, f, 0, uvs=uv, M=T(X, h, Z))
        if i < len(pts) - 1:
            X2, Z2 = pts[i + 1]; h2 = height(X2, Z2) - .15; L = math.hypot(X2 - X, Z2 - Z)
            M = T((X + X2) / 2, (h + h2) / 2, (Z + Z2) / 2, yaw_of(X2 - X, Z2 - Z))
            v, f = box(L + .05, .62, .45, (0, 0, .28)); mb.add(v, f, 0, M=M, scale=.2)
            v, f = box(L + .05, .62, .3, (0, 0, 2.45)); mb.add(v, f, 0, M=M, scale=.2)
    return finish(name, mb, MARBLE, coll)


# ---- marble plaza: paving, teal inlay ring, curved colonnade behind the Hatch Tree
disc('Plaza_Paving', HUB[0], HUB[1], 15.5, 'marble', 'Plaza', lift=.13, segs=32, wob=.03, seed=3)
mb = MB(); V = []; U = []; F = []
for k in range(41):
    a = k / 40 * 6.283
    V += [(math.cos(a) * 10.4, math.sin(a) * 10.4, 0), (math.cos(a) * 11.9, math.sin(a) * 11.9, 0)]; U += [(k * .25 * 1.5, .52), (k * .25 * 1.5, .73)]
for k in range(40):
    a = k * 2; F.append([a, a + 1, a + 3, a + 2])
mb.add(V, F, 0, uvs=U)
finish('Plaza_InlayRing', mb, ['trim'], 'Plaza', HUB[0], .2, HUB[1])
mb = MB(); V = [(0, 0, 0)] + [(math.cos(k / 16 * 6.283) * (3.2 if k % 2 == 0 else 1.5), math.sin(k / 16 * 6.283) * (3.2 if k % 2 == 0 else 1.5), 0) for k in range(16)]
mb.add(V, [[0, 1 + k, 1 + (k + 1) % 16] for k in range(16)], 0)
finish('Plaza_InlayStar', mb, ['gold'], 'Plaza', HUB[0], .2, HUB[1])
COLS = []
for k, a in enumerate((196, 215, 234, 253, 272, 318, 338)):
    X, Z = HUB[0] + math.cos(math.radians(a)) * 23, HUB[1] + math.sin(math.radians(a)) * 23
    me = COLUMN if k < 5 else COLUMN_BROKEN[k - 5]
    kit('Colonnade_Column', me, 'Colonnade', X, Z, rot=-math.radians(a)); COLS.append((X, Z))
mb = MB()
for (X, Z), (X2, Z2) in zip(COLS[:5], COLS[1:5]):
    L = math.hypot(X2 - X, Z2 - Z); M = T((X + X2) / 2, 9.0, (Z + Z2) / 2, yaw_of(X2 - X, Z2 - Z))
    trim_box(mb, L + 2.2, 1.7, .9, 0, M @ Matrix.Translation((0, 0, .45)), 3)
    v, f = box(L + 2.4, 1.9, .22, (0, 0, 1.01)); mb.add(v, f, 1, M=M)
    v, f = box(L + 2.6, 2.1, .35, (0, 0, 1.3)); mb.add(v, f, 0, M=M, scale=.2)
finish('Colonnade_Entablature', mb, MARBLE + ['trim'], 'Colonnade')
kit('Colonnade_FallenDrum', DRUM, 'Colonnade', HUB[0] + 19, HUB[1] - 15, rot=.6, h=.68, tilt=(math.pi / 2, 0))
for X, Z, me, rt in [(HUB[0] - 12, HUB[1] + 13.5, EGGSTAT, 0), (HUB[0] + 12, HUB[1] + 13.5, EGGSTAT, 0), (HUB[0] - 16.5, HUB[1] - 13, URN, 0), (HUB[0] + 16.5, HUB[1] + 9, URN, 0)]:
    kit('Plaza_Ornament', me, 'Statues_Urns', X, Z, rot=rt)


# ---- Chime Arch, rebuilt as a clean marble arch (two piers + a true half-ring; no swept tube)
def marble_arch(X, Z, yaw):
    mb = MB(); px, ph, ri, ro, dp = 6.2, 7.0, 5.1, 7.3, 2.5
    for s in (-1, 1):
        v, f = box(3.1, 3.3, .55, (s * px, 0, .275)); mb.add(v, f, 0, scale=.2)
        v, f = box(2.3, 2.5, ph - .95, (s * px, 0, .55 + (ph - .95) / 2)); mb.add(v, f, 0, scale=.2)
        v, f = box(2.8, 3.0, .4, (s * px, 0, ph - .2)); mb.add(v, f, 1)
    V, F = arch_ring(ri, ro, dp, 18); mb.add(V, F, 0, scale=.2, M=Matrix.Translation((0, 0, ph)))
    v, f = box(1.1, dp + .3, ro - ri + .16, (0, 0, ph + (ri + ro) / 2)); mb.add(v, f, 1)                      # keystone
    v, f, uv = lathe([(.02, ph + ro + .05), (.45, ph + ro + .3), (.02, ph + ro + 1.0)], 6); mb.add(v, f, 1, uvs=uv)            # small gold finial on the keystone
    for s in (-1, 1): trim_box(mb, 2.42, 2.62, .6, 1, Matrix.Translation((s * px, 0, ph - .75)), 8)
    for k, (dx, L, m) in enumerate([(-3.4, 1.8, 3), (-1.7, 2.6, 4), (0, 3.2, 5), (1.7, 2.4, 6), (3.4, 1.7, 7)]):  # chimes
        top = ph + math.sqrt(ri * ri - dx * dx) - .1
        v, f = box(.06, .06, 1.0, (dx, 0, top - .5)); mb.add(v, f, 1)
        v, f, uv = lathe([(.24, top - 1.0 - L), (.24, top - 1.0)], 6, True, True); mb.add(v, f, m, uvs=uv, M=Matrix.Translation((dx, 0, 0)))
    return finish('Landmark_ChimeArch_Marble', mb, MARBLE + ['ph_pink', 'ph_yellow', 'ph_lilac', 'ph_aqua', 'ph_mint', 'trim'], 'MarbleArch', X, height(X, Z), Z, rot=yaw)


ARCH = (85, 57.5)
pd = Vector((ARCH[0] - STATIONS['Spawn'][0], -(ARCH[1] - STATIONS['Spawn'][1]), 0)).normalized()
ARCH_YAW = math.atan2(pd.y, pd.x) + math.pi / 2
marble_arch(ARCH[0], ARCH[1], ARCH_YAW)
for s in (-1, 1):                                                   # statues flank the path just inside the arch
    kit('Arch_Statue', STATUE, 'Statues_Urns', ARCH[0] + pd.x * 9 + pd.y * s * 7.5, ARCH[1] - pd.y * 9 + pd.x * s * 7.5, rot=ARCH_YAW + math.pi)

# ---- balustrades along the open edge (the lip that makes the drop read; gaps are closed by rim stones)
for k, (a0, a1) in enumerate(BAL_ARCS):
    balustrade('Balustrade_%d' % (k + 1), [P(a, RIM(a) + 1.1) for a in range(a0, a1 + 1, 2)])

# ---- Tumble Falls: aqueduct -> marble lip -> upper fall -> ledge pool -> lower fall -> falls pool
fx, fz = math.cos(math.radians(FALLS_TH)), math.sin(math.radians(FALLS_TH))
Rf = RIM(FALLS_TH); Hf = wall_H(FALLS_TH) + .4; acr = (-fz, fx)
def fp(d, h, lat=0.0): return (fx * (Rf + d) + acr[0] * lat, h, fz * (Rf + d) + acr[1] * lat)
# rock face that sits BEHIND the water everywhere (water is always 0.8-1.4 studs in front of it)
BACK = [(0.4, -2.5), (1.0, 6), (2.0, 14), (3.6, 17.7), (10.0, 17.7), (10.6, 22), (11.8, 34), (13.6, Hf), (19, Hf)]
LATS = [(-11.5, 5.0), (-8.5, 0.6), (-4, 0), (0, 0), (4, 0), (8.5, 0.6), (11.5, 5.0)]
mb = MB(); V = []; U = []; F = []
for j, (d, h) in enumerate(BACK):
    for i, (lat, push) in enumerate(LATS):
        jit = .5 * (_hash(i, j, 77) - .5) if 0 < j < len(BACK) - 1 else 0
        V.append(B(*fp(d + push + jit, h + (jit if 0 < j < 3 or 4 < j < 7 else 0), lat))); U.append((lat / 40, h / 40 + d / 60))
for j in range(len(BACK) - 1):
    for i in range(len(LATS) - 1):
        a = j * len(LATS) + i; F.append([a, a + 1, a + len(LATS) + 1, a + len(LATS)])
def facecol(p, n):
    k = .70 + .40 * (abs(n[2]) * .5 + .5) + .10 * max(0, Vector(n).dot(SUN)); return (k * 1.02, k, k * .97)
mb.add(V, F, 0, uvs=U, colfn=facecol)
finish('Landmark_TumbleFalls_RockFace', mb, ['cliff_rock'], 'Landmarks', pivot=False)
ribbon3('Water_TumbleFalls_Upper', [fp(15.5, Hf + .75), fp(12.7, Hf + .7), fp(11.6, Hf - 3), fp(10.6, 34), fp(9.6, 22), fp(9.2, 18.25)], [5, 8, 8.4, 8.8, 9.2, 9.6], acr)
ribbon3('Water_TumbleFalls_Lower', [fp(4.6, 18.3), fp(2.9, 18.2), fp(1.2, 14), fp(0.0, 6), fp(-.6, WATER)], [11, 11, 11.4, 12, 12.6], acr)
mb = MB(); V = [B(*fp(d, 18.15, lat)) for d, lat in ((3.3, -7), (3.3, 7), (10.2, 7), (10.2, -7))]; mb.add(V, [[0, 1, 2, 3], [3, 2, 1, 0]], 0, uvs=[(0, 0), (1, 0), (1, .5), (0, .5)])
obj('Water_TumbleFalls_LedgePool', mb.build('LedgePool', ['water']), 'Water')
for nm, d, hh, n_, spread in (('Water_TumbleFalls_Foam_Bottom', -1.6, WATER + .1, 9, 6.5), ('Water_TumbleFalls_Foam_Ledge', 8.2, 18.25, 6, 4.5)):
    mb = MB()
    for k in range(n_):
        lat = -spread + 2 * spread * k / (n_ - 1)
        v, f = blob(1, 90 + k, rough=.2, squash=(1.5, 1.3, .8)); mb.add(v, f, 0, col=(1, 1, 1), M=Matrix.Translation(B(*fp(d + rnd.uniform(-.6, .6), hh + .15, lat))))
    obj(nm, mb.build(nm, ['foam']), 'Water')
mb = MB()                                                           # marble lip on the ledge + spout at the top
v, f = box(15, .7, .7); mb.add(v, f, 0, M=T(*fp(3.2, 17.85), yaw_of(*acr)), scale=.2)
v, f = box(9.5, 3.6, .6); mb.add(v, f, 0, M=T(*fp(13.6, Hf + .15), yaw_of(*acr)), scale=.2)
for s in (-1, 1):
    v, f = box(.7, 3.8, 1.3); mb.add(v, f, 0, M=T(*fp(13.6, Hf + .7, s * 4.6), yaw_of(*acr)), scale=.2)
    v, f = box(.9, .9, .3); mb.add(v, f, 1, M=T(*fp(12.2, Hf + 1.5, s * 4.6), yaw_of(*acr)))
finish('Landmark_TumbleFalls_MarbleLips', mb, MARBLE, 'Aqueduct', pivot=False)
for side in (-1, 1):                                                # flanking forms, kept clear of the water
    for lvl, (d, w, top) in enumerate([(3.5, 11, 12), (8, 12, 25), (13, 12, Hf * .9), (20, 15, Hf * 1.22)]):
        x_, h_, z_ = fp(d + 2, 0, side * (15.5 + lvl * 1.2)); crag(x_, z_, w, top, coll='Landmarks').name = 'Landmark_TumbleFalls_Flank_%s%d' % ('L' if side < 0 else 'R', lvl)

# aqueduct: an arcade on the wall top carrying water to the falls lip
AQ_A = P(291, RIM(291) + 17); AQ_B = fp(15.2, 0)[0], fp(15.2, 0)[2]
aqL = math.dist(AQ_A, AQ_B); aqn = max(3, round(aqL / 8.5)); span = aqL / aqn; aqyaw = yaw_of(AQ_B[0] - AQ_A[0], AQ_B[1] - AQ_A[1]); aqtop = Hf + .15
mb = MB()
for i in range(aqn + 1):
    X = AQ_A[0] + (AQ_B[0] - AQ_A[0]) * i / aqn; Z = AQ_A[1] + (AQ_B[1] - AQ_A[1]) * i / aqn
    g0 = min(height(X, Z), aqtop - 6) - 2.5
    v, f = box(2.0, 2.8, aqtop - g0, (0, 0, (aqtop + g0) / 2)); mb.add(v, f, 0, M=T(X, 0, Z, aqyaw), scale=.2)
    v, f = box(2.5, 3.2, .35, (0, 0, aqtop - span / 2 - .2)); mb.add(v, f, 1, M=T(X, 0, Z, aqyaw))
    if i < aqn:
        Xm = X + (AQ_B[0] - AQ_A[0]) / aqn / 2; Zm = Z + (AQ_B[1] - AQ_A[1]) / aqn / 2; ra = span / 2 - 1.0
        V, F = arch_ring(ra, ra + .8, 2.6, 10); mb.add(V, F, 0, M=T(Xm, aqtop - ra - .8, Zm, aqyaw), scale=.2)
Xm, Zm = (AQ_A[0] + AQ_B[0]) / 2, (AQ_A[1] + AQ_B[1]) / 2
v, f = box(aqL + 2.4, 4.0, .7, (0, 0, aqtop + .35)); mb.add(v, f, 0, M=T(Xm, 0, Zm, aqyaw), scale=.2)
for s in (-1, 1):
    v, f = box(aqL + 2.4, .55, .9, (0, s * 1.75, aqtop + 1.1)); mb.add(v, f, 0, M=T(Xm, 0, Zm, aqyaw), scale=.2)
finish('Aqueduct_Arcade', mb, MARBLE, 'Aqueduct')
mb = MB(); v, f = box(aqL + 1.5, 2.9, .1, (0, 0, aqtop + 1.05)); mb.add(v, f, 0, M=T(Xm, 0, Zm, aqyaw), scale=.1)
obj('Water_AqueductChannel', mb.build('AqueductWater', ['water']), 'Water')
o = kit('Aqueduct_SourceUrn', URN, 'Aqueduct', AQ_A[0], AQ_A[1], scale=2.2, h=aqtop + 1.0); o.name = 'Aqueduct_SourceUrn'

# ---- Sky Falls: the stream runs out along a marble spout and pours off the island into the clouds
ce = min(resample(STREAM, 1), key=lambda p: abs(math.hypot(*p) - RIM(polar(*p)[1])))
sth = polar(*ce)[1]; sx_, sz_ = math.cos(math.radians(sth)), math.sin(math.radians(sth)); Rs = math.hypot(*ce); sacr = (-sz_, sx_)
def sp_(d, h, lat=0.0): return (sx_ * (Rs + d) + sacr[0] * lat, h, sz_ * (Rs + d) + sacr[1] * lat)
SPOUT_END = 13.0
mb = MB(); syaw = yaw_of(*sacr)
v, f = box(8.6, SPOUT_END + 3, .7); mb.add(v, f, 0, M=T(*sp_(SPOUT_END / 2 - 1.5, WATER - .75), syaw), scale=.2)
for s in (-1, 1):
    v, f = box(.8, SPOUT_END + 3, 1.9); mb.add(v, f, 0, M=T(*sp_(SPOUT_END / 2 - 1.5, WATER - .15, s * 3.9), syaw), scale=.2)
    v, f = box(1.1, 1.1, .3); mb.add(v, f, 1, M=T(*sp_(SPOUT_END - .2, WATER + .95, s * 3.9), syaw))
v, f = box(8.6, 2.2, 6.5); mb.add(v, f, 0, M=T(*sp_(SPOUT_END - 2.4, WATER - 4.3), syaw), scale=.2)       # bracket under the lip
finish('Landmark_SkyFalls_MarbleSpout', mb, MARBLE, 'Aqueduct', pivot=False)
mb = MB(); V = [B(*sp_(d, WATER, lat)) for d, lat in ((-3, -3.5), (-3, 3.5), (SPOUT_END + .1, 3.5), (SPOUT_END + .1, -3.5))]; mb.add(V, [[0, 1, 2, 3], [3, 2, 1, 0]], 0, uvs=[(0, 0), (.5, 0), (.5, 1), (0, 1)])
obj('Water_SkyFalls_Channel', mb.build('SkyFallsChannel', ['water']), 'Water')
ribbon3('Water_SkyFalls', [sp_(SPOUT_END - .6, WATER + .05), sp_(SPOUT_END + .5, WATER), sp_(SPOUT_END + 1.9, -4), sp_(SPOUT_END + 3.2, -16), sp_(SPOUT_END + 4.2, -38), sp_(SPOUT_END + 4.8, -72)], [7, 7, 7.3, 8, 9.5, 12], sacr)
mb = MB()
for k in range(5):
    v, f = blob(1, 60 + k, rough=.2, squash=(1.3, 1.1, .7)); mb.add(v, f, 0, col=(1, 1, 1), M=Matrix.Translation(B(*sp_(SPOUT_END + .4, WATER + .1, -2.8 + k * 1.4))))
obj('Water_SkyFalls_Foam', mb.build('SkyFallsFoam', ['foam']), 'Water')
cloud('Water_SkyFalls_Mist', *sp_(SPOUT_END + 5, -78), 11, 61)
bpy.data.objects['Water_SkyFalls_Mist'].users_collection[0].objects.unlink(bpy.data.objects['Water_SkyFalls_Mist']); COL['Water'].objects.link(bpy.data.objects['Water_SkyFalls_Mist'])
for s in (-1, 1):
    x_, h_, z_ = sp_(-4.5, 0, s * 8.5); kit('SkyFalls_Urn', URN, 'Statues_Urns', x_, z_)

# ================================================================== LANDMARKS (kept from v2)
# ---- Hatch Tree + lantern (moved with the hub)
hatch_tree()
for nm in ('Landmark_HatchTree', 'Landmark_HatchTree_Lantern'):
    o = bpy.data.objects[nm]; o.location.x += HATCH_TREE[0] + 3.4; o.location.y += -(HATCH_TREE[1] + 10.9)


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

# ---- Pinwheel Rotunda on the knoll, with a wide marble stair up the ramp
def rotunda(X, Z):
    h0 = height(X, Z); mb = MB()
    v, f, uv = lathe([(9.2, -2.0), (9.2, .3), (8.4, .3), (8.4, .6), (7.6, .6), (7.6, .9)], 16, cap_top=True); mb.add(v, f, 0, uvs=uv)
    for k in range(8):
        a = k / 8 * 6.283 + .39; column_parts(mb, h=7.5, r=.6, M=Matrix.Translation((math.cos(a) * 6.2, math.sin(a) * 6.2, .9)))
    v, f, uv = lathe([(5.3, 8.4), (7.2, 8.4), (7.4, 9.4), (5.1, 9.4), (5.3, 8.4)], 16); mb.add(v, f, 0, uvs=uv)
    v, f, uv = lathe([(7.5, 9.4), (7.5, 9.7), (7.2, 9.7)], 16); mb.add(v, f, 1, uvs=uv)
    v, f, uv = lathe([(7.2, 9.7), (6.8, 10.9), (5.5, 12.2), (3.4, 13.2), (.7, 13.85)], 16); mb.add(v, f, 2, uvs=uv)
    v, f, uv = lathe([(.7, 13.85), (1.0, 14.3), (.3, 15.0), (.75, 15.6), (.02, 16.5)], 8); mb.add(v, f, 1, uvs=uv)
    v, f, uv = lathe([(7.45, 8.45), (7.45, 9.35)], 24); mb.add(v, f, 3, uvs=[((n_ % 25) / 24 * 6.0, .27 + (n_ // 25) * .21) for n_ in range(len(v))])
    return finish('Landmark_KnollRotunda', mb, MARBLE + ['trim'], 'Rotunda', X, h0, Z, smooth=False)


rotunda(kx, kz)
o_ = kit('Rotunda_EggStatue', EGGSTAT, 'Rotunda', kx, kz, scale=1.6, h=height(kx, kz) + .9); o_.name = 'Landmark_KnollRotunda_EggStatue'
RAMP = math.radians(-52); rdx, rdz = math.cos(RAMP), math.sin(RAMP)
mb = MB(); s_ = kr - 1.5
while s_ < kr + 27:
    X, Z = kx + rdx * s_, kz + rdz * s_; hh = height(X, Z)
    if hh < .25: break
    v, f = box(2.3, 9.0, 1.6, (0, 0, -.5)); mb.add(v, f, 0, M=T(X, hh + .1, Z, yaw_of(rdx, rdz)), scale=.2)
    s_ += 1.7
STAIR_END = (kx + rdx * s_, kz + rdz * s_)
finish('Stairs_KnollSteps', mb, MARBLE, 'Stairs')
for s in (-1, 1):
    kit('Stairs_Urn', URN, 'Statues_Urns', STAIR_END[0] - rdz * s * 6, STAIR_END[1] + rdx * s * 6)

# ---- ruins: Blossom Point and beside the grotto
for X, Z, me, rt, tl, hh in [(-92, -4, COLUMN, 0, (0, 0), None), (-96, -19, COLUMN_BROKEN[0], .5, (0, 0), None), (-88, -18, COLUMN_BROKEN[1], 1.1, (0, 0), None),
                             (-90, -22, DRUM, .9, (math.pi / 2, 0), .68), (-86.5, -21, DRUM, 2.2, (math.pi / 2, 0), .68),
                             (-22, -78, COLUMN_BROKEN[0], .3, (0, 0), None), (7, -80, COLUMN, 0, (0, 0), None), (3, -74, DRUM, .4, (math.pi / 2, 0), .68)]:
    kit('Ruin', me, 'Ruins', X, Z, rot=rt, tilt=tl, h=hh)
kit('BlossomPoint_Statue', STATUE, 'Statues_Urns', -103, -8, rot=math.pi / 2)

# ---- marble bridge: flat deck seated on both banks (pets cross here), low ramps at each end
mb = MB(); bL, bW, DT = 20.0, 6.6, .34                              # DT = deck top above the lawn
v, f = box(bL, bW, .8, (0, 0, DT - .4)); mb.add(v, f, 0, scale=.2)
for s in (-1, 1):                                                   # end ramps down to the lawn + abutment blocks in the bank
    x0, x1 = s * bL / 2, s * (bL / 2 + 2.6)
    V = [(x0, -bW / 2, DT), (x0, bW / 2, DT), (x1, bW / 2, .03), (x1, -bW / 2, .03), (x0, -bW / 2, -.5), (x0, bW / 2, -.5), (x1, bW / 2, -.5), (x1, -bW / 2, -.5)]
    mb.add(V, [[0, 1, 2, 3], [0, 3, 7, 4], [1, 5, 6, 2], [3, 2, 6, 7]], 0, scale=.2)
    v, f = box(3.0, bW + .8, 2.6, (s * (bL / 2 - 1.8), 0, -1.6)); mb.add(v, f, 0, scale=.2)
    trim_box(mb, bL, .2, .7, 1, Matrix.Translation((0, s * (bW / 2 + .06), DT - .38)), 3)
V, F = arch_ring(4.3, 5.0, bW, 10); mb.add(V, F, 0, scale=.2, M=Matrix.Translation((0, 0, -4.75)))
for s in (-1, 1):
    v, f = box(bL, .5, .35, (0, s * (bW / 2 - .3), DT + 2.45)); mb.add(v, f, 0, scale=.2)
    for k in range(9):
        x = -bL / 2 + .6 + k * (bL - 1.2) / 8
        if k % 4 == 0:
            v, f = box(.8, .8, 2.9, (x, s * (bW / 2 - .3), DT + 1.45)); mb.add(v, f, 0, scale=.2)
            v, f = box(1.0, 1.0, .25, (x, s * (bW / 2 - .3), DT + 3.0)); mb.add(v, f, 1)
        else:
            v, f = box(.3, .3, 2.2, (x, s * (bW / 2 - .3), DT + 1.2)); mb.add(v, f, 0, scale=.2)
finish('Bridge_Main_Marble', mb, MARBLE + ['trim'], 'Bridge', BRIDGE[0], 0.0, BRIDGE[1])

# ---- marble edging along the stream and around both pools
def curb(mb, pts):
    """Kerb 1.2 wide, top 0.28 above the lawn, wall down into the bed, along a world polyline."""
    acc = 0; prev = None; rows = []
    for i, (X, Z) in enumerate(pts):
        a_ = pts[max(i - 1, 0)]; b_ = pts[min(i + 1, len(pts) - 1)]; tx, tz = b_[0] - a_[0], b_[1] - a_[1]; L = math.hypot(tx, tz) or 1; nx, nz = -tz / L, tx / L
        if prev: acc += math.dist(prev, (X, Z))
        prev = (X, Z); rows.append([(X - nx * .6, .28, Z - nz * .6), (X + nx * .6, .28, Z + nz * .6), (X + nx * .6, -2.2, Z + nz * .6), (X - nx * .6, -2.2, Z - nz * .6), acc])
    for r0, r1 in zip(rows, rows[1:]):
        for (a_, b_, v0, v1) in ((0, 1, .0, .24), (1, 2, .25, .74), (3, 0, .25, .74)):
            V = [B(*r0[a_]), B(*r0[b_]), B(*r1[b_]), B(*r1[a_])]
            mb.add(V, [[0, 1, 2, 3], [3, 2, 1, 0]], 0, uvs=[(r0[4] * .2, v0), (r0[4] * .2, v1), (r1[4] * .2, v1), (r1[4] * .2, v0)])


subcol('Architecture', 'Edging')
def pool_e(X, Z, pool): return math.hypot((X - pool[0]) / pool[2], (Z - pool[1]) / pool[3])
mb = MB(); sp_pts = resample(STREAM, 2.5)
for side in (-1, 1):
    run = []
    for i, (X, Z) in enumerate(sp_pts):
        nx, nz = outward(sp_pts, i); nx, nz = (nx, nz) if True else (0, 0)
        a_ = sp_pts[max(i - 1, 0)]; b_ = sp_pts[min(i + 1, len(sp_pts) - 1)]; tx, tz = b_[0] - a_[0], b_[1] - a_[1]; L = math.hypot(tx, tz) or 1
        px_, pz_ = X - tz / L * side * 4.3, Z + tx / L * side * 4.3
        ok = in_garden(px_, pz_, .5) and pool_e(px_, pz_, FALLS_POOL) > .93 and pool_e(px_, pz_, LILY) > .93
        if ok: run.append((px_, pz_))
        if (not ok or i == len(sp_pts) - 1) and len(run) > 1: curb(mb, run); run = []
        if not ok: run = []
finish('Edging_Stream', mb, ['marble'], 'Edging', pivot=False)
for nm, pool in (('Edging_FallsPool', FALLS_POOL), ('Edging_LilyPool', LILY)):
    mb = MB(); run = []
    for k in range(73):
        a = k / 72 * 6.283; X, Z = pool[0] + math.cos(a) * pool[2] * .885, pool[1] + math.sin(a) * pool[3] * .885
        ok = pdist(X, Z, STREAM) > 4.6 and in_garden(X, Z, 1.5)
        if ok: run.append((X, Z))
        if (not ok or k == 72) and len(run) > 1: curb(mb, run)
        if not ok: run = []
    finish(nm, mb, ['marble'], 'Edging', pivot=False)
for sx_b in (-1, 1):
    for sz_b in (-1, 1):
        kit('Bridge_Urn', URN, 'Statues_Urns', BRIDGE[0] + sx_b * 12, BRIDGE[1] + sz_b * 4.6)

# ================================================================== UNDERSIDE (the island floats)
def rim_out(th):
    """Outer edge of the island at angle th: beyond the lip on open sides, behind the wall on walled sides."""
    E = wall_env(th); H = wall_H(th)
    return RIM(th) + E * (24 + (16 + H * .9) * .92) + (1 - E) * ((6 + 5 * g(th, 97, 20)) * 1.08)


def under_depth(X, Z):
    return (20 + 78 * gauss(X + 14, Z + 4, 58) + 46 * gauss(X - 62, Z + 46, 34) + 50 * gauss(X + 62, Z - 10, 32)
            + 30 * gauss(X - 78, Z - 46, 24) + 26 * gauss(X + 6, Z + 78, 26))


SEG = 72; RING = [1.0, 1.02, .93, .82, .68, .52, .36, .2, .08]
mb = MB(); V = []; r_u = random.Random(7)
for j, s in enumerate(RING):
    for i in range(SEG):
        th_ = i * 360 / SEG; Ro = rim_out(th_); rr = Ro * s * (1 + (.07 * (r_u.random() - .5) if j > 1 else 0))
        X, Z = P(th_ + (2.2 * (r_u.random() - .5) if j > 1 else 0), rr)
        if j == 0: hh = -4.2
        elif j == 1: hh = -9.5
        else: hh = -9.5 - under_depth(X, Z) * (1 - s ** 2.0) ** .8 * (1 + .30 * (r_u.random() - .5))
        V.append(B(X, hh, Z))
tips = [(-14, -4), (62, -46), (-62, 10), (78, 46), (-6, -78)]
ct = len(V); V.append(B(-14, -9.5 - under_depth(-14, -4) * 1.12, -4))
F = [[j * SEG + i, j * SEG + (i + 1) % SEG, (j + 1) * SEG + (i + 1) % SEG, (j + 1) * SEG + i] for j in range(len(RING) - 1) for i in range(SEG)]
F += [[(len(RING) - 1) * SEG + i, (len(RING) - 1) * SEG + (i + 1) % SEG, ct] for i in range(SEG)]
def undercol(p, n):
    t = min(1, max(0, -p[2] / 95)); k = (.96 - .30 * t) * (.86 + .22 * abs(n[2])) * (1 + .06 * (_hash(int(p[0] * 3), int(p[1] * 3), 5) - .5))
    return (k * (1.0 - .10 * t), k * (1.0 - .04 * t), k * (.96 + .16 * t))
mb.add(V, F, 0, colfn=undercol, scale=.035)
finish('Underside_Rock', mb, ['cliff_rock'], 'Underside', smooth=False, pivot=False)

# hanging roots / vines along the lip, stalactites and crystals underneath
mb_r = MB(); mb_v = MB()
for k in range(22):
    th_ = r_u.uniform(0, 360); Ro = rim_out(th_) * r_u.uniform(.9, 1.0); X, Z = P(th_, Ro); L = r_u.uniform(7, 22); pts = []
    for q in range(5):
        t = q / 4; pts.append(B(X + math.sin(t * 3 + k) * 1.2 * t, -7 - L * t, Z + math.cos(t * 2.5 + k) * 1.2 * t))
    v, f, uv = tube(pts, [.5 * (1 - .8 * q / 4) + .06 for q in range(5)], 4, seed=k)
    (mb_r if k % 3 else mb_v).add(v, f, 0, uvs=uv)
finish('Underside_HangingRoots', mb_r, ['bark'], 'Underside', smooth=True, pivot=False)
finish('Underside_HangingVines', mb_v, ['foliage'], 'Underside', smooth=True, pivot=False)
mb_s = MB(); mb_c = MB()
for k in range(34):
    th_ = r_u.uniform(0, 360); s = r_u.uniform(.25, .9); X, Z = P(th_, rim_out(th_) * s)
    hh = -9.5 - under_depth(X, Z) * (1 - s ** 2.0) ** .8 * .9; L = r_u.uniform(4, 13); w = L * r_u.uniform(.16, .26)
    v, f, uv = lathe([(.02, -L), (w * .7, -L * .45), (w, .8), (w * .6, 2.2)], 5)
    M = Matrix.Translation(B(X, hh, Z)) @ Euler((r_u.uniform(-.15, .15), r_u.uniform(-.15, .15), r_u.uniform(0, 3))).to_matrix().to_4x4()
    if k % 3 == 0: mb_c.add(v, f, k % 2, uvs=uv, M=M)
    else: mb_s.add(v, f, 0, uvs=uv, M=M, colfn=undercol)
finish('Underside_Stalactites', mb_s, ['cliff_rock'], 'Underside', smooth=False, pivot=False)
finish('Underside_Crystals', mb_c, ['glow_aqua', 'glow_pink'], 'Underside', smooth=False, pivot=False)

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
    if math.hypot(X - ARCH[0], Z - ARCH[1]) < 14 or math.hypot(X - kx, Z - kz) < 40 and height(X, Z) > .6: return False
    if not pet_ok(X, Z) or not in_garden(X, Z, 6): return False
    if any(pdist(X, Z, p) < r for p in ALLPATH): return False
    if any(math.hypot(X - sx, Z - sz) < r + 5 for sx, sz in STATIONS.values()): return False
    return math.hypot(X - HUB[0], Z - HUB[1]) > 27 and pdist(X, Z, STREAM) > 8 and water_clear(X, Z, r)


TREES = [(-62, -24, 1.15, 'round'), (-50, -42, 1.2, 'tall'), (-36, -52, 1.0, 'blossom'), (-70, -44, 1.1, 'round'), (-8, -48, 1.0, 'blossom'),
         (-76, 16, 1.0, 'tall'), (-66, 28, .95, 'blossom'), (-34, 38, 1.1, 'round'), (-28, 56, 1.0, 'tall'), (18, 44, 1.0, 'blossom'),
         (30, 60, 1.15, 'round'), (52, 56, .95, 'tall'), (66, 26, 1.1, 'round'), (74, 12, .9, 'blossom'), (38, 8, 1.0, 'round'),
         (72, -22, 1.15, 'tall'), (38, -62, 1.0, 'blossom'), (76, -40, 1.0, 'round'), (-12, 34, .9, 'blossom'), (100, 44, .95, 'round'),
         (-84, -30, 1.0, 'blossom'), (36, -16, .9, 'tall')]
def water_clear(X, Z, rad):
    """True when nothing within `rad` studs of (X, Z) is water or wet bank."""
    for a_ in range(0, 360, 30):
        for q in (.5, 1.0):
            if height(X + math.cos(math.radians(a_)) * rad * q, Z + math.sin(math.radians(a_)) * rad * q) < 0.0: return False
    return height(X, Z) >= 0.0 and pdist(X, Z, STREAM) > rad + 3.5


TREE_R = {'round': 5.4, 'tall': 3.6, 'blossom': 5.2}                 # canopy radius at scale 1
for n, (X, Z, sc, kind) in enumerate(TREES):
    rad = TREE_R[kind] * sc * 1.1 + 1.0; name = 'Tree_%02d_%s' % (n + 1, kind); ok = water_clear(X, Z, rad); X2, Z2 = X, Z
    if not ok:
        for step in range(1, 10):
            for a_ in range(0, 360, 45):
                X2, Z2 = X + math.cos(math.radians(a_)) * step * 2.5, Z + math.sin(math.radians(a_)) * step * 2.5
                if water_clear(X2, Z2, rad) and in_garden(X2, Z2, rad + 3) and height(X2, Z2) < 1.2 and all(pdist(X2, Z2, p) > 3.5 for p in ALLPATH) \
                        and all(math.hypot(X2 - sx, Z2 - sz) > 7 for sx, sz in STATIONS.values()) and math.hypot(X2 - HUB[0], Z2 - HUB[1]) > 27:
                    ok = True; break
            if ok: break
        if not ok: TREE_LOG['dropped'].append(name); continue
        TREE_LOG['moved'].append([name, [X, Z], [round(X2, 1), round(Z2, 1)]])
    obj(name, TREE[kind], 'Trees', X2, height(X2, Z2), Z2, rot=rnd.uniform(0, 6.28), scale=sc * rnd.uniform(.95, 1.05))
obj('Landmark_BlossomPointTree', TREE['blossom'], 'Landmarks', -100, height(-100, -15), -15, rot=.6, scale=1.7)
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
st_ = [p for p in resample(STREAM, 5) if 26 < p[0] < 40][:3]
for k, (X, Z) in enumerate(st_):                                  # stepping stones to the falls side (players)
    mb = MB(); v, f, uv = lathe([(2.2, -2.4), (2.4, .1), (2.0, .3)], 8, cap_top=True); mb.add(v, f, 0, uvs=uv)
    obj('Prop_SteppingStone_%d' % (k + 1), mb.build('SteppingStone', ['stone_tile']), 'Props', X, WATER + .25, Z, rot=k)
LAMP = lamp_mesh()
for k, (X, Z) in enumerate(LAMPS): obj('Lamp_%d' % (k + 1), LAMP, 'Lamps', X, height(X, Z), Z)

# ================================================================== SKY: islets, drifting rocks, far islands, cloud floor
HAZE = Vector(lin('#CFE9FF'))
C_ISL_G = Vector(lin('#27A836')); C_ISL_R = Vector(lin('#B6AF8E')); C_ISL_M = Vector(lin('#F6F1E6')); C_ISL_T = Vector(lin('#2FB7B0'))
ISLN = [0]


def islet(name, X, h, Z, R, coll, far=False, tree=0, ruin=False, castle=False, seed=0):
    """A small floating island: grass cap, faceted rock underside. far=True -> unlit + hazed for the backdrop."""
    r = random.Random(seed or int(X * 3 + Z)); haze = min(.42, .05 + math.hypot(X, Z) / 4500) if far else 0.0
    def hz(c, lit=1.0):
        c = Vector(c) * lit
        return tuple(c.lerp(HAZE, haze)) if far else tuple(c)
    mb = MB(); sides = 9
    v, f, uv = lathe([(R * 1.0, -.4), (R * .97, .6), (R * .62, 1.0 + R * .04), (.02, 1.2 + R * .06)], sides); v = wobble(v, sides, r.randrange(99), .12)
    mb.add(v, f, 0, uvs=[(a * .4, b) for a, b in uv], colfn=(lambda p, n: hz(C_ISL_G, .86 + .2 * max(0, Vector(n).dot(SUN)))) if far else (lambda p, n: (1, 1, 1)))
    D = R * r.uniform(1.5, 2.3)
    prof = [(R * 1.0, -.4), (R * 1.03, -R * .12), (R * .86, -D * .28), (R * .62, -D * .55), (R * .34, -D * .8), (.02, -D)]
    v, f, uv = lathe(prof[::-1], sides); v = wobble(v, sides, r.randrange(99), .2)
    def rc(p, n):
        k = (.98 - .3 * min(1, -p[2] / max(D, 1))) * (.84 + .22 * max(0, Vector(n).dot(SUN)))
        return hz(C_ISL_R, k) if far else (k * 1.02, k, k * .97)
    mb.add(v, f, 1, uvs=[(a * .5, b * .4) for a, b in uv], colfn=rc)
    if castle or ruin:                                           # generic fairy-tale towers / classical ruin silhouettes
        n_t = 3 if castle else 4
        for k in range(n_t):
            a = k / n_t * 6.283 + .4; rr = R * (.34 if castle else .5); tx, ty = math.cos(a) * rr, math.sin(a) * rr
            th_ = R * (r.uniform(.5, .8) if castle else r.uniform(.2, .42)); tw = R * (.11 if castle else .05)
            v, f, uv = lathe([(tw, .5), (tw * .92, th_), (tw * 1.25, th_ + tw * .3), (tw * 1.25, th_ + tw * .9)] if castle else [(tw * 1.3, .5), (tw, .9), (tw * .9, th_)], 8, cap_top=True)
            mb.add(v, f, 2, uvs=uv, colfn=(lambda p, n: hz(C_ISL_M, .86 + .18 * max(0, Vector(n).dot(SUN)))) if far else None, M=Matrix.Translation((tx, ty, 0)))
            if castle:
                v, f, uv = lathe([(tw * 1.35, th_ + tw * .9), (.02, th_ + tw * 3.4)], 8)
                mb.add(v, f, 3, uvs=uv, colfn=(lambda p, n: hz(C_ISL_T, .9 + .15 * max(0, Vector(n).dot(SUN)))) if far else None, M=Matrix.Translation((tx, ty, 0)))
                zt = th_ + tw * 3.4
                mb.add([(tx, ty, zt), (tx, ty, zt + tw * 2.2), (tx + tw * 2.4, ty, zt + tw * 1.7), (tx, ty, zt + tw * 1.2)], [[0, 1, 2, 3], [3, 2, 1, 0]], 3,
                       colfn=(lambda p, n: hz(Vector(lin('#FF6FAE')))) if far else None)
        if castle:
            v, f, uv = lathe([(R * .44, .4), (R * .42, R * .2), (R * .46, R * .2), (R * .46, R * .26)], 12)
            mb.add(v, f, 2, uvs=uv, colfn=(lambda p, n: hz(C_ISL_M, .84 + .18 * max(0, Vector(n).dot(SUN)))) if far else None)
    mats = ['far_peak'] * 4 if far else ['grass', 'cliff_rock', 'marble', 'teal']
    me = fix_normals(mb.build(name, mats, smooth=False))
    o = obj(name, me, coll, X, h, Z, rot=r.uniform(0, 6.28))
    for k in range(tree):
        a = r.uniform(0, 6.28); rr = R * r.uniform(.1, .5)
        if not far: obj('%s_Tree%d' % (name, k + 1), TREE[('round', 'blossom', 'tall')[k % 3]], coll, X + math.cos(a) * rr, h + 1.0, Z + math.sin(a) * rr, rot=a, scale=min(1.1, R / 11))
    return o


for nm, X, hh, Z, R_, tr, ru in [('Islet_Near_East', 168, 14, 22, 15, 2, False), ('Islet_Near_South', 28, -12, 150, 20, 2, True), ('Islet_Near_SouthWest', -112, 6, 128, 11, 1, False),
                                 ('Islet_Near_West', -176, 24, -30, 17, 2, False), ('Islet_Near_NorthWest', -150, 44, -128, 12, 1, False), ('Islet_Near_SouthEast', 150, -22, 118, 9, 1, False),
                                 ('Islet_Near_FarSouth', -40, -34, 215, 26, 3, True)]:
    islet(nm, X, hh, Z, R_, 'Sky_Islets', tree=tr, ruin=ru)
for k in range(14):                                               # drifting rocks
    a = r_u.uniform(0, 6.283); d_ = r_u.uniform(135, 250); sz = r_u.uniform(2.5, 8)
    o = crag(math.cos(a) * d_, math.sin(a) * d_, sz, 0, base=-sz * 1.4, coll='Sky_Islets', bare=True); o.name = 'Drifting_Rock_%02d' % (k + 1)
    o.location.z += r_u.uniform(-30, 45)
for k, (X, hh, Z, R_, cs) in enumerate([(-420, 60, -620, 120, True), (380, 20, -700, 150, False), (760, 90, -180, 130, False), (700, -10, 420, 160, True), (-760, 40, 120, 140, False),
                                        (-560, -30, 620, 170, False), (120, 30, 900, 190, False), (-1000, 120, -500, 200, False), (1050, 60, -640, 210, True), (240, 140, -1150, 220, False)]):
    islet('Distant_Island_%02d' % (k + 1), X, hh, Z, R_, 'Distant', far=True, castle=cs, ruin=not cs and k % 2 == 0, seed=40 + k)
for k in range(20):                                               # clouds around the island
    a = k / 20 * 6.283 + rnd.uniform(-.1, .1); d_ = rnd.uniform(300, 1150)
    cloud('Distant_Cloud_%02d' % (k + 1), math.cos(a) * d_, rnd.uniform(40, 330), math.sin(a) * d_, rnd.uniform(38, 95), 900 + k)
for k in range(46):                                               # the cloud floor far below
    a = rnd.uniform(0, 6.283); d_ = 1250 * math.sqrt(rnd.uniform(.0, 1))
    cloud('CloudFloor_%02d' % (k + 1), math.cos(a) * d_, rnd.uniform(-300, -235) - d_ * .03, math.sin(a) * d_, rnd.uniform(70, 150), 1000 + k)
for k in range(16):                                               # cloud banks on the horizon
    a = k / 16 * 6.283 + .1
    cloud('CloudBank_%02d' % (k + 1), math.cos(a) * 1500, rnd.uniform(-160, -40), math.sin(a) * 1500, rnd.uniform(170, 260), 1100 + k)
for k, (X, hh, Z, sc) in enumerate([(150, -70, -150, 34), (230, -50, 120, 26), (-90, -90, -210, 36), (-250, 30, -40, 22), (230, 60, -90, 24), (60, -150, 40, 40), (-80, -165, -40, 44)]):
    cloud('Cloud_Near_%d' % (k + 1), X, hh, Z, sc, 950 + k)

# ================================================================== SKY + LIGHT
world = bpy.data.worlds.new('W1v4_Sky'); scene.world = world; world.use_nodes = True
nt = world.node_tree
for n in list(nt.nodes): nt.nodes.remove(n)
out = nt.nodes.new('ShaderNodeOutputWorld'); bg = nt.nodes.new('ShaderNodeBackground')
tc = nt.nodes.new('ShaderNodeTexCoord'); sep = nt.nodes.new('ShaderNodeSeparateXYZ'); rampn = nt.nodes.new('ShaderNodeValToRGB')
mp = nt.nodes.new('ShaderNodeMapRange'); mp.inputs[1].default_value = -1; mp.inputs[2].default_value = 1
nt.links.new(tc.outputs['Generated'], sep.inputs[0]); nt.links.new(sep.outputs['Z'], mp.inputs[0]); nt.links.new(mp.outputs[0], rampn.inputs[0])
cr = rampn.color_ramp
stops = [(.0, '#58B4F2'), (.32, '#8FD3F8'), (.47, '#D9F1F7'), (.505, '#FFF3DC'), (.56, '#9FE0FB'), (.68, '#3FB8F6'), (.85, '#1E96EE'), (1.0, '#1280E2')]
cr.elements[0].position = stops[0][0]; cr.elements[0].color = (*lin(stops[0][1]), 1)
cr.elements[1].position = stops[-1][0]; cr.elements[1].color = (*lin(stops[-1][1]), 1)
for p_, c_ in stops[1:-1]:
    e = cr.elements.new(p_); e.color = (*lin(c_), 1)
nt.links.new(rampn.outputs[0], bg.inputs[0]); bg.inputs[1].default_value = 1.0; nt.links.new(bg.outputs[0], out.inputs[0])
sun = bpy.data.lights.new('Sun', 'SUN'); sun.energy = 3.5; sun.color = (1.0, .97, .90)
try: sun.angle = math.radians(2)
except Exception: pass
so = bpy.data.objects.new('Sun', sun); so.rotation_euler = (-SUN).to_track_quat('-Z', 'Y').to_euler(); so.location = (0, 0, 120); COL['Sky_Lighting'].objects.link(so)
fill = bpy.data.lights.new('SkyFill', 'SUN'); fill.energy = .55; fill.color = (.7, .86, 1.0)
try: fill.use_shadow = False
except Exception: pass
fo = bpy.data.objects.new('SkyFill', fill); fo.rotation_euler = Vector((-.5, -.6, -.6)).to_track_quat('-Z', 'Y').to_euler(); fo.location = (20, 0, 120); COL['Sky_Lighting'].objects.link(fo)

# ================================================================== REF
avatar('REF_Avatar_5p5_Hub', HUB[0] + 5, HUB[1] + 4, rot=.4)
avatar('REF_Avatar_5p5_Arrival', 58, 30, rot=2.4)
avatar('REF_Avatar_5p5_Knoll', kx + rdx * 13, kz + rdz * 13, rot=1.2)
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
cam('Cam_01_Overview', (-150, 175, 250), (-8, -4, 12), 30)                 # same framing as v1 / v2
cam('Cam_02_SpawnView', (100, height(100, 69) + 5.0, 69), (40, 11, 22), 20)
cam('Cam_03_Hub', (-14, 11, 24), (-33, 5.5, -12), 22)
cam('Cam_04_TumbleFalls', (40, 12, -34), (fx * (Rf + 6), 22, fz * (Rf + 6)), 20)
cam('Cam_05_Distant', (-92, 6.5, 0), (-330, 16, 60), 22)
cam('Cam_06_Scale', (HUB[0] + 7, 3.0, HUB[1] + 15), (HUB[0] + 2.5, 3.0, HUB[1] - 2), 30)
cam('Cam_07_GlowGrotto', (-24, 6.5, -44), (gx * (Rg + 4), 7, gz * (Rg + 4)), 24)
cam('Cam_08_SkyFalls', (26, 5, 122), sp_(SPOUT_END + 1, -10), 26)
cam('Cam_09_TopDownMap', (0, 420, 0), (0, 0, -.1), 50)
cam('Cam_10_KnollRotunda', (-24, 8, 20), (kx, 13, kz), 24)
cam('Cam_11_MarbleArch', (63, 6.5, 41), (ARCH[0], 8.5, ARCH[1]), 26)
cam('Cam_12_Underside', (-170, -95, 205), (0, -30, 0), 24)
cam('Cam_13_SideFloating', (30, 6, 380), (0, -34, 0), 28)
cam('Cam_14_PlazaCloseUp', (HUB[0] + 4, 15, HUB[1] + 30), (HUB[0] - 1, 3.5, HUB[1] - 6), 24)
cam('Cam_15_TumbleFallsLower', (58, 6, -44), (fx * (Rf + 1), 9, fz * (Rf + 1)), 24)
cam('Cam_16_Bridge', (17, 7, 37), (4, 1.2, 21), 26)
cam('Cam_17_RockTexture', (-50, 6, -28), (-70, 9, -52), 28)
cam('Cam_18_WaterClear', (25, 6.5, 8), (13, -1.5, -8), 28)
cam('Cam_19_MarbleTrim', (HUB[0] - 14, 7.0, HUB[1] + 1), (HUB[0] + math.cos(math.radians(244)) * 23, 9.6, HUB[1] + math.sin(math.radians(244)) * 23), 30)
for o in list(COL['Sky_Lighting'].objects):
    if o.type == 'CAMERA': COL['Sky_Lighting'].objects.unlink(o); COL['Cameras'].objects.link(o)
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

# ================================================================== WATER CHECK: nothing may stand in or over water
bpy.context.view_layer.update()
wm_ = bpy.data.objects['Water_StreamAndPools'].data
WCELLS = []
for p in wm_.polygons:
    xs = [wm_.vertices[i].co.x for i in p.vertices]; ys = [wm_.vertices[i].co.y for i in p.vertices]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    if min(height(x, -y) for x in (x0, (x0 + x1) / 2, x1) for y in (y0, (y0 + y1) / 2, y1)) < WATER - .02:   # visible water only
        WCELLS.append((x0, x1, y0, y1))
for nm in ('Water_SkyFalls_Channel',):
    m2 = bpy.data.objects[nm].data; xs = [v.co.x for v in m2.vertices]; ys = [v.co.y for v in m2.vertices]; WCELLS.append((min(xs), max(xs), min(ys), max(ys)))
EXEMPT = ('Edging_', 'Bridge_Main_Marble', 'Prop_SteppingStone', 'Landmark_SkyFalls_MarbleSpout', 'Landmark_TumbleFalls', 'Aqueduct_', 'Underside_', 'Ground_', 'Path_')
CHECK_COLS = ['Trees', 'Bushes', 'Flowers', 'Lamps', 'Props', 'Rocks_Shore', 'Rocks_Field', 'Stations', 'Statues_Urns', 'Ruins', 'Colonnade', 'Plaza', 'Stairs',
              'Balustrades', 'MarbleArch', 'Rotunda', 'Landmarks', 'Bridge', 'Edging']


WSET = {(math.floor((x0 + x1) / 2 / 3.0), math.floor((y0 + y1) / 2 / 3.0)) for (x0, x1, y0, y1) in WCELLS[:-1]}
CH = WCELLS[-1]


def water_hits(o):
    """Number of this object's vertices that sit over visible water (world XY), ignoring parts high overhead."""
    mw = o.matrix_world; n = 0
    for v in o.data.vertices:
        p = mw @ v.co
        if p.z > 14: continue
        if (math.floor(p.x / 3.0), math.floor(p.y / 3.0)) in WSET or (CH[0] < p.x < CH[1] and CH[2] < p.y < CH[3]): n += 1
    return n


def run_check():
    out = []
    for cn in CHECK_COLS:
        for o in COL[cn].objects:
            if o.type != 'MESH' or o.name.startswith(EXEMPT): continue
            n = water_hits(o)
            if n: out.append((cn, o.name, n))
    return out


first = run_check(); removed = []
for cn, name, n in first:
    if cn in ('Trees', 'Bushes', 'Flowers', 'Lamps', 'Rocks_Shore', 'Rocks_Field', 'Statues_Urns', 'Ruins'):
        bpy.data.objects.remove(bpy.data.objects[name], do_unlink=True); removed.append(name)
final = run_check()
n_checked = sum(1 for cn in CHECK_COLS for o in COL[cn].objects if o.type == 'MESH' and not o.name.startswith(EXEMPT))
WATER_CHECK = {'visible_water_cells': len(WCELLS), 'objects_checked_after_cleanup': n_checked, 'trees_checked': len([o for o in COL['Trees'].objects]),
               'trees_moved_at_placement': TREE_LOG['moved'], 'trees_dropped_at_placement': TREE_LOG['dropped'],
               'overlaps_found_first_pass': [list(x) for x in first], 'auto_removed': removed, 'overlaps_remaining': [list(x) for x in final],
               'exempt_by_design': ['Edging_* (the marble kerbs that line the water)', 'Bridge_Main_Marble (deck over the stream)', 'Prop_SteppingStone_* (in the stream on purpose)', 'marble spout, falls rock face and lips, aqueduct'],
               'method': 'every vertex of every object (world XY, below 14 studs) tested against every visible cell of Water_StreamAndPools and the Sky Falls channel'}
json.dump(WATER_CHECK, open(os.path.join(HERE, 'water-check.json'), 'w'), indent=1)
print('WATERCHECK', json.dumps({k_: v_ for k_, v_ in WATER_CHECK.items() if k_ not in ('exempt_by_design', 'method')}))

# ================================================================== CLEAN-UP for hand editing
KEEP_INSTANCED = ('Trees', 'Bushes', 'Flowers')                   # linked duplicates on purpose: edit one, all update
applied = 0
for o in scene.objects:
    if o.type != 'MESH': continue
    cn = o.users_collection[0].name
    if cn in KEEP_INSTANCED or cn == 'REF' or o.parent is not None: continue
    if o.data.name.startswith('Tree_') and o.data.users > 1: continue
    rs = o.matrix_world.to_3x3().to_4x4()
    if max(abs(rs[i][j] - (1 if i == j else 0)) for i in range(3) for j in range(3)) < 1e-7: continue
    if o.data.users > 1: o.data = o.data.copy()
    o.data.transform(rs); o.data.name = o.name
    loc = o.matrix_world.to_translation(); o.matrix_world = Matrix.Translation(loc); applied += 1
for me in list(bpy.data.meshes):
    if me.users == 0: bpy.data.meshes.remove(me)
for m in list(bpy.data.materials):
    if m.users == 0: bpy.data.materials.remove(m)
for im in list(bpy.data.images):
    if im.users == 0: bpy.data.images.remove(im)
for o in scene.objects:                                            # unique meshes carry their object's name
    if o.type == 'MESH' and o.data.users == 1: o.data.name = o.name
for c in list(bpy.data.collections):
    if not c.objects and not c.children: bpy.data.collections.remove(c)
print('CLEANUP applied rotation/scale on', applied, 'objects')

# ================================================================== STATS
vis = 0; per = {}
PARENTS = ('Walls_Rocks', 'Props', 'Architecture')
for o in scene.objects:
    if o.type != 'MESH': continue
    t = tri_count(o.data); top = o.users_collection[0].name
    for pn in PARENTS:
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
stats = {'triangles_visible_total': vis, 'triangles_without_REF': vis - per.get('REF', 0), 'triangles_island_only': vis - per.get('REF', 0) - per.get('Distant', 0) - per.get('Sky_Islets', 0),
         'triangles_by_collection': per, 'triangles_unique_mesh_data': sum(tri_count(m) for m in bpy.data.meshes if m.users),
         'objects': len(scene.objects), 'garden_floor_area_sq_studs': round(a_g), 'pet_walkable_area_sq_studs': round(a_pet),
         'spawn_to_hub_path_studs': round(walk), 'spawn_to_hub_seconds_at_16': round(walk / 16, 1),
         'underside_lowest_point_studs': round(min(v.co.z for v in bpy.data.objects['Underside_Rock'].data.vertices), 1),
         'stations': STATIONS, 'hatch_tree': HATCH_TREE, 'hub_centre': HUB, 'chime_arch': ARCH, 'bridge': BRIDGE, 'knoll_rotunda': KNOLL[:2], 'bridge_deck_top_above_lawn': .34,
         'falls_foot': [round(fx * Rf, 1), round(fz * Rf, 1)], 'sky_falls_lip': [round(sp_(SPOUT_END, 0)[0], 1), round(sp_(SPOUT_END, 0)[2], 1)],
         'grotto_mouth': [round(gx * Rg, 1), round(gz * Rg, 1)], 'lamps': LAMPS,
         'station_heights': {k_: round(height(*v_), 3) for k_, v_ in STATIONS.items()},
         'transforms': 'rotation and scale applied on every mesh except linked-duplicate vegetation (Trees, Bushes, Flowers, islet trees) and the REF bears',
         'origin_note': 'Blender (x,y,z) = Roblox (X, -Z, Y-4); 1 unit = 1 stud'}
json.dump(stats, open(os.path.join(HERE, 'stats.json'), 'w'), indent=1)
print('STATS', json.dumps({k_: v_ for k_, v_ in stats.items() if k_ not in ('stations', 'lamps', 'station_heights')}))
bpy.ops.wm.save_as_mainfile(filepath=OUT, relative_remap=True)
try:
    for img in bpy.data.images:
        if img.filepath: img.filepath = bpy.path.relpath(img.filepath)
    bpy.ops.wm.save_mainfile()
except Exception as e: print('relpath:', e)
print('BUILD_OK', OUT)
