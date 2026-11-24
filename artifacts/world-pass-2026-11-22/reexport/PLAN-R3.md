# World leftovers, round 3: pool map, crown reshape, fountain loop (Opus, 2026-11-23)

Spencer's go via the coordinator. Aero/beta only, nothing on live, no publish. Look numbers: `LOOK-R3.md` (Fable).
Branch `claude/island-reexport-337cd0`, fast-forwarded to `feat/egg-drop-arcade-polish` eda1e56 (beta 14).

## 1. Aero pool map

- `scripts/draw_aero_pool.py` (new, PIL/numpy, fixed seed): `assets/world/textures/aero/pool-aero.png` (seamless tile,
  14 studs, caustics) and `pool-shade.png` (soft radial falloff for the foot). Uploaded as Decals/Images (Studio MCP).
- `WorldAero.Surfaces.water_pool` gains `TextureID` (the pool tile). AeroWorld already writes TextureID through its
  records (the slice 9 palette does the same), so `/aero off` restores the island's cobalt map. Only the pool part has
  kind `water_pool` (falls, lily and ledge pools); the stream and landmark water keep theirs.
- `WorldAero.Skins.FlowSkin.water_pool`: per LOOK-R3 (the scrolling layer over the pool).
- Foot shade: a flat static Beam `PoolShade` in `AeroFalls.kitStack`, built like the Apron (Axis up, width across t),
  under it (lower `up`), tinted per LOOK-R3, level 1 on, Reduced Motion on (static, no motion).

## 2. Crown reshape + leaf tiles (kit r10)

- `build_world_aero_kit.py`: Round, Tall, Blossom are built new from LOOK-R3's clump tables (low-poly ellipsoid
  clumps, ragged lower-rim tufts, flat underside), pivot at the trunk top as today, box-projected UVs at 1/4 stud
  (one tile per 4 studs), vertex shading per LOOK-R3. The Hatch crown and the rest/bushes are unchanged.
- The old fit proof (shared crown == tree's merged leaves) no longer holds by design. Replaced by: the merged meshes'
  geometry hash still matches the manifest (the hide list stays exact); each placed new crown's footprint stays within
  a tolerance of its tree's old leaves' bounds (so it still sits on the trunk and the fade radius still fits); the trunk
  top is inside the lowest clump by at least .5 stud; tri counts at or under today's (240 / 220 / 240).
- `draw_aero_leaf_tiles.py` (new): `leaf-dark.png`, `leaf-lime.png` (256 px, seamless) and a leaf roughness map.
- Gate (`build_world_aero_kit_assets.py`): the three reshaped crowns get the leaf tiles in their SurfaceAppearance;
  Hatch and rest keep today's maps. Kit uploads as r10 through the same proof gate.

## 3. Fountain loop

- `scripts/synth_fountain_loop.py` (new, numpy, fixed seed, seamless by construction as the rustle):
  `assets/audio/custom/egg_drop_fountain_loop.wav` + a report (spectrum bands, loop-seam check, peak).
- Uploaded as Audio through Open Cloud. `WorldAero.Fountain.Voice` gets the new id; the stand-in
  (`water_bed_loop` 71747963121003 at 1.25) stays as `Voice.fallback`, used if the new asset fails to load.

## Tests

Offline runner, AeroFalls / AeroKit / AeroWorld specs (pool TextureID restore, PoolShade layer counts, voice
fallback), `world_aero_kit_test.py`, native checkpoint `--check` unchanged, Studio specs, captures for Fable.

## Architect review (2026-11-23): GO with changes, applied

| Concern | Change |
|---|---|
| New crown geometry must be in place before `centred()` measures size / pivotToCentre | `reshape()` runs inside `crowns()`, before `main()` measures |
| Prove pivot/yaw/scale with today's geometry, then check the new crown in the shared frame | old fit proof kept (every instance `fit` < .01); new: same tris, overhang <= 1 stud, trunk depth >= .5, trunk top in clump 0, no zero-area triangle; recorded per mesh as `reshape` and tested |
| Triangle counts "at or under" vs the exact merged-triangles test | kept exactly equal (240 / 220 / 240) |
| A clip the place may not use can report Success and never load | fallback also when `Ambient.length(voice)` is nil after preload |
| Random start past the end of a shorter stand-in | start is a share of the loaded clip's own TimeLength (x .98), set after load, re-applied for the fallback |
| Upload as Image, not Decal | `upload_image` ids, checked through Open Cloud: assetType Image, Approved |

## Results (Studio r5, kit r11)

- Uploads: pool tile 135229051638910 (render-compensated), glint 82414579008999, foot shade 135109259637937, leaf-dark
  94198650524622, leaf-lime 119756604191368, leaf-rough 87122441764394; fountain loop Audio 96991688758765 (moderation
  "Reviewing" at upload; loads in Studio Play as its own 32 s clip); kit r10 Model 123207026828791 (boxy clumps), r11
  Model 105545360157599 (uneven ring latitudes), both Approved; r11 through the gate.
- Found in Studio: the Aero sun lifts a part's TextureID about 1.0 / 1.22 / 1.29 (R / G / B): the tile drawn at #3BA3BE
  rendered (58, 200, 246). The shipped tile is drawn darker so it renders near the target. Part Color does not tint a
  TextureID. The stream's FlowGlint drew the cobalt water map (a white tint keeps it blue), so the stream now takes the
  glint too and matches the pool in `hub`.
- The first foot-shade falloff showed only as a 1-stud strip at the very foot (under the boil); redrawn with a plateau.
- `PreloadAsync` reports Failure for the leaf maps although they render on the crowns' SurfaceAppearance.
- Specs: offline runner 47/47 + AeroFalls 22; Studio AeroKit 7, WindClient 26, AeroFalls 22, AeroWorld 27;
  AmbientAudio stops at the beta 14 crickets case ("full at night", line 151, not touched here; the new fallback case
  passes offline). world_aero_kit_test 10/11: the native-checkpoint test fails on `world-dressing-import.json`, changed by
  beta 14's 2f60802 (ground flower patches, +7 lines) without refreshing the checkpoint binding. Not this diff: no bound
  input is touched here. Note the binding hashes most JSON inputs as CRLF bytes (a Windows checkout); an LF checkout
  reports seven more "changed" inputs that are not.

## Code review (2026-11-23): GO WITH CHANGES, applied

| Finding | Fix |
|---|---|
| Clump faces wound inward (only tufts faced out), possibly Fable's grey film | `recalc_face_normals` before shading, as `Builder.build` |
| Tuft roots from the analytic rim picked clumps that do not reach the underside: tufts in clear air | tufts rooted on the built mesh: the leaf vertex furthest out at that angle in the rim (or shoulder) band, `TUFT_IN` .3 back into the leaves; the band widens until leaves face that way |
| `IsLoaded` can lag a Success, so a good clip could fall back to the stand-in | `Ambient.LoadGrace` 4 s of polling before falling back; spec covers a lagging load |

## Fable round 6 (Now), applied; round 7: pool GO, crowns GO

Glint Transparency .55 to .72 (pool and stream); the rim strip was the pebble bed peeking above the waterline:
`Surfaces.pebble_bed` Tint (.98, 1, .83) so it renders as the pool's teal; clump poles tilted 20-40 degrees, jitter 13
percent; leaf roughness flat 1.0 (125570475932961). Kit r12 Model 119297492044861 (Approved) through the gate. Captures
`r6/` (pool-edge with the Bear in the pool, lime-tree, under-round). Studio: AeroWorld 27, AeroFalls 22, AeroKit 7.

## Not verified

Spencer's ears on the fountain loop (Audio 96991688758765 was "Reviewing" at upload; until it clears outside Studio
the voice falls back to the stand-in); a phone frame and draw counts (+2 beams near Tumble, +1 at level 1); the foot
shade seen from the side; garden hour on the new crowns (no vertex shading under a SurfaceAppearance). Fable's Later
list (LOOK-R3 round 6) stays open: curved glint redraw, base net lift, fountain basin water colour, Hatch/bush UVs.
