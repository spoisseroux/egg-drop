# Garden finds: build plan (S9) (Opus, 2026-11-22)

Scope: `V3-SCOPE-2026-11-21.md` 5.3 and S9; places and onboarding row 3 from `WORLD-PLAN-2026-11-22.md` 2 and 4. Spencer, 2026-11-22: "Keep building, what's next". **Beta only; live untouched.**

## Goal

A sparkle sits on one of the four lawns. You walk your pet up to it, the pet sniffs, it pops: +8 Smarts XP. Each player has their own and sees only their own. At most 3 waiting, a new one every 4 minutes of active play, 12 a day. Nothing else pays.

## Rules

- **Ceiling:** `FeatureFlags.GardenFinds=true` AND (beta place 107705084891479 or Studio), constant in `src/shared/Finds.lua` (`Finds.PlaceId`), added to the going-live list beside `Alive.PlaceId`, `Levels.PlaceId`, Dash, Aero, Things.
- **Switch:** ConfigService `garden_finds` through the AliveConfig publisher (as `ThingsConfig`): off until loaded once, then missing = on. Owner chat `/finds on|off|clear` on beta and Studio. Attribute `Finds_on`. Off mid-session: live sparkles vanish, nothing written, unsaved claims dropped (the spot was never paid).
- With the ceiling off: no remotes, no attributes, no connections, no save field touched.

## Save: one optional field, no version bump

`finds = {day, count, op, receipt={op, petId, xp}}` on the hatching save, written only inside `HatchProgress.transact` by `Hatching.findClaim`. Read tolerantly like `DashState.read`: malformed day or count reads as "12 done today" (fail closed). Never in `HatchProgress.valid`; old servers keep it untouched (clone-whole writers).

## Components

| File | What |
|---|---|
| `src/shared/Finds.lua` | Pure: ceiling, keys, `Every=240`, `Waiting=3`, `DailyLimit=12`, `Reach=14`, `FirstAfter=60`, `XP=StatCatalog.XP.find`; `pick(random, live, recent)` (never a live spot, never one of the last 6, never within 20 studs of a live one) |
| `src/shared/FindSpots.lua` | 24 authored spots `{x, y, z, lawn}` on the south, east, west and grove-edge lawns; data only, measured in Studio (below) |
| `src/server/FindsState.lua` | Save field: `read`, `left(state, today)`, `apply(state, candidate, today)` (count < 12, pet owned, then `StatState.grant(state, petId, "smarts", XP, day)`), `committed`, `receipt` |
| `src/server/HatchProgress.lua` | `Hatching.findClaim(handle, operationId, petId)`: signature `find:<op>`, pending resumes the same candidate, digest `find:<day>:<petId>` |
| `src/server/FindsConfig.lua` | The switch, as `ThingsConfig` |
| `src/server/FindsHost.lua` | Per player (server memory only): live spots (random ids), active-play timer, claim handling, one write in flight; remotes `FindsEvent` (server to that player only) and `FindsClaim` |
| `src/client/FindsClient.lua` | Own sparkles as local non-colliding, non-query parts; twinkle harder within 20 studs; within 8 studs with the pet out and nothing else going on, sends the claim; pet sniff pose locally, pop sparkle and sound on the server's yes |
| `src/shared/Things.lua`, `src/client/ThingsPage.lua`, `ThingsTrail.lua` | A "Garden finds" row: "{count} finds waiting" / "Come back later", Show me to the nearest live one |
| `src/client/ThingsTips.lua`, `UICopy` | Tip 3 once ever (new `coachMask` bit): "Something sparkles" / "Walk {pet} over to sniff it." when the first find is within 20 studs |

## Server flow

1. **Timer:** adds wall seconds only while active: character alive, board in Room mode (not a deck round, hatch or race), and the root moved more than 2 studs within the last 60 s. First spot after 60 active seconds, then one every 240, while `waiting < 3` and `savedToday + inFlight + waiting < 12`.
2. **Send:** `FindsEvent:FireClient(player, {kind="spots", list={{id, x, y, z}}})` on each change and on join; never to other players.
3. **Claim** `FindsClaim {id}`: 0.3 s throttle; feature on; board loaded and `canProgress`; id is one of this player's live spots and not already claiming; a companion is out; the character's root within 14 studs (3D) of the spot. Anything else: ignored with a reason packet; nothing paid.
4. **Write:** the spot moves to `claiming`; one write in flight per player, id kept across retries (as `dashFlight`); never while the save is busy, pending or paying a round, after a 3 s quiet window. Success: spot removed, `{kind="claimed", id, xp}`. `AlreadySaved`: same. Refused for a reason that will not change (`DailyLimit`, `NoPet`): spot removed, no XP. Ambiguous or busy: stays `claiming`, retried with the same op id. Leaving: unsaved claim dropped by `CloseProgress` (as Dash).
5. **Day:** the day is read inside the write; a claim that commits after midnight counts on the new day.

## Edge cases

| Case | Expected |
|---|---|
| Claim from 30 studs, a stale id, another player's id, a replay | Refused, nothing paid |
| Two claims in a frame | One in flight; the second waits or is ignored |
| Write ambiguous, retried | Same op id; `committed` proves it; paid once |
| Two sessions on one save | Lease fences (`SessionLost`); cap counted on the save, never above 12 |
| Rejoin to farm the timer | Timer restarts from zero; the daily cap is on the save |
| Switch off mid-claim | Pending write finishes or drops; nothing new; sparkles gone |
| Pet put away before the claim | `NoPet`, spot kept |
| Clock rollback | Saved later day kept; nothing extra |
| Malformed `finds` | 12 done today, never a failed load |
| Studio streaming, character respawn | Client redraws from the last `spots` packet |

## Not in this slice

The pet trotting over on everyone's screen (the sniff is local: other players see your pet as now), Treasure Hunt, the "glows from further away" Smarts 14 perk, quests "Sniff out 2 finds", How it works page, real sparkle art and sound (a drawn four-point star and an existing chime until Fable's).

## Spots: measured, not guessed

A Studio server script raycasts each candidate: ground hit is a grass part (not water, `cliff_rock`, kerb, path stone), slope under 15 degrees, at least 6 studs from stations, park kerbs, `WorldDressing` flowers and every Dash course point, 3 studs clear overhead. Keep 24 that pass, six per lawn; record the script output in `artifacts/finds-2026-11-22/`.

## Tests

New specs: `Finds` (pick never repeats a live or recent spot, spacing, spot table valid), `FindsState` (apply, cap 12, rollback, malformed, replay, pet not owned), `FindsHost` (fake clock and board: timer only when active, cap 3, daily cap with in-flight, far/stale/foreign/replay refused, leave mid-write, switch off), `FindsClaim` in HatchProgress (exactly once). All existing suites against the baseline; `ClientLocalBudget` (no new column-0 local: mount from a do-block).

Studio: walk to a find, it pops, Smarts XP goes up 8 in the Stats panel, rejoin keeps the count; 13th claim refused; `/finds off` clears sparkles; output log clean.

## Revisions after the architect review (2026-11-22; these win over the text above)

1. **Malformed field** (blocker): `FindsState.read` (built, specs pass): a good day with a bad count closes that day only; a malformed day reads as no field, repaired by the first find. Never stuck, never Stars at stake.
2. **NoPet** (blocker): the host takes `petId` when it accepts the claim (`board.profile.companionId`); the write checks only that the pet is owned (owned pets never shrink). The spot is removed on success, `AlreadySaved`, `DailyLimit` and `NoPet`.
3. **Things row** (blocker): the finds row goes **before** the Dash row (`ThingsPage:paint` marks `dashSeen` only when `rows[#rows].id=="dash"`), and `things.show` in `init.client.lua` gets a `finds` branch before its Dash fallback.
4. **Remotes** (blocker): made the first time the switch is on (Dash pattern). `FindsClient` binds through `remotes.ChildAdded` (as `DashClient` ~116), never `WaitForChild` at init; `FindsClaim {kind="sync"}` asks for the current spots.
5. **Retry reasons:** same op id on `Busy`, `Pending`, `Retrying`, `RevisionChanged`; give up on `DailyLimit`, `NoPet`, `OperationConflict` (warn); `SessionLost` stops that board. `finish()` removes the spot even while the switch is off (the background `Nursery.retry` loop can finish an ambiguous write later).
6. **Pop at once:** `{kind="taken", id}` the moment a claim is accepted; `{kind="claimed", id, xp}` after the write. XP shown is what `grant` returned (Bonus doubles the first 100 a day; favourite +10%), so usually +16.
7. **Claim check** as `DashHost:check`'s join stage: a garden actor with the matching `petId`, mode Room, not carried or in care, no `petContact.lease`; root within 14 studs. No server pet-position check.
8. **Timer:** `active(board)` from `init.server` built on the existing `petState().conflict` and `board.mode=="Room"`; paused at 3 waiting or at the cap.
9. **Close:** no settle; `CloseProgress.drain` retries a pending find.
10. **Tip 3:** `findsIntro` bit 14 in `Coach.Bits`, `Coach.Order`, `Coach.Gated` (`"tips"`); subject to `Tips.Max=2` and the 1.2 s standstill.
11. Mount client in a `do` block as `clientUI.finds`; translations export and sync for the new strings.
