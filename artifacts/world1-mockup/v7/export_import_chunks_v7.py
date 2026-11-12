"""Turn the hand-editable v7 scene into import chunks for Roblox.

  blender --factory-startup -b assets/art-source/environment/world1-mockup-v7.blend --python artifacts/world1-mockup/v7/export_import_chunks_v7.py

Reads world1-mockup-v7.blend (never saves over it) and writes:
  assets/art-source/environment/world1-mockup-v7-import.blend   joined chunks, one material each, under 10k triangles each,
                                                                all at the world origin with identity transforms
  v7/import-chunks.json                                         every chunk: category, material, triangles, bounds, anim
  v7/vegetation-placements.json                                 every tree / bush / flower instance (mesh, position, yaw, scale)

Chunk names: <Category>__<material>[_NN]. Animated objects (custom property `anim`, except drifting clouds) stay one
object each: Anim__<object>[__<material>]. Invisible_Collision objects are carried over unchanged.
Station anchors are empties named StationAnchor_<name>. Blender (x, y, z) = Roblox (X, -Z, Y - 4).
"""
import bpy, os, json, math
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
OUT = os.path.join(REPO, 'assets', 'art-source', 'environment', 'world1-mockup-v7-import.blend')
LIMIT = 9500
scene = bpy.context.scene
stats = json.load(open(os.path.join(HERE, 'stats.json')))
st_of = {p: s['object_prefix'] for s in stats['stations_placed'] for p in s['parts']}
ARCH = {c.name for c in bpy.data.collections['Architecture'].children}


def category(o):
    cn = o.users_collection[0].name
    if cn in ('REF', 'Cameras', 'Invisible_Collision', 'Lighting_Night', 'Sky_Lighting'): return None
    if 'anim' in o.keys() and o['anim'] != 'drift': return 'Anim__' + o.name
    if o.name in st_of: return 'Stations_' + st_of[o.name].replace('Station_', '')
    if cn == 'Ground': return 'Terrain_Ground'
    if cn == 'Underside': return 'Rocks_Underside'
    if cn == 'Wall_Crags': return 'Rocks_Walls'
    if cn in ('Rocks_Shore', 'Rocks_Field'): return 'Rocks_Loose'
    if cn in ARCH: return 'Architecture_' + cn
    if cn == 'Landmarks': return 'Vegetation_HatchTree' if 'HatchTree' in o.name or 'Tree' in o.name else 'Landmarks'
    if cn == 'Water': return 'Water_Static'
    if cn in ('Trees', 'Bushes', 'Flowers'): return 'Vegetation_' + cn
    if cn in ('Lamps', 'Stations', 'Props'): return 'Stations_Misc' if cn != 'Props' else 'Props'
    if cn == 'Sky_Islets': return 'Sky_Islets'
    if cn == 'Distant': return 'Backdrop_Clouds' if 'Cloud' in o.name else 'Backdrop_Islands'
    return 'Misc_' + cn


placements = []
for o in scene.objects:
    if o.type == 'MESH' and o.data.users > 1 and o.data.name.startswith(('Tree_', 'TreeLite_', 'Bush', 'Flowers_')):
        placements.append({'object': o.name, 'mesh': o.data.name, 'blender_location': [round(c, 3) for c in o.location],
                           'roblox_position': [round(o.location.x, 3), round(o.location.z + 4, 3), round(-o.location.y, 3)],
                           'yaw_rad': round(o.rotation_euler.z, 4), 'scale': round(o.scale.x, 4)})
json.dump({'note': 'Linked-duplicate vegetation: import each mesh once and place copies from this table.', 'instances': placements},
          open(os.path.join(HERE, 'vegetation-placements.json'), 'w'), indent=1)

# ---- gather triangles per (category, material)
buckets = {}; props = {}
dg = bpy.context.evaluated_depsgraph_get()
for o in list(scene.objects):
    if o.type != 'MESH': continue
    cat = category(o)
    if cat is None: continue
    me = o.data; mw = o.matrix_world; uvl = me.uv_layers[0].data if me.uv_layers else None
    ca = me.color_attributes.get('Col'); n_m = max(1, len(me.materials))
    if cat.startswith('Anim__'): props[cat] = {k: o[k] for k in o.keys() if k in ('anim', 'anim_note', 'anim_group')}
    for p in me.polygons:
        mat = me.materials[p.material_index].name if me.materials else 'none'
        b = buckets.setdefault((cat, mat), {'v': [], 'vid': {}, 'f': [], 'uv': [], 'col': [], 'smooth': [], 'cen': []})
        idx = []
        for li in p.loop_indices:
            vi = me.loops[li].vertex_index; key = (o.name, vi)
            if key not in b['vid']:
                b['vid'][key] = len(b['v']); b['v'].append(tuple(mw @ me.vertices[vi].co))
            idx.append(b['vid'][key])
        b['f'].append((idx, [tuple(uvl[li].uv) if uvl else (0, 0) for li in p.loop_indices],
                       [tuple(ca.data[li].color) if ca and ca.domain == 'CORNER' else (1, 1, 1, 1) for li in p.loop_indices], p.use_smooth))
        c = mw @ p.center; b['cen'].append(math.atan2(c.y, c.x))

mats = {m.name: m for m in bpy.data.materials}
new_root = bpy.data.collections.new('Import_Chunks'); manifest = []
subcols = {}


def emit(name, cat, mat, b, faces):
    remap = {}; V = []; F = []; UV = []; CL = []; SM = []
    for (idx, uvs, cols, sm) in faces:
        ff = []
        for i in idx:
            if i not in remap: remap[i] = len(V); V.append(b['v'][i])
            ff.append(remap[i])
        F.append(ff); UV += [c for uv in uvs for c in uv]; CL += [c for col in cols for c in col]; SM.append(sm)
    me = bpy.data.meshes.new(name); me.from_pydata(V, [], F)
    me.uv_layers.new(name='UVMap').data.foreach_set('uv', UV)
    me.color_attributes.new('Col', 'FLOAT_COLOR', 'CORNER').data.foreach_set('color', CL)
    if mat in mats: me.materials.append(mats[mat])
    me.polygons.foreach_set('use_smooth', SM); me.update()
    o = bpy.data.objects.new(name, me)
    top = cat.split('__')[0].split('_')[0] if not cat.startswith('Anim__') else 'Anim'
    if top not in subcols: subcols[top] = bpy.data.collections.new('Import_' + top); new_root.children.link(subcols[top])
    subcols[top].objects.link(o)
    for k, v in props.get(cat, {}).items(): o[k] = v
    tris = sum(len(f) - 2 for f in F); xs = [v[0] for v in V]; ys = [v[1] for v in V]; zs = [v[2] for v in V]
    manifest.append({'chunk': name, 'category': cat, 'material': mat, 'triangles': tris, 'anim': props.get(cat, {}).get('anim'),
                     'bounds_min': [round(min(xs), 2), round(min(ys), 2), round(min(zs), 2)], 'bounds_max': [round(max(xs), 2), round(max(ys), 2), round(max(zs), 2)]})


for (cat, mat), b in sorted(buckets.items()):
    mshort = mat.replace('W1_', '')
    tris = sum(len(f[0]) - 2 for f in b['f']); parts = max(1, math.ceil(tris / LIMIT))
    base = '%s__%s' % (cat, mshort)
    if parts == 1: emit(base, cat, mat, b, b['f'])
    else:                                                           # split a big bucket into sectors around the origin
        order = sorted(range(len(b['f'])), key=lambda k: b['cen'][k]); per = math.ceil(len(order) / parts)
        for k in range(parts): emit('%s_%02d' % (base, k + 1), cat, mat, b, [b['f'][i] for i in order[k * per:(k + 1) * per]])

# ---- swap the scene contents: chunks + collision helpers + station anchors + the day sun
keep = {o.name for o in bpy.data.collections['Invisible_Collision'].objects} | {'Sun', 'SkyFill'}
for o in list(scene.objects):
    if o.name not in keep: bpy.data.objects.remove(o, do_unlink=True)
scene.collection.children.link(new_root)
anch = bpy.data.collections.new('Station_Anchors'); scene.collection.children.link(anch)
for s in json.load(open(os.path.join(HERE, 'stations.json')))['stations']:
    e = bpy.data.objects.new('StationAnchor_' + s['name'], None); e.empty_display_type = 'ARROWS'; e.empty_display_size = 2
    e.location = s['blender_location']; e.rotation_euler = (0, 0, s['yaw_rad']); e['source_file'] = s['source_file']; anch.objects.link(e)
for c in list(bpy.data.collections):
    if not c.all_objects and c.name not in ('Import_Chunks',): bpy.data.collections.remove(c)
for blk in (bpy.data.meshes, bpy.data.cameras, bpy.data.lights):
    for d in list(blk):
        if d.users == 0: blk.remove(d)
for m in list(bpy.data.materials):
    if m.users == 0: bpy.data.materials.remove(m)
over = [m for m in manifest if m['triangles'] > 10000]
summary = {'chunks': len(manifest), 'triangles_total': sum(m['triangles'] for m in manifest), 'largest_chunk_triangles': max(m['triangles'] for m in manifest),
           'chunks_over_10k': [m['chunk'] for m in over], 'animated_chunks': sum(1 for m in manifest if m['anim']),
           'note': 'Every chunk has exactly one material, identity transform and its origin at the world origin. Blender (x, y, z) = Roblox (X, -Z, Y - 4).'}
json.dump({'summary': summary, 'chunks': manifest}, open(os.path.join(HERE, 'import-chunks.json'), 'w'), indent=1)
bpy.ops.wm.save_as_mainfile(filepath=OUT, relative_remap=True, copy=True)
print('CHUNKS', json.dumps(summary))
