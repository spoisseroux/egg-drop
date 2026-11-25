# Beta 17 candidate: Studio check R12 (Opus, 2026-11-24)

`feat/egg-drop-arcade-polish` at **fa21fcf**, Rojo on 34872, Studio 53800d7d (place file; Studio counts as beta).
Before Play, Edit held the repo's LF byte lengths for all 22 changed modules (EggMachineClient 26,165, HatchAim 754,
HatchDisplayScene 25,007, GardenPetVisual 32,802, client init 321,577, server init 153,108, EggCornerWorld 23,394,
UICopy 57,072, DenHost 10,879, DenConfig 2,594, DenClient 7,339, DenLayout 13,007, DenGreybox 5,005, DashAnchor 1,859,
PlayDen 3,234, DashHost 24,295, DashDirector 21,052, DashClient 49,474, Tier 12,739, TierHost 8,912, ThingsPage
12,550, PetFloors 899). Plays: **1** streaming off (as the place), **2** streaming off with a temporary DenLayout fix
(reverted, not committed), **3** streaming on (set in Edit for the Play, set back to false). Fresh save each time (Bear
by the welcome remotes, ack). Nothing saved or published. No src change committed. Captures in `studio/r12/`.

**Streaming on the beta:** this place file has `Workspace.StreamingEnabled` **false** (target 1024, min 64), and every
beta is "Publish As" from this file, so the beta is false too. Play 1 mimics it. Play 3 tried it on.

## Results

| # | Check | Result |
|---|---|---|
| 1 | Egg machine: prompt | **PASS.** `EggMachinePrompt.TurnEggs` reads **"Hatch eggs" / "Egg machine"**, reach 7 (01a). |
| 1 | Turn (open crank) | **PASS.** Dial from rest: 90 deg turn, overshoot to 96 at .25 s, settles at 90 by .43 s; loose eggs hop .10; Hatch eggs opens at **.32 s**. Play 3 (streaming on): 102 deg of travel (90 + 6 + 6 back) from .02 to .42 s, screen at .31 s. The dial keeps its turn (dialRest +90 a press). |
| 1 | Buy (Toy Egg) | **PASS.** Full turn (.6 s) after the buy is confirmed, the pile shivers .007 to .039, the drop egg shows at +.58 s and sits in the cup (distance 0) at **+.81 s**, colour `#FFB340`. Hatch another on a Stat Egg within 20 s: **193 deg** (the half turn), .74 to 1.32 s, egg in cup at 1.42 s. Clunk not heard (Studio unfocused plays no sound). |
| 1 | `[EggMachine]` warnings | **None** in any Play. The machine was whole at first bind (Body, Dial, DialPivot); with streaming on it is Persistent, whole 160 studs away at spawn. |
| 1 | Spencer's B1 | **Not reproduced.** Real-server mimic: Test > Server and Clients started a server (machine present, corner on) but no client window joined; abandoned. **One way to get exactly his symptom in Studio:** with the camera more than 60 studs from the Body (the Assistant froze it at spawn, 160 away) Turn still opens the screen at .3 s and every crank is drawn at rest (the range check). On the beta that needs a far camera, so unlikely. Ask Spencer for the F9 log lines `[EggMachine]` if it happens on beta 17. |
| 2 | Reveal centred (B3) | **PASS.** The egg's axis projects to **x .500** in the reveal card for Toy, Stat (twice) and Customization Eggs; the closed egg's wobble spans .468 to .514 (Toy), .474 to .512 (Stat), .475 to .545 (Customization). Hatch eggs preview tile: egg about .49 (02d). **Finding:** an "Open saved toy" reveal stayed `QABuilding=true`, `QAPresented=false` for over 60 s (egg drawn centred, 02a); Backspace closed it; the next Toy Egg (Bone) played through. |
| 3 | Bunny glance | **PASS.** Runtime `GardenPetVisual`, Bunny eye mesh `111729099378548` (the conform). Curious vs neutral, in Head space: both eyes turn **2.80 deg** round the head; their distance from the head centre is unchanged (EyeL .4364 / .4364, EyeR .4366 / .4366); travel x +.018, y +.010. Captures front, 3/4 left and right at 40 deg: both eyes whole (03a to 03d). Pets drawn without a palette (white). |
| 3 | Bear glance | **PASS.** Same turn (2.73 deg, x +.018); both eyes whole front and both 3/4 (03e to 03g). |
| 4 | Terrace closed | **PASS.** `Tier_on` false: no `EggDropLounge.Tier` (no zigzag, no terrace), 0 footprints, ring boxes Wall98..Wall111 (14) colliding. `/tier on`: Tier model 68 descendants, 14 ring boxes off, 8 footprints. `/tier off` puts it back. |
| 5 | `/den on` | **PASS.** `Den_on`/`Den_open` true, `PlayDen` 39 parts, 4 PointLights (r 14, 1.2, no shadows, `#FFC98A`), blocker CanCollide/CanQuery false, prompts Race / Play / Things to do (reach 6, E, ButtonX, clickable, OnePerButton). |
| 5 | **Pet follows in (P3)** | **FAIL.** The player walks in; the Bear stays on the apron (x -3..-6, z -88.6..-91.5) for 15 s. Cause: `DenLayout` floors top out at `floorY+3` = **7.0**, and `petAnchor` tests the owner's anchor at root height (**7.38** in the den, about 8 on the apron), so `PetFloors.ok` is false and the anchor is nil. Probe: same point at root height false, at floor height true. **Smallest fix:** the four floor boxes' top `floorY+3` -> `roofY` (DenLayout lines 66, 67, 128, 129). With that change in Play 2 (not committed): the pet is in by 2 s, 22 of 35 samples in the room, 0 inside a furniture footprint; a catch-up from 110 studs lands at (-5.5, 4.5, -105.0), 2.6 from the owner, at 5.1 s; `/den off` carries it to (-6.1, 5.1, -84.0). |
| 5 | **Bars across the mouth** | **FAIL (look).** The island cave art's yellow bars (`W7_Landmarks__palette`, merged, non-colliding) still stand in the open mouth: from the lawn the den reads as a cage (05a), from inside the lawn and the pet sit behind bars (05c, 05g). Players walk through them. Fix: art (Fable/island): hide the bars when the den opens, or in step B. |
| 5 | Sign, lanterns, board, niche | **PASS with notes.** Sign under the trim (trim y 10.2 at z -100.07, sign top 10.0 at z -99.6). Mouth lantern posts on the ground (post 1 sinks .7 into the slope). Roof over every bay 15.0 to 17.6. Back wall z -114.2. **Notice board:** the walk collision under its post is 9.38 (the right jamb's slope), so the post foot is buried; the board face stands clear and reads (05a). |
| 5 | Prompts (P2) | **PASS.** 121-point grid (Play 1): never two E prompts; Race 42, Play 54, none 25. 54-point grid with the pet inside (Play 2): never two; the pet's "Say hi" nearest at 3. |
| 5 | Dash from the den (P4) | **PASS.** Gate -> picker -> Just for Fun: gather at 2.6 s with the seat, den gate prompt "Leave line" (hold .4), meadow prompt hidden; countdown 22.6, race 26.1, results 59.4, idle 65.4; the avatar stayed at (-7.5, 7.4, -105.0) throughout; after results the camera came back to it in the den (05d). |
| 5 | Stray (P6) | **PASS.** Walked out while gathering: seat dropped at **3.0 s**, toast "You left the line." (my seat was the only one, so the gather went idle). |
| 5 | Meadow pad (P5) | **Partial.** Den on, idle: text "Join race", disabled (hidden). Two-player hop not run (one client). |
| 5 | `/den off` (P7) | **PASS.** In a gather seat: moved to the doorstep (-4.4, 8.0, -87.0) at .15 s, seat dropped .36 s, toast **"The Play Den closed"**, blocker colliding, model and den prompts gone. Mid-race: moved out at .11 s, the race ran on, camera back to the avatar on the doorstep after results. Den off: meadow "Race", enabled (today's picker). |
| 5 | Deck table (P8) | **PASS.** Play -> Board mode, "Pick a difficulty" shown; back to Room at the table (-6.4, 7.4, -107.5). While waiting: "Leave the line?" with Leave / Stay in line (05f). |
| 5 | Notice board (P9, P10) | **PASS.** Opens Things to do with "The Play Den, Games inside the cave" first (05e). Its Show me pin is at (-6, 4.23, -96), the mouth. Dash row with the den on and idle: pin at the den gate (-10, 4, -105). |
| 5 | P11 to P14 | Lights as above; frame time not measured. P12: `PlayDen.ceiling()` live false, beta true, Studio true (launch project not loaded). P13: properties only (E, ButtonX, clickable). P14: tier and den open together; tier evacuation (-8.24, 8.0, -86.41), den doorstep (-7.6, 8.0, -87.0): 0.9 apart, both on the lawn. |
| 5 | **Camera in the den** | **Finding.** Standing at the table facing the back wall, the camera sat outside over the lintel and the sign filled the view (05f). After a race it came back inside, close behind the avatar (05d). P1 phone size not captured. |
| 6 | Output log | **PASS.** Known lines only (ConfigService keys, Assistant notices, EditableImage, `Player:Move`, 203785492, one BoardSnapshot drop) plus one error from my own PlayDen probe. No `[EggMachine]`, `[EggCorner]`, Den, Dash or Tier lines. |

## Captures (`studio/r12/`, Fable)

01a the machine prompt "Hatch eggs" at play distance. 01b machine mid-crank (**staged**: a Dial copy at 50 deg, the loose
eggs lifted; the den's bars show in the background). 02a reveal egg centred, 02d the Hatch eggs preview tile. 03a to 03d
Bunny glance (front mid, front close, 3/4 left, 3/4 right). 03e to 03g Bear glance (front, 3/4 left, 3/4 right). 05a den
mouth from the lawn. 05b inside: gate, niche, table. 05c inside looking out (bars, pet stuck outside). 05d player camera
in the den after a race. 05e notice board: Things to do. 05f table while waiting: "Leave the line?" and the camera
over the lintel. 05g pet inside with the floor fix (TEMP, Play 2).

At the end: Studio in Edit, StreamingEnabled false again. The Rojo plugin was disconnected and only my serve (34872)
was stopped. Rojo had synced the repo's untracked `src/*/ZZSpecs` into Studio: the 2 `ZZSpecs` folders (105 + 222)
were removed from Edit, 0 left. DenLayout.lua is back to HEAD (13,007 in Edit).
