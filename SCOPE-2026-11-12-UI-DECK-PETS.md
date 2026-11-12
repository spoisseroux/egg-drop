# Scope: UI pass, Pocket Deck Slim, faceplates, boot, quests, difficulty, in-deck results, pet attachments

Written 2026-11-12 by Fable (art and UX lead) from Spencer's ten requests. **Scope only.** Nothing in `src/` changed. The only things built are the Blender mock (`assets/art-source/pets/pet-bear-attachments.blend`) and the boards in `artifacts/scope-2026-11-12/`.

Effort: **S** under 2 hours, **M** about half a day, **L** a day or more. Anything that moves Stars is listed under "Decisions for Spencer" and is not decided here.

| Board | What it shows |
|---|---|
| [01-attachment-anchors.png](artifacts/scope-2026-11-12/01-attachment-anchors.png) | All anchors on the Bear, front and back |
| [02-attachment-mock-outfits.png](artifacts/scope-2026-11-12/02-attachment-mock-outfits.png) | Placeholder shirt, necklace, helix ring, beanie, alternate eyes, mouth and tail; slot rules |
| [03-horn-sizes.png](artifacts/scope-2026-11-12/03-horn-sizes.png) | Devil horns, stages 1 to 5 |
| [04-ui-system.png](artifacts/scope-2026-11-12/04-ui-system.png) | Surfaces, type, components, icons, motion and sound |
| [05-pocket-deck-slim.png](artifacts/scope-2026-11-12/05-pocket-deck-slim.png) | The new handheld look |
| [06-faceplates.png](artifacts/scope-2026-11-12/06-faceplates.png) | 16 faceplates and how each tints the UI |
| [07-boot-sequence.png](artifacts/scope-2026-11-12/07-boot-sequence.png) | Boot storyboard and timeline |
| [08-deck-screens-flow.png](artifacts/scope-2026-11-12/08-deck-screens-flow.png) | Heat picker, quest log, results, back arrow, flow |

The boards are concept drawings made with Python, not Studio captures. The 3D renders are real background-Blender renders of the mock file.

## What I found in the current build

- **Two type systems are live at once.** The deck body uses FredokaOne and PatrickHand (`Art.Font`), the sheets use BuilderSans (`Art.SheetFont`). The recap mixes mono, hand-drawn and sans in one panel (`batch/04-star-countup-final.jpg`).
- **The new glass tint works, the layout under it has not caught up.** `DeckThemes` already derives `theme.ui` from the shell and button colours. The sheets still use four different card treatments (menu, daily, style rows, recap rows).
- **The recap floats over the device** and covers half the tray, the score bar and the Lounge cap. Six unlabelled coloured dots sit in the middle of it.
- **The deck body carries reading.** Score, goal, queue and drop count are on the grips, so the case is 1.5:1 and the grips are mostly empty green.
- **The held 3D device is a plain box** (`handheld-after-front.jpg`, `Lounge.lua`), so the deck style barely shows in the garden.
- **Quests are thin.** Details in section 5.

---

## 1. UI pass

**Goal.** One system that reads as a console dashboard: dark glass, big confident type, one accent, obvious focus. Every screen should look like it came from the same device.

**Design** (board 04).

- **Surfaces.** Keep the shipped rule: glass `#15171B`, raised `#23262C`, well `#0C0D10`, each leaning 10 to 16% toward the faceplate's deep colour. Add one 1 px white stroke at 14% and one drop shadow. No second panel style.
- **Colour roles.** Text is always neutral (`#F3F4F6`, `#C3C8D0`, `#8A909A`). The faceplate accent is only for selection, focus fill, primary action and progress. Stars are always `#FFC14D`. Danger is `#FF5A6E` plus a word.
- **Type.** Six sizes, two faces.

  | Role | Size (compact) | Face | Use |
  |---|---|---|---|
  | Display | 40 (30) | BuilderSans ExtraBold | The Stars number or outcome. One per screen. |
  | Title | 26 (20) | BuilderSans Bold | Screen and sheet titles |
  | Heading | 20 (17) | BuilderSans Bold | Card titles, tabs, primary button |
  | Body | 16 (14) | BuilderSans | Rows, descriptions |
  | Label | 13 (12) | BuilderSans Bold, caps | Eyebrows, chips, hints |
  | Counter | 18 (15) | RobotoMono | Anything that ticks |

  FredokaOne stays only in the wordmark. PatrickHand is retired from UI text.
- **Spacing and shape.** 4, 8, 12, 16, 24, 32. Radius: chip full, button 12, card 14, sheet 20. Targets stay 44 px or larger.
- **Components.** Each gets one constructor in `DeckArt`:
  - **Button:** primary (accent fill, dark text, 3 px lower edge), secondary (raised, stroke), ghost, disabled, destructive. Optional input glyph chip (A, B) on the left.
  - **Focus:** 2.5 px white ring with a soft glow, 4 px outside the control. The ring slides between targets.
  - **Tabs:** one pill track; the selected pill slides. A gold dot marks a tab with something to claim.
  - **Card:** icon well, title, one supporting line, progress, reward. Four states: in progress, ready, claimed, locked.
  - **Toggle, stepper, chip:** as drawn. The stepper replaces today's cycle-on-tap sound setting.
  - **Progress:** bar, segmented (for counts of 10 or fewer), ring.
  - **Toast:** top centre, 2.4 s, one at a time.
  - **Wallet pill:** star plus mono count, same place on every screen.
- **Icons.** One set: 2 px stroke, round caps, at most one accent fill, 24 grid. Ten to start: back, quests, stars, replay, reroll, lock, difficulty, faceplate, check, settings. Draw them once as an image sheet rather than building each from Frames.
- **Motion and sound.** The table on board 04 is the spec. Three new cues are needed: `quest_done`, `deny`, `boot_chime`. Everything else reuses `BoardAudio`. Every motion has a Reduced Effects fallback.

**Per-screen notes.**

| Screen | Change |
|---|---|
| Board HUD | Moves inside the glass (section 2). Score and drops in mono. Goal as a two-line card with a progress bar. |
| Pocket menu | Becomes the quest log plus Settings, opened from the Menu pill. "Hatch eggs" stays reachable but stops being the first tile. |
| Daily | Folded into the quest log (section 5). |
| Deck style | Tabs become Faceplate and Background. Rows show a mini deck render, not a colour chip. "Selection applies immediately" becomes a toast. |
| Egg shop | Same layout, new cards. Odds in mono. Price uses the wallet pill style. |
| Hatch reveal | Display size for the item name, one primary button. No layout change. |
| Journal, companions | Shared header (title left, wallet right, close right). Card grid from the new card. |
| Recap | Replaced by the in-glass results screen (section 7). |
| Garden dock, pet focus | Glass circles in the same style as the back arrow. |

**Files.** `src/client/DeckArt.lua` (tokens, constructors), `DeckMenu.lua`, `DeckPicker.lua`, `EggHatchView.lua`, `HatchReveal.lua`, `PetJournal.lua`, `StoreView.lua`, `RoundRecap.lua`, `BoardQuestHUD.lua`, `FieldQuestText.lua`, `PetFocusUI.lua`, `RoomView.lua`, `BoardAudio.lua`, `src/shared/DeckThemes.lua`.

**Effort.** L (about 3 days): tokens and components M, then about 8 screens at S to M each.

**Risks.**
- Many client specs assert sizes, fonts and node names (SharedFinish, SharedHeaders, PreferredTextLayout already fail at HEAD). Budget spec updates with every screen.
- BuilderSans is wider than PatrickHand at the same size. Largest text preference on the 733×307 phone root is the tight case.
- An icon sheet is an image upload (moderation wait). Fallback: keep Frame-built icons for v1.

---

## 2. Pocket Deck look: "Slim"

**Goal.** A compact, premium, slim landscape handheld with a metal rim and a swappable front plate. Visual only.

**Design** (board 05). Three layers:

1. **Band.** A thin anodised metal rim, about 3.5% of the height. It never changes shape. Two shoulder nubs sit on the top edge.
2. **Faceplate.** The whole front face inside the band. It carries the colour, finish and print (section 3). Two thumb screws at the top corners make it read as removable.
3. **Glass.** A wide dark window, 50% of the width and 80% of the height. The 11:19 tray sits in the centre; score and goal sit to its left, next and drops to its right.

Controls: a smoked two-way rocker on the left, a large accent A and a small dark B on the right, a Menu pill under the rocker, a five-dot seed speaker, a status LED and an engraved POCKET DECK mark.

```
 ____[L]__________________________________[R]____
/ o                                            o \
|  POCKET   +------------------------------+      |
|  DECK     | SCORE  |            | NEXT   |  (A) |
|           | GOAL   |    tray    | DROPS  |      |
|  (< | >)  |        |   11:19    |        | (B)  |
|  [MENU]   +------------------------------+  ::. |
\________________________________________________/
```

The body goes from about 1.5:1 to 2:1. Moving the HUD into the glass is what makes the slim shape possible, and it is also what sections 6 and 7 need.

**Original, not a copy.** The tall egg tray in a wide window, the two-way rocker, the seed speaker and the egg in the wordmark are ours. There is no cross pad, no start/select pair, no traced silhouette and no third-party logo shape.

**The held 3D model.** Replace the box Part with one low-poly mesh (about 300 tris) with two material slots, band and plate. Finishes map to Roblox materials: Gloss = SmoothPlastic, Brushed = Metal, Pearl = a PBR SurfaceAppearance, Clear = Glass at about 0.35 transparency, Matte = Plastic. I did not model this; it needs Spencer's go-ahead on the shape first.

**Files.** `DeckArt.lua` (`Art.deck`, `Art.finish`, `Art.instrument`), `DeckLayout.lua` (new solve: glass first, then grips), `init.client.lua` (HUD parenting, around lines 440 to 660 and 1550 to 1670), `DeckWordmark.lua`, `BoardQuestHUD.lua`, `JellyLCD.lua`/`DeckBackdrop.lua` (tray inside a wider LCD), `src/server/Lounge.lua` (held device), `UI-EDITING.md`.

**Effort.** L. 2D skin M; layout re-solve with HUD in the glass M to L; held mesh M (after an art pass).

**Risks.**
- `DeckLayout.resolve` has explicit short-landscape (568×160) and portrait branches. On a 307 px-high phone the side columns are about 95 px wide; the goal text must fit two lines at Largest. Portrait keeps today's stacked layout and only takes the new skin.
- The doc's 48 to 55% tray-width rule changes meaning (it becomes glass width). Update `UI-DESIGN-SYSTEM.md` with the pass.
- Finishes are drawn with gradients and a few images. Brushed and pearl need one small tiling texture each (uploads).

---

## 3. Faceplates instead of stickers

**Goal.** One collectible that changes how the deck looks in the hand, in the garden and in every menu.

**Design** (board 06). A faceplate is `colourway + finish + optional print`. It is the existing `DeckThemes` entry with two new fields, `finish` and `print`. Saved theme ids do not change.

| # | Plate (id) | Finish | How you get it today or proposed |
|---|---|---|---|
| 1 | Scout (`sherbet`) | Gloss | Free, default |
| 2 | Pebble (`stone`) | Matte speckle | Free |
| 3 | Creek (`ice`) | Clear (you can see the board inside) | Free |
| 4 | Ember (`brick`) | Brushed metal | Free |
| 5 | Canopy (`moss`) | Leaf print | Free |
| 6 | Honey (`honey`) | Pearl | Win 1 round (existing `firstWin`) |
| 7 | Gloaming (`gloaming`) | Two-tone gloss | Win 3 rounds (existing `rankI`) |
| 8 | Copperleaf (`copperleaf`) | Brushed copper | Win 10 rounds (existing `rankII`) |
| 9 | Graphite | Brushed gunmetal | Stars, direct buy |
| 10 | Moonmilk | Pearl white | Stars, direct buy |
| 11 | Gumdrop | Clear pink | Stars, direct buy |
| 12 | Checker Jam | Checker print | Weekly quest reward |
| 13 | Starfield | Star-speckle gloss | Milestone: 50 wins |
| 14 | Trial Crest | Etched metal | Finish the 3 Pocket Trials (was the Trial crest sticker) |
| 15 | Lantern | Lantern-dot print | Chain 3 merges (was the Lantern stamp) |
| 16 | Obsidian | Mirror black, red accent | Milestone: clear all 6 goals on Hard |

- **Sticker migration.** `DeckStickers` is retired. Trial crest and Lantern stamp become plates 14 and 15 with the same unlock rules, so nobody loses an earned item. Star, Glitch and Seed were free and are dropped. Wick (rank 3) is legacy and is dropped unless Spencer wants a plate for it. Saves are wiped at launch, so no data migration is needed, only tolerant reads of an old `sticker` field.
- **How it tints the UI.** Each plate supplies `accent` (bright) and `shell` (deep). `DeckThemes` already turns those into `theme.ui`. The chip under each plate on board 06 is that derivation. Rule: accent must reach 4.5:1 against `#0E0F12` text; Obsidian and Graphite were chosen to prove dark and neutral plates still work.
- **In the garden.** The plate's colour and finish drive the held model's plate material, so other players see it.
- **Picker.** The Style sheet shows a 2-column grid of mini decks. Locked plates show how to earn them and current progress.

**Files.** `src/shared/DeckThemes.lua`, `AppearanceCatalog.lua` (unlock rules), `DeckStickers.lua` and `DeckStickerArt.lua` (retire), `src/client/DeckPicker.lua`, `DeckArt.lua`, `src/server/AppearanceIntent.lua`, `Lounge.lua`, `init.server.lua` (appearance validation near line 249), `HatchProgress.lua` if plates are bought with Stars.

**Effort.** M for the 8 existing plates with finishes and the sticker retirement. M more for 8 new plates with unlock rules. S more for a Star purchase path.

**Risks.**
- A Star purchase is a wallet change and must go through `HatchProgress` `transact` with an operation id.
- If plates ever come from an egg they become a paid random item (odds on the card, half refund on duplicates). A direct price avoids that.
- Clear plates need the 2D case to show something behind them; a static printed "circuit" image is enough.

---

## 4. Startup animation: "the first drop"

**Goal.** A retro handheld start-up that is ours: under 2 seconds, skippable, and it teaches the game's one verb.

**Design** (board 07). Total 1.8 s, all inside the glass.

| Time | Beat | Sound |
|---|---|---|
| 0.00 | Glass black. LED blinks once. | Soft low "tok" |
| 0.12 | One accent scanline opens top and bottom. Faint horizontal rows appear. | |
| 0.35 | A pixel egg falls from the top in 8 px steps and squashes on landing. | Existing `drop` ("plip") |
| 0.70 | The egg pops. POCKET DECK dithers in left to right on a chunky pixel grid. | Existing `merge_bubble` |
| 1.05 | Letters flash white, settle to the plate accent, the O fills gold, four sparks. EGG DROP sub-line fades in. | New `boot_chime` |
| 1.50 | Checker-dither dissolve to the start screen. Input is live. | |

- **Wordmark.** An original 5×7 pixel face drawn for seven letters, POCKET over DECK, with the O filled like an egg. It replaces the tilted FredokaOne mark in the boot and is engraved small on the plate.
- **Chime.** Three rising notes (C5, G5, E6), square wave with a bell tail, 0.45 s. It is not a two-note "ba-ding" and not any existing console's jingle. Brief the audio engineer with the row in `AUDIO-HANDOFF.md`; until then the synth bank (`scripts/synth_egg_drop.py`) can generate a draft.
- **Skip.** Any input from 0.15 s jumps to the hand-off. The existing boot token (`Transition:owns`) already cancels delayed work.
- **Reduced Effects.** Show the finished logo for 0.4 s, no motion, chime still plays at normal volume.
- **When it plays.** Only on a real arrival at the deck, exactly as `UI-DESIGN-SYSTEM.md` "Presentation ownership" says. Never over results or a menu.

**Files.** `src/client/DeckTransition.lua` (`reveal`, lines 74 to 100), `DeckWordmark.lua` (new pixel mark; keep the old API), `BoardAudio.lua` (`boot`), `PresentationPolicy.lua`, `AUDIO-HANDOFF.md`.

**Effort.** M. The pixel mark is about 150 small Frames, or one image (S once uploaded).

**Risks.**
- Boot and recap have collided before (baseline capture 12). Keep the existing ownership tests and add a skip test.
- A new sound needs an upload and moderation. Ship with the existing boot cue if it is not ready.

---

## 5. Keeping the deck exciting: quest audit, rotation and log

### What exists today

| System | Where | What it does | Gap |
|---|---|---|---|
| **Field objectives** | `src/shared/FieldObjectives.lua`, `src/server/FieldRun.lua` | 6 two-goal templates (Bank pair, Creek crossing, Lantern chain, Ripple relay, Bank bounce, Mirror marks) with 3 bounce presets. A win pays 6 Stars, +2 if the stack ends below height 7.5. | They rotate in a **fixed order** by completed-round count (`Objectives.next`). No player choice, no difficulty, nothing harder than tier III. |
| **Daily contracts** | `src/shared/DailyContracts.lua` | 3 contracts: Win 2 rounds (+4), Chain 3 (+3), Score 500 (+3). Auto-credited. Day rolls at UTC−5. | **The same three every day.** 10 Stars a day, forever. No reroll, no claim moment. |
| **Daily gift** | `HatchProgress.lua` (`dailyClaimDay`, `EggCatalog.DailyBonus`) | One claim a day. | Fine. No streak. |
| **Pocket Trials** | `src/shared/PocketTrials.lua` | 3 one-time goals (Triple Pop, High Roller 250, Clean Sweep) for the Trial crest sticker. Two more bits (Fivefold, Double Sweep) are leftovers from the retired rare pets. | Done in the first session. Nothing after. |
| **Unlock rules** | `AppearanceCatalog.lua` | firstWin, 3 wins, 10 wins unlock deck styles. | Three steps, then nothing. |
| **Petting** | `PetContact.lua` | +1 Star, daily cap. | Fine. |

There is **no weekly quest, no streak, no reroll, no milestone ladder and no log**. So the honest answer to "did we add more quests" is: the round goals got more varied (6 templates), the dailies did not.

### Design (board 08, screen B)

**One quest log on the deck**, opened with the shoulder nubs or the Menu pill. Three tabs.

**Today (3 slots, new at the daily roll).**
- Each day draws one quest from each of three pools, seeded by user id and day so it is stable across rejoins.

  | Pool | Examples | Reward |
  |---|---|---|
  | Play | Win 2 rounds. Finish 3 rounds. Play each heat once. | 3 to 4 |
  | Craft | Chain 4. Make 3 tier IIIs in one round. Finish with the stack below the line. Complete a goal with your first 8 drops. | 3 to 4 |
  | Skill | Make a tier IV on Hard. Win Hard without the danger line arming. Clear a tier V pair. Score 800. | 5 |

- About 18 quests to start (6 per pool).
- **Reroll:** one free reroll a day, on an unstarted quest, to another from the same pool. More rerolls are a decision for Spencer.
- **Claim:** rewards are claimed from the row (a button press and a Star count-up) instead of being silently credited. The results screen shows "claim in log".

**This week (3 slots, new on Monday).** Bigger counts that reward playing across days: Win 12 rounds. Win 3 on Hard. Complete all 6 goal types. Reward: Stars and, for finishing all three, a faceplate (Checker Jam first).

**Milestones (permanent).**
- **Goal stamps:** a 6 × 3 grid, one stamp per goal template per heat. 18 stamps. This is the "difficult to master" track; all six on Hard unlocks Obsidian.
- **Ladders:** total wins (1, 3, 10, 25, 50, 100), total merges, tier V clears, best chain, daily streak. Each step pays a small Star amount or a plate. The existing firstWin, 3 and 10 rules become the first rungs.
- Pocket Trials become the first three milestone rows.

**Streak.** A 7-dot row under Today. Playing one full round a day fills a dot. Day 7 pays a faceplate token or Stars. Missing a day resets the row but never takes anything away.

**Why this keeps it exciting.** Easy to play: one quest is always nearly done, and every round ticks something. Hard to master: the Skill pool, the weekly Hard quest and the 18 stamps all ask for Hard heat.

**Server shape.** A `quests` record next to `daily`: `{ day, slots = {id, progress, claimed}, rerolls, week, weekSlots, streak = {lastDay, count}, lifetime = {...}, stamps = bitmask }`. `Daily.apply` becomes the pattern: pure functions that take a round summary and return the new record and what completed. Claims go through `HatchProgress` `transact` with an operation id. The round summary needs a few more facts (heat, max tier made, drops used per goal, whether danger armed).

**Files.** New `src/shared/QuestCatalog.lua`, `QuestRotation.lua`; `DailyContracts.lua` (replaced or wrapped), `PocketTrials.lua` (folded in), `src/server/HatchProgress.lua`, `PlayerProgress.lua`, `ProgressStore.lua`/`SessionProfile.lua` (schema), `init.server.lua` (round settlement), `EconomyAnalytics.lua` (new source names), `FieldRun.lua` (summary facts), `src/client/DeckMenu.lua` (becomes the log), `BoardQuestHUD.lua`, new specs.

**Effort.** L (3 to 4 days): catalog and rotation M, server record, claims and specs L, log UI M, milestones and stamps M.

**Risks.**
- **Save schema.** New fields before the launch wipe are cheap; after launch they need a migration. Do this before launch or not until after.
- Day and week boundaries with rejoin and clock rollback: reuse the rules already in `Daily.apply`.
- Claimable rewards can pile up unclaimed. Auto-claim anything older than the next roll.

### Decisions for Spencer (quests)
1. Daily Star total. Today it is 10 from contracts. The proposal is 11 to 13 depending on the Skill quest. Keep 10, or allow up to 13?
2. Weekly reward size, and whether weekly gives Stars at all or only a faceplate.
3. Extra rerolls: none, a Star price, or one extra for Supporter?
4. Does the 2× Stars pass double quest claims (today it doubles contracts)?
5. Streak reward: Stars, a faceplate token, or cosmetic only?
6. Claim by hand (proposed) or keep silent auto-credit?

---

## 6. Difficulty choice: "pick your heat"

**Goal.** The player picks Easy, Medium or Hard on the deck's start screen. Harder pays more. Easy must still feel like winning.

**Design** (board 08, screen A). Three cards in one row, so the two-way rocker is enough. Medium is selected the first time; after that the last choice is remembered. A starts.

| | Easy "Breezy" | Medium "Classic" | Hard "Spicy" |
|---|---|---|---|
| Drop bag (`BoardSimulation` bag) | 5 × I, 1 × II | 4 × I, 2 × II (today) | 3 × I, 2 × II, 1 × III |
| Danger line (`FieldRun.roundOptions.overflowY`) | 9.6 | 8.6 (today) | 7.6 |
| Grace before overflow | 3.0 s | 2.4 s (today) | 1.6 s |
| Line arms after | 16 drops | 12 drops (today) | 6 drops |
| Goals | 2, tier II targets | 2, tier III targets (today) | 3: today's two plus one tier IV or chain 3 |
| Speed | No clock | No clock | Shot clock: auto-drop after 6 s |
| Bounce | Preset × 0.85 | As the template says | Preset × 1.1 |
| Score multiplier | × 1 | × 1.5 | × 2 |
| Star multiplier (proposed) | × 1 | × 1.5 | × 2 |

- **Medium is exactly today's round**, so all current balance data and solver replays still apply to it.
- **Score** is multiplied so a personal best per heat means something; bests are stored per heat.
- **The shot clock is the only real-time pressure** and only on Hard. It shows as a thin bar shrinking under the aim line.
- **Losing.** No change proposed here (0 Stars), but see the decisions.
- **Replay** from results keeps the heat. Holding left or right on Replay opens the picker again.
- **First session.** The first three guided rounds skip the picker and run Easy rules.

**How it fits Stars.** Today a win pays 6 or 8. With the proposed multipliers on the base 6 and the +2 bonus:

| | Win | Win + tidy stack | Wins for a Feature Egg (32) |
|---|---|---|---|
| Easy × 1 | 6 | 8 | 4 to 6 |
| Medium × 1.5 | 9 | 12 | 3 to 4 |
| Hard × 2 | 12 | 16 | 2 to 3 |

That makes Medium pay 50% more than the same round pays today, which is inflation. The alternative that keeps today's income is Easy × 0.75, Medium × 1, Hard × 1.5 (4 to 6, 6 to 8, 9 to 12).

**Files.** `src/shared/BoardConfig.lua` (new `Heat` table), `FieldObjectives.lua` (third goal, `validatePublic` currently requires exactly 2 goals), `src/server/FieldRun.lua`, `BoardSimulation.lua` (bag), `BoardRound.lua`, `init.server.lua` (start-round remote takes a validated heat; reward settlement near line 445), `HatchProgress.lua`, `EconomyAnalytics.lua`, `src/client/init.client.lua`, new `DeckStartScreen.lua`, `BoardQuestHUD.lua`/`FieldQuestText.lua` (3 goals), `scripts/` solver specs.

**Effort.** L (2 to 3 days). Config and server M; three-goal support M (it touches validation, HUD and recap); picker UI M; balance pass with the solver M.

**Risks.**
- **Three goals** ripple through `validatePublic`, `BoardQuestHUD`, the results checklist and several specs. A cheaper Hard keeps 2 goals at tier IV.
- **Server authority.** Heat is chosen by the client but validated and stored on the server at round start; rewards read the stored value.
- Hard may be unwinnable on some templates. Run the six-seed solver on all 6 templates per heat before it ships, then a human pass.
- Shot clock plus mobile lag: pause the clock while the save-wait or "Falling" states block input.

### Decisions for Spencer (difficulty)
1. Which multiplier set: 1 / 1.5 / 2 (pays more than today on Medium) or 0.75 / 1 / 1.5 (Medium unchanged)?
2. Do the multipliers stack with the 2× Stars pass and the Supporter +1? Hard with both would be up to 33 a win.
3. Does the multiplier apply to the +2 tidy-stack bonus, or only to the base 6?
4. Should a loss on Hard pay a consolation Star (ties to A2 in `OVERNIGHT-2026-11-12.md`)?
5. Is Hard open from the start, or unlocked by a few Medium wins?
6. Hard: 3 goals plus shot clock (proposed), or just one of them?

---

## 7. Results inside the deck, and the back arrow

**Goal.** The end-of-round screen lives in the glass and is driven by the deck's own controls. One back arrow, always in the same place, off the body.

**Design** (board 08, top-left and screen C).

```
 viewport                                    ( <- )   back arrow: top right of the
  ______________________________________________      view, outside the device
 /            ROUND CLEAR                       \
 |  POCKET    Creek crossing | Medium           |
 |  DECK        * +12 Stars                     |
 |           [ PAYOUT      ] [ GOALS  v v     ] | (A)
 |  (< | >)  [ win 6       ] [ score best x4  ] |
 |           Quests: 2/2 done, 4/4 done, 3/5    | (B)
 |  [MENU]   [  Replay  ]  [ Leave to garden ]  |
 \______________________________________________/
```

- **Order, top to bottom:** outcome and heat; the Stars number (the only Display-size text); payout lines; goals with checks; score, best, chain; one quest strip; two buttons.
- **Two choices only:** **Replay** (primary, focused on open) and **Leave to garden**. Left and right move focus, A confirms, B is Leave. Touch taps the same buttons. The focus ring is the system ring.
- **Leave** runs the existing lounge transition (today's Lounge cap handler, `roomButton.Activated`, `init.client.lua:611`).
- **"Hatch eggs" leaves the recap.** If the player can afford an egg, the quest strip shows "You can hatch an egg" and the egg spot in the garden glows. The buying moment stays in the world.
- **Loss** uses the same layout: "Overflow" or "Goals missed", which goal was missed, 0 Stars shown plainly, Replay still focused.
- **Pending save** shows "Saving..." on a disabled Replay; Leave stays usable (existing behaviour).
- **Back arrow.** A 56 px glass circle at the top right of the view, 24 px inside `CoreUISafeInsets`, on every deck screen.
  - At the start screen or results: leave to the garden at once.
  - Mid-round: pause and leave, exactly as the Lounge cap does today; coming back resumes.
  - In the quest log: go back one screen.
  - Controller B, keyboard Esc or Backspace.
- **The Lounge and Menu caps come off the body.** Lounge is the back arrow; Menu is the small pill under the rocker.

I read "top right of the pocket deck screen, not on the body" as the top right of the full deck view. If Spencer meant the top right of the LCD glass itself, the same button moves inside the glass and nothing else changes.

**Files.** `src/client/RoundRecap.lua` (rebuild as an in-glass screen; keep `RunReceipt` and `RecapFeedback` as data owners), `init.client.lua` (modal ownership near lines 658 and 1440 to 1520; utility buttons near 440 and 1646), `ControllerFocus.lua`, `RoundEndPresentation.lua` (confetti stays under the screen), `DeckLayout.lua` (remove `l.lounge`, add back-arrow rect), `PresentationPolicy.lua`, `LoungeStations.lua`.

**Effort.** M to L (1.5 to 2 days). It depends on section 2's glass layout; without it, the screen can be built inside today's tray as an interim (narrow, one column).

**Risks.**
- The recap is the most heavily tested screen (receipts, stale receipts, zero rewards, save notices). Keep the data path and replace only the view.
- The rocker has no up or down. Every in-glass screen has to work as a single row or a single list. The designs above do.
- The top-right corner holds Roblox's own buttons on some layouts; staying inside the safe insets covers it, and it needs a phone check.

---

## 8. Pet attachment points

**Goal.** One anchor vocabulary for every pet, so any future cosmetic knows where it goes, which way it faces and what it conflicts with.

### Conventions

- **Naming.** `<Pet>__Anchor_<Name>`, an empty under the pet root. Meshes are `<Pet>__<Role>`, parented to their anchor with an identity transform, with custom properties `role`, `channel`, `slot`.
- **Axes.** 1 unit = 1 stud. Front is −Y, up is +Z, L = −X (as in `PET-STYLE-GUIDE.md`).
- **Orientation.**
  - *Surface anchors* (horns, hat, helix, wrist, claws): local **+Z leaves the surface**, local Y stays as close to world +Y as it can. A part modelled "growing up +Z" sits correctly on any pet.
  - *Face anchors* (eyes, mouth, nose, cheeks, bridge, forehead): **identity rotation**, so textures and decals stay upright. The anchor sits on the surface; the part is modelled pushed out along −Y.
  - *Swap anchors* (tail, torso): identity, origin at the joint.
- **Left and right.** R is positioned as the mirror of L. Never use negative scale; L and R are separate meshes.
- **Channel** is the body part the anchor moves with in the rig (`Head`, `Body`, `HandL/R`, `FootL/R`, `Root`). A cosmetic inherits its anchor's channel, so ear flicks, head turns and arm swings carry it for free.
- **Scale.** Anchors are always scale 1. Parts are authored at Bear size. A pet with a different head sets one number per channel (`fit.Head`, `fit.Body`) in its rig definition; the importer multiplies every part on that channel. Rings, beads and horns get a floor (never below 0.8) so they stay readable.
- **Depth.** Hard parts sink 0.02 to 0.03 into the surface. Cloth shells sit 0.024 off the body. Nothing may pass z = 0.

### The anchors

Positions are for the Bear, in root-local studs, read from the mock file. "Exists" means it was already in `pet-bear.blend`.

| Anchor | Channel | Slot | Position (x, y, z) | Notes |
|---|---|---|---|---|
| HatCrown | Head | Hat | 0, −0.03, 1.38 | Top of the skull. Hat radius up to 0.19 clears the ears. |
| HornL / HornR | Head | Horns | ∓0.175, −0.10, 1.35 | Tilted 17° outward, 8° forward |
| HelixL / HelixR | Head | EarPiercing | ∓0.44, 0, 1.43 | Upper outer ear rim, 45° |
| LobeL / LobeR | Head | Earring | ∓0.46, 0, 1.25 | Lower outer rim; drops hang along world −Z |
| EarL / EarR | Head | (ears) | ∓0.33, 0, 1.27 | Exists |
| EyeL / EyeR | Head | Eyes | ∓0.21, −0.42, 1.03 | Eye swaps |
| FaceBridge | Head | Eyewear | 0, −0.46, 1.04 | Glasses, masks |
| EyeLine | Head | (gaze) | 0, −0.47, 1.03 | Exists |
| Forehead | Head | Forehead | 0, −0.37, 1.24 | Gem, bow |
| CheekL / CheekR | Head | Cheek | ∓0.36, −0.31, 0.88 | Blush, whiskers |
| Nose | Head | Nose | 0, −0.51, 0.905 | Nose swaps |
| Mouth | Head | Mouth | 0, −0.51, 0.80 | Mouth swaps |
| Head | Head | (joint) | 0, −0.02, 0.70 | Exists |
| Neck | Body | Neck | 0, −0.07, 0.63 | Necklace, scarf, collar. Ring tilts 0.03 down at the front. |
| Torso | Body | Shirt | 0, −0.05, 0.455 | Same point as Body |
| Chest | Body | Chest | 0, −0.40, 0.50 | Badge, bib |
| Back | Body | Back | 0, 0.22, 0.52 | Backpack, cape |
| WingL / WingR | Body | Back | ∓0.11, 0.17, 0.54 | Exists |
| Tail | Body | Tail | 0, 0.24, 0.33 | Exists. Tail swaps. |
| HandL / HandR | HandL/R | (shoulder), sleeves | ∓0.225, −0.06, 0.655 | Exists |
| WristL / WristR | HandL/R | Wrist | ∓0.33, −0.11, 0.49 | Bracelet, watch |
| ClawL / ClawR | HandL/R | Claws | ∓0.39, −0.14, 0.39 | Paw tip |
| FootL / FootR | FootL/R | (joint) | ∓0.165, −0.08, 0.10 | Exists |
| AnkleL / AnkleR | FootL/R | Ankle | ∓0.165, −0.01, 0.17 | Sock cuff, anklet |
| ToeL / ToeR | FootL/R | Claws | ∓0.165, −0.325, 0.08 | Toe claws |
| CharmFloat, CharmLeft, CharmRight, CharmCenter | Root | Charm | see file | Exist |
| HandCatch | Root | (toy) | 0, −0.47, 0.45 | Exists |
| Ground | Root | Aura | 0, 0, 0 | Shadow, aura ring |

That is 28 new anchors and 19 existing ones. There is deliberately **no legs or pants anchor**.

### Slots and exclusivity

| Slot | One at a time? | Blocks / is blocked by |
|---|---|---|
| Hat | Yes | A full hat hides **Horns** and **CharmCenter**. Hats flagged `openCrown` (bands, bows) keep horns. Hats flagged `hidesEars` hide EarPiercing and Earring. A low brim hides Forehead. |
| Horns | One style, 5 stages | Hidden under a full hat. The earned stage is kept; only visibility changes. |
| EarPiercing, Earring | Per ear, independent | Hidden by `hidesEars` hats |
| Eyes | Yes (swap) | Eyewear stacks on top unless the eye style says `noEyewear` |
| Mouth, Nose | Yes (swap) | Expressions still pick the mouth frame |
| Neck | Yes | Necklace or scarf or collar. Sits over a shirt. |
| Shirt | Yes | A printed chest blocks Chest. Sleeves are separate meshes on HandL/R. |
| Back | Yes | Wings or a backpack or a cape |
| Tail | Yes (swap) | Replaces the species tail |
| Claws | One style, 5 stages | Mittens would hide hand claws |
| Wrist, Ankle | Per side | None |
| Charm | Yes | CharmCenter is hidden by a full hat; CharmFloat sits above any hat up to 0.18 tall |

The rule the code should enforce is hide, never unequip: a blocked item stays owned and selected and comes back when the blocker is removed.

### The mock

`assets/art-source/pets/pet-bear-attachments.blend` is a copy of `pet-bear.blend`; the original is untouched. Added collections:

- `PetBear_AttachAnchors`: the 28 new empties (arrow display, with `channel`, `slot`, `excludes`, `note` properties).
- `PetBear_AttachPlaceholders`: `Hat_Beanie`, `Shirt_Tee` (a shell of the body mesh, hem cut above the legs) with `Shirt_Tee_SleeveL/R` on the arm channels, `Neck_Beads`, `HelixL_Ring` (left ear only), `EyeL/R_AltButton`, `Mouth_AltO`, `Tail_AltArrow`.
- `PetBear_FeatureHorns`: section 9.
- `MockOnly_HornSizeLineup` and `MockOnly_Stage`: a viewport line-up, camera and lights. Not for export.

The file opens in outfit A (hat, shirt, beads, helix). Alternates and horns are hidden the same way the existing `_Alt` meshes are.

**Honest limits.** These are grey-box shapes. The shirt is the body mesh pushed out, so its silhouette is right but its topology is not final. The helix ring is placed from the ear's outline and reads as a ring through the rim; a real one needs the ear modelled with a rim. The Bear's two ears differ by about 0.02 in the source, so HelixR and LobeR are not exact mirrors; I left them where the mesh is. The 3D head is low-poly, so surface anchors were placed by ray-cast onto the real mesh and will need re-deriving per pet.

**Files (to make it real).** `src/shared/BearRigDefinition.lua`, `PetRigDefinitions.lua` (anchor table per pet), `src/client/PetFactory.lua`, `PetFeatureGeometry.lua`, `GardenPetVisual.lua` (attach and hide rules), a new `src/shared/PetSlots.lua` (slot and exclusivity table), `scripts/build_bear_assets.py` (export), `PET-STYLE-GUIDE.md` (rig conventions section), `assets/garden-babies/IMPORT.md`.

**Effort.** Spec: done. Wiring anchors and the slot table into the rig and factory: M. Each real cosmetic afterwards: S to M of art plus S of data.

**Risks.**
- Every pet needs every anchor or a declared "none". Add a build check.
- Shells (shirts) only fit pets that share the Bear body, which the style guide already requires.
- Accessory count multiplies draw calls per pet in a shared garden. Cap visible accessories per visiting pet, or merge on spawn.

---

## 9. Horns

**Goal.** Simple, cute, low-poly devil horns in 5 growth stages for the Feature Egg's "Horn buds".

**Built** (board 03). In `pet-bear-attachments.blend`, collection `PetBear_FeatureHorns`: `PetBear__HornL_S1` to `S5` and `PetBear__HornR_S1` to `S5`, parented to `HornL` and `HornR`.

| Stage | Name | Height | Base radius | Tris each | Shape |
|---|---|---|---|---|---|
| 1 | Bud | 0.06 | 0.050 | 46 | Rounded nub |
| 2 | Nub | 0.10 | 0.057 | 46 | Short cone, slight lean out |
| 3 | Horn | 0.15 | 0.064 | 58 | Leans out, tip starts to turn in |
| 4 | Curl | 0.21 | 0.071 | 70 | Clear inward curl |
| 5 | Crown | 0.28 | 0.078 | 82 | Full devil curve, tips point up and in |

- Six sides, smooth shaded, base sunk 0.025 into the head. 164 tris for the largest pair.
- Material is `petBear__secondary`, so they take the pet's secondary colour.
- Each mesh has `role`, `channel = Head`, `feature = horns`, `stage`, `optional`, a UV map, and its origin on the anchor.
- Stage 5 tops out at about z = 1.63, below CharmFloat (1.70) but close. Stage 5 plus a centred charm is tight; the charm should lift 0.1 when horns are at stage 4 or 5.

**To ship them.** Review the shape with Spencer, then export per `ART-HANDOFF.md`, upload, and point `PetFeatureGeometry` at five meshes per side. Today it stacks sphere primitives in code and colours them ivory, not the pet's secondary. An earlier first-pass horn mock also sits in `assets/art-source/features/features.blend`; this set supersedes it only if Spencer prefers it. `FeatureCatalog` already has 5 stages; no economy or odds change.

**Files.** `src/client/PetFeatureGeometry.lua`, `src/shared/BearRigDefinition.lua` (HornL/R anchors), `assets/art-source/features/`, `scripts/build_bear_assets.py`.

**Effort.** Art: done as a first pass. Review tweaks S. Export, upload and wiring M.

**Risks.** Ten mesh uploads (5 per side) against the monthly quota; mirroring one side in code would halve that but breaks the "separate L and R meshes" rule. Horns sit 0.02 from the inner ear edge at stage 5; check ear-flick animation for clipping.

---

## 10. The rest, effort, risk and build order

### Summary

| # | Item | Effort | Risk | Needs Spencer first |
|---|---|---|---|---|
| 1 | UI system and screen pass | L | Medium (specs, text sizes) | Approve board 04 |
| 2 | Pocket Deck Slim | L | Medium to high (layout re-solve) | Approve board 05; back-arrow reading |
| 3 | Faceplates | M + M | Low to medium | Plate list, prices, which are earned |
| 4 | Boot sequence | M | Low | Approve board 07 |
| 5 | Quest rotation and log | L | Medium to high (save schema, economy) | Six quest decisions |
| 6 | Difficulty | L | High (balance, 3 goals, economy) | Six difficulty decisions |
| 7 | In-deck results and back arrow | M to L | Medium (most-tested screen) | Leave vs Hatch eggs removal |
| 8 | Attachment anchors in the rig | M | Low | Approve the anchor list |
| 9 | Horns | S + M | Low | Approve the shape |

### Recommended build order

1. **UI tokens and components** (section 1, first half). Everything else is built from them.
2. **Glass layout** (section 2, layout only, old skin). HUD moves into the glass. This is the riskiest layout change, so it goes early and alone.
3. **In-deck results and back arrow** (section 7). Small, visible, and it retires the floating recap.
4. **Slim skin and the 8 existing faceplates** (sections 2 and 3). Pure visuals on the new layout. Stickers retire here.
5. **Boot** (section 4). Self-contained.
6. **Horns** and **anchors in the rig** (sections 9 and 8). Independent of the deck work; can run in parallel with steps 1 to 5 on the art side.
7. **Screen pass** (section 1, second half): shop, journal, companions, style.
8. **Quests** (section 5), after Spencer's decisions. Schema must land before the launch save wipe.
9. **Difficulty** (section 6), last: it needs the start screen from step 2, the quest facts from step 8 and a balance pass.
10. **New plates and the held 3D deck model**, once plate prices and the deck shape are approved.

Steps 1 to 5 are about 6 to 7 working days. Steps 8 and 9 are about 6 more and should not start until the decisions below are made.

### Cross-cutting risks

- **Launch timing.** Quests and difficulty add save fields and change Star income. Both are far cheaper before the `EggDropLaunchV1` wipe than after.
- **Spec debt.** 33 of 196 specs were failing or stale in last night's sweep. Each step here should fix the specs it touches and not add to that number.
- **Uploads.** New sounds (3), finish textures (2), an icon sheet (1), horn meshes (10) and a deck mesh (1) all go through moderation and the monthly quota. Batch them.
- **Not verifiable in Studio:** phone thumb reach for the back arrow, shot-clock feel under real latency, the look of Glass and Metal materials at garden distance on low graphics.

### All decisions for Spencer, in one place

**Economy**
1. Difficulty multipliers: 1 / 1.5 / 2, or 0.75 / 1 / 1.5 (Medium unchanged from today)?
2. Do multipliers stack with the 2× Stars pass and Supporter?
3. Does the multiplier cover the +2 tidy-stack bonus?
4. Consolation Star for a loss, on Hard or at all?
5. Daily quest total: hold at 10 Stars or allow up to 13?
6. Weekly rewards: Stars, a faceplate, or both?
7. Rerolls beyond the one free one: none, a Star price, or a Supporter perk?
8. Does 2× Stars double quest claims?
9. Faceplates for Stars: direct prices (I suggest 40 to 80), and which three?
10. Streak reward.

**Design**
11. Back arrow: top right of the whole view (my reading) or inside the glass?
12. Remove "Hatch eggs" from results in favour of Replay and Leave only?
13. Hard: three goals plus a shot clock, or a lighter Hard?
14. Is Hard open from the start?
15. Claim quest rewards by hand, or keep auto-credit?
16. Drop the Star, Glitch, Seed and Wick stickers outright?
17. Pocket Deck Slim shape and the new pixel wordmark: approve, or iterate?
18. Horn shape and the five sizes: approve, or iterate?
19. Anchor list: anything missing (I left out pants on purpose)?

## Decisions (Spencer + Claude, 2026-11-12)
Spencer approved the deck shape, the pixel wordmark, the horn shape and the attachment list, and asked Claude to set the balance numbers.

- **Back arrow:** a UI back arrow in the top-right of the whole view (not inside the deck glass).
- **Wider screen:** yes. The deck screen goes wide, in a Tetris-like layout. The board sits in the middle, with side panels inside the screen for the current quests/goals, the ball/egg count, next egg, score, chain and difficulty.
- **Difficulty:**
  - Easy ×0.8, Medium ×1 (today's round, unchanged), Hard ×1.5 Stars.
  - Multipliers stack multiplicatively with the 2× Stars pass and Supporter, applied to the round's base payout.
  - Harder modes always pay more, so it's never optimal to grind Easy.
- **Hard mode:** three goals, a lower overflow line and a slightly faster spawn mix. No shot clock, because a timer adds stress for younger players.
- **Quests:**
  - Daily: 3 quests worth 12 Stars in total, plus 1 free reroll per day.
  - Weekly: 3 quests worth 30 Stars in total, plus a small bonus for clearing all three.
  - A quest log shows today's and this week's quests, with progress and history.
  - Quests rotate from a pool, so the dailies are no longer identical every day.
- **Faceplates replace stickers:**
  - Drop the Star, Glitch, Seed and Wick stickers.
  - Faceplates use non-pixel Y2K/Frutiger Aero designs: glossy gradients, bubbles, chrome, translucent plastic, aurora/water overlays, lens-flare-style shapes.
  - Sold at fixed Star prices: 20 / 40 / 80 for common / rare / showcase.
  - The 8 existing deck styles become the starter faceplates.
- **No random faceplates:** faceplates are bought directly, never from an egg (see the next point).
- **Paid random items:** Stars can be bought with Robux, so anything random bought with Stars is a paid random item. Roblox requires the odds to be shown, some countries restrict loot boxes, and too many of them make the game feel gacha-like. A few eggs are fine; cosmetics people want specific copies of (faceplates) are fixed-price.
- **Attachments:** approved. One helix piercing on each ear, made bigger. Documented in PET-STYLE-GUIDE.md ("Character creation").
