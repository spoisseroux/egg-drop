# Egg Drop

A merge-physics pet collection game. Players drop eggs into a board; matching
eggs merge and build a combo. Clearing a combo awards coins and a chance at a
pet egg hatch. Pets, coins, and rebirths carry all long-term progression.

## Core loop

1. Enter board (Suica-style drop zone, physics-driven)
2. Drop eggs; same-tier eggs merge into the next tier; chain merges build a
   combo multiplier
3. Clearing a combo awards soft coins and charges the "hatch meter"
4. Full hatch meter rolls a pet egg
5. Pets multiply coin income; coins buy board powerups and more eggs
6. Rebirth resets tiers/coins for permanent multipliers

## Progression & economy

| Parameter | Value |
|---|---|
| Egg tiers | 12 (common -> mythic) |
| Coins per merge | tier^1.35 * comboMult (1.0 - 2.5) |
| Coin upgrade cost curve | cost = base * 1.15^level |
| Rebirth requirement | tier 8 reached + coin wall, scaled x2.4 per rebirth |
| Rebirth multiplier | +25% coin rate per rebirth (multiplicative) |
| Idle coin rate | 40% of active rate, accrues offline up to 4h |

## Pets

Pets are permanent multipliers with rarity tiers.

| Rarity | Chance | Coin multiplier |
|---|---|---|
| Common | 55% | x1.05 |
| Uncommon | 25% | x1.15 |
| Rare | 14% | x1.30 |
| Epic | 4.5% | x1.75 |
| Legendary | 1.4% | x3.00 |
| Mythic | 0.1% | x8.00 |

- **Pity:** 120 hatches without Legendary/Mythic -> next hatch guaranteed
  Legendary or better. Pity counter shown to the player.
- Odds for every egg are displayed on the egg UI before purchase (store
  policy compliance for paid random items).
- Duplicate pets merge into pet levels: 3 dupes -> level up (x1.5 pet power).
- Weekly limited egg with its own pool, rotates every 7 days, visible
  countdown.

## Engagement systems

**Daily streak**

- Rewards escalate D1-D7 (small coins -> exclusive pet), reset to D1 on a
  miss. Streak is displayed as owned progress ("Day 4 - don't lose it!").
- One grace restore per week via Robux or a large coin cost.

**Limited-time shop**

- Rotating powerup bundle rotates every 4 hours with countdown on every item.
- Weekly limited egg pool: last-season pets do not return for at least
  90 days (real scarcity, published in advance).

**Hatch celebration**

- Every hatch above Rare triggers a server-wide announcement with player
  name, egg type, and pet.
- Rare hatch produces a board-wide particle burst visible to all players.
- Hatch meter fills fastest right before completion; a "nearly there" state
  shows glowing progress bar.

**Sessions**

- Daily quests: 3 quests, refresh at 2pm EST, tiered final reward (D1-D7
  completion track).
- Offline earnings modal on login ("While you were away: +N coins") with
  an instant-collect-with-multiplier option.

## Monetization (Robux)

All purchases are through Roblox dev products / gamepasses. No purchase
dialog is triggered automatically more than once per session; every prompt
is player-initiated from a UI element.

| Product | Price | Effect |
|---|---|---|
| x2 Coins gamepass | 199 R$ | Permanent 2x coin rate |
| x2 Luck gamepass | 249 R$ | Permanent 2x pet luck |
| Auto-Merge gamepass | 299 R$ | Auto-merges tier-1 and tier-2 eggs |
| VIP gamepass | 499 R$ | 1.35x coins, chat tag, VIP pet (exclusive, seasonal) |
| Coin topup | 50-1000 R$ | Scale-discounted coin packs (bigger = better rate) |
| Streak freeze | 99 R$ | Preserves daily streak for one missed day |
| Hatch now | 49 R$ | Instantly completes the hatch meter |

Rules for purchase prompts:

- One soft-offer per session maximum (a single dismissible "starter pack" on
  first session, never repeated after purchase)
- All gamepass benefits are permanent and clearly described on the store UI
- Odds are always visible on any product with randomized contents
- Prices use fixed Robux tiers, no countdown on the starter pack

## Non-negotiables

- Server-authoritative: coin, pet, and merge calculations run on the server
  only
- All purchases must be idempotent (store receipt GUIDs)
- No player-visible mechanic may differ from displayed odds

## Tech

- Rojo 7 project layout (src/server, src/client, src/shared)
- selene for linting, StyLua for formatting, wally for packages
- DataStore v2-style versioned saves, ProfileService pattern
- Rate limiting on every remote event
