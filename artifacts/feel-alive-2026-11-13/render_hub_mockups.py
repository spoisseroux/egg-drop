"""Render the hub before/after declutter and the three station close-ups.

  blender --factory-startup -b assets/art-source/environment/world1-mockup-v7.blend \
      --python artifacts/feel-alive-2026-11-13/render_hub_mockups.py

Never saves the .blend. Writes raw renders to artifacts/feel-alive-2026-11-13/raw/
and anchors.json (projected pixel positions) for compose_mockups.py, which paints
the attract treatment on top with PIL.
"""
import bpy, bmesh, json, math, os, random
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, 'raw'); os.makedirs(RAW, exist_ok=True)
SPR = os.path.join(HERE, 'sprites')
scene = bpy.context.scene
scene.render.image_settings.file_format = 'PNG'
scene.render.resolution_percentage = 100


def B(X, Y, Z): return Vector((X, -Z, Y - 4))          # Roblox studs -> Blender


STATIONS = {  # Roblox position, yaw, icon height above base
    'deck': ((-46, 4.2, -9), .45, 9.4),
    'eggs': ((-31, 4.1, -11), -.35, 5.6),
    'care': ((-17, 4.2, -15), -.5, 9.6),
}
REMOVE = ['Plaza_Ornament_09', 'Plaza_Ornament_10', 'Plaza_Ornament_11', 'Plaza_Ornament_12', 'Stairs_Urn_18', 'Stairs_Urn_19',
          'Colonnade_Column_01', 'Colonnade_Column_06', 'Colonnade_Column_07', 'Colonnade_FallenDrum_08', 'Pad_Future_A', 'Pad_Future_B']


def make_cam(name, eye, target, lens):
    cd = bpy.data.cameras.new(name); cd.lens = lens; cd.clip_end = 5000
    o = bpy.data.objects.new(name, cd); scene.collection.objects.link(o)
    o.location = B(*eye); d = B(*target) - o.location
    o.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    return o


CAMS = {'hub': (make_cam('FA_Hub', (-21, 15.5, 33), (-32, 5.5, -9), 24), 1600, 900)}
for key, (pos, yaw, _h) in STATIONS.items():
    f = Vector((math.sin(yaw), 0, math.cos(yaw))); s = Vector((f.z, 0, -f.x)); P = Vector(pos)
    eye = P + f * 15.5 + s * 3.5 + Vector((0, 4.2, 0)); tgt = P + Vector((0, 4.6 if key != 'eggs' else 3.2, 0))
    CAMS[key] = (make_cam('FA_' + key, tuple(eye), tuple(tgt), 30), 1280, 800)


def project(camobj, w, h, p):
    v = world_to_camera_view(scene, camobj, B(*p))
    return [round(v.x * w, 1), round((1 - v.y) * h, 1), round(v.z, 2)]


def anchors():
    out = {}
    for ck, (camobj, w, h) in CAMS.items():
        scene.render.resolution_x, scene.render.resolution_y = w, h
        bpy.context.view_layer.update()
        row = {'size': [w, h], 'stations': {}}
        for key, (pos, yaw, ih) in STATIONS.items():
            X, Y, Z = pos
            ring = [project(camobj, w, h, (X + math.cos(a / 48 * math.tau) * 4.7, Y + .12, Z + math.sin(a / 48 * math.tau) * 4.7)) for a in range(48)]
            icon = project(camobj, w, h, (X, Y + ih, Z)); up = project(camobj, w, h, (X, Y + ih + 1, Z))
            row['stations'][key] = {'ring': ring, 'base': project(camobj, w, h, (X, Y + .12, Z)), 'icon': icon,
                                    'top': project(camobj, w, h, (X, Y + ih - 1.6, Z)), 'sky': project(camobj, w, h, (X, Y + ih + 9, Z)),
                                    'px_per_stud': round(math.hypot(up[0] - icon[0], up[1] - icon[1]), 2)}
        out[ck] = row
    json.dump(out, open(os.path.join(HERE, 'anchors.json'), 'w'), indent=1)


def render(tag):
    for ck, (camobj, w, h) in CAMS.items():
        orient(camobj)
        scene.camera = camobj; scene.render.resolution_x, scene.render.resolution_y = w, h
        scene.render.filepath = os.path.join(RAW, '%s-%s.png' % (ck, tag))
        bpy.ops.render.render(write_still=True)


# ---------------------------------------------------------------- sprite flowers
FLOWERS = []
KINDS = ['daisy', 'tulip', 'bellflower', 'buttercup', 'starbloom']


def sprite_mesh(kind):
    img = bpy.data.images.load(os.path.join(SPR, 'flower_%s_64.png' % kind))
    mat = bpy.data.materials.new('FA_' + kind); mat.use_nodes = True
    nt = mat.node_tree; nt.nodes.clear()
    tex = nt.nodes.new('ShaderNodeTexImage'); tex.image = img; tex.interpolation = 'Closest'
    em = nt.nodes.new('ShaderNodeEmission'); em.inputs['Strength'].default_value = .82
    tr = nt.nodes.new('ShaderNodeBsdfTransparent'); mix = nt.nodes.new('ShaderNodeMixShader'); out = nt.nodes.new('ShaderNodeOutputMaterial')
    nt.links.new(tex.outputs['Color'], em.inputs['Color']); nt.links.new(tex.outputs['Alpha'], mix.inputs['Fac'])
    nt.links.new(tr.outputs[0], mix.inputs[1]); nt.links.new(em.outputs[0], mix.inputs[2]); nt.links.new(mix.outputs[0], out.inputs['Surface'])
    for attr, val in (('surface_render_method', 'DITHERED'), ('blend_method', 'HASHED')):
        try: setattr(mat, attr, val)
        except Exception: pass
    me = bpy.data.meshes.new('FA_' + kind)
    me.from_pydata([(-.5, 0, 0), (.5, 0, 0), (.5, 0, 1), (-.5, 0, 1)], [], [(0, 1, 2, 3)])
    uv = me.uv_layers.new()
    for loop, co in zip(uv.data, [(0, 0), (1, 0), (1, 1), (0, 1)]): loop.uv = co
    me.materials.append(mat)
    return me


def ground_at(X, Z):
    dg = bpy.context.evaluated_depsgraph_get()
    hit, loc, _n, _i, ob, _m = scene.ray_cast(dg, B(X, 7.2, Z), Vector((0, 0, -1)))
    if not hit or ob is None: return None
    nm = ob.name
    if not nm.startswith('Ground') or nm.startswith('Ground_ToyLawn'): return None
    return loc


def plant(rnd, cx, cz, radius, count, kinds, meshes, smin=1.05, smax=1.55):
    placed = []
    for _ in range(count * 12):
        if len(placed) >= count: break
        a, r = rnd.uniform(0, math.tau), radius * math.sqrt(rnd.random())
        X, Z = cx + math.cos(a) * r, cz + math.sin(a) * r
        if any(math.hypot(X - px, Z - pz) < .85 for px, pz in placed): continue
        if any(math.hypot(X - sp[0], Z - sp[2]) < 4.9 for sp, _y, _h in STATIONS.values()): continue
        loc = ground_at(X, Z)
        if loc is None: continue
        kind = kinds[rnd.randrange(len(kinds))]
        o = bpy.data.objects.new('FA_Flower', meshes[kind]); scene.collection.objects.link(o)
        s = rnd.uniform(smin, smax); o.scale = (s, s, s); o.location = loc + Vector((0, 0, -.04))
        FLOWERS.append(o); placed.append((X, Z))
    return len(placed)


def orient(camobj):
    c = camobj.location
    for o in FLOWERS:
        d = c - o.location
        o.rotation_euler = (0, 0, math.atan2(d.x, -d.y))


D, T, L, Y, S = 'daisy', 'tulip', 'bellflower', 'buttercup', 'starbloom'
PATCHES = [  # Roblox X, Z, radius, count, kinds
    # where marble came out: a flower patch marks the spot instead
    (-42, 9.5, 2.2, 8, [D, Y]), (-18, 9.5, 2.2, 8, [D, T]),
    (-46.5, -17.5, 2.0, 6, [S, D]), (-13.5, 5.5, 2.0, 6, [T, L]),
    (-48, -22, 3.0, 9, [S, L, D]), (-12.5, -4, 3.0, 9, [T, Y, D]),
    (-41.4, 16.4, 1.8, 5, [Y, D]), (-33.5, 25, 1.8, 5, [L, D]),
    # station runways: each station's hue, both sides of its approach
    (-52.5, -5.5, 2.4, 8, [S, S, D]), (-41.5, -15.5, 2.0, 6, [S, D]),
    (-36.5, -15.5, 1.8, 5, [Y, D]), (-25.5, -15.5, 1.8, 5, [Y, Y, D]),
    (-11.5, -19.5, 2.6, 9, [T, T, L]), (-20, -21.5, 2.2, 7, [T, L, D]),
    # plaza rim and lawn drifts
    (-50, 5, 2.6, 8, [D, L, Y]), (-10.5, 12, 2.4, 7, [D, S]),
    (-38, 22, 2.4, 7, [T, D]), (-20, 22, 2.6, 8, [Y, S, D]),
    (-56, -14, 3.0, 9, [L, T, D]), (-6, -9, 2.6, 7, [Y, D]),
    (-27, 31, 3.0, 9, [D, T, Y, S, L]), (-14, 29, 2.6, 7, [L, D]),
]


def declutter():
    for nm in REMOVE:
        o = bpy.data.objects.get(nm)
        if o: o.hide_render = True
        else: print('FA missing', nm)
    # The entablature is one mesh: drop the span that rested on column 01.
    ent = bpy.data.objects['Colonnade_Entablature']
    c1, c2 = Vector((-52.1, 10.3)), Vector((-48.8, 17.2))        # Blender XY of columns 01 and 02
    axis = (c1 - c2); axis.normalize()
    bm = bmesh.new(); bm.from_mesh(ent.data); gone = []
    for f in bm.faces:
        p = (ent.matrix_world @ f.calc_center_median()).xy - c2
        side = abs(p.x * axis.y - p.y * axis.x)
        if side < 2.2 and all(((ent.matrix_world @ v.co).xy - c2).dot(axis) > -1.35 for v in f.verts): gone.append(f)
    bmesh.ops.delete(bm, geom=gone, context='FACES'); bm.to_mesh(ent.data); bm.free()
    print('FA entablature faces removed', len(gone))


anchors()
render('before')
declutter()
rnd = random.Random(1113)
meshes = {k: sprite_mesh(k) for k in KINDS}
bpy.context.view_layer.update()
total = sum(plant(rnd, p[0], p[1], p[2], p[3], p[4], meshes) for p in PATCHES)
print('FA flowers placed', total, 'in', len(PATCHES), 'patches')
json.dump({'flowers': total, 'patches': len(PATCHES), 'removed': REMOVE}, open(os.path.join(HERE, 'mockup-stats.json'), 'w'), indent=1)
render('after')
