"""Sanity-check the mockup height field at gameplay spots (no scene is built).

  blender --factory-startup -b --python artifacts/world1-mockup/check_layout.py
"""
import os, math, json
HERE = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(HERE, 'build_world.py'), encoding='utf-8').read()
ns = {'__file__': os.path.join(HERE, 'build_world.py')}
exec(src[:src.index('# ------------------------------------------------------------------ scene reset')], ns)
height, STATIONS, PATHS, WATER = ns['height'], ns['STATIONS'], ns['PATHS'], ns['WATER']
out = {'stations': {}, 'paths': {}}
for n, (X, Z) in STATIONS.items():
    hs = [height(X + dx, Z + dz) for dx in (-3, 0, 3) for dz in (-3, 0, 3)]
    out['stations'][n] = {'h': round(height(X, Z), 3), 'min3': round(min(hs), 3), 'max3': round(max(hs), 3)}
extra = {'ToyRest': (-5, 11.5), 'Toy': (-2, 17.5), 'HatchTreeRoot': (-3.4, -10.9), 'SpringLawn': (-10, 88), 'WestBridge': (-83, 35)}
for n, (X, Z) in extra.items():
    out['stations'][n] = {'h': round(height(X, Z), 3)}
for n, pts in PATHS.items():
    p = ns['resample'](ns['chaikin'](pts, 3), 1.0)
    hs = [height(x, z) for x, z in p]
    slope = max(abs(a - b) for a, b in zip(hs, hs[1:]))
    wet = sum(1 for h in hs if h < WATER)
    out['paths'][n] = {'min_h': round(min(hs), 2), 'max_h': round(max(hs), 2), 'max_slope_deg': round(math.degrees(math.atan(slope)), 1), 'wet_samples': wet}
json.dump(out, open(os.path.join(HERE, 'layout-check.json'), 'w'), indent=1)
print('CHECK', json.dumps(out))
