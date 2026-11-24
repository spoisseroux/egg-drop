# Egg corner: build plan (Opus, 2026-11-24)

Step 1 of the review-driven build: **plan only, no `src/` change.** The code side of Fable's
`EGG-CORNER-LOOK.md` (which replaces R2 sections 1 to 3 of `qa-2026-11-23-beta14/WORLD-AND-NEST-LOOK.md`): the nest on
the old Eggs station spot, the egg machine as station `Eggs`, the "?" tip on the napping egg, the Hatch eggs row and the
`EggsNest` line retired. Beta place only, behind the onboarding v3 ceiling. Live unchanged.

Branch: `feat/egg-drop-arcade-polish` at `cb9323d` (worktree `worktree-agent-aaa23d577aa8b98fd`, reset onto it).
Offline baseline at `cb9323d`: `python scripts/run_dash_server_specs.py <luau.exe>`: **60 PASS, 0 FAIL**.
New read-only Studio probe: `scripts/probe_egg_corner.luau` (section 9). Machine mesh: branch `claude/egg-machine`
(`4c8d637`, r3 final: Model 91898637344879, Fable Studio R1 applied); the contract in section 6.1 keeps its part names.

Read for this plan: `Nest.lua`, `NestClient.lua`, `NestHost.lua` / `NestState.lua` (claim, tuck), `LoungeStations`,
`StationAttract(+Data)`, `LoungeWorldV7Art`, `LoungeArt` (legacy Eggs sign), `HollowWorldLayout`, `WorldV7Data`
(parsed), `WorldAero` (dome, lips), `AeroAdditions`, `AeroKit`, `ThingsTrail`, `ThingsPage`, `ThingsTips`,
`HowItWorks` + `DeckKit.helpButton` (the "?" card), `EggHatchView` (the row, the cinematic hand-off), `HatchCinematic`
(`clockHold`), `HueItemReveal`, the four item intents, `EggModels`, `UICopy` (`onb3`, `r5`), `BoardAudio`
(`PendingCues`), `Onboard` / `OnboardConfig`, `init.client.lua` (nest mount, trail, needs), `init.server.lua` (scene
cache), `WorldDressing`, `GroundDressing`, `scripts/probe_nest_spot.luau`, `STUDIO-CHECK-R5.md`, the v7 world builder
(`artifacts/world1-mockup/v7/build_world_v7.py`, `stations_v2.py`, `stations.json`), `build_world_v7_chunks.py`,
and the machine branch's manifest, gate script and `FABLE-RENDER-R1.md`.

---

## 1. What the repository already says (before any Studio probe)

These change the plan, so they come first. Each is from source data; the probe confirms them in Play.

1. **The dais cannot seat the nest.** `stations_v2.st_egg` lathes the steps at radius **3.4 / 2.8 / 2.2**, tops 0.25 /
   0.5 / 0.78 over the station root (y 4.1), so the top step is a flat disc of radius **2.2** at about y 4.88
   (`WorldAero.lua` measured the same: tops 4.4 / 4.6 / 4.9). Fable's rule needs 3.0. **By her rule the whole station
   goes** and the nest stands on plain marble at (-31, -11).
2. **The station cannot be hidden at runtime today.** `build_world_v7_chunks.classify` merges every `Stations_*`
   object by material into island-wide MeshParts: `W7_Stations__marble` is 164 x 106 studs, `__palette` 141 x 97, and
   so on. The steps (marble, gold trim, trim), the glowing egg (`egg` material, folded into a shared batch) and the
   sign stele (marble_smooth, gold) live inside meshes shared with every other station, on live too. Only three pieces
   stand alone and can be hidden by name now:
   - `W7_NestHalo__glow_warm` (the halo ring, its own animated part),
   - `W7_Stations__foliage` (the nest cup's leaves: 3.7 x 0.5 x 3.8 centred on (-31, -11); no other station uses foliage),
   - the **glass globe is not in the mesh at all**: it is `AeroAdditions.dome` (client, `WorldAero.Dome`, Glass, 4.2
     across at (-31, 5.6, -11)), plus the white `GlossLip_Eggs` on the bottom step.
   The **"gold ring"** is the steps' own gold trim ring (`trim_ring` at r 2.21) and, on the floor, the Eggs attract
   ring (`StationAttract`, r 4.7, hue `#FFC83C`). The **tag post** is `Station_EggNest_Sign_Stele` (with a gold egg
   emblem). So removing the steps, the egg and the stele needs the island re-export to split them out (section 6.2).
3. **M = (-44, 4) sits on the west bench.** `Station_BenchWest` is at **(-43, 4.05, 5)**, yaw 2.442, a 5.0 x 1.75
   marble-and-plank bench (`stations.json`, `st_bench`). M is 1.4 studs from its middle, on the seat. **M2 =
   (-41.5, 2.5)** is 2.9 from it, centred on the bench's depth axis: the machine's back would touch the bench's front
   edge (gap about -0.1). Both west spots fail before any ray is cast, unless the bench goes.
4. **M is off the paving.** `Plaza_Paving` is a marble disc of radius **15.5** round (-30, -4); M is 16.1 out, so its
   footprint straddles the paving edge onto lawn. M2 is 13.2 out (edge at about 15.6, just on).
5. **There is a marble egg statue 5.9 studs from M:** `Plaza_Ornament` `Statue_Egg` at **(-42, 9.5)** (and its twin at
   (-18, 9.5)). With the machine near it, the west side would hold two egg-shaped things again.
6. **The two west path mouths bracket M:** `Path_HubToBlossomPoint` starts at (-44, -2) (6.0 from M) and
   `Path_HubToKnoll` at (-38, 10) (8.5 from M).
7. **A spot that clears all of it** (offline search: paving radius 12.5 or less, 12 studs from the nest, the Style deck
   kiosk, the care arch and the toy lawn, 4.6 from bench middles, 3.8 from statues, 4.5 from path centre lines, 4 from
   the arrival walk line): **M4 = (-38.5, 1.5)**, 10.1 from the plaza middle, 12.9 from the kiosk, 14.6 from the nest,
   19.0 from the toy lawn, 5.2 in front of the west bench's seat (about 2.3 studs of air between them), 8.5 from the egg
   statue, 6.6 from the Blossom path mouth. It is the probe's fourth candidate. Its catch: it is closer to the middle,
   so it stands more in the walk-in view (section 13, question F1).
8. **The tuck-in rail toast is already gone.** `8df8eaa` (beta 14 Q2) removed it; `NestClient` only says the line in
   the pill. Shot 4 is from beta 14. Nothing to remove; a spec pins that no `toast` call happens on tuck.
9. **Fable's card lines are true of `Nest.lua` / `NestState.lua` as shipped:** 8 hours (`Nest.Hours`) on the server
   clock, it grows while you are away (`at` is unix time), a claim pays the gift and lands the next egg at once
   (`State.claim` sets `entry.at = now`), nothing ever costs Stars, and there is no skip. **Tuck in changes only the
   look** (lean, double Zzz rate) and the funnel step `NestTucked` (and the `need.nest` bubble counts it). No line to add.
10. **Plaza middle vs hub star:** the builder draws the gold `Plaza_InlayStar` at (-30, -4), the paving's middle.
    `HollowWorldLayout.Hub` (-30, 4) is 8 studs south of it, on the paving. Fable's table calls (-30, 4) the star; the
    probe's inventory shows which is drawn where.

---

## 2. The plaza near the egg corner, for Fable's ruling

From the builder and `stations.json` (Roblox x, z). The probe's section C re-lists them from rays and adds anything the
builder did not name.

| Element | Where | Distance to M / M4 / nest (-31, -11) | Note |
|---|---|---|---|
| `Plaza_Paving` marble disc | r 15.5 round (-30, -4) | | M is outside its edge |
| `Plaza_InlayRing` trim ring | r 10.4 to 11.9 round (-30, -4) | | raised trim, 0.2 up |
| `Plaza_InlayStar` gold star | (-30, -4), r 3.2 | 16.1 / 9.9 / 7.1 | |
| `Station_EggNest` (steps, cup, egg, halo, stele) | (-31, -11), yaw -0.35 | 21.4 / 14.6 / 0 | goes (section 1.1) |
| `Station_BenchWest` | (-43, 5), yaw 2.442 | **1.4** / 5.2 / 20.0 | **blocks M and M2** |
| `Station_BenchEast` | (-17, 5), yaw 3.842 | 27.0 / 21.6 / 20.6 | |
| `Station_PocketDeckKiosk` + `Pad_Workbench` r 4.6 | (-46, -9) | 13.2 / 12.9 / 15.1 | Style deck |
| `Station_CareCradle` + pad r 4.6 | (-17, -15) | 33.1 / 26.4 / 14.6 | care arch, mobile |
| `Statue_Egg` (Plaza_Ornament) | (-42, 9.5) | 5.9 / 8.5 / 22.8 | an egg on a plinth |
| `Statue_Egg` (Plaza_Ornament) | (-18, 9.5) | 26.6 / 21.3 / 24.3 | |
| `Urn` (Plaza_Ornament) | (-46.5, -17) | 21.2 / 19.8 / 17.3 | |
| `Urn` (Plaza_Ornament) | (-13.5, 5) | 30.5 / 25.1 / 23.7 | |
| Colonnade columns (r 23, 7) | (-52.1, -10.3), (-48.8, -17.2), (-43.5, -22.6), (-36.7, -26.0), (-29.2, -27.0), (-12.9, -19.4), (-8.7, -12.6) | nearest 16.5 / 16.9 / 16.1 | entablature over the first five |
| `Colonnade_FallenDrum` | (-11, -19) | | |
| Hatch tree (trunk near (-36, -18)) + lantern | lantern (-31.8, 8.8, -16.7) | | the nest sits under its crown |
| `Pad_Future_A` / `Pad_Future_B` marble pads r 3.6 | (-48, -22) / (-13, -4) | | empty pads |
| `Station_ToyLawn` | (-30, 18.5) | | toys, chest |
| `Station_PicnicWest` + pad | (-58, 12) | 16.1 / | |
| Path mouths | Blossom (-44, -2), Knoll (-38, 10), Bridge (-20, 3), Grotto (-28, -22), Nook (-18, -14) | | |
| Lamp 5 | (-70, -3) | | far |
| Flower patch (WorldDressing) | (-49.2, 6.2), 3.5 across | 5.6 / 11.6 / | outside the 4.9 station clearance |
| Runtime: attract pins and rings for Customize, Eggs, Journal | at each station | | Eggs moves to the machine |
| Runtime: lights `EggNestLight`, `KioskLight`, `CradleLight`, `PlazaLight` (Hub + 7), `LanternLight` | | | `EggNestLight` stays at the nest, lowered |

---

## 3. The switch

- **`Onboard.on("corner")`**: a fourth onboarding v3 part (Fable suggested `eggCorner`; the chat parser lower-cases and
  matches `%a+`, so a one-word lower-case id gives **`/onboard corner on|off|clear`** for free). Attribute
  `Onboard_corner`, ConfigService key `onboard_corner`, missing = on (the Onboard rule), under the ceiling, so live
  (`FeatureFlags.OnboardingV3` ceiling false off the beta and Studio) never runs any of it. Edits: `Onboard.Features`,
  `Attributes`, `Keys`, the server's `switches` table. **No `FeatureFlags.lua` or `init.server.lua` edit** (the
  upper-tier builder owns blocks in both).
- **A readiness gate** for the world half: `EggCorner.split()` is true when the island export carries the station as
  its own parts (section 6.2: any `WorldV7Data.parts` entry with region `EggStation`). Until then the station's steps,
  egg and stele cannot be hidden, so:
  - corner on, not split: the machine (mesh or greybox) at its spot with the `Turn` prompt, pin and ring; the old
    station loses its prompt, pin, ring, dome, lip, halo and cup leaves; **the nest stays at E1** (-25.12, -9.82) beside
    the bare steps. Everything else (pill, "?", card, Peek, row, line) is on.
  - corner on and split: the full layout, the nest at (-31, -11).
  - corner off: exactly beta 15 (nest at E1, station prompt `Browse eggs`, the Napping egg row, `Yield.Eggs`).
- The machine's own runtime flip (off to on mid-session) is supported: every piece listens to `Onboard.changed("corner")`
  (section 4). Under the hood the nest re-opens at its new root, the same way it already does for the `nest` switch.

---

## 4. Files and approach

New shared module **`src/shared/EggCorner.lua`** (pure, specs inject it): every number in section 5, `on()`,
`split(data)`, `machineFrame()` (`CFrame.lookAt(M, Face) * Ry(pi)`, so +Z is the front as the stations' rule says),
`nestSpot()` (corner and split: (-31, -11); else `Nest.Spot`), `trailEnd()` (M + front 3.0), `blockBox()`,
`pinHeight(model)` (model top + 1.6), `lightAt()`. `HollowWorldLayout` is **not** edited: `V7.Stations.Eggs` stays the
old station for live and for every spec that reads it.

| File | Change |
|---|---|
| `src/shared/Onboard.lua` | the `corner` part (section 3). |
| `src/shared/EggCorner.lua` | new (above). |
| `src/shared/UICopy.lua` | `onb3.nest.help.{title,what,time,gift,free,next,wait,button}` (section 8), `onb3.nest.peek = "Peek"`, `onb3.nest.helpAsk = "What is this?"` (the "?" disc's accessible label), `r5.station.Eggs.turn = "Turn"`; **remove** `r5.station.EggsNest` (the sync deletes its translations). `inside` reuses `onb3.nest.inside` / `insideStars`. |
| `scripts/export_localization_csv.py` | a context column note for `r5.station.Eggs.turn`: "turn the handle of a toy machine" (if the exporter has no context column, add one; check `sync_localization.py` passes it). |
| `src/server/LoungeWorldV7Art.lua` | under the ceiling only: build **both** Eggs anchors at boot (the old `EggsSign` and a new `EggMachinePrompt` anchor at `machineFrame * (0, 2.2, 2.6)`, prompt `Turn`, reach 7, `UIOffset` as today) so the scene cache sees both station parts; the machine model (section 6.1) placed by `PivotTo(machineFrame)` into the room, mesh template or greybox; a `GardenBlockedRegion` box 4.8 x 1 x 4.4 turned with it; the nest's box built at `nestSpot()`. Lights: `EggNestLight` at `lightAt()`. All flips go through the new `EggCornerWorld` below. Off the ceiling: exactly as now. |
| `src/server/EggCornerWorld.lua` | new, server: `apply(on)` on boot and on `Onboard.changed("corner")`: swaps `PocketClubStation = "Eggs"` between the two prompts (the other gets no attribute: `LoungeStations.observe` already drops a prompt whose attribute goes), parents the machine model in or out (to a hidden folder in `ServerStorage`), moves the nest's blocked box (destroy and re-create: the scene cache only learns parts through `DescendantAdded`, and every reader checks `part.Parent`), moves and dims `EggNestLight` (+4 range 10 -> +2.5 range 8), and hides the station parts by name: `W7_NestHalo__glow_warm`, `W7_Stations__foliage` and, once split, every `W7_EggStation__*` (`Transparency 1`, `CanCollide false`, `CanQuery false`, `CastShadow false`; the old values kept in attributes to restore). |
| `src/client/AeroAdditions.lua` | `dome` and the `Eggs` lip skip when `EggCorner.on()`; `EggMachineClient` hides an already-built `EggDome` / `GlossLip_Eggs` on a flip (`LocalTransparencyModifier = 1`), so Aero never has to rebuild. |
| `src/client/EggMachineClient.lua` | new: idle motion, hello, open crank, buy crank, the cinematic hold, sounds, haptics (section 7). Finds the replicated `EggMachine` model under the room; animates its parts locally from their `WorldRestCFrame` attributes (the server never moves them after placing, so there is no fight); 60-stud cut-off; Reduced Motion. |
| `src/client/HatchCinematic.lua` | one seam: `Cinematic.gate` (module field, a function or nil). `held()` becomes `clockHold() or gate()`. `EggMachineClient` sets it during a buy crank and clears it at the landing (hard cap 1.0 s from the press). |
| `src/client/StatEggReveal.lua` | the same hold at its first frame (the Stat Egg does not use the item cinematic). `[verify]` its clock entry point in the build. |
| `src/client/EggPreview3D.lua` | `Preview:crank(clicks, clunkAt)`: a 6 degree shake per click and an 8 px drop at the clunk, on the preview egg of the screen the buy was pressed on (`[verify]` which view owns the buy button for each egg type: `EggHatchView` for the list, `HueEggView` for toy / look / feature / material). |
| `src/client/BoardAudio.lua` | `PendingCues` (silent until uploaded): `egg_tok_1..3`, `crank_click_1..3`, `crank_clunk`, `egg_roll`. The landing thud is the existing `land` cue until the ritual's Settle exists. |
| `src/client/StationAttract.lua` | `labelText`: under the ceiling always `EggsV3` (the `nest` branch and `EggsNest` go). New `options.place(id)` -> `{position, iconHeight}` or nil, asked at build and on `Attract:move(id)`; init passes the machine's base and `pinHeight` while the corner is on. A flip calls `attract:move("Eggs")`, which rebuilds the entry (as `extra` already does for the Dash gate). |
| `src/client/StationAttractData.lua` | no change (`iconHeight` comes from `place`). |
| `src/client/NestClient.lua` | `Client.Spot` from `EggCorner.nestSpot()` at `open()`; re-open on `Onboard.changed("corner")`; `Stations.Yield.Eggs` only while the corner is off; the pill rows and the "?" disc (section 8); the prompt's third action `peek` (section 8); `menuRow` unchanged (init stops asking it). |
| `src/client/HowItWorks.lua` | a list set (section 8): `How.Sets.nest = {tint = "companions", list = true, copy = "onb3.nest.help", lines = {...}, live = fn}`; `How.build` draws one card with the 56 px icon, the live line and up to six dotted lines; no "Show tips again", no replay line; "Got it" only. Not in `How.Order` (not a machine set). |
| `src/client/init.client.lua` | the nest mount gets `help = function() How.open("nest", ...) end`; `nurseryView.nest.row` returns nil while the corner is on; `needs.place("Eggs")` returns `EggCorner.trailEnd()` while on; mount `EggMachineClient` (Room mode, free, reduced, audio, haptic) behind the ceiling; wrap the four intents' `send` and `nurseryRequest` sends for `toyBuy`, `hueBuy`, `lookBuy`, `materialBuy`, `featureBuy`, `statEggBuy` so each press calls `clientUI.eggMachine:bought(kind)` before the remote fires; the Eggs station route waits 0.3 s for the open crank (section 7). |
| `src/client/LoungeStations.lua` | no change (the attribute swap does it). |
| `default.project.json` | `ServerStorage.EggMachine` <- `assets/world/EggMachine.rbxmx` (one entry; written by the machine branch's gate). |
| `scripts/run_dash_server_specs.py` | add the new specs to `SPECS` / `CLIENT` and the new client modules to the bundle patterns. |
| `scripts/probe_egg_corner.luau` | new, read-only (section 9). Committed with this plan. |
| `V3-TEST-PASS.md`, `PLAY-BUILD.md` | rows when it publishes on the beta. |

---

## 5. Numbers

| What | Value | Source |
|---|---|---|
| Machine root | the first of **M (-44, 4)**, **M2 (-41.5, 2.5)**, **M4 (-38.5, 1.5)**, M3 (-17.5, -2.5) that passes probe A (Fable, Studio review: M stands on lawn with the dirt path under 4 studs; from source both M and M2 also meet `BenchWest`). `EggCorner.Spot` takes the winner; F1 if only M4 or M3 pass | section 1, 9, F1 |
| Machine front | +Z looks at (-26, y, 7) | LOOK 1 |
| Machine y | the probe's floor at the chosen spot (about 4.13 on paving) | probe A1 |
| Block box | 4.8 x 4.4, turned with the machine, Y 1 at FloorTop + .5 | LOOK 1 |
| Prompt | `Turn`, reach 7, anchor at machine-local (0, 2.2, 2.6) (in front of the dial, outside the box) | LOOK 1 |
| Pin | Eggs glyph, hue `#FFC83C`, `iconHeight` = model top + 1.6 (7.2 + 1.6 = **8.8**; read from the model's bounds, since R1 lets the sprout reach 7.6) | LOOK 1 |
| Ring | Eggs attract ring at the machine (r 4.7) | LOOK 1 |
| Trail end | M + front * 3.0 | LOOK 1 |
| Nest root | (-31, y, -11) once split; y from the nest's own ground ray (`GroundSlack` 1) | LOOK 1 |
| Nest facing | (-30, y, -4) | LOOK 1 |
| Bear spot, sign, SignYaw | (-2.2, 0, -1.4), (-1.7, y, 1.6), 50 (unchanged; probe B5 says whether 50 still reads from (-20, 12)) | LOOK 1 |
| `EggNestLight` | at the nest, +2.5 over the ground, range 8 (was +4, 10), brightness .85 | LOOK 1 |
| Nest prompt | reach 4.5; `Tuck in` / `Peek` / `Hatch` | LOOK 1 |
| Globe light | PointLight `#FFE9A6`, range 8, brightness .5, night only (`HollowLamp`, day 0, night .5) | LOOK 2 |
| Pill (napping) | one line, the clock at 14 px (13 compact) + the "?" disc: 24 px drawn, 44 x 44 hit, 6 px gap; about 130 px wide | LOOK 3 |
| First-time pulse | the disc 1 -> 1.15 -> 1, twice, 0.5 s each, once ever (coach bit `nestHelp`) | LOOK 3 |
| Card icon | 56 px, the chip art `rbxassetid://114080030018596` | LOOK 3 |

---

## 6. The contracts for the island session

### 6.1 The machine model (branch `claude/egg-machine`, r3: keep its names)

Read from `claude/egg-machine` at `4c8d637`: `assets/world/EggMachine.rbxmx` (Model 91898637344879, texture
119526952958289, roughness 78518887759939) and `src/shared/EggMachineData.lua`. **The island session renames nothing.**
The template already matches what the code needs; the contract below fixes how the code reads it, plus two small
asks to the gate.

**Template as built (kept).** One `Model` **`EggMachine`**, its `WorldPivot` the base's centre on the ground with
**+Z the front** (dial side), every part placed machine-local:

| Instance | As built | How the code uses it |
|---|---|---|
| `Body` | MeshPart, SurfaceAppearance `Enamel`, Anchored, CanCollide true, CollisionFidelity Box, CanQuery true, CastShadow true | never moves; the machine's collision (with the server's blocked box for pets) |
| `Globe` | MeshPart, SmoothPlastic, Transparency .62, no collide / query / shadow | never moves |
| `Dial` | MeshPart, satin texture, no collide / query, shadow | turns about `EggMachineData.pivots.Dial` (0, 1.95, 1.70), axis `dialFace` (machine +Z); positive angle = clockwise seen from the front |
| `Sprout` | MeshPart, no collide / query / shadow | sways about `pivots.Sprout` (0, 7.08, 0), the stem's foot, around machine X and Z |
| `EggPile` | MeshPart, vertex-coloured baked eggs, no collide / query | shivers 0.04 about its own centre |
| `Egg` | MeshPart, one 96-triangle egg, no collide / query | **the clone source only**: the server makes `Loose1`..`Loose6` and `DropEgg` from it, then removes `Egg` from the placed copy |

**What the server builds on the placed copy** (in `EggCornerWorld`, from `EggMachineData`, after `PivotTo`):

- `Loose1`..`Loose6`: clones of `Egg` at `loose[i].at` (machine-local), `Color` from `eggTypes[loose[i].type]`,
  attribute `EggType`. Each rocks and hops about its **base**: `CFrame * (0, -Size.Y / 2, 0)` (fat end down).
- `DropEgg`: a clone of `Egg` scaled by **1.0909** (0.66 -> 0.72 wide, R1), Transparency 1 at rest, at `chute.top`.
  It rolls `chute.top` -> `chute.end` -> the cup's seat (`cup` + half its height), takes the bought type's colour,
  lands, fades.
- Attachments on `Body` named `DialPivot`, `SproutPivot`, `ChuteTop`, `ChuteEnd`, `CupSeat`, `GlobeLight` at the data's
  points (so the client reads world positions without redoing the maths), and a PointLight in `GlobeLight` (`#FFE9A6`,
  range 8, brightness .5, `HollowLamp` night only).
- `WorldRestCFrame` on `Dial`, `Sprout`, `EggPile`, `Loose1..6`, `DropEgg`. The server never moves them again; clients
  animate from these.
- Model attributes `EggMachineAsset` (`assetId`) and `Triangles` (`triangles`, 5254).

**Mount.** Rojo: `ServerStorage.EggMachine` <- `assets/world/EggMachine.rbxmx`; `EggMachineData` is already under
`src/shared`. The **server** clones it into the lounge room (one replicated copy, real collision for everyone);
clients only animate it.

**Two asks to the gate** (no rename, no re-upload):
1. The docstring says "the client places the Model with PivotTo": make it "the server".
2. Add `dropScale` (1.0909) to `EggMachineData` so the number lives with the mesh (until then `EggCorner` holds it).

**Greybox fallback** (no `ServerStorage.EggMachine`): the server builds parts with the same six names at the data's
sizes (Body a cream block 4.2 x 2.95 x 3.8 plus a cup, Globe a Ball 3.4 at .62, Dial a 1.7 cylinder facing +Z, Sprout
a 0.9 x 0.6 block, EggPile a Ball 2.8, Egg a Ball 0.66 x 0.86 with a Sphere mesh), then the same clones and
attachments, so the client never branches on mesh or greybox.

### 6.2 The station split (needed before the nest can move)

In the island export (`build_world_v7_chunks.classify`), **every `Station_EggNest_*` object** (Steps, Nest_Cup, Egg,
Glow_Halo, Sign_Stele) goes to its own region **`EggStation`**, grouped by material as `W7_EggStation__<mat>`
(collide as today: marble, marble_smooth, trim, gold), out of `Stations__*` and `NestHalo__*`. Live looks the same
(the parts are visible and collide as before); the beta hides them by name. Also:

- **Floor under it:** the plaza marble (`Plaza_Paving`, region Architecture) must be a whole surface under the dais
  footprint (r 3.6). If the builder culled the faces under the steps, fill the disc. Probe B3 says which.
- **Collision:** if the island's native collision checkpoint bakes the dais into a `W7C_*` tile, the dais collision
  must come out of that tile into a part the beta can switch off (`W7C_EggStation`). Probe B1 / B3 show whether the
  floor rays meet a step-shaped collision proxy.
- The `NestHalo` motion (pulse) moves with the halo into `EggStation`'s glow part, or the halo is simply dropped from
  the beta (it is hidden there anyway); keep live's pulse.
- `WorldV7Data` regenerates (the new region); `HollowWorldLayout.V7.Stations.Eggs` and `WorldAero.Lips` stay.
- If the island session would rather not touch `WorldAssetsNative`: the fallback is kit copies of the four affected
  island-wide meshes without the station, swapped in by the server on the beta. It costs four large meshes and a
  collision re-check; I recommend the split (question A2).

---

## 7. Motion, cranks and the hold

All client-side, all in `EggMachineClient`, nothing replicated (others' cranks: question A4). Beyond 60 studs (camera
or root) no per-frame work; Reduced Motion: sprout and rock off, settle and hello stay.

**Idle.** Sprout 4 degrees each way at 0.35 Hz. `Loose1..6` rock 3 degrees about their base at 0.2 to 0.3 Hz, own
phase (seeded by index). Settle every 9 to 14 s (random): one loose egg slips 0.15 to 0.3 studs down the pile over
0.5 s with one bounce, then eases back to rest over the next idle second; `egg_tok_1..3` at -26 dB within 14 studs.
The body never moves.

**Hello.** The root comes within 10 studs (flat): the dial nudges 15 degrees and springs back over 0.4 s, one
`crank_click` at -24 dB; once per approach (leave past 12 to re-arm), at most every 20 s.

**Open crank (`Turn`).** The Eggs route, while the corner is on: `machine:openCrank()` then `task.delay(0.3, open)`,
where `open` re-checks `Stations.visitEggs`' own conditions (a menu, a death or a mode change in those 0.3 s cancels;
a second press inside them is ignored). t 0: dial 90 degrees over 0.28 s, ease-out with a 6 degree overshoot; clicks at
0, 90, 180 ms; three light haptic ticks. t 0.1: the six loose eggs hop 0.12 and land, one `egg_tok` at -24 dB.
t 0.3: the screen opens as today. Closing: nothing; the dial stays where it is.

**Buy crank.** `machine:bought(kind)` at the press, before the remote fires (all six buy actions; `lookBuy` drops a
Hue-coloured egg since the Customization Egg wears the Hue art, `nameEggBuy` is not on the screen):

| Streak (a buy within 20 s of the last landing) | Turn | Clicks (ms) | Clunk at | Roll | Lands at |
|---|---|---|---|---|---|
| 1st | 360 degrees, 0.6 s, even speed, a little resistance in the first 60 ms | 0, 110, 220, 330, 440, pitch +4% each | 0.60 (spring-back 8 degrees, `crank_clunk` -16 dB, one medium haptic) | 0.62 to 0.85 | **0.85** |
| 2nd | 180, 0.45 s | 0, 150, 300 | 0.45 | 0.47 to 0.70 | 0.70 |
| 3rd on | 90, 0.25 s | 0 | 0.25 | 0.27 to 0.50 | 0.50 |

Churn from 0.1 to the clunk: loose eggs hop 0.2, the pile shivers 0.04, two soft `egg_tok`. Roll: `DropEgg` in the
bought type's colour along `ChuteTop` -> `ChuteEnd` -> `CupSeat` with `egg_roll` (-20 dB, 0.22 s). Landing: one rock,
and **the landing thud** (`land`, the ritual's Settle stand-in) and its haptic, **once**. The egg fades 1.5 s after the
screen's hatch ends (the reveal's close), or at 6 s if no reveal ever came. The globe never empties.

**The hold.** From the press to the landing, `HatchCinematic.gate` returns true, so the reveal's first frame is the
frame after the landing (if the result arrives first it waits; if it arrives after the landing it plays at once, and
no second thud plays). The gate clears itself at the landing, on a refused buy (the intent's status leaves Pending
without a result), and in any case 1.0 s after the press. **On screen** (the menu covers the machine), the preview egg
on the screen the press came from shakes 6 degrees per click and drops 8 px at the clunk; no new art. The sounds play
even when the player is far from the machine (they are the buy's feedback); the world animation only within 60 studs.
**Skip** cannot cut the crank (under a second); the reveal's own skip rule applies after.

Haptics: one small helper over `HapticService:SetMotor` (`Small` motor, 30 to 50 ms pulses) for gamepads that report
support; nothing on touch or mouse (Roblox has no phone haptics API). No haptics exist in the client today.

---

## 8. The "?" tip, Peek and the card

**Pill rows** (`Client.row`, corner on): napping = **row 7, the clock only**, with the "?" disc; the explainer row 5
and the "Inside" row 6 move into the card; ready = row 4 `Hatch me!` gold, no disc; the beats (rows 1 to 3: first
tuck-in, tuck-in, a new egg) stay as they are. Corner off: today's rows.

**The disc.** The pill's `BillboardGui` moves to `PlayerGui` with `Adornee` = the egg anchor and `Active = true`
(a billboard under a workspace part never gets clicks), `ResetOnSpawn = false`. The disc is a `TextButton` 44 x 44
(hit) with a 24 px drawn disc in the `Kit.button` secondary look (cream fill, ink "?"); a second transparent button
over the pill's text does the same. Both call `d.help()`. The board stays a fixed 220 x 80 with the pill at its bottom
(no jump); the pill is clock width + 12 + 24 + 6 + 12. `AccessibleLabel`: `onb3.nest.helpAsk`. First time only, after
the first tuck-in ever: two pulses, then the coach bit `nestHelp` (a new `CoachMarks` id under the `nest` part; the
server's coach-id allow list gains it).

**Peek.** The nest prompt's actions: not tucked -> `Tuck in`; tucked and napping -> **`Peek`** (calls `d.help()`, no
remote); ready -> `Hatch`. Peek is enabled under the same `free` / `busy` rules (the card open counts as busy, so the
prompt hides behind it). On keyboard E, gamepad X, and a tap on the prompt.

**The card** (`How.open("nest")`, the HowItWorks overlay: same frame, eyebrow, title bar, close, shade, B / Backspace /
outside-tap close, A / Enter "Got it"). It opens centred on every device (today's "?" card is centred on phones too;
there is no bottom sheet). Content: the 56 px icon top left, the title **Napping egg**, one live small line
(`Hatches in {hours} h` or `{minutes} min`, then ` · Egg {count} of 7` in the welcome week; refreshed once a second
while open), then six lines with a leading dot at 14 px: `what`, `time` ({hours} = `Nest.Hours`), `gift`, the inside
line (`onb3.nest.inside` / `insideStars` from the view), `free`, `wait`, plus `next` when it fits. At 320 px wide each
line must fit two lines: `How.listFit(width)` measures and **drops `next` first** if the body would scroll. No Stars
icon, one button `Got it` (`onb3.nest.help.button`).

| Key | Text |
|---|---|
| `onb3.nest.help.title` | Napping egg |
| `onb3.nest.help.what` | Your pet's egg is asleep in the nest. |
| `onb3.nest.help.time` | It naps for {hours} hours, even when you're not playing. |
| `onb3.nest.help.gift` | When it wakes up, come back and hatch it for a gift. |
| `onb3.nest.help.free` | It's always free. You never need Stars for it. |
| `onb3.nest.help.next` | Hatch it, and a new egg starts its nap. |
| `onb3.nest.help.wait` | Naps can't be hurried. Go play, it will be here. |
| `onb3.nest.help.button` | Got it |
| `onb3.nest.peek` | Peek |
| `onb3.nest.helpAsk` | What is this? |
| `r5.station.Eggs.turn` | Turn (context: turn the handle of a toy machine) |
| `r5.station.EggsNest.*` | removed |

**Hatch eggs row.** `nurseryView.nest.row` returns nil while the corner is on: no row in any state, first focus the
first egg type, the space left empty. The `"nest"` close reason and the Board-mode row code stay for the corner-off
path (they go when the switch is retired). Nothing else reads the `"nest"` reason (`View.closeReason` only).

---

## 9. Studio probes (`scripts/probe_egg_corner.luau`, read-only, **Play** on the beta)

Run with Studio MCP `execute_luau` in Play (in Edit the world is not built: STUDIO-CHECK-R5). It creates nothing.

- **A**, for M, M2, M3 and M4: A1 the centre and 16 rays on r 2.8 on marble within .1; A2 a .5-stud grid of rays inside
  the turned 4.8 x 4.4 footprint meets only the floor (catches the bench, statues, steps); A3 no path, trim, lawn or
  meadow within 4.0; A4 the three walk-in sight lines ((2.5, 21), (-9, 21), (-20, 12), 5 up) to the machine's middle;
  A5 the same three to the nest + 2 with the machine's 4.8 x 7.2 x 4.4 box in the way (a slab test in the probe, no
  part placed); A6 the four neighbour gaps.
- **B**, the nest at (-31, -11): B1 the dais by rings (each step's radius, top, mesh) and the largest flat disc (the
  3.0 rule); B2 which meshes carry the egg (from above, across at 5.5 and 6.5), the halo / cup and the stele (the
  split list for 6.2); B3 with every `W7_Stations__*` / `W7_NestHalo__*` left out: the floor under r 3.6 (a hole =
  the re-export fills it), the r 2.6 ring at .5 / 1.5 / 2.5 up, the Bear spot, sign post and prompt point on marble
  within .1; B4 sight lines to the sign board and the nest; B5 the sign's Front and Back angles to each walk-in point
  and the `SignYaw` that would face (-20, 12).
- **C**, the inventory for Fable: a 1-stud ray grid over x -54..-10, z -26..18 (up to five hits a column), blobs by
  mesh with centre, extent, height range and their distances to M and the nest; then the runtime parts within 20.

**After the build, in Studio (Play):** P1 the probe again with the chosen spot (A all PASS); P2 one prompt at a time
around the machine and the nest (13 points x 4 facings, as STUDIO-CHECK-R5 2c); P3 the pill's "?" tap and the Peek key
open the card, B closes, the prompt returns; P4 the card at 844 x 390 and 320 wide (lines fit, `next` dropped only if
needed); P5 a buy: the hold (reveal starts after the landing; log the press, landing and first-frame times), a streak of
three; P6 corner flip on and off mid-session (`/onboard corner off|on`): prompt, pin, nest, boxes, light, dome come and
go, no warnings; P7 the globe against a jelly pet walking behind it (Glass vs SmoothPlastic); P8 the captures Fable
listed (section 5 of her doc).

---

## 10. Edge cases

- **An egg tucked in today at the beta 15 spot.** Nothing is saved by position: the egg shows at the new root with
  `tucked = true`, so the prompt says `Peek` and no tuck beat replays. A ready egg says `Hatch`.
- **Corner flipped mid-session.** The nest closes and re-opens at the new root (its folder is rebuilt; the view comes
  back with the next `sync`); a live Show me trail to the old spot stops (`trail:stop("moved")`); the attract entry is
  rebuilt; an open crank in flight finishes; the server swaps the prompt attribute in the same frame it moves the box.
- **Two players.** Each draws only their own nest, at the same spot (as today). One shared machine model; each sees
  their own cranks only (others' cranks wait for A4). Both near the machine: one `Turn` prompt each, local.
- **Pre-split world** (section 3): corner on keeps the nest at E1 beside the bare steps; the 12-stud rule is then
  broken only by a dais with no prompt, no pin and no glass. Question A1 decides whether that ships.
- **Gamepad / keyboard.** `Peek` (X / E) opens the card; A or Enter is Got it, B closes; the disc is touch and mouse
  only (`Selectable = false`), so gamepad focus never lands in the world. `Turn` is the station prompt as before.
- **Touch.** The disc's 44 px hit and the pill both open the card; a tap on the prompt's button works too.
- **Board mode / Deck.** A buy from the Hatch eggs screen opened from the Pocket menu while in Board mode: sounds, the
  preview shake and the hold play; no world animation (the room is not drawn); the hold still clears at 0.85.
- **Refused buy** (not enough Stars, busy, saving): the crank has already started; the roll does not start without
  the intent going Pending, and a refusal before the clunk stops the turn at the clunk with no egg; the gate clears.
- **Reduced Motion.** No sprout sway or rocking; settle, hello and the cranks play (the cranks are feedback); the "?"
  pulse is skipped.
- **Budget level 2 / Aero off.** The dome and lip are not built anyway; the machine is not part of Aero, so it stays.
- **Live unchanged.** The ceiling is false on live: no `corner` attribute, no second anchor, no machine clone, no box,
  no hides, no client module mounted, `labelText` unchanged off the ceiling, the row code unchanged. The only live-
  visible change is none: `ServerStorage.EggMachine` is mounted but never cloned; the island split (6.2) keeps every
  station part visible and colliding. A spec runs the world build with the ceiling off and diffs it against today's.
- **Pets.** The machine's blocked box and the station rule (no wander target within 3 studs of a prompt anchor: the
  new anchor is there at boot) keep pets off it; the old station anchor keeps its 3-stud rule even with its prompt off
  (harmless: it is the nest's square, which has its own box).
- **Dressing.** No flower or ground plate is within 4.9 of M or M4 (one flower patch at 5.6 from M); `GroundDressing`
  keeps `nest = 1` from `Nest.Spot`, and the new spot is on bare paving (the generator put no plate there).

---

## 11. Specs (offline runner)

`python scripts/run_dash_server_specs.py "C:/Users/skunk/Documents/Development/egg-drop/build/luau-cli/luau.exe"`
(baseline 60 PASS). New and changed:

- **`EggCorner.spec`** (new, shared): the switch off = beta 15 numbers (nest E1, Eggs = the old station); on and not
  split: machine frame, nest still E1; on and split: nest (-31, -11); front +Z looks at (-26, 7); the 12-stud rule
  between the machine, the nest, the kiosk, the arch and the toy lawn; 4.6 from both benches' middles, 3.8 from the
  statues; trail end 3.0 in front; block box; the light; pin height from a model's bounds.
- **`Onboard.spec`** / **`OnboardConfig`**: `corner` in `Features`, its attribute and key, `/onboard corner off` parses.
- **`NestClient.spec`**: spot by corner and split; re-open on a corner flip; rows (napping = clock + disc, ready = no
  disc, beats unchanged, rows 5 and 6 gone under the corner); pill width with the disc; `Peek` state machine (tuck ->
  peek -> hatch, disabled while busy, no remote sent); `help()` called by the disc, the pill and Peek; no `toast` on
  tuck (the beta 14 rule); `Yield.Eggs` unset under the corner; the first-time pulse once.
- **`NestSpot.spec`**: today's E1 cases kept for corner off; the corner spot's clearances (stations, course, pad, walk
  line, flower patches, firefly areas).
- **`StationAttract.spec`**: `labelText` never `EggsNest`; `place("Eggs")` moves base and `iconHeight`; `move` rebuilds.
- **`EggMachineClient.spec`** (new, client): crank schedules for streaks 1, 2, 3 (click, clunk, roll and landing times);
  the gate holds until the landing and never past 1.0 s; a refused buy clears it; open crank opens at 0.3 and a second
  press is ignored; idle settle 9 to 14 s; hello at 10, re-armed past 12, 20 s apart; nothing past 60; Reduced Motion.
- **`HowItWorks` list card** (pure `How.listLines(view, width)`): order, the inside line from the view, `next` dropped
  first at 320 px.
- **`LoungeWorldV7Art`** world build (server, mocked): ceiling off = today's instances only; ceiling on: two anchors,
  one `PocketClubStation = "Eggs"` by the switch, the machine model or greybox with the contract's names and
  attachments, the blocked boxes, the light. `EggCornerWorld.apply` round trip restores every hidden part.
- **`UICopy.spec`**, **`LocalizationFit.spec`**: the new keys fit; `EggsNest` gone. Then the two localization scripts
  before publish (AGENTS rule).
- **`GroundDressing.spec`**, **`DashCourse.spec`**: the machine spot added to their station lists (clear of plates,
  course and pad).

---

## 12. Order (slices)

1. **Slice A, no art** (can ship on the beta first): `Onboard` corner, `EggCorner`, `EggCornerWorld` (prompt swap,
   hides of halo / foliage / dome / lip, light), greybox machine at the chosen spot with `Turn`, pin, ring, box, trail;
   the "?" disc, card, `Peek`; row and `EggsNest` removal; open crank on the greybox (dial part turns). Nest stays at E1
   until the split (A1).
2. **Slice B, the machine mesh**: the branch's gate confirmed with this contract's names; the server clones it;
   idle motion, hello, globe light; Fable's Studio noon / dusk captures.
3. **Slice C, the buy crank and the hold** (`HatchCinematic.gate`, `StatEggReveal`, preview shake, sounds pending).
4. **Slice D, the split** (island re-export, 6.2): the nest moves to (-31, -11); probe B again; captures.
5. Optional **slice E**: others see your crank (A4).

Each slice: plan review (this doc, architect), build, code review, fix, offline specs, Studio checks, beta publish with
the `V3-TEST-PASS.md` rows and translations synced.

---

## 13. Risks

- **The spot.** Both of Fable's west spots fail on the bench (section 1.3); M4 changes the composition (more central).
  This needs Fable's ruling before slice A.
- **The split is a re-export of `WorldAssetsNative`**: a new mesh upload and a collision re-check of the plaza, on live
  too (visually identical). If it slips, the nest stays at E1 and the corner is only half done.
- **Glass.** Roblox Glass hides transparent things behind it (jelly pets, billboards); the r3 globe is already
  SmoothPlastic at .62. Check P7 with a jelly pet behind it.
- **Billboard input.** Moving the pill's board to `PlayerGui` changes its lifetime (respawn, leaving the room); it must
  be destroyed with the nest folder and hidden in Board mode like today.
- **The hold.** If the gate ever failed to clear, the reveal would stall; the 1.0 s cap and the spec cover it. The
  Stat Egg reveal has its own clock (`[verify]` the seam).
- **Turn** may read oddly in translation (context row added); Fable's fallback is `Browse`.
- **Concurrent edits.** The upper-tier builder edits `init.server.lua` and `FeatureFlags.lua` in its own block. This
  plan edits neither (the `/onboard` command and the ceiling already exist). It edits `default.project.json` (one
  entry) and `init.client.lua` (the nest mount block and the intents' send wrapper): merge with care.
- **Haptics** are gamepad-only on Roblox; Fable's phone "light ticks" cannot exist. Sound carries it.

---

## 14. Questions

**For the architect**

- **A1.** Ship slice A before the split (nest at E1 beside the bare dais, everything else on), or hold the corner until
  slice D? I recommend shipping A: the machine, the "?" and the row are what Spencer asked for, and the bare dais has
  no prompt, pin or glass.
- **A2.** Station split in `WorldAssetsNative` (my pick) or server-swapped kit copies of the four island-wide meshes?
- **A3.** Server-placed machine (one replicated model, real collision; my pick) or a client-cloned kit with a server
  collision proxy (the gate docstring assumed client)?
- **A4.** Others' cranks: ship local-only (Fable's fallback); later, a `Crank` attribute on the server's model set by
  the buy handlers, which live in `init.server.lua` (the other builder's file). Agree to defer?
- **A5.** Keep the corner-off path (E1, the row, `Yield.Eggs`, `EggsNest`-free label) until the switch is retired, or
  delete the beta 14 merge code now? I keep it for the flip-back Fable asked for, except the `EggsNest` copy.
- **A6.** The first-time "?" pulse needs a saved coach bit (`nestHelp`): fine to add one under the `nest` part?

**For Fable**

- **F1.** The machine spot: M and M2 sit on / against `Station_BenchWest` (-43, 5). Choose: (a) **M4 (-38.5, 1.5)**,
  (b) remove the west bench in the re-export and keep M (M is also 0.6 off the paving edge, so nudge it in to about
  (-43, 3)), or (c) M3 east.
- **F2.** The marble egg statue at (-42, 9.5) near the machine (and its twin at (-18, 9.5)): keep, or remove in the
  re-export so the machine is the only egg-shaped thing on the west side?
- **F3.** The plaza list in section 2 (and the probe's section C): rulings for the urns, the empty future pads, the
  colonnade and the fallen drum near the corner.
- **F4.** The Show me trail to the nest shows its pin while the egg naps ("Napping egg"); your table allows only the
  ready "Hatch!" pin. Keep the trail's transient pin, or show it only when ready?
- **F5.** The hub star is drawn at (-30, -4) (the paving's middle); your table says (-30, 4). Confirm which you meant
  to keep (both stay; only the label differs).
- **F6.** The buy crank's sounds while the player is far from the machine (the screen opened from the Pocket menu):
  play them (my pick: they are the buy's feedback) or only near the machine?
