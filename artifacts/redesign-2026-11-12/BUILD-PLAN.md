# Redesign build plan (2026-11-13)

Spencer approved every mockup in `UI-SPEC-REDESIGN-MENUS-2026-11-12.md` and
`UI-SPEC-REDESIGN-CELEBRATIONS-2026-11-12.md` ("build all that") with the
recommended answers: Features and the Feature Egg hidden behind one flag;
background kept and drawn inside the board well; tier V violet; one-time
fill-line coach card; full-screen hatch reveal; gold plate for undyed pets;
"Round win 5, Tidy stack +1" payout wording; Hatch button on results.

## Slices and file ownership

One Studio and one Rojo tree, so implementers write code and pure specs only;
the coordinator runs every spec and capture in Studio, then integrates.
A file belongs to one slice at a time. `init.client.lua` is shared: each slice
makes small, anchored Edit calls in its own region only (A: deck picker / shop
routes; B: results data builder and hatch reveal hooks; C: round HUD danger
state and overflow cue).

| Slice | Wave | Owns | Spec sections |
|---|---|---|---|
| A. Shared header + Deck style | 1 | DeckKit.lua (header, icon tabs, wallet/back heights), DeckAssets.lua (icon cells), WardrobeShop.lua, FaceplateShop.lua, new BackgroundShop.lua, DeckPicker.lua | Menus 0.1, 0.2, 4 |
| B. Celebrations | 1 | new RevealStage.lua, HatchCinematic.lua, EggHatchView.lua (reveal host only), DeckResults.lua, RecapFeedback.lua, PetCatalog.lua (description), new CelebrationKit.lua (Display font, reward button, star token) | Celebrations 1, 2 |
| C. Round look + background in board | 1 | JellyLCD/JellySpanSurface/JellySprite/JellyVisual.lua, JellyPalette.lua, Pico8.lua TierRamps, BoardAudio.lua, DeckArt.lua/DeckBackdrop.lua (board pattern), DeckScreen.lua (border only) | Menus 5, 6 |
| D. Companions hub, Customize, Hatch eggs list | 2 (after A, B) | new CompanionsHub.lua, HueEggView.lua, EditorTabRail.lua, MaterialPanel/ToyPanel/FeaturePanel.lua, EggHatchView.lua (list + preview), PocketMenu/RoomView routes | Menus 1, 2, 3 |

Wave 2 starts once A (Kit.header, icon tabs) and B (EggHatchView reveal host)
have landed, because D builds on both.

## Flags and data

- `Shared.FeatureFlags.Features=false` hides the Features tab and drops the
  Feature Egg from the hatch list; saved features keep rendering.
- 3D eggs and the StarToken mesh: until modelled, the egg preview uses the 2D
  shell with tilt and hop, and the Star uses a 2D sprite with scale/rotation.
- New sound cue names are registered with no asset id (BoardAudio already
  warns and no-ops); Spencer authors the audio.

## Tests

- Each slice adds pure ZZSpecs in `scripts/` (timeline `sample(t)`, accent
  rule, spin decay, headline choice, meter maths, focus order, danger state
  machine, tier ramps, header geometry) and updates specs that assert removed
  names (ShowCharm/HideCharm, hatch grid, picker card, overflow cue).
- Coordinator runs CompactPhone, DeckScreen, DeckResults, DeckQuests,
  DeckBoot, HatchProgress, HueProgress, MaterialProgress, ToyFeatureProgress,
  WearablePurchase, FaceplatePurchase, RunReturn, WorldRoutes and the new
  specs in Studio, plus captures at 1920x1080 and 812x354 against the mockups.

## Architect review changes (2026-11-13)

1. **A keeps the DeckPicker object and its fields** (`picker.shade` is the Deck
   style root; `tabs`, `active`, `sound`, `cancel`, `music` stay). Faceplates and
   Backgrounds become the two style tabs under `Kit.header`; the Settings and
   Pocket Trials pages stay inside the picker (re-skinned with the header) so
   DeckMenu routes keep working. A owns `src/shared/FeatureFlags.lua`
   (`Features=false`) in wave 1. A is the only slice that regenerates the
   DeckAssets atlas.
2. **B keeps every Kit addition in CelebrationKit.lua** (Display font with
   Builder Sans ExtraBold fallback, reward button, star token, headline drawn
   with rotated TextLabels and strokes; no atlas sprites). B keeps the
   `nurseryView` fields init.client.lua reads (`shade`, `revealHost`, `body`,
   `ackReady`, `ownsInput`).
3. **DeckArt.lua API is frozen in wave 1**: C may add exports, never rename or
   remove (`Art.setBackgroundPreview`, `Art.setBackground` and the rest are used
   by A and B).
4. **Danger state (C)**: grace is 1.1 s, so no per-second countdown. The server
   publishes `OverflowGraceLeft` (seconds, 0 when not overflowing) beside
   `OverflowPressure`; the client shows calm / near (amber line + "FILL LINE"
   tag, from pressure) / over (amber haze, "Stack too high · Merge to clear",
   line drains by GraceLeft / grace, red in the last 0.35 s). One entry cue, no
   repeating blip. **Coach card and its pause are cut** from this build (it needs
   a saved "seen" flag, which changes save v10); follow-up for Spencer.
5. **Feature hidden, not removed (D, flag from A)**: FeaturePanel is still
   constructed and the `featureReceipt` page and "Open saved feature" path keep
   working for pending feature hatches; only the tab and the Feature Egg row
   in the hatch list are hidden.
6. **Receipts (D)**: material, toy and feature "Use now" land on the hub's Pets
   selector instead of the removed Pet tab; one spec per receipt kind.

## Added 2026-11-13 (Spencer)

- **3D eggs and Star:** base egg (top/bottom shell + glow core) with one texture per egg type, a 3D Star token, and a preview effects recipe (`assets/eggs/`, Fable art pass). The coordinator uploads and wires them into the Hatch eggs preview and the results Star after slice D.
- **Placeholder audio for every cue without an asset** (`assets/audio/placeholder/`); Spencer's own audio replaces them later.

## Checkpoint 2026-11-13 ~01:30 (paused for usage; resume 04:00)

Done, uncommitted on feat/egg-drop-arcade-polish (nothing committed since f443b36):
- Slices A-D built; every client/shared/server module loads; client boots clean.
- Full regression: 37/53 client specs passed, then fixes landed for the rest; still to re-run:
  AppearancePalette, CareMachineUI, CompactDeck, CompactEggShop, ControllerSheets,
  DeviceItemFront, MaterialEditor, SharedHeaders (pass a live ScreenGui), StarsPresentation,
  UsableSheetWidth. Pre-existing failures (ignore): SaveNoticeLayout, StyleJournalActions,
  StyleJournalLayout, VividHandheld, Onboarding, SemanticUI (PetJournal Species).
- Code review GO WITH CHANGES; all fixes applied (stuck reveal, danger after round end
  zeroed on server, reveal ring name clash, reveal per-frame cost). Span budget 1229/1536.
- 28 placeholder sounds uploaded and wired in BoardAudio (`placeholderIds`); ids in
  assets/audio/placeholder/manifest.json. Run ArcadeAudio/PresentationAudio/LoopAudio.
- 3D eggs + Star uploaded; ids in src/shared/EggModels.lua. MeshId can't be set by
  Rojo/scripts, so parts are created with AssetService:CreateMeshPartAsync (verified).
- In flight when paused: slice D agent wiring the 3D egg preview into EggHatchView;
  slice B agent wiring the 3D Star into DeckResults. If they did not finish, do it here.

Next: copy specs to ZZSpecs, fresh Play, run the full set (runner pattern: spec(client,
freshScreenGui), own-gui specs get PlayerGui, gui/board specs get the EggDrop gui + board),
capture every screen at 1920x1080 and 812x354 against the mockups, commit, publish via
File > Publish (computer-use; minimise the Studio home window first), record in PLAY-BUILD.md.

## Not in this build

Audio by Spencer (placeholders ship),
Wardrobe card thumbnails, prop crowding, Easy payout rebalance.
