-- The locked dusk look (batch 2026-11-13, W1; FeatureFlags.DayNight=false). One source for
-- the server's initial Lighting (LoungeWorldV7Art.lighting) and the client clock
-- (HollowClock.environment), so both sides paint the same golden-hour garden: a low warm
-- key light, soft pink and peach haze, a pink cloud sea below the island and saturated
-- grass. Mood reference only (artifacts/batch-2026-11-13/reference/spencer-9-dusk-mood.webp).
local Dusk={}

-- Clock state reported while the cycle is off. Daylight .55 sits in the dusk band the
-- rest of the game already reads (lamps glow at half strength, no night faces,
-- no fireflies, the night focus key stays off).
Dusk.Hour=16.9
Dusk.Daylight=.55

Dusk.Lighting=table.freeze({
	ClockTime=Dusk.Hour,
	Brightness=2.6,
	ExposureCompensation=.08,
	Ambient=Color3.fromHex("#9C8698"),
	OutdoorAmbient=Color3.fromHex("#B89CA8"),
	ColorShift_Top=Color3.fromHex("#FFD49A"),
	ColorShift_Bottom=Color3.fromHex("#E6A2BE"),
	-- Pets and water rely on the global specular scale (GardenGreyboxWorld spec).
	EnvironmentDiffuseScale=.35,
	EnvironmentSpecularScale=.2,
	ShadowSoftness=.55,
})
Dusk.Atmosphere=table.freeze({
	Density=.26,Offset=.12,Haze=1.4,Glare=.45,
	Color=Color3.fromHex("#FFD2B8"),Decay=Color3.fromHex("#E59CC2"),
})
Dusk.Grade=table.freeze({Brightness=0,Contrast=.06,Saturation=.14,TintColor=Color3.fromHex("#FFF1E4")})
-- QA 2026-11-13: bloom turned well down (was Intensity .28, Size 24, Threshold 1.05): the
-- white marble, foam and lit grass haloed and blew out. Only near-white highlights glow now.
Dusk.Bloom=table.freeze({Intensity=.12,Size=16,Threshold=1.4})
Dusk.SunRays=table.freeze({Intensity=.035,Spread=.55})
-- The engine draws the low sun over the painted sky, so the sun always sits where the
-- key light comes from; the painted faces carry only a broad golden glow.
Dusk.Sky=table.freeze({CelestialBodiesShown=true,SunAngularSize=16,MoonAngularSize=0,StarCount=0})
-- Backdrop cloud sea (W7_Backdrop__cloud*): untextured, painted pink in the warm light.
Dusk.CloudColor=Color3.fromHex("#F6C2D8")

-- Painted dusk faces once uploaded (Data.sky.dusk); the day faces until then.
function Dusk.skyFaces(data)
	local sky=data and data.sky
	if not sky then return nil end
	return sky.dusk or sky.day
end

local function find(lighting,className,name)
	local item=if name then lighting:FindFirstChild(name)else lighting:FindFirstChildOfClass(className)
	if item and item:IsA(className)then return item,false end
	item=Instance.new(className)
	if name then item.Name=name end
	return item,true
end

-- Writes every dusk property. Creates the Atmosphere, SproutHollowGrade, HollowBloom,
-- HollowSunRays and WorldSky when missing (the server's call replicates them).
function Dusk.apply(lighting,data)
	for key,value in pairs(Dusk.Lighting)do lighting[key]=value end
	local air,newAir=find(lighting,"Atmosphere",nil)
	for key,value in pairs(Dusk.Atmosphere)do air[key]=value end
	if newAir then air.Parent=lighting end
	local grade,newGrade=find(lighting,"ColorCorrectionEffect","SproutHollowGrade")
	for key,value in pairs(Dusk.Grade)do grade[key]=value end
	if newGrade then grade.Parent=lighting end
	local bloom,newBloom=find(lighting,"BloomEffect","HollowBloom")
	for key,value in pairs(Dusk.Bloom)do bloom[key]=value end
	if newBloom then bloom.Parent=lighting end
	local rays,newRays=find(lighting,"SunRaysEffect","HollowSunRays")
	for key,value in pairs(Dusk.SunRays)do rays[key]=value end
	if newRays then rays.Parent=lighting end
	local sky,newSky=find(lighting,"Sky","WorldSky")
	for key,value in pairs(Dusk.Sky)do sky[key]=value end
	local faces=Dusk.skyFaces(data)
	if faces and sky:GetAttribute("FaceSet")~="dusk"then
		for _,face in ipairs({"Bk","Dn","Ft","Lf","Rt","Up"})do sky["Skybox"..face]=faces[face]end
		sky:SetAttribute("FaceSet","dusk")
	end
	if newSky then sky.Parent=lighting end
	return sky
end

return table.freeze(Dusk)
