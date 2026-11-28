-- Wardrobe: pet wearables for Stars (the faceplate shop pattern, UI-SPEC-2026-11-12
-- section 3 components, UI-SPEC-COMPACT section 5 sheet on phones).
-- Opened from the Companions editor at the Care Cradle. Slot tabs (hat, shirt, neck,
-- ears, eyes, mouth, tail), item cards with price / owned / wearing states, and a pinned
-- preview pane where the pet wears the focused item live. Fixed prices; the server
-- validates, debits and saves (HatchProgress.buyWearable / equipWearable).
-- Focus is owned here: d-pad / arrows / WASD move, Q / E and L1 / R1 switch tabs,
-- A / Enter acts, B / Backspace backs out. Touch: the first tap selects, the pane
-- button (or a second tap) acts.
local GuiService=game:GetService("GuiService")
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage").Shared
local Catalog=require(Shared.WearableCatalog)
local Pets=require(Shared.PetCatalog)
local Rules=require(Shared.PetAttachmentRules)
local Defs=require(Shared.PetRigDefinitions)
local Palette=require(Shared.PetPalette)
local Kit=require(script.Parent.DeckKit)
local UICopy=require(Shared.UICopy)
local Factory=require(script.Parent.PetFactory)
local Bounds=require(script.Parent.PetRigBounds)
local TabInk=require(script.Parent.TabInk)
local HintLegend=require(script.Parent.HintLegend)
local Deal=require(script.Parent.ShelfDeal)
-- "This week" (ThisWeek): one recolour a week at its full price, in a tab of its own while the switch is on.
local ThisWeek=require(Shared.ThisWeek)
-- Levels matter (S2): level-gated recolours (the chip, the bar and the way to the training).
local Levels=require(Shared.Levels)
local Locked=require(script.Parent.LockedItem)
-- The daily rack, lane C (ROTATION-BRIEF 1 "Wardrobe with the switch on" and 2 "Colour selector"; ctx.closet, the
-- DailyRack "rack" switch): the closet (one card per base item, "From the Outfit Egg" on what the pet does not own,
-- only level-gated rows and the This week pick for sale) and the swatch row (owned colours, one equip at a time).
-- Off (ctx.closet not true): the Wardrobe exactly as before.
local Swatches=require(script.Parent.WardrobeSwatches)
local Finish=require(script.Parent.WearableFinish)
-- Angel Wings (ROTATION-2-BRIEF 3): an egg-only Back item, never sold; its card (and the Back tab) shows only once owned.
local Wings=require(script.Parent.AngelWings)
local Shop={}
Shop.__index=Shop
Shop.Size=Vector2.new(848,608)
Shop.ConfirmSeconds=3
local TierChip={common={"COMMON",Color3.fromHex("#9BE3A8")},rare={"RARE",Color3.fromHex("#8CC8FF")},showcase={"SHOWCASE",Color3.fromHex("#E6B3FF")}}
-- Outfit Egg rows carry a rarity (ROTATION-BRIEF 3 pills: Common grey, Uncommon green, Rare blue, Epic purple, Sparkle gold).
local RarityChip={common={"COMMON",Color3.fromHex("#D3D8DF")},uncommon={"UNCOMMON",Color3.fromHex("#9BE3A8")},rare={"RARE",Color3.fromHex("#8CC8FF")},
 epic={"EPIC",Color3.fromHex("#E6B3FF")},legendary={"SPARKLE",Color3.fromHex("#FFD86B")}}
Shop.RarityChip=RarityChip
-- The closet's words: UICopy keys (lane B owns UICopy; these fall back to the English until the keys land).
Shop.ClosetCopy=table.freeze({
 fromEgg={"rack.closet.fromEgg","From the Outfit Egg"},
 go={"rack.closet.go","Hatch an Outfit Egg"},
 tile={"rack.closet.tile","Outfit Egg"},
 more={"rack.closet.more","More colours come from the Outfit Egg."},
 promise={"rack.closet.promise","Clothes come from the Outfit Egg."},
 reason={"rack.closet.reason","Clothes come from the Outfit Egg now."},
 -- Angel Wings: the Back tab and the pane's note while the pet has grown wings of its own.
 wingsTab={"rack.wings.tab","Back"},
 wingsNote={"rack.wings.note","Your own wings rest while these are on"}})
function Shop.closetCopy(name)
 local row=Shop.ClosetCopy[name];if not row then return ""end
 return if UICopy.has(row[1])then UICopy.get(row[1])else row[2]
end
local SlotNote={Hat="Hats sit on the crown",Shirt="Sleeves move with the arms",Neck="Draws over a shirt",EarPiercing="A pair, one for each ear",
 Eyes="Replaces the eyes",Mouth="Replaces the neutral smile",Tail="Replaces the tail"}

-- QA v2 R4.2: every slot tab starts with a "None" card (take the slot off). It is a
-- card like the others: focus previews the bare slot, A / Enter saves the take-off
-- through the same server path (wearableEquip with itemId=false, validated there).
Shop.NoneId="none"
-- Pure: the cards of one slot tab (None first, then the catalogue items). A slot
-- with no items for this pet has no cards at all (the empty line shows instead).
-- `owned` (the pet's owned ids): a gated item it owns stays listed while gates are off.
-- `tab` (optional): the "This week" tab holds its one pick and no None card.
-- `closet` (the rack switch): the closet's cards (WearableCatalog.closetTab): one per base item, plus unowned gated rows.
function Shop.tileList(petId,slot,owned,tab,closet)
 if not petId then return {}end -- before the first open there is no pet yet (slice E)
 if type(tab)=="table"and tab.thisWeek then
  -- The tab already decided the pick is listed (Shop.thisWeekTab); status decides what it sells.
  local item=Catalog.forPet(petId,math.huge).byId[tab.thisWeek]
  return if item then {item}else {}
 end
 local items=Shop.slotCards(petId,slot,owned,closet)
 if #items==0 then return {}end
 local list={{id=Shop.NoneId,none=true,slot=slot,name=UICopy.get("r4.wardrobe.none")}}
 for _,item in ipairs(items)do table.insert(list,item)end
 return list
end
-- Pure: one slot tab's catalogue cards (the closet's or the shop's), without an egg-only base the pet does not own
-- (Angel Wings: a card only once owned, so its Back tab shows only then; AngelWings.ownedOnly).
function Shop.slotCards(petId,slot,owned,closet)
 local items=if closet==true then Catalog.closetTab(petId,slot,owned)else Catalog.shopTab(petId,slot,owned)
 return Wings.ownedOnly(items,owned)
end
-- Pure: the item if it is for sale to this pet now. A "This week" pick is for sale only in the server's week
-- (ctx.thisWeek, public.thisWeek), never by the device clock (review B37); everything else is the catalogue's list.
function Shop.forSale(petId,itemId,ctx)
 if ThisWeek.isWeekly(itemId)then
  local week=ctx and ctx.thisWeek
  return if type(week)=="number"then Catalog.forPet(petId,week).byId[itemId]else nil
 end
 return Catalog.item(petId,itemId)
end
-- Pure: an item by id. A gated item the shop does not list (gates off), or a "This week" item
-- outside its week, still resolves, so an owned one can be seen, worn and taken off; `status`
-- never sells it.
function Shop.item(petId,id)
 local item=Catalog.item(petId,id)
 if item then return item end
 local any=Catalog.forPet(petId,math.huge).byId[id]
 -- An Outfit Egg row (never sold) resolves too, so an owned one is seen, worn and taken off.
 return if any and(any.gate~=nil or any.weekly==true or any.egg==true)then any else nil
end
-- Pure: the None card's pane. Current when nothing is worn in the slot.
function Shop.noneStatus(petId,slot,ctx)
 local row=(ctx and ctx.row)or {owned={},equipped={}}
 if Catalog.equippedIn(petId,row.equipped,slot)==nil then return {kind="equipped",text="",button=UICopy.get("r4.equipped"),enabled=false}end
 return {kind="owned",text="",button=UICopy.get("r4.wardrobe.takeOff"),enabled=true}
end
-- Pure: what the pane says and offers for one item.
-- ctx = { petId, wallet, row = {owned={...}, equipped={key=id}}, levels = {petId={stat=level}} }
-- QA v2 R3.5: the item being worn keeps its button, disabled, reading "Equipped"
-- (taking it off is the None card).
function Shop.status(petId,itemId,ctx)
 local item=Shop.item(petId,itemId)
 if not item then return {kind="invalid",text="",button=nil}end
 local row=ctx.row or {owned={},equipped={}}
 local owned=table.find(row.owned or {},itemId)~=nil
 -- The closet: what the pet does not own and the Wardrobe no longer sells comes from the Outfit Egg (the button opens it).
 if not owned and ctx.closet==true and not Catalog.closetSells(item)then
  return {kind="egg",text=Shop.closetCopy("fromEgg"),button=Shop.closetCopy("go"),enabled=true}
 end
 if not owned and not Shop.forSale(petId,itemId,ctx)then return {kind="invalid",text="",button=nil}end
 -- An egg-only base with no colours (Angel Wings) has no "more colours" line.
 local more=if ctx.closet==true and not(item.egg==true and item.variant~=true and #Catalog.family(petId,item.id)<2)then Shop.closetCopy("more")else ""
 if owned and Catalog.equippedIn(petId,row.equipped,item.slot)==itemId then return {kind="equipped",text=more,button=UICopy.get("r4.equipped"),enabled=false}end
 if owned then return {kind="owned",text=more,button="Wear",enabled=true}end
 local wallet=ctx.wallet or 0
 -- Levels matter (S2): below the level the pane shows the way there; the card shows the chip.
 local gate=Locked.info(item,ctx.levels)
 if gate and not gate.met then
  local pet=gate.petId and Pets.byId[gate.petId]or Pets.byId[petId]
  return {kind="locked",text=gate.line,button=Locked.trainText(gate,pet and pet.name),price=item.price,gate=gate,enabled=true}
 end
 -- Slice C: an item on this week's shelf sells at the shelf price (`full` = the struck price).
 local price,full=Deal.quote("wearable",itemId,item.price,ctx.week)
 -- This week: the pick at its full price, and the stated cycle (never a countdown).
 if item.weekly==true and wallet>=price then
  local lines=Shop.thisWeekLines()
  return {kind="buy",text=lines[1],fit=lines,button="★ Buy "..price,price=price,enabled=true,thisWeek=true}
 end
 if wallet>=price then return {kind="buy",text=if full then UICopy.get("shelf.status")else "You have enough Stars",button="★ Buy "..price,price=price,full=full,enabled=true}end
 return {kind="short",text=require(script.Parent.ShopPriceState).need(price,wallet),button="★ Buy "..price,price=price,full=full,enabled=false}
end
function Shop.tileStatus(petId,itemId,ctx,slot)
 if itemId==Shop.NoneId then
  if Shop.noneStatus(petId,slot,ctx).kind=="equipped"then return "WEARING","accent"end
  return "","soft"
 end
 local s=Shop.status(petId,itemId,ctx)
 if s.kind=="equipped"then return "WEARING","accent"end
 if s.kind=="owned"then return "✓ Owned","soft"end
 if s.kind=="buy"then return Deal.priceText(s.price,s.full),"stars"end
 if s.kind=="short"then return Deal.priceText(s.price,s.full),"dim"end
 if s.kind=="locked"then return "","dim"end -- the chip stands where the price would
 if s.kind=="egg"then return Shop.closetCopy("tile"),"soft"end
 return "","dim"
end
-- This week: the pane line for the pick, longest first ("This week's pick. Back every 8 weeks.", then the short one).
function Shop.thisWeekLines()
 return {UICopy.get("thisWeek.status",{weeks=ThisWeek.Every}),UICopy.get("thisWeek.statusShort",{weeks=ThisWeek.Every})}
end
-- Pure: the "This week" tab for this pet in `week` (the server's week, ShelfDeal.thisWeek), or nil: no week (the
-- server's switch is off, or no snapshot yet), the switch is off here, or the pet's rig does not sell this week's
-- pick. Its slot is the pick's own slot.
function Shop.thisWeekTab(petId,week)
 if not petId or type(week)~="number"then return nil end
 local row=ThisWeek.featured(week)
 local item=row and Catalog.forPet(petId,week).byId[row.id]
 if not item then return nil end
 return {id="thisweek",slot=item.slot,label="This week",copy="thisWeek.tab",thisWeek=item.id}
end
-- Slice E: the pet the Wardrobe opens on when none (or one without wearables) is asked
-- for: the first active pet that has items, else the first active pet.
function Shop.firstPet()
 for _,pet in ipairs(Pets.active)do if Catalog.hasItems(pet.id)then return pet.id end end
 return Pets.active[1]and Pets.active[1].id or nil
end
-- Slice B: only slot tabs with at least one item for this pet are shown (Ankle stays
-- hidden until an anklet exists). A pet with no wearables at all keeps every tab, so
-- the screen still has a tab bar and the empty line.
function Shop.tabsFor(petId,owned,week,closet)
 local list={}
 if petId then
  for _,tab in ipairs(Catalog.Tabs)do
   if #Shop.slotCards(petId,tab.slot,owned,closet)>0 then table.insert(list,tab)end
  end
  -- This week: its own tab, last in line so the Wardrobe never opens on a sale item (only while the switch is on and
  -- this pet's rig sells the pick).
  local pick=Shop.thisWeekTab(petId,week)
  if pick then table.insert(list,pick)end
 end
 if #list==0 then for _,tab in ipairs(Catalog.Tabs)do table.insert(list,tab)end end
 return list
end
function Shop.tabKey(tabs)
 local ids={};for _,tab in ipairs(tabs)do table.insert(ids,tab.id)end
 return table.concat(ids,",")
end
-- A tab's label: the UICopy string for the new tabs, the catalogue's label otherwise.
function Shop.tabLabel(tab)
 if tab.copy then return UICopy.get(tab.copy)end
 if tab.slot=="Back"then return Shop.closetCopy("wingsTab")end
 local key="variants.tab."..tostring(tab.id)
 return if UICopy.has(key)then UICopy.get(key)else tab.label
end
-- Pure: the tab track for these labels in `width` px. Every segment holds its label with
-- TabPad px to spare (plus translation headroom while Roblox auto-translates); when equal
-- segments of `width` cannot, the track grows and the strip scrolls sideways.
-- Returns {track, segment, scroll}.
Shop.TabPad=16
Shop.TabHeadroom=.35
function Shop.tabStrip(labels,width,textSize,translating)
 local widest=0
 for _,label in ipairs(labels)do widest=math.max(widest,Kit.measure(label,"Strong",textSize).X)end
 local need=math.ceil(widest*(if translating then 1+Shop.TabHeadroom else 1))+Shop.TabPad
 local count=math.max(1,#labels)
 local segment=(width-8)/count
 if segment>=need then return{track=width,segment=segment,scroll=false}end
 return{track=count*need+8,segment=need,scroll=true}
end
-- Pure: the strip's scroll x that brings tab `index` (and half a neighbour) into view.
function Shop.tabReveal(index,plan,view,x)
 local left=4+(index-1)*plan.segment;local right=left+plan.segment
 local peek=plan.segment*.5
 if left-peek<x then x=left-peek elseif right+peek>x+view then x=right+peek-view end
 return math.clamp(x,0,math.max(0,plan.track-view))
end
-- Slice B: a recolour variant's own colour (nil for a base item or a bad hex).
function Shop.variantColor(item)
 if type(item)~="table"or item.variant~=true or type(item.color)~="string"then return nil end
 local ok,color=pcall(Color3.fromHex,item.color)
 return if ok then color else nil
end
-- Pure: the preview's wearables signature. Variant ids stay as worn (so beanie and
-- beanie_mint differ); the rig check runs on their base ids (WearableCatalog.renderMap).
function Shop.previewSignature(petId,wearables)
 wearables=wearables or {}
 local mapped=wearables
 if type(Catalog.renderMap)=="function"then
  local ok,render=pcall(Catalog.renderMap,petId,wearables)
  if ok and type(render)=="table"and type(render.mapped)=="table"then mapped=render.mapped end
 end
 local kept={}
 for key in pairs(Rules.normalize(Defs[petId],mapped))do kept[key]=wearables[key]end
 return Rules.signature(kept)
end
-- Pure: the wearables shown on the preview pet: what is saved, with the focused item
-- swapped into its slot (or the slot emptied when the focused item is the one worn).
function Shop.previewWearables(petId,equipped,itemId)
 local result=table.clone(equipped or {})
 local item=itemId and Shop.item(petId,itemId)
 if not item then return result end
 for _,key in ipairs(Catalog.slotKeys(petId,item.slot))do result[key]=nil end
 for _,key in ipairs(item.keys)do result[key]=item.id end
 return result
end
-- Pure: a short line about exclusions for the focused item (hide, never unequip).
function Shop.note(petId,itemId,stages)
 local item=Shop.item(petId,itemId);if not item then return ""end
 local horns=(stages and stages.horns or 0)>0
 if item.slot=="Hat"and item.flags.openCrown then return if horns then "Open crown: your horns stay visible"else "Open crown: horns stay visible"end
 if item.slot=="Hat"and item.flags.coversHorns and horns then return "Hides your horns while worn"end
 if item.slot=="Mouth"and item.flags.neutralOnly then return "Shows on the neutral face; other moods keep their mouth"end
 if item.slot=="Back"and(stages and stages.wings or 0)>0 then return Shop.closetCopy("wingsNote")end
 -- Slice B: a recolour says which item it recolours; the new slots' notes are UICopy strings.
 if item.variant==true and type(item.base)=="string"then
  local base=Catalog.item(petId,item.base)
  if base then return UICopy.get("variants.note",{item=base.name})end
 end
 if SlotNote[item.slot]then return SlotNote[item.slot]end
 for _,tab in ipairs(Catalog.Tabs)do
  if tab.slot==item.slot and UICopy.has("variants.slot."..tab.id)then return UICopy.get("variants.slot."..tab.id)end
 end
 return ""
end
function Shop.step(index,dx,dy,count,columns)
 local cols=math.max(1,columns or 2)
 local col,row=(index-1)%cols,math.floor((index-1)/cols)
 local rows=math.max(1,math.ceil(count/cols))
 col=math.clamp(col+dx,0,cols-1);row=math.clamp(row+dy,0,rows-1)
 return math.max(1,math.min(count,row*cols+col+1))
end
-- Pure (UI-SPEC-COMPACT 9 geometry): pane width, grid width, columns, tile width.
function Shop.compactGrid(W,H)
 local pw=if W<700 then 200 else 232
 local gw=W-pw-52
 local cols=if gw>=420 then 2 else 1
 return{pw=pw,gw=gw,cols=cols,tileW=math.floor((gw-8-(cols-1)*8)/cols),paneH=H-82,gridH=H-82-48}
end
function Shop.viewKey(view)return if view then string.format("%dx%d:%d",view.W,view.H,view.hx)else "regular"end
-- QA Q2.3 card previews: each visible card shows the pet wearing only that item,
-- framed on the slot, in its own ViewportFrame. Built lazily (one per frame, visible
-- cards only), cached per pet / item / tint while the Wardrobe is open, and the
-- colour tile stays as the fallback when a rig cannot be built.
-- Code review: only visible cards hold a ViewportFrame (at most CardPreviewLive at
-- once); a card scrolled off screen has its preview detached, and past the cache size
-- the least recently shown detached preview is destroyed (visible ones never are).
Shop.CardPreviewLive=12
Shop.CardPreviewCache=24
-- Pure: where a card preview's camera looks ("head", "body" or "tail") and its zoom.
Shop.HeadSlots=table.freeze({Hat=true,Eyes=true,Mouth=true,EarPiercing=true,Eyewear=true,Cheek=true})
function Shop.cardFraming(slot)
 if Shop.HeadSlots[slot]then return "head",.62 end
 if slot=="Tail"then return "tail",.85 end
 -- Back (Angel Wings): the camera 15% further back so both wings and the halo fit the card.
 if slot=="Back"then return "body",.9*Wings.Preview.pull end
 return "body",.9
end
-- Pure: the preview pet's turn for a slot tab: the tail faces the viewer; Back turns 35 degrees so the wings read from
-- the front; everything else the slight turn (`default`: the pane -.25, a card -.35).
function Shop.slotYaw(slot,default)
 if slot=="Tail"then return math.pi*.8 end
 if slot=="Back"then return Wings.Preview.yaw end
 return default
end
-- Pure: the cache key (a tinted item renders in the pet's own palette colour).
function Shop.cardKey(petId,itemId,tint)return petId..":"..itemId..":"..(if tint then tint:ToHex()else "")end
-- Pure: is a card (top y, height) inside the scroll window (top y, height), with a margin.
function Shop.cardVisible(cardY,cardH,windowY,windowH)
 return cardY+cardH>=windowY-8 and cardY<=windowY+windowH+8
end

-- Toy Shell: a role read on `object`'s own surface (ink on cream tiles, white on trays).
local function colorOf(role,object,property)return Kit.roleOn(object,role,property)end
local function txt(parent,role,content,color,x,y,w,h,props)
 local t=Kit.text(parent,role,content,color,props);t.Position=UDim2.fromOffset(x,y);t.Size=UDim2.fromOffset(w,h);return t
end

-- host: a full-screen Frame. callbacks: buy(order), equip(order), back(), appearance(petId) -> appearance.
-- Slice E: no pet is named here. Until open(petId) the shop holds the first active pet that
-- has wearables (Shop.firstPet), so it can be built and measured before it is opened.
function Shop.new(host,callbacks)
 local self=setmetatable({host=host,callbacks=callbacks or {},tab=1,index=1,petId=Shop.firstPet(),tabList=Shop.tabsFor(Shop.firstPet()),ctx={wallet=0,row={owned={},equipped={}}},
  visible=false,pending=nil,confirmUntil=0,columns=2},Shop)
 -- QA Q2.1: one full-screen shade beside the panel (never its parent).
 local shade=Kit.modalShade(host,"WardrobeShade",40);self.shade=shade
 local root=Kit.frame(host,"WardrobeShop","panel",UDim2.fromScale(.5,.5),UDim2.fromOffset(848,608),30)
 root.AnchorPoint=Vector2.new(.5,.5);root.Active=true;root.ClipsDescendants=true;root.ZIndex=41;root.Visible=false;self.rootStroke=Kit.stroke(root)
 local gradient=Kit.frame(root,"Gradient",nil,UDim2.new(),UDim2.fromScale(1,1));gradient.BackgroundTransparency=0;gradient.BackgroundColor3=Color3.new(1,1,1)
 Kit.node("UIGradient",gradient,{Rotation=90,Color=ColorSequence.new(Color3.new(1,1,1),Color3.new(0,0,0)),Transparency=NumberSequence.new(.97,.88)})
 self.gradient=gradient;self.root=root
 self.scale=Kit.node("UIScale",root,{Scale=1})
 self:build(nil)
 return self
end

-- The visible tab list (slice B) and the tab in front.
function Shop:tabInfo()return self.tabList[self.tab]or self.tabList[1]end
function Shop:owned()return self.ctx.row and self.ctx.row.owned or nil end
function Shop:items()
 if not self.petId then return {}end
 local tab=self:tabInfo()
 if tab.thisWeek then return Shop.tileList(self.petId,tab.slot,self:owned(),tab)end
 if self:closet()then return Catalog.closetTab(self.petId,tab.slot,self:owned())end
 return Catalog.shopTab(self.petId,tab.slot,self:owned())
end
function Shop:closet()return self.ctx.closet==true end
-- A closet card stands for its base item's family: its face is the colour worn (else the base, else the first owned).
function Shop:faceOf(tile)
 if not tile or not tile.family then return tile and tile.id end
 return Catalog.closetFace(self.petId,tile.family,self:owned(),self.ctx.row and self.ctx.row.equipped)
end
function Shop:slot()return self:tabInfo().slot end
-- The pane status of a card (None included).
function Shop:statusOf(id)
 if id==Shop.NoneId then return Shop.noneStatus(self.petId,self:slot(),self.ctx)end
 return Shop.status(self.petId,id,self.ctx)
end

-- Shared pane pieces: a ViewportFrame with the pet, name, tier, note, status, action.
function Shop:buildPane(pane,pw,ph,compact)
 local pad=if compact then 12 else 16
 local nameH=if compact then 22 else 30
 local actionH=if compact then 48 else 56
 local lower=(if compact then 22+18+20+12 else 30+22+24+16)+actionH+pad
 -- Levels matter (art review): room for the level bar, 8 px tall and 10 px clear of the button.
 if Locked.on()then lower+=if compact then 8 else 16 end
 local viewH=math.max(80,ph-lower-pad)
 local _,well=Kit.previewWell(pane,"PreviewWell",UDim2.fromOffset(pad,pad),UDim2.fromOffset(pw-pad*2,viewH),12)
 local viewport=Kit.node("ViewportFrame",well,{Name="PetPreview",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=well.ZIndex+1});Kit.petLight(viewport)
 local world=Kit.node("WorldModel",viewport,{});local camera=Kit.node("Camera",viewport,{FieldOfView=30})
 viewport.CurrentCamera=camera
 self.viewport,self.world,self.camera=viewport,world,camera
 if self.visual then self.visual:destroy();self.visual=nil end
 -- Slice C: "THIS WEEK −20%" in the well's corner while the focused item is on the shelf.
 self.deal=Deal.chip(well,22);self.deal.root.ZIndex=well.ZIndex+3;self.deal.root.Position=UDim2.fromOffset(8,8)
 -- This week: the same corner for the weekly pick (it is never on the shelf, so the two never meet).
 local pick=Kit.chip(well,UICopy.get("thisWeek.chip"),"sticker",22);pick.label.TextSize=12
 pick.set(UICopy.get("thisWeek.chip"),"sticker",Kit.Color.stars)
 pick.root.Name="ThisWeekChip";pick.root.Visible=false;pick.root.Active=false;pick.root.ZIndex=well.ZIndex+3;pick.root.Position=UDim2.fromOffset(8,8)
 self.weekChip=pick
 self.dealWidth=pw-pad*2-16
 local y=pad+viewH+(if compact then 8 else 12)
 self.name=txt(pane,"Title","","text",pad,y,pw-pad*2-96,nameH,{TextSize=if compact then 18 else 24,TextTruncate=Enum.TextTruncate.AtEnd})
 self.tier=Kit.chip(pane,"RARE","sticker",if compact then 22 else 26);if compact then self.tier.label.TextSize=12 end
 self.tier.root.AnchorPoint=Vector2.new(1,.5);self.tier.root.Position=UDim2.fromOffset(pw-pad,y+nameH/2)
 y+=nameH+(if compact then 0 else 4)
 self.note=txt(pane,"Small","","soft",pad,y,pw-pad*2,18,{TextSize=12,TextTruncate=Enum.TextTruncate.AtEnd})
 self.lines={note=y,noteH=18,status=y+(if compact then 18 else 22),statusH=20}
 y=self.lines.status
 self.status=txt(pane,"Body","","soft",pad,y,pw-pad*2,20,{TextSize=14,TextTruncate=Enum.TextTruncate.AtEnd})
 local action,state=Kit.button(pane,"Action",{variant="primary",text="Wear",glyph="A",size=Vector2.new(pw-pad*2,actionH),textSize=if compact then 16 else nil,selectable=false})
 action.Position=UDim2.fromOffset(pad,ph-pad-actionH);self.action,self.actionState=action,state
 action.Activated:Connect(function()self:act()end)
 -- The colour selector (closet only): a row of round swatches along the foot of the preview well, scrolling sideways
 -- when the owned colours do not fit. Built empty; paintSwatches fills it for the focused card.
 local rowH=Swatches.Size+Swatches.Ring*2+4
 local strip=Kit.node("ScrollingFrame",well,{Name="Swatches",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.new(0,6,1,-rowH-6),
  Size=UDim2.new(1,-12,0,rowH),CanvasSize=UDim2.fromOffset(0,0),ScrollBarThickness=0,ZIndex=well.ZIndex+4,Selectable=false,
  ScrollingDirection=Enum.ScrollingDirection.X,Visible=false})
 self.swatchStrip,self.swatchKey,self.swatchButtons=strip,nil,{}
end
-- The swatch row for the focused card: visible in the closet when the card's base has two or more owned colours.
-- A ring marks the colour worn; a sparkle colour's swatch moves (WearableFinish) unless motion is reduced.
function Shop:paintSwatches(item)
 local strip=self.swatchStrip;if not strip then return end
 local list=if self:closet()and item and self.petId then Catalog.swatchRow(self.petId,item.id,self:owned())else nil
 strip.Visible=list~=nil
 self.root:SetAttribute("Swatches",if list then #list else 0)
 if not list then self.swatchButtons={};self.swatchKey=nil;for _,child in ipairs(strip:GetChildren())do child:Destroy()end;return end
 local ids={};for _,row in ipairs(list)do table.insert(ids,row.id)end
 local key=table.concat(ids,",")
 local width=math.max(1,strip.AbsoluteSize.X>0 and strip.AbsoluteSize.X or 160)
 if key~=self.swatchKey then
  self.swatchKey=key;self.swatchButtons={}
  for _,child in ipairs(strip:GetChildren())do child:Destroy()end
  local xs,canvas=Swatches.layout(#list,width)
  strip.CanvasSize=UDim2.fromOffset(canvas,0)
  for index,row in ipairs(list)do
   local size=Swatches.Size
   local b=Instance.new("TextButton");b.Name="Swatch_"..row.id;b.Text="";b.AutoButtonColor=false;b.BorderSizePixel=0
   b.Size=UDim2.fromOffset(size,size);b.Position=UDim2.fromOffset(xs[index],Swatches.Ring+2);b.ZIndex=strip.ZIndex+1;b.Selectable=false
   b.BackgroundColor3=Finish.still(row);b:SetAttribute("ItemId",row.id)
   Kit.node("UICorner",b,{CornerRadius=UDim.new(.5,0)})
   Kit.node("UIStroke",b,{Name="Edge",Thickness=1.5,Color=Kit.Sticker.cream,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
   local ring=Kit.node("Frame",b,{Name="Worn",BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
    Size=UDim2.new(1,Swatches.Ring*2+2,1,Swatches.Ring*2+2),ZIndex=b.ZIndex+1,Visible=false})
   Kit.node("UICorner",ring,{CornerRadius=UDim.new(.5,0)})
   Kit.node("UIStroke",ring,{Thickness=Swatches.Ring,Color=Kit.color("ink"),ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
   b.Parent=strip
   b.Activated:Connect(function()self:wearSwatch(row.id)end)
   self.swatchButtons[index]={button=b,ring=ring,row=row}
  end
 end
 local worn=Catalog.equippedIn(self.petId,self.ctx.row.equipped,item.slot)
 for _,entry in ipairs(self.swatchButtons)do
  local on=entry.row.id==worn
  entry.ring.Visible=on
  entry.button:SetAttribute("AccessibleLabel",Swatches.label(entry.row,on))
 end
end
-- Sparkle colours' swatches move at the finish stepper's pace (called from the open clock).
function Shop:stepSwatches(now)
 if not self.swatchStrip or not self.swatchStrip.Visible then return end
 if now-(self.swatchClock or 0)<1/Finish.Hz then return end
 self.swatchClock=now
 local reduced=Finish.reducedNow()
 for _,entry in ipairs(self.swatchButtons or {})do
  if Finish.moves(entry.row,reduced)then entry.button.BackgroundColor3=Finish.color(entry.row,now,false)
  elseif Finish.kind(entry.row)then entry.button.BackgroundColor3=Finish.still(entry.row)end
 end
end

function Shop:buildTiles(parent,x0,y0,tileW,tileH,gap,cols)
 self:detachPreviews()
 if self.tileRoot then self.tileRoot:Destroy()end
 local holder=Kit.frame(parent,"Tiles",nil,UDim2.new(),UDim2.fromScale(1,1));holder.ZIndex=parent.ZIndex+1;self.tileRoot=holder
 self.tiles={}
 local closet=self:closet()and not self:tabInfo().thisWeek
 for index,item in ipairs(Shop.tileList(self.petId,self:slot(),self:owned(),self:tabInfo(),closet))do
  local col,row=(index-1)%cols,math.floor((index-1)/cols)
  -- The closet: a base item's card stands for its family and shows its face (the colour worn, else one owned).
  local family=if closet and not item.none and not item.variant then item.id else nil
  if family then item=Shop.item(self.petId,Catalog.closetFace(self.petId,family,self:owned(),self.ctx.row.equipped))or item end
  -- T2: pressable tile with a lip (4 px in the 12 px desktop gap, 3 px in the 8 px phone gap).
  local tile,tileState=Kit.tile(holder,"Tile_"..item.id,{selectable=false,radius=12,compact=gap<12,
   position=UDim2.fromOffset(x0+col*(tileW+gap),y0+row*(tileH+gap)),size=UDim2.fromOffset(tileW,tileH)})
  local stroke=tileState.stroke
  tile:SetAttribute("AccessibleLabel",item.name);tile:SetAttribute("ItemId",item.id)
  -- Swatch: the item's own colour (or the pet's secondary for tinted items).
  local side=tileH-20
  local variantDot=nil
  local _,swatch=Kit.previewWell(tile,"Swatch",UDim2.fromOffset(10,10),UDim2.fromOffset(side,side),10);swatch.BackgroundTransparency=0
  if item.none then
   Kit.paint(swatch,"BackgroundColor3","well")
   local mark=Kit.icon(swatch,"none",math.floor(side*.5),"soft");mark.AnchorPoint=Vector2.new(.5,.5);mark.Position=UDim2.fromScale(.5,.5)
  else
   local variant=Shop.variantColor(item)
   swatch.BackgroundColor3=variant or(if item.primary then Color3.fromHex(item.primary)else Kit.Color.soft)
   local tier=TierChip[item.tier]or TierChip.common
   local dot=Kit.frame(swatch,"TierDot",nil,UDim2.new(1,-12,0,4),UDim2.fromOffset(8,8),999);dot.BackgroundTransparency=0;dot.BackgroundColor3=tier[2];dot.ZIndex=swatch.ZIndex+3
   -- Slice B: a recolour carries its colour as a dot over the card preview (cream ring). A closet card always has one
   -- (hidden on the base colour): its face changes with the colour worn.
   if variant or family then
    local chipSize=if side>=60 then 14 else 12
    local colour=Kit.frame(swatch,"VariantDot",nil,UDim2.new(1,-chipSize-3,1,-chipSize-3),UDim2.fromOffset(chipSize,chipSize),999)
    colour.BackgroundTransparency=0;colour.BackgroundColor3=variant or Color3.new(1,1,1);colour.ZIndex=swatch.ZIndex+3;colour.Visible=variant~=nil
    Kit.node("UIStroke",colour,{Name="VariantRing",Thickness=1.5,Color=Kit.Sticker.cream,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
    tile:SetAttribute("Variant",variant~=nil);tile:SetAttribute("VariantColor",if variant then variant:ToHex()else nil)
    variantDot=colour
   end
  end
  local tx=10+side+12
  local nameLabel=txt(tile,"Name",item.name,"text",tx,tileH/2-20,tileW-tx-8,20,{TextSize=14,TextTruncate=Enum.TextTruncate.AtEnd})
  local status=txt(tile,"Counter","","soft",tx,tileH/2+2,tileW-tx-8,18,{TextSize=13})
  self.tiles[index]={id=item.id,button=tile,status=status,name=nameLabel,stroke=stroke,swatch=swatch,role=item.role,slot=item.slot,primary=item.primary,none=item.none,
   variantColor=Shop.variantColor(item),family=family,dot=variantDot}
  if family then tile:SetAttribute("Family",family)end
  -- Levels matter (S2): the requirement chip where the price stands (hidden while locked) and the
  -- small lock, made only for a gated item while gates are on.
  if Locked.on()and item.gate~=nil then
   local entry=self.tiles[index]
   entry.lock=Locked.mark(swatch,if side>=60 then 22 else 16)
   entry.chip=Locked.chip(tile,20)
   entry.chip.root.Position=UDim2.fromOffset(tx,math.floor(tileH/2)+2);entry.chipRoom=tileW-tx-8
  end
  tile.Activated:Connect(function()if self.index==index then self:act()else self:focus(index);Kit.boing(tile)end end)
 end
 if #self.tiles==0 then txt(holder,"Body",UICopy.get("wardrobe.emptySlot"),"soft",x0,y0,300,24)end
end

-- The slot tabs: Kit.tabs, inside a sideways ScrollingFrame when the labels need more
-- room than the bar has (slice B: up to ten tabs on a phone).
function Shop:buildTabs(parent,labels,x,y,width,height,textSize)
 local plan=Shop.tabStrip(labels,width,textSize,Kit.translating==true)
 self.tabStripFrame=nil
 if plan.scroll then
  -- 44 px tall hits and a thin bar under the 36 / 44 px track.
  local top=math.max(0,(44-height)/2)
  local strip=Kit.node("ScrollingFrame",parent,{Name="TabStrip",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(x,y-top),
   Size=UDim2.fromOffset(width,height+top+6),CanvasSize=UDim2.fromOffset(plan.track,0),ScrollBarThickness=3,ZIndex=parent.ZIndex+1,Selectable=false,
   ScrollingDirection=Enum.ScrollingDirection.X,ScrollBarImageColor3=Color3.new(1,1,1),ScrollBarImageTransparency=.6})
  self.tabStripFrame=strip
  self.tabs=Kit.tabs(strip,labels,plan.track,height,textSize);self.tabs.root.Position=UDim2.fromOffset(0,top)
 else
  self.tabs=Kit.tabs(parent,labels,width,height,textSize);self.tabs.root.Position=UDim2.fromOffset(x,y)
 end
 self.tabPlan=plan
 self.root:SetAttribute("TabsScroll",plan.scroll);self.root:SetAttribute("TabCount",#labels)
end
-- Keep the front tab in view on a scrolling strip.
function Shop:revealTab(index)
 local strip=self.tabStripFrame;if not strip or not self.tabPlan then return end
 local view=strip.AbsoluteWindowSize.X;if view<=0 then view=strip.Size.X.Offset end
 strip.CanvasPosition=Vector2.new(Shop.tabReveal(index,self.tabPlan,view,strip.CanvasPosition.X),0)
end
function Shop:build(view)
 self:detachPreviews()
 if self.content then self.content:Destroy()end
 if self.ring then self.ring.hide();self.ring.root:Destroy();self.ring=nil end
 self.view=view;self.key=Shop.viewKey(view);self.tileRoot=nil;self.legend=nil
 local root=self.root;local phone=view~=nil
 root.BackgroundTransparency=if phone then 1 else 0;self.gradient.Visible=not phone;self.rootStroke.Enabled=not phone;root.ClipsDescendants=not phone
 Kit.setShadeAlpha(self.shade,if phone then 1 else Kit.ShadeAlpha)
 local content=Kit.frame(root,"Content",nil,UDim2.new(),if phone then UDim2.fromOffset(view.W,view.H)else UDim2.fromOffset(848,608));content.ZIndex=root.ZIndex+2
 self.content=content
 -- Slice B: the tabs this pet has items for; the front tab stays on its slot when it can.
 local frontId=self.tabList and self.tabList[self.tab]and self.tabList[self.tab].id
 self.levelsKey=Levels.key()
 self.closetKey=self:closet()
 self.tabList=Shop.tabsFor(self.petId,self:owned(),self.ctx.thisWeek,self:closet());self.tabKey=Shop.tabKey(self.tabList)
 self.tab=1;for i,tab in ipairs(self.tabList)do if tab.id==frontId then self.tab=i end end
 local labels={};for _,tab in ipairs(self.tabList)do table.insert(labels,Shop.tabLabel(tab))end
 if phone then
  local W,H=view.W,view.H;local g=Shop.compactGrid(W,H);self.columns=g.cols;self.grid=g
  local sheet=Kit.sheet(content,W,H)
  local body=Kit.frame(content,"Body",nil,UDim2.new(),UDim2.fromScale(1,1));body.ZIndex=sheet.ZIndex+3;self.body=body
  -- Shared header (redesign 0.1): title, Stars capsule and back circle, 36 drawn.
  self.header=Kit.header(body,{title="Wardrobe",tint="companions",compact=true,width=W,left=view.hx,onBack=function()self:back()end})
  self.title,self.wallet,self.backArrow=self.header.title,self.header.wallet,self.header.back
  -- QA v760: no stitched seam on a phone preview pane (the preview well sat on top of it, so it read as an occluded inner border)
  local pane=Kit.card(body,"Preview",nil,{pad=12,seam=false});pane.Position=UDim2.fromOffset(W-20-g.pw,64);pane.Size=UDim2.fromOffset(g.pw,g.paneH)
  self:buildPane(pane,g.pw,g.paneH,true)
  self:buildTabs(body,labels,20,64,g.gw,36,if g.gw<400 then 12 else 14)
  local list=Kit.node("ScrollingFrame",body,{Name="Grid",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(20,112),
   Size=UDim2.fromOffset(g.gw,g.gridH),ScrollBarThickness=4,ZIndex=body.ZIndex+1,Selectable=false,ScrollingDirection=Enum.ScrollingDirection.Y,
   ScrollBarImageColor3=Color3.new(1,1,1),ScrollBarImageTransparency=.6})
  self.list=list
 else
  self.columns=2;self.grid=nil;self.body=content;self.legend=nil
  self.header=Kit.header(content,{title="Wardrobe",eyebrow="Companions",tint="companions",width=848,onBack=function()self:back()end})
  Kit.halftone(content,"companions",false)
  self.title,self.wallet,self.backArrow=self.header.title,self.header.wallet,self.header.back
  self:buildTabs(content,labels,24,84,800,44,16)
  local pane=Kit.card(content,"Preview",nil,{pad=16,seam=true});pane.Position=UDim2.fromOffset(24,144);pane.Size=UDim2.fromOffset(328,404)
  self:buildPane(pane,328,404,false)
  local list=Kit.node("ScrollingFrame",content,{Name="Grid",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(368,144),
   Size=UDim2.fromOffset(456,404),ScrollBarThickness=4,ZIndex=content.ZIndex+1,Selectable=false,ScrollingDirection=Enum.ScrollingDirection.Y,
   ScrollBarImageColor3=Color3.new(1,1,1),ScrollBarImageTransparency=.6})
  self.list=list
  -- QA v2 R2.5: footer chips per device (R2's HintGlyphs), explained once (HintLegend).
  local footer=Kit.frame(content,"Footer",nil,UDim2.fromOffset(24,566),UDim2.fromOffset(800,24))
  local promise=txt(footer,"Small",if self:closet()then Shop.closetCopy("promise")else "Fixed prices. No random items.","dim",500,0,300,24,{Name="Promise",TextXAlignment=Enum.TextXAlignment.Right})
  local legend=HintLegend.attach(footer,800,"wardrobe",{{"browse",UICopy.get("input.action.browse")},{"tab",UICopy.get("r4.wardrobe.slot")},
   {"confirm",UICopy.get("r4.wardrobe.buyOrWear")},{"back",UICopy.get("input.action.back")}})
  self.legend=legend
  local function sync()promise.Visible=footer:GetAttribute("HintLegend")~=true end
  footer:GetAttributeChangedSignal("HintLegend"):Connect(sync);sync()
 end
 TabInk.guard(self.tabs) -- R3.6: labels keep their ink across theme repaints
 self.tabs.changed=function(index)self:setTab(index)end
 self.tabs.select(self.tab);self:revealTab(self.tab)
 self.ring=Kit.focusRing(self.root)
 self:layoutTiles()
end

function Shop:layoutTiles()
 local list=self.list
 if self.view then
  local g=self.grid
  -- 3 px in from the scroll edges: the selected tile's outline was clipped (QA 2026-11-12).
  self:buildTiles(list,3,3,g.tileW-6,64,8,g.cols)
  list.CanvasSize=UDim2.fromOffset(0,math.max(0,math.ceil(#self.tiles/g.cols)*72-8+6))
 else
  self:buildTiles(list,3,3,217,96,12,2)
  list.CanvasSize=UDim2.fromOffset(0,math.max(0,math.ceil(#self.tiles/2)*108-12+6))
 end
 list.CanvasPosition=Vector2.zero
 self:placeEmptyLine()
end
-- T12: this pet owns no wearables yet: one line in voice under the cards, only where
-- the grid has room below them (no layout change; the pane already shows the pet).
function Shop.ownsNothing(row)return not(row and type(row.owned)=="table"and #row.owned>0)end
function Shop.emptyText(petId)
 local pet=Pets.byId[petId]
 return if pet then UICopy.get("wardrobe.empty",{pet=pet.name})else UICopy.get("wardrobe.emptySolo")
end
function Shop:placeEmptyLine()
 self.emptyLine=nil
 local list=self.list
 if not list or not self.tileRoot or #self.tiles==0 then return end
 local last=self.tiles[#self.tiles].button
 local y=last.Position.Y.Offset+last.Size.Y.Offset+12
 if y+22>list.Size.Y.Offset then return end
 self.emptyLine=txt(self.tileRoot,"Body",Shop.emptyText(self.petId),"soft",3,y,list.Size.X.Offset-6,22,
  {Name="EmptyLine",TextSize=if self.view then 12 else 14,TextTruncate=Enum.TextTruncate.AtEnd})
 self.emptyLine.Visible=Shop.ownsNothing(self.ctx.row)
end

function Shop:fit(size)
 if Kit.compactRule(size.X,size.Y)then
  -- QA 2026-11-12: the sheet starts under the Roblox controls, so it has no keep-out.
  local _,kh=Kit.keepOut();local top=kh+2
  local view={phone=true,W=math.floor(size.X),H=math.floor(size.Y)-top,kx=0,kh=0,hx=24}
  self.root.AnchorPoint=Vector2.zero;self.root.Position=UDim2.fromOffset(0,top);self.root.Size=UDim2.fromOffset(view.W,view.H);self.scale.Scale=1
  if self.key~=Shop.viewKey(view)then self:build(view);self:relayout()end
  return
 end
 if self.view then self.root.Size=UDim2.fromOffset(848,608);self:build(nil);self:relayout()end
 self.root.AnchorPoint=Vector2.new(.5,.5);self.root.Position=UDim2.fromScale(.5,.5)
 self.scale.Scale=math.min(1.2,(size.X-24)/848,(size.Y-24)/608)
end
function Shop:relayout()
 self.wallet.set(self.ctx.wallet);self.index=math.clamp(self.index,1,math.max(1,#self.tiles))
 self:refresh();if self.visible then self:focus(self.index,true)end
end

-- Pure (QA Q2.4): the equipped map after wearing (wear = item id) or taking off
-- (wear = false) one item, as the server's equipWearable saves it.
-- `slot` names the slot a take-off empties (the None card has no item of its own).
function Shop.applyEquip(petId,equipped,itemId,wear,slot)
 if wear then return Shop.previewWearables(petId,equipped,itemId)end
 local result=table.clone(equipped or {})
 local item=Shop.item(petId,itemId)
 slot=slot or(item and item.slot)
 if not slot then return result end
 for _,key in ipairs(Catalog.slotKeys(petId,slot))do result[key]=nil end
 return result
end
-- Code review: the look shown is the last server-confirmed look (`self.confirmed`)
-- with every equip still in flight (`self.equips`, oldest first) replayed on top, so a
-- refusal only ever undoes its own change and never a save that already succeeded.
function Shop.replayEquips(petId,confirmed,equips)
 local result=table.clone(confirmed or {})
 for _,order in ipairs(equips or {})do if order.petId==petId then result=Shop.applyEquip(petId,result,order.itemId,order.wear,order.slot)end end
 return result
end
-- Every equip not answered yet, oldest first: those sent, then the swatch row's queued tap (last tap wins).
function Shop:openEquips()
 local list=table.clone(self.equips or {})
 local queued=self.swatchQueue and self.swatchQueue.queued
 if queued then table.insert(list,queued)end
 return list
end
-- Pure: would wearing `order` change the confirmed look? (A queued tap that changes nothing is never sent.)
function Shop.changes(petId,confirmed,order)
 local after=Shop.applyEquip(petId,confirmed,order.itemId,order.wear,order.slot)
 for k,v in pairs(after)do if(confirmed or {})[k]~=v then return true end end
 for k,v in pairs(confirmed or {})do if after[k]~=v then return true end end
 return false
end
-- The closet's equips (a swatch, the Wear button, the None card): one in flight, the last tap waiting behind it.
function Shop:queueEquip(itemId,wear,slot)
 if not self.petId or(self.pending and self.pending.action~="wearableEquip")then return false end
 self.equips=self.equips or {}
 self.swatchQueue=self.swatchQueue or Swatches.new()
 if #self.equips==0 and not self.swatchQueue:busy()then self.confirmed=table.clone(self.ctx.row.equipped or {})end
 local order={id=game:GetService("HttpService"):GenerateGUID(false),action="wearableEquip",petId=self.petId,slot=slot,itemId=itemId,wear=wear}
 local send=self.swatchQueue:tap(order)
 if send then
  self.pending=send;table.insert(self.equips,send)
  if self.callbacks.equip then self.callbacks.equip(send)end
 end
 self.ctx.row={owned=self.ctx.row.owned,equipped=Shop.replayEquips(self.petId,self.confirmed,self:openEquips())}
 self.errorId,self.errorText=nil,nil
 require(script.Parent.UIClick).play(if wear then "equip"else "unequip")
 self:refresh();return true
end
-- A swatch tap: wear that owned colour.
function Shop:wearSwatch(itemId)
 local item=self.petId and Shop.item(self.petId,itemId)
 if not item or not table.find(self.ctx.row.owned or {},itemId)then return false end
 if self.legend then self.legend.dismiss()end
 if Catalog.equippedIn(self.petId,self.ctx.row.equipped,item.slot)==itemId then return false end
 return self:queueEquip(itemId,itemId,item.slot)
end
-- Gamepad X / keyboard C: the next owned colour of the focused card (wraps).
function Shop:cycleSwatch(delta)
 local id=self:focusedId();local item=id and id~=Shop.NoneId and Shop.item(self.petId,id)
 local list=item and self:closet()and Catalog.swatchRow(self.petId,item.id,self:owned())
 if not list then return false end
 local at=1;for i,row in ipairs(list)do if row.id==item.id then at=i end end
 return self:wearSwatch(list[(at-1+(delta or 1))%#list+1].id)
end
function Shop:setContext(ctx)
 if ctx.wallet then self.ctx.wallet=ctx.wallet end
 if ctx.row then
  -- The server's word; an optimistic equip in flight stays on until its own result says otherwise.
  self.confirmed=table.clone(ctx.row.equipped or {})
  self.ctx.row={owned=ctx.row.owned,equipped=Shop.replayEquips(self.petId,self.confirmed,self:openEquips())}
 end
 -- The closet (DailyRack "rack"): nil keeps what the shop had.
 if ctx.closet~=nil then self.ctx.closet=ctx.closet==true end
 if ctx.stages then self.ctx.stages=ctx.stages end
 -- Levels matter: the pets' levels (the owner snapshot's) for the requirement chips.
 self.ctx.levels=if Locked.on()then ctx.levels or Locked.levels()else nil
 -- Slice C: the shelf week (the snapshot's own day; ShelfDeal.week reads the owner snapshot).
 if ctx.week~=nil then self.ctx.week=ctx.week else self.ctx.week=Deal.week()or self.ctx.week end
 -- This week: the server's week (false = none, as a spec passes week=false); never the device clock (review B37).
 if ctx.thisWeek~=nil then self.ctx.thisWeek=ctx.thisWeek
 elseif ctx.week==false then self.ctx.thisWeek=false
 else self.ctx.thisWeek=Deal.thisWeek()or false end
 if self.wallet then self.wallet.set(self.ctx.wallet)end
 -- The runtime switch flipped while the shop is open: list, chips and tabs again.
 if self.visible and(self.levelsKey~=Levels.key()or self.closetKey~=self:closet())then self:build(self.view);self:relayout();return end
 if self.visible then self:refresh()end
end

function Shop:focusedId()local tile=self.tiles[self.index];return tile and tile.id end

-- Card previews (QA Q2.3).
-- The card's own colour tile (the pet's palette colour for tinted items).
function Shop:swatchColor(tile)
 if tile.variantColor then return tile.variantColor end
 if tile.role then
  local palette=Palette.resolve(self.petId,self.callbacks.appearance and self.callbacks.appearance(self.petId)or nil)
  if palette and typeof(palette[tile.role])=="Color3"then return palette[tile.role]end
 end
 return if tile.primary then Color3.fromHex(tile.primary)else Kit.Color.soft
end
-- One card loses its preview (scrolled off, rebuilt or closed); the entry stays cached.
function Shop:detachPreview(tile)
 local entry=tile.preview
 if not entry then return end
 entry.viewport.Parent=nil;entry.shownAt=os.clock();tile.preview=nil
 if tile.swatch.Parent then tile.swatch:SetAttribute("Preview",nil);tile.swatch.BackgroundColor3=self:swatchColor(tile)end
end
function Shop:detachPreviews()
 for _,tile in ipairs(self.tiles or {})do self:detachPreview(tile)end
end
local function destroyEntry(entry)
 if entry.visual and not entry.visual.destroyed then entry.visual:destroy()end
 entry.viewport:Destroy()
end
-- Destroy the least recently shown detached preview; false when every one is on a card.
function Shop:evictPreview()
 local oldestKey,oldest=nil,nil
 for key,entry in pairs(self.previews or {})do
  if entry and entry.viewport.Parent==nil and(oldest==nil or(entry.shownAt or 0)<(oldest.shownAt or 0))then oldestKey,oldest=key,entry end
 end
 if not oldest then return false end
 destroyEntry(oldest);self.previews[oldestKey]=nil;self.previewCount-=1
 return true
end
function Shop:clearPreviews()
 self:detachPreviews()
 for _,entry in pairs(self.previews or {})do if entry then destroyEntry(entry)end end
 self.previews,self.previewCount={},0
end
-- Previews currently on cards (each one a rendering ViewportFrame).
function Shop:livePreviews()
 local live=0
 for _,tile in ipairs(self.tiles or {})do if tile.preview then live+=1 end end
 return live
end
function Shop:poseCard(entry)
 local v=entry.visual;if not v or v.destroyed then return end
 v.yaw=Shop.slotYaw(entry.slot,-.35)
 v.reducedEffects=true;v.poseDirty=true;v:update(0)
 entry.rig=v.rigRevision
 local box,size=Bounds.get(v)
 local focus,zoom=Shop.cardFraming(entry.slot)
 local half=math.tan(math.rad(entry.camera.FieldOfView/2))
 local distance=(math.max(size.Y,size.X)*.5/half+size.Z*.5+.3)*zoom
 local center=box.Position+(if focus=="head"then Vector3.new(0,size.Y*.22,0)elseif focus=="body"then Vector3.new(0,-size.Y*.04,0)else Vector3.zero)
 entry.camera.CFrame=CFrame.lookAt(center+Vector3.new(0,.1,distance),center)
end
function Shop:buildCardPreview(tile)
 local pet=Pets.byId[self.petId];if not pet then return false end
 local appearance=table.clone(self.callbacks.appearance and self.callbacks.appearance(self.petId)or {})
 appearance.wearables=Shop.previewWearables(self.petId,{},tile.id)
 local viewport=Instance.new("ViewportFrame");viewport.Name="CardPreview";viewport.BackgroundTransparency=1;viewport.Size=UDim2.fromScale(1,1)
 Kit.petLight(viewport)
 local world=Instance.new("WorldModel");world.Parent=viewport
 local camera=Instance.new("Camera");camera.FieldOfView=30;camera.Parent=viewport;viewport.CurrentCamera=camera
 local ok,visual=pcall(Factory.new,world,Vector3.zero,pet,nil,appearance)
 if not ok or not visual then viewport:Destroy();return false end
 local entry={viewport=viewport,camera=camera,visual=visual,slot=tile.slot}
 local posed=pcall(self.poseCard,self,entry)
 if not posed then visual:destroy();viewport:Destroy();return false end
 return entry
end
-- Runs every frame while open: detaches previews from cards scrolled off screen,
-- attaches cached previews to visible cards, builds at most one missing one, and refits
-- a card whose rig finished loading after it was built.
function Shop:pumpPreviews()
 if not self.visible or not self.list or not self.tiles then return end
 self.previews=self.previews or {};self.previewCount=self.previewCount or 0
 local windowY=self.list.AbsolutePosition.Y;local windowH=self.list.AbsoluteWindowSize.Y
 if windowH<=0 then windowH=self.list.AbsoluteSize.Y end
 local now=os.clock()
 local visible={}
 local live=0
 for index,tile in ipairs(self.tiles)do
  visible[index]=tile.button.Parent~=nil and Shop.cardVisible(tile.button.AbsolutePosition.Y,tile.button.AbsoluteSize.Y,windowY,windowH)
  if tile.preview then
   if not visible[index]then self:detachPreview(tile)
   else
    live+=1;tile.preview.shownAt=now
    local v=tile.preview.visual
    if v and not v.destroyed and v.rigRevision~=tile.preview.rig then self:poseCard(tile.preview)end
   end
  end
 end
 local built=false
 for index,tile in ipairs(self.tiles)do
  if live>=Shop.CardPreviewLive then break end
  if tile.preview==nil and visible[index]and not tile.none then
   local palette=tile.role and Palette.resolve(self.petId,self.callbacks.appearance and self.callbacks.appearance(self.petId)or nil)
   local tint=if palette and typeof(palette[tile.role])=="Color3"then palette[tile.role]else nil
   local key=Shop.cardKey(self.petId,tile.id,tint)
   local entry=self.previews[key]
   if entry==nil then
    if built then continue end
    while self.previewCount>=Shop.CardPreviewCache and self:evictPreview()do end
    if self.previewCount>=Shop.CardPreviewCache then continue end
    built=true
    entry=self:buildCardPreview(tile);self.previews[key]=entry
    if entry then self.previewCount+=1 end
   end
   if entry then
    entry.viewport.ZIndex=tile.swatch.ZIndex+1;entry.viewport.Parent=tile.swatch;entry.shownAt=now
    tile.preview=entry;tile.swatch.BackgroundColor3=Kit.color("well")
    tile.swatch:SetAttribute("Preview",true);live+=1
   else tile.preview=false end
  end
 end
end
-- A closet card's face follows the colour worn (a swatch tap, a refusal rolled back): name, colour dot and preview.
function Shop:repaintFace(tile)
 if not tile.family then return end
 local face=self:faceOf(tile)
 if face==tile.id then return end
 local item=Shop.item(self.petId,face);if not item then return end
 tile.id=face;tile.variantColor=Shop.variantColor(item)
 tile.name.Text=item.name
 tile.button:SetAttribute("AccessibleLabel",item.name);tile.button:SetAttribute("ItemId",item.id)
 tile.button:SetAttribute("Variant",tile.variantColor~=nil);tile.button:SetAttribute("VariantColor",if tile.variantColor then tile.variantColor:ToHex()else nil)
 if tile.dot then tile.dot.Visible=tile.variantColor~=nil;if tile.variantColor then tile.dot.BackgroundColor3=tile.variantColor end end
 self:detachPreview(tile)
 tile.swatch.BackgroundColor3=self:swatchColor(tile)
end
function Shop:refresh()
 if self.emptyLine then self.emptyLine.Visible=Shop.ownsNothing(self.ctx.row)end
 for _,tile in ipairs(self.tiles or {})do self:repaintFace(tile)end
 -- Tinted items show this pet's own palette colour (its secondary, face...), not grey.
 local palette=Palette.resolve(self.petId,self.callbacks.appearance and self.callbacks.appearance(self.petId)or nil)
 for index,tile in ipairs(self.tiles)do
  if tile.role and not tile.variantColor and palette and typeof(palette[tile.role])=="Color3"and not tile.preview then tile.swatch.BackgroundColor3=palette[tile.role]end
  local text,role=Shop.tileStatus(self.petId,tile.id,self.ctx,self:slot())
  if self.view and role=="dim"then role="soft"end
  Deal.setPrice(tile.status,text)
  tile.status.FontFace=if role=="accent"then Kit.Type.Label[3]else Kit.Type.Counter[3]
  Kit.paint(tile.status,"TextColor3",function()return colorOf(role,tile.status,"TextColor3")end)
  local focused=index==self.index
  Kit.paint(tile.button,"BackgroundColor3",function()return colorOf(if focused then "selected"else "raised",tile.button,"BackgroundColor3")end)
  tile.stroke.Thickness=if focused then 2 else 1;tile.stroke.Transparency=if focused then 0 else .86
  Kit.paint(tile.stroke,"Color",function()return Kit.color("ink")end) -- Toy Shell: the outline is always ink
  tile.button:SetAttribute("TileState",self:statusOf(tile.id).kind)
  if tile.chip then
   local owned=table.find(self.ctx.row.owned or {},tile.id)~=nil
   local item=Shop.item(self.petId,tile.id)
   local gate=Locked.info(item,self.ctx.levels,owned)
   tile.chip.set(gate,tile.chipRoom);tile.lock.set(gate~=nil and not gate.met)
   if item then tile.button:SetAttribute("AccessibleLabel",if gate and not gate.met then item.name..", "..gate.needs else item.name)end
  end
 end
 self:paintPane()
end

function Shop:paintPreview()
 local id=self:focusedId()
 local base=table.clone(self.callbacks.appearance and self.callbacks.appearance(self.petId)or {})
 if id==Shop.NoneId then base.wearables=Shop.applyEquip(self.petId,self.ctx.row.equipped,id,false,self:slot())
 else
  base.wearables=Shop.previewWearables(self.petId,self.ctx.row.equipped,if id and Shop.status(self.petId,id,self.ctx).kind~="equipped"then id else nil)
  if id and Shop.status(self.petId,id,self.ctx).kind=="equipped"then base.wearables=table.clone(self.ctx.row.equipped)end
 end
 base.appearanceGeneration=(base.appearanceGeneration or 0)
 if not self.visual or self.visualPet~=self.petId then
  if self.visual then self.visual:destroy()end
  self.visual=Factory.new(self.world,Vector3.zero,Pets.byId[self.petId],nil,base);self.visualPet=self.petId;self.cameraKey=nil
 end
 local slot=self:slot()
 -- The tail tab turns the pet round so the tail faces the viewer.
 self.visual.yaw=Shop.slotYaw(slot,-.25)
 self.visual.reducedEffects=GuiService.ReducedMotionEnabled
 if self.visual.applyAppearance then self.visual:applyAppearance(base)end
 self.visual.poseDirty=true;self.visual:update(0)
 self.root:SetAttribute("PreviewWearables",Shop.previewSignature(self.petId,base.wearables))
 self:fitCamera()
end
function Shop:fitCamera()
 local v=self.visual;if not v then return end
 local key=tostring(self.viewport.AbsoluteSize)..":"..tostring(v.rigRevision or 0)..":"..self.tab
 if self.cameraKey==key then return end;self.cameraKey=key
 local box,size=Bounds.get(v);local a=math.max(.1,self.viewport.AbsoluteSize.X/math.max(1,self.viewport.AbsoluteSize.Y));local half=math.tan(math.rad(self.camera.FieldOfView/2))
 local slot=self:slot()
 local zoom=if Shop.HeadSlots[slot]then .78 elseif slot=="Back"then Wings.Preview.pull else 1
 local distance=(math.max(size.Y*.5/half,size.X*.5/(half*a))+size.Z*.5+.3)*zoom
 local center=box.Position+(if zoom<1 then Vector3.new(0,size.Y*.18,0)else Vector3.zero)
 self.camera.CFrame=CFrame.lookAt(center+Vector3.new(0,.12,distance*1.10),center)
end

function Shop:paintPane()
 local id=self:focusedId()
 if not id then
  self.name.Text="";self.note.Text="";self.status.Text="";self.action.Visible=false;self.tier.root.Visible=false
  self:paintLock(nil)
  if self.deal then self.deal.set(false)end
  if self.weekChip then self.weekChip.root.Visible=false end
  self:paintSwatches(nil)
  if self.visible and self.petId then self:paintPreview()end;return
 end
 local item=Shop.item(self.petId,id)
 if id==Shop.NoneId or not item then
  self.tier.root.Visible=false;self.name.Text=UICopy.get("r4.wardrobe.none")
  self.note.Text=UICopy.get("r4.wardrobe.noneNote")
 else
  self.tier.root.Visible=true;self.name.Text=item.name
  local tier=TierChip[item.tier]or TierChip.common
  -- An Outfit Egg row shows its rarity instead (the shop's pills).
  if item.egg==true and RarityChip[item.rarity]then tier=RarityChip[item.rarity]end
  self.tier.set(tier[1],"sticker",tier[2]) -- T6: tier sticker, ink on the tier colour
  self.note.Text=Shop.note(self.petId,id,self.ctx.stages)
 end
 self:paintSwatches(if id~=Shop.NoneId then item else nil)
 local status=self:statusOf(id)
 if self.deal then self.deal.set(status.full~=nil,self.dealWidth)end
 -- This week: the chip on the pick in every state (bought or not) while it is this week's.
 if self.weekChip then
  local weekly=item~=nil and item.weekly==true and type(self.ctx.thisWeek)=="number"and ThisWeek.listed(id,self.ctx.thisWeek)
  self.weekChip.root.Visible=weekly
  self.root:SetAttribute("ThisWeek",weekly)
 end
 self.root:SetAttribute("ShelfPrice",if status.full then status.price else nil)
 local confirming=self.confirmId==id and os.clock()<self.confirmUntil
 local pending=self.pending and self.pending.itemId==id and self.pending.action=="wearableBuy"
 self.status.Text=if pending then "Saving…"elseif self.errorId==id and self.errorText then self.errorText else status.text
 if not pending and not(self.errorId==id and self.errorText)and status.fit then Kit.fitText(self.status,status.fit)end
 if not pending and self.errorId==id and self.errorFit then Kit.fitText(self.status,self.errorFit)end
 -- Levels matter: "Needs Jump 30 · 22/30" (the requirement alone when that is too long) and its bar.
 local gate=if status.kind=="locked"then status.gate else nil
 self:paintLock(gate)
 if gate and not(self.errorId==id and self.errorText)then Kit.fitText(self.status,{gate.line,gate.needs})end
 local tone=if status.kind=="equipped"and status.text==""then "accent"elseif status.kind=="short"or(self.errorId==id and self.errorText)then(if self.view then "dangerText"else "danger")else "soft"
 Kit.paint(self.status,"TextColor3",function()return colorOf(tone,self.status,"TextColor3")end)
 self.action.Visible=status.button~=nil
 if status.button then
  Kit.setText(self.action,if pending then "Saving…"elseif confirming then "Confirm ★ "..status.price else status.button)
  Kit.setEnabled(self.action,status.enabled==true and not(self.pending and self.pending.action=="wearableBuy")and(gate==nil or self.callbacks.train~=nil))
  Kit.setTappable(self.action,status.kind=="short"and not self.pending)
 end
 self.root:SetAttribute("FocusedItem",id);self.root:SetAttribute("PaneState",status.kind);self.root:SetAttribute("Tab",self:tabInfo().id)
 if self.visible then self:paintPreview()end
end

-- The bar between the requirement line and the button; made the first time a locked item is shown.
-- A short pane tightens the two lines over it, for a locked item only, and drops the note when even
-- that is not enough: the bar is always LockGap clear of the button.
Shop.LockBar,Shop.LockGap,Shop.LockLine=8,10,16
-- Pure: where the note and the requirement line stand. lines: their resting places; barTop: the bar's.
function Shop.lockLines(lines,barTop)
 if lines.status+lines.statusH<=barTop then return lines,true end
 local status=math.max(lines.note,math.min(lines.status,barTop-Shop.LockLine))
 local noteH=math.min(lines.noteH,status-lines.note)
 if noteH<Shop.LockLine then return{note=lines.note,noteH=lines.noteH,status=status,statusH=Shop.LockLine},false end
 return{note=lines.note,noteH=noteH,status=status,statusH=Shop.LockLine},true
end
function Shop:paintLock(gate)
 local lines,note=self.lines,true
 if gate then lines,note=Shop.lockLines(lines,self.action.Position.Y.Offset-Shop.LockGap-Shop.LockBar)end
 for label,at in pairs({[self.note]={lines.note,lines.noteH},[self.status]={lines.status,lines.statusH}})do
  label.Position=UDim2.fromOffset(label.Position.X.Offset,at[1]);label.Size=UDim2.fromOffset(label.Size.X.Offset,at[2])
 end
 self.note.Visible=note
 local size=if gate then 13 else 14
 if self.status.TextSize~=size then self.status.TextSize=size end
 if not gate and not self.lockBar then return end
 if not self.lockBar or not self.lockBar.root.Parent then
  if not gate then self.lockBar=nil;return end
  self.lockBar=Locked.bar(self.status.Parent,self.status.Position.X.Offset,self.action.Position.Y.Offset-Shop.LockGap-Shop.LockBar,self.status.Size.X.Offset,Shop.LockBar)
 end
 self.lockBar.set(gate)
end
-- Brings one item's card to the front (the reward guide's "Go to shop"). True when it is listed.
function Shop:showItem(itemId)
 local item=self.petId and Shop.item(self.petId,itemId)
 if not item then return false end
 for index,tab in ipairs(self.tabList)do
  if tab.slot==item.slot and(tab.thisWeek==nil or tab.thisWeek==itemId)then
   if index~=self.tab and self:setTab(index)==false then return false end
   for i,tile in ipairs(self.tiles)do if tile.id==itemId or(tile.family~=nil and tile.family==(item.base or item.id))then self:focus(i,true);return true end end
  end
 end
 return false
end

function Shop:scrollTo(index)
 local list=self.list;local tile=self.tiles[index];if not list or not tile then return end
 local top=tile.button.Position.Y.Offset;local bottom=top+tile.button.Size.Y.Offset
 local view=list.AbsoluteWindowSize.Y;if view<=0 then view=list.Size.Y.Offset end
 local y=list.CanvasPosition.Y
 if top-8<y then y=top-8 elseif bottom+8>y+view then y=bottom+8-view end
 list.CanvasPosition=Vector2.new(0,math.clamp(y,0,math.max(0,list.CanvasSize.Y.Offset-view)))
end
function Shop:focus(index,instant)
 if #self.tiles==0 then self.index=1;self.ring.hide();self:refresh();return end
 index=math.clamp(index,1,#self.tiles)
 if index~=self.index then self.confirmId=nil;self.errorId=nil end
 self.index=index;self:refresh();self:scrollTo(index)
 self.ring.attach(self.tiles[index].button,12)
 if instant then self.ring.root.Visible=self.visible and self.ring.root.Visible end
 if self.view then Kit.setGlyphVisible(self.action,not Kit.lastInputTouch())end
end
function Shop:move(dx,dy)
 if self.legend then self.legend.dismiss()end
 local nextIndex=Shop.step(self.index,dx,dy,#self.tiles,self.columns)
 if nextIndex==self.index then return false end
 self:focus(nextIndex);return true
end
function Shop:setTab(index)
 index=math.clamp(index,1,#self.tabList)
 if self.pending and self.pending.action=="wearableBuy"then self.tabs.select(self.tab);return false end
 self.tab=index;self.tabs.select(index);self:revealTab(index);self.confirmId=nil;self.errorId=nil;self.cameraKey=nil
 self:layoutTiles()
 -- Land on the item worn in this slot, else the first card.
 local worn=Catalog.equippedIn(self.petId,self.ctx.row.equipped,self.tabList[index].slot);local landing=1
 for i,tile in ipairs(self.tiles)do if tile.id==worn then landing=i end end
 self.index=landing;self:focus(landing,true);return true
end
function Shop:shiftTab(delta)
 if self.legend then self.legend.dismiss()end
 local index=math.clamp(self.tab+delta,1,#self.tabList)
 if index==self.tab then return false end;return self:setTab(index)
end

-- A / Enter / pane button. Buying needs one confirmation within 3 s.
function Shop:act()
 local id=self:focusedId();if not id then return false end
 -- An equip in flight never blocks the next choice; a buy does.
 if self.pending and self.pending.action~="wearableEquip"then return false end
 if self.legend then self.legend.dismiss()end
 local status=self:statusOf(id)
 local slot=self:slot()
 local opId=game:GetService("HttpService"):GenerateGUID(false)
 if status.kind=="owned"and self:closet()then
  return self:queueEquip(id,if id==Shop.NoneId then false else id,slot)
 elseif status.kind=="egg"then
  -- The closet: "From the Outfit Egg" opens Hatch eggs on the Outfit Egg (init.client's outfitEgg).
  if self.pending or not self.callbacks.outfitEgg then return false end
  return self.callbacks.outfitEgg(self.petId,id)~=false
 elseif status.kind=="owned"then
  -- QA Q2.4: optimistic. The pet wears it (or takes it off) at once; the save runs in
  -- the background and only a refusal puts the previous look back, with a toast.
  self.equips=self.equips or {}
  if #self.equips==0 or self.confirmed==nil then self.confirmed=table.clone(self.ctx.row.equipped or {})end
  -- The None card takes the slot off (wear=false); an owned item is worn.
  local wear=if id==Shop.NoneId then false else id
  self.pending={id=opId,action="wearableEquip",petId=self.petId,slot=slot,itemId=id,wear=wear}
  table.insert(self.equips,self.pending)
  self.ctx.row={owned=self.ctx.row.owned,equipped=Shop.replayEquips(self.petId,self.confirmed,self.equips)}
  self.errorId,self.errorText=nil,nil
  if self.callbacks.equip then self.callbacks.equip(self.pending)end
  require(script.Parent.UIClick).play(if wear then "equip"else "unequip") -- QA v775 note 10
  self:refresh();return true
 elseif status.kind=="buy"then
  if self.pending then return false end -- let an equip's save land first
  if self.confirmId==id and os.clock()<self.confirmUntil then
   self.confirmId=nil
   self.pending={id=opId,action="wearableBuy",petId=self.petId,itemId=id,price=status.price}
   if self.callbacks.buy then self.callbacks.buy(self.pending)end
   self:paintPane();return true
  end
  -- Round 3 (Spencer): a buy asks in the confirm dialog instead of "press again".
  return require(script.Parent.ConfirmDialog).purchase(self,id,(Shop.item(self.petId,id)or{name=""}).name or "",status.price,
   function()return self.visible and self:focusedId()==id end,function()self:act()end)~=nil
 elseif status.kind=="locked"then
  -- Levels matter: the button leads to where that stat is trained (the stats panel on it).
  if self.pending or not self.callbacks.train then return false end
  self.callbacks.train(Locked.route(status.gate))
  return true
 elseif status.kind=="short"then
  -- Stars store access: a short item opens the "need more Stars" card.
  if self.pending then return false end
  return require(script.Parent.StarsShort).ask({price=status.price,wallet=self.ctx.wallet,item=(Shop.item(self.petId,id)or{name=""}).name,from="wardrobe"},self)
 end
 return false
end

local Reasons={NeedStars="shop.reason.needStars",Busy="shop.reason.busy",Throttled="shop.reason.throttled",NotOwned="shop.reason.notOwned",
 NeedsLevel="shop.reason.needsLevel",PriceChanged="shop.reason.priceChanged",ShelfChanged="shop.reason.priceChanged",Retrying="shop.reason.retrying"}
function Shop:result(message)
 if type(message)~="table"then return false end
 -- Equips: any in-flight order (an earlier one superseded by a quicker second tap still
 -- reports, and its save counts).
 local index=nil
 for i,order in ipairs(self.equips or {})do if order.id==message.id then index=i end end
 if index then
  if message.status=="Retrying"then
   -- Code review (beta 45): Retrying is the server's last word on this equip (the save retries on its own), so the
   -- closet's queue lets go of it here; otherwise every later swatch tap waits behind it for the whole session.
   if self.swatchQueue then
    local nextOrder=self.swatchQueue:settle(message.id,function(o)return o.petId~=self.equips[index].petId or Shop.changes(o.petId,self.confirmed,o)end)
    if nextOrder then
     self.pending=nextOrder;table.insert(self.equips,nextOrder)
     if self.callbacks.equip then self.callbacks.equip(nextOrder)end
    end
   end
   return false
  end
  local order=table.remove(self.equips,index)
  local latest=index>#self.equips and not(self.swatchQueue and self.swatchQueue.queued) -- nothing newer was tapped after it
  if self.pending==order then self.pending=self.equips[#self.equips]end
  if message.status=="Saved"then
   if order.petId==self.petId then self.confirmed=Shop.applyEquip(order.petId,self.confirmed,order.itemId,order.wear,order.slot)end
   if latest then self.errorId,self.errorText=nil,nil end
  else
   -- Roll back this change only: the confirmed look with the newer equips still on top.
   self.errorId,self.errorText,self.errorFit=order.itemId,UICopy.get(Reasons[message.reason]or "shop.failed.applied"),nil
   if self.callbacks.rolledBack then self.callbacks.rolledBack(order)
   else self.toaster=self.toaster or Kit.toaster(self.host);self.toaster.show(UICopy.get("shop.rolledBack"))end
  end
  -- The closet's queue: the answer for the one in flight sends the last tap waiting behind it (if it changes anything).
  if self.swatchQueue then
   local nextOrder=self.swatchQueue:settle(order.id,function(o)return o.petId~=order.petId or Shop.changes(o.petId,self.confirmed,o)end)
   if nextOrder then
    self.pending=nextOrder;table.insert(self.equips,nextOrder)
    if self.callbacks.equip then self.callbacks.equip(nextOrder)end
   end
  end
  self.ctx.row={owned=self.ctx.row.owned,equipped=Shop.replayEquips(self.petId,self.confirmed,self:openEquips())}
  if self.visible then self:refresh()end;return true
 end
 if not self.pending or self.pending.action=="wearableEquip"or message.id~=self.pending.id then return false end
 if message.status=="Retrying"then return false end
 local order=self.pending;self.pending=nil
 if message.status~="Saved"then
  self.errorId,self.errorText,self.errorFit=order.itemId,if message.reason=="FromOutfitEgg"then Shop.closetCopy("reason")else UICopy.get(Reasons[message.reason]or "shop.failed.saved"),nil
  if message.reason=="NeedStars"then
   local item=Shop.item(order.petId or self.petId,order.itemId)
   local price=item and Deal.quote("wearable",order.itemId,item.price,self.ctx.week)
   self.errorFit=UICopy.starsShort(if price then price-(self.ctx.wallet or 0)else nil);self.errorText=self.errorFit[1]
  end
 else self.errorId,self.errorText=nil,nil;if self.callbacks.done then self.callbacks.done(order)end end
 self:refresh();return true
end

function Shop:isOpen()return self.visible end
function Shop:open(petId,ctx)
 -- Slice E: any pet with wearables; otherwise the first active pet that has some.
 self.petId=if petId and Catalog.hasItems(petId)then petId else Shop.firstPet()
 if not self.petId then return false end
 if ctx then self:setContext(ctx)end
 self.visible=true;self.root.Visible=true;self.confirmId,self.errorId=nil,nil
 Kit.shadeOpen(self,self.shade,function(covered)self.root.Visible=not covered end)
 -- Slice B: another pet can have other tabs; rebuild the bar when the set changes.
 if Shop.tabKey(Shop.tabsFor(self.petId,self:owned(),self.ctx.thisWeek,self:closet()))~=self.tabKey or self.levelsKey~=Levels.key()or self.closetKey~=self:closet()then self:build(self.view);self:relayout()end
 self:fit(self.host.AbsoluteSize)
 if self.visual and self.visualPet~=self.petId then self.visual:destroy();self.visual=nil end
 self:setTab(self.tab)
 -- QA Q2.2: in from the right like the Pets page (Reduced Motion cuts); Back is a cut
 -- to the screen underneath, which slides back in from the left.
 Kit.slideIn(self.body,Kit.SlideOffset,Kit.headerSkip(self.header))
 if self.legend then self.legend.open()end
 if self.clock then self.clock:Disconnect()end
 self.previewFeedback=self.previewFeedback or require(script.Parent.PreviewFeedback).new()
 self.clock=RunService.RenderStepped:Connect(function(dt)
  if self.visible then self:pumpPreviews();self:stepSwatches(os.clock())end
  local v=self.visual;if not self.visible or not v or v.destroyed then return end
  local idle=require(script.Parent.PreviewFeedback).pointerIdle()
  self.previewFeedback:step(os.clock(),self.root.Visible and idle and not GuiService.ReducedMotionEnabled and not GuiService.MenuIsOpen,v)
  if GuiService.ReducedMotionEnabled then return end
  v.cosmeticTime=os.clock();v:update(math.min(dt,.1))
 end)
 self.sizeConnection=self.sizeConnection or self.host:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()if self.visible then self:fit(self.host.AbsoluteSize)end end)
end
function Shop:back()if self.callbacks.back then self.callbacks.back()else self:close()end end
function Shop:close()
 if self.previewFeedback then self.previewFeedback:cancel()end
 self.visible=false;self.root.Visible=false;Kit.shadeClose(self);if self.ring then self.ring.hide()end;self.confirmId=nil;require(script.Parent.ConfirmDialog).cancelFor(self)
 if self.clock then self.clock:Disconnect();self.clock=nil end
 if self.visual then self.visual:destroy();self.visual=nil end
 self:clearPreviews()
end
function Shop:destroy()self:close();if self.sizeConnection then self.sizeConnection:Disconnect()end;self.root:Destroy();self.shade:Destroy()end
return Shop
