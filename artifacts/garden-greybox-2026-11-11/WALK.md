# Greybox walk test — 2026-11-11

Studio Play, R15 avatar (WalkSpeed 16, JumpHeight 7.2), teleported to `GreyboxSpawn`. The handheld UI was hidden locally for the walk because a fresh save starts in Board mode.

| Route | Result |
|---|---|
| Spawn → low terrace via east ramp (8 studs) | Pass (pathfinding walked it) |
| Low terrace → high terrace via ramp (16 studs) | Pass |
| Spawn lawn → across the creek → west lawn | Pass. The creek is only 2 studs deep, so it is not a barrier; the bridge is optional. |
| Stepping pillars → lookout ledge | **Failed first version** (7-stud pillars, 9 apart: only pillar 1 reachable). Fixed to 10-stud tops, 1-stud gaps, 3.5-stud rises: all 5 pillars and the 21-stud ledge reached, 1–2 jumps each. |

Findings for the art pass:
- Terraces read poorly from above: same green as the floor with no edge. Give terrace lips a darker or rocky trim.
- The high terrace and the pillar ledge are good lookouts: both show the whole garden and the sea.
- In Board mode Space is the Drop key, so jumping in the garden must not depend on the board being open (it isn't in Room mode; noted because the walk started in Board mode).

Not tested: phone camera framing, Room-mode spawn into the greybox, pets walking it (path data not rebuilt yet).
