-- PBR owns bound MeshParts; unsupported/native surfaces use bounded role fills.
local Materials=require(script.Parent.PetMaterials)
local Night={DefaultTreatment="luminousVinyl"}
local function groupFor(visual,role)
 local groups=visual.nightGroups
 if not groups then groups={};visual.nightGroups=groups end
 local group=groups[role];if group then return group end
 local model=Instance.new("Model");model.Name=if role=="body"then "MainSurfaces"else "SecondarySurfaces";model.Parent=visual.model
 local fill=Instance.new("Highlight");fill.Name="Night"..model.Name;fill.Adornee=model;fill.DepthMode=Enum.HighlightDepthMode.Occluded
 fill.OutlineTransparency=1;fill.FillTransparency=1;fill.Enabled=false;fill.Parent=visual.model
 group={model=model,fill=fill};groups[role]=group;return group
end
function Night.paint(entry,visual,daylight)
 if Materials.paint(entry,visual,daylight)then return true end
 if entry.colorRole~="body"and entry.colorRole~="secondary"then return false end
 local base=entry.color or entry.originalColor or entry.part.Color
 local dusk=Materials.dusk(daylight)
 local selected=entry.renderHidden~=true and(entry.role~="charm"or(visual.charmVisible~=false and(entry.charmShape or "dot")==visual.renderCharmShape))
 local neon=visual.worldContext and entry.role=="charm"and selected and dusk>.001
 local rendered=if neon then Color3.new(base.R*(1-.60*dusk),base.G*(1-.60*dusk),base.B*(1-.60*dusk))else base
 local material=if neon then Enum.Material.Neon else entry.faceBaseMaterial or Enum.Material.SmoothPlastic
 if entry.part.Color~=rendered then entry.part.Color=rendered end
 if entry.part.Material~=material then entry.part.Material=material end
 if not visual.worldContext or entry.role=="charm"then
  if entry.part.Parent~=visual.model then entry.part.Parent=visual.model end
  return false
 end
 local group=groupFor(visual,entry.colorRole)
 if entry.part.Parent~=group.model then entry.part.Parent=group.model end
 local color=(visual.colors or {})[entry.colorRole]or base
 local opacity=if entry.colorRole=="body"then .30 else .28
 if group.fill.FillColor~=color then group.fill.FillColor=color end
 local transparency=1-opacity*dusk
 if group.fill.FillTransparency~=transparency then group.fill.FillTransparency=transparency end
 local enabled=dusk>.001
 if group.fill.Enabled~=enabled then group.fill.Enabled=enabled end
 return false
end
return Night
