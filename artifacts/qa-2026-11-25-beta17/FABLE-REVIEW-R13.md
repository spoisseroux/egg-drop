# Fable review: Studio check R13, before beta (18) (2026-11-25)

Reviewed: the 19 captures in `studio/r13/`, against `STUDIO-CHECK-R13.md`, `CAPSULE-AND-HUD-LOOK.md` and
`WORLD-ALIVE-LOOK.md`. I also read `src/shared/RiverStones.lua` and `src/server/StoneBuilder.lua` to turn the stones
finding into numbers. Nothing was run; every number below is a first value to capture and adjust, not a measured one.
Most captures are single frames at one time of day on a very wide Studio viewport (about 2.47:1), so framing calls
need the 16:9 and 19.5:9 captures still owed.

## Verdicts for beta (18)

| Feature | Verdict | Why |
|---|---|---|
| Capsule shot (Shots A and B) | **Ship with fixes** (its switch on) | Timeline and hand-off are right. Shot B is loose: the cup is small and sits on the loud runner; a flat egg sprite covers the dial in Shot A; the egg ticket stays up over the reveal. |
| Pocket version | **Ship** | Reveal reads as before. The well drop itself is still unseen. |
| HUD chips (Play date, egg ticket) | **Ship with one fix** | Names and priority are right. The ticket must hide over full screens. |
| Peek and the "?" card | **Ship** | Card is clean. E opening pet focus behind it is Opus's finding 3. |
| Flat bubbles | **Ship** | The hand bubble reads as a flat sticker. |
| Reveal shadow | **Ship with fix** | One shadow per item; the Bone has two. |
| Egg-well glow | **Ship** | Centred. Second window size still owed. |
| River stones | **Hold, unless fix 1 lands** | What is on screen is two grey slabs about 10 studs across, not stones. With fix 1 (or the fallback: rows and company only) it ships. |
| Dash fete set | **Ship on the beta, look unreviewed** | No capture shows the gate or finish. 10a only proves no flag enters the race camera. |
| The Hollow | **Hold behind its switch** | Agreed: the cliff path runs over its south rim; it is being re-laid. |
| Den board, Den, race camera | **Ship** | |

## Per capture

| Capture | Reads well | Doesn't |
|---|---|---|
| **02a** Shot A, mid-tuck | The machine is whole, with air above the globe; the garden behind it is calm. | A **flat cream egg with an ink outline** stands in front of the body and hides the flower dial, the one thing Shot A exists to show. The machine is only about half the frame height and dead centre (spec: dial left of centre). The egg ticket and a yellow burst (bottom right) are still drawn. Mid-tuck, so the last two may be fading: confirm on a frame at .30 s. |
| **02b** Shot B, held | Dial upper left, cup below it, matte marble: the right idea. Nothing blocks the view. | The **cup is about 9% of the frame width** and sits on the zigzag runner, which is the loudest thing in frame; wicker on zigzag is busy. The leaf chute is one small leaf and does not read as a chute. The bottom 40% is empty paving. The globe is out of frame (spec: its lower third shows). The game stand's cyan screen (upper right) pulls the eye. |
| **02c** reveal rising | The egg is centred and the burst is strong. | The egg ticket is drawn over the reveal. |
| **02d** Bear reveal after refocus | The best frame of the set: Bear, name plate, one shadow, one gold ring. No ticket. | Nothing. |
| **02e** pocket reveal | Same reveal, correct. | Egg ticket on screen; chat lines over the top left (test only). |
| **02x** frozen before the fix | Evidence only. | |
| **03a** "Napping egg" card | Clear title, one green button, cursor free. | Seven bullet lines is a lot for a card about a nap; trim to four in a later copy pass. Not tonight. |
| **04a** Play date chip | `Play date 0/3 · +4 ★` reads and nothing overlaps bottom right. | Nothing. |
| **04b** flat hand bubble | Flat cream disc, ink line, no gloss: a sign, as asked. | Nothing at this size. A noon close-up from two angles is still owed. |
| **05a** Wobble Top | One soft shadow at the tip. | Nothing. |
| **05b** toy receipt | Layout holds. | `Squeaky...` is cut off while the odds panel is half empty. |
| **05c** Bone | The bone itself is clean. | **Two shadows**: a small dark ellipse just under the bone and a wide soft one lower. It reads as two light sources. `Pocket...` is cut off. Egg ticket on screen. |
| **05d** egg well | Glow, egg and shadow share one centre. | Nothing. |
| **06a** stones from the bank | The Middle stone (domed, mossy) is a believable boulder. The small company stone is right. | A **grey slab fills the stream kerb to kerb for about 10 studs** and spills past both kerbs onto the grass. Water shows only as two V shapes, upstream and downstream, in the middle. East and West stones cannot be told from the slab. Light, flat grey Slate reads as dry concrete. Moss is three faint smudges. No flow rings visible. Small dark diamonds poke through the kerb on both sides. |
| **06b** stones, low | Same boulder reads well. | Same slab. From this height it is a dam. The far crossing by the falls is still three pale flat tiles (the old look). |
| **07a** the Hollow | Fallen log, stump circle, rim boulders and the bench are right and belong to the place. | The cliff path's treads cross the wall above as a row of slate-blue boxes seen from underneath. The sandbox is pressed into the rock. The toe patches are barely visible, so there is no paw. The play pieces and the ball pad are still saturated plastic (known, meshes later). |
| **08a** Things to do | Five rows, one style, clear buttons. | Nothing. |
| **10a** race camera | Course is readable; no flag in frame. | Shows no part of the fete set, so it is not a look review. |
| **10b** Den after the race | Warm and enclosed; the camera is back. | Brown on brown: the gate and its prompt do not separate from the wall. Later, not tonight. |

## Ranked fixes (code, parts and numbers only)

### 1. River stones: the slab is the two Landings carved far too big (blocker for the stones)

**What I think is happening** `[check]`: the two shapes are centred on the two banks (x 9.2 and x -.2) and meet in mid
stream, which is exactly the two `Stones.Landings`. Each uses `ball = 12` (a 28.8-stud ball, top 4.33), and a ball that
flat stays above the water (3.2) out to about 5.7 studs. So the cutting blocks are not trimming it to 2.4 x 1.6.
Likely `GeometryService:IntersectAsync(ball, blocks)` keeps the ball where it meets **any** block, not **every** block.
One probe settles it: read the carved `LandingEast` part's `Size`. Expected about 2.5 x .2 x 1.7; if it is near 10
across, that is the cause. The wet bands (`ball = 16`) have the same exposure.

Fix, in order of preference:

- **Carve by cutting away, not by intersecting:** put each block on the **outside** of its face and use `SubtractAsync`,
  or intersect one block at a time. `Stones.Block` must then be larger than the largest ball (set it to 60).
- **Fallback for tonight if the carve cannot be fixed:** build `Rows` and `Company` only. Skip `Landings` and the bands.
  Three boulders in open water already beat the slab.

Acceptance, from 06a's spot: blue water between every pair of stones and between each end stone and its kerb, at least
.35 studs; no grey on the grass.

### 2. River stones: make them wet stones in moving water (after fix 1)

| Thing | Now | Change to |
|---|---|---|
| Row colours (East, Middle, West) | `#8A8580`, `#7F847F`, `#948E84` | `#6F6C68`, `#646A66`, `#77726A` (wet stone is darker and cooler; the light grey is what reads as concrete) |
| Wet band | scale 1.12, top 3.25, darker .35 | **scale 1.04, top 3.45, darker .45**. At 1.12 the bands touch (stones are 3 apart). At 1.04 and .25 high it is a dark collar at the waterline, not a plinth. |
| Moss | share .7, `#5F7F4A`, transparency .45 | share .55, `#56793F`, **transparency .25**, offset .2 studs to the upstream side (+Z) |
| Landings | `#9A958C`, `#968F86`, ball 12 | Keep 2.4 x 1.6 and the colours; **ball 6**, so even a failed cut cannot spread |
| Company stones | 3 | Add 2 by the West stone: (0.9, 12.0) .9 x .7, top 3.45, `#7C807B`; (2.6, 7.9) .6 x .5, top 3.38, `#878580`. Darken the first three by the same 20%. |
| Flow ring | not visible in either capture | One per row stone at y 3.22: 1.15 to 1.5 x the footprint over 2.6 s, colour `#EAF6F8`, decal transparency .45 to .85. `[check]` it is on at `AliveBudget` 0. |
| Wake (new) | none | One plate per row stone, 1.2 wide x 2.6 long, centred 1.5 studs **downstream** (-Z) at y 3.22, the same `Ripple` texture, `#EAF6F8`, transparency .6 to .85 on a 1.8 s pulse. A ring says "something is in the water"; a wake says "the water is moving". |
| Kerb diamonds | small dark tips through the kerb at both landings | Should vanish with fix 1; if not, sink that part .1. |

Then the far crossing by the falls gets the same builder (three rows, no landings), so the garden has one kind of stone.

### 3. Capsule Shot B framing

Targets on 16:9: the cup at least **14% of the frame width**, its centre near **62% across, 66% down**; the whole dial
inside the upper left third; paving below the cup no more than a quarter of the frame.

- Camera: **4.4 in front, 2.3 right, 1.8 up** (was 5.5 / 2.0 / 2.4). Look at **1.0 right, 0.9 up** (was 0.6 right, 1.0 up).
  Lower and closer cuts the paving and turns the runner edge-on.
- If the cup is still under 14%: ease `FieldOfView` to **58** over the A to B move and restore it with the camera.
  One number, and it is the one exception to "field of view stays the player's".
- The cup rim pulse in the beat (`cup_shine`) is what separates the cup from the runner: make sure it is the egg's
  colour at full strength for the .3 s, not a tint.
- The egg in the cup: at least .8 of the cup's inner width, and it does not start fading until the panel has covered
  half of it.

### 4. Capsule Shot A

- **Find the flat cream egg in front of the machine** (02a) and hide it from the tuck to the camera's return. It is a
  2D object with an ink outline, so it is a billboard or a screen element, not the machine. The dial must be visible
  for the whole turn.
- Camera: **8.0 in front, 1.8 right, 4.0 up**; look at **0.4 left, 3.4 up** (was 10 / 1.5 / 4.2, look at centre 2.6 up).
  The machine goes from about 50% to about 62% of the frame height and the dial moves left of centre.
- Confirm the ticket, dock and every chip are at zero by .18 s.

### 5. The egg ticket over full screens

`Egg 8 h` is drawn over the reveal in 02c, 02e, 05b and 05c (not in 02d). The rail hides for the hatch reveal, the
result card and the capsule shot, always. One rule, one place.

### 6. One shadow per revealed item (05c)

Keep the wide soft ground ellipse; drop the small dark one whenever the item's lowest point is clear of the ground
line (floating items: Bone, Ball). Ground shadow: 55% of the item's drawn width, transparency .65. An item standing on
its point (Wobble Top) keeps the small one only, as in 05a.

### 7. Odds chips (05b, 05c)

Two chips per row instead of three, so `Squeaky Toy` and `Pocket Deck` fit; the panel has the room.

### 8. For the Hollow's re-lay (not tonight)

- Shift the whole fan 2.5 studs toward P so the sandbox and swing clear the rock (H3).
- Toe patches: decal transparency **.30 to .15**; palm **.45 to .30**. At today's values there is no paw to find.
- The treads seen from below: give the path a bank or skirt in the cliff's own rock colour under each tread, so from
  the Hollow it reads as a ledge, not as boxes.

## Still owed to me

Shots A and B after the reframing, noon and dusk, 16:9 and a 19.5:9 phone; the pocket well drop; the stones top-down and
from 06a's spot after fix 1; **the Dash start gate from the dais (96, 66), from the pad, and the finish from 20 studs
up the course**; a bubble close-up at noon from two angles.
