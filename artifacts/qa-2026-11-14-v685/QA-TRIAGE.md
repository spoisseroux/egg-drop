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
3. **DONE (unpublished).** **(225303) The "moon" theme.** The Moonpond background, from the Deck style background Codex added, covers the balls at the bottom of the board, which is a draw-order bug. Fix the layering; consider whether the theme should stay at all.

## U: menus and HUD

1. **DONE (unpublished).** **(225459) The notification pill** ("✓ Machines") next to Roblox's top-left buttons isn't vertically centred with them. Align it to the Roblox top bar's centre line.
2. **(225543) The Pocket menu** (six tiles) is too empty. Make it more exciting and filled out: tile art and illustrations, a live preview (for example the egg, the deck, the pet), progress chips, or a featured "this week" tile.
3. **(225611) Hatch eggs.** The inner panel's borders are still clipped: the top-left corner and the right edge of the preview frame. The left list also cuts off "Get Stars" at the bottom.
4. **(225929) Companions.**
   - The pet preview on the left is clipped by its inner panel at some points.
   - Should Toys move to their own tab in Companions? They're currently inside "Customize: Hue, charm, materials and toys". **Recommendation: yes, a fourth row, "Toys".**

## W: world

1. **(225909) Tapping the pet** is still hard at some places and angles. Widen the pick: a screen-space radius check around the pet's projected position, plus a bigger hit capsule.
2. **(230026) The lamppost** blocks the end of the first bridge. Move it off the path.
   - **Not done (2026-11-14 night).** Found: it is lamp 3, light at Studio (-9, 9, 23), 2 studs off the bridge centre line (bridge z = 21). The post is baked into the world v7 chunk meshes, so it cannot move at runtime. The fix is the existing mechanism: add lamp 3 to `LAMP_MOVES` in `scripts/build_world_v7_chunks.py` (about +4 studs in z onto the grass), move `HollowWorldLayout.Lamps[3]` with it, rebuild and re-upload the chunks. Left alone because those build scripts and the .blend hold uncommitted path-collision work.

## Carried over from the handoff (open, not raised again)

- Blip is parked (`SecondPet=false`). Spencer dislikes the alien; consider a different pet.
- The path detour around the grove park: native collision is not approved. Keep it staged; it's low priority.
- The v4 melodic music audition isn't mapped.

## Order of work

H1, then H4 (quick), then D1/D2, then D3, then U3 and U4 (clipping), then U1, then H2/H3/H5 (the new reveal, with Fable art direction and Opus implementation), then U2, then W1, then W2.

Show Spencer real captures of H1 and H2 before calling them done.

**No publish until Spencer says.** The handoff says v685 stays stable until he asks for a replacement build.
