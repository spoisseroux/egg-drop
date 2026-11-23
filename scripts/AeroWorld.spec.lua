-- Studio Client. Frutiger Aero (WORLD-PLAN-2026-11-22 section 9): the switch, the values, and AeroWorld on fixture
-- parts, a fake Lighting and a fake clock: exact restore, rebuilds, late parts, double toggles, crowns, owners left
-- alone, additions and their budget. The live room and Lighting are never touched.
-- Usage: require(PlayerScripts.Client.ZZSpecs.AeroWorld)(PlayerScripts.Client)
return function(client)
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
		local t=Instance.new("Texture");t.Name=name;t.Face=Enum.NormalId.Top;t.Transparency=.6;t.Color3=hex("#FFEEEE");t.Parent=part
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
	local Props={"Color","Material","Transparency","Reflectance","TextureID","Color3","Enabled","CFrame"}
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
			additions=r.additions,warn=function(text)table.insert(r.warnings,text)end})
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
			for _,kind in ipairs({"dirt_path","pebble_bed","bark","wood_plank","palette","far_peak","ground"})do assert(Values.Surfaces[kind]==nil,kind)end
			for _,kind in ipairs({"water_stream","water_pool","water"})do assert(Values.Surfaces[kind].Transparency==nil,"water stays opaque")end
			assert(#Values.Lips<=Values.MaxLips and #Values.Glints<=Values.MaxGlints)
			assert(#Values.Glints*Values.GlintRate*Values.GlintLife<=Values.MaxGlintsLive)
			assert(1+#Values.Lips+#Values.Glints<=8,"draw calls")
			assert(Values.kind("W7_Water__water_stream")=="water_stream"and Values.kind("W7_Backdrop__cloud_2")=="cloud")
			assert(Values.kind("W7C_Ground_01")==nil and Values.kind("Dog__grass")==nil and Values.kind("W7_Thing")==nil)
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
			assert(rgb(l.flowSkin.Color3)==rgb(hex("#3CC8F0"))and near(l.flowSkin.Transparency,.42)and near(l.glint.Transparency,.6)and near(l.poolSkin.Transparency,.5))
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
			local water=mesh(w,"W7_Water__water_pool");r.pump();local t=skin(water,"FlowSkin");r.pump();assert(near(t.Transparency,.5))
			crown.Parent=nil;r.pump();assert(sa.Parent==crown and crown.TextureID=="rbxassetid://222"and crown.Material==Enum.Material.SmoothPlastic)
			crown.Parent=w;r.pump();assert(sa.Parent==nil and crown.TextureID==Values.Crowns.lime.Texture)
			r.flip(false);assert(sa.Parent==crown and near(t.Transparency,.6)and near(water.Reflectance,0)and #r.warnings==0)
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
			local added=Additions.build({parent=parent,clouds=false,groundY=function()return 4.5 end})
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
