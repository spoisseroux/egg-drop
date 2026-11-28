# Daily picks, slice 2: toy colours, the Deck Egg, Angel Wings (Fable, 2026-11-28)

Spencer: "finish: toy colours, deck skins in the rotation, and Angel Wings." Builds on `ROTATION-BRIEF.md` and `ARCH-REVIEW-ROTATION.md`; every rule there still holds (bound request `{day, price, mode, poolKey, requestId}`, exact integer weights, owned items leave the pool, the egg rests when today's picks are owned, no clock on screen). Every number is `[PLACEHOLDER]` until played.

## Read first: what slice 2 must not break

- `ToyCatalog.Pools`, `PoolVersion`, `PaidOrder`: untouched. The Toy Egg keeps selling toys exactly as today.
- Plates and ball themes the eggs grant are **existing catalogue ids** appended to the existing `faceplates` / ball-theme owned lists (limit 64 each). Older builds already know every id. No new deck field.
- The only new save data is inside the tolerant `rack` field: `rack.toy`, and `rack.last` / `rack.ops` reused. `validLast` needs a non-empty `pet`: toy and deck eggs write the pet that is out.
- Wearable cap: slice 1 rows + `angelwings` must stay ≤ 128 (expected 126). **Angel Wings gets no colour variants** for this reason. The spec asserts the count.

## 1. Toy colours

**The egg:** a new rack egg, id `toycolour`, shown as **Toy Colour Egg**, **15 Stars**. The tile appears in Hatch eggs once the player owns one toy. It deals colours only; toys still come from the Toy Egg.

**The deal** (new pure `shared/ToySkins.lua`, reusing `DailyRack.hash` and `Weights`): bases = the 6 toys, 3 a day, cycle of 2 days. Each toy shows one colour this cycle: `list[(cycle mod 4)+1]`, list sorted by `hash(0, skinId)`. A toy returns within 3 days, a colour within 9. A pick whose toy the player does not own is drawn locked ("Get this toy from the Toy Egg") with 0 units. Pool = today's picks, toy owned, skin not owned. Empty pool = the egg rests. No sparkle pick for toys.

Typical odds (one common, one uncommon, one rare today, all three toys owned): 50% / 33.3% / 16.7%. Restricted players: the first unowned pick, common first.

**Skins** (id `toy_colour`, 24 rows; the original colour is always the first swatch and is never a row):

| Toy | Part tinted | Common | Uncommon | Rare | Epic |
|---|---|---|---|---|---|
| `ball` | `FeltBall` | Sky `#5CBEF5` | Bubblegum `#FF86C8` | Midnight `#2F2C7C` | Gold `#F0B429` |
| `bone` | `BoneBody` | Mint `#7FE0CF` | Grape `#9B7BE8` | Midnight `#2F2C7C` | Gold `#F0B429` |
| `sparkler` | `IndigoGrip` + sparks | Cherry `#E9574C` | Mint `#7FE0CF` | Grape `#9B7BE8` | Rose Gold `#F2A0A8` |
| `wobble_top` | `TealBody` | Cherry `#E9574C` | Grape `#9B7BE8` | Midnight `#2F2C7C` | Gold `#F0B429` |
| `squeaky_carrot` | `CarrotBody` | Butter `#FFD86B` | Grape `#9B7BE8` | Snow `#F4F6FB` | Gold `#F0B429` |
| `pocket_deck` | `DeckShell` | Sky `#5CBEF5` | Bubblegum `#FF86C8` | Midnight `#2F2C7C` | Gold `#F0B429` |

Only the named part changes; seams, leaves, brass, buttons and the mint screen keep their colours so the toy still reads as itself. Sparkler sparks: `ColorSequence` from the skin hex lerped 60% to white, to the skin hex; the tip and light stay warm. Names: `<Colour> <Toy>` ("Sky Ball"); `squeaky_carrot_grape` is "Purple Carrot".

**Selector:** Customize → Toys (`ToyPanel:layoutCards`). The focused toy's pane shows the `WardrobeSwatches` row (28 px, 8 px gap, ring on the worn one): original first, then owned colours only. Tap = wear. Under it: "More colours come from the Toy Colour Egg." One wear in flight, last tap wins.

**Data:**
- Save: `rack.toy = {owned = {skinId = true}, worn = {toyId = skinId}}`. Account-wide, like toy unlocks; a toy wears one colour for every pet. At most 64 owned keys; ids ≤ 32 chars, `^[a-z][a-z0-9_]*$`; unknown keys kept; malformed = `RackBroken`, never written over.
- Ops: `rackEgg(handle, "toycolour", {...})` and `toySkinWear {toyId, skinId | "none"}` (one transact; refuses an unowned skin or toy).
- Snapshot: `public.rack.toy = {price, mode, rest, next?, total, poolKey, items = {{id, toy, rarity, units, percent, owned, locked, name, hex}}, owned, worn}`.
- Other players see the colour: the public field that carries a pet's toy id gains an optional `toySkin`. `Toys.create(parent, id, scale, skinId)`; an unknown skin draws the original.

## 2. Deck skins in the rotation: the Deck Egg

**Decision:** yes, a **Deck Egg** (rack egg id `deck`, **60 Stars**). It deals 2 plates and 2 ball themes a day from the ones sold at fixed prices today.

| Rarity | Plates (12) | Ball themes (11) |
|---|---|---|
| Common (40 today) | Aqua Pop, Lime Gel, Sorbet Sky, Grape Soda | Gumdrops, Pea Soup, Pocket Grey |
| Rare (100) | Liquid Chrome, Tidepool, Aurora Glass, Rose Chrome, Lagoon, Dewy Meadow | Gems, Planets, Bubbles, Amber, Deep Sea, Bubblegum |
| Epic (250) | Prism Flare, Night Orb | Kittens, Midnight |

**The deal** (new pure `shared/DeckRack.lua`): two lists, each sorted by `hash(cycle, id)`, 2 a day, cycle of 6 days, the short last day wraps. Everything returns within 11 days. Weights from tier as slice 1: common 18, rare 6, epic 2. Typical fresh day (1 common, 2 rare, 1 epic): 56.3% / 18.8% / 18.8% / 6.3%. **No legendary:** no plate moves, so nothing pretends to.

**No colour variants.** A plate is a painted texture with a hand-solved glass palette (`ui`, `toyShell`); a tint would muddy the art and break the contrast those palettes guarantee. The plate is the colour. The six monotone ball themes already are the balls' colour family.

**Stays earned, never in the egg:** starters (free), Bookworm and Stargazer (the Book), Sky Fizz, Storm Glass and Tangerine Pop (level goals, still at their fixed price), and all four backgrounds (their rules).

**Deck style with the switch on:** a closet, like the Wardrobe. Shell and Balls tabs list what you own, the starters and the level-goal rows; no other price buttons. One link: "More at the Deck Egg". The footer changes from "Fixed prices. No random plates." to "Plates you own stay yours." Anything already bought stays owned and simply never shows in the pool. Weekly shelf discounts on plates and balls do not show while on.

**Price check:** all 23 cost 2,480 Stars at fixed prices, 1,380 through the egg; a day caps at 240.

**Today's picks sheet** (`RackPicks`, reused): a plate card is its texture on the handheld silhouette (ImageLabel, no viewport); a ball card is its five circles (`BallThemes.circle`). Rarity pill and percent as slice 1; owned cards show "Yours". The sheet's own glass follows the **equipped** plate; each card is trimmed in its plate's `accent`. After the crank and emerge, the reveal's button is "Use it!": the existing equip path, so the deck's glass recolours at once.

**Data:** `rackEgg(handle, "deck", {...})` appends to the existing owned list for its kind and refuses at 64 (`ShelfFull`, no charge). Snapshot: `public.rack.deck = {price, mode, rest, next?, total, poolKey, items = {{id, kind = "plate" | "ball", rarity, units, percent, owned, name}}}`.

## 3. Angel Wings

**The item:** `angelwings`, "Angel Wings", slot **Back**, legendary, `egg = true`, `finish = "sparkle"`, still colour Snow `#F4F6FB`. Never sold, never gifted, never on the fixed path, no pity.

**Look (no new art):** the authored stage 5 wing meshes the Folded wings feature already uses (`WingL` / `WingR`, the existing attachment pack), drawn Snow white, SmoothPlastic, at 1.25× about their roots. Folded at rest; `PetIdleMotion.wings` already gives them the gentle idle flap (`wingSide`). Plus a **halo**: a true ring of 8 short cylinders, radius 0.13, tube 0.022, 0.12 above the head top (0.28 when a Hat is worn), `#FFE08A`, SmoothPlastic, Reflectance 0.15, bobbing ±0.02 on a 3 s sine. Not Neon, no light, no Highlight (wearables never glow at night). The existing `sparkle` finish puts one soft Snow emitter on each wing, garden pets only.

**Mount:** Back slot, max 1. While worn it hides the pet's own grown wings (a Back wearable blocks the `wings` feature); taking it off brings them back. A new closet tab "Back" appears only for a pet that owns a Back item.

**Who can wear it:** Bear (`pip`) and Bunny (`blip`): both have `WingL`, `WingR`, `Back` and the wing meshes (the Bunny inherits the Bear's). Every other rig has no template: the row is not in its pool tonight.

**Where it lives:** the Outfit Egg's sparkle pick. On days where `day mod 9 == 4` the sparkle pick is Angel Wings instead of the regular one, at the same **flat 1%**. Nine, not seven, so it drifts through the weekdays. Once the pet owns it, those days show the regular sparkle pick. All eight eggs on a wings day is about a 7.7% chance: most players wait a long time, which is the point. The other five sparkle picks now return within 10 days (update `DailyRack.spec`).

**Previews:** ViewportFrames draw the wings and halo as still parts (posed once, `CardPreviewCache`); the card adds `UISparks`. Camera pulls back 15% and turns the pet 35° so the wings read from the front.

**Reduced Motion / Motion: Low:** no flap, no halo bob, the still sparkle from slice 1.

## 4. Switches and onboarding

All three sit under the `DailyRack` build ceiling and need `daily_rack` on. Missing = **on** (beta).

| Feature | Config key | Attribute | Off means |
|---|---|---|---|
| `toys` | `rack_toys` | `RackToys_on` | no Toy Colour Egg, no swatches, every toy draws its original colour; `rack.toy` kept untouched |
| `deck` | `rack_deck` | `RackDeck_on` | no Deck Egg; Deck style sells at fixed prices exactly as today |
| `wings` | `rack_wings` | `RackWings_on` | Angel Wings is never the sparkle pick; the slice 1 schedule exactly |

Owned things stay owned and wearable whatever the switches say. `/rack <toys|deck|wings> <on|off|clear>` joins the owner command.

**Onboarding: no change.** No new gift, no new lesson, the chain stays Outfit → Paint → Toy → Snack. The Deck Egg tile appears only after the Snack gift is recorded, and the Toy Colour Egg only once a toy is owned. Each new tile carries the client-local "New" dot until opened.

## 5. Copy (lane B owns `UICopy`)

| Key | Text |
|---|---|
| `rack.toy.title`, `.label`, `.line` | Toy Colour Egg / Today's toy colours / New colours every day |
| `rack.toy.locked` | Get this toy from the Toy Egg |
| `rack.toy.rest` | You have today's colours! New colours tomorrow. |
| `rack.toy.more`, `.original` | More colours come from the Toy Colour Egg. / Original |
| `rack.deck.title`, `.label`, `.line` | Deck Egg / Today's picks / New picks every day |
| `rack.deck.rest` | You have today's picks! New picks tomorrow. |
| `rack.deck.more`, `.promise` | More at the Deck Egg / Plates you own stay yours. |
| `rack.deck.use`, `.full` | Use it! / Your shelf is full. |
| `rack.wings.name`, `.tab` | Angel Wings / Back |

Unchanged: "Missed one? They come back." and the rounded-odds note. No countdown, "only today" or "last chance" anywhere.

## 6. Lanes and cut order

| Lane | Does | Owns |
|---|---|---|
| **A. Core (server)** | three switches, `ToySkins`, `DeckRack`, the wings row and schedule, the Back tab, `rackEgg` by egg id, `toySkinWear`, snapshots, specs | `DailyRack.lua`, `RackState.lua`, `RackConfig.lua`, `HatchProgress.lua`, `WearableVariants.lua`, `WearableCatalog.lua`, `WearableState.lua`, `PetRigDefinitions.lua`, new `ToySkins.lua`, `DeckRack.lua`, `init.server.lua` |
| **B. Shop (client)** | two tiles, panes, picks-sheet card kinds (toy, plate, ball), reveals, all copy | `RackShop.lua`, `RackPicks.lua`, `EggHatchView.lua`, `UICopy.lua`, `init.client.lua` |
| **C. Toys (client)** | tint by skin, sparks, swatch row, the garden toy for other players | `PetToyGeometry.lua`, `ToyPanel.lua`, `GardenToyVisual.lua`, `RewardItemArt.lua` |
| **D. Deck closet (client)** | closet mode on Shell and Balls | `FaceplateShop.lua`, `BallShop.lua`, `DeckPicker.lua` |
| **E. Wings (client)** | wing meshes in Snow, the halo, hiding grown wings, preview pose | `PetAttachments.lua`, `PetIdleMotion.lua`, `CardPreviewCache.lua`, `WardrobeShop.lua` |

Contract: the snapshot shapes and copy keys above; C, D and E send strings to B. Merge A first, then C, D, E in parallel, then B. Fable reviews real renders of the wings (garden, card, night) and the 24 toy colours before the beta publish.

**Cut order if time runs short:** (1) the halo's Hat offset, then the halo; (2) ball themes in the Deck Egg (plates only); (3) the sparkler's spark colour; (4) toy colours for other players (owner sees them); (5) the Deck style closet (the egg ships, the shop still sells beside it, beta only); (6) lane C and the toy egg whole. **Never cut:** the odds specs (100k rolls against shown odds, 30 days, each egg), no duplicates, the wings staying at a flat 1% with no fixed path, the three switches, the caps (128 wearables, 64 plates, 64 skins).

**Broken means:** a charge for something owned; a pick absent beyond its stated return; Angel Wings granted by anything but a roll; a toy unrecognisable in a colour.

**Later:** plate tints with solved palettes, a moving legendary plate, wings for the other rigs, a server cheer when someone hatches Angel Wings, a fixed-price path for restricted players.

Before the beta publish: translations export and sync, `V3-TEST-PASS.md` rows (one per switch), `TODO.md`, `PLAY-BUILD.md`.
