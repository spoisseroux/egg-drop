# Lane U (client UI) notes, overnight 2026-11-14

Nothing committed, nothing deleted, Play never started. `init.client.lua` still has 219 column-0 locals.

## What landed

### E-cli (second pet; all hidden while `EarnedPets.enabled("blip")` is false)
- `CompanionsHub.lua`: `Hub.petCards` lists owned **and active** pets only; new `Hub.firstOwned(state)` and `Hub:activePet()` replace every `or "pip"`.
- `WardrobeShop.lua`: no pet named. `Shop.firstPet()` (first active pet with items) is the default and the fallback of `open(nil)` / `open(<pet with no wearables>)`.
  - Deviation from the scope: the default is `Shop.firstPet()`, not `nil`. Existing specs build and measure the shop before `open`, and a nil pet broke `refresh`.
- `HueEggView.lua`: first pet is `Pets.active[1]` (not nil: the view concatenates `petId` in several keys before `open`). `View:owned` now also needs a rig definition, so a rig-less collection pet is never a target or a preview.
- `DeckMenu.lua`: name and portrait fall back to the first active pet. The `FamilyCrest.create(host,"pip")` literal stays (crest is family art, scope row 37).
- `RoomView.lua`: charm toggle uses `HueCatalog.Supported`; `captureFocusSubject` takes the Bear path for rig `blip`.
- `PetJournal.lua` (not on my list; coordinator's note 1): rows that are neither active nor owned build no portrait. Blip has no portrait art, and `Portrait.create` would have thrown on the first journal refresh. `init.client.lua:1308` now walks `journal.portraits` with `pairs` (the list can have holes).
- `init.client.lua`: Wardrobe context has no fallback pet; results "pet is impressed" uses the companion's name.
- `CoachCards.lua`: arrival card `petArrived` (coach bit 10). `Cards.arrivalDue` = enabled + owned + bit unset + not seen this session; it does **not** use `Coach.wants`, so veterans get it. Shows only in the free, settled garden; a menu hides it and it comes back.
  - **Say hi** calls `options.sayHi(petId)` (init sends the existing `companion` action), then saves the bit.
  - **Got it** and the card's full 20 s also save the bit without switching. A stray tap on the card keeps it.
  - Already the companion: the bit is saved with no card.
- `StampCardView.lua`: the line under the card becomes "Someone's on the way… N more stamps" while the pet is enabled, not owned and still ahead (`View.tease`). `View.Earned` lets specs inject the gate.

### B-cli
- Variant cards: own card after the base, swatch in the variant colour plus a colour dot with a cream ring over the card preview; pane note "A new colour of {base}". Preview signature keeps the variant id (`Shop.previewSignature`, via `WearableCatalog.renderMap`).
- Tabs: `Shop.tabsFor(pet)` shows only tabs with items (Ankle hidden). New tab labels and slot notes come from UICopy `variants.tab.*` / `variants.slot.*`.
- Ten tabs on phone: `Shop.tabStrip` measures the labels; when equal segments cannot hold them the Kit.tabs track sits in a sideways `TabStrip` ScrollingFrame and the front tab is scrolled into view. Measured: 528 px phone bar gives a 668 px track; the 800 px desktop bar does not scroll (79 px segments). With auto-translation on, segments keep 35% headroom, so desktop scrolls too.

### C-cli
- New `src/client/ShelfDeal.lua`: week from the snapshot (`shelfWeek`, else `dailyDay`), `quote`, `priceText`, `lines`, and the chip.
- Wardrobe, Faceplates, Balls: "THIS WEEK −20%" chip on the pane preview, card price `★ 12  <s>15</s>` (rich text), the buy sends the shelf price, shortfall lines use it. `ctx.week=false` means no shelf.
- Deluxe tier chip (gold) on Faceplates and Balls.
- `MachineHub.lua`: Deck style and Companions tiles show "This week: {names}" in Stars gold, falling back to "20% off this week" when it cannot fit. No countdown.

### D-cli
- `HueEggView.lua` Charm tab: shapes with a rule show Locked (lock icon, rule line, progress for counted rules), then Earned. A locked card previews on the pet but cannot be worn. Star uses the star icon; Heart falls back to the sparkle (no heart glyph in Kit).
- Toys and Discoveries need no client change on my files (lane K's whitelists and BookView's per-item chips cover them).

### F-cli
- New `src/client/BondPips.lua`: heart pips (Kit frames in a CanvasGroup), 3 px bar, `info`, `levelUps`, `toastText`.
- `CompanionsHub.lua`: pips under the name on the desktop hub pane (the preview well gives up 22 px); beside the name on the phone pane and both selector panes (no room under it).
- `PetFocusUI.lua`: new focus card top right (name, pips, "Lv N"). There was no name card before.
- `PetAffection.lua` (not on my list; scope 5.4 names it): pooled six-heart burst, `bondBurst` / `stepBond`. The heart is the "♥" glyph until the 64 px PNG is uploaded (`Affection.BondHeartImage`).
- `RoomView.lua`: `setBond`, `bondLevelUp`, `bondFlourish`, `playBeat`, `bondTricks`. A level earned on the deck waits up to 2 min for the garden.
- `init.client.lua`: one do-block subscribes to the snapshot, feeds `roomView:setBond`, and toasts level-ups on the coach toaster. `clientUI.bondSeen` holds the last level seen.
- Tricks 1–2 only. Hello = one wave per pet per session when the owner stands near. Sit = the owner-still sit now needs level 2.

## Specs

Copy to `src/client/ZZSpecs/<Name>.lua` (already there), then in the Client datamodel:
`require(PlayerScripts.Client.ZZSpecs.<Name>)(PlayerScripts.Client, PlayerGui)`.

| Spec | Cases | Status |
|---|---|---|
| `scripts/PetGeneralization.spec.lua` | 5 | **Not run.** Compiles. It reads module Sources, so it needs the real client in Play |
| `scripts/WardrobeTabs.spec.lua` | 9 | Passed in the Edit harness |
| `scripts/ShelfDeal.spec.lua` | 7 | Passed in the Edit harness |
| `scripts/BondView.spec.lua` | 9 | Passed in the Edit harness |
| `scripts/ArrivalCard.spec.lua` | 7 | Passed in the Edit harness |
| `scripts/CharmCards.spec.lua` | 4 | Passed in the Edit harness |

- "Edit harness" = clones of `Shared` and the client modules required in Edit (Edit's own `require` cache was stale, it still had the pre-lane catalogues). It is not a Play run.
- Existing specs re-run the same way and passing: CompanionsHub, StampCardView, CoachCards, MachineHub, CustomizeRedesign, UICopy (from the ZZSpecs copies, which may be older than `scripts/`).
- **Not run at all:** LocalizationFit, R4Content, UIShellQA, DeckHeader, CareMachineUI, HueEggView, PetFocusUI, ClientLocalBudget's spec file (I counted 219 by hand). A batch with these timed out in Edit, so they need Play.
- No existing spec needed editing.

## Open issues

1. **Sit is now gated.** Once `public.bond` is in the snapshot, a level-1 pet no longer sits when the owner stands still; that returns at 25 XP. It is the scope's design but it removes something players have today.
2. `GardenPetVisual.lua:378` still keys the walk squash on `petId=="pip"` (scope row 34 wants the rig id). Not my file; it is on the spec's allowlist.
3. The server half of the `"pip"` literal check is not covered by my spec (a client cannot read server Sources).
4. Arrival card on gamepad: the button is not selectable (coach cards bind no keys). A gamepad player lets it time out and switches in Companions.
5. `PseudoLocale` on would break two exact-string asserts in BondView and ArrivalCard specs.
6. `TODO.md` not touched (left to the coordinator to avoid lane collisions).

## Needs a Studio visual check

- Wardrobe at 812x354 with ten tabs: strip scroll, thin scrollbar, front tab in view after Q/E.
- Variant cards: colour dot over the 3D card preview; tinted preview in the pane; one dark and one light dyed pet.
- Shelf chip on all three shop panes (it overlays the preview corner), and the struck price on cards at phone size.
- Machine hub shelf line: two wrapped lines on desktop, one line on phone.
- Bond pips at 14 px on phone (filled vs empty), the desktop hub pane with the shorter preview well, and the focus card top right against the Roblox top bar.
- Level-up: toast position under the coach card, heart burst colour at noon and night, stretch beat.
- Arrival card with the Blip placeholder (`StudioBlipPlaceholder`): button row, card height on phone.
- Charm tab: locked cards and the rule line in the phone pane.
