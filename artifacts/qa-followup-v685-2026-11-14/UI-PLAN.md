# Unpublished v685 UI and hatch follow-up

Sol implementation following `CREATIVE-BRIEF.md`. Architect review requested before runtime code. Published private v685 stays unchanged; no publish/upload. Root owns Studio/native captures/localization/release. Systems owns the separate grove-path work.

## 1. One receipt disclosure point

Use the existing shared cinematic **receipt-ready beat** (items2.2s, companion2.65s) as the coherent disclosure owner; do not add another animation timer. A small pure identity helper checks both the exact receipt id and the adapter's actual presentation state.

`HueItemReveal` reports receipt readiness once through its existing cinematic completion callback. Toy/Material/Feature panels and HueEggView use that same state for their outer/inner headings, supporting receipt text, result-specific button copy and accessibility labels. Before disclosure, localized neutral copy replaces identity; ready actions keep their existing safe timing. New-result setup must not inherit readiness from an older receipt. Suppress reentrant refresh while synchronous settled/reopen setup is still running; paint that ready identity in the outer refresh instead.

Fresh loading remains mysterious until a visible settled fallback/receipt can be shown. Skip/Reduced Motion/settled reopen disclose immediately with their actual visible item. Gate every title override, including `layoutTransaction`, and scan item-art accessibility labels. Preserve saved receipt/grant/ack/navigation behavior and FirstSpend cancellation fixes.

## 2. Pigment jars and truthful copy

Replace the jar's per-colour fruit/leaf/seed geometry with one consistent rounded pigment fill, curved fill surface and restrained highlight; retain compact glass/lid and palette. Saved rose/tide/citrus/iris/reset ids remain unchanged.

Use **Rose jar / Tide jar / Citrus jar / Iris jar** consistently in display catalog metadata, hatch/inventory/confirmation/accessibility text and UICopy. Legacy Reset Hue remains supported. Replace edible-fruit instructions in the affected player flow with jar/colour wording. Internal proof/controller identifiers may remain for compatibility; no redesign of the existing saved-use cosmetic choreography or recolouring rules.

## 3. Genuine spherical material sample

Remove Bear__CharmDot from MaterialFinishPreview. Reuse only `EggPreview3D`'s ready cloned **Core** (EggModels id97136732817875). Source `build_egg_models.py:181` creates that Core as a subdivision3 icosphere with UVs; actual native roundness/finish appearance still needs coordinator capture.

Use the existing cache/load API; destroy unused shell clones immediately, retain only this owner's Core, and detach the owner from any stalled cache callback on timeout/destroy. Bind the actual verified finish through MaterialOwner, preserve the round fallback during loading/failure, and report ProductionPBR only after successful native binding. Recheck epoch/parent after yields; keep the approximately70% frame occupancy/camera/light/shadow. No new mesh upload or charm substitution. Supporting receipt copy: “Material for your pet”.

## 4. Fixed rarity policy and a post-reveal answer

New pure client policy resolves only canonical authored metadata: FeatureCatalog Common/Uncommon/Rare; actual entries in PetCatalog.rares; explicit material presentation map JellyRare, Gloss/Matte/StandardCommon; other Toy/Hue/legacy/unknownsNeutral unless canonical metadata exists. No conditional-odds/ownership/price/colour/duplicate inference and no new tier names. Do not change pools, cost, versions or saved payloads.

Keep every approved timed hatch file at speed1. Common/Neutral retain the current body. Add a separately owned finish cue using the existing approximately80ms goal_tick sample, in a dedicated pooled cue alias: Uncommon one faint upper note at receipt+.10s; Rare two quiet upward notes at+.12/+.26s. The answer ends within450ms. Calibrate modest gains against the existing finish window so peaks remain about1dB within it; no louder jackpot. Render matched short Common/Uncommon/Rare listening examples with measured levels, without claiming to hear them.

Schedule from the same cinematic age only after actual receipt disclosure. Consume/drop overdue events, at most one per frame, rather than dumping delayed notes. Separate accent ownership preserves the base file and allows cancel/skip/focus-loss/reduced/reopen/destruction to stop it. No task-delay note queue, global combined-file pitch shift, late preload replay or extra reward wait.

## Files and verification

Runtime: HueEggView, HueItemReveal, ToyPanel, MaterialPanel, FeaturePanel, HueJarArt, MaterialFinishPreview, UICopy/HueCatalog display names; new identity/rarity helpers; bounded HatchCinematic/BoardAudio cue glue. EggPreview3D API extension only if lifecycle inspection proves necessary, coordinated before editing. No server/save/world edits.

Tests: pre-reveal/ready/skip/reopen/slow-load identities including accessibility and stale id; real typed-view callback/layout overrides; all four pigment jars with no fruit descendants and truthful text search; Core cache success/failure/timeout/destroy/late callback with actual spherical mesh + correct profile/opacity and no leaked shell clones; canonical tiers including conditional100% Jelly stillRare, unknownNeutral; accent timing/mute/focus/cancel/skip/reduced/replay/late-step burst suppression; exact unchanged opening audio prefix and bounded answer levels. Run appropriate existing native host/receipt/material/FirstSpend and localization-text bounds regressions.

Backlog independently reviews code before freeze. Root captures actual Toy/Hue/Material before-opening, hero and receipt frames, round fallback→PBR and Gloss/Matte/Jelly comparisons; Astra reviews actual images and audio implementation evidence. User listening determines rarity accent taste. No Smash intro reconstruction or broad hatch redesign.
