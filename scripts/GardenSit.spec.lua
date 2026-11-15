-- QA v685 R9: pets sit for longer. In the live garden (shared toy retired) every
-- Layout.SitEvery-th idle turn is a replicated sit in place (a "settle" rest of
-- Layout.SitRest seconds, then the usual 5 s rest) instead of a wander, so nothing walks
-- the pet off after 3.5 s. Pure GardenState with a fake clock.
-- Run (Server): require(game.ServerScriptService.Server.ZZSpecs.GardenSit)(game.ServerScriptService.Server)
return function(server)
 local Garden=require(server.GardenState);local L=require(game.ReplicatedStorage.Shared.GardenLayout)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function fixture(shared)
  local f={now=0}
  f.g=Garden.new({sharedToyEnabled=shared,now=function()return f.now end,validWander=function(_,target)return target end})
  f.input={alive=true,owned=true,mode="Room",petId="pip",characterId=1,petGeneration=1,position=Vector3.new(0,7,-25),anchor=Vector3.new(0,4.025,-25),yaw=0}
  -- (the same open spot PersonalToyGardenTimeline wanders on)
  f.inputs={[1]=f.input};f.g:sync(f.inputs)
  function f:run(seconds,watch)
   for _=1,math.floor(seconds/.5)do
    self.now+=.5;self.g:sync(self.inputs);self.g:decide()
    if watch and watch(self.g.actors[1],self.now)==false then return end
   end
  end
  return f
 end
 local function isSit(actor)return actor.behavior=="rest"and actor.action=="settle"and math.abs(actor.endTime-actor.startTime-L.SitRest)<1e-6 end

 test("the numbers: every third idle turn, 14 s",function()
  assert(L.SitEvery==3 and L.SitRest==14 and L.SitRest>=2*6,"R9 asks for roughly double the old 6 s")
 end)

 test("an idle pet sits in place for SitRest, then rests 5 s more, and still wanders in between",function()
  local f=fixture(false)
  local sits,walks,current,lastId={},0,nil,nil
  f:run(150,function(actor,now)
   if isSit(actor)then
    if not current or current.actionId~=actor.actionId then
     current={actionId=actor.actionId,start=actor.startTime,at=f.g:position(actor,now),walksBefore=walks};table.insert(sits,current);walks=0
    end
    assert((f.g:position(actor,now)-current.at).Magnitude<1e-3,"the pet moved during a sit")
   elseif current and not current.after and actor.behavior=="rest"and actor.action==nil then
    -- The existing follow-on rest: 5 s more in the same spot (a rest of 4 s+ also sits).
    current.after=actor.endTime-actor.startTime
    assert(math.abs(current.after-5)<1e-6 and(f.g:position(actor,now)-current.at).Magnitude<1e-3)
    current.stillUntil=actor.endTime
   end
   if(actor.action=="wander"or actor.action=="nookApproach")and actor.actionId~=lastId then walks+=1;lastId=actor.actionId end
  end)
  assert(#sits>=3,"only "..#sits.." sits in 150 s")
  assert(sits[1].start<40,"the first sit came late: "..sits[1].start)
  for index,sit in ipairs(sits)do
   if index<#sits then
    assert(sit.after,"sit "..index.." had no follow-on rest")
    assert(sit.stillUntil-sit.start>=L.SitRest+5-1e-6,"sit "..index.." was cut short")
   end
   if index>1 then assert(sit.walksBefore>=1,"no wander between sits "..(index-1).." and "..index)end
  end
 end)

 test("the owner walking off ends the sit at once",function()
  local f=fixture(false)
  f:run(60,function(actor)return not isSit(actor)end)
  local actor=f.g.actors[1];assert(isSit(actor),"no sit to interrupt")
  f.now+=2
  f.input.position+=Vector3.new(3,0,0);f.input.anchor+=Vector3.new(3,0,0)
  f.g:sync(f.inputs);f.g:decide()
  assert(actor.behavior=="follow"and actor.action==nil,"the pet stayed sitting: "..tostring(actor.behavior).."/"..tostring(actor.action))
 end)

 test("the shared-toy garden keeps its old turns (no sit turn)",function()
  local f=fixture(nil)
  f:run(90,function(actor)assert(not isSit(actor),"a sit turn ran with the shared toy on")end)
 end)

 return cases
end
