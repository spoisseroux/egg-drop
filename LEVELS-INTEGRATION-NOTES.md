# Levels matter: integration notes (worker A, 2026-11-22)

Contract: `V3-LEVELS-BUILD-PLAN-2026-11-22.md`. This branch holds the shared modules, the server, the catalogue rows and the specs. Nothing here turns on until step 1. With `LevelsMatter` missing or false the game is the one at cf61cc0 (specs `LevelsOffParity`, `GatedPurchase`, `MedalEggs`, `ParkPerks`).

## What B and C read

| Module | Use |
|---|---|
| `Levels.on(part)` | `track`, `gates`, `medals`, `juice`. `Levels.Shipped[part]=false` holds a part back until its client code lands (S1, S2, S4, S3). Specs: `Levels.inject({flags={LevelsMatter=true},studio=true,shipped={...}})`, then `Levels.inject(nil)`. |
| `LevelGate` | `Gate.levels(snapshot.petStats.pets)`, then `Gate.met(levels,item.gate)` and `Gate.progress(levels,item.gate)` = `{have,need,petId,met,stat,total}` for the chip and bar. |
| `StatRewards` | `next`, `upcoming(stat,level,n)`, `earned(stat,from,to)`, `forStat`, `totals()`, `text(row,UICopy.get)`, `bookHints(levels)`. `row.kind=="gate"` is the shop tag, every other kind is free; `row.area` is `wardrobe`, `balls` or `plates`. |
| `Medals` | `forPet(levels)` six slots, `count`, `tier`, `crossed(before,after)`, `Badges` (all nil). |
| `ParkPerks` | `fromPublic(JSONDecode(PublicStats),petId)` gives `{swingCheer,swingHigh,slideSpin,seesawHop,catchHop,longThrow}`; `SwingScale` 1.25. Empty while off. |
| `DeckJuiceCatalog` | `ByKind`, `unlocked(kind,id,levels)`, board attribute `DeckJuice` (JSON `{pop,trail,start}`, already resolved; absent = classic). |
| `BondCatalog.trickLevel(xp,heartLevel)` | Tricks unlocked. Equals `Bond.level(xp)` while off. |

**Shop lists (must use, or gated items never show or never hide):**

- Balls: `BallThemes.listed(ownedIds)` in place of `BallThemes.Order` in `BallShop` (lines 144, 150, 166, 398). `Order` is unchanged on purpose: the shelf, the Book and existing specs read it. `tangerine_pop` is in `BallThemes.Gated`.
- Plates: `DeckThemes.listed(ownedIds)` in place of `table.clone(Themes.Order)` (`FaceplateShop` 90, 543, 670). `Gated` is empty until the two textures are uploaded.
- Wardrobe: `WearableCatalog.shopTab(petId,slot,ownedIds)` in place of `inTab` in `WardrobeShop` (41, 94, 241). With gates on it equals `inTab`; off, it only adds owned gated items.

Server reasons: a purchase below the gate is `NeedsLevel` (no charge); a gated id while off is `NotForSale`.
Snapshot: `statEgg.free` is bank plus medal eggs, and `statEgg.medalEggs` (only while medals are on) is the medal part. A medal egg's receipt has `source="medal"`. Open one with the existing `free=true` request.

## 1. FeatureFlags.lua

Comment: `-- LevelsMatter (V3-LEVELS-BUILD-PLAN-2026-11-22): the build ceiling for levels, gates, medals and deck juice. Also needs the beta place or Studio (Levels.PlaceId). Missing = off.`
In the table: `LevelsMatter=true`

## 2. init.server.lua

No new remotes and no new top-level locals.

Settings action, right after the `whiteSecond` block (`now` is the handler's own):

```lua
	if action == "deckJuice" then
		-- Levels matter S3: {kind, id}. Known and unlocked from the save, or ignored (DeckJuiceState).
		if type(value) ~= "table" then return end
		if not canProgress(board) or board.closing or board.profile.loadFailed then return end
		local DeckJuice = require(script.DeckJuiceState)
		if board.juiceAt and now - board.juiceAt < DeckJuice.Throttle then return end
		board.juiceAt = now
		local map = DeckJuice.choose(board.profile.deckJuice, board.nursery.state, value.kind, value.id)
		if not map then return end
		Progress.setSetting(board.profile, "deckJuice", map)
		petHello.social(board)
		Progress.requestFlush(board.profile)
		return
	end
```

In `petHello.social`, after the `PublicStats` line:

```lua
		local juice=state and require(script.DeckJuiceState).public(board.profile.deckJuice,state)or nil
		board.folder:SetAttribute(require(ReplicatedStorage.Shared.DeckJuiceCatalog).Attribute,if juice then HttpService:JSONEncode(juice)else nil)
```

In `ParkDirector.attach(garden, {...})`, beside `busy` (the longer throw; without it every throw is 4 studs):

```lua
	speedLevel = function(ownerId)
		-- Levels matter S1: the thrower's companion's saved Speed (never a public attribute).
		local player = Players:GetPlayerByUserId(ownerId); local board = player and boards[player]
		local state = board and not board.closing and board.nursery and board.nursery.state
		local petId = state and board.profile and board.profile.companionId
		if not petId or not NurseryCatalog.isOwned(state.inventoryMask, petId) then return nil end
		return require(ReplicatedStorage.Shared.StatCatalog).levelFor(require(script.StatState).xp(state, petId, "speed"))
	end,
```

In `snackEffects`, the `EggOpened_stat` event: replace `if receipt.free then "free"else "paid"` with `receipt.source or(if receipt.free then "free"else "paid")`.

Badges: after a committed write, `Medals.crossed` on the levels before and after (baseline on the first snapshot of the session), pcall, once per badge per session, skip a nil `Medals.Badges[tier]`. Nothing to call until the ids exist.

## 3. init.client.lua

- `request:FireServer("deckJuice",{kind=kind,id=id})` (the same remote as `whiteSecond`); `id="classic"` clears a kind.
- Bond block (about 3181): while `Levels.on("track")`, unlocked tricks are `BondCatalog.trickLevel(bond[petId],state.petStats.pets[petId].level.heart)`. Baseline on the first snapshot, as `bondSeen` does, so turning the part on never toasts old tricks.
- StatsHost mount (about 1342): pass `focus` (B).

## 4. DeckKit

Nothing from A.

## 5. UICopy (final English)

Under `stats`:

```lua
  next={free="Next at {level}: {name} · free",gate="Next at {level}: {name} · shop",top="Top level"},
  guide={title="{name} guide",open="All {name} rewards",earned="Got it",at="Level {level}",shop="Go to shop",jobs="Also good for",none="More rewards soon"},
  levelUpReward="{name} {count} · {reward}",
  reward={item="{name}",name="Name piece: {name}",trick="New trick: {name}",
   swingCheer="A wave on the swing",swingHigh="Swings higher",slideSpin="A spin on the slide",seesawHop="A hop on the see-saw",
   longThrow="Longer throw in the park",catchHop="A happy catch hop",bookHints="Where-to-find hints in the Book",
   confetti="Confetti merge pop",fizz="Fizz merge pop",bubble="Bubble drop trail",comet="Comet drop trail",
   ready="Ready, steady start",lightning="Lightning lid start"},
```

Top level:

```lua
 medal={sprout="Sprout medal",bloom="Bloom medal",fullBloom="Full Bloom medal",starbloom="Starbloom medal",
  earned="{name} medal! A free Stat Egg is yours.",eggOne="1 medal egg is waiting.",eggs="{count} medal eggs are waiting."},
```

`shop.needs={stat="Needs {name} {level}",total="Needs total level {count}"}`, `shop.reason.needsLevel="Your pet needs a higher level first"`, `shop.train="Train {name}"`, `inspect.marks="Marks"`.

Under `book`:

```lua
  where={balls="In Deck style, under Balls.",faceplates="In Deck style, under Faceplates.",wardrobe="In Companions, under Wardrobe.",
   toy="Hatches from the Toy Egg.",finishJar="Hatches from the Customization Egg.",charmEgg="Hatches from the Customization Egg.",charmEarned="Earned by playing. Check its page.",
   pets="Say hello in Companions.",discoveries="Play a round and it will turn up."},
```

Deck style, Effects tab (C): `style.effects={title="Effects",pop="Merge pop",trail="Drop trail",start="Start",classic="Classic",promise="Just for looks. Never an advantage.",locked="Needs {name} {level}"}`.

## 6. Translations

`scripts/export_localization_csv.py`: add `"DeckJuiceCatalog"` to `CATALOGS`. The 14 recolours and Tangerine Pop export through `WearableCatalog.Variants` and `BallThemes.ById` already.

## 7. Two faceplates (when the textures are uploaded)

Add the `sky_fizz` and `storm_glass` rows from `artifacts/levels-2026-11-22/art.json` to `Plates` in `DeckThemes.lua` with `gate={stat="energy",level=10}` / `{stat="energy",level=30}` and their `texture`, and set `Themes.Gated={"sky_fizz","storm_glass"}`. Never add them to `Themes.Order`. `StatRewards`, the shop list, the purchase gate and the specs pick them up from there.

## 8. Specs

All run as `(ServerScriptService.Server)`: `Levels`, `LevelGate` (with Medals), `StatRewards`, `GatedPurchase`, `MedalEggs`, `ParkPerks`, `DeckJuice`, `LevelsOffParity`. Changed: `WearableVariants` (24 rows; each test on and off), `WearablePurchase` (10 ungated, 10 or 24 listed). Still to do in Studio: the plan's Studio and two-client checks, and a full re-run against the baseline with the flag on and off. `BookClaim` and `BookStateBits` fail at cf61cc0 too (in the baseline).
