"""Render the v2 mockup cameras (+ a very light post bloom: v4 is meant to look crisp), then build v4-vs-v5 side-by-sides.

  blender --factory-startup -b assets/art-source/environment/world1-mockup-v5.blend --python artifacts/world1-mockup/v5/render_views_v5.py -- [name-filter] [scale%]
"""
import bpy, os, sys, numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
V1 = os.path.join(os.path.dirname(HERE), 'v4')
argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
flt = argv[0] if argv else ''
pct = int(argv[1]) if len(argv) > 1 else 100
scene = bpy.context.scene
scene.render.resolution_percentage = pct
scene.render.image_settings.file_format = 'PNG'
NAMES = {'Cam_01_Overview': '01-overview', 'Cam_02_SpawnView': '02-spawn-view', 'Cam_03_Hub': '03-hub-stations',
         'Cam_04_TumbleFalls': '04-waterfall-tumble-falls', 'Cam_05_Distant': '05-distant-view',
         'Cam_06_Scale': '06-scale-bear-avatar', 'Cam_07_GlowGrotto': '07-landmark-glow-grotto', 'Cam_08_SkyFalls': '08-waterfall-sky-falls',
         'Cam_09_TopDownMap': '09-top-down-map', 'Cam_10_KnollRotunda': '10-knoll-rotunda', 'Cam_11_MarbleArch': '11-marble-chime-arch',
         'Cam_12_Underside': '12-underside', 'Cam_13_SideFloating': '13-side-floating', 'Cam_14_PlazaCloseUp': '14-marble-plaza',
         'Cam_15_TumbleFallsLower': '15-waterfall-tumble-falls-lower', 'Cam_16_Bridge': '16-closeup-bridge',
         'Cam_17_RockTexture': '17-closeup-rock-texture', 'Cam_18_WaterClear': '18-closeup-clear-water', 'Cam_19_MarbleTrim': '19-closeup-marble-trim', 'Cam_20_TreeCloseUp': '20-closeup-trees',
         'Cam_21_PoolBedCloseUp': '21-closeup-pool-bed', 'Cam_22_StreamBedCloseUp': '22-closeup-stream-bed', 'Cam_23_Workbench_Front': '23-workbench-front',
         'Cam_24_Workbench_Side': '24-workbench-side', 'Cam_25_Statue_Bear': '25-statue-bear', 'Cam_26_Statue_Eggs': '26-statue-eggs', 'Cam_27_Statue_RotundaEgg': '27-statue-rotunda-egg'}


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

# side by side: v4 left, v5 right (same camera for the overview, same ortho scale for the map)
for fn, out in (('01-overview.png', '28-compare-overview-v4-left-v5-right.png'), ('09-top-down-map.png', '29-compare-map-v4-left-v5-right.png')):
    a_p, b_p = os.path.join(V1, fn), os.path.join(HERE, fn)
    if not (os.path.exists(a_p) and os.path.exists(b_p)): continue
    a, b = load(a_p), load(b_p)
    if a.shape != b.shape:
        ys = (np.arange(b.shape[0]) * a.shape[0] / b.shape[0]).astype(int); xs = (np.arange(b.shape[1]) * a.shape[1] / b.shape[1]).astype(int)
        a = a[ys][:, xs]
    gap = np.ones((a.shape[0], 12, 4), np.float32)
    save(os.path.join(HERE, out), np.concatenate([a, gap, b], 1))
    print('COMPARED', out)
