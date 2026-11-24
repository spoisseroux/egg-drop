# The Hush greybox (G0 + the pet part of G1/G2): build plan (Opus, 2026-11-23)

Spencer, 2026-11-23: "Yes, greybox it", on Fable's `GARDEN-EXPANSION-LOOK.md` with her defaults: same place (no
teleport), a short fade in the tunnel, open from day 1, "the Underway" (the cave room) and "the Hush" (a sunken mossy
hollow, about 150 x 110, still pool, no music), the two sealed doors visible from the first build.

Step 1 of a review-driven build. Beta place only, behind a build ceiling, a ConfigService switch and an owner chat
command. Off = the cave blocked exactly as today. **The architect's verdict (section 13) wins over anything above it;
section 13 also records what was built.**

**Scope delta from the spec's G0.** The spec's G0 leaves the pet waiting in the Underway. The brief for this slice
says the pet comes through the fade and walks in the Hush, so this slice also takes the minimum of G1 (the server's
pet floor checks learn the second region) and G2 (the pet is moved with its owner). Everything else in G1 to G7
(walk map, region-aware ground heights, art, sound, toys, race call-back) stays out.

**What I read:** the spec; `WorldV7Data` (decoded: `caveBlocker`, `perimeter`, `fallCatch`, the `ground` grid, the
mesh bounds); `LoungeWorldV7Art`; `HollowWorldLayout`; `IslandBounds` / `IslandBoundsConfig` / `IslandBoundsHost`;
`Lounge` (spawn, FallCatch, `Lounge.moved`); `init.server.lua` (`petAnchor`, `groundAnchor`, `gardenInput`,
`validWander`, `validFocus`, `resolveGardenTarget`, `catchupLanding`, the mounts and the owner chat block);
`GardenState` (`sync`, `transition`, `catchUp`, snapshot `hop`); `PetCatchup`; `GardenPathPlanner`;
`GardenWalkability`; `GardenLayout`; `PetFollow` (ground snap, hop poof); `RoomCompanions` (72-stud observer cut);
`CameraClamp`; `BoardAudio:duck`; `AmbientAudio` (headers only); `GardenLife` (deps only); `FindsHost`; `DashHost`
join reach; `RoomView` focus; `FeatureFlags`; `GardenHour` / `GardenHourConfig`; `default.project.json`;
`scripts/run_dash_server_specs.py`. Nothing here has been seen in Studio. Every `[probe]` is listed in section 9.

---

## 1. What the code says today (findings that shape the plan)

1. **The pocket is smaller than the spec assumes.** The ground grid has a flat floor at y 4.0 for x about -12 to -3
   and z -100 to -113 (cells at x -10 and -6), rising to 7 to 12 at x -14 and 5 to 8 at x -2, and to 20+ at z -116.
   So about **10 wide x 13 deep from the blocker line**, not 14 x 20. The blocker is x -17.1..3.0, z -102.6..-99.6,
   y 3..20. The grid is a downward ray on the ground meshes, so it says nothing about a roof `[probe P1]`. The pocket
   is inside the perimeter ring (checked: (-7, -113) and (-7, -120) are inside; the ring passes at z -119 to -122).
2. **The pet cannot leave the home Floor box today.** `petAnchor`, `validWander` and `validFocus` in
   `init.server.lua` all refuse a point outside `room.Floor` (228 x 176 round (4, -2): **x -110..118, z -90..86**).
   The pocket (z < -99) is already outside it. Today an owner in the pocket leaves the pet at the last ground anchor
   (`board.groundAnchor`), about z -89. In the Hush the same thing would happen: the pet would stand at the cave
   mouth. This is the one real gate on "the pet walks in the Hush".
3. **The server's ground rays are `Include {EggDropLounge}`** (`petAnchor`, `resolveGardenTarget`, `validWander`,
   `validFocus`). Hush geometry must live **under `workspace.EggDropLounge`** or every pet ray misses it.
4. **`GardenPathPlanner` does not clamp follow targets.** Its `onFloor` (line 73, the one Fable named) only filters
   the static graph's corner nodes. A direct path between two Hush points passes `Walk.pathAllowed` (no home wet or
   blocked box is within 80 studs of the Hush). So the planner needs no change for G0 as long as the Hush adds **no**
   wet or blocked regions: a blocked box there would send paths into the graph, whose nodes take
   `World.groundY`, which returns `FloorTop` (4) off the grid, and the pet would fly up to y 4.
5. **`World.groundY` / `GardenLayout.onGround` do not know the Hush.** Off the grid they return 4. For the Hush this
   is benign: every Hush height is below 4, so `onGround` says "ground" and `groundAnchor` keeps Hush anchors. Fix in
   G1, not here.
6. **`IslandBounds.gone` would pull anyone in the Hush home.** It is true outside the ring by more than 3 studs, and
   below y -25. The Hush is outside the ring. The host's leap guard and `moved()` quiet only last 2 s.
7. **`PetCatchup.clear` needs `Bounds.safeCell`**, which is home ground only, so a catch-up in the Hush would never
   find a landing. Needed as the backstop.
8. **`GardenState.catchUp` is already a "move the pet now" primitive**: a prepared hold at a spot, `from = to = spot`,
   `hop.seq + 1`, and every client plays `PetPoof` once on a new seq and snaps (`PetFollow`, line 127). A
   respawn already recreates the actor at the new anchor (`sync` drops an actor whose `characterId` changed).
9. **Other players' pets are not drawn past 72 studs** (`RoomCompanions`, `Layout.ObserverDistance`). Home and the
   Hush are 120+ studs apart, so two players in different gardens never draw each other's pets.
10. **`CameraClamp` only stops on parts whose name starts with "W7"** (lounge descendants). Hush parts named
    `W7H_*` get the clamp for free; no change to `CameraClamp`.
11. **World music has a duck table** (`BoardAudio:duck(name, duration, gain)`, used by `AmbientAudio:setRound`). A
    `"hush"` duck needs no change to `BoardAudio` or `AmbientAudio`.
12. **Streaming is not set in the repo** (`default.project.json` sets only FilteringEnabled; `DashClient` checks
    `workspace.StreamingEnabled` at run time). Plan for both `[probe P2]`.
13. **Joining a race needs the gate in reach** (`DashHost`: 12 studs, `HeightReach`). A player in the Hush gets
    "Far". Nothing pulls them home. That is G2's call-back, not this slice.
14. **Nothing gameplay-placed is near the mouth**: no find spot within 40 studs of (-7, -95); the Dash course is
    100+ studs away; the nest is at (-17.5, -2.5). The island wall `spur_neck_west` ends at (1, -101), at the
    mouth's east corner, outside the walkable floor (x -12..-3) `[probe P1: does it pinch the mouth]`.

---

## 2. Where the Hush sits

One authored frame, **`Hush.Origin`**: the tunnel mouth on the Sill, Hush-local (u east = +X, v north = -Z,
h up from the floor). Moving the whole Hush is one constant.

- **Origin: x -7, floor y -20, Sill mouth at z -226.** So world x = -7 + u, z = -226 - v, y = -20 + h.
- I moved it **20 studs north of the spec's centre** (spec: centre about (-7, -20, -275)): the drift rocks' bounds
  reach z -195, and with the spec's numbers the 24-stud tunnel would start at z -182, inside them. Now the tunnel is
  z -202..-226, the floor z -226..-350, the Quiet Shelf to z -360. Floor centre about (-7, -20, -288).
- Clear of: the island underside (to z -161), the ground collision tiles (to z -159), the drift rocks (to z -195),
  the far peak 2 bounds (from z -403). Inside the fall catch (1400 square at y -166). **The cloud meshes' bounds
  overlap it** (cloud 4 and 5 are 1800-stud boxes); they do not collide `[probe P3: any cloud surface in the hollow]`.
- **Sightline.** From the lawn the ridge (y 25 to 30 at z -116 to -136) hides the floor and walls. A camera zoomed
  far out above the lawn can see over the ridge to wall tops at y +20 `[probe P12]`. If it does, lower
  `Hush.Origin` (floor -40 puts wall tops at 0) or narrow the camera's max zoom near the cave; one number either
  way. From inside, the south wall (40 high, 55 studs from the pool) hides the island's underside and ridge.

### Coordinates (world, studs)

| Piece | u, v, h (Hush-local) | World centre | Size (x, y, z) | Notes |
|---|---|---|---|---|
| Floor slab | u -79..79, v -4..138, top h 0 | (-7, -22, -293) | 158 x 4 x 142 | Under walls, Sill, shelf. |
| West / east wall | u -79..-75 / 75..79, v -4..128, h 0..40 | (-84 / 70, 0, -288) | 4 x 40 x 132 | |
| South wall left / right | u -79..-3 / 3..79, v -4..0 | (-48 / 34, 0, -224) | 76 x 40 x 4 | Tunnel gap u -3..3. |
| South wall lintel / under | u -3..3, h 14..40 / 0..6 | (-7, 7 / -17, -224) | 6 x 26 / 6 x 6 x 4 | Gap h 6..14 (tunnel). |
| North wall left / right | u -79..-5 / 15..79, v 124..128 | (-49 / 40, 0, -352) | 74 / 64 x 40 x 4 | Shelf gap u -5..15. |
| Quiet Shelf sides | u -9..-5 / 15..19, v 128..138 | (-14 / 10, 0, -359) | 4 x 40 x 10 | |
| Quiet Shelf rail | u -5..15, v 137.6, h 0..1.2 | (-2, -19.4, -363.6) | 20 x 1.2 x .4 | Visible. |
| Shelf invisible wall | u -5..15, v 138.2, h 0..14 | (-2, -13, -364.2) | 20 x 14 x 1 | Players only. |
| Tunnel floor / walls / roof | u -3..3, v -24..0, h 6..14 | (-7, -14.5 / -10 / -5.5, -214) | 6 x 1 x 24; 1 x 8 x 24 at u ±3.5; 8 x 1 x 24 | Straight in G0 (the bend is G3). |
| Tunnel end wall | v -24.5 | (-7, -10, -201.5) | 8 x 10 x 1 | Dead end; the return trigger is in front of it. |
| The Sill | u -8..8, v 0..10, h 0..6 | (-7, -17, -231) | 16 x 6 x 10 | Top y -14 = the tunnel floor. |
| Sill lip + invisible wall | v 10 (north) and u -8 (west) edges | | lip .8 high; walls 10 high | The ramp is the way down. |
| Ramp | wedge u 8..40, v 1.5..8.5, h 6 down to 0 | (17, -17, -231) | 7 wide x 6 x 32 | About 10.6 degrees. Spec asserts its top meets the Sill. |
| Clumps (3) | (-24, 50), (0, 94), (52, 72) | (-31, -14, -276), (-7, -17, -320), (45, -16, -298) | 10 x 12 x 8; 6 x 6 x 6; 8 x 8 x 8 | Screen clump, shrub, east marker. Not pet-blocked in G0 (finding 4). |
| Pool outline (optional) | (0, 78), flat | (-7, -19.9, -304) | 44 x .2 x 26 | Dark plate, no collision, not wet: only to judge scale. |

**Pet floors** (invisible, no collision, attribute `GardenFloor`): Hush interior u -73..73, v 1..122; the tunnel
u -2.5..2.5, v -23..0; the Quiet Shelf u -5..15, v 124..137. No Underway pet floor (the architect: the pet waits at
the mouth while you are in the pocket). As built these are data boxes, not parts.

**Regions** (`Hush.regionAt(position)`, plain boxes): `hush` = x -86..72, z -200..-366, y -40..60; `underway` =
x -14..0, z -99.5..-116, y 0..26. Hush fall line y -32 (floor -20 less 12).

### The Underway (inside the existing pocket)

All relative to `Hush.UnderwayOrigin` = (-7, 4, -101) facing north, so measuring the pocket once `[probe P1]` moves
every piece.

| Piece | World | Size | Notes |
|---|---|---|---|
| North throat: two jambs, lintel, back plate | jambs x -10.5 / -3.5, lintel y 12.5, back z -115.5; alcove z -112..-115 | 6 wide x 8 high x 3 deep inside | Dark back plate. The back plate stops the walk; the pocket's back wall is about z -114 and the parts may sit into the rock. |
| North trigger | (-7, 8, -113.75) | 6 x 8 x 2.5 | Not a part: data both sides read. |
| West sealed throat | stones at x -12, z -104.5..-110.5, y 4..9; dark gap plate y 9..12 | 1.5 x 5 x 6 | Collides. Amber light above. |
| East sealed throat | the same at x -2 | | Blue light above. |
| Lights (fixtures) | north (-7, 9, -112) #DFF5E6 r 10 b .9; west (-11, 10, -107.5) #FFC07A r 7 b .6; east (-3, 10, -107.5) #5C8CFF r 7 b .6 | | The existing `GrottoLight` (cyan, r 18) stays. |
| Underway escape caps | only if the sweep finds a climbable slope `[probe P1]` | | Invisible, Hush-owned, exist only while the Hush is open. |

**Arrival frames and pet landings**

| Door | Owner arrives | Facing | Pet lands | Distance from the opposite trigger |
|---|---|---|---|---|
| Into the Hush | (-7, -14 + lift, -209) (u 0, v -17) | north (-Z) | (-7, -13.975, -214) (5 ahead, toward the Sill) | 4 studs from the return trigger |
| Back to the Underway | (-7, 4 + lift, -108) | south (+Z) | (-7, 4.625, -88), inside the home Floor | 4.5 studs from the north trigger |
| Evacuation (switch off) | (-7, 4.6 + lift, -86) on the lawn, inside the home Floor | south | (-7, 4.625, -82) | n/a |

`lift` is `Lounge.spawnFrame`'s (HipHeight + half the root + .1, plus the leg for R6). Hush return trigger:
(-7, -10, -203.5), 6 x 8 x 3. Arriving facing the way you were walking means the default camera, which keeps its
yaw, already looks the right way: the camera does nothing on its own.

---

## 3. How it is built

**Parts made by the server from a pure data module**, the `IslandBoundsHost` walls pattern, not a place edit and not
a new asset: nothing to upload, nothing in `default.project.json`, the build is reviewable in a diff, and off removes
it. About **45 Parts (about 540 triangles), no meshes, no textures**: well inside Fable's 25k / 6 textures. Matte
SmoothPlastic greys so shapes read (floor #6E7A6A, walls #5A5E62, Sill and ramp #7A746A, clumps #59665A, throat
backs #101412). Walls `CastShadow` on (the sunken read), the rest off.

- `HushGreybox` returns `{name, kind, size, cframe, color, collide, transparency, attributes}` rows from
  `Hush.Origin` / `UnderwayOrigin`. Names `W7H_*` (camera clamp). Every part `Anchored`, `CanTouch` false;
  `CanQuery` = `CanCollide` (pet rays and the clamp need the solids; invisible walls `CanQuery` false like the
  perimeter); attribute `WorldMesh = true` so `gardenScene` solids, greeting-shot blockers and other bounds-based
  scans skip the big boxes (rays still hit them).
- `HushHost` builds them into **`EggDropLounge.Hush`** (a Model, `ModelStreamingMode = Persistent`)
  when the switch turns on, and destroys it when it turns off.
- **The blocker:** `HushHost` finds `EggDropLounge.CaveBlocker` and sets `CanCollide` / `CanQuery` false while open,
  back to true / true when closed (today's values; the spec asserts both). `LoungeWorldV7Art` and `WorldV7Data` are
  not edited.

---

## 4. The passage (tunnel and fade)

Client asks, server decides. The destination is never sent by the client.

1. **Client (`HushClient`)**, about 10 Hz: the local root enters a trigger box (`Hush.Doors`) while Room mode, alive,
   no race seat, no close-up. It starts a black fade over `FadeOut` .35 s at once (controls are never taken) and
   fires `HushPassage {kind = "go", door = "north" | "home", seq}`. One request per entry: leave the box to re-arm.
2. **Server (`HushHost`)** checks, refusing with `{kind = "refused", seq, reason}`: ceiling and switch on; the
   board exists, not closing, `mode == "Room"`, not `dashHeld`, not `careHeld` / `careEquip`, no `lastHatch` (the
   same as `IslandBoundsHost.held`); humanoid alive, not seated, root not anchored; the **server's** root inside the
   door's trigger grown by `Slack` 3 studs; no passage already in flight; `Cooldown` 1.5 s since the last; a
   well-formed packet (table, known door, integer seq above the last). More than 4 packets a second are dropped.
3. If `workspace.StreamingEnabled`: `player:RequestStreamAroundAsync(arrival, StreamWait 2)` in its own task.
4. The server waits until `FadeOut` after receipt (the client began fading when it sent, so it is fully black by
   then), **checks everything again** (same character, still in the slack box, still on), then in one step:
   `PivotTo(arrival)`, velocities zeroed; `Lounge.moved(player)` and `boundsHost:arrived(player, arrival)` (section
   5); `garden:carry(userId, landing)` (section 6); `board.groundAnchor = landing`; then
   `FireClient {kind = "arrived", seq, region}`.
5. **Client** on "arrived": waits (at most 2 s) for a ray under the root to hit, so a streamed-in far side is there,
   holds black at least `Hold` .3 s, then fades in over `FadeIn` .5 s. On "refused": fades straight back in. No
   answer in `ClientTimeout` 3 s: fades in anyway. Reduced Motion: the same plain fade (no overshoot in G0).
6. **What other players see:** the avatar walks into the dark alcove and is gone; the pet poofs (the catch-up poof).
   In the Hush they see someone appear in the tunnel with a poof beside them. No other client fades.

Not in G0 (G3): the bend, exposure overshoot, the tick, the chirp and echo, the 1.0 s music fade at the mouth.

---

## 5. Island bounds (the move must not pull anyone home)

`IslandBounds` stays pure; the host is told about extra regions.

- `Bounds.gone(position, regions)`: inside any given region box, gone only below that region's `fallY` (-32 for the
  Hush); otherwise today's rule. `regions` nil or empty = today, byte for byte.
- `IslandBoundsHost`: a new dep `d.regions()` (init passes `Hush.activeRegions()`, empty while the Hush is off).
  Safe samples are also taken on a region's safe ground (`region.safe(x, z)`: the Hush interior less a 2-stud
  margin, root at most `safeTopY` -10, so the Sill counts and the ramp's foot does). New
  `Host:arrived(player, spot)` = `moved(player)` plus `rec.safe = spot`, so a later fall in the Hush returns to the
  Hush arrival, never to a home safe spot behind the mountain. The Underway is inside the ring: no change there.
- FallCatch (y -166, 1400 square) stays the last resort for both.

---

## 6. The pet

- **`Garden:carry(id, spot)`** (GardenState): the `catchUp` move without its rules. No actor: nothing. An actor in
  a race (`actor.dash`) or in care: refused (the passage already refuses those). Otherwise `release`, `idleSince =
  now`, the prepared rest hold at `spot` for `Catchup.Rest`, `from = to = spot`, `hop.seq + 1` with
  `why = "passage"`, `actor.catch = {}` (no stale far clock). The next decide (every .5 s) follows the owner's new
  anchor as usual. Clients poof and snap through `PetFollow` as they do for a catch-up.
- **Pet floors** in `init.server.lua`: one local `onPetFloor(position, margin)` = inside `room.Floor` as today, **or**
  (only while `Hush.on()`) inside one of the `GardenFloor` boxes. Used by `petAnchor`, `validWander` and
  `validFocus` in place of their three copies of the Floor test. Off = the old test exactly. This is what lets the
  anchor, and so the follow, live in the tunnel, on the Sill, on the floor and on the Quiet Shelf. (No Underway pet
  floor: section 13.)
- **Catch-up backstop:** `PetCatchup.clear(x, z, racing, from, extraSafe)`; `catchupLanding` passes
  `Hush.safeCell` while on. A carry that failed (no actor yet, a race starting the same tick) is then fixed by the
  next far hop.
- **Known greybox defects (fixed in G1):** the pet steps off the Sill's edge rather than taking the ramp (the
  client's ground ray snaps it down 6 studs); it walks through the three clumps; between the lawn and the pocket a
  follow line can clip the rock corners at the mouth.

---

## 7. Lighting, sound, life

- **Light:** the Hush is open to the same sky; the 40-stud walls shade the floor. Greybox adds one dim green-white
  `PointLight` in the Hush tunnel (r 14, b .8) plus the three Underway throat lights, so night is walkable.
  `HushClient` adds its own `Lighting.HushGrade` (ColorCorrectionEffect, TintColor #E6F2EC, Saturation -.08) while
  the local root is in the `hush` region, set during the black. It is a separate effect, so `AeroWorld` (which
  writes only `SproutHollowGrade`) and the garden hour are untouched `[probe P10: how it stacks with dawn, dusk,
  night]`.
- **No music in the Hush:** `audio:duck("hush", 2, 0)` refreshed every region pass (.5 s) while in the Hush (a stall
  gives the music back within 2 s), `audio:duck("hush", 0, 1)` when it stops; both change during the black. The region comes from the root's position every
  pass, never stored, so a respawn or an evacuation clears it by itself.
- **Hooks I need from owners of files I must not touch** (each optional, pcall-guarded; G0 ships without them):
  - `AmbientAudio`: `Ambient:setQuiet(name, on)` (or a `quiet()` dep) that takes birds, crickets and the bed to 0
    over 1 s. Without it, birds may still chirp from home perches 150+ studs away `[probe P10: audible?]`.
  - `GardenLife` / `LifeSim`: a `quiet()` dep: no leaves round the player, no bubbles, no birds while true.
    `HushClient.inHush()` answers it. Without it, leaves and bubbles follow you into the Hush.
  - `Dash*`: G2 decides what the race card says to a player in the Hush (today "Join" answers Far).
  - `Nest*`, `AeroWorld`, `AeroFalls`, `AeroKit`, `WorldAero`: nothing needed.
- **Finds** stay home (the list is home only; `FindsHost` keeps its timer and places the next find near the
  nearest home spot). **Dewdrops** cannot land in the Hush (`Bounds.safeCell`). Both as intended for G0.

---

## 8. Files

**New**

| File | What |
|---|---|
| `src/shared/Hush.lua` | Gate (the `IslandBounds` pattern): `PlaceId` beta, `Attribute "Hush_on"`, `Key "garden_hush"`, `ceiling(env)`, `resolve`, `setSwitch`, `on`, `inject`. Data: `Origin`, `UnderwayOrigin`, timings, `Doors` (trigger box, arrival CFrame, pet landing, to-region), `Regions`, `PetFloors`. Pure: `regionAt(p)`, `inTrigger(door, p, slack)`, `safeCell(x, z)`, `onPetFloor(p, margin)`, `activeRegions()`. |
| `src/shared/HushGreybox.lua` | Pure rows for every part in section 2. |
| `src/server/HushConfig.lua` | `IslandBoundsConfig` shape on `garden_hush`. Owner chat (beta, Studio): `/hush on|off|clear`; and `/hush go` / `/hush home` (the owner's own passage without walking; same checks bar the trigger box). |
| `src/server/HushHost.lua` | `mount(d)` nil with the ceiling off. One protected Heartbeat (errors counted, dead after 3, then closes and restores the blocker). Build / destroy, blocker, the remote and passage, evacuation, `leave(board)`. |
| `src/client/HushClient.lua` | `mount(d)` nil with the ceiling off. Trigger watch, fade, region effects (grade, duck), `inHush()`. |
| `scripts/Hush.spec.lua`, `HushConfig.spec.lua`, `HushHost.spec.lua`, `HushClient.spec.lua` | Section 10. |

**Changed** (each with an off path identical to today): `FeatureFlags.lua` (`Hush = true` and its comment);
`IslandBounds.lua` (`gone(position, regions)`); `IslandBoundsHost.lua` (`d.regions`, region safe samples,
`arrived`); `PetCatchup.lua` (`clear` gains `extraSafe`); `GardenState.lua` (`carry`); `init.server.lua` (mount
`HushHost` after the bounds host, `onPetFloor`, `catchupLanding`, the `/hush` line in the owner chat block,
`leave` on close); `init.client.lua` (mount `HushClient` with `audio`, `reduced`, `root`, `free`);
`scripts/run_dash_server_specs.py` (the new specs, plus `IslandBounds` and `IslandBoundsHost`, which already pass
offline); `scripts/IslandBounds.spec.lua`, `IslandBoundsHost.spec.lua`, `PetCatchup.spec.lua`,
`GardenState.spec.lua` (cases below). Docs at landing: `TODO.md` (Now working on, then checked off),
`V3-TEST-PASS.md` (row: "walk into the cave: the Underway, three doors, the north one fades you into the Hush with
your pet; walk back out", switch `/hush off`), `PLAY-BUILD.md` entry.

**Not touched:** `LoungeWorldV7Art`, `WorldV7Data`, `HollowWorldLayout`, `GardenPathPlanner`, `CameraClamp`,
`BoardAudio`, `default.project.json`, every `Nest*`, `Dash*`, `GardenLife`, `LifeSim`, `AeroWorld`, `AeroFalls`,
`AeroKit`, `AmbientAudio`, `WorldAero`. **Translations:** G0 adds no player text (chat commands are owner-only);
run the export and sync before publish anyway and record "0 add/update" if so.

---

## 9. Edge cases

| Case | What happens |
|---|---|
| Switch off (or ceiling off) | No model, blocker as today, `activeRegions()` empty, `onPetFloor` = the old Floor test, `clear` without extra safe ground, no client effects. Live: `mount` answers nil on both sides, no remote is made. |
| Switch turns **on** | Build the model, then open the blocker, then `Hush_on`. |
| Switch turns **off with people inside** | For every board whose root is in `hush` or `underway` (the box spans the blocker line): passage-style move to the evacuation frame, carry the pet, `arrived`, `FireClient {kind = "evacuated"}` (the client fades if it can, else it is just moved). Then, on the next Heartbeat, blocker back on, model destroyed, attribute false. A passage in flight re-checks `on()` before moving and is refused. Nobody can be left behind the blocker. |
| Respawn in the Hush (reset, death) | `Lounge.spawn` puts the new character on the arrival dais; the bounds host sees a new character; `GardenState.sync` recreates the pet at the new anchor; the client's region is home again, so the grade and the duck go. An in-flight passage sees a different character and is dropped. |
| Leaving the game in the Hush | Nothing about place is saved. `HushHost:leave(board)` and the bounds host forget the player; the next join is on the dais. |
| Deck round started in the Hush | Allowed; the player stays in the Hush, the pet rests at its Hush anchor; passages are refused while `mode ~= "Room"` (the trigger cannot be walked into anyway). `[probe P8: the round end does not move the character]` |
| Race started while someone is in the Hush | The call reaches everyone as today; "Join" from the Hush answers Far. A player in the race line who walks in may be dropped from the line by `DashHost`'s own reach check `[probe P9]`. Passages are refused while `dashHeld`. The call-back is G2. |
| Pet catch-up | The carry moves the pet in the same server step as the owner, before any decide, so the far clock never sees the gap; `actor.catch` is reset. If no carry happened, the far hop lands on `Hush.safeCell`. |
| Pet in a toy, a greeting or the park | `carry` releases it, as `catchUp` does `[question 6: the park session]`. Care and race: the passage is refused. |
| Two players in different gardens | One server, both gardens replicated. Each client's grade and duck follow its own root. Pets past 72 studs are not drawn. Finds are per player. |
| Spamming the trigger or the remote | One in flight, 1.5 s cooldown, 4 packets a second, monotonic seq. The server's own position check means a client cannot ask for a passage from anywhere else. |
| Streaming | Server asks to stream the arrival before the move; the client holds black until a ground ray hits (at most 2 s). |
| Owner on the Sill edge, anchor ray misses | `groundAnchor` keeps the last Hush anchor (it was set to the landing on arrival), never a home one. |

---

## 10. Specs

Offline: `python scripts/run_dash_server_specs.py "C:/Users/skunk/Documents/Development/egg-drop/build/luau-cli/luau.exe"`
(baseline on `eaa73c2`: 47 suites pass; `DASH_SPECS="IslandBounds IslandBoundsHost PetCatchup GardenState"`: 4 pass).

- **Hush.spec** (pure): ceiling and resolve (flag, beta, Studio, live refused; the switch default per question 3);
  `regionAt` for a point in each region and none; every door's arrival is outside both triggers by at least 3.5
  studs and inside a pet floor; every pet landing is on a pet floor and `safeCell` (Hush side); Hush region and the
  ring do not overlap; the Hush box is clear of the drift rocks' bounds (z < -195) and the underside (z < -161) and
  inside the fall catch; nothing in `FindSpots`, `DashCourse`, the nest spot or `IslandBounds.Walls` within 6 studs
  of the Underway pieces. **HushGreybox rows:** every size and CFrame finite and positive; names `W7H_*` and unique;
  a colliding top under every arrival and landing (a box test standing in for a ray); walls 40 high round the whole
  interior except the tunnel and shelf gaps; the ramp's high end at the Sill top within .1; part count at most 60.
- **HushConfig.spec:** parse `/hush on|off|clear|go|home`, nothing else; ceiling off: no command, nothing started.
- **HushHost.spec** (mocked boards, heartbeat, room, clock): ceiling off = nil and no remote (off parity); switch on
  builds then opens, off restores the blocker's two booleans and destroys the model; each refusal reason in section
  4; an accepted passage moves after `FadeOut`, never before, in the order move, moved, arrived, carry, reply; a
  re-check failure refuses; a second request in flight is dropped; switch off with one player in the Hush and one
  in the pocket evacuates both before the blocker comes back; leave forgets; three errors kill it and the blocker is
  restored.
- **HushClient.spec:** arms once per entry, re-arms on exit; fade out, refused fades in, timeout fades in, arrived
  waits for ground then fades in; region `hush` sets the grade and the duck, leaving clears both, a respawn at home
  clears both; ceiling off = nil.
- **IslandBounds.spec + IslandBoundsHost.spec:** `gone` with no regions is today's; inside the Hush region at y -17
  not gone, at y -40 gone; after `arrived` a fall in the Hush returns to the Hush arrival; with the Hush off a Hush
  position is rescued as today.
- **PetCatchup.spec:** `clear` with `extraSafe` accepts a Hush cell; without, refuses it (today).
- **GardenState.spec:** `carry` places the actor at the spot, bumps `hop.seq`, resets `catch`, releases a toy
  reservation; no actor is a no-op; a racing actor is refused; snapshot carries the hop.

**Studio probes (listed, not run):**

- **P1** The pocket with the blocker off: rays for the true floor, roof (if any), back wall z, side walls; captures
  from the mouth looking in and the back looking out; does `spur_neck_west` pinch the mouth; rerun
  `scripts/sweep_island_edges.py` with the blocker open for a climbable way out.
- **P2** `workspace.StreamingEnabled`, `StreamingTargetRadius`, and with it on: time from request to ground under
  the root in the Hush.
- **P3** Cloud and drift-rock surfaces inside or above the hollow.
- **P4** One full crossing each way, logged (request, move, arrived, fade in) on PC and on Spencer's phone; the pet
  arrives beside you and follows down to the floor; a second account watching at the Underway and in the Hush.
- **P5** Stand in the Hush 60 s: no bounds return. Force the root to y -40 in the Hush: returned to the Hush
  arrival. Jump at the shelf rail and the Sill lip.
- **P6** `/hush off` with one account in the Hush and one in the pocket: both home, nobody behind the blocker, the
  blocker collides again, the model is gone.
- **P7** Reset in the Hush: dais, pet with you, music back, grade gone.
- **P8** A deck round started in the Hush, to its results.
- **P9** A race called while one account is in the Hush and one is in the line.
- **P10** Music silent in the Hush and back at home; whether home birds are audible in the Hush; HushGrade at dawn,
  day, golden and night (`/hour at`).
- **P11** Memory and frame time at home and in the Hush, Studio emulator and Spencer's phone.
- **P12** Captures: from the Sill, from the floor up at the Sill, the Quiet Shelf out, from the home lawn north at
  max zoom (must not show the Hush); camera clamp against the Hush walls and in the tunnel.
- **P13** A close-up (focus) and the Things to do trail from the Hush: what they do.

---

## 11. Risks

1. **The pet-floor change touches the garden's hottest code** (`petAnchor`, `validWander`, `validFocus`). Mitigation:
   one helper, the Hush branch only while on, specs for off parity, and Studio P4.
2. **The pocket is smaller and maybe roofed** (finding 1). The Underway pieces are data off one origin; P1 first.
3. **Visible from home at max zoom** (P12). One constant to lower it.
4. **Server PivotTo of a client-owned character** is the pattern FallCatch and the bounds host already use; a slow
   phone may draw one frame at the old spot. It is black then.
5. **Pets in the Hush walk straight lines** with no ramp or obstacle awareness until G1 (section 6).
6. **Leaves, bubbles and birds** follow you in until the GardenLife and AmbientAudio owners add `quiet()`.
7. **A switch flip builds about 45 parts at once** under the lounge; `LoungeStations` and the garden scene watcher
   see `DescendantAdded` and ignore them (no station prompt, no wet or blocked attribute). HollowClock's lamp scan
   ignores parts without its attributes `[probe: the throat lights stay as authored at day]`.

## 12. Questions for the architect

1. **Pet floors:** one `onPetFloor` helper in `init.server.lua` reading `Hush.onPetFloor` (data) while on, or
   invisible `GardenFloor` parts scanned from the room? I lean to data (no scan, testable offline).
2. **Carry:** a new `Garden:carry` (my plan) or `catchUp` with a forced reason and spot?
3. **Switch default:** missing `garden_hush` = **on** (the IslandBounds and Finds pattern; the ceiling already keeps
   it to the beta, so Spencer walks it without a ConfigService entry) or off (the GardenHour pattern)?
4. **Client-asked passage** (instant fade, server validates) or **server-detected trigger** (no remote, but the fade
   starts a ping late and the player walks further into the alcove)? I lean to client-asked.
5. **The Underway as a pet floor in G0:** the pet follows you into the pocket (my plan), or waits at the mouth and is
   carried from there (simpler, and what the spec's G0 says)?
6. **Park session on carry:** end it (release) or refuse the passage while the pet is in a park session?
7. **Build on switch-on and destroy on off** (my plan) or keep the model whenever the ceiling is open and only
   toggle the blocker? Mine keeps "off = today" literal at the cost of a build burst per flip.
8. **Hush height:** keep the spec's floor y -20 until P12 says otherwise, or start at -40?
9. **`W7H_` naming for the camera clamp**, or a `WorldSolid` attribute check added to `CameraClamp` instead?

---

## 13. Architect verdict (2026-11-23: GO WITH CHANGES) and what was built

**Answers.** (1) The pet follows spec G0: no Underway pet floor. In the pocket the pet waits at the mouth (its last
ground anchor, as today); the passage carries it into the Hush; on the way home it lands inside `room.Floor` at
z -88, so home pet code only ever sees home positions. (2) Missing `garden_hush` = **on**; `HushConfig` is
`IslandBoundsConfig` exactly (a failed refresh keeps the last good value); the ceiling allows only the beta place and
Studio, with specs that live mounts nothing. (3) A pet in the Park (or in care, racing, holding the toy) refuses the
passage with `PetBusy`, as a snack feed does (`init.server.lua`); HushHost never ends a park session. (4) The camera
clamp picks the parts up by the `W7H_` prefix; `CameraClamp` is unchanged.

**Required changes, all built:**
- The Hush region (island bounds) and the pet floor checks read **`HushHost.open`**, which goes false only after the
  evacuation has finished; the evacuation calls `arrived(player, evac spot)`.
- The model is `ModelStreamingMode = Persistent`.
- The delayed move runs in a pcall, always clears the in-flight flag, and its errors count toward the 3-error
  shutdown (which evacuates, closes and restores the blocker).
- `Hush.onPetFloor(floor, position, open)` is pure; init passes `hushHost ~= nil and hushHost.open` (a field read; no
  ConfigService or attribute on the hot path). `Hush.spec` proves closed (`false`, `nil`, anything not `true`) equals
  the old Floor test exactly on a grid, at the exact edges either side of `Size/2 - 1`, for NaN and on a turned floor.
- Music and grade: `duck("hush", 2, 0)` refreshed every pass, no long duck; the grade goes on destroy and on a new
  character.
- A missing or renamed `CaveBlocker`: the Hush stays closed with one warning.
- Two players arriving together take the next of five arrival offsets (door-local), and so do their pets.

**As built** (branch `worktree-agent-aa0edfc9059d09a19`, Opus, offline only, not seen in Studio, not code reviewed):

| File | What |
|---|---|
| `src/shared/Hush.lua` | Gate (`Hush_on`, `garden_hush`, beta + Studio), origin (x -7, floor y -20, mouth z -226), regions, safe ground, pet floors, `onPetFloor`, doors (trigger, arrival, landing), evacuation, arrival offsets, timings. |
| `src/shared/HushGreybox.lua` | 39 rows: the hollow (floor, walls 40 high with the tunnel and shelf gaps, the Sill with its lip and stops, the ramp as a tilted slab, three clumps, the pool outline, a tunnel light) and the Underway (the north alcove, two sealed throats, three throat lights). |
| `src/server/HushConfig.lua` | `IslandBoundsConfig` on `garden_hush`; `/hush on|off|clear`. |
| `src/server/HushHost.lua` | Open/close, the passage (`HushPassage` remote), `/hush go|home`, evacuation, `leave`, protected heartbeat and remote, the 3-error shutdown. |
| `src/client/HushClient.lua` | Trigger watch, fade (out .35 s, in .5 s, ground wait 2 s, timeout 3 s), the duck and `Lighting.HushGrade`, `inHush()`. |
| `src/shared/IslandBounds.lua` | `gone(position, regions)`, `regionSafe(regions, position)`; nil regions = as before. |
| `src/server/IslandBoundsHost.lua` | `d.regions()`, region safe samples, `arrived(player, spot)`. |
| `src/shared/PetCatchup.lua` | `clear(..., extraSafe)`. |
| `src/server/GardenState.lua` | `Garden:carry(id, spot)` (a function added, nothing else). |
| `src/server/init.server.lua` | The mount, the three floor-test swaps, `catchupLanding`'s parameter, the bounds `regions` dep, the chat line, `leave`, the config start. |
| `src/client/init.client.lua` | The mount. |
| `src/shared/FeatureFlags.lua` | `Hush = true`. |

**Specs:** `python scripts/run_dash_server_specs.py ".../build/luau-cli/luau.exe"`: **53/53 pass** (47 before, plus
Hush 8, HushConfig 3, HushHost 12, HushClient 5, and IslandBounds 8 and IslandBoundsHost 8 now in the default run;
GardenState 20 and PetCatchup with their new cases). `Hush.spec`'s clearance cases read `WorldV7Data`,
`HollowWorldLayout.V7`, the find spots, the Dash course, the nest and the island walls: **rerun them after the island
re-export merges into feat** (rebase first), before probe P1.

**Hooks owed by others** (nothing of theirs was edited):
- **Island / AmbientAudio owner:** a quiet hook (`Ambient:setQuiet("hush", on)` or a `quiet()` dep) taking birds,
  crickets and the beds to 0 over 1 s; `clientUI.hush:inHush()` answers it.
- **Garden-life builder (GardenLife / LifeSim):** a `quiet()` dep: no leaves round the player, no bubbles, no birds
  while `clientUI.hush:inHush()`.
- **Nest / race builder (Dash*):** G2's race call-back: what the race card says to a player in the Hush (today "Join"
  answers Far). A "take me there" button would need a server entry point on `HushHost` like `/hush home`.

**Unverified:** everything in Studio and on a phone (probes P1 to P13: the pocket's true size and roof, streaming,
the sightline from home at max zoom, the camera clamp on the greybox, a real crossing each way with the pet, the
evacuation, respawn, music and grade, memory). Translations: no new player text; run the export and sync anyway at
publish.

**Code review (2026-11-24: GO WITH CHANGES, live safety holds), fixed:** (1) closing also carries any pet still in the
Hush whose owner is not there (a reset or respawn home) to the evacuation landing (`HushHost:rescuePet`, spec'd);
(2) the island bounds never return a player to a recorded safe spot that is itself off the island now (a Hush spot
after the Hush closed): the arrival spawn instead (spec'd); cosmetic: `Hush.ClientTimeout` = StreamWait + FadeOut +
1.5 s (3.85 s), so a streamed arrival never fades in early. Runner 53/53. **For the art pass (not fixed):** Hush parts
carry `WorldMesh`, so pet paths ignore the walls and clumps.
