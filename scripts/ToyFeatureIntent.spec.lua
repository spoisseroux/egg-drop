return function(client)
 local Toy=require(client.ToyIntent);local Feature=require(client.FeatureIntent);local cases={}
 local function test(n,f)f();table.insert(cases,n)end
 local function deps()local sent={};return {id=function()return "intent-fixture"end,delay=function()end,send=function(a,v,r)table.insert(sent,{action=a,value=v,revision=r})end},sent end
 local function state()return {status="Ready",revision=10,nectar=64,inventoryMask=127,toyUnlocks={},petToys={},featureStock={horns=2,claws=0,wings=0},petFeatures={pip={horns={earned=0,visible=0},claws={earned=0,visible=0},wings={earned=0,visible=0}}}}end
 test("Toy purchase uses sorted quote and waits for matching snapshot grant",function()
  local d,sent=deps();local intent=Toy.new(d);intent:update(state());assert(intent:buy()and #sent==1)
  local p=intent.pending;assert(p.value.id=="10:toy-intent-fixture"and table.concat(p.value.eligible,",")=="ball,bone,sparkler")
  local r={id=p.value.id,action="toyBuy",catalogVersion=1,revision=11,cost=8,balanceBefore=64,balanceAfter=56,toyId="ball",resultId=p.value.id}
  assert(intent:receive({id=r.id,action=r.action,status="Saved",receipt=r})and intent.pending)
  local nextState=state();nextState.revision=11;intent:update(nextState);assert(intent.pending)
  nextState.toyUnlocks.ball=true;intent:update(nextState);assert(not intent.pending and intent.receipt==r)
 end)
 test("Toy retries preserve exact quote and all-owned or cross-kind results block purchase",function()
  local d,sent=deps();local intent=Toy.new(d);local s=state();intent:update(s);intent:buy();local p=intent.pending
  intent:receive({id=p.value.id,action=p.action,status="Retrying"});assert(intent:retry()and sent[2].value==sent[1].value and sent[2].revision==10)
  local other=Toy.new(d);s.pendingFeatureResult={id="held"};other:update(s);assert(not other:buy());s.pendingFeatureResult=nil;s.toyUnlocks={ball=true,bone=true,sparkler=true};other:update(s);assert(not other:buy())
 end)
 test("Feature growth requires exact stage stock visibility and committed snapshot",function()
  local d,sent=deps();local intent=Feature.new(d);intent:update(state());assert(intent:use("pip","horns"))
  local p=intent.pending;local r={id=p.value.id,action=p.action,catalogVersion=1,revision=11,cost=0,outcome="Applied",petId="pip",featureId="horns",earnedBefore=0,earnedAfter=1,visibleBefore=0,visibleAfter=1,inventoryBefore=2,inventoryAfter=1}
  local bad=table.clone(r);bad.inventoryBefore=3;bad.inventoryAfter=2
  assert(not intent:receive({id=r.id,action=r.action,petId="pip",status="Saved",receipt=bad}))
  local nextState=state();nextState.revision=11;nextState.featureStock.horns=1;nextState.petFeatures.pip.horns={earned=1,visible=1};intent:update(nextState);assert(intent.pending)
  assert(intent:receive({id=r.id,action=r.action,petId="pip",status="Saved",receipt=r})and not intent.pending and intent.receipt==r and #sent==1)
 end)
 test("Feature hidden visibility preserves earned stage and caps never consume stock",function()
  local d,sent=deps();local intent=Feature.new(d);local s=state();s.petFeatures.pip.horns={earned=5,visible=3};intent:update(s)
  assert(not intent:use("pip","horns")and not intent:show("pip","horns",6)and #sent==0)
  assert(intent:show("pip","horns",0));local p=intent.pending
  local r={id=p.value.id,action=p.action,catalogVersion=1,revision=11,cost=0,outcome="Applied",petId="pip",featureId="horns",earnedBefore=5,earnedAfter=5,visibleBefore=3,visibleAfter=0}
  s.revision=11;s.petFeatures.pip.horns.visible=0;s.lastFeatureResult=r;intent:update(s);assert(not intent.pending and s.petFeatures.pip.horns.earned==5 and s.featureStock.horns==2)
 end)
 test("Feature full rolled stack is a durable zero-debit refusal with no result",function()
  local d=deps();local intent=Feature.new(d);local s=state();s.featureStock.horns=99;intent:update(s);assert(intent:buy());local p=intent.pending
  local r={id=p.value.id,action=p.action,catalogVersion=1,revision=11,cost=0,outcome="Refused",reason="StackLimit",featureId="horns",inventoryBefore=99,inventoryAfter=99,balanceBefore=64,balanceAfter=64}
  assert(intent:receive({id=r.id,action=r.action,status="Saved",receipt=r})and intent.pending);s.revision=11;intent:update(s);assert(not intent.pending and intent.status=="Rejected"and intent.message:find("No Stars",1,true))
 end)
 return cases
end
