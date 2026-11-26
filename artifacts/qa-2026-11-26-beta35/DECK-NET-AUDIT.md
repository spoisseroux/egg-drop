# Pocket Deck on a bad connection: net audit (beta 35, 2026-11-26)

Spencer, beta (35) note 1: "the pocket deck game still feels a bit laggy on bad connection. Can we audit
that a bit, to have the visuals more disconnected from the backend but safe".

Scope: field rounds on the client-run board (`FeatureFlags.DeckClientSim = true`, live since v933):
`ClientRoundDriver` + `ClientBoardMirror` on the client, `ClientSimHost` (lockstep `BoardRoundSim`) on the
server. The Welcome round still runs on the server path (ghosts and the snapshot stream). Other players' held
decks are not part of this. Nothing here was checked in Studio: the numbers come from reading the code and from
the new offline harness (`scripts/DeckNetFeel.spec.lua`), which plays one real round through the client path
over a simulated reliable, ordered link.

How the delays are counted: RTT is the round trip. "One-way" is RTT/2. The server answers on its next Heartbeat,
so add up to one frame (17 ms). With 5% loss, a lost packet on a reliable RemoteEvent is resent after about one
more round trip and holds back everything behind it. The harness models that as RTT + 100 ms. A round averages
about 175 client messages, so about 9 of them get resent per round at 5% loss.

## 1. What waits on the server: the trace

### One drop

| Step | Waits on | Before this change | After |
|---|---|---|---|
| Tap, ball appears, drop sound and jolt | nothing (the host applies the drop, the mirror draws it on the next render step) | 0 frames | 0 frames |
| **Tap in the round's first RTT** | the server's `ack` to the hello (`state.hello`) | **refused silently** (`Hello`). No ball, no sound, the DROP button looked live. | plays at once, and is sent with the hello |
| Tap when the ball's queue slot is not revealed yet | the server's `reveal` (5 slots past its drops + up to 2 queued) | **refused silently** (`Unrevealed`) | held, plays the frame the reveal lands (at most 1.5 s, counted) |
| Tap with 64 inputs unacked | the server's acks | refused (`Backlog`) | held, as above |
| FieldReady (DROP / FALLING caption, button) | host gate | the server's value until the hello ack | the host's value from the first frame |
| The 3rd preview ball (`PreviewTier2`) | `reveal` | the placeholder (tier 1) until the reveal lands, then a flip | unchanged (finding 7) |

### One merge chain, combos, goals, items

All of these run on the client's host and have no network wait: the merge blob, sounds, chain accent, haptics,
score popup, jolt, the HUD score and chain, goal progress, the Settling phase, item grants, item use, and bomb and
magnet effects. B3 already did this. The harness confirms it: at every RTT the drawn frames are bit-identical
to the no-latency run, and no merge juice is ever skipped as late. The server's `BoardMerge` and `ItemEvent`
for an owned round are only compared (Studio) or skipped.

### Goal completion

`FieldStage` and `FieldObjective` come from the host through `clientUI.attr`, so there is no wait. The only goal
cue the server sends is the daily/weekly quest toast. It comes from the nursery snapshot after the save, so it is
a reward and stays server-gated.

### Round end and results

| Step | Waits on | Before | After |
|---|---|---|---|
| Board ends (host.over), taps stop | nothing | 0 | 0 |
| **End art (balls rise, confetti), results card, pet's cheer** | the server's `RoundOver` + `FieldPhase` + `FieldSuccess` attributes: client report (one-way, sent at once on over) + server step + replication (one-way) | **RTT + ~1 frame**, measured: 150 ms at 150, 283 at 300, 600 at 600; **667 ms** at 300 ± 100 with 5% loss; **1.43 s** at 600 ± 150 with 5% loss; 2.3 s at 1 s ± 250. In that gap the board sat frozen with a FALLING caption. | **next frame**, from the host's outcome (`Mirror:localEnd`). The Stars count shows the existing neutral "Saving…" until the server's `RewardStatus = Saved` and the receipt. |
| Stars, 2x, Supporter, quests moved, stat gains, Replay / Hatch buttons | `RewardStatus` + `NurserySnapshot.lastRunReward` (DataStore save) | the gap above + the save | the same: **server-gated by design** |
| HUD values (score, merges, peak chain, clears) | the mirror serves them until the server's end, then the server's values stand | equal (checked: `settle.diffs`) | unchanged |

If the server's outcome is different (a desync in the last ticks), its values replace the shown outcome. There
is no second intro, and `RoundEndPresentation.corrected` counts it.

### Pause and resume

| Step | Waits on | Delay |
|---|---|---|
| Menu, Pocket Menu, carousel, quest log pause and resume | nothing (a tick-stamped input on the host) | 0 |
| Leave to the garden | `Mode` (server attribute). The board keeps running until it lands, then the host pauses. | RTT, harmless (the deck is still up) |
| **Back to the deck from the garden** | the server's `Mode = Board`. The deck rises and the host resumes only then. | **RTT.** Server-gated by design: other players see the held deck. Not changed. |
| Replay after results | Replay is enabled only after `Saved`. Then the `reset` request and the server's `start`. | RTT after the save. The retry sound plays at once. Server-gated by design: the round's seed, goals and hidden tiers are the server's. |

### Resync and desync

* Detection: the server hashes every 32 ticks (0.2 s) once it has stepped there, so a mismatch is seen about
  RTT + 0.1 to 0.3 s after it happens. The full state needs one more round trip, then a replay of up to 48
  steps a frame. The client sees the mismatch about RTT + 0.1 to 0.3 s after the divergence and has the
  corrected host one RTT plus the replay later: the harness measured **333 ms from mismatch to swap at 300 ms**
  for a +0.3 stud perturbation, so about 0.9 s from the divergence. B4 measured 0.2 s at lag 0 and 2.6 s at 0.6 s
  in Studio.
* The drawn balls ease back at most `L.MaxCorrection` (0.5 studs) a frame. A ball the corrected host does not
  have, or has at another tier, is redrawn at once, as is a correction over `L.PopDistance` (4 studs). Harness:
  offset up to 1.43 studs after 1 RTT of divergence, never a jump larger than normal motion.
* Safety valves, where a bad connection falls back to the old feel: no hello for `L.HelloSeconds` (5 s), a
  4th resync (`L.MaxResyncs`), or 3 s of client silence in Settling (`Stalled`). Each one releases the round to
  the server path (ghost balls and the 30 Hz snapshot stream, which waits on the server for every merge). On a
  phone with multi-second stalls this is the "old lag" coming back. These are counted in the server's
  `ClientSimStats.takeover`. See the open question below.

## 2. Worst findings (before this change)

1. **Dead taps at the start of every round** (one RTT, plus a resend when a packet is lost). The first one or
   two taps were eaten with no sound. Harness: 1 tap at 150 to 300 ms and 2 at 600 ms, every round.
2. **The board hangs at the end of every round** for one RTT, and up to 1.4 s with jitter and loss, before the
   end art and results.
3. Silent refusals (`Unrevealed`, `Backlog`) on loss bursts. These are rare: none in the harness up to 1 s
   with 5% loss. When one happens, the player's tap just vanishes.
4. On a desync, the correction arrives after about 2 x RTT. It is eased, so it never pops.
5. Fallbacks to the server path under multi-second stalls (above).
6. Returning to the deck and Replay take one RTT each (menu-level, server-gated by design).
7. The 3rd preview ball can flip from the placeholder when a reveal is late: never up to 600 ms steady, once a
   round at 600 ± 150 with 5% loss, four at 1 s ± 250.

## 3. What changed (branch `worktree-agent-a5fa49b07d041bcd4`, from `fix/beta25-feedback` 6b84226a)

* `ClientRoundDriver`
  * Taps before the hello ack play at once while the hello can still reach the server well inside its no-hello
    fallback. The rule: time since the server sent the start (on `GetServerTimeNow`, in the new `start.sentAt`)
    plus one more trip for the hello stays under `EarlyTapSeconds` (`L.HelloSeconds - 2` = 3 s). The hello leaves
    with the start and is ordered first, so the server's no-hello fallback is unchanged. A link too slow for that
    holds the taps instead (they never show a ball that a fallback would take away).
  * A tap that can only wait for the network (`Hello` past 3 s, `Unrevealed`, `Backlog`) is held in one slot
    and plays the frame its reason clears. It is let go after `HoldTapSeconds` (1.5 s), counted `heldExpired`.
  * Studio `/netsim`: outgoing lockstep messages wait one simulated round trip (`DeckNetSim`).
  * Test seam for the harness: `Driver.start(deps)` with its own remote, folder, clock and heartbeat.
    `Driver.stats` is exposed.
* `ClientBoardMirror`: `FieldReady` comes from the host from the first frame. `localEnd(serial)` gives the
  host's outcome. `drawnParts()` gives the end art's balls. There are optional `clock` and `bindRender` seams.
* `RoundEndPresentation`: a provisional end frozen from the host (`localEnd`, `readLocalView`, `localBalls`).
  The server's confirmed end replaces it with no second intro, and corrects a different outcome.
* `init.client.lua`: `clientUI.localEnd()` and `clientUI.roundOver()`. The results, the end art, the pet's cheer
  (once per round), canAim, the Pocket Menu and items gates, the danger cue end and the coach all read the
  round end through `roundOver()`. Rewards still read `RewardStatus` and the receipt.
* `DeckNetSim` (new, shared, pure): parsing, the `/netsim` command, and a reliable ordered link with RTT,
  jitter and loss (head-of-line resend).
* `init.server.lua` (Studio only): the owner's `/netsim <rtt ms> [jitter ms] [loss %]` and `/netsim off` set
  the board folder's `DeckNetSim`. BoardRequest actions (reset, mode, pause, today's-path drops) are held for
  one simulated RTT, in order. In live builds `IsStudio()` is false and the handler is a direct call.

**Unchanged and exactly as strict:** every `ClientSimHost` check (shape, order, gap, late, ahead and lead clock
guards, rate, pending cap, stall, idle, settle takeover, the hash stream and resyncs), the reveal window
(`L.Reveal` 5 + 2 queued), and the reward, receipt, save and quest paths. The server still decides every Star
from its own replay.

## 4. Measurement

* `scripts/DeckNetFeel.spec.lua`, registered in `run_dash_server_specs.py` (client list). It plays a real round:
  24 drops, 18 merges, an item, and a pause. Scenarios: no latency, 150, 300, 600 ms, 300 ± 100 with 5% loss,
  600 ± 150 with 5% loss, and 1 s ± 250 with 5% loss. Each scenario asserts:
  * the drawn frames are identical to the no-latency run, every ball, every frame, up to one second past the end;
  * the round ends on the same frame;
  * no tap is lost or held for a network reason, and there are no server refusals;
  * every merge's juice plays on time;
  * the client and server have the same end hash and the same result;
  * there are no preview flips up to 600 ms.

  A 2.6 s round trip must close the early-tap window before the no-hello fallback could take a shown ball (taps
  are held instead), and the round must still end equal. A control case puts the old hello gate back, and the
  harness catches it (frame 3 differs at 600 ms). A forced desync must ease, with no jump beyond normal motion.
  There is also a round-end presentation case (provisional end, server takeover, a corrected outcome) and the
  netsim parser cases.
* Code review (Code Reviewer agent, no blockers). Applied: the early-tap window uses the server's clock
  (`start.sentAt`); a rolled-back provisional end clears its intro and cheer marks; held taps wait through a
  rejoin's queued inputs; a held tap plays no sound without a mirror; the `ended` / restart-copy / settle-hint
  reads use `roundOver()`; the Studio hold release goes through the netsim link; `IsStudio()` is cached. Kept: a
  provisional outcome stands until the server's end is confirmed. It equals the server's unless there is a
  desync, and the confirmed end corrects it.
* Studio: in Play, chat `/netsim 300`, `/netsim 600 150 5`, then `/netsim off`. The output prints the setting.
  You can also set the `DeckNetSim` attribute on `ReplicatedStorage.EggDropBoards.<UserId>` from the server
  view.

## 5. Open questions for Spencer

1. Reveal window: `L.Reveal` from 5 to 7 would remove the preview flips up to about 1 s RTT with loss. The
   cost is that the client knows two more hidden tiers. That is a small anti-cheat give, so it was not changed
   without your OK.
2. Safety valves on very bad links: should `Stalled` in Settling (3 s) finish the round on the server while the
   client keeps drawing its own settle, instead of releasing to the server's Parts? A settle takes no inputs, so
   both sides land on the same board. This would be a small follow-up.
