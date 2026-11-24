# Nest corner, nest words, trail pin, race line, world feel: build plan (Opus, 2026-11-23)

Step 1 of the review-driven build: **plan only, no `src/` changes.** Spec: Fable's `WORLD-AND-NEST-LOOK.md` (sections
2, 3, 4, 5), approved by Spencer ("sure build it"). That file is still untracked in the main checkout; it should be
committed with this plan (the coordinator's call). QA source: `FEEDBACK.md` items D1, Q2, Q1, F2, W4.

Scope: **D1, Q2, Q1, F2, W4 (not life, not Aero).** Beta only, behind the existing ceilings: the nest work behind
`Onboard.ceiling()` / `Onboard.on("nest")`, the trail behind `Things`, the race line behind `Dash.ceiling()` /
`Dash.on()`, and W4 behind a new beta switch (question A5). Not touched: GardenLife, LifeSim, LifeArt, Wind,
TomorrowStrip, Kit*, AeroWorld, AeroFalls, AeroKit, AmbientAudio, WorldAero.

Baseline: `python scripts/run_dash_server_specs.py ".../build/luau-cli/luau.exe"` is green on 7fa744b (every spec,
including NestSpot 4, NestClient 15, ThingsTrail 8, DashHost 22, DashDirector 26, DashClient 27, GardenHour 17).

---

## 0. What I measured before planning (offline, no Studio)

**The nest candidates** (Fable's formula, exact `f` and `e`; scratch check against HollowWorldLayout, WorldDressing,
WorldAero fireflies):

| | Root (x, z) | Prompt point | Eggs station | Journal | Customize | Arrival line | Plaza middle | Nearest flower |
|---|---|---|---|---|---|---|---|---|
| A (today) | (-17.50, -2.50) | (-20.08, -2.81) | 15.95 | 12.51 | 29.23 | 12.88 | 12.59 | 5.71 |
| **E1** | **(-25.27, -9.80)** | **(-26.92, -7.78)** | **5.85** | 9.77 | 20.74 | 14.59 | 7.48 | 12.19 |
| E2 | (-36.16, -8.24) | (-34.02, -6.77) | 5.85 | 20.32 | 9.87 | 13.71 | 7.48 | 11.10 |

- The prompt point at E1 is **5.2 studs from the Eggs station's centre**. The station's own prompt (`BrowseEggs`, on
  `EggsSign` at the station centre, LoungeWorldV7Art) has reach **7, not 9** as the spec says, so both prompts are in
  reach at the nest's front. Both use E / ButtonX, `OnePerButton`. Roblox will show one; Fable's `[check]` stands.
- **The Bear's curl spot at E1 lands on the station.** `BearSpot` (2.2, 0, -1.4) root-local is world (-27.87, -10.09),
  **3.3 studs from the station centre**: almost certainly on its dais. At E1 the station is on the nest's **+X**
  (right) side, so mirroring the curl to (-2.2, 0, -1.4) (world (-24.44, -7.32), 7.7 from the station) is needed, and
  then Fable's own fallback puts the sign on +X: **between the nest and the station**, not on the outer side. Today's
  sign (root-local -1.95, -1.03) is on the outer side at E1 (7.8 from the station) and is fine where it is; the
  trouble is that the curl spot and the sign are on opposite sides by design, and only the outer side has room.
  Question F1 below.
- Shot 4: the gold-pinned pedestal is the Eggs station (the marker carries `attract_icon_eggs`). Fable's `[check]` on
  "which thing is the pedestal egg" is answered: E1 puts the nest beside the station display.

**The rope ring does not fit round today's pad.** Scratch check with `build_dash_course.py`'s own walk map, ground,
`OBSTACLES` and `half_width` (`scripts/build_dash_course.py` rules: level lawn, 1 stud off every lane, 0.5 off every
obstacle, 4 from the cliff):

| Ring centre | R | Walk-map codes | Ground span | Line clear (need R + 1) | Obstacle edge (need R + .5) | Result |
|---|---|---|---|---|---|---|
| (66, -21) today | 4.0 | G P **R** | .21 | 7.57 | **3.08** | fails: the ring runs through the meadow tree and its rocks (72, -22, r 3) |
| (66, -21) today | 3.2 | G P | .17 | 7.57 | **3.08** | fails: the obstacle's edge is 3.08 from the centre, inside 3.2 |
| (65, -21) | 3.2 | G P | .20 | 7.98 | 4.07 | passes |
| **(64.5, -21)** | **4.0** | G P | .22 | 8.10 | 4.57 | **passes** |
| (64, -21) | 4.0 | G P | .21 | 8.23 | 5.06 | passes (most room) |

A ring that is not centred on the pad (pad at 66, ring at 64.5) puts the pad's east edge on the rope. So F2 needs
**the pad to move 1.5 studs west**, or a smaller ring with a 1 stud move. Question F2-1.

**Who writes Atmosphere today** (W4 haze): three writers, last one wins.
1. `HollowClock.environment` / `Clock.island` (client, the 5 s pass): fixed `Density` .16 to .20. Only matters with Aero off.
2. `AeroWorld:paint` (client, Aero on): writes `look.Atmosphere`, where `look` is `GardenHour.at(...)` while the garden
   hour is on, else the constant `WorldAero.Atmosphere` (Density .28).
3. Server `LoungeWorldV7Art.lighting` / `LoungeArt`: creates it at build.

So on the beta (hour on, Aero on) the values come from **GardenHour** (the four phase holds and the blend), and
AeroWorld only writes them. The haze change can live in `GardenHour.at` without touching Aero. With the hour off the
value is `WorldAero.Atmosphere`, which is the other session's: **I will not cover that path** (A6).

**Today's values** (W4 `[check]`s): no code sets `CameraMaxZoomDistance`, `CameraMinZoomDistance`,
`CharacterWalkSpeed` or `Humanoid.WalkSpeed` (only PetFocusUI saves and restores it), and `default.project.json` sets
only `DevCameraOcclusionMode`. So they are the place file's StarterPlayer values: probably 128 / 0.5 / 16, to be read
by probe P4. The arrival camera is world-space `+ (5, 6, 12)` in two places in RoomView (lines 837 and 939): 24.8
degrees down. Fable's (4, 3.5, 11) is 16.6 degrees.

**Tree and rock assets** (W4 islets and sightline clumps): the island's trunks are merged meshes
(`W7_Trunks__bark`). Single tree crowns and rocks exist only as **AeroKit** templates (ReplicatedStorage.AeroKit, Aero
ceiling, another session's). `WorldAssets.Dressing` holds only the three low frond bushes (about 1 to 2 studs tall).
**There is no standalone tree today.** Question W4-2.

---

## 1. D1: one place for eggs

### Files
- `src/shared/Nest.lua`: `Nest.Spot` to E1 (y stays the walk map's 4.07 until probe P1 says otherwise), `Nest.Facing`
  unchanged (-30, 4.07, -4). Comment block rewritten (E1, why, the probe), fallback E2 recorded.
- `src/client/NestClient.lua`: `Client.Prompt` 6 to **4.5**; `BearSpot` and the sign per question F1; `SignYaw` mirrored
  if the sign changes side (+40); the egg's tuck lean already reads `BearSpot`, so it follows.
- `src/server/LoungeWorldV7Art.lua`: nothing to change. The `SleepyNest` blocked box is built from `Nest.Spot` /
  `Nest.Facing`, so it follows.
- `src/client/StationAttract.lua`: `labelText("Eggs", intro)` reads `r5.station.EggsNest.*` while `Onboard.on("nest")`
  (needs a small dep or a direct `Onboard` require; StationAttract is in the offline client set, so it stays pure).
- `src/client/EggHatchView.lua`: the "Napping egg" row (below).
- `src/client/init.client.lua`: wire `nurseryView.nest = {row = fn, show = fn}` inside the nest mount block (the
  `nurseryView.appearanceFor` pattern: the view is built long before the nest mounts).
- `scripts/probe_nest_spot.luau`: rewritten (P1).
- `scripts/NestSpot.spec.lua`, `scripts/NestClient.spec.lua`: updated (section 7).

### The napping egg row on Hatch eggs
- **Model (pure, in NestClient so it is tested offline):** `Client.menuRow(summary)` returns nil without a nest, else
  `{title = onb3.nest.title, clock = Client.clock(left), ready = bool, label = <accessible text>}`.
- **Render (EggHatchView.renderBody):** one row above the `liveOrder` loop, only while `self.nest` is set and
  `self.nest.row()` answers. Quiet style: no lip, `well` background, the nest chip icon (`NestClient.Assets.chip`),
  the title left, the clock right (gold `stars` paint and "Hatch me!" when ready). Height 44 px phone / 56 px desktop;
  the phone row-height formula's `fixed` adds it so the egg rows still fit the window.
- **Tap / A:** `self:close("nest")` then `self.nest.show()` (the Show me trail to the nest). A new close reason
  `"nest"` so `onRouteChanged` / `onAccepted` do not reopen the Pocket menu (that would stop the trail at
  `Trail.MenuGrace`). Question D1-2.
- **Gamepad:** the row is `Selectable`, first in the list's order; `SelectionGained` does **not** select an egg recipe
  or repaint the pane. `restoreBodyFocus` keeps working because the row has a stable name (`NestRow`).
- **Clock refresh:** only while the screen is open and the row is showing, the row's clock text is rewritten once a
  second (text compare, no relayout). Minutes resolution only shows under an hour.
- **Opened from the Pocket Deck (Board mode):** the trail cannot run outside Room mode. The row still shows the clock
  but is display-only (no chevron, not selectable) there. Question D1-2.

### Copy
- `r5.station.EggsNest = {name = "Eggs", line = "Hatch new friends. Your napping egg waits here too."}`. **Flag for
  Fable:** the paid eggs on that screen hatch toys, looks, materials and stat eggs, not pets, so "Hatch new friends"
  promises something the station does not sell. Suggest `Hatch toys and looks. Your napping egg waits here too.`
  (320 px check either way).

### Edge cases
- **Existing saves with an egg tucked at the old spot:** the nest's position is never saved (`Nest.lua`: `at`, `n`,
  `gift`, `tucked`, `pet` only), and NestClient draws at `Nest.Spot` on every join. A tucked egg simply appears in
  the new corner, still tucked, same clock. No migration. A server publish restarts every server, so nobody sees it
  move mid-session.
- **The Bear's paw-print need (`needNest`), the HUD chip, the strip and the tip** all read `clientUI.nestPlace()`
  (the prompt point), so they follow. `onb3.tip.nest` was already marked for most testers; nothing re-fires.
- **Two players:** the nest is drawn only on its owner's client, so two players at the corner each see their own egg
  in the same place, and each has their own prompt. The pets' blocked box is server-wide and does not depend on who
  has a nest.
- **Pets:** the 4.2 box now sits 5.85 from the station centre. Pets walking to the station's care spots, a catch-up
  landing beside a player at the station, and leaves and bubbles (`LifeSim.Keep.station` 8) are fine; NestSpot.spec
  measures the catch-up ring at the prompt point as today.
- **Deck rounds and races:** unchanged (the prompt needs `free()`; the label hides on the focus camera).
- **Phone:** the prompt's 4.5 reach on a thumbstick is about a stride; checked in P2.

---

## 2. Q2: one calm line at the nest (NestClient)

### Structure
- Delete `InsidePill` and its board growth (`SecondWidth`, `secondLine` stays as pure helpers used by rows 5 and 6).
- Delete the first tuck-in's rail toast in `pose()` (`self.d.toast` there). The reward toast (`onb3.nest.got`) stays.
- One `BillboardGui` **220 x 80 px**, `LightInfluence` 0, `MaxDistance` 60 (backstop), the pill bottom-anchored at
  `Position (0.5, 0, 1, -lift)`, `lift` = 0 or **34** (row 4 with the bubble). `StudsOffset` lowered by the 34 px
  headroom's share so a one-line pill sits where today's does. Text never jumps when it changes lines.
- Pill: cream (gold when ready), ink 2 px stroke, padding 12 each side, **max 220 px**, wraps at **196 px**,
  14 px for the clock and "Hatch me!", 13 px for sentences, **2 lines max**, 28 px tall for one line, 46 for two. If a
  sentence needs three lines at 13 px, it drops to 12 px. Line count from a new dep `measureBox(text, size, width)`
  (TextService:GetTextSize with the 196 px frame), not today's 1.15 fudge; specs pass a stub.

### The row table (pure: `Client.row(view, ctx)` -> `{key, text, size, gold, onTop, near, full}`)

| # | When | Text | Holds | Shows within (fade from) | AlwaysOnTop |
|---|---|---|---|---|---|
| 1 | beat: first tuck-in ever | `onb3.nest.tuckedFirst` | 6 s | 18 | true |
| 2 | beat: later tuck-ins | `onb3.nest.tucked` | 4 s | 18 | true |
| 3 | beat: a new egg landed | `onb3.nest.next` | **5 s** (was 3) | 18 | true |
| 4 | ready | `onb3.nest.ready`, gold | while near | 18 (18 to 15) | false |
| 5 | untucked, `n == 0` | `onb3.nest.how` | while near | 12 (12 to 10) | false |
| 6 | within 8 studs, `n >= 1` | `onb3.nest.inside` / `insideStars` | while near | 12 (12 to 10) | false |
| 7 | otherwise | the clock (`onb3.nest.hours` / `minutes`) | while near | 12 (12 to 10) | false |

- `ctx` = `{beat, clock, near (studs, player root to nest root), now}`; "untucked" counts `self.tuck` as tucked, so
  the explainer goes the moment the prompt is pressed.
- **Beats:** rows 1 to 3 fade in 0.25 s and out 0.4 s. The tuck-in beat still starts at `TuckSeconds` (2.6 s, after
  the gift peek). Between the press and the beat the gift peek is up: the pill **hides during the peek** (it sat under
  the peek tile today).
- **Fade:** `t = clamp((d - full) / (near - full), 0, 1)` written to the pill's `BackgroundTransparency`, its
  `UIStroke.Transparency` and the label's `TextTransparency`; `Enabled = false` past `near`. Distance is the
  player's root to the nest root (`deps.root()`), not the camera.
- Halo `MaxDistance` 120 to **80**, StillZ 80 to **40**.

### The need bubble
- New dep `bubble()` -> `{shown = bool, pet = Vector3?}` read lazily (the needs block mounts after the nest).
- Rows 5 to 7 hide while the bubble is shown and the pet is within **6** studs of the nest root.
- Row 4 with the bubble: both show, the pill lifts 34 px.
- **Beats hold the bubble back:** `Client:holdsBubble()` is true from a beat's start until 0.3 s after it ends.
  The bubble wrapper in `init.client.lua` (the `bubble` table round `NeedBubble.new`) keeps the wanted
  `{icon, visible}` and applies `visible and not nest:holdsBubble()` in its `step`, so BearNeeds and NeedBubble are
  untouched and the bubble comes back by itself.

### Edge cases
- **Two pills never coexist** because there is one. The peek tile and the "+N" float are beats, not pills.
- **Phone (`compact`):** 13 px for the clock too, as today. The 12-character pet name case is a spec row.
- **Pet focus camera:** label off, as today.
- **Reduced Motion:** fades are instant (transparency snaps), no lift tween (the lift is a jump, it is not animated
  anyway).

---

## 3. Q1: the Show me pin (ThingsTrail, every destination)

- `Trail.PinNear = 28`, `Trail.PinFull = 22`, pin **150 x 48 px**, plate 34 px tall, text **15 px fixed**
  (`TextScaled` off, so a long name wraps inside 150 px instead of growing), pointer 14 px.
- `Trail.pinAlpha(distance, way)` pure: `clamp((d - 22) / 6, 0, 1)`, applied each step to the plate's background,
  text, stroke and the pointer; `gui.Enabled = false` past 28. `AlwaysOnTop` stays true inside 28.
- **No dry way (`Way == "none"`): the pin shows at any distance**, as the only guide (it is today's behaviour for
  that case, and the paw prints cannot carry it). Question Q1-1.
- Started on the spot (within `Arrive` 8): unchanged, the pin shows for `Near` 3 s.
- The trail ends at `Arrive` (8 studs), so the pin is fully visible only from 22 to 8.
- **Nest pin text:** a new key `onb3.nest.pinReady = "Hatch!"` (not `nest.hatch .. "!"`: a joined string cannot be
  translated) when `clientUI.nest:summary().ready`, else `onb3.nest.title`. Used by `things.show("nest")` and by
  BearNeeds' `place("Nest")` (one helper in init.client.lua).
- Other destinations (park, finds, Dash) get the distance rule too. `[check]` in Studio that no first-visit step
  leans on a far pin: the Bear's auto trail to Eggs is the one to watch (it starts near the plaza, so it is inside 28
  for most of its length).

---

## 4. F2: the race line

### The pad and the ring (needs F2-1 answered first)
- Recommended: move `PAD` in `scripts/build_dash_course.py` to **(64.5, -21)**, keep `PAD_RADIUS` 2.5, add a
  `RING_RADIUS = 4.0` constant with its own checks (the pad rules at R: level lawn, ground span <= .3, R + 1 off the
  line, R + .5 off every obstacle, `CLIFF_ROOM`). Rerun the builder; the diff must be the `Course.Pad` row only (the
  course points are all "F"; if anything else moves, revert and hand-edit the one row, then `--check`).
- Everything else reads `Course.Pad`: DashMount (wait pad, sign), DashClient (gate sign, prompt), DashHost
  (`Mount.gate()` for every reach), Things (`dashGate()`). DashCourse.spec / DashGrid.spec re-run.
- **Studio check:** the "after Done" camera line that put the pad at (66, -21) (the north start post 6.6 studs off
  the line) has to be re-captured at 64.5 (P7).
- Fallback if Spencer or Fable prefers the pad where it is: (65, -21) with R 3.2.

### Look (new client module `src/client/DashLine.lua`, picked up by the spec runner's `Dash*.lua` glob)
- 10 stakes 0.16 x 1.0 x 0.16 round R, sunk 0.1, leaning out 4 degrees, yaw from a hash, Wood **#6B4A2B**; a chalk
  cap part 0.17 x 0.12 x 0.17 **#E9E2C8** on each (10 more parts). One Attachment per stake top.
- 10 Beams stake to stake: width 0.11, `Segments` 8, `FaceCamera` true, texture `rope.png` tiling, **#B79A66**,
  `LightEmission` 0, `LightInfluence` 1. Sag: both attachments' axes point down; a cubic Bezier's midpoint drops
  0.75 x CurveSize, so `CurveSize0 = s`, `CurveSize1 = -s` with **s = 0.22 / 0.75 = 0.293** (sway: 0.34 / 0.75 =
  0.453).
- One ground plate 9 x 9, 0.04 over the lawn, Decal `queue-ring.png`.
- All local, anchored, no collide / query / touch, `CastShadow` off. About 21 parts + 10 beams + 20 attachments,
  its own pool (not DashProps' 60).
- Textures: a new `scripts/draw_race_line_textures.py` (rope 128 x 32, ring 256 x 256, script-drawn), uploaded like
  the life textures, ids in a small table in DashLine with fallbacks (rope: no texture, plain colour; ring: no decal).
  Not in LifeArt (another builder's file).
- **Shown** to everyone while `roster.phase == "gather"` or `#roster.queue > 0` (the roster attribute every client
  reads). Rise: stakes come up over 0.45 s (ease out, 0.05 s apart round the ring), the rope fades in over 0.3 s after.
  Sinks the same way **2 s** after the line empties. Reduced Motion: fade 0.3 s, no rise. AliveBudget level 2: no
  rise either (static show / hide).

### Walls: client-side invisible walls (decision, A3)
- **Recommended: walls on the queued player's own client only**, not collision groups. The local character is
  simulated by its own client, so client-only anchored `CanCollide` parts stop it and nobody else; nothing replicates;
  no collision group registry, no per-part group bookkeeping on respawn or accessories. Collision groups would not be
  more secure: the character is client-owned either way, so the server distance rule is the real authority.
- 10 boxes, one per span chord, 0.4 thick, **12 studs high (not 6)**: a default jump lifts the feet about 7.2 studs,
  so a 6-stud wall can be jumped. `CanQuery` false (the camera clamp and the trail's raycasts ignore them),
  `Transparency` 1.
- On while this client is waiting (in the line, or holding a gather seat: question F2-2) and its root has once been
  inside **R - 0.6**; off at once on leave, removal, countdown (`held()`), death, respawn, a missing root, Dash off.
- **Pushing the rope:** while walls are on, if the root is within 0.6 of a wall and `Humanoid.MoveDirection` points
  out (dot > 0.5), the two nearest spans sway (s 0.293 to 0.453 and back, 0.5 s eased) and the rail line pulses once
  (1 to 1.06 to 1 over 0.3 s), at most every 4 s. Reduced Motion: the pulse only. The pulse needs a small
  `handle:pulse()` on NotificationRail status handles.

### Server: the stray rule (DashHost, DashDirector)
- `Host.LineReach = RING_R + 2.5` (6.5), `Host.StraySeconds = 1`.
- In `Host:check(userId, "queue")` (the line, every `CheckEvery` 0.5 s) and a new stage `"gather"` (question F2-2):
  - `board.dashInside` turns true the first time the root is within R of the pad.
  - Before that, today's rule (QueueReach 16): **a player who joined from the prompt 10 studs out is not removed for
    walking in**, and a player who cannot get in because the ring is full is not removed either.
  - After that, beyond `LineReach`: `board.dashStrayAt` starts; at 1 s the check fails with reason **`"Strayed"`**;
    back inside clears it. Both fields clear on leave, removal, seat change and board close.
- `Director:checkAll`: while `heat.phase == "gather"`, seated players are checked with `"gather"` instead of `"seat"`
  (seat stays the cheap check for countdown and race).
- Client: `refused` with reason `"Strayed"` notifies `dash.line.left` ("You left the line."), not a `dash.reason.*`
  key, so the same sentence is not translated twice.

### Leaving: the rail line and the confirm (DashClient)
- `gatherLine`: while queued, `dash.queue` (new text) **with `activate`** and the chevron; while holding a gather seat,
  the gather line, also tappable (F2-2). The status handle is created with `activate` set, so the ticket is tappable
  from its first frame (`Rail.tappable` is read when the ticket is laid out; I will check whether `update` re-lays it).
- Tap: `ConfirmDialog.ask` with `title = dash.line.title`, `line = dash.line.line`, **`confirm = dash.line.no` ("Stay
  in line": the primary key on the right, Enter / A) with an empty `onConfirm`**, and **`alt = {text = dash.line.yes,
  onSelect = leave}`** (the quiet left key, X / ButtonX). B, Esc and a tap on the shade cancel = stay. This gets
  Fable's "Stay is the default, Back closes as Stay" without changing ConfirmDialog (it adds the round close key the
  `alt` mode always has). Question F2-3.
- On Leave: `send("leave")` (the existing lane: never refused, never throttled behind a join), walls off at once,
  toast `dash.line.left`. The server already handles `leave` for the line and for a gather seat.
- `askLeave` (opening the Pocket Deck): while queued it now asks the same question (today it leaves silently); a held
  race keeps `dash.ask.*`.
- **Gamepad / keyboard path:** the rail is not reliably reachable with a pad. Proposal: while waiting, the gate's own
  prompt (on the sign at the pad centre, reach 10, today disabled while queued) turns back on as **"Leave line"**
  (`dash.line.prompt`) and opens the same confirm. Question F2-4.

### Copy
| Key | Text |
|---|---|
| `dash.queue` (changed) | `You're in line. Tap to leave.` |
| `dash.reason.Queued` (changed) | `You're in line for the next race!` |
| `dash.line.title` | `Leave the line?` |
| `dash.line.line` | `You'll lose your spot for the next race.` |
| `dash.line.yes` / `dash.line.no` | `Leave` / `Stay in line` |
| `dash.line.left` | `You left the line.` |
| `dash.line.prompt` (if F2-4) | `Leave line` |

### Edge cases
- **Two players:** each has their own walls; two avatars and two pets fit at R 4. **Crowding:** characters collide
  (no collision groups in the game), and a ring of R 4 holds about 6 to 8 avatars. Eight gather seats plus a line of
  up to 24 cannot all stand inside. The "entered once" rule keeps those outside under the old 16-stud rule, so nobody
  is removed for a full ring. Question F2-5 (cap or accept).
- **Respawn / death while waiting:** the new character is far away; the stray rule removes them after 1 s with
  `dash.line.left`; walls are off on the new character.
- **Deck round:** opening the Deck asks first; the Deck itself fails the `"queue"` check (`"Deck"`) as today.
- **Promotion from the line into a race:** the line player is inside the ring, so the `"Closer"` path is rare now.
- **Race in progress with a line:** the ring stays up (the queue is not empty) while racers run 8 studs off it.
- **Phone:** the rail line at 320 px: "You're in line. Tap to leave." plus the chevron; the confirm at 320 px.
- **The pet:** stays free (Fable's fallback). The pet's roam is server-planned (GardenState); a "stay at the pad"
  spot would be a GardenState change for one beat. Say so to Fable.

---

## 5. W4: the world feels bigger (no life, no Aero)

Order (cheapest first, Fable's): W4a camera and zoom, haze, walk speed; W4b far islets and sightline clumps, **only
after W4-2 is answered** (they need assets this repo does not have).

### W4a
- **New shared `src/shared/WorldFeel.lua`** (pure): `Arrival = Vector3.new(4, 3.5, 11)` (today's
  `Vector3.new(5, 6, 12)` kept as `ArrivalOff`), `MaxZoom = 22`, `Walk = 14` (spec-pinned never under 13),
  `HazeDensity = 0.05`, plus `on(feature)` over the switch (A5).
- **Arrival camera:** RoomView's two arrival placements read `WorldFeel.arrival()`. The second one is inside the
  `enterDash`..`retryArrivalPlacement` span that `run_dash_server_specs.py` cuts into `RoomViewDash`, so the runner's
  stub header gains a `WorldFeel` local (or the offset lives on `Room.ArrivalOffset`, set once at the top of RoomView
  and in the stub). FOV stays 65.
- **Zoom cap:** client, `LocalPlayer.CameraMaxZoomDistance = 22` while on, back to the StarterPlayer value when off
  (read once at start). Only the Custom camera is affected; DashCamera, the focus shot and the Deck are Scriptable.
- **Haze:** `GardenHour.at` adds `HazeDensity` to `out.Atmosphere.Density` (after the cover term, under its
  `MaxDensity`) when a `haze` option is passed; HollowClock's controller passes it from the switch. Off = byte-for-byte
  today (GardenHour spec parity row). Covers the beta (hour on). Hour off + Aero on = `WorldAero.Atmosphere`: not
  mine (A6).
- **Walk speed:** server. On `CharacterAdded`, and on a switch flip for every live humanoid, set `WalkSpeed` to 14
  (on) or `StarterPlayer.CharacterWalkSpeed` (off). PetFocusUI saves and restores whatever is there, so it carries 14.
  Checked against: pet follow (`GardenLayout.WalkSpeed` 4, catch-up), the trail's 20 s, the Dash join reach: all fine
  at 14.

### W4b (blocked on W4-2)
- **Far islets:** 4 static shapes at 260 / 340 / 450 / 600 studs, colours mixed toward the sky by 25 / 40 / 55 / 70%.
  Plan: the server copies one rock template into ReplicatedStorage under the ceiling; a client module clones four
  scaled copies while the switch is on (so the switch works at runtime). Needs a rock mesh of at most about 300
  triangles: the AeroKit falls rocks are one merged vertex-coloured mesh, not reusable. **Ask Fable / the island
  session for one rock-and-grass islet mesh.** Night: the fixed sky mix will read bright after dusk; the haze carries
  some of it; capture at night.
- **Sightline clumps:** solid, so server-built with collision, a `GardenBlockedRegion` box each (LoungeWorldV7Art),
  the walk map re-swept, finds, catch-up and the trail's pathfinding re-checked. Build-time only (behind the ceiling,
  not a runtime switch: pets' blocked regions are built once). **Spot (2) collides with the race line:** 15 studs before
  the plaza on the arrival route is about (-18.3, 13.4), which is the course point (-18.95, 14.33) and the trail's
  west approach; the clump must keep `KEEP` 6 off the course, so it moves. Spots need a top-down pick by Fable plus an
  offline check script (walk map, course, finds, stations, lamps), like `build_find_spots.py`.

---

## 6. Studio steps (I cannot use Studio; the coordinator runs these)

| # | Probe | Mode | What it answers |
|---|---|---|---|
| P1 | `scripts/probe_nest_spot.luau` (rewritten): candidates A, E1, E2 in one run, each with the 16-ray ring at r 2.6 and three heights, the prompt point's floor, the Bear curl spot both ways (ray down: station dais or marble?), the sign's spot both sides, and 9 points along the hub-to-Eggs walking line (one ray each, nest box clearance). Read-only. | Edit | E1 or E2; F1 (curl and sign side) |
| P2 | Stand between the station and the nest (about 3 studs from each), turn slowly, on keyboard, pad and phone | Play | prompt contention; drop nest reach to 3.5 if it flickers |
| P3 | Nest captures (Fable section 8 D1 and Q2 lists) | Play | review |
| P4 | Print `StarterPlayer.CameraMaxZoomDistance`, `CameraMinZoomDistance`, `CharacterWalkSpeed`, `Lighting.Atmosphere` values, `HollowClock.hourOn()`, the Aero switch | Play | W4 `[check]`s |
| P5 | List `ServerStorage.WorldAssets` (WorldV7, Dressing) and `ReplicatedStorage.AeroKit` children with sizes | Edit | W4-2 |
| P6 | `scripts/probe_dash_ring.luau` (new, read-only): 32 rays out from the chosen centre at .5 / 1.5 / 2.5 studs to R + .5, and a ground ray at each stake | Edit | the ring is clear of merged meshes the walk map blurs |
| P7 | After Done, the camera line past the start post with the pad at 64.5 | Play | the pad move did not undo the beta 12 fix |
| P8 | Queue with two clients (Studio's 2-player test): walk in from the prompt, push the rope, jump at it, die, tap the rail, pad path | Play | F2 |
| P9 | Shot 1's view before and after camera, zoom and haze; walk speed feel | Play | W4a for Fable and Spencer |

---

## 7. Specs (offline runner unless marked Studio)

- **NestSpot.spec** (rewrite): E1 numbers; Eggs station 5.5 to 6.5 (part of the corner), Journal >= 9, Customize >= 18,
  arrival line >= 9, the hub-to-Eggs line >= Block / 2 + 1, the prompt point >= 4.5 from the station centre
  (the prompts' distance rule), flowers, fireflies, the blocked box (beta, Studio, live off, flag off), the catch-up
  ring at the prompt point.
- **NestClient.spec** (extend, 15 cases today): the spot; `Client.row` for each of the 7 rows and their precedence;
  fade at 20 / 12 / 11 / 10 / 4 studs (rows 5 to 7) and 18 / 15 (row 4); the need bubble hide rule and the 34 px lift;
  `holdsBubble` through a beat and 0.3 s after; no `InsidePill`; no rail toast on the first tuck-in (the reward toast
  still fires); the pill hidden under the peek; prompt reach 4.5; halo 80, StillZ 40; two-line wrap at 196 px with a
  12-character name; `menuRow` both states.
- **ThingsTrail.spec** (extend): `pinAlpha` at 30 / 28 / 25 / 22 / 10; `Way == "none"` shows at 60; size 150 x 48;
  the on-the-spot case unchanged.
- **DashLine.spec** (new, client): ring geometry (10 stakes at R, chords, sag s for 0.22), shown rule from rosters
  (gather, queue, idle; the 2 s sink), walls only for this client and only after entering R - 0.6, off on every exit
  path, the push detector and its 4 s limit, Reduced Motion paths.
- **DashHost.spec / DashDirector.spec** (extend): walk-in from 10 studs not removed; once inside, 6.4 kept, 6.6 for 0.9 s
  kept, for 1.0 s removed with `Strayed`; back inside clears; a full ring (never entered) keeps the 16 rule; gather
  seats checked with `"gather"`; leave from the line and from a gather seat.
- **DashClient.spec** (extend): rail line text and `activate` for line and gather; the confirm's keys (Stay primary,
  Leave on `alt`, cancel = stay); `askLeave` while queued asks; `Strayed` -> `dash.line.left`. The runner's
  `ConfirmDialog` stub gains `ask` (records the options).
- **DashOffParity / DashCrossVersion:** unchanged and must stay green (Dash off: no ring, no walls, no new reasons).
- **DashCourse / DashGrid:** after the pad move; the builder's `--check`.
- **GardenHour.spec** (extend): haze on adds 0.05 under `MaxDensity` in every phase and blend; off is identical.
- **WorldFeel** (new, tiny): the numbers and the switch's off path.
- **Studio only:** EggHatchView's napping row (the view needs the full Kit), StationAttract label at 320 px.
- After every build: `python scripts/export_localization_csv.py` (sync at publish, per AGENTS.md), and
  `V3-TEST-PASS.md` gets rows for D1 + Q2 + Q1 (switch `onboard_nest` / Things), F2 (`garden_dash`), W4a (A5's key).

---

## 8. Risks

1. **The pad move** (F2-1) touches a beta 12 camera fix and the course builder; the builder must not re-search the
   course. Mitigation: diff is the Pad row only, `--check`, P7.
2. **Prompt contention** at the egg corner (P2). Mitigation: nest reach 3.5, or the station prompt's `UIOffset` moved
   so the two never overlap on screen.
3. **The curl spot / sign side** at E1 (F1): building before Fable answers risks a second pass on the nest parts and
   NestClient.spec's sign-reading angles (they are measured from the arrival path's mouth, which moves relative to
   the nest).
4. **Billboard occlusion:** `AlwaysOnTop` false for rows 4 to 7 means the station machine can hide the pill from some
   plaza angles. That is Fable's intent; capture it.
5. **NotificationRail** is shared by every feature; `handle:pulse()` must be additive only (and the tappable re-layout,
   if `update` does not already re-measure).
6. **Walls are client-side:** an exploiter can delete them. Accepted: the server's stray rule is the authority, and
   leaving the line harms nobody but the leaver.
7. **W4b assets** do not exist; the islets and clumps cannot be built from this repo alone.
8. **Zoom cap 22** will feel tight to players who zoom out to find things; the Show me trail and markers carry that.
   It is a switch; Spencer judges.

---

## 9. Questions for the architect

- **F2-1 (blocking F2):** move the Dash pad to (64.5, -21) for R 4.0 (all builder rules pass), or (65, -21) with
  R 3.2, or keep the pad and shrink the ring below Fable's minimum of 3?
- **F2-2:** does "in line" include a **gather seat**? With no race running a join goes straight into a gather seat, so
  a line-only fence would almost never be seen on a quiet beta. I recommend yes: walls, the stray rule (new
  `"gather"` check stage) and the tappable rail line for both.
- **A3:** client-side walls (recommended) or collision groups?
- **F2-3:** the confirm via ConfirmDialog's `alt` (Stay = primary, Leave = alt, B = stay) without changing
  ConfirmDialog, accepting its extra close key? Or a new `quiet` option on ConfirmDialog?
- **F2-4:** the gate prompt as "Leave line" while waiting, for gamepad and keyboard?
- **F2-5:** a full ring: accept "never entered = old 16-stud rule", or cap the line?
- **D1-2:** a new EggHatchView close reason `"nest"` so the trail is not killed by a reopened Pocket menu; and the row
  display-only in Board mode (or wait for F1's route)?
- **Q1-1:** keep the pin at any distance when there is no dry way?
- **A5:** W4's switch: two new Onboard features (`feel`, `walk`, ConfigService `onboard_feel` / `onboard_walk`, the
  `/onboard` chat command for an instant revert), which ties them to Things being on, or a separate small config?
- **A6:** the haze only on the garden-hour path (GardenHour.at); the hour-off Aero path is WorldAero's owner's. OK?
- **W4-2:** who supplies a standalone tree (trunk + crown) and an islet rock? Can W4b read AeroKit's crown templates
  read-only, or does it wait for the island session? Or defer W4b to the next slice?
- **F1 (for Fable, blocking D1's parts):** at E1 the station is on the nest's +X side, so the curl spot must move to
  -X; where does the sign go so "station, egg, sign" still reads left to right (for example behind the nest at
  root-local (-1.6, 0, 1.4))? E2 does not escape it: there the station is on -X, the curl spot is clear (7.5 from the
  station) but today's sign lands 3.7 from the station centre. Today's sign and curl spot sit on opposite sides, and
  only the outer side has room.
- **Copy (for Fable):** "Hatch new friends" on a station that sells toys and looks.
