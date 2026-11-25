-- Typed actual payload renderers. No ownership/receipt mutation or pet stand-in.
local Item={}
local function sphere(part)
 local mesh=part:FindFirstChildOfClass("SpecialMesh")
 return mesh and mesh.MeshType==Enum.MeshType.Sphere
end
function Item.lowest(part)
 local cf,half=part.CFrame,part.Size*.5
 if sphere(part)then
  local r,u,l=cf.RightVector,cf.UpVector,cf.LookVector
  local radius=math.sqrt((r.Y*half.X)^2+(u.Y*half.Y)^2+(l.Y*half.Z)^2)
  return cf.Position-(r*(half.X*half.X*r.Y)+u*(half.Y*half.Y*u.Y)+l*(half.Z*half.Z*l.Y))/math.max(1e-8,radius)
 end
 local low
 for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
  local p=cf:PointToWorldSpace(half*Vector3.new(x,y,z));if not low or p.Y<low.Y then low=p end
 end end end
 return low
end
function Item.surfacePoints(part,padding)
 local points={};local half=part.Size*.5+Vector3.one*(padding or 0)
 if sphere(part)then
  for j=0,8 do local a=math.pi*j/8
   for k=0,15 do local b=math.pi*2*k/16
    table.insert(points,part.CFrame:PointToWorldSpace(half*Vector3.new(math.sin(a)*math.cos(b),math.cos(a),math.sin(a)*math.sin(b))))
   end
  end
 else
  for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do table.insert(points,part.CFrame:PointToWorldSpace(half*Vector3.new(x,y,z)))end end end
 end
 return points
end
-- QA R2 (2026-11-15): a finish is shown worn, on a Bear in the garden's own renderer (the
-- starter every player owns), instead of a sample sphere on a slate tile. It is a display
-- model only: `result` is never read for ownership and no pet is awarded.
local function finishBear(world,result,height)
 local Shared=game:GetService("ReplicatedStorage").Shared
 local Pets=require(Shared.PetCatalog)
 if not Pets.byId.pip or not require(Shared.MaterialCatalog).known(result.finishId)then return nil end
 local ok,visual=pcall(require(script.Parent.PetFactory).new,world,Vector3.zero,Pets.byId.pip,nil,{finish=result.finishId},{emissionEnabled=false})
 if not ok or not visual then return nil end
 visual.idleMotionFrozen=true;visual.expression="neutral";visual.greeting=2;visual.poseCadence=0
 local self={visual=visual,model=visual.model,mode="PetFinish",entries={},fit=1,extent=.74}
 local function body()
  local low,high=math.huge,-math.huge;table.clear(self.entries)
  for _,piece in ipairs(visual.pieces)do
   local part=piece.part
   if piece.role~="charm"and part.Parent and part.Transparency<.99 then
    table.insert(self.entries,{part=part})
    local cf,half=part.CFrame,part.Size*.5
    for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
     local py=cf:PointToWorldSpace(half*Vector3.new(x,y,z)).Y;low=math.min(low,py);high=math.max(high,py)
    end end end
   end
  end
  return low,high
 end
 local function measure()
  visual:setRevealPose({heroScale=1});visual.origin=Vector3.zero;visual.yaw=0;visual.poseDirty=true;visual:update(0)
  local low,high=body()
  if low<math.huge then self.fit=height*1.25/math.max(.01,high-low)end
 end
 measure()
 visual.onRigChanged=function()
  if self.destroyed then return end
  measure();if self.onChanged then self.onChanged()end
 end
 function self:pose(sample)
  local reveal={heroScale=self.fit*sample.heroScale,stretch=0,eye=1,blink=1,headYaw=0,headRoll=0,handL=.16,handR=.24,ear=0,tail=0}
  visual:setRevealPose(reveal);visual.yaw=sample.toyYaw or 0;visual.origin=Vector3.zero;visual.greeting=2;visual.poseDirty=true;visual:update(0)
  local low=body()
  local lift=.0021+(sample.hop or 0)*height;local forward=(sample.forward or 0)*height
  if low<math.huge then visual.origin=Vector3.new(0,lift-low,forward);visual.poseDirty=true;visual:update(0);body()end
  self.minimum=lift;self.contact=Vector3.new(0,lift,forward)
 end
 function self:destroy()
  if self.destroyed then return end;self.destroyed=true
  pcall(function()visual:setRevealPose(nil);visual:destroy()end)
 end
 return self
end
function Item.create(world,gui,result,builder,height,reduced)
 if result.finishId and not result.toyId and not result.featureId then
  local bear=finishBear(world,result,height)
  if bear then return bear end
 end
 local api,id
 if result.toyId then api=require(script.Parent.PetToyGeometry);id=result.toyId
 elseif result.featureId then api=require(script.Parent.PetFeatureGeometry);id=result.featureId end
 local handle
 if api then handle=if result.toyId then api.create(world,id,1)else api.create(world,id,1,1,Color3.fromHex("#95CDB9"))
  -- v842: the Sparkler's sparks in the reveal follow Reduced Effects.
  if handle and result.toyId and api.setSparks then api.setSparks(handle,not reduced and not game:GetService("GuiService").ReducedMotionEnabled)end
 elseif result.stat and result.size then
  -- Round 3: the Stat Egg's hero is the 3D Stat Snack. Until its meshes load the snack is the
  -- placeholder stack; it swaps for the production model when they arrive (onChanged).
  local SnackModel=require(script.Parent.SnackModel)
  local model=SnackModel.build(result.size,result.stat,1)
  model.Parent=world
  handle={model=model,destroy=function()model:Destroy()end,snack=true,placeholder=model:GetAttribute("SnackBackend")=="Placeholder"}
 elseif result.itemId then
  -- Slice 3 (2026-11-16): hue jars, finish jars and the charm capsule turn in 3D like toys.
  local model=require(script.Parent.JarModel).build(result.itemId,1,{turn=false})
  if model then model.Parent=world;handle={model=model,destroy=function()model:Destroy()end}end
 end
 do
  if handle then
   local _,size=handle.model:GetBoundingBox();local scale=height*1.45/math.max(.01,size.X,size.Y)
   local entries={}
   for _,part in ipairs(handle.model:GetDescendants())do if part:IsA("BasePart")then
    table.insert(entries,{part=part,frame=part.CFrame,size=part.Size})
   end end
   local self={model=handle.model,handle=handle,entries=entries,scale=scale,mode="Object3D"}
   -- A snack tips its top 16 degrees toward the camera so the topper reads (Spencer 2026-11-20).
   local lean=if handle.snack then math.rad(16)else 0
   function self:pose(sample)
    self.lastSample=sample
    local rotation=CFrame.Angles(sample.toyTilt+lean, sample.toyYaw, sample.toyTilt*.45)
    local factor=self.scale*sample.heroScale;local lowest
    for _,entry in ipairs(self.entries)do
     local p=entry.part;p.Size=entry.size*factor;p.CFrame=rotation*CFrame.new(entry.frame.Position*factor)*entry.frame.Rotation
     local point=Item.lowest(p);if not lowest or point.Y<lowest.Y then lowest=point end
    end
    local offset=Vector3.new(0,.0021-lowest.Y+(sample.hop or 0)*height,(sample.forward or 0)*height)
    for _,entry in ipairs(self.entries)do entry.part.CFrame+=offset end
    self.minimum=.0021+(sample.hop or 0)*height;self.contact=lowest+offset
    -- Beta (17) U6: the contact shadow's spot, under the middle of the item (HatchAim.footprint).
    if not self.partList then self.partList={};for _,entry in ipairs(self.entries)do table.insert(self.partList,entry.part)end end
    local fx,fz=require(script.Parent.HatchAim).footprint(self.partList)
    self.footprint=if fx then Vector3.new(fx,self.contact.Y,fz)else self.contact
   end
   function self:destroy()self.destroyed=true;self.handle:destroy()end
   if handle.placeholder then
    -- Poll for the production meshes (SnackModel.warm runs in the background), up to 6 s.
    task.spawn(function()
     local SnackModel=require(script.Parent.SnackModel)
     for _=1,30 do
      task.wait(.2)
      if self.destroyed then return end
      if SnackModel.template(result.size)then
       local made=SnackModel.build(result.size,result.stat,1)
       if made:GetAttribute("SnackBackend")=="Placeholder"then made:Destroy();return end
       self.handle.destroy();made.Parent=world
       local _,size2=made:GetBoundingBox()
       self.scale=height*1.45/math.max(.01,size2.X,size2.Y)
       table.clear(self.entries);self.partList=nil
       for _,part in ipairs(made:GetDescendants())do if part:IsA("BasePart")then table.insert(self.entries,{part=part,frame=part.CFrame,size=part.Size})end end
       self.model=made;self.handle={model=made,destroy=function()made:Destroy()end,snack=true}
       if self.lastSample then self:pose(self.lastSample)end
       if self.onChanged then self.onChanged()end
       return
      end
     end
    end)
   end
   return self
  end
 end
 -- Hue keeps its actual flat native fruit art. Finish/unknown payloads use
 -- their existing host's actual renderer, never a fabricated awarded pet.
 local graphic=if builder then builder(gui,result,UDim2.fromScale(.15,.12),UDim2.fromScale(.7,.76),gui.ZIndex+1)else nil
 local scale=Instance.new("UIScale");scale.Parent=gui
 local self={graphic=graphic,scale=scale,mode="NativeItemArt"}
 function self:pose(sample)
  self.scale.Scale=sample.heroScale
  gui.Rotation=if result.itemId then math.deg(sample.toyYaw)*15/18 else 0
 end
 function self:destroy()if self.graphic then self.graphic:Destroy();self.graphic=nil end end
 return self
end
return Item
