-- One material owner. Template binding is not proof of processed GPU rendering.
-- Immutable maps are authored in the mounted pack; runtime writes only tint/strength.
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Config=require(script.Parent.PetMaterialConfig)
-- Customization Egg finish doses (slice 3): sheen stops and Jelly stages per pet.
local Look=require(ReplicatedStorage.Shared.LookEggCatalog)
local Materials={};local Owner={};Owner.__index=Owner
local white=Color3.new(1,1,1)
local function release(entry)
 if entry.materialSurface then entry.materialSurface:Destroy()end
 entry.materialSurface=nil;entry.materialProfile=nil
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
-- PetMaterials.rbxm also carries stale unverified copies of BodyGloss/BodyMatte/BodyMetal
-- under the same names, and replication order decides which FindFirstChild returns.
-- Prefer the NativeVerified copy of a name; otherwise the first one.
local templateCache=setmetatable({},{__mode="k"})
function Materials.template(pack,key)
 if not pack or not key then return nil end
 local cache=templateCache[pack]
 if not cache then
  cache={};templateCache[pack]=cache
  local function clear()table.clear(cache)end
  pack.ChildAdded:Connect(clear);pack.ChildRemoved:Connect(clear)
 end
 local found=cache[key]
 if found and found.Parent==pack and found.Name==key then return found end
 found=nil
 for _,child in ipairs(pack:GetChildren())do
  if child.Name==key then
   if child:GetAttribute("NativeVerified")==true then found=child;break end
   found=found or child
  end
 end
 cache[key]=found;return found
end
function Materials.dusk(daylight)
 local t=math.clamp(1-daylight,0,1);return t*t*(3-2*t)
end
-- Two-tone pets glow only after sunset: nothing while daylight is above .75,
-- then a smoothstep ramp to full glow at full night. Daylight follows the
-- real-time garden clock, so the fade lasts the whole dusk (about 2 hours).
-- The garden hour (Fable, GARDEN-HOUR-REVIEW-R1 fix 1): while it is on (hourOn true) the ramp stops at HourGlowCap, so
-- a white coat at the hour's night (daylight .12, ramp .93) no longer clips. Off: the ramp as it was.
Materials.HourGlowCap=.6
function Materials.nightGlow(daylight,hourOn)
 local t=math.clamp((.75-daylight)/.75,0,1);t=t*t*(3-2*t)
 if hourOn==true and t>Materials.HourGlowCap then return Materials.HourGlowCap end
 return t
end
-- HollowClock.hourOn (the hour and the Aero look painting it), required on first use; a seam for specs.
local Clock
function Materials.hourOn()
 Clock=Clock or require(script.Parent.HollowClock)
 return Clock.hourOn~=nil and Clock.hourOn()==true
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
local function validTemplate(template,name,allowUnverified)
 return template~=nil and template:IsA("SurfaceAppearance")and template:GetAttribute("MaterialVersion")==Config.Version
  and template:GetAttribute("MaterialProfile")==name and(template:GetAttribute("NativeVerified")==true or allowUnverified==true)
end
function Owner:jellyReady(visual)
 local pack=self.templates or ReplicatedStorage:FindFirstChild("PetMaterials")
 if not validTemplate(Materials.template(pack,"BodyJelly"),"BodyJelly",visual.allowUnverifiedFinish)then return false end
 if visual.twoTone then
  local two=self.twoToneTemplates or ReplicatedStorage:FindFirstChild("PetMaterialsTwoTone")
  if not validTemplate(Materials.template(two,"BodyTwoToneJelly"),"BodyTwoToneJelly",visual.allowUnverifiedFinish)then return false end
 end
 return true
end
-- The dose look (appearance.sheen -3..3, appearance.jellyStage 0..3). Out-of-cap stored values
-- clamp to the display stops (plan R6). Zero on both axes means no dose look (legacy finish).
function Materials.dose(appearance)
 if type(appearance)~="table"then return 0,0 end
 local sheen=if type(appearance.sheen)=="number"and appearance.sheen==appearance.sheen then math.clamp(math.round(appearance.sheen),-Look.SheenStops,Look.SheenStops)else 0
 local jelly=if type(appearance.jellyStage)=="number"and appearance.jellyStage==appearance.jellyStage then math.clamp(math.round(appearance.jellyStage),0,Look.JellyStops)else 0
 return sheen,jelly
end
local function twoToneName(key)
 return Config.TwoToneProfiles[key]or(if string.sub(key,1,9)=="BodySheen"then "BodyTwoTone"..string.sub(key,5)else nil)
end
-- The one-colour template key for a dose look: an unverified sheen stop falls back to the
-- nearest verified stop toward 0 (never the wrong direction, never an error). A Jelly stage at
-- sheen 0 wears the verified Jelly surface.
function Materials.doseProfile(pack,sheen,jelly,allowUnverified)
 local stop=sheen
 while stop~=0 do
  local name=Look.SheenProfiles[stop]
  if validTemplate(Materials.template(pack,name),name,allowUnverified)then return name end
  stop-=if stop>0 then 1 else -1
 end
 if jelly>0 and validTemplate(Materials.template(pack,"BodyJelly"),"BodyJelly",allowUnverified)then return "BodyJelly"end
 return "Body"
end
local definitionPieces=setmetatable({},{__mode="k"})
local function piecesOf(definition)
 local pieces=definitionPieces[definition]
 if not pieces then
  pieces={};for _,piece in ipairs(definition.pieces or {})do pieces[piece.name]=true end;definitionPieces[definition]=pieces
 end
 return pieces
end
function Materials.jellyAlpha(entry,visual)
 -- Dose look: the Jelly stage scales the per-part alpha on any bound body surface.
 local _,stage=Materials.dose(visual and visual.appearance)
 if stage>0 then
  if visual.materialsEnabled==false or entry.role~=nil or entry.faceRole~=nil or(entry.colorRole~="body"and entry.colorRole~="secondary")then return 0 end
  local surface=entry.materialSurface
  if entry.materialFailure~=nil or typeof(surface)~="Instance"or surface.Parent~=entry.part or not visual.definition then return 0 end
  return if piecesOf(visual.definition)[entry.name]then(Config.JellyAlphaByPart[entry.name]or 0)*(Config.JellyStageAlpha[stage]or 0)else 0
 end
 if not visual or not visual.appearance or visual.appearance.finish~="jelly"or visual.materialsEnabled==false
  or entry.role~=nil or entry.faceRole~=nil or(entry.colorRole~="body"and entry.colorRole~="secondary")
  or(entry.materialProfile~="BodyJelly"and entry.materialProfile~="BodyTwoToneJelly")then return 0 end
 local surface=entry.materialSurface
 if entry.materialFailure~=nil or typeof(surface)~="Instance"or surface.Parent~=entry.part
  or not validTemplate(surface,entry.materialProfile,visual.allowUnverifiedFinish)then return 0 end
 local definition=visual.definition;if not definition then return 0 end
 local pieces=piecesOf(definition)
 return if pieces[entry.name]then Config.JellyAlphaByPart[entry.name]or 0 else 0
end
function Materials.transparency(entry,visual,hidden)
 if hidden then return 1 end
 local base=entry.baseTransparency or 0;local alpha=Materials.jellyAlpha(entry,visual)
 return if alpha==0 then base else 1-(1-base)*(1-alpha)
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
 local sheen,jelly=Materials.dose(visual.appearance)
 if key=="Body"and(sheen~=0 or jelly~=0)then
  -- A pet's dose look wins over a legacy permanent finish (plan §4).
  templateKey=Materials.doseProfile(pack,sheen,jelly,visual.allowUnverifiedFinish)
 elseif key=="Body"then
  local finish=visual.appearance and visual.appearance.finish or "standard"
  if finish=="jelly"and(entry.role~=nil or not self:jellyReady(visual))then finish="standard"end
  local candidate=Config.FinishProfiles[finish]
  local selected=candidate and Materials.template(pack,candidate)
  if candidate~="Body"and selected and selected:IsA("SurfaceAppearance")and selected:GetAttribute("MaterialVersion")==Config.Version and selected:GetAttribute("MaterialProfile")==candidate and (selected:GetAttribute("NativeVerified")==true or visual.allowUnverifiedFinish==true)then templateKey=candidate end
 end
 local template=Materials.template(pack,templateKey)
 -- Two-tone pets (PET-STYLE-GUIDE.md): body-role parts use a template whose
 -- ColorMap alpha is the shared UV gradient. Overlay shows the part Color
 -- (primary) where alpha is 0 and the surface tint (secondary) where it is 1.
 -- A missing or unverified variant falls back to the ordinary one-colour finish.
 local twoTone=false
 if key=="Body"and visual.twoTone==true and entry.colorRole=="body"then
  local twoPack=if self.twoToneTemplates then self.twoToneTemplates else ReplicatedStorage:FindFirstChild("PetMaterialsTwoTone")
  local name=twoToneName(templateKey)
  local candidate=name and Materials.template(twoPack,name)
  if candidate and name~="BodyTwoTone"and candidate:GetAttribute("NativeVerified")~=true and visual.allowUnverifiedFinish~=true then
   name="BodyTwoTone";candidate=Materials.template(twoPack,name)
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
 -- The gift paint wipe's sweep (GardenPetVisual sets entry.wipeColor while it passes; nil the rest of the time).
 local base=entry.wipeColor or entry.color or entry.faceBaseColor or entry.part.Color
 local values=Config.Profiles[if twoTone then "BodyTwoTone" else key]
 local ramp=if twoTone then Materials.nightGlow(daylight,Materials.hourOn())else Materials.dusk(daylight)
 local strength=values.day+(values.night-values.day)*ramp
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
function Owner:paintSafely(entry,visual,daylight)
 local ok,bound=pcall(self.paint,self,entry,visual,daylight)
 if not ok then
  release(entry);entry.materialFailure=tostring(bound);return false
 end
 return bound
end
local default=Materials.new()
function Materials.paint(entry,visual,daylight)return default:paintSafely(entry,visual,daylight)end
function Materials.status()return default:status()end
function Materials.start()default:begin();return default:status()end
Materials.profile=profile
return Materials
