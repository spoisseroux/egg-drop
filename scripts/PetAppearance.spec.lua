-- Protocol plus real PlayerProgress source with isolated in-memory storage.
return function(server,progressSource)
 local Appearance=require(server.PetAppearance);local realRequire=require
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function copy(value)if type(value)~="table"then return value end;local out={};for k,v in pairs(value)do out[k]=copy(v)end;return out end
 local function fixture()
  local f={now=1000,db={hatching={nectar=17,revision=6,inventory=3},customSibling="preserve",theme="sherbet",sticker="none"},saved={},superseded={},published={}}
  local store={persistent=false}
  function store:UpdateAsync(_,transform)
   if f.failBefore then f.failBefore=false;error("Expected fixture: pet appearance write unavailable")end
   if f.before then local fn=f.before;f.before=nil;fn()end
   f.db=transform(copy(f.db))
   if f.after then local fn=f.after;f.after=nil;fn()end
   return copy(f.db)
  end
  local fakeGame={JobId="pet-appearance-fixture"}
  function fakeGame:GetService(name)return game:GetService(name)end;function fakeGame:BindToClose()end
  local module=Instance.new("ModuleScript");module.Name="_PetAppearanceProgressFixture"
  module.Source="return function(e) local game,script,task,require,DateTime=e.game,e.script,e.task,e.require,e.DateTime\n"..progressSource.."\nend";module.Parent=server
  local run=realRequire(module);module:Destroy()
  f.api=run({game=fakeGame,script=server.PlayerProgress,task={spawn=function()end,defer=function()end},DateTime={now=function()return{UnixTimestampMillis=f.now}end},require=function(target)if target==server.ProgressStore then return store end;return realRequire(target)end})
  f.profile=f.api.fromRecord(1,copy(f.db),true);f.state=Appearance.new()
  f.profile.onPetAppearanceSaved=function(candidate)table.insert(f.published,Appearance.public(f.profile));for _,result in ipairs(Appearance.saved(f.state,f.profile,candidate))do table.insert(f.saved,result)end end
  f.profile.onPetAppearanceSuperseded=function(candidate)for _,result in ipairs(Appearance.superseded(f.state,f.profile,candidate))do table.insert(f.superseded,result)end end
  function f:request(id,visible,seq,time,usable,owned)return Appearance.request(self.state,self.profile,{petId=id,visible=visible,seq=seq},time,usable~=false,function()return owned~=false end,self.api.setPetAppearance)end
  return f
 end
 test("strict owned aliases and booleans reject forged shapes without a progression mutation",function()
  local f=fixture();assert(Appearance.public(f.profile).pip.charmVisible)
  assert(f:request("wick",false,1,1).reason=="Malformed")
  assert(f:request("pip",false,1,2,true,false).reason=="Unowned")
  assert(f:request("puddle",false,1,3,false).status=="Rejected")
  assert(next(f.profile.petAppearanceChanges)==nil and f.profile.rank==0 and f.db.hatching.nectar==17)
 end)
 test("duplicate and stale requests cannot reapply, and independent pets save exact preferences",function()
  local f=fixture();local first=f:request("pip",false,1,1);assert(first.status=="Applied")
  local pending=f.profile.petAppearanceChanges.pip
  assert(f:request("pip",false,1,1.1)==first and f.profile.petAppearanceChanges.pip==pending)
  assert(f:request("pip",true,1,1.4).reason=="SeqConflict")
  assert(f:request("pip",true,0,1.7).reason=="Malformed")
  assert(f:request("puddle",false,1,2).status=="Applied")
  assert(f.api.flushOnce(f.profile));assert(#f.saved==2)
  assert(not f.db.petAppearance.pip.charmVisible and not f.db.petAppearance.puddle.charmVisible)
  assert(f.db.customSibling=="preserve"and f.db.hatching.nectar==17 and f.db.hatching.revision==6)
  local rejoined=f.api.fromRecord(1,f.db,true);assert(not Appearance.public(rejoined).pip.charmVisible)
 end)
 test("A B A same-value intent settles against the pending per-pet generation",function()
  local f=fixture();f:request("pip",false,1,1);local a=f.profile.petAppearanceChanges.pip
  f:request("puddle",false,1,2);assert(f:request("pip",false,2,3).status=="Applied")
  assert(f.state.requests.pip.generation==a.generation)
  assert(f.api.flushOnce(f.profile));assert(f.state.requests.pip.result.status=="Saved"and f.state.requests.pip.result.seq==2)
 end)
 test("a newer local toggle during save remains pending and cannot receive the old receipt",function()
  local f=fixture();f:request("pip",false,1,1)
  f.after=function()f.now+=1;f:request("pip",true,2,2)end
  assert(not f.api.flushOnce(f.profile));assert(f.state.requests.pip.result.status=="Applied"and #f.saved==0)
  assert(Appearance.visible(f.profile,"pip")==true,"new desired intent must remain pending")
  assert(Appearance.public(f.profile).pip.charmVisible==false and f.published[1].pip.charmVisible==false,"old receipt must not publish newer uncommitted intent")
  assert(f.api.flushOnce(f.profile));assert(f.db.petAppearance.pip.charmVisible and #f.saved==1 and f.saved[1].seq==2)
  assert(Appearance.public(f.profile).pip.charmVisible==true)
 end)
 test("Applied and failed writes retain the previous confirmed public projection",function()
  local f=fixture();assert(f:request("pip",false,1,1).status=="Applied")
  assert(Appearance.visible(f.profile,"pip")==false and Appearance.public(f.profile).pip.charmVisible==true)
  f.failBefore=true;assert(not f.api.flushOnce(f.profile))
  assert(f.profile.saveFailed and Appearance.public(f.profile).pip.charmVisible==true and #f.published==0)
  assert(f.db.hatching.nectar==17 and f.db.hatching.revision==6 and f.db.petAppearance==nil)
  assert(f.api.flushOnce(f.profile));assert(Appearance.public(f.profile).pip.charmVisible==false)
 end)
 test("A commit cannot expose B created while A's write is in flight",function()
  local f=fixture();f:request("pip",false,1,1)
  f.before=function()f:request("puddle",false,1,2)end
  assert(not f.api.flushOnce(f.profile))
  local public=Appearance.public(f.profile)
  assert(public.pip.charmVisible==false and public.puddle.charmVisible==true)
  assert(f.published[1].puddle.charmVisible==true and Appearance.visible(f.profile,"puddle")==false)
  assert(f.api.flushOnce(f.profile));assert(Appearance.public(f.profile).puddle.charmVisible==false)
  assert(f.db.hatching.nectar==17 and f.db.customSibling=="preserve")
 end)
 test("foreign newer same-pet intent supersedes explicitly while other pet and wallet survive",function()
  local f=fixture();f:request("pip",false,1,1)
  f.before=function()f.db.petAppearance={pip={charmVisible=true,at=2000,writer="other"},puddle={charmVisible=false,at=900,writer="other"},future={x=1}}end
  assert(f.api.flushOnce(f.profile));assert(#f.superseded==1 and f.superseded[1].reason=="Superseded")
  assert(Appearance.public(f.profile).pip.charmVisible and f.db.petAppearance.future.x==1 and not f.db.petAppearance.puddle.charmVisible)
 end)
 test("invalid stored entries default safely and independent per-pet merge retains future fields",function()
  local decoded=Appearance.decode({pip={charmVisible=false,at=0/0,writer="x"},puddle={charmVisible=false,at=7,writer="x"}})
  assert(decoded.pip==nil and decoded.puddle.charmVisible==false)
  local result=Appearance.merge({future={keep=true},puddle={charmVisible=false,at=5,writer="a"}},{pip={visible=false,at=9,writer="b"}})
  assert(result.future.keep and result.puddle.at==5 and result.pip.charmVisible==false)
 end)
 return cases
end
