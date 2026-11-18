# B0 plan: deterministic board sim foundation (2026-11-17)

Slice B0 of "Option B, revised" in `client-sim-plan.md`. Nothing changes for players:
the server keeps running `src/server/BoardSimulation.lua`.

## Files

- `scripts/gen_board_sim_launch.py` (new): writes `src/shared/BoardSimLaunch.lua`, the launch
  velocity for every aim on a fixed grid (`AimSteps=400`, index = floor(aim*400+0.5)), plus the
  per-step constants (gravity*dt, drag 1-dt*0.85, dt) as `%.17g` literals.
- `src/shared/BoardSim.lua` (new, pure, server and client): a port of `BoardSimulation` and the
  physics/state half of `BoardItems` (armed marks, magnet pull, bomb burst, pop, swap, star slots,
  tier queue) to plain doubles (`x, y, vx, vy`). Same rules and order as the old sim, with these
  deliberate differences:
  - aim is quantized to the 400-step grid; launch velocity comes from the literal table;
  - timers are counted in ticks (contact gate 72 ticks = 0.6 s, magnet 240 ticks = 2 s) so no
    float drift decides an edge;
  - the step always uses `FixedStep`; there is no dt parameter.
  Random: `Random.new(seed):NextInteger` for the tier queue, `RoundItems.plan` for star slots (both
  integer PCG, created once in `new`; the board keeps no RNG state). Step path: `ipairs`/numeric
  loops only, no Vector2/Vector3, no sin/cos/exp/pow.
  API: `new(preset, serial, options)`, `nextTier`, `powerUpAt`, `canDrop`, `drop(aim)`,
  `swapNext`, `pop`, `arm(id)`, `step(board, merged?, impacts?)`, `apply(board, input)`,
  `hash`, `snapshot`, `restore`, `replay(seed, preset, inputs, ticks, options)`.
- `BoardSim.hash`: FNV-1a 32 plus a second 32-bit polynomial lane over a canonical byte string
  (`string.pack("<d")` for every double, integers and strings in fixed order: tick, serial, drops,
  falling id, gate ticks, armed, queue, star slots 1..#queue, every ball in array order, pending
  bursts). Returned as 16 hex chars.
- `scripts/BoardSimDeterminism.spec.lua` (new): 3 seeded input logs (24 drops, gaps 50-160 ticks,
  aims across the grid, swap/pop/bomb/magnet), replays each, hashes every 60 ticks. Returns the
  hash lists plus a digest. Runs on Server and Client (copied to both ZZSpecs folders).
- `scripts/BoardSimParity.spec.lua` (new, Server): the same logs through the old `BoardSimulation`
  (Vector2) and `BoardSim`: merges, score (the server's chain rule and `Config.mergeScore`), final
  ball count, drops accepted. Reports differences; exact equality is not expected (float32).
- `src/shared/SimCheck.lua` (new): the 3 harness logs (generator + replay runner with yields), the owner check,
  shared by the spec and the owner check so both sides run the identical code.
- Owner phone check (`FeatureFlags.SimCheck`, true):
  - `src/server/SimCheckHost.lua` (new): RemoteEvent `SimCheck`. Accepts one report per player per
    server, only from the experience creator (user creator id, or rank 255 in the owning group)
    or any player in Studio. Validates the payload (one list per log, at most 128 strings of 16 hex chars each),
    runs the logs itself once per server (cached, 30 steps a frame), replies `{match, mismatchAt, total}`.
  - `src/client/SimCheckClient.lua` (new): after the loading screen (`PlayerGui.LoadingSeconds`)
    plus 8 s, only for the same creator check, runs the logs in yielding chunks and sends the
    hashes; shows one line on `NotificationRail` with the result.
  - One line in `init.server.lua` (mount) and one statement in `init.client.lua` (start; no new
    top-level local).
- `FeatureFlags`: `SimCheck=true`, `DeckClientSim=false` (unused until B3, documented).

## Verification

1. Studio Play, Server datamodel: determinism spec, hash lists.
2. Client datamodel: same spec, compare digests and every hash to the server's.
3. Parity spec on the server: old vs new numbers.
4. Play as the Studio player: the SimCheck toast appears and says match; server log shows it.
5. Code Reviewer agent on the diff, blockers fixed, commit (no push, no publish).

## Out of scope (B1+)

Drop interval in ticks, the server's pending drop queue, welcome round, field objectives and
round/overflow logic, switching the live board.

## Results (Studio, 2026-11-17)

- Determinism spec, Server and Client datamodels: all 6 cases pass; 164 hashes (56/55/53 per log),
  identical string on both sides, digest `05a4e5ecb8ad2f44` (Edit datamodel too). About 25 ms for
  the three logs (~9.7k steps).
- Owner check in Studio Play: `[SimCheck] ...: match (164 hashes, server 05a4e5ecb8ad2f44, client
  05a4e5ecb8ad2f44)`, rail line "Sim check: match (164 hashes)".
- Old (Vector2) vs new (doubles), same logs: one unobstructed drop differs by at most 1.3e-5 studs
  after 0.5 s. Log 1 (Springy, medium): merges 16/16, score 580/560, balls 3/3, drops 22/22,
  drift > 0.01 stud at tick 1162. Log 2 (Gentle, hard): 12/12, 440/440, 6/6, 21/21, drift at
  2560. Log 3 (starter, custom kick/bounce): 18/18, 670/670, 3/3, 20/20, drift at 145. Max tier,
  bursts and peak chain equal in all three.

## Code review (Code Reviewer agent): no blockers

Applied: load-time asserts that the generated literals match BoardConfig; server replay at 30
steps a frame; client "no answer" line after 30 s; plan fixes; the 240-step magnet documented as a
deliberate change (the old float countdown runs 241). Carried to B1+: the belt, item sequence and
grants inside the sim state and hash; score/chain/grace/goals in ticks; the aim index (integer) on
the wire and `replay` refusing (not asserting) bad logs; ship queue and stars in the round-start
state instead of trusting `Random` to match across engine builds; `bursts` as an output parameter.
