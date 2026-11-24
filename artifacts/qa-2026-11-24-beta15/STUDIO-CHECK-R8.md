# Beta 16 candidate: Studio check R8 (Opus, 2026-11-24)

`feat/egg-drop-arcade-polish` from **91a9c76**, Rojo live on 34872, Studio 53800d7d on the place file (Studio counts as
beta). Before Play, Edit held the repo's LF byte lengths: Tier 12,499, TierGreybox 5,259, EggCorner 8,732,
EggCornerWorld 13,961, TierHost 8,912, server init 150,820, EggMachineClient 20,758, NestClient 63,225, EggMachineData
1,290. `ServerStorage.EggMachine` was mounted and `ServerStorage.WorldAssets` (native pack from the repo) carries the
split: `W7_EggsStation__marble`, `__marble_smooth`, `__trim`, `__foliage`, `__palette`, `__glow_warm`. **The island
geometry in Play reflects the split**, so no staged rebuild was needed here. No ZZSpecs copies were used. Nothing was
saved or published. Three Plays (fresh save each: Skip tutorial, Meet Bear, Back). Captures are in `studio/r8/`.

## Fixes committed (offline runner 65/65 after each)

| Commit | What | Found by |
|---|---|---|
| **97f196b** | `EggCornerWorld.template`: the clone's `WorldPivot` is set to the origin. Since 91a9c76 dropped `WorldPivotData`, the pivot followed the bounding box (y 3.64, turned 180), so `PivotTo` sank the body **3.56** into the plaza (body bottom 0.57 vs floor 4.13) and put the dial on the **back**. After: body bottom **4.13**, dial **1.97** in front, loose eggs inside the globe. | Play 1 |
| **863a0ee** | `EggCornerWorld:apply`: the old `EggsSign.BrowseEggs` prompt is also disabled on the server while the corner is on. A client that joins after the boot swap never owned it, so `LoungeStations` never turned it off, and **"Browse eggs" showed over the nest** at (-31, -11) (capture 13 shows the fixed state). | Play 2 |
| **20caa8f** | `Tier.WallTop` 40 -> **54** (the plan's data rule). See T-P3. | Play 2, 3 |

## 1. Egg corner

| Check | Result |
|---|---|
| Machine at M5 | **PASS.** Pivot (-41, 4.13, 2), front +Z faces (-26, 7). Centre on `W7_Architecture__marble` 4.07; 14 of 16 rays on r 2.8 on marble/trim, spread **0.16** (rule .25). The 2 west-back rays (135 / 157 deg, about (-43.3, 3.6), 15.3 from the plaza middle) hit only `W7C_Ground_16` at 4.02: the visual there is `W7_Ground__grass` (CanQuery off), so the paving's polygon edge stops just short. The machine's own footprint is on marble. Fable: check the ring's back arc in 05 / 12. |
| Sight lines A4 / A5 | **PASS** from (2.5, 21), (-9, 21), (-20, 12) to the machine's middle and, with the real machine in place, to the nest + 2. |
| Gaps | nest 16.4, Style deck 12.1, care arch 29.4. |
| Nest at (-31, -11) | **PASS.** Mound (-31, 4.34, -11), floor 4.13 on `W7_Architecture__marble`; 0 of 96 rays meet a `W7_EggsStation__*` part. All six station parts hidden (T 1, no collide, no query). |
| Straw scatter + shadow | **PASS / note.** 12 straw + 3 leaves at r **2.75 to 3.57**; `NestShadow` 6 x 6 plate with a 6-ring SurfaceGui. Only **6 of 15** pieces are on the tree side (x < -31, z < -11); Fable asked for two thirds. |
| Dais / glow egg / tag post | **PASS**, gone (hidden). `EggDome` and `GlossLip_Eggs` LocalTransparencyModifier 1. |
| One prompt at a time | **PASS after 863a0ee.** 29 points round the nest and machine x 4 facings = **116 samples, 0** with two enabled prompts in reach. Before the fix: `Browse eggs` at the nest. |
| Attract | Eggs pin and ring at the machine (ring part 8.4 = r 3.6), icon 9.31 up (model top 7.71 + 1.6). |

## 2. Machine

| Check | Result |
|---|---|
| Model, not greybox | **PASS.** Body, Globe, Dial, Sprout, EggPile, Loose1..6, DropEgg (r3 meshes). |
| Idle | **PASS** (30 s sample). Sprout 4.2 deg, loose eggs rock 3.4 deg, pile still. Settles at 3.4, 13.6 and 23.0 s (gaps **10.2, 9.4** s). Hello nudge 14.9 deg on approach. |
| Turn | **PASS.** Dial moved at t 1.464, Hatch eggs visible at **1.768 (0.30 s)**. Peak 96 deg, rest 90 (6 deg overshoot). |
| Buy crank | **PASS.** Press to landing: **0.833 s** (Toy) and **0.833 s** (Stat); egg visible at 0.617 (roll at 0.62); full turn 371 to 375 deg. |
| Streak | **PASS.** Within 20 s of a landing: 2nd crank **192 deg** (half turn), 3rd **103 deg**, landing **0.483 s** after the press. |
| Hold | **Partial.** The cinematic went active **0.09 s** after the press (the result came before the landing), so the gate path ran. I could not see the frozen age from outside: `QAAge` is only published on owner refreshes. Skip during the hold is not proven in Studio. The toy reveal skipped from a tap I sent after the landing; earlier presses were first hatches, which can't be skipped anyway. |
| Stat Egg not held | **PASS.** Its reveal UI showed **0.085 s** after the press; the egg landed at 0.833. |
| Finding | `Hatch another` on a Toy result sends a buy that comes back as the Toy Egg panel ("This toy was not changed"). That **turns the crank fully with no egg** and **uses up a streak step**. Not a one-line fix (Sol / Fable). |
| Turn right after a buy | **Not run.** |

## 3. Nest "?" and card

**PASS.** The pill reads "Hatches in 8 h" with the `?` disc (24 px drawn, 44 px hit). A real click opens **Napping egg**
(14) with the live line "Hatches in 8 h · Egg 1 of 7" and all seven lines; Got it closes it. Tuck in turns the prompt
into **Peek**; E opens the card and the prompt hides behind it. `/onboard nest off` (the nest goes) **closes the
card**. Note: `/onboard corner off` only moves the nest, so an open card **stays open**. Hatch eggs has **no Napping egg
row**, and focus starts on Toy Egg. The card at 844 x 390 was not captured.

## 4. `/onboard corner off` and `on`

**PASS.** Off: all six station parts are back at the template values; the machine is parked in
`ServerStorage.EggCornerParked`; BrowseEggs is on with `Eggs`; Turn has no attribute; the block box is gone; the nest
box is at E1 (-25.12, -9.82); EggNestLight is at +4, range 10; the nest is at E1 with no scatter; the dome is shown;
the Eggs pin is on the old station. On: everything flips back (station hidden 6/6, machine body bottom 4.13, light +2.5
range 8, nest (-31, -11) with 16 scatter/shadow parts, prompt `Peek`). One thing to note: right after the flip off, the
tucked egg's prompt read `Tuck in`.

## 5. Upper tier

| Probe | Result |
|---|---|
| Build | 64 parts, `Persistent`, `Tier_on` true, floor top **29.00**; ring boxes **98 to 111** stood aside; 4 pet blocks. **No Hush** (no model, no `Hush_on`). |
| T-P1 | Collision **PASS**: W7C ground under the terrace peaks at **28.38** (1-stud grid, 0 cells above 29). Visuals **FAIL**: the `W7_Rocks__grass` / `__cliff_rock` meshes poke through the floor in **704 of 3,225** cells, **557** by more than a stud (214 by 1-3, 219 by 3-6, 124 by 6+, up to **38.1** at s 26 t 16), mostly t -5 to 20 (09). Players walk through them. Needs the art pass or a local re-export; not a constant. |
| T-P2 | **PASS** on PC: MoveTo along all 4 legs and 3 landings reached every waypoint, foot to terrace in about 11 s, no fall. The camera presses close to the cliff at the near landing (07). Not run at 844 x 390. |
| T-P3 | **FAIL at 40, then fixed.** At 40 one player left over **every** edge (NE / SW ends, outer rim, balustrade) by jumping from the 3-4 stud visible lip (root 43.3 to 44.7). At 48: singles held; a stand-in avatar (5.3) on a lip edge with a player on its head reached root **51.3** and left. At 54 (stops raised locally on the client) all four stacked cases held (max root 50.7). Closers present at s -38.8 / +39.2. `sweep_island_edges.py --check` passes but **knows nothing of the tier** (no tier geometry, ring always shut), so it proves nothing here. Recheck at 54 on the next Play. |
| T-P4 | **PASS.** 60 s on the terrace: no return (min root y 32.41). Forced to (-77.5, 18, -120.4) outside the ring: back on the lawn in **0.46 s**. |
| T-P5 | **PASS.** Owner on the terrace 35 s: the Bear waited by the cave mouth (max body y 6.63), 0 samples over any footprint, no poof. Back down: following again at 5.5 studs. |
| T-P6 | **PASS** (one account). `/tier off` from the terrace: moved to the evacuation spot (flat error 0.00), ring all colliding, model and pet blocks gone. `/tier clear`: rebuilt (64 parts, 98 to 111 aside, 4 blocks). |
| T-P8 | Reset on the terrace: respawned on the dais in 7.6 s. Deck round and race call **not run**. |
| T-P9 | **PASS.** The cave blocker collides; walking in stops at z -99.06 (front face -99.58). |
| T-P7, T-P10 | Captures below; memory and frame time on a phone **not run**. |

## 6. Output log

**PASS** in all three Plays. Only the known lines: ConfigService missing keys (now incl. `onboard_corner`,
`garden_tier`), `BoardSnapshot` 1 dropped, EditableImage, `Player:Move`, `203785492`, the Assistant version notice.
Nothing from Tier, TierHost, EggCornerWorld, EggMachineClient or NestClient.

## 7. Captures (`studio/r8/`, the player camera)

"Noon" is the default daylight hold (ClockTime 10.5; the hour cycle is off until `/hour on`). Dusk is `/hour at 2900`
(17.2).
- 01 / 10: the plaza from the path mouth, noon / dusk (machine left, nest centre, arch right).
- 02 / 11: arrival at the bridge, noon / dusk.
- 05 / 12: the machine close with an avatar, noon (Turn prompt, ring) / dusk (with the nest).
- 13: the nest pill with `?` and the single prompt. 14: the "?" card, desktop.
- 03: the tier from the hub (the hatch tree covers most of it; it reads as a grey block behind the colonnade).
- 04: the tier from the plaza's east side: the greybox face and skirt read as **one tall grey block** on the ridge.
- 06: the zigzag from the lawn (the solid supports read as a stepped grey wall). 07: on the near landing.
- 08: the lookout over the garden. 09: the crest rock and grass through the terrace floor.

Not captured: 844 x 390, the hub and (-9, 21) points, a phone.

Studio is left in Edit; Rojo is disconnected in the plugin and only my serve process (34872) was stopped.

# R9 recheck (Opus, 2026-11-24)

`feat/egg-drop-arcade-polish` at **17b4142**, Rojo on 34872, Studio 53800d7d (place file, Studio counts as beta). Edit
held the repo's LF lengths: Tier 12,627, TierGreybox 6,374, GreyboxRows 4,126, EggCorner 8,760, EggCornerWorld 14,220,
TierHost 8,912, server init 150,820, EggMachineClient 22,772, HowItWorks 29,733 (29,741 after e10cb3e), NestClient
63,423, client init 317,910. Two Plays (fresh save: Skip tutorial, Meet Bear, Back). Nothing saved or published.
Captures in `studio/r9/`.

## Fix committed (offline runner 65/65)

| Commit | What |
|---|---|
| **e10cb3e** | `HowItWorks.buildList`: the new `local pad` (the gamepad check) **shadowed the panel padding**, so `panelW-pad-bw` threw. Got it sat at the panel's top-left **(0, 0), over the title**, and its `Activated` was never connected: **Got it did nothing**. Renamed to `gamepad`. After: Got it at (316, 332) in the 520 x 396 panel, and a real click closes the card. |

## Results

| Check | Result |
|---|---|
| 1. Tier walls at 54 (server) | **PASS.** Server model: 68 parts, 7 stops, every top **54.00**. Stacked case on one account: an anchored 2 x 5.3 x 1 stand-in made on the server, standing on the lip line at lip height (rim 33, balustrade 32), the player on its head, W + Space held 5 s outward (real keys). Max root: outer rim **51.61** / 51.00, NE end **50.31**, SW end **50.64**, balustrade **49.82**. All held (feet at most 48.2, so 5.8 under the stop top). |
| 1. Tier colours | **PASS** (as coded). Lawn `#17702C` Grass x5, cliff `#6B7465` Slate x27, marble `#B2B1B3` Marble x16, dirt `#815C3F` Ground x4, clumps `#5A6256` Slate x3, pads x3, pole x1. Look notes for Fable: the kerbs and balustrade in Roblox Marble read **cool blue-grey with cracks**, not the plaza's warm white (06b, 08). The stack still reads as one block from the plaza, now dark rock with a green strip (04, 06). |
| 2. Hatch another on a Toy result | **PASS.** 4 presses: the dial nudges **14.8 to 15.0 deg** out and back, starting 0.10 to 0.16 s after the press. No full turn, the egg stays hidden, and the Toy Egg panel opens ("The toy was not changed"). |
| 2. No streak step | **PASS.** Refused press at 76.13, then a buy at 78.15 (15.7 s after the last landing): **192.1 deg** (2nd step, a half turn), not the quarter. |
| 2. Normal buy | **PASS.** The crank starts **0.113 to 0.134 s** after the press, in the same frame the reveal opens (Stat Egg: 0.116 s, at Saved). Full turn 371.6 to 374.2 deg. The egg shows about 0.6 s after the crank starts and lands at **0.85 s**. |
| 2. Hold up to 1 s | **Not isolated.** Toy reveals (held) show the name 2.47 to 2.49 s after the stage opens. A corner-off Customization egg (no machine) showed it at 2.16 s. Both corner-on Customization eggs were rare charms (3.98 s), so there is no like-for-like pair. The Stat Egg reveal is not held. |
| 2. Turn right after a buy | **PASS.** Turn pressed about 0.5 s after a Stat buy's egg landed: the open crank started 0.016 s later (101.8 deg) and the screen opened at 0.33 s. Note: the prompt fired while the Stat reveal card was still up, and the screen opened underneath it. |
| 3. Attract ring off the grass | **FAIL.** Ring part 7.2 (r 3.0) at (-41, 4.21, 2). Of 128 rays at r 3.0, **24 (67.5 deg)** are off marble and trim: world 121 to 186 deg, which is **105 to 167 deg from the facing**, on the west side. Seen on a fresh save's natural attract (16) and from above (15, forced on locally). No radius fixes it: r 2.6 has 11 rays off, 2.8 has 18, 3.2 has 28. Only r 2.4 or less is clear, and that is inside the body (bbox 4.2 x 4.3). Smallest fix: Fable's front arc. **200 deg (+-100)** clears every ray. Her 220 deg still leaves 105 to 110 deg (about 0.26 studs) on grass. |
| 4. "?" card with a mouse | **PASS after e10cb3e.** The live line is 14 px `#FFFFFF`, the body 14, the title 24. Got it has a label only, no glyph (last input MouseButton1). Before the fix: see the commit above. |
| 4. `/onboard corner off` | **PASS.** The open card closes **0.05 to 0.07 s** after the chat line (both Plays). The machine parks; `corner on` brings it back. |
| 5. Output log | **PASS** (Play 2: known lines only). Play 1 is flooded with my own watcher's errors (`NameGroup is not a valid member`, AssistantCommand). Nothing came from Tier, TierHost, EggCornerWorld, EggMachineClient or NestClient. The HowItWorks throw never printed. |

## Captures (`studio/r9/`, noon 10.5, camera set at the R8 spots)

- 01: the plaza from the path mouth (-20, 12).
- 04: the tier from the plaza's east side.
- 06: the zigzag from the lawn (the orange tree in front).
- 06b: the zigzag close, from the east foot (marble kerbs).
- 08: the terrace lookout.
- 14: the "?" card with a mouse, after the fix.
- 15: the machine ring from above (forced on locally).
- 16: the machine ring on a fresh save, west arc on grass.

At the end: Studio is in Edit. Rojo is disconnected in the plugin, and only my serve process (34872) was stopped. The
stand-ins are gone. The `ZZSpecs` folders Rojo mapped in (327 instances) were removed from Edit; 0 are left.
