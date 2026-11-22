# Levels matter: notes from worker C (deck: gated balls and plates, Effects tab, deck juice) for D

No file of D's was touched. Without the lines below the shops and the Effects tab still work (they read `OwnerSnapshot`, the board attribute and `BoardRequest` themselves); locked buttons are disabled and no trail or flourish is drawn. No new column-0 locals in `init.client.lua`.

## init.client.lua

**1. Juice mount.** Anywhere after `eggViews`, `project` and `clientUI.deck` exist (best: right after `rendererPresentation.restoreCheap=...`, about line 2102):

```lua
-- Levels matter S3: the chosen merge pop, drop trail and start flourish (FieldEffects owns them; classic costs nothing).
rendererPresentation.fx:attachJuice({board=board,views=eggViews,project=project,launchY=Config.SpawnY,
 ready=function()local boot=clientUI.deck and clientUI.deck.boot;return not(boot and boot.host and boot.host.Visible)end})
```

It does nothing on the live place (`Levels.ceiling`), follows the attribute and the runtime switch, and steps inside the existing `fx:update`, `fx:setOwner`, `fx:observeDrop` and `fx:clear` calls, so no other render line changes.

**2. The one juice hook in the render host**, last line of `addView`, after `viewsById[id] = gel`:

```lua
	if rendererPresentation.fx.trail then rendererPresentation.fx:ballAdded(source) end -- deck juice: nil while classic
```

It only reads where a ball starts. Without it there is no trail; pops and flourishes still work.

**3. Locked items' way to the training** (balls, plates, effects), after `picker.onAccepted=...`:

```lua
picker.shop.callbacks.train=function(route)
 picker:close("stats")
 clientUI.openStats({from="rail",stat=route.stat,petId=route.petId})
end
```

## Nothing else

- `DeckPicker` is unchanged: Effects is the Deck style screen's own tab (no appearance slot). `picker.active` keeps the last of its three tabs while Effects shows, so the Stars store opened from Effects comes back to that tab.
- `EffectsShop.lua` is a new file beyond the plan's list (BackgroundShop / BallShop pattern).
- UICopy: uses D's `style.effects.*`, `shop.needs.*`, `shop.train`, `shop.reason.needsLevel`. No new keys.
- Two plates: no rows added. When D adds them, `Themes.Gated` is enough; the grid, chip, bar and lock follow.

## Found, not changed

Balls tab, desktop, parts off (and live): 13 themes in two columns of 134 px rows with no scrolling, so rows 4 to 7 fall outside the 608 px panel. While a gated theme is listed (beta) the grid scrolls, which fixes it there. Off is left exactly as it is; to fix it live, scroll whenever more than 6 are listed (`#order>#Themes.Order` in `BallShop:build`).

## Specs

New: `DropTrail` (9), `DeckJuiceClient` (10), both `(PlayerScripts.Client, PlayerGui)`. Changed: `DeckStyle` (pins the part off for every old case, then the gated theme and the Effects tab on at 1920x1080, 812x354, 667x375). Other client specs that build Deck style run with four tabs while Studio's switch is on.
