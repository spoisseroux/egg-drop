# Egg Drop

Run `rojo serve --port 34873` and connect the Rojo Studio plugin to that
port. In Play mode, aim with the Pocket Deck's D-pad and press A to drop.
You can also drag across the screen bar and release to drop.
On a keyboard, aim with the arrows or A/D and drop with Space.
A controller uses D-pad left/right and A.
Merges earn score and hatch charge. Hatch Pip to unlock the lounge, then
work toward Puddle, Wick, and Orbit. Use the pet journal to choose a
companion and **Open deck** to resume the same tray.
Other players in the lounge can see your handheld's live display.
Use **Customize** in either view to preview and equip a shell and sticker.
Open **Customize → Club** for Pocket Trials, SFX volume, and reduced motion.
Finish all three trials during regular play to earn the Club sticker.
Published servers save pet ownership, hatch charge, personal best,
companion, trial completion, settings, and the deck's appearance. Studio
uses an in-memory profile for each play session.
Sustained overflow ends the round. The recap shows score, best chain,
tier V clears, and the next hatch. Choose **Try again** or press Enter
to start a fresh tray. Hatch charge and collection progress carry over. See the
[prototype rundown](PROTOTYPE.md) and [product scope](PRODUCT-SCOPE.md).

Generate the original sound bank with `python scripts/synth_egg_drop.py`.
To preview it in a local Studio place, copy the WAVs from `assets/audio`
into `content/sounds/egg-drop-polish` under the active Studio installation.
For published play, import the WAVs and map their Roblox asset IDs in
`src/client/BoardAudio.lua`.

In Studio Play mode, set the `MeshPreview` attribute on the local
`PlayerGui.EggDrop` ScreenGui to compare the mesh render with the default
84 × 112 pixel display. Set `PixelLCD` to false to compare the smooth
sprites. Published games need **Allow Mesh / Image APIs** for the pixel
display. The smooth sprites load if the image API is unavailable.
