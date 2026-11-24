# The upper tier, greybox T0: build plan (Opus, 2026-11-24)

Spencer, after beta (15): "I want the new area to be part of the same world, just like a level above, and not as big,
like a different tier to the island." Fable's re-scope: `UPPER-TIER-LOOK.md` (read in full). This plans **T0 only**:
an untextured walkable terrace on the north-west ridge and an open switchback up to it, **players only**, beta place
only, behind a build ceiling, a ConfigService switch and an owner chat command. Off = the game as it is today.

Step 1 of a review-driven build: plan only, no src changes in this commit. Worktree reset onto feat `efc846c`.

**What I read:** `UPPER-TIER-LOOK.md`; `HUSH-GREYBOX-BUILD-PLAN.md` (with the architect, code review and R5 sections);
`Hush.lua`, `HushGreybox.lua`, `HushHost.lua`, `HushConfig.lua`, `HushClient.lua` as merged; `IslandBounds.lua`,
`IslandBoundsHost.lua`; `init.server.lua` (`petAnchor`, `groundAnchor`, `validWander`, `validFocus`,
`resolveGardenTarget`, `catchupLanding`, the garden scene's wet/blocked watcher); `GardenWalkability`;
`GardenPathPlanner`; `WorldV7Data` (decoded: the ground grid, the perimeter boxes); `FindSpots`. Every number below
was measured on the 4-stud ground grid with throwaway scripts; **nothing has been seen in Studio.** The numbers are
starting values: `Tier.spec` (section 7) holds the rules they must meet, so a probe that moves one is a data edit.

---

## 1. What the data says (and where it differs from the look doc)

1. **The crest is narrow.** Between the cliff top (ground about 20) and the outer fall, the crest band at y 20 to 28 is
   about **22 to 26 studs wide**. A 44-wide slab at y 28 on Fable's centre (-52, -90) hangs about 8 studs over the
   lawn on the garden side (the garden-edge corners read ground 4) and its outer half sits over the island's outer
   slope.
2. **What fits.** I searched centres, lengths and widths with three rules: the garden edge stands on the crest
   (ground 14+ under it, so the retaining face rises from the cliff top, not the lawn), the slab at y 28 clears the
   crest (no ground over 29 under it), and nothing reaches over the cave pocket (x > -16, z < -97). Results:
   - **76 x 44, centre (-60, 28, -96)**, long axis along the ridge (direction (-0.812, 0.584)): fits; the outer edge
     is over ground about -4 to +3 (the island's outer slope, outside the ring). **My proposal.** 3,344 square studs.
   - 84 x 44 fits only at x -64 and beyond, with the outer edge over the void past the island's edge.
   - Inside the ring with the outer edge over real ground: 84 x 24 (Fable's fallback promenade).
   - Corners of the proposal: garden side NE (-16.3, -100.3), SW (-78.0, -56.0); outer side NE (-42.0, -136.0),
     SW (-103.7, -91.7). The NE garden corner stands above the cave mouth's west jamb, as the look doc wants.
3. **The crest is not flat.** Bumps reach 28.3 at about (-66, -76) and 29+ just behind the cave. The slab at **y 28**
   leaves bumps of up to 1 stud poking through (the W7C collision tiles follow the ground). Either the floor goes to
   **29** or we accept a few low bumps in the greybox `[probe T-P1]`. Question 6.
4. **Leg B cannot be "cut into the face".** The cliff rises 4 to 20 within 4 to 8 studs. A ramp at y 16 to 28 eight
   studs into the face would run inside the rock (and inside the W7C collision). So the switchback is **two legs side
   by side on the lawn at the cliff foot**: leg B (the upper one) against the face, leg A (the lower one) outside it.
   Same 46-ish run, same 15 degrees, same landing; you see both from the plaza.
5. **The perimeter ring runs along the crest** (y about 17 to 40), box 103 at (-50, -92) right through the middle of
   the terrace. For the proposed footprint grown 1 stud, the boxes that meet it are **98 to 111** (14 boxes); the
   neighbours left standing, **97** and **112**, are about 6 studs past the tier's ends. Confirmed in `WorldV7Data.perimeter`; `LoungeWorldV7Art` makes them as
   `EggDropLounge.PerimeterWall.Wall<i>` (players only, `CanQuery` false).
6. **Pets cannot walk the mountain** (look doc, confirmed): the planner is the flat home floor plus bridge decks; the
   pet floor test is the home Floor box (z -90 to 86); `World.groundY` reads the crest under the slab or 4 off the
   grid. Worse, today a pet would follow its owner **up**: an owner on the tier's south part is inside the home Floor
   box in plan, the anchor ray hits the slab at 28, and `GardenLayout.onGround` passes where the crest grid reads
   27.5+. The pet would then float up the cliff on a straight line. T0 must stop that, not just leave it alone.
7. **Nothing gameplay-placed is in the way.** Nearest find spot to the landing about 9 studs ((-60, -50)); the Dash
   course 100+ studs away; the nest (-17.5, -2.5), the stations and the colonnade (-36, -25) clear; no `IslandBounds`
   wall near (the nearest, `west_ramp`, about 30 studs from the landing).

---

## 2. Geometry (T0)

Tier-local frame: **s** along the ridge (NE end s -38, SW end s +38), **t** toward the garden (garden edge t +22,
outer edge t -22), **h** = world y. Centre (-60, -96). Path frame: from **F0 (-24, -93)** (the cliff foot at the cave's
west jamb) along **a (-0.685, 0.728)** (south-west along the foot), **out (0.728, 0.685)** toward the garden.

| Piece | Where | Size | Notes |
|---|---|---|---|
| **Tier slab** | s -38..38, t -22..22, top y 28 | 76 x 44, 2 thick | `W7T_Floor`. Corners chamfered 6 so it reads as a bean, not a card. |
| Retaining face (garden side) | t +22, y 14..28 | 76 long | Visible skirt down to the cliff top. |
| Outer skirt | t -22 and the two ends, y 0..28 | | Seen only from outside the island. |
| **Balustrade** | garden edge, h 28..31 | 1 thick | Visible lip; **invisible wall** above to y 40 (players only). Gap for the top platform. |
| Outer wall | outer edge and both ends, y 28..33 visible rock rim, invisible to y 40 | | The tier's own wall, replacing the ring boxes that stand aside. |
| **Top platform** | from leg B's top (-18.5, -87.9) back 9 studs to the garden edge at about s -29 | 7 x 9, top y 28 | Bridges the retaining face. A balustrade gap opens onto it. |
| **Leg B** (upper) | centre line 7.5 out from the foot, from the landing (-48.7, -55.8) y 16 up NE to (-18.5, -87.9) y 28 | 44 run x 7 wide, 15.3 degrees | Against the face. Measured clearance between its surface and the ground under it: 5.4 studs or more. Kerb 1.5 high on its outer (garden) edge. |
| **Landing** | centre (-48.5, -50.2), y 16 | 8 along x 16 across | Spans both legs' SW ends. One low stone block to sit on. Kerb on its outer sides. |
| **Leg A** (lower) | centre line 15.5 out, from the foot (-12.7, -82.4) y 4.6 up SW to the landing end (-42.9, -50.4) y 16 | 44 run x 7 wide, about 14.6 to 15.3 degrees | On the lawn. Kerb on its outer edge; the inner edge meets leg B's kerb. |
| Supports | under each leg and the landing | stepped boxes, 4 per leg | So nobody walks under a ramp. The walk surface is the smooth tilted slab (the Hush ramp's slab method, spec'd by its two end points). |
| Clumps | (s 6..24, t -8..14), (s -36..-22, t -20..-6) | about 18 and 14 wide, 10 high | Fable's clump 1 and 2. |
| Toy pads | Crunch (s 32, t 8), Pop (s 36, t -4), Moss (s -16, t -12) | flat coloured plates | No collision change; markers only. |
| Tree pole | (s -10, t -14) | 2 x 14 high | The "something is up there" marker. |

About **45 parts**, no meshes, no textures, a few hundred triangles. Names `W7T_*`: the camera clamp takes any name
starting "W7", so no change to `CameraClamp`. Matte SmoothPlastic greys as in the Hush greybox. Built under
`EggDropLounge.Tier` (the pet rays are `Include {EggDropLounge}`), `ModelStreamingMode` Persistent, every part
`WorldMesh` (bounds scans skip it; rays still hit it), `CanTouch` false.

**Pet-blocked footprints** (new, T0's pet rule): four invisible boxes at lawn height under leg A, leg B, the landing
and the top platform, with `GardenBlockedRegion = true` set before they are parented, in `EggDropLounge.PetRegions`.
The garden scene's watcher adds them on the beta and in Studio (its `PetCatchup` / onboarding ceiling); destroyed
ones are skipped by `GardenWalkability` (`if not water.Parent`).

---

## 3. Pets in T0: they wait at the foot

Cheapest and safe. Three pieces, all already proven code paths:

1. **`Tier.covers(position, open)`** (pure): inside any tier footprint (slab, top platform, legs, landing; plan boxes,
   turned). The three pet floor checks become `Hush.onPetFloor(floor, p, hushOpen) and not Tier.covers(p, tierOpen)`.
   Closed (`open ~= true`) it answers false, so the line is today's exactly. An owner anywhere on the path or tier
   gives no new anchor; `groundAnchor` keeps the last lawn spot by the foot, and the pet waits there (the same thing
   that happens when you stand on a bench today).
2. **The blocked footprints** keep pet paths, wanders and catch-up landings off the lawn under the legs: a pet never
   walks under a ramp and gets ground-snapped onto it, and `resolveGardenTarget` refuses a landing there.
3. Nothing else: no carry, no hop. When the owner comes down, the next lawn anchor resumes the follow.

The catch-up "far" clock measures the pet against `input.anchor` (the waiting spot), not the owner, so it does not
fire while the owner is up top. `[probe T-P5]` the leash with the owner 30+ studs above.

The pet route (true heights for legs and tier, a routed path, pet floors up top) is its own later slice (T1), as the
look doc says.

---

## 4. The ring, the bounds and the switch-off

- **Stand aside.** `Tier.RingAside` = the perimeter indices whose box meets the tier footprint grown 1 stud, computed
  from `WorldV7Data.perimeter` at require (today 98 to 111; the spec proves the list is exactly those). While open,
  `TierHost` sets their `CanCollide` false (keeping what each had, to put back); closed, it puts them back. A
  missing `PerimeterWall` folder or box, or a missing tier-adjacent box, keeps the tier **closed with one warning**
  (the CaveBlocker rule).
- **The tier's own wall** stands where the ring was: outer edge and both ends, invisible to y 40, plus two **end
  closers** (invisible, y 17 to 40) from each end wall's outer corner to the standing neighbour (97 at the NE end,
  112 at the SW end; about 6 studs each), so there is no gap on the crest beyond the tier's ends. The spec checks
  each closer meets its neighbour box within half a stud, so the island's edge is closed while the tier is open.
- **Island bounds.** One region, `Tier.BoundsRegions = {min, max, fallY}`, the axis-aligned box round the slab, the top
  platform and the top of leg B, from **y 20** up (so it never swallows the lawn or leg A). Inside it a root is gone
  only below 20; the outer half of the tier is past the ring, so without it anyone up there would be pulled home.
  **No safe samples up there** (no `safe` function): a later fall returns you to your last lawn spot, which is where
  you want to be. `IslandBoundsHost` needs **no change** (its regions dep already exists); init's `regions` returns
  the tier's list while `tierHost.open`.
- **Switch off with people up there.** `TierHost:close()`: everyone whose root is on a footprint above it (`Tier.onIt`:
  on a leg or the landing more than 2.5 studs over the lawn, or in the tier region) is moved to the lawn by the foot
  (**(-8.6, 4.6, -86.8)**, inside the home Floor, facing the plaza; offsets for several), with `arrived(player, spot)`.
  Pets are already on the lawn (section 3). Only then: `open` false, ring boxes back, model and blocked boxes
  destroyed. Held players (deck round, seated) are moved too: their ground is about to go.
- **Errors**: the HushHost pattern (protected heartbeat, count without reset, at 3 the host closes as above).
- **The cave**: untouched. The blocker stays exactly as today. No remote, no fade, no client module in T0.

---

## 5. Retired vs reused

| From the Hush code | T0 |
|---|---|
| Gate pattern (flag, beta + Studio ceiling, ConfigService publisher, attribute, owner chat) | **Reused** as `Tier` / `TierConfig`. |
| `HushGreybox` row shapes (`span`, tilted slab, `slant`, invisible, light fixture) | **Reused**: I move the row helpers into a small shared `GreyboxRows.lua` (local frame in, rows out) used by both; `HushGreybox` keeps its rows exactly (its spec still passes). |
| `HushHost.build` (rows to parts) | **Reused**: moved to `GreyboxRows.build(rows, name)`; HushHost calls it. |
| `Hush.onPetFloor` | **Reused** unchanged; `Tier.covers` is chained after it. |
| `IslandBounds` regions, `IslandBoundsHost.arrived` | **Reused**, no change. |
| Evacuation and the 3-error shutdown | **Reused** pattern in `TierHost`. |
| Passage (remote, doors, fade, offsets, cooldown, rate), Underway rows, `Pocket`, the hollow, `HushClient` (grade, full duck), `GardenState.carry`, catch-up extra safe ground | **Retired**: `FeatureFlags.Hush = false`. Code and specs stay until Spencer says yes to the tier (specs inject their own flags, so they keep running). `carry` and `extraSafe` stay as harmless unused paths. |
| Music | T0 has none. T1: `audio:duck("tier", 2, .4)` refreshed while on the tier, the Hush client's pass with a part gain. |

**Switch:** new names, not the Hush's: `FeatureFlags.Tier`, ConfigService **`garden_tier`** (missing = on, the
IslandBounds rule), attribute `Tier_on`, owner chat **`/tier on|off|clear`**. Reasons: the Hush code stays in the repo
with its own switch until removal; `/hush` now means something Spencer has seen and rejected; and a fresh key cannot
pick up a `garden_hush` value someone set in ConfigService during the Hush tests. Question 2.

---

## 6. Files

**New:** `src/shared/Tier.lua` (gate; frames; footprints; `covers`, `onIt`, `RingAside`, `BoundsRegions`, evacuation
frames), `src/shared/TierGreybox.lua` (rows), `src/shared/GreyboxRows.lua` (the row helpers and the builder),
`src/server/TierConfig.lua` (IslandBoundsConfig exactly, on `garden_tier`), `src/server/TierHost.lua`;
`scripts/Tier.spec.lua`, `TierConfig.spec.lua`, `TierHost.spec.lua`.

**Changed:** `FeatureFlags.lua` (`Tier = true`, `Hush = false`); `HushGreybox.lua` and `HushHost.lua` (use
`GreyboxRows`; behaviour unchanged); `init.server.lua` (require `Tier`, the `tierHost` local, the three pet floor lines,
the bounds `regions` dep, the mount, the `/tier` chat line, `leave`, the config start: nothing else);
`scripts/run_dash_server_specs.py` (the three specs). Docs at landing: `TODO.md`, `V3-TEST-PASS.md` row, plan as-built.

**Not touched:** `init.client.lua` and every client module, `CameraClamp`, `LoungeWorldV7Art`, `WorldV7Data`,
`IslandBounds*`, `GardenState`, `GardenPathPlanner`, every `Nest*` / station / plaza file (the egg-corner builder's),
`Dash*`, `GardenLife`, `LifeSim`, `Aero*`, `AmbientAudio`, `WorldAero`.

**Live safety:** the ceiling opens only on the beta place and in Studio; `TierHost.mount` and `TierConfig.start` do
nothing on live (spec); no remote is created at all; `Tier.covers(p, false or nil)` is false, so the pet floor line is
today's (spec on a grid, the edges, NaN); the bounds `regions` dep returns nil unless `tierHost.open`; nothing reads
an attribute or ConfigService on the hot path.

---

## 7. Specs (offline runner)

`python scripts/run_dash_server_specs.py "C:/Users/skunk/Documents/Development/egg-drop/build/luau-cli/luau.exe"`

- **Tier.spec** (pure, reads the live world data so it rechecks after any re-export):
  gate (beta + Studio, live never, missing = on); `covers` closed = false everywhere, so the chained pet floor test
  equals the old one on a grid, the Floor's exact edges and NaN; open covers every footprint and not the lawn 2 studs
  past a leg; the slab clears the crest (ground under it at most 1 stud above the top, the bump allowance) and the
  garden edge stands on ground 14+; **leg rules**: run, rise 12 each, slope 13 to 16 degrees, 7 wide, the walk
  surface 1+ stud over the ground everywhere under it (no ramp inside rock), the two legs meet the landing and leg B's
  top meets the top platform at y 28 within .05, the top platform meets the slab's garden edge; footprints 4+ studs
  from every find spot, station, rest spot, lamp, park kerb, the Dash course and pad, the nest spot and every
  `IslandBounds` wall; nothing over the cave pocket or the mouth's walkable strip (x -12 to -3, z -116 to -88);
  `RingAside` is exactly the boxes that meet the grown footprint (98 to 111 today), and the end closers meet boxes 97
  and 112; the bounds region starts at y 20 and holds the slab, the top platform and leg B's top 8 studs; the
  evacuation spot is inside the home Floor, on `IslandBounds.safeCell` ground, under no footprint, `onIt` false;
  rows: `W7T_` names unique, finite, at most 60, the tier floor under the middle, the balustrade gap at the top
  platform, invisible walls 12 high all round but that gap.
- **TierConfig.spec**: IslandBoundsConfig's cases on `garden_tier` / `/tier` (missing = on, refresh failure keeps the
  last value, closed ceiling asks nothing).
- **TierHost.spec** (fake room with a `PerimeterWall` of numbered boxes): live = nil and nothing connected; on builds,
  stands the ring aside (only `RingAside`), adds the blocked boxes, then `open`; off evacuates first (one on the tier,
  one on leg A, one on the lawn who stays), then the ring back as it was, everything destroyed; a missing box keeps
  it closed with one warning; three errors close it the same way.
- The existing Hush, IslandBounds, IslandBoundsHost, GardenState and PetCatchup specs stay green unchanged.

**Studio probes (listed, not run):**

- **T-P1** The slab against the crest: bumps through the floor, the retaining face, the outer skirt; floor 28 vs 29.
- **T-P2** Walk up and down both legs on PC and at 844 x 390 with the default camera; leg B against the cliff (camera
  clamp); kerbs; stepping off each leg (lands on the lawn or leg A, no damage).
- **T-P3** The rim: walk the whole tier edge, jump at the balustrade and the outer wall, try both ends where the ring
  stood aside; **rerun `scripts/sweep_island_edges.py` with the tier on** for any new way off the island.
- **T-P4** Island bounds: stand on the tier 60 s (no return); force a root under y 20 out past the ring (returned to
  the lawn).
- **T-P5** Pets: owner up the path and round the tier for 60 s; the pet waits at the foot, never floats up, never
  walks under a leg; owner back down, the follow resumes; the catch-up never fires.
- **T-P6** `/tier off` with one account on the tier and one on leg A: both on the lawn, ring back, model and blocked
  boxes gone; `/tier clear` rebuilds.
- **T-P7** Fable's captures: from the Hub, the arch and the dais looking north; the Overlook looking down; the path
  foot looking up; each also at 844 x 390.
- **T-P8** Reset on the tier (dais), a deck round started up there, a race called while up there.
- **T-P9** The cave blocker still collides; finds, the Dash course and the plaza unchanged.
- **T-P10** Memory and frame time at home with the tier on and off (phone).

---

## 8. Risks

1. **The ring gap.** Standing 14 ring boxes aside opens the island's edge where the tier is. The tier's own wall must
   close it at both ends; the spec checks the geometry, T-P3 and the edge sweep check the walking.
2. **Pets following up.** Without `Tier.covers` they would (finding 6). It is the one change on the garden's hot path;
   closed it is provably today's line.
3. **Crest bumps** through the slab, and the slab's outer half over the island's outer slope: greybox looks rough from
   outside; nobody at home sees that side.
4. **Leg B against the cliff on a phone**: the camera clamp will pull the camera in against the rock. Seven wide and
   open on the garden side is the mitigation; T-P2 decides.
5. **Two hosts with the Hush retired**: `FeatureFlags.Hush = false` turns the Hush off on the beta at the next publish.
   That is the intent (Spencer has moved on), but the beta loses `/hush` the same day.
6. **The egg-corner builder** works on the plaza and stations; none of these files overlap, and the tier is 80+ studs
   from the plaza. The only shared file is `init.server.lua` (separate lines).

## 9. Questions for the architect

1. **Size and place:** 76 x 44 at (-60, -96) (outer half over the island's outer slope) instead of Fable's 84 x 44 at
   (-52, -90) (which overhangs the lawn by about 8), or the 84 x 24 promenade inside the ring? Fable to confirm too.
2. **Switch:** new `garden_tier` / `/tier` / `Tier_on` (my plan), or keep `garden_hush` / `/hush`?
3. **Retire the Hush now** (`FeatureFlags.Hush = false` in this slice), or leave it on beside the tier until Spencer
   has walked the tier?
4. **Pets in T0:** wait at the foot (my plan: `Tier.covers` plus blocked footprints), or the catch-up poof to the top
   (needs tier pet floors and true heights, which is most of T1)?
5. **No safe samples on the tier** (falls return you to the lawn): fine, or should the tier keep its own safe spots?
6. **Floor y 28 with up to 1-stud bumps, or 29** (no bumps, 25 over the lawn)?
7. **`GreyboxRows` extraction** touches the retired `HushGreybox` / `HushHost` (behaviour unchanged, specs prove it),
   or should the tier copy the 40 lines instead?

---

## 10. Architect verdict (2026-11-24: GO WITH CHANGES) and what was built

**Answers:** 76 x 44 at (-60, **29**, -96); new `garden_tier` / `/tier`; the Hush retired now (`FeatureFlags.Hush =
false`; the bounds `regions` dep returns one list); pets wait at the foot (by design, T0); no safe spots on the tier;
`GreyboxRows.lua` new, for the tier only (`HushGreybox` / `HushHost` untouched).

**Required changes, all built:** `Tier.ringAside` / `Tier.closers` run inside `TierHost.mount`'s pcall, never at
require (bad data = closed with one warning; spec). Skirts and closers from y **-8** to the wall top **40** (spec checks
the ground under the outer skirt). Bounds region from y 20 to 80. Close evacuates, puts back only the ring boxes that
still exist (references kept), and destroys the model and footprints in one step; a rebuilt lounge drops the state.
Pet-blocked footprints are the solids grown 1.5; a catch-up spot on the foot leg's low end is refused (spec, through
`GardenWalkability.resolveAnchor`). The 4-stud checks include garden-life perches and crowns, lamps, routes, ground
dressing (litter, lawn patches, path fray), bushes, find spots, stations, rest spots, the nest, the Dash course and
pad, park kerbs and island walls; a flood fill proves no lawn is closed off. The pet floor chain closed equals today's
line on a grid, the Floor's exact edges and NaN. Ring boxes come from geometry (today 98 to 111, neighbours 97 and
112). The tier code is its own block in `init.server.lua`; the other edits there are the require, the `tierHost`
local, the three pet floor lines, the bounds `regions` dep, the `/tier` chat line and the config start.

**One deviation, forced by the world (for Fable and Spencer):** the Pet Park **grove** (centre (-38, -46), 16 x 11)
fills the cliff foot south-west of the cave, so Fable's two 44-stud legs along the foot cannot fit (they ran through
the park). The free lawn between the cave mouth, the park, Tree_05 and lamp 4 is about 26 along the cliff by 38 out.
So the path is **a zigzag of four legs running out from the cliff and back**, side by side: each 6 wide (7 did not
fit), 25.5 run, rising 6.1 (**13.5 degrees**), with a near landing against the cliff (y 16.8), two far landings out
in the lawn (y 10.7 and 22.9) and a top platform from leg 4 back over the cliff onto the terrace's garden edge. The foot
is leg 1's near end on the cave side; every leg is open-sided with kerbs; solid supports below. It is visible from the
plaza and climbs about the same 100 studs of walking. Alternatives if Fable dislikes it: move the grove park, or put
the path south-west of the park (crowded: three find spots and Tree_04). Any flowers and bushes under the path's
solid supports are hidden (the spec counts them, at most 12); the art pass re-scatters them.

**As built** (branch `worktree-agent-aa0edfc9059d09a19`, offline, not seen in Studio, not code reviewed):
`src/shared/Tier.lua`, `TierGreybox.lua` (at most 70 rows, spec), `GreyboxRows.lua`; `src/server/TierConfig.lua`,
`TierHost.lua`; `FeatureFlags` (`Tier = true`, `Hush = false`); `init.server.lua` as above; specs `Tier` (11 cases),
`TierConfig` (3), `TierHost` (7). Offline runner **63/63**.

**Studio probes (unchanged list, adjusted for the zigzag):** T-P1 floor at 29 against the crest, the retaining face,
the outer skirt; T-P2 walk the four legs and three landings on PC and at 844 x 390 (camera clamp at the near landing
against the cliff, the far landings over the lawn); T-P3 the rim, both ends where the ring stood aside, the closers,
**rerun `scripts/sweep_island_edges.py`** with the tier on; T-P4 bounds (60 s on the tier, a forced fall past the ring);
T-P5 pets wait at the foot and never walk under the path; T-P6 `/tier off` with players on the terrace and on a far
landing; T-P7 Fable's captures; T-P8 reset, a deck round, a race call up there; T-P9 the cave blocker still collides,
the grove park, finds and the Dash course unchanged; T-P10 memory and frame time on the phone.
