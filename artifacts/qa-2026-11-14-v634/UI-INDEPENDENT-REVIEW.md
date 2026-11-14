# QA UI independent code review

2026-11-14 · systems Sol · GO WITH CHANGES · no publish

Reviewed UI-IMPLEMENTATION.md/frozen source list and runtime queue/rail, asset warmup, preview/type routing, focus row, help scroll, Kit adapter, price state, preview feedback and host integration.

Required changes:

1. `src/client/HowItWorks.lua` builds a scrollable Cards body (~157), but `bind()` sinks Up/Down/DPad directions without scrolling (~224–242), while gamepad selection starts on GotIt. Lower cards in portrait/long-copy layouts cannot be reached using keyboard/gamepad. Own bounded vertical scroll in this overlay, retaining fixed footer/B behavior. Test both directions to the last card, then close and verify input release.
2. `src/client/DeckKit.lua` toaster adapter (~1121) uses message+Stars as event identity. Distinct equal awards during one dwell now collapse into one visual notice; the previous adapter queued each call. Assign each ordinary show call a serial key; dedupe only when the caller supplies actual event/operation identity. Test two identical amount/text calls present twice, and explicit repeated event identity presents once.

Nonblocking: `FocusRow.layout(320,190,true)` leaves 2px between Back and the bond card rather than the approved 8px. Cap the card to available width (still >=150) or provide a bounded narrow fallback, and assert all row gaps.

Remaining reviewed mechanisms are GO subject to actual GUI fixtures: transient queue preempts persistent status; owner destruction cancels work; narrow notices defer without acknowledgement; timeouts retain stalled engine concurrency slots; preview route epochs/cancellation reject stale loads; confirmed-wallet shortfalls preserve actual prices; host results selection does not reset a round or buy automatically.

Separate integration fix: ParkClient outer facade previously referenced UICopy scoped only inside the per-site factory. Require moved to shared scope; initial missing actors guarded; exact-grove production facade case now executes step and departure cleanup. Both files compile. Coordinator reports restarted entrypoint no repeated ParkCopy error. Current-source ParkFetch8 and LossPayout4 passed actual isolated Server Play. InPlaceResults/GUI acceptance and actual F retry remain coordinator owned.

Coordinator identified missing `hub.quests.title` localized quest target label; UICopy owner notified to append the exact key. Production hatch and material scope are unchanged by this review.

## Targeted re-review after owner fixes

Required UI changes are source GO (2026-11-14): How.scroll now owns bounded keyboard/DPad Up/Down/W/S scrolling, fixed footer and close behavior retained; default toaster calls get a per-show serial while explicit event keys dedupe intentionally; FocusRow at320 caps bond width to184, preserving8px Back gap. Added rail singleton teardown disconnects RenderStepped before GUI destruction, preventing cloned-spec rails from recreating themselves. UICopy owner added hub.quests.title. Coordinator actual GUI tests remain required; source review is not native visual acceptance.

Separate board reviewer findings applied: DeckResultsInPlace measured payout/goal row heights now include each label's actual LineHeight; fifth InPlaceResults fixture checks long wrapped TextBounds and6px row spacing. Opening results after hide resets the entrance clock, while same-visible receipt updates/resize retain it. Modules/spec compile; actual5-case GUI execution pending coordinator.

## Board targeted source re-review

Reports/UI Sol returned GO for the row/goal actual LineHeight multiplier+ceil and new multiline TextBounds/6px-spacing fixture, plus opening-only entrance clock reset. No source blocker remains in those fixes. Coordinator owns actual5-case execution and rendered acceptance.
