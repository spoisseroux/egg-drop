-- Isolated authority/clock tests for the shared toy; no rewards or remotes.
return function(server)
 local Garden=require(server.GardenState)
 local Shared=game:GetService("ReplicatedStorage").Shared
 local Activity=require(Shared.GardenActivity);local Layout=require(Shared.GardenLayout)
 local cases={};local function test(name,f)f();table.insert(cases,name)end
 local function fixture()
  local f={now=0,inputs={},writes=0}
  f.g=Garden.new({now=function()return f.now end,publish=function()f.writes+=1 end,validFocus=function()return true end})
  for id=1,3 do
   local slot=if id==1 then Layout.ToyWest else Layout.ToyEast
   f.inputs[id]={alive=true,owned=true,mode="Room",petId=if id==1 then "pip"else "puddle",characterId=1,petGeneration=1,
    position=slot+Vector3.new(0,3,0),anchor=slot,yaw=0}
  end
  f.g:sync(f.inputs)
  function f:packet(id,kind,seq,actionId)
   local a=self.g.actors[id];return{kind=kind,seq=seq,actionId=actionId,petId=a.petId,characterId=a.characterId,petGeneration=a.petGeneration,actorGeneration=a.generation}
  end
  function f:request(id,kind,seq,actionId)return self.g:toyRequest(id,self:packet(id,kind,seq,actionId))end
  function f:step(dt)self.now+=dt;self.g:step(dt,self.inputs)end
  function f:autonomous(stage)
   for id=2,3 do self.inputs[id].mode="Board"end;self.g:sync(self.inputs)
   self.now=4;self.g:decide();assert(self.g.toy.ownerId==1 and self.g.actors[1].behavior=="investigate")
   if stage=="shove"then self.now=self.g.actors[1].endTime+.01;self.g:decide();self.now+=.37;assert(self.g.actors[1].action=="shove")end
   self.inputs[2].mode="Room";self.g:syncOne(2,self.inputs[2])
   return self.g.toy,self.g.actors[1]
  end
  return f
 end
 test("start reserves one identity and exact retry never replans it",function()
  local f=fixture();local packet=f:packet(1,"toyStart",1)
  local first,changed=f.g:toyRequest(1,packet);assert(first.status=="Started"and changed)
  local action=f.g.toy.returnAction;local generation=f.g.actors[1].generation
  local second,again=f.g:toyRequest(1,packet)
  assert(second==first and not again and f.g.toy.returnAction==action and f.g.actors[1].generation==generation)
  packet.kind,packet.actionId="toyCancel",first.actionId;assert(f.g:toyRequest(1,packet).reason=="SeqConflict")
 end)
 test("competing start or third participant cannot displace the reservation",function()
  local f=fixture();local first=f:request(1,"toyStart",1)
  assert(f:request(2,"toyStart",1).reason=="Busy")
  assert(f:request(2,"toyJoin",2,first.actionId).status=="Joined")
  assert(f:request(3,"toyJoin",1,first.actionId).status=="Rejected")
  local a=f.g.toy.returnAction;assert(a.starterId==1 and a.receiverId==2 and a.id==first.actionId)
  assert(f.g.actors[1].actionId==a.id and f.g.actors[2].actionId==a.id)
 end)
 test("join binds identity generations and starts only when both validated approaches are ready",function()
  local f=fixture();local first=f:request(1,"toyStart",1)
  local forged=f:packet(2,"toyJoin",1,first.actionId);forged.petGeneration=0
  assert(f.g:toyRequest(2,forged).status=="Rejected")
  forged=f:packet(2,"toyJoin",2,first.actionId);forged.actorGeneration-=1
  assert(f.g:toyRequest(2,forged).status=="Rejected")
  assert(f:request(2,"toyJoin",3,first.actionId).status=="Joined")
  local a=f.g.toy.returnAction
  assert(a.id==first.actionId and a.startTime==math.max(a.starterReady,a.receiverReady,f.now)and a.endTime==a.startTime+5)
 end)
 test("join deadline expires into solo without creating rewards or a second action",function()
  local f=fixture();local first=f:request(1,"toyStart",1)
  f:step(3);assert(f.g.toy.returnAction.state=="solo")
  assert(f:request(2,"toyJoin",1,first.actionId).status=="Rejected")
  f:step(8);assert(not f.g.toy.returnAction and f.g.actors[1].toyActionId==nil)
 end)
 test("unrelated or stale cancellation cannot reset a current or reused return",function()
  local f=fixture();local first=f:request(1,"toyStart",1)
  assert(f:request(3,"toyCancel",1,first.actionId).status=="Rejected")
  assert(f:request(1,"toyCancel",2,first.actionId).status=="Cancelled")
  local second=f:request(1,"toyStart",3);assert(second.status=="Started"and second.actionId~=first.actionId)
  assert(f:request(1,"toyCancel",4,first.actionId).status=="Rejected")
  assert(f.g.toy.returnAction.id==second.actionId)
 end)
 test("focus releases both toy participants while preserving unrelated actors",function()
  local f=fixture();local first=f:request(1,"toyStart",1);assert(f:request(2,"toyJoin",1,first.actionId).status=="Joined")
  local third=f.g.actors[3];local generation=third.generation
  assert(f.g:focus(2,{kind="focus",seq=1,petId="puddle",characterId=1,petGeneration=1}))
  assert(not f.g.toy.returnAction and not f.g.actors[1].toyActionId and f.g.actors[2].mode=="Focus")
  assert(third.generation==generation)
 end)
 test("leave, bench mode, equip and character replacement retire only their action",function()
  for _,change in ipairs({"leave","bench","equip","character"})do
   local f=fixture();local first=f:request(1,"toyStart",1);f:request(2,"toyJoin",1,first.actionId)
   if change=="leave"then f.inputs[2]=nil
   elseif change=="bench"then f.inputs[2].mode="Board"
   elseif change=="equip"then f.inputs[2].petGeneration=2;f.inputs[2].petId="wick"
   else f.inputs[2].characterId=2 end
   f.g:sync(f.inputs)
   assert(not f.g.toy.returnAction and not f.g.actors[1].toyActionId,change)
  end
 end)
 test("late observer samples exact semantic travel even under reduced effects",function()
  local f=fixture();local first=f:request(1,"toyStart",1);f:request(2,"toyJoin",1,first.actionId)
  local toy=f.g:snapshot().toy;local a=toy.returnAction
  local near,far=Activity.vector(a.near),Activity.vector(a.far)
  local sending=Activity.sampleToy(toy,a.startTime+1.25)
  local receiving=Activity.sampleToy(toy,a.startTime+2.25)
  local returned=Activity.sampleToy(toy,a.startTime+4.5)
  assert((receiving.basePosition-far).Magnitude<.001 and(returned.basePosition-near).Magnitude<.001)
  assert((sending.basePosition-near).Magnitude>.2 and(sending.basePosition-far).Magnitude>.2)
  assert((Activity.sampleToy(toy,a.startTime+1.25).basePosition-sending.basePosition).Magnitude<1e-9)
  assert(#game:GetService("HttpService"):JSONEncode(f.g:snapshot())<10000)
 end)
 test("invalid reach and nonfinite commands cannot acquire the toy",function()
  local f=fixture();f.inputs[1].position+=Vector3.new(20,0,0)
  assert(f:request(1,"toyStart",1).status=="Rejected"and not f.g.toy.returnAction)
  local packet=f:packet(2,"toyStart",0/0);assert(f.g:toyRequest(2,packet).status=="Rejected")
  assert(f.g:toyRequest(2,{}).status=="Rejected")
 end)
 test("automatic solo and greeting decisions cannot steal the reserved toy actors",function()
  local f=fixture();local first=f:request(1,"toyStart",1);f:request(2,"toyJoin",1,first.actionId)
  local finish=f.g.toy.returnAction.endTime
  while f.now<finish-.01 do f:step(math.min(.5,finish-.01-f.now));assert(f.g.toy.returnAction.id==first.actionId)
   assert(f.g.actors[1].actionId==first.actionId and f.g.actors[2].actionId==first.actionId)
  end
  f:step(.51);assert(not f.g.toy.returnAction)
 end)
 test("a stale retired actor cannot release a newer shared return for the same owner",function()
  local f=fixture();local old=table.clone(f.g.actors[1]);local first=f:request(1,"toyStart",1)
  old.toyActionId=first.actionId-1;old.toyReservation=first.actionId-1
  f.g:release(old)
  assert(f.g.toy.returnAction and f.g.toy.returnAction.id==first.actionId)
 end)
 test("validated manual Start preempts exact investigating or shoving solo and preserves both ball presentations",function()
  for _,stage in ipairs({"investigate","shove"})do
   local f=fixture();local old,oldActor=f:autonomous(stage)
   local before=Activity.sampleToy(old,f.now);local oldPosition=f.g:position(oldActor,f.now)
   local result=f:request(2,"toyStart",1);assert(result.status=="Started")
   assert(f.g.toy.returnAction.starterId==2 and oldActor.behavior=="follow"and not oldActor.toyReservation)
   assert((f.g:position(oldActor,f.now)-oldPosition).Magnitude<1e-5,"preemption moved the other root")
   local after=Activity.sampleToy(f.g.toy,f.now)
   assert((after.position-before.position).Magnitude<1e-5 and(after.basePosition-before.basePosition).Magnitude<1e-5)
   assert(math.abs(after.tilt-before.tilt)<1e-8 and math.abs(after.rotation-before.rotation)<1e-8)
  end
 end)
 test("failed incoming path or reach leaves autonomous reservation and actors untouched",function()
  for _,failure in ipairs({"path","reach"})do
   local f=fixture();local old,oldActor=f:autonomous("shove");local generation=oldActor.generation;local requester=f.g.actors[2];local incomingGeneration=requester.generation
   if failure=="path"then f.g.options.validToyPath=function()return false end else f.inputs[2].position+=Vector3.new(20,0,0)end
   local result=f:request(2,"toyStart",1);assert(result.status=="Rejected")
   assert(f.g.toy==old and oldActor.generation==generation and oldActor.action=="shove"and requester.generation==incomingGeneration)
  end
 end)
 test("autonomous owner may start a manual return and another Start cannot replace it",function()
  local f=fixture();f:autonomous("shove");local result=f:request(1,"toyStart",1);assert(result.status=="Started")
  local action=f.g.toy.returnAction;assert(f:request(2,"toyStart",1).reason=="Busy"and f.g.toy.returnAction==action)
 end)
 test("manual priority cannot cancel a greeting or borrow its participant",function()
  local f=fixture();f.now=.5;f.g:decide();local a,b=f.g.actors[1],f.g.actors[2]
  assert(a.action=="greet"and a.pairId==b.pairId);local pair=a.pairId;local generation=a.generation
  assert(f:request(1,"toyStart",1).reason=="Busy")
  assert(a.pairId==pair and b.pairId==pair and a.generation==generation and not f.g.toy.returnAction)
 end)
 test("stale solo completion and exact manual retry cannot reset or replan the new return",function()
  local f=fixture();local old,oldActor=f:autonomous("shove");local stale=table.clone(oldActor)
  local packet=f:packet(2,"toyStart",1);local first=f.g:toyRequest(2,packet);local action=f.g.toy.returnAction
  f.g:release(stale);assert(f.g.toy.returnAction==action)
  local generation=f.g.actors[2].generation
  assert(f.g:toyRequest(2,packet)==first and f.g.toy.returnAction==action and f.g.actors[2].generation==generation)
 end)
 test("a mismatched autonomous token or identity is never eligible for manual retirement",function()
  for _,failure in ipairs({"token","identity"})do
   local f=fixture();local old,oldActor=f:autonomous("investigate");local generation=oldActor.generation
   if failure=="token"then oldActor.toyReservation+=1 else f.inputs[1].petGeneration+=1 end
   assert(f:request(2,"toyStart",1).reason=="Busy"and f.g.toy==old and oldActor.generation==generation)
  end
 end)
 test("handoff pickup ends at the regular rest position even for delayed observers",function()
  local f=fixture();f:autonomous("shove");f:request(2,"toyStart",1);local a=f.g.toy.returnAction
  assert((Activity.sampleToy(f.g.toy,a.endTime).position-Layout.Toy).Magnitude<1e-6)
  assert((Activity.sampleToy(f.g.toy,a.endTime+100).basePosition-Layout.Toy).Magnitude<1e-6)
 end)
 test("a joining pet cannot tear down an unrelated greeting or the waiting manual return",function()
  local f=fixture();local first=f:request(1,"toyStart",1);local action=f.g.toy.returnAction
  f.now=.1;f.g:greeting(f.now,{f.g.actors[2],f.g.actors[3]})
  local second,third=f.g.actors[2],f.g.actors[3];local pair=second.pairId;local generation=second.generation
  assert(pair and pair==third.pairId and second.action=="greet")
  assert(f:request(2,"toyJoin",1,first.actionId).reason=="Busy")
  assert(second.pairId==pair and third.pairId==pair and second.generation==generation)
  assert(f.g.toy.returnAction==action and action.state=="waiting"and not action.receiverId and not action.participants["2"])
 end)
 local function place(f,id,position,yaw)
  local a=f.g.actors[id];a.from,a.to=Activity.pack(position),Activity.pack(position);a.path=nil;a.startTime,a.endTime=f.now,f.now+.5;a.yaw=yaw or 0
 end
 test("ready nearby partners start promptly without waiting the full solo join window",function()
  local f=fixture();local first=f:request(1,"toyStart",1);local action=f.g.toy.returnAction
  assert(action.joinUntil==3 and action.startTime==3)
  f.now=.1;assert(f:request(2,"toyJoin",1,first.actionId).status=="Joined")
  assert(action.startTime<1 and action.startTime>=action.starterReady and action.startTime>=action.receiverReady and action.endTime==action.startTime+5)
  for _,id in ipairs({1,2})do
   local a=f.g.actors[id];local p=action.participants[tostring(id)];local pose=Activity.sample(a,action.startTime)
   assert((pose.position-Activity.vector(p.slot)).Magnitude<1e-5 and pose.velocity.Magnitude<1e-5 and a.endTime==action.endTime and a.toyStartTime==action.startTime)
  end
 end)
 test("a valid seven-stud solo approach waits for its pet instead of rejecting a normal start",function()
  local f=fixture();place(f,1,Layout.ToyWest+Vector3.new(0,0,7),math.pi)
  local first=f:request(1,"toyStart",1);assert(first.status=="Started")
  local a=f.g.toy.returnAction;assert(a.starterReady>3 and a.starterReady<=8 and a.startTime==a.starterReady and a.endTime==a.startTime+5)
  f.now=3;f.g:decide();assert(a.state=="solo"and f.g.toy.returnAction==a)
  local pose=Activity.sample(f.g.actors[1],a.startTime);assert((pose.position-Activity.vector(a.near)).Magnitude<1e-5 and pose.velocity.Magnitude<1e-5)
 end)
 test("last-moment seven-stud join retimes both holds atomically with no root or ball jump",function()
  local f=fixture();place(f,1,Layout.ToyWest+Vector3.new(0,0,7),math.pi);place(f,2,Layout.ToyEast+Vector3.new(0,0,7),math.pi)
  local first=f:request(1,"toyStart",1);assert(first.status=="Started")
  local a=f.g.toy.returnAction;local created=a.createdTime;f.now=a.joinUntil-.01
  local ball=Activity.sampleToy(f.g.toy,f.now);local root=Activity.sample(f.g.actors[1],f.now)
  local packet=f:packet(2,"toyJoin",1,first.actionId);local result=f.g:toyRequest(2,packet);assert(result.status=="Joined")
  assert(a.createdTime==created and a.pickupTime==f.now and a.startTime<=created+11 and a.receiverReady<=f.now+8 and a.startTime==math.max(a.starterReady,a.receiverReady,f.now))
  local after=Activity.sampleToy(f.g.toy,f.now);local rootAfter=Activity.sample(f.g.actors[1],f.now)
  assert((after.position-ball.position).Magnitude<1e-5 and(after.basePosition-ball.basePosition).Magnitude<1e-5 and math.abs(after.tilt-ball.tilt)<1e-8 and math.abs(after.rotation-ball.rotation)<1e-8)
  assert((root.position-rootAfter.position).Magnitude<1e-5 and(root.velocity-rootAfter.velocity).Magnitude<1e-5 and math.abs(root.yaw-rootAfter.yaw)<1e-6)
  for _,id in ipairs({1,2})do local actor=f.g.actors[id];assert(actor.endTime==a.endTime and actor.toyStartTime==a.startTime);local pose=Activity.sample(actor,a.startTime);assert((pose.position-Activity.vector(a.participants[tostring(id)].slot)).Magnitude<1e-5 and pose.velocity.Magnitude<1e-5)end
  local start,finish=a.startTime,a.endTime;assert(f.g:toyRequest(2,packet)==result and a.startTime==start and a.endTime==finish)
  assert((Activity.sampleToy(f.g.toy,a.startTime+2.25).basePosition-Activity.vector(a.far)).Magnitude<1e-5)
 end)
 test("join immediately before deadline preserves pickup pose while exact-deadline join rejects",function()
  local f=fixture();local first=f:request(1,"toyStart",1);local a=f.g.toy.returnAction;f.now=a.joinUntil-.001
  local before=Activity.sampleToy(f.g.toy,f.now);assert(f:request(2,"toyJoin",1,first.actionId).status=="Joined")
  assert((Activity.sampleToy(f.g.toy,f.now).position-before.position).Magnitude<1e-5 and a.startTime>=f.now)
  local second=fixture();local saved=second:request(1,"toyStart",1);local action=second.g.toy.returnAction;second.now=action.joinUntil
  assert(second:request(2,"toyJoin",1,saved.actionId).reason=="NotJoinable"and not action.receiverId and action.startTime==3)
 end)
 return{passed=#cases,cases=cases}
end
