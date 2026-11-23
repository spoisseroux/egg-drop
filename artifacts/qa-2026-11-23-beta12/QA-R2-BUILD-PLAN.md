# QA R2 build plan (Opus, 2026-11-23)

Implements Fable's `QA-R2-LOOK.md` (Spencer's Round 2 in `FEEDBACK.md`) plus two items from `STUDIO-CHECK-R2.md`.
Branch: this worktree, fast-forwarded to `feat/egg-drop-arcade-polish` (cf61cc0). Target: beta 14. Plan only; nothing
built yet. No Studio, no live, no `save_place`, no AI art or audio.

## Live inertness (place 96451847774961), the rule for every slice

Every change below sits behind a gate that is false on the live place, or is a value that live never reaches:

| Slice | Gate on live | Why it is inert |
|---|---|---|
| 1 Springs | `Kit.alive("springs")` / `Kit.alive("menus")` / `Kit.alive("close")` | Alive ceiling is beta place or Studio only (`Alive.PlaceId`). Off, every path is today's tween. |
| 2 Crickets | `Clock.hourOn()` and `Alive.on("life")` | Cricket voices are made lazily the first time both are on (the `RustleId` pattern), never in `warm`, so live never even preloads them. Bird fade: live daylight is constant .9 (Aero) or .55 (dusk lock), both >= .40, so the fade multiplier is 1 and the night band is never reached. |
| 3 Bird, 4 sizes | `GardenLife` mounts only with `Alive.on("life")` | Birds, butterflies and leaves do not exist on live. |
| 5 Coming up | `Onboard.on("nest")` (OnboardingV3 ceiling is beta/Studio) | `Strip.model` answers nil off, so no strip at all. |
| 6 Flowers | new: R2 ids used only with `Alive.on("life")`; a kind with no R2 id keeps its current id | Live keeps today's five ids and Decal transparency. Placeholders (nil) are a no-op even on the beta. |
| 7a Nest post | `Onboard.on("nest")` | The nest is beta only. |
| 7b Dash pill | `Dash` ceiling (GardenDash, beta/Studio) | Dash is beta only; the fix is also harmless anywhere. |

Offline proof: `scripts/run_dash_server_specs.py` already bundles `LifeSim`, `GardenLife`, `AmbientAudio`, `NestClient`,
`TomorrowStrip`, `DashHud`, `DashClient` with Roblox mocks, and `DashOffParity` / `DashCrossVersion` compare to live (aeae2d9).
`DeckKit` is a stub there, so `KitSpring` / `KitArrive` / `MenuPolish` specs are Studio-only (ZZSpecs copies), run by the coordinator.

## 1. Springs you can see (`DeckKit.lua`, `KitSpring.lua`, menu open/close call sites)

All numbers are Fable's table; `Kit.Motion.bounce` still scales damping via `springTo`; Reduced Motion still snaps
(`Spring.reduced -> Kit.patternStill`); caps (24 touch / 48 desktop) unchanged.

- **PressScale** (new). `Kit.button` today puts `Edge`, `Fill`, `Content` straight under the hit-rect `TextButton`. A
  UIScale must sit on one GuiObject, so add a `Face` frame (AnchorPoint .5/.5, Position .5/.5, Size 1/1, clear, not
  Active/Selectable) holding Edge, Fill and Content, with `UIScale "PressScale"`. The hit rect never scales. Grep found no
  code or spec doing `button:FindFirstChild("Fill"/"Content"/"Edge")`; state keeps direct refs. Down: 60 ms tween to the
  variant's scale; release: `springTo(face.PressScale,"Scale",1,{set = clamp to top})`. One writer per property, as now.
- `Kit.Press`: over 2 -> 5, widen 2 -> 4, frequency 6 -> 4.5, damping .28 -> .32, limit .35 -> .6; PressScale .95, top 1.06.
- Ghost variant: drop 2, PressScale .94, 4.5 Hz / .32, top 1.06. Round key / icon button (`Kit.helpButton`, glyph keys;
  I will list every builder that makes one): PressScale .88, 5 Hz / .32, top 1.12.
- Tiles (`pressTile`/`springTile`): their own `Kit.TilePress` {over 4, 4.5 Hz, .38} and PressScale .96 / top 1.04 on a
  tile `Face` holder (same rule: never beside a foreign UIScale, never under a grid layout: grid tiles get the drop only).
- Wallet `TapScale`: 1.12 -> 1.18 and the Back tween becomes `springTo` 5 Hz / .35, clamp 1.18 (tween kept with springs off).
- Toggle knob: 5 / .65 -> 4.5 / .45, limit .5. `KitPill`: stretch 6% -> 14% mid-flight, 5 Hz / .5, limit .45.
  `KitHop`: velocity 416 -> 620, cap 8 -> 12. `Kit.boing`: from .90 / .88, damping .35, growth cap 8 -> 14 px total.
- **Menus** (`Kit.arrive`): rise 12 -> 28 (22 phone), 3.0 Hz / .42, plus a root scale .90 -> 1 on the same spring,
  clamped 1.03. Phone bottom sheet: from 40 px, 3.2 Hz / .50. Every screen root here already owns a fit `UIScale`
  (`self.scale`, MachineHub:325 and the other five), so the root scale is a virtual property on that UIScale
  (get/set writes `fit * k`); a fit write mid-spring is foreign and wins (cancel, keep fit). AliveBudget level 2: rise only.
  Call sites that use their own 8/12 px tween today move to `Kit.arrive`: QuestLog, DifficultyPicker, DeckMenu (Fable's
  acceptance screen, today an instant `Visible=true`), ConfirmDialog/HowItWorks keep their scale tween unless the architect
  wants them in.
- **Close** (`Kit.depart` plate, already the post-close paint): .12 s Quad In, scale to .94 (shrink .04 -> .06), 10 px
  down, fade. Close stays instant for state.
- `Kit.Pop`: from .70, top 1.12, 4.5 Hz / .40, gap .04, time .55. Toast in: from 16 px, 3.5 Hz / .45.
- Specs: KitSpring (unchanged API), KitArrive (pinned 12 px and `high>=-4` become 28 and the new peak), MenuPolish,
  KitSurfaces (button tree now has `Face`). Studio-only.

## 2. Crickets at night (`AmbientAudio.lua`)

- Birds: `Ambient.birdGain(d) = smoothstep((d-.30)/.10)` on every chirp's volume; `Bands.night` schedules nothing
  (`min/max` kept, `cues={}`; `Birds:step` returns no event in the night band). Dusk/dawn sparse chirps unchanged.
- Crickets (new `Ambient.Crickets` table, not `Ids`): bed 9112764558 at .16, layer 9112764023 at .09, fallback
  9112762451 (swap by changing one field; Canyon 1 9112764040 noted). Gain `smoothstep((.45-d)/.25)`, slewed at most
  .25/s. Both looped 2D voices in the ambience group (so master, Ambience level, round fade, menu and deck ducks apply as
  for birds), `EqualizerSoundEffect` LowGain -18, PlaybackSpeed .97 / 1.03, breathing +-25% on 23 s / 37 s sines.
  A full gust (`self.wind.gust()`) x .8.
- Near crickets: the three bird pool voices are re-pointed at night (same parts) to the three nearest `WorldDressing.Bushes`
  within 40 studs: a 1-2 s trill via `PlaybackRegionsEnabled` + `PlaybackRegion` on the bed id, every 6-14 s each, pitch
  .94-1.08, volume .22, roll-off 6-40; a bush within 6 studs of the listener is quiet, and stays so 4 s after. A pure
  `Ambient.NearCrickets` scheduler (like `Birds`) so the spec can drive it.
- Gate: lazily created on the first step where `Clock.hourOn() and Alive.on("life")`; off again means gain slews to 0 and
  the voices stop at 0. Studio fixture: `options.crickets` / `options.hourOn` injectable.
- Spec: `AmbientAudio.spec` "night uses only the hoo-hoo" becomes "night schedules no birds"; new cases: bird gain
  curve, cricket gain curve and slew (a clock jump takes 4 s), overlap .30-.40, near-cricket hush and 4 s hold, off = no
  voices made, gust duck.

## 3. Bird silhouette (`LifeSim.birdParts`, `GardenLife` bird pool)

- Body: Block + Sphere SpecialMesh via the existing `spindle` helper, (.50,.52,.82), posed `root*Angles(rad(20),0,0)`,
  breast decal on Front. Head Ball .40 at (0,.28,-.30). Beak WedgePart (.09,.08,.20) at head*(0,-.02,-.27), thin edge
  forward (the pool's `part()` grows a Wedge case); fallback spindle (.07,.06,.24) behind one constant. Eyes Ball .08 at
  head*(+-.135,.04,-.12). Folded wings plates (.03,.68,.32) at (-+.25,.03,.11), yaw 8, droop +10. Flying: shoulder
  (+-.20,.10,-.04), half-span .34. Tail plate (.22,.62,.02), pivot (0,-.01,.32), half-length .31, `Sim.Bird.tail` 20 -> -15,
  flick to +5 (`tailUp` relative).
- Sized off it: `Sim.Bird.lift` .50 (the old ball's radius) -> about .30 (the pitched ellipsoid's half height, .28, plus
  the dip); hop/dip numbers unchanged. Bird perch probes and `AmbientPerches` untouched.
- Spec: `LifeSim.spec` part-pose cases updated (8 frames, head 1:2 body, tail 3:4 body, 2.3:1 length to height, beak tip to
  tail tip 1.59); `GardenLife.spec` part sizes.

## 4. Butterflies .52 and leaves (`LifeSim`, `GardenLife`)

Wing plates (.24,.29,.02), hinge +-.013, half offset .12 (`butterflyParts`), body `Life.ButterflySize` (.04,.035,.18) at
.013 forward, `flapHz` {3.0,2.2}, `bob` .04. Leaf keys A {.16,.24,.04,.22}, B {.14,.21,.03,.19}, petal {.11,.17,.03,.15}.
Rates unchanged (the 3.0/1.5 bump only if Spencer finds the air empty). Firefly glow and rest heights unchanged.
Checked: nothing else is sized off the wing (glow is its own `glowFrom`); `Sim.Leaf` drift is size-free.

## 5. "Coming up" strip (`TomorrowStrip.lua`, `UICopy.lua`, the three hosts)

- Rename: instance `ComingUpStrip`; title key `onb3.strip.title` "Coming up"; the phone moon becomes a 10 px clock (disc
  + two 1 px ink hands, 4 px up and 3 px right). The wait line stays.
- New UICopy keys under `onb3.strip` exactly as Fable lists; old `stamp`/`quests` keys removed (the localization sync
  deletes them). `UICopy.spec` sample gains `left`. Number-only short forms keep `AutoLocalize=false`; short forms with
  units ("7 h 52 m", "<1 min", "Ready!", "Done!") are new short keys too, so they translate.
- Pure `Strip.eggParts(left)`: hours floored, minutes the rest rounded up, 60 rolls to the hour; `<60 s` is "under 1 min".
  `Nest.countdown` (the sign's own ceil-hours lines) untouched.
- Chips by state (whole/short/tiny per Fable), gold = ready, ready chips sort first (egg, stamp, quests). Stamp: ready
  while `dailyAvailable`, else "Next stamp: +N", or "Stamp N in H h" once the reset time is known. Quests: count from the
  snapshot's `quests.daily` rows, "Quests done!" with a tick and soft text, or "New quests in H h".
- **Live**: `Strip.new` takes `options.source` (a function returning the model; the hosts pass the existing provider
  instead of a frozen model: DeckResults `self.tomorrow`, DeckResultsInPlace, DashCard/DashResultsSheet via DashClient's
  `strip`). While the strip is shown and parented, a 1 Hz pass rebuilds the model, re-fits only when some chip's text
  changes (about once a minute), writes labels only on change. Egg turning ready: gold plus one `Kit.boing` on the chip
  (Reduced Motion: colour only). The pass stops on hide/destroy.
- Fit: tiny tier added (phone under 300 wide); whole words only when they fit the 125 px column at 400+, else short.
- Spec: `TomorrowStrip.spec` rewritten for the new texts, the eggParts table (7 h 52 m, 7 h, 42 min, <1 min, rollover at
  7 h 59 m 30 s -> 8 h), sorting, the three fit tiers, never truncating, the live pass writing once per minute change.

## 6. Ground flowers (`WorldDressing`, `WorldDressingClient`, import JSON, generator)

- Copy `look/r2/flower_patch_*.png` to `assets/world/textures/r2/` (Fable's PIL output, not AI art).
- `world-dressing-import.json` gains `"flowers_r2": {daisy: "", ...}`; `build_world_v7_dressing.py` emits
  `Dressing.TexturesR2` (empty strings become absent). `WorldDressingClient.build`: per kind, the R2 id when
  `Alive.on("life")` and one exists, else today's id; with R2 in use, `Decal.Transparency = .08`. The client re-picks
  if the Alive attribute arrives after build (`Alive.changed`). After Spencer uploads: paste ids, rerun the script.
- Night tint toward #C8D0E0 under daylight .3 is a **[check]** in Fable's spec; not built unless the beta shows it.
- Spec: `WorldDressing.spec` checks the R2 table shape and the fallback.

## 7. Studio recheck items

- **Nest sign post** covers the "e" from the Back face: the board carries words on both faces, so any post behind it
  hides words from one side. Fix: shorten the post to stop under the board (size .14 x 1.12, centre y .56: top 1.12,
  board bottom 1.05 after its 6 deg tilt), so the board sits on it. `NestClient.spec` sight-line cases unchanged; add one
  that the post's top is below the board's lower edge.
- **Dash place pill "1st" behind a 4th sheet in race 2.** Found: `Hud:show` clears `place.Text` and hides it but never
  resets `self.shown.place`, and `DashClient` only calls `setPlace` while `racing` and while `heat.raceId==seat.raceId`.
  So race 2 starts with a stale cache, writes "1st" at the start line (everyone at Length left -> place 1), and if the
  new heat's tracks lag (or arrive after the pet is home) the pill is never corrected. Fix: `Hud:show` resets `shown`;
  `setPlace` also runs on the last racing frame from the server's final order when known; the pill hides on
  `Hud:rest(true)` (the results sheet is the answer). `DashHud.spec` / `DashClient.spec`: two races back to back, the
  pill never shows race 1's value and is hidden under the results. I will confirm the lagging-heat path in the
  DashClient fixture before choosing between the cache fix alone and the final-order write.

## Order and commits

One commit per slice, specs with it: 7 (small), 4, 3, 2, 6, 5, 1 (largest, Studio-only specs last). Then `TODO.md`,
`V3-TEST-PASS.md` "Built, not on the beta" rows, and the PLAY-BUILD note. Translations: export + sync at publish time
by the coordinator (new and deleted `onb3.strip` keys).

## Risks

- PressScale `Face` holder changes every Kit button's tree; anything that reads child order or sizes Content against the
  button may shift. Mitigation: Face is 1/1 with no padding; run KitSurfaces, MenuPolish, SemanticUI, GlobalUIBounds.
- A root UIScale on the big deck menus re-rasterises text each frame for ~.5 s (Fable's [check] on a low phone). Kept
  behind one constant (`Kit.Rise.scale=false` drops to rise only).
- Decals on a Sphere-meshed block (bird breast): they render projected on the mesh in current Roblox, but the pitched
  body may show it stretched. [check] in Studio.
- WedgePart facing for the beak ([check]); fallback constant ready.
- Cricket candidates unheard; "distant freeway/traffic" in two descriptions. Low cut helps; Spencer decides on the beta.
- PlaybackRegion trills from a 36 s loop may land on a quiet stretch; pick from a few fixed region starts after a listen.
- Strip 1 Hz pass on three result screens: cheap (one model build, compare strings), but must die with the screen.

## Questions for the architect

1. **Countdown time source and refresh.** Egg: `NestClient:summary()` (`view.readyAt` minus `workspace:GetServerTimeNow()`),
   polled by the strip at 1 Hz through a provider, fine? Reset ("in 5 h"): compute the next day boundary client-side from
   `EggCatalog.DayOffsetSeconds` and server time (the `Daily.dayOf` formula), rather than the snapshot's `quests.resetIn`,
   which is stale from the moment it lands. When that boundary passes while the screen is open, `dailyAvailable` is still
   the old snapshot's: I plan to show "Next stamp: +N" / "2 quests to go" with no time until the next snapshot. OK?
   Rows under 1 h: hours rounded up (min 1), since there is no minutes key for them.
2. **Sound gating.** Crickets behind `Clock.hourOn() and Alive.on("life")`, made lazily (never preloaded on live). The bird
   fade and the empty night band are global but inert on live (daylight .9 or .55). Do you want the bird change also
   behind `hourOn` for byte-identical live behaviour, or is "unreachable on live" enough?
3. **PressScale structure.** Add a `Face` holder (Edge, Fill, Content) under every Kit button and tile, or keep the tree
   and scale Fill and Content with two UIScales and anchor maths? I prefer the holder.
4. **Root scale on open.** Compose with each screen's own fit `UIScale` as a virtual property (fit x k; a fit write wins),
   or skip the root scale where a fit UIScale exists (rise only)? And should QuestLog, DifficultyPicker and DeckMenu move
   onto `Kit.arrive` in this slice?
5. **Quests chip semantics.** "{left} quests to go": daily rows not yet claimed (ready-to-claim still counts as to go), the
   weekly ones ignored? And the flowers gate: `Alive.on("life")` or a dedicated switch so the lawn can be A/B'd on its own?
