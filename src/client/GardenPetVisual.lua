-- Astra-authored babies. One host-owned update; geometry is created only once.
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Definitions=require(ReplicatedStorage.Shared.PetRigDefinitions)
local Bounds=require(script.Parent.PetRigBounds)
local Expression=require(script.Parent.PetExpression)
local Charms=require(script.Parent.PetCharms)
local Face=require(script.Parent.PetFace)
local Motion=require(script.Parent.PetIdleMotion)
local ToyPose=require(script.Parent.PetToyPose)
local Palette=require(ReplicatedStorage.Shared.PetPalette)
local Visual={};Visual.__index=Visual
local function v(a)return Vector3.new(a[1],a[2],a[3])end
local function authoredFrame(def,scale)
 local a=def.xyzEulerDeg
 return CFrame.new(v(def.center)*scale)*CFrame.Angles(math.rad(a[1]),math.rad(a[2]),math.rad(a[3]))
end
local function configure(part,color)
 part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=true
 part.Material=Enum.Material.SmoothPlastic;part.Color=color
end
local function add(self,part,def,frame,size)
 configure(part,self.colors[def.colorRole])
 if def.colorRole=="blush"then part.Color=Color3.fromHex(self.definition.palette.body):Lerp(self.colors.blush,.82)end
 part.Name=def.name;part.Size=size;part.Parent=self.model
 local role=if def.channel=="Charm"then "charm"else nil
 local entry={part=part,name=def.name,colorRole=def.colorRole,channel=def.channel,frame=frame,size=size,role=role,color=part.Color,faceRole=if def.colorRole=="blush"then "cheek"elseif string.find(def.name,"Glint")then "spark"else nil,faceBaseColor=part.Color,faceBaseMaterial=part.Material}
 table.insert(self.pieces,entry)
 if def.name=="Body"then self.model.PrimaryPart=part;part.CanQuery=true end
 return entry
end
local function ellipsoid()
 local part=Instance.new("Part");local mesh=Instance.new("SpecialMesh");mesh.MeshType=Enum.MeshType.Sphere;mesh.Parent=part;return part
end
local function native(self)
 for _,def in ipairs(self.definition.pieces)do
  local cf,size=authoredFrame(def,self.scale),v(def.size)*self.scale
  if def.fallbackParts then
   -- Components retain the parent semantic name/channel; transforms are local to its size.
   for _,component in ipairs(def.fallbackParts)do
    local a=component.xyzEulerDeg
    local frame=cf*CFrame.new(v(component.center)*size)*CFrame.Angles(math.rad(a[1]),math.rad(a[2]),math.rad(a[3]))
    add(self,ellipsoid(),def,frame,v(component.size)*size)
   end
  elseif def.shape=="tooth"then
   -- Two wedges form one downward pointed tooth, with a real six-tip grin.
   for _,side in ipairs({-1,1})do
    local part=Instance.new("WedgePart")
    add(self,part,def,cf*CFrame.new(side*size.X*.25,0,0)*CFrame.Angles(0,side*math.pi*.5,math.pi),Vector3.new(size.Z,size.Y,size.X*.5))
   end
  elseif def.shape=="smile"and self.definition.id=="ovelle"then
   for i=-1,1 do
    local part=ellipsoid()
    add(self,part,def,cf*CFrame.new(i*size.X*.28,math.abs(i)*size.Y*.18,0)*CFrame.Angles(0,0,i*.28),Vector3.new(size.X*.48,size.Y*.48,size.Z))
   end
  else
   local part=ellipsoid()
   add(self,part,def,cf,size)
  end
 end
 self.backend="NativeRecipe"
end
local function imported(self)
 local assets=ReplicatedStorage:FindFirstChild("PetAssets")
 local template=string.upper(string.sub(self.definition.id,1,1))..string.sub(self.definition.id,2)
 local source=assets and assets:FindFirstChild(template)
 if not source or not source:IsA("Model")then return false end
 -- Templates are trusted authored assets. Their pivot is at the paws, import front -Z.
 local marker=source:FindFirstChild("PawsOrigin")
 local sourcePivot=if marker and marker:IsA("CFrameValue")then marker.Value else source:GetPivot();local lookup={}
 for _,def in ipairs(self.definition.pieces)do lookup[def.name]=def end
 local pending={};local present={}
 for _,part in ipairs(source:GetDescendants())do if part:IsA("BasePart")then
  local name=string.gsub(part.Name,"^.-__","")
  local def=lookup[name]
  if not def and string.find(name,"^CuffTrim")then def={name=name,channel=(if self.definition.id=="zivvi"then "Hand"else "Cuff")..string.sub(name,-1),colorRole="secondary"}end
  if not def and name=="Teeth"then def={name=name,channel="Face",colorRole="ivory"}end
  if not def and name=="Mouth"then def=lookup.MouthSmile end
  if not def and name=="Cheeks"then def={name=name,channel="Face",colorRole="blush"}end
  if def then
   -- Rojo can create named MeshParts without their immutable mesh resource.
   -- Never mistake checkerboard placeholders for the authored asset backend.
   if not part:IsA("MeshPart")or part.MeshId==""or part.MeshSize.X<=0 or part.MeshSize.Y<=0 or part.MeshSize.Z<=0 then return false end
   if self.definition.id~="zivvi"and self.definition.id~="ovelle"then
    -- New FBXs were imported at100x: only physical Size was normalized, resource bounds stay raw.
    local resourceBounds=part.Size*100
    if(part.MeshSize-resourceBounds).Magnitude>math.max(.001,resourceBounds.Magnitude*.00001)then return false end
   end
   table.insert(pending,{part=part,def=def});present[def.name]=true
  end
 end end
 for _,name in ipairs({"Body","Head","HandL","HandR","FootL","FootR","EyeL","EyeR","MouthSmile","CharmDot"})do if not present[name]then return false end end
 if self.definition.id~="zivvi"and self.definition.id~="ovelle"then
  for _,def in ipairs(self.definition.pieces)do if def.name~="MouthO"and not present[def.name]then return false end end
 end
 if self.definition.id=="zivvi"and not present.Teeth then return false end
 local rotation=CFrame.Angles(0,math.pi,0)
 for _,item in ipairs(pending)do
  local localCF=rotation*sourcePivot:ToObjectSpace(item.part.CFrame)
  add(self,item.part:Clone(),item.def,CFrame.new(localCF.Position*self.scale)*localCF.Rotation,item.part.Size*self.scale)
 end
 -- O mouth remains a separate shape so surprise reads even without a blendshape.
 if not self.model:FindFirstChild("MouthO")then
  local def=lookup.MouthO;local part=ellipsoid()
  add(self,part,def,authoredFrame(def,self.scale),v(def.size)*self.scale)
 end
 self.backend="AuthoredMesh";return self.model.PrimaryPart~=nil
end
function Visual.new(parent,origin,pet,worldScale,appearance,options)
 local definition=assert(Definitions[pet.id],"No authored garden rig for alias")
 local model=Instance.new("Model");model.Name=pet.name
 local cachedColors=Palette.resolve(pet.id,appearance)
 local self=setmetatable({petId=pet.id,nightTreatment=options and options.nightTreatment or "shadedHead",secondaryColor=cachedColors.secondary,colors=cachedColors,model=model,definition=definition,pieces={},bodyHull={},origin=origin,yaw=0,time=0,greeting=2,worldScale=worldScale or 1,worldContext=worldScale~=nil,scale=(worldScale or 1)*definition.nativeScaleFactor,expression="neutral",lastActionId=nil},Visual)
 if(options and options.native==true)or not imported(self)then for _,entry in ipairs(self.pieces)do entry.part:Destroy()end;table.clear(self.pieces);native(self)end
 model:SetAttribute("PetFamily",pet.id);model:SetAttribute("RigId",definition.id);model:SetAttribute("RigBackend",self.backend)
 model.Parent=parent;self:applyAppearance(appearance);return self
end
function Visual:greet()self.greeting=0 end
function Visual:applyAppearance(appearance)
 local colors=Palette.resolve(self.petId,appearance)
 self.colors,self.secondaryColor=colors,colors.secondary
 for _,entry in ipairs(self.pieces)do
  if entry.colorRole=="body"or entry.colorRole=="secondary"then
   local color=colors[entry.colorRole]
   if entry.part.Color~=color then entry.part.Color=color end
   entry.color=color
  end
 end
 self.model:SetAttribute("HueBody",appearance and appearance.body or "original")
 self.model:SetAttribute("HueRank",appearance and appearance.bodyRank or 0)
 self.model:SetAttribute("HueSecondary",appearance and appearance.secondary or "default")
 Charms.apply(self,appearance);self.poseDirty=true;self:update(0)
end
function Visual:applyGardenPose(sample)
 self.gardenAction,self.actionPhase,self.expression=sample.action,sample.actionPhase or sample.phase or 0,sample.expression or "neutral"
 self.gardenFocus=sample.action=="focus"
 self.toyRole,self.toyTime=sample.toyRole,sample.toyTime
 if sample.action=="greet"and(sample.actionId~=self.lastActionId or sample.generation~=self.lastGeneration)then self:greet()end
 self.lastActionId,self.lastGeneration=sample.actionId,sample.generation
end
function Visual:update(dt)
 self.time+=dt;self.greeting=math.min(2,self.greeting+dt)
 local reduced=self.reducedEffects==true;local toyReach,toyExpression=0,nil
 if self.gardenAction=="toyReturn"then toyReach,toyExpression=ToyPose.sample(self.toyRole,self.toyTime,reduced)end
 local expression=toyExpression or Expression.name(self);local pose=Expression.get(expression)
 local blink,breath,bodyStretch,headPitch,headYaw,dotX,dotY,dotStretch=Motion.sample(self,expression)
 local wave=if reduced then 0 else math.sin(math.clamp(self.greeting/1.2,0,1)*math.pi)
 if self.greeting>=1.2 then wave=0 end
 local greet=wave*(if self.focusPose then .35 else 1)
 local gait=if reduced then 0 else(self.gaitWeight or 0)
 local step=math.sin(self.gaitPhase or 0)*gait
 local shove=if self.gardenAction=="shove"then math.sin(math.clamp(self.actionPhase or 0,0,1)*math.pi*4)else 0
 local daylight=Face.daylight()
 local root=CFrame.new(self.origin)*CFrame.Angles(0,self.yaw or 0,0)
 local u=((self.gaitPhase or 0)/(math.pi*2))%1;local support=0
 if not reduced and not self.focusPose and not self.gardenFocus then
  if u>.08 and u<.50 then support=-math.sin((u-.08)/.42*math.pi)
  elseif u>.58 then support=math.sin((u-.58)/.42*math.pi)end
 end
 support*=gait
 local weightX=support*.045*math.min(1,(self.worldScale or .72)/.72)
 local weightRoll=support*math.rad(3)
 self.weightShift,self.weightRoll=weightX,weightRoll
 local hipAnchor=v(self.definition.anchors.Body)*self.scale
 local upper=root*CFrame.new(weightX,0,0)*CFrame.new(hipAnchor)*CFrame.Angles(0,0,weightRoll)*CFrame.new(-hipAnchor)
 local hop=(greet*.11+(self.movementBob or 0))*self.scale
 local headAnchor=v(self.definition.anchors.Head)*self.scale
 local head=upper*CFrame.new(0,hop+(pose.head+breath)*self.scale,0)*CFrame.new(headAnchor)*CFrame.Angles(-greet*.08+shove*.15+headPitch,headYaw,pose.tilt+(self.affectionTilt or 0)*.08)*CFrame.new(-headAnchor)
 Bounds.begin(self);Bounds.begin(self.bodyHull)
 for _,entry in ipairs(self.pieces)do
  local name,channel=entry.name,entry.channel;local part=entry.part
  local cf=upper*CFrame.new(0,hop,0)*entry.frame
  local isFace=channel=="Face"or string.find(name,"Eye")or string.find(name,"Glint")or string.find(name,"Mouth")or string.find(name,"Teeth")or string.find(name,"Cheek")
  if channel=="Head"or isFace or channel=="Charm"then cf=head*entry.frame end
  if channel=="HandL"or channel=="HandR"or channel=="CuffL"or channel=="CuffR"or channel=="Hand"then
   local side=if string.sub(name,-1)=="L"then -1 else 1
   local anchorName=(if string.find(channel,"^Cuff")then "Cuff"else "Hand")..(if side<0 then "L"else "R")
   local anchor=v(self.definition.anchors[anchorName]or self.definition.anchors[if side<0 then "HandL"else "HandR"])*self.scale
   local fold=pose.hand+greet*.5+shove*.7+toyReach*.50
   cf=upper*CFrame.new(0,hop+toyReach*.045*self.scale,toyReach*.105*self.scale)*CFrame.new(anchor)*CFrame.Angles(-fold,0,side*(-fold*.38+step*.18))*CFrame.new(-anchor)*entry.frame
  elseif channel=="FootL"or channel=="FootR"or channel=="Foot"then
   local side=if string.sub(name,-1)=="L"then -1 else 1
   cf=root*CFrame.new(0,math.max(0,step*side)*.045*self.scale,step*side*.075*self.scale)*entry.frame
  end
  local size=entry.size;local hidden=not Charms.isVisible(self,entry)
  if channel=="Body"then
   local squash=if self.petId=="pip"then math.cos((self.gaitPhase or 0)*2)*gait*.018 else 0
   size=Vector3.new(size.X*(1+squash*.35),size.Y*(1+bodyStretch-squash),size.Z*(1+squash*.35))
  end
  if entry.role=="charm"then cf,size=Charms.pose(self,cf,size,dotX,dotY,dotStretch,entry)end
  if string.find(name,"Eye")then size=Vector3.new(size.X*(if pose.mouth=="open"then 1.12 else 1),size.Y*pose.eye*blink,size.Z)
  elseif string.find(name,"Glint")then hidden=hidden or pose.eye*blink<.4
  elseif name=="MouthO"then hidden=hidden or pose.mouth~="open"
  elseif name=="MouthSmile"then
   hidden=hidden or pose.mouth=="open"
   if pose.mouth=="line"then size=Vector3.new(size.X*.5,size.Y*.24,size.Z)elseif pose.mouth=="soft"then size=Vector3.new(size.X*.82,size.Y*.75,size.Z)end
  elseif name=="Teeth"or string.find(name,"^Teeth")then
   hidden=hidden or pose.mouth=="open"or pose.mouth=="line"
   if pose.mouth=="soft"then size*=.78 end
  end
  if(name=="EyeL"or name=="EyeR"or name=="GlintL"or name=="GlintR")and self.expression=="curious"then cf*=CFrame.new(.018*self.scale,.01*self.scale,0)end
  Face.paintSurface(entry,self,daylight)
  if entry.faceRole then
   local tint=if entry.faceRole=="cheek"then entry.color:Lerp(self.colors.blush,math.clamp(pose.blush+(self.affectionBlush or 0),0,1))else nil
   Face.paint(entry,self.worldContext,tint,daylight)
  end
  local transparency=if hidden then 1 else 0
  if entry.lastSize~=size then part.Size=size;entry.lastSize=size end
  if entry.lastFrame~=cf then part.CFrame=cf;entry.lastFrame=cf end
  if entry.lastTransparency~=transparency then part.Transparency=transparency;entry.lastTransparency=transparency end
  if not hidden then
   Bounds.include(self,cf,size)
   if entry.role~="charm"then Bounds.include(self.bodyHull,cf,size)end
  end
 end
 Bounds.finish(self);Bounds.finish(self.bodyHull)
 self.bodyBoundsFrame,self.bodyBoundsSize=self.bodyHull.rigBoundsFrame,self.bodyHull.rigBoundsSize
end
function Visual:destroy()self.model:Destroy()end
return Visual
