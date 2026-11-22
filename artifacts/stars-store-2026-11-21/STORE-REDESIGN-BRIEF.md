# Get Stars: Toy Shell restyle brief

Fable, 2026-11-21. Mocks: `store-redesign-mock.png` (1920x1080), `store-redesign-mock-phone.png` (844x390, plus `@2x`), `store-redesign-mock-passes-only.png`. Script: `build_store_mock.py`. Sizes are Kit design units (the desktop mock is the Hatch capture scaled 1.47x).

## Idea

The store is the Hatch eggs screen with offers where the eggs were: a list of cream tiles on the left, one detail tray with a stage and one green key on the right. Pick, read, Buy.

## Shell and header

- `Kit.sheet` + `Kit.shellPattern`, the Hatch panel's own size and position. While the store is open it takes the whole body under the header, not only the egg card.
- `Kit.header`: eyebrow "GARDEN", title "Get Stars", tint `results` (the `stars` gold plate, ink title, sparkle). Right side: `Kit.helpButton`, `Kit.wallet` (live balance), `Kit.backArrow`. No "0/7" chip. Back returns to the egg list.

## Left: offer list (desktop 340 wide)

- `Kit.tile` rows, as the egg list: `cream` face, `ink` stroke, `creamLip`; selected is `selected` (lemon) with `selectedLip`.
- Two eyebrow labels in `onShellSoft`: "BOOSTS", "STARS PACKS" (Starter first).
- Row, 50 tall, 8 gap: icon 38 px (radius 8, 2 px `ink` stroke) at the left; name in the display face, `ink`; one sub line in `inkSoft`; price right-aligned in `ink` as `R$ 199` (`View.price`).
- Sub lines: "Double Stars, forever", "+1 Star every round", "40 Stars · one per player", "20 Stars", "60 Stars", "140 Stars", "400 Stars".
- **Owned** pass: the price becomes an `ink` `Kit.chip` with `Kit.check`, "OWNED" in `cream`. A claimed Starter pack leaves the list.
- **Best value**: one `Kit.chip` sticker (the "THIS WEEK" sticker) reading "BEST VALUE", top right of the Chest row only.
- Under the list, `onShellSoft`: "You can always earn Stars free by playing."

## Right: detail tray

- `Kit.card` (`tray`, `ink` stroke), as the egg card.
- `Kit.previewWell` stage (`stage`, `stageDot`, `stageGlow`), 196 tall. The selected offer's icon sits centred at **144 px** (3 px `ink` stroke, ink lip, floor shadow, sparkles in `stars` and `white`). `Kit.boing` on selection change.
- Name in the display face, `onShell`. Right of it a `stars` chip: "★ 140" for packs, "FOREVER" for passes, "✓ OWNED" when owned.
- One blurb line, `onShellSoft`. Passes keep the catalogue blurbs. Packs: Starter keeps its blurb; Handful "A little top-up for one more egg."; Pouch "Enough Stars for a few eggs."; Jar "Lots of Stars for lots of eggs."; Chest "The big one. Most Stars per Robux."
- "WHAT YOU GET" label, then `well` rows as the odds rows. Packs: "Stars / +140", "Your wallet after / 160". Passes: "Every round and quest / 2× Stars" (Supporter: "Every finished round / +1 Star"), "Keeps working / Forever". Chest adds "Best value / Most Stars per Robux".
- **Primary key**: the screen's only `go` key, `Kit.button` primary, full tray width, A glyph: "Buy · R$ 199". Owned pass: the key paints `Kit.Disabled`, reads "✓ Owned", with "Thank you! This boost is always on." above it.

## Footer

Hint chips left: WASD Browse, ENTER Buy, BKSP Back. Right, `onShellSoft`: "Roblox asks you to confirm every purchase." Status messages use `Kit.toaster`.

## Phone, 844x390 (compact)

- Compact `Kit.header` (60 tall), same parts.
- List 268 wide: rows 35 tall, 5 gap, icon 25 px, name and price only (the icon carries the number); a 6 px break between passes and packs, no eyebrows. All seven fit without scrolling.
- Tray: stage 138 square on the left, icon **100 px**; name, chip, blurb and the two `well` rows to its right. Then "Roblox asks you to confirm every purchase.", the `go` key (44 tall, no glyph on touch), and "You can always earn Stars free by playing." inside the tray, so both lines are always on screen.
- No hint chips on touch.

## Passes-only (restricted accounts)

Drop "STARS PACKS" and its rows. The two pass rows grow to the egg-row size (72 tall, icon 60 px, sub line 13). Free-earn line right below. Tray and footer unchanged; the first pass is selected.

## Rules

One green key. No red, countdowns, "limited", crossed-out prices or pulsing. Opens on the first unowned offer, never the dearest pack. Icons are used uncropped.

## New Kit needs

No new colour tokens. Two build gaps: (1) an image slot for `Kit.tile` rows and `Kit.previewWell` (rounded, ink-stroked ImageLabel; the stage shows 3D today), with the seven icon asset ids added to `StoreCatalog`; (2) `EggHatchView` must hand the store the whole body and swap the header title and tint, not only the egg card.
