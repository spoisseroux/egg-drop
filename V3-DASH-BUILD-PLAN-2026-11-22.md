# Garden Dash build plan: S6, S7 (Opus, 2026-11-22)

Scope: `V3-SCOPE-2026-11-21.md` section 4. `DashCourse/DashSim/DashStats` stay unchanged; pars are `DashStats.Pars`, not scope 4.5. Code says **race**, not "heat" (board difficulty).

## Switch

`FeatureFlags.GardenDash` is the ceiling. `shared/Dash.lua` copies `Levels.lua` (flag and (beta or Studio)). `server/DashConfig.lua` runs AliveConfig's publisher on `garden_dash` and `garden_dash_prizes` (off until loaded, then missing = on). Owner chat `/dash`. Ceiling off: no remotes, gate, attributes, snapshot keys or writes. **Go-live:** set keys, then move the `Alive`, `Levels`, `Dash` PlaceIds.

## Files

- **Shared:** `Dash`, `DashWire` (packet checks, state codec).
- **Server:** `DashDirector` (pure: phases, seats, queue, Sim, pals; injected clock/guid/seed), `DashHost` (remotes, board checks, tags, prize queue), `DashState` (save), `DashConfig`, `DashMount` (static gate, arches, stones, as `ParkMount`).
- **Client:** `DashClient`, `DashPredict` and `DashCamera` (pure), `DashInput`, `DashHud`, `DashPose`, `DashProps`, `DashResults`.
- **Edits:** `GardenState`, `ParkDirector`, `HatchProgress`, `CloseProgress`, `RoomView`, `RoomCompanions`, `PetInspect`, `StatsPanel`; one protected require in each `init`.

## Remotes

- `DashRequest` (C->S): `{kind=join/leave/mode/trial/ping, seq, petId?, petGeneration?, characterId?, mode?}`; seq rules as `ParkThrowHost`; 0.3 s throttle.
- `DashInput` (C->S): `{r=raceId, n=seq, t=tick, k=kind}`.
- `DashEvent` (S->C): `joined, refused, refusedInput(n), judged, zoom(tick), result, cup`.
- `DashState` (S->C, unreliable, 10 Hz): buffer of tick and, per seat, cs, pace, flags, bar, next.

Roster, phase, GO time and `Sim.publicPlan`: a JSON attribute beside the garden `Snapshot` (late joiners). **The seed and zoomies moments stay on the server.** Frozen levels go only to their owner.

**Checks, in order:** 20 packets/s; exact types (finite integers, strings up to 40, known kind); seat by `player.UserId`, never the packet; `r` matches; `n` above the last (drops duplicates); `Sim.push`. Refusals answer `refusedInput`; 30 bad packets: ignored for the race, never kicked.

## Server authority

- Idle, gather (20 s; at least 8 s after a join), countdown 3.5 s (locked; seed and plan drawn, GO published), race, results 6 s. One race a server, 8 seats; others queue FIFO (within 16 studs).
- Heartbeat steps toward `floor((serverNow-GO)*100)-LagTicks`, **at most 10 ticks a frame**, so queued inputs land first after a hitch. This live replay of stamped inputs is the result.
- Time Trial: one Sim per player, same path, live only. Posted logs refused.
- Join needs: switch on, `Room`, `canProgress`, owned pet out, alive, HRP within 12 studs, no care/focus/contact/pending hatch. Levels come from saved XP, frozen at countdown (all rechecked).
- Stats On: first seat's band, others `WrongBand`. Pals fill to 4 (band middle, leaf tag).
- A Director error aborts unpaid; three: Dash off.
- **Accepted limit:** perfect-press macros; prizes are small.

## Prizes and save

Optional `hatching.dash`, no version bump, **outside `valid()`** (as `MedalEggs`):
`{day, paid, week, weekRibbons, ribbons, cups, best, op, receipt={op,seed,place,us,stars,balance}}`

- Results join `board.dashQueue`; the flush copies `flushParkGames`. `Hatching.dashResults(handle, opId, results)` writes up to 8 in one `transact` (signature `dash:<op>`, content digest). `dash.op` is the proof; `Hatching.retry` settles ambiguity; analytics use only the receipt.
- **2 Stars, any place,** if finished, 3+ accepted inputs, within 2x Gold par, `paid<5`. No 2x pass or XP. Day is read inside the callback; a later saved day is kept (clock rollback). Balance cap pays 0.
- Ribbon: 3 inputs, seated at the end. Cup: bitmask OR, server time. Title derived: 5 ribbons this week.
- Prizes flag frozen at enqueue; off still records bests.
- Leaving: `CloseProgress.drain` gains `options.dash`, after pending and payout, before release.
- Malformed: repaired per subfield; bad day/paid reads 5 paid today. **Old build** ignores and keeps `dash`. Two servers: lease fence.

## Mode gating

- `actor.dash=raceId`, set by the host at join after `garden:release` (frees park slots). Decide, greeting, park membership, focus, care, contact, hello, throw and companion switch skip or refuse tagged actors. Cleared at results, leave or abort. Seats key on UserId; respawn re-tags.
- Opening the Deck while seated forfeits (`Sim.toBot`, no prize); the client asks first. Rounds stay paused.
- Client: `overlayOpen` true, notifications held, MovementLock `dash`, menus closed at countdown, no store prompts, Leave key visible.

## Prediction

- Local one-runner `Sim.new` with plan `{mode, layout, lanes={mine}, clovers, cloverHurdle, zoomies={}}`. Clock: server time minus GO **plus a fixed lead**, clamp(RTT/2 + 30 ms - 150 ms, 0, 300 ms).
- Refused input or zoom: edit the log, **rebuild from tick 0**, ease 0.25 s, snap above 6 studs. A second mismatch with `DashState`: server rendering for that race.
- Rivals extrapolate up to 400 ms. Final time and place come only from `result`.
- Client paces to 8 inputs/s, always reserving dashUp.

## Client

- `DashClient:step` runs in RoomView's RenderStepped. Racers reuse companion visuals via a `drive` hook (as `ParkClient`), full tier; only pals and ghost are created.
- RoomView owns the camera: `enterDash/leaveDash`; `_useRoomCamera` yields while held; restored on end, abort, switch off, respawn, error.
- Phone: Jump right, Dash left, 96 px, safe insets, half-screen zones, per-touch ids; stones key above Jump. Focus loss, core menu, touch cancel or text box sends dashUp. Bindings open at GO, fresh press only.
- HUD: ring, bar, place, strip. First-race helper: Just for Fun, bigger ring.
- **Reduced Motion:** ring closes; no shake, FOV kick, puff or pop; tumble is a sit.
- **Caps:** server 0.5 ms p95 (race + 12 trials); 30 fps, 8 runners, 12 players; rebuild 8 ms on phone; 60 prop parts; no per-frame instances or physics; packet 120 B.
- **Fallbacks:** no art: parts; no sound: silent; no config: off; course not streamed: request streaming at countdown, else draw the rail only.

## Edges

- Late, early, reordered, flooded, duplicate, other seat, old race: Refused
- Disconnect in race / results: Pal, no prize / saved once
- All humans leave; switched off: Abort, unpaid, camera restored
- Ambiguous write retried: One payment
- Sixth race; midnight: Ribbon, 0 Stars; commit day
- 12 players: 8 race, 4 queue or trial
- Respawn, hitch, tab away: Seat kept; dash released
- Unfinished after 20 s: Finisher ribbon, no Stars
- Server stops: Nothing written

## Tests

- **Specs** (pure in `run_dash_specs.py`, rest ZZSpecs): `Dash`, `DashConfig`, `DashWire` (fuzz), `DashDirector`, `DashState`, `DashPrize` (retry, replay, clock, cap), `DashPredict` (1,000 races equal the server), `DashCamera`, `DashInput`, `DashGating`, `DashOffParity`. Re-run the baseline. **Cross-version:** new save through live HEAD and back.
- **Studio/agentic:** hostile client; keyboard and touch races; kill switch mid-race; captures 844x390, 667x375, 600x360 largest text, gamepad; streaming; course walk (never done).
- **Two clients:** same order, times, clovers; leaver; band refusal; trial invisible to B; 300 ms lag; beta save check.

## Art and sound (Fable; placeholders first)

Scope 4.2 and 4.4b props, gate pads, leaf tag; puff, spring, bolt, arrow, ribbon, cup icons; pal recolours. Eight sounds (scope 4.2, 4.4b).

## Split and order

1. Stubs: Dash, DashWire, roster shape.
2. Parallel: **A** server and specs; **B** Predict, Camera, Pose, Props, drive; **C** Input, Hud, Results, panels.
3. **Integrator only:** Host, flags, init, RoomView, garden edits, UICopy, translations.
4. S6 with prizes off, review; S7, review; prizes on in beta, two accounts.

## Questions (default)

1. Ghost saved? **Session only.**
2. Ribbon for idle racers? **No.**
3. Hoops and clovers client-drawn (scope says server)? **Yes; layouts differ.**
4. Deck mid-race forfeits? **Yes.**
5. Today cup? **Server memory.**
6. Inputs saved? **Last 5 races in memory; seed in receipt.**
7. Lag lead? **On.**
