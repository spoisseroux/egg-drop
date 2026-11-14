# Unpublished QA checkpoint — 14 November 2026

Implementation and verification are complete for this checkpoint. **No experience publish.** The last published QA baseline remains private v634. This document supersedes earlier staged/pending statements in the working notes.

## Changes ready for QA

- World overlaps: all 196 reported pairs removed; original UVs/palette and bounded footprints preserved. Five vegetation objects cleared for the second park. The canonical native collision model now survives fresh builds; run `python scripts/world_native_collision.py --check` before Rojo.
- Garden: independent second park/shared fetch, exact activity reservations and one completion owner; Play date analytics recovery and qualified-loss +1 Star payout. Reports use deterministic shards with immutable retries/deduplication.
- Interface: results keep the same Pocket Deck hardware/LCD, four-way controls, generic Hatch eggs route, correct wallet clearance, one CoreGui-aware notification rail, consistent focus controls, rounded preview clipping, typed image loading/retry, clearer prices, complete help and quieter interactions.
- Hatches: one shared native scene/clock, centered forward scale/fade entrance, correctly oriented same-side shells clearing quickly, Bear expressions/hop/wave and reusable item/cosmetic adapters. Bear 4.4s/item 3.1s; receipts unlock 2.65s/2.2s. Actual Wobble Top and Ball each measure 115px in a 200px receipt seat. Reduced Motion uses a 150ms fade. Five new timed SFX are approved and load at the exact durations.
- Jelly: active Material Egg pool 4 costs 16 Stars; initial Gloss 45% / Jelly 10% / Matte 45%, no duplicates, conditional odds update visibly. Restricted/unknown policy uses the disclosed fixed order. Old pools/reservations/receipts remain immutable. Native body/head/secondary/ears-tail transparency is 15/8/8/12%; face/accessories stay opaque. Two named water bases render opaque while retaining flow textures, fixing observed water sorting through Jelly.
- Music: new 72-second garden/Pocket Deck working candidates use real documented CC0 rubber squeaks and bubbles, with a quiet stable motif. Approved assets 73327108010209 / 108432047352639 load and run in Studio. The rejected 104 BPM loops and old bursts remain unmapped. Listening quality is still Spencer's QA; technical/creative compliance reviews do not claim a listening verdict.
- First Toy: actual callback-order race fixed. Automatic receipt reconciliation preserves only the exact pending equip flight; Saved proof still controls navigation. Explicit navigation/focus/movement cancels normally. The real Give click confirmed one visible toy play 2.68s later, after a safe idle opportunity.

## Evidence

[Consolidated native tests](native-final-verification.json): **56 server suites and 36 client suites pass**, across full initial runs and targeted corrections/reruns. Initial reports are retained; this is not described as one clean full run. Post-mapping audio 16/7/3, help 36 and reconciliation2 are included in the final verification history.

Fresh complete-Rojo world import, without ApplyMesh rescue: **20,920 rays, zero hit mismatches/position delta**, positive hits on all eight changed solids (Landmarks65). All170 physical payload hashes match the approved native export. Source-only XML had 4,302 mismatches in the earlier 5,184-ray comparison; the native model and stale-checkpoint guard fix that portability defect.

[Actual Bear receipt](hatch-production/native-final-bear-receipt.jpg) · [Actual toy receipt](hatch-production/native-final-toy-receipt.jpg) · [115px item proof](hatch-production/native-final-200px-items.png) · [Phone Material Egg](jelly-native/native-final-phone-material-odds.jpg) · [Real first-toy proof](first-toy-final-native-proof.json).

[Garden/deck listening excerpts and full loops](audio/revision-3-full/README.md) · [Jelly appearance review](JELLY-NATIVE-REVIEW.md) · [Full QA coverage](QA-COMPLETION-AUDIT.md).

Local native Studio copies are under ignored `build/`; these preserve native physics and are separate from generated Rojo files. Local translation export: 591 strings. Cloud localization sync was not run because there is no publish.

## Deliberately deferred

- Blip stays disabled. Spencer hates the alien and all D/E/F redesigns; consider a different pet later.
- [Names Egg](../pet-social-scope-2026-11-14/NAMES-EGG-SCOPE.md) and [visitor pet inspect/Hello](../pet-social-scope-2026-11-14/VISITOR-PET-SCOPE.md) are scopes only.
- Physical-device, genuine two-account and published-service/rejoin/Creator Analytics checks remain release acceptance work. No claim that local fixtures replace those observations.
- The localization exporter regenerated the pre-existing modified `artifacts/localization/hardcoded-strings.csv`; its exact earlier contents were not backed up. It is excluded from this commit. Later exports use the separate QA review path.

Final native copy: [egg-drop-native-final-unpublished-2026-11-14.rbxl](../../../build/egg-drop-native-final-unpublished-2026-11-14.rbxl), 1663457 bytes. [Save/hash and final source compilation proof](FINAL-NATIVE-SAVE.json). All 301 runtime sources match disk; all 498 Edit script containers compile with no temporary First Toy probes.
