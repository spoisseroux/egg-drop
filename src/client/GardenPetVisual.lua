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
local Readiness=require(script.Parent.PetAssetReadiness)
local NativeArt=require(script.Parent.CareNativeOverrides)
local CooPose=require(script.Parent.PetCooPose)
local PersonalPlay=require(script.Parent.PetPlayVisual)
local Reactions=require(script.Parent.PetReactions)
local IdleBeats=require(script.Parent.PetIdleBeats)
local Attachments=require(script.Parent.PetAttachments)
local Sit=require(script.Parent.PetSitPose)
local Look=require(script.Parent.PetLookAt)
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
 if def.colorRole=="blush"then part.Color=Color3.fromHex(self.definition.faceBody or self.definition.palette.body):Lerp(self.colors.blush,.82)end
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
  local rule=NativeArt.byPet[self.petId]and NativeArt.byPet[self.petId][def.name]
  if rule and rule.frameOffset then cf*=CFrame.new(v(rule.frameOffset)*self.scale)end
  local components=rule and rule.fallbackParts or def.fallbackParts
  if components then
   -- Components retain the parent semantic name/channel; transforms are local to its size.
   for _,component in ipairs(components)do
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
 self.model:SetAttribute("NativeArtVersion",NativeArt.version)
end
local function imported(self,inspectOnly)
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
 if inspectOnly then return source,pending end
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
local function signature(source,pending)
 local rows={tostring(source:GetAttribute("TemplateRevision")or 0)}
 for _,item in ipairs(pending)do local p=item.part;table.insert(rows,p.Name..p.MeshId..tostring(p.MeshSize)..tostring(p.Size)..tostring(p.CFrame))end
 table.sort(rows);return table.concat(rows,"|")
end
function Visual:requestAuthored()
 if self.destroyed or self.nativeOnly or self.assetTicket then return end
 local source,pending=imported(self,true)
 if not source then self.assetStatus="TemplateUnavailable";return end
 local hash=signature(source,pending);local parts={}
 for _,item in ipairs(pending)do table.insert(parts,item.part)end
 self.assetSource,self.assetSignature=source,hash;self.assetStatus="Loading"
 local epoch=self.assetEpoch
 self.assetTicket=self.readiness:request(self.petId,source,hash,parts,self.assetPriority,function(ready,reason)
  if self.destroyed or self.assetEpoch~=epoch then return end
  self.assetReady=ready;self.assetStatus=if ready then "ReadyToSwap"else reason or "Failed"
  if ready then
   self.poseDirty=true
   if not self.readyFrame then self.readyFrame=game:GetService("RunService").PreRender:Once(function()
    self.readyFrame=nil
    if not self.destroyed and self.assetEpoch==epoch then self:commitReadyRig()end
   end)end
  end
 end)
end
function Visual:commitReadyRig()
 if self.destroyed or self.nativeOnly or self.rigSwapInProgress then return end
 self.readiness:step()
 if not self.assetTicket and os.clock()<(self.assetSearchUntil or 0)and os.clock()>=(self.assetProbeAt or 0)then
  self.assetProbeAt=os.clock()+.5;self:requestAuthored()
 end
 if not self.assetReady or not self.model.Parent then return end
 local source,pending=imported(self,true)
 if not source or source~=self.assetSource or signature(source,pending)~=self.assetSignature then
  self.assetTicket:cancel();self.assetTicket=nil;self.assetReady=false;self:requestAuthored();return
 end
 local candidate=setmetatable({},Visual)
 for key,value in pairs(self)do candidate[key]=value end
 candidate.model=Instance.new("Model");candidate.pieces={};candidate.bodyHull={};candidate.nativeOnly=true
 -- Never run the facade's captured sampler against shared live fallback slots.
 candidate.update=Visual.update;candidate.greet=Visual.greet;candidate.poseSlots=nil;candidate.poseBucket=nil;candidate.poseStateKey=nil;candidate.focusEnvelopeCache=nil
 candidate.nightGroups=nil;candidate.nightDaylight=nil;candidate.nightColors=nil;candidate.charmFormsPrepared=nil;candidate.charmRingBound=nil
 candidate.featureHandles=nil;candidate.featureSignature=nil;candidate.personalToy=nil;candidate.personalQuietSince=nil;candidate.personalPlayIdentity=nil
 if not imported(candidate)then candidate.model:Destroy();self.assetReady=false;return end
 candidate:applyAppearance(self.appearance)
 self.rigSwapInProgress=true
 local oldPieces,oldGroups,oldPrimary=self.pieces,self.nightGroups,self.model.PrimaryPart
 local oldFeatures=self.featureHandles;PersonalPlay.cancel(self)
 local newPrimary=candidate.model.PrimaryPart
 self.pieces,self.nightGroups,self.charmFormsPrepared=candidate.pieces,candidate.nightGroups,candidate.charmFormsPrepared
 self.charmRingBound=candidate.charmRingBound
 self.featureHandles,self.featureSignature,self.featureStages=candidate.featureHandles,candidate.featureSignature,candidate.featureStages
 self.featureHaloLift,self.featureRevision=candidate.featureHaloLift,candidate.featureRevision;self.careBoundsKey=nil
 for _,child in ipairs(candidate.model:GetChildren())do child.Parent=self.model end
 -- Feature/attachment attributes were published on the candidate model.
 for key,value in pairs(candidate.model:GetAttributes())do self.model:SetAttribute(key,value)end
 self.model.PrimaryPart=newPrimary
 if oldPrimary then for _,child in ipairs(oldPrimary:GetChildren())do
  if child:IsA("ProximityPrompt")or child:IsA("ClickDetector")then child.Parent=self.model.PrimaryPart end
 end end
 self.backend="AuthoredMesh";self.rigRevision=(self.rigRevision or 0)+1
 self.model:SetAttribute("RigBackend",self.backend);self.model:SetAttribute("RigRevision",self.rigRevision)
 self.poseSlots=nil;self.poseBucket=nil;self.poseStateKey=nil;self.focusEnvelopeCache=nil;self.pivotStartYaw=nil;self.bodyHull={};self.poseDirty=true
 self.nightDaylight=nil;self.nightColors=nil
 self.assetReady=false;self.assetStatus="AuthoredMesh";self.assetTicket:cancel();self.assetTicket=nil;self.nativeOnly=true
 Visual.update(self,0)
 -- Host-only interaction references move before any old geometry can retire.
 if self.onRigChanged then self.onRigChanged(oldPrimary,self.model.PrimaryPart,self.rigRevision)end
 for _,entry in ipairs(oldPieces)do entry.part:Destroy()end
 for _,handle in ipairs(oldFeatures or {})do handle:destroy()end
 for _,group in pairs(oldGroups or {})do group.fill:Destroy();group.model:Destroy()end
 candidate.model:Destroy();self.rigSwapInProgress=false
end
function Visual.new(parent,origin,pet,worldScale,appearance,options)
 local definition=assert(Definitions[pet.id],"No authored garden rig for alias")
 local model=Instance.new("Model");model.Name=pet.name
 local cachedColors=Palette.resolve(pet.id,appearance)
 local self=setmetatable({petId=pet.id,nightTreatment=options and options.nightTreatment or "shadedHead",secondaryColor=cachedColors.secondary,colors=cachedColors,model=model,definition=definition,pieces={},bodyHull={},origin=origin,yaw=0,time=0,greeting=2,worldScale=worldScale or 1,worldContext=worldScale~=nil,scale=(worldScale or 1)*definition.nativeScaleFactor,expression="neutral",lastActionId=nil},Visual)
 self.readiness=options and options.readiness or Readiness.shared;self.nativeOnly=options and options.native==true
 self.materialsEnabled=not options or options.materialsEnabled~=false
 -- Rigs authored to the shared UV gradient opt in to the two-colour body.
 self.twoTone=definition.twoTone==true and not(options and options.twoTone==false)
 self.emissionEnabled=not options or options.emissionEnabled~=false
 self.assetPriority=options and options.priority or(if worldScale==nil then 3 else 2);self.assetEpoch=1;self.rigRevision=0
 local source,pending
 if not self.nativeOnly then source,pending=imported(self,true)end
 local already=source and self.readiness:ready(pet.id,source,signature(source,pending))
 if not(already and imported(self))then native(self)end
 model:SetAttribute("PetFamily",pet.id);model:SetAttribute("RigId",definition.id);model:SetAttribute("RigBackend",self.backend)
 model.Parent=parent;self:applyAppearance(appearance)
 if self.backend~="AuthoredMesh"and not self.nativeOnly then self.assetSearchUntil=os.clock()+12;self:requestAuthored()else self.nativeOnly=true end
 return self
end
function Visual:greet()self.greeting=0 end
function Visual:applyAppearance(appearance)
 self.appearance=appearance
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
 Charms.apply(self,appearance);PersonalPlay.apply(self,appearance);self.poseDirty=true;self:update(0)
end
function Visual:applyGardenPose(sample)
 self.gardenAction,self.actionPhase=sample.action,sample.actionPhase or sample.phase or 0
 -- FEEL-ALIVE B2/B3: a rest sits with a content face (dozy, then sleepy after 20 s);
 -- settle, nookRest and rests of 4 s+ sit. Age/length come from the replicated action.
 local resting=sample.behavior=="rest"or sample.action=="settle"or sample.action=="nookRest"
 self.expression=Expression.garden(sample.expression or "neutral",resting,self.gardenActionAge,Face.daylight(),self.ownerOnDeck)
 self.activitySit=resting and Sit.fromActivity(sample.action,sample.behavior,self.gardenActionLength)
 self.gardenFocus=sample.action=="focus"
 self.gardenBehavior=sample.behavior
 self.toyRole,self.toyTime=sample.toyRole,sample.toyTime
 if sample.action=="greet"and(sample.actionId~=self.lastActionId or sample.generation~=self.lastGeneration)then self:greet()end
 self.lastActionId,self.lastGeneration=sample.actionId,sample.generation
end
function Visual:update(dt)
 self:commitReadyRig()
 -- Studio-only: a changed StudioPetWearables attribute re-applies the current appearance.
 if self.wearDebugRevision~=Attachments.debug.revision and self.appearance~=nil and not self.destroyed then PersonalPlay.apply(self,self.appearance)end
 Charms.step(self)
 self.time+=dt;self.greeting=math.min(2,self.greeting+dt)
 local reduced=self.reducedEffects==true;local toyReach,toyExpression=0,nil
 if self.gardenAction=="toyReturn"then toyReach,toyExpression=ToyPose.sample(self.toyRole,self.toyTime,reduced)end
 local personal=PersonalPlay.sample(self,self.cosmeticTime or self.time)
 if personal then toyReach=personal.reach;toyExpression=personal.expression end
 -- Deck-play reactions (cheer/win/loss) are local presentation over the resting pose.
 local reactHop,reactExpression=Reactions.sample(self,os.clock())
 -- Idle personality beats (C3/C4), only for the owner's own garden pet.
 local beatEligible=self.idleBeatsEnabled==true and self.worldContext and not reduced and not self.focusPose and not self.gardenFocus and not self.focused
  and not self.careState and not self.petting and not personal and toyReach==0 and reactExpression==nil
  and self.gardenAction~="greet"and self.gardenAction~="shove"and self.gardenAction~="toyReturn"and self.gardenAction~="focus"
 local daylight=Face.daylight()
 local beat,beatPhase=IdleBeats.step(self,dt,beatEligible,self.ownerNearStill==true,(self.gaitWeight or 0)<.03 and not self.gardenPivot,daylight)
 local beatPitch,beatYaw,beatHandL,beatHandR,beatStretch,beatEye,beatMouth,beatExpression,beatRise,beatHip,beatWag=IdleBeats.pose(beat,beatPhase or 0,self.idleBeat and self.idleBeat.side)
 -- The cute sit (B3): idle beat, a resting activity, or the owner standing still nearby.
 local sitAllowed=self.worldContext and not self.focusPose and not self.gardenFocus and not self.focused and not self.careState and not self.petting
  and not personal and toyReach==0 and reactExpression==nil and(self.gaitWeight or 0)<.03 and not self.gardenPivot
  and self.gardenAction~="greet"and self.gardenAction~="shove"and self.gardenAction~="toyReturn"and self.gardenAction~="focus"
 if not sitAllowed and(self.careState or self.focusPose or self.gardenFocus or self.petting)then self.sitBlend=0 end
 local sit=Sit.step(self,dt,sitAllowed and(self.activitySit==true or Sit.fromOwner(self.ownerStillNearFor,self.gaitWeight)),if beat=="sit"then IdleBeats.sitWeight(self.idleBeat)else 0)
 if not sitAllowed and sit>0 and not self.reducedEffects then self.poseDirty=true end
 local expression=toyExpression or reactExpression or beatExpression or Expression.name(self)
 if sit>.5 and not toyExpression and not reactExpression and not self.petting then expression=Sit.face(self.sitAge)or(if expression=="neutral"then "content"else expression)end
 local pose=Expression.get(expression)
 -- Look at owner (B2): the head turns toward a nearby owner who starts or stops moving.
 local lookAllowed=self.worldContext and not self.focusPose and not self.gardenFocus and not self.focused and not self.careState and not self.petting and not personal and(beat==nil or beat=="sit")
 local lookYaw=Look.step(self,dt,lookAllowed)
 if math.abs(lookYaw-(self.lastLookYaw or 0))>.002 or(sit>0 and sit<1)then self.poseDirty=true end
 self.lastLookYaw=lookYaw
 local cooRoll,cooNod,cooHand,cooMouth,cooEye=CooPose.sample(self)
 local mouth=if cooMouth>.12 then "open"else pose.mouth
 if personal and self.personalToyId=="bone"and personal.phase>=.58 and personal.phase<=1.02 and not reduced then
  mouth=if math.sin((personal.phase-.58)/.44*math.pi*4)>.25 then "open"else "soft"
 end
 local eye=pose.eye*cooEye
 local blink,breath,bodyStretch,headPitch,headYaw,dotX,dotY,dotStretch=Motion.sample(self,expression)
 if beat then headPitch+=beatPitch;headYaw+=beatYaw;bodyStretch+=beatStretch;eye*=beatEye;if beatMouth then mouth="open"end end
 headYaw+=lookYaw;headPitch-=Sit.HeadUp*sit
 -- Ears roll about their base anchors and the tail yaws about its anchor (C1).
 local wagBoost=self.wagBoost;if beatWag and beatWag>0 then self.wagBoost=math.max(wagBoost or 0,beatWag)end
 local earL,earR,tailYaw=Motion.appendages(self,expression,dt)
 self.wagBoost=wagBoost
 -- Sitting perks the ears; a scamper (over 7 studs a second) lays them back 10 degrees.
 local scamper=if self.reducedEffects then 0 else math.clamp(((self.travelSpeed or 0)-7)/1.5,0,1)*(self.gaitWeight or 0)
 earL+=Sit.EarPerk*sit-math.rad(10)*scamper;earR+=Sit.EarPerk*sit-math.rad(10)*scamper
 local hinges=self.appendageHinges
 if not hinges or hinges.scale~=self.scale then
  local anchors=self.definition.anchors
  hinges={scale=self.scale,EarL=anchors.EarL and v(anchors.EarL)*self.scale,EarR=anchors.EarR and v(anchors.EarR)*self.scale,Tail=anchors.Tail and v(anchors.Tail)*self.scale,
   WingL=anchors.WingL and v(anchors.WingL)*self.scale,WingR=anchors.WingR and v(anchors.WingR)*self.scale}
  self.appendageHinges=hinges
 end
 local wingL,wingR=Motion.wings(self,expression,dt)
 if personal then headPitch-=math.sin(math.clamp(personal.phase/1.8,0,1)*math.pi)*.06 end
 local wave=if reduced then 0 else math.sin(math.clamp(self.greeting/1.2,0,1)*math.pi)
 if self.greeting>=1.2 then wave=0 end
 local greet=wave*(if self.focusPose then .35 else 1)
 local gait=if reduced then 0 else(self.gaitWeight or 0)
 local step=math.sin(self.gaitPhase or 0)*gait
 local shove=if self.gardenAction=="shove"then math.sin(math.clamp(self.actionPhase or 0,0,1)*math.pi*4)else 0
 local root=CFrame.new(self.origin)*CFrame.Angles(0,self.yaw or 0,0)*CFrame.Angles(self.carePitch or 0,0,0)
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
 -- Walk body (B2): lean 4 degrees into travel; sitting lowers 0.22 and leans back 6.
 local lean=math.rad(4)*gait-Sit.Pitch*sit
 local upper=root*CFrame.new(weightX,-(self.careBodyLower or 0)-Sit.Lower*self.scale*sit,0)*CFrame.new(hipAnchor)*CFrame.Angles(lean,0,weightRoll+(beatHip or 0))*CFrame.new(-hipAnchor)
 -- A 0.12 s settle squash at half the boop when a walk stops.
 if(self.lastGait or 0)>.3 and gait<.05 and not reduced then self.settleAt=os.clock()end
 self.lastGait=gait
 -- Boop (C2): a 0.15 s squash, body wider and shorter with the head dipping.
 local boopAge=if self.boopAt and not reduced then os.clock()-self.boopAt else nil
 local boop=if boopAge and boopAge>=0 and boopAge<.15 then math.sin(boopAge/.15*math.pi)else 0
 local settleAge=if self.settleAt and not reduced then os.clock()-self.settleAt else nil
 if settleAge and settleAge>=0 and settleAge<.12 then boop=math.max(boop,.5*math.sin(settleAge/.12*math.pi))end
 self.boopSquash=boop
 -- Head nods 2 degrees a quarter cycle behind the two-bounce walk.
 headPitch+=math.rad(2)*math.sin(2*(self.gaitPhase or 0)-math.pi*.5)*gait
 local hop=(greet*.11+reactHop*.11-boop*.05+(self.movementBob or 0)+(beatRise or 0))*self.scale
 local headAnchor=v(self.definition.anchors.Head)*self.scale
 local head=upper*CFrame.new(0,hop+(pose.head+breath)*self.scale,0)*CFrame.new(headAnchor)*CFrame.Angles(-greet*.08+shove*.15+headPitch+cooNod+(self.careHeadPitch or 0),headYaw,pose.tilt+(self.affectionTilt or 0)*.08+cooRoll+(self.careHeadRoll or 0)+Sit.side(self)*Sit.HeadTilt*sit)*CFrame.new(-headAnchor)
 Bounds.begin(self);Bounds.begin(self.bodyHull)
 for _,entry in ipairs(self.pieces)do
  local name,channel=entry.name,entry.channel;local part=entry.part
  local cf=upper*CFrame.new(0,hop,0)*entry.frame
  local isFace=channel=="Face"or string.find(name,"Eye")or string.find(name,"Glint")or string.find(name,"Mouth")or string.find(name,"Teeth")or string.find(name,"Cheek")
  if channel=="Head"or isFace or channel=="Charm"then cf=head*entry.frame end
  if channel=="Head"and(entry.earSide or string.sub(name,1,3)=="Ear")then
   -- Ear pieces and anything pierced through an ear roll about the ear's base anchor.
   local left=(entry.earSide or string.sub(name,-1))=="L";local hinge=if left then hinges.EarL else hinges.EarR
   -- Positive pose perks the ear toward the crown; negative droops it outward.
   if hinge then cf=head*CFrame.new(hinge)*CFrame.Angles(0,0,if left then -earL else earR)*CFrame.new(-hinge)*entry.frame end
  elseif(name=="Tail"or entry.tailWag)and hinges.Tail and tailYaw~=0 then
   cf=upper*CFrame.new(0,hop,0)*CFrame.new(hinges.Tail)*CFrame.Angles(0,tailYaw,0)*CFrame.new(-hinges.Tail)*entry.frame
  elseif entry.wingSide then
   -- Each wing lifts about its own root: the axis is horizontal and square to the
   -- wing's outward reach, so positive flap raises the tip (cached once per piece).
   local left=entry.wingSide=="L";local hinge=if left then hinges.WingL else hinges.WingR
   local flap=if left then wingL else wingR
   if hinge and flap~=0 then
    local axis=entry.wingAxis
    if not axis then
     local reach=entry.frame.Position-hinge;reach=Vector3.new(reach.X,0,reach.Z)
     axis=if reach.Magnitude>1e-4 then reach.Unit:Cross(Vector3.yAxis)else Vector3.new(0,0,if left then 1 else -1)
     entry.wingAxis=axis
    end
    cf=upper*CFrame.new(0,hop,0)*CFrame.new(hinge)*CFrame.fromAxisAngle(axis,flap)*CFrame.new(-hinge)*entry.frame
   end
  end
  if channel=="HandL"or channel=="HandR"or channel=="CuffL"or channel=="CuffR"or channel=="Hand"then
   local side=if string.sub(name,-1)=="L"then -1 else 1
   local anchorName=(if string.find(channel,"^Cuff")then "Cuff"else "Hand")..(if side<0 then "L"else "R")
   local anchor=v(self.definition.anchors[anchorName]or self.definition.anchors[if side<0 then "HandL"else "HandR"])*self.scale
   local fold=pose.hand+greet*.5+shove*.7+toyReach*.50+(if side<0 then beatHandL else beatHandR)+Sit.HandFold*sit
   cf=upper*CFrame.new(0,hop+cooHand+toyReach*.045*self.scale+(self.careHand or 0),toyReach*.105*self.scale)*CFrame.new(anchor)*CFrame.Angles(-fold,0,side*(-fold*.38+step*.18))*CFrame.new(-anchor)*entry.frame
  elseif channel=="FootL"or channel=="FootR"or channel=="Foot"then
   local side=if string.sub(name,-1)=="L"then -1 else 1
   cf=root*CFrame.new(0,math.max(0,step*side)*.045*self.scale+(self.careFootLift or 0),step*side*.075*self.scale+(self.careFootForward or 0))*Sit.foot(entry.frame,side,sit,self.scale)*entry.frame
  end
  local size=entry.size;local hidden=not Charms.isVisible(self,entry)or entry.suppressed==true
  if channel=="Body"then
   local squash=if self.petId=="pip"then math.cos((self.gaitPhase or 0)*2)*gait*.018 else 0
   size=Vector3.new(size.X*(1+squash*.35+boop*.07),size.Y*(1+bodyStretch-squash-boop*.14),size.Z*(1+squash*.35+boop*.07))
  end
  if entry.role=="charm"then
   cf+=head:VectorToWorldSpace(Vector3.new(0,self.featureHaloLift or 0,0))
   cf,size=Charms.pose(self,cf,size,dotX,dotY,dotStretch,entry)
  end
  if string.find(name,"Eye")then size=Vector3.new(size.X*(if mouth=="open"then 1.12 else 1),size.Y*eye*blink,size.Z)
   if entry.eyeOffsetY then cf*=CFrame.new(0,-entry.eyeOffsetY*(1-eye*blink),0)end
  elseif string.find(name,"Glint")then hidden=hidden or eye*blink<.4
  elseif entry.mouthAlt then hidden=hidden or mouth=="open"or(entry.neutralOnly==true and mouth~="smile")
  elseif name=="MouthO"then hidden=hidden or mouth~="open";if cooMouth>.12 then size*=.45+.55*cooMouth end
  elseif name=="MouthSmile"then
   hidden=hidden or mouth=="open"or(entry.neutralSuppressed==true and mouth=="smile")
   if mouth=="line"then size=Vector3.new(size.X*.5,size.Y*.24,size.Z)elseif mouth=="soft"then size=Vector3.new(size.X*.82,size.Y*.75,size.Z)end
  elseif name=="Teeth"or string.find(name,"^Teeth")then
   hidden=hidden or mouth=="open"or mouth=="line"
   if mouth=="soft"then size*=.78 end
  end
  if(name=="EyeL"or name=="EyeR"or name=="GlintL"or name=="GlintR")and self.expression=="curious"then cf*=CFrame.new(.018*self.scale,.01*self.scale,0)end
  entry.renderHidden=hidden
  Face.paintSurface(entry,self,daylight)
  if entry.faceRole then
   local tint=if entry.faceRole=="cheek"then entry.color:Lerp(self.colors.blush,math.clamp(pose.blush+(self.affectionBlush or 0),0,1))else nil
   Face.paint(entry,self.worldContext,tint,daylight)
  end
  if entry.role=="charm"then Charms.paintVisibility(entry,hidden,self.secondaryColor)end
  local transparency=if hidden then 1 else entry.baseTransparency or 0
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
function Visual:renderPersonalPlay(root)
 PersonalPlay.sample(self,self.cosmeticTime or self.time)
 PersonalPlay.render(self,root or CFrame.new(self.origin)*CFrame.Angles(0,self.yaw or 0,0))
end
function Visual:destroy()
 if self.destroyed then return end;self.destroyed=true;self.assetEpoch+=1
 if self.assetTicket then self.assetTicket:cancel();self.assetTicket=nil end
 if self.readyFrame then self.readyFrame:Disconnect();self.readyFrame=nil end
 PersonalPlay.destroy(self);self.model:Destroy()
end
return Visual
