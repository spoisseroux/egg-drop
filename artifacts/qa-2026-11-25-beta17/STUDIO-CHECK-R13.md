# Beta (18) candidate: Studio check R13 (Opus, 2026-11-25)

`feat/egg-drop-arcade-polish` at **4bf14d02**, then **84379c68** (my one-line fix, below) for Play 2. Rojo on 34872,
Studio 53800d7d (the beta place file), streaming off (as the place). Before Play, Edit held the repo's LF byte lengths
for EggMachineClient 41,978, HudChips 3,390, NestClient 81,182, StoneBuilder 4,771, ParkHollowMount 7,922, ParkLayout
27,438, DashFete 9,448, DashMount 10,596, BoardAudio 26,216, FeatureFlags 9,107, PetFollow 9,763, TierHost 10,250,
client init 325,159, server init 153,336. Two Plays, fresh save each (Bear by the welcome remotes), 140-Star jars from
`EggDropStoreTestGrant`. Nothing saved or published; place 96451847774961 untouched. Captures in `studio/r13/`.
At the end: Play stopped, Studio in Edit, my serve stopped, the 2 synced `ZZSpecs` folders removed from Edit (0 left).

## Results

| # | Check | Result |
|---|---|---|
| 1 | Console | **PASS.** Both Plays, start and after every step: only the known lines (ConfigService keys, Assistant version, BoardSnapshot drop, EditableImage, `Player:Move`, 203785492) and errors from my own probes. No `[EggMachine]`, `[Tier]`, `[Dash]`, Den or Hollow lines. |
| 2 | Capsule shot at the machine (`/onboard capsule on`, 7.7 studs off) | **PASS.** Times from the click (confirmation +.09): `screen_tuck` .09, Hatch eggs panel slides off (HueEggView Y 8 to 827 by .32), camera to Shot A by .33 and held; 5 clicks .40 to .88 (pitch steps), `egg_tok` .20/.80, `crank_clunk` 1.00, `egg_roll` 1.05, DropEgg y 5.23 to 4.70 over .40 s, `land` 1.45, `cup_shine` 1.60, `screen_rise` 1.85, panel back at Y 8 by 2.15, reveal clock (`egg_wobble`) 2.30. Spec deltas all within .02 s. Shot A camera 9.8 in front, 1.5 to the side; Shot B 5.3 in front, 2.05 to the side (spec 5.5 / 2.0). Camera holds Shot B under the reveal, the DropEgg fades under the panel; character ghosted (LTM 1) during the shot. Same timeline three times (Toy x2, Customization). |
| 2 | Space during the shot | **PASS.** Two Spaces at 1.20 / 1.48 on a first Customization drop: `gameProcessed` true (sunk), no jump, no state change, no skip (first of a type). |
| 2 | Skip on a second drop of a type | **Not shown.** Space ~.4 s into the 2nd Customization shot: the full schedule still ran (clunk +.91, land at the normal time). Click-skip not tried. Needs a recheck (see Findings 4). |
| 2 | Camera returns | **PASS.** Store/close: CameraType back to Custom at the player's camera, LTM 0, dock back. A refused Hatch another gives the camera back in .35 s. |
| 2 | Pocket version (34 studs off) | **PASS (sound/camera).** Camera stays Custom; clicks 0/.12/.29, clunk .42, roll .45, `land` .73 after the first click (spec 0/.15/.30/.45/.47/.75); reveal follows. The well egg's drop not captured. |
| 2 | Machine sounds | **PASS.** All 11 BoardAudio machine ids: one voice each, `IsLoaded` true, TimeLength .08 to .60. |
| 3 | Peek (E at the nest, egg tucked) | **PASS.** Egg (`SleepyEggBottomShell`) lifts .134, tilts 8.2 degrees; GiftPeek tile shows; no card. |
| 3 | "?" opens the card | **PASS.** Real click on the pill's "?" opens "Napping egg"; `MouseBehavior` Default; Got it closes it. |
| 3 | Esc / E on the card | **FAIL (minor).** Backspace closes. Esc opens the Roblox menu (Roblox reserves Escape; the card stays). E at the nest **opened the Bear's pet focus behind the card** (Findings 3). |
| 4 | HUD | **PASS.** In the arrival park the rail reads **"Play date 0/3 · +4 ★"** (date beats the egg clock); "Pets playing" appears nowhere; outside a park the rail shows "Egg 8 h". Flat bubble icons: all 6 `IconIds` `IsLoaded` true; the live hand bubble draws the flat hand (04b). |
| 5 | Hatch reveal shadow | **PASS with a note.** Wobble Top: one soft shadow under the tip (05a). Bone: a small shadow right under the bone **and** a second, wider ellipse lower down (05c), for Fable. |
| 5 | Egg-well glow | **PASS at one size.** Egg, Bloom1, CrackGlow, EggShadow3D, GroundShadow all centred at x 1259.9 in a 508 px well. Second window size not tried (no resize from MCP). |
| 6 | River stones walk | **PASS.** Kerb to kerb (x 14 to -4.2) with MoveTo, no Jumping/Freefall, root y 7.23 to 7.89. Colliders top 3.97 (stones 4.00), 2.9 across; gaps .1. |
| 6 | Carved | **PASS.** 8 of 8 river stones are PartOperations (0 cylinder fallbacks). Look: from the bank the row, its wet bands and landings read as one grey dry causeway across the river, not stones in water (06a, 06b; Findings 6). |
| 6 | Dash fete set | **PASS.** 51 parts: posts, feet, caps, header, start/finish flags, guy stakes and flags, rosettes, sign, 8 lane stones. Flag bottoms: start 15.05, finish 10.44 (spec 9.6 or more over the lanes); guy flags 7.46 sit outside the lanes. No flag in two race-camera frames (10a). |
| 7 | The Hollow probe | **37 FLAGs** (all below). Hollow is `PetPark_grove`, centre (-42, -51), r 14, switch on. Pets in the Hollow's slots not run. |
| 8 | Cliff path walk | **PASS.** MoveTo along all 49 centre-line points, foot (-20, 4.6, -88) to the terrace (-71.8, 31.9, -60.2), 7 s, never stuck. |
| 8 | Den prompts | **PASS.** Board: Things to do opens ("The Play Den" first, 08a). Table: Play goes to Board mode. Gate: Race opens the picker (Time Trial run). All three are disabled while a menu is open, which is correct. Pet "Say hi" enabled elsewhere. |
| 8 | `/den off` | **PASS.** From the table (-7, 8.9, -114.5) to the doorstep (-7.0, 8.0, -87.0) within .5 s; Den_on false. |
| 8 | `/tier off` | **PASS twice, FAIL once.** First try, standing on the terrace (-71.8, 31.9, -62) after the walk: not moved in 3 s, although the server saw `Tier.onIt` true and the gates built. Two retries: moved to (-14.0, 8.1, -79.0) / (-12.4, 8.1, -78.7) within .5 s. Not reproduced (Findings 5). |
| 9 | Floating pet (U8) | **Partial PASS.** The pet does not go up the path (by design: `Tier.covers` blocks the path off the lawn and the terrace). With the owner on the terrace for 15 s the Bear waited on the lawn at (-12.3, 5.2, -79.8), never in the air; no Set down arrow (`CarrySetDown` hidden). The carry-up variant (Pick up, walk up, Set down) not driven: E at the Bear was taken by its need bubble. |
| 10 | Race song | **PASS.** Time Trial: `EggDropAmbient_race_song` plays, TimePosition +1.00/s (0 to 34.5), effective volume .105; garden music (`EggDrop_Music`) ducked to 0. At the finish the song jumps to the finish section (tp 3.6), fades (.037) and stops 4 s later. Garden music stays at 0 while results show (about 20 s), then is back at .088 once they close. |
| 11 | Perf (garden, `/alive all on`, finds, hour, tier, feel) | 361 frames over 6 s: mean **16.66 ms**, p50 16.63, p95 18.31, p99 19.00, max 19.21 (60 fps, vsync); heartbeat 1.43 ms; render CPU 3.8 ms; 1,552 BaseParts in workspace, 78,425 instances. Studio window focused. |

## Findings

1. **Fixed and committed (84379c68): a reveal froze for good after the window lost focus.** `HatchCinematic.lua:60`.
   Studio proves later connections run first (two WindowFocused handlers fired "second, first"). The cinematic's
   WindowFocused handler ran before BoardAudio's (`BoardAudio.lua:198`), saw `audio.deviceActive` still false, stayed
   unowned (`owned()`, line 94) and never refreshed again. Any alt-tab, or a phone app switch, during a reveal left the
   egg sitting there until the player backed out; it is also R12's "Open saved toy stuck at QABuilding" (that attribute
   is stale on the native path). Fix: refresh on the next resumption cycle,
   `task.defer(function() if not self.destroyed then self:refreshOwner() end end)`. Verified in Play 2: the Bear's
   first reveal, frozen while unfocused, ran on to "A new little wonder" on refocus (02d); before the fix it stayed
   frozen (02x). Specs not run.
2. **Hatch another buys nothing (pre-existing, capsule on and off).** Capture: `HueResult hueStore Saved` at .25, then
   `lookBuy Rejected Throttled` 20 ms later. The server refuses any hatch request within .3 s of the last
   (`init.server.lua:1622`, `:1650`, `:1681` and the other `lastHatchRequest` checks), and `HatchFlow:syncAgain`
   (`HatchFlow.lua:77`, open at `:87`) buys the moment the store lands. Customization: the reveal closes, Stars
   unchanged. Toy: "This toy was not changed. Review your items." (R8's finding). With real ping, a fast reply still
   lands under .3 s. Fix (client): in `syncAgain`, if `os.clock()-self.againAt<.35`, `task.delay` a re-sync and return
   false; or (server) let a buy follow that player's own store without the throttle. This also blocked the capsule
   shot's streak 2 and 3 schedules from being checked.
3. **E on a "?" card at the nest opens pet focus behind it.** `HowItWorks.lua:403` binds E at High+2000, but the
   Bear's `PetInteraction` prompt (and the nest prompt) take E first. Fix: while `How` is open, set
   `ProximityPromptService.Enabled=false` (restore on close), or have the pet/nest prompt handlers ignore a press while
   a card is open. Esc cannot be bound (Roblox menu); drop "Esc" from U2's line in the test pass.
4. **Skip on a repeat drop not confirmed.** Space .4 s into the 2nd Customization shot ran the full schedule. Possibly
   `canSkip` counts the type as unseen until a reveal completes, or my press missed the window. Recheck with a click.
5. **`/tier off` did not evacuate once** (terrace, after walking up; Tier_on false, gates built). `TierHost.lua:166`
   `evacuate` only runs from `close()` when `self.open`; two retries worked. Worth a spec or a log line in `close()` if
   no one was moved while `Tier.onIt` was true.
6. **River stones look (Fable).** Stones about 3 apart with wet bands 1.12 x wide touch each other, so the row reads as
   one grey ford with the water cut out (06a). Narrower wet bands or gaps that show water between them.
7. **The Hollow probe: 37 FLAGs.**
   - H1 (31): `HollowDeckBoulder` (-45.44, -60.51) ground 4.18 vs 4.54 (-.35). 30 rim / rim+2 points from 196 to 281
     degrees hit 12.5 to 19.3 against a layout of 4.4 to 14.1: the new cliff path's treads (`W7C_CD_Box_tread_45/46` at
     15.8 to 16.0) and cliff rock run over the Hollow's south rim (07a). H6's "path bank under z -80" no longer holds.
   - H2: sandbox ground spread .63 (4.11 to 4.74), slide .45 (4.33 to 4.79).
   - H3: `W7_CD_Rocks__cliff_rock_1818` (top 15.26) inside the swing's (4.0) and the sandbox's (3.6) keepouts and both
     sand approaches (1.2).
   - H4 walls: seesaw 10, slide 6, sandbox 6 (passes 6+), swing 14. H6 most southern z -67.00, 13.0 clear. H7 rim past
     the foot line 1.31 at -2.15 (as mapped), past the polyline .39.
   Not a code blocker; Fable/level call on the swing and sandbox against the cliff rock and the path over the rim.

## Blockers for beta (18)

None in code after 84379c68. Strongly suggested before publish: Findings 2 (Hatch another) and 3 (E on cards).
Judgement calls for Fable: Findings 6 and 7.

## Captures (`studio/r13/`, Fable)

02a capsule Shot A live (mid-tuck frame). 02b Shot B held under the reveal (GUI hidden). 02c reveal rising after the
shot (Customization). 02d reveal resumed after refocus (fix). 02e pocket version's reveal. 02x reveal frozen after
refocus (before the fix). 03a the nest "?" card. 04a Play date chip in a park. 04b flat hand bubble, pet waiting at the
path foot. 05a Wobble Top shadow. 05b toy receipt. 05c Bone with two shadows. 05d egg-well glow centred. 06a / 06b river
stones (grey causeway). 07a the Hollow's south rim under the cliff path. 08a den board: Things to do. 10a Time Trial
race camera. 10b camera back in the den after the race.
Still wanted: Shot A and B clean at noon and dusk and on a 19.5:9 phone; a skip frame; the pocket well drop; the stones
top-down; the Hollow with pets in its slots; a second window size for the egg well.
