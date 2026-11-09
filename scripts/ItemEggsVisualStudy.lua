-- EVIDENCE FIXTURE ONLY. Invoke in a real client VM: require(driver)(client, options).
-- Uses production Factory/PoseSampler, Follow and GardenActivity. No remotes,
-- character movement, ownership, inventory, stores or rewards are involved.
-- owner:set({hour=0,view="wide",preset="mixed",motion="idle",frozen=true})
-- owner:set({view="side",pets={"pip"},motion="sequence",cadence=15,frozen=false})
-- owner:stats() / owner:destroy(). Only the current runtime is rendered here.
return function(client,initial)
 local Players=game:GetService("Players");local Run=game:GetService("RunService");local Lighting=game:GetService("Lighting");local Http=game:GetService("HttpService")
 local player=assert(Players.LocalPlayer,"real native client VM required")
 local Shared=game:GetService("ReplicatedStorage").Shared
 local Factory=require(client.PetFactory);local Follow=require(client.PetFollow);local Clock=require(client.HollowClock)
 local Activity=require(Shared.GardenActivity);local Hue=require(Shared.HueCatalog);local Pets=require(Shared.PetCatalog)
 local folder=Instance.new("Folder");folder.Name="_ItemEggsVisualStudy_FIXTURE";folder:SetAttribute("FixtureOnly",true);folder.Parent=workspace
 local gui=Instance.new("ScreenGui");gui.Name="ItemEggsVisualStudy_FIXTURE";gui.ResetOnSpawn=false;gui.IgnoreGuiInset=false;gui.DisplayOrder=1000;gui.Parent=player:WaitForChild("PlayerGui")
 local label=Instance.new("TextLabel");label.Name="FixtureMetadata";label.Size=UDim2.new(1,-24,0,48);label.Position=UDim2.fromOffset(12,4)
 label.BackgroundColor3=Color3.fromHex("#16282C");label.BackgroundTransparency=.12;label.BorderSizePixel=0;label.TextColor3=Color3.fromHex("#FFF6E9")
 label.Font=Enum.Font.GothamMedium;label.TextSize=12;label.TextWrapped=true;label.TextXAlignment=Enum.TextXAlignment.Left;label.Parent=gui
 local owner={folder=folder,gui=gui,visuals={},actors={},connections={},cameras={},savedGui={},frames=0,elapsed=0,destroyed=false,trace={}}
 local state={hour=12,view="front",preset="neutral",motion="idle",cadence=15,reduced=false,frozen=true,pets={"pip","puddle"},origin=Vector3.new(-8,4.025,8),hideUI=true,markers=true,treatment="current",at=0}
 local bind="ItemEggsStudy_"..Http:GenerateGUID(false)
 local savedEnvironment={};for _,key in ipairs({"ClockTime","Brightness","ExposureCompensation","Ambient","OutdoorAmbient","ColorShift_Top"})do savedEnvironment[key]=Lighting[key]end
 local air=Lighting:FindFirstChildOfClass("Atmosphere");local savedAir={};if air then for _,key in ipairs({"Color","Decay","Density"})do savedAir[key]=air[key]end end
 local grade=Lighting:FindFirstChild("SproutHollowGrade");local savedGrade=grade and grade.TintColor
 local savedHour,savedDaylight=Clock.lastHour,Clock.lastDaylight
 local savedLamps={};for _,part in ipairs(workspace:GetDescendants())do if part:IsA("PointLight")and part:GetAttribute("HollowLamp")==true then savedLamps[part]=part.Brightness end end
 local controller=Clock.controller;local borrowed=controller~=nil and not controller.destroyed;local savedNow,savedClockElapsed
 if borrowed then savedNow,savedClockElapsed=controller.now,controller.elapsed end
 owner.heldNow=function()return ((state.hour-Clock.TimeZoneOffsetHours)%24)*3600 end
 local function pack(v)return{v.X,v.Y,v.Z}end
 local function rgb(c)return{c.R,c.G,c.B}end
 local function doseLabel(c)return string.format("R%d T%d C%d I%d",c.rose,c.tide,c.citrus,c.iris)end
 local function hide(item)
  if state.hideUI and item:IsA("ScreenGui")and item~=gui then
   if owner.savedGui[item]==nil then
    owner.savedGui[item]=item.Enabled
    table.insert(owner.connections,item:GetPropertyChangedSignal("Enabled"):Connect(function()if not owner.destroyed and state.hideUI and item.Enabled then item.Enabled=false end end))
   end
   item.Enabled=false
  end
 end
 local function pinCamera()
  local camera=workspace.CurrentCamera;if not camera then return end
  if not owner.cameras[camera]then owner.cameras[camera]={type=camera.CameraType,cf=camera.CFrame,focus=camera.Focus,fov=camera.FieldOfView,subject=camera.CameraSubject}end
  camera.CameraType=Enum.CameraType.Scriptable;camera.FieldOfView=state.fov or 45;camera.CFrame=owner.cameraFrame;camera.Focus=CFrame.new(owner.cameraTarget)
 end
 function owner:destroy()
  if self.destroyed then return end;self.destroyed=true;Run:UnbindFromRenderStep(bind)
  for _,connection in ipairs(self.connections)do connection:Disconnect()end
  for _,visual in ipairs(self.visuals)do visual:destroy()end
  if borrowed and not controller.destroyed and controller.now==self.heldNow then
   controller.now=savedNow;controller.elapsed=savedClockElapsed;controller:apply(savedNow())
  else
   if controller and not borrowed then controller:destroy()end
   for key,value in pairs(savedEnvironment)do Lighting[key]=value end
   if air and air.Parent then for key,value in pairs(savedAir)do air[key]=value end end
   if grade and grade.Parent then grade.TintColor=savedGrade end
   for light,brightness in pairs(savedLamps)do if light.Parent then light.Brightness=brightness end end
   Clock.lastHour,Clock.lastDaylight=savedHour,savedDaylight
  end
  for item,enabled in pairs(self.savedGui)do if item.Parent then item.Enabled=enabled end end
  for camera,saved in pairs(self.cameras)do if camera.Parent then pcall(function()camera.CFrame=saved.cf;camera.Focus=saved.focus;camera.FieldOfView=saved.fov;camera.CameraSubject=saved.subject;camera.CameraType=saved.type end)end end
  if folder.Parent then folder:Destroy()end;if gui.Parent then gui:Destroy()end
 end
 local function appearance()
  local main,secondary=Hue.emptyCounts(),Hue.emptyCounts()
  if state.preset=="rose"then main.rose=5 elseif state.preset=="tide"then main.tide=5
  elseif state.preset=="rose-tide"then main.rose=5;secondary.tide=5
  elseif state.preset=="mixed"then main.rose,main.tide=5,5;secondary.citrus,secondary.iris=3,2 end
  if state.main then main=table.clone(state.main)end;if state.secondary then secondary=table.clone(state.secondary)end
  return{mainDoses=main,secondaryDoses=secondary,charmVisible=true,charmShape="dot"}
 end
 local function makeActor(base)
  local route
  if state.motion=="idle"then route={Vector3.zero}
  elseif state.motion=="straight"or state.motion=="stop"then route={Vector3.new(0,0,-2),Vector3.new(0,0,2)}
  elseif state.motion=="turn90"then route={Vector3.new(0,0,-2),Vector3.zero,Vector3.new(3,0,0)}
  elseif state.motion=="turn180"then route={Vector3.new(0,0,-2),Vector3.new(0,0,2),Vector3.new(0,0,-2)}
  else route={Vector3.new(0,0,-2),Vector3.new(0,0,2),Vector3.new(3,0,2),Vector3.new(0,0,2)}end
  local path,total={},0;local position=base+route[1];local first=position;local yaw=0
  local function append(target,hold)
   local legs,duration=Activity.plan(position,target,Vector3.zero,4,hold or 0,yaw)
   for _,leg in ipairs(legs)do table.insert(path,leg)end
   total+=duration
   local actor={from=Activity.pack(position),to=Activity.pack(target),startTime=0,endTime=duration,path=legs}
   local final=Activity.sample(actor,duration);position,yaw=final.position,final.yaw
  end
  if #route==1 then append(position,1)else
   for i=2,#route do append(base+route[i]);if i<#route then append(position,.55)end end
   append(position,2)
  end
  return{from=Activity.pack(first),to=Activity.pack(position),startTime=0,endTime=total,path=path,mode="Room",behavior="follow",generation=1,actionId=1,yaw=yaw},total
 end
 local function metadata()
  local a=owner.appearance
  label.Text=string.format("FIXTURE • current production rigs • %02d:00 • %s • %s • %s • %s\nMain %s / Secondary %s • no purchases, saved ownership or rewards",state.hour,if state.cadence==0 then "continuous control"else state.cadence.." poses/s",state.motion,state.view,if state.reduced then "reduced"else "normal",doseLabel(a.mainDoses),doseLabel(a.secondaryDoses))
  folder:SetAttribute("FixtureHour",state.hour);folder:SetAttribute("FixtureCadence",state.cadence);folder:SetAttribute("FixtureMotion",state.motion);folder:SetAttribute("FixtureView",state.view)
  folder:SetAttribute("HistoricalBaseline",false);folder:SetAttribute("Treatment",state.treatment);folder:SetAttribute("Daylight",Clock.lastDaylight)
 end
 function owner:set(options)
  if self.destroyed then return false,"destroyed"end;options=options or{}
  local nextState=table.clone(state);for key,value in pairs(options)do nextState[key]=value end
  if nextState.hour~=0 and nextState.hour~=12 and nextState.hour~=18 then return false,"hour must be 0, 12 or 18"end
  if nextState.cadence~=0 and nextState.cadence~=12 and nextState.cadence~=15 then return false,"cadence must be 0 (continuous), 12 or 15"end
  if not({front=true,threeQuarter=true,side=true,wide=true,lineup=true})[nextState.view]then return false,"unknown view"end
  if not({idle=true,straight=true,stop=true,turn90=true,turn180=true,sequence=true})[nextState.motion]then return false,"unknown motion"end
  if not({neutral=true,rose=true,tide=true,["rose-tide"]=true,mixed=true})[nextState.preset]then return false,"unknown preset"end
  if typeof(nextState.origin)~="Vector3"or type(nextState.at)~="number"or nextState.at<0 or nextState.at~=nextState.at then return false,"invalid origin/time"end
  if nextState.main and not Hue.validCounts(nextState.main)then return false,"invalid Main vector"end
  if nextState.secondary and not Hue.validCounts(nextState.secondary)then return false,"invalid Secondary vector"end
  if nextState.treatment~="current"then return false,"only current runtime supported; use archived captures for historical comparison"end
  if nextState.pets=="all"then nextState.pets={};for _,pet in ipairs(Pets.collection)do table.insert(nextState.pets,pet.id)end end
  if type(nextState.pets)~="table"or #nextState.pets<1 or #nextState.pets>7 then return false,"one to seven pet IDs required"end
  for _,id in ipairs(nextState.pets)do if not Pets.byId[id]then return false,"unknown pet ID"end end
  state=nextState;self.elapsed=state.at;self.frames=0;self.trace={};self.appearance=appearance()
  for _,visual in ipairs(self.visuals)do visual:destroy()end;table.clear(self.visuals);table.clear(self.actors)
  if self.markers then self.markers:Destroy();self.markers=nil end
  controller:apply(self.heldNow())
  local n=#state.pets;local spacing=if n>2 then 2.8 else 3.2
  for index,id in ipairs(state.pets)do
   local shift=(index-(n+1)/2)*spacing;local offset=if state.view=="side"then Vector3.new(0,0,shift)else Vector3.new(shift,0,0)
   local actor,duration=makeActor(state.origin+offset);self.actors[index]=actor;self.duration=duration
   local visual=Factory.new(folder,Activity.vector(actor.from),Pets.byId[id],.72,self.appearance)
   visual.poseCadence=state.cadence;visual.reducedEffects=state.reduced
   visual.greeting=if id=="pip"or id=="puddle"or id=="bloom_pip"then 2 else 0;visual.time=0;visual.poseDirty=true;visual.cosmeticSeed=index*113
   visual.model:SetAttribute("EvidenceFixture",true);table.insert(self.visuals,visual)
  end
  if state.markers then
   local markers=Instance.new("Folder");markers.Name="FixtureGroundRuler";markers.Parent=folder;self.markers=markers
   for i=-4,4 do local mark=Instance.new("Part");mark.Name="QuarterStudTick";mark.Anchored=true;mark.CanCollide=false;mark.CanTouch=false;mark.CanQuery=false;mark.Material=Enum.Material.SmoothPlastic;mark.Color=Color3.fromHex("#D8E5C4")
    mark.Size=Vector3.new(.025,.012,if i%4==0 then .24 else .12);mark.Position=state.origin+Vector3.new(i*.25,-.015,-2.7);mark.Parent=markers
   end
  end
  local target=state.origin+Vector3.new(if state.motion=="sequence"or state.motion=="turn90"then 1.2 else 0,if state.view=="side"then .65 else 1.0,0)
  local offset
  if state.view=="side"then offset=Vector3.new(7,1.35,0)
  elseif state.view=="threeQuarter"then offset=Vector3.new(6,2.4,7)
  elseif state.view=="wide"then offset=Vector3.new(7,3.2,14)
  elseif state.view=="lineup"then offset=Vector3.new(0,4.0,math.max(16,n*2.8))
  else offset=Vector3.new(0,2.4,9)end
  if state.cameraOffset then offset=state.cameraOffset end
  self.cameraTarget=state.cameraTarget or target;self.cameraFrame=CFrame.lookAt(self.cameraTarget+offset,self.cameraTarget)
  if not state.hideUI then for item,enabled in pairs(owner.savedGui)do if item.Parent then item.Enabled=enabled end end end
  for _,item in ipairs(gui.Parent:GetChildren())do hide(item)end
  metadata();pinCamera();return true
 end
 function owner:stats()
  local subjects={}
  for index,visual in ipairs(self.visuals)do
   local pieces=0;for _ in ipairs(visual.pieces)do pieces+=1 end
   local feet={};for _,slot in ipairs(visual.poseSlots or{})do if slot.side then table.insert(feet,{side=slot.side,position=pack(slot.entry.part.Position),stance=slot.stance==true,anchor=slot.anchor and pack(slot.anchor)or nil})end end
   local secondaryPart;for _,entry in ipairs(visual.pieces)do if entry.colorRole=="secondary"and entry.role~="charm"then secondaryPart=entry.part;break end end
   local primary=visual.model.PrimaryPart
   subjects[index]={id=state.pets[index],backend=visual.backend or visual.model:GetAttribute("RigBackend"),origin=pack(visual.origin),yaw=visual.yaw or 0,
    gaitPhase=visual.gaitPhase or 0,gaitWeight=visual.gaitWeight or 0,pivot=visual.gardenPivot==true,pivotPhase=visual.gardenPivotPhase or 0,poseSamples=visual.poseSamples or 0,pieces=pieces,
    mainRGB=rgb(visual.colors.body),secondaryRGB=rgb(visual.colors.secondary),renderMainRGB=primary and rgb(primary.Color),bodyMaterial=primary and tostring(primary.Material),renderSecondaryRGB=secondaryPart and rgb(secondaryPart.Color),secondaryMaterial=secondaryPart and tostring(secondaryPart.Material),feet=feet}
  end
  local quality="unknown";pcall(function()quality=tostring(UserSettings():GetService("UserGameSettings").SavedQualityLevel)end)
  local camera=workspace.CurrentCamera
  return{fixture=true,historicalBaseline=false,treatment=state.treatment,treatmentNote="current production material treatment",
   hour=Clock.lastHour,daylight=Clock.lastDaylight,exposure=Lighting.ExposureCompensation,brightness=Lighting.Brightness,graphics=quality,
   cadence=state.cadence,reduced=state.reduced,frozen=state.frozen,view=state.view,motion=state.motion,frames=self.frames,elapsed=self.elapsed,duration=self.duration,
   cameraFov=camera and camera.FieldOfView,cameraFrame=camera and{camera.CFrame:GetComponents()},origin=pack(state.origin),appearance=self.appearance,subjects=subjects,lastFrames=table.clone(self.trace)}
 end
 local ok,problem=pcall(function()
  if borrowed then controller.now=owner.heldNow else controller=Clock.new({now=owner.heldNow,auto=false})end
  table.insert(owner.connections,gui.Parent.ChildAdded:Connect(hide))
  table.insert(owner.connections,folder.Destroying:Connect(function()owner:destroy()end))
  table.insert(owner.connections,gui.Destroying:Connect(function()owner:destroy()end))
  local accepted,why=owner:set(initial);assert(accepted,why)
  Run:BindToRenderStep(bind,Enum.RenderPriority.Last.Value+20,function(dt)
   if owner.destroyed then return end
   if not state.frozen then owner.elapsed+=math.max(0,dt)end
   owner.frames+=1
   for index,visual in ipairs(owner.visuals)do
    owner.actors[index].mode="Room"
    visual.cosmeticTime=owner.elapsed;visual.reducedEffects=state.reduced
    visual.studyFollow=Follow.activity(visual,owner.actors[index],owner.elapsed+.12,if state.frozen then 0 else dt,visual.studyFollow,state.reduced)
    visual:update(if state.frozen then 0 else dt)
   end
   if owner.frames%2==0 and owner.visuals[1]then
    local v=owner.visuals[1];table.insert(owner.trace,{frame=owner.frames,time=owner.elapsed,origin=pack(v.origin),yaw=v.yaw or 0,pivot=v.gardenPivot==true,gait=v.gaitPhase or 0})
    if #owner.trace>32 then table.remove(owner.trace,1)end
   end
   pinCamera()
  end)
 end)
 if not ok then owner:destroy();error(problem)end
 return owner
end
