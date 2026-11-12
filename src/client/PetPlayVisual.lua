-- Personal props and rooted features share the pet's existing pose clock.
local Toys=require(script.Parent.PetToyGeometry)
local Features=require(script.Parent.PetFeatureGeometry)
local Attachments=require(script.Parent.PetAttachments)
local Rules=require(game:GetService("ReplicatedStorage").Shared.PetAttachmentRules)
local Play={}
local maps={
 pip={left="HandL",right="HandR"},puddle={left="CuffL",right="CuffR"},wick={left="HandL",right="HandR"},orbit={left="HandL",right="HandR"},
 bloom_pip={left="HandL",right="HandR"},foxfire_wick={left="HandL",right="HandR"},eclipse_orbit={left="HandL",right="HandR"}}
local function stage(n)return if type(n)=="number"and n==n and n%1==0 and n>=0 and n<=5 then n else 0 end
function Play.seats(v)
 local found={};local low,high=math.huge,-math.huge
 for _,e in ipairs(v.pieces)do if e.role~="feature"and e.role~="charm"and e.role~="attachment"and not e.suppressed then
  found[e.name]=found[e.name]or e
  low=math.min(low,e.frame.Y-e.size.Y*.5);high=math.max(high,e.frame.Y+e.size.Y*.5)
 end end
 local mapping=maps[v.petId]or maps.pip
 return {head=found.Head,body=found.Body,mouth=found.MouthSmile or found.MouthO,
  left=found[mapping.left]or found.HandL,right=found[mapping.right]or found.HandR,
  height=math.max(.1,high-low),found=found}
end
local function hideToy(v)
 if v.personalToy then v.personalToy:destroy();v.personalToy=nil end
 v.personalToyActive=false;v.personalToyPhase=nil
end
function Play.cancel(v)
 hideToy(v);v.personalQuietSince=nil;v.personalPlayStarted=nil
end
function Play.reset(v)
 Play.cancel(v);v.personalPlayIdentity=nil;v.personalNextOpportunity=nil
end
function Play.clearFeatures(v)
 if v.featureHandles then for _,h in ipairs(v.featureHandles)do h:destroy()end end
 v.featureHandles={}
 for i=#v.pieces,1,-1 do local e=v.pieces[i];e.suppressed=nil;if e.role=="feature"or e.role=="attachment"then table.remove(v.pieces,i)end end
 v.attachmentState=nil
end
function Play.apply(v,appearance)
 local a=type(appearance)=="table"and appearance or {};local toy=a.toyId
 if toy~="ball"and toy~="bone"and toy~="sparkler"then toy="none"end
 if v.personalToyId~=toy or v.personalAppearanceGeneration~=a.appearanceGeneration then Play.reset(v)end
 v.personalToyId,v.personalAppearanceGeneration=toy,a.appearanceGeneration
 local stages=type(a.featureStages)=="table"and a.featureStages or {}
 local h,c,w=stage(stages.horns),stage(stages.claws),stage(stages.wings)
 -- Authored rigs (the Bear) place horns, wings and wearables from their attachment template;
 -- any feature without authored meshes, and every rig without a template, stays procedural.
 local source=Attachments.template(v)
 local wear=if source then Rules.normalize(v.definition,Attachments.wearables(a))else {}
 local key=h..":"..c..":"..w..":"..v.secondaryColor:ToHex()..":"..(if source then "A"..Rules.signature(wear)else "P")
 v.wearDebugRevision=Attachments.debug.revision
 if v.featureSignature==key then return end
 Play.clearFeatures(v);v.featureSignature=key;v.featureStages={horns=h,claws=c,wings=w}
 local seats=Play.seats(v);local head=seats.head
 if not head then return end
 local authored={}
 if source then
  local resolved=Rules.resolve(v.definition,{horns=h,claws=c,wings=w},wear)
  for id in pairs(v.definition.features or {})do authored[id]=Rules.hasFeature(v.definition,id)end
  for name in pairs(resolved.suppress)do for _,e in ipairs(v.pieces)do if e.name==name then e.suppressed=true end end end
  for _,part in ipairs(Attachments.build(v,resolved,source))do table.insert(v.featureHandles,part)end
  v.attachmentState=resolved
 end
 local width=head.size.X;local headCenter=head.frame.Position
 local function attach(id,n,side,frame,channel)
  local prop=Features.create(v.model,id,n,width,v.secondaryColor,side);if not prop then return end
  table.insert(v.featureHandles,prop)
  for i,e in ipairs(prop.specs)do
   local name="Feature_"..id..i..(if side<0 then "L"else "R")
   e.part.Name=name
   table.insert(v.pieces,{part=e.part,name=name,role="feature",featureId=id,channel=channel,frame=frame*e.frame,size=e.size,color=e.part.Color,faceBaseColor=e.part.Color,faceBaseMaterial=e.part.Material})
  end
 end
 for _,side in ipairs({-1,1})do
  if not authored.horns then attach("horns",h,side,CFrame.new(headCenter+Vector3.new(side*width*.30,head.size.Y*.43,-head.size.Z*.18)),"Head")end
  local hand=if side<0 then seats.left else seats.right
  if hand then attach("claws",c,side,CFrame.new(hand.frame.Position+Vector3.new(0,-hand.size.Y*.25,hand.size.Z*.38)),hand.channel)end
  local body=seats.body
  if body and not authored.wings then attach("wings",w,side,CFrame.new(body.frame.Position+Vector3.new(side*body.size.X*.29,body.size.Y*.20,-body.size.Z*.47)),"Back")end
 end
 v.featureHaloLift=0
 if authored.horns then
  -- PET-STYLE-GUIDE: horn stage 4 or 5 lifts the floating charm 0.10 so it clears the tips.
  v.featureHaloLift=v.attachmentState.charmLift*v.scale
 end
 local dot=seats.found.CharmDot
 -- CharmDot was excluded from core measurements; resolve it explicitly.
 for _,e in ipairs(v.pieces)do if e.role=="charm"and(e.charmShape or "dot")=="dot"then dot=e;break end end
 if h>0 and dot and not authored.horns then
  local hornTop=headCenter.Y+head.size.Y*.43+.22*width*h/5
  v.featureHaloLift=math.max(0,hornTop+width*.07-(dot.frame.Y-.05*v.scale))
 end
 v.featureRevision=(v.featureRevision or 0)+1;v.careBoundsKey=nil;v.focusEnvelopeCache=nil;v.poseSlots=nil;v.poseDirty=true
 local shown=v.attachmentState and v.attachmentState.stages or {}
 v.model:SetAttribute("VisibleHorns",shown.horns or h);v.model:SetAttribute("VisibleClaws",c);v.model:SetAttribute("VisibleWings",shown.wings or w)
 v.model:SetAttribute("FeatureBackend",if source then "AuthoredAttachments"else "Procedural")
 v.model:SetAttribute("Wearables",if source then Rules.signature(wear)else "")
end
local function eligible(v)
 return v.personalPlayEnabled==true and v.worldContext and v.personalToyId~="none"and not v.destroyed
  and not v.focusPose and not v.gardenFocus and not v.careState and not v.gardenPivot
  and(v.gaitWeight or 0)<.025 and(v.greeting or 2)>=1.2
  and(v.gardenBehavior==nil or v.gardenBehavior=="follow")and(v.gardenAction==nil or v.gardenAction=="follow")
end
function Play.sample(v,now)
 local seed=math.abs(v.cosmeticSeed or 0)%997
 local identity=tostring(v.personalToyId)..":"..tostring(v.personalAppearanceGeneration)..":"..tostring(v.personalActorIdentity)
 if v.personalPlayIdentity~=identity then
  Play.reset(v);v.personalPlayIdentity=identity;v.personalNextOpportunity=now
 end
 if not eligible(v)then Play.cancel(v);return nil end
 if not v.personalQuietSince then v.personalQuietSince=now end
 -- The authoritative garden starts wandering at3.5s. Settle briefly first,
 -- then preserve the9–16s opportunity deadline across ordinary interruptions.
 if now-v.personalQuietSince<.75 then hideToy(v);return nil end
 if v.personalPlayStarted and now-v.personalPlayStarted>=1.8 then hideToy(v);v.personalPlayStarted=nil end
 if not v.personalPlayStarted then
  if now<(v.personalNextOpportunity or now)then hideToy(v);return nil end
  -- Only begin with room for a complete action before the already-published
  -- follow path can yield to autonomous wandering. An overdue chance waits.
  if v.personalIdleUntil and v.personalIdleUntil-now<1.95 then hideToy(v);return nil end
  v.personalPlayStarted=now;v.personalNextOpportunity=now+9+(seed%701)/100
 end
 local t=if v.reducedEffects then .43 else now-v.personalPlayStarted
 if not v.personalToy then local seats=Play.seats(v);v.personalToy=Toys.create(v.model,v.personalToyId,seats.height);v.personalToyHeight=seats.height end
 if not v.personalToy then return nil end
 v.personalToyActive=true;v.personalToyPhase=t
 local reach=if v.reducedEffects then .22 else math.sin(math.min(1,t/1.8)*math.pi)*.38
 return {phase=t,reach=reach,expression=if v.personalToyId=="bone"then "pleased"else "curious"}
end

function Play.render(v,root)
 local toy=v.personalToy;if not toy or not v.personalToyActive then return end
 local seats=Play.seats(v);local hand=seats.right or seats.left;if not hand then Play.cancel(v);return end
 local size=v.personalToyHeight;local t=v.personalToyPhase or 0;local handFrame=hand.part.CFrame
 local cf=handFrame*CFrame.new(size*.035,0,size*.045)
 if v.personalToyId=="sparkler"then
  local lift=if t<.38 then t/.38 elseif t<.95 then 1 else math.max(0,1-(t-.95)/.8)
  local arc=math.rad(32)*math.sin(math.clamp((t-.38)/.57,0,1)*math.pi)
  cf=CFrame.new(handFrame.Position+root:VectorToWorldSpace(Vector3.new(size*.08,size*.12*lift,0)))*root.Rotation*CFrame.Angles(0,0,-arc)
 elseif v.personalToyId=="ball"then
  local roll=if t<.3 then 0 else math.sin(math.clamp((t-.3)/1.5,0,1)*math.pi)
  local localHand=root:PointToObjectSpace(handFrame.Position)
  cf=root*CFrame.new(localHand.X+roll*size*.32,size*.124,localHand.Z+size*.05)*CFrame.Angles(0,0,-roll*2)
 elseif seats.mouth then
  local sniff=if t<.20 then t/.20 elseif t<1.02 then 1 else math.max(0,1-(t-1.02)/.63)
  local bite=if t>=.58 and t<=1.02 then math.sin((t-.58)/.44*math.pi*4)*size*.014 else 0
  local mouth=seats.mouth.part.Position+root:VectorToWorldSpace(Vector3.new(size*.035,-size*.035,size*.045+bite))
  cf=CFrame.new(handFrame.Position:Lerp(mouth,sniff*.75))*root.Rotation*CFrame.Angles(0,.12,0)
 end
 toy:pivot(cf)
 for i,spec in ipairs(toy.specs)do
  local p=spec.part
  if v.personalToyId=="ball"then
   local roll=if t<.3 then 0 else math.sin(math.clamp((t-.3)/1.5,0,1)*math.pi)
   local squash=Vector3.new(1+roll*.05,1-roll*.12,1+roll*.05)
   p.Size=spec.size*squash;p.CFrame=cf*CFrame.new(spec.frame.Position*squash)*spec.frame.Rotation
  end
  if p.Name=="GlowTip"then
   -- A gentle flicker; Reduced Motion keeps a steady glow and stops the sparks.
   p.Transparency=if v.reducedEffects then 0 else .12+math.sin(t*31+i)*.12
  end
 end
 if toy.emitter then toy.emitter.Enabled=not v.reducedEffects end
end
function Play.destroy(v)Play.cancel(v);Play.clearFeatures(v)end
return Play
