# World look, round 2 (Fable, 2026-11-23)

Answers Spencer's beta (12) QA. Nothing is built or seen; numbers are first settings. Standing rule: the world goes
matte, textured and natural so the smooth bright pets stand out. Aero only. No web study was run.

## 1. Crowns

**Matte lime.** The gloss is the white SmoothPlastic part, not the map. Move the lime map into a SurfaceAppearance on
`Crown_Blossom`: ColorMap = the lime map, RoughnessMap = flat grey 235 (0.92), no metalness, no normal map. Dark
crowns get the same roughness; they shine too. Check the vertex gradient still multiplies. If not, keep TextureID
and set Material to Fabric. Top #8FCB3A, underside #5FAE2A.

**Leafier read, same triangles.** Leaves come from the map and the outline.
- Map: one drawn 256 px leaf-cluster tile per colour. Overlapping leaf shapes 18 to 30 px long, three values (light
  20 percent, mid 55, dark gaps 25). Tile every 4 studs. Roughness: leaves 0.88, gaps 1.0.
- Shape: rebuild Round, Tall, Blossom at today's counts (240, 220, 240). Five to seven uneven clumps, not one ball.
  Tufts pulled out 0.5 to 0.8 studs along the lower rim for a ragged edge. Flat underside.

**Clipping.**
- Near fade, client: every 0.15 s, for each of the 21 crowns, if the camera is inside radius + 1.5 studs, tween
  LocalTransparencyModifier to 0.8 over 0.25 s. Back over 0.4 s. If only the player's root is inside, 0.5.
- Height: any tree within 6 studs of a path or route gets its crown underside at 9 studs or more above the lawn.
  If the trunk cannot stretch, rely on the fade.

## 2. Waterfall rework

**Target.** White water tumbling down dark wet rock, not a blue curtain. Real falls are clear only at the lip, turn
white as they speed up, split into uneven strands with rock between, and end in a boiling apron and soft mist.
From the pool edge: dark rock, white moving water, pale spray, deep teal pool.

**Drop.** The cobalt striped sheet (hide the server sheet under Aero). Both lip bars. The cloud-puff foam. The ripple
rings. The rainbow. Strand A, Strand B and the ribbon maps. Confirm the white line goes too.

**Stack.**

| Layer | What | Numbers |
|---|---|---|
| Rock face | Opaque, in the Falls mesh, replaces Sheets (336 tris) | 3 ledges per drop, 0.6 to 1.2 studs proud. #2F3B40 to #3F4E55. Wet: roughness 0.35 |
| Chutes | Static white water shape on the rock, same mesh | 5 per drop, 1.2 to 3.5 wide, gaps 0.4 to 1.0. Bow 1.5. Top 6 percent #7FE0FF, white #F4FCFF by 15 percent, edges #DDF6FF |
| Flow A | Beam, new map `fall-white` 256x512: clumped streaks, uneven widths, 70 percent cover | Sheet width. Out 0.2. TextureLength 18, 14 studs/s. #F4FCFF. Transparency 0.6 top, 0.1 from 12 percent, 0.3 foot |
| Flow B | Beam, new map `fall-veil`: thin strands and bead trails, 25 percent cover | Width + 1.2. Out 0.4. Shift 0.7. Length 11, 19 studs/s. White, 0.35. LightEmission 0.15 |
| Apron | Beam lying flat on the pool, flowing out from the foot, map `foam-streak` | 9 wide, 7 long, 1.5 studs/s. Transparency 0.25 to 1 |
| Boil | Emitter, new map `spray-soft` (one soft uneven blob, no outline) | Pool: rate 14, life 0.6 to 0.9, size 1.6 to 3.2, speed 3 to 6, spread 50, 0.35 to 1. Ledge: half |
| Droplets | Emitter, 8 px speck | Rate 10, size 0.15 to 0.3, speed 8 to 12, spread 60, gravity 30, life 0.5 |
| Mist | Pool only, quieter | Rate 3, size 4 to 8, transparency 0.88 at best. Off within 16 studs |

Total 9 draws against today's 14. Level 1: Flow A, apron, pool boil (4). Reduced Motion: beams still, emitters
off. Sky Falls: Flow A and one mist.

**Pool.** Too electric. Target #3BA3BE, caustics at 40 percent contrast, darker (#2A7F99) within 4 studs of the foot.

**Sound.** `waterfall_loop` unchanged.

## 3. Fountain (replaces the Bubble Spring look at 52, 3)

**Form.** Two-tier garden fountain. Basin 6.4 studs across, rim 0.45 high and 0.5 thick so pets still step in. Stem
0.9 thick. Upper bowl 2.6 across at 2.4 high. Finial 0.5. Total 4.2 high. 320 triangles at most. The wet box stays.

**Materials.** Weathered stone: the plaza marble map, roughness 0.75, vertex tint #B9BEC2 down to #8E979A at the
base, moss #6E8B5A in a 0.3 band at the waterline. Water discs in both bowls, #3BA3BE, same mesh.

**Water, 3 emitters.**
- Jet: up from the finial. Rate 18, speed 9, gravity 30, spread 6, life 0.6, streaks 0.25 to 0.4, along velocity.
- Spill: ring at the upper bowl rim, falling 1.9 studs. Rate 24, life 0.45, same streak.
- Splash: ring in the basin, `spray-soft`, rate 8, size 0.5 to 1.0.
No bubbles. About +2 draws over the spring; architect to confirm.

**Sound.** We own no fountain loop. Flag: needs an original synth `fountain_loop`. Until then, `water_bed_loop` as a positional voice at pitch 1.25. Volume 0.16, InverseTapered, min 5, max 26.

## 4. Order and captures

1. Matte lime and roughness. Capture `lime-tree` camera at day and garden hour.
2. Near fade. Capture the camera inside a crown, before and after.
3. Falls. First a flat mock of the new maps on rock colour, then the kit. Capture `pool-edge` with a
   pet in the pool, `falls-wide`, `falls-oblique`, a 5 s clip, one phone frame, level 1.
4. Fountain. Capture at 40, 15 and 5 studs with a pet beside it, and at night.
5. Crown reshape and leaf tiles. Capture `hub` and `lime-tree`.

## Round 3 (build review, kit r6, 2026-11-23)

Judged from `r2/pool-edge`, `r2/falls-wide`, `r2/fountain-15`, `r2/fountain-5`. Stills only. Motion and sound not judged.

**Verdict: GO WITH CHANGES. The falls are NO-GO as captured; lime crowns and fountain pass once the Now rows land.**

### What I see

- **Falls: zebra.** The blue curtain is gone, good. But the chutes read as five flat grey-blue ribbons with even navy
  bars between them, full height, on both drops. That is my brief's fault as much as the build's: five even chutes
  with full-length gaps make stripes. Spencer will call this awful again.
- **Flow beams barely show.** I see one thin strand near the centre, about 1 stud wide. The moving white layer that
  should blur the gaps is missing or far too clear. Check Flow A's width before tuning anything else.
- **Rock in the gaps renders navy**, not slate. Ledges do not read at all.
- **Foot:** the old faceted white foam chunks are still there. Boil reads as a few small round dots.
- **Pool:** still electric cobalt. The #3BA3BE skin at 0.5 does not register.
- **Fountain:** right idea, reads as a fountain. Too small beside the lamp. The stem and bowl are dark slate on a pale
  basin, so it looks like two objects. The jet is large round white blobs: it reads as steam or bubbles. No spill
  visible. Basin is an obvious octagon. Water is the same cobalt.
- **Lime crown:** matte now. Pass on gloss. Still neon against the pets.

### Now

| Piece | Property | From | To |
|---|---|---|---|
| Chutes | count per drop | 5 | 3, widths 2.4 / 4.2 / 3.0 of a 10.5 sheet (scale to the upper) |
| Chutes | gaps | 0.4 to 1.0, full height | 0.25 to 0.5 wide, each only 30 to 55 percent of the drop, staggered, closed at the top 20 percent and at the foot 10 percent |
| Chutes | colour, shading | #F4FCFF, flat | #FFFFFF centre, #EAF6FF edges, smooth-shaded |
| Chutes | at each ledge | flat | kink out 0.8 studs, so ledges cast a break |
| Rock face | colour | renders navy | #55666B top to #44545A foot, no blue |
| Flow A | width | (renders ~1) | sheet + 0.6, confirm both ends |
| Flow A | transparency | 0.6 / 0.1 / 0.3 | 0.35 / 0 / 0.2, LightEmission 0.2 |
| Flow B | transparency, width | 0.35, + 1.2 | 0.2, + 1.6 |
| Foot foam chunks | old mesh | shown | hidden under Aero |
| BoilPool | rate, size | 14, 1.6 to 3.2 | 22, 2.2 to 4.0, confirm `spray-soft` is the map |
| Pool skin | transparency | 0.5 | 0.15 (or tint the pool part #3BA3BE) |
| Fountain | bowl height, bowl width, total | 2.4, 2.6, 4.2 | 3.2, 3.2, 5.2 |
| Fountain | basin segments | 8 | 16 |
| Fountain | stem and bowl tint | dark slate | #B9BEC2, base #9AA3A6, same marble as the basin |
| Fountain | water | cobalt | #3BA3BE |
| Jet | size, rate, speed | reads ~0.8 round | 0.12 to 0.2 streak, 40, 11, transparency 0.2 |
| Spill | rate | 24 | 40, in 8 streams round the rim |
| Lime crown | top, underside | neon | #86BE3C, #55992B |

### Re-capture

Same four cameras, plus a 5 s clip of the falls and the fountain, and `pool-edge` with a pet in the pool.

## Round 4 (kit r8, 2026-11-23)

Judged from the four `r3/` stills. Motion and sound still not judged.

**Verdict: GO WITH CHANGES for the private beta. Fountain and lime crown: GO. Falls: two blocking fixes.**

- **Falls, wide:** the zebra is gone. It now reads as white water on rock. Real progress.
- **Falls, pool edge (Spencer's angle): fails.** The camera-facing beams sit a full chute to the right of the sheet.
  The left half is a blank pale slab with two slits, and the chute edge shows as a sawtooth. This is the view he
  judged, so it blocks.
- **Bands:** `falls-wide` shows four or five even horizontal bands down each drop. The flow map's tile seam is
  visible and both beams repeat in step.
- **Fountain:** reads as a real stone fountain. Jet is right. Pass.
- **Lime crown:** matte, calmer. Pass without the gradient.

### Blocking

| Piece | Property | From | To |
|---|---|---|---|
| Chutes | bow | 1.5 | 0.5 |
| Chutes | ledge kink | 0.6 | 0.3 |
| Flow A, Flow B | shape | curved, FaceCamera | straight (CurveSize 0), flat on the sheet plane, FaceCamera off |
| Flow A, Flow B | out | 0.2, 0.4 | 0.6, 0.8 (in front of the bow at mid drop) |
| Flow A | TextureLength | 18 | 26, and make `fall-white` tile with no bright row at the seam |
| Flow B | TextureLength | 11 | 17 |

Check only: basin wall looks about 1.2 high. If pets must enter the wet box, 0.6 at most.

### Not blocking, later

The pool's own cobalt texture needs a new Aero pool map. Fountain water sits low and dark: raise to 0.15 under the rim.

### Re-capture

`pool-edge` and `falls-wide`, plus a 5 s clip. I will not pass the falls without `pool-edge`.

## Round 5 (kit r9, 2026-11-23)

Judged from `r4/pool-edge` and `r4/falls-wide`. Motion and sound not judged.

**Verdict: GO for the private beta.**

- **Pool edge:** the flow now covers the sheet. It reads as falling white water with strands and a glassy lip. The
  slab and the sawtooth are gone. This is the first version I would show Spencer.
- **Wide:** no bands. Clean white cascade on dark rock, both drops.
- The SecondaryAxis finding explains every thin white line since step 1. Good catch.

### Not blocking, next pass

| Piece | Property | From | To |
|---|---|---|---|
| BoilPool | rate, size | 22, 2.2 to 4.0 | 30, 2.5 to 4.5 (the foot still meets the pool too cleanly) |
| Chute slits | width | 0.25 to 0.5 | 0.15 to 0.3 (they read a little drawn) |
| Flow B | width | + 1.6 | + 0.8 (a stray strand hangs off the right edge at the pool) |
| Pool | map | cobalt | new Aero pool map, #3BA3BE. Now the loudest thing in the frame |

Still owed: a 5 s clip, a pet in the pool, one phone frame, and Spencer's ears on the fountain voice.
