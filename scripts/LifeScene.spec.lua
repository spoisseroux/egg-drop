-- Studio Client. The garden's scene, the parts (LifeScene through GardenLife; beta 14 QA W3, GARDEN-LIFE-BUILD-PLAN
-- section 4) with a fake switch, clock, camera, Heartbeat and data: nothing with `scene` off (or the `life` ceiling off);
-- on, inert hidden parts in GardenLife's folder moved by its one BulkMoveTo; dapple under the nearest crowns by daylight;
-- koi, a far flock and dragonflies by level (none with Reduced Motion); the lamps one by one on the hour's clock with
-- PointLights at level 0 only; the shooting star; parked hides it all; the switch off destroys it; a step that throws
-- drops the scene with one warning and life goes on.
-- Usage: require(PlayerScripts.Client.ZZSpecs.LifeScene)(PlayerScripts.Client); offline in
-- scripts/run_dash_server_specs.py (DASH_SPECS="LifeScene").
return function(client)
	local Life=require(client.GardenLife)
	local Sim=require(client.LifeSceneSim)
	local Hour=require(game:GetService("ReplicatedStorage").Shared.GardenHour)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local T0=1795300000
	local function signal()
		local s={list={}}
		function s:Connect(fn)
			local c={Connected=true}
			function c:Disconnect()self.Connected=false;local at=table.find(s.list,fn);if at then table.remove(s.list,at)end end
			table.insert(s.list,fn)
			return c
		end
		function s:Fire(...)for _,fn in ipairs(table.clone(s.list))do fn(...)end end
		return s
	end
	local cross=Sim.crossings(function(s)return Hour.phase(s).daylight end)
	local rigs={}
	local function rig(options)
		options=options or {}
		local r={on=true,scene=options.scene~=false,ceiling=options.ceiling~=false,now=options.now or T0,level=options.level or 0,
			hatch=false,mode="Room",reduced=options.reduced==true,warned={},clock=options.clock,daylight=options.daylight}
		r.changed=signal();r.beat=signal()
		r.camera=CFrame.lookAt(Vector3.new(60,10,-50),Vector3.new(64,4,-66))
		r.player=Vector3.new(60,4,-50)
		r.world=Instance.new("Folder");r.world.Name="_LifeSceneSpec";r.world.Parent=workspace
		local data={crowns={Vector3.new(55,4,-48),Vector3.new(70,4,-48),Vector3.new(40,4,-60),Vector3.new(90,4,-40),
				Vector3.new(30,4,-30),Vector3.new(-50,4,0),Vector3.new(-60,4,0),Vector3.new(-70,4,0)},
			boxes={{frame=CFrame.new(64.5,3.2,-66),hx=13.5,hz=12,y=3.2},{frame=CFrame.new(35,3.2,-40),hx=10.5,hz=7.5,y=3.2}},
			hourClock=function()return r.clock end,hourDaylight=function(s)return Hour.phase(s).daylight end,
			art=function(key)return "rbxassetid://"..#key end,
			-- Beta 17 1.3 B: a stone (its ring only while the stones are built) and a pier.
			obstacles={{x=50,z=-52,size=2.6,stone=true},{x=40,z=-48,size=1.6}},stones=function()return r.stones==true end}
		if options.broken then data.crowns={"not a place"}end
		r.life=Life.mount({world=r.world,heartbeat=r.beat,seed=11,
			alive={ceiling=function(f)return f=="life"and r.ceiling end,
				on=function(f)return(f=="life"and r.on)or(f=="scene"and r.on and r.scene)end,changed=function()return r.changed end},
			now=function()return r.now end,camera=function()return r.camera end,root=function()return r.player end,
			level=function()return r.level end,hatching=function()return r.hatch end,mode=function()return r.mode end,
			dash=function()return nil end,modalOpen=function()return false end,reduced=function()return r.reduced end,
			move=function(parts,frames)for i,p in ipairs(parts)do p.CFrame=frames[i]end end,
			spots={Perches=0,Landings={},Crowns={}},patches={},stations={Vector3.new(400,4,400)},pad={x=500,z=500,r=3},course={600,600,700,600},
			crowns=function()return "lime"end,warn=function(text)table.insert(r.warned,text)end,groundY=function()return 4 end,
			safe=function()return true end,finds={},kerbs={},pets=function()return{}end,cover={},leaves=function()return false end,
			report=function()end,banks={},scene=data,heading=function()return nil end,
			daylight=function()return r.daylight end})
		function r.step(seconds)
			for _=1,math.floor(seconds*30+.5)do r.now+=1/30;if r.clock then r.clock+=1/30 end;r.beat:Fire(1/30)end
		end
		function r.folder()return r.world:FindFirstChild(Life.Folder)end
		function r.sceneParts()
			local out={}
			local folder=r.folder()
			for _,p in ipairs(folder and folder:GetChildren()or {})do if string.sub(p.Name,1,5)=="Scene"then table.insert(out,p)end end
			return out
		end
		function r.shown(prefix)
			local n=0
			for _,p in ipairs(r.sceneParts())do
				-- The lamp and star anchors are still parts at the origin (attachments on them carry the halos and the beam).
				if string.sub(p.Name,1,#prefix)==prefix and p.Name~="SceneLamps"and p.Name~="SceneStar"and p.CFrame.Position.Y<4000 then n+=1 end
			end
			return n
		end
		table.insert(rigs,r)
		return r
	end

	local ok,problem=pcall(function()
		test("scene off, or the life ceiling off: no scene parts at all",function()
			local off=rig({scene=false})
			off.step(3)
			assert(#off.sceneParts()==0 and off.life.sceneParts==nil)
			local live=rig({ceiling=false})
			assert(live.life==nil,"the live place: GardenLife never mounts")
		end)

		test("on: inert parts in GardenLife's folder, hidden until used; dapple under the 6 nearest crowns (3 at level 1), .55 by day",function()
			local r=rig()
			local parts=r.sceneParts()
			-- dapple, koi, rings, flock, dragonflies, lamp and star anchors; beta 17: 8 leaves and 2 flow rings.
			assert(#parts==6+3+3+10+6+2+8+2,"scene parts: "..#parts)
			for _,p in ipairs(parts)do
				assert(p.Anchored and not p.CanCollide and not p.CanQuery and not p.CanTouch and not p.CastShadow,p.Name)
			end
			r.step(1.2)

			assert(r.shown("SceneDapple")==6,"6 plates: "..r.shown("SceneDapple"))
			r.step(1)
			for slot=1,6 do
				local plate=r.folder():FindFirstChild("SceneDapple"..slot)
				local decal=plate:FindFirstChildOfClass("Decal")
				assert(math.abs(decal.Transparency-.55)<.02,"shade by day: "..decal.Transparency)
			end
			for slot=1,6 do
				assert(r.folder():FindFirstChild("SceneDapple"..slot).CFrame.Position.X>-55,"the two farthest crowns are not picked")
			end
			r.level=1;r.step(1.5)
			assert(r.shown("SceneDapple")==3,"level 1: 3")
			-- Night (daylight under .30): the shade is gone.
			local night=rig({daylight=.12})
			night.step(2.5)
			assert(night.shown("SceneDapple")==0,"no dapple at night")
			-- Reduced Motion: static shade.
			local still=rig({reduced=true})
			still.step(1.5)
			local plate=still.folder():FindFirstChild("SceneDapple1")
			local at=plate.CFrame.Position
			still.step(2)
			assert(still.shown("SceneDapple")==6 and plate.CFrame.Position==at,"static")
		end)

		test("koi: 3 in the pool at level 0, 2 at level 1, none with Reduced Motion; a rise ring within 15 s",function()
			local r=rig()
			r.step(1)
			assert(r.shown("SceneKoi")==3)
			for k=1,3 do
				local at=r.folder():FindFirstChild("SceneKoi"..k).CFrame.Position
				-- STUDIO-CHECK-R5: the over fallback (the pool mesh is opaque): on the surface + .02, decal .35.
				assert(math.abs(at.Y-(3.2+.02))<1e-6 and(Vector3.new(at.X,0,at.Z)-Vector3.new(64.5,0,-66)).Magnitude<12,"in the pool")
			end
			local rose=false
			for _=1,16 do r.step(1);if r.shown("SceneRipple")>0 then rose=true end end
			assert(rose,"a rise ring")
			r.level=1;r.step(.5);assert(r.shown("SceneKoi")==2)
			r.reduced=true;r.step(.5);assert(r.shown("SceneKoi")==0 and r.shown("SceneRipple")==0)
		end)

		test("the far flock: 10 wing plates in flight by day (6 at level 1), none at night or with Reduced Motion",function()
			local n=math.floor(T0/Sim.Flock.slot)+2
			local start=Sim.flockStart(n)
			local r=rig({now=start+2})
			r.step(.5)
			assert(r.shown("SceneFlock")==10,"5 birds: "..r.shown("SceneFlock"))
			r.level=1;r.step(.5);assert(r.shown("SceneFlock")==6)
			r.step(Sim.Flock.length);assert(r.shown("SceneFlock")==0,"gone after 25 s")
			local night=rig({now=start+2,daylight=.12})
			night.step(.5);assert(night.shown("SceneFlock")==0)
			local still=rig({now=start+2,reduced=true})
			still.step(.5);assert(still.shown("SceneFlock")==0)
		end)

		test("dragonflies: 2 by day over the water (1 at level 1), none at night",function()
			local r=rig()
			r.step(2)
			assert(r.shown("SceneDragonfly")==6,"2 flies, 3 parts each: "..r.shown("SceneDragonfly"))
			r.level=1;r.step(.5);assert(r.shown("SceneDragonfly")==3)
			local night=rig({daylight=.12})
			night.step(2);assert(night.shown("SceneDragonfly")==0)
		end)

		test("lamps: one by one from the hour's dusk, PointLights on the nearest 4 at level 0 only; none with the hour off",function()
			local hourStart=math.floor(T0/3600)*3600
			local r=rig({clock=hourStart+cross.down-.5})
			r.step(.5)
			assert(r.life.sceneParts:counts().lamps==0,"before dusk")
			r.step(.5)
			local early=r.life.sceneParts:counts().lamps
			r.step(3)
			local counts=r.life.sceneParts:counts()
			assert(early>=1 and early<=3 and counts.lamps==7,"one by one: "..early.." then "..counts.lamps)
			assert(counts.lights==4,"4 PointLights: "..counts.lights)
			r.level=1;r.step(.2)
			assert(r.life.sceneParts:counts().lights==0,"no PointLights at level 1")
			local off=rig({clock=nil})
			off.step(1)
			assert(off.life.sceneParts:counts().lamps==0,"the hour off: none")
		end)

		test("the shooting star: the beam is on only for its streaks (shared timing), never with Reduced Motion",function()
			local hour=math.floor(T0/3600)
			local times=Sim.starTimes(hour)
			local r=rig({clock=times[1]-.2})
			r.step(.4)
			assert(r.life.sceneParts:counts().star==true,"on in the streak")
			r.step(1)
			assert(r.life.sceneParts:counts().star==false,"off after .7 s")
			local still=rig({clock=times[1]-.2,reduced=true})
			still.step(.4)
			assert(still.life.sceneParts:counts().star==false)
		end)

		test("beta 17 1.3 B: 6 leaves on the water (3 at level 1, none with Reduced Motion); rings pulse, round a stone only while it stands",function()
			local r=rig()
			r.step(1)
			local counts=r.life.sceneParts:counts()
			assert(counts.leaves==6,"6 leaves: "..counts.leaves)
			assert(counts.flows==1,"the pier's ring, not the stone's: "..counts.flows)
			local pier=r.folder():FindFirstChild("SceneFlow2")
			local sizes={}
			for _=1,12 do r.step(.25);table.insert(sizes,pier.Size.X)end
			local lo,hi=math.huge,-math.huge
			for _,v in ipairs(sizes)do lo=math.min(lo,v);hi=math.max(hi,v)end
			assert(lo>=1.6*1.15-.05 and hi<=1.6*1.5+.05 and hi-lo>.3,"pulses "..lo.." "..hi)
			assert(math.abs(pier.CFrame.Position.Y-(3.2+.03))<1e-6 and math.abs(pier.CFrame.Position.X-40)<1e-6)
			r.stones=true;r.step(1.2)
			assert(r.life.sceneParts:counts().flows==2,"the stone's ring once it stands")
			r.level=1;r.step(.5)
			assert(r.life.sceneParts:counts().leaves==3,"level 1: 3")
			local still=rig({reduced=true})
			still.step(1)
			assert(still.life.sceneParts:counts().leaves==0,"no leaves with Reduced Motion")
			local ring=still.folder():FindFirstChild("SceneFlow2")
			local size=ring.Size.X
			still.step(1.3)
			assert(math.abs(size-1.6*1.2)<.03 and ring.Size.X==size,"rings still at 1.2 x")
		end)

		test("parked hides every moving scene part; the switch off destroys the scene; on again builds it",function()
			local r=rig()
			r.step(2)
			assert(r.shown("SceneDapple")>0 and r.shown("SceneKoi")>0)
			r.hatch=true;r.step(.5)
			assert(r.shown("Scene")==0,"parked: all hidden")
			r.hatch=false;r.step(1.5)
			assert(r.shown("SceneDapple")>0,"back")
			r.scene=false;r.changed:Fire();r.step(.2)
			assert(#r.sceneParts()==0 and r.life.sceneParts==nil,"off: gone")
			r.scene=true;r.changed:Fire();r.step(1.5)
			assert(#r.sceneParts()>0 and r.life.sceneParts~=nil,"on again")
		end)

		test("a scene step that throws: the scene is dropped with one warning; the rest of garden life goes on",function()
			local r=rig({broken=true})
			r.step(2)
			assert(r.life.enabled and r.life.sceneParts==nil and #r.sceneParts()==0,"dropped")
			assert(#r.warned==1 and string.find(r.warned[1],"scene stopped",1,true),tostring(r.warned[1]))
			r.step(3)
			assert(#r.warned==1 and r.life.enabled,"once")
			table.clear(r.warned)
		end)
	end)
	for _,r in ipairs(rigs)do
		if r.life then pcall(function()r.life:destroy()end)end
		r.world:Destroy()
	end
	assert(ok,problem)
	for _,r in ipairs(rigs)do assert(#r.warned==0,"stopped: "..tostring(r.warned[1]))end
	return{passed=#cases,cases=cases}
end
