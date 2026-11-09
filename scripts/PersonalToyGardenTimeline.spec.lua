-- Execute in Edit/Server with fresh client+server source namespaces. This drives
-- the real production coordinator, planner and activity sampler, not fake follow.
return function(server,client)
 local Garden=require(server.GardenState);local A=require(game.ReplicatedStorage.Shared.GardenActivity)
 local Follow=require(client.PetFollow)
 local Factory=require(client.PetFactory);local Pets=require(game.ReplicatedStorage.Shared.PetCatalog)
 local folder=Instance.new("Folder");folder.Name="_PersonalToyGardenTimeline";folder.Parent=workspace
 local visuals,cases={},{};local function test(name,f)f();table.insert(cases,name)end
 local function fixture(realFollow,seed)
  seed=seed or 299
  local f={now=0,starts={},durations={},wanderAt=nil,wanders=0,previous=false,realFollow=realFollow,ownerId=seed+1,dt=if realFollow then 1/60 else .05}
  f.input={alive=true,owned=true,mode="Room",petId="pip",characterId=7,petGeneration=3,position=Vector3.new(0,7,-25),anchor=Vector3.new(0,4.025,-25),yaw=0}
  f.garden=Garden.new({sharedToyEnabled=false,now=function()return f.now end,validWander=function(_,target)return target end,
   publish=function(snapshot)
    if f.snapshot then for id,actor in pairs(snapshot.actors)do local prior=f.snapshot.actors[id];if prior then actor.previous=prior;prior.previous=nil end end end
    f.snapshot=snapshot
   end})
  f.visual=Factory.new(folder,f.input.anchor,Pets.byId.pip,.72,{charmVisible=false,toyId="ball",appearanceGeneration=1},{native=true});table.insert(visuals,f.visual)
  f.visual.greeting=2;f.visual.cosmeticSeed=seed;f.visual.reducedEffects=false
  function f:step()
   self.now+=self.dt;self.garden:step(self.dt,{[self.ownerId]=self.input})
   local actor=self.garden.actors[self.ownerId];if not actor then return end
   local v=self.visual
   v.personalPlayEnabled=actor.mode=="Room";v.personalActorIdentity=actor.characterId..":"..actor.petGeneration
   v.personalIdleUntil=if actor.behavior=="follow"then actor.endTime+3.5 else 0
   if self.realFollow then
    self.follow=Follow.activity(v,self.snapshot.actors[tostring(self.ownerId)],self.now,self.dt,self.follow,false)
   else
    local sample=A.sample(actor,self.now)
    v.origin=sample.position;v.gaitWeight=if sample.velocity.Magnitude>.05 then .5 else 0;v.yaw=sample.yaw;v:applyGardenPose(sample)
   end
   v.cosmeticTime=self.now;v:update(self.dt)
   if actor.action=="wander"then
    if not self.wanderAt then self.wanderAt=self.now end
    if self.lastWander~=actor.actionId then self.wanders+=1;self.lastWander=actor.actionId end
   end
   if v.personalToyActive and not self.previous then table.insert(self.starts,self.now);self.episodeStart=self.now end
   if not v.personalToyActive and self.previous then
    table.insert(self.durations,{seconds=self.now-self.episodeStart,behavior=v.gardenBehavior,action=v.gardenAction,gait=v.gaitWeight})
   end
   self.previous=v.personalToyActive
  end
  return f
 end
 local ok,problem=pcall(function()
  test("real wander timeline permits a first play before3.5s and spaced later opportunities",function()
   local f=fixture();for _=1,1800 do f:step()end
   assert(f.wanderAt and #f.starts>=3,"real garden starved personal toys")
   assert(f.starts[1]<f.wanderAt and f.starts[1]<3.5,"first play missed settled garden window")
   local period=9+(299%701)/100
   for i=2,#f.starts do assert(f.starts[i]-f.starts[i-1]>=period-.051,"wandering reset the persistent cooldown")end
  end)
  test("seven real Follow seeds finish full actions and preserve stationary wandering",function()
   for _,seed in ipairs({0,1,42,299,300,700,996})do
    local f=fixture(true,seed)
    for i=1,5400 do f:step();if i%600==0 then task.wait()end end
    assert(f.wanders>=3,"quiet grace starved ordinary wandering for seed"..seed)
    assert(#f.durations>=3,"real Follow pipeline starved toy opportunities for seed"..seed)
    for _,episode in ipairs(f.durations)do
     assert(episode.seconds>=1.75,"seed"..seed.." short idle toy "..episode.seconds.."s: "..tostring(episode.behavior).."/"..tostring(episode.action).." gait="..tostring(episode.gait))
    end
    local period=9+(seed%701)/100
    for i=2,#f.starts do assert(f.starts[i]-f.starts[i-1]>=period-.017,"cooldown shortened for seed"..seed)end
   end
  end)
  test("unchanged follow retarget does not move the settled idle deadline",function()
   local f=fixture(true);repeat f:step()until f.garden.actors[f.ownerId]
   local actor=f.garden.actors[f.ownerId];local idle=actor.idleSince
   for _=1,5 do f.now+=.1;f.garden:transition(actor,"follow",f.input.anchor,.5);assert(actor.idleSince==idle)end
  end)
  test("actual owner movement cancels prop and preserves deadline through the next arrival",function()
   local f=fixture();repeat f:step()until f.visual.personalToyActive or f.now>3
   assert(f.visual.personalToy);local deadline=f.visual.personalNextOpportunity;local old=f.visual.personalToy
   f.input.position+=Vector3.new(2,0,0);f.input.anchor+=Vector3.new(2,0,0)
   local canceled=false
   for _=1,100 do
    f:step()
    if f.visual.gaitWeight>.025 then assert(not f.visual.personalToy);canceled=true end
    assert(f.visual.personalNextOpportunity==deadline,"arrival recreated its first-play deadline")
    if canceled and f.visual.gaitWeight==0 then assert(not f.visual.personalToy,"arrival spammed a new toy before cooldown")end
   end
   assert(canceled and old.destroyed and f.now<deadline)
  end)
 end)
 for _,v in ipairs(visuals)do v:destroy()end;folder:Destroy();assert(ok,problem);return{passed=#cases,cases=cases,productionGardenTimeline=true}
end
