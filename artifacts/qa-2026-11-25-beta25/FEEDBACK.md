# Beta (25) feedback, Spencer 2026-11-25

Verbatim notes, then triage.

1. "the cave entrance is way too smal"
2. "theres a lot of missing faces or inverted normals etc around teh cave and stairs ramps to terrace / just a lot of messy geometry"
3. "can we make the clouds pokcet deck skin the deafult one? or a blue one? i hate the green"
4. "theres no pets playing bubble thing anymore? telling us how many pets are in the park?"
5. "the race entrance in the cave thing needs to be clearer / the model / it kinda belnds in"
6. "everything feels a little too small idk"

## Triage

| # | Lane | Cause / plan |
|---|---|---|
| 1 | Art (Fable look, Blender) + WorldFinish data | Den mouth opening sized to the old greybox; make it read as a walk-in cave from the lawn. Measure vs the avatar (5 studs) in Studio first. |
| 2 | Art | Studio audit of den shell, path, terrace: open edges, back-faces visible (Roblox MeshParts are single-sided), slivers. Fix in Blender (recalc normals outward, fill holes, close step sides, no zero-area faces), re-upload, readback. |
| 3 | Code (`DeckThemes`) | `Themes.Default="sherbet"` (Scout, green). New default: Cloud Glass (blue, the store-art hero), made a free starter so every save can equip it. The house menu palette stays as it is (DeckArt reads the default plate's glass; pin it to Scout's so menus don't shift). Saves that stored "sherbet" keep it. |
| 4 | Code (`ParkThrowControl`) | Removed on purpose in beta (17) U1 (Fable HUD look: "Remove the always-on count") after Spencer saw it hide behind the egg chip. The egg chip now lives in the top rail, so the bottom-right slot is free: show "Pets playing N/M" again whenever you're in a park. |
| 5 | Art | Garden Dash gate in the Play Den: give it a distinct silhouette, colour and light (arch, flag, lit sign) so it reads from the den door. Fable brief. |
| 6 | Art + code | Scale pass: path width, step rise, den interior, terrace, Top Lawn toys against the avatar. Fable decides the factor from Studio captures. |
