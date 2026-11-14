# QA pass 2026-11-13 v2 (Spencer, private v600): triage

Source: `notes.md` (copy of `obsidian-spencer/roblox qa pass nov 12 v2.md`) + 28 screenshots in `shots/`
("Pasted image <timestamp>.png"; the note lists each image right before the comments about it).
Spencer: "lets fix all of it." PC pass first, then a phone pass (from 195553 on).

Answered in chat, no build needed:
- "Play date 1/3" (193142) is the daily Play-date progress, not a player cap. The park has 9 slots; extra pets
  mingle and wait. No second park for v1.
- Colour mixing (194227): not for v1 (fruit stay preset colours; revisit later).

## R1 Hatch reveal + first-session flow (HatchCinematic, RevealStage, CoachCards first-session beats)
1. (192700) Reveal screen: add a confetti popper burst with sound on the reveal.
2. (192700) Reveal background doesn't fill the screen (gap at the top under the Roblox top bar, edges).
3. (192700) The transition out of the Pocket Deck shows a non-full-screen rect while closing.
4. (192904) Meet Bear: the Bear first appears in an awkward pose/position; plan a proper first spawn spot facing the camera.
5. (195712) First Bear: B = exit (not "Play again"), since we're onboarding; the "Hatch eggs" coach text comes after the Meet Bear screen, not on it; the bear screen fills the screen.
6. (193129/onboarding) After the Bear: make the garden walkthrough unmissable (it waits until the player is idle and visible; replayable).
7. (193416) Hatch eggs: the square shine overlay sits too far right and is a square over the whole panel: clip it to the egg; the circle gradient behind the egg is off-centre; particles come from off the right instead of the egg (193626).
8. (193416) Bear gets excited (hop/cheer) when the player presses Hatch.
9. (193839) Hatch eggs egg list scrolls (room for more eggs later).

## R2 Input, camera, controls (init.client input plumbing, ModalCursor/DeckCameraLock, PocketDeck touch)
1. No character movement while any menu/overlay/reveal is open (WASD/arrows currently walk the avatar behind the reveal).
2. Opening a machine while holding a walk key leaves the avatar walking: stop movement when a menu opens.
3. Camera clips through the ground/walls: prevent (camera occlusion / min zoom; Invisicam off, collision on).
4. (200131) Mobile Pocket Deck: bigger left/right hit areas in rounds; up/down disabled in rounds, enabled in menus for selection; B backs out of menus.
5. (193722, 194125) Controller hints ("Browse / Hatch / Back", Wardrobe hints): explain once what each does (a legend line or tooltip), and make sure each works on keyboard, gamepad and touch.
6. (193000, 194803) PC: our top-right buttons sit under Roblox's player list and are hard to click: move them so they never overlap CoreGui (player list, top bar) on PC.

## R3 Menu shell on every machine (Kit shade/overlay, sheet sizing, wallet, headers)
1. Overlay background doesn't fill the screen on machine screens (193626 Hatch eggs), doubles in Customize, missing on Quests (195946) and another (200037). One full-screen shade per open screen, always.
2. Mobile: menus too short (195844, 195931, 200120); top/left of first cards cut off (195844, 195946, 200037).
3. Every menu's Stars counter uses the 3D WalletStar (195844, 195931, 195946, 200037).
4. Missing back arrow top right on Quests (195946).
5. "Equipped" is the Equip button disabled, reading "Equipped" (194500, 195844), never overlapping names.
6. Category texts vanish until you click back in (194541).
7. Quests/dailies: more exciting and readable (195946): clear progress bars, reward chips, what to do.
8. Per-machine replayable "How it works" (a ? button on each machine screen; 2-3 short illustrated cards). Stamps explained here (193549). Move the stamp card from Hatch eggs to Quests (daily things live together).

## R4 Wardrobe, Customize, Deck style content
1. (194020) Hats clip into the Bear's head mesh: per-hat offsets.
2. A "None" option per Wardrobe category (unequip).
3. Customize: no previews for anything: real previews (pet with that finish/colour/toy).
4. (194227) Colour swatches more saturated; a place to reset fruit usage (restore default colour).
5. Toys category: a new icon; remove the Toy egg / Material egg footer rows; a small hint "More from eggs" instead.
6. (193916) Deck style Balls: animate each preview (balls fall in as a sample).

## R5 World + garden
1. (193025) Station indicator arrow disconnected under the icon: one connected marker; the first time near each, say what it is (name label).
2. (193300) The Browse eggs station lost its indicator: restore; fix arrows on all station visuals.
3. Pocket Deck customization desk: the deck model on the table still has thumbsticks: remove.
4. (193213) Marble river lining still flickers: overlapping meshes/coplanar faces: remove the duplicate.
5. Petting: +1 ★ more often (less time), with a sparkle burst on the Bear and a sound.

## R6 Mobile Pocket Deck (CompactDeck / phone layout)
1. (195553) Phone layout should look like PC: the full handheld and background, not the flat panel.
2. (195553) The welcome card covers the aim guide and its title cuts off ("Hatch your"): a small, subtle pill at the top that fades after a few seconds (or on first drop).

## Architect re-cut (2026-11-13) — final ownership
- R2.4 (phone deck hit areas) moves to R6; R6.2 (welcome pill) moves to R1; R3.5 + R3.6 (Equipped button, vanishing
  category text) move to R4; R2.5 (hint legends) split: Hatch eggs footer -> R1, Wardrobe/Customize footers -> R4,
  ControllerFocus -> R2.
- B on phone: in menus B = back (Spencer: "b to go back out of the menu"); in rounds B stays Items.
- Owners: init.client.lua R2 (others anchored edits: R3 at updateShade, R6 at deck dpad/B handlers + wide layout, R1 at
  CoachCards require); DeckKit.lua R3 only; EggHatchView/HatchCinematic/RevealStage/CoachCards/BoardHints R1;
  WalletStar/QuestLog/QuestLogHost/MachineHub/DeckPicker R3; ModalCursor/DeckCameraLock/RoomView R2;
  WardrobeShop/Customize (MaterialEditor, Hue views)/BallShop R4; StationAttract*/PetContact/PetAffection/world
  build scripts R5; DeckScreen.lua R6. UICopy.lua append-only, one new block per track at the end.
- Central fixes: movement lock on ModalCursor's setOpen edge (ref-counted, controls-only, not a WalkSpeed
  snapshot); shades: EggHatchView dim, DeckPicker local shade, journal -> Kit.modalShade, legacy modalShade only for
  round modal/pause; 3D wallet on phone: Kit.WalletSpec[36].star (18) vs WalletStar.MinSize (20).
- R6 phone handheld: keep resolveCompact geometry, showShell(true) drawn in the side shoulders (not the Small path).
- R5 world meshes: Blender/export only by the agent; coordinator uploads and rebuilds collision in Studio.

## Follow-up from Spencer mid-build (phone, v600)
- Fill-line board card "wayyy too intrusive": every board tip (fill line, first item) is now the same quiet pill as
  the Welcome (one short line, top of the board, fades after ~5 s). CoachCards + UICopy `coach.*.short`.
- Phone results: "TIDY WIN" and the Star sat too high: headline y 27 / subline 42, and the Star column (star,
  count, STARS) centres on the cards (DeckResults.buildPhone). Capture `studio/phone-results-748x294.jpg`.
