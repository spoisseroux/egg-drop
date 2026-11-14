# Egg Drop v1 content scope: catalog and a second pet

Scoping only, 2026-11-13. No code, Studio or commits. Read against private v609 (runtime 6c77cb4) and `30ae7c1` (Reset Hue jar dropped). Income figures come from `PLAY-FOREVER-SCOPE-2026-11-13.md` §3 (about 39 Stars a day casual, 126 engaged) with petting now capped at 10 a day. Every new price below is `[PLACEHOLDER]` until week-1 telemetry exists.

**Sized for one developer, maybe two, aiming at $5–10k a month.** That is roughly 1.5–3M earned Robux a month at DevEx rates. At the 2–5 R$ per daily player typical for small cute-collect games, it means something like 10–30k daily players. That figure is a rough estimate; replace it with week-1 data. At that scale, **retention and discovery move revenue far more than catalog size.** So the rules here are:
- Rotation is generated from art that already exists: recolours, finishes, faceplate and ball variants, a shelf and egg pools that rotate on their own.
- No live-ops team, no pet roster, and no heavy per-item 3D work.
- Each item carries an **ongoing weekly cost in hours** (`h/wk`) once built.

## 1. Inventory today

| Catalog | Items | Price | How earned | Day-7 engaged player still chasing |
|---|---|---|---|---|
| Wardrobe, Bear only (`BearRigDefinition.wearableItems`) | 13 items in 7 tabs: Hat 3, Shirt 2, Neck 2, Ears 2, Eyes 2, Mouth 1, Tail 1 | 15 / 30 / 60, 360 total | Stars, direct | Nothing |
| Faceplates (`DeckThemes`) | 8 free starters, 8 sold, 1 book-only (Bookworm) | 20 / 40 / 80, 340 total | Stars direct; Bookworm for finishing 3 book pages | Bookworm |
| Ball themes (`BallThemes`) | 2 free, 4 sold | 20 / 40 / 40 / 120, 220 total | Stars, direct | Nothing |
| Toys (`ToyCatalog`) | **3** (Ball, Bone, Sparkler) | Toy Egg 8, no duplicates | Egg, odds shown | Nothing. **Thinnest catalog** |
| Finishes (`MaterialCatalog` pool v2) | **2** (Gloss, Matte; Metal retired from pool) | Material Egg 16 | Egg | Nothing |
| Features (`FeatureCatalog`) | Horns 50%, Claws 35%, Wings 15%; 5 stages, stacks to 99 | Feature Egg 32 | Egg, repeatable | Wings stage 5 (a real sink) |
| Hue (`HueCatalog`) | 4 fruits, 6 mixes, 3 ranks | Hue Egg 8, 25% each | Egg, repeatable | Ranks and mixes (small sink) |
| Charms (`PetCharmCatalog`) | **3** free shapes | Free | Customize | Nothing |
| Deck backgrounds | 3 | Free / rule-gated | Rules (High Roller, rank II) | Maybe one |
| Book (`BookCatalog`) | 5 pages (Pets page stays closed until a 2nd pet exists), 11 Discoveries | 35 a page, 175 now | Milestones | Hard-win Discoveries |
| Stamp card | 7 stamps | 4,4,5,5,6,6,12 | One per day played | Endless, flat |
| Quests | 24 daily, 12 weekly | 4 / 10, +5 for clearing all weeklies | Play | Endless, flat |
| Pets (`PetCatalog.active`) | **1** (Bear, id `pip`) | Granted in onboarding | Onboarding | Nothing |

One-time sinks total about **976 Stars**. An engaged player clears them in about 7 days; a casual one in about 4.6 weeks. Thin spots: 3 toys, 2 finishes, 3 charms, 1 pet, 1 mouth and 1 tail. Nine authored slots are empty: Eyewear, Nose, Forehead, Cheek, Chest, Wrist, Ankle, Aura and Earring.

**Free find:** `Round Eyes`, `Small Wide Eyes` and the `W` mouth are already exported as Bear attachments (`EyeL_AltRound`, `EyeL_AltSmallWide`, `Mouth_AltW`), but they are missing from `wearableItems`. Selling them costs only a manifest entry.

## 2. Catalog expansion for v1

Aim: one-time sinks go from about 976 to about 2,000 Stars, or about 2,250 with the second pet's refits. That is roughly 2.5 weeks for an engaged player and 10 for a casual one. After that, a rotation generated from existing art keeps the shop moving at about 1–2 h/wk. Repeatable sinks (Feature, Hue, and Polish later) cover anything beyond that. Everything here is cosmetic, fixed-price or a no-duplicate egg with shown odds, with no stat effect. All art is made by hand or by script in Blender, with no generated art.

**Wardrobe +15 (Bear)**, pipeline `assets/art-source/pets/pet-bear-attachments.blend` → `scripts/build_bear_attachments.py`, per-item `WearableCatalog.Fit`:

| Item | Slot | Price | Art |
|---|---|---|---|
| Round Eyes, Wide Eyes | Eyes | 15, 15 | none (exists) |
| Kitty W | Mouth | 15 | none (exists) |
| Toothy Grin | Mouth | 30 | S |
| Round Specs / Heart Shades | Eyewear (new tab) | 15 / 30 | M |
| Blush Stickers | Cheek (new tab) | 15 | S |
| Friendship Bands | Wrist, per side (new tab) | 15 | S |
| Jingle Anklets | Ankle, per side | 30 | S |
| Party Hat / Bucket Hat | Hat | 15 / 30 | M each |
| Bow Tail | Tail | 30 | S |
| Acorn Pendant | Neck | 30 | S |

Total 315, 13 items. New tabs need UI only (`WearableCatalog.Tabs`); the slots, anchors and exclusions already exist. The 3-piece Raincoat and the Top Hat were cut as too heavy per item for a solo developer.

**Recolour variants: the main source of rotation (best value per hour).** Every wearable already has an `own:#hex` main colour. One small code change (M, once) adds a variant id that points at a base item's meshes with a colour override, for example `beanie_mint` → `beanie` + `#7FE0CF`. After that, each variant is a single data line with no Blender work, about 0.25 h including a capture check. Launch with 10 variants at the base item's tier price (for example Beanie ×3, Tee ×3, Bell Collar ×2, Sun Hat ×2), adding 210 Stars. Rotate 3 new variants into the shelf each week (0.5–1 h/wk).

**Faceplate and ball theme variants.** `build_faceplates.py` and the `BallThemes` ramps are parameterized by script, so a palette swap of an existing plate or theme is S (about 1 h). Hand-built finishes are M.

**Faceplates +4** (`scripts/deck_art/build_faceplates.py`): three sold at 20, 40 and a new deluxe 160 tier, plus one book-only plate for the Pets page or Discoveries. Make at least two of them palette variants of existing plates. Adds 220, 0 h/wk.

**Ball themes +2**: one ramp variant at 40 (S) and one deluxe at 160 (M, for example "Ducklings"). Adds 200, 0 h/wk.

**Toy Egg pool v3 +4** (8 each, pool shrinks as items are owned, `PoolVersion` bump already supported): Wobble Top, Bubble Wand, Squeaky Carrot, Mini Plush. S–M each if they reuse the generic hold-and-play pose. Adds 32.

**Material Egg pool v3 +2** (16 each): Pearl Edge and Speckle Satin, through `BuildPetMaterialTemplates`. M each. Adds 32.

**Charms +3 earned shapes**: Heart (book Wardrobe 100%), Star (weekly bonus ×4), Leaf (stamp 14). S each. These add goals, not sinks.

**Discoveries +6 bits** (11 → 17, bit limit 30): pet at night, Play date with another player's pet, a full outfit worn, win with each item type, 25 tidy wins, 100 rounds. S, reads `LifetimeState`.

**Second pet's wardrobe:** 10 refits of existing items at the same prices, about 250. See §3. Recolour variants carry over to the second pet for free once its base item fits.

Every item in this section costs 0 h/wk after it ships. Only the shelf rotation (§4.2) has an ongoing cost.

## 3. Second pet: yes, earned, and ready by day 7

**Recommendation: build exactly one, then stop.** For 1–2 people, one pet on the Bear's shared base is realistic, at about a week of focused work. Each further pet costs the same again plus a refit for every wearable, so no roster plan. Ongoing cost is 0 h/wk. The second pet is the only content that answers "what happens after the accessories": a new face to dress, a new Pets book page (35 Stars, auto-opens at `PetsPageMin=2`) and a new reason to set a goal. Make it **earned, not bought**: it arrives when the player's **first stamp card is complete** (7 days played, not consecutive). That makes it a built-in D7 hook, and the art only has to be live by the first week-1 update, not on launch day. Keep the Companion Egg retired. Earning the pet avoids paid-random-pet policy issues and keeps pets out of the shop.

Concepts. All three sit on the Bear's shared plush base, about 1.5k triangles:

1. **Blip, the green toy alien (recommended).** Spencer's stated next pet. The brief is already in `PET-STYLE-GUIDE.md` §9. Soft green with a mint secondary. Two stubby antennae with ball tips take the ear roles, so ear flicks become antenna wiggles, and at night the tips glow softly. Quirk: it copies the Bear's last gesture a beat late. Original as long as the guide's "no three eyes, no grey almond head" rule holds.
2. **Sprig, the seedling.** A round plush with two leaf ears and a curl sprout on top that perks up when petted and droops when sleepy. Peach body, leaf-green secondary. It fits the garden best.
3. **Puff, the cloud.** A three-bump cloud head and a raindrop tail. It swells when happy, using the torso squash channel. Cream with a pale-sky secondary.

The lilac mochi mockup (`artifacts/new-pet-1-mockup/`) is still waiting for review. It is sized to `newPet1`, which reads as Chao, so treat it as a resemblance risk.

**Already built:** owned-pet switching (`CompanionsHub` Pets selector), per-pet wardrobe, hue and materials, the auto-opening Pets page, and spare collection bits (append index 8; never reuse retired ids).

**Needed:** a rig definition and import; garden, park and petting poses checked against the new silhouette (`ParkPoseData`, `GardenCarePoseData`, `PetIdleBeats`); a portrait and book icon (`render_book_icons.py`, `build_book_atlas.py`); per-pet `Fit` offsets; a server grant on the 7th stamp, modelled on `Hatching.grantStarter`, with an idempotent receipt; and reveal or "a friend arrived" copy.

**Code that assumes one pet (about 25 sites):**
- Server: `HatchProgress.lua` 779–851 (`MeetPipFirst`, a starter grant that only grants `pip`); `init.server.lua` 99, 352–354, 408–409 (pip-only `equipCompanion` and family defaults).
- Client: `CompanionsHub` 128/135/235/409 and `WardrobeShop` 144/681 (fall back to `"pip"`); `DeckMenu` 22/56/69; `init.client.lua` 1071/1929/2010/2636; `FirstHatchGuide` 92; `HueEggView` 66 (`petId="pip"` hard-set).
- Per-pet special cases: `RoomView` 476/482/658 and `HatchCinematic` 25 (greeting support limited to pip/puddle); `GardenPetVisual` 378 (squash only on pip); `PetPortrait` 52 and `FamilyCrest` 18/50.
- Data: `HueCatalog.Supported` (new id), `WearableCatalog.Fit.bear`, and `FamilyMastery` (hardcoded legacy rare ids).

**Cost (honest):**

| Work | Size |
|---|---|
| Art: model and rig | L, 2 sessions |
| Art: 10 wardrobe refits | M, 1 session |
| Art: portraits and icons | S |
| Code: generalize one-pet assumptions | M, 1–2 sessions; worth doing even without the pet |
| Code: grant and reveal | M, 1 session |
| QA: poses in garden, park and petting, phone and PC | 1 session |

Total about 6–8 agent sessions, roughly a calendar week with review.

## 4. Retention and revenue

### 4.1 Reasons to return

| Day | What pulls a player back | Gap |
|---|---|---|
| D1 | Stamp 2, three fresh daily quests, petting cap reset (10), Play date +4, "Tomorrow" line, an affordable 30–60 item | Nothing about the pet changes overnight |
| D3 | Book 25/50% milestones, a 60–120 headline item | No surprise or reveal |
| D7 | Stamp 7 (12 Stars), weekly reset and bonus, Bookworm plate | **Engaged players have bought everything**; nothing new arrives |
| D30 | Nothing | **No rotation, no pet growth, no events.** Biggest hole |

### 4.2 Proposals, ranked by retention value per build cost

| # | Proposal | What it is | Retention | Build | h/wk |
|---|---|---|---|---|---|
| 1 | **Bond levels 1–10 per pet** | Gained from petting, rounds with the pet, park games and toys. Each level unlocks something you can see: a trick (sit and wave from `PetSitPose`, spin, flop), a greeting, a nap spot, an earned charm shape at 5, a bond-only recolour at 10. Replaces the dormant `FamilyMastery` ranks (Sprout/Grove/Bloom) under a clear name. Pace is 2–4 weeks to level 10. Nothing to buy. | High (D3–D30) | M | 0 |
| 2 | **Auto-rotating weekly shelf** | Three items a week, picked by the week-seeded RNG from the catalog plus recolour variants, at about 20% off. Items always return, so there is no fear-of-missing-out pressure. No hand curation needed. | Medium (D7/D30) | S | 0–1 (optional new variants) |
| 3 | **Weekly Board** | One board a week, seeded from the week number (no hand-made levels), bronze/silver/gold medals paying 5/10/15, unlimited tries. The 2x pass must not change medal lines. | High | M | 0 |
| 4 | **Second pet on the 7th stamp** | §3 | High (D7) | L | 0 |
| 5 | **Rotating limited egg pool** | Each month a "Colour Egg" of 12 recolour variants: 12 Stars, no duplicates, odds shown, all also sold directly, returns later. Replaces the Style set's new art with variants. | Medium–high (D30) | M once | 1 (pick 12 colours monthly) |
| 6 | **Treat for a friend's pet** | A 2–3 Star park consumable used on the spot on another player's pet. Both players see hearts, and the giver earns bond. Nothing tradable changes hands, so it stays within the no-trading rule. | Medium | S–M | 0 |
| 7 | **Show-off moments** | A "Visit" button on a player in the park that frames their pet and outfit, plus a deck/faceplate glimpse on the bench. | Low–medium | S | 0 |

Not recommended at this scale: theme weeks, hand-built events and a season track. Each needs about 5+ h/wk of live operations.

### 4.3 Monetization

What exists (`StoreCatalog`, `StoreService`):

| Product | Price | Notes |
|---|---|---|
| 2x Stars pass | 299 R$ | |
| Supporter pass | 99 R$ | +1 Star per round |
| Starter pack (once) | 49 R$ | 40 Stars |
| Star packs | 39 / 99 / 199 / 499 R$ | 20 / 60 / 140 / 400 Stars, a sound value ladder |

Eggs are Star-bought, so they count as paid random items. Odds are shown, and restricted players get a fixed "next item" through PolicyService, which fails closed. This matches the norms for cute collect games and stays cosmetics-only. The 2x pass only speeds up cosmetics in a non-competitive game, which is fine, but keep it off the Weekly Board.

Three additions, best first:

1. **Fixed-price Robux cosmetic bundles.** For example, "Rainy Day": Bucket Hat + 2 recolours + a faceplate variant for about 149 R$, with the contents shown and nothing random. Kids buy named things more readily than currency. Expected impact is moderate and unmeasured. It reuses §2 art and needs no new policy surface. About 0.5 h a month for a new bundle.
2. **Private servers at 25–50 R$.** Cheap, common for social games, and good for friend groups in the park. Small revenue, 0 h/wk.
3. **A Premium perk.** For example, a monthly Premium-only recolour plus `PromptPremiumPurchase` on the store page. This raises engagement-based Premium Payouts. Small but passive; about 0.25 h a month.

Honest read: revenue at this target is set mostly by daily players (retention plus discovery: thumbnails, icon, sponsored ads tested on small budgets), not by adding SKUs.

Not recommended: paid pets, paid luck, an energy refill, or a paid season lane.

### 4.4 Metrics to instrument before launch

D1/D7/D30 retention and revenue come from Creator Analytics automatically.

**Already logged:**
- `EconomyAnalytics`: Stars sources and sinks by SKU (round by heat, quests, Play date, petting, welcome, IAP packs, wearables, faceplates, ball themes, egg actions).
- Custom events: `RoundWon`/`RoundLost`, `StoreOpened`, `PassPurchased_*`.
- Onboarding funnel (`FirstSession`): 4 steps plus `FirstSessionLoungeVisit` and `FirstSessionRoundRetry`.

**Must add:**
1. **Rebuild the onboarding funnel** around the current flow: welcome card → first drop → first merge → first round finished → Bear met → walkthrough beats 1–3 → first quest claimed → first purchase → second round started. The current step 4 is still named "Pip hatched", and step 4 also fires from line 357.
2. **Egg opens**: `EggOpened_<type>` with the result SKU, so the odds can be audited against what players actually got.
3. **Firsts**: `FirstStarsSpend`, `FirstWardrobeEquip`, `FirstRobuxPurchase` (with the product key).
4. **Engagement**: `BookMilestone_<id>`, `StampAdded` with the count, `PlayDateDone`, `PettingCapReached`, and `RoundsThisSession` on leave.
5. **Economy health**: the wallet balance on session end, so the day-7 and day-14 median wallet can be checked against the 300-Star "bring sinks forward" trigger.

## 5. Build order

| Slice | Art (Astra / Fable) | Code (Sol / Opus) | Parallel? |
|---|---|---|---|
| A | none | Sell the 3 existing eyes/mouth; analytics events (§4.4) | Start now |
| B | Wardrobe batch (S items first) | **Recolour variant system** plus 10 variants; new tabs (Eyewear, Cheek, Wrist, Ankle); `Fit` entries | Yes |
| C | 4 faceplates, 2 ball themes (mostly palette variants) | Deluxe 160 tier; book-only plate #2; auto-rotating shelf | Yes |
| D | 4 toys, 2 finishes | Toy pool v3, Material pool v3; earned charm shapes; +6 Discoveries | Yes |
| E | Blip model, poses, portrait | Generalize the ~25 one-pet sites (needs no art), 7th-stamp grant | Code can start at once |
| F | Bond unlock art (tricks reuse poses) | Bond levels 1–10 | After E code |
| Post-launch | none | Weekly Board, monthly Colour Egg, bundles, private servers | Weeks 2–4 |

Steady state after launch: about **1–2 h/wk** (shelf variants, a monthly Colour Egg list, a bundle), plus fixes.

**Cut order if time is short:**
1. The deluxe ball theme.
2. Finishes v3.
3. Bond levels 6–10 (ship 1–5).
4. Blip moves to the week-1 update. Its unlock is at D7 anyway, so the only loss is a launch-day teaser.

Never cut slice A or the one-pet generalization.

## 6. Open questions for Spencer

1. **How is the second pet earned?** Recommended: free on the first complete stamp card, with no Stars or Robux price.
2. **Which concept: Blip, Sprig or Puff?** Recommended: Blip (your stated direction, brief already written).
3. **Should a wardrobe item bought for the Bear be owned again for the new pet?** Recommended: yes, per-pet as built, with 10 refits at launch.
4. **Do bond levels ship in v1?** Recommended: levels 1–5 in v1, 6–10 in the week-2 update.
5. **One fixed-price Robux bundle and private servers at launch?** Recommended: yes to both. No random Robux items.

## Summary

1. The launch shop is about 976 Stars. Engaged players clear it in about 7 days; toys (3), finishes (2), charms (3) and pets (1) are the thinnest catalogs.
2. Three wardrobe items (Round Eyes, Wide Eyes, W mouth) are already modelled and only need manifest entries.
3. Sized for a solo developer at $5–10k a month: a recolour variant system is the main source of rotation. Add 13 light wearables, 10 recolours, 4 faceplates, 2 balls, 4 toys and 2 finishes (about 1,000 Stars), at 0 h/wk once built.
4. Add earned goals: 3 charm shapes, 6 Discoveries and a second book-only plate.
5. Second pet: yes. Blip the green toy alien, granted free on the 7th stamp, which is a built-in D7 hook.
6. The pet costs about 6–8 agent sessions; generalizing the ~25 code sites that assume one pet should start now.
7. The biggest retention gap is D30. Bond levels 1–10 are the best value per cost and answer "what after accessories".
8. Next by value per cost: an auto-rotating shelf, a seeded Weekly Board, a monthly Colour Egg with odds shown, and a park treat for a friend's pet. Total upkeep is about 1–2 h/wk.
9. Monetization is sound as built. Add a fixed-price Robux bundle, private servers and a Premium perk; no paid pets or luck.
10. Before launch, rebuild the onboarding funnel and log egg opens, firsts, book, stamps, Play dates and end-of-session wallet.
