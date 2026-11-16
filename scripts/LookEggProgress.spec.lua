-- Customization Egg, slice 1 server foundation (plan 2026-11-16 §2, §3, §10; nothing on sale).
-- Save stays v11: optional fields, the "no default charm" switch at load, lookBuy reserve and
-- total settlement, replay, refusals, pity, restricted fixed order, finish doses and validators.
-- The sale switch is off in this build: purchase cases use the spec-only `handle.lookAvailable`.
-- Isolated fixture records only; never real user writes.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.LookEggProgress)(ServerScriptService.Server)
return function(server)
 local RawH=require(server.HatchProgress);local H={};for key,value in pairs(RawH)do H[key]=value end
 function H.load(...)local handle=RawH.load(...);handle.restricted=false;return handle end -- explicit allowed random fixture
 local S=require(server.HueState);local LS=require(server.LookState)
 local Shared=game.ReplicatedStorage.Shared;local Hue=require(Shared.HueCatalog);local LE=require(Shared.LookEggCatalog)
 local cases={};local function test(name,f)f();table.insert(cases,name)end
 local function copy(x)if type(x)~="table"then return x end;local r={};for k,v in pairs(x)do r[k]=copy(v)end;return r end
 local currentDb
 local function fixture()
  local db={player_1={rank=4,trials=31,custom="kept",petAppearance={pip={charmVisible=false,at=1,writer="old"}}}}
  local c={now=1000,n=0,rolls=0,unit=.01,updates=0}
  local a={now=function()return c.now end,guid=function()c.n+=1;return"server-"..c.n end,random=function()c.rolls+=1;return c.unit end,wait=function()end}
  a.update=function(key,transform)
   c.updates+=1
   if c.before then c.before=false;error("Expected fixture: before write")end
   local output=transform(copy(db[key]))
   if output then db[key]=copy(output)end
   if c.failSettlement and db[key].hatching.hueReservation then c.failSettlement=false;c.before=true end
   return copy(output)
  end
  local h=H.load(1,{},a);assert(h.status=="Ready");for n=1,4 do assert(H.award(h,n,8))end -- 32 Stars
  currentDb=db
  return h,db,c,a
 end
 local function fund(h)for n=5,70 do assert(H.award(h,n,8))end end
 local function request(h,fields)
  local r=h.state.revision;local v=copy(fields or{});v.id=v.id or(tostring(r)..":look-"..tostring(h.state.operationSeq+1));v.catalogVersion=Hue.CatalogVersion;return v,r
 end
 local function command(h,action,fields)
  local q,r=request(h,fields);local ok,why,receipt=H.hueCommand(h,action,q,r);assert(ok,action.." failed: "..tostring(why))
  assert(S.valid(h.state)and RawH.valid(h.state),"invalid state after "..action);return q,r,receipt
 end
 local function lookFields(h,mode)
  mode=mode or "random";local s=h.state
  local f={poolVersion=LE.PoolVersion,price=LE.Price,selectionMode=mode,missingCharms=LE.missing(s.charmUnlocks),charmMisses=LS.misses(s)}
  if mode=="fixed"then f.fixedItemId=LS.fixedNext(s)end
  return f
 end
 local function unitFor(s,itemId)
  local missing=LE.missing(s.charmUnlocks);local misses=LS.misses(s)
  if LE.pityDue(missing,misses)then local i=table.find(missing,LE.shape(itemId));assert(i,"pity draws a charm");return(i-.5)/#missing end
  local cumulative=0
  for _,row in ipairs(LE.odds(missing))do if row.id==itemId then return(cumulative+row.percent/2)/100 end;cumulative+=row.percent end
  error("not in the pool: "..itemId)
 end
 local function look(h,c,itemId)c.unit=unitFor(h.state,itemId);local q,r,receipt=command(h,"lookBuy",lookFields(h));assert(receipt.itemId==itemId);return q,r,receipt end
 local function store(h)return command(h,"hueStore",{resultId=h.state.pendingHueResult.id})end
 local function finishUse(h,item,pet,pending)
  return command(h,"finishUse",{petId=pet or "pip",itemId=item,finish=LS.finish(h.state,pet or "pip"),pendingResultId=if pending then h.state.pendingHueResult.id else nil})
 end
 local function refuse(h,action,fields,expected)
  local q,r=request(h,fields);local ok,why=H.hueCommand(h,action,q,r)
  assert(not ok and why==expected,action..": expected "..expected..", got "..tostring(why));return q,r
 end
 local function grantFinish(h,stock)
  h.state.finishInventory=copy(stock);currentDb.player_1.hatching.finishInventory=copy(stock);assert(RawH.valid(h.state))
 end
 local function mutate(state,id,f)f(state.hueItemReceipts[id]);if state.lastHueResult and state.lastHueResult.id==id then f(state.lastHueResult)end end

 test("a fresh save starts with no egg charm, publishes the look fields and refuses a closed egg",function()
  local h,db,c=fixture()
  local saved=db.player_1.hatching.charmUnlocks;assert(type(saved)=="table"and next(saved)==nil,"fresh save: charmUnlocks = {}")
  local p=H.public(h)
  assert(p.lookAvailable==H.lookAvailable(h)and p.lookSelectionMode=="random"and p.lookPoolVersion==LE.PoolVersion and p.lookCharmMisses==0 and p.lookFound==0)
  assert(next(p.charmUnlocks)==nil and p.finishInventory.gloss==0 and p.finishInventory.jelly==0 and p.petFinish.pip.sheen==0 and p.petFinish.pip.jelly==0)
  assert(p.nextFixed.look=="rose")
  local balance,rolls,updates=h.state.nectar,c.rolls,c.updates
  h.lookAvailable=false -- templates not verified, or the switch off: the whole egg is Not ready
  refuse(h,"lookBuy",lookFields(h),"NotReady")
  assert(h.state.nectar==balance and c.rolls==rolls and c.updates==updates and not db.player_1.hatching.hueReservation,"refused before any write or roll")
 end)

 test("a save from before this build keeps Snowflake, Ring and Pebble and its charm choice",function()
  local h,db,_,a=fixture();assert(H.release(h))
  local old=db.player_1.hatching;old.charmUnlocks=nil
  db.player_1.petAppearance.pip={charmVisible=true,charmShape="ring",at=2,writer="old"}
  h=H.load(1,{},a);assert(h.status=="Ready")
  local u=db.player_1.hatching.charmUnlocks;assert(u.dot==true and u.ring==true and u.pebble==true,"legacy grant written once")
  assert(db.player_1.petAppearance.pip.charmShape=="ring"and db.player_1.petAppearance.pip.charmVisible==true,"profile choice untouched")
  assert(#LE.missing(h.state.charmUnlocks)==0 and H.public(h).nextFixed.look=="rose")
  assert(H.release(h));h=H.load(1,{},a);assert(h.status=="Ready"and h.state.charmUnlocks.pebble==true)
  -- A field already written is never reinterpreted: an empty set stays empty.
  assert(H.release(h));db.player_1.hatching.charmUnlocks={};h=H.load(1,{},a);assert(next(h.state.charmUnlocks)==nil)
 end)

 test("temporary and failed loads hold no egg charm and write nothing",function()
  local _,db,_,a=fixture()
  local t=H.load(1,{loadFailed=true},a);assert(t.status=="Temporary"and next(t.state.charmUnlocks)==nil)
  local before=copy(db.player_1.hatching);db.player_1.hatching.nectar=-1
  local bad=H.load(1,{},a);assert(bad.status=="InvalidData"and next(bad.state.charmUnlocks)==nil and db.player_1.hatching.nectar==-1)
  db.player_1.hatching=before
 end)

 test("every new field loads when well formed; malformed new fields fail closed",function()
  local h,db,_,a=fixture();assert(H.release(h))
  local full=copy(db.player_1.hatching)
  full.finishInventory={gloss=1,matte=0,jelly=2};full.petFinish={pip={sheen=-3,jelly=3}};full.charmUnlocks={dot=true}
  full.lookCharmMisses=14;full.lookFound=1023
  db.player_1.hatching=copy(full);h=H.load(1,{},a);assert(h.status=="Ready","all fields: "..h.status)
  assert(H.public(h).petFinish.pip.sheen==-3 and H.public(h).finishInventory.jelly==2 and H.public(h).lookCharmMisses==14)
  assert(RawH.valid((function()local s=copy(h.state);s.finishInventory=nil;s.petFinish=nil;s.lookCharmMisses=nil;s.lookFound=nil;return s end)()),"each field is optional")
  local bad={
   {"finishInventory",{gloss=-1}},{"finishInventory",{gloss=1.5}},{"finishInventory",{shine=1}},{"finishInventory","x"},
   {"petFinish",{blip={sheen=0,jelly=0}}},{"petFinish",{pip={sheen=4,jelly=0}}},{"petFinish",{pip={sheen=0}}},{"petFinish",{pip={sheen=0,jelly=0,gloss=1}}},{"petFinish",{nope={sheen=0,jelly=0}}},
   {"charmUnlocks",{heart=true}},{"charmUnlocks",{dot=1}},{"charmUnlocks","all"},
   {"lookCharmMisses",64},{"lookCharmMisses",-1},{"lookCharmMisses",1.5},{"lookFound",1024},{"lookFound",-1},
  }
  for _,case in ipairs(bad)do
   local s=copy(h.state);s[case[1]]=case[2];assert(not RawH.valid(s),case[1].." accepted a malformed value")
  end
  assert(H.release(h));local saved=copy(db.player_1.hatching);db.player_1.hatching.charmUnlocks={heart=true}
  local refused=H.load(1,{},a);assert(refused.status=="InvalidData"and db.player_1.hatching.charmUnlocks.heart==true,"fail closed, nothing written")
  db.player_1.hatching=saved
 end)

 test("each item kind lands in its own inventory at the quoted price; misses, found bits and acks",function()
  local h,_,c=fixture();fund(h);h.lookAvailable=true
  local balance=h.state.nectar
  local _,_,receipt=look(h,c,"tide")
  assert(receipt.cost==LE.Price and h.state.nectar==balance-LE.Price and h.state.hueInventory.tide==1 and receipt.inventoryBefore==0 and receipt.inventoryAfter==1)
  assert(receipt.missesBefore==0 and receipt.missesAfter==1 and h.state.lookCharmMisses==1 and h.state.lookFound==LE.bit("tide"))
  assert(h.state.pendingHueResult.itemId=="tide"and h.state.pendingHueResult.inventoryAfter==1)
  command(h,"hueUse",{itemId="tide",petId="pip",channel="main",counts=S.row(h.state,"pip").main,pendingResultId=h.state.pendingHueResult.id})
  assert(h.state.petHues.pip.main.tide==1 and h.state.hueInventory.tide==0 and not h.state.pendingHueResult)
  look(h,c,"gloss");assert(h.state.finishInventory.gloss==1 and h.state.finishInventory.matte==0 and h.state.lookCharmMisses==2)
  local blocked=lookFields(h);refuse(h,"lookBuy",blocked,"RevealPending")
  finishUse(h,"gloss","pip",true);assert(h.state.petFinish.pip.sheen==1 and h.state.finishInventory.gloss==0 and not h.state.pendingHueResult)
  _,_,receipt=look(h,c,"charm_ring")
  assert(h.state.charmUnlocks.ring==true and receipt.inventoryBefore==0 and receipt.inventoryAfter==1 and receipt.missesAfter==0 and h.state.lookCharmMisses==0)
  assert(h.state.pendingHueResult.itemId=="charm_ring")
  local q,r=request(h,{itemId="rose",petId="pip",channel="main",counts=S.row(h.state,"pip").main,pendingResultId=h.state.pendingHueResult.id})
  local ok,why=H.hueCommand(h,"hueUse",q,r);assert(not ok and why=="RevealPending","a charm is acknowledged with hueStore")
  store(h);assert(not h.state.pendingHueResult and h.state.charmUnlocks.ring==true)
  assert(table.concat(LE.missing(h.state.charmUnlocks),",")=="dot,pebble"and #LE.odds(LE.missing(h.state.charmUnlocks))==9)
  local found=bit32.bor(LE.bit("tide"),LE.bit("gloss"),LE.bit("charm_ring"));assert(h.state.lookFound==found)
  look(h,c,"jelly");store(h);assert(h.state.finishInventory.jelly==1)
  -- The Hue Egg still sells beside it, with its own price and roll.
  c.unit=.01;local _,_,hueReceipt=command(h,"hueBuy",{});assert(hueReceipt.itemId=="rose"and hueReceipt.cost==Hue.Cost);store(h)
  local p=H.public(h);assert(p.charmUnlocks.ring==true and p.finishInventory.jelly==1 and p.petFinish.pip.sheen==1 and p.lookFound==bit32.bor(found,LE.bit("jelly")))
 end)

 test("the same quote replays its receipt without a roll; the same id with another quote conflicts",function()
  local h,_,c=fixture();h.lookAvailable=true
  local q,r,receipt=look(h,c,"citrus");local rolls,balance=c.rolls,h.state.nectar
  local ok,why,again=H.hueCommand(h,"lookBuy",q,r);assert(ok and why=="AlreadySaved"and again.itemId=="citrus"and again.resultId==receipt.resultId)
  assert(c.rolls==rolls and h.state.nectar==balance and h.state.hueInventory.citrus==1)
  local altered=copy(q);altered.charmMisses=5;ok,why=H.hueCommand(h,"lookBuy",altered,r);assert(not ok and why=="OperationConflict")
 end)

 test("a reservation saved while the egg was on sale settles after the switch goes off, once",function()
  local h,db,c,a=fixture();fund(h);h.lookAvailable=true;c.failSettlement=true
  c.unit=unitFor(h.state,"iris");local q,r=request(h,lookFields(h));local balance=h.state.nectar
  local ok,why=H.hueCommand(h,"lookBuy",q,r);assert(not ok and why=="Retrying")
  assert(db.player_1.hatching.hueReservation and db.player_1.hatching.hueReservation.itemId=="iris"and db.player_1.hatching.hueInventory.iris==0)
  c.now+=100;c.unit=.99
  -- Settlement runs inside load, before any availability is read: it never checks the switch.
  local joined=H.load(1,{},a)
  assert(joined.status=="Ready"and joined.state.hueInventory.iris==1 and joined.state.nectar==balance-LE.Price and not joined.state.hueReservation and c.rolls==1)
  assert(joined.state.pendingHueResult.itemId=="iris"and RawH.valid(joined.state))
  ok,why=H.hueCommand(joined,"lookBuy",q,r);assert(ok and why=="AlreadySaved"and joined.state.hueInventory.iris==1)
 end)

 test("a reserved charm owned before settlement becomes a jar and records substitutedFrom",function()
  local h,db,c,a=fixture();fund(h);h.lookAvailable=true;c.failSettlement=true
  c.unit=unitFor(h.state,"charm_dot");local q,r=request(h,lookFields(h));assert(not H.hueCommand(h,"lookBuy",q,r))
  assert(db.player_1.hatching.hueReservation.itemId=="charm_dot")
  db.player_1.hatching.charmUnlocks={dot=true};c.now+=100
  local joined=H.load(1,{},a);assert(joined.status=="Ready")
  local receipt=joined.state.hueItemReceipts[q.id]
  assert(receipt.substitutedFrom=="charm_dot"and receipt.itemId=="rose"and receipt.cost==LE.Price and receipt.outcome=="Applied")
  assert(joined.state.hueInventory.rose==1 and joined.state.pendingHueResult.itemId=="rose"and RawH.valid(joined.state))
 end)

 test("Stars spent before settlement resolve as a free refusal, never a stuck reservation",function()
  local h,db,c,a=fixture();h.lookAvailable=true;c.failSettlement=true
  c.unit=unitFor(h.state,"rose");local q,r=request(h,lookFields(h));assert(not H.hueCommand(h,"lookBuy",q,r))
  db.player_1.hatching.nectar=5;c.now+=100
  local joined=H.load(1,{},a);assert(joined.status=="Ready")
  local receipt=joined.state.hueItemReceipts[q.id]
  assert(receipt.outcome=="Refused"and receipt.reason=="NeedStars"and receipt.cost==0 and joined.state.nectar==5)
  assert(not joined.state.hueReservation and not joined.state.pendingHueResult and joined.state.hueInventory.rose==0 and RawH.valid(joined.state))
  joined.lookAvailable=true;refuse(joined,"lookBuy",lookFields(joined),"NeedStars")
 end)

 test("reserve-time refusals write nothing and never roll",function()
  local h,db,c=fixture();h.lookAvailable=true
  local rolls=c.rolls;local f=lookFields(h)
  local function refused(fields,expected)refuse(h,"lookBuy",fields,expected);assert(c.rolls==rolls and not db.player_1.hatching.hueReservation)end
  h.lookAvailable=false;refused(f,"NotReady");h.lookAvailable=true
  local g=copy(f);g.selectionMode="fixed";g.fixedItemId=LS.fixedNext(h.state);refused(g,"PolicyChanged")
  g=copy(f);g.charmMisses=3;refused(g,"PoolChanged")
  g=copy(f);g.missingCharms={"ring","pebble"};refused(g,"PoolChanged")
  for _,bad in ipairs({{poolVersion=2},{price=13},{selectionMode="lucky"},{missingCharms={"pebble","dot"}},{missingCharms={"heart"}},{charmMisses=64},{fixedItemId="rose"}})do
   g=copy(f);for k,v in pairs(bad)do g[k]=v end;refused(g,"InvalidHue")
  end
  g=copy(f);g.selectionMode="fixed";g.fixedItemId="charm_star";refused(g,"InvalidHue")
  look(h,c,"rose");store(h);rolls=c.rolls
  -- Leave less than one egg's price (awards may be boosted in Studio, so set it directly).
  h.state.nectar=LE.Price-1;db.player_1.hatching.nectar=LE.Price-1
  refused(lookFields(h),"NeedStars")
 end)

 test("fourteen misses force a charm; the counter resets and stays 0 once every egg charm is owned",function()
  local h,db,c,a=fixture();fund(h);assert(H.release(h))
  db.player_1.hatching.lookCharmMisses=14;h=H.load(1,{},a);h.lookAvailable=true
  c.unit=.01;local _,_,receipt=command(h,"lookBuy",lookFields(h))
  assert(receipt.itemId=="charm_dot"and receipt.missesBefore==14 and receipt.missesAfter==0,"the 15th egg is a charm")
  store(h);assert(H.release(h))
  db.player_1.hatching.charmUnlocks={dot=true,ring=true,pebble=true};db.player_1.hatching.lookCharmMisses=0
  h=H.load(1,{},a);h.lookAvailable=true
  for _=1,3 do c.unit=.5;_,_,receipt=command(h,"lookBuy",lookFields(h));assert(LE.kind(receipt.itemId)~="charm"and receipt.missesAfter==0);store(h)end
 end)

 test("restricted accounts get the named next item; every 12th egg is the first missing charm",function()
  local h,_,c=fixture();fund(h);h.restricted=true;h.lookAvailable=true
  assert(H.public(h).lookSelectionMode=="fixed")
  local rolls=c.rolls
  for n=1,12 do
   local f=lookFields(h,"fixed");local _,_,receipt=command(h,"lookBuy",f)
   assert(receipt.itemId==f.fixedItemId,"named item "..n)
   if n==12 then assert(receipt.itemId=="charm_dot")else assert(LE.kind(receipt.itemId)~="charm")end
   store(h)
  end
  assert(c.rolls==rolls,"restricted never rolls")
  local f=lookFields(h,"fixed");f.fixedItemId=if f.fixedItemId=="jelly"then "rose"else "jelly";refuse(h,"lookBuy",f,"PoolChanged")
  refuse(h,"lookBuy",lookFields(h,"random"),"PolicyChanged")
 end)

 test("finish doses: Gloss and Matte cancel, Jelly stacks to 3, refusals keep the jar, Original is free per axis",function()
  local h,_,c=fixture();h.lookAvailable=true
  grantFinish(h,{gloss=4,matte=3,jelly=4})
  for _=1,3 do finishUse(h,"gloss")end;assert(h.state.petFinish.pip.sheen==3)
  local function refusedUse(item,expected)
   refuse(h,"finishUse",{petId="pip",itemId=item,finish=LS.finish(h.state,"pip")},expected)
  end
  refusedUse("gloss","MaxSheen");assert(h.state.finishInventory.gloss==1,"a refusal keeps the jar")
  finishUse(h,"matte");finishUse(h,"matte");assert(h.state.petFinish.pip.sheen==1)
  for _=1,3 do finishUse(h,"jelly")end;refusedUse("jelly","MaxJelly");assert(h.state.petFinish.pip.jelly==3 and h.state.finishInventory.jelly==1)
  refuse(h,"finishUse",{petId="pip",itemId="matte",finish={sheen=0,jelly=0}},"FinishChanged")
  refuse(h,"finishUse",{petId="blip",itemId="matte",finish={sheen=0,jelly=0}},"Unowned")
  local balance=h.state.nectar
  command(h,"finishClear",{petId="pip",axis="sheen",finish=LS.finish(h.state,"pip")})
  assert(h.state.petFinish.pip.sheen==0 and h.state.petFinish.pip.jelly==3 and h.state.nectar==balance and h.state.finishInventory.matte==1)
  refuse(h,"finishClear",{petId="pip",axis="sheen",finish=LS.finish(h.state,"pip")},"AlreadyOriginal")
  command(h,"finishClear",{petId="pip",axis="jelly",finish=LS.finish(h.state,"pip")})
  assert(h.state.petFinish.pip==nil and H.public(h).petFinish.pip.jelly==0,"an all-Original row is dropped")
  finishUse(h,"matte");refusedUse("matte","EmptyStock")
  -- A finish jar from the egg is used straight from its result.
  fund(h);look(h,c,"matte");finishUse(h,"matte","pip",true);assert(h.state.petFinish.pip.sheen==-2 and not h.state.pendingHueResult)
 end)

 test("a jar at the stack limit is a free refusal that clears the reservation",function()
  local h,db,c=fixture();h.lookAvailable=true
  h.state.hueInventory.rose=Hue.StackLimit;db.player_1.hatching.hueInventory.rose=Hue.StackLimit
  local balance=h.state.nectar;c.unit=unitFor(h.state,"rose");local _,_,receipt=command(h,"lookBuy",lookFields(h))
  assert(receipt.outcome=="Refused"and receipt.reason=="StackLimit"and receipt.cost==0 and h.state.nectar==balance)
  assert(not h.state.pendingHueResult and not h.state.hueReservation and LS.misses(h.state)==0 and receipt.missesAfter==receipt.missesBefore)
 end)

 test("corrupt Customization Egg receipts and reservations fail validation",function()
  local h,_,c=fixture();fund(h);h.lookAvailable=true
  local charmQ=look(h,c,"charm_pebble");store(h)
  grantFinish(h,{gloss=1,matte=0,jelly=0});local useQ=finishUse(h,"gloss")
  local hueQ=look(h,c,"rose")
  local good=copy(h.state);assert(RawH.valid(good))
  local cases={
   function(s)mutate(s,hueQ.id,function(r)r.cost=8;r.balanceAfter=r.balanceBefore-8 end)end,
   function(s)mutate(s,charmQ.id,function(r)r.missesAfter=3 end)end,
   function(s)mutate(s,charmQ.id,function(r)r.inventoryAfter=2 end)end,
   function(s)mutate(s,useQ.id,function(r)r.finishAfter={sheen=2,jelly=0}end)end,
   function(s)mutate(s,useQ.id,function(r)r.channel="main"end)end,
   function(s)mutate(s,hueQ.id,function(r)r.substitutedFrom="charm_pebble"end)end, -- pebble was already owned: not in the quoted pool
   function(s)s.pendingHueResult.itemId="tide"end,
  }
  for index,f in ipairs(cases)do local s=copy(good);f(s);assert(not RawH.valid(s),"corrupt case "..index)end
  -- Reservations: build one from a valid quote on an acknowledged state.
  store(h);local base=copy(h.state)
  local q=S.quote("lookBuy",(function()local v=lookFields(h);v.id=tostring(base.revision)..":look-res";v.catalogVersion=Hue.CatalogVersion;return v end)(),base.revision)
  assert(q,"reservation quote")
  local function reserved(itemId)local s=copy(base);s.hueReservation={quote=copy(q),operationId="op-res",sequence=s.operationSeq+1,itemId=itemId};return s end
  assert(RawH.valid(reserved("rose"))and RawH.valid(reserved("charm_dot")))
  assert(not RawH.valid(reserved("charm_pebble")),"an owned charm is not in the quoted pool")
  assert(not RawH.valid(reserved("charm_heart"))and not RawH.valid(reserved("reset")))
  local fixed=copy(q);fixed.selectionMode="fixed";fixed.fixedItemId="tide";assert(S.quote("lookBuy",(function()local v=copy(fixed);v.action=nil;v.revision=nil;return v end)(),base.revision))
  local s=reserved("rose");s.hueReservation.quote=fixed;assert(not RawH.valid(s),"a fixed reservation draws only its named item")
  s=reserved("tide");s.hueReservation.quote=fixed;assert(RawH.valid(s))
 end)

 return{passed=#cases,cases=cases,persistentWrites=false}
end
