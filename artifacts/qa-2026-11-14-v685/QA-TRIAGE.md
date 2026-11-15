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

## Before save_place (2026-11-14 late)

- **Destroy `ServerStorage.ZZ_Probe` in Edit first.** It is a temporary clone of the client and Shared folders used to run specs in Edit; Play was running when the cleanup was tried, so it is still there. Nothing else temporary was left (StarterGui and Workspace are clean).

## Stale specs (2026-11-14 late)

- `scripts/CompactPhone.spec.lua`: geometry tables regenerated from `Screen.resolve` for the 16 px shift (`b70d56b`); body top 60, board H - 96, sheets at 76; the plate overlay is expected off on phones (70e0440 hid it, the spec still wanted it drawn); new D2 determinism check. In Studio Edit (cloned client) it passes through the handheld test; the Pocket Menu case then stops at "wipe finished", a tween timing check that needs Play.
- `scripts/HatchEggsList.spec.lua` line 37: the spec was stale, the code is right. Material pool 4 (lucky Jelly) shows odds only to a player the server marks unrestricted and in random mode; a bare `{materialAvailable=true}` snapshot reads the fixed "Next" row, whose value is empty, so `value:match("%%$")` failed. The spec now asks for the unrestricted random rows (they add up to 100), and pins the Next row and the "mode not confirmed" case. In Edit it passes that test and stops later at the 3D egg templates, which need Play.
- Run in Play: `MachineHub`, `CompactPhone`, `HatchEggsList` (copies are in `src/client/ZZSpecs/`).

## Spencer on the reveal captures (2026-11-15, ~05:30)

Approved: "those sounds sound good and the hatch animations look good." Still to do before the next private build:

- R1. **Fun descriptions** for every hatch result, mostly items: toys, finishes, hue jars and features. Use the warm, quirky garden voice of the pet descriptions in PetCatalog; one line of 60 characters or fewer. Shown on the reveal.
- R2. **Exciting item previews.** On the item reveal and in the item previews, show Material and Toy results as a **rotating 3D model** like the Bear: the toy itself, and for finishes the Bear (or an egg) wearing the finish. Use a lit, coloured backdrop instead of the flat slate grey.
- R3. **Pet reveal headline.** At the tip of the slanted name/headline box there's a disconnected clear block (see `shots/10-slant-tip.png`). Clean it up so the slant is one continuous shape.
- R4. **Super smooth, satisfying transitions** into and out of the hatch screens (pet and items): no pops, a matched dim, easing, and a quick, polished exit back to the menu or garden.

## Spencer, 2026-11-15 ~06:00 (added to the 4am batch)

- R5. **Pet reveal lighting.** The Bear looks "a bit creepy" under the spotlight (`shots/12-reveal-lighting.png`). Make it more unlit and glowy, like the Bear in the garden: a soft emissive or flat-lit look with fewer dark shadows. Have the Bear **wave** on the reveal screen.
- R6. **Inspect other players' pets** (v1; scope `artifacts/pet-social-scope-2026-11-14/VISITOR-PET-SCOPE.md`).
  - **Layout:** a profile card.
    - Left: a live, spinnable 3D preview of their pet in its real appearance.
    - Right: a name slot on top, then a grid of every wearable slot showing the equipped item, or empty.
    - The name slot shows the species ("Bear") until Names ships in v2.
    - Also show bond level, owner name, and the charm, finish and toy.
  - **Say hello button:** the pet glances over and waves. The owner can turn greetings off in Settings.
  - **Access:** inspect within 12 studs by tap, click or controller.
  - **Read-only:** no rewards; nobody can change someone else's pet.
  - **Landed in source, unpublished, not yet seen in Play (agent B, 2026-11-15).**
    - Card: `src/client/PetInspect.lua` (own ScreenGui `PetInspect`, DisplayOrder 11). Left a live viewport clone of the published appearance, spun by drag or the right stick; right the species name, `{owner}'s pet · Bond level n`, a 3-column grid of all 11 wearable slots plus Charm, Finish and Toy, and **Say hello**. Desktop: 540 px wide on the right side; phone: 460 px, top centre under the top bar.
    - Access: tap or click the pet (the same forgiving screen radius as your own pet; your own pet wins a shared tap), or E / X on a small "Inspect" chip over the nearest visitor pet within 12 studs (a custom ProximityPrompt, so the owner's pet and stations keep E when they are nearer). Closes on B / Backspace / Escape, the ×, past 16 studs, any menu, focus or deck, or "Pet moved on" when the target leaves, respawns or swaps pets.
    - Hello: `src/server/PetHello.lua` + `src/shared/PetHelloRules.lua`, remote `PetHello`. The server resolves the actor, positions (7 studs, line of sight), consent and busy state itself; 1 accepted per viewer per 5 s, per target per 10 s, per pair per 30 s; requests under 0.25 s apart are dropped. No Stars, XP, quests or saves. The accepted wave rides on the owner's board (`PetHello` attribute) and every client plays it on server time (`PetHelloPose`: glance 0.25 s, two waves 0.8 s, back 0.25 s; Reduced Motion one small raise). Owner focus, carry, care, park play, a pet swap or turning greetings off withdraws it.
    - Public summary only: board attributes `PublicBond` (level of the selected pet) and `GreetingsOff`; the card reads those plus the existing `PetAppearance`. No profile, wallet or XP is broadcast.
    - Setting: Settings > "Pet greetings: On/Off" (default On), saved as the optional `greetOff` on the player profile with the same last-writer merge as Motion.
    - Specs: `scripts/PetHello.spec.lua` (server, 6 cases, pass offline in the Luau CLI) and `scripts/PetInspect.spec.lua` (client, 5 cases, not run). Not done: a per-pet highlight outline, D-pad cycling between nearby pets, item icons in the grid (names only), the localization CSV sync. Needs a two-account check (scope's acceptance plan) and a look at the card on a phone.
- R7. **Pocket Deck toy.** A tiny Pocket Deck handheld as a pet toy, in the Toy Egg pool as pool 3 (keep pool 2 and sort).
  - **Landed in source, unpublished, not yet seen in Play (agent B, 2026-11-15).** `ToyCatalog`: id `pocket_deck` ("Pocket Deck"), `PoolVersion` 3, `Pools[3]` = ball, bone, pocket_deck, sparkler, squeaky_carrot, wobble_top (sorted); pools 1 and 2 and `CatalogVersion` 1 are unchanged, so stored receipts keep validating; `PaidOrder` gets it last. `PetToyGeometry.pocket_deck`: 8 parts (cream pill shell, dark bezel, Neon mint screen, d-pad, two buttons), played with the new "tap" clip in `PetPlayVisual` (lifted to the face, button jolts, a blinking screen; still under Reduced Motion). The Toys book page lists the current pool, so its cell is there already; it draws the initial "P" until a cell is added to `book-atlas-2.png` (`BookView.Art.slots["toy:pocket_deck"]`, not done: needs art and an upload). Stale specs fixed for six toys (`ToyFeatureProgress`, `ToyFeatureHost`, `HatchEggsList`, `BookStateBits`, `PetPersonalPlay`), none run. An old server after the publish refuses pool 2 quotes from new clients and the other way round (`LegacyPurchaseClosed`): restart servers. Needs a look at the toy in a pet's hands and in the Toy Egg reveal.
- R8. **Pets always hold their equipped toy:** in their hands while idling or walking, put down only for play beats that need it. Tune it per toy.
  - **Landed in source, unpublished, not yet seen in Play (agent B, 2026-11-15).** `PetPlayVisual.renderHeld`: a second, carried prop (`HeldToy_<id>` in the pet's model, `visual.heldToy`) follows the right hand every frame while the pet idles, walks, sits or is petted; the play clip keeps its own prop and lifecycle (`visual.personalToy`, specs unchanged) and the carried one steps out of the model while a clip shows. Put down only when the pet is carried or in the care machine, on park equipment (`parkPose`), or for the shared garden toy. The holding arm stays a little raised (`holdFold`, eased). Per toy in `PetToyGeometry.Hold` (offset from the hand in body heights, turn, arm fold): sparkler upright and unlit (sparks and light only in the clip), ball hugged low in front, bone across the body, Wobble Top on the palm, carrot leaves up, Pocket Deck screen tipped to the face. World pets only; menu previews stay bare (the inspect card opts in). Spec `scripts/PetHeldToy.spec.lua` (7 cases, not run). **The offsets were set from the geometry numbers, not from a render: each toy needs a look in the hand, standing and walking.**
- R9. **Pets sit for longer:** raise PetIdleBeats SitHoldMin, roughly double it.
- R10. **Daily stamp on Hatch eggs.** The stamp card moved to Quests in QA v2 (R3.8) and stays there. Add a small stamp chip on the Hatch eggs header (today ✓, n/7) that opens Quests, so stamps are visible where you spend.
- R11. **Store icon.**
  - Layout: icon B (the garden Bear with the sparkler) holding the Pocket Deck toy, with a deck playing a round. Alternatively, B with a small Pocket Deck screen in the bottom-right corner.
  - Rebuild with `scripts/store_listing/build_store_listing_art.py` from real Studio captures. No AI art.
  - The wordmark follows the name decision. Keep "EGG DROP" unless Spencer picks another name.
  - Refresh all thumbnails from the final build.

## Name decided (Spencer, 2026-11-15)

The game is now **Pocket Pals**. Store listing title: **Pocket Pals: Pet Garden**.
- The R11 icon and thumbnail wordmarks read **POCKET PALS**.
- Update `artifacts/store-listing/LISTING.md` (name, hook, description) to match.
- Change any player-visible "Egg Drop" text in the game (UICopy, the boot/title screen) to "Pocket Pals". The internal names stay as they are: repo, folders, DataStore keys and the place name for now.
- Renaming the experience in Creator Hub happens at launch, together with the listing.
