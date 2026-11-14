# Board QA implementation review packet

2026-11-14 · unpublished source only · no production hatch changes, no Blip work, no publish.

## Changes for independent code review

- `src/client/DeckScreen.lua`: resultsView/physical regions from the exact current gameplay LCD; results layer uses that clip, not a full phone sheet. Existing hardware/hit seats and tested Welcome HUD interfaces retained. Phone desktop plate-overlay is hidden because `build_shell.py` proves it contains baked desktop wells/glass recess mapped differently from phone controls; phone's actual wells remain. Wordmark is inset inside its shoulder. Bottom-left quest handle/card gets a real callback, blocked under result/menu input ownership.
- `src/client/DeckResultsInPlace.lua` (new): physical three-region content, own clipped/scrollable panes and fixed four-action order; max8px content transition, no shell/camera writes. Pending actions disabled, receipt truth/count-up delegated to existing owner; Hatch eggs always routes to store without buying. Reading Star yaw ±20°, one viewport mesh, clean opaque gold material (explicit optional CelebrationKit flag; no mesh/art upload). Wallet is inset inside central LCD region, leaving title clearance. Actions retain44px height and a scrolling fallback when the existing region is short.
- `src/client/DeckResults.lua`: in-place branch/four-way API; legacy builders remain for compatibility fixtures. Positive paid losses no longer inherit zero-Star silver presentation. Existing callback/data/feedback owner remains.
- `src/client/RecapFeedback.lua`: optional per-instance count window; new in-place timing .30–.65s, default behavior unchanged. Existing pending/Saved/seen receipt gates are unchanged.
- `src/client/DeckBackdrop.lua`: actual-case exclusion prevents drifting motifs entering hardware, plus Moonpond delegate for exterior/board/thumbnail. Rounded composite roots use a CanvasGroup only when no existing parent CanvasGroup owns that mask. Existing ids and defaults remain.
- `src/client/DeckArt.lua`: native disabled purchases retain exact Astra opaque colors and inert interaction; disabled border survives focus/hover restore. Existing enabled geometry stays.
- `src/shared/HeatPayout.lua`, `src/server/HatchProgress.lua`: approved+1 only for a completed zero-goal loss with score>=100, merges>=3, drops>=6. Computed from captured validated summary inside existing award transaction. Existing goal+2, win amounts and pass/Supporter arithmetic unchanged.
- `src/server/ParkFetch.lua`: old-feature usability fix: fetch-specific eligibility includes truly idle post-activity rest/cooldown; autonomous equipment cooldown stays unchanged. No reservation/contact/care/focus/greeting/hop interruption. Idle snapshots include per-owner availability and lane readiness, so Throw is disabled with “Pets are playing” when candidates are occupied instead of promising ready and rejecting repeatedly.
- `src/client/ParkClient.lua`, `ParkThrowControl.lua`, `src/server/ParkGameCommit.lua`, `init.server.lua`: one persistent park status provider in shared rail, transient fetch feedback shares rail, literal Games/Playing/Saving state; ParkGamesPending is ephemeral board state cleared by the same durable commit finalizer. No reward/count inflation.
- `init.client.lua`/UICopy remain UI Sol owned: that owner applied provided resultsView/caseBounds, four-way input, confirmed next-heat Store-only selection (no directional reset), quest callback, generic Hatch eggs and exact effort label/copy. Review their final diff separately as shared integration.

## Verification available

- Root isolated Server fresh-current-source **ParkFetch8/8** and **LossPayout4/4** passed after rest-window fix/qualified payout. Updated availability assertion is within existing fetch case; request one relevant rerun.
- New `scripts/InPlaceResults.spec.lua`4cases cover current LCD region bounds at812×354/1280×720/640×360, unchanged physical device/hardware through results, four-way focus and heat direction without spend/reset, pending gates, visible generic store, positive-loss gold/zero silver, custom count window and unchanged legacy default.
- `scripts/HeatPayout.spec.lua` adds pure threshold/malformed-boundary assertions; `scripts/LossPayout.spec.lua`4cases cover boosts, boundary refusals, before/after ambiguous writes/caller mutation, idempotent sequence and unchanged wins.
- Luau compile passed on new/changed board files. Actual current client fixtures/captures, native disabled styling, Moonpond render, park availability and full regression suite are coordinator-owned and remain pending until explicitly recorded.

## Review concerns

1. Pending→Saved and resize must preserve receipt deduplication, input ownership and animation clock; no positive payout may show “no Stars.”
2. Same LCD coordinate system and original camera/hardware must hold before/after; scrollable short-region content cannot hide/unreach actions or clip translated goal text.
3. Moonpond's static delegate must not add per-frame instances or lose case/field masking; normal backgrounds remain intact.
4. Fetch cooldown invitation must never steal a busy pet; per-owner readiness is snapshot advisory, server validation remains authoritative.
5. Native disabled fill/lip/text cannot re-enable spending or a hidden press animation.

Actual screenshots and Astra critique are required after review/tests. Star clean material is a local viewport treatment, not an unproven claim that source mesh UV/topology is repaired. If actual side inspection still shows duplicated geometry, stop and supply Astra measured mesh evidence before any asset edit/import.
