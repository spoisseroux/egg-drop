"""Render the v2 mockup cameras (+ a very light post bloom: v4 is meant to look crisp), then build v5-vs-v6 side-by-sides.

  blender --factory-startup -b assets/art-source/environment/world1-mockup-v6.blend --python artifacts/world1-mockup/v6/render_views_v6.py -- [name-filter] [scale%]
"""
import bpy, os, sys, numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
V1 = os.path.join(os.path.dirname(HERE), 'v5')
argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
flt = argv[0] if argv else ''
pct = int(argv[1]) if len(argv) > 1 else 100
scene = bpy.context.scene
scene.render.resolution_percentage = pct
scene.render.image_settings.file_format = 'PNG'
NAMES = {'Cam_01_Overview': '01-overview', 'Cam_02_SpawnView': '02-spawn-view', 'Cam_03_Hub': '03-hub', 'Cam_29_HubStations': '04-hub-stations-wide',
         'Cam_28_HatchTree': '05-hatch-tree', 'Cam_20_TreeCloseUp': '06-trees', 'Cam_30_ToyLawnAndBenches': '07-toy-lawn-benches', 'Cam_09_TopDownMap': '08-top-down-map',
         'Cam_13_SideFloating': '09-side-floating', 'Cam_14_PlazaCloseUp': '10-marble-plaza', 'Cam_11_MarbleArch': '11-arch-and-arrival-dais',
         'Cam_21_PoolBedCloseUp': '12-pool-and-nap-dais'}


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
    gl = blur(blur(np.clip(rgb - .93, 0, 1) * 2.0, r), r)
    px[..., :3] = np.clip(1 - (1 - rgb) * (1 - np.clip(gl * .12, 0, 1)), 0, 1)
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

# side by side: v5 left, v6 right (same camera for the overview, same ortho scale for the map)
for fn, out in (('01-overview.png', '40-compare-overview-v5-left-v6-right.png'), ('03-hub-stations.png', '41-compare-hub-v5-left-v6-right.png')):
    a_p, b_p = os.path.join(V1, fn), os.path.join(HERE, {'03-hub-stations.png': '03-hub.png'}.get(fn, fn))
    if not (os.path.exists(a_p) and os.path.exists(b_p)): continue
    a, b = load(a_p), load(b_p)
    if a.shape != b.shape:
        ys = (np.arange(b.shape[0]) * a.shape[0] / b.shape[0]).astype(int); xs = (np.arange(b.shape[1]) * a.shape[1] / b.shape[1]).astype(int)
        a = a[ys][:, xs]
    gap = np.ones((a.shape[0], 12, 4), np.float32)
    save(os.path.join(HERE, out), np.concatenate([a, gap, b], 1))
    print('COMPARED', out)
