-- No profile writes: active availability is independent from permanent saved identity.
return function(shared)
 local Pets=require(shared.PetCatalog);local Eggs=require(shared.EggCatalog);local Palette=require(shared.PetPalette)
 local Hue=require(shared.HueCatalog);local Defs=require(shared.PetRigDefinitions);local NewDefs=require(shared.NewBabyRigDefinitions)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local ids={"pip","puddle","wick","orbit","bloom_pip","foxfire_wick","eclipse_orbit"}
 local protected={
  pip={"#2A2226","#66332E","#FFF6E9","#E8A6A6"},puddle={"#404149","#7C626C","#FFFAF0","#D6AFB0"},
  wick={"#383342","#63434C","#FFF4DB","#DCA39D"},orbit={"#343448","#655265","#FFF4DB","#C2ABB7"},
  bloom_pip={"#383342","#63434C","#FFF4DB","#DCA39D"},foxfire_wick={"#393044","#6B475C","#FFF4DB","#D9A3AB"},eclipse_orbit={"#363448","#645265","#FFF4DB","#C5A6AF"},
 }
 test("all seven saved IDs and ownership bits remain permanent while only the Bear (pip) is active",function()
  assert(#Pets.collection==7 and #Pets.active==1 and Pets.active[1].id=="pip")
  for i,id in ipairs(ids)do
   assert(Pets.collection[i]==Pets.byId[id]and Pets.byId[id].index==i and Eggs.bit(id)==2^(i-1))
   assert(Pets.isActive(id)==(i==1)and Pets.isActive(Pets.byId[id])==(i==1))
   assert(Pets.isUnlocked(Pets.byId[id],0,0,Eggs.bit(id)),"retained ownership no longer equips")
  end
  assert(Eggs.mask(ids)==127 and #Pets.rares==3 and #Eggs.Families==4)
 end)
 test("active collection target excludes retained owners without changing total ownership semantics",function()
  local retained=Eggs.bit("foxfire_wick")
  assert(Pets.ownedCount(0,0,retained)==1 and Pets.activeOwnedCount(0,0,retained)==0)
  assert(Pets.collectionSummary(0,0,retained)=="00/01 · 1 retained")
  assert(Pets.activeOwnedCount(0,0,127)==1 and Pets.ownedCount(0,0,127)==7 and Pets.collectionSummary(0,0,127)=="01/01 · 6 retained")
  assert(Pets.collectionSummary(0,0,Eggs.bit("pip"))=="01/01")
 end)
 test("white Main and achromatic grey Secondary agree across canonical and direct definitions, protected colors stay exact",function()
  for _,id in ipairs(ids)do
   local p=Palette.original(id);assert(p.body==Color3.fromHex("#FFFFFF")and p.secondary==Color3.fromHex("#C8C8C8"))
   assert(Pets.byId[id].color==p.body and Pets.byId[id].accent==p.secondary)
   local def=Defs[id];assert(Color3.fromHex(def.palette.body)==p.body and Color3.fromHex(def.palette.secondary)==p.secondary)
   if NewDefs[id]then assert(NewDefs[id].palette.body=="#FFFFFF"and NewDefs[id].palette.secondary=="#C8C8C8")end
   for i,role in ipairs({"face","mouth","ivory","blush"})do assert(p[role]==Color3.fromHex(protected[id][i]),"protected "..id.." "..role)end
   -- faceBody only feeds blush (cheek) pieces; the two-tone Bear has none.
   local hasBlush=false;for _,piece in ipairs(def.pieces)do if piece.colorRole=="blush"then hasBlush=true end end
   if hasBlush then assert(def.faceBody~="#FFFFFF","original cheek blend source lost")end
  end
 end)
 test("hands cuffs feet and floating charm use Secondary without changing semantic geometry",function()
  for _,id in ipairs(ids)do
   local found={};local twoTone=Defs[id].twoTone
   for _,piece in ipairs(Defs[id].pieces)do
    if piece.channel=="HandL"or piece.channel=="HandR"or piece.channel=="CuffL"or piece.channel=="CuffR"or piece.channel=="FootL"or piece.channel=="FootR"or piece.channel=="Charm"then
     -- Two-tone rigs (the v1 Bear) take paw/foot tips from the body gradient, so limbs stay body; the charm stays Secondary.
     local expected=(twoTone and piece.channel~="Charm")and"body"or"secondary"
     assert(piece.colorRole==expected,id.." "..piece.name.." expected "..expected);found[piece.channel]=true
    end
   end
   assert(found.HandL and found.HandR and found.FootL and found.FootR and found.Charm)
  end
 end)
 test("four pigment anchors and six equal-pair recipes retain their prior exact colors",function()
  for id,hex in pairs({rose="#FF327A",tide="#008DFF",citrus="#FFCC00",iris="#9350FF"})do assert(Hue.ById[id].color==Color3.fromHex(hex))end
  for pair,hex in pairs({["rose:tide"]="#AC4BFA",["citrus:rose"]="#FF733A",["iris:rose"]="#E333BE",["citrus:tide"]="#00BE77",["iris:tide"]="#5859F1",["citrus:iris"]="#EE6997"})do assert(Hue.Mixes[pair].color==Color3.fromHex(hex))end
 end)
 test("partial doses start at new neutral base, reset independently, and retained pets still receive full dyes",function()
  for _,id in ipairs(ids)do
   local main,secondary=Hue.emptyCounts(),Hue.emptyCounts();main.rose=1;secondary.tide=5
   local p=Palette.resolve(id,{mainDoses=main,secondaryDoses=secondary})
   local expected=Palette.tint(Color3.fromHex("#FFFFFF"),Hue.ById.rose.color,.44)
   assert((Vector3.new(p.body.R,p.body.G,p.body.B)-Vector3.new(expected.R,expected.G,expected.B)).Magnitude<.00001)
   assert(p.secondary==Hue.ById.tide.color and main.rose==1 and secondary.tide==5)
   p=Palette.resolve(id,{mainDoses=Hue.emptyCounts(),secondaryDoses=secondary});assert(p.body==Color3.new(1,1,1)and p.secondary==Hue.ById.tide.color)
   p=Palette.resolve(id,{mainDoses=main,secondaryDoses=Hue.emptyCounts()});assert(p.body==expected and p.secondary==Color3.fromHex("#C8C8C8"))
  end
 end)
 -- v1: formerly checked normalized surviving Meadow weights. Meadow is retired, so it
 -- publishes no odds and cannot roll at any stored guarantee counter.
 test("retired Meadow egg publishes no odds and cannot roll even with frozen guarantee counter",function()
  assert(Eggs.ById.meadow.retired and not Eggs.hasRarePool("meadow"))
  for misses=0,7 do
   assert(#Eggs.odds("meadow",misses)==0)
   for i=0,9 do assert(not pcall(Eggs.roll,"meadow",misses,i/10))end
  end
 end)
 return{passed=#cases,cases=cases}
end
