# Spencer's v775 phone QA notes (2026-11-16)

Status key: [running] agent at work, [queued] next batch, [decided] Spencer's call.

1. "Tap your pet to say hi" covers "Pets are playing": remove it, move it into a guide. [running]
2. Tips at the top change on a timer and replace an open tip card. Make them calm. [running]
3. Materials missing from the Hue Egg: they were switched off for v1 by the economy cut. [decided] Pull the v1.1 Look Egg into v1 as a **Customization Egg**: hues, finishes (with stages and mixing), and charms as a rare drop. The Toy Egg stays separate and the Wardrobe stays direct-buy. [running: architect plan]
4. Charms: rare egg drop, not a default. [decided] New pets start with no charm. Snowflake, Ring and Pebble become rare drops; Heart, Star and Leaf stay earned; owned charms are kept.
5. New icons or models for the hue jars. [running: Fable, Blender, renders first]
6. The waterfall is too loud from far away (rolloff). [done in source, unpublished, not heard: InverseTapered 9 / 64 and 6 / 42 studs, silent from the lawn]
7. The Toys tab on the Companions screen is redundant with Customize. Remove it. [done in source, unpublished: three rows again]
8. Tapping a toy in the menu previews the pet playing with it. [done in source, unpublished: first tap selects and the pane's pet loops the play clip; second tap or Wear equips]
9. Pocket menu tiles should be animated instead of using sprites:
   - Companions: a pet model waving in a portrait
   - Book: animate the pink picture
   - Deck style: loop an animation
   - Hatch eggs: rotating eggs
   [done in source, unpublished: paused while the menu is closed or covered, still under Reduced Effects]
10. "Use" on an item plays an equip sound. [done in source, unpublished, not heard: equip and a different unequip, from existing cues]
11. The hatch screen's X sits too far into the top-right corner. [done in source, unpublished: 24 / 16 px inside the device safe area; real insets not seen]
12. Every button gets click audio. The Pets tab under Companions makes no sound. [done in source, unpublished, not heard: one shared helper (UIClick) and a spec that walks the menus]
13. Pocket Deck drops frames intermittently during play. [queued]
14. The seam where the ball-drop board meets the bottom of the screen needs cleaning up and rounding off; the board may sit too high. [done in source, unpublished: a rounded tray base and matching corners; the board rect did not move]
15. Darken the Pet Park textures to match the world's new darker palette (v735 world pass: greyer marble, darker grass, browner path). [done in source, unpublished: park palette graded with the v735 world numbers, new Image 86494931505767]

Batch 6 to 12, 14, 15: captures, critique and what was not verified are in `ui-batch/README.md`.

## v816 phone notes (2026-11-16, later)

16. On first play, a black popover with an X and an empty blue button sits under the Roblox menu and covers the POCKET DECK wordmark. [investigating]
17. A and B are still awkward and too far right. Use Game Boy Micro placement: a same-size diagonal pair, centred on the d-pad's height. [Fable spec, then build]
18. Toys get their own category: a Companions row, not a Customize tab. Rename Finish to **Material**. [decided]
19. The Material tab is confusing: unlabelled dots at the top, nothing to tap, and Original appears twice. Redesign it with labelled Shine and Jelly meters and a clear empty state. [Fable spec, then build]
20. The Pocket Deck still stutters on the phone. Is it server sync? It should be async. [investigating the network path]
21. The wallet 3D Star shows as a thin orange sliver in Customize, but looks fine in Companions. [check]
