"""Egg Drop world 1 (v3): the v2 calm set, plus light grass detail and marble.

Run:  blender --factory-startup -b --python assets/art-source/environment/textures/v3/generate_textures_v3.py

Reuses the v2 generator's code (textures/v2/generate_textures_v2.py) so the shared tiles stay identical,
then adds / replaces:
  ground_grass.png  neutral grass-detail tile for the vertex-coloured terrain (soft clumps + light/dark patches)
  grass.png         the same detail on green, for rock caps and islets
  marble.png        cream-white marble with faint warm veining
"""
import os, numpy as np, bpy

HERE = os.path.dirname(os.path.abspath(__file__))
V2 = os.path.join(os.path.dirname(HERE), 'v2', 'generate_textures_v2.py')
src = open(V2, encoding='utf-8').read()
head, tail = src.split("names = list(sheet)", 1)
head = head.replace("OUT = os.path.dirname(os.path.abspath(__file__))", "OUT = %r" % HERE)
exec(compile(head, V2, 'exec'))


def clumps(n, seed, count):
    """Soft grass detail in -1..1: large patches plus short, tapered blade strokes. Wraps."""
    rng = np.random.default_rng(seed)
    a = np.zeros((n, n))
    for _ in range(count):
        cx, cy = rng.integers(0, n, 2); L = rng.integers(3, 7); sgn = 1.0 if rng.random() < .6 else -.8; lean = rng.integers(-1, 2)
        for q in range(L):
            x = (cx + (lean * q) // 3) % n; y = (cy + q) % n
            a[y, x] += sgn * (1 - q / L)
            if q < L // 2: a[y, (x + 1) % n] += sgn * .45 * (1 - q / L)
    a = np.clip(a, -1, 1)
    return a


patch = soft(N, 201) * 2 - 1                                        # big light / dark patches
mid = (tnoise(N, 8, 202) * 2 - 1) * .5                               # clump-sized variation
blades = clumps(N, 203, 760)
detail = np.clip(.45 * patch + .25 * mid + .60 * blades, -1, 1)      # reads as grass close up, calm from afar
neutral = .875 + .125 * detail
sheet['ground_grass'] = save('ground_grass', np.repeat(neutral[..., None], 3, -1))
gcol = ramp(.5 + .5 * detail, ['#2FAE3C', '#3DBE47', '#4BCB50', '#62D85B'])
sheet['grass'] = save('grass', gcol)
sheet['meadow'] = save('meadow', dots(ramp(.5 + .5 * detail, ['#3DBE47', '#4BCB50', '#5BD658', '#72E064']), N, 23, 16, ['#FFFFFF', '#FFE96B', '#FF9CC8'], 1.4, 2.2))

y, x = np.mgrid[0:N, 0:N] / N
w1 = soft(N, 301, 2); w2 = soft(N, 302, 3)
vein = np.abs(np.sin((2 * x + y + w1 * 1.1) * 2 * np.pi)) ** .35       # thin dark lines where the sine crosses zero
vein2 = np.abs(np.sin((x - 2 * y + w2 * 1.4) * 2 * np.pi)) ** .35
mar = ramp(soft(N, 303), ['#F1EADB', '#F8F3E8', '#FFFCF5'])
mar = mar * (1 - .07 * (1 - vein)[..., None] * np.array([.8, .9, 1.0])) * (1 - .04 * (1 - vein2)[..., None])
sheet['marble'] = save('marble', mar)

exec(compile("names = list(sheet)" + tail.replace('TEXTURES_V2_OK', 'TEXTURES_V3_OK'), V2, 'exec'))
