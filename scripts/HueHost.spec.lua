-- Real server entry callbacks/workers with isolated services and a suspended store.
return function(server,hostSource)
 assert(type(hostSource)=="string","pass current init.server source as argument two")
 local H=require(server.HatchProgress);local P=require(server.PlayerProgress)
 local realGame,realRequire,nativeInstance=game,require,Instance
 local c={now=0,serial=0,packets={},tasks={},writes=0};local db={};local id=82001
 local function copy(v)if type(v)~="table"then return v end;local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out end
 local function signal()
  local callbacks={};return{Connect=function(_,f)table.insert(callbacks,f);return{Disconnect=function()end}end,
   Fire=function(_,...)for _,f in ipairs(callbacks)do f(...)end end}
 end
 local function resume(thread,...)
  local ok,problem=coroutine.resume(thread,...);assert(ok,problem)
 end
 local adapter={now=function()return 1700000000+c.now end,guid=function()c.serial+=1;return"hue-wire-"..c.serial end,
  random=function()c.rolls=(c.rolls or 0)+1;return .1 end,wait=function()end}
 adapter.update=function(key,transform)
  c.writes+=1
  if c.hold then c.hold=false;c.blocked=coroutine.running();coroutine.yield("store-held")end
  local output=transform(copy(db[key]));if output then db[key]=copy(output)end
  if c.failAfter then c.failAfter=false;error("Expected fixture: Hue committed then response lost")end
  return copy(output)
 end
 local h=H.load(id,{rank=1,companionId="pip"},adapter);assert(H.award(h,1,8));local before=h.state.nectar
 local fixture=nativeInstance.new("Folder");fixture.Name="_HueHostFixture";fixture.Parent=server
 local replicated=nativeInstance.new("Folder");replicated.Parent=fixture
 local shared=realGame.ReplicatedStorage.Shared:Clone();shared.Parent=replicated
 local remotes=nativeInstance.new("Folder");remotes.Name="Remotes";remotes.Parent=replicated
 local players={PlayerAdded=signal(),PlayerRemoving=signal()};local heart=signal()
 local player={UserId=id,Parent=players,Character=nil,CharacterAdded=signal()}
 function players:GetPlayers()return{player}end
 local world={};function world:GetServerTimeNow()return 1700000000+c.now end;function world:FindFirstChild()return nil end
 local taskShim={wait=function()return coroutine.yield()end}
 function taskShim.spawn(f,...)
  local thread=coroutine.create(f);resume(thread,...)
  if coroutine.status(thread)=="suspended"then table.insert(c.tasks,thread)end;return thread
 end
 taskShim.defer=taskShim.spawn
 local fakeGame={JobId="hue-host-fixture",GameId=0}
 function fakeGame:GetService(name)
  if name=="Players"then return players elseif name=="ReplicatedStorage"then return replicated
  elseif name=="RunService"then return{Heartbeat=heart,IsStudio=function()return true end}end
  return realGame:GetService(name)
 end
 function fakeGame:BindToClose()end
 local profile={hydrate=P.hydrate};function profile.load()return P.fromRecord(id,db["player_"..id],true)end
 function profile.flushOnce()return true end
 for _,name in ipairs({"equip","equipCompanion","setSetting","recordScore","recordTrials","chargeHatch"})do profile[name]=function()error("Unexpected profile mutation "..name)end end
 local hatch={};for k,v in pairs(H)do hatch[k]=v end;function hatch.load()return h end
 local events={};local instanceShim={new=function(class)
  if class~="RemoteEvent"then return nativeInstance.new(class)end
  local event={OnServerEvent=signal()}
  function event:FireClient(who,packet)
   assert(who==player)
   if self.Name=="NurserySnapshot"then c.snapshot=copy(packet);c.snapshotCount=(c.snapshotCount or 0)+1 end
   if self.Name=="HueResult"then
    if packet.status=="Saved"then
     local state=c.snapshot
     assert(state.nectar==h.state.nectar and packet.receipt.id==packet.id and packet.receipt.revision<=state.revision,
      "saved wallet/color must publish before HueResult; historical receipt keeps its own revision")
    end
    if not(c.dropSaved and packet.status=="Saved")then table.insert(c.packets,copy(packet))end
   end
  end
  table.insert(events,event);return event
 end}
 local module=nativeInstance.new("ModuleScript");module.Name="_HueHostSandbox"
 module.Source="return function(e)local game,script,task,require,Instance,workspace,os,Random=e.game,e.script,e.task,e.require,e.Instance,e.workspace,e.os,e.Random\n"..hostSource.."\nend"
 module.Parent=server;local ok,run=pcall(realRequire,module);module:Destroy();assert(ok,run)
 run({game=fakeGame,script=server,task=taskShim,Instance=instanceShim,workspace=world,os={clock=function()return c.now end},
  Random={new=function()return{NextInteger=function()return 1234 end,NextNumber=function()return .1 end}end},require=function(target)
   if target==server.PlayerProgress then return profile elseif target==server.HatchProgress then return hatch
   elseif target==server.Lounge then return{create=function()end,spawn=function()end,setMode=function()end,setAppearance=function()end}
   elseif target==server.FirstSession then return{new=function()return nil end}end
   return realRequire(target)
  end})
 local requests={};for _,event in ipairs(events)do requests[event.Name]=event end
 local board=replicated.EggDropBoards[tostring(id)];local cases={}
 local function test(name,f)f();table.insert(cases,name)end
 local function send(value,revision,action)requests.HatchRequest.OnServerEvent:Fire(player,action or"hueBuy",value,revision);return c.packets[#c.packets]end
 local function snapshot()assert(board:GetAttribute("HatchState")==nil,"private state leaked on replicated board");return copy(c.snapshot)end
 local Hue=realRequire(realGame.ReplicatedStorage.Shared.HueCatalog)
 local revision=h.state.revision;local packet={id=tostring(revision)..":host-egg",catalogVersion=Hue.CatalogVersion}
 test("actual random buy reservation lost response preserves confirmed stock and same-quote throttle stays Retrying",function()
  c.now=1;c.failAfter=true;local response=send(packet,revision)
  assert(response.status=="Retrying"and h.pending and h.state.nectar==before and response.petId==nil)
  assert(snapshot().pendingHueResult==nil and snapshot().hueInventory.rose==0)
  local appearance=realGame.HttpService:JSONDecode(board:GetAttribute("PetAppearance"));assert(appearance.pip.body=="original")
  c.now=1.05;assert(send(packet,revision).status=="Retrying","same pending throttle must not be terminal")
 end)
 test("background retry held in storage preserves waiter and changed same-ID quote cannot replace candidate",function()
  assert(#c.tasks==2,"only existing retry/renew workers")
  c.now=2;c.hold=true;resume(c.tasks[1]);assert(h.busy and c.blocked and h.pending)
  local pending=h.pending;c.now=2.4;assert(send(packet,revision).status=="Retrying")
  local conflict={id=packet.id,catalogVersion=Hue.CatalogVersion,resultId="wrong"};c.now=2.8
  local rejected=send(conflict,revision,"hueStore");assert(rejected.status=="Rejected"and rejected.reason=="OperationConflict")
  assert(h.pending==pending and h.state.nectar==before)
  c.now=3;resume(c.blocked)
  local saved=c.packets[#c.packets];assert(saved.status=="Saved"and saved.id==packet.id,"conflicting request cleared original waiter")
  assert(h.status=="Ready"and not h.pending and h.state.nectar==before-8 and h.state.hueInventory.rose==1 and c.rolls==1)
  c.now=3.01;assert(send(packet,revision).status=="Saved"and h.state.nectar==before-8)
  local public=snapshot();assert(public.pendingHueResult.id==packet.id and public.pendingHueResult.itemId=="rose"and public.hueReservation==nil)
 end)
 test("lost use event recovers committed vectors, replay never consumes later stock and altered pending ID conflicts",function()
  local balance=h.state.nectar;local rev=h.state.revision
  local usage={id=tostring(rev)..":host-use",catalogVersion=Hue.CatalogVersion,petId="pip",itemId="rose",channel="main",counts=Hue.emptyCounts(),pendingResultId=h.state.pendingHueResult.id}
  c.now=4;c.dropSaved=true;local count=#c.packets;send(usage,rev,"hueUse");assert(#c.packets==count)
  local current=snapshot();assert(current.lastHueResult.id==usage.id and current.nectar==balance and current.petHues.pip.main.rose==1 and current.hueInventory.rose==0 and not current.pendingHueResult)
  assert(current.hueItemReceipts==nil and current.hueReceipts==nil and current.lastHueResult.quote==nil)
  c.dropSaved=false;c.now=4.5;local replay=send(usage,rev,"hueUse");assert(replay.status=="Saved"and replay.receipt.cost==0)
  assert(H.award(h,2,8));c.now=5;local nextRevision=h.state.revision
  local nextBuy={id=tostring(nextRevision)..":host-next",catalogVersion=Hue.CatalogVersion};send(nextBuy,nextRevision)
  local newResult=h.state.pendingHueResult.id;local newBalance=h.state.nectar
  c.now=5.5;assert(send(usage,rev,"hueUse").status=="Saved"and h.state.hueInventory.rose==1 and h.state.pendingHueResult.id==newResult and h.state.nectar==newBalance)
  c.now=6;local altered=copy(usage);altered.pendingResultId=newResult;local changed=send(altered,rev,"hueUse");assert(changed.status=="Rejected"and changed.reason=="OperationConflict"and h.state.hueInventory.rose==1)
 end)
 test("private snapshot is owner-targeted and snapshot requests cannot select another profile",function()
  local count=c.snapshotCount;c.now=7
  requests.HatchRequest.OnServerEvent:Fire({UserId=id+1},"snapshot",id)
  assert(c.snapshotCount==count and board:GetAttribute("HatchState")==nil)
  requests.HatchRequest.OnServerEvent:Fire(player,"snapshot",id+1)
  assert(c.snapshotCount==count+1 and c.snapshot.nectar==h.state.nectar)
 end)
 players.PlayerRemoving:Fire(player);fixture:Destroy()
 return{passed=#cases,cases=cases,persistentWrites=false,evidence="actual host callbacks and retry coroutine; isolated durable reservation/store suspension"}
end
