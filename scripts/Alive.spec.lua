-- Studio Client. Alive switches (ALIVE-BUILD-PLAN-2026-11-22 step 0, revisions 1 and 2): the ceiling needs
-- the flag and the beta place or Studio; a missing key is on; a missing attribute is off.
-- Usage: require(PlayerScripts.Client.ZZSpecs.Alive)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Shared=game:GetService("ReplicatedStorage").Shared
 local Alive=require(Shared.Alive);local Flags=require(Shared.FeatureFlags)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local saved={}
 for _,f in ipairs(Alive.Features)do saved[f]=workspace:GetAttribute(Alive.attribute(f))end
 local ok,problem=pcall(function()
  test("five features, their attributes and config keys; every flag is in the build",function()
   assert(table.concat(Alive.Features," ")=="springs menus close wind life scene snack windbed asmr wobble balls crunch air fruit keepout aerohatch deckjuice pet2 paint")
   assert(Alive.attribute("wind")=="Alive_wind"and Alive.key("wind")=="alive_wind")
   assert(Flags.AliveSprings and Flags.AliveMenus and Flags.AliveClose and Flags.AliveWind and Flags.AliveLife and Flags.AliveScene and Flags.AliveSnack)
   assert(Flags.AliveWindbed and Flags.AliveAsmr and Flags.AliveWobble and Flags.AliveBalls and Flags.AliveCrunch and Flags.AliveAir and Flags.AliveFruit and Flags.AliveKeepOut and Flags.AliveAeroHatch and Flags.AliveDeckJuice and Flags.AlivePet2)
   assert(Alive.attribute("life")=="Alive_life"and Alive.key("life")=="alive_life")
  end)
  test("ceiling: flag and (beta place or Studio); never the live place; unknown features are off",function()
   local on={AliveSprings=true,AliveMenus=true,AliveClose=true,AliveWind=true,AliveLife=true,AliveScene=true,AliveSnack=true,AliveWindbed=true,AliveAsmr=true,AliveWobble=true,AliveBalls=true,AliveCrunch=true,AliveAir=true,AliveFruit=true,AliveKeepOut=true,AliveAeroHatch=true,AliveDeckJuice=true,AlivePet2=true}
   for _,f in ipairs(Alive.Features)do
    assert(Alive.ceiling(f,on,107705084891479,false),f.." on the beta")
    assert(Alive.ceiling(f,on,96451847774961,true),f.." in Studio")
    assert(not Alive.ceiling(f,on,96451847774961,false),f.." on live")
    assert(not Alive.ceiling(f,{},107705084891479,true),f.." without its flag")
   end
   assert(not Alive.ceiling("nope",on,107705084891479,true)and not Alive.on("nope"))
  end)
  test("resolve: ceiling, then override, then config, then on; malformed config counts as missing",function()
   assert(Alive.resolve("wind",true,true,false)==false,"the ceiling wins")
   assert(Alive.resolve("wind",true,false,true)==false and Alive.resolve("wind",false,true,true)==true)
   assert(Alive.resolve("wind",false,nil,true)==false and Alive.resolve("wind",true,nil,true)==true)
   assert(Alive.resolve("wind",nil,nil,true)==true,"missing")
   for _,odd in ipairs({"false",0,1,"",{}})do assert(Alive.resolve("wind",odd,nil,true)==true,"malformed "..tostring(odd))end
   assert(Alive.resolve("wind",nil,"off",true)==true,"an override is a boolean or nothing")
   -- Beta 17: the wind bed's missing (or malformed) value is off; a config or an override still turns it on.
   assert(Alive.resolve("windbed",nil,nil,true)==false and Alive.resolve("windbed","yes",nil,true)==false)
   assert(Alive.resolve("windbed",true,nil,true)==true and Alive.resolve("windbed",nil,true,true)==true)
  end)
  test("on(): only a true attribute; missing, false or odd is off; changed() fires",function()
   local fired=0
   for _,f in ipairs(Alive.Features)do
    local name=Alive.attribute(f)
    workspace:SetAttribute(name,nil);assert(not Alive.on(f),f.." missing")
    local link=Alive.changed(f):Connect(function()fired+=1 end)
    workspace:SetAttribute(name,true);assert(Alive.on(f)==Alive.ceiling(f))
    workspace:SetAttribute(name,false);assert(not Alive.on(f))
    workspace:SetAttribute(name,"true");assert(not Alive.on(f),f.." string")
    task.wait();link:Disconnect()
   end
   assert(fired>=#Alive.Features,"changed() fired "..fired)
  end)
 end)
 for _,f in ipairs(Alive.Features)do workspace:SetAttribute(Alive.attribute(f),saved[f])end
 assert(ok,problem)
 return{passed=#cases,cases=cases}
end
