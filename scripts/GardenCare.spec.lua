-- Actual transient coordinator + GardenState; no profiles, remotes or scene writes.
return function(server)
 local Garden=require(server.GardenState);local Care=require(server.GardenCare)
 local L=require(game.ReplicatedStorage.Shared.GardenCareLayout)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function fixture()
  local f={now=0,dry=true,equips={},seq={}}
  local g=Garden.new({now=function()return f.now end})
  local care=Care.new(g,{now=function()return f.now end,place=function(input)return if f.dry then input.anchor else nil end,validDock=function()return f.dry end,
   equip=function(id,packet,entry)f.equips[id]=entry;return true end})
  g.care=care;f.g=g;f.care=care
  f.inputs={}
  for id=1,2 do f.inputs[id]={alive=true,owned=true,petId="pip",characterId=id,petGeneration=1,mode="Room",position=L.Approach+Vector3.new((id-1)*2,0,0),anchor=L.Approach+Vector3.new((id-1)*2,0,0),carryPosition=L.Approach+Vector3.new(0,1,0),yaw=0}end
  g:sync(f.inputs)
  function f:packet(id,kind,extra)
   self.seq[id]=(self.seq[id]or 0)+1;local a=self.g.actors[id]
   local p={kind=kind,seq=self.seq[id],petId=a.petId,characterId=a.characterId,petGeneration=a.petGeneration,actorGeneration=a.generation,claimId=a.care and a.care.claimId,revision=3}
   for k,v in pairs(extra or {})do p[k]=v end;return p
  end
  function f:request(id,kind,extra)local p=self:packet(id,kind,extra);return self.care:request(id,p),p end
  function f:dock(id)assert(self:request(id,"carePickup").status=="Accepted");assert(self:request(id,"carePlace").status=="Accepted");return self.care.bay.id end
  return f
 end
 test("forged character pet and actor generations reject without changing the actor",function()
  for key,value in pairs({characterId=999,petId="orbit",petGeneration=99,actorGeneration=99})do
   local f=fixture();local a=f.g.actors[1];local gen=a.generation;local r=f:request(1,"carePickup",{[key]=value})
   assert(r.status=="Rejected"and a.mode=="Room"and a.generation==gen and not f.care.bay)
  end
 end)
 test("pickup preserves one actor and moving owner cannot reset a held pet",function()
  local f=fixture();local a=f.g.actors[1];assert(f:request(1,"carePickup").status=="Accepted")
  f.inputs[1].position+=Vector3.new(12,0,0);f.inputs[1].carryPosition+=Vector3.new(12,0,0);f.g:sync(f.inputs);f.g:decide()
  assert(f.g.actors[1]==a and a.mode=="Carried"and a.action=="carry"and not a.path)
  assert(f.g:snapshot().actors["1"].care.holderId==1)
 end)
 test("two-owner placement contention leaves losing pet held with independent controls",function()
  local f=fixture();local claim=f:dock(1);assert(f:request(2,"carePickup").status=="Accepted")
  local r=f:request(2,"carePlace");assert(r.reason=="BayOccupied"and f.g.actors[2].mode=="Carried"and f.care.bay.id==claim)
  local wrong=f:request(2,"careRelease",{claimId=claim});assert(wrong.status=="Accepted"and f.care.bay.id==claim,"non-bay release evicted another owner")
 end)
 test("unsafe set-down preflight makes no generation position or bay mutation",function()
  local f=fixture();local claim=f:dock(1);local a=f.g.actors[1];local generation=a.generation;f.dry=false
  local r=f:request(1,"careSetDown");assert(r.reason=="NoDrySpace"and a.mode=="Docked"and a.generation==generation and f.care.bay.id==claim)
 end)
 test("supported setdown is Placed until departure then resumes ordinary follow",function()
  local f=fixture();f:dock(1);assert(f:request(1,"careSetDown").status=="Accepted"and not f.care.bay)
  assert(f.g.actors[1].mode=="Placed");f.inputs[1].position+=Vector3.new(8,0,0);f.inputs[1].anchor=f.inputs[1].position;f.g:sync(f.inputs)
  assert(f.g.actors[1].mode=="Room"and not f.g.actors[1].care)
 end)
 test("exact replay returns original result and a conflicting same sequence cannot act",function()
  local f=fixture();local r,p=f:request(1,"carePickup");local gen=f.g.actors[1].generation
  assert(f.care:request(1,p)==r and f.g.actors[1].generation==gen)
  local conflict=table.clone(p);conflict.kind="careSetDown";assert(f.care:request(1,conflict).reason=="SequenceConflict"and f.g.actors[1].mode=="Carried")
 end)
 test("old claim release cannot evict the next occupant after a bay expires",function()
  local f=fixture();local old=f:dock(1);local stale=f:packet(1,"careRelease")
  f.now=4;f.g:sync(f.inputs);assert(not f.care.bay);local new=f:dock(2)
  local response=f.care:request(1,stale);assert(response.status=="Rejected"and f.care.bay.id==new and new~=old)
 end)
 test("late saved equip follows new truth without reclaiming a superseded bay",function()
  local f=fixture();f:dock(1);assert(f:request(1,"careEquip",{targetId="orbit"}).status=="Pending");local entry=f.equips[1]
  f.now=4;f.g:sync(f.inputs);local newer=f:dock(2)
  f.inputs[1].petId="orbit";f.inputs[1].petGeneration=2;f.care:complete(1,entry,"Saved","orbit",2)
  assert(f.g.actors[1].petId=="orbit"and f.g.actors[1].mode=="Room"and f.care.bay.id==newer and f.care.bay.ownerId==2)
 end)
 test("durable equip while exact live claim exists replaces just its one actor",function()
  local f=fixture();local claim=f:dock(1);local actor=f.g.actors[1];f:request(1,"careEquip",{targetId="orbit"})
  f.inputs[1].petId="orbit";f.inputs[1].petGeneration=2;f.care:complete(1,f.equips[1],"Saved","orbit",2)
  assert(f.g.actors[1]==actor and actor.petId=="orbit"and actor.mode=="Docked"and f.care.bay.id==claim and f.care.bay.petGeneration==2)
 end)
 test("an uncommitted equip failure preserves old pet and exact dock session",function()
  local f=fixture();local claim=f:dock(1);f:request(1,"careEquip",{targetId="orbit"});f.care:complete(1,f.equips[1],"Rejected")
  assert(f.g.actors[1].petId=="pip"and f.g.actors[1].mode=="Docked"and f.care.bay.id==claim)
 end)
 test("closing during an unresolved equip releases bay but does not cancel committed truth",function()
  local f=fixture();f:dock(1);f:request(1,"careEquip",{targetId="orbit"});local entry=f.equips[1]
  assert(f:request(1,"careRelease").status=="Accepted"and not f.care.bay)
  f.inputs[1].petId="orbit";f.inputs[1].petGeneration=2;f.care:complete(1,entry,"Saved","orbit",2)
  assert(f.g.actors[1].petId=="orbit"and f.g.actors[1].mode=="Room")
 end)
 test("death character replacement and disconnect retire only owned reservation",function()
  for _,reason in ipairs({"death","character","remove"})do local f=fixture();f:dock(1)
   if reason=="remove"then f.g:remove(1)else if reason=="death"then f.inputs[1].alive=false else f.inputs[1].characterId=9 end;f.g:sync(f.inputs)end
   assert(not f.care.bay and(not f.g.actors[1]or not f.g.actors[1].care))
  end
 end)
 test("unsafe editor close frees its exact bay and keeps the pet safely held",function()
  local f=fixture();f:dock(1);f.dry=false
  assert(f:request(1,"careRelease").status=="Accepted"and not f.care.bay and f.g.actors[1].mode=="Carried")
  f.dry=true;local claim=f:dock(2);assert(f.care.bay.id==claim and f.care.bay.ownerId==2)
 end)
 test("late saved equipment with no dry point stays safely carried and never uses arbitrary anchor",function()
  local f=fixture();f:dock(1);f:request(1,"careEquip",{targetId="orbit"});local entry=f.equips[1]
  f.now=4;f.g:sync(f.inputs);f.dry=false;f.inputs[1].anchor=Vector3.new(30,-80,30);f.inputs[1].petId="orbit";f.inputs[1].petGeneration=2
  f.care:complete(1,entry,"Saved","orbit",2)
  assert(f.g.actors[1].petId=="orbit"and f.g.actors[1].mode=="Carried"and not f.care.bay)
  assert(require(game.ReplicatedStorage.Shared.GardenActivity).vector(f.g.actors[1].to)==f.inputs[1].carryPosition)
 end)
 test("lost carried UI lease releases on next supported point without stranding attachment",function()
  local f=fixture();f:request(1,"carePickup");f.now=4;f.dry=false;f.g:sync(f.inputs);assert(f.g.actors[1].mode=="Carried")
  f.dry=true;f.g:sync(f.inputs);assert(f.g.actors[1].mode=="Room"and not f.g.actors[1].care)
 end)
 return {passed=#cases,cases=cases}
end
