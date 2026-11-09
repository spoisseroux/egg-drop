return function(client)
 local Intent=require(client.MaterialIntent);local Catalog=require(game.ReplicatedStorage.Shared.MaterialCatalog)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function fixture()
  local sent,timers={},{};local serial=0
  local intent=Intent.new({id=function()serial+=1;return "material-"..serial end,send=function(action,value,revision)table.insert(sent,{action=action,value=value,revision=revision})end,delay=function(seconds,run)assert(seconds==8);table.insert(timers,run)end})
  local state={revision=1,status="Ready",nectar=64,inventoryMask=127,materialAvailable=true,materialUnlocks={},petMaterials={}}
  intent:update(state);return intent,state,sent,timers
 end
 test("purchase captures sorted remaining pool version and blocks duplicate purchase",function()
  local i,s,sent=fixture();s.materialUnlocks.gloss=true
  assert(i:buy()and not i:buy()and #sent==1)
  local q=sent[1].value;assert(q.id=="1:material-1"and q.catalogVersion==1 and q.poolVersion==Catalog.PoolVersion and table.concat(q.eligible,",")==table.concat(Catalog.remaining(s.materialUnlocks),",")and s.nectar==64)
 end)
 test("full collection and unverified pool cannot send or debit",function()
  local i,s,sent=fixture();s.materialAvailable=false;assert(not i:buy()and #sent==0)
  s.materialAvailable=true;s.materialUnlocks={};for _,id in ipairs(Catalog.PaidOrder)do s.materialUnlocks[id]=true end;assert(not i:buy()and i.message=="All materials owned"and #sent==0 and s.nectar==64)
 end)
 test("lost response timeout and retry retain exact quote object and revision",function()
  local i,_,sent,timers=fixture();assert(i:buy());timers[1]();assert(i.status=="Retrying"and i:retry())
  assert(#sent==2 and sent[1].value==sent[2].value and sent[1].revision==sent[2].revision)
 end)
 test("Saved cannot unlock early and malformed same-ID finish cannot clear exact receipt wait",function()
  local i,s,sent=fixture();assert(i:buy());local q=sent[1].value
  local receipt={id=q.id,action="materialBuy",revision=2,catalogVersion=1,cost=16,finishId="unknown",resultId=q.id}
  assert(not i:receive({id=q.id,action="materialBuy",status="Saved",receipt=receipt})and i.pending)
  receipt.finishId="gloss";assert(i:receive({id=q.id,action="materialBuy",status="Saved",receipt=receipt})and i.pending and not s.materialUnlocks.gloss)
  s.revision=2;s.nectar=48;s.materialUnlocks.gloss=true;s.pendingMaterialResult={id=q.id,finishId="gloss",revision=2,catalogVersion=1};s.lastMaterialResult=receipt;i:update(s)
  assert(not i.pending and i.receipt==receipt and i.message==nil and s.nectar==48)
 end)
 test("free equip captures per-pet expected finish and cannot equip locked or unowned pet",function()
  local i,s,sent=fixture();assert(not i:equip("pip","metal"));s.materialUnlocks.metal=true;s.inventoryMask=1
  assert(not i:equip("puddle","metal")and i:equip("pip","metal")and not i:equip("pip","metal"))
  local q=sent[1].value;assert(q.petId=="pip"and q.finishId=="metal"and q.expectedFinish=="standard"and s.petMaterials.pip==nil and s.nectar==64)
 end)
 test("Use now preserves result identity and selected finish before snapshot proof",function()
  local i,s,sent=fixture();s.materialUnlocks.gloss=true;s.pendingMaterialResult={id="paid-result",finishId="gloss",revision=1,catalogVersion=1}
  assert(not i:equip("pip","gloss","foreign")and i:equip("pip","gloss","paid-result"));local q=sent[1].value
  local r={id=q.id,action="materialEquip",petId="pip",revision=2,catalogVersion=1,cost=0,finishId="gloss",selectedBefore="standard",selectedAfter="gloss",acknowledgedResultId="paid-result"}
  assert(i:receive({id=q.id,action=q and "materialEquip",petId="pip",status="Saved",receipt=r})and i.pending)
  s.revision=2;s.lastMaterialResult=r;s.petMaterials.pip="gloss";s.pendingMaterialResult=nil;i:update(s)
  assert(not i.pending and s.nectar==64 and s.petMaterials.pip=="gloss")
 end)
 test("destroyed owner cannot revive a pending timeout or send another command",function()
  local i,_,sent,timers=fixture();i:buy();i:destroy();timers[1]();assert(not i:buy()and not i:retry()and #sent==1 and not i.pending)
 end)
 return {passed=#cases,cases=cases}
end
