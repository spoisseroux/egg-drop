# Stars store access: plan (Opus, 2026-11-21)

Spencer: "do we need to make stars easier to buy in game? ... Like clicking the stars icon opens a store to buy stars?" He picked **both** parts: tapping the Stars counter, and a card when you can't afford something.

## Goal

A player who wants Stars can reach the Robux store in one tap from any menu, and a player who taps something they can't afford is told how many Stars they need, with two ways to get them: buy them, or play a round. Restricted accounts never see Star packs (the server already hides them). The store itself is unchanged.

## Today (read from the code)

- The Stars counter is `Kit.wallet` (`DeckKit.lua:1371`), a Frame with no input. It sits in the top right of every `Kit.header` menu (17 screens: hub, Companions, Wardrobe, Deck style, Book, Quests, Stats, Names, Hatch eggs and others), plus the deck results and difficulty picker.
- The Robux store is `StoreView`, parented to the Hatch eggs shade. The only way in is the "Get Stars" button on Hatch eggs (`EggHatchView:openStore`, which refuses while a hatch result or request is pending).
- The server gates packs by PolicyService (`StoreService.policyAllowsPacks`, `packsAllowed`), and every purchase prompt starts on the server.
- When a shop item costs more than the wallet, the buy button is disabled and reads "N more Stars needed" (`ShopPriceState.need`): Wardrobe, Deck style faceplates and balls, Names Egg, Bunny adopt, Hatch eggs, Stat Egg, Customization Egg. Hatch eggs' Stat Egg row already sends a short player to the deck (`close("earn")`).

## Changes

1. **`clientUI.openStarsStore(from)`** in `init.client.lua` (one route for both parts).
   - Only in Room mode, not while `roomView.busy`, not while a hatch result is waiting (`nurseryState.lastHatch`) or a hatch request is pending. Otherwise it returns false and does nothing.
   - Closes the screen you are on the way the existing `openHub` route does (cancel hatch navigation, picker, journal, Customize, hub, Wardrobe, item and pocket menus), opens Hatch eggs (`openNursery`), then `nurseryView:openStore()`.
   - Sets `clientUI.machineReturn="store:"..from` so that Back from the store, and then from Hatch eggs, returns to the screen you came from where a return already exists (hub, Companions, Book). Anywhere else, Back ends in the garden as today.
2. **Tappable wallet** (`DeckKit.lua`).
   - `Kit.wallet` gets a transparent full-size `TextButton` ("Tap") over the capsule, with `AutoButtonColor=false`, a hover lift and a press scale, and `AccessibleLabel` "Get Stars".
   - The tap calls the hook `Kit.onWalletTap(api)`, which is nil by default; `init.client` sets it to `openStarsStore("wallet")`. When the hook is nil or returns false, the wallet only pulses (the existing earn flash, without the number pop).
   - The button is `Selectable=false`, so controller focus order on every screen is unchanged. Controllers reach the store through the card (3) and Hatch eggs' Get Stars.
   - On the deck results and difficulty picker, which are Board mode, the route returns false, so the tap just pulses. The Pocket Deck round is never interrupted.
3. **"Need more Stars" card**: new `StarsShortCard.lua` (client), built on `Kit` surfaces, one instance, above every menu.
   - Content: the Star, "You need ★ N more", the item's name and price, then three buttons: **Get Stars** (opens the store through the route in 1), **Play a round** (the existing earn route: close menus and open the Pocket Deck in the hub's Play mode), and **Not now**.
   - **Restricted accounts** (`packsAllowed==false` in the latest StoreState snapshot): Get Stars still shows, because passes are allowed and the store shows them; packs stay hidden as today. If the snapshot isn't ready, Get Stars shows and the store shows its loading state.
   - Controller: the card takes focus on open (Get Stars first), B closes it, focus returns to the button that opened it.
   - Reduced Motion: no pop-in.
4. **Short buy buttons open the card.** In each shop, the `kind="short"` state keeps its look and text ("N more Stars needed") but becomes pressable (`enabled=true`, `short=true`), and pressing it calls `clientUI.needStars{count, price, name, from}`.
   - Shops: `WardrobeShop`, `FaceplateShop`, `BallShop`, `NameScreen`, `CompanionsHub` adopt, `EggHatchView` (Toy, Stat, Customization, Names rows), `StatEggOdds`, `HueEggView`.
   - Hatch eggs' Stat Egg "earn" shortcut becomes the card, so every short press behaves the same.
   - The server still refuses short buys (`NeedStars`). When a buy is refused with `NeedStars` (the wallet changed during the press), the shop shows its message as today and does not open the card.
5. **Copy** (`UICopy`, then the localization export and sync):
   - `stars.short.title` "You need ★ {count} more"
   - `stars.short.item` "{item} · ★ {price}"
   - `stars.short.buy` "Get Stars"
   - `stars.short.earn` "Play a round"
   - `stars.short.later` "Not now"
   - `stars.wallet.label` "Get Stars"

## Edge cases

| Case | Behaviour |
|---|---|
| Wallet tapped during a hatch result or pending hatch | Pulse only. The result must be seen first. |
| Wallet tapped in a Pocket Deck round or on results | Pulse only (Board mode). |
| Wallet tapped on Hatch eggs itself | Opens the store page in place. |
| Wallet tapped while the store is already open | Nothing. |
| Restricted account | Store shows passes only (server-gated, unchanged). The card still offers Get Stars and Play a round. |
| Store snapshot not ready | The store opens in its loading state (fallbackState). |
| The player buys Stars while the card is behind the store | The card closes when the store opens. Returning to the shop shows the new wallet, so the button is buyable. |
| Short press, then the wallet rises above the price before the card opens | The card isn't shown; the shop re-renders as buyable. The card reads the live wallet at open. |
| Gamepad | The wallet isn't in the focus chain. The card takes and returns focus. |
| Phone 667x375 | The card fits inside the safe area; the buttons are at least 44 px. |
| Two menus' wallets in one frame (hub header and a sheet) | One route, idempotent; a second call while opening is ignored (an `opening` latch). |

## Not in this slice

- A store tab inside the hub or menu (the route plus the card covers it).
- Buying from the deck results screen (Board mode); revisit if numbers show demand.
- A controller button for the wallet (it would change focus chains on 17 screens).
- Any change to prices, products, passes, Managed Pricing or the store page layout.

## Test plan

**Specs** (ZZSpecs copies, run as in `studio-spec-running`):

- **`StarsShortCard` (new):**
  - Copy for 1 and N Stars.
  - Buttons and focus order.
  - Get Stars calls the route; Play a round calls earn; Not now and B close the card.
  - Reduced Motion.
  - Fits at 667x375 and 1920x1080.
- **`StarsStoreRoute` (new):** the route refuses in Board mode, while busy, on a lastHatch or a pending hatch; it opens Hatch eggs and the store in Room mode; it is idempotent; and Back returns to the hub where the hub was the origin.
- **`WalletStar` / `DeckKit` wallet:**
  - The Tap button exists, its Selectable is false, and it carries the accessible label.
  - The hook is called once per tap.
  - A nil hook means a pulse only, and the number does not change.
- **Shop specs (`WardrobeShop`, `FaceplateShop`, `BallShop`, `NameScreen`, `CompanionsHub`, `EggHatchView`, `StatEggOdds`):** the short state is enabled, has `short=true` and the same text, and pressing it calls `needStars` with the right count and price. Update the existing asserts that expected `enabled=false`.

**Live check (beta place 107705084891479):**

1. Fresh save at 12 Stars: Wardrobe → a 40-Star hat reads "28 more Stars needed" → tap → card "You need ★ 28 more" → Get Stars → store opens on Hatch eggs → Back → Hatch eggs → Back → garden. Repeat from the hub to check the return.
2. Tap the wallet from the hub, Book, Quests, Stats and Deck style headers: each opens the store.
3. During a round and on the results screen: the tap pulses, and the round doesn't stop.
4. Gamepad: open the card from a short Wardrobe item, move focus, close it with B, and focus returns to the item.
5. Phone emulation 667x375 and 844x390: captures of the card and the store.
6. A test purchase on the beta (Studio test purchase, no Robux) through the card path: the Stars land and the wallet flashes.
7. A restricted-policy test: Studio's PolicyService override, or the server flag forced to false through the test hook. The store shows passes only, and the card still works.

If any check fails, look first at `nurseryView:openStore`'s refusal conditions (shade not visible, pending) and the route's close order.

## Risks

- **Closing every menu correctly:** 17 screens each have their own close and return logic. A missed one leaves a menu under the store. Mitigation: reuse `openHub`'s close list and check each header in the live pass.
- **Short buttons were disabled on purpose in some specs** (and the controller A press on a short item did nothing). Making them pressable changes the A press on short items everywhere; the card is the intended result.
- **Spending pressure:** the card must stay friendly and offer the free path (Play a round) on equal footing, with no countdowns or red. It is a 16+ game today, but the copy stays kid-safe.

## Revisions after the architect review (2026-11-21)

| Original plan | Revised | Architect's reason |
|---|---|---|
| Route closes screens using `openHub`'s list | New `clientUI.closeAllMenus("store")`, built from `openMenu`'s "is anything open" check plus picker, journal and machine hub. Afterwards it checks again and refuses if anything is still open. | `openHub` misses Wardrobe, Book, Quests, Stats, Names, the machine hub and the Companions hub, and `ownsPresentation` doesn't check them either, so the store could open underneath those screens. |
| Screens close normally | Screens close with a non-"back" reason. | A "back" close fires `returnToMachineHub`, which then reopens a menu over the store. |
| Route always reopens Hatch eggs | If the store is already open, the route does nothing. If Hatch eggs is open, it calls `openStore()` directly. | Calling `View:open` again resets gamepad focus onto a hidden card. |
| `machineReturn="store:"..from` | Dropped. Set `machineReturn="hatch"` only when starting from the machine hub; otherwise nil. | Nothing clears a `store:` marker. The existing "hatch" path already gives Store, then Hatch eggs, then hub on Back. |
| Short buy buttons get `enabled=true` | `enabled` is left alone. Each shop's `act()` gets a `kind=="short"` branch (Wardrobe, Faceplate, Ball, Names, HueEggView, CompanionsHub, EggHatchView, StatEggOdds), and Kit gets a new state that can be tapped but looks dim. | `Kit.setEnabled` repaints the button, so the dim "short" look would be lost. Every `act()` already branches on `kind`, and tile taps already call `act()`. |
| Every `Kit.wallet` is tappable | Opt-in: `Kit.wallet(parent,h,{tap=true})`, passed only from `Kit.header`. The button's ZIndex sits above the Star's. Header Back and Help are checked at 667 px. | The deck results and difficulty picker build wallets too. |
| Route refuses while a hatch is pending | Also refuses while any of `toyIntent`, `hueIntent`, `materialIntent` or `featureIntent` is pending. | Otherwise it would force-close Customize in the middle of a purchase. |
