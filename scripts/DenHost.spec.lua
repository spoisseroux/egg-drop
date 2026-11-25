-- The Play Den host (PLAY-DEN-BUILD-PLAN.md, architect verdict applied): nothing on live; open builds the greybox and the
-- pets' footprints, turns the blocker off (its own values kept) and only then writes Den_open; a missing blocker, one off
-- the mouth line or no layout keeps it closed with one warning; close clears Den_open first, moves everyone in the room,
-- the apron or the blocker's volume (and their pets) to the doorstep, then puts the blocker back and destroys
-- everything; the Hush open keeps it closed; a rebuilt lounge drops the state; three errors close it. Fake room, boards,
-- clock and heartbeat. Usage (Server): require(ServerScriptService.Server.ZZSpecs.DenHost)(ServerScriptService.Server)
-- Offline: python scripts/run_dash_server_specs.py
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Den=require(Shared.PlayDen)
	local Layout=require(Shared.DenLayout)
	local Data=require(Shared.WorldV7Data)
	local Host=require(server.DenHost)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local ON={flags={PlayDen=true},studio=true}
	local OFF={flags={PlayDen=true},studio=true,on=false}
	local P=Layout.Pocket
	local LAWN=Vector3.new(40,7,50)
	local INSIDE=Vector3.new(-7,7,-106)

	local function lounge(options)
		options=options or {}
		local room=Instance.new("Model")
		if not options.noBlocker then
			local b=Data.caveBlocker
			local blocker=Instance.new("BasePart");blocker.Name=Den.Blocker
			local at=Vector3.new(b.center[1],b.center[2],b.center[3])+(options.shift or Vector3.zero)
			blocker.Position=at;blocker.CFrame=CFrame.new(at);blocker.Size=Vector3.new(b.size[1],b.size[2],b.size[3])
			blocker.CanCollide,blocker.CanQuery=true,true
			blocker.Parent=room
		end
		local regions=Instance.new("Folder");regions.Name="PetRegions";regions.Parent=room
		return room
	end
	local function rig(options)
		options=options or {}
		local c={now=0,boards={},placed={},arrivedAt={},warnings={},carried={},log={},room=lounge(options),actors={},hush=false}
		local beat={list={}}
		function beat:Connect(fn)table.insert(self.list,fn);return{Disconnect=function()table.clear(self.list)end}end
		c.beat=beat
		c.host=Host.mount({boards=c.boards,room=function()return c.room end,heartbeat=beat,clock=function()return c.now end,
			garden={actors=c.actors},layout=options.layout or function()return P end,hushOpen=function()return c.hush end,
			read=function(board)if board.boom then error("read failed")end return board.view end,
			place=function(board,view,cframe)
				local blocker=c.room:FindFirstChild(Den.Blocker)
				table.insert(c.placed,{board=board,cframe=cframe,blockerOff=blocker==nil or blocker.CanCollide==false})
				table.insert(c.log,"place")
				view.position=cframe.Position
			end,
			carry=function(board,spot)table.insert(c.carried,{board=board,spot=spot});table.insert(c.log,"carry");return true end,
			petPosition=function(actor)return actor.at end,
			attribute=function(name,value)table.insert(c.log,name.."="..tostring(value)..(if c.host then " open="..tostring(c.host.open)else ""))end,
			arrived=function(player,spot)c.arrivedAt[player]=spot end,
			warn=function(text)table.insert(c.warnings,text)end})
		function c.blocker()return c.room:FindFirstChild(Den.Blocker)end
		function c.player(id,at,pet)
			local p={UserId=id}
			local board={player=p,mode="Room",closing=false,view={character={id=id},position=at or LAWN,lift=3}}
			c.boards[p]=board
			if pet then c.actors[id]={at=pet}end
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

	test("live: the build ceiling closed means no host, nothing connected, no attribute written",function()
		Den.inject({flags={PlayDen=true},studio=false,place=96451847774961})
		local beat={list={}}
		function beat:Connect(fn)table.insert(self.list,fn);return{Disconnect=function()end}end
		local wrote=false
		assert(Host.mount({boards={},heartbeat=beat,attribute=function()wrote=true end})==nil and #beat.list==0 and not wrote)
		Den.inject({flags={PlayDen=false},studio=true})
		assert(Host.mount({boards={},heartbeat=beat})==nil and #beat.list==0)
		Den.inject(nil)
	end)

	test("open: the greybox and footprints built, the blocker off (values kept), open, and only then Den_open",function()
		Den.inject(OFF);local c=rig();c.tick();c.tick()
		assert(not c.host.open and c.host:live()==nil and not c.room:FindFirstChild(Den.Model)and c.blocker().CanCollide)
		Den.inject(ON);c.tick()
		assert(c.host.open and c.host:live()==P and c.room:FindFirstChild(Den.Model))
		assert(c.blocker().CanCollide==false and c.blocker().CanQuery==false)
		assert(#blocked(c.room)==#Layout.footprints(P)and #blocked(c.room)>=4)
		assert(c.log[#c.log]=="Den_open=true open=true",c.log[#c.log])
		c.tick();c.tick();assert(#c.room:FindFirstChild(Den.Model):GetChildren()>0 and #blocked(c.room)==#Layout.footprints(P),"built once")
		Den.inject(nil)
	end)

	test("closed with one warning: no blocker, a blocker off the mouth line, no layout (bad CliffDenData)",function()
		Den.inject(ON)
		local a=rig({noBlocker=true});a.tick();a.tick();assert(not a.host.open and #a.warnings==1 and not a.room:FindFirstChild(Den.Model))
		local b=rig({shift=Vector3.new(0,0,12)});b.tick();b.tick();assert(not b.host.open and #b.warnings==1 and b.blocker().CanCollide)
		local c=rig({layout=function()return Layout.current({cliffDen=true,data={schema=9}})end})
		c.tick();c.tick();assert(not c.host.open and #c.warnings==1 and string.find(c.warnings[1],"schema"))
		for _,r in ipairs({a,b,c})do for _,line in ipairs(r.log)do assert(not string.find(line,"Den_open=true"))end end
		Den.inject(nil)
	end)

	test("close: Den_open cleared first, everyone in the room, apron or blocker volume moved with their pets, then the blocker back",function()
		Den.inject(ON);local c=rig()
		local inRoom,b1=c.player(1,INSIDE,Vector3.new(-7,4,-104))
		local onApron,b2=c.player(2,Vector3.new(-6,7,-97.5))
		local inMouth,b3=c.player(3,Vector3.new(-6,7,-101))
		local outside,b4=c.player(4,LAWN,Vector3.new(30,4,40))
		local onTop,b5=c.player(5,Vector3.new(-7,32,-106))
		c.tick();assert(c.host.open)
		table.clear(c.log)
		Den.inject(OFF);c.tick()
		assert(string.find(c.log[1],"Den_open=nil"),c.log[1])
		local moved={}
		for _,p in ipairs(c.placed)do moved[p.board]=true;assert(p.blockerOff,"moved before the blocker is back");assert(p.cframe.Position.Z>-89)end
		assert(moved[b1]and moved[b2]and moved[b3]and not moved[b4]and not moved[b5])
		assert(c.arrivedAt[inRoom]and c.arrivedAt[onApron]and c.arrivedAt[inMouth]and not c.arrivedAt[outside])
		assert(#c.carried==1 and c.carried[1].board==b1 and c.carried[1].spot.Z>-89)
		assert(not c.host.open and c.host:live()==nil and c.blocker().CanCollide==true and c.blocker().CanQuery==true)
		assert(not c.room:FindFirstChild(Den.Model)and #blocked(c.room)==0)
		-- Opened again: the same blocker's values are the first ones it saw.
		Den.inject(ON);c.tick();assert(c.host.open and c.blocker().CanCollide==false)
		Den.inject(OFF);c.tick();assert(c.blocker().CanCollide==true)
		local _=outside;_=onTop;_=b5
		Den.inject(nil)
	end)

	test("the Hush open keeps the den closed (one owner per blocker), and closes it if it was open",function()
		Den.inject(ON);local c=rig();c.hush=true;c.tick();c.tick()
		assert(not c.host.open and #c.warnings==1)
		c.hush=false;c.tick();assert(c.host.open)
		c.hush=true;c.tick();assert(not c.host.open and c.blocker().CanCollide)
		Den.inject(nil)
	end)

	test("a rebuilt lounge drops the den's state (never touches the old parts) and opens again in the new one",function()
		Den.inject(ON);local c=rig();c.tick();assert(c.host.open)
		local old=c.blocker()
		c.room=lounge();c.tick()
		assert(old.CanCollide==false,"the old part is left alone")
		c.tick();assert(c.host.open and c.blocker().CanCollide==false and c.room:FindFirstChild(Den.Model))
		Den.inject(nil)
	end)

	test("errors: three close it (everyone moved, the blocker back) and the heartbeat stops",function()
		Den.inject(ON);local c=rig();local _,b=c.player(1,INSIDE);c.tick();assert(c.host.open)
		local step=c.host.step
		c.host.step=function()error("boom")end
		c.tick();c.tick();assert(c.host.open)
		c.tick();assert(not c.host.open and c.host.dead and #c.beat.list==0 and c.blocker().CanCollide and #c.placed==1 and c.placed[1].board==b)
		c.host.step=step
		Den.inject(nil)
	end)
	return{passed=#cases,cases=cases}
end
