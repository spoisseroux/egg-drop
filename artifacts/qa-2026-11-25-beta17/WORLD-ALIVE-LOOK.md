# A more alive world, the Hollow park, the Dash gate set, the river stones: the look (Fable, 2026-11-25)

For beta (17) QA (`FEEDBACK.md`, Direction): "think more about how we can make the world look more alive; research how
to make a Roblox world feel alive and high quality", the pet park by the cliff, the race start and finish models, and
the river stepping stones (shot 012655). Direction only; Opus builds. Original designs, no generated art.

**The rule, unchanged:** the world is realistic, textured and matte, in lower-saturation natural colour, so the pets are
the brightest, smoothest things on screen. Ambient motion is eased and slow.

**What I read:** `FEEDBACK.md` and shot 012655; `WORLD-AND-NEST-LOOK.md` (W3) and `GARDEN-LIFE-BUILD-PLAN.md` (rows 1 to 8
and "As built"); `ParkLayout.lua`, `ParkDirector.lua` (how sites are used), `park-manifest.json`;
`CLIFF-PATH-AND-ARCADE-CAVE-LOOK.md`, and on `claude/cliff-den-scope`: `FABLE-BLOCKOUT-R1.md`, `STUDIO-PROBE-R1.md`,
`cliff_den_data.py`; `DashCourse.lua`, `DashMount.lua`, `DashProps.lua`, `DashRing.lua`, `build_dash_course.py`, the
`dash-2026-11-22` captures; `WorldAero.lua`, `GardenHour.lua`, `HollowClock.lua`, `AmbientAudio.lua`, `WorldMotion.lua`,
`WorldAeroKit.lua`, `WorldV7Data.lua`, and the one-stud surface map in `world-v7-walk.json`.
**Nothing here has been seen in Studio.** Positions from the surface map are good to about 1 stud; the park's own
comment says never to trust the exported grid for clearances, so every park number needs the Studio raycast sweep.
Every `[check]` is one look or one probe.

Common, as before: new world parts `Anchored`, no collide / query / touch, `CastShadow` off unless said. Budget levels
are `AliveBudget` 0 / 1 / 2. New motion sits behind the `scene` switch (beta only) unless said.

---

## 1. Alive and high quality

### 1.1 What the research says (web search, 2026-11-25)

| Finding | Source | What it means here |
|---|---|---|
| Movement is the first thing that makes a place feel real: ambient sway, reactive objects. | Roblox docs, "Develop a moving world" | We have this (wind, leaves, birds, koi). The gap is **things that answer the player** and **the water**, which is still a flat sheet. |
| `Workspace.GlobalWind` drives dynamic clouds (and terrain grass); script it for gusts. | Roblox docs, "Global wind" | We never set it. Our clouds ignore our own wind. One line makes the sky answer the big breath. |
| Use Atmosphere, not fog. ColorCorrection sets the tone and runs at every quality level. Keep bloom low. Animate `ColorShift_Top` to warm the sun. `OutdoorAmbient` is the shadow colour. | DevForum lighting guides; Roblox docs, post-processing | All already done (`WorldAero`, `GardenHour`, `HollowClock`). **Do not add more post effects.** Bloom .18 and SunRays .03 are right. No gameplay depth of field: on a phone it costs a full-screen pass and blurs the pets. |
| Borrow from photography: framing, leading lines, one focal point per view. | ebur1n, Roblox Connect 2022 (gamedeveloper.com) | The cliff path is a new high viewpoint. Design what it looks down on (section 2). |
| Forced perspective, lighting, colour and material use make a pleasing space. Detail density on surfaces is what reviewers praise in cosy places. | Roblox developer blog; Pocket Gamer on Livetopia; DevForum showcase threads | Quality is read at **edges**: where grass meets path, water, stone and cliff. Ours are clean lines (a marble kerb the whole length of the stream reads as a canal). |
| Budget: stay under 1,000 draw calls and 1,000,000 triangles on the baseline device; a mobile developer's stricter rule is 500 draws and 500,000 triangles in view. Particles and clouds count as draws. | Roblox docs, "Design for performance"; DevForum optimisation guide | The island is **115,900 triangles in 103 mesh parts**. Triangles are not our limit; draws and overdraw are. Meshes that share one mesh id and one texture batch well, so a small kit placed many times is cheap. Alpha cards (grass, reeds) cost overdraw: keep them few and at edges. |
| Ambience matters as much as visuals: layered beds, zones with their own reverb, emitters on things. Global `AmbientReverb` hits every sound and ignores SoundGroup effects. | DevForum, AmbientSorcery's tutorial; Roblox docs, Duvall Drive soundscapes, `SoundService` | Use a `ReverbSoundEffect` on the ambience and SFX groups only (never the music) for the Play Den. Keep one continuous wind bed instead of restarting a loop per gust. |

I found no good source comparing named cosy games' art, so there is no "do it like X" here. No art is copied.

### 1.2 What the garden still lacks

Against the six W3 points (one wind, three distances, changing light, shared moments, residents, quiet):

- **The sky does not join the wind.** Clouds drift on their own; daylight never changes between hour phases.
- **The water is dead on top.** Koi are under it; nothing rides it, and nothing shows it flowing past the stones and piers.
- **Nothing lives on the ground.** Birds sit on crowns and leave. Nothing forages on the lawn or answers a pet.
- **Edges are bare.** No reeds, bank stones or tufts. The stream is a marble canal.
- **Sound has no room and no wind.** The rustle is off (it restarted per gust); the cave has no echo.

### 1.3 Ranked additions

Build in this order. A to F are code-only (no new mesh; textures already uploaded or one small script-drawn one).

| # | What | Numbers | Budget | Needs |
|---|---|---|---|---|
| **A** | **The sky on the same wind, and a cloud across the sun.** | (1) Every .5 s set `workspace.GlobalWind = Wind.Direction * (3 + 9 * blow)` studs/s, `blow` = `Wind.blow` at the camera (the big breath visibly pushes the clouds). (2) A passing cloud, by day only (daylight over .7), shared clock: slot **100 s**, jitter ±30. Ease in 4 s, hold **5 to 9 s**, ease out 6 s. At full: `Lighting.Brightness` x **.90**, SunRays intensity x .3, Clouds `Cover` +.06, grade `Brightness` -.02. Do it as a pure `GardenHour.shaded(look, k)` beside `Hour.hazed`, so one owner writes Lighting. Shows at every budget level and under Reduced Motion (slow light, no parts). Not in the Hush. | 0 parts, 0 draws. | Code only. `[check]` dynamic clouds follow a client-set `GlobalWind`; if not, set it on the server from the same clock. |
| **B** | **Things on the water.** | (1) **6 drifting leaves** (level 1: 3): plate .7 x .02 x .45, the existing leaf decal, at the surface + .02. They ride the stream's centre line (the `wet` `Water_Stream` boxes in order) at **1.1 studs/s**, each with a side offset of ±35% of the half width, a side wander `.3 * sin(2 pi t / 7)`, and a spin of 8 to 20 degrees/s. Fade in 1 s at the top, out 1 s at the end. Within 1.5 studs of a stone or pier they ease sideways round it. In the big breath, 2 more land. `[check]` they go the way the water texture scrolls. (2) **Flow rings**: one plate at each stepping stone and each bridge pier (5 to 7), the uploaded `Ripple` texture, size pulsing **1.15 to 1.5 x** the stone's footprint over **2.6 s**, decal transparency .55 to .9, each its own phase. | 11 to 13 plates, 6 CFrames at 15 Hz. | Code only (textures exist). Reduced Motion: rings static at 1.2 x, no leaves. |
| **C** | **Birds that forage and notice you.** The same 3 birds, no new parts. | A sitting bird may fly down to a lawn spot (10+ studs from every player, within 40 of the camera, off the course, pad, parks and stations) and forage for **12 to 25 s**: 2 to 4 pecks (head pitch -35 degrees for .12 s, .25 s apart), a hop of .4 studs, a look-about of .6 to 1.4 s, repeat. It **flushes** when a character comes within **7** studs or a pet within **4**: two quick hops away, then up to the nearest crown, one chirp. At most one on the ground at a time (level 1: same; level 2: none, as today). | 0 new parts. | Code only (`LifeSim` Birds: a `forage` state; `flee` exists at 12 for sitting birds). |
| **D** | **A wind you can hear that never restarts, and an echo in the Den.** | (1) The rustle loop plays **all the time** from mount at a random offset: volume `.012 + .07 * blow^2`, slewed at +.12/s and -.05/s; `PlaybackSpeed` `.92 + .10 * blow`; an `EqualizerSoundEffect` with `HighGain` -6 so it is air, not hiss. Never `:Stop()` it outside a deck round or the Hush. It was turned off because each gust restarted it ("toilet flush"); this removes the restart. Ship it **behind its own switch, off by default**, for Spencer to hear. (2) **Den echo**: a `ReverbSoundEffect` on the ambience and SFX SoundGroups (not music): `DecayTime` 1.6, `Density` .8, `Diffusion` .8, `DryLevel` 0, `WetLevel` eased from -60 (outside) to **-14** over .6 s while the camera is inside the den's outline (`CliffDenData.den.outline`). | 0 parts. | Code only; (1) uses the old id 131058187750745 as a placeholder. |
| **E** | **Butterflies lift as you pass.** | A butterfly within **3** studs of a moving character takes its next waypoint 3 to 4 studs up and away at 1.6 x speed for 2 s, then drifts back. `[check]` whether `flies:step` already does this; skip if so. | 0. | Code only. |
| **F** | **Paw prints on the dirt.** | Where a pet walks on dirt (surface code `P`), a print every **.9 studs**, alternating side ±.18: plate .45 x .45, `paw.png` (64 x 64, script-drawn, alpha, one soft print), colour **#5E4534**, decal transparency .35, fading to 1 over **18 s**. Pool of **14** (level 1: 7), only for pets within 35 studs of the camera, nearest first. | 14 plates, written only on spawn and at 2 Hz for the fade. | Code + one tiny texture to upload. |
| **G** | **A bank kit: break the canal.** The biggest still-picture gain. | Three meshes: a **reed clump** (two crossed cards 1.6 x 2.2, one 128 x 256 alpha texture, muted green **#6E8F58** with tan tips; or a 60-triangle solid clump if alpha sorts badly), **three river stones** from the kit's own `rock_shape` generator (.8, 1.4 and 2.2 across, 40 to 80 triangles, the `boulder_rock` texture), and a **lily pad** (12 triangles, 1.1 across, **#5C8A5A**). Place 10 clumps, 14 stones and 5 pads along the stream at bends and beside both bridges, covering about a quarter of the kerb length, never on the Dash line or the stepping stones' landings. Reeds are `WorldMotion` `sway` movers (amp 5, period 3.4, gust gain 2). | About 1,600 triangles placed; 3 mesh ids, 2 textures: a handful of draws. | **Meshes** (Blender kit build + upload). |
| **H** | **Tufts at edges only.** | One crossed-card tuft (8 triangles, .9 x .7) and one 128 x 128 alpha grass texture in the lawn's own green, two tints. **120** placed where lawn meets rock, cliff foot, tree feet and the outer side of path edges; none on open lawn (the pets must stay readable). Static. Culled past 60 studs; level 1: the 60 nearest; level 2: none. | 960 triangles. Overdraw is the cost: `[probe]` frame p75 on Spencer's phone before keeping it. | **Mesh + texture.** |
| **I** | **Mist on the water at dawn.** | 5 plates 6 x 4 over the stream boxes, the `dapple` texture tinted **#EAF2F4**, decal transparency **.86**, drifting .25 studs/s downstream, only while daylight rises through .30 to .70, fading at both ends. | 5 plates at 5 Hz, a few minutes an hour. | Code only. Low priority: it may read as a film on the water `[check]`. |

**Phone budget for A to F at level 0:** about **27 plates** more (13 water, 14 prints), **no new emitters, no lights, no
post effects**, about 120 more CFrame writes a second in GardenLife's `BulkMoveTo` (on top of about 1,800). G and H add
about 2,600 triangles to 115,900.

**Do not add:** more particles, glow, bloom, depth of field in play, saturated colour, or anything looping faster than
about 1 Hz at mid distance. A world reads as high quality when its edges are broken and its light changes, not when
more effects are on it.

---

## 2. The park by the cliff: "the Hollow"

Today the grove is the arrival park turned half a circle: the same ellipse (32 x 22), the same marble kerb, the same
star-orb posts, dropped on a lawn at (-38, -46). It ignores the cliff 10 studs behind it.

### The idea

**A round glade backed into the cliff, with no kerb.** The cliff is its back wall. Its edge is made of natural things:
the cliff foot, a fallen log, boulders, a flower drift. The play pieces fan out round a middle lawn so that **from the
new cliff path above, the worn ground under them reads as a paw print**: four toe patches and one palm. Nobody is told.
Shelf 2 of the cliff path runs right above it at 19 to 23 studs up, with gaps in its stone lip to look through.

More to find: a **fallen marble column** half buried in the dig spot (the same marble as the garden, as if the old
garden runs under the hill; a column already stands at the path's foot), and a **stump circle** by the east gap.

### The ground

- Cliff foot (lawn side of the rock, from the surface map): (-36, -70), (-46, -66), (-50, -62), (-56, -58), (-64, -54),
  (-70, -48). It rises to 10 to 17 within 4 studs.
- Dirt path to the cave on the east: x about -22 at z -46, -15 at z -56, -11 at z -66.
- Between them the lawn is flat (4.4 to 4.6) and has no trees. Nearest find spot (-60, -50); nearest trunk (-71, -44).
- The cliff path's bank is at z under -80 and the den apron ends at z -89: 15+ studs north of everything below.

### Layout (world studs; yaw as `ParkLayout`: atan2(dx, dz) of the piece's front)

| Thing | Where (x, z) | Yaw | Notes |
|---|---|---|---|
| **Membership circle** | centre **C (-42, -51)**, radius **14** (`Radius = Vector2.new(14, 14)`) | | Invisible. It kisses the rock on the north-west; that is fine. 6 studs clear of the dirt path, 4 clear of the find spot. |
| Palm (middle lawn) | **P (-40, -48)**, about 13 x 10 | | Lighter, trodden clover. Where you arrive. |
| Toe 1: **see-saw** | (-36.3, -58.4) | -0.34 | Beam across the fan, pets face each other. |
| Toe 2: **slide** (deck) | (-43.1, -58.6) | 0.29 | Ladder foot toward the cliff at about (-43.4, -59.8); the chute runs to (-41.0, -51.4) and lands pets in the palm. Boulders round the deck so it reads as coming off the rock. |
| Toe 3: **dig spot** (sandbox) | (-48.7, -54.7) | 0.91 | In the cove, nearest the cliff. The fallen column lies along its cliff side. |
| Toe 4: **swing** | (-51.0, -48.3) | 1.54 | Seats face the palm. |
| **Ball** | (-35.5, -46.5) | 0.6 | In the palm's east half, 7 studs from the chute's foot. |
| **Bench** (the long one, 9.57) | (-34.5, -43.5) | faces C | On the palm's outer rim, looking at the fan and up at the path. |
| Gap "path" | rim at angle -0.15: about (-28.2, -53.1), 4 wide | | Toward the dirt path and lamp 4. |
| Gap "plaza" | rim at angle 1.75: about (-44.5, -37.2), 4 wide | | Toward the hub. Both gaps are 6+ studs from the bench's ends. |

The toes sit 11 studs from P, 36 degrees apart (about 7 studs centre to centre), fanned toward the cliff.

### What you see instead of a kerb

| Piece | Where | Build |
|---|---|---|
| Toe patches (4) | under each toe piece | Ground plates 6.5 x 5.5, long side pointing at P, `lawn-patch-a` tinted earth **#9A7B55**, decal transparency .30 (the dig spot's: sand **#D9C29A**). Height .040 like the other patches. |
| Palm patch | at P | Three overlapping plates (9 x 8 at P, 6 x 5 at P ± 3.5 along the cliff), `lawn-patch-b` tinted **#6FA85A**, transparency .45. |
| Gap stones | each side of each gap, 4 apart | Four standing stones about 1.2 x 1.8 x 1.0, from the stone builder in section 4. No star orbs here. |
| Fallen log | about (-54.5, -44.5), lying along the rim | Cylinder 9 long, 1.4 across, `Wood`, **#6B4E37**, sunk .25; one end cap lighter **#B79A72**. Players collide (a simple box); pets keep out (radius 1.2 circles along it). |
| Stump circle | about (-30.5, -57), three stumps | Cylinders 1.2 across, .7 to .9 high, same wood; tops **#B79A72**. |
| Flower drift | along the rim behind the bench, 16 studs | 8 of the existing flower decal plates. |
| Rim boulders | 5, from 2.4 down to .9 across, on the east rim between the stumps and the cliff, and 3 round the slide deck | The stone builder (section 4). |
| Fallen column | at the dig spot, cliff side | Cylinder 3.2 long, 1.6 across, `Marble`, the bridge's marble colour, leaned 20 degrees, 60% sunk in the sand; one gold band .2 wide. |

### What changes in code, and constraints

- `makeLayout` takes a **site spec** (centre, radius, gaps, bench, and for each piece a position and yaw) in place of
  one centre and a half turn. Each piece moves as a **rigid group**: its root, its slots, its named points and its
  keepout circles turn about the piece's own root. Nothing inside a piece changes (seat heights, arcs, the chute's 7.5
  run, `SeatStepOut`), so the pose data and choreography are untouched. The arrival site's numbers must come out
  byte-for-byte as today (a spec that pins them).
- The same five pieces and nine slots, the same `SlotOrder` and capacity. No new activities.
- The grove site carries `natural = true`: `ParkMount` builds no kerb and no star-orb posts there, and builds the
  dressing list above instead. The equipment meshes stay as they are tonight.
- Every position gets the **Studio raycast sweep** the park's own comment asks for (flat ground under each anchor, the
  rim and 2 studs outside). Every slot approach must be inside the circle less 1 stud. Nudge by up to 1.5 studs and
  tell me.
- Regenerate what reads the kerbs: `GroundDressing` (parks + 2), `FindSpots`, the Dewdrop rest spots; `GardenLife`
  reads `Radius` at run time. Rerun `MultipleParks.spec`, `ParkDirector.spec`, `ParkMount.spec`.
- Clear of the cliff work: the path's bank strip is 15+ studs from the circle, the new evacuation spot (-27, -84) is
  22 from it. If the island sculpt's dry-stone bank bows more than 3 studs onto this lawn, the fan shifts toward P, not
  the circle `[check]` against `CliffDenData.path`.
- `[check]` the phone camera with the player on toe 3 facing the palm (a 65-degree wall 6 studs behind).
- `[check]` from shelf 2 the four patches and the palm read as a paw. If they read as blotches, darken the toes to
  transparency .20 before changing shape.

**Later, with meshes (not tonight):** a see-saw that is a log on a stone, a swing hung from a leaning tree (a new
trunk, the kit's round crown), the slide as a worn stone chute, a log bench, glow-caps in the cove.

---

## 3. The Garden Dash start and finish: one fete set

Today: red and cream plastic posts, a red ball with a yellow flag, yellow and cream slabs, a sky-blue disc, and at the
far end a lilac frame with a yellow bar. Five unrelated colours in `SmoothPlastic` on a textured world, and the two
ends do not look like the same event.

**One family: timber posts on the garden's marble-and-gold feet, rope, and cloth flags in four muted colours.** The
feet are the bridge's newel posts (marble block, gold cap), so the set belongs to this garden. The rope and stakes are
the waiting ring's.

**Shared values**

| | Value |
|---|---|
| Timber | `Wood`, **#A9764A**; dark end grain **#7A5636** |
| Marble foot | `Marble`, the bridge's marble (`#F4EFF5` to start `[check]` against the bridge) |
| Gold cap | **#E0A93A**, `SmoothPlastic` is fine here (it matches the bridge caps) |
| Cloth | `Fabric`: cream **#EFE6D2**, dusty rose **#D9A0A8**, sage **#9DB8A0**, soft teal **#6FAFA6**, in that order, repeating |
| Rope | the ring's rope look (`DashRing`): a Beam, width .11, with sag |
| Stone | section 4's stones |

**Start gate** (at distance 0, posts at ±`Grid.PostOut` = 6.75, so 13.5 between centres). Nothing may hang below
**9.6** across the lanes (the race camera is 9 up).

| Piece | Size | Where |
|---|---|---|
| Foot x 2 | 1.6 x 1.0 x 1.6 marble | on the ground |
| Cap x 2 | 1.8 x .25 x 1.8 gold | on each foot |
| Post x 2 | .6 x 10.6 x .6 timber (casts a shadow) | on each cap; top at 11.85 |
| Rope | Beam between the post tops, sag .6 | lowest point 11.2 |
| Flags x 9 | .8 x 1.0 x .05 cloth, hung by their top edge from the rope, 1.35 apart, each resting turned 3 to 8 degrees | bottoms at about 10.1 |
| Header board | 5.0 x 1.3 x .22 timber, on two .12 rope drops from the rope's middle | centre at 10.4, bottom 9.75 |
| Header words | SurfaceGui on both faces, the existing Dash title string (no new words), cream on timber | |
| Guy lines x 2 | a Beam from each post at 9 up to a stake (.16 x 1 x .16, the ring's stake) 5 studs out and 3 back | 3 small flags on each |
| Start line | one strip 13.5 x .04 x .3, **#EDE8DA**, transparency .15 (chalk) | replaces the eight slabs |
| Lane stones x 8 | flat pebbles .7 across, .08 high, `Slate`, alternating **#8C8A84** and **#B8B2A6** | one under each racer's slot |
| Balloon | 4 across (was 5), `Fabric`, **#D9776B**, a cream band round its middle, a rope Beam down to the north post's top | still 16 up, still bobbing |

**Waiting pad:** the blue disc becomes **trodden earth**: a disc of radius 2.5, .06 high, `Ground`, the dirt path's
colour `[check]`, with the rope ring round it as today. The sign: a timber post .3 x 3 x .3 and a board 2.4 x 1.3 x .2
in the header's style.

**Finish** (at the course's end on the west path; today 5.6 wide and 5 tall):

| Piece | Size | Where |
|---|---|---|
| Foot x 2, cap x 2 | 1.2 x .8 x 1.2 marble; 1.4 x .2 x 1.4 gold | at ±3.4 |
| Post x 2 | .5 x 6.2 x .5 timber | top at 7.2 |
| Rope and flags | Beam, sag .4; 5 flags .7 x .9 | bottoms at about 5.9 |
| Rosette | a cream disc 1.6 across and .12 thick, a gold disc .7 across on it, two cloth tails .35 x 1.1 (rose, teal) | hung at the rope's middle, facing the runners. No words. |
| Finish line | the same chalk strip, 6.8 long | on the dirt |

**Hoops** (client, `DashProps`): keep the shape; `Fabric`, rose **#E79AB4** with the cream top. Not tonight's priority.

**Parts:** about 50 static parts in `DashMount` (was 25). They are anchored, shadowless but for four posts, and in
five materials, so they batch. Raise the "both under 60" note to **Mount 60, Props 60**. Flags are static tonight;
swaying them on the client with `Wind.swayAt` (±6 to ±22 degrees about the rope) is the follow-up.

**As a kit mesh later:** one start-gate mesh (about 600 triangles) and one finish mesh (about 350) on the park
palette's approach, with the flags as separate `sway` movers like `W7_Pennant`. The part set above is the blockout for
it, so its sizes carry over.

`[check]` from the arrival dais (96, 66) the gate reads as a festival gate, not scaffolding; from the pad the header is
readable; no flag enters the race camera.

---

## 4. The river stepping stones

Shot 012655: three pale lilac squares (2.2 x .3 x 2.2, `SmoothPlastic`, **#B9B4C4**), evenly spaced in a straight row,
floating on the water like tiles. Beside them is a real mossy boulder, which shows them up.

**What makes a stone read as a stone:** an irregular outline, a domed top, a darker wet band at the waterline, a
different size and turn for each, moss or lichen on top, water moving round it, and a bank that is broken where the
crossing lands.

**Each stone** (centres stay within **.3** of `Course.Stones`, where the hop is judged):

| Stone | Centre (x, z) | Footprint | Turn | Top y | Colour |
|---|---|---|---|---|---|
| East | (7.5, 9.0) | 2.6 x 2.1 | 20 degrees | 4.05 | **#8A8580** |
| Middle | (4.5, 9.4) | 2.8 x 2.4 | -35 | 4.15 | **#7F847F** |
| West | (1.55, 10.0) | 2.5 x 2.0 | 70 | 4.05 | **#948E84** |

Water is at 3.2 and the kerb at 4.3, so each shows about .85 of stone and steps down a little from the bank.

- **Shape, tonight (code-only, the "stone builder"):** carve each on the server with `GeometryService:IntersectAsync`:
  a Ball 1.5 x the stone's length, sunk so only a low dome of the stone's height shows, cut by **5 to 7** big Blocks
  whose near faces stand at 85 to 100% of the footprint radius, each at its own yaw and leaning out 8 to 20 degrees
  (seeded per stone). Result: one faceted, flat-domed, many-sided stone, like the kit's boulders. `Slate`,
  `UsePartColor`, `SmoothingAngle` 0, no collision on the visual. If the call throws: two stacked Cylinders (the
  footprint's width, then 80% of it, .45 and .3 high), `Slate`. The same builder makes the park's stones (section 2).
- **Shape, proper (mesh):** three stones from the Aero kit's `rock_shape` with the `boulder_rock` texture, so they are
  the very rock beside them. Swap in when the bank kit (1.3 G) is built.
- **Wet band:** under each, a second stone 1.12 x as wide, 35% darker, its top at 3.25 (just over the water).
- **Moss:** on top, one plate at 70% of the footprint, `lawn-patch-a` tinted **#5F7F4A**, decal transparency .45.
- **Flow ring:** 1.3 B's ring round each.
- **Company:** three small stones (.7 to 1.1 across, top 3.4 to 3.6, not walkable) just off the row: one upstream of
  the middle stone, two downstream of the east one. They break the straight line.
- **Landings:** where the row meets each bank, one flat stone set **into the kerb line** (2.4 x 1.6, top 4.3, at about
  x 9.2 and x -.2), so the marble kerb is interrupted and the crossing looks used. `[check]` it does not z-fight the kerb;
  sink it .02 below or raise .03 above, whichever hides the seam.

**Colliders (Opus):** separate from the look. One invisible Cylinder per stone, axis up, **2.9 across** (a little
wider than the stone), top .03 under the stone's top, 1.2 deep. At that width the three discs and the two kerbs leave
no gap over .3, so the crossing is a walk, not a jumping puzzle. Players only; pets and Dash runners do not use them.
`[check]` an avatar walks kerb to kerb without jumping, and nothing catches at the kerb's .25 step.

---

## 5. Captures wanted for my review

1. The sky in a big breath, 10 s of video; a passing cloud on the plaza, before and at full.
2. The stream from the bridge: leaves and flow rings, 10 s.
3. A bird foraging, then flushing as the player walks up.
4. The Hollow from the plaza gap, from the palm, and **from shelf 2 of the cliff path looking down**.
5. The start gate from the dais (96, 66), from the pad and from the race camera at the countdown; the finish from 20
   studs up the course.
6. The stones from shot 012655's spot, and one from water level.
