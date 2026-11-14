-- Permanent account unlocks; selections are independent for each owned pet.
-- Pool 3 (overnight 2026-11-14, slice D) is DATA ONLY: Pearl Edge and Speckle Satin are named
-- and pooled here, but PoolVersion stays 2 and PaidOrder / Order are unchanged, so nothing
-- sells or lists them. Catalog.available() needs a verified SurfaceAppearance template for
-- every PaidOrder finish; adding one without its template would close ALL finish purchases.
-- To ship pool 3: build and verify the templates (BuildPetMaterialTemplates), then in one
-- commit set PoolVersion=3 and append both ids to PaidOrder and Order.
-- Pools stay sorted by id and old pools stay forever (stored receipts re-validate against them).
local Catalog={CatalogVersion=1,PoolVersion=2,Cost=16,Default="standard",ReceiptLimit=32,EnablePurchases=true,
 Order=table.freeze({"standard","gloss","matte","metal"}),PaidOrder=table.freeze({"gloss","matte"}),
 Pools=table.freeze({[1]=table.freeze({"gloss","matte","metal"}),[2]=table.freeze({"gloss","matte"}),
  [3]=table.freeze({"gloss","matte","pearl_edge","speckle_satin"})}),
 ById=table.freeze({standard=table.freeze({name="Standard",profile="Body"}),gloss=table.freeze({name="Gloss",profile="BodyGloss"}),matte=table.freeze({name="Matte",profile="BodyMatte"}),metal=table.freeze({name="Metal",profile="BodyMetal"}),
  pearl_edge=table.freeze({name="Pearl Edge",profile="BodyPearl"}),speckle_satin=table.freeze({name="Speckle Satin",profile="BodySpeckle"})})}
for version,pool in pairs(Catalog.Pools)do
 local previous=""
 for _,id in ipairs(pool)do
  assert(Catalog.ById[id]~=nil and id~=Catalog.Default and id>previous,"MaterialCatalog: pool "..version.." is not sorted known ids")
  previous=id
 end
end
function Catalog.known(id)return type(id)=="string"and Catalog.ById[id]~=nil end
function Catalog.owns(unlocks,id)return id==Catalog.Default or(Catalog.known(id)and type(unlocks)=="table"and unlocks[id]==true)end
function Catalog.remaining(unlocks,poolVersion)
 local pool=Catalog.Pools[poolVersion or Catalog.PoolVersion]or {}
 local result={};for _,id in ipairs(pool)do if not Catalog.owns(unlocks,id)then table.insert(result,id)end end;return result
end
function Catalog.odds(unlocks)
 local remaining=Catalog.remaining(unlocks);local result={}
 for _,id in ipairs(remaining)do table.insert(result,{id=id,probability=1/#remaining})end;return result
end
-- Restricted players: the first not-yet-owned finish in the published PaidOrder (no roll).
function Catalog.fixedNext(eligible)
 if type(eligible)~="table"then return nil end
 for _,id in ipairs(Catalog.PaidOrder)do if table.find(eligible,id)then return id end end
 return eligible[1]
end
function Catalog.roll(eligible,unit)
 if type(unit)~="number"or unit~=unit or unit<0 or unit>=1 or #eligible<1 then return nil end
 return eligible[math.floor(unit*#eligible)+1]
end
function Catalog.available(pack)
 if not Catalog.EnablePurchases or not pack then return false end
 for _,id in ipairs(Catalog.PaidOrder)do
  local profile=Catalog.ById[id].profile;local template=pack:FindFirstChild(profile)
  if not template or not template:IsA("SurfaceAppearance")or template:GetAttribute("NativeVerified")~=true or template:GetAttribute("MaterialVersion")~=1 or template:GetAttribute("MaterialProfile")~=profile then return false end
 end
 return true
end
return table.freeze(Catalog)
