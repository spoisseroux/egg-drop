-- The Frutiger Aero "Medium" values (WORLD-PLAN-2026-11-22 section 9, "Medium, exact"), shaped like WorldDusk.
-- Values only: HollowClock paints the light while AeroWorld holds it as the clock's look, and AeroWorld paints the
-- surfaces. Keep every number in step with the plan's table.
local Aero={}
local hex=Color3.fromHex

-- Light
Aero.Hour=10.5
Aero.Daylight=.9
Aero.Lighting=table.freeze({
	-- The plan's 2.4 and .4 washed the pale pets to flat white (Studio 2026-11-22); these keep the Bear's muzzle.
	ClockTime=Aero.Hour,Brightness=1.85,ExposureCompensation=0,
	Ambient=hex("#7C8894"),OutdoorAmbient=hex("#8CAAC8"),
	ColorShift_Top=hex("#FFF6E0"),ColorShift_Bottom=hex("#BFE4FF"),
	-- Pets and water rely on the global specular scale.
	EnvironmentDiffuseScale=.2,EnvironmentSpecularScale=.2,ShadowSoftness=.5,
})
Aero.Atmosphere=table.freeze({Density=.28,Offset=.1,Haze=1.2,Glare=.2,Color=hex("#CFEFFF"),Decay=hex("#8FCBF5")})
Aero.Grade=table.freeze({Brightness=0,Contrast=.05,Saturation=.12,TintColor=hex("#F6FBFF")})
-- Not the plan's section 5 value (.35): marble haloed at .28 in the 2026-11-13 QA.
Aero.Bloom=table.freeze({Intensity=.18,Size=20,Threshold=1.3})
Aero.SunRays=table.freeze({Intensity=.03,Spread=.5})
Aero.Sky=table.freeze({CelestialBodiesShown=true,SunAngularSize=12,MoonAngularSize=0,StarCount=0})
Aero.FaceSet="day"
Aero.CloudColor=hex("#FFFFFF") -- W7_Backdrop__cloud*, painted by HollowClock.backdrop
Aero.Clouds=table.freeze({Cover=.5,Density=.3,Color=hex("#FFFFFF")})
function Aero.skyFaces(data)return data and data.sky and data.sky[Aero.FaceSet]end

-- Surfaces, by the material after "__" in a world mesh's name. Tint is SurfaceAppearance.Color (it multiplies);
-- the rest are properties of the part. dirt_path, pebble_bed and bark stay as they are.
Aero.Surfaces=table.freeze({
	grass={Tint=hex("#F0FFD6")},
	meadow={Tint=hex("#E4FFC8")},
	foliage={Tint=hex("#E6FFE0")},
	cliff_rock={Tint=hex("#E2EAF0")},
	boulder_rock={Tint=hex("#E2EAF0")},
	marble={Reflectance=.06},
	marble_smooth={Reflectance=.12},
	trim={Reflectance=.18},
	-- Water stays opaque: transparent, it sorted through pet heads.
	water_stream={Reflectance=.22},
	water_pool={Reflectance=.22},
	water={Reflectance=.22},
	glow_warm={Color=hex("#FFE08A")},
	glow_aqua={Color=hex("#4FE6FF")},
	glow_pink={Color=hex("#C4F060")},
	cloud={Color=hex("#FFFFFF")},
	foam={Color=hex("#FFFFFF")},
	bubble={Color=hex("#DEF3FF"),Transparency=.55,Reflectance=.2},
})
-- Scrolling Texture layers (LoungeWorldV7Art.WaterSkins) by layer name, then by the water under them.
Aero.Skins=table.freeze({
	FlowSkin={
		water_stream={Color3=hex("#3CC8F0"),Transparency=.42},
		water_pool={Color3=hex("#7FE0FF"),Transparency=.5},
		water={Color3=hex("#7FE0FF"),Transparency=.5},
	},
	FlowGlint={water_stream={Color3=hex("#FFFFFF"),Transparency=.6}},
})
-- Beams and emitters under the room's WaterFlow folder.
Aero.Falls=ColorSequence.new(hex("#DDF6FF"))
Aero.Spray=table.freeze({Splash=ColorSequence.new(hex("#F4FCFF")),Mist=ColorSequence.new(hex("#E9F8FF"))})
-- foliage_blossom. Pink cannot multiply to green, so both drop the SurfaceAppearance and texture for flat smooth crowns.
-- (A textured crown needs a world export.)
Aero.CrownKind="foliage_blossom"
Aero.Crowns=table.freeze({
	-- Fabric rendered olive (Studio 2026-11-22). World pass 1 (Fable, 2026-11-22): a full-colour lime leaf map whose mean is
	-- #8FD63F (assets/world/lime-leaf.png) on the crown's TextureID, with the part white so it shows as drawn.
	lime={Flat=true,Color=hex("#8FD63F"),Material=Enum.Material.SmoothPlastic,
		Texture="rbxassetid://127425168647805",TextureColor=Color3.new(1,1,1)},
	coral={Flat=true,Color=hex("#F2545B"),Material=Enum.Material.SmoothPlastic}, -- as a tint on the leaf texture it rendered near black
})

-- Additions. Draw calls at worst, all on screen at once: dome 1, lips 3, glints 4 = 8, plus the waterfall layers below
-- (14 at Tumble Falls, only within 120 studs of it; 8 at budget level 1). Station sizes are measured on
-- assets/world/world-v7.fbx: the egg nest is three round steps (radius 3.4 / 2.8 / 2.2, tops 4.4 / 4.6 / 4.9) with the
-- egg and its leaves inside 2 studs up to y 7.5. The kiosk is square, so it has no lip.
Aero.MaxLips,Aero.MaxGlints,Aero.MaxGlintsLive=6,4,24
Aero.Dome=table.freeze({center=Vector3.new(-31,5.6,-11),diameter=4.2,Color=hex("#CFF4FF"),Transparency=.7,Reflectance=.15})
-- A thin white disc inside each round step, standing this far out of its side: only the rim shows.
Aero.Lip=table.freeze({Color=hex("#FFFFFF"),Reflectance=.35,thickness=.12,out=.08})
Aero.Lips=table.freeze({
	{name="Eggs",center=Vector3.new(-31,4.28,-11),radius=3.4},
	{name="Journal",center=Vector3.new(-17,4.32,-15),radius=2.75},
	{name="ArrivalDais",center=Vector3.new(96,4.16,66),radius=4.3},
})
-- x, z, width, depth: the four finds lawns of section 2.
Aero.Glints=table.freeze({{72,75,32,10},{32.5,-18.5,25,13},{-87.5,21.5,25,27},{-72.5,-42.5,25,25}})
Aero.GlintSize=.25
Aero.GlintTexture="rbxasset://textures/particles/sparkles_main.dds"
Aero.GlintRate,Aero.GlintLife=3,2 -- at most 6 alive per lawn

-- Waterfall layers, step 1 (artifacts/world-pass-2026-11-22/WATERFALL-LOOK.md; AeroFalls builds them from
-- WorldV7Data.beams.sheets). Frame per fall: n its normal, t = n turned flat (Tumble t (.707, 0, .707)), "sheet" its
-- width. The server's WaterFlow beams and emitters stay as they are: they are the back sheet.
-- Draws near Tumble: strands 4, ribbons 2, lips 2, foam 2, rings 1, mist 2, rainbow 1 = 14 (Opus budget, 2026-11-23:
-- only while the camera is within Radius of the falls). Level 1 keeps only `Level1` = 8: no rainbow, one strand a
-- tier, no ledge foam or mist, no rings, no Sky Falls. Level 2 and Reduced Motion: none of them.
local function keys(list)
	local out={}
	for _,point in ipairs(list)do table.insert(out,NumberSequenceKeypoint.new(point[1],point[2]))end
	return NumberSequence.new(out)
end
Aero.Waterfall=table.freeze({
	Radius=120,MistKeepOut=16,RainbowDaylight=.5,
	PoolTop=3.2, -- the pool's water top (world-v7-walk surface), where the lower sheet ends
	Tiers={Water_TumbleFalls_Upper="Upper",Water_TumbleFalls_Lower="Lower"},
	Sky="Water_SkyFalls",
	Textures=table.freeze({Strand="rbxassetid://136221967090040",Ribbon="rbxassetid://101983518173947",
		Foam="rbxassetid://134089185354561",Ripple="rbxassetid://123065684226119",Rainbow="rbxassetid://129354894959810",
		Mist="rbxasset://textures/particles/smoke_main.dds"}),
	Level1=table.freeze({StrandA=true,Ribbon=true,Lip=true,Foam=true,Mist=true}),
	-- grow: added to the sheet's width (scale multiplies it first); out along n; shift along t.
	Strands=table.freeze({
		{name="StrandA",scale=1,grow=1,out=.15,shift=0,length=20,skyLength=28,speed=.55,Color=hex("#3CC8F0"),
			Transparency=keys({{0,.6},{.08,.35},{.85,.35},{1,.8}})},
		{name="StrandB",scale=.7,grow=0,out=.3,shift=.6,length=13,speed=1.1,Color=hex("#DDF6FF"),
			Transparency=keys({{0,.7},{.08,.45},{.85,.45},{1,.85}})},
	}),
	Ribbon=table.freeze({scale=1,grow=1.6,out=.45,shift=0,length=16,skyLength=22,speed=1,Color=hex("#FFFFFF"),LightEmission=.25,
		Transparency=keys({{0,.5},{.05,.2},{.85,.2},{1,.7}})}),
	-- Along t at a tier's top, this far out along n.
	Lips=table.freeze({Upper={length=8.8,thickness=.9,out=.3},Lower={length=11.8,thickness=1.1,out=.3}}),
	LipLook=table.freeze({Color=hex("#FFFFFF"),Reflectance=.2}),
	-- box: along t, up, along n. Pool boxes sit at I + n * out, at PoolTop + up; ledge boxes at the Lower top.
	Foam=table.freeze({
		{name="Foam",at="pool",box=Vector3.new(12,.6,2.5),out=1,up=.3,rate=16,rate1=8,
			Size=keys({{0,1},{.3,1.9},{1,1.3}})},
		{name="LedgeFoam",at="ledge",box=Vector3.new(10.5,.5,2),out=.6,up=0,rate=8,
			Size=keys({{0,.8},{.3,1.5},{1,1}})},
	}),
	FoamLook=table.freeze({Life=NumberRange.new(.7,1.1),Speed=NumberRange.new(2,4),Spread=35,Acceleration=Vector3.new(0,-9,0),
		Drag=1,RotSpeed=NumberRange.new(-30,30),Transparency=keys({{0,.15},{.6,.35},{1,1}}),
		Color=ColorSequence.new(hex("#FFFFFF"),hex("#F4FCFF")),LightEmission=.2}),
	Rings=table.freeze({out=2.5,up=.08,rate=1.25,life=2.4,speed=.05,Size=keys({{0,4},{1,9}}),
		Transparency=keys({{0,.3},{.7,.6},{1,1}})}),
	Mist=table.freeze({
		{name="Mist",at="pool",box=Vector3.new(10,1,3),out=1.5,up=2,rate=3,rate1=1.5,Size=keys({{0,3},{1,6.5}})},
		-- Just above the ledge roll.
		{name="LedgeMist",at="ledge",box=Vector3.new(8,1,2),out=.3,up=1.2,rate=2,Size=keys({{0,2.5},{1,5}})},
	}),
	SkyMist=table.freeze({box=Vector3.new(10,1,3),out=1.5,up=-3,rate=3}), -- 3 studs under the lip, pool settings
	MistLook=table.freeze({Life=NumberRange.new(2.5,3.5),Speed=NumberRange.new(1,1.6),Spread=15,ZOffset=-2,
		RotSpeed=NumberRange.new(-12,12),Transparency=keys({{0,1},{.25,.8},{1,1}}),Color=ColorSequence.new(hex("#E9F8FF"))}),
	-- Feet 7 studs either side of I along t, 2 out along n, 1 above the pool; both axes up, so the curve sizes arc it
	-- 14 wide and 6 high.
	Rainbow=table.freeze({half=7,out=2,up=1,width=1.6,curve=8,segments=16,LightEmission=.3,
		Transparency=keys({{0,1},{.2,.84},{.5,.8},{.8,.84},{1,1}})}),
})

-- "W7_Water__cloud", "W7_Backdrop__cloud_2" -> "cloud"; nil for anything else (collision tiles, pets, props).
function Aero.kind(name)
	if string.sub(name,1,3)~="W7_"then return nil end
	local kind=string.match(name,"__(.+)$")
	return kind and(string.gsub(kind,"_%d+$",""))
end
return table.freeze(Aero)
