-- Real mesh/PBR when the verified production pack is ready; visible geometry immediately.
local Storage=game:GetService("ReplicatedStorage")
local Art=require(script.Parent.DeckArt)
local Config=require(script.Parent.PetMaterialConfig)
local Materials=require(script.Parent.PetMaterials)
local Readiness=require(script.Parent.PetAssetReadiness)
local Preview={};local Owner={};Owner.__index=Owner
local teal=Color3.fromHex("#69D7D5")
local function configure(part)
 part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false
 part.Size=Vector3.new(2,2,2);part.CFrame=CFrame.new(0,0,0);part.Color=teal;part.Material=Enum.Material.SmoothPlastic
end
function Owner:tryUpgrade()
 if self.destroyed or self.ready or self.ticket then return false end
 local pack=self.options.templates or Storage:FindFirstChild("PetMaterials")
 local key=Config.FinishProfiles[self.finish];local template=pack and pack:FindFirstChild(key)
 if not template or not template:IsA("SurfaceAppearance")or template:GetAttribute("NativeVerified")~=true
  or template:GetAttribute("MaterialVersion")~=Config.Version or template:GetAttribute("MaterialProfile")~=key then return false end
 local source=self.options.meshSource
 if not source then
  local assets=Storage:FindFirstChild("PetAssets");local family=assets and assets:FindFirstChild("Zivvi")
  source=family and family:FindFirstChild("Zivvi__CharmDot",true)
 end
 if not source or not source:IsA("MeshPart")or source.MeshId==""or source.MeshSize.Magnitude<=0 then return false end
 local epoch=self.epoch;local queue=self.options.readiness or Readiness.shared
 self.ticket=queue:request("finish-sample",source,source.MeshId,{source},2,function(ready)
  if self.destroyed or self.epoch~=epoch or not ready then return end
  local mesh=source:Clone();mesh:ClearAllChildren();configure(mesh);mesh.Name="ProductionFinishSphere"
  local entry={part=mesh,name="Body",colorRole="body",color=teal}
  local visual={appearance={finish=self.finish},emissionEnabled=false}
  local materialOwner=Materials.new({templates=pack})
  local ok,bound=pcall(materialOwner.paint,materialOwner,entry,visual,1)
  if not ok or not bound or entry.materialProfile~=key then mesh:Destroy();return end
  mesh.Parent=self.world;self.fallback:Destroy();self.highlight:Destroy();self.ready=true
  self.root:SetAttribute("PreviewBackend","ProductionPBR");self.root:SetAttribute("FinishProfile",key)
 end)
 return true
end
function Owner:destroy(fromRoot)
 if self.destroyed then return end;self.destroyed=true;self.epoch+=1
 if self.ticket then self.ticket:cancel();self.ticket=nil end
 if not fromRoot and self.root.Parent then self.root:Destroy()end
end
function Preview.new(parent,result,position,size,z,options)
 local root=Art.frame(parent,"UnlockedMaterial",Color3.fromHex("#314E59"),position,size,z);Art.corner(root,16)
 root:SetAttribute("AccessibleLabel",(if result.finishId=="gloss"then "Gloss"else "Matte").." material sample")
 root:SetAttribute("PreviewBackend","ShadedFallback");root:SetAttribute("FinishId",result.finishId)
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
 local self=setmetatable({root=root,world=world,fallback=fallback,highlight=highlight,finish=result.finishId,options=options or {},epoch=0},Owner)
 root.Destroying:Connect(function()self:destroy(true)end)
 if self.options.autoLoad~=false then task.spawn(function()
  local deadline=os.clock()+Config.LoadTimeout
  repeat if self.destroyed or self:tryUpgrade()then return end;task.wait(.1)until os.clock()>=deadline
 end)end
 return self
end
function Preview.create(parent,result,position,size,z)return Preview.new(parent,result,position,size,z).root end
return Preview
