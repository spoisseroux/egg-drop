# Personal-toy ordinary-rest completion fix

2026-11-14 · unpublished · systems + UI Sol · root-authorized old-feature repair

Actual root test saved the first toy equip correctly but never showed the cosmetic beat. Two independent causes: follow-only readiness excluded natural rest while movement cancelled the handoff; the host sampled visual.time while normal room rendering samples absolute cosmeticTime/serverNow, allowing a manually started beat to expire immediately on the next frame.

Reviewed plan GO by UI Sol: no actor duration/authority change. Shared client resolver permits only Room/follow-follow or stationary ordinary rest/wanderPause+nookRest, with no park, care, peer/pair, toy reservation/role, contact, carried or focus flags. Nook initial pivot waits .35s. Existing follow timing remains1.8clip/.75quiet/.15guard. Ordinary rest retimes the existing animation into.90clip/.15quiet/.10guard, fitting an existing1.5s rest. Preserve9–16s opportunity spacing; bind current clip to exact actor generation/actionId so takeover cancels. Owner movement cancels immediately.

Files: new PersonalToyOpportunity.lua; RoomView and RoomCompanions both apply its fields; PetPlayVisual consumes strict readiness/timing and existing normal prop/pose. UI Sol owns init.client and FirstSpendGuide changes: same absolute clock, no quietSince rewind, no Guide completion until actual Play.sample created an active normal prop. No unsupported forced pose, reward mutation or server state extension.

Checks: affected runtime and specs compile. New PersonalToyOpportunity.spec5cases exercise exact timings/denial matrix, actual normal prop lifetime in1.5s rest, autonomous cooldown persistence, generation/owner/park cancellation, late-short window then next safe rest. Existing real Garden timeline spec now uses production shared resolver and verifies full clip duration for its actual1.8/.9type. Existing PetPersonalPlay and real timeline must rerun in coordinator's fresh namespace. Actual first-toy Give completion/cancellation is still coordinator live acceptance, not established by source or compile.

Independent code review: UI Sol GO for PersonalToyOpportunity/RoomView/RoomCompanions/Play; systems Sol GO for UI-owned FirstSpendToyHost/Guide/init glue. Raw Garden follow action=nil remains accepted (redundant follow action is absent in production snapshots); added assertion covers it. Runtime/spec compile PASS after final helper change. Coordinator actual Opportunity5/FirstSpendHost3/updatedGardenTimeline and real Give flow remain pending; no live behavior claim yet.

Coordinator verification update: actual phone Client FirstSpendToyHost3/PersonalToyOpportunity5/FirstSpendGuide4/PetPersonalPlay17 passed; mask7 also passed. Actual second Give user flow was still in progress at this checkpoint, so that flow is not marked accepted here.
