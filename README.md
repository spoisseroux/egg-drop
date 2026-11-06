# Egg Drop

Run `rojo serve --port 34873` and connect the Rojo Studio plugin to that
port. In Play mode, aim with the Pocket Deck's D-pad and press A to drop.
You can also drag across the screen bar and release to drop.
On a keyboard, aim with the arrows or A/D and drop with Space.
A controller uses D-pad left/right and A.
Hatch guaranteed Pip to unlock the lounge, then play 24-drop field runs:
make tier III+ merges in the left bank patch, then the right. Successful runs
earn nectar for random egg hatches. Open **Menu → Hatch eggs** to compare exact odds and
choose a recipe. Use the pet journal to choose a companion and **Deck** to play.
Other players in the lounge can see your handheld's live display.
Menu also shows three daily contracts and four family mastery tracks. Wins and
duplicates earn marks; ranks I–III unlock companion badges and effects.
In the enlarged lounge, click a pet or use its E/controller/touch prompt to greet;
the small roaming menu hides during the close-up.
Use **Menu → Style & sound** to preview and equip a shell and sticker.
Open **Menu → Style & sound → Club** for Pocket Trials, SFX volume, and reduced motion.
Finish all three trials during regular play to earn the Club sticker.
Published servers save pet inventory, nectar, pending hatch results, personal best,
companion, trial completion, settings, and the deck's appearance. Studio
uses an in-memory profile for each play session.
Overflow or the drop budget ends a round, with time for final cascades. The recap
shows score, best chain, tier V clears and earned nectar. Choose **Try again**,
press Enter, or open **Hatch eggs**. Collection and balance carry over.
See the current [hatch-loop rundown](HATCH-LOOP.md). The
[prototype archive](PROTOTYPE.md) and [product scope](PRODUCT-SCOPE.md)
record earlier iterations and future direction.

Generate the original sound bank with `python scripts/synth_egg_drop.py`.
To preview it in a local Studio place, copy the WAVs from `assets/audio`
into `content/sounds/egg-drop-polish` under the active Studio installation.
For the private Roblox build, import the 17 WAVs through Studio's Asset
Manager under the experience owner. Map the approved IDs by cue name in
`src/client/BoardAudio.lua` and confirm each asset can load in the private
place. The client logs missing IDs and failed audio loads.

Roblox Analytics records the onboarding funnel from board ready through
first drop, first merge, and Pip's hatch. The first lounge visit and round
retry are separate counters because they can occur in either order. The
tracker starts when a player loads a save without Pip. The two counters
record once per tracked connection. Studio uses local gameplay checks
since Roblox accepts analytics events only from published servers.

In Studio Play mode, set the `MeshPreview` attribute on the local
`PlayerGui.EggDrop` ScreenGui to compare the mesh render with the default
84 × 112 pixel display. Set `PixelLCD` to false to compare the smooth
sprites. Published games need **Allow Mesh / Image APIs** for the pixel
display. The smooth sprites load if the image API is unavailable.
