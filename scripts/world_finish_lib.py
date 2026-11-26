"""Shared helpers for the world finish art (scripts/build_world_finish_art.py): Roblox <-> Blender coordinates, meshes from
studs, deterministic 3D noise (numpy, for bakes), Cycles bakes, FBX export and the manifest rows.

Original art only: every shape and every pixel here comes from code (sweeps, height fields, Voronoi, value noise).
Coordinates are Roblox studs; Blender (x, y, z) = Roblox (x, -z, y - 4).
"""
from __future__ import annotations

import math
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]


def bl(p):
    return Vector((p[0], -p[2], p[1] - 4))


def rb(v):
    return (v[0], v[2] + 4, -v[1])


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def srgb_to_lin(c):
    c = np.asarray(c, dtype=np.float64)
    return np.where(c <= .04045, c / 12.92, ((c + .055) / 1.055) ** 2.4)


def lin_to_srgb(c):
    c = np.clip(np.asarray(c, dtype=np.float64), 0, 1)
    return np.where(c <= .0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - .055)


# ------------------------------------------------------------------------------------------------- meshes from studs
def mesh_object(name, verts, faces, uvs=None, smooth=True, collection=None, local=False):
    """verts: Roblox studs; faces: index lists wound counter-clockwise seen from the side they face; uvs: per face-corner
    list parallel to faces (optional). local: a template authored about its placement point (no world y offset)."""
    me = bpy.data.meshes.new(name)
    conv = (lambda v: Vector((v[0], -v[2], v[1]))) if local else bl
    me.from_pydata([conv(v) for v in verts], [], [list(f) for f in faces])
    me.validate(clean_customdata=False)
    if uvs is not None:
        layer = me.uv_layers.new(name="UVMap")
        k = 0
        for poly, fuv in zip(me.polygons, uvs):
            for li, uv in zip(poly.loop_indices, fuv):
                layer.data[li].uv = uv
            k += 1
    for p in me.polygons:
        p.use_smooth = smooth
    obj = bpy.data.objects.new(name, me)
    (collection or bpy.context.scene.collection).objects.link(obj)
    return obj


def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def bounds_rb(obj):
    """World-space bounds in Roblox studs: (centre, size), of the vertices faces use (Roblox's MeshSize ignores loose
    ones; the den shell's split once left 120 per half and the halves' sizes missed the import scale)."""
    me = obj.data
    used = {k for p in me.polygons for k in p.vertices} or set(range(len(me.vertices)))
    ws = [rb(obj.matrix_world @ me.vertices[k].co) for k in used]
    lo = [min(p[i] for p in ws) for i in range(3)]
    hi = [max(p[i] for p in ws) for i in range(3)]
    return [round((a + b) / 2, 4) for a, b in zip(lo, hi)], [round(b - a, 4) for a, b in zip(lo, hi)]


def recentre(obj):
    """Move the mesh's origin to its bounds centre (Roblox puts a MeshPart's position at the mesh's bounds centre)."""
    c, _ = bounds_rb(obj)
    off = bl(c) - obj.location
    obj.data.transform(__import__("mathutils").Matrix.Translation(-off))
    obj.location = obj.location + off
    return c


def material(name, rgb, rough=.9, emission=None, strength=1.0, image=None, alpha=1.0):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*srgb_to_lin(rgb), 1)
    bsdf.inputs["Roughness"].default_value = rough
    if emission is not None:
        bsdf.inputs["Emission Color"].default_value = (*srgb_to_lin(emission), 1)
        bsdf.inputs["Emission Strength"].default_value = strength
    if alpha < 1:
        bsdf.inputs["Alpha"].default_value = alpha
    if image is not None:
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = image
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def image_material(name, color_path, normal_path=None, rough=.9):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Roughness"].default_value = rough
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(str(color_path), check_existing=False)
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if normal_path:
        nimg = bpy.data.images.load(str(normal_path), check_existing=False)
        nimg.colorspace_settings.name = "Non-Color"
        ntex = nt.nodes.new("ShaderNodeTexImage")
        ntex.image = nimg
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(ntex.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


# --------------------------------------------------------------------------------------------- noise (numpy, seeded)
def _hash3(ix, iy, iz, seed):
    h = (ix.astype(np.int64) * 374761393 + iy.astype(np.int64) * 668265263 + iz.astype(np.int64) * 2147483647
         + seed * 1274126177) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    h = h ^ (h >> 16)
    return (h & 0xFFFFFF) / float(0xFFFFFF)


def value_noise(p, seed=0, period=None):
    """Smooth value noise in [0, 1] at points p (N x 3). period: integer lattice wrap per axis (tiling), or None."""
    p = np.asarray(p, dtype=np.float64)
    i0 = np.floor(p).astype(np.int64)
    f = p - i0
    u = f * f * (3 - 2 * f)
    out = np.zeros(len(p))
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                ix, iy, iz = i0[:, 0] + dx, i0[:, 1] + dy, i0[:, 2] + dz
                if period is not None:
                    ix, iy, iz = ix % period[0], iy % period[1], iz % period[2]
                w = ((u[:, 0] if dx else 1 - u[:, 0]) * (u[:, 1] if dy else 1 - u[:, 1]) * (u[:, 2] if dz else 1 - u[:, 2]))
                out += w * _hash3(ix, iy, iz, seed)
    return out


def fbm(p, octaves=4, seed=0, lac=2.0, gain=.5, period=None):
    p = np.asarray(p, dtype=np.float64)
    total, amp, norm = np.zeros(len(p)), 1.0, 0.0
    per = None if period is None else np.array(period)
    for o in range(octaves):
        total += amp * value_noise(p, seed + o * 17, None if per is None else tuple(int(v) for v in per))
        norm += amp
        amp *= gain
        p = p * lac
        if per is not None:
            per = per * lac
    return total / norm


def voronoi_edge(p, seed=0, period=None):
    """Distance to the nearest Voronoi cell border (F2 - F1)/2 and F1, cells one unit across (jittered lattice)."""
    p = np.asarray(p, dtype=np.float64)
    i0 = np.floor(p).astype(np.int64)
    d1 = np.full(len(p), 9.0)
    d2 = np.full(len(p), 9.0)
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            for dz in (-1, 0, 1):
                c = i0 + np.array([dx, dy, dz])
                cc = c if period is None else c % np.array(period)
                j = np.stack([_hash3(cc[:, 0], cc[:, 1], cc[:, 2], seed + k) for k in range(3)], 1)
                d = np.linalg.norm(c + .15 + .7 * j - p, axis=1)
                nd1 = np.minimum(d1, d)
                d2 = np.where(d < d1, d1, np.minimum(d2, d))
                d1 = nd1
    return (d2 - d1) / 2, d1


# ---------------------------------------------------------------------------------------------------------- bakes
def use_cycles(samples=16):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = samples
    scene.cycles.device = "CPU"
    try:
        scene.cycles.use_denoising = False
    except AttributeError:
        pass


def new_image(name, size, float_buffer=False, non_color=False):
    img = bpy.data.images.new(name, size[0], size[1], alpha=False, float_buffer=float_buffer)
    if non_color:
        img.colorspace_settings.name = "Non-Color"
    return img


def _target(obj, img):
    """Point the object's (only) material at img through an active, unlinked image node (Cycles bakes into it)."""
    for mat in obj.data.materials:
        nt = mat.node_tree
        node = next((n for n in nt.nodes if n.name == "BakeTarget"), None) or nt.nodes.new("ShaderNodeTexImage")
        node.name = "BakeTarget"
        node.image = img
        nt.nodes.active = node


def only(objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[-1]


def bake_position(obj, size, lo, hi):
    """Each texel's world position (Roblox studs) as an (H, W, 3) array, via an emission bake of the normalised
    position. lo/hi: Roblox bounds used for the normalisation."""
    use_cycles(1)
    img = new_image(obj.name + "_pos", size, float_buffer=True, non_color=True)
    saved = list(obj.data.materials)
    mat = bpy.data.materials.new(obj.name + "_PosBake")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        if n.type != "OUTPUT_MATERIAL":
            nt.nodes.remove(n)
    out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    # Blender position -> Roblox (x, z+4, -y) -> normalised to [0, 1] with lo/hi
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Position"], sep.inputs[0])
    comb = nt.nodes.new("ShaderNodeCombineXYZ")
    lo_b = bl(lo)
    hi_b = bl(hi)
    chans = []
    for k, (src, a, b) in enumerate((("X", lo_b.x, hi_b.x), ("Z", lo_b.z, hi_b.z), ("Y", lo_b.y, hi_b.y))):
        m1 = nt.nodes.new("ShaderNodeMath")
        m1.operation = "SUBTRACT"
        nt.links.new(sep.outputs[src], m1.inputs[0])
        m1.inputs[1].default_value = a
        m2 = nt.nodes.new("ShaderNodeMath")
        m2.operation = "DIVIDE"
        nt.links.new(m1.outputs[0], m2.inputs[0])
        m2.inputs[1].default_value = (b - a) or 1.0
        nt.links.new(m2.outputs[0], comb.inputs[k])
    emit = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(comb.outputs[0], emit.inputs["Color"])
    nt.links.new(emit.outputs[0], out.inputs["Surface"])
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    nt.nodes.active = tex
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    only([obj])
    bpy.ops.object.bake(type="EMIT", margin=6, use_clear=True)
    obj.data.materials.clear()
    for m in saved:
        obj.data.materials.append(m)
    a = np.array(img.pixels[:], dtype=np.float64).reshape(size[1], size[0], 4)[..., :3]
    # channels hold (x, y, z) Roblox after the swizzle above: X -> x, Blender Z -> y, Blender Y -> -z (lo/hi swap)
    pos = np.empty_like(a)
    pos[..., 0] = lo_b.x + a[..., 0] * (hi_b.x - lo_b.x)
    pos[..., 1] = lo_b.z + a[..., 1] * (hi_b.z - lo_b.z) + 4
    pos[..., 2] = -(lo_b.y + a[..., 2] * (hi_b.y - lo_b.y))
    return pos, img


def bake_ao(obj, size, distance=3.0, samples=64):
    use_cycles(samples)
    bpy.context.scene.world.light_settings.distance = distance
    img = new_image(obj.name + "_ao", size, float_buffer=True, non_color=True)
    _target(obj, img)
    only([obj])
    bpy.ops.object.bake(type="AO", margin=6, use_clear=True)
    return np.array(img.pixels[:], dtype=np.float64).reshape(size[1], size[0], 4)[..., 0], img


def bake_normal(high, low, size, extrusion=.35, ray=.8, samples=4):
    use_cycles(samples)
    img = new_image(low.name + "_nrm", size, non_color=True)
    _target(low, img)
    only([high, low])
    bpy.ops.object.bake(type="NORMAL", use_selected_to_active=True, cage_extrusion=extrusion, max_ray_distance=ray,
                        normal_space="TANGENT", margin=8, use_clear=True)
    return np.array(img.pixels[:], dtype=np.float64).reshape(size[1], size[0], 4)[..., :3], img


def save_png(arr, path, size, srgb_input=True):
    """arr (H, W, 3) in display (sRGB) values [0, 1], row 0 = image bottom (Blender's pixel order)."""
    img = bpy.data.images.new(Path(path).stem, size[0], size[1], alpha=False)
    if not srgb_input:
        img.colorspace_settings.name = "Non-Color"
    rgba = np.ones((size[1], size[0], 4), dtype=np.float32)
    rgba[..., :3] = np.clip(arr, 0, 1)
    img.pixels.foreach_set(rgba.ravel())
    img.filepath_raw = str(path)
    img.file_format = "PNG"
    img.save()
    return img


def clean_slivers(obj, deg=4.0, tiny=.002, passes=6):
    """Round 6 mesh gate: collapse the shortest edge of every face with a corner under `deg` degrees or an area under
    `tiny` (the dome's apex fan, decimated rock), a few passes, so no needle triangle is exported. Returns the count."""
    import bmesh
    lim, done = math.radians(deg), 0
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    for _ in range(passes):
        bm.faces.ensure_lookup_table()
        edges = set()
        for f in bm.faces:
            if f.calc_area() < tiny or any(l.calc_angle() < lim for l in f.loops):
                edges.add(min(f.edges, key=lambda e: e.calc_length()))
        if not edges:
            break
        edges = [e for e in edges if e.is_valid]
        bmesh.ops.collapse(bm, edges=edges, uvs=True)
        bmesh.ops.dissolve_degenerate(bm, dist=1e-5, edges=bm.edges)
        done += len(edges)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    return done


def export_fbx(objs, path):
    for o in objs:                          # round 6: the art's own meshes (never the re-cut island copies)
        if o.type == "MESH" and o.name.startswith("W7_F_"):
            clean_slivers(o)
    only(objs)
    bpy.ops.export_scene.fbx(filepath=str(path), use_selection=True, axis_forward="-Z", axis_up="Y", global_scale=1.0,
                             apply_unit_scale=True, use_mesh_modifiers=True, object_types={"MESH"}, add_leaf_bones=False,
                             bake_anim=False, path_mode="STRIP", mesh_smooth_type="FACE", colors_type="SRGB")
