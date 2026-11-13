-- Restricted players (paid random items; BUILD-PLAN F1 architect change 6, F2 item 4).
-- When the snapshot says `restricted`, every Star egg gives the fixed next item in a
-- published order instead of a roll, so the egg views show "Next: <item>" (or "All
-- collected") where the odds list would be. Pure; the egg views call it.
local Shared=game:GetService("ReplicatedStorage").Shared
local UICopy=require(Shared.UICopy)
local Pets=require(Shared.PetCatalog)
local Toys=require(Shared.ToyCatalog)
local Finishes=require(Shared.MaterialCatalog)
local Hues=require(Shared.HueCatalog)
local Features=require(Shared.FeatureCatalog)
local Next={}

-- The display name of a fixed next item. kind: "toy", "material", "hue", "feature",
-- or "hatch" (a pet egg; `recipeId` picks the recipe).
function Next.itemName(kind,id)
 if type(id)~="string"then return nil end
 local entry
 if kind=="toy"then entry=Toys.ById[id]
 elseif kind=="material"then entry=Finishes.ById[id]
 elseif kind=="hue"then entry=Hues.Items and Hues.Items[id]
 elseif kind=="feature"then entry=Features.ById[id]
 elseif kind=="hatch"then entry=Pets.byId[id]end
 return if entry and type(entry.name)=="string"then entry.name else id
end
-- The id the server will give next for an egg kind, or nil (nothing left to give).
function Next.itemId(kind,state,recipeId)
 local fixed=type(state)=="table"and state.nextFixed
 if type(fixed)~="table"then return nil end
 if kind=="hatch"then return type(fixed.hatch)=="table"and fixed.hatch[recipeId]or nil end
 local id=fixed[kind]
 return if type(id)=="string"then id else nil
end
-- True when this player's eggs show the fixed next item instead of odds.
function Next.restricted(state)return type(state)=="table"and state.restricted==true end
-- "Next: Squeaky Bone" / "All collected".
function Next.line(kind,state,recipeId)
 local name=Next.itemName(kind,Next.itemId(kind,state,recipeId))
 if not name then return UICopy.get("hatch.next.done")end
 return UICopy.get("hatch.next.line",{item=name})
end

return table.freeze(Next)
