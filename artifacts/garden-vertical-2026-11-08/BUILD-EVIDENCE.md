# Garden vertical slice — verified private-build candidate

The bounded two-pet foundation passed native verification and both reviews. Commit/push and private publication are the remaining release steps; v180/runtime7910cf8 stays the published checkpoint until the new version is verified. This is a private prototype, not production-readiness certification.

## Models and source gate

Astra authored Zivvi and Ovelle in a separate Blender scene and reviewed their actual rendered geometry. Native Studio imports and the color-separated cuff patch succeeded. The production factory selects the imported meshes while retaining a primitive fallback. Stable catalog IDs remain `pip` and `puddle`; display names now come from the catalog.

Initial Rojo reification lost 25 immutable mesh resources, although the XML and server snapshot retained correct asset references. After one diagnostic repair and three bounded batches, the Edit-only repair helper validated all33 resources. An actual native Rojo Disconnect/Connect then preserved33/33; the validation made zero async calls. The renderer now rejects empty/zero-size mesh resources. The initial checkerboard hatch capture is a reproduced failure, not an accepted gallery image.

Fresh Play passed95/95 source hash and native compile checks. The first hatch now starts and reaches Meet without resizing; the managed, repaired templates render Zivvi's actual grin/cuffs correctly. See `fresh-zivvi-hatch-no-resize-final.png`.

## Native fixtures run so far

Client:195 unique cases passed, comprising GardenPetVisual11, GardenActivity4, GardenClient8, PetCharmFocus3, HatchOwnerTransition1, CompanionEligibility5, PetGreetingShot61, HatchCinematic7, PetHeldContact8, PetContactIntentClient12, PetAffection8, RoamReturnCamera15, GreetingLifecycle4, CompanionScale17, PetNightFace8, WelcomeCoaching6, JournalPurpose4, Onboarding8 and FocusFraming5. Repeated suites are not counted twice. Final production FocusFraming passed strict body occupancy, all focused-pose containment, live-pose restoration, reduced→full motion, bounded caching and short-greet/contact expression checks.

Server:90 unique cases passed, comprising GardenState12, PetAppearance8, HatchProgress21, PetContact16, PetAward15, SessionRecovery8, SessionHost2, PetContactHost4 and GardenFocusReach4. The last suite exercises72 actual factory/planner/coordinator/care configurations. These use isolated adapters or an isolated execution of actual host/profile source; no live user profile is changed. The initial ordinary Script-based harness lacked Source capabilities for four sandbox suites. Re-running those through the plugin-capable QA host passed. Deliberate connection/save failures emitted expected fixture warnings; these are not ordinary play-session errors. Final affected host suites were rerun after care-anchor changes: PetContactHost4 and SessionHost2 passed.

Source review caught and corrected optimistic charm publication, cross-pet pending save generations, delayed focus acquisition after character/equip replacement, missing recovered charm publication, sender-only focus synchronization and bounded rapid reopen retries. Independent review gave GO on those corrections and on the later mesh fallback/repair helper and catalog-derived names. Native end-to-end checks remain necessary.

## Actual controls and behavior

- Two actual pointer drops completed the fresh welcome and opened the starter reveal. Native Meet acknowledged its exact receipt; wallet6, inventory mask1 and revision3 were unchanged thereafter.
- Native charm control: Applied retained the prior visible dot; after Saved, public preference became OFF, the dot disappeared and the control changed to Show charm. Wallet/inventory/hatch revision remained unchanged. `native-charm-off-confirmed-desktop.json` records the state. No physical-phone claim.
- Native Back returned to roaming with the menu collapsed.
- A read-only40-second observation of the real client/server recorded80 samples covering follow/investigate/play/rest, shove/settle, and toy motion. Wallet6→6 and hatch revision3→3 prove this autonomous loop did not award idle currency.

## Reproduced focus blocker — repaired and verified

Actual focused staging placed Zivvi7.704 studs horizontally from the owner with the dot ON, and7.078 with it OFF. The authoritative seven-stud focus check correctly refused acquisition, so the local close-up and remote AI could disagree. Pure framing and state fixtures had not tested this cross-component boundary. `focus-staging-rejected-native-before.json` records the actual acquisition/pulse trace and positions.

Astra approved separating the stage from the lens: floor-project a4.8-forward/2.4-side stage, require true3D distance≤6.7, fit the lens independently, test visible-owner sightlines across the existing bearings, and use a generation-matching server-accepted focus target for care. The seven-stud authority, reward lease, odds and daily care cap remain unchanged. Actual acquisition now accepts the6.135stud target. A26-second actual E hold saved two naturally rolled+1 awards, wallet6→8, petCount0→2 and revision3→5. Key release ended care exactly once. Audio playback traces loaded the purr/reaction assets; this does not certify an audible mix.

Actual nearby E entry then native Back restored the exact original camera and FOV, max translated component error0. Native W movement restored the Custom following camera. A far-owner toy interruption loop was also reproduced and fixed by requiring all toy-path waypoints to be within20studs, below the unchanged22stud leash; no teleport or larger leash was added.

## Phone and two-client controls

Landscape iPhone17Pro emulation at749×381, Medium text: E proximity entry, native charm click saved OFF, native Back, Deck and Lounge controls worked. Both focus controls retain44px hit areas. The handheld return restored Custom camera/FOV65 and its prior orbit. The saved appearance remained OFF. These are emulator controls, not a physical phone or sustained touch-rub run.

Two newly launched real Studio clients, Player1/-1 and Player2/-2, ran the actual source from Egg Drop96451847774961. Each earned the guaranteed starter through two pointer drops, clicked Meet and Back. A45-second read-only observation recorded90 snapshots with follow/investigate/rest/shove/settle/greet. Shared greeting56 reserved both owners with matching action and opposing yaw; both wallet/revision pairs stayed6/3. A visitor saw the other avatar holding a physical PocketDeck while its pet rested nearby. Native charm OFF was published only after Saved and reached the observer's actor/model. Native Alt+F4 closed the owner client; the survivor had only its own actor and model and continued solo play. This is real local two-client evidence, not injected peer snapshots; it is still not live public-server or network-latency evidence.

Console output for both clients/server contained only the known optional EditableImage and external203785492 asset warnings. The stale prior Egg Drop test session was ended before the fresh two-client run; the collector project was untouched.

## Performance and remaining gates

Desktop1626×994, Medium preference, fixed hub camera/FOV65/ClockTime16.31: original p95 **17.65/17.78/17.71ms**, candidate **17.87/17.90/17.70ms**,180 warm samples per run, three runs. This is a short local Studio comparison. The2951-node/1618-part counts in those JSONs describe the static lounge model, excluding the separately parented pet/toy/avatar. The candidate has one GardenBall and one20-descendant Zivvi model; measure allocation/observers separately.

The final two-species production factory day and clock23 captures passed Astra's asset review. They are controlled pose/lighting fixtures, not two owned pets; the clock23 capture does not apply the full live Hollow lighting curve. Face silhouettes remain legible, with body colors tending olive/gray at night. Local warm fill/material refinement remains a follow-up.

## Final close-up and release gate

The original conservative aggregate envelope undershot body size on the phone. The final new-rig path captures17 bounded synchronous focused poses, restores live state and caches at most two Dot variants per visual. It fits per-piece swept bounds including the visible Dot, but targets the body separately. Native tests caught two oversized curious poses at initial neutral targets.60/.59. Final production.58 keeps all24 tested neutral/curious/affectionate measurements between.58 and.646; the strict55–65% assertions were not relaxed. Portrait and extremely short views can honestly report a frustum-limited smaller body. Legacy rigs retain the existing conservative path.

Final actual welcome used one native A click and two solver-assisted pointer drops, then the full hatch and native Meet without resizing. Final first desktop plan7.49ms, cached phone reframe2.26ms,128 swept points; OFF Dot variant120points. Accepted stage remains6.135studs. These are local Studio planning times, not phone CPU timings or frame-time benchmarks.

Astra approved final actual desktop/phone rasters: open curious eyes, affectionate contact, and curious eyes restored on release, with complete feet and Dot and reachable controls. The final13.5-second actual E hold in phone emulation awarded0 in that run; no RNG was forced. Earlier26-second actual care saved two+1 receipts. Final native Back→E→Back restored Custom camera/FOV65 with max component error0. Native OFF charm saved and reframed without moving the accepted stage.

After one warmup,20 actual OpenHandheld→Lounge round trips retained3307 Workspace descendants,4628 PlayerGui descendants, one pet, wallet6/revision3 and the Custom camera. This proves stable measured instance counts, not absence of all Lua heap growth. Final console contained only the known optional EditableImage and external203785492 warnings. Final95 sources matched/compiled; all33 Edit mesh resources validated with zero repair attempts. Rojo build and scoped diff checks passed. Astra raster review and independent Sol code/hash review both gave GO. No temporary QA models/scripts remain in Edit.

Stars, new egg pools, the remaining two new pets and the broader garden redesign follow this foundation. Physical-phone comfort/performance, real controllers, live-server latency, eight-player budgets, long-session memory and real private-client save/rejoin still need testing. Save/rejoin/failure cases above use isolated persistence adapters; two local Studio clients are not live public multiplayer.
