# Pocket Deck feel brief (beta 41)

Fable, 2026-11-27. Answers Spencer's beta 40 notes 9-17 (`FEEDBACK.md` B). For the Opus implementer. Presentation only: no sim, score, payout or server rule changes except where section 6 says so. Every item has a Reduced Motion (RM) line; "RM" means `Kit.reduced()` / Motion: Low.

What exists today (read before building):
- Open: `DeckTransition` shade in (.26) -> handheld rises from below, Back Out (.46) -> boot sheet 1.67 s, unskippable -> lit fade (.22). About 2.6 s, and the same every time.
- First open: `src/first/LoadingScreen` fades itself out over .45 onto the garden, then RoomView runs the "initial" route (shade fades in again). Sky -> garden glimpse -> shell colour -> deck: that is the pop.
- Hardware: `Screen:flash(id)` (DeckScreen 705) is a 100 ms sprite swap, called from `handleControl` for keyboard/gamepad only. Touching the drawn buttons presses them. Dragging or releasing on the playfield (init.client ~3061, `dropEgg`) shows nothing.
- The well pattern is static at 6% (`DeckBackdrop.board`).
- Difficulty: full-LCD `DifficultyPicker`, plus the stepper under Replay on results. Server freezes heat at the first drop.
- Results: `RecapFeedback` clock (goals .15, rows .30, count .6 to 1.5), `CelebrationKit` rays/confetti. Cues: `star_land`, `count_blip`, `bank`, `stars_total`, `win`, `lose`, `meter_fill`.

## 1. Open transition

Every open, target 1.25 s to playable (was ~2.6):
1. 0-.20: shade in (Quad Out). Unchanged.
2. .20-.58: handheld arrives from 0.42 body heights below, **scale .92 -> 1** (UIScale on the device root) with a 4 px overshoot, Back Out (.38). Screen dark.
3. .58-.70: a 2 px cyan scanline (118,246,176) opens from the LCD centre to full height (Quad Out); `deck_boot` at .58, volume .4.
4. .70-1.05: wordmark frame (boot frame 21) held .2, then the LCD content fades in (.15) while the panels stagger up 6 px, 30 ms apart, left column then well then right column (Quad Out .14 each).
5. 1.05-1.25: the held ball drops into the cradle from 10 px above with one squash (1.12 x .88, .12 s). Input is live from 1.05.

The full 1.67 s boot sheet plays only on the first open of a session. Any press from .15 s skips to step 4.

First open after loading (one handoff): the loading screen does not fade to the garden. Keep its sky up until `boardContentReady`, then cross-fade the sky colour to `Transition.shadeColor()` over .30 (Sine InOut) while its pals and title fade (.20), and hand straight to step 2. The garden is never shown in between; no frame is fully transparent. Needs a ready signal between ReplicatedFirst and RoomView (attribute on PlayerGui).

RM: shade cross-fade .2, deck appears at rest, still logo .4 s (today's `stillBoot`).

## 2. Buttons mirror every input

Replace `flash` with `Screen:hold(id, down)` (flash becomes hold + release after .10).
- A: down in 60 ms (sprite swap as today, letter drops 7% of diameter, plus PressScale .94); up on a spring (4.5 Hz, damping .32, as `Kit.Press`). Touch release-to-drop, tap on the well, Space, ButtonA all call it. Minimum visible hold 90 ms.
- D-pad: `dpadPress` wedge shown **for as long as aim is moving that way**, not 100 ms. Touch drag: direction from pointer delta, on above 3 px/frame, off after 120 ms still. Keys/stick: down while held (`heldAim`), stick past .25.
- Haptics: A 18 ms light tick on touch (existing `Haptics`); none for the d-pad.

RM: sprite swaps stay, no scale or spring.

## 3. Body press

New `DeckPressLean` composed into the same writer as `DeckMergeJolt` (one position write per frame; `Jolt:appliedOffset` must include it so touch aim never shifts). No GUI Rotation: it breaks `ClipsDescendants` and blurs the pixel art. Fake the tilt:
- Body offset (x, y in px): A **+2, +3**; B +2, +2; d-pad Left **-2, +2**; d-pad Right +1, +2; Up 0, +1; Down 0, +2.
- A soft shade on the pressed half (right for A/B, left for the d-pad): a horizontal gradient, black at 8% opacity at the pressed edge to 0% at the body centre, fading in with the press.
- LCD counter-moves 1 px the other way (parallax: the screen sits deeper than the keys).
- Down 70 ms Quad Out; back on a spring 5 Hz, damping .45 (one small overshoot under 1 px). Caps: 3 px total, never stacks; a merge jolt wins while it runs. Phones (`g.compact`): scale offsets by .6.

RM: none of it. Motion: Low: shade only.

## 4. Playfield life

Calm, 15 Hz steps (`Backdrop.Step`), no Instances made after build, at most 4 live tweens.
- Idle: well pattern drifts down 1 cell per 16 s. Held ball breathes 1 px at 2.4 s and blinks every 4-6 s (2 frames). Aim dots march downward, one dot spacing per .6 s. FILL LINE dashes march left 8 px/s; the line label fades to 40% after the first drop. LEFT/RIGHT labels fade out after the first drop.
- Drop: a 2 px dust puff, 3 pixels, at the landing point (.18 s). Lane the ball fell through lightens 4% for .25 s.
- Merge: existing jolt, plus the well border flashes the merged tier's light (.2 s out) and the pattern jumps one step.
- Chain x3 and up: the well's top edge glows gold (255,211,92) at 30%, decaying over 1.2 s.
- Near the fill line: line colour eases to (255,120,96), dashes march 2x. No flashing faster than 2 Hz.

RM: all loops off; border flash and lane tint stay.

## 5. Fresh reopen

Old balls must never draw. On close, at the end of Sink (under the opaque shade), clear the ball view and hide the well's ball layer. On open the layer stays hidden until the server's new-round serial has replicated (extend `boardContentReady`), then:
- New round: empty well, the section 1 step 5 ball drop is the first thing that moves.
- Resumed unfinished round: balls fade in by row, bottom up, 40 ms per row (max .3 s), no physics pop.

## 6. Difficulty on reopen

No extra screen. The existing right-column Difficulty card becomes the control while the round is untouched (balls 24/24, heat not frozen):
- It draws as a pressable (4 px lip, `Kit.button` ledge) with small arrows: `◀ Easy ▶`, the bars and `★ ×0.8` pill updating, and Win Pays rolling to the new range (.2 s count).
- Touch: tap cycles Easy -> Medium -> Hard -> Easy. Keyboard/gamepad: Up/Down (unused in a round); hint row shows "▲▼ Level" until the first drop.
- On arrival it pops once (scale 1 -> 1.08 -> 1, .28 s) at 1.2 s, never again that round. Defaults to the last played level; a quick replay is still one press.
- At the first drop it settles into today's plain card (lip sinks .12 s, arrows fade). `DifficultyPicker` full screen stays for the first ever round and "Up on Replay".
- Each level tints: Easy (95,227,154), Medium (255,211,92), Hard (255,120,96). No "recommended" badges, no nudging upward here.

## 7. Panel polish

- Card radius 14 -> **18** (compact 12); LCD radius stays. Gap between cards 12 (compact 8).
- Tag pills: inset **14 px left, 12 px top** (today ~8/6, which is why they crowd the corner). Height 24, horizontal padding 10, radius 8, 2 px darker lip under the pill, text optically centred. BALLS LEFT and Easy get the same pill treatment (today they are bare text, so the column reads uneven).
- Content starts 12 px under the pill; 14 px side padding everywhere.
- Each card: 1 px top highlight, white at 14%; 1 px inner stroke, black at 18%.
- Well: radius 12, a 3 px inner shadow at top.
- Motion on change only: score punches 1.14 (.16 s), balls-left bar eases (.25) and the number ticks down with a 2 px drop, chain dots pop 1.3 in turn (40 ms apart), a completed goal's ring fills clockwise (.3 s) with `goal_tick`. Next balls bob 1 px, offset half a beat. Nothing loops on text.

## 8. Results

Sequence (skippable by A at any time, lands on the final state):
| t | Beat | Sound (existing cue) |
|---|---|---|
| 0 | Well dims 40%, headline banner slams in from 1.6 scale, rotation -4 to 0, .22 Back Out | `tag_slam` .5 (win) / `streak_whoosh` .35 (so close, loss) |
| .15 | Goals stamp one by one, .09 apart: check stamp 1.4 -> 1, 3 degree wobble | `goal_tick`, pitch +.06 per goal |
| .30 | Payout rows flip in, .12 apart | `row_flip` .3 |
| .60 | Star lands with squash, rays open (.3) | `star_land` |
| .6-1.5 | Count-up; the star pulses 1.04 per 5 counted; mini stars fly from each payout row into the star | `count_blip`, pitch rising 1.0 to 1.5 across the count |
| 1.5 | Total punches 1.25, 12-piece star burst (gold 255,211,92 and white), wallet capsule ticks up | `bank` + `stars_total` |
| 1.7 | New best only: ribbon stamp over Score | `new_best` |
| 1.9 | Buttons rise 8 px, Replay focused | none |

- Win: `win` at 0, confetti 1.5-2.7, 3 px body bounce at 1.5 (section 3 path).
- So close: gold star, rays at half opacity, no confetti, burst of 6. Warm line names what was reached ("1 goal to go"), never what was lost.
- Loss: silver star, no rays, `lose` at .45 volume replaced by `reveal_hush` + `meter_fill` (the current sting reads sad); "Good effort" row still counts up with blips.
- No countdowns, no "almost!" meters, no purchase prompt in the sequence, Hatch stays a plain button. Replay is never delayed past 1.9 s.

Sound sourcing: no AI audio. Reuse the cues above (several are in `placeholderIds`; keep them as stand-ins). Acceptable new stand-ins: Roblox Creator Store licensed SFX, or chiptune made by hand in a tracker / sfxr-type synth. Wanted later: a 3-note rising win jingle and a soft 2-note "nice try".

RM: no slam, burst, confetti or bounce; rows and count appear at once with `stars_total` (as today).

## Priority

Must for beta 41:
1. Fresh reopen (5): `RoomView.lua`, `init.client.lua` (board view clear), `DeckTransition.lua`.
2. Button mirroring (2): `DeckScreen.lua`, `init.client.lua`.
3. First-open handoff + shorter open (1): `src/first/LoadingScreen.client.lua`, `DeckTransition.lua`, `DeckBoot.lua`, `RoomView.lua`.
4. Panel polish (7): `DeckKit.lua` (card/eyebrow), `DeckScreen.lua`, `DeckLayout.lua`.
5. Body press (3): new `DeckPressLean.lua`, `DeckMergeJolt.lua`, `DeckScreen.lua`.
6. Results sequence (8): `RecapFeedback.lua`, `DeckResultsInPlace.lua`, `DeckResults.lua`, `CelebrationKit.lua`, `BoardAudio.lua`.

Nice later:
7. Difficulty card stepper (6): `DeckScreen.lua`, `init.client.lua`, `DifficultyPicker.lua`, `UICopy.lua` (new hint strings -> localization sync).
8. Playfield life (4): `DeckBackdrop.lua`, `FieldEffects`, `DeckScreen.lua`.
9. Hand-made win / nice-try jingles: `BoardAudio.lua`.

Each slice gets a row in `V3-TEST-PASS.md` and a switch.
