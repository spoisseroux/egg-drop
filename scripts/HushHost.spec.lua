-- The Hush host (HUSH-GREYBOX-BUILD-PLAN.md sections 3 to 5 and 9): nothing on live; open builds then opens the cave;
-- a missing blocker keeps it closed; the passage's refusals; the move after FadeOut, in order, with the pet and the
-- island bounds; per-player arrival offsets; the in-flight flag always cleared and errors counted; the switch off with
-- people inside evacuates them before the blocker comes back; leave. Fake boards, clock, scheduler, remote and room:
-- no character is touched.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.HushHost)(ServerScriptService.Server)
-- Offline: python scripts/run_dash_server_specs.py
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Hush=require(Shared.Hush)
	local Rows=require(Shared.HushGreybox)
	local Host=require(server.HushHost)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local ON={flags={Hush=true},studio=true}
	local OFF={flags={Hush=true},studio=true,on=false}
	local NORTH=Vector3.new(-7,7,-113.5)  -- in the north trigger
	local HOME=Hush.at(0,-22.5,9)         -- in the return trigger
	local LAWN=Vector3.new(40,7,50)

	local function rig(options)
		options=options or {}
		local c={now=0,boards={},log={},parked={},placed={},carried={},arrivedAt={},warnings={}}
		c.room=Instance.new("Model")
		if not options.noBlocker then
			c.blocker=Instance.new("BasePart");c.blocker.Name=Hush.Blocker;c.blocker.CanCollide=true;c.blocker.CanQuery=true
			c.blocker.Parent=c.room
		end
		c.remotes=Instance.new("Folder")
		c.remote=Instance.new("RemoteEvent")
		c.garden={actors={}}
		local beat={list={}}
		function beat:Connect(fn)table.insert(self.list,fn);return{Disconnect=function()table.clear(self.list)end}end
		c.beat=beat
		c.host=Host.mount({boards=c.boards,remotes=c.remotes,remote=if options.remote==false then nil else c.remote,garden=c.garden,
			room=function()return c.room end,heartbeat=beat,clock=function()return c.now end,
			spawn=function(fn)local co=coroutine.create(fn);local ok,e=coroutine.resume(co);assert(ok,e)end,
			wait=function(s)table.insert(c.parked,{due=c.now+s,co=coroutine.running()});coroutine.yield()end,
			read=function(board)
				if options.readFails and board.view and board.view.boom then error("read failed")end
				return board.view
			end,
			place=function(board,view,cframe)
				table.insert(c.log,"place");table.insert(c.placed,{board=board,cframe=cframe})
				view.position=cframe.Position
			end,
			ground=function(position)return position.Y-.5 end,
			streaming=function()return options.streaming==true end,
			stream=function(_,position)table.insert(c.log,"stream");c.streamedTo=position end,
			carry=function(board,spot)table.insert(c.log,"carry");table.insert(c.carried,{board=board,spot=spot});return true end,
			arrived=function(player,spot)table.insert(c.log,"arrived");c.arrivedAt[player]=spot end,
			petPosition=function(actor)return actor.at end,
			warn=function(text)table.insert(c.warnings,text)end})
		function c.player(id,at)
			local p={UserId=id}
			local board={player=p,mode="Room",closing=false,nursery={state={}}}
			board.view={character={id=id},position=at or NORTH,alive=true,seated=false,anchored=false,lift=3}
			c.boards[p]=board
			return p,board
		end
		function c.tick(dt)
			c.now+=dt or .2
			for _,fn in ipairs(table.clone(beat.list))do fn()end
		end
		function c.advance(to)
			while true do
				local best
				for i,p in ipairs(c.parked)do if p.due<=to and(not best or p.due<c.parked[best].due)then best=i end end
				if not best then break end
				local p=table.remove(c.parked,best);c.now=math.max(c.now,p.due)
				local ok,e=coroutine.resume(p.co);assert(ok,e)
			end
			c.now=math.max(c.now,to)
		end
		function c.go(p,door,seq)c.remote.OnServerEvent:Fire(p,{kind="go",door=door or "north",seq=seq})end
		function c.last(p)
			for i=#c.remote.sent,1,-1 do if c.remote.sent[i].player==p then return c.remote.sent[i].packet end end
			return nil
		end
		return c
	end

	test("live: the build ceiling closed means no host, no remote, nothing connected",function()
		Hush.inject({flags={Hush=true},studio=false,place=96451847774961})
		local remotes=Instance.new("Folder")
		local beat={list={}}
		function beat:Connect(fn)table.insert(self.list,fn);return{Disconnect=function()end}end
		assert(Host.mount({boards={},remotes=remotes,heartbeat=beat})==nil)
		assert(#remotes:GetChildren()==0 and #beat.list==0)
		Hush.inject({flags={Hush=false},studio=true})
		assert(Host.mount({boards={},remotes=remotes,heartbeat=beat})==nil and #remotes:GetChildren()==0)
		Hush.inject(nil)
	end)

	test("on: the greybox is built into the room, then the blocker stops colliding and answering rays, then open; off puts it back",function()
		Hush.inject(OFF)
		local c=rig({remote=false})
		assert(c.remotes:FindFirstChild(Hush.Remote))
		c.tick();assert(not c.host.open and not c.room:FindFirstChild(Hush.Model)and c.blocker.CanCollide==true)
		Hush.inject(ON);c.tick()
		local model=c.room:FindFirstChild(Hush.Model)
		assert(c.host.open and model and #model:GetChildren()==#Rows)
		assert(c.blocker.CanCollide==false and c.blocker.CanQuery==false)
		for _,part in ipairs(model:GetChildren())do
			assert(part.Anchored==true and part.CanTouch==false and part:GetAttribute("WorldMesh")==true,part.Name)
			assert(part.CanQuery==(part.CanCollide and part.Transparency==0),part.Name)
		end
		c.tick();assert(#c.room:GetChildren()==2) -- still one model
		Hush.inject(OFF);c.tick()
		assert(not c.host.open and model.Parent==nil and not c.room:FindFirstChild(Hush.Model))
		assert(c.blocker.CanCollide==true and c.blocker.CanQuery==true)
		Hush.inject(nil)
	end)

	test("a missing or renamed CaveBlocker keeps the Hush closed, with one warning",function()
		Hush.inject(ON)
		local c=rig({noBlocker=true})
		c.tick();c.tick();c.tick()
		assert(not c.host.open and not c.room:FindFirstChild(Hush.Model)and #c.warnings==1)
		local p=c.player(1);c.go(p,"north",1)
		assert(c.last(p).kind=="refused"and c.last(p).reason=="Closed")
		Hush.inject(nil)
	end)

	test("the passage: moved only after FadeOut, then bounds, then the pet, then the answer; the arrival is the door's",function()
		Hush.inject(ON)
		local c=rig();c.tick()
		local p,b=c.player(1)
		c.go(p,"north",1)
		assert(#c.placed==0 and c.host.records[p].flight==1)
		c.advance(c.now+Hush.FadeOut-.01);assert(#c.placed==0)
		c.advance(c.now+.02)
		assert(table.concat(c.log,",")=="place,arrived,carry",table.concat(c.log,","))
		local cf=c.placed[1].cframe
		assert((cf.Position-(Hush.Doors.north.arrival.Position+Vector3.new(0,3,0))).Magnitude<1e-6)
		assert(cf.LookVector.Z<-.99)
		assert(c.arrivedAt[p]==cf.Position)
		local spot=c.carried[1].spot
		assert(math.abs(spot.X-Hush.Doors.north.landing.X)<1e-6 and math.abs(spot.Z-Hush.Doors.north.landing.Z)<1e-6)
		local answer=c.last(p)
		assert(answer.kind=="arrived"and answer.seq==1 and answer.at==cf.Position and answer.region=="hush")
		assert(c.host.records[p].flight==nil)
		-- And home again, after the cooldown.
		c.tick(Hush.Cooldown)
		b.view.position=HOME
		c.go(p,"home",2);c.advance(c.now+Hush.FadeOut)
		assert(#c.placed==2 and c.last(p).kind=="arrived"and c.last(p).region=="underway")
		local back=c.placed[2].cframe
		assert((back.Position-(Hush.Doors.home.arrival.Position+Vector3.new(0,3,0))).Magnitude<1e-6 and back.LookVector.Z>.99)
		assert(c.carried[2].spot.Z>-90) -- the pet lands inside the home Floor
		Hush.inject(nil)
	end)

	test("streaming on: the far side is asked for before the move",function()
		Hush.inject(ON)
		local c=rig({streaming=true});c.tick()
		local p=c.player(1);c.go(p,"north",1);c.advance(c.now+1)
		assert(c.log[1]=="stream"and c.streamedTo==Hush.Doors.north.arrival.Position and c.log[2]=="place")
		Hush.inject(nil)
	end)

	test("refusals: closed, out of the trigger, deck mode, race, care, hatch, seated, dead, a busy pet, in flight, cooldown",function()
		Hush.inject(ON)
		local function try(change,reason,door)
			local c=rig();c.tick()
			local p,b=c.player(1)
			change(c,p,b)
			local moves=#c.placed
			c.go(p,door or "north",1)
			local answer=c.last(p)
			assert(answer and answer.kind=="refused"and answer.reason==reason,reason.." / "..tostring(answer and answer.reason))
			c.advance(c.now+5);assert(#c.placed==moves,reason)
		end
		try(function(c)Hush.inject(OFF);c.tick();Hush.inject(ON)end,"Closed")
		try(function(_,_,b)b.view.position=LAWN end,"Far")
		try(function(_,_,b)b.view.position=NORTH end,"Far","home")
		try(function(_,_,b)b.mode="Board"end,"Busy")
		try(function(_,_,b)b.dashHeld=true end,"Racing")
		try(function(_,_,b)b.careHeld=true end,"Carried")
		try(function(_,_,b)b.nursery.state.lastHatch={}end,"Hatching")
		try(function(_,_,b)b.view.seated=true end,"Seated")
		try(function(_,_,b)b.view.alive=false end,"NoCharacter")
		for _,busy in ipairs({"park","care","dash","toyReservation"})do
			try(function(c,p)c.garden.actors[p.UserId]={[busy]=1}end,"PetBusy")
		end
		-- Slack: 3 studs outside the box still counts (the server sees the root a little late).
		local c=rig();c.tick();local p,b=c.player(1,NORTH+Vector3.new(0,0,Hush.Slack+.25))
		c.go(p,"north",1);assert(c.host.records[p].flight==1)
		-- In flight, then the cooldown.
		c.go(p,"north",2);assert(c.last(p).reason=="Busy")
		c.advance(c.now+Hush.FadeOut);assert(c.last(p).kind=="arrived")
		b.view.position=HOME;c.go(p,"home",3);assert(c.last(p).reason=="Cooldown")
		Hush.inject(nil)
	end)

	test("bad packets are dropped without an answer; old seqs and floods too",function()
		Hush.inject(ON)
		local c=rig();c.tick()
		local p=c.player(1)
		for _,packet in ipairs({nil,5,"go",{},{kind="go"},{kind="go",door="west",seq=1},{kind="go",door="north",seq=1.5},
			{kind="go",door="north",seq=0/0},{kind="go",door="north",seq=-1},{kind="go",door="north",seq=2e9},{kind="move",door="north",seq=1}})do
			c.remote.OnServerEvent:Fire(p,packet)
		end
		assert(#c.remote.sent==0)
		c.tick(1)
		c.go(p,"north",5);assert(c.host.records[p].flight==5)
		c.go(p,"north",4);c.go(p,"north",5)
		assert(#c.remote.sent==0) -- old seqs: no answer
		-- More than Rate in a second: dropped.
		local q=c.player(2,LAWN)
		for k=1,Hush.Rate+3 do c.go(q,"north",k)end
		assert(#c.remote.sent==Hush.Rate)
		Hush.inject(nil)
	end)

	test("checked again before the move: walking back out, a new character or the switch going off refuses it",function()
		Hush.inject(ON)
		local c=rig();c.tick()
		local p,b=c.player(1)
		c.go(p,"north",1);b.view.position=LAWN;c.advance(c.now+1)
		assert(#c.placed==0 and c.last(p).reason=="Far"and c.host.records[p].flight==nil)
		c.tick(2);b.view.position=NORTH;c.go(p,"north",2);b.view={character={id="new"},position=NORTH,alive=true,lift=3}
		c.advance(c.now+1);assert(#c.placed==0 and c.last(p).reason=="NoCharacter")
		-- The switch off mid-flight: the pocket is evacuated (one move), and the passage is refused.
		c.tick(2);c.go(p,"north",3);Hush.inject(OFF);c.tick(.2)
		c.advance(c.now+1);assert(#c.placed==1 and c.last(p).reason=="Closed")
		Hush.inject(nil)
	end)

	test("two players arriving together take different spots",function()
		Hush.inject(ON)
		local c=rig();c.tick()
		local p=c.player(1);local q=c.player(2)
		c.go(p,"north",1);c.go(q,"north",1);c.advance(c.now+1)
		assert(#c.placed==2 and(c.placed[1].cframe.Position-c.placed[2].cframe.Position).Magnitude>1.5)
		assert((c.carried[1].spot-c.carried[2].spot).Magnitude>1.5)
		Hush.inject(nil)
	end)

	test("the switch off with one player in the Hush and one in the pocket: both out on the lawn first, then closed",function()
		Hush.inject(ON)
		local c=rig();c.tick()
		local p,b=c.player(1,Hush.at(0,60,3))
		local q,b2=c.player(2,Vector3.new(-7,7,-106))
		local r=c.player(3,LAWN)
		local openWhenMoved={}
		c.host.place=function(board,view,cframe)
			table.insert(openWhenMoved,c.host.open and c.blocker.CanCollide==false)
			table.insert(c.placed,{board=board,cframe=cframe});view.position=cframe.Position
		end
		Hush.inject(OFF);c.tick()
		assert(#c.placed==2 and openWhenMoved[1]and openWhenMoved[2])
		for _,m in ipairs(c.placed)do
			assert(m.board==b or m.board==b2)
			assert(Hush.regionAt(m.cframe.Position)==nil and m.cframe.Position.Z>-90)
		end
		assert(c.last(p).kind=="evacuated"and c.last(q).kind=="evacuated"and c.last(r)==nil)
		assert(c.arrivedAt[p]and c.arrivedAt[q]and #c.carried==2)
		assert(not c.host.open and c.blocker.CanCollide==true and not c.room:FindFirstChild(Hush.Model))
		Hush.inject(nil)
	end)

	test("code review 1: closing also brings out a pet left in the Hush by an owner who reset home; never one twice, never one at home",function()
		Hush.inject(ON)
		local c=rig();c.tick()
		local p,b=c.player(1,LAWN)                 -- respawned home; the pet is still on the Hush floor
		c.garden.actors[1]={at=Hush.at(0,60,0)}
		local q,b2=c.player(2,Hush.at(5,60,3))     -- in the Hush with the pet: evacuated, the pet with them
		c.garden.actors[2]={at=Hush.at(6,60,0)}
		local r=c.player(3,LAWN)                   -- home with the pet at home
		c.garden.actors[3]={at=Vector3.new(41,4,50)}
		c.player(4,LAWN)                           -- no pet out
		Hush.inject(OFF);c.tick()
		assert(#c.carried==2,#c.carried)
		local seen={}
		for _,m in ipairs(c.carried)do
			seen[m.board]=true
			assert(Hush.regionAt(m.spot)==nil and m.spot.Z>-90 and m.spot.Z<-75,tostring(m.spot))
		end
		assert(seen[b]and seen[b2])
		assert(#c.placed==1 and c.placed[1].board==b2) -- only the owner who was inside is moved
		assert(c.last(p)==nil and c.last(r)==nil)
		assert(not c.host.open and not c.room:FindFirstChild(Hush.Model))
		Hush.inject(nil)
	end)

	test("errors: a failing move clears the flight and counts; three errors close the Hush, evacuate and restore the blocker",function()
		Hush.inject(ON)
		local c=rig({readFails=true});c.tick()
		local p,b=c.player(1)
		local inside=c.player(9,Hush.at(0,40,3))
		for k=1,2 do
			c.go(p,"north",k);b.view.boom=true;c.advance(c.now+1);b.view.boom=nil
			assert(c.host.records[p].flight==nil and c.host.errors==k and c.last(p).reason=="Error")
			c.tick(2)
		end
		assert(c.host.open and not c.host.dead)
		c.go(p,"north",3);b.view.boom=true;c.advance(c.now+1)
		assert(c.host.dead and not c.host.open and c.blocker.CanCollide==true and not c.room:FindFirstChild(Hush.Model))
		assert(c.last(inside).kind=="evacuated")
		assert(#c.beat.list==0)
		Hush.inject(nil)
	end)

	test("owner /hush go and home: fade first, then the same passage from anywhere; leave forgets the player",function()
		Hush.inject(ON)
		assert(Host.parse("/hush go")=="north"and Host.parse(" /HUSH home ")=="home"and Host.parse("/hush on")==nil and Host.parse(5)==nil)
		local c=rig();c.tick()
		local p,b=c.player(1,LAWN)
		assert(c.host:command(b,"/hush go"))
		assert(c.remote.sent[1].packet.kind=="out"and c.remote.sent[1].packet.seq==0)
		c.advance(c.now+1)
		assert(#c.placed==1 and c.last(p).kind=="arrived"and c.last(p).seq==0)
		assert(not c.host:command(b,"/hush on"))
		c.host:leave(b);assert(c.host.records[p]==nil)
		Hush.inject(nil)
	end)

	return{passed=#cases,cases=cases}
end
