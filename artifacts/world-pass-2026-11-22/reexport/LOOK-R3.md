# World look, round 3 leftovers (Fable, 2026-11-23)

Three pieces Spencer said go on: the Aero pool map, the crown reshape with leaf tiles, the fountain loop. Aero only.
Nothing here is built, seen or heard yet; every number is a first setting. All art and audio drawn or synthesised in
Python, fixed seeds. Rule as before: surroundings matte, textured, calm, so the pets are the brightest smooth thing.

## 1. Pool map

Today (`r4/pool-edge`): electric cobalt with hard pale polygon lines. Target: calm teal with a soft, broken light net.

**Base tile `pool-aero`** (replaces the pool part's TextureID under Aero).

| Property | Value |
|---|---|
| Size | 512 x 512 px for the 14 stud tile (36.6 px per stud). Seamless: build everything wrapped on the tile |
| Net | Wrapped Voronoi edges (F2 minus F1), 24 points on a jittered 5 x 5 grid: cells 2.2 to 3.6 studs across |
| Bend | Warp the lookup by wrapped low noise, 0.4 studs at 2 cycles per tile. No straight polygon edges |
| Line | Core 0.10 stud (4 px), soft falloff to nothing at 0.45 stud (16 px). Width varies 0.6x to 1.4x along a line |
| Broken | 30 percent of edges fade out along their length. It is a loose net, not a honeycomb |
| Base | #379DB9 |
| Line peak | #5DB7CD. Nothing in the tile lighter than #7CC8D8. No white |
| Cell centre | Soft dip to #3193AF |
| Second tone | Wrapped mottle, blobs about 3 studs, toward #3AA7B4, 2 percent value at most |
| Mean | #3BA3BE, within 3 per channel. Measure the file and print it |

Seam check: tile it 3 x 3 into one image and look. No row, column or repeated bright knot should catch the eye.

**FlowSkin stays, as a glint layer, not a colour wash.** At 0.15 it would hide the new map.

| Property | From | To |
|---|---|---|
| Image | water map | new `pool-glint`, 256 px, RGBA, seamless. Same net recipe, other seed, cells 1.8 studs, keep only the thinnest 35 percent of lines, core 2 px. About 10 percent of pixels lit |
| StudsPerTile | 14 | 9 (so it never sits in step with the base) |
| Color | #3BA3BE | #E4F7FA |
| Transparency | 0.15 | 0.55 |
| Flow | 0.18 / -0.12 | unchanged. Reduced Motion: still |

If the cobalt still reads after this, drop the part's Reflectance from 0.22 to 0.12 (the sky is adding blue).
The stream shares the old map. If it can take the same tile under Aero, do it: pool and stream should match in `hub`.

**Foot shade.** Your Beam plan is right.

| Property | Value |
|---|---|
| Image | `foot-shade`, 128 px, white with alpha. Half disc: full at the middle of the falls edge, smooth falloff to zero at 4 studs. Alpha is zero on the three outer edges |
| Beam | Flat on the water, 0.03 above it (Apron at 0.06). 12 wide along the foot, 5 out. Texture stretched once |
| Tint | #1F6F8A, Transparency 0.3 at the foot (blends to about #2A7F99), LightEmission 0 |
| Ledge pool | Same, 7 wide, 2.5 out. Drop it at level 1 |

Capture `r5/pool-edge` (with a pet in the pool), `falls-wide`, `hub`.

## 2. Crowns

**Shape.** Clump 0 is unchanged in every table, so the trunk top, pivot and sway do not move. Footprint and top stay
inside today's. Same triangle counts.

| Crown | Clumps (x, y, z, radius, squash) | Flat underside z | Tufts |
|---|---|---|---|
| Round, 7 | (0,0,8.5,3.6,.78) (2.5,.7,7.2,2.7,.74) (-2.3,-1,7.4,2.5,.74) (.4,2.3,9.4,2.1,.8) (-.6,-2.4,8.8,2,.78) (-1.3,.9,10.7,1.8,.82) (1.5,-1.2,10.3,1.4,.85) | 5.6 | 6 on the rim, at 20, 75, 140, 200, 255, 320 degrees |
| Tall, 6 | (0,0,8.8,3,.82) (.5,.3,10.9,2.5,.86) (-.4,-.4,12.8,2,.9) (.1,.1,14.6,1.3,1) (1.6,-.8,9.5,1.6,.78) (-1.5,.9,10.2,1.4,.78) | 6.4 | 4 on the rim, 3 on the tier shoulders (z 9.6, 11.6, 13.6) |
| Blossom, 7 | (0,0,7.4,3.4,.74) (2.4,-.5,6.6,2.6,.72) (-2.2,1,6.8,2.5,.72) (.4,2.1,8.3,1.9,.78) (-.5,-2.2,8,1.9,.78) (1.4,.9,9.1,1.5,.8) (-1.3,-.6,8.9,1.3,.82) | 4.9 | 6 on the rim, at 35, 95, 150, 215, 270, 330 degrees |

| Triangles | Round 240 | Tall 220 | Blossom 240 |
|---|---|---|---|
| Clump 0 | 48 | 44 | 48 |
| Next clumps | 4 x 32 | 40, 36 | 4 x 32 |
| Small clumps | 2 x 20 | 3 x 24 | 2 x 20 |
| Tufts, 4 each | 24 | 28 | 24 |

- Flat underside: clamp every vertex below the plane up to the plane. Do not cut and cap (caps cost triangles).
- Clumps: jitter each vertex 8 percent of its radius, fixed seed. Smooth normals pointing out from the clump centre
  (random face normals read as blocks in kit r3).
- Tuft: a 4-sided spike with no base. Root 0.9 wide on the rim of the outermost clump at that angle, tip 0.5 to 0.8
  out and 0.3 below the plane. Vary length per tuft. Shoulder tufts on Tall point out and 20 degrees down.
- Hatch crown: geometry unchanged.
- The kit's "same leaves within 0.01 stud" proof cannot hold for reshaped crowns. Prove pivot, yaw and scale instead.

**Leaf tiles.** One leaf layout, two palettes, one roughness map. 256 px, tiling every 4 studs (64 px per stud), box
mapped by face normal. Seamless: a leaf that crosses an edge is drawn again on the far side.

| Property | Value |
|---|---|
| Leaf | Pointed oval, 22 to 34 px long, 10 to 16 wide, lighter along one long edge. No vein, no outline |
| Count, order | About 120. Fill with gap colour, then dark-side leaves, then mid, then light on top |
| Direction | 60 percent hang within 40 degrees of straight down, the rest any angle |
| Cover | Light 20 percent, mid 55, gaps 25 |
| Dark tile `leaf-dark` | Light #3F9A4E, mid #2A7A3C, gap #17522A. Mean about #29763B |
| Lime tile `leaf-lime` | Light #A6D552, mid #86BE3C, gap #4F8F2A. Mean about #7FB73C. Do not brighten it to hit #86BE3C |
| Roughness `leaf-rough` | Leaves 0.88 (grey 224), gaps 1.0 (255). Replaces flat 0.92 on lime. No metalness, no normal map |

- Lime (Blossom): `leaf-lime` replaces `lime-leaf.png`. SA Color white: the tile already holds the final colours.
- Dark (Round, Tall): `leaf-dark` replaces the island foliage map, with `leaf-rough`. Keep the #E6FFE0 tint.
- Hatch crown and the Rest bushes: take `leaf-dark` only if their UVs give 3 to 6 studs per tile. If not, leave them
  on the island map and tell me. Merged crowns (no kit, Aero off) are untouched.
- Blossom Point at scale 1.7 will show bigger leaves. Accepted.

**Vertex shading** (a multiplier over the tile). By height: t = (z - plane) / (top - plane), smoothstep.

| Crown | Underside (t 0) | Top (t 1) | Gives |
|---|---|---|---|
| Lime | #A1CEB7 | #FFFFFF | #55992B under, tile colour on top |
| Dark | #A6B8AE | #FFFFFF | about two thirds value under |

Then times 0.85 on any vertex that sits inside another clump (dark creases between clumps). Tufts take the value at
their root. Capture `hub`, `lime-tree`, and one from under a Round crown looking up, at day and garden hour.

## 3. Fountain loop (`fountain_loop`)

**What it should be:** small water falling into water, close by. Light, bright, steady. A garden fountain you stop
noticing. What the rustle got wrong was a noise wash that swelled and restarted. This must do neither.

File: 32 s, 44.1 kHz, 16-bit, mono. Built on a circle like the rustle (loop-wide filters, grains that wrap), no crossfade.

| Layer | What | Band | Detail | Level |
|---|---|---|---|---|
| A. Basin splash bed | Shaped noise, made lumpy | 900 to 5,000 Hz, centre near 2.2 kHz | Multiply by random flutter at 25 to 60 Hz, depth 35 percent, so it is water texture, not hiss | 0 dB (reference) |
| B. Spill streams | 8 narrow noise bands, one per stream | Centres spread 1.4 to 3.6 kHz, each about a quarter octave wide | Each: centre wanders 6 percent at 0.3 to 0.8 Hz, flutter 12 to 30 Hz at depth 50 percent, all eight unrelated | -5 dB |
| C. Jet patter | Short sine plinks, pitch rising 10 to 25 percent | Start 2.2 to 6.5 kHz | 55 per second on average, random timing. 6 to 22 ms, 1 ms attack, exponential decay. Loudness -18 to 0 dB, mostly quiet ones | -7 dB |
| D. Ticks | Tiny noise grains | 3 to 8 kHz | 30 per second, 3 to 8 ms | -12 dB |

**Slow variation allowed:** only grain density (C, D) and stream levels (B), each 15 percent at most, on different
whole-number cycles per loop (3, 4 and 5 cycles: 10.7, 8 and 6.4 s). Never all layers together. Layer A does not move.

**Keep out:**
- Anything below 500 Hz (40 dB down by 350 Hz). No gurgle, no rumble, no plink starting under 2.2 kHz.
- Anything above 9 kHz (30 dB down by 11 kHz). That is hiss.
- Falling pitch of any kind. Moving filter cutoffs on the bed. Any swell, fade in or fade out. Any envelope longer
  than a grain except the slow variation above.

Level: peak -6 dBFS, RMS -22 to -20 dBFS.

**In game:** PlaybackSpeed 1.0, volume 0.14 (the stand-in was 0.16; this is brighter), min 5, max 26, InverseTapered,
through AmbientAudio as now. Start at a random TimePosition and never restart it while the garden is loaded: distance
alone sets how loud it is. If the voice must be made on approach, fade it in over 0.6 s from a random position.

**Checks before Spencer hears it:**
1. Spectrogram of the whole loop: an even horizontal band. No vertical stripe wider than 0.1 s, no slanted lines,
   nothing above -45 dB under 400 Hz, nothing above 10 kHz.
2. RMS in 0.5 s windows: highest minus lowest 2 dB or less. Play it three times end to end: the seam at 32 s cannot
   be found by eye on the waveform or by ear. Starting at five random positions sounds the same each time.
3. Flush test: play it at half speed, and through a phone speaker. If it reads as a cistern filling, a tap in a
   sink, rain on a roof, frying or TV static, it fails. Next to `waterfall_loop` it must sit higher and lighter.

These checks only keep a bad file from reaching him. **Spencer's ears decide.** If he says no, the fountain stays on
the stand-in or goes silent; do not ship a "nearly".

## Round 6 (build review, kit r11, 2026-11-23)

| Piece | Verdict | In one line |
|---|---|---|
| Pool and stream | GO WITH CHANGES | Colour is right. The glint dashes are too hard, and old blue shows at the rim |
| Crowns | GO WITH CHANGES | Leaf tiles work. Blossom still reads as a cube, tufts float, grey film on shaded faces |
| Fountain loop file | GO to Spencer's ears | Every number I set passes. Nobody has listened yet |

**Pool.** Water in `pool-edge` measures (61,165,195) against the #3BA3BE target (59,163,190): keep the darker tile.
The cobalt is gone and the white Bear is the brightest smooth thing in frame, which is the point. Pool and stream
match in `hub`. What is wrong: the base net is almost invisible in game, so the glint layer is the whole pattern,
and it reads as straight chalk dashes (L and T shapes), not a soft net. Also a strip of saturated blue, about
(62,161,234), shows at the waterline against the rim wall left and right, in both captures, so it predates the tile.
The foot shade cannot be judged from this angle.

**Crowns.** Dark tile measures as specified and Round and Tall read leafy and matte in `hub`. Better than
`lime-close-r10-boxy`, but in `lime-tree` the Blossom is still a cube with a flat lid: every clump has its pole
straight up, so each shows the same vertical wall (the 74 to 118 degree band) and the same flat cap, all lined up.
Three tufts hang in clear air right of the near crown in `lime-tree` and two in `under-round`: that reads as a bug.
Shaded faces carry a grey-tan film that hides the gap colour (`under-round` centre and top clump, measured
(60,113,74) where the tile is (42,120,60)). I think it is sheen from the 0.88 leaf roughness; that is a guess.

**Fountain loop.** RMS -21.95, peak -6.0, 0.5 s spread 1.18 dB, seam -0.09 dB, -65 dB at 400 Hz, -82 dB above
11 kHz: all inside the checks. Spectrogram: even band, no slants, no wide stripes, no swell. Checks 2 (by ear) and
3 (half speed, phone speaker) still need a person. Risk I can see but not hear: the bed is a very even slab, which
could read as static. If Spencer says so: layer A down 3 dB and its flutter depth 35 to 50 percent. Not before.

### Now

| Piece | Property | From | To |
|---|---|---|---|
| Pool, stream | Glint layer Transparency | 0.55 | 0.72 |
| Pool | Blue strip at the rim waterline | about (62,161,234) | Find the part; colour it #379DB9 or hide it under Aero |
| Crowns | Clump pole axis | all straight up | Tilt each clump 20 to 40 degrees, random direction, fixed seed. Flat underside clamp after the tilt |
| Crowns | Alternate rings | lined up | Turn every second ring half a step (22.5 degrees at 8 around) |
| Crowns | Vertex jitter | 8 percent of radius | 13 percent |
| Crowns | Tuft root | on the rim, some in clear air | 0.3 inside the nearest clump surface. Delete any tuft whose root cannot reach one |
| Crowns | `leaf-rough` leaves | 0.88 (grey 224) | 1.0 (flat 255). Recapture `under-round`; if the film stays, tell me, do not chase it |

Recapture `pool-edge`, `lime-tree`, `under-round` after these. Triangle counts, pivots and footprints unchanged.

### Later

- Redraw `pool-glint` with the bend warp and a soft falloff so the lines curve; then try Transparency back at 0.6.
- Lift the base net a little (line peak toward #6CC0D3) so the pool keeps a pattern under Reduced Motion.
- Capture the foot shade from the side, low, before deciding its strength.
- Fountain basin water in `fountain-15` is flat navy; move it toward the pool teal.
- Hatch crown and bushes: new UVs at 4 studs a tile so they can take `leaf-dark`.
- If crowns look flat at garden hour (no vertex shading), bake a darker underside tile variant.

## Round 7 (fix check, kit r12, 2026-11-23)

Compared `r6/` with `r5/` for `pool-edge`, `lime-tree`, `under-round`.

**Pool: GO.**
- The saturated blue strips at the rim waterline (left foreground, right by the far coping) are gone; the edge now meets the coping in pool teal.
- Glint at 0.72 sits under the base net instead of on top of it. The surface reads as water with a pattern, not white chalk lines.
- The Bear (facing away) stays the brightest thing in the frame. Rocks and coping unchanged.

**Crowns: GO.**
- The grey-tan film is gone in `under-round` and on the near crown in `lime-tree`: shaded faces are now deep green with the leaf tile readable, no washed patches.
- Clumps lean in different directions, so the round crown and the lime crown read as lumpy masses instead of stacked balls.
- No tuft floats in clear air; all the spikes in both frames grow out of a clump. The lime crown keeps its lighter, yellower value against the round crown.
- Seen, not blocking: the near crown in `lime-tree` shows two large flat faces with a hard straight edge at very close range, and the round crown is now a little uniform in value from below. Both fall under the existing Later item (darker underside tile variant).

**Blocking items:** none. Ship r12 to the private beta. The Later list from Round 6 stands unchanged.
