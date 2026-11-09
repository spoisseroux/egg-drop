-- Canonical paid pigments and free learned recipes. Stable IDs remain saved.
local Hue={Cost=8,MaxRank=3,Supported={pip=true,puddle=true},Weights={0,.65,.84,1}}
Hue.Order={
 {id="rose",name="Rose",direction="Rose",color=Color3.fromHex("#FF327A"),cost=8},
 {id="tide",name="Tide",direction="Tide",color=Color3.fromHex("#008DFF"),cost=8},
 {id="citrus",name="Citrus",direction="Citrus",color=Color3.fromHex("#FFCC00"),cost=8},
 {id="iris",name="Iris",direction="Iris",color=Color3.fromHex("#9350FF"),cost=8},
}
Hue.ById={};for _,item in ipairs(Hue.Order)do Hue.ById[item.id]=item end
Hue.MixOrder={"rose:tide","citrus:rose","iris:rose","citrus:tide","iris:tide","citrus:iris"}
Hue.Mixes={
 ["rose:tide"]={a="rose",b="tide",name="Rose + Tide",color=Color3.fromHex("#AC4BFA")},
 ["citrus:rose"]={a="citrus",b="rose",name="Rose + Citrus",color=Color3.fromHex("#FF733A")},
 ["iris:rose"]={a="iris",b="rose",name="Rose + Iris",color=Color3.fromHex("#E333BE")},
 ["citrus:tide"]={a="citrus",b="tide",name="Tide + Citrus",color=Color3.fromHex("#00BE77")},
 ["iris:tide"]={a="iris",b="tide",name="Tide + Iris",color=Color3.fromHex("#5859F1")},
 ["citrus:iris"]={a="citrus",b="iris",name="Citrus + Iris",color=Color3.fromHex("#EE6997")},
}
function Hue.pair(a,b)
 if not Hue.ById[a]or not Hue.ById[b]or a==b then return nil end
 return if a<b then a..":"..b else b..":"..a
end
function Hue.get(hues,petId)
 local row=type(hues)=="table"and hues[petId]
 local ranks={};for _,item in ipairs(Hue.Order)do ranks[item.id]=if row and row.ranks then row.ranks[item.id]or 0 else 0 end
 return{ranks=ranks,body=if row then row.body else "original",secondary=if row then row.secondary else "default",mix=if row then row.mix else nil}
end
function Hue.appearance(hues,petId)
 local row=Hue.get(hues,petId);local mix=Hue.Mixes[row.mix]
 return{body=row.body,bodyRank=if mix then math.min(row.ranks[mix.a],row.ranks[mix.b])else row.ranks[row.body]or 0,secondary=row.secondary,bodyMix=row.mix}
end
function Hue.capacity(state)
 for pet in pairs(Hue.Supported)do
  local Eggs=require(script.Parent.EggCatalog)
  if Eggs.isOwned(state.inventoryMask or 0,pet)then
   local row=Hue.get(state.hues,pet)
   for _,item in ipairs(Hue.Order)do if row.ranks[item.id]<Hue.MaxRank then return true end end
  end
 end
 return false
end
return Hue
