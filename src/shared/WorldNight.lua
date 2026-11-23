-- The garden hour's night (artifacts/world-pass-2026-11-22/GARDEN-HOUR-LOOK.md section 2, Fable 2026-11-23), shaped
-- like WorldAero and WorldDusk. Values only: GardenHour blends them and HollowClock paints the blend. Nothing here has
-- been seen in Studio yet; the cells marked [check] are Fable's best start and wait on her capture review.
-- The white Bear rule (look section 3) holds: Brightness >= 1.1, Ambient >= #566090, OutdoorAmbient >= #6E86C8,
-- ExposureCompensation 0 to .15, EnvironmentDiffuseScale <= .2, Bloom Intensity <= .18, Atmosphere Density <= .30.
local Night={}
local hex=Color3.fromHex

Night.Hour=22.5 -- the moon where the 10.5 sun is, so night shadows fall the way day shadows do
Night.Daylight=.12
Night.Lighting=table.freeze({
	ClockTime=Night.Hour,Brightness=1.25,ExposureCompensation=.1,
	Ambient=hex("#5E6A9C"),OutdoorAmbient=hex("#7890D0"),
	ColorShift_Top=hex("#BFD4FF"),ColorShift_Bottom=hex("#6FD8F0"),
	EnvironmentDiffuseScale=.2,EnvironmentSpecularScale=.25,ShadowSoftness=.7,
})
Night.Atmosphere=table.freeze({Density=.24,Offset=.1,Haze=.8,Glare=0,Color=hex("#5A6FB8"),Decay=hex("#2E3A78")})
Night.Grade=table.freeze({Brightness=.02,Contrast=.04,Saturation=.08,TintColor=hex("#E6EEFF")})
Night.Bloom=table.freeze({Intensity=.18,Size=20,Threshold=1.2})
Night.SunRays=table.freeze({Intensity=0,Spread=.5})
-- StarCount 1200 [check]: 0 if the night faces already carry painted stars.
Night.Sky=table.freeze({CelestialBodiesShown=true,SunAngularSize=12,MoonAngularSize=9,StarCount=1200})
Night.FaceSet="night"
Night.CloudColor=hex("#7E90C8") -- W7_Backdrop__cloud*
Night.Clouds=table.freeze({Cover=.5,Density=.3,Color=hex("#8FA2D8")}) -- workspace.Terrain Clouds
Night.GlowWarm=hex("#FFC96A") -- the glow_warm meshes (AeroWorld)
Night.PeakColor=hex("#56629A") -- [check] far peaks drop their texture for this flat colour
function Night.skyFaces(data)
	local sky=data and data.sky
	return sky and(sky.night or sky.day)
end
return table.freeze(Night)
