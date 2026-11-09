-- Real server entry callbacks/workers with isolated services and a suspended store.
return function(server,hostSource,kind)
 assert(kind=="toy"or kind=="feature","choose toy or feature")
 local title=kind:sub(1,1):upper()..kind:sub(2)
 local Catalog=require(game.ReplicatedStorage.Shared[title.."Catalog"])
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
 local adapter={now=function()return 1700000000+c.now end,guid=function()c.serial+=1;return"material-wire-"..c.serial end,
  random=function()c.rolls=(c.rolls or 0)+1;return .1 end,wait=function()end}
 adapter.update=function(key,transform)
  c.writes+=1
  if c.hold then c.hold=false;c.blocked=coroutine.running();coroutine.yield("store-held")end
  local output=transform(copy(db[key]));if output then db[key]=copy(output)end
  if c.failAfter then c.failAfter=false;error("Expected fixture: Material committed then response lost")end
  return copy(output)
 end
 local h=H.load(id,{rank=1,companionId="pip"},adapter);for n=1,12 do assert(H.award(h,n,8))end;local before=h.state.nectar
 local fixture=nativeInstance.new("Folder");fixture.Name="_"..title.."HostFixture";fixture.Parent=server
 local replicated=nativeInstance.new("Folder");replicated.Parent=fixture
 local shared=realGame.ReplicatedStorage.Shared:Clone();shared.Parent=replicated
 local materials=nativeInstance.new("Folder");materials.Name="PetMaterials";materials.Parent=replicated
 local MaterialCatalog=realRequire(realGame.ReplicatedStorage.Shared.MaterialCatalog)
 for _,id in ipairs(MaterialCatalog.PaidOrder)do local name=MaterialCatalog.ById[id].profile;local surface=nativeInstance.new("SurfaceAppearance");surface.Name=name;surface:SetAttribute("MaterialProfile",name);surface:SetAttribute("MaterialVersion",1);surface.Parent=materials end
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
 local fakeGame={JobId="material-host-fixture",GameId=0}
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
 function hatch.public(handle)local public=H.public(handle);public.materialAvailable=MaterialCatalog.available(materials);return public end
 local events={};local instanceShim={new=function(class)
  if class~="RemoteEvent"then return nativeInstance.new(class)end
  local event={OnServerEvent=signal()}
  function event:FireClient(who,packet)
   assert(who==player)
   if self.Name=="NurserySnapshot"then c.snapshot=copy(packet);c.snapshotCount=(c.snapshotCount or 0)+1 end
   if self.Name==title.."Result"then
    if packet.status=="Saved"then
     local state=c.snapshot
     assert(state.nectar==h.state.nectar and packet.receipt.id==packet.id and packet.receipt.revision<=state.revision,
      "saved state must publish before typed result; historical receipt keeps its own revision")
    end
    if not(c.dropSaved and packet.status=="Saved")then table.insert(c.packets,copy(packet))end
   end
  end
  table.insert(events,event);return event
 end}
 local module=nativeInstance.new("ModuleScript");module.Name="_MaterialHostSandbox"
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
 local function send(value,revision,action)requests.HatchRequest.OnServerEvent:Fire(player,action or kind.."Buy",value,revision);return c.packets[#c.packets]end
 local function snapshot()assert(board:GetAttribute("HatchState")==nil,"private state leaked on replicated board");return copy(c.snapshot)end
 local revision=h.state.revision
 local packet={id=tostring(revision)..":"..kind.."-host-buy",catalogVersion=1,poolVersion=1}
 if kind=="toy"then packet.eligible=Catalog.remaining(h.state.toyUnlocks)end
 test(kind.." durable lost-response reservation keeps exact waiter and same-pending throttle retryable",function()
  c.now=2;c.failAfter=true;local response=send(packet,revision)
  assert(response.status=="Retrying"and h.pending and h.state.nectar==before and snapshot()["pending"..title.."Result"]==nil)
  c.now=2.05;assert(send(packet,revision).status=="Retrying")
 end)
 test(kind.." background completion publishes private state before receipt and conflict cannot clear waiter",function()
  assert(#c.tasks==2);c.now=3;c.hold=true;resume(c.tasks[1]);assert(h.busy and c.blocked and h.pending)
  c.now=3.4;assert(send(packet,revision).status=="Retrying")
  c.now=3.8;local conflict={id=packet.id,catalogVersion=1,resultId="other"};local refused=send(conflict,revision,kind.."Ack")
  assert(refused.status=="Rejected"and refused.reason=="OperationConflict"and h.pending and h.state.nectar==before)
  c.now=4;resume(c.blocked);local saved=c.packets[#c.packets]
  assert(saved.status=="Saved"and saved.id==packet.id and h.state.nectar==before-Catalog.Cost and c.rolls==1)
  local public=snapshot();assert(public[kind.."Reservation"]==nil and public[kind.."Receipts"]==nil and public["pending"..title.."Result"].id==packet.id and public["last"..title.."Result"].quote==nil and public["last"..title.."Result"].operationId==nil)
  c.now=4.01;local writes=c.writes;assert(send(packet,revision).status=="Saved"and c.writes==writes)
 end)
 test(kind.." lost apply response reconciles exact confirmed appearance and historical replay preserves next result",function()
  local rev=h.state.revision;local usage={id=tostring(rev)..":"..kind.."-host-use",catalogVersion=1,petId="pip"}
  local action
  if kind=="toy"then action="toyEquip";usage.toyId="ball";usage.expectedToy="none";usage.resultId=packet.id
  else action="featureUse";usage.featureId="horns";usage.expectedStage=0;usage.pendingResultId=packet.id end
  local balance=h.state.nectar;c.now=5;c.dropSaved=true;local count=#c.packets;send(usage,rev,action);assert(#c.packets==count)
  local public=snapshot();assert(public["pending"..title.."Result"]==nil and public.nectar==balance)
  if kind=="toy"then assert(public.petToys.pip=="ball")else assert(public.petFeatures.pip.horns.earned==1 and public.petFeatures.pip.horns.visible==1 and public.featureStock.horns==0)end
  local appearance=realGame.HttpService:JSONDecode(board:GetAttribute("PetAppearance"))
  assert(appearance.pip.body=="original"and appearance.pip.charmVisible and not appearance.pip.featureStock and not appearance.pip.earned)
  if kind=="toy"then assert(appearance.pip.toyId=="ball")else assert(appearance.pip.featureStages.horns==1)end
  c.dropSaved=false;c.now=5.5;assert(send(usage,rev,action).status=="Saved")
  local nextRev=h.state.revision;local nextBuy={id=tostring(nextRev)..":"..kind.."-host-next",catalogVersion=1,poolVersion=1}
  if kind=="toy"then nextBuy.eligible=Catalog.remaining(h.state.toyUnlocks)end
  c.now=6;send(nextBuy,nextRev);local resultId=h.state["pending"..title.."Result"].id;local nextBalance=h.state.nectar
  c.now=6.5;assert(send(usage,rev,action).status=="Saved"and h.state["pending"..title.."Result"].id==resultId and h.state.nectar==nextBalance)
 end)
 test(kind.." exact acknowledgement stores result without spending or changing appearance",function()
  local rev=h.state.revision;local pending=h.state["pending"..title.."Result"]
  local q={id=tostring(rev)..":"..kind.."-host-ack",catalogVersion=1,resultId=pending.id};local balance=h.state.nectar
  c.now=7;assert(send(q,rev,kind.."Ack").status=="Saved"and not h.state["pending"..title.."Result"]and h.state.nectar==balance)
 end)
 test(kind.." owner snapshots contain no private grant proofs and foreign player cannot operate profile",function()
  local count=c.snapshotCount;c.now=8;requests.HatchRequest.OnServerEvent:Fire({UserId=id+1},"snapshot",id)
  assert(c.snapshotCount==count and board:GetAttribute("HatchState")==nil)
  requests.HatchRequest.OnServerEvent:Fire(player,"snapshot",id+1);assert(c.snapshotCount==count+1 and c.snapshot.nectar==h.state.nectar)
 end)
 players.PlayerRemoving:Fire(player);fixture:Destroy()
 return{passed=#cases,cases=cases,persistentWrites=false,evidence="actual typed host callbacks and retry coroutine; isolated store"}
end
