# Lane B inputs (rotation slice 2)

## From lane D (branch worktree-agent-ae1c9ec69b0243ff1, 23894746)
- init.client.lua hook:
  picker.onDeckEgg=function(kind,id) -- "plate"|"ball"
   picker:close("forced")
   if clientUI.hub and clientUI.hub:isOpen()then clientUI.hub:close("eggs")end
   clientUI.eggPick={id="deck",at=os.clock()}
   task.defer(function()if not visitEggs()then clientUI.eggPick=nil end end)
   return true
  end
- UICopy: rack.deck.fromEgg "From the Deck Egg"; rack.deck.reason "Plates and balls come from the Deck Egg now."; plus brief's rack.deck.more / promise / title.
- r3.help.style.a.line under the switch: "Dress up your Pocket Deck. New plates come from the Deck Egg." (HowItWorks pattern like rack.closet.book).
- Assumes switch DailyRack.on("deck") (+ on("rack")); refused buy reason FromDeckEgg; DeckCloset pins 12 plates + 11 ball ids.

## From lane C (branch worktree-agent-a45407ceb7603e151, 332931f0)
- ToySkins.lua stub (lane A's wins at merge); ToySkinLook.lua is the only reader.
- init.client.lua hooks:
  1. nurseryView.appearanceFor (:1095) owned pets: a.toySkins = clientUI.hueView.toyPanel:shownSkins(state) (require ToySkinLook inside the function; no top-level local)
  2. like storeFirst (:3759): toyPanel.options.wearSkin=function(o) nurseryRequest:FireServer("toySkinWear",{id=o.id,toyId=o.toyId,skinId=o.skinId},revision) end
  3. WearableResult handler (:1340): clientUI.hueView.toyPanel:result(message)
- Unowned: HatchDisplayItem.lua:107 pass result.toySkin as the 4th arg to create.
- UICopy: rack.toy.more "More colours come from the Toy Colour Egg."; rack.toy.original "Original".
- Assumes state.rack.toy={owned,worn} only while switch on; owned map or list; PetAppearance[pet].toySkin; reply on WearableResult {action="toySkinWear",id,status,reason}; "none" = original.

## From lane E (branch worktree-agent-ae4b2effd372add27, 5379f8ca)
- UICopy: rack.wings.tab "Back"; rack.wings.note "Your own wings rest while these are on"; rack.wings.name "Angel Wings".
- Hatch reveal: AngelWings.previewPose(appearance) -> turn + camera pull, for EggHatchView if it doesn't use CardPreviewCache.
- Assumes A: forPet(pet,math.huge).byId.angelwings {slot="Back", egg=true, finish="sparkle"}; Bear rows item="angelwings", slot Back, anchors WingL/WingR, mesh from row.template or row.name (WingL_S5); halo uses HatCrown; Tabs gets {id="back",slot="Back"}.

## From lane A (server, merged 8e38b38b)
- public.rack: outfit as slice 1 + `full`; on wings days `outfit.sparkle={id="angelwings",wings=true,rarity="legendary",finish="sparkle",units,percent=1,owned}`.
- rack.toy (rack_toys on): {day, price=15, mode, rest, next?, total, poolKey, broken, full, owned={skinId=true}, worn={toyId=skinId}, items={{id,toy,rarity,weight,units,percent,owned,locked,name,hex}}}.
- rack.deck (rack_deck on): {day, price=60, mode, rest, next?, total, poolKey, full, closet=true, items={{id,kind="plate"|"ball",rarity,weight,units,percent,owned,name}}}.
- rack.last carries `kind` for a Deck pick.
- Requests: rackEgg {egg="outfit"|"toycolour"|"deck", id, petId, day, price, mode, poolKey, equip?} (toycolour + equip wears in the same write; deck "Use it!" uses the existing plate/ball equip paths). toySkinWear {id, toyId, skinId ("none" = original)} → WearableResult {action="toySkinWear", id, toyId, skinId, status, reason}.
- New refusals: ShelfFull, FromDeckEgg, LockedToy, NotOwned, InvalidSkin; malformed rack.toy → RackBroken for toy actions only.
- UICopy keys: rack.toy.title/.label/.line/.locked/.rest/.more/.original; rack.deck.title/.label/.line/.rest/.more/.promise/.use/.full; rack.wings.name/.tab. (Values: brief section 5, plus the C/D/E strings above.)
- Wings are NOT in forPet(...).order (Book stays 100%); use eggBases(pet), closetTab, tabsFor(pet, owned).
- Client must hide This week plate/ball deals while rack.deck.closet (server already refuses them).
