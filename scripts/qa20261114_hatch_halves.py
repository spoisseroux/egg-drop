"""Export native lower-shell halves from isolated copies; never save a blend."""
from pathlib import Path
import hashlib,json
import bpy,bmesh
from mathutils import Vector

ROOT=Path(__file__).resolve().parent.parent
SOURCE=ROOT/"assets/art-source/eggs/eggs.blend"
assert Path(bpy.data.filepath).resolve()==SOURCE.resolve()
before=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
OUT=ROOT/"artifacts/qa-2026-11-14-v634/hatch-production"
OUT.mkdir(exist_ok=True)
source=bpy.data.objects["Egg__BottomShell"]
parts=[];rows=[]
for side,label in((-1,"Left"),(1,"Right")):
    ob=source.copy();ob.data=source.data.copy();ob.parent=None;ob.matrix_world=source.matrix_world.copy()
    ob.name="HatchLower"+label;bpy.context.scene.collection.objects.link(ob)
    bm=bmesh.new();bm.from_mesh(ob.data)
    uv=bm.loops.layers.uv.active;assert uv is not None
    # Source separates UV corner vertices. Weld positions only; UV data remains
    # per-loop, so texture seams retain their independent coordinates.
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7)
    bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=1e-7,
        plane_co=(0,0,0),plane_no=(1,0,0),clear_inner=side>0,clear_outer=side<0)
    boundary=[e for e in bm.edges if e.is_boundary and all(abs(v.co.x)<1e-6 for v in e.verts)]
    filled=bmesh.ops.holes_fill(bm,edges=boundary,sides=0)["faces"]
    for face in filled:
        for loop in face.loops:loop[uv].uv=(.02,.02)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert not any(e.is_boundary for e in bm.edges),"Native shell half must be closed"
    bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(ob.data);bm.free();ob.data.update()
    points=[ob.matrix_world@v.co for v in ob.data.vertices]
    lo=Vector(tuple(min(p[k]for p in points)for k in range(3)))
    hi=Vector(tuple(max(p[k]for p in points)for k in range(3)))
    center=(lo+hi)*.5;size=hi-lo
    # Centre geometry for a MeshPart while recording egg-base placement.
    for vertex in ob.data.vertices:vertex.co-=center
    ob.location=Vector((side*.8,0,0));ob.data.update()
    parts.append(ob);rows.append(dict(name=ob.name,triangles=len(ob.data.polygons),
        size=[size.x,size.z,size.y],center=[center.x,center.z,-center.y],closed=True,
        uv_layers=[layer.name for layer in ob.data.uv_layers],new_cut_faces=len(filled)))
bpy.ops.object.select_all(action="DESELECT")
for ob in parts:ob.select_set(True)
bpy.context.view_layer.objects.active=parts[0]
fbx=OUT/"hatch-lower-halves.fbx"
bpy.ops.export_scene.fbx(filepath=str(fbx),use_selection=True,object_types={"MESH"},
    axis_forward="-Z",axis_up="Y",apply_unit_scale=True,add_leaf_bones=False,bake_anim=False,use_mesh_modifiers=True)
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==before
report=dict(source=str(SOURCE.relative_to(ROOT)),source_sha256=before,source_unchanged=True,
    fbx=fbx.name,fbx_sha256=hashlib.sha256(fbx.read_bytes()).hexdigest(),parts=rows,
    note="UV-preserving bisected copies; closed planar cut faces use UV .02,.02. No source blend save. Coordinator uploads/imports and verifies sizes/IDs before activation.")
(OUT/"hatch-halves-manifest.json").write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
