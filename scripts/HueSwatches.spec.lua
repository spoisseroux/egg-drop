-- Actual four-key resolver quotes, with independent Astra-authored mixed examples.
return function(client)
 local Swatches=require(client.HueSwatches);local Shared=game.ReplicatedStorage.Shared
 local H=require(Shared.HueCatalog);local P=require(Shared.PetPalette);local Pets=require(Shared.PetCatalog)
 local Http=game:GetService("HttpService");local cases={};local function test(name,run)run();table.insert(cases,name)end
 local examples=Http:JSONDecode([=[[{"channel":"Main","base":"#FFFFFF","counts":{"rose":2,"tide":1,"citrus":0,"iris":0},"savedColor":"#E0A7E8","inspected":{"id":"rose","stage":4},"rows":[{"id":"rose","savedCount":2,"colors":["#DFCAFD","#E0A7E8","#E17CD2","#E55FC1","#E83CB3"]},{"id":"tide","savedCount":1,"colors":["#E0A7E8","#CEA9FC","#B189FC","#9B7AFC","#856DFC"]},{"id":"citrus","savedCount":0,"colors":["#FAAABC","#FBAFB4","#FA9C8F","#FB9875","#FB965A"]},{"id":"iris","savedCount":0,"colors":["#DAA8F0","#DAA8F0","#C87FEF","#BC65F0","#B24AF1"]}]},{"channel":"Secondary","base":"#A8A5AE","counts":{"rose":0,"tide":0,"citrus":1,"iris":2},"savedColor":"#D190C4","inspected":{"id":"iris","stage":4},"rows":[{"id":"rose","savedCount":0,"colors":["#D68CC3","#E089B9","#E96BAE","#EE58A6","#F3449E"]},{"id":"tide","savedCount":0,"colors":["#8DABD5","#87A6D6","#679ADF","#5094E5","#378FEA"]},{"id":"citrus","savedCount":1,"colors":["#D190C4","#E294AA","#EC9295","#F19884","#F59D75"]},{"id":"iris","savedCount":2,"colors":["#DAA7B5","#D190C4","#C777D2","#BF68DC","#B859E3"]}]}]]=])
 test("forty authored mixed chips match on all seven neutral saved identities",function()
  for _,pet in ipairs(Pets.collection)do for _,example in ipairs(examples)do
   local channel=string.lower(example.channel);local appearance={mainDoses=H.emptyCounts(),secondaryDoses=H.emptyCounts()}
   appearance[if channel=="main"then "mainDoses"else "secondaryDoses"]=example.counts
   for _,row in ipairs(example.rows)do for stage,hex in ipairs(row.colors)do
    local actual=Swatches.at(pet.id,appearance,channel,row.id,stage)
    assert("#"..string.upper(actual:ToHex())==hex,pet.id.." "..channel.." "..row.id.." "..stage)
   end end
  end end
 end)
 test("all 1296 legal vectors preserve other pigments and current saved-stage color in both channels",function()
  local combinations=0
  for rose=0,5 do for tide=0,5 do for citrus=0,5 do for iris=0,5 do
   local counts={rose=rose,tide=tide,citrus=citrus,iris=iris};combinations+=1
   for _,channel in ipairs({"main","secondary"})do
    local appearance={mainDoses=H.emptyCounts(),secondaryDoses=H.emptyCounts()}
    appearance[if channel=="main"then "mainDoses"else "secondaryDoses"]=counts
    local before=Http:JSONEncode(appearance);local actual=P.resolve("pip",appearance)[if channel=="main"then "body"else "secondary"]
    for _,hue in ipairs(H.Order)do
     local stage=if counts[hue.id]>0 then counts[hue.id]else 1
     local color=Swatches.at("pip",appearance,channel,hue.id,stage)
     assert(color and color.R==color.R and color.G>=0 and color.B<=1.00001)
     if counts[hue.id]>0 then assert(color==actual,"saved chip is not current color")end
    end
    assert(Http:JSONEncode(appearance)==before,"inspection mutated saved vectors")
   end
  end end end end
  assert(combinations==1296)
 end)
 test("isolated full stage reaches exact existing anchors without altering the opposite channel",function()
  for _,pet in ipairs(Pets.collection)do for _,hue in ipairs(H.Order)do
   local a={mainDoses=H.emptyCounts(),secondaryDoses=H.emptyCounts()};local before=Http:JSONEncode(a)
   assert(Swatches.at(pet.id,a,"main",hue.id,5)==hue.color and Swatches.at(pet.id,a,"secondary",hue.id,5)==hue.color)
   assert(Http:JSONEncode(a)==before)
  end end
 end)
 test("invalid stage channel hue and unknown target cannot form a quote",function()
  for _,stage in ipairs({-1,6,1.5,math.huge})do assert(Swatches.at("pip",{},"main","rose",stage)==nil)end
  assert(Swatches.at("pip",{},"main","rose",0)==require(game.ReplicatedStorage.Shared.PetPalette).resolve("pip",{mainDoses=H.emptyCounts(),secondaryDoses=H.emptyCounts()}).body)
  assert(Swatches.at("pip",{},"other","rose",2)==nil and Swatches.at("pip",{},"main","garnet",2)==nil and Swatches.at("unknown",{},"main","rose",2)==nil)
 end)
 return{passed=#cases,cases=cases}
end
