-- The Sleepy Nest in the garden (NestClient, Onboarding v3 slice D) with a fake network, clock and character: off is
-- nothing at all; state packets draw the nest (10 inert local parts) and the egg at its growth look; Tuck in and Hatch go
-- through the prompt's action; the reward shows only on `claimed`, never on the ask or a refusal; a refused claim settles
-- back and waits; the next egg lands after the hatch; the switch going off clears everything within a frame; nestPlace
-- names where the Bear's prints end; the chip counts down.
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.NestClient)(PlayerScripts.Client); offline in
-- scripts/run_dash_server_specs.py (DASH_SPECS="NestClient").
return function(client)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Onboard=require(Shared.Onboard)
	local Nest=require(Shared.Nest)
	local Client=require(client.NestClient)
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
	local ON={flags={OnboardingV3=true},studio=true}
	local OFF={flags={OnboardingV3=true},studio=true,nest=false}
	local NOW=1800000000
	local function rig(options)
		options=options or {}
		Onboard.inject(options.env or ON)
		local r={sent={},sounds={},toasts={},shows=0,at=Vector3.new(96,4.33,66),open=true,menu=false,now=NOW,small=options.compact==true}
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
		r.host=Instance.new("Frame")
		r.client=Client.mount({remotes=r.remotes,world=r.world,player=r.player,step=false,now=function()return r.now end,
			root=function()return r.at end,free=function()return r.open end,busy=function()return r.menu end,
			reduced=function()return r.still==true end,compact=function()return r.small end,chipHost=function()return r.host end,
			focus=function()return r.focus==true end,chipHidden=function()return r.inPark==true end,
			ground=options.ground,measure=function(text,size)return #text*size*.5 end,show=function()r.shows+=1 end,
			toast=function(text,stars)table.insert(r.toasts,{text=text,stars=stars})end,
			audio={play=function(_,name)table.insert(r.sounds,name);return true end}})
		function r.fire(packet)(r.event or kids[Client.Event]).OnClientEvent:Fire(packet)end
		function r.folder()return r.world:FindFirstChild(Client.Folder)end
		function r.count(kind)
			local n=0
			for _,packet in ipairs(r.sent)do if packet.kind==kind then n+=1 end end
			return n
		end
		function r.heard(name)
			local n=0
			for _,sound in ipairs(r.sounds)do if sound==name then n+=1 end end
			return n
		end
		function r.step(dt)r.now+=dt;r.client:step(dt)end
		return r
	end
	-- A public snapshot: an egg that landed `ago` seconds before NOW.
	local function public(ago,options)
		options=options or {}
		local at=NOW-ago
		return{at=at,readyAt=at+Nest.Seconds,left=math.max(0,Nest.Seconds-ago),ready=ago>=Nest.Seconds,n=options.n or 0,egg=(options.n or 0)+1,
			week=false,gift=options.gift or {kind="toy",item="ball",stars=5},tucked=options.tucked==true,pet="bear"}
	end
	local function state(ago,options)return{kind="state",public=public(ago,options)}end

	test("off: nil with the ceiling off; with the switch off no part, no remote bound, no packet sent",function()
		Onboard.inject({flags={OnboardingV3=false},studio=true})
		assert(Client.mount({remotes={},root=function()end})==nil,"the ceiling")
		local r=rig({env=OFF})
		assert(r.client and not r.client.isOpen and #r.sent==0)
		assert(#r.event.OnClientEvent.list==0 and #r.remotes.ChildAdded.list==0,"nothing bound")
		r.fire(state(0));r.step(1)
		assert(r.folder()==nil and #r.sent==0 and r.client:place3D()==nil and #r.host:GetChildren()==0)
		Onboard.inject(ON);r.client:sync()
		assert(r.client.isOpen and r.count("sync")==1,"switch on: asks for the nest")
		Onboard.inject(nil)
	end)
	test("remotes made later are bound as they come; sync once both are there, again on respawn",function()
		local r=rig({remotes=false})
		assert(#r.sent==0)
		r.add(Client.Event);assert(#r.sent==0,"the claim remote is not there yet")
		r.add(Client.Claim);assert(r.count("sync")==1)
		r.add(Client.Claim);assert(r.count("sync")==1,"once")
		r.player.CharacterAdded:Fire({});assert(r.count("sync")==2,"respawn")
		assert(r.count("land")==0,"the client never lands an egg")
		Onboard.inject(nil)
	end)
	test("state: the nest's ten parts and the egg, local and inert, at Fable's spot; junk and nil draw nothing",function()
		local r=rig()
		r.fire({kind="state",public={at="soon",n=0}});r.fire({kind="state",public=nil});r.fire("junk");r.fire({kind="nope"})
		assert(r.folder()==nil,"junk draws nothing")
		r.fire(state(0))
		local folder=r.folder()
		assert(folder and folder.Parent==r.world)
		local nestParts,parts=0,0
		for _,item in ipairs(folder:GetChildren())do
			assert(string.sub(item.Name,1,2)~="W7","no world names: "..item.Name)
			if item.ClassName=="Part"then
				parts+=1
				assert(item.Anchored and not item.CanCollide and not item.CanQuery and not item.CanTouch and not item.CastShadow,item.Name)
				if string.sub(item.Name,1,4)=="Nest"then nestParts+=1 end
			end
		end
		assert(nestParts==10,"ten nest parts, got "..nestParts)
		assert(parts==13,"the ten, the egg's anchor, its body and the prompt spot")
		local base=folder:FindFirstChild("NestBase")
		assert(math.abs(base.CFrame.Position.X-86)<1e-6 and math.abs(base.CFrame.Position.Z-66)<1e-6,"at (86, 66)")
		assert(#folder:FindFirstChild("NestFlag"):GetChildren()==2 and #folder:FindFirstChild("NestRim1"):GetChildren()==4,"decals and weave")
		local prompt=folder:FindFirstChild("SleepyNestPrompt"):FindFirstChild("NestPrompt")
		assert(prompt and prompt.ClassName=="ProximityPrompt"and prompt.RequiresLineOfSight==false)
		assert(prompt.MaxActivationDistance==6 and prompt.UIOffset==Vector2.new(0,72),"never fires at the spawn, 10 away; under the nest")
		r.fire(state(60));assert(#r.world:GetChildren()==1,"a second packet redraws nothing")
		r.fire({kind="state",public=nil});assert(r.folder()==nil and r.client:place3D()==nil,"no nest: everything goes")
		Onboard.inject(nil)
	end)
	test("stages: small, glow, rocking and ready by time passed; the clock and the prompt follow",function()
		local r=rig()
		local looks={{0,"small",1.25},{3*3600,"glow",1.6},{6*3600,"rocking",2},{8*3600,"ready",2}}
		for _,row in ipairs(looks)do
			r.now=NOW
			r.fire(state(row[1]))
			r.client.stage=nil;r.client:step(0)
			assert(r.client.lookNow==row[2],row[2].." got "..tostring(r.client.lookNow))
			local egg=r.client.egg
			assert(math.abs(egg.ball.Size.X-row[3])<.05,row[2].." scale "..tostring(egg.ball.Size.X))
			assert(egg.prompt.Enabled==true,row[2].." prompt")
			assert(egg.prompt.ActionText==(if row[2]=="ready"then "Hatch"else "Tuck in"))
			assert(egg.light.Enabled==(row[2]~="small"))
			assert(egg.sparks.Rate==(if row[2]=="ready"then 6 else 0))
		end
		assert(r.client.egg.clock.Text=="Ready!")
		r.now=NOW;r.fire(state(3600));r.client:step(0)
		assert(r.client.egg.clock.Text=="Ready in 7 h.",r.client.egg.clock.Text)
		r.now=NOW;r.fire(state(Nest.Seconds-40*60));r.client:step(0)
		assert(r.client.egg.clock.Text=="Ready in 40 min.",r.client.egg.clock.Text)
		-- Growing while watched: the look changes on the clock, and the scale tweens there.
		r.now=NOW;r.fire(state(Nest.Seconds/3-1));r.client.stage=nil;r.client:step(0);assert(r.client.lookNow=="small")
		r.now+=2;r.client:step(.01);assert(r.client.lookNow=="glow"and r.client.stage~=nil,"a stage tween starts")
		for _=1,10 do r.client:step(.1)end
		assert(r.client.stage==nil and math.abs(r.client.shownScale-1.6)<1e-6)
		-- A menu or a busy garden: no prompt.
		r.menu=true;r.client:step(0);assert(r.client.egg.prompt.Enabled==false);r.menu=false
		r.open=false;r.client:step(0);assert(r.client.egg.prompt.Enabled==false);r.open=true
		-- Reduced Motion: no rock or hop, the still Z.
		r.still=true;r.now=NOW;r.fire(state(8*3600));r.client:step(.3)
		local scale,rock,hop=Client.motion("ready",.3,true)
		assert(scale==1 and rock==0 and hop==0)
		assert(r.client.egg.stillZ.Enabled==false and r.client.egg.sparks.Rate==0,"ready: no Z, no sparks")
		r.fire(state(0));r.client:step(.1);assert(r.client.egg.stillZ.Enabled==true)
		Onboard.inject(nil)
	end)
	test("Tuck in: one tuck, the gift peek and the coo at once; no reward; a refusal undoes nothing; Sleep tight after 2.6 s",function()
		local r=rig()
		r.fire(state(60));r.client:step(0)
		assert(r.client:act()==true and r.count("tuck")==1)
		assert(#r.toasts==0,"tucking pays nothing")
		assert(r.heard("pet_coo_1")==1 and r.client.egg.zzz.emitted~=nil)
		r.client:step(0);assert(r.client.egg.prompt.Enabled==false,"one tuck per egg")
		assert(r.client:act()==false and r.count("tuck")==1,"no second tuck")
		r.fire({kind="refused",reason="Tucked",of="tuck"})
		assert(r.client.tuck~=nil,"refused as Tucked: undoes nothing")
		local peek=r.client.egg.anchor:FindFirstChild("GiftPeek")
		assert(peek~=nil,"the gift peek")
		assert(peek:FindFirstChild("Tile"):FindFirstChild("Count").Text=="Egg 1 of 7","the egg's number is on the tile")
		for _=1,27 do r.client:step(.1)end
		assert(r.client.egg.clock.Text=="Sleep tight. It will wait for you.",r.client.egg.clock.Text)
		assert(r.client.egg.anchor:FindFirstChild("GiftPeek")==nil,"the peek is gone")
		r.fire(state(70,{tucked=true}));r.client:step(0)
		assert(r.client.egg.prompt.Enabled==false,"a tucked egg: no prompt until it is ready")
		for _=1,45 do r.client:step(.1)end
		assert(r.client.egg.clock.Text~="Sleep tight. It will wait for you.","the clock again after 4 s")
		Onboard.inject(nil)
	end)
	test("a tuck refused as Lost, Off or Busy gives Tuck in back",function()
		local r=rig()
		r.fire(state(60));r.client:step(0)
		for _,reason in ipairs({"Lost","Off","Busy","Unknown"})do
			assert(r.client:act()==true,reason)
			r.client:step(0);assert(r.client.egg.prompt.Enabled==false)
			r.fire({kind="refused",reason=reason,of="tuck"})
			r.client:step(0)
			assert(r.client.tuck==nil and r.client.egg.prompt.Enabled==true and r.client.action=="tuck",reason..": Tuck in is back")
		end
		assert(r.count("tuck")==4)
		Onboard.inject(nil)
	end)
	test("Hatch: the claim goes; the reward shows only on claimed; a refusal settles back and the prompt waits 2 s",function()
		local r=rig()
		r.fire(state(Nest.Seconds+5));r.client:step(0)
		assert(r.client.action=="hatch"and r.client:act()==true and r.count("claim")==1)
		for _=1,10 do r.client:step(.1)end
		assert(#r.toasts==0 and r.client.egg.anchor:FindFirstChild("StarsGain")==nil,"nothing before claimed")
		assert(r.client:act()==false and r.count("claim")==1,"one ask at a time")
		r.fire({kind="refused",reason="Busy",of="claim"})
		r.client:step(.1)
		assert(#r.toasts==0 and r.client.waiting==nil and r.client.egg.prompt.Enabled==false,"refused: no reward, the prompt waits")
		for _=1,20 do r.client:step(.1)end
		assert(r.client.egg.prompt.Enabled==true,"back after 2 s")
		assert(r.client:act()==true and r.count("claim")==2)
		r.fire({kind="claimed",receipt={egg=1,kind="toy",item="ball",stars=5,pet="bear"}})
		assert(#r.toasts==0 and r.heard("hatch_rise")==1,"the rocks first")
		-- The server's state packet comes straight after: the new egg waits for the hatch.
		r.fire(state(0,{n=1,gift={kind="stars",stars=15}}))
		assert(r.client.view.n==0,"the old egg until the hatch is over")
		for _=1,7 do r.client:step(.1)end
		assert(#r.toasts==1 and r.toasts[1].text=="Ball from the Sleepy egg!"and r.toasts[1].stars==5,tostring(r.toasts[1]and r.toasts[1].text))
		assert(r.heard("hatch")==1 and r.client.egg.anchor:FindFirstChild("StarsGain")~=nil,"+5 floats up")
		for _=1,15 do r.client:step(.1)end
		assert(r.client.view.n==1 and r.heard("land")==1,"the new egg lands")
		assert(r.client.egg.clock.Text=="A new egg is growing.")
		assert(#r.toasts==1,"paid once")
		Onboard.inject(nil)
	end)
	test("a Stars egg: the +N floats, no item toast; a claim with no answer settles back and syncs",function()
		local r=rig()
		r.fire(state(Nest.Seconds,{n=1,gift={kind="stars",stars=15}}));r.client:step(0)
		r.client:act()
		r.fire({kind="claimed",receipt={egg=2,kind="stars",stars=15}})
		for _=1,7 do r.client:step(.1)end
		assert(#r.toasts==0 and r.client.rewarded==1)
		local gain=r.client.egg.anchor:FindFirstChild("StarsGain")
		assert(gain and gain:FindFirstChild("Text").Text=="+15 ★")
		for _=1,20 do r.client:step(.1)end
		r.fire(state(Nest.Seconds,{n=2,gift={kind="stars",stars=20}}));r.client:step(0)
		local syncs=r.count("sync")
		r.client:act()
		for _=1,85 do r.client:step(.1)end
		assert(r.client.waiting==nil and r.count("sync")==syncs+1,"no answer: back to the hop and ask again")
		Onboard.inject(nil)
	end)
	test("the switch going off clears everything within a frame; on again draws on the next packet",function()
		local r=rig()
		r.fire(state(60));r.client:step(0)
		assert(r.folder()~=nil and #r.host:GetChildren()==1)
		Onboard.inject(OFF)
		r.client:step(.016)
		assert(r.folder()==nil and #r.host:GetChildren()==0 and not r.client.isOpen and r.client:place3D()==nil)
		r.fire(state(60));assert(r.folder()==nil,"nothing while off")
		Onboard.inject(ON);r.client:sync()
		assert(r.count("sync")==2)
		r.fire(state(60));assert(r.folder()~=nil)
		Onboard.inject(nil)
	end)
	test("nestPlace: the front of the nest on the raycast ground, nil without a nest",function()
		local r=rig({ground=function()return 5 end})
		assert(r.client:place3D()==nil)
		r.fire(state(60))
		local at=r.client:place3D()
		assert(typeof(at)=="Vector3")
		assert(math.abs(at.Y-6)<1e-6,"ground 5, the prompt 1 over it: "..tostring(at.Y))
		assert(math.abs((at-Vector3.new(86,6,66)).Magnitude-2.6)<1e-6,"2.6 studs toward the dais")
		assert(at.X>86,"toward the dais at x 96")
		Onboard.inject(nil)
		-- A pet (or a player) standing on the spot is not the ground: the walk map's 4.33 is kept.
		local onPet=rig({ground=function()return 4.33+2.4 end})
		onPet.fire(state(60))
		assert(math.abs(onPet.client:place3D().Y-5.33)<1e-6,"the hit on the pet is ignored")
		Onboard.inject(nil)
	end)
	test("the chip: 7 h, 40 min, Ready!; gold when ready; above the dock, never wider; hidden in the park",function()
		assert(Client.chipText(7*3600-5)=="7 h"and Client.chipText(40*60)=="40 min"and Client.chipText(0)=="Ready!")
		assert(Client.chipText(3601)=="2 h"and Client.chipText(3600)=="60 min"and Client.chipText(1)=="1 min","rounded up, never 0")
		local r=rig()
		r.fire(state(3600));r.client:step(0)
		local chip=r.client.chip
		assert(chip and chip.button.Parent==r.host and chip.label.Text=="7 h"and chip.width>0)
		assert(chip.ready==false)
		r.now=NOW;r.fire(state(Nest.Seconds));r.client:step(0)
		assert(chip.label.Text=="Ready!"and chip.ready==true and chip.pill.BackgroundColor3==Client.Color.stars)
		r.small=true;r.client:step(0)
		assert(r.client.chip~=chip and #r.host:GetChildren()==1 and r.client.chip.hit==44,"phone: rebuilt, 44 px hit")
		assert(r.client.chip.button:GetAttribute("AccessibleLabel")=="Sleepy egg")
		r.inPark=true;r.client:step(0);assert(r.client.chip.button.Visible==false,"the park's lane");r.inPark=false
		r.client:step(0);assert(r.client.chip.button.Visible==true)
		-- The 568 x 250 phone (touch: the dock 102 px off the bottom, 12 in from the right): the chip above the dock,
		-- inside its width, under the top bar, clear of the save line on the dock's row (x < dock.x - 8).
		local W,H=568,250
		local dock={x=W-12-104,y=H-102-48,w=104,h=48}
		for _,text in ipairs({"8 h","40 min","Ready!"})do
			local rect=Client.chipRect(dock,Client.chipWidth(18,#text*13*.6),44)
			assert(rect.x>=dock.x and rect.x+rect.w==dock.x+dock.w,text..": inside the dock's width")
			assert(rect.y+rect.h<=dock.y-Client.ChipGap and rect.y>=36,text..": above the dock, under the top bar")
		end
		local wide=Client.chipRect(dock,300,36)
		assert(wide.w==dock.w,"never wider than the dock")
		local desk={x=1280-16-104,y=720-16-48,w=104,h=48}
		local rect=Client.chipRect(desk,Client.chipWidth(22,3*14*.6),36)
		assert(rect.y+rect.h<desk.y and rect.x>=desk.x and rect.w<=88,"desktop: about 76 px for 8 h, above the dock")
		Onboard.inject(nil)
	end)
	test("the ready ping: once per egg within 14 studs; the second line only near",function()
		local r=rig()
		r.at=Vector3.new(120,4,66)
		r.fire(state(Nest.Seconds));r.client:step(0)
		assert(r.heard("machine_attract")==0 and r.client.egg.insidePill.Visible==false)
		r.at=Vector3.new(96,4.33,66);r.client:step(0)
		assert(r.heard("machine_attract")==1 and r.client.egg.insidePill.Visible==false,"10 studs: the ping, not the line")
		r.at=Vector3.new(90,4.33,66);r.client:step(0)
		assert(r.client.egg.insidePill.Visible==true,"within 8: the line")
		assert(r.client.egg.inside.Text=="Inside: Ball and 5 Stars.",r.client.egg.inside.Text)
		assert(r.client.egg.count==nil and r.client.egg.board:FindFirstChild("Count")==nil,"no Egg n of 7 on the world label")
		r.focus=true;r.client:step(0);assert(r.client.egg.board.Enabled==false,"hidden during the pet focus camera")
		r.focus=false;r.client:step(0);assert(r.client.egg.board.Enabled==true)
		r.at=Vector3.new(120,4,66);r.client:step(0);r.at=Vector3.new(90,4.33,66);r.client:step(0)
		assert(r.heard("machine_attract")==1,"once per egg")
		assert(r.client.egg.anchor:FindFirstChild("GiftPeek")==nil)
		r.fire(state(Nest.Seconds,{n=8,gift={kind="stars",stars=4}}));r.client:step(0)
		assert(r.heard("machine_attract")==2,"a new egg pings again")
		assert(r.client.egg.inside.Text=="Inside: 4 Stars.","a new egg: its own line")
		Onboard.inject(nil)
	end)
	return{passed=#cases,cases=cases}
end
