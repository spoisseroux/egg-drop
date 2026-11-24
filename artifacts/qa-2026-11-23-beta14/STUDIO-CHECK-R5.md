# Beta 15 candidate: Studio check R5 (Opus, 2026-11-24)

Branch `feat/egg-drop-arcade-polish` from 91f867a, Studio Play on the place file (96451847774961, Studio counts as beta),
Rojo live on 34872. Before Play, Edit showed Hush, HushGreybox, HushHost, HushClient, Nest, LifeScene, GardenLife and the
ZZSpecs copies at the repo byte lengths. 24 stale ZZSpecs copies were refreshed from `scripts/` and `GardenLifeStudio`
was added (removed again at the end). Nothing was saved or published. Captures are in `studio/r5/`.

Three one-constant fixes were committed after their probes (all sanctioned by their plans; offline runner 60/60 after
each): **f5d03fa** `Nest.Spot` slid .15 along e, **47983ca** `Koi.over = true`, **aa6c0e0** Dewdrop `down` .62 -> .75.

## Blocker: the nest is never drawn on the client

`[Nest] untilT is not a valid member of RBXScriptConnection` on the first frame. `NestClient` uses `self.beat` for two
things: the Heartbeat connection (`open`, line 344-345; `close`, 395) and the speech-beat table (lines 732-733, 781,
927). `step` reads `self.beat.untilT` on the connection, throws, sets `dead` and closes. Result in Studio: no
`EggDropSleepyNest` folder, no nest prompt, no HUD chip, and no "Coming up" strip, because `TomorrowStrip.model` needs
`ctx.nest.left`. Offline specs miss it because they pass `d.step = false`.
**Smallest fix:** rename the connection, e.g. `self.stepConn`, at lines 344, 345 and 395. `clear()` (line 388) also
resets `self.beat`, which would then only touch the table. This is not a constant, so I left it for Sol.

## 1. Studio-only specs (Play, Client)

| Spec | Result |
|---|---|
| StationAttract (with the live-line row) | **PASS 9** |
| GardenLifeStudio | **PASS 4** |
| RevealStage | **PASS 22** |
| KitArrive | **PASS 15** |
| KitSurfaces | **PASS 9** |
| MenuPolish | **PASS 10** |
| DeckResults | **PASS 18** |

## 2. Probes

| Probe | Result |
|---|---|
| Nest P1, at E1 (-25.27, -9.80) | **FAIL, ring.** `W7_Stations__marble_smooth` at **2.55** (202 deg, .5 and 1.5 up). Floors, base edge, sight lines and the walk clearance passed. Note: in Edit the world isn't built, so every ray misses; run this probe in Play. |
| Nest P1, after the slide | **PASS.** Spot (-25.12, 4.07, -9.82): ring nearest 2.68; Bear spot y 4.13, sign post 4.10 and prompt 4.13, all on `W7_Architecture__marble` (root ground 4.13); base edge 2.70; three sight lines clear; hub walk clears the box by 2.13. A .30 slide also cleared the ring (2.81), but NestClient.spec then put the sign 40.56 deg off from one approach point, past the 40 deg limit. |
| Nest P2 (two prompts at the corner) | **BLOCKED** by the NestClient bug. Only `EggsSign.BrowseEggs` exists. |
| Dash P6 | **PASS.** Pad (64.5, 4.70, -21), R 4: 96 rays hit nothing; 10 stakes, worst height .13. |
| Dash P7 | **PASS.** Posts 8.5 / 21.2 studs off the east eye line and 7.3 / 12.2 off the south; both eyes see the avatar. |
| Hush P1, the pocket (blocker off) | **PASS.** Floor y 4.0 from z -101 to -113. Roof (cliff rock) at y 15.0-18.6, so 11-14 studs of headroom; the mouth's east edge has open sky. Width 11.5 at z -102 (x -12.6 to -1.1), 9 between the throat stones (x -11.5 / -2.5). Back rock at z -114.2. The mouth at z -100 is 17.7 wide (x -14.8 to 2.9), so `spur_neck_west` doesn't pinch it. The sweep script was not rerun. |
| Hush P2, streaming | `StreamingEnabled` **false** (radius 1024), so the streaming-on case can't be tested here. The model is `Persistent`. |
| Hush P3 | **PASS.** A 20 x 21 grid of downward rays found only `W7H_` parts or nothing (57 over the tunnel gap). No cloud or rock surfaces. |
| Hush P12, max zoom from home | **PASS with WorldFeel on.** The client caps zoom at **22**, and nothing of the Hush is in view from 8 lawn and plaza spots at 22 or 30. With feel off (zoom 400), wall tops show from 60 studs out (3-12 sightlines) and widely at 120 / 400. |
| Hush P4, a real crossing in | **PASS.** Walking into the trigger: fade out .33 s, moved to (-7, -10.6, -209), fade in .5 s. The Bear landed at (-7.03, -13.74, -213.92); the plan says (-7, -13.975, -214). It followed down the ramp to the floor (body y -19.58). Grade on. |
| Hush P4, crossing out | **PASS.** Player at (-7, 7.39, -108). The Bear landed at (-7.05, 4.86, -88.06), inside `room.Floor`. Grade off. |
| `/hush go` | **PASS.** Arrived at the next offset (-8.6). |
| Hush P5 (part) | **PASS.** Root forced to y -40: back at the Hush arrival in .26 s. The 60 s stand and the rail jumps were not done. |
| Hush P6, `/hush off` evacuation | **PASS** (one account). Home at (-7, 8, -86) in .21 s, the Bear beside, blocker collides, model gone, grade gone. `/hush clear` rebuilt it. |
| Hush P7, reset in the Hush | **PASS.** Respawned on the dais in 9.6 s with the Bear beside; music group back to 1, grade gone. |
| Hush P10 (part) | In the Hush the `EggDropMusic` and `EggDropAmbience` groups are at **0** (ducked). |
| Hush P8, P9, P11, P13 | Not run. P9 needs two accounts. |
| Garden life: chimes | **PASS.** `W7_Chime_1..5__palette` are separate parts, `WorldMotion` sway, each with its own pivot. |
| Garden life: lamp halos | **PASS.** The `LampOrbs` mesh centre is y 9.04 (1.48 tall), and all 7 halos are at y 9.0. Halos came on at ClockTime about 17.5 (7 of 7). |
| Garden life: Dewdrops in the crowns | **FAIL, then fixed.** The probe script hits `CollisionFidelity.Box` bounds, so its numbers are useless. Using `PreciseConvexDecomposition` clones instead, at `down` .62 an average of .85 of each image is inside the leaves, and from 8 studs none showed (capture 10). Per-stem hidden share by `down`: .62 .85, .70 .61, .75 .44, .80 .26. Hulls overstate the leaves, so I chose **.75**. Staged on Tree_14, the lower part of each fruit shows (capture 11). Fable should judge it live. |
| Garden life: koi depth | **FAIL, then fixed.** `W7_Water__water_pool` has Transparency 0, and a precise hull puts its surface at y **3.200**. The koi plates at 2.95 never showed (capture 05). Applied the plan's fallback, `over`: plates at 3.22 with the decal at .35. Staged, the koi read (capture 21). Not yet seen live after a Play restart. |
| Garden life: koi orientation | **FAIL.** Projecting each plate, the LookVector (the travel direction) ends at the **tail fins**, so the koi swim tail first. The plan's own `[check]` covers this: flip the koi-a/b/c images, or turn the plate 180 deg in `koiPose` (`CFrame.Angles(0, math.pi + sway, 0)`). |

## 3. Output log (Play)

From our scripts: one warning, `[Nest] untilT is not a valid member of RBXScriptConnection` (the blocker above). The other
lines are known: `EditableImage is not accessible`, `Player:Move ... no humanoid`, `rbxassetid://203785492` type
mismatch, the ConfigService missing keys and the Assistant version notice. `UICopy: missing key strip.title` was my own
probe. The server shows only the 203785492 lines.

## 4. Captures (`studio/r5/`)

- 01: Bear reveal, desktop.
- 02: Bear reveal, phone 844x390, from RevealCaptureFixture at t 4.
- 03: the Sill from the Hush floor.
- 04: the hollow from the Sill, with the Bear on the floor.
- 05: koi before the fix (pool opaque).
- 06: lawn patch and dapple.
- 07: path fray.
- 08: litter.
- 09: the player at the arch with the chimes.
- 10: Tree_14 at `down` .62 (no fruit shows).
- 11: Tree_14 at .75 (staged).
- 12: dusk lamps (`/hour at 2900`).
- 13: night fireflies (`/hour at 3100`).
- 14: the falls from the plaza.
- 15: the falls from the lawn.
- 16: race rope ring at gather, my Bear seated.
- 17: "Leave the race?" confirm in the race.
- 18: phone menu frozen mid-rise, about 15 px below rest.
- 19: phone menu at rest.
- 20: phone deck in-place results ("Too tall!", 1.6 s).
- 21: koi with the `over` fallback (staged).

## 5. Could not check

- The nest corner, a nest bubble, P2 and the Coming up strip: all blocked by the NestClient bug.
- The line's "Leave the line?" confirm with a queued player: solo, the gather ran straight into the race.
- Leaves in flight (emitters at rate 0 between bursts; none caught).
- Live koi and Dewdrops after a Play restart (the fixes were seen staged only).
- Hush P8, P9, P11 and P13; any sound; a real phone.

Studio is left in Edit. Rojo was disconnected in the plugin and the serve process stopped. The `GardenLifeStudio` ZZSpecs
copy was removed; the 222 + 105 earlier ZZSpecs files remain, as before.

---

## R6 recheck (Opus, 2026-11-24)

Same setup as R5: Rojo live on 34872, Studio Play on the place file (Studio counts as beta), nothing saved or published,
no ZZSpecs copies needed. Captures are in `studio/r6/`.

**Three Plays.** Play 1 ran **d90d3f8** (Edit's NestClient was byte for byte the repo file, 53,760 bytes, with
`self.heartbeat`; LifeSceneSim had `face=180`). While I worked, five commits landed on the branch (5b4a593 to 42fb0d7:
race confirm, Dewdrops skirt and matte art, dapple, Hush). Rojo synced them, so Plays 2 and 3 ran **42fb0d7**. Items 1,
2, 3 and 5 are from Play 1; item 4 is from Plays 1 to 3.

| # | Check | Result |
|---|---|---|
| 1 | Output log | **PASS.** No `[Nest]` line in any of the three Plays. The nest draws at the Hatch eggs corner: 26 parts in `EggDropSleepyNest`, mound at (-25.12, 4.34, -9.82), `NestPrompt` "Tuck in" (reach 4.5) and the HUD chip "Egg 8 h" (03, 07). Only the known lines remain (ConfigService keys, EditableImage, `Player:Move`, 203785492). The new R5 uploads first logged "content representation is being generated", and that cleared. |
| 2a | Nest from the arrival path, 8 studs | **PASS** (03, at 8.16 studs). One nest billboard: "Bear's egg naps for 8 hours. Come back to hatch a gift." The need bubble was hidden there. |
| 2b | One nest bubble only | **PASS.** Within 12 studs only `SleepyEgg.Label` has text. The station icons carry no words. |
| 2c | P2: two prompts at the corner | **PASS** (keyboard; pad and phone not run). 13 points on and around the line from the station prompt to the nest prompt, each facing 0/90/180/270 (52 samples): **exactly one** prompt was shown every time. The nearer one wins: nest 2.0 vs station 3.3 gives NestPrompt, nest 3.3 vs station 2.0 gives BrowseEggs. At the 2.6/2.6 midpoint the Bear's own `PetInteraction` showed. No flicker, so the nest reach stays 4.5. |
| 2d | "Coming up" strip on deck results | **PASS.** After a full field round (45 drops, `RoundOver`), `InPlaceResults.ComingUpStrip` shows "Coming up": **Egg in 7 h 53 m**, Stamp 1 in 22 h 18 m, 2 ready to claim (05). |
| 2e | The strip at 844x390 (host trick) | **PASS** (06). The strip is at (233, 327) and is 417 x 48 inside the 844 x 390 frame. The stamp chip shortens to "22 h 18 m". |
| 2f | Tapping the egg chip | **PASS.** From 27 studs away, after a second round: the deck closes (Mode Room) and `EggDropShowMe` lays the Show me pin **"Napping egg"** at the nest prompt (-26.79, 5.13, -7.83) (08). |
| 2g | Hatch eggs "Napping egg" row | **PASS** (04). The top row reads "Napping egg / Hatches in 8 h", quiet, with no price. Focus starts on Toy Egg. A tap on `NestRow` closes the shop. |
| 3 | Koi head first | **PASS.** For each plate, the dot of LookVector with its 1 s travel is **-0.99, -1.00, -0.98**, so the plate turns away from travel, which is the R5 fix. From above, with travel pointing up in the frame (10, then 11 a few seconds later), the heads lead. From the bank (12) the koi read, with a rise ring. Koi 1 and 2 were side by side in both samples; they may just have crossed paths, so this is worth a look in the review. |
| 4a | Live Dewdrops hanging | **Seen, but they barely show at 42fb0d7.** Play 1 (d90d3f8, previous art id 126842815810909): a whole orange fruit hangs under the crown (13), but no stem shows at 60 px. Play 2 (42fb0d7, matte art 119564411112297, `skirt` .60): from 6 studs below, only a **thin brown crescent** of each fruit shows under the skirt (14), and from the player camera nearly nothing (15). The stem never shows (it is about 0.6 px at this size). Fable should judge whether `down` .75 with the skirt pull-in hides too much. |
| 4b | A fruit falls | **PASS.** Falls in ordinary gusts every 30 to 60 s, for example Dewdrop4 from (18.1, 9.2, 42.3) to rest at (19.4, 5.4, 41.8) in 0.8 s. The big breath was not forced (there is no command): breath b5985010 arrived at t 123 s and a fruit fell on its rise (t 121). A fruit rests about 32 s, then goes back to the pool and regrows on the stem. |
| 4c | Pet snack | **NOT SEEN** (see below). |
| 5 | Fresh save, Bear greeting | **PASS with mouse.** Fresh Play save, welcome skip, real Bear reveal, Meet (00). With pet focus closed, the **hand bubble** shows over the Bear about 4 s later (01; anchor 4.47 above the body, `AlwaysOnTop`). A real mouse click on it counts (`Taps` 1) and opens the greeting focus. After Back, the **ball bubble** shows within 3 s, with paw prints toward Hatch eggs (02). A click on the ball counts (`Taps` 2) and restarts the trail. Real touch is **unverified**. In Play 3 the hand bubble showed right after Meet, with no focus step. |

### 4c. Why no snack (numbers)
Play 3 (42fb0d7), with the need bubble hidden ("away" after 20 s idle, so the bubble did not make the pet busy). Two
fruits rested near the Bear:
- t 278 to 310: Dewdrop1 at rest at (19.8, 5.1, 41.5). The Bear was at 2.3 to 4.3 flat studs from it, wandering and pausing. No turn, no trot, no heart.
- t 317 to 348: Dewdrop1 at rest at (22.2, 5.5, 43.9). The Bear walked to 0.2 studs of it and then the fruit sat at (25.4, 4.95, 43.2): it was **batted**, not eaten (no heart, the image never shrank, the cooldown never showed).
- Play 2: a fruit rested 5.7 to 7.0 studs from the Bear; no snack.

The switches are on (`Alive` snack/life/scene ceiling and on, AliveLevel 0). The gate that refuses can't be seen from
outside: `Pet.free` reads the server actor's behavior and action, and `isBusy` reads clientUI. **Smallest next step**
(not a one-line fix, so I left it): a Studio-only attribute on the Bear with `LifePet:notice`'s refusal reason (busy,
not free, notice distance, leash, cooldown), then one Play. Note the header says `notice=8`; the plan's 2c table says
12. **Harness caveat:** when an `execute_luau` spans a camera change (Meet), the Assistant puts `CameraType` back to
Scriptable. The garden camera then stays frozen at the arrival, and the garden reads as a greeting. In Play 3 I undid
that with E and Back before the snack test, but it may have skewed Play 2.

### Studio notes
- `screen_capture` with no camera draws the Assistant's own view, not the player's. For live UI and billboards I used computer-use screenshots of the viewport.
- `user_mouse_input` with an `instance_path` into a BillboardGui (`EggDropNeedBubble.Hit`) sends the input, but `Activated` does not fire. A real computer-use click on the bubble does.

Studio is left in Edit; Rojo is disconnected in the plugin and the serve process stopped. No src change in R6.

---

## R7 snack and fruit (Opus, 2026-11-24)

**2c3cd41**, Rojo live on 34872. Edit held feat's scripts, at the repo's LF byte lengths: LifePet 15,549, GardenLife
55,861, Client.RoomView 81,716, Client 309,494. One Studio Play on the place file (Studio counts as beta): fresh save,
Skip tutorial, Quit to garden, Meet Bear, Back. Then I stood still on the lawn at (22.7, 8.0, 48.1), by the tree whose
fruit lands near (21.5, 5.1, 41.0). Nothing was saved or published. No src change. Captures are in `studio/r7/`.

| # | Check | Result |
|---|---|---|
| 1 | Dewdrops hang below the crowns | **PASS.** From the lawn, with the camera 6.5 high: at 10 studs from the west crown (`W7_Kit_Crown_Blossom`, centre (-11.6, 11.55, 34.6), AABB bottom 8.90), two fruits hang fully below the crown with stems. The right one's stem clearly reaches the crown (01). At 8 studs from the east crown (73.9, 11.84, 12.7), three fruits hang fully below it with stems (02). The image centres are at Y 8.82 to 9.07 and the billboard is 1.1 x 1.5, so the bottoms are at about 8.1 to 8.3. Fable should judge the look. |
| 2 | Pet snack | **PASS, 3 of 3.** In 300 s, three fruits came to rest within 8 studs, each after the 90 s cooldown, and the Bear ate all three. Frame samples of snack 2: **turn** .3 s (yaw -128 to -135); **pause** .4 s; **trot** 1.8 s over 6.3 studs (3.5 studs/s), stopping .87 to .91 from the fruit; **three nibbles** in 1.05 s, with the fruit image shrinking 1.10, then .71/.79, then .45/.50; **hop** to +.35 and back in .3 s; **one heart** rising from Y 5.65 to 6.65 over .8 s and fading in the last .3 s. Then 1.5 s content and a trot back to the server's sample. No `aborted:` value appeared. Snack 3 (03) shows the content face at the fruit, which the trunk hides. |
| 2a | Every `SnackWhy` value seen | `refused: a need bubble` (at spawn); `refused: following a moving owner`; `refused: fruit N studs off (notice 8)` (N from 61 to 103: every resting fruit on the island is asked about, so this cycles every 2 s); `refused: busy with investigate/wander`; `snack: going (7.6 / 7.2 / 7.1 studs)`; `snack: ate it`; `refused: cooldown N s` (counting down from 83). |
| 3 | Output log | **PASS.** No LifePet, GardenLife or RoomView line. Only the known lines appeared (ConfigService keys, EditableImage, `Player:Move`, 203785492, the Assistant version notice), plus one `BoardSnapshot ... 1 events dropped` at join and my own probe's `AssistantCommand:4` error. |

**Why R6 saw no snack:** it was the park-branch actor (fixed in e4544cf). R6's "batted" fruit was the pet walking
through it with no actor. With the actor passed, the gate passes as soon as the pet is resting or pausing.
**Notes:** all three fruits fell to nearly the same spot (21.4 to 21.6, 40.5 to 41.5), as the deterministic Grove
places them. `screen_capture` with a camera did not freeze the player camera (`CameraType` stayed Custom).

Studio is left in Edit; Rojo is disconnected in the plugin and the serve process is stopped.
