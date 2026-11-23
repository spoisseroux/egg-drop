# Alive step 5, garden life: build plan (Opus, 2026-11-22)

Spencer, 2026-11-22, picking the next build: "Latter" (petals, birds, butterflies and bubbles). Scope: `ALIVE-BRIEF-2026-11-22.md` B4, B7, C1, C3 (numbers there win unless stated here); places from `WORLD-PLAN-2026-11-22.md` section 6; budget and switches from `ALIVE-SAFETY-2026-11-22.md` 4. **Beta only; live untouched.** Client only: no remotes, no saves, no server gameplay change.

## Goal

The garden has small living things: petals blow off the blossom crowns in a gust, soap bubbles rise from the Bubble Spring and drift past, a round little bird sits where you hear it chirp, and a few butterflies wander over the flower patches by day. All of it is looks only and costs almost nothing on a phone.

## Rules

- **Switch:** new Alive feature `life`: `FeatureFlags.AliveLife=true` (ceiling: flag AND beta place or Studio, through `Alive.ceiling`), ConfigService key `alive_life`, attribute `Alive_life`, `/alive life on|off|clear` and `/alive all ...` (AliveConfig is generic over `Alive.Features`). Missing attribute = off. Off mid-session: every creature and emitter gone within a frame.
- **Ceiling off or switch off = today's game exactly:** no instances, no RenderStepped/Heartbeat work beyond one attribute signal, AmbientAudio's birds sound the same.
- **Parked** (deck round, hatch reveal, Garden Dash race, Board mode): everything hidden, nothing simulated. Menus: petals, birds and butterflies keep going behind the shade; bubbles stop spawning.
- **Budget** (`AliveBudget.level()`): level 1 halves every cap and runs at 15 Hz; level 2 shows nothing. **Reduced Motion:** no petals, bubbles or flying; birds still appear and sit, no hops.
- **Day:** butterflies and bubbles by day only (`HollowClock.daylight() > .5`); birds follow AmbientAudio's chirps (already day-banded); petals any time.
- **Never in the way:** nothing spawns or lands within 6 studs of the camera, within 8 studs of a station (`StationAttractData`), on the Garden Dash course while a race runs, or over the waiting pad. Nothing collides, casts shadow, is queryable or touchable (`CanCollide`, `CanQuery`, `CanTouch`, `CastShadow` false; `Anchored`).
- **One stepper:** one Heartbeat connection at 30 Hz, one `workspace:BulkMoveTo` per step for every moving part. No tweens, no per-creature connections.
- **Art:** our own, no outside assets. Birds and butterflies are built from a handful of parts (round, big eye dot, cousins of the Bear and Bunny); petal and bubble textures are script-drawn PNGs (Fable), uploaded once. Fable writes the look numbers (`artifacts/alive-life-2026-11-22/LOOK.md`) and reviews real captures.

## Components

| File | What |
|---|---|
| `src/shared/FeatureFlags.lua`, `src/shared/Alive.lua` | `AliveLife`; `life` in `Alive.Features` and the flag map |
| `src/client/LifeSim.lua` | Pure, no instances: petal rate from `Wind.at`, bubble path (rise .4, drift with wind 1.5 to 3 studs/s, life 9 s), butterfly wander (3 studs round a patch at .8 studs/s, rest 2 to 4 s), bird landing (.8 s arc in, hop on chirp, stay 8 to 20 s, 1.2 s arc out when the player is within 12), spawn rejection (camera, stations, course, pad), caps per budget level |
| `src/client/GardenLife.lua` | Instances and the one stepper: pools (birds 3, butterflies 4, bubbles 8, petal emitters 3 / 24 petals), mount/destroy, parked/menu/budget/Reduced Motion/day handling, colours from LOOK.md |
| `src/client/AmbientAudio.lua` | `options.onChirp(perchIndex, position, cue)` called for each chirp it plays (nil = today); no change to sound |
| `src/client/init.client.lua` | Mounts `GardenLife` in a pcall'd `do` block (no column-0 local; budget 219, now 218) and passes the chirp hook to the existing Ambient mount |
| Petal emitters | `ParticleEmitter` on up to 3 hidden anchor parts at the nearest blossom crowns (`foliage_blossom`, the parts `WorldAero` recolours); petal colour follows the crown (lime with Aero on, pink off); rate `3 x gust`, life 5 s, drift 6 studs/s downwind via `Acceleration`, slow `RotSpeed` |

## Edge cases

| Case | Expected |
|---|---|
| Switch off mid-flight, ceiling off | Everything destroyed in a frame; no connection but the attribute signal |
| Deck round / hatch / race starts | Hidden at once, nothing simulated; back on return to Room |
| Streaming: crowns or flowers not loaded | No emitter there; re-picked every 2 s from what exists |
| Respawn, camera jump, teleport | Creatures more than 120 studs away are dropped and re-spawned near |
| Budget level drops mid-session | Caps shrink at once (extras removed), never back up |
| Reduced Motion toggled | Petals, bubbles and flight stop at once; birds sit |
| Two players | Purely local; nobody else's game is affected |
| AmbientAudio missing or its hook throws | No birds; sound unaffected (hook pcall'd) |

## Not in this slice

Pet looks at a bird or butterfly (C2), bubble pop and wing flutter sounds (D4, D5), crowns sway (B5), fish (C6), residents (C5), ripple rings (B8).

## Tests

Specs: `LifeSim` (rates follow the wind, caps per level, paths deterministic for a seed, spawn rejection near camera/stations/course/pad, bird stay and leave), `GardenLife` (with a fake world: mount nil with the ceiling off; off destroys everything; parked hides; Reduced Motion; budget level 2 shows nothing; one Heartbeat connection; chirp lands a bird at that perch; 4th bird refused), `AmbientAudio` hook (called per chirp, sound unchanged without it), `Alive` (feature list), `ClientLocalBudget`. Offline runner as Finds.

Studio: switch on, watch each kind in day and night, `/alive life off` clears, deck round hides; frame time pairs (life on/off) with the probe; output log clean. Fable reviews the captures before publish.
