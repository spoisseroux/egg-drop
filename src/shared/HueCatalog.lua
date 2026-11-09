-- Canonical paid pigments and free learned recipes. Stable IDs remain saved.
local Hue={Cost=8,MaxRank=3,Supported={pip=true,puddle=true,wick=true,orbit=true,bloom_pip=true,foxfire_wick=true,eclipse_orbit=true},LegacySupported={pip=true,puddle=true},Weights={0,.65,.84,1},CatalogVersion="hue-items-v1",MaxDose=5,StackLimit=9007199254740000}
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
function Hue.appearance(hues,petId,petHues)
 local row=Hue.get(hues,petId);local mix=Hue.Mixes[row.mix]
 local result={body=row.body,bodyRank=if mix then math.min(row.ranks[mix.a],row.ranks[mix.b])else row.ranks[row.body]or 0,secondary=row.secondary,bodyMix=row.mix}
 local doses=petHues and petHues[petId]
 if doses then result.mainDoses=table.clone(doses.main);result.secondaryDoses=table.clone(doses.secondary)end
 return result
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
Hue.ItemOrder={"rose","tide","citrus","iris","reset"}
Hue.Items={};for _,h in ipairs(Hue.Order)do Hue.Items[h.id]={id=h.id,name=h.name.." fruit",color=h.color,weight=20}end
Hue.Items.reset={id="reset",name="Reset Hue",color=Color3.fromHex("#D4F8FF"),weight=20}
Hue.DoseWeights={0,.44,.65,.84,.93,1}
function Hue.emptyCounts()return{rose=0,tide=0,citrus=0,iris=0}end
function Hue.validCounts(v)
 if type(v)~="table"then return false end
 for k in pairs(v)do if not Hue.ById[k]then return false end end
 for _,h in ipairs(Hue.Order)do local n=v[h.id];if type(n)~="number"or n~=n or n%1~=0 or n<0 or n>5 then return false end end
 return true
end
function Hue.equalCounts(a,b)
 if not Hue.validCounts(a)or not Hue.validCounts(b)then return false end
 for _,h in ipairs(Hue.Order)do if a[h.id]~=b[h.id]then return false end end;return true
end
function Hue.doseStrength(counts)
 local maximum=0;for _,h in ipairs(Hue.Order)do maximum=math.max(maximum,counts[h.id]or 0)end
 return Hue.DoseWeights[maximum+1]or 0
end
local setAnchors={}
local function setKey(ids)local sorted=table.clone(ids);table.sort(sorted);return table.concat(sorted,":")end
for _,h in ipairs(Hue.Order)do setAnchors[h.id]=h.color end
for key,m in pairs(Hue.Mixes)do setAnchors[key]=m.color end
for key,hex in pairs({["citrus:rose:tide"]="#F45688",["iris:rose:tide"]="#A64FFF",["citrus:iris:rose"]="#F059A5",["citrus:iris:tide"]="#35A9CD",["citrus:iris:rose:tide"]="#C963D9"})do setAnchors[key]=Color3.fromHex(hex)end
local function linear(c)return if c<=.04045 then c/12.92 else ((c+.055)/1.055)^2.4 end
local function srgb(c)return if c<=.0031308 then c*12.92 else 1.055*c^(1/2.4)-.055 end
function Hue.resolveTarget(counts)
 if not Hue.validCounts(counts)then return nil end
 local r,g,b,total=0,0,0,0
 for level=1,5 do
  local ids={};for _,h in ipairs(Hue.Order)do if counts[h.id]>=level then table.insert(ids,h.id)end end
  if #ids>0 then local c=setAnchors[setKey(ids)];local weight=#ids;r+=linear(c.R)*weight;g+=linear(c.G)*weight;b+=linear(c.B)*weight;total+=weight end
 end
 if total==0 then return nil end
 return Color3.new(srgb(r/total),srgb(g/total),srgb(b/total))
end
function Hue.roll(unit)
 if type(unit)~="number"or unit~=unit or unit<0 or unit>=1 then return nil end
 return Hue.ItemOrder[math.min(5,math.floor(unit*5)+1)]
end
function Hue.mappedCounts(row,channel,preset)
 local counts=Hue.emptyCounts();local mapping={2,3,5}
 if channel=="secondary"then if Hue.ById[preset]and row.ranks[preset]>0 then counts[preset]=5;return counts end
 elseif Hue.ById[preset]and row.ranks[preset]>0 then counts[preset]=mapping[row.ranks[preset]];return counts
 elseif Hue.Mixes[preset]then local mix=Hue.Mixes[preset];local rank=math.min(row.ranks[mix.a],row.ranks[mix.b]);if rank>0 then counts[mix.a],counts[mix.b]=mapping[rank],mapping[rank];return counts end end
 return nil
end
function Hue.presets(hues,petId)
 local row=Hue.get(hues,petId);local result={main={},secondary={}}
 for _,h in ipairs(Hue.Order)do if row.ranks[h.id]>0 then
  table.insert(result.main,{id=h.id,name=h.name,counts=Hue.mappedCounts(row,"main",h.id)})
  table.insert(result.secondary,{id=h.id,name=h.name,counts=Hue.mappedCounts(row,"secondary",h.id)})
 end end
 for _,key in ipairs(Hue.MixOrder)do local counts=Hue.mappedCounts(row,"main",key);if counts then table.insert(result.main,{id=key,name=Hue.Mixes[key].name,counts=counts})end end
 return result
end
return Hue
