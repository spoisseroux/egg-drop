# Beta (14) phone QA: bug-fix plan (Opus, 2026-11-23, step 1 of the review-driven build)

Source: `FEEDBACK.md` (Spencer's phone pass on the private beta 107705084891479, beta ceilings on, `garden_hour=True`) and
shots 1-5. Branch base `feat/egg-drop-arcade-polish` 7fa744b. Read-only diagnosis: nothing in `src/` changed, nothing run
in Studio (another session holds it). Line numbers are at 7fa744b.

Scope here (after the coordinator's scope change): B1, B2, B3, B6, Q3, F1. **Moved:** B5 (garden-life builder) and Q1
(nest builder). Not here: B4/Q4/W1/W2 (island session), Q2/Q5/Q6/F3/F4/W3/D1/D2 (Fable), F2 (its own plan).

Files this builder will not touch: GardenLife, LifeSim, LifeArt, Wind, Nest* / NestClient, ThingsTrail, Dash*. Where a fix
needs one of them (B2 entirely, F1's Dash results part), it is written out precisely below, marked **ROUTE**, for the
coordinator to hand on. Calling an existing public API of those modules from my files (for example `trail:start`,
`clientUI.things.show`) is not touching them.

Summary of causes

| Item | Cause | Confidence |
|---|---|---|
| B1 | On a phone the hub-family screens never call `Kit.arrive` (gated `not self.view`); every other screen never adopted it; the phone's most-tapped keys are not Kit buttons | High (code) |
| B2 | By design there is no night population: fireflies exist only as a 6 s hand-off from butterflies alive near you at the moment dusk crosses .30 | High (code) |
| B3a | The automatic first-Meet greeting shot counts as "said hi", so `needHi` is closed before the bubbles are ever ready | High (code) |
| B3b | Not proven offline. Tap path is wired; its only effect is a paw trail the auto trail already drew (or a 3 s marker when near), with no feedback; a phone BillboardGui hit problem is the other candidate | Medium |
| B5 | **Moved** to the garden-life builder (diagnosis notes kept below for them) | n/a |
| B6 | The 42 px foot stopped the overlap, but on a ~200 px phone pane the content needs ~176 px and the scroll window is ~158 px: the 2nd stat row is clipped by the ScrollingFrame edge | High (numbers match shot 5) |
| Q1 | **Moved** to the nest builder (Fable: it is the ThingsTrail pin) | n/a |
| Q3 | Phone geometry puts the button row's left edge 8 px inside the well's right edge at 844 wide | High (numbers match shot 2) |
| F1 | Chips are plain Frames (`Active=false`); results have no route to the nest/quest log; the strip has no input hook | n/a (feature) |

---

## B1. Only the quest log springs up (phone)

### Root cause

1. **Phone hubs skip the rise entirely.** Each hub's `fit` switches to a phone view on `Kit.compactRule` (W >= 1.2 H and
   H < 500 or W < 1000, `DeckKit.lua:2460`): `self.view` is set, the root goes `AnchorPoint (0,0)` at a fitted offset
   (`MachineHub.lua:572-577`, `CompanionsHub.lua:540-543`, `StatsPanel.lua:643-646`, `NameScreen.lua:617-620`). The open
   paths then gate both the spring and the old 8 px tween on the desktop view:
   - `MachineHub.lua:686` `elseif not wasOpen and not self.view and not Kit.reduced() then ... Kit.arrive(self.root)`
   - `CompanionsHub.lua:828`, `StatsPanel.lua:728`, `NameScreen.lua:701`: the same `not self.view`.
   So on a phone the garden "Pocket menu" (the machine hub, `init.client.lua:63`), Pets, Stats and Names appear with no
   motion at all. Studio check R4 saw the machine hub rise because Studio ran at a desktop size.
2. **The quest log is the one screen that rises on every size.** `QuestLog.lua:612` calls
   `Kit.arrive(self.overlay.content, UDim2.new())` with no view gate (the overlay content is a deck overlay, anchored 0,0,
   so `Kit.arrive` rises it 22 px on a phone, rise only: `DeckKit.lua:296-308`). `DifficultyPicker.lua:204` is the same
   (also rises on a phone).
3. **Most other screens never adopted `Kit.arrive`.** Hatch eggs (`EggHatchView.lua:1422`, shade on, no motion), Wardrobe
   (`WardrobeShop.lua:927`) and Book (`BookView.lua:914`) use `Kit.slideIn`, a plain 160 ms Quad tween
   (`DeckKit.lua:2720-2732`); the deck's Pocket menu (`PocketMenu.lua:135-157`) opens with its shutters; DeckMenu, which did
   call `Kit.arrive` (`DeckMenu.lua:412`), is retired.
4. **Press springs miss the keys a phone player presses most.** The PressScale `Face` exists only in `Kit.button`
   (`DeckKit.lua:950-958`, `Kit.FaceOn` from `Alive.ceiling("springs")`, `DeckKit.lua:793`) and the round keys
   (`DeckKit.lua:1934`, `2150-2152`). The garden dock (Menu and Deck circles) are `DeckArt` buttons (`RoomView.lua:130-133`,
   `DeckArt.lua:509-526`) with no spring; the nest chip, need bubble and HUD chips likewise. The touch path itself is fine:
   `MouseButton1Down/Up` fire for touch on GuiButtons, and `Kit.button` holds the press for `Motion.pressUp` (.10 s).

Ruled out: place gating (`Alive.ceiling` passes on the beta place id, `Alive.lua:14-19`; the quest log proves `menus` is
on); the touch spring cap (`KitSpring.lua:170`, 24 live springs: if it were hit, the quest log would snap too).

### Fix

- `MachineHub`, `CompanionsHub`, `StatsPanel`, `NameScreen`: drop the `not self.view` gate. Phone: `Kit.arrive(self.root,
  self.root.Position)` (the fitted goal; anchored 0,0, so `Kit.arrive` rises 22 px only, no root scale, by its own
  `centred` rule at `DeckKit.lua:305`). Desktop unchanged. Keep `slideFrom` paths as they are.
- Phone fallback when springs are off: none (today's behaviour on a phone is a cut, keep it; desktop keeps its 8 px tween).
- Hatch eggs: `Kit.arrive` on its panel on open (only on a fresh open, not on `update` or the store page). Phone and
  desktop. Needs a look at which frame is the panel (`self.shopPanel` vs the result card) before building.
- `Kit.slideIn`: when `Kit.alive("menus")`, a horizontal `springTo` (same 3.0 Hz / .42) instead of the tween; off, the
  tween as now. This gives Wardrobe, Book, Customize and Back-to-hub the same feel without touching each screen.
- Dock circles (`Art.dockCircle`): a `PressScale` on their glyph holder (round spec .88 / top 1.12) via
  `Kit.pressScale`, only where `Kit.FaceOn`. The need bubble gets its own squash (see B3b).
- **ROUTE (nest builder):** the nest HUD chip ("Egg 8 h") has no press spring either; the same one-line
  `Kit.pressScale(chipFace, down, Kit.PressScale.round)` on its MouseButton1Down/Up/MouseLeave in `NestClient`.

Files: `MachineHub.lua`, `CompanionsHub.lua`, `StatsPanel.lua`, `NameScreen.lua`, `EggHatchView.lua`, `DeckKit.lua`
(`slideIn`), `DeckArt.lua` or `RoomView.lua` (dock press).

### Edge cases

- A rotation mid-rise: `fit` writes `root.Position`, a foreign write that wins (`KitSpring.lua` header). Lands at the fit.
- Back from a child screen passes `slideFrom`: no rise, a slide (spring when alive).
- The hub covered by a child screen (`setCovered`) must not re-arrive.
- Reduced Motion / Motion Low: `Kit.alive` false, no rise (phone) or the 8 px tween (desktop), as today.

### Specs

- `KitArrive.spec` (Studio): a phone-sized host (844 x 390): each hub's open moves its root from fit + 22 px to the fit,
  no `ArriveScale` ride on an anchored-0,0 root; desktop case unchanged.
- `MenuPolish.spec` (Studio): `Kit.slideIn` with menus alive is a spring (lands exactly on the goal; a foreign write wins).
- `KitSurfaces.spec`: dock circle press scale exists only with `FaceOn`.

### Risks

- The phone hub roots are full-screen and transparent; a 22 px rise shows the garden through a 22 px band for ~.3 s.
  Fable to judge on a phone capture; fallback constant `Kit.Rise.phone=14`.
- Text re-raster on a low phone (root scale stays off on phone: anchored 0,0).

### Studio probe to confirm

Device emulator at 844 x 390: open the machine hub, sample `root.Position.Y.Offset` each frame for .5 s. Today: constant.
After: fit+22 to fit with ~6 px overshoot.

---

## B2. No fireflies at night

### Root cause

Fireflies are not a night population. They exist only as a hand-off from live butterflies:
- `LifeSim.lua:294-305`: butterflies fly while daylight > .30, spawn only while > .34 (`Sim.Butterfly.spawn`); under .30
  each one hands off to a firefly glow 1.5 s apart and is **gone 6 s after its hand-off starts** (`handGone=6`).
- `LifeSim.lua:330-336` removes them at `handGone`; `LifeSim.lua:352` stops all spawning under .34. So from dusk to dawn
  nothing spawns and nothing glows.
- A hand-off needs butterflies alive at that moment: at most 4 (`Sim.Caps.butterflies`, `LifeSim.lua:29-31`; 2 at budget
  level 1, 0 at level 2), only within 60 studs of a flower patch (`reach=60`) and of the camera.
- Under .24 (a player who joins, respawns or teleports into night) they just fade (`handFloor`).

So the whole firefly show is ~6-12 s at one moment per garden hour, only if you are standing by a flower patch. Spencer
never saw it. Two further gates can hide even that on a phone: `AliveBudget` level 2 (frame p75 > 40 ms three windows
running, `AliveBudget.lua:1-20`) tears garden life down for the session (`GardenLife.lua:323`, `594`), and the daylight
reads `nil` (always day) unless `HollowClock.hourOn()` (the Aero look started, `GardenLife.lua:309-313`).

### Fix: **ROUTE (garden-life builder)**. Every line is in LifeSim / GardenLife, which this builder does not touch.

A real night population, client only, no new parts beyond the existing butterfly pool's glow billboards:

1. `LifeSim.lua`, `Sim.Butterfly` (`294-305`): add `night=table.freeze({cap=table.freeze({6,3,0}),gap=1.5,fadeOut=2,
   fadeGap=.8,reach=60})`. Keep `fly=.30`, `spawn=.34`.
2. `Butterflies:step` (`328-436`): while `dark(daylight)`:
   - do not remove a `b.hand` entry at `handGone` (`LifeSim.lua:335`); a handed-off butterfly simply stays a firefly
     (mode "glow") for the rest of the night;
   - new spawn branch (where `spawn` is false today, `352`): if `#list < night.cap[level+1]` and `now >= spawnAt`, pick a
     patch within `night.reach` of the camera that is `Sim.clear` and not used, create an entry with `mode="glow"`,
     `hand = now - B.handFade` (so `butterflyLook` paints it as a lit firefly at once, wings 1), `glowY` from
     `world.ground` + `glowRise`, `colour` = the first free slot; `spawnAt = now + night.gap`;
   - the hand-off of day butterflies (`337-350`) stays, and `handFloor` (.24) no longer means "fade": under .24 a day
     butterfly hands off immediately (start = now) instead of fading, so a player who arrives at night still gets glows.
   - `step` needs the budget level for the night cap: pass it in (it already gets `cap`; add `nightCap` as a new last
     argument, or let GardenLife pass `Sim.cap("fireflies", level)` with `Sim.Caps.fireflies = {6,3,0}`).
3. At dawn (`daylight > .34` and an entry is in "glow" mode): set `b.fade = now + (i-1)*night.fadeGap` once; extend
   `butterflyLook` (`492-515`) so a glow with `b.fade` fades `glow.transparency` to 1 over `night.fadeOut`, then the entry
   is removed (`fadeOut` check at `335` uses `night.fadeOut` for glow entries).
4. Pool: the butterfly pool has one glow billboard per colour slot, 4 slots (`Sim.Caps.butterflies`). Fireflies need 6:
   `GardenLife` must build `max(butterflies, fireflies)` slots (the pool loop `for slot=1,Sim.Caps.butterflies[1]` at
   `GardenLife.lua:448`, entries at `459`; the glow billboard builder above it) and `flyPool[b.colour]` must exist for colours 5-6 (body and wing parts can stay hidden for glow-only slots).
5. `GardenLife.lua:681`: pass the firefly cap; nothing else changes (paint already handles `look.glow`).
6. Diagnostics (beta only): `Players.LocalPlayer:SetAttribute("AliveLevel", level)` when `AliveBudget.level()` changes
   (from `GardenLife:step`, one write per change), so a phone session can report whether it sits at level 2.

Edge cases for them: `/hour at` jumps day->night (spawns, no fade-only path) and night->day (fades); parked (hatch, deck,
own race) clears as today; Reduced Motion none; hour off (live) `daylight=nil`, unchanged; a respawn/teleport over 120
studs drops entries (`Sim.Drop`) and night spawning refills near the new camera.

### Edge cases

- Joining at night: fireflies spawn at once (staggered), no fade-only path.
- The hour flips by `/hour at`: a jump from day to deep night spawns them; to day fades them.
- Parked (hatch, deck, my own race): all hidden, as now (`Life:park`). Reduced Motion: none (as butterflies).
- Hour off (live): daylight nil, nothing changes on live.

### Specs (for the garden-life builder; offline runner: `LifeSim`, `GardenLife` are in the default set)

- LifeSim: at daylight .2 from an empty list, glows appear 1.5 s apart up to the cap, stay past 6 s, none spawn at .5;
  a day butterfly at .2 hands off (no fade-only); at dawn they fade and are gone; a level-2 cap is 0; a patch out of
  reach spawns none. The existing round-3 hand-off case changes (no removal at `handGone` while dark).
- GardenLife: with a `daylight` dep at .2, after 10 s the pool has `cap` glow billboards enabled.

### Studio probe

`/hour at 3000` (night), stand at a flower patch: count enabled `EggDropLife` glows (today: 0 after the dusk hand-off).
Read the `AliveLevel` attribute (item 6) on Spencer's phone: at level 2 no garden life shows at all, which is a separate
performance item.

---

## B3. New-save need bubbles

### B3a. The hand bubble over the Bear never showed

Root cause:
- After the starter reveal, Meet runs `hatchNavigation:meet` -> `present` -> `roomView:focusPet()`
  (`init.client.lua:1558-1571`, `1579-1580`), which sets `roomView.focusing=true` (`RoomView.lua:1129`); the first Meet is
  also staged as a front greeting (`init.client.lua:3198-3201`).
- BearNeeds' greeting dep is `roomView.focusing==true` (`init.client.lua:4899`), and its step marks the need done
  **before** the ready gate: `BearNeeds.lua:191` `if owned>0 and d.greeting()==true then self.live.saidHi=true end`.
- So the automatic first-Meet shot closes `needHi` while the bubbles are still waiting for the garden to settle; when
  they become ready, `Needs.current` skips straight to `needToy` (the ball). Every new save misses the hand bubble.

Fix: a greeting counts as "said hi" only once the bubbles are ready and only on a false-to-true edge after that
(`self.ready` and `not self.greetingWas`), or while the hand bubble is open. The first-Meet shot, which begins before
ready, never counts. `intent.d.saved` (a petting save) still counts at any time.

Files: `BearNeeds.lua` (the step's greeting block).

Edge cases: a player who greets again during the settle window (still before ready): does not count; the bubble shows
and asks; one tap or E says hi and closes it. Returning players: unchanged (no bubbles). The `follow` auto trail waits for
`needHi` (it starts after Say hi with the bubbles on): check that the trail still starts after a real greeting.

Spec (`BearNeeds`, offline): "the first Meet greeting before ready never closes need 1": rig with `greeting=true` and
`gate.greeting=true` from t=0, then false; after settle the bubble icon is `hand`. Existing test at
`scripts/BearNeeds.spec.lua:104` stays green.

### B3b. The ball bubble showed but could never be tapped (phone)

Not proven without a phone or Studio. What the code says:
- The hit area is wired: `NeedBubble.lua:84-94` a 108 px clear `TextButton` over the 72 px bubble, `BillboardGui.Active`,
  `AlwaysOnTop`, parented to PlayerGui (`init.client.lua:4877-4882`); `Activated` calls `BearNeeds:tap()` when shown.
- What a ball tap does: `BearNeeds.lua:147-154` -> `trailTo("Eggs","tap")` -> `ThingsTrail:start` (`ThingsTrail.lua:169-176`).
  But when the ball bubble first shows, BearNeeds already starts that same trail by itself (`BearNeeds.lua:241`, `252`).
  A tap restarts an identical trail (no visible change); within 8 studs of the station (`Trail.Arrive`) it is a 3 s
  marker only (`ThingsTrail.lua:175`, `230-231`); and the bubble itself gives no feedback (no press, sound or pop). On
  shot 4 he is beside the Eggs station, so a tap there would show almost nothing. This fits "could never be tapped" even
  if every tap arrived.
- The other candidate is a phone BillboardGui input miss (no tap reaches `Activated`): the bubble moves (chase spring,
  hops) and touch input on billboards with a device safe-area inset is a known weak spot. Shot 3 is at the cliff, far
  from the station: if taps arrived there, he should have seen fresh prints, which argues for this candidate too.

Fix (covers both):
1. Feedback on every tap: the bubble squashes (.88, spring back), a soft pop sound, and `gui:SetAttribute("Taps", n+1)`
   (beta diagnostics; the bug report sheet can read it).
2. A tap that would repeat what is already on screen does more: within 8 studs (the trail's `Arrive`, read, not changed)
   of the Eggs station, open Hatch eggs on the Toy Egg (the same route the station prompt uses: `openNursery`); with the
   same trail already live, restart it through the existing `trail:start` and hop the bubble (`bubble:hop()`) plus the
   pet's chirp. No change inside ThingsTrail.
3. Touch fallback independent of billboard input: on `UserInputService.TouchTap` (and `TouchEnded` with a short travel),
   project the bubble's anchor with `Camera:WorldToViewportPoint` and call `tap()` if the touch lies within `HitSize/2`
   of it; de-duplicate with `Activated` (one tap per 0.3 s). Only while the bubble is shown.
4. Hold the bubble still while a finger is down on it (pause the chase), so the release lands inside.

Files: `NeedBubble.lua`, `BearNeeds.lua` (`tap`), `init.client.lua` (the TouchTap hook and the Eggs-station open route).

Specs: `BearNeeds` (offline): a tap within `Arrive` of the target opens the station (dep called) instead of a trail; a tap
with the same trail live restarts it and reports feedback; taps de-dupe. `NeedBubble`: pure `Bubble.hitTest(screenPoint,
anchorPoint, hitSize)`.

Studio probe that settles it: Device emulator (phone, touch), show the ball bubble (`/onboard needs on` on a fresh save),
click it: watch `EggDropNeedBubble:GetAttribute("Taps")` (after step 1) or temporarily print in `Activated`. If clicks
land in the emulator but Spencer's phone still fails, the fallback (3) is the fix that matters.

Risk: the TouchTap fallback must never steal a tap meant for a ScreenGui button over the bubble (check `gameProcessed`
and skip when a GuiObject is under the point: `PlayerGui:GetGuiObjectsAtPosition`).

---

## B5. Dewdrops float under the crowns; the pet did nothing: **MOVED to the garden-life builder**

No fix planned here. The diagnosis below is left as input for that builder (file:line evidence), not as a plan of record.

### Root cause (float)

- The grove reads `LifeSpots.Crowns` (`GardenLife.lua:477`), generated before the Aero kit from the v7 blossom crown
  clumps (`LifeSpots.lua:1-4`, `40-53`): round footprints (e.g. Tree_05_blossom centre y 11.78, size 9.73 x 5.68 x 9.73).
- The island re-export replaced the visible crowns with kit meshes (`WorldAeroKit.lua` crowns, placed by
  `AeroKit.crownFrame`, `AeroKit.lua:26-32`): Tree_05 is now a yawed 9.02 x 5.88 x 6.92 blob (blossom mesh 9.37 x 6.11 x 7.19
  at scale .9625), centre y ~11.66, rounded underneath.
- `Sim.fruitStems` (`LifeSim.lua:813-826`) puts stems at `out=.36 * size.X` = 3.50 studs out and `down=.80 * size.Y` from
  the top (1.58 below the kit centre). At that height the kit blob is only ~.84 of its half extents wide: ~3.8 studs on
  the long axis, ~2.9 on the short axis. Most stems sit outside the leaves, then hang `.64` lower (`Sim.fruitHang`): they
  read as floating under and beside the crown. Same for the Blossom Point tree (kit scale 1.7).
- Kit crowns sway about the trunk top (`WindClient.lua:37`: up to 4 degrees + 1.5 lean); the fruit's stem point is fixed,
  so in a gust the crown moves off the fruit.

### Root cause (the pet)

There is no pet reaction. `Sim.fruitBat` (`LifeSim.lua:1003-1021`) only hops the **fruit** when one of my drawn pets is
within 3 flat studs of a resting one (`F.bat=3`), polled every 2 s (`F.poll`, `LifeSim.lua:1137-1150`); the pet itself
never moves, looks or animates, and a following pet is rarely within 3 studs of where a fruit lands.

### Fix ideas (for the garden-life builder to own or discard)

1. Crowns from the kit: a pure `Sim.kitCrowns(data)` builds `{position, size, cframe, pivot, tree}` from
   `WorldAeroKit.crowns` with `AeroKit.crownFrame` maths (copied pure, no instances), for the trees that `LifeSpots.Crowns`
   lists (same set of 12, so the gust seeds and the fruit count do not change; islet trees not in the kit keep their v7
   box). Used when the Aero kit is up (`AeroWorld` reports it), else the old list.
2. Stems on the kit blob: stem tip on an ellipsoid model of the crown in its own yawed frame, at height `-hang`
   (`F.stemDrop`, start -.25 of the half height) and `F.stemIn` (.82) of the ellipse radius at that height and angle, so
   every stem is inside the leaves; the image hangs from there. Fable tunes `stemDrop/stemIn` on captures.
3. Follow the sway: hanging fruit is drawn at `crownPart.CFrame * localStem` when that crown's live part is found (the
   kit folder, matched by tree name once at enable); falling plans keep the shared data stem (the let-go moment is the
   same on every client; the visual start differs by under .4 stud).
4. Pet reaction (client view only, no server state): when a loose fruit lands within 12 studs of my own pet and the pet
   is in the garden, not focused, racing or carried: the pet looks at it (a `visual.interest={position, untilAt}` that
   `PetLookAt.step` prefers over the owner, 2.5 s), a curious `cheerPet("cheer")` hop with its chirp, and if it is within
   `F.bat` (raise 3 -> 4) a bat (`Sim.fruitBat`, existing). Rate limit: one reaction per 8 s.
   Walking the pet to the fruit needs the server's garden actor (positions are server-simulated), so it is left for D2.

Files (for the garden-life builder): `LifeSim.lua` (`kitCrowns`, stem rule, constants), `GardenLife.lua` (crown source, live sway lookup, a
`notice(position)` dep on landing), `PetLookAt.lua` (interest target), `init.client.lua` (the `notice` dep:
`roomView.pet.interest`, `cheerPet`), `LifeSpots.lua` untouched.

Edge cases: lime vs coral crowns (`/aero coral`: the pink path already hides fruit); kit down or refused (old list);
Reduced Motion (fruit hangs, no pet reaction); budget level 1 (no sway follow: static stems); a crown inside the camera's
fade (fruit stays visible: fine).

Specs (offline: `LifeSim`, `GardenLife`, `AeroKit` are default): every stem of every kit crown lies inside its ellipsoid
model and below its centre; the same trees and the same gust seeds as before (fruit count per crown unchanged); a
landing within 12 studs calls `notice` once and not again within 8 s; none while parked.

Studio probe: capture each of the 12 trees from 8 studs at eye height with fruit hanging (Fable's look pass).

Risk: `AeroKit` instance lookup by tree name each enable; must survive the kit being rebuilt (AeroWorld switch): re-read
on `Life.Poll`.

---

## B6. Deck results (phone): "Power +64" cut off under the wallet chip

### Root cause

Row 22's fix made the rows stop 42 px above the pane's foot (`DeckResultsInPlace.lua:113`
`payout.Size = (1,0,1,-Layout.payoutFoot())`, `DeckResultsLayout.lua:77-83`), so nothing draws under the chip. But the
content does not fit the window that is left. In `paintPayoutV3` (`DeckResultsInPlace.lua:196-262`), with three payout
rows and the strip on: title to 28, rows 3 x 22 -> 94, rule and total -> 126, the stat gap +14 -> 140, then 18 px a stat:
Heart 140-158, Power 158-176. Shot 5's payout pane is ~118 x 200 px (2000 x 920 capture of an 844 x 388 screen), so the
scroll window is ~158 px: Power starts at the window's edge and is clipped by the `ScrollingFrame`
(`DeckResultsInPlace.lua:29-33`, 3 px bar, no cue). With 3-4 stats it is worse.

### Fix

A pure fit in `DeckResultsLayout`: `Layout.payoutPlan(paneW, paneH, rowCount, statCount, stripOn)` returning the y of each
block and a mode, tried in order until everything fits the window:
1. Stat gap 14 -> 6 and payout rows 22 -> 20 on a pane under 220 tall.
2. Stat gains two to a line (dot, gain; the name dropped, colour carries it; disc for a level-up) when the pane is under
   `DiscBelow` (150) wide; names kept on wider panes.
3. Wallet chip 28 -> 24 (`Kit.WalletSpec[24]` must exist with the 3D star; else keep 28) and foot 42 -> 36.
4. Still over: the window keeps its scroll and shows a 12 px fade at the bottom edge as a cue.
Shot 5 (118 x 200, 3 rows, 2 stats): step 1 gives 28 + 60 + 32 + 6 + 2 x 18 = 162, still over the 158 window; step 2
puts both stats on one 18 px line: 144, fits. Four stats: two lines, 162; step 3 widens the window to 164: fits.

Files: `DeckResultsLayout.lua`, `DeckResultsInPlace.lua` (`paintPayoutV3` reads the plan).

Edge cases: zero-payout round ("No Stars this time" 44 px row); pending ("Saving…"); a level-up disc on a two-up line;
translated stat names (two-up drops names, so long names stop mattering on narrow panes); the old (not v3) path unchanged.

Specs (offline `DeckResultsLayout`): for panes 118 x {160,180,200,240} and 0-4 stats with 1-4 rows, every block's bottom
<= window and the chip's top >= window + 6; the existing "foot 42" case changes to the plan's foot. Studio
`DeckResults.spec`: the in-place payout at 844 x 390 with two stats has no child below the scroll window.

Risk: dropping stat names on narrow panes; Fable signs off the two-up look (alternative: keep names, move the chip into
the pane's eyebrow row).

---

## Q3. Bear reveal (phone): Back and Meet Bear cut into the preview card

Root cause: `RevealStage.geometry` phone branch (`RevealStage.lua:330-345`) and `Stage.wellRect` (`RevealStage.lua:738-743`)
size the well from the pet alone; the button row is right-aligned from `W - margin` (`RevealStage.lua:883-891`) with fixed
minimum widths, and nothing keeps the two apart. At 844 x 390: s = 1.039, petX 278, petBox 239, well width
min(406, 524) = 406, so the well's right edge is 481; Meet 182 and Back 155 wide with margin 24 and gap 10 put Back's
left edge at 473: 8 px inside the card (shot 2: Back's left edge at x 1125 / 2.37 = 475 vs the card edge 1140 / 2.37 = 481).

Fix: a pure `Stage.buttonRow(L)`: the row's left limit is `wellRight + 12`; if the two buttons do not fit, shrink both
toward their measured minimum (label + glyph cap + 2 x 14 padding, at `btnText` 16), then clamp the well's width to
`2 * (rowLeft - 12 - petX)` (never under `petBox * 1.3`); if still short (a very narrow phone), stack Meet above Back in
the right column. `layout` uses the row's x and widths.

Files: `RevealStage.lua`.

Edge cases: one button only (`Meet` alone); the duplicate tag ("ALREADY OWNED") and Rare jackpot edge ring (34 px
corners on a phone: the clamp must include the ring's offset); 667 x 375, 740 x 360, 812 x 375, 844 x 390, 932 x 430.

Spec: `RevealStage.spec` (Studio): for the five phone sizes, button left >= well right + 12, both buttons on screen,
well >= petBox x 1.3. If `RevealStage` cannot load offline, the pure row maths goes in a small `RevealLayout.lua` that can.

---

## F1. "Coming up" chips tappable

### Current state

- `TomorrowStrip.lua:1-5`: "Never a button, never focusable"; chips are `Frame`s with `Active=false`
  (`TomorrowStrip.lua:209-219`), the root `Active=false, Selectable=false` (`290-300`). Pinned by
  `scripts/TomorrowStrip.spec.lua:135-150`.
- Consumers: desktop/phone deck results `DeckResults:paintTomorrow` (`DeckResults.lua:933-955`), phone in place
  `DeckResultsInPlace.lua:266-273` (and the old placement at `326`), the Dash results sheet
  `DashResultsSheet.lua:155-166` (via `DashCard.open`, `DashClient.lua:750-766`).
- QA Q5 made the results quest cell progress only, with no route to the quest log (`init.client.lua:3148`). Spencer's F1
  reverses that for the strip.

### APIs to route with

| Chip | Target | Route |
|---|---|---|
| `nest` (egg) | the nest | leave the deck (`clientUI.leaveDeck`, `init.client.lua:2378-2385`, which hides the results), then once in Room `clientUI.things.show("nest")` (a paw trail to `clientUI.nestPlace()`, `init.client.lua:4788-4791`) |
| `stamp` | the stamp card | leave the deck, then `clientUI.openQuestLog("daily", {focus="stamp"})` (`init.client.lua:3569-3582`); `QuestLog:show` gains a focus option that sets `focusIndex = Log.StampFocus` (`QuestLog.lua:24`, `606-614`) |
| `quests` | the quest log | leave the deck, then `clientUI.openQuestLog("daily")` |
| any, from Dash results | as above | `card:back()` (closes the sheet and ends the seat, `DashCard.lua:195-199`), then the same garden route (already in Room) |

`leaveDeck` switches mode on the server, so the garden step must wait: a small `clientUI.afterGarden(fn, 8)` that runs `fn`
once `board Mode=="Room"`, `roomView.mode=="Room"`, `not roomView.busy`, within 8 s, else drops it (and is replaced by a
newer one). Guard like the Hatch action: no route while `recap.data.pending` (`init.client.lua:3137-3140`).

### Build

- `TomorrowStrip`: `options.onChip(id)`; with it each chip gets a clear `TextButton` "Hit" over the frame (Active,
  `Selectable = options.selectable ~= false`), press feedback via `Kit.pressScale` on the chip frame (round spec), and
  `Strip:targets()` returning the hit buttons in order (egg, stamp, quests). Without `onChip`: exactly today's tree (the
  existing spec case keeps passing for that path). The header comment changes.
- `DeckResults` / `DeckResultsInPlace`: pass `onChip = function(id) self.callbacks.chip(id) end`; register
  `recap:on("chip", ...)` in `init.client.lua` with the routes above.
- Gamepad/keyboard: chips join the results focus as ids 6, 7, 8. `DeckResultsLayout.move`: down from the bottom action row
  to the chip row (nearest by x), left/right along the chips, up back to the action it came from. `Results:target(index)`
  and `View:activate(id)` learn 6-8. Desktop `Results:move/move2D` (`DeckResults.lua:972-990`) the same. A on a chip
  activates it.
- `init.client.lua`: one shared `clientUI.stripRoute(id)` (the table above, with `afterGarden`), used by `recap:on("chip")`
  and passed into the Dash mount as a new dep `stripChip = clientUI.stripRoute` (my side of the Dash hookup).
- **ROUTE (Dash owner): the Dash results sheet.** `DashClient.lua:757-765`: pass `stripChip=function(id) card:back();
  self.d.stripChip(id) end` into `DashCard.open` (guard `self.d.stripChip` nil). `DashCard.open` forwards it to the sheet;
  `DashResultsSheet.lua:159-161`: `Strip.new(panel,{..., onChip=o.stripChip})`. The sheet's selection order (Again, Done)
  appends `strip:targets()` when the strip is shown, so gamepad down from Again/Done reaches the chips and A activates.
  `Card:press`'s `inputAt` guard applies to chips too. Spec `DashSheets` (offline): with a strip the selection order has
  the three chips after Done; activating one calls `stripChip(id)` once and closes the card.

Files (mine): `TomorrowStrip.lua`, `DeckResults.lua`, `DeckResultsInPlace.lua`, `DeckResultsLayout.lua`, `QuestLog.lua`,
`init.client.lua`, `UICopy` (an `AccessibleLabel` per chip: "Go to the nest", "Open the stamp card", "Open quests").
`TomorrowStrip` lands first so the Dash owner can build on `onChip` / `targets()`.

### Edge cases

- The strip's live 1 Hz `set` rebuilds chip text: the hit buttons must survive `set` (made once per chip in `chipFor`).
- Egg ready (gold): the nest route is the same (the prompt there hatches it).
- The quest log refuses to open (a modal up): the route drops silently after the garden step; no stuck state.
- Phone in place: the strip sits in the LCD under the panes; chips are 22 px tall (`Strip.ChipH`): the hit button extends
  to 32 px (5 px over each edge) without overlapping the action buttons above (spec it).
- Mid-round results do not exist; Dash results on a phone use the sheet's own focus.
- Gamepad selection must not land on a chip when the strip is hidden (nest off).

### Specs

- `TomorrowStrip` (offline): with `onChip` each chip has one `TextButton` Hit, `Activated` calls `onChip(id)` with the
  right id, `targets()` order is egg, stamp, quests; without `onChip` the old "never a button" case holds; `set` twice
  keeps the same buttons.
- `DeckResultsLayout` (offline): `move` from each action to the chip row and back, left/right clamped at the ends.
- `DashSheets` (offline): with the Dash owner's change (ROUTE above).
- Studio `DeckResults.spec`: tapping the quests chip on the in-place results leaves the deck and opens the quest log.

### Risks

- Leaving the deck from results while a save is pending: guarded by `data.pending`.
- Re-opening a route from the hub's Back (`questFromHub`): this path is not from the hub, so Back closes to the garden.

---

## Q1. "Napping egg" tag visible from far (shot 1): **MOVED to the nest builder**

No fix planned here. Correction to my first reading: Fable found the tag in shot 1 is the ThingsTrail pin, not the nest's
own label. That fits the code: `things.show("nest")` starts a trail whose marker plate is named `onb3.nest.title`
("Napping egg") (`init.client.lua:4788-4791`, `ThingsTrail.lua:169-178`). The nest's own `Label` billboard
(`NestClient.lua:457`, `AlwaysOnTop=true`, `MaxDistance=60`, fixed 240 x 62 px) has the same far-and-on-top shape and is
worth the nest builder's look while they are there.

---

## Built (step 2, after the architect's GO WITH CHANGES)

Offline runner: 47 suites, 0 failures (BearNeeds 20 -> 24, DeckResultsLayout 5 -> 7, TomorrowStrip 12 -> 13). Nothing seen
in Studio or on a phone. Where the build differs from the plan above, this section wins.

| Commit | Item | What landed |
|---|---|---|
| 0c1e16a | B1 | Each of MachineHub, CompanionsHub, StatsPanel and NameScreen has its own phone branch, `Kit.arrive(self.root, self.root.Position)`, which does nothing when it returns false (live: no tween, so an anchored-0,0 root never flies off); no art pop on a phone. Hatch eggs rises only on a fresh shop open (not a result, a reveal, the store page or a reopen). The dock Menu and Deck keys squeeze their glyph on the round-key spring under `Kit.FaceOn` (the button itself never scales). **Not changed:** `Kit.slideIn`, `Kit.Rise.phone`, Wardrobe, Book (they keep their slide-in). `KitArrive.spec` (Studio): the phone rise and a menus-off 844 x 390 case that ends exactly at the fit. |
| a1c6cc5 | B3a | With the bubbles on, a greeting counts as "said hi" only once the hand bubble has shown (`hiShown`); bubbles off or a returning save count any greeting, as before; petting and a tap count any time. |
| a1c6cc5 | B3b | `Needs:tap()` keeps one action a tap (a step frame, and `TapGap` .3 s with the game's clock). Every taken tap squashes the bubble and bumps `EggDropNeedBubble:GetAttribute("Taps")`; a tap that repeats the live trail also hops the bubble and chirps. NeedBubble: a short touch that begins and ends on the hit area counts even with no `Activated`; a `TouchTapInWorld` (no GUI took it) within `HitSize/2` of the drawn bubble counts (PetClickTarget's pattern); the bubble holds still under a finger (1 s at most). **Dropped:** the "within 8 studs open Hatch eggs" branch. |
| 5b1681c | B6 | `Layout.payoutPlan`: normal, tight (rows 20, total 28, gap 6), paired (stats two to a line, the disc in the dot's place), else a 12 pt fade at the window's foot. **Kept** the 28 chip and 42 foot: `Kit.WalletSpec` has no 24 (its fallback Star would be flat). Shot 5 lands on "tight" at exactly 158 of 158. |
| 8d3701f | Q3 | Phone geometry keeps the button row 12 px clear of the card: Back narrows first (to 110), then the card (never under 1.3 pet boxes). Clear at 667x375, 740x360, 812x354, 812x375, 844x390 and 932x430. **Residual:** 568 x 320 still overlaps (the card is at its floor). `RevealStage.spec` (Studio) covers the six sizes. |
| b42578e + next | F1 | `TomorrowStrip.tappable()` (its own beta-place/Studio switch; live stays inert). With `onChip`, each chip gets a clear hit button: never Selectable, inert until the enter fade ends (`Strip:arm`), press squash, AccessibleLabel `onb3.strip.go.*`. Deck results reach the chips as focus ids 6-8 (`Layout.move` with a `chips` count; the desktop order appends them), only while the strip is visible and armed and never while a save is pending; a stale chip focus goes back to Replay. `clientUI.stripRoute`: a latch, no route while pending, `leaveDeck()` first and `afterGarden` only if it returned true (8 s, a newer route replaces it), then egg -> `things.show("nest")`, stamp -> quest log on its stamp card (`QuestLog:show` option `focus="stamp"`), quests -> quest log. Already in the garden (the Dash card): the step at once. Copy exported (3 new keys), **not synced**. |

**ROUTE status:** B2 (garden-life builder) unchanged from the B2 section above. F1 Dash: `init.client.lua` now passes
`stripChip(id)` into the Dash mount (it calls `clientUI.stripRoute`); the Dash owner adds `onChip` only when
`TomorrowStrip.tappable()`, calls `card:back()` then `self.d.stripChip(id)`, and appends `strip:targets()` to the sheet's
selection (the hit buttons are not Selectable; focus by index as the deck results do).

### Studio steps (coordinator; no Studio here)

1. ZZSpecs: KitArrive, RevealStage, KitSurfaces, MenuPolish, DeckResults (the last two unchanged, rerun for regressions).
2. B1, Device emulator at 844 x 390 with menus on: open the machine hub, Pets, Stats, Names and Hatch eggs (fresh): each
   root/panel steps from fit + 22 to the fit; with `/alive menus off` (or the attribute false) each opens at its fit with
   no motion. Press the dock keys: the glyph dips to .88 and springs back.
3. B3b, the bubble on a phone (emulator, touch): fresh save, `/onboard needs on`, wait for the ball bubble. Then:
   (a) click the bubble: does the hit button's `Activated` fire (watch `Taps` go up by one, and the trail restart)?
   (b) `PlayerGui:GetGuiObjectsAtPosition(x, y)` at the bubble's centre: what is listed above `EggDropNeedBubble.Hit`
   (anything Active over it would take the touch)?
   (c) the thumbstick zone: with the bubble over the left 40 % of the screen, does the dynamic thumbstick take the touch?
   (d) a camera swipe that starts on the bubble must not count as a tap (`Taps` unchanged).
   On Spencer's phone: `Taps` in the bug report sheet, or `/onboard` after tapping, settles whether taps arrive at all.
4. B3a: fresh save through the Bear reveal and Meet: the hand bubble shows once the garden settles.
5. B6: in-place results at 844 x 390 after a round with two and with four stat gains: nothing below the scroll window.
6. F1: in-place results, wait for the strip's fade, tap each chip: the deck closes and the trail / quest log (stamp
   focused) opens; gamepad down from Hatch reaches the chips; during "Saving…" the chips do nothing.

### Unverified

Everything visual and every input path above (no Studio, no phone). The phone billboard input question in B3b is still
open; the build covers both candidates. The `luau.exe` used for the export was a local copy, removed, never committed.

## Order, review and evidence

1. Plan review (architect) of this file. 2. Build in this order, one commit each with its specs: B3a, Q3, B6, B1, B3b,
F1 (TomorrowStrip first). B2 and F1's Dash part go to their owners as ROUTE notes. 3. Offline runner green
(`python scripts/run_dash_server_specs.py "C:/Users/skunk/Documents/Development/egg-drop/build/luau-cli/luau.exe"`).
4. Studio-only specs copied to ZZSpecs by the coordinator: KitArrive, MenuPolish, KitSurfaces, RevealStage, DeckResults.
5. Code review. 6. Fable on phone captures (B1 rise band, B6 two-up stats, Q3, F1 press).
7. `V3-TEST-PASS.md` rows, `TODO.md`, translations (new `AccessibleLabel` copy for chips).

## Open questions for the architect

1. B1: the phone rise for a full-screen transparent root (22 px band of garden showing), or rise the body only?
2. B3b: is a TouchTap screen-space fallback acceptable next to the billboard button, or move the bubble's hit area into a
   ScreenGui proxy that follows the projected anchor (one input path on every device)?
3. F1: stamp and quests leave the deck first (garden quest log), or open the quest log over the results inside the deck?
   I chose leaving, as Spencer said "closes the Pocket Deck".
