# Dash and Deck UI: build plan (beta 12 QA U2-U7, G4, S2)

Opus builder, 2026-11-23. Implements Fable's `DASH-DECK-UI-LOOK.md` (mockups in `look/ui/`). Look only: no race rules,
no save fields, no wire change. Branch `worktree-agent-a38498f9260b40e53`, fast-forwarded to `feat/egg-drop-arcade-polish`
(aaab3a8). For architect review before any code.

Not mine: U1 (hint card padding, rail toast: quick-fix builder, `worktree-agent-a8953522b60d4b3f1`; I do not touch
`NotificationRail` or the `PettingHint` / `RoamPetHint` code), and garden life / the nest (`NestClient`, `GardenLife`,
`onb3.nest.*`). `GardenLife` reads `Course.Pad`; if the pad moves (U5) it follows by itself, no edit there.

## Coordinator decisions, applied

| # | Decision | How it lands |
|---|---|---|
| 1 | Tag chip = the pet's **top stat** and its level; Heart when all equal | `Room:topStat()`: highest level, ties broken by `StatCatalog.Order` (heart first), so all-equal is Heart |
| 2 | Start arch about 13 studs | posts at +/- 6.4, banner widened, 8 pads at 1.5 |
| 3 | Mid-race lanes 1.0 if geometry allows | **Kept at 0.5.** The marble bridge deck is 4 studs wide (`SPAN` z = 4.0 in `build_dash_course.py`); 8 lanes at 1.0 put the outer pets 3.5 studs out, off the deck. The boulders by the stones are measured 3.15 to 3.3 studs from the centre line (`OBSTACLES`), so lanes 1 and 8 would run inside them, and every hoop would need to be 8.4 wide (4.4 today). It would mean a new course search, not a widening |
| 4 | Onlookers see hoops only while a race runs; per-client stays per-client | Already per-client: `DashClient:readRoster` calls `props:show(plan)` on **every** client while the roster is live (countdown, race, results), so onlookers do see hoops today. Change: an onlooker's hoops sink when the roster leaves `race` (today they stay through `results`). No replication added |
| 5 | "Hatch" is fine | `results.inPlace.hatchShort` |
| 6 | Dash results: no X; deck results keep their back paths | no close key on the U6 card; B / Backspace = Done |

## Gates: what can reach live

Live place 96451847774961. Every Dash module answers to `Dash.ceiling()` (beta place or Studio), Levels to
`Levels.ceiling`, the strip to `Onboard.on("nest")`, tips to `Things.tips()`; all four are beta-only ceilings.

| Item | Gate | On live |
|---|---|---|
| U2 stat chip | `Levels.on("track")` (the chip path, `Focus:setHeart`) | inert: live shows the bond pips path, untouched |
| U2 `FocusRow.layout` clamp 150-190 -> 120-220 | none | inert: the bond path pre-clamps its width to 150-190 before it calls the row |
| U3, U4, U5, U6, G4 | `Dash.ceiling` (client mount), `DashMount` only built while Dash is on | inert |
| U7 strip v2, panes giving up 54 pt | the strip exists only with `Onboard.on("nest")` | inert |
| U7 right-pane action compaction, payout restyle, gamepad graph | none | **live-safe layout fix** (no data, no rules); ships with the next live version, after a translations sync (`Hatch`). See question 3 |
| S2 `TipChime` | silent: sound id `nil`; Things tips are beta-only | inert |
| New `UICopy` keys | none | unused strings on live; exported for translation |

## Placeholder asset ids (one table each)

`src/client/DashIcons.lua` (new, pure): `{dash=nil, jump=nil, racingFlag=nil, dashWhite=nil, jumpWhite=nil}`. A nil id
draws today's frame-built glyph (bolt, spring) or the flag as a FredokaOne "⚑", so nothing breaks before the upload.
Later: Studio MCP `upload_image` of `look/ui/icons/{dash,jump,racing-flag}.png` (256 px, transparent), ids written into
this table only. `src/client/TipChime.lua`: `TipChime.SoundId=nil` (one line to fill when Spencer picks).

## Per item

### U5 start line (do first: U3/U6 camera shots and G4 tags build on it)

- **New `src/shared/DashGrid.lua`** (pure, no instances). `DashGrid.offset(cs, onStones, lane, count)` in cs:
  `slot = lane - (count+1)/2` (lanes are a permutation of `1..count`, `DashSim` line 80, so this is the racer's order
  among those present, centred); step `150` up to `cs 300`, smoothstep to `50` at `cs 1100`, `50` after and on the
  stones. `DashGrid.at(cs, onStones, lane, count)` = `Course.at(cs, onStones)` (centre line) plus the offset along
  the normal (`x -= cos(yaw)*o`, `z += sin(yaw)*o`, the same normal `DashCourse.sample` uses). `DashCourse.lua` stays
  generated and unedited. Constants `StartStep=150, RaceStep=50, FunnelFrom=300, FunnelTo=1100, PostOut=6.4`.
- **Every lane draw goes through DashGrid** with `plan.count`: `DashPose.step` (new `count` argument), `DashCamera.rail`
  and `:step`, `DashProps` clovers (`frameAt`), `DashClient` pal spawn (line 526) and the fade target (line 684). Side
  effect: with fewer than 8 racers the lanes are centred for the whole race (today 2 racers run at -1.75 / -1.25). The
  sim never reads a lane offset (only `plan.lanes` as identity), so `DashSim`, `DashPredict` and the wire are unchanged.
- **`src/server/DashMount.lua`**: `PostOut 3.4 -> 6.4`, banner pieces widen with it (`(6.4*2+.7)/3` each), the eight
  `Pad_` slabs at slot x 1.5 (1.5 wide) from `DashGrid.offset(0, false, lane, 8)`. Part count unchanged (26 server,
  33 client, 59 of `Props.MaxParts` 60).
- **The waiting pad has to move.** Measured on the course numbers: the start faces west from (72, -8) and positive
  slots go toward -z, i.e. toward the pad at (69, -14), r 3. At 1.5 studs the outer racer stands at about (71.6, -13.2),
  2.7 studs from the pad's centre (inside it), and the new post at -6.4 lands at about (71.5, -14.4), 2.5 from it. Plan:
  change `PAD` in `scripts/build_dash_course.py`, make its "pad on the line" rule use the start half-width
  (`6.4 + .35 + PAD_RADIUS + 1`), rerun, and diff the output: `Main`, `Branch`, `Stones`, `Layouts`, `Length` must be
  byte-identical (only `Course.Pad` changes). Candidate to try first: (69, -17), r 2.5 (9.5 from the start, 5.5 from
  the meadow tree, about 9.4 off the line). `Course.Version` stays 2 (it keys saved Time Trial bests, the line is the
  same). The prompt, sign, `Mount.gate()` join reach, `GardenLife` and `init.client` 4729 all read `Course.Pad`.
  `Client.GateEye` sits on the other side of the line and is unaffected. Question 1.
- **Line-up shot**: `DashCamera.lineup(W, H)` (pure): eye behind the row's centre and up, distance so the row (10.5
  studs + one pet) is at most 70% of the screen width at FOV 58, never more than `StartRoom` (6) behind the line (the
  cliff); when capped, it rises instead. `DashClient:raceStep` uses it from lock to GO, then blends to the rail camera
  over 0.6 s (Reduced Motion: a cut).
- **Names**: see the tag work under G4 (one tag system for both).

### G4 + U5 tags (`DashProps`, `DashClient`)

- One BillboardGui per seat on the existing per-seat anchor parts (no new parts). `Props:tag(seat, kind, text)`, kind
  `name` | `mine` | `racing`. The board's size is in px (same size on screen at any distance); the pill sits at the top
  of a board `22 + tier*30 + stem` tall with `SizeOffset (0, .5)`, so the tier is exact px and a 2 pt ink stem runs to
  the head.
- **Racers** (this client holds a seat in that heat): from lock to GO + 1.5 s every racer's `name` tag shows,
  `AlwaysOnTop`, cream (yours lemon), 22 tall, FredokaOne 13, 9 pt sides, 104 max with ellipsis. Pure
  `Props.tiers(tags)`: odd slots tier 0, even slots tier 1; then any two that still overlap on screen push the farther
  one up a tier (loop, never hide). Pop in 0.8 -> 1 over 0.15 s, 40 ms apart left to right; fade out 0.3 s at GO + 1.5,
  then today's leaf-tag rule. Your own pet keeps a 14 pt lemon chevron (bob 3 pt at 1 Hz) for the race. Reduced
  Motion: no pop, no bob. The gather phase has no pets on the line (they follow their owners until lock), so "gather
  and countdown" is lock to GO in practice.
- **Names of other players' pets**: the public pet name the inspect card already reads (board attributes via
  `GardenClient`), passed in as a new dep `petName(userId)`, falling back to the player's DisplayName. Pals keep
  `palName`. No roster or wire change. Question 5.
- **Onlookers** (no seat in that heat): every racing pet (players' and pals) gets the `racing` pill: 20 tall, cream
  90%, 2 pt ink ring, flag 14 + "Racing" FredokaOne 12, `MaxDistance 60`, not on top. Fades in 0.2 s at GO, out 0.2 s
  when that track is `finished`. Onlookers never see name or leaf tags.
- **No prompts on a racing pet for onlookers**: `PetInspect` (the only onlooker prompt on another player's pet: the
  chip, tap and E/X) skips companions whose owner `dash:racing(userId)`; a new `options.racing` dep wired in
  `init.client`. Pet, feed and pick-up look owner-only (the `RoomView` prompt and `PetClickTarget` sit on the owner's
  own pet); step 2 confirms that before relying on it. The owner's own are held by `DashClient:held()`.

### U4 HUD (`DashHud`, `DashIcons`)

- Pads 96 / 108 opaque, 3 pt ink ring, 5 pt ink lip frame under the face; `ImageLabel` 50 x 50 from `DashIcons`
  (fallback: today's bars); word `dash.dash` / `dash.jump` upper-cased, FredokaOne 14 ink at 76% height; key cap
  `Kit.glyph` 20 tall at the top right, overlapping 8 (Shift/Space, RT/A), replacing the stroked text; hidden on touch.
- States through new setters, written only on change: `Hud:press(kind)` (face drops 4 over 0.06 s, back 0.1 s, called
  from the `RaceInput.Core` press callback), `setBar(share, puff, held)` (held: face down, ring white; puff: face and
  bar `#B9B6C9`, icon 50%, word `dash.puff`), `Hud:flash()` on a Perfect (white 30%, 0.12 s). Reduced Motion: no drop,
  no flash, pressed face 10% darker.
- `Hud.layout`: digits centred at 26% of the height (FredokaOne 72, 4 pt ink `UIStroke`); place pill 54 x 24 at
  `strip.x - 8 - 54`; strip 20 tall with a cream flag cap and 2 x 12 hoop ticks at `hurdle / Course.Length`; your dot
  18 lemon, others 12 cream. Nothing selectable, as now.

### U3 mode picker (`DashCard` shell, new `DashSheetLayout`, new `DashStage`)

- `DashCard` keeps the shell (ScreenGui, shade, ContextAction binding, close, rebuild on resize) and gains
  `options.sheet = "gate" | "results"`; the generic lines-and-buttons card stays for anything else. The gate stops
  being `low`.
- **`src/client/DashSheetLayout.lua`** (pure): every box of both sheets for W x H. Phone (H <= 430): 620 x 276
  centred at (W/2, H/2 + 14). Small phone (W < 640 or H < 340): min(620, W - 24) x 236 with the reductions in the look
  spec (stage 150 x 208, line row dropped, stats pitch 18, tiles 60, tile sub-line dropped under W 600). Tablet and
  desktop: the phone layout under `UIScale` 1.25, lowered until it fits W - 48 by H - 120.
- **`src/client/DashStage.lua`**: the left stage for U3 and U6. `ViewportFrame` + `WorldModel` + `Camera` (FOV 30,
  front three-quarter, 20 degrees right, 10 down, pet at 60% of the width), `Kit.petLight`, the pet from
  `PetFactory.new(world, Vector3.zero, pet, nil, appearance)` (the `PetInspect` pattern), appearance through a new
  dep `appearance(petId)` from `init.client` (`CompanionsHub.appearanceOf`). Pedestal (U3) or podium step (U6) and
  glow are frames behind the viewport; the spotlight wedge is an `ImageLabel` with a `UIGradient` (no art). One
  RenderStepped connection while the card is open, destroyed with it. Clone fails: `PetPortrait.create` on the
  pedestal.
- **Poses**: `DashPose.treadmill(visual, state, dt, reduced)`: fixed origin and yaw, `gaitWeight 1`, gait phase advanced
  by `PetFollow.stride` at the 100% pace speed; Reduced Motion: idle. `DashPose.podium(visual, state, dt, place, reduced)`:
  two hops (1.2 studs, 0.42 s), then a hop every 3 s; 4th or lower one hop, then a wag (`applyGardenPose` happy idle;
  a wave only if the rig has one). Never sad.
- Right column: title, line, stats tray (Speed, Energy, Jump from `state.petStats.pets[id].level`, atlas icons
  `sneaker` / `bolt` / `spring`, bar fill level / 99 with an 8 pt minimum), three race tiles (`Kit.button`, 4 pt lip,
  name 15 + sub-line 11), foot (prizes line, "Best {best} s"). Band line: `dash.band` with `stats.tier.*` words.
- States: the last-raced tile (session `self.last`, Just for Fun for a new racer) is primary and focused. The stats
  follow the focused or hovered tile (`SelectionGained`, `MouseEnter`): Fun / Trial dim to 45%, bars puff-grey, "Lv"
  hidden, the "All pets equal in this race" pill; 0.15 s cross-fade; touch shows the green tile's state. A tap starts
  the race at once (as now). Locked reasons stay toasts.
- Gamepad: focus on the green tile; tiles' `NextSelectionLeft/Right` chain the three, no wrap, Up/Down point to self;
  the close key is `Selectable=false`. A / Enter starts the focused tile (the binding presses `selectedIndex`, now the
  focused tile, not the first); B / Backspace / close key closes.
- Motion: spring 0.92 -> 1 over 0.22 s, spotlight fades in 0.3 s after 0.1 s; Reduced Motion: idle pet, no spring.

### U6 results (`DashResults.model`, the `results` sheet)

- **`DashResults.model(packet, mine, before, ctx)`** (pure, next to `words`, which stays for the old card and specs):
  `{headline, time, best, newBest, medal={ordinal, color, cup?}, earned={state, stars, done, total}, field={...}}`.
  `earned.state`: `saving` (no new receipt yet), `paid`, `usedUp` (paid >= limit, nothing new), `off` (prizes off: row
  dropped), `cup` / `noCup` (Time Trial). `newBest`: the saved best equals this time and beats `seat.bestBefore`
  (captured at lock, like `seat.before`). `field`: the top three plus you as the fourth if lower, from `packet.seats`
  `{seat, place, us}` and the names collected for the tags (`seat.names` at result time); none for a Time Trial or a
  race of one.
- The sheet: stage with podium and medal disc (40 pt, Stars / soft / Power / cream, cup colour for a Time Trial),
  confetti (24 frames in the stage, 1.2 s) for 1st-3rd and a cup; Headline 28 with the `#B8791A` drop shadow; Time
  tray (NEW BEST chip); Earned tray (Star, "+n Stars", five pips, "{done} of {total} today" / "Stars again tomorrow" /
  "Saving…"); Field chips (yours lemon); strip v2 when its model is there; Race again (388, primary) and Done (196).
  **No close key.**
- Timeline as the look spec (0 / 0.15 / 0.30 / 0.55 / 1.05 / 1.25 / 1.70 / 1.90 s) on one clock in the card's step;
  buttons take input from 0.30 s; Race again `Kit.pulse` at 1.9 s, then every 6 s. Reduced Motion: final numbers,
  sitting pet, no confetti, no pulse. `Card:update(model)` replaces today's `setLine` loop in `DashClient:slowStep`:
  when the receipt lands, the Stars count runs from that moment. Auto close stays at `ResultSeconds` (20 s).
- Gamepad: focus on Race again, D-pad left / right between the two, A / Enter press, B / Backspace = Done.
- Small phone or H < 390: field row dropped (272 / 216); below W 640 the card is W - 24 and keeps 2 : 1 buttons.

### U7 deck results (`TomorrowStrip`, `DeckResultsInPlace`, new `DeckResultsLayout`)

- **Strip v2** (`TomorrowStrip.fit` and `new`, phone path only): 48 tall, title row inside (moon mark 10 + title
  FredokaOne 12 at y 11), chips at y 21, 22 tall, three equal columns, 6 pt gaps, text centred; width >= 400 whole
  words, < 400 short values, **< 240 nothing** (`fit` answers nil, `set` hides). The tab over the top edge goes.
  Desktop path unchanged. `Strip.Height.phone 36 -> 48`; `DashCard.layout`'s hard-coded 36 follows it.
- **New `src/client/DeckResultsLayout.lua`** (pure): pane rects with the strip on (each pane -54, strip at the left
  pane's x, full LCD width, 48 tall, 6 above), the payout rows, the goals area, and the action rows for the stack
  layout: Replay full x 44, Difficulty full x 36 (cream, 3 pt lip, radius 10, soft `‹ ›` 12 in), Hatch | Leave halves
  x 40, gaps 4, 128 in all. `fitActions(rw, measure)`: a half label that does not fit at 13 tries 11, then row 3
  becomes two full rows of 36 (164). The grid layout (right pane >= 176) and `DeckResults` are unchanged apart from
  strip v2.
- `DeckResultsInPlace`: builds from the layout; decides strip on/off once at `new` from `owner:tomorrowModel()`,
  and relayouts panes if a later `paint` flips it. Payout pane: "PAYOUT" `Label` 11, rows pitch 22, rule, Total in
  Stars with a 12 pt Star; the "Today" line only without the strip; stat gains as rows (10 pt dot, name in its colour,
  gain) with a "Lv n" pill on a level-up, replacing the `StatToasts.resultsRich` rich text and the "Stats" title. The
  Star column's band moves to top 58, foot 52 with the strip on.
- Gamepad (`View:move`, stack layout only): Down from Difficulty -> Hatch, Right Hatch -> Leave, Left Leave -> Hatch,
  Up from either -> Difficulty; Difficulty left / right still steps it; `ORDER` unchanged for A / B.

### U2 pet tag (`PetFocusUI`, `StatsPanel`, `FocusRow`, `RoomView`)

- `RoomView:topStat()` -> `{id, level}` (ties by `StatCatalog.Order`, so all-equal is Heart); `syncBond` passes
  `info.stat` (`info.heart` kept for `trickLevel`). `Focus:setHeart` becomes `setStat`: one row 48 tall,
  `12 | name | 10 | chip | 10`, name FredokaOne 16 white truncating first, card width clamped 120-220, right edge
  fixed (`FocusRow.layout` grows it left). Attributes: `HeartLevel` kept when the stat is Heart (specs read it), plus
  `TopStat`.
- `StatsPanel.statChip(parent, compact)` with `set(id, level)`; `heartChip` becomes `statChip` fixed to heart (the
  two `CompanionsHub` callers keep their look). Non-compact chip: 22 tall, `6 | icon 14 | 4 | word | 5 | disc 18 | 2`;
  word `Strong` 12 in the stat colour mixed 60% to white; level in an 18 pt disc in the stat colour (FredokaOne 12 ink),
  a pill for two digits. Accessible label unchanged ("Heart 1"). Level up: `Kit.boing` the disc.
- Small phone (W < 700): word dropped (chip 45 wide).

### S2 tip chime (`TipChime`, `CoachCards`, `BoardAudio`, `init.client`)

- `src/client/TipChime.lua`: `SoundId=nil`, `Volume=.25`, `Gap=20`, pitch +/- 3%; pure `TipChime.allowed(now, last,
  ctx)` (not within 20 s; not during a deck round, a race (`dash:held()`), or a hatch). The sound setting is the
  `BoardAudio` group volume (0 = silent) as for every UI sound.
- `BoardAudio`: a `tip_chime` slot from `TipChime.SoundId`; a nil id makes no voice, and `Audio:play` already answers
  false for a name without voices. `CoachCards:showIntro`'s `onShown` (the moment a Things line is really on the rail)
  calls an optional `things.shown(id)`; `init.client` sets it to play the chime through `TipChime`. Nothing else
  rings.
- Candidates for Spencer (none chosen, none uploaded): (a) a two-note wooden xylophone or marimba, G5 then C6, felt
  mallet, about 0.4 s, dry; (b) a kalimba pluck pair, E5 then B5, soft attack, short tine ring; (c) a soft glockenspiel
  pair with a felt beater, low-passed under 3 kHz so it loses the bell shimmer. Sourcing: CC0 (e.g. Freesound CC0) or
  the Roblox audio library; licence recorded beside the file.

### New words

One block in `src/shared/UICopy.lua`, after the `Table` literal and before `freeze` (my own block, new keys only):
`dash.sub.{fun,stats,trial}`, `dash.equal`, `dash.band`, `dash.bestShort`, `dash.label.{time,best}`,
`dash.result.{newBest,starsShort,today,tomorrow,saving}`, `dash.racing`, `results.inPlace.hatchShort`. Then
`python scripts/export_localization_csv.py` to check the new rows. The coordinator runs the export and the cloud
sync before the beta publish (not at a live publish), so every new string, "Racing" included, goes through `UICopy`.

## Phone sizes checked by specs

874 x 402 (Spencer's phone), 667 x 375, 568 x 320, 1024 x 768 (tablet, UIScale 1.25), 1920 x 1080. U7 at the measured
phone panes (125 / 162 / 126 x 261) and a 176-wide grid pane.

## Specs

Offline, `python scripts/run_dash_server_specs.py` (luau `build/luau-cli/luau.exe`), each new pure module added to its
module patterns and `CLIENT` list:

- `DashGrid.spec` (new): centring for 1, 2, 8 racers; 1.5 at the line, 0.5 from 11 studs, smooth in between; stones
  0.5; posts clear of the outer slot.
- `DashHud.spec`: pads, lip, word box at 76%, key caps per input, place pill left of the strip, digits at 26%, states.
- `DashProps.spec` (new): tiers, overlap push-up never hides, kinds per viewer, part count stays <= 60 with the mount.
- `DashResults.spec` (new): every `earned.state`, new best, the field with you 1st / 3rd / 6th, Time Trial, race of one.
- `DashSheetLayout.spec` (new): both sheets at the five sizes; nothing outside the card; touch targets >= 44.
- `DashClient.spec`: grid draws, onlooker vs racer tags, lineup camera until GO, results model wiring, hoops sink after
  `race` for onlookers.
- `DashCamera.spec`: lineup fits 70% at each aspect and stays within `StartRoom`.
- `TomorrowStrip.spec`: v2 fit (48, title row, 400 / 240 thresholds), desktop unchanged.
- `FocusRow.spec`, `DeckResultsLayout.spec`, `TipChime.spec` (new).
- Must stay green: `DashOffParity` (off = game before), `DashCrossVersion` (live aeae2d9 saves), all existing Dash specs.

`python scripts/run_dash_specs.py`: `DashCourse.spec` and `DashSim.spec` after the pad move, plus a new pad check
against the DashGrid start width.

Studio-only (src ZZSpecs copies, when Studio is free; not in this step): `PetFocusUI.spec`, `PetFocusKey.spec`,
`DeckResults.spec`, `UICopy.spec` (fits the new strings), `LocalizationFit.spec`, then captures of each sheet on the
phone sizes for Fable's review.

## Order of work

1. DashGrid, pad move, DashMount, camera line-up (U5 geometry). 2. Tags: names, racing pill, inspect exclusion (U5, G4).
3. HUD (U4). 4. DashCard shell, layout, stage, gate (U3). 5. Results (U6). 6. Strip v2, in-place results (U7).
7. Stat chip (U2). 8. Tip chime (S2). 9. UICopy block, export, V3-TEST-PASS "Built, not on the beta" row. One commit per step.

## Risks

- **Pad move rerun**: `build_dash_course.py` must reproduce `Main` exactly; if it does not, stop and hand-patch only
  `Course.Pad` with the script's checks run as a spec instead. Players waiting on the old spot after an update: the
  pad is drawn from the same constant, so it moves together.
- **ViewportFrame pet on phones**: one extra rig while a sheet is open, one RenderStepped; destroyed on close.
- **Merge with U1**: `PetFocusUI` is shared; my edits are `buildBondCard` / `setHeart` / `layoutFocusRow`, U1's the
  hint builders. Rebase on theirs before committing step 7.
- **Part budget** is at 59 of 60: no new parts (tags and chevron reuse the seat anchors). A spec guards it.
- **Live exposure of U7 actions**: a live layout change in the Pocket Deck; needs the Studio `DeckResults` spec and a
  translation check for "Hatch" / "Leave" at 13 in 55 pt.
- **Billboards on top**: names `AlwaysOnTop` only from lock to GO + 1.5, so they never show through walls in the race.
- **Results timing**: `setLine` callers move to `update(model)`; a receipt arriving after the 20 s close is ignored as now.

## Architect review (2026-11-23): these win over the plan above

- **Pad**: (69, -17) failed three checks. The rule is measured against the funnel only: 6.75 at the line (the posts),
  then `3.5 * step(cs) + 0.6`, plus `r + 1`. The pad goes to **(67, -17), r 2.5** (3.5 clear of the funnel, 13.2
  from the cliff, 10.3 from the start, inside the 12-stud join reach). Main, Branch, Layouts and Length byte-identical
  after the rerun; Python and `DashGrid` constants kept in step by a `DashCourse.spec` case. Rechecked:
  `build_find_spots.py --check`, `sweep_island_edges.py --check`, IslandBounds, DashCourse, DashHost, DashClient
  (the line-up eye too).
- Q2: centre the lanes for the whole race; an odd count stands half a slot over at the line (on the `Pad_` slabs).
- Q3: U7 is held behind a v3 switch; the old stack path stays untouched.
- Q4: `DashCard` stays the shell; two separate sheet modules share `DashSheetLayout` and `DashStage`.
- Q5: both OK; the board attribute must carry the broadcast-filtered pet name; `AutoLocalize=false` on names.
- Tags: all 8 seats' anchors are already counted, so name, chevron and Racing are GUI on those anchors. Player pets
  get their anchor position in `Client:drive`; tags not touched in a frame hide.
- No race outcome or save change; `Course.Version` stays 2.

## Questions for the architect (answered above)

1. **Pad**: move the waiting pad (script rerun, only `Course.Pad` changes, `Course.Version` stays 2), or keep it and
   start the funnel at the line so only the posts need room? The second still puts the outer pets 2.7 studs from the
   pad's centre.
2. **Centred lanes mid-race**: with fewer than 8 racers the lanes become centred for the whole race (visual only, sim
   untouched). OK, or centre only through the funnel and drift back to `Course.laneOffset`?
3. **U7 on live**: ship the action compaction and payout restyle unflagged as a layout fix with the next live version,
   or hold them behind a v3 ceiling until the v3 release?
4. **Sheets**: extend `DashCard` with `sheet` kinds plus `DashSheetLayout` / `DashStage` (planned), or two separate
   sheet modules and leave `DashCard` as the generic card only?
5. **Names and chime scope**: other players' pet names read client-side from the public board attributes (no roster
   change), and the chime only for Things lines on the rail, not the station label tips (`onb3.tip.*`). Both OK?
