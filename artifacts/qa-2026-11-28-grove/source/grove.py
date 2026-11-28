"""Hidden-grove art-direction mockup around the real v7 island (headless Blender, Cycles).
blender -b --factory-startup --python grove.py -- <before|grove> <day|night> <out_dir> <res_x> <samples> cam1,cam2
Units are studs. Blender (x, y, z) = Roblox (x, -z, y - 4). All geometry and materials are procedural (no image generators)."""
import bpy, bmesh, sys, math, random
from mathutils import Vector, noise
import os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import island

A = sys.argv[sys.argv.index("--") + 1:]
MODE, TIME, OUT, RES, SAMPLES, CAMS = A[0], A[1], A[2], int(A[3]), int(A[4]), A[5].split(",")
NIGHT = TIME == "night"
random.seed(7)
CX, CY = 12.0, 8.0
TAU = math.tau


def S(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def n1(theta, k, f=1.0):  # smooth periodic noise in -1..1
    return noise.noise(Vector((math.cos(theta) * f * 1.7 + k * 9.1, math.sin(theta) * f * 1.7 - k * 4.3, k * 2.7)))


def rin(theta):
    a, b, n = 122.0, 106.0, 2.6
    c, s = abs(math.cos(theta)), abs(math.sin(theta))
    return (c ** n / a ** n + s ** n / b ** n) ** (-1 / n)


FALLS = [0.55, 2.35, 3.75, 5.35]  # angles of the gorges with waterfalls
SUN_GATE = 5.0  # the gap in the giants where the light comes through (south-east)


def levels(theta):
    g = max(math.exp(-((math.atan2(math.sin(theta - f), math.cos(theta - f))) / .09) ** 2) for f in FALLS)
    w1 = 30 + 9 * n1(theta, 1, 2) + 10 * g
    L1 = 30 + 12 * n1(theta, 2, 3)
    led1 = 20 + 12 * n1(theta, 3, 3)
    L2 = L1 + 46 + 14 * n1(theta, 4, 2)
    led2 = 26 + 12 * n1(theta, 5, 3)
    L3 = L2 + 48 + 18 * n1(theta, 6, 2)
    return w1, L1, led1, L2, led2, L3, g


def height(theta, d, x, y):
    w1, L1, led1, L2, led2, L3, g = levels(theta)
    d = d + 7 * noise.noise(Vector((x / 60, y / 60, 3.3)))
    # the moat round the garden terrace
    if d < w1:
        t = d / w1
        z = -3 - 9.5 * max(0.0, math.sin(math.pi * max(0.0, min(1, t * 1.15)))) ** .8 + 3 * S((t - .7) / .3)
    else:
        z = 0
    a1, a2, a3 = w1, w1 + 13 + led1, w1 + 13 + led1 + 17 + led2
    z += L1 * S((d - a1) / 13) + (L2 - L1) * S((d - a2) / 17) + (L3 - L2) * S((d - a3) / 22)
    if d > a3 + 22:
        z += 22 * noise.noise(Vector((x / 90, y / 90, 1.0))) + (d - a3 - 22) * .12
    # strata: partial quantising on the walls gives stepped ledges
    wall = max(S((d - a1) / 6) * (1 - S((d - a1 - 13) / 5)), S((d - a2) / 6) * (1 - S((d - a2 - 17) / 5)),
               S((d - a3) / 6) * (1 - S((d - a3 - 22) / 5)))
    if wall > 0:
        q = round(z / 9) * 9
        z = z + (q - z) * .55 * wall
        z += 5 * wall * noise.cell(Vector((x / 16, y / 16, z / 30)))
    z += 1.6 * noise.noise(Vector((x / 14, y / 14, 7.0))) * S(d / 20)
    return z


def ground(theta, d):
    r = rin(theta) + d
    x, y = CX + r * math.cos(theta), CY + r * math.sin(theta)
    return Vector((x, y, height(theta, d, x, y)))


# ---------- mesh helpers ----------
class Mesh:
    def __init__(self):
        self.v, self.f = [], []

    def add(self, verts, faces):
        o = len(self.v)
        self.v.extend(verts)
        self.f.extend(tuple(i + o for i in f) for f in faces)

    def obj(self, name, mat, smooth=False):
        me = bpy.data.meshes.new(name)
        me.from_pydata([tuple(v) for v in self.v], [], self.f)
        me.update()
        if smooth:
            for p in me.polygons:
                p.use_smooth = True
        o = bpy.data.objects.new(name, me)
        o.data.materials.append(mat)
        bpy.context.scene.collection.objects.link(o)
        return o


def tube(spine, radii, segs=14, lobes=0, lobe_amp=None):
    verts, faces = [], []
    n = len(spine)
    for i, p in enumerate(spine):
        t = (spine[min(i + 1, n - 1)] - spine[max(i - 1, 0)]).normalized()
        ref = Vector((0, 0, 1)) if abs(t.z) < .9 else Vector((1, 0, 0))
        u = t.cross(ref).normalized()
        w = t.cross(u)
        for k in range(segs):
            a = TAU * k / segs
            r = radii[i]
            if lobes and lobe_amp:
                r *= 1 + lobe_amp[i] * (.5 + .5 * math.cos(lobes * a + i * .15)) ** 2
            verts.append(p + (u * math.cos(a) + w * math.sin(a)) * r)
    for i in range(n - 1):
        for k in range(segs):
            a, b = i * segs + k, i * segs + (k + 1) % segs
            faces.append((a, b, b + segs, a + segs))
    verts.append(spine[-1]); top = len(verts) - 1
    for k in range(segs):
        faces.append(((n - 1) * segs + k, (n - 1) * segs + (k + 1) % segs, top))
    return verts, faces


def unit_ico(sub):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=1)
    v = [x.co.copy() for x in bm.verts]
    f = [tuple(x.index for x in face.verts) for face in bm.faces]
    bm.free()
    return v, f


ICO3, ICO2, ICO1 = unit_ico(3), unit_ico(2), unit_ico(1)


def blob(c, r, squash=.6, ico=ICO3, amp=.28, freq=.09):
    out = []
    for v in ico[0]:
        k = 1 + amp * noise.noise((c + v * r) * freq * 2.2) + amp * .5 * noise.noise((c + v * r) * freq * 6)
        out.append(c + Vector((v.x * r * k, v.y * r * k, v.z * r * k * squash)))
    return out, ico[1]


# ---------- materials ----------
def new_mat(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    return m, m.node_tree, island.bsdf(m)


def node(nt, t, **kw):
    n = nt.nodes.new(t)
    for k, v in kw.items():
        if k in n.inputs:
            n.inputs[k].default_value = v
        else:
            setattr(n, k, v)
    return n


def ramp(nt, stops):
    r = nt.nodes.new("ShaderNodeValToRGB")
    e = r.color_ramp.elements
    while len(e) < len(stops):
        e.new(.5)
    for el, (p, c) in zip(e, stops):
        el.position = p
        el.color = (*c, 1)
    return r


def coords(nt, scale=(1, 1, 1)):
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = scale
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    return mp.outputs["Vector"]


def mat_stone():
    m, nt, b = new_mat("GroveStoneMoss")
    L = nt.links.new
    co = coords(nt)
    # clean pale blue-white limestone, crisp cracks
    vor = node(nt, "ShaderNodeTexVoronoi", feature="DISTANCE_TO_EDGE", Scale=.13)
    L(coords(nt, (1, 1, .45)), vor.inputs["Vector"])
    crack = ramp(nt, [(0, (.42, .5, .58)), (.06, (.78, .84, .88)), (1, (.9, .93, .93))])
    L(vor.outputs["Distance"], crack.inputs["Fac"])
    nz = node(nt, "ShaderNodeTexNoise", Scale=.035, Detail=6.0)
    L(coords(nt, (1, 1, 3.5)), nz.inputs["Vector"])
    tone = ramp(nt, [(.3, (.50, .60, .70)), (.5, (.72, .76, .78)), (.7, (.80, .76, .66))])
    L(nz.outputs["Fac"], tone.inputs["Fac"])
    mul = node(nt, "ShaderNodeMixRGB", blend_type="MULTIPLY"); mul.inputs["Fac"].default_value = 1
    L(crack.outputs["Color"], mul.inputs["Color1"]); L(tone.outputs["Color"], mul.inputs["Color2"])
    # fresh moss and grass on anything facing up
    gn = node(nt, "ShaderNodeTexNoise", Scale=.5, Detail=8.0)
    L(co, gn.inputs["Vector"])
    moss = ramp(nt, [(.3, (.10, .50, .10)), (.5, (.25, .70, .12)), (.72, (.55, .88, .2))])
    L(gn.outputs["Fac"], moss.inputs["Fac"])
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ"); L(geo.outputs["Normal"], sep.inputs[0])
    edge = node(nt, "ShaderNodeTexNoise", Scale=.12, Detail=4.0); L(co, edge.inputs["Vector"])
    add = node(nt, "ShaderNodeMath", operation="ADD"); L(sep.outputs["Z"], add.inputs[0])
    sc = node(nt, "ShaderNodeMath", operation="MULTIPLY"); sc.inputs[1].default_value = .35
    L(edge.outputs["Fac"], sc.inputs[0]); L(sc.outputs[0], add.inputs[1])
    mask = ramp(nt, [(.68, (0, 0, 0)), (.82, (1, 1, 1))]); L(add.outputs[0], mask.inputs["Fac"])
    mix = node(nt, "ShaderNodeMixRGB"); L(mask.outputs["Color"], mix.inputs["Fac"])
    L(mul.outputs["Color"], mix.inputs["Color1"]); L(moss.outputs["Color"], mix.inputs["Color2"])
    L(mix.outputs["Color"], b.inputs["Base Color"])
    bump = node(nt, "ShaderNodeBump", Strength=.6, Distance=1.5)
    hsum = node(nt, "ShaderNodeMath", operation="ADD"); L(vor.outputs["Distance"], hsum.inputs[0]); L(gn.outputs["Fac"], hsum.inputs[1])
    L(hsum.outputs[0], bump.inputs["Height"]); L(bump.outputs["Normal"], b.inputs["Normal"])
    b.inputs["Roughness"].default_value = .82
    return m


def mat_bark():
    m, nt, b = new_mat("GroveBark")
    L = nt.links.new
    wv = node(nt, "ShaderNodeTexNoise", Scale=1.0, Detail=5.0)
    L(coords(nt, (.55, .55, .035)), wv.inputs["Vector"])
    col = ramp(nt, [(.32, (.30, .19, .12)), (.5, (.56, .40, .26)), (.68, (.80, .64, .44))])
    L(wv.outputs["Fac"], col.inputs["Fac"])
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ"); L(geo.outputs["Normal"], sep.inputs[0])
    mn = node(nt, "ShaderNodeTexNoise", Scale=.2, Detail=5.0); L(coords(nt), mn.inputs["Vector"])
    add = node(nt, "ShaderNodeMath", operation="ADD"); L(sep.outputs["Z"], add.inputs[0]); L(mn.outputs["Fac"], add.inputs[1])
    mask = ramp(nt, [(.95, (0, 0, 0)), (1.1, (1, 1, 1))]); L(add.outputs[0], mask.inputs["Fac"])
    mix = node(nt, "ShaderNodeMixRGB"); L(mask.outputs["Color"], mix.inputs["Fac"])
    L(col.outputs["Color"], mix.inputs["Color1"]); mix.inputs["Color2"].default_value = (.3, .72, .14, 1)
    L(mix.outputs["Color"], b.inputs["Base Color"])
    bump = node(nt, "ShaderNodeBump", Strength=.9, Distance=1.2)
    L(wv.outputs["Fac"], bump.inputs["Height"]); L(bump.outputs["Normal"], b.inputs["Normal"])
    b.inputs["Roughness"].default_value = .85
    return m


def mat_leaf(name, stops, trans):
    m, nt, b = new_mat(name)
    L = nt.links.new
    co = coords(nt)
    vor = node(nt, "ShaderNodeTexVoronoi", Scale=.8, Randomness=1.0)
    L(co, vor.inputs["Vector"])
    big = node(nt, "ShaderNodeTexNoise", Scale=.045, Detail=3.0); L(co, big.inputs["Vector"])
    cell = node(nt, "ShaderNodeSeparateXYZ"); L(vor.outputs["Color"], cell.inputs[0])
    mx = node(nt, "ShaderNodeMath", operation="ADD"); L(cell.outputs["X"], mx.inputs[0]); L(big.outputs["Fac"], mx.inputs[1])
    hf = node(nt, "ShaderNodeMath", operation="MULTIPLY"); hf.inputs[1].default_value = .5; L(mx.outputs[0], hf.inputs[0])
    col = ramp(nt, stops); L(hf.outputs[0], col.inputs["Fac"])
    # darker creases between leaves
    cr = ramp(nt, [(0, (1, 1, 1)), (.55, (1, 1, 1)), (1, (.45, .6, .45))]); L(vor.outputs["Distance"], cr.inputs["Fac"])
    mul = node(nt, "ShaderNodeMixRGB", blend_type="MULTIPLY"); mul.inputs["Fac"].default_value = 1
    L(col.outputs["Color"], mul.inputs["Color1"]); L(cr.outputs["Color"], mul.inputs["Color2"])
    L(mul.outputs["Color"], b.inputs["Base Color"])
    bump = node(nt, "ShaderNodeBump", Strength=1.0, Distance=1.2, invert=True)
    L(vor.outputs["Distance"], bump.inputs["Height"]); L(bump.outputs["Normal"], b.inputs["Normal"])
    b.inputs["Roughness"].default_value = .55
    tr = nt.nodes.new("ShaderNodeBsdfTranslucent"); L(mul.outputs["Color"], tr.inputs["Color"])
    ms = nt.nodes.new("ShaderNodeMixShader"); ms.inputs[0].default_value = trans
    out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
    L(b.outputs[0], ms.inputs[1]); L(tr.outputs[0], ms.inputs[2]); L(ms.outputs[0], out.inputs["Surface"])
    return m


def mat_water():
    m, nt, b = new_mat("GroveWater")
    L = nt.links.new
    vor = node(nt, "ShaderNodeTexVoronoi", feature="DISTANCE_TO_EDGE", Scale=.26)
    warp = node(nt, "ShaderNodeTexNoise", Scale=.05, Detail=2.0); co = coords(nt); L(co, warp.inputs["Vector"])
    mixv = node(nt, "ShaderNodeMixRGB"); mixv.inputs["Fac"].default_value = .25
    L(co, mixv.inputs["Color1"]); L(warp.outputs["Color"], mixv.inputs["Color2"]); L(mixv.outputs["Color"], vor.inputs["Vector"])
    net = ramp(nt, [(0, (.75, 1, 1)), (.05, (.1, .75, .78)), (.4, (.03, .5, .6))]); L(vor.outputs["Distance"], net.inputs["Fac"])
    L(net.outputs["Color"], b.inputs["Base Color"]); L(net.outputs["Color"], b.inputs["Emission Color"])
    b.inputs["Emission Strength"].default_value = 1.6 if NIGHT else .55
    b.inputs["Roughness"].default_value = .06
    return m


def mat_fall():
    m, nt, b = new_mat("GroveFall")
    L = nt.links.new
    wv = node(nt, "ShaderNodeTexNoise", Scale=1.0, Detail=3.0)
    L(coords(nt, (.7, .7, .03)), wv.inputs["Vector"])
    a = ramp(nt, [(.3, (.15, .15, .15)), (.6, (1, 1, 1))]); L(wv.outputs["Fac"], a.inputs["Fac"])
    b.inputs["Base Color"].default_value = (.85, .97, 1, 1)
    b.inputs["Emission Color"].default_value = (.7, .95, 1, 1)
    b.inputs["Emission Strength"].default_value = 2.2 if NIGHT else .9
    L(a.outputs["Color"], b.inputs["Alpha"])
    b.inputs["Roughness"].default_value = .2
    return m


def mat_flat(name, c, rough=.7, emit=0.0, ec=None):
    m, nt, b = new_mat(name)
    b.inputs["Base Color"].default_value = (*c, 1)
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = (*(ec or c), 1)
        b.inputs["Emission Strength"].default_value = emit
    return m


def mat_bubble():
    m, nt, b = new_mat("GroveBubble")
    L = nt.links.new
    out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
    gl = node(nt, "ShaderNodeBsdfGlossy", Roughness=.02)
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    lw = node(nt, "ShaderNodeLayerWeight", Blend=.35)
    rm = ramp(nt, [(0, (.03, .03, .03)), (.55, (.12, .12, .12)), (1, (.9, .9, .9))]); L(lw.outputs["Facing"], rm.inputs["Fac"])
    tint = ramp(nt, [(0, (.7, 1, 1)), (.5, (1, .8, 1)), (1, (.8, 1, .8))]); L(lw.outputs["Facing"], tint.inputs["Fac"])
    L(tint.outputs["Color"], gl.inputs["Color"])
    ms = nt.nodes.new("ShaderNodeMixShader"); L(rm.outputs["Color"], ms.inputs[0]); L(tr.outputs[0], ms.inputs[1]); L(gl.outputs[0], ms.inputs[2])
    L(ms.outputs[0], out.inputs["Surface"])
    return m


# ---------- the grove ----------
LIGHTS = []
STONE = []


def build_grove():
    stone, bark = STONE[0], mat_bark()
    leaf = mat_leaf("GroveLeaf", [(.25, (.04, .36, .10)), (.5, (.14, .60, .12)), (.78, (.50, .88, .16))], .3)
    leaf2 = mat_leaf("GroveLeafLime", [(.25, (.16, .55, .10)), (.5, (.42, .82, .14)), (.78, (.78, .96, .30))], .35)
    fern = mat_leaf("GroveFern", [(.25, (.10, .55, .20)), (.5, (.22, .75, .28)), (.78, (.55, .95, .40))], .3)
    wood = mat_flat("GroveWood", (.66, .47, .28), .7)
    cream = mat_flat("GroveCream", (.97, .95, .88), .35)
    roof = mat_flat("GroveRoof", (.12, .72, .78), .22)
    rope = mat_flat("GroveRope", (.80, .68, .46), .9)
    warm = mat_flat("GroveLampWarm", (1, .86, .5), .3, 14 if NIGHT else 2.5, (1, .78, .36))
    aqua = mat_flat("GroveLampAqua", (.5, .95, 1), .3, 12 if NIGHT else 2.5, (.3, .9, 1))
    mote = mat_flat("GroveMote", (1, 1, .8), .3, 30 if NIGHT else 6, (1, .95, .6) if NIGHT else (1, 1, .85))

    # 1. the hollow: moat, three cliff bands with ledges, the forest rim
    T = Mesh()
    NT, ds = 300, [-10 + i * 2.2 for i in range(96)] + [201 + i * 9 for i in range(1, 22)]
    for j in range(NT):
        th = TAU * j / NT
        for d in ds:
            T.v.append(ground(th, d))
    nd = len(ds)
    for j in range(NT):
        for i in range(nd - 1):
            a, b = j * nd + i, ((j + 1) % NT) * nd + i
            T.f.append((a, b, b + 1, a + 1))
    T.obj("GroveHollow", stone)

    # 2. rock spires and stacks for vertical accents
    R = Mesh()
    for _ in range(46):
        th = random.uniform(0, TAU)
        d = random.choice([random.uniform(8, 26), random.uniform(48, 62), random.uniform(98, 118)])
        base = ground(th, d)
        h = random.uniform(14, 46) if d < 30 else random.uniform(22, 60)
        r = random.uniform(4, 9)
        lean = Vector((random.uniform(-3, 3), random.uniform(-3, 3), 0))
        spine = [base + Vector((0, 0, -6)) + lean * (k / 5) + Vector((0, 0, (h + 6) * k / 5)) for k in range(6)]
        rad = [r * (1.15 - .09 * k * k / 5 + .12 * math.sin(k * 2.1 + th * 7)) for k in range(6)]
        R.add(*tube(spine, rad, segs=7))
    R.obj("GroveSpires", stone)

    # 3. the old giants: roots, trunks, boughs, crowns that lean in over the rim
    TR, CR, CR2, V = Mesh(), Mesh(), Mesh(), Mesh()
    giants = []
    angs = [.2, .95, 1.55, 2.1, 2.75, 3.35, 3.95, 4.38, 5.95]  # none at the sun gate (about 5.0)
    for th in angs:
        th += random.uniform(-.08, .08)
        d = random.uniform(30, 52)
        base = ground(th, d)
        H = random.uniform(165, 205)
        r0 = random.uniform(8, 11.5)
        inward = Vector((-math.cos(th), -math.sin(th), 0))
        side = Vector((-inward.y, inward.x, 0))
        bend = random.uniform(4, 12)
        sw = random.uniform(-10, 10)
        N = 14
        spine, rad, amp = [], [], []
        for k in range(N):
            t = k / (N - 1)
            spine.append(base + Vector((0, 0, -8 + (H + 8) * t)) + inward * bend * t * t + side * sw * math.sin(t * 3))
            rad.append(r0 * (1 - .62 * t) + r0 * 1.5 * math.exp(-t * 11))
            amp.append(.75 * math.exp(-t * 9))
        TR.add(*tube(spine, rad, segs=18, lobes=5, lobe_amp=amp))
        top = spine[-1]
        giants.append((th, base, spine, r0, H, inward, side))
        # boughs
        tips = [top]
        for q in range(6):
            t0 = random.uniform(.62, .9)
            i0 = int(t0 * (N - 1))
            a = TAU * q / 6 + random.uniform(-.4, .4)
            dirn = (inward * math.cos(a) + side * math.sin(a)) + inward * .0
            ln = random.uniform(28, 46)
            bs = [spine[i0] + dirn * ln * s + Vector((0, 0, ln * .55 * s - 9 * s * s)) for s in (0, .3, .6, .85, 1)]
            TR.add(*tube(bs, [rad[i0] * .5, rad[i0] * .38, rad[i0] * .26, rad[i0] * .16, .6], segs=8))
            tips.append(bs[-1]); tips.append(bs[3])
        # crown
        for tip in tips:
            for _ in range(2):
                c = tip + Vector((random.uniform(-12, 12), random.uniform(-12, 12), random.uniform(2, 12)))
                (CR2 if random.random() < .3 else CR).add(*blob(c, random.uniform(14, 23), .55))
        # hanging vines from the boughs
        for tip in tips[1:]:
            if random.random() < .7:
                p = tip + Vector((random.uniform(-6, 6), random.uniform(-6, 6), -6))
                ln = random.uniform(18, 60)
                sway = Vector((random.uniform(-4, 4), random.uniform(-4, 4), 0))
                pts = [p + Vector((0, 0, -ln * s)) + sway * math.sin(s * 3) for s in [i / 8 for i in range(9)]]
                V.add(*tube(pts, [.35] * 9, segs=5))
                for s in range(1, 9):
                    for _ in range(2):
                        c = pts[s] + Vector((random.uniform(-1.2, 1.2), random.uniform(-1.2, 1.2), random.uniform(-2, 2)))
                        V.add(*blob(c, random.uniform(1.2, 2.3), .7, ICO1, .2, .5))

    # 4. smaller trees on the ledges and a forest on the rim (depth bands)
    for _ in range(170):
        th = random.uniform(0, TAU)
        band = random.random()
        d = random.uniform(50, 66) if band < .25 else random.uniform(100, 124) if band < .5 else random.uniform(165, 330)
        base = ground(th, d)
        H = random.uniform(22, 44) if d < 130 else random.uniform(40, 80)
        r0 = H * .055
        lean = Vector((random.uniform(-4, 4), random.uniform(-4, 4), 0))
        spine = [base + Vector((0, 0, -3 + (H + 3) * k / 4)) + lean * (k / 4) ** 2 for k in range(5)]
        TR.add(*tube(spine, [r0 * (1.5 - .28 * k) for k in range(5)], segs=8))
        for _ in range(4 if d < 130 else 3):
            c = spine[-1] + Vector((random.uniform(-.25, .25) * H, random.uniform(-.25, .25) * H, random.uniform(-.1, .12) * H))
            (CR2 if random.random() < .35 else CR).add(*blob(c, H * random.uniform(.24, .36), .7, ICO2))
    TR.obj("GroveTrunks", bark, True)
    CR.obj("GroveCrowns", leaf, True)
    CR2.obj("GroveCrownsLime", leaf2, True)

    # 5. moss curtains over the lips of the walls, ferns in the moat and on ledges
    F = Mesh()
    for _ in range(260):
        th = random.uniform(0, TAU)
        w1, L1, led1, L2, led2, L3, g = levels(th)
        d = random.choice([w1 + 13, w1 + 13 + led1 + 17]) + random.uniform(-1, 2)
        p = ground(th, d) + Vector((-math.cos(th), -math.sin(th), 0)) * random.uniform(2.5, 5)
        ln = random.uniform(8, 30)
        pts = [p + Vector((0, 0, 1 - ln * s)) for s in (0, .25, .5, .75, 1)]
        V.add(*tube(pts, [.5, .45, .4, .3, .2], segs=4))
        for s in range(5):
            for _ in range(2):
                V.add(*blob(pts[s] + Vector((random.uniform(-1.5, 1.5), random.uniform(-1.5, 1.5), random.uniform(-2, 2))),
                            random.uniform(1.4, 2.8), .8, ICO1, .2, .5))
    for _ in range(520):
        th = random.uniform(0, TAU)
        w1, L1, led1, L2, led2, L3, g = levels(th)
        d = random.choice([random.uniform(1, 9), random.uniform(w1 - 8, w1 + 2), random.uniform(w1 + 15, w1 + 12 + led1),
                           random.uniform(w1 + 32 + led1, w1 + 28 + led1 + led2)])
        p = ground(th, d)
        F.add(*blob(p + Vector((0, 0, .8)), random.uniform(2.2, 5.5), .5, ICO1, .35, .4))
    V.obj("GroveVines", fern, True)
    F.obj("GroveFerns", fern, True)

    # 6. water: the luminous moat, falls down each gorge, pools on the ledges
    W, FL = Mesh(), Mesh()
    ring = []
    for j in range(240):
        th = TAU * j / 240
        r = rin(th)
        ring.append(Vector((CX + (r - 12) * math.cos(th), CY + (r - 12) * math.sin(th), -8.6)))
        ring.append(Vector((CX + (r + 46) * math.cos(th), CY + (r + 46) * math.sin(th), -8.6)))
    W.add(ring, [(2 * j, 2 * ((j + 1) % 240), 2 * ((j + 1) % 240) + 1, 2 * j + 1) for j in range(240)])
    for f in FALLS:
        w1, L1, led1, L2, led2, L3, g = levels(f)
        side = Vector((-math.sin(f), math.cos(f), 0))
        inward = Vector((-math.cos(f), -math.sin(f), 0))
        pts = [ground(f, d) + Vector((0, 0, 1.0)) + inward * 1.6 for d in [w1 - 6 + i * 1.6 for i in range(int((led1 + led2 + 64) / 1.6))]]
        wd = random.uniform(6, 9)
        vs, fs = [], []
        for i, p in enumerate(pts):
            vs += [p - side * wd, p + side * wd]
            if i:
                fs.append((2 * i - 2, 2 * i - 1, 2 * i + 1, 2 * i))
        FL.add(vs, fs)
        # mist puffs at the foot
        LIGHTS.append((pts[0] + Vector((0, 0, 6)), (.6, .95, 1), 1.0))
    W.obj("GroveMoat", mat_water())
    fo = FL.obj("GroveFalls", mat_fall())

    # 7. set dressing: tree houses, rope bridges, lantern strings
    WD, CRM, RF, RP, LW, LA = Mesh(), Mesh(), Mesh(), Mesh(), Mesh(), Mesh()

    def disc(c, r, h, segs=16):
        return tube([c, c + Vector((0, 0, h))], [r, r], segs)

    def lantern(p, big=1.0, kind=None):
        kind = kind or ("warm" if random.random() < .6 else "aqua")
        (LW if kind == "warm" else LA).add(*blob(p, 1.3 * big, 1.15, ICO2, 0, 1))
        RP.add(*tube([p + Vector((0, 0, 1.2 * big)), p + Vector((0, 0, 3.2 * big))], [.12, .12], 4))
        LIGHTS.append((p, (1, .72, .35) if kind == "warm" else (.35, .9, 1), big))

    def swag(a, b, sag, n=14, lamps=True, planks=False):
        pts = [a.lerp(b, i / n) + Vector((0, 0, -sag * math.sin(math.pi * i / n))) for i in range(n + 1)]
        RP.add(*tube(pts, [.22] * (n + 1), 5))
        if planks:
            dirn = (b - a).normalized(); sd = Vector((-dirn.y, dirn.x, 0)).normalized()
            for off in (-2.4, 2.4):
                RP.add(*tube([p + sd * off + Vector((0, 0, 3.4)) for p in pts], [.2] * (n + 1), 5))
            fine = [a.lerp(b, i / (n * 4)) + Vector((0, 0, -sag * math.sin(math.pi * i / (n * 4)))) for i in range(n * 4 + 1)]
            for i in range(0, n * 4, 1):
                p, q = fine[i], fine[i + 1]
                p2 = p.lerp(q, .7)
                WD.add([p - sd * 2.4, p + sd * 2.4, p2 + sd * 2.4, p2 - sd * 2.4,
                        p - sd * 2.4 + Vector((0, 0, .4)), p + sd * 2.4 + Vector((0, 0, .4)), p2 + sd * 2.4 + Vector((0, 0, .4)), p2 - sd * 2.4 + Vector((0, 0, .4))],
                       [(0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (2, 3, 7, 6), (1, 2, 6, 5), (0, 3, 7, 4)])
            for i in range(0, n + 1, 2):
                for off in (-2.4, 2.4):
                    RP.add(*tube([pts[i] + sd * off, pts[i] + sd * off + Vector((0, 0, 3.4))], [.15, .15], 4))
        if lamps:
            for i in range(1, n, 2):
                lantern(pts[i] + Vector((0, 0, -2.6 if not planks else 5.5)), .8)
        return pts

    houses = []
    for gi in (0, 2, 4, 6, 8, 1):
        th, base, spine, r0, H, inward, side = giants[gi]
        t = random.uniform(.2, .34)
        i0 = int(t * 13)
        c = spine[i0]
        rr = r0 * (1 - .62 * t) + 7
        WD.add(*disc(c, rr + 5, 1.0, 20))
        hc = c + (inward * .6 + side * .8).normalized() * (rr + .5) + Vector((0, 0, 1))
        CRM.add(*disc(hc, 4.6, 6.5, 12))
        RF.add(*tube([hc + Vector((0, 0, 6.5)), hc + Vector((0, 0, 8.3)), hc + Vector((0, 0, 12.5))], [6.2, 3.6, .2], 12))
        for a in range(4):
            wpos = hc + Vector((math.cos(a * 1.57 + .4), math.sin(a * 1.57 + .4), 0)) * 4.5 + Vector((0, 0, 3.6))
            LW.add(*blob(wpos, 1.15, 1.2, ICO1, 0, 1))
        LIGHTS.append((hc + Vector((0, 0, 4)) + inward * 6, (1, .75, .4), 1.6))
        # railing posts + rim lanterns
        for a in range(10):
            p = c + Vector((math.cos(a * .628), math.sin(a * .628), 0)) * (rr + 4.5)
            RP.add(*tube([p + Vector((0, 0, 1)), p + Vector((0, 0, 4))], [.25, .25], 5))
        lantern(c + inward * (rr + 5) + Vector((0, 0, 6)), 1.2, "warm")
        houses.append((c + Vector((0, 0, 1)), rr + 4.5, th))
    # rope bridges between neighbouring houses and from a house to a ledge
    order = sorted(houses, key=lambda h: h[2])
    for (a, ra, tha), (b, rb, thb) in zip(order, order[1:] + order[:1]):
        if (a - b).length < 190 and abs(math.atan2(math.sin((tha + thb) / 2 - SUN_GATE), math.cos((tha + thb) / 2 - SUN_GATE))) > .5:
            dirn = (b - a).normalized()
            swag(a + dirn * ra, b - dirn * rb, (a - b).length * .07, n=int((a - b).length / 9), lamps=True, planks=True)
    # lantern strings from every giant to the next, lower, over the moat
    for g1, g2 in zip(giants, giants[1:] + giants[:1]):
        if abs(math.atan2(math.sin((g1[0] + g2[0]) / 2 - SUN_GATE), math.cos((g1[0] + g2[0]) / 2 - SUN_GATE))) < .5:
            continue
        a, b = g1[2][2] + g1[5] * 9, g2[2][2] + g2[5] * 9
        if (a - b).length < 170:
            swag(a, b, (a - b).length * .1, n=int((a - b).length / 8))
    # stone lantern posts on ledge one, facing the garden
    for k in range(26):
        th = TAU * k / 26 + random.uniform(-.06, .06)
        w1, L1, led1, L2, led2, L3, g = levels(th)
        if g > .3:
            continue
        p = ground(th, w1 + 16)
        CRM.add(*tube([p + Vector((0, 0, -1)), p + Vector((0, 0, 5))], [.7, .5], 6))
        lantern(p + Vector((0, 0, 6.4)), 1.1)
    WD.obj("GroveWood", wood); CRM.obj("GroveCream", cream, True); RF.obj("GroveRoofs", roof, True)
    RP.obj("GroveRope", rope); LW.obj("GroveLampsWarm", warm, True); LA.obj("GroveLampsAqua", aqua, True)

    # 8. Aero air: soap bubbles and sparkle motes drifting in the light
    B, M = Mesh(), Mesh()
    for _ in range(70):
        c = Vector((CX + random.uniform(-140, 140), CY + random.uniform(-130, 130), random.uniform(4, 90)))
        B.add(*blob(c, random.uniform(.8, 3.2), 1, ICO3, 0, 1))
    for _ in range(420):
        c = Vector((CX + random.uniform(-170, 170), CY + random.uniform(-160, 160), random.uniform(0, 110) ** 1.0))
        M.add(*blob(c, random.uniform(.07, .16) * (2.0 if NIGHT else 1), 1, ICO1, 0, 1))
    B.obj("GroveBubbles", mat_bubble(), True); M.obj("GroveMotes", mote, True)
    return giants


def avatar(p, yaw):
    """Blocky stand-in for scale: 5.2 studs tall, with a 1.5 stud pet beside it."""
    skin = mat_flat("AvSkin", (.98, .8, .62), .6); shirt = mat_flat("AvShirt", (.25, .7, .95), .6)
    legs = mat_flat("AvLegs", (.95, .95, 1), .6); pet = mat_flat("AvPet", (1, .82, .55), .7)
    def box(c, s, m):
        bpy.ops.mesh.primitive_cube_add(size=1, location=p + Vector(c)); o = bpy.context.object; o.scale = s; o.rotation_euler = (0, 0, yaw)
        o.data.materials.append(m)
        bev = o.modifiers.new("b", "BEVEL"); bev.width = .12; bev.segments = 3
    box((0, 0, 1), (1.9, .95, 2), legs); box((0, 0, 3), (1.9, .95, 2), shirt); box((0, 0, 4.6), (1.25, 1.25, 1.25), skin)
    for sx in (-1.45, 1.45):
        box((sx * math.cos(yaw), sx * math.sin(yaw), 3), (.95, .95, 2), skin)
    pp = p + Vector((2.8 * math.cos(yaw) - 1.5 * math.sin(yaw), 2.8 * math.sin(yaw) + 1.5 * math.cos(yaw), .75))
    for c, r in (((0, 0, 0), .8), ((0, 0, .85), .62), ((-.42, 0, 1.4), .22), ((.42, 0, 1.4), .22)):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=pp + Vector(c)); o = bpy.context.object
        bpy.ops.object.shade_smooth(); o.data.materials.append(pet)


def world_and_light():
    sc = bpy.context.scene
    w = bpy.data.worlds.new("GroveSky"); w.use_nodes = True; sc.world = w
    nt = w.node_tree; L = nt.links.new
    bg = nt.nodes["Background"]
    tc = nt.nodes.new("ShaderNodeTexCoord"); sep = nt.nodes.new("ShaderNodeSeparateXYZ"); L(tc.outputs["Generated"], sep.inputs[0])
    if NIGHT:
        r = ramp(nt, [(.0, (.10, .22, .42)), (.25, (.07, .13, .36)), (1, (.03, .05, .20))])
        bg.inputs[1].default_value = .7
    else:
        r = ramp(nt, [(.0, (.80, .95, 1.0)), (.18, (.50, .82, 1.0)), (1, (.12, .50, .98))])  # the game's Aero sky
        bg.inputs[1].default_value = 1.7
    L(sep.outputs["Z"], r.inputs["Fac"]); L(r.outputs["Color"], bg.inputs[0])
    sun = bpy.data.lights.new("Sun", "SUN"); so = bpy.data.objects.new("Sun", sun); sc.collection.objects.link(so)
    # through the sun gate (south-east), high enough to light the lawn
    az = SUN_GATE
    el = math.radians(58 if not NIGHT else 62)
    d = Vector((math.cos(az) * math.cos(el), math.sin(az) * math.cos(el), math.sin(el)))
    so.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    if NIGHT:
        sun.energy, sun.color, sun.angle = .9, (.45, .72, 1.0), math.radians(3)
    else:
        sun.energy, sun.color, sun.angle = 5.2, (1, .97, .88), math.radians(2.5)
    return d


def haze(sun_dir):
    """White-blue Aero haze so the light shows as shafts (grove only)."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=(CX, CY, 150)); o = bpy.context.object; o.scale = (1300, 1300, 420); o.name = "GroveHaze"
    m = bpy.data.materials.new("GroveHaze"); m.use_nodes = True; nt = m.node_tree
    for n in list(nt.nodes):
        if n.type != "OUTPUT_MATERIAL":
            nt.nodes.remove(n)
    out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
    vs = nt.nodes.new("ShaderNodeVolumeScatter")
    vs.inputs["Color"].default_value = (.85, .97, 1, 1) if not NIGHT else (.6, .85, 1, 1)
    vs.inputs["Density"].default_value = .0015 if not NIGHT else .0005
    vs.inputs["Anisotropy"].default_value = .55
    nt.links.new(vs.outputs[0], out.inputs["Volume"])
    o.data.materials.append(m)
    o.visible_shadow = False


def rays(sun_dir):
    """Light shafts as soft additive cards, the way Roblox Beams would draw them."""
    m = bpy.data.materials.new("GroveRay"); m.use_nodes = True; nt = m.node_tree; L = nt.links.new
    for n in list(nt.nodes):
        if n.type != "OUTPUT_MATERIAL":
            nt.nodes.remove(n)
    out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (1, .97, .82, 1) if not NIGHT else (.62, .9, 1, 1)
    em.inputs["Strength"].default_value = 1.5 if not NIGHT else 1.1
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    lw = node(nt, "ShaderNodeLayerWeight", Blend=.5)
    inv = ramp(nt, [(.02, (1, 1, 1)), (.45, (.35, .35, .35)), (.9, (0, 0, 0))]); L(lw.outputs["Facing"], inv.inputs["Fac"])
    uv = nt.nodes.new("ShaderNodeTexCoord"); sp = nt.nodes.new("ShaderNodeSeparateXYZ"); L(uv.outputs["UV"], sp.inputs[0])
    fade = ramp(nt, [(0, (0, 0, 0)), (.18, (1, 1, 1)), (.75, (.8, .8, .8)), (1, (0, 0, 0))]); L(sp.outputs["Y"], fade.inputs["Fac"])
    st = node(nt, "ShaderNodeTexNoise", Scale=1.0, Detail=2.0); L(coords(nt, (.012, .012, .012)), st.inputs["Vector"])
    a = node(nt, "ShaderNodeMath", operation="MULTIPLY"); L(inv.outputs["Color"], a.inputs[0]); L(fade.outputs["Color"], a.inputs[1])
    b2 = node(nt, "ShaderNodeMath", operation="MULTIPLY"); L(a.outputs[0], b2.inputs[0]); L(st.outputs["Fac"], b2.inputs[1])
    c2 = node(nt, "ShaderNodeMath", operation="MULTIPLY"); L(b2.outputs[0], c2.inputs[0]); c2.inputs[1].default_value = .26 if not NIGHT else .2
    ms = nt.nodes.new("ShaderNodeMixShader"); L(c2.outputs[0], ms.inputs[0]); L(tr.outputs[0], ms.inputs[1]); L(em.outputs[0], ms.inputs[2])
    L(ms.outputs[0], out.inputs["Surface"])
    ends = [(-48, -8), (-8, -52), (28, 2), (62, -44), (-78, 30), (4, 44), (88, 14), (-30, 70), (-66, -66)]
    for i, (x, y) in enumerate(ends):
        gp = Vector((x, y, -1)); ln = 215 / sun_dir.z
        r0 = random.uniform(2.5, 6)
        segs = 12
        me = bpy.data.meshes.new("Ray"); verts = []; faces = []
        ref = sun_dir.cross(Vector((0, 0, 1))).normalized(); w = sun_dir.cross(ref)
        for k, (t, r) in enumerate(((0, r0 * 1.5), (1, r0 * .7))):
            for q in range(segs):
                an = TAU * q / segs
                verts.append(gp + sun_dir * ln * t + (ref * math.cos(an) + w * math.sin(an)) * r)
        for q in range(segs):
            faces.append((q, (q + 1) % segs, segs + (q + 1) % segs, segs + q))
        me.from_pydata([tuple(v) for v in verts], [], faces)
        uvl = me.uv_layers.new()
        for poly in me.polygons:
            poly.use_smooth = True
            for li in poly.loop_indices:
                vi = me.loops[li].vertex_index
                uvl.data[li].uv = ((vi % segs) / segs, 0 if vi < segs else 1)
        o = bpy.data.objects.new("GroveRay", me); o.data.materials.append(m); bpy.context.scene.collection.objects.link(o)
        o.visible_shadow = False


def clouds():
    c = mat_flat("AeroCloud", (1, 1, 1), 1.0, .08 if not NIGHT else .03)
    C = Mesh()
    for _ in range(26):
        p = Vector((random.uniform(-900, 900), random.uniform(-900, 900), random.uniform(420, 560)))
        for k in range(5):
            C.add(*blob(p + Vector((random.uniform(-70, 70), random.uniform(-70, 70), random.uniform(-8, 12))), random.uniform(40, 80), .4, ICO2, .2, .01))
    C.obj("AeroClouds", c, True)


def camera(name):
    sc = bpy.context.scene
    cam = bpy.data.cameras.new(name); co = bpy.data.objects.new(name, cam); sc.collection.objects.link(co)
    cam.sensor_fit = "VERTICAL"; cam.clip_start = .3; cam.clip_end = 6000
    # (eye, target, vertical fov) in Blender studs
    table = {
        "garden": ((-12, -30, 10.5), (-52, 60, 19), 70),       # player on the hub lawn looking out to the north-west wall
        "garden2": ((40, -52, 9.0), (110, 40, 42), 70),       # from the east lawn toward the east falls
        "wide": ((62, -158, 122), (0, 25, 12), 62),          # establishing, from up on the south-east rim
        "within": ((112, -92, 52), (-30, 30, 24), 68),        # from a tree-house deck across the hollow
        "up": ((-20, -10, 6), (5, 30, 160), 85),              # lying on the lawn looking up at the sky opening
        "dusk": ((18, -44, 10.5), (-34, 60, 26), 70),           # evening, from the south lawn across the garden
    }
    eye, tgt, fov = table[name]
    cam.angle_y = math.radians(fov)
    co.location = eye
    co.rotation_euler = (Vector(tgt) - Vector(eye)).to_track_quat("-Z", "Y").to_euler()
    sc.camera = co
    return Vector(eye), Vector(tgt)


def main():
    island.load_island(MODE == "before")
    STONE.append(mat_stone())
    for o in bpy.data.objects:
        if o.type == 'MESH':
            for sl in o.material_slots:
                if sl.material and sl.material.name.startswith('W1_ground'):
                    sl.material = STONE[0]
    sc = bpy.context.scene
    sun_dir = world_and_light()
    if MODE == "grove":
        build_grove()
        haze(sun_dir)
        rays(sun_dir)
        clouds()
        if NIGHT:
            # the garden's own lamps and glows come up; a soft cool fill keeps it bright, not gloomy
            for i, (p, c, s) in enumerate(LIGHTS):
                if i % 2 and len(LIGHTS) > 90:
                    continue
                l = bpy.data.lights.new("L", "POINT"); l.energy = 9000 * s; l.color = c; l.shadow_soft_size = 1.5
                o = bpy.data.objects.new("L", l); o.location = p; sc.collection.objects.link(o)
            for m in bpy.data.materials:
                if m.name.startswith("W1_glow"):
                    island.bsdf(m).inputs["Emission Strength"].default_value = 14
    if NIGHT:
        for x, y in ((69.65, -51.97), (29.44, -29.85), (-9, -28), (-12, 44), (-70, 3), (50, 10), (-22, -38)):
            l = bpy.data.lights.new("Lamp", "POINT"); l.energy = 9000; l.color = (1, .8, .5); l.shadow_soft_size = 1
            o = bpy.data.objects.new("Lamp", l); o.location = (x, y, 5.6); sc.collection.objects.link(o)
    sc.render.engine = "CYCLES"
    cy = sc.cycles
    cy.samples = SAMPLES
    cy.use_denoising = True
    cy.volume_bounces = 0
    cy.max_bounces = 5
    cy.volume_step_rate = 4
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        for t in ("OPTIX", "CUDA"):
            try:
                prefs.compute_device_type = t; break
            except TypeError:
                pass
        prefs.get_devices()
        for dv in prefs.devices:
            dv.use = dv.type != "CPU"
        cy.device = "GPU"
    except Exception as e:
        print("GPU setup failed", e)
    sc.render.resolution_x, sc.render.resolution_y = RES, int(RES * 9 / 16)
    sc.view_settings.view_transform = "Standard"
    try:
        sc.view_settings.look = "Medium High Contrast"
    except TypeError:
        pass
    sc.view_settings.exposure = -.1 if NIGHT else -.15
    for name in CAMS:
        eye, tgt = camera(name)
        if name in ("garden", "garden2", "dusk") and not bpy.data.objects.get("Av_" + name):
            f = (tgt - eye); f.z = 0; f.normalize()
            p = eye + f * 19; p.z = 0.1
            avatar(p, math.atan2(f.y, f.x) - math.pi / 2)
        tag = ("before" if MODE == "before" else "mockup") + "-" + name + ("-night" if NIGHT and name != "dusk" else "")
        sc.render.filepath = OUT + "/" + tag + ".png"
        bpy.ops.render.render(write_still=True)
        print("WROTE", sc.render.filepath)


main()
