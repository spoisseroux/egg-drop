-- Pet wearables sold for Stars (manifest `items`, generated into each rig definition's
-- `wearableItems` by scripts/build_bear_attachments.py). Fixed prices, never random.
-- An item fills one slot key, or both sides of a per-side slot (a helix pair fills
-- EarPiercingL and EarPiercingR). The keys match PetAttachmentRules.
local Defs=require(script.Parent.PetRigDefinitions)
local Catalog={Version=1,OwnedLimit=64}
-- Shop tabs in display order (UI: hat, shirt, neck, ears, eyes, mouth, tail).
Catalog.Tabs=table.freeze({
 {id="hat",slot="Hat",label="Hat"},{id="shirt",slot="Shirt",label="Shirt"},{id="neck",slot="Neck",label="Neck"},
 {id="ears",slot="EarPiercing",label="Ears"},{id="eyes",slot="Eyes",label="Eyes"},{id="mouth",slot="Mouth",label="Mouth"},
 {id="tail",slot="Tail",label="Tail"}})
Catalog.TierPrice=table.freeze({common=15,rare=30,showcase=60})

local cache={}
-- Items for one pet's rig: {order={item}, byId={id=item}}. Pets without authored wearables get none.
function Catalog.forPet(petId)
 if cache[petId]then return cache[petId]end
 local definition=type(petId)=="string"and Defs[petId]
 local order,byId={},{}
 if type(definition)=="table"and type(definition.wearableItems)=="table"then
  local slots=definition.slots or {}
  for _,raw in ipairs(definition.wearableItems)do
   if type(raw.id)=="string"and type(raw.slot)=="string"and type(raw.price)=="number"and raw.price>0 then
    local perSide=slots[raw.slot]~=nil and slots[raw.slot].perSide==true
    local item=table.freeze({id=raw.id,slot=raw.slot,name=raw.name or raw.id,tier=raw.tier or "common",price=raw.price,
     flags=table.freeze(table.clone(raw.flags or {})),perSide=perSide,
     keys=table.freeze(if perSide then {raw.slot.."L",raw.slot.."R"}else {raw.slot}),
     primary=if type(raw.primary)=="string"and string.sub(raw.primary,1,4)=="own:"then string.sub(raw.primary,5)else nil,
     -- Tinted items name the pet palette role their main piece takes ("secondary", "face").
     role=if type(raw.primary)=="string"and string.sub(raw.primary,1,4)~="own:"then raw.primary else nil})
    table.insert(order,item);byId[item.id]=item
   end
  end
 end
 cache[petId]=table.freeze({order=table.freeze(order),byId=table.freeze(byId)})
 return cache[petId]
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
-- The item worn in a slot (either side for a pair), or nil.
function Catalog.equippedIn(petId,equipped,slot)
 if type(equipped)~="table"then return nil end
 for _,key in ipairs(Catalog.slotKeys(petId,slot))do if type(equipped[key])=="string"then return equipped[key]end end
 return nil
end
return table.freeze(Catalog)
