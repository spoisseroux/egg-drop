# Carry-machine independent source review

**Source verdict: GO. Release acceptance remains with root and Astra.** Reviewed against private v326 / runtime `3c6b61b`, tracked docs HEAD `748ce45`, on November 9, 2026. No Studio operations or production source edits were performed by this reviewer. Reviewer authored the isolated `scripts/GardenCareIntegration.spec.lua` and this note.

## Reviewed boundaries

- `GardenCare`, `GardenCareHost`, `GardenCarePlacement`, `GardenState` and host integration: one existing actor, generation-bound ownership, one exact bay, finite carry/bay leases, preflight before mutation, cheap validation and bounded throttling. Exact replay precedes throttling; a pending equip proof survives ordinary UI-history compaction, and bounded terminal proofs prevent another save. Dry placement requires actual support, body clearance and a path that reaches its endpoint; a planner safety hold is not arrival. Unsafe deliberate set-down retains the hold. System release frees the bay and can safely retain carrying.
- `PlayerProgress`: equipment stays old until exact stored ID/stamp/writer proof. The merge checks current ownership and writer lease/epoch/revision inside the transaction. Ambiguous saves retain the captured operation; foreign owned winners reconcile without rollback. Legacy calls cannot interleave with a staged save or remain permanently dirty after losing to a proven newer winner. Late success changes saved following truth without reclaiming an expired or replaced bay.
- Client care/editor integration: intent lookup remains strict. Cosmetic-only normalization bridges equipment/snapshot ordering under the same owner, character and bay claim. Actual owner and visitor creators start at the dock, avoiding a normal-motion slide from the avatar. Editor callbacks bind to the original claim/epoch. Close, expiry and teardown retire their own ownership. Held actors suppress petting rewards, toys, greetings, wandering, incidental coos and ground foot planting; complete-rig readiness preserves the same visual.
- Avatar/UI: the care controls own a real safe-area Frame under the original ScreenGui. The arm adapter handles Motor6D and current R15 AnimationConstraint joints, reads rig frames and writes only Transform on the existing animation clock. Carry owns shoulder/elbow rotations from bind/target frames; animator translation and original transforms are retained for restoration. Legs and rig attachments/settings are untouched. Compact machine Hue/Charm keeps the existing font preference and 44-pixel actions, resets entry scroll, and tests all charm choices while the complete saved portrait remains visible.

No new persistent schema, wallet, rewards, hatch pool, pigment migration or material dependency is introduced. Seven stable pet IDs, four active hatch offers and the parked material work remain preserved.

## Evidence and limits

The historical `final-native-tests.json` records 301 cases / 36 suites at its checkpoint, not every later source revision. `integration-final-native.json` records all 12 integration cases, including the reproduced compaction failure's correction and real dry/wet-enclosure geometry. Repeated suite executions are not additional unique cases.

Root reports the final actual-Largest targeted cohort passing **45 cases / 7 suites**: CareAvatarJoints6, CarePose6, GardenCareStartup2, CareMachineUI8, HueEggView13, HueSwatchInspection4 and HuePortraitLifecycle6. Root also reports 142 native source matches, zero native compile errors and a passing Rojo build. Local Rojo and diff checks passed. The current source manifest was refreshed; final equality/compile/targeted raw artifacts must correspond to it, rather than the earlier equality file.

Failed-first evidence remains meaningful: production startup exposed the ScreenGui parent error; the real R15 exposed zero Motor6Ds; actual walking exposed animated-arm leakage; actual Largest text exposed the machine footer/fold issue. They were not disproved by earlier mock-based passing suites. AnimationConstraint's first no-op setter reproduces a `7.82310962677e-7` matrix normalization with zero translation/angle change; restoration now compares to an independent one-write control at the unchanged `1e-7` threshold. Other capture, direction, attachment and settings checks remain strict.

Root reports Astra's final current-R15 motion GO over 548 frames. Actual phone controls have saved Ring, picked up, rejected unsafe set-down while retaining the hold, then placed on dry ground and freed the bay. Final compact phone visual acceptance is still pending at this note. Retain the required ordinary/two-owner machine, interruption and camera/movement restoration evidence before private publication. Synthetic R6 coverage is not a physical R6-device claim; physical-phone performance and live-service save/rejoin remain separate limits.

Minor nonblocking copy reflow: the redundant compact Charm description can remain hidden after a size-only rotation until the next refresh; the controls and Secondary accessible labels remain available.

This note certifies the reviewed source boundaries, not publication or live-service persistence.
