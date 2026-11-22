# Live fixes: plan (Opus, 2026-11-22)

Spencer: "push the fixes to live when done ... fold those fixes in for the next builds and the smaller ones". Source: the post-release code review of 3b32b8a / 283546a / 2c644a5 (TODO, PLAY-BUILD corrections).

## Goal

Every finding from that review is fixed, reviewed and tested before one live publish. No new features.

## Changes

| # | Finding | Change |
|---|---|---|
| 1 | Store icons queue ahead of the hatch prewarm at join | `StoreView.new` no longer calls `warmIcons`. StylePreload already leads with the icons (background priority), and `buildChrome` warms them on open. |
| 2 | Icon retries spend several tries per failure, exhausted icons never re-asked | One live ask per icon: keep its ticket, cancel it before a retry, ignore stale callbacks. Retry only while the page is open. Opening the page resets the count for icons that are not ready. |
| 3 | Mesh ids asked for as images | Done in 39d8544 (skip `mesh` fields, spec case). Needs its first Studio run. |
| 4 | Closing the store can focus a hidden Hatch eggs row on gamepad | `StoreView:close` restores `previousSelection` only if it and all its ancestors are visible, interactable and enabled, else nil. |
| 5 | Desktop `Kit.shellPattern` leaks a connection and its Fade per rebuild | Keep the `fill` connection and disconnect it in `ctl.destroy`. |
| 6 | Back sound fires twice | The store's Back closes Hatch eggs with a new reason `"storeBack"`, which does not call `onAccepted`. `nurseryView.onClosed` treats `"storeBack"` as `"close"` for `machineReturn=="hatch"` only. |
| 7 | Back from the store: Deck style, Settings and Customize go to the garden; Stats and Names forget the pet; the way back to the Pocket menu is lost | New module `StarsRoute.lua` (below). |
| 8 | No spec for the Back route | `StarsRoute` spec, plus `storeReturn` cases in the StoreView spec. |

### StarsRoute.lua

`Route.capture(deps)` is pure over injected functions and is called before `closeAllMenus`. It returns nil (garden), `"hub"` (the machine hub, as today through `machineReturn="hatch"`), or a function that reopens what was open:

- **Base screen** (first that is open): Names `{petId, from, tab}`, Stats `{petId = petOverride, from, stat}`, Customize `openHue(page, petId, back)` only for `back` = `"companions"` or `"hub"`, Companions `openHub({page})`, Book `openBook({page})`, Quests `openQuestLog(tab, {fromHub})`, Deck style / Settings `openPicker(mode, back, source)`.
- **Wardrobe** reopens on top of the base screen when it was open over one.
- It also saves and restores `machineReturn` and the screen's own return marker (`pickerReturn`, `questFromHub`), so Back from the reopened screen still leads to the Pocket menu.
- Customize at the care machine (`hueReturn=="machine"`), the journal and anything that refuses to reopen: the garden.

`init.client.lua` keeps the open/refuse logic and passes the deps in.

## Not in this slice

- MachineHub spec's order-dependent failure (cause unknown, test only).
- Restoring Customize's exact tab, scroll positions or an open confirm dialog.
- Showing a player's Roblox discount in our price.

## Edge cases

| Case | Behaviour |
|---|---|
| Round starts, a hatch result arrives or a screen refuses on Back | The reopener's own guards return false: the garden |
| Store closed by force (round, hatch) | Nothing reopens |
| Player buys Stars, then Back | The reopened screen gets the current snapshot |
| Companions opened from the Pocket menu, then store, Back, Back | Pocket menu |
| Two quick Backs | `storeReturn` is cleared on the first; one reopen |

## Test plan

Specs in Studio Play: StarsRoute (new), StoreView, StylePreload, StarsStoreAccess, HatchEggsList, EggShopReopen, CompactEggShop, KitSurfaces, ToyShell, WalletStar, DeckHeader, MachineHub (alone), CompanionsHub, NameScreen, BookView, DeckStyle, UIShellQA, CompactPhone.

Live in Studio with the window focused: store and Back from the Pocket menu, Companions, Wardrobe, Names, Stats, Book, Quests, Deck style, Customize and Hatch eggs; one free test purchase; no "Asset type does not match" errors from our ids in the output.

## Release gate (missed last time)

1. Code Reviewer verdict on the final diff, findings applied, specs rerun.
2. The Studio output log read for new errors.
3. Beta publish, then live: Rojo stopped, strip report, translation export and sync, File > Publish, PLAY-BUILD, TODO, and a listing audit that actually opens the listing.
4. Servers are restarted only if Spencer says so.
