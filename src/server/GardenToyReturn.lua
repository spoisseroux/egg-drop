-- One finite server-owned return reservation. No tasks, profile or reward access.
local Shared=game:GetService("ReplicatedStorage").Shared
local A=require(Shared.GardenActivity);local L=require(Shared.GardenLayout)
local Toy={}
local function integer(n)return type(n)=="number"and n==n and n%1==0 and n>=1 and n<=2147483647 end
local fields={"kind","seq","actionId","petId","characterId","petGeneration","actorGeneration"}
local function same(a,b)for _,key in ipairs(fields)do if a[key]~=b[key]then return false end end;return true end
local function horizontal(a,b)return Vector2.new(a.X-b.X,a.Z-b.Z).Magnitude end
local function result(packet,status,id,reason)return{kind=packet.kind,seq=packet.seq,status=status,actionId=id,reason=reason}end
function Toy.replay(g,owner,packet)
 local previous=g.toyRequests and g.toyRequests[owner]
 if type(packet)~="table"or not previous or not integer(packet.seq)or packet.seq>previous.packet.seq then return nil end
 if packet.seq==previous.packet.seq and same(packet,previous.packet)then return previous.result end
 return result(packet,"Rejected",packet.actionId,if packet.seq==previous.packet.seq then "SeqConflict"else "Stale")
end
function Toy.release(g,id,excluded)
 local action=g.toy.returnAction
 if not action or action.id~=id then return false end
 g.toy={position=A.pack(L.Toy)};g.dirty=true
 for key,participant in pairs(action.participants)do
  local owner=tonumber(key);local actor,input=g.actors[owner],g.inputs[owner]
  if actor and actor.toyActionId==id then
   actor.toyActionId,actor.toyRole,actor.toyStartTime=nil,nil,nil
   if owner~=excluded and actor.generation==participant.generation and input then
    actor.idleSince=g.options.now();g:transition(actor,if input.mode=="Board"then "rest"else "follow",input.anchor,.5)
   end
  end
 end
 return true
end
local function approach(g,actor,slot,faceTo)
 local now=g.options.now();local sample=A.sample(actor,now)
 local from=sample and sample.position or g.inputs[actor.ownerId].anchor
 local path,duration=A.plan(from,slot,sample and sample.velocity or Vector3.zero,L.StrollSpeed,0,sample and sample.yaw or actor.yaw or 0)
 if horizontal(from,slot)>7 then return nil end
 if g.options.validToyPath and not g.options.validToyPath(path,g.inputs[actor.ownerId])then return nil end
 local final=A.sample({from=A.pack(from),to=A.pack(slot),path=path,startTime=0,endTime=duration,yaw=sample and sample.yaw or 0},duration)
 local direction=faceTo-slot;local heading=math.atan2(direction.X,direction.Z)
 local delta=(heading-final.yaw+math.pi)%(2*math.pi)-math.pi
 local turnDuration=if math.abs(delta)>.01 then math.max(.12,math.abs(delta)*1.5/12)else 0
 if duration+turnDuration>8 then return nil end
 return{path=path,duration=duration,readyDuration=duration+turnDuration,from=from,yaw=sample and sample.yaw or actor.yaw or 0,
  arrivalYaw=final.yaw,heading=heading,turn=delta,turnDuration=turnDuration}
end
local function occupy(g,actor,slot,action,plan)
 g:release(actor)
 actor.generation+=1;actor.behavior,actor.action="play","toyReturn"
 actor.actionId,actor.toyActionId=action.id,action.id
 actor.toyRole,actor.toyStartTime=if slot==A.vector(action.near)then "starter"else "receiver",action.startTime
 actor.startTime,actor.endTime=g.options.now(),action.endTime
 actor.from,actor.to,actor.via=A.pack(plan.from),A.pack(slot),nil
 actor.yaw,actor.path,actor.peerId=plan.yaw,plan.path,nil
 if plan.turnDuration>0 then
  table.insert(actor.path,{from=A.pack(slot),to=A.pack(slot),v0=A.pack(Vector3.zero),v1=A.pack(Vector3.zero),duration=plan.turnDuration,yaw=plan.arrivalYaw,turn=plan.turn,turnDuration=plan.turnDuration,pivot=true})
 end
 local remaining=action.endTime-g.options.now()-plan.readyDuration
 table.insert(actor.path,{from=A.pack(slot),to=A.pack(slot),v0=A.pack(Vector3.zero),v1=A.pack(Vector3.zero),duration=remaining,yaw=plan.heading,turn=0,turnDuration=0})
 action.participants[tostring(actor.ownerId)]={petId=actor.petId,characterId=actor.characterId,petGeneration=actor.petGeneration,generation=actor.generation,slot=A.pack(slot),readyAt=g.options.now()+plan.readyDuration}
 g.dirty=true
end
local function pickup(action,sample,now)
 action.pickupTime=now
 action.initialPosition=sample and A.pack(sample.position)
 action.initialBasePosition=sample and A.pack(sample.basePosition)
 action.initialTilt,action.initialRotation=sample and sample.tilt or 0,sample and sample.rotation or 0
end
local function retime(g,action,start,now,sample)
 local finish=start+5;local delta=finish-action.endTime
 -- A waiting participant always has a final zero-velocity hold. Only its
 -- duration changes; no already-walked leg, root position or yaw is rebased.
 for key in pairs(action.participants)do
  local actor=g.actors[tonumber(key)];local hold=actor.path[#actor.path]
  hold.duration+=delta;actor.endTime,actor.toyStartTime=finish,start
 end
 pickup(action,sample,now)
 action.startTime,action.endTime=start,finish
 g.toy.startTime,g.toy.endTime=start,finish
 g.dirty=true
end
function Toy.request(g,owner,packet)
 packet=if type(packet)=="table"then packet else {}
 local actor,input=g.actors[owner],g.inputs[owner]
 local function reject(reason)return result(packet,"Rejected",packet.actionId,reason),false end
 if not integer(packet.seq)or(packet.kind~="toyStart"and packet.kind~="toyJoin"and packet.kind~="toyCancel")then return reject("Malformed")end
 if not integer(packet.actorGeneration)or(packet.kind=="toyStart"and packet.actionId~=nil)or(packet.kind~="toyStart"and not integer(packet.actionId))then return reject("Malformed")end
 local replay=Toy.replay(g,owner,packet);if replay then return replay,false end
 if not actor or not input or not input.alive or not input.owned or input.mode~="Room"or actor.mode~="Room"
  or packet.petId~=actor.petId or packet.petId~=input.petId or packet.characterId~=actor.characterId or packet.characterId~=input.characterId
  or packet.petGeneration~=actor.petGeneration or packet.petGeneration~=(input.petGeneration or 0)then return reject("IdentityChanged")end
 g.toyRequests=g.toyRequests or {};local previous=g.toyRequests[owner]
 local function finish(status,id,reason,changed)
  local reply=result(packet,status,id,reason);local capture={}
  for _,key in ipairs(fields)do capture[key]=packet[key]end
  g.toyRequests[owner]={packet=capture,result=reply};return reply,changed==true
 end
 if packet.actorGeneration~=actor.generation then return finish("Rejected",packet.actionId,"GenerationChanged")end
 local now=g.options.now();local action=g.toy.returnAction
 if packet.kind=="toyCancel"then
  local participant=action and action.participants[tostring(owner)]
  if not action or packet.actionId~=action.id or not participant or participant.generation~=actor.generation then return finish("Rejected",packet.actionId,"ActionChanged")end
  Toy.release(g,action.id);return finish("Cancelled",action.id,nil,true)
 end
 if actor.pairId or actor.action=="greet"then return finish("Rejected",packet.actionId,"Busy")end
 if horizontal(input.position,L.Toy)>7 or math.abs(input.position.Y-L.Toy.Y)>6 then return finish("Rejected",packet.actionId,"OutOfReach")end
 if packet.kind=="toyStart"then
  if action then return finish("Rejected",nil,"Busy")end
  local oldToy,oldActor,oldGeneration
  if g.toy.ownerId then
   oldToy=g.toy;oldActor=g.actors[oldToy.ownerId];local oldInput=g.inputs[oldToy.ownerId]
   if(oldToy.kind~=nil and oldToy.kind~="solo")or not integer(oldToy.reservation)or not oldActor or not oldInput or not oldInput.alive or not oldInput.owned or oldInput.mode~="Room"
    or oldActor.mode~="Room"or oldActor.pairId or oldActor.toyActionId or oldActor.toyReservation~=oldToy.reservation
    or oldActor.petId~=oldInput.petId or oldActor.characterId~=oldInput.characterId or oldActor.petGeneration~=(oldInput.petGeneration or 0)
    or not((oldActor.behavior=="investigate"and oldActor.action==nil)or(oldActor.behavior=="play"and oldActor.action=="shove"and oldToy.actionId==oldActor.actionId))then return finish("Rejected",nil,"Busy")end
   oldGeneration=oldActor.generation
  end
  local position=g:position(actor,now)
  local near,far=L.ToyWest,L.ToyEast
  if horizontal(position,far)<horizontal(position,near)then near,far=far,near end
  local plan=approach(g,actor,near,far)
  if not plan then return finish("Rejected",nil,"ApproachBlocked")end
  -- A validated explicit action has priority over exactly this autonomous
  -- reservation. Nothing is retired until the incoming identity/slots/path fit.
  if oldToy and(g.toy~=oldToy or oldActor.generation~=oldGeneration or oldActor.toyReservation~=oldToy.reservation)then return finish("Rejected",nil,"Busy")end
  local initial=A.sampleToy(g.toy,now)
  if oldToy then
   g:release(oldActor)
   if oldActor~=actor then
    oldActor.idleSince,oldActor.nextWanderAt=now,now+7
    g:transition(oldActor,"follow",g.inputs[oldActor.ownerId].anchor,.5)
   end
  end
  local id=g:token()
  local ready=now+plan.readyDuration;local start=math.max(now+3,ready)
  action={id=id,state="waiting",starterId=owner,joinUntil=now+3,startTime=start,endTime=start+5,starterReady=ready,
   createdTime=now,near=A.pack(near),far=A.pack(far),participants={}}
  pickup(action,initial,now)
  occupy(g,actor,near,action,plan)
  g.toy={kind="return",position=A.pack(L.Toy),ownerId=owner,reservation=id,actionId=id,returnAction=action,startTime=action.startTime,endTime=action.endTime}
  return finish("Started",id,nil,true)
 end
 if not action or packet.actionId~=action.id or action.state~="waiting"or action.receiverId or action.starterId==owner or now>=action.joinUntil then return finish("Rejected",packet.actionId,"NotJoinable")end
 -- Fresh host sync validates both halves immediately, not only at the next2Hz tick.
 for key,participant in pairs(action.participants)do
  local a,i=g.actors[tonumber(key)],g.inputs[tonumber(key)]
  if not a or not i or not i.alive or i.mode~="Room"or a.generation~=participant.generation or a.characterId~=participant.characterId or a.petGeneration~=participant.petGeneration then
   Toy.release(g,action.id);return finish("Rejected",packet.actionId,"ActionChanged",true)
  end
 end
 local far=A.vector(action.far);local plan=approach(g,actor,far,A.vector(action.near))
 if not plan then return finish("Rejected",action.id,"ApproachBlocked")end
 if g.toy.returnAction~=action then return finish("Rejected",action.id,"ActionChanged")end
 local sample=A.sampleToy(g.toy,now)
 action.receiverReady=now+plan.readyDuration
 retime(g,action,math.max(action.starterReady,action.receiverReady,now),now,sample)
 occupy(g,actor,far,action,plan);action.receiverId,action.state=owner,"paired"
 local starter=g.actors[action.starterId];starter.peerId,actor.peerId=owner,action.starterId
 return finish("Joined",action.id,nil,true)
end
function Toy.step(g,now)
 local action=g.toy.returnAction;if not action then return end
 for key,p in pairs(action.participants)do
  local a,input=g.actors[tonumber(key)],g.inputs[tonumber(key)]
  if not a or not input or not input.alive or not input.owned or input.mode~="Room"or a.mode~="Room"or a.toyActionId~=action.id or a.generation~=p.generation
   or a.characterId~=p.characterId or a.petGeneration~=p.petGeneration or a.petId~=p.petId then Toy.release(g,action.id);return end
 end
 if now>=action.endTime then Toy.release(g,action.id);return end
 if action.state=="waiting"and now>=action.joinUntil then action.state="solo";g.dirty=true end
end
return Toy
