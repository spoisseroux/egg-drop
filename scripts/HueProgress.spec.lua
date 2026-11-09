-- Isolated authoritative transactions; no player storage, RNG or live remotes.
return function(server,progressSource)
 local H=require(server.HatchProgress);local HS=require(server.HueState)
 local Shared=game.ReplicatedStorage.Shared;local Hue=require(Shared.HueCatalog);local Eggs=require(Shared.EggCatalog)
 local Appearance=require(server.PetAppearance)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function copy(x)if type(x)~="table"then return x end;local out={};for k,v in pairs(x)do out[k]=copy(v)end;return out end
 local function fixture()
  local db={player_1={rank=2,custom="preserved",petAppearance={pip={charmVisible=false,at=1,writer="old"}}}}
  local c={now=1000,serial=0,writes=0};local adapter={now=function()return c.now end,guid=function()c.serial+=1;return"server-"..c.serial end,
   random=function()error("Hue must not roll RNG")end,wait=function()end}
  adapter.update=function(key,transform)
   c.writes+=1;if c.before then c.before=false;error("Expected fixture: before commit")end
   local result=transform(copy(db[key]));if c.replay then result=transform(copy(db[key]))end
   if result then db[key]=copy(result)end
   if c.after then c.after=false;error("Expected fixture: after commit")end
   return copy(result)
  end
  local h=H.load(1,{},adapter);assert(h.status=="Ready");assert(H.award(h,1,8));assert(H.award(h,2,8))
  return h,db,c,adapter
 end
 local function request(h,action,fields,revision)
  revision=revision or h.state.revision;local p=copy(fields);p.id=p.id or(tostring(revision)..":request-"..tostring(h.state.operationSeq+1))
  return p,revision
 end
 local function buy(h,hue,pet)
  local p,r=request(h,"hue",{petId=pet or"pip",hue=hue or"rose",rank=Hue.get(h.state.hues,pet or"pip").ranks[hue or"rose"]})
  local ok,reason,receipt=H.hueCommand(h,"hue",p,r);assert(ok,reason);return p,r,receipt
 end
 local function equip(h,fields)
  fields.petId=fields.petId or"pip";local p,r=request(h,"hueEquip",fields);local ok,why=H.hueCommand(h,"hueEquip",p,r);assert(ok,why);return p,r
 end
 test("absent v4 namespace stays sparse and purchases atomically preserve old facts",function()
  local h,db,c=fixture();assert(h.state.version==4 and h.state.hues==nil and h.state.hueReceipts==nil)
  local old=copy(h.state);c.replay=true;local _,_,r=buy(h)
  assert(h.state.nectar==old.nectar-8 and r.oldRank==0 and r.newRank==1 and r.cost==8 and r.balanceBefore==old.nectar)
  assert(h.state.inventoryMask==old.inventoryMask and h.state.misses==old.misses and h.state.lastAwardSeq==old.lastAwardSeq)
  assert(db.player_1.custom=="preserved"and not db.player_1.petAppearance.pip.charmVisible and HS.valid(h.state))
  local public=H.public(h);assert(public.hueReceipts==nil and public.lastHueResult.quote==nil and public.lastHueResult.operationId==nil)
 end)
 test("independent learned body and secondary persist without spending or losing Dot",function()
  local h,db=fixture();buy(h);equip(h,{secondary="rose"});buy(h,"tide")
  local row=Hue.get(h.state.hues,"pip");assert(row.body=="tide"and row.secondary=="rose"and row.ranks.rose==1 and row.ranks.tide==1)
  local balance=h.state.nectar;equip(h,{body="original"});assert(h.state.nectar==balance)
  assert(Hue.get(h.state.hues,"pip").ranks.rose==1 and Hue.get(h.state.hues,"puddle").ranks.rose==0)
  local public=Appearance.public({petAppearanceSaved=db.player_1.petAppearance},h.state.hues)
  assert(not public.pip.charmVisible and public.pip.body=="original"and public.pip.secondary=="rose")
  local p,r=request(h,"hueEquip",{petId="puddle",secondary="rose"});local ok,why=H.hueCommand(h,"hueEquip",p,r);assert(not ok and why=="LockedHue")
 end)
 test("paid old-ID replay returns original wallet facts after awards and equip without reverting selections",function()
  local h=fixture();local p,r,saved=buy(h);equip(h,{body="original"});assert(H.award(h,3,8))
  local balance,revision=h.state.nectar,h.state.revision
  local ok,why,again=H.hueCommand(h,"hue",p,r);assert(ok and why=="AlreadySaved"and again.balanceAfter==saved.balanceAfter)
  assert(h.state.nectar==balance and h.state.revision==revision and Hue.get(h.state.hues,"pip").body=="original")
  for _,change in ipairs({{petId="puddle"},{hue="tide"},{rank=1}})do
   local bad=copy(p);for k,v in pairs(change)do bad[k]=v end
   local accepted,reason=H.hueCommand(h,"hue",bad,r);assert(not accepted and reason=="OperationConflict")
  end
  local accepted,reason=H.hueCommand(h,"hueEquip",{id=p.id,petId="pip",body="original"},r);assert(not accepted and reason=="OperationConflict")
  assert(not H.hueCommand(h,"hue",p,revision))
 end)
 test("ambiguous before/after commit retries preserve one quote and a later reconnect proves the old purchase",function()
  for _,failure in ipairs({"before","after"})do
   local h,db,c,adapter=fixture();local p,r=request(h,"hue",{petId="pip",hue="rose",rank=0});local balance=h.state.nectar
   c[failure]=true;local ok,why=H.hueCommand(h,"hue",p,r);assert(not ok and why=="Retrying"and h.state.hues==nil)
   local changed=copy(p);changed.hue="tide";assert(not H.hueCommand(h,"hue",changed,r))
   local pending=h.pending;h.busy=true
   assert(select(2,H.hueCommand(h,"hue",p,r))=="Busy"and h.pending==pending and h.status=="Retrying")
   h.busy=false
   assert(H.retry(h));assert(h.state.nectar==balance-8 and Hue.get(h.state.hues,"pip").ranks.rose==1 and HS.valid(h.state))
   assert(H.release(h));local joined=H.load(1,{},adapter);assert(joined.status=="Ready")
   local replay,_,receipt=H.hueCommand(joined,"hue",p,r);assert(replay and receipt.newRank==1 and joined.state.nectar==balance-8)
  end
 end)
 test("a generic lastOperation ID collision cannot counterfeit paid Saved proof",function()
  local h,db,c=fixture();local p,r=request(h,"hue",{petId="pip",hue="rose",rank=0});c.before=true
  assert(not H.hueCommand(h,"hue",p,r));local pending=h.pending;local state=db.player_1.hatching
  state.operationSeq=pending.sequence;state.revision+=1;state.lastOperation={id=pending.id,sequence=pending.sequence}
  local balance=state.nectar;local ok,why=H.retry(h)
  assert(not ok and why=="RevisionChanged"and h.status=="Ready"and not h.pending)
  assert(h.state.hues==nil and h.state.nectar==balance and db.player_1.hatching.hueReceipts==nil)
 end)
 test("free equip retry is CAS-bound and duplicate receipt cannot switch back after a newer equip",function()
  local h,_,c=fixture();buy(h);local p,r=request(h,"hueEquip",{petId="pip",secondary="rose"})
  c.after=true;assert(not H.hueCommand(h,"hueEquip",p,r));assert(H.retry(h))
  assert(H.hueCommand(h,"hueEquip",p,r));equip(h,{secondary="default"})
  assert(not H.hueCommand(h,"hueEquip",p,r));assert(not H.hueCommand(h,"hueEquip",p,h.state.revision))
  assert(Hue.get(h.state.hues,"pip").secondary=="default")
 end)
 test("all 24 paid ranks cap exactly; new attempts and insufficient wallets do not spend",function()
  local h=fixture();for i=3,35 do assert(H.award(h,i,8))end
  for _,pet in ipairs({"pip","puddle"})do for _,hue in ipairs(Hue.Order)do for _=1,3 do buy(h,hue.id,pet)end end end
  local count=0;for _ in pairs(h.state.hueReceipts)do count+=1 end;assert(count==24 and HS.valid(h.state))
  local p,r=request(h,"hue",{petId="pip",hue="rose",rank=3});local balance=h.state.nectar
  local ok,why=H.hueCommand(h,"hue",p,r);assert(not ok and why=="MaxRank"and h.state.nectar==balance)
  local poor=fixture();buy(poor);buy(poor,"tide");local requestValue,rev=request(poor,"hue",{petId="pip",hue="iris",rank=0})
  local accepted,reason=H.hueCommand(poor,"hue",requestValue,rev);assert(not accepted and reason=="NeedStars")
 end)
 test("malformed present namespaces, arbitrary colors and stale rank/revision reject",function()
  local h,db,_,adapter=fixture();local p,r=request(h,"hue",{petId="pip",hue="rose",rank=1})
  assert(select(2,H.hueCommand(h,"hue",p,r))=="RankChanged")
  p.rank=0;p.color="#ffffff";assert(select(2,H.hueCommand(h,"hue",p,r))=="InvalidHue")
  p.color=nil;p.petId="wick";assert(not H.hueCommand(h,"hue",p,r))
  for _,invalid in ipairs({false,{wick={}}, {pip={ranks={rose=4,tide=0,citrus=0,iris=0},body="original",secondary="default"}},
   {pip={ranks={rose=0,tide=0,citrus=0,iris=0},body="rose",secondary="default"}}})do
   local state=copy(h.state);state.hues=invalid;assert(not HS.valid(state))
  end
  buy(h);local malformed=copy(h.state);malformed.hueReceipts[malformed.lastHueResult.id].quote.action="hatch";assert(not HS.valid(malformed))
  malformed=copy(h.state);malformed.hueReceipts[malformed.lastHueResult.id].balanceAfter+=1;assert(not HS.valid(malformed))
  local unowned=fixture();unowned.state.inventoryMask=Eggs.bit("pip")
  local u,ur=request(unowned,"hue",{petId="puddle",hue="rose",rank=0});assert(select(2,H.hueCommand(unowned,"hue",u,ur))=="Unowned")
  assert(H.release(h));db.player_1.hatching.hues={pip={bad=true}};assert(H.load(1,{},adapter).status=="InvalidData")
 end)
 test("pending pet reveal and expired or foreign leases fence every new hue operation",function()
  local h,db,c=fixture();h.state.lastHatch={id="old-result",petId="pip"};db.player_1.hatching.lastHatch=copy(h.state.lastHatch)
  local p,r=request(h,"hue",{petId="pip",hue="rose",rank=0});assert(select(2,H.hueCommand(h,"hue",p,r))=="RevealPending")
  assert(h.state.lastHatch.id=="old-result"and db.player_1.hatching.lastHatch.id=="old-result")
  h.state.lastHatch=nil;db.player_1.hatching.lastHatch=nil;c.now+=91
  assert(select(2,H.hueCommand(h,"hue",p,r))=="SessionLost")
 end)
 test("actual independent PlayerProgress Dot flush preserves atomic Hue namespace and receipts",function()
  assert(type(progressSource)=="string","argument two must be current PlayerProgress source")
  local h,db=fixture();buy(h);local before=copy(db.player_1.hatching);local realRequire=require
  local store={persistent=false};function store:UpdateAsync(key,transform)db[key]=transform(copy(db[key]));return copy(db[key])end
  local module=Instance.new("ModuleScript");module.Name="_HueProfileFixture";module.Source="return function(e)local game,script,task,require=e.game,e.script,e.task,e.require\n"..progressSource.."\nend";module.Parent=server
  local factory=realRequire(module);module:Destroy();local fakeGame={JobId="hue-profile-fixture"}
  function fakeGame:GetService(name)return game:GetService(name)end;function fakeGame:BindToClose()end
  local progress=factory({game=fakeGame,script=server.PlayerProgress,task={spawn=function()end,defer=function()end},require=function(target)if target==server.ProgressStore then return store end;return realRequire(target)end})
  local profile=progress.fromRecord(1,copy(db.player_1),true);progress.setPetAppearance(profile,"pip",true);progress.setSetting(profile,"sound","Off");assert(progress.flushOnce(profile))
  local after=db.player_1.hatching;assert(after.nectar==before.nectar and after.revision==before.revision and HS.valid(after))
  assert(after.lastHueResult.id==before.lastHueResult.id and after.hues.pip.ranks.rose==1 and db.player_1.petAppearance.pip.charmVisible)
  assert(H.award(h,3,8));assert(db.player_1.petAppearance.pip.charmVisible and HS.valid(db.player_1.hatching))
 end)
 return cases
end
