-- One material owner. Template binding is not proof of processed GPU rendering.
-- Immutable maps are authored in the mounted pack; runtime writes only tint/strength.
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Config=require(script.Parent.PetMaterialConfig)
local Materials={};local Owner={};Owner.__index=Owner
local white=Color3.new(1,1,1)
local function release(entry)
 if entry.materialSurface then entry.materialSurface:Destroy();entry.materialSurface=nil;entry.materialProfile=nil end
 entry.materialTint=nil;entry.materialStrength=nil;entry.materialPartColor=nil
end
local function profile(entry)
 -- Authored textures (eye whites, the mouth) would be hidden by a finish surface.
 if entry.part and entry.part:IsA("MeshPart")and entry.part.TextureID~=""then return nil end
 if entry.role=="charm"then return "Charm"end
 if entry.faceRole=="spark"then return "Catchlight"end
 if entry.name=="EyeL"or entry.name=="EyeR"or entry.name=="Eye"then return "Eye"end
 if entry.colorRole=="body"or entry.colorRole=="secondary"then return "Body"end
 return nil
end
function Materials.dusk(daylight)
 local t=math.clamp(1-daylight,0,1);return t*t*(3-2*t)
end
function Materials.new(options)
 options=options or {}
 return setmetatable({templates=options.templates,twoToneTemplates=options.twoToneTemplates},Owner)
end
function Owner:begin()
 -- These are immutable, authored SurfaceAppearances. Raw URI callbacks and
 -- unparented ImageLabel.IsLoaded disagree with processed-map readiness.
 -- Bind the pack, retain real binding failures, and prove rendering natively.
 return self:status()
end
function Owner:status()
 local pack=self.templates or ReplicatedStorage:FindFirstChild("PetMaterials")
 return if pack then "AuthoredPackAvailable"else "TemplateUnavailable"
end
function Owner:paint(entry,visual,daylight)
 local key=profile(entry)
 if visual.materialsEnabled==false then
  release(entry)
  return false
 end
 if not key or entry.materialFailure or not entry.part:IsA("MeshPart")then return false end
 local pack=if self.templates then self.templates else ReplicatedStorage:FindFirstChild("PetMaterials")
 local templateKey=key
 if key=="Body"then
  local finish=visual.appearance and visual.appearance.finish or "standard"
  local candidate=Config.FinishProfiles[finish]
  local selected=candidate and pack and pack:FindFirstChild(candidate)
  if candidate~="Body"and selected and selected:IsA("SurfaceAppearance")and selected:GetAttribute("MaterialVersion")==Config.Version and selected:GetAttribute("MaterialProfile")==candidate and (selected:GetAttribute("NativeVerified")==true or visual.allowUnverifiedFinish==true)then templateKey=candidate end
 end
 local template=pack and pack:FindFirstChild(templateKey)
 -- Two-tone pets (PET-STYLE-GUIDE.md): body-role parts use a template whose
 -- ColorMap alpha is the shared UV gradient. Overlay shows the part Color
 -- (primary) where alpha is 0 and the surface tint (secondary) where it is 1.
 -- A missing or unverified variant falls back to the ordinary one-colour finish.
 local twoTone=false
 if key=="Body"and visual.twoTone==true and entry.colorRole=="body"then
  local twoPack=if self.twoToneTemplates then self.twoToneTemplates else ReplicatedStorage:FindFirstChild("PetMaterialsTwoTone")
  local name=Config.TwoToneProfiles[templateKey]
  local candidate=name and twoPack and twoPack:FindFirstChild(name)
  if candidate and name~="BodyTwoTone"and candidate:GetAttribute("NativeVerified")~=true and visual.allowUnverifiedFinish~=true then
   name="BodyTwoTone";candidate=twoPack:FindFirstChild(name)
  end
  if candidate and candidate:IsA("SurfaceAppearance")and candidate:GetAttribute("MaterialVersion")==Config.Version and candidate:GetAttribute("MaterialProfile")==name then
   template,templateKey,twoTone=candidate,name,true
  end
 end
 if not template or not template:IsA("SurfaceAppearance")or template:GetAttribute("MaterialVersion")~=Config.Version then release(entry);return false end
 local surface=entry.materialSurface
 if surface and entry.materialProfile~=templateKey then release(entry);surface=nil end
 if not surface or surface.Parent~=entry.part then
  surface=entry.part:FindFirstChildWhichIsA("SurfaceAppearance")
  if surface and(surface:GetAttribute("MaterialProfile")~=templateKey or surface:GetAttribute("MaterialVersion")~=Config.Version)then return false end
  if not surface then surface=template:Clone();surface.Name="PetFinish";surface.Parent=entry.part end
  entry.materialSurface=surface;entry.materialProfile=templateKey
  entry.materialTint=nil;entry.materialStrength=nil;entry.materialPartColor=nil
 end
 local base=entry.color or entry.faceBaseColor or entry.part.Color
 local values=Config.Profiles[if twoTone then "BodyTwoTone" else key]
 local strength=values.day+(values.night-values.day)*Materials.dusk(daylight)
 if visual.emissionEnabled==false or entry.renderHidden==true or(key=="Charm"and(visual.charmVisible==false or(entry.charmShape or "dot")~=(visual.renderCharmShape or "dot")))then strength=0 end
 -- Emission multiplies albedo; a neutral tint avoids applying the pigment twice.
 -- Two-tone: the part keeps the primary; the surface tint carries the secondary.
 local tint=if twoTone then(visual.secondaryColor or base)else base
 if entry.materialTint~=tint then surface.Color=tint;entry.materialTint=tint end
 if surface.EmissiveTint~=white then surface.EmissiveTint=white end
 if entry.materialStrength~=strength then surface.EmissiveStrength=strength;entry.materialStrength=strength end
 -- BasePart readback is byte-quantized; compare logical requests to avoid
 -- rewriting mixed pigment every frame because its float readback differs.
 if entry.materialPartColor~=base then entry.part.Color=base;entry.materialPartColor=base end
 if entry.part.Material~=Enum.Material.SmoothPlastic then entry.part.Material=Enum.Material.SmoothPlastic end
 if visual.nightGroups and entry.part.Parent~=visual.model then
  local old=entry.part.Parent;entry.part.Parent=visual.model
  local group=visual.nightGroups[entry.colorRole]
  if group and group.model==old and not old:FindFirstChildWhichIsA("BasePart")then
   group.fill:Destroy();group.model:Destroy();visual.nightGroups[entry.colorRole]=nil
  end
 end
 return true
end
local default=Materials.new()
function Materials.paint(entry,visual,daylight)
 local ok,bound=pcall(default.paint,default,entry,visual,daylight)
 if not ok then
  if entry.materialSurface then entry.materialSurface:Destroy();entry.materialSurface=nil end
  entry.materialFailure=tostring(bound);return false
 end
 return bound
end
function Materials.status()return default:status()end
function Materials.start()default:begin();return default:status()end
Materials.profile=profile
return Materials
