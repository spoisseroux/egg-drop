# Pocket Deck frame drops (v775, 2026-11-16)

Spencer: "sometimes the pocket deck lags / drops a few frames intermittently when playing" (phone).

## How it was measured

- Studio Play, place 96451847774961, a fresh save taken to its first field round (5 drops earn Pip, the hatch is acked over `HatchRequest`, back to Board).
- Scripted round: a fresh round (`restart`/`reset` with the RunSequence), then 30 drop attempts 0.9 s apart at `sin(i*1.7)*0.85` aims. Every round landed 15 drops and 9 to 13 merges in 29.3 s.
- Wall time: `os.clock()` between RenderStepped callbacks. A spike is a frame over 20 ms.
- Script time: a temporary probe (`src/client/ZZSpecs/DeckPerfProbe.lua`, git-excluded) timed sections of the render loop, `updateHud`, `addView`, the merge, impact and Drops handlers, RoomView's RenderStepped and `GardenCareClient:step`. "Script/frame" is the main-thread script ms per frame with nested sections counted once. The probe lines were stripped before the commit.
- Before = HEAD c02c977 plus the same probes. After = the fix plus the same probes. Same harness both times: 3 rounds at the Studio desktop size, 2 rounds with `EggDrop.Backdrop` forced to 812x354 (the phone deck layout).
- Studio is vsync-locked at 60 Hz on a desktop CPU, so wall time hides most headroom: a ">20 ms" frame there is one missed vsync. The script time is the number that grows on a phone CPU.

## Results

Wall time, all frames of the scripted rounds pooled:

| Layout | Build | Frames | Spikes > 20 ms | Worst | p99 | p50 |
|---|---|---|---|---|---|---|
| Desktop | before | 5262 | 27 | 22.6 ms | 19.31 ms | 16.67 ms |
| Desktop | after | 5268 | **7** | 22.0 ms | **18.73 ms** | 16.68 ms |
| Phone 812x354 | before | 3506 | 18 | 22.3 ms | 19.36 ms | 16.67 ms |
| Phone 812x354 | after | 3510 | **7** | 21.3 ms | **18.81 ms** | 16.67 ms |

Script time per frame (mean / p99 / worst over each round):

| Round | Before | After |
|---|---|---|
| Desktop 1 | 1.30 / 3.28 / 5.20 ms | 0.68 / 2.31 / 3.30 ms |
| Desktop 2 | 1.28 / 3.32 / 4.69 ms | 0.69 / 1.85 / 3.07 ms |
| Desktop 3 | 1.32 / 3.54 / 4.88 ms | 0.68 / 1.98 / 2.97 ms |
| Phone 1 | 1.33 / 3.46 / 5.54 ms | 0.71 / 2.08 / 3.87 ms |
| Phone 2 | 1.30 / 3.45 / 5.00 ms | 0.69 / 2.20 / 2.98 ms |

About half the script time per frame (-47%) and about 40% off the p99 and worst frames.

Section totals over one 29 s desktop round (before -> after):

| Section | Before | After |
|---|---|---|
| `GardenCareClient:step` (runs every frame, deck open or not) | 736.0 ms (0.42 ms/frame) | 47.3 ms (0.03 ms/frame) |
| LCD finish (span pre-count + paint) | 725.5 ms (0.41 ms/frame, max 2.32) | 436.4 ms (0.25 ms/frame, max 1.40) |
| of which span commit, per 30 Hz tick | 0.44 ms, max 1.55 | 0.31 ms, max 0.95 |
| of which pixel scans | 2 per tick, 326.8 ms | 1 per tick, 148.5 ms |
| `updateHud`, per call (about 3 per drop) | 1.84 ms, max 3.27 | 1.31 ms, max 2.33 |
| `addView`, per new ball | 0.34 ms | ~0 (no Instances) |
| render loop head (`r.pre`) | 66.0 ms | 47.5 ms |

## Causes found and fixed

1. **Two buttons restyled every frame, in every mode.** `GardenCareClient:step` wrote `pickup.Interactable` / `setDown.Interactable` (false while hidden), DeckArt's Interactable watcher ran a full `Art.control` restyle, then the step's own `Art.control(..., enabled=not pending)` set it back. 44 GUI properties changed 122 times a second (PickUp and CarrySetDown, their strokes, gradients and arrow pieces). `Art.control` now owns Interactable alone; the end-of-frame state is the same as before (enabled = not pending). Changes counted afterwards: 0 a second.
2. **LCD span paint reparented frames.** Every pooled span lived under a per-row host, so a ball moving down a row reparented its spans, and retired spans were reparented to a stash. Spans now sit on the LCD root at the same integer row edges (Position/Size writes only); the row hosts stay as geometry. Same pixels on screen.
3. **The LCD scanned each frame twice.** The span-budget pre-count (`demand`) and `paint` ran the same run scan. `Surface:scan` keeps its runs and `paint` commits them; a face-simplify replay rescans. The scan token is cleared on `beginFrame`, `replay` and `setBackground`.
4. **About 30 GUI Instances per dropped or merged ball for nothing.** Every ball built a fallback `JellySprite` (bands, gradients, glints) that is never painted while the LCD draws. With the LCD up the sprite is built on its first painted frame (the LCD failure or PixelLCD-off hand-over). Checked in Play: with `PixelLCD=false` the sprites build and show.
5. **`updateHud` redid hidden work.** It flipped 24 hidden meter cells visible and back, rewrote their layout and called `layoutDropMeter` (an AbsoluteSize read mid-refresh) on every refresh; wrote `rareGoal.Text` twice; and wrote a different string to the TextScaled `eggGoalText` that the render loop overwrote before paint (two re-fits per refresh). The meter now keeps its colours only (its own AbsoluteSize signal lays it out), `rareGoal` is written once, and the render loop alone owns `eggGoalText`.
6. **HUD refresh on danger telemetry.** The server republishes OverflowPressure and OverflowGraceLeft up to 10 times a second while the pile is near the line, and each queued a full `updateHud`. The HUD reads neither (the danger cues, faces and coach read them every frame), so they and the Welcome telemetry no longer queue it. Not exercised by these rounds (pressure stayed 0).
7. **Per-frame allocations in the render loop.** `Stars.format` built the egg-goal string every frame (now only when the egg, wallet or label changes), and `boardHints:step` got a new table every frame (now reused).

Looked at and left alone: the exterior pattern backdrop (0.04 ms/frame at 15 Hz), the Pocket menu tile art (stepped only while the hub is open), FieldEffects (already pooled), the merge and impact handlers (~0.3 ms per event), the finish overlay sheen (one write a frame, a deliberate animation), RoomView's pet and park step (the pet shows through the see-through deck), and server traffic (one `BoardMerge` per merge and batched impacts; `syncVisuals` still rebuilds its content signature every Heartbeat on the server, which doesn't affect client frames).

## Verification

- Deck specs in Play: JellyLCD 10, JellySprite 6, JellyUnderlay 3, JellyMarks 4, JellyMaterials 5, JellyPalette 3, JellyRendererBenchmark, GardenCareClient 13, GardenCareStartup 2, DeckBoot, DeckFit 4, DeckHeader 4, DeckMergeJolt 15, DeckQuests 7, DeckResults 18, DeckRoundQA 10, DeckScreen 8, DeckStyle 11, FieldEffects, FieldQuestText, BallSpanBudget 9, ThemeLCD 19, RoundEndPresentation 11, InPlaceResults 7: all pass. JellyOverflow (4) and FieldFeedbackOwner pass when run with their own (gui, board) arguments.
- Full client suite (161 ZZSpecs copies as (client, gui), UIClick with PlayerGui): 143 pass. The 18 failures are the 14 known (SemanticUI, Onboarding, SaveNoticeLayout, PreferredTextLayout, VividHandheld, StyleJournalActions, StyleJournalLayout, EmulatorSafeArea, CompactDeck, JellyOverflow, JellyRenderOwner, FieldFeedbackOwner, HardwareDeck, WelcomeCoaching) plus 4 that take other arguments (CoachMask, FirstSpendGuide, PersonalToyGardenTimeline, SaveNoticeOwnership). JellyRenderOwner still looks for the retired tier "Mark" labels.
- Console after a clean Play (first pet, 12-drop round, Room and back): only the pre-existing lines (EditableImage not accessible, Player:Move without a humanoid, asset 203785492 type mismatch).
- `init.client.lua` stays at 219 column-0 locals. Place saved (v816). Not published; translations not synced (no player-facing text changed).

## Not verified

- **A real phone.** All numbers are Studio on a desktop CPU; the phone-size rounds only force the 812x354 layout. A phone CPU should show the same order of savings at several times the ms, but that was not measured.
- **The EditableImage backend.** EditableImage is not accessible in this experience, so Studio draws the board with spans. If a phone gets the image backend, fixes 2 and 3 do not apply there; the rest still do.
- **The danger phase** (fix 6): no round reached the overflow line.
- Engine-side GUI layout and render time: the probe only sees Luau time, so the cost of the 122/s restyles and the reparents inside the engine is not counted.
