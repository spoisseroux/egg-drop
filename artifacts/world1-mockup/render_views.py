"""Render the world1 mockup cameras, then add a soft bloom in numpy (stand-in for Roblox BloomEffect).

  blender --factory-startup -b assets/art-source/environment/world1-mockup.blend --python artifacts/world1-mockup/render_views.py -- [name-filter] [scale%]
"""
import bpy, os, sys, numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
flt = argv[0] if argv else ''
pct = int(argv[1]) if len(argv) > 1 else 100
scene = bpy.context.scene
scene.render.resolution_percentage = pct
scene.render.image_settings.file_format = 'PNG'
NAMES = {'Cam_01_Overview': '01-overview', 'Cam_02_SpawnView': '02-spawn-view', 'Cam_03_Hub': '03-hub-stations',
         'Cam_04_TumbleFalls': '04-landmark-tumble-falls', 'Cam_05_Mountains': '05-distant-mountains',
         'Cam_06_Scale': '06-scale-bear-avatar', 'Cam_07_GlowGrotto': '07-landmark-glow-grotto',
         'Cam_08_ChimeArchSea': '08-landmark-chime-arch', 'Cam_09_TopDownMap': '09-top-down-map',
         'Cam_10_Terrace': '10-pinwheel-terrace', 'Cam_11_WestBank': '11-hopstones-wobble-egg'}


def blur(a, r):
    for ax in (0, 1):
        c = np.cumsum(np.pad(a, [(r + 1, r) if k == ax else (0, 0) for k in range(3)], mode='edge'), axis=ax)
        n = a.shape[ax]
        hi = np.take(c, np.arange(2 * r + 1, 2 * r + 1 + n), axis=ax); lo = np.take(c, np.arange(0, n), axis=ax)
        a = (hi - lo) / (2 * r + 1)
    return a


def bloom(path):
    img = bpy.data.images.load(path); w, h = img.size
    px = np.empty(w * h * 4, np.float32); img.pixels.foreach_get(px); px = px.reshape(h, w, 4)
    rgb = px[..., :3]
    bright = np.clip(rgb - .80, 0, 1) * 2.0
    r = max(2, w // 110)
    g = blur(blur(bright, r), r * 2)
    out = 1 - (1 - rgb) * (1 - np.clip(g * .42, 0, 1))             # screen
    px[..., :3] = np.clip(out, 0, 1)
    img.pixels.foreach_set(px.ravel()); img.save(); bpy.data.images.remove(img)


for cam_name, fn in NAMES.items():
    if flt and flt not in cam_name and flt not in fn: continue
    cam = bpy.data.objects.get(cam_name)
    if not cam: continue
    scene.camera = cam
    hide = cam_name == 'Cam_09_TopDownMap'
    if hide:
        cam.data.type = 'ORTHO'; cam.data.ortho_scale = 470
    for c in bpy.data.collections:
        if c.name == 'Distant': c.hide_render = hide
    path = os.path.join(HERE, fn + '.png')
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    if not hide: bloom(path)
    print('RENDERED', path)
