# Capsule shot, HUD chips, Peek, bubbles, cursor (Fable, 2026-11-25)

Direction for Opus, from Spencer's beta (17) notes (`FEEDBACK.md` U1, U2, U3, U5, U7; shots 012050, 012230).
It replaces "The crank when a hatch is bought" in `artifacts/qa-2026-11-24-beta15/EGG-CORNER-LOOK.md` section 2 and
the `Peek` row of its prompt table. Everything else in that document stands. The machine is ours (egg in an egg cup,
flower dial, leaf chute, woven cup); nothing here borrows another game's machine, camera or UI.

`[check]` marks something Opus confirms in Studio before building on it.

---

## 1. U5: the capsule shot

### Why nobody has seen the crank

The buy is pressed with the Hatch eggs screen open. `EggMachineClient` turns the dial behind the panel, and
`HatchCinematic` is already visible with its clock held by `Cinematic.gate` for at most `Machine.Cap` = 1 s. So the
player sees the reveal's first frame, frozen, over a machine they cannot see. The fix is not a longer hold. The
reveal must **not be on screen** until the egg is in the cup.

### The rule

**Hatch pressed and confirmed: the screen gets out of the way, the camera looks at the machine, the egg comes out,
then the screen comes back with the reveal.** One egg, one landing: the thud in the cup is still the ritual's Settle
thud (`land`); the reveal does not play its own.

Nothing moves on the press itself. The tuck starts on the confirmation (the same moment the crank turns today), so a
refused buy keeps the screen exactly where it is and gets the hello nudge and one click, as now.

### Timeline: first hatch, at the machine (t = 0 at the confirmation)

| Time (s) | Screen | Camera | Machine | Sound | Haptic |
|---|---|---|---|---|---|
| 0.00 to 0.18 | Hatch eggs panel slides down 40 px and fades out. The shade lifts. The dock, the rail and every HUD chip fade out with it. | Starts easing to **Shot A** (0.30 s, ease out). | Still. The old egg in the cup, if any, goes now. | `screen_tuck` (new) | |
| 0.30 to 0.90 | Nothing on screen. | Holds Shot A. | Dial makes the full turn (0.6 s). Loose eggs hop, the pile shivers, as today. | 5 `crank_click`, pitch stepping up 4% each; 2 `egg_tok` | 5 light |
| 0.90 | | Starts easing to **Shot B** (0.40 s, ease in-out), following the egg. | Dial stops, springs back 8 degrees. | `crank_clunk` | 1 medium |
| 0.95 to 1.35 | | Arrives at Shot B as the egg lands. | The egg, in the bought type's colour, appears at the chute top and rolls down the leaf: **0.40 s** (today's 0.23 is too fast to read). | `egg_roll`, stretched to 0.40 s | |
| 1.35 | | Holds Shot B. | Lands in the cup, rocks once (8 degrees, 0.3 s). | `land` (the Settle thud) | the Settle haptic |
| 1.35 to 1.75 | | Holds. | **The beat.** The egg sits. One soft pulse of its own colour on the cup rim (a 0.3 s brighten, no particles). | `cup_shine` (new) at 1.50 | |
| 1.75 to 2.00 | The panel rises back from the bottom (the tuck in reverse) with the reveal already on it, its egg centred, the same type and colour as the egg in the cup. | Holds Shot B behind the panel. | The egg in the cup fades as the panel covers it. | `screen_rise` (new, quiet) | |
| 2.00 | The reveal's clock starts at "Tap the egg", exactly as specified. | | | | |

Two seconds from confirmation to the reveal. Hard cap: if anything stalls, the panel rises at **2.2 s** regardless
(`Machine.Cap` becomes the hand-off time of the running schedule plus 0.2).

### The two shots

Positions are in the machine's own frame (front = the dial's face, right = the chute and cup side, up from the
ground). Field of view stays at the player's own setting; no roll, no shake, no cut.

| Shot | Camera at | Looks at | In frame |
|---|---|---|---|
| **A, the machine** | 10 studs in front, 1.5 right, 4.2 up | the front face 2.6 up | The whole machine with a little air above the sprout; the dial left of centre, the cup lower right. |
| **B, the cup** | 5.5 studs in front, 2.0 right, 2.4 up | a point 0.6 right of the dial, 1.0 up | The dial upper left, the leaf chute across the middle, the cup lower right at about two fifths of the screen height. The globe's lower third shows at the top. |

- The move A to B is one continuous push down and in. It should feel like leaning closer, not like a cutscene.
- **Hide what is in the way:** the player's own character and their own pets go see-through for the shot
  (`LocalTransparencyModifier`, 0.15 s fade) and come back when the camera returns. Other players and their pets are
  left alone.
- **Line check** before the tuck: a ray from each shot's look-at point to its camera position. If world geometry
  blocks Shot A, mirror the camera to 1.5 left. If that is blocked too, use the pocket version below.
- **Coming back:** the camera stays at Shot B for as long as the reveal or its result is up (so Hatch another starts
  from there). When the reveal closes it eases to the player's camera in 0.30 s. It is always given back: on close,
  on the Hatch eggs screen closing, on respawn, on the 2.2 s cap failing, on the model unbinding. Never leave the
  camera Scriptable.
- Movement stays locked from the confirmation to the reveal closing (the existing modal lock). The cursor is free.
- `[check]` Opus sends captures of Shot A and Shot B at noon and dusk, desktop 16:9 and a phone 19.5:9, before
  tuning anything else. The numbers above are my first read of a 4.2 x 3.8 x 7.2 machine; move the camera, not the
  machine, if the cup is cropped.

### Hatch another (2nd, 3rd in a row, within 20 s)

The camera is already at Shot B, and Shot B has the dial in it, so there is no Shot A.

| | Tuck | Dial | Clunk | Roll | Lands | Beat | Panel back | Reveal starts |
|---|---|---|---|---|---|---|---|---|
| **2nd** | 0 to 0.15 | half turn 0.10 to 0.55, 3 clicks | 0.55 | 0.57 to 0.87 (0.30) | 0.87 | to 1.07 | 1.07 to 1.30 | **1.30** |
| **3rd onward** | 0 to 0.15 | quarter turn 0.10 to 0.35, 1 click | 0.35 | 0.37 to 0.62 (0.25) | 0.62 | to 0.75 | 0.75 to 0.95 | **0.95** |

The clunk, the roll and the thud always play. `cup_shine` only on the first of a streak. The previous egg in the cup
goes the moment the new tuck starts.

### Skip

- **The first capsule drop of each egg type cannot be skipped** (the same rule and the same `canSkip` source as the
  first reveal of each type).
- After that, a tap, a click, or A / Space / Enter anywhere during the shot **jumps to the landing**: the egg is set
  in the cup, `land` plays, and the panel rises 0.12 s later. The thud is never skipped; it is the hand-off.
- No Skip button, no hint text. The shot is two seconds.

### Phone

Same shots, same times. The panel's tuck is its normal sheet sliding down. Skip is a tap anywhere. Nothing is drawn
over the shot, so there is nothing to fit. `[check]` on a 19.5:9 phone the cup is not under the notch side; if it is,
shift both shots' look-at 0.4 studs toward the cup.

### Reduced Motion

No camera move, no tuck, no roll. The panel stays up. The sounds play over the 3rd-in-a-row schedule (1 click, clunk,
`land` at 0.62), the preview egg in the right pane fades to the bought colour, and the static result card shows **on
the thud** (0.62 s) rather than at once as it does today. The world machine still turns for anyone watching.

### Bought away from the machine (the Pocket menu)

Never fly the camera across the garden, and never cut to a machine that may not be streamed in. **The pocket
version** plays instead whenever any of these is true: the machine model is not bound whole; the player's root is
more than 24 studs from it; both line checks failed.

The panel stays up. The drop happens in the egg preview well on the right pane, with the art that is already there:

| Time (s) | In the well | Sound |
|---|---|---|
| 0 to 0.45 | The preview egg shakes 6 degrees on each click, then slips out of the bottom of the well. | 3 `crank_click` |
| 0.45 | The well is empty for a breath. | `crank_clunk` |
| 0.47 to 0.75 | The bought egg drops in from above the well's top edge (clipped by the well), falls to rest, one small bounce. | `egg_roll` |
| 0.75 | It sits. | `land` |
| 0.75 to 1.00 | Beat. | |
| 1.00 | The reveal starts from that egg. | |

Streaks use the same table every time (it is already a second). Skip as above. No new art, no ViewportFrame of the
machine. The world machine still turns and drops its egg for anyone standing near it.

### Left alone tonight

- **The Stat Egg** (its own reveal, never held today): the pocket version's sounds only, as now. Bringing it into
  the shot is a later slice.
- **Other players seeing it:** unchanged from EGG-CORNER-LOOK (local first).
- The `Turn` open crank (quarter turn, then the screen) is unchanged.

### New sounds

| Name | What | Length | Level |
|---|---|---|---|
| `screen_tuck` | a soft paper slide downward, falling pitch | 0.18 s | -22 dB |
| `screen_rise` | the same slide, rising | 0.20 s | -24 dB |
| `cup_shine` | one small glassy ting, about 1.8 kHz, no tail | 0.25 s | -22 dB |

Existing and kept: `crank_click_1..3`, `crank_clunk`, `egg_roll` (stretch to fit the roll time, do not loop),
`egg_tok_1..3`, `land`. All flat with the screen. If the three new ones cannot be made tonight, ship without them;
the shot must not wait on audio.

---

## 2. U1: HUD chips (shot 012050)

### What each thing is

- **"Games 0/3"** (top, the rail's status ticket; `UICopy` `park.games`, built in `ParkClient` `railStatus`) is the
  daily **Play date**: your pet joins 3 park games today and you get Stars once (`date.reward`, 4 by default). 3 is
  the day's **target, not a limit**; pets keep playing after it, there is just no second reward. Its other states
  are `Playing · 1/3`, `Saving · 1/3` and `+4 ★ today`.
- **"Pets playing 3/9"** (bottom right, `ParkCounter`) is something else: how many pets, everyone's, are in this park
  out of its play slots. It only matters when the park is full.
- **"Egg 4 h"** (bottom right, `NestClient` chip) is the napping egg's clock.

Two counters that both look like "x/y games" is the confusion. Rulings:

| Thing | Ruling |
|---|---|
| `park.games` "Games {count}/{target}" | **Rename** to the name the Things page and the park pill already use: `Play date {count}/{target} · +{reward} ★`. Phone: `Play date {count}/{target}`. One name for one thing everywhere. |
| `park.playing`, `park.saving` | Keep the states, same pattern: `Play date {count}/{target} · playing`, `... · saving`. |
| `park.done` "+4 ★ today" | `Play date done · +{reward} ★`. |
| `park.count` "Pets playing 3/9" | **Remove** the always-on count. Nobody needs it until it is a problem. |
| `park.full` "Park full · 9/9" + `otherHasRoom` | **Keep**, and only this: the pill appears above the dock when the park is full. |
| Egg chip | **Moves into the notification area**, below. |

### The egg chip in the rail

The lane above the dock belongs to the Throw button and, rarely, "Park full". The egg clock leaves it for good.

- The egg becomes a **status ticket** in `NotificationRail` (the pinned-left slot the play date uses), with the same
  nest icon, the same text (`Egg 4 h`, `Egg 12 min`, `Hatch egg!`), the same accessible label and the same tap (the
  Show me trail to the nest).
- The slot shows one status at a time, in this order: **`Hatch egg!`** (gold, always wins) > **Play date** (only
  while you are inside a park) > **the egg's clock** (everywhere else).
- When the egg turns ready while something else holds the slot, it takes the slot at once with the rail's normal
  entrance. No extra toast.
- Hidden where the rail is hidden today (rounds, the Deck, any full screen).
- Phone: icon and `4 h`; the word `Egg` drops under 360 px of rail width.
- Remove `NestClient`'s dock-lane chip and its `chipHidden` wiring once the ticket is in. (The overlap in the shot
  is that `chipHidden` did not fire in this park; it stops mattering.)

Bottom right, top to bottom, is then: `Park full` (rare), `Throw` (in a park), the dock. Nothing overlaps.

---

## 3. U3: Peek

Spencer pressed `Peek` and got the help card. The verb promised a look at the egg. Ruling: **Peek shows the egg;
the "?" explains it.** Two things, two controls.

**`Peek` (E / the prompt / gamepad), while the egg naps:** a 1.6 s look, no card, no camera move, nothing to close.

| Time (s) | What |
|---|---|
| 0 | The egg stirs: lifts 0.15 studs and tilts 8 degrees toward the player, three `zzz` puffs. Sound: the tuck-in rustle, quiet. |
| 0.1 | The gift tile that Tuck in already shows (`NestClient:peek()`, the `GiftPeek` board: the item, `+Stars`, `Egg n of 7`) fades in over the egg. |
| 0.1 to 1.3 | The pill reads the clock, `Hatches in 4 h`. The tile holds. |
| 1.3 to 1.6 | The tile fades, the egg settles back with one small rock. |

- The prompt is off while it plays and for 0.6 s after, so E cannot stack peeks.
- Reduced Motion: no lift or tilt; the tile fades in and out.
- The name `Peek` stays. It is now true.

**The card:** only the "?" disc on the pill (and a tap on the pill) opens "Napping egg". Keyboard and gamepad reach
it from the Things to do page's nest row, as today. No prompt opens a card any more.

---

## 4. U7: the need and ball bubbles

`NeedBubble.lua` draws a white disc with a top-to-bottom grey gradient (`UIGradient`, `Bubble.Shade`) and a white
gloss crescent (`Gloss`), and the icons are still system emoji, which carry their own baked highlights (the tennis
ball most of all). Together it reads as a shiny 3D ball. A BillboardGui turns to face the camera, so as you orbit,
the "ball" turns with you and its highlight never moves against the sun. That is the fake look.

It is a sign, so draw it as a sign. **A flat sticker, in the same family as the rail tickets and Kit tiles:**

- **Remove** the `UIGradient` and the `Gloss` frame. No highlight, no shading, anywhere on it.
- Fill flat cream-white `#FFFDF6`. Outline stays 2 px ink `#24304F`. Tail stays, same fill and outline.
- Depth comes from a **lip**, not from light: a second disc of the same size behind it, 3 px lower, ink at 25%
  opacity (the Kit.tile lip). It is drawn, so it never disagrees with the sun.
- **Icons:** ship the six flat icons from the onboarding art table (`Bubble.IconIds`): two flat colours and ink
  line, no gradient, no gloss, no drop shadow. Until they are uploaded the emoji stay, and the ball will still look
  lit; say so in the build note rather than calling U7 done.
- **No rotation of any kind:** nothing on the bubble animates `Rotation`; the press squash is scale only; the tail's
  fixed 45 degrees is fine. The hop stays (it is a lift, not a turn).
- Keep `LightInfluence = 0`, `AlwaysOnTop`, the fixed pixel size, the hit area, the key cap, the follow spring.
- Same rule for every world billboard a pet or the nest carries (`GiftPeek`, the nest pill): flat fill, ink line,
  lip. No gloss on anything that faces the camera.
- `[check]` I found no code that turns these billboards. If Spencer still sees one turn after this, it is another
  object; capture it and send it to me.

---

## 5. U2: the PC cursor

Finding: `ModalCursor` frees the mouse only while `clientUI.anyModalOpen()` is true, and that is a hand-kept list of
screens. The "?" cards (`How`), `Confirm` and the arrival hatch are checked separately elsewhere and are not in it.
So the "Napping egg" card opened with the mouse still owned by the camera.

The rule:

1. **Any card or screen with a button frees the cursor.** One registry, not a list: every card and screen registers
   itself when it opens and leaves when it closes, and `ModalCursor` reads the registry. A new card cannot forget.
2. **Every card closes from the keyboard.** Its main button is focused by default; E, Enter, Space or gamepad A
   presses it; Esc or B closes. A stuck mouse can never trap a player on "Got it".
3. **Shift Lock is off** for this game (`StarterPlayer.EnableMouseLockOption = false`). It is a pet garden with
   things to click; nothing here needs a locked aim. `[check]` the place's current value in Studio: nothing in
   `src/` sets it. If something else of ours is locking the mouse (the care camera, a lost right-button release),
   fix that; do not paper over it.
4. **No hint is needed** once 1 to 3 hold: the cursor is free whenever there is something to click, and right-drag
   turns the camera as in every Roblox game. If Spencer wants Shift Lock kept, then and only then add a small key
   cap bottom left while it is on: `Shift` `Free the mouse`.

---

## 6. Order, switches, what I want to see

1. Cursor rule (small, unblocks testing everything else).
2. Bubble sticker (small).
3. Chip rename and the egg ticket in the rail.
4. Peek.
5. The capsule shot, behind its own switch, pocket version first (it needs no camera), then Shots A and B.

Captures for me: Shots A and B (noon, dusk, desktop, phone); a clip of a first hatch, a 2nd in a row and a pocket
hatch; the rail with each of the three status states; a bubble over the Bear at noon from two camera angles.

Each adds its row to `V3-TEST-PASS.md` when it lands on the beta. New strings (`park.*` renames, the `Shift` hint if
used) go through the localization export.
