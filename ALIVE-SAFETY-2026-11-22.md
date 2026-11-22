# Alive safety review (Opus, 2026-11-22)

Scope only; source read, nothing run. Budgets are proposals: **no baseline exists**. Client files unless stated.

**Verdict:** safe if state changes first and motion is paint, panels move before they scale, and bushes sway before trees.

## 1. Spring

- New `KitSpring.lua`; DeckKit exposes `Kit.spring`. Nothing in `init.client.lua`: 223 column-0 locals against a 219 budget (`ClientLocalBudget.spec:10`), so that spec looks red at HEAD.
- State `live[object][property]={x,v,goal}`, removed at rest. One analytic RenderStepped step, connected only while moving, dt capped at 1/20.
- Retarget keeps x and v; after a foreign write, adopt it with v=0.
- Destroyed: drop. Hidden, covered, closed: `Kit.springSettle(root)` snaps. Reduced Motion snaps all, even mid-flight.
- Cap 24 live on phones, 48 desktop; extras snap. 0.3 ms p95.
- One writer per property. `Kit.tween` (DeckKit:197) keeps no handle: register it so either cancels the other. `boing` (:879), tabs (:1233), TapScale (:1484) and wallet Pop (:1451) use raw tweens: migrate whole or leave.
- Layout: never scale UIListLayout children (SnackTray:115, QuestLog:235) or animate CanvasGroups (FaceplateShop:113); overshoot at most 4 px in ScrollingFrames.
- Spec switch settles instantly; specs wait 3 heartbeats (CompanionsHub.spec:12).

## 2. What breaks

**Panel scale .92**
- Panels already own a fit UIScale (CompanionsHub:224, MachineHub:302, BookView:225, StoreView:519, EggHatchView:878) that `fit()` rewrites.
- AbsoluteSize fires every frame: EggHatchView:187 **rebuilds its list**; CompanionsHub:257 repaints its ViewportFrame; EggPreview3D:146 and HueEggView:189 refit; guardText (DeckKit:275) flips truncation for translated players.
- Focus ring divides only by its host's UIScale (DeckKit:1551). HueEggView:2096 mixes scaled and unscaled units.
- Phones grow from the top-left; CompactPhone.spec's 44 px audit fails (44 x .92 = 40).
- **Instead:** 12 px springy rise on `root.Position`. Scale later, desktop only, multiplied into the fit.

**Stagger:** `slideIn` owns body children's Position (DeckKit:2311). Pop the art only; never hide, move or disable a hit rect, so focus and visibility pumps (CompanionsHub:507, WardrobeShop:567) stay right.

**Closes:** `Visible` is open state. Delaying it makes `closeAllMenus` return false (init:1776) and the store refuse (:1851), fails MachineHub.spec:298, holds ModalCursor's movement lock, reorders `onClosed` routes (init:1088, 1553), and leaves a shade eating taps.

**Yes, ghost only:** close exactly as today, then draw one pooled blank plate in its own ScreenGui with Interactable, Active and Selectable off, .12 s. Only if the shade stack is empty a frame later; never for `store`, `forced`, `machine`, `destroy`. No clones; `CelebrationKit.detach` (:384) reparents, so unusable here. Precedent: PocketMenu:161.

Focus attaches on frame one; wallet taps never wait; round or hatch start calls `springSettle`. `coachMask` is save bits, not an overlay: unaffected.

## 3. Trees

Crowns: 3,660 + 2,020 triangles in two parts, no collision or query, casting shadows. Placements minus declutter give 31 trees plus the Hatch Tree; AmbientPerches lists 34, so check for stale ones. `WorldMotion.Range` 900 culls nothing locally; `sway` pivots at the **top** (`build_world_v7_assets.py:332`), wrong for trees; it scans only `room.World`, so bushes need binding.

| Option | Cost and risk |
|---|---|
| A. Unique crowns | Up to ~32 draws; every upload through the proof gate |
| **A2. 5 shared crown meshes** | Same mesh and SurfaceAppearance can batch; gains culling and LOD; authored edits may differ |
| B. One skinned mesh | ~32 bone writes; island bounds never cull; new pipeline, cluster-rebuild risk |
| C. Keep crowns, add tufts | No export; mesh tufts, since alpha cards overdraw |

Moving crowns cast no shadow (trunks do) and keep `WorldMesh` (RoomView:852). Visible birds read `Wind`, or they float. Check streaming (not in the repo).

**Blocker:** world pipeline scripts hold uncommitted path-reroute edits. Commit or shelve before exporting.

**First prototype:** client gust on the 44 bushes (separate, non-colliding, shadowless; `LoungeWorldV7Art.lua:327`), beta only. Then C, then A2.

## 4. Phone budget

| | Hold |
|---|---|
| Frame | p50 33 ms; p95 within 1 ms of baseline |
| Wind | 0.4 ms p95, 60 parts, 120 studs, 30 Hz |
| Scene | +10 draws, +1,500 triangles, +0 shadow draws |
| Idle UI | 0 live springs |
| Memory | +8 MB |
| Open | no new 50 ms frame |

Measure with `ZZSpecs/DeckPerfProbe.lua` (git-excluded: commit a copy) and `scripts/CareLoadingPerf.lua`'s alternating pairs. Add `Stats` scene, shadow and UI draw counts and triangles. Finish on a real phone.

Step-down (5 s windows, ignoring joins and refocus): p75 over 40 ms twice gives 15 Hz and 60 studs; again gives stillness, no particles, no stagger. Never back up that session. Rest outside Room mode.

Kill switch: per-feature `FeatureFlags` as ceiling, **plus** server `ConfigService` copied to workspace attributes (new here; docs: server-only, about 15 to 60 s, needs `Refresh`). Missing means off; off settles at once. v1054 left running servers alone, so publishing is no kill switch.

## 5. Outside assets

- Scratch place only: live v1054 **was** a Studio autosave (PLAY-BUILD:37).
- Strip scripts, constraints, sounds, hidden children; pass through Blender.
- Commit source, author, licence, date, SHA, our asset id. No licence, no use.
- Upload as game owner; await moderation; grant both universes; test another account.
- Textures 256 or less. "Original art only" was loosened 2026-11-22 ("Allow some"): V3-SCOPE 12.9.

## 6. Rollout

| Slice | Contents | Gate |
|---|---|---|
| 0 | Probe, flags, config, baseline, locals | Off is identical; config proven on beta |
| 1 | Spring, press, tabs | KitSpring.spec (new), KitSurfaces, SharedHeaders |
| 2 | Rise, art stagger | CompanionsHub, MachineHub, BookView, UIShellQA, CompactPhone, ControllerSheets |
| 3 | Close ghost | StarsStoreAccess, StarsRoute, HatchNavigation, MovementLock |
| 4 | Wind, bushes | Wind.spec (new), WorldDressing, phone pair |
| 5 | Tufts, petals, life | Caps, Reduced Motion |
| 6 | A2 crowns | Native proof, WorldRoutes, GardenGreyboxWorld |
| 7 | Desktop scale, optional | Listener guards |

Each: own commit and flag, full suite, beta, phone, live. Revert: flag off; slice 6 keeps merged crowns in ServerStorage for new servers.
