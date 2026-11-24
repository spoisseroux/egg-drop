# World round 5: falls far read, lime crown outline, chime saturation (Opus, 2026-11-24)

Source: Fable's `artifacts/qa-2026-11-23-beta14/FABLE-REVIEW-R5.md` items 1, 2, 9 (captures `studio/r5/14`, `15`, `10-12`,
`09`). Branch `claude/world-r5` from feat d90d3f8. Aero/beta only; live and the island export unchanged. No publish.

## 1. Falls (W1)

- Atlas v3 (`draw_aero_r4_textures.py`): the streak region now spans one sheet's width (u = 0..1 across each drop, so
  band positions are designed): 3-4 broad soft darker bands, each 15-25% of the width, #6FA3C8; body capped at
  #BFD9EA (white only for foam); render-compensated as before (measured again in Studio).
- Sheet geometry (`build_world_aero_kit.py add_sheet`): side edges break into 3-5 uneven lobes (edge x varies by up to
  ~0.5 stud along the drop); the outer 0.6 stud of each side fades in vertex colour to wet stone (a feather without
  alpha: the falls mesh stays opaque, so nothing in it sorts as transparent).
- Rock face narrowed to sit behind the sheet (the two dark frame slabs go).
- The step: the lower drop's white lip line and the ledge foam roll go; a dark rock lip strip across the step instead.
- Foot foam: lumps at most 0.8 tall, uneven widths; the foam part Transparency .25, emissive lift .3.
- Mist: a new kit part `Falls__kitmist`: 3 soft cards ~6 wide at the foot and 1 at the step, a drawn soft blob in a
  SurfaceAppearance ColorMap with AlphaMode Transparency, part Transparency .6, matte, no shadow.

## 2. Lime crowns (W2)

- Blossom crown: the 6 rim tufts go; 14 leaf-cluster cards (jagged 12-sided discs, 2-3 studs) round the outline, facing
  out, half embedded, textured with the same leaf tile: the edge reads as leaves, not facets. +~144 triangles per lime
  crown (8 placed: ~+1,150): the triangle checks move from "equal to the merged crowns" to "merged plus the cards,
  recorded per mesh".
- Lime UVs 1.5x denser (leaf ~0.5 stud). Lime tile saturation -15%, value -10% (`leaf-lime`), so it sits with the dark
  crowns at dusk (there is no separate dusk grade on crowns: lighting only).

## 3. Chimes

- `palette-chimes.png`: the Aero palette with saturation x .75; `WorldAero` gains named surfaces (by part-name prefix,
  checked before the kind's surface): `W7_Chime_` takes it. Restore through AeroWorld's records as every surface.

## Order

Offline first (textures, kit build, gate code, specs). Then ask the coordinator for Studio: uploads (images, kit r18
Model), readback, Rojo, Play captures from the plaza, the lawn and the arrival dais, Fable on captures.
