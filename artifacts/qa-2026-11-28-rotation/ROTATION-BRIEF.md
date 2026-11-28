# Daily picks: the Outfit Egg, colours, rarities (Fable, 2026-11-28)

Spencer's ask: items roll every day, one colour of an item at a time, rarer ones less likely, tap the odds to preview today's items, onboarding teaches it. This brief is buildable tonight. Every number is `[PLACEHOLDER]` until played.

**What the player feels:** "What's in the egg today?" A small, readable rack that is different each day, a real chance at something shiny, and no fear of missing out: nothing counts down, everything comes back.

## What the code allows (read first)

- A recolour is already an item id (`WearableVariants.Rows`), drawn as the base mesh with `part.Color` (`PetAttachments.build`, `WearableCatalog.renderMap`/`tintFor`). One asset, many colours, no new art.
- Older builds accept unknown wearable ids in `petWearables.owned` and draw nothing for them (`WearableState.valid` checks shape only). **Hard limits every build enforces: 128 owned per pet, ids up to 32 chars, `^[a-z][a-z0-9_]*$`.** A 129th item fails the load on every build.
- Paint Egg and Toy Egg receipts pin a pool version and exact quote keys (`LookState` line 69, `ToyState.poolValid`). A new pool version on tonight's build makes an older build reject the save. **So nothing tonight changes `LookEggCatalog.PoolVersion`, `Tables`, `PityAt` or `ToyCatalog.Pools`.**
- The safe pattern for a new grant is the gift chain's: one optional, tolerant field, one `transact`, no reservation (`Hatching.giftEgg`).
- Restricted players (`PaidRandomPolicy`, `handle.restricted`) never roll; every egg has a `fixedNext`.
- Particles and Highlights do not draw in ViewportFrames. `SurfaceAppearance` cannot be parented at runtime.

## 1. The model

### Eggs after this
| Egg | Tonight | Holds |
|---|---|---|
| **Outfit Egg** (new, id `outfit`) | build | today's 8 clothes picks + 1 sparkle pick, 25 Stars |
| Paint Egg (`look`) | unchanged | pots, shine, charms. Its daily odds shift and the charm change are **later** (below) |
| Toy Egg | unchanged; toy colours are lane D behind their own switch | |
| Snack Egg | unchanged | |
| Deck styles | **no egg** | plates and ball themes are painted textures, not recolours, so there is no colour to select. Later: a Deck Egg that deals existing plates daily |

Wardrobe with the switch on: a closet. It lists what the pet owns and one link, "More at the Outfit Egg". It sells only level-gated rows (earned goals stay) and the This week pick (unchanged). Switch off: today's Wardrobe exactly.

### The day
`DailyContracts.dayOf(now)`: the game's existing day (rolls 05:00 UTC, the same moment as stamps and daily quests). Same for everyone, server clock only. The client never picks from its own clock; it draws the snapshot.

### The rack (pure, `shared/DailyRack.lua`)
Egg rows are appended to `WearableVariants.Rows` with three new fields: `egg=true`, `rarity`, `finish` (optional). They are never listed for sale (the `weekly` plumbing: listed under `math.huge` and once owned). Base items join the rack as themselves (rarity from tier: common→common, rare→rare, showcase→epic). The ten ungated recolours already shipped join as common.

- **Bases:** every rig item of the pet that is out (Bear: 23). `P = ceil(#bases/8)` days make one cycle (Bear: 3).
- **Today's 8:** in cycle `c = floor(day/P)`, sort bases by `hash(c, baseId)` (FNV-1a, a copy of `WeeklyShelf.hash`) and deal 8 a day; the short last day wraps to the cycle's start.
- **One colour per base:** each base's colour list is sorted by `hash(0, rowId)`; this cycle it shows `list[(c mod n)+1]`. A hat is on the rack in exactly one colour, and that colour changes next cycle.
- **Returns:** every base returns within 3 days; every colour of it within `3 × n` days (n ≤ 8, so 24 days at worst). The UI says "They come back." A spec proves no row is absent over 24 days across a year of days.
- **Sparkle pick:** one legendary row a day, `Sparkle[(day mod #Sparkle)+1]`.

### Rarity and odds (exact)
Weight per rack item: **common 18, uncommon 12, rare 6, epic 2**. The sparkle pick is a **flat 1%**, never renormalised upward.
Odds = the weights of today's rack items the pet does not own yet, scaled to 99% (100% once the sparkle pick is owned). Shown through `OddsText.list` with its rounded note. A typical fresh day (3 common, 2 uncommon, 2 rare, 1 epic): 16.5% / 11% / 5.5% / 1.8% each, sparkle 1%.

**No duplicates, ever.** Owned items leave the pool (the Toy Egg's rule), so nobody pays for something they have and no Stars conversion is needed. When the pet owns all 8 rack picks the egg rests: "You have today's picks! New picks tomorrow." It never sells a 100% sparkle: legendary is never guaranteed. The rack is also a natural daily spend cap (8 × 25 = 200 Stars).

Restricted players: `fixedNext` = the first unowned rack item, common first, data order. The sparkle pick is not on the fixed path tonight (open question for Spencer: sell it to them at a fixed 400 Stars later).

### Colours tonight (Bear and Bunny share the rig items)
16 colourable bases (own-colour main piece: beanie, sunhat, flowercrown, partyhat, tee, hoodie, beads, bellcollar via `piece`, ring, starstud, sparkle, blush, bowtail, acorn, bands, specs). **4 new rows each = 64 rows**, id `base_colour`:
- common (one of): Cherry `#E9574C`, Sky `#5CBEF5`, Mint `#7FE0CF`, Butter `#FFD86B`
- uncommon (one of): Grape `#9B7BE8`, Bubblegum `#FF86C8`, Tangerine `#F08A3C`
- rare: Midnight `#2F2C7C`, or Snow `#F4F6FB` on dark bases
- epic: Gold `#F0B429`; Rose Gold `#F2A0A8` where the base is already gold (ring, starstud, specs)

Skip a colour an existing row of that base already uses (`Variants.problem` catches a duplicate id). Face items (eyes, mouth) stay one row each.

**Cap check:** 23 base + 24 shipped variants + 8 weekly + 64 + 5 sparkle = 124 ≤ 128. The server refuses a roll at 128 owned (`ClosetFull`, no charge). More colours need an overflow field first: later.

### Sparkle picks: animated finishes (legendary, 1%)
Five tonight: `beanie_rainbow`, `bowtail_rainbow` (finish `rainbow`), `hoodie_aurora`, `partyhat_aurora` (`shimmer`), `flowercrown_stardust` (`sparkle`). Each returns every 5 days.

How (client only, new `WearableFinish.lua`, one shared stepper at 10 Hz, at most 24 parts):
- `shimmer`: `part.Color` eases between two hexes on a 2.4 s sine (aurora: `#6FD0F0` ↔ `#B58CFF`).
- `rainbow`: hue turns once in 6 s at S .55, V 1 (pastel, never strobing).
- `sparkle`: one ParticleEmitter on the main piece (rate 3, `sparkles_main.dds`, the Sparkler's recipe), colour Snow.
- Reduced Motion or Reduced Effects: a still mid colour, no particles.
- In ViewportFrame previews the colour motion works; particles do not, so cards add a 2D `UISparks` overlay.
- Not used: Highlight (31-a-client cap, crowded gardens) and Neon (wearables never glow at night, style guide 6). A scrolling foil needs a `TextureID` flipbook on UV-matched meshes: later, verify in Studio first.

**Angel Wings and charms.** Angel Wings becomes a sparkle pick once it has a wearable mount (the cherub's folded wings and halo exist only in `DriftLanternsClient`/`PetFeatureGeometry`; it needs a Back slot in the rig data). Reserve the id `angelwings`; art lane, not tonight. Charms stay in the Paint Egg tonight at their shown 2%. "Never guaranteed" means removing `PityAt`: that is a pool change older builds reject, and players mid-streak were promised a charm. Later, with an architect review: pool version 2 once the rollback floor accepts it, and anyone with misses saved keeps the old promise until their next charm.

### Paint Egg daily odds shift (designed now, built later, same blocker)
Pots always total 68%. "Today's splash" = `RollOrder[(day mod 4)+1]` at **23%**; the other three **15%** each. No pot ever under 15 or over 23; each is the splash every fourth day. Shine and charm rows never move.

## 2. Colour selector

**Dress up → Outfit** (`WardrobeShop`): one card per base item. The pane shows a row of round swatches, one per colour of that base the pet owns (28 px, 8 px gap, a ring on the worn one; a sparkle colour's swatch animates). Tap a swatch = wear it: the existing `equipWearable(petId, slot, variantId)`, no server change. Unowned colours are not drawn as locked slots (no wall of things you lack). Under the row, soft text: "More colours come from the Outfit Egg."

**Toys** (lane D): the same swatch row in `ToyPanel`; new op `toySkinWear`. **Deck styles:** none (above).

## 3. Odds list → today's picks

In `EggHatchView:paintEggPane` for `outfit`: the label reads **TODAY'S PICKS** (not ODDS); each row is a button: colour dot, name, rarity pill, percent. Above the rows, one calm line: "New picks every day."

Tap any row (gamepad Y) → the **Today's picks sheet** over the pane (`RackPicks.lua`): cards 2 across on phone, 4 on desktop. Each card: a ViewportFrame of your pet wearing the item (`PetFactory` + `PetAttachments`; at most 6 live, the rest lazy), name, rarity pill (Common grey, Uncommon green, Rare blue, Epic purple, Sparkle gold with `UISparks`), percent. Owned cards show a tick and "Yours", no percent. The tapped row's card opens focused. Footer: "Missed one? They come back." Close returns to the pane.

**Kid-safety decision:** no countdown, no clock, no "last chance", no "only today". "New picks every day" tells the truth about change; "They come back" removes the loss. A ticking timer would turn curiosity into pressure, so the day is never shown as time left. The machine may show a small "New" dot until the shop is opened that day (client-local, no number).

## 4. Onboarding

Chain order: **Outfit (new, first) → Paint → Toy → Snack.** Outfit takes Paint's trigger (the tuck). Paint needs the Outfit record and takes Toy's old trigger (2 rounds or a later day). Toy needs the Paint record plus the same rule counted from it. Snack unchanged. A save that got Paint under the old order is simply owed the Outfit gift next. The `dress` lesson stays tied to the Paint gift.

The Outfit gift is not random and says so: "A gift: Pom Beanie, 100%". The server grants `beanie` (else the rig's first common Hat) to the pet that is out and wears it in the same write.

**Teaching the tap** (in the shop, free egg open; `GiftShop.aim` gains `"odds"`):
1. Mitten on the Outfit tile (today's "pick").
2. Mitten glides to the first row of TODAY'S PICKS, label **"Tap to see today's picks!"**
3. The sheet opens with the gift pinned first ("Your gift") and today's rack under it, one line: "New picks every day." Button: "Got it".
4. Mitten glides to **Hatch free!**

It never blocks: Hatch free! works at any step and ends the lesson. Latch: a new `CoachMarks` bit `picksSeen` (append-only; older servers keep unknown bits). All eggs crank: the Outfit Egg plays the machine crank and emerge before its card.

## 5. Data and authority

- **Switch:** `FeatureFlags.DailyRack` (beta place or Studio) + ConfigService `daily_rack` + attribute `DailyRack_on`: the `ThisWeekConfig` pattern. Off = today's game, nothing read or written.
- **Grant:** `Hatching.rackEgg(handle, "outfit", {petId, day})`, shaped on `giftEgg`. The client sends the day it showed; a different server day answers `DayChanged` with no charge and a fresh snapshot. The candidate freezes `day`, `petId`, `unit`, `fixed`; the write recomputes the pool from the save, rolls, appends to `petWearables[pet].owned` (an existing field), debits Stars and records the op.
- **New optional field** (never in `valid()`, tolerant, fails closed, unknown keys kept; the `gifts` pattern):
  `rack = { v=1, last={op, egg, pet, item, rarity, day, seen?}, ops={last 16 op ids}, toy={owned={skinId=true}, worn={toyId=skinId}} }`
- **Older builds and live:** they ignore `rack` and keep it on save, hold the new wearable ids unseen, and keep `gifts.outfit` as an unknown key. Nothing existing is rewritten.
- **Snapshot** (owner only, switch on): `public.rack = {day, price, outfit={pet, mode, next?, rest?, items={{id, rarity, percent, owned}}, sparkle={id, percent, owned}}}`. The client draws only this.
- **Broken means:** shown odds differ from a 100k-roll spec on any of 30 days; any row gone over 24 days; a roll charged for an owned item; a fresh player unable to afford one egg by the end of session two.

## 6. Tonight: lanes (no shared files)

| Lane | Must | Files |
|---|---|---|
| **A. Core (server)** | rack maths, rows, grant, snapshot, switch, Outfit gift, specs | new `shared/DailyRack.lua`, `server/RackState.lua`, `server/RackConfig.lua`; `WearableVariants.lua`, `GiftEggs.lua`, `CoachMarks.lua`, `FeatureFlags.lua`, `HatchProgress.lua`, `init.server.lua` |
| **B. Shop and onboarding (client)** | Outfit tile, tappable rows, picks sheet, reveal after the crank, pointer step, all copy | `EggHatchView.lua`, `GiftShop.lua`, `GiftChain.lua`, new `RackPicks.lua`, `RackPreview.lua`; `UICopy.lua`, `init.client.lua` |
| **C. Wear and finish (client)** | swatch selector, closet mode, finishes on pets | `WearableCatalog.lua`, `WardrobeShop.lua`, `PetAttachments.lua`, new `WearableFinish.lua` |
| **D. Toy colours (only if A is green)** | skins data, recolour, swatches; own switch `rack_toys` | new `shared/ToySkins.lua`; `PetToyGeometry.lua`, `ToyPanel.lua` |

Contract between lanes: row fields `egg`, `rarity`, `finish`; the snapshot shape above; copy keys `rack.*` (B owns `UICopy`; A and C send their strings to B).

**Later:** Paint Egg odds shift and pity removal (architect review), Angel Wings, Deck Egg, texture flipbook foil, overflow past 128 owned, a fixed-price sparkle for restricted players, folding This week into the rack.

Before the beta publish: translations export and sync (new row names), a `V3-TEST-PASS.md` row (switch `daily_rack`), `TODO.md`.
