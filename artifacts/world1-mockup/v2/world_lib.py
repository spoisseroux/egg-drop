"""Shared helpers for the world mockups. GENERATED from the top-level defs of ../build_world.py (v1).
Scene-specific functions (height, edges, landmarks) are overridden by the v2 script after this is exec'd."""
import bpy, bmesh, math, os, json, random, sys
from mathutils import Vector, Matrix, Euler


def B(X, h, Z):
    return (X, -Z, h)


def _hash(ix, iz, s):
    n = (ix * 374761393 + iz * 668265263 + s * 982451653) & 0xffffffff
    n = ((n ^ (n >> 13)) * 1274126177) & 0xffffffff
    return ((n ^ (n >> 16)) & 0xffff) / 65535.0


def S(t):
    t = 0.0 if t < 0 else 1.0 if t > 1 else t
    return t * t * (3 - 2 * t)


def vnoise(x, z, s=0):
    ix, iz = math.floor(x), math.floor(z)
    fx, fz = S(x - ix), S(z - iz)
    a, b = _hash(ix, iz, s), _hash(ix + 1, iz, s)
    c, d = _hash(ix, iz + 1, s), _hash(ix + 1, iz + 1, s)
    return (a + (b - a) * fx) * (1 - fz) + (c + (d - c) * fx) * fz


def fbm(x, z, s=0, octs=3):
    t = 0; a = 1; tot = 0
    for o in range(octs):
        t += a * vnoise(x, z, s + o * 7); tot += a; a *= .5; x *= 2; z *= 2
    return t / tot


def gauss(dx, dz, r):
    return math.exp(-(dx * dx + dz * dz) / (r * r))


def chaikin(pts, it=2):
    for _ in range(it):
        out = [pts[0]]
        for a, b in zip(pts, pts[1:]):
            out.append((a[0] * .75 + b[0] * .25, a[1] * .75 + b[1] * .25))
            out.append((a[0] * .25 + b[0] * .75, a[1] * .25 + b[1] * .75))
        out.append(pts[-1]); pts = out
    return pts


def resample(pts, step):
    out = [pts[0]]; carry = 0.0
    for a, b in zip(pts, pts[1:]):
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        if L < 1e-6: continue
        d = step - carry
        while d <= L:
            t = d / L; out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)); d += step
        carry = (carry + L) % step
    return out


def pdist(x, z, pts):
    best = 1e9
    for a, b in zip(pts, pts[1:]):
        ax, az = a; bx, bz = b
        dx, dz = bx - ax, bz - az
        L2 = dx * dx + dz * dz
        t = 0 if L2 == 0 else max(0, min(1, ((x - ax) * dx + (z - az) * dz) / L2))
        d = math.hypot(x - ax - dx * t, z - az - dz * t)
        if d < best: best = d
    return best


def west_edge(Z):
    return -134 + 4 * math.sin(Z / 23) + 3 * math.sin(Z / 9 + 1) - 8 * S((-18 - Z) / 12)


def south_edge(X):
    return 128 + 5 * math.sin(X / 31 + .5) + 2.5 * math.sin(X / 11) + 9 * math.exp(-((X + 10) / 16) ** 2)


def terrace_edge(Z):
    return 72 + 4 * math.sin(Z / 13) + 2 * math.sin(Z / 5 + 1)


def terrace_masks(X, Z):
    w = 3.5 + 22 * math.exp(-((Z - 8) / 6) ** 2)                       # the low ramp widens the bank at Z~8
    mL = S((X - terrace_edge(Z) + (w - 3.5) * .85) / w) * S((50 + 3 * math.sin(X / 9) - Z) / 4)
    w2 = 3.5 + 18 * math.exp(-((X - 92) / 6) ** 2)                     # the high ramp at X~92
    mH = S((-30 + 3 * math.sin(X / 11) - Z + (w2 - 3.5) * .85) / w2)
    return mL, mH


def height(X, Z):
    h = 3.2 * (fbm(X / 60, Z / 60, 3) - .5) + 1.0 * (fbm(X / 22, Z / 22, 9) - .5)
    h += 6.5 * gauss(X + 48, Z - 80, 24)        # Blossom Hill (south-west)
    h += 3.5 * gauss(X - 60, Z - 86, 28)        # Sun Meadow swell (south-east)
    h += 3.0 * gauss(X + 44, Z + 48, 20)        # rise toward the falls
    h += 2.6 * gauss(X - 45, Z + 55, 18)        # orchard rise
    h += 2.0 * gauss(X + 112, Z + 12, 16)
    h = h + .9
    if h < .25: h = .25 + (h - .25) * .12
    m = 0.0
    for px, pz, r0, r1 in PADS:
        d = math.hypot(X - px, Z - pz)
        m = max(m, 1 - S((d - r0) / (r1 - r0)))
    h *= (1 - m)
    mL, mH = terrace_masks(X, Z)
    if mL > 0:
        h = h * (1 - mL) + mL * (8 + 8 * mH + .5 * (fbm(X / 14, Z / 14, 21) - .5))
    # water carving
    px, pz, rx, rz = POND
    e = math.hypot((X - px) / rx, (Z - pz) / rz) + .16 * (fbm(X / 12, Z / 12, 31) - .5)
    if e < 1.25: h = h * S((e - .75) / .5) - 3.6 * (1 - S((e - .45) / .55))
    ix, iz, ir = ISLET
    h += 4.6 * gauss(X - ix, Z - iz, ir * .8)
    lx, lz, lrx, lrz = LILY
    e = math.hypot((X - lx) / lrx, (Z - lz) / lrz)
    if e < 1.5: h = h * S((e - .8) / .7) - 2.2 * (1 - S((e - .35) / .65))
    d = pdist(X, Z, CREEK)
    if d < 12: h = h * S((d - 5) / 7) - 2.6 * (1 - S((d - 2.2) / 4.6))
    d = pdist(X, Z, BROOK)
    if d < 7: h = h * S((d - 2.6) / 4.4) - 1.9 * (1 - S((d - 1.0) / 2.4))
    return h


def subcol(parent, name):
    c = bpy.data.collections.new(name); COL[parent].children.link(c); COL[name] = c; return c


def _mix_mul(nt, a, b):
    mx = nt.nodes.new('ShaderNodeMix'); mx.data_type = 'RGBA'; mx.blend_type = 'MULTIPLY'
    mx.inputs[0].default_value = 1.0
    nt.links.new(a, mx.inputs[6]); nt.links.new(b, mx.inputs[7])
    return mx.outputs[2]


def set_blend(m):
    try: m.surface_render_method = 'BLENDED'
    except Exception:
        try: m.blend_method = 'BLEND'
        except Exception: pass


def mat_tex(name, tex, rough=.85, emit=0.0, alpha=1.0, spec=.25, tint=(1, 1, 1)):
    m = bpy.data.materials.new('W1_' + name); m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    img = bpy.data.images.load(os.path.join(TEX, tex + '.png'), check_existing=True)
    t = nt.nodes.new('ShaderNodeTexImage'); t.image = img; t.interpolation = 'Linear'
    vc = nt.nodes.new('ShaderNodeVertexColor'); vc.layer_name = 'Col'
    col = _mix_mul(nt, t.outputs['Color'], vc.outputs['Color'])
    if tint != (1, 1, 1):
        rgb = nt.nodes.new('ShaderNodeRGB'); rgb.outputs[0].default_value = (*tint, 1)
        col = _mix_mul(nt, col, rgb.outputs[0])
    nt.links.new(col, bsdf.inputs['Base Color'])
    bsdf.inputs['Roughness'].default_value = rough
    for k in ('Specular IOR Level', 'Specular'):
        if k in bsdf.inputs: bsdf.inputs[k].default_value = spec; break
    if emit > 0:
        nt.links.new(col, bsdf.inputs['Emission Color']); bsdf.inputs['Emission Strength'].default_value = emit
    if alpha < 1:
        bsdf.inputs['Alpha'].default_value = alpha; set_blend(m)
    m.diffuse_color = (*tint, 1)
    MAT[name] = m; return m


def mat_flat(name, rgb, rough=.5, emit=0.0, alpha=1.0, spec=.4, vcol=False, coat=0.0):
    m = bpy.data.materials.new('W1_' + name); m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value = (*rgb, 1)
    if vcol:
        vc = nt.nodes.new('ShaderNodeVertexColor'); vc.layer_name = 'Col'
        rgbn = nt.nodes.new('ShaderNodeRGB'); rgbn.outputs[0].default_value = (*rgb, 1)
        col = _mix_mul(nt, rgbn.outputs[0], vc.outputs['Color'])
        nt.links.new(col, bsdf.inputs['Base Color'])
        if emit > 0: nt.links.new(col, bsdf.inputs['Emission Color'])
    elif emit > 0:
        bsdf.inputs['Emission Color'].default_value = (*rgb, 1)
    bsdf.inputs['Emission Strength'].default_value = emit
    bsdf.inputs['Roughness'].default_value = rough
    for k in ('Specular IOR Level', 'Specular'):
        if k in bsdf.inputs: bsdf.inputs[k].default_value = spec; break
    if coat and 'Coat Weight' in bsdf.inputs: bsdf.inputs['Coat Weight'].default_value = coat
    if alpha < 1:
        bsdf.inputs['Alpha'].default_value = alpha; set_blend(m)
    m.diffuse_color = (*rgb, alpha)
    MAT[name] = m; return m


def mat_unlit(name, tex=None, tex_strength=1.0):
    """Pure emission of (texture x vertex colour): hazy far scenery with baked light."""
    m = bpy.data.materials.new('W1_' + name); m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes): nt.nodes.remove(n)
    out = nt.nodes.new('ShaderNodeOutputMaterial'); em = nt.nodes.new('ShaderNodeEmission')
    vc = nt.nodes.new('ShaderNodeVertexColor'); vc.layer_name = 'Col'
    col = vc.outputs['Color']
    if tex:
        img = bpy.data.images.load(os.path.join(TEX, tex + '.png'), check_existing=True)
        t = nt.nodes.new('ShaderNodeTexImage'); t.image = img
        if tex_strength < 1:
            mx = nt.nodes.new('ShaderNodeMix'); mx.data_type = 'RGBA'; mx.inputs[0].default_value = tex_strength
            mx.inputs[6].default_value = (1, 1, 1, 1); nt.links.new(t.outputs['Color'], mx.inputs[7])
            col = _mix_mul(nt, mx.outputs[2], col)
        else:
            col = _mix_mul(nt, t.outputs['Color'], col)
    nt.links.new(col, em.inputs['Color']); nt.links.new(em.outputs[0], out.inputs['Surface'])
    MAT[name] = m; return m


def lin(hexs):
    hexs = hexs.lstrip('#'); c = [int(hexs[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= .04045 else ((x + .055) / 1.055) ** 2.4 for x in c)


class MB:
    def __init__(s):
        s.v = []; s.f = []; s.uv = []; s.col = []; s.mi = []

    def add(s, verts, faces, mat=0, col=(1, 1, 1), uv='box', uvs=None, scale=.125, colfn=None, M=None):
        base = len(s.v)
        if M is not None: verts = [tuple(M @ Vector(v)) for v in verts]
        s.v += [tuple(v) for v in verts]
        for f in faces:
            p0, p1, p2 = Vector(verts[f[0]]), Vector(verts[f[1]]), Vector(verts[f[2]])
            n = (p1 - p0).cross(p2 - p0)
            if n.length > 1e-9: n.normalize()
            ax = max(range(3), key=lambda k: abs(n[k]))
            s.f.append([base + i for i in f]); s.mi.append(mat)
            for i in f:
                p = verts[i]
                if uvs is not None: s.uv.append(uvs[i])
                elif ax == 0: s.uv.append((p[1] * scale, p[2] * scale))
                elif ax == 1: s.uv.append((p[0] * scale, p[2] * scale))
                else: s.uv.append((p[0] * scale, p[1] * scale))
                c = colfn(p, n) if colfn else col
                s.col.append((c[0], c[1], c[2], 1.0))
        return s

    def build(s, name, mats, smooth=True):
        me = bpy.data.meshes.new(name)
        me.from_pydata(s.v, [], s.f)
        uvl = me.uv_layers.new(name='UVMap')
        uvl.data.foreach_set('uv', [c for uv in s.uv for c in uv])
        ca = me.color_attributes.new('Col', 'FLOAT_COLOR', 'CORNER')
        ca.data.foreach_set('color', [c for col in s.col for c in col])
        for m in mats: me.materials.append(MAT[m])
        me.polygons.foreach_set('material_index', s.mi)
        me.polygons.foreach_set('use_smooth', [smooth] * len(s.f))
        me.update()
        return me


def obj(name, me, coll, X=0, h=0, Z=0, rot=0, scale=(1, 1, 1), tilt=(0, 0)):
    o = bpy.data.objects.new(name, me)
    o.location = B(X, h, Z); o.rotation_euler = (tilt[0], tilt[1], rot)
    o.scale = scale if isinstance(scale, tuple) else (scale, scale, scale)
    COL[coll].objects.link(o); return o


def shade_top(lo=.74, hi=1.06, warm=0.0):
    def fn(p, n):
        k = lo + (hi - lo) * (n[2] * .5 + .5)
        return (k * (1 + warm), k, k * (1 - warm))
    return fn


def ico(sub):
    if sub not in _ico_cache:
        bm = bmesh.new(); bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=1.0)
        _ico_cache[sub] = ([tuple(v.co) for v in bm.verts], [[v.index for v in f.verts] for f in bm.faces]); bm.free()
    v, f = _ico_cache[sub]; return list(v), [list(x) for x in f]


def blob(sub, seed, rough=.3, chisel=0, squash=(1, 1, 1), center=(0, 0, 0), flat_bottom=None):
    """Displaced icosphere; `chisel` flat cuts give the faceted rock silhouette."""
    r = random.Random(seed); v, f = ico(sub); out = []
    planes = []
    for _ in range(chisel):
        n = Vector((r.uniform(-1, 1), r.uniform(-1, 1), r.uniform(-.6, 1))).normalized()
        planes.append((n, r.uniform(.55, .85)))
    for p in v:
        p = Vector(p)
        k = 1 + rough * (fbm(p.x * 1.6 + seed, p.y * 1.6 + p.z * 1.3, seed, 2) - .5) * 2
        p *= k
        for n, d in planes:
            e = p.dot(n) - d
            if e > 0: p -= n * e
        p = Vector((p.x * squash[0], p.y * squash[1], p.z * squash[2]))
        if flat_bottom is not None and p.z < flat_bottom: p.z = flat_bottom
        out.append((p.x + center[0], p.y + center[1], p.z + center[2]))
    return out, f


def box(sx, sy, sz, c=(0, 0, 0)):
    x, y, z = sx / 2, sy / 2, sz / 2; cx, cy, cz = c
    P = lambda a, b, d: (cx + a * x, cy + b * y, cz + d * z)
    quads = [[(-1, -1, -1), (-1, 1, -1), (1, 1, -1), (1, -1, -1)], [(-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)],
             [(-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1)], [(1, 1, -1), (-1, 1, -1), (-1, 1, 1), (1, 1, 1)],
             [(-1, 1, -1), (-1, -1, -1), (-1, -1, 1), (-1, 1, 1)], [(1, -1, -1), (1, 1, -1), (1, 1, 1), (1, -1, 1)]]
    v = []; f = []
    for q in quads:
        b = len(v); v += [P(*k) for k in q]; f.append([b, b + 1, b + 2, b + 3])
    return v, f


def lathe(profile, sides=10, cap_top=False, cap_bot=False):
    """profile: [(radius, z)] bottom -> top. Returns verts, faces, uvs."""
    v = []; uv = []; f = []
    L = [0]
    for a, b in zip(profile, profile[1:]): L.append(L[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
    for j, (r, z) in enumerate(profile):
        for i in range(sides + 1):
            a = 2 * math.pi * i / sides
            v.append((r * math.cos(a), r * math.sin(a), z)); uv.append((i / sides * max(1, round(r * .8)), L[j] * .125))
    for j in range(len(profile) - 1):
        for i in range(sides):
            a = j * (sides + 1) + i
            f.append([a, a + 1, a + sides + 2, a + sides + 1])
    for cap, j in ((cap_bot, 0), (cap_top, len(profile) - 1)):
        if cap:
            r, z = profile[j]; b = len(v)
            for i in range(sides):
                a = 2 * math.pi * i / sides
                v.append((r * math.cos(a), r * math.sin(a), z)); uv.append((r * math.cos(a) * .125, r * math.sin(a) * .125))
            ring = list(range(b, b + sides))
            f.append(ring if j else ring[::-1])
    return v, f, uv


def wobble(v, sides, seed, amt):
    """Radial jitter for lathe side verts (seam-safe)."""
    out = []
    for n, p in enumerate(v):
        j, i = divmod(n, sides + 1); k = 1 + amt * (_hash(i % sides, j, seed) - .5) * 2
        out.append((p[0] * k, p[1] * k, p[2]))
    return out


def tube(points, radii, sides=7, seed=0, wob=.0):
    """Sweep a ring along 3D points (Blender coords). Returns verts, faces, uvs."""
    v = []; uv = []; f = []; Lacc = 0
    pts = [Vector(p) for p in points]
    for j, p in enumerate(pts):
        t = (pts[min(j + 1, len(pts) - 1)] - pts[max(j - 1, 0)]).normalized()
        ref = Vector((0, 0, 1)) if abs(t.z) < .9 else Vector((1, 0, 0))
        a1 = t.cross(ref).normalized(); a2 = t.cross(a1).normalized()
        if j: Lacc += (p - pts[j - 1]).length
        for i in range(sides + 1):
            a = 2 * math.pi * (i % sides) / sides
            r = radii[j] * (1 + wob * (_hash(i % sides, j, seed) - .5) * 2)
            q = p + (a1 * math.cos(a) + a2 * math.sin(a)) * r
            v.append(tuple(q)); uv.append((i / sides * 2, Lacc * .125))
    for j in range(len(pts) - 1):
        for i in range(sides):
            a = j * (sides + 1) + i
            f.append([a, a + sides + 1, a + sides + 2, a + 1])
    return v, f, uv


def tri_count(me):
    return sum(len(p.vertices) - 2 for p in me.polygons)


def band_points():
    ctrl = [(-138, -10), (-137, -24), (-136, -40), (-132, -58), (-122, -72), (-105, -77), (-85, -82), (-62, -76),
            (-36, -79), (-10, -75), (10, -80), (30, -76), (55, -79), (80, -76), (100, -78), (111, -71), (114, -45),
            (111, -15), (114, 15), (111, 45), (114, 75), (112, 100), (115, 125), (119, 152)]
    return resample(chaikin(ctrl, 3), 4.0)


def outward(pts, i):
    a = pts[max(i - 1, 0)]; b = pts[min(i + 1, len(pts) - 1)]
    tx, tz = b[0] - a[0], b[1] - a[1]; L = math.hypot(tx, tz) or 1
    nx, nz = -tz / L, tx / L
    if nx * (pts[i][0] - CENTRE[0]) + nz * (pts[i][1] - CENTRE[1]) < 0: nx, nz = -nx, -nz
    return nx, nz


def band_info(i):
    """Top height, taper and bulge for band column i."""
    n = len(BAND); s = i * 4.0; X, Z = BAND[i]
    taper = min(S(i / 9) * .97 + .03, S((n - 1 - i) / 8) * .97 + .03)
    T = (38 + 13 * fbm(s / 45, 0, 51, 2) + 5 * math.sin(s / 17)) * taper
    fall = math.exp(-((X + 85) / 7) ** 2) if Z < -60 else 0
    T -= 7 * fall
    cave = max(0.0, 1 - ((X - 10) / 9.5) ** 2) if Z < -60 else 0
    bul = 0
    for u, amp, wid in BULGES:
        bul += amp * math.exp(-((s - u * n * 4) / wid) ** 2)
    bul *= (1 - min(1, cave * 3)) * (1 - fall) * taper
    return T, taper, bul, cave, fall


def ground_material_and_color():
    faces = []; mi = []; uvs = []; cols = []
    W = NX + 1
    vcol = []
    for (X, h, Z) in gv:
        n = fbm(X / 30, Z / 30, 77, 2) - .5
        k = 1.0 + .16 * n + .012 * max(-2, min(6, h))
        d = pdist(X, Z, BAND)
        k *= .78 + .22 * S(d / 14)                                # soft contact shade under the walls
        vcol.append((k * (1 + .10 * n), k, k * (1 - .14 * n)))
    for j in range(NZ):
        for i in range(NX):
            a = j * W + i; b = a + 1; c = a + W + 1; d = a + W
            for tri in ((a, d, c), (a, c, b)):                    # CCW seen from above in Blender (y = -Z)
                P = [Vector(B(*gv[t])) for t in tri]
                n = (P[1] - P[0]).cross(P[2] - P[0]).normalized()
                cx = sum(gv[t][0] for t in tri) / 3; cz = sum(gv[t][2] for t in tri) / 3; ch = sum(gv[t][1] for t in tri) / 3
                mL, mH = terrace_masks(cx, cz)
                if n.z < .80: m = 3                               # steep -> rock
                elif ch < WATER + .62 and not (mL > .1): m = 2    # shore + bed -> sand/pebble
                elif math.hypot(cx + 10, cz - 88) < 13 or math.hypot(cx + 2, cz - 15) < 8 or \
                        (math.hypot(cx - 62, cz - 88) < 30 and fbm(cx / 9, cz / 9, 5) > .42) or \
                        (math.hypot(cx + 48, cz - 80) < 15): m = 1  # meadow flowers
                else: m = 0
                faces.append(tri); mi.append(m)
                for t in tri:
                    X, h, Z = gv[t]
                    if m == 3: uvs.append(((X * .7 + Z * .7) / 26, h / 26))
                    else: uvs.append((X / 16, -Z / 16))
                    cols.append((*vcol[t], 1))
    return faces, mi, uvs, cols


def ribbon(name, pts, width, coll='Ground', mat='dirt_path', lift=.13, closed=False):
    pts = resample(chaikin(pts, 3), 2.2)
    mb = MB(); V = []; U = []; F = []
    across = (-1, -.4, .4, 1)
    for i, (X, Z) in enumerate(pts):
        a = pts[max(i - 1, 0)]; b = pts[min(i + 1, len(pts) - 1)]
        tx, tz = b[0] - a[0], b[1] - a[1]; L = math.hypot(tx, tz) or 1
        nx, nz = -tz / L, tx / L
        end = min(i, len(pts) - 1 - i)
        w = width * (.82 + .36 * vnoise(i * .23, 0, hash(name) & 255)) * (.55 + .45 * S(end / 3))
        for k in across:
            x = X + nx * k * w / 2; z = Z + nz * k * w / 2
            V.append(B(x, height(x, z) + (lift if abs(k) < 1 else lift * .35), z)); U.append((x / 8, -z / 8))
    for i in range(len(pts) - 1):
        for k in range(3):
            a = i * 4 + k
            F.append([a, a + 1, a + 5, a + 4])
    mb.add(V, F, 0, uvs=U, colfn=lambda p, n: (1, 1, 1))
    me = mb.build(name, [mat]); obj(name, me, coll); return me


def disc(name, X, Z, r, mat, coll, lift=.16, segs=24, wob=.12, seed=0):
    mb = MB(); V = [B(X, height(X, Z) + lift, Z)]; U = [(X / 8, -Z / 8)]; F = []
    rings = (.5, 1.0)
    for ri, rr in enumerate(rings):
        for i in range(segs):
            a = 2 * math.pi * i / segs
            R = r * rr * (1 + wob * (vnoise(i * .7, ri, seed) - .5) * 2 * rr)
            x = X + math.cos(a) * R; z = Z + math.sin(a) * R
            V.append(B(x, height(x, z) + (lift if rr < 1 else lift * .3), z)); U.append((x / 8, -z / 8))
    for i in range(segs):
        j = (i + 1) % segs
        F.append([0, 1 + j, 1 + i]); F.append([1 + i, 1 + j, 1 + segs + j, 1 + segs + i])
    mb.add(V, F, 0, uvs=U)
    me = mb.build(name, [mat]); obj(name, me, coll); return me


def build_band():
    mb = MB(); V = []; U = []; C = []; F = []; MI = []
    n = len(BAND); rows = len(FR) + 4
    for i, (X, Z) in enumerate(BAND):
        nx, nz = BANDN[i]; T, taper, bul, cave, fall = band_info(i); s = i * 4.0
        inside = Z < south_edge(X) - 1.5 and X > west_edge(Z) + 1
        foot = -3.0 if inside else SEA - 2
        prof = []
        Hc = 15.5 * math.sqrt(cave) if cave > 0 else 0
        for r, fr in enumerate(FR):
            hh = foot + (T - foot) * fr if not inside else (foot if r == 0 else T * fr)
            d = 2.4 * (fbm(s / 10, r * 1.7, 61, 2) - .5) * 2 - bul * (1 - .65 * fr) + 1.6 * fr
            d += 8.0 * fall
            shade = .70 + .34 * fr
            if cave > 0 and hh < Hc:
                push = 17 * S(cave * 1.6) * S((Hc - hh) / 4)
                d += push; shade *= max(.07, 1 - push / 7.5)
            prof.append((d, hh, shade, 0))
        wsc = .04 + .96 * taper
        prof.append((prof[-1][0] + 9 * wsc, T + 2.5 * taper + 2 * fbm(s / 20, 3, 5) * taper, 1.0, 1))
        prof.append((prof[-1][0] + 16 * wsc, T + 1.0 * taper, .96, 1))
        prof.append((prof[-1][0] + 11 * wsc, T * .5, .85, 1))
        prof.append((prof[-1][0] + 9 * wsc, SEA - 2, .7, 0))
        acc = 0
        for r, (d, hh, shade, g) in enumerate(prof):
            if r: acc += math.hypot(d - prof[r - 1][0], hh - prof[r - 1][1])
            V.append(B(X + nx * d, hh, Z + nz * d)); U.append((s / 26, acc / 26))
            C.append((shade * .98, shade * .98, shade * 1.03))
        if inside: FOOT_ROCKS.append((X, Z, nx, nz, T, bul, cave, fall, s))
    for i in range(n - 1):
        for r in range(rows - 1):
            a = i * rows + r; b = a + rows
            # winding: outward normal must face the garden (inner side)
            F.append([a, a + 1, b + 1, b]); MI.append(1 if FR.__len__() - 1 <= r < rows - 2 else 0)
    # fix winding using the first face
    mbv = V
    p0, p1, p2 = Vector(mbv[F[len(F) // 2][0]]), Vector(mbv[F[len(F) // 2][1]]), Vector(mbv[F[len(F) // 2][2]])
    nrm = (p1 - p0).cross(p2 - p0)
    mid = BAND[len(BAND) // 2]; to_c = Vector((CENTRE[0] - mid[0], -(CENTRE[1] - mid[1]), 0))
    flip = nrm.dot(to_c) < 0 and False
    for f, m in zip(F, MI):
        mb.add(V, [f], m, uvs=U, colfn=None)
    # MB.add appended verts repeatedly; rebuild compactly instead
    mb = MB(); mb.v = [tuple(v) for v in V]
    for f, m in zip(F, MI):
        mb.f.append(f); mb.mi.append(m)
        for i in f: mb.uv.append(U[i]); mb.col.append((*C[i], 1))
    me = mb.build('Wall_CliffBand', ['cliff_rock', 'grass'])
    o = obj('Wall_CliffBand', me, 'Walls_Rocks')
    return me


def build_rim():
    """Rock skirt hanging from the south + west rim down into the sea."""
    W = NX + 1
    idx = [j * W for j in range(NZ, -1, -1) if gXZ[j * W][1] > -22][::-1]     # west column north->south
    idx += [NZ * W + i for i in range(1, NX + 1)]                              # south row west->east
    pts = [gXZ[k] for k in idx]
    prof = [(0, None), (.8, -3.5), (-1.2, -11), (2.2, -21), (.2, -33), (3.5, SEA - 2)]
    mb = MB(); V = []; U = []; C = []
    s = 0
    for n_, k in enumerate(idx):
        X, Z = pts[n_]; nx, nz = outward(pts, n_)
        if n_: s += math.hypot(X - pts[n_ - 1][0], Z - pts[n_ - 1][1])
        acc = 0
        for r, (d, hh) in enumerate(prof):
            if hh is None: hh = gv[k][1]; dd = 0
            else: dd = d + 3.0 * (fbm(s / 9, r * 1.3, 91, 2) - .5) * 2
            if r: acc += abs(hh - (prof[r - 1][1] if prof[r - 1][1] is not None else gv[k][1]))
            V.append(B(X + nx * dd, hh, Z + nz * dd)); U.append((s / 18, acc / 18))
            sh = 1.0 - .30 * r / (len(prof) - 1)
            C.append((sh, sh, sh * 1.04))
    R = len(prof)
    mb.v = [tuple(v) for v in V]
    for n_ in range(len(idx) - 1):
        for r in range(R - 1):
            a = n_ * R + r; f = [a, a + R, a + R + 1, a + 1]
            mb.f.append(f); mb.mi.append(0)
            for i in f: mb.uv.append(U[i]); mb.col.append((*C[i], 1))
    me = mb.build('Wall_RimSkirt', ['cliff_rock'])
    bm = bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm, faces=bm.faces); bm.to_mesh(me); bm.free()
    obj('Wall_RimSkirt', me, 'Walls_Rocks')


def rock(coll, X, Z, size, kind=None, h=None, sink=.3, sq=None, raw=False):
    kind = kind or ('big%d' % rnd.randrange(4) if size > 4.5 else 'small%d' % rnd.randrange(4))
    sq = sq or (rnd.uniform(.8, 1.25), rnd.uniform(.8, 1.25), rnd.uniform(.7, 1.15))
    hh = (height(X, Z) if h is None else h) + (0 if raw else size * sq[2] * (.85 - sink * 1.7) * .5)
    ROCKN[0] += 1
    return obj('Rock_%03d' % ROCKN[0], ROCK[kind], coll, X, hh, Z, rot=rnd.uniform(0, 6.28),
               scale=(size * sq[0] / 2, size * sq[1] / 2, size * sq[2] / 2), tilt=(rnd.uniform(-.2, .2), rnd.uniform(-.2, .2)))


def water_sheet():
    step = 3.0; cells = {}
    X = -112
    while X < 44:
        Z = -100
        while Z < 132:
            if min(height(X + a, Z + b) for a in (0, step) for b in (0, step)) < WATER + .25:
                if Z + step < south_edge(X) + 1: cells[(round(X / step), round(Z / step))] = 1
            Z += step
        X += step
    mb = MB(); vid = {}; V = []; U = []; F = []
    def vi(i, j):
        if (i, j) not in vid:
            vid[(i, j)] = len(V); V.append(B(i * step, WATER, j * step)); U.append((i * step / 12, -j * step / 12))
        return vid[(i, j)]
    for (i, j) in cells:
        F.append([vi(i, j), vi(i, j + 1), vi(i + 1, j + 1), vi(i + 1, j)])
    mb.v = V
    for f in F:
        mb.f.append(f); mb.mi.append(0)
        for i in f: mb.uv.append(U[i]); mb.col.append((1, 1, 1, 1))
    me = mb.build('Water_PondCreekBrook', ['water']); obj('Water_PondCreekBrook', me, 'Water')


def sea():
    mb = MB(); V = [B(0, SEA, 0)]; U = [(0, 0)]; C = [lin('#6CCDEC')]; F = []
    rings = [(180, '#6CCDEC'), (420, '#84D8F0'), (900, '#A9E5F6'), (1800, '#CFF1FC'), (4200, '#E9F9FF')]
    segs = 40
    for r, c in rings:
        for i in range(segs):
            a = 2 * math.pi * i / segs
            V.append(B(math.cos(a) * r, SEA, math.sin(a) * r)); U.append((math.cos(a) * r / 48, -math.sin(a) * r / 48)); C.append(lin(c))
    for i in range(segs):
        j = (i + 1) % segs; F.append([0, 1 + j, 1 + i])
        for k in range(len(rings) - 1):
            a = 1 + k * segs; F.append([a + i, a + j, a + segs + j, a + segs + i])
    mb.v = V
    for f in F:
        mb.f.append(f); mb.mi.append(0)
        for i in f: mb.uv.append(U[i]); mb.col.append((*[c * 1.08 for c in C[i]], 1))
    obj('Water_Sea', mb.build('Water_Sea', ['sea']), 'Water')


def falls_ribbon(name, pts, widths, coll='Water', mat='waterfall'):
    """pts: [(X, h, Z)] top->bottom centre line; ribbon across X."""
    V = []; U = []; F = []; acc = 0
    for i, (X, h, Z) in enumerate(pts):
        if i: acc += math.dist(pts[i], pts[i - 1])
        for k in (-1, -.33, .33, 1):
            bow = .6 * (1 - k * k)
            V.append(B(X + k * widths[i] / 2, h, Z + bow)); U.append((k * widths[i] / 12, -acc / 14))
    for i in range(len(pts) - 1):
        for k in range(3):
            a = i * 4 + k; F.append([a, a + 4, a + 5, a + 1])
    mb = MB(); mb.add(V, F, 0, uvs=U)
    me = mb.build(name, [mat])
    bm = bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm, faces=bm.faces); bm.to_mesh(me); bm.free()
    return obj(name, me, coll)


def tree_mesh(name, seed, trunk_h, trunk_r, blobs, foliage='foliage', sub=1, lean=.4):
    r = random.Random(seed); mb = MB()
    pts = [(0, 0, -.6), (lean * .3, 0, trunk_h * .4), (lean, lean * .3, trunk_h * .8), (lean * 1.2, lean * .4, trunk_h)]
    v, f, uv = tube(pts, [trunk_r * 1.35, trunk_r, trunk_r * .8, trunk_r * .6], sides=6)
    mb.add(v, f, 0, uvs=uv, colfn=shade_top(.85, 1.05))
    for (bx, by, bz, br, sq) in blobs:
        v, f = blob(sub, r.randrange(999), rough=.22, squash=(br, br, br * sq), center=(bx + lean, by, bz))
        mb.add(v, f, 1, colfn=leaf_col, scale=.09)
    return mb.build(name, ['bark', foliage])


def flower_mesh(name, mats):
    mb = MB(); r = random.Random(len(name) * 7 + ord(name[-1]))
    for k in range(5):
        x, y = r.uniform(-1.2, 1.2), r.uniform(-1.2, 1.2); hh = r.uniform(.4, .8); q = .05
        V = [(x - q, y - q, 0), (x + q, y - q, 0), (x, y + q, 0), (x - q, y - q, hh), (x + q, y - q, hh), (x, y + q, hh)]
        mb.add(V, [[0, 1, 4, 3], [1, 2, 5, 4], [2, 0, 3, 5]], 0)
        d = .26
        V = [(x, y, hh + .16), (x + d, y, hh), (x, y + d, hh), (x - d, y, hh), (x, y - d, hh), (x, y, hh - .1)]
        mb.add(V, [[0, 1, 2], [0, 2, 3], [0, 3, 4], [0, 4, 1], [5, 2, 1], [5, 3, 2], [5, 4, 3], [5, 1, 4]], 1 + k % (len(mats) - 1))
    return mb.build(name, mats, smooth=False)


def clear_spot(X, Z, r=4.0, water_ok=False):
    if not (west_edge(Z) + 4 < X < 106 and -70 < Z < south_edge(X) - 5): return False
    if not water_ok and height(X, Z) < .05: return False
    if any(pdist(X, Z, p) < r for p in ALLPATH): return False
    if any(math.hypot(X - sx, Z - sz) < r + 4 for sx, sz in STATIONS.values()): return False
    if math.hypot(X, Z - 4) < 19: return False
    mL, mH = terrace_masks(X, Z)
    if .03 < mL < .97 or (mL > .5 and .03 < mH < .97): return False
    return True


def hatch_tree():
    mb = MB(); r = random.Random(5)
    pts = [(0, 0, -.8), (-.5, 0, 4), (-.2, .2, 8.5), (.6, -.2, 12.5), (-.4, .6, 16)]
    v, f, uv = tube(pts, [2.5, 1.8, 1.55, 1.3, .9], sides=8, seed=4, wob=.06)
    mb.add(v, f, 0, uvs=uv, colfn=shade_top(.85, 1.05))
    for a in range(6):                                              # roots
        an = a / 6 * 6.283 + .3
        v, f, uv = tube([(math.cos(an) * .9, math.sin(an) * .9, 1.6), (math.cos(an) * 2.6, math.sin(an) * 2.6, .5),
                         (math.cos(an) * 4.4, math.sin(an) * 4.4, -.4)], [.8, .6, .25], sides=5)
        mb.add(v, f, 0, uvs=uv, colfn=shade_top(.85, 1.05))
    crowns = [(0, 0, 19.5, 8.0), (6.5, 1.5, 16.5, 5.6), (-6.8, 1.0, 16.2, 5.8), (1.0, -6.2, 16.0, 5.2), (-1.0, 6.0, 17.0, 5.4),
              (4.6, -4.4, 20.5, 4.4), (-4.5, -4.2, 20.0, 4.2)]
    for (bx, by, bz, br) in crowns:
        v, f, uv = tube([(.3, -.1, 11.5), (bx * .5, by * .5, bz - br * .55), (bx * .85, by * .85, bz - br * .2)], [.9, .6, .3], sides=5)
        mb.add(v, f, 0, uvs=uv, colfn=shade_top(.85, 1.05))
        v, f = blob(2, r.randrange(999), rough=.2, squash=(br, br, br * .68), center=(bx, by, bz))
        mb.add(v, f, 1, colfn=leaf_col, scale=.07)
    for k in range(5):                                              # blossom puffs
        a = k * 1.26
        v, f = blob(1, 60 + k, rough=.2, squash=(2.3, 2.3, 1.5), center=(math.cos(a) * 7.5, math.sin(a) * 7.5, 20.5 - (k % 2) * 3))
        mb.add(v, f, 2, colfn=leaf_col, scale=.1)
    obj('Landmark_HatchTree', mb.build('Landmark_HatchTree', ['bark', 'foliage', 'foliage_blossom']), 'Landmarks', -3.4, 0, -10.9)
    # hanging lantern (matches the existing lantern spot)
    mb = MB(); v, f = box(.1, .1, 3.4, (0, 0, 1.7)); mb.add(v, f, 0)
    v, f, uv = lathe([(.05, -.9), (.45, -.6), (.5, -.1), (.3, .1)], 8); mb.add(v, f, 1, uvs=uv)
    obj('Landmark_HatchTree_Lantern', mb.build('HatchLantern', ['bark', 'glow_warm']), 'Landmarks', .82, 5.2, -9.6)


def chime_arch(X, Z):
    mb = MB(); pts = []; rad = []
    for k in range(17):
        a = math.pi * k / 16
        pts.append((-math.cos(a) * 9.6, .3 * math.sin(a * 2), math.sin(a) * 14 - 1.2 * (1 - math.sin(a))))
        rad.append(2.25 - .95 * math.sin(a) + .35 * vnoise(k * .9, 0, 8))
    v, f, uv = tube(pts, rad, sides=7, seed=11, wob=.14)
    mb.add(v, f, 0, uvs=[(a * 1.0, b * .6) for a, b in uv], colfn=shade_top(.76, 1.08))
    for k, (dx, L, m) in enumerate([(-5.0, 2.0, 1), (-2.5, 2.9, 2), (0, 3.6, 3), (2.5, 2.6, 4), (5.0, 1.8, 5)]):
        top = 14 * math.sin(math.acos(max(-1, min(1, -dx / 9.6)))) - 2.0
        v, f = box(.05, .05, 1.6, (dx, 0, top - .6)); mb.add(v, f, 6)
        v, f, uv = lathe([(.24, top - 1.4 - L), (.24, top - 1.4)], 6, True, True); mb.add(v, f, m, uvs=uv, M=Matrix.Translation((dx, 0, 0)))
    me = mb.build('Landmark_ChimeArch', ['cliff_rock', 'ph_pink', 'ph_yellow', 'ph_lilac', 'ph_aqua', 'ph_mint', 'bark'])
    obj('Landmark_ChimeArch', me, 'Landmarks', X, height(X, Z), Z)
    for sx in (-1, 1):
        rock('Landmarks', X + sx * 11, Z + 1.5, 4.5, kind='mossy0'); rock('Landmarks', X + sx * 8.2, Z - 2.8, 2.4, kind='small1')


def tumble_falls():
    i = min(range(len(BAND)), key=lambda k: abs(BAND[k][0] + 85) + (0 if BAND[k][1] < -60 else 999))
    X, Z = BAND[i]; T = band_info(i)[0]
    zf = Z - 8.0                                                   # alcove face
    falls_ribbon('Water_TumbleFalls_Upper', [(X, T + 2.4, zf - 6), (X, T + 1.8, zf - .5), (X, T - 3, zf + 1.4), (X, T * .6, zf + 2.2), (X, 14.5, zf + 2.6)],
                 [9, 9.5, 10, 10.5, 11])
    falls_ribbon('Water_TumbleFalls_Lower', [(X + 1.5, 15.3, zf + 3.0), (X + 1.5, 14.9, zf + 8.4), (X + 1.5, 11, zf + 10.4), (X + 1.5, 4, zf + 11.3), (X + 1.5, WATER, zf + 11.6)],
                 [12, 12.5, 13, 14, 15])
    falls_ribbon('Water_TumbleFalls_Trickle', [(X - 14, T * .5, zf + 6.4), (X - 14, T * .25, zf + 8.0), (X - 14.4, WATER, zf + 9.4)], [1.6, 2.0, 2.6])
    # the tumble shelf: a wide flat boulder that splits the drop in two (top ~ h 15)
    rock('Landmarks', X + 1.5, zf + 3.5, 20, kind='big1', h=7.6, raw=True, sq=(1.25, .85, .9)).name = 'Landmark_TumbleShelf'
    rock('Landmarks', X + 1.5, zf + 4.5, 17, kind='big3', h=1.0, raw=True, sq=(1.2, .9, .9)).name = 'Landmark_TumbleShelf_Base'
    # stacked buttresses hugging both sides of the alcove
    for side in (-1, 1):
        for lvl, (dz, sz) in enumerate([(7.5, 12), (6.0, 11), (5.0, 9.5), (4.0, 8)]):
            rock('Landmarks', X + side * (11.5 + lvl * .6) + rnd.uniform(-1, 1), zf + dz, sz, kind=('mossy%d' % (lvl % 2)) if lvl in (0, 3) else 'crag%d' % rnd.randrange(4),
                 h=2 + lvl * 8.5, raw=True, sq=(1.0, 1.1, .95))
    for dx, dz, sz in [(-9, 13.5, 3.4), (11, 14, 3.8), (-4, 15.5, 2.2), (6, 16, 2.4)]:
        rock('Landmarks', X + dx, zf + dz, sz, kind='small%d' % rnd.randrange(4), h=WATER + .3, raw=True)
    mb = MB(); V = [(0, 0, 0)]; F = []
    for k in range(14):
        a = k / 14 * 6.283; R = 9 * (1 + .25 * vnoise(k * .8, 0, 3)); V.append((math.cos(a) * R, math.sin(a) * R * .55, 0))
    for k in range(14): F.append([0, 1 + k, 1 + (k + 1) % 14])
    mb.add(V, F, 0, col=(1, 1, 1))
    for k in range(8):
        v, f = blob(1, 90 + k, rough=.2, squash=(1.6, 1.2, .9), center=(rnd.uniform(-6.5, 6.5), rnd.uniform(-1.0, 2.0), .25)); mb.add(v, f, 0, col=(1, 1, 1))
    obj('Water_TumbleFalls_Foam', mb.build('FallsFoam', ['foam']), 'Water', X + 1.5, WATER + .08, zf + 13)
    mb = MB()
    for k in range(5):
        v, f = blob(1, 70 + k, rough=.2, squash=(1.4, 1.0, .8), center=(-4.5 + k * 2.3, rnd.uniform(-.5, .5), 0)); mb.add(v, f, 0, col=(1, 1, 1))
    obj('Water_TumbleFalls_ShelfFoam', mb.build('FallsShelfFoam', ['foam']), 'Water', X + 1, 15.1, zf + 3.2)
    ix, iz, _ = ISLET
    obj('Landmark_IsletTree', TREE['blossom'], 'Landmarks', ix, height(ix, iz) - .1, iz, rot=2.1, scale=.85)
    return X, zf


def glow_grotto():
    cx, cz = 10, -80
    for k in range(9):                                             # boulder arch framing the mouth
        a = math.pi * (k + .5) / 9
        X = cx - math.cos(a) * 11.5; hh = math.sin(a) * 15.5
        rock('Landmarks', X + rnd.uniform(-.6, .6), cz + 1.0 + rnd.uniform(-.6, .6), rnd.uniform(5.5, 8), kind='big%d' % (k % 4), h=hh, sink=.3).name = 'Landmark_GrottoArchRock_%d' % k
    mb = MB(); r = random.Random(9)
    spots = [(-6.5, 2, 3.2, 1), (-7.8, -3, 2.2, 2), (6.8, 1, 3.8, 1), (8.0, -4, 2.4, 2), (-4, -9, 4.6, 1), (4.5, -11, 5.2, 2), (0, -14, 6.5, 1),
             (-9.5, 6.5, 1.6, 2), (10, 6, 1.9, 1)]
    for (dx, dz, hh, m) in spots:
        v, f, uv = lathe([(hh * .2, -.4), (hh * .24, hh * .62), (0.02, hh)], 6)
        Mx = Matrix.Translation(B(dx, 0, dz)) @ Euler((r.uniform(-.35, .35), r.uniform(-.35, .35), r.uniform(0, 3))).to_matrix().to_4x4()
        mb.add(v, f, m - 1, uvs=uv, M=Mx)
    o = obj('Landmark_GrottoCrystals', mb.build('GrottoCrystals', ['glow_aqua', 'glow_pink'], smooth=False), 'Landmarks', cx, 0, cz)
    o.location.z = height(cx - 6, cz + 2) * 0 - .2
    li = bpy.data.lights.new('GrottoGlow', 'POINT'); li.energy = 1400; li.color = (.45, .95, 1.0); li.shadow_soft_size = 3
    lo = bpy.data.objects.new('GrottoGlow', li); lo.location = B(cx, 6, cz - 8); COL['Landmarks'].objects.link(lo)


def pinwheel(X, Z):
    h0 = height(X, Z); mb = MB()
    v, f, uv = lathe([(1.5, -.5), (1.1, .6), (.55, 2), (.4, 25), (.55, 25.6)], 8, cap_top=True); mb.add(v, f, 0, uvs=uv)
    v, f, uv = lathe([(2.4, -.2), (2.6, .5), (2.2, .9)], 10, cap_top=True); mb.add(v, f, 2, uvs=uv)
    obj('Landmark_Pinwheel_Mast', mb.build('PinwheelMast', ['ph_white', 'ph_aqua', 'stone_tile']), 'Landmarks', X, h0, Z)
    mb = MB()
    v, f = blob(1, 5, rough=0, squash=(.9, .7, .9)); mb.add(v, f, 0)
    for k in range(5):                                            # folded-paper blades in the local XZ plane
        a = k / 5 * 6.283; ca, sa = math.cos(a), math.sin(a)
        R = lambda x, z, y=0: (x * ca - z * sa, y, x * sa + z * ca)
        V = [R(0, 0, -.5), R(2.6, 3.4, -1.3), R(.4, 9.4, -.3), R(-1.2, 4.2, -.25), R(1.0, 3.8, -.2)]
        mb.add(V, [[0, 1, 4], [1, 2, 4], [4, 2, 3], [0, 4, 3], [0, 4, 1][::-1], [1, 4, 2][::-1], [4, 3, 2][::-1], [0, 3, 4][::-1]], 1 + k)
    me = mb.build('PinwheelRotor', ['ph_white', 'ph_pink', 'ph_yellow', 'ph_mint', 'ph_aqua', 'ph_lilac'], smooth=False)
    yaw = math.atan2(-(8 - Z) * -1, (0 - X))                     # face the hub
    d = Vector((0 - X, -(8 - Z), 0)).normalized()
    o = obj('Landmark_Pinwheel_Rotor', me, 'Landmarks', X + d.x * 1.5, h0 + 25.2, Z - d.y * 1.5, scale=1.3)
    o.rotation_euler = (0, .35, math.atan2(d.y, d.x) + math.pi / 2)
    return o


def pavilion(X, Z):
    h0 = height(X, Z); mb = MB()
    for a in range(5):
        an = a / 5 * 6.283 + .3
        v, f, uv = lathe([(.42, 0), (.3, .6), (.28, 6.4)], 6); mb.add(v, f, 0, uvs=uv, M=Matrix.Translation((math.cos(an) * 5, math.sin(an) * 5, 0)))
    v, f, uv = lathe([(6.6, 6.2), (6.2, 7.0), (4.6, 8.6), (2.2, 9.7), (.3, 10.1)], 12, cap_bot=True); mb.add(v, f, 1, uvs=uv)
    v, f = blob(1, 3, rough=0, squash=(.7, .7, .7), center=(0, 0, 10.5)); mb.add(v, f, 2)
    v, f, uv = lathe([(6.2, 0), (6.2, .25)], 14, cap_top=True); mb.add(v, f, 3, uvs=uv)
    v, f, uv = lathe([(1.6, .25), (1.8, .9), (1.5, 1.1)], 10, cap_top=True); mb.add(v, f, 4, uvs=uv)
    obj('Landmark_CloudPavilion_PLACEHOLDER', mb.build('CloudPavilion', ['wood_plank', 'ph_white', 'ph_aqua', 'stone_tile', 'ph_pink']), 'Landmarks', X, h0, Z)


def hopstones():
    for k, (Z, hh) in enumerate([(64, 3.5), (53, 7), (42, 10.5), (31, 14), (20, 17.5)]):
        mb = MB(); R = 5.0
        nseg = max(1, int(hh / 3.5))
        prof = [(R * 1.2, -2)] + [(R * (1.08 - .08 * t / nseg) * (1 + .07 * ((t + k) % 2)), hh * t / nseg - (.5 if t == nseg else 0)) for t in range(1, nseg + 1)]
        v, f, uv = lathe(prof, 7); v = wobble(v, 7, k, .09); mb.add(v, f, 0, uvs=[(a * .5, b * .6) for a, b in uv], colfn=shade_top(.8, 1.05))
        v, f, uv = lathe([(R * 1.0, hh - .5), (R * 1.1, hh - .2), (R * 1.0, hh)], 7, cap_top=True); mb.add(v, f, 1, uvs=uv)
        o = obj('Landmark_Hopstone_%d' % (k + 1), mb.build('Hopstone_%d' % (k + 1), ['cliff_rock', 'grass']), 'Landmarks', -117, 0, Z, rot=k * .4)
    mb = MB()
    v, f, uv = lathe([(12.5, -2), (11, 4), (11.6, 9), (10.4, 13), (11, 17), (10.0, 20.4)], 9); v = wobble(v, 9, 3, .1); mb.add(v, f, 0, uvs=[(a * .5, b * .6) for a, b in uv], colfn=shade_top(.8, 1.05))
    v, f, uv = lathe([(10.0, 20.4), (10.6, 20.75), (10.2, 21)], 9, cap_top=True); mb.add(v, f, 1, uvs=uv)
    o = obj('Landmark_LookoutLedge', mb.build('LookoutLedge', ['cliff_rock', 'grass']), 'Landmarks', -120, 0, 6, scale=(.9, .72, 1))
    for dx, dz, sz, hh in [(-8, 7, 8, 0), (9, 5, 7, 0), (3, -8, 9, 0), (-6, -6, 6, 9), (8, -2, 5, 12)]:
        rock('Landmarks', -120 + dx, 6 + dz, sz, h=hh, sink=.25)
    # the Wobble Egg: a giant speckled egg-boulder balanced on the ledge
    prof = [(0.02, 0), (1.5, .5), (2.6, 1.7), (2.95, 3.1), (2.6, 4.7), (1.7, 6.0), (.7, 6.8), (.02, 7.0)]
    v, f, uv = lathe(prof, 12)
    def eggcol(p, n):
        sp = 1.0 if fbm(p[0] * 1.3 + 4, p[1] * 1.3 + p[2] * 1.7, 12, 2) < .56 else .0
        band = .5 + .5 * math.sin(p[2] * 2.2)
        base = (1.0, .95, .90) if sp else (.55, .85, 1.0)
        k = .82 + .2 * (n[2] * .5 + .5)
        return (base[0] * k, base[1] * k, base[2] * k)
    me = MB().add(v, f, 0, uvs=uv, colfn=eggcol).build('WobbleEgg', ['egg'])
    obj('Landmark_WobbleEgg', me, 'Landmarks', -123, 20.9, 5, tilt=(.13, -.1))


def bubble_spring():
    X, Z = STATIONS['SpringBasin']; h0 = height(X, Z); mb = MB()
    v, f, uv = lathe([(4.2, -.3), (4.3, .45), (3.6, .55), (3.4, .1)], 12); mb.add(v, f, 0, uvs=uv)
    v, f, uv = lathe([(3.4, .32), (3.41, .33)], 12, cap_top=True); mb.add(v, f, 1, uvs=uv)
    v, f, uv = lathe([(1.2, .1), (.9, .9), (.5, 1.2), (.02, 1.3)], 8); mb.add(v, f, 0, uvs=uv)
    obj('Landmark_BubbleSpring_Basin', mb.build('BubbleSpringBasin', ['stone_tile', 'water']), 'Landmarks', X, h0, Z, scale=(1, .62, 1))
    for k, (dx, dz, hh, r) in enumerate([(0, 0, 2.6, .9), (-1.6, .4, 4.2, .55), (1.4, -.3, 5.4, .7), (.3, .6, 7.2, .4), (-2.6, -.6, 1.6, .35), (2.4, .5, 2.1, .45)]):
        v, f = blob(2, 0, rough=0, squash=(r, r, r))
        obj('Landmark_BubbleSpring_Bubble_%d' % k, MB().add(v, f, 0).build('Bubble_%d' % k, ['bubble']), 'Landmarks', X + dx, h0 + hh, Z + dz)


def swing():
    X, Z = -44.5, 82.5; h0 = height(X, Z); mb = MB()
    for sx in (-.9, .9):
        v, f = box(.07, .07, 5.6, (sx, 0, 3.6)); mb.add(v, f, 0)
    v, f = box(2.3, .8, .16, (0, 0, .85)); mb.add(v, f, 1)
    v, f, uv = tube([(-2.2, 0, 6.9), (0, 0, 6.4), (2.4, 0, 6.2)], [.4, .32, .22], 5); mb.add(v, f, 0, uvs=uv)
    obj('Landmark_BlossomSwing_PLACEHOLDER', mb.build('BlossomSwing', ['bark', 'wood_plank']), 'Landmarks', X, h0, Z, rot=.5)


def pad(name, X, Z, r=4.2):
    return disc(name, X, Z, r, 'stone_tile', 'Stations', lift=.2, segs=18, wob=.05, seed=int(abs(X * 7 + Z)))


def station(name, X, Z, build, mats, rot=0, smooth=False, coll='Stations', lift=.2):
    mb = MB(); build(mb)
    return obj(name, mb.build(name, mats, smooth=smooth), coll, X, height(X, Z) + lift, Z, rot=rot)


def b_table(mb, w=5.2, d=2.3, top=1.75, awning=False, back=False):
    v, f = box(w, d, .26, (0, 0, top)); mb.add(v, f, 0)
    for sx in (-1, 1):
        v, f = box(.34, d * .7, top, (sx * (w / 2 - .4), 0, top / 2)); mb.add(v, f, 1)
    if back:
        v, f = box(w * .9, .16, 1.5, (0, d / 2 - .1, top + .9)); mb.add(v, f, 1)
    if awning:
        for sx in (-1, 1):
            v, f = box(.2, .2, 4.6, (sx * (w / 2 + .1), d / 2, 2.3)); mb.add(v, f, 1)
        v, f = box(w + 1.2, d + 1.6, .14, (0, -.1, 4.75)); mb.add(v, f, 2, M=Matrix.Rotation(.12, 4, 'X'))


def b_care(mb):
    v, f, uv = lathe([(2.3, 0), (2.4, .5), (2.1, 2.6), (2.2, 3.0)], 12, cap_top=True); mb.add(v, f, 0, uvs=uv)
    v, f, uv = lathe([(1.9, 3.0), (1.75, 4.1), (1.15, 4.9), (.05, 5.2)], 12); mb.add(v, f, 1, uvs=uv)
    v, f = box(1.9, .25, 1.2, (0, -2.1, 1.8)); mb.add(v, f, 2)
    v, f = box(.5, .3, .3, (-1.2, -2.25, .9)); mb.add(v, f, 3)
    v, f = box(.5, .3, .3, (1.2, -2.25, .9)); mb.add(v, f, 4)
    v, f = blob(1, 2, rough=0, squash=(.55, .55, .7), center=(0, 0, 3.85)); mb.add(v, f, 5)


def b_bench(mb):
    v, f = box(5.3, 1.5, .24, (0, 0, 1.05)); mb.add(v, f, 0)
    v, f = box(5.3, .22, 1.1, (0, .7, 1.8)); mb.add(v, f, 0)
    for sx in (-2.1, 2.1):
        v, f = box(.3, 1.25, 1.0, (sx, 0, .5)); mb.add(v, f, 1)


def b_picnic(mb):
    v, f = box(5.2, 2.4, .25, (0, 0, 1.3)); mb.add(v, f, 0)
    for s in (-1, 1):
        v, f = box(5.8, .9, .22, (0, s * 2.1, .75)); mb.add(v, f, 0)
        for e in (-1, 1):
            v, f = box(.3, 4.6, .3, (e * 1.9, 0, .45)); mb.add(v, f, 1)
            v, f = box(.3, .3, 1.2, (e * 1.9, s * .7, .65)); mb.add(v, f, 1)


def b_nest(mb):
    v, f, uv = lathe([(3.5, -.2), (3.3, .35), (2.6, .5)], 12, cap_top=True); mb.add(v, f, 0, uvs=uv)
    v, f, uv = lathe([(1.5, .5), (1.75, .9), (1.4, 1.05), (1.0, .8)], 10); mb.add(v, f, 1, uvs=uv)
    prof = [(.02, .8), (.55, .95), (.95, 1.5), (1.02, 2.0), (.85, 2.6), (.5, 3.05), (.02, 3.2)]
    v, f, uv = lathe(prof, 10)
    mb.add(v, f, 2, uvs=uv, colfn=lambda p, n: (.55, .9, 1.0) if math.sin(p[2] * 5.5 + math.atan2(p[1], p[0]) * 2) > .55 else (1, 1, 1))


def b_cushion(mb, mat=0):
    v, f, uv = lathe([(.1, 0), (1.9, .05), (2.2, .3), (1.9, .55), (.1, .6)], 12); mb.add(v, f, mat, uvs=uv)


def b_toys(mb):
    v, f = blob(2, 0, rough=0, squash=(.9, .9, .9), center=(-2.4, 0, .9))
    mb.add(v, f, 0, colfn=lambda p, n: (1, 1, 1) if (math.atan2(p[1], p[0] + 2.4) * 3 / 3.1416) % 2 < 1 else (.5, .85, 1))
    for k, (x, y, s, m) in enumerate([(1.2, .3, 1.1, 1), (2.4, -.2, 1.1, 2), (1.8, .1, 1.1, 3)]):
        v, f = box(s, s, s, (x, y, s / 2 + (1.1 if k == 2 else 0))); mb.add(v, f, m)
    v, f, uv = tube([(math.cos(a / 10 * 6.283) * 1.1, 2.6 + math.sin(a / 10 * 6.283) * 1.1, .28) for a in range(11)], [.28] * 11, 6); mb.add(v, f, 4, uvs=uv)


def b_spawn(mb):
    v, f, uv = lathe([(4.2, -.2), (4.0, .22), (3.2, .3)], 14, cap_top=True); mb.add(v, f, 0, uvs=uv)
    v, f, uv = lathe([(2.2, .3), (2.2, .36)], 14, cap_top=True); mb.add(v, f, 1, uvs=uv)


def bridge(name, X, Z, L, Wd):
    def build(mb):
        n = int(L / .9)
        for k in range(n):
            v, f = box(L / n - .06, Wd, .22, (-L / 2 + (k + .5) * L / n, 0, .02)); mb.add(v, f, 0 if k % 2 else 1)
        for s in (-1, 1):
            v, f = box(L, .16, .16, (0, s * (Wd / 2 - .15), 1.15)); mb.add(v, f, 0)
            for e in (-1, 0, 1):
                v, f = box(.24, .24, 1.6, (e * (L / 2 - .3), s * (Wd / 2 - .15), .45)); mb.add(v, f, 1)
    return station(name, X, Z, build, ['wood_plank', 'bark'], coll='Bridges', lift=.22)


def lamp_mesh():
    mb = MB()
    v, f, uv = lathe([(.42, 0), (.2, .35), (.14, 3.6), (.34, 3.8)], 6); mb.add(v, f, 0, uvs=uv)
    v, f = blob(1, 0, rough=0, squash=(.62, .62, .62), center=(0, 0, 4.45)); mb.add(v, f, 1)
    v, f, uv = lathe([(.5, 4.95), (.12, 5.25)], 6); mb.add(v, f, 0, uvs=uv)
    return mb.build('Lamp', ['bark', 'glow_warm'])


def mountain(name, X, Z, R, H, seed, snow=.56, base=None):
    r = random.Random(seed); sides = 9; fr = [0, .22, .45, .66, .84, 1.0]
    dist = math.hypot(X, Z); haze = min(.78, .30 + dist / 2600)
    V = []; rings = []
    ridge = r.uniform(0, 6.28)
    for j, t in enumerate(fr):
        rad = R * (1 - t) ** .85 + (R * .015 if j == len(fr) - 1 else 0)
        for i in range(sides):
            a = 2 * math.pi * i / sides + j * .25
            k = 1 + .34 * (r.random() - .5) + .22 * math.cos(2 * (a - ridge))
            V.append((math.cos(a) * rad * k, math.sin(a) * rad * k, SEA + H * t * (1 + .10 * (r.random() - .5)) - (30 if j == 0 else 0)))
    F = []
    for j in range(len(fr) - 1):
        for i in range(sides):
            a = j * sides + i; b = j * sides + (i + 1) % sides
            F.append([a, b, b + sides, a + sides])
    bc = Vector(lin(base or ('#93A7E2', '#A59BE0', '#86B4E6', '#9AA2E8')[seed % 4])); sn = Vector(lin('#FFFFFF')); gr = Vector(lin('#9FD9B6'))

    def colfn(p, n):
        t = (p[2] - SEA) / H
        c = gr.lerp(bc, S(t / .28)) if t < .3 else bc.lerp(sn, S((t - snow + .08 * (fbm(p[0] / 60, p[1] / 60, seed) - .5)) / .10))
        lit = .80 + .26 * max(0, Vector(n).dot(SUN))
        c = c * lit
        c = c.lerp(HAZE, haze * (1 - .45 * t))
        return (c.x, c.y, c.z)
    mb = MB(); mb.add(V, F, 0, colfn=colfn, scale=1 / 90)
    me = mb.build(name, ['far_peak'])
    bm = bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm, faces=bm.faces); bm.to_mesh(me); bm.free()
    # recolour after normals are outward
    return obj(name, me, 'Distant', X, 0, Z)


def sea_stack(name, X, Z, R, H, tree=True):
    """Mid-distance islet: gives parallax between the rim and the far peaks."""
    mb = MB(); r = random.Random(int(X + Z)); Hh = (H - SEA) / 2 + 6
    v, f = blob(2, r.randrange(999), rough=.2, chisel=9, squash=(R * 1.1, R * 1.1, Hh * 1.15), center=(0, 0, SEA + Hh - 8))
    v = [(p[0], p[1], min(p[2], H)) for p in v]
    mb.add(v, f, 0, colfn=shade_top(.84, 1.12), scale=1 / 26)
    vv, ff = blob(2, r.randrange(99), rough=.2, squash=(R * .8, R * .8, R * .22), center=(0, 0, H))
    mb.add(vv, ff, 1, colfn=leaf_col, scale=.05)
    obj(name, mb.build(name, ['cliff_rock', 'grass']), 'Distant', X, 0, Z)
    if tree:
        obj(name + '_Tree', TREE['round'], 'Distant', X + R * .15, H + R * .12, Z, scale=R / 10, rot=r.uniform(0, 6))


def cloud(name, X, h, Z, sc, seed):
    r = random.Random(seed); mb = MB()
    def colfn(p, n):
        k = .86 + .14 * (n[2] * .5 + .5)
        return (k * 1.02, k * 1.03, k * 1.08) if n[2] > -.2 else (.80, .88, 1.0)
    for k in range(r.randrange(4, 7)):
        rr = r.uniform(.55, 1.0)
        v, f = blob(1, r.randrange(999), rough=.12, squash=(rr * 1.4, rr, rr * .7), center=(r.uniform(-1.6, 1.6), r.uniform(-.6, .6), r.uniform(0, .35)), flat_bottom=-.28)
        mb.add(v, f, 0, colfn=colfn)
    obj(name, mb.build(name, ['cloud']), 'Distant', X, h, Z, scale=sc, rot=r.uniform(0, 6.28))


def avatar(name, X, Z, rot=0):
    mb = MB()
    for sx in (-.5, .5):
        v, f = box(.96, .96, 2, (sx, 0, 1)); mb.add(v, f, 2)
        v, f = box(.96, .96, 2, (sx * 3, 0, 3)); mb.add(v, f, 0)
    v, f = box(2, 1, 2, (0, 0, 3)); mb.add(v, f, 1)
    v, f, uv = lathe([(.02, 4.05), (.6, 4.1), (.75, 4.45), (.75, 5.05), (.6, 5.4), (.02, 5.45)], 10); mb.add(v, f, 0, uvs=uv)
    return obj(name, mb.build(name, ['avatar_skin', 'avatar_shirt', 'avatar_pants']), 'REF', X, height(X, Z), Z, rot=rot)


def import_bear():
    before = set(bpy.data.objects)
    ok = False
    for op in ('wm.fbx_import', 'import_scene.fbx'):
        try:
            mod, fn = op.split('.'); getattr(getattr(bpy.ops, mod), fn)(filepath=BEAR); ok = True; break
        except Exception as e:
            print('bear import via', op, 'failed:', e)
    new = [o for o in bpy.data.objects if o not in before]
    if not ok or not new: return None
    for o in list(new):                                           # a new pet starts with no wings and no charm
        if 'Wing' in o.name or 'Charm' in o.name:
            new.remove(o); bpy.data.objects.remove(o, do_unlink=True)
    tdir = os.path.join(os.path.dirname(BEAR), 'bear-textures')
    for img in bpy.data.images:
        fp = bpy.path.abspath(img.filepath) if img.filepath else ''
        if fp and not os.path.exists(fp):
            cand = os.path.join(tdir, os.path.basename(fp))
            if not os.path.exists(cand):
                key = next((k for k in ('eye', 'mouth', 'wing') if k in os.path.basename(fp).lower() or k in img.name.lower()), None)
                cand = os.path.join(tdir, 'bear-%s.png' % key) if key else ''
            if cand and os.path.exists(cand):
                img.filepath = cand; img.reload(); print('bear texture ->', os.path.basename(cand))
            else:
                print('bear texture MISSING', img.name, fp)
    root = bpy.data.objects.new('REF_Bear', None); COL['REF'].objects.link(root)
    lo = Vector((1e9,) * 3); hi = Vector((-1e9,) * 3)
    bpy.context.view_layer.update()
    for o in new:
        for c in list(o.users_collection): c.objects.unlink(o)
        COL['REF'].objects.link(o)
        if o.type == 'MESH':
            for c in o.bound_box:
                w = o.matrix_world @ Vector(c)
                lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
    Hh = hi.z - lo.z
    for o in new:
        if o.parent is None: o.parent = root
    k = 2.3 / Hh if Hh > 1e-6 else 1
    root.scale = (k, k, k)
    X, Z = 1.2, 7.6
    root.location = Vector(B(X, height(X, Z), Z)) - Vector((0, 0, lo.z * k))
    root.rotation_euler = (0, 0, -.35)
    print('BEAR imported', len(new), 'objects, source height', round(Hh, 3), 'scale', round(k, 3))
    return root, new, k


def cam(name, pos, look, lens=28):
    c = bpy.data.cameras.new(name); c.lens = lens; c.clip_start = .3; c.clip_end = 9000; c.sensor_width = 36
    o = bpy.data.objects.new(name, c)
    p = Vector(B(*pos)); t = Vector(B(*look))
    o.location = p; o.rotation_euler = (t - p).to_track_quat('-Z', 'Y').to_euler()
    COL['Sky_Lighting'].objects.link(o); return o
