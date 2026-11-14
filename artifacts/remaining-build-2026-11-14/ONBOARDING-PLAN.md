# Remaining onboarding — implementation and test plan

2026-11-14 · Sol · **awaiting architect review**, runtime unchanged by this plan. User authorizes accepted remaining work during QA; no publish. Creative contract: `ONBOARDING-BRIEF.md`; historical scope: `ONBOARDING-V1-SCOPE-2026-11-13.md` §§1–2, reconciled with actual v634 source. The current Welcome grant already awards Bear and +6 together. No second starter round, second +6, save-version bump, new currency or funnel renumbering.

**Status update:** architect GO WITH CHANGES received and coordinator allocated implementation. Continuous universal opener proof is not a blocker to all other accepted work: retain honest manual physics and a tested-aim demo, record actual finite solver coverage, and leave any stronger guarantee to reviewed evidence. Cap refresh preserves charge/run/manual epoch/demo state without seeded rewards; Skip/threshold share the existing grant owner and retry identity; first-spend exact proof and cancellation cover every explicit route, including tabs. Current source and checks are recorded in `ONBOARDING-IMPLEMENTATION.md`.

## Current facts and intended outcome

`FirstHatchGuide` still uses 1/3 numerical copy. `BoardRound.safe` disables overflow only; both its egg-cap outcome and `Simulation.drop` cap can stop Welcome. The normal seed has four eggs, not the accepted three. `Nursery.grantStarter` already uses the stable `starter` transaction and saved ownership/lastHatch receipt; it does not require charge itself, so only the validated host may call it. `FirstSession` already has nine stable steps and a deduplicating custom-event `record(name)` API. `ToyState` already supports atomic receipt acknowledgement plus equip, binding exact result id, pet, toy and expected selection.

Deliver a coherent first Welcome board: three seeded eggs; honest first-match physics; mystery egg in the existing meter; device-appropriate nonblocking input demonstration; one idle demo and one Skip action; then an optional current-price Toy Egg route and saved equip into garden play. Returning owners bypass all Welcome work. Existing reveal, wallet, garden walkthrough and catalog odds remain authoritative.

## File ownership and APIs

Proposed reports/onboarding Sol ownership, after explicit coordinator allocation: new `src/server/WelcomeState.lua`, `src/server/WelcomeSeed.lua`, `src/shared/WelcomeProgress.lua`, `src/client/WelcomePresentation.lua`, `src/client/FirstSpendGuide.lua`; specs `WelcomeSeed`, `WelcomeState`, `WelcomeProgress`, `FirstSpendGuide`; existing `src/server/BoardRound.lua` only if systems Sol releases it. Do not start runtime edits before architect GO and allocation.

Systems Sol retains `init.server.lua`, `init.client.lua`, `UICopy.lua`, `HatchProgress.lua`, `RoomView.lua` and shared UI modules. Supply exact API/glue changes to that owner. Proposed client Welcome module owns its own instances/connections and exposes `new(hosts, dependencies)`, `update(snapshot)`, `step(dt, active)`, `input()`, `destroy()`. Hosts include existing meter well, tray and free coach/header space; dependencies inject localized copy, device glyphs, reduced motion and sends. No new column-zero init.client locals: use a `do` block/clientUI. Existing FirstHatchGuide retains normal field diagrams and delegates Welcome presentation rather than duplicating owners.

## A. Server solver first, then seed

`WelcomeSeed.options()` supplies exactly three settled eggs and a first dispenser tier matching two targets. Start research with two separated tier-II targets symmetrically around center and a tier-I contrast egg outside their approach; do not freeze guessed coordinates as accepted geometry. Run the actual `BoardSimulation` fixed-step solver with both existing presets, default aim .5, endpoints 0/1 and a dense deterministic aim sweep. Track first collision/merge partner, accepted drop, first-merge time and initial overlaps; reject any setup that starts already merging or misses a legal aim.

**Guarantee gate:** finite samples alone are evidence, not proof over continuous [0,1]. Select a reviewed seed whose two same-tier contact regions overlap across the bounded opening trajectories with positive margin; record minimum collision margin and an interval bound between samples. If that cannot be established, stop seed integration and request an architect/creative revision of the opener contract. Never silently snap/restrict/replace manual aim or move a settled target after input. A seeded demo at a tested aim may be called guaranteed only for that demo; do not claim every manual opening merges until proven. After the first merge, return to the existing queue/preset; no continuing guided physics or automatic play.

Welcome `safe` rounds suppress both overflow and egg-cap round failure, while ordinary fields retain both. Do **not** remove the simulation's resource bound and allow unbounded eggs. At the existing cap, use a reviewed bounded Welcome-only board refresh retaining authoritative hatch charge, grant/retry state, run generation, manual-input/demo flags and earned progression; reseed three eggs without a RoundOver/miss/payout. Render the existing quiet reset transition. This recovery needs architect review because simply changing `Round.over` still leaves `Simulation.drop` refusing at MaxEggs. Refresh must not create a second idle demo or reward, clear charge, or affect ordinary field results. Manual default/extreme solver cases and cap recovery must pass before visual integration.

## B. Active-time, idle demo and Skip

`WelcomeState` is a server-owned per-run object: generation, active seconds, manual-input epoch, accepted drop count, demoUsed, skipPending. No saved timer or client-provided duration. Accumulate time only in Welcome, Board mode, unpaused/active control; menu/background transitions reset the idle countdown. Existing validated focus/window state supplies inactivity; client signals can only postpone a free demo, never authorize rewards. Skip becomes eligible after three active seconds. Ghost replay occurs once after eight idle seconds; one demo becomes eligible after 25 idle seconds with zero accepted drops/manual input for that interval. Demonstration is one direct server call through the same accepted-drop helper as real input, using tested intended-match aim; never fire a fake client input or both paths.

Before demo, recheck run generation, no pet, no reveal, same manual-input epoch, active phase and `Simulation.canDrop`. Mark demoUsed only on accepted drop. Manual input handling advances the epoch before scheduling; server execution order is the race arbiter. A genuine drop processed before the demo cancels it; if demo already committed, later manual drop remains normal input and cannot replay the demo. Pause/menu/run exit destroys pending work. Log `OnbIdleDemo` once through the existing session recorder.

Add a narrow existing-intent action for Welcome Skip with exact current RunSequence and bounded nonce. Server validates current player/board, ready profile, Welcome/no pet, generation, active eligibility and existing busy/closing fences; stale/repeated messages are harmless. Both charge completion and Skip request the same `grantWelcome` single flight and existing `Nursery.grantStarter` transaction. Do not create another grant id, reward or shortcut write. Preserve pending transaction/candidate on retry and exact saved lastHatch id for normal reveal. Log `OnbSkipWelcome` once on accepted skip; disable pill while pending, expose existing save feedback, returning ownership hides it. Reconnect relies on saved ownership and receipt, not transient skip flags.

## C. Mystery egg and ghost presentation

`WelcomeProgress.stage(charge, threshold)` derives intact/first/second/ready at 0, ceil(threshold/3), ceil(2*threshold/3), threshold, clamped and driven by replicated authoritative charge. Current grant threshold comes from PetCatalog; never assume three merges. Persist nothing. Initial snapshot/reconstruction sets a baseline silently; only a later monotonic progress increase in the same run plays the restrained existing cue (three pitches) and 140ms ±3° wobble. Reduced Motion swaps static stages only; audio respects existing sound/mute mix. A threshold snapshot hands ownership to existing reveal, never another cinematic.

Build cream/mint egg and cumulative short zigzag cracks procedurally within the existing meter well with 8px inset. Preserve wallet/tray/status bounds. Touch ghost is authored cream translucent UI shapes, loop 1.6s then rest 2s; keyboard/gamepad use existing arrow/Space and D-pad/A glyphs. Remove immediately on accepted drop, manual input, menu or phase exit; reduced motion static arrow/outline. Welcome lesson copy is “Hatch a friend”, “Match”, “One more!” through UICopy. Skip has >=48px touch target, appears in measured free header/coach space after 3s, never under Roblox top-left controls or over play controls. No new modal.

Fresh-owner boot may cap existing DeckBoot at 1.2s through its options/clock; returning behavior stays current. Existing greeting/reveal timing and Meet route should first be verified; change only if actual fresh-session evidence shows the accepted handoff missing.

## D. Optional first spend and Give to Bear

`FirstSpendGuide` is a pure derived stage helper plus cancellable navigation owner. Inputs: owns pet, pending starter reveal, saved toy ownership/receipts/pending result, equipped toy, current wallet, existing coach bits, current screen/mode/readiness. Avoid daily pet counts and transient timers. Any saved toy ownership/valid prior purchase proves first toy spend even after bounded receipt history rotates. No new required save field. Existing funnel FirstSpend remains any first Stars spend; this affordance must not redefine its identity.

After starter reward is saved and reveal closes, eligible existing results/coach affordance points to Hatch eggs only if ToyCatalog.Cost is affordable and first toy spend is absent. Opening selects Toy Egg; other eggs, exact current catalog odds/prices, Back and ordinary choices stay available. Poor balance gets normal feedback/earn route; no hidden free toy, auto-purchase, forced sheet or teleport. A wandering player is not redirected. Existing garden walkthrough does not get replaced or repeated.

For the pending first Toy purchase receipt, label primary action “Give to Bear” via localized pet name. Invoke existing ToyIntent/ToyState `toyEquip` with resultId and expectedToy so equip and receipt ack are one saved operation. Navigate to Room only after exact Saved/equipped proof; keep dismissal/ack available. On failure/retry do not set coach completion or navigate as success. Generation-fence all delayed navigation; cancel on user mode/menu change. Wait for existing owner actor/assets, then request the existing permitted toy-play behavior once. Do not revive retired toyStart/toyJoin/toyCancel shared activity remotes. Confirm existing autonomous pet toy renderer actually provides the play beat before adding any new action. Server-confirmed petToys/appearance remains what observers see.

## Tests and acceptance gates

| Case | Expected evidence |
|---|---|
| Seed default/extremes/dense aims, both presets | Actual fixed-step solver first merge; zero seed overlap, accepted aim unchanged; record margin/proof limits. |
| Normal field regression | Existing loss/overflow/cap/queue/rewards unchanged. |
| Welcome overflow/cap | No failure; bounded resources and playable recovery; saved charge unchanged. |
| Demo/manual/menu/background/reset races | At most one accepted demo per Welcome lifetime, correct generation, paused time excluded, real input wins if processed first. |
| Skip normal/repeat/threshold race/reconnect | One saved Bear/+6, stable receipt, one reveal; no extra paid starter round. |
| Store failure before/after commit | Existing transaction retry converges; no success UI/coach bit before proof. |
| Mystery stage boundaries/reconstruction | Correct threshold math, cumulative cracks, no rejoin cue replay, reduced motion static. |
| Desktop + 812x354 + preferred text/pseudo-locale | Egg inset, unobscured tray/wallet/Roblox controls, >=48px Skip, glyph/device variants; actual captures reviewed by Astra. |
| First toy spend/decline/poor balance/rejoin | Current catalog odds, all choices/Back retained; saved receipt reconstructs stage; no repeat coaching after ownership. |
| Equip retry/change pet/stale result/menu cancel | Exact existing server proof before navigation; cancellation blocks delayed takeover, ordinary dismissal available. |
| Observer readiness | Actual shared equipped toy/play on second client if available; one-client evidence labeled honestly. |
| Analytics/localization | Existing nine funnel numbers unchanged; once/session skip/demo custom identities; existing event ingestion still unproven in Studio. Export strings before eventual authorized build, cloud sync/publish coordinator-owned. |

Order: architect review → allocate modules/host glue → solver/seed + bounded no-fail spec → grant/demo/skip spec → client egg/ghost → optional spend → independent code review/fix → coordinator fresh Studio specs and actual device captures/Astra critique. No external publish, report migration, release flag changes, catalog retune, new reward or art upload is included. Physical phones, real second-client behavior and service-backed reconnect remain acceptance debt unless actually exercised.
