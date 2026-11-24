# The upper tier: the new area as a level above the garden (Fable, 2026-11-24)

For Spencer, after walking the Hush greybox on beta (15): "I want the new area to be part of the same world, just
like a level above, and not as big, like a different tier to the island."

This **replaces the Hush as a separate sunken hollow** (`GARDEN-EXPANSION-LOOK.md` sections 3 to 6 and 8). The new
area becomes a terrace on top of the north-west ridge: you can see it from the plaza, you walk up to it, there is no
fade and no tunnel, and it is about a fifth of the Hush's floor. Direction only; Opus builds. Original design.

**What I read:** `GARDEN-EXPANSION-LOOK.md`, `WORLD-AND-NEST-LOOK.md`, `FABLE-REVIEW-R5.md`, `ASMR-AND-SCALE-LOOK.md`,
`HUSH-GREYBOX-BUILD-PLAN.md` (findings and the as-built section), `Hush.lua`, `HushGreybox.lua`, `HushHost.lua`
(outline), `IslandBounds.lua`, `IslandGround.lua` (the ring), `WorldV7Data.lua` (the 4-stud ground grid, the
perimeter boxes, the cave blocker), `GardenPathPlanner.lua` (how pets path), beta12 `STUDIO-PROBES.md`, and captures
r5/03 (the Sill) and r5/14 (the ridge and cave from the plaza). **Nothing here has been seen in Studio.** Heights
are from the 4-stud ground grid, so every position is good to about 4 studs. Every `[check]` is for Opus or Spencer.

**The one idea:** the hill to the left of the cave in capture 14 already has a grass top about 20 studs over the
lawn. Nobody can get up there. Level it into a terrace, put a balustrade on its edge and a path up its face, and the
island has an upstairs that everyone can see from the day they arrive.

---

## 1. Where it sits

**On the north-west ridge, directly west of the cave mouth.**

What the ground grid says about that hill:

- The cliff foot (lawn at y 4 to 5) runs south-west from the cave's west jamb: about **(-24, -92) to (-50, -62)**.
- Above it the ground jumps to y 20+ within 4 to 8 studs (a real cliff), then a broad crest at **y 22 to 28**
  running diagonally from about **(-22, -112) to (-86, -66)**: about 80 studs long and 30 to 35 wide.
- Beyond the crest the ground falls away outward to the island's edge.
- East of the cave the ridge is 24 to 29, then climbs to 45 to 50 at the aqueduct and Tumble Falls. That is the
  natural place for a third tier one day (section 3).

| | Number | Note |
|---|---|---|
| **Floor height** | **y 28**, so **24 studs above the lawn** | At 28 a flat slab clears every bump of the present crest, so the greybox needs no mesh edit. The art pass may settle at 26 to 28 `[check]`. |
| **Size** | a bean about **84 x 44 studs**, long axis along the ridge (north-east to south-west) | About 3,000 square studs after rounding the ends. The Hush floor was about 16,500; the home floor is about 40,000. So about a fifth of the Hush and 8% of home. |
| **Centre** | about **(-52, 28, -90)** `[check]` | North-east end stops at x -20, short of the cave pocket (x -14 to -2), whose roof is unmeasured. |
| **Fallback size** | a promenade about **76 x 24** | If opening the ring (below) is costly. Still enough for the lookout and one toy; I would rather have the 44. |

**Why here**

- **You see it.** From the plaza (Hub, about (-30, 4)) the tier's garden-side edge is about 85 studs away and 24
  up: about **16 degrees** above eye level, in the upper third of a phone frame without tilting the camera. From the
  arch and bridge it is about 12 degrees; from the arrival dais (about 200 studs) about 7. It is the hill on the
  left of capture 14.
- **It does not hide the sky.** The crest is already 22 to 28 there. The tier raises the skyline by 0 to 6 studs,
  plus a 3-stud balustrade and one tree. No walls. Nothing on it taller than 16 studs.
- **It is the same world.** Same sky, same sun, same day and night grade, the same music. You can stand on it and
  see the plaza, the stream, both falls and the arrival dais, and people at home can see you standing there. That
  is the strongest "there is a level above" signal we can have: other players at the rail.
- **It keeps the cave as the landmark.** The way up starts at the cave mouth, which is already the thing at the
  back of the garden that looks like it goes somewhere.
- **Nothing gameplay-placed is in the way.** No find spot, station or the Dash course is near the cliff foot or
  the crest as far as I can read `[check]` against the live find spots and the west colonnade at (-36, -25).

**The one real obstacle: the perimeter ring runs along that crest.** Its invisible boxes stand from about y 18 to
y 34 to 41 on the line (-22, -118) to (-86, -66) (about 17 boxes). At y 28 they would be an invisible wall through
the middle of the terrace. Inside the ring there is only a band about 22 studs wide. So for the 44-wide tier those
boxes must stand aside while the tier is on, and the tier brings its own outer wall, the same way the Hush handled
the cave blocker `[check]` how `LoungeWorldV7Art` names them. Off is the game as it is today.

---

## 2. How you get up

**A switchback path up the cliff face, starting beside the cave mouth. In the open, visible from the plaza.**

```
        tier (y 28)   ====================== balustrade ======
   top of leg B ->  /                                          (plan view, not to scale;
   (-26,-92) y 28  /  leg B: cut into the face, y 16 -> 28      north-east is right)
                  /________________________________
   landing (-52,-62) y 16  <-- 8 x 8 -->           \
                  \________________________________  \
                     leg A: along the cliff foot, y 4 -> 16
                                                 foot at the cave's west jamb (-22,-94) y 4
```

- **Leg A:** from the cave's west jamb, south-west along the cliff foot, rising 12.
- **Landing:** about 8 x 8 at y 16, with a low stone to sit on. A first small view.
- **Leg B:** back north-east above leg A, cut into the face, rising 12. It tops out on the tier's north-east end,
  just west of above the cave mouth. You arrive walking along the edge with the whole garden opening on your right.
- **Numbers:** 7 wide (the Hush ramp's width; home paths are 6). Each leg about **46 studs** of run. Total rise 24
  over about 92: **about 15 degrees**. The cliff foot is only about 40 long, so leg A may need to start about 6
  studs out on the lawn `[check]`. About 6 seconds to walk up.
- **Slope limits.** Avatars walk anything (the sweep notes `MaxSlopeAngle` 89), so the limit is comfort and pets:
  **15 degrees target, 18 the most**, no step over 1 stud. Draw worn stone steps if they look better, but the
  **collision is a smooth ramp** so pets and thumbsticks do not stutter.
- **Edges.** Outer edge of each leg: a kerb 1.5 high, no invisible wall. Stepping off drops you on the lawn and
  costs nothing `[check]` no fall damage. Keeping that side open also gives the phone camera room against the cliff.
  The tier's own edge does get a balustrade and an invisible wall above it, all the way round.

**What must be walkable for pets.** Today pets do not walk the mountain at all: the planner runs on the flat home
floor plus bridge decks, the pet floor test is the home Floor box (x -110 to 118, z -90 to 86), and off the grid
`World.groundY` answers 4. In the Hush greybox the pet stepped off the Sill instead of taking the ramp. So this is
the hard part, and it is what "walkable" means here:

1. Leg A, the landing, leg B and the whole tier floor inside its balustrade are pet floor, with their true heights.
2. A pet going between the lawn and the tier **takes the route**: foot, landing, top, along the centre line of each
   leg. It never cuts across the cliff face and never drops off the lip.
3. A pet may wander on the tier and on the landing, not on the legs.
4. If the pet is more than a few seconds behind its owner, the existing catch-up poof is fine. That is not a
   teleport of the player, and players already know it.
5. Other players' pets are not drawn past 72 studs, so from the plaza you see people on the tier but not their
   pets `[check]` whether to lift that for pets at the balustrade. Not for the greybox.

**The cave: retired as a passage, kept as a landmark.** I am not routing the climb through it. The pocket is about
10 x 13 with a roof nobody has measured; a 24-stud climb in there means cutting a spiral into the island mesh, and
it would hide the climb, which is the opposite of what Spencer asked for. So: the blocker stays where it is, the
Underway and its fade go, and the path starts at its jamb. Later, if probe P1 shows a real roof, the pocket can
open as a shaded nook with a bench at the foot of the path. Not part of this.

---

## 3. What is on the tier

**Mood: the quiet upstairs.** Home is marble, stations, shop, races and wide lawn. The tier is upland meadow: shorter,
paler grass, moss on grey rock, low shrubs, a little more wind, nothing sold, no stations, no prompts except the
toys. Calm, bright, open. Never spooky (the Hush's cool grade and its silence are dropped).

- **Light and sky:** home's, untouched. No per-player grade.
- **Sound:** the home music keeps playing, turned down while you are up there (about 40% `[check]` by ear on the
  phone) so the toys can be heard. More air, less water. Footsteps on short grass are soft.
- **Look** (Spencer's rule: surroundings textured, realistic and matte so pets stand out): home's cliff rock for
  the face and the retaining edge; home's grass, paler and shorter on top; moss in two greens; a broken run of
  home's marble balustrade along the garden-side edge, as if the plaza's builders once came up here. That marble is
  what makes it read as part of the same place from below.
- **One tall thing:** a single white-flowering tree at the back, about 14 studs, so its crown shows over the edge
  from the plaza. It is the "something is up there" marker by day.
- **Night:** about 8 glow-caps (the low lamp-plants from the Hush design) along the balustrade and under the tree.
  From the lawn they are a faint line of light up on the hill.

### Layout

Tier-local: **s** = studs along the ridge from the top of the path (north-east end), **t** = studs back from the
garden-side edge.

| Thing | Where (s, t) | Size | Notes |
|---|---|---|---|
| Path top | s 0 to 10, t 0 to 12 | | Where leg B arrives. |
| **The Click Walk** (keycap path) | from s 10 to s 56, curving between t 12 and t 20 | 24 keycaps, 2 abreast x 12 rows, about 46 studs | It is the tier's path, so everyone walks it once without being told. Three patches: clicky, thocky, creamy. Stone-coloured caps, soft icons, no letters. |
| **The Overlook** | s 30 to 46, t 0 to 6 | 16 x 6 | The balustrade, one bench, the view across the plaza to the falls. Nothing to do. This is the spot seen from below. |
| Clump 1 | s 44 to 62, t 8 to 30 `[check]` | about 18 wide, 10 high | Boulders and shrubs. Hides the far end from the path top, so the tier is two rooms (R5: clumps make rooms). |
| **Crunch Bed** | about (70, 14) | 12 x 8 | Crisp leaves in a rock hollow, behind clump 1. |
| **Pop Pad** | about (76, 26) | 8 x 6 | Round water-blisters on a tilted slab. |
| **Moss Beds** | about (22, 34), under the tree | 3 cushions, about 4 across | The pet nap spot. |
| Clump 2 | s 0 to 14, t 26 to 40 | about 14 wide | Screens the outer wall at the path-top end. |
| Find spots | 3 `[check]` with the finds rules | | One at the Overlook. A reason to come up for players who ignore toys. |
| Outer edge | all round the back | | Rock rising 3 to 5 studs with shrubs, an invisible wall above. No drop to look at on that side. |

No pool up here. Home has the stream and two falls, and the falls are still on the fix list.

### What pets do here

1. **Press the keys** on the Click Walk under their own feet, each a quieter, higher click.
2. **Crunch and pop:** wade the Crunch Bed, boop the Pop Pad.
3. **Moss naps** under the tree, with the kneading lead-in.
4. **Look over the edge:** a pet left near the Overlook goes to the balustrade, puts its front feet up and watches
   the garden. New, and only possible because this is a level above.
5. **Lead the way up (first time only):** the pet runs ahead to the landing, looks back, then on to the top.

Looks and sound only, as before: no Stars, XP or odds for any of it.

### The sealed doors

**Drop the two sealed throats.** They belonged to a room of doors, and the world now grows upward in the open.
**Keep the promise, as one thing:** at the tier's north-east end a worn path carries on toward the higher east
ridge (the aqueduct top, y 45 to 50) for about 6 studs and stops at a sagging rope between two stakes, the same
fete rope as the race ring. No sign, no price. Scenery only, not in the greybox, and only once Spencer has said yes
to the tier. If he wants a third tier, that is where it goes.

---

## 4. What carries over from the Hush code, and the greybox step

**Retire** (leave in the repo, switched off, until Spencer has said yes to the tier):

- The passage: the `HushPassage` remote, the doors, triggers, arrivals and landings, the fade (out, in, ground
  wait, stream wait, client timeout), the arrival offsets, the cooldown and rate limit.
- The Underway rows and the `Pocket` region; the far `Hollow` at z -226; the Sill, ramp and clumps as placed.
- `Lighting.HushGrade` and the full music duck (a part duck replaces it).
- Moving the cave blocker. It now stays put.

**Reuse**

- The gate: build flag, beta-only ceiling, ConfigService switch, the workspace attribute, off = the game as it is.
  A new key or the same one renamed is Opus's call.
- `HushGreybox`'s row builder (boxes from local coordinates, tilted slabs for ramps, the `W7H_` prefix that gives
  the camera clamp for free), with a new tier-local origin. The model stays under `EggDropLounge` so pet rays hit
  it, and Persistent.
- `Hush.onPetFloor` with a new list of boxes: the two legs, the landing, the tier.
- `IslandBounds.gone` / `regionSafe` with regions, and `PetCatchup.clear`'s extra safe ground. The tier is one
  region: its outer half is outside the ring, and its floor at y 28 is above `SafeTopY` (16), so without a region a
  player up there never gets a safe sample and anyone past the old ring is pulled home. The region's box must start
  at about y 20 so it does not swallow the lawn under the edge.
- The switch-off evacuation: with people on the tier when it turns off, put them on the lawn at the path foot.
- The host's error count and shutdown.

**New work the Hush did not need**

- Standing the crest ring boxes aside while the tier is on, and the tier's own outer wall (section 1).
- The pet route (section 2): heights for the legs and tier (today `groundY` would answer the old crest under the
  slab, or 4 off the grid), and a routed path so the pet uses the legs. This is the riskiest slice, as G1 was.
- Rerun the edge sweep and `IslandGround` once the art replaces the greybox. Check `spur_neck_west` and the cave
  jamb do not pinch the path foot.

**The greybox step (T0, about a day, beta only, behind the switch)**

- Slab(s) for the 84 x 44 bean at y 28, with a skirt down to the old ground on the outer side.
- Leg A, landing, leg B as tilted slabs 7 wide with kerbs.
- A 3-high visible lip on the garden side as the balustrade, invisible wall above; outer wall all round.
- Two clumps at the sizes above. Three flat coloured pads where the toys go. One pale pole 14 high for the tree.
- Players walk it. The pet: Opus's choice between waiting at the foot and a catch-up poof at the top; say which.
- Not in T0: art, toys, sound, the rope stub, the cave nook.

**Captures I want back:** from the Hub looking north; from the arch; from the arrival dais; from the Overlook
looking down; from the lawn at the path foot looking up; each of those at 844 x 390; a clip walking up and down on
the phone with the default camera (watch leg B against the cliff); and the answer to every `[check]`.

**Then Spencer walks it** and answers: is this the "level above" he means, is 84 x 44 right, is 24 studs high
enough to feel like a tier.

---

## 5. Budget and phone notes

- **It is always in view, so it is always drawn.** The Hush could have streamed out; this cannot. So the budget is
  smaller: **at most 8,000 triangles and 2 new textures** (upland grass or moss, the keycap), against 25,000 and 6
  for the Hush. Reuse home's cliff rock, grass and marble. Home is 115,900 triangles in 99 mesh parts today.
- **Small things hide from below.** Keycaps, leaves, blisters, cushions and glow-cap meshes cannot be seen from
  the lawn. Do not draw them past about 90 studs `[check]`.
- **Lights:** at most 4 point lights on the tier, short range, no shadows. The rest of the night glow is unlit
  emissive texture, matte by day.
- **Collision:** boxes and wedges for the terrace and path. No new mesh collision.
- **Camera on a phone:** leg B has rock on one side. Keep it 7 wide and open on the outside. `[check]` the camera
  clamp on the tier's lip from the lawn (the greeting-shot rays and the clamp read `W7` names).
- **The phone frame from the plaza:** at 844 x 390 the vertical view is short. `[check]` capture that the tier's
  edge is inside the frame from the Hub with the default camera pitch. If it is not, the tree and the upper leg of
  the path still are.
- **Text:** none in the greybox. Any later string goes through the translations steps.
- **Memory:** measure on Spencer's phone at T0 and again with art, as for the Hush. I expect it to be a non-event at
  this size `[check]`.

---

## 6. Decisions for Spencer

1. **The spot:** the hill west of the cave, 24 studs up, about 84 x 44. Yes, or somewhere else (the other
   candidate is the higher, smaller east ridge by the aqueduct, which I would keep for a third tier)?
2. **The way up:** an open switchback beside the cave, about 6 seconds of walking. The cave itself stays closed.
3. **Mood:** a quiet upland meadow under the same sky, home's music turned down. The Hush's moss, toys and nap
   spots come up with it; the sunken hollow, the pool and the silence do not.
4. **The name:** "the Hush" can stay as the tier's name, or it gets a new one.
5. **One roped path onward** as the promise of a third tier: yes, later, or never.
6. **The Hush greybox:** kept switched off in the repo until he has walked the tier, then removed.
