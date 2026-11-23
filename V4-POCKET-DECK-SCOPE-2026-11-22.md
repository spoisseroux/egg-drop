# Pocket Pals v4 scope: the Pocket Deck update (cartridges)

**Status: scope for approval, 2026-11-22 (Fable). Nothing here is built or approved.** No code, save, Studio place or listing was changed. Every number marked [P] is a placeholder. Opus architects the framework (section 4) after Spencer answers section 6.

Spencer, 2026-11-22: "for v4 i want to make it the pocket deck update, i wanna add games, like game cartridges."

Read for this pass: `GAME-DESIGN.md`, `PROTOTYPE.md`, `V3-SCOPE-2026-11-21.md` (sections 2, 4, 6), `V2-PINBALL.md`, `DeckThemes.lua`, `DeckJuiceCatalog.lua`, `DashStats.lua`, `SimCheck.lua`, `client-sim-plan.md`, `StatCatalog.lua`, and one deck capture (`artifacts/qa-2026-11-13/studio/deck-idle-hint.jpg`). I did not open Studio or play a build for this.

---

## 1. The idea

The Pocket Deck stops being one game and becomes a little console. Each game is a **cartridge**: a chunky, rounded plastic cart with a pixel label, which you slot into the top of the deck with a click. The merge game you play today becomes cartridge number one, **Egg Drop**, free and already in the slot, so nobody loses anything. New carts are collected the same ways everything else is: **earned** (finish a trial, reach a level), **bought for a fixed Stars price**, or **level gated** like faceplates and juice. A cart is never inside an egg, never a random prize and never Robux-only. On the deck: the MENU button gets a **Carts** shelf; picking one plays a short swap (old cart pops out, new one clicks in, boot wordmark, the cart's own title card). In the world: the cart's label pokes out of the top of your deck while you play, so other players can see what you are playing, and a **cartridge shelf** at the deck's spot in the garden shows the whole set, with the ones you do not own as grey outlines that say how to get them.

## 2. Why the named games are out, and what we make instead

Pokémon Pinball, Balatro, Nintendo's NES games, Tetris and Candy Crush belong to other companies. A decompiled game is still their code, and a reskin still carries their table layout, their rules, their level designs and their names. Shipping that on Roblox gets the experience taken down and can cost the account, and it is not ours anyway. (`V2-PINBALL.md` describes the pinball idea in those terms; this document replaces it.) What nobody owns is the **genre**: flippers and a ball, scoring with a hand of cards, blocks that fall, swapping things to match. So every cart below is built from nothing: our code, our layouts, our rules, our pets, our names, our hand-made art and sound. No generated art or audio.

| Spencer named | Out because | Our original |
|---|---|---|
| Pokémon Pinball R/S, decompiled | Their code, tables, creatures, catch mode | **Moonpond Pinball** (3.1) |
| A Balatro clone | Their rules, poker-hand scoring, jokers, look | **Picnic Pals** (3.2) |
| Tetris | Their pieces-and-lines design and trade dress | **Hop Stack** (3.3) |
| A Candy Crush type | Their levels, boosters, look | **Jelly Shuffle** (3.4) |
| NES games from Animal Crossing | Real Nintendo games | **Lime Time**, **Echo Chimes** (3.5) |

All names are working titles and need a quick search for clashes before any is shown to players.

## 3. The cartridges

Stats follow Garden Dash (`DashStats`): each stat has one job, a straight line from level 1 to 99, whole numbers. Dash gives 25% at 99; carts give **at most 15% [P]**, because a score board is less forgiving than a race band. Hands always beat stats.

### 3.1 Moonpond Pinball (the headline)

**Pitch:** a pinball table set on the Moonpond at night, where you warm eggs, hatch babies and walk them home.

**Core loop:** launch the ball (a jelly ball with a face, from Egg Drop), keep it alive with two flippers, light things in sets to start modes, bank a bonus when the ball drains. Three balls a game.

**Controls:** left side of the screen or D-pad left = left flipper, A or right side = right flipper, B = **Hop** (our nudge: the whole table does a small bounce, limited uses). Hold A to pull the launcher.

**Table layout ideas (one table, bottom to top):**
- **The Dock (bottom):** two flippers shaped like lily-pad paddles, two slingshots as bouncy toadstools, inlanes and outlanes as reed channels. A **Bunny Burrow** kickback on the left outlane and a **Bear Paw** save post in the middle, both off until earned.
- **The Lawn (middle):** three **Puffbug** bumpers in a triangle. Puffbugs are round garden critters who puff up, bounce the ball off their bellies and giggle; each hit makes them rounder until all three pop into a shower and reset. A row of four **Sleepy Sprout** drop targets: each hit wakes one (it stands up and waves); wake all four to light a lane.
- **The Stream (left):** a curved orbit that carries the ball round the back as if on water. Repeated orbits raise the **Tide** (the bonus multiplier, up to 5 [P]).
- **The Lime Tree (right):** a ramp up the trunk. Each ramp shot shakes a lime loose; limes roll down the lawn as moving bonus targets.
- **The Nest (top centre):** a bowl with three rollover lanes above it (Sun, Moon, Star). This is where eggs arrive.
- **The Burrow (top left):** a saucer hole. It starts modes and is "home".
- **The Stepping Stones (top right):** five standup targets over the pond, lit in order for the Garden Hour.

**Modes:**
1. **Hatch (ours, the centre of the game).** Light Sun, Moon and Star (the flippers rotate which lanes are lit) and an egg rolls into the Nest. Now **warm** it: every shot that passes the Nest adds warmth, and Puffbug hits add a little. The egg wobbles, cracks and hatches into a pixel baby, which sits up in the Nest. You never hit a pet with the ball.
2. **Walk Home.** The baby toddles from the Nest toward the Burrow along a path of lanterns. It only walks while the lantern in front of it is lit, and you light lanterns by making the shot each one points at (stream, ramp, a sprout). Nothing is aimed at the baby; if the ball rolls near, it ducks and laughs. Get it home before the timer and it is **tucked in**: it joins your **Nursery row** on the side panel for this game and gives a helper. Run out of time and it naps where it is; the next hatch picks it up.
3. **Helpers.** Each tucked-in baby switches one thing on for the rest of the game: Bunny = the Burrow kickback, Bear = the Paw save, later pets = their own (a magnet lane, a second Hop).
4. **Puff Party:** pop all three Puffbugs twice for a 20 second frenzy where every bumper hit scores triple.
5. **Lime Rain:** five ramp shots; the tree drops limes for 20 seconds, each one a rolling target.
6. **Garden Hour (wizard mode):** tuck in three babies in one game. The table goes to dawn, the music opens up, two extra balls launch and every shot is lit for 40 seconds.

**Why it is not their game:** no creature is caught, thrown at or hit; there is no reel or slot of any kind; no evolution, no travel between areas, no map. The loop is care (warm, walk, tuck in), which is what Pocket Pals is.

**Stats [P]:** Power = flipper strength (+0 to 15%). Energy = ball-save seconds at launch (4 to 6). Jump = Hops a ball (2 to 3). Speed = how fast the baby walks home. Smarts = mode timer length. Heart = warmth an egg needs (less at high levels).

**Session:** 3 to 6 minutes. A quick-play "one ball" option for phones [P].

**Build size: L.** Risks, plainly: (a) the sim must be a fixed-step, whole-number ball, flipper and curve physics so the server can replay it; `BoardSim` gives the pattern but not the flippers or ramps. (b) The deck's centre well is small on a phone; see question 4. (c) Pinball lives or dies on feel, so it needs a greybox table that Spencer flips before any art.

**Art and audio:** one table painting in the deck's pixel style, in layers (playfield, ramp, overlays, a dawn recolour); sprite sheets for Puffbugs, Sprouts, eggs, two babies (walk, duck, sleep), lanterns, limes; a dot-style banner area for mode names. Sounds: flipper, 3 bumper pitches, targets, ramp, hatch, tuck-in, drain, Hop, plus one music loop with a livelier Garden Hour layer. About 25 sounds.

### 3.2 Picnic Pals (card-scoring run)

**Pitch:** lay snack cards on a picnic blanket to feed a queue of hungry pets, and build a better hamper as you go.

**Core loop:** a run is one picnic of **six guests** who arrive one at a time. Each guest has an **appetite** (a score to reach) and three **servings**. You hold seven snack cards and lay up to five as a **plate**; the plate scores **Yum x Cheer**. Reach the appetite and the guest leaves happy; fail and the picnic ends. Between guests you take **one of three hamper upgrades shown face up** (free, no currency in the run, no odds).

**How it stays clearly not Balatro:**
- **No playing cards.** No suits, no ranks, no face cards. Snack cards have a **flavour** (Sweet, Crunchy, Juicy, Leafy, Zesty) and a **size** (crumb, bite, slice, feast).
- **No poker hands by name or by rule.** Plates are our **recipes**: Fruit Salad (all different flavours), Sandwich (same flavour on both ends), Tower (sizes in rising order), Feast (all one flavour), Sharing Plate (two pairs of matching size). Recipe names appear with a small picture of the dish.
- **No jokers.** The modifier is the **guest**: each has a craving ("Leafy counts double", "the smallest card scores twice", "hates Zesty"). Guests are the round, they leave when fed, and you never own or stack them. Lasting upgrades are **hamper items** (a bigger blanket, a jam jar that changes one card's flavour) and are few.
- **No chips, stakes, antes, blinds, money or shop.** Nothing is bet. The look is a gingham blanket and stickers, not felt and neon.

**Stats [P]:** Smarts = one free re-deal a guest at level 25, two at 75. Heart = first guest's appetite a little lower. Others unused.

**Session:** 5 to 8 minutes; saves between guests so a child can stop.

**Ours because:** it is feeding pets, the thing players already do in the garden, and the guests are the roster.

**Build size: M to L.** The rules are simple to replay (turn based, seeded); the cost is content and balance: about 40 snack cards, 18 guests' cravings, 15 hamper items.

**Art and audio:** card frame, 20 snack icons (the live snack art can be redrawn as pixels), guest portraits with happy and grumpy faces, blanket, about 15 sounds, a calm loop.

### 3.3 Hop Stack (falling blocks, with a climber)

**Pitch:** build stairs out of falling pebble clumps so your pet can climb out before the pond rises.

**Core loop:** clumps of 2 to 4 rounded pebbles fall into a well 8 wide. **Your pet stands on the stack** and walks by itself; it can step up one block. A star hangs higher up the well. Build a path it can climb, it grabs the star, the view scrolls up and a new star appears. The **tide** rises from the bottom; if it reaches the pet, the run ends (the pet floats off in a rubber ring, not hurt).

**The twist, and why it is not Tetris:** there are **no line clears at all**. Full rows do nothing. You are building a staircase, not erasing one, so neat flat rows are bad play. Pieces cannot land on the pet (it hops aside), and a clump dropped beside it can lift it.

**Stats [P]:** Jump = the pet can step up two at level 50. Speed = pet walk speed. Energy = a few seconds of "hold the tide" on B.

**Session:** 2 to 4 minutes. **Build size: M.** Grid sim, easy to replay. **Art and audio:** pebble tiles in 4 colours, the pet in 6 small poses, water, stars, about 12 sounds, a loop that speeds up with the tide.

### 3.4 Jelly Shuffle (match and merge)

**Pitch:** slide rows of jellies so three touch and squish into a bigger one, and serve the pet what it orders.

**Core loop:** a 6 x 6 board of Egg Drop's jellies. You do not swap two pieces: you **slide a whole row or column**, and it wraps round the edge. Three or more of the same tier touching **merge into one of the next tier** where you moved. Your pet sits beside the board with an **order card** ("two tier III, one tier V"). Fill orders to earn moves; the run ends when moves run out.

**Why it is not Candy Crush:** no swapping, no level map, no lives, no timers that sell refills, no boosters for sale, no sweets. It is the merge ladder players already know from Egg Drop, on a grid.

**Stats [P]:** Smarts = a hint glow after a pause. Power = the first merge each order counts double toward it. Heart = one extra starting move per 33 levels.

**Session:** 3 to 5 minutes. **Build size: M** (small M: the jellies and merge sounds exist). **Art and audio:** board, order cards, the pet's waiting and happy poses; reuses jelly sprites and pops.

### 3.5 Two tiny carts (our own 8-bit style minigames)

- **Lime Time. Size S.** One screen, 60 seconds. Your pet runs left and right under the lime tree and catches falling limes in a basket; leaves drift down as fakes, and a golden lime bounces once. Speed = run speed, Jump = a hop to reach a high lime. Art: tree, pet in 3 poses, 3 items. 6 sounds. **This is the framework's test cart.**
- **Echo Chimes. Size S.** Three chime posts play a tune that grows by one note a turn; play it back on D-pad and A. Each post has its own note, so a good run is also a melody. Smarts = the tune replays once for free. Art: 3 posts, the pet listening. 3 notes and a miss sound.

More tiny carts (a pond-crossing, a bug round-up) can follow at S each once the framework exists.

## 4. Shared cartridge framework (creative side; Opus architects)

Built once, used by every cart:

1. **Cart catalogue.** One table, like `DeckThemes`: id, name, label art, how it is got (starter, earned, `priceStars`, `gate`), its trained stat, its board rule. Ids frozen at ship.
2. **Carts shelf and swap.** A Carts tab in the deck menu; locked carts say exactly how to get them; the swap animation and a per-cart title card. Faceplates, stickers and juice keep working with every cart.
3. **One screen contract.** Each cart gets the centre well and may ask for the wide layout (question 4). Shared side panels: score, best, pet helper, goals. Shared pause, quit, results and controller focus.
4. **One input contract.** D-pad, A, B, plus touch zones. Every cart playable with one thumb on a phone and on a gamepad.
5. **Client-run sim, server check.** As Egg Drop does today: the client runs the game from a server seed and sends its inputs by tick; the server replays and only then pays. A cart whose sim cannot be replayed bit for bit does not ship. Each cart needs its own determinism check in the `SimCheck` style.
6. **Saves.** Per cart: owned, best score, a few goals ("Pocket Trials" style), today's paid plays. Small and append only.
7. **Boards.** Per cart: best this week among friends, this server, and global. Display names only, no text entry.
8. **One reward gate.** All carts pay through one shared, capped path (section 5), so adding a cart never adds Stars.
9. **Pet on the deck.** The pet out with you is the one in the game, as a pixel sprite; its stats are read once at the start of a run.

## 5. Economy and fairness

- **Stars [P]:** 2 Stars for a finished run that passes a small effort bar (so quitting at once pays nothing), **first 5 runs a day across all new carts together: at most 10 a day**, the same as Garden Dash. Score does not change the pay. The 2x Stars pass does not apply. Egg Drop keeps its own round pay as it is today.
- **Stat XP [P]:** each cart trains one stat lightly: 8 XP for each of the first 3 finished runs a day, per cart, under the per-minute caps in `StatCatalog`. So the deck becomes another way to train, never the best one.
- **Cart prices [P]:** tiny carts earned by play; mid carts 100 to 250 Stars with a low level gate; all fixed, all shown before buying. About 600 Stars of new sink in total.
- **Other rewards:** stickers, a faceplate per cart for a hard goal, and a weekly title for a top-banded score. Cosmetic only.
- **No gambling-like loops.** No bets, no stakes, no reels, no spin for a prize, no double-or-nothing, no near-miss teasing. Picnic Pals avoids casino words and looks on purpose. Pinball has no slot feature.
- **No paid randomness.** Nothing random is ever bought. Randomness inside a run (which piece, which card, which guest) comes from the server seed, is free, and never touches Stars, Robux or what you own. Upgrade choices in a run are shown face up.
- **Under-13 safe.** No chat or text entry, no pressure timers that sell anything, no lives to refill, every run can be stopped and nothing is lost, losing is gentle (the pet naps or floats off, never hurt).
- **Fair boards.** Stat edges would tilt a global board, so see question 3.

## 6. Order, sizes and questions

| Step | What | Size | Why here |
|---|---|---|---|
| 1 | Framework, with Egg Drop moved into cart slot one | M to L | Everything else stands on it; the live game must not change for players |
| 2 | **Lime Time** | S | Proves seed, replay, save, board and pay on something tiny |
| 2b | Pinball **greybox table** (no art), in parallel from step 1 | part of L | Feel is the risk; Spencer flips it early |
| 3 | **Moonpond Pinball** | L | The headline. **v4.0 = steps 1 to 3** |
| 4 | **Jelly Shuffle** | M | Cheapest mid cart, reuses jellies. v4.1 |
| 5 | **Hop Stack** | M | v4.1 |
| 6 | **Picnic Pals** | M to L | Most content and balance. v4.2 |
| 7 | **Echo Chimes**, more tiny carts | S each | Fillers between the big ones |

Art comes after each greybox is fun. Translations and the store listing audit run per publish as in `AGENTS.md`; v4.0 needs new thumbnails and an icon pass, drafted for Spencer's OK.

### Questions for Spencer

1. **Is v4.0 the framework, Lime Time and Moonpond Pinball, with the other carts following in v4.1 and v4.2?** Recommended: **yes.** Pinball is the one you care about and it is the largest; holding it for four more games delays it by months.
2. **How do players get carts?** Recommended: **Egg Drop and Moonpond Pinball free for everyone** (the headline should not sit behind a price), tiny carts earned through trials, the three mid carts for fixed Stars with a low level gate. Never in an egg, never Robux-only.
3. **Do pet stats count on the weekly boards?** Recommended: **no.** Board runs use the level 50 numbers for every pet, as Dash's Just for Fun does; stats give their edges in normal play, where the Stars and XP are.
4. **May a cart use the whole deck screen?** The centre well is narrow on a phone and a pinball table wants height. Recommended: **yes, a "wide" layout** where the side panels shrink to a slim strip, with the table two screens tall and the view following the ball. The greybox settles it; I have not measured it on a phone.
5. **Who makes the music?** The garden and deck loops are your own tracks. Recommended: **you write one new loop for Moonpond Pinball** (with a brighter Garden Hour layer); the small carts reuse the deck loop until each earns its own.

## Files

This document only. No code, assets, save formats or `TODO.md` lines were changed.

## Spencer's answers (2026-11-22)

"Whatever you rec for those 5 v4 qs": all five recommended answers stand (v4.0 = framework + Lime Time + Moonpond Pinball; Egg Drop and pinball free, tiny carts earned, mid carts fixed Stars behind a level gate; boards at level-50 numbers; full deck screen allowed; Spencer writes one pinball loop).

**Pokémon Pinball as a guide** (Spencer: "I just want to use decompiled pokemon pinball as a heavy guide for we don't repeat work, we'd have to translate to Roblox anyways and change / cut some things"). The line we hold:
- **OK:** play it and study it as a player and designer; write down at the idea level what makes a handheld table feel good (mode structure, how a catch/hatch mode is paced, ball save timing, how many targets light a mode, camera on a tall table, flipper feel), then design and code our own. `V2-PINBALL.md` already lists design references from 2026-11-03.
- **Not OK:** porting or line-by-line translating the decompiled code, its physics constants, collision masks, data tables, table layouts, art, sounds, music or text into Luau, even changed or trimmed. Translated code is still their code; that is the part that would put the game at risk (takedown).
- **So "not repeating work" means:** a short reference doc of mechanics in our own words (Fable), a fresh pinball physics core in Luau (Opus: circle-vs-segment collisions, swept ball, flipper as a rotating capsule; standard techniques), and Moonpond's own table.
