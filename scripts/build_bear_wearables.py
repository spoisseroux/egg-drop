"""Build the Bear's launch wearables (final art) in pet-bear-attachments.blend.

Run on its own (background Blender only), or let scripts/export_bear_attachments.py run it:
  blender -b assets/art-source/pets/pet-bear-attachments.blend --python scripts/build_bear_wearables.py -- [--no-save]

Every wearable is rebuilt from code on each run into the `PetBear_Wearables` collection; the old
grey-box `PetBear_AttachPlaceholders` collection is removed. Conventions (PET-STYLE-GUIDE.md,
"Character creation"): mesh `PetBear__<Slot>_<Variant>[_<Piece>]` (eyes and mouths keep the importer's
`Eye*` / `Mouth*` prefix: `EyeL_Alt<Variant>[_<Piece>]`), parented to its anchor with an identity
transform, one material per mesh, a UV map, smooth shading.

An item is one or more meshes that share an item id (`variant`, lower-cased). Pieces exist because a mesh
has one colour: each piece is either tinted by the pet's secondary colour (`tintBySecondary`), drawn in the
face ink, or keeps its own colour (`ownColor`). A shirt is always Torso + SleeveL + SleeveR, plus trim.
"""
import bpy, bmesh, math, sys
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

D = bpy.data.objects
root = D["PetBear"]
TIERS = {"common": 15, "rare": 30, "showcase": 60}   # suggested Star prices

# item id -> shop data. Order is the lineup order.
ITEMS = {
    "beanie":      dict(slot="Hat", name="Pom Beanie", tier="common", flags=dict(coversHorns=True)),
    "sunhat":      dict(slot="Hat", name="Tiny Sun Hat", tier="rare", flags=dict(coversHorns=True)),
    "flowercrown": dict(slot="Hat", name="Flower Crown", tier="showcase", flags=dict(openCrown=True, lowBrim=True)),
    "tee":         dict(slot="Shirt", name="Stripy Tee", tier="common", flags={}),
    "hoodie":      dict(slot="Shirt", name="Star Hoodie", tier="showcase", flags=dict(printedChest=True)),
    "beads":       dict(slot="Neck", name="Pearl Beads", tier="common", flags={}),
    "bellcollar":  dict(slot="Neck", name="Bell Collar", tier="rare", flags={}),
    "ring":        dict(slot="EarPiercing", name="Little Hoops", tier="common", flags={}),
    "starstud":    dict(slot="EarPiercing", name="Star Studs", tier="rare", flags={}),
    "sparkle":     dict(slot="Eyes", name="Sparkle Eyes", tier="rare", flags={}),
    "sleepy":      dict(slot="Eyes", name="Sleepy Eyes", tier="common", flags={}),
    "blep":        dict(slot="Mouth", name="Blep", tier="common", flags=dict(neutralOnly=True)),
    "heart":       dict(slot="Tail", name="Heart Tail", tier="rare", flags={}),
    # Slice A (2026-11-14): replace the beady Wide Eyes (Spencer: "creepy"); cozy-sim conventions, original shapes.
    "happy":       dict(slot="Eyes", name="Happy Eyes", tier="common", flags={}),
    "lash":        dict(slot="Eyes", name="Lash Eyes", tier="common", flags={}),
}

# own colours (sRGB hex). Everything else is the pet's secondary or the face ink.
C_BEANIE, C_STRAW, C_LEAF, C_POLLEN = "#E9574C", "#F3D37E", "#58B368", "#FFD23F"
C_TEE, C_HOODIE, C_PEARL, C_GOLD = "#33539E", "#8E7BE8", "#FFF2D6", "#FFC240"
C_WHITE, C_TONGUE = "#FFFFFF", "#FF7C9C"

SHELL = 0.024                # shirt torso above the body
SLEEVE_OFFSET = 0.020        # sleeve surface above the arm surface
SLEEVE_AXIS = (-0.525, -0.277, -0.805)   # down the left arm from the shoulder (pet-local); x mirrors for R
SLEEVE_CUFF_T = 0.268        # where the cuff plane crosses the arm axis, measured from the shoulder anchor
SLEEVE_CUFF_LEAN = (0.90, 0.40, 0.0)     # the cuff gets longer in this direction (toward the body, a bit back)
SLEEVE_CUFF_SLOPE = 0.62     # extra sleeve length per unit of distance from the axis along the lean
SLEEVE_LIP = 0.030           # the cuff turns in this far, so it closes onto the arm
HEM_Z, COLLAR_Z = 0.355, 0.705           # pet-local; body-local -0.10 and +0.25


# ---------------------------------------------------------------- scene helpers
def world(o):
    m = o.matrix_parent_inverse @ o.matrix_basis
    return (world(o.parent) @ m) if o.parent else o.matrix_basis.copy()


ROOT_INV = world(root).inverted()


def local(o):
    return ROOT_INV @ world(o)


def anchor(name):
    return D["PetBear__Anchor_" + name]


def bvh_of(*names):
    vs, ts = [], []
    for n in names:
        o = D["PetBear__" + n]
        m = local(o)
        base = len(vs)
        vs += [m @ v.co for v in o.data.vertices]
        o.data.calc_loop_triangles()
        ts += [tuple(base + i for i in t.vertices) for t in o.data.loop_triangles]
    return BVHTree.FromPolygons(vs, ts)


HEAD = bvh_of("Head")
FACE = bvh_of("Head", "Muzzle")
BODY = bvh_of("Body")


def srgb(hexcode):
    def lin(c):
        c /= 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    h = hexcode.lstrip("#")
    return (lin(int(h[0:2], 16)), lin(int(h[2:4], 16)), lin(int(h[4:6], 16)), 1.0)


def own_material(hexcode, rough=0.6, metallic=0.0):
    name = "wear__" + hexcode.lstrip("#").upper() + ("_metal" if metallic else "")
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = srgb(hexcode)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metallic
    mat.diffuse_color = srgb(hexcode)
    mat["ownColor"] = hexcode.upper()
    return mat


def ink_material():
    mat = bpy.data.materials.get("attach__ink") or bpy.data.materials.new("attach__ink")
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (0.03, 0.03, 0.05, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.2
    return mat


SECONDARY = bpy.data.materials["petBear__secondary"]

# ---------------------------------------------------------------- collection reset
for cname in ("PetBear_AttachPlaceholders", "PetBear_Wearables"):
    col = bpy.data.collections.get(cname)
    if col:
        for o in list(col.objects):
            me = o.data
            bpy.data.objects.remove(o, do_unlink=True)
            if me.users == 0:
                bpy.data.meshes.remove(me)
        bpy.data.collections.remove(col)
WEAR = bpy.data.collections.new("PetBear_Wearables")
bpy.context.scene.collection.children.link(WEAR)
BUILT = []


def finish(short, bm, anchor_name, color, item, role, channel, piece="Main", fix_normals=True, facing=None, **props):
    """bm is in pet-local coordinates. color: 'secondary', 'face' or an own '#RRGGBB'.
    facing: for thin face pieces, the direction every island must look (instead of away from its centre)."""
    if fix_normals:
        outward(bm, facing)
    for f in bm.faces:
        f.smooth = True
    a = anchor(anchor_name)
    bmesh.ops.transform(bm, matrix=local(a).inverted(), verts=bm.verts[:])
    uv = bm.loops.layers.uv.new("UVMap")
    lo = Vector([min(v.co[i] for v in bm.verts) for i in range(3)])
    size = Vector([max(max(v.co[i] for v in bm.verts) - lo[i], 1e-6) for i in range(3)])
    flat = min(range(3), key=lambda i: size[i])          # box-project along the thinnest axis
    ua, va = [i for i in range(3) if i != flat]
    for f in bm.faces:
        for l in f.loops:
            l[uv].uv = ((l.vert.co[ua] - lo[ua]) / size[ua], (l.vert.co[va] - lo[va]) / size[va])
    name = "PetBear__" + short
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    if color == "secondary":
        mat, role_name = SECONDARY, "secondary"
    elif color == "face":
        mat, role_name = ink_material(), "face"
    else:
        metal = color == C_GOLD
        mat = own_material(color, rough=0.28 if metal else (0.3 if color in (C_PEARL, C_WHITE) else 0.7),
                           metallic=0.0)
        role_name = "own:" + color.upper()
    me.materials.append(mat)
    me.calc_loop_triangles()
    ob = bpy.data.objects.new(name, me)
    WEAR.objects.link(ob)
    ob.parent = a
    ob.matrix_parent_inverse = Matrix.Identity(4)
    ob.matrix_basis = Matrix.Identity(4)
    info = ITEMS[item]
    data = dict(role=role, channel=channel, slot=info["slot"], variant=item, item=item, piece=piece,
                displayName=info["name"], tier=info["tier"], price=TIERS[info["tier"]],
                colorRole=role_name, tintBySecondary=color == "secondary", optional=True,
                tris=len(me.loop_triangles))
    if info["slot"] in ("Eyes", "Mouth", "Tail"):
        data["alternate"] = True
    data.update(info["flags"])
    data.update(props)
    for k, v in data.items():
        ob[k] = v
    ob.hide_render = True
    BUILT.append(ob)
    return ob


# ---------------------------------------------------------------- mesh helpers
def outward(bm, facing=None):
    """Consistent normals, then make each island point away from its own centre (or along `facing`)."""
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.faces.index_update()
    seen = set()
    for start in bm.faces:
        if start.index in seen:
            continue
        island, stack = [], [start]
        seen.add(start.index)
        while stack:
            f = stack.pop()
            island.append(f)
            for e in f.edges:
                for g in e.link_faces:
                    if g.index not in seen:
                        seen.add(g.index)
                        stack.append(g)
        centre = sum((f.calc_center_median() for f in island), Vector()) / len(island)
        if facing is not None:
            score = sum(f.normal.dot(facing) * f.calc_area() for f in island)
        else:
            score = sum(f.normal.dot(f.calc_center_median() - centre) * f.calc_area() for f in island)
        if score < 0:
            for f in island:
                f.normal_flip()


def ring_faces(bm, a, b, closed=True):
    n = len(a)
    for i in range(n if closed else n - 1):
        j = (i + 1) % n
        if len(a) == len(b):
            bm.faces.new((a[i], a[j], b[j], b[i]))


def fan(bm, pole, ring, closed=True):
    n = len(ring)
    for i in range(n if closed else n - 1):
        bm.faces.new((pole, ring[i], ring[(i + 1) % n]))


def lathe(bm, profile, segs, M=Matrix.Identity(4), squash=(1.0, 1.0), wave=None):
    """profile: [(radius, z)], radius 0 makes a pole. wave(angle, r, z) -> dz for wobbly brims."""
    prev = None
    for r, z in profile:
        if r <= 1e-9:
            cur = bm.verts.new(M @ Vector((0, 0, z)))
        else:
            cur = []
            for i in range(segs):
                a = 2 * math.pi * i / segs
                dz = wave(a, r, z) if wave else 0.0
                sq = squash(r) if callable(squash) else squash
                cur.append(bm.verts.new(M @ Vector((r * sq[0] * math.cos(a), r * sq[1] * math.sin(a), z + dz))))
        if prev is not None:
            if isinstance(prev, list) and isinstance(cur, list):
                ring_faces(bm, prev, cur)
            elif isinstance(prev, list):
                fan(bm, cur, prev)
            elif isinstance(cur, list):
                fan(bm, prev, cur)
        prev = cur


def ball(bm, centre, radius, segs=6, rings=3, scale=(1, 1, 1), M=None):
    prof = [(0.0, -radius)] + [(radius * math.sin(math.pi * k / (rings + 1)), -radius * math.cos(math.pi * k / (rings + 1)))
                               for k in range(1, rings + 1)] + [(0.0, radius)]
    base = M if M is not None else Matrix.Identity(4)
    lathe(bm, prof, segs, Matrix.Translation(centre) @ base.to_3x3().to_4x4() @ Matrix.Diagonal((*scale, 1.0)))


def tube(bm, pts, radii, sides=4, closed=False, flat=1.0, up=Vector((0, 0, 1)), cap=True):
    """Sweep a ring along pts. flat squashes the section across `up` (a strap when flat < 1)."""
    n = len(pts)
    rings = []
    carried, last_t = None, None
    for i, p in enumerate(pts):
        a = pts[(i - 1) % n] if (closed or i > 0) else p
        b = pts[(i + 1) % n] if (closed or i < n - 1) else p
        t = (b - a).normalized()
        if closed or carried is None:
            side = t.cross(up)
            side = side.normalized() if side.length > 1e-6 else Vector((1, 0, 0))
        else:       # open tubes carry the frame along, so a tube that turns upright never pinches
            side = (last_t.rotation_difference(t) @ carried).normalized()
        carried, last_t = side, t
        u = side.cross(t).normalized()
        r = radii[i] if isinstance(radii, (list, tuple)) else radii
        rings.append([bm.verts.new(p + (side * math.cos(2 * math.pi * k / sides + math.pi / sides) * flat
                                        + u * math.sin(2 * math.pi * k / sides + math.pi / sides)) * r)
                      for k in range(sides)])
    for i in range(n if closed else n - 1):
        ring_faces(bm, rings[i], rings[(i + 1) % n])
    if cap and not closed:
        for ring, p, q in ((rings[0], pts[0], pts[1]), (rings[-1], pts[-1], pts[-2])):
            r0 = radii[0] if isinstance(radii, (list, tuple)) else radii
            fan(bm, bm.verts.new(p + (p - q).normalized() * r0 * 0.5), ring)
    return rings


def star_outline(points=5, inner=0.5, rot=math.pi / 2):
    return [((1.0 if i % 2 == 0 else inner) * math.cos(rot + math.pi * i / points),
             (1.0 if i % 2 == 0 else inner) * math.sin(rot + math.pi * i / points)) for i in range(points * 2)]


def ellipse_outline(n=12, rx=1.0, rz=1.0):
    return [(rx * math.cos(2 * math.pi * i / n), rz * math.sin(2 * math.pi * i / n)) for i in range(n)]


def heart_outline(n=16):
    pts = []
    for i in range(n):
        t = 2 * math.pi * i / n
        pts.append((16 * math.sin(t) ** 3 / 17.0,
                    (13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t) + 2.5) / 17.0))
    return pts


def flower_outline(petals=5, notch=0.5):
    out = []
    for i in range(petals):
        a = math.pi / 2 + 2 * math.pi * i / petals
        w = math.pi / petals
        out += [(notch * math.cos(a - w), notch * math.sin(a - w)),
                (0.92 * math.cos(a - w * 0.45), 0.92 * math.sin(a - w * 0.45)),
                (0.92 * math.cos(a + w * 0.45), 0.92 * math.sin(a + w * 0.45))]
    return out


def puff(bm, origin, x_axis, y_axis, normal, outline, size, rise, mid=0.6, rim=0.0, sink=0.0, back=None):
    """A cushion over a 2D outline in the plane (x_axis, y_axis): raised centre, optional mid ring,
    rim on the plane, optional skirt sunk below it (into the surface) or a closing back bulge."""
    def at(u, v, h):
        return bm.verts.new(origin + x_axis * (u * size) + y_axis * (v * size) + normal * h)
    top = at(0, 0, rise)
    cu = sum(p[0] for p in outline) / len(outline)
    cv = sum(p[1] for p in outline) / len(outline)
    ring = [at(u, v, rim) for u, v in outline]
    if mid:
        inner = [at(cu + (u - cu) * mid, cv + (v - cv) * mid, rim + (rise - rim) * 0.72) for u, v in outline]
        fan(bm, top, inner)
        ring_faces(bm, inner, ring)
    else:
        fan(bm, top, ring)
    if sink:
        ring_faces(bm, ring, [at(cu + (u - cu) * 0.9, cv + (v - cv) * 0.9, -sink) for u, v in outline])
    if back is not None:
        fan(bm, at(cu, cv, -back), ring)


def face_y(x, z, tree=None):
    """Front (-Y) surface of the face at pet-local (x, z)."""
    hit = (tree or FACE).ray_cast(Vector((x, -3.0, z)), Vector((0, 1, 0)))
    return hit[0].y if hit[0] else -0.40


def face_patch(bm, cx, cz, outline, rise, rim=0.004, sink=0.012, mid=0.6, tree=None, lift=0.0):
    """A cushion that follows the face: outline is [(dx, dz)] in studs around (cx, cz)."""
    def at(dx, dz, h):
        return bm.verts.new(Vector((cx + dx, face_y(cx + dx, cz + dz, tree) - h - lift, cz + dz)))
    mx = sum(p[0] for p in outline) / len(outline)
    mz = sum(p[1] for p in outline) / len(outline)
    top = at(mx, mz, rise)
    ring = [at(dx, dz, rim) for dx, dz in outline]
    if mid:
        inner = [at(mx + (dx - mx) * mid, mz + (dz - mz) * mid, rim + (rise - rim) * 0.75) for dx, dz in outline]
        fan(bm, top, inner)
        ring_faces(bm, inner, ring)
    else:
        fan(bm, top, ring)
    ring_faces(bm, ring, [at(mx + (dx - mx) * 0.92, mz + (dz - mz) * 0.92, -sink) for dx, dz in outline])


def face_stroke(bm, cx, cz, line, width, rise=0.010, sink=0.006, taper=0.35, tree=None):
    """An ink stroke that follows the face. line is [(dx, dz)]; it tapers at both ends."""
    n = len(line)
    rows = []
    for i, (dx, dz) in enumerate(line):
        a = line[max(i - 1, 0)]
        b = line[min(i + 1, n - 1)]
        t = Vector((b[0] - a[0], b[1] - a[1])).normalized()
        nrm = Vector((-t.y, t.x))
        k = min(i, n - 1 - i) / max(1, (n - 1) / 2)
        w = width * 0.5 * (taper + (1 - taper) * min(1.0, k * 2.2))
        row = []
        for s, h in ((-1.0, -sink), (-0.62, rise), (0.62, rise), (1.0, -sink)):     # flat-topped ribbon
            x, z = cx + dx + nrm.x * w * s, cz + dz + nrm.y * w * s
            row.append(bm.verts.new(Vector((x, face_y(x, z, tree) - h, z))))
        rows.append(row)
    for i in range(n - 1):
        ring_faces(bm, rows[i], rows[i + 1], closed=False)
    for row, (dx, dz), other in ((rows[0], line[0], line[1]), (rows[-1], line[-1], line[-2])):
        d = Vector((dx - other[0], dz - other[1])).normalized() * width * 0.3
        x, z = cx + dx + d.x, cz + dz + d.y
        tip = bm.verts.new(Vector((x, face_y(x, z, tree) + sink, z)))
        fan(bm, tip, row, closed=False)


def arc(cx, cz, rx, rz, a0, a1, n):
    return [(cx + rx * math.cos(math.radians(a0 + (a1 - a0) * i / (n - 1))),
             cz + rz * math.sin(math.radians(a0 + (a1 - a0) * i / (n - 1)))) for i in range(n)]


# ================================================================= HATS
crown = local(anchor("HatCrown"))
CROWN_P = crown.translation


def head_top(x, y):
    hit = HEAD.ray_cast(Vector((x, y, 3.0)), Vector((0, 0, -1)))
    return hit[0], hit[1]


# ---- Pom Beanie: a puffy knit dome (own coral), rolled cuff and pom (secondary)
# It bulges above the cuff: the ears lean away up there, so the dome can be wider than the 0.19 cuff.
tilt = Matrix.Translation(CROWN_P) @ Matrix.Rotation(math.radians(-7), 4, "X")   # slouches back a little
bm = bmesh.new()
lathe(bm, [(0.184, -0.020), (0.199, 0.028), (0.198, 0.070), (0.170, 0.106), (0.104, 0.126), (0.0, 0.132)], 14, tilt,
      squash=(1.0, 1.06))
finish("Hat_Beanie", bm, "HatCrown", C_BEANIE, "beanie", "Hat", "Head", height=0.18)
bm = bmesh.new()
lathe(bm, [(0.158, -0.082), (0.184, -0.066), (0.192, -0.044), (0.192, -0.016), (0.188, 0.002), (0.174, 0.008)], 14, tilt,
      squash=(1.0, 1.06))
ball(bm, tilt @ Vector((0, 0, 0.133)), 0.047, segs=7, rings=3)
finish("Hat_Beanie_Trim", bm, "HatCrown", "secondary", "beanie", "Hat", "Head", piece="Trim")

# ---- Tiny Sun Hat: straw crown and brim (own straw), ribbon and bow (secondary)
# The brim is an oval: 0.19 across so it passes between the ears, longer front to back so it shades the face.
tilt = Matrix.Translation(CROWN_P) @ Matrix.Rotation(math.radians(5), 4, "X") @ Matrix.Rotation(math.radians(4), 4, "Y")
wave = lambda a, r, z: 0.008 * math.sin(a * 2 + 0.4) * max(0.0, (r - 0.13) / 0.06)
oval = lambda r: (1.0, 1.0 + 0.42 * min(1.0, max(0.0, (r - 0.125) / 0.065)))
bm = bmesh.new()
lathe(bm, [(0.0, 0.128), (0.070, 0.122), (0.112, 0.098), (0.124, 0.050), (0.120, -0.002),          # crown
           (0.150, -0.010), (0.190, -0.024), (0.186, -0.038), (0.140, -0.042), (0.100, -0.058)],     # brim, top then underside
      16, tilt, squash=oval, wave=wave)
finish("Hat_SunHat", bm, "HatCrown", C_STRAW, "sunhat", "Hat", "Head", height=0.13)
bm = bmesh.new()
lathe(bm, [(0.120, -0.006), (0.133, 0.000), (0.135, 0.038), (0.122, 0.044)], 16, tilt)
ang = math.radians(-58)                              # bow at the front right, two puffy loops and a knot
out = (tilt.to_3x3() @ Vector((math.cos(ang), math.sin(ang), 0))).normalized()
tang = (tilt.to_3x3() @ Vector((-math.sin(ang), math.cos(ang), 0))).normalized()
upv = tilt.to_3x3() @ Vector((0, 0, 1))
knot = tilt @ Vector((0.130 * math.cos(ang), 0.130 * math.sin(ang), 0.020))
for sx in (-1, 1):
    loop = [(0.0, 0.0), (0.55, 0.60), (1.0, 0.46), (1.0, -0.46), (0.55, -0.60)]
    puff(bm, knot + out * 0.004, tang * sx, upv, out, loop, 0.066, 0.030, mid=0.0, rim=0.0, sink=0.014)
ball(bm, knot + out * 0.012, 0.020, segs=5, rings=2)
finish("Hat_SunHat_Band", bm, "HatCrown", "secondary", "sunhat", "Hat", "Head", piece="Band")

# ---- Flower Crown: a wreath round the whole head, low on the brow and under the ears.
# Leafy vine (own green), eight blossoms (secondary), pollen centres (own yellow). Horns and ears stay visible.
def brow(deg, lift=0.0):
    """Point and normal on the wreath line: 270 = front. The ring tilts, high on the brow, low at the back."""
    a = math.radians(deg)
    d = Vector((math.cos(a), math.sin(a), 0))
    z = 1.172 - 0.088 * math.sin(a)
    hit = HEAD.ray_cast(Vector((0, -0.03, z)) + d * 2.0, -d)
    return hit[0] + hit[1] * lift, hit[1], d


vine, petals, centers = bmesh.new(), bmesh.new(), bmesh.new()
tube(vine, [brow(360 * i / 20, 0.008)[0] for i in range(20)], 0.019, sides=3, closed=True)
FLOWERS = [(270, 0.078), (238, 0.062), (302, 0.062), (207, 0.070), (333, 0.070), (140, 0.058), (90, 0.066), (40, 0.058)]
LEAVES = [254, 286, 222, 318, 186, 354, 115, 65]
for deg, size in FLOWERS:
    p, n, radial = brow(deg, 0.016)
    face = (n + Vector((0, 0, 0.25))).normalized()
    x_axis = face.cross(Vector((0, 0, 1))).normalized()
    y_axis = x_axis.cross(face).normalized()
    puff(petals, p, x_axis, y_axis, face, flower_outline(5, 0.50), size, 0.024, mid=0.0, rim=0.006, back=0.026)
    puff(centers, p + face * 0.016, x_axis, y_axis, face, ellipse_outline(5), size * 0.36, size * 0.36, mid=0.0, sink=0.012)
for deg in LEAVES:
    p, n, radial = brow(deg, 0.012)
    tangent = Vector((-radial.y, radial.x, 0))
    lf = (n + Vector((0, 0, 0.5))).normalized()
    upish = lf.cross(tangent).normalized()
    leaf = [(-1.0, 0.0), (-0.35, 0.50), (0.45, 0.42), (1.0, 0.0), (0.45, -0.42), (-0.35, -0.50)]
    puff(vine, p + upish * 0.022, upish, tangent, lf, leaf, 0.046, 0.014, mid=0.0, rim=0.0, back=0.016)
finish("Hat_FlowerCrown", vine, "HatCrown", C_LEAF, "flowercrown", "Hat", "Head", piece="Vine", height=0.0)
finish("Hat_FlowerCrown_Petals", petals, "HatCrown", "secondary", "flowercrown", "Hat", "Head", piece="Petals")
finish("Hat_FlowerCrown_Centers", centers, "HatCrown", C_POLLEN, "flowercrown", "Hat", "Head", piece="Centers")


# ================================================================= SHIRTS
def torso_shell():
    """Body pushed out SHELL along its normals, cut flat at the hem and the collar. Pet-local."""
    body = D["PetBear__Body"]
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.normal_update()
    for v in bm.verts:
        v.co += v.normal * SHELL
    bmesh.ops.transform(bm, matrix=local(body), verts=bm.verts[:])
    for z, no in ((HEM_Z, (0, 0, -1)), (COLLAR_Z, (0, 0, 1))):
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, z), plane_no=no,
                               clear_outer=True)
    return bm


def band_split(bm, bands):
    """Cut the shell at each band edge; return (rest, inside-bands) as two bmeshes."""
    for lo, hi in bands:
        for z in (lo, hi):
            bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, z), plane_no=(0, 0, 1))
    inside = bm.copy()
    is_in = lambda f: any(lo < f.calc_center_median().z < hi for lo, hi in bands)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if is_in(f)], context="FACES")
    bmesh.ops.delete(inside, geom=[f for f in inside.faces if not is_in(f)], context="FACES")
    return bm, inside


def sleeve(side):
    """A shell of the arm mesh, cut by a slanted cuff plane, with the cuff lip turned in. Pet-local."""
    sx = 1.0 if side == "L" else -1.0
    arm = D["PetBear__Hand" + side]
    bm = bmesh.new()
    bm.from_mesh(arm.data)
    bm.normal_update()
    for v in bm.verts:  # push out so every face around the vertex ends up SLEEVE_OFFSET above the arm
        tight = min((v.normal.dot(f.normal) for f in v.link_faces), default=1.0)
        v.co += v.normal * (SLEEVE_OFFSET / max(tight, 0.45))
    axis = Vector((SLEEVE_AXIS[0] * sx, SLEEVE_AXIS[1], SLEEVE_AXIS[2])).normalized()
    lean = Vector((SLEEVE_CUFF_LEAN[0] * sx, SLEEVE_CUFF_LEAN[1], SLEEVE_CUFF_LEAN[2]))
    lean = (lean - axis * lean.dot(axis)).normalized()
    to_arm = arm.matrix_basis.inverted() @ arm.matrix_parent_inverse.inverted()  # anchor space -> mesh space
    plane_no = (to_arm.to_3x3() @ (axis - lean * SLEEVE_CUFF_SLOPE)).normalized()
    plane_co = to_arm @ (axis * SLEEVE_CUFF_T)
    cut = bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=plane_co,
                                 plane_no=plane_no, clear_outer=True)["geom_cut"]
    rim = [e for e in cut if isinstance(e, bmesh.types.BMEdge)]
    lip = [v for v in bmesh.ops.extrude_edge_only(bm, edges=rim)["geom"] if isinstance(v, bmesh.types.BMVert)]
    middle = sum((v.co for v in lip), Vector()) / len(lip)
    for v in lip:  # the lip stays in the cuff plane and ends just under the arm surface
        out = v.co - middle
        v.co = middle + out * max(0.0, 1.0 - SLEEVE_LIP / out.length)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bmesh.ops.transform(bm, matrix=local(arm), verts=bm.verts[:])
    # recalc on an open shell can pick either winding, and the right arm's mirrored transform flips it:
    # make the faces look away from the sleeve's axis so neither side renders inside-out (backface-culled).
    bm.normal_update()
    centre = sum((v.co for v in bm.verts), Vector()) / len(bm.verts)
    ax = Vector((SLEEVE_AXIS[0] * sx, SLEEVE_AXIS[1], SLEEVE_AXIS[2])).normalized()
    score = 0.0
    for f in bm.faces:
        d = f.calc_center_median() - centre
        d -= ax * d.dot(ax)
        score += f.normal.dot(d) * f.calc_area()
    if score < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    return bm


def shirt_sleeves(item, color, variant):
    for side in "LR":
        finish(f"Shirt_{variant}_Sleeve{side}", sleeve(side), "Hand" + side, color, item, "Sleeve" + side,
               "Hand" + side, piece="Sleeve" + side, fix_normals=False, shellOffset=SLEEVE_OFFSET)


# ---- Stripy Tee: navy torso and sleeves (own), two bold stripes (secondary)
rest, stripes = band_split(torso_shell(), [(0.425, 0.490), (0.555, 0.620)])
finish("Shirt_Tee_Torso", rest, "Torso", C_TEE, "tee", "Shirt", "Body", piece="Torso", fix_normals=False,
       shellOffset=SHELL, shell=True)
finish("Shirt_Tee_Stripes", stripes, "Torso", "secondary", "tee", "Shirt", "Body", piece="Stripes", fix_normals=False,
       shellOffset=SHELL, shell=True)
shirt_sleeves("tee", C_TEE, "Tee")

# ---- Star Hoodie: lilac torso, sleeves and hood (own), hem rib and a puffy chest star (secondary)
rest, hem = band_split(torso_shell(), [(HEM_Z - 0.01, 0.398)])
finish("Shirt_Hoodie_Torso", rest, "Torso", C_HOODIE, "hoodie", "Shirt", "Body", piece="Torso", fix_normals=False,
       shellOffset=SHELL, shell=True)
finish("Shirt_Hoodie_Hem", hem, "Torso", "secondary", "hoodie", "Shirt", "Body", piece="Hem", fix_normals=False,
       shellOffset=SHELL, shell=True)
shirt_sleeves("hoodie", C_HOODIE, "Hoodie")
bm = bmesh.new()
hit = BODY.ray_cast(Vector((0, -3, 0.515)), Vector((0, 1, 0)))
n = (hit[1] + Vector((0, -0.6, 0))).normalized()
o = hit[0] + hit[1] * (SHELL + 0.002)
x_axis = Vector((1, 0, 0))
y_axis = n.cross(x_axis).normalized()
puff(bm, o, x_axis, y_axis, n, star_outline(5, 0.52), 0.098, 0.030, mid=0.0, rim=0.006, sink=0.022)
finish("Shirt_Hoodie_Star", bm, "Torso", "secondary", "hoodie", "Shirt", "Body", piece="Star")
bm = bmesh.new()   # the hood, folded down behind the neck: a fat crescent that tapers toward the shoulders
pts, radii = [], []
for i in range(9):
    a = math.radians(-66 + 132 * i / 8)           # 0 = straight back
    k = math.cos(math.radians(-66 + 132 * i / 8) * 1.36)    # 1 at the back, ~0 at the ends
    pts.append(Vector((0.205 * math.sin(a), 0.030 + 0.205 * math.cos(a), 0.632 - 0.030 * k)))
    radii.append(0.028 + 0.046 * max(k, 0.0))
tube(bm, pts, radii, sides=6, flat=1.0)
finish("Shirt_Hoodie_Hood", bm, "Torso", C_HOODIE, "hoodie", "Shirt", "Body", piece="Hood")


# ================================================================= NECKLACES
neck = local(anchor("Neck")).translation


def neck_path(count, lift, drop=0.0):
    """Points round the neck: a ring tilted 0.03 lower at the front, projected on the body and lifted."""
    out = []
    for i in range(count):
        a = -math.pi / 2 + 2 * math.pi * i / count           # starts at the front centre
        d = Vector((math.cos(a), math.sin(a), 0))
        z = neck.z + 0.03 * math.sin(a) - drop
        hit = BODY.ray_cast(Vector((0, -0.05, z)) + d * 2.0, -d)
        out.append(hit[0] + hit[1] * lift)
    return out


# ---- Pearl Beads: string and pearls (own cream), heart pendant (secondary)
bm = bmesh.new()
loop = neck_path(20, 0.036)
tube(bm, loop, 0.008, sides=3, closed=True)
for i, p in enumerate(loop):
    if i == 0:
        continue                                          # the pendant hangs here
    ball(bm, p, 0.027 if i % 2 else 0.023, segs=5, rings=2)
finish("Neck_Beads", bm, "Neck", C_PEARL, "beads", "Necklace", "Body")
bm = bmesh.new()
front = loop[0]
puff(bm, front + Vector((0, -0.012, -0.030)), Vector((1, 0, 0)), Vector((0, 0.25, 0.97)).normalized(),
     Vector((0, -0.97, 0.25)).normalized(), heart_outline(12), 0.050, 0.022, mid=0.0, back=0.022)
finish("Neck_Beads_Pendant", bm, "Neck", "secondary", "beads", "Necklace", "Body", piece="Pendant")

# ---- Bell Collar: soft band (secondary), round gold bell (own gold)
bm = bmesh.new()
loop = neck_path(16, 0.026)
tube(bm, loop, 0.034, sides=4, closed=True, flat=0.50)
finish("Neck_BellCollar", bm, "Neck", "secondary", "bellcollar", "Necklace", "Body")
bm = bmesh.new()
bell = neck_path(16, 0.050)[0] + Vector((0, -0.012, -0.050))
lathe(bm, [(0.0, -0.052), (0.026, -0.045), (0.044, -0.026), (0.050, -0.006), (0.055, 0.000), (0.050, 0.006),
           (0.042, 0.028), (0.022, 0.046), (0.0, 0.052)], 8, Matrix.Translation(bell))
ball(bm, bell + Vector((0, 0.004, 0.056)), 0.016, segs=5, rings=2)      # the loop it hangs from
finish("Neck_BellCollar_Bell", bm, "Neck", C_GOLD, "bellcollar", "Necklace", "Body", piece="Bell")


# ================================================================= HELIX PIERCINGS
for side in "LR":
    A = local(anchor("Helix" + side))
    ear = bvh_of("Ear" + side, "EarInner" + side)
    # ---- Little Hoops: a gold ring hanging from the ear LOBE (Spencer 2026-11-12), same Ears slot, so
    # saves keep working; the mesh keeps its Helix*_Ring name. Anchor-local YZ plane at the Lobe anchor.
    # Built in pet-local space (not the lobe anchor's tilted frame): the hoop hangs straight down in the
    # front-back/up plane, its top passing through the lobe, so it reads as a hoop from the side.
    R, r = 0.046, 0.0105
    A = Matrix.Translation(local(anchor("Lobe" + side)).to_translation() + Vector((0, 0, -(R - 0.016))))
    bm = bmesh.new()
    rings = []
    for i in range(14):
        a = 2 * math.pi * i / 14
        c = Vector((0, R * math.cos(a), R * math.sin(a)))
        radial = Vector((0, math.cos(a), math.sin(a)))
        rings.append([bm.verts.new(A @ (c + (radial * math.cos(2 * math.pi * k / 6) + Vector((1, 0, 0)) * math.sin(2 * math.pi * k / 6)) * r))
                      for k in range(6)])
    for i in range(14):
        ring_faces(bm, rings[i], rings[(i + 1) % 14])
    finish(f"Helix{side}_Ring", bm, "Lobe" + side, C_GOLD, "ring", "Lobe" + side, "Head", majorRadius=R, minorRadius=r)
    # ---- Star Studs: a puffy gold star on the front of the rim, a little ball behind
    A = local(anchor("Helix" + side))
    bm = bmesh.new()
    c = A @ Vector((0, 0, -0.040))
    f = ear.ray_cast(Vector((c.x, -2, c.z)), Vector((0, 1, 0)))[0]
    b = ear.ray_cast(Vector((c.x, 2, c.z)), Vector((0, -1, 0)))[0]
    puff(bm, Vector((c.x, f.y - 0.002, c.z)), Vector((1, 0, 0)), Vector((0, 0, 1)), Vector((0, -1, 0)),
         star_outline(5, 0.50), 0.052, 0.024, mid=0.0, rim=0.004, sink=0.014)
    ball(bm, Vector((c.x, b.y + 0.004, c.z)), 0.017, segs=5, rings=2)
    finish(f"Helix{side}_StarStud", bm, "Helix" + side, C_GOLD, "starstud", "Helix" + side, "Head")


# ================================================================= EYES
for side, sx in (("L", -1.0), ("R", 1.0)):
    e = local(anchor("Eye" + side)).translation
    # ---- Sparkle Eyes: white (own) under a big dark pupil (face ink), a secondary-colour iris glow, star shine (own white)
    bm = bmesh.new()
    face_patch(bm, e.x, e.z, ellipse_outline(12, 0.0825, 0.1225), rise=0.016, rim=0.006, sink=0.014)
    finish(f"Eye{side}_AltSparkle_White", bm, "Eye" + side, C_WHITE, "sparkle", "Eye" + side, "Head", piece="White", facing=Vector((0, -1, 0)))
    bm = bmesh.new()
    face_patch(bm, e.x, e.z - 0.004, ellipse_outline(12, 0.066, 0.104), rise=0.030, rim=0.014, sink=0.004)
    finish(f"Eye{side}_AltSparkle", bm, "Eye" + side, "face", "sparkle", "Eye" + side, "Head", piece="Pupil", facing=Vector((0, -1, 0)))
    bm = bmesh.new()
    face_patch(bm, e.x, e.z - 0.052, ellipse_outline(10, 0.044, 0.038), rise=0.035, rim=0.026, sink=-0.020, mid=0.0)
    finish(f"Eye{side}_AltSparkle_Iris", bm, "Eye" + side, "secondary", "sparkle", "Eye" + side, "Head", piece="Iris", facing=Vector((0, -1, 0)))
    bm = bmesh.new()
    star4 = [(0.036 * (1.0 if i % 2 == 0 else 0.36) * math.cos(math.pi / 2 + math.pi * i / 4),
              0.044 * (1.0 if i % 2 == 0 else 0.36) * math.sin(math.pi / 2 + math.pi * i / 4)) for i in range(8)]
    # Mirrored per side (outer upper corner): the same +x offset sat toward the face centre on the left
    # eye, where the head curves forward, and sank that shine into the pupil.
    face_patch(bm, e.x + sx * 0.020, e.z + 0.040, star4, rise=0.042, rim=0.034, sink=-0.026, mid=0.0)
    face_patch(bm, e.x - sx * 0.026, e.z - 0.006, ellipse_outline(6, 0.012, 0.014), rise=0.040, rim=0.034, sink=-0.026, mid=0.0)
    finish(f"Eye{side}_AltSparkle_Shine", bm, "Eye" + side, C_WHITE, "sparkle", "Eye" + side, "Head", piece="Shine", facing=Vector((0, -1, 0)))
    # ---- Sleepy Eyes: a closed, drooping lid with two lashes at the outer corner (face ink)
    bm = bmesh.new()
    lid = [(sx * dx, dz) for dx, dz in arc(0.0, 0.030, 0.074, 0.062, 200, 340, 9)]
    face_stroke(bm, e.x, e.z - 0.012, lid, 0.034, rise=0.014)
    for ang, length in ((218, 0.040), (250, 0.034)):
        base = (sx * 0.060, 0.004) if ang == 218 else (sx * 0.036, -0.022)
        d = (sx * -math.cos(math.radians(ang)) * length, math.sin(math.radians(ang)) * length)
        lash = [(base[0] + d[0] * t, base[1] + d[1] * t) for t in (0.0, 0.5, 1.0)]
        face_stroke(bm, e.x, e.z - 0.012, lash, 0.020, rise=0.010, taper=0.5)
    finish(f"Eye{side}_AltSleepy", bm, "Eye" + side, "face", "sleepy", "Eye" + side, "Head", facing=Vector((0, -1, 0)))
    # ---- Happy Eyes: a thick upturned arc (^), content and squinty (face ink)
    bm = bmesh.new()
    face_stroke(bm, e.x, e.z - 0.010, arc(0.0, -0.024, 0.078, 0.070, 18, 162, 13), 0.054, rise=0.018, taper=0.55)
    finish(f"Eye{side}_AltHappy", bm, "Eye" + side, "face", "happy", "Eye" + side, "Head", facing=Vector((0, -1, 0)))
    # ---- Lash Eyes: a glossy oval with two short lashes off the outer corner (face ink), white shine (own)
    bm = bmesh.new()
    face_patch(bm, e.x, e.z - 0.006, ellipse_outline(14, 0.072, 0.100), rise=0.030, rim=0.012, sink=0.006)
    for ang, length, base in ((22, 0.036, (0.064, 0.044)), (52, 0.034, (0.046, 0.076))):
        d = (sx * math.cos(math.radians(ang)) * length, math.sin(math.radians(ang)) * length)
        lash = [(sx * base[0] + d[0] * t, base[1] + d[1] * t) for t in (0.0, 0.5, 1.0)]
        face_stroke(bm, e.x, e.z - 0.006, lash, 0.032, rise=0.014, taper=0.25)
    finish(f"Eye{side}_AltLash", bm, "Eye" + side, "face", "lash", "Eye" + side, "Head", facing=Vector((0, -1, 0)))
    bm = bmesh.new()
    face_patch(bm, e.x - sx * 0.022, e.z + 0.030, ellipse_outline(10, 0.026, 0.032), rise=0.036, rim=0.030, sink=-0.020, mid=0.0)
    face_patch(bm, e.x + sx * 0.022, e.z - 0.040, ellipse_outline(6, 0.009, 0.010), rise=0.034, rim=0.030, sink=-0.020, mid=0.0)
    finish(f"Eye{side}_AltLash_Shine", bm, "Eye" + side, C_WHITE, "lash", "Eye" + side, "Head", piece="Shine", facing=Vector((0, -1, 0)))


# ================================================================= MOUTH
m = local(anchor("Mouth")).translation
MUZ = bvh_of("Muzzle", "Head")
# ---- Blep: a soft smile (face ink) with the tip of the tongue out (own pink). Replaces the neutral frame only.
bm = bmesh.new()
face_stroke(bm, 0.0, m.z, arc(0.0, 0.058, 0.052, 0.044, 212, 328, 9), 0.022, rise=0.008, sink=0.004, tree=MUZ)
finish("Mouth_AltBlep", bm, "Mouth", "face", "blep", "Mouth", "Head", facing=Vector((0, -1, 0)))
bm = bmesh.new()
tongue = [(-0.024, 0.014), (-0.026, -0.014), (-0.016, -0.037), (0.0, -0.044), (0.016, -0.037), (0.026, -0.014), (0.024, 0.014), (0.0, 0.018)]
face_patch(bm, 0.0, m.z + 0.006, tongue, rise=0.016, rim=0.006, sink=0.008, mid=0.55, tree=MUZ)
finish("Mouth_AltBlep_Tongue", bm, "Mouth", C_TONGUE, "blep", "Mouth", "Head", piece="Tongue", facing=Vector((0, -1, 0)))


# ================================================================= TAIL
# ---- Heart Tail: a curly stalk with a puffy heart on the end (secondary). Starts 0.04 inside the body.
t = local(anchor("Tail")).translation
bm = bmesh.new()
stalk = [Vector(p) for p in ((0.0, -0.045, -0.005), (0.0, 0.070, -0.030), (0.020, 0.165, 0.005), (0.050, 0.225, 0.085),
                             (0.050, 0.235, 0.180), (0.020, 0.205, 0.255))]
tube(bm, [t + p for p in stalk], [0.038, 0.036, 0.032, 0.028, 0.025, 0.023], sides=6, cap=True)
hc = t + Vector((0.005, 0.190, 0.335))
face = Vector((0.10, 0.94, 0.32)).normalized()          # looks back and a little up
hx = Vector((0, 0, 1)).cross(face).normalized()
hy = face.cross(hx).normalized()
puff(bm, hc, hx, hy, face, heart_outline(16), 0.125, 0.048, mid=0.62, back=None)
puff(bm, hc, hx, hy, -face, [(-u, v) for u, v in heart_outline(16)], 0.125, 0.048, mid=0.62, back=None)
bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
finish("Tail_AltHeart", bm, "Tail", "secondary", "heart", "Tail", "Body")

bpy.context.view_layer.update()
for ob in BUILT:
    print(f"WEARABLE {ob.name:38s} {ob['item']:12s} {ob['piece']:9s} {ob['colorRole']:13s} tris {ob['tris']}")
totals = {}
for ob in BUILT:
    totals[ob["item"]] = totals.get(ob["item"], 0) + ob["tris"]
print("ITEM TRIS", totals)
assert max(totals.values()) <= 600, totals
if __name__ == "__main__" and "--no-save" not in sys.argv:
    bpy.ops.wm.save_mainfile()
