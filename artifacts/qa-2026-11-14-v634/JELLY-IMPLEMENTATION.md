LATEST: see JELLY-ACTIVATION-RESULT.md (sourcepool4+4approvedflags READY; root integration/review pending). Earlier staged notes below are historical.

# Jelly / Lucky Material Egg implementation checkpoint

2026-11-14 · STAGED / NOT ACTIVATED · no publish. Parent requested temporary worker finish to free Astra slot.

## Implemented and compiled

- MaterialCatalog keeps **PoolVersion2** and existing PaidOrder Gloss/Matte. Staged pool4 immutable45Gloss/10Jelly/45Matte, cost16, sortedeligible and restricted Gloss→Matte→Jelly. Pools1/2/3 remain literal-compatible; pool3 future Pearl/Speckle inactive. Versioned odds/roll/cost/fixedNext; verified template lookup handles existing duplicate names. Pool4 availability requires allthree one/two-tone profiles verified.
- MaterialState pool4-only strict quote adds price/mode/fixedtarget, retains legacy shapes. Exact new public receipt proof includes poolVersion/selectionMode/quotedPrice. Historical and accepted reservation outcome preserved, no reroll; fixed reservation/result must match advertised target. Cost bound to versionedrules, pending result/eviction/equip behavior unchanged.
- HatchProgress defaults restrictiontrue and uses explicitfalse-only permission across shared helper. New mode checked beforeRNG and again beforefirst reservation write; already durable reservation/receipt proof wins. Public materialSelectionMode; host checks paired material capability. No activepool/price changes.
- MaterialIntent binds version/mode/price/guaranteedtarget and receipt proof; missing/inconsistent mode or fixedtarget cannot send. UI owner staged MaterialDisclosure/host/UICopy separately; its fixed-next disclosure correction is compiled but targeted re-review still pending.
- OddsText.preciseList provides4decimal probabilities summing100, existing whole-percent APIs untouched. MaterialPanel latest disclosure glue is UI-owned; preserve their edits.
- PetMaterials/Config staged BodyJelly and BodyTwoToneJelly, explicit core-part alpha semantics15body/8head+secondary/12ears-tail, face/charm/attachment/unknown opacity protected. One final GardenPetVisual Materials.transparency hook composes authored opacity once; missing/unverifiedpaired profiles coherently fall back opaque Standard. Existing expression changes by worldSol preserved.
- New BodyJelly.model.json merges namedchild into existing binarypack via default.project.json; TwoTone JSON appends Jelly only. BothNativeVerified=false. All old templateflags unchanged. Actual image75946070025172 roughness64/255; original91575369316154 is Decal wrapper.

## Verification / next coordinator runs

Owned runtime/spec/fixture compilePASS. Rojo build `build/jelly-staged.rbxlx` PASS. Offline ACTUAL MaterialCatalog/OddsText test passed all8ownershipsets,weighted boundaries,legacyuniform,fixedorder and18.1818/81.8182 disclosure; mounted pool2asserted.

New `JellyMaterialPool.spec.lua`8cases executes actual catalog/MaterialState/HatchProgress source in disposable sandbox with **only local catalogue PoolVersion4**; mounted pool2 unchanged. Tests typedquotes, old1/2reserved rejoin, accepted response loss/policyflip, zero-rollrestricted/newstale modes, pendingreceipt32eviction/freeequip and existingcommons→100Jelly. Needs actual Studio run; no passing count claimed.

New `JellyMaterials.spec.lua`4cases tests real MaterialOwner cloning/opacity/Overlay pigment, protected roles, pairedfallback/recovery, authoredalpha/Standardrestore. Lifecycle proof only, no GPU claim. MaterialIntent adds exact pool4receipt/mode/fixed-disclosure case. Run existing MaterialProgress/HueProgress/ToyFeatureProgress/HueClear/CharmRules/RestrictedEggs/Store suites; ordinary randomfixtures nowexplicitlyoptinfalse,3hostfixtures inject deterministic allowedPolicy ratherthanrealservice. All fixture changes compile; no full regression pass claimed yet.

## Native proof distinction

Coordinator reports actual v2 manual-alpha/Gloss-alias study images ready, actual gray64 image validated via typed ImageLabel warmup (raw URI preload failure was transport-type bug). Actual8Matte/Gloss/Standard/Jelly look frames and plain background exist under jelly-native/v2-*.png. These are valid look studies, **not new production renderer verification**. Astra review pending.

Updated fixture options READY/compiled:
`new(client,PlayerGui,{columns={'standard','gloss','matte','jelly'},allowUnverified=true,roughnessId='rbxassetid://75946070025172',nativeJellyProfile=true,useRendererOpacity=true,...})`.
This binds BodyJelly/BodyTwoToneJelly via disposablecandidate clones and actual PetMaterials.transparency (manualalphaoverrides rejected). Report profileMode/opacityOwner/bodyMaps/bodyTransparencies plus ready/frustum/sourceproof. Root mustfreshclone currentclient/Config sources. No source/nativeflags or globalLighting mutation. Root executes actual newrenderer proof andAstra critique beforeactivation.

## Review and ownership

Architect Lucky plan GO from UI Sol; no implementation code review yet. Request sent UI Sol with this packet; independent backend/render source review and actualtests required. Systems owns MaterialCatalog/State/HatchProgress/materialserverbranch, MaterialIntent,OddsText,PetMaterials/Config/assets; GardenPetVisual ONLYopacityhook (worldSol expressionhook). UI sole writer init.client/UICopy/HueEggView/EggHatchView/MaterialDisclosure andlatest Paneldisclosureglue. No concurrent file reverts.

Pending unrelated review requests: sparse music audition tool (UI author), native hatch newfrustum/envelope delta andaudio duck (worldauthor). Initial nativehatch source requiredfixes re-reviewed GO; latest delta not reviewed yet. Parent canassign/read while this worker paused. No productionactivation, flagsverification or placepublish.

## Required implementation review fixes — resolved

UI Sol returned CHANGES REQUIRED for three bounded defects; all are now fixed and targeted re-review is **GO**:

1. MaterialState.valid table-guards every non-nil materialReservation before quote access. False/true/scalar/string/malformedquote cases reject without throwing.
2. PetMaterials.release always clears profile/tint binding, including already-missing surfaces. Owner.paintSafely uses that release on errors. jellyAlpha requires a current parented SurfaceAppearance with matching profile/version/verification (or explicit fixture override) and no failure before granting opacity. Detached/destroyed/failed bindings render opaque. New real native property-write failure regression covers cleanup, not just a hand-assigned flag.
3. Public snapshot.restricted now calls the same explicit-false-only helper as transaction mode; nil/unknown publishes true+fixed, allowed false publishes false+random.

Affected runtime/spec compilePASS. Updated coordinator invocation counts: **JellyMaterialPool9**, **JellyMaterials5**. Root runs actual fresh namespace tests and production-profile native fixture; no passing runtime count claimed yet. ActivePoolVersion2, both Jelly NativeVerified=false, no activation/publish.

Camera/shell/audio delta review transferred to UI Sol by coordinator; this worker must not duplicate it. Latest targeted review GO was also delivered directly to root.
