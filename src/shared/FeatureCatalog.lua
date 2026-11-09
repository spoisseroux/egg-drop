-- Fixed disclosed odds. Full rolled stacks refuse durably without charging.
local Catalog={CatalogVersion=1,PoolVersion=1,Cost=32,StackLimit=99,MaxStage=5,ReceiptLimit=32,
 Order=table.freeze({"horns","claws","wings"}),
 ById=table.freeze({horns=table.freeze({name="Horn buds",rarity="Common",probability=.5}),claws=table.freeze({name="Claws",rarity="Uncommon",probability=.35}),wings=table.freeze({name="Folded wings",rarity="Rare",probability=.15})})}
function Catalog.known(id)return type(id)=="string"and Catalog.ById[id]~=nil end
function Catalog.emptyStock()return{horns=0,claws=0,wings=0}end
function Catalog.emptyRow()return{horns={earned=0,visible=0},claws={earned=0,visible=0},wings={earned=0,visible=0}}end
function Catalog.odds()
 local result={};for _,id in ipairs(Catalog.Order)do local row=Catalog.ById[id];table.insert(result,{id=id,probability=row.probability,rarity=row.rarity})end;return result
end
function Catalog.full(stock)for _,id in ipairs(Catalog.Order)do if(stock[id]or 0)<Catalog.StackLimit then return false end end;return true end
function Catalog.roll(unit)
 if type(unit)~="number"or unit~=unit or unit<0 or unit>=1 then return nil end
 return if unit<.5 then "horns"elseif unit<.85 then "claws"else "wings"
end
return table.freeze(Catalog)
