# QA pass 2026-11-14 v2 (Spencer, phone, private v685): triage

Source: `notes.md` (copy of `obsidian-spencer/roblox qa pass nov 14 v2.md`) and 11 screenshots in `shots/`. Spencer: "i shouldnt have passed off to codex, it messed up a lot of visuals". Read `CLAUDE-HANDOFF-2026-11-14.md` for the state Codex left. **Priority is the visible UI, not pipelines.**

## H: hatch presentation (top priority, Spencer's main complaint)

1. **(225416) Pet reveal.** The new Bear hatch screen "sucks". Codex/Astra removed the Smash-style reveal (silhouette, then a name slam). **Bring the Smash-style screen back for pets only, with the egg hatch inside it.**
2. **(225745) Item hatch UI is too plain.** The egg-opening animation itself is fine, but the UI around it is lackluster: "just an egg animation opening is not enough".
   - He wants something far more exciting: Smash-like but different, or a loot-box-style reveal (rarity glow building up, a beam or colour by rarity, a card flip or burst, the item name slamming in, particles).
   - It must apply to Toy, Hue, Material and Feature items.
3. **Rarity sounds.** Each rarity needs its own sound. Revision 2 of the audio (`3eb4be4`) is unconfirmed; he only heard that Common and Rare "are the same". Rework this as part of H2, so each rarity also gets its own colour, light and particles.
4. **DONE (unpublished).** **(225718) Remove the second hatch confirmation.** Hatch eggs → a "Toy Egg / Hatch · 8 Stars" popup is a new extra step that Codex added. **Remove it.** The Hatch button in Hatch eggs already shows the price. The popup also prints the egg name twice and its info line is clipped.
5. **(225745) Toy receipt.** "Squeaky Carrot unlocked!", then Store / Give to Bear. Fold this into H2's reveal so the reveal ends with the Give/Store buttons.

## D: Pocket Deck on phone (top priority)

1. **DONE (unpublished).** **(225049) Deck sizing on first open.**
   - The handheld is too big: the top edge and the POCKET DECK logo sit under Roblox's top-left buttons.
   - On first open the player camera is visible rotating behind the deck, and the camera sits inside the avatar's head.
2. **(225303) The deck looks different on a later open.** A different scale or layout than the first open. **Use one layout every time.**
   - **Root cause found (2026-11-14 late): the two screenshots are two builds, not two layouts of one build.** 225049 shows the wordmark at (18, kh + 6) and SW - 32 wide (92 px) with the desktop plate overlay drawn on the phone (d-pad / MENU / A / B seats and the seed speaker). That is the v634 runtime (`f75cf12`, `DeckScreen.lua` lines 164-165 and 707). 225303 shows the wordmark at (24, kh + 12), SW - 48 wide (76 px) and no overlay: `70e0440`, the v685 runtime. Nothing in v685 can draw the first picture (those constants are gone), which is why it never reproduced. The first join after the publish landed on a server still running v634 (servers were not restarted after publishing v685); the rejoin two minutes later got v685. The leaf background / Moonpond difference and the camera behind the deck (D1) belong to the same split.
   - **Process fix for the coordinator:** after a publish, restart the servers ("Restart servers for updates", or shut down all servers) before phone QA, so the first join is the new build.
   - Code hardening anyway (one layout every time): every deck open (Mode -> Board) now runs the full layout again, deferred so the inset switch has landed, and once more 0.25 s later if the screen size or the top-bar keep-out moved in between. `DeckScreen` stamps what a layout was resolved from on the root (`LayoutKey`, e.g. `Compact:812x354:116:58`), and `CompactPhone.spec` now proves the phone layout is the same after a desktop pass, another phone size, another keep-out and a second pass. No column-0 local added to `init.client.lua` (still 219).
3. **DONE (unpublished).** **(225303) The "moon" theme.** The Moonpond background, from the Deck style background Codex added, covers the balls at the bottom of the board, which is a draw-order bug. Fix the layering; consider whether the theme should stay at all.

## U: menus and HUD

1. **DONE (unpublished).** **(225459) The notification pill** ("✓ Machines") next to Roblox's top-left buttons isn't vertically centred with them. Align it to the Roblox top bar's centre line.
2. **(225543) The Pocket menu** (six tiles) is too empty. Make it more exciting and filled out: tile art and illustrations, a live preview (for example the egg, the deck, the pet), progress chips, or a featured "this week" tile.
   - **Done (unpublished, 2026-11-14 late).** Each hub tile now carries a glass art well with a live picture, all from art the game already draws (`MachineHubArt.lua`, no new images): Hatch eggs = three shells (EggArt); Deck style = the mini deck in this week's shelf faceplate, else the equipped plate, or the shelf balls; Companions = the player's pet in its colours (PetPortrait) plus the shelf wearable's book cell; Quests = the stamp card as seven slots with the reward Star (3D WalletStar); Collection book = up to three owned items from the book atlas, fanned; Settings = three sliders. Locked tiles show their icon, dimmed.
   - "This week": a tile with something on the weekly shelf gets a gold THIS WEEK sticker, a gold rim on its well and the shelf item itself in the picture (the gold line was already there).
   - Progress chips: Quests "2/3 today" and "Stamp 3/7"; Book "22% found"; Hatch eggs / Deck style / Companions show owned counts from the book pages (toys, styles, outfits). Gold once complete. Strings in `UICopy` (`hub.chip.*`, `hub.week`); run the localization export before the next publish.
   - Glass style: the wells are Kit wells (dot grid) with a sheen, the tiles keep their lips, desktop tiles get the stitched seam, and the chevron is a small raised badge on the well's corner.
   - Phone 812 x 354: tiles are 252 x 105; well 76 px square on the right, name / status / line / one chip on the left, all text 12 px or more. Narrow phones (568) shrink the well to keep the name. `Hub.tileLayout` is pure and specced.
   - Checked: `scripts/MachineHub.spec.lua` (11 cases, three new) passes in Studio Edit on a cloned client at 1920 x 1080 and 812 x 354. **Not seen rendered** (Play belonged to the hatch agent): needs a look in Play on phone and PC.
3. **DONE (unpublished).** **(225611) Hatch eggs.** The inner panel's borders are still clipped: the top-left corner and the right edge of the preview frame. The left list also cuts off "Get Stars" at the bottom.
4. **DONE (unpublished).** **(225929) Companions.**
   - The pet preview on the left is clipped by its inner panel at some points.
   - Should Toys move to their own tab in Companions? They're currently inside "Customize: Hue, charm, materials and toys". **Recommendation: yes, a fourth row, "Toys".**

## W: world

1. **DONE (unpublished).** **(225909) Tapping the pet** is still hard at some places and angles. Widen the pick: a screen-space radius check around the pet's projected position, plus a bigger hit capsule.
2. **(230026) The lamppost** blocks the end of the first bridge. Move it off the path.
   - **Not done (2026-11-14 night).** Found: it is lamp 3, light at Studio (-9, 9, 23), 2 studs off the bridge centre line (bridge z = 21). The post is baked into the world v7 chunk meshes, so it cannot move at runtime. The fix is the existing mechanism: add lamp 3 to `LAMP_MOVES` in `scripts/build_world_v7_chunks.py` (about +4 studs in z onto the grass), move `HollowWorldLayout.Lamps[3]` with it, rebuild and re-upload the chunks. Left alone because those build scripts and the .blend hold uncommitted path-collision work.
   - **Done in source and in Studio Edit, native pack NOT promoted (2026-11-14 late).** `LAMP_MOVES[3] = (0, +0.15, +5)`: the lamp now stands at Studio (-9, 28) on the lawn beside the left urn, outside the bridge width; `HollowWorldLayout.Lamps[3]` is (-9, 9.15, 28). The path-collision hooks are no-ops without a reroute descriptor, so the legacy builder ran; only the `LAMP_MOVES` hunk of `build_world_v7_chunks.py` is committed.
     - Rebuild diff: exactly three merged meshes changed hash (bounds identical): `W7_Stations__marble_smooth` (solid, the post), `W7_Stations__palette` and `W7_LampOrbs__glow_warm` (both non-colliding). Walk map: only cell (-9,23) M to G and (-9,28) G to M.
     - Upload: Model 94799462047807, operation ce9e44fa-4901-4d62-9c6d-7a2c2bbf0bdd, Approved. New MeshIds: marble_smooth 125972227162285 (was 119204983359532), palette 71188520415952 (was 116040760150477), glow 111376211885197 (was 116409916215490). Written to `world-v7-studio-import.json` (one line).
     - Studio Edit: the three MeshParts in `ServerStorage.WorldAssets.WorldV7` got `ApplyMesh` with their own fidelity (marble_smooth PreciseConvexDecomposition, the other two Box); Size, CFrame and TextureID restored and checked. Probe rays on a temporary clone hit the post at z=28 and nothing at z=23. Place not saved.
     - **Left for the coordinator:** plain `build_world_v7_assets.py` refuses to write (native checkpoint guard), so it was run as `--stage-native-rebuild artifacts/qa-2026-11-14-v685/w2-lamp/staged --confirm-upload artifacts/qa-2026-11-14-v685/w2-lamp/upload-readback.json`. The staged `WorldAssets.rbxmx` differs from canonical only in those three MeshIds / InitialSizes; `WorldV7Data.lua` is byte-identical. Still to do: export `ServerStorage.WorldAssets` from Edit as the new `WorldAssetsNative.rbxm`, copy the staged `WorldAssets.rbxmx` and `world-v7-pending.json` into `assets/world/`, and re-sign `world-v7-native-collision.json`. Until then `python scripts/world_native_collision.py --check` fails and a Rojo build from the repo still mounts the old lamp meshes (with the light already at the new spot).

## Carried over from the handoff (open, not raised again)

- Blip is parked (`SecondPet=false`). Spencer dislikes the alien; consider a different pet.
- The path detour around the grove park: native collision is not approved. Keep it staged; it's low priority.
- The v4 melodic music audition isn't mapped.

## Order of work

H1, then H4 (quick), then D1/D2, then D3, then U3 and U4 (clipping), then U1, then H2/H3/H5 (the new reveal, with Fable art direction and Opus implementation), then U2, then W1, then W2.

Show Spencer real captures of H1 and H2 before calling them done.

**No publish until Spencer says.** The handoff says v685 stays stable until he asks for a replacement build.

## Stale specs (2026-11-14 late)

- `scripts/CompactPhone.spec.lua`: geometry tables regenerated from `Screen.resolve` for the 16 px shift (`b70d56b`); body top 60, board H - 96, sheets at 76; the plate overlay is expected off on phones (70e0440 hid it, the spec still wanted it drawn); new D2 determinism check. In Studio Edit (cloned client) it passes through the handheld test; the Pocket Menu case then stops at "wipe finished", a tween timing check that needs Play.
- `scripts/HatchEggsList.spec.lua` line 37: the spec was stale, the code is right. Material pool 4 (lucky Jelly) shows odds only to a player the server marks unrestricted and in random mode; a bare `{materialAvailable=true}` snapshot reads the fixed "Next" row, whose value is empty, so `value:match("%%$")` failed. The spec now asks for the unrestricted random rows (they add up to 100), and pins the Next row and the "mode not confirmed" case. In Edit it passes that test and stops later at the 3D egg templates, which need Play.
- Run in Play: `MachineHub`, `CompactPhone`, `HatchEggsList` (copies are in `src/client/ZZSpecs/`).
