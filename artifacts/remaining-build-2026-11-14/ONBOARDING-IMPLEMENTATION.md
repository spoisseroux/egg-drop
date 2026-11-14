# Remaining onboarding — unpublished implementation checkpoint

2026-11-14 · Sol · user authorized accepted remaining work during QA, **no publish**. Parent coordinator owns Studio verification and final evidence. This lane made no Studio calls, commits, external report writes or publication.

## Delivered source

- `WelcomeSeed` creates three settled eggs at x=-1.5/I, +.7/I, +2.75/II and a matching first dispenser I, using the original manual aim and server solver. First natural merge restores the normal queue/contact policy. Full or spawn-blocked Welcome trays can refresh to three eggs while preserving monotonic egg ids and accepted drop count; caller retains charge, run generation, score, WelcomeState, demo/input epoch and pending starter transaction. Seeded eggs never grant charge/rewards.
- `WelcomeState` provides active timing, one idle replay/demo ticket, input-epoch cancellation, synchronous accepted demo dispatch, generation validation and one grant-request latch. Systems Sol integrates it with the existing server drop/grant owner; this lane does not add a reward path. `BoardRound.safe` excludes both overflow and egg-cap failure while the simulation still enforces its resource bound.
- `WelcomeProgress` derives cumulative charge stages from the real pet threshold, gates cues against same-run progress and silent reconstruction, and makes Applied replies terminal against late Retrying messages for the same run.
- `WelcomePresentation` draws an original cream/mint strip ovoid, speckles and cumulative cracks; device gesture/glyphs, static Reduced Motion, short wobble/cues, one pending Skip and explicit layout-block diagnostics. Presentation checkpoints preserve baseline, manual-interaction, pending and replay state across actual HUD reconstruction.
- Actual `DeckScreen` PC/phone HUD uses the existing EggsLeft well for the mystery egg and existing three-row Goals allocation for Skip. Physical 8px egg inset and 72x48 Skip account for the desktop UIScale. No board, wallet, aim/drop/menu hit rect is moved. The portrait fallback uses its existing meter/coach region and reports insufficient room rather than overlapping controls. Fresh Welcome boot receives the 1200ms cap before initial boot starts.

Physical sizing regression detail: UDim offsets quantize to integer authored layout pixels. At desktop scale .77, assigning `48/.77` becomes62 authored px and only47.74 physical px. The current code rounds hit/host dimensions **up** before scaling (63→48.51 physical), and rounds the egg's authored side **down** to preserve its physical inset. The HUD fixture asserts the full >=48px/72px bounds and includes actual hit/coach/meter/egg/host rectangles plus all scale factors in failures; it does not hide or relax the control requirement.
- `FirstHatchGuide` uses localized “Hatch a friend”, “Match”, “One more!” instead of numerical teaching steps.
- `FirstSpendGuide` reconstructs optional purchase/earn/receipt/done stages from saved pet/toy state and current catalog cost. Exact typed toy purchase proof supplies “Give to {pet}”; exact saved equip/ack proof precedes Room navigation. Same-screen tab/channel/pet choices and all explicit route changes invalidate navigation; an owned internal close is guarded. Existing personal toy scheduler runs only after actual actor/appearance readiness. Ordinary receipt Store remains available; no new currency or retired shared-toy remote is used.
- `init.client` wiring is contained in an IIFE to fit the real Luau register limit and retains **219 column-zero locals**. Server active pulses cache both boolean and RunSequence, so a Welcome-to-Welcome reset restarts server timing correctly.

## Verification performed by this lane

`python scripts/testhelpers/run_welcome.py` executes real Luau solver/config/state/guide source, with only Roblox Vector2/color/import shims. Latest result:

```
SOLVER tested=2002 min=0.8666666666666667 max=3.533333333333333 universalProof=false
WelcomeState: 4 passed
FirstSpendGuide: 3 passed
```

The sweep covers both original presets and aims 0..1 in .001 increments after settling; it also checks three seeds earn no automatic merges, queue restoration, normal-field loss versus safe Welcome, and bounded refresh. These finite traces **do not prove every continuous aim**. The .5 demonstration aim is explicitly tested; manual physics/aim are unchanged. Parent should retain this honest distinction in acceptance evidence.

State cases cover inactive reset, active Skip timing, replay once, real-input epoch winning a pending demo, rejected versus accepted drop, demo once, grant-request single flight, destruction, threshold boundaries, silent reconstruction and Applied→late Retrying monotonicity. FirstSpend cases cover insufficient balance, optional eligibility, saved receipt reconstruction, unrelated/malformed purchase proof, old receipt eviction, exact equip proof/readiness, retries, duplicate input, same-screen navigation, rejection and shutdown.

All owned runtime/spec files compile through `luau-compile --null`, including the actual `init.client.lua` entry point. `WelcomePresentation` and `WelcomeHUDBounds` are real GUI fixtures for coordinator execution; compile alone is not a visual/layout pass.

## Coordinator fixture instructions

- Server: `WelcomeSeed(server,shared)` and `WelcomeState(server,shared)`.
- Client: `FirstSpendGuide(client,shared)` and `WelcomePresentation(client,gui)`.
- Client actual HUD: `WelcomeHUDBounds(client,PlayerGui)` checks 812x354, 1280x720 and 640x360, including physical hit size/inset, unchanged tray, passive Reduced Motion and real same-run HUD rebuild.
- For a capture: `WelcomeHUDBounds(client,PlayerGui,{keepFixture=true,width=812,height=354})` leaves `_WelcomeHUDQA` with an evidence label. This is an **actual fixed-size GUI fixture**, not a physical phone or emulator. It returns measured bounds. Coordinator owns capture/removal of the fixture and actual runtime desktop/phone-size visual review with Astra.

Independent client review requested from world Sol; identified run-active cache and HUD checkpoint issues were fixed with regressions. Parent live test observed three rapid Skip requests converging on one Bear/+6 and a stable receipt; its initial out-of-order Applied/Retrying replies motivated the terminal reply fix above. Service-backed reconnect, physical devices, multi-owner shared toy appearance, localized text fit and actual final live captures remain separate acceptance gates until the coordinator exercises them.


## Coordinator acceptance checkpoint — before QA UI

Actual fresh Client Play: WelcomePresentation5/5, FirstSpendGuide3/3, client local budget219. WelcomeHUDBounds3/3 passed at812×354,1280×720 and640×360, including physical72×48 Skip, inset and same-run HUD reconstruction. Three rapid live Skip requests returned Applied×3 and converged on ONE Bear/+6, nectar12, revision2 and the same saved pet/receipt identity. The coordinator saved the unpublished-before-QA checkpoint. No publish. Physical devices and service-backed reconnect are not implied by these fixtures.
