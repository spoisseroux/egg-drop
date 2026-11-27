# Garden brief for beta 38 (Fable, 2026-11-27)

Answers Spencer's beta 37 notes 12, 13, 15 and 16 (`FEEDBACK.md`, `shot-64-stars.png`). Look and feel only; Opus builds.
Every number is a starting value to tune in Studio. All art is our own: painted textures and Blender meshes from our
scripts, nothing generated, nothing copied. Animal Crossing is the mechanic reference (shake a tree, fruit in the
canopy, a patterned ball), never the look.

Rule that runs through all four: the world stays matte, textured and believable; the toys (balls, fruit) may be bright
because the player touches them; the pets stay the cutest thing on screen.

| # | Item | Priority |
|---|---|---|
| 1 | Three plain balls get patterns (geometry now) | P1 |
| 1b | The same three as painted 256 px textures on our own sphere mesh | P2 |
| 2 | Balloons: seven, three depths, the hub cleared | P1 |
| 3a | Fruit seated in the canopy, five a tree, three varieties | P1 |
| 3b | "Shake" prompt, trunk rock, leaves, drops, "nothing" outcomes | P1 |
| 3c | Buds growing back, the creature surprises | P2 |
| 4a | Trees scaled up in three grades | P1 |
| 4b | Understory: bushes, tall grass, reeds, flower clumps, ferns | P1 for bushes and reeds, P2 for the rest |

---

## 1. Balls (note 12)

Read: `BumbleBallLook.lua`. Patch (six round panels) and Stripe (crossed bands, capped) read as toys. The three older
ones do not: `artifacts/qa-2026-11-26-beta34/studio-b35/04-ball-felt.jpg` shows Felt as a rust knitted lump with one
thin seam. All three are a single brown-family body with one or two thin bands:

| Ball | Today | Why it is plain |
|---|---|---|
| felt | coral Fabric, one .12 cream band | one colour, the band is a hairline; reads as a ball of yarn |
| wicker | tan WoodPlanks, two brown bands | brown on brown, no shape to follow as it rolls |
| cork | brown Cardboard, one brass band | brown again; three of five balls are tan or brown on a green lawn |

Keep the ids, homes, feel and network records exactly as they are. Only `Look.Kinds` changes. Keep every surface matte
(Fabric, Rubber, SmoothPlastic; no Neon, no gloss).

### P1: built geometry, with the band and disc system that already exists

**felt becomes a patchwork felt ball ("Patches of felt").** Body cream `#F4E8CF`, Fabric. Three meridian bands, each
`width=.9`, `across=2.42`, turned 0, 60 and 120 degrees about the vertical axis, coloured coral `#E8785A`, teal
`#7FB8A4`, mustard `#F2C14E` (Fabric). Where they cross at the two poles, a cream cap disc `.06 x .8`, proud `.04`, so
the crossing is tidy (Stripe's trick). Reads as a six-segment plush ball: cream, coral, cream, teal, cream, mustard.
Needs `turn` to accept any angle (today only `QUARTER` is used; the maths already takes a CFrame). 6 parts.

**wicker becomes a polka-dot ball ("Dot").** Body mustard `#F2C14E`, Rubber. Fourteen cream `#F4E8CF` discs: six on
the axes (as Patch) at `.06 x .8`, and eight on the cube corners (axis = `Vector3.new(±1,±1,±1).Unit`) at `.06 x .6`,
proud `.02`, SmoothPlastic. Any view shows five to seven dots, and they tumble clearly when it rolls. 15 parts.
`discFrame` already handles any axis.

**cork becomes a ringed ball ("Hoop").** Body deep teal `#3E8E86`, Rubber. Three parallel cream rings about one axis:
`offset=-.62, 0, .62`, widths `.14, .3, .14` (the existing band maths sizes each to the section). Two coral `#E8785A`
pole discs `.06 x .7`. Reads like a spinning top toy: the rings wobble as it rolls, which is the most fun of the three
in motion. 6 parts.

Total parts go from 4 + 3 + 2 to 6 + 15 + 6. All anchored, no collide, no shadows, already culled at 90 / 150 studs.

Colour check: the five balls are now cream-patchwork, mustard-dot, teal-hoop, cream six-panel (Patch) and sky-banded
(Stripe). Patch and felt are both cream-bodied: move Patch's body to soft white `#FBF6EA` and keep its three panel
colours, or swap felt's body to pale sky `#CFE6F2`. I prefer the second.

### P2: painted textures (the "Animal Crossing texture" finish)

Geometry bands cannot make stars, stitching or alternating segment colours. For those we need the mesh the Look file
already promises: one of our own UV spheres (about 300 triangles, made by a Blender script, pole-pinch hidden under a
cap) and one 256 px albedo per ball, painted by hand in our palette, matte roughness, no normal map.

- felt: true beach-ball segments in felt, six alternating colours, with a cream blanket-stitch line painted along each
  seam and a button cap at each pole.
- wicker: mustard with cream five-point stars of two sizes (stars are not possible with Parts).
- cork: teal with cream rings and a zigzag stitch between them.
- Later, a sixth ball only if wanted: navy with a ring of small cream moons.

The squash already works on a mesh body. Note the runtime rule from memory: no SurfaceAppearance parented at runtime;
use a MeshPart with `TextureID` in a prebuilt pack. P2 because P1 already fixes "boring".

---

## 2. Hot-air balloons (note 13)

Read: `DriftLanterns.lua`. Today nine balloons sit in three tight clusters (hub, bridge, fountain), all between 15 and
21.4 studs over the ground, all the same size, each drifting on a 1.5 stud circle. Tree crowns top out about 10 to 13
studs over the ground, so every balloon hangs just above the treeline in one flat layer, and three of them sit over
the hub. In `shot-64-stars.png` three overlap in one patch of sky. That is the crowding.

Change to **seven balloons in three depths**, and **nothing over the hub paving**.

| id | Layer | x, z (target) | Over ground | Scale | Mascot | Notes |
|---|---|---|---|---|---|---|
| low_knoll | low | -27, 20.3 | 14 | 1.0 | yes | the old hub_3 spot by the knoll stairs, off the paving |
| low_fountain | low | 47, 13 | 14 | 1.0 | yes | the old fountain_1 spot |
| mid_stream | mid | 14, 31 | 30 | 1.25 | no | over the stream, the old bridge_3 spot, raised |
| mid_west | mid | -58, 40 | 36 | 1.25 | no | over the west lawn |
| mid_east | mid | 86, -6 | 42 | 1.25 | no | east lawn, between the two east crowns |
| high_north | high | -20, -95 | 75 | 1.8 | no | out past the north rim, behind the hatch tree's skyline |
| high_falls | high | 112, -50 | 100 | 1.8 | no | beyond the falls, well above the cliff top |

- The two low ones are the only ones a player walks under; they carry the mascots (set `Mascot.count=2`). They stay at
  `MascotOver=14` so the pet reads from the ground.
- Mid balloons are over every crown, so the crown keep-out only matters for the low two. Keep `GardenClearance` for the
  low two; for mid and high, only the rule "not over the hub paving, not within 20 of the hatch tree".
- High balloons sit outside the walkable island. They are skyline: no mascot, no light, no sound, no burn lift needed
  (keep the flame flicker at night; it is the nicest part of dusk). Scale 1.8 so they still read as balloons, not dots.
- Raise `MaxOver` to 100. The spec's spots check needs the new layers.
- The accents stay three (coral, teal, mustard); never two of the same accent in neighbouring spots. Give the high two
  a slightly greyer envelope (`#EDE6D6`) so distance reads as haze.

**Drift, per layer** (today: radius 1.5, period 40 s, about .24 studs/s for all):

| Layer | Drift radius | Period | Speed | Bob | Sway |
|---|---|---|---|---|---|
| low | 2 | 50 s | .25 studs/s | .6 over 7 s | 2.5 degrees |
| mid | 6 | 85 s | .45 studs/s | .9 over 9 s | 2 degrees |
| high | 14 | 160 s | .55 studs/s | 1.5 over 13 s | 1 degree |

Far things should look slower even when they move further: these do. Each keeps its own phase.

**Budget.** 7 x 13 = 91 parts (was 117) and two mascot rigs (was three). The cull is 90 studs on phones, which would
hide the high pair exactly when they matter. Exempt the high layer from the distance cull and step it at 1/10 s with
no lights, or, cheaper, draw the high pair as a 5-part balloon (envelope, one gore ring, skirt, basket, flame).
Sound is the other engineer's; only the low and mid balloons should ever make any.

P1. The seed fluff emitter over the hub stays.

---

## 3. Fruit in the trees and the shake (note 15)

Read: `GardenFruit.lua`, `LifeSim.lua` (`Sim.Fruit`). Fruit already hangs: three slots a tree, 80% filled, **under**
the crown's skirt on a stem, and a tree shakes when you run into its trunk above 4 studs/s. Both are easy to miss:
fruit under the skirt sits in the crown's own shade, and nothing tells a kid a tree can be shaken. Spencer played the
build and saw neither.

The fruit trees are the eight blossom crowns (seven around the island and Blossom Point). The Heart XP rules do not
change: 2 Heart XP, one paid fruit a minute, twelve a day, then the pet still eats happily. No Stars, no counter.

### 3a. Fruit in the canopy (P1)

- **How many:** five slots a tree (from three), all full when grown. Blossom Point (scale 1.7): seven.
- **Where:** two keep hanging under the skirt. Three sit **on the outer face** of the crown, between 15 and 40
  degrees below its widest line, spread round it so two or three face any camera. This reverses FABLE-REVIEW-R5 point
  3 ("never a side face"); the sticker problem then was a flat fruit. Fix it by seating each one: the fruit sunk 35%
  into the leaves, a darker leaf-green shadow disc behind it (`#2F6B34`, matte), and a two-leaf sprig over its top.
- **Size:** body 1.15 studs in the tree (the ground fruit is .9). It drops at 1.15 and settles to .9 on its first
  bounce, so it never looks oversized next to a pet. At player scale .8 a 1.15 fruit is about a head wide: readable from
  40 studs.
- **Colours, three varieties, one a tree** (look only; rules identical):
  - Sunset: body `#FF8A4C`, blush `#FFD166` (today's fruit). Trees 05, 10, 17.
  - Berry: body `#E8456B`, blush `#FF9DB5`. Trees 07, 14, 21.
  - Honey pear: body `#F2C14E`, blush `#FFF0B0`, slightly taller (1 x 1.2). Tree 19.
  - Blossom Point: golden `#FFC83D` with a pale blush, the only tree with seven.
  All warm, against lime-green blossom crowns. No green or blue fruit. SmoothPlastic, matte, stem and leaf as now.
- **Sway:** each fruit a small pendulum from its stem, 3 degrees at rest on its own 2.2 to 3 s period, up to 10 in a
  gust, and it rides the crown's sway. The seated three sway half as much. Reduced Motion: still.
- **Growing back (P2):** after a drop, the slot shows nothing for 60 s (as now), then a small green bud (`#9CCB5A`,
  .35 studs) that swells and warms to the fruit's colour over the 20 s grow. A kid can see "not ready yet".

### 3b. The shake (P1)

- **The prompt.** Within 6 studs of a fruit tree's trunk a soft pill appears at trunk height, in the Guide bubble's
  style: a little tree icon and **"Shake"**. Keyboard E, gamepad X, tap the pill, or click / tap the trunk. It shows
  only when a shake is allowed for me (the 75 s per-tree gap), so it never offers a dead button. While the tree is
  resting, the pill is replaced by nothing; the buds tell the story.
- **Keep the bump.** Running into the trunk still shakes it. The prompt is the discoverable way, the bump is the
  delightful accident.
- **The avatar.** Turns to the trunk, both hands out, two quick pushes (.5 s). The pet hops back half a stud and
  looks up.
- **The tree.** The whole tree rocks, trunk included, from the roots: 5 degrees at the trunk, 8 at the crown, three
  swings in .7 s, easing out (today the crown alone rocks 6). The crown squashes 4% on each swing. Hanging fruit swing
  wide (25 degrees) on the first swing before any lets go.
- **Leaves.** 12 leaf cards (from 8) in the crown's two greens, fluttering down over 1.5 s, two or three landing on
  the grass for 4 s before fading.
- **What falls.** With fruit on the tree: one fruit drops on the second swing, and one time in four a second fruit
  drops .3 s later (a second fruit is only a second thing for the pet to eat; the paid-fruit cap already covers it).
  Each lands with a squash, two small bounces and rolls up to 2 studs. The pet runs to it and eats it in five bites as
  now.
- **Sometimes nothing.** A tree with no ripe fruit still shakes: leaves fall, and that is all. About one such shake in
  five gets a cosmetic surprise instead (P2): two butterflies burst out of the crown, or a small bird leaves with a
  chirp, or one extra-large leaf drifts down and the pet pounces on it. Never Stars, never an item, never XP.
- **Sound.** A new `tree_shake` take: we record a leafy branch being shaken (two takes, original). Layer: the shake
  (.6), two `asmr_flake` rustles as now, a soft wooden creak pitched low, then per fruit a short stem "pluck" and the
  `land` thud at .4. An empty shake ends on the rustle alone, slightly lower in pitch, so "nothing" sounds different
  from "something". The pet's bites, gulp and happy squeak as now.
- **Haptics.** `settle` on the shake as now; add a light tick on each fruit landing.
- **Onboarding hook.** The first time a player stands near a fruit tree with their pet, the Guide points at it once:
  "Shake the tree!" (a new UICopy line, so it goes through the translation sync).

Server: the claim rules, the 75 s gap, reach and window are unchanged; a prompt shake is the same message as a bump.

---

## 4. Trees and vegetation (note 16)

**Yes, bigger, but not all by the same amount.** The player is drawn at .8 (about 4.2 studs tall) and garden pets at
.72. Crowns top out 10 to 13 studs over the ground and are 6 to 10 across, so a tree is about two and a half players
tall and the garden reads as a lawn with saplings on it. `shot-64-stars.png` shows it: wide flat green, a few lollipop
trees, the skyline carried by the pavilions. Scaling everything equally would keep the same flat rhythm, only larger.

### 4a. Three grades (P1)

| Trees | Scale on trunk and crown | Result |
|---|---|---|
| Round and tall crowns (12 trees) | x 1.35, crowns x 1.45 wide | shade trees, 14 to 17 studs tall, real canopy overhead |
| Blossom fruit trees (7) | x 1.15 | stay the short, friendly trees; the fruit stays close to eye level and in frame |
| Hatch tree, Blossom Point | unchanged | already the landmarks (25 wide; scale 1.7) |

Make three of the outer round trees (01, 13, 20) x 1.6 so the edge of the island has a taller silhouette than the
middle. Vary by plus or minus 5% so no two match.

Things that move with the scale, for Opus: `WorldAeroKit` crown pivots and scales (the generator), `GardenKeepOut`
trunk radius, `GardenFruit.Trunk`, `DriftLanterns.Crowns` (only the two low balloons care now), ground litter plates
under each tree (5 to 6.5 across), fruit slot maths, and the crown-clip check from the beta 12 note (a player must not
walk into a solid crown: bigger crowns start higher, which helps). No new triangles: same meshes, scaled.

### 4b. More plants (bushes and reeds P1, the rest P2)

Yes. The garden has trees and ground plates and almost nothing in between, so there is no middle layer for a small pet
to walk behind, sniff or pop out of. Add an understory, clustered, never sprinkled evenly:

| Plant | Where | Count | Triangles each | Look |
|---|---|---|---|---|
| Round bushes, two sizes (2.5 and 4 across, 1.5 to 2.5 tall) | in threes at fence corners, the pavilion backs, the foot of the knoll steps, path forks | 24 | 120 | leaf-cluster shells like the crowns, darker green than the lawn, matte |
| Flowering bush (the same mesh, a blossom texture) | either side of the hub's benches, the fountain lawn | 8 | 120 | small cream and coral flowers, never neon |
| Reeds and rushes | both stream banks, the pool under the falls, the fountain basin's lawn side | 14 clumps | 36 | tall thin blades with two cattail heads a clump, sway in the wind |
| Tall grass tufts | round every trunk, along fences and the cliff foot, the lawn's edges | 60 | 12 (three crossed cards) | uneven blades, lighter tips; a pet walking through makes them part |
| Flower clumps | drifts of five to nine on the open lawns, away from the Dash line and ball homes | 30 | 40 | 3D stems and heads replacing some of the flat flower dots |
| Ferns | the shaded side of the big trees and the cliff den mouth | 16 | 48 | low rosettes |

- Budget: about 152 instances, five shared meshes, roughly 7,000 triangles. The Aero kit is 3,952 today, so the garden
  stays near 11,000 for all vegetation. All anchored, CanCollide / CanQuery / CanTouch off, CastShadow off (a blob
  decal under bushes only), one 256 px atlas for all five. On phones cull tufts, flowers and ferns past 60 studs and
  halve them at budget level 1; bushes and reeds always draw.
- Keep-outs: the paths, the Dash course, ball homes and leash circles, the nest, find spots, stations (reuse
  `GroundDressing.Keep`). Bushes are see-over height for a .8 player (2.5 at most) so no one loses their pet.
- Motion: reeds and tufts lean with `Wind` gusts (the existing wind); bushes shiver on a strong gust only.
- Taste: every plant matte and textured (leaf clusters, blade cards with painted variation). Nothing rounded-glossy or
  candy coloured; that is the pets' job.

A good later beat (P2, after this lands): a pet now and then disappears into a bush and comes out with a leaf on its
head.

---

## Order for beta 38

1. Balloons re-layout (data only, fastest visible win).
2. Tree grades (generator rerun, then the dependants).
3. Ball looks, geometry.
4. Fruit in the canopy, then the Shake prompt.
5. Bushes and reeds.

Each lands behind its existing Alive switch (`air`, `balls`, `fruit`, `scene`) and gets a row in `V3-TEST-PASS.md`.
I review renders of each from Spencer's angle in `shot-64-stars.png` before it goes to the beta.
