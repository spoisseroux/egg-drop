# Inspect and greet another player's pet — scope only

2026-11-14 · Astra recommendation. **Not implemented; no code/art/runtime changes authorized by this scoping request.** Active QA/unpublished work continues separately. No new species and no revival of rejected Blip designs.

## Proposed experience

Approach another player's real pet, select it, see a small card with its name and appearance, then optionally say hello. The pet looks over and gives a little wave. The owner can allow or disable greetings. Nobody else can pick it up, rename, dress, spend, feed or earn rewards from it.

```text
Nearby real visitor pet
      ↓ click / tap / focused Inspect
┌────────────────────────────────┐
│ Marmalade Moonboots       [×]  │
│ Bear · @owner                  │
│ [small actual-appearance view] │
│ Bond level 4 · Rose / Gloss    │
│ Bell Collar · Star charm       │
│ [ Say hello ]       [ Close ] │
└────────────────────────────────┘
      ↓ allowed + near + idle
brief shared glance + hand wave → ordinary pet behavior
```

Wireframe is a proposed flow, not an implemented screen or proof of live multiplayer. Name falls back to “Bear” until the separate Names feature exists. Bond text is only shown when the new deliberate public summary exists; do not infer it from appearance or mastery.

## What the repository actually supports now

Read-only source inspection on2026-11-14, including the active unpublished tree:

- `src/client/RoomCompanions.lua` already discovers **real Players**, reads their board attributes and renders their selected pet in Room or Board mode. With Park tiers it supports up to11 visitors, nearest6 at full update, others at10Hz within the72-stud observer distance. Rigs carry `CompanionOwnerId`. This is the integration point for selecting a visitor; do not create a second competing pet renderer.
- `src/client/GardenClient.lua` reads the server `GardenState.Snapshot`, checks owner/pet, character identity and `CompanionGeneration`; appearance comes from `PetAppearance` and `PetAppearanceRevision`. `renderActor` has a cosmetic care-gap fallback; **interaction intents must use the exact `get` validation**, not that rendering fallback.
- `src/server/GardenState.lua:snapshot()` includes owner/pet/character/pet generation, behavior/action/actionId, timings, positions, care and park identity. Server transitions/greetings already use generations and paired action IDs. The snapshot does **not** currently supply a custom name or public bond level.
- `src/client/GardenPetVisual.lua` has a queryable Body part and an existing appearance/pose renderer. Hit testing can map a body/model to owner identity, then validate against the real active entry; a client-created model attribute is not authority.
- `src/server/PetContact.lua` is the owner's reach/lease/pulse/reward path. It validates owned pet identity and awards through the owner's transaction. **Do not loosen that code to accept foreign owners.** New social acknowledgement is a separate nonreward action.
- `src/server/HatchProgress.lua` exposes owner bond information in its public profile object, but `GardenClient` does not currently consume a small explicit foreign bond summary. Avoid broadcasting that whole object: it contains wallet/progress/receipts that this card does not need.

## Input and presentation defaults

Inspect range **12 studs** from viewer character to the server-sampled pet ground position, with line-of-sight/visible target. Highlight only the currently selectable pet with a quiet ground outline; never fill the garden with permanent labels.

- PC: click visible foreign pet body, or E on the nearest highlighted **Inspect** prompt when no higher-priority owner/care/station interaction owns E.
- Touch: tap the pet, then the small **Inspect** affordance if crowded targets need disambiguation.44px+ screen-space hit target around visible body, bounded so it cannot swallow camera drag or adjacent pets. Swipes remain camera movement.
- Gamepad: focus nearest visible pet in a small camera-forward cone; X opens Inspect when that prompt is active. D-pad cycles nearby eligible pets only while inspecting/choosing, not during normal avatar movement. A activates Say hello, B closes. Resolve conflicts with existing owner Pet controls by target identity and mode.

Keep the roaming camera, player movement and owner's camera unchanged. Phone card ~260×220 logical px, inside safe-right region above jump/thumbstick, below the topbar notification rail; shrink/remove portrait before crowding controls. Desktop same card family ~300px wide. One card only; outside tap/Escape/B closes. If a menu opens, close the card. On target disappearance/identity change, show brief “Pet moved on” then close; no stale persistent preview offered as if still interactive.

Public card content: custom equipped name IDs/revision or species fallback; species; Roblox owner identity (display name with @username disambiguation where needed); actual currently equipped hue/finish/wearables/toy/charm labels; **bond level only**, if deliberately replicated. No wallet, exact XP, daily pet count, receipts, hidden inventory, spend or private history. Existing appearance renderer may supply an inspect portrait; it is a read-only local clone of published appearance, clearly separate from the world actor and cleaned up on close. Do not replay owner-private animation or expose locked inventory.

## Consent and gentle interaction

**V1 recommendation: Hello only, no rubbing/foreign petting.** It gives a shared expressive response without introducing physical handling, pet-contact rewards or an intrusive permission dialog per tap.

Add owner setting **“Let visitors greet my pet”**, default **On**, with plain explanation that it permits only a brief wave and gives no rewards. Keep an obvious Off toggle in Companions/settings; turning Off immediately cancels pending/new greetings. Public setting state makes the card honestly say “Greetings off”. This is the proposed explicit control, not an assertion that current owners already enabled anything. If the product prefers opt-in for launch, setting default Off is a single policy choice before implementation; do not silently omit the control.

Hello requires viewer within **7 studs** and unobstructed reach; owner and target alive/present; exact current target pet/character/generation; permission On; target idle/follow-settled. Reject while carried/focused/petted, docked, greeting, fetching, in any park equipment slot, transitioning to owner, or otherwise reserved. Owner play/focus always wins. Card remains inspectable when pet is busy; action is visibly disabled with “Playing right now”. Do not queue surprise greetings for after an activity.

On accepted Hello: target looks toward viewer for~.25s, raises one hand and waves twice over~.8s, returns to its prior idle over~.25s. No teleport, chase, hug/contact, forced owner avatar emote, camera takeover or interruption of toys. Small coo is spatial, quiet and respects each listener's SFX/reduced-effects settings. Every observer sees the same action start/duration/identity through existing server-time snapshots. Reduced Motion retains glance and one minimal wave; no particles or extra UI heart reward.

Cooldown defaults: viewer action budget1 accepted attempt per5s, target10s between accepted visitor greetings, viewer-target pair30s. Reject spam with bounded replies; do not stack cues or notifications. No Stars, bond XP, stamps, quest/Play date counts, achievements or economy events from Hello in V1; this removes incentive to farm somebody else's pet.

## Authority and stale-state handling

New request carries target ownerId, petId, characterId, petGeneration, current action/generation token and caller sequence. Server resolves its own actor and sampled positions; clients supply neither destination nor arbitrary animation. Capture eligibility and reserve a short action atomically so two visitors cannot override each other. On a stale actor generation, return a refreshable refusal rather than act on the replacement pet.

Client labels update on public name/appearance revision, but that does not grant ownership authority. Server rechecks consent/range/busy state on start and during the short action. Owner leave, respawn, pet swap, carry, movement out of reach or setting Off cancels it and releases only its own reservation. Old callbacks/late responses cannot revive a destroyed rig, move the new pet or overwrite newer owner action. Replicate a minimal public pet summary separately from economy state; validate bounded stable IDs and public-name parts server-side.

## True two-account acceptance plan

1. Two authenticated accounts in the same private test server; capture both screens with account roles/build clearly recorded. Owner changes appearance/name; visitor sees the confirmed update and correct owner identity. No fake actors count as multiplayer proof.
2. Visitor inspects while owner moves/plays; neither camera changes unexpectedly. Test PC click/E, landscape touch tap vs camera drag, and gamepad focus/cycling. Recheck safe areas with notification rail and chat open.
3. Consent On: one Hello produces the same timed wave on owner and visitor views. Consent Off: no wave, card says why. No change to either wallet, XP, daily pet count or Play date.
4. Owner starts care/carry/park swing/fetch as Hello arrives; owner action wins cleanly. Test two visitors contesting the same target if a third real account is available; otherwise mark three-account contention as unverified and cover server arbitration with fixtures separately.
5. Leave/rejoin, respawn, pet switch, name save, 7/12-stud boundaries, obstruction, latency, out-of-order response, repeated requests and cooldown expiry. No ghost actor, stale name interaction, double wave or leaked reservation.
6. Keep unit/fixture evidence labeled synthetic; actual two-account screenshots/video establish shared behavior, and client/server assertions establish authorization cleanup. Feature stays unshipped until the implementation review and these relevant checks pass.

V1 excludes carry/pet rub/feed/equip/rename/spend on another pet, trading, gifts, private messages, free-text comments, persistent friendships and ranked social rewards. The proposal is small enough to build after current QA stabilizes, but this scoping request alone does not authorize implementation.
