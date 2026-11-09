-- Isolated current PlayerProgress source; no real profiles/datastores.
return function(server,source)
 assert(type(source)=="string","pass current PlayerProgress.Source")
 local realRequire=require;local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function copy(t)if type(t)~="table"then return t end;local r={};for k,v in pairs(t)do r[k]=copy(v)end;return r end
 local function fixture()
  local db={companionId="pip",companionAt=500,companionWriter="old",rank=1,hatching={epoch=1,revision=2,inventoryMask=127,lease={token="lease",expiresAt=200}}}
  local state={writes=0};local store={persistent=false}
  function store:UpdateAsync(_,transform)
   state.writes+=1;db=transform(copy(db))or db
   if state.throwAfter then state.throwAfter=false;error("Expected ambiguous committed write")end
   return copy(db)
  end
  local m=Instance.new("ModuleScript");m.Name="_CareSaveSandbox";m.Source="return function(e)local game,task,DateTime,require,script=e.game,e.task,e.DateTime,e.require,e.script\n"..source.."\nend";m.Parent=server
  local factory=realRequire(m);m:Destroy()
  local P=factory({script=server.PlayerProgress,game={JobId="care-writer",GetService=function(_,name)return game:GetService(name)end},
   task={spawn=function()end,defer=function()end},DateTime={now=function()return {UnixTimestampMillis=1000}end},
   require=function(module)if module==server.ProgressStore then return store end;return realRequire(module)end})
  local profile=P.fromRecord(123,db);local Pets=realRequire(game.ReplicatedStorage.Shared.PetCatalog)
  local fence={epoch=1,revision=2,token="lease",now=function()return 100 end}
  return P,profile,Pets.byId,fence,state,function()return db end
 end
 test("active equipment changes only on exact durable ID stamp writer proof",function()
  local P,p,pets,f,_,db=fixture();local saved=0;p.onCompanionSaved=function(c)assert(c.petId=="orbit");saved+=1 end
  local c=P.stageCompanion(p,pets.orbit,"op",f);assert(c and p.companionId=="pip"and db().companionId=="pip")
  assert(P.flushOnce(p)and saved==1 and p.companionId=="orbit"and db().companionAt==c.at and db().companionWriter==c.writer)
 end)
 test("ordinary dirty settings flush with stored companion stamp has no nil-stamp comparison",function()
  local P,p,_,_,_,db=fixture();P.setSetting(p,"sound","Quiet");assert(P.flushOnce(p)and db().sound=="Quiet"and p.companionId=="pip")
 end)
 test("legacy known owned newer winner terminates pending rather than blocking hydrate forever",function()
  local P,p,pets,_,_,db=fixture();P.equipCompanion(p,pets.orbit);db().companionId="wick";db().companionAt=3000;db().companionWriter="foreign"
  assert(P.flushOnce(p)and p.companionAt==nil and p.companionId=="wick")
  assert(P.hydrate(p,db()),"legacy loser left a hidden dirty owner")
 end)
 test("legacy and staged APIs cannot interleave competing companion writes",function()
  local P,p,pets,f=fixture();local c=P.stageCompanion(p,pets.orbit,"op",f)
  local ok,reason=P.equipCompanion(p,pets.wick);assert(ok==false and reason=="Busy"and p.companionId=="pip"and p.companionChange==c and not p.companionAt)
  assert(not P.stageCompanion(p,pets.puddle,"other",f));assert(P.flushOnce(p)and p.companionId=="orbit")
 end)
 test("commit-then-error retries the same captured candidate and acknowledges once",function()
  local P,p,pets,f,s,db=fixture();local saved=0;p.onCompanionSaved=function()saved+=1 end
  local c=P.stageCompanion(p,pets.orbit,"ambiguous",f);s.throwAfter=true
  assert(not P.flushOnce(p)and p.companionChange==c and p.companionId=="pip"and db().companionId=="orbit")
  assert(P.flushOnce(p)and p.companionId=="orbit"and saved==1 and db().companionAt==c.at and s.writes==2)
 end)
 test("expired and taken-over nursery lease cannot perform a new companion write",function()
  for _,kind in ipairs({"expiry","takeover","revision"})do
   local P,p,pets,f,_,db=fixture();local rejected=0;p.onCompanionRejected=function()rejected+=1 end
   P.stageCompanion(p,pets.orbit,"blocked",f)
   if kind=="expiry"then db().hatching.lease.expiresAt=99 elseif kind=="takeover"then db().hatching.lease.token="new";db().hatching.epoch=2 else db().hatching.revision=3 end
   assert(P.flushOnce(p)and p.companionId=="pip"and db().companionId=="pip"and rejected==1 and not p.companionChange)
  end
 end)
 test("proven newer owned foreign selection wins without rollback or candidate replay",function()
  local P,p,pets,f,_,db=fixture();local superseded=0;p.onCompanionSuperseded=function()superseded+=1 end
  P.stageCompanion(p,pets.orbit,"loser",f);db().companionId="foxfire_wick";db().companionAt=5000;db().companionWriter="foreign"
  assert(P.flushOnce(p)and p.companionId=="foxfire_wick"and superseded==1 and not p.companionChange)
 end)
 test("a foreign unknown or unowned selection cannot become public confirmed truth",function()
  local P,p,pets,f,_,db=fixture();local published=0;p.onCompanionSuperseded=function()published+=1 end
  P.stageCompanion(p,pets.orbit,"no-foreign-grant",f);db().companionId="foxfire_wick";db().companionAt=5000;db().companionWriter="foreign";db().hatching.inventoryMask=15
  assert(not P.flushOnce(p)and published==0 and p.companionId=="pip"and p.companionChange and p.saveFailed)
 end)
 return {passed=#cases,cases=cases,persistentWrites=false}
end
