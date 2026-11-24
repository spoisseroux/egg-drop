# LOOK-R4: falls that read without motion, denser leaves, quiet water (Fable, 2026-11-23)

Source: Spencer's beta (14) phone test. Judged from `r7/falls-70-static-only`, `falls-70-layers`, `falls-105-lawn`,
`falls-45-static-only`, `r5/leaf-lime-3x3`, `r6/lime-tree`. Colours are sRGB. Audio numbers are beta-only (Aero ceiling).

## W1 Waterfall: the static mesh carries the read

**What is wrong (static-only, 70 studs).** Three things, in order: (1) the chute is one flat pale value, about
(190,206,226), so it reads as a painted board; (2) the four slits are the only detail and they are near-black, so
they read as cracks; (3) the navy side frames, about (30,58,100), outline it like a UI panel. With layers on
(`falls-105-lawn`) it reads as water, so the target is: static-only looks like that frame at about 60 percent contrast.

**Ruling on the atlas: GO**, with these changes to the proposal.
- Hue lives in the texture, not the vertex colours (multiply can only darken). Chute vertices go near-white.
- Rock faces get no wet-rock texture (invisible at 70). They map to a white block and keep vertex colour.
- Foam is geometry in the same mesh plus vertex colour, not just a colour band: it must change the silhouette.
- Slits: closed. Gap 0. The streaks do that job now.

**Atlas, 512 x 512, drawn.**

| Region | Pixels | Covers | Wrap |
|---|---|---|---|
| Streaks | x 0-511, y 0-383 | 16 studs wide, 24 studs tall | U wraps; top and bottom rows match so a taller drop can be cut and restarted |
| Gutter | y 384-399 | white | none |
| White block | y 400-511 | rock faces, foam, apron (UVs inside y 416-496) | none |

**Streak region.** Vertical only, soft edges (3 px feather), ends taper over 2 to 3 studs, sideways wobble up to 0.15 stud.

| Layer | Width (studs) | Per 16 studs | Length (studs) | Colour | Share of area |
|---|---|---|---|---|---|
| Base (between streaks) | n/a | n/a | n/a | (168,205,224) | 32% |
| Deep accents | 0.3-0.5 | 4 | 5-10 | (132,180,206) | 8% |
| Mid streaks | 0.4-0.8 | 9 | 8-20 | (222,238,245) | 25% |
| Wide white streaks | 0.9-1.6 | 5 | 10-24 | (246,251,253) | 35% |
| Hairlines (close-up only) | 0.12-0.25 | 20 | 3-8 | (236,246,250) | over the above |

Rules: nothing in the streak region darker than (132,180,206); that floor is what stops "cracks". No two deep
accents closer than 2 studs. Wide streaks uneven: never three at equal spacing. At 105 studs a stud is about 6 px
on a phone, so only the wide and mid layers survive; they are the design, the hairlines are a bonus.

**Mesh and vertex colours.**

| Piece | Change |
|---|---|
| Chutes | Three chutes per drop become one sheet, gaps 0. Keep bow .5 and ledge kink .3. Optional 0.25-stud depth stagger between the three; any step face uses the streak UVs, never a dark face |
| Chute vertex colour | Top of each drop (226,238,246), blending to (255,255,255) over the lower 60%: glassy at the lip, whiter as it falls |
| Lip line | 0.5 stud tall strip at the top edge of each drop, white block UV, (250,253,254) |
| Ledge foam (between drops) | Raised roll, 1.6 studs tall, 0.6 proud of the sheet, 5 lobes, (250,252,253) |
| Foot foam | Raised roll, full chute width plus 0.6 each side, 6 or 7 lobes 1.0-1.8 wide, heights 1.4-2.6 (uneven), 0.8 proud, (250,252,253) with the bottom row (226,241,246) |
| Foot apron | Flat scalloped fan on the pool, 3.5 studs out, 0.08 above the water plane, (226,241,246) at the foot to (190,222,232) at the rim |
| Side rock frames | Navy out. (72,84,86) at the top to (58,72,76) at the foot: wet stone, darker than the boulders, no blue |
| Material | Plastic stays. No Reflectance. Beams and emitters unchanged |

Budget: under 400 added triangles. If the apron z-fights or shows through under Aero water, drop it and tell me.

**Pass checks (recapture the same four views, static-only and layers).**
1. `falls-70-static-only` shrunk to 480 px wide still says waterfall: white vertical strokes and a white foot.
2. No dark vertical line inside the water at 70 or 45 studs.
3. Mean chute colour, static-only, within 12 per channel of the layers-on frame at 70.
4. From 105 the foot foam is visible as a white bar above the pool rim stones.

## W2 Leaves: denser and textured

**What is wrong.** In `lime-tree` the lime crown is camouflage: big light blobs and big dark holes, three values.
Gap colour shows over roughly a fifth of the tile and the holes are up to a stud across. Leaves are 0.34 to 0.53
stud long, large for a 9-stud crown. "Denser" means: smaller leaves, far less gap, more value steps, detail on each leaf.

| Property | Today | New (lime and dark share one layout) |
|---|---|---|
| Tile | 256 px for 4 studs | 512 px for 4 studs (128 px a stud) |
| Leaf length | 22-34 px (0.34-0.53 stud) | 26-40 px (0.20-0.31 stud), width 45-55% of length |
| Leaf count | n/a | 1100-1300, in 4 depth layers, drawn back to front |
| Gap colour visible | about 20% | 8% or less; no gap blob wider than 0.25 stud |
| Value steps | 3 | 5 (table below), deeper layers darker |
| Leaf detail | flat fill | Midrib 2 px, 12% darker; one half of each leaf 8% darker; 1 px darker rim on the lower edge |
| Grouping | scattered | Sprigs of 5 to 7 leaves fanning from one point; sprigs point within 50 degrees of straight down |
| Large-scale variation | blobs | Soft value drift only, plus or minus 6%, period about 2 studs. No hard patches |

| Step | Share | Lime | Dark |
|---|---|---|---|
| Gap | 8% | (40,104,34) | (22,70,40) |
| Layer 1 (deepest) | 22% | (72,138,40) | (34,96,50) |
| Layer 2 | 34% | (108,172,48) | (44,118,58) |
| Layer 3 | 30% | (140,200,58) | (58,138,66) |
| Tips, top layer only | 6% | (176,222,84) | (84,160,80) |

Tile mean should land near (106,168,48) lime and (44,116,57) dark: lime stays clearly lighter and yellower than
dark, a little less neon than today. `leaf-rough` stays 1.0. Crown meshes, UVs and tuft cards unchanged (tufts
take the same new tile).

Second step, only after the colour tile is approved in a capture: one 512 normal map from the same layout (leaf
height: top layer 1.0, each layer down 0.25 less, gap 0), strength as if leaves stand 0.06 stud proud. One map
serves both crowns. Skip it if the phone budget says no.

Pass checks: `lime-tree` and `under-round` recaptured. No single flat patch wider than 0.4 stud on the lime crown.
From 60 studs the crown is one soft green with fine grain. No visible 4-stud repeat on the largest flat face.

## Q4 and B4 Audio: water only where water is

**Cause.** The bed is the "constant" sound: it never drops below .12 anywhere. It goes to silence away from the stream.

| Voice | Property | Today | New |
|---|---|---|---|
| Brook bed (`water_bed_loop`) | Type | 2D, distance-driven | Same (stays 2D, no positional rewrite) |
| Brook bed | Floor | .12 | 0 (silent; pause the voice after 2 s at 0) |
| Brook bed | Peak | .24 | .10 |
| Brook bed | Full within / silent beyond | 45 studs, never silent | Full within 6 studs of the stream or pool edge, smoothstep to 0 at 28 |
| Brook bed | Volume slew | n/a | 0.6 s, so it does not pump along the bank |
| Tumble falls | Volume / min / max / speed | .22 / 6 / 44 / .92 | .18 / 6 / 38 / .92 |
| Sky Falls | Volume / min / max / speed | .15 / 4 / 30 / 1.08 | .10 / 4 / 26 / 1.08 |
| Fountain (`fountain_loop`) | Volume / min / max / speed | .14 / 5 / 26 / 1 | .20 / 7 / 30 / 1 |

All stay InverseTapered, in the ambience group, with the same ducks and the On / Soft / Off setting. Live keeps today's mix.

Why the fountain goes up: at 15 studs a min of 7 leaves about 40 percent of .20 after the taper, close to what the
old bed floor was, and that was plainly audible. With the bed silent on the lawn nothing masks it.

**Listening checks for Spencer (phone speaker, Ambience On).**
1. Middle of the lawn, 40+ studs from any water: no water sound at all.
2. 15 studs from the fountain: fountain clearly there. 30 studs: gone.
3. On the stream bank: a soft brook, quieter than the music. Walk 30 studs away: gone, with no audible step.
4. At the foot of the falls: the falls dominate. From the lawn at 70 studs: silent.

If check 2 is still weak: fountain volume .26, min 8. If check 3 is still annoying: bed peak .07. Change nothing else.

## Order of work

1. Audio table (config only). 2. Falls atlas and mesh, recapture four views. 3. Leaf tiles, recapture two views.
4. Leaf normal map, only on my GO after step 3.

## Round 2 (build review, kit r14, 2026-11-23)

Judged from `r8/` against `r7/`. Rendered colours below are my own samples of the r8 JPEGs (mean over the region).

| Piece | Verdict for the private beta |
|---|---|
| Falls, static-only | **GO WITH CHANGES** (two fixes below, one build pass). The sheet itself is right: streaks read as falling water at 45, 70 and 105, the slits are gone, the board is gone |
| Falls, layers on | **GO**. Whiter and livelier than r7, no fight between sheet and beams |
| Leaves (lime and dark) | **GO**. 2,641 leaves accepted: the gap share was the real target, the count was my guess |

**W1 pass checks**
1. 480 px read at 70: **pass** for the strokes, **fail** for the white foot (see 4).
2. No dark vertical line inside the water at 70 or 45: **pass**.
3. Static mean within 12 of layers-on at 70: **pass** (6, 2, 6). Sky-leaning normals and compensated atlas values accepted.
4. Foot foam a white bar from 105: **fail**. It renders as a grey band, darker than the water above it: foam (123,155,180) against sheet (146,193,226) at 45; same at 70 (123,157,185). Ledge roll (124,174,209) and lip (133,190,231) are also no lighter than the sheet.

**W2 pass checks**
- No flat patch wider than 0.4 stud on the lime crown: **pass**.
- One soft green with fine grain from 60 studs: **pass** (a little crisp on the dark crowns at 105, acceptable).
- No visible 4-stud repeat on the largest flat face: **pass** in `lime-tree` and `under-round`. The repeat shows only in the flat 3x3 sheet.
- Means (101,160,47) and (44,111,55) against targets (106,168,48) and (44,116,57): **pass**.

**Now (blocks W1 sign-off only; leaves, layers and audio can ship)**

| Item | Rendered today | Target (rendered, static-only, 45 studs) |
|---|---|---|
| Foam: foot roll, ledge roll, lip strip | Darker than the sheet, grey | Each at least 25 lighter than the sheet beside it in R and G, never darker in any channel. Same cure as the sheet: lean the normals to the sky, compensate the colour. If the roll still shades grey, flatten its underside rather than add colour |
| Side rock frames | (35,60,75): still a dark blue outline, half the value I asked for | R 60-80, G 72-88, B 76-92, and B no more than 12 above R. Wet stone, not navy |

Recapture `falls-45-static-only`, `falls-70-static-only`, `falls-105-static-only`. No other view needed.

**Later**
- Faint horizontal seam across the upper drop at 45 (tile restart): offset the restart or hide it under the lip strip.
- Foot apron does not read in any capture. After the foam fix, keep it only if it shows at 45; otherwise drop it.
- Deep accents at 3% instead of 8%: keep as built. Under, not on top, is the right call.
- Leaf tile: the brightest tip clusters repeat as a grid in the flat sheet. Thin the tips to 4% or break their spacing next time the tile is redrawn.
- Leaf normal map (step 4): GO to try, behind the phone budget; one capture of `lime-tree` before and after.
- Audio: numbers hold in Studio, nobody has listened. Spencer's four listening checks above stay open.

## Round 3 (fix check, kit r17, 2026-11-23)

Judged by eye from `r9/` against `r8/`; colour figures are Opus's samples at 45 studs, not re-sampled by me.

**Falls, static-only: GO** for the private beta. Falls with layers: still GO. No blocking items.

1. 480 px read at 70, strokes and a white foot: **pass**. The lobed foot roll is now the brightest thing in the frame.
2. No dark vertical line inside the water at 70 or 45: **pass**.
3. Static mean within 12 of layers-on at 70: **pass**, but `r9/falls-70-layers` is near-identical to the static frame, so confirm the beams were on in that capture.
4. Foot foam a white bar from 105: **pass**. Foam (228,255,255) against sheet (146,192,224): 82 and 63 lighter. Lip and ledge lines read white too.

Frames: (58,84,90) left, (71,87,96) right. Left R is 2 under and B is 32 above R (I asked 12), but on screen they read as dark wet stone, not a navy outline. Accepted.

**Later (not blocking)**
- Emissive foam at .45: look at it once at night. If it glows against a dark cliff, tie the strength to the day/night cycle (about .2 at night).
- Foam G and B clip at 255 at 45 studs; if it looks like paper close up, drop strength to .35 before touching colour.
- Apron still does not read at 45: drop it. The Round 2 seam note stands.
