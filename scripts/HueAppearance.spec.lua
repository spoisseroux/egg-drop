-- Production renderer/portrait/replica palette parity; no commands, profile or camera mutation.
return function(client,parent)
 local readyFixture=assert(script.Parent:FindFirstChild("PetAssetsReadyFixture"),"Install the real authored-readiness QA helper beside this spec")
 require(readyFixture)(client)
 local Shared=game.ReplicatedStorage.Shared;local Pets=require(Shared.PetCatalog);local Palette=require(Shared.PetPalette)
 local Visual=require(client.GardenPetVisual);local Factory=require(client.PetFactory);local Portrait=require(client.PetPortrait)
 local Cinematic=require(client.HatchCinematic);local Garden=require(client.GardenClient);local Companions=require(client.RoomCompanions)
 local Http=game:GetService("HttpService");local Players=game:GetService("Players");local Run=game:GetService("RunService")
 local folder=Instance.new("Folder");folder.Name="_HueAppearance";folder.Parent=workspace
 local gui=Instance.new("Frame");gui.Size=UDim2.fromOffset(600,360);gui.Parent=parent
 local cases={};local cleanup={};local function test(n,f)parent:SetAttribute("HueAppearanceProgress",n);f();table.insert(cases,n)end
 local function token(body,rank,secondary,dot)return{body=body,bodyRank=rank,secondary=secondary,charmVisible=dot~=false}end
 local function expect(v,id,t)
  local colors=Palette.resolve(id,t)
  for _,e in ipairs(v.pieces)do if e.colorRole=="body"or e.colorRole=="secondary"then
   -- Broad world surfaces intentionally use a dimmed night emission color;
   -- compare their resolved source channel here, with material behavior covered
   -- by PetLoopResetPresentation. All other parts compare rendered RGB directly.
   local a,b=if e.nightSurface then e.color else e.part.Color,colors[e.colorRole]
   local delta=math.max(math.abs(a.R-b.R),math.abs(a.G-b.G),math.abs(a.B-b.B))
   assert(delta<=1/255+.000001,string.format("%s palette mismatch %s RGB8 delta=%.8f",id,e.name,delta))end end
  assert(v.secondaryColor==colors.secondary and v.charmVisible==t.charmVisible)
 end
 local ok,problem=pcall(function()
  for _,id in ipairs({"pip","puddle"})do
   test(id.." native and factory body accents Dot share resolver and preserve protected face geometry",function()
    for _,native in ipairs({true,false})do
     local v=if native then Visual.new(folder,Vector3.new(2000,4.025,0),Pets.byId[id],.72,nil,{native=true})else Factory.new(folder,Vector3.new(2000,4.025,0),Pets.byId[id],.72)
     v.reducedEffects=true;v.idleMotionFrozen=true;v:update(0);local protected,geometry={},{}
     for _,e in ipairs(v.pieces)do
      if e.colorRole~="body"and e.colorRole~="secondary"then protected[e]=e.part.Color end
      geometry[e]={e.part.CFrame,e.part.Size}
     end
     local count=#v.model:GetDescendants()
     for _,t in ipairs({token("rose",1,"default",true),token("tide",3,"rose",false),token("original",0,"rose",true)})do
      v:applyAppearance(t);expect(v,id,t)
      for e,color in pairs(protected)do assert(e.part.Color==color,"Hue altered protected face/ivory "..e.name)end
      for e,g in pairs(geometry)do assert(e.part.CFrame==g[1]and e.part.Size==g[2],"Hue changed approved geometry")end
      assert(#v.model:GetDescendants()==count)
     end
     v:destroy()
    end
   end)
  end
  test("journal portrait recolors existing pixels using the same body and secondary roles",function()
   local sprite=Portrait.create(gui,Pets.byId.pip,3,UDim2.fromOffset(30,30),25,false)
   local first=sprite:GetChildren()[1];local count=#sprite:GetDescendants()
   local t=token("iris",3,"citrus",false);Portrait.apply(sprite,t)
   assert(sprite:GetAttribute("BodyColor")==Palette.resolve("pip",t).body and sprite:GetAttribute("SecondaryColor")==Palette.resolve("pip",t).secondary)
   Portrait.apply(sprite,token("original",0,"rose",true));assert(sprite:GetChildren()[1]==first and #sprite:GetDescendants()==count)
   sprite:Destroy()
  end)
  test("same hatch ID appearance updates keep epoch hero viewport and static completion",function()
   local c=Cinematic.new(gui,{play=function()end},function()return true end,function()return true end);table.insert(cleanup,c)
   local completed=0;c:play({id="hue-static-hatch",petId="pip"},function()completed+=1 end,{skipIntro=true,appearance=token("rose",1,"default",true)})
   for _=1,3 do Run.Heartbeat:Wait()end
   assert(c.heroVisual,"production hatch rig unavailable");expect(c.heroVisual,"pip",token("rose",1,"default",true))
   local hero,epoch=c.heroViewport,c.epoch;c:setAppearance(token("tide",3,"rose",true))
   expect(c.heroVisual,"pip",token("tide",3,"rose",true));assert(c.heroViewport==hero and c.epoch==epoch and completed==1)
   c:destroy()
  end)
  test("pixel hatch fallback updates palette without rebuilding the receipt scene",function()
   local c=Cinematic.new(gui,{play=function()end},function()return true end,function()return true end);table.insert(cleanup,c);c.forceFallback=true
   c:play({id="hue-fallback",petId="puddle"},function()end,{skipIntro=true,appearance=token("original",0,"default",true)})
   local p,epoch=c.portrait,c.epoch;assert(p and c.renderMode=="PixelFallback")
   local t=token("tide",2,"iris",false);c:setAppearance(t)
   assert(c.portrait==p and c.epoch==epoch and p:GetAttribute("BodyColor")==Palette.resolve("puddle",t).body)
   c:destroy()
  end)
  test("confirmed peer token refresh updates the existing observer rig instead of only Dot",function()
   local own=Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart");assert(own,"live local avatar required")
   local boards=Instance.new("Folder");boards.Parent=folder
   local board=Instance.new("Folder");board.Name="90101";board:SetAttribute("CompanionId","pip");board:SetAttribute("Mode","Room");board.Parent=boards
   local function publish(t)board:SetAttribute("PetAppearance",Http:JSONEncode({pip=t}))end
   local f=Instance.new("Folder");f.Name="GardenState";f.Parent=folder
   local g=Garden.new(boards,{folder=f,playerId=Players.LocalPlayer.UserId,remote={FireServer=function()error("no focus intent in appearance fixture")end}})
   local character=Instance.new("Model");character.Parent=folder
   local root=Instance.new("Part");root.Name="HumanoidRootPart";root.Anchored=true;root.CanCollide=false;root.Position=own.Position+Vector3.new(6,0,0);root.Parent=character
   local humanoid=Instance.new("Humanoid");humanoid.Parent=character
   local player={UserId=90101,Character=character}
   local observer=Companions.new(boards,Factory.create,function()return true end,{garden=g,players=function()return{player}end})
   publish(token("rose",1,"default",true));observer:update(.13,workspace:GetServerTimeNow());local entry=observer.active[player];assert(entry)
   local visual=entry.visual;expect(visual,"pip",token("rose",1,"default",true))
   publish(token("tide",3,"rose",false));observer:update(.13,workspace:GetServerTimeNow())
   assert(observer.active[player].visual==visual);expect(visual,"pip",token("tide",3,"rose",false))
   observer:clear();g:destroy()
  end)
  test("bodyMix-only confirmation recolors the same visitor model and preserves shared activity state",function()
   local own=Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart");assert(own,"live local avatar required")
   local boards=Instance.new("Folder");boards.Parent=folder
   local board=Instance.new("Folder");board.Name="90102";board:SetAttribute("CompanionId","pip");board:SetAttribute("Mode","Room")
   board:SetAttribute("CompanionGeneration",2);board:SetAttribute("GardenCharacterId",1);board.Parent=boards
   local f=Instance.new("Folder");f.Name="GardenState";f.Parent=folder
   local g=Garden.new(boards,{folder=f,playerId=Players.LocalPlayer.UserId,remote={FireServer=function()error("appearance fixture cannot focus")end}})
   local character=Instance.new("Model");character:SetAttribute("GardenCharacterId",1);character.Parent=folder
   local root=Instance.new("Part");root.Name="HumanoidRootPart";root.Anchored=true;root.CanCollide=false;root.Position=own.Position+Vector3.new(6,0,0);root.Parent=character
   local humanoid=Instance.new("Humanoid");humanoid.Parent=character
   local player={UserId=90102,Character=character};local now=workspace:GetServerTimeNow()
   local at={root.Position.X,4.025,root.Position.Z}
   f:SetAttribute("Snapshot",Http:JSONEncode({version=1,revision=1,toy={},actors={["90102"]={ownerId=90102,petId="pip",characterId=1,petGeneration=2,generation=7,
    mode="Room",behavior="rest",action="wanderPause",actionId=12,from=at,to=at,startTime=now,endTime=now+20,yaw=.7}}}))
   Run.Heartbeat:Wait()
   local function publish(t)board:SetAttribute("PetAppearance",Http:JSONEncode({pip=t}))end
   local observer=Companions.new(boards,Factory.create,function()return true end,{garden=g,players=function()return{player}end})
   local initial=token("rose",3,"iris",false);publish(initial);observer:update(.13,now)
   local entry=assert(observer.active[player]);local visual,model,state,actor=entry.visual,entry.visual.model,entry.followState,entry.actor
   assert(actor and state and actor.generation==7,"fixture must exercise authoritative activity")
   expect(visual,"pip",initial)
   local nodeCount=#model:GetDescendants();local position,yaw=visual.origin,visual.yaw;local before=visual.colors.body
   local head=assert(model:FindFirstChild("Head",true));local renderedBefore=head.Color
   for _,pair in ipairs({"rose:tide","citrus:iris"})do
    local mixed=token("rose",3,"iris",false);mixed.bodyMix=pair;publish(mixed);observer:update(.13,now)
    assert(g:appearance(board,"pip").bodyMix==pair,"replica lost canonical mix")
    assert(observer.active[player]==entry and entry.visual==visual and visual.model==model and #model:GetDescendants()==nodeCount,"mix rebuilt visitor rig")
    assert(entry.actor==actor and entry.followState==state and visual.origin==position and visual.yaw==yaw,"mix reset shared activity")
    expect(visual,"pip",mixed);assert(visual.colors.body~=before,"mix-only change did not repaint body")
    assert(visual.secondaryColor==Palette.resolve("pip",initial).secondary and visual.charmVisible==false)
    assert(head.Color~=renderedBefore,"mix-only change did not repaint rendered head")
    before=visual.colors.body;renderedBefore=head.Color
   end
   publish(initial);observer:update(.13,now);expect(visual,"pip",initial)
   assert(entry.visual==visual and entry.followState==state and entry.actor==actor,"clearing mix reset visitor state")
   observer:clear();g:destroy()
  end)
 end)
 for _,v in ipairs(cleanup)do v:destroy()end;folder:Destroy();gui:Destroy();assert(ok,problem)
 return{passed=#cases,cases=cases,liveCommands=0,authorityMutation=false}
end
