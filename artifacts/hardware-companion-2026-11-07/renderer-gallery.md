# Pixel renderer checkpoint

Accepted runtime on the existing Egg Drop branch. These are Studio captures, not a physical handset or live multiplayer session. Menus, companion scale, station height and music playback remain queued for later slices.

| Evidence | What it establishes |
| --- | --- |
| [Earlier smooth GUI board](hardware-largest-field-desktop.jpg) | Earlier hardware checkpoint; different field/run state. |
| [64 vs 84 cells](renderer-64-84-phone-size-shape-fixture.jpg) | Explicit static 172×289 shape comparison used to choose the lower-cost square-cell grid. Lighting was still the prototype. |
| [Fixed-light angle fixture](renderer-fixed-light-angle-fixture.jpg) | Static 0°/45°/90° comparison of both final pixel and emergency stepped renderers. No profile or physics changes. |
| [Largest field, halfway](renderer-largest-field-halfway.jpg) | Actual field at 12 drops with an earned tier V, upright mark and active RIGHT quest. |
| [Largest pressure fixture](renderer-largest-pressure-fixture.jpg) | Client-local pressure .65 visual check; restored immediately. Contrasting warning text and threshold are visible. This did not earn or consume anything. |
| [Round receipt](renderer-largest-round-receipt.jpg) | Actual 24-control round: 680 score, 12 nectar saved once, balance 18. Aim positions were solver-assisted. |
| [Largest native phone A](renderer-largest-native-phone-after-a.jpg) | Native Studio phone-emulator button accepted one drop. Before the final row-clipping correction. |
| [Seams before correction](renderer-medium-native-phone.jpg) | Thin seams in phone-emulator row clipping; retained as diagnosed before evidence. |
| [Final fresh phone run](renderer-medium-native-phone-final.jpg) | Normal production constructor selects pooled pixels with current settings; continuous rims after removing redundant row clipping. |

The final pixel pool has 1536 dynamic slots, 209 static rectangles and 107 row hosts, plus root/stash. Peak benchmark demand was 903; no instances were created after warmup. On the Studio phone profile, paint p95 was 0.303/5.049/1.618/3.657 ms for idle/falling/pile/merge. Whole-client frame p95 was about 18 ms and includes Studio. The full pixel material costs more CPU than the original smooth GUI. The approximately 32% reduction was against the 84-cell pixel prototype, not the original GUI. See the JSON benchmark files and [native results](../../scripts/JellyRenderer-results.json).

Native QA caught allocation-success/write-denial, covered overflow graphics and phone clipping seams. The final source passed targeted retests after each fix. Medium preference was restored. Physical handset performance, multiplayer and live-account rejoin remain untested.
