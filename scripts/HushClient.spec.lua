-- The Hush, the client (HushClient, HUSH-GREYBOX-BUILD-PLAN.md sections 4 and 7) with a fake remote, root and audio:
-- nothing on live; one ask per trigger entry, only while free and open; the fade out at once and in on a refusal, a
-- timeout, or once the root is at the arrival with ground under it (or GroundWait); "out" from the owner's command;
-- in the Hush the music duck refreshed every pass and the grade, gone on leaving, a new character and destroy().
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.HushClient)(PlayerScripts.Client); offline in
-- scripts/run_dash_server_specs.py.
return function(client)
	local Hush=require(game:GetService("ReplicatedStorage").Shared.Hush)
	local Client=require(client.HushClient)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
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
	local ON={flags={Hush=true},studio=true}
	local NORTH=Vector3.new(-7,7,-113.5)
	local POCKET=Vector3.new(-7,7,-106)
	local IN_HUSH=Hush.at(0,60,3)
	local function rig(options)
		options=options or {}
		Hush.inject(options.env or ON)
		local r={sent={},ducks={},now=0,open=true,free=true,grounded=true,character={},at=POCKET}
		r.remote={Name=Hush.Remote,OnClientEvent=signal(),FireServer=function(_,packet)table.insert(r.sent,packet)end}
		r.remotes={FindFirstChild=function(_,name)if name==Hush.Remote and options.remote~=false then return r.remote end return nil end}
		r.lighting=Instance.new("Folder")
		r.gui=Instance.new("Folder")
		r.beat=signal()
		r.client=Client.mount({remotes=r.remotes,heartbeat=r.beat,clock=function()return r.now end,
			open=function()return r.open end,free=function()return r.free end,
			root=function()return if r.at then{Position=r.at}else nil end,character=function()return r.character end,
			ground=function()return r.grounded end,lighting=r.lighting,gui=r.gui,
			audio={duck=function(_,name,duration,gain)table.insert(r.ducks,{name=name,duration=duration,gain=gain})end}})
		function r.step(dt)r.now+=dt or .1;r.beat:Fire(dt or .1)end
		function r.run(seconds)for _=1,math.ceil(seconds/.05)do r.step(.05)end end
		function r.black()return r.client.alpha end
		function r.grade()return r.lighting:FindFirstChild(Hush.Grade)end
		return r
	end

	test("live: the build ceiling closed mounts nothing",function()
		Hush.inject({flags={Hush=true},studio=false,place=96451847774961})
		assert(Client.mount({remotes={},heartbeat=signal()})==nil)
		Hush.inject(nil)
	end)

	test("one ask per entry into a trigger, black at once; only while free and open; leaving re-arms",function()
		local r=rig()
		r.step();assert(#r.sent==0)
		r.at=NORTH;r.step()
		assert(#r.sent==1 and r.sent[1].kind=="go"and r.sent[1].door=="north"and r.sent[1].seq==1)
		assert(r.client.target==1)
		r.run(.5);assert(#r.sent==1 and r.black()==1)
		r.remote.OnClientEvent:Fire({kind="refused",seq=1,reason="Far"})
		r.run(Hush.FadeIn+.05);assert(r.black()==0)
		r.step();assert(#r.sent==1) -- still inside: no second ask
		r.at=POCKET;r.step();r.at=NORTH;r.step();assert(#r.sent==2 and r.sent[2].seq==2)
		r.remote.OnClientEvent:Fire({kind="refused",seq=2})
		r.at=POCKET;r.step();r.free=false;r.at=NORTH;r.step();assert(#r.sent==2)
		r.free=true;r.at=POCKET;r.step();r.open=false;r.at=NORTH;r.step();assert(#r.sent==2)
		local q=rig({remote=false});q.at=NORTH;q.step();assert(#q.sent==0 and q.client.target==0)
		Hush.inject(nil)
	end)

	test("arrived: black until the root is at the arrival with ground under it, at most GroundWait; no answer: back in",function()
		local r=rig()
		r.at=NORTH;r.step();r.run(.5)
		local to=Hush.Doors.north.arrival.Position+Vector3.new(0,3,0)
		r.remote.OnClientEvent:Fire({kind="arrived",seq=1,at=to})
		r.run(.5);assert(r.black()==1) -- the root has not moved yet
		r.at=to;r.grounded=false;r.run(.5);assert(r.black()==1) -- streamed out
		r.grounded=true;r.step();r.run(Hush.FadeIn+.05);assert(r.black()==0)
		-- Nothing under our feet for GroundWait: in anyway.
		r.at=Hush.at(0,-22.5,9);r.step()
		assert(#r.sent==2 and r.sent[2].door=="home")
		r.run(.5);r.remote.OnClientEvent:Fire({kind="arrived",seq=2,at=POCKET});r.grounded=false
		r.run(Hush.GroundWait-.2);assert(r.black()==1)
		r.run(.4+Hush.FadeIn);assert(r.black()==0)
		-- No answer at all.
		r.at=POCKET;r.step();r.at=NORTH;r.step();assert(#r.sent==3)
		r.run(Hush.ClientTimeout-.2);assert(r.black()==1)
		r.run(.3+Hush.FadeIn);assert(r.black()==0)
		-- A late or stale answer does nothing.
		r.remote.OnClientEvent:Fire({kind="arrived",seq=3,at=to});r.step();assert(r.client.arrival==nil)
		Hush.inject(nil)
	end)

	test("out (the owner's /hush go): fade, then the same arrival; evacuated fades in",function()
		local r=rig()
		r.remote.OnClientEvent:Fire({kind="out",seq=0});r.run(.5);assert(r.black()==1)
		r.remote.OnClientEvent:Fire({kind="arrived",seq=0,at=r.at});r.step();r.run(Hush.FadeIn+.05);assert(r.black()==0)
		r.remote.OnClientEvent:Fire({kind="out",seq=0});r.run(.2)
		r.remote.OnClientEvent:Fire({kind="evacuated"});r.run(Hush.FadeIn+.05);assert(r.black()==0)
		Hush.inject(nil)
	end)

	test("in the Hush: the duck refreshed every pass for DuckFor, the grade; leaving, a new character and destroy take them away",function()
		local r=rig()
		r.at=IN_HUSH;r.step()
		assert(#r.ducks==1 and r.ducks[1].name==Hush.Duck and r.ducks[1].duration==Hush.DuckFor and r.ducks[1].gain==0)
		assert(r.grade()and r.client:inHush())
		r.run(Hush.EffectsEvery*2+.05);assert(#r.ducks>=3)
		for _,d in ipairs(r.ducks)do assert(d.duration<=Hush.DuckFor)end
		r.at=POCKET;r.run(Hush.EffectsEvery+.05)
		assert(not r.grade()and not r.client:inHush()and r.ducks[#r.ducks].gain==1)
		local count=#r.ducks
		r.run(2);assert(#r.ducks==count) -- outside: nothing more
		r.at=IN_HUSH;r.run(Hush.EffectsEvery+.05);assert(r.grade())
		r.character={};r.at=Vector3.new(96,7,66);r.step();assert(not r.grade())
		r.at=IN_HUSH;r.run(Hush.EffectsEvery+.05);assert(r.grade())
		r.open=false;r.run(Hush.EffectsEvery+.05);assert(not r.grade())
		r.open=true;r.run(Hush.EffectsEvery+.05);assert(r.grade())
		r.client:destroy();assert(not r.grade()and r.ducks[#r.ducks].gain==1 and #r.beat.list==0)
		Hush.inject(nil)
	end)

	return{passed=#cases,cases=cases}
end
