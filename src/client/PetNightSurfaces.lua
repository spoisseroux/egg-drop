-- Two grouped occluded fills retain the shaded material under each saved channel.
-- No per-part Highlights, lights, geometry clones, exposure or palette mutation.
local Palette=require(game:GetService("ReplicatedStorage").Shared.PetPalette)
local Night={DefaultTreatment="tonalRoleFill"}
local function prepare(visual)
 local groups={}
 for _,role in ipairs({"body","secondary"})do
  local model=Instance.new("Model");model.Name=if role=="body"then "MainSurfaces"else "SecondarySurfaces";model.Parent=visual.model
  local fill=Instance.new("Highlight");fill.Name="Night"..model.Name;fill.Adornee=model;fill.DepthMode=Enum.HighlightDepthMode.Occluded;fill.OutlineTransparency=1;fill.FillTransparency=1;fill.Enabled=false;fill.Parent=visual.model
  groups[role]={model=model,fill=fill}
 end
 for _,entry in ipairs(visual.pieces)do
  if entry.nightHeadLift then entry.nightHeadLift:Destroy();entry.nightHeadLift=nil end
  local group=groups[entry.colorRole]
  if group then entry.part.Parent=group.model end
 end
 visual.nightGroups=groups;return groups
end
function Night.paint(entry,visual,daylight)
 if entry.colorRole~="body"and entry.colorRole~="secondary"then return end
 local base=entry.color or entry.originalColor or entry.part.Color
 local treatment=if visual.nightTreatment=="groupedRoleFill"then "groupedRoleFill"else Night.DefaultTreatment
 local dusk=math.clamp((.50-daylight)/.50,0,1);dusk=dusk*dusk*(3-2*dusk)
 local tone=1
 if visual.worldContext and treatment=="tonalRoleFill"and visual.definition then
  if entry.name=="Body"then tone=1-.26*dusk
  elseif entry.name=="HandL"or entry.name=="HandR"then tone=1-.12*dusk end
 end
 local rendered=if tone<1 then Palette.tint(base,Color3.new(0,0,0),1-tone)else base
 local material=entry.faceBaseMaterial or Enum.Material.SmoothPlastic
 if entry.part.Color~=rendered then entry.part.Color=rendered end
 if entry.part.Material~=material then entry.part.Material=material end
 if not visual.worldContext then return end
 local groups=visual.nightGroups or prepare(visual)
 local colors=visual.colors or {};local charm=visual.charmVisible~=false;local charmShape=visual.renderCharmShape
 if visual.nightDaylight==daylight and visual.nightColors==colors and visual.nightCharm==charm and visual.nightStyle==treatment and visual.nightCharmShape==charmShape then return end
 visual.nightDaylight,visual.nightColors,visual.nightCharm,visual.nightStyle,visual.nightCharmShape=daylight,colors,charm,treatment,charmShape
 local active=if visual.nightFillActive then daylight<.48 else daylight<.44
 visual.nightFillActive=active
 for role,group in pairs(groups)do
  local color=colors[role]or base
  local opacity=if treatment=="groupedRoleFill"then (if role=="body"then .55 else .42)else (if role=="body"then .32 else .36)
  group.fill.FillColor=color;group.fill.FillTransparency=1-opacity*dusk;group.fill.Enabled=active and dusk>.001
 end
 for _,piece in ipairs(visual.pieces)do if piece.role=="charm"then
  local parent=if charm and(piece.charmShape or "dot")==charmShape then groups.secondary.model else visual.model
  if piece.part.Parent~=parent then piece.part.Parent=parent end
 end end
end
return Night
