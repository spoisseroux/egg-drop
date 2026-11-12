"""Build one source .blend per redesigned station into assets/art-source/stations/v2/, and render each.

  blender --factory-startup -b --python artifacts/world1-mockup/v6/build_stations_v2.py

Each file: collection <Station> holds the named parts (origin on the ground at the station centre, front -Y,
identity transforms, 1 unit = 1 stud). Collection Preview_Only holds a grass disc, a 5.5-stud avatar, a 2.3-stud
bear-sized block, lights and two cameras; delete it freely. Renders go to v6/stations/<Station>-front|three-quarter.png.
Re-running OVERWRITES the station files.
"""
import bpy, bmesh, math, os, json, random, sys
from mathutils import Vector, Matrix, Euler

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
TEX = os.path.join(REPO, 'assets', 'art-source', 'environment', 'textures', 'v5')
OUTDIR = os.path.join(REPO, 'assets', 'art-source', 'stations', 'v2')
RENDERS = os.path.join(HERE, 'stations')
os.makedirs(OUTDIR, exist_ok=True); os.makedirs(RENDERS, exist_ok=True)
LIB = open(os.path.join(HERE, 'world_lib.py'), encoding='utf-8').read()
MOD = open(os.path.join(HERE, 'stations_v2.py'), encoding='utf-8').read()
SUN = Vector((-0.52, -0.42, 0.70)).normalized()
INFO = {
    'CareCradle': ('Care machine: dock a pet on the cushion, restyle hue / charm, open companions', 9.5),
    'EggNest': ('Egg spot under the Hatch Tree: browse and hatch eggs', 10.5),
    'PocketDeckKiosk': ('Deck workbench: style the Pocket Deck handheld', 10.5),
    'ToyLawn': ('Toy lawn props: toys pets chase and play with', 9.0),
    'NapDais': ('Rest spot (creek nook, spring meadow): pets nap here', 7.5),
    'Bench': ('Garden bench by the plaza', 8.5),
    'PicnicTable': ('Picnic table', 10.0),
    'ArrivalDais': ('Spawn pad inside the Chime Arch', 11.5),
    'Lamp': ('Path lamp', 8.0),
}
report = {}
for key, (purpose, dist) in INFO.items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    g = {'__name__': 'station_build', 'bpy': bpy, 'bmesh': bmesh, 'math': math, 'os': os, 'json': json, 'random': random, 'sys': sys,
         'Vector': Vector, 'Matrix': Matrix, 'Euler': Euler}
    exec(compile(LIB, 'world_lib.py', 'exec'), g)
    scene = bpy.context.scene; scene.name = key; scene.unit_settings.system = 'NONE'
    COL = {}
    for nm in (key, 'Preview_Only'):
        c = bpy.data.collections.new(nm); scene.collection.children.link(c); COL[nm] = c
    COL['REF'] = COL['Preview_Only']; COL['Sky_Lighting'] = COL['Preview_Only']
    g.update(MAT={}, COL=COL, TEX=TEX, SUN=SUN, rnd=random.Random(7), _ico_cache={}, STATS={}, height=lambda X, Z: 0.0, scene=scene)
    exec(compile(MOD, 'stations_v2.py', 'exec'), g)
    g['ensure_station_mats']()
    tris = 0; names = []
    for (pn, mb, mats, smooth) in g['STATION_DEFS'][key]():
        me = mb.build('%s_%s' % (key, pn), mats, smooth=smooth)
        o = bpy.data.objects.new('%s_%s' % (key, pn), me); COL[key].objects.link(o)
        tris += g['tri_count'](me); names.append(o.name)
    if key in ('CareCradle', 'EggNest', 'PocketDeckKiosk'):
        li = bpy.data.lights.new(key + '_Glow', 'POINT'); li.energy = 300; li.color = (1.0, .84, .6); li.shadow_soft_size = 1.5
        lo = bpy.data.objects.new(key + '_Glow', li); lo.location = (0, -1.2, 4.6); COL[key].objects.link(lo)
    # ---- preview-only dressing
    mbp = g['MB'](); v, f, uv = g['lathe']([(.02, -.02), (14, -.02)], 24); mbp.add(v, f, 0, uvs=[(p[0] / 14, p[1] / 14) for p in v])
    o = bpy.data.objects.new('Preview_Ground', mbp.build('Preview_Ground', ['grass'])); COL['Preview_Only'].objects.link(o)
    av = g['avatar']('Preview_Avatar_5p5', -5.2, .4, rot=.5)
    mbb = g['MB'](); v, f = g['blob'](2, 0, rough=0, squash=(.75, .7, 1.15), center=(0, 0, 1.15)); mbb.add(v, f, 0)
    o = bpy.data.objects.new('Preview_BearSize_2p3', mbb.build('Preview_BearSize_2p3', ['ph_white'], smooth=True)); o.location = (-4.0, -2.8, 0); COL['Preview_Only'].objects.link(o)
    for unused in [m for m in bpy.data.materials if m.users == 0]: bpy.data.materials.remove(unused)
    for unused in [i for i in bpy.data.images if i.users == 0]: bpy.data.images.remove(unused)
    world = bpy.data.worlds.new('Preview_Sky'); scene.world = world; world.use_nodes = True
    world.node_tree.nodes['Background'].inputs[0].default_value = (.45, .72, .98, 1); world.node_tree.nodes['Background'].inputs[1].default_value = 1.0
    sun = bpy.data.lights.new('Preview_Sun', 'SUN'); sun.energy = 3.4; sun.color = (1.0, .97, .9)
    so = bpy.data.objects.new('Preview_Sun', sun); so.rotation_euler = (-SUN).to_track_quat('-Z', 'Y').to_euler(); so.location = (0, 0, 20); COL['Preview_Only'].objects.link(so)
    zmid = 2.6 if key in ('CareCradle', 'PocketDeckKiosk') else 1.6 if key in ('EggNest', 'Lamp') else 1.0
    cams = {}
    for cn, pos in (('front', (0, -dist * 1.45, zmid + 1.6)), ('three-quarter', (dist * .95, -dist * 1.0, zmid + 3.2))):
        cd = bpy.data.cameras.new('Preview_Cam_' + cn); cd.lens = 34; cd.clip_end = 500
        co = bpy.data.objects.new('Preview_Cam_' + cn, cd); co.location = pos
        co.rotation_euler = (Vector((0, 0, zmid)) - Vector(pos)).to_track_quat('-Z', 'Y').to_euler(); COL['Preview_Only'].objects.link(co); cams[cn] = co
    for eng in ('BLENDER_EEVEE', 'BLENDER_EEVEE_NEXT'):
        try:
            scene.render.engine = eng; break
        except TypeError: continue
    scene.render.resolution_x = 1280; scene.render.resolution_y = 800
    try: scene.view_settings.view_transform = 'Standard'
    except Exception: pass
    scene.camera = cams['three-quarter']
    path = os.path.join(OUTDIR, key + '.blend')
    bpy.ops.wm.save_as_mainfile(filepath=path, relative_remap=True)
    for img in bpy.data.images:
        if img.filepath: img.filepath = bpy.path.relpath(img.filepath)
    bpy.ops.wm.save_mainfile()
    for cn, co in cams.items():
        scene.camera = co; av.hide_render = cn == 'front'
        scene.render.filepath = os.path.join(RENDERS, '%s-%s.png' % (key, cn)); scene.render.image_settings.file_format = 'PNG'
        bpy.ops.render.render(write_still=True)
    bad = [o.name for o in COL[key].objects if o.type == 'MESH' and (o.location.length > 1e-6 or max(abs(a) for a in o.rotation_euler) > 1e-6 or max(abs(s_ - 1) for s_ in o.scale) > 1e-6)]
    zmin = min((o.matrix_world @ v.co).z for o in COL[key].objects if o.type == 'MESH' for v in o.data.vertices)
    report[key] = {'file': 'assets/art-source/stations/v2/%s.blend' % key, 'purpose': purpose, 'parts': names, 'triangles': tris,
                   'non_identity_parts': bad, 'lowest_point': round(zmin, 2)}
    print('STATION', key, tris, 'tris', len(names), 'parts', 'non-identity:', bad)
json.dump(report, open(os.path.join(HERE, 'stations.json'), 'w'), indent=1)
print('STATIONS_OK', len(report))
