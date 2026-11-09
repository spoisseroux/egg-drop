-- Captured transport and prompt facts; no real server dispatch or profile mutation.
return function(client)
 local Intent=require(client.GardenToyIntent);local Prompt=require(client.GardenToyPrompt);local Pose=require(client.PetToyPose)
 local sent={};local intent=Intent.new(function(p)table.insert(sent,p)end);local cases={}
 local actor={petId="pip",characterId=3,petGeneration=4,generation=8}
 assert(intent:request("toyStart",actor));local first=sent[1];actor.generation=9
 for _=1,121 do intent:step(1/60)end
 assert(#sent==2 and sent[2]==first and first.actorGeneration==8 and intent.pending.retryReady)
 assert(intent:retry()and sent[3]==first);assert(not intent:result({kind="toyJoin",seq=first.seq,status="Joined"}))
 assert(intent:result({kind="toyStart",seq=first.seq,status="Started",actionId=99}));assert(not intent.pending)
 table.insert(cases,"one captured generation retries exactly once automatically and explicit retry never replans")
 assert(intent:request("toyJoin",actor,99));local join=sent[#sent];assert(join.actorGeneration==9 and join.actionId==99 and join.seq>first.seq)
 assert(not intent:result({kind="toyStart",seq=first.seq,status="Started"}));intent:abandon();local count=#sent;intent:step(10);assert(#sent==count)
 table.insert(cases,"new request captures fresh actor and retiring context cancels old retry work")
 local snapshot={toy={}}
 assert(Prompt.describe(snapshot,101,10)=="toyStart")
 snapshot.toy={returnAction={id=99,state="waiting",starterId=101,joinUntil=11,participants={["101"]={}}}}
 assert(Prompt.describe(snapshot,101,10)==nil);local kind,label,id=Prompt.describe(snapshot,102,10);assert(kind=="toyJoin"and id==99)
 assert(Prompt.describe(snapshot,102,11)==nil);snapshot.toy.returnAction.state="paired";assert(Prompt.describe(snapshot,102,10)==nil)
 table.insert(cases,"only another eligible owner sees join before the exact deadline; participants never dispatch twice")
 local autonomous={toy={kind="solo",ownerId=102,reservation=44,actionId=44}}
 for _,owner in ipairs({101,102})do local action,title,id=Prompt.describe(autonomous,owner,10);assert(action=="toyStart"and title=="Start a return"and id==nil,"autonomous play hid deliberate Start")end
 snapshot.toy.returnAction.state="paired";assert(Prompt.describe(snapshot,101,10)==nil and Prompt.describe(snapshot,102,10)==nil,"manual return displaced by Start prompt")
 table.insert(cases,"autonomous solo reservation leaves Start available to owner/visitor while manual participants stay passive")
 local preparation={toy={returnAction={id=100,state="waiting",starterId=101,joinUntil=13,startTime=15,endTime=20,participants={["101"]={}}}}}
 local coming="Pets coming"..utf8.char(0x2026);local returning="Returning"..utf8.char(0x2026)
 local action,title=Prompt.describe(preparation,101,10);assert(action==nil and title==coming)
 action,title=Prompt.describe(preparation,102,12.99);assert(action=="toyJoin"and title=="Join return")
 action,title=Prompt.describe(preparation,102,13);assert(action==nil and title==coming)
 action,title=Prompt.describe(preparation,101,15);assert(action==nil and title==returning)
 preparation.toy.returnAction.state="paired";preparation.toy.returnAction.participants["102"]={}
 action,title=Prompt.describe(preparation,102,14.9);assert(action==nil and title==coming)
 table.insert(cases,"authoritative3second join window and ready time distinguish pet approach from the actual exchange")
 for _,beat in ipairs({{"starter",.5},{"starter",4.5},{"receiver",2.25},{"receiver",2.8}})do
  local reach,expression=Pose.sample(beat[1],beat[2],false);assert(reach>.8 and expression)
  assert(Pose.sample(beat[1],beat[2],true)==0)
 end
 assert(Pose.sample("starter",-1,false)==0 and Pose.sample("receiver",5.1,false)==0)
 table.insert(cases,"shared exchange timestamps drive four finite push/catch beats with reduced reach suppressed")
 local root=Instance.new("Folder");root.Name="_ToyPrompt";root.Parent=workspace
 local part=Instance.new("Part");part.Anchored=true;part.CanCollide=false;part.Parent=root
 local result=Instance.new("BindableEvent");local live=true;local now=10;local position=require(game.ReplicatedStorage.Shared.GardenLayout).Toy
 local actor={mode="Room",petId="pip",characterId=1,petGeneration=0,generation=4};local messages={}
 local garden={playerId=101,snapshot={toy={}},now=function()return now end}
 local prompt=Prompt.new(garden,part,{context=function()return actor,position,live end,remote={FireServer=function(_,p)table.insert(messages,p)end},result={OnClientEvent=result.Event}})
 local ok,err=pcall(function()
  prompt:step(.1);assert(prompt.prompt.Enabled and prompt.prompt.KeyboardKeyCode==Enum.KeyCode.E and prompt.prompt.GamepadKeyCode==Enum.KeyCode.ButtonX)
  assert(prompt:activate()and not prompt:activate()and #messages==1);local p=messages[1]
  live=false;prompt:step(1);assert(not prompt:inReach()and not prompt.prompt.Enabled and not prompt.intent.pending)
  assert(not prompt:activate());table.insert(cases,"one local native prompt owns keyboard gamepad touch and overlay retirement blocks writes")
  live=true;assert(prompt:activate());local captured=messages[#messages];actor=table.clone(actor);actor.characterId=2
  prompt:step(1);assert(not prompt.intent.pending and #messages==2,"respawn retained old retries")
  garden.snapshot.toy={returnAction={id=99,state="waiting",starterId=102,joinUntil=11,participants={["102"]={}}}}
  assert(prompt:activate());local joinPacket=messages[#messages];assert(joinPacket.kind=="toyJoin"and joinPacket.actionId==99 and joinPacket.characterId==2)
  now=11;result:Fire({kind="toyJoin",seq=joinPacket.seq,status="Joined",actionId=99});game:GetService("RunService").Heartbeat:Wait();prompt:step(.1)
  assert(not prompt.prompt.Enabled and prompt.status.Enabled);table.insert(cases,"fresh actor joins exact action and expired/nonjoinable return presents passive status")
  local old=prompt.prompt;prompt:destroy();prompt:step(5);assert(old.Parent==nil and prompt.status.Parent==nil)
  result:Fire({kind=p.kind,seq=p.seq,status="Started"});assert(not prompt:inReach());table.insert(cases,"destroy disconnects result and removes native prompt/status with no retry job")
 end)
 prompt:destroy();result:Destroy();root:Destroy();assert(ok,err)
 local staging=Instance.new("Folder");staging.Parent=workspace;local ball=Instance.new("Part");ball.Parent=staging
 local remotes=Instance.new("Folder");remotes.Parent=staging
 local late=Prompt.new(garden,ball,{remotes=remotes,remote={FireServer=function()end},context=function()return nil,nil,false end})
 local earlyDestroyed=Prompt.new(garden,ball,{remotes=remotes,remote={FireServer=function()end},context=function()return nil,nil,false end});earlyDestroyed:destroy()
 local event=Instance.new("RemoteEvent");event.Name="GardenToyResult";event.Parent=remotes
 game:GetService("RunService").Heartbeat:Wait()
 assert(late.resultConnection and late.resultConnection.Connected and not earlyDestroyed.resultConnection,"late result binder missed event or survived owner destruction")
 local connection=late.resultConnection;local duplicate=Instance.new("RemoteEvent");duplicate.Name="GardenToyResult";duplicate.Parent=remotes;game:GetService("RunService").Heartbeat:Wait()
 assert(late.resultConnection==connection,"late binder accumulated result listeners")
 late:destroy();assert(not connection.Connected);staging:Destroy()
 table.insert(cases,"late replicated result child attaches once and owner destruction retires waiting and live listeners")
 return cases
end
