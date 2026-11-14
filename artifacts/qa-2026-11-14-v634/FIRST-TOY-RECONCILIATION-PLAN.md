# First toy receipt reconciliation

Coordinator's ordinary LocalScript trace proves the cancellation order: Give creates a pending equip flight; HueIntent's earlier snapshot callback refreshes HueEggView; automatic receipt-finished close emits the same navigation event as a user close; the host cancels the flight before ToyIntent's exact Saved reconciliation.

Bounded correction submitted to Backlog for architect review:

1. Only the three automatic receipt-finished callsites pass an internal reconciliation flag to HueEggView.close. That flag emits a distinct receipt-reconciled event. Ordinary close/Back/tab actions retain their explicit navigation event, even if a caller uses the same reason string.
2. init.client forwards route kind/reason to FirstSpendGuide.
3. Guide ignores that one automatic event only for its current valid equip flight when ToyIntent still has the matching operation id, toyEquip action, pet id, toy id and purchase result id. It neither accepts a save nor enters the garden. Existing exact Saved receipt plus owner snapshot remains the only equip-to-room transition.
4. Explicit navigation, focus/menu loss, movement, rejection, destruction and actor identity rules remain unchanged.

Tests: extend the pure Guide regression; add a native integration fixture with real HueIntent, ToyIntent, HueEggView.refresh/close and Guide callbacks in the traced order. Assert no navigation before ToyIntent's exact Saved proof and exactly one safe handoff afterward. Explicit Back, an unflagged same-reason close, and a changed pending operation must cancel. No real remotes, profile writes or production renderer changes.

## Implementation checkpoint

Backlog architect GO received and the bounded change is implemented. Runtime files: FirstSpendGuide, HueEggView, init.client. Exactly three automatic close callsites pass the internal flag; explicit same-reason close remains cancellation. Pure Guide 5, WelcomeState 4 and the existing solver sweep pass. New native FirstSpendReconcile 2 runs the actual callback chain, plus explicit Back/same-reason/tab/focus/stale operation/wrong Saved cases. Canonical and ZZ mirrors match and compile; source local budget remains219. Backlog independent CODE REVIEW GO received with no required changes, including independent compilation/mirror checks. Source is frozen for coordinator native execution and controlled actual Give/beat proof.

## Actual acceptance

Coordinator reports native Guide5 and Reconcile2 passing. Controlled actual Give retained generation12 through automatic receipt close, advanced equip→room only after the exact saved proof, and confirmed normal toy play2.68seconds after Give. `Workspace.Bear.OnboardingToyBeat` was `wobble_top`. This closes the observed production handoff defect; focus/navigation/actor identity cancellation guards remain in force.
