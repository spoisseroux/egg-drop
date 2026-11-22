# Get Stars page restyle: plan (Opus, 2026-11-21)

Spencer, on the beta: "It doesn't match the other UI at all??" He approved Fable's mock ("Looks good"). Brief: `artifacts/stars-store-2026-11-21/STORE-REDESIGN-BRIEF.md`. Mocks: `store-redesign-mock.png` (desktop), `store-redesign-mock-phone@2x.png`, `store-redesign-mock-passes-only.png`.

## Goal

The Get Stars page looks and works like Hatch eggs. On the left is a list of cream rows, one per pass or pack, each with its new icon. On the right is a tray with the selected offer large, what you get, and one green Buy key. The page has the Toy Shell header: title, wallet and back arrow. The server prompt path, the policy gate and every message stay as they are.

## Today

- `StoreView.lua` (566 lines) draws its own old-style card (`DeckArt` panel, grey tiles, pills, a square ✕) inside `nurseryView.shade`.
- `EggHatchView.attachStore` hides the egg card and `shopRoot` while the store is open, and `close("close")` from Hatch eggs closes only the store page.
- Every offer button prompts at once.
- Gamepad uses GUI selection over the offer buttons. Keyboard keys are refused by Hatch eggs while the store is open (`EggHatchView:1231`), and Back reaches the store through `nurseryView:close`.
- State comes from the `StoreState` snapshot: passes, products, `packsAllowed`, `ready`. Results come from `StoreResult`.
- `bestValueKey` computes the best Stars-per-Robux pack from the snapshot. This is the Starter pack while it is unclaimed, so the "BEST VALUE" sticker follows the computation, not a fixed Chest. The Chest blurb drops "Most Stars per Robux".

## Changes

1. **Icons**:
   - Downscale the 7 PNGs in `artifacts/store-listing/v2-new-look/passes/` to 256 px and upload them as Roblox Images.
   - Store the ids in `StoreCatalog`: an `icon` field on each pass and product, and a new `StoreCatalog.Icons` table.
   - A missing id draws the old glyph badge ("2×", "+1", the Stars count) in an ink-stroked square, so nothing breaks before moderation.
2. **`StoreView` rebuilt on Kit** (same public API: `new`, `open`, `close`, `isOpen`, `setState`, `setBalance`, `handleResult`, `prompt`, `getControllerFocus`, `ownsInput`, `onOpened`, `onClosed`, `onAccepted`):
   - **Shell:** a centred panel sized like the Hatch eggs panel (`Kit.frame` panel 30 + `Kit.stroke` + `Kit.shellPattern` on desktop; `Kit.sheet` on phone), drawn over the dimmed shade.
   - **Header:** `Kit.header{title="Get Stars", tint="results", help=..., wallet=true, onBack=close("back")}`.
     - The header's wallet tap returns true (the store is already open).
     - The help circle uses an existing card id if there is one, else none.
   - **Left list:** `Kit.tile`-style rows in a ScrollingFrame.
     - Each row has the icon (ImageLabel, rounded, ink stroke), the name, one sub line, and the price `R$ N` or an "✓ OWNED" chip.
     - Eyebrows "BOOSTS" / "STARS PACKS" on desktop only.
     - The selected row is lemon, and the "BEST VALUE" sticker goes on the `bestValueKey` row.
     - The free-earn line sits under the list.
     - A claimed Starter is hidden. When packs aren't allowed (restricted or not ready), there are no pack rows and the pass rows are 72 tall.
   - **Right tray:** `Kit.card` with a `Kit.previewWell` stage holding the selected icon at 144 px (100 on phone), plus sparkles.
     - Under the stage: the name, a chip ("★ 140", "FOREVER" or "✓ OWNED"), a blurb, and "WHAT YOU GET" rows.
     - Packs show "Stars +N" and "Your wallet after N". Passes show their two rows.
     - At the bottom is one primary `Kit.button`, "Buy · R$ 199".
       - An owned pass or unavailable offer gets a disabled key with its reason ("✓ Owned", "Coming soon").
       - While the prompt is cooling the key reads "Opening…".
   - **Selection:** the page opens on the first unowned, available offer (never the dearest pack).
     - Tapping a row selects it, and the tray changes with a `Kit.boing` on the icon.
     - Only the Buy key prompts (`self:prompt(key)`), one tap. Roblox's own purchase window is the confirm.
   - **Messages:** `setMessage` keeps its texts. They show in the status line above the key, or as a `Kit.toaster` for reward results. Idle shows "Roblox asks you to confirm every purchase."
   - **Input:**
     - Gamepad: rows and the Buy key are Selectable, and A on a row selects it.
     - Keyboard: the store binds its own ContextAction while open. Up/Down/W/S move the selection, Enter/Space buy, and Esc/Backspace/B go back.
     - Hatch eggs still owns Back through `nurseryView:close` (unchanged).
     - Touch: no hint chips.
   - **Reduced Motion:** no boing or pop.
3. **`EggHatchView`:** no change to the open/close contract. The store page draws its own full panel, so the hidden egg card and `shopRoot` stay hidden as today. While the store is open, the Hatch eggs panel itself must also be hidden (today only the card and list are hidden, but the new store panel must not sit over a second panel).
4. **Copy** (`UICopy.store.*`): row sub lines, blurbs, "WHAT YOU GET" labels, "Buy · R$ {price}", "✓ Owned", "BEST VALUE", the free-earn line. The `View.Rejected` texts and Idle/Opening stay.

## Edge cases

| Case | Behaviour |
|---|---|
| Snapshot not ready (`ready=false`) | Pass rows are shown disabled with "Loading…" and the Buy key is disabled; packs are hidden (fail-closed, as today). |
| Restricted account | Passes only, rows 72 tall, tray unchanged, the first unowned pass selected. |
| Both passes owned and packs not allowed | The first pass is selected; its key is disabled with "✓ Owned" and the line "Thank you! This boost is always on." |
| Pass bought while open (`handleResult` kind pass) | The row turns OWNED, the key disables, and a toast says thank you. |
| Product granted | Toast "+140 added", the wallet counts up (`Kit.wallet` set), "wallet after" recomputes. |
| Starter claimed | Its row leaves, and the selection moves to the next offer. |
| Icon id missing or not yet moderated | The glyph badge shows. |
| Phone 844x390 and 568x320 | All rows fit (35 tall); the tray holds both fair-play lines; key 44 tall. |
| Prompt cooling double tap | Unchanged (1.2 s window). |
| Store closed while a prompt is open | Unchanged (`promptToken`). |

## Not in this slice

- Price changes, product changes, Managed Pricing.
- A 3D icon on the stage (the 2D icon is the design).
- Hint chips for gamepad. The footer shows keyboard chips on desktop; touch shows none.

## Test plan

**Specs:** rewrite `scripts/StoreView.spec.lua` for the new layout, keeping its behaviour checks. A new `StoreRestyle` spec covers:
- the row order: passes first, then the Starter if unclaimed, then packs by price;
- best value, which matches the computation;
- the opening selection (first unowned);
- the restricted layout (passes only, 72 rows);
- the Buy key: one prompt; disabled for owned and loading;
- `handleResult` for a pass (OWNED) and a product (toast, wallet);
- sizes: desktop 1920x1080 and phones 844x390 and 568x320, where every row and the key are at least 44 px for touch (35 rows rely on the row hit area spanning the 5 px gap? no: rows are 44 on touch phones; see risk);
- Reduced Motion.

Then run the `HatchEggsList`, `EggShopReopen`, `CompactEggShop`, `StarsStoreAccess` and `CompactPhone` specs.

**Live (beta):**
- Tap the wallet to open the store.
- Captures at desktop and phone size, compared with the mocks.
- A test purchase in Studio (developer products prompt in Studio as test purchases): the toast and the wallet update.
- A restricted-policy check through the existing server test hook if there is one, else by forcing `packsAllowed=false` in a spec fixture.

## Risks

- **Touch targets:** Fable's phone rows are 35 tall, under the 44 px rule (CompactPhone enforces it). Make phone rows 44 with smaller icons and let the list scroll on the smallest phones, or give each row an invisible 44 px hit area. Recommendation: 44 px rows, and scroll only on 568x320.
- **Icon moderation:** uploads can sit in moderation and render blank, so the glyph badge fallback is the guard.
- **StoreView rewrite:** the existing StoreView spec and HatchActions/HatchEggsList may assert old node names (Card, Close, Body). Keep the `Body` ScrollingFrame name for the list, and check those specs.
