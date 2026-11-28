-- Authored attachment meshes (horns and wings S1-S5, wearables) placed from the rig's
-- attachment template. Each part keeps its anchor's channel, so head turns, ear flicks,
-- arm swings and tail wags carry it. Rigs without a template keep the procedural features.
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Rules=require(ReplicatedStorage.Shared.PetAttachmentRules)
local Wearables=require(ReplicatedStorage.Shared.WearableCatalog)
local Variants=require(ReplicatedStorage.Shared.WearableVariants)
-- Angel Wings (ROTATION-2-BRIEF 3): the client look over an egg-only base's rows (scale, Snow, the halo, its finish).
local Wings=require(script.Parent.AngelWings)
local Attachments={}
local rotation=CFrame.Angles(0,math.pi,0)

-- Per-anchor fit (v2 Bunny). A rig that wears another rig's attachment meshes (`fitFrom`, the
-- account id of the rig the meshes were authored on) lists the anchors that moved in
-- `anchorDeltaFromBear`. Every piece on a moved anchor is carried by that anchor's change,
-- T = own anchor frame * source anchor frame:Inverse(), in rig space at scale 1: the face items
-- (EyeL/R, FaceBridge, Mouth, Nose, Cheek) follow the lower face, the ear piercings move onto the
-- long ears and turn with them. Unmoved anchors (hat, shirt, neck, wrists) keep the Bear's frame.
-- Returns {anchor=CFrame}; empty for rigs that wear their own meshes. Pure; cached per definition.
local fitCache=setmetatable({},{__mode="k"})
function Attachments.anchorFit(definition)
 if type(definition)~="table"then return {}end
 local cached=fitCache[definition];if cached then return cached end
 local result={}
 local deltas=definition.anchorDeltaFromBear
 local source=type(definition.fitFrom)=="string"and require(ReplicatedStorage.Shared.PetRigDefinitions)[definition.fitFrom]
 if type(deltas)=="table"and type(source)=="table"then
  for anchor in pairs(deltas)do
   local own=Rules.anchorFrame(definition,anchor,1);local from=Rules.anchorFrame(source,anchor,1)
   if own and from then result[anchor]=own*from:Inverse()end
  end
 end
 fitCache[definition]=result
 return result
end
-- True when the rig's hat pose applies: a shown Hat item without the definition's `unlessFlag`
-- (openCrown: the Flower Crown sits between the ears). Pure.
function Attachments.hatEarPose(definition,resolved)
 local pose=type(definition)=="table"and type(definition.earPose)=="table"and definition.earPose.hat
 if type(pose)~="table"or type(resolved)~="table"then return nil end
 for _,a in ipairs(resolved.show or {})do
  if a.slot==(pose.whenSlot or "Hat")and a.item and not(pose.unlessFlag and a.flags and a.flags[pose.unlessFlag])then return pose end
 end
 return nil
end

-- The template part a rig row clones: lane A's Angel Wings rows may name the shared stage 5 wing mesh (`template`).
local function templatePart(source,a)
 local name=Wings.templateName(a)
 return source:FindFirstChild("Bear__"..name)or source:FindFirstChild(name)
end
Attachments.templatePart=templatePart
-- The template model, only for authored-mesh rigs whose every attachment resource is present.
function Attachments.template(v)
 local definition=v.definition
 if v.backend~="AuthoredMesh"or type(definition.attachments)~="table"or type(definition.attachmentTemplate)~="string"then return nil end
 local assets=v.attachmentAssets or ReplicatedStorage:FindFirstChild("PetAssets")
 local source=assets and assets:FindFirstChild(definition.attachmentTemplate)
 if not source or not source:IsA("Model")then return nil end
 for _,a in ipairs(definition.attachments)do
  local part=templatePart(source,a)
  if not part or not part:IsA("MeshPart")or part.MeshId==""or part.MeshSize.X<=0 then return nil end
 end
 return source
end

local function handle(part)return {part=part,destroy=function()part:Destroy()end}end
-- The finish stepper, required on first use (a rig with no sparkle pick never loads it).
local finishModule=nil
function Attachments.finish()
 if not finishModule then finishModule=require(script.Parent.WearableFinish)end
 return finishModule
end

-- Adds one entry per shown attachment to v.pieces and returns the cleanup handles.
-- tints (optional, WearableCatalog.renderMap(...).tints): slot key -> recolour for a variant;
-- only the base item's main own-colour piece(s) change, the piece stays an "own" colour.
function Attachments.build(v,resolved,source,tints)
 local haloFor=nil
 local marker=source:FindFirstChild("PawsOrigin")
 local pivot=if marker and marker:IsA("CFrameValue")then marker.Value else source:GetPivot()
 local handles={}
 local fits=Attachments.anchorFit(v.definition)
 -- Multi-piece eyes squint and blink as one eye: every piece scales toward the centre of
 -- the item's largest piece on that side, not about its own centre.
 local eyeCenter={}
 for _,a in ipairs(resolved.show)do if a.slot=="Eyes"and a.item then
  local key=(a.side or "")..a.item;local c=eyeCenter[key]
  if not c or a.size[2]>c.h then eyeCenter[key]={h=a.size[2],y=a.center[2]}end
 end end
 for _,a in ipairs(resolved.show)do
  local template=templatePart(source,a)
  local part=template:Clone();part.Name=a.name
  -- An egg-only base's look (Angel Wings): its own colour, its scale about the row's anchor; features never have one.
  local look=if a.feature==nil then Wings.look(a.item)else nil
  part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=true
  part.Material=Enum.Material.SmoothPlastic
  if a.texture and v.definition.attachmentTextures then part.TextureID=v.definition.attachmentTextures[a.texture]or part.TextureID end
  local tint=if tints and a.item then tints[Wearables.attachmentKey(v.definition,a)]else nil
  local tinted=if tint then Wearables.tintFor(tint,a)else nil
  local color=if tinted then Color3.fromHex(tinted)elseif a.colorRole=="own"then Color3.fromHex(a.color)else(v.colors[a.colorRole]or v.secondaryColor)
  -- The look's colour wins over a row that copied the grown wings' secondary role (it stays an own colour).
  if look and look.color and not tinted and a.colorRole~="own"then color=Color3.fromHex(look.color)end
  part.Color=color
  -- Piece colour roles: own colour, secondary-tinted, face ink. Wearables never glow at
  -- night (PET-STYLE-GUIDE 6), so a tinted wearable piece leaves the secondary glow group;
  -- horns and wings (features) keep it.
  local role=if a.colorRole=="own"or(look and look.color)then "own"elseif a.feature==nil and a.colorRole=="secondary"then "wearSecondary"else a.colorRole
  local localCF=rotation*pivot:ToObjectSpace(template.CFrame)
  -- v2 Bunny: the anchor's own fit first (see Attachments.anchorFit), then the per-item lift.
  local anchorFit=a.anchor and fits[a.anchor]
  if anchorFit then localCF=anchorFit*localCF end
  -- Angel Wings: 1.25x about their own root (the row's WingL / WingR anchor), so they stay on the back.
  local grow=if look and type(look.scale)=="number"and look.scale~=1 then look.scale else 1
  if grow~=1 and a.anchor then
   local root=Rules.anchorFrame(v.definition,a.anchor,1)
   if root then localCF=Wings.scaleAbout(localCF,root.Position,grow)else grow=1 end
  end
  -- QA v2 R4.1: a per-item fit lift (WearableCatalog.Fit) so hats sit on the crown.
  local fit=if a.item then Wearables.fitOffset(v.definition.id,a.item)else Vector3.zero
  local frame=CFrame.new((localCF.Position+fit)*v.scale)*localCF.Rotation
  local side=a.side
  local entry={part=part,name=a.name,colorRole=role,variantTint=tinted,piece=a.piece,item=a.item,neutralOnly=a.flags and a.flags.neutralOnly==true or nil,channel=a.channel,frame=frame,size=template.Size*v.scale*grow,
   role=if a.feature then "feature"else "attachment",featureId=a.feature,slot=a.slot,attachment=a,color=color,faceBaseColor=color,faceBaseMaterial=part.Material,
   -- Piercings ride the ear flick; swapped tails wag; an alternate mouth gives way to the open "O".
   earSide=if a.slot=="EarPiercing"or a.slot=="Earring"then side else nil,tailWag=a.slot=="Tail"or nil,mouthAlt=a.slot=="Mouth"or nil,
   -- Wings flap about their own WingL/WingR root (PetIdleMotion.wings).
   wingSide=if a.anchor=="WingL"then "L"elseif a.anchor=="WingR"then "R"else nil}
  local c=a.slot=="Eyes"and a.item and eyeCenter[(a.side or "")..a.item]
  if c then entry.eyeOffsetY=(a.center[2]-c.y)*v.scale end
  part.Parent=v.model
  -- A sparkle pick (WearableVariants finish row): its main piece moves on a garden pet only (WearableFinish).
  local finishRow=tinted and tint and Variants.ById[tint.id]
  -- A BASE row with a finish (Angel Wings: an egg-only base, no tint): the finish is the catalogue item's own (lane A),
  -- else its look's; every own-coloured piece of the item takes it (one soft Snow sparkle on each wing).
  if not finishRow and a.item and a.feature==nil and role=="own"then
   local item=Wearables.forPet(v.petId,math.huge).byId[a.item]
   if look or(item and item.variant~=true and item.finish)then finishRow=Wings.finishRow(item,a.item,a.color)end
  end
  if finishRow and finishRow.finish then
   entry.finish=finishRow.finish
   Attachments.finish().attach(part,finishRow,v.worldContext==true)
  end
  table.insert(v.pieces,entry);table.insert(handles,handle(part))
  if look and look.halo then haloFor=haloFor or a end
 end
 if haloFor then
  for _,h in ipairs(Attachments.halo(v,resolved,haloFor))do table.insert(handles,h)end
 end
 return handles
end

-- Angel Wings' halo (ROTATION-2-BRIEF 3): a ring of 8 short cylinders over the head top, on the Head channel so it turns
-- and nods with the head. Its own entries in v.pieces (role "attachment": PetPlayVisual.clearFeatures removes them with
-- the rows). A garden pet's halo bobs (AngelWings.track); a preview's stays posed. Returns the cleanup handles.
function Attachments.halo(v,resolved,row)
 local crown=Rules.anchorFrame(v.definition,"HatCrown",1)
 if not crown then return {}end
 local H=Wings.Halo
 local center=(crown.Position+Vector3.new(0,Wings.haloLift(resolved),0))*v.scale
 local handles,entries={},{}
 local color=Color3.fromHex(H.color)
 for i,segment in ipairs(Wings.haloSegments(v.scale))do
  local part=Instance.new("Part");part.Name="AngelHalo"..i;part.Shape=Enum.PartType.Cylinder
  part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false
  part.Material=Enum.Material.SmoothPlastic;part.Reflectance=H.reflectance;part.Color=color
  part.TopSurface=Enum.SurfaceType.Smooth;part.BottomSurface=Enum.SurfaceType.Smooth
  part.Size=segment.size
  local frame=CFrame.new(center)*segment.frame
  local entry={part=part,name=part.Name,colorRole="own",item=row.item,channel="Head",frame=frame,size=segment.size,
   role="attachment",slot=row.slot,color=color,faceBaseColor=color,faceBaseMaterial=part.Material,halo=true}
  part.Parent=v.model
  table.insert(v.pieces,entry);table.insert(entries,entry);table.insert(handles,handle(part))
 end
 Wings.track(v,entries)
 return handles
end

-- Studio-only check path: workspace attribute StudioPetWearables, e.g.
-- "Hat=flowercrown;Shirt=hoodie;Neck=bellcollar;EarPiercingL=starstud;EarPiercingR=starstud;Eyes=sparkle;Mouth=blep;Tail=heart".
-- Studio only; it overrides the saved wearables (hatching v10, the Wardrobe) while set.
local debug={revision=0,map=nil}
Attachments.debug=debug
function Attachments.parseDebug(text)
 if type(text)~="string"or text==""then return nil end
 local map={}
 for pair in string.gmatch(text,"[^;,]+")do
  local key,item=string.match(pair,"^%s*([%w_]+)%s*=%s*([%w_]+)%s*$")
  if key then map[key]=string.lower(item)end
 end
 return map
end
if RunService:IsStudio()and RunService:IsClient()then
 local function read()debug.map=Attachments.parseDebug(workspace:GetAttribute("StudioPetWearables"));debug.revision+=1 end
 workspace:GetAttributeChangedSignal("StudioPetWearables"):Connect(read)
 if workspace:GetAttribute("StudioPetWearables")~=nil then read()end
end
function Attachments.wearables(appearance)
 if debug.map then return debug.map end
 return type(appearance)=="table"and appearance.wearables or nil
end
return Attachments
