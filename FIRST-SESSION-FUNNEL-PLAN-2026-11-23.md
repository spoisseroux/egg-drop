# First-session tracking: build plan (Opus, 2026-11-23)

Spencer, 2026-11-22: "Add first session tracking". Live numbers: ~10 new players a day, 3.9 min average session, 1% day-1 retention; we can't see where new players quit.

## What

Roblox's onboarding funnel: `AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName)` from the **server**, one step per milestone of a player's first session, in order, each at most once per player. Roblox shows it as a funnel in Creator Hub Analytics (counted per player, first time only; steps must be logged in increasing order to be meaningful). No custom fields, no personal data.

## Steps (draft; the builder confirms each hook exists on live 54dca26)

| # | Name | When (server sees it) |
|---|---|---|
| 1 | Joined | Profile and save loaded for a player with no prior session (new save) |
| 2 | FirstDrop | First egg dropped in the opening deck round |
| 3 | FirstRoundDone | Opening round settled |
| 4 | MetBear | The Bear arrival acknowledged (pet owned and its reveal acked) |
| 5 | InGarden | First time in Room mode with the character spawned |
| 6 | TourClosed | Garden tour coach card closed (coach bit) |
| 7 | FirstPet | First pet / care action on a companion |
| 8 | FirstHatch | First egg hatched at a machine |
| 9 | SecondRound | Second deck round started (chose to play again) |
| 10 | FiveMinutes | Five minutes of session time reached |
| 11 | ReturnedDay2 | Joined again on a later day (logged at that join) |

Only players whose save is new on this join get steps 1-10 (an `onboardingStarted` marker in session memory from the "new save" signal; no save change). Step 11 needs a saved first-join day: if the save already stores a first-play day or join count, use it; **no new save field** in this hotfix otherwise (then drop step 11 and rely on Roblox's own D1 retention).

## Rules

- **Server only, fire-and-forget:** every call in `pcall`, never yields game code, never blocks a round, save or join. A helper `FirstSessionFunnel.lua` (pure step table + `log(player, stepName)` that keeps a per-player set and refuses out-of-order or repeated steps).
- **Live-safe and tiny:** a hotfix branch `hotfix/first-session-funnel` from live runtime `54dca26` with only this; the same helper merged into `feat/egg-drop-arcade-polish` (where v3's tips/Things to do steps can be added later). Off switch: `FeatureFlags.FirstSessionFunnel` (true) so a bad build can be disabled by a publish; no runtime remote needed for analytics.
- Studio: `AnalyticsService` calls are no-ops/logged in Studio; verify by a spec with a fake AnalyticsService and a Studio play-through printing the steps in order.

## Tests

`FirstSessionFunnel.spec.lua`: order, once-only, out-of-order refused, pcall on a throwing service, only new saves, cleanup on leave. Existing specs unchanged. Code review before the hotfix; **live publish waits for Spencer's go**.
