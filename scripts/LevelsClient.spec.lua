-- Studio Client. The Levels runtime switch as a client reads it: only a true workspace attribute is on (a
-- missing one, as on a server without LevelsConfig, is off), it cannot be set from here for the server,
-- and the init wiring that depends on it is in the build.
-- Usage: require(PlayerScripts.Client.ZZSpecs.LevelsClient)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Levels=require(game:GetService("ReplicatedStorage").Shared.Levels)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local saved=workspace:GetAttribute(Levels.Attribute)
 local ok,problem=pcall(function()
  test("only true is on; missing, false and odd values are off; changed() fires",function()
   local fired=0
   local link=Levels.changed():Connect(function()fired+=1 end)
   workspace:SetAttribute(Levels.Attribute,true)
   assert(Levels.switch())
   for _,part in ipairs(Levels.Parts)do assert(Levels.on(part)==Levels.ceiling(part),part)end
   for _,odd in ipairs({false,"true",1})do
    workspace:SetAttribute(Levels.Attribute,odd);assert(not Levels.switch()and Levels.key()=="0000",tostring(odd))
   end
   workspace:SetAttribute(Levels.Attribute,nil);assert(not Levels.switch()and Levels.key()=="0000","missing")
   task.wait();link:Disconnect()
   assert(fired>=1)
  end)
  test("a client cannot set the server's value",function()
   assert(Levels.setSwitch(true)==false and not Levels.switch())
  end)
  test("off: the trick tickets, the medal watch and the shop chip all stand down",function()
   workspace:SetAttribute(Levels.Attribute,false)
   local Toasts=require(client.StatToasts)
   assert(not Toasts.tricksOn()and #Toasts.trickUps({},{petStats={pets={}}})==0)
   assert(require(client.LockedItem).info({gate={stat="jump",level=15}},{},false)==nil)
   assert(require(client.StatsHost).medalEggs({statEgg={medalEggs=3}})==0)
  end)
 end)
 workspace:SetAttribute(Levels.Attribute,saved)
 assert(ok,problem)
 return{passed=#cases,cases=cases}
end
