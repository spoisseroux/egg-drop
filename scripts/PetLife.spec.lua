-- Overnight 2026-11-12 pet-life presentation: deck reactions, ears/tail, petting
-- curve, idle beats. Native-recipe fixture pets in workspace; no remotes, no saves.
return function(client)
 local Visual=require(client.GardenPetVisual);local Reactions=require(client.PetReactions)
 local Pets=require(game.ReplicatedStorage.Shared.PetCatalog)
 local folder=Instance.new("Folder");folder.Name="_PetLifeSpec";folder.Parent=workspace
 local cases,views={},{};local function test(name,run)run();table.insert(cases,name)end
 local function make()local v=Visual.new(folder,Vector3.new(2100,4.025,#views*4),Pets.byId.pip,.72,nil,{native=true});table.insert(views,v);return v end
 local function piece(v,name)for _,p in ipairs(v.pieces)do if p.name==name then return p end end;error(name.." missing")end
 local ok,err=pcall(function()
  test("deck cheer hops with the pleased face and is limited to one per 1.5 s",function()
   local v={};assert(Reactions.trigger(v,"cheer",10))
   local hop,face=Reactions.sample(v,10+Reactions.HopDuration/2);assert(hop>.9 and face=="pleased")
   assert(not Reactions.trigger(v,"cheer",11.2),"cheer repeated inside 1.5 s");assert(Reactions.trigger(v,"cheer",11.6))
   local done=select(2,Reactions.sample(v,11.6+2));assert(done==nil,"cheer face never ended")
  end)
  test("a win double-hops; a loss is startled for 0.4 s, then sleepy",function()
   local v={};assert(Reactions.trigger(v,"win",0))
   local d=Reactions.HopDuration;assert(Reactions.sample(v,d*.5)>.9 and Reactions.sample(v,d*1.5)>.9 and Reactions.sample(v,d)<.05)
   assert(select(2,Reactions.sample(v,d*1.5))=="pleased")
   local l={};assert(Reactions.trigger(l,"loss",0))
   assert(select(2,Reactions.sample(l,.2))=="startled"and select(2,Reactions.sample(l,.6))=="sleepy"and Reactions.sample(l,.2)==0)
   assert(not Reactions.trigger(l,"cheer",1),"a cheer interrupted the loss beat")
   assert(select(2,Reactions.sample(l,10))==nil)
  end)
  test("Reduced Effects keeps the faces but drops the hop",function()
   local v={reducedEffects=true};Reactions.trigger(v,"cheer",0);local hop,face=Reactions.sample(v,Reactions.HopDuration/2)
   assert(hop==0 and face=="pleased")
  end)
  test("a real Bear visual lifts and shows the reaction without allocating",function()
   local v=make();v.reducedEffects=false;v:update(0)
   local count=#v.model:GetDescendants();local rest=piece(v,"Head").part.Position.Y
   Reactions.trigger(v,"cheer",os.clock()-Reactions.HopDuration/2);v:update(0)
   assert(piece(v,"Head").part.Position.Y>rest+.02,"no hop");assert(#v.model:GetDescendants()==count)
   Reactions.clear(v);v:update(0);assert(math.abs(piece(v,"Head").part.Position.Y-rest)<1e-3)
  end)
 end)
 for _,v in ipairs(views)do v:destroy()end;folder:Destroy()
 assert(ok,err);return{passed=#cases,cases=cases}
end
