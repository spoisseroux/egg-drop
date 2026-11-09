-- Earned, deterministic color directions. Unlocks are derived from saved ranks.
local Hue={Cost=8,MaxRank=3,Supported={pip=true,puddle=true},Weights={0,.12,.23,.35}}
Hue.Order={
 {id="rose",name="Rose Hue Egg",direction="Rose",color=Color3.fromHex("#D988A1"),cost=8},
 {id="tide",name="Tide Hue Egg",direction="Tide",color=Color3.fromHex("#77AAD3"),cost=8},
 {id="citrus",name="Citrus Hue Egg",direction="Citrus",color=Color3.fromHex("#E7C764"),cost=8},
 {id="iris",name="Iris Hue Egg",direction="Iris",color=Color3.fromHex("#A994D4"),cost=8},
}
Hue.ById={};for _,item in ipairs(Hue.Order)do Hue.ById[item.id]=item end
function Hue.get(hues,petId)
 local row=type(hues)=="table"and hues[petId]
 local ranks={};for _,item in ipairs(Hue.Order)do ranks[item.id]=if row and row.ranks then row.ranks[item.id]or 0 else 0 end
 return{ranks=ranks,body=if row then row.body else "original",secondary=if row then row.secondary else "default"}
end
function Hue.appearance(hues,petId)
 local row=Hue.get(hues,petId)
 return{body=row.body,bodyRank=row.ranks[row.body]or 0,secondary=row.secondary}
end
return Hue
