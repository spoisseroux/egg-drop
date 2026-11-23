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
