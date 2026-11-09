# Egg Drop — garden companions, Stars and Hue Eggs

**Private v241 Published — Stars and Hue Eggs - 7145db9**, verified in refreshed Studio Version History after tests, reviewed commit and push. [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · [Publication proof](artifacts/hue-eggs-2026-11-08/private-published-v241-7145db9.png) · [Hue gallery](artifacts/hue-eggs-2026-11-08/GALLERY.md).

Previous checkpoint: **private v232 — Softer babies and smooth movement - 355fad7**, confirmed in refreshed Studio Version History after tests, commit and push. [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · [Publication proof](artifacts/pet-softening-2026-11-08/private-published-v232-355fad7.png). This supersedes private v225. Nursery, paid products and public release remain deferred.

The latest pass softens Zivvi and Ovelle into neutral porcelain/pebble babies, replaces Ovelle's suspended arms with attached mittens, and adds seeded blinks, breathing, slow gaze and a softly independent Dot bounce. Shared follow paths ease through turns and braking. The PocketDeck backdrop is stronger, its A-adjacent caption is removed, and both bank overlays sit behind the jelly colors. **114 unique native client /98 isolated server checks passed**, alongside actual desktop/phone-emulator controls and a two-client Studio session with saved charm propagation and leave cleanup. [Current screenshots](artifacts/pet-softening-2026-11-08/GALLERY.md) · [Exact evidence and live movement limits](artifacts/pet-softening-2026-11-08/BUILD-EVIDENCE.md).

The repository now includes the accepted handheld, shared palette, recap and hatch polish, plus Astra's first two authored baby pets, implemented by Sol. **Zivvi replaces Pip's common visual/name; Ovelle replaces Puddle's.** Their original stored IDs remain stable, preserving earned ownership and pending receipts. The other five visuals are temporary legacy pets. Stars and Hue Eggs are now implemented. The remaining new base forms, random item pools and broader garden redesign remain planned.

Companions can investigate and shove the shared wobble toy, rest, and greet a nearby pet. A saved per-pet control hides/shows the secondary-colored dot. A visitor can see a player holding the physical deck with their pet resting nearby. Focus preempts autonomy; petting remains the existing server-validated saved reward path. Actual two-client controls verified shared actions, charm propagation and leaving cleanup without idle currency awards.

[Current garden gallery](artifacts/garden-vertical-2026-11-08/GALLERY.md) · [Exact garden tests](artifacts/garden-vertical-2026-11-08/BUILD-EVIDENCE.md) · [Garden slice and boundaries](GARDEN-VERTICAL-SLICE.md). The sections below describe the current arcade/economy rules. Stars are the existing wallet renamed one-for-one; internal compatibility storage still uses nectar.

## Hue Eggs and Stars

Menu → Hatch eggs → Hue Eggs shows matching Current/After previews. Choose an owned Zivvi/Ovelle and a hue, then explicitly Feed for8Stars. Purchase advances body grade and unlocks accents; it preserves the previous accent selection. Colors lets you choose Original or learned bodies and accents separately without spending. Grades use subtle12/23/35percent linear-light blends.

145unique Largest client cases and59isolated server cases passed;60Medium checks repeated successfully. Actual desktop earned purchases, duplicate-click single charging, independent free selections, fresh phone-emulator swipe/earn route and actual two-client same-rig palette propagation passed. Physical phone, private-client rejoin and live latency remain unverified. [Hue screenshots](artifacts/hue-eggs-2026-11-08/GALLERY.md) · [Exact Hue evidence](artifacts/hue-eggs-2026-11-08/BUILD-EVIDENCE.md).

## What changed

- Larger Sprout Hollow: the112×96 footprint is now160×128, with an east lantern boardwalk/pool overlook and a west orchard loop. Eight new lanterns, water ripples, drifting leaves and evening fireflies animate the walks. Existing hatch tree, journal and workbench retain their fast menu shortcuts.
- Pocket Deck: lower inset instruments, rounded pixel LCD, compact animated supply meter, subtle symmetric banks and brighter fixed-light procedural jelly. Chain/merge/impact effects and accepted-action synth ticks are pooled and respect sound/motion settings. The liked Pocket Apricot music stays the default. Three more energetic original music/cue drafts are saved locally for later listening; they are not uploaded or substituted.
- Consistent shell/menu/LCD palettes; immediate unlocked style/sticker selection; large right-faceplate printed emblems. Shell, Stickers and Background are separate choices; Settings and Pocket Trials have their own menu entries. No redundant Resume/Equip button.
- Three field variations rotate: Bank Pair, Creek Crossing and Lantern Chain. Coaching names the actual tier/area/progress. Bank and Creek reward placement under tested solver policies; Lantern is deliberately the forgiving chain variation.
- Compact animated recap: exact earned Stars first, concise breakdown and egg progress; full score/chain/mastery details behind Details. An unfinished outing survives a lounge visit; returning after a completed saved outing starts a fresh field. Reconnect does not preserve an unfinished physical board.
- Companions bob gently while following, stop their gait at rest and remain easier to read at night. Tap a pet to focus; rub it or hold E/X for purrs and a reaction every3–5 seconds. Back ends focus. Continuous eligible petting has a50% opportunity after12 seconds, repeating at least12 seconds apart, for saved+1 Stars up to5 per Hollow day. Mute/reduced effects keep reward eligibility. No reward for idle focus or a fabricated client claim.

## A first session

1. Aim and merge on the welcome board to earn guaranteed Zivvi, then Meet and Back to explore Hollow.
2. Open the deck. You have24 drops **per round**, with unlimited rounds. Aim for the active goal and keep the pile low; impatient center spam can overflow and fail.
3. Complete both goals for6Stars, or8with the low-pile bonus. A completed failed round can still earn its eligible skill contracts. The recap shows exact saved earnings and distance to the selected egg.
4. Browse the hatch tree or Menu → Hatch eggs. Mixed Meadow costs18Stars; Sprout Focused costs24. Choosing or entering a station never spends; the explicit Hatch action does. Outcomes are random from displayed odds. Closing a purchased reveal preserves it until Meet; reopening cannot reroll it.
5. Meet/equip a companion, work toward family mastery and trials, choose earned cosmetics, and try the next field variation.

## Rewards and return goals

Seven current catalog entries: porcelain/rose Zivvi and cool-stone/sage Ovelle; temporary legacy orange flame Wick, lavender ringed Orbit, rare peach flower Bloom Pip, blue/turquoise Foxfire Wick and violet/gold Eclipse Orbit. Meadow odds35/25/20/10/5/3/2%; Focused Zivvi80/Bloom20%. Seven consecutive non-rare hatches make the next rare-only; this does not guarantee an unowned common. Duplicates add one family mark. Hue Eggs now offer Rose, Tide, Citrus and Iris for Zivvi/Ovelle at8Stars per grade, capped atIII. Each first grade unlocks its independent secondary; Original/learned body and Default/learned accents select free, with optional Dot preserved. Other catalog entries retain temporary legacy visuals.

Wins add1mark, clean wins2. Family ranks: I Sprout at3marks, II Grove at10, III Bloom at25 plus all three saved skill conditions (clean win, chain3, score500). Crests/effects progress with rank. The existing optional daily gift is6Stars; contracts are Win2+4, Chain3+3, Score500+3, automatically awarded through valid full rounds. New players start with6 instead of an extra first-day gift. Daily rollover is the Hollow's fixed05:00UTC boundary, not device time or DST. No daily play cap or paid luck.

Earned cosmetics: Honey shell after1saved win; Gloaming at any owned rankI; Copperleaf and Lantern background at rankII. Creek background comes from High Roller250points; Lantern stamp from Triple Pop chain3. Existing free finishes/prints remain; Wick print requires Wick, Trial crest requires the three trials. Locked previews show their real condition and never equip themselves.

## Prior published v180 verification and limits

Final:81runtime sources matched/compiled, Rojo build and diff check passed. Companion client61 and isolated server69 passed; completed/live-return regression21 passed. Earlier slices have their own named layout, appearance, solver, audio and lifecycle suites in the evidence. These repeats are not summed as new coverage.

Actual final controls completed welcome → Pip →24-drop Bank660/chain4 →Saved+12 wallet6→18 →18Meadow Wick →X/reopen sameID/revision →Meet →Back →fresh Creek0/24 with no old recap. Actual foreground29-second petting saved two+1 awards with one purr voice; emulated touch, muted/reduced eligibility, same-finger leave/reentry and window interruption were checked. Source-rendered seven-pet night lineup is a lighting/rig fixture, not seven owned/live peers.

288 production-solver comparisons included72 fast-center rounds, all overflowed and won0; objective-aware policy won24/24 for each template. Nine legal winning traces replayed exactly. These are automated policies, not proof of human difficulty, fun or retention. A rejected lateral-chain experiment is retained as nonshipping evidence.

Short final desktop Room sample:180frames after30warm-up, p95 17.850ms, no new Room node growth; existing62-node arcade FX benchmarks stayed pooled. Engine playback events verify sound ownership/loading/looping, not an audible mix/seam judgment. Optional EditableImage remains unavailable under unchanged settings; tested native GUI spans render the LCD. Known external asset203785492 warnings remain.

Still needed: your physical-phone comfort/performance check, live multiplayer, actual private-client save/rejoin and longer human play/balance/audio testing. This is a private playable prototype, not a production-readiness or proven-retention claim.

[Before/after gallery](artifacts/living-world-2026-11-07/GALLERY.md) · [Exact build/test notes](artifacts/living-world-2026-11-07/BUILD-EVIDENCE.md) · [Accepted design and boundaries](LIVING-WORLD-AND-ARCADE-PASS.md) · [Full economy/save rules](HATCH-LOOP.md).

## Simple layout edits

Tune small layout values in `src/client/DeckLayout.lua` Settings; `src/shared/DeckThemes.lua` holds palettes and `src/client/DeckArt.lua` shared design roles. Restart Play after changes and inspect desktop plus phone emulation. Dragging generated UI during Play is temporary; source/Rojo is the saved version. Keep44px input targets and screen clearance.
