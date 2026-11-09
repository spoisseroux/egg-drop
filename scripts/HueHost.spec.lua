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
  random=function()error("Hue host never rolls")end,wait=function()end}
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
   if self.Name=="HueResult"then
    if packet.status=="Saved"then
     local board=replicated.EggDropBoards[tostring(id)];local state=realGame.HttpService:JSONDecode(board:GetAttribute("HatchState"))
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
 local function send(value,revision)requests.HatchRequest.OnServerEvent:Fire(player,"hue",value,revision);return c.packets[#c.packets]end
 local function snapshot()return realGame.HttpService:JSONDecode(board:GetAttribute("HatchState"))end
 local revision=h.state.revision;local packet={id=tostring(revision)..":host-rose",petId="pip",hue="rose",rank=0}
 test("actual ambiguous write exposes old confirmed palette and throttled same quote stays Retrying",function()
  c.now=1;c.failAfter=true;local response=send(packet,revision)
  assert(response.status=="Retrying"and h.pending and h.state.nectar==before)
  assert(snapshot().hues.pip==nil and snapshot().lastHueResult==nil)
  local appearance=realGame.HttpService:JSONDecode(board:GetAttribute("PetAppearance"));assert(appearance.pip.body=="original")
  c.now=1.05;assert(send(packet,revision).status=="Retrying","same pending throttle must not be terminal")
 end)
 test("background retry held in storage preserves original waiter through manual Busy and conflicting quote",function()
  assert(#c.tasks==2,"only existing retry/renew workers")
  c.now=2;c.hold=true;resume(c.tasks[1]);assert(h.busy and c.blocked and h.pending)
  local pending=h.pending;c.now=2.4;assert(send(packet,revision).status=="Retrying")
  local conflict=copy(packet);conflict.hue="tide";c.now=2.8
  local rejected=send(conflict,revision);assert(rejected.status=="Rejected"and rejected.reason=="OperationConflict")
  assert(h.pending==pending and h.state.nectar==before)
  c.now=3;resume(c.blocked)
  local saved=c.packets[#c.packets];assert(saved.status=="Saved"and saved.id==packet.id,"conflicting retry cleared original Hue waiter")
  assert(h.status=="Ready"and not h.pending and h.state.nectar==before-8)
  c.now=3.01;local queued=send(packet,revision)
  assert(queued.status=="Saved"and queued.reason=="AlreadySaved"and h.state.nectar==before-8,"queued known receipt became a throttled false failure")
  local receipts=0;for _ in pairs(db["player_"..id].hatching.hueReceipts)do receipts+=1 end
  assert(receipts==1 and snapshot().hues.pip.ranks.rose==1 and snapshot().hues.pip.ranks.tide==0)
 end)
 test("lost saved event remains recoverable from saved-only snapshot and exact request replay cannot spend twice",function()
  assert(H.award(h,2,8));local balance=h.state.nectar
  local rev=h.state.revision;local second={id=tostring(rev)..":host-tide",petId="pip",hue="tide",rank=0}
  c.now=4;c.dropSaved=true;local count=#c.packets;send(second,rev);assert(#c.packets==count)
  local current=snapshot();assert(current.lastHueResult.id==second.id and current.nectar==balance-8 and current.hues.pip.ranks.tide==1)
  assert(current.hueReceipts==nil and current.lastHueResult.quote==nil)
  c.dropSaved=false;c.now=4.5;local replay=send(second,rev)
  assert(replay.status=="Saved"and replay.receipt.balanceAfter==balance-8 and h.state.nectar==balance-8)
  assert(H.award(h,3,8));local currentBalance=h.state.nectar;c.now=5
  local historical=send(packet,revision);local latest=snapshot()
  assert(historical.status=="Saved"and historical.receipt.balanceAfter==before-8 and h.state.nectar==currentBalance)
  assert(latest.lastHueResult.id==second.id and latest.hues.pip.body=="tide"and latest.nectar==currentBalance,
   "old paid replay rewound the latest saved wallet or selection")
 end)
 players.PlayerRemoving:Fire(player);fixture:Destroy()
 return{passed=#cases,cases=cases,persistentWrites=false,evidence="actual host callbacks and retry coroutine; isolated DB with forced timeout/store suspension"}
end
