-- EVIDENCE ONLY. Invoke as a ModuleScript from a real client LocalScript VM.
-- No remotes, ownership, purchases, care contacts or character movement.
return function(client,options)
 options=options or {}
 local Players=game:GetService("Players");local Run=game:GetService("RunService");local Http=game:GetService("HttpService")
 local player=Players.LocalPlayer;assert(player,"real client VM required")
 local guiParent=player:WaitForChild("PlayerGui")
 local Clock=require(client.HollowClock);local controller=assert(Clock.controller,"live HollowClock controller required")
 local Visual=require(client.GardenPetVisual);local Pets=require(game.ReplicatedStorage.Shared.PetCatalog)
 local camera=assert(workspace.CurrentCamera,"live camera required")
 local savedCamera={type=camera.CameraType,cf=camera.CFrame,focus=camera.Focus,fov=camera.FieldOfView,subject=camera.CameraSubject}
 local savedNow,savedElapsed=controller.now,controller.elapsed
 local folder=Instance.new("Folder");folder.Name="_PetNightStudyFixture";folder.Parent=workspace
 local gui=Instance.new("ScreenGui");gui.Name="PetNightStudyEvidence";gui.ResetOnSpawn=false;gui.DisplayOrder=100;gui.Parent=guiParent
 local label=Instance.new("TextLabel");label.Name="EvidenceLabel";label.Position=UDim2.fromOffset(12,8);label.Size=UDim2.new(1,-24,0,44)
 label.BackgroundColor3=Color3.fromHex("17242A");label.BackgroundTransparency=.15;label.BorderSizePixel=0
 label.TextColor3=Color3.fromHex("FFF6E9");label.TextSize=13;label.Font=Enum.Font.GothamMedium;label.TextWrapped=true;label.Parent=gui
 local owner={folder=folder,gui=gui,visuals={},connections={},savedGui={},destroyed=false}
 local origin=options.origin or Vector3.new(-40,4.025,12)
 local bindName="PetNightStudy_"..Http:GenerateGUID(false)
 local state={hour=12,treatment="groupedRoleFill",view="front",body="original"}
 local function hide(item)
  if item:IsA("ScreenGui")and item~=gui and owner.savedGui[item]==nil then
   owner.savedGui[item]=item.Enabled;item.Enabled=false
   table.insert(owner.connections,item:GetPropertyChangedSignal("Enabled"):Connect(function()
    if not owner.destroyed and item.Enabled then item.Enabled=false end
   end))
  end
 end
 function owner:destroy()
  if self.destroyed then return end;self.destroyed=true
  Run:UnbindFromRenderStep(bindName)
  for _,connection in ipairs(self.connections)do connection:Disconnect()end
  table.clear(self.connections)
  if not controller.destroyed and controller.now==self.heldNow then
   controller.now=savedNow;controller.elapsed=savedElapsed
   controller:apply(savedNow())
  end
  for item,enabled in pairs(self.savedGui)do if item.Parent then item.Enabled=enabled end end
  if workspace.CurrentCamera==camera and camera.Parent then
   camera.CFrame=savedCamera.cf;camera.Focus=savedCamera.focus;camera.FieldOfView=savedCamera.fov
   camera.CameraSubject=savedCamera.subject;camera.CameraType=savedCamera.type
  end
  for _,visual in ipairs(self.visuals)do visual:destroy()end
  if folder.Parent then folder:Destroy()end
  if gui.Parent then gui:Destroy()end
 end
 local function reject(message)
  folder:SetAttribute("LastError",message);gui:SetAttribute("LastError",message)
  return false,message
 end
 local function paint()
  if owner.destroyed then return false end
  controller:apply(owner.heldNow())
  local appearance=if state.body=="rose"then {body="rose",bodyRank=3,secondary="tide",charmVisible=true}
   elseif state.body=="mix"then {body="rose",bodyRank=3,bodyMix="rose:tide",secondary="citrus",charmVisible=true}
   else {body="original",bodyRank=0,secondary="default",charmVisible=true}
  for _,visual in ipairs(owner.visuals)do
   visual.nightTreatment=state.treatment;visual:applyAppearance(appearance);visual:update(0)
   visual.model:SetAttribute("StudyTreatment",state.treatment)
  end
  local target,offset,fov
  if state.view=="close"then target=origin+Vector3.new(-1.8,1.05,0);offset=Vector3.new(1.8,.65,3.9);fov=38
  else
   target=origin+Vector3.new(if owner.avatar then 1.6 else 0,2.1,0)
   offset=if state.view=="rear"then Vector3.new(-7,4,-17)else Vector3.new(7,4,17)
   fov=43
  end
  owner.cameraFrame=CFrame.lookAt(target+offset,target);owner.cameraFocus=CFrame.new(target);owner.cameraFov=fov
  camera.CameraType=Enum.CameraType.Scriptable;camera.CFrame=owner.cameraFrame;camera.Focus=owner.cameraFocus;camera.FieldOfView=fov
  label.Text="Night material study — source rigs, no purchase\n"..string.format("%02d:00 · %s · %s · %s",state.hour,state.treatment,state.view,state.body)
  folder:SetAttribute("ActualHour",Clock.lastHour);folder:SetAttribute("Daylight",Clock.lastDaylight)
  folder:SetAttribute("CameraCFrame",owner.cameraFrame);folder:SetAttribute("CameraFov",fov)
  folder:SetAttribute("LastError",nil);gui:SetAttribute("LastError",nil)
  return true
 end
 function owner:set(hour,treatment,view,body)
  if self.destroyed then return false,"destroyed"end
  hour=if hour==nil then state.hour else hour;treatment=treatment or state.treatment;view=view or state.view;body=body or state.body
  if hour~=12 and hour~=18 and hour~=0 then return reject("Hour must be 12, 18 or 0")end
  if treatment~="groupedRoleFill"then return reject("Historical material labels require an explicitly injected frozen source control")end
  if view~="front"and view~="rear"and view~="close"then return reject("Unknown view")end
  if body~="original"and body~="rose"and body~="mix"then return reject("Unknown appearance")end
  state.hour,state.treatment,state.view,state.body=hour,treatment,view,body
  self.writing=true
  for _,host in ipairs({folder,gui})do host:SetAttribute("Hour",hour);host:SetAttribute("Treatment",treatment);host:SetAttribute("View",view);host:SetAttribute("Body",body)end
  self.writing=false
  return paint()
 end
 local ok,problem=pcall(function()
  owner.heldNow=function()return ((state.hour-Clock.TimeZoneOffsetHours)%24)*3600 end
  controller.now=owner.heldNow
  for _,item in ipairs(guiParent:GetChildren())do hide(item)end
  table.insert(owner.connections,guiParent.ChildAdded:Connect(hide))
  for i,id in ipairs({"pip","puddle"})do
   local visual=Visual.new(folder,origin+Vector3.new(if i==1 then -1.8 else 1.8,0,0),Pets.byId[id],.72,nil,{nightTreatment=state.treatment})
   visual.yaw=0;visual.greeting=2;visual.reducedEffects=true;visual.idleMotionFrozen=true;visual.gaitWeight=0
   visual.model:SetAttribute("EvidenceSourceRig",true);table.insert(owner.visuals,visual)
   folder:SetAttribute(id.."Backend",visual.backend)
  end
  -- Copy only visible avatar parts at their exact authored sizes. This avoids
  -- touching the live character's Archivable, physics, pose or appearance.
  local character=player.Character
  if options.avatar~=false and character then
   local avatar=Instance.new("Model");avatar.Name="ActualAvatarScaleReference";avatar.Parent=folder
   local minimum,maximum=math.huge,-math.huge
   for _,part in ipairs(character:GetDescendants())do if part:IsA("BasePart")and part.Transparency<.99 then
    for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
     local point=part.CFrame:PointToWorldSpace(part.Size*Vector3.new(x,y,z)*.5)
     minimum=math.min(minimum,point.Y);maximum=math.max(maximum,point.Y)
    end end end
   end end
   local root=character:FindFirstChild("HumanoidRootPart")
   if root and minimum<math.huge then
    local delta=origin+Vector3.new(6,0,0)-Vector3.new(root.Position.X,minimum,root.Position.Z)
    for _,part in ipairs(character:GetDescendants())do if part:IsA("BasePart")and part.Transparency<.99 then
     local clone=part:Clone()
     if clone then
      for _,child in ipairs(clone:GetDescendants())do
       if child:IsA("LuaSourceContainer")or child:IsA("JointInstance")or child:IsA("Constraint")or child:IsA("Light")or child:IsA("ParticleEmitter")or child:IsA("Trail")or child:IsA("Beam")then child:Destroy()end
      end
      clone.Anchored=true;clone.CanCollide=false;clone.CanTouch=false;clone.CanQuery=false;clone.AssemblyLinearVelocity=Vector3.zero;clone.AssemblyAngularVelocity=Vector3.zero
      clone.CFrame=part.CFrame+delta;clone.Parent=avatar
     end
    end end
    owner.avatar=avatar;folder:SetAttribute("AvatarMeasuredHeight",maximum-minimum)
   else avatar:Destroy()end
  end
  for _,host in ipairs({folder,gui})do
   for _,name in ipairs({"Hour","Treatment","View","Body"})do
    table.insert(owner.connections,host:GetAttributeChangedSignal(name):Connect(function()
     if owner.writing or owner.destroyed then return end
     owner:set(host:GetAttribute("Hour"),host:GetAttribute("Treatment"),host:GetAttribute("View"),host:GetAttribute("Body"))
    end))
   end
   table.insert(owner.connections,host:GetAttributeChangedSignal("Cleanup"):Connect(function()if host:GetAttribute("Cleanup")==true then owner:destroy()end end))
   table.insert(owner.connections,host.Destroying:Connect(function()owner:destroy()end))
  end
  Run:BindToRenderStep(bindName,Enum.RenderPriority.Camera.Value+2,function()
   if owner.destroyed then return end
   if workspace.CurrentCamera~=camera then owner:destroy();return end
   camera.CameraType=Enum.CameraType.Scriptable;camera.CFrame=owner.cameraFrame;camera.Focus=owner.cameraFocus;camera.FieldOfView=owner.cameraFov
  end)
  owner:set(options.hour or 12,options.treatment or "groupedRoleFill",options.view or "front",options.body or "original")
 end)
 if not ok then owner:destroy();error(problem)end
 return owner
end
