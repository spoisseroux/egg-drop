-- Current pool4 runs in isolated copies of the ACTUAL source. The mounted
-- MaterialCatalog stays pool4; this spec never mutates the mounted catalogue.
return function(server)
 local Shared=game.ReplicatedStorage.Shared;local original=require(Shared.MaterialCatalog)
 local root=Instance.new("Folder");root.Name="_JellyPool4Sandbox";root.Parent=server
 local function evaluate(source,name,sourceScript,overrides)
  local module=Instance.new("ModuleScript");module.Name=name
  module.Source="return function(injectedRequire,sourceScript)local require,script=injectedRequire,sourceScript\n"..source.."\nend";module.Parent=root
  local factory=require(module)
  return factory(function(target)return(overrides and overrides[target])or require(target)end,sourceScript)
 end
 local text,count=Shared.MaterialCatalog.Source:gsub("PoolVersion=%d+","PoolVersion=4",1);assert(count==1,"isolated activation seam changed")
 local C=evaluate(text,"FutureMaterialCatalog",Shared.MaterialCatalog)
 local S=evaluate(server.MaterialState.Source,"FutureMaterialState",server.MaterialState,{[Shared.MaterialCatalog]=C})
 local H=evaluate(server.HatchProgress.Source,"FutureHatchProgress",server.HatchProgress,{[Shared.MaterialCatalog]=C,[server.MaterialState]=S})
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function copy(v)if type(v)~="table"then return v end;local t={};for k,x in pairs(v)do t[k]=copy(x)end;return t end
 local function fixture()
  local db={};local c={now=1000,serial=0,rolls=0,writes=0,unit=.5,nonce=0}
  local a={now=function()return c.now end,guid=function()c.serial+=1;return "jelly-op-"..c.serial end,wait=function()end,
   random=function()c.rolls+=1;return c.unit end}
  a.update=function(key,transform)
   c.writes+=1
   if c.failBefore then c.failBefore=false;error("Expected Jelly before-write failure")end
   if c.flip then c.flip.restricted=true;c.flip=nil end
   local out=transform(copy(db[key]));if out then db[key]=copy(out)end
   if c.failAfter then c.failAfter=false;error("Expected Jelly accepted response loss")end
   return copy(out)
  end
  local h=H.load(1,{rank=1},a);assert(h.status=="Ready"and h.restricted==true)
  for n=1,8 do assert(H.award(h,n,8))end
  h.restricted=false
  return h,db,c,a
 end
 local function quote(h,c,version,mode)
  c.nonce+=1;version=version or 4
  local q={id=tostring(h.state.revision)..":jelly-"..c.nonce,catalogVersion=1,poolVersion=version,eligible=C.remaining(h.state.materialUnlocks,version)}
  if version==4 then q.price=16;q.selectionMode=mode or C.selectionMode(h.restricted);if q.selectionMode=="fixed"then q.fixedFinishId=C.fixedNext(q.eligible,4)end end
  return q,h.state.revision
 end
 local function command(h,c,action,extra)
  c.nonce+=1;local q=copy(extra);q.id=tostring(h.state.revision)..":jelly-extra-"..c.nonce;q.catalogVersion=1
  local ok,why=H.materialCommand(h,action,q,h.state.revision);assert(ok,why);return q
 end
 local ok,problem=pcall(function()
 test("mounted current pool and immutable legacy pools remain unchanged",function()
  assert(original.PoolVersion==4 and C.PoolVersion==4)
  for v=1,3 do assert(S.same(C.Pools[v],original.Pools[v]))end
  assert(table.concat(C.Pools[4],",")=="gloss,jelly,matte"and C.cost(4)==16)
  assert(C.roll({"gloss","jelly","matte"},.45,4)=="jelly"and C.roll({"gloss","jelly","matte"},.55,4)=="matte")
 end)
 test("pool4 quote is exact while legacy quotes keep their original shape",function()
  local h,_,c=fixture();local q,r=quote(h,c);assert(S.quote("materialBuy",q,r))
  for _,change in ipairs({{price=15},{selectionMode="other"},{fixedFinishId="jelly"},{extra=true}})do local bad=copy(q);for k,v in pairs(change)do bad[k]=v end;assert(not S.quote("materialBuy",bad,r))end
  q,r=quote(h,c,2);assert(S.quote("materialBuy",q,r));q.price=16;assert(not S.quote("materialBuy",q,r),"legacy shape was widened")
  for _,reservation in ipairs({true,false,17,"malformed",{quote=7}})do
   local bad=copy(h.state);bad.materialReservation=reservation
   local safe,valid=pcall(S.valid,bad);assert(safe and valid==false,"malformed reservation did not fail closed without throwing")
  end
 end)
 test("public unknown policy stays restricted and matches fixed material mode",function()
  local h=fixture();h.restricted=nil
  local snapshot=H.public(h);assert(snapshot.restricted==true and snapshot.materialSelectionMode=="fixed"and snapshot.nextFixed.material=="gloss")
  h.restricted=false;snapshot=H.public(h)
  assert(snapshot.restricted==false and snapshot.materialSelectionMode=="random")
 end)
 test("accepted random reservation survives policy flip and retries exactly once",function()
  local h,db,c=fixture();local before=h.state.nectar;local q,r=quote(h,c)
  c.failAfter=true;local saved,why=H.materialCommand(h,"materialBuy",q,r)
  assert(not saved and why=="Retrying"and db.player_1.hatching.materialReservation.finishId=="jelly"and h.state.nectar==before and c.rolls==1)
  h.restricted=true;local receipt;saved,why,receipt=H.materialCommand(h,"materialBuy",q,r)
  assert(saved and h.state.materialUnlocks.jelly and h.state.nectar==before-16 and c.rolls==1 and receipt.poolVersion==4 and receipt.selectionMode=="random"and receipt.quotedPrice==16)
  local writes=c.writes;assert(H.materialCommand(h,"materialBuy",q,r)and c.writes==writes and c.rolls==1)
  assert(S.valid(h.state))
 end)
 test("new stale mode rejects before roll and reserve-time flip cannot charge",function()
  local h,db,c=fixture();local q,r=quote(h,c);h.restricted=nil;local writes=c.writes;local balance=h.state.nectar
  local saved,why=H.materialCommand(h,"materialBuy",q,r);assert(not saved and why=="PolicyChanged"and c.rolls==0 and c.writes==writes and h.state.nectar==balance)
  h.restricted=false;q,r=quote(h,c);c.flip=h;saved,why=H.materialCommand(h,"materialBuy",q,r)
  assert(not saved and why=="PolicyChanged"and not db.player_1.hatching.materialReservation and h.state.nectar==balance and c.rolls==1,"mode changed during first reservation")
 end)
 test("restricted or unknown modes disclose and grant fixed next with zero RNG",function()
  local h,_,c=fixture();h.restricted=nil;local q,r=quote(h,c)
  assert(q.selectionMode=="fixed"and q.fixedFinishId=="gloss")
  local saved,why,receipt=H.materialCommand(h,"materialBuy",q,r);assert(saved,why)
  assert(receipt.finishId=="gloss"and receipt.selectionMode=="fixed"and c.rolls==0)
  command(h,c,"materialAck",{resultId=q.id})
  q,r=quote(h,c);assert(q.fixedFinishId=="matte");h.restricted=false
  saved,why=H.materialCommand(h,"materialBuy",q,r);assert(not saved and why=="PolicyChanged"and c.rolls==0)
 end)
 test("old pool1 and2 reservations round-trip through future catalogue without reroll",function()
  for version,finish in pairs({[1]="metal",[2]="matte"})do
   local h,db,c,a=fixture();local before=h.state.nectar;local q,r=quote(h,c,version)
   local canonical=assert(S.quote("materialBuy",q,r));assert(H.release(h))
   db.player_1.hatching.materialReservation={quote=canonical,operationId="legacy-jelly-test-"..version,sequence=h.state.operationSeq+1,finishId=finish}
   assert(S.valid(db.player_1.hatching));h=H.load(1,{},a)
   assert(h.status=="Ready"and h.state.materialUnlocks[finish]and h.state.nectar==before-16 and c.rolls==0)
   assert(S.same(h.state.lastMaterialResult.quote,canonical)and H.materialCommand(h,"materialBuy",q,r))
  end
 end)
 test("pending Jelly receipt survives bounded eviction and per-pet equip stays free",function()
  local h,_,c=fixture();local q,r=quote(h,c);assert(H.materialCommand(h,"materialBuy",q,r))
  assert(h.state.petMaterials.pip==nil,"random unlock auto-equipped")
  local balance=h.state.nectar
  for i=1,36 do command(h,c,"materialEquip",{petId="pip",finishId=if i%2==1 then "jelly"else "standard",expectedFinish=if i%2==1 then "standard"else "jelly"})end
  assert(#h.state.materialReceiptOrder==32 and h.state.materialReceipts[q.id]and h.state.pendingMaterialResult.id==q.id and h.state.nectar==balance and c.rolls==1 and S.valid(h.state))
 end)
 test("both existing common finishes make the next Jelly egg certain",function()
  local h,db,c=fixture();h.state.materialUnlocks={gloss=true,matte=true};db.player_1.hatching.materialUnlocks=copy(h.state.materialUnlocks)
  local odds=C.odds(h.state.materialUnlocks,4);assert(#odds==1 and odds[1].id=="jelly"and odds[1].probability==1)
  local q,r=quote(h,c);local before=h.state.nectar;assert(H.materialCommand(h,"materialBuy",q,r))
  assert(h.state.materialUnlocks.jelly and h.state.nectar==before-16 and #C.remaining(h.state.materialUnlocks,4)==0)
 end)
 end)
 root:Destroy();assert(ok,problem);return{passed=#cases,cases=cases,mountedPoolUnchanged=original.PoolVersion==4}
end
