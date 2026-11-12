"""Render the v2 mockup cameras (+ soft post bloom), then build v1-vs-v2 side-by-sides.

  blender --factory-startup -b assets/art-source/environment/world1-mockup-v2.blend --python artifacts/world1-mockup/v2/render_views_v2.py -- [name-filter] [scale%]
"""
import bpy, os, sys, numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
V1 = os.path.dirname(HERE)
argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
flt = argv[0] if argv else ''
pct = int(argv[1]) if len(argv) > 1 else 100
scene = bpy.context.scene
scene.render.resolution_percentage = pct
scene.render.image_settings.file_format = 'PNG'
NAMES = {'Cam_01_Overview': '01-overview', 'Cam_02_SpawnView': '02-spawn-view', 'Cam_03_Hub': '03-hub-stations',
         'Cam_04_TumbleFalls': '04-landmark-tumble-falls', 'Cam_05_Distant': '05-distant-view',
         'Cam_06_Scale': '06-scale-bear-avatar', 'Cam_07_GlowGrotto': '07-landmark-glow-grotto', 'Cam_08_Cove': '08-cove-beach',
         'Cam_09_TopDownMap': '09-top-down-map', 'Cam_10_KnollPinwheel': '10-knoll-pinwheel', 'Cam_11_ArrivalBack': '11-chime-arch'}


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


def bloom(path):
    px = load(path); rgb = px[..., :3]
    r = max(2, px.shape[1] // 110)
    gl = blur(blur(np.clip(rgb - .84, 0, 1) * 2.0, r), r * 2)
    px[..., :3] = np.clip(1 - (1 - rgb) * (1 - np.clip(gl * .32, 0, 1)), 0, 1)
    save(path, px)


for cam_name, fn in NAMES.items():
    if flt and flt not in cam_name and flt not in fn: continue
    cam = bpy.data.objects.get(cam_name)
    if not cam: continue
    scene.camera = cam
    top = cam_name == 'Cam_09_TopDownMap'
    if top:
        cam.data.type = 'ORTHO'; cam.data.ortho_scale = 470          # same scale as v1's map
    for c in bpy.data.collections:
        if c.name == 'Distant': c.hide_render = top
    path = os.path.join(HERE, fn + '.png'); scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    if not top: bloom(path)
    print('RENDERED', path)

# side by side: v1 left, v2 right (same camera for the overview, same ortho scale for the map)
for fn, out in (('01-overview.png', '12-compare-overview-v1-left-v2-right.png'), ('09-top-down-map.png', '13-compare-map-v1-left-v2-right.png')):
    a_p, b_p = os.path.join(V1, fn), os.path.join(HERE, fn)
    if not (os.path.exists(a_p) and os.path.exists(b_p)): continue
    a, b = load(a_p), load(b_p)
    if a.shape != b.shape:
        ys = (np.arange(b.shape[0]) * a.shape[0] / b.shape[0]).astype(int); xs = (np.arange(b.shape[1]) * a.shape[1] / b.shape[1]).astype(int)
        a = a[ys][:, xs]
    gap = np.ones((a.shape[0], 12, 4), np.float32)
    save(os.path.join(HERE, out), np.concatenate([a, gap, b], 1))
    print('COMPARED', out)
