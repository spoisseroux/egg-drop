-- Bounded near-owner rest-nook behavior; no world, profile or timed tasks.
return function(server)
 local Garden=require(server.GardenState);local Shared=game.ReplicatedStorage.Shared
 local L=require(Shared.GardenLayout);local A=require(Shared.GardenActivity)
 local cases={};local function test(name,f)f();table.insert(cases,name)end
 local function fixture()
  local f={now=0};f.input={alive=true,owned=true,mode="Room",petId="pip",characterId=1,petGeneration=1,
   position=L.Nook+Vector3.new(-2,3,1),anchor=L.Nook+Vector3.new(-2,0,1),yaw=0}
  f.g=Garden.new({now=function()return f.now end,validFocus=function()return true end,validWander=function(_,target)return target end})
  f.g:sync({[1]=f.input});f.now=4;f.g:decide();return f
 end
 test("nearby idle baby approaches the supported nook then settles facing its owner",function()
  local f=fixture();local a=f.g.actors[1];assert(a.action=="nookApproach"and(A.vector(a.to)-L.Nook).Magnitude<1e-6)
  f.now=a.endTime+.01;f.g:decide();assert(a.action=="nookRest"and math.abs(a.endTime-a.startTime-6)<1e-6)
  local pose=A.sample(a,a.startTime+1);local d=f.input.position-pose.position
  assert(math.abs(math.atan2(math.sin(pose.yaw-math.atan2(d.X,d.Z)),math.cos(pose.yaw-math.atan2(d.X,d.Z))))<1e-6)
 end)
 test("walking or focus preempts nook rest without moving another owner or toy",function()
  for _,kind in ipairs({"walk","focus"})do
   local f=fixture();local a=f.g.actors[1];f.now=a.endTime+.01;f.g:decide()
   if kind=="walk"then f.input.position+=Vector3.new(1,0,0);f.input.anchor+=Vector3.new(1,0,0);f.g:syncOne(1,f.input);assert(a.behavior=="follow")
   else assert(f.g:focus(1,{kind="focus",seq=1,petId="pip",characterId=1,petGeneration=1}));assert(a.mode=="Focus")end
   assert(not f.g.toy.ownerId)
  end
 end)
 test("distant owner does not send a baby across the garden just to use the nook",function()
  local now=4;local input={alive=true,owned=true,mode="Room",petId="pip",characterId=1,petGeneration=1,position=Vector3.new(0,7,0),anchor=Vector3.new(0,4.025,0),yaw=0}
  local g=Garden.new({now=function()return now end,validWander=function(_,target)return target end});g:sync({[1]=input});now=8;g:decide()
  assert(g.actors[1].action~="nookApproach"and g.actors[1].action~="nookRest")
 end)
 test("actual nearby owner discovers nook even when lateral follow anchor is farther than4",function()
  local now=0;local input={alive=true,owned=true,mode="Room",petId="pip",characterId=1,petGeneration=1,
   position=Vector3.new(24.181,7.148,-13.796),anchor=Vector3.new(21.5,4.38,-11.35),yaw=0}
  assert(Vector2.new(input.anchor.X-L.Nook.X,input.anchor.Z-L.Nook.Z).Magnitude>4)
  local g=Garden.new({now=function()return now end,validWander=function(_,target)return target end});g:sync({[1]=input});now=4;g:decide()
  assert(g.actors[1].action=="nookApproach"and(A.vector(g.actors[1].to)-L.Nook).Magnitude<1e-6)
 end)
 test("a planner safety hold is never reported as arriving at the nook",function()
  local now=0;local input={alive=true,owned=true,mode="Room",petId="pip",characterId=1,petGeneration=1,
   position=L.Nook+Vector3.new(-2,3,1),anchor=L.Nook+Vector3.new(-2,0,1),yaw=0}
  local g=Garden.new({now=function()return now end,validWander=function(_,target)return target end,
   planPath=function(from,_,_,speed,_,yaw)local path,seconds=A.plan(from,from,Vector3.zero,speed,.5,yaw);path[1].safetyStop=true;return path,seconds end})
  g:sync({[1]=input});now=4;g:decide();assert(g.actors[1].action~="nookApproach"and g.actors[1].action~="nookRest")
 end)
 return{passed=#cases,cases=cases}
end
