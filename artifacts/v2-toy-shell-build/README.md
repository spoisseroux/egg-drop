# Toy Shell restyle, Studio captures (2026-11-19, Sol)

Studio Play on the dev place, not a phone. `844x390` files are the live screen hosts forced to
844x390 with the keep-out pinned to 116x58, cropped from the Studio capture. `desktop` files are
the full 1649x734 Studio viewport. The suffix is the equipped Pocket Deck (Scout `sherbet`, Creek
`ice`, Ember `brick`) or `classic` (Settings > Menu colours: Classic Shell).

| # | Screen | Before | After |
|---|---|---|---|
| 01 | Pocket Deck round HUD | before-01-* | after-01-* (Scout) |
| 02 | Customize, Hue | before-02-* | after-02-* (Scout, Creek, Ember, Classic) |
| 03 | Pocket menu (hub) | before-03-* | after-03-* (Scout, Creek, Ember, Classic) |
| 04 | Companions | before-04-* | after-04-* |
| 05 | Stats panel | before-05-* | after-05-* |
| 06 | Hatch eggs (egg shop) | before-06-* | after-06-* (Scout desktop, Ember phone) |
| 07 | Stat Egg card | before-07-* | after-07-* (Scout desktop, Ember phone) |
| 08 | Round results | before-08 (from artifacts/v2-s3-stats-ui) | after-08-* |
| 09 | Inspect card | before-09 (FIXTURE, from artifacts/v2-s4-inspect-stats) | after-09 FIXTURE |

Notes:
- **FIXTURE (09):** the real `PetInspect:build` card on the local player's own board (inspecting
  needs a second account). Its preview stage is empty because the fixture spawns no pet.
- The 04 and 05 "after" captures were taken before two late fixes: the stat detail name is now
  white (Heart pink measured 4.3:1 on a tray) and companion row outlines are always ink.
- Body-text contrast was measured in Studio on every visible label (nearest opaque surface):
  hub 6.16, Companions 6.16, results 5.99 minimum. The probe's lower readings were false
  positives (a title on its sibling plate, ink on a sibling HUD tab or sticker face). All 19
  palettes x 18 text pairs pass WCAG AA 4.5:1 by computation (worst: soft text on the Canopy
  shell, 4.66; disabled keys 3.42 by design).
- The moving checker was checked numerically: one tween per sheet, only the visible sheet runs,
  it rests at offset 0 under Reduced Motion / Motion: Low, and it stays inside the rounded corners
  (rectangular clip inset `ceil(r * 0.293)`; the step-0 spike showed `ClipsDescendants` ignores
  `UICorner` and a tiled ImageLabel ignores `ImageRectSize`).
