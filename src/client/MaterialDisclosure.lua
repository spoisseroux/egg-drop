-- One current-pool/mode disclosure for both Material Egg purchase surfaces.
local Shared=game:GetService("ReplicatedStorage").Shared
local Catalog=require(Shared.MaterialCatalog);local Odds=require(Shared.OddsText);local Copy=require(Shared.UICopy)
local Next=require(script.Parent.NextItemText)
local Disclosure={}
function Disclosure.pool(state)return state.materialPoolVersion or Catalog.PoolVersion end
function Disclosure.fixed(state)
 if Disclosure.pool(state)==4 then return state.restricted~=false or state.materialSelectionMode~="random"end
 return Next.restricted(state)
end
function Disclosure.ready(state)
 if Disclosure.pool(state)~=4 then return true end
 local mode=Catalog.selectionMode(state.restricted)
 if state.materialSelectionMode~=mode then return false end
 if mode=="fixed"then
  return Next.itemId("material",state)==Catalog.fixedNext(Catalog.remaining(state.materialUnlocks,4),4)
 end
 return true
end
function Disclosure.rows(state)
 local rows={};local version=Disclosure.pool(state)
 local entries=Catalog.odds(state.materialUnlocks,version)
 if Disclosure.fixed(state)then
  rows={{id="next",name=Next.line("material",state),value=""}}
 else
  local probabilities={};for _,entry in ipairs(entries)do table.insert(probabilities,entry.probability)end
  local text=if version==4 then Odds.preciseList(probabilities,4)else Odds.list(probabilities)
  for i,entry in ipairs(entries)do table.insert(rows,{id=entry.id,name=Catalog.ById[entry.id].name,value=text[i]})end
 end
 return{rows=rows,per="1 finish per egg",restricted=Disclosure.fixed(state),
  empty=if #entries==0 then "All materials owned"elseif state.materialAvailable~=true or not Disclosure.ready(state)then "Material Eggs are not ready yet."else nil}
end
function Disclosure.note(state)
 if Disclosure.pool(state)~=4 then return "16 Stars · one new material. No duplicates."end
 return Copy.get(if Disclosure.fixed(state)then "hatch.material.fixed"else "hatch.material.random")
end
function Disclosure.promise(state)
 return Copy.get(if Disclosure.fixed(state)then "hatch.material.nextPromise"else "hatch.material.oddsPromise")
end
return Disclosure
