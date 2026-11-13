# QA pass 2026-11-13 (Spencer, private v583): triage

Source: `C:\Users\skunk\Documents\obsidian-spencer\roblox qa pass nov 13.md` + 18 screenshots (copied to `shots/`).
"Everything else looks good." 2-player test fine; pets never played together yet.

## Q1 Pocket Deck round + results (client)
1. Freeze 3D camera movement/rotation while the Pocket Deck is up (mouse aim rotates the camera today).
2. Remove the corner screw graphics (cut off top-left/top-right).
3. Goals panel: uneven layout; "Match ● + ● in CENTER" not vertically centred; side panels need the house personality (less "vibe coded", more fun).
4. No sound on losing a round.
5. Results Star: flashes purple then settles grey; pops in a second late; side texture looks doubled; spin not constant (resets randomly / on touch).
6. Final flourish audio cut off abruptly.
7. Waiting for the last ball to settle feels stuck: add audio + visual feedback (or finish faster).
8. Whole Pocket Deck shakes on merges (visual only; hit boxes stay).
9. Items: where magnets came from wasn't clear (power-up ball merges); items need real icons/art (Swap, Pop, Magnet, Bomb).
10. Selected tab highlight overflows the right edge in some selectors (Deck style tabs).
11. Idle hint for new players (approved): if no drop after ~6 s, an animated "aim / drop" hint; never again after the first drop.

## Q2 UI shell
1. Companions/menus: background overlays mis-sized and stacking when one opens over another.
2. Wardrobe, Customize and Collection book slide in from the right like the Pets page (consistent transitions).
3. Wardrobe cards: real previews of the items (not colour squares).
4. Faceplate (and other appearance) changes take long to save: apply instantly, save in the background.
5. Alt-tab back while in UI: cursor lost, camera captures the mouse, player stuck.
6. World music restarts on every alt-tab back in.
7. Petting: still no visible Stars from petting (investigate the award + feedback end to end).

## Q3 World
1. Stream bed: double texturing (overlapping water/bed planes); the light-blue water texture looks bad: animate the lower water instead.
2. Bottom waterfall not animated; top waterfall billboards.
3. Waterfall foam: more fun (more particles), and its bottom has inverted normals.
4. Distant castle flags: lighting glitches when moving; make them wave. Clouds slowly bob.
5. Turn the bloom down.
6. You can still walk off the world (perimeter walls: missing or inverted normals); cliff-edge normals messed up.
7. Lamp posts sit in the middle of paths: move them to the edges. Bridges must meet the paths directly.
8. Marble river-bed lining: uncapped / disconnected segments.
9. Hub: remove the two benches and the toy-lawn toys by the hub (keep the picnic table at the back).
10. Pocket Deck customization station model still has the joysticks on top: remove them.

## Q4 Pet Park
1. Benches face outward: face inward. Keep only the bench by the entrance (cull the others) and give it 5 seats.
2. A floating indicator over the park like the machines have.
3. Walking into the park, the pet stayed away until the owner walked back toward it: the pet should come into the park.
4. Models flipped: pets go UP the slide and DOWN the ladder; check every equipment orientation vs poses.
5. Pets never played together in the 2-account test: investigate duo matching live.

## Open (Spencer's questions, answered in chat; build after he decides)
- Pocket menu as a hub for the machines? Is the quest log needed? Move the book out of the Care machine? Stamps need visual assets. Onboarding still to build.
- Results "Next egg" strip: replace with a daily Stars cap meter? (No daily cap exists today.)

## Q5 Machine hub (Spencer approved 2026-11-13: "Yes, machine hub") — starts after Q1 + Q2 land
- The Pocket menu becomes one hub outside rounds: a tile per machine (Hatch eggs, Deck style, Companions), plus Quests, Collection book, Settings. During a round it stays a pause menu (Resume, Restart, Quit, Settings).
- Pocket Trials retired (quests + the book cover it). The Quest log stops being its own entry point: Quests is a hub tile; the deck's daily-quest panel and the results strip keep showing progress.
- Collection book moves out of the Care machine (Companions hub row removed) into the hub.
- Stamp card gets real stamp art (Astra).
- Results strip: "Next egg" meter replaced by "Today: ★ earned" beside the daily quest (no daily Star cap; revisit with telemetry).
- Onboarding (full) still to build after this; the idle drop hint ships in Q1.
