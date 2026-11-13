# Round items, cuter balls and ball themes: scope

2026-11-13. Scope and mockups only. Nothing in `src/` changed, nothing committed, Studio not used.

Answers Spencer's three asks: (1) in-round items with a quick-select carousel, and where items come from; (2) cuter balls with crude smiley faces, a slight shake, and no tier numbers anywhere; (3) ball themes as a buyable Pocket Deck customization.

Mockups: `artifacts/round-items-2026-11-13/` (generator: `scripts/deck_art/build_round_items_mockups.py`; `--stats` prints the numbers quoted below).

| File | Shows |
|---|---|
| `01-item-carousel-desktop-848x608.png` | Carousel open on the deck LCD |
| `02-item-carousel-phone-812x354.png` | Carousel open on a phone, with the new item button under A |
| `03-board-before-after.png` | Board today (numerals) vs smileys, calm, over the line, last second |
| `04-round-circles-*-desktop-848x608.png`, `04-round-circles-*-phone-812x354.png` | Whole round HUD: goals, quests and Next with colour circles; calm and danger |
| `04-round-today-desktop-848x608.png` | The same screen as built, for comparison |
| `05-deck-style-ball-themes-desktop-848x608.png`, `...-phone-812x354.png` | Deck style, new "Balls" tab, six themes |
| `06-ball-themes-strip.png` | Every theme across the five sizes, plus its icon circles |
| `07-face-expressions.png` | Every face state for every size, and the shiver frames |
| `08-colour-blind-check.png` | Default theme under protan, deutan and tritan vision |
| `09-item-set.png` | The six candidate items |

How to read the mockups: the balls are not smooth art. They are drawn on the game's real 64 x 107 LCD grid by a Python copy of `JellyLCD.shade()`, then scaled up, so each face has exactly the pixels it would get in game. The HUD around them is drawn from the existing spec numbers. These are concept drawings, not Studio captures.

## Recommendations in one place

1. **Items come from power-up balls in v1, not a Power-up Egg.** A rare star-marked ball drops from the normal queue; merge it and an item lands on your belt. The belt holds 3, lasts one round, and is not saved.
2. **Ship four items first:** Swap, Pop, Magnet, Bomb. Mini and Scope wait.
3. **B opens the carousel and freezes the round.** B stops meaning "leave" during a round; leaving is MENU or the back arrow.
4. **On phones, a small item button appears under A** only while the belt holds something.
5. **Smiley faces replace tier numerals and motifs.** Size and colour carry the tier; the face adds personality and a third cue.
6. **Everywhere else a ball type is a flat coloured circle that also steps in size.**
7. **Ball themes are a third Deck style tab ("Balls")**, six themes, priced 0 / 20 / 40 / 80 Stars like faceplates. Looks only.
8. **Build faces first, themes second, items third.** Faces and circles need no save change. Themes need save v11. Items as recommended need no save change.

---

## A. Items

### A1. What the round allows

Facts from the code that shape every item:

- The round is simulated on the server (`BoardSimulation.lua`, fixed 1/120 s step). The client sends `drop` with an aim and renders what the server publishes.
- A round is 24 drops (`FieldRun.Budget`). The queue is four shuffled bags of six, fixed by the round's seed at the start (`Simulation.new`). `Simulation.nextTier(board, lookahead)` reads it.
- The round ends when balls rest over the fill line for the grace time, or at 32 balls (`BoardRound.lua`).
- A `pause` action already exists (`board.menuPaused`), with one pause owner on the client (`clientUI.syncPause`).
- `restart` re-seeds the same field, so a learned queue cannot be replayed.

So an item is a new server action, `item`, carrying an item id and the round sequence number. The server checks: the round is live and not over; the belt really holds that item; no item is already armed; the item's own condition holds (below). It then applies the effect inside the simulation and publishes the new belt. The client never decides an outcome. A repeated or late request is ignored by sequence number, the same way `restart` is guarded.

### A2. Candidate items

Mockup: `09-item-set.png`.

| Item | Effect | Server rule | Strength | v1 |
|---|---|---|---|---|
| **Swap** | Next and Then trade places. | Swap two queue entries at `drops + 1` and `drops + 2`. Refused on the last drop. | Low. Pure planning. | Yes |
| **Pop** | Removes the highest resting ball. No points. | Server picks the ball with the greatest top edge that has touched the tray. Refused on an empty tray. Removed balls never count for score, goals or chains. | Medium. A rescue. | Yes |
| **Magnet** | Your next ball pulls same-size balls toward it for 2 seconds after it lands. | New force in the step: balls of the same tier within about 3 units accelerate toward the tagged ball. Merges it causes are ordinary merges. | Medium to high. Makes chains. | Yes |
| **Bomb** | Your next ball bursts on first contact and clears a small circle (about 2.2 units). No points. | Tag the held ball. On first contact remove it and every ball whose centre is inside the radius; never more than 4 balls. | High. The big rescue. | Yes |
| **Mini** | Your next ball drops at half size until it merges. | Radius override on that ball; the merge result is normal size. | Low. Skill item. | Later |
| **Scope** | Full aim line for your next 3 drops. | Server only debits and counts down. The longer preview is drawn by the client from the published board. | Low. Helps new players. | Later |

Notes:

- **"Slow-mo aim" is not in the list.** Aiming has no timer today, so slowing time would do nothing. Scope is the honest version of that idea.
- **"Shrink one ball" became Mini** (the held ball) because picking any ball on the board needs a cursor, which is poor on a phone. Every item acts on the held ball or on a target the server picks. No item needs aiming at a ball.
- Magnet is new simulation code. The existing `reach` and `kick` values push balls *away* from a merge; they are not an attraction.
- Mini changes a radius, which touches physics, the renderer and the fill-line check. That is why it waits.

### A3. Balance

Payouts do not change: Easy 5 to 6, Medium 6 to 8, Hard 9 to 12 Stars (`HeatPayout`). Items never touch the multiplier.

| | Easy | Medium | Hard |
|---|---|---|---|
| Power-up balls per round | 2 | 2 | 1 |
| Earliest drop | 5th | 5th | 8th |
| Item odds | Pop 35, Swap 30, Bomb 20, Magnet 15 | Swap 30, Pop 30, Magnet 25, Bomb 15 | Swap 40, Magnet 30, Pop 20, Bomb 10 |
| Belt size | 3 | 3 | 3 |

- Items left on the belt at round end are lost. This stops hoarding and means nothing needs saving.
- Pop and Bomb give no points and complete no goals, so they cannot farm score.
- One item can be armed at a time.
- No power-up balls in the onboarding round, so the first lesson stays about dropping and merging.
- Target: win rate moves by no more than about 5 points per difficulty. If it moves more, cut Easy and Medium to 1 ball before touching payouts. This needs play data; I have not measured it.

### A4. Can items break goals or quests?

| Thing | Risk | Verdict |
|---|---|---|
| Round goals (merge a size in a zone, chain, count) | Magnet makes a merge happen. It still happens where the balls are. | Fine. Pop and Bomb removals count for nothing. |
| Score quests (400, 600, 800) | Magnet merges score normally. | Slightly easier. Acceptable. |
| Chain quests (3, 4, 5) | Magnet is a chain maker. | Easier by design. Limited by 1 or 2 balls a round. |
| "Make a size" quests | Only merges make sizes. No item creates or upgrades a ball. | Safe. |
| Tidy wins (+2 Stars, and quests) | Pop and Bomb lower the stack. | Easier. Accepted: the item was earned in that round and is gone after. |
| Hard "skill" quests | Hard gets one ball, and its odds lean to Swap. | Safe enough. |
| Pocket Trials (for example High Roller, score 250) | Same as score quests. | Check when building. |
| New item quests ("use 2 items") | Adding quests means bumping `QuestCatalog.CatalogVersion`, which today wipes claim masks. | **Do not add item quests in v1.** Write the `QuestState.sanitize` migration first. |

If a best-score board is ever added, store whether items were used so assisted and clean scores can be told apart.

### A5. The carousel

Mockups: `01-item-carousel-desktop-848x608.png`, `02-item-carousel-phone-812x354.png`.

An original design, not a copy of any game's wheel: items are round toy capsules on a shallow belt. The middle one is large and lit, its neighbours are smaller and dimmed. Its name and one line of effect sit underneath.

**Where it sits.** Inside the board, in the empty air above the fill line. The fill line is 49% to 59% of the way down the board, so the carousel (at most 45% of the board height) never covers a legally resting ball, and Next and Then stay visible beside it. That matters for Swap.

**The belt is always visible.** Desktop: a new Items card in the right column with three slots and a "B Open" hint. Phone: a small Items strip under Win pays.

**Desktop and gamepad.**

| Input | Does |
|---|---|
| B (gamepad B, keyboard B) | Opens the carousel. Again to close. |
| Left / Right (d-pad, stick, arrows, A / D) | Browse. Wraps. |
| A (gamepad A, Space, Enter, click the middle capsule) | Use the middle item. Closes. |
| Click a side capsule | Brings it to the middle. |

- **The round freezes while it is open.** It has to: the overflow grace timer runs in real time, so browsing must not cost a life. It uses the existing pause. The board dims, a "Paused" chip shows, and every ball looks up with a small "o" mouth.
- Using an item closes the carousel and resumes. Swap and Pop act at once. Magnet and Bomb arm the held ball, which shows the item's mark in Next and on the board.
- An armed item cannot be cancelled in v1. It was debited when used.
- With an empty belt, B gives a small shake of the Items card and the line "Merge a star ball to get an item". It does not open an empty carousel and it does not leave the round.
- **B no longer means "leave" during a round.** Today B and Backspace are Back. Leaving stays on MENU (Quit to garden) and the back arrow. Outside a round B is still Back. The Controls card changes its B row to "Items".
- Motion: capsules slide 120 ms Quad Out; the panel drops in 140 ms. Reduced Motion: cuts.

**Phones.** Compact decision 4 left B off the touch HUD and kept its space under A free. Use that space:

- A 58 px item button under A on the right shoulder, drawn as a small B with the front item's icon and a count badge. Hit area 66 px.
- **It is only drawn while the belt holds an item.** With an empty belt the shoulder looks as it does today, so decision 4 still holds and there is never a dead button. It pops in when the first item arrives.
- Tap it: the carousel opens in the board and the round freezes. Swipe, tap a side capsule, or use the d-pad to browse. Tap the middle capsule or press A to use. Tap the button again, the dimmed board or the back arrow to close.
- At 812 x 354 the carousel is 157 x 156, the middle capsule 60 px, side capsules 42 px with 50 px spacing (touch targets 44 or more). Effect text uses a short form ("Removes the top ball.") so it fits on one line.
- The five speaker dots on the right shoulder give way to the button.
- At 568 x 320 the shoulder is 80 wide and A is 70. A 52 px button fits under it by the same rule; not drawn here, check in the build.

I considered tapping belt slots directly on the screen with no carousel. It is one tap faster, but the slots would be under 44 px in the phone's side column and it would not be the same control as desktop. The shoulder button keeps one design on every device.

### A6. Where items come from

| | Power-up Egg | Power-up balls | Both |
|---|---|---|---|
| How | Hatch for Stars, get random items into a saved inventory | A rare star ball in the queue; merge it to get an item for this round | Balls feed the belt; the Egg stocks a pouch you bring 1 from |
| Fun | Opening is fun once. In the round it is just a menu. | The prize is on the board and you have to earn it with a merge. | Most to learn |
| Economy | A new Stars sink, but it converts Stars into wins that pay Stars | None. No Stars in or out. | Needs careful pricing |
| Retention | Inventory to grow | A reason to play one more round, nothing to hoard | Both |
| Simplicity | Large: inventory, receipts, idempotent buys, save bump, shop screen, odds text | Medium: queue flags, one action, belt, no save | Largest |
| Pay-to-win risk | **Real.** Stars are sold for Robux, so this is paid random gameplay power | None | Real unless capped |
| Fits the game | Other eggs give looks and toys, never power | Yes | Mixed |

**Recommendation: power-up balls only for v1.**

- It is the only option with no pay-to-win risk. Stars can be bought with Robux, so an egg that turns Stars into random round power is a paid loot box that affects winning. Every other egg in the game is cosmetic or a toy.
- It needs no save change and no shop work, so it can ship and be tuned quickly.
- It puts the reward in the play itself. A star ball changes how you play the next few drops.
- If items prove fun, add the Egg later with a hard cap: bring one item per round, fixed prices or shown odds, Stars only.

**How a power-up ball works.**

- The server marks 1 or 2 queue slots as star balls when the round starts, from the same seed. The ball keeps its normal size and colour, so the bag and the 24-drop budget do not change.
- It shows a twinkling pale star instead of a face (in `03-board-before-after.png`, the small blue ball with a plus).
- Merge it with a ball of its size and the item is granted. Which item was fixed by the seed. It is revealed at the merge with a pop toward the Items card.
- If the belt is full, the new item replaces nothing and is lost, with a "Belt full" toast. (Alternative: replace the oldest. See question 5.)
- If it is never merged, nothing is granted.

### A7. Save impact

- **Recommended v1 (balls, round-only belt): none.** The belt lives on the server's board object and in the published round state. Leaving or restarting clears it.
- **If a Power-up Egg is added later:** a new `items` map in the fenced hatching record beside the wallet (for example `{ pop = 2, swap = 1 }`, each count capped), bought through the same idempotent operation pattern as faceplates, and a save version bump. If that ships with ball themes it should share the one bump to v11.

---

## B. Cuter balls

Mockups: `03-board-before-after.png`, `07-face-expressions.png`, `04-round-circles-*`.

### B1. The size we are drawing at

The board LCD is 64 pixels wide. Ball diameters on it are about **8, 11, 16, 20 and 26 pixels**. On a 1080p desktop one LCD pixel is about 5 screen pixels; on an 812 x 354 phone about 2.5. So a face on the smallest ball is a handful of pixels, and "crude" comes free.

### B2. Face rules

One ink colour per theme (default `#15102B`, a very dark violet, never pure black). Faces stay upright; they do not spin with the ball, because a rotated 8-pixel face is noise.

| Size | Eyes | Mouth | Resting personality |
|---|---|---|---|
| Blue, 8 px | 1 x 1 dots, 2 apart | 2 pixels | Tiny and cheerful |
| Orange, 11 px | 1 x 2 tall | 4-pixel U | Bright-eyed |
| Green, 16 px | 2 x 2 with a white glint | Two-row grin | Big grin |
| Pink, 20 px | Heavy lids | Smirk | Sleepy and smug |
| Violet, 26 px | 3 x 3 with a glint | Open mouth, pink tongue, blush | Delighted |

Each size has its own resting face, so the face is a third cue after size and colour.

| State | When | Face |
|---|---|---|
| Idle | Default | The size's own face |
| Blink | Every 3 to 6 s, staggered, 120 ms | Eyes become a line |
| About to merge | A same-size ball is within about one radius | Wide eyes, small "o" |
| Just merged | 0.32 s on the new ball (the existing merge time) | Happy squint, open smile |
| Over the line | Resting in the warning zone | Wide eyes, frown, and it shivers |
| Last second | Under 1 s of grace | Wide eyes, big "O", a sweat drop |
| Sleepy | Untouched and calm for 8 s | Closed eyes, mouth nearly gone |
| Items open | Carousel is up | Eyes up, small "o" |

The held ball and Next / Then use the same faces.

### B3. Shading changes to make room

A face needs a clean field. Today's shading (large highlight, second glint dot, rim light, motif) fights it. With faces on:

- One small glint, higher and further left, above the eyes.
- The deep shade stays lower right. A thin light crescent stays upper left.
- Rim light only on the three larger sizes.
- **Motifs go** (bands, speckles, stars, ring of dots). Faces replace them as the non-colour cue.
- **Tier numerals go** (the label drawn at radius 12 px or more).
- The bloom on the well stays exactly as built.

### B4. The shake, and its cost

"Slightly shaking" is done by moving **only the face**, one LCD pixel sideways, for two ticks, then back (bottom of `07-face-expressions.png`). The body's pixels do not move.

- Calm balls shiver rarely: one short shiver every 2 to 5 s each, staggered.
- Balls over the line shiver continuously. This is the "alive and worried" read.
- The existing impact wobble on the body is unchanged.
- At most 6 balls shiver in the same tick; ticks are 10 per second.
- Reduced Motion: no shiver. Blinks and expression changes stay.

**Renderer budget.** The span renderer is capped at 1536 spans and the measured peak is about 1229. I could not measure in Studio for this scope, so I modelled it: a Python copy of the shader counts runs of equal colour per row. On a tall 27-ball board the model gives 1291 for today's look, close to the real 1229, so it is a fair guide but not a measurement.

| Board (model) | Today | Faces on today's shading | Faces with the B3 shading |
|---|---|---|---|
| Calm, 12 balls | 642 | 705 (+63) | 638 (-4) |
| Tall, 27 balls | 1291 | 1436 (+145) | 1298 (+7) |
| Stress, 32 balls | 1369 | 1550 (+181), **over the cap** | 1392 (+23) |

- Faces painted on top of today's shading would break the cap. Faces with the cleaner shading cost about the same as today, because the motifs and extra highlights they replace were spending the same spans.
- The busiest expression adds up to 15 spans on one ball. Only balls near the line wear it.
- A shiver moves a few face pixels, so it does not add spans. It does cause property writes: about 12 per shivering ball per tick, at most about 70 per tick with the 6-ball limit.
- **Gate:** `JellyRendererBenchmark.spec` falling scenario with faces must peak at or under 1440 (6% headroom). If it does not, the two smallest sizes drop their mouths first (eyes only) whenever the last frame used more than 1350.

### B5. No numbers anywhere: the coloured circle rule

Wherever the UI names a ball type, draw a flat circle in that size's colour. No numeral, no "tier IV".

- **The circle also steps in size** inside a fixed slot: 52%, 64%, 76%, 88%, 100%. This is needed for colour-blind players (B6) and matches "told apart by size and colour".
- A thin lighter ring keeps it clear of the card.
- "Or bigger" is the words "or bigger" on desktop and a small up arrow on phones. Not a plus sign, which now means "and".
- Zone glyphs (the mini tray) stay.

| Place | Today | Becomes |
|---|---|---|
| Goals, desktop | "Merge II in the centre" | "Merge ● + ● in the centre" with the zone glyph |
| Goals, phone icon rows | Ball with "II" on it | Plain circle, zone glyph, count |
| Quests | "Make a tier IV", "Tier IV on Hard" | "Make a ●", "Make a ● on Hard" |
| Next / Then | Sprite with numeral | The live sprite with its face |
| Results, toasts | "Tier IV made" | "Made a ●" |
| Difficulty picker bullets | "Bag with tier III" | "More ● in the mix" |
| Screen readers, plain-text toasts | "tier 4" | The size's colour name from the theme ("pink ball") |

`QuestCatalog` titles hold "IV" as text today. Changing how a title is drawn does not change what the quest means, so `CatalogVersion` must **not** be bumped for this. Draw the circle from the quest's `tier` field instead of editing meaning.

### B6. Colour-blind check

Mockup: `08-colour-blind-check.png`. Numbers from `--stats` (colour distance, CIE76; about 10 is "clearly different side by side", under 6 is "easily confused").

| Vision | Closest neighbouring sizes | Closest pair overall |
|---|---|---|
| Full colour | 60 | 39 (Blue and Violet) |
| Protan | 22 | **8** (Blue and Violet) |
| Deutan | 32 | **6** (Blue and Violet) |
| Tritan | 72 | 21 |

- Neighbouring sizes are always clearly different in colour, in every theme (20 or more).
- **Blue and Violet look alike without red-green vision.** They are the smallest and the biggest ball: 8 px against 26 px on the board, and the smallest and largest circle in the icon. Size separates them. This is why the icon circle must step in size and not be colour alone.
- On the board, three cues stack: size (each step is 25% to 44% bigger), colour, and the face.
- Optional later: a Settings toggle that adds one to five small pips under icon circles. Off by default, because Spencer asked for no numbers.

---

## C. Ball themes

Mockups: `05-deck-style-ball-themes-*`, `06-ball-themes-strip.png`.

### C1. Where it lives

Deck style gets a third tab: **Faceplates | Backgrounds | Balls**. Same header, same pane and grid as the other two, LB / RB and Q / E switch.

- Pane: the theme on a small live board (where it will really show), name, tier chip, one line, and the five icon circles it will put in goals.
- Grid: one card per theme with the five sizes in a row. Desktop 2 x 3 cards of 222 x 122. Phone 3 x 2 cards of 169 x 68.
- Status on a card: IN USE, Owned, or the Star price. Buy and Use are the same primary button as faceplates.

### C2. The themes

| Theme | Price | Palette | Face | Texture | Size names |
|---|---|---|---|---|---|
| **Smileys** | Free, default | Vivid (as built) | Crude smileys, one personality per size | None | Blue, Orange, Green, Pink, Violet |
| **Marbles** | Free | Vivid | None | Today's glossy look and motifs, no numerals | Same |
| **Gumdrops** | 20, common | Pastel | Always-happy squint | Pale sugar skirt on the lower third | Blueberry, Apricot, Mint, Rose, Lilac |
| **Gems** | 40, rare | Jewel tones | Two tiny eyes, no mouth | Hard facets, flat planes | Sapphire, Topaz, Emerald, Ruby, Amethyst |
| **Planets** | 40, rare | Dusty space tones | Dozing, eyes closed | Craters, land, bands, a ring | Moon, Mars, Terra, Giant, Nebula |
| **Kittens** | 80, showcase | Soft candy | Cat face, pink nose | Ears on the four larger sizes | Blue kitten, Ginger, Matcha, Sakura, Plum |

- **Marbles is free** so anyone who dislikes faces can turn them off without paying.
- Prices match the faceplate tiers (20 / 40 / 80). The whole set costs 180 Stars: about 15 Hard wins, or a week of daily quests.
- **Fruit is left out on purpose.** A fruit set would make the board look like Suika Game, and this game should look like itself. If Spencer wants it, it is an easy fifth paid theme.
- A theme changes: body, shade and highlight colours; ink colour; face style; texture; size names. It changes nothing else.

### C3. Rules every theme must pass

1. **Same sizes.** Radii come from `BoardConfig`. A theme never changes a silhouette's size. Ears and the like may stick out at most 15% of the radius and never count for collisions or the fill line.
2. **Same hue family per size**, smallest to biggest: blue, orange, green, pink, violet. Goals read the same in every theme, and a player watching a friend's screen is not lost.
3. **Neighbouring sizes differ by 20 or more** in colour distance under full, protan, deutan and tritan vision (the `--stats` table; all six pass after two palettes were adjusted during this scope).
4. **Face ink contrast 4.5 : 1 or more** on the body colour (all pass; lowest is 4.5, Gems ruby).
5. **Body contrast 3 : 1 or more** against the darkest well band on every faceplate.
6. **Span budget:** the benchmark peak stays at or under 1440. In the model Gumdrops costs about +20 to +60 over today, Gems and Planets cost less than today, and **Kittens is the expensive one at about +100**. It fits, but it is the theme to measure first. If it fails, ears move to the three largest sizes (about +80).
7. **At most 8 tones per ball**, so the 64-entry palette cache in `JellyLCD` is never exhausted by one theme.
8. **Works at 2.5 screen pixels per LCD pixel.** Every theme is checked on the 812 x 354 phone board, not only on desktop.
9. **Readable danger state.** The over-the-line and last-second faces must exist, or the theme must show danger another way (Marbles relies on the amber line and haze only).
10. **Looks only.** No theme changes physics, odds, payouts or what a goal means.

### C4. How it is sold and saved

Faceplates are the pattern to copy:

- Catalogue: a new shared `BallThemes.lua` (order, name, tier, `priceStars`, palettes, face style, texture id), like the `Plates` table in `DeckThemes.lua`.
- Buying: a `ballThemeBuy` action through `HatchProgress` with the same fenced debit, price check and bound operation id as `faceplateBuy` (`FaceplateState.lua` is the model: `check`, `apply`, tolerant `valid`).
- Owning: `state.ballThemes`, a list of ids in the hatching record beside `faceplates`, same 64 limit, unknown ids tolerated.
- Equipping: a `ballTheme` slot in the appearance record in `PlayerProgress.lua`, beside `theme` and `background`. A missing value means "smiley", the same way a missing background means the default.
- The server publishes the equipped id; `JellyPalette` and `JellyLCD` read the theme. The server's board never knows or cares.

**Save impact: version 11.** `ballThemes = {}` is added on upgrade, as `petWearables` was for v10. The same warning as v10 applies: once players save on v11, the place must not be rolled back to a build that cannot read v11. The appearance slot is a tolerant addition and needs no bump of its own.

---

## D. Build order, risks, questions

### D1. Build order

| # | Slice | Size | Save | Depends on |
|---|---|---|---|---|
| 1 | Faces on the board: B3 shading, face patterns, states, shiver, remove motifs and numerals. Benchmark gate. | M | None | - |
| 2 | Coloured circles in goals, quests, Next / Then, results, toasts, picker text | S | None | 1 |
| 3 | Theme plumbing: `BallThemes` catalogue, renderer reads a theme, Smileys and Marbles (both free), equip slot | M | Appearance slot only | 1 |
| 4 | Balls tab in Deck style, buying, four paid themes | M | **v11** | 3 |
| 5 | Item core on the server: `item` action, belt, star balls in the queue, Swap and Pop | M | None | - |
| 6 | Carousel UI on desktop and gamepad, B rebinding, Items card, freeze | M | None | 5 |
| 7 | Phone item button and compact carousel | S | None | 6 |
| 8 | Magnet and Bomb (new simulation code), tuning pass | M | None | 5 |
| 9 | Later: Mini, Scope, Power-up Egg with a saved pouch | L | With the Egg | 8 |

Slices 1 and 2 are the fastest visible win and answer ask 2 on their own. Slices 5 to 8 can run beside 3 and 4 because they do not touch the same files, apart from `JellyLCD` drawing the star mark.

Per the agent split: Astra reviews the rendered faces, themes and carousel; Sol writes the code; each substantial slice follows the review-driven-build steps.

### D2. Risks

- **Span cap.** The model says faces fit. It is a model. Slice 1 is not done until the benchmark passes in Studio.
- **Property writes from shivers** on low-end phones. The 6-ball limit is a guess to be measured.
- **Faces at phone scale.** At 2.5 px per LCD pixel the smallest face is about 5 screen pixels across. It reads as "two dots" in the mockup; check on a real phone.
- **Rebinding B** changes a habit. Players who press B to leave will open items instead. The Controls card and the first-item coach line must say so.
- **Items shift difficulty.** Win rates and tidy rates will rise. Easy already pays little; watch that items do not make Medium trivially tidy.
- **Magnet and Bomb are new physics.** They need their own specs for determinism and for the 32-ball end rule.
- **Save v11 is one-way**, like v10.
- **Quest text.** Circles must be drawn without bumping `CatalogVersion`, or claim masks are lost.
- **Originality.** The carousel, capsule look and star balls are original. Avoiding a fruit theme keeps the board from reading as a clone.

### D3. Open questions for Spencer

1. **Power-up balls only for v1, no Power-up Egg yet?** Recommend yes. It avoids selling round power for Stars, and needs no save change.
2. **B opens items during a round and no longer leaves; leaving is MENU or the back arrow?** Recommend yes.
3. **Phone: an item button under A that only appears while you hold an item?** Recommend yes. Decision 4 (no B on touch) still holds when the belt is empty.
4. **Remove the motifs as well as the numerals, so faces are the only mark on the default balls?** Recommend yes. It is what makes faces fit the renderer budget. The old look stays available as the free Marbles theme.
5. **When the belt is full and you earn another item: lose the new one, or replace the oldest?** Recommend lose the new one, with a "Belt full" toast. It rewards using items.
6. **Theme list and prices: Smileys and Marbles free, Gumdrops 20, Gems 40, Planets 40, Kittens 80, no fruit?** Recommend yes. Say if you want fruit added or a different sixth theme.
