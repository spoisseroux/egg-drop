-- Pet wearables sold for Stars (manifest `items`, generated into each rig definition's
-- `wearableItems` by scripts/build_bear_attachments.py). Fixed prices, never random.
-- An item fills one slot key, or both sides of a per-side slot (a helix pair fills
-- EarPiercingL and EarPiercingR). The keys match PetAttachmentRules.
-- Recolour variants (WearableVariants, slice B) are their own item ids: they sell and save
-- like any item and render as their base item's meshes with one colour override (renderMap).
local Defs=require(script.Parent.PetRigDefinitions)
local Variants=require(script.Parent.WearableVariants)
local Catalog={Version=1,OwnedLimit=128}
-- Shop tabs in display order (UI: hat, shirt, neck, ears, eyes, mouth, tail, then slice B's
-- eyewear, cheek, wrist, ankle). Append-only: WearableState validates take-off against this
-- list. The shop shows only tabs that sell something for the pet (Catalog.tabsFor).
Catalog.Tabs=table.freeze({
 {id="hat",slot="Hat",label="Hat"},{id="shirt",slot="Shirt",label="Shirt"},{id="neck",slot="Neck",label="Neck"},
 {id="ears",slot="EarPiercing",label="Ears"},{id="eyes",slot="Eyes",label="Eyes"},{id="mouth",slot="Mouth",label="Mouth"},
 {id="tail",slot="Tail",label="Tail"},
 {id="eyewear",slot="Eyewear",label="Eyewear"},{id="cheek",slot="Cheek",label="Cheek"},
 {id="wrist",slot="Wrist",label="Wrist"},{id="ankle",slot="Ankle",label="Ankle"}})
Catalog.TierPrice=table.freeze({common=15,rare=30,showcase=60})
-- Recolour rows (WearableVariants), here so the localization export reads their names.
Catalog.Variants=Variants.Rows
Catalog.week=Variants.week

-- Items for one pet's rig from an explicit variant row list (uncached; forPet caches it).
-- Order: each rig item, then its variants in row order, so a slot tab lists a base with its
-- recolours right after it. A variant copies the base's slot, keys, flags, tier and main
-- colour data and adds variant=true, base=<id>, color=<hex>, piece=<attachment name or nil>.
function Catalog.compose(petId,rows)
 local definition=type(petId)=="string"and Defs[petId]
 local order,byId={},{}
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
     variant=true,base=base.id,color=row.color,piece=row.piece}))
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
 end
 return table.freeze({order=table.freeze(order),byId=table.freeze(byId)})
end
local cache={}
local none=Catalog.compose(nil)
-- Items for one pet's rig: {order={item}, byId={id=item}}. Pets without authored wearables
-- get none. `week` (default: this week) gates variant rows that carry `from`; pass
-- math.huge for every row ever released (rendering a saved id never depends on the clock).
function Catalog.forPet(petId,week)
 if type(petId)~="string"then return none end
 local rows=Variants.rows(if type(week)=="number"then week else Variants.week())
 -- Rows only ever join as the week advances, so the count names the set.
 local key=petId.."|"..#rows
 local found=cache[key]
 if not found then found=Catalog.compose(petId,rows);cache[key]=found end
 return found
end
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
 bear=table.freeze({sunhat=Vector3.new(0,.03,0),beanie=Vector3.new(0,.015,0)}),
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
-- The shop tabs that sell at least one item for this pet, in Tabs order. A tab ships only
-- when it has an item (VISUAL-BRIEF 6): no Anklets, no Ankle tab.
function Catalog.tabsFor(petId)
 local used={};for _,item in ipairs(Catalog.forPet(petId).order)do used[item.slot]=true end
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
