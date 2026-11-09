-- Actual host/coordinator and actual placement geometry. No live players, stores,
-- production remotes or synthetic reward input. Native Server invocation:
-- require(spec)(serverFolder, serverFolder.GardenCareHost.Source)
return function(server,hostSource)
 assert(type(hostSource)=="string","pass current GardenCareHost.Source")
 local Shared=game:GetService("ReplicatedStorage").Shared
 local Garden=require(server.GardenState);local A=require(Shared.GardenActivity)
 local L=require(Shared.GardenCareLayout);local Placement=require(server.GardenCarePlacement)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function copy(value)if type(value)~="table"then return value end;local t={};for k,v in pairs(value)do t[k]=copy(v)end;return t end
 local function hostClass(f)
  local module=Instance.new("ModuleScript");module.Name="_CareHostSource"
  module.Source="return function(e) local workspace,Instance,os,task,script=e.workspace,e.Instance,e.os,e.task,e.script\n"..hostSource.."\nend"
  module.Parent=server
  local ok,factory=pcall(require,module);module:Destroy();assert(ok,factory)
  return factory({script=server.GardenCareHost,workspace={GetServerTimeNow=function()return f.now end},
   os={clock=function()return f.now end},task={defer=function(callback,...)table.insert(f.deferred,{callback=callback,args={...}})end},
   Instance={new=function(class)
    assert(class=="RemoteEvent","unexpected host allocation")
    return {FireClient=function(_,player,packet)table.insert(f.results,{player=player,packet=packet})end}
   end}})
 end
 local function fixture()
  local f={now=100,dry=true,dockClear=true,results={},deferred={},boards={},inputs={},byId={},seq={},inputCalls=0,publishes=0,stageCalls=0}
  f.garden=Garden.new({now=function()return f.now end})
  local progress={}
  function progress.stageCompanion(profile,pet,id,fence)
   if profile.companionChange then return nil,"Busy"end
   f.stageCalls+=1
   local c={petId=pet.id,id=id,fence=fence};profile.companionChange=c;return c
  end
  function progress.flushOnce()return false,"Injected pending durable outcome"end
  for id=1,2 do
   local player={UserId=id};local board={player=player,mode="Room",companionGeneration=1,publishedCompanionId="pip",
    profile={companionId="pip"},nursery={state={revision=3,inventoryMask=127,nectar=24,hueInventory={rose=2}},epoch=1,token="lease-"..id,
     adapter={now=function()return f.now end}}}
   f.boards[player]=board;f.byId[id]=board
   local point=L.Approach+Vector3.new((id-1)*2,0,0)
   f.inputs[id]={alive=true,owned=true,petId="pip",characterId=id,petGeneration=1,mode="Room",position=point,anchor=point,carryPosition=point+Vector3.new(0,1,0),yaw=0}
  end
  local d={garden=f.garden,boards=f.boards,progress=progress,remotes={FindFirstChild=function()return nil end},
   canProgress=function(board)return not board.unavailable end,inventory=function(board)return board.nursery.state.inventoryMask end,
   place=function(input)return if f.dry then input.anchor else nil end,validDock=function()return f.dockClear end,
   publishCompanion=function(board)
    f.publishes+=1
    if board.profile.companionId~=board.publishedCompanionId then board.companionGeneration+=1;board.publishedCompanionId=board.profile.companionId end
   end,
   gardenInput=function(board)
    f.inputCalls+=1;local input=f.inputs[board.player.UserId]
    input.petId=board.profile.companionId;input.petGeneration=board.companionGeneration;input.mode=board.mode
    input.alive=not board.closing;return input
   end}
  f.host=hostClass(f).new(d);f.garden:sync(f.inputs)
  function f:packet(id,kind,extra)
   self.seq[id]=(self.seq[id]or 0)+1;local a=self.garden.actors[id]
   local p={kind=kind,seq=self.seq[id],petId=a.petId,characterId=a.characterId,petGeneration=a.petGeneration,actorGeneration=a.generation,
    claimId=a.care and a.care.claimId,revision=self.byId[id].nursery.state.revision}
   for k,v in pairs(extra or {})do p[k]=v end;return p
  end
  function f:deliver(id,packet,advance)
   self.now+=advance or 0;local before=#self.results;self.host:request(self.byId[id],packet)
   return if #self.results>before then self.results[#self.results].packet else nil
  end
  function f:request(id,kind,extra)
   local packet=self:packet(id,kind,extra);return self:deliver(id,packet,.2),packet
  end
  function f:dock(id)
   assert(self:request(id,"carePickup").status=="Accepted")
   local response=self:request(id,"carePlace");assert(response.status=="Accepted",response.reason);return response.claimId
  end
  function f:commit(id,status)
   local profile=self.byId[id].profile;local c=assert(profile.companionChange,"expected staged candidate")
   profile.companionChange=nil
   if status=="Rejected"then profile.onCompanionRejected(c)
   else profile.companionId=c.petId;profile.onCompanionSaved(c)end
  end
  return f
 end
 test("cheap malformed requests never scan actor input or consume the valid request lane",function()
  local f=fixture();local base=f:packet(1,"carePickup");local before=f.inputCalls
  for _,bad in ipairs({{kind="careUnknown",seq=1},{kind="carePickup",seq=0},{kind="carePickup",seq=math.huge},
   {kind="carePickup",seq=0/0},copy(base),copy(base)})do
   if bad==nil then error("fixture")end
   if bad.petId then bad[if bad.seq==base.seq and bad.characterId then "characterId"else "actorGeneration"]=math.huge end
   assert(f:deliver(1,bad)==nil)
  end
  assert(f.inputCalls==before and #f.results==0 and not f.byId[1].careRequestAt)
  assert(f:deliver(1,base).status=="Accepted")
 end)
 test("exact accepted replay and sequence conflict precede throttling and resampling",function()
  local f=fixture();local accepted,p=f:request(1,"carePickup");local a=f.garden.actors[1];local generation=a.generation;local calls=f.inputCalls
  f.byId[1].unavailable=true
  assert(f:deliver(1,p)==accepted,"exact replay became throttle/availability rejection")
  local conflict=copy(p);conflict.kind="carePlace"
  assert(f:deliver(1,conflict).reason=="SequenceConflict")
  assert(a.generation==generation and f.inputCalls==calls)
 end)
 test("fresh intent flood is bounded before actor scans; later exact fresh retry can act",function()
  local f=fixture();f:request(1,"carePickup");local calls=f.inputCalls;local p=f:packet(1,"careSetDown")
  for _=1,20 do assert(f:deliver(1,p).reason=="Throttled")end
  assert(f.inputCalls==calls and f.garden.actors[1].mode=="Carried")
  assert(f:deliver(1,p,.11).status=="Accepted"and f.garden.actors[1].mode=="Placed")
 end)
 test("pulse rate has an independent bounded lane and cannot evict another claim",function()
  local f=fixture();local claim=f:dock(1);local first=f:packet(1,"carePulse")
  assert(f:deliver(1,first).status=="Accepted");local calls=f.inputCalls
  assert(f:deliver(1,f:packet(1,"carePulse"),.01).reason=="Throttled"and f.inputCalls==calls)
  local wrong=f:packet(2,"carePulse",{claimId=claim})
  assert(f:deliver(2,wrong).reason=="ClaimChanged"and f.host.care.bay.id==claim)
 end)
 test("unsafe deliberate setdown keeps dock but system close releases it to safe held state",function()
  local f=fixture();local claim=f:dock(1);f.dry=false
  local refused=f:request(1,"careSetDown");assert(refused.reason=="NoDrySpace"and f.host.care.bay.id==claim)
  local released=f:request(1,"careRelease");assert(released.status=="Accepted"and not f.host.care.bay)
  assert(f.garden.actors[1].mode=="Carried"and f.garden.actors[1].care.claimId==nil)
  local newer=f:dock(2);assert(newer~=claim and f.host.care.bay.ownerId==2)
 end)
 test("late verified equip over unsafe ground cannot reclaim another owner's bay or use wet anchor",function()
  local f=fixture();f:dock(1);assert(f:request(1,"careEquip",{targetId="orbit"}).status=="Pending")
  f.now+=4;f.garden:sync(f.inputs);local newer=f:dock(2)
  f.dry=false;f.inputs[1].anchor=Vector3.new(500,4.025,500);local oldActor=f.garden.actors[1]
  f:commit(1)
  assert(f.byId[1].profile.companionId=="orbit"and f.garden.actors[1]==oldActor and oldActor.petId=="orbit")
  assert(oldActor.mode=="Carried","no dry placement must retain a safe hold")
  assert(f.host.care.bay.id==newer and f.host.care.bay.ownerId==2)
  assert(A.vector(oldActor.to)~=f.inputs[1].anchor,"unsafe anchor became following truth")
 end)
 test("ordinary shortcut uses the same staged save and safe held fallback",function()
  local f=fixture();local board=f.byId[1];f.dry=false
  assert(f.host:switch(board,"orbit")and board.profile.companionId=="pip"and board.careEquip)
  assert(not f.host:switch(board,"wick"),"parallel shortcut bypassed staged candidate")
  f:commit(1)
  assert(board.profile.companionId=="orbit"and f.garden.actors[1].petId=="orbit"and f.garden.actors[1].mode=="Carried")
 end)
 test("exact live bay keeps one actor through saved equip; uncommitted failure preserves original",function()
  for _,status in ipairs({"Saved","Rejected"})do
   local f=fixture();local claim=f:dock(1);local a=f.garden.actors[1]
   assert(f:request(1,"careEquip",{targetId="orbit"}).status=="Pending")
   f:commit(1,status)
   assert(f.garden.actors[1]==a and a.mode=="Docked"and f.host.care.bay.id==claim)
   assert(a.petId==(if status=="Saved"then "orbit"else "pip"))
  end
 end)
 test("pending equip proof survives history compaction and remains replayable after its single commit",function()
  local f=fixture();f:dock(1);local pending,packet=f:request(1,"careEquip",{targetId="orbit"})
  assert(pending.status=="Pending"and f.stageCalls==1)
  assert(f:request(1,"carePickup").status=="Accepted")
  for _=1,17 do
   assert(f:request(1,"careSetDown").status=="Accepted")
   assert(f:request(1,"carePickup").status=="Accepted")
  end
  assert(f:deliver(1,packet).status=="Pending"and f.stageCalls==1,"compaction lost the still-owned pending proof")
  local conflict=copy(packet);conflict.targetId="wick"
  assert(f:deliver(1,conflict).reason=="SequenceConflict"and f.stageCalls==1)
  f:commit(1)
  assert(f:deliver(1,packet).status=="Saved"and f.stageCalls==1,"terminal result was lost after releasing its pending pin")
 end)
 test("replaced or closing board cannot publish a delayed profile callback into current actor",function()
  for _,replacement in ipairs({false,true})do
   local f=fixture();f:dock(1);f:request(1,"careEquip",{targetId="orbit"})
   local board=f.byId[1];local a=f.garden.actors[1];local calls=f.publishes
   if replacement then f.boards[board.player]={player=board.player} else board.closing=true end
   f:commit(1)
   assert(f.publishes==calls and a.petId=="pip","old callback changed a retired board's actor")
  end
 end)
 local function scene(run)
  local room=Instance.new("Model");room.Name="_CarePlacementIntegration";room.Parent=workspace
  local function part(name,size,position,collides)
   local p=Instance.new("Part");p.Name=name;p.Size=size;p.Position=position;p.Anchored=true;p.CanCollide=collides;p.Transparency=1;p.Parent=room;return p
  end
  part("Floor",Vector3.new(160,1,176),Vector3.new(0,3.5,24),true)
  local anchor=Vector3.new(-30,4.025,30);local root=part("FixtureRoot",Vector3.one,anchor+Vector3.new(0,3,0),false)
  local input={root=root,anchor=anchor,yaw=0};local ok,problem=pcall(run,room,part,input,anchor)
  room:Destroy();assert(ok,problem)
 end
 test("actual placement accepts a fully dry supported clear destination",function()
  scene(function(room,_,input)
   local point=Placement.find(input,room,{},{});assert(point and math.abs(point.Y-4.025)<.001)
   assert((point-input.anchor).Magnitude>1 and (point-input.anchor).Magnitude<4)
  end)
 end)
 test("actual wet enclosure cannot turn a safe stationary planner hold into placement across water",function()
  scene(function(room,part,input,anchor)
   local wet={}
   for _,offset in ipairs({Vector3.new(-1.5,0,0),Vector3.new(1.5,0,0),Vector3.new(0,0,-1.5),Vector3.new(0,0,1.5)})do
    local size=if offset.X~=0 then Vector3.new(.2,.1,8)else Vector3.new(8,.1,.2)
    table.insert(wet,part("DecorativeWet",size,anchor+offset,false))
   end
   assert(Placement.find(input,room,wet,{})==nil,"a planner hold is not an arrival at the target")
  end)
 end)
 return {passed=#cases,cases=cases}
end
