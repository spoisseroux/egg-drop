-- Island edges host (WORLD-PASS-2026-11-22 item 5, slice 1): the safe-spot recording rules, the return after a fall or a
-- walk off the ring, the cooldown, the holds (deck mode, hatch, Dash race, seated, anchored, closing), the server's own
-- moves, a new character, a leap, leaving and the switch going off. Fake players, boards, clock and heartbeat; read()
-- and place() replaced, so no character is touched.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.IslandBoundsHost)(ServerScriptService.Server)
-- Offline: DASH_SPECS="IslandBoundsHost" python scripts/run_dash_server_specs.py
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Bounds=require(Shared.IslandBounds)
	local Host=require(server.IslandBoundsHost)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local ON={flags={IslandBounds=true},studio=true}
	-- Root positions over known ground (IslandBounds.spec checks the cells): two lawns, the dais (a structure), the spur.
	local LAWN,LAWN2=Vector3.new(56,7,74),Vector3.new(40,7,50)
	local DAIS,SPUR=Vector3.new(96,7.5,66),Vector3.new(18,16,-60)
	local SPAWN=CFrame.new(96,7.5,66)

	local function rig()
		local c={now=1000,boards={},placed={},parent=Instance.new("Folder")}
		local beat={list={}}
		function beat:Connect(fn)table.insert(self.list,fn);return{Disconnect=function()table.clear(self.list)end}end
		c.host=Host.mount({boards=c.boards,parent=c.parent,heartbeat=beat,clock=function()return c.now end,
			read=function(board)return board.view end,
			place=function(board,view,cframe)table.insert(c.placed,{board=board,cframe=cframe})end,
			spawnFrame=function()return SPAWN end})
		assert(c.host)
		function c.player(id)
			local p={UserId=id}
			local board={player=p,mode="Room",closing=false,nursery={state={}}}
			board.view={character={id=id},position=LAWN,look=Vector3.new(0,0,-1),alive=true,grounded=true,seated=false,anchored=false}
			c.boards[p]=board
			return p,board
		end
		-- Advance the clock and run the heartbeat (one host step).
		function c.at(t)c.now=1000+t;c.host:step()end
		function c.safe(p)local rec=c.host.records[p];return rec and rec.safe end
		return c
	end
	local function near(cframe,position)return(cframe.Position-position).Magnitude<1e-6 end

	Bounds.inject(ON)

	test("a safe spot is recorded once a second, only standing, unseated, unanchored, alive, on safe ground and not too high",function()
		local c=rig();local p,b=c.player(1)
		c.at(0) -- first sight of this character: the server spawns it, so nothing for Quiet seconds
		assert(c.safe(p)==nil)
		c.at(1);assert(c.safe(p)==nil)
		c.at(2.5);assert(c.safe(p)==LAWN)
		b.view.position=LAWN2;c.at(2.8);assert(c.safe(p)==LAWN) -- not a second yet
		c.at(3.6);assert(c.safe(p)==LAWN2)
		local t=3.6
		local function try(change,undo)
			-- The last sample is forgotten so the test positions never read as a leap (the leap rule has its own case).
			c.host.records[p].last=nil
			b.view.position=LAWN;change();t+=1.1;c.at(t);assert(c.safe(p)==LAWN2);undo()
		end
		try(function()b.view.grounded=false end,function()b.view.grounded=true end)
		try(function()b.view.seated=true end,function()b.view.seated=false end)
		try(function()b.view.anchored=true end,function()b.view.anchored=false end)
		try(function()b.view.alive=false end,function()b.view.alive=true end)
		try(function()b.view.position=DAIS end,function()end)
		try(function()b.view.position=SPUR end,function()end)
		try(function()b.view.position=Vector3.new(LAWN.X,Bounds.SafeTopY+1,LAWN.Z)end,function()end)
		b.view.position=LAWN;t+=1.1;c.at(t);assert(c.safe(p)==LAWN)
	end)

	test("a fall below FallY puts the character back on the safe spot, facing the way it faced, at most once per cooldown",function()
		local c=rig();local p,b=c.player(1)
		c.at(0);c.at(2.5);assert(c.safe(p)==LAWN)
		b.view.position=Vector3.new(60,Bounds.FallY-1,80);c.at(3)
		assert(#c.placed==1 and c.placed[1].board==b and near(c.placed[1].cframe,LAWN+Vector3.new(0,Bounds.Lift,0)))
		local look=c.placed[1].cframe.LookVector
		assert(math.abs(look.X)<1e-6 and math.abs(look.Z+1)<1e-6)
		-- Still falling (the fake does not move): nothing more until the cooldown is over.
		c.at(4);c.at(5.9);assert(#c.placed==1)
		c.at(6.1);assert(#c.placed==2)
		-- Above FallY on the island again: no return; the return itself is not recorded as a safe spot for Quiet seconds.
		b.view.position=LAWN2;c.at(6.5);c.at(7.7);assert(#c.placed==2 and c.safe(p)==LAWN)
		c.at(8.8);assert(c.safe(p)==LAWN2)
	end)

	test("leaving the ring returns too; with no safe spot yet the arrival spawn is used",function()
		local c=rig();local p,b=c.player(1)
		c.at(0);c.at(2.5)
		b.view.position=Vector3.new(200,6,0);c.at(3)
		assert(#c.placed==1 and near(c.placed[1].cframe,LAWN+Vector3.new(0,Bounds.Lift,0)))
		local c2=rig();local _,b2=c2.player(2)
		b2.view.position=DAIS;c2.at(0);c2.at(2.5)
		b2.view.position=Vector3.new(0,-40,0);c2.at(3)
		assert(#c2.placed==1 and c2.placed[1].cframe==SPAWN)
	end)

	test("never while deck mode, a hatch or a Dash race holds the player, while seated or anchored, or while closing",function()
		local holds={
			function(b)b.mode="Board"end,function(b)b.nursery.state.lastHatch={id="h"}end,function(b)b.dashHeld=true end,
			function(b)b.view.seated=true end,function(b)b.view.anchored=true end,function(b)b.closing=true end,
		}
		for k,hold in ipairs(holds)do
			local c=rig();local p,b=c.player(k)
			c.at(0);c.at(2.5);assert(c.safe(p)==LAWN)
			hold(b)
			b.view.position=Vector3.new(0,-60,0);c.at(3);c.at(10)
			assert(#c.placed==0,"hold "..k)
		end
	end)

	test("the server's own moves: no sample and no return for Quiet seconds after moved(); a new character counts too",function()
		local c=rig();local p,b=c.player(1)
		c.at(0);c.at(2.5);assert(c.safe(p)==LAWN)
		c.host:moved(p)
		b.view.position=LAWN2;c.at(3.6);assert(c.safe(p)==LAWN)
		b.view.position=Vector3.new(0,-60,0);c.at(4);assert(#c.placed==0)
		c.at(4.6);assert(#c.placed==1)
		-- A new character: the old safe spot is forgotten and the spawn waits Quiet seconds.
		b.view={character={id="new"},position=LAWN2,look=Vector3.new(1,0,0),alive=true,grounded=true,seated=false,anchored=false}
		c.at(8);assert(c.safe(p)==nil)
		b.view.position=Vector3.new(0,-60,0);c.at(9);assert(#c.placed==1)
		b.view.position=LAWN2;c.at(10.1);assert(c.safe(p)==LAWN2)
		-- moved() for a player the host has not seen is harmless.
		c.host:moved({UserId=99})
	end)

	test("a leap no walker can make between two samples is treated as a server move",function()
		local c=rig();local p,b=c.player(1)
		c.at(0);c.at(2.5);assert(c.safe(p)==LAWN)
		b.view.position=Vector3.new(0,7,0);c.at(3.6) -- 81 studs in a second
		assert(c.safe(p)==LAWN)
		c.at(4.7);assert(c.safe(p)==LAWN) -- still in the quiet the leap started
		c.at(5.8);assert(c.safe(p)==Vector3.new(0,7,0))
	end)

	test("leaving forgets the player; a board that is gone is pruned; switching off forgets everyone and stops returns",function()
		local c=rig();local p,b=c.player(1);local q,b2=c.player(2)
		c.at(0);c.at(2.5);assert(c.safe(p)==LAWN and c.safe(q)==LAWN)
		c.host:leave(b);assert(c.host.records[p]==nil)
		c.boards[q]=nil;c.at(3);assert(c.host.records[q]==nil)
		c.boards[q]=b2;c.at(4);c.at(6.5);assert(c.safe(q)==LAWN)
		Bounds.inject({flags={IslandBounds=true},studio=true,on=false})
		c.at(7);assert(next(c.host.records)==nil and #c.parent:GetChildren()==0)
		b2.view.position=Vector3.new(0,-60,0);c.at(8);c.at(12);assert(#c.placed==0)
		Bounds.inject(ON)
	end)

	test("the Hush: with its regions a root there is never returned home; arrived() makes the Hush arrival the safe spot",function()
		local Hush=require(Shared.Hush)
		local regions=nil
		local c=rig()
		c.host.d.regions=function()return regions end
		local p,b=c.player(1)
		c.at(0);c.at(2.5);assert(c.safe(p)==LAWN)
		-- Closed: a root in the Hush is off the island and goes back to the lawn.
		b.view.position=Hush.at(0,60,3);c.at(3);assert(#c.placed==1)
		-- Open: the passage moves the player and says where.
		regions=Hush.BoundsRegions
		local arrival=Hush.Doors.north.arrival.Position+Vector3.new(0,3,0)
		b.view.position=arrival;c.host:arrived(p,arrival)
		assert(c.safe(p)==arrival)
		c.at(4);c.at(6);c.at(10);assert(#c.placed==1)
		-- (The walk from the tunnel reads as a leap in this fake, so a quiet first.)
		b.view.position=Hush.at(10,60,3);c.at(11.5);c.at(12.6);c.at(13.7);assert(c.safe(p)==Hush.at(10,60,3))
		-- A fall in the Hush returns to the Hush.
		b.view.position=Hush.at(10,60,Hush.FallY-Hush.FloorY-1);c.at(14)
		assert(#c.placed==2 and near(c.placed[2].cframe,Hush.at(10,60,3)+Vector3.new(0,Bounds.Lift,0)))
		-- arrived() for a player not seen yet records them with their character, so the next check keeps the spot.
		local q,b2=c.player(2)
		b2.view.position=arrival;c.host:arrived(q,arrival);c.at(20);assert(c.safe(q)==arrival)
		c.host:arrived({UserId=99},arrival)
	end)

	Bounds.inject(nil)
	return{passed=#cases,cases=cases}
end
