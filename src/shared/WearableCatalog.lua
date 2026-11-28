-- Pet wearables sold for Stars (manifest `items`, generated into each rig definition's
-- `wearableItems` by scripts/build_bear_attachments.py). Fixed prices, never random.
-- An item fills one slot key, or both sides of a per-side slot (a helix pair fills
-- EarPiercingL and EarPiercingR). The keys match PetAttachmentRules.
-- Recolour variants (WearableVariants, slice B) are their own item ids: they sell and save
-- like any item and render as their base item's meshes with one colour override (renderMap).
local Defs=require(script.Parent.PetRigDefinitions)
local Variants=require(script.Parent.WearableVariants)
local Levels=require(script.Parent.Levels)
-- OwnedLimit: every WRITE path refuses at 128 (ClosetFull / OwnedLimit). LoadLimit (ARCH-REVIEW-ROTATION-2 4): what
-- this build's load accepts, loosened now so a later build may raise the write cap one release after; builds before
-- this one still refuse a save over 128 on load, so the write cap stays 128 until this build is the rollback floor.
local Catalog={Version=1,OwnedLimit=128,LoadLimit=256}
-- Shop tabs in display order (UI: hat, shirt, neck, ears, eyes, mouth, tail, then slice B's
-- eyewear, cheek, wrist, ankle). Append-only: WearableState validates take-off against this
-- list. The shop shows only tabs that sell something for the pet (Catalog.tabsFor).
Catalog.Tabs=table.freeze({
 {id="hat",slot="Hat",label="Hat"},{id="shirt",slot="Shirt",label="Shirt"},{id="neck",slot="Neck",label="Neck"},
 {id="ears",slot="EarPiercing",label="Ears"},{id="eyes",slot="Eyes",label="Eyes"},{id="mouth",slot="Mouth",label="Mouth"},
 {id="tail",slot="Tail",label="Tail"},
 {id="eyewear",slot="Eyewear",label="Eyewear"},{id="cheek",slot="Cheek",label="Cheek"},
 {id="wrist",slot="Wrist",label="Wrist"},{id="ankle",slot="Ankle",label="Ankle"},
 -- Rotation slice 2 (ARCH-REVIEW-ROTATION-2 2): Angel Wings' slot. Shown only for a pet that owns a Back item.
 {id="back",slot="Back",label="Back"}})
Catalog.TierPrice=table.freeze({common=40,rare=100,showcase=250})
-- Recolour rows (WearableVariants), here so the localization export reads their names.
Catalog.Variants=Variants.Rows
Catalog.week=Variants.week
-- Egg-only BASE items (rotation slice 2, ARCH-REVIEW-ROTATION-2 1-3): an item of its own (not a recolour) that no rig
-- sells. compose lists one only under math.huge (render, equip, grant) and only for a rig whose definition carries its
-- attachment rows (PetRigDefinitions: the Bear's, which the Bunny inherits); it is never in `order` (so never one of the
-- daily picks, a Wardrobe card for sale, the Book's wardrobe page or the shelf), only in `eggBases` and `byId`. No
-- price: WearableState.check refuses it NotForSale; only the Outfit Egg's wings-day sparkle pick grants it.
-- Append-only; never rename or reuse an id.
Catalog.WingsId="angelwings"
Catalog.EggBases=table.freeze({
 table.freeze({id="angelwings",slot="Back",name="Angel Wings",tier="showcase",rarity="legendary",finish="sparkle",color="#F4F6FB"}),
})
local eggBaseById={};for _,row in ipairs(Catalog.EggBases)do eggBaseById[row.id]=row end
Catalog.EggBaseById=table.freeze(eggBaseById)

-- Items for one pet's rig from an explicit variant row list (uncached; forPet caches it).
-- Order: each rig item, then its variants in row order, so a slot tab lists a base with its
-- recolours right after it. A variant copies the base's slot, keys, flags, tier and main
-- colour data and adds variant=true, base=<id>, color=<hex>, piece=<attachment name or nil>,
-- gate=<LevelGate gate or nil>, weekly=<true on a "This week" row (ThisWeek), else nil>, and on an Outfit Egg row
-- (DailyRack) egg=true, rarity, finish?, finishHexes? (listed only under math.huge: never sold, always rendered).
-- `eggBases` (forPet passes it only under math.huge): Catalog.EggBases rows to add, each only when the rig has its
-- attachment rows. They land in `eggBases` and `byId`, never in `order`.
function Catalog.compose(petId,rows,eggBases)
 local definition=type(petId)=="string"and Defs[petId]
 local order,byId,extra={},{},{}
 if type(definition)=="table"and type(definition.wearableItems)=="table"then
  local slots=definition.slots or {}
  local bases={}
  for _,raw in ipairs(definition.wearableItems)do
   if type(raw.id)=="string"and type(raw.slot)=="string"and type(raw.price)=="number"and raw.price>0 and not bases[raw.id]then
    local perSide=slots[raw.slot]~=nil and slots[raw.slot].perSide==true
    bases[raw.id]=table.freeze({id=raw.id,slot=raw.slot,name=raw.name or raw.id,tier=raw.tier or "common",price=raw.price,
     flags=table.freeze(table.clone(raw.flags or {})),perSide=perSide,
     keys=table.freeze(if perSide then {raw.slot.."L",raw.slot.."R"}else {raw.slot}),
     primary=if type(raw.primary)=="string"and string.sub(raw.primary,1,4)=="own:"then string.sub(raw.primary,5)else nil,
     -- Tinted items name the pet palette role their main piece takes ("secondary", "face").
     role=if type(raw.primary)=="string"and string.sub(raw.primary,1,4)~="own:"then raw.primary else nil})
   end
  end
  local following={}
  for _,row in ipairs(rows or {})do
   local base=bases[row.base]
   if base then
    -- A variant id never collides with an item the rig sells.
    assert(bases[row.id]==nil,"WearableCatalog: variant id is a rig item: "..row.id)
    local list=following[row.base];if not list then list={};following[row.base]=list end
    table.insert(list,table.freeze({id=row.id,slot=base.slot,name=row.name,tier=base.tier,price=row.price or base.price,
     flags=base.flags,perSide=base.perSide,keys=base.keys,primary=base.primary,role=base.role,
     variant=true,base=base.id,color=row.color,piece=row.piece,gate=row.gate,weekly=row.weekly,
     egg=row.egg,rarity=row.rarity,finish=row.finish,finishHexes=row.finishHexes}))
   end
  end
  for _,raw in ipairs(definition.wearableItems)do
   local item=bases[raw.id]
   if item and not byId[item.id]then
    table.insert(order,item);byId[item.id]=item
    for _,variant in ipairs(following[item.id]or {})do
     if not byId[variant.id]then table.insert(order,variant);byId[variant.id]=variant end
    end
   end
  end
  for _,row in ipairs(eggBases or {})do
   local mounted=false
   for _,a in ipairs(type(definition.attachments)=="table"and definition.attachments or {})do if a.item==row.id then mounted=true;break end end
   if mounted and not byId[row.id]then
    local perSide=slots[row.slot]~=nil and slots[row.slot].perSide==true
    local item=table.freeze({id=row.id,slot=row.slot,name=row.name,tier=row.tier,price=nil,flags=table.freeze({}),perSide=perSide,
     keys=table.freeze(if perSide then {row.slot.."L",row.slot.."R"}else {row.slot}),primary=nil,role=nil,
     egg=true,eggBase=true,rarity=row.rarity,finish=row.finish,color=row.color})
    table.insert(extra,item);byId[item.id]=item
   end
  end
 end
 return table.freeze({order=table.freeze(order),byId=table.freeze(byId),eggBases=table.freeze(extra)})
end
local cache={}
local none=Catalog.compose(nil)
-- Items for one pet's rig: {order={item}, byId={id=item}}. Pets without authored wearables
-- get none. `week` (default: this week) gates variant rows that carry `from`; pass
-- math.huge for every row ever released (rendering a saved id never depends on the clock).
function Catalog.forPet(petId,week)
 if type(petId)~="string"then return none end
 local rows,weekly=Variants.rows(if type(week)=="number"then week else Variants.week())
 -- Rows only ever join as the week advances, so the count names the set (with the gated rows
 -- listed or not: Levels may differ between two calls in a spec). "This week" rows come and go, so
 -- the ones listed are named too.
 -- Egg-only bases join under math.huge only ("|e" names that set: ARCH-REVIEW-ROTATION-2 2).
 local huge=week==math.huge
 local key=petId.."|"..#rows..(if Levels.on("gates")then "|g"else "").."|"..weekly..(if huge then "|e"else "")
 local found=cache[key]
 if not found then found=Catalog.compose(petId,rows,if huge then Catalog.EggBases else nil);cache[key]=found end
 return found
end
-- The egg-only bases this pet's rig can wear (every one ever, math.huge), in EggBases order.
function Catalog.eggBases(petId)return Catalog.forPet(petId,math.huge).eggBases or {}end
function Catalog.item(petId,id)return Catalog.forPet(petId).byId[id]end
function Catalog.price(petId,id)local item=Catalog.item(petId,id);return item and item.price or nil end
function Catalog.hasItems(petId)return #Catalog.forPet(petId).order>0 end
-- Every slot key a slot covers (per-side slots cover both sides).
function Catalog.slotKeys(petId,slot)
 local definition=Defs[petId];local info=definition and definition.slots and definition.slots[slot]
 if info and info.perSide then return {slot.."L",slot.."R"}end
 return {slot}
end
-- QA v2 R4.1 (shot 194020): per-item fit lifts, in rig studs at garden size (scaled
-- with the pet), keyed by rig definition id. Measured in Blender against the Bear's
-- head mesh (pet-bear-attachments.blend): the sun hat's brim underside sat ~0.03
-- inside the crown and the beanie dome ~0.015; the flower crown wraps the brow by
-- design and stays put. Only Y is used today; X/Z are there for later rigs.
-- Keyed by base item id: a variant renders as its base, so it takes the same lift.
Catalog.Fit=table.freeze({
 -- v2 cute Bear (2026-11-21): the snout pad is narrower, so at the mouth its surface sits a
 -- little further back (pet-bear-v2-cute.blend: the W mean gap 0.010 -> 0.016, Blep 0.0015 ->
 -- 0.005). Blep and Kitty W step back onto it (Z is the front); deepest stays as live.
 bear=table.freeze({sunhat=Vector3.new(0,.03,0),beanie=Vector3.new(0,.015,0),blep=Vector3.new(0,0,-.003),w=Vector3.new(0,0,-.005)}),
 -- v2 Bunny: same crown (HatCrown unmoved, head within 0.01 of the Bear's: bunny-report.json),
 -- so the same lifts. Its moved face and ear anchors are carried by PetAttachments.anchorFit.
 bunny=table.freeze({sunhat=Vector3.new(0,.03,0),beanie=Vector3.new(0,.015,0)}),
})
function Catalog.fitOffset(rigId,itemId)
 local rig=type(rigId)=="string"and Catalog.Fit[rigId]
 local offset=rig and type(itemId)=="string"and rig[itemId]
 return if typeof(offset)=="Vector3"then offset else Vector3.zero
end
function Catalog.inTab(petId,tabSlot)
 local result={};for _,item in ipairs(Catalog.forPet(petId).order)do if item.slot==tabSlot then table.insert(result,item)end end
 return result
end
-- The same list plus gated items the pet owns while gates are off (they are not sold then, but
-- stay wearable and removable). "This week" items show here only once owned (ThisWeek: bought stays
-- owned, in any week); unowned, the pick is sold from the Wardrobe's This week tab alone, by the
-- server's week, never by this clock's list (review B37). With gates on and no weekly item listed or
-- owned, or nothing gated or weekly owned, it is exactly inTab.
-- Outfit Egg rows (DailyRack) are kept the same way: never sold here, listed in their slot tab once owned.
local function ownsWeekly(owned)
 for _,id in ipairs(owned)do if Variants.ById[id]and(Variants.ById[id].weekly or Variants.ById[id].egg)then return true end end
 return false
end
local function listsWeekly(petId)
 for _,item in ipairs(Catalog.forPet(petId).order)do if item.weekly then return true end end
 return false
end
-- An owned egg-only base (Angel Wings) is kept the same way, after the slot's rig items.
local function ownsEggBase(petId,owned)
 for _,item in ipairs(Catalog.eggBases(petId))do if table.find(owned,item.id)then return true end end
 return false
end
function Catalog.shopTab(petId,tabSlot,owned)
 local gates=Levels.on("gates")
 if type(owned)~="table"then owned={}end
 if gates and not ownsWeekly(owned)and not listsWeekly(petId)and not ownsEggBase(petId,owned)then return Catalog.inTab(petId,tabSlot)end
 local listed=Catalog.forPet(petId).byId
 local result={}
 for _,item in ipairs(Catalog.forPet(petId,math.huge).order)do
  local mine=table.find(owned,item.id)~=nil
  local sold=listed[item.id]~=nil and item.weekly~=true
  local kept=((item.gate~=nil and not gates)or item.weekly==true or item.egg==true)and mine
  if item.slot==tabSlot and(sold or kept)then table.insert(result,listed[item.id]or item)end
 end
 for _,item in ipairs(Catalog.eggBases(petId))do
  if item.slot==tabSlot and table.find(owned,item.id)then table.insert(result,item)end
 end
 return result
end
-- Closet mode (DailyRack "rack" on; ROTATION-BRIEF 1 "Wardrobe with the switch on", Spencer: "move clothes to eggs").
-- Clothes come from the Outfit Egg: the Wardrobe sells only a level-gated row (an earned goal stays earned) and the
-- "This week" pick (unchanged). Everything else is "From the Outfit Egg"; whatever the pet owns stays owned and
-- wearable. Pure: the server's refusal (WearableState.check, FromOutfitEgg) and the Wardrobe read the same rule.
function Catalog.closetSells(item)
 return type(item)=="table"and item.egg~=true and(item.gate~=nil or item.weekly==true)
end
-- Every colour of one base item for this pet (the base, then its rows in data order), every row ever (math.huge).
-- An egg-only base is a family of one (no colours: ROTATION-2-BRIEF 3).
function Catalog.family(petId,baseId)
 local result={}
 for _,item in ipairs(Catalog.forPet(petId,math.huge).order)do
  if item.id==baseId or item.base==baseId then table.insert(result,item)end
 end
 if #result==0 then
  local egg=Catalog.forPet(petId,math.huge).byId[baseId]
  if egg and egg.eggBase then table.insert(result,egg)end
 end
 return result
end
-- The colour selector (ROTATION-BRIEF 2): the colours of `itemId`'s base the pet owns, in family order. Unowned colours
-- are never drawn (no wall of things you lack). A row shows only with two or more (Catalog.swatchRow).
function Catalog.swatches(petId,itemId,owned)
 local item=type(petId)=="string"and Catalog.forPet(petId,math.huge).byId[itemId]
 if not item then return {}end
 local mine={};for _,id in ipairs(type(owned)=="table"and owned or {})do mine[id]=true end
 local result={}
 for _,row in ipairs(Catalog.family(petId,item.base or item.id))do if mine[row.id]then table.insert(result,row)end end
 return result
end
function Catalog.swatchRow(petId,itemId,owned)
 local list=Catalog.swatches(petId,itemId,owned)
 return if #list>=2 then list else nil
end
-- A closet card's face: the family's colour worn in its slot, else the base when owned, else the first owned colour,
-- else the base itself (unowned: "From the Outfit Egg").
function Catalog.closetFace(petId,baseId,owned,equipped)
 local base=type(petId)=="string"and Catalog.forPet(petId,math.huge).byId[baseId]
 if not base then return baseId end
 local list=Catalog.swatches(petId,baseId,owned)
 local worn=Catalog.equippedIn(petId,equipped,base.slot)
 for _,row in ipairs(list)do if row.id==worn then return worn end end
 for _,row in ipairs(list)do if row.id==base.id then return base.id end end
 return if list[1]then list[1].id else base.id
end
-- The closet's slot tab: one card per base item (its face is Catalog.closetFace; its owned colours are the swatches),
-- plus each level-gated row the shop lists now that the pet does not own yet (it is still sold: an earned goal).
-- Recolours, Outfit Egg rows and owned gated or weekly rows are colours of their base's card, never cards of their own.
-- An egg-only base (Angel Wings) is a card only once owned (never a wall of things you lack).
function Catalog.closetTab(petId,tabSlot,owned)
 local mine={};for _,id in ipairs(type(owned)=="table"and owned or {})do mine[id]=true end
 local listed=Catalog.forPet(petId).byId
 local result={}
 for _,item in ipairs(Catalog.forPet(petId,math.huge).order)do
  if item.slot==tabSlot then
   if not item.variant then table.insert(result,item)
   elseif item.gate~=nil and not mine[item.id]and listed[item.id]then table.insert(result,listed[item.id])end
  end
 end
 for _,item in ipairs(Catalog.eggBases(petId))do
  if item.slot==tabSlot and mine[item.id]then table.insert(result,item)end
 end
 return result
end
-- The shop tabs that sell at least one item for this pet, in Tabs order. A tab ships only
-- when it has an item (VISUAL-BRIEF 6): no Anklets, no Ankle tab. `owned` (optional, the pet's owned list): a tab
-- whose only item is an owned egg-only base shows too (the Back tab once the pet owns Angel Wings).
function Catalog.tabsFor(petId,owned)
 local used={};for _,item in ipairs(Catalog.forPet(petId).order)do used[item.slot]=true end
 if type(owned)=="table"then
  for _,item in ipairs(Catalog.eggBases(petId))do if table.find(owned,item.id)then used[item.slot]=true end end
 end
 local result={};for _,tab in ipairs(Catalog.Tabs)do if used[tab.slot]then table.insert(result,tab)end end
 return result
end
-- The item worn in a slot (either side for a pair), or nil.
function Catalog.equippedIn(petId,equipped,slot)
 if type(equipped)~="table"then return nil end
 for _,key in ipairs(Catalog.slotKeys(petId,slot))do if type(equipped[key])=="string"then return equipped[key]end end
 return nil
end
-- Rendering a saved wearables map (slot key -> item id). Returns one table:
--   mapped: the same slot keys with every variant id replaced by its base id (what the rig
--           rules and meshes know), and
--   tints:  slot key -> {to=<hex>, primary=<base main own hex, or its palette role>,
--           piece=<attachment name or nil>, item=<base id>, id=<variant id>}.
-- Unknown ids pass through unchanged (PetAttachmentRules.normalize drops them).
function Catalog.renderMap(petId,wearables)
 local mapped,tints={},{}
 if type(wearables)=="table"then
  local byId=Catalog.forPet(petId,math.huge).byId
  for key,id in pairs(wearables)do
   if type(key)=="string"and type(id)=="string"then
    local item=byId[id]
    if item and item.variant then
     mapped[key]=item.base
     tints[key]={to=item.color,primary=item.primary or item.role,piece=item.piece,item=item.base,id=item.id}
    else mapped[key]=id end
   end
  end
 end
 return {mapped=mapped,tints=tints}
end
-- The main-piece rule: the override hex for one rig attachment row under a tint, or nil.
-- Only own-coloured pieces of the tinted base item change: the named piece when the variant
-- names one, otherwise every piece whose own colour is the base's main own colour.
function Catalog.tintFor(tint,attachment)
 if type(tint)~="table"or type(attachment)~="table"or attachment.item~=tint.item or attachment.colorRole~="own"then return nil end
 if tint.piece~=nil then return if attachment.name==tint.piece then tint.to else nil end
 if type(tint.primary)~="string"or type(attachment.color)~="string"then return nil end
 return if string.upper(attachment.color)==string.upper(tint.primary)then tint.to else nil
end
-- The slot key a rig attachment row answers to ("Hat", "EarPiercingL").
function Catalog.attachmentKey(definition,attachment)
 local slot=type(definition)=="table"and type(definition.slots)=="table"and definition.slots[attachment.slot]
 return if slot and slot.perSide and attachment.side then attachment.slot..attachment.side else attachment.slot
end
-- Stable text for a tints map (cache keys: beanie and beanie_mint map to the same meshes).
function Catalog.tintSignature(tints)
 local rows={};for key,tint in pairs(tints or {})do table.insert(rows,key.."="..tostring(tint.id or tint.to))end
 table.sort(rows);return table.concat(rows,";")
end
return table.freeze(Catalog)
