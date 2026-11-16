# QA pass 2026-11-15 (Spencer, phone, private v735): triage

Source: `notes.md` and `shots/` (filenames are timestamps). Spencer: "after we do all this we're really close to pushing v1". Fable owns the visuals, the sounds and the debugging.

## D: Pocket Deck (Fable lane D, owns Studio Play)
- D1 (173720, 173936). **The deck is still the wrong size on phone, even after the first round.** The handheld's top sits under Roblox's buttons and its bottom runs off screen (the MENU and Items labels touch the edge).
  - Find the real root cause: what scales the shell, and when the safe area and inset arrive.
  - Make it fit **both** width and height inside the safe area every time, with one deterministic layout function on every open and on every viewport or inset change.
  - Add a spec that checks the shell fits at 812x354, 844x390, 926x428 and a tablet size, including after a second open.
  - **FIXED 2026-11-15 (lane D). Root cause:** it was never a timing fault. `DeckScreen.resolveCompact` did not fit the shell at all; it authored it to overflow. Measured in Play at 844x390: the body (`Band`) was `4,60 836x362`, so its bottom was at 422 on a 390 px root (`body = H - bodyTop + 32`, "runs off the bottom edge"), the glass ended 4 px from the screen edge, and the bumpers are drawn 12 design px above the body, at y 55, behind Roblox's buttons (keep-out 58). One input always gave that one layout, which is why it looked the same on the first open and after a round. b70d56b only moved the same overflowing shell down 16 px.
  - **What scales the shell:** nothing on phone. It is stretched to the root in px (`sx = body.w / 1600`, `sy = body.h / 800`); the root is the `EggDrop` gui under `DeviceSafeInsets` while Mode is Board, and the top keep-out is `GuiService.TopbarInset` (116x58 when it reads zero). `layout()` already reruns on the Backdrop's size, on `TopbarInset`, on every Mode change (deferred) and 0.25 s later, so the inputs were arriving; the function they fed was wrong.
  - **The fit (deterministic):** `Screen.Fit = {side=4, crown=16, chin=14}`. The body is 4 px in from the left, right and bottom of the root, its bumpers start 2 px under the top bar, the glass sits 16 px under the body's top and 14 px above its bottom, and the d-pad, MENU, A and Items are laid out against that bottom, not the screen's. Cost: the board is 19 to 20 px shorter (275 instead of 294 at 844x390). Tablets and small windows ("Small") had the same fault (LCD sized to the root height, body off every edge); they now fit the whole handheld with the LCD text still at 1.2x or more.
  - **Spec:** `scripts/DeckFit.spec.lua` (geometry at 812x354, 844x390, 926x428 with three keep-outs; 1024x710 and 1180x762; a built deck at each size on the first layout and after hide, other sizes, show; and a live pass over the real deck). It fails on the pre-fix `DeckScreen` ("812x354 keep 116x58 body 4,60 804x326 leaves the safe area") and passes now, live on the first open and again after leaving and reopening the deck. Captures: `verify-D/D1-*.png` (magenta = the safe root and the keep-out).
- D2 (174105). **Opening and closing the deck is abrupt.**
  - A full-screen overlay and a smaller overlay pop in, then animate roughly.
  - The power-on animation sometimes cuts off before it finishes.
  - Make the transition one smooth, satisfying motion (the shade fades in, the handheld rises and settles, the screen powers on fully every time), and the reverse on close.
  - **FIXED 2026-11-15 (lane D).** What was wrong, measured frame by frame in Play:
    - Two overlays: the handoff shade lived in the inset `SafeContent` frame (828x374 on an 844x390 root) with a second full-screen curtain behind it at the same alpha, so the inner rectangle read darker (shot 174105). It is now one full-screen shade (`EggDropOverlays.DeckHandoff`).
    - Abrupt: 0.16 s fade, a hard swap, a 0.10 s fade back, and the HUD cut in on the frame the boot ended.
    - The power-on cut off: any key, click or tap from 150 ms skipped it, and it also ended early whenever the boot's ownership test failed (a pending hatch, an overlay). On a phone the tap that opened the deck was often still landing.
  - **Now (`DeckTransition.Timing`):** open = shade in 0.26 s, swap under it, the handheld rises from below with its screen dark and settles (0.46 s, a small overshoot) while the shade lifts (0.30 s), then the power-on plays all 24 frames (taps no longer skip it; only leaving the deck ends it) and its last frame fades onto the lit HUD over 0.22 s. Close = the screen shutters off (0.16 s), the handheld sinks as the shade comes in (0.30 s), swap, the shade lifts off the garden (0.32 s). The handheld's rest position is restored on every path, including a cancel.
  - **Verified in Play at 844x390:** two open/close cycles traced per frame (rest y back to 20 after each; frames 0 to 23 all shown; no lit frame between the boot and the fade), and an open with five key presses during the boot (24 of 24 frames, `BootSkipped` false). `DeckBoot.spec` has a new case for hold, no-skip, linger and fade. Captures: `verify-D/D2-*.png` (the rise and the sink were taken with the Studio-only `DeckHandoffSlow` attribute).
  - Cost to know about: the deck is playable about 2.6 s after the tap (it was about 0.5 s when the boot was skipped by a tap, 1.9 s when it was not).
- D3. **The fill-line warning fires on every drop.** It should only warn when the pile is actually near the line.
- D4. **The left and right area indicators are missing from rounds** (173936 shows the lines; check the goals' LEFT/RIGHT zones). Restore them.
- D5 (173949). **The moon theme** that Codex added doesn't animate and doesn't match the others. Redo it like the rest of the deck backgrounds (animated, same style), or replace it.
- D6 (174812). **Results screen polish:**
  - the Star spins all the way around again in 3D, like before
  - the "WIN" / "TIDY WIN!" headline uses the old display font
  - a smoother entry animation
  - general cleanup: column spacing, the Payout list, the 20-Star wallet chip, and the Goals list readability

## H: hatch, sounds, onboarding text (Fable lane H, Edit only plus offline audio)
- H1 (174207). **Smoother transition into the hatch screen.** It's currently a bit abrupt; otherwise good.
- H2 (174207). **The Ball toy** looks odd: a red sphere with a band and a nub. Make it read clearly as a **tennis ball**: yellow-green felt and the curved white seam. Update its book cell if it changes.
- H3. **Redo all the hatch rarity sounds.** Spencer: "they suck bc they were made by codex". Fable authors new Common, Uncommon and Rare reveal sounds (and the pet one if needed) that are satisfying, cute and clearly different. They must be original: procedural or synthesized, or built from documented CC0 sources. No AI audio. Render auditions for Spencer before wiring them in.
- H4 (173809). **The Companions "How it works"** gets a 4th card about Hatch eggs: toys, finishes, colours and features come from eggs.
- H5. **Quest tickers and onboarding notices** at the top (the "✓ Hatch eggs" pill) are confusing.
  - Tapping one opens a detailed card: what it means and what to do next.
  - The first-session flow must explicitly teach where Quests and dailies are, how machines work, and how to customize the pet.

## W: world and garden (Fable lane W, Edit only plus Blender)
- W1 (174019). **World palette:** greyer marble (so the white Bear stands out), darker grass, bluer water, a darker brown dirt path, and darker, more realistic textures overall. Use the world texture and palette pipeline; re-upload the textures. Keep collision untouched unless the geometry changes.
- W2 (173828). **Park counter:**
  - Bring back "Pets are playing" with a live count, for example "Pets playing 3/9".
  - Place it **above** the Menu and Pocket Deck buttons, not to their left.
  - When the park is full, show "Park full · 9/9", and point to the other park if it has room.
- **W1 landed in source (lane W, 2026-11-15; not checked in Studio, Play was lane D's).**
  - `scripts/build_world_v7_grounded_textures.py` grades the dusk set a second time into `assets/world/textures/grounded/`: marble mid-light grey (mean 234 to about 175), grass (9,164,46) to (28,114,54), water (84,223,250) to (58,147,225), dirt path (216,165,108) to (129,93,65); rock, bark, wood, pebbles, foliage and the vertex-tinted ground map drop a step; more contrast and a faint tileable mottle everywhere. Palette props (rails, urns, `ph_white`) are unchanged: the palette PNG is a bound native input.
  - 16 Images uploaded; ids in `world-v7-uploads.json` (old file kept as `verify-W/world-v7-uploads-previous.json`). Pool and stream now use the W1_water id. `W1_waterfall_sky` and `W1_far_peak` were not re-graded (no source in the dusk set).
  - Native pack: `scripts/retexture_world_native.py` swapped ids in `TextureContent` and `ColorMapContent` and cleared the 30 compiled `TexturePackContent` entries; 123 of 126 chunks byte-identical (report `verify-W/W1-native-retexture.json`), so geometry and collision did not move. `world_native_collision.py --check` and the 12 collision tests pass.
  - Renders: `verify-W/W1-compare-*.png` (Blender, the real world mesh, before left and after right, with a white Bear stand-in on the hub marble) and `W1-swatches-before-top-after-bottom.png`. Plain sun and sky, not Roblox lighting.
  - **Coordinator, before a save:** once Rojo has synced the pack in Edit, confirm the lawn, marble and water show the new maps (if a SurfaceAppearance still shows the old colour, its compiled texture pack is stale: re-set its ColorMap in Edit), and re-check that no MeshPart's CollisionFidelity changed (a synced pack dropped one to Box on 2026-11-15).
- **W2 landed in source (lane W, 2026-11-15; spec written, not run: no Play).**
  - `src/client/ParkCounter.lua` (pure census and layout) and `ParkThrowControl.lua`: a counter pill, "Pets playing 3/9", shows while the owner is inside a park, stacked above the Menu + Deck dock on its right edge. Count = pets whose garden-snapshot `parkId` is this park (ParkDirector membership); capacity = the site's 9 slots.
  - Full: "Park full · 9/9", amber, plus a second line "The other park has room" when the other site is under 9. The server does not cap membership, so a 10th pet still joins and idles; the counter reads 9/9.
  - The Throw button moved from the dock's left to the row above the dock and now shows only when it can be pressed or the ball is out; its old disabled "Pets are playing" state is what the counter replaces (`park.waitIdle` is unused but kept).
  - Strings: `park.count`, `park.full`, `park.otherHasRoom` in UICopy (translations not synced). Spec: `scripts/ParkCounter.spec.lua` (client).

## Answered in chat / decisions
- **Move everything into eggs** (deck, customize, wardrobe, pet eggs)? Recommendation: no for v1. The Wardrobe and Deck style stay fixed-price direct buys, which are clearer and fairer and keep the paid-random rules simple. Eggs stay for collectibles (toys, finishes, hues, and Names in v2). Spencer to confirm.
- **Do pets use their toys?** Yes: they carry the equipped toy, play with it in idle beats, and the park has shared fetch.
- **v2:** **Cartridges**, different games for the Pocket Deck. Added to TODO.

## P: price pass before v1 (decided 2026-11-15; Spencer: "up to you")

- Wardrobe tiers move from 15/30/60 to **25/50/100**. Change `TIERS` in scripts/build_bear_wearables.py, then regenerate the manifest and rig, and update WearableCatalog.TierPrice. Recolours follow their base item.
- Faceplates move from 20/40/80 to **30/60/120**.
- Ball themes move from 20/40/40/120 to **30/60/60/160**.
- Eggs are unchanged. The shelf stays at 20% off.
- Update every spec that pins prices, the store-listing copy and the UICopy price strings.
- After launch, tune with the SessionEndWallet data: if the median wallet is 300+ Stars on day 7, add sinks or raise prices.

Do this **after** lanes D, H and W land, and before the publish.
