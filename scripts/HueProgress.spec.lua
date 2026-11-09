-- v6 item inventory, immutable legacy rights, durable roll reservation. Isolated stores only.
return function(server)
 local H=require(server.HatchProgress);local S=require(server.HueState);local L=require(server.LegacyHueState)
 local Shared=game.ReplicatedStorage.Shared;local Hue=require(Shared.HueCatalog);local Palette=require(Shared.PetPalette)
 local cases={};local function test(name,f)f();table.insert(cases,name)end
 local function copy(x)if type(x)~="table"then return x end;local r={};for k,v in pairs(x)do r[k]=copy(v)end;return r end
 local function fixture(rank)
  local db={player_1={rank=rank or 4,trials=31,custom="kept",petAppearance={pip={charmVisible=false,at=1,writer="old"}}}}
  local c={now=1000,n=0,rolls=0,unit=.01,updates=0}
  local a={now=function()return c.now end,guid=function()c.n+=1;return"server-"..c.n end,random=function()c.rolls+=1;return c.unit end,wait=function()end}
  a.update=function(key,transform)
   c.updates+=1
   if c.before then c.before=false;error("Expected fixture: before write")end
   local output=transform(copy(db[key]))
   if c.callbackReplay then output=transform(copy(db[key]))end
   if output then db[key]=copy(output)end
   if c.after then c.after=false;error("Expected fixture: after write")end
   if c.failSettlement and db[key].hatching.hueReservation then c.failSettlement=false;c.before=true end
   return copy(output)
  end
  local h=H.load(1,{},a);assert(h.status=="Ready");assert(H.award(h,1,8));assert(H.award(h,2,8))
  return h,db,c,a
 end
 local function request(h,fields,revision)
  local r=revision or h.state.revision;local v=copy(fields or{});v.id=v.id or(tostring(r)..":test-"..tostring(h.state.operationSeq+1));v.catalogVersion=Hue.CatalogVersion;return v,r
 end
 local function command(h,action,fields)
  local q,r=request(h,fields);local ok,why,receipt=H.hueCommand(h,action,q,r);assert(ok,why);assert(S.valid(h.state),"invalid state after "..action);return q,r,receipt
 end
 local function store(h)return command(h,"hueStore",{resultId=h.state.pendingHueResult.id})end
 local function buy(h,c,id)
  local index=table.find(Hue.ItemOrder,id or"rose");c.unit=(index-.5)/5
  local q,r,receipt=command(h,"hueBuy",{});assert(receipt.itemId==(id or"rose"));return q,r,receipt
 end
 local function use(h,item,pet,channel,pending)
  pet,channel=pet or"pip",channel or"main"
  return command(h,"hueUse",{itemId=item,petId=pet,channel=channel,counts=S.row(h.state,pet)[channel],pendingResultId=if pending then h.state.pendingHueResult.id else nil})
 end
 local function fund(h)for n=3,70 do assert(H.award(h,n,8))end end
 local function makeLegacy(db,mode,count)
  local state=db.player_1.hatching
  state.version=5;for _,k in ipairs({"materialUnlocks","petMaterials","materialReceipts","materialReceiptOrder","materialReservation","pendingMaterialResult","lastMaterialResult","petHues","hueInventory","hueItemReceipts","hueReceiptOrder","hueMigrationId","hueMigrationAcknowledged","legacyHueEgg","legacyHueRedemption","legacyLastHueResult","lastHueResult","pendingHueResult","hueReservation"})do state[k]=nil end
  state.hues={};state.hueReceipts={};state.hueAssignments={};state.lease.expiresAt=0
  for n=1,count or 2 do
   local pet=if n<=12 then "pip"else "puddle";local hue=Hue.Order[math.floor(((n-1)%12)/3)+1].id;local rank=(n-1)%3
   local q={id=tostring(state.revision)..":old-"..n,action="hue",petId=pet,hue=hue,rank=rank,revision=state.revision}
   local row=Hue.get(state.hues,pet);row.ranks[hue]=rank+1;row.body=hue;state.hues[pet]=row
   state.revision+=1;state.operationSeq+=1
   local receipt={id=q.id,action="hue",petId=pet,quote=q,operationId="old-op-"..n,sequence=state.operationSeq,revision=state.revision,cost=8,
    balanceBefore=state.nectar,balanceAfter=state.nectar-8,hue=hue,oldRank=rank,newRank=rank+1,secondaryUnlocked=rank==0,body=hue,secondary="default"}
   state.nectar-=8;state.hueReceipts[q.id]=receipt;state.lastHueResult=copy(receipt);state.lastOperation={id=receipt.operationId,sequence=receipt.sequence}
  end
  if mode=="held"then
   local q={id=tostring(state.revision)..":old-buy",action="hueBuy",revision=state.revision}
   state.revision+=1;state.operationSeq+=1
   local receipt={id=q.id,action="hueBuy",quote=q,operationId="old-held-token",sequence=state.operationSeq,revision=state.revision,cost=8,balanceBefore=state.nectar,balanceAfter=state.nectar-8,token="old-held-token",purchaseId=q.id}
   state.nectar-=8;state.hueLastPurchase=receipt;state.heldHueEgg={token=receipt.token,purchaseId=q.id};state.lastHueResult=copy(receipt);state.lastOperation={id=receipt.operationId,sequence=receipt.sequence}
  end
  assert(L.valid(state));return state
 end
 test("fresh v6 has five private stacks and seven independent color capabilities",function()
  local h,db=fixture();assert(h.state.version==7 and S.valid(h.state));assert(db.player_1.custom=="kept"and not db.player_1.petAppearance.pip.charmVisible)
  for _,item in ipairs(Hue.ItemOrder)do assert(h.state.hueInventory[item]==0)end
  local p=H.public(h);assert(not p.hueReservation and not p.hueItemReceipts and not p.hueReceiptOrder)
  for pet in pairs(Hue.Supported)do assert(Palette.resolve(pet,{mainDoses=Hue.emptyCounts(),secondaryDoses=Hue.emptyCounts()}))end
 end)
 test("each 20-percent server roll stores exactly one item, one debit and no companion pity change",function()
  local h,_,c=fixture();fund(h);c.callbackReplay=true
  for _,item in ipairs(Hue.ItemOrder)do local before=h.state.nectar;local misses=h.state.misses;local _,_,r=buy(h,c,item)
   assert(h.state.nectar==before-8 and r.inventoryAfter==1 and h.state.hueInventory[item]==1 and h.state.misses==misses);store(h)
  end
  assert(c.rolls==5)
 end)
 test("stored duplicates stack, pending results block new purchases and result use acknowledges once",function()
  local h,_,c=fixture();buy(h,c,"rose");local pending=h.state.pendingHueResult.id
  local q,r=request(h,{});assert(not H.hueCommand(h,"hueBuy",q,r));store(h);buy(h,c,"rose");assert(h.state.hueInventory.rose==2)
  local before=h.state.nectar;local useQ,useRev=use(h,"rose","puddle","secondary",true)
  assert(h.state.hueInventory.rose==1 and h.state.petHues.puddle.secondary.rose==1 and h.state.nectar==before and not h.state.pendingHueResult)
  assert(H.hueCommand(h,"hueUse",useQ,useRev));assert(h.state.hueInventory.rose==1)
  local altered=copy(useQ);altered.pendingResultId=pending;local ok,why=H.hueCommand(h,"hueUse",altered,useRev);assert(not ok and why=="OperationConflict")
 end)
 test("five-dose cap and reset affect exactly one channel, reject empty/noop/stale use without spend",function()
  local h,_,c=fixture();fund(h)
  for _=1,5 do buy(h,c,"rose");use(h,"rose","pip","main",true)end
  buy(h,c,"rose");store(h);local q,r=request(h,{itemId="rose",petId="pip",channel="main",counts=S.row(h.state,"pip").main});local stock=h.state.hueInventory.rose
  local ok,why=H.hueCommand(h,"hueUse",q,r);assert(not ok and why=="MaxDose"and h.state.hueInventory.rose==stock)
  buy(h,c,"tide");use(h,"tide","pip","secondary",true);buy(h,c,"reset");use(h,"reset","pip","main",true)
  assert(Hue.doseStrength(h.state.petHues.pip.main)==0 and h.state.petHues.pip.secondary.tide==1 and h.state.hueInventory.rose==stock)
  buy(h,c,"reset");store(h);q,r=request(h,{itemId="reset",petId="pip",channel="main",counts=Hue.emptyCounts()});ok,why=H.hueCommand(h,"hueUse",q,r);assert(not ok and why=="AlreadyOriginal"and h.state.hueInventory.reset==1)
 end)
 test("reservation and settlement retry the frozen draw before and after ambiguous writes",function()
  for _,phase in ipairs({"before","after","settlement"})do local h,_,c=fixture();local balance=h.state.nectar
   if phase=="settlement"then c.failSettlement=true else c[phase]=true end
   local q,r=request(h,{});local ok,why=H.hueCommand(h,"hueBuy",q,r);assert(not ok and why=="Retrying")
   local rollCount=c.rolls;c.unit=.99;assert(H.retry(h));assert(c.rolls==rollCount and h.state.hueInventory.rose==1 and h.state.nectar==balance-8 and not h.state.hueReservation)
   assert(H.hueCommand(h,"hueBuy",q,r));assert(c.rolls==rollCount and h.state.nectar==balance-8)
  end
 end)
 test("durable reservation survives writer takeover and settles its original result once",function()
  local h,db,c,a=fixture();c.failSettlement=true;local q,r=request(h,{});local balance=h.state.nectar
  assert(not H.hueCommand(h,"hueBuy",q,r));assert(db.player_1.hatching.hueReservation and db.player_1.hatching.hueInventory.rose==0)
  c.now+=100;c.unit=.99;local joined=H.load(1,{},a);assert(joined.status=="Ready"and joined.state.hueInventory.rose==1 and joined.state.nectar==balance-8 and c.rolls==1)
  assert(H.hueCommand(joined,"hueBuy",q,r));assert(joined.state.hueInventory.rose==1)
  assert(not H.retry(h));assert(h.status=="SessionLost")
 end)
 test("v5 grades map exactly, frozen receipts replay after reset, presets lock only after new pigment",function()
  local h,db,c,a=fixture();fund(h);assert(H.release(h));local old=makeLegacy(db,nil,5)
  old.hues.pip.mix="rose:tide";old.hues.pip.secondary="rose";local snapshot=copy(old)
  h=H.load(1,{},a);assert(h.status=="Ready"and h.state.version==7 and h.state.petHues.pip.main.rose==3 and h.state.petHues.pip.main.tide==3 and h.state.petHues.pip.secondary.rose==5)
  local before=Palette.resolve("pip",Hue.appearance(snapshot.hues,"pip"));local after=Palette.resolve("pip",Hue.appearance(h.state.hues,"pip",h.state.petHues))
  assert((Vector3.new(before.body.R,before.body.G,before.body.B)-Vector3.new(after.body.R,after.body.G,after.body.B)).Magnitude<.00001)
  command(h,"hueLegacyPreset",{migrationId=h.state.hueMigrationId,petId="pip",channel="main",presetId="rose",counts=S.row(h.state,"pip").main,locked=false})
  buy(h,c,"tide");use(h,"tide","pip","main",true)
  local q,r=request(h,{migrationId=h.state.hueMigrationId,petId="pip",channel="main",presetId="rose:tide",counts=S.row(h.state,"pip").main,locked=true});local ok,why=H.hueCommand(h,"hueLegacyPreset",q,r);assert(not ok and why=="LegacyLocked")
  buy(h,c,"reset");use(h,"reset","pip","main",true)
  command(h,"hueLegacyPreset",{migrationId=h.state.hueMigrationId,petId="pip",channel="main",presetId="rose:tide",counts=S.row(h.state,"pip").main,locked=false})
  for _,receipt in pairs(snapshot.hueReceipts)do local quote=receipt.quote;assert(H.hueCommand(h,"hue",{id=quote.id,petId=quote.petId,hue=quote.hue,rank=quote.rank},quote.revision))end
  assert(S.valid(h.state)and Hue.equalCounts(h.state.petHues.pip.main,{rose=3,tide=3,citrus=0,iris=0}))
 end)
 test("held legacy token redeems exactly once without roll/debit and original buy proof survives",function()
  local h,db,c,a=fixture();assert(H.release(h));local old=copy(makeLegacy(db,"held",1));h=H.load(1,{},a)
  local balance=h.state.nectar;local q,r=command(h,"hueLegacyRedeem",{migrationId=h.state.hueMigrationId,token=h.state.legacyHueEgg.token,purchaseId=h.state.legacyHueEgg.purchaseId,itemId="iris"})
  assert(h.state.hueInventory.iris==1 and not h.state.legacyHueEgg and h.state.nectar==balance and c.rolls==0)
  assert(H.hueCommand(h,"hueLegacyRedeem",q,r));assert(h.state.hueInventory.iris==1)
  local oldQ=old.hueLastPurchase.quote;assert(H.hueCommand(h,"hueBuy",{id=oldQ.id},oldQ.revision));assert(h.state.hueInventory.iris==1)
 end)
 test("invalid v5 proof or fabricated old seven-rig ranks fail closed; all 24 old slots remain valid",function()
  for _,bad in ipairs({"missing","wick"})do local h,db,_,a=fixture();fund(h);assert(H.release(h));local old=makeLegacy(db,nil,1)
   if bad=="missing"then old.hueReceipts={}else old.hues.wick=copy(old.hues.pip)end
   h=H.load(1,{},a);assert(h.status=="InvalidData"and db.player_1.hatching.version==5)
  end
  local h,db,_,a=fixture();fund(h);assert(H.release(h));makeLegacy(db,nil,24);h=H.load(1,{},a);assert(h.status=="Ready"and S.valid(h.state))
  assert(H.release(h));local original=copy(db.player_1.hatching.petHues);h=H.load(1,{},a);for pet,row in pairs(original)do assert(Hue.equalCounts(row.main,h.state.petHues[pet].main))end
 end)
 test("v2 v3 v4 migrate once while pending Focused duplicate and sparse ownership survive",function()
  for _,version in ipairs({2,3,4})do local h,db,_,a=fixture(1);assert(H.release(h));local old=makeLegacy(db,nil,0)
   old.version=version;old.hueAssignments=nil;old.lastHatch={id="old-focused",petId="pip",duplicate=true,recipe="sprout",mastery=2}
   if version<4 then old.petDay=nil;old.petCount=nil;old.lastPetAward=nil end
   if version==2 then old.masteryChallenges=nil;old.masteryLegacyMask=nil;old.totalWins=nil;old.contracts=nil end
   local balance=old.nectar;h=H.load(1,{},a);assert(h.status=="Ready"and h.state.version==7 and h.state.nectar==balance and h.state.lastHatch.id=="old-focused")
   assert(H.command(h,"ack","old-focused",h.state.revision));local ok,why=H.command(h,"hatch","sprout",h.state.revision);assert(not ok and why=="RetiredEgg")
  end
 end)
 test("bounded receipt eviction and capacity refusal cannot reroll, replay old uses, or debit",function()
  local h,_,c=fixture();fund(h);buy(h,c,"rose");store(h)
  for _=1,40 do buy(h,c,"tide");store(h)end
  assert(#h.state.hueReceiptOrder==S.ReceiptLimit and S.valid(h.state))
  h.state.hueInventory.iris=Hue.StackLimit -- next write uses fixture DB below in separate case
  local h2,db,c2=fixture();db.player_1.hatching.hueInventory.iris=Hue.StackLimit;h2.state.hueInventory.iris=Hue.StackLimit;c2.unit=.7
  local balance=h2.state.nectar;local q,r,receipt=command(h2,"hueBuy",{})
  assert(receipt.outcome=="Refused"and receipt.reason=="StackLimit"and h2.state.nectar==balance and not h2.state.pendingHueResult)
  local rolls=c2.rolls;assert(H.hueCommand(h2,"hueBuy",q,r));assert(c2.rolls==rolls and h2.state.nectar==balance)
 end)
 test("malformed vectors, stale stock and unknown payload fields do not block genuine subsequent operation",function()
  local h,_,c=fixture();buy(h,c,"rose");store(h)
  for _,bad in ipairs({{rose=-1,tide=0,citrus=0,iris=0},{rose=0/0,tide=0,citrus=0,iris=0},{rose=.5,tide=0,citrus=0,iris=0}})do
   local q,r=request(h,{itemId="rose",petId="pip",channel="main",counts=bad});assert(not H.hueCommand(h,"hueUse",q,r)and not h.pending)
  end
  local q,r=request(h,{itemId="rose",petId="pip",channel="main",counts={rose=1,tide=0,citrus=0,iris=0}});assert(not H.hueCommand(h,"hueUse",q,r));use(h,"rose")
 end)
 test("each seven-pet channel can consume independently without changing equip, charm, sibling channel or ownership",function()
  local h,db,c=fixture();fund(h);local mask=h.state.inventoryMask
  for pet in pairs(Hue.Supported)do for _,channel in ipairs({"main","secondary"})do
   buy(h,c,"iris");use(h,"iris",pet,channel,true)
   assert(S.row(h.state,pet)[channel].iris==1 and h.state.inventoryMask==mask and db.player_1.petAppearance.pip.charmVisible==false)
  end end
 end)
 test("two uses of last jar at one revision have one winner and rejected request cannot strand next intent",function()
  local h,_,c=fixture();buy(h,c,"rose");store(h)
  local first,revision=request(h,{itemId="rose",petId="pip",channel="main",counts=Hue.emptyCounts()})
  local second=copy(first);second.id=tostring(revision)..":other-use";second.petId="puddle"
  assert(H.hueCommand(h,"hueUse",first,revision));local ok,why=H.hueCommand(h,"hueUse",second,revision)
  assert(not ok and why=="RevisionChanged"and h.state.hueInventory.rose==0 and S.row(h.state,"puddle").main.rose==0 and not h.pending)
  buy(h,c,"tide");use(h,"tide","puddle","secondary",true)
 end)
 test("v5 zero-cost assignments retain their exact token proof after upgrade and later reset",function()
  local h,db,c,a=fixture();fund(h);assert(H.release(h));local old=makeLegacy(db,nil,0)
  local function legacyCommand(action,fields)
   local revision=old.revision;fields.id=tostring(revision)..":old-"..action
   local q=L.quote(action,fields,revision);local candidate={quote=q,operationId="legacy-"..action,sequence=old.operationSeq+1}
   assert(L.apply(old,candidate));old.revision+=1;old.operationSeq+=1;old.lastOperation={id=candidate.operationId,sequence=candidate.sequence};assert(L.valid(old));return copy(fields),revision
  end
  legacyCommand("hueBuy",{});local payload,revision=legacyCommand("hueApply",{token=old.heldHueEgg.token,petId="pip",hue="tide",rank=0})
  h=H.load(1,{},a);assert(h.status=="Ready"and S.row(h.state,"pip").main.tide==2)
  buy(h,c,"reset");use(h,"reset","pip","main",true);local stock=copy(h.state.hueInventory)
  assert(H.hueCommand(h,"hueApply",payload,revision));assert(S.row(h.state,"pip").main.tide==0 and h.state.hueInventory.reset==stock.reset)
 end)
 test("corrupt v6 counts ownership receipts and rolled reservations fail validation without repairs",function()
  local h=fixture();local good=copy(h.state)
  for _,bad in ipairs({"fractional","foreign","negative-stock","sparse-vector","unreserved-roll"})do local state=copy(good)
   if bad=="fractional"then state.petHues.pip={main={rose=.5,tide=0,citrus=0,iris=0},secondary=Hue.emptyCounts(),legacyLocked={main=false,secondary=false}}
   elseif bad=="foreign"then state.inventoryMask=1;state.petHues.wick={main=Hue.emptyCounts(),secondary=Hue.emptyCounts(),legacyLocked={main=false,secondary=false}}
   elseif bad=="negative-stock"then state.hueInventory.reset=-1
   elseif bad=="sparse-vector"then state.petHues.pip={main={},secondary=Hue.emptyCounts(),legacyLocked={main=false,secondary=false}}
   else state.hueReservation={quote={action="hueBuy",id="bad",revision=state.revision,catalogVersion=Hue.CatalogVersion},operationId="bad-op",sequence=state.operationSeq+1,itemId="unknown"}end
   assert(not S.valid(state),bad)
  end
 end)
 test("migration notice acknowledgment persists and historical entitlements cannot lose marker rows or held-token proof",function()
  local h,db,_,a=fixture();assert(H.release(h));makeLegacy(db,"held",1);h=H.load(1,{},a)
  assert(not H.public(h).hueMigrationAcknowledged)
  local q,r=command(h,"hueMigrationAck",{migrationId=h.state.hueMigrationId});assert(H.public(h).hueMigrationAcknowledged)
  assert(H.hueCommand(h,"hueMigrationAck",q,r));assert(H.release(h));h=H.load(1,{},a);assert(H.public(h).hueMigrationAcknowledged)
  for _,kind in ipairs({"marker","row","token"})do local bad=copy(h.state)
   if kind=="marker"then bad.hueMigrationId=nil elseif kind=="row"then bad.petHues.pip=nil else bad.legacyHueEgg=nil end
   assert(not S.valid(bad),kind)
  end
 end)
 test("a sparse Ovelle-only veteran can buy and apply without owning the welcome pet",function()
  local h,db,c,a=fixture();assert(H.release(h));db.player_1.hatching.inventoryMask=require(Shared.EggCatalog).bit("puddle")
  h=H.load(1,{},a);assert(h.status=="Ready");buy(h,c,"tide");use(h,"tide","puddle","main",true);assert(S.row(h.state,"puddle").main.tide==1)
 end)
 return{passed=#cases,cases=cases,persistentWrites=false}
end
