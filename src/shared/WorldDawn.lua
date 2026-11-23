-- The garden hour's dawn (artifacts/world-pass-2026-11-22/GARDEN-HOUR-LOOK.md section 2, Fable 2026-11-23), shaped
-- like WorldAero and WorldDusk. Values only: GardenHour blends them and HollowClock paints the blend. Nothing here has
-- been seen in Studio yet; Fable reviews captures before publish. R1 (GARDEN-HOUR-REVIEW-R1 fix 4, its own phase): Atmosphere
-- Color #FFE0D0 and Haze 1.8, Grade TintColor #FFEEE2, ExposureCompensation 0; Brightness stays 1.6.
local Dawn={}
local hex=Color3.fromHex

Dawn.Hour=7.1
Dawn.Daylight=.5
Dawn.Lighting=table.freeze({
	ClockTime=Dawn.Hour,Brightness=1.6,ExposureCompensation=0,
	Ambient=hex("#86889C"),OutdoorAmbient=hex("#A0B0CC"),
	ColorShift_Top=hex("#FFE2C4"),ColorShift_Bottom=hex("#A8ECF0"),
	EnvironmentDiffuseScale=.2,EnvironmentSpecularScale=.2,ShadowSoftness=.6,
})
Dawn.Atmosphere=table.freeze({Density=.3,Offset=.1,Haze=1.8,Glare=.3,Color=hex("#FFE0D0"),Decay=hex("#FFC9A8")})
Dawn.Grade=table.freeze({Brightness=0,Contrast=.05,Saturation=.12,TintColor=hex("#FFEEE2")})
Dawn.Bloom=table.freeze({Intensity=.15,Size=18,Threshold=1.35})
Dawn.SunRays=table.freeze({Intensity=.04,Spread=.55})
Dawn.Sky=table.freeze({CelestialBodiesShown=true,SunAngularSize=14,MoonAngularSize=0,StarCount=0})
Dawn.FaceSet="day"
Dawn.CloudColor=hex("#FFE6DC") -- W7_Backdrop__cloud*
Dawn.Clouds=table.freeze({Cover=.5,Density=.3,Color=hex("#FFE6DC")}) -- workspace.Terrain Clouds
Dawn.GlowWarm=hex("#FFC96A") -- the glow_warm meshes (AeroWorld)
Dawn.PeakColor=nil -- far peaks keep their texture
function Dawn.skyFaces(data)return data and data.sky and data.sky.day end
return table.freeze(Dawn)
