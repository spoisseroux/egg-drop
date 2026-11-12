-- Current fenced backend, isolated root records only; never real user writes.
return function(server)
 local H=require(server.HatchProgress);local S=require(server.MaterialState);local Hue=require(server.HueState)
 local C=require(game.ReplicatedStorage.Shared.MaterialCatalog);local cases={}
 local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
 local function same(a,b)return S.same(a,b)end
 local function fixture()
  local db={player_1={rank=4,trials=31,custom="kept",petAppearance={pip={charmVisible=false,charmShape="ring",at=1,writer="old"}}}}
  local c={now=1000,serial=0,rolls=0,writes=0,unit=0,quoteSerial=0}
  local a={now=function()return c.now end,guid=function()c.serial+=1;return "material-guid-"..c.serial end,random=function()c.rolls+=1;return c.unit end,wait=function()end}
  a.update=function(key,transform)
   c.writes+=1;if c.failBefore then c.failBefore=false;error("Expected Material before-write failure")end
   local old=copy(db[key]);local output=transform(copy(db[key]))
   if c.callbackReplay then output=transform(copy(db[key]))end
   if output then db[key]=copy(output)end
   if c.failAfter then c.failAfter=false;error("Expected Material committed response loss")end
   if c.failSettlement and old and old.hatching.materialReservation and output and not output.hatching.materialReservation then c.failSettlement=false;error("Expected Material settlement response loss")end
   if c.blockSettlement and output and output.hatching.materialReservation then c.blockSettlement=false;c.failBefore=true end
   return copy(output)
  end
  local h=H.load(1,{},a);assert(h.status=="Ready"and h.state.version==9)
  for n=1,8 do assert(H.award(h,n,8))end
  return h,db,c,a
 end
 local function quote(h,c,fields)
  c.quoteSerial+=1;local r=h.state.revision;local value=copy(fields);value.id=tostring(r)..":material-test-"..c.quoteSerial;value.catalogVersion=C.CatalogVersion;return value,r
 end
 local function command(h,c,action,fields)
  local value,r=quote(h,c,fields);local ok,why,receipt=H.materialCommand(h,action,value,r);assert(ok,why);assert(S.valid(h.state)and Hue.valid(h.state),"invalid state after "..action);return value,r,receipt
 end
 local function buy(h,c)return command(h,c,"materialBuy",{poolVersion=C.PoolVersion,eligible=C.remaining(h.state.materialUnlocks)})end
 local function ack(h,c)return command(h,c,"materialAck",{resultId=h.state.pendingMaterialResult.id})end
 local function test(name,run)run();table.insert(cases,name)end
 test("v6 migration preserves frozen Hue fields proofs and root siblings exactly",function()
  local h,db,c,a=fixture();assert(H.release(h));local old=db.player_1.hatching
  old.version=6;old.quests=nil;old.contracts={day="20",progress={runs=0,chain=0,score=0},claimedMask=0};for _,k in ipairs({"toyUnlocks","petToys","toyReceipts","toyReceiptOrder","toyReservation","pendingToyResult","lastToyResult","featureStock","petFeatures","featureReceipts","featureReceiptOrder","featureReservation","pendingFeatureResult","lastFeatureResult","materialUnlocks","petMaterials","materialReceipts","materialReceiptOrder","pendingMaterialResult","materialReservation","lastMaterialResult"})do old[k]=nil end
  assert(Hue.valid(old));local preserved=copy(old)
  h=H.load(1,{},a);assert(h.status=="Ready"and h.state.version==9 and next(h.state.materialUnlocks)==nil)
  for _,k in ipairs({"nectar","inventoryMask","hues","petHues","hueInventory","hueItemReceipts","hueReceiptOrder","hueMigrationId","hueMigrationAcknowledged","heldHueEgg","legacyHueEgg","legacyHueRedemption","legacyLastHueResult","misses","operationSeq","lastAwardSeq","lastRunReward"})do assert(same(h.state[k],preserved[k]),"v6 field changed "..k)end
  assert(db.player_1.custom=="kept"and not db.player_1.petAppearance.pip.charmVisible and db.player_1.petAppearance.pip.charmShape=="ring")
 end)
 test("v6 cannot smuggle a preexisting Material namespace into the v7 upgrade",function()
  local h,db,_,a=fixture();assert(H.release(h));db.player_1.hatching.version=6
  local refused=H.load(1,{},a);assert(refused.status=="InvalidData"and db.player_1.hatching.version==6)
 end)
 test("two sorted remaining-only rolls debit16 once each and exhausted pool never spends",function()
  local h,_,c=fixture();local initial=h.state.nectar
  for i,id in ipairs({"gloss","matte"})do
   local pool=C.remaining(h.state.materialUnlocks);local odds=C.odds(h.state.materialUnlocks);assert(#pool==3-i and pool[1]==id)
   for _,row in ipairs(odds)do assert(row.probability==1/#pool)end
   local _,_,receipt=buy(h,c);assert(receipt.finishId==id and receipt.cost==16 and h.state.materialUnlocks[id]and h.state.pendingMaterialResult.finishId==id);ack(h,c)
  end
  assert(h.state.nectar==initial-32 and c.rolls==2)
  local value,r=quote(h,c,{poolVersion=C.PoolVersion,eligible={"gloss"}});local writes=c.writes
  local ok,why=H.materialCommand(h,"materialBuy",value,r);assert(not ok and why=="AllUnlocked"and c.writes==writes and c.rolls==2)
 end)
 test("exact saved replay is read-only and same-ID changed quote is a conflict",function()
  local h,_,c=fixture();local q,r,receipt=buy(h,c);local balance,rolls,writes=h.state.nectar,c.rolls,c.writes
  assert(H.materialCommand(h,"materialBuy",q,r));assert(h.state.nectar==balance and c.rolls==rolls and c.writes==writes)
  local wrong=copy(q);wrong.eligible={"gloss"};local ok,why=H.materialCommand(h,"materialBuy",wrong,r);assert(not ok and why=="OperationConflict")
  assert(not receipt.operationId and not receipt.sequence and not receipt.quote,"private grant proof leaked to client")
 end)
 test("reserve and settlement ambiguous responses retain one winner and one debit",function()
  for _,phase in ipairs({"reserve","settle"})do
   local h,db,c=fixture();local before=h.state.nectar;local q,r=quote(h,c,{poolVersion=C.PoolVersion,eligible=C.remaining(h.state.materialUnlocks)})
   if phase=="reserve"then c.failAfter=true else c.failSettlement=true end
   local ok,why=H.materialCommand(h,"materialBuy",q,r);assert(not ok and why=="Retrying"and h.pending and c.rolls==1)
   local candidate=copy(h.pending.candidate);assert(H.materialCommand(h,"materialBuy",q,r))
   assert(c.rolls==1 and h.state.nectar==before-16 and h.state.materialUnlocks[candidate.finishId])
   assert(db.player_1.hatching.materialReceipts[q.id].operationId==candidate.operationId and H.materialCommand(h,"materialBuy",q,r))
  end
 end)
 test("durable reservation resumes after release/rejoin without another roll",function()
  local h,db,c,a=fixture();local initial=h.state.nectar;c.blockSettlement=true
  local q,r=quote(h,c,{poolVersion=C.PoolVersion,eligible=C.remaining(h.state.materialUnlocks)})
  assert(not H.materialCommand(h,"materialBuy",q,r));local held=copy(db.player_1.hatching.materialReservation);assert(held and db.player_1.hatching.nectar==initial)
  assert(H.release(h));h=H.load(1,{},a)
  assert(h.status=="Ready"and not h.pending and c.rolls==1 and h.state.nectar==initial-16 and h.state.materialUnlocks[held.finishId])
  assert(H.materialCommand(h,"materialBuy",q,r)and h.state.pendingMaterialResult.id==q.id)
 end)
 test("free whole-pet selections are independent and atomically acknowledge Use now",function()
  local h,_,c=fixture();buy(h,c);local pending=h.state.pendingMaterialResult;local before=h.state.nectar
  command(h,c,"materialEquip",{petId="foxfire_wick",finishId="gloss",expectedFinish="standard",resultId=pending.id})
  assert(not h.state.pendingMaterialResult and h.state.petMaterials.foxfire_wick=="gloss"and S.selected(h.state,"pip")=="standard"and h.state.nectar==before)
  command(h,c,"materialEquip",{petId="pip",finishId="gloss",expectedFinish="standard"})
  command(h,c,"materialEquip",{petId="foxfire_wick",finishId="standard",expectedFinish="gloss"})
  assert(h.state.petMaterials.pip=="gloss"and h.state.petMaterials.foxfire_wick=="standard"and h.state.nectar==before)
  local q,r=quote(h,c,{petId="pip",finishId="matte",expectedFinish="gloss"});local ok,why=H.materialCommand(h,"materialEquip",q,r);assert(not ok and why=="LockedMaterial")
 end)
 test("stale selection unowned target and wrong result cannot mutate any pigment or charm",function()
  local h,db,c=fixture();buy(h,c);ack(h,c);local before=copy(h.state);local root=copy(db.player_1.petAppearance)
  local value,r=quote(h,c,{petId="pip",finishId="gloss",expectedFinish="metal"});local ok,why=H.materialCommand(h,"materialEquip",value,r);assert(not ok and why=="SelectionChanged")
  value,r=quote(h,c,{petId="pip",finishId="gloss",expectedFinish="standard",resultId="wrong-result"});ok,why=H.materialCommand(h,"materialEquip",value,r);assert(not ok and why=="ResultChanged")
  h.state.inventoryMask=1;db.player_1.hatching.inventoryMask=1
  value,r=quote(h,c,{petId="puddle",finishId="gloss",expectedFinish="standard"});ok,why=H.materialCommand(h,"materialEquip",value,r);assert(not ok and why=="Unowned")
  assert(same(h.state.hueInventory,before.hueInventory)and same(h.state.petHues,before.petHues)and same(db.player_1.petAppearance,root))
 end)
 test("lease expiry takeover and authoritative revision changes fence new purchases",function()
  for _,kind in ipairs({"expiry","takeover","revision"})do
   local h,db,c=fixture();local before=h.state.nectar;local value,r=quote(h,c,{poolVersion=C.PoolVersion,eligible=C.remaining(h.state.materialUnlocks)})
   if kind=="expiry"then c.now+=100 elseif kind=="takeover"then db.player_1.hatching.epoch+=1;db.player_1.hatching.lease.token="foreign"else db.player_1.hatching.revision+=1 end
   local ok=H.materialCommand(h,"materialBuy",value,r);assert(not ok and db.player_1.hatching.nectar==before and next(db.player_1.hatching.materialUnlocks)==nil)
  end
 end)
 test("pending Material result blocks Hue/Companion purchases and compaction retains referenced proof",function()
  local h,_,c=fixture();local q=buy(h,c);local id=q.id
  local hue,r=quote(h,c,{});hue.catalogVersion=require(game.ReplicatedStorage.Shared.HueCatalog).CatalogVersion
  local ok,why=H.hueCommand(h,"hueBuy",hue,r);assert(not ok and why=="RevealPending")
  local nectar=h.state.nectar;ok,why=H.command(h,"hatch","meadow",h.state.revision);assert(not ok and why=="RetiredEgg"and h.state.nectar==nectar) -- v1: Meadow retired; the Hue route above covers the pending block.
  for i=1,40 do command(h,c,"materialEquip",{petId="pip",finishId=if i%2==1 then "gloss"else "standard",expectedFinish=if i%2==1 then "standard"else "gloss"})end
  assert(#h.state.materialReceiptOrder==32 and h.state.materialReceipts[id]and h.state.pendingMaterialResult.id==id)
 end)
 test("UpdateAsync callback reentry never rerolls or duplicates unlocks",function()
  local h,_,c=fixture();c.callbackReplay=true;local before=h.state.nectar;buy(h,c)
  assert(c.rolls==1 and h.state.nectar==before-16 and #h.state.materialReceiptOrder==1)
 end)
 test("historical v1 three-choice reservation can grant Metal after rejoin and replay its proof",function()
  local h,db,c,a=fixture();local before=h.state.nectar;local revision=h.state.revision
  local value={id=tostring(revision)..":historical-v1",catalogVersion=1,poolVersion=1,eligible={"gloss","matte","metal"}}
  local q=assert(S.quote("materialBuy",value,revision))
  db.player_1.hatching.materialReservation={quote=q,operationId="old-material-roll",sequence=h.state.operationSeq+1,finishId="metal"}
  assert(S.valid(db.player_1.hatching));assert(H.release(h));local rolls=c.rolls
  h=H.load(1,{},a);assert(h.status=="Ready"and h.state.materialUnlocks.metal and h.state.nectar==before-16 and c.rolls==rolls)
  assert(H.materialCommand(h,"materialBuy",value,revision)and h.state.pendingMaterialResult.finishId=="metal")
  command(h,c,"materialEquip",{petId="pip",finishId="metal",expectedFinish="standard",resultId=value.id})
  local prior=copy(h.state.materialReceipts[value.id]);assert(H.release(h));h=H.load(1,{},a)
  assert(h.status=="Ready"and h.state.petMaterials.pip=="metal"and same(h.state.materialReceipts[value.id],prior))
  assert(table.concat(C.remaining(h.state.materialUnlocks),",")=="gloss,matte","Metal leaked into current sellable pool")
 end)
 test("new v1 buy and forged v2 Metal eligibility cannot roll write or debit",function()
  local h,_,c=fixture();local writes,rolls,balance=c.writes,c.rolls,h.state.nectar
  local value,r=quote(h,c,{poolVersion=1,eligible={"gloss","matte","metal"}})
  local ok,why=H.materialCommand(h,"materialBuy",value,r);assert(not ok and why=="LegacyPurchaseClosed")
  value,r=quote(h,c,{poolVersion=C.PoolVersion,eligible={"gloss","matte","metal"}})
  ok,why=H.materialCommand(h,"materialBuy",value,r);assert(not ok and why=="InvalidMaterial")
  assert(c.writes==writes and c.rolls==rolls and h.state.nectar==balance)
 end)
 return {passed=#cases,cases=cases,persistentWrites=false}
end
