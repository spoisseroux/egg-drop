-- Disposable CLIENT Play fixture only. Never mounted by default.project.json.
-- Actual production renderers + synthetic receipts; no remotes or save acknowledgements.
local Driver={}
function Driver.new(client,playerGui,options)
 options=options or {};local Run=game:GetService("RunService");assert(Run:IsClient(),"Client Play only")
 local Shared=game:GetService("ReplicatedStorage").Shared;local Pets=require(Shared.PetCatalog)
 local C=require(client.HatchCinematic);local Stage=require(client.RevealStage);local View=require(client.EggHatchView)
 local self={serial=0,epoch=0,links={},hidden={},kind=nil};local api=self
 local gui=Instance.new("ScreenGui");gui.Name="_NativeReviewDriver";gui.DisplayOrder=10000;gui.ResetOnSpawn=false
 gui.IgnoreGuiInset=true;gui.ScreenInsets=Enum.ScreenInsets.None;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=playerGui
 local root=Instance.new("Frame");root.Name="Presentation";root.Size=UDim2.fromScale(1,1);root.BackgroundColor3=Color3.fromHex("#132F31");root.BorderSizePixel=0;root.Visible=false;root.Parent=gui
 self.gui,self.root=gui,root
 if options.audio then self.audio=options.audio
 elseif not options.silent then self.audio=require(client.BoardAudio).new();self.ownedAudio=true;self.audio:setMusicEnabled(false);self.audio:setVolume(options.volume or 1)end
 local function noSend()error("Preview is synthetic: transaction/acknowledgement disabled",2)end
 local function hideGui()
  for _,other in ipairs(playerGui:GetChildren())do if other:IsA("ScreenGui")and other~=gui then self.hidden[other]=other.Enabled;other.Enabled=false end end
 end
 local function restore()
  for other,enabled in pairs(self.hidden)do if other.Parent then other.Enabled=enabled end end;table.clear(self.hidden)
  local old=self.oldCamera
  if old and old.camera.Parent then old.camera.CameraType=old.type;old.camera.CFrame=old.frame;old.camera.FieldOfView=old.fov end
  self.oldCamera=nil
 end
 function api:clear()
  self.epoch+=1;self.seekAge=nil
  if self.freeze then self.freeze:Disconnect();self.freeze=nil end
  if self.worldStep then Run:UnbindFromRenderStep(self.worldStep);self.worldStep=nil end
  for _,intent in pairs(self.intents or {})do if intent.destroy then intent:destroy()end end;self.intents=nil
  if self.view then self.view:destroy();self.view=nil end
  if self.cinematic then self.cinematic:destroy();self.cinematic=nil end
  if self.stage then self.stage:destroy();self.stage=nil end
  if self.visual then self.visual:destroy();self.visual=nil end
  if self.reference then self.reference:destroy();self.reference=nil end
  if self.world then self.world:Destroy();self.world=nil end
  if self.backdrop then self.backdrop:destroy();self.backdrop=nil end
  for _,child in ipairs(root:GetChildren())do child:Destroy()end
  root.Visible=false;self.kind=nil;self.itemFinish=nil;restore()
 end
 local function begin(kind)
  assert(not self.destroyed,"Driver destroyed");self:clear();self.serial+=1;self.kind=kind;hideGui();root.Visible=true
  return "native-review-"..self.serial
 end
 function api:pet(appearance)
  local id=begin("pet");local result={id=id,petId="pip",starter=true};local pet=Pets.byId.pip
  local c=C.new(root,self.audio,false,function()return not self.destroyed and gui.Enabled and root.Visible end);self.cinematic=c;c:setBleed(true)
  c.stageHandoff=function(info)
   local stage=Stage.show(root,{scene=info.scene,externalClock=info.externalClock,result=info.result,pet=pet,name=pet.name,description=pet.description,
    appearance=info.appearance,tag=Stage.tagKind(result,"companion"),fresh=info.fresh,instant=info.instant,audio=self.audio,voice=false,reduced=false,
    buttons={View.secondaryButton(result),{id="meet",text="Meet "..pet.name,primary=true}},
    owns=function()return not self.destroyed and root.Visible end,consumeSkipInput=info.consumeSkipInput,
    onSkip=function()c:skip()end,onButton=function()end})
   self.stage=stage;return stage
  end
  c.stageClear=function()local stage=self.stage;self.stage=nil;if stage then stage:destroy()end end
  c:play(result,function()end,{nativeDisplay=true,kind="companion",appearance=appearance});return id
 end
 function api:item(kind,itemId)
  assert(kind=="toy"or kind=="hue"or kind=="material"or kind=="feature","Unknown item kind")
  local id=begin(kind);local Hue=require(client.HueIntent)
  local intents={};local view
  local dependencies={id=function()return id.."-disabled"end,send=noSend,delay=function()end,changed=function()if view then view:refresh()end end}
  local hue=Hue.new(dependencies)
  intents.toy=require(client.ToyIntent).new(dependencies);intents.material=require(client.MaterialIntent).new(dependencies);intents.feature=require(client.FeatureIntent).new(dependencies)
  view=require(client.HueEggView).new(root,hue,{toyIntent=intents.toy,materialIntent=intents.material,featureIntent=intents.feature,
   audio=self.audio,reduceEffects=function()return false end,canCustomize=function()return false end,appearance=function()return{}end})
  self.view=view;self.intents=intents
  local H=require(Shared.HueCatalog);local state={revision=1,status="Ready",inventoryMask=1,nectar=0,restricted=true,
   hueInventory={},petHues={pip={main=H.emptyCounts(),secondary=H.emptyCounts()}},toyUnlocks={},petToys={},materialUnlocks={},petMaterials={},featureStock={},petFeatures={},
   materialAvailable=true,materialPoolVersion=require(Shared.MaterialCatalog).PoolVersion,materialSelectionMode="fixed",nextFixed={material="gloss"}}
  if kind=="toy"then itemId=itemId or "wobble_top";state.toyUnlocks[itemId]=true;state.pendingToyResult={id=id,toyId=itemId,revision=1,catalogVersion=1};view.toyPurchaseInFlight=id
  elseif kind=="material"then itemId=itemId or "jelly";self.itemFinish=itemId;state.materialUnlocks[itemId]=true;state.pendingMaterialResult={id=id,finishId=itemId,revision=1,catalogVersion=1};view.materialPurchaseInFlight=id
  elseif kind=="feature"then itemId=itemId or "horns";state.featureStock[itemId]=1;state.pendingFeatureResult={id=id,featureId=itemId,revision=1,catalogVersion=1};view.featurePurchaseInFlight=id
  else itemId=itemId or "rose";state.hueInventory[itemId]=1;state.pendingHueResult={id=id,itemId=itemId,revision=1,catalogVersion=1};view.purchaseInFlight=id end
  view:open(state,if kind=="toy"then "toys"elseif kind=="material"then "materials"elseif kind=="feature"then "features"else "hue","pip")
  local reveal=if kind=="toy"then view.toyPanel.reveal elseif kind=="material"then view.materialPanel.reveal elseif kind=="feature"then view.featurePanel.reveal else view.itemReveal
  self.cinematic=reveal.cinematic;assert(self.cinematic,"Production receipt did not instantiate its cinematic")
  return id
 end
 function api:ready()
  if self.visual then
   if self.visual.backend~="AuthoredMesh"or not self.reference or self.reference.backend~="AuthoredMesh"then return false end
   for _,entry in ipairs(self.visual.pieces)do
    if entry.name=="Body"then return entry.materialSurface~=nil and entry.materialSurface:GetAttribute("NativeVerified")==true
     and(entry.materialProfile=="BodyJelly"or entry.materialProfile=="BodyTwoToneJelly")and entry.part.Transparency>.1 and entry.part.Transparency<.2 end
   end
   return false
  end
  if self.backdrop then return true end
  local c=self.cinematic;local scene=c and c.nativeScene
  if not scene or not scene.ready or scene.failure then return false end
  if self.kind=="material"then
   local graphic=c:getItemGraphic();if not graphic or graphic:GetAttribute("PreviewBackend")~="ProductionPBR"then return false end
   local expected=require(Shared.MaterialCatalog).ById[self.itemFinish].profile
   for _,part in ipairs(graphic:GetDescendants())do if part:IsA("SurfaceAppearance")and part:GetAttribute("NativeVerified")==true
    and part:GetAttribute("MaterialProfile")==expected and part.Parent:IsA("MeshPart")then
     return self.itemFinish~="jelly"or math.abs(part.Parent.Transparency-.15)<.001
   end end
   return false
  end
  return true
 end
 function api:seek(age)
  local c=assert(self.cinematic,"Replay a hatch first")
  assert(type(age)=="number"and age==age and math.abs(age)<math.huge,"Finite age required")
  assert(self:ready(),"Wait for actual assets before seeking")
  self.seekAge=math.clamp(age,0,c.duration);c:disconnectClock();c.active=true;c.age=self.seekAge;c:paint()
  if self.view then self.view:refresh()end;c:disconnectClock()
  if not self.freeze then
   local epoch=self.epoch
   self.freeze=Run.RenderStepped:Connect(function()
    if self.destroyed or self.epoch~=epoch or self.cinematic~=c then return end
    c:disconnectClock();c.age=self.seekAge;c:paint()
   end)
  end
  return self.seekAge
 end
 function api:jelly(appearance,twoTone)
  begin("jelly");root.Visible=false
  local folder=Instance.new("Folder");folder.Name="_NativeReviewJelly";folder.Parent=workspace;self.world=folder
  local character=game:GetService("Players").LocalPlayer.Character;local hrp=character and character:FindFirstChild("HumanoidRootPart")
  local anchor=options.jellyOrigin or(hrp and hrp.Position+Vector3.new(4,0,0))or Vector3.new(34,10,46)
  local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances=if character then {folder,character}else{folder};params.RespectCanCollide=true
  local function ground(point)
   local hit=workspace:Raycast(point+Vector3.new(0,50,0),Vector3.new(0,-120,0),params)
   assert(hit and hit.Normal.Y>.6,"Choose a real garden ground position through options.jellyOrigin")
   return hit.Position+Vector3.new(0,.02,0)
  end
  local left,right=ground(anchor+Vector3.new(-1,0,0)),ground(anchor+Vector3.new(1,0,0));local origin=(left+right)*.5
  local H=require(Shared.HueCatalog)
  if not appearance then
   local main,secondary=H.emptyCounts(),H.emptyCounts();main.rose=5;secondary.tide=5
   appearance={mainDoses=main,secondaryDoses=secondary}
  end
  appearance=table.clone(appearance);appearance.finish="jelly"
  local standard=table.clone(appearance);standard.finish="standard"
  local Factory=require(client.PetFactory)
  -- Omitting native=true is essential: that option forces the recipe fallback.
  local visual=Factory.new(folder,right,Pets.byId.pip,.72,appearance,{twoTone=twoTone~=false});self.visual=visual
  local reference=Factory.new(folder,left,Pets.byId.pip,.72,standard,{twoTone=twoTone~=false});self.reference=reference
  for _,v in ipairs({reference,visual})do v.greeting=2;v.idleMotionFrozen=true end
  local camera=workspace.CurrentCamera;self.oldCamera={camera=camera,type=camera.CameraType,frame=camera.CFrame,fov=camera.FieldOfView,subject=camera.CameraSubject}
  camera.CameraType=Enum.CameraType.Scriptable;camera.FieldOfView=32
  local key="NativeReviewCamera"..self.serial;self.worldStep=key;local time=0
  Run:BindToRenderStep(key,Enum.RenderPriority.Last.Value+100,function(dt)
   if self.destroyed or self.visual~=visual then return end
   time+=dt
   for _,v in ipairs({reference,visual})do v.yaw=time*.28;v.poseDirty=true;v:update(dt)end
   camera.CFrame=CFrame.lookAt(origin+(options.jellyCameraOffset or Vector3.new(0,2,7.5)),origin+Vector3.new(0,.65,0))
  end)
  return visual
 end
 function api:moonpond()
  begin("moonpond");self.backdrop=require(client.MoonpondBackdrop).new(root,{field=false});return self.backdrop
 end
 function api:status()
  local c=self.cinematic;return{kind=self.kind,ready=self:ready(),age=c and c.age,duration=c and c.duration,
   failure=c and c.nativeScene and c.nativeScene.failure,manual=self.seekAge~=nil,synthetic=true}
 end
 function api:destroy(fromGui)
  if self.destroyed then return end;self:clear();self.destroyed=true
  for _,link in ipairs(self.links)do link:Disconnect()end
  for _,intent in pairs(self.intents or {})do if intent.destroy then intent:destroy()end end
  if self.ownedAudio then self.audio:destroy()end
  if not fromGui then gui:Destroy()end
 end
 table.insert(self.links,gui.Destroying:Connect(function()self:destroy(true)end))
 table.insert(self.links,playerGui:GetAttributeChangedSignal("NativeReviewNonce"):Connect(function()
  if self.destroyed then return end
  local command=playerGui:GetAttribute("NativeReviewCommand");local value=playerGui:GetAttribute("NativeReviewValue")
  local ok,problem=pcall(function()
   if command=="pet"then self:pet()
   elseif command=="toy"or command=="material"or command=="hue"or command=="feature"then self:item(command,value)
   elseif command=="seek"then self:seek(playerGui:GetAttribute("NativeReviewTime"))
   elseif command=="jelly"then self:jelly(nil,value~="plain")
   elseif command=="moonpond"then self:moonpond()
   elseif command=="clear"then self:clear()
   elseif command=="destroy"then self:destroy()else error("Unknown preview command")end
  end)
  if not ok then self:clear();playerGui:SetAttribute("NativeReviewError",tostring(problem))else playerGui:SetAttribute("NativeReviewError",nil)end
 end))
 table.insert(self.links,Run.RenderStepped:Connect(function()
  if self.destroyed then return end
  local status=self:status();playerGui:SetAttribute("NativeReviewReady",status.ready);playerGui:SetAttribute("NativeReviewAge",status.age)
  playerGui:SetAttribute("NativeReviewKind",status.kind);playerGui:SetAttribute("NativeReviewFailure",status.failure)
 end))
 return api
end
return Driver
