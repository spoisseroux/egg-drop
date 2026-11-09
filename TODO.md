# Egg Drop — remaining work

Updated November 9, 2026. Published private builds are recorded in [PLAY-BUILD.md](PLAY-BUILD.md). Verified source and local Studio evidence do not establish live save or physical-device coverage.

## Completed item-egg and Aero build

Private v274 / bb8c60b contains the accepted [item-egg scope](ITEM-EGGS-AND-AERO.md): unified Companion / Hue shop, saved stacked hue/reset items, independent five-dose channels, migration of old purchases, per-pet customization, seven-ID color support, planted motion, faster aiming and themed supply balls.

## Current palette and roster — private v316

- [x] White Main / light-grey Secondary, unchanged hue anchors and independently saved doses. New hatches offer four pets; already-owned Vezzi, Kiprik and Nolli remain usable. Retained rare progress freezes safely. [Scope and148-case verification](NEUTRAL-ROSTER.md).
- [ ] Finish the separate glossy/luminous night-material pass. Candidate source is safely parked in stash7f72106e5d3a9444c6ae4b03be975f637e2c0505; [resume notes](PET-MATERIAL-PASS.md). v316 includes none of that experiment.
- [x] Rechecked actual welcome→Meet→E petting→Back with the virtual controller disconnected. Ordinary native input works; loading and affection lifetime regressions also pass in the care slice.
- [ ] New replacement designs for the three retired pets require visual approval; no replacements were silently substituted.

## Approved pet-care expansion — work in progress, November 9

The user authorized building the [Astra proposal](PET-CARE-EXPANSION.md) within the [architecture constraints](PET-CARE-ARCHITECTURE.md), starting with loading/feedback, then carry/machine/garden. The first reviewed care slice is private v326 Published / 3c6b61b, verified in native Version History. Carry and machine are planned in CARE-CARRY-MACHINE.md. Remaining unchecked phases are not implemented. Illustrative prices, chances, XP curves and dimensions still require play tuning.

- [x] Complete-model loading/fallback before authored mesh reveal, bounded shared asset queue and owner/hatch priority; reviewed whole-rig handoff and stale-lifetime cases. [Care verification](CARE-LOADING-FEEDBACK.md).
- [x] Exact conditional color swatches on the existing four hue rows; live muted Customize portrait; explicit one-channel Reset Main/Secondary confirmation. Actual Largest phone controls preserve a full first row.
- [ ] Add dark-red/Garnet and black/Ink with historical data and receipts preserved.
- [x] Tier-based device-art merge response, bounded existing effects and88%-opacity motifs over the opaque theme base. Earned low-tier and labeled injected-clear native recordings pass review.
- [x] Carry from petting, supported set-down, one physical care-machine bay and confirmed owned-pet switching; fast shortcuts retained. Astra accepted actual earned R15 motion and Largest phone UI; [verification](artifacts/carry-machine-2026-11-09/VERIFY.md) distinguishes isolated switch/contention tests from actual controls. Private publication is recorded in PLAY-BUILD.md.
- [ ] Independent Skin FX gradients/finishes, original UV/material work and readable dark/night faces; restore the parked gloss work under review.
- [ ] Feature Egg with horns/tail/wings, rarities, stored items and separate five-stage earned/visible feature sizes per pet.
- [ ] Per-pet Movement/Swim XP levels, Stat Egg, meaningful practice, crawl/first-step and beginner/competent swimming animations with safe shores.
- [ ] Original textured basin, terrace, animated pond/waterfall and purposeful cave entrance inspired by the supplied garden's proportions. No Sonic mesh or textures imported into the game.
- [x] Bounded room coo scheduler and Astra-authored relative poses with mute/reduced/lifecycle guards. Existing original family voices verified in accelerated Studio playback; normal listening frequency unverified after160s with no cue.
- [ ] Upload/verify the four newly authored coo drafts if selected, and build saved-item sniff/bite/growth/training responses as the corresponding item systems ship.
- [ ] Build one real activity behind the cave entrance before enabling its portal. Further stats, prestige resets and minigames need a purpose and a later bounded scope.

## Completed overnight builds — historical v309

The newer **Spring Meadow continuation is private v309 Published / pushed runtime b71c702**. [Proof](artifacts/spring-meadow-2026-11-09/private-published-v309-b71c702.png) · [Verification](artifacts/spring-meadow-2026-11-09/VERIFY.md) · [Gallery](artifacts/spring-meadow-2026-11-09/GALLERY.md).

- [x] Genuinely larger garden:160 ×176,37.5% more floor area, dry loop beyond the former south wall, volumetric spring landmark and two separate resting spaces. Two local owners and earned pets traversed/gathered/returned; Astra source/render/movement/phone gates pass. Existing hub and economy retained.
- [x] Preserve below the separately verified v297 baby, expression, free charm, shared-return and hatch work. All bounded overnight original TODO slices are complete; verification/future scope remains explicit.

The bounded [garden and baby scope](OVERNIGHT-GARDEN-PETS.md) is implemented, independently reviewed and published as **private v297 / 2e9da43**. Runtime is pushed; refreshed native Version History verifies **Aero babies and shared garden - 2e9da43**. [Publication proof](artifacts/aero-garden-2026-11-09/private-published-v297-2e9da43.png) · [Verification](artifacts/aero-garden-2026-11-09/VERIFY.md) · [Gallery](artifacts/aero-garden-2026-11-09/GALLERY.md) · [Native test index](artifacts/aero-garden-2026-11-09/TEST-INDEX.md).

- [x] Purposeful lawn, usable creek crossing, curved rest nook, clearer routes and bounded moving scenery. At v297 the main floor was 160 × 128 studs; actual avatars and pets crossed both ways and the pet rested in the nook. The v309 expansion above supersedes that footprint.
- [x] Five original replacement babies: Tikket, Nuum, Vezzi, Kiprik and Nolli, with authored expressions, portraits, fallback forms and protected pigment roles. All seven saved identities and existing ownership remain stable; Zivvi and Ovelle retain their models.
- [x] Free optional Dot / Ring / Pebble shapes with saved visibility, unknown-shape preservation, exact retries and old-client compatibility. Published source enables selections with `SelectionsEnabled=true` and `PetCharmVersion=2`; pre/post-publication censuses found no older gameplay writer.
- [x] One shared two-pet return with ordinary Start / Join, exclusive generation-bound reservations, bounded approaches and interruption/retry guards. Final actual two-client film has visual GO; no rewards or currency were added.
- [x] Saturated hatch presentation, bounded ambience, focus scenery coverage and short-landscape phone-emulator review at Largest text.
- [x] Native source equality / compile / Rojo gates; 172 server cases across 19 suites and 292 client cases across 36 suites, counted without duplicate reruns.
- [x] Two original local synth music drafts and technical loop/loudness validation. Subjective listening and any future audio upload are separate; the currently liked in-game default is unchanged.

## Follow-up verification

- [x] Record private v309 / pushed runtime b71c702 and refreshed native Version History proof. The browser connection failed on its new census refresh; the last census is v297's, with no claim of live v309 save/rejoin.
- [x] Record private v297 / pushed runtime 2e9da43, refreshed Version History proof and the 6:11 AM post-publication census (one Team Create edit server, no gameplay writer).
- [ ] Test physical-phone touch, sustained performance and controls; Studio landscape emulation is the current coverage.
- [ ] Repeat actual two-client carry, visitor observation and bay contention after updating Studio: the November9 local-client launcher refused to start because Studio was out of date. Actual R6 controls also remain unverified; synthetic joint/geometry coverage is recorded separately.
- [ ] Verify live save/rejoin, including shape/visibility pairs and hue inventory. The browser Play attempt reached Download Roblox while the standalone player was signed out; no live VM/profile test ran. Sign in to the standalone player before retrying. Isolated Studio receipts are not live persistence proof.
- [ ] Run longer human play and service-scale multiplayer sessions; assess earning pace, repeated companion outcomes, time to a chosen hue and whether shared activities remain enjoyable.
- [ ] Revisit flatter nighttime shading and weak individual Vezzi teeth if further art tuning is authorized; the proposed .60 brightness trial target was not met.

## Future scope — separate design and review

- [ ] Additional garden spaces and social activities/minigames beyond the completed shared return and Spring Meadow. The original larger-footprint requirement is now implemented; broader expansion needs a new bounded design/review.
- [ ] Clothing eggs and battling. Stat Eggs are now part of the proposal above, not yet built. Nursery remains deferred.

No paid luck, daily play caps, new currency or public release is authorized by this backlog.
