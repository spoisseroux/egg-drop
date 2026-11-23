# Beta 14 candidate: Studio check R4 (Opus, 2026-11-23)

Branch `feat/egg-drop-arcade-polish` at 56910e4 (Fable R3 fixes merged), Studio Play (place file 96451847774961, Rojo live
on 34872). The ZZSpecs copies of KitArrive, KitSpring, KitSurfaces, MenuPolish, WorldDressing and UICopy were refreshed
from `scripts/`. Before Play, Edit showed every copy at the repo length (CR stripped), `LifeSim` and `GardenLife` holding
the `WedgePart` tail, `TomorrowStrip` at 27032 (holds `questsReady`, `resetWords`), `DeckKit` holding the R3 round-key
`PressScale`, and `Shared.UICopy` holding `stampInHM` and "ready to claim". Fresh Studio save: Bear through the welcome
skip, then the garden. Nothing published or saved. Captures are in `studio/r4/`.

## 1. Studio-only specs

| Spec | Result |
|---|---|
| KitArrive | **PASS 14** |
| KitSpring | **PASS 21** (all cases ran; 43 s) |
| KitSurfaces | **PASS 9** |
| MenuPolish | **PASS 10** |
| WorldDressing | **PASS 6** |
| UICopy | **PASS 9** |

The R3 failures are gone: KitSpring no longer stops at `disabled mid-release`, and the KitSurfaces, MenuPolish and
WorldDressing timing and float32 cases pass with the Studio flags as they are.

## 2. Output log

No errors or warnings from our scripts. Lines seen: ConfigService missing keys, the Assistant plugin version notice,
"Asset content representation is being generated" for the R2 flower ids at start, `rbxassetid://203785492` type
mismatch (long-standing), `EditableImage is not accessible` (JellyLCD, old), `Player:Move called, but player currently
has no humanoid` (at start), the KitSpring spec's three deliberate throws, `UICopy: missing key no.such.key` (on
purpose), and the Assistant camera-type reset notice.

## 3. Checks

| Item | Result | Evidence |
|---|---|---|
| Round key press (Back/Help) | **PASS** | 01 to 04. Egg shop Help key held with `user_mouse_input` mouseButtonDown: `Disc.PressScale` 1 to .942, .903, .884, .880 in about 50 ms, held at .88 (Disc 52.8 to 46.5 px). `KeyLip` and the hit rect stay 52.8 px, so the cream lip shows as a ring round the smaller disc (04). Release off the key: .896, .931, .974, 1.006, 1.031, **1.041** peak, .986 low, rest 1.000 about .55 s after release. Under the 1.12 clamp. `Kit.FaceOn` is true in Studio; all 10 round keys found (egg shop, faceplate shop, quest log, wardrobe, report, deck picker) carry the PressScale |
| Bird, 8 studs, perched | **PASS** | 05 front, 06 side, 07 three-quarter, with zooms 09a to 09c. Live pool parts match the R3 table: Body .50 x .50 x .74, Head .38, Beak .14 x .12 x .26 #E2A548, Eyes .09, Tail WedgePart .26 x .10 x .44, Legs .03 x .16 x .03 in the beak colour. Front: round dark head, bright round beak in the middle, both eyes, rust breast, two legs; it reads as a small bird beside the Bear. Side: upright teardrop, head on top, short bright point forward, solid tail wedge in line with the back, one leg showing (the other is behind it). Three-quarter: all of that plus the wing file. Note: from the front the folded wing tips stick out a little either side of the body (09a) |
| Bird in flight | **PASS, staged** | 08, 09d. Slate clone posed with `birdParts(root,"fly",0,40 deg)`: body level, legs not drawn, beak and tail wedge read side-on. Live birds were all parked (Y 4096) the whole session, so this is not live flight |
| Leaf beside a .5 stud cube | **PASS on width; leaf A at the line on height** | 10, 11. Live emitter keys match Fable's 4b table exactly: A {.11, .165±.03, .15}, B {.10, .145±.02, .13}, petal {.075, .12±.02, .105}; LightEmission 0 on all three. Clones frozen at 1 s against a plain backdrop, 3 studs from the camera (cube front face 110 px at 2.75 studs, so 202 px/stud at the leaves). Real keys (10, random envelope): A .23 x .22, B .16 x .23, petal .19 x .19 studs. Fixed at peak size (11): A .23 wide x .25 to .27 tall, B .13 x .23, petal .17 x .20. The drawn leaf's long side is about **1.5 to 1.65 x Size** (R3's 1.45 was a little low). Fable's pass line (no wider than half the cube, .25): every leaf is narrower; leaf A's long side sits at .25 to .27, and with its +.03 envelope can reach about .30 |
| Leaves beside the pet | **for Fable** | 12, 13. The same three frozen at the Bear's head height at about 5 studs: leaf A reads at roughly half the cube's width and well under the Bear's head; the petal is a small cream oval. Against the bush line (12) the green leaves nearly vanish; against the sky (13) they read |
| Petal colour | **note** | The petal emitter colour is **#FFF6C2**, brighter than Fable's cap of #F1E6C8 (her 4b [check]). LightEmission is 0 |
| "Coming up" strip, quest ready | **PASS, one order note** | 14, 15. After a deck round (Tidy win, Chain 4 done): chips "1 ready to claim", "Egg in 7 h 56 m", "Stamp 1 in 6 h 56 m". The quest chip has the **#FFC14D 2 px** outline; the others are #15143A 1.5 px. Stamp text is white (#FFFFFF, the same as the egg chip) with only the Star icon gold. **Order:** the ready quest chip sorts **first** (the model puts every ready chip ahead), where Fable's 5.1 says it "sorts after egg and stamp" |
| "Coming up" strip, nothing ready | **PASS** | 16, 17. Claimed the quest over `HatchRequest questClaim` with the results still open; within a second the live pass changed the chip to "2 quests to go" with no outline, in normal order: egg, stamp, quests |
| Stamp line wording | **PASS** | "Stamp 1 in 6 h 56 m", then "6 h 55 m", the same h/m format as the egg chip beside it (reset was 24886 s, 6 h 54.8 m, so both round the minute up) |

How the bird and leaf shots were taken: all birds were parked. The birds are clones of the live pool parts (real sizes,
colours and decals; wings at Transparency 1 as live) posed with client `LifeSim.birdParts` beside a clone of the Bear on
the lawn at (-20, 12), with a magenta .5 stud cube. Camera positions were set per capture, 8 studs from the bird (5 to
6 studs in 12 and 13). The leaves are clones of the live emitters (speed, spread and rotation zeroed, lifetime 10)
fired with `:Emit(1)` and frozen with `TimeScale = 0` after 1 s, near the peak key.

## 4. Could not check

- Live bird flight and landing, and real falling leaves in real time (no bird left its parked slot this session).
- Hearing anything (the unfocused window plays no audio).
- A real touch press on a phone, and phone (844 x 390) captures of the strip.
- The strip's egg-ready gold and boing, and `stampReady` (the egg was 7 h 55 m out, stamp 6 h 55 m).

## Captures (`studio/r4/`)

01 egg shop round keys at rest · 02 Help key held (.88) · 03 and 04 the same, 3x zoom · 05 bird front at 8 studs ·
06 bird side at 8 studs · 07 bird three-quarter at 8 studs · 08 bird in flight, side, 8 studs (staged) · 09a to 09d
zooms of 05 to 08 · 10 leaves A, B and petal frozen beside the .5 cube, real keys · 11 the same at fixed peak size ·
12 leaves and bird beside the Bear and cube · 13 leaves beside the Bear against the sky · 14 deck results strip with
"1 ready to claim" · 15 its 2x zoom · 16 strip with nothing ready · 17 its 2x zoom.
