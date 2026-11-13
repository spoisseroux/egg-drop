-- Permanent account unlocks; a pet may freely select one unlocked personal toy.
local Catalog={CatalogVersion=1,PoolVersion=1,Cost=8,Default="none",ReceiptLimit=32,
 Order=table.freeze({"none","sparkler","ball","bone"}),PaidOrder=table.freeze({"ball","bone","sparkler"}),
 Pools=table.freeze({[1]=table.freeze({"ball","bone","sparkler"})}),
 ById=table.freeze({none=table.freeze({name="None"}),sparkler=table.freeze({name="Sparkler"}),ball=table.freeze({name="Ball"}),bone=table.freeze({name="Bone"})})}
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
