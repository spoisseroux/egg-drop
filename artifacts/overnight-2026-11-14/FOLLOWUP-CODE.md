# Follow-up code notes, 2026-11-14

Six follow-ups Spencer asked for after v628. Nothing committed, nothing deleted, Play never started. `init.client.lua` is untouched and still has 219 column-0 locals. Saves are unchanged (v11, no new field).

**Status: every changed module and spec compiles in Studio Edit (required from clones). No spec has been run.** The rule for this pass was compile checks only, so the specs below still need a Play run.

## What changed

### 1. Bond levels 6–10
- `src/shared/BondCatalog.lua`: `MaxLevelShipped = 10`, `Version = 2`. Thresholds are the reserved ones, now live: 350 / 475 / 600 / 725 / 850 **[PLACEHOLDER]**. Steps are 100 then a flat 125, so about 3 to 4 days a level at 35 XP a day; level 10 is about 24 days engaged, about 9 weeks casual.
- **Server: no code change needed.** `BondState` stores XP only (0..100000) and never levels, so old and new saves already validate. A pet that banked 350+ XP under the five-level build reads its new level on the next snapshot, with no flood of toasts (the first snapshot is the baseline).
- `src/client/BondPips.lua`: the row stays **five hearts wide** (ten 14 px hearts are 176 px, too wide beside a name on phone). Levels 1–5 fill the hearts; levels 6–10 turn them gold one by one, each with a small cream dot so gold reads without colour. `Pips.hearts(shown)`, `Pips.cap` up to 10, `info.top`. No layout change in `CompanionsHub` or `PetFocusUI`.
- Label at level 10 is "Lv 10 · Best friends" (`bond.top`); "more soon" is kept only for a cap below 10.

### 2. Tricks 3–5 and unlocks 6–10
- `BondCatalog.Unlocks` 6–10 **[PLACEHOLDER routines and names, for Astra]**, existing idle beats only:

| Lv | Name | Beats |
|---|---|---|
| 6 | Peekaboo | look, wave |
| 7 | Cosy stretch | yawn, stretch, sit |
| 8 | Sneezy wiggle | sneeze, wiggle, wiggle |
| 9 | Show-off | scratch, stretch, wave + hearts |
| 10 | Best friends | wave, wiggle, wiggle, stretch, sit + hearts |

- `src/client/RoomView.lua` `bondTricks`: levels 3 and up now play. While the owner stands near and still, the pet shows one unlocked routine every 24 s (first after 6 s), newest first, then the others in turn. Beats run one after another through `playBeat` (which now accepts a short `sit`). The heart burst fires at the end when the unlock has `hearts`. A routine stops quietly if the owner walks off or the pet gets busy. None under Reduced Effects. Tunables: `Room.BondTrickGap`, `BondTrickFirst` **[PLACEHOLDER]**.
- `src/shared/UICopy.lua` (bond block): `bond.trick.l6..l10`, `bond.top`.

### 3. Owner-still sit
- Restored for every pet at any level (the `info.shown<2` gate is gone).
- **Decision to confirm:** level 2 "Sit" would otherwise unlock nothing, so it now means the pet sits sooner (after 3 s instead of 6 s, `Room.BondSitHead` **[PLACEHOLDER]**). Set it to 0 to make level 2 a name only.

### 4. Phone menus
- `EggHatchView.lua` (`layoutShop`) and `HueEggView.lua` (`fitChrome`): the phone sheet top is `Kit.sheetTop(self.shade)` instead of `kh + 2`, as `DeckPicker` does.

### 5. Shop grids
- `BackgroundShop.lua`, `BallShop.lua`: `Kit.scrollBleed(list, 4)` on the phone grids, canvas grown by 8 (the `FaceplateShop` pattern).
- `scripts/CompactPhone.spec.lua:443` asserted the Backgrounds grid at y = 112; it now allows the bleed, like line 436.

### 6. Round camera
- `src/client/DeckCameraLock.lua`: new pure `Lock.parkCFrame(origin, hub, look)` and `Lock:park(origin, hub)`. `release` puts back the view the camera was frozen at.
- `RoomView.lua` `show("Board")`: after the freeze, the camera parks 4.5 studs above the avatar's root, 1.5 studs toward the hub, looking in across the garden with a slight downward tilt. It can no longer look out over the perimeter wall, and the avatar is behind the lens. Within 10 studs of the hub it keeps its current heading. On the legacy layout (no `Hub`) it only freezes, as before.
- Not handled: visible island meshes do not collide, so nothing checks whether the parked spot is inside a tree canopy.

## Specs

Copies are already in `src/client/ZZSpecs/` and `src/server/ZZSpecs/` (BondView, DeckRoundQA, BondCatalog, BondProgress). Run in Play after a Rojo sync.

| Spec | Run | New or changed |
|---|---|---|
| `scripts/BondCatalog.spec.lua` | `require(Server.ZZSpecs.BondCatalog)(Server)` | Thresholds and boundaries to 10, progress past level 5, ten unlocks from existing beats, no repeated routine |
| `scripts/BondProgress.spec.lua` | `require(Server.ZZSpecs.BondProgress)(Server)` | New case: old saves with 250..100000 XP load, validate and read levels 5..10; an award crosses into level 6 |
| `scripts/BondView.spec.lua` | `require(PlayerScripts.Client.ZZSpecs.BondView)(PlayerScripts.Client, PlayerGui)` | Ten levels on five hearts (gold round), labels, trick names 1–10; sit never gated; new case for routines 3–10 |
| `scripts/DeckRoundQA.spec.lua` | `require(PlayerScripts.Client.ZZSpecs.DeckRoundQA)(PlayerScripts.Client, PlayerGui)` | New case: park position and heading, once per freeze, view restored on exit |
| `scripts/CompactPhone.spec.lua` | client, as above (the ZZSpecs copy is older than `scripts/`) | Line 443 only |

Also worth re-running: `BackgroundPicker`, `HatchCinematic`, `HueEggView`, `CustomizeRedesign`, `UICopy`, `LocalizationFit`, `ClientLocalBudget`.

## Needs a visual check in Studio

- **Pips:** gold hearts and the cream dot at 14 px (phone) and 18 px; levels 5, 6, 9, 10; the pop when a heart turns gold; "Lv 10 · Best friends" in the desktop Companions pane and the focus card.
- **Routines:** each of 3–10 on the Bear near a still owner; how beats read over the owner-still sit (the pet is usually sitting by then); pacing of the 24 s gap; hearts at the end of 5, 9 and 10.
- **Level 2 sit** at 3 s versus level 1 at 6 s.
- **Hatch eggs and Customize at 812x354:** sheet top just under the Roblox controls, not pushed down twice; bottom edge of the sheet.
- **Backgrounds and Balls grids on phone:** first card's top and left stroke whole; scrollbar now 4 px further right; keyboard scroll to the last row.
- **Round camera:** start a round from the arrival dais, the perimeter, the hub and under a tree. Check what shows through the deck, and that the roam view comes back unchanged after the round.

## Before the next publish

- New strings: run the localization export and sync (AGENTS.md "Every build: translations").
- `TODO.md` was not touched; the v628 line still lists "tricks 3-5" and "owner-still sit now needs bond 2" as open.
