# Aero garden native test index

Generated from retained JSON by `python scripts/summarize_aero_verification.py`. This index does not run tests, certify source equality or publication, or replace actual controls/render evidence.

## Unique current suite results

- **Server: 172 cases across 19 suite identities.** Baseline 153; replace ToyReturn 11→23 (+12), ToyHost 4→5 (+1), PetAppearance 15→19 (+4), WorldRoutes 6→8 (+2): **153 + 12 + 1 + 4 + 2 = 172**.
- **Client core: 201 cases across 30 suite identities.** Largest baseline 197; replace HueCharmIntent 5→7 (+2) and GardenToyClient 8→10 (+2): **197 + 2 + 2 = 201**.
- **Additional focus: 91 cases across 6 additional suite identities.** These are outside the original 30-suite matrix; the selected counts appear below.
- **All client suite identities together: 292 cases across 36 suites**, with repeated preferences/reruns counted once per suite.

The fresh 13-case PetFocusUI raw result is retained; the expected **292 client cases / 36 suites** is supported by the selected files.

## Server selection

| Suite | Cases | Selected raw evidence |
|---|---:|---|
| GardenBridgeFollow | 2 | [server-relocated-toy-final.json](server-relocated-toy-final.json) · final relocated toy |
| GardenIntentHost | 3 | [server-final153.json](server-final153.json) · consolidated baseline |
| GardenMotion | 10 | [server-late-pacing-first.json](server-late-pacing-first.json) · late pacing |
| GardenNook | 5 | [server-final153.json](server-final153.json) · consolidated baseline |
| GardenNookHost | 6 | [server-late-pacing-first.json](server-late-pacing-first.json) · late pacing |
| GardenState | 12 | [server-relocated-toy-final.json](server-relocated-toy-final.json) · final relocated toy |
| GardenToyHost | 5 | [server-relocated-toy-final.json](server-relocated-toy-final.json) · final relocated toy |
| GardenToyReturn | 23 | [server-relocated-toy-final.json](server-relocated-toy-final.json) · final relocated toy |
| GardenWalkability | 11 | [server-final153.json](server-final153.json) · consolidated baseline |
| HatchProgress | 21 | [server-final153.json](server-final153.json) · consolidated baseline |
| HueHost | 4 | [server-final153.json](server-final153.json) · consolidated baseline |
| HuePalette | 6 | [server-final153.json](server-final153.json) · consolidated baseline |
| HueProgress | 18 | [server-final153.json](server-final153.json) · consolidated baseline |
| PetAppearance | 19 | [server-pet-appearance19.json](server-pet-appearance19.json) · fresh fixture reload |
| PetContactHost | 4 | [server-final153.json](server-final153.json) · consolidated baseline |
| PetLoopResetGarden | 5 | [server-relocated-toy-final.json](server-relocated-toy-final.json) · final relocated toy |
| SessionHost | 2 | [server-final153.json](server-final153.json) · consolidated baseline |
| SessionRecovery | 8 | [server-final153.json](server-final153.json) · consolidated baseline |
| WorldRoutes | 8 | [server-relocated-toy-final.json](server-relocated-toy-final.json) · final relocated toy |

## Client core selection

| Suite | Cases | Selected raw evidence |
|---|---:|---|
| AppearancePalette | 9 | [client-full-largest.json](client-full-largest.json) · Largest matrix |
| CompactEggShop | 4 | [client-full-largest.json](client-full-largest.json) · Largest matrix |
| CompanionHatchArt | 3 | [client-full-largest.json](client-full-largest.json) · Largest matrix |
| ControllerSheets | 9 | [client-full-largest.json](client-full-largest.json) · Largest matrix |
| EggArt | 2 | [client-full-largest.json](client-full-largest.json) · Largest matrix |
| EmulatorSafeArea | 8 | [client-full-largest.json](client-full-largest.json) · Largest matrix |
| GardenActivity | 4 | [client-full-largest.json](client-full-largest.json) · Largest matrix |
| GardenPetVisual | 11 | [client-relocated-toy-final.json](client-relocated-toy-final.json) · final relocated toy; preference not retained |
| GardenToyClient | 10 | [client-relocated-toy-final.json](client-relocated-toy-final.json) · final relocated toy; preference not retained |
| HatchCinematic | 8 | [client-full-largest.json](client-full-largest.json) · Largest matrix |
| HatchNavigation | 12 | [client-full-largest.json](client-full-largest.json) · Largest matrix |
| HatchOwnerTransition | 1 | [client-full-largest.json](client-full-largest.json) · Largest matrix |
| HollowAmbience | 11 | [client-relocated-toy-final.json](client-relocated-toy-final.json) · final relocated toy; preference not retained |
| HueAppearance | 7 | [client-full-largest.json](client-full-largest.json) · Largest matrix |
| HueCharmIntent | 7 | [client-late-focus-charm.json](client-late-focus-charm.json) · late native; preference not retained |
| HueEggView | 13 | [client-full-largest.json](client-full-largest.json) · Largest matrix |
| HueIntent | 8 | [client-full-largest.json](client-full-largest.json) · Largest matrix |
| HueItemReveal | 3 | [client-full-largest.json](client-full-largest.json) · Largest matrix |
| ItemPetVisuals | 7 | [client-full-largest.json](client-full-largest.json) · Largest matrix |
| JournalPurpose | 3 | [client-full-largest.json](client-full-largest.json) · Largest matrix |
| NewBabyRigs | 10 | [client-full-largest.json](client-full-largest.json) · Largest matrix |
| PetCharmShapes | 7 | [client-full-largest.json](client-full-largest.json) · Largest matrix |
| PetFocusKey | 3 | [client-full-largest.json](client-full-largest.json) · Largest matrix |
| PetLoopResetPresentation | 3 | [client-full-largest.json](client-full-largest.json) · Largest matrix |
| PetMeshResources | 2 | [client-full-largest.json](client-full-largest.json) · Largest matrix |
| PetNightStudy | 2 | [client-full-largest.json](client-full-largest.json) · Largest matrix |
| PetNightSurfaces | 7 | [client-full-largest.json](client-full-largest.json) · Largest matrix |
| PetPlantedMotion | 13 | [client-full-largest.json](client-full-largest.json) · Largest matrix |
| PetWeightTransfer | 2 | [client-full-largest.json](client-full-largest.json) · Largest matrix |
| SharedHeaders | 12 | [client-full-largest.json](client-full-largest.json) · Largest matrix |

## Additional focus selection

| Suite | Cases | Selected raw evidence |
|---|---:|---|
| FocusCharacterVisibility | 3 | [client-late-focus-charm.json](client-late-focus-charm.json) · late native; preference not retained |
| FocusFraming | 6 | [client-late-focus-charm.json](client-late-focus-charm.json) · late native; preference not retained |
| GreetingLifecycle | 4 | [client-late-focus-charm.json](client-late-focus-charm.json) · late native; preference not retained |
| GreetingOcclusion | 4 | [client-late-focus-charm.json](client-late-focus-charm.json) · late native; preference not retained |
| PetFocusUI | 13 | [client-pet-focus-ui13.json](client-pet-focus-ui13.json) · fresh final focus UI |
| PetGreetingShot | 61 | [client-late-focus-charm.json](client-late-focus-charm.json) · late native; preference not retained |

## Preferences and scope

- Original Largest matrix: **197 / 30**. Original Medium first run: **194 / 29 passing suites**, with JournalPurpose failed; its corrected 3-case rerun completes **197 / 30**. These repeated preferences are coverage, not extra unique cases.
- The current 201-case core is a consolidation of that baseline and later native updates. The late file does not retain text preference; do not describe this as a newly recorded complete 201-case run at both Medium and Largest.
- Counts follow actual retained case arrays, including Luau's 1-based numeric-key maps. Every present `passed`/`count` claim is checked against array length. Latest successful results replace the same suite; case lists from multiple revisions are never concatenated.
- Final relocation files replace earlier results for their rerun suites. Any unresolved failure in an ordered late/final batch stops generation; the tool cannot silently fall back to an older passing row. Known failed-first records are superseded only by an explicit later pass of that same suite.
- Internal assertions, 1,296×7 palette inputs, projection checks, frames, synthetic actors, care awards and repeated runs are not additional cases. Lighting/comparator QA and human-control/visual evidence are separate; no missing raw QA result is added here.
- Native Studio fixtures do not establish physical-phone behavior, live DataStore rejoin, service outages, extended cooperative play, or publication.

## Failed-first and correction trail

- [server-late-pacing-first.json](server-late-pacing-first.json): PetAppearance failed in that first late batch. [server-pet-appearance19.json](server-pet-appearance19.json) retains its fresh 19-case pass after fixture reload. Successful reruns of other suites replace baseline rows without increasing their counts.
- [server-final153.json](server-final153.json) is already a consolidation. Its recorded provenance identifies three corrected runner signatures and the reviewed dry-world care mock correction; its 153 is not summed with older batches.
- [client-full-medium-first.json](client-full-medium-first.json): JournalPurpose failed on the obsolete Foxfire Wick label. [journal-medium-corrected.json](journal-medium-corrected.json) preserves the corrected 3-case pass, with Kiprik's stable `foxfire_wick` route still checked.
- [client-regressions-first.json](client-regressions-first.json): failed-first suites **HueCharmIntent**. Later passing selections above supersede these failures; they are not extra cases.
- [focus-new-collector-first-native.json](focus-new-collector-first-native.json): failed-first suites **GreetingLifecycle, PetFocusUI**. Later passing selections above supersede these failures; they are not extra cases.
- [server-relocated-toy-first-runner.json](server-relocated-toy-first-runner.json): failed-first suites **WorldRoutes**. Later passing selections above supersede these failures; they are not extra cases.
- The relocated WorldRoutes first runner omitted its required current `LoungeArt.Source` argument. Its corrected final 8-case raw result is selected, while the failed runner artifact remains retained.
- HueCharmIntent's first failure exposed an uninitialized shape-control table; GreetingLifecycle/PetFocusUI first attempts lacked current helper methods in their isolated mocks. The corrected runs remain separately retained.
- [bridge-anchor-first-FAILED.json](bridge-anchor-first-FAILED.json) remains a failed diagnostic, not a pass. The dynamic bridge observation was later corrected to require a destination-bank crossing and a stable arrival within 3 studs before autonomous play; it does not claim dynamic exact-offset arrival. The independent static route fixture retains its <0.1-stud endpoint gate.
- The original [two-client-focus-occlusion-FAILED.png](two-client-focus-occlusion-FAILED.png) remains unattributed. Repeated clear native shots do not diagnose that original image. GreetingOcclusion proves the separately reproduced tiny/nonqueryable-decor class.

## Raw source fingerprints

| Raw JSON | SHA-256 |
|---|---|
| [client-full-largest.json](client-full-largest.json) | `bd064ccc8e73d5f23709df94fbba2d6c235437211e74cb08f041150c3280d29c` |
| [client-full-medium-first.json](client-full-medium-first.json) | `fef08aa29771188ebb3590bebdded4c1d01bf80c3ea69154c422890b0a672a64` |
| [client-late-focus-charm.json](client-late-focus-charm.json) | `b38403e2c7f28a81c6a86e2455bac93557cc339f84c69f69736372ed0a3e7111` |
| [client-pet-focus-ui13.json](client-pet-focus-ui13.json) | `be2ce30532e5e80bd56e0d7eb0fabc857dca8750fca5e8dd7e5781a4d1664e77` |
| [client-regressions-first.json](client-regressions-first.json) | `24b15605c780d456ff753e111dd02930d6e16369806cea55e5183f634b40746a` |
| [client-relocated-toy-final.json](client-relocated-toy-final.json) | `6d7c31dd545aa3c099b66d8b44d98ccb06ce2a05951c424e73876fdfc894821d` |
| [focus-new-collector-first-native.json](focus-new-collector-first-native.json) | `5bdb7b1685f267ce2a73d2776a179e4fc31779e6f9a8eeb91109da9d03d7447e` |
| [journal-medium-corrected.json](journal-medium-corrected.json) | `d893f6e2c70a4c2ffc5e06415d69d0d23fa5698fff239833b58f30502cabeb74` |
| [server-final153.json](server-final153.json) | `b8b1a7d54fe4a8278f8a6c7ad4ae84b8c5f67dc6c1664021f5b8e2b6ed2b4a2b` |
| [server-late-pacing-first.json](server-late-pacing-first.json) | `095c89acfd51f6ead35b1e124980fbcf678900b303cfd2f851b10b3b9cf286f4` |
| [server-pet-appearance19.json](server-pet-appearance19.json) | `2a7b44bbb542d029db24cccf94c2217a5d3acedc7ba15b339da3bef35ac3bac8` |
| [server-relocated-toy-final.json](server-relocated-toy-final.json) | `ac300cd24f67952dbd3b4551d93cb84f97b7c5e8249174d41f4e0a2a3aa7b2d5` |
| [server-relocated-toy-first-runner.json](server-relocated-toy-first-runner.json) | `22ade3384823d1beaae3d55ff3f7cb4307107453669cae96b675a824e3894923` |

Regenerate after saving new raw results. `--check` fails if this index is stale or a retained count disagrees with its actual cases.
