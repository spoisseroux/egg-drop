return function(shared)
 local Hue=require(shared.HueCatalog);local Palette=require(shared.PetPalette);local Defs=require(shared.PetRigDefinitions)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function close(a,b)return math.abs(a-b)<.00001 end
 test("linear-light blend uses the standard independent black-white reference",function()
  local mixed=Palette.tint(Color3.new(0,0,0),Color3.new(1,1,1),.5)
  assert(close(mixed.R,.735356983)and close(mixed.G,.735356983)and close(mixed.B,.735356983))
 end)
 test("every learned grade keeps protected facial roles exact and Original restores authored colors",function()
  for _,pet in ipairs({"pip","puddle"})do
   local base=Palette.resolve(pet);assert(table.isfrozen(base))
   for _,hue in ipairs(Hue.Order)do
    local previous=0
    for rank=1,3 do
     local palette=Palette.resolve(pet,{body=hue.id,bodyRank=rank,secondary=hue.id})
     local distance=(Vector3.new(palette.body.R,palette.body.G,palette.body.B)-Vector3.new(base.body.R,base.body.G,base.body.B)).Magnitude
     assert(distance>previous);previous=distance;assert(palette.secondary==hue.color)
     for _,role in ipairs({"face","blush","mouth","ivory"})do assert(palette[role]==base[role])end
    end
   end
   local original=Palette.resolve(pet,{body="original",bodyRank=3,secondary="default"})
   for role,hex in pairs(Defs[pet].palette)do assert(original[role]==Color3.fromHex(hex))end
  end
 end)
 test("sparse defaults and invalid tokens cannot add arbitrary colors or mutate rank maps",function()
  local row=Hue.get(nil,"pip");assert(row.body=="original"and row.secondary=="default")
  for _,hue in ipairs(Hue.Order)do assert(row.ranks[hue.id]==0)end
  local base=Palette.resolve("pip");local invalid=Palette.resolve("pip",{body="rose",bodyRank=99,secondary="unknown",face=Color3.new(1,0,0)})
  assert(invalid.body==base.body and invalid.secondary==base.secondary and invalid.face==base.face)
  assert(Palette.resolve("unknown-pet")==nil and Palette.resolve("wick")~=nil)
 end)
 test("canonical vivid swatches and six fixed recipes use the lesser learned grade without recoloring face",function()
  for _,pet in ipairs({"pip","puddle"})do
   local base=Palette.resolve(pet)
   for _,h in ipairs(Hue.Order)do local full=Palette.resolve(pet,{body=h.id,bodyRank=3});assert(full.body==h.color)end
   for _,key in ipairs(Hue.MixOrder)do
    local mix=Hue.Mixes[key];local ranks={rose=3,tide=3,citrus=3,iris=3};ranks[mix.a]=1
    local token=Hue.appearance({[pet]={ranks=ranks,body=mix.a,secondary="default",mix=key}},pet)
    assert(token.bodyRank==1 and token.bodyMix==key)
    local palette=Palette.resolve(pet,token);local expected=Palette.tint(base.body,mix.color,.65)
    assert(close(palette.body.R,expected.R)and close(palette.body.G,expected.G)and close(palette.body.B,expected.B))
    assert(palette.face==base.face and palette.secondary==base.secondary and palette.ivory==base.ivory)
   end
  end
 end)
 test("all 1296 legal dose combinations resolve finite colors and preserve authored protected roles on all seven pets",function()
  local combinations=0
  for rose=0,5 do for tide=0,5 do for citrus=0,5 do for iris=0,5 do
   local counts={rose=rose,tide=tide,citrus=citrus,iris=iris};assert(Hue.validCounts(counts));combinations+=1
   local target=Hue.resolveTarget(counts);local total=rose+tide+citrus+iris
   assert((target==nil)==(total==0))
   if target then for _,n in ipairs({target.R,target.G,target.B})do assert(n==n and n>=0 and n<=1.000001)end end
   for pet in pairs(Hue.Supported)do
    local original=Palette.resolve(pet);local main=Palette.resolve(pet,{mainDoses=counts,secondaryDoses=Hue.emptyCounts()})
    local secondary=Palette.resolve(pet,{mainDoses=Hue.emptyCounts(),secondaryDoses=counts})
    assert(main.secondary==original.secondary and secondary.body==original.body)
    for _,role in ipairs({"face","mouth","ivory","blush"})do assert(main[role]==original[role]and secondary[role]==original[role])end
   end
  end end end end
  assert(combinations==1296)
 end)
 test("layered mixture uses pigment mass in linear light and equal bars hit exact shared anchors",function()
  local mixed=Hue.resolveTarget({rose=3,tide=1,citrus=0,iris=0})
  local expected=Palette.tint(Hue.ById.rose.color,Hue.Mixes["rose:tide"].color,.5)
  assert(close(mixed.R,expected.R)and close(mixed.G,expected.G)and close(mixed.B,expected.B))
  mixed=Hue.resolveTarget({rose=5,tide=1,citrus=0,iris=0});expected=Palette.tint(Hue.ById.rose.color,Hue.Mixes["rose:tide"].color,2/6)
  assert(close(mixed.R,expected.R)and close(mixed.G,expected.G)and close(mixed.B,expected.B))
  for _,key in ipairs(Hue.MixOrder)do local pair=Hue.Mixes[key]
   for n=1,5 do local counts=Hue.emptyCounts();counts[pair.a],counts[pair.b]=n,n;local actual=Hue.resolveTarget(counts)
    assert(close(actual.R,pair.color.R)and close(actual.G,pair.color.G)and close(actual.B,pair.color.B))
   end
  end
  for _,bad in ipairs({{rose=6,tide=0,citrus=0,iris=0},{rose=1/0,tide=0,citrus=0,iris=0},{rose=0,tide=0,citrus=0,iris=0,unknown=0}})do assert(not Hue.validCounts(bad)and Hue.resolveTarget(bad)==nil)end
 end)
 return cases
end
