# Beta 13 candidate: Studio recheck R2 (Opus, 2026-11-23)

Branch `feat/egg-drop-arcade-polish` at 9614eaa, Studio Play (place file 96451847774961, Rojo live on 34872). Before Play, Edit showed `DashIcons` Source holding `123828042465302` (spotWedge), and the ZZSpecs copies of UICopy, AeroWorld and AeroFalls were refreshed from `scripts/` (lengths match the repo, CR stripped). Fresh Studio save: Bear through the welcome skip, then the garden. Nothing published or saved. Captures are in `studio/r2/`.

## 1. Specs that failed in R1

| Spec | Realm | Result |
|---|---|---|
| AeroWorld | Client | **PASS 27** |
| AeroFalls | Client | **PASS 22** |
| UICopy | Client | **FAIL**: `onb3.nest.chipHours leaves a placeholder: Egg {hours} h` |

UICopy still fails, on the next stale sample key. The `band=` fix landed, but `onb3.nest.chipHours="Egg {hours} h"` and `chipMinutes="Egg {minutes} min"` (UICopy.lua:223, from 3f13722) also need `hours=` and `minutes=` in the spec's `sample` table (UICopy.spec.lua:13 to 22). With `hours=8,minutes=40` added to the Studio copy only, UICopy **passes 9**. No other placeholder is missing (checked every `{name}` in UICopy.lua against the sample). The repo spec is unchanged; the Studio copy is back to the repo version.

## 2. Captures and look checks

| Item | Result | Evidence |
|---|---|---|
| Dash HUD, desktop: both key caps on screen | **PASS** | 06, 05. Caps are 20 tall with 11 pt text. On the 2107 wide viewport, Shift sits at x 116 and Space ends 116 from the right edge. The avatar's own jump button is not shown during the race. Minor: the cap fill is 0.86 transparent, so "Space" is faint over the bright water in 06 |
| Dash picker stage: wedge and glow, no staircase | **PASS** | 04. One soft wedge (id 123828042465302, `ImageTransparency` .90, loaded) and no stacked bars. Glow: `firefly-dot` 132656608030953, #FFE14D, .55, 237.5 x 50 (190 x 40 at UIScale 1.25), behind the pedestal. It barely shows at this size, and the state is as specified |
| Line-up: 4 racers fill the frame, posts | **PASS** | 05 (countdown 1). The row spans about 60% of the width; neither gate post is in frame |
| Dash results, desktop: pet framing | **PASS** | 07. The whole pet, ears included, stands on the podium inside the stage, with headroom (prizes off, 4th) |
| Dash results, phone 844x390 | **PASS** | 08. The whole pet is in frame |
| Deck results, phone: no overlaps | **PASS** | 12, 13. Pane 121 wide: Power and Energy carry the 14 pt "4" disc, 17 right of the gain. The wallet chip (y 227) sits 6 below the end of the rows (221), so nothing draws under it. Desktop: 11 |
| Nest sign from the plaza | **PASS** | 01. "Bear's egg" reads square-on from the plaza's middle |
| Nest sign from the arrival path | **FAIL (small)** | 02, 03. The Back face now carries the words, but the post stands in front of that face and covers the "e" of "egg" ("Bear's / gg") |
| Waiting pad (66, -21) with the avatar | **PASS** | 09. On the pad, the follow camera has a clear line to the avatar and the gate post is off to the right. 10 is a forced camera from due east: the tree at (72, -22) stands beside the avatar. The game camera would not choose that view |
| Butterfly close-up: spindle body | **PASS** | 21, 22. The body is #33271C, 0.09 x 0.08 x 0.42, with a Sphere SpecialMesh, a tapered spindle with no flat faces. From above it is about 0.58 of the wing's depth, and there is no gap at the wing roots |
| Birds, front and side | **PASS, one note** | 14 to 20 (Ember, Slate, Moss). Matte Sand body and head, dark eyes with no shine, an ellipsoid beak, the breast decal, the Moss head #6E7A4A, and wings 0.04 x 0.95 x 0.66 whose tips reach the tail. Note for Fable: side-on, the tail plate reads as a thin spike (18, 19) |

How the bird and butterfly shots were taken: no bird was out during the session. Every bird and butterfly part sat in its parked pose, so a close-up needs a staged copy. These are clones of the live parts, with their real sizes, colours, materials and decals, posed with `LifeSim.birdParts(root,"sit")` and `LifeSim.butterflyParts(root, 35°)` on the lawn at (-22 to -16, 12). They are not live flight.

**Other things seen**
- In race 2 the Dash HUD place pill still showed behind the results sheet, and it read "1st" while the sheet said 4th (08, top right). In race 1 it read "4th" (07). Minor; it may be a stale pill under the sheet.
- On the 121 wide phone payout pane, "Round win" wraps to two lines (12).

## 3. Output log
No errors or warnings from our scripts in about 25 minutes of Play: 3 specs, 2 Dash races, a deck round, and the staged shots. The only lines were:
- Engine noise: ConfigService missing keys, and "Asset content representation is being generated".
- `rbxassetid://203785492` "Asset type does not match": a long-standing default asset, also listed in older build notes and not in `src/`.
- `UICopy: missing key no.such.key`, which the spec causes on purpose.
- My own two execute_luau typos.

## 4. Could not check
- Live birds and butterflies in motion: the close-ups are staged copies.
- AlwaysOnTop billboards: `screen_capture` does not draw them.
- Stats On, Time Trial, and a top-3 finish with prizes (medal, confetti, Earned row): MCP keys don't reach the unfocused window, so the pet always finished 4th.
- The real after-Done camera. `execute_luau` resets the camera type after each call, and my character stood at (66, -18.4) for race 1. The pad check (09) is the follow camera with the avatar standing on the pad centre.

## Captures (`studio/r2/`)
01 nest sign from the plaza · 02 from the arrival path · 03 the Back face with the post across "egg" · 04 Dash picker, desktop · 05 line-up, countdown 1 · 06 race HUD, desktop · 07 and 08 Dash results, desktop and phone · 09 waiting pad, follow camera · 10 the pad from due east · 11 deck results, desktop · 12 and 13 deck results, phone (13 scrolled to the stat rows) · 14 the three birds from the front · 15 to 17 each bird, front · 18 to 20 each bird, side · 21 butterfly, side, close · 22 butterfly from above.

Phone captures use the 844x390 host trick, cropped at (20, 20) and rescaled from the 0.91-scale capture.
