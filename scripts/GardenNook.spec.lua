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
 local spring=L.RestAnchors[2]
 local function springFixture(options)
  local f={now=0};f.input={alive=true,owned=true,mode="Room",petId="pip",characterId=1,petGeneration=1,
   position=spring.position+Vector3.new(1,3,-2),anchor=spring.position+Vector3.new(1,0,-2),yaw=0}
  local settings={now=function()return f.now end,validFocus=function()return true end,validWander=function(_,target)return target end}
  for key,value in pairs(options or {})do settings[key]=value end
  f.g=Garden.new(settings);f.g:sync({[1]=f.input});return f
 end
 test("second nearby rest retains six seconds and a distinct internal identity",function()
  local f=springFixture();f.now=4;f.g:decide();local a=f.g.actors[1]
  assert(a.action=="nookApproach"and a.restAnchorId=="spring_meadow_west"and(A.vector(a.to)-spring.position).Magnitude<.1)
  f.now=a.endTime+.01;f.g:decide()
  assert(a.action=="nookRest"and a.restAnchorId==spring.id and math.abs(a.endTime-a.startTime-6)<1e-6)
  assert(not f.g.toy.ownerId and f.g:snapshot().actors["1"].restAnchorId==nil,"rest adds no public protocol field")
 end)
 test("spring walking and focus interruptions clear the selected rest identity",function()
  for _,kind in ipairs({"walk","focus"})do
   local f=springFixture();f.now=4;f.g:decide();local a=f.g.actors[1];f.now=a.endTime+.01;f.g:decide()
   if kind=="walk"then f.input.position+=Vector3.new(1,0,0);f.input.anchor+=Vector3.new(1,0,0);f.g:syncOne(1,f.input);assert(a.behavior=="follow")
   else assert(f.g:focus(1,{kind="focus",seq=1,petId="pip",characterId=1,petGeneration=1}));assert(a.mode=="Focus")end
   assert(a.restAnchorId==nil and not f.g.toy.ownerId)
  end
 end)
 test("invalid rest path does not mutate identity or consume the shared cooldown",function()
  local f=springFixture({validWander=function(_,target)return if target==spring.position then target else nil end,
   planPath=function(from,_,_,speed,_,yaw)local path,seconds=A.plan(from,from,Vector3.zero,speed,.5,yaw);path[1].safetyStop=true;return path,seconds end})
  local a=f.g.actors[1];local generation,actionId=a.generation,a.actionId
  f.now=4;assert(not f.g:wander(a,f.input,f.now))
  assert(a.generation==generation and a.actionId==actionId and a.behavior=="follow"and not a.nextNookAt and not a.restAnchorId)
 end)
 test("a safety-stop leg followed by an apparent final rest endpoint still rejects",function()
  local f=springFixture({validWander=function(_,target)return if target==spring.position then target else nil end,
   planPath=function(from,to,v,speed,minimum,yaw)local path,seconds=A.plan(from,to,v,speed,minimum,yaw);path[1].safetyStop=true;return path,seconds end})
  f.now=4;assert(not f.g:wander(f.g.actors[1],f.input,4));assert(not f.g.actors[1].nextNookAt)
 end)
 test("a validated approach is planned once and committed without a second route decision",function()
  local calls=0;local f=springFixture({planPath=function(...)calls+=1;return A.plan(...)end})
  f.now=4;assert(f.g:wander(f.g.actors[1],f.input,4));assert(calls==1 and f.g.actors[1].restAnchorId==spring.id)
 end)
 test("height owner radius and pet radius independently fence the new rest",function()
  for _,kind in ipairs({"height","owner","pet"})do
   local f=springFixture({validWander=function(_,target)return if target==spring.position then target else nil end})
   if kind=="height"then f.input.position=spring.position+Vector3.new(0,6.1,0)
   elseif kind=="owner"then f.input.position=spring.position+Vector3.new(4.1,3,0)
   else local a=f.g.actors[1];a.from=A.pack(spring.position+Vector3.new(8.1,0,0));a.to=a.from end
   f.now=4;assert(not f.g:wander(f.g.actors[1],f.input,4));assert(not f.g.actors[1].nextNookAt)
  end
 end)
 test("eighteen-second cooldown is retained across different rest anchors",function()
  local f=springFixture();f.now=4;assert(f.g:wander(f.g.actors[1],f.input,4));local a=f.g.actors[1]
  local untilTime=a.nextNookAt;assert(untilTime==22)
  f.input.position=L.Nook+Vector3.new(0,3,0);f.input.anchor=L.Nook
  f.g:syncOne(1,f.input);a.from=A.pack(L.Nook);a.to=a.from;a.path=nil
  f.now=10;f.g:wander(a,f.input,10);assert(a.action~="nookApproach"and a.nextNookAt==untilTime)
 end)
 test("replacing character or pet retires the selected spring rest",function()
  for _,key in ipairs({"characterId","petGeneration"})do
   local f=springFixture();f.now=4;f.g:decide();local prior=f.g.actors[1];assert(prior.restAnchorId==spring.id)
   f.input[key]+=1;f.g:syncOne(1,f.input)
   assert(f.g.actors[1]~=prior and f.g.actors[1].restAnchorId==nil and f.g.actors[1].action~="nookRest")
  end
 end)
 local function pairedSpring()
  local f={now=0};local center=(L.RestAnchors[2].position+L.RestAnchors[3].position)*.5
  local input={alive=true,owned=true,mode="Room",petId="pip",characterId=1,petGeneration=1,
   position=center+Vector3.new(0,3,-1),anchor=center+Vector3.new(0,0,-2),yaw=0}
  f.inputs={[1]=table.clone(input),[2]=table.clone(input)}
  f.g=Garden.new({now=function()return f.now end,validFocus=function()return true end,validWander=function(_,target)return target end})
  f.g:sync(f.inputs);f.now=4;f.g:decide();return f
 end
 test("two nearby owners deterministically take distinct spring approach and rest targets",function()
  local f=pairedSpring();local a,b=f.g.actors[1],f.g.actors[2]
  assert(a.restAnchorId=="spring_meadow_east"and b.restAnchorId=="spring_meadow_west","equal distance uses stable ID ordering")
  assert(a.action=="nookApproach"and b.action=="nookApproach"and(A.vector(a.to)-A.vector(b.to)).Magnitude==5)
  f.now=math.max(a.endTime,b.endTime)+.01;f.g:decide()
  assert(a.action=="nookRest"and b.action=="nookRest"and(f.g:position(a,f.now)-f.g:position(b,f.now)).Magnitude==5)
 end)
 test("occupied spring slots reject a third rest and release when an owner leaves",function()
  local f=pairedSpring();f.inputs[3]=table.clone(f.inputs[1]);f.g:sync(f.inputs)
  local third=f.g.actors[3];f.g:wander(third,f.inputs[3],f.now)
  assert(third.restAnchorId==nil and third.action~="nookApproach"and not third.nextNookAt)
  f.g:remove(2);f.g:wander(third,f.inputs[3],f.now)
  assert(third.restAnchorId=="spring_meadow_west"and third.action=="nookApproach")
 end)
 test("focused occupant keeps its held target clear without a rest reservation protocol",function()
  local f=pairedSpring();local a,b=f.g.actors[1],f.g.actors[2]
  f.now=math.max(a.endTime,b.endTime)+.01;f.g:decide()
  assert(f.g:focus(1,{kind="focus",seq=1,petId="pip",characterId=1,petGeneration=1}))
  assert(a.restAnchorId==nil and a.mode=="Focus")
  f.inputs[3]=table.clone(f.inputs[1]);f.g:sync(f.inputs);f.g:wander(f.g.actors[3],f.inputs[3],f.now)
  assert(f.g.actors[3].restAnchorId==nil and f.g.actors[3].action~="nookApproach")
 end)
 test("a rejected first slot leaves its claim free for another owner's valid preflight",function()
  local f=pairedSpring()
  local now=f.now;local rejectedId="spring_meadow_east"
  local g=Garden.new({now=function()return now end,validWander=function(_,target)return target end,
   planPath=function(from,to,v,speed,minimum,yaw)
    local path,seconds=A.plan(from,to,v,speed,minimum,yaw)
    if to==L.RestAnchors[3].position then path[1].safetyStop=true end
    return path,seconds
   end})
  g:sync({[1]=f.inputs[1],[2]=f.inputs[2]})
  assert(g:wander(g.actors[1],f.inputs[1],now)and g.actors[1].restAnchorId=="spring_meadow_west")
  assert(not g:wander(g.actors[2],f.inputs[2],now)or g.actors[2].restAnchorId~=rejectedId)
  assert(g.actors[2].nextNookAt==nil,"failed preflight claimed a cooldown")
 end)
 test("solid approach rejection precedes all rest identity and cooldown changes",function()
  local calls=0;local f=springFixture({validWander=function(_,target)return if target==spring.position then target else nil end,
   validRestPath=function()calls+=1;return false end})
  local a=f.g.actors[1];local generation,actionId=a.generation,a.actionId
  f.now=4;assert(not f.g:wander(a,f.input,4))
  assert(calls==1 and a.generation==generation and a.actionId==actionId and not a.nextNookAt and not a.restAnchorId)
 end)
 test("greeting never resumes an unclaimed spring rest after a third owner takes the slot",function()
  local f=pairedSpring();local a,b=f.g.actors[1],f.g.actors[2]
  f.now=math.max(a.endTime,b.endTime)+.01;f.g:decide();assert(a.action=="nookRest"and b.action=="nookRest")
  f.g.nextGreeting=0;f.g:greeting(f.now,{a,b});assert(a.action=="greet"and b.action=="greet"and not a.restAnchorId and not b.restAnchorId)
  f.inputs[3]=table.clone(f.inputs[1]);f.g:sync(f.inputs);local third=f.g.actors[3]
  assert(f.g:wander(third,f.inputs[3],f.now)and third.restAnchorId=="spring_meadow_east")
  local prior=f.g:release(a);f.g:resume(a,f.inputs[1],prior)
  assert(a.behavior=="follow"and b.behavior=="follow"and not a.restAnchorId and not b.restAnchorId)
  assert(third.restAnchorId=="spring_meadow_east"and third.action=="nookApproach")
 end)
 return{passed=#cases,cases=cases}
end
