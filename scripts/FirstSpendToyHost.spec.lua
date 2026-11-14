-- Real saved-receipt guide + normal prop sampler, with distinct local/server clocks.
return function(client,parent)
 local Host=require(client.FirstSpendToyHost);local Guide=require(client.FirstSpendGuide)
 local Play=require(client.PetPlayVisual);local Opportunity=require(client.PersonalToyOpportunity)
 local Factory=require(client.PetFactory);local Shared=game:GetService("ReplicatedStorage").Shared
 local Toys=require(Shared.ToyCatalog);local Pets=require(Shared.PetCatalog)
 local root=Instance.new("Folder");root.Name="_FirstSpendToyHost";root.Parent=parent or workspace
 local visuals,cases={},{};local function test(name,run)run();table.insert(cases,name)end
 local function fixture()
  local c={now=1000,entered=0}
  c.actor={mode="Room",behavior="rest",action="wanderPause",startTime=1000,endTime=1001.5,from={0,4,0},to={0,4,0},characterId=7,petGeneration=3,generation=8,actionId=9}
  c.visual=Factory.new(root,Vector3.new(0,4,0),Pets.byId.pip,.72,{toyId="wobble_top",appearanceGeneration=1},{native=true})
  table.insert(visuals,c.visual)
  local v=c.visual;v.time=.2;v.gardenBehavior="rest";v.gardenAction="wanderPause";v.personalPlayEnabled=true;v.greeting=2;v.gaitWeight=0;v.ownerMoving=false
  c.intent={status="Ready",equip=function(self,petId,toyId,resultId)
   self.status="Pending";self.pending={action="toyEquip",value={id="equip",petId=petId,toyId=toyId,resultId=resultId}};return true
  end}
  c.guide=Guide.new({intent=c.intent,actorIdentity=function()return Host.identity(c.actor)end,
   enterRoom=function()c.entered+=1 end,play=function(_,toyId)return Host.try(c.guide,v,toyId,Play,c.now)end})
  local state={revision=2,status="Ready",inventoryMask=1,nectar=0,toyUnlocks={wobble_top=true},petToys={},
   pendingToyResult={id="purchase",toyId="wobble_top",revision=2,catalogVersion=Toys.CatalogVersion},
   lastToyResult={id="purchase",action="toyBuy",toyId="wobble_top",resultId="purchase",revision=2,catalogVersion=Toys.CatalogVersion,cost=Toys.Cost,balanceBefore=Toys.Cost,balanceAfter=0}}
  c.guide:update(state,{eligible=true});assert(c.guide:give("pip"))
  assert(c.entered==0);c.intent.status="Saved";c.intent.pending=nil
  state.revision=3;state.pendingToyResult=nil;state.petToys.pip="wobble_top"
  state.lastToyResult={id="equip",action="toyEquip",petId="pip",toyId="wobble_top",acknowledgedResultId="purchase"}
  c.guide:update(state,{eligible=true});assert(c.entered==1)
  function c:step(now,noCosmeticTime)
   self.now=now;Opportunity.apply(v,self.actor,now);v.personalActorIdentity=Host.identity(self.actor)
   v.cosmeticTime=if noCosmeticTime then nil else now
   return self.guide:step({mode="Room",ready=true,petId="pip",actorReady=Host.ready(v,self.actor,self.guide.flight),actorIdentity=Host.identity(self.actor)})
  end
  return c
 end
 local ok,problem=pcall(function()
  test("saved Give starts a real short prop in ordinary rest on shared clock",function()
   for _,fallbackClock in ipairs({false,true})do
    local c=fixture();local v=c.visual
    assert(not c:step(1000,fallbackClock)and c.guide.flight,"quiet wait must not consume saved handoff")
    assert(v.personalQuietSince==1000 and not v.personalToyActive,"quiet clock was rewound")
    assert(c:step(1000.16,fallbackClock)and not c.guide.flight and v.personalToyActive and v.personalToy)
    assert(v.personalPlayStarted==1000.16 and v.personalClipDuration==.9 and v.model:GetAttribute("OnboardingToyBeat")=="wobble_top")
    assert(Play.sample(v,1000.3)and v.personalToyActive,"elapsed visual.time instantly expired real beat")
    assert(v.personalNextOpportunity>1009,"handoff shortened autonomous cooldown after starting")
   end
  end)
  test("an already active normal beat keeps its original cooldown",function()
   local c=fixture();local v=c.visual
   c:step(1000);v.cosmeticTime=1000.16;assert(Play.sample(v,1000.16));local deadline=v.personalNextOpportunity
   assert(c:step(1000.17)and v.personalNextOpportunity==deadline,"observed active beat reset next opportunity")
  end)
  test("park or replaced actor cannot inherit a pending saved handoff",function()
   local c=fixture();c.actor.park={parkId="grove"};assert(not c:step(1000)and c.guide.flight and not c.visual.personalToy)
   c=fixture();c:step(1000);c.actor.petGeneration+=1
   assert(not c:step(1000.16)and not c.guide.flight and not c.visual.personalToy,"replacement pet inherited Give")
  end)
 end)
 for _,v in ipairs(visuals)do v:destroy()end;root:Destroy();assert(ok,problem)
 return{passed=#cases,cases=cases}
end
