# Play forever: cosmetic eggs, the long-term loop and the Star economy

**Status: scope only, 2026-11-13. Nothing here is built.** No code, save format, Studio place or published build was changed. No mockups were made for this pass; section 6 lists the three worth drawing.

It answers Spencer's ask: "Should we put [ball themes] in eggs or something? Since they're just cosmetic? We need players to play forever."

Sources read: `GAME-DESIGN.md`, `PRODUCT-SCOPE.md`, `CHAO-GARDEN-DIRECTION.md`, `ONBOARDING-V1-SCOPE-2026-11-13.md` (accepted), `ROUND-ITEMS-AND-BALL-THEMES-SCOPE-2026-11-13.md`, `PET-PARK-V1-SCOPE-2026-11-13.md`, `artifacts/batch-2026-11-13/BUILD-PLAN.md`, `TODO.md`, and the code named in section 0. Roblox's paid random items page was re-read on 2026-11-13 ([link](https://create.roblox.com/docs/production/monetization/paid-random-items)).

## The answer in one place

1. **Keep ball themes, faceplates and the Wardrobe as direct buys.** Putting four paid themes in an egg does not make anyone play longer. It makes the same 180 Stars of content less predictable, adds policy work, and changes a price Spencer approved this morning.
2. **The real problem is volume, not the buying method.** Everything for sale at launch costs 936 Stars. An engaged player earns that in about a week, a casual player in about four and a half weeks. After that the wallet has nothing to do.
3. **Add a Style Egg after launch for small, numerous cosmetics** (merge pops, drop trails, face packs): Stars, shown odds, no duplicates ever, every item also sold directly. Hand eggs out as rewards so the opening moment is mostly earned.
4. **"Forever" comes from goals that are not purchases:** a collection book, a weekly shared board, the Bear's bond level, quests that keep changing, and new content on a steady beat.
5. **One thing is urgent: start counting now.** Lifetime counters cannot be backfilled. Add them to the v11 save bump that is already being written for ball themes.

---

## 0. What the code does today (checked 2026-11-13)

| Fact | Where |
|---|---|
| Round pay: Easy 5 (tidy 6), Medium 6 (tidy 8), Hard 9 (tidy 12). 2x Stars pass doubles it; Supporter adds +1 per finished round. | `src/shared/HeatPayout.lua`, `BoardConfig.Heat` (tenths 8 / 10 / 15), `StoreCatalog.lua` |
| Daily quests: 3 a day at 4 Stars. Weekly: 3 at 10 Stars plus 5 for all three. Pools of 8 per daily slot and 4 per weekly slot. | `src/shared/QuestCatalog.lua` |
| Daily gift 6 Stars. Petting +1, five times a day. | `EggCatalog.DailyBonus`, `HatchProgress.lua` |
| Accepted, not built: +2 Stars for a missed round with a goal met; daily Play date +4 in the park. | Onboarding and Pet Park scopes |
| Fixed-price cosmetics: 8 paid faceplates (3 at 20, 3 at 40, 2 at 80), 13 Bear wearables (6 at 15, 5 at 30, 2 at 60), ball themes planned at 20 / 40 / 40 / 80. | `DeckThemes.lua`, `BearRigDefinition.lua` via `WearableCatalog.lua`, batch build plan |
| Eggs sold for Stars today: Toy Egg 8 (pool of 3), Material Egg 16 (pool of 2), Hue Egg 8 (repeatable). Feature Egg 32 is hidden by `FeatureFlags`. Companion Egg retired. | `ToyCatalog`, `MaterialCatalog`, `HueCatalog`, `FeatureCatalog`, `EggCatalog` |
| Toy and Material eggs already remove owned items from the pool and show the remaining odds. | `Catalog.remaining` in both, `OddsText.lua` |
| Star packs are hidden when `ArePaidRandomItemsRestricted` is true or the policy cannot be read. The eggs themselves are not gated. | `src/server/StoreService.lua` `policyAllowsPacks` |
| Stars for Robux: 20 for 39, 60 for 99, 140 for 199, 400 for 499 (1.25 to 1.95 Robux per Star). | `StoreCatalog.lua` |
| The only lifetime counter saved is `totalWins`. Best score is saved. Family mastery (marks, three ranks, challenge bits) is in the save but its display is retired. | `HatchProgress.lua`, `FamilyMastery.lua`, `src/client/PetPrestige.lua` |
| Pocket Trials (five one-time skill goals) still exist beside quests. Spencer has asked whether they are redundant. | `PocketTrials.lua`, `TODO.md` |
| Hatching save is v10. v11 (ball themes) is in progress. Both are one-way. | `HatchProgress.lua`, batch build plan item 1 |
| Bumping `QuestCatalog.CatalogVersion` wipes claim masks until a migration is written. | Warning at the top of `QuestCatalog.lua` |

---

## 1. Direct buy or cosmetic eggs

### 1.1 The comparison

| | Direct buy (today) | Everything in eggs | Hybrid (recommended) |
|---|---|---|---|
| Engagement | Clear goal: "Kittens, 34 more Stars". Works with the come-back strip on the results screen. No surprise. | A surprise each open. With duplicates it lasts longer but by frustrating people. With a no-duplicate pool it costs the same total as direct buy, so it adds no playtime. | Clear goals for the items people point at. Surprise for small items, mostly as earned rewards. |
| Fairness | Best. A child knows what the Stars buy. | Worst for the item a player wants: with four themes the one you want can be last. | The showcase item is never random. Anything in an egg can also be bought on its own. |
| Roblox policy | None beyond the store. | Every Star egg is a paid random item because Stars are sold for Robux. Odds, per-player updates, region handling on each egg. | The same rules, but on one egg with one simple pool rule. |
| Build cost | None (already built or in the approved batch). | Rework of three shops and their receipts. | One new egg on the existing Toy Egg pattern, after launch. |
| Trust | Prices already shown to Spencer and to private testers. | Turns a known price into a gamble. | No change to anything already priced. |

Pool size decides this. Gacha needs many small prizes. Ball themes are four paid items, each one a big visible change to the board. Faceplates are eight. Those are shop-window items.

### 1.2 What Roblox requires (re-read 2026-11-13)

- A random item bought with a currency that can be bought with Robux is a paid random item. That covers every Star egg, including the Toy, Material and Hue eggs already live.
- Before the spend, show every outcome and its numerical odds. The page words this as percentages that sum to 100%, with rounding allowed if a note says totals may not add up.
- If an outcome can only be won once, the remaining odds must update for that player. The Toy and Material eggs already do this.
- Pity and luck boosts count as "probability modifiers". Their effect must be explained before purchase and the shown odds must change while they apply.
- When `ArePaidRandomItemsRestricted` is true the player must not use paid random item generators. Allowed treatments: an unpaid path, a fixed order shown before purchase, direct purchase priced at expected value, hiding the egg, or blocking the purchase.
- Random rewards earned by play, with no Robux or currency spent, need no odds. Showing them anyway is good practice.
- The page gives no age or country list. The policy flag is the only test, and it has to be read per player.

**Two checks for the launch list, both found during this read:**

1. `OddsText.format` prints "1 in 3" for equal thirds. The policy page asks for percentages. Either confirm "1 in N" is acceptable or print "33.3%" with the rounding note. Small, but it is on every egg card.
2. Restricted players have Star packs hidden, which makes their Stars earned. That is a fair reading of "unpaid path", but the 2x Stars pass still touches the wallet and a player could hold Stars bought before the flag applied. The safer treatment is cheap: for restricted players each egg shows which item comes next (fixed order, shown before the spend). Recommend doing that for all eggs before public launch.

### 1.3 Duplicates, dust, pity

| Approach | What it means | Verdict |
|---|---|---|
| Duplicates with a Star refund | `EggCatalog.DuplicateRefund = 0.5` exists for the retired Companion Egg. A duplicate returns half. | Feels bad for a child, and half a refund is still a loss. Not for cosmetics. |
| Duplicates turned into dust | A second currency to craft with. | Breaks the one-wallet rule. More UI, more save, more to explain. No. |
| Pity counter | A rare is promised within N opens (`RareGuarantee = 7` exists). | Works, but it is a probability modifier with its own disclosure. Not needed if the pool empties. |
| **No duplicates, pool empties** | Owned items leave the pool. Odds are recalculated and shown. The last egg is always the last item. | **Recommended.** Already built for Toy and Material eggs. Pity is built in: a set of 12 completes in exactly 12 opens. |

### 1.4 Recommendation

**Direct buy stays for anything a player would name as a goal:** ball themes, faceplates, backgrounds, Wardrobe items. No change to the approved batch.

**Add one Style Egg after launch (weeks 3 to 4), for small cosmetics that come in sets:**

| Rule | Value |
|---|---|
| What is inside | A named set of 12 small items (7 common, 4 rare, 1 showcase): merge pops (the burst when two balls merge), drop trails, face packs for the Smileys theme, results stamps. No ball themes, faceplates or wearables. |
| Price | 12 Stars per egg. A set costs 144 Stars by egg. |
| Currency | Stars. One wallet, as approved in `CHAO-GARDEN-DIRECTION.md`. |
| Odds | By tier: common 70, rare 25, showcase 5, split evenly inside a tier, renormalised as tiers empty. All shown as percentages before the spend and updated per player. |
| Duplicates | None. Owned items leave the pool. "7 of 12 left" on the card. |
| Pity | None needed. The set finishes in 12 opens. |
| Direct price | Every item is also sold on its own at 15 / 30 / 60 (the Wardrobe tiers). The egg is the cheap way to get all of it; direct is the sure way to get one. |
| Restricted players | The egg shows the next item (fixed order). Same price. |
| Earned eggs | Free Style Eggs come from the collection book, the stamp card and finishing all three weekly quests. Most eggs a player opens should be earned. |
| When the set is done | The card reads "Set complete" and shows when the next set arrives. Old sets stay on sale. |
| Power | None. Looks only, same rule as ball themes (C3 rule 10). |

Why Stars and not an earned-only ticket: a ticket would sit outside the paid random item rules, but it is a second currency in a game whose direction says one wallet. The no-duplicate pool already removes what makes paid eggs unfair, and the odds display is already built.

Why not at launch: it needs 12 finished items, and launch already has more to buy than a new player can afford for three weeks (section 3).

---

## 2. The long-term loop

### 2.1 What keeps a player for months

A round is two to three minutes and is replayable on its own. Today a returning player has three daily reasons (gift, quests, pets) and one direction (buy the next thing). When the shop is empty the direction is gone. The loop below gives four more directions that do not run out at the same time.

| Rhythm | Reason to open the game | System |
|---|---|---|
| Every session | Beat the board, earn Stars, pet the Bear | Rounds, items, petting (exists) |
| Every day | Gift, three quests, Play date, a stamp | Quests (exists), park (accepted), stamp card (new) |
| Every week | Weekly quests, the shared weekly board, the shop shelf | Weekly quests (exists), Weekly Board (new), shelf (new) |
| Every month | A new Style set, a theme week, new shop items | Style Egg, events, content beat |
| Always | Fill the book, raise the Bear's bond, earn medals | Collection book, bond, trials |

### 2.2 The systems, ranked

Retention value is a judgement (no telemetry exists yet). Cost is S (under a session), M (one to two sessions with review), L (more, or needs new art).

| # | System | What it is | Retention | Cost | When |
|---|---|---|---|---|---|
| 1 | **Lifetime counters** | Rounds, wins by difficulty, tidy wins, merges, best chain, tier V made, items used, pets given, park games, days played, Stars earned and spent. No UI. | Enables 2, 5, 7, 12 | S | **v1, in save v11** |
| 2 | **Collection book** | One screen. Pages for Balls, Faceplates, Wardrobe, Toys and finishes, Pets, and Discoveries (first tier V, chain of 5, each goal type won, each difficulty won). Each page shows owned / total and pays at 25, 50, 75 and 100%. | High | M | **v1** |
| 3 | **Stamp card** | Each day played adds one stamp. Seven stamps finish a card: small Stars on most stamps, a bigger gift on the seventh. Stamps never reset. A missed day costs nothing. Replaces the flat 6-Star gift. | Medium | S | **v1** |
| 4 | **Quest growth** | New metrics for the park, petting and items; all three weeklies pay a Style Egg instead of only +5 once the egg exists; pools widen so a week never repeats. | Medium | S each | Weeks 1 to 2, then ongoing |
| 5 | **Weekly Board** | One seeded board a week, the same for everyone. Bronze, silver and gold score lines. Unlimited tries, best score kept. Pays once per medal. A friend's medal shows on their deck. | High | M | Weeks 2 to 3 |
| 6 | **Style Egg and sets** | Section 1.4. | Medium to high | M plus 12 items of art | Weeks 3 to 4 |
| 7 | **Bear bond** | The pet's own level, 1 to 10, from petting, rounds played with it, toys and park games. Each level unlocks something seen: an idle, a greeting, a nap spot, a bond-only wearable at 10. Revives the saved family mastery under a clearer name. | High | M | Weeks 3 to 4 |
| 8 | **Second pet** | The green alien plush. A new Pets page, a new Wardrobe, a new bond track. | High | L (art) | Weeks 4 to 6 |
| 9 | **Shop shelf** | Three featured items a week at about 20% off. Items always come back. Needs more items than the shelf shows, so it waits for content. | Medium | S | Week 5 |
| 10 | **Polish** | Pay Stars to turn an owned item into its gold-trim version. Fixed price, no chance. Cheap art, deep sink. | Medium (as a sink, high) | S to M | Weeks 5 to 6 |
| 11 | **Theme week** | Seven days, three event quests, one progress bar, one event cosmetic at the end. No event currency. The cosmetic returns in a later rotation. | Medium to high | M | Week 6 |
| 12 | **Trials as medals** | The five Pocket Trials become permanent medals on the Discoveries page, per difficulty, plus harder ones (no items, 20 drops, small well). Answers the "are Trials redundant" question: quests rotate, medals are forever. | Medium | M | Weeks 7 to 8 |
| 13 | **Park social goals** | "Meet 10 different pets", a server goal that pays everyone who took part. Needs the park shipped and enough players at once. | Medium | M | Weeks 6 to 8, if concurrency allows |
| 14 | **Friends board** | Weekly Board scores among friends. | Medium | M | Weeks 7 to 8 |
| 15 | **Free season track** | 20 steps a month fed by quests. No paid lane to start. | High | L | After week 8, if the data asks for it |

Not proposed: streaks that reset or sell a freeze, items that never return, trading, paid luck, a paid season lane at launch, energy or round caps. `GAME-DESIGN.md` listed several of these; the later direction documents and the all-ages audience rule them out.

### 2.3 The v1 set

Four pieces, chosen because they are cheap, need no new art, and are what every later system reads from.

1. **Direct-buy ball themes, as approved.** No change.
2. **Lifetime counters in save v11.** Invisible. A week of launch play that is not counted can never be credited to the book, medals or bond later.
3. **Collection book.** Lean version: pages and percentages from the lists the save already holds, milestone rewards in Stars (5 / 5 / 10 / 15 per page, six pages), and one book-only faceplate for finishing any three pages. It gives the wallet a purpose beyond "the next thing" and gives finished players a number to raise.
4. **Stamp card.** One integer. It turns the daily gift into a seven-step goal without any penalty.

Already in v1 from other scopes and counted here: daily and weekly quests, the park Play date, the results come-back strip, the "Tomorrow" line.

The onboarding scope said no login streaks for v1 because of new saved state and policy review. The stamp card is the non-punishing form of that idea, it is one field, and it carries no paid element. If v1 has to shrink, drop the stamp card first and keep the counters and the book.

### 2.4 First eight weeks after launch

| Week | Ship | Why then |
|---|---|---|
| 1 | Fixes only. Read the funnel, win rates, Stars earned and spent per player per day. | Every number in section 3 is an estimate until this exists. |
| 2 | Quest growth (park, petting and item metrics). Write the `CatalogVersion` migration first. Weekly Board. | Engaged players start running out of shop around day 7. The board is their next goal. |
| 3 | Bear bond levels. | Deepens the one pet the game has. |
| 4 | Style Egg with Set 1. Earned eggs from the book, stamp card and weeklies. | Casual players finish the launch shop around weeks 4 to 5. |
| 5 | Shop shelf. One new ball theme or four new wearables at the new 160 tier. | First content beat. |
| 6 | Polish. Theme week 1. Second pet if the art is ready. | Deep sink for players with full wallets. |
| 7 | Trials as medals. Park social goals if servers are full enough. | Long-tail skill goals. |
| 8 | Set 2. Friends board. Review: keep, cut, and decide on a season track. | Second month starts with something new. |

The steady beat after that: one Style set, one shop drop and one theme week per month. That is roughly 400 to 500 Stars of new things to want each month.

---

## 3. Economy sanity

### 3.1 Assumptions

No telemetry exists. These are stated so they can be replaced with real numbers in week 1.

| | Casual | Engaged | Engaged with 2x pass |
|---|---|---|---|
| Session | 10 to 15 minutes, 5 rounds | 45 minutes, 15 rounds | Same as engaged |
| Difficulty | Easy and Medium | Mostly Hard | Hard |
| Wins | 3 (1 tidy) | 9 (4 tidy) | 9 (4 tidy) |
| Misses with a goal met (+2, accepted) | 1 | 3 | 3 |
| Daily quests done | 2 of 3 | 3 of 3 | 3 of 3 |
| Weekly quests done | 1 of 3 | All, with bonus | All, with bonus |
| Days a week | 5 | 7 | 7 |

### 3.2 Stars in per day

| Source | Casual | Engaged | Engaged 2x |
|---|---:|---:|---:|
| Round wins | 18 | 93 | 186 |
| Missed-round finish pay | 2 | 6 | 12 |
| Daily quests (4 each) | 8 | 12 | 24 |
| Play date (park, +4) | 0 | 4 | 8 |
| Daily gift | 6 | 6 | 6 |
| Petting (up to 5) | 5 | 5 | 5 |
| **Per day** | **39** | **126** | **241** |
| Weekly quests | 10 | 35 | 70 |
| **Per week** | **about 205** | **about 917** | **about 1,757** |

The casual day matches the onboarding scope's estimate of about 40. Round wins are 46% of casual income and 74% of engaged income, so difficulty choice and win rate are the levers that matter.

### 3.3 Stars out: everything for sale at launch

| Shelf | Items | Stars |
|---|---|---:|
| Wardrobe (Bear) | 6 at 15, 5 at 30, 2 at 60 | 360 |
| Faceplates | 3 at 20, 3 at 40, 2 at 80 | 340 |
| Ball themes | 20, 40, 40, 80 | 180 |
| Material Egg | 2 finishes at 16 | 32 |
| Toy Egg | 3 toys at 8 | 24 |
| **Total, one time** | | **936** |
| Hue Egg | 8 each, repeatable | Small, ongoing |

At the Chest rate the whole launch catalogue is about 1,170 Robux.

### 3.4 How long things take

| Goal | Casual | Engaged | Engaged 2x |
|---|---|---|---|
| Gumdrops (20) | Half a play day | 2 Hard wins | 1 Hard win |
| Gems or Planets (40) | 1 day | 4 Hard wins, about 15 minutes | 2 wins |
| Kittens (80) | 2 days | About 30 minutes | About 15 minutes |
| Showcase wearable (60) | 1.5 days | Half a session | A quarter |
| All four paid ball themes (180) | 4.6 play days, about a week | 1.4 days | Under a day |
| **Everything (936)** | **4.6 weeks** | **7 days** | **4 days** |

Three readings:

1. **The first three weeks are well paced for a casual player.** Something new every day or two, which is what the day 1 to 7 table in the onboarding scope wants. Do not cut income.
2. **An engaged player empties the shop in a week.** From then on they bank about 900 Stars a week with nothing to spend on. This is the "play forever" gap, and eggs do not close it: a no-duplicate egg of the same items costs the same total.
3. **The top price is too low for the headline item.** Kittens at 80 is half an hour of Hard rounds.

### 3.5 Adjustments

| # | Change | Effect |
|---|---|---|
| 1 | **Leave round pay, quests, gift and petting as they are.** | A generous first week is good for return rates, and the numbers were just accepted. |
| 2 | **Raise Kittens from 80 to 120**, and reserve a 160 "deluxe" tier for themes and faceplates added after launch. | The headline item becomes a two to three day goal for a casual player. One constant, before it has ever been sold. |
| 3 | **Stamp card replaces the flat gift at the same weekly total** (42 Stars a week: for example 4, 4, 5, 5, 6, 6, 12). | No inflation. The seventh stamp can become a Style Egg once that exists. |
| 4 | **Book rewards: 210 Stars in total across six pages** (35 a page), paid once. | Under a quarter of the catalogue returned for finishing it. Small against weekly income, large as a moment. |
| 5 | **Style sets: 144 Stars a month by egg, up to 285 direct.** | A renewable sink. |
| 6 | **Polish at 100 to 150 Stars per item**, about 25 eligible items at launch. | Around 3,000 Stars of optional sink with almost no art. Four weeks for an engaged player, months for a casual one. |
| 7 | **Park consumables at 2 to 3 Stars** (bubbles, confetti, a fancy ball, a treat for someone else's pet). Seen by everyone, gone when used. | The only sink that never runs out. Add with park social goals. |
| 8 | **New fixed-price content every month** worth 250 Stars or more. | Keeps a direct-buy goal on the come-back strip. |
| 9 | **Weekly Board pays once per medal** (5 / 10 / 15). | 30 Stars a week at most. A goal, not an income stream. |

With all of these, monthly sinks reach roughly 700 to 1,000 Stars before Polish. That covers a casual player (about 820 a month) and leaves engaged players leaning on Polish, medals, bond and the book, none of which need Stars to matter. That is the intended shape: Stars pace the first months, goals carry the rest.

Watch in week 1: median Stars held on day 7 and day 14. If the median wallet at day 14 is above 300, bring the 160 tier and Polish forward.

---

## 4. Save impact

v11 is being written now for ball themes and is one-way. Counters cannot be backfilled, so the cheapest moment to add them is that same bump.

| Field | Shape | Version | Notes |
|---|---|---|---|
| `ballThemes` | List of ids | v11 (approved) | No change. |
| `stats` | Map of capped integers: `rounds`, `winsEasy`, `winsMedium`, `winsHard`, `tidyWins`, `merges`, `bestChain`, `tierFive`, `itemsUsed`, `pets`, `parkGames`, `starsEarned`, `starsSpent` | **v11 (add)** | Written inside the existing fenced round and spend transactions. `totalWins` stays. |
| `stamps` | Integer count, using the existing `dailyClaimDay` | **v11 (add)** | Missing value reads as 0. |
| `book` | `{ claimed = list of milestone ids, found = bitmask of discoveries }` | **v11 (add)** | Ownership itself is read from existing lists; only claims are new. Milestone ids are never reused. |
| `styleItems`, `styleEgg` | Owned list (limit 128), last operation and receipts, like `ToyState` | v12 | With the Style Egg. Equipped merge pop and trail go in the tolerant appearance record, like `ballTheme`. |
| `bond` | Per pet `{ xp, claimed }` | v12 | Can share the bump with the Style Egg. Seeded from `stats` so launch play counts. |
| `weeklyBoard` | `{ week, best, medals }` | v12 | Same bump. |
| `polished` | List of item ids | v13 or with v12 | Small. |

Rules that carry over: every new field gets its own tolerant validator, the v10 and v11 `valid()` functions stay, unknown ids are tolerated, and the place must never be rolled back past a version players have saved on. Target: one bump at launch (v11) and one for the first post-launch batch (v12).

Quests: adding park, petting and item metrics changes `QuestCatalog`. The migration that carries `claimed`, `bonus` and `rerolled` across a `CatalogVersion` bump has to exist first, or claimed quests pay twice.

---

## 5. Build order

| # | Slice | Size | Save | Depends on |
|---|---|---|---|---|
| 1 | `stats`, `stamps`, `book` fields and validators in the v11 upgrade; counters written in round, spend, petting and park transactions | S to M | v11 | The R1 save work in progress |
| 2 | Kittens price to 120; `deluxe = 160` tier added to the price tables | S | None | Decision 4 below |
| 3 | Collection book: shared `BookCatalog` (pages, milestones, rewards), server claim action, one deck screen | M | Uses 1 | 1 |
| 4 | Stamp card on the gift-on-arrival moment from the onboarding scope | S | Uses 1 | 1, onboarding slice |
| 5 | Policy pass: percentage odds text, fixed-order eggs for restricted players | S | None | None. Before public launch. |
| 6 | Quest catalogue migration, then new metrics | S + S | None | 1 |
| 7 | Weekly Board: weekly seed, medal lines, results variant | M | v12 | 1 |
| 8 | Bear bond: levels, unlocks, Companions hub row | M | v12 | 1 |
| 9 | Style Egg: `StyleCatalog`, egg card on the Toy Egg pattern, direct buy, merge pop and trail slots, Set 1 art | M + art | v12 | 5 |
| 10 | Shelf, Polish, theme week, medals, park goals, friends board | S to M each | v12 / v13 | Above |

Slices 1 to 5 are the v1 work. Per the agent split, Astra reviews the rendered book, stamp card and egg card; Sol writes the code; each substantial slice follows the review-driven-build steps.

Risks:

- **v1 is already large** (onboarding, park, ball themes, items, world). Slice 1 is the only one that cannot wait. The book and stamp card can follow in the first patch without losing anything, because the counters will already be running.
- **Every estimate in section 3 is a model.** Win rates on Hard and rounds per session move engaged income by a factor of two.
- **A monthly content beat is a commitment.** If it slips, the shelf and Style Egg run dry. Polish and medals are the cushion.
- **Earned eggs can flood the Style set.** Cap them (for example four a week) so a set lasts about a month.
- **The Weekly Board needs every client to get the same queue from the seed**, including power-up balls. Check against the item work in R2.

---

## 6. Mockups worth drawing before the build

1. Collection book: page list with percentages, one open page, a milestone being claimed (desktop 848 x 608 and phone 812 x 354).
2. Stamp card on arrival: seven stamps, today's stamp landing, the seventh gift.
3. Style Egg card: set name, "7 of 12 left", the odds list in percentages, the direct-buy row, and the restricted "next item" version.

---

## 7. Open questions for Spencer

1. **Keep ball themes, faceplates and the Wardrobe as direct buys, and use eggs only for small set items later?**
   Recommendation: yes. Four themes are too few and too visible for a gamble, and an egg would not add a single day of play.

2. **Add lifetime counters, the stamp count and book claims to the v11 save bump now, even if their screens ship in the first patch?**
   Recommendation: yes. It is the only part of this scope that cannot be done later without losing players' history.

3. **Style Egg (after launch): Stars with shown odds and no duplicates, or an earned-only ticket?**
   Recommendation: Stars. One wallet stays one wallet, every item is also sold directly, and most eggs arrive as rewards from the book, stamp card and weekly quests.

4. **Raise Kittens to 120 and add a 160 tier for post-launch showcase items?**
   Recommendation: yes. At 80 the headline theme is half an hour of Hard rounds. Change it before anyone has bought it.

5. **Rule for scarcity: everything comes back?**
   Recommendation: yes. Shelf and event items rotate and return on a published schedule, and nothing is sold only once. The audience is all ages, and returning players who missed a week should find a reason to stay, not a reason to feel behind.
