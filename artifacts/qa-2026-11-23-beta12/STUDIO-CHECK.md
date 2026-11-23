# Beta (12) fixes: Studio check (Opus, 2026-11-23)

Branch `feat/egg-drop-arcade-polish` at c6b16ef, Studio Play (place file 96451847774961, Rojo live), fresh Studio save: Bear through the welcome skip, then the garden. Nothing published or saved.

## 1. Studio-only specs

| Spec | Realm | Result |
|---|---|---|
| WindClient | Client | PASS 26 |
| PetFocusUI | Client | PASS 13 |
| BondView | Client | PASS 12 |
| DeckResults | Client | PASS 18 |
| LocalizationFit | Client | PASS 3 (0 clip, 0 grow, 54 truncated, 0 English clips, 0 screens failed) |
| DashCourse (not in the offline runner) | Server | PASS 13 |
| UICopy | Client | **FAIL**: `dash.band leaves a placeholder: {band} · Dash level 25` |
| AeroWorld (not in the offline runner) | Client | **FAIL**: `AeroWorld.spec.lua:321 assertion failed` |
| AeroFalls (offline only when named) | Client | **FAIL**: `AeroFalls.spec.lua:506 assertion failed` |

All three failures are stale or Studio-only spec checks, not game bugs:
- UICopy: `dash.band="{band} · Dash level {level}"` (UICopy.lua:615, added in 69e739d) needs `band=` in the spec's `sample` table (UICopy.spec.lua:13).
- AeroWorld:321 still expects `poolSkin.Transparency .5`; 45e32a9 set `water_pool` to `#3BA3BE`, `.15` (WorldAero.lua). Update the spec's pool values.
- AeroFalls:506 compares `e.Size.Keypoints[1].Value==.6` exactly. A real NumberSequence stores float32 (0.6000000238), so it fails in Studio and passes offline on the mocks. Use `near(...)`.

All other `*.spec.lua` changed since 0015d0a are in the offline runner.

## 2. Output log
No errors or warnings from our scripts in about 25 minutes of Play: specs, two `/hour` changes, five Dash races and a deck round. Only engine noise: ConfigService missing keys (expected in Studio), "Asset content representation is being generated" for fresh uploads (the Dash icons were blank for the first seconds, then loaded), and `rbxassetid://1` from spec fixtures.

## 3. Behaviour checks

**Passed**
- `/catchup on`: after teleporting 51 studs away, the pet hopped to 4.7 studs from me 2.0 s later (snapshot `hop.seq` 1 to 2).
- `/finds now`: a find spawned 21 studs from the player at once.
- Nest at (-17.5, -2.5) in the plaza: a woven nest with a straw bed and egg. The sign reads "Bear's egg", and the inside line is "Bear's egg naps for 8 hours. Come back to hatch a gift." The pet walked round it, never closer than 2.6 studs to its centre. The HUD chip reads "Egg 8 h".
- Dash:
  - Pad prompt, mode picker, Just for Fun, and a countdown with four racers spaced evenly (no overlap).
  - Name tags for every racer were enabled and on screen through the countdown (Teacup, Bear, Dumpling, Detour), checked by instance state.
  - HUD: drawn Dash and Jump icons, place pill beside the strip.
  - Results: time count-up, top three plus you, "See you tomorrow" strip, Race again, Done (back on the pad, avatar shown again).
- `DashCamera.LineupBack`: clear rays from all four lanes to the camera, no geometry within 1.5 studs of it.
- Butterflies:
  - The wing angle is continuous: a flap with glides, no two-pose snap. Studio ran at 15 fps while unfocused, so per-frame steps were 9°.
  - At `/hour at 2870` they handed off one by one as daylight fell under .30: glow on, wings faded over about 1.3 s, 1.5 s apart.
  - `/hour at 2900` (a jump past dusk) just fades them out.
- Leaves: over 25 s with me standing on the rotunda (67 emitter moves), every emitter stayed at least 11.8 studs from (-60, 50).
- Birds: a songbird landed on a lime crown and did not move through gusts of 0.69 to 0.83, then left about 10 s later.
- Deck results (strip v2): the strip runs full width under the panes, and the four buttons are compact (Hatch and Leave side by side on phone).

**Problems**
1. **Desktop Dash HUD: the Jump key cap ("Space") is cut off at the right screen edge**, and the "Shift" cap is barely visible next to the energy bar (11). On phone size both show (12). See the key cap anchoring in `src/client/DashHud.lua`.
2. **Dash results: the pet's ears are cut off by the top of the portrait** in every results sheet, desktop and phone (13, 14, 16). See the portrait camera or podium hop height in `src/client/DashSheets.lua`.
3. **Deck results on phone: the Lv 4 and Lv 2 chips cover the "+58" and "+18" stat gains, and the wallet "25" chip covers the Energy row** (25). See the payout pane in `src/client/DeckResults.lua`.
4. Waiting pad: after arriving or pressing Done, the default camera puts the red and white gate post right across the avatar (09, 18). This is minor.
5. Nest sign: it faces west, away from the plaza, so people crossing the plaza see its edge or back (06). See the sign yaw in `NestClient` or `NestSpot`.
6. For Fable: up close, the butterfly body is a plain dark box (19).
7. The first catch-up (right after `/catchup on`, landing near (30, 50)) took more than 5 s, and its hop was only seen later. The second was 2.0 s. Not reproduced.

## 4. Could not check
- **Studio `screen_capture` does not draw AlwaysOnTop BillboardGuis** (proved with a test billboard). So the countdown names, the firefly glows and the nest egg's pill are verified by state only, not by picture.
- The poof effect itself (too quick to catch).
- Stats On and Time Trial races, prizes and the podium medal: the pet finished 4th each time, because MCP keys can't reach the unfocused Studio window, so it never jumped.
- Bars following the hovered tile (MCP hover did not register).
- The onlooker "Racing" pill (needs two players), the tip chime, the U2 pet tag (needs the focus key), and `/freshsave` (it kicks the player).

## 5. Captures (`studio/`)
01 garden arrival and egg chip · 02 `/finds now` sparkle and butterfly · 03 pet after catch-up · 04 nest with the pet walking round it · 05 nest sign front · 06 nest sign edge-on from the plaza · 07 and 08 Dash mode picker, desktop and phone · 09 waiting pad with the gate post in the way · 10 and 15 line-up camera (countdown 3) · 11 and 12 race HUD, desktop and phone · 13, 16 and 17 Dash results, desktop (17 mid-staging) · 14 Dash results, phone · 18 after Done · 19 butterfly close-up · 20 songbird on a lime crown · 21 the rotunda leaf run · 22 night at `/hour at 2900` · 23 the dusk hand-off (glow not captured) · 24 and 25 deck results, desktop and phone.

Phone captures use the 844x390 host trick, cropped and rescaled from the 0.91-scale capture.
