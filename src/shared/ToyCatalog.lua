-- Permanent account unlocks; a pet may freely select one unlocked personal toy.
-- Pools (overnight 2026-11-14, slice D): PoolVersion 2 adds Wobble Top and Squeaky Carrot.
-- PoolVersion 3 (QA v685 R7, 2026-11-15) adds the Pocket Deck handheld. Pools 1 and 2 stay.
--   * Every pool is in strictly ascending id order (ToyState.poolValid and the eligible
--     comparison in purchaseEligibility need it; an unsorted pool refuses every purchase).
--   * Pools[1] stays forever: stored toy receipts re-validate their quote against the pool
--     version they were bought from on every load.
--   * CatalogVersion stays 1: stored receipts and quotes pin it.
--   * A toy joins a pool only once PetToyGeometry can build it (client) and it has a name here.
--   * PaidOrder is append-only: a restricted player's fixed next toy stays the old toys first.
local Catalog={CatalogVersion=1,PoolVersion=3,Cost=20,Default="none",ReceiptLimit=32,
 Order=table.freeze({"none","sparkler","ball","bone","wobble_top","squeaky_carrot","pocket_deck"}),
 PaidOrder=table.freeze({"ball","bone","sparkler","wobble_top","squeaky_carrot","pocket_deck"}),
 Pools=table.freeze({[1]=table.freeze({"ball","bone","sparkler"}),
  [2]=table.freeze({"ball","bone","sparkler","squeaky_carrot","wobble_top"}),
  [3]=table.freeze({"ball","bone","pocket_deck","sparkler","squeaky_carrot","wobble_top"})}),
 ById=table.freeze({none=table.freeze({name="None"}),sparkler=table.freeze({name="Sparkler"}),ball=table.freeze({name="Ball"}),bone=table.freeze({name="Bone"}),
  wobble_top=table.freeze({name="Wobble Top"}),squeaky_carrot=table.freeze({name="Squeaky Carrot"}),
  pocket_deck=table.freeze({name="Pocket Deck"})})}
for version,pool in pairs(Catalog.Pools)do
 local previous=""
 for _,id in ipairs(pool)do
  assert(Catalog.ById[id]~=nil and id~=Catalog.Default and id>previous,"ToyCatalog: pool "..version.." is not sorted known ids")
  previous=id
 end
end
-- Saved toyBuy receipts keep the price they were charged: 8 (to v760) or the current Cost.
function Catalog.charged(cost)return cost==Catalog.Cost or cost==8 end
function Catalog.known(id)return type(id)=="string"and Catalog.ById[id]~=nil end
function Catalog.owns(unlocks,id)return id==Catalog.Default or(Catalog.known(id)and type(unlocks)=="table"and unlocks[id]==true)end
function Catalog.remaining(unlocks,version)
 local result={};for _,id in ipairs(Catalog.Pools[version or Catalog.PoolVersion]or{})do if not Catalog.owns(unlocks,id)then table.insert(result,id)end end;return result
end
function Catalog.odds(unlocks)
 local pool=Catalog.remaining(unlocks);local result={};for _,id in ipairs(pool)do table.insert(result,{id=id,probability=1/#pool})end;return result
end
-- Restricted players: the first not-yet-owned toy in the published PaidOrder (no roll).
function Catalog.fixedNext(eligible)
 if type(eligible)~="table"then return nil end
 for _,id in ipairs(Catalog.PaidOrder)do if table.find(eligible,id)then return id end end
 return eligible[1]
end
function Catalog.roll(pool,unit)
 if type(unit)~="number"or unit~=unit or unit<0 or unit>=1 or #pool<1 then return nil end;return pool[math.floor(unit*#pool)+1]
end
return table.freeze(Catalog)
