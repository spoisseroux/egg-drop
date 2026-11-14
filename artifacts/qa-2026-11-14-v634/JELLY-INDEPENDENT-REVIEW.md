# Staged Jelly source review

2026-11-14 · UI Sol reviewing Systems Sol's frozen `JELLY-IMPLEMENTATION.md` packet. **Changes required**; no activation or publish.

1. `src/server/MaterialState.lua:95` reads `reservation.quote` before proving the reservation is a table. A scalar persisted reservation can throw during validation. Reject scalar/string/boolean values before field access; add malformed reservation coverage.
2. `src/client/PetMaterials.lua:164–168` destroys the surface after a paint exception but retains its Jelly profile. The new alpha resolver accepts the profile alone, so a failed binding can remain translucent. Clear all binding proof on failure, including when the surface is already absent, and require a current valid surface before granting Jelly alpha. Cover failure/disconnection with opaque fallback.
3. `src/server/HatchProgress.lua:412` publishes restriction with `== true`, while permission now requires explicit `false`. Unknown policy consequently publishes `restricted=false` with fixed selection mode. Publish the shared fail-closed restriction helper and cover unknown and explicit-false public snapshots.

The remaining reviewed quote/reservation/receipt paths preserve strict historical shapes, fixed target and cost binding, durable accepted outcomes across retries/policy changes, and no rerolls. Policy changes before first reservation cannot charge. Pool 2 and unverified native flags remain unchanged. Native production renderer acceptance remains separate from look-study captures.

The UI-owned fixed-next disclosure correction is present: missing/stale advertised targets reject purchase, and all-owned/nil is terminal. Its fixture still needs coordinator execution.

UI lane verification after review: seven affected UI/helper/spec files compiled; offline NotificationQueue 8, QAUIState 4, and UIAssetWarmup 10 passed. No systems-owned source was edited during this review.

## Targeted re-review

**GO** after Systems' fixes. Every non-nil reservation is table-checked before field access. The renderer now releases all binding proof on paint failure and requires a current parented, verified SurfaceAppearance before granting alpha. Public restriction uses the shared fail-closed helper. Added tests cover scalar/false reservations, unknown policy snapshots, detached surfaces and a real native property-write failure. Coordinator execution of JellyMaterialPool 9 and JellyMaterials 5, plus native renderer acceptance, remains separate.
