-- Garden finds, the client (FindsClient, slice S9) with a fake network and character: off is nothing at all; spots
-- packets draw local stars nothing can touch, a full replace each time; the claim goes once within Sniff, only with the
-- pet out and the garden free; a refused id backs off; taken pops and goes, claimed floats the Smarts, lost goes
-- quietly; the switch going off clears everything within a frame; summary() names the nearest.
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.FindsClient)(PlayerScripts.Client); offline in
-- scripts/run_dash_server_specs.py (DASH_SPECS="FindsClient").
return function(client)
	local Finds=require(game:GetService("ReplicatedStorage").Shared.Finds)
	local Client=require(client.FindsClient)
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
	local ON={flags={GardenFinds=true},studio=true}
	local OFF={flags={GardenFinds=true},studio=true,on=false}
	local rigs={}
	local function rig(options)
		options=options or {}
		Finds.inject(options.env or ON)
		local r={sent={},sounds={},at=Vector3.new(0,3,0),pet=true,open=true,menu=false,now=100}
		local kids={}
		r.remotes={ChildAdded=signal(),FindFirstChild=function(_,name)return kids[name]end}
		function r.add(name)
			local remote={Name=name,OnClientEvent=signal(),FireServer=function(_,packet)table.insert(r.sent,packet)end}
			kids[name]=remote
			r.remotes.ChildAdded:Fire(remote)
			return remote
		end
		if options.remotes~=false then r.event=r.add(Client.Event);r.claim=r.add(Client.Claim)end
		r.player={CharacterAdded=signal()}
		r.world=Instance.new("Folder")
		r.client=Client.mount({remotes=r.remotes,world=r.world,player=r.player,step=false,now=function()return r.now end,
			root=function()return r.at end,petOut=function()return r.pet end,free=function()return r.open end,busy=function()return r.menu end,
			reduced=function()return r.still==true end,audio={play=function(_,name)table.insert(r.sounds,name);return true end}})
		function r.fire(packet)(r.event or kids[Client.Event]).OnClientEvent:Fire(packet)end
		function r.parts(name)
			local n,folder=0,r.world:FindFirstChild(Client.Folder)
			for _,item in ipairs(folder and folder:GetChildren()or {})do if item.Name==(name or"Find")then n+=1 end end
			return n,folder
		end
		function r.count(kind)
			local n=0
			for _,packet in ipairs(r.sent)do if packet.kind==kind then n+=1 end end
			return n
		end
		function r.step(dt)r.now+=dt;r.client:step(dt)end
		table.insert(rigs,r)
		return r
	end
	local function spot(id,x,z)return{id=id,x=x,y=0,z=z}end

	test("off: nothing with the ceiling off; with the switch off no star, no remote bound, no packet sent",function()
		Finds.inject({flags={GardenFinds=false},studio=true})
		assert(Client.mount({remotes={},root=function()end})==nil,"the ceiling")
		local r=rig({env=OFF})
		assert(r.client and not r.client.isOpen and #r.sent==0)
		assert(#r.event.OnClientEvent.list==0 and #r.remotes.ChildAdded.list==0,"nothing bound")
		r.fire({kind="spots",list={spot("a",5,0)}});r.step(1)
		assert(r.parts()==0 and select(2,r.parts())==nil and #r.sent==0)
		Finds.inject(ON);r.client:sync()
		assert(r.client.isOpen and r.count("sync")==1,"switch on: asks for the spots")
	end)
	test("remotes made later are bound as they come; sync once both are there, again on respawn",function()
		local r=rig({remotes=false})
		assert(#r.sent==0)
		r.add(Client.Event);assert(#r.sent==0,"the claim remote is not there yet")
		r.add(Client.Claim);assert(r.count("sync")==1)
		r.add(Client.Claim);assert(r.count("sync")==1,"once")
		r.player.CharacterAdded:Fire({});assert(r.count("sync")==2,"respawn")
		r.fire({kind="spots",list={spot("a",30,0)}});assert(r.parts()==1)
	end)
	test("spots: a star per find, local parts nothing can touch, a full replace each time, junk dropped",function()
		local r=rig()
		r.fire({kind="spots",list={spot("a",30,0),spot("b",-30,0)}})
		local n,folder=r.parts();assert(n==2 and folder.Parent==r.world)
		for _,item in ipairs(folder:GetChildren())do
			assert(item.Anchored and not item.CanCollide and not item.CanQuery and not item.CanTouch and not item.CastShadow,item.Name)
			assert(item:FindFirstChild("Glint")~=nil)
		end
		local a=r.client.spots.a.part
		r.fire({kind="spots",list={spot("b",-30,0),spot("c",0,40)}})
		assert(r.parts()==2 and r.client.spots.a==nil and r.client.spots.b and r.client.spots.c and a.Parent==nil,"a gone, b kept, c drawn")
		r.fire({kind="spots",list={spot("b",-30,5)}})
		assert(r.parts()==1 and r.client.spots.b.position.Z==5,"a moved find is drawn where it is")
		r.fire({kind="spots",list={}});assert(r.parts()==0)
		r.fire({kind="spots",list={{id="x",x="nope",y=0,z=0},{x=1,y=0,z=0},{id="y",x=0/0,y=0,z=0},spot("d",1,1),spot("d",9,9),"junk"}})
		assert(r.parts()==1 and r.client.spots.d.position.X==1,"junk dropped, the first of a repeated id kept")
		local many={}
		for i=1,40 do many[i]=spot("m"..i,i,0)end
		r.fire({kind="spots",list=many});assert(r.parts()==Client.MaxSpots)
		r.fire("junk");r.fire({kind="taken"});r.fire({kind="nope",id="m1"});assert(r.parts()==Client.MaxSpots)
	end)
	test("claim: once within Sniff, and only with the pet out and the garden free",function()
		local r=rig()
		r.fire({kind="spots",list={spot("a",20,0)}})
		r.step(.1);assert(r.count("claim")==0,"too far")
		r.at=Vector3.new(20-Finds.Sniff-.5,3,0);r.step(.1);assert(r.count("claim")==0,"just outside")
		for reason,change in pairs({pet=function()r.pet=false end,free=function()r.open=false end,busy=function()r.menu=true end,dead=function()r.at=nil end})do
			r.at=Vector3.new(15,3,0)
			change();r.step(.1)
			assert(r.count("claim")==0,reason)
			r.pet,r.open,r.menu=true,true,false
		end
		r.at=Vector3.new(15,3,0);r.step(.1)
		assert(r.count("claim")==1 and r.sent[#r.sent].id=="a")
		for _=1,20 do r.step(.1)end
		assert(r.count("claim")==1,"never again while it waits for the answer")
		r.step(Client.Pending);assert(r.count("claim")==2,"an answer that never came: asked again")
	end)
	test("refused: the find stays and that id waits Backoff seconds; the nearest is asked first",function()
		local r=rig()
		r.fire({kind="spots",list={spot("a",3,0),spot("b",-6,0)}})
		r.step(.1);assert(r.count("claim")==1 and r.sent[#r.sent].id=="a","the nearest")
		r.fire({kind="refused",id="a",reason="Busy"})
		assert(r.parts()==2)
		r.step(.1);assert(r.count("claim")==2 and r.sent[#r.sent].id=="b","the other one meanwhile")
		r.fire({kind="refused",id="b",reason="Far"})
		r.step(1);assert(r.count("claim")==2,"backing off")
		r.step(1.1);assert(r.count("claim")==3 and r.sent[#r.sent].id=="a","again after Backoff")
	end)
	test("taken pops at once with the sounds and is gone after the pop; claimed floats +N Smarts; lost goes quietly",function()
		local r=rig()
		r.fire({kind="spots",list={spot("a",3,0),spot("b",40,0)}})
		r.step(.1)
		r.fire({kind="taken",id="a"})
		assert(r.client:summary().waiting==1 and r.client.spots.a==nil and r.client.popping.a,"popping, not waiting")
		assert(table.find(r.sounds,"snack_boost_sparkle")and table.find(r.sounds,"snack_sniff"))
		assert(r.parts()==2,"the burst plays out")
		r.step(Client.Pop+.05);assert(r.client.popping.a and r.client.popping.a.glint==nil,"the star has shrunk away")
		r.step(Client.Hold);assert(r.parts()==1 and r.client.popping.a==nil,"and its part is gone")
		r.fire({kind="claimed",id="a",xp=16})
		assert(r.parts("Gain")==1)
		r.step(Client.Rise+.1);assert(r.parts("Gain")==0)
		local heard=#r.sounds
		r.fire({kind="lost",id="b"})
		assert(r.parts()==0 and #r.sounds==heard,"no pop, no sound")
		-- A claimed with no taken before it pops too; xp 0 floats nothing.
		r.fire({kind="spots",list={spot("c",40,0)}});r.fire({kind="claimed",id="c",xp=0})
		assert(r.client.spots.c==nil and r.parts("Gain")==0)
		r.fire({kind="claimed",id="zzz",xp=16});assert(r.parts("Gain")==0,"an id never drawn floats nothing")
		-- Reduced Motion: still stars, and the pop is the star going at once.
		r.still=true
		r.fire({kind="spots",list={spot("d",40,0)}});r.step(1)
		assert(r.client.spots.d.scale==1 and r.client.spots.d.turn==0)
		r.fire({kind="taken",id="d"});assert(r.parts()==0 and r.client.popping.d==nil)
	end)
	test("twinkle: harder within Notice; Reduced Motion still; the pop swells and ends at nothing",function()
		local s,turn=Client.twinkle(3.1,false,true,2);assert(s==1 and turn==0)
		local farMax,nearMin=0,math.huge
		for t=0,6,.05 do
			farMax=math.max(farMax,math.abs(Client.twinkle(t,false,false,1)-1))
			local near,spin=Client.twinkle(t,true,false,1)
			nearMin=math.min(nearMin,near);assert(spin>=0 and spin<90)
		end
		assert(farMax<=.1+1e-6 and nearMin>=1.1-1e-6)
		assert(Client.popScale(0)==1 and Client.popScale(.3)>1.5 and Client.popScale(1)==0)
		local r=rig()
		r.fire({kind="spots",list={spot("near",10,0),spot("far",80,0)}})
		local seenNear,seenFar=0,0
		for _=1,30 do r.step(.05);seenNear=math.max(seenNear,r.client.spots.near.scale);seenFar=math.max(seenFar,r.client.spots.far.scale)end
		assert(seenNear>seenFar,"the near one twinkles harder")
	end)
	test("off: every star, pop and gain gone within a frame; on again asks again; destroy leaves nothing",function()
		local r=rig()
		r.fire({kind="spots",list={spot("a",3,0),spot("b",40,0)}})
		r.step(.1);r.fire({kind="taken",id="a"});r.fire({kind="claimed",id="a",xp=8})
		Finds.inject(OFF)
		r.step(0)
		assert(select(2,r.parts())==nil and not r.client.isOpen and next(r.client.spots)==nil and next(r.client.popping)==nil and #r.client.gains==0)
		local sent=#r.sent
		r.fire({kind="spots",list={spot("c",3,0)}});r.step(1)
		assert(select(2,r.parts())==nil and #r.sent==sent and #r.event.OnClientEvent.list==0,"nothing bound, nothing sent")
		assert(r.client:summary().waiting==0 and r.client:summary().nearest==nil)
		Finds.inject(ON);r.client:sync()
		assert(r.count("sync")==2,"switch on again: asks again")
		r.fire({kind="spots",list={spot("c",30,0)}});assert(r.parts()==1)
		r.client:destroy()
		assert(select(2,r.parts())==nil and #r.event.OnClientEvent.list==0 and #r.remotes.ChildAdded.list==0 and #r.player.CharacterAdded.list==0)
		r.client:sync();r.fire({kind="spots",list={spot("e",3,0)}});assert(select(2,r.parts())==nil,"destroyed stays down")
	end)
	test("summary: how many wait and the nearest to my character",function()
		local r=rig()
		assert(r.client:summary().waiting==0 and r.client:summary().nearest==nil)
		r.fire({kind="spots",list={spot("a",30,0),spot("b",10,0),spot("c",-50,0)}})
		local s=r.client:summary()
		assert(s.waiting==3 and s.nearest==Vector3.new(10,0,0)and math.abs(s.distance-math.sqrt(109))<1e-6)
		r.fire({kind="taken",id="b"})
		s=r.client:summary();assert(s.waiting==2 and s.nearest==Vector3.new(30,0,0))
		r.at=nil
		s=r.client:summary();assert(s.waiting==2 and s.nearest~=nil and s.distance==nil,"no character: still a place to show")
	end)
	for _,r in ipairs(rigs)do r.client:destroy()end
	Finds.inject(nil)
	return{passed=#cases,cases=cases}
end
