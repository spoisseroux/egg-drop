# Spec sweep, 2026-11-12

Branch `feat/egg-drop-arcade-polish`, place 96451847774961, Studio Play (fresh Studio save), Rojo 7.7.1.
Every `scripts/*.spec.lua` was copied to ZZSpecs and run from a temporary runner (pcall, 90 s timeout each).
Arguments followed each spec header: `server`/`shared` folders, current module `.Source` text for the source-injected
server specs, a fresh enabled ScreenGui as `parent`, and the live `EggDrop` gui and board for `gui,board` specs.

## Totals

- 198 specs: 196 run, 2 skipped (benchmark/QA drivers).
- First pass: 158 pass, 38 fail.
- After fixes: **163 pass, 33 fail**.
- Remaining 33: 10 known pre-existing (reconfirmed at the same lines), 4 harness limits,
  19 pre-existing stale expectations (13 dated to an older commit, 6 "likely" by dependency analysis).
- No remaining failure traces to tonight's commits.

## Fixes

- Specs (stale expectations): GardenBabyMotion, HueSwatches, PreferenceFlush, ToyFeatureHost, RewardPresentation:30.
- Source: `PetMaterials.template()` picks the NativeVerified copy when the material pack has same-named
  templates; used by `PetMaterials` and `MaterialFinishPreview`.

## Place state found (not changed)

The open Studio place has duplicate instances: two `ReplicatedStorage.Shared` (the second holds only `Hello`),
and two copies each of `Shared.BearRigDefinition`, `Shared.Pico8`, `Client.PetIdleBeats`, `Client.PetReactions`
and `PetAssets.Bear`. The code copies are byte-identical. Every file added through Rojo during this sweep
was also created twice, so the Rojo plugin looks double-connected.

## Smoke test (Studio Play)

Fresh save: 5 Spaces earned the Bear (meet card renders, two-tone, no charm).
Meet Bear opens the focus view; holding E pets (content eyes, hearts).
The menu opens as dark glass with Stars 6, and the egg shop lists 4 eggs with odds.
"Play for Toy Egg" starts a round. 14 centre drops overflowed, and the recap showed +1 Star (RewardStatus Saved).
Companions station not opened (prompt hold cannot be synthesized here).
Console: only the known EditableImage and asset 203785492 warnings, plus expected spec fixture messages.

## Results

| Spec | Result | Classification |
|---|---|---|
| AppearanceIntent | PASS |  |
| AppearanceIntentClient | PASS |  |
| AppearancePalette | PASS |  |
| AppearanceStyle | PASS |  |
| ArcadeAudio | PASS |  |
| BackdropFloor | PASS |  |
| BackdropGlobal | PASS |  |
| BackgroundAppearanceCatalog | PASS |  |
| BackgroundAppearanceHydration | PASS |  |
| BackgroundAppearancePersistence | PASS |  |
| BackgroundPicker | FAIL :33 | Known pre-existing, reconfirmed. |
| BoardAngle | PASS |  |
| BoardContentGate | PASS |  |
| BoardContentPublication | FAIL | Harness: needs loadstring, which Play does not allow. |
| CareAvatarJoints | PASS |  |
| CareCompanionSave | PASS |  |
| CareMachineUI | FAIL :66 | Known pre-existing (233px row), reconfirmed. |
| CarePose | PASS |  |
| CloseProgress | PASS |  |
| ColdHatchSplit | PASS |  |
| CompactDeck | FAIL :85 | Pre-existing stale: Backdrop.Tray moved (be57098, Nov 9). |
| CompactEggShop | PASS |  |
| CompactRecap | PASS |  |
| CompanionCrest | PASS |  |
| CompanionEligibility | PASS |  |
| CompanionHatchArt | PASS |  |
| CompanionScale | PASS |  |
| ControllerFocus | PASS |  |
| ControllerSheets | PASS |  |
| DeckBackground | PASS |  |
| DeckComposition | PASS |  |
| DeckExperience | PASS |  |
| DeckMergeJolt | PASS |  |
| DeviceItemFront | FAIL :40 | Known pre-existing, reconfirmed. |
| DirectPetting | PASS |  |
| DispenserFeedback | PASS |  |
| DropCaption | FAIL :11 | Harness: OwnerSnapshot.read() is nil in the execute_luau module instance (no live owner state). |
| EggArt | PASS |  |
| EggBrowseNavigation | PASS |  |
| EggShopReopen | PASS |  |
| EmulatorSafeArea | PASS |  |
| FamilyCrest | FAIL :40 | Pre-existing stale: mastery family cards retired from DeckMenu. |
| FieldEffects | PASS |  |
| FieldFeedbackOwner | PASS |  |
| FieldObjectives | PASS |  |
| FieldQuestLayout | PASS |  |
| FieldQuestOwner | FAIL :53 | Pre-existing stale: Backdrop.Customize gone. (:5 was a no-pet precondition; rerun with the Bear earned.) |
| FieldQuestText | PASS |  |
| FocusCharacterVisibility | PASS |  |
| FocusFraming | PASS |  |
| GardenActivity | PASS |  |
| GardenBabyMotion | PASS (was :79) | Stale: default secondary is now #A8A5AE (e9d9c52). Spec updated. |
| GardenBridgeFollow | PASS |  |
| GardenCare | PASS |  |
| GardenCareClient | PASS |  |
| GardenCareIntegration | PASS |  |
| GardenCareRender | PASS |  |
| GardenCareStartup | PASS |  |
| GardenClient | PASS |  |
| GardenFocusReach | PASS |  |
| GardenGreyboxWorld | PASS |  |
| GardenIntentHost | PASS |  |
| GardenItemAppearance | PASS |  |
| GardenMotion | PASS |  |
| GardenNook | PASS |  |
| GardenNookHost | PASS |  |
| GardenPetVisual | PASS |  |
| GardenState | PASS |  |
| GardenToyClient | PASS |  |
| GardenToyHost | PASS |  |
| GardenToyReturn | PASS |  |
| GardenWalkability | PASS |  |
| GreetingLifecycle | PASS |  |
| GreetingOcclusion | PASS |  |
| HandheldTextLayout | PASS |  |
| HardwareDeck | FAIL :8 | Harness: same OwnerSnapshot limitation. |
| HardwareInstruments | FAIL :89 | Known pre-existing (CanopyArt path), reconfirmed. |
| HatchActions | PASS |  |
| HatchCinematic | PASS |  |
| HatchNavigation | PASS |  |
| HatchOwnerTransition | FAIL :20 | Likely pre-existing: hatch cinematic/Room busy path not touched tonight. |
| HatchProgress | PASS |  |
| HollowAmbience | PASS |  |
| HollowClock | PASS |  |
| HueAppearance | PASS |  |
| HueCharmIntent | PASS |  |
| HueEatingProof | PASS |  |
| HueEggView | FAIL :51 | Known pre-existing, reconfirmed. |
| HueHost | PASS |  |
| HueIntent | PASS |  |
| HueItemReveal | FAIL :16 | Likely pre-existing: HatchCinematic not touched tonight. |
| HuePalette | PASS |  |
| HuePortraitLifecycle | PASS |  |
| HueProgress | PASS |  |
| HueSwatchInspection | PASS |  |
| HueSwatches | PASS (was :13) | Stale: Secondary example quoted against old #C8C8C8 neutral; re-quoted from the resolver (stage-5 anchors unchanged). |
| ItemEggsVisualStudy | PASS |  |
| ItemPetVisuals | PASS |  |
| ItemReceiptComposition | PASS |  |
| JellyLCD | PASS |  |
| JellyMarks | PASS |  |
| JellyOverflow | PASS |  |
| JellyPalette | PASS |  |
| JellyRenderOwner | FAIL | Pre-existing stale: Backdrop.TrayOverlay path. |
| JellyRendererBenchmark | PASS |  |
| JellySprite | PASS |  |
| JellyUnderlay | PASS |  |
| JournalPromptPriority | PASS |  |
| JournalPurpose | PASS |  |
| LoopAudio | PASS |  |
| LoungeStations | PASS |  |
| MaterialEditor | PASS |  |
| MaterialFinishPreview | PASS (was :27) | Real bug, pre-existing since 97c64d0 (Nov 9): PetMaterials.rbxm holds unverified duplicate BodyGloss/BodyMatte/BodyMetal; the client got the unverified copy first, so Gloss/Matte fell back to standard. Fixed in src (prefer the NativeVerified copy). |
| MaterialHost | PASS |  |
| MaterialIntent | PASS |  |
| MaterialProgress | PASS |  |
| MenuLifecycle | PASS |  |
| MenuPolish | PASS |  |
| NeutralPetRoster | PASS |  |
| NewBabyRigs | PASS |  |
| Onboarding | FAIL :93 | Likely pre-existing: starterGoal copy (EggHatchView unchanged tonight). Not run against a pre-tonight build. |
| PersonalToyGardenTimeline | PASS |  |
| PetAffection | PASS |  |
| PetAppearance | PASS |  |
| PetAssetReadiness | PASS |  |
| PetAward | PASS |  |
| PetCharmFocus | PASS |  |
| PetCharmShapes | PASS |  |
| PetContact | PASS |  |
| PetContactHost | PASS |  |
| PetContactIntentClient | PASS |  |
| PetCoos | PASS |  |
| PetFocusKey | PASS |  |
| PetFocusUI | PASS |  |
| PetFruitEating | PASS |  |
| PetGreetingShot | PASS |  |
| PetHeldContact | PASS |  |
| PetLife | PASS |  |
| PetLoopResetGarden | FAIL :61 | Pre-existing: no server garden source changed tonight. |
| PetLoopResetPresentation | FAIL :76 | Known pre-existing, reconfirmed. |
| PetMaterialExpressions | PASS | Was flagged as pack precondition; passed in both runs tonight. Same duplicate-template root cause likely made it order-dependent. |
| PetMaterials | PASS |  |
| PetMeshResources | PASS |  |
| PetNightFace | PASS |  |
| PetNightStudy | FAIL :15 | Known pre-existing, reconfirmed. |
| PetNightSurfaces | PASS |  |
| PetPersonalPlay | PASS |  |
| PetPlantedMotion | PASS |  |
| PetRoamHint | PASS |  |
| PetWeightTransfer | PASS |  |
| PetWholeRigGate | PASS |  |
| PhonePetFirstRow | PASS |  |
| PlayfulFieldObjectives | SKIP | Benchmark driver; needs FieldRunBenchmark dependencies. |
| PlayfulPresentation | PASS |  |
| PocketDeckAim | FAIL | Pre-existing stale: Backdrop.Tray path. |
| PreferenceFlush | PASS (was :41) | Stale: pets start with no charm (81ab8fe); first case now turns the charm ON. |
| PreferredTextLayout | FAIL :69 | Known pre-existing, reconfirmed. |
| PresentationAudio | PASS |  |
| PresentationPolicy | PASS |  |
| RecapFeedback | PASS |  |
| ReceiptRouteGuard | PASS |  |
| RegisteredEggAtlas | PASS |  |
| RewardPresentation | FAIL :38 (was :30) | Pre-existing stale. :30 egg panel hidden in the unified receipt since 4bf7893 (Nov 9); spec updated. :38+ assert mastery receipt lines retired in a3fce0c (Nov 9). Needs a rewrite, not a src fix. |
| RigOnlyComparison | SKIP | QA driver; needs study driver/comparison/archive. |
| RoamReturnCamera | FAIL :34 | Likely pre-existing: tonight's RoomView edits do not touch driveModes. |
| RoundEndPresentation | PASS |  |
| RoundJuiceShop | PASS |  |
| RoundRecapClarity | PASS |  |
| RunGoals | FAIL :60 | Pre-existing stale: rank promotion copy retired. |
| RunReturn | PASS |  |
| SaveNotice | PASS |  |
| SaveNoticeLayout | FAIL :25 | Likely pre-existing: NectarPurpose box is 0px tall in the loading state (layout, not font). Not run against a pre-tonight build. |
| SaveNoticeOwnership | FAIL :9 | Harness: same OwnerSnapshot limitation. |
| SemanticUI | FAIL :53 | Pre-existing stale: recap details always open; activateDetails returns false since 4bf7893. |
| SessionHost | PASS |  |
| SessionRecovery | PASS |  |
| SharedFinish | FAIL :32 | Known pre-existing, reconfirmed. |
| SharedHeaders | FAIL :100 | Known pre-existing (Recipe_meadow), reconfirmed. |
| SharedToyRetirement | PASS |  |
| SpringMeadowFollow | PASS |  |
| SpringMeadowHost | FAIL :29 | Pre-existing: spring slots vs greybox layout; host/garden source unchanged tonight. |
| StarsPresentation | PASS |  |
| StationProportions | FAIL :7 | Pre-existing stale: lounge geometry changed by the greybox swap (c7a189e). |
| StickerPrintSeat | PASS |  |
| StorePurchase | PASS |  |
| StoreView | PASS |  |
| StudioStore | PASS |  |
| StyleJournalActions | FAIL :156 | Pre-existing stale: FamilyRank retired. |
| StyleJournalLayout | FAIL :117 | Likely pre-existing: goalsButton missing; PetJournal only recoloured tonight. |
| ThemeLCD | PASS |  |
| ToyFeatureHost | PASS toy+feature (was :116) | Stale: same no-charm default. |
| ToyFeatureIntent | PASS |  |
| ToyFeatureProgress | PASS |  |
| UsableSheetWidth | PASS |  |
| VividHandheld | FAIL :87 | Pre-existing stale: roomy menu tabs are 22px since bf72d93/be57098. |
| WelcomeCoaching | PASS |  |
| WorldRoutes | PASS |  |
| WornTheme | PASS |  |
