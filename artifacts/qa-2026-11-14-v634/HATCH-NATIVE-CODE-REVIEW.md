# Native hatch backend independent code review

2026-11-14 · systems Sol · GO WITH CHANGES (author notified)

Required:

1. `HatchCinematic.new` InputBegan arms skipInput/drainInput whenever active, including decorative tail after receiptReady2.65/2.2. Native skip() then returnsfalse, but HatchReceiptStage consumes drainInput and native button activation rejects. Gate drain to actual inputLocked/acceptedskip. Regression: A/Enter immediately after receiptReady while decorativeActive stilltrue must activate once; held pre-ready skip must settle/drain without purchasing/acking.
2. `HatchDisplayScene.loadHalves` retains per-Scene callback closures in global halfWaiters until CreateMeshPartAsync returns. Destroyed/timed-out scenes remain retained if that engine call stalls. Return a cancellable waiter ticket; detach on destroy/timeout while preserving the single shared engine request. Detach this scene's existing EggPreview.loadTemplates consumer through a weak/cancellable binding too; no broad mesh-loader rewrite required. Test repeated create/cancel while loader stalled, zero retained scene listeners/late mutation.

Remaining reviewed architecture is sound: Cinematic is sole clock/scene owner, receipt borrows token and releases before owned Scene destruction, late callbacks have epoch/destroy/fallback fences, receipt readiness is separate from decorative tail, failed assets settle safely, semantic shell centers remain distinct from localRy(pi), conservative transformed bounds anchor visible geometry above the reference plane. Garden reveal-pose override is viewport-only, preserves expression/material visibility ownership and clears on destruction. Actual graphics/camera/face/render acceptance remains coordinator/Astra, not proved by code.

Nonblocking: HatchReceiptStage.move should skip disabled controls when cheap. No save/reward mutation found. No publish.

## Targeted fixes re-review

GO after author fixes (2026-11-14): Cinematic.skipInputBegan now checks presentation inputLocked before arming drain and clears it if skip is refused, so ready receipts can accept keyboard/gamepad during decorative tail. loadHalves returns a cancel ticket whose callback is cleared and waiter-map entry removed on scene timeout/destroy; its global engine task captures no scene. EggPreview consumer now captures only a detachable holder cleared at lifetime end, preventing retained destroyed scene. Other late-callback guards remain. Author added post-ready confirmation/held-skip regressions; coordinator owns actual execution and visual acceptance. No remaining required source blocker from this review.
