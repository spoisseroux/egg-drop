# Egg Drop

Run `rojo serve --port 34873` and connect the Rojo Studio plugin to that
port. In Play mode, drag across the rail and release to drop an egg.
Merges charge the hatch meter. The first hatch reveals Pip, and sustained
overflow ends the round with a retry button.

Generate the original sound bank with `python scripts/synth_egg_drop.py`.
To preview it in a local Studio place, copy the WAVs from `assets/audio`
into `content/sounds/egg-drop` under the active Studio installation.
For published play, import the WAVs and map their Roblox asset IDs in
`src/client/BoardAudio.lua`.

In Studio Play mode, set the `MeshPreview` attribute on the local
`PlayerGui.EggDrop` ScreenGui to compare the mesh render with the default
2D jelly render. Both use the same simulation.
