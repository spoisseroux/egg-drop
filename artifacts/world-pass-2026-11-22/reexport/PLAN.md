# One world re-export: split crowns, falls shapes, rocks, slice 9 (Opus, 2026-11-23)

Scope: WORLD-PASS-2026-11-22 table row 6 (sections 1B, 1C, 2, 4 step 2, Architect check) and WORLD-PLAN-2026-11-22
slice 9. Spencer approved one re-export (WORLD-PASS question 5). Grove-path edits stay parked on `wip/grove-path`.

## Key decision: an additive "Aero kit", the island export stays byte-identical

Every piece in this row is Aero look, and the architect check already requires the split crowns to be an extra group
behind the ceiling while live keeps the merged crowns. So the whole re-export becomes **one new kit export**, not a
change to the 99 merged island meshes:

- `scripts/build_world_aero_kit.py` (background Blender, reads `world1-mockup-v7-import.blend`, never saves it) writes
  `assets/world/aero-kit/aero-kit.fbx` + `aero-kit-manifest.json` (names, tris, sizes, geometry hashes, pivots,
  instance placements).
- One Open Cloud Model upload (Studio MCP `open_cloud_invoke`, as `world1-v7-import/PLAN.md`), readback of MeshId and
  MeshSize per part with `InsertService:LoadAsset` in Studio Edit (the loaded model is destroyed, never parented,
  never saved) into `aero-kit-readback.json`.
- **Proof gate:** `scripts/build_world_aero_kit_assets.py --confirm READBACK` refuses unless the readback names exactly
  the manifest's meshes, each id is new and positive, sizes finite, and the FBX + manifest SHA256 in the readback match
  the files on disk. Only then it writes `assets/world/AeroKit.rbxmx` (templates, mounted at
  `ReplicatedStorage.AeroKit`) and `src/shared/WorldAeroKit.lua` (placements). Tests like `world_overlap_upload_test.py`.
- `world-v7.fbx`, the manifest, walk json, `WorldAssetsNative.rbxm`, `WorldV7Data.lua` and the native collision proof
  are **not touched**: `python scripts/world_native_collision.py --check` must still pass unchanged. So no native
  rebuild, no 20,920-ray comparison, and live (Aero ceiling off) loads the exact same world.
- "Collision rebuild": the only new collision is the falls rocks (below), done with simple invisible proxies, so there is
  no precise-collision payload to rebuild.

## Kit contents (measured in the import blend)

| Kit mesh | From | Instances |
|---|---|---|
| `Crown_Round`, `Crown_Tall`, `Crown_LiteRound` (dark, `__foliage`) | `Vegetation_Trees__foliage`, split per tree | ~21 |
| `Crown_Blossom`, `Crown_LiteBlossom` (lime, `__foliage_blossom`) | `Vegetation_Trees__foliage_blossom` | ~11 |
| `Crown_Hatch__foliage`, `Crown_Hatch__foliage_blossom` | `Vegetation_HatchTree__*` | 1 (one sway unit) |
| `Rest__foliage`, `Rest__foliage_blossom` | `Vegetation_Bushes__*` (what the merged crown parts hold besides trees) | 1 each, static |
| `Falls_SheetUpper`, `Falls_SheetLower` | new: tapered, wavy sides, bowed 1.5 out (section 4 layer 1) | 1 each |
| `Falls_LipUpper`, `Falls_LipLower` | new foam rolls along the top lip and the ledge (replace AeroFalls capsules) | 1 each |
| `Rock_A`, `Rock_B`, `Rock_C` | new wet boulders, ~60 tris each | 3 split the lower fall, 2 flank, 2 in the pool, 3-4 "break" the pool rim |

- The five shared crowns are one canonical geometry per tree kind. The builder fits each tree's cluster to its
  placement (`vegetation-placements.json`: yaw, scale; translation fitted) and **proves** every instance reproduces
  its slice of the merged chunk (max vertex error under 0.01 stud), so the split crowns are the same leaves in the same
  places. Pivot = the trunk top of that tree kind (`tree_mesh_v7`'s `(c0.x + lean, c0.y, top)`).
- 1B shading: lime crown vertex colours light tops #B8F060 to dark undersides #5FAE2A (render with the lime TextureID,
  no SurfaceAppearance). 1C: the crowns already are 3-6 overlapping puffs; the kit keeps them and adds a thin gloss rim
  only if Fable asks after the first renders (no new puff art without a reason).
- Dark crowns keep the merged part's look (SurfaceAppearance "MatteFinish" with the foliage map) so Aero's foliage tint
  and `/aero off` behave as today.
- No per-crown shadow decals (over the draw budget). Crowns cast no shadow while they move (CastShadow false); trunks
  still do.
- Broken pool rim is done **additively**: rocks seated over the marble ring at 3-4 points (the ring is part of a
  merged marble mesh that also holds the plaza; cutting it would force the full native rebuild). Fable to judge.

## Runtime (client only, like the rest of Aero)

1. **`AeroKit` client module** (new, built by `AeroWorld` when Aero is on, beside `AeroAdditions`): clones the kit
   templates into a local folder `AeroKit` under the room, from `WorldAeroKit` placements. It hides the merged
   `W7_Vegetation__foliage`, `W7_Vegetation__foliage_blossom` and `W7_Water__waterfall_tumble` through AeroWorld's own
   records (`Transparency` 1, put back exactly on off / room gone). Budget level 2: kit dropped, merged parts back.
   AeroWorld watches the `AeroKit` folder too, so `paintCrown` (lime map / coral) and the foliage tint paint the split
   crowns by name exactly as they paint the merged ones.
2. **Sway:** `WindClient` gets a second kind, `crown`, bound from the `AeroKit` folder (attribute `WorldDressing=
   "crown"`, `WorldRestCFrame`, `WorldPivot` = trunk top). Crown pose: rest 1.2 degrees at the breeze, 4 at full wind,
   plus a lean of up to 1.5 degrees downwind that follows the gust, own period 3.4-4.6 s (seeded from the pivot). The
   Hatch crown's two parts move as one unit. One selection across both kinds under the existing caps (phone 16 within
   120 studs, desktop 44 within 200), one `BulkMoveTo`. Same ease, Reduced Motion, parked and budget rules as bushes.
   `WorldMotion.sway` is not used for crowns (WindClient already pivots at a base), so it is left unchanged.
3. **Followers:** `DashFade` fades the split dark crowns in its zone (the merged mesh is hidden while the kit shows).
   GardenLife birds on a crown top and hanging Dewdrops ride the crown: WindClient exposes `offsetAt(position)` (the
   current pose delta of the crown whose pivot is nearest within 8 studs), GardenLife applies it.
4. **Falls fit:** `AeroFalls` strands and ribbons follow the bowed sheets (`CurveSize0/1` out by the bow, `out` from
   the bowed face); the lip capsules are replaced by the kit lip meshes when present.
5. **Rocks:** kit MeshParts (no collision, `CanQuery` false) plus one invisible `Ball` proxy each (collide, no query,
   no touch) in the same local folder: the local player can't walk through them; pets never reach them because every
   rock footprint is inside the `Water_Pool_Falls` wet box or on cliff cells (spec-checked), so the pets' walk grid is
   unchanged. Rock tops stay low enough that no new climb onto the walled cliff exists (Studio jump test).
6. **Slice 9:** marble and marble_smooth maps drawn down to mean #E6ECF2 and the palette map at saturation 1.0
   (`PALETTE_SATURATION` 1.0 equivalent) are uploaded as images and written by `WorldAero.Surfaces`
   (`TextureID`) under Aero. Cloud and foam are already white under Aero (`Surfaces.cloud/foam`): verified, no change.

## Edge cases

| Case | Behaviour |
|---|---|
| Aero off / live place / `/aero off` mid-session | No kit; merged crowns and falls exactly as today (records restore) |
| Aero on, wind off (`/alive wind off`) | Split crowns shown still |
| Reduced Motion | Crowns at rest at once |
| Budget level 2 | Kit dropped, merged parts back (fewer draws) |
| Kit templates missing (not mounted, old build) | One warning; nothing hidden |
| `/aero coral` | Lime split crowns repaint coral via `repaintCrowns` |
| Room rebuilt / streamed | Kit rebuilt on the new room; old one gone with it |
| Bird or fruit over a crown out of the sway cap | offset is identity |

## Not in this slice

Per-crown shadow decals (budget). Cutting the marble pool ring (needs the native rebuild). Sky Falls shape (step 2 is
Tumble only). Store art (Aero is still beta only). Any publish (Spencer is testing beta (12); ask first).

## Test plan

- Python: kit builder fit proof (per-instance max error), proof-gate tests (wrong names, stale SHA, old ids, missing
  rows refuse; valid passes; outputs untouched on refusal), `world_native_collision.py --check` still PASS.
- Offline specs: `Wind` spec extended (crown pose: rest/peak/lean numbers, pivot, period range, shared cap with
  bushes, Reduced Motion rest, restore exact), new `AeroKit` spec (placements count, hide/restore of merged parts via
  records, level 2 drop, rocks inside wet box or cliff cells, no rock within 4 studs of any Dash checkpoint / find spot /
  station), `AeroFalls` with bowed sheets, `DashFade` with split crowns. Full `run_dash_server_specs.py` green.
- `sweep_island_edges.py` rerun: identical output expected (no ground moved); `IslandBounds.Walls` unchanged;
  `build_find_spots.py --check` / `build_life_spots.py --check` unchanged.
- Studio (Edit + Play on the place file, no save): split crowns overlay the merged ones exactly (toggle compare
  captures), crowns sway in a gust and rest under Reduced Motion, `/aero off` restores, draw calls and triangles before
  and after (`Stats`), rocks block the avatar and can't be used to climb, falls captures from the same cameras as
  `artifacts/world-pass-2026-11-22/` (`waterfall.jpg`, pool edge, hub) and tree captures (`lime-tree.jpg`, `lime.jpg`).
- Fable review of captures (look), Code Reviewer GO.

## Risks

- Instancing: same mesh + same SurfaceAppearance should batch; measure draws, not assume.
- Client-side rock collision affects only the local avatar (every Aero client has the same rocks).
- Hiding a merged part through `Transparency` while `DashFade` writes `LocalTransparencyModifier`: different
  properties, no fight.
- Upload moderation delay on the kit model.

## Measured in the import blend (2026-11-23, background Blender, read only)

Rebuilding `W7_Vegetation__foliage`, `__foliage_blossom` and `W7_Water__waterfall_tumble` from the import chunks
(declutter + QA fixes, the chunk script's own functions) gives the **exact shipped geometry hashes**
(d193ab5cffb4fda3, 33c5209953f4b5a3, 3344a0753c7a5af0). The island has **20 trees + the Hatch Tree**, not 31 (the
Lite trees are on the islets, which keep their own bobbing meshes): Round 7, Tall 5 (dark), Blossom 8 (lime, including
the Blossom Point tree at scale 1.7). So **3 shared crown meshes + the Hatch crown = 21 sway units**, not 5 meshes / 24.

## Architect review (Software Architect, GO WITH CHANGES) and what changed

| Original | Revised (reviewer's point) |
|---|---|
| Hide merged parts through AeroWorld's surface records | Own `hidden` records, restored only by the kit's drop, Aero off and room gone (1: `repaintCrowns`, refusal and `sweep` would bring the merged crowns back) |
| Kit parts named freely, AeroWorld watches `World`/`WaterFlow` | Kit parts named `W7_Kit_<Name>__<material>`; `watch` and `repaintCrowns` include the `AeroKit` folder (2) |
| Server Tumble beams stay | Tumble `WaterFlow` sheet beams switched off through `hidden` while the kit sheets show; motion comes from AeroFalls' layers (3) |
| 3-4 rim rocks on the marble ring | Only on cells pets cannot walk (wet / rock / none); the spec checks every rock against `world-v7-walk.json` (4) |
| Kit crowns plain parts | `WorldMesh=true` on every kit visual, so greeting-shot and bounds queries skip them as they skip the merged meshes (5) |
| Templates in ReplicatedStorage | Mounted in `ServerStorage.AeroKit`; the server clones it to `ReplicatedStorage` only when `Aero.ceiling()` passes (6: live clients never download it) |
| 16 kit meshes | Sheets, lips and rocks are one vertex-coloured `Falls` mesh; crowns 4, rest 2: 7 meshes, minus 3 hidden = +4 draws at worst (7) |
| One shared cap | Fixed quota per kind inside the existing cap: phone 10 bushes + 6 crowns within 120 studs, desktop 32 + 12 within 200; parts counted (Hatch = 1 unit, 1 part) |
| `offsetAt` for birds and fruit | Dropped: they hover (about .5 stud at peak) |
| Gate: names, new ids, SHA | Also refuses ids already used by the island (`world-v7-studio-import.json`, collision import, dressing), records moderation state, checks every raw MeshSize is the manifest size times one uniform import scale, and a test proves `WorldAssetsNative.rbxm` and the native proof are unchanged |
| DashFade fades `W7_Vegetation__foliage` | Also looks in the kit folder and fades the split dark crowns in its zone |

## Result (2026-11-23)

- **Kit r5**, Model 108202274856277 (operation 37ad92ca-c3c8-4626-bcd3-6b129b0c8c79, Approved): 8 meshes, 3,016 triangles.
  Crowns: Round x7, Tall x5, Blossom x8 (incl. Blossom Point at 1.7), Hatch x1 = 21 sway units on 4 meshes, each
  proven within 0.01 stud of its tree's leaves; Rest (bushes) x2; Falls = `W7_Kit_Sheets__waterfall_tumble` (today's
  texture and mapping, bowed 1.5 along the fall on the beam curve, CurveSize 2) + `W7_Kit_Falls__kitwater` (lips and
  10 rocks, vertex coloured). Earlier uploads r1-r4 are superseded (r2: flat bow fought the strands; r3: random face
  normals read as blocks; r4: before Fable r1).
- Gate: `build_world_aero_kit_assets.py --confirm` passes; `world_aero_kit_test.py` 10/10; native checkpoint PASS
  unchanged (`68118c32...`, 325,290 bytes). The island export, WorldV7Data and walk map are byte-identical, so the
  edge sweep reran identical (`sweep_island_edges.py --check` exit 0) and FindSpots / LifeSpots are current.
- Draws: merged crowns 2 + tumble 1 hidden; kit adds 8 meshes (crowns batch per mesh) = +5 at worst, +0 shadow casters
  net (crowns and falls cast none; the 2 rest meshes replace the 2 merged crown casters). Triangles: crowns and rest
  equal the merged parts exactly; falls +1,228 over today's sheet (under the +1,500 cap).
- Slice 9: palette at saturation 1.0 (`palette-aero.png`, image 121108587763392) under Aero. Marble: Fable kept the
  grounded grey as is (it is already darker than #E6ECF2). Cloud and foam were already white under Aero.
- Studio (Play, place file, no save): kit built under Aero, merged crowns / tumble sheet / server sheet beams hidden;
  split vs merged crowns identical in the same frame; 12 crowns sway on desktop quota, peak tilt 5.2 degrees.
  Specs: offline suite 34 PASS + AeroFalls 22 + AeroKit 6; Studio WindClient 25, AeroWorld 27, AeroKit 6.
- Fable: R1 GO WITH CHANGES (rocks darker and varied, lips trimmed), R2 **GO** for the beta
  (`FABLE-REVIEW-R1.md`).
- Code Reviewer: GO WITH CHANGES, all applied: late-arriving merged parts and sheet beams are re-hidden on the queue
  flush; hides go through the folders the layer watches; the kit's meshes are preloaded (ContentProvider) before anything
  hides, and the additions rebuild once the kit stands; the gate takes only "Approved" and refuses a missing island
  import; the readback recorder can bind the pre-upload FBX digest (`--uploaded`). Studio specs rerun green.

**Not verified:** phone frame time and draw counts on a real device (Stats draw calls are not readable from scripts);
motion clip; a pet at the pool; an avatar jump test on the rocks (the Studio client sits on the deck; rock tops stay at or
under 4.7, the ring and shore height, and the two high ones are on the walled ledge).

**Before live (Fable R2):** the Ribbon layer shows a thin bright line down both tiers (a step-1 layer; fade its ends or
trim it to each sheet); hide the old mossy rock on the ledge pool under Aero if cheap.

## Round 2 plan (Spencer's beta (12) QA, Fable LOOK-R2.md)

All Aero-only, through the same kit and gate (one more upload, r6). Nothing on live.

1. **Matte crowns.** Lime kit template gets its own SurfaceAppearance (ColorMap = lime map, RoughnessMap = flat grey
   235 = 0.92, metalness 0). AeroWorld.paintCrown leaves a kit crown that carries `AeroMatteLime` alone for lime (no
   parking); coral still parks it and goes flat. Dark crowns already sit on roughness 1.
2. **Near fade (clipping).** `AeroKit.fader`: every .15 s, Room mode only, camera inside a crown's box + 1.5 studs ->
   LocalTransparencyModifier toward .8 (.25 s in, .4 s out); only the avatar's root inside -> .5. Outside Room mode
   (deck, Dash race: DashFade owns that property then) it puts every crown back to 0 and writes nothing. Started by
   AeroWorld.standKit, stopped by dropKit.
3. **Falls rework (kit mode only; without the kit today's step-1 layers stay).** Kit mesh: the Sheets mesh goes; the
   Falls mesh gets a dark wet rock face (3 ledges per drop, .6-1.2 proud) and 5 static white chutes per drop on the
   beam curve (bow 1.5), lips dropped, rocks kept. AeroFalls kit stack: Flow A, Flow B (curved beams, new drawn maps
   `fall-white`, `fall-veil`), a flat apron beam (`foam-streak`), boil and droplet emitters (`spray-soft`, speck),
   quieter pool mist; no strands, ribbon, lips, rings or rainbow. Pool FlowSkin to #3BA3BE under Aero.
4. **Fountain.** Kit mesh `W7_Kit_Fountain__kitstone` (stem, upper bowl, finial, water disc; vertex-tinted stone on
   the marble map, moss band), inside the existing spring basin at (52, 3); `W7_Bubbles__bubble` joins the hides.
   `AeroFountain` in the additions: jet, spill and splash emitters (level 1 keeps the jet), a positional
   `water_bed_loop` voice at pitch 1.25, volume .16, InverseTapered 5..26 (an original `fountain_loop` later).
5. **Crown reshape and leaf tiles** (LOOK-R2 step 5): after 1-4 are seen; may stay a follow-up.

Draws: kit +1 (fountain) with Sheets removed (net 0 for the kit); falls layers 14 -> 9; fountain emitters +3 within
range. New drawn textures uploaded as images. Every new piece follows Reduced Motion and the budget levels.

## Round 2 result (2026-11-23, Spencer's beta (12) QA)

- **Kit r9**, Model 125352578844438 (operation 9f0fb6c4-8e24-425f-94db-f2810ca11826, Approved), through the gate:
  8 meshes. Falls: dark slate rock faces with ledges + three white chutes per drop with short staggered slits, bow .5,
  ledge kink .3, wet rocks; the striped sheet and lip bars are gone. Fountain (new): a two-tier stone fountain,
  5.2 tall, 16 sides, marble with a moss band, its own round rim and teal water over the old octagon basin; the spring's
  glass bubbles, its old water and the falls' faceted foam mesh are hidden under Aero (Sky Falls loses its foam blob
  too: it keeps its step-1 layers and the server's splash). Lime crowns: their own SurfaceAppearance, roughness .92,
  tinted to #86BE3C (matte, no gloss). Crowns fade to .8 when the camera is inside one (roam camera only).
- Falls layers under the kit (AeroFalls.kitStack): Flow A (`fall-white`) and Flow B (`fall-veil`) flat beams at
  1.0 / 1.2 in front of the chutes, a flat foam apron, boil, droplets, quiet mist; 9 draws, 4 at level 1.
  **Found:** a Beam lays its width along its attachments' SecondaryAxis; AeroFalls gave "up", so every step-1 strand
  and ribbon has stood edge-on since beta (10) (a thin line, the reason Spencer saw no strands). The kit's beams take the
  sheet's width there; the step-1 stack is unchanged (it only shows without the kit).
- Fountain: jet, spill and splash emitters (squashed streaks), a `water_bed_loop` voice at pitch 1.25 through
  AmbientAudio (ambience mix, ducks, round fade), 5 to 26 studs. An original fountain loop is still owed.
- New drawn maps (scripts/draw_aero_falls_textures.py): fall-white, fall-veil, foam-streak, spray-soft, speck,
  roughness-92; uploaded as images.
- Reviews: Software Architect GO WITH CHANGES (fade gate, bubble restore order, voice through AmbientAudio, crown
  exemption, distinct level-1 flags; all applied). Fable LOOK-R2 rounds 3-5: falls NO-GO, then GO WITH CHANGES, then
  **GO** for the beta; fountain and lime crowns GO. Code Reviewer **GO** (two hardening notes applied).
- Checks: offline suite 34 PASS + AeroFalls 22 + AeroKit 7; Studio WindClient 25, AeroWorld 27, AeroKit 7;
  world_aero_kit_test 10/10; native checkpoint PASS unchanged; sweep identical; FindSpots / LifeSpots current.
  Captures: `r4/` (pool-edge, falls-wide, fountain-5, fountain-15).
- **Not done / not verified:** crown reshape and leaf tiles (LOOK-R2 step 5); the pool part's own cobalt texture (needs
  a new Aero pool map, Fable's top next item); chute slits .15-.3 (another upload); a 5 s clip, a pet in the pool, a
  phone frame and draw counts on a device; the fountain voice heard by Spencer; the near fade seen in Room mode (spec
  only: the Studio client sits on the deck). The AeroFalls Studio run stops at a pre-existing firefly float check
  (line 504, garden hour); offline it passes.
