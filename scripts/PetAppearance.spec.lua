-- Protocol plus real PlayerProgress source with isolated in-memory storage.
return function(server,progressSource)
 local Appearance=require(server.PetAppearance);local realRequire=require
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function copy(value)if type(value)~="table"then return value end;local out={};for k,v in pairs(value)do out[k]=copy(v)end;return out end
 local function fixture(options)
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
  f.state=Appearance.new(options)
  function f:reload()
   self.profile=self.api.fromRecord(1,copy(self.db),true)
   self.profile.onPetAppearanceSaved=function(candidate)table.insert(self.published,Appearance.public(self.profile));for _,result in ipairs(Appearance.saved(self.state,self.profile,candidate))do table.insert(self.saved,result)end end
   self.profile.onPetAppearanceSuperseded=function(candidate)for _,result in ipairs(Appearance.superseded(self.state,self.profile,candidate))do table.insert(self.superseded,result)end end
  end
  f:reload()
  function f:request(id,visible,seq,time,usable,owned)return Appearance.request(self.state,self.profile,{petId=id,visible=visible,seq=seq},time,usable~=false,function()return owned~=false end,self.api.setPetAppearance)end
  return f
 end
 test("strict owned aliases and booleans reject forged shapes without a progression mutation",function()
  -- Pets start with no charm: with nothing saved the public projection is hidden.
  local f=fixture();assert(Appearance.public(f.profile).pip.charmVisible==false and Appearance.visible(f.profile,"pip")==false)
  assert(f:request("unknown-pet",false,1,1).reason=="Malformed")
  assert(f:request("pip",false,1,2,true,false).reason=="Unowned")
  assert(f:request("puddle",false,1,3,false).status=="Rejected")
  assert(next(f.profile.petAppearanceChanges)==nil and f.profile.rank==0 and f.db.hatching.nectar==17)
 end)
 test("duplicate and stale requests cannot reapply, and independent pets save exact preferences",function()
  -- Pets start hidden, so the changing request is Show (a Hide would equal the default and save nothing).
  local f=fixture();local first=f:request("pip",true,1,1);assert(first.status=="Applied")
  local pending=f.profile.petAppearanceChanges.pip
  assert(f:request("pip",true,1,1.1)==first and f.profile.petAppearanceChanges.pip==pending)
  assert(f:request("pip",false,1,1.4).reason=="SeqConflict")
  assert(f:request("pip",true,0,1.7).reason=="Malformed")
  assert(f:request("puddle",true,1,2).status=="Applied")
  assert(f.api.flushOnce(f.profile));assert(#f.saved==2)
  assert(f.db.petAppearance.pip.charmVisible==true and f.db.petAppearance.puddle.charmVisible==true)
  assert(f.db.customSibling=="preserve"and f.db.hatching.nectar==17 and f.db.hatching.revision==6)
  local rejoined=f.api.fromRecord(1,f.db,true);assert(Appearance.public(rejoined).pip.charmVisible==true)
  assert(f:request("puddle",false,2,3).status=="Applied","explicit Hide after a saved Show must change the profile")
 end)
 test("A B A same-value intent settles against the pending per-pet generation",function()
  local f=fixture();f:request("pip",true,1,1);local a=f.profile.petAppearanceChanges.pip
  f:request("puddle",true,1,2);assert(f:request("pip",true,2,3).status=="Applied")
  assert(f.state.requests.pip.generation==a.generation)
  assert(f.api.flushOnce(f.profile));assert(f.state.requests.pip.result.status=="Saved"and f.state.requests.pip.result.seq==2)
 end)
 test("a newer local toggle during save remains pending and cannot receive the old receipt",function()
  local f=fixture();f:request("pip",true,1,1)
  f.after=function()f.now+=1;f:request("pip",false,2,2)end
  assert(not f.api.flushOnce(f.profile));assert(f.state.requests.pip.result.status=="Applied"and #f.saved==0)
  assert(Appearance.visible(f.profile,"pip")==false,"new desired intent must remain pending")
  assert(Appearance.public(f.profile).pip.charmVisible==true and f.published[1].pip.charmVisible==true,"old receipt must not publish newer uncommitted intent")
  assert(f.api.flushOnce(f.profile));assert(f.db.petAppearance.pip.charmVisible==false and #f.saved==1 and f.saved[1].seq==2)
  assert(Appearance.public(f.profile).pip.charmVisible==false)
 end)
 test("Applied and failed writes retain the previous confirmed public projection",function()
  -- Default is hidden, so the pending intent is Show and the confirmed projection stays hidden until saved.
  local f=fixture();assert(f:request("pip",true,1,1).status=="Applied")
  assert(Appearance.visible(f.profile,"pip")==true and Appearance.public(f.profile).pip.charmVisible==false)
  f.failBefore=true;assert(not f.api.flushOnce(f.profile))
  assert(f.profile.saveFailed and Appearance.public(f.profile).pip.charmVisible==false and #f.published==0)
  assert(f.db.hatching.nectar==17 and f.db.hatching.revision==6 and f.db.petAppearance==nil)
  assert(f.api.flushOnce(f.profile));assert(Appearance.public(f.profile).pip.charmVisible==true)
 end)
 test("A commit cannot expose B created while A's write is in flight",function()
  -- Show requests (default is hidden) so B's pending intent differs from the confirmed projection.
  local f=fixture();f:request("pip",true,1,1)
  f.before=function()f:request("puddle",true,1,2)end
  assert(not f.api.flushOnce(f.profile))
  local public=Appearance.public(f.profile)
  assert(public.pip.charmVisible==true and public.puddle.charmVisible==false)
  assert(f.published[1].puddle.charmVisible==false and Appearance.visible(f.profile,"puddle")==true)
  assert(f.api.flushOnce(f.profile));assert(Appearance.public(f.profile).puddle.charmVisible==true)
  assert(f.db.hatching.nectar==17 and f.db.customSibling=="preserve")
 end)
 test("foreign newer same-pet intent supersedes explicitly while other pet and wallet survive",function()
  local f=fixture();f:request("pip",true,1,1)
  f.before=function()f.db.petAppearance={pip={charmVisible=false,at=2000,writer="other"},puddle={charmVisible=true,at=900,writer="other"},future={x=1}}end
  assert(f.api.flushOnce(f.profile));assert(#f.superseded==1 and f.superseded[1].reason=="Superseded")
  assert(Appearance.public(f.profile).pip.charmVisible==false and f.db.petAppearance.future.x==1 and f.db.petAppearance.puddle.charmVisible==true)
 end)
 test("invalid stored entries default safely and independent per-pet merge retains future fields",function()
  local decoded=Appearance.decode({pip={charmVisible=false,at=0/0,writer="x"},puddle={charmVisible=false,at=7,writer="x"}})
  assert(decoded.pip==nil and decoded.puddle.charmVisible==false)
  local result=Appearance.merge({future={keep=true},puddle={charmVisible=false,at=5,writer="a"}},{pip={visible=false,at=9,writer="b"}})
  assert(result.future.keep and result.puddle.at==5 and result.pip.charmVisible==false)
 end)
 test("known forms save with visibility while legacy missing shape decodes to Dot",function()
  local f=fixture()
  local packet=Appearance.request(f.state,f.profile,{petId="wick",visible=false,shape="star",seq=1},1,true,function()return true end,f.api.setPetAppearance)
  assert(packet.status=="Rejected"and packet.reason=="Malformed"and f.profile.petAppearanceChanges.wick==nil)
  packet=Appearance.request(f.state,f.profile,{petId="wick",visible=true,shape="dot",shapeVersion=2,seq=1},2,true,function()return true end,f.api.setPetAppearance)
  assert(packet.status=="Applied"and packet.shape=="dot");assert(f.api.flushOnce(f.profile))
  assert(f.db.petAppearance.wick.charmShape=="dot"and f.db.petAppearance.wick.charmVisible==true and Appearance.public(f.profile).wick.charmShape=="dot")
  local old=Appearance.decode({pip={charmVisible=false,at=7,writer="legacy"}});assert(old.pip.charmShape=="dot"and not old.pip.charmVisible)
 end)
 test("hidden Ring and Pebble persist the exact shape pair, with same-seq conflict detection",function()
  local f=fixture()
  local function request(shape,seq)return Appearance.request(f.state,f.profile,{petId="pip",visible=false,shape=shape,shapeVersion=if shape~=nil then 2 else nil,seq=seq},seq,true,function()return true end,f.api.setPetAppearance)end
  local first=request("ring",1);assert(first.status=="Applied"and first.shape=="ring")
  assert(request("ring",1)==first and request("pebble",1).reason=="SeqConflict")
  assert(f.api.flushOnce(f.profile));assert(not f.db.petAppearance.pip.charmVisible and f.db.petAppearance.pip.charmShape=="ring")
  assert(request("pebble",2).status=="Applied");assert(f.api.flushOnce(f.profile))
  local rejoined=f.api.fromRecord(1,copy(f.db),true);local public=Appearance.public(rejoined).pip
  assert(not public.charmVisible and public.charmShape=="pebble")
 end)
 test("unknown future form survives decode, public projection and visibility-only old client writes",function()
  local f=fixture();f.db.petAppearance={pip={charmVisible=false,charmShape="future_kite",at=900,writer="future",extra={keep=true}}}
  f:reload()
  assert(Appearance.public(f.profile).pip.charmShape=="future_kite"and not Appearance.public(f.profile).pip.charmVisible)
  assert(f:request("pip",true,1,1).status=="Applied");assert(f.api.flushOnce(f.profile))
  assert(f.db.petAppearance.pip.charmShape=="future_kite"and f.db.petAppearance.pip.charmVisible and f.db.petAppearance.pip.extra.keep)
  local Charms=require(game.ReplicatedStorage.Shared.PetCharmCatalog)
  assert(Charms.renderShape("future_kite")=="dot")
 end)
 test("newer foreign unknown form wins intact rather than being replaced by an older known shape",function()
  local f=fixture()
  Appearance.request(f.state,f.profile,{petId="pip",visible=false,shape="ring",shapeVersion=2,seq=1},1,true,function()return true end,f.api.setPetAppearance)
  f.before=function()f.db.petAppearance={pip={charmVisible=false,charmShape="future_kite",at=2000,writer="future"}}end
  assert(f.api.flushOnce(f.profile));assert(#f.superseded==1 and f.profile.petAppearanceChanges.pip==nil)
  assert(Appearance.public(f.profile).pip.charmShape=="future_kite"and not Appearance.public(f.profile).pip.charmVisible)
 end)
 test("later local shape during an in-flight save cannot receive the earlier shape receipt",function()
  local f=fixture()
  local function request(shape,seq)return Appearance.request(f.state,f.profile,{petId="pip",visible=false,shape=shape,shapeVersion=if shape~=nil then 2 else nil,seq=seq},seq,true,function()return true end,f.api.setPetAppearance)end
  request("ring",1);f.after=function()f.now+=1;request("pebble",2)end
  assert(not f.api.flushOnce(f.profile)and #f.saved==0)
  assert(Appearance.public(f.profile).pip.charmShape=="ring"and Appearance.shape(f.profile,"pip")=="pebble")
  assert(f.api.flushOnce(f.profile)and #f.saved==1 and f.saved[1].shape=="pebble")
 end)
 test("future unknown shape cannot be selected through a forged request",function()
  local f=fixture();local result=Appearance.request(f.state,f.profile,{petId="pip",visible=true,shape="future_kite",seq=1},1,true,function()return true end,f.api.setPetAppearance)
  assert(result.reason=="Malformed"and next(f.profile.petAppearanceChanges)==nil)
 end)
 test("optional shape presence is part of exact wire identity while resolved pairs remain durable",function()
  local f=fixture()
  local function request(id,shape,seq)return Appearance.request(f.state,f.profile,{petId=id,visible=false,shape=shape,shapeVersion=if shape~=nil then 2 else nil,seq=seq},seq,true,function()return true end,f.api.setPetAppearance)end
  local ring=request("pip","ring",1);assert(request("pip",nil,1).reason=="SeqConflict"and request("pip","ring",1)==ring)
  local omitted=request("puddle",nil,2);assert(request("puddle","dot",2).reason=="SeqConflict"and request("puddle",nil,2)==omitted)
  f.profile.petAppearance.wick={charmVisible=false,charmShape="future_kite",at=9,writer="future"}
  local opaque=request("wick",nil,3);assert(request("wick",nil,3)==opaque and opaque.shape=="future_kite")
 end)
 test("v274 explicit unmarked Dot Hide/Show preserves saved Ring Pebble and opaque future IDs",function()
  for _,savedShape in ipairs({"ring","pebble","future_kite"})do
   local f=fixture();f.db.petAppearance={pip={charmVisible=true,charmShape=savedShape,at=900,writer="older",extra={keep=true}}};f:reload()
   local function request(visible,seq,version)return Appearance.request(f.state,f.profile,{petId="pip",visible=visible,shape="dot",shapeVersion=version,seq=seq},seq,true,function()return true end,f.api.setPetAppearance)end
   local hidden=request(false,1);assert(hidden.status=="Applied"and hidden.shape==savedShape and request(false,1)==hidden)
   assert(request(false,1,2).reason=="SeqConflict","legacy/modern marker identity collapsed")
   assert(f.api.flushOnce(f.profile));assert(f.db.petAppearance.pip.charmShape==savedShape and not f.db.petAppearance.pip.charmVisible)
   assert(request(true,2).status=="Applied"and f.api.flushOnce(f.profile));assert(f.db.petAppearance.pip.charmShape==savedShape and f.db.petAppearance.pip.charmVisible and f.db.petAppearance.pip.extra.keep)
   assert(f.db.hatching.nectar==17 and f.db.hatching.revision==6)
  end
 end)
 test("closed server selection gate rejects marked changes while visibility-only writes preserve shape",function()
  local f=fixture({selectionsEnabled=false});f.db.petAppearance={pip={charmVisible=true,charmShape="ring",at=900,writer="older"}};f:reload()
  local function request(shape,version,visible,seq)return Appearance.request(f.state,f.profile,{petId="pip",visible=visible,shape=shape,shapeVersion=version,seq=seq},seq,true,function()return true end,f.api.setPetAppearance)end
  local denied=request("pebble",2,true,1);assert(denied.reason=="SelectionsDisabled"and request("pebble",2,true,1)==denied and next(f.profile.petAppearanceChanges)==nil)
  assert(request("dot",2,true,2).reason=="SelectionsDisabled")
  assert(request("dot",nil,false,3).status=="Applied"and f.api.flushOnce(f.profile))
  assert(f.db.petAppearance.pip.charmShape=="ring"and not f.db.petAppearance.pip.charmVisible)
 end)
 test("open v2 explicit Dot selection changes the saved shape with exact protocol-aware replay",function()
  local f=fixture({selectionsEnabled=true});f.db.petAppearance={pip={charmVisible=false,charmShape="ring",at=900,writer="older"}};f:reload()
  local function request(version)return Appearance.request(f.state,f.profile,{petId="pip",visible=false,shape="dot",shapeVersion=version,seq=1},1,true,function()return true end,f.api.setPetAppearance)end
  local selected=request(2);assert(selected.status=="Applied"and selected.shape=="dot"and request(2)==selected and request(nil).reason=="SeqConflict")
  assert(f.api.flushOnce(f.profile));assert(f.db.petAppearance.pip.charmShape=="dot"and not f.db.petAppearance.pip.charmVisible and request(2).status=="Saved")
 end)
 test("unmarked nondefault selections and malformed declared versions cannot change a profile",function()
  local f=fixture({selectionsEnabled=true})
  for i,value in ipairs({{shape="ring"},{shape="pebble"},{shape="dot",shapeVersion=1},{shape="dot",shapeVersion=3},{shapeVersion=2},{shape="future_kite",shapeVersion=2}})do
   value.petId,value.visible,value.seq="pip",true,i
   local result=Appearance.request(f.state,f.profile,value,i,true,function()return true end,f.api.setPetAppearance)
   assert(result.status=="Rejected"and next(f.profile.petAppearanceChanges)==nil and f.db.petAppearance==nil)
  end
 end)
 return cases
end
