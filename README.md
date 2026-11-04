# Egg Drop

Run `rojo serve --port 34873` and connect the Rojo Studio plugin to that
port. In Play mode, drag across the rail and release to drop an egg.
Merges charge the hatch meter. Hatch Pip at 6 points to unlock the lounge,
then hatch Puddle at 12 points. Meet either pet and select **Open deck** to
resume the same tray.
Other players in the lounge can see your handheld's live display.
Use **Customize** in either view to preview and equip a shell.
Published servers save pet ownership and shell choice per player. Studio
uses an in-memory profile for each play session.
Sustained overflow ends the round with a retry button. See
[the prototype rundown](PROTOTYPE.md) for the full flow and pet concepts.

Generate the original sound bank with `python scripts/synth_egg_drop.py`.
To preview it in a local Studio place, copy the WAVs from `assets/audio`
into `content/sounds/egg-drop-polish` under the active Studio installation.
For published play, import the WAVs and map their Roblox asset IDs in
`src/client/BoardAudio.lua`.

In Studio Play mode, set the `MeshPreview` attribute on the local
`PlayerGui.EggDrop` ScreenGui to compare the mesh render with the default
2D jelly render. Both use the same simulation.
