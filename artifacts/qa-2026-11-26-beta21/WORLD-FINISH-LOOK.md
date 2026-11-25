# Finishing the world for this version: den, cliff path, terrace, and the park up top (Fable, 2026-11-25)

Spencer: "lets finish everything in the scope now then for this version, the larger cave, the terrace, cliff path with
full integration and art. maybe lets move the second park up there?" Direction only; Opus builds. Original art only:
modelled and textured in Blender (procedural or painted), no generated art, no outside assets.

**The rule, unchanged:** the world is realistic, textured and matte in lower-saturation natural colour, so the pets are
the brightest, smoothest things on screen.

**What I looked at:** `CLIFF-DEN-BUILD.md`, `FABLE-REVIEW-CLIFF-DEN.md`, `WORLD-ALIVE-LOOK.md` section 2,
`STUDIO-CHECK-R15.md`, `UPPER-TIER-LOOK.md` / `UPPER-TIER-BUILD-PLAN.md`, `PLAY-DEN-BUILD-PLAN.md`,
`CLIFF-PATH-AND-ARCADE-CAVE-LOOK.md`, the headers of `Tier.lua`, `ParkLayout.lua`, `ParkHollowMount.lua`, `ParkFetch.lua`;
captures `studio/world/r3/01` to `06`, `studio/r15/07a` + `07b`, `hollow-r14/02`. All captures are Studio, PC framing,
Assistant camera. **I have not seen a phone frame, the turn, or anything moving.** Hexes are targets: set, capture,
compare. Every `[check]` is one look or one probe. Tier-frame points are `(s, t)` as `Tier.T(s, t)`: s along the ridge
(north-east -38, south-west +38), t toward the garden (lip at +22).

## 1. The second park moves up: yes

| Question | Answer |
|---|---|
| **Flat ground for play dates and fetch** | The terrace is the only large, perfectly flat, empty floor we have (76 x 44 at y 29). The Hollow is squeezed between a 65-degree cliff and the dirt path, and had to be re-laid once already to clear the path. Fetch (`Fetch.Radius` 14) and nine slots fit up top with room to spare. |
| **A reason to climb** | Today the path leads to nothing. "The playground is up there" is a reason a child understands from the plaza, with no sign, because the swing and the slide roof stand on the skyline and other players' pets are visibly playing on them. |
| **What the lawn gains** | The cliff foot holds the den mouth, the apron, the path's foot, a find spot and a park inside 40 studs. Taking the equipment out gives the den a clear forecourt and the path a clear foot, and removes the pink and yellow toys from the 01 view of the cliff. |
| **Phone camera** | Better. On the Hollow's toe 3 the camera has a wall 6 studs behind it. On the terrace there is sky all round and the bench view looks out over the whole garden. |
| **Reachability, players** | About 80 studs of path, 8 to 9 s. The arrival park stays where it is for first-session play dates, so onboarding never depends on the climb. |
| **Reachability, pets** | The cost: pets must walk the path (transit only, with catch-up landings; the old site spec stays behind the switch for one beta). That is "full integration" and we are doing it anyway (section 5). **The park moves only after pets pass the path probes** (slice order in section 6); until then the Hollow stays as built. |

### The terrace park: "the Top Lawn"

Same five pieces, nine slots, `SlotOrder`, id `grove` (sessions and snapshots unchanged). A new site spec beside
`Specs.hollow`, `natural = true` (no kerb, no star orbs), built by the same `ParkMount` / `ParkHollowMount` code.

| Thing | Tier frame (s, t) | Notes |
|---|---|---|
| **Membership circle** | centre **K (0, 5)**, radius **13** (world about (-57.1, -91.9)) | Rim 4 studs inside the garden lip, 9 inside the outer edge, 13+ from the arrival gap (s 26..34). |
| **Swing** | (-7, 12) | Bar across the view; seats face K. Tallest piece nearest the lip on purpose. |
| **Slide** (deck) | (1, 14) | Ladder on the lip side, chute runs toward K and lands about (1, 6.5). |
| **See-saw** | (8, 11.5) | Beam along the lip; pets face each other. |
| **Dig spot** | (-9, 0) | Outer side, beside an outcrop so it reads as a natural sand pocket. |
| **Ball** | (6, 0) | Open middle; fetch throws go along s. |
| **Bench** (the long one) | (0, -7), facing K | **The composition:** you sit with your back to the outer edge and watch the pets play against the garden and sky. |
| Gap "path" | rim at (13, 4) | Toward the arrival. Two gap stones, 4 apart. |
| Gap "lookout" | rim at (-13, 5) | Toward the north-east end. Two gap stones. |

- **Why the tall pieces sit on the lip side:** from the Hub the lip is about 85 studs away and 24 up, so anything
  more than about 3.5 x its own height back from the lip is hidden. At 8 to 10 studs back the swing bar (5.6) and the
  slide roof show their top 2 to 3 studs on the skyline. `[check]` from CAM-HUB; if they do not show, move K to t 7.
- **Reused dressing** (`Park.Dressing` rows, same builders): 5 toe / palm ground patches under the pieces (earth
  #9A7B55, sand #D9C29A, palm #6FA85A), 4 gap stones, 3 rim boulders by the dig spot, the flower drift behind the bench
  (8 plates). **No log, stumps or column up here**: they stay below.
- Pets keep **3 studs** inside the lip everywhere (slot approaches and wander). Yaws: Opus derives them from "faces K"
  and tells me the numbers. Every anchor gets the Studio raycast sweep; nudge up to 1.5 studs and tell me.
- `[check]` the slide's ladder foot is 5+ studs from the lip and no slot approach leaves the circle less 1.

### What the Hollow's spot becomes: "the Paw Glade"

Equipment, ball mat, toe earth patches and the membership circle go. **Stay:** the fallen log, the stump circle, the
half-buried marble column, the rim boulders, the flower drift and the long bench (a second copy; it now looks up at
the path). The paw print stays as a secret: the four toe plates and the palm become **clover and flower patches**
(`lawn-patch-b`, toes #7FB069 at transparency .35, each with 3 of the existing flower plates; the sand toe becomes
clover too). From shelf 2 it still reads as a paw; on the ground it is just a pretty glade. Keep the find spot at
(-60, -50) and one Dewdrop rest spot. No prompts, no park logic. Regenerate `GroundDressing`, `FindSpots`, rest spots.

## 2. The den art pass

**The idea:** one hollow carved out of the hill, the colour of old dry earth-stone, lit only by four lanterns. Dark
enough that the lamps make pools, plain enough that the toys and pets are the colour in the room.

### The shell (replaces `W7_CD_PlayDen__cliff_rock` and every wall panel)

- **One closed mesh, `W7_CD_PlayDen__shell`:** walls and dome as a single welded surface, normals inward, no loose
  panels, no interior edges, no coplanar faces. Its bottom edge is a **skirt that drops 0.6 under the floor**, and at
  the mouth it runs **outward 3 studs as a collar** that flares into the outside rock and ends buried. Nothing can be
  seen past any edge of it from inside.
- **Shape:** build it round the collision room (x -22..6, z -119..-100, ceiling 12.2 at the walls rising to about 16
  mid-room, mouth x -15..1, 11 high). Not a smooth dome: three or four broad scooped facets per wall, a ledge at about
  y 7.5 along the back wall for the lanterns to hang under, two shallow alcoves (behind the Dash gate and behind the
  crates), and a slightly lower brow over the mouth. Largest facet about 6 studs; no facet under 1.5. Sculpt high,
  retopologise low, bake.
- **Fit to collision:** at body height (floor +1 to +6) the drawn wall is **never inside** the collision room by more
  than 0.3 and **never more than 1.0 outside** it. Collision stays the server boxes; the shell does not collide.
- **Texture: one unique bake, not tiling.** `SurfaceAppearance` drops vertex colours, so the shading has to be in the
  maps. Unwrap the shell once (seams along the floor skirt and inside the collar only), and bake from a **3D
  procedural** rock (so no seam can show) plus the sculpt:
  - Colour 1024: fine grain, faint horizontal bedding every 1.2 to 2 studs, hairline cracks no wider than 0.15 stud,
    baked ambient occlusion at 60%, a darker damp band for the first 1.5 studs above the floor, soot smudges above each
    lantern point. **No big crack network.** Base **#7A6A5C**, bedding **#6A5B4E**, floor band **#54483E**.
  - Normal 1024 from the sculpt plus grain. Roughness flat about .9, no metalness.
  - Give the walls about 60% of the atlas and the dome 40% (it is dimmer and further). Target 24+ px per stud on walls.
    `[check]` from CAM-DEN-IN against the outside rock; if it reads soft, split into two welded halves with 1024 each.
- **Budget:** shell 6,000 triangles or fewer; one material; one draw.

### Floor

`W7_CD_PlayDen__floor`: its own mesh, very slightly dished (0.15), edges under the shell's skirt. Packed earth with a
few flat worn stones pressed in near the mouth and under the bays. A new **512 tile** (`den_floor`: colour, normal),
6 studs per repeat, **#6E5140**, clearly darker than the walls' lit pools and far darker than the Deck screen. 600
triangles or fewer. Drawn top within 0.1 of the collision floor everywhere `[probe]`. The mat stays.

### Lighting

- Four lanterns only, as placed. `PointLight` #FFB870, brightness **0.9**, range **14**, shadows off. `[check]` the
  walls between two lanterns read about two stops under the wall beside one. If the room is still flat (ambient
  winning), lower the bake by 15%, do not add lights.
- **Lantern mesh** (one mesh, 4 copies, 180 triangles): a dark iron cage (#3A3028) with a cap and ring, four slim
  panes. Only the panes are Neon **#C9772E**; the frame hides half of them, so no pure cube of light. Hung from the
  ledge and the beam on 0.8 cords.
- **Crystals are accents, not lamps.** One mesh in three sizes (0.6, 1.0, 1.5 tall, 40 triangles): five- or six-sided
  shards with a clean break at the top, in clusters of 2 or 3 rising from rubble. Colour **#C98A3C** (amber, not
  lemon), `Glass`-free: a matte body with an emissive core (`SurfaceAppearance` emissive strength about 1.2) or Neon
  at **transparency .25** if emissive masks are awkward. **No light on them.** Two clusters outside at the mouth's
  feet, one in each alcove. `[check]` no green or yellow spill on the lawn (r3/02 and 06 still show it).

### Props

**Stay:** timber frame and sign, notice board, Dash gate arch with bunting, rope posts, the Deck stump with the propped
screen and stools, the crate with its dust sheet, the mat, eight paw stones (now one flat stone mesh from the stone
builder, sunk 0.1, #8A8378, not white tiles). **Remove:** every free-standing lantern post. No new props.

### How it meets the cliff outside

- **Bury, do not carve.** The live marble frame and sill stay (their collision bake is the problem); a new
  **`W7_CD_DenMouth` surround** covers them: two leaning jamb buttresses and one overhanging brow, sculpted as a single
  mesh in the **outside cliff rock material at the outside texel density**, 2,500 triangles or fewer. The brow's face
  is 1.5 studs lawnward of the marble and 1 stud over the timber lintel; the buttresses wrap the marble posts. No
  white shows from any angle on the lawn `[check]` CAM-MOUTH30, noon and night.
- The loose slabs over the mouth in r3/02 go (they are the old sculpt's): the brow replaces them. **Every cut face
  takes the rock material.** No tan faces anywhere within 40 studs of the mouth.
- The apron becomes a worn earth patch with a broken edge: the slab's lawn side hidden by 5 or 6 small stones and two
  tufts each side, and the dirt path's foot runs into it. No hard rectangle, no step.
- The marble column stub at the path's foot is live mesh: hide it behind one boulder from the stone builder.

## 3. The terrace art pass

**The idea:** the top of the hill, mown by nobody, with a playground on it. Not a platform. Nothing built except the
toys, one bench and a rope.

- **Ground and outline:** one cap mesh over the slab. Lawn in the **home lawn's material and green** (same world),
  outline a soft bean: the visual edge wanders **0.5 to 2.5 studs outside** the invisible wall line, never inside it,
  and no straight run longer than 12 studs. Collision floor stays 29, walls stay. A worn earth patch 6 x 5 where the
  path arrives, running into the park's "path" gap.
- **The face below it:** no retaining wall. The cap's edge rolls over in a grass lip 0.6 thick and the hillside under
  it is cliff rock leaning back 15 to 25 degrees, sculpted into the existing rock, with **three grass tongues**
  spilling 3 to 5 studs down the face. From the lawn you must not be able to point at where the terrace starts.
  `FaceGarden`, both `Balustrade` runs and their stops are deleted from the greybox.
- **Edge:** a **natural lip, no railing.** The same lip stones as the path (section 4) along the garden side, with
  gaps of 2 to 6 studs, 0.8 to 1.6 high, so pets and children are visible between them from below. On the outer side
  and the ends: three low rock outcrops (the old `ClumpOne` / `ClumpTwo`, now sculpted boulders, 5 high at most, none
  within 14 studs of the arrival) and shrubs. The invisible walls do the safety.
- **The lookout** (north-east end, about s -30..-36, t 12..20): a flat stone slab 7 x 5 set in the grass, standing
  right over the den's mouth, a **log bench** (the Hollow's log builder, 6 long, top flattened) facing the garden, and
  a 6-stud gap in the lip. This is where 07b was blocked: **nothing over 1.2 high within 8 studs in front of it.**
- **Plants:** one tree only, the kit's round crown, 14 tall, at about (20, -12) (outer, south-west), so the hill has
  a top-knot on the skyline. Two blossom shrubs against the outcrops. Edge tufts (World Alive H kit) along the lip and
  outcrops, 30 at most, none in the park circle. Flower plates in two drifts. Night: two unlit glow-caps at
  the lookout, no lights; the sky is the show up here.
- **From the lawn (CAM-HUB, CAM-LAWN01):** a grassy hilltop with a tree, a swing and a slide roof, pets moving
  between lip stones, people on a bench. No dark band, no white, no box.
- **Budget:** cap + face + outcrops 5,000 triangles in two or three meshes, existing lawn and rock materials, no new
  texture. Tree and shrubs are kit instances.

## 4. The cliff path art

**The idea:** an old shelf worn into the rock by feet, not a ramp laid on it.

- **Width 6** walking (8 at the turn). `[check]` the built width (05 reads as 4); two avatars must pass.
- **The cut:** on the uphill side a back wall **3 to 5 studs high along at least the middle 60%**, leaning back 20
  degrees, never more than 9 studs of bare rock in one rise. Its lowest 1 stud is darker (baked occlusion in a colour
  variant, or a dirt-tinted strip mesh). The line **bows 2 to 3 studs** in and out with the contour, twice. Where the
  face is convex and no wall is possible, the outer side gets a built-up dry-stone shoulder under the lip instead, so
  the shelf still has thickness. From CAM-HUB you see a shadowed notch, not a brown stripe.
- **Tread:** shelves stay smooth ramps (pets and collision). Surface: the garden's dirt path material down the middle
  4 studs, **grass creeping over the outer third** (a ragged grass strip mesh, 0.05 proud), pebbles against the back
  wall. The two flights are **five broad stone steps each** (tread 1.4, rise about 0.75, irregular fronts, the lip
  stone material, sunk and worn in the middle) drawn over the collision ramp.
- **Edge:** lip stones from one kit of **five** stones (stone builder, 60 to 90 triangles): length 1.2 to 3.4, height
  0.8 to 1.8, yaw within 15 degrees, gaps 0.6 to 4, every fourth missing, each sunk 0.3, tops rounded. No two
  neighbours alike. Three gaps of 4+ studs on shelf 2 sit directly over the Paw Glade.
- **Handholds:** rope only where it is steep or blind: along the outer side of both flights and round the turn. Dark
  timber stakes (#5C4330, 0.35 square, 2.6 high, leaning a few degrees, 4 to 5 studs apart) and one sagging rope in
  the Dash ring's rope look. Three stakes per flight, four at the turn. None on the shelves: they would fence the view.
- **Plants:** a fern or tuft in a back-wall crack every 8 to 12 studs (12 at most), one shrub on each grass bench
  where the wall steps back, the small tree and the sitting stone at the turn behind the rock fin (now an irregular
  boulder, not a post). Notch rocks at the top are two leaning boulders with grass between.
- **Foot:** two flanking boulders, the dirt running out into the den's apron. Five or six fallen stones on the lawn
  under shelf 1, as if the cut shed them.
- **Night:** three glow-caps on the lip and one at the turn, unlit emissive, shown only when daylight is under .4.
- **Budget:** path, wall, steps and shoulder inside the island sculpt, 6,000 added triangles at most; lip stones and
  stakes are instances (5 + 1 mesh ids).

## 5. Integration

**Pets**
- **They follow you everywhere you can walk here:** up the path, onto the terrace, into the den. The planner reads
  the beta's walk and ground patches (`CliffDenData.walk`, `ground`) when the sculpt is in; the pet floor gains the
  path and the terrace as the den gained its floor.
- **The path is transit only.** No wander, rest, focus, Dewdrop or find target on it, except the turn pocket (one rest
  spot). A pet on the path is going up or coming down behind its owner. Pets keep to the middle 3 studs.
- **Flights:** pets **hop** each step (the existing hop), about 0.25 s a step. `[check]` how a hop reads at 31 degrees.
- **Catch-up:** if the pet is more than 18 studs or 5 s behind on the path, it lands on a path safe cell 4 studs
  behind the owner, never on a flight. Ground rays start no more than 6 over the tread where rock overhangs (the den
  fix, reused).
- **Terrace:** pets wander, rest and play inside the floor less 3 studs. The Top Lawn works like any park.
- **`/tier off` and `/den off`** move pets with their owners to the same lawn spots as today.

**Finds, fruit, races:** finds: two on the terrace (lookout slab; under the tree), one at the turn pocket, none in the
den; the Paw Glade keeps (-60, -50). Dewdrop rest spots: two on the terrace, one at the turn. Garden Dash stays in the
meadow, the den gate is the sign-up, and the path and terrace are never on the Dash line.

**Day and night:** one sky, one clock, the same grade everywhere. The den is the garden's **warm landmark at night**:
lantern panes brighten from 1.0 to 1.5 emissive as daylight falls under .4. Fireflies may use the terrace at night at
`AliveBudget` 0 only. Pets' sleepy night behaviour works up top unchanged.

**Sound zones** (by camera position, eased over .6 s; music is never reverbed):
- **Den** (inside `CliffDenData.den.outline`): home music at 50%; reverb send on ambience and SFX (decay 1.6, wet -14);
  a soft room tone; water and birds -12 dB.
- **Path** (2+ over the lawn): wind bed rises with height to +4 dB at the top; water falls to -6 dB.
- **Terrace:** wind +4 dB, birds as home, water -9 dB (fountain and falls still faintly there).

**Camera**
- No scripted camera anywhere. On the path the back wall's lean and the 9-stud rule give the phone camera room.
- **The camera must never show the inside of rock or sky through a den wall.** Drawn rock that does not collide may
  not stop the default camera `[check]`; if it does not, Opus picks the mechanism. Test by orbiting at CAM-SHELF2,
  CAM-TURN, CAM-DEN-IN and CAM-DEN-BACK at 844 x 390.

**Collision and probe acceptance** (each art export, before publish)

1. Den: 470 room cells, nothing over the floor, nothing under the ceiling line; drawn shell within -0.3 / +1.0 of the
   collision wall at body height; drawn floor within 0.1.
2. Path: the centre-line walk up and down, never stuck, feet within 0.8 of the drawn tread, **also at ±2 studs either
   side of the centre**; no mesh over any tread at body height; two avatars pass on shelf 2.
3. Terrace: rim walk and jump at every lip gap and both ends, held by the walls; the drawn edge never inside the wall.
4. Pets: 10 climbs and 10 descents with one pet, 3 with three pets: pet on the terrace within 6 s of the owner, never
   off the tread, never on a lip stone, no stall over 2 s. A full play date and one fetch on the Top Lawn. Into the
   den and out 5 times.
5. `/tier off` and `/den off` with owner and pet at the turn, on a flight, on the bench, in the den: both moved.
6. Phone frame p75 at CAM-BENCH and CAM-DEN-IN no worse than the Hub's today.

## 6. Build order

Two lanes, each slice shippable on the beta behind today's switches. Code lane: A then B. Art lane: C, D, E. F last.

**Camera spots** (each PC and 844 x 390; noon unless said): **CAM-HUB** the plaza Hub looking at the hill;
**CAM-LAWN01** the r3/01 viewpoint; **CAM-MOUTH30** 30 studs south of the mouth, noon and night; **CAM-DEN-IN** in the
mouth looking in; **CAM-DEN-BACK** at the back wall looking out; **CAM-FOOT** the path's foot looking up;
**CAM-SHELF2** mid shelf 2, along the path and down at the glade; **CAM-TURN** the pocket; **CAM-ARRIVE** the first
frame through the notch; **CAM-BENCH** seated on the Top Lawn bench; **CAM-LOOKOUT** on the slab over the den.

| Slice | What | Accept when |
|---|---|---|
| **A. Pets go up** (code) | Walk patches read; pets on path, terrace, den; transit-only path; hops; catch-up; evacuation with pets. No art. | Probes 4 and 5 pass on the greybox. CAM-SHELF2: the pet is on the tread behind the owner. Clip of one climb on a phone. |
| **B. The park moves** (code + rows) | Top Lawn site spec and dressing; Paw Glade; finds and rest spots; specs rerun (`ParkSites`, `MultipleParks`, `ParkDirector`, `ParkMount`). | A play date and a fetch complete up top. CAM-BENCH: pets play against the garden. CAM-HUB: swing bar or slide roof on the skyline. CAM-SHELF2: the glade reads as a paw. CAM-LAWN01: no toys at the cliff foot. |
| **C. Den shell** (Blender, one pack version) | Shell, floor, mouth surround, lantern and crystal meshes, paw stones, apron edge. | Probe 1. CAM-DEN-IN and CAM-DEN-BACK: no seam, pane or gap in any direction; lamp pools visible; the Deck screen and the pet are the two brightest things. CAM-MOUTH30 noon: a cave in a hill, no white, no tan. Night: a warm glow, no lemon, no spill on the grass. |
| **D. Path** (Blender, island sculpt export) | Cut, bow, steps, lip stone kit, grass strip, rope, plants, foot. | Probe 2. CAM-HUB: one shadowed shelf, no dotted line. CAM-FOOT: steps and wall visible. CAM-SHELF2 and CAM-TURN: wall behind, view through lip gaps, camera clean. Width reads 6. |
| **E. Terrace** (Blender, same or next export) | Cap, face, lip, outcrops, lookout, tree, plants; greybox walls and crates removed. | Probe 3. CAM-HUB and CAM-LAWN01: no band, no box, cannot point at where the terrace starts. CAM-ARRIVE: the whole lawn and the park ahead. CAM-LOOKOUT: the garden unobstructed, the den's glow below at night. |
| **F. Sound, night, polish** (code) | Sound zones, lantern night lift, glow-caps, terrace fireflies, phone budget. | By ear at den, path and terrace on Spencer's phone. Probe 6. Night set of CAM-MOUTH30, CAM-LOOKOUT, CAM-HUB. |

If D and E share one sculpt export, do it: one collision re-probe instead of two. If time runs short, the order to
cut is F's fireflies, the path's plants, the terrace tongues. Never cut: the closed den shell, the path's back wall,
the removal of the terrace box, pets on the path.

**Each beta publish:** the slice's row in `V3-TEST-PASS.md`, translations synced, captures under `artifacts/qa-2026-11-26-beta21/`.
