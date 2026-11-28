-- Offline (default run of scripts/run_dash_server_specs.py), or Studio Client. The Hidden Grove (artifacts/qa-2026-11-28-
-- grove: GROVE-BUILD-PLAN, ARCH-REVIEW-GROVE): the switch, the WorldGrove contract (the committed placeholder refuses, a
-- fixture passes), the budgets and clearances, the ring's layout and build, the backdrop it hides and gives back inside
-- AeroWorld's lifecycle, Sky Falls cut at the moat, WorldMotion's skip, the light's pure rules (ray fade by the garden
-- hour's phase, counts by level and device, Reduced Motion, the sun gate) and the template mount.
-- The fixture is a small grove (scripts/fixtures/grove-fixture-*.json) run through build_world_grove_assets.fixture_lua,
-- bundled as client/WorldGroveFixture; it is never the real one.
-- Usage (Studio): copy the fixture's generated Lua to ZZSpecs.WorldGroveFixture, then
-- require(PlayerScripts.Client.ZZSpecs.Grove)(PlayerScripts.Client)
return function(client,offline)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Rules=require(Shared.Grove)
	local Alive=require(Shared.Alive)
	local Flags=require(Shared.FeatureFlags)
	local Hour=require(Shared.GardenHour)
	local Lanterns=require(Shared.DriftLanterns)
	local Layout=require(Shared.HollowWorldLayout)
	local Values=require(Shared.WorldAero)
	local V7=require(Shared.WorldV7Data)
	local Placeholder=require(Shared.WorldGrove)
	local Fixture=require(client.WorldGroveFixture)
	local GroveWorld=require(client.GroveWorld)
	local Light=require(client.GroveLight)
	local Falls=require(client.AeroFalls)
	local Motion=require(client.WorldMotion)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function near(a,b,within)return math.abs(a-b)<(within or 1e-3)end
	local function v(list)return Vector3.new(list[1],list[2],list[3])end
	local function deep(value)
		if type(value)~="table"then return value end
		local out={}
		for key,each in pairs(value)do out[key]=deep(each)end
		return out
	end
	local function signal()
		if offline then return offline.signal()end
		return Instance.new("BindableEvent").Event
	end
	local ctx={lanterns=Lanterns,world=Layout,dome=Values.Dome,sheets=V7.beams.sheets}

	-- Templates: one MeshPart a fixture mesh, cloned as the game clones ReplicatedStorage.GroveKit's.
	local function templates(data,missing)
		local made={}
		return{GetChildren=function()return{}end,FindFirstChild=function(_,name)
			if name==missing or not data.meshes[name]then return nil end
			made[name]=made[name]or{IsA=function(_,class)return class=="MeshPart"end,
				Clone=function()
					local p=Instance.new("MeshPart");p.Name=name;p.CastShadow=true;p.CanCollide=true;p.CanQuery=true
					p.Material="Plastic";p.Color=Color3.new(1,1,1)
					return p
				end}
			return made[name]
		end}
	end

	test("switch: the Alive feature grove (missing = off, like windbed), on only with the Aero look too",function()
		assert(table.find(Alive.Features,"grove")and Flags.AliveGrove==true and Rules.Feature=="grove")
		assert(Alive.attribute("grove")=="Alive_grove"and Alive.key("grove")=="alive_grove")
		assert(Alive.resolve("grove",nil,nil,true)==false,"missing is off")
		assert(Alive.resolve("grove","yes",nil,true)==false,"malformed is off")
		assert(Alive.resolve("grove",true,nil,true)==true and Alive.resolve("grove",false,true,true)==true)
		assert(Alive.resolve("grove",true,true,false)==false,"the ceiling wins")
		assert(Alive.ceiling("grove",{AliveGrove=true},107705084891479,false),"the beta")
		assert(Alive.ceiling("grove",{AliveGrove=true},96451847774961,true),"Studio")
		assert(not Alive.ceiling("grove",{AliveGrove=true},96451847774961,false),"never the live place")
		local aero,grove=true,true
		local env={aero={on=function()return aero end},alive={on=function(f)return f=="grove"and grove end,changed=function()return "sig"end}}
		assert(Rules.on(env)==true)
		grove=false;assert(Rules.on(env)==false,"grove off")
		grove,aero=true,false;assert(Rules.on(env)==false,"Aero off")
		assert(Rules.changed(env)=="sig")
		if offline then
			local Config=offline.new.require(offline.new.server.AliveConfig)
			local command=Config.parse("/alive grove on")
			assert(command and command.features[1]=="grove"and command.value==true,"/alive grove on")
			assert(Config.parse("/alive grove clear").value==nil)
		end
	end)

	test("contract: the committed placeholder refuses quietly; the fixture (through the generator) passes",function()
		local ok,problem,placeholder=Rules.validate(Placeholder)
		assert(not ok and placeholder==true,"placeholder: "..tostring(problem))
		assert(Placeholder.assetId==""and string.find(Placeholder.note,"PLACEHOLDER",1,true))
		assert(Rules.validate(nil)==false)
		ok,problem=Rules.validate(Fixture)
		assert(ok,"fixture: "..tostring(problem))
		assert(Fixture.turnApplied==true and Fixture.version==1 and Fixture.textures.leaf.normal and not Fixture.textures.stone.normal)
		assert(Fixture.textures.stone.color=="rbxassetid://800000001","the readback's image ids, not the manifest's file names")
	end)

	test("contract: any missing field or a broken rule refuses",function()
		for _,key in ipairs({"version","coordinates","turnApplied","meshes","instances","textures","rays","sunGate","moat",
			"canopyBottomY","hides","lanterns","falls","bubbles","totals"})do
			local data=deep(Fixture);data[key]=nil
			assert(not Rules.validate(data),"missing "..key)
		end
		local function refuses(label,change)
			local data=deep(Fixture);change(data)
			local ok,_,placeholder=Rules.validate(data)
			assert(not ok and not placeholder,label)
		end
		refuses("assetId text",function(d)d.assetId="abc"end)
		refuses("not GV_",function(d)d.meshes.Tier=d.meshes.GV_Fix_TierNorth;d.meshes.GV_Fix_TierNorth=nil;d.totals.meshes=7 end)
		refuses("a shadow",function(d)d.meshes.GV_Fix_Moat.shadow=true end)
		refuses("both centres",function(d)d.meshes.GV_Fix_Moat.pivotToCentre={0,0,0}end)
		refuses("no band",function(d)d.meshes.GV_Fix_Moat.band="sky"end)
		refuses("a texture key",function(d)d.meshes.GV_Fix_Moat.texture="moss"end)
		refuses("maxLevel",function(d)d.meshes.GV_Fix_Moat.maxLevel=3 end)
		refuses("an instance of nothing",function(d)table.insert(d.instances,{mesh="GV_Nope",pivot={0,0,0},yaw=0,scale=1})end)
		refuses("an instanced mesh never placed",function(d)
			for i=#d.instances,1,-1 do if d.instances[i].mesh=="GV_Fix_Crown"then table.remove(d.instances,i)end end
		end)
		refuses("radians for the sun gate",function(d)d.sunGate={az=5.0,el=1.01}end)
		refuses("a ray going up",function(d)d.rays[1].from,d.rays[1].to=d.rays[1].to,d.rays[1].from end)
		refuses("ten rays",function(d)for _=1,7 do table.insert(d.rays,d.rays[1])end end)
		refuses("a hide of our own",function(d)table.insert(d.hides,"GV_Fix_Moat")end)
		refuses("a lantern kind",function(d)d.lanterns[1].kind="pink"end)
		refuses("totals",function(d)d.totals.tris+=1 end)
		refuses("bedOpaque",function(d)d.moat.bedOpaque=nil end)
		refuses("a texture url",function(d)d.textures.stone.color="tex/stone.png"end)
	end)

	test("budgets: 45k tris counting every instance, 10k a mesh, 40 meshes, 2k a far mesh",function()
		local b=Rules.budget(Fixture)
		assert(b.tris==26100 and b.groups==7 and #b.problems==0,("%d %d %d"):format(b.tris,b.groups,#b.problems))
		assert(Fixture.totals.tris==b.tris and Fixture.totals.meshes==b.groups)
		local function over(change,want)
			local data=deep(Fixture);change(data)
			local problems=table.concat(Rules.budget(data).problems," | ")
			assert(string.find(problems,want,1,true),want.." in: "..problems)
		end
		over(function(d)d.meshes.GV_Fix_TierNorth.tris=10001 end,"10001 tris (over 10000)")
		over(function(d)d.meshes.GV_Fix_FarEast.tris=2001 end,"far band 2001")
		over(function(d)for i=1,34 do d.meshes["GV_Extra"..i]=d.meshes.GV_Fix_Moat end end,"41 mesh groups")
		over(function(d)for _=1,7 do table.insert(d.instances,{mesh="GV_Fix_Trunk",pivot={0,0,0},yaw=0,scale=1})end end,"ring 47100 tris")
		-- The real data, once confirmed, keeps the same budgets.
		if Rules.validate(Placeholder)then assert(#Rules.budget(Placeholder).problems==0,table.concat(Rules.budget(Placeholder).problems," | "))end
	end)

	test("clearances: the moat under -25, the mid band 45 past the rim, balloons under the canopy, rays clear",function()
		local problems=Rules.clearances(Fixture,ctx)
		assert(#problems==0,table.concat(problems," | "))
		-- The balloons' highest top (DriftLanterns high_falls: the floor, 98 over, its bob and lift, its envelope).
		local top=-math.huge
		for _,place in ipairs(Lanterns.Places)do top=math.max(top,Rules.balloonTop(Lanterns,Layout,place))end
		local high=Lanterns.Places[7]
		assert(high.id=="high_falls"and near(Rules.balloonTop(Lanterns,Layout,high),Layout.FloorTop+98+1.5+.4+1.8*1.52),tostring(top))
		assert(top<Fixture.canopyBottomY)
		local function clash(change,want)
			local data=deep(Fixture);change(data)
			local found=table.concat(Rules.clearances(data,ctx)," | ")
			assert(string.find(found,want,1,true),want.." in: "..found)
		end
		clash(function(d)d.moat.surfaceY=-20 end,"moat surfaceY -20")
		clash(function(d)d.meshes.GV_Fix_TierNorth.minRimDist=40 end,"GV_Fix_TierNorth: 40 past the rim")
		clash(function(d)d.canopyBottomY=100 end,"balloon high_falls")
		clash(function(d)d.rays[1].to={-10,5,-30}end,"ray 1 ends")
		clash(function(d)local c=Values.Dome.center;d.rays[2].to={c.X,c.Y+3,c.Z};d.rays[2].from={c.X,c.Y+150,c.Z}end,"ray 2 passes")
		clash(function(d)d.rays[3].to={-5.5,8,62};d.rays[3].from={-5.5,160,62}end,"Water_SkyFalls")
		assert(Rules.segmentDistance(Vector3.new(0,0,0),Vector3.new(10,0,0),Vector3.new(5,3,0),Vector3.new(5,3,0))==3)
		if Rules.validate(Placeholder)then
			local real=Rules.clearances(Placeholder,ctx)
			assert(#real==0,table.concat(real," | "))
		end
	end)

	test("layout: placed meshes at their centres, instances on their pivots, the pi turn, maxLevel drops",function()
		local rows=GroveWorld.layout(Fixture,0)
		assert(#rows==5+6,"rows "..#rows)
		for _,row in ipairs(rows)do
			if row.instance then
				local data=Fixture.instances[row.instance]
				local mesh=Fixture.meshes[data.mesh]
				local back=CFrame.Angles(0,data.yaw,0):VectorToObjectSpace(row.cframe.Position-v(data.pivot))/data.scale
				assert((back-v(mesh.pivotToCentre)).Magnitude<1e-3,row.name)
				assert((row.size-v(mesh.size)*data.scale).Magnitude<1e-3)
				local want=CFrame.Angles(0,data.yaw,0)*GroveWorld.Turn
				assert((row.cframe.LookVector-want.LookVector).Magnitude<1e-3,"turned")
			else
				assert((row.cframe.Position-v(row.mesh.center)).Magnitude<1e-3)
				assert((row.cframe.LookVector-GroveWorld.Turn.LookVector).Magnitude<1e-3,"the import's turn")
			end
		end
		local level2=GroveWorld.layout(Fixture,2)
		assert(#level2==10,"level 2 drops the vines")
		for _,row in ipairs(level2)do assert(row.name~="GV_Fix_Vines")end
		local flat=deep(Fixture);flat.turnApplied=false
		for _,row in ipairs(GroveWorld.layout(flat,0))do
			if not row.instance then assert((row.cframe.LookVector-Vector3.new(0,0,-1)).Magnitude<1e-3,"no turn")end
		end
		assert(GroveWorld.lanternKind(Fixture,"GV_Fix_Lamps",CFrame.new(140,20,-8))=="warm")
		assert(GroveWorld.lanternKind(Fixture,"GV_Fix_Lamps",CFrame.new(-120,22,40))=="aqua")
	end)

	test("build: one EggDropGrove folder, nothing collides or casts, lanterns and falls, level 2, destroy",function()
		local parent=Instance.new("Folder")
		assert(not pcall(GroveWorld.build,{data=Placeholder,templates=templates(Fixture),parent=parent}),"the placeholder builds nothing")
		local ok=pcall(GroveWorld.build,{data=Fixture,templates=templates(Fixture,"GV_Fix_Crown"),parent=parent})
		assert(not ok and #parent:GetChildren()==0,"a missing template leaves nothing")
		local gains={}
		local built=GroveWorld.build({data=Fixture,templates=templates(Fixture),parent=parent,level=0,reduced=false,
			fallTexture="rbxassetid://1",daylight=function()return .9 end,setSunRays=function(g)table.insert(gains,g)end})
		assert(built.folder.Parent==parent and built.folder.Name=="EggDropGrove"and built.moatY==-26)
		assert(#built.parts==11)
		for _,p in ipairs(built.parts)do
			assert(p.Anchored==true and p.CanCollide==false and p.CanQuery==false and p.CanTouch==false and p.CastShadow==false,p.Name)
			assert(p:GetAttribute("WorldMesh")==true and type(p:GetAttribute("GroveMaxLevel"))=="number")
		end
		assert(#built.lanterns==1 and built.lanterns[1].kind=="warm")
		assert(#built.falls==1 and built.falls[1].Name=="GV_Fix_Falls_1"and built.falls[1].TextureSpeed==GroveWorld.Falls.speed)
		built.still(true)
		assert(built.falls[1].TextureSpeed==0,"Reduced Motion: the falls stand still")
		built.still(false)
		built.setLevel(2)
		assert(#built.parts==10,"level 2 takes the vines down")
		for _,p in ipairs(built.parts)do assert(p.Name~="GV_Fix_Vines")end
		built.setLevel(1)
		assert(built.level==2,"the level never comes back down")
		built.destroy()
		assert(built.folder.Parent==nil)
	end)

	test("light: ray fade by the garden hour's phase (day, night cyan, 0 at dawn and golden), hour off by daylight",function()
		local function look(phase,from,k)return Light.phaseLook({phase=phase,from=from,k=k})end
		assert(look("day").weight==1 and look("day").night==false)
		assert(look("night").weight==1 and look("night").night==true,"cyan at night")
		assert(look("dawn").weight==0 and look("golden").weight==0)
		assert(near(look("day","dawn",.5).weight,.5)and look("day","dawn",.5).night==false)
		assert(near(look("golden","day",.25).weight,.75)and look("golden","day",.25).night==false)
		assert(near(look("night","golden",.25).weight,.25)and look("night","golden",.25).night==true)
		assert(near(look("dawn","night",.5).weight,.5)and look("dawn","night",.5).night==true,"the night's rays fade into dawn")
		-- The real clock: day hold, night hold, golden hold, the dawn blend out of night.
		assert(Light.phaseLook(Hour.phase(1000)).weight==1)
		local night=Light.phaseLook(Hour.phase(3200))
		assert(night.weight==1 and night.night)
		assert(Light.phaseLook(Hour.phase(2600)).weight==0)
		local dawn=Hour.phase(30)
		assert(dawn.phase=="dawn"and dawn.from=="night")
		assert(near(Light.phaseLook(dawn).weight,1-dawn.k)and Light.phaseLook(dawn).night)
		assert(Light.daylightLook(.9).weight==1 and not Light.daylightLook(.9).night,"Aero alone reads .9")
		assert(Light.daylightLook(Hour.Holds.night.Daylight).weight==1 and Light.daylightLook(.12).night)
		assert(Light.daylightLook(.55).weight==0 and Light.daylightLook(.3).weight==0 and Light.daylightLook(nil).weight==0)
		assert(Light.rayClear(1)==.8 and Light.rayClear(0)==1 and near(Light.rayClear(.5),.9))
		assert(Light.lanternsLit(.25)==true and Light.lanternsLit(.35)==false and Light.lanternsLit(nil)==false)
	end)

	test("light: counts by level and device, motes and bubbles off, Reduced Motion stills the rays",function()
		assert(Light.rayCount(9,0,false)==9 and Light.rayCount(9,0,true)==5,"at most 5 on a phone")
		assert(Light.rayCount(9,1,false)==5 and Light.rayCount(9,1,true)==3,"level 1: half")
		assert(Light.rayCount(9,2,false)==0 and Light.rayCount(3,2,true)==0,"level 2: none")
		assert(table.concat(Light.rayPick(9,5),",")=="1,2,4,6,8"and #Light.rayPick(3,3)==3 and #Light.rayPick(3,0)==0)
		assert(Light.motesOn(0,false)and not Light.motesOn(1,false)and not Light.motesOn(0,true))
		assert(Light.bubblesOn(1,false)and not Light.bubblesOn(2,false)and not Light.bubblesOn(0,true))
		assert(Light.rayMoves(false)and not Light.rayMoves(true))
		local daylight=.9
		local folder=Instance.new("Folder")
		local lamp=Instance.new("MeshPart");lamp.Material="Plastic";lamp.Color=Color3.new(1,1,1)
		local light=Light.build({parent=folder,data=Fixture,lanterns={{part=lamp,kind="aqua",material="Plastic",color=lamp.Color}},
			level=0,reduced=false,phone=false,daylight=function()return daylight end,now=function()return 10 end})
		local function shown()
			local rays,motes=0,0
			for _,ray in ipairs(light.rays)do
				if ray.beam.Enabled then rays+=1 end
				if ray.motes.Enabled then motes+=1 end
			end
			return rays,motes
		end
		local rays,motes=shown()
		assert(rays==3 and motes==3,"day: every ray with its motes")
		for _,ray in ipairs(light.rays)do
			assert(ray.beam.FaceCamera==true and ray.beam.Segments==1 and ray.beam.LightInfluence==0 and ray.beam.TextureSpeed==Light.Ray.speed)
		end
		for _,bubble in ipairs(light.bubbles)do assert(bubble.shown and bubble.part.CanCollide==false)end
		assert(lamp.Material=="Plastic","no glow by day")
		light.update({reduced=true})
		rays,motes=shown()
		assert(rays==3 and motes==0,"Reduced Motion: rays stay, still; no motes")
		for _,ray in ipairs(light.rays)do assert(ray.beam.TextureSpeed==0)end
		for _,bubble in ipairs(light.bubbles)do assert(not bubble.shown and bubble.part.Transparency==1)end
		light.update({reduced=false,level=1})
		rays,motes=shown()
		assert(rays==2 and motes==0,"level 1: half the rays, no motes")
		light.update({level=2})
		rays=shown()
		assert(rays==0,"level 2: no rays")
		for _,bubble in ipairs(light.bubbles)do assert(not bubble.shown)end
		light.update({level=0})
		assert(light.level==2,"the level never comes back down")
		daylight=.2
		light.step(1)
		assert(lamp.Material==Enum.Material.Neon,"lit at night (DriftLanterns' rule)")
		daylight=.9
		light.step(1)
		assert(lamp.Material=="Plastic","back to its own by day")
		light.destroy()
		assert(light.folder.Parent==nil)
	end)

	test("light: the garden hour drives the rays (cyan at night, none at golden), the sun gate's SunRays gain",function()
		local s=1000
		local hour={on=function()return true end,time=function()return s end,phase=Hour.phase}
		local gate=Light.gateDirection(Fixture.sunGate)
		local facing=CFrame.lookAt(Vector3.new(0,10,0),Vector3.new(0,10,0)+gate)
		local camera=facing
		local gains={}
		local light=Light.build({parent=Instance.new("Folder"),data=Fixture,level=0,hour=hour,daylight=function()return .9 end,
			camera=function()return camera end,setSunRays=function(g)table.insert(gains,g)end,now=function()return 0 end})
		assert(light.look.weight==1 and light.look.night==false)
		assert(near(gains[#gains],Light.Sun.peak/Light.Sun.base,1e-2),"facing the gate: "..tostring(gains[#gains]))
		camera=CFrame.lookAt(Vector3.new(0,10,0),Vector3.new(0,10,0)-gate)
		light.step(1)
		assert(gains[#gains]==1,"looking away: back to 1")
		s=3200;light.step(1)
		assert(light.look.night==true and light.rays[1].night==true and light.rays[1].beam.Enabled,"night: cyan rays")
		camera=facing;light.step(1)
		assert(gains[#gains]==1,"no sun gain at night")
		s=2600;light.step(1)
		for _,ray in ipairs(light.rays)do assert(not ray.beam.Enabled,"golden: no rays")end
		s=1000;light.step(1);camera=facing;light.step(1)
		local before=#gains
		light.destroy()
		assert(#gains==before+1 and gains[#gains]==1,"destroy gives the SunRays back")
		assert(near(Light.sunGain(gate,gate),.08/.03,1e-6)and Light.sunGain(Vector3.new(0,-1,0),gate)==1 and Light.sunGain(nil,gate)==1)
		local d=Light.gateDirection({az=0,el=90})
		assert(near(d.Y,1)and near(Light.gateDirection({az=90,el=0}).Z,-1),"az toward -Z")
		local path={Vector3.new(0,0,0),Vector3.new(10,0,0)}
		assert(near(Light.pathPoint(path,10,0,0).X,0)and near(Light.pathPoint(path,10,2.5,0).X,5)and near(Light.pathPoint(path,10,7.5,0).X,5))
		assert(near(Light.pathPoint(path,10,10,0).X,0),"one loop a period")
	end)

	test("Sky Falls is cut at the moat (not extended); without a grove it keeps its full drop",function()
		local sky
		for _,sheet in ipairs(V7.beams.sheets)do if sheet.name==Values.Waterfall.Sky then sky=sheet end end
		assert(sky and sky.bottom[2]==-68)
		local fall={top=v(sky.top),bottom=v(sky.bottom),width0=sky.width0,width1=sky.width1}
		local cut=Falls.cut(fall,-26)
		assert(near(cut.bottom.Y,-26)and near(cut.top.Y,3.25),"ends at the moat")
		local f=(3.25+26)/(3.25+68)
		assert(near(cut.width1,sky.width0+(sky.width1-sky.width0)*f)and fall.bottom.Y==-68,"the sheet's own shape, a new table")
		assert(Falls.cut(fall,nil)==fall and Falls.cut(fall,-80)==fall and Falls.cut(fall,10)==fall)
	end)

	test("WorldMotion: a part or emitter the grove hides stops stepping",function()
		local m=Motion.new(workspace)
		m.reduced=function()return false end
		m.sceneOn=function()return false end
		local function mover(hidden)
			local p=Instance.new("BasePart");p.Size=Vector3.new(1,1,1);p.CFrame=CFrame.new(0,0,0)
			if hidden then p:SetAttribute("GroveHidden",true)end
			p.Parent=Instance.new("Folder")
			table.insert(m.entries,{part=p,kind="bob",rest=CFrame.new(0,0,0),amp=2,period=4,phase=.25,far=true})
			return p
		end
		local shown,hidden=mover(false),mover(true)
		local e1,e2=Instance.new("ParticleEmitter"),Instance.new("ParticleEmitter")
		e1.Enabled,e2.Enabled=false,false
		e2:SetAttribute("GroveHidden",true)
		m.emitters={e1,e2}
		m.still=nil -- as bind leaves it: the first moving pass switches the emitters on
		m:apply(0)
		assert(near(shown.CFrame.Position.Y,2)and hidden.CFrame.Position.Y==0,"the hidden one stays put")
		assert(e1.Enabled==true and e2.Enabled==false,"the hidden emitter stays off")
	end)

	test("AeroWorld: the grove stands after its preload, hides the backdrop in its own records, gives it all back",function()
		if not offline then return end -- the room fixtures are offline mocks
		local AeroWorld=require(client.AeroWorld)
		local world=Instance.new("Folder");world.ChildAdded=signal();world.ChildRemoved=signal()
		local lighting=Instance.new("Lighting")
		local rays=Instance.new("SunRaysEffect");rays.Name="HollowSunRays";rays.Intensity=.03;rays.Parent=lighting
		local room=Instance.new("Folder");room.Name="EggDropLounge";room.ChildAdded=signal();room.ChildRemoved=signal()
		local meshes=Instance.new("Folder");meshes.Name="World";meshes.DescendantAdded=signal();meshes.DescendantRemoving=signal()
		local flow=Instance.new("Folder");flow.Name="WaterFlow";flow.DescendantAdded=signal();flow.DescendantRemoving=signal()
		meshes.Parent=room;flow.Parent=room
		local function backdrop(name)
			local p=Instance.new("BasePart");p.Name=name;p.LocalTransparencyModifier=0;p.Transparency=0;p.Parent=meshes
			return p
		end
		local cloud=backdrop("W7_Backdrop__cloud_1")
		local foam=backdrop("W7_Water__cloud")
		local skin=Instance.new("Texture");skin.Name="Skin";skin.LocalTransparencyModifier=0;skin.Parent=foam
		local keep=backdrop("W7_Underside__cliff_rock")
		local anchor=Instance.new("Part");anchor.Parent=flow
		local sheet=Instance.new("Beam");sheet.Name="Water_SkyFalls";sheet.Enabled=true;sheet.Parent=anchor
		room.Parent=world
		local on,changed=true,signal()
		local builds={}
		local warned={}
		local function nothing()return signal()end
		local self=AeroWorld.new({world=world,lighting=lighting,data=V7,
			clock={now=function()return 0 end,apply=function()end,daylight=function()return .9 end},
			switch={on=function()return true end,changed=nothing,trees=function()return "lime"end,treesChanged=nothing},
			level=function()return 0 end,reduced=function()return false end,reducedChanged=nothing,sceneChanged=nothing,
			camera=function()return nil end,defer=function(fn)fn()end,delay=function()end,spawn=function(fn)fn()end,
			preload=function()return true end,warn=function(text)table.insert(warned,text)end,
			kitData=function()return nil end,templates=function()return nil end,trunks=function()return nil end,
			additions={build=function(options)
				table.insert(builds,options.moat or false)
				return{still=function()end,destroy=function()end}
			end},
			groveOn=function()return on end,groveChanged=function()return changed end,groveData=function()return Fixture end,
			groveTemplates=function()return templates(Fixture)end,groveCamera=function()return nil end,phone=function()return false end})
		-- The placeholder: nothing built, nothing said.
		local quiet=AeroWorld.new({world=Instance.new("Folder"),lighting=lighting,data=V7,groveData=function()return Placeholder end,
			groveOn=function()return true end,groveTemplates=function()return templates(Fixture)end,spawn=function(fn)fn()end,
			preload=function()return true end,warn=function(text)table.insert(warned,text)end,level=function()return 0 end})
		quiet.room,quiet.enabled=room,true
		quiet:buildGrove()
		assert(quiet.grove==nil and #warned==0,"placeholder: quiet")
		quiet.room,quiet.enabled=nil,false

		self:enable()
		assert(self.grove and self.grove.folder.Parent==world and self.grove.folder.Name=="EggDropGrove","stands beside the lounge")
		assert(self.grove.folder.Parent~=room)
		assert(cloud.LocalTransparencyModifier==1 and cloud:GetAttribute("GroveHidden")==true,"the backdrop hidden")
		assert(cloud.Transparency==0,"Transparency is never the grove's")
		assert(foam.LocalTransparencyModifier==1 and skin.LocalTransparencyModifier==1,"Sky Falls' cloud foam and its skin")
		assert(sheet.Enabled==false and sheet:GetAttribute("GroveHidden")==true,"Sky Falls' server sheet off")
		assert(keep.LocalTransparencyModifier==0,"the underside stays")
		assert(builds[#builds]==-26 and builds[#builds-1]==false,"the additions rebuilt with the moat: "..tostring(builds[#builds]))
		assert(next(self.hidden)==nil,"never the kit's records")
		-- Streaming: a backdrop piece that comes back later is hidden too.
		local late=Instance.new("BasePart");late.Name="W7_IsletsA__bark";late.LocalTransparencyModifier=0;late.Parent=meshes
		meshes.DescendantAdded:Fire(late)
		assert(late.LocalTransparencyModifier==1,"the late pass")
		-- The sun gate's gain goes through the look.
		self.look.setSunRays(2)
		assert(near(rays.Intensity,.06),"SunRays x2: "..tostring(rays.Intensity))
		self.look.setSunRays(1)
		assert(near(rays.Intensity,.03))
		-- Off: everything back, the folder gone, Sky Falls full length again.
		local folder=self.grove.folder
		on=false;changed:Fire()
		assert(self.grove==nil and folder.Parent==nil)
		assert(cloud.LocalTransparencyModifier==0 and cloud:GetAttribute("GroveHidden")==nil)
		assert(foam.LocalTransparencyModifier==0 and skin.LocalTransparencyModifier==0 and late.LocalTransparencyModifier==0)
		assert(sheet.Enabled==true and sheet:GetAttribute("GroveHidden")==nil)
		assert(next(self.groveHidden)==nil,"no records left")
		assert(builds[#builds]==false,"the additions rebuilt without the moat")
		-- On again, then the whole layer off: the same.
		on=true;changed:Fire()
		assert(self.grove and cloud.LocalTransparencyModifier==1)
		folder=self.grove.folder
		self:disable()
		assert(self.grove==nil and folder.Parent==nil and cloud.LocalTransparencyModifier==0 and sheet.Enabled==true)
		assert(#warned==0,"no warnings: "..table.concat(warned," | "))
	end)

	test("mount: GroveKit goes to ReplicatedStorage only where the Aero and grove ceilings pass",function()
		if not offline then return end
		local AeroConfig=offline.new.require(offline.new.server.AeroConfig)
		local function store(names)
			local kids={}
			local self={kids=kids}
			function self:FindFirstChild(name)return kids[name]end
			for _,name in ipairs(names)do
				kids[name]={Clone=function()return setmetatable({},{__newindex=function(_,key,value)
					if key=="Parent"then value.kids[name]=true end
				end})end}
			end
			return self
		end
		local from,to=store({"AeroKit","GroveKit"}),store({})
		AeroConfig.mountKit({ceiling=function()return true end,groveCeiling=function()return false end,from=from,to=to})
		assert(to.kids.AeroKit and not to.kids.GroveKit,"no grove ceiling: not copied")
		AeroConfig.mountKit({ceiling=function()return true end,groveCeiling=function()return true end,from=from,to=to})
		assert(to.kids.GroveKit,"copied")
		local none=store({})
		AeroConfig.mountKit({ceiling=function()return false end,groveCeiling=function()return true end,from=from,to=none})
		assert(next(none.kids)==nil,"no Aero ceiling: nothing")
	end)

	return{passed=#cases,cases=cases}
end
