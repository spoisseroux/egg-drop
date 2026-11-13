-- Permanent account unlocks; selections are independent for each owned pet.
local Catalog={CatalogVersion=1,PoolVersion=2,Cost=16,Default="standard",ReceiptLimit=32,EnablePurchases=true,
 Order=table.freeze({"standard","gloss","matte","metal"}),PaidOrder=table.freeze({"gloss","matte"}),
 Pools=table.freeze({[1]=table.freeze({"gloss","matte","metal"}),[2]=table.freeze({"gloss","matte"})}),
 ById=table.freeze({standard=table.freeze({name="Standard",profile="Body"}),gloss=table.freeze({name="Gloss",profile="BodyGloss"}),matte=table.freeze({name="Matte",profile="BodyMatte"}),metal=table.freeze({name="Metal",profile="BodyMetal"})})}
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
