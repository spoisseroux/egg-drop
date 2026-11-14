-- Inactive pool4 UI fixture; never activates catalogue/save/native capability.
return function(client)
 local D=require(client.MaterialDisclosure)
 local Catalog=require(game:GetService("ReplicatedStorage").Shared.MaterialCatalog)
 local Shop=require(client.EggHatchView)
 for mask=0,7 do
  local unlocks={};for i,id in ipairs({"gloss","jelly","matte"})do if bit32.band(mask,2^(i-1))~=0 then unlocks[id]=true end end
  local state={materialPoolVersion=4,materialSelectionMode="random",restricted=false,materialAvailable=true,materialUnlocks=unlocks,nectar=16}
  local data=D.rows(state);local remaining=Catalog.remaining(unlocks,4)
  assert(D.ready(state)and not data.restricted and #data.rows==#remaining)
  if #remaining>0 then
   local sum=0;for _,row in ipairs(data.rows)do sum+=assert(tonumber((row.value:gsub("%%",""))))end
   assert(math.abs(sum-100)<.000001,"precise conditional odds do not sum100")
   assert(Shop.hatchAction("material",state).enabled,"disclosed pool4 buy blocked")
  else assert(not Shop.hatchAction("material",state).enabled)end
  for _,restricted in ipairs({true,false})do
   state.restricted=restricted;state.materialSelectionMode="fixed"
   state.nextFixed={material=Catalog.fixedNext(remaining,4)}
   data=D.rows(state)
   assert(data.restricted and data.rows[1].value==""and not data.rows[1].name:find("%%"),"fixed alternative leaked luck percentage")
   assert(D.ready(state)==restricted,"contradictory policy/mode did not fail closed")
  end
 end
 local one={materialPoolVersion=4,materialSelectionMode="random",restricted=false,materialAvailable=true,materialUnlocks={gloss=true}}
 local rows=D.rows(one).rows
 assert(rows[1].id=="jelly"and rows[1].value=="18.1818%"and rows[2].value=="81.8182%")
 local missing={materialPoolVersion=4,materialAvailable=true,materialUnlocks={},restricted=false,nectar=16}
 assert(not D.ready(missing)and not Shop.hatchAction("material",missing).enabled,"missing published mode enabled purchase")
 local fixed={materialPoolVersion=4,materialSelectionMode="fixed",restricted=true,materialAvailable=true,materialUnlocks={},nectar=16}
 assert(not D.ready(fixed)and not Shop.hatchAction("material",fixed).enabled,"missing next finish enabled purchase")
 fixed.nextFixed={material="matte"};assert(not D.ready(fixed),"stale published next finish enabled purchase")
 fixed.nextFixed.material="gloss";assert(D.ready(fixed),"exact published next finish rejected")
 fixed.materialUnlocks={gloss=true,matte=true,jelly=true};fixed.nextFixed={}
 assert(D.ready(fixed)and not Shop.hatchAction("material",fixed).enabled,"all-owned fixed empty state is not terminal")
 local legacy={materialPoolVersion=2,materialAvailable=true,materialUnlocks={},restricted=false}
 assert(D.ready(legacy)and #D.rows(legacy).rows==2 and D.rows(legacy).rows[1].value=="50%"and Catalog.PoolVersion==4,"legacy pool2 disclosure changed or active pool4 missing")
 return{passed=4}
end
