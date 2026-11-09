-- Pure intent/transport ordering; no GUI, remotes, instances or saved profiles.
return function(client)
 local Intent=require(client.HueIntent)
 local Shared=game.ReplicatedStorage.Shared;local Hue=require(Shared.HueCatalog);local Eggs=require(Shared.EggCatalog)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function copy(v)if type(v)~="table"then return v end;local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out end
 local function initial()
  return{status="Ready",revision=7,nectar=22,inventoryMask=Eggs.mask({"pip","puddle"}),hues={}}
 end
 local function fixture(state)
  local f={sends={},serial=0,changes=0,available=true}
  f.intent=Intent.new({id=function()f.serial+=1;return"intent-"..f.serial end,available=function()return f.available end,
   send=function(action,value,revision)table.insert(f.sends,{action=action,value=copy(value),revision=revision})end,
   changed=function()f.changes+=1 end})
  f.intent:update(state or initial());return f
 end
 local function receipt(f,extra)
  local p=f.intent.pending;assert(p)
  local r={id=p.value.id,petId=p.value.petId,action=p.action,revision=p.revision+1,body="rose",secondary="default",
   cost=8,balanceBefore=22,balanceAfter=14,hue="rose",oldRank=0,newRank=1,secondaryUnlocked=true}
  if p.action=="hueEquip"then r.cost,r.balanceAfter=0,22;r.hue,r.oldRank,r.newRank,r.secondaryUnlocked=nil,nil,nil,nil end
  for key,value in pairs(extra or {})do r[key]=value end;return r
 end
 local function reply(f,status,r,reason)
  local p=assert(f.intent.pending)
  return{id=p.value.id,petId=p.value.petId,action=p.action,status=status,receipt=r,reason=reason,revision=if r then r.revision else p.revision}
 end
 local function confirmed(r,revision,body,balance)
  local s=initial();s.revision=revision or r.revision;s.nectar=balance or r.balanceAfter
  s.lastHueResult=copy(r);s.hues.pip={ranks={rose=1,tide=2,citrus=0,iris=0},body=body or r.body,secondary=r.secondary}
  return s
 end
 test("duplicate clicks create one revision-prefixed quote and exact retries preserve every field",function()
  local f=fixture();assert(f.intent:buy("pip","rose"));local p=copy(f.intent.pending)
  assert(not f.intent:buy("pip","rose")and not f.intent:buy("puddle","tide")and #f.sends==1)
  assert(p.value.id=="7:intent-1"and p.value.rank==0 and p.revision==7)
  assert(f.intent:receive(reply(f,"Retrying",nil,"Retrying")))
  local newer=initial();newer.revision=9;newer.nectar=30;f.intent:update(newer)
  assert(f.intent:retry()and #f.sends==2 and f.sends[2].revision==p.revision)
  for key,value in pairs(p.value)do assert(f.sends[2].value[key]==value,"retry changed "..key)end
  assert(f.sends[2].action==p.action and not f.intent:retry())
 end)
 test("pending pet reveal, unavailable host and pending save status fence requests",function()
  for _,status in ipairs({"Busy","Retrying","Locked","Temporary","SessionLost"})do
   local s=initial();s.status=status;local f=fixture(s)
   assert(not f.intent:buy("pip","rose")and #f.sends==0 and not f.intent.pending)
  end
  local s=initial();s.lastHatch={id="companion-result",petId="pip"};local f=fixture(s)
  assert(not f.intent:buy("pip","rose")and not f.intent:equip("pip","body","original")and #f.sends==0)
  assert(f.intent.state.lastHatch.id=="companion-result")
  f=fixture();f.available=false;assert(not f.intent:buy("pip","rose")and #f.sends==0)
 end)
 test("wrong operation id, pet or action replies cannot terminate or prove the pending request",function()
  local f=fixture();assert(f.intent:buy("pip","rose"));local pending=f.intent.pending
  for _,change in ipairs({{id="other"},{petId="puddle"},{action="hueEquip"}})do
   for _,status in ipairs({"Saved","Rejected","Retrying"})do
    local packet=reply(f,status,receipt(f),"RevisionChanged");for k,v in pairs(change)do packet[k]=v end
    assert(not f.intent:receive(packet)and f.intent.pending==pending and f.intent.status=="Pending")
   end
  end
  assert(not f.intent:receive(nil)and #f.sends==1)
 end)
 test("Saved before snapshot retains proof without changing confirmed palette or wallet",function()
  local f=fixture();assert(f.intent:buy("pip","rose"));local r=receipt(f)
  assert(f.intent:receive(reply(f,"Saved",r))and f.intent.pending and f.intent.pending.savedReceipt==r)
  assert(f.intent.state.nectar==22 and Hue.appearance(f.intent.state.hues,"pip").body=="original")
  assert(not f.intent:retry()and #f.sends==1)
  f.intent:update(confirmed(r));assert(not f.intent.pending and f.intent.status=="Saved"and f.intent.receipt.id==r.id)
  assert(f.intent.state.nectar==14 and Hue.appearance(f.intent.state.hues,"pip").body=="rose")
 end)
 test("snapshot before event settles once and a late event cannot create another request",function()
  local f=fixture();assert(f.intent:buy("pip","rose"));local r=receipt(f);local event=reply(f,"Saved",r)
  f.intent:update(confirmed(r));assert(not f.intent.pending and f.intent.status=="Saved")
  assert(not f.intent:receive(event)and #f.sends==1 and f.intent.receipt.id==r.id)
 end)
 test("coalesced newer last result accepts older matching Saved without rewinding current colors",function()
  local f=fixture();assert(f.intent:buy("pip","rose"));local own=receipt(f);local event=reply(f,"Saved",own)
  local newer=copy(own);newer.id="9:another-operation";newer.revision=10;newer.body="tide";newer.hue="tide"
  newer.oldRank,newer.newRank,newer.secondaryUnlocked=1,2,false
  f.intent:update(confirmed(newer,10,"tide",30));assert(f.intent.pending and f.intent.status=="Pending")
  assert(f.intent:receive(event)and not f.intent.pending and f.intent.status=="Saved")
  assert(f.intent.receipt.id==own.id and f.intent.state.lastHueResult.id==newer.id)
  assert(f.intent.state.nectar==30 and Hue.appearance(f.intent.state.hues,"pip").body=="tide")
 end)
 test("Saved proof survives late Rejected and Retrying until a newer snapshot crosses its revision",function()
  local f=fixture();assert(f.intent:buy("pip","rose"));local own=receipt(f)
  local rejected=reply(f,"Rejected",nil,"Throttled");local retrying=reply(f,"Retrying",nil,"Busy")
  assert(f.intent:receive(reply(f,"Saved",own)))
  assert(not f.intent:receive(rejected)and not f.intent:receive(retrying)and f.intent.pending.savedReceipt==own)
  local newer=copy(own);newer.id="9:later-operation";newer.revision=10;newer.body="tide"
  newer.action,newer.cost,newer.balanceBefore,newer.balanceAfter="hueEquip",0,30,30
  newer.hue,newer.oldRank,newer.newRank,newer.secondaryUnlocked=nil,nil,nil,nil
  f.intent:update(confirmed(newer,10,"tide",30))
  assert(not f.intent.pending and f.intent.status=="Saved"and f.intent.receipt.id==own.id)
  assert(not f.intent:receive(rejected)and f.intent.status=="Saved"and #f.sends==1)
 end)
 test("rejected rank or wallet quote never optimistically grants a color or permits retry",function()
  for _,reason in ipairs({"RevisionChanged","RankChanged","NeedStars","RevealPending","OperationConflict"})do
   local s=initial();local f=fixture(s);assert(f.intent:buy("pip","rose"))
   assert(f.intent:receive(reply(f,"Rejected",nil,reason))and not f.intent.pending and f.intent.status=="Rejected")
   assert(f.intent.state==s and s.nectar==22 and next(s.hues)==nil and not f.intent:retry()and #f.sends==1)
   local refresh=initial();refresh.revision=8;refresh.nectar=18;f.intent:update(refresh)
   assert(Hue.appearance(f.intent.state.hues,"pip").body=="original"and f.intent.state.nectar==18)
  end
 end)
 test("stale snapshots cannot roll back the confirmed revision, palette or wallet",function()
  local f=fixture();local newer=initial();newer.revision=10;newer.nectar=30
  newer.hues.pip={ranks={rose=1,tide=2,citrus=0,iris=0},body="tide",secondary="rose"};f.intent:update(newer)
  local stale=initial();stale.revision=8;stale.nectar=14;f.intent:update(stale)
  assert(f.intent.state.revision==10 and f.intent.state.nectar==30 and Hue.appearance(f.intent.state.hues,"pip").body=="tide")
 end)
 test("body and secondary requests are independent; Original retains learned ranks and secondary",function()
  local s=initial();s.hues.pip={ranks={rose=1,tide=2,citrus=0,iris=0},body="tide",secondary="default"}
  local f=fixture(s);assert(f.intent:equip("pip","secondary","rose"))
  local first=f.sends[1];assert(first.action=="hueEquip"and first.value.secondary=="rose"and first.value.body==nil)
  assert(s.hues.pip.secondary=="default"and s.hues.pip.body=="tide")
  local r=receipt(f,{body="tide",secondary="rose",cost=0,balanceAfter=22});f.intent:update(confirmed(r,8,"tide",22))
  assert(f.intent:equip("pip","body","original"));local second=f.sends[2]
  assert(second.value.body=="original"and second.value.secondary==nil and second.revision==8)
  local original=receipt(f,{body="original",secondary="rose",cost=0,balanceAfter=22});f.intent:update(confirmed(original,9,"original",22))
  local row=Hue.get(f.intent.state.hues,"pip");assert(row.body=="original"and row.secondary=="rose"and row.ranks.rose==1 and row.ranks.tide==2)
  assert(not f.intent:equip("puddle","secondary","rose")and not f.intent:equip("pip","body","iris")and #f.sends==2)
 end)
 test("insufficient wallet, max rank, unsupported or unowned pet and unknown direction send nothing",function()
  local s=initial();s.nectar=7;local f=fixture(s);assert(not f.intent:buy("pip","rose")and #f.sends==0)
  s=initial();s.hues.pip={ranks={rose=3,tide=0,citrus=0,iris=0},body="rose",secondary="default"};f=fixture(s)
  assert(not f.intent:buy("pip","rose")and #f.sends==0)
  f=fixture();assert(not f.intent:buy("wick","rose")and not f.intent:buy("pip","unknown")and #f.sends==0)
  s=initial();s.inventoryMask=Eggs.bit("pip");f=fixture(s);assert(not f.intent:buy("puddle","rose")and #f.sends==0)
 end)
 return{passed=#cases,cases=cases,persistentWrites=false,evidence="pure client intent ordering with injected transport and confirmed snapshots"}
end
