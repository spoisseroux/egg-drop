# Waterfall look, step 1: client layers (Fable, 2026-11-22)

World pass item 4, runtime only. Nothing here is built or seen in Studio; numbers are a first setting to capture and tune.

**Where it lives.** In the `EggDropAero` additions folder (`AeroAdditions`), client-built, behind the Aero switch. The server's
`WaterFlow` beams and emitters stay as they are (live uses them): they are the back sheet. Values go in `WorldAero`.

**Frame.** For each fall: n = its `normal`, t = n turned 90 degrees flat (Tumble: n (-.707, 0, .707), t (.707, 0, .707)),
"sheet" = that fall's width0 to width1. Tumble impact point I = (72.7, 3.2, -72.7). Pool top Y: measure it, falls end at 3.2.

**Maps** (`python scripts/draw_world_textures.py`, add `--preview DIR` for a stacked mock-up and small sizes). All white on clear:
`water-strand.png` 512 (strands, sides fade out), `water-ribbon.png` 512 (puffed froth down both sides, two broken ribbons),
`foam.png` 256, `ripple.png` 512, `rainbow-band.png` 256x32. Strand, ribbon and rainbow run along image Y: check which way a
Beam lays them and, if the streaks come out sideways, rotate the three PNGs in the script, not in Studio.

## Layers

**1. Falling strands.** Two beams per Tumble tier on the server sheet's own top and bottom points, pushed out along n. Not
billboarded, `TextureMode` Wrap, `Segments` 6, `LightInfluence` 1, map `water-strand`.

| Beam | Width | Out | Shift along t | TextureLength | TextureSpeed | Colour | Transparency |
|---|---|---|---|---|---|---|---|
| Strand A | sheet + 1.0 | .15 | 0 | 20 | .55 (11 studs/s) | #3CC8F0 | .6 at the top, .35 from 8% to 85%, .8 at the foot |
| Strand B | sheet x .7 | .30 | +.6 | 13 | 1.1 (14 studs/s) | #DDF6FF | .7, .45, .85 at the same points |

A is wider than the sheet on purpose: its faded sides hide the ruler-straight edge. B is offset so the two never line up.

**2. White ribbons, edges and lips.** One beam per tier, map `water-ribbon`: width sheet + 1.6, out .45, TextureLength 16,
TextureSpeed 1.0 (16 studs/s), #FFFFFF, transparency .2 (.5 in the top 5%, .7 at the foot), `LightEmission` .25. The froth
columns sit just outside the sheet's sides. Lips: two white cylinders along t, SmoothPlastic, #FFFFFF, reflectance .2:
top lip at the Upper top, 8.8 long, .9 thick; ledge roll at the Lower top, 11.8 long, 1.1 thick; each .3 out along n.

**3. Impact foam.** Two emitters on clear boxes turned to face n, map `foam`, flat to the camera.

| | Pool | Ledge |
|---|---|---|
| Box (along t, up, along n) | 12 x .6 x 2.5, centre I + n x 1.0, pool top + .3 | 10.5 x .5 x 2, at the Lower top + n x .6 |
| Rate, life | 16 a second, .7 to 1.1 s | 8 a second, .7 to 1.1 s |
| Size over life | 1.0, 1.9 at 30%, 1.3 | .8, 1.5, 1.0 |

Both: speed 2 to 4 upward, spread 35, acceleration (0, -9, 0), drag 1, rotation 0 to 360 turning up to 30 a second,
transparency .15, .35 at 60%, 1; #FFFFFF to #F4FCFF; `LightEmission` .2. No separate glints: the foam is the sparkle.

**4. Ripple rings.** One emitter, no per-frame code: map `ripple`, `Orientation` VelocityPerpendicular, emitting straight up at
speed .05 so the rings lie flat. Point: I + n x 2.5, pool top + .08. Rate 1.25 (a ring every .8 s), life 2.4 s, so 3 rings
alive. Size 4 growing to 9 studs. Transparency .3, .6 at 70%, 1. #FFFFFF, no rotation. The rim's foam skin waits for the export.

**5. Mist.** Roblox's own `smoke_main.dds` (as the dew glints use `sparkles_main.dds`), #E9F8FF, `ZOffset` -2 so it sorts
behind anything in front of it. Pool: box 10 x 1 x 3 at I + n x 1.5, pool top + 2; rate 3, life 2.5 to 3.5 s, size 3 to 6.5,
speed 1 to 1.6 up, transparency 1, .8 at 25%, 1. Ledge: box 8 x 1 x 2 above the ledge roll, rate 2, size 2.5 to 5, same rest.
Mist never leaves a box 14 along t by 6 along n by 9 high from I. Off whenever the camera is within 16 studs of I (checked on
the additions' existing timer, not each frame), so it never fills a phone screen.

**6. Rainbow.** One beam, map `rainbow-band`, `TextureMode` Stretch, speed 0, `FaceCamera` on (it is a ribbon in the air),
`Segments` 16, width 1.6. Feet at (66.3, 4.2, -76.2) and (76.2, 4.2, -66.3): 7 studs either side of I, 2 out, 1 up. Both
attachments' axis up, `CurveSize0` 8, `CurveSize1` -8: an arc 14 wide, 6 high. Colour white (the map carries the pastels),
transparency 1 at the feet, .84 at 20% and 80%, .8 at the top; `LightEmission` .3, `LightInfluence` 0. Day only: on when
the look's clock is between 9 and 15.5 (Aero pins 10.5 today, so on), else transparency 1. Only ever at the pool mist.

**7. Rocks: export only, later.** Three wet boulders splitting the lower fall, two flanking, two in the pool, #7E8C98, about
400 triangles, plus wavy tapered sheet sides, lip meshes and a broken pool rim. Collision means the walk grid is rebuilt.

**Sky Falls** (south edge, top (-5.4, 3.25, 61.1) to (-5.6, -68, 64), width 7.3 to 12): Strand A and the ribbon only, same
settings, TextureLength 28 and 22; one mist emitter 3 studs under the lip, pool settings. No foam, rings, lips or rainbow.

## Budget

| Layer | Draws | Alive at most | Level 1 | Level 2 | Reduced Motion |
|---|---|---|---|---|---|
| 1 Strands | 4 beams (+1 Sky) | - | Strand B dropped: 2 (+1) | gone | TextureSpeed 0 |
| 2 Ribbons, lips | 2 beams (+1 Sky), 2 parts | - | kept | gone | TextureSpeed 0 |
| 3 Foam | 2 | 18 + 9 | rates 8 and 4 | gone | off and cleared |
| 4 Rings | 1 | 3 | rate .6 | gone | off and cleared |
| 5 Mist | 2 (+1 Sky) | 11 + 7 (+11) | pool only at rate 1.5, Sky off | gone | off and cleared |
| 6 Rainbow | 1 | - | dropped | gone | kept, it does not move |

Totals at Tumble: level 0 is 14 draws and 48 particles; level 1 is 9 draws and about 20. Sky Falls adds 3 draws and 11
particles and is never on screen with Tumble. This is more than the scope's "+8 draws": the additions comment in `WorldAero`
(8 at worst) needs the new count, and the architect should OK it. Level 2 is today's rule: all additions gone for the session.
Touch devices start on the level 1 set until pool-edge overdraw is measured on a phone (3 see-through layers, 4 with B).

## Rules

- Never over the pet or prompts: every emitter box and the rainbow stay within 6 studs of the sheet along n. Check the walk
  grid: if a walkable tile is within 3 studs of any emitter box, shrink that box. Mist sorts behind (`ZOffset` -2).
- Reduced Motion and levels: `AeroAdditions.build` returns `still(reduced)` and only knows emitters. It must also stop the new
  beams (store each speed, set 0) and take the budget level. `WorldMotion` does not see this folder; do not rely on it.
- Aero palette only: #3CC8F0, #7FE0FF, #DDF6FF (`Aero.Falls`), #F4FCFF, #E9F8FF (`Aero.Spray`), white. Sound: scope row 11 stands.
- Captures I review: the `waterfall.jpg` camera, pool edge at pet height, hub, phone at the pool edge, Reduced Motion, level 1.

## Uploaded (Opus, 2026-11-23)

- water-strand.png -> rbxassetid://136221967090040
- water-ribbon.png -> rbxassetid://101983518173947
- foam.png -> rbxassetid://134089185354561
- ripple.png -> rbxassetid://123065684226119
- rainbow-band.png -> rbxassetid://129354894959810

Budget decision (Opus): 14 draws at Tumble is accepted only while the camera is within 120 studs of the falls; budget level 1 drops to 8 or fewer (no rainbow, one strand a tier, no ledge foam); level 2 and Reduced Motion: today's falls only.
