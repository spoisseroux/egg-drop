-- The Frutiger Aero "Medium" values (WORLD-PLAN-2026-11-22 section 9, "Medium, exact"), shaped like WorldDusk.
-- Values only: HollowClock paints the light while AeroWorld holds it as the clock's look, and AeroWorld paints the
-- surfaces. Keep every number in step with the plan's table.
local Aero={}
local hex=Color3.fromHex
local LifeArt=require(script.Parent.LifeArt)

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
-- the rest are properties of the part. dirt_path and bark stay as they are.
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
	-- LOOK-R3 1: the pool (and the stream, so they match) on a calm teal tile with a broken light net, not the cobalt
	-- water map (scripts/draw_aero_r3_textures.py pool-aero, 14 studs like the part's UVs). Drawn darker than it shows:
	-- the Aero sun lifts it about 1.2 x green and 1.3 x blue (Studio r5).
	-- LOOK-R3 round 6: the pebble bed peeks above the waterline at the pool rims as a saturated blue strip; tinted, it
	-- renders as the pool's teal.
	pebble_bed={Tint=Color3.new(.98,1,.83)},
	water_stream={Reflectance=.22,TextureID="rbxassetid://135229051638910"},
	water_pool={Reflectance=.22,TextureID="rbxassetid://135229051638910"},
	water={Reflectance=.22},
	glow_warm={Color=hex("#FFE08A")},
	glow_aqua={Color=hex("#4FE6FF")},
	glow_pink={Color=hex("#C4F060")},
	cloud={Color=hex("#FFFFFF")},
	foam={Color=hex("#FFFFFF")},
	bubble={Color=hex("#DEF3FF"),Transparency=.55,Reflectance=.2},
	-- WORLD-PLAN slice 9: the props' palette at saturation 1.0, not the dusk grade's 1.1 (scripts/draw_aero_palette.py;
	-- the island's own map is bound to the native collision checkpoint, so the swap is here).
	palette={TextureID="rbxassetid://121108587763392"},
})
-- Scrolling Texture layers (LoungeWorldV7Art.WaterSkins) by layer name, then by the water under them.
-- Fable R5 / beta 14 W3 row 2: named parts that take their own surface before their kind's (an ordered prefix list).
-- The five arrival chimes: the Aero palette at saturation x .75 (scripts/draw_aero_palette.py palette-chimes).
Aero.Named=table.freeze({
	table.freeze({prefix="W7_Chime_",kind="palette",surface=table.freeze({TextureID="rbxassetid://97924490156376"})}),
	-- Fable cliff-den review fixes 4 to 6 (the beta's sculpt, W7_CD_ names only; live never has them): the Play Den's
	-- floor and walls darker and warmer so its lamps and toys lead, and the carved crystals (the cave's glow-caps) amber
	-- instead of lemon. The garden's own dirt, rock and crystals keep their surfaces.
	table.freeze({prefix="W7_CD_PlayDen__dirt_path",kind="dirt_path",surface=table.freeze({Tint=hex("#B8A898")})}),
	table.freeze({prefix="W7_CD_PlayDen__cliff_rock",kind="cliff_rock",surface=table.freeze({Tint=hex("#A8957E")})}),
	-- Beta 18 (known: the crystals too bright): at #E8C468 the Neon still read lemon with a bloom on the lawn (R3); a
	-- darker, warmer amber (relative luminance about 60% lower), so they glow under the Aero bloom threshold: markers, not lamps.
	table.freeze({prefix="W7_CD_Crystals__glow_pink",kind="glow_pink",surface=table.freeze({Color=hex("#A07A3C")})}),
})
function Aero.namedSurface(name,kind)
	for _,entry in ipairs(Aero.Named)do
		if entry.kind==kind and string.sub(name,1,#entry.prefix)==entry.prefix then return entry.surface end
	end
	return nil
end
Aero.Skins=table.freeze({
	FlowSkin={
		-- LOOK-R3 1 (Studio r5): the stream takes the pool's glint too, so pool and stream match in the hub.
		water_stream={Texture="rbxassetid://82414579008999",StudsPerTileU=9,StudsPerTileV=9,Color3=hex("#E4F7FA"),Transparency=.72},
		-- LOOK-R3 1: a sparse glint layer over the new pool tile (at .15 a colour wash would hide it), 9 studs so it never
		-- sits in step with the 14-stud base.
		water_pool={Texture="rbxassetid://82414579008999",StudsPerTileU=9,StudsPerTileV=9,Color3=hex("#E4F7FA"),Transparency=.72},
		water={Color3=hex("#7FE0FF"),Transparency=.5},
	},
	-- The stream's second layer drew the cobalt water map at .6 (white tint keeps it blue): the glint at 6 studs instead.
	FlowGlint={water_stream={Texture="rbxassetid://82414579008999",StudsPerTileU=6,StudsPerTileV=6,Color3=hex("#FFFFFF"),Transparency=.72}},
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

-- Additions. Draw calls at worst, all on screen at once: dome 1, lips 3, glints 4 = 8 by day (fireflies 5 instead at
-- night with the garden hour on, = 9; glints and fireflies are never on together), plus the waterfall layers below
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
-- With the garden hour on (GardenHour), dew glints only while its daylight is above this (day; GARDEN-HOUR-LOOK 5).
-- Off, they are as before: always, but for Reduced Motion.
Aero.GlintDaylight=.7

-- Fireflies (GARDEN-HOUR-LOOK 5, v7): only with the garden hour on, spawning while its daylight is under Spawn, at the
-- full count from Full down; none under Reduced Motion. One emitter an area (5 draws): 2 on each finds lawn and 4 on the
-- stream bank = 12 alive at most; level 1 halves them (6); level 2 drops the additions. Each area is a box `Low` to
-- `Low + Band` studs over the ground at its centre, and a firefly drifts up to `Reach` studs from where it starts
-- (Speed with Drag: Speed / (Drag ln 2)), so it stays 1.5 to 4 studs up. The boxes are trimmed from the Glints lawns
-- to stay at least Keep.water studs from every WorldV7Data.wet box and Keep.station studs from every station, rest,
-- bridge and the nest (AeroFalls.spec measures it); an area is off while the camera is within CameraKeepOut + Reach
-- of its box (the particles fade, never cleared).
Aero.Fireflies=table.freeze({
	Spawn=.3,Full=.12,
	-- Beta 12 QA L1 (GARDEN-LIFE-NEST-LOOK 1): the soft round dot (LifeArt fireflyDot; the glint sparkle until it is
	-- uploaded), .6 studs (was .35; .45 if it reads as a blob at night).
	Color=hex("#E8FF8A"),Size=.6,LightEmission=1,
	Texture=LifeArt.id("fireflyDot"),
	Life=table.freeze({4,6}),Fade=1,Pulse=1.8, -- seconds; Fade at each end, the brightness pulse's period
	Speed=.6,Drag=.45,Reach=2,Low=1.5,Band=.5,
	CameraKeepOut=6,
	Keep=table.freeze({water=3,station=10}),
	-- x, z, width (along x before the yaw), depth, yaw, alive at level 0, alive at level 1.
	Areas=table.freeze({
		table.freeze({name="South",x=66,z=75,width=16,depth=8,yaw=0,count=2,count1=1}),
		table.freeze({name="East",x=43,z=-16,width=5,depth=12,yaw=0,count=2,count1=1}),
		table.freeze({name="West",x=-89,z=18,width=8,depth=14,yaw=0,count=2,count1=1}),
		table.freeze({name="Grove",x=-66,z=-35,width=8,depth=8,yaw=0,count=2,count1=1}),
		table.freeze({name="Bank",x=12,z=46,width=12,depth=3,yaw=.785,count=4,count1=2}),
	}),
})

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
	-- RainbowDaylight .7 (GARDEN-HOUR-LOOK 5): golden is .55 and would show it. Aero alone reads .9, so day keeps it.
	Radius=120,MistKeepOut=16,RainbowDaylight=.7,
	PoolTop=3.2, -- the pool's water top (world-v7-walk surface), where the lower sheet ends
	Tiers={Water_TumbleFalls_Upper="Upper",Water_TumbleFalls_Lower="Lower"},
	Sky="Water_SkyFalls",
	Textures=table.freeze({Strand="rbxassetid://136221967090040",Ribbon="rbxassetid://101983518173947",
		Foam="rbxassetid://134089185354561",Ripple="rbxassetid://123065684226119",Rainbow="rbxassetid://129354894959810",
		Mist="rbxasset://textures/particles/smoke_main.dds"}),
	Level1=table.freeze({StrandA=true,Ribbon=true,Lip=true,Foam=true,Mist=true}),
	-- LOOK-R2 2 (Fable, 2026-11-23): Tumble's white-water stack while the world kit stands (AeroFalls.kitStack). Drawn maps:
	-- scripts/draw_aero_falls_textures.py. Speeds are texture lengths per second (studs per second / length). Draws 9,
	-- level 1 keeps FlowA, Apron and BoilPool (4 with both FlowA tiers); Reduced Motion and level 2: none.
	Kit=table.freeze({
		Textures=table.freeze({White="rbxassetid://127390802678159",Veil="rbxassetid://138106096840651",
			Foam="rbxassetid://73367773850066",Spray="rbxassetid://90482640070809",Speck="rbxassetid://119614715171256"}),
		-- LOOK-R2 rounds 3 and 4: Flow A wider and nearly opaque, Flow B stronger; both straight and flat, just in front of
		-- the chutes' furthest point (bow .5 + .05 + ledge kink .3): any nearer and the chutes cut bands through them.
		FlowA=table.freeze({across=true,scale=1,grow=.6,out=1,shift=0,length=26,speed=14/26,Color=hex("#F4FCFF"),LightEmission=.2,
			Texture="rbxassetid://127390802678159",Transparency=keys({{0,.65},{.12,.3},{.9,.3},{1,.5}})}), -- Fable R6: +.3 so the static bands read through
		FlowB=table.freeze({across=true,scale=1,grow=.8,out=1.2,shift=.7,length=17,speed=19/17,Color=hex("#FFFFFF"),LightEmission=.15,
			Texture="rbxassetid://138106096840651",Transparency=keys({{0,.9},{.08,.5},{.9,.5},{1,.9}})}), -- Fable R6: +.3
		-- Flat on the pool, flowing out along n from `from` to `to` studs off the foot.
		-- LOOK-R3 1: darker water at the foot, a static flat beam under the Apron (foot-shade: row 0 at the foot). The ledge
		-- pool gets a smaller one, dropped at level 1.
		-- LOOK-R4 round 2: the kit's foam part (rolls, lips, apron) sits in the cliff's shade; a small white emissive lift on
		-- its SurfaceAppearance keeps it whiter than the water. Written by AeroKit.build on the cloned part.
		FoamGlow=table.freeze({Strength=.3,Tint=hex("#FFFFFF")}), -- the mask (the atlas white block) is on the template
		-- Fable R5: soft mist cards, camera-facing, at the foot (3, about 6 wide) and over the step's rock lip (1): `along`
		-- across the sheet, `out` in front of it, from `up` to `up + tall`. Static (no TextureSpeed); level1 per card.
		MistCards=table.freeze({Texture="rbxassetid://108518466669868",Color=hex("#EEF6FA"),Transparency=.6,
			Cards=table.freeze({
				table.freeze({at="pool",along=-3.4,out=1.4,up=-.2,tall=3,width=6,level1=true}),
				table.freeze({at="pool",along=.2,out=1.8,up=-.2,tall=3.4,width=6.5,level1=true}),
				table.freeze({at="pool",along=3.3,out=1.3,up=-.2,tall=2.8,width=5.5,level1=false}),
				table.freeze({at="ledge",along=0,out=.9,up=-.3,tall=2,width=6,level1=false}),
			})}),
		PoolShade=table.freeze({Texture="rbxassetid://135109259637937",Color=hex("#1F6F8A"),Transparency=.3,up=.03,
			pool=table.freeze({width=12,out=5}),ledge=table.freeze({width=7,out=2.5})}),
		Apron=table.freeze({from=.5,to=7.5,up=.06,width0=9,width1=9.5,length=7,speed=1.5/7,Color=hex("#FFFFFF"),
			Transparency=keys({{0,.25},{.7,.6},{1,1}})}),
		Emitters=table.freeze({
			table.freeze({name="BoilPool",at="pool",box=Vector3.new(10,.5,1.5),out=.6,up=.2,rate=30,rate1=15,level1=true,
				texture="Spray",Life=NumberRange.new(.6,.9),Speed=NumberRange.new(3,6),Spread=50,Acceleration=Vector3.new(0,-9,0),
				Drag=1,Size=keys({{0,2.5},{1,4.5}}),Transparency=keys({{0,.35},{1,1}}),Color=hex("#FFFFFF"),LightEmission=.1}),
			table.freeze({name="BoilLedge",at="ledge",box=Vector3.new(9,.5,1.5),out=.4,up=0,rate=7,
				texture="Spray",Life=NumberRange.new(.6,.9),Speed=NumberRange.new(3,6),Spread=50,Acceleration=Vector3.new(0,-9,0),
				Drag=1,Size=keys({{0,1.2},{1,2.4}}),Transparency=keys({{0,.4},{1,1}}),Color=hex("#FFFFFF"),LightEmission=.1}),
			table.freeze({name="Droplets",at="pool",box=Vector3.new(9,.3,1),out=.8,up=.3,rate=10,
				texture="Speck",Life=NumberRange.new(.5),Speed=NumberRange.new(8,12),Spread=60,Acceleration=Vector3.new(0,-30,0),
				Size=keys({{0,.3},{1,.15}}),Transparency=keys({{0,.1},{1,.6}}),Color=hex("#F4FCFF")}),
			table.freeze({name="KitMist",at="pool",box=Vector3.new(10,1,1.5),out=1,up=3,rate=3,keepOut=true,
				texture="Spray",Life=NumberRange.new(2.5,3.5),Speed=NumberRange.new(1,1.6),Spread=15,Acceleration=Vector3.new(0,.4,0),
				Drag=.6,Size=keys({{0,4},{1,8}}),Transparency=keys({{0,1},{.25,.88},{1,1}}),Color=hex("#E9F8FF"),ZOffset=-2}),
		}),
	}),
	-- grow: added to the sheet's width (scale multiplies it first); out along n; shift along t.
	Strands=table.freeze({
		{name="StrandA",scale=1,grow=1,out=.15,shift=0,length=20,skyLength=28,speed=.55,Color=hex("#7FE0FF"),
			Transparency=keys({{0,.6},{.08,.28},{.85,.28},{1,.8}})},
		{name="StrandB",scale=.7,grow=0,out=.3,shift=.6,length=9,speed=1.1,Color=hex("#DDF6FF"),
			Transparency=keys({{0,.7},{.08,.62},{.85,.62},{1,.85}})},
	}),
	Ribbon=table.freeze({scale=1,grow=1.6,out=.45,shift=0,length=16,skyLength=22,speed=1,Color=hex("#FFFFFF"),LightEmission=.25,
		Transparency=keys({{0,.5},{.05,.2},{.85,.2},{1,.7}})}),
	-- Along t at a tier's top, this far out along n.
	Lips=table.freeze({Upper={length=8,thickness=.5,out=.3},Lower={length=10.6,thickness=.6,out=.3}}),
	LipLook=table.freeze({Color=hex("#F4FCFF"),Reflectance=.1}),
	-- box: along t, up, along n. Pool boxes sit at I + n * out, at PoolTop + up; ledge boxes at the Lower top. The pool bed
	-- is walkable, so pool boxes stay within 1.5 studs of the sheet along n and mist starts above pet height (Fable r1).
	Foam=table.freeze({
		{name="Foam",at="pool",box=Vector3.new(12,.6,1.5),out=.75,up=.3,rate=22,rate1=8,
			Size=keys({{0,1},{.3,1.4},{1,1.3}})},
		{name="LedgeFoam",at="ledge",box=Vector3.new(10.5,.5,2),out=.6,up=0,rate=11,
			Size=keys({{0,.8},{.3,1.1},{1,1}})},
	}),
	FoamLook=table.freeze({Life=NumberRange.new(.6,.8),Speed=NumberRange.new(2,4),Spread=35,Acceleration=Vector3.new(0,-9,0),
		Drag=1,RotSpeed=NumberRange.new(-30,30),Transparency=keys({{0,.15},{.6,.35},{1,1}}),
		Color=ColorSequence.new(hex("#FFFFFF"),hex("#F4FCFF")),LightEmission=.2}),
	Rings=table.freeze({out=2,up=.08,rate=1.25,life=2.4,speed=.05,Size=keys({{0,4},{1,7}}),
		Transparency=keys({{0,.3},{.7,.6},{1,1}})}),
	Mist=table.freeze({
		{name="Mist",at="pool",box=Vector3.new(10,1,1.5),out=1,up=3,rate=3,rate1=1.5,Size=keys({{0,3},{1,5}})},
		-- Just above the ledge roll.
		{name="LedgeMist",at="ledge",box=Vector3.new(8,1,2),out=.3,up=1.2,rate=2,Size=keys({{0,2.5},{1,5}})},
	}),
	-- 3 studs under the lip; the pool mist's look, at its size before the r1 pool change.
	SkyMist=table.freeze({box=Vector3.new(10,1,3),out=1.5,up=-3,rate=3,Size=keys({{0,3},{1,6.5}})}),
	MistLook=table.freeze({Life=NumberRange.new(2.5,3.5),Speed=NumberRange.new(1,1.6),Spread=15,ZOffset=-2,
		RotSpeed=NumberRange.new(-12,12),Transparency=keys({{0,1},{.25,.62},{1,1}}),Color=ColorSequence.new(hex("#E9F8FF"))}),
	-- Feet 7 studs either side of I along t, 2 out along n, 1 above the pool; both axes up, so the curve sizes arc it
	-- 14 wide and 6 high.
	Rainbow=table.freeze({half=7,out=2,up=1,width=1.6,curve=8,segments=16,LightEmission=.3,
		Transparency=keys({{0,1},{.2,.84},{.5,.8},{.8,.84},{1,1}})}),
})

-- LOOK-R2 3 (Fable, 2026-11-23): the fountain in the Bubble Spring's basin, while the world kit stands (AeroFountain, in
-- the additions). Positions come from WorldAeroKit.fountain. Jet up from the finial, a spill ring off the upper bowl, a
-- splash ring in the basin. Level 1 keeps the jet; level 2 and Reduced Motion: none. On only within Radius of the camera.
-- Sound: today's water_bed_loop as a positional voice through AmbientAudio (an original fountain loop is owed).
Aero.Fountain=table.freeze({
	Radius=90,
	Texture="rbxassetid://119614715171256", -- the speck, stretched along the velocity into streaks
	-- LOOK-R2 round 3: a thin streak jet, a heavier spill.
	Jet=table.freeze({rate=40,rate1=24,Speed=NumberRange.new(11),Spread=5,Life=NumberRange.new(.6),Acceleration=Vector3.new(0,-30,0),
		Size=keys({{0,.2},{1,.12}}),Transparency=keys({{0,.2},{1,.5}})}),
	Spill=table.freeze({rate=40,Speed=NumberRange.new(.6),Spread=10,Life=NumberRange.new(.45),Acceleration=Vector3.new(0,-18,0),
		Size=keys({{0,.35},{1,.25}}),Transparency=keys({{0,.25},{1,.6}})}),
	Splash=table.freeze({rate=8,texture="rbxassetid://90482640070809",Speed=NumberRange.new(1.5,2.5),Spread=40,
		Life=NumberRange.new(.4,.6),Acceleration=Vector3.new(0,-8,0),Size=keys({{0,.5},{1,1}}),Transparency=keys({{0,.35},{1,1}})}),
	Color=hex("#F4FCFF"),
	Squash=NumberSequence.new(-1.6), -- jet and spill: tall, thin streaks along their flight (positive squashes them flat)
	-- LOOK-R3 3: the original loop (scripts/synth_fountain_loop.py, 32 s), from a random point, never restarted by distance.
	-- The library stand-in (water_bed_loop at 1.25) plays if the loop does not load. Spencer's ears decide.
	Voice=table.freeze({id=96991688758765,volume=.20,speed=1,min=7,max=30, -- LOOK-R4 B4: heard within ~15 studs, gone by 30
		fallback=table.freeze({id=71747963121003,speed=1.25,volume=.16})}),
})

-- "W7_Water__cloud", "W7_Backdrop__cloud_2" -> "cloud"; nil for anything else (collision tiles, pets, props).
function Aero.kind(name)
	if string.sub(name,1,3)~="W7_"then return nil end
	local kind=string.match(name,"__(.+)$")
	return kind and(string.gsub(kind,"_%d+$",""))
end
return table.freeze(Aero)
