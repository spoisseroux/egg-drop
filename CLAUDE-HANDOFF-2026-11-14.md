# Claude handoff — November 14, 2026

## Spencer's latest instructions come first

Spencer is stopping Codex's work and handing this back to Claude. **Read the new QA pass document he attaches with this handoff before building.** That attachment supersedes stale checklists and earlier acceptance assumptions. The earlier QA document was `C:\Users\skunk\Documents\obsidian-spencer\roblox qa pass nov 14.md`; do not assume it is the new attachment.

Spencer explicitly asked me to tell you:

> Codex did a poor job integrating the hatch animation. The animation themes are okay, but the UI is very lackluster. Pocket Deck sizing still needs to be fixed.

Treat those as open work and direct user feedback. **The hatch UI is not accepted or polished.** Our code tests and Astra's bounded visual reviews do not override Spencer's judgment. I spent too long on the pathway's collision pipeline while these visible integration problems remained. Do not repeat that prioritization.

**No new experience publish or server restart.** The phone QA build is still private **v685**. Current follow-ups are unpublished. Wait for Spencer's direction and attached QA before deciding the next release.

## Where things are

- Repository: `C:\Users\skunk\Documents\Development\egg-drop`.
- Authorized branch: `feat/egg-drop-arcade-polish`; latest pushed implementation commit **3eb4be4** (handoff documentation may have a later commit).
- Place **96451847774961**, universe **10774758591**. Never touch the other Suica project/place.
- Studio MCP ID: `382a9271-f8bd-4f5d-b4c4-54405899367e`; currently **Edit**, Play stopped.
- I removed my six temporary world upload/collision candidate models from Studio before handing off. Canonical `ServerStorage.WorldAssets` remains intact. Capture helpers were Play-only and were removed by Stop.
- **Uncommitted world pipeline/staging work remains in the working tree. Preserve it.** It is not a finished native world update. `src` and canonical `assets/world` have no pending world promotion; the changed Python pipeline and new `world_path_*` helpers are not yet committed.
- Read `TODO.md`, `PLAY-BUILD.md`, then the evidence linked below. The old `CODEX-HANDOFF-2026-11-14.md` contains historical instructions; its original wait-for-v634 instruction has already been superseded.

## What was implemented and published today in private v685

The earlier consolidated checkpoint is [UNPUBLISHED-RESULT.md](artifacts/qa-2026-11-14-v634/UNPUBLISHED-RESULT.md). Despite that historical filename, its release banner correctly says these changes subsequently shipped in private v685.

1. **World overlap repair:** removed the remaining 196 reported overlap pairs; preserved palette/UVs and bounded geometry. Cleared five vegetation objects for the second park. Fixed native collision portability: bare generated XML lost physics, so the mounted world now uses a native `.rbxm` plus a stale-checkpoint guard. Fresh full-build verification matched all170 physical payloads and20,920 rays across the repaired solids.
2. **Garden systems:** second independent park, shared fetch, activity reservations and one completion owner; Play date analytics recovery. Qualified losing rounds get+1 Star. Bug reports use deterministic shards with immutable retry/deduplication behavior.
3. **UI and onboarding changes:** results retain Pocket Deck hardware/LCD, four-way controls and generic Hatch eggs route; wallet/notification/focus/preview-loading/help/price changes. **Implementation does not mean Spencer accepted the presentation. Pocket Deck sizing and hatch UI polish remain open.**
4. **Reusable native hatches:** one scene/clock; centered forward scale/fade emergence; shells stay on their correct sides and shrink/fade away quickly. Bear expressions, hop and wave; reusable Toy/Hue/Material/Feature adapters. Bear4.4s, items3.1s; receipts unlock at2.65/2.2s. Reduced Motion uses a short fade. New timed hatch SFX load at their intended durations.
5. **Jelly finish:** lucky Material Egg outcome, not an earned special unlock. Pool4:16 Stars, initial Gloss45% / Jelly10% / Matte45%, no duplicates with disclosed remaining odds. Restricted/unknown policy uses disclosed fixed order. Historical pools, reservations, receipts and savev11 remain compatible. Actual production Jelly body transparency is15%; face/accessories remain opaque. Two water bases were made opaque to address sorting through Jelly.
6. **Music:** rejected the earlier full104BPM approach; produced the current72-second v3 garden/deck loops using documented CC0 squeak/bubble sources. Spencer wants more melody and softer, more transformed samples, but **explicitly chose current sparse v3 for phone QA**. Garden73327108010209; Deck108432047352639. A separate27-second v4 melodic audition exists locally and is not mapped/uploaded.
7. **First Toy race:** fixed callback ordering so automatic receipt close preserves only the exact pending equip flight; Saved proof still controls handoff. Real Give produced one visible toy play2.68s later. Explicit navigation/focus/movement cancels normally.
8. **Moonpond:** added/shown the background in the actual handheld context. The earlier115px two-item image was an internal sizing diagnostic overlay, not a proposed game screen; Spencer reasonably found that confusing. Actual native previews were subsequently provided.

Private release proof and real pet/item/Jelly videos: [native-review/README.md](artifacts/qa-2026-11-14-v634/native-review/README.md). v685 runtime reference70e0440; source checkpoint00287c5 and release documentation57b7402. Translations synced **59 add/update,4 delete**,591 entries. Visibility PRIVATE; mobile/tablet enabled. Actual server capacity is still50; intended public target12 is unresolved. `TestFreshSaves=true`, `Park=true`, `DayNight=false` locked dusk, `SecondPet=false`, `Features=false`. Public release remains held; fresh-save flag must be disabled before launch.

Earlier verification:56 server/36 client suites passed across full initial runs and targeted fixes/reruns, not one flawless single run. Physical-device, genuine two-account, service/rejoin and Creator Analytics acceptance are still human/live QA work.

## Later unpublished follow-ups, committed and pushed

### acfdfd0 — disclosure, pigment jars, true finish sample, initial rarity sound

- Hide the rolled reward name until the existing item receipt beat. Toy/Hue/Material headings say **“A little surprise”** beforehand; identity/accessibility follow the exact result ID and presentation state. Pre-purchase odds/fixed-next disclosures remain truthful.
- Remove fruit/leaf shapes from the four jars, replacing them with pigment. Visible names are Rose/Tide/Citrus/Iris jar; saved IDs are unchanged.
- Fix the misleading Jelly sample. It had cloned `Bear__CharmDot`, which is a Snowflake shape, despite being called a sphere. **That was a preview bug, not a charm grant.** It now uses a real round UV-mapped Egg Core mesh97136732817875 with verified production finish profiles.
- Each preview owns its geometry/cache lifetime. A shared six-face garden Sky inside the viewport makes Gloss visibly shiny and Matte diffuse; same tint/camera/light, no painted fake per-finish highlights. Jelly is the actual verified15% transparent material. Round fallback remains explicitly unverified while loading.
- Added fixed authored rarity policy; Jelly Rare, Gloss/Matte Common, canonical pet/Feature tiers, unknown Toy/Hue Neutral. Never infer rarity from remaining odds, price or ownership.

Evidence: [NATIVE-UI-RESULTS.md](artifacts/qa-followup-v685-2026-11-14/NATIVE-UI-RESULTS.md). Actual time-stepped Roblox movies, disclosure frames, four jars, finish comparisons and profile readbacks are included. Synthetic receipts do not perform purchases. Movie soundtracks are matched PCM auditions, not recorded Studio output. Fresh source100 client cases passed;303 runtime files compiled and Rojo built. **These checks do not establish UI polish or correct Pocket Deck sizing.**

### 3eb4be4 — audible rarity revision2

Spencer listened to the first Common/Rare comparison and said **“The rare and common hatches are the same sound.”** He was right about the practical result: the first accent was nearly20dB below the tail. A peak-only numerical pass had not established audibility.

Astra revised the answer: Rare gets two later, stronger notes rising a fifth, at receipt+.20/.42s, gains.35/.32, pitches−2/+5 semitones, ending by+.60s. Uncommon gets one note; Common and opening/body stay unchanged. Reuses existing goal_tick103058048084589; no new sound upload or music change.

**New comparison was shown, but Spencer has not given listening approval:** [Common → pause → Rare, revision2](artifacts/qa-followup-v685-2026-11-14/audio/revision-2-audible/material-common-then-rare-comparison-revision-2.mp3). Old rejected files are preserved. First-note contrast+5.37dB over the tail; full peak−4.77dBTP. Independent code/PCM review and fresh native policy5/owner3 cases pass. Real native Jelly playback accepted both revised notes at2.4005/2.6338; Gloss played only the original body. [Revision details](artifacts/qa-followup-v685-2026-11-14/AUDIO-REVISION-2.md).

Updated Jelly movie with revision2 matched soundtrack: [material-hatch-audible-revision-2.mp4](artifacts/qa-followup-v685-2026-11-14/native/material-hatch-audible-revision-2.mp4).

The pet entrance currently has the newer egg opening/hop/wave. **It does not include the old Smash-style silhouette/name-slam intro.** Spencer asked whether it did; that question was not authorization to silently redesign it.

Local localization export is now592 strings. Cloud table is still the v685 synced state; sync translations before any future authorized publish.

## Incomplete path detour — preserve, do not promote blindly

Spencer asked that the path go around the second/grove park. The source geometry is complete and reviewed, but **native collision is not approved**. This is what consumed too much of the session.

- Source detour preserves the park and grass, adds a3.4-stud entrance apron through the4-stud east gate, and clears closed kerb/posts by over2 studs. Astra approved source curve/apron renders. Only the dirt visual and ground collision tiles25/26 change;98 other visuals and66 other tiles are preserved.
- Source pipeline/rebuild contract and42 tests pass. Optional reroute descriptor is **absent from canonical assets**, so hooks retain legacy behavior. Staged descriptor, source geometry, hashes and forward reproduction proofs exist. Native guard remains valid for the old canonical325417-byte pack, SHA98a95633da48bdfb54af5a16311502a03f7f711d02814a4be83417e870890003.
- Exact three-resource upload was approved: Model **140496177780523**, operation **c69408af-128a-4da6-8a72-510442c35a14**. New mesh IDs: dirt99700887546147; tile25 **102699373356235**; tile26 **119461310282666**. No new textures. Do not re-upload the same geometry needlessly.
- [UPLOAD-AND-NATIVE-QA.md](artifacts/qa-followup-v685-2026-11-14/world-path/UPLOAD-AND-NATIVE-QA.md) describes everything. Actual receipt: `world-path/upload/actual-readback.json`. `world_path_packet.py --readback ABSOLUTE_JSON` already validated it against trusted previous IDs and produced `runtime-candidate/` XML/Lua/confirmed pending in staging only.
- Initial native PreciseConvexDecomposition was **bad despite correct source geometry**:3,671 rays, no outright missing hit, but up to1.453stud outside-mask height difference and about.148stud old-road ghosting. Old native data also has a separate1.416stud deep deviation. Do not turn those into a false pass or loosen to the road crown bound.
- Tunable diagnostics improved this substantially. Fresh factory request near1, followed by ApplyMesh, actually reported Tunable precision **.972549 for25 / .984314 for26**; actual readbacks matter more than assumptions. Full3,671-ray maximum new-vs-source error **.050995stud**, outside old/new Tunable difference **.051248**, inside expected-delta error **.019079**. Those are **diagnostic results, not a passed strict gate**. An in-memory serialize/deserialize preserved fidelity/precision and the five sampled ray heights.
- Files: `native-initial-precise-rays.json`, `native-tunable-diagnostic.json`, `native-probes.json`, `native-baseline-properties.json` under the path folder. Baseline properties are complete170-part JSON. All167 protected readable part properties matched before tuning; unaffected physical buffers still require final native export verification.
- **No canonical world imports/native binary/proof/descriptor were promoted. No full native avatar traverse, park capture acceptance, serialized full-build parity or final native world tests were completed for this detour.** All temporary Studio models were removed at handoff. Reconstruct from staged assets/readbacks if continuing. The approved source alone is not permission to mount bare XML or publish.

If continuing later, first resolve the native accuracy/acceptance plan, then exact native export, protected-buffer comparison, actual route/gate walk and final park views. Any fidelity/precision source policy change needs explicit reviewed metadata/descriptor updates and serialized reload proof. [Native diagnostic review](artifacts/qa-followup-v685-2026-11-14/WORLD-PATH-NATIVE-ACCURACY-REVIEW.md).

## Deferred decisions and protected files

- **Blip/alien parked.** Spencer hates the alien and the redesigns too. D/E/F and earlier concepts are rejected; consider a different pet. Do not import/refit/enable it; `SecondPet=false`.
- **Names Egg is scope only:** quirky mix-and-match title/racehorse-style names, up to two pieces, inspired by Animal Crossing titles. Not an implemented name system. [Scope](artifacts/pet-social-scope-2026-11-14/NAMES-EGG-SCOPE.md).
- **Other people's pets, v1 scope only:** read-only inspect plus owner-controlled cosmetic Hello; no implementation claim. [Scope](artifacts/pet-social-scope-2026-11-14/VISITOR-PET-SCOPE.md).
- Preserve unrelated dirty `assets/garden-babies/garden-babies.blend`, `mouthTex.png`, older scope/raw images, old Blip files and `.codex/`. The old `artifacts/localization/hardcoded-strings.csv` was accidentally regenerated earlier without an exact backup; disclosed and excluded from commits. Later exports used a separate review-file path.
- Source workflow in `AGENTS.md` still applies: Astra/Fable owns creative direction, Sol6.1 High/Opus implementation and independent reviews; coordinator owns actual Studio/evidence/releases. Main client has219 top-level locals; don't expand that budget. Savev11/history IDs remain compatible. Never delete watched asset files to clear pending state; Rojo can crash.

## Suggested first action for Claude

Read Spencer's new attached QA pass and this handoff. Reconcile priorities with his actual screenshots/device observations. Start with **hatch UI integration and Pocket Deck sizing**, not another long invisible pipeline detour. Keep v685 stable until he asks for a replacement private build, show actual integrated results, and distinguish implementation/tests from his approval.
