# Pocket Deck on poor connections: client simulation plan (draft for review)

Spencer, v890 phone/PC QA (2026-11-17), on a poor connection:
- "balls dropping then coming back"
- "the balls can still take up to like a second to merge, the pause right before merging"
- "we need to separate server and visuals more"

## Why it happens today (v890)

- The server runs the board (`src/server/BoardSimulation.lua`, fixed step, `Config.Pace`) and streams 30 Hz snapshots. The client draws them on a render clock 50-250 ms behind (`BoardSnapshots`, `DelayMax=.25`).
- A tap shows a local ghost ball at once (`GhostDrops` and `GhostFlight`, S5). The ghost flies, bounces and settles locally, but **on a same-tier touch it stops and waits** for the server merge, which needs the round trip plus the render delay. On a poor link that is the one-second pause.
- Ghost timeouts are fixed: `UnboundTimeout=1.5` (no ack), `ServerTimeout=2`, `HandoffTimeout=2.5`, plus a late ack fades the ghost. With RTT above about 1 s, a ghost fades and the server ball appears later somewhere else: "dropping then coming back".

## Option A: mitigation inside the current model (about 1 session)

1. **Latency-aware ghosts.** Timeouts scale with the measured RTT (from drop acks: send to ack). A ghost is never faded while its drop request is unanswered (the remote is reliable). A late ack hands over with the blend, never with a fade.
2. **Predicted merges.** When a ghost, or any drawn ball, touches a same-tier ball, the client plays the merge at once: blob, sound, jolt, a predicted result ball at the contact point. When the server merge event arrives it is matched by the pair (`first`, `second` ids) or by tier and position within a radius, then the predicted ball hands over to the server ball with the existing blend. If none arrives within RTT plus 0.5 s, the prediction is undone: the two balls come back, a short fade. The score and HUD wait for the server as now.
3. `BoardSnapshots.DelayMax` adapts up to about 0.6 s on jittery links, so the drawn board stops starving and extrapolating.

Risk: low to medium. Mispredicted merges (the server's timing differs) undo visibly, but rarely.

## Option B: the client runs the board, the server verifies (deterministic replay, 4 to 6 sessions)

Each board belongs to one player and nothing else moves its balls, so the client can run the real simulation and the server can replay the same inputs behind it:

1. Move `BoardSimulation` and `BoardItems`' physics to `ReplicatedStorage.Shared` (pure modules). The client steps its own copy at `FixedStep` and draws it. Merges, bounces and item effects show at once, with no network in the loop.
2. **Input stream.** The client sends `{tick, inputs}` messages: a drop (aim), swap, pop, use item, pause, resume, plus a heartbeat every 100 ms carrying its current tick. The server sim advances only to the client's reported tick (the input horizon), never past it, so both run identical inputs at identical ticks. The server is the authority for score, payout, goals, quests and the round end, all computed from its replay.
3. **Clock guards.** The server clamps the client's tick to wall time: no faster than real time plus 5%, and no more than about 3 s behind (beyond that the server pauses the board, as a disconnect does). This removes speed-ups and stalling exploits.
4. **Randomness.** The tier queue seed is sent at round start (the client already shows the next two tiers). Welcome-round server drops (the demo) become scheduled inputs at a tick the server publishes ahead.
5. **Determinism and rollback.** Same Luau code on both sides, but Vector2 is float32 and ARM phones may fuse multiply-adds, and `math.sin/cos` (launch velocity) is libm. So: launch velocity from a fixed table; the server sends a compact state hash every 0.25 s; on a mismatch it sends the full state at tick T, and the client restores T and replays its logged inputs to now (rollback). The drawn balls ease to the corrected spots.
6. The 30 Hz snapshot stream, the ghost balls and most of `BoardNetClient` retire. Other players' held decks keep the low-rate replicated Parts.

Risk: high for a launch week. It touches the board's core, the welcome round, items and payouts. Needs a soak test with simulated loss and latency, plus phone and PC cross-platform determinism tests.

## Recommendation (for review)

Ship Option A now (v1). Build Option B as v1.1 behind a flag, with a determinism harness first (run the same input log on client and server and compare hashes on a real phone), then flip the flag.

## Questions for the architect

1. Is Option A's predicted merge sound: matching rule, undo path, the interaction with ghost handoff and the `afterRemoval`/`afterSpawn` lifetimes?
2. Option B: is the input-horizon lockstep (the server never steps past the client's reported tick) safe against stalling and speed-up exploits, and against the server's other per-board work (Welcome timers, field objectives, overflow grace, pause by menus)?
3. Option B determinism: float32 Vector2 and FMA on ARM. Is hash plus rollback enough, or should the sim move to plain Luau numbers (doubles) for positions?
4. Anything that makes A or B break in production that this plan misses?
