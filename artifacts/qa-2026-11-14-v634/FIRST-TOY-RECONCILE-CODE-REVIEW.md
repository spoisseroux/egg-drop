# First Toy automatic receipt reconciliation — independent review

14 November 2026. Reviewer: Sol /backlog_audit; implementation: separate UI Sol. **GO; no required changes.** Read-only runtime review; no Studio, save-data writes or publish.

- `src/client/FirstSpendGuide.lua:41–52`: exemption requires distinct receipt-reconciled/receipt-finished event, valid same-generation flight, equip phase and exact pending toyEquip operation/pet/toy/result identity. It preserves a pending flight without advancing it. Existing Saved + owner-snapshot proof at66–73 remains the only room transition.
- `src/client/HueEggView.lua:679`, `:680`, `:728` are the three internal completion sites supplying true. `:1625–1629` emits that distinct event only with the internal flag and exact reason. An explicit close with the same reason still cancels.
- `src/client/init.client.lua:2721–2722` forwards kind/reason. Existing tab, Back, focus/menu, movement and identity cancellation remain.
- `scripts/FirstSpendReconcile.spec.lua` uses real HueIntent/ToyIntent/View/Guide to reproduce automatic close before typed Saved, requires zero early navigation and one saved handoff, and covers explicit Back/same-reason/tab/focus/stale operation/wrong Saved proof. Pure Guide identity matrix retains narrow cancellation cases.

Reviewer validation: compiler PASS for all three runtime files and both specs; canonical and client ZZ mirrors byte-exact. Native5+2 suites and actual click flow belong to coordinator and were pending at this review. This source review makes no native interaction claim.
