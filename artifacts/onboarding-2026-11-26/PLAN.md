# Plan: "The First Hatch" (onboarding slice 1)

Source: Fable `FIRST-3-MINUTES.md` (items 1, 3, 4 plus the funnel steps from 2). Spencer 2026-11-25: "start the
onboarding and first 3 minutes fixes/improvements ... It needs to be GREAT!!!". Beta line only (`fix/beta25-feedback`).

## Goal

A new player's first minute is one story: a Welcome round that shows off (a sure chain on drop two), an egg they crack
themselves (three taps, crunch and buzz under the finger), and a Bear who hands them tomorrow's egg straight after the
first hello. We can measure the loading loss and the tap.

## Changes

1. **Opener (`/onboard opener`)**: `src/server/WelcomeSeed.lua` gets a second starter layout whose second drop
   (at `DemoAim` or any aim in a tested band) sets off a three-step chain; the Welcome charge threshold rises so the
   egg fills in 5 to 6 drops (~30 s). Each merge sends a spark from the merge point to the egg well (client,
   `WelcomePresentation.lua`), the egg squashes and ticks a crack; the well is twice the size on phones. The solver
   evidence (existing Welcome specs) is re-run for the new layout and charge sum. Off = today's starter exactly.
2. **Crack it yourself (`/onboard crack`)**: when the Welcome egg fills, the client moves it from the well to the
   middle of the glass, dims the board and shows "Tap the egg". Three taps: a crack from the tap point, a fork with the
   Bear's colour leaking through, then creak and pop; each tap plays the matching existing `asmr_*` layer and buzz in
   the same frame (`HatchAsmr.lua`, `Haptics.lua`). Untouched, it cracks itself every 1.1 s (opens in ~4 s); holding
   opens it fast. Then the existing Bear reveal continues (`HatchCinematic`, gated with `Cinematic:held()`).
   Presentation only: the grant is already server-side when the charge completes; taps never gate the reward.
   Crack lines and flakes drawn in code (no new art). Reduced Motion: no shake, cracks still draw; sound off: buzz.
3. **The nest first (`/onboard nestfirst`)**: `BearNeeds.Needs.Order` becomes hi, nest, toy, deck, park for new saves
   when the switch is on (an alternative order table, not a mutation). The nest bubble, prints and tuck card as today
   (`NestClient`, `NestHost`); the rail ticket says "Hatches tomorrow" for a first nest instead of the countdown.
4. **Funnel**: two new measurements, "Joined" (player added, before the board) and "Egg tapped" (first crack tap,
   reported by the client, accepted once). How they enter the funnel without renumbering the v3 steps is the open
   question for review (append-only rule in `FirstSession.lua`).
5. **Copy**: "Tap the egg", "Hatches tomorrow" in `UICopy`; localization export.

## Edge cases

| Case | Expected |
|---|---|
| Player never taps | Egg opens by itself in ~4 s; reward and flow as today |
| Player taps during the move to centre | Taps queue; first crack lands when the egg arrives |
| Rejoin mid-crack / mid-Welcome | Server state as today; client shows the reveal or the garden, never a second hatch |
| Switch off | That piece is exactly beta (27) |
| Returning saves | None of it shows (Welcome is new-save only) |
| Opener drop lands outside the tested band | Normal play; chain may not fire; egg still fills by drop 6 to 8 |
| Nest not loaded yet at the first hello | Bubble waits for the nest instance (or falls back to today's order) |
| Mobile small screen | Egg in the middle at >= 120 px; tap target the whole egg |

## Not this slice

Board in five seconds (loading change; measure first with "Joined"), juicing the classic deck, the reacting shell,
endless/"Chill" mode.

## Test plan

- Offline: Welcome solver spec for the new starter (chain on drop 2 across the aim band; egg fills by drop 6; drops
  stay within MaxEggs); WelcomeProgress thresholds; BearNeeds order with and without `nestfirst`; FirstSession new
  events log once, never out of order; crack controller pure state (taps, auto timer, hold) as a spec.
- Studio (beta place, `/freshsave`): Fable's nine steps in `FIRST-3-MINUTES.md` section 3.

## Risks

- Changing the Welcome charge threshold could break the payout/Stars budget or the existing Welcome specs.
- The crack overlay sitting between the round end and `HatchCinematic` could double-play sounds or desync the reveal.
- Funnel numbering: a wrong step order silently corrupts Creator Hub funnels.

## Revised after the architect review (2026-11-25)

| Original | Revised (why) |
|---|---|
| Raise the Welcome charge threshold | Keep `pip.charge=6` (live, save cap, skip path, meter all use it). With `opener` on, a server-only Welcome charge with its own threshold; on reaching it, `chargeHatch(profile, pip.charge-profile.charge)`. Own attributes for the client meter. Payout unchanged (fixed amounts). |
| "A sure chain on drop two" | A measured hit rate over all first-and-second aim pairs (the first merge clears the fixed queue); the spec also asserts no Trials unlock (3-chain, 250 points, tier V pair) and no rare hatch. Run in Studio (solver spec is not offline). |
| Crack overlay on the board, egg moves to the glass | Cut the move. The taps live inside `HatchCinematic` for the Bear's receipt only, using its per-reveal clock hold (before crack 1, crack 2, the pop); each tap releases the next beat, so the existing sound+buzz plays once. Not `Cinematic.gate` (the capsule shot uses it). Rejoin replays the receipt, never a second grant. |
| Nest first: reorder `Needs.Order` | Also lock the order once the garden is ready: an opened bubble is never replaced; wait up to ~6 s for the nest, else today's order. `nestfirst` needs `needs` and `nest` on. Spec updated. No "Hatches tomorrow" once the egg is ready. |
| Funnel steps "Joined" and "Egg tapped" | One-time custom events "DeckShown" (client, when the loading screen leaves) and "EggTapped" (server-validated, once, Bear owned). No v3 step renumbering. Note: nest first makes step 8 arrive before 7 (held, not corrupted). |
| Three switches | Added to the four `Onboard.lua` tables; default on in the beta (missing config = on). `opener` read once per Welcome round; re-seed if it resolves before the first drop. |
