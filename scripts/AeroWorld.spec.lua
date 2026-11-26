-- Studio Client. Frutiger Aero (WORLD-PLAN-2026-11-22 section 9): the switch, the values, and AeroWorld on fixture
-- parts, a fake Lighting and a fake clock: exact restore, rebuilds, late parts, double toggles, crowns, owners left
-- alone, additions and their budget. The live room and Lighting are never touched.
-- Usage: require(PlayerScripts.Client.ZZSpecs.AeroWorld)(PlayerScripts.Client)
-- The garden hour cases (slice B) are all fakes and run first; a bundle with AeroWorld passes `offline` (the second
-- argument) and the Studio cases after them are skipped.
return function(client,offline)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Aero=require(Shared.Aero)
	local Values=require(Shared.WorldAero)
	local AeroWorld=require(client.AeroWorld)
	local Additions=require(client.AeroAdditions)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local holder=Instance.new("Folder");holder.Name="_AeroSpec";holder.Parent=workspace
	local live={}
	-- Signals may be deferred.
	local function events()task.wait();task.wait()end
	local function near(a,b)return math.abs(a-b)<1e-4 end
	local hex=Color3.fromHex
	local function rgb(c)return math.round(c.R*255).."/"..math.round(c.G*255).."/"..math.round(c.B*255)end
	local PINK=hex("#FFB7D4")

	local function signal()
		local s={listeners={}}
		function s:Connect(fn)
			local link={Connected=true}
			self.listeners[link]=fn
			function link.Disconnect()link.Connected=false;s.listeners[link]=nil end
			return link
		end
		function s.fire()local list={};for _,fn in pairs(s.listeners)do table.insert(list,fn)end;for _,fn in ipairs(list)do fn()end end
		function s.count()local n=0;for _ in pairs(s.listeners)do n+=1 end;return n end
		return s
	end
	-- A Lighting that counts its writes: plain values behind a proxy.
	local function fake(class,name,props,log)
		local attrs,item={},{}
		local methods={IsA=function(_,c)return c==class end,GetAttribute=function(_,k)return attrs[k]end,
			SetAttribute=function(_,k,v)attrs[k]=v;log.writes+=1 end}
		return setmetatable(item,{__index=function(_,k)
			if k=="Name"then return name elseif k=="ClassName"then return class elseif k=="Parent"then return log.parent and log.parent(item)end
			return methods[k]or props[k]
		end,__newindex=function(_,k,v)
			if props[k]==nil and methods[k]==nil then error(class.." has no "..tostring(k),2)end
			if log.refuse==k then error("refused "..k,2)end
			props[k]=v;log.writes+=1
		end}),props,attrs
	end
	local Faces={"Bk","Dn","Ft","Lf","Rt","Up"}
	local Data={sky={day={},dusk={}}}
	for _,f in ipairs(Faces)do Data.sky.day[f]="day"..f;Data.sky.dusk[f]="dusk"..f end
	local function lightingOf(log)
		local children={}
		local function copy(values,seed)local out={};for k,v in pairs(values)do out[k]=if type(v)=="number"then v*.5+seed elseif type(v)=="boolean"then not v else PINK end;return out end
		local raw={}
		local function child(class,name,values)
			local props=copy(values,.1)
			if class=="Sky"then for _,f in ipairs(Faces)do props["Skybox"..f]="dusk"..f end end
			local item,_,attrs=fake(class,name,props,log)
			raw[class]=props
			if class=="Sky"then attrs.FaceSet="dusk";raw.attrs=attrs end
			table.insert(children,item)
		end
		child("Atmosphere","Atmosphere",Values.Atmosphere)
		child("ColorCorrectionEffect","SproutHollowGrade",Values.Grade)
		child("BloomEffect","HollowBloom",Values.Bloom)
		child("SunRaysEffect","HollowSunRays",Values.SunRays)
		child("Sky","WorldSky",Values.Sky)
		local props=copy(Values.Lighting,.2)
		raw.Lighting=props
		props.FindFirstChild=function(_,name)for _,c in ipairs(children)do if c.Name==name then return c end end;return nil end
		props.FindFirstChildOfClass=function(_,class)for _,c in ipairs(children)do if c.ClassName==class then return c end end;return nil end
		local lighting=fake("Lighting","Lighting",props,log)
		log.parent=function(item)return if table.find(children,item)then lighting else nil end
		return lighting,raw,children
	end
	local function frozen(raw)
		local out={}
		for class,props in pairs(raw)do for k,v in pairs(props)do if type(v)~="function"then out[class.."."..k]=v end end end
		return out
	end
	local function same(a,b)
		for k,v in pairs(a)do assert(b[k]==v,k.." "..tostring(b[k]).." was "..tostring(v))end
		for k in pairs(b)do assert(a[k]~=nil,k.." is new")end
	end

	local function mesh(folder,name,options)
		options=options or {}
		local p=Instance.new(options.class or "MeshPart")
		p.Name=name;p.Anchored=true;p.Color=options.color or hex("#F0E8E0");p.Material=Enum.Material.SmoothPlastic
		p.Transparency=options.transparency or 0
		if p:IsA("MeshPart")and options.texture then p.TextureID="rbxassetid://"..options.texture end
		for k,v in pairs(options.attributes or {})do p:SetAttribute(k,v)end
		if options.matte then local sa=Instance.new("SurfaceAppearance");sa.Parent=p end
		p.Parent=folder
		return p
	end
	local function skin(part,name)
		local t=Instance.new("Texture");t.Name=name;t.Face=Enum.NormalId.Top;t.Transparency=.6;t.Color3=hex("#FFEEEE")
		t.Texture="rbxassetid://79678594491030";t.StudsPerTileU,t.StudsPerTileV=14,14;t.Parent=part
		return t
	end
	local function lounge(world)
		local room=Instance.new("Folder");room.Name="EggDropLounge"
		local w=Instance.new("Folder");w.Name="World";w.Parent=room
		local f=Instance.new("Folder");f.Name="WaterFlow";f.Parent=room
		local r={room=room,world=w,flow=f}
		r.grass=mesh(w,"W7_Ground__grass",{matte=true})
		r.path=mesh(w,"W7_Ground__dirt_path",{matte=true})
		r.rock=mesh(w,"W7_DriftRocksA__cliff_rock",{matte=true})
		r.marble=mesh(w,"W7_Rotunda__marble")
		r.trim=mesh(w,"W7_Bridge__trim")
		r.stream=mesh(w,"W7_Water__water_stream");r.flowSkin=skin(r.stream,"FlowSkin");r.glint=skin(r.stream,"FlowGlint")
		r.pool=mesh(w,"W7_Water__water_pool");r.poolSkin=skin(r.pool,"FlowSkin")
		r.bubble=mesh(w,"W7_Bubbles__bubble",{transparency=.45,attributes={WorldMotion="bob"}})
		r.lamp=mesh(w,"W7_LampOrbs__glow_warm",{transparency=.2,attributes={WorldMotion="pulse"}})
		r.cradle=mesh(w,"W7_CradleMobile__glow_warm",{attributes={CareStatusSurface=true,WorldMotion="spin"}})
		r.backdrop=mesh(w,"W7_Backdrop__cloud_2");r.cloud=mesh(w,"W7_Water__cloud",{transparency=.35})
		r.crown=mesh(w,"W7_Vegetation__foliage_blossom",{matte=true,texture="111"})
		r.islet=mesh(w,"W7_IsletsA__foliage_blossom",{matte=true,texture="111"})
		r.tile=mesh(w,"W7C_Ground_01",{transparency=1})
		r.prop=mesh(w,"Lantern",{})
		local anchor=mesh(f,"Water_Foam",{class="Part",transparency=1})
		r.splash=Instance.new("ParticleEmitter");r.splash.Name="Splash";r.splash.Color=ColorSequence.new(PINK);r.splash.Parent=anchor
		r.beam=Instance.new("Beam");r.beam.Parent=anchor
		room.Parent=world
		return r
	end
	local Props={"Color","Material","Transparency","Reflectance","TextureID","Color3","Enabled","CFrame","Texture","StudsPerTileU","StudsPerTileV"}
	local function picture(room)
		local out={}
		for _,item in ipairs(room:GetDescendants())do
			local got={parent=item.Parent}
			for _,key in ipairs(Props)do
				local ok,value=pcall(function()return item[key]end)
				if ok then got[key]=if typeof(value)=="ColorSequence"then rgb(value.Keypoints[1].Value)elseif typeof(value)=="Color3"then rgb(value)else value end
			end
			out[item]=got
		end
		return out
	end
	local function samePicture(a,b)
		for item,got in pairs(a)do
			assert(b[item],item.Name.." is missing")
			for key,value in pairs(got)do assert(b[item][key]==value,item.Name.."."..key.." "..tostring(b[item][key]).." was "..tostring(value))end
		end
		for item in pairs(b)do assert(a[item],item.Name.." is new")end
	end
	local function rig(options)
		options=options or {}
		local r={on=false,trees="lime",lvl=0,still=false,deferred={},timers={},log={writes=0},applied=0,built=0,dropped=0,stills={}}
		r.world=Instance.new("Folder");r.world.Name="_AeroWorld";r.world.Parent=holder
		r.lighting,r.raw,r.effects=lightingOf(r.log)
		r.clock={now=function()return 0 end,apply=function()r.applied+=1;if r.clock.look then r.clock.look.paint()end end}
		r.changed,r.treesChanged,r.reducedChanged=signal(),signal(),signal()
		r.warnings={}
		r.additions=if options.additions then options.additions else{build=function(o)
			assert(o.parent==r.world);r.built+=1
			return{still=function(v)table.insert(r.stills,v)end,destroy=function()r.dropped+=1 end}
		end}
		r.aero=AeroWorld.new({world=r.world,lighting=r.lighting,data=Data,clock=r.clock,
			switch={on=function()return r.on end,changed=function()return r.changed end,trees=function()return r.trees end,treesChanged=function()return r.treesChanged end},
			level=function()return r.lvl end,reduced=function()return r.still end,reducedChanged=function()return r.reducedChanged end,
			defer=function(fn)table.insert(r.deferred,fn)end,delay=function(s,fn)assert(s==AeroWorld.Interval);table.insert(r.timers,fn)end,
			additions=r.additions,warn=function(text)table.insert(r.warnings,text)end,
			-- The world kit (AeroKit): none unless a case brings fixture templates, data and a builder.
			kit=options.kit,kitData=function()return options.kitData end,templates=function()return options.templates end,
			spawn=function(fn)fn()end,preload=function()return options.loaded~=false end})
		function r.flip(on)r.on=on;r.aero:sync()end
		function r.pump()events();local list=r.deferred;r.deferred={};for _,fn in ipairs(list)do fn()end;events()end
		function r.tick()local list=r.timers;r.timers={};for _,fn in ipairs(list)do fn()end end
		function r.links()return r.changed.count()+r.treesChanged.count()+r.reducedChanged.count()end
		table.insert(live,r)
		return r
	end
	local function painted(l)
		local sa=l.grass:FindFirstChildOfClass("SurfaceAppearance")
		return rgb(sa.Color)==rgb(Values.Surfaces.grass.Tint)
	end

	local ok,problem=pcall(function()
		-- The garden hour (slice B): HollowClock paints GardenHour.look through self.look.paint(values). All fakes (a
		-- fake world, room, Lighting, glow parts and AeroClouds), so these cases also run offline.
		local Hour=require(Shared.GardenHour)
		local Night=require(Shared.WorldNight)
		local HourData={sky={day=Data.sky.day,dusk=Data.sky.dusk,night={}}}
		for _,f in ipairs(Faces)do HourData.sky.night[f]="night"..f end
		local function hourRig(options)
			options=options or {}
			local r={on=false,log={writes=0},timers={},applied=0,cloudsGone=false}
			r.lighting,r.raw=lightingOf(r.log)
			local base=r.log.parent
			r.terrain={}
			r.cloudsProps={Cover=.4,Density=.2,Color=PINK}
			r.clouds=fake("Clouds","AeroClouds",r.cloudsProps,r.log)
			r.log.parent=function(item)
				if item==r.clouds then return if r.cloudsGone then nil else r.terrain end
				return base(item)
			end
			local function part(name,care)
				local props={Color=PINK}
				local item,_,attrs=fake("BasePart",name,props,r.log)
				if care then attrs.CareStatusSurface=true end
				return item,props
			end
			r.glow,r.glowProps=part("W7_LampOrbs__glow_warm")
			r.care,r.careProps=part("W7_CradleMobile__glow_warm",true)
			r.part=part
			local folder={Name="World",DescendantAdded=signal(),DescendantRemoving=signal(),GetDescendants=function()return{r.glow,r.care}end}
			local room={Name="EggDropLounge",ChildAdded=signal(),ChildRemoved=signal(),GetChildren=function()return{folder}end}
			r.world={ChildAdded=signal(),ChildRemoved=signal(),FindFirstChild=function(_,name)return if name=="EggDropLounge"then room else nil end}
			r.clock={now=function()return 0 end,apply=function()r.applied+=1;if r.clock.look then r.clock.look.paint(r.values)end end}
			r.aero=AeroWorld.new({world=r.world,lighting=r.lighting,data=HourData,clock=r.clock,
				switch={on=function()return r.on end,changed=function()return signal()end,trees=function()return "lime"end,treesChanged=function()return signal()end},
				level=function()return 0 end,reduced=function()return false end,reducedChanged=function()return signal()end,
				defer=function()end,delay=function(_,fn)table.insert(r.timers,fn)end,warn=function(text)error(text)end,
				clouds=function()return if r.cloudsGone then nil else r.clouds end,
				-- The real additions destroy the AeroClouds with themselves (budget level 2, Aero off).
				additions={build=function()return{still=function()end,destroy=function()if not options.keepClouds then r.cloudsGone=true end end}end},
				templates=function()return nil end})
			function r.flip(on)r.on=on;r.aero:sync()end
			function r.paint(values)r.values=values;r.clock.apply()end
			table.insert(live,r)
			return r
		end
		local Warm=Values.Surfaces.glow_warm.Color

		test("hour: the hour's light, sky, glow_warm and clouds through the clock; off paints the Aero picture back exactly",function()
			local r=hourRig();r.flip(true)
			local aero=frozen(r.raw)
			assert(rgb(r.glowProps.Color)==rgb(Warm)and r.careProps.Color==PINK and r.cloudsProps.Color==PINK and r.cloudsProps.Cover==.4)
			r.paint(Hour.Holds.night)
			for k,v in pairs(Night.Lighting)do assert(r.lighting[k]==v,k)end
			for k,v in pairs(Night.Atmosphere)do assert(r.raw.Atmosphere[k]==v,k)end
			for k,v in pairs(Night.Bloom)do assert(r.raw.BloomEffect[k]==v,k)end
			for k,v in pairs(Night.Grade)do assert(r.raw.ColorCorrectionEffect[k]==v,k)end
			for k,v in pairs(Night.SunRays)do assert(r.raw.SunRaysEffect[k]==v,k)end
			assert(r.raw.Sky.SkyboxBk=="nightBk"and r.raw.Sky.SkyboxUp=="nightUp"and r.raw.attrs.FaceSet=="night"and r.raw.Sky.StarCount==Night.Sky.StarCount)
			assert(rgb(r.glowProps.Color)==rgb(Night.GlowWarm)and r.careProps.Color==PINK,"glow_warm, never the care mobile")
			for k,v in pairs(Night.Clouds)do assert(r.cloudsProps[k]==v,k)end
			-- golden: the dusk faces
			r.paint(Hour.Holds.golden);assert(r.raw.Sky.SkyboxBk=="duskBk"and r.raw.attrs.FaceSet=="dusk")
			r.paint(nil)
			same(aero,frozen(r.raw))
			assert(rgb(r.glowProps.Color)==rgb(Warm)and r.cloudsProps.Color==PINK and r.cloudsProps.Cover==.4 and next(r.aero.sky)==nil)
			r.flip(false)
		end)
		test("hour: a hold writes nothing pass after pass, a blend does; a glow_warm arriving under the hour takes its colour",function()
			local r=hourRig();r.flip(true)
			for _,hold in ipairs({Hour.Holds.night,Hour.Holds.day,Hour.Holds.dawn,Hour.Holds.golden})do
				r.paint(hold)
				local engine,own=r.log.writes,r.aero.writes
				for _=1,5 do r.paint(hold)end
				assert(r.log.writes==engine and r.aero.writes==own,hold.Phase.." hold wrote")
			end
			local engine=r.log.writes
			r.paint(Hour.look(3600*1000+2950));assert(r.log.writes>engine,"a blend writes")
			r.paint(Hour.Holds.night)
			local late,props=r.part("W7_Late__glow_warm");r.aero:paint(late)
			assert(rgb(props.Color)==rgb(Night.GlowWarm))
			-- off the day hold writes nothing new either (WorldAero's own tables)
			r.paint(Hour.Holds.day);r.paint(nil);engine=r.log.writes;r.paint(nil);assert(r.log.writes==engine)
			r.flip(false)
		end)
		test("hour: Aero off mid-night puts back the light and glow; clouds the additions took are let go, kept ones put back",function()
			for _,keep in ipairs({false,true})do
				local r=hourRig({keepClouds=keep})
				local before=frozen(r.raw)
				r.flip(true);r.paint(Hour.Holds.night);r.flip(false)
				same(before,frozen(r.raw))
				assert(r.glowProps.Color==PINK and r.careProps.Color==PINK and r.clock.look==nil and next(r.aero.sky)==nil)
				assert(next(r.aero.light)==nil and next(r.aero.surfaces)==nil and r.aero.glow==nil)
				if keep then assert(r.cloudsProps.Color==PINK and r.cloudsProps.Cover==.4)end
			end
		end)
		if offline then return end
		test("the ceiling: the flag, and the beta place or Studio; the live place never; on needs the attribute",function()
			local on={AeroWorld=true}
			assert(Aero.ceiling({flags=on,place=Aero.PlaceId,studio=false})and Aero.ceiling({flags=on,place=1,studio=true}))
			assert(not Aero.ceiling({flags=on,place=96451847774961,studio=false}))
			for _,flags in ipairs({{},{AeroWorld=false},{AeroWorld="true"},{AeroWorld=1}})do assert(not Aero.ceiling({flags=flags,place=Aero.PlaceId,studio=true}))end
			assert(Aero.PlaceId==107705084891479 and Aero.Key=="aero_world")
			assert(Aero.resolve(nil,nil,true)and Aero.resolve("false",nil,true)and not Aero.resolve(false,nil,true)and not Aero.resolve(true,true,false))
			assert(Aero.resolve(false,true,true)and not Aero.resolve(true,false,true))
		end)
		test("the values are the plan's, and inside its caps",function()
			assert(Values.Hour==10.5 and Values.Lighting.ClockTime==10.5 and Values.Bloom.Intensity==.18 and Values.Lighting.EnvironmentSpecularScale==.2)
			assert(rgb(Values.Crowns.lime.Color)==rgb(hex("#8FD63F"))and rgb(Values.Crowns.coral.Color)==rgb(hex("#F2545B")))
			for _,kind in ipairs({"dirt_path","bark","wood_plank","far_peak","ground"})do assert(Values.Surfaces[kind]==nil,kind)end
			-- LOOK-R3 round 6: the pebble bed only takes a tint (it peeks above the pool rims).
			local pebble=Values.Surfaces.pebble_bed;assert(pebble.Tint and next(pebble,next(pebble))==nil,"pebble bed: tint only")
			-- Slice 9: the palette is only swapped for its saturation-1.0 map, nothing else about the props moves.
			local palette=Values.Surfaces.palette
			assert(palette and next(palette)=="TextureID"and next(palette,"TextureID")==nil and string.match(palette.TextureID,"^rbxassetid://%d+$"))
			-- The kit's own meshes (scripts/build_world_aero_kit.py): the falls lips and rocks are no surface, the sheets keep
			-- their texture, and the crowns and bushes paint as the merged parts they replace.
			assert(Values.kind("W7_Kit_Falls__kitwater")=="kitwater"and Values.Surfaces.kitwater==nil)
			assert(Values.Surfaces.waterfall_tumble==nil and Values.kind("W7_Kit_Crown_Blossom__foliage_blossom")==Values.CrownKind)
			assert(Values.kind("W7_Kit_Rest__foliage")=="foliage")
			for _,kind in ipairs({"water_stream","water_pool","water"})do assert(Values.Surfaces[kind].Transparency==nil,"water stays opaque")end
			assert(#Values.Lips<=Values.MaxLips and #Values.Glints<=Values.MaxGlints)
			assert(#Values.Glints*Values.GlintRate*Values.GlintLife<=Values.MaxGlintsLive)
			assert(1+#Values.Lips+#Values.Glints<=8,"draw calls")
			assert(Values.kind("W7_Water__water_stream")=="water_stream"and Values.kind("W7_Backdrop__cloud_2")=="cloud")
			assert(Values.kind("W7C_Ground_01")==nil and Values.kind("Dog__grass")==nil and Values.kind("W7_Thing")==nil)
		end)
		test("Fable R5: the arrival chimes take their own palette (saturation x .75); other palette parts and off are untouched",function()
			local r=rig();local l=lounge(r.world)
			local chime=mesh(l.world,"W7_Chime_2__palette",{texture="555"})
			local prop=mesh(l.world,"W7_Bench__palette",{texture="555"})
			r.flip(true)
			local named=Values.namedSurface("W7_Chime_2__palette","palette")
			assert(named and string.match(named.TextureID,"^rbxassetid://%d+$")and named.TextureID~="rbxassetid://0","a real chime palette id")
			assert(named.TextureID~=Values.Surfaces.palette.TextureID)
			assert(chime.TextureID==named.TextureID and prop.TextureID==Values.Surfaces.palette.TextureID)
			assert(Values.namedSurface("W7_Chime_2__glow_warm","glow_warm")==nil,"only the chimes' palette kind")
			r.flip(false)
			assert(chime.TextureID=="rbxassetid://555"and prop.TextureID=="rbxassetid://555"and #r.warnings==0,"restored")
		end)
		test("off: nothing is connected, created, written or timed",function()
			local r=rig();local l=lounge(r.world);local before=picture(r.world)
			r.flip(false);events()
			assert(r.links()==0 and #r.timers==0 and r.built==0 and r.log.writes==0 and r.applied==0 and r.clock.look==nil and r.aero.writes==0)
			mesh(l.world,"W7_Late__grass",{matte=true}).Parent=nil;r.pump()
			samePicture(before,picture(r.world))
		end)
		test("on: section 9's light, sky, surfaces, water and crowns",function()
			local r=rig();local l=lounge(r.world);r.flip(true)
			for k,v in pairs(Values.Lighting)do assert(r.lighting[k]==v,k)end
			for k,v in pairs(Values.Atmosphere)do assert(r.raw.Atmosphere[k]==v,k)end
			for k,v in pairs(Values.Bloom)do assert(r.raw.BloomEffect[k]==v,k)end
			assert(r.raw.Sky.SkyboxBk=="dayBk"and r.raw.Sky.SkyboxUp=="dayUp"and r.raw.attrs.FaceSet=="day"and r.raw.Sky.SunAngularSize==12)
			assert(r.clock.look==r.aero.look and r.aero.look.Daylight==.9 and r.applied==1)
			assert(painted(l)and rgb(l.path:FindFirstChildOfClass("SurfaceAppearance").Color)=="255/255/255","paths stay")
			assert(near(l.marble.Reflectance,.06)and near(l.trim.Reflectance,.18)and near(l.stream.Reflectance,.22)and l.stream.Transparency==0)
			assert(rgb(l.flowSkin.Color3)==rgb(hex("#E4F7FA"))and near(l.flowSkin.Transparency,.72)and near(l.glint.Transparency,.72)and near(l.poolSkin.Transparency,.72)and rgb(l.poolSkin.Color3)==rgb(hex("#E4F7FA")))
			-- LOOK-R3 1: the pool and the stream on the drawn teal tile; the pool skin is a sparse 9-stud glint.
			assert(l.pool.TextureID==Values.Surfaces.water_pool.TextureID and l.stream.TextureID==Values.Surfaces.water_stream.TextureID)
			assert(l.poolSkin.Texture==Values.Skins.FlowSkin.water_pool.Texture and l.poolSkin.StudsPerTileU==9 and l.poolSkin.StudsPerTileV==9)
			assert(l.flowSkin.Texture==l.poolSkin.Texture and l.glint.Texture==l.poolSkin.Texture and l.glint.StudsPerTileU==6,"the stream glints like the pool")
			assert(near(l.bubble.Transparency,.55)and rgb(l.cloud.Color)=="255/255/255"and near(l.cloud.Transparency,.35))
			assert(rgb(l.beam.Color.Keypoints[1].Value)==rgb(hex("#DDF6FF"))and rgb(l.splash.Color.Keypoints[1].Value)==rgb(hex("#F4FCFF")))
			assert(l.crown:FindFirstChildOfClass("SurfaceAppearance")==nil and l.crown.TextureID==Values.Crowns.lime.Texture and l.crown.Material==Enum.Material.SmoothPlastic and rgb(l.crown.Color)==rgb(Color3.new(1,1,1)))
			assert(#r.warnings==0,r.warnings[1])
		end)
		test("other owners' properties are left alone: pulses, the care mobile, the backdrop, tiles and props",function()
			local r=rig();local l=lounge(r.world);local before=picture(r.world);r.flip(true);local after=picture(r.world)
			assert(after[l.lamp].Transparency==before[l.lamp].Transparency and rgb(l.lamp.Color)==rgb(hex("#FFE08A")))
			for _,p in ipairs({l.cradle,l.backdrop,l.tile,l.prop})do for k,v in pairs(before[p])do assert(after[p][k]==v,p.Name..k)end end
			for item,got in pairs(after)do if before[item].CFrame then assert(before[item].CFrame==got.CFrame and before[item].Enabled==got.Enabled)end end
		end)
		test("off again is exact: every light, surface, texture and parent; nothing stays connected",function()
			local r=rig();local l=lounge(r.world)
			local before,light=picture(r.world),frozen(r.raw)
			r.flip(true);r.flip(false)
			samePicture(before,picture(r.world));same(light,frozen(r.raw))
			assert(r.clock.look==nil and r.applied==2 and r.links()==0 and r.built==1 and r.dropped==1)
			assert(next(r.aero.light)==nil and next(r.aero.surfaces)==nil)
			l.grass.Transparency=.1;mesh(l.world,"W7_Late__grass",{matte=true});r.pump();r.tick()
			assert(r.aero.writes>0 and #r.timers==0 and not painted(l))
		end)
		test("double toggles: on twice, off twice, ten times round; never a second snapshot",function()
			local r=rig();lounge(r.world)
			local before,light=picture(r.world),frozen(r.raw)
			for _=1,10 do r.flip(true);r.flip(true);r.aero:enable();r.pump();r.flip(false);r.flip(false);r.aero:disable();r.pump()end
			samePicture(before,picture(r.world));same(light,frozen(r.raw));assert(r.built==10 and r.dropped==10 and #r.warnings==0)
		end)
		test("a repaint of a painted garden writes nothing; a foreign write is put back by the clock's pass",function()
			local r=rig();lounge(r.world);r.flip(true);r.pump()
			local writes,light=r.aero.writes,r.log.writes
			for _=1,5 do r.clock.apply()end
			r.aero.folders={};for _,c in ipairs(r.aero.room:GetChildren())do r.aero:watch(c)end
			assert(r.aero.writes==writes and r.log.writes==light)
			r.raw.Lighting.Brightness=9;r.clock.apply();assert(math.abs(r.lighting.Brightness-1.85)<1e-5)
		end)
		test("effects that arrive after the switch are painted on the clock's next pass, and put back",function()
			local r=rig();lounge(r.world);local late=table.remove(r.effects);assert(late.ClassName=="Sky")
			r.flip(true);assert(r.raw.Sky.SkyboxBk=="duskBk")
			table.insert(r.effects,late);r.clock.apply();assert(r.raw.Sky.SkyboxBk=="dayBk")
			r.flip(false);assert(r.raw.Sky.SkyboxBk=="duskBk"and r.raw.attrs.FaceSet=="dusk")
		end)
		test("a value that cannot be put back stays on record, says so, and goes back next time",function()
			local r=rig();lounge(r.world);local light=frozen(r.raw);r.flip(true)
			r.log.refuse="Haze";r.flip(false)
			assert(r.raw.Atmosphere.Haze==Values.Atmosphere.Haze and r.raw.Atmosphere.Density==light["Atmosphere.Density"]and #r.warnings==1 and next(r.aero.light)~=nil)
			r.log.refuse=nil;r.flip(true);r.flip(false);same(light,frozen(r.raw));assert(next(r.aero.light)==nil)
			-- a parked child, the same way
			local part=Instance.new("Part");part.Parent=holder
			local child,locked={},true
			local records={[part]={was={Transparency=.25},now={},want={},parked={setmetatable(child,{__newindex=function(t,k,v)if locked then error("locked")end;rawset(t,k,v)end})}}}
			assert(AeroWorld.restore(records,part)~=nil and near(part.Transparency,.25)and #records[part].parked==1 and next(records[part].was)==nil)
			locked=false;assert(AeroWorld.restore(records,part)==nil and records[part]==nil and child.Parent==part)
		end)
		test("a crown that will not go flat keeps its leaves, once, until the next switch",function()
			local r=rig();local l=lounge(r.world);local before=picture(l.crown)
			local real,refusing=AeroWorld.write,true
			AeroWorld.write=function(records,item,key,value)if refusing and item==l.crown and key=="Color"then error("refused")end;return real(records,item,key,value)end
			local fine,wrong=pcall(function()
				r.flip(true);for _=1,3 do r.pump()end
				assert(#r.deferred==0,"no retry loop");samePicture(before,picture(l.crown))
				assert(l.crown.TextureID=="rbxassetid://111"and l.crown.Material==Enum.Material.SmoothPlastic and l.crown:FindFirstChildOfClass("SurfaceAppearance")and l.islet.TextureID==Values.Crowns.lime.Texture and #r.warnings==1)
				refusing=false;r.treesChanged.fire();r.pump();assert(l.crown.TextureID==Values.Crowns.lime.Texture and l.crown:FindFirstChildOfClass("SurfaceAppearance")==nil)
			end)
			AeroWorld.write=real;assert(fine,wrong);r.flip(false);assert(l.crown.TextureID=="rbxassetid://111")
		end)
		test("a new World beside, or instead of, the old: the old gets its looks back, its signals are let go, and a re-add connects once",function()
			local r=rig();local l=lounge(r.world);local before=picture(l.world);r.flip(true);r.pump()
			local function links()local n=0;for _,list in pairs(r.aero.folderLinks)do for _,link in ipairs(list)do if link.Connected then n+=1 end end end;return n end
			assert(links()==4)
			local w=Instance.new("Folder");w.Name="World";local marble=mesh(w,"W7_New__marble");w.Parent=l.room;r.pump()
			assert(near(marble.Reflectance,.06)and links()==4);samePicture(before,picture(l.world))
			mesh(l.world,"W7_Old__marble");r.pump();assert(near(l.world.W7_Old__marble.Reflectance,0));l.world.W7_Old__marble:Destroy()
			w.Parent=nil;r.pump();assert(near(marble.Reflectance,0)and painted(l)and links()==4,"the one left is painted again")
			for _=1,3 do l.world.Parent=nil;r.pump();assert(links()==2 and not painted(l));l.world.Parent=l.room;r.pump();assert(links()==4 and painted(l))end
			r.flip(false);assert(links()==0);samePicture(before,picture(l.world))
		end)
		test("an effect that was replaced is let go, and the new one painted",function()
			local r=rig();lounge(r.world);r.flip(true)
			local old=table.remove(r.effects);assert(r.aero.light[old]);r.clock.apply()
			assert(r.aero.light[old]==nil and r.raw.Sky.SkyboxBk=="duskBk");r.flip(false);assert(#r.warnings==0)
		end)
		test("a rebuilt room is painted; the old one gets its looks back",function()
			local r=rig();local a=lounge(r.world);local before=picture(a.room);r.flip(true)
			a.room.Parent=nil;r.pump();samePicture(before,picture(a.room));assert(r.dropped==1)
			local b=lounge(r.world);r.pump();assert(painted(b)and b.crown.TextureID==Values.Crowns.lime.Texture and r.built==2)
			b.room:Destroy();r.pump();assert(r.aero.room==nil and next(r.aero.surfaces)==nil and #r.warnings==0)
			local c=lounge(nil);local fresh=picture(c.room);c.room.Parent=r.world;r.pump();assert(painted(c));r.flip(false);samePicture(fresh,picture(c.room))
		end)
		test("late parts, late SurfaceAppearances, late folders and returning parts",function()
			local r=rig()
			r.flip(true);assert(r.built==0,"no room yet")
			local room=Instance.new("Folder");room.Name="EggDropLounge";room.Parent=r.world;r.pump()
			local w=Instance.new("Folder");w.Name="World";w.Parent=room;r.pump()
			local meadow=mesh(w,"W7_Ground__meadow",{matte=true});local crown=mesh(w,"W7_X__foliage_blossom",{texture="222"})
			r.pump()
			assert(rgb(meadow:FindFirstChildOfClass("SurfaceAppearance").Color)==rgb(Values.Surfaces.meadow.Tint)and crown.TextureID==Values.Crowns.lime.Texture)
			local sa=Instance.new("SurfaceAppearance");sa.Parent=crown;r.pump();assert(sa.Parent==nil,"taken off the crown")
			local water=mesh(w,"W7_Water__water_pool");r.pump();local t=skin(water,"FlowSkin");r.pump();assert(near(t.Transparency,.72)and t.StudsPerTileU==9)
			crown.Parent=nil;r.pump();assert(sa.Parent==crown and crown.TextureID=="rbxassetid://222"and crown.Material==Enum.Material.SmoothPlastic)
			crown.Parent=w;r.pump();assert(sa.Parent==nil and crown.TextureID==Values.Crowns.lime.Texture)
			r.flip(false);assert(sa.Parent==crown and near(t.Transparency,.6)and near(water.Reflectance,0)and #r.warnings==0)
			assert(t.StudsPerTileU==14 and t.Texture=="rbxassetid://79678594491030"and water.TextureID=="","the pool skin and tile restored")
		end)
		test("arrivals queued when the layer goes off are not painted",function()
			local r=rig();local l=lounge(r.world);r.flip(true)
			local late=mesh(l.world,"W7_Late__marble");events();r.flip(false);r.pump();assert(near(late.Reflectance,0))
		end)
		test("crowns: coral is flat too; back to lime and off are exact",function()
			local r=rig();local l=lounge(r.world);local before=picture(r.world)
			r.flip(true);r.trees="coral";r.treesChanged.fire();r.pump()
			for _,p in ipairs({l.crown,l.islet})do
				local sa=p:FindFirstChildOfClass("SurfaceAppearance")
				assert(sa==nil and rgb(p.Color)==rgb(hex("#F2545B"))and p.TextureID==""and p.Material==Enum.Material.SmoothPlastic)
			end
			r.trees="lime";r.treesChanged.fire();r.pump();assert(l.crown:FindFirstChildOfClass("SurfaceAppearance")==nil and l.crown.TextureID==Values.Crowns.lime.Texture)
			r.trees="coral";r.treesChanged.fire();r.flip(false);r.pump();samePicture(before,picture(r.world))
		end)
		test("the world kit: hides what it replaces in its own records; coral, a new World, level 2 and off are exact",function()
			local kit={built=0,dropped=0}
			function kit.build(o)
				kit.built+=1
				local folder=Instance.new("Folder");folder.Name="AeroKit"
				local crown=mesh(folder,"W7_Kit_Crown_Blossom__foliage_blossom",{matte=true})
				crown:SetAttribute("AeroMatteLime",true) -- its own matte lime skin (AeroKit)
				folder.Parent=o.parent
				kit.folder,kit.crown=folder,crown
				return{folder=folder,data=o.data,destroy=function()kit.dropped+=1;folder:Destroy()end}
			end
			local r=rig({kit=kit,kitData={hides={"W7_Vegetation__foliage_blossom","W7_Water__waterfall_tumble","W7_Bubbles__bubble"}},templates={}})
			local l=lounge(r.world)
			l.beam.Name="Water_TumbleFalls_Lower";l.beam.Enabled=true
			local before=picture(r.world)
			r.flip(true);r.pump()
			assert(kit.built==1 and kit.folder.Parent==l.room)
			assert(l.crown.Transparency==1 and l.beam.Enabled==false and l.bubble.Transparency==1,"what the kit replaces is hidden")
			local skin=kit.crown:FindFirstChildOfClass("SurfaceAppearance")
			assert(skin and kit.crown.TextureID=="","a matte lime kit crown keeps its own skin for lime")
			-- Coral and back repaint every crown: the merged one stays hidden (its own records are not the surfaces').
			r.trees="coral";r.treesChanged.fire();r.pump()
			assert(l.crown.Transparency==1 and kit.crown:FindFirstChildOfClass("SurfaceAppearance")==nil and rgb(kit.crown.Color)==rgb(hex("#F2545B")))
			r.trees="lime";r.treesChanged.fire();r.pump()
			assert(l.crown.Transparency==1 and kit.crown:FindFirstChildOfClass("SurfaceAppearance")==skin,"lime again: its skin is back")
			-- A new World under a standing kit: its crown is hidden too; the old one has its looks back.
			local old=l.crown
			local w2=Instance.new("Folder");w2.Name="World"
			local crown2=mesh(w2,"W7_Vegetation__foliage_blossom",{matte=true,texture="111"})
			l.world.Parent=nil;w2.Parent=l.room;r.pump()
			assert(crown2.Transparency==1,"the new World's crown is hidden")
			w2.Parent=nil;l.world.Parent=l.room;r.pump()
			assert(old.Transparency==1)
			-- Budget level 2: the kit goes and the merged parts come back in the same step.
			r.lvl=2;r.tick()
			assert(kit.dropped==1 and kit.folder.Parent==nil and l.crown.Transparency==0 and l.beam.Enabled==true)
			assert(near(l.bubble.Transparency,Values.Surfaces.bubble.Transparency),"Aero is still on: the bubble takes the Aero look again")
			assert(crown2.Transparency==0,"every hidden part is put back, even one that left")
			r.flip(false);r.pump()
			samePicture(before,picture(r.world))
			assert(next(r.aero.hidden)==nil and #r.warnings==0,r.warnings[1])
			-- Meshes that fail to load: nothing built, nothing hidden, one warning.
			local r3=rig({kit=kit,kitData={hides={"W7_Vegetation__foliage_blossom"}},templates={},loaded=false});local l3=lounge(r3.world)
			r3.flip(true);r3.pump()
			assert(kit.built==1 and l3.crown.Transparency==0 and #r3.warnings==1)
			r3.flip(false)
			-- No templates (not this place): nothing built, nothing hidden.
			local r2=rig({kit=kit,kitData={hides={"W7_Vegetation__foliage_blossom"}}});local l2=lounge(r2.world)
			r2.flip(true);r2.pump()
			assert(kit.built==1 and l2.crown.Transparency==0)
			r2.flip(false)
		end)
		test("additions: one build a room; budget level 2 drops them for the session, the look stays",function()
			local r=rig();local l=lounge(r.world);r.flip(true);assert(r.built==1 and #r.timers==1)
			r.tick();assert(#r.timers==1 and r.dropped==0);r.lvl=1;r.tick();assert(r.dropped==0)
			r.lvl=2;r.tick();assert(r.dropped==1 and #r.timers==0 and painted(l))
			r.flip(false);r.flip(true);assert(r.built==1 and #r.timers==0 and painted(l))
		end)
		test("additions: Reduced Motion at once and on the check; a build that fails leaves the look",function()
			local r=rig();lounge(r.world);r.still=true;r.flip(true);assert(r.stills[1]==true)
			r.still=false;r.reducedChanged.fire();assert(r.stills[2]==false);r.tick();assert(r.stills[3]==false)
			local bad=rig({additions={build=function()error("no parts")end}});local l=lounge(bad.world);bad.flip(true)
			assert(painted(l)and #bad.warnings==1 and #bad.timers==0);bad.flip(false);assert(not painted(l))
		end)
		test("the real additions: local, inert, inside the caps, gone on destroy",function()
			local parent=Instance.new("Folder");parent.Parent=holder
			local added=Additions.build({parent=parent,clouds=false,falls=false,groundY=function()return 4.5 end})
			local parts,emitters=0,0
			for _,item in ipairs(added.folder:GetDescendants())do
				if item:IsA("BasePart")then
					parts+=1
					assert(item.Anchored and not item.CanCollide and not item.CanQuery and not item.CanTouch and not item.CastShadow,item.Name)
				elseif item:IsA("ParticleEmitter")then
					emitters+=1
					assert(item.Enabled and item.Rate*item.Lifetime.Max<=Values.MaxGlintsLive/Values.MaxGlints and near(item.Size.Keypoints[1].Value,.25))
				end
			end
			assert(parts==1+#Values.Lips+#Values.Glints and emitters==4)
			local dome=added.folder.EggDome;assert(dome.Material==Enum.Material.Glass and near(dome.Transparency,.7)and dome.Size.X<5)
			added.still(true);for _,e in ipairs(added.emitters)do assert(not e.Enabled)end
			added.still(false);for _,e in ipairs(added.emitters)do assert(e.Enabled)end
			added.destroy();assert(#parent:GetChildren()==0)
		end)
		test("additions: the waterfall layers get the level, the camera and the clock's daylight on build and on each check",function()
			local states={}
			local r=rig({additions={build=function(o)
				assert(o.data==Data)
				return{still=function()end,update=function(state)table.insert(states,state)end,destroy=function()end}
			end}})
			lounge(r.world);r.clock.lastDaylight=.55
			local spot=Vector3.new(80,10,-60)
			r.aero.camera=function()return spot end
			r.flip(true)
			assert(#states==1 and states[1].level==0 and states[1].camera==spot and states[1].daylight==.55)
			r.lvl=1;spot=Vector3.new(0,10,0);r.tick()
			assert(#states==2 and states[2].level==1 and states[2].camera==spot)
			r.clock.lastDaylight=nil;r.tick();assert(states[3].daylight==Values.Daylight)
			r.flip(false)
		end)
		test("additions: the real waterfall layers through the switch; off puts the picture back",function()
			local falls=Values.Waterfall
			local data={sky=Data.sky,beams={sheets={
				{name="Water_TumbleFalls_Upper",top={81.4254,51.6046,-81.4254},bottom={79.7284,22.25,-79.7284},width0=8.4,width1=9.6,normal={-.7071,0,.7071}},
				{name="Water_TumbleFalls_Lower",top={73.9649,22.3,-73.9649},bottom={72.6921,3.2,-72.6921},width0=11.4,width1=12.6,normal={-.7071,0,.7071}},
			}}}
			local built
			local r=rig({additions={build=function(o)
				built=Additions.build({parent=o.parent,data=o.data,clouds=false,groundY=function()return 4.5 end,hour={on=function()return false end}}) -- the hour off: these are the waterfall's own counts
				return built
			end}})
			r.aero.data=data
			lounge(r.world);local before=picture(r.world)
			r.aero.camera=function()return Vector3.new(60,8,-60)end
			r.flip(true)
			local farBeams=0 -- round 6: the other falls' beams and lips within FarRadius draw too (level 0)
			for _,l in ipairs(built.falls.layers)do if l.group~="Tumble"and l.kind~="emitter"and not l.rainbow then farBeams+=1 end end
			assert(built.falls.draws()==14+farBeams and built.folder.Parent==r.world and built.falls.folder.Parent==built.folder,built.falls.draws())
			r.still=true;r.reducedChanged.fire();assert(built.falls.draws()==0)
			r.still=false;r.reducedChanged.fire();r.lvl=1;r.tick();assert(built.falls.draws()<=8)
			r.aero.camera=function()return Vector3.new(72.7+falls.Radius+5,8,-72.7)end;r.tick();assert(built.falls.draws()==0)
			r.flip(false);r.pump()
			assert(built.folder.Parent==nil)
			samePicture(before,picture(r.world))
		end)
		test("start follows the switch; destroy puts everything back and lets go",function()
			local r=rig();lounge(r.world);local before=picture(r.world)
			r.aero.link=r.changed:Connect(function()r.aero:sync()end)
			r.on=true;r.changed.fire();assert(r.aero.enabled);r.on=false;r.changed.fire();assert(not r.aero.enabled)
			r.on=true;r.changed.fire();r.aero:destroy();r.aero:destroy();assert(r.links()==0 and not r.aero.enabled)
			r.changed.fire();samePicture(before,picture(r.world))
		end)
	end)
	for _,r in ipairs(live)do pcall(function()r.aero:destroy()end)end
	holder:Destroy()
	assert(ok,problem)
	return{passed=#cases,cases=cases}
end
