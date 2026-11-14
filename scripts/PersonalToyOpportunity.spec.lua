-- Shared opportunity and actual normal toy sampler. No server actor mutation.
return function(client,parent)
 local Opportunity=require(client.PersonalToyOpportunity)
 local Factory=require(client.PetFactory);local Play=require(client.PetPlayVisual)
 local Pets=require(game.ReplicatedStorage.Shared.PetCatalog)
 local root=Instance.new("Folder");root.Name="_PersonalToyOpportunity";root.Parent=parent or workspace
 local visuals,cases={},{};local function test(name,run)run();table.insert(cases,name)end
 local function actor()
  return{mode="Room",behavior="rest",action="wanderPause",startTime=1000,endTime=1001.5,
   from={0,4,0},to={0,4,0},characterId=7,petGeneration=3,generation=8,actionId=9}
 end
 local function visual()
  local v=Factory.new(root,Vector3.new(0,4,0),Pets.byId.pip,.72,{toyId="wobble_top",appearanceGeneration=1},{native=true})
  table.insert(visuals,v);v.gardenBehavior="rest";v.gardenAction="wanderPause";v.personalPlayEnabled=true;v.greeting=2;v.gaitWeight=0;v.ownerMoving=false;v.cosmeticSeed=42
  return v
 end
 local function sample(v,a,now)
  Opportunity.apply(v,a,now);v.cosmeticTime=now;return Play.sample(v,now)
 end
 local ok,problem=pcall(function()
 test("published follow and ordinary rest retain distinct bounded timings",function()
  local a=actor();local deadline,duration,quiet,guard,rest=Opportunity.fromActor(a,1000)
  assert(deadline==1001.5 and duration==.9 and quiet==.15 and guard==.1 and rest)
  a.behavior,a.action="follow","follow"
  deadline,duration,quiet,guard,rest=Opportunity.fromActor(a,1000)
  assert(deadline==1005 and duration==1.8 and quiet==.75 and guard==.15 and not rest)
  a.action=nil;assert(Opportunity.fromActor(a,1000)==1005,"raw Garden follow omits redundant action")
  a.behavior,a.action="rest","nookRest";assert(Opportunity.fromActor(a,1000.34)==nil)
  assert(Opportunity.fromActor(a,1000.36)==1001.5)
 end)
 test("park care pair focus contact reservation movement and malformed windows reject",function()
  for _,entry in ipairs({{"park",{}},{"parkId","grove"},{"care",{}},{"peerId",4},{"pairId",2},{"toyRole","winner"},{"toyReservation",2},{"toyStartTime",0},{"contact",{}},{"focus",true},{"focused",true},{"carried",true},{"mode","Focus"},{"action","parkReturn"},{"behavior","investigate"},{"endTime",0/0},{"from",{1,4,0}}})do
   local a=actor();a[entry[1]]=entry[2];assert(Opportunity.fromActor(a,1000)==nil,entry[1].." allowed a competing activity")
  end
  assert(Opportunity.fromActor(actor(),1001.5)==nil)
 end)
 test("real normal prop fits 1.5 second rest without resetting autonomous cooldown",function()
  local a,v=actor(),visual()
  assert(sample(v,a,1000)==nil,"quiet settle must run")
  assert(sample(v,a,1000.16)and v.personalToyActive and v.personalClipDuration==.9)
  local deadline=v.personalNextOpportunity;local prop=v.personalToy
  assert(sample(v,a,1001.05)and v.personalToyActive,"short clip ended early")
  assert(sample(v,a,1001.07)==nil and not v.personalToy,"short clip exceeded its bounded duration")
  assert(prop.destroyed and v.personalNextOpportunity==deadline and deadline>1009,"normal opportunity spacing reset")
  a.startTime,a.endTime=1002,1003.5;a.generation+=1;a.actionId+=1
  assert(sample(v,a,1002.2)==nil and v.personalNextOpportunity==deadline,"next rest bypassed existing cooldown")
 end)
 test("takeover and owner movement cancel actual prop and preserve cooldown",function()
  for _,kind in ipairs({"generation","owner","park"})do
   local a,v=actor(),visual();sample(v,a,1000);sample(v,a,1000.16)
   local prop,deadline=v.personalToy,v.personalNextOpportunity;assert(prop)
   if kind=="generation"then a.generation+=1;a.actionId+=1 elseif kind=="owner"then v.ownerMoving=true else a.parkId="grove"end
   assert(sample(v,a,1000.25)==nil and prop.destroyed and not v.personalToy,kind.." did not retire actual prop")
   assert(v.personalNextOpportunity==deadline,"interruption reset cooldown")
  end
 end)
 test("late short rest waits instead of forcing an incomplete beat",function()
  local a,v=actor(),visual();a.endTime=1000.9
  assert(sample(v,a,1000)==nil and sample(v,a,1000.16)==nil and not v.personalToy)
  a.startTime,a.endTime=1002,1003.5;a.generation+=1;a.actionId+=1
  assert(sample(v,a,1002)==nil and sample(v,a,1002.16)and v.personalToyActive,"next ordinary safe rest never became usable")
 end)
 end)
 for _,v in ipairs(visuals)do v:destroy()end;root:Destroy();assert(ok,problem)
 return{passed=#cases,cases=cases}
end
