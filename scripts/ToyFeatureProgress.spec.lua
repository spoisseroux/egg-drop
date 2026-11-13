-- Isolated durable roots only. frozenSource must be fixtures/FrozenV370HatchProgress.lua.
return function(server,frozenSource,frozenDailySource)
 local H=require(server.HatchProgress);local T=require(server.ToyState);local F=require(server.FeatureState)
 local Hue=require(server.HueState);local Material=require(server.MaterialState)
 local TC=require(game.ReplicatedStorage.Shared.ToyCatalog);local FC=require(game.ReplicatedStorage.Shared.FeatureCatalog)
 local Appearance=require(server.PetAppearance);local cases={}
 local function copy(v)if type(v)~="table"then return v end;local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out end
 local function fixture(loader)
  local db={player_1={rank=4,trials=31,custom="preserved"}}
  local c={now=1000,serial=0,unit=0,rolls=0,writes=0,quoteSerial=0}
  local a={now=function()return c.now end,guid=function()c.serial+=1;return "tf-guid-"..c.serial end,random=function()c.rolls+=1;return c.unit end,wait=function()end}
  a.update=function(key,transform)
   c.writes+=1;if c.failBefore then c.failBefore=false;error("Expected isolated before-write failure")end
   local old=copy(db[key]);local result=transform(copy(db[key]))
   if c.callbackReplay then result=transform(copy(db[key]))end
   if result then db[key]=copy(result)end
   if c.failAfter then c.failAfter=false;error("Expected isolated lost reply")end
   local was=old and old.hatching;local now=result and result.hatching
   if c.failSettlement and was and(was.toyReservation or was.featureReservation)and now and not(now.toyReservation or now.featureReservation)then c.failSettlement=false;error("Expected isolated settlement reply loss")end
   if c.blockSettlement and now and(now.toyReservation or now.featureReservation)then c.blockSettlement=false;c.failBefore=true end
   return copy(result)
  end
  local h=(loader or H).load(1,{},a);assert(h.status=="Ready",h.status)
  for n=1,40 do assert((loader or H).award(h,n,8))end
  return h,db,c,a
 end
 local function quote(h,c,kind,fields)
  c.quoteSerial+=1;local revision=h.state.revision;local q=copy(fields);q.id=tostring(revision)..":"..kind.."-test-"..c.quoteSerial;q.catalogVersion=if kind=="hue"then "hue-items-v1"else 1;return q,revision
 end
 local function command(h,c,kind,action,fields)
  local q,r=quote(h,c,kind,fields);local ok,why,receipt=H[kind.."Command"](h,action,q,r);assert(ok,why)
  assert(T.valid(h.state)and F.valid(h.state)and Hue.valid(h.state)and Material.valid(h.state),"invalid after "..action)
  return q,r,receipt
 end
 local function buy(h,c,kind)
  return command(h,c,kind,kind.."Buy",if kind=="toy"then{poolVersion=1,eligible=TC.remaining(h.state.toyUnlocks)}else{poolVersion=1})
 end
 local function ack(h,c,kind)
  local p=h.state["pending"..kind:sub(1,1):upper()..kind:sub(2).."Result"];return command(h,c,kind,kind.."Ack",{resultId=p.id})
 end
 local function frozenWriter()
  assert(type(frozenSource)=="string","pass exact fixtures/FrozenV370HatchProgress.lua as argument two")
  -- v9 retired DailyContracts' contract API; the frozen writer gets the frozen
  -- module (fixtures/FrozenDailyContracts.lua) as argument three.
  assert(type(frozenDailySource)=="string","pass fixtures/FrozenDailyContracts.lua as argument three")
  local daily=Instance.new("ModuleScript");daily.Name="_FrozenDailyContracts";daily.Source=frozenDailySource;daily.Parent=server
  local source=frozenSource:gsub("require%(ReplicatedStorage%.Shared%.DailyContracts%)","require(script.Parent._FrozenDailyContracts)",1)
  local module=Instance.new("ModuleScript");module.Name="_FrozenV370HatchWriter";module.Source=source;module.Parent=server
  local ok,old=pcall(require,module);module:Destroy();daily:Destroy();assert(ok,old);return old
 end
 local function test(name,run)run();table.insert(cases,name)end
 test("catalog fixed boundaries remaining uniform odds and no stats",function()
  assert(TC.Cost==8 and FC.Cost==32 and FC.StackLimit==99 and FC.MaxStage==5)
  assert(FC.roll(0)=="horns"and FC.roll(.49999)=="horns"and FC.roll(.5)=="claws"and FC.roll(.84999)=="claws"and FC.roll(.85)=="wings"and FC.roll(.99999)=="wings")
  for _,bad in ipairs({-1,1,math.huge})do assert(not FC.roll(bad)and not TC.roll({"ball"},bad))end
  assert(not FC.roll(0/0));local odds=TC.odds({ball=true});assert(#odds==2 and odds[1].probability==.5 and odds[2].probability==.5)
 end)
 test("new v8 profile neutral state and permanent uniform toy exhaustion costs24",function()
  local h,db,c=fixture();local before=h.state.nectar;assert(h.state.version==11 and db.player_1.custom=="preserved")
  for _,id in ipairs({"ball","bone","sparkler"})do local _,_,r=buy(h,c,"toy");assert(r.toyId==id and r.cost==8 and h.state.toyUnlocks[id]);ack(h,c,"toy")end
  assert(h.state.nectar==before-24 and c.rolls==3 and #TC.remaining(h.state.toyUnlocks)==0)
  local q,r=quote(h,c,"toy",{poolVersion=1,eligible={"ball"}});local writes=c.writes;local ok,why=H.toyCommand(h,"toyBuy",q,r);assert(not ok and why=="AllUnlocked"and writes==c.writes and c.rolls==3)
 end)
 test("all seven pet toy choices are independent free and require exact result ownership",function()
  local h,_,c=fixture();buy(h,c,"toy");local pending=h.state.pendingToyResult
  local q,r=quote(h,c,"toy",{petId="pip",toyId="ball",expectedToy="none"});local ok,why=H.toyCommand(h,"toyEquip",q,r);assert(not ok and why=="RevealPending")
  command(h,c,"toy","toyEquip",{petId="pip",toyId="ball",expectedToy="none",resultId=pending.id});assert(not h.state.pendingToyResult)
  local before=h.state.nectar
  for _,pet in ipairs(Appearance.Ids)do if pet~="pip"then command(h,c,"toy","toyEquip",{petId=pet,toyId="ball",expectedToy="none"})end end
  command(h,c,"toy","toyEquip",{petId="pip",toyId="none",expectedToy="ball"})
  assert(h.state.petToys.pip=="none"and h.state.petToys.eclipse_orbit=="ball"and h.state.nectar==before)
 end)
 test("toy same ID exact replay no writes changed payload conflict and stripped private proof",function()
  local h,_,c=fixture();local q,r,receipt=buy(h,c,"toy");local before,writes=h.state.nectar,c.writes
  assert(H.toyCommand(h,"toyBuy",q,r));assert(c.writes==writes and h.state.nectar==before)
  local wrong=copy(q);wrong.eligible={"ball"};local ok,why=H.toyCommand(h,"toyBuy",wrong,r);assert(not ok and why=="OperationConflict")
  assert(not receipt.quote and not receipt.operationId and not receipt.sequence)
 end)
 test("both namespaces retain the exact roll across reservation and settlement reply loss",function()
  for _,kind in ipairs({"toy","feature"})do for _,phase in ipairs({"reserve","settle","before"})do
   local h,_,c=fixture();local before=h.state.nectar
   local q,r=quote(h,c,kind,if kind=="toy"then{poolVersion=1,eligible=TC.remaining(h.state.toyUnlocks)}else{poolVersion=1})
   if phase=="reserve"then c.failAfter=true elseif phase=="settle"then c.failSettlement=true else c.failBefore=true end
   local ok,why=H[kind.."Command"](h,kind.."Buy",q,r);assert(not ok and why=="Retrying"and c.rolls==1)
   local candidate=copy(h.pending.candidate);c.unit=.99;assert(H[kind.."Command"](h,kind.."Buy",q,r))
   assert(c.rolls==1 and h.state.nectar==before-(if kind=="toy"then 8 else 32))
   local receipt=h.state[kind.."Receipts"][q.id];assert(receipt.operationId==candidate.operationId and receipt[if kind=="toy"then"toyId"else"featureId"]==candidate[if kind=="toy"then"toyId"else"featureId"])
  end end
 end)
 test("durable reservations rejoin without another roll in either namespace",function()
  for _,kind in ipairs({"toy","feature"})do
   local h,db,c,a=fixture();local before=h.state.nectar;c.blockSettlement=true
   local q,r=quote(h,c,kind,if kind=="toy"then{poolVersion=1,eligible=TC.remaining(h.state.toyUnlocks)}else{poolVersion=1})
   assert(not H[kind.."Command"](h,kind.."Buy",q,r));local held=copy(db.player_1.hatching[kind.."Reservation"]);assert(held and db.player_1.hatching.nectar==before)
   assert(H.release(h));h=H.load(1,{},a);assert(h.status=="Ready"and c.rolls==1 and h.state.nectar==before-(if kind=="toy"then 8 else 32))
   assert(H[kind.."Command"](h,kind.."Buy",q,r));assert(h.state[kind.."Receipts"][q.id].operationId==held.operationId)
  end
 end)
 test("feature full rolled stack durable refusal zero debit no reroll and all full disables",function()
  local h,db,c=fixture();h.state.featureStock.horns=99;db.player_1.hatching.featureStock.horns=99;local before=h.state.nectar
  local q,r,receipt=buy(h,c,"feature");assert(receipt.outcome=="Refused"and receipt.reason=="StackLimit"and receipt.cost==0 and receipt.inventoryBefore==99 and receipt.inventoryAfter==99 and not h.state.pendingFeatureResult and h.state.nectar==before)
  c.unit=.99;assert(H.featureCommand(h,"featureBuy",q,r)and c.rolls==1)
  for _,id in ipairs(FC.Order)do h.state.featureStock[id]=99;db.player_1.hatching.featureStock[id]=99 end
  q,r=quote(h,c,"feature",{poolVersion=1});local writes=c.writes;local ok,why=H.featureCommand(h,"featureBuy",q,r);assert(not ok and why=="AllStacksFull"and c.writes==writes and c.rolls==1)
 end)
 test("feature growth consumes one stock shows earned stage and supports simultaneous features",function()
  local h,db,c=fixture();for _,id in ipairs(FC.Order)do h.state.featureStock[id]=35;db.player_1.hatching.featureStock[id]=35 end
  local before=h.state.nectar
  for _,pet in ipairs(Appearance.Ids)do for _,id in ipairs(FC.Order)do for stage=0,4 do
   local _,_,r=command(h,c,"feature","featureUse",{petId=pet,featureId=id,expectedStage=stage})
   assert(r.earnedBefore==stage and r.earnedAfter==stage+1 and r.visibleAfter==stage+1 and r.inventoryAfter==r.inventoryBefore-1)
  end end end
  assert(h.state.nectar==before and h.state.featureStock.horns==0)
  for _,pet in ipairs(Appearance.Ids)do for _,id in ipairs(FC.Order)do assert(h.state.petFeatures[pet][id].earned==5 and h.state.petFeatures[pet][id].visible==5)end end
 end)
 test("feature free hidden display preserves earned stage and exact stale stage protection",function()
  local h,db,c=fixture();h.state.featureStock.horns=5;db.player_1.hatching.featureStock.horns=5
  for stage=0,1 do command(h,c,"feature","featureUse",{petId="pip",featureId="horns",expectedStage=stage})end
  local before=h.state.nectar;command(h,c,"feature","featureShow",{petId="pip",featureId="horns",expectedStage=2,expectedVisible=2,stage=0})
  assert(h.state.petFeatures.pip.horns.earned==2 and h.state.petFeatures.pip.horns.visible==0 and h.state.featureStock.horns==3 and h.state.nectar==before)
  for _,case in ipairs({{featureId="horns",expectedStage=1,reason="StageChanged"},{featureId="wings",expectedStage=0,reason="EmptyStock"}})do
   local q,r=quote(h,c,"feature",{petId="pip",featureId=case.featureId,expectedStage=case.expectedStage});local ok,why=H.featureCommand(h,"featureUse",q,r);assert(not ok and why==case.reason)
  end
  local q,r=quote(h,c,"feature",{petId="pip",featureId="horns",expectedStage=2,expectedVisible=0,stage=3});local ok,why=H.featureCommand(h,"featureShow",q,r);assert(not ok and why=="StageLocked")
 end)
 test("feature exact pending use clears only matching result and cap never consumes stock",function()
  local h,db,c=fixture();buy(h,c,"feature");local p=h.state.pendingFeatureResult
  local q,r=quote(h,c,"feature",{petId="pip",featureId="horns",expectedStage=0});local ok,why=H.featureCommand(h,"featureUse",q,r);assert(not ok and why=="RevealPending")
  command(h,c,"feature","featureUse",{petId="pip",featureId="horns",expectedStage=0,pendingResultId=p.id});assert(not h.state.pendingFeatureResult and h.state.featureStock.horns==0)
  h.state.featureStock.horns=5;db.player_1.hatching.featureStock.horns=5
  for stage=1,4 do command(h,c,"feature","featureUse",{petId="pip",featureId="horns",expectedStage=stage})end
  q,r=quote(h,c,"feature",{petId="pip",featureId="horns",expectedStage=5});ok,why=H.featureCommand(h,"featureUse",q,r);assert(not ok and why=="MaxStage"and h.state.featureStock.horns==1)
 end)
 test("toy and feature pending results block old Hue Material Companion routes symmetrically",function()
  for _,kind in ipairs({"toy","feature"})do
   local h,_,c=fixture();buy(h,c,kind);local before=h.state.nectar
   local q,r=quote(h,c,"hue",{});local ok,why=H.hueCommand(h,"hueBuy",q,r);assert(not ok and why=="RevealPending")
   q,r=quote(h,c,"hue",{itemId="rose",petId="pip",channel="main",counts={rose=0,tide=0,citrus=0,iris=0}});ok,why=H.hueCommand(h,"hueUse",q,r);assert(not ok and why=="RevealPending")
   q,r=quote(h,c,"material",{petId="pip",finishId="standard",expectedFinish="standard"});ok,why=H.materialCommand(h,"materialEquip",q,r);assert(not ok and why=="RevealPending")
   q,r=quote(h,c,"material",{poolVersion=2,eligible={"gloss","matte"}});ok,why=H.materialCommand(h,"materialBuy",q,r);assert(not ok and why=="RevealPending")
   ok,why=H.command(h,"hatch","meadow",h.state.revision);assert(not ok and why=="RetiredEgg"and h.state.nectar==before) -- v1: Meadow retired; ack below covers the Companion route.
   ok,why=H.command(h,"ack","wrong",h.state.revision);assert(not ok and why=="RevealPending"and h.state.nectar==before)
   local other=if kind=="toy"then"feature"else"toy";q,r=quote(h,c,other,if other=="toy"then{poolVersion=1,eligible=TC.remaining(h.state.toyUnlocks)}else{poolVersion=1});ok,why=H[other.."Command"](h,other.."Buy",q,r);assert(not ok and why=="RevealPending")
  end
 end)
 test("new families respect existing Hue Material and Companion pending results",function()
  for _,kind in ipairs({"hue","material","companion"})do
   local h,db,c=fixture()
   -- v1: Meadow is retired, so a saved Companion reveal receipt replaces the hatch fixture.
   if kind=="companion"then local ok,why=H.command(h,"hatch","meadow",h.state.revision);assert(not ok and why=="RetiredEgg")
    db.player_1.hatching.lastHatch={id="saved-companion-reveal",petId="pip",duplicate=true,refund=0,family="pip",mastery=0,rare=false,recipe="meadow"};assert(H.renew(h)and h.state.lastHatch)
   else local q,r=quote(h,c,kind,if kind=="material"then{poolVersion=2,eligible={"gloss","matte"}}else{});assert(H[kind.."Command"](h,kind.."Buy",q,r))end
   for _,new in ipairs({"toy","feature"})do local q,r=quote(h,c,new,if new=="toy"then{poolVersion=1,eligible=TC.remaining(h.state.toyUnlocks)}else{poolVersion=1});local ok,why=H[new.."Command"](h,new.."Buy",q,r);assert(not ok and why=="RevealPending")end
  end
 end)
 test("revision takeover expiry and callback reentry cannot double charge",function()
  for _,kind in ipairs({"toy","feature"})do for _,mode in ipairs({"revision","epoch","expiry","callback"})do
   local h,db,c=fixture();local before=h.state.nectar;local q,r=quote(h,c,kind,if kind=="toy"then{poolVersion=1,eligible=TC.remaining(h.state.toyUnlocks)}else{poolVersion=1})
   if mode=="revision"then db.player_1.hatching.revision+=1 elseif mode=="epoch"then db.player_1.hatching.epoch+=1 elseif mode=="expiry"then c.now+=100 else c.callbackReplay=true end
   local ok=H[kind.."Command"](h,kind.."Buy",q,r)
   assert(if mode=="callback"then ok and db.player_1.hatching.nectar==before-(if kind=="toy"then 8 else 32)and c.rolls==1 else not ok and db.player_1.hatching.nectar==before)
  end end
 end)
 test("new receipt eviction makes old ids stale without regrant and pending proof remains exact",function()
  local h,_,c=fixture();local q,r=buy(h,c,"toy");ack(h,c,"toy")
  for n=1,40 do command(h,c,"toy","toyEquip",{petId="pip",toyId=if n%2==1 then"ball"else"none",expectedToy=if n%2==1 then"none"else"ball"})end
  assert(#h.state.toyReceiptOrder==32 and not h.state.toyReceipts[q.id]);local before=h.state.nectar;local ok,why=H.toyCommand(h,"toyBuy",q,r);assert(not ok and why=="RevisionChanged"and h.state.nectar==before)
 end)
 test("public appearance exposes only selected toy and visible feature stages",function()
  local h,db=fixture();h.state.petToys.pip="ball";h.state.petFeatures.pip=FC.emptyRow();h.state.petFeatures.pip.horns={earned=5,visible=1}
  local public=Appearance.public({petAppearanceSaved={},companionId="pip"},h.state.hues,h.state.petHues,h.state.petMaterials,h.state.petToys,h.state.petFeatures)
  assert(public.pip.toyId=="ball"and public.pip.featureStages.horns==1 and public.pip.featureStages.claws==0 and not public.pip.earned and not public.pip.featureStock and not public.pip.toyUnlocks)
  assert(public.puddle.toyId==nil and public.puddle.featureStages==nil and db.player_1.custom=="preserved")
 end)
 test("malformed namespace quote unknown ids stages and unowned recipients reject without mutation",function()
  local h,db,c=fixture();local q,r=quote(h,c,"feature",{petId="pip",featureId="horns",expectedStage=6});assert(not H.featureCommand(h,"featureUse",q,r))
  q,r=quote(h,c,"toy",{poolVersion=1,eligible={"sparkler","ball"}});assert(not H.toyCommand(h,"toyBuy",q,r))
  q,r=quote(h,c,"feature",{poolVersion=1});q.id=tostring(r)..":toy-forged";assert(not H.featureCommand(h,"featureBuy",q,r))
  h.state.inventoryMask=1;db.player_1.hatching.inventoryMask=1;q,r=quote(h,c,"feature",{petId="puddle",featureId="horns",expectedStage=0});local ok,why=H.featureCommand(h,"featureUse",q,r);assert(not ok and why=="Unowned")
 end)
 test("frozen actual v370 writer cannot renew write or release upgraded v8 root",function()
  local old=frozenWriter()
  local h,db,c,a=fixture(old);assert(h.state.version==7);assert(old.release(h));local oldHandle=old.load(1,{},a);assert(oldHandle.status=="Ready")
  c.now+=100;local fresh=H.load(1,{},a);assert(fresh.status=="Ready"and fresh.state.version==11)
  local before=copy(db.player_1);assert(not old.renew(oldHandle));assert(T.same(db.player_1,before))
  oldHandle.status="Ready";assert(not old.award(oldHandle,41,8));assert(T.same(db.player_1,before))
  oldHandle.status="Ready";assert(not old.release(oldHandle));assert(T.same(db.player_1,before))
 end)
 test("frozen old writer rejects v8 even when supplied matching lease metadata",function()
  local old=frozenWriter()
  local h,db,c,a=fixture(old);assert(old.release(h));local fresh=H.load(1,{},a);local before=copy(db.player_1)
  -- Isolate schema rejection from token/epoch rejection by matching both fences.
  h.token,h.epoch=fresh.token,fresh.epoch;h.state.revision=fresh.state.revision;h.state.operationSeq=fresh.state.operationSeq;h.status="Ready"
  assert(not old.renew(h)and T.same(db.player_1,before));h.status="Ready"
  assert(not old.award(h,41,8)and T.same(db.player_1,before));h.status="Ready"
  assert(not old.release(h)and T.same(db.player_1,before))
 end)
 test("v7 durable Hue and historical Material reservations settle once after v8 acquisition",function()
  local old=frozenWriter()
  for _,kind in ipairs({"hue","material"})do
   local h,db,c,a=fixture(old);local revision=h.state.revision
   local value={id=tostring(revision)..":historical-reservation",catalogVersion=if kind=="hue"then "hue-items-v1"else 1}
   if kind=="material"then value.poolVersion=1;value.eligible={"gloss","matte","metal"}end
   local api=if kind=="material"then Material else Hue
   local candidate={quote=assert(api.quote(kind.."Buy",value,revision)),operationId="historical-reservation",sequence=h.state.operationSeq+1}
   candidate[if kind=="material"then"finishId"else"itemId"]=if kind=="material"then"metal"else"iris"
   db.player_1.hatching[kind.."Reservation"]=candidate;assert(api.valid(db.player_1.hatching));assert(old.release(h))
   local before=db.player_1.hatching.nectar;local rolls=c.rolls;local fresh=H.load(1,{},a)
   assert(fresh.status=="Ready"and fresh.state.version==11 and c.rolls==rolls and not fresh.state[kind.."Reservation"])
   assert(fresh.state.nectar==before-(if kind=="material"then 16 else 8))
   assert(H[kind.."Command"](fresh,kind.."Buy",value,revision))
  end
 end)
 test("v7 upgrade refuses smuggled new namespaces and malformed historical proof",function()
  local old=frozenWriter()
  for _,mode in ipairs({"smuggled","malformed"})do
   local h,db,_,a=fixture(old);assert(old.release(h))
   if mode=="smuggled"then db.player_1.hatching.toyUnlocks={}else db.player_1.hatching.hueInventory.rose=-1 end
   local before=copy(db.player_1);local failed=H.load(1,{},a);assert(failed.status=="InvalidData"and T.same(db.player_1,before))
  end
 end)
 test("v7 migration preserves pending historical outcomes and exact receipts without reroll",function()
  local old=frozenWriter()
  for _,kind in ipairs({"hue","material","companion"})do
   local h,db,c,a=fixture(old)
   -- v1: the frozen writer also refuses retired Meadow, so a saved historical Companion reveal replaces the hatch fixture.
   if kind=="companion"then local ok,why=old.command(h,"hatch","meadow",h.state.revision);assert(not ok and why=="RetiredEgg")else local q,r=quote(h,c,kind,if kind=="material"then{poolVersion=2,eligible={"gloss","matte"}}else{});assert(old[kind.."Command"](h,kind.."Buy",q,r))end
   assert(old.release(h))
   if kind=="companion"then db.player_1.hatching.lastHatch={id="v7-companion-reveal",petId="pip",duplicate=true,refund=9,family="pip",mastery=0,rare=false,recipe="meadow"}end
   local previous=copy(db.player_1.hatching);local rolls=c.rolls;local new=H.load(1,{},a);assert(new.status=="Ready"and new.state.version==11 and c.rolls==rolls)
   for _,key in ipairs({"hueInventory","petHues","hueItemReceipts","hueReceiptOrder","materialUnlocks","petMaterials","materialReceipts","materialReceiptOrder","pendingHueResult","pendingMaterialResult","lastHatch","misses","inventoryMask","nectar"})do assert(T.same(new.state[key],previous[key]),"changed historical "..key)end
  end
 end)
 return{passed=#cases,cases=cases,persistentWrites=false}
end
