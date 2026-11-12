"""Egg Drop world 1 (v5): the v4 painted set, with richer foliage and a seamless polished marble.

Run:  blender --factory-startup -b --python assets/art-source/environment/textures/v5/generate_textures_v5.py

Reuses textures/v4/generate_textures_v4.py for every shared tile, then replaces / adds:
  foliage.png          darker painted leaves (leaf-shaped dabs in three tones over a deep green)
  foliage_blossom.png  softer, less magenta pink petals with a few leaves showing
  marble_smooth.png    polished statue marble: no block seams, soft veining only
"""
import os, math, numpy as np, bpy

HERE = os.path.dirname(os.path.abspath(__file__))
V4 = os.path.join(os.path.dirname(HERE), 'v4', 'generate_textures_v4.py')
src = open(V4, encoding='utf-8').read()
head, tail = src.split("names = list(sheet)", 1)
exec(compile(head.replace("OUT = os.path.dirname(os.path.abspath(__file__))", "OUT = %r" % HERE), V4, 'exec'))


def leaves(seed, count, lmin, lmax):
    """Leaf-shaped dabs at every angle: two offset strokes make each one a little lens."""
    a = strokes(N, seed, count, lmin, lmax, 0, math.pi)
    return np.maximum(a, np.roll(np.roll(a, 1, 0), 1, 1) * .8)


f = ramp(soft(N, 151, 3), ['#0C5A1F', '#116A25', '#177A2B'])
f = mix(f, flat('#094A19'), .6 * leaves(152, 1500, 5, 9))
f = mix(f, flat('#27983A'), .8 * leaves(153, 1700, 5, 10))
f = mix(f, flat('#4FBF4C'), .8 * leaves(154, 900, 4, 8))
f = mix(f, flat('#86DA62'), .7 * leaves(155, 260, 3, 6))
save('foliage', f)
b = ramp(soft(N, 161, 3), ['#D98AA2', '#E79DB2', '#F0AEC0'])
b = mix(b, flat('#C9748F'), .55 * leaves(162, 1200, 4, 8))
b = mix(b, flat('#F9C9D5'), .8 * leaves(163, 1700, 4, 9))
b = mix(b, flat('#FFF0F3'), .75 * leaves(164, 700, 3, 6))
b = mix(b, flat('#5DB357'), .7 * leaves(165, 120, 4, 7))
save('foliage_blossom', b)
yy, xx = np.mgrid[0:N, 0:N]
ms = ramp(soft(N, 171, 2), ['#ECE4F0', '#F3EDF2', '#F9F4EC', '#FCF8EE'])
for k, (ax, ay, sd, amt) in enumerate(((2, 1, 172, .06), (1, -2, 173, .045), (3, 2, 174, .03))):
    vein = np.abs(np.sin((ax * xx / N + ay * yy / N + soft(N, sd) * 1.3) * 2 * np.pi)) ** .3
    ms = ms * (1 - amt * (1 - vein)[..., None] * np.array([1.0, 1.0, .92]))
save('marble_smooth', ms)

exec(compile("names = list(sheet)" + tail.replace('TEXTURES_V4_OK', 'TEXTURES_V5_OK'), V4, 'exec'))
