# Garden hour (1-hour day/night): build plan (Opus, 2026-11-23)

Spencer, 2026-11-22: "And should we add like a 1hr day night cycle?" Answer (recommended, accepted with "Cool"): yes, 34 min day / 8 golden / 12 bright night / 6 dawn, same clock for everyone, beta first; pets stay awake at night; night Book finds follow the hour. Scope `WORLD-PASS-2026-11-22.md` item 6 + its "Architect check" (wins). Look: `artifacts/world-pass-2026-11-22/GARDEN-HOUR-LOOK.md` (Fable; values per phase, blends 90 s / night 120 s, fireflies 12 #E8FF8A, lamps at golden+night, rainbow daylight .7, PetExpression skips its night test). **Beta only; live untouched** (live keeps the dusk lock exactly).

## Gate

`src/shared/GardenHour.lua` (Things/Finds pattern): ceiling `FeatureFlags.GardenHour=true` AND beta place or Studio; server switch ConfigService `garden_hour` (server `GardenHourConfig`, owner chat `/hour on|off|clear`, plus Studio-only `/hour at <seconds>` to jump the clock for testing), attribute `Hour_on`. **`FeatureFlags.DayNight` is never touched.** Off = today (dusk lock / Aero 10.5).

## Pure clock (shared, server and client read the same)

`GardenHour.phase(serverTime)`: period 3600 s from a fixed epoch; phases dawn 0-360, day 360-2400, golden 2400-2880, night 2880-3600 (per the look); returns `{phase, t, daylight, blend}` with the look's blend windows. One `daylight` value for everything (pets, audio, Garden life, waterfall rainbow, Book). `GardenHour.isNight(serverTime)` for the server's `Book.isNight`.

## Client

- `HollowClock`: when GardenHour is on, `sample()` uses `GardenHour.phase(workspace:GetServerTimeNow())` instead of the dusk lock; `environment()` and the Aero `Clock.look` follow the phase (Aero look per phase from the look doc, not a pinned 10.5). Lerp per frame between 5 s samples during blend windows only (≤20 writes/s); holds keep the 5 s pass. Off: exactly today's code path.
- Consumers read the one daylight: AmbientAudio (birds day-banded), Garden life (birds, butterflies, bubbles day only), AeroFalls rainbow (> .7), lamps on at golden+night (find the existing lamp parts; client-only light toggles), fireflies at night (12, client-only, inside Garden life or Aero additions; budget levels and Reduced Motion as elsewhere).
- `PetExpression` (and any other daylight<.3 sleepy/glow rule): skipped while GardenHour is on (pets stay awake).
- Reduced Motion: ClockTime steps instead of sliding; light still changes.

## Server

`Book.isNight` reads `GardenHour.isNight` when on (same save bit; no save change). Nothing else on the server changes; the server's own sky writes (if any) follow the same gate.

## Tests

`GardenHour.spec` (phase boundaries, blends, daylight monotonic within blends, isNight), HollowClock spec (on: phase-driven; off: identical to today), PetExpression (awake when on), Book night (on/off), Garden life day-only rules, AeroFalls rainbow threshold. Studio: `/hour at` each phase, captures of the Bear at night (face readable), Fable review, frame time during a blend.

## Architect review (Opus, 2026-11-23; wins over the text above)

Blockers folded in:
1. **Two daylights exist under Aero:** `Clock.lastDaylight` (.9, feeds `Face.daylight`, lamps, rainbow) and `Clock.daylight()` (dusk .55, feeds AmbientAudio, coos, HollowAmbience). With the hour on, both return the hour's value; off, nothing changes.
2. **The hour needs Aero on too** (day is `WorldAero`; the only Lighting writer is `look.paint`). Aero off = the dusk lock as today.
3. **Missing switch = off** (unlike Aero's resolve).
4. **Sun/moon swap under the haze:** bend the ClockTime path so 18.0 and 6.0 fall on the sky swap at the haze peak; keep Fable's brightness pinch. Reduced Motion steps across the swap.
5. **Holds return the exact table values** (not `Lerp(a,b,1)`), so `World.write` writes nothing on 5 s holds.

Design: one writer `HollowClock.environment → Clock.look.paint(blend)`; `GardenHour.look(t)` (shared, pure) returns the blended table; `Clock.sample` returns `blend.Hour, blend.Daylight` when the look is set and the hour is on; `AeroWorld.paintLight(values)` takes the table (default WorldAero) and paints `glow_warm`; `Clock.backdrop` takes cloud colour and flat peaks from the blend. Blend apply in `Controller:step` at ≤20 Hz (10 at budget 1, 2 at budget 2); holds keep the 5 s pass; measure GPU shadow cost on a phone. Consumers: `WorldAero.Waterfall.RainbowDaylight` .5→.7; GardenLife daylight dep (bubbles, butterflies, birds above .7); AeroAdditions dew glints above .7 + new v7 fireflies (HollowAmbience fireflies are legacy only); pets awake via one `Face.moodDaylight()` (never below .3 while the hour is on) feeding `PetExpression.garden` (GardenPetVisual:240), `PetIdleBeats` night weights (:273), `PetCooScheduler` NightWait (RoomView:336). Book: leave `Book.isNight`; add optional `isNight` arg to `Book.stateBits(state, now, sig, isNight)`, `LifetimeState:102` passes `GardenHour.isNight` when on (same bit 11, no save change). Studio `/hour at`: a workspace offset attribute `GardenHour.time()` reads on both sides.
Split: **A first** `GardenHour.lua` (gate, phases, look blend, isNight, offset), `WorldNight`/`WorldDawn` values, `GardenHourConfig` + `/hour`, spec. **Then parallel:** B `HollowClock` + `AeroWorld.paintLight` + backdrop (the writer, one owner); C `AeroAdditions`/`AeroFalls`/`WorldAero` (rainbow, glints, fireflies) + D `GardenLife`/`LifeSim`; E `PetFace`/`GardenPetVisual`/`RoomView` + F `BookCatalog`/`LifetimeState`. Merge B before the others' Studio checks.
