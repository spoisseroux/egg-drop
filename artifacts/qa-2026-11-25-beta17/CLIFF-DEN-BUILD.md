# Cliff path, Play Den (step B) and terrace top: build (Opus, overnight 2026-11-25)

Spencer (2026-11-25): "the play den [small cave] sucks, lets just test / build out the cliff path and larger cave now".
Takes over the island session's `claude/cliff-den-scope` (out of usage until Nov 29). Branch `claude/cliff-den-build`
(that branch rebased on `feat/egg-drop-arcade-polish`). Beta only; live unchanged.

## Plan (compressed review-driven-build)

1. **Collision.** The island session's last WIP (691f1bc: den and path collide on server-built boxes from
   `CliffDenData.collision`; island meshes near them visual only) was never probed. Upload it, build the native
   `WorldBeta` pack in Studio Edit, probe the colliders (room floor and headroom, apron, path treads, terrace crest,
   carved copies against live), fix what fails, export the pack with its own proof.
2. **Mount** `ServerStorage.WorldBeta` in `default.project.json` only (`world_beta_pack.py --check` binds the bytes to
   the proof and to `CliffDenData.version`; it fails if `launch.project.json` ever mounts it).
3. **Wire step B.** `DenLayout.current` answers the room from `CliffDenData` when the sculpt is in, and nothing
   otherwise (step A's pocket retired: the den stays closed without the pack). The world owns the closer
   (`CaveBlocker` on the new mouth line, closed by default; `DenHost` only opens it). The cave bars hide while the den
   is open (already on the branch). `play_den` missing = on.
4. **Terrace.** The zigzag retired: `Tier` keeps only the terrace (floor 29 over the sculpt's regrade, balustrade gap
   s 26..34 where the path arrives = `CliffDenData.terrace.gap`). Opens only with the cliff path in (`CliffDen`), and
   `garden_tier` missing = on again; `/tier` still works. Closed, the path's foot and notch are gated (invisible
   walls). Pets: `Tier.covers` covers the path where it has left the lawn (pets wait at the foot, as T0); pet-blocked
   footprints along it.
5. **Dressing** the sculpt leaves floating (flowers and bushes over the terrace top or in the path's cut) skipped
   while the sculpt is in (`CliffDenData.dressingHide`, `CliffDenDressing`).
6. Offline runner, pipeline gates, Rojo builds; a Studio Play walk; captures to `studio/world/`.

## Architect checklist (own judgement)

| Concern | Answer |
|---|---|
| Live safety | Live builds from `launch.project.json`: no `WorldBeta`, so `CliffDenSwap.apply` finds no pack and the island is today's. Every new path is behind `FeatureFlags.Tier` / `PlayDen` ceilings (beta place or Studio). `CliffDenData` is never required on live (lazy reads only when the ceiling is open). `world_native_collision.py --check` PASS (live checkpoint untouched). |
| A stale pack | `CliffDenSwap.apply` refuses a pack whose `Version` is not `CliffDenData.version` (the live island stays, one warning); `world_beta_pack.py --check` refuses it before a build. |
| Bounds | The path is inside the perimeter ring everywhere (9.6 studs at its closest; spec: no path point reads as gone). The terrace keeps its bounds region (y 20 up). The den keeps `DenLayout.boundsRegions` while open. The island-bounds walls (`west_ramp` top 21) stay under the path where it passes (the path is at 23 there). |
| Pets | `Tier.covers` (open) refuses targets over the path off the lawn, so the anchor stays at the foot; footprints keep catch-up landings off it. In the den, `DenLayout.floors` (R12 fix) as before. |
| Evacuation | Terrace switch-off moves people up there to the lawn south-east of the path's foot (-14, -79): inside the home Floor, safe ground, out of the den's waiting area, 8+ from the doorstep (spec). People on the path are not moved (it is island); the notch gate stops them at the top. Den close: the doorstep, as step A. |
| Runtime swap | Never: the sculpt is swapped at server start only (architect review of the scope); the switches only open/close the terrace greybox, the gates and the den. |
| Collision fidelity | Probed in Studio (below); the remaining known misfits are listed. |

## Studio R2 (2026-11-25, Studio 53800d7d, Edit only, nothing saved or published)

**Uploads** (Open Cloud, creator user 10716920546, all Approved): `world-v7-beta.fbx` (R1 WIP) -> 136528276089470
(superseded), `world-v7-beta-collision.fbx` -> 85946264544648, the re-exported `world-v7-beta.fbx` (rock tiled) ->
103926272368523. Readback: `cliff-den/upload-readback-r2.json`.

**Probes on the WIP and what they found** (rays against the live colliders less the swapped ones plus the pack's):

| Finding | Fix |
|---|---|
| `W7_CD_Ground__ground` / `__grass` built precise and colliding (the manifest's `collide`); live's ground meshes do not collide (the W7C tiles do). Their hulls filled 208 of 470 room cells. | The pack follows `CliffDenData.parts.collide` (false): Box, no collision, no query. |
| The carved `W7_CD_Landmarks__marble` re-baked one long hull at y 7.1 to 7.5 from the mouth to z -22 over bare lawn (2,799 of 9,234 samples off live). A fresh bake of the live marble mesh matches live exactly. | Marble and trim stay live (not carved). The live marble leaves the new mouth open: a 4.4 sill (floor 4.2), posts on the new jambs (x -15 and 1), the trim lintel at 10.5. The old frame stays drawn round the new mouth until the art pass. |
| The carved island-wide `W7_CD_Rocks__cliff_rock` re-baked differently everywhere (up to 10 studs on the east mountain; the decomposition is global). | `TILE_ALL`: the cliff rock (Rocks and Landmarks) tiled whole into 32-stud parts (19 new). Against the drawn surface (EditableMesh rays) the tiled bake is closer than live's: mean 3.34 vs 3.85, over by 1+ at 142 vs 153 of 563 samples. Still not identical to live: the east mountain's hulls moved. |
| Five zero-width ground-collision slivers (one at x 0 inside the den's ceiling). | Left out (`DEGENERATE`). |

**Probes on the final pack:** room (470 cells): nothing over the floor, nothing under the 12.2 ceiling but the west back
corner (`W7_CD_Rocks__cliff_rock_1916` at 9.9 to 11.5, one stud from the wall) and the east front corner (ground tile
36_01 at 11.1 to 11.9). Apron and mouth (168 cells): no hole past the floor box; the trim lintel at 10.55. Path: no mesh
over any tread (960 samples, a body's height). Terrace crest: under the floor (29) but 7 samples at the end rims (29.3
to 32). Export: 134,706 bytes, sha 48d42001..., round trip exact (201 parts, 2,958 rays identical).

## Studio Play probe (2026-11-25, Studio 53800d7d, Rojo on 34872 from this branch with a serve project that leaves out
the two native packs; the exported `WorldBeta` put in ServerStorage by hand; streaming off as the place; fresh save,
Bear by the welcome remotes; nothing saved or published)

| Check | Result |
|---|---|
| Server start | **PASS.** `CliffDen` true, 323 `W7_CD_`/`W7C_CD_` parts and 123 collision boxes in the world, live cliff rock gone, live marble kept; `Tier_on`, `Den_on`, `Den_open` all true with no config (missing = on); the terrace greybox built, no gates; `CaveBlocker` on the new mouth line (-7, 7.2, -100.5) open; the cave bars hidden. No `[CliffDen]`, `[Tier]` or `[Den]` warning. |
| Walk the cliff path up and down | **PASS.** `Humanoid:MoveTo` along the 49 centre-line points from the lawn by the den to the arrival and back: never stuck (no point missed by more than 2), feet within -0.8..+0.7 of the treads. Up the last steps through the notch and onto the terrace floor (feet 29.0, Grass). |
| Terrace edges | **PASS.** Walking and jumping at the outer rim, both end rims and the garden balustrade: held at s -36.5 / +36.5, t -20.5 / +20.5 (no gap where the ring stands aside). |
| `/tier off` | **PASS.** The player on the terrace moved to (-14, 8.1, -79); greybox gone; `TierGates` built; climbing from the foot stops at (-23.3, -85.5), before the foot gate. `/tier clear` reopens (gates gone). |
| The den | **PASS.** Walked from the lawn through the mouth into the room (floor: the collision boxes). Gate, table and board prompts at the layout's spots, enabled once the egg shop that opens on arrival is closed. Fired (see below): gate opens the Dash picker (Just for Fun / Stats On / Time Trial), table switches to the Deck (Mode Board; back with mode Room), board opens Things to do. |
| Pets into the den | **FAIL, then fixed and PASS.** First Play: the Bear stopped at the mouth (z -97.6). Cause: `petAnchor` (and `resolveGardenTarget`) cast their ground ray from 8 over the point; in the room that is above the collision ceiling (12.2), so the ray landed on the ceiling and the anchor was refused. Fix: `DenLayout.groundRayTop` starts the ray at most 6 over the den floor inside the waiting area (elsewhere +8 exactly, spec'd). Second Play: the Bear in the room 3.1 s after the owner, 25 of 30 samples inside, on the floor (y 4.4 to 4.7). |
| Pets and the path | **PASS.** Owner on the path (mid, y 20): the Bear stays on the lawn by the den (-9.6, 5.1, -90.1) for 10 s; it never climbs. |
| `/den off` with the player inside | **PASS.** Moved to the doorstep (-7, 8, -87), Bear to the lawn, blocker colliding, bars shown, greybox gone; `/den clear` reopens. |

**Prompts and the pet's prompt (unverified for a real player):** with the Bear following, the den prompts (and the
meadow's Dash gate) never showed in Studio: `PromptShown` fired only for the Bear's `PetInteraction` (also E,
`OnePerButton`), even with the den prompt nearer (3.6 vs 6.7). With `AlwaysShow` set for the test each fired at once.
Studio's camera here is the Assistant's, not the player's, which may decide the winner; check on the beta that E at
the gate, table and board picks them over the pet. If not, give the den prompts priority (another key or `AlwaysShow`).

Captures: `studio/world/01-path-from-lawn.jpg`, `02-den-mouth.jpg`, `03-den-inside.jpg`, `04-terrace-arrival.jpg`,
`05-avatar-on-path.jpg`.

## Known, not fixed tonight

- The cliff-rock collision on the beta is not live's (tiled bake; closer to the drawn rock, but a slope may climb or
  stop differently, notably the east mountain). Walk the island once on the beta.
- The walk-map patch (`CliffDenData.walk`, `ground`) is still not read by `HollowWorldLayout` or the pets' planner:
  pets plan on live's map (fine: they wait at the path's foot and use `DenLayout.floors` in the den).
- The old marble frame and trim round the new mouth (art pass).
- `CliffDenSwap`'s "pocket" layer (`FeatureFlags.CliffDen=false`) still exists but no layout uses it.

## Fable R1 fixes and code review (2026-11-25), Studio R3

Fable fixes 1 to 8, 10 and 11 built (rows, tints, numbers; no meshes); code review fixes 1 to 3 and the nits. Rebased on
`feat/egg-drop-arcade-polish` (capsule, HUD, race audio, world-alive W1, the Hollow). Deviations: the `ClumpOneTop` step
sits at s 8..12 (Fable's s 12..18 is 8 from the gap, against its own 14-stud rule); the apron slab's top is 4.95, not
4.65 (the drawn lawn by the mouth stands up to about 4.9 over its 4.2 to 4.6 collision, so at 4.65 the slab showed only
as a frame round the grass).

Studio R3 Play (Rojo from this branch; the exported pack loaded through a test-copy Model upload, 133050222362651,
checked equal to the export: 201 parts, 188 precise, the same hull heights): E at the gate, table and board now shows
their prompt and the pet's prompt is off (`PromptShown`: Den_gate / Den_deck / Den_board; pet prompt false), the gate
fires with OnePerButton; away from them the pet's E shows (3.7 studs). `/tier off` with the player on the path (y 20)
moves them to the lawn spot (-14, 8.1, -79). The Bear follows into the den on the floor (y 4.68). Captures
`studio/world/r3/01` to `06` (06: the mouth at night, `/hour at 3400`).

Open for Fable: the crystals at #E8C468 still read lemon in Neon (a number to lower); the glassy vertical panes in the
den are not collision boxes (every `W7C_CD_Box_` is Transparency 1, and no part in the room is partly transparent):
they are the den wall mesh's own panels and seams, a mesh fix. Not done: fix 9 (dressing over the tan faces), phone
844 x 390 captures, the turn and shelf 2 shots.
