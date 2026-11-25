# The Play Den: build plan, step 1 (Opus, 2026-11-24)

Spencer chose (2026-11-24): the north cave becomes **the Play Den**, a walk-in, enlarged (about 28 x 19, roof 16,
mouth 16 wide), lantern-lit room with one physical object per game and no menu on entry. The meadow Dash pad keeps
only **"Join race"** while a race gathers. The Deck button stays. Things to do points to the den.

Look: Fable, `CLIFF-PATH-AND-ARCADE-CAVE-LOOK.md` section 2. Rock: the island session, `CLIFF-DEN-ISLAND-SCOPE.md`
(branch `claude/cliff-den-scope`, 8c4e9c3, architect-reviewed). This plan covers the code, the furniture and the
greybox only. **No src changes in this step.** Beta only, behind a new switch. Live stays unchanged.

**What I read:** the spec (all of it) and the island scope; `DashHost`, `DashDirector`, `DashMount`, `DashRing`,
`DashLine` (header), `DashClient` (open, gate, slowStep, line), `DashWire.request`, `Dash.lua`; the Deck button path
(`init.client.lua` RoomView callback at line 660, `things.act`); `ThingsPage.rows/layout`, the Things wiring in
`init.client.lua` (5031-5145), `Things.lua`; `WorldV7Data.caveBlocker`, `LoungeWorldV7Art.collision`; `IslandBounds`
+ `IslandBoundsHost`; `Hush.lua` + `HushHost` (blocker, pocket, evacuation, pet rescue); `Tier.lua`, `TierHost`,
`TierConfig` (the switch and footprint pattern); the pet floor checks in `init.server.lua` (`petAnchor`,
`validWander`, `validFocus`, `groundAnchor`, `catchupLanding`, the bounds `regions()`); `GardenPathPlanner.restPathClear`;
`GardenLayout.onGround`; `JournalPromptPriority`; `UICopy` (dash, things); STUDIO-CHECK-R5 (Hush P1, the pocket's real size).

---

## 0. What the code says today (findings that shape the plan)

1. **The pocket is small.** Studio R5 (Hush P1, blocker off): floor y 4.0 from z -101 to -113, back rock z -114.2,
   roof (cliff rock) y 15.0 to 18.6 (11 to 14 headroom), width 11.5 at z -102 (x -12.6..-1.1), the ground grid flat
   for x about -12..-3. Mouth at z -100 is 17.7 wide (x -14.8..2.9). The pocket sits **west** of the mouth's middle.
   Usable floor for furniture: about 9 x 12.
2. **The CaveBlocker** is a data box, `WorldV7Data.caveBlocker` centre (-7.07, 11.5, -101.07), 20.06 x 17 x 2.99
   (x -17.1..3.0, z -102.6..-99.6, y 3..20), built by `LoungeWorldV7Art.collision` as `EggDropLounge.CaveBlocker`
   (CanCollide and CanQuery true, invisible). The retired Hush opened it by setting both false and recording their
   values (`HushHost:openUp` / `close`). `FeatureFlags.Hush=false` today, so nothing else touches it.
3. **Pets cannot leave the home Floor** (x -110..118, **z -90..86**): `petAnchor`, `validWander` and both `validFocus`
   calls refuse a point off it unless `Hush.onPetFloor` adds a box. The den (z < -99) is off it. Today an owner in
   the pocket leaves the pet at `board.groundAnchor` by the mouth. This is the one real gate on "pets follow you in".
4. **Catch-up landings** need `IslandBounds.safeCell` (IslandGround starts at z -112, and the pocket is not safe:
   the sweep ran with the blocker up) or the `extraSafe` hook (`Hush.safeCell` while the Hush was open).
5. **Island bounds:** the pocket is inside the ring (ring at z -119..-122 near x -7). The enlarged room's west corner
   (-22, -119) is about 1 stud outside the ring there, inside `Margin` 3, so not "gone", but too close to trust: a
   `BoundsRegions` box is cheap. `init.server`'s `regions()` returns Tier **or** Hush today, not both: it must concatenate.
6. **Garden Dash measures everything from one spot,** `Mount.gate()` = `Course.Pad` (64.5, 4.7, -21): `JoinReach` 12
   for join and countdown, `QueueReach` 16 for promote, and the rope ring rule (`DashRing.rule`: latched once inside
   `Enter` 3.4, out past `Stray` 6.5 for 1 s = "Strayed") for the line and gather seats. A gather seat is tagged at
   once (`Director:seat` calls `tag`), so the pet **rests where it stands** from the join; the client draws it on the
   course from the countdown. So a den join already leaves the pet in the den. Only the reach rules need a second anchor.
7. **The client's rope clamp** (`DashLine`) only engages after the root has been inside the meadow ring's `Enter`,
   so a den waiter is never clamped at the meadow. It still needs to know its anchor so it never tries.
8. **The Deck button** is the first callback given to `RoomView.new` (init.client line 660): Dash `askLeave` first,
   then `cancelHatchNavigation(); request:FireServer("mode","Board"); clientUI.accepted("confirm")`. `things.act("deck")`
   does the same through `roomView:requestSwitch`. The difficulty picker follows on the server's mode change.
9. **Rest-path solids** are cached once per lounge but `restPathClear` re-reads `CanCollide` live, so the blocker
   going non-colliding is seen at once. New colliding furniture is **not** in that cache: pets are kept off it by
   `GardenBlockedRegion` footprints (Tier's pattern; the scene watcher picks them up on the beta).
10. **Island scope (step B):** the enlarged room arrives as a beta-only overlay swapped in **at server start** (never at
    runtime), announced by the workspace attribute **`CliffDen`**, with data in a generated **`Shared.CliffDenData`**
    (`den`: `floorY`, a convex plan polygon, `roofY(x, z)` grid, the mouth `x1 -15`, `x2 1`, top 11 and its z line, the
    back wall line for bays, the sign anchor under `W7_Landmarks__trim` y 10.2, four lantern anchors, the `PlayDen`
    region box; `evacuate` about (-27, y, -84); `caveBlocker` "off on the beta"). Parts: `W7_CD_PlayDen__*` (art),
    `W7C_CD_*` (invisible collision). The walk-grid patch is applied inside `HollowWorldLayout` and there is a beta
    `IslandGround`.

---

## 1. The approach

One small feature, the Tier pattern exactly, with the room's numbers in one pure layout module that has two variants:

- **`pocket`** (step A): constants from Studio R5, used only when `CliffDen` is not set.
- **`room`** (step B): resolved from `CliffDenData.den` when `workspace:GetAttribute("CliffDen")==true`. Server and
  client resolve the same variant (the attribute is set at server start, before any client joins).
- `CliffDen` on but `CliffDenData.den` missing or invalid: the den **stays closed** with one warning (the pocket no
  longer exists, so never fall back to it).

Everything that places furniture, measures a join, gives the pet a floor or a catch-up cell, or bounds a player reads
`DenLayout.current()`; nothing else hard-codes den numbers. Bays are a list; a new game is one bay entry plus a kind
handler, one Things row, one board row.

### Switch

`Shared.PlayDen` (the Tier module's shape): `FeatureFlags.PlayDen` is the build ceiling, opens only on the beta place
(107705084891479) or in Studio; ConfigService key **`play_den`**, workspace attribute **`Den_on`**. Off until the
config loads once; then **missing or malformed = off** (as Tier today), so Spencer opens it with **`/den on`** (this
server) or the key. `/den on|off|clear`, owner chat, beta and Studio only (`DenConfig`, TierConfig copied).
Off is the game before this build: blocker closed, nothing built, meadow prompt as today, no Things row.

### Server: `DenHost` (TierHost + HushHost's blocker)

- `mount(d)` answers nil with the ceiling off. At mount (protected): resolve the layout; `nil` keeps the den closed.
- **Open** (switch on, room present, Hush not open): build `EggDropLounge.PlayDen` from `DenGreybox` rows through
  `GreyboxRows.build` (held before parenting), pet-blocked footprints into `PetRegions` (`GardenBlockedRegion` set
  before parenting), then the blocker: record `CanCollide`/`CanQuery`, set both false. Then `open=true`.
- **Close** (switch off, 3 errors): everyone whose root is in the room box (slack 1) moves to the doorstep with the
  arrival offsets (`arrived()` for the bounds), each pet in the room is carried out (`rescuePet`, HushHost's), waiting
  den racers are dropped by DashHost's own check (reason `Closed`), the blocker gets its values back, model and
  footprints destroyed, `open=false`. A rebuilt lounge drops all state (TierHost's rule). Never yields.
- `open` is the host's own flag: the pet floor checks, catch-up, bounds and DashHost read it (never an attribute on
  the hot path).

### The furniture (greybox, server-built so everyone sees and collides with it)

Anchored greybox parts, `WorldMesh` attribute (bounds scans skip them; rays still hit), colliding for players where
they are solid (posts, stump, stools, crates), non-colliding for the flat things (paw stones, mat, sign, rope).
Pets are kept off by footprints grown 1.5. All prompts are **client-made** on local invisible anchor parts at layout
positions (DashClient's GateSign pattern), so they never depend on the server model streaming in.

| Piece | Step A (pocket), world (x, y, z) | Size / count | Notes |
|---|---|---|---|
| Sign | (-6, 9.0, -99.2), facing +z | 8 x 2.2 x .3 board, grey with a SurfaceGui text "The Play Den" + paw | Under the lintel trim (y 10.2) `[P1]`. One string. |
| Mouth lanterns | (-14.3, 7, -98.8), (2.4, 7, -98.8) | post .4 x 7, lamp 1 x 1.2 | PointLight #FFC98A, range 14, brightness 1.2, no shadows |
| Back lanterns | (-11, 9, -113.6), (-3, 9, -113.6) | wall bracket + lamp | Same light. **Four lights in all: the whole budget.** |
| Notice board | (4.5, ground, -96), facing +z (the lawn) | post + 4 x 3 board | Prompt "Things to do". SurfaceGui rows (section 4). |
| Bay 1: Dash gate | (-11, 4, -107), facing +x | two posts 5 high, 4 apart, a bunting bar, a chalk slate 1.6 x 1.2 | Prompt "Race" (today's picker). Paw stones: 6 flat discs r 2.5 round (-8.5, -107). |
| Bay 3: Deck table | (-5, 4, -111), facing the mouth | stump 3.5 across x 2.6, a Deck slab 2.4 x 1.6 tilted 20 degrees, Neon screen face at .6 alpha, 3 log stools | Prompt "Play". 7.2 from the gate (spec: 7+). |
| Bay 2: niche | (-10.5, 4, -112.8) | crate 2 x 2 x 2 under a grey dust sheet, 2 rope posts + rope | No prompt. |
| Bays 4, 5 | do not fit | `fits=false` | Shown in step B only. |
| Mat | (-7, 4.02, -106) | disc 6 across, .05 | Non-colliding. |

About 45 parts in step A, under 60 in step B (Mount's budget). Colours: matte greys and wood browns
(SmoothPlastic, no new texture); the Deck screen and the bunting are the only bright things.

**Step B** (room variant): the same kinds placed at Fable's five bays, (-18, -110) gate, (-12, -116) niche,
(-7, -117) table, (-2, -116) niche, (4, -110) niche, from the island's anchors (section 7); lanterns and sign from
`CliffDenData.den`; paw stones r 5 with eight stones; four stools.

### Prompts (client, `DenClient`)

- Three prompts: gate, table, board. `MaxActivationDistance` 6, `RequiresLineOfSight` false, `Exclusivity`
  `OnePerButton` (one E shown: the nearest), E / ButtonX like the Dash gate, `HoldDuration` 0 (gate: .4 while waiting,
  as the meadow "Leave line").
- Enabled only while `PlayDen.on()` (the `Den_on` attribute) **and** the layout resolved, the board is in Room mode,
  `roomView.canRoam()`, no other modal, and not held by a race (`clientUI.dash:held()`).
- **Gate:** calls `clientUI.dash:gate()` (today's function, unchanged: the `DashGateSheet` picker with Just for Fun,
  Stats On, Time Trial; or "Leave the line?" while waiting). Hidden while Dash is off.
- **Table:** calls `clientUI.playDeck()`, the Deck button's own callback pulled out into one local function (no
  behaviour change for the HUD button: it calls the same function).
- **Board:** `clientUI.openThings()`: `openMenu()`, then `gameMenu:openPage()`.

### Garden Dash: a second anchor

Pure `Shared.DashAnchor`:

- `DashAnchor.pick(at, den)` -> `"den"` when `den` (the layout, passed only while DenHost is open) holds `at` in its
  room box (slack 1), else `"meadow"`. **The server picks it from the root's position at the join**, never from the
  client.
- `DashAnchor.rule(rec, anchor, at, now, ...)`: `"meadow"` is today's `DashRing.rule` exactly; `"den"` is a box rule:
  in the room (slack 1) is fine; out by more than 2 for **2 s** is `"Strayed"`; den closed is `"Closed"`.
- `DashAnchor.reach(anchor, at, stage, den)` for join, promote and countdown: meadow keeps `JoinReach` / `QueueReach`
  / "Closer"; den is "in the room" (never "Closer").

`DashHost`: `self.anchors[userId]` set in `answer()` before `director:join` / `trial`, cleared in `leave()`;
`check()` and `line()` read it (missing = meadow, so every existing spec runs unchanged). `d.den()` returns the
layout only while DenHost is open, nil on live. The `joined` event and the join `reply` carry `anchor="den"` (absent
for the meadow: old shape). `DashDirector` is untouched except the hop rule below.

**The meadow pad while the den is on:** its prompt shows **"Join race"** only while `roster.phase=="gather"`, fewer
than 8 players are seated, and this player has no seat and is not queued (or "Leave line" while waiting there, as
today). It sends `join` with the gathering race's mode and **`hop=true`** (`Wire.request` accepts an optional boolean).
`Director:join(userId, mode, hop)`: with `hop`, anything that would queue is refused instead (`"Missed"` when no race
is gathering, `"WrongBand"`, `"Full"`), so a meadow hop never lands you in a line you did not pick. Idle or live: the
prompt is hidden; picking a race is the den's job. With the den off: today's "Race" picker, unchanged.

The client keeps `seat.anchor` / `queuedAnchor` from the server's packets; `DashLine:setWaiting` is only true for the
meadow anchor. The gather rail line, the camera, the countdown, the race and the results are unchanged. After the
results the camera returns to the avatar, which is still in the den.

### Pets in the den

- **Pet floor:** a shared pure `PetFloors.ok(floor, position, opens)` replaces the four copies of
  `not Hush.onPetFloor(...) or Tier.covers(...)` in `init.server`:
  `(Hush.onPetFloor(floor, p, opens.hush) or DenLayout.petFloor(p, opens.den)) and not Tier.covers(p, opens.tier)`.
  With every flag false or nil it is today's expression exactly (spec'd over a grid). Den pet floor = the room's floor
  polygon less 1 stud.
- **Ground anchor:** `GardenLayout.onGround` uses `World.groundY`; the pocket's grid cells read y 4.0 (Hush plan),
  so the owner's anchor counts as ground. Step B relies on the walk patch in `HollowWorldLayout` `[B-P1]`.
- **Catch-up:** `extraSafe` becomes a chain: `Hush.safeCell` (Hush open) or `DenLayout.safeCell` (den open: floor
  polygon less 1.5, less the furniture footprints).
- **Furniture:** footprints grown 1.5 as `GardenBlockedRegion` boxes; wander rays (Include the lounge, RespectCanCollide)
  also stop at the colliding pieces.
- **Switch off:** pets in the room are carried to the doorstep landing before the floor closes (HushHost's rescue).

### Island bounds

`DenLayout.BoundsRegions` = the room box, `fallY` = floorY - 8, `safe` = `DenLayout.safeCell`. `init.server`'s
`regions()` concatenates Tier, Den and Hush (each only while its host is open) instead of picking one.

### Things to do

- `ThingsPage.rows(ctx)`: with `ctx.den` a row **first**: `id="den"`, name `things.den.name` "The Play Den", line
  `things.den.line` "Games inside the cave", button Show me. Deck, Park, Finds, Dash rows unchanged.
- `things.show("den")`: the trail to the mouth pin (ground in front of the mouth's middle).
- `things.show("dash")` with the den on: to the meadow pad while a race gathers, else to the den's gate. Den off: today.
- `things.context()` adds `den = PlayDen.on() and DenLayout.current() ~= nil`.

### Notice board text (step A, cheap; Fable may defer it to A2)

A SurfaceGui on the board: up to four lines, `name · line` from the same `ThingsPage.rows(things.context())` (no new
strings, so translations come free), refreshed once a second while the local root is within 30 studs, nothing
otherwise. Hidden when Things to do is off.

### Copy (UICopy, then the translation steps)

`den.name` "The Play Den" (sign, board ObjectText); `dash.join` "Join race"; `dash.reason.Missed` "That race has
started"; `dash.reason.Closed` "The Play Den closed"; `things.den.name`, `things.den.line`. A den stray reuses "Strayed"
(the client already shows `dash.line.left` for it). Fable to word them. Every build: export CSV, sync, note in PLAY-BUILD.

---

## 2. Files

| File | New / changed | About |
|---|---|---|
| `src/shared/FeatureFlags.lua` | changed | `PlayDen=true` + its comment line |
| `src/shared/PlayDen.lua` | new, ~80 | ceiling, resolve (missing = off), setSwitch, on, inject |
| `src/shared/DenLayout.lua` | new, ~220 | pocket variant, `fromData(CliffDenData.den)`, `current()`, room box, `inRoom`, `petFloor`, `safeCell`, `BoundsRegions`, bays, pins, doorstep |
| `src/shared/DenGreybox.lua` | new, ~150 | rows for `GreyboxRows.build` from a layout; footprints |
| `src/shared/DashAnchor.lua` | new, ~70 | pick, rule, reach |
| `src/shared/PetFloors.lua` | new, ~25 | the one pet floor chain |
| `src/shared/DashWire.lua` | changed | optional `hop` boolean on join |
| `src/shared/UICopy.lua` | changed | the strings above |
| `src/server/DenConfig.lua` | new, ~55 | TierConfig copy, `/den` |
| `src/server/DenHost.lua` | new, ~230 | open, close, evacuate, rescuePet, blocker, footprints, lights |
| `src/server/DashHost.lua` | changed, ~40 | anchors, `d.den`, anchor-aware `check` / `line`, packets carry `anchor` |
| `src/server/DashDirector.lua` | changed, ~10 | `join(userId, mode, hop)` refusal instead of queue |
| `src/server/init.server.lua` | changed, ~30 | mount DenHost + DenConfig + `/den` chat; `PetFloors.ok` at 4 sites; catch-up chain; bounds regions concat; `den=` for DashHost; leave hook |
| `src/client/DenClient.lua` | new, ~200 | prompts on local anchors, enable rules, board SurfaceGui |
| `src/client/DashClient.lua` | changed, ~50 | meadow prompt state (pure `Client.promptState`), hop send, anchor on seat/queue, line only for meadow |
| `src/client/ThingsPage.lua` | changed, ~8 | den row |
| `src/client/init.client.lua` | changed, ~40 | `clientUI.playDeck` (the HUD callback), `clientUI.openThings`, mount DenClient, Things den row/show targets |
| `scripts/*.spec.lua` | new / changed | section 5 |
| `V3-TEST-PASS.md`, `TODO.md`, `PLAY-BUILD.md` | changed | rows when it lands on the beta |

Not touched: `LoungeWorldV7Art` (the blocker stays where it is built), `HushHost` (retired; DenHost refuses to open
while a Hush host is open), `TierHost`, the island data, `launch.project.json`.

---

## 3. Live safety

- `FeatureFlags.PlayDen=true` opens nothing on live: `PlayDen.ceiling()` needs the beta place id or Studio, so
  `DenHost.mount` and `DenClient.mount` answer nil, no attribute is written, ConfigService is never asked, the blocker
  is never touched, no model.
- `DashHost` gets `den=function() return denHost and denHost.open and layout or nil end`: nil on live, so every anchor
  is `"meadow"` and every rule is today's. `hop` is only ever sent when `PlayDen.on()`; the server ignores it unless
  the den is open (and the field is optional in `Wire.request`).
- The meadow prompt's new state is behind `PlayDen.on()` (false on live): text "Race", today's picker.
- `PetFloors.ok` with `opens.den` nil is today's line (spec over a grid of points, every flag combination).
- `regions()` with only Tier/Hush gives the same list as today.
- Things: `ctx.den` nil, rows unchanged. `clientUI.playDeck` is the same callback the HUD button runs today.
- Specs run the live case with `inject({studio=false, place=<live id>})`. Studio probe P12 reads the live project.

---

## 4. Edge cases

| Case | What happens |
|---|---|
| A race gathering while players are in the den | Den players can join it from the gate picker (mode change only if they are the first and alone, as today). Their seat is anchored to the den: they wait inside. Meadow players hop in with "Join race". At the countdown everyone is checked against their own anchor. |
| A race live while someone uses the den gate | Today's rule: they go in line (`Queued`), den-anchored; promoted when it is their turn as long as they are still in the room. |
| Two players at the table | Each starts their own round (the Deck is per player); one prompt per client. The first one's avatar moves into Board mode; nothing is shared. |
| Deck table while waiting in a race | `playDeck` asks "Leave the line?" first (today's `askLeave`). |
| Pet inspect prompt on E near furniture | `Exclusivity OnePerButton` shows the nearest E. Probe P2 checks the pet's prompt vs the gate/table at 116 points; if the pet's wins too often, den prompts take the keyboard E and the pet keeps its own key path `[question 9]`. |
| Den switched off mid-gather | Den waiters fail their anchor check (`Closed`), leave the line with a toast; meadow seats keep racing. Mid-race: the race runs (the pet is drawn on the course); the avatar is moved out by the evacuation, which skips no one (`dashHeld` players are moved too, as Tier and Hush do: the floor they stand on is closing). |
| Den on, Dash off | Gate hidden (no prompt, the arch still stands as a greybox). Board and table work. |
| Things to do off | Board prompt hidden, board text hidden, the den row absent. Gate and table still work. |
| Mobile | Prompts are tap targets; the gate picker and confirms are today's. Camera at 844 x 390 in a roof 11 to 14 pocket `[P1]`. |
| Gamepad | ButtonX on the prompts; the picker's focus is today's. |
| Respawn in the den / reset | Lounge.spawn moves the character home; the anchor rule drops a den waiter after 2 s out of the room. |
| A player inside when the server's lounge is rebuilt | DenHost drops its state (old parts gone with the old lounge) and reopens next tick. |
| Tier open at the same time | The zigzag's foot is about 20 studs west of the mouth; its evacuation spot (-8.3, -86.4) is 2 studs from the den doorstep (-6, -87): the offsets differ; both are inside the home Floor. Step B: Tier moves its spot to (-27, -84) (island `evacuate`). |
| Hush flag ever turned back on | DenHost refuses to open while `hushHost.open` (one warning): two owners of one blocker would restore each other's values. |

---

## 5. Specs

- `PlayDen.spec.lua`: ceiling (flag, place, studio), resolve (missing = off, override), on/inject (Tier.spec copy).
- `DenConfig.spec.lua`: `/den on|off|clear`, refused with the ceiling off.
- `DenLayout.spec.lua`: the pocket numbers sit inside R5's measured floor; prompt bays 7+ apart; every footprint inside
  the room; `inRoom`/`petFloor`/`safeCell` false when closed; `fromData` on a fake `CliffDenData.den` gives five bays,
  four lanterns, the sign, a room box; invalid data gives nil; `current()` picks `room` only with `CliffDen`.
- `DenGreybox.spec.lua`: parts under 60, every light range 14 / no shadows, colliding pieces all have footprints.
- `DenHost.spec.lua`: live mount nil; open records and clears the blocker; close restores it, evacuates players in
  the room (and not those outside), rescues pets in it; Hush open refuses; 3 errors close; rebuilt lounge.
- `DashAnchor.spec.lua`: pick; den rule (in, out 1.9 s stays, out 2.1 s strays, closed); meadow rule equals `DashRing.rule`.
- `DashHost.spec.lua` (added cases): den join from inside the room; den gather seat strays after leaving; den closed
  drops waiters `Closed`; countdown checks den seats in the room; `hop` refused when nothing gathers / wrong band;
  `anchor` in packets; **every existing case unchanged with `d.den` nil.**
- `DashClient` pure `promptState` matrix (den on/off x phase x seat/queued/waiting).
- `ThingsPage.spec.lua`: the den row first with `ctx.den`; rows unchanged without it.
- `PetFloors.spec.lua`: equal to the old expression with den nil, over a 4-stud grid and every Hush/Tier flag pair.

---

## 6. Studio probes (in Play; Edit has no world)

| Probe | What |
|---|---|
| P1 | `/den on`: blocker off (collide, query), walk in; rays for floor, roof over each piece, back wall, the lintel's real y (the sign hangs under it); captures from the mouth and the back wall at 1280 x 720 and 844 x 390, noon and night. |
| P2 | Prompts: the R8 116-point grid across the floor: never two E prompts; the pet's inspect prompt vs gate/table. |
| P3 | Pet follows in (two pets), wanders, never stands in furniture; catch-up landing in the den; leash out at the mouth. |
| P4 | Dash from the den: Fun alone, gather, countdown, race, results; the avatar stays in, the camera comes back to it. Time Trial from the den. |
| P5 | Two players: one picks in the den, one hops at the meadow ("Join race" only while gathering; hidden idle and live). Stats band mismatch hop refused with a toast. |
| P6 | Stray: walk out of the den while waiting: "You left the line." after about 2 s. |
| P7 | `/den off` with two players and pets inside, one in a gather seat: moved out, blocker colliding again, toast, model gone. |
| P8 | Table: round starts, difficulty picker as today; table while waiting asks first. |
| P9 | Board: Things to do opens on its page; board text rows. |
| P10 | Things: the den row's trail ends at the mouth; the Dash row's target follows the phase. |
| P11 | Four lights at night; frame time with the den in view on the phone emulator. |
| P12 | Live safety: the launch project in Studio with the injected live place: no `PlayDen`, blocker colliding, no `Den_on`, meadow "Race" with the picker. |
| P13 | Gamepad and touch on gate, table, board. |
| P14 | Tier and den both open: foot, mouth and the two evacuation spots. |

---

## 7. Step B: snapping to the enlarged room (island session's names)

When the beta pack lands, the server sets `CliffDen` at start and `DenLayout.current()` resolves from
`CliffDenData.den`: room = `den` polygon and the `PlayDen` region box; floor = `den.floorY`; roof samples from
`den.roofY` (probe the arch and lanterns under it); mouth = `den.mouth` (`x1`, `x2`, top, z line); sign = the lintel
anchor; lanterns = the four anchors; bays along the back wall line (or the named bays below). Parts `W7_CD_PlayDen__*`
and `W7C_CD_*` need no code (they are island parts). No den number is in code for step B.

**What I need from the island session that the scope does not give yet:**

1. **A mouth closer while the den switch is off.** The scope says `caveBlocker` is "off on the beta". With the room
   always present on a `CliffDen` server, the den switch must still close it. Ask: keep a box named **`CaveBlocker`**
   on the beta at the **new** mouth (x about -16..2, the mouth's z line, y 3 to top + 6), built as today, so DenHost
   toggles it exactly as in step A. The back-wall stop is a separate always-on box (its own name).
2. **Five named bay anchors** `den.bays[1..5]` = {position on the floor, facing}, so Fable's layout (two bays on the
   side walls, three on the back) is kept; the back wall line alone puts all five on one line.
3. **A doorstep** `den.doorstep` (lawn in front of the mouth, inside the home Floor z > -90) for the switch-off move
   and the pets' landing, and a **mouth pin** (ground at the mouth's middle) for the trail. The scope's `evacuate`
   (-27, -84) is the tier's.
4. **The notice board's spot** outside the right jamb (about (3, -96)), with its ground y.
5. **Ground rays:** confirm the den floor (and the apron) answer the server's rays (`Include EggDropLounge`,
   `RespectCanCollide`) at `floorY` +- .1, as the lawn tiles do; the scope's note that `W7C_` filters keep collision out
   of floor rays must not apply to these.
6. **Walk data:** the walk-grid patch inside `HollowWorldLayout.groundY` covering the den floor and apron (pets'
   `onGround`), and the beta `IslandGround` with the den floor as safe cells (or say it is not, and the den keeps its
   own `safeCell`).
7. **Roof clearance:** `roofY` at each bay (the gate arch is 6 high, lanterns at 7 to 9).
8. **The version stamp** check (a spec) that `CliffDenData` matches the data `DenLayout.fromData` was written for.

---

## 8. Risks

- **The pocket is cramped** (9 x 12 of floor): two prompts, paw stones and a waiting crowd overlap. It is a greybox
  for the idea; eight racers waiting in it will stand on each other. Step B fixes it.
- **The race camera from inside a cave:** the gate shot and the race cut to the meadow; the cut back lands under a
  roof 11 to 14 with `CameraClamp` pulling in. Probe P1/P4 on the phone.
- **Prompt fights** with the pet's own E prompt and the station priority code (`JournalPromptPriority` only knows
  stations).
- **The pet floor refactor** touches four live call sites. Guarded by the equality spec and by keeping the den
  argument nil on live.
- **Evacuating a racer**: moving a `dashHeld` avatar mid-race is new for Dash (Hush refused passages while racing but
  its close moved everyone). The race itself never reads the avatar after the countdown; check the camera hand-back.
- **Step B swap is start-only**: a server started before the pack is promoted keeps the pocket variant until it
  restarts. Fine on the beta (restart on publish).
- **Copy changes** need the translation steps before the beta publish.

---

## 9. Questions for the architect

1. Anchor picked by the server from the root's position at the join (my pick), not a client hint. Agree?
2. Den waiting rule: the room box, out 2 for 2 s strays, **no clamp** (the rock walls are the rope). Or a paw-stone
   ring clamp like the meadow?
3. Meadow `hop`: refuse instead of queueing (`Missed` / `WrongBand` / `Full`). Or let a hop queue like today?
4. Fable suggested keeping the full picker at both for one build; Spencer chose "Join race" only. I follow Spencer:
   `/den off` brings the picker back at once, which is the fallback. Agree, or a second key `play_den_meadow`?
5. The gate shot (camera on the course) while the picker is open in the den: keep it (shows where the race is) or
   keep the camera in the den?
6. Default: missing `play_den` = off (Tier today). Or on, for the beta testers?
7. `PetFloors.ok` as one shared helper replacing the four inline copies: worth the refactor now?
8. Things to do: the den row first (spec) pushes Dash to row 5 and scrolls on the smallest phone. First, or after Deck?
9. Furniture colliding for players plus footprints for pets (my pick), or all non-colliding like the Dash props?
10. Evacuate racers on `/den off` mid-race (my pick, the floor closes), or hold the close until the results?
11. Board text in step A, or wait for A2's board art?
12. Music duck inside (about 50%): leave for A2 with the sound (my pick)?
