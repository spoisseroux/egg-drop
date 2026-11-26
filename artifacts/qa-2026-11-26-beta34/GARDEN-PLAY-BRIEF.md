# Garden play brief (Fable, 2026-11-26) for Opus

Beta (34) notes 13, 14, 16, 17. Beta only, one Alive switch each (`balls`, `crunch`, `wobble`, `air`). No new text. All numbers `[PLACEHOLDER]`; raycast-check every coordinate in Studio. Avatar: ~4 studs.

Shared rules: matte, textured, believable, so the pets stay the cute thing. Our own meshes (Blender scripts) and sounds (`scripts/synth_asmr.py`). Reduced Motion: all still. Vibration only through `Haptics` and its cap. Cull at 90 studs (phone) / 150 (desktop).

## 1. Bumble balls (3)

**Why:** walk into it and it goes; a friend or a pet sends it back.

**Look:** diameter 2.4 (knee to waist), one mesh each, 300 tris or fewer, 256 px hand-drawn texture.

| Ball | Look | Colours | Voice |
|---|---|---|---|
| Wicker | woven rattan, two darker bands | `#C9A36B`, bands `#8A6A3C` | dry rattle |
| Felt | wool felt, cream blanket-stitch seam | `#E8785A`, seam `#F4E8CF` | soft thud |
| Cork | speckled cork, brass bell slot | `#B98A5E`, slot `#D9B24C` | knock + small jingle |

No sports-ball looks, no gloss. A blob shadow under each.

**Where (off `Routes.ArrivalToHub`, the parks and the Dash):** Felt south of the Toy Lawn about (-30, 27); Wicker on the fountain lawn about (42, -6), outside the `BubbleSpring` wet box; Cork about (58, 30). Leash: 22 studs.

**Motion:** a kick is a character's root within 1.9 of the ball, moving over 4 studs/s. Launch along the walker's heading: 26 studs/s flat + 9 up (running jump: 32 + 13). Gravity 60, restitution .55, .42, .30, then roll with drag to rest in about 2.5 s. Squash 12% per bounce; spin matches travel.

**Networking feel (the main ask):**
- An anchored client part. No Roblox physics, no position stream.
- One pure shared module (`BallMotion.sample(record, now)`, like `ParkFetchMotion`) gives position from a kick record `{id, origin, velocity, startTime, n}` on `workspace:GetServerTimeNow()`. Ground from `groundY`; water, `Blocked`, the island edge and the leash reflect inside the sim.
- **Kicker: instant.** Sound, buzz, squash and launch play the same frame from a predicted record, then one reliable remote is sent.
- **Server:** checks reach (6 studs or fewer), rate (4 a second per player), clamps speed, stamps `startTime` and `n`, broadcasts. It steps the pure sim once to store the rest spot. No per-frame work.
- **Others:** start the record at its server time, already part-way along the arc, and blend from where their ball is drawn over .15 s. Never snap; if the gap is over 12 studs, shrink, move, grow in .25 s.
- Two kicks at once, or a refused kick: the losing client blends to the server's arc over .2 s.
- A late packet costs a later start, never a stutter. Joiners get the three rest spots.
- A ball off its leash with nobody within 30 studs rolls home slowly.

**Pets:** a moving ball within 14 studs: ears up, head tracks. At rest within 10 studs: about one in three free pets trots over and nose-bunts it (server kick at 40% speed, once per 8 s per ball), then hops. Never onto a path, water or the Dash.

**Sound and buzz:** kick `land` (114394270790206) pitched per ball, plus new `ball_wicker`, `ball_felt`, `ball_cork` (kick and bounce, 3 takes each). Pet bunt: `bear_boop` (110282522210689). Water edge: `puddle` (79464813520035). Haptic: `settle` on kick for the kicker only.

**Budget:** 3 meshes, 3 shadows, one remote per kick, a client loop only while a ball moves.

## 2. Crunchy toys (4 kinds, 7 pieces)

**Why:** nice to stomp. Sound first.

| Toy | Look and size | What it does | Where |
|---|---|---|---|
| Leaf heap (2) | dry leaf mound 5 wide, 1.2 tall; `#C98A3C`, `#A8552E`, `#E0B24F` | walk or jump through: mound flattens, 14 leaf cards burst and flutter down 1.5 s; re-heaps over 20 s | under the trees near lamp 7 (-22, 38); near lamp 4 (-12, -44) |
| Pop pods (1 row of 6) | sage seed pods, .9 across, `#9DBF6A`, paler dome | step on one: squashes flat with a pop; re-inflates after 6 s with a creak | a curve on the lawn about (20, 34) |
| Pebble tray (1) | 6 x 4 timber frame `#6B4A2E`, pea gravel `#B9B2A3` | a crunch per footstep, tiny pebble hop | beside the fountain lawn about (44, 12) |
| Rattle gourds (3) | dried gourds 1.1 tall on a low twig arch, `#D8B56A` | bump: swings 25 degrees, settles in 2 s, seed rattle | arrival side about (78, 56) |

**Networking:** none. Each client watches nearby characters and pets (already replicated) and reacts locally.

**Pets:** trigger them at half volume; a pet that pops a pod startles, then sniffs.

**Sound:** reuse `snack_crunch_feast` (130468203740981), `asmr_flake_a` to `_e`, `asmr_pop_a` to `_c`, `asmr_creak_a` to `_c`, `asmr_egg_set_a` to `_c` (ids in `BoardAudio.AsmrIds`). New: `leaf_crunch` x4, `gravel_step` x4, `gourd_rattle` x3. Always a dry transient over a soft body, pitch varied 6%. Haptics, local player only: `crack1` pods, `creak` leaves, `settle` gravel.

**Budget:** 120 parts in all; 14-particle bursts; other players' crunches at 40% within 30 studs.

## 3. The egg on the rock = the Wobble Egg

**Which:** `Landmark_WobbleEgg` on `Landmark_WobbleEgg_Perch` (`artifacts/world1-mockup/v7/build_world_v7.py` lines 780 to 790): the big cream egg with blue speckles on the crag at the tip of the rock spur, about (17, -45), 5.6 tall, 4.7 wide. Baked into `W7_Landmarks__palette`, so it is flat vertex colour and cannot move. Not NestLandmark, EggCorner or the dressing. **Confirm with Spencer from a Studio capture before building.**

**Build:** split it into its own part in the island export (the `W7_EggsStation__*` pattern), pivot at its foot.
- **Texture:** matte eggshell, 512 px drawn by us: warm cream `#F3EAD8`, fine pores, speckles `#6FB6E8` and `#3F86C4` in loose clusters, weathering near the foot. No gloss.
- **Seat:** a twig and moss collar (`#6B4A2E`, `#7A9A52`).
- **Motion:** idle rock 2 degrees, 5 s period. Every 35 to 50 s (random) one big wobble: 7 degrees, twice, settle in 1.6 s, with `egg_wobble` (103643084989292) heard within 40 studs and 4 moss flecks falling.
- **Reacts:** a player within 8 studs, or a Bumble ball hitting it, triggers the big wobble (4 s cooldown) with `asmr_egg_set` and a `settle` buzz.
- **Night:** a second speckle-only shell fades to a faint `#9FD8FF` glow, one light range 10 at .4. No runtime SurfaceAppearance.
- **Budget:** 3 parts, client tween only. It never hatches.

## 4. Drift lanterns (the garden's air)

**Why:** something to look up at.

**Look:** 9 paper lanterns, each 1.6 across, 2.2 tall, eight-sided: washi cream `#F6EBD2`, bark hoops `#6B4A2E`, a cap and a .8 tassel in `#E8785A`, `#7FB8A4` or `#F2C14E` (three each). One mesh, 250 tris or fewer.

**Where:** 14 to 24 studs over the ground in three loose groups: over the hub (-30, 4), along the bridge (2.5, 21), round the fountain (52, 3). None in the Dash.

**Motion:** bob .6 studs over 7 s, drift on a 3-stud circle over 40 s, sway 4 degrees; each with its own phase. Reuse the `WorldV7Data` `motion` mover.

**Day:** unlit matte paper. Plus one soft seed-fluff emitter over the hub lawn, 3 a second, daylight over .7.
**Night (the lamps' rule, daylight under .3):** paper warms to `#FFD98A`, inner core glows; lights only on the 4 nearest (range 12, .5).

**Budget:** 9 meshes, 4 lights, 1 emitter, one client loop.

## Not yet

Goals or scores; carrying or throwing balls; skins or anything sold; more than 3 balls; physics replication; rewards, Stars or streaks; touchable or released lanterns; the Wobble Egg hatching; new UI or text.
