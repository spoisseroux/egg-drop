-- The Sleepy Nest in the garden (NestClient, Onboarding v3 slice D) with a fake network, clock and character: off is
-- nothing at all; state packets draw the nest (21 inert local parts in the plaza, beta 12 QA O2: the twig mound casts
-- the only shadow, the sign carries the pet's name) and the egg at its growth look; Tuck in and Hatch go
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
	local UICopy=require(Shared.UICopy) -- words come from UICopy, so a wording change never breaks a case
	local LifeArt=require(Shared.LifeArt)
	-- Places relative to the nest (Nest.Spot, the plaza since beta 12 QA O2): dx studs east of it.
	local SPOT=Client.Spot
	local function from(dx)return Vector3.new(SPOT.X+dx,SPOT.Y,SPOT.Z)end
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
	-- The cases below are the nest before the egg corner (its own cases are at the end, CORNER).
	local ON={flags={OnboardingV3=true},studio=true,corner=false}
	local CORNER={flags={OnboardingV3=true},studio=true}
	local OFF={flags={OnboardingV3=true},studio=true,nest=false,corner=false}
	local NOW=1800000000
	local function rig(options)
		options=options or {}
		Onboard.inject(options.env or ON)
		local r={sent={},sounds={},toasts={},shows=0,at=from(10),open=true,menu=false,now=NOW,small=options.compact==true}
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
		local deps={remotes=r.remotes,world=r.world,player=r.player,step=false,now=function()return r.now end,
			root=function()return r.at end,free=function()return r.open end,busy=function()return r.menu end,
			reduced=function()return r.still==true end,compact=function()return r.small end,chipHost=function()return r.host end,
			focus=function()return r.focus==true end,chipHidden=function()return r.inPark==true end,
			ground=options.ground,measure=function(text,size)return #text*size*.5 end,show=function()r.shows+=1 end,
			toast=function(text,stars)table.insert(r.toasts,{text=text,stars=stars})end,
			audio={play=function(_,name)table.insert(r.sounds,name);return true end}}
		for key,value in pairs(options.deps or {})do deps[key]=value end
		r.client=Client.mount(deps)
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
	test("state: the nest's 21 parts and the egg, local and inert, at Nest.Spot in the plaza; junk and nil draw nothing",function()
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
				assert(item.Anchored and not item.CanCollide and not item.CanQuery and not item.CanTouch,item.Name)
				assert(item.CastShadow==(item.Name=="NestMound"),"only the mound casts a shadow: "..item.Name)
				if string.sub(item.Name,1,4)=="Nest"then nestParts+=1 end
			end
		end
		assert(nestParts==21,"21 nest parts, got "..nestParts)
		assert(parts==24,"the 21, the egg's anchor, its body and the prompt spot")
		local base=folder:FindFirstChild("NestMound")
		assert(math.abs(base.CFrame.Position.X-SPOT.X)<1e-6 and math.abs(base.CFrame.Position.Z-SPOT.Z)<1e-6,"at the plaza spot")
		assert(SPOT==Nest.Spot and SPOT==Vector3.new(-25.12,4.07,-9.82),"beta 14 D1: E1 slid .15 along e, the Eggs station's foot")
		assert(folder:FindFirstChild("NestCushion")==nil and folder:FindFirstChild("NestFlag")==nil and folder:FindFirstChild("NestLeaves")==nil,"the old cushion, flag and leaves are gone")
		local prompt=folder:FindFirstChild("SleepyNestPrompt"):FindFirstChild("NestPrompt")
		assert(prompt and prompt.ClassName=="ProximityPrompt"and prompt.RequiresLineOfSight==false)
		assert(prompt.MaxActivationDistance==4.5 and prompt.UIOffset==Vector2.new(0,72),"beta 14 D1: 4.5 beside the station; under the nest")
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
		assert(r.client.egg.clock.Text==UICopy.get("onb3.nest.ready"))
		r.now=NOW;r.fire(state(3600,{tucked=true}));r.client:step(0)
		assert(r.client.egg.clock.Text==UICopy.get("onb3.nest.hours",{hours=7}),r.client.egg.clock.Text)
		r.now=NOW;r.fire(state(Nest.Seconds-40*60,{tucked=true}));r.client:step(0)
		assert(r.client.egg.clock.Text==UICopy.get("onb3.nest.minutes",{minutes=40}),r.client.egg.clock.Text)
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
		r.fire(state(60,{n=1}));r.client:step(0)
		assert(r.client:act()==true and r.count("tuck")==1)
		assert(#r.toasts==0,"tucking pays nothing")
		assert(r.heard("pet_coo_1")==1 and r.client.egg.zzz.emitted~=nil)
		r.client:step(0);assert(r.client.egg.prompt.Enabled==false,"one tuck per egg")
		assert(r.client:act()==false and r.count("tuck")==1,"no second tuck")
		r.fire({kind="refused",reason="Tucked",of="tuck"})
		assert(r.client.tuck~=nil,"refused as Tucked: undoes nothing")
		local peek=r.client.egg.anchor:FindFirstChild("GiftPeek")
		assert(peek~=nil,"the gift peek")
		assert(peek:FindFirstChild("Tile"):FindFirstChild("Count").Text=="Egg 2 of 7","the egg's number is on the tile")
		for _=1,27 do r.client:step(.1)end
		assert(r.client.egg.clock.Text==UICopy.get("onb3.nest.tucked"),r.client.egg.clock.Text)
		assert(r.client.egg.anchor:FindFirstChild("GiftPeek")==nil,"the peek is gone")
		r.fire(state(70,{n=1,tucked=true}));r.client:step(0)
		assert(r.client.egg.prompt.Enabled==false,"a tucked egg: no prompt until it is ready")
		for _=1,45 do r.client:step(.1)end
		assert(r.client.egg.clock.Text~=UICopy.get("onb3.nest.tucked"),"the clock again after 4 s")
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
		assert(#r.toasts==1 and r.toasts[1].text==UICopy.get("onb3.nest.got",{item="Ball"})and r.toasts[1].stars==5,tostring(r.toasts[1]and r.toasts[1].text))
		assert(r.heard("hatch")==1 and r.client.egg.anchor:FindFirstChild("StarsGain")~=nil,"+5 floats up")
		for _=1,15 do r.client:step(.1)end
		assert(r.client.view.n==1 and r.heard("land")==1,"the new egg lands")
		assert(r.client.egg.clock.Text==UICopy.get("onb3.nest.next",{hours=Nest.Hours}))
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
	test("O2 remodel: the look's parts, sizes, faces and textures; the sign names the pet stored at land",function()
		local r=rig()
		r.fire(state(60))
		local folder=r.folder()
		local root=CFrame.lookAt(Vector3.new(SPOT.X,SPOT.Y,SPOT.Z),Vector3.new(Nest.Facing.X,SPOT.Y,Nest.Facing.Z))
		local function localAt(name)return root:PointToObjectSpace(folder:FindFirstChild(name).CFrame.Position)end
		local function close(a,b)return(a-b).Magnitude<1e-4 end
		local mound=folder:FindFirstChild("NestMound")
		assert(mound.Size==Vector3.new(.42,3.5,3.5)and close(localAt("NestMound"),Vector3.new(0,.21,0))and mound.Material==Enum.Material.Wood)
		local twigs=0
		for _,t in ipairs(mound:GetChildren())do if t.ClassName=="Texture"then twigs+=1;assert(t.Texture==LifeArt.id("nestTwigs")and t.StudsPerTileU==2.4 and t.StudsPerTileV==1.2)end end
		assert(twigs==4,"twigs on the four curved faces")
		for k=0,7 do
			local rim=folder:FindFirstChild("NestRim"..(k+1))
			local at=localAt("NestRim"..(k+1))
			local r0=if k%2==0 then 1.42 else 1.50
			assert(rim.Size==Vector3.new(1.30,.66,.66)and math.abs(Vector3.new(at.X,0,at.Z).Magnitude-r0)<1e-4,"rim "..k)
			assert(rim.Material==Enum.Material.Wood,"FABLE-REVIEW-R1 3: wood, not varnish")
			local t=rim:FindFirstChildOfClass("Texture")
			assert(t and math.abs(t.OffsetStudsU-.37*k)<1e-6)
			local faces={}
			for _,c in ipairs(rim:GetChildren())do if c.ClassName=="Texture"then faces[c.Face]=true end end
			assert(faces[Enum.NormalId.Left]and faces[Enum.NormalId.Right],"twigs on both caps: no flat brown slat")
		end
		local straw=folder:FindFirstChild("NestStraw")
		assert(straw.Size==Vector3.new(.30,2.36,2.36)and close(localAt("NestStraw"),Vector3.new(0,.55,0)))
		assert(straw.CFrame.RightVector.Y>.99,"the Right cap faces up")
		local bed=straw:FindFirstChildOfClass("Decal")
		if LifeArt.id("strawBed")then assert(bed and bed.Face==Enum.NormalId.Right)else assert(bed==nil,"no stand-in while pending")end
		for k=1,6 do
			local plate=folder:FindFirstChild("NestFringe"..k)
			assert(plate.Transparency==1 and plate.Size==Vector3.new(1.9,1.05,.04))
			local at=localAt("NestFringe"..k)
			assert(math.abs(Vector3.new(at.X,0,at.Z).Magnitude-1.62)<1e-4 and math.abs(at.Y-.78)<1e-4)
			-- Tipped outward: the plate's top leans away from the middle.
			local upLocal=root:VectorToObjectSpace(plate.CFrame.UpVector)
			assert(Vector3.new(upLocal.X,0,upLocal.Z):Dot(Vector3.new(at.X,0,at.Z).Unit)>.3,"fringe "..k.." tips out")
			assert(#plate:GetChildren()==2)
		end
		for k=1,3 do assert(folder:FindFirstChild("NestTuft"..k).Size==Vector3.new(1.3,.62,.04))end
		local post,board=folder:FindFirstChild("NestSignPost"),folder:FindFirstChild("NestSign")
		assert(post.Material==Enum.Material.Wood and board.Material==Enum.Material.Wood and board.Size==Vector3.new(1.3,.8,.08))
		assert(close(localAt("NestSign"),Vector3.new(-1.7,1.45,1.6)),"beta 14 D1 (Fable R2): the outer side, behind the Bear")
		-- STUDIO-CHECK-R2: the post never rises behind the board's words (on either face); the board sits on its top.
		local lowest=math.huge
		for _,x in ipairs({-.65,0,.65})do for _,z in ipairs({-.04,.04})do
			lowest=math.min(lowest,root:PointToObjectSpace(board.CFrame:PointToWorldSpace(Vector3.new(x,-.4,z))).Y)
		end end
		local top=root:PointToObjectSpace(post.CFrame:PointToWorldSpace(Vector3.new(0,post.Size.Y/2,0))).Y
		assert(top>=lowest and top<=lowest+.08,"the post meets the board's bottom edge: top "..top..", board "..lowest)
		assert(close(localAt("NestSignPost")*Vector3.new(1,0,1),Vector3.new(-1.7,0,1.6)),"under the board's middle")
		local front=root:VectorToObjectSpace(board.CFrame.LookVector)
		assert(front.Z<-.5 and front.X<-.5,"beta 14 D1: the board's Front looks forward-left: "..tostring(front))
		-- Fable R2: the Front reads along the walk in, within 40 degrees of square on at the path mouth, the bridge, two
		-- points on the way and the hub.
		local at=board.CFrame.Position
		local function facing(point,normal)
			local to=Vector3.new(point.X-at.X,0,point.Z-at.Z).Unit
			return to:Dot(Vector3.new(normal.X,0,normal.Z).Unit)
		end
		local look=board.CFrame.LookVector
		for _,p in ipairs({Vector3.new(14,0,21),Vector3.new(2.5,0,21),Vector3.new(-10,0,12),Vector3.new(-20,0,8),Vector3.new(-30,0,4)})do
			assert(facing(p,look)>math.cos(math.rad(40)),"the Front from "..tostring(p).." "..math.deg(math.acos(facing(p,look))))
		end
		local words=board:FindFirstChild("Words"):FindFirstChild("Name")
		local back=board:FindFirstChild("WordsBack")
		assert(back and back.Face==Enum.NormalId.Back and back.AlwaysOnTop==false)
		assert(words.Text==Client.signText(r.client.view),"the pet stored at land: "..words.Text)
		assert(back:FindFirstChild("Name").Text==words.Text,"both faces name the pet")
		local signDecals={}
		for _,c in ipairs(board:GetChildren())do if c.ClassName=="Decal"then signDecals[c.Face]=true end end
		if LifeArt.id("nestSign")then assert(signDecals[Enum.NormalId.Front]and signDecals[Enum.NormalId.Back],"painted on both faces")end
		assert(Client.signText({pet="pip"})==UICopy.get("onb3.nest.sign",{pet="Bear"}),"a named pet")
		assert(Client.signText({pet="nobody"})==UICopy.get("onb3.nest.signPlain"))
		assert(math.abs(Client.EggBase-.64)<1e-9 and Client.BearSpot==Vector3.new(-2.2,0,-1.4),"beta 14 D1: the Bear on the outer side")
		assert(close(localAt("SleepyEgg"),Vector3.new(0,.64,0)),"the egg on the straw")
		Onboard.inject(nil)
	end)
	test("nestPlace: the front of the nest on the raycast ground, nil without a nest",function()
		local r=rig({ground=function()return 5 end})
		assert(r.client:place3D()==nil)
		r.fire(state(60))
		local at=r.client:place3D()
		assert(typeof(at)=="Vector3")
		assert(math.abs(at.Y-6)<1e-6,"ground 5, the prompt 1 over it: "..tostring(at.Y))
		local centre=Vector3.new(SPOT.X,6,SPOT.Z)
		assert(math.abs((at-centre).Magnitude-Nest.Front)<1e-6,"Front studs toward the plaza's middle")
		local toward=(Vector3.new(Nest.Facing.X,6,Nest.Facing.Z)-centre).Unit
		assert(((at-centre).Unit-toward).Magnitude<1e-6,"the front faces the plaza's middle")
		Onboard.inject(nil)
		-- A pet (or a player) standing on the spot is not the ground: the walk map's ground is kept.
		local onPet=rig({ground=function()return SPOT.Y+2.4 end})
		onPet.fire(state(60))
		assert(math.abs(onPet.client:place3D().Y-(SPOT.Y+1))<1e-6,"the hit on the pet is ignored")
		Onboard.inject(nil)
	end)
	test("the chip: 7 h, 40 min, Ready!; gold when ready; above the dock, never wider; hidden in the park",function()
		assert(Client.chipText(7*3600-5)==UICopy.get("onb3.nest.chipHours",{hours=7})and Client.chipText(40*60)==UICopy.get("onb3.nest.chipMinutes",{minutes=40})and Client.chipText(0)==UICopy.get("onb3.nest.chipReady"))
		assert(Client.chipText(3601)==UICopy.get("onb3.nest.chipHours",{hours=2})and Client.chipText(3600)==UICopy.get("onb3.nest.chipMinutes",{minutes=60})
			and Client.chipText(1)==UICopy.get("onb3.nest.chipMinutes",{minutes=1}),"rounded up, never 0")
		local r=rig()
		r.fire(state(3600));r.client:step(0)
		local chip=r.client.chip
		assert(chip and chip.button.Parent==r.host and chip.label.Text==UICopy.get("onb3.nest.chipHours",{hours=7})and chip.width>0)
		assert(chip.ready==false)
		r.now=NOW;r.fire(state(Nest.Seconds));r.client:step(0)
		assert(chip.label.Text==UICopy.get("onb3.nest.chipReady")and chip.ready==true and chip.pill.BackgroundColor3==Client.Color.stars)
		r.small=true;r.client:step(0)
		assert(r.client.chip~=chip and #r.host:GetChildren()==1 and r.client.chip.hit==44,"phone: rebuilt, 44 px hit")
		assert(r.client.chip.button:GetAttribute("AccessibleLabel")==Client.how(r.client.view),"the chip names the egg")
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
	test("the ready ping: once per egg within 14 studs; Inside only within 8 (beta 14 Q2: in the one pill)",function()
		local r=rig()
		r.at=from(34)
		r.fire(state(Nest.Seconds,{n=1}));r.client:step(0)
		assert(r.heard("machine_attract")==0 and r.client.egg.board.Enabled==false,"34 studs: no pill")
		r.at=from(10);r.client:step(0)
		assert(r.heard("machine_attract")==1 and r.client.egg.clock.Text==UICopy.get("onb3.nest.ready"),"10 studs: the ping, Hatch me!")
		r.at=from(34);r.client:step(0);r.at=from(4);r.client:step(0)
		assert(r.heard("machine_attract")==1,"once per egg")
		assert(r.client.egg.anchor:FindFirstChild("GiftPeek")==nil)
		r.fire(state(Nest.Seconds,{n=8,gift={kind="stars",stars=4}}));r.client:step(0)
		assert(r.heard("machine_attract")==2,"a new egg pings again")
		-- Not ready yet: the clock beyond 8 studs, what is inside within it.
		r.now=NOW;r.fire(state(60,{n=1,tucked=true}));r.at=from(10);r.client:step(0)
		assert(r.client.egg.clock.Text==UICopy.get("onb3.nest.hours",{hours=8}),r.client.egg.clock.Text)
		r.at=from(4);r.client:step(0)
		assert(r.client.egg.clock.Text=="Inside: Ball and 5 Stars.",r.client.egg.clock.Text)
		assert(r.client.egg.count==nil and r.client.egg.board:FindFirstChild("Count")==nil,"no Egg n of 7 on the world label")
		assert(r.client.egg.board:FindFirstChild("InsidePill")==nil and r.client.egg.insidePill==nil,"beta 14 Q2: no second pill")
		r.focus=true;r.client:step(0);assert(r.client.egg.board.Enabled==false,"hidden during the pet focus camera")
		r.focus=false;r.client:step(0);assert(r.client.egg.board.Enabled==true)
		Onboard.inject(nil)
	end)
	-- Beta (12) QA O1 (GARDEN-LIFE-NEST-LOOK 5): plain words for the napping egg.
	test("O1: before the tuck-in of the first egg the pill explains it (within 12 studs, beta 14 Q2); Nest.Hours, the pet's name, a plain fallback",function()
		local r=rig()
		r.at=from(34)
		r.fire(state(60));r.client:step(0)
		assert(r.client.egg.board.Enabled==false,"34 studs: nothing")
		r.at=from(6);r.client:step(0)
		local how=Client.how(r.client.view)
		assert(Client.how({pet="pip"})==UICopy.get("onb3.nest.how",{pet="Bear",hours=Nest.Hours}),"the pet's name from PetCatalog")
		assert(r.client.egg.clock.Text==how and r.client.egg.board.Enabled,r.client.egg.clock.Text)
		assert(string.find(how,tostring(Nest.Hours),1,true)and not string.find(how,"{",1,true),"filled")
		assert(r.client.egg.clock.TextWrapped==true and select(1,Client.pillSize(#how*13*.5,#how*12*.5))==2,"two lines in the 220 px pill")
		assert(Client.how({pet="nobody"})==UICopy.get("onb3.nest.howPlain",{hours=Nest.Hours}),"no name: the plain line")
		assert(Client.secondLine({n=1,pet="bear",gift={kind="stars",stars=3}})==UICopy.get("onb3.nest.insideStars",{stars=3}),"after a hatch: Inside")
		assert(r.client.egg.prompt.ObjectText==UICopy.get("onb3.nest.title"))
		Onboard.inject(nil)
	end)
	test("O1: the first tuck-in ever holds its own line for 6 s (beta 14 Q2: no rail toast any more)",function()
		local r=rig()
		r.fire(state(60));r.client:step(0)
		assert(r.client:act()==true and #r.toasts==0)
		for _=1,27 do r.client:step(.1)end
		local first=UICopy.get("onb3.nest.tuckedFirst",{hours=Nest.Hours})
		assert(r.client.egg.clock.Text==first,r.client.egg.clock.Text)
		assert(#r.toasts==0,"no rail toast")
		for _=1,50 do r.client:step(.1)end
		assert(r.client.egg.clock.Text==first,"still there at 5 s")
		for _=1,15 do r.client:step(.1)end
		assert(r.client.egg.clock.Text~=first,"the clock again after 6 s")
		Onboard.inject(nil)
	end)
	-- Beta 14 QA Q2 (WORLD-AND-NEST-LOOK 4): one pill, one message.
	test("Q2: the seven rows, first true wins",function()
		local view={n=0,pet="pip",tucked=false,gift={kind="toy",item="ball",stars=5}}
		local function row(ctx,v)return Client.row(v or view,ctx)end
		assert(row({beat={row=1,text="b"},look="ready"}).row==1,"a beat over everything")
		assert(row({look="ready",near=3}).row==4 and row({look="ready"}).gold)
		assert(row({look="small",near=3}).row==5,"untucked, no hatch yet: the explainer")
		assert(row({look="small",near=3,tucked=true}).row==7,"tucked: the clock")
		local later={n=2,pet="pip",gift={kind="stars",stars=4}}
		assert(row({look="glow",near=7.9},later).row==6 and row({look="glow",near=8.1},later).row==7)
		assert(row({look="glow",near=3,bubble=true},later).hidden and not row({look="ready",bubble=true},later).hidden)
		assert(row({look="ready",bubble=true},later).lift and not row({look="ready"},later).lift)
		assert(row({beat={row=3,text="x"},bubble=true}).onTop and not row({look="ready"}).onTop,"AlwaysOnTop only for beats")
	end)
	test("Q2: shown by the player's distance: 12 fading from 10 (rows 5 to 7), 18 from 15 (ready), 18 (beats)",function()
		assert(Client.fade(20,12,10)==1 and Client.fade(12.01,12,10)==1 and math.abs(Client.fade(11,12,10)-.5)<1e-9 and Client.fade(10,12,10)==0 and Client.fade(4,12,10)==0)
		assert(Client.fade(18.5,18,15)==1 and math.abs(Client.fade(16.5,18,15)-.5)<1e-9 and Client.fade(15,18,15)==0)
		assert(Client.fade(18,18,18)==0 and Client.fade(18.1,18,18)==1 and Client.fade(nil,12,10)==1)
		local r=rig();r.fire(state(60,{n=1,tucked=true}))
		for _,row in ipairs({{20,1},{12.5,1},{11,.5},{10,0},{4,0}})do
			r.at=from(row[1]);r.client:step(0)
			assert(math.abs(r.client.egg.clock.TextTransparency-row[2])<1e-6 and r.client.egg.board.Enabled==(row[2]<1),row[1])
		end
		r.now=NOW;r.fire(state(Nest.Seconds,{n=1}));r.at=from(17);r.client:step(0);assert(r.client.egg.board.Enabled,"ready: up to 18")
		assert(r.client.egg.board.AlwaysOnTop==false and r.client.egg.halo.MaxDistance==80 and r.client.egg.stillZ.MaxDistance==40)
		Onboard.inject(nil)
	end)
	test("Q2: the need bubble: rows 5 to 7 hide while it shows with the pet within 6 studs; ready lifts 34 px; a beat holds the bubble back",function()
		local bubble={shown=false}
		local r=rig();r.client.d.bubble=function()return bubble end
		r.fire(state(60,{n=1,tucked=true}));r.at=from(4);r.client:step(0);assert(r.client.egg.board.Enabled)
		bubble={shown=true,pet=from(7)};r.client:step(0);assert(r.client.egg.board.Enabled,"the pet 7 studs off: not over the nest")
		bubble={shown=true,pet=from(3)};r.client:step(0);assert(not r.client.egg.board.Enabled,"the pet at the nest with its bubble: no pill")
		r.now=NOW;r.fire(state(Nest.Seconds,{n=1}));r.client:step(0)
		assert(r.client.egg.board.Enabled and r.client.egg.row.lift==true,"ready: both, the pill over the bubble")
		bubble={shown=false};r.client:step(0);assert(r.client.egg.row.lift==false)
		-- A beat: held over the bubble, and the bubble held back until .3 s after it.
		r.now=NOW;r.fire(state(60,{n=1}));r.client:step(0)
		assert(not r.client:holdsBubble())
		r.client:act();for _=1,27 do r.client:step(.1)end
		bubble={shown=true,pet=from(1)};r.client:step(0)
		assert(r.client:holdsBubble()and r.client.egg.board.Enabled and r.client.egg.board.AlwaysOnTop,"the tucked beat shows over the bubble")
		for _=1,45 do r.client:step(.1)end
		assert(not r.client:holdsBubble(),"the bubble may come back .3 s after the 4 s beat")
		Onboard.inject(nil)
	end)
	test("Q2: the pill hides under the gift peek; a long sentence drops to 12 px before a third line",function()
		local r=rig();r.at=from(4)
		r.fire(state(60,{n=1}));r.client:step(0)
		r.client:act();r.client:step(.1);assert(r.client.egg.anchor:FindFirstChild("GiftPeek")and not r.client.egg.board.Enabled,"under the peek")
		for _=1,26 do r.client:step(.1)end;assert(r.client.egg.board.Enabled and r.client.egg.clock.Text==UICopy.get("onb3.nest.tucked"))
		local lines,w,h,small=Client.pillSize(80);assert(lines==1 and w==Client.Pill.min and h==28 and not small)
		lines,w,h=Client.pillSize(190);assert(lines==1 and w==214 and h==28)
		lines,w,h=Client.pillSize(300);assert(lines==2 and w==220 and h==46)
		lines,w,h,small=Client.pillSize(600,500);assert(lines==2 and small,"three lines at 13 px: 12 px")
		Onboard.inject(nil)
	end)
	test("D1: the Hatch eggs row (quiet, no price); the station's prompt steps aside where the nest's can act and is nearer",function()
		assert(Client.menuRow(nil)==nil)
		local row=Client.menuRow({left=7*3600-5})
		assert(row.title==UICopy.get("onb3.nest.title")and row.clock==UICopy.get("onb3.nest.hours",{hours=7})and not row.ready)
		row=Client.menuRow({left=0});assert(row.ready and row.clock==UICopy.get("onb3.nest.ready"))
		local Stations=require(client.LoungeStations)
		Stations.Yield.Eggs=nil -- earlier rigs stay open; the game has one
		assert(not Stations.yields("Eggs",Vector3.zero,nil),"no nest: the station as before")
		local r=rig();r.fire(state(60,{n=1}));r.client:step(0)
		assert(Stations.Yield.Eggs~=nil)
		local front=r.client:place3D()
		local station={Position=front+Vector3.new(5,1,0)}
		assert(Stations.yields("Eggs",front,station),"at the nest's front: the nest's E")
		assert(not Stations.yields("Eggs",front+Vector3.new(4,0,0),station),"nearer the station: the station's E")
		assert(not Stations.yields("Journal",front,station))
		r.fire(state(70,{n=1,tucked=true}));r.client:step(0)
		assert(not Stations.yields("Eggs",front,station),"nothing to do at the nest: the station keeps its E")
		Onboard.inject(OFF);r.client:step(0);assert(Stations.Yield.Eggs==nil,"the switch off takes the claim away")
		Onboard.inject(nil)
	end)
	test("Q2: the need bubble's wrapper (BubbleHold): no hold passes every call through as before; a nest beat holds it and lets it back",function()
		local Hold=require(client.BubbleHold)
		local log={}
		local function make()
			local real={}
			function real:set(icon,visible)table.insert(log,{icon,visible})end
			function real:hop()table.insert(log,"hop")end;function real:press()table.insert(log,"press")end
			function real:step()end;function real:destroy()table.insert(log,"gone")end
			return real
		end
		local plain=Hold.new(make,nil)
		plain:set("toy",false);assert(plain.real==nil and #log==0,"made only when a bubble shows")
		plain:set("toy",true);plain:hop();plain:press();plain:step(.1);plain:set(nil,false);plain:destroy()
		assert(log[1][1]=="toy"and log[1][2]==true and log[2]=="hop"and log[3]=="press"and log[4][2]==false and log[5]=="gone"and #log==5,"as before")
		table.clear(log)
		local held=true
		local hold=Hold.new(make,function()return held end)
		hold:set("toy",true);assert(log[1][2]==false and hold:state().held and not hold:state().shown,"held back by the beat")
		hold:step(.1);assert(#log==1,"no rewrite while still held")
		held=false;hold:step(.1);assert(log[2][1]=="toy"and log[2][2]==true and hold:state().shown,"back after the beat")
		held=true;hold:step(.1);assert(log[3][2]==false)
		hold:set(nil,false);held=false;hold:step(.1);assert(log[4][2]==false and #log==4,"a hidden bubble stays hidden")
	end)
	-- ── The egg corner (EGG-CORNER-BUILD-PLAN 8; EGG-CORNER-LOOK 3, R2 3) ───────────────────────────────────────────
	local Corner=require(Shared.EggCorner)
	local function cornerRig(options)
		options=options or {}
		local r
		local helps={}
		local deps={help=function(nest)table.insert(helps,nest);return true end,split=function()return r and r.split==true end,
			gui=function()return r and r.gui end,helpPulse=function()return r and r.pulseDue==true end,
			helpPulsed=function()if r then r.pulsed=(r.pulsed or 0)+1;r.pulseDue=false end end}
		for key,value in pairs(options.deps or {})do deps[key]=value end
		r=rig({env=options.env or CORNER,deps=deps})
		r.helps=helps
		r.gui=Instance.new("Folder")
		return r
	end
	test("corner: the nest stays at E1 until the island split, then stands at (-31, -11) facing the plaza; no Yield either way",function()
		local Stations=require(client.LoungeStations)
		Stations.Yield.Eggs=nil
		local r=cornerRig()
		r.fire(state(60))
		assert(r.client.corner==true and r.client.spot==Nest.Spot and Stations.Yield.Eggs==nil,"not split: E1, no Yield")
		local split=cornerRig()
		split.split=true;split.client:close();split.client:sync();split.fire(state(60))
		assert(split.client.spot==Corner.NestSpot and split.client.facing==Corner.nestFacing())
		local root=split.client.root
		assert(math.abs(root.X+31)<1e-6 and math.abs(root.Z+11)<1e-6)
		local toward=(Vector3.new(Corner.NestFacing.X,root.Y,Corner.NestFacing.Z)-root.Position).Unit
		assert(root.LookVector:Dot(toward)>.9999,"root -Z faces the plaza middle")
		local straw,leaves,shadow=0,0,split.folder():FindFirstChild("NestShadow")
		for _,part in ipairs(split.folder():GetChildren())do
			if string.match(part.Name,"^ScatterStraw")then straw+=1 elseif string.match(part.Name,"^ScatterLeaf")then leaves+=1 end
		end
		assert(straw==12 and leaves==3 and shadow~=nil,"the scatter and the contact shadow on plain marble: "..straw..","..leaves..","..tostring(shadow~=nil))
		assert(r.folder():FindFirstChild("NestShadow")==nil,"none at E1")
		Onboard.inject(nil)
	end)
	test("corner: a switch flip closes and re-opens the nest where it now stands; off gives the station's Yield back",function()
		local Stations=require(client.LoungeStations)
		Stations.Yield.Eggs=nil
		local r=cornerRig()
		r.split=true;r.client:close();r.client:sync();r.fire(state(60))
		assert(r.client.spot==Corner.NestSpot)
		Onboard.inject(ON);r.client:relocate()
		assert(r.client.isOpen and r.client.corner==false and r.client.spot==Nest.Spot and Stations.Yield.Eggs~=nil)
		assert(r.count("sync")>=2,"asks for the nest again")
		Onboard.inject(nil)
		Stations.Yield.Eggs=nil
	end)
	test("Studio check R8: the corner off closes the open ? card (the nest only moves); on again does not",function()
		local closed=0
		local r=cornerRig({deps={helpClose=function()closed+=1 end}})
		r.fire(state(60))
		Onboard.inject(ON);r.client:relocate()
		assert(closed==1 and r.client.corner==false)
		Onboard.inject(CORNER);r.client:relocate()
		assert(closed==1 and r.client.corner==true)
		Onboard.inject(nil)
	end)
	test("corner rows: napping is the clock and the disc (no explainer, no Inside); ready is Hatch me! without it",function()
		local view=Client.parse(public(60))
		local row=Client.row(view,{look="small",left=Nest.Seconds-60,near=2,tucked=false,corner=true})
		assert(row.row==7 and row.help==true and row.text==(Client.clock(Nest.Seconds-60)))
		local later=Client.parse(public(60,{n=2,tucked=true}))
		row=Client.row(later,{look="glow",left=100,near=2,tucked=true,corner=true})
		assert(row.row==7 and row.help==true,"no Inside row near the nest")
		row=Client.row(view,{look="ready",left=0,corner=true})
		assert(row.row==4 and row.gold and not row.help)
		row=Client.row(view,{beat={row=1,text="Tucked in!"},look="small",left=100,corner=true})
		assert(row.row==1 and not row.help,"the beats stay")
		local old=Client.row(view,{look="small",left=100,near=2,tucked=false})
		assert(old.row==5 and not old.help,"off: as before")
	end)
	test("corner prompt: Tuck in, then Peek (beta 17 U3: a 1.6 s look, no card, no packet), then Hatch",function()
		local r=cornerRig()
		r.fire(state(60));r.step(.1)
		assert(r.client.action=="tuck"and r.client:act())
		r.fire(state(60,{tucked=true}));r.step(3)
		assert(r.client.action=="peek"and r.client.egg.prompt.ActionText==UICopy.get("onb3.nest.peek"))
		local sent=#r.sent
		r.at=from(1)
		assert(r.client:act()==true and #r.helps==0 and #r.sent==sent,"Peek: no card, nothing sent")
		assert(r.client.egg.anchor:FindFirstChild("GiftPeek"),"the gift tile")
		r.step(.1)
		assert(not r.client.egg.prompt.Enabled,"the prompt is off while it plays")
		assert(r.client.egg.board.Enabled,"the pill keeps its clock during the look")
		assert(not r.client:act(),"E never stacks peeks")
		for _=1,16 do r.step(.1)end
		assert(r.client.looking==nil and r.client.egg.anchor:FindFirstChild("GiftPeek")==nil,"over by 1.7")
		assert(not r.client.egg.prompt.Enabled,"and .6 s after")
		r.step(.6);assert(r.client.egg.prompt.Enabled,"back")
		local lift=Client.lookPose(.5)
		assert(math.abs(lift-Client.Look.lift)<1e-6 and Client.lookPose(.5,true)==0,"the stir; none with Reduced Motion")
		r.menu=true;r.step(.1);assert(not r.client.egg.prompt.Enabled,"hidden behind an open card (busy)")
		r.menu=false
		r.now+=Nest.Seconds;r.step(.1)
		assert(r.client.action=="hatch")
		assert(r.client.egg.help~=nil and r.client.egg.helpTap~=nil,"the disc and the pill's tap target")
		assert(r.client.egg.board.Parent==r.gui and r.client.egg.board.Adornee==r.client.egg.anchor,"the board lives in PlayerGui")
		assert(#r.toasts==0,"no rail toast on tuck (beta 14 Q2 stays)")
		Onboard.inject(nil)
	end)
	test("corner card: what, time, gift, inside, free, next, wait; the live clock with Egg n of 7; Hatch me! once ready",function()
		local r=cornerRig()
		r.fire(state(3600,{n=1,gift={kind="stars",stars=15}}))
		local card=r.client:helpNow()
		assert(card.title==UICopy.get("onb3.nest.help.title")and card.button==UICopy.get("onb3.nest.help.button"))
		local keys={}
		for _,line in ipairs(card.lines)do table.insert(keys,line.key)end
		assert(table.concat(keys,",")=="what,time,gift,inside,free,next,wait",table.concat(keys,","))
		assert(card.lines[2].text==UICopy.get("onb3.nest.help.time",{hours=Nest.Hours}))
		assert(card.lines[4].text==UICopy.get("onb3.nest.insideStars",{stars=15}))
		assert(string.find(card.live,UICopy.get("onb3.nest.count",{count=2}),1,true),card.live)
		r.now+=Nest.Seconds
		card=r.client:helpNow()
		assert(card.ready and card.live==UICopy.get("onb3.nest.ready"),"an egg that wakes while the card is open says so")
		Onboard.inject(nil)
	end)
	test("corner: the disc's first-time pulse is asked once, saved once, and plays twice (none with Reduced Motion)",function()
		local r=cornerRig()
		r.pulseDue=true
		r.fire(state(60,{tucked=true}));r.at=from(1)
		for _=1,5 do r.step(.1)end
		assert(r.pulsed==1 and r.client.pulse~=nil)
		for _=1,12 do r.step(.1)end
		assert(r.client.pulse==nil and r.client.egg.helpScale.Scale==1 and r.pulsed==1)
		Onboard.inject(nil)
	end)
	-- ── The Sleepy Nest landmark (NEST-LANDMARK-LOOK; NestLandmark) ───────────────────────────────────────────────────
	-- The server's ONE shared model (code review of 443346b): a stand-in with the template's names, rest poses and root.
	local Land=require(Shared.NestLandmark)
	local function sharedModel()
		local data=Land.data()
		local root=CFrame.lookAt(Vector3.new(Corner.NestSpot.X,Corner.NestSpot.Y,Corner.NestSpot.Z),
			Vector3.new(Corner.NestFacing.X,Corner.NestSpot.Y,Corner.NestFacing.Z))
		local model=Instance.new("Model");model.Name="NestLandmark"
		for _,name in ipairs(Client.LandmarkNames)do
			local p=Instance.new("Part");p.Name=name
			local info=data.parts[name]
			p.Size=if info then Vector3.new(info.size[1],info.size[2],info.size[3])else Vector3.new(4.8,2.75,4.8)
			p.CFrame=root*CFrame.new(if info then Vector3.new(info.center[1],info.center[2],info.center[3])else Vector3.new(0,1.375,0))
			p.Transparency=if name=="BlanketDraped"or name=="BlanketSlipped"or name=="Collider"then 1 else 0
			p.Color=Color3.new(1,1,1)
			p.CanCollide=name=="Collider"
			p:SetAttribute("WorldRestCFrame",p.CFrame);p:SetAttribute("RestTransparency",p.Transparency)
			p.Parent=model
		end
		model:SetAttribute("NestRoot",root)
		return model
	end
	local function landRig(options)
		options=options or {}
		local r
		r=cornerRig({deps={split=function()return true end,landmark=function()return r==nil or r.landmarkOn~=false end,
			landmarkModel=function()return r and r.model end,daylight=function()return r and r.daylight or 1 end}})
		r.landmarkOn=options.landmarkOn
		r.model=if options.model==false then nil else sharedModel()
		if options.landmarkOn==false then r.client:close();r.client:sync()end
		return r
	end
	test("landmark: the server's shared model, animated here; no twig parts, a sign on the bowl, prompt, pill and pin",function()
		local r=landRig()
		r.fire(state(60));r.step(.1)
		local folder=r.folder()
		assert(r.client.landmark==true and folder:FindFirstChild("NestMound")==nil)
		assert(folder:FindFirstChild("NestLandmark")==nil,"no local copy: the shared one is the server's")
		local L=r.client.landmarkState
		assert(L.model==r.model and L.parts.Collider==r.model:FindFirstChild("Collider"))
		assert(r.model.Collider.CanCollide==true,"solid for everyone (the server's), untouched here")
		local sign=folder:FindFirstChild("NestSign")
		local into=r.client.root:PointToObjectSpace(sign.CFrame.Position)
		assert(math.abs(into.Z+2.45)<1e-6 and math.abs(into.Y-1.15)<1e-6,"the sign on the bowl's front")
		local prompt=r.client.root:PointToObjectSpace(r.client:place3D())
		assert(math.abs(prompt.Z+3.5)<1e-6 and math.abs(prompt.Y-1)<1e-6,"the prompt at (0, 1, -3.5)")
		assert(r.client.bearSpot==Land.BearSpot and r.client.eggBase==2.15 and r.client.eggScales==Land.EggScales)
		-- StudsOffsetWorldSpace is in the adornee's object space (Studio R11), so through the anchor's frame.
		local pill=r.client.root:VectorToObjectSpace(r.client.egg.anchor.CFrame:VectorToWorldSpace(r.client.egg.board.StudsOffsetWorldSpace))
		assert(math.abs(pill.Y-(Land.PillAt-2.15))<1e-6 and math.abs(pill.Z+1)<1e-6 and math.abs(pill.X)<1e-6,"the pill at (0, 5.2, -1.0) in front of the root")
		assert(r.client.egg.board.AlwaysOnTop==false,"never over the landmark")
		assert(math.abs(r.client.shownScale-Land.EggScales.small)<1e-6,"the small look at 1.6")
		local pin=r.client.root:PointToObjectSpace(r.client:pinAt())
		assert(math.abs(pin.Y-8.2)<1e-6 and math.abs(pin.X)<1e-6 and math.abs(pin.Z)<1e-6,"the pin over the bowl's centre")
		assert(math.abs(folder:FindFirstChild("NestShadow").Size.X-6.6)<1e-6,"the shadow r 3.3")
		Onboard.inject(nil)
	end)
	test("landmark: the blanket folded, draped after Tuck in (unrolling), slipped when ready, folded again after the hatch",function()
		local r=landRig()
		r.fire(state(60));r.step(.1)
		local P=r.client.landmarkState.parts
		assert(P.BlanketFolded.Transparency<1 and P.BlanketDraped.Transparency==1 and P.BlanketSlipped.Transparency==1)
		r.client:act();r.step(.1)
		assert(P.BlanketDraped.Transparency<1 and P.BlanketFolded.Transparency==1,"tucked: draped")
		local unrolling=P.BlanketDraped.Size.Y
		r.step(1)
		assert(P.BlanketDraped.Size.Y>unrolling,"it unrolls from its lower edge")
		r.now+=Nest.Seconds;r.step(.1)
		assert(P.BlanketSlipped.Transparency<1 and P.BlanketDraped.Transparency==1,"ready: slipped")
		r.client:act();r.fire({kind="claimed",receipt={kind="stars",stars=5}})
		for _=1,30 do r.step(.1)end
		r.fire(state(NOW-r.now,{n=1}));r.step(.1) -- a new egg that landed just now
		assert(P.BlanketFolded.Transparency<1 and P.BlanketSlipped.Transparency==1,"the next egg: folded")
		Onboard.inject(nil)
	end)
	test("landmark: the moon lantern off by day, a 3 s linear fade at dusk (halo too), gold when ready at any hour",function()
		local r=landRig()
		r.fire(state(60));r.step(.1)
		local L=r.client.landmarkState
		assert(not L.light.Enabled and not L.halo.Enabled,"day: no light, no halo")
		r.daylight=.1
		r.step(1.5)
		assert(math.abs(L.light.Brightness-.3)<1e-6,"half way through the fade: half bright")
		assert(math.abs(L.haloImage.ImageTransparency-(1-.4*.5))<1e-6,"the halo fades with it")
		r.step(1.5)
		assert(L.light.Enabled and math.abs(L.light.Brightness-.6)<1e-6 and L.light.Range==9 and L.halo.Enabled)
		r.daylight=1;r.step(1.5)
		assert(math.abs(L.light.Brightness-.3)<1e-6,"fades out the same way")
		r.now+=Nest.Seconds;r.step(.1)
		assert(L.light.Enabled and L.light.Range==10 and L.light.Brightness>=.8*.8-1e-6 and L.light.Color==Land.Moon.ready.color,"ready: lit by day too")
		Onboard.inject(nil)
	end)
	test("landmark: the moon's daylight from HollowClock's real shape (daylight(), lastDaylight, sample's second value)",function()
		assert(Client.daylightFrom({daylight=function()return .2 end})==.2)
		assert(Client.daylightFrom({lastDaylight=.15})==.15)
		assert(Client.daylightFrom({sample=function(t)return 21.5,.05,t end},100)==.05)
		assert(Client.daylightFrom({daylight=function()error("no")end,lastDaylight=.4})==.4)
		assert(Client.daylightFrom(nil)==1 and Client.daylightFrom({})==1)
	end)
	test("landmark: closing the nest puts the shared model back as the server left it; a late model is bound when it comes",function()
		local r=landRig({model=false})
		r.fire(state(60,{tucked=true}));r.step(.1)
		assert(r.client.landmarkState.model==nil,"no model yet: the egg and the sign still draw")
		r.model=sharedModel();r.step(.1)
		local P=r.client.landmarkState.parts
		assert(P.BlanketDraped and P.BlanketDraped.Transparency==0,"bound the moment it arrives")
		local rest=r.model.Moon:GetAttribute("WorldRestCFrame")
		r.step(1)
		r.client:close()
		assert(r.model.BlanketDraped.Transparency==1 and r.model.BlanketFolded.Transparency==0 and r.model.Moon.CFrame==rest,"restored")
		assert(r.client.landmarkState==nil)
		Onboard.inject(nil)
	end)
	test("landmark: off (its own switch) draws the twig nest at the same spot; a flip re-opens it",function()
		local r=landRig({landmarkOn=false})
		r.fire(state(60));r.step(.1)
		assert(r.client.landmark==false and r.folder():FindFirstChild("NestMound"))
		assert(r.client.spot==Corner.NestSpot and r.client:pinAt()==nil)
		r.landmarkOn=true;r.client:relocate()
		assert(r.client.landmark==true,"re-opened as the landmark")
		Onboard.inject(nil)
	end)
	test("Studio check R10: the empty landmark keeps its idle life: a Sleepy Nest sign, the quilt, sway, the moon at dusk",function()
		local model=sharedModel()
		local daylight=.1
		local idle=Client.idleMount({world=Instance.new("Folder"),landmarkModel=function()return model end,daylight=function()return daylight end,
			reduced=function()return false end})
		assert(idle:idleStep(.1,true))
		local sign=idle.folder:FindFirstChild("NestSign")
		assert(sign and idle.signWords[1].Text=="","the sign board stays, blank but for its painted moon (Fable R10 4)")
		local rest=model.Moon:GetAttribute("WorldRestCFrame")
		for _=1,40 do idle:idleStep(.1,true)end
		local L=idle.landmarkState
		assert(model.Moon.CFrame~=rest,"the moon sways")
		assert(L.light.Enabled and math.abs(L.light.Brightness-.6)<1e-6,"lit at dusk")
		assert(model.BlanketFolded.Transparency==0 and model.BlanketDraped.Transparency==1,"the folded quilt")
		assert(idle:idleStep(.1,false)==false and idle.folder==nil and model.Moon.CFrame==rest,"steps aside, restored")
		assert(idle:idleStep(.1,true)and idle.folder~=nil,"and back")
		idle:idleClose()
	end)
	test("Studio check R10: the idle steps aside while this player's nest animates the landmark",function()
		local r=landRig()
		assert(not r.client:animatesLandmark(),"no egg yet: the idle has it")
		r.fire(state(60));r.step(.1)
		assert(r.client:animatesLandmark())
		r.client:close()
		assert(not r.client:animatesLandmark())
		Onboard.inject(nil)
	end)
	test("code review of de31e8a: this nest stands on the server's root (NestRoot) and follows a re-seat; the moon's rest colour is the server's",function()
		local r=landRig()
		local seated=CFrame.new(0,.06,0)*r.model:GetAttribute("NestRoot")
		r.model:SetAttribute("NestRoot",seated)
		r.model.Moon:SetAttribute("RestColor",Color3.new(1,0,0))
		r.fire(state(60));r.step(.1)
		assert(math.abs(r.client.root.Y-seated.Y)<1e-6,"drawn on the server's root, not this client's ground ray")
		assert(r.client.landmarkState.rest.Moon.color==r.model.Moon:GetAttribute("RestColor"))
		local reseat=CFrame.new(0,.01,0)*seated
		r.model:SetAttribute("NestRoot",reseat);r.step(.1)
		assert(math.abs(r.client.root.Y-reseat.Y)<1e-6 and r.client.egg~=nil and r.client.view~=nil,"re-seated, the egg still there")
		Onboard.inject(nil)
	end)
	return{passed=#cases,cases=cases}
end
