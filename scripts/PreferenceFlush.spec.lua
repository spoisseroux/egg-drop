-- Actual profile writer/protocol with a deterministic deferred scheduler/store.
-- No real profile or DataStore calls; the12s periodic safety sweep is disabled.
return function(server,source)
 assert(type(source)=="string","pass current PlayerProgress.Source")
 local actualRequire=require;local Appearance=actualRequire(server.PetAppearance);local cases={}
 local function copy(value)if type(value)~="table"then return value end;local result={};for k,v in pairs(value)do result[k]=copy(v)end;return result end
 local function fixture()
  local f={now=0,writes=0,jobs={},saved={},db={custom="kept",hatching={nectar=37,revision=6,lease={token="same",expiresAt=90}}}}
  local store={persistent=false}
  function store:UpdateAsync(_,transform)
   f.writes+=1
   if f.failBefore then error("Expected preference write failure")end
   if f.before then local fn=f.before;f.before=nil;fn()end
   f.db=transform(copy(f.db))or f.db
   if f.failAfter then f.failAfter=false;error("Expected committed write with lost response")end
   return copy(f.db)
  end
  local function queue(delay,fn)table.insert(f.jobs,{at=f.now+delay,run=fn})end
  local shim={spawn=function()end,defer=function(fn)queue(0,fn)end,delay=queue}
  local module=Instance.new("ModuleScript");module.Name="_PreferenceFlushSource";module.Source="return function(e)local game,script,task,require,DateTime=e.game,e.script,e.task,e.require,e.DateTime\n"..source.."\nend";module.Parent=server
  local factory=actualRequire(module);module:Destroy()
  f.api=factory({script=server.PlayerProgress,game={JobId="flush-fixture",GetService=function(_,name)return game:GetService(name)end},task=shim,
   DateTime={now=function()return {UnixTimestampMillis=1000+math.floor(f.now*1000)}end},
   require=function(target)if target==server.ProgressStore then return store end;return actualRequire(target)end})
  f.profile=f.api.fromRecord(12,copy(f.db),true);f.state=Appearance.new({selectionsEnabled=true})
  f.profile.onPetAppearanceSaved=function(candidate)for _,packet in ipairs(Appearance.saved(f.state,f.profile,candidate))do table.insert(f.saved,packet)end end
  function f:request(id,visible,seq,shape)
   local packet=Appearance.request(self.state,self.profile,{petId=id,visible=visible,seq=seq,shape=shape,shapeVersion=if shape then 2 else nil},seq,true,function()return true end,self.api.setPetAppearance)
   if packet and packet.status=="Applied"then assert(self.api.requestFlush(self.profile))end
   return packet
  end
  function f:next()
   table.sort(self.jobs,function(a,b)return a.at<b.at end);local job=table.remove(self.jobs,1);assert(job,"expected deferred work");self.now=job.at;job.run()
  end
  function f:drain()local turns=0;while #self.jobs>0 do self:next();turns+=1;assert(turns<=20,"unbounded flush loop")end end
  return f
 end
 local function test(name,run)run();table.insert(cases,name)end
 test("healthy preference gets deferred durable proof before retry UI without periodic sweep",function()
  local f=fixture();local packet=f:request("pip",false,1,"ring")
  assert(packet.status=="Applied"and f.writes==0 and #f.jobs==1 and Appearance.public(f.profile).pip.charmVisible)
  f:drain();assert(f.now<2 and f.writes==1 and #f.saved==1 and f.saved[1].status=="Saved")
  assert(not Appearance.public(f.profile).pip.charmVisible and f.db.petAppearance.pip.charmShape=="ring")
  assert(f.db.custom=="kept"and f.db.hatching.nectar==37 and f.db.hatching.revision==6 and f.db.hatching.lease.token=="same")
 end)
 test("same-turn preferences and Applied replays coalesce into one writer",function()
  local f=fixture();local first=f:request("pip",false,1,"ring");f:request("puddle",false,2,"pebble")
  assert(f:request("pip",false,1,"ring")==first and #f.jobs==1);f:drain();assert(f.writes==1 and #f.saved==2)
  assert(f:request("pip",false,1,"ring").status=="Saved"and #f.jobs==0 and f.writes==1)
 end)
 test("new exact generation during an unrelated in-flight flush drains immediately afterward",function()
  local f=fixture();f.api.setSetting(f.profile,"sound","Quiet")
  f.before=function()assert(f.profile.saving);f:request("pip",false,1,"ring");assert(#f.jobs==0)end
  assert(not f.api.flushOnce(f.profile)and #f.jobs==1 and #f.saved==0);f:drain()
  assert(f.writes==2 and #f.saved==1 and f.db.sound=="Quiet"and not f.db.petAppearance.pip.charmVisible)
 end)
 test("newer local choice during a save receives only its own later durable proof",function()
  local f=fixture();f:request("pip",false,1,"ring")
  f.before=function()f:request("pip",false,2,"pebble")end
  f:next();assert(#f.saved==0 and Appearance.public(f.profile).pip.charmShape=="ring"and #f.jobs==1)
  f:drain();assert(f.writes==2 and #f.saved==1 and f.saved[1].seq==2 and f.saved[1].shape=="pebble")
 end)
 test("commit-then-error retries exact stamp once without duplicate acknowledgement",function()
  local f=fixture();f.failAfter=true;f:request("pip",false,1,"ring");local candidate=f.profile.petAppearanceChanges.pip
  f:next();assert(#f.saved==0 and f.profile.petAppearanceChanges.pip==candidate and f.db.petAppearance.pip.at==candidate.at)
  f:drain();assert(f.writes==2 and #f.saved==1 and f.saved[1].seq==1 and f.db.petAppearance.pip.at==candidate.at)
 end)
 test("real failures have three bounded backoffs and exact client retry can re-arm",function()
  local f=fixture();f.failBefore=true;f:request("pip",false,1,"ring");local candidate=f.profile.petAppearanceChanges.pip
  f:drain();assert(f.writes==4 and math.abs(f.now-3.5)<.00001 and #f.saved==0 and f.profile.petAppearanceChanges.pip==candidate)
  f.failBefore=false;assert(f:request("pip",false,1,"ring").status=="Applied");f:drain()
  assert(f.writes==5 and #f.saved==1 and f.db.petAppearance.pip.at==candidate.at and not f.profile.saveFailed)
 end)
 return {passed=#cases,cases=cases,persistentWrites=false}
end
