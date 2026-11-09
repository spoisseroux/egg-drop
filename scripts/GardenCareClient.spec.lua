-- Isolated transport, injected actor/character/remote. No real sends or profile operations.
return function(client)
 local Client=require(client.GardenCareClient);local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function fixture()
  local character={};local actor={petId="pip",characterId=1,petGeneration=2,generation=3,mode="Docked",care={state="Docked",claimId="bay-A"}}
  local sent={};local remote={FireServer=function(_,packet)table.insert(sent,table.clone(packet))end}
  local self=setmetatable({seq=0,operations={},remote=remote,actorProvider=function()return actor end,characterProvider=function()return character end,
   revision=function()return 4 end,notice={},room={}},Client)
  return self,actor,sent,function(value)character=value end
 end
 test("captured request has exact identity claim revision and independent sequence",function()
  local c,_,sent=fixture();assert(c:request("careEquip","puddle"));local p=sent[1]
  assert(p.kind=="careEquip"and p.seq==1 and p.petId=="pip"and p.characterId==1 and p.petGeneration==2 and p.actorGeneration==3 and p.claimId=="bay-A"and p.revision==4 and p.targetId=="puddle")
 end)
 test("same-kind pending request cannot accumulate or become a second equip",function()
  local c,_,sent=fixture();assert(c:request("careEquip","puddle")and not c:request("careEquip","orbit")and #sent==1)
 end)
 test("pending then saved invokes one captured completion and duplicate terminal is ignored",function()
  local c=fixture();local done=0;c:request("careEquip","puddle",function(p)assert(p.status=="Saved");done+=1 end)
  c:receive({kind="careEquip",seq=1,status="Pending"});assert(c.operations[1].saving and done==0)
  c:receive({kind="careEquip",seq=1,status="Saved"});c:receive({kind="careEquip",seq=1,status="Saved"});assert(done==1 and not c.operations[1])
 end)
 test("stale character or mismatched packet cannot close another character focus",function()
  local c,_,_,replace=fixture();local done=0;c:request("carePickup",nil,function()done+=1 end)
  c:receive({kind="careSetDown",seq=1,status="Accepted"});assert(done==0 and c.operations[1])
  replace({});c:receive({kind="carePickup",seq=1,status="Accepted"});assert(done==0 and not c.operations[1])
 end)
 test("an equip can stay unresolved while exact claim release is independently sent",function()
  local c,_,sent=fixture();c:request("careEquip","puddle");assert(c:release()and #sent==2 and sent[2].kind=="careRelease"and sent[2].claimId=="bay-A")
  assert(c.operations[1]and c.operations[2]and c.releasing)
 end)
 test("exact carried snapshot confirms pending pickup before generic dock cleanup and late receipt is inert",function()
  local c,actor,sent=fixture();local done,closed=0,0
  c.closeMachine=function()closed+=1 end
  c:request("carePickup",nil,function(packet)assert(packet.status=="Accepted");done+=1 end)
  actor.care={state="Carried"};actor.mode="Carried";actor.generation=4
  assert(c:reconcilePickup(actor)and done==1 and closed==1 and not c.operations[1]and not c.wantMachine)
  c:receive({kind="carePickup",seq=1,status="Accepted"});assert(done==1 and closed==1 and #sent==1 and not c:reconcilePickup(actor))
 end)
 test("pickup receipt first and wrong-generation snapshots cannot manufacture a second confirmation",function()
  local c,actor=fixture();local done=0
  c:request("carePickup",nil,function()done+=1 end)
  actor.care={state="Carried"};actor.generation=5
  assert(not c:reconcilePickup(actor)and done==0)
  c:receive({kind="carePickup",seq=1,status="Accepted"});assert(done==1 and not c:reconcilePickup(actor))
 end)
 test("refused setdown preserves hold and gives a clear dry-space reason",function()
  local c,actor=fixture();actor.mode="Carried";actor.care={state="Carried"};c:request("careSetDown")
  c:receive({kind="careSetDown",seq=1,status="Rejected",reason="NoDrySpace"});assert(actor.mode=="Carried"and c.notice.Text:find("dry",1,true)and not c.operations[1])
 end)
 test("only accepted place opens the machine and no synthetic saved result mutates equipment",function()
  local c,actor=fixture();c:request("carePlace");c:receive({kind="carePlace",seq=1,status="Accepted"});assert(c.wantMachine and actor.petId=="pip")
  c:request("careEquip","puddle");c:receive({kind="careEquip",seq=2,status="Saved"});assert(actor.petId=="pip","client receipt mutated authoritative equipment")
 end)
 test("destroyed transport ignores late callbacks and cannot send",function()
  local c,_,sent=fixture();local done=0;c:request("carePickup",nil,function()done+=1 end);c.destroyed=true
  c:receive({kind="carePickup",seq=1,status="Accepted"});assert(done==0 and not c:request("careSetDown")and #sent==1)
 end)
 test("board-first and snapshot-first equip replication preserve the exact current editor claim",function()
  local c,_,_,replace=fixture();local character={};replace(character);c.boundCharacter=character;c.boundClaim="bay-A";c.docked=true;c.ownerId=123;c.room.mode="Room";c.room.target="Room"
  local old={id="bay-A",ownerId=123,petId="pip",petGeneration=2};local nextPet={id="bay-A",ownerId=123,petId="puddle",petGeneration=3}
  assert(c:keepsDock(nil,old)and c:keepsDock(nil,nextPet),"temporary identity disagreement retired current bay")
  assert(not c:keepsDock(nil,{id="bay-B",ownerId=124}));replace({});assert(not c:keepsDock(nil,old))
 end)
 test("teardown sends one best-effort exact release and retires all UI resources",function()
  local c,_,sent=fixture();local retired=0;c.connections={};c.room.focusUI={};c.pickup={Destroy=function()retired+=1 end};c.setDown=c.pickup;c.notice=c.pickup
  c:destroy();assert(c.destroyed and #sent==1 and sent[1].kind=="careRelease"and sent[1].claimId=="bay-A"and retired==3)
  c:destroy();assert(#sent==1)
 end)
 return {passed=#cases,cases=cases}
end
