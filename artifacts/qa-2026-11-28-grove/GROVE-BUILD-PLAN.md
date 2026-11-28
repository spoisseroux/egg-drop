# Hidden Grove: build plan (Opus, 2026-11-28)

Spencer, 2026-11-28: canopy opening "is good now"; tree houses "leave as scenery". "Build that new world." Art target: `GROVE-MOCKUP.md` and its renders. Beta first, behind a switch; live untouched.

## Goal
The playable island is unchanged (collision, routes, stations, Dash course, walk map). Around it, behind the Aero look and a new switch `grove`, the client builds the hollow: moat, three cliff tiers with ledges and four waterfall gorges, nine giant trees whose crowns frame the sky opening (sun gate SE), six scenery tree houses with rope bridges and lantern strings, the far forest rim, animated god rays, motes, a few bubbles, night lanterns. The floating-island backdrop (cloud meshes, far peaks, drift rocks, islets, underside) hides while `grove` is on.

## Pipeline (the Aero kit's, proven)
1. **Art (Fable lane):** `scripts/build_world_grove.py`, headless Blender (`blender -b --factory-startup --python ...`), procedural geometry from `artifacts/qa-2026-11-28-grove/source/grove.py` productionised: merged meshes by role, origin at bounds centre (instanced pieces at their root), coordinate rule Blender (x, y, z) = Roblox (x, -z, y - 4) as in grove.py (state it in the manifest), each mesh ≤ 10k tris (Roblox MeshPart limit 20k), ring total ≤ 45k tris on screen, ≤ ~40 draw calls. Four tiling 1024 texture sets baked procedurally (stone, moss, bark, leaf atlas; colour only, plus normal if MeshPart can take it via SurfaceAppearance *authored in Studio*, otherwise colour TextureID only). Writes `assets/world/grove/grove.fbx`, `grove-manifest.json` (meshes {name: role, kind, size, tris, center|pivot, texture}, instances [{mesh, pivot, yaw, scale}], rays [{from, to, width}], lanterns [{pos}], falls, bubbles paths), `assets/world/grove/tex/*.png`, and review renders.
2. **Upload (primary agent, Studio MCP):** FBX as one Model via Open Cloud; PNGs as Decals → image ids. MeshIds / MeshSize read back in Studio Edit.
3. **Data (Opus lane):** `scripts/build_world_grove_assets.py` → generated `src/shared/WorldGrove.lua` (like `WorldAeroKit.lua`), placeholder-safe (empty assetId = nothing built).
4. **Runtime (Opus lane):** `src/client/GroveWorld.lua` builds the ring client-side once (Anchored, CanCollide/CanQuery/CanTouch false, CastShadow false beyond the moat, RenderFidelity Performance for far band), instanced giants/crowns, `GroveLight.lua` for the ray Beams (7-9, LightEmission 1, transparency ~.8, TextureSpeed .02-.05, faded by GardenHour daylight, cool cyan at night from the moon), one mote emitter per ray (6-10 alive), 3-5 slow bubbles, night lanterns Neon + the four nearest lit (the balloons' rule), SunRays .03 → .08 only facing the sun gate. Budget levels: 1 drops motes and half the rays; 2 drops rays, vines, set dressing. Reduced Motion: rays still, no motes or bubbles.
5. **Switch:** `Grove` shared module on the `Aero` pattern (FeatureFlags ceiling = beta place or Studio; ConfigService `grove_world`; workspace attribute `GroveWorld`; owner chat `/grove on|off|clear`). Needs Aero on. Off = today's backdrop exactly.
6. **Backdrop:** while on, hide the six cloud meshes, far peaks, drift rocks, islets, underside (WorldMotion's islets and rocks stop stepping); balloons (DriftLanterns) capped below the crowns; Sky Falls lands in the moat (its fall length extended or a splash at the moat).

## Edge cases
| Case | Expected |
|---|---|
| `grove` on, assets not uploaded (assetId "") | nothing built, backdrop stays (never an empty sky) |
| Toggle off mid-session | ring destroyed, backdrop restored, rays and emitters gone, no leaked connections |
| Phone, budget level 2 | ring meshes only, no rays/motes/vines/dressing |
| Night | lanterns/windows glow, rays cyan, Bear stays above WorldNight floors |
| Dash race | the course untouched; racers see the ring |
| Players walking the rim | collision unchanged; nothing of the ring is collidable or queryable; camera never clips into tiers (nearest tier ≥ 45 studs past the rim) |
| StreamingEnabled | ring is client-built, not streamed; check memory on phone |

## Not doing
Reachable tree houses; changing the island mesh, walk map or collision; live; store thumbnails (when it goes live).

## Tests
Offline specs: `Grove` switch resolve; `WorldGrove` data shape (budgets: total tris ≤ 45k, per mesh ≤ 10k, ≤ 40 meshes+instances groups, every instance names a mesh); `GroveLight` pure parts (ray fade by hour, budget-level counts, reduced motion). Studio: Play from each lawn and the spawn dais, look round 360°, the sky opening, the sun gate, dusk and night, phone 812x375 frame rate with everything on, `/grove off` restores the old sky.

## Risks
Triangle and texture memory on low-end phones; MeshPart import scale/orientation (the pi turn, `fbx-import-pi-turn` memory); unique template names per pack (`world-finish-template-names` memory); camera near the rim seeing tier seams; beams through crowns looking like planks from the side.
