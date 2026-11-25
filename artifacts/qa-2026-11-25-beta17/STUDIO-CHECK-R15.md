# Beta (18) candidate: Studio check R15 (Opus, 2026-11-25)

`feat/egg-drop-arcade-polish` at **2a075417** (R13 fixes, river stones, capsule framing, the Hollow re-lay). Rojo on
34872, Studio 53800d7d (the beta place file), one Play. Before Play, Edit held the repo's LF byte lengths for HatchFlow
8,672, ModalCursor 7,011, HowItWorks 30,124, StoneBuilder 4,619, RiverStones 8,938, LifeScene 18,939, EggMachineClient
42,989, HatchAim 2,498, HudChips 3,942, NotificationRail 32,172, TierHost 10,250, ParkLayout 27,846, FindSpots 1,547,
WorldDressingClient 9,622, client init 326,062, server init 153,336. Fresh save, Bear by the welcome remotes, three
140-Star jars (440 Stars). Studio window focused with one real click; buys, Hatch another, the "?" and Store were real
clicks. Nothing saved or published; place 96451847774961 untouched. Captures in `studio/r15/`. At the end: Play
stopped, Studio in Edit, Rojo disconnected and serve stopped, the 2 synced `ZZSpecs` folders removed from Edit (0 left).

## Results

| # | Check | Result |
|---|---|---|
| 1 | Console | **PASS.** At start and after every step: only the known lines (ConfigService keys, Assistant version, BoardSnapshot drop, EditableImage, `Player:Move`, 203785492, the Assistant camera reset). No `[EggMachine]`, `[Tier]`, Hollow, stone or HatchFlow lines. |
| 2 | River stones: no slabs | **PASS.** 8 unions, none spread: rows 2.7 to 3.7 studs across, landings 2.5 x 3.0, company .8 to 1.4 (bounding boxes). |
| 2 | Tops | **PASS.** Rays on the stones: East / Middle / West **4.00**, landings 4.33, company 3.40 to 3.60 (spec). Colliders top 3.97, 2.9 across. |
| 2 | Water between stones | **PASS.** Top-down (02b): water shows between all three and at both ends. Middle and East come closest. |
| 2 | Landings meet the kerb | **PASS with a note.** Each landing touches the kerb's outer face on the lawn side (02b, 02c), so the kerb stays whole between landing and river. They do not break the kerb as the RiverStones comment says. Fable call. |
| 2 | Wet band, moss, wakes, rings at budget 0 | **PASS (state); look for Fable.** `AliveLevel` 0. 5 flow rings + 3 wakes, `#EAF6F8` at y 3.22, decals pulsing .45 to .85 (two reads .9 s apart), wakes 1.5 studs downstream (-Z). Moss reads on the tops (02a). The wet band is hard to pick out at these distances. |
| 2 | Walk across | **PASS.** MoveTo from kerb to kerb (x 13.3 to -3.4) through both landings and the three stones in 1.4 s. No humanoid state change (no Jumping or Freefall). Root y 7.04 to 7.73 over the river. |
| 3 | Capsule shot timeline | **PASS** (Toy, first of a type, from the shop; times from the click): `screen_tuck` .10, HueEggView tucked to Y 1.0+40 by .29, 5 clicks .40 to .88, clunk 1.00, roll 1.05, land 1.45, shine 1.60, rise 1.85, panel home 2.10, wobble 2.30. Same as R13. |
| 3 | Shot A shows the dial (no flat egg) | **FAIL.** The reveal's full-screen stage stays on screen for the whole shot: teal shell, the waiting egg card and "Tap to skip" (03c live during a Hatch another shot; 03d frozen at tuck + .60 s on a Customization buy). The camera is at Shot A behind it, with the dial left of centre (03e, GUI hidden). Cause in Findings 1. |
| 3 | Shot B cup size | **PASS by measurement.** GUI hidden (03b): cup 147 px wide on a 485 px tall viewport, so **17.0%** of a 16:9 frame and **14.0%** of 19.5:9 at FOV 65 (12.3% of Studio's 2.47:1 panel). Cup centre 53% across, 70% down on 16:9 (Fable's target: 62% / 66%). Shot A camera (-32.84, 8.13, 2.82); Shot B (-36.10, 5.93, 1.21). I could not set a 19.5:9 viewport from MCP, so that number is computed. |
| 3 | Rail hidden during the shot and reveal, back after | **PASS, one flash.** Row `Visible` false from the shop opening, through the shot and the reveal, and back when the reveal closes (Store). During each Hatch another gap it comes back for about .38 s (04a, Findings 2). |
| 4 | Hatch another, 2nd and 3rd in a row | **PASS (buys) with a finding.** A Toy Egg from the shop, then 5 Hatch another in a row (all 6 toys found); a Customization Egg from the shop, then 1 Hatch another. Every Hatch another: store `Saved`, then buy `Saved` .38 to .40 s later, never `Throttled`; Stars 440 to 296. Each gap closes the reveal and hands the camera back, and the next buy plays the full first-drop schedule, not the streak 2 or 3 one (Findings 2). |
| 5 | "?" card at the nest | **PASS.** Tuck in, E for Peek, then a real click on the pill's "?" opens "Napping egg" (05a). While it is open, `ProximityPromptService.Enabled` is false. E closes it (Got it), no `PromptTriggered`, pet focus not opened, camera Custom (05b). After it closes, prompts are Enabled and Peek shows again. |
| 6 | Bone reveal shadow | **PASS.** One wide shadow (06a, 06b): stage `FloorShadow` 156 x 33 at .5; the scene's `ContactShadow` at Transparency 1. |
| 7 | The Hollow | **PASS.** With the owner standing in the palm, the Bear went to the swing (-47, -44) within 4 s and swung (y 5.0 to 6.4); the HUD read "Play date 1/3 · playing". For Fable's paw read: 07a, from the cliff path above, shows the four toes (see-saw, slide, sand box, swing) round the palm mat and ball. In 07b, from the terrace edge, a rock face blocks the near half of the view. |
| 8 | `/tier off` evacuates | **PASS 6 of 6.** Terrace (-71.9, 31.9, -60.1), 3 tries: moved in .07 / .12 / .12 s to (-14.0, 8.1, -79.0) / (-12.4, 8.1, -78.7) / (-15.6, 8.1, -79.3). Path points 20 / 30 / 40 (y 17.3 / 22.5 / 26.4, `onPathUp` true, `onIt` false): moved in .13 / .07 / .12 s. Walked up by MoveTo along the 49 centre-line points each time (8.4 s, never stuck). R13's miss was not reproduced. `/tier on` restored. |

## Findings

1. **The capsule shot is hidden behind the reveal stage (blocker for the capsule switch).** `HatchItemStage.lua:482`
   puts the stage root under `Kit.coverScreen`, and `DeckKit.lua:2493` re-syncs it to cover the screen whenever its
   parent's AbsolutePosition changes (`:2507`). The capsule tuck (`EggMachineClient.lua:680` `placePanel`) moves
   HueEggView off the screen, so coverScreen moves the stage straight back. Frozen at tuck + .6 s: HueEggView
   AbsolutePosition y 827, stage `Position` offset -885, so it still sits at y -58 and covers 2108 x 854 with an
   opaque Shell. `lateRoots` (`:690`) cannot help, because the stage's top root is HueEggView itself. The player sees
   the teal stage with the egg card and "Tap to skip", not the machine, in Shot A and Shot B. Fable's 02a flat egg is
   the first frame or two of this. Possible fix: coverScreen leaves a frame alone while it carries a hold attribute
   (for example `CoverHeld`), and the machine sets that attribute on `cinematic.borrowedStage.root` and tucks it with
   the panel; or the machine offsets the stage after each sync. This is not a one-liner, so I made no edit. Until it
   is fixed, the beta should ship with `/onboard capsule off`.
2. **Hatch another breaks the streak and the camera hold.** `HatchFlow.lua:115` `hold()` now waits out
   `Flow.Spacing`. In that wait the store's snapshot closes the shade, then `init.client.lua:4937` `watchClose` calls
   `Machine:revealClosed`, which calls `returnCamera`. The camera eases back to the player and is Custom by +.30 s, and
   the rail returns. At +.38 s the buy goes out and `EggMachineClient.lua:640` resets the streak to 1, because the
   camera was given back. So every repeat plays the full Shot A to Shot B swoop (5 clicks, land +1.36), never the
   2nd or 3rd schedule from Shot B. The `handoverNext` pending in `HueEggView.lua:290` does not hold the shade over
   the gap. Possible fix: `revealClosed` skips `returnCamera` (and the rail stays hidden) while
   `hatchFlow:againPending()`, or the shade stays open until the next buy lands. Not a blocker: the buys work.
3. **Landings sit outside the kerb.** They touch the kerb's outer face on the lawn; the kerb is not broken where the
   crossing lands. Fable call: accept it, or move the landings .3 to .5 studs toward the water.
4. **Studio note.** After the first `execute_luau` the Assistant left the camera Scriptable. E (pet focus) followed by
   a real click on Back restored Custom before the buys, so the shot's saved camera type was correct.

## Blockers for beta (18)

Findings 1: the capsule shot as built shows the reveal stage, not the machine. Fix it before publish, or publish with
the capsule switch off. Everything else passes. Findings 2 is strongly suggested (the visible swoop and rail flash on
every Hatch another). Findings 3 is for Fable.

## Captures (`studio/r15/`, for Fable)

02a stones from the south, rings and wakes. 02b stones top-down: water between them; landings at the kerbs. 02c east
landing and stones, low angle. 03a first buy, the tuck's first frame. 03b Shot B with the GUI hidden (cup). 03c a live
Hatch another shot: the stage covers the screen ("Tap to skip"). 03d frozen at tuck + .6 s: stage covers Shot A. 03e
Shot A world under the stage (GUI hidden). 04a the Hatch another gap: the rail back over a greyed card. 05a the nest
"?" card. 05b after E: card closed, no pet focus, Peek back. 06a / 06b Bone reveal, one wide shadow. 07a the Hollow
from the cliff path (paw read). 07b the Hollow from the terrace edge (blocked by rock, near half).
