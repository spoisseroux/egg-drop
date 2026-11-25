-- The upper tier host (UPPER-TIER-BUILD-PLAN.md, architect verdict applied): nothing on live; bad ring data keeps it
-- closed; open builds, adds the pet-blocked footprints, stands only the found ring boxes aside; a missing box keeps it
-- closed with one warning; close evacuates first, puts back only the boxes that still exist, destroys everything, in
-- one step; a rebuilt lounge drops the state; three errors close it; the cliff path gated while closed, no terrace
-- without it. Fake room, ring, boards, clock and heartbeat.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.TierHost)(ServerScriptService.Server)
-- Offline: python scripts/run_dash_server_specs.py
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Tier=require(Shared.Tier)
	local Data=require(Shared.WorldV7Data)
	local Host=require(server.TierHost)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local ON={flags={Tier=true},studio=true}
	local OFF={flags={Tier=true},studio=true,on=false}
	local aside,before,after=Tier.ringAside(Data.perimeter)
	local LAWN=Vector3.new(40,7,50)

	local function lounge(options)
		options=options or {}
		local room=Instance.new("Model")
		local ring=Instance.new("Folder");ring.Name=Tier.Ring;ring.Parent=room
		for i=1,#Data.perimeter do
			if i~=options.missing then
				local box=Instance.new("Part");box.Name="Wall"..i;box.CanCollide=true;box.Parent=ring
			end
		end
		local regions=Instance.new("Folder");regions.Name="PetRegions";regions.Parent=room
		return room
	end
	local function rig(options)
		options=options or {}
		local c={now=0,boards={},placed={},arrivedAt={},warnings={},room=lounge(options)}
		local beat={list={}}
		function beat:Connect(fn)table.insert(self.list,fn);return{Disconnect=function()table.clear(self.list)end}end
		c.beat=beat
		c.host=Host.mount({boards=c.boards,room=function()return c.room end,heartbeat=beat,clock=function()return c.now end,
			perimeter=options.perimeter,
			read=function(board)if board.boom then error("read failed")end return board.view end,
			place=function(board,view,cframe)
				table.insert(c.placed,{board=board,cframe=cframe,open=c.host.open,ringOff=c.box(aside[1]).CanCollide==false})
				view.position=cframe.Position
			end,
			arrived=function(player,spot)c.arrivedAt[player]=spot end,
			warn=function(text)table.insert(c.warnings,text)end})
		function c.box(i)return c.room[Tier.Ring]:FindFirstChild("Wall"..i)end
		function c.player(id,at)
			local p={UserId=id}
			local board={player=p,mode="Room",closing=false,view={character={id=id},position=at or LAWN,lift=3}}
			c.boards[p]=board
			return p,board
		end
		function c.tick(dt)c.now+=dt or .2;for _,fn in ipairs(table.clone(beat.list))do fn()end end
		return c
	end
	local function blocked(room)
		local out={}
		for _,part in ipairs(room.PetRegions:GetChildren())do if part:GetAttribute("GardenBlockedRegion")==true then table.insert(out,part)end end
		return out
	end

	test("live: the build ceiling closed means no host, nothing connected, no world data read",function()
		Tier.inject({flags={Tier=true},studio=false,place=96451847774961})
		local beat={list={}}
		function beat:Connect(fn)table.insert(self.list,fn);return{Disconnect=function()end}end
		local read=false
		local perimeter=setmetatable({},{__index=function()read=true;return nil end,__len=function()read=true;return 0 end})
		assert(Host.mount({boards={},heartbeat=beat,perimeter=perimeter})==nil and #beat.list==0 and not read)
		Tier.inject({flags={Tier=false},studio=true})
		assert(Host.mount({boards={},heartbeat=beat})==nil and #beat.list==0)
		Tier.inject(nil)
	end)

	test("bad ring data (it throws, or no box meets the tier) keeps the tier closed with one warning, never an error",function()
		Tier.inject(ON)
		local c=rig({perimeter=setmetatable({},{__len=function()error("broken data")end})})
		c.tick();c.tick();assert(not c.host.open and #c.warnings==1 and not c.room:FindFirstChild(Tier.Model))
		local d=rig({perimeter={{center={500,0,500},size={5,10,1},yaw=0}}})
		d.tick();assert(not d.host.open and #d.warnings==1)
		Tier.inject(nil)
	end)

	test("code review: ring boxes that are not one run, or that wrap past 1 / n, keep the tier closed",function()
		Tier.inject(ON)
		local far={center={500,0,500},size={5,10,1},yaw=0}
		local hit={center={Tier.C.X,25,Tier.C.Z},size={5,10,1},yaw=0}
		for _,list in ipairs({{far,hit,far,hit,far},{hit,far,far,far},{far,far,far,hit}})do
			local c=rig({perimeter=list});c.tick()
			assert(not c.host.open and c.host.broken and #c.warnings==1)
		end
		assert(Tier.ringRunOk({3,4,5},9)and not Tier.ringRunOk({3,5},9)and not Tier.ringRunOk({1,2},9)and not Tier.ringRunOk({8,9},9))
		assert(not Tier.ringRunOk({},9)and not Tier.ringRunOk(nil,9))
		Tier.inject(nil)
	end)

	test("code review: a throw part-way through opening orphans nothing; the retry reuses the model and keeps each box's value",function()
		Tier.inject(ON)
		local c=rig()
		local footprints=Host.footprints
		Host.footprints=function()error("boom")end
		c.tick()
		Host.footprints=footprints
		assert(not c.host.open and c.host.errors==1)
		local models=0
		for _,child in ipairs(c.room:GetChildren())do if child.Name==Tier.Model then models+=1 end end
		assert(models==1)
		c.tick()
		models=0
		for _,child in ipairs(c.room:GetChildren())do if child.Name==Tier.Model then models+=1 end end
		assert(c.host.open and models==1 and c.box(aside[1]).CanCollide==false)
		Tier.inject(OFF);c.tick()
		assert(not c.room:FindFirstChild(Tier.Model)and c.box(aside[1]).CanCollide==true)
		Tier.inject(nil)
	end)

	test("on: the greybox, the pet-blocked footprints, only the found ring boxes stand aside, then open; off puts all back",function()
		Tier.inject(OFF)
		local c=rig()
		c.tick();assert(not c.host.open and not c.room:FindFirstChild(Tier.Model))
		Tier.inject(ON);c.tick()
		local model=c.room:FindFirstChild(Tier.Model)
		assert(c.host.open and model and #model:GetChildren()==#c.host.rows)
		for _,part in ipairs(model:GetChildren())do assert(part.Anchored==true and part.CanTouch==false and part:GetAttribute("WorldMesh")==true,part.Name)end
		local feet=blocked(c.room);assert(#feet==#Host.footprints()and #feet>=8)
		for _,part in ipairs(feet)do assert(part.CanCollide==false and part.CanQuery==false and part.Transparency==1)end
		for i=1,#Data.perimeter do
			assert(c.box(i).CanCollide==(table.find(aside,i)==nil),"ring box "..i)
		end
		c.tick();assert(#c.room:GetChildren()==3) -- the ring, the regions, one model
		Tier.inject(OFF);c.tick()
		assert(not c.host.open and model.Parent==nil and #blocked(c.room)==0)
		for i=1,#Data.perimeter do assert(c.box(i).CanCollide==true,"ring box "..i)end
		Tier.inject(nil)
	end)

	test("a missing ring box (stood aside or a neighbour) keeps it closed with one warning",function()
		Tier.inject(ON)
		for _,missing in ipairs({aside[3],before})do
			local c=rig({missing=missing});c.tick();c.tick()
			assert(not c.host.open and not c.room:FindFirstChild(Tier.Model)and #blocked(c.room)==0 and #c.warnings==1)
			for i=1,#Data.perimeter do local box=c.box(i);if box then assert(box.CanCollide==true)end end
		end
		Tier.inject(nil)
	end)

	test("off with people up there: each moved to the lawn by the path's foot while it is still open, then everything closed; the path stays",function()
		Tier.inject(ON)
		local c=rig();c.tick()
		local p=c.player(1,Tier.T(0,0,Tier.FloorY+3))
		local q=c.player(2,Tier.T(-30,10,Tier.FloorY+3))
		local r=c.player(3,LAWN)
		local onPath=c.player(5,Tier.path().points[30]+Vector3.new(0,3,0)) -- the cliff path is island: they walk down
		local _,closing=c.player(4,Tier.T(5,5,Tier.FloorY+3));closing.closing=true
		Tier.inject(OFF);c.tick()
		assert(#c.placed==2 and not c.arrivedAt[onPath])
		for _,m in ipairs(c.placed)do
			assert(m.open and m.ringOff,"moved after the tier closed")
			local at=m.cframe.Position
			assert((Vector3.new(at.X,0,at.Z)-Vector3.new(Tier.Evacuation.at.X,0,Tier.Evacuation.at.Z)).Magnitude<4)
			assert(not Tier.onIt(at))
		end
		assert((c.placed[1].cframe.Position-c.placed[2].cframe.Position).Magnitude>1)
		assert(c.arrivedAt[p]and c.arrivedAt[q]and not c.arrivedAt[r])
		assert(not c.host.open and c.box(aside[1]).CanCollide==true)
		Tier.inject(nil)
	end)

	test("the cliff path: closed, its foot and notch are gated (invisible, colliding); open, the gates go; no path, no terrace",function()
		Tier.inject(OFF)
		local c=rig();c.tick()
		local gates=c.room:FindFirstChild(Tier.Gates)
		assert(gates and #gates:GetChildren()==2 and not c.host.open)
		for _,part in ipairs(gates:GetChildren())do assert(part.CanCollide==true and part.Transparency==1 and part.Anchored==true,part.Name)end
		local foot=Tier.path().points[Tier.GateFoot]
		local at=gates:FindFirstChild("W7T_GateFoot").CFrame.Position
		assert((Vector3.new(at.X,0,at.Z)-Vector3.new(foot.X,0,foot.Z)).Magnitude<.01)
		Tier.inject(ON);c.tick()
		assert(c.host.open and c.room:FindFirstChild(Tier.Gates)==nil and gates.Parent==nil)
		Tier.inject(OFF);c.tick();assert(c.room:FindFirstChild(Tier.Gates))
		-- No sculpt on this server (no WorldBeta pack): never opens, nothing gated (there is no path to gate).
		Tier.inject({flags={Tier=true},studio=true,cliffDen=false})
		local d=rig();d.tick();d.tick()
		assert(not d.host.open and d.room:FindFirstChild(Tier.Model)==nil and d.room:FindFirstChild(Tier.Gates)==nil)
		Tier.inject(nil)
	end)

	test("close puts back only the ring boxes that still exist; a rebuilt lounge drops the state and builds fresh",function()
		Tier.inject(ON)
		local c=rig();c.tick()
		c.box(aside[2]):Destroy()
		Tier.inject(OFF);c.tick()
		assert(not c.host.open and c.box(aside[1]).CanCollide==true and c.box(aside[2])==nil)
		Tier.inject(ON);c.tick()
		assert(not c.host.open and #c.warnings==1) -- the box is gone now: stays closed
		local d=rig();d.tick();assert(d.host.open)
		local old=d.room
		d.room=lounge();d.tick()
		assert(d.host.open and d.room:FindFirstChild(Tier.Model)and d.box(aside[1]).CanCollide==false)
		assert(old:FindFirstChild(Tier.Model)) -- the old lounge's parts are left to go with it
		Tier.inject(nil)
	end)

	test("errors: three close it the same way (evacuated, ring back), and the heartbeat stops",function()
		Tier.inject(ON)
		local c=rig();c.tick()
		local _,b=c.player(1,Tier.T(0,0,Tier.FloorY+3))
		local stepWas=c.host.step
		c.host.step=function()error("boom")end
		c.tick();c.tick();assert(c.host.open and c.host.errors==2)
		c.tick()
		assert(c.host.dead and not c.host.open and #c.placed==1 and c.placed[1].board==b and c.box(aside[1]).CanCollide==true)
		assert(#c.beat.list==0)
		c.host.step=stepWas
		Tier.inject(nil)
	end)

	return{passed=#cases,cases=cases}
end
