# Spec sweep, 2026-11-12 (afternoon, pre-publish)

Branch `feat/egg-drop-arcade-polish`, place 96451847774961, Studio Play, Rojo connected.
Every `scripts/*.spec.lua` was copied into `Server/ZZSpecs` (54 server-signature specs) or `Client/ZZSpecs`
(149 client/gui specs), with `PetAssetsReadyFixture`, the `ItemEggsVisualStudy` driver and the two frozen
fixtures beside them. A temporary `_Runner` module in each folder ran them one at a time (pcall, 90 s timeout)
with their documented arguments: `server`/`shared`, `PlayerProgress`/`SessionProfile`/`init.server`/
`GardenCareHost`/`Lounge`/`LoungeArt` sources, a fresh enabled ScreenGui as `parent`, and the live `EggDrop`
gui and board for the `gui,board` specs. Copies and runners were removed afterwards; the ZZSpecs folders stay.

## Totals

| | Last sweep (overnight, `artifacts/overnight-2026-11-12/SPEC-SWEEP.md`) | This sweep |
|---|---|---|
| Spec files | 198 | 205 (+DeckBoot, DeckQuests, DeckResults, DeckScreen, FaceplatePurchase, HeatPayout, HeatRequest, PetAttachments, QuestRotation, RewardRetry, RunDay; -CompactRecap, RewardPresentation, RoundRecapClarity, StickerPrintSeat retired by the deck rebuild) |
| Run | 196 (2 skipped) | 203 (2 skipped: PlayfulFieldObjectives, RigOnlyComparison) |
| Pass | 163 | **171** (3 of them are v7 "not applicable" early returns: GardenNookHost, SpringMeadowFollow, SpringMeadowHost) |
| Fail | 33 | **32** |

None of the 32 remaining failures traces to today's work (world v7, deck parts 1/2a/2b, pet attachments, glow,
or the review fixes). All 11 new specs pass.

## Fixed in this sweep (newly broken by today's work)

| Spec | Cause | Fix |
|---|---|---|
| SessionRecovery :138 | Stale: daily contracts retired for quests (4dae3d0), so a clean win pays welcome 6 + 8 = 14, not 20 | Spec expectations 20/32 -> 14/22 |
| GardenNook :36 | World v7 moved the nook; case used legacy absolute coordinates | Same owner/anchor geometry, now relative to `GardenLayout.Nook` |
| GardenNookHost :29 | Legacy creek detour fixture; v7 nook sits on a dais with different wet geometry | Early return outside the legacy world (v7 walkability covered by GardenWalkability/GardenGreyboxWorld) |
| SpringMeadowFollow :5, SpringMeadowHost :12 | v7 has no Spring Meadow (`World.Spring` nil) | Early return when the world has no spring |
| PetContactHost :41 | v7 lawn moved; the garden reset raycasts toward it before the anchor ray | Owner placed relative to `GardenLayout.Lawn` (legacy origin unchanged) |
| JellyOverflow :28 | Stale: warning text is danger red on the dark well since dec8b9e | Assert `#FF5A6E`; now reaches :47 (audio, see harness) |
| BoardContentPublication :7 | `reset(board, preset)` became `reset(board, preset, sameField)` (2b) | Anchor on `local function reset(board`; still a loadstring harness limit after that |
| HeatRequest, RunReturn | New review cases (cooldown; refused payout) | Added; pass |

Source fix found by the smoke test: opening the quest log (MENU/M) over the difficulty picker drew both translucent
layers on top of each other (2b). The picker layer now stays hidden while the log is open and returns when it closes
(`clientUI.refreshDeckOverlays`, open/close). Verified in Play.

## Remaining failures (32), classified

- **Harness (5):** BoardContentPublication (loadstring unavailable in Play); DropCaption :11, SaveNoticeOwnership :9,
  HardwareDeck :8 (OwnerSnapshot is nil in the execute_luau module instance); JellyOverflow :47 (overflow audio did
  not play: the Studio window lost focus during the run, which BoardAudio treats as an inactive device).
- **Known pre-existing, reconfirmed at the same assertion (10):** BackgroundPicker :33, CareMachineUI :66,
  DeviceItemFront :40, HardwareInstruments :89, HueEggView :51, PetLoopResetPresentation :76, PetNightStudy :15,
  PreferredTextLayout :69, SharedFinish :32, SharedHeaders :100.
- **Pre-existing stale expectations (12):** CompactDeck :85 (Backdrop.Tray), FamilyCrest :40, FieldQuestOwner :53
  (Backdrop.Customize), JellyRenderOwner (TrayOverlay), PocketDeckAim (Tray), RunGoals :60, StationProportions :7,
  StyleJournalActions :157 (FamilyRank; was :156), StyleJournalLayout :113 (was :117), SaveNoticeLayout :25,
  VividHandheld :65 (same 22px tab assertion; line moved when sticker cases were retired), Onboarding :98 (same
  starterGoal assertion as :93).
- **Likely pre-existing (4):** HatchOwnerTransition :20, HueItemReveal :16, RoamReturnCamera :34,
  PetLoopResetGarden :61 (same lines as the overnight sweep).
- **Pre-existing, newly unmasked (1):** SemanticUI :61. The overnight failure (:53, recap Details) was a case the
  deck rebuild retired (c5799e3); the run now reaches the journal case, which fails on `Bear.Species`. PetJournal
  is unchanged today.

ItemEggsVisualStudy failed once (:40, Lighting.ClockTime restored late while the live clock ran) and passed on rerun.

## Notes

- The `RoomView:1007 setContentCover` console errors during the client batch come from RoomView instances that
  specs construct with fake transitions; a clean Play session shows none.
- Studio test hook caveat: ending a round with `EggDropRoundTestHook` before any drop keeps `ResetId` (it is the egg
  id counter), so the next Room -> Board handoff waits forever on the content gate. Real rounds always drop eggs;
  recorded in TODO as a latent fragility.
