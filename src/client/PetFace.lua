-- Existing named face details only. No light, geometry or per-frame rig scan.
local Clock=require(script.Parent.HollowClock)
local Face={}
function Face.daylight()return Clock.lastDaylight or 1 end
function Face.paint(entry,worldContext,color,daylight)
 local role=entry.faceRole;if not role then return end
 local night=worldContext==true and daylight<.35
 local base=color or entry.faceBaseColor
 local tint=if night and role=="cheek"then Color3.new(base.R*.55,base.G*.55,base.B*.55)else base
 local material=if night then Enum.Material.Neon else entry.faceBaseMaterial
 if entry.faceColor~=tint then entry.part.Color=tint;entry.faceColor=tint end
 if entry.faceMaterial~=material then entry.part.Material=material;entry.faceMaterial=material end
end
-- Primitive material study: only the two broad surfaces emit. Adjacent limbs,
-- crown/chin planes, eyes, mouth and teeth retain authored shaded materials.
-- Palette storage stays untouched; each frame derives from the resolved color.
function Face.paintSurface(entry,visual,daylight)
    if entry.name~="Head"and entry.name~="Body"then return end
    local night=visual.worldContext==true and (if entry.nightSurface then daylight<.34 else daylight<.26)
    entry.nightSurface=night
    local base=entry.color
    local mix=math.clamp((.48-daylight)/.40,0,1)
    mix=mix*mix*(3-2*mix)
    local ovelle=visual.definition.id=="ovelle"
    local strength=if entry.name=="Head"then (if ovelle then .60 else .58)else (if ovelle then .45 else .43)
    local tint=if night then base:Lerp(Color3.new(base.R*strength,base.G*strength,base.B*strength),mix)else base
    local shadedHead=entry.name=="Head"and visual.nightTreatment=="shadedHead"
    if shadedHead and not entry.nightHeadLift then
        -- Candidate B is a bounded fixture option. Only this shaded head is
        -- adorned, so separate eyes, teeth and overlapping face pieces occlude it.
        local lift=Instance.new("Highlight")
        lift.Name="NightHeadLift";lift.Adornee=entry.part
        lift.DepthMode=Enum.HighlightDepthMode.Occluded
        lift.FillTransparency=.70;lift.OutlineTransparency=1
        lift.Parent=visual.model;entry.nightHeadLift=lift
    end
    if entry.nightHeadLift then
        local lift=entry.nightHeadLift
        if lift.FillColor~=base then lift.FillColor=base end
        lift.Enabled=shadedHead and night
    end
    if shadedHead then tint=base end
    local material=if night and not shadedHead then Enum.Material.Neon else Enum.Material.SmoothPlastic
    if entry.part.Color~=tint then entry.part.Color=tint end
    if entry.part.Material~=material then entry.part.Material=material end
end
return Face
