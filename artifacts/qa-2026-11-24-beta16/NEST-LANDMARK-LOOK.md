# The Sleepy Nest as a landmark (Fable, 2026-11-24)

For Spencer after the beta (16) candidate: "let's make the egg nest look more substantial like the machines".

Direction only. The island session builds the mesh through the kit pipeline (as for the egg machine); Opus wires it.
Original design, hand-modelled, hand-painted. No AI art, no generated mesh.

**This reverses one of my own rulings.** `EGG-CORNER-LOOK.md` Placement rulings (R2) section 3 said "No rim, no rug, no
plinth... a nest on the floor under the tree is fine". In the captures it is not fine: next to a 7.2-stud machine the
nest is a brown ring 0.9 high that reads as set dressing. The part of that ruling that stays: the nest is **not a
station**. No attract pin, no attract ring, nothing sold, no glass, no enamel shine.

**Seen:** `r8/05-machine-close-avatar-noon.jpg`, `r8/12-machine-close-avatar-dusk.jpg`,
`r8/13-nest-pill-disc-one-prompt.jpg`, `r9/01-plaza-path-mouth-noon.jpg`; `Nest.lua`; `NestClient.lua` part list and
constants; `EGG-CORNER-LOOK.md` in full.
**Not seen:** the hatch tree's trunk position and lowest branch height, the Bear's curled size, the nest egg mesh's
triangle count, whether `Plaza_InlayStar` is flush. Those are the `[check]` items. Every position is arithmetic.

---

## 0. The idea in one line

**The machine is an egg in an egg cup with a sprout on top. The nest is an egg in a bowl with a moon beside it.**
Same cream pot, same three green feet, same leaf collar, same painted band: one potter made both. The machine is
upright, glassy, bright and symmetric. The nest is low, wide, woven, matte and lopsided, with one bent branch holding
a paper moon over the sleeper.

From the path mouth, left to right: machine (tall, bright), kiosk, nest (wide, soft, moon), care arch.

---

## 1. Size (studs; an avatar is about 5.5 tall; root-local, front is -Z, as `NestClient` today)

Root +X is the plaza's west (the machine's side), -X the east (the walk-in side).

| Part | Size | Notes |
|---|---|---|
| **Whole landmark** | **5.2 wide, 5.0 deep, 6.6 tall** | Machine: 4.2 x 3.8 x 7.2. The nest is wider and 0.6 lower, so the machine stays the tallest thing on the marble. Solid mass ends at 2.75; above that it is egg, branch and moon. |
| Feet (3) | 1.0 across, 0.35 tall | Same rounded pads as the machine, two front, one back. |
| Bowl | 4.8 across at the rim, 3.4 at the foot, 0.35 to 1.75 | A pot-bellied bowl, the machine's base cut off at the belly. Widest at the rim. Wall reads 0.2 thick. |
| Painted band | 0.35 high, round the bowl at 1.0 to 1.35 | Where the machine has its darker band. Here: 8 small crescent moons alternating with 8 dots, incised and painted. No text. |
| Leaf collar | 5.0 across, 0.5 tall, 1.55 to 2.05 | The machine's 8 scallops, bigger and **drooping over the bowl rim** instead of standing up. Tips curl out 0.2. |
| Woven nest | 4.6 across, opening 2.6, 1.75 to 2.75 | A fat twig ring sitting in the bowl like a loaf in a tin, overflowing it. Three woven bands, visibly plaited. About 24 loose twig ends stick out to 5.2 across. Geometry, not alpha cards. |
| Straw bed | 2.6 across, top at 2.2, dished 0.2 | With an egg-shaped dent, seen when empty. |
| Egg (ready size) | **1.6 wide, 2.1 tall**, base at 2.15, top at 4.25 | Today it is 1.25 x 1.63. The four looks keep their ratios, all times 1.3. Centre at 3.2: a child's eye looks slightly down at it, an adult avatar looks down into the bed. |
| Blanket, draped | covers the egg's front and sides to 45% of its height, spills 0.5 over the front rim | Its own part. |
| Blanket, folded | 1.1 x 0.8 x 0.35, on the rim at (-1.5, 2.75, -1.1) | Its own part. Shown when not tucked. |
| Crook | one bent branch: base at (+1.5, 1.75, +1.9), 0.45 thick, tapering to 0.2; apex 6.6 at (+1.2, +0.9); tip at (+1.7, 5.0, -0.3) | A shepherd's crook shape. Rises behind the nest on the west side and curls forward. Part of the body mesh. |
| Leaf awning | 3 leaves, 2.2 long each, fanning from the crook's apex over the **back half only**, 5.0 to 6.4 up, never past z = +2.5 or forward of z = +0.3 | Its own part: it sways. It frames the egg from behind; it never roofs it, so the space over the egg stays open for the pill. |
| Moon lantern | crescent 0.8 tall, 0.6 wide, 0.18 thick, on a 0.35 cord from the crook tip; centre (+1.7, 4.25, -0.3) | Its own part: it sways and glows. Beside the egg, level with its top, not over it. |
| Sign | board 1.7 x 0.85 x 0.1, centre (0, 1.15, -2.45), tilted back 10 degrees | On the bowl's front face, where the machine has its dial. Hangs from two rope loops modelled on the body. The board stays a code Part with the existing SurfaceGui (the words are translated). |
| Pet mat | round woven straw mat, radius 1.1, 0.06 thick, centre (-2.9, 0, -2.0) | Part of the body mesh, no collision. Section 5. |

Footprint radius 2.6 (twig ends), the same reach as today's fringe (2.57), so the plaza arithmetic does not move.

---

## 2. Where it stands

**(-31, -11), unchanged. No nudge.** `Nest.Facing` stays (-30, y, -4).

- Root to star middle 7.1. Radius 2.6 spans 4.5 to 9.7: clears the star (3.2) by 1.3 and the inlay ring (10.4) by 0.7.
- Neighbours, centre to centre: kiosk bench 15.1, care arch 14.6, machine at M5 16.4 (M4 14.6). Edge to edge the
  tightest is the arch at about 9.6. The 12-stud rule is centre to centre and holds.
- `Nest.Block` 4.2 to **5.6** (pets keep 3.15 off the middle). `Nest.Front` 2.6 to **3.5**.
- The sign faces the root's front. From (-20, 12) it is 18 degrees off face-on, from (-9, 21) 26, from (2.5, 21) 38.
  `SignYaw` is retired (0).
- `[check]` the hatch tree: trunk at least 3.5 from the root, lowest foliage above 8. If the crook's apex (6.6) comes
  within 1.0 of a branch, shorten the crook to 6.0 and tell me. If the trunk stands straight behind the crook from
  (-20, 12) and the two merge, mirror the crook and moon to -X and the Bear, mat and folded blanket to +X.
- `[check]` `Plaza_InlayStar` is flush. The prompt point is 3.6 from the star's middle, so a player stands on a star tip.
- Contact shadow radius 3.0 to **3.3**. Straw scatter ring moves out to **3.0 to 4.0**, same count, none on the mat or
  the prompt point.

---

## 3. Materials and colours

All matte. Nothing here is shinier than roughness 0.7. The only light is the moon.

| Part | Colour | Finish |
|---|---|---|
| Bowl | cream `#F4E8CF`, band ground `#E2D2B0` (the machine's two creams) | **Unglazed stoneware**, roughness 0.8. The machine is painted enamel at 0.6; this is the same pot left unpainted. Texture: fine speckle, a soft darker tide line near the feet, two small rim chips. |
| Band moons and dots | deep garden green `#38694A` | Incised, painted flat. |
| Feet | deep garden green `#38694A` | Matte. |
| Leaf collar, awning | leaf `#6FBF73`, underside `#4E9A5A` | Matte, painted veins. Awning leaves one step duller, `#63AD68`, so they sit back. |
| Nest twigs | `#6B4A2C`, `#5A3D24`, `#7D5A38`, shadow between `#3A2616` | Today's four nest browns. Bark grain painted in, a few pale snapped ends `#A47E50`. |
| Straw bed | `#B8974F`, highlights `#C9A560` | The cup under the machine's chute is the same straw. |
| Crook | peeled branch `#A47E50`, bark patches `#6B4A2B`, two small leaf buds | Paler than the tree's trunk so it does not merge with it. |
| Moon | paper cream `#FFF3C4`, a thin sunflower `#FFC83C` edge | By day a matte paper shape. The sunflower edge is the rhyme with the machine's dial. |
| Cord | `#8A6A3A` | |
| Blanket | soft teal `#6FB3AE` wool, quilted in 0.4 squares; every third square cream `#FFF3C4`; **one** sunflower `#FFC83C` star patch; blanket-stitch edge `#38694A` | Teal is the plaza inlay's colour, so it belongs to the marble. Lavender on teal is the strongest read on the plaza that is still quiet. Roughness 0.9. |
| Egg | lavender `#C9B4FF`, as now | Still the only lavender egg anywhere. |
| Sign board | `#A47E50`, ink `#3B2A1A` | As now. |
| Pet mat | straw `#C9A560` over `#8A6A3A`, coiled | The machine's cup weave. |

Not allowed: glass, neon by day, gold trim, any Stars colour on the body, any text but the sign.

---

## 4. What moves, and the three states

### Motion (all client-side, stops beyond 60 studs)

| Thing | Motion | Reduced motion |
|---|---|---|
| Egg breathing (napping, any look) | one breath every 4.5 s: height +2.5%, width -1%, rises 0.04. Ease in and out, a 0.6 s rest at the bottom. | Off. |
| Blanket ripple (tucked) | follows the breath 0.15 s late, scale 1.0 to 1.02, and a slow roll of the front spill, 2 degrees | Off. |
| Moon | sways 3 degrees each way at 0.25 Hz, always | Off. |
| Leaf awning | sways 2 degrees at 0.3 Hz, own phase | Off. |
| Egg looks | `small`, `glow`, `rocking`, `ready` exactly as coded today, on the bigger egg. The lean toward the Bear stays. | As today. |
| Body | never moves. | |

### The moon's glow

One PointLight in the moon. It **replaces** `EggNestLight` (move that light here; do not run two).

| When | Moon | Light |
|---|---|---|
| Day, napping or empty | matte paper, no glow | off |
| Dusk and night | Neon off; the part's colour lifts to `#FFE9A6`, a soft halo sprite 1.6 across at 40% | `#FFE9A6`, range 9, brightness 0.6. Fades in over 3 s with the lamps. |
| Ready, any hour | colour `#FFE08A`, halo 2.0 across at 60%, a slow pulse 0.5 Hz between 80% and 100% | `#FFE08A`, range 10, brightness 0.8 |

The machine's globe light is `#FFE9A6`, range 8, 0.5, dusk and night only. At dusk the two glow as a pair.

### States

| | **Empty** (no egg, or the beat after a hatch) | **Napping** | **Ready** |
|---|---|---|---|
| Egg | none; the dent shows in the straw | in the bed, breathing; look by growth | rocking as today, gold halo as today |
| Blanket | folded on the rim | not tucked: folded on the rim. Tucked: draped to 45% | draped but slipped to 20%, one corner off the rim |
| Moon | day rule or dusk rule | day rule or dusk rule | ready rule |
| Awning | sways | sways | lifts 6 degrees and holds, still swaying |
| Zzz, sparkles | none | as today | as today |
| Prompt | none | `Tuck in`, then `Peek` | `Hatch` |

- **Tuck in:** the folded blanket goes, the draped one unrolls from the front rim up over the egg in 0.6 s (scale Y
  0.2 to 1 from its lower edge), then one deeper breath. Existing tuck sound.
- **Hatch:** the blanket drops to the bed in 0.3 s before the existing hatch beat; the next egg lands untucked with the
  blanket folded.

---

## 5. Pill, "?" disc, prompt, pin, Bear

| Thing | Root-local position | Notes |
|---|---|---|
| Pill (its bottom edge) | (0, **5.2**, 0) | Over the egg, above the moon's top (4.65), in front of the awning. Fixed height: it no longer rides the egg's scale, so it does not jump between looks. |
| "?" disc | the pill's right end, as built (24 px in a 44 px hit) | Unchanged. The moon is 1.7 to the side and lower, so the disc is clear of it from the front. |
| Gift peek tile | bottom at (0, 5.6, 0) | |
| Zzz | (+0.4, 4.6, 0), drifting toward -X, away from the moon | |
| Prompt anchor | (0, 1.0, **-3.5**) | `UIOffset` (0, 72) as now. Reach 4.5 as now. |
| Show me trail end, catch-up landing | `Nest.Front` = 3.5 | |
| "Hatch!" pin (`pinReady`) | (0, **8.2**, 0), top + 1.6 | The machine's rule. Still no pin or ring in any other state. |
| Bear | `BearSpot` (**-2.9, 0, -2.0**), radius 3.5 | Was (-2.2, 0, -1.4). |

**How the Bear curls.** On the round straw mat at the bowl's front-east foot, the walk-in side, so you see pet and
egg together as you arrive. Curled with its back to the plaza and its nose toward the bowl, chin on the mat's edge
nearest the egg. The egg's existing lean points at it. The bowl is narrowest at the foot (1.7) and the twig ends
overhang to 2.6 at 2.2 up, so the Bear sleeps tucked under the eave of the nest. `[check]` the curled Bear is under
2.0 tall and 2.0 across; if it is bigger, move the spot and the mat out to radius 3.9 on the same bearing (the mat is
baked, so tell the island session before the export). The mat sits 4.8 from the star's middle at its nearest: clear.

---

## 6. Build and budget

Blender mesh, kit pipeline, hand-painted. One **512 px** texture for everything (body, leaves, moon, blanket, mat).
No alpha. No physics: every move is a tween.

| Piece | Instances | Triangles |
|---|---|---|
| Body: feet, bowl, collar, woven nest and twig ends, bed, crook, sign loops, mat | 1 MeshPart, anchored, box collision | 3,000 |
| Leaf awning | 1 MeshPart, no collision | 240 |
| Moon and cord | 1 MeshPart, no collision | 160 |
| Blanket, draped | 1 MeshPart, no collision | 420 |
| Blanket, folded | 1 MeshPart, no collision | 180 |
| Egg | today's code egg, scaled 1.3 | `[check]` its count; cap 320 |
| Sign board, prompt anchor, shadow plate, scatter | code parts as today | about 60 |
| **Total** | **5 meshes + today's code parts** | **about 4,400; hard cap 5,000** |

Retired: the 21 nest parts (`NestMound`, `NestRim*`, `NestStraw`, `NestFringe*`, `NestTuft*`, `NestSignPost`) and the
`nestTwigs`, `nestFringe`, `strawBed`, `strawWisps` textures. Kept: sign board, egg, pill, prompt, shadow, scatter.

One switch (suggest `Onboard.on("nestLandmark")`, under the ceiling): off draws today's twig nest with today's
constants, so the beta can flip back. Add its row to `V3-TEST-PASS.md` when it publishes.

**Order.** 1: Blender renders to me before any export: front, three-quarter, and the path mouth's angle, in each of
empty, tucked and ready, plus one render beside the machine at the same scale. 2: placed in Studio, static. 3: motion,
moon, states. 4: pill and prompt heights.

**Captures I need back:** noon and dusk from (2.5, 21), (-20, 12) and the hub, machine and nest in one frame; the nest
close with an avatar and the curled Bear in all three states; the pill with "?" and the `Tuck in` prompt showing
together; a phone clip of tuck-in and of one breath cycle.

## 7. Open items

- `[check]` Tree trunk and branch clearance for the crook; mirror rule if the crook merges with the trunk.
- `[check]` `Plaza_InlayStar` is flush at the prompt point.
- `[check]` Curled Bear size against the mat (1.1) and the eave (2.2).
- `[check]` The egg mesh's triangle count at 1.3 scale, and that every look still seats in the bed (base at 2.15).
- `[check]` Players can jump onto the bowl (box collision, as the machine). If standing in the nest looks bad, raise
  the collision box to 4.4 so they slide off the egg's height, and tell me.
- `[check]` The pill at a fixed 5.2 against the gift peek and the `StarsGain` float (both anchor on the egg today).
