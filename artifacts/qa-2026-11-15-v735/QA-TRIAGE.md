# QA pass 2026-11-15 (Spencer, phone, private v735): triage

Source: `notes.md` and `shots/` (filenames are timestamps). Spencer: "after we do all this we're really close to pushing v1". Fable owns the visuals, the sounds and the debugging.

## D: Pocket Deck (Fable lane D, owns Studio Play)
- D1 (173720, 173936). **The deck is still the wrong size on phone, even after the first round.** The handheld's top sits under Roblox's buttons and its bottom runs off screen (the MENU and Items labels touch the edge).
  - Find the real root cause: what scales the shell, and when the safe area and inset arrive.
  - Make it fit **both** width and height inside the safe area every time, with one deterministic layout function on every open and on every viewport or inset change.
  - Add a spec that checks the shell fits at 812x354, 844x390, 926x428 and a tablet size, including after a second open.
- D2 (174105). **Opening and closing the deck is abrupt.**
  - A full-screen overlay and a smaller overlay pop in, then animate roughly.
  - The power-on animation sometimes cuts off before it finishes.
  - Make the transition one smooth, satisfying motion (the shade fades in, the handheld rises and settles, the screen powers on fully every time), and the reverse on close.
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

## Answered in chat / decisions
- **Move everything into eggs** (deck, customize, wardrobe, pet eggs)? Recommendation: no for v1. The Wardrobe and Deck style stay fixed-price direct buys, which are clearer and fairer and keep the paid-random rules simple. Eggs stay for collectibles (toys, finishes, hues, and Names in v2). Spencer to confirm.
- **Do pets use their toys?** Yes: they carry the equipped toy, play with it in idle beats, and the park has shared fetch.
- **v2:** **Cartridges**, different games for the Pocket Deck. Added to TODO.
