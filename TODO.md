# Egg Drop — remaining work

Updated November 11, 2026. Published private builds are recorded in [PLAY-BUILD.md](PLAY-BUILD.md). Verified source and local Studio evidence do not establish live save or physical-device coverage.

## Now working on

Keep this list current: add an item when work starts, move it to done when it lands.

- **Overnight systems run, 2026-11-11 — done:** store backend `0d5798e`, Get Stars shop + analytics `3b82189`. Not published. Next systems step needs Spencer's product/pass ids.
- **Spencer:** Blender template + test cube, then horns/claws/wings ([ART-HANDOFF.md](ART-HANDOFF.md)).

## v1 public launch

Decided 2026-11-11 by Spencer. These supersede the "no public release / no paid luck" line at the end of this file for v1.

- Quiet soft public launch, then iterate on retention data.
- Roster: the four new babies only (Zivvi, Ovelle, Nuum, Tikket). Legacy Vezzi/Kiprik/Nolli and rare editions leave the hatch pool and shop.
- Private-test saves are wiped at launch with a fresh DataStore name. No legacy migration.
- Rounds stay unlimited. Monetization: Stars boosts (2× Stars pass, per-round bonus), game passes and Robux→Stars packs.
- All ages, default chat, no trading.
- Agents: in Claude Code, Fable for art/UI and Opus for systems. In Codex, Astra/Sol per AGENTS.md.

**Paid random items (applies once Stars are sold for Robux).** Every egg becomes a paid random item under [Roblox's policy](https://devforum.roblox.com/t/clarifying-requirements-for-paid-random-items/4654622):
- Odds must be shown as percentages for every outcome before purchase and must sum to 100%.
- **Every outcome must give something.** Today a duplicate companion grants nothing, so it needs compensation, for example a Stars refund.
- Players for whom `PolicyService:GetPolicyInfoForPlayerAsync` reports `ArePaidRandomItemsRestricted` must not be able to buy Stars packs. This currently covers UK under-18s, with reports of Brazil restrictions too.
- Disclose it in the maturity questionnaire.

**Launch prices** (Claude's pick, 2026-11-11; all in one config, retune after the balance pass). Earning baseline: a won round pays 6–8 Stars and a Mixed companion egg costs 18, so one egg is about 3 wins.

| Product | Type | Price | Gives |
|---|---|---:|---|
| Starter pack | Developer product, once per player | 49 R$ | 40 Stars + Supporter charm shape |
| Handful of Stars | Developer product | 39 R$ | 20 Stars |
| Pouch of Stars | Developer product | 99 R$ | 60 Stars |
| Jar of Stars | Developer product | 199 R$ | 140 Stars |
| Chest of Stars | Developer product | 499 R$ | 400 Stars |
| 2× Stars | Game pass | 299 R$ | Doubles Stars from rounds and contracts (not the daily gift or refunds) |
| Supporter | Game pass | 99 R$ | +1 Star per finished round, Supporter deck shell + charm |
| Duplicate companion | — | — | Refunds 50% of that egg's Stars price |

### 1. Systems
- [x] Save hardening: fresh `EggDropLaunchV1` store and DataStore request-budget waits (`0d5798e`). The existing hatching lease (90 s, renewed every 20 s) already acts as the economy session lock, with re-acquire on Locked/Unavailable, retries and a close drain, so no rewrite was needed.
- [x] Trim to four babies: only Zivvi/Ovelle/Tikket/Nuum were already active and the rare pool was empty. Meadow odds are now whole percentages 40/28/22/10 (`0d5798e`). With the save wipe nobody owns retired pets.
- [x] Duplicate companion refunds 50% of the egg price (9 Stars on Meadow) (`0d5798e`).
- [x] Monetization backend (`0d5798e`): `StoreCatalog` config, `PurchaseState` ledger (each purchase id grants once across servers), `StoreService` (server-initiated prompts, ProcessReceipt, pass ownership, PolicyService gate that fails closed). Passes boost round rewards inside the transaction.
- [x] Dashboard products and passes created 2026-11-11 (Managed Pricing off, fixed prices) and wired into `StoreCatalog.lua`. Starter 3730431023, Handful 3730431114, Pouch 3730431153, Jar 3730431202, Chest 3730431229; passes 2× Stars 2078960411, Supporter 2078804439. Studio: all 7 show available and the server prompt fires. Passes use Roblox's default image until we make icons.
- [ ] Decide on Roblox Managed Pricing (regional pricing plus automatic price tests). Turning it on means accepting its terms on the dashboard.
- [ ] Supporter cosmetics (deck shell + charm) promised by the Supporter pass and starter pack need art; currently Stars-only.
- [x] Get Stars shop (Fable), opened from the egg shop header; packs hidden when Roblox restricts paid random items; "Coming soon" until ids exist (`3b82189`). Not yet checked: Largest text, gamepad focus, the real in-game path, real purchases.
- [x] Analytics (`3b82189`): Stars sources/sinks, round won/lost, store opens, pass purchases. D1/D7 retention comes from the Creator Dashboard. Only fires on published servers, so it is unverified until a live session.
- [x] Retired surfaces: the Family mastery menu was already removed, and the save wipe clears retired pets. Nothing else to hide.
- [ ] `scripts/PetAward.spec.lua` fails on a stale `version == 4` assert (pre-existing, unrelated to v1 work).

### 2. Garden environment
The current garden is code-built from primitive Parts (`LoungeArt`, `LoungeGardenArt`, `LoungeSpringArt`) on a flat 160 × 176 lawn. Reference: [top](artifacts/garden-reference-2026-11-11/reference-layout-top.png) · [perspective](artifacts/garden-reference-2026-11-11/reference-layout-perspective.png). Target proportions and the kit list are in ART-HANDOFF.md section 7.
- [x] Greybox built in Studio Edit as `Workspace.GardenGreybox` at X=+1000, from `scripts/GardenGreybox.lua` (rebuildable). Captures in `artifacts/garden-greybox-2026-11-11/`. Not in the Rojo tree, so it is only in this Studio session until the place is saved; remove it before any publish.
- [ ] (spec) Greybox in Studio: about 230 × 180 stud crescent floor, roughly 60-stud cliff ring on north/east with cave gap, west pond about 35 × 65 with island, waterfall, terraces/pillar steps, creek crossing, landmark tree, hub stations. Original layout; no Sega mesh or textures.
- [x] Walk test with an R15 avatar (`artifacts/garden-greybox-2026-11-11/WALK.md`): ramps, terraces and creek pass; pillars were too hard and are now 10-stud tops with 3.5-stud rises.
- [ ] Spencer walks the greybox himself and approves or changes the layout. Phone camera framing not yet checked.
- [ ] Spencer models the final kit in Blender from the approved greybox.
- [ ] Load the environment as authored assets instead of code-built parts; keep day/night lighting.
- [ ] Rebuild garden walkability and pet path data (`GardenLayout`, `GardenWalkability`, `GardenPathPlanner`) for the new ground.
- [ ] Original skybox, sea plane and phone performance budget.

### 3. 3D assets (Spencer models, Claude integrates; see ART-HANDOFF.md)
- [ ] Blender template, export preset, test cube and test cone verified in Studio.
- [ ] Horns, claws, wings: shared set, separate L/R meshes, stage-5 size, base/tip split.
- [ ] Hand-tweak the four babies, keeping the part names and split.
- [ ] Toys: Ball, Bone, Sparkler.
- [ ] Stations and props: care machine, hatch tree, workbench, journal stand, lanterns, bench, rocks, bushes.
- [ ] Claude: import, pivot/collision/material setup, code wiring, before/after captures.

### 4. Live verification (after systems and the garden are in)
- [ ] Physical iPhone and Android: touch, frame rate, heat, text size, first session to first hatch.
- [ ] Live save/rejoin on the published place (needs signed-in standalone player).
- [ ] Live purchase test of each pass and pack.
- [ ] Two-player garden, carry and bay contention (needs a second account or tester).
- [ ] 6–8 player load test.

### 5. Release
- [ ] Human balance pass on Star earning against egg and pack prices; the three newer field goals with real players.
- [ ] Confirm all 17 SFX, Music and Purr load in the published place; decide on coo and garden music drafts.
- [ ] Icon, thumbnails, description, maturity questionnaire (including paid random items).
- [ ] Soft launch.

### Deferred past v1
Metal and gradient materials, Movement/Swim XP and Stat Egg, cave activity, retired-pet replacements, Ink on Main, clothing eggs, battling, additional garden spaces.

## Round feedback and clear rewards — private v397 Published

- [x] Accepted Drop kicks the entire handheld; merge priority, hidden/duplicate/reduced suppression and pointer mapping remain correct.
- [x] Current-run final balls bounce with bounded confetti/seed art; exact payout and live controls retain authority. Actual two-goal24-drop win:1010 points, chain9,12 Stars =6 Quest +6 Daily; one art owner,12 confetti, quiet settlement, fresh replay.
- [x] Compact recap shows one payout breakdown and one marked goal list; remove duplicate hint/cards/kicker and scenario/dynamics jargon from results.
- [x] Three measured egg offers per row with accessible narrow fallback; actual desktop/phone-emulator controls reach both rows.
- [x] Lit Matte/Gloss sample and compact award receipt; fix2px empty scroll. Complementary cold-load shell halves and120ms shell-only opening pass15 native phase captures across all five egg families.
- [x] Every hue0 notch white on both channels; retain saved-dose highlight, original stages1–5 and one-channel confirmed Reset semantics. No stored colours changed.
- [x]250 unique client checks/26 suites,40 server cases/3 suites,171 source matches/compiles, cold Rojo, independent source review and Astra render review. Runtime b733167 pushed, private v397 Published verified in refreshed native Version History. Exact artifacts and limitations: [verification](artifacts/round-juice-2026-11-09/VERIFY.md), [gallery](artifacts/round-juice-2026-11-09/GALLERY.md).
- [ ] Remaining verification: physical phone, live rejoin, current two-owner toys/features observation, human objective balance and actual overflow walkthrough. Garnet/Ink trial work below remains design-only until a compatible versioned catalog is implemented.

## Player feedback after v358 — private v370 Published

### Device, hatching and personal play — private v389 Published

- [x] Move the entire device, screen, labels and controls together on merges; keep simulation and pointer mapping correct and Reduced Motion quiet.
- [x] Horizontal halo torus and matching top/bottom fallback; reset ended board render caches under cover before a fresh game appears, preserve suspended games.
- [x] Shared usable scrolling width, no right-edge cuts, four filled Pet columns, larger measured body/action text, no decorative button highlight lines.
- [x] Remove Pocket Menu footer and Companions/Deck Style shortcuts; customization and pet swap at cradle, styling at workbench.
- [x] Menu egg glints and more climactic original all-egg cracking with exact result/audio ownership, interruption/reopen/reduced safeguards.
- [x] Fruit-use preview feeding/eating animation only after the matching confirmed application.
- [x] Remove the old world ball/shared-return activity and its visible props/prompts; keep other care leases intact.
- [x] Toy Egg, permanent toy unlocks/per-pet selection and observer-visible idle play (Sparkler, Ball, Bone), separate from removed world activity.
- [x] Feature Egg, stored Horn/Claw/Wing items, exact one-item/per-pet next-notch application, earned maximum and selected visible sizes0–5, original models/animation.
- [x] Final phone first-row labels, clean-source audit169/169, reviewed runtime13afc44 committed/pushed, privatev389 Published verified in refreshed Version History. [Exact evidence and limits](artifacts/device-hatch-play-2026-11-09/VERIFY.md).

Asset research: [Kenney UI Pack](https://kenney.nl/assets/ui-pack) (CC0) and [Quaternius Ultimate Stylized Nature](https://quaternius.com/packs/ultimatestylizednature.html) (CC0) are optional sources for selected supporting assets. No third-party pack imported in this pass yet; original pets/device stay coherent. Packs do not replace layout correctness.

Runtime97c64d0 is pushed; privatev370 Published is verified in refreshed native Version History. The current pass follows [Astra's plan](FOLLOWUP-PLAYFUL-CARE.md). Native evidence and release state are recorded in [verification](artifacts/playful-care-2026-11-09/VERIFY.md); final publication is recorded in PLAY-BUILD.md.

- [x] Coalesced immediate exact charm-save flushing, without the12-second periodic delay. Actual isolated Studio Ring change: Applied65ms / durable Saved117ms; delayed/fenced transactions also tested. This is not live-service latency evidence.
- [x] Retire fruit art on confirmation/result exit and Pet/Hue/Charm transitions, including stale and repeated paths. Short item decisions omit routine Saved / Review use.
- [x] Hue0–5, checked saved notch including0. Any notch offers one next relevant dose or no-stock/max explanation. Zero is not a reset; Reset remains one explicitly confirmed channel.
- [x] Pet-grid8px top inset, shared solid carry/back arrows,44px controls; playful measured PatrickHand supporting/action type, FredokaOne headings and Mono counters.
- [x] Brighter daytime pet emission with accepted nighttime strengths preserved; native neutral and dyed review. No global lighting change.
- [x] Stronger bounded tier/chain device-art shake; actual24-drop round produced19 merges and9.49px peak movement. Input/aim stays stationary; Reduced Motion gets no translation.
- [x] Exterior backdrop composited once at92% opacity; case, tray and controls stay opaque.
- [x] Original tapered Companion/Hue/Material egg art across shop and hatch, with fallback silhouettes.
- [x]16-earned-Star Material Egg: one permanent remaining Gloss/Matte unlock, initial50/50, then100%, no duplicates/debit when complete. Standard is free; finish selection is reversible per pet. Atomic exact proofs, replay/leases/migration and private/public payloads verified. Actual earned Gloss purchase and selection covered in Studio.
- [x] Materials tab and compact receipt; fixed preview with scrolling choices, Use now/Keep adjacent. Hue receipts show Reset/fruit and both actions together on short landscape at Largest.
- [x] Add Ripple relay, Bank bounce and Mirror marks after the existing three objectives. Each has a spatial goal and short next hint; six-seed production-solver trace replay gives6/6,5/6,5/6 respectively.
- [ ] Complete each new objective through ordinary native controls and tune their difficulty with humans. Solver replay is not native-input completion or fun evidence. Bank pair and Creek crossing have earned24-drop control completions in this pass.
- [ ] Metal: native trial resembled Gloss. Retain historical proof recovery, exclude from new egg pool until a distinct accepted render exists. White/black gradients also need dyed endpoint/UV/compositing proof.
- [ ] Physical-phone touch/performance, live-service rejoin/persistence, real multi-owner carry/bay contention, lowest graphics quality and longer human play remain unverified. See broader backlog below.

## Companion editor, recap and materials — private v358

[Astra's companion editor and recap scope](COMPANION-EDITOR-AND-RECAP.md) is implemented, verified and published as private v358 /runtime4bf7893. Final native tests and Astra actual-control visual review pass; [the candidate notes](COMPANION-EDITOR-AND-RECAP.md#candidate-status--november-9-2026) distinguish isolated fixtures, actual Studio controls and remaining coverage limits.

- [x] Candidate recap with a consistent Stars emblem, deep ink, default-visible scrolling details and no selected-egg progress area. Matching receipt and audio ownership remain intact.
- [x] Candidate Pet / Hue / Charm editor replacing Journal routes, with square live owned-pet cards, fixed preview/channel controls and independently scrolling options. Preserve ownership, legacy colors, inventory and exact item/equip confirmations; keep jar recipient selection distinct from equip.
- [x] Candidate full-width tabs, bare X, no editor wallet/hex values/carry footer, illustrated charm rows and mutually exclusive Charm On / Off controls. Larger text uses measured layout; swatch stage lettering chooses real-sRGB contrast against its actual fill.
- [x] Candidate machine X returns the pet after exact pickup proof; snapshot/result ordering and late equipment are reconciled. Forced cleanup remains separate. Up/down-arrow world carry controls have actual earned Studio evidence.
- [x] Candidate continuous torus preserves the saved Ring ID and has a deliberate two-sided fallback. Native material fixtures compare brighter pet-local emission and stronger charm emission without changing the garden's global lighting.
- [x] Verify separate Charm icon/name/selected-mark rectangles at Largest: exact 233 px rows, all three selected shapes at 568 × 160 and [corrected actual-control capture](artifacts/companion-editor-2026-11-09/actual-largest-phone-charm-final.jpg). The [earned Pet card](artifacts/companion-editor-2026-11-09/actual-medium-phone-pet-final.jpg) includes the complete live pet, name and Active mark in the first view.
- [x] Fresh ordinary final-source wheel verification: Body.Active=true, options list 200→100, zero camera displacement. Final actual machine × confirms Carried. The earlier regression moved the camera 11.7923 studs and remains recorded as failed evidence.
- [x] Final [Medium](artifacts/companion-editor-2026-11-09/client-medium-final.json) and [Largest](artifacts/companion-editor-2026-11-09/client-largest-final.json) client batches each pass 161 cases/20 suites; [server fixtures](artifacts/companion-editor-2026-11-09/server-final.json) pass 145/15. [Astra visual GO](artifacts/companion-editor-2026-11-09/VISUAL-REVIEW.md) covers the corrected editor, actual earned recap and separate materials/halo matrix. Do not add overlapping preference reruns together.
- [x] [Final native audit](artifacts/companion-editor-2026-11-09/native-final-audit.json): all 144 runtime sources match and compile with zero errors; Rojo/diff checks pass. QA driver/spec folder/import helper removed from Edit, Medium/Automatic/default viewport restored.
- [x] Private v358 Published and runtime4bf7893 pushed; refreshed native Version History proof in PLAY-BUILD.md.
- [x] Current seven-owned editor benchmark: three open/close cycles,7 models open and0 closed; six counterbalanced single/grid samples show17.65/17.88ms median frameP95. This is a current workload comparison, not the unmeasured historical v344 baseline. Test-enabled-session Focus interference has no established individual-fixture cause; ordinary earned controls pass in a clean session with the QA auto-driver disabled.

## Completed item-egg and Aero build

Private v274 / bb8c60b contains the accepted [item-egg scope](ITEM-EGGS-AND-AERO.md): unified Companion / Hue shop, saved stacked hue/reset items, independent five-dose channels, migration of old purchases, per-pet customization, seven-ID color support, planted motion, faster aiming and themed supply balls.

## Current palette and roster — private v316

- [x] White Main / light-grey Secondary, unchanged hue anchors and independently saved doses. New hatches offer four pets; already-owned Vezzi, Kiprik and Nolli remain usable. Retained rare progress freezes safely. [Scope and148-case verification](NEUTRAL-ROSTER.md).
- [x] Complete native visual/verification gates for the new luminous material candidate above, including a separate six-round seven-rig comparison and Astra GO. Published in private v358. The older experiment stays parked in stash7f72106e5d3a9444c6ae4b03be975f637e2c0505 and was inspected selectively rather than restored wholesale; [trial history](PET-MATERIAL-PASS.md). Published v316 includes none of that experiment.
- [x] Rechecked actual welcome→Meet→E petting→Back with the virtual controller disconnected. Ordinary native input works; loading and affection lifetime regressions also pass in the care slice.
- [ ] New replacement designs for the three retired pets require visual approval; no replacements were silently substituted.

## Approved pet-care expansion — work in progress, November 9

The user authorized building the [Astra proposal](PET-CARE-EXPANSION.md) within the [architecture constraints](PET-CARE-ARCHITECTURE.md), starting with loading/feedback, then carry/machine/garden. The first reviewed care slice is private v326 Published / 3c6b61b, verified in native Version History. Carry and machine are planned in CARE-CARRY-MACHINE.md. Remaining unchecked phases are not implemented. Illustrative prices, chances, XP curves and dimensions still require play tuning.

- [x] Complete-model loading/fallback before authored mesh reveal, bounded shared asset queue and owner/hatch priority; reviewed whole-rig handoff and stale-lifetime cases. [Care verification](CARE-LOADING-FEEDBACK.md).
- [x] Exact conditional color swatches on the existing four hue rows; live muted Customize portrait; explicit one-channel Reset Main/Secondary confirmation. Actual Largest phone controls preserve a full first row.
- [ ] Version the Hue catalog and preserve historical rolls, odds and receipts. Four-pet noon/midnight trials provisionally accepted Garnet on Main and Secondary and Ink on Secondary. Ink Main is pending. Its original blink nearly disappears at midnight, and the warm-gray backing trial left oval marks when the eyes closed. Test a narrow stroke that follows the actual lid pose before offering Ink on Main. [Original blink](artifacts/round-juice-2026-11-09/palette-ink-main-0-blink-TRIAL.jpg) · [Rejected backing](artifacts/round-juice-2026-11-09/ink-contrast-0-blink-TRIAL.jpg).
- [x] Tier-based device-art merge response, bounded existing effects and88%-opacity motifs over the opaque theme base. Earned low-tier and labeled injected-clear native recordings pass review.
- [x] Carry from petting, supported set-down, one physical care-machine bay and confirmed owned-pet switching; fast shortcuts retained. Astra accepted actual earned R15 motion and Largest phone UI; [verification](artifacts/carry-machine-2026-11-09/VERIFY.md) distinguishes isolated switch/contention tests from actual controls. Private publication is recorded in PLAY-BUILD.md.
- [x] Standard/Gloss/Matte finish ownership and per-pet selection, with native day/night facial review.
- [ ] Metal and gradient-to-white/black Skin FX require accepted native rendering; UV/compositor work remains open.
- [x] Feature Egg with Horn/Claw/Wing items, rarities, storage and separate five-stage earned/visible sizes per pet, shipped in private v389. Tail shapes remain future scope.
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
