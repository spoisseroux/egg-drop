"""Render the v7 mockup cameras by day and (for three of them) by night.

  blender --factory-startup -b assets/art-source/environment/world1-mockup-v7.blend --python artifacts/world1-mockup/v7/render_views_v7.py -- [name-filter] [scale%]

Night = world W1v7_Sky_Night, the Lighting_Night collection on, the day sun and fill off, and the unlit backdrop
materials dimmed. A light post bloom is added (a touch more at night so lamps and crystals glow).
"""
import bpy, os, sys, numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
V6 = os.path.join(os.path.dirname(HERE), 'v6')
argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
flt = argv[0] if argv else ''
pct = int(argv[1]) if len(argv) > 1 else 100
scene = bpy.context.scene
scene.render.resolution_percentage = pct
scene.render.image_settings.file_format = 'PNG'
DAY = {'Cam_01_Overview': '01-overview-day', 'Cam_02_SpawnView': '02-spawn-view-day', 'Cam_03_Hub': '03-hub-day', 'Cam_29_HubStations': '04-hub-stations-wide',
       'Cam_31_RotundaInterior': '05-rotunda-interior', 'Cam_32_RotundaEntrance': '06-rotunda-entrance', 'Cam_36_BlossomTrees': '07-blossom-trees',
       'Cam_37_BlossomTreeUnder': '08-blossom-tree-from-below', 'Cam_33_EdgeFence': '09-edge-fence-and-rocks', 'Cam_34_EdgeFromOutside': '10-edge-from-outside',
       'Cam_04_TumbleFalls': '11-waterfall-tumble-falls', 'Cam_08_SkyFalls': '12-waterfall-sky-falls', 'Cam_35_CaveBlocker': '13-cave-blocker',
       'Cam_09_TopDownMap': '14-top-down-map', 'Cam_13_SideFloating': '15-side-floating', 'Cam_05_Distant': '16-sky-and-distance'}
NIGHT = {'Cam_01_Overview': '20-overview-night', 'Cam_03_Hub': '21-hub-night', 'Cam_02_SpawnView': '22-spawn-view-night', 'Cam_35_CaveBlocker': '23-grotto-night',
         'Cam_13_SideFloating': '24-side-floating-night'}


def blur(a, r):
    for ax in (0, 1):
        c = np.cumsum(np.pad(a, [(r + 1, r) if k == ax else (0, 0) for k in range(3)], mode='edge'), axis=ax)
        n = a.shape[ax]
        a = (np.take(c, np.arange(2 * r + 1, 2 * r + 1 + n), axis=ax) - np.take(c, np.arange(0, n), axis=ax)) / (2 * r + 1)
    return a


def load(path):
    img = bpy.data.images.load(path); w, h = img.size
    px = np.empty(w * h * 4, np.float32); img.pixels.foreach_get(px); bpy.data.images.remove(img)
    return px.reshape(h, w, 4)


def save(path, px):
    h, w = px.shape[:2]
    img = bpy.data.images.new('tmp', w, h, alpha=False); img.pixels.foreach_set(px.astype(np.float32).ravel())
    img.filepath_raw = path; img.file_format = 'PNG'; img.save(); bpy.data.images.remove(img)


def bloom(path, thr, amt):
    px = load(path); rgb = px[..., :3]; r = max(2, px.shape[1] // 110)
    gl = blur(blur(np.clip(rgb - thr, 0, 1) * 2.0, r), r)
    px[..., :3] = np.clip(1 - (1 - rgb) * (1 - np.clip(gl * amt, 0, 1)), 0, 1); save(path, px)


def set_night(on):
    scene.world = bpy.data.worlds['W1v7_Sky_Night' if on else 'W1v7_Sky_Day']
    bpy.data.collections['Lighting_Night'].hide_render = not on
    for nm in ('Sun', 'SkyFill'): bpy.data.objects[nm].hide_render = on
    for m in bpy.data.materials:                                   # unlit backdrop / foam / clouds must not glow in the dark
        if m.node_tree is None: continue
        t = m.node_tree.nodes.get('NightTint')
        if t: t.outputs[0].default_value = (.20, .26, .52, 1) if on else (1, 1, 1, 1)


for night, table in ((False, DAY), (True, NIGHT)):
    set_night(night)
    for cam_name, fn in table.items():
        if flt and flt not in cam_name and flt not in fn: continue
        cam = bpy.data.objects.get(cam_name)
        if not cam: print('NO CAMERA', cam_name); continue
        scene.camera = cam
        top = cam_name == 'Cam_09_TopDownMap'
        if top: cam.data.type = 'ORTHO'; cam.data.ortho_scale = 470
        bpy.data.collections['Distant'].hide_render = top
        path = os.path.join(HERE, fn + '.png'); scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        if not top: bloom(path, .80 if night else .93, .40 if night else .12)
        print('RENDERED', path)
set_night(False)
for left, right, out in ((os.path.join(V6, '01-overview.png'), os.path.join(HERE, '01-overview-day.png'), '30-compare-overview-v6-left-v7-right.png'),
                         (os.path.join(HERE, '01-overview-day.png'), os.path.join(HERE, '20-overview-night.png'), '31-compare-overview-day-left-night-right.png')):
    if not (os.path.exists(left) and os.path.exists(right)): continue
    a, b = load(left), load(right)
    if a.shape != b.shape:
        ys = (np.arange(b.shape[0]) * a.shape[0] / b.shape[0]).astype(int); xs = (np.arange(b.shape[1]) * a.shape[1] / b.shape[1]).astype(int); a = a[ys][:, xs]
    save(os.path.join(HERE, out), np.concatenate([a, np.ones((a.shape[0], 12, 4), np.float32), b], 1)); print('COMPARED', out)
