-- The Garden Dash start balloon (GARDEN-PLAY-BRIEF-2 section 7): the countdown cues (a beat at GO - 3, - 2, - 1, GO and
-- the finish, each once a race, a late join skipping the old ones), the motion (an 8% puff, a 1.6x burn, the 1.5 GO
-- jump, two finish hops, the flag's swing, the cards), and DashBalloon built on fakes: its parts under its own budget,
-- none colliding, touching or answering a raycast, nothing under DashFete.Clear over the lanes; a race's cues with their
-- sounds, the cards and the mascot's hops; Reduced Motion still with the sounds; nothing drawn beyond the cull.
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.DashBalloon)(PlayerScripts.Client)
-- Offline: python scripts/run_dash_server_specs.py
return function(client)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Balloon=require(client.DashBalloon)
	local Course=require(Shared.DashCourse)
	local Fete=require(Shared.DashFete)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function near(a,b,eps)return math.abs(a-b)<=(eps or 1e-6)end
	local M=Balloon.Motion

	test("cues: three beats and GO once a race, the finish on the results; a late join skips what has passed",function()
		local state={}
		local cue={raceId="r1",goAt=100,phase="countdown"}
		assert(#Balloon.cues(state,96,cue)==0,"nothing before GO - 3")
		local kinds={}
		for t=96,101,.05 do for _,e in ipairs(Balloon.cues(state,t,cue))do table.insert(kinds,e.kind..":"..e.at)end end
		assert(table.concat(kinds," ")=="beat:97 beat:98 beat:99 go:100",table.concat(kinds," "))
		cue.phase="results"
		local done=Balloon.cues(state,120,cue)
		assert(#done==1 and done[1].kind=="finish")
		assert(#Balloon.cues(state,121,cue)==0,"once")
		-- Joining at GO - 1.2: the first two beats are skipped, the third and GO play.
		state={}
		local late={raceId="r2",goAt=200,phase="countdown"}
		local got={}
		for t=198.8,200.6,.05 do for _,e in ipairs(Balloon.cues(state,t,late))do table.insert(got,e.kind)end end
		assert(table.concat(got," ")=="beat go",table.concat(got," "))
		-- A new race starts over; no race, nothing.
		assert(#Balloon.cues(state,300,nil)==0 and #Balloon.cues(state,300,{raceId="r3"})==0)
		local again=Balloon.cues(state,297,{raceId="r3",goAt=300,phase="countdown"})
		assert(#again==1 and again[1].kind=="beat")
	end)

	test("motion: the puff is 8% and back, the burn 1.6x, the GO jump 1.5, two finish hops, the flag swings 40",function()
		local puff,burn,jump,swing=1,1,0,0
		for t=0,2,.005 do
			puff=math.max(puff,Balloon.puff(t));burn=math.max(burn,Balloon.burn(t))
			jump=math.max(jump,Balloon.jump(t));swing=math.max(swing,math.abs(Balloon.swing(t)))
		end
		assert(near(puff,1.08,1e-3)and Balloon.puff(M.puffTime)==1 and Balloon.puff(-.1)==1)
		assert(near(burn,1.6,1e-3)and Balloon.burn(M.burnTime)==1)
		assert(near(jump,1.5,1e-3)and Balloon.jump(M.jumpTime)==0)
		assert(swing>math.rad(30)and swing<=math.rad(40)and Balloon.swing(M.swingTime)==0)
		local hops,up,peak=0,false,0
		for t=0,1,.005 do
			local h=Balloon.hop(t);peak=math.max(peak,h)
			if h>.25 and not up then hops+=1 end
			up=h>.25
		end
		assert(hops==2 and near(peak,.5,.01)and Balloon.hop(M.hopTime*M.hops)==0,"two hops: "..hops)
		-- The cards: out to the sides, gone before they drop floorDrop and by their life.
		for i=1,20 do
			for t=0,M.cardLife,.02 do
				local at,_,_,seen=Balloon.card(3,i,t,2)
				assert(at.Y>=-2-1e-9,"never under the floor")
				if at.Y<=-2+1e-6 then assert(seen==0,"gone at the floor")end
			end
			assert(select(4,Balloon.card(3,i,M.cardLife,2))==0)
			assert(math.abs((Balloon.card(3,i,1,2)).X)>.5,"out to the side")
		end
	end)

	-- On fakes ---------------------------------------------------------------------------------------------------------
	local function rig(options)
		options=options or {}
		local r={sounds={},camera=options.camera}
		local parent=Instance.new("Folder");parent.Name="BalloonSpec";parent.Parent=workspace
		r.parent=parent
		r.mascot={origin=Vector3.zero,updates=0,update=function(self)self.updates+=1 end,destroy=function(self)self.destroyed=true end}
		r.balloon=Balloon.new(parent,{mascot=function(_,origin)r.mascot.origin=origin;return r.mascot end,
			sound=function(cue,_,volume)table.insert(r.sounds,{cue=cue,volume=volume})end,
			camera=function()return r.camera end,phone=function()return false end,terrain=parent})
		function r.done()r.balloon:destroy();parent:Destroy()end
		return r
	end
	local _,groundY=Course.at(0)

	test("built: its own budget and folder, nothing collides, touches or answers a raycast, nothing under the lanes' clear height",function()
		local r=rig()
		local ok,err=pcall(function()
			local folder=r.parent:FindFirstChild(Balloon.FolderName)
			assert(folder and folder:GetAttribute("BalloonParts")==r.balloon.count)
			local parts,wedges,beams=0,0,0
			for _,item in ipairs(folder:GetDescendants())do
				if item.ClassName=="Part"or item.ClassName=="WedgePart"then
					parts+=1
					if item.ClassName=="WedgePart"then wedges+=1 end
					assert(item.Anchored==true and item.CanCollide==false and item.CanQuery==false and item.CanTouch==false,item.Name)
					assert(item.Material~=Enum.Material.Fabric,item.Name.." is not Fabric")
					local bottom=item.CFrame.Position.Y-math.max(item.Size.X,item.Size.Y,item.Size.Z)/2
					if item.Name~="GoCard"then assert(bottom-groundY>=Fete.Clear,item.Name.." hangs to "..(bottom-groundY))end
				elseif item.ClassName=="Beam"then beams+=1 end
			end
			-- 13 for the balloon, 12 pennants, the flag and its pole, 20 cards.
			assert(parts==47 and r.balloon.count==47 and parts<=Balloon.MaxParts,"parts "..parts)
			assert(wedges==12 and beams==2,"six pennants a tether, both tethers kept")
			assert(r.mascot.origin.Y-groundY>Fete.Clear,"the mascot stands in the basket")
		end)
		r.done();assert(ok,err)
	end)

	test("a race: a pop each beat, a whoosh on GO with the cards and the jump, two hops at the results",function()
		local r=rig()
		local ok,err=pcall(function()
			local cue={raceId="r1",goAt=100,phase="countdown"}
			local envelope=r.balloon.envelope
			local biggest,highest,cards=0,-math.huge,0
			for t=96,103,1/30 do
				r.balloon:frame(t,false,cue,1/30)
				biggest=math.max(biggest,envelope.Size.X)
				highest=math.max(highest,envelope.CFrame.Position.Y)
				local shown=0
				for _,card in ipairs(r.balloon.cards)do if card.at and card.part.Transparency<1 then shown+=1 end end
				cards=math.max(cards,shown)
			end
			local pops,go=0,0
			for _,s in ipairs(r.sounds)do if string.match(s.cue,"^asmr_pop_")then pops+=1 elseif s.cue=="spin_whoosh"then go+=1 end end
			assert(pops==3 and go==1,"pops "..pops.." go "..go)
			assert(biggest>Balloon.Look.envelope*1.06 and biggest<=Balloon.Look.envelope*1.08+1e-6,"it puffs: "..biggest)
			assert(highest-(groundY+Balloon.Height)>1.5,"it jumps on GO: "..(highest-groundY))
			assert(cards>=15,"the GO cards: "..cards)
			local before=r.mascot.origin.Y
			cue.phase="results"
			local top=before
			for t=110,111,1/30 do r.balloon:frame(t,false,cue,1/30);top=math.max(top,r.mascot.origin.Y)end
			assert(top-before>.3,"the mascot hops")
			assert(r.mascot.updates>0,"posed")
		end)
		r.done();assert(ok,err)
	end)

	test("Reduced Motion: it hangs still, the sounds stay; beyond the cull nothing is drawn",function()
		local r=rig()
		local ok,err=pcall(function()
			local cue={raceId="r1",goAt=100,phase="countdown"}
			local envelope=r.balloon.envelope
			r.balloon:frame(95,true,cue,1/30)
			local rest=envelope.CFrame
			for t=95,102,1/30 do
				r.balloon:frame(t,true,cue,1/30)
				assert((envelope.CFrame.Position-rest.Position).Magnitude<1e-9 and envelope.Size.X==Balloon.Look.envelope,"still")
			end
			assert(#r.sounds==4,"the beats and GO still sound: "..#r.sounds)
			for _,card in ipairs(r.balloon.cards)do assert(card.part.Transparency==1)end
			-- Far off: no frame written.
			r.camera=r.balloon.at.Position+Vector3.new(400,0,0)
			local far=envelope.CFrame
			r.balloon:frame(130.7,false,nil,1/30)
			assert(envelope.CFrame==far,"culled: the same frame, never rewritten")
		end)
		r.done();assert(ok,err)
	end)

	test("DashProps: the fete gate gets the balloon (apart from the race props' budget); without it, the old ball and flag",function()
		local Props=require(client.DashProps)
		local world=Instance.new("Folder");world.Name="PropsSpec";world.Parent=workspace
		local ok,err=pcall(function()
			local gate=Instance.new("Model");gate.Name="GardenDash";gate.Parent=world
			gate:SetAttribute("Fete",true)
			local props=Props.new(world)
			props:balloon(10,false,{raceId="a",goAt=12,phase="countdown"},1/30)
			assert(props.fair and world:FindFirstChild(Balloon.FolderName),"the balloon")
			assert(props.count==0 and props.sky==nil,"none of the race props' 60")
			gate:SetAttribute("Fete",false)
			props:balloon(11,false,nil,1/30)
			assert(props.fair==nil and world:FindFirstChild(Balloon.FolderName)==nil and props.sky and props.count==2,"the ball and flag")
			gate:SetAttribute("Fete",true)
			props:balloon(12,false,nil,1/30)
			assert(props.fair and props.sky==nil and props.count==0)
			props:destroy()
			assert(world:FindFirstChild(Balloon.FolderName)==nil,"gone with the props")
		end)
		world:Destroy();assert(ok,err)
	end)

	return{passed=#cases,cases=cases}
end
