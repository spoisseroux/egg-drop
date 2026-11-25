-- One Cinematic-owned native scene. Receipt stages borrow, never destroy it.
local Shared=game:GetService("ReplicatedStorage").Shared
local Models=require(Shared.EggModels)
local Assets=require(script.Parent.HatchDisplayAssets)
local Factory=require(script.Parent.PetFactory)
local EggPreview=require(script.Parent.EggPreview3D)
local Warmup=require(script.Parent.UIAssetWarmup)
local Pose=require(script.Parent.HatchDisplayPose)
local Scene={};Scene.__index=Scene
local function copy(value)
 if type(value)~="table"then return value end
 local result={};for key,v in pairs(value)do result[key]=copy(v)end;return result
end
local function equal(a,b)
 if type(a)~=type(b)then return false end;if type(a)~="table"then return a==b end
 for key,v in pairs(a)do if not equal(v,b[key])then return false end end
 for key in pairs(b)do if a[key]==nil then return false end end;return true
end
local halves,halfLoading,halfWaiters={},false,{}
local function node(class,parent,props)local o=Instance.new(class);for k,v in pairs(props or {})do o[k]=v end;o.Parent=parent;return o end
local function part(parent,name,size,cf,color,shape)
 local p=node("Part",parent,{Name=name,Size=size,CFrame=cf,Color=color,Material=Enum.Material.SmoothPlastic,Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,CastShadow=false})
 if shape then node("SpecialMesh",p,{MeshType=Enum.MeshType.Sphere})end
 return p
end
local function loadHalves(done)
 local ticket={callback=done}
 function ticket:cancel()self.callback=nil;halfWaiters[self]=nil end
 local function dispatch(ok)
  task.defer(function()local fn=ticket.callback;ticket.callback=nil;if fn then fn(ok)end end)
 end
 if halves.HatchLowerLeft and halves.HatchLowerRight then dispatch(true);return ticket end
 for _,spec in pairs(Assets.Halves)do if not spec.mesh then dispatch(false);return ticket end end
 halfWaiters[ticket]=true;if halfLoading then return ticket end;halfLoading=true
 task.spawn(function()
  local found={};local ok=true
  for name,spec in pairs(Assets.Halves)do
   local success,p=pcall(function()return game:GetService("AssetService"):CreateMeshPartAsync(Content.fromUri(spec.mesh))end)
   if success and typeof(p)=="Instance"and p:IsA("MeshPart")then found[name]=p else ok=false;break end
  end
  if ok then halves=found else for _,p in pairs(found)do p:Destroy()end end
  local callbacks=halfWaiters;halfWaiters={};halfLoading=false
  for consumer in pairs(callbacks)do
   task.defer(function()local fn=consumer.callback;consumer.callback=nil;if fn then fn(ok)end end)
  end
 end)
 return ticket
end
-- v890 QA: on a slow join the egg meshes, split shells and egg texture missed the 1.2 s
-- budget and the hatch showed its settled pose with no animation. The budget is longer and
-- prewarm() (called once at startup) fetches everything a hatch needs before the first one.
Scene.AssetTimeout=3.5
function Scene.prewarm()
 EggPreview.loadTemplates(function()end)
 loadHalves(function()end)
 local maps={}
 for _,typ in pairs(Models.Types)do if typ.colorMap then table.insert(maps,typ.colorMap)end end
 if #maps>0 then Warmup.shared:request(maps,function()end,1)end
end
local function lowBound(parts)
 local low=math.huge;local high=-math.huge
 for _,p in ipairs(parts)do if p.Parent and p.Transparency<.99 then
  local cf,half=p.CFrame,p.Size*.5
  for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
   local yValue=cf:PointToWorldSpace(half*Vector3.new(x,y,z)).Y
   low=math.min(low,yValue);high=math.max(high,yValue)
  end end end
 end end
 return low,high
end
function Scene.new(parent,options)
 options=options or {}
 local self=setmetatable({options=options,home=parent,kind=options.kind or "companion",parts={},ready=false,epoch=1,age=0},Scene)
 self.appearanceSnapshot=copy(options.appearance)
 self.root=node("Frame",parent,{Name="NativeHatchScene",BackgroundColor3=Color3.fromHex("#132F31"),BorderSizePixel=0,Size=UDim2.fromScale(1,1),ClipsDescendants=true,ZIndex=44})
 local function viewport(name)
  local v=node("ViewportFrame",self.root,{Name=name,BackgroundTransparency=1,Size=UDim2.fromScale(1,1),BorderSizePixel=0,ZIndex=45,
   Ambient=Color3.fromRGB(155,181,164),LightColor=Color3.fromRGB(255,241,216),LightDirection=Vector3.new(-1,-1.4,-3)})
  local world=node("WorldModel",v,{});local camera=node("Camera",v,{FieldOfView=38});v.CurrentCamera=camera
  return v,world,camera
 end
 self.stageView,self.stageWorld,self.stageCamera=viewport("NativeHatchStage")
 self.heroView,self.heroWorld,self.heroCamera=viewport("NativeHatchHero");self.heroView.ZIndex=46;self.heroView.ImageTransparency=1
 self.itemGui=node("CanvasGroup",self.root,{Name="NativeItemArt",BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(1,1),GroupTransparency=1,ZIndex=47})
 self.height=1.5
 if self.kind=="companion"then
  local ok,visual=pcall(Factory.new,self.heroWorld,Vector3.zero,options.pet,nil,options.appearance,{emissionEnabled=false})
  if ok then
   self.visual=visual;visual.idleMotionFrozen=true;visual.expression="neutral";visual.greeting=2;visual.poseCadence=0;visual:update(0)
   local ps={};for _,entry in ipairs(visual.pieces)do if entry.role~="charm"then table.insert(ps,entry.part)end end
   local low,high=lowBound(ps);if low<math.huge then self.height=math.max(.1,high-low)end
   visual.onRigChanged=function()
    if self.destroyed or self.visual~=visual then return end
    visual:setRevealPose(nil);self:measureEnvelope();self:render(self.sample or Pose.settled(self.kind,false));self:checkReady()
   end
  else self.failure="PetRendererUnavailable"end
 else
  self.item=require(script.Parent.HatchDisplayItem).create(self.heroWorld,self.itemGui,options.result,options.resultBuilder,self.height,options.reduced==true)
  -- v842 phone notes: the Sparkler sparks in the reveal. A ViewportFrame draws no particles,
  -- so its sparks are 2D (UISparks) thrown from the tip's projected position.
  local tip=options.result and options.result.toyId=="sparkler"and self.item and self.item.model and self.item.model:FindFirstChild("GlowTip",true)
  if tip then
   self.sparkTip=tip;self.sparks=require(script.Parent.UISparks).new(self.root,48)
   self.sparkClock=game:GetService("RunService").RenderStepped:Connect(function(dt)self:stepSparks(dt)end)
  end
  -- A worn finish (the Bear) can swap its rig once the authored meshes arrive.
  self.item.onChanged=function()
   if self.destroyed or self.measuring then return end
   self:measureEnvelope();self:render(self.sample or Pose.settled(self.kind,false))
  end
 end
 self.floor=part(self.stageWorld,"DisplayFloor",Vector3.new(200,.02,200),CFrame.new(0,-.01,0),Color3.fromHex("#132F31"))
 self.pool=part(self.stageWorld,"CreamPool",Vector3.new(2.44,.004,1.34),CFrame.identity,Color3.fromHex("#C6B78B"),true)
 self.shadow=part(self.stageWorld,"ContactShadow",Vector3.new(.42,.002,.26),CFrame.new(0,.003,0),Color3.fromHex("#354134"),true);self.shadow.Transparency=.60
 self:layout()
 local typ=Models.Types[self.kind]or Models.Types.companion
 self.textureTicket=Warmup.shared:request({typ.colorMap},function(ok)
  if self.destroyed or self.timedOut then return end
  self.textureReady=ok;if not ok then self.failure="EggTextureUnavailable"end;self:checkReady()
 end,3)
 local eggConsumer={scene=self};self.eggConsumer=eggConsumer
 EggPreview.loadTemplates(function(ok)
  local scene=eggConsumer.scene
  if not scene or scene.destroyed or scene.timedOut then return end
  if ok then
   local clones=EggPreview.cloneTemplates()
   if clones then for name,p in pairs(clones)do scene:eggPart(name,p,Models.Egg[name],typ)end;scene.eggReady=true end
  end
  if not scene.eggReady then scene.failure="EggMeshesUnavailable"end;scene:checkReady()
 end)
 self.halfTicket=loadHalves(function(ok)
  if self.destroyed or self.timedOut then return end
  if ok then for name,spec in pairs(Assets.Halves)do self:eggPart(name,halves[name]:Clone(),spec,typ)end;self.halvesReady=true
  else self.failure="SplitShellUnavailable"end;self:checkReady()
 end)
 task.delay(Scene.AssetTimeout,function()
  if self.destroyed or self.ready then return end
  self.timedOut=true;self.failure=self.failure or "DisplayAssetsTimeout";self.ready=true
  self:detachLoads()
  self:render(Pose.settled(self.kind,options.reduced==true));if options.onReady then options.onReady(false)end
 end)
 self:render(Pose.sample(0,self.kind,options.reduced==true))
 return self
end
function Scene:detachLoads()
 if self.textureTicket then self.textureTicket:cancel();self.textureTicket=nil end
 if self.halfTicket then self.halfTicket:cancel();self.halfTicket=nil end
 if self.eggConsumer then self.eggConsumer.scene=nil;self.eggConsumer=nil end
end
function Scene:eggPart(name,p,spec,typ)
 p.Name=name;p.Size=spec.size;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
 p.TextureID=if name=="Core"then ""else typ.colorMap;p.Material=Enum.Material.SmoothPlastic;p.Color=Color3.new(1,1,1)
 p.Transparency=1;p.Parent=self.stageWorld;self.parts[name]={part=p,spec=spec}
end
function Scene:checkReady()
 if self.destroyed or self.ready then return end
 local hero=self.kind~="companion"or(self.visual~=nil and self.visual.backend=="AuthoredMesh")
 if self.eggReady and self.halvesReady and self.textureReady and hero then
  self:measureEnvelope()
  self.ready=true;self.failure=nil;if self.options.onReady then self.options.onReady(true)end
 end
end
function Scene:borrow(parent)
 assert(not self.destroyed,"Cannot borrow a destroyed hatch scene")
 local token={};self.borrowToken=token;self.root.Parent=parent;self:layout();return token
end
function Scene:release(token)
 if self.destroyed or token~=self.borrowToken then return false end
 self.borrowToken=nil;self.root.Parent=self.home;self:setBare(false);self:setVeil(0);return true
end
-- QA R4: a stage fades the whole scene in with its own dim (0 clear .. 1 hidden).
function Scene:setVeil(amount)
 if self.destroyed then return end
 amount=math.clamp(amount or 0,0,1)
 if self.veil==amount then return end
 self.veil=amount;self.stageView.ImageTransparency=amount
 if self.sample then self:render(self.sample)end
end
-- A full-screen reveal stage (RevealStage for pets, HatchItemStage for items) draws its own
-- backdrop, floor light and glow: `bare` drops this scene's panel, floor and cream pool, and
-- `hideHero` keeps the emerging pet out (the stage owns the pet's silhouette entrance).
function Scene:setBare(bare,hideHero)
 if self.destroyed then return end
 self.bare=bare==true;self.heroHidden=self.bare and hideHero==true
 -- On a stage the item stands in the stage's own light: brighter and neutral, so it reads
 -- as lit against the coloured backdrop (the panel's green-grey ambient is for the card).
 for _,view in ipairs({self.stageView,self.heroView})do
  view.Ambient=if self.bare then Color3.fromRGB(196,198,204)else Color3.fromRGB(155,181,164)
 end
 if not self.bare then self:setSpin(0)end
 self.root.BackgroundTransparency=if self.bare then 1 else 0
 self.floor.Transparency=if self.bare then 1 else 0;self.pool.Transparency=if self.bare then 1 else 0
 self.root:SetAttribute("Bare",self.bare)
 if self.sample then self:render(self.sample)end
end
-- Where the egg's contact point (the world origin) lands in this scene's rect, 0..1.
-- QA R2: turn the shown item (toy, feature or the Bear wearing a finish) about its own
-- upright axis, by orbiting the hero camera and its light: no part is rewritten. Flat item
-- art (a Hue jar) does not turn. `radians` 0 restores the shared scene camera.
function Scene:setSpin(radians)
 if self.destroyed then return false end
 radians=radians or 0
 if not(self.item and self.item.entries)then radians=0 end
 if self.spin==radians then return radians~=0 end
 self.spin=radians;self:applySpin();return radians~=0
end
function Scene:applySpin()
 local base=self.cameraBase;if not base then return end
 local spin=self.spin or 0
 if spin==0 then self.heroCamera.CFrame=base;self.heroView.LightDirection=Vector3.new(-1,-1.4,-3);return end
 local pivot=self.itemPivot or Vector3.zero
 local turn=CFrame.new(pivot)*CFrame.Angles(0,-spin,0)*CFrame.new(-pivot)
 self.heroCamera.CFrame=turn*base
 self.heroView.LightDirection=turn:VectorToWorldSpace(Vector3.new(-1,-1.4,-3))
end
function Scene:groundPoint()
 local size=self.root.AbsoluteSize;local aspect=math.max(.4,size.X/math.max(1,size.Y))
 local tangent=math.tan(math.rad(self.stageCamera.FieldOfView*.5))
 local v=self.stageCamera.CFrame:PointToObjectSpace(Vector3.zero)
 if v.Z>=0 then return Vector2.new(.5,.8)end
 return Vector2.new(.5+v.X/(-v.Z*tangent*aspect*2),.5-v.Y/(-v.Z*tangent*2))
end
function Scene:layout()
 if self.destroyed then return end
 -- Beta (16) B3: aimed over the egg (HatchAim), never pulled sideways by the item's flight.
 local h=self.height;local target=require(script.Parent.HatchAim).target(self.envelopeCenter,h);local distance=3.6*h
 local size=self.root.AbsoluteSize;local aspect=math.max(.4,size.X/math.max(1,size.Y))
 local vertical=math.clamp(math.deg(2*math.atan(math.tan(math.rad(19))/aspect)),20,75)
 self.stageCamera.FieldOfView=vertical;self.heroCamera.FieldOfView=vertical
 local direction=Vector3.new(0,math.sin(math.rad(8)),math.cos(math.rad(8)))
 local up=Vector3.new(0,math.cos(math.rad(8)),-math.sin(math.rad(8)))
 local tangent=math.tan(math.rad(vertical*.5))
 local function fit(aim,minimum)
  local required=minimum
  for _,point in ipairs(self.envelopePoints or {})do
   local d=point-aim
   required=math.max(required,d:Dot(direction)+math.max(h*.1,math.abs(d.X)/(tangent*aspect*.90),math.abs(d:Dot(up))/(tangent*.90)))
  end
  return required
 end
 distance=fit(target,distance)
 if self.item and self.item.entries and self.itemSettledPoints then
  -- Same fixed scene camera: aim starts at .95H, then solves the requested
  -- contact line (~80%) and 57.5% settled extent. Swept fit always wins.
  target=Vector3.new(target.X,.95*h,target.Z)
  local contact=self.itemSettledContact or Vector3.new(0,.0021,.08*h)
  for _=1,6 do
   local v=contact.Z-target.Z;local k=.6*tangent
   local u=(v*math.sin(math.rad(8))+k*v*math.cos(math.rad(8))-k*distance)/(math.cos(math.rad(8))-k*math.sin(math.rad(8)))
   target=Vector3.new(target.X,contact.Y-u,target.Z)
   -- v850 phone notes: a flat item (the Pocket Deck) sat low in the reveal card, because the
   -- camera put the floor contact on a fixed line. The aim is now the settled item's own
   -- vertical middle, so every item is centred in the card.
   do
    local lowY,highY=math.huge,-math.huge
    for _,point in ipairs(self.itemSettledPoints)do lowY=math.min(lowY,point.Y);highY=math.max(highY,point.Y)end
    if lowY<math.huge then target=Vector3.new(target.X,(lowY+highY)*.5,target.Z)end
   end
   local camera=CFrame.lookAt(target+direction*distance,target)
   local lx,ly,hx,hy=math.huge,math.huge,-math.huge,-math.huge
   for _,point in ipairs(self.itemSettledPoints)do
    local p=camera:PointToObjectSpace(point)
    local x,y=.5+p.X/(-p.Z*tangent*aspect*2),.5-p.Y/(-p.Z*tangent*2)
    lx,ly,hx,hy=math.min(lx,x),math.min(ly,y),math.max(hx,x),math.max(hy,y)
   end
   local desired=distance*math.max(hx-lx,hy-ly)/(self.item.extent or .575)
   distance=math.max(desired,fit(target,h*.1))
  end
 end
 local cf=CFrame.lookAt(target+direction*distance,target)
 self.stageCamera.CFrame=cf;self.heroCamera.CFrame=cf;self.cameraBase=cf
 if(self.spin or 0)~=0 then self:applySpin()end
 self.cameraDistance=distance
 if self.floor then
  local span=math.max(200,distance*12)
  self.floor.Size=Vector3.new(span,.02,span)
 end
end
function Scene:measureEnvelope()
 if self.destroyed or self.measuring then return end;self.measuring=true
 local saved=self.sample;local points={}
 if self.visual then
  local visual=self.visual;visual:setRevealPose(nil);visual.origin=Vector3.zero;visual.greeting=2;visual.poseDirty=true;visual:update(0)
  local body={};for _,entry in ipairs(visual.pieces)do if entry.role~="charm"then table.insert(body,entry.part)end end
  local low,high=lowBound(body);if low<math.huge then self.height=math.max(.1,high-low)end
 end
 -- Analytic gesture extrema plus adjacent landing/entrance/head poses. Cached
 -- once per authored rig/appearance; resizing only refits these same points.
 for _,age in ipairs({0,.95,1,1.05,1.10,1.21,1.32,1.48,1.64,1.85,1.91,1.97,2.05,2.135,2.23,2.30,2.35,2.50,2.65,2.77,2.95,3.65,4.4})do
  self:render(Pose.sample(age,self.kind,false))
  local parts={}
  if self.visual then for _,entry in ipairs(self.visual.pieces)do table.insert(parts,entry.part)end
  elseif self.item and self.item.entries then for _,entry in ipairs(self.item.entries)do table.insert(parts,entry.part)end end
  for _,p in ipairs(parts)do if p.Parent and p.Transparency<.99 then
   if self.item and self.item.entries then
    -- Known primitive ellipsoids need their rendered surface, not a rotated
    -- phantom cube; that cube forced a97px Ball despite the110px target.
    for _,point in ipairs(require(script.Parent.HatchDisplayItem).surfacePoints(p,self.height*.025))do table.insert(points,point)end
   else
    local cf,half=p.CFrame,p.Size*.5+Vector3.one*self.height*.025
    for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do table.insert(points,cf:PointToWorldSpace(half*Vector3.new(x,y,z)))end end end
   end
  end end
  if self.item and self.item.entries then
   if age==4.4 then
    self.itemSettledPoints={}
    self.itemSettledContact=self.item.contact
    local lo,hi=Vector3.one*math.huge,-Vector3.one*math.huge
    for _,p in ipairs(parts)do if p.Parent and p.Transparency<.99 then
     for _,point in ipairs(require(script.Parent.HatchDisplayItem).surfacePoints(p))do table.insert(self.itemSettledPoints,point);lo=lo:Min(point);hi=hi:Max(point)end
    end end
    -- The upright axis the settled item turns about (Scene:setSpin).
    if lo.X<math.huge then self.itemPivot=Vector3.new((lo.X+hi.X)*.5,0,(lo.Z+hi.Z)*.5)end
   end
   -- Include the actual whole egg and visible clearing fragments, so item
   -- enlargement never buys its framing by cropping the intro geometry.
   for _,entry in pairs(self.parts)do local p=entry.part;if p.Transparency<.99 then
    for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do table.insert(points,p.CFrame:PointToWorldSpace(p.Size*.5*Vector3.new(x,y,z)))end end end
   end end
  end
 end
 if #points>0 then
  local lo,hi=Vector3.one*math.huge,-Vector3.one*math.huge
  for _,p in ipairs(points)do lo=lo:Min(p);hi=hi:Max(p)end
  self.envelopePoints=points;self.envelopeCenter=(lo+hi)*.5
 end
 self:layout();self:render(saved or Pose.sample(0,self.kind,false));self.measuring=false
end
function Scene:itemProjectionBounds()
 local aspect=math.max(.4,self.root.AbsoluteSize.X/math.max(1,self.root.AbsoluteSize.Y));local tangent=math.tan(math.rad(self.heroCamera.FieldOfView*.5))
 local lo,hi=Vector2.one*math.huge,-Vector2.one*math.huge
 local function project(point)
  local v=self.heroCamera.CFrame:PointToObjectSpace(point)
  return Vector2.new(.5+v.X/(-v.Z*tangent*aspect*2),.5-v.Y/(-v.Z*tangent*2))
 end
 if self.item and self.item.entries then for _,entry in ipairs(self.item.entries)do
  for _,point in ipairs(require(script.Parent.HatchDisplayItem).surfacePoints(entry.part))do local p=project(point);lo=lo:Min(p);hi=hi:Max(p)end
 end end
 return lo,hi,if self.item and self.item.contact then project(self.item.contact)else nil
end
function Scene:projectionBounds()
 local size=self.root.AbsoluteSize;local aspect=math.max(.4,size.X/math.max(1,size.Y));local tangent=math.tan(math.rad(self.heroCamera.FieldOfView*.5))
 local lo,hi=Vector2.one*math.huge,-Vector2.one*math.huge;local count=0
 local parts={}
 if self.visual then for _,e in ipairs(self.visual.pieces)do table.insert(parts,e.part)end
 elseif self.item and self.item.entries then for _,e in ipairs(self.item.entries)do table.insert(parts,e.part)end end
 for _,p in ipairs(parts)do if p.Parent and p.Transparency<.99 then
  for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
   local v=self.heroCamera.CFrame:PointToObjectSpace(p.CFrame:PointToWorldSpace(p.Size*.5*Vector3.new(x,y,z)))
   local point=Vector2.new(.5+v.X/(-v.Z*tangent*aspect*2),.5-v.Y/(-v.Z*tangent*2))
   lo=lo:Min(point);hi=hi:Max(point);count+=1
  end end end
 end end
 return lo,hi,count
end
function Scene:render(sample)
 if self.destroyed then return end
 self.sample=sample;self.age=sample.age
 local show=sample.heroAlpha
 local veil=self.veil or 0
 self.heroView.ImageTransparency=if self.heroHidden then 1 else math.max(1-show,veil);self.itemGui.GroupTransparency=math.max(1-show,veil)
 if self.visual then
  local visual=self.visual;visual:setRevealPose(sample);visual.origin=Vector3.zero;visual.greeting=2;visual:update(0)
  local ps={};for _,entry in ipairs(visual.pieces)do if entry.role~="charm"then table.insert(ps,entry.part)end end
  local low=lowBound(ps);local target=.002+.005*self.height+sample.hop*self.height
  if low<math.huge then visual.origin=Vector3.new(0,target-low,(sample.forward or 0)*self.height);visual.poseDirty=true;visual:update(0)end
  self.minimum=target
 elseif self.item then self.item:pose(sample);self.minimum=self.item.minimum end
 self.shadow.Size=Vector3.new(.42+sample.hop,.002,.26+sample.hop*.65);self.shadow.Transparency=.60+sample.hop*1.4
 -- Beta (17) U6: under the item's footprint (its middle), not its lowest corner.
 local spot=self.item and(self.item.footprint or self.item.contact)
 if spot then self.shadow.CFrame=CFrame.new(spot.X,.003,spot.Z)end
 -- On a bare stage there is no floor pool: the pet stage draws its own shadow, and an item's
 -- shadow (it sits where the item will land) only belongs once the shell has opened.
 if self.bare and(self.heroHidden or sample.shellAlpha>.02)then self.shadow.Transparency=1 end
 -- v2 (R1.3): the Rare lift and shiver, and a volume-keeping squash pivoted at the foot.
 local shiver=(sample.shiver or 0)*math.rad(1.6)*math.sin((sample.age or 0)*71)
 local egg=CFrame.new(0,(sample.eggLift or 0)*self.height*.06,0)*CFrame.Angles(sample.rock*.25,0,sample.rock+shiver)
 local squash=Vector3.new(sample.eggSX or 1,sample.eggSY or 1,sample.eggSX or 1)
 for name,e in pairs(self.parts)do
  local p,spec=e.part,e.spec;local shellScale=sample.shellScale or 1
  p.Size=spec.size*shellScale*squash
  local cf=egg*CFrame.new(spec.center*shellScale*squash)
  p.Transparency=1-sample.shellAlpha
  if name=="Core"then p.Transparency=1
  elseif name=="TopShell"then
   p.Transparency=1-(sample.capAlpha or sample.shellAlpha)
   cf=CFrame.new(sample.opening*.72,sample.opening*.70,-sample.opening*1.1)*CFrame.Angles(sample.opening*.4,0,sample.opening*.7)*cf
  elseif name=="BottomShell"then if sample.opening>.001 then p.Transparency=1 end
  else
   local side=if spec.center.X<0 then -1 else 1
   p.Transparency=if sample.opening<=.001 then 1 else 1-sample.shellAlpha
   cf=CFrame.new(side*sample.opening*.65,.03,-sample.opening*.75)*CFrame.Angles(0,side*sample.opening*.15,side*sample.opening*.65)*cf
  end
  p.CFrame=cf*CFrame.Angles(0,spec.rotationY or 0,0)
 end
 self.root:SetAttribute("DisplayAge",sample.age);self.root:SetAttribute("DisplayAssetsReady",self.ready and not self.failure)
 self.root:SetAttribute("DisplayFallback",self.failure or "");self.root:SetAttribute("DisplayMinimumY",self.minimum or 0)
end
function Scene:getItemGraphic()return self.item and self.item.graphic end
function Scene:setAppearance(appearance)
 if self.destroyed or equal(self.appearanceSnapshot,appearance)then return false end
 self.appearanceSnapshot=copy(appearance);self.options.appearance=appearance
 if self.visual then
  self.visual:applyAppearance(appearance);self:measureEnvelope()
 end
 return true
end
function Scene:stepSparks(dt)
 local tip,sparks=self.sparkTip,self.sparks;if not tip or not sparks or self.destroyed then return end
 local size=self.root.AbsoluteSize
 if size.X<1 or not tip.Parent then sparks:hide();return end
 local aspect=math.max(.4,size.X/math.max(1,size.Y));local tangent=math.tan(math.rad(self.heroCamera.FieldOfView*.5))
 local function project(point)
  local v=self.heroCamera.CFrame:PointToObjectSpace(point)
  if v.Z>=-.01 then return nil end
  return Vector2.new((.5+v.X/(-v.Z*tangent*aspect*2))*size.X,(.5-v.Y/(-v.Z*tangent*2))*size.Y)
 end
 local at=project(tip.Position);local edge=project(tip.Position+self.heroCamera.CFrame.RightVector*tip.Size.X*.5)
 -- One spark unit is about 3.5% of the stage (a 4-6 px spark thrown 15-40 px), never under 5 px.
 local unit=math.max(5,size.Y*.035);local _=edge
 local on=at~=nil and self.itemGui.GroupTransparency<.5 and not self.heroHidden and self.options.reduced~=true
  and not game:GetService("GuiService").ReducedMotionEnabled
 sparks:step(dt,at,unit,on)
end
function Scene:destroy()
 if self.destroyed then return end;self.destroyed=true;self.epoch+=1
 if self.sparkClock then self.sparkClock:Disconnect();self.sparkClock=nil end
 if self.sparks then self.sparks:destroy();self.sparks=nil end
 self:detachLoads()
 if self.visual then self.visual:setRevealPose(nil);self.visual:destroy();self.visual=nil end
 if self.item then self.item:destroy();self.item=nil end
 self.root:Destroy()
end
return Scene
