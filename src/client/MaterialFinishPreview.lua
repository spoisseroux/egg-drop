-- Real mesh/PBR when the verified production pack is ready; visible geometry immediately.
local Storage=game:GetService("ReplicatedStorage")
local Lighting=game:GetService("Lighting")
local Art=require(script.Parent.DeckArt)
local Config=require(script.Parent.PetMaterialConfig)
local Materials=require(script.Parent.PetMaterials)
local Catalog=require(game:GetService("ReplicatedStorage").Shared.MaterialCatalog)
local EggPreview=require(script.Parent.EggPreview3D)
local Models=require(game:GetService("ReplicatedStorage").Shared.EggModels)
local Preview={};local Owner={};Owner.__index=Owner
local teal=Color3.fromHex("#69D7D5")
local skyFaces={"SkyboxBk","SkyboxDn","SkyboxFt","SkyboxLf","SkyboxRt","SkyboxUp"}
function Owner:refreshEnvironment()
 if self.destroyed or not self.root.Parent then return end
 for _,connection in ipairs(self.skyFaceConnections)do connection:Disconnect()end;table.clear(self.skyFaceConnections)
 if self.skyClone then self.skyClone:Destroy();self.skyClone=nil end
 self.root:SetAttribute("PreviewEnvironmentReady",false)
 self.root:SetAttribute("PreviewEnvironmentSource",nil)
 self.root:SetAttribute("PreviewEnvironmentReadiness","Unavailable")
 local source=self.environmentRoot:FindFirstChild("WorldSky")
 if not source or not source:IsA("Sky")then return end
 local complete=true
 for _,face in ipairs(skyFaces)do
  table.insert(self.skyFaceConnections,source:GetPropertyChangedSignal(face):Connect(function()self:refreshEnvironment()end))
  if source[face]==""then complete=false end
 end
 if not complete then self.root:SetAttribute("PreviewEnvironmentReadiness","IncompleteSixFaceSky");return end
 local clone=source:Clone()
 if not clone then return end
 clone.Name="FinishEnvironment";clone.Parent=self.viewport;self.skyClone=clone
 -- Six bound faces enable the Viewport environment. This does not claim GPU delivery.
 self.root:SetAttribute("PreviewEnvironmentReady",true)
 self.root:SetAttribute("PreviewEnvironmentSource","WorldSky")
 self.root:SetAttribute("PreviewEnvironmentReadiness","BoundSixFaceSky")
end
function Owner:watchEnvironmentSky(child)
 if not child:IsA("Sky")or self.skyNameConnections[child]then return end
 self.skyNameConnections[child]=child:GetPropertyChangedSignal("Name"):Connect(function()self:refreshEnvironment()end)
end
function Owner:attachEnvironment()
 self.environmentRoot=self.options.environmentRoot or Lighting
 self.skyFaceConnections={};self.skyNameConnections={};self.environmentConnections={}
 for _,child in ipairs(self.environmentRoot:GetChildren())do self:watchEnvironmentSky(child)end
 table.insert(self.environmentConnections,self.environmentRoot.ChildAdded:Connect(function(child)
  if self.destroyed then return end;self:watchEnvironmentSky(child);self:refreshEnvironment()
 end))
 table.insert(self.environmentConnections,self.environmentRoot.ChildRemoved:Connect(function(child)
  local connection=self.skyNameConnections[child];if connection then connection:Disconnect();self.skyNameConnections[child]=nil end
  self:refreshEnvironment()
 end))
 self:refreshEnvironment()
end
function Owner:detachEnvironment()
 for _,connection in ipairs(self.environmentConnections)do connection:Disconnect()end;table.clear(self.environmentConnections)
 for _,connection in ipairs(self.skyFaceConnections)do connection:Disconnect()end;table.clear(self.skyFaceConnections)
 for child,connection in pairs(self.skyNameConnections)do connection:Disconnect();self.skyNameConnections[child]=nil end
 if self.skyClone then self.skyClone:Destroy();self.skyClone=nil end
end
local function configure(part)
 part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false
 part.Size=Vector3.new(2,2,2);part.CFrame=CFrame.new(0,0,0);part.Color=teal;part.Material=Enum.Material.SmoothPlastic
end
function Owner:detachLoads()
 if self.cacheHolder then self.cacheHolder.owner=nil;self.cacheHolder=nil end
 if self.lifeHolder then self.lifeHolder.owner=nil;self.lifeHolder=nil end
 if self.ticket then self.ticket:cancel();self.ticket=nil end
 if self.coreSource then self.coreSource:Destroy();self.coreSource=nil end
end
function Owner:core()
 if self.options.meshSource then return self.options.meshSource end
 if self.coreSource then return self.coreSource end
 local cache=self.options.cache or EggPreview
 local copies=cache.cloneTemplates()
 if copies then
  self.coreSource=copies.Core
  for name,part in pairs(copies)do if name~="Core"then part:Destroy()end end
  return self.coreSource
 end
 if not self.cacheHolder then
  local holder={owner=self,epoch=self.epoch};self.cacheHolder=holder
  cache.loadTemplates(function(ok)
   local owner=holder.owner;holder.owner=nil
   if not owner or owner.destroyed or owner.expired or owner.epoch~=holder.epoch or not owner.root.Parent then return end
   owner.cacheHolder=nil
   if ok then owner:tryUpgrade()else owner.coreFailed=true;owner.root:SetAttribute("PreviewFailure","CoreUnavailable")end
  end)
 end
 return nil
end
function Owner:tryUpgrade()
 if self.destroyed or self.expired or self.coreFailed or self.ready or self.ticket then return false end
 local pack=self.options.templates or Storage:FindFirstChild("PetMaterials")
 local key=Config.FinishProfiles[self.finish];local template=Materials.template(pack,key)
 if not template or not template:IsA("SurfaceAppearance")or template:GetAttribute("NativeVerified")~=true
  or template:GetAttribute("MaterialVersion")~=Config.Version or template:GetAttribute("MaterialProfile")~=key then return false end
 local source=self:core()
 if not source or not source:IsA("MeshPart")or source.MeshId:match("%d+")~=Models.Egg.Core.mesh:match("%d+")or source.MeshSize.Magnitude<=0 then return false end
 local bounds=source.MeshSize
 if math.max(bounds.X,bounds.Y,bounds.Z)/math.min(bounds.X,bounds.Y,bounds.Z)>1.02 then self.root:SetAttribute("PreviewFailure","CoreNotRound");return false end
 local epoch=self.epoch
 local function bind(ready)
  if self.destroyed or self.expired or self.epoch~=epoch or not self.root.Parent or not ready then return end
  local mesh=source:Clone();mesh:ClearAllChildren();configure(mesh);mesh.Name="ProductionFinishSphere"
  local entry={part=mesh,name="Body",colorRole="body",color=teal}
  -- This is an explicit body sample, using the same opacity owner as real pets.
  local visual={appearance={finish=self.finish},emissionEnabled=false,definition={pieces={{name="Body"}}}}
  local materialOwner=Materials.new({templates=pack})
  local ok,bound=pcall(materialOwner.paint,materialOwner,entry,visual,1)
  if not ok or not bound or entry.materialProfile~=key or not entry.materialSurface or entry.materialSurface.Parent~=mesh
   or entry.materialSurface:GetAttribute("NativeVerified")~=true or entry.materialSurface:GetAttribute("MaterialProfile")~=key then mesh:Destroy();return end
  mesh.Transparency=Materials.transparency(entry,visual,false)
  if self.finish=="jelly"and math.abs(mesh.Transparency-.15)>.001 then mesh:Destroy();return end
  mesh.Parent=self.world;self.fallback:Destroy();self.highlight:Destroy();self.ready=true
  self.root:SetAttribute("PreviewBackend","ProductionPBR");self.root:SetAttribute("FinishProfile",key)
  self.root:SetAttribute("PreviewReady",true);self.root:SetAttribute("PreviewMeshSource","EggCore")
  self.root:SetAttribute("PreviewReadiness","BoundVerifiedPBR")
  self:detachLoads()
 end
 if self.options.readiness then
  -- External embedding/tests own their readiness transport. Production uses the
  -- already completed CreateMeshPartAsync cache, not a shared owner-clone key.
  self.ticket=self.options.readiness:request("finish-sample",source,source.MeshId,{source},2,bind)
 elseif not self.options.meshSource then
  bind(true)
 else self.root:SetAttribute("PreviewFailure","ExternalSourceUnverified");return false end
 return true
end
function Owner:destroy(fromRoot)
 if self.destroyed then return end;self.destroyed=true;self.epoch+=1
 self:detachLoads();self:detachEnvironment()
 if not fromRoot and self.root.Parent then self.root:Destroy()end
end
function Preview.new(parent,result,position,size,z,options)
 local root=Art.frame(parent,"UnlockedMaterial",Color3.fromHex("#314E59"),position,size,z);Art.corner(root,16)
 root:SetAttribute("AccessibleLabel",(Catalog.ById[result.finishId]or Catalog.ById.standard).name.." material sample")
 root:SetAttribute("PreviewBackend","ShadedFallback");root:SetAttribute("FinishId",result.finishId)
 root:SetAttribute("PreviewReady",false)
 root:SetAttribute("PreviewReadiness","RoundFallback")
 local aspect=Instance.new("UIAspectRatioConstraint");aspect.AspectRatio=1;aspect.Parent=root
 local shadow=Art.frame(root,"GroundShadow",Color3.fromHex("#152C35"),UDim2.fromScale(.5,.85),UDim2.fromScale(.66,.12),z+1);shadow.AnchorPoint=Vector2.new(.5,.5);shadow.BackgroundTransparency=.28;Art.corner(shadow,100)
 local vp=Instance.new("ViewportFrame");vp.Name="FinishViewport";vp.BackgroundTransparency=1;vp.Size=UDim2.fromScale(1,1);vp.ZIndex=z+2;vp.Parent=root
 vp.Ambient=Color3.fromRGB(128,155,157);vp.LightColor=Color3.fromRGB(255,246,226);vp.LightDirection=Vector3.new(-1,-1.4,-3)
 local world=Instance.new("WorldModel");world.Parent=vp
 local fallback=Instance.new("Part");fallback.Name="ShadedFallbackSphere";fallback.Shape=Enum.PartType.Ball;configure(fallback);fallback.Reflectance=if result.finishId=="gloss"then .12 else 0;fallback.Parent=world
 -- Native fallback reflection is a small curved surface, never a claimed PBR binding.
 local highlight=Instance.new("Part");highlight.Name="FallbackReflection";highlight.Shape=Enum.PartType.Ball;configure(highlight)
 highlight.Size=Vector3.new(.15,.40,.06);highlight.CFrame=CFrame.new(-.40,.46,.80)*CFrame.Angles(0,math.rad(-24),math.rad(-25));highlight.Color=Color3.fromHex("#DDF9EF")
 highlight.Transparency=if result.finishId=="gloss"then .06 else 1;highlight.Parent=world
 local camera=Instance.new("Camera");camera.FieldOfView=30
 -- Two-unit sphere occupies 70% of the square stage under the shared lighting.
 camera.CFrame=CFrame.lookAt(Vector3.new(0,.08,1/(math.tan(math.rad(15))*.70)),Vector3.new(0,.08,0));camera.Parent=vp;vp.CurrentCamera=camera
 local self=setmetatable({root=root,viewport=vp,world=world,fallback=fallback,highlight=highlight,finish=result.finishId,options=options or {},epoch=0},Owner)
 self:attachEnvironment()
 local lifetime={owner=self};self.lifeHolder=lifetime
 local delay=self.options.delay or task.delay
 delay(Config.LoadTimeout,function()
  local owner=lifetime.owner
  if owner and not owner.destroyed and not owner.ready then owner.expired=true;owner:detachLoads();if owner.root.Parent then owner.root:SetAttribute("PreviewFailure","TimedOut")end end
 end)
 root.Destroying:Connect(function()self:destroy(true)end)
 if self.options.autoLoad~=false then task.spawn(function()
  local deadline=os.clock()+Config.LoadTimeout
  repeat if self.destroyed or self:tryUpgrade()then return end;task.wait(.1)until os.clock()>=deadline
 end)end
 return self
end
function Preview.create(parent,result,position,size,z)return Preview.new(parent,result,position,size,z).root end
return Preview
