-- Isolated v5 stock/assignment ledger and historical migration. No live stores.
return function(server)
 local H=require(server.HatchProgress);local HS=require(server.HueState)
 local Shared=game.ReplicatedStorage.Shared;local Hue=require(Shared.HueCatalog);local Eggs=require(Shared.EggCatalog)
 local Appearance=require(server.PetAppearance)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function copy(x)if type(x)~="table"then return x end;local out={};for k,v in pairs(x)do out[k]=copy(v)end;return out end
 local function fixture(rank)
  local db={player_1={rank=rank or 2,custom="preserved",petAppearance={pip={charmVisible=false,at=1,writer="old"}}}}
  local c={now=1000,serial=0,writes=0};local adapter={now=function()return c.now end,guid=function()c.serial+=1;return"server-"..c.serial end,random=function()return .1 end,wait=function()end}
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
 local function request(h,fields,revision)
  revision=revision or h.state.revision;local p=copy(fields);p.id=p.id or(tostring(revision)..":request-"..tostring(h.state.operationSeq+1))
  return p,revision
 end
 local function command(h,action,fields)
  local p,r=request(h,fields);local ok,why,receipt=H.hueCommand(h,action,p,r);assert(ok,why);assert(HS.valid(h.state));return p,r,receipt
 end
 local function buy(h)return command(h,"hueBuy",{})end
 local function apply(h,hue,pet)
  pet=pet or"pip";return command(h,"hueApply",{token=h.state.heldHueEgg.token,petId=pet,hue=hue or"rose",rank=Hue.get(h.state.hues,pet).ranks[hue or"rose"]})
 end
 local function feed(h,hue,pet)buy(h);return apply(h,hue,pet)end
 local function fund(h)for i=3,35 do assert(H.award(h,i,8))end end
 local function legacy(h,db,count)
  assert(H.release(h));local state=db.player_1.hatching
  state.version=4;state.hueAssignments=nil;state.hueLastPurchase=nil;state.heldHueEgg=nil;state.nectar=300
  state.hues={};state.hueReceipts={};local n=0
  for _,pet in ipairs({"pip","puddle"})do for _,offer in ipairs(Hue.Order)do for rank=0,2 do
   if n>=count then return state end;n+=1
   local q={id=tostring(state.revision)..":legacy-"..n,action="hue",petId=pet,hue=offer.id,rank=rank,revision=state.revision}
   local row=Hue.get(state.hues,pet);row.ranks[offer.id]=rank+1;row.body=offer.id;state.hues[pet]=row
   state.operationSeq+=1;state.revision+=1
   local r={id=q.id,action="hue",petId=pet,quote=q,operationId="legacy-op-"..n,sequence=state.operationSeq,revision=state.revision,
    balanceBefore=state.nectar,balanceAfter=state.nectar-8,cost=8,hue=offer.id,oldRank=rank,newRank=rank+1,secondaryUnlocked=rank==0,body=offer.id,secondary=row.secondary}
   state.nectar-=8;state.hueReceipts[q.id]=r;state.lastHueResult=copy(r);state.lastOperation={id=r.operationId,sequence=r.sequence}
  end end end
  return state
 end
 test("generic purchase creates durable unassigned stock without a pet, hue, pity or rank mutation",function()
  local h,db,c=fixture();local old=copy(h.state);c.replay=true;local p,r,receipt=buy(h)
  assert(h.state.version==5 and receipt.action=="hueBuy"and receipt.petId==nil and receipt.hue==nil)
  assert(h.state.nectar==old.nectar-8 and h.state.hues==nil and h.state.heldHueEgg.token==receipt.token)
  assert(h.state.inventoryMask==old.inventoryMask and h.state.misses==old.misses and h.state.totalWins==old.totalWins)
  assert(db.player_1.custom=="preserved"and not db.player_1.petAppearance.pip.charmVisible)
  local before=h.state.nectar;assert(H.hueCommand(h,"hueBuy",p,r));assert(h.state.nectar==before)
  local x,v=request(h,{});local ok,why=H.hueCommand(h,"hueBuy",x,v);assert(not ok and why=="EggHeld"and h.state.heldHueEgg)
 end)
 test("held item survives release/rejoin and assignment advances one chosen baby without another debit",function()
  local h,db,_,adapter=fixture();buy(h);local held=copy(h.state.heldHueEgg);assert(H.release(h));h=H.load(1,{},adapter)
  assert(h.status=="Ready"and h.state.heldHueEgg.token==held.token)
  local balance=h.state.nectar;local p,r,receipt=apply(h,"tide","puddle")
  assert(not h.state.heldHueEgg and h.state.nectar==balance and receipt.cost==0 and receipt.oldRank==0 and receipt.newRank==1)
  assert(Hue.get(h.state.hues,"puddle").ranks.tide==1 and Hue.get(h.state.hues,"pip").ranks.tide==0)
  assert(H.hueCommand(h,"hueApply",p,r));assert(Hue.get(h.state.hues,"puddle").ranks.tide==1)
  local public=Appearance.public({petAppearanceSaved=db.player_1.petAppearance},h.state.hues);assert(not public.pip.charmVisible)
 end)
 test("before and after ambiguous purchase/apply writes retry captured identity exactly once",function()
  for _,action in ipairs({"hueBuy","hueApply"})do for _,failure in ipairs({"before","after"})do
   local h,_,c=fixture();if action=="hueApply"then buy(h)end
   local fields=if action=="hueBuy"then {}else{petId="pip",hue="rose",rank=0,token=h.state.heldHueEgg.token}
   local p,r=request(h,fields);local balance=h.state.nectar;c[failure]=true
   local ok,why=H.hueCommand(h,action,p,r);assert(not ok and why=="Retrying")
   local captured=h.pending;local changed=copy(p);if action=="hueBuy"then changed.petId="pip"else changed.hue="tide"end
   assert(not H.hueCommand(h,action,changed,r));assert(h.pending==captured)
   assert(H.retry(h));assert(HS.valid(h.state));assert(h.state.nectar==balance-(if action=="hueBuy"then 8 else 0))
   assert(H.hueCommand(h,action,p,r));assert(h.state.nectar==balance-(if action=="hueBuy"then 8 else 0))
  end end
 end)
 test("wrong token, stale grade, max grade and unsupported/unowned assignment retain stock",function()
  local h=fixture(1);fund(h);for _=1,3 do feed(h,"rose")end;buy(h)
  for _,case in ipairs({{petId="pip",hue="rose",rank=3},{petId="pip",hue="tide",rank=1},{petId="puddle",hue="tide",rank=0},{petId="wick",hue="tide",rank=0}})do
   case.token=h.state.heldHueEgg.token;local p,r=request(h,case);local before=h.state.nectar;assert(not H.hueCommand(h,"hueApply",p,r));assert(h.state.heldHueEgg and h.state.nectar==before)
  end
  local p,r=request(h,{petId="pip",hue="tide",rank=0,token="wrong"});assert(not H.hueCommand(h,"hueApply",p,r));assert(h.state.heldHueEgg)
 end)
 test("all six mixes are canonical free learned recipes; reset preserves grades, accent unlocks and held egg",function()
  local h,db=fixture();fund(h);for _,offer in ipairs(Hue.Order)do feed(h,offer.id)end
  command(h,"hueEquip",{petId="pip",secondary="iris"});buy(h);local held=h.state.heldHueEgg.token;local balance=h.state.nectar
  for _,key in ipairs(Hue.MixOrder)do local mix=Hue.Mixes[key]
   assert(Hue.pair(mix.a,mix.b)==key and Hue.pair(mix.b,mix.a)==key)
   command(h,"hueMix",{petId="pip",pair=key});assert(Hue.appearance(h.state.hues,"pip").bodyMix==key)
   assert(Hue.appearance(h.state.hues,"pip").bodyRank==1 and Hue.get(h.state.hues,"pip").secondary=="iris")
  end
  command(h,"hueReset",{petId="pip"});local row=Hue.get(h.state.hues,"pip")
  assert(row.body=="original"and row.secondary=="default"and not row.mix and row.ranks.rose==1 and row.ranks.iris==1)
  assert(h.state.nectar==balance and h.state.heldHueEgg.token==held and not db.player_1.petAppearance.pip.charmVisible)
  command(h,"hueEquip",{petId="pip",secondary="iris"});assert(Hue.get(h.state.hues,"pip").secondary=="iris")
 end)
 test("single body clears mixing; independent accent retains mix; apply clears mix and preserves accent",function()
  local h=fixture();fund(h);feed(h,"rose");feed(h,"tide")
  command(h,"hueMix",{petId="pip",pair=Hue.pair("rose","tide")});command(h,"hueEquip",{petId="pip",secondary="rose"});assert(Hue.get(h.state.hues,"pip").mix)
  command(h,"hueEquip",{petId="pip",body="original"});assert(not Hue.get(h.state.hues,"pip").mix)
  command(h,"hueMix",{petId="pip",pair=Hue.pair("rose","tide")});feed(h,"tide");local row=Hue.get(h.state.hues,"pip")
  assert(not row.mix and row.body=="tide"and row.secondary=="rose"and row.ranks.tide==2)
  local p,r=request(h,{petId="puddle",pair=Hue.pair("rose","tide")});assert(not H.hueCommand(h,"hueMix",p,r))
 end)
 test("v4 legacy paid receipts migrate verbatim, remain replayable, and new directional purchases close",function()
  local h,db,_,adapter=fixture();local state=legacy(h,db,2);local original=copy(state);assert(HS.validLegacy(state))
  h=H.load(1,{},adapter);assert(h.status=="Ready"and h.state.version==5 and HS.valid(h.state))
  for id,r in pairs(original.hueReceipts)do
   local saved=h.state.hueReceipts[id];assert(saved.balanceBefore==r.balanceBefore and saved.operationId==r.operationId and HS.same(saved.quote,r.quote))
   local fields={id=r.id,petId=r.petId,hue=r.hue,rank=r.oldRank};local balance=h.state.nectar;assert(H.hueCommand(h,"hue",fields,r.quote.revision));assert(h.state.nectar==balance)
  end
  local p,r=request(h,{petId="pip",hue="tide",rank=0});local ok,why=H.hueCommand(h,"hue",p,r);assert(not ok and why=="LegacyPurchaseClosed")
  feed(h,"tide");assert(HS.valid(h.state));assert(H.release(h));h=H.load(1,{},adapter);assert(h.status=="Ready"and HS.valid(h.state))
 end)
 test("full 24-slot historical records preserve paid grades and disallow buying exhausted stock",function()
  local h,db,_,adapter=fixture();legacy(h,db,24);h=H.load(1,{},adapter);assert(h.status=="Ready"and HS.valid(h.state)and not Hue.capacity(h.state))
  local p,r=request(h,{});local balance=h.state.nectar;local ok,why=H.hueCommand(h,"hueBuy",p,r);assert(not ok and why=="NoCapacity"and h.state.nectar==balance)
 end)
 test("v2 and v3 upgrades twice preserve ownership, wallet, pending duplicate and mastery archive",function()
  for _,version in ipairs({2,3})do
   local h,db,_,adapter=fixture();assert(H.release(h));local state=db.player_1.hatching
   state.version=version;state.hueAssignments=nil;state.petDay=nil;state.petCount=nil;state.lastPetAward=nil
   state.lastHatch={id="historical-pending",petId="pip",duplicate=true,mastery=2,recipe="meadow"};state.mastery.pip=2
   if version==2 then state.masteryChallenges=nil;state.masteryLegacyMask=nil;state.totalWins=nil;state.contracts=nil end
   local balance,mask=state.nectar,state.inventoryMask
   h=H.load(1,{},adapter);assert(h.status=="Ready"and h.state.version==5 and h.state.mastery.pip==2 and h.state.nectar==balance and h.state.inventoryMask==mask)
   assert(h.state.lastHatch.id=="historical-pending"and h.state.lastHatch.mastery==2)
   assert(H.release(h));h=H.load(1,{},adapter);assert(h.status=="Ready"and h.state.nectar==balance and h.state.mastery.pip==2)
  end
 end)
 test("malformed v4 fails closed without writing defaults over original fields",function()
  for _,kind in ipairs({"missing-proof","bad-stock-namespace","bad-ranks"})do
   local h,db,_,adapter=fixture();local state=legacy(h,db,1)
   if kind=="missing-proof"then state.hueReceipts={}elseif kind=="bad-stock-namespace"then state.heldHueEgg={}else state.hues.pip.ranks.rose=4 end
   local before=copy(state);h=H.load(1,{},adapter);assert(h.status=="InvalidData"and db.player_1.hatching.version==4 and db.player_1.hatching.nectar==before.nectar)
  end
 end)
 test("companion hatches coexist with held stock and duplicates grant no mastery; saved wins remain independent",function()
  local h=fixture();fund(h);buy(h);local token=h.state.heldHueEgg.token;local marks=h.state.mastery.pip
  local ok,why=H.command(h,"hatch","sprout",h.state.revision);assert(ok,why)
  assert(h.state.lastHatch.duplicate and h.state.mastery.pip==marks and h.state.heldHueEgg.token==token)
  local p,r=request(h,{token=token,petId="pip",hue="rose",rank=0});assert(not H.hueCommand(h,"hueApply",p,r));assert(h.state.heldHueEgg)
  assert(H.command(h,"ack",h.state.lastHatch.id,h.state.revision));apply(h,"rose")
  local oldWins=h.state.totalWins;local summary={family="pip",day=h.state.dailyClaimDay,success=true,clean=true,score=600,chain=4,clears=1,drops=24}
  assert(H.award(h,36,8,summary));assert(h.state.mastery.pip==marks and h.state.masteryChallenges.pip==0 and h.state.totalWins==oldWins+1 and h.state.lastRunReward.masteryPoints==0)
  assert(H.award(h,36,8,summary));assert(h.state.totalWins==oldWins+1)
 end)
 test("later stock cannot be consumed by old apply replay or same-ID altered quote",function()
  local h=fixture();fund(h);local p,r=feed(h,"rose");buy(h);local token=h.state.heldHueEgg.token
  assert(H.hueCommand(h,"hueApply",p,r));assert(h.state.heldHueEgg.token==token and Hue.get(h.state.hues,"pip").ranks.rose==1)
  local altered=copy(p);altered.hue="tide";local ok,why=H.hueCommand(h,"hueApply",altered,r);assert(not ok and why=="OperationConflict"and h.state.heldHueEgg.token==token)
 end)
 test("new and legacy assignment slots share one 24-grade cap without fabricated old purchases",function()
  local h,db,_,adapter=fixture();legacy(h,db,23);h=H.load(1,{},adapter);assert(h.status=="Ready")
  local oldCount=0;for _ in pairs(h.state.hueReceipts)do oldCount+=1 end
  feed(h,"iris","puddle");assert(HS.valid(h.state)and not Hue.capacity(h.state))
  local newCount=0;for _ in pairs(h.state.hueAssignments)do newCount+=1 end
  assert(oldCount==23 and newCount==1)
  h=fixture();fund(h)
  for _,pet in ipairs({"pip","puddle"})do for _,hue in ipairs(Hue.Order)do for _=1,3 do feed(h,hue.id,pet)end end end
  local count=0;for _ in pairs(h.state.hueAssignments)do count+=1 end
  assert(count==24 and h.state.hueReceipts==nil and HS.valid(h.state)and not Hue.capacity(h.state))
 end)
 test("session takeover fences an uncommitted purchase without losing held stock committed before takeover",function()
  for _,failure in ipairs({"before","after"})do
   local h,db,c,adapter=fixture();local p,r=request(h,{});local balance=h.state.nectar;c[failure]=true
   assert(not H.hueCommand(h,"hueBuy",p,r));local saved=db.player_1.hatching
   saved.epoch+=1;saved.lease={token="other-session",expiresAt=c.now+90}
   local ok,why=H.retry(h);assert(not ok and why=="SessionLost")
   c.now+=100;local joined=H.load(1,{},adapter);assert(joined.status=="Ready")
   assert(joined.state.nectar==balance-(if failure=="after"then 8 else 0))
   assert((joined.state.heldHueEgg~=nil)==(failure=="after"))
   if failure=="after"then assert(H.hueCommand(joined,"hueBuy",p,r))end
  end
 end)
 test("overlapping new quotes cannot replace a captured immutable buy or apply candidate",function()
  local h,_,c=fixture();local p,r=request(h,{});c.before=true;assert(not H.hueCommand(h,"hueBuy",p,r));local pending=h.pending
  local other=copy(p);other.id=tostring(r)..":other-buy"
  assert(not H.hueCommand(h,"hueBuy",other,r)and h.pending==pending);assert(H.retry(h))
  p,r=request(h,{petId="pip",hue="rose",rank=0,token=h.state.heldHueEgg.token});c.before=true;assert(not H.hueCommand(h,"hueApply",p,r));pending=h.pending
  other=copy(p);other.petId="puddle";assert(not H.hueCommand(h,"hueApply",other,r)and h.pending==pending)
  assert(H.retry(h)and Hue.get(h.state.hues,"pip").ranks.rose==1 and Hue.get(h.state.hues,"puddle").ranks.rose==0)
 end)
 return{passed=#cases,cases=cases}
end
