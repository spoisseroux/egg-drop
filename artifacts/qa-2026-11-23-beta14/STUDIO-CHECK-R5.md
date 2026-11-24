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
