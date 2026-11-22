# Alive build plan, steps 0 to 4 (Opus, 2026-11-22)

Spencer: "build that overnigth, test agentically, dont break anything that already works, have proper fallbacks, handle client server interactions well etc". Scope `V3-SCOPE-2026-11-21.md` 12.8, `ALIVE-BRIEF`, `ALIVE-SAFETY` (safety wins). **Beta only; live untouched.** No saves, remotes, prices, world export or server gameplay change.

## Rule zero

With every Alive flag off the game behaves exactly as at `6696339`. State changes first; motion is paint on top and may be cut at any frame. No tap, focus move, route, `onClosed`, shade, `Visible` write or input path is delayed, reordered or made conditional on motion. Hit rects never move or resize.

## Step 0: flags, off switch, probe

- `FeatureFlags`: `AliveSprings, AliveMenus, AliveClose, AliveWind = true` (build ceiling).
- `src/shared/Alive.lua` (pure, both sides): `Alive.Features = {"springs","menus","close","wind"}`, `Alive.attribute(f)` ("Alive_" .. f), `Alive.key(f)` ("alive_" .. f), `Alive.ceiling(f)`, `Alive.resolve(f, configValue, override)`: ceiling false is false; else override if boolean; else configValue if boolean; else true. Malformed config (string, number, nil) counts as missing. `Alive.on(f)`: ceiling and `workspace:GetAttribute(attribute) ~= false` (missing means on: the shipped default). `Alive.changed(f)` signal.
- `src/server/AliveConfig.lua`: writes all attributes synchronously at start (before any yield), then reads `ConfigService:GetConfigAsync()` in pcall with backoff 5, 15, 60, then every 300 s until it loads; `UpdateAvailable` then `Refresh` (pcall, at most one per 5 s), re-resolve. A failed or errored snapshot keeps the last good values. Never blocks boot or PlayerAdded; a throw anywhere cannot reach the caller. Overrides: owner-only chat `/alive <feature|all> <on|off|clear>` on the beta place and Studio only, same gate as `/stars` (init.server ~816), server-wide for that server.
- Client: only reads attributes. Turning a feature off mid-session settles live springs, ghosts and wind to rest within one frame.
- `src/client/AliveBudget.lua`: frame p75 over 5 s windows (ignores the first 20 s, refocus, Studio, deck rounds); over 40 ms twice: level 1; again: level 2; never back up that session. Pure `Budget.step(samples, state)`.
- `scripts/AlivePerfProbe.lua` (Studio/QA only, never shipped): alternating off/on windows, frame p50/p95, script ms for the stepper and wind, draw calls and triangles from `Stats` where readable, memory.
- `init.client.lua` column-0 locals from 223 to 219 or fewer by inlining requires used once; no behaviour change (`ClientLocalBudget`).

## Step 1: `src/client/KitSpring.lua`, presses

- `Spring.to(object, property, goal, {frequency, damping, velocity, done})`, number, Vector2, UDim, UDim2; analytic damped step; `live[object][property]` removed at rest; one RenderStepped connection only while something is live; dt capped 1/20; destroyed or unparented objects dropped; hidden ancestors settle; foreign write adopted with v = 0; cap 24 touch / 48 desktop, extras snap to the goal; `Spring.settle(root?)`, `Spring.cancel(object, property)`, `Spring.count()`. Reduced Motion (also when switched on mid-flight) snaps all. `Spring.Instant` for specs.
- `Kit.spring(object, property, goal, options)`: flag off or Reduced Motion: exactly today's `Kit.tween` call (time and style in options). On: cancels any Kit tween on that object+property first, and Kit.tween cancels a spring on it. `Kit.Motion.bounce = 1` scales overshoot (0 = none).
- Uses: button release (Content and Fill Position overshoot 2 px up; Fill widens at most 2 px a side on press, only when a ledge exists and the key is 60 px or wider), tile release, toggle knob, tab pill (clamped in the track, always ends on `pillRect`), `Kit.boing` (.94, 5 Hz, .45; objects under a UIListLayout or UIGridLayout keep today's numbers), wallet star hop 8 px on a gain (2D and 3D star; hops merge within .3 s). Press down stays a .06 s tween.

## Step 2: `Kit.arrive`

- Replaces the 8 px .16 s rise at each call site that has it (CompanionsHub, MachineHub, BookView, WardrobeShop, StoreView, EggHatchView, Stats, Names, PocketMenu...: grep) with a 12 px spring rise (3.2 Hz, .55) on the same Position property under the same conditions (`slideFrom`, rebuilds, phones that skip it today keep skipping). Never adds motion where there was none on phones' full-screen sheets.
- `Kit.artPop(objects)`: icon discs and 2D art only (never an object that contains or is a ViewportFrame, ScrollingFrame, CanvasGroup, text, or already has a UIScale; never a child of a list/grid layout); scale .85 to 1, 25 ms apart, first 8 visible, done by .35 s; never replays on refresh, scroll, resize or tab re-select; cut at budget level 2, on round/hatch start and on close.

## Step 3: `Kit.depart`

- Called at the very start of a real close by a player (`close`, `back` or nil reason) while still visible; records absolute rect, radius and shell colour. The close then runs exactly as today. On the next Heartbeat, only if the shade stack is empty and no other screen opened: one pooled plain plate in its own ScreenGui (Interactable, Active, Selectable false; below toasts) goes from .35 transparency to 1 and shrinks 4% in .12 s. Never for store, forced, machine, destroy, hatch, round start, route-to-child.

## Step 4: `src/client/Wind.lua`, `WindClient.lua`

- `Wind.at(position, time)` 0 to 1, pure, deterministic from gust number; time `workspace:GetServerTimeNow()`; numbers from ALIVE-BRIEF section 3. `Wind.Strength = 1`.
- Followers: the bushes (`LoungeWorldV7Art` dressing; client binds, pivots at the base, rest 1.5, peak 6 degrees; rest CFrame kept on the client; re-bind on stream-in, late parts, room replaced; `BulkMoveTo`, 30 Hz, nearest 16 on touch / 44 desktop, 120 / 200 studs; out of range eases to rest, never pops); pennants and flags x1.8, chimes x2.5 inside `WorldMotion` (flag off: today's pose values bit for bit); rustle loop (Fable) 2D through the ambience group, 0 to .10, 2 voices at most, obeys the Ambience setting, missing or unloaded asset is silent.
- Room mode only: parked in deck rounds and hatches, kept behind menus. Budget level 1: 15 Hz and 60 studs; 2: still. Reduced Motion: motion 0, rustle stays.

## Edge cases

| Case | Expected |
|---|---|
| ConfigService missing, throws, slow, returns a string | Shipped defaults; boot unaffected |
| Attribute never replicates | On (default), no error |
| Feature off mid-spring / mid-gust / mid-ghost | Settles in a frame, exact rest values |
| Open, close, open within 50 ms; B spam; rebuild on resize mid-rise | Ends on the exact rest Position; one screen |
| Two players | Same gust at the same place within replication clock error |
| Join mid-gust, respawn, room rebuilt, streaming out and in | Followers re-bind; no drift from rest |
| Reduced Motion toggled live | Still at once |

## Tests

New: `KitSpring`, `Alive` (shared/client), `AliveConfig` (server, fake service), `AliveBudget`, `KitArrive`, `KitDepart`, `Wind`, `WindClient`. Each suite also runs with all flags off. Then every existing client and server spec on this build versus HEAD (a failure is ours unless it fails the same on `6696339`). Agentic play: Bear save, open/close every screen by mouse, keys and gamepad, spam, resize to phone, round start from a menu, hatch, store, wallet; `/alive` off and on live; two-client Studio session for gust agreement and attributes. Perf pairs from the probe. Output log clean.

## Work split

- **UI** (steps 0 to 3): `FeatureFlags, Alive, AliveConfig, AliveBudget, KitSpring, DeckKit`, screens, `init.server` chat line, `init.client` locals, specs, probe.
- **Wind** (step 4): `Wind, WindClient, WorldMotion`, `AmbientAudio` rustle hook, specs; mounts from a do-block or `clientUI`, no new column-0 local; codes against the `Alive` contract above.
- **Fable**: rustle loop, later the review of real captures.
- One owner of Studio at a time (the integrator). Workers do not touch Studio, Rojo or git.

## Revisions after the architect review (2026-11-22; these win over the text above)

1. **Ceiling** = flag AND (`game.PlaceId == 107705084891479` or Studio). The place id constant lives in `Alive.lua`. Nothing Alive can run on the live place until that line changes.
2. **Missing:** a missing or malformed config key means the shipped default (on). On the client a missing attribute means **off** (`Alive.on` is `== true`): AliveConfig writes explicit booleans, so absence means there is no kill switch. Existing specs then run the old paths unless they set the attribute.
3. **AliveConfig** runs in one pcall'd `task.spawn` (require, GetService, start). `/alive` is its own `player.Chatted` connection, outside the `/stars` handler's board and busy checks, same owner and place gate.
4. **`Kit.tween` registry:** when a spring takes one property of a live multi-property tween, write that tween's other goals first. With the flag off never cancel anything.
5. **Presses:** one scalar `drop` spring per key or tile; its setter writes Content, Fill, PaddingTop, PaddingBottom and TileLip together (top = -bottom always). Cancelled in `setTileLip`, disable, hide and destroy, landing on exact rest.
6. **Foreign write:** cancel the spring, never keep the old goal. Detect by comparing with the value **read back** after our own write (Scale is float32, offsets are integers).
7. **Flag-off bodies stay verbatim** for boing, tabs and wallet (an `if` around them). In tabs `done` fires exactly once on rest, snap, settle and drop.
8. **Boing** growth is capped at 4 px a side and never shrinks a hit rect under its rest size by more than today's 4%.
9. **Arrive** only where the 8 px rise exists today: CompanionsHub, MachineHub, StatsPanel, NameScreen. Not BookView, Wardrobe, Store, EggHatch, PocketMenu, DifficultyPicker, QuestLog, DeckResults. `artPop` may be used on MachineHub and CompanionsHub icon discs.
10. **Depart:** called from the input handlers that mean "the player closed this" (close key, B/Escape/Backspace, shade tap), not inferred from the reason; requires board Mode == Room at capture and at the next Heartbeat, an unchanged `shadeOpen` counter, `Kit.shadeTop()` nil, and the screen effectively visible at capture. `shadeOpen` kills a live plate. Plate uses ScreenInsets.None through `coverRect`. Never `shadeDepth()`.
11. **Bushes:** server sets `WorldRestCFrame` on each dressing bush (an attribute only; `LoungeWorldV7Art` ~341). Client binds only from it, never from live CFrame, and resets to rest on stream-in before swaying. `RoomView:857` uses rest for `WorldDressing` parts. Gust gain applies only to kind `flag` and WorldRegion `Chime_*`; parked = gain 1; movers never stop.
12. **Split:** Wind owns `Wind, WindClient, WorldMotion, RoomView, LoungeWorldV7Art, AmbientAudio`; mounts inside `WorldMotion.start()`. UI owns everything else. `AliveBudget.level()` returns 0, 1 or 2 and is safe to require first. Locals: inline requires at their current execution position only. Rustle asset 131058187750745; nil id means no voice and nothing in `warm`; destroyed with Ambient.
