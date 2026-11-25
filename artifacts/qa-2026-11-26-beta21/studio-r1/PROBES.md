# World finish, Studio R1 (beta place, Play Solo, fresh save, 2026-11-25 evening)

Runtime: feat c25b3818 + ae49574d (den bound), synced by Rojo; 525+ scripts matched the repo before the pack merge.

- **Top Lawn sweep (`scripts/probe_top_lawn.luau`)**: PASS, 0 failing points, floor within 0.000 of 29; PetPark_grove mounted (meshes ready); PawGlade 5 seats, 3 colliders; Paw Glade on the lawn (0 off).
- **Pets go up (`scripts/probe_tier_pets.luau`, probe 4, 2 climbs)**: 4/4 PASS. Off-tread .35-.71 (limit .8), lane 1.48-1.50 (limit Lane+.15), lip 0, stall at most .3 s, no hops on the flight, the pet on the terrace 1.0 / 1.3 s after its owner, back on the lawn after each descent.
  - Run note: execute_luau has its own module cache, so the probe's `Pets.on()` reads its own copy (false). I set the local copy's switch and dropped probe 5 (its `/tier off` would only flip the probe's copy of TierConfig). Probe 5 (evacuation) needs the owner chat commands in a real session.
- **WorldFinish pack**: den, path and terrace mounted (W7_F_* in EggDropLounge.World); no `[WorldFinish]` warnings after the den binding fix; several new textures were still "being generated" on Roblox's side at first.
- Captures 01-06 in this folder; Fable review `FABLE-REVIEW-WORLD-R1.md`.
