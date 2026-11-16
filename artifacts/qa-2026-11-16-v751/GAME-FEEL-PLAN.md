# G1 game-feel pass: faster, more exciting egg drop

Spencer, 2026-11-16 (v751): "we need to do a pass to make the egg drop game more fast and exciting".

Status: compiled and run in Studio Play on 2026-11-16 (see "Play verification" at the end), place saved v760, not published. The paragraph below is the state before that run.

Status: implemented and pushed on `feat/egg-drop-arcade-polish`. **Not compiled or run in Studio** (Studio was in Play for another agent the whole session, so the Edit compile check could not run). Not published. All numbers are `[PLACEHOLDER]` until the Play tests at the bottom pass and Spencer plays it on a phone.

## What the player should feel

- **Drop, drop, drop.** The next ball is ready almost as soon as you let go. No waiting for the last one to land.
- **Every merge hits.** A flash, a burst, a kick and a squash, all bigger for a bigger ball.
- **Chains climb.** Each chain step is one note higher, a little louder, with a bigger counter.
- **The line is alive.** Near the fill line you feel a heartbeat that speeds up; over it you hear it.

## The one pacing decision: speed the clock, keep the game

The round now runs **1.3 simulation seconds per real second** (`BoardConfig.Pace`). The server steps the same 1/120 s fixed step more often. Nothing inside the simulation changes: gravity, launch speed, bounce, merge kick, the aim preview dots, the chain window, the overflow grace and the goals are the same numbers in simulation time. A given set of drops gives the same board as before, played 1.3x faster.

Why this and not higher gravity: raising gravity alone changes bounce heights, how far a merge throws its neighbours and where the preview dots land, so every benchmark and every taught shot would need re-tuning. A clock change keeps the round exactly as fair as v751.

## Numbers, before and after

### Pacing (server rules)

| What | Before | After | Where |
|---|---|---|---|
| Round clock | 1.0x | **1.3x** | `BoardConfig.Pace`, `init.server` step loop |
| Fall time, launch to an empty floor | 0.93 s | **0.71 s** | from Pace |
| Fall time, launch to a mid pile (y = 6) | 0.71 s | **0.55 s** | from Pace |
| Fastest fall speed on screen | 38 units/s | 49 units/s (board is 19 tall) | from Pace |
| Drop cooldown (server minimum between drops) | 0.35 s | **0.2 s** | `BoardConfig.DropInterval` |
| "Next ball ready" gate: last ball has touched something, or this long has passed | 1.8 sim s (1.8 s) | **0.6 sim s (0.46 s)** | `BoardConfig.ContactGateSeconds` |
| Practical time between drops | 0.6 to 0.9 s | **about 0.46 s** | gate + fall time |
| Settle wait after the last ball | 4 s | **3 sim s = 2.3 s** | `FieldRun.SettleSeconds`, `BoardHints` |
| Settling chip ticks | 4 ticks at 0/1/2/3 s | 3 ticks at 0/0.75/1.5 s | `BoardHints.TickTimes` |
| Chain window | 1.25 s | 1.25 sim s = 0.96 s | unchanged in sim time |
| Overflow grace, Easy / Medium / Hard | 3.0 / 2.4 / 2.0 s | 2.3 / 1.85 / 1.54 s real (same sim time) | unchanged in sim time |
| Gravity, launch speed, bounce, merge kick | 32 / 10 / 0.64 / per goal | unchanged | not touched |
| Round length, 24 drops, steady play | about 45 to 60 s | **about 30 to 40 s** | estimate, to measure in Play |

The published `OverflowGraceLeft` is converted to real seconds, so the draining fill line still empties exactly when the round ends. The Welcome round's idle timers stay in real seconds.

**Fairness notes**
- The grace is shorter in real seconds, and so is everything the pile does during it. A stack that used to save itself still does.
- The earlier "ready" gate only adds a choice: you may drop while the last ball is still falling. Nothing forces it.
- Item timers that live in the simulation (Magnet pull seconds) are also 1.3x shorter in real time, with the same effect on the board.

### Merge feedback (client only)

| What | Before | After | Where |
|---|---|---|---|
| Merge blob (two balls flowing into one) | 0.32 s | **0.22 s**, lands 10% bigger | `JellyLCD.MergeDuration`, `MergePop` |
| Squash on the new ball | none | **squash wobble by tier** (impact 10 / 12 / 14 / 16 for II to V) | `init.client` merge handler |
| Ring lifetime | 0.28 s | 0.26 to 0.32 s by tier | `FieldEffects.mergeDuration` |
| Ring reach | +42% | +58% (II) to +82% (V), ease-out | `FieldEffects.ringReach` |
| Ring line | 1.5 px, starts 45% see-through | 2.5 to 4 px by tier, starts as a bright flash (8%) | `FieldEffects` |
| Fragments | 6, fly 0.9 radii, 12% of radius | 6, fly **1.5 to 2.1 radii** by tier, 16% of radius, every other one near-white | `FieldEffects.fragmentReach` |
| "+N" score pop | fixed size | lands from **1.45x** to 1x in 0.1 s | `FieldEffects.PunchScale`, `PunchTime` |

### Screen kick, scales with tier

| Merge | Before | After |
|---|---|---|
| II | 3 px, 0.11 s | **4 px**, 0.11 s |
| III | 5 px, 0.14 s | **7 px**, 0.14 s |
| IV | 7 px, 0.17 s | **10 px**, 0.17 s |
| V | 9 px, 0.19 s | **13 px**, 0.20 s |
| Max clear | 12 px, 0.22 s | **16 px**, 0.24 s |
| Chain boost | +12% once | **+12% per chain step**, up to +48% |
| Cap | 12 px | 16 px |
| Phone | same pixels | **scaled by board height / 420** (about 0.66 on a phone, never below 0.5) |

`DeckMergeJolt.Kick`. The key curve is the approved one. Reduced Motion still has no kick, and the aim under a still finger does not move.

### Chain counter and pitch

| What | Before | After | Where |
|---|---|---|---|
| Counter text size | 14 px, always | **20 px at x2, +2 px per step, 30 px from x7** | `FieldEffects.chainTextSize` |
| Counter entrance | none | lands from 1.45x in 0.1 s | `FieldEffects` |
| Counter lifetime | 0.30 s, fading from the start | **0.5 s**, solid for 0.2 s, then fades | `FieldEffects.CaptionHold` |
| Merge and chain pitch | 0 / +3 / +5 semitones, flat from chain 3 | **0, 2, 4, 5, 7, 9, 11, 12 semitones**: one major-scale note per step, an octave at chain 8 | `BoardAudio.ChainSemitones` |
| Chain accent volume | 0.30 | 0.30 at x2, +0.04 per step, 0.50 from x7 | `BoardAudio.chainAccentVolume` |
| Chain accent guard | one per 0.18 s | one per 0.09 s | `init.client` |

This replaces the earlier approved "zero, third, fourth" contour, because Spencer asked for rising pitch per chain step. Same uploaded cues (`merge_bubble`, `merge_jelly`, `merge_chain`), only pitched.

### Near-fill-line tension: a heartbeat

| State | Before | After |
|---|---|---|
| Near the line | solid amber line | amber line plus a **beating glow** (lub-dub), every 1.1 s at the edge of the warning band down to **0.6 s** just under the line. Silent. |
| Over the line | glow with a slow sine | glow beats every **0.42 s**, with a soft `danger_tick` on each beat; pitch climbs 1.0 to 1.35 as the grace drains |
| Last 0.35 s (red) | red line and haze | beat every **0.21 s**, tick louder (0.34) |
| Entry cue, cleared chime, draining line, chip | as is | unchanged; the first tick waits one full beat after the entry cue |
| Reduced Motion | no pulse | no pulse; ticks still play (sound has its own setting) |

`BoardDanger.beatPeriod`, `beat`, `tickVoice`. `danger_tick` is an existing uploaded cue that had no user until now. This replaces the earlier "no repeating blip" rule for the over state only.

## Not changed

- Scoring (`BoardConfig.mergeScore`), the 6 + 2 Star payout, heat multipliers, goals, the 24-drop budget and saves. No economy change was needed for pacing. A round is shorter, so Stars per minute go up by roughly the same 1.3x to 1.5x. That is intended here; flag it if the Star economy should stay flat per minute.
- The DeckScreen layout and fit code, the results screen and the hatch stages (another agent's lane).
- Between rounds: the settle wait is the only slow beat this pass owns, and it is now 2.3 s. The round-end presentation (0.45 to 0.65 s) and the results count-up belong to the results lane.
- No new strings, no new sounds, no new column-0 locals in `init.client.lua` (still 219).

## Specs updated on purpose

- `BoardAngle.spec`: contact gate at `ContactGateSeconds` (0.6).
- `JellyPalette.spec`: `DropInterval` 0.2, `Pace` 1.3.
- `DeckRoundQA.spec`: settle wait is 3 / Pace, three ticks.
- `DeckMergeJolt.spec`: new kick table, 16 px cap, per-step chain boost, phone scale.
- `FieldEffects.spec`: new test for the tier and chain scaling and the punch.
- `ArcadeAudio.spec`: major-scale chain contour up to an octave, accent volume.
- `BoardDanger.spec`: heartbeat rules, near beat, ticks only over the line and only when presented.

The `src/*/ZZSpecs` copies are not refreshed; copy the specs above before running them.

## What "broken" looks like

- A ball visibly skips or teleports while falling (replication cannot keep up with 49 units/s).
- The fill line still shows time left when the round ends, or ends early.
- A player spamming drops fills the board before they can read it, or the 32-ball cap is hit in normal play.
- The kick makes a phone player miss the aim rail or feel sick; a x5 chain makes the deck jump more than about 10 px on a phone.
- A chain of 6 or more sounds shrill, or the heartbeat tick gets annoying within one round.
- Win rate on Medium drops against v751.

## Play tests for the coordinator

Run after a Play restart (Rojo changes reach Play only then).

1. **Compile.** Server and client start with no errors in the output. This was not checked in Edit.
2. **Specs.** Server: BoardAngle, RoundItems, WelcomeSeed, OverflowGraceLeft, FieldObjectives. Client: JellyPalette, DeckRoundQA, DeckMergeJolt, FieldEffects, ArcadeAudio, BoardDanger, JellyLCD, FieldFeedbackOwner.
3. **Drop cadence, phone size.** Hold A / tap fast for 10 drops. Expect about two drops a second, the dispenser never stuck, balls falling smoothly. Record a clip.
4. **Merge ladder.** Make a II, III, IV and V merge. Each one kicks harder, bursts wider and the new ball squashes. Then check Reduced Motion: no kick, no fragments, no punch.
5. **Chain of 4 or more.** Counter grows x2, x3, x4; pitch steps up each time; nothing shrill.
6. **Fill line.** Build to just under the line: the glow beats, faster as you get closer, no sound. Go over: ticks start one beat after the entry cue, speed up in red, and the line reaches zero exactly as the round ends. Merge to clear: chime, "Safe".
7. **Round end.** Use the last ball: "Settling" shows about 2.3 s with three ticks, then results.
8. **Welcome round.** A fresh save: the idle demo and the first-drop hint still appear at their usual times, and the taught first merge still lands.
9. **Fairness check.** Run `scripts/FieldObjectiveBenchmark.lua` once; the simulation is unchanged, so win rates should match the stored results.
10. **Time a round.** Medium, steady play, launch to results. Target 30 to 40 s.

## Tuning levers if it is too much or too little

- Overall speed: `BoardConfig.Pace` (1.2 calmer, 1.4 arcade). Everything else follows.
- Drop spam: `ContactGateSeconds` (raise toward 0.9 to make players wait for the landing).
- Kick: `DeckMergeJolt.Kick` and `ChainStep`; phone size via the 420 px reference in `init.client`.
- Heartbeat: `BoardDanger.BeatNearSlow / BeatNearFast / BeatOver / BeatRed`, tick volume in `tickVoice`.
- Chain pitch: `BoardAudio.ChainSemitones`.

## Play verification (2026-11-16, Studio Play, 750x402 phone fixture)

No number was changed. One spec was re-pinned: `OverflowGraceLeft.spec` now expects the grace published as `graceLeft / Config.Pace`.

| Test | Result |
|---|---|
| Compile | Server and client start clean on two Play starts. |
| Specs | Server 58/58. Client 134 of 149; the 15 failures are the long-standing ones. |
| Ten fast drops | 10 drops in 4.25 s, one every 0.465 s. Dispenser never stuck. No position jump; longest gap between position updates 36 ms. |
| Merge ladder | Tier II to V merges in live rounds. Burst and score pop scale (ring up to 118 px, 18 fragments). |
| Reduced Motion | No fragments, no punch on the score pop or chain counter, no kick. |
| Chain | Live chains up to x9. Counter 20 px at x2, +2 px per step, lands from 1.45x. |
| Fill line | Near: glow beats every 0.95 s at pressure 0.3. Over: first beat 0.45 s after entry, then 0.43 s, 0.22 s in red. Overflow end: line at zero 0.03 s before the round ended (Easy and Medium). |
| Round end | Settling to results 2.33 s. |
| Welcome round | Skip ready at 3.1 s, replay at 8.1 s, demo at 25.1 s; the demo ball merged 0.67 s later. |
| Benchmark (`heats`, 6 seeds) | Easy 33/36 (was 33), Medium 35/36 (was 34), Hard 17/36 (was 16). `mediumMatchesToday` true. |
| Medium round | 33.0 s from first drop to results, one drop every 1.25 s, a win. Floor with drop spam: about 13.5 s. |

**Checked on the real modules, not in the live game** (Studio had no window focus, and the game mutes sound and the kick without it):
- Kick on the phone board (273 px tall, scale 0.65): II 2.0 px, III 4.1, IV 6.3, V 7.3, cap 9.5 px. Desktop: 3.2 / 6.3 / 9.5 / 12.6 px.
- `merge_chain` plays at 1.00, 1.12, 1.26, 1.33, 1.50, 1.68, 1.89, 2.00x for chain 1 to 8, volume 0.30 to 0.50. `danger_tick` 1.00 to 1.34x, 0.26 then 0.34.
- Nobody has listened to it. "Nothing shrill" is still open for Spencer.

**One rule change to know about.** The settle wait went from 4 to 3 simulation seconds, and the overflow grace did not change (3.0 / 2.4 / 2.0). A stack that goes over the line after the last ball now usually reaches the settle before the grace runs out on Easy and Medium, so the round ends on its goals with the line still partly lit (seen once: 0.39 s left). Before G1 that was an overflow loss. It is kinder, and it is why the benchmark gained one win on Medium and Hard. To restore the old rule, set `FieldRun.SettleSeconds` back to 4 (3.1 s real).

Captures: `verify/G1-fast-round-750x402-01..06-FIXTURE.png` and `verify/G1-fast-round-750x402-FIXTURE.gif` (six frames 0.75 s apart, chain x3 to x5).
