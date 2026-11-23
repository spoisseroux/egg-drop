# Fable review R3: QA round 2 in Studio (2026-11-23)

Reviewed: `STUDIO-CHECK-R3.md` and all 19 captures in `studio/r3/`, against `QA-R2-LOOK.md` and Spencer's round 2
words. Look only; code findings (KitSpring `setEnabled` gap, spec timing, float32) are Opus's.
Verdicts: **GO** ships as is, **FIX** has numbers, **LATER** does not block beta 14.

| # | Item | Verdict |
|---|---|---|
| 1 | Springs (button press, menu open) | **GO**, one FIX (round keys) |
| 2 | Crickets at night, birds silent | **GO** to the beta; Spencer's ears decide |
| 3 | Bird shape | **FIX** (below) |
| 4a | Butterflies | **GO** |
| 4b | Leaves and petals | **FIX** (sizes below) |
| 5 | "Coming up" strip | **GO** with 3 small FIXes |
| 6 | Ground flowers, day | **GO**; night LATER |
| - | Nest sign back face, Dash place pill | **GO** |

## 1. Springs: GO, one FIX

- 01 vs 02: the held Hatch button is plainly smaller and flat on its lip. At .95 with the 4 px widen it is a visible
  change on a 509 px button. 03 vs 04: the pocket menu mid-open is about 7% smaller and 18 px low; with the measured
  1.022 peak and 6 px past home it will read. Rings twice, as specified. GO.
- 05 quest log rising only is right (it has its own UIScale; rise alone is the allowed fallback).
- **FIX: the round Back and Help keys do not press.** They have no `Face`, so the .88 round-key row never reaches them.
  These are the keys a thumb hits most. Scale the `Disc` (with its glyph) under a `PressScale`: down **.88** in 60 ms,
  release **5 Hz, damping .32**, clamp **1.12**; `KeyLip` stays still. Hit rect unchanged.
- LATER (not seen here): the filmed 390 x 844 tap on Play and deck menu open, phone bottom sheet, close animation.
  That film is still the acceptance test for "springs visible".
- LATER, copy: the stamp card in 05 says "Come back tomorrow for the next one." under a header that says
  "New in 7 h 27 m". Same complaint as R2.6. When the reset time is known: "Next stamp in {hours} h {minutes} m".

## 2. Crickets: GO to the beta

State and timing match the spec (bed .12 to .20, second layer, three bush voices, the 6 stud hush, no bird voice at
night). Nobody has heard it: no audio came out of the unfocused window. Ship it to the beta and let Spencer listen for
three things: the bed sits under the brook, no traffic rumble survives the -18 dB low cut, the near trills do not
sound like the same clip three times. If the trills repeat, widen pitch to **.90 to 1.12**. No look change.

## 3. Bird: FIX

What the captures show. Close three-quarter (10) is nearly there: the wing file is lovely and the egg body reads.
Everything else fails at play distance:

- **Side (07, 09):** a loaf lying in the grass with a ball on the front: a duck on water, or a kiwi. The 20 degree
  pitch does not read, and with no legs the belly sits on the ground.
- **Beak:** a thin dark wedge (#3A3028 on a #7A6248 head, about 30% value apart). In 07 it is a needle, in 08 a brown
  square, in 09 gone. Colour is half the problem: dark on dark.
- **Front (08):** wide dark ball, eyes at the far edges, square in the middle: a frog.
- **Tail:** a .02 plate seen edge-on is a hair. In 06, 07 and 10 it is a line longer than the body.

The fix: 10 parts, no mesh assets, same pool, same wing and breast files. Root = body centre, -Z forward, studs.

| Part | Now | Change to |
|---|---|---|
| Body | spindle (.50, .52, .82), pitch 20 | Size **(.50, .50, .74)**, pitch **35 deg nose-up**. Upright is what says songbird; flat says duck |
| Head | Ball .40 at (0, .28, -.30) | Ball **.38** at **(0, .34, -.20)**: on top of the raised chest, not out in front of it |
| Beak | WedgePart (.09, .08, .20), dark | **Spindle (Block + Sphere mesh) (.14, .12, .26)** at head * **(0, -.03, -.20)**, so half is buried and a **.13 long, .14 wide** rounded cone sticks out. Round from the front, a short point from the side. No wedge |
| Beak colour | #3A3028 / #2E2E33 / #4A4038 | Ember **#E2A548**, Slate **#E8B45A**, Moss **#D98A4A**. Rule: beak value at least 35% above the head's. This is the single biggest win |
| Eyes | Ball .08 at head * (+-.135, .04, -.12) | Ball **.09** at head * **(+-.125, .05, -.135)**: a little forward and inward, so both show from the front and one from the side |
| Wings, folded | plates (.03, .68, .32) at (-+.25, .03, .11) | unchanged size; re-seat on the 35 degree body, tips meeting over the tail root |
| Tail | plate (.22, .62, .02), -15 deg | **WedgePart (.26, .10, .44)**, thick end sunk **.08** into the rump, thin edge at the tip, flat face up in line with the back, rest **-10 deg**, flick to **+10**. Colour `tail`. Tail file on the top face. **[check]** wedge facing |
| Legs (new, 2) | none | Block **(.03, .16, .03)** at **(+-.08, -.31, .02)**, vertical in world, colour = beak colour. Root sits **.14** higher on perches and ground. Drop these first if the pool budget bites |

Proportions to hold: beak out : head = **1 : 3**; head : body length = **1 : 2**; tail : body length = **3 : 5**
(shorter than now); tail thickness at the root at least **.10** so it never goes to a line; overall height about equal
to overall length (was 1 : 2.3: that was the duck).

Why it reads from each side:
- **Front:** round head over a round pale breast, a bright round beak in the middle, two eyes beside it, legs under.
- **Side:** tilted teardrop, head bump on top, bright point forward, solid tail wedge down the back line, legs.
- **Three-quarter:** all of the above, plus the wing file, which already works.

Flight: wing shoulders move with the head change to **(+-.20, .12, -.06)**; body pitch in flight goes to **10 deg**
(level), legs hidden (Transparency 1) while flying. `Sim.Bird.tail` -15 -> **-10**. Recapture front, side and
three-quarter at **8 studs**, not close-ups: the test is play distance.

## 4a. Butterflies: GO

07: wingspan equals the .5 stud cube, about a third of the Bear. That is the Animal Crossing size. The white one
against the sky in 06 still reads. LATER: the orange wing shows a grey fringe at its edge up close (decal alpha
halo); bleed the wing colour into the transparent pixels of the file.

## 4b. Leaves and petals: FIX

06 is wrong: the leaf by the Bear's ear is the size of its head. 07 measures it: emitter Size .25 draws a leaf
**.36** studs across, so the drawn leaf is **1.45 x Size**. My keys assumed 1 x. Target is the drawn size, so divide
by 1.45:

| Emitter | R2 keys | **New keys** | Drawn at peak |
|---|---|---|---|
| Leaf A | {.16, .24, .04, .22} | **{.11, .165, .03, .15}** | .24 studs, 1 : 6 of a pet |
| Leaf B | {.14, .21, .03, .19} | **{.10, .145, .02, .13}** | .21 |
| Petal | {.11, .17, .03, .15} | **{.075, .12, .02, .105}** | .17 |

- If the air then looks empty, rate 2.4 / 1.2 -> **3.0 / 1.5**, nothing else (as in the R2 spec).
- **[check]** the petals in 06 are blown-out cream blobs with no texture. If `LightEmission` is above 0 on the petal
  emitter, set it to **0** and colour no brighter than **#F1E6C8**.
- Recapture next to the pet and the .5 cube. Pass = a leaf no wider than half the cube.

## 5. "Coming up" strip: GO, 3 small FIXes

Title, clock mark, live countdown and three chips are right in both places (17 deck, 19 Dash). The "see you tomorrow"
problem is gone. Fixes, all small:

1. **Gold must mean ready, and say so.** The quest chip is outlined and sorted first because one quest is ready to
   claim, but it reads "3 quests to go". Add the state: `questsReady` **"{count} ready to claim"** (short "Ready!",
   tiny "Ready!"), gold outline, sorts after egg and stamp. With nothing ready: no outline, normal order.
2. **Stamp text is gold while 8 h away.** #FFC14D text reads as ready. Text goes to the same cream as the egg chip;
   only the Star icon stays gold. Gold text and outline only in the `stampReady` state.
3. **"Stamp 1 in 8 h" breaks the floor rule** (about 7 h 17 m were left; the egg chip beside it said 7 h 48 m). Use
   the egg's format: new key `stampInHM` **"Stamp {count} in {hours} h {minutes} m"**, short "7 h 17 m", tiny
   "7h 17m"; under 1 h "Stamp {count} in {minutes} min". Same for `questsIn`.

Also: the outline in 17 and 19 renders cream, not gold. Ready outline is **#FFC14D, 2 px**.
LATER: phone 844 x 390 capture of both strips; the egg-ready gold and boing (egg was 7 h out).

## 6. Ground flowers: GO by day

11 to 14: the rosettes have vanished into the lawn, no ink, soft edges, and from the wide shot (14) the patches are
quiet dots of colour instead of stickers. That answers "too glaring". The daisies (13) are the brightest thing on the
lawn but only just; leave them. The lawn in Studio renders brighter than my computed #31763D, which only helps.
LATER: the night capture. If whites pop at night, the #C8D0E0 tint under daylight .3 from the R2 spec.

## Other

- Nest sign back face (15, 16): "Bear's egg." reads whole from the arrival path, post stops under the board. GO.
- Dash place pill hidden at results (18, 19). GO.

## Order of work

1. Leaf and petal keys (builder already on it; use the table in 4b).
2. Bird: beak shape and colour, tail wedge, 35 degree pitch and head position, then legs.
3. Strip fixes 1 to 3. 4. Round key press.
Then recapture: bird x3 at 8 studs, leaf beside the cube, strip with a quest ready.
