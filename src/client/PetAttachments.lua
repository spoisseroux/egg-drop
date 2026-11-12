-- Authored attachment meshes (horns and wings S1-S5, wearables) placed from the rig's
-- attachment template. Each part keeps its anchor's channel, so head turns, ear flicks,
-- arm swings and tail wags carry it. Rigs without a template keep the procedural features.
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Rules=require(ReplicatedStorage.Shared.PetAttachmentRules)
local Attachments={}
local rotation=CFrame.Angles(0,math.pi,0)

-- The template model, only for authored-mesh rigs whose every attachment resource is present.
function Attachments.template(v)
 local definition=v.definition
 if v.backend~="AuthoredMesh"or type(definition.attachments)~="table"or type(definition.attachmentTemplate)~="string"then return nil end
 local assets=v.attachmentAssets or ReplicatedStorage:FindFirstChild("PetAssets")
 local source=assets and assets:FindFirstChild(definition.attachmentTemplate)
 if not source or not source:IsA("Model")then return nil end
 for _,a in ipairs(definition.attachments)do
  local part=source:FindFirstChild("Bear__"..a.name)or source:FindFirstChild(a.name)
  if not part or not part:IsA("MeshPart")or part.MeshId==""or part.MeshSize.X<=0 then return nil end
 end
 return source
end

local function handle(part)return {part=part,destroy=function()part:Destroy()end}end

-- Adds one entry per shown attachment to v.pieces and returns the cleanup handles.
function Attachments.build(v,resolved,source)
 local marker=source:FindFirstChild("PawsOrigin")
 local pivot=if marker and marker:IsA("CFrameValue")then marker.Value else source:GetPivot()
 local handles={}
 for _,a in ipairs(resolved.show)do
  local template=source:FindFirstChild("Bear__"..a.name)or source:FindFirstChild(a.name)
  local part=template:Clone();part.Name=a.name
  part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=true
  part.Material=Enum.Material.SmoothPlastic
  if a.texture and v.definition.attachmentTextures then part.TextureID=v.definition.attachmentTextures[a.texture]or part.TextureID end
  local color=if a.colorRole=="own"then Color3.fromHex(a.color)else(v.colors[a.colorRole]or v.secondaryColor)
  part.Color=color
  local localCF=rotation*pivot:ToObjectSpace(template.CFrame)
  local frame=CFrame.new(localCF.Position*v.scale)*localCF.Rotation
  local side=a.side
  local entry={part=part,name=a.name,colorRole=if a.colorRole=="own"then "own"else a.colorRole,channel=a.channel,frame=frame,size=template.Size*v.scale,
   role=if a.feature then "feature"else "attachment",featureId=a.feature,slot=a.slot,attachment=a,color=color,faceBaseColor=color,faceBaseMaterial=part.Material,
   -- Piercings ride the ear flick; swapped tails wag; an alternate mouth gives way to the open "O".
   earSide=if a.slot=="EarPiercing"or a.slot=="Earring"then side else nil,tailWag=a.slot=="Tail"or nil,mouthAlt=a.slot=="Mouth"or nil}
  part.Parent=v.model
  table.insert(v.pieces,entry);table.insert(handles,handle(part))
 end
 return handles
end

-- Studio-only check path: workspace attribute StudioPetWearables, e.g.
-- "Hat=beanie;Shirt=tee;Neck=beads;EarPiercingL=ring;EarPiercingR=ring;Eyes=button;Mouth=o;Tail=arrow".
-- Never read in a live server; there is no shop or save for wearables yet.
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
