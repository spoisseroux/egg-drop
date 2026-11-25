"""Check the den's shell for gaps from inside (WORLD-FINISH-LOOK.md probe 1, the art half), in BACKGROUND Blender on the
scene build_world_finish_art.py saved (--save):

  blender -b <den-built.blend> --python scripts/check_world_finish_den.py

From eye points across the room (and in the mouth looking in) it casts rays in every direction and names what each one
hits first. PASS when every ray from inside the room ends on the shell, the floor or a den prop, and every ray that
leaves through the mouth was aimed through the opening. Also measures the drawn wall against the collision walls at
body height (floor +1 to +6): never more than 0.3 inside or 1.0 outside (the pilaster round the live marble posts
excepted), and the drawn floor against 4.2.
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import cliff_den_sculpt as S  # noqa: E402
import world_finish_den as Den  # noqa: E402
import world_finish_lib as L  # noqa: E402

OK_PREFIX = ("W7_F_", "WF_")


def fib(n):
    out = []
    g = math.pi * (3 - math.sqrt(5))
    for k in range(n):
        y = 1 - 2 * (k + .5) / n
        r = math.sqrt(1 - y * y)
        out.append(Vector((math.cos(g * k) * r, math.sin(g * k) * r, y)))
    return out


def main():
    scene = bpy.context.scene
    bars = bpy.data.objects.get("W7_CD_CaveBars__palette")      # hidden while the den is open (CliffDenSwap.bars)
    if bars:
        bars.hide_viewport = True
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    eyes = [(-7, 6.5, -108), (-18, 6, -112), (3, 6, -112), (-7, 6, -117.5), (-19, 9.5, -103), (4, 9.5, -103),
            (-7, 11, -110), (-12, 5, -102.5), (-2, 5, -102.5)]
    bad, escaped, total = {}, 0, 0
    for e in eyes:
        o = L.bl(e)
        for d in fib(1500):
            total += 1
            hit, loc, nrm, idx, obj, mat = scene.ray_cast(dg, o, d, distance=80)
            if not hit:
                # a ray may leave only through the mouth: where it crosses the front wall plane it must be in the opening
                p = L.rb(o + d * 2)
                bad_dir = True
                if d.y > 1e-6:                                 # toward the lawn (Blender +y is Roblox -z, so -y)
                    pass
                t = ((-(Den.Z1 + Den.PIL_OFF)) - o.y) / d.y if abs(d.y) > 1e-6 else -1
                if t > 0:
                    c = L.rb(o + d * t)
                    bad_dir = not (Den.JW - .2 <= c[0] <= Den.JE + .2 and Den.FLOOR - .2 <= c[1] <= Den.SOFFIT + .2)
                if bad_dir:
                    escaped += 1
                continue
            if obj.name.startswith(OK_PREFIX):
                continue
            q = L.rb(loc)
            # outside the mouth (through the opening) anything may be seen
            if q[2] > Den.COLLAR_END - .05:
                continue
            bad.setdefault(obj.name, []).append(tuple(round(v, 2) for v in q))
    print("DENCHECK rays", total, "escaped outside the opening", escaped)
    for name, pts in sorted(bad.items(), key=lambda kv: -len(kv[1])):
        print("DENCHECK seen", name, len(pts), pts[:4])
    # wall fit at body height: horizontal rays outward from inside each collision wall
    pts, nrm, iw = Den.loop(.5)
    worst_in, worst_out = 0.0, 0.0
    from mathutils.bvhtree import BVHTree
    sv, sp = [], []
    for o in bpy.data.objects:
        if o.name.startswith("W7_F_Den__shell"):
            for p in o.data.polygons:
                b = len(sv)
                sv.extend(o.matrix_world @ o.data.vertices[k].co for k in p.vertices)
                sp.append(list(range(b, len(sv))))
    tree = BVHTree.FromPolygons(sv, sp)
    for (x, z), (nx, nz) in zip(pts, nrm):
        if Den.PIL[0] < x < Den.PIL[1] and abs(z - Den.Z1) < 1e-6:
            continue
        for y in (5.2, 6.4, 7.6, 8.8, 10.0):
            o = L.bl((x - nx * 1.0, y, z - nz * 1.0))
            hit = tree.ray_cast(o, Vector((nx, -nz, 0)), 3.0)
            if hit[0] is None:
                worst_out = max(worst_out, 9.0)
                continue
            off = hit[3] - 1.0
            if off > 1.0 or off < -.3:
                print("DENCHECK wall out of range", round(off, 2), "at", round(x, 2), y, round(z, 2))
            worst_in, worst_out = min(worst_in, off), max(worst_out, off)
    print("DENCHECK wall offset at body height: min %.2f max %.2f (allowed -0.30 .. +1.00)" % (worst_in, worst_out))
    floor = bpy.data.objects["W7_F_Den__floor"]
    ftree = BVHTree.FromObject(floor, dg)
    devs = []
    for x in range(-21, 6):
        for z in range(-118, -101):
            if not S.den_inside(x + .5, z + .5, -.5):
                continue
            if Den.JW - .7 <= x + .5 <= Den.JE + .7 and z + .5 > -101.7:
                continue                    # the threshold over the live marble sill (it collides at 4.4)
            hit = ftree.ray_cast(L.bl((x + .5, 8, z + .5)), Vector((0, 0, -1)), 10)
            if hit[0] is not None:
                devs.append(L.rb(hit[0])[1] - Den.FLOOR)
    print("DENCHECK floor vs 4.2 over %d cells: min %.3f max %.3f" % (len(devs), min(devs), max(devs)))
    ok = not bad and escaped == 0 and worst_in >= -.3 and worst_out <= 1.0 and max(abs(v) for v in devs) <= .1
    print("DENCHECK", "PASS" if ok else "FAIL")


main()
