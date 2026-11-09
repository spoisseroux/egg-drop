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
  assert(Palette.resolve("wick")==nil)
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
 return cases
end
