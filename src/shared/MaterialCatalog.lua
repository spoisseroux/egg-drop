-- Permanent finish unlocks and per-pet selections. Historical pools are immutable.
-- Pool3 stays data-only. Pool4 Lucky Jelly requires verified one/two-tone assets;
-- capability remains closed until native proof and coherent rollout are complete.
-- EnablePurchases=false for v1 (economy scope 2026-11-16): the Material Egg is not sold. Its row
-- leaves Hatch eggs (EggHatchView.liveOrder), `available` is false so the server refuses a new
-- materialBuy, and no odds show. Owned finishes, receipts and a saved pending result stay valid
-- and keep rendering. Finishes return in the v1.1 Look Egg (TODO.md).
local Catalog={CatalogVersion=1,PoolVersion=4,StagedPoolVersion=4,Cost=16,Default="standard",ReceiptLimit=32,EnablePurchases=false,
 Order=table.freeze({"standard","gloss","matte","metal","jelly"}),PaidOrder=table.freeze({"gloss","matte","jelly"}),
 Pools=table.freeze({[1]=table.freeze({"gloss","matte","metal"}),[2]=table.freeze({"gloss","matte"}),
  [3]=table.freeze({"gloss","matte","pearl_edge","speckle_satin"}),[4]=table.freeze({"gloss","jelly","matte"})}),
 PoolRules=table.freeze({[4]=table.freeze({cost=16,weights=table.freeze({gloss=45,jelly=10,matte=45}),fixedOrder=table.freeze({"gloss","matte","jelly"})})}),
 ById=table.freeze({standard=table.freeze({name="Standard",profile="Body"}),gloss=table.freeze({name="Gloss",profile="BodyGloss"}),matte=table.freeze({name="Matte",profile="BodyMatte"}),metal=table.freeze({name="Metal",profile="BodyMetal"}),
  jelly=table.freeze({name="Jelly",profile="BodyJelly",twoToneProfile="BodyTwoToneJelly"}),
  pearl_edge=table.freeze({name="Pearl Edge",profile="BodyPearl"}),speckle_satin=table.freeze({name="Speckle Satin",profile="BodySpeckle"})})}
for version,pool in pairs(Catalog.Pools)do
 local previous=""
 for _,id in ipairs(pool)do assert(Catalog.ById[id]~=nil and id~=Catalog.Default and id>previous,"MaterialCatalog: pool "..version.." is not sorted known ids");previous=id end
end
function Catalog.known(id)return type(id)=="string"and Catalog.ById[id]~=nil end
function Catalog.owns(unlocks,id)return id==Catalog.Default or(Catalog.known(id)and type(unlocks)=="table"and unlocks[id]==true)end
function Catalog.cost(poolVersion)
 local version=poolVersion or Catalog.PoolVersion
 if not Catalog.Pools[version]then return nil end
 local rules=Catalog.PoolRules[version];return if rules then rules.cost else 16
end
function Catalog.selectionMode(restricted)return if restricted==false then "random"else "fixed"end
function Catalog.remaining(unlocks,poolVersion)
 local result={};for _,id in ipairs(Catalog.Pools[poolVersion or Catalog.PoolVersion]or {})do if not Catalog.owns(unlocks,id)then table.insert(result,id)end end;return result
end
local function weight(id,version)
 local rules=Catalog.PoolRules[version];return if rules then rules.weights[id]or 0 else 1
end
function Catalog.odds(unlocks,poolVersion)
 local version=poolVersion or Catalog.PoolVersion
 local remaining=Catalog.remaining(unlocks,version);local total=0
 for _,id in ipairs(remaining)do total+=weight(id,version)end
 local result={};for _,id in ipairs(remaining)do table.insert(result,{id=id,probability=weight(id,version)/total})end;return result
end
function Catalog.fixedNext(eligible,poolVersion)
 if type(eligible)~="table"then return nil end
 local version=poolVersion or Catalog.PoolVersion;if not Catalog.Pools[version]then return nil end
 local rules=Catalog.PoolRules[version]
 local order=if rules then rules.fixedOrder else Catalog.Pools[version]
 for _,id in ipairs(order)do if table.find(eligible,id)then return id end end
 return eligible[1]
end
function Catalog.roll(eligible,unit,poolVersion)
 local version=poolVersion or Catalog.PoolVersion;local pool=Catalog.Pools[version]
 if not pool or type(eligible)~="table"or type(unit)~="number"or unit~=unit or unit<0 or unit>=1 or #eligible<1 then return nil end
 local total,seen=0,{}
 for _,id in ipairs(eligible)do
  if seen[id]or not table.find(pool,id)then return nil end
  seen[id]=true;total+=weight(id,version)
 end
 for k in pairs(eligible)do if type(k)~="number"or k%1~=0 or k<1 or k>#eligible then return nil end end
 if total<=0 then return nil end
 local target,cumulative=unit*total,0
 for _,id in ipairs(eligible)do cumulative+=weight(id,version);if target<cumulative then return id end end
 return eligible[#eligible] -- floating-point endpoint, with unit still strictly below1
end
local function verified(pack,name)
 if not pack then return false end
 for _,entry in ipairs(pack:GetChildren())do
  if entry.Name==name and entry:IsA("SurfaceAppearance")and entry:GetAttribute("NativeVerified")==true and entry:GetAttribute("MaterialVersion")==1 and entry:GetAttribute("MaterialProfile")==name then return true end
 end
 return false
end
-- Asset capability alone: every finish of the pool has a verified template. `available` adds the
-- sale switch; the server and the client sell only through `available`.
function Catalog.capable(pack,twoTonePack,poolVersion)
 if not pack then return false end
 local version=poolVersion or Catalog.PoolVersion;if not Catalog.Pools[version]then return false end
 local rules=Catalog.PoolRules[version]
 local order=if rules then rules.fixedOrder else Catalog.Pools[version]
 for _,id in ipairs(order)do
  local profile=Catalog.ById[id].profile
  if not verified(pack,profile)then return false end
  if version>=4 and not verified(twoTonePack,Catalog.ById[id].twoToneProfile or("BodyTwoTone"..string.sub(profile,5)))then return false end
 end
 return true
end
function Catalog.available(pack,twoTonePack,poolVersion)
 return Catalog.EnablePurchases==true and Catalog.capable(pack,twoTonePack,poolVersion)
end
return table.freeze(Catalog)
