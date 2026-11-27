"""The garden understory's meshes, P1 (GARDEN-B38-BRIEF 4b, Fable 2026-11-27): a round bush (leaf-cluster shells, one
mesh for both sizes), the same bush on the blossom part of the atlas (the flowering bush), and a clump of reeds with two
cattail heads. Original art: every shape is built here from code (icospheres pushed by seeded noise, triangle blades).
No AI mesh, no downloads, no samples.

Run in BACKGROUND Blender from an empty scene (draw the atlas first: python scripts/draw_understory_atlas.py):
  blender.exe -b --factory-startup --python scripts/build_understory_meshes.py -- [--render]

Mesh-local Roblox axes: origin on the ground at the plant's foot, y up. Blender (x, y, z) = Roblox (x, -z, y). FBX:
forward -Z, up Y (as the nest landmark), so Roblox imports each mesh turned by pi about Y (UnderstoryClient's Turn) with
its origin at its bounds centre; the manifest records each mesh's bounds centre from the foot and its size, so the
client seats it: CFrame.new(foot) * yaw * CFrame.new(centre * scale) * Turn, Size = size * scale.

Budget (brief): bush 120 triangles, reeds 36. Reed blades and cattail stems are cards: each is two triangles back to
back with their own vertices (Roblox culls back faces; a merged pair would smooth its normal to nothing). The bush keeps
a soft smooth normal and a vertex-colour shade (darker low down and inside), which a MeshPart's TextureID multiplies.

Writes assets/world/understory/understory.fbx and understory-manifest.json (names unique to this slice: memory note
world-finish-template-names); with --render, renders the three meshes beside a player-height post (4.2) and a pet-size
ball (.9 x 1.1) to artifacts/qa-2026-11-27-beta37/understory/.
"""
from __future__ import annotations

import hashlib
import json
import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "world" / "understory"
RENDERS = ROOT / "artifacts" / "qa-2026-11-27-beta37" / "understory"
ATLAS = OUT / "understory-atlas.png"
ATLAS_PX = 256.0
# Atlas regions, x0 y0 x1 y1 in pixels, image y down (scripts/draw_understory_atlas.py).
REGION = {"bush": (0, 0, 128, 128), "flower": (128, 0, 256, 128), "blades": (0, 128, 96, 256),
          "stem": (96, 128, 104, 256), "head": (104, 128, 128, 256)}
INSET = 2.0                                   # pixels kept off each region's edge (mip bleed)
NAMES = {"bush": "Understory_B38_Bush", "flower": "Understory_B38_BushFlower", "reeds": "Understory_B38_Reeds"}
TRIS = {"bush": 120, "flower": 120, "reeds": 36}
BUSH_ACROSS, BUSH_TALL = 3.0, 2.0             # design size; the client scales each bush to 2.5 / 4 across
SEED = 20261127


def bl(p):
    return Vector((p[0], -p[2], p[1]))


def rb(v):
    return (v[0], v[2], -v[1])


def region_uv(name, u, v):
    """u, v in 0..1 inside a region (v = 0 at the region's TOP row) to Blender UV (v up), inset off the edges."""
    x0, y0, x1, y1 = REGION[name]
    x0, y0, x1, y1 = x0 + INSET, y0 + INSET, x1 - INSET, y1 - INSET
    u = min(max(u, 0.0), 1.0)
    v = min(max(v, 0.0), 1.0)
    return ((x0 + (x1 - x0) * u) / ATLAS_PX, 1 - (y0 + (y1 - y0) * v) / ATLAS_PX)


# ----------------------------------------------------------------------------------------------------------- bush
def lump(bm, centre, radius, squash, subdiv, seed, sink):
    """An icosphere pushed by seeded noise (leaf clusters, not a ball), its underside flattened at the ground."""
    made = bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
    out = []
    off = Vector((seed * 3.7, seed * 1.3, seed * 2.1))
    for vert in made["verts"]:
        d = vert.co.normalized()
        bump = noise.noise(d * 1.6 + off) * .16 + noise.noise(d * 3.4 + off * 2) * .06
        r = radius * (1 + bump)
        p = Vector((d.x * r, d.y * r, d.z * r * squash)) + bl(centre)
        if p.z < -sink:                              # Blender z is up: tuck the underside just under the lawn
            p.z = -sink
        vert.co = p
        out.append(vert)
    return made


def build_bush(name, region):
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    col = bm.loops.layers.color.new("Col")
    # Six leaf clusters of 20 triangles (bmesh icosphere subdivisions 1): a crowning one, four round the shoulder and one
    # leaning off the top, so the outline is clumps like the tree crowns, never one smooth boulder. 120 in all.
    for k, (centre, radius, squash) in enumerate((
            ((0, 1.05, 0), .95, .85), ((.82, .62, .3), .72, .85), ((-.2, .6, .86), .7, .82),
            ((-.86, .64, -.12), .74, .85), ((.1, .58, -.84), .7, .82), ((.36, 1.42, -.28), .6, .9))):
        lump(bm, centre, radius, squash, 1, k + 1, .08)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.normal_update()
    # scale to the design size exactly (3 across, 2 tall from the ground)
    xs = [v.co.x for v in bm.verts]
    ys = [v.co.y for v in bm.verts]
    zs = [v.co.z for v in bm.verts]
    cx, cy = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
    sx = BUSH_ACROSS / max(max(xs) - min(xs), max(ys) - min(ys))
    sz = BUSH_TALL / (max(zs) - min(zs))
    z0 = min(zs)
    for v in bm.verts:
        v.co = Vector(((v.co.x - cx) * sx, (v.co.y - cy) * sx, (v.co.z - z0) * sz - .08))
    bm.normal_update()
    span = BUSH_ACROSS * 1.02
    for f in bm.faces:
        f.smooth = True
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        a, b = [(1, 2), (0, 2), (0, 1)][ax]
        for loop in f.loops:
            p = loop.vert.co
            # each face is its own planar island (the leaf print hides the seams): a top face takes x and y, a side
            # face its horizontal axis across and the height down the region
            u = p[a] / span + .5
            v = (.5 - p[b] / span) if ax == 2 else (1 - (p.z + .1) / (BUSH_TALL + .2))
            loop[uv].uv = region_uv(region, u, v)
            # shade: darker low down (the clusters shade each other), never black
            h = max(0.0, min(1.0, (p.z + .08) / BUSH_TALL))
            k = .66 + .34 * h
            loop[col] = (k, k, k, 1.0)
    return finish(bm, name)


# ---------------------------------------------------------------------------------------------------------- reeds
def card(bm, uv, col, pts, uvs, shades):
    """One triangle as two back to back faces, each with its own vertices (flat, so each side lights as itself)."""
    for order in ((0, 1, 2), (0, 2, 1)):
        vs = [bm.verts.new(bl(pts[i])) for i in order]
        f = bm.faces.new(vs)
        f.smooth = False
        for loop, i in zip(f.loops, order):
            loop[uv].uv = uvs[i]
            k = shades[i]
            loop[col] = (k, k, k, 1.0)


def build_reeds(name):
    rnd = random.Random(SEED)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    col = bm.loops.layers.color.new("Col")
    blades = 10
    for k in range(blades):
        a = k / blades * math.tau + rnd.uniform(-.25, .25)
        r = .08 + rnd.random() * .3
        foot = (math.cos(a) * r, -.05, math.sin(a) * r)
        tall = 2.3 + rnd.random() * .9
        lean = math.radians(6 + rnd.random() * 14)            # outward from the clump's middle
        tip = (foot[0] + math.cos(a) * math.sin(lean) * tall, tall * math.cos(lean), foot[2] + math.sin(a) * math.sin(lean) * tall)
        side = a + math.pi / 2 + rnd.uniform(-.5, .5)          # the blade's flat face turns round the clump
        w = .07 + rnd.random() * .04
        left = (foot[0] - math.cos(side) * w, foot[1], foot[2] - math.sin(side) * w)
        right = (foot[0] + math.cos(side) * w, foot[1], foot[2] + math.sin(side) * w)
        strip = k % 8                                           # eight 12 px strips across the blade region
        u0, u1 = strip / 8 + .01, (strip + 1) / 8 - .01
        card(bm, uv, col, [left, right, tip],
             [region_uv("blades", u0, 1), region_uv("blades", u1, 1), region_uv("blades", (u0 + u1) / 2, 0)],
             [.7, .7, 1.0])
    for k in range(2):
        a = k * math.pi + .6
        foot = (math.cos(a) * .12, -.05, math.sin(a) * .12)
        tall = 2.75 + k * .35
        lean = math.radians(5 + k * 4)
        top = Vector((foot[0] + math.cos(a) * math.sin(lean) * tall, tall * math.cos(lean), foot[2] + math.sin(a) * math.sin(lean) * tall))
        side = a + math.pi / 2
        w = .035
        card(bm, uv, col,
             [(foot[0] - math.cos(side) * w, foot[1], foot[2] - math.sin(side) * w),
              (foot[0] + math.cos(side) * w, foot[1], foot[2] + math.sin(side) * w), tuple(top)],
             [region_uv("stem", 0, 1), region_uv("stem", 1, 1), region_uv("stem", .5, 0)], [.7, .7, .95])
        # the head: a three-sided velvet sleeve (6 triangles, open ends) .5 long, its top .35 under the stem's tip
        axis = (top - Vector(foot)).normalized()
        head_top = top - axis * .35
        head_low = head_top - axis * .5
        ref = Vector((0, 1, 0)) if abs(axis.y) < .9 else Vector((1, 0, 0))
        e1 = axis.cross(ref).normalized()
        e2 = axis.cross(e1).normalized()
        ring = []
        for s in range(3):
            t = s / 3 * math.tau
            ring.append((math.cos(t) * e1 + math.sin(t) * e2) * .09)
        for s in range(3):
            q0, q1 = ring[s], ring[(s + 1) % 3]
            # (point, around 0..1, along 0..1) round the quad
            quad = [(head_low + q0, s / 3, 0), (head_low + q1, (s + 1) / 3, 0), (head_top + q1, (s + 1) / 3, 1),
                    (head_top + q0, s / 3, 1)]
            # wound so the face looks out along (q0 + q1), in Blender space
            p0, p1, p2 = (bl(tuple(q[0])) for q in quad[:3])
            if (p1 - p0).cross(p2 - p0).dot(bl(tuple(q0 + q1))) < 0:
                quad.reverse()
            f = bm.faces.new([bm.verts.new(bl(tuple(q[0]))) for q in quad])
            f.smooth = True
            for loop, (_, around, along) in zip(f.loops, quad):
                loop[uv].uv = region_uv("head", around, 1 - along)
                k = .75 + .25 * along
                loop[col] = (k, k, k, 1.0)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    return finish(bm, name)


# --------------------------------------------------------------------------------------------------------- common
def finish(bm, name):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def bounds(obj):
    pts = [rb(v.co) for v in obj.data.vertices]
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    return [round((lo[i] + hi[i]) / 2, 4) for i in range(3)], [round(hi[i] - lo[i], 4) for i in range(3)]


def digest(obj):
    h = hashlib.sha256()
    for v in obj.data.vertices:
        h.update(("%.4f,%.4f,%.4f;" % tuple(v.co)).encode())
    for loop in obj.data.uv_layers[0].data:
        h.update(("%.4f,%.4f;" % tuple(loop.uv)).encode())
    return h.hexdigest()[:16]


def main():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    OUT.mkdir(parents=True, exist_ok=True)
    objs = {"bush": build_bush(NAMES["bush"], "bush"), "flower": build_bush(NAMES["flower"], "flower"),
            "reeds": build_reeds(NAMES["reeds"])}
    meshes = {}
    for key, obj in objs.items():
        n = tris(obj)
        assert n == TRIS[key], (key, n, TRIS[key])
        centre, size = bounds(obj)
        meshes[key] = {"name": obj.name, "tris": n, "centre": centre, "size": size, "hash": digest(obj)}
    assert meshes["bush"]["hash"] != meshes["flower"]["hash"], "the flowering bush must sit on its own atlas region"
    manifest = {
        "note": "Generated by scripts/build_understory_meshes.py. Mesh-local Roblox studs: origin on the ground at the "
                "plant's foot, y up. Roblox imports each mesh turned by pi about Y, its origin at its bounds centre "
                "(`centre`, from the foot). Size = `size` x the instance scale.",
        "atlas": "assets/world/understory/understory-atlas.png",
        "blob": "assets/world/understory/understory-blob.png",
        "meshes": meshes,
        "triangles": {k: v["tris"] for k, v in meshes.items()},
    }
    # Origins at the bounds centres (Roblox puts the part there anyway; this keeps Blender and Studio the same).
    for key, obj in objs.items():
        c = bl(meshes[key]["centre"])
        obj.data.transform(Matrix.Translation(-c))
        obj.location = c
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objs.values():
        obj.select_set(True)
    bpy.ops.export_scene.fbx(filepath=str(OUT / "understory.fbx"), use_selection=True, axis_forward="-Z", axis_up="Y",
                             global_scale=1.0, apply_unit_scale=True, use_mesh_modifiers=False, object_types={"MESH"},
                             add_leaf_bones=False, bake_anim=False, path_mode="STRIP", mesh_smooth_type="FACE",
                             colors_type="SRGB")
    (OUT / "understory-manifest.json").write_text(json.dumps(manifest, indent=1), encoding="utf-8", newline="\n")
    print("UNDERSTORY", {k: (v["tris"], v["size"], v["centre"]) for k, v in meshes.items()})
    if "--render" in sys.argv:
        render(objs, meshes)


# --------------------------------------------------------------------------------------------------------- render
def lin(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= .04045 else ((x + .055) / 1.055) ** 2.4 for x in c)


def material(name, image=None, colour=None, rough=.95, vcol=False):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    if image:
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = image
        tex.interpolation = "Linear"
        out = tex.outputs["Color"]
        if vcol:   # the vertex shade multiplies the texture, as a MeshPart's TextureID does
            attr = nt.nodes.new("ShaderNodeAttribute")
            attr.attribute_name = "Col"
            mul = nt.nodes.new("ShaderNodeVectorMath")
            mul.operation = "MULTIPLY"
            nt.links.new(out, mul.inputs[0])
            nt.links.new(attr.outputs["Color"], mul.inputs[1])
            out = mul.outputs[0]
        nt.links.new(out, bsdf.inputs["Base Color"])
    elif colour:
        bsdf.inputs["Base Color"].default_value = (*colour, 1)
    bsdf.inputs["Roughness"].default_value = rough
    for key in ("Specular IOR Level", "Specular"):
        if key in bsdf.inputs:
            bsdf.inputs[key].default_value = .15
            break
    return mat


def place(src, name, foot, scale, yaw):
    obj = bpy.data.objects.new(name, src.data)
    bpy.context.scene.collection.objects.link(obj)
    centre = Vector(src.location)                       # Blender coords of the bounds centre from the foot
    obj.scale = (scale[0], scale[0], scale[1])
    obj.rotation_euler = (0, 0, yaw)
    off =Matrix.Rotation(yaw, 4, "Z") @ Vector((centre.x * scale[0], centre.y * scale[0], centre.z * scale[1]))
    obj.location = bl(foot) + off
    return obj


def render(objs, meshes):
    RENDERS.mkdir(parents=True, exist_ok=True)
    image = bpy.data.images.load(str(ATLAS))
    tex = material("Understory", image, vcol=True)
    for obj in objs.values():
        obj.data.materials.append(tex)
        obj.hide_render = True
    scene = bpy.context.scene
    # a lineup at the brief's sizes: big bush 4 x 2.4, small bush 2.5 x 1.6, flowering 3 x 2, two reed clumps, then a
    # cluster of three as the garden places them, a player post and a pet ball for scale
    b = meshes["bush"]["size"]
    lineup = [
        (objs["bush"], "big", (-7.5, 0, 0), (4 / b[0], 2.4 / b[1]), .3),
        (objs["bush"], "small", (-3.8, 0, .6), (2.5 / b[0], 1.6 / b[1]), 1.4),
        (objs["flower"], "flowering", (-.4, 0, 0), (3 / b[0], 2 / b[1]), 2.2),
        (objs["reeds"], "reedsA", (3.0, 0, .2), (1, 1), .4),
        (objs["reeds"], "reedsB", (4.3, 0, -.5), (.85, .9), 2.6),
        (objs["bush"], "c1", (-4, 0, 9), (4 / b[0], 2.3 / b[1]), 4.0),
        (objs["bush"], "c2", (-1.2, 0, 10.6), (2.6 / b[0], 1.7 / b[1]), .9),
        (objs["bush"], "c3", (-6.4, 0, 11.4), (2.5 / b[0], 1.5 / b[1]), 5.1),
        (objs["flower"], "f2", (3.5, 0, 9.5), (2.6 / b[0], 1.8 / b[1]), 3.3),
    ]
    for src, name, foot, scale, yaw in lineup:
        place(src, name, foot, scale, yaw)
    bpy.ops.mesh.primitive_plane_add(size=80, location=(0, 0, 0))
    ground = bpy.context.object
    ground.data.materials.append(material("Lawn", colour=lin("#56A54B"), rough=1))
    bpy.ops.mesh.primitive_cylinder_add(radius=.6, depth=4.2, location=bl((8, 2.1, 0)))
    bpy.context.object.data.materials.append(material("Player", colour=lin("#B8B8C8"), rough=.8))
    bpy.ops.mesh.primitive_uv_sphere_add(radius=.5, location=bl((6.6, .55, 1.2)))
    pet = bpy.context.object
    pet.scale = (.9, .9, 1.1)
    pet.data.materials.append(material("Pet", colour=lin("#F4E8CF"), rough=.6))
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 3.4
    sun.angle = math.radians(8)
    so = bpy.data.objects.new("Sun", sun)
    so.rotation_euler = (math.radians(50), 0, math.radians(-30))
    scene.collection.objects.link(so)
    world = bpy.data.worlds.new("Sky")
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (.55, .75, 1.0, 1)
    bg.inputs[1].default_value = 1.0   # the Aero day ambient is bright: nearer the game than a dim sky
    scene.world = world
    for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "BLENDER_WORKBENCH"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue
    try:
        scene.view_settings.view_transform = "Standard"
    except TypeError:
        pass
    scene.render.resolution_x, scene.render.resolution_y = 1400, 800
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = 42
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    views = (("lineup", (-1, 4.2, -13), (-1, 1.3, 3)), ("player-eye", (-2, 5.2, -6), (-1, 1.0, 9)),
             ("close", (-3.5, 2.6, -5.2), (-3.5, 1.0, 1)), ("reeds", (4.5, 2.2, -4.5), (3.6, 1.6, 0)))
    for label, eye, target in views:
        e, t = bl(eye), bl(target)
        cam.location = e
        cam.rotation_euler = (t - e).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(RENDERS / f"understory-{label}.png")
        bpy.ops.render.render(write_still=True)
    print("UNDERSTORY renders in", RENDERS)


main()
