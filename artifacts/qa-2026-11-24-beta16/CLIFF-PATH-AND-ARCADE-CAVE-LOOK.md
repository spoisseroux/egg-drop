# The cliff path and the cave as the game den (Fable, 2026-11-24)

Spencer after beta (16): "wtf is that horrible ada compliant ramp up to the new area? i like the new area but needs to
be integrated more naturally into the landscape. Maybe theres a ramp up that cuts into the cliff to the left of the
cave? i think we should use the cave to enter the minigames? and mini game selection? itll be like the central repo for
minigame".

Direction only. Opus implements; the island session cuts the rock. Original designs. The standing look rule holds: the
world is realistic, textured and matte so the pets (and their toys) stand out.

**What I read:** `FEEDBACK.md` (beta 16); `UPPER-TIER-LOOK.md`, `UPPER-TIER-BUILD-PLAN.md` (with the as-built zigzag),
`STUDIO-CHECK-R8.md` and its R9 recheck; captures r8/07 and r9/04, 06, 06b; `Tier.lua`; the ground grid, perimeter and
cave blocker decoded from `WorldV7Data.lua`; `HollowWorldLayout` (lamps, landmarks, `groundY`); `DashCourse.lua`,
`DashHost` / `DashDirector` / `DashClient` / `DashGateSheet` headers; `ThingsPage.lua`, `Things.lua`, `things.act` /
`things.show` in `init.client.lua`; `DifficultyPicker`, `MachineHub`, `ParkLayout`, `ParkActivities`.
**Nothing here has been seen in Studio.** Positions come from the 4-stud ground grid, so they are good to about 4
studs. Every `[check]` is for Opus, the island session or Spencer.

**Why the zigzag failed (r9/06, 06b):** four straight marble ramps with kerbs on a stepped grey block, standing out on
the lawn in front of the cliff. It is a built thing placed against the mountain. Greybox colour is not the problem;
the shape is. Dressing it in rock would still read as a ramp.

---

## 1. The cliff path

**One line climbing left from the cave mouth, half cut into the face, turning once behind a rock at the hill's
shoulder, and coming up through a notch onto the far (south-west) end of the terrace.** From the plaza you see a worn
ledge rising across the cliff and people walking on it. You never see two ramps stacked.

### What the ground says

- The cliff foot runs from the cave's west jamb about (-20, -98) through (-32, -84), (-40, -74), (-48, -63), then
  bends west through (-60, -56) to (-72, -48). The face rises from 4 to 20+ within 4 to 8 studs (60 to 70 degrees).
- At the cave end the terrace's garden edge stands right on the foot (a 24-stud wall). Going south-west the hillside
  bulges out 8 to 12 studs past the terrace edge. So a line parallel to the terrace edge starts on the lawn and
  **enters the hillside on its own** as it climbs.
- The hill's south-west shoulder is soft: about (-74, -44) is 5, (-78, -48) is 13, (-78, -52) is 19, (-78, -56) is
  22. That is where a turn can hide.
- The Pet Park grove (centre (-38, -46), kerb 16 x 11) is 9+ studs from the line everywhere `[check]` with its
  1.5-stud leave margin. Ring boxes 112 to 114 (about (-89, -61) to (-88, -48)) are 6+ studs past the turn.

### The line (tier frame from `Tier.lua`: s along the ridge, t toward the garden; terrace edge is t 22)

| Point | (s, t) | World (x, z) | Height | What it is |
|---|---|---|---|---|
| **Foot** | (-28, 27) | about (-21.5, -90.5) | 4.6 | On the lawn, 5 studs left of the cave's west jamb, on the same worn-dirt apron as the cave mouth. Two boulders flank it. |
| Bank | (-28..-10, 27) | to about (-36, -80) | 4.6 to 10 | The first 18 studs sit on the lawn against the wall: a turf-and-boulder bank, not a ramp. Uses a strip about 8 x 18 of the free lawn. |
| Shelf 1 | (-10..10, 27 to 29) | to about (-51, -66) | 10 to 16 | Half cut into the face, half held by a dry-stone bank below. Bows out with the foot. |
| Steps A | at about s 10 | | +3 over 5 studs | Five worn stone steps. |
| Shelf 2 | (10..34, 29 to 27) | to about (-72, -55) | 19 to 23 | Full cut. The find spot near (-60, -50) stays on the lawn below `[check]` 4+ studs clear. |
| **The turn** | (34..40, 25 to 30) | about (-76, -52) | 23 | A flat pocket about 8 x 8 on the shoulder, hidden from the plaza by a standing rock fin (about 10 wide, top y 28) and one small tree. A low stone to sit on. First view west. |
| Steps B + notch | (40 back to 28, 26 to 22) | to about (-70, -61) | 23 to 29 | Five steps, then up between two rocks through the terrace lip. |
| **Arrival** | s 26 to 34 on the garden edge | about (-71.5, -60.6) | 29 | You come up facing north-east with the whole terrace ahead and the garden on your right. |

- **Length about 80 studs, rise 24.4: 17 degrees on average** `[check]`. Shelves at about **15 degrees**; the two
  flights are 31 degrees drawn as steps. About 5 seconds to walk.
- **Slope limits.** Avatars: anything (`MaxSlopeAngle` 89), so the limit is comfort and the camera. **Collision is a
  smooth ramp everywhere**, steps are drawn only, no riser over 0.6. Pets later (T1): one centre line with true
  heights, 18 degrees the most on shelves; they hop the flights `[check]` how a pet reads at 31 degrees for 5 studs.
- **If the flights feel wrong:** drop the terrace's south-west third 3 studs to y 26 as an arrival porch with two
  broad grass steps up to the main floor. Rise becomes 21.4, the whole path about 15.7 degrees, no flights. It also
  stops the terrace being one flat card. My fallback, not my first ask, because it changes the terrace slab.
- **Width:** 6 walking (home paths are 6; two avatars pass), opening to 8 at the turn.
- **Outer edge:** a low natural stone lip, broken and uneven, 1.2 to 1.8 high, with gaps. No rail, no kerb, no
  marble, no invisible wall. Stepping off drops you to the lawn and costs nothing `[check]` no fall damage from 23.
- **Back wall:** leaning back about 20 degrees, never more than 9 studs of bare rock in one rise (step it back with a
  grass bench and a shrub), so the phone camera has room. `[check]` the camera clamp on shelf 2 at 844 x 390.
- **Surface:** worn dirt and flat stone, the garden paths' dirt, with grass creeping in from the lip. Home's cliff
  rock for everything else. No new texture.
- **Night:** 3 glow-caps on the lip (unlit emissive), one at the turn. No lights.

### What is removed

All of the zigzag: `Tier.Legs`, `Landings`, `Top`, the supports, kerbs and dirt wedge, and the four pet blocks under
them. The balustrade gap moves from about s -29 to **s 26..34**. `Tier.Region` / `BoundsRegions` are rebuilt for the new
arrival (they are built from the old top platform). The evacuation spot (-8.3, -86.4) is now on the cave's doorstep:
move it to about (-27, -84) `[check]`. The terrace layout flips: arrival is the south-west end, so the Click Walk
runs north-east from there and the Overlook stays mid-edge.

### Mesh cut or dressed pieces?

**It needs the island export.** Two thirds of the line is inside today's rock, and the `W7C` collision tiles follow the
ground, so pieces laid on top cannot make it. Ask the island session for one sculpt covering three things together:
the path, the terrace top (R8: rock pokes through the floor in 704 cells) and the cave room (section 2). That is one
re-export of the ground grid, collision and walk data, and one rerun of the edge sweep.

- Only the first 18 studs (the bank) can be dressed pieces today.
- **Until the cut lands:** the zigzag stays, beta only, so the terrace can still be tested. Decision 2.
- Order: a grey blockout cut first (collision and shape, no texture), walk it, then the art.

---

## 2. The cave: the Play Den

**Walk in. It is a real room. Each game is an object you walk up to.** No screen pops up when you step inside. Names
to choose from: **the Play Den** (mine: short, plain, translates), Glowcap Grotto, Pocket Arcade.

It must not be a neon arcade: that breaks the matte world. It is a warm, lantern-lit rock room with wooden and stone
furniture, and the **games themselves are the bright toys** in it, the way pets are the bright thing in the garden.

### The room

- Today: the pocket is about x -14..-2, z -116..-100 (11.5 x 13), roof 11 to 14, behind the blocker at z -101. Too
  small for eight racers and a phone camera.
- **Ask the island session for about 28 wide x 19 deep:** x -22..6, z -119..-100, a low dome, **roof 16 at the middle,
  11 at the walls**. The rock allows it: 28 to 30 on top behind, the terrace (floor 29) over the west part.
- **Stay inside the ring in plan** (boxes 92 to 97 run about z -118 to -122). Going deeper passes under them and needs
  a bounds region `[check]`.
- **Mouth: 16 wide (x -15..1), 11 high, no door.** Wide and shallow on purpose: the camera sits in the mouth looking
  in, and the room is a lit stage seen from the lawn. `[check]` the camera at 844 x 390 standing at the back wall.
- Floor: packed earth and flat stones at lawn height (4.x), one round woven mat about 8 across in the middle.

### At the mouth

- **Sign:** a wooden board about 8 x 2.2 hung under the existing lintel trim (`W7_Landmarks__trim`, y 10.2), the name
  burnt into it with a small paw. One string to translate.
- **Lanterns:** two at the jambs about (-15.5, 7, -98) and (1.5, 7, -98), two inside on the back wall. Four warm point
  lights, range 14, no shadows: the whole light budget. Glow-caps along the foot of the walls.
- **Notice board** on a post just outside the right jamb, about (3, -96): a row per game and how it stands ("Race
  gathering 3 of 8"). Its prompt opens the **Things to do page**, so there is one list UI with two ways in.
- **Apron:** worn dirt from the mouth out to about z -90, shared with the path foot, joined to the nearest garden path
  `[check]` where that is.
- From the plaza at night it is a warm glow at the back of the garden. That is the landmark.

### Inside: five bays along the back wall, facing the mouth

| Bay | About (x, z) | Object | What the prompt does |
|---|---|---|---|
| 1 west | (-18, -110) | **Garden Dash gate:** a small fete arch 6 wide x 6 high with bunting (the race ring's rope language), a chalk slate of the course, eight paw stones on the floor (radius 5). | Opens today's mode picker (`DashGateSheet`: Just for Fun, Stats On, Time Trial). |
| 2 | (-12, -116) | Empty niche, a crate under a patchwork dust sheet behind a sagging rope. | None. |
| 3 centre | (-7, -117) | **Pocket Deck table:** a stump table 5 across with one oversized Deck propped on it (about 3.5 x 2.4, its screen softly lit), four log stools. | Starts a round exactly as the Deck button does (`mode`, `Board`), then the difficulty picker as today. |
| 4 | (-2, -116) | Empty niche, roped. | None. |
| 5 east | (4, -110) | Empty niche, roped. | None. |

- Bays about 7 wide, centres 7+ apart; **one prompt in reach at a time** `[check]` (the R8 116-sample probe).
- A new game takes a niche: one object, one board row, one Things row. Five bays is the cap for this room.
- Budget: objects at most 6,000 triangles in all, no new texture beyond the sign (reuse the fete bunting and wood).
- Sound: home music turned down inside (about 50% `[check]` by ear) and a soft room tone. No arcade jingles.
- Pets come in with you: the Hush's `Pocket` pet floor and blocker-off code is the reuse `[check]`.

### Garden Dash: where you sign up versus where it runs

Today: one prompt at the gate by the pad (64.5, -21) in the east meadow, 107 studs from the cave; you must stand
within 12 studs to join and 16 to stay in line. The pets race; the camera already leaves your avatar for the course.

- **The cave gate becomes the place to pick a race.** Your avatar stays in the den; the gather shot, countdown and
  race camera work as now. `[check]` (Opus): a second anchor for `JoinReach` / `QueueReach`, and where the pet waits.
- **The meadow start arch and pad stay** (the course starts there, and a race in the open is the best advert). Its
  prompt becomes **"Join race" only while a race is gathering**: hop in, no picker. Choosing a mode is the den's job.
- For one beta build keep the full picker at both, so nothing is lost if the cave anchor misbehaves.

### Pocket Deck

Keep the **Deck button**. The Deck is the handheld; playing it anywhere is the point, and onboarding leans on it.
The table is a second, physical way in for people who come to the den.

### Entries elsewhere

- **Things to do** stays as the list you carry. Add a first row for the den (Show me: prints to the mouth). The Dash
  row's Show me leads to the den, or to the start arch while a race is gathering. The Deck row's Play is unchanged.
- Pet Park and finds are places, not games: unchanged, not in the den.
- Tips and How it works lines that send players to the meadow for Dash need new copy, through the translation steps.

### Steps

1. **A0 (Opus, no mesh, behind a switch, beta):** open today's pocket (blocker off, pet floor, bounds), a grey sign,
   two lanterns, a grey Dash gate and Deck table squeezed in, the cave Dash anchor. Spencer walks it for the idea.
   Probes: the real roof height, the phone camera inside, prompts.
2. **A1 (island session):** the room, mouth and apron, in the same export as the path and terrace.
3. **A2:** the art objects from my brief, the board, lights, sound. I review renders, then Studio captures.

**Captures I want back:** the mouth from the Hub and from 30 studs, noon and night; inside from the mouth and from
the back wall, PC and 844 x 390; the path from the Hub, from its foot, on shelf 2 and at the turn; a phone clip
walking up and down.

---

## 3. Decisions for Spencer

1. **The path:** one ledge rising left from the cave, one hidden turn, arriving at the terrace's far end. Yes?
2. **Meanwhile:** keep the zigzag on the beta until the rock is cut (my pick), or close the terrace until then?
3. **Steps or porch:** two short step flights (my pick), or drop the terrace's arrival end 3 studs for a gentler walk?
4. **The den is a walk-in room with an object per game**, not a menu on entry. Yes?
5. **Enlarge the cave** to about 28 x 19 with a 16-wide mouth, or start with the small pocket as it is (step A0 only)?
6. **Name:** the Play Den, Glowcap Grotto, or Pocket Arcade.
7. **Garden Dash:** pick the race in the den; the meadow start keeps only "Join race" while one is gathering. Or
   remove the meadow prompt entirely?
8. **The Deck button stays** in the HUD, with the den table as a second way in. Or den only?
9. **Things to do** stays as the carried list and points to the den. Yes?
