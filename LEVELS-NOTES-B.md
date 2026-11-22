# Levels matter: notes from worker B (menus, park) for D and C

Every line below is optional: without it the screens still work, with the fallback named. No new column-0 locals in `init.client.lua`. `openPicker(mode,back,source)` modes: `Shell` = faceplates, `Balls` = balls.

## init.client.lua (D)

**1. StatsHost mount** (the `clientUI.stats=require(script.StatsHost).mount({...` table): add

```lua
  -- Levels matter: the reward guide's "Go to shop", the medal moment and its sting.
  openShop=function(area,ref)task.defer(function()
   if area=="wardrobe"then clientUI.openWardrobe(board:GetAttribute("CompanionId"),ref)
   else openPicker(if area=="balls"then "Balls"else "Shell",nil,"workbench")end
  end)end,
  audio=audio,playerGui=gui.Parent,
  quiet=function()return board:GetAttribute("Mode")=="Room"and not roomView.busy and not roomView.focusing and not nurseryView:isOpen()
   and not(nurseryState and nurseryState.lastHatch)and not(clientUI.snacks and clientUI.snacks.reveal and clientUI.snacks.reveal:isOpen())
   and not clientUI.book:isOpen()and not clientUI.hueView:isOpen()and not clientUI.isWardrobeOpen()and not clientUI.hub:isOpen()
   and not modal.Visible and not isPickerOpen()and not clientUI.questLog.visible and not GuiService.MenuIsOpen
   and not(clientUI.names and clientUI.names.isOpen())and not clientUI.deckResults.visible end,
```

Without `openShop` the guide shows no shop keys. Without `quiet` medals show as a rail ticket only (no stage). `clientUI.stats.isBusy()` is true while the medal stage is up: add it beside `clientUI.stats.isOpen()` wherever other menus ask "is something modal open" (lines 55, 1736, 1760, 4490) and to the `names`/`book` `canOpen` guards if they can be opened under it; the stage sinks A, B, Enter, Space, Escape and Backspace itself.

**2. Wardrobe** (`clientUI.wardrobe=WardrobeShop.new(host,{...`): add

```lua
  -- Levels matter: a locked item's button goes to the stats panel on the stat that unlocks it.
  train=function(route)
   clientUI.wardrobe:close();if clientUI.hub:isOpen()then clientUI.hub:close("stats")end
   clientUI.openStats({from="rail",stat=route.stat,petId=route.petId})
  end,
```

Without `train` the button is disabled. `clientUI.openWardrobe=function(petId,itemId)`: after `clientUI.wardrobe:open(...)` add `if itemId then clientUI.wardrobe:showItem(itemId)end`. Its `WearableCatalog.item(order.petId,order.itemId)` in `done` may stay (buys only). The Wardrobe reads levels from `OwnerSnapshot` itself; `context()` needs nothing.

**3. Bond block** (about 3337): replace the loop body's toast while the track is on (Heart tickets already name Heart tricks, so this only fires for a trick Bond XP brought):

```lua
  local Toasts=require(script.StatToasts)
  if Toasts.tricksOn()then
   for _,event in ipairs(Toasts.trickUps(clientUI.bondSeen,state))do
    if Pets.isActive(event.petId)then
     if not event.heart then clientUI.coach.toaster.show(event.text)end
     roomView:bondLevelUp(event.petId,event.level)
    end
   end
   return
  end
  clientUI.bondSeen.tricks=nil -- off: the old pips and toast, with a fresh trick baseline next time
```

Put it right after `if type(bond)~="table"then return end`. Keep calling `BondPips.levelUps` first when the track is on if you want its baseline current (its result is ignored): `BondPips.levelUps(clientUI.bondSeen,bond)`.

**4. Book, Companions, inspect, focus card, park**: no mount lines. They read `OwnerSnapshot` / public attributes and `Levels.on`.

## Runtime switch

`WardrobeShop` and `StatsPanel` rebuild when `Levels.key()` changes, `CompanionsHub` and `BookView` re-read the part on every snapshot, so the snapshot the server pushes after a flip updates an open screen. A card already open in `PetInspect` hides its Marks row on the next paint. Nothing listens to `Levels.changed()`.

## Medal images

`MedalView.Art` is empty. After the upload: `MedalView.Art={[25]={tint="rbxassetid://..",trim="rbxassetid://.."},[50]=...,[75]=...,[99]=...}`. A missing half keeps that tier's drawn discs. Stings: `MedalView.Sting` uses the existing hatch stings until the four medal stings are uploaded.

New file beyond the list: `src/client/MedalView.lua` (one drawing for the panel slots, the Marks row, the guide and the medal moment). On phones the Marks sit in the inspect card's summary strip (a row of their own would push the card past the top-bar rule). The guide has no "Also good for" block: no job rows exist yet, so `stats.guide.jobs` is unused.

## C: LockedItem

`local Locked=require(script.Parent.LockedItem)`; `Locked.info(item,Locked.levels(),owned)` is nil when ungated, owned or gates off; otherwise `{met,needs,short,count,line,ratio,color,stat,total}`. `Locked.chip(parent,h).set(info,maxWidth)`, `Locked.bar(parent,x,y,w,h).set(info)`, `Locked.mark(picture,size).set(shown)`, `Locked.trainText(info,petName)`, `Locked.route(info)` (StatsHost.open options). `Reasons.NeedsLevel="shop.reason.needsLevel"`.
