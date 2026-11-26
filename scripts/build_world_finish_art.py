"""The world finish art (WORLD-FINISH-LOOK.md, Fable 2026-11-25): the den (slice C), the cliff path (D) and the terrace (E),
modelled and textured from code in BACKGROUND Blender. Original art only: no generated meshes or images, no outside assets.

  1. The beta island preview (the scene the art is fitted to and rendered in; see scripts/world_finish_scene.py):
       WORLD_V7_PREVIEW_BLEND=<tmp>/cliff-den-preview.blend blender -b assets/art-source/environment/world1-mockup-v7-import.blend \
           --python scripts/build_world_finish_art.py ...   (no: build_world_v7_chunks.py -- --beta; then
       git checkout -- assets/world/world-v7-beta.fbx)
  2. blender -b <tmp>/cliff-den-preview.blend --python scripts/build_world_finish_art.py -- den [--renders DIR] [--no-bake]

Writes (per slice, assets/world/world-finish/):
  world-finish-<slice>.fbx          the meshes to upload (Open Cloud, one Model per slice)
  world-finish-<slice>.json         the manifest: every mesh (name, role, Roblox centre/size, triangles, look) and the
                                    placements (src/shared/WorldFinishData.lua is generated from these by
                                    scripts/build_world_finish_pack.py, with the upload readback)
  textures/*.png                    the baked maps (den shell 1024 colour + normal, den floor 512 tile colour + normal)
Renders of Fable's camera spots go to --renders (artifacts/qa-2026-11-26-beta21/art/).
"""
from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import bpy
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import world_finish_lib as L  # noqa: E402
import world_finish_scene as W  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "world" / "world-finish"
TEX = OUT / "textures"
GROUNDED = ROOT / "assets" / "world" / "textures" / "grounded"
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SLICE = ARGS[0] if ARGS else "den"
RENDERS = str((ROOT / ARGS[ARGS.index("--renders") + 1]).resolve()) if "--renders" in ARGS else None
NO_BAKE = "--no-bake" in ARGS
# The island's surface looks (WorldAero.Surfaces tints on the grounded maps, as Studio shows them).
AERO_TINT = {"cliff_rock": "#E2EAF0", "boulder_rock": "#E2EAF0", "grass": "#F0FFD6", "meadow": "#E4FFC8",
             "foliage": "#E6FFE0", "foliage_blossom": None, "dirt_path": None, "pebble_bed": "#FAFFD4", "bark": None,
             "wood_plank": None}
# Parts the den, the path and the terrace hide while open (the bars) or replace, never drawn in the review renders.
RENDER_HIDE = ["W7_CD_CaveBars__palette"]


def studio_look():
    """The review renders show the island as Studio does: SurfaceAppearance maps (the grounded textures) with the Aero
    tints, no vertex colours (SurfaceAppearance drops them). Round 7: the island's re-cut copies (W7_F_Over*,
    W7_F_PathOver*) too, which the pack dresses as their island part (they rendered in the raw import colour)."""
    for o in bpy.data.objects:
        if o.type != "MESH" or (o.name.startswith(("W7_F_", "WF_")) and "Over" not in o.name):
            continue
        for slot in o.material_slots:
            m = slot.material
            kind = m.name[3:] if m and m.name.startswith("W1_") else None
            if kind in AERO_TINT and (GROUNDED / f"W1_{kind}.png").exists():
                slot.material = island_material(kind)
    hide_for_render(RENDER_HIDE)


def island_density(name_prefix):
    """UV units per stud of an island material (median over the first faces of a preview object)."""
    o = next((o for o in bpy.data.objects if o.type == "MESH" and o.name.startswith(name_prefix)), None)
    if o is None or not o.data.uv_layers:
        return .25
    me = o.data
    uv = me.uv_layers.active.data
    ratios = []
    for p in list(me.polygons)[:400]:
        li = list(p.loop_indices)
        for a, b in zip(li, li[1:] + li[:1]):
            va, vb = me.vertices[me.loops[a].vertex_index].co, me.vertices[me.loops[b].vertex_index].co
            d = (vb - va).length
            if d > .2:
                ratios.append((uv[b].uv - uv[a].uv).length / d)
    ratios.sort()
    return ratios[len(ratios) // 2] if ratios else .25


def rock_density():
    """The island's own cliff rock cell size (Fable world R1 fixes 8 and 14): the median UV density over the big colliding
    rock tiles near the hill (W7_CD_Rocks__cliff_rock_NNNN), not the small region piece."""
    vals = []
    for o in [o for o in bpy.data.objects if o.type == "MESH" and o.name.startswith("W7_CD_Rocks__cliff_rock_")][:12]:
        me = o.data
        if not me.uv_layers:
            continue
        uv = me.uv_layers.active.data
        for p in list(me.polygons)[:200]:
            li = list(p.loop_indices)
            for a, b in zip(li, li[1:] + li[:1]):
                d = (me.vertices[me.loops[b].vertex_index].co - me.vertices[me.loops[a].vertex_index].co).length
                if d > .5:
                    vals.append((uv[b].uv - uv[a].uv).length / d)
    vals.sort()
    return vals[len(vals) // 2] if vals else island_density("W7_CD_Region__cliff_rock")


def triplanar_uv(obj, k):
    """World-projected UVs per face on its dominant axis (as cliff_den_sculpt.Piece), k uv units per stud."""
    me = obj.data
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    uv = me.uv_layers.active.data
    mw = obj.matrix_world
    for p in me.polygons:
        n = p.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        a, b = [(1, 2), (0, 2), (0, 1)][ax]
        for li in p.loop_indices:
            co = mw @ me.vertices[me.loops[li].vertex_index].co
            uv[li].uv = (co[a] * k, co[b] * k)


def island_material(kind):
    """A render material for an island surface: the grounded map (as uploaded) times the Aero tint."""
    name = "WF_" + kind
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    path = GROUNDED / f"W1_{kind}.png"
    mat = L.image_material(name, path)
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    tint = AERO_TINT.get(kind)
    if tint:
        nt = mat.node_tree
        tex = next(n for n in nt.nodes if n.type == "TEX_IMAGE")
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = 1.0
        nt.links.new(tex.outputs["Color"], mix.inputs[6])
        mix.inputs[7].default_value = (*L.srgb_to_lin(L.hexrgb(tint)), 1)
        nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
    return mat


def hide_for_render(names):
    for n in names:
        o = bpy.data.objects.get(n)
        if o:
            o.hide_render = True
            o.hide_viewport = True


def solo(objs):
    """Hide every other object from render (bakes see only these); returns the restore list."""
    keep = set(objs)
    was = [(o, o.hide_render) for o in bpy.data.objects]
    for o in bpy.data.objects:
        if o not in keep and o.type == "MESH":
            o.hide_render = True
    return was


def restore(was):
    for o, h in was:
        o.hide_render = h


def recut(source_name, new_name, doomed, corner=None, face=None):
    """A copy of an island pack part with the faces `doomed(centre_roblox)` removed (its UVs and material kept). The
    pack's part is hidden by the mount and this copy shown in its place (visual-only parts only: never a colliding
    one, whose hulls a cut would move). Round 7: `face(points, normal_y)` (Roblox) condemns a face by its points and
    its world normal's y."""
    src = bpy.data.objects[source_name]
    src.name = source_name + "__pack"         # the copy takes the pack part's own name (Aero, CliffDenData.parts)
    o = src.copy()
    o.data = src.data.copy()
    o.name = new_name
    assert o.name == new_name, o.name
    bpy.context.scene.collection.objects.link(o)
    import bmesh as _bm
    bm = _bm.new()
    bm.from_mesh(o.data)
    mw = o.matrix_world
    # a face goes when doomed(centre) is true (or, with corner, when corner(points) is for its sample points)
    def samples(f):
        cs = [L.rb(mw @ v.co) for v in f.verts]
        out = list(cs)
        for a in range(len(cs)):
            for b in range(a + 1, len(cs)):
                out.append(tuple((cs[a][i] + cs[b][i]) / 2 for i in range(3)))
        out.append(tuple(sum(c[i] for c in cs) / len(cs) for i in range(3)))
        return out
    rot = mw.to_3x3()
    gone = [f for f in bm.faces if doomed(L.rb(mw @ f.calc_center_median())) or (corner and corner(samples(f)))
            or (face and face(samples(f), (rot @ f.normal).normalized().z))]
    _bm.ops.delete(bm, geom=gone, context="FACES")
    bm.to_mesh(o.data)
    bm.free()
    src.hide_render = True
    src.hide_viewport = True
    return o, len(gone)


def remeasure(rows):
    """Right before a manifest is written: every row's centre, size and triangles again from its object's face vertices
    as exported (Roblox's MeshSize ignores loose vertices). The den's shard pass once removed faces after its rows were
    measured, and five parts missed the one import scale."""
    for r in rows:
        o = bpy.data.objects[r["name"]]
        c, s = L.bounds_rb(o)
        if r["role"] == "template":
            c = [c[0], round(c[1] - 4, 4), c[2]]
        r["centre"], r["size"], r["triangles"] = c, s, L.tris(o)


def manifest_row(obj, role, look, slice_, extra=None):
    centre, size = L.bounds_rb(obj)
    row = {"name": obj.name, "slice": slice_, "role": role, "centre": centre, "size": size, "triangles": L.tris(obj),
           "look": look}
    row.update(extra or {})
    return row


def place_copy(template, name, cframe_pos, yaw=0.0, scale=(1, 1, 1), collection=None):
    """A render copy of a template at a Roblox position, yawed about +y (radians, Roblox's CFrame.Angles(0, yaw, 0))."""
    o = template.copy()
    o.name = name
    o.location = L.bl(cframe_pos)          # templates are authored about their placement point (mesh_object local)
    o.rotation_euler = (0, 0, yaw)
    o.scale = scale
    (collection or bpy.context.scene.collection).objects.link(o)
    return o


# ------------------------------------------------------------------------------------------------------------ den
def cliff_den_parts():
    import re
    text = (ROOT / "src" / "shared" / "CliffDenData.lua").read_text(encoding="utf-8")
    return json.loads(re.search(r"\[=\[(.*)\]=\]", text, re.S).group(1))


def cliff_depth_fn(accept):
    """Fable R7 review A: cliff_depth(centre, inward, reach) for world_finish_path.seat_masses over the visible meshes
    `accept(name)` takes: the nearest of five rays (the centre and four points a third of the way to the blob's sides)
    along `inward` that meets one within `reach`, or None."""
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    dg = bpy.context.evaluated_depsgraph_get()
    trees = [(BVHTree.FromObject(o, dg), o.matrix_world, o.matrix_world.inverted()) for o in bpy.data.objects
             if o.type == "MESH" and not o.hide_render and accept(o.name)]

    def depth(c, inward, reach):
        d = L.bl(inward) - L.bl((0, 0, 0))
        d.normalize()
        side = Vector((d.y, -d.x, 0)).normalized() if abs(d.z) < .99 else Vector((1, 0, 0))
        best = None
        for off in (Vector((0, 0, 0)), side * 1.5, -side * 1.5, Vector((0, 0, 1.2)), Vector((0, 0, -1.2))):
            o = L.bl(c) + off
            for t, mw, inv in trees:
                h = t.ray_cast(inv @ o, (inv.to_3x3() @ d).normalized(), reach * 4)
                if h[0] is not None:
                    dist = ((mw @ h[0]) - o).length
                    if dist <= reach and (best is None or dist < best):
                        best = dist
        return best
    return depth


def den_sweep(c):
    """Round 7: the den's orphan sweep envelopes (world_finish_path.sweep_envelope) round the mouth only, the west flank
    and the path's foot; the path slice sweeps the rest of the path."""
    import world_finish_path as Pth
    env = Pth.sweep_envelope(c)
    return env if env == "flank" or (env and -46 < c[0] < 24 and -106 < c[2] < -78) else None


def den_recuts(Den, rows, shell):
    """Island pack parts against the new shell (architect review: re-cuts keep the pack part's own name, so
    CliffDenData.parts, WorldMotion and the Aero named surfaces still apply).

    * Any face of an island pack part with its centre or a corner inside the shell (a ray straight up from it meets the
      shell) goes: the sculpt carved only 0.3 past the collision walls and under the old, lower roof, so rock and ground
      poked through the new walls and dome. A visual-only part is re-cut under its own name; a colliding tile (whose
      convex hulls a cut would move) stays in place, invisible and still colliding, and a visual re-cut copy
      `W7_F_Over<name>` shows instead (`overlays`).
    * The grotto crystals lose the clusters at the mouth's feet (the new amber shards stand there), and the lawn and the
      ground lose what stands over the mouth's floor (it collides at 4.2; the drawn lawn stood up to 4.9 over it)."""
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    dg = bpy.context.evaluated_depsgraph_get()
    tree = BVHTree.FromObject(shell, dg)
    up = Vector((0, 0, 1))

    def inside(c):
        if c[1] < Den.FLOOR - .3 or not (-25 < c[0] < 10 and -122 < c[2] < Den.COLLAR_END):
            return False
        return tree.ray_cast(L.bl(c), up, 30)[0] is not None

    in_mouth = lambda c: Den.JW - .4 < c[0] < Den.JE + .4 and -101.6 < c[2] < -93.0 and c[1] < 5.8
    extra = {"W7_CD_Crystals__glow_pink": lambda c: -26 < c[0] < 10 and -101 < c[2] < -86,
             "W7_CD_Ground__grass": in_mouth, "W7_CD_Ground__ground": in_mouth}
    parts = cliff_den_parts()["parts"]
    out = []
    candidates = [o.name for o in bpy.data.objects if o.type == "MESH" and not o.hide_render
                  and o.name.startswith("W7_CD_") and o.name in parts and o.name != "W7_CD_CaveBars__palette"]

    # Fable world R1 fix 1: by volume, not by picked faces. A triangle goes when any of its points (corners, edge
    # middles, centre) is inside the shell or within 1.5 of it, up to y 18.5 (the dome included). The cliff face round
    # the mouth (lawnward of z -101.4 under 12.5) keeps its faces: the mouth surround covers that front. What the cut
    # opens over the dome is closed from outside by the lid (W7_F_DenLid__cliff_rock, 1.35 out).
    def near_shell(p):
        if p[1] > 18.5 or p[1] < Den.FLOOR - .7 or (p[2] > -101.4 and p[1] < 12.5):
            return False
        hit = tree.find_nearest(L.bl(p), 1.5)
        return hit[0] is not None

    # Fable R3: the island rock blade standing in front of the west post (seen from the path's approach) goes
    blade = lambda p: -18.5 < p[0] < -12.5 and -96.8 < p[2] < -90.5 and 4.6 < p[1] < 16.0

    def spans(points):
        return any(inside(p) or near_shell(p) or blade(p) for p in points)

    # Round 7 (Fable ROUND7 5, R6-CDE 3: the grass flaps in the collar, upper left, over the brow, far right): the island's
    # grass standing on the cliff round the mouth (normal y under FLAP[1]) goes outright; no more masses to hide it
    FLAP_BOX, FLAP_NY = ((-46.0, 6.0, -106.0), (24.0, 34.0, -88.0)), .6

    def flap(points, ny):
        (x0, y0, z0), (x1, y1, z1) = FLAP_BOX
        if ny < FLAP_NY and any(x0 < p[0] < x1 and y0 < p[1] < y1 and z0 < p[2] < z1 for p in points):
            return True
        # Fable R7 review (watch list: three smaller flaps left in r7-S01): also any island grass standing on edge
        # (normal y under 0.5) within 30 studs of the mouth, above y 20
        mx, mz = (Den.M["x0"] + Den.M["x1"]) / 2, Den.Z1
        return ny < .5 and any(p[1] > 20 and math.hypot(p[0] - mx, p[2] - mz) < 30 for p in points)

    import world_finish_path as Pth
    holes = []
    for name in candidates:
        o = bpy.data.objects[name]
        mw = o.matrix_world
        rot = mw.to_3x3()
        doomed_extra = extra.get(name)
        grassy = "__grass" in name or "__meadow" in name
        hits = flaps = 0
        for p in o.data.polygons:
            c = L.rb(mw @ p.center)
            pts = [L.rb(mw @ o.data.vertices[k].co) for k in p.vertices] + [c]
            if inside(c) or (doomed_extra and doomed_extra(c)) or spans(pts):
                hits += 1
            elif grassy and flap(pts, (rot @ p.normal).normalized().z):
                flaps += 1
        isl, bm_ = Pth.islands(o)
        small = sum(1 for f_, cen, area, _ in isl if Pth.sweepable(f_, area, den_sweep(cen)))
        bm_.free()
        if not hits and not flaps and not small:
            continue
        doomed = lambda c, e=doomed_extra: inside(c) or (e is not None and e(c))
        collide = parts[name]["collide"]
        face = flap if grassy else None
        if collide:
            copy, gone = recut(name, "W7_F_Over" + name[len("W7_CD_"):], doomed, spans, face)
            bpy.data.objects[name + "__pack"].name = name          # the original stays (invisible, colliding)
        else:
            copy, gone = recut(name, name, doomed, spans, face)
        # Fable world R1 fix 2: loose shards left near the mouth (islands of 60 faces or fewer, R3) go too (round 7:
        # only from a part the shell cut, as before; a part copied only for its flaps or orphans keeps its big islands)
        if hits:
            gone += drop_shards(copy, lambda c: -50 < c[0] < 25 and -112 < c[2] < -78, 60)
        # round 7 (Fable ROUND7 3): the orphan sweep over the path and the mouth's west flank
        n0 = len(copy.data.polygons)
        holes += Pth.sweep(copy, den_sweep)
        gone += n0 - len(copy.data.polygons)
        if not copy.data.polygons:
            # nothing left to show: a visual part is simply hidden; a colliding one stays invisible, colliding
            bpy.data.objects.remove(copy)
            (Den.HIDE_VISUAL if collide else Den.HIDE).append(name)
            continue
        # round 7: its own name (this used to rebind `extra`, the per-part cut rules, after the first copy, so the
        # crystal and lawn rules never ran)
        row_extra = {"overlays": name} if collide else {"replaces": name}
        row_extra.update(facesRemoved=gone, collide=False)
        rows.append(manifest_row(copy, "fixed", {"kind": "copy", "of": name}, "den", row_extra))
        out.append(copy)
    return out, holes


def rock_skin(name, where, steep=.65, keep=None):
    """Fable world R1 fixes 2 and 9 (R2): the island's steep ground faces (W1_ground, tan in game) that show where the
    sculpt took the rock in front of them get a rock skin 0.12 proud (one welded surface), in the island's cliff rock at
    the hill's cell size. The ground faces stay behind it (nothing opens)."""
    import bmesh as _bm
    verts, faces = [], []
    for o in bpy.data.objects:
        if o.type != "MESH" or o.hide_render or not any(m and m.name in ("W1_ground", "WF_ground") for m in o.data.materials):
            continue
        mw = o.matrix_world
        rot = mw.to_3x3()
        for p in o.data.polygons:
            c = L.rb(mw @ p.center)
            n = (rot @ p.normal).normalized()
            if not where(c) or abs(n.z) >= (steep(c) if callable(steep) else steep):
                continue
            if keep is not None and not keep([L.rb(mw @ o.data.vertices[k].co) for k in p.vertices] + [c]):
                continue                                  # round 7: a face-level rule (its corners and centre)
            base = len(verts)
            for k in p.vertices:
                verts.append(mw @ o.data.vertices[k].co)
            faces.append(list(range(base, base + len(p.vertices))))
    if not faces:
        return None
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    bm = _bm.new()
    bm.from_mesh(me)
    _bm.ops.remove_doubles(bm, verts=bm.verts, dist=1e-3)
    # Round 5 (studio-r3/05: thin tan wedges along the path wall): weld first, then lift each vertex along its averaged
    # normal, so neighbouring faces keep their shared edges. Offsetting each face along its own normal opened a crack
    # wherever two faces met at an angle, and the ground showed through it.
    bm.normal_update()
    lifts = [(v, v.normal.copy()) for v in bm.verts if v.link_faces]
    for v, nv in lifts:
        # opposite-wound faces welded together cancel the averaged normal: leave such a vertex where it is
        cos = min((nv.dot(f.normal) for f in v.link_faces), default=1.0)
        if nv.length < .5 or cos <= .1:
            continue
        v.co += nv * (.12 / max(cos, .5))
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = False
    triplanar_uv(obj, rock_density())
    obj.data.materials.append(island_material("cliff_rock"))
    return obj


def push_out_of_shell(obj, tree, margin, vertical=False):
    """Round 3: no vertex of `obj` inside the den shell (a ray straight up meets the shell): each one moves to the
    nearest point of the shell and `margin` beyond it (outward). The lid's offset folded through the dome where it is
    scooped, and the mouth's rock reached past the front corners; the den's checker now counts both."""
    from mathutils import Vector
    up = Vector((0, 0, 1))
    moved = 0
    mw = obj.matrix_world
    inv = mw.inverted()
    for v in obj.data.vertices:
        w = mw @ v.co
        hit = tree.ray_cast(w, up, 30)
        if hit[0] is None:
            continue
        if vertical:
            # over the highest shell layer above it (the dome's apex folds; the nearest point can be the wrong side)
            top = hit[0]
            while True:
                nxt = tree.ray_cast(top + up * .01, up, 30)
                if nxt[0] is None:
                    break
                top = nxt[0]
            v.co = inv @ (top + up * margin)
        else:
            loc, nrm, _, _ = tree.find_nearest(w)
            if loc is None:
                continue
            v.co = inv @ (loc - nrm.normalized() * margin)       # the shell's normals face in
        moved += 1
    return moved


def drop_shards(obj, where, most):
    """Delete connected islands of `most` faces or fewer whose centre is `where`; returns how many faces went."""
    import bmesh as _bm
    bm = _bm.new()
    bm.from_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    mw = obj.matrix_world
    seen, gone = set(), []
    for f in bm.faces:
        if f.index in seen:
            continue
        stack, island = [f], []
        seen.add(f.index)
        while stack:
            g = stack.pop()
            island.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h.index not in seen:
                        seen.add(h.index)
                        stack.append(h)
        if len(island) <= most:
            c = [sum(L.rb(mw @ g.calc_center_median())[i] for g in island) / len(island) for i in range(3)]
            if where(c):
                gone += island
    _bm.ops.delete(bm, geom=gone, context="FACES")
    bm.to_mesh(obj.data)
    bm.free()
    return len(gone)


def slice_den():
    import world_finish_den as Den
    OUT.mkdir(parents=True, exist_ok=True)
    TEX.mkdir(parents=True, exist_ok=True)
    rows, place = [], {"lanterns": [], "crystals": [], "stones": [], "mouthBoxes": []}
    # the shell, low and high, kept in front of the colliding island tiles where it can be (0.28 inside the collision
    # face at most); whatever still pokes through is re-cut from the island (den_recuts)
    hide_for_render(["W7_CD_PlayDen__cliff_rock", "W7_CD_PlayDen__dirt_path"])
    parts = cliff_den_parts()["parts"]
    solid = [o.name for o in bpy.data.objects if o.type == "MESH" and not o.hide_render and o.name in parts
             and "glow" not in o.name and o.name != "W7_CD_CaveBars__palette"]
    bvh = Den.obstacles(solid)
    low, info = Den.build_shell("W7_F_Den__shell", .9, .8, 9, 4, bvh=bvh)
    high, _ = Den.build_shell("WF_ShellHigh", .3, .27, 27, 12, detail=True, bvh=bvh)
    cut_objs, holes = den_recuts(Den, rows, low)
    rock_k = rock_density()
    from mathutils.bvhtree import BVHTree
    shell_tree = BVHTree.FromObject(low, bpy.context.evaluated_depsgraph_get())
    lid = Den.build_lid(low)
    push_out_of_shell(lid, shell_tree, .4, vertical=True)
    triplanar_uv(lid, rock_k)
    lid.data.materials.append(island_material("cliff_rock"))
    Den.mark_seams(low, info)
    # Fable R1 9 (the brief's fallback): two welded halves, each with its own 1024 maps. The cut runs along x -8 (the
    # back wall's seam, the cut over the mouth's middle and the collar soffit's seam); the halves share the cut's
    # vertices exactly, so nothing opens between them.
    halves = Den.split_halves(low, -8.0)
    high.data.materials.append(L.material("WF_ShellHighMat", L.hexrgb("#7E6B58")))
    floor = Den.build_floor("W7_F_Den__floor")
    floor.data.materials.append(L.material("WF_FloorBake", L.hexrgb("#6B5240")))
    fcol_path, fnrm_path = TEX / "den_floor_color.png", TEX / "den_floor_normal.png"
    size = (1024, 1024)
    density = {}
    for half, side in halves:
        Den.unwrap_half(half)
        half.data.materials.append(L.material("WF_ShellBake" + side, L.hexrgb("#7E6B58")))
    if not NO_BAKE:
        was = solo([h for h, _ in halves] + [high, floor])
        for half, side in halves:
            high.hide_render = True
            lo_b, hi_b = (-26.0, 2.0, -124.0), (10.0, 18.0, -92.0)
            pos, _ = L.bake_position(half, size, lo_b, hi_b)
            ao, _ = L.bake_ao(half, size, distance=3.5, samples=48)
            high.hide_render = False
            nrm, _ = L.bake_normal(high, half, size, extrusion=.45, ray=1.0)
            colour = Den.shell_colour(pos, ao, None)
            L.save_png(colour, TEX / f"den_shell_{side}_color.png", size)
            L.save_png(nrm, TEX / f"den_shell_{side}_normal.png", size, srgb_input=False)
        restore(was)
        fc, fn = Den.floor_tile(512)
        L.save_png(fc, fcol_path, (512, 512))
        L.save_png(fn, fnrm_path, (512, 512), srgb_input=False)
    bpy.data.objects.remove(high)
    areas = {}
    for half, side in halves:
        half.data.materials.clear()
        half.data.materials.append(L.image_material("WF_Shell" + side, TEX / f"den_shell_{side}_color.png",
                                                    TEX / f"den_shell_{side}_normal.png"))
        walls = [p for p in half.data.polygons if abs(p.normal.z) < .5]
        density[side] = {"walls": round(Den.texel_density(half, 1024, walls), 1),
                         "all": round(Den.texel_density(half, 1024), 1)}
        areas[side] = round(sum(p.area for p in half.data.polygons), 1)
        # Fable world R1 3: in game the walls read about #A89F8C from a #7E6B58 map (Aero's ambient lifts them); the
        # SurfaceAppearance tint brings them to about #7A6A5C as seen
        rows.append(manifest_row(half, "fixed", {"kind": "baked", "color": f"den_shell_{side}_color",
                                                 "normal": f"den_shell_{side}_normal", "roughness": .9,
                                                 "material": "Slate", "tint": "#B8A39E"}, "den",
                                 {"pxPerStud": density[side], "collide": False, "shadow": True}))
    floor.data.materials.clear()
    floor.data.materials.append(L.image_material("WF_Floor", fcol_path, fnrm_path))
    low = halves[0][0]
    # Fable world R1 5: the floor read #A98C78 in game from #6B5240; tinted toward #6E5140 as seen
    rows.append(manifest_row(floor, "fixed", {"kind": "tile", "color": "den_floor_color", "normal": "den_floor_normal",
                                              "studsPerTile": Den.FLOOR_TILE, "material": "Ground", "tint": "#A69487"},
                             "den", {"collide": False, "shadow": False}))
    rows.append(manifest_row(lid, "fixed", {"kind": "island", "material": "cliff_rock"}, "den",
                             {"collide": False, "shadow": True, "uvPerStud": round(rock_k, 5)}))
    # rock skin: east of the mouth (round 3), and the one contiguous tan wall left of the mouth over the path's foot (round 4,
    # studio-r3/01: x -42..-17, y 5..24; every ground face there short of a near-flat top, so the skin is one surface
    # following the ground, not loose sheets)
    import cliff_den_sculpt as S
    import world_finish_path as Pth

    def off_path(c):                      # never over the cliff path's tread
        s = S._nearest(c[0], c[2])
        a = (c[0] - s["x"]) * s["out"][0] + (c[2] - s["z"]) * s["out"][1]
        return not (abs(a) < s["w"] / 2 + .6 and c[1] < s["h"] + 1.5)

    left = lambda c: -42 < c[0] < -17 and -104 < c[2] < -84 and 5.0 < c[1] < 24.5 and off_path(c)
    skin_where = lambda c: (2 < c[0] < 24 and -106 < c[2] < -86 and c[1] > 4.8) or left(c)
    skin_steep = lambda c: .85 if c[0] < 0 else .65
    skin = rock_skin("W7_F_DenSkin__cliff_rock", skin_where, steep=skin_steep)
    # round 7 (Fable ROUND7 3, jagged shards; studio-r6e 01 left third): the orphan sweep over the skin too, and the
    # holes it and the re-cuts leave over the path backed by rock masses on the mouth's surround (the west flank's are
    # backed by the round 6 mass at (-36, 14, -98.5), already in MOUTH_BLOBS)
    # The skin is a layer of cards by construction (big ground triangles lifted 0.12): in the two envelopes round the
    # mouth any of its islands up to SKIN_SWEEP faces goes (studio-r6e 01's left third: a 16-face island of tall cards
    # west of the mouth), and rock masses take its place.
    SKIN_SWEEP = (24, 0.0)
    if skin:
        holes += Pth.sweep(skin, den_sweep, SKIN_SWEEP)
        if not skin.data.polygons:
            bpy.data.objects.remove(skin)
            skin = None
    r6 = next(c for c, r, yaw in Den.MOUTH_BLOBS if c == (-36.0, 14.0, -98.5))      # the round 6 flank mass
    # Fable R7 review A: each backing blob sinks 1.5 into the wall and stays only if it reaches 1.0 into the cliff or
    # into another mass (den/CAM-MOUTH-EAST: one stood free against the sky)
    blobs = Pth.backing_blobs(holes, covered=[r6])
    depth = cliff_depth_fn(lambda n: (n.startswith(("W7_CD_", "W7_F_Over", "W7_F_DenLid")) and "glow" not in n
                                      and "CaveBars" not in n and "Crystals" not in n))
    seated, dropped = Pth.seat_masses(blobs, [(c, r, math.radians(y)) for c, r, y in Den.MOUTH_BLOBS], depth)
    backing = [(c, r, math.degrees(yaw)) for c, r, yaw, _ in seated]
    # the mouth surround
    mouth = Den.build_mouth("W7_F_DenMouth__cliff_rock", extra=backing)
    push_out_of_shell(mouth, shell_tree, .3)
    if backing:
        # the skin again, less what the surround now covers in those envelopes: a ground face the masses do not reach
        # (the lawn's keep-out flattens their feet) keeps its skin, so no tan shows through between them
        from mathutils import Vector as _V
        m_tree = BVHTree.FromObject(mouth, bpy.context.evaluated_depsgraph_get())

        def covered(c):
            hits, o = 0, L.bl(c)
            while True:
                h = m_tree.ray_cast(o, _V((0, 0, 1)), 60)
                if h[0] is None:
                    break
                hits, o = hits + 1, h[0] + _V((0, 0, .001))
            return hits % 2 == 1
        if skin:
            bpy.data.objects.remove(skin)
        skin = rock_skin("W7_F_DenSkin__cliff_rock", skin_where, steep=skin_steep,
                         keep=lambda pts: not (den_sweep(pts[-1]) and all(covered(q) for q in pts)))
    triplanar_uv(mouth, rock_k)
    mouth.data.materials.append(island_material("cliff_rock"))
    rows.append(manifest_row(mouth, "fixed", {"kind": "island", "material": "cliff_rock"}, "den",
                             {"collide": False, "shadow": True, "uvPerStud": round(rock_k, 5)}))
    place["mouthBoxes"] = Den.MOUTH_BOXES
    # the apron: worn earth over the greybox slabs, rolling into the lawn
    dirt_k = island_density("W7_CD_CliffPath__dirt_path")    # the sculpt's path: the garden path's density
    apron = Den.build_apron("W7_F_DenApron__dirt_path", dirt_k)
    apron.data.materials.append(island_material("dirt_path"))
    rows.append(manifest_row(apron, "fixed", {"kind": "island", "material": "dirt_path"}, "den",
                             {"collide": False, "shadow": False, "doubleSided": True, "uvPerStud": round(dirt_k, 5)}))
    place["apronStones"] = Den.APRON_STONES
    place["tufts"] = Den.APRON_TUFTS
    place["paw"] = Den.PAW
    place["frame"], place["cloth"] = Den.FRAME, Den.CLOTH
    # templates: lantern (cage + panes), crystal, flat stone
    cage, panes = Den.build_lantern()
    crystal = Den.build_crystal()
    stone = Den.build_flat_stone()
    iron = L.material("WF_Iron", L.hexrgb("#3A3028"), rough=.7)
    glow = L.material("WF_Pane", L.hexrgb("#C9772E"), emission=L.hexrgb("#C9772E"), strength=4.0)
    amber = L.material("WF_Crystal", L.hexrgb("#C98A3C"), emission=L.hexrgb("#C98A3C"), strength=1.6)
    pawc = L.material("WF_Stone", L.hexrgb("#8A8378"), rough=.95)
    cage.data.materials.append(iron)
    panes.data.materials.append(glow)
    crystal.data.materials.append(amber)
    stone.data.materials.append(pawc)
    for t, look in ((cage, {"kind": "flat", "color": "#3A3028", "material": "Metal"}),
                    (panes, {"kind": "flat", "color": "#C9772E", "material": "Neon"}),
                    (crystal, {"kind": "flat", "color": "#C98A3C", "material": "Neon", "transparency": .4}),
                    (stone, {"kind": "flat", "color": "#8A8378", "material": "Slate"})):
        row = manifest_row(t, "template", look, "den", {"collide": False, "shadow": False})
        row["centre"][1] = round(row["centre"][1] - 4, 4)     # local: the offset of the mesh's centre from its point
        rows.append(row)
    # placements: the crystals (two clusters at the mouth's feet, one in each alcove), the stones pressed into the floor
    place["crystals"] = Den.CRYSTALS
    place["stones"] = Den.FLOOR_STONES
    place["lanterns"] = {"light": {"color": "#FFB870", "brightness": .9, "range": 14, "shadows": False},
                         "ledgeY": Den.LEDGE_Y, "cord": .8}
    tri = {r["name"]: r["triangles"] for r in rows}
    report = {"holes": [[[round(v, 2) for v in h[0]], round(h[1], 1), h[3]] for h in holes],
              "backing": [[round(v, 2) for v in b[0]] for b in backing],
              "backingDropped": [[round(v, 2) for v in b[0]] for b in dropped],
              "shell": tri["W7_F_Den__shellWest"] + tri["W7_F_Den__shellEast"], "floor": tri["W7_F_Den__floor"],
              "mouth": tri["W7_F_DenMouth__cliff_rock"],
              "lantern": tri["W7_F_Lantern__cage"] + tri["W7_F_Lantern__pane"], "crystal": tri["W7_F_Den__crystal"],
              "stone": tri["W7_F_Stone__flat"], "pxPerStud": density, "areas": areas}
    print("WORLDFINISH den", json.dumps(report))
    # export: fixed parts carry world coordinates (their centre is where the part goes); templates are authored about
    # their placement point, so their centre is the offset from it (Roblox centres a MeshPart on its mesh's bounds)
    if skin:
        rows.append(manifest_row(skin, "fixed", {"kind": "island", "material": "cliff_rock"}, "den",
                                 {"collide": False, "shadow": True, "doubleSided": True}))
        report["skin"] = L.tris(skin)
    exported = [h for h, _ in halves] + [floor, lid, mouth, apron, cage, panes, crystal, stone] + cut_objs + \
        ([skin] if skin else [])
    report["apron"] = L.tris(apron)
    L.export_fbx(exported, OUT / "world-finish-den.fbx")
    remeasure(rows)
    (OUT / "world-finish-den.json").write_text(json.dumps({"slice": "den", "parts": rows, "place": place,
                                                            "hide": Den.HIDE, "hideVisual": Den.HIDE_VISUAL, "report": report}, indent=1) + "\n",
                                               encoding="utf-8")
    if RENDERS:
        studio_look()
        den_render_dressing(Den, cage, panes, crystal, stone)
        Path(RENDERS).mkdir(parents=True, exist_ok=True)
        for label in ("CAM-MOUTH30", "CAM-DEN-IN", "CAM-DEN-BACK", "CAM-MOUTH-WEST", "CAM-MOUTH-EAST"):
            W.render(label, RENDERS)
        W.render("CAM-MOUTH30", RENDERS, night=True)
        W.render("CAM-DEN-IN", RENDERS, night=True)


def den_render_dressing(Den, cage, panes, crystal, stone):
    """Review-render stand-ins for the den's Roblox props (DenGreybox rows: the timber frame, the sign, the mat, the
    Deck stump and screen, the Dash gate, the crates) plus the four lanterns with their lights, the crystals and the
    paw stones, placed as WorldFinishMount places them."""
    wood, dark = L.material("WF_Wood", L.hexrgb("#7A5A3A")), L.material("WF_Dark", L.hexrgb("#5C4330"))
    cloth = L.material("WF_Cloth", L.hexrgb("#B8AE98"))
    red = L.material("WF_Red", L.hexrgb("#D9725E"))
    screen = L.material("WF_Screen", L.hexrgb("#3D6F62"), emission=L.hexrgb("#3D6F62"), strength=.4)   # as DenGreybox (round 6)

    def box(name, c, s, mat, rot=(0, 0, 0)):
        bpy.ops.mesh.primitive_cube_add(size=1)
        o = bpy.context.object
        o.name = name
        o.location = L.bl(c)
        o.scale = (s[0], s[2], s[1])
        o.rotation_euler = rot
        o.data.materials.append(mat)
        return o

    def disc(name, c, d, h, mat):
        bpy.ops.mesh.primitive_cylinder_add(radius=d / 2, depth=h, vertices=32)
        o = bpy.context.object
        o.name = name
        o.location = L.bl(c)
        o.data.materials.append(mat)
        return o

    # round 6: DenGreybox's props (no frame), the sign under the brow, the room's props spread, the Garden Dash gate
    import cliff_den_sculpt as S_
    M_, D_ = S_.MOUTH, S_.DEN
    F_ = D_["floor"]
    for x, side in ((M_["x0"], -1), (M_["x1"], 1)):
        # code review r6: as DenGreybox, the foot 1.6 into the opening and the top back on the jamb
        box("WF_Prop", (x - side * 1.6 + side * 5 * math.sin(math.radians(8)), F_ + 5, D_["z1"] + 1.6), (1, 10, 1), dark,
            rot=(math.radians(-4.8), math.radians(-side * 8), 0))
    box("WF_Sign", (-7, F_ + 9.2, D_["z1"] + .6), (8, 2.2, .25), wood)
    disc("WF_Mat", (-7, F_ + .04, -112), 10, .08, cloth)
    disc("WF_MatInner", (-7, F_ + .05, -112), 8, .08, red)
    disc("WF_Stump", (-7, F_ + 1.1, -121.5), 5, 2.2, dark)
    box("WF_DeckScreen", (-7, F_ + 3.25, -120.3), (2.8, .05, 1.7), screen, rot=(math.radians(55), 0, 0))
    teal, cream = L.material("WF_Teal", L.hexrgb("#2F7F8C")), L.material("WF_Cream", L.hexrgb("#DCCAA2"))
    gx, gz = -20.0, -112.0
    fx, fz = -7.0 - gx, -106.0 - gz
    ln = math.hypot(fx, fz)
    sx, sz = -fz / ln, fx / ln
    for side in (-1, 1):
        box("WF_GatePost", (gx + side * 5 * sx, F_ + 5.5, gz + side * 5 * sz), (1, 11, 1), teal)
    box("WF_GateBanner", (gx, F_ + 9.7, gz), (9, 1.4, .3), cream, rot=(0, math.atan2(sz, sx), 0))
    for x, z in ((-13, -120.5), (-1, -120.5), (6, -112)):
        box("WF_Crate", (x, F_ + .8, z), (1.6, 1.6, 1.6), wood)
    for i, (lx, ly, lz) in enumerate(Den.LANTERNS):
        place_copy(cage, f"WF_Cage{i}", (lx, ly, lz))
        place_copy(panes, f"WF_Pane{i}", (lx, ly, lz))
        light = bpy.data.lights.new(f"WF_Lamp{i}", "POINT")
        light.color = L.hexrgb("#FFB870")
        light.energy = 420
        light.shadow_soft_size = .3
        lo = bpy.data.objects.new(f"WF_Lamp{i}", light)
        lo.location = L.bl((lx, ly, lz))
        bpy.context.scene.collection.objects.link(lo)
    for k, c in enumerate(Den.CRYSTALS):
        place_copy(crystal, f"WF_Crystal{k}", c["at"], yaw=c["yaw"], scale=(c["scale"], c["scale"], c["scale"]))
    for k, s in enumerate(Den.FLOOR_STONES + Den.APRON_STONES):
        place_copy(stone, f"WF_Stone{k}", s["at"], yaw=s["yaw"], scale=(s["size"][0], s["size"][2], s["size"][1]))


def island_object(mesh, kind, uv_from=None):
    """Build a Mesh as an island-material part: world-projected UVs at the island's density for that material."""
    k = rock_density() if kind == "cliff_rock" else (island_density(uv_from) if uv_from else .25)
    obj = mesh.build(k)
    if not obj.get("own_uvs"):
        triplanar_uv(obj, k)
    obj.data.materials.append(island_material(kind))
    return obj, k


def slice_path():
    import cliff_den_sculpt as S
    import world_finish_path as Pth
    OUT.mkdir(parents=True, exist_ok=True)
    S.build_path(list(bpy.data.objects))           # fills PATH_BLOCKS (the fin and notch boxes); its meshes are dropped
    for o in [o for o in bpy.data.objects if o.name.startswith("CD_CliffPath__")]:
        bpy.data.objects.remove(o)
    hide_for_render(["W7_CD_CliffPath__cliff_rock", "W7_CD_CliffPath__dirt_path"])
    rows, place = [], {}
    dirt_m, grass_m = Pth.tread()
    wall_m, foot_m = Pth.wall_and_shoulders()
    steps_m, step_rows = Pth.steps()
    parts = []
    for mesh, kind, uv in ((dirt_m, "dirt_path", "W7_CD_CliffPath__dirt_path"), (grass_m, "grass", "W7_CD_Rocks__grass"),
                           (wall_m, "cliff_rock", "W7_CD_Region__cliff_rock"),
                           (foot_m, "dirt_path", "W7_CD_CliffPath__dirt_path"),
                           (steps_m, "boulder_rock", "W7_CD_Rocks__boulder_rock")):
        obj, k = island_object(mesh, kind, uv)
        if mesh is wall_m:
            Pth.facet(obj)
            Pth.tuck(obj)
            if not obj.get("own_uvs"):
                triplanar_uv(obj, k)
        parts.append(obj)
        rows.append(manifest_row(obj, "fixed", {"kind": "island", "material": kind}, "path",
                                 {"collide": False, "shadow": kind in ("cliff_rock", "boulder_rock"), "doubleSided": True,
                                  "uvPerStud": round(k, 5)}))
    rocks = Pth.fin_and_notch()
    triplanar_uv(rocks, rock_density())
    rocks.data.materials.append(island_material("cliff_rock"))
    parts.append(rocks)
    rows.append(manifest_row(rocks, "fixed", {"kind": "island", "material": "cliff_rock"}, "path",
                             {"collide": False, "shadow": True}))
    # the kit: five lip stones and the stake (templates about their base point)
    kit = [Pth.lip_stone(k) for k in range(5)]
    bk = island_density("W7_CD_Rocks__boulder_rock")
    for o in kit:
        triplanar_uv(o, bk)
        o.data.materials.append(island_material("boulder_rock"))
        row = manifest_row(o, "template", {"kind": "island", "material": "boulder_rock"}, "path",
                           {"collide": False, "shadow": False, "uvPerStud": round(bk, 5)})
        row["centre"][1] = round(row["centre"][1] - 4, 4)
        rows.append(row)
    st = Pth.stake()
    st.data.materials.append(L.material("WF_Stake", L.hexrgb("#5C4330")))
    row = manifest_row(st, "template", {"kind": "flat", "color": "#5C4330", "material": "Wood"}, "path",
                       {"collide": False, "shadow": False, "doubleSided": True})
    row["centre"][1] = round(row["centre"][1] - 4, 4)
    rows.append(row)
    # Fable D1 1: re-cuts of the visual island parts that poke into the new cut. Run on the den's saved scene, these
    # carry the den's cuts too, so the path slice requires the den slice (data: requires = "den").
    parts_cd = cliff_den_parts()["parts"]
    cuts, path_hide, path_hide_visual = [], [], []
    test = lambda pts: Pth.recut_test(pts) or Pth.in_fin(pts)       # round 3: and inside the fin cluster
    # round 7 (Fable ROUND7 1, 2, 3): ground and grass standing on edge behind the inner edge (the pale bank), whatever
    # is left from 1.0 under the tread (the slivers), and the small orphan islands over the path and the west flank
    import re
    holes = []
    # round 7: the den's overlay copies of colliding tiles (W7_F_Over<tile>) too. Their tile is hidden in this scene, so
    # until now the path's cuts never reached them; a path copy of the den's copy (both slices' cuts) replaces it, and
    # the den's copy is hidden (the path requires the den)
    def den_overlay_tile(n):
        return "W7_CD_" + n[len("W7_F_Over"):] if n.startswith("W7_F_Over") else None
    for o in [o for o in bpy.data.objects if o.type == "MESH" and not o.hide_render
              and (o.name in parts_cd or den_overlay_tile(o.name) in parts_cd)
              and o.name != "W7_CD_CaveBars__palette" and "glow" not in o.name]:
        mw = o.matrix_world
        rot = mw.to_3x3()
        face = Pth.bank_face if re.match(r"(ground|grass|meadow)", o.name.rsplit("__", 1)[1]) else None

        def hit(p):
            pts = [L.rb(mw @ o.data.vertices[k].co) for k in p.vertices]
            c = L.rb(mw @ p.center)
            return test(pts) or Pth.under_tread(c) or (face is not None and face(pts + [c], (rot @ p.normal).normalized().z))
        isl, bm_ = Pth.islands(o)
        small = any(Pth.sweepable(f_, area, Pth.sweep_envelope(cen)) for f_, cen, area, _ in isl)
        bm_.free()
        if not small and not any(hit(p) for p in o.data.polygons):
            continue
        den_copy = o.name if den_overlay_tile(o.name) else None
        name = den_overlay_tile(o.name) or o.name
        collide = parts_cd[name]["collide"]
        if den_copy:
            copy, gone = recut(den_copy, "W7_F_PathOver" + name[len("W7_CD_"):], Pth.under_tread, test, face)
            bpy.data.objects[den_copy + "__pack"].name = den_copy
            path_hide.append(den_copy)                       # the den's copy goes; the tile stays invisible, colliding
        elif collide:
            # a colliding tile keeps its hulls: it stays invisible and colliding under a visual re-cut copy
            copy, gone = recut(name, "W7_F_PathOver" + name[len("W7_CD_"):], Pth.under_tread, test, face)
            bpy.data.objects[name + "__pack"].name = name
        else:
            copy, gone = recut(name, name, Pth.under_tread, test, face)
        n0 = len(copy.data.polygons)
        holes += Pth.sweep(copy)
        gone += n0 - len(copy.data.polygons)
        if not copy.data.polygons:
            bpy.data.objects.remove(copy)
            if not den_copy:
                (path_hide_visual if collide else path_hide).append(name)
            continue
        extra = {"overlays": name} if collide else {"replaces": name}
        extra.update(facesRemoved=gone, collide=False)
        cuts.append(copy)
        rows.append(manifest_row(copy, "fixed", {"kind": "copy", "of": name}, "path", extra))
    # Fable world R1 9 (R2): the hill's steep tan ground faces near the path get the rock skin too
    def near_path(c):
        s = S._nearest(c[0], c[2])
        return c[1] > 5.0 and (c[0] - s["x"]) ** 2 + (c[2] - s["z"]) ** 2 < 12 ** 2 and not (c[0] > -26 and c[2] < -86)
    pskin = rock_skin("W7_F_PathSkin__cliff_rock", near_path)
    if pskin:
        holes += Pth.sweep(pskin)                                    # round 7 (Fable ROUND7 3)
        if not pskin.data.polygons:
            bpy.data.objects.remove(pskin)
            pskin = None
    if pskin:
        parts.append(pskin)
        rows.append(manifest_row(pskin, "fixed", {"kind": "island", "material": "cliff_rock"}, "path",
                                 {"collide": False, "shadow": True, "doubleSided": True}))
    # round 7 (Fable ROUND7 3): rock masses over the holes the sweep left over the path, one per 10 studs of hole,
    # standing 0.8 proud, rock cells about 6 studs (the west flank's holes: the den's round 6 mass)
    depth = cliff_depth_fn(lambda n: n.startswith(("W7_CD_", "W7_F_Over", "W7_F_PathOver", "W7_F_PathWall",
                                                   "W7_F_PathRocks", "W7_F_DenMouth", "W7_F_DenLid"))
                           and "glow" not in n and "CaveBars" not in n and not n.startswith("W7_CD_CliffPath"))
    import world_finish_den as Den
    seated, dropped = Pth.seat_masses(Pth.backing_blobs(holes), [(c, r, math.radians(y)) for c, r, y in Den.MOUTH_BLOBS],
                                      depth)
    backing = Pth.backing_mass("W7_F_PathBacking__cliff_rock", seated)
    if backing:
        triplanar_uv(backing, rock_density())
        backing.data.materials.append(island_material("cliff_rock"))
        parts.append(backing)
        rows.append(manifest_row(backing, "fixed", {"kind": "island", "material": "cliff_rock"}, "path",
                                 {"collide": False, "shadow": True}))
    # Fable R7 review B: a lip stone with no surface within 0.5 under its centre goes (one stood in the sky)
    from mathutils import Vector as _V
    from mathutils.bvhtree import BVHTree as _T
    dg = bpy.context.evaluated_depsgraph_get()
    ground_trees = [(_T.FromObject(o, dg), o.matrix_world, o.matrix_world.inverted()) for o in bpy.data.objects
                    if o.type == "MESH" and not o.hide_render and not o.name.startswith(("WF_", "W7_F_Lip", "W7_F_Stake"))
                    and "Backdrop" not in o.name]

    def under(lp):
        top = L.bl((lp["at"][0], lp["seat"] + 1.0, lp["at"][2]))
        for t, mw, inv in ground_trees:
            h = t.ray_cast(inv @ top, (inv.to_3x3() @ _V((0, 0, -1))).normalized(), 10.0)
            if h[0] is not None and (mw @ h[0]).z + 4 >= lp["seat"] - .5:
                return True
        return False
    lips_all = Pth.lip_layout()
    lips = [lp for lp in lips_all if under(lp)]
    stakes, ropes = Pth.stake_layout()
    boulders = Pth.foot_stones()
    place.update(lips=lips, stakes=stakes, ropes=ropes, tufts=Pth.tufts(), steps=step_rows, boulders=boulders,
                 hideBoxes=["lip", "fin"], extraBoxes=Pth.fin_boxes(), requires="den" if cuts else None,
                 rope={"color": "#B79A66", "width": .1, "sag": .35})
    report = {r["name"]: r["triangles"] for r in rows}
    report["fixedTotal"] = sum(r["triangles"] for r in rows if r["role"] == "fixed")
    report["lipStones"], report["stakes"] = len(lips), len(stakes)
    report["stepMaxDeviation"] = max((s["dev"] for s in step_rows), default=0)
    report["lipStonesByShelf"] = {str(k): sum(1 for lp in lips if lp["shelf"] == k) for k in (1, 2, 3)}
    report["lipStonesDropped"] = [lp["at"] for lp in lips_all if lp not in lips]
    report["backingKept"], report["backingDropped"] = len(seated), [[round(v, 2) for v in b[0]] for b in dropped]
    report["holes"] = [[[round(v, 2) for v in h[0]], round(h[1], 1), h[3]] for h in holes]
    print("WORLDFINISH path", json.dumps(report))
    L.export_fbx(parts + kit + [st] + cuts, OUT / "world-finish-path.fbx")
    remeasure(rows)
    (OUT / "world-finish-path.json").write_text(json.dumps({"slice": "path", "parts": rows, "place": place,
                                                             "hide": ["W7_CD_CliffPath__cliff_rock",
                                                                      "W7_CD_CliffPath__dirt_path"] + path_hide,
                                                             "hideVisual": path_hide_visual,
                                                             "report": report}, indent=1) + "\n", encoding="utf-8")
    if RENDERS:
        studio_look()
        for i, lp in enumerate(lips):
            place_copy(kit[lp["kit"] - 1], f"WF_Lip{i}", lp["at"], yaw=lp["yaw"])
        for i, s in enumerate(stakes):
            place_copy(st, f"WF_Stake{i}", s["at"], yaw=s["yaw"])
        for i, b in enumerate(boulders):
            place_copy(kit[b["kit"] - 1], f"WF_Boulder{i}", b["at"], yaw=b["yaw"], scale=(b["scale"][0], b["scale"][2], b["scale"][1]))
        Path(RENDERS).mkdir(parents=True, exist_ok=True)
        for label in ("CAM-HUB", "CAM-FOOT", "CAM-SHELF2", "CAM-TURN", "CAM-ARRIVE"):
            W.render(label, RENDERS)


def slice_terrace():
    import world_finish_terrace as Ter
    OUT.mkdir(parents=True, exist_ok=True)
    rows, parts = [], []
    cap, face_m, ol, cols = Ter.cap_and_face()
    triplanar_uv(cap, island_density("W7_CD_Rocks__grass"))
    cap.data.materials.append(island_material("grass"))
    parts.append(cap)
    for mesh, kind, uv in ((face_m, "cliff_rock", "W7_CD_Region__cliff_rock"),
                           (Ter.tongues(cols, ol), "grass", "W7_CD_Rocks__grass"),
                           (Ter.earth_patch(), "dirt_path", "W7_CD_CliffPath__dirt_path")):
        obj, k = island_object(mesh, kind, uv)
        parts.append(obj)
    rocks, slab_m = Ter.outcrops_and_slab()
    triplanar_uv(rocks, island_density("W7_CD_Region__cliff_rock"))
    rocks.data.materials.append(island_material("cliff_rock"))
    slab, _ = island_object(slab_m, "boulder_rock", "W7_CD_Rocks__boulder_rock")
    parts += [rocks, slab]
    for o in parts:
        kind = o.name.rsplit("__", 1)[1]
        rows.append(manifest_row(o, "fixed", {"kind": "island", "material": kind}, "terrace",
                                 {"collide": False, "shadow": kind in ("cliff_rock", "boulder_rock"), "doubleSided": True}))
    log, trunk = Ter.log_bench(), Ter.trunk()
    bark_k = island_density("W7_Trunks__bark") if bpy.data.objects.get("W7_Trunks__bark") else .25
    for o in (log, trunk):
        triplanar_uv(o, bark_k)
        o.data.materials.append(island_material("bark"))
        row = manifest_row(o, "template", {"kind": "island", "material": "bark"}, "terrace",
                           {"collide": False, "shadow": True, "doubleSided": True})
        row["centre"][1] = round(row["centre"][1] - 4, 4)
        rows.append(row)
    import math as _m
    yaw = _m.atan2(-Ter.S.TIER_D[1], Ter.S.TIER_D[0])
    lx, _, lz = Ter.T(Ter.LOOKOUT[0] + .5, Ter.LOOKOUT[1] - .8)
    tx, _, tz = Ter.T(20.0, -12.0)
    place = {"lips": Ter.lip_layout(ol), "tufts": Ter.plants(), "extraBoxes": Ter.outcrop_boxes(), "requires": "path",
             "logs": [{"template": "W7_F_TerraceLog__bark", "at": [lx, Ter.Y + .35, lz], "yaw": yaw}],
             "trunks": [{"template": "W7_F_TerraceTrunk__bark", "at": [tx, Ter.Y, tz], "yaw": .4}],
             "kitCrowns": [{"template": "W7_Kit_Crown_Round__foliage", "at": [tx + .8, Ter.Y + 15.2, tz], "yaw": .7,
                            "scale": 1.5}],   # round 6 (Fable 2): the tree 18
             "dressTier": {"hide": ["Floor", "FaceGarden", "SkirtOuter", "SkirtNorthEast", "SkirtSouthWest", "BalustradeNorth",
                                    "BalustradeSouth", "RimOuter", "RimNorthEast", "RimSouthWest"],
                           "remove": ["ClumpOne", "ClumpOneTop", "ClumpTwo", "PadCrunch", "PadPop", "PadMoss", "TreePole"],
                           "prefix": "W7T_"}}
    report = {r["name"]: r["triangles"] for r in rows}
    report["fixedTotal"] = sum(r["triangles"] for r in rows if r["role"] == "fixed")
    print("WORLDFINISH terrace", json.dumps(report))
    L.export_fbx(parts + [log, trunk], OUT / "world-finish-terrace.fbx")
    remeasure(rows)
    (OUT / "world-finish-terrace.json").write_text(json.dumps({"slice": "terrace", "parts": rows, "place": place,
                                                                "hide": [], "report": report}, indent=1) + "\n",
                                                    encoding="utf-8")
    if RENDERS:
        studio_look()
        place_copy(log, "WF_Log", place["logs"][0]["at"], yaw=yaw)
        place_copy(trunk, "WF_Trunk", place["trunks"][0]["at"], yaw=.4)
        kit = {o.name: o for o in bpy.data.objects if o.name.startswith("W7_F_Lip")}
        for i, lp in enumerate(place["lips"]):
            t = kit.get(f"W7_F_Lip{lp['kit']}__boulder_rock")
            if t:
                place_copy(t, f"WF_TLip{i}", lp["at"], yaw=lp["yaw"])
        hide_for_render([o.name for o in bpy.data.objects if o.name.startswith("WF_Slab")])
        Path(RENDERS).mkdir(parents=True, exist_ok=True)
        for label in ("CAM-HUB", "CAM-LAWN01", "CAM-ARRIVE", "CAM-LOOKOUT", "CAM-BENCH"):
            W.render(label, RENDERS)


if __name__ == "__main__":
    {"den": slice_den, "path": slice_path, "terrace": slice_terrace}[SLICE]()
    if "--save" in ARGS:              # a copy of the finished scene, for section views (never over the preview blend)
        bpy.ops.wm.save_as_mainfile(filepath=ARGS[ARGS.index("--save") + 1], copy=True)
