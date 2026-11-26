-- Crunchy toys (GARDEN-PLAY-BRIEF 2026-11-26 section 2): every piece's spot against the garden's keep-outs
-- (GardenClearance: ground under it, off the paths, water, blocked ground, the parks and the Dash), the part budget,
-- the switch, the pure timings and sound layers, and CrunchToysClient mounted on fakes (built only with the switch on;
-- a walk through a heap, a pet on a pod, gravel steps and a gourd bump, with sound, buzz and pets).
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.CrunchToys)(PlayerScripts.Client)
-- Offline: python scripts/run_dash_server_specs.py
return function(client,offline)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Toys=require(Shared.CrunchToys)
	local Clear=require(Shared.GardenClearance)
	local World=require(Shared.HollowWorldLayout)
	local Alive=require(Shared.Alive)
	local Flags=require(Shared.FeatureFlags)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function near(a,b,eps)return math.abs(a-b)<=(eps or 1e-6)end
	local function signal()
		if type(offline)=="table"and offline.signal then return offline.signal()end
		local b=Instance.new("BindableEvent")
		return{Connect=function(_,fn)return b.Event:Connect(fn)end,Fire=function(_,...)b:Fire(...)end}
	end

	test("every toy and pod: island ground under it, off the paths, water, blocked ground, bridge, parks, Dash, lamps and stations",function()
		local bad={}
		for _,f in ipairs(Toys.footprints())do
			local ok,why=Clear.check(f.x,f.z,f.r,false)
			if not ok then table.insert(bad,string.format("%s (%.1f, %.1f): %s",f.id,f.x,f.z,why))end
			-- Fairly flat, so a seated piece does not float or sink on a slope.
			local lo,hi=math.huge,-math.huge
			for k=0,7 do
				local a=k*math.pi/4
				local y=World.groundY(f.x+math.cos(a)*f.r,f.z+math.sin(a)*f.r)
				lo,hi=math.min(lo,y),math.max(hi,y)
			end
			if hi-lo>.8 then table.insert(bad,string.format("%s: ground spread %.2f",f.id,hi-lo))end
		end
		assert(#bad==0,table.concat(bad,"; "))
		assert(#Toys.footprints()==2+6+1+1+1,"two heaps, six pods and the row, the tray, the gourds")
		-- The pods are 1.5 apart along the row; the gourds hang 1.05 apart along the bar.
		local pods=Toys.podSpots()
		for i=2,#pods do assert(near((pods[i]-pods[i-1]).Magnitude,Toys.Pod.spacing,1e-3),"pod spacing "..i)end
		local gourds=Toys.gourdSpots()
		assert(#gourds==3 and near((gourds[3]-gourds[1]).Magnitude,Toys.Gourd.gap*2,1e-6))
	end)

	test("the keep-outs catch what they should: a path, the spring, the Dash, a park, the knoll, the bridge, off the island",function()
		local function why(x,z,r,air)local ok,reason=Clear.check(x,z,r or 1,air);assert(not ok,("(%g, %g) passed"):format(x,z));return reason end
		assert(string.find(why(60,50),"path"),"the arrival path")
		assert(string.find(why(52,3),"water"),"BubbleSpring")
		assert(string.find(why(-4.6,49),"water")or string.find(why(-4.6,49),"ground"),"the stream (no lawn under it)")
		assert(string.find(why(45.3,-1.2),"Dash"),"the Dash line")
		assert(string.find(why(36,66),"park")or string.find(why(36,66),"path"),"the arrival park")
		assert(string.find(why(-63,45),"blocked"),"the knoll")
		assert(string.find(why(2.5,21),"path")or string.find(why(2.5,21),"Dash")or string.find(why(2.5,21),"span"),"the bridge")
		assert(string.find(why(400,0),"ground"),"off the island")
		assert(string.find(why(-12,-44,1),"lamp"),"lamp 4")
		assert(Clear.check(-12,-44,1,true)==true,"a lantern may float over a lamp")
	end)

	test("the budget: every part counted, under 120; the switch is AliveCrunch, beta and Studio only",function()
		assert(Toys.partCount()<=Toys.Budget and Toys.Budget==120,"parts "..Toys.partCount())
		-- Fable B35: pods 2 -> 5 parts each, gourds 12 -> 16; 94 in all. Each pod its own yaw and a .9 to 1.1 height.
		assert(Toys.partCount()==94,"parts "..Toys.partCount())
		local yaws={}
		for i=1,Toys.Pod.count do
			local yaw,high=Toys.podLook(i)
			assert(high>=.9 and high<=1.1 and not yaws[yaw],"pod "..i);yaws[yaw]=true
		end
		assert(table.find(Alive.Features,"crunch")and Flags.AliveCrunch==true)
		assert(Alive.attribute("crunch")=="Alive_crunch"and Alive.key("crunch")=="alive_crunch")
		assert(Alive.ceiling("crunch",{AliveCrunch=true},Alive.PlaceId,false)==true)
		assert(Alive.ceiling("crunch",{AliveCrunch=true},96451847774961,false)==false,"never on live")
		assert(Alive.ceiling("crunch",{AliveCrunch=false},Alive.PlaceId,true)==false,"the flag off")
		assert(Alive.resolve("crunch",nil,nil,true)==true and Alive.resolve("crunch",false,nil,true)==false,"missing = on")
	end)

	test("timings: the heap flattens and heaps back over 20 s; a pod pops, waits 6 s, creaks back; a gourd settles in 2 s",function()
		local H,P=Toys.Heap,Toys.Pod
		local s={}
		assert(Toys.heapLevel(s,0)==1)
		local burst,gain=Toys.heapHit(s,10)
		assert(burst==H.burst and near(gain,1),"a full heap: the full burst")
		assert(near(Toys.heapLevel(s,10+H.squash),H.flat),"flat after the squash")
		assert(near(Toys.heapLevel(s,10+H.squash+H.reheap/2),H.flat+(1-H.flat)/2,1e-6),"half back at 10 s")
		local again=Toys.heapHit(s,10+H.squash+1)
		assert(again<=3,"a flattened heap bursts a few cards only: "..again)
		assert(near(Toys.heapLevel(s,10+H.squash+1+H.squash+H.reheap),1),"back after 20 s")
		assert(select(3,Toys.podScale(nil,0))=="ready")
		local y,w,phase=Toys.podScale(0,.5)
		assert(near(y,P.flat)and near(w,P.spread)and phase=="flat")
		assert(select(3,Toys.podScale(0,P.reinflate+.1))=="inflating")
		assert(select(3,Toys.podScale(0,P.reinflate+P.inflate+1e-3))=="ready")
		assert(math.abs(Toys.gourdAngle(0,1,.25))>math.rad(10),"a real swing")
		assert(math.abs(Toys.gourdAngle(0,1,.25))<=math.rad(Toys.Gourd.swing))
		assert(Toys.gourdAngle(0,1,Toys.Gourd.settle)==0 and math.abs(Toys.gourdAngle(0,1,1.9))<math.rad(1),"settled in 2 s")
		assert(Toys.pebbleHop(Toys.Tray.hopTime/2)==Toys.Tray.hop and Toys.pebbleHop(Toys.Tray.hopTime)==0)
		-- Burst cards: deterministic, up then down, on the ground by 1.5 s, gone by the end of their life.
		local a=Toys.card(3,4,.5);local b=Toys.card(3,4,.5)
		assert(a==b,"the same card flies the same way")
		local top=0
		for i=1,H.burst do for t=0,1.2,.05 do top=math.max(top,(Toys.card(3,i,t)).Y)end end
		assert(top>H.height,"they fly up out of the heap")
		for i=1,H.burst do
			assert(near((Toys.card(9,i,H.burstTime+.05)).Y,.04,1e-6),"card "..i.." down by 1.5 s")
			assert(select(5,Toys.card(9,i,Toys.cardLife()+1e-3))==0)
		end
	end)

	test("sound: stand-in layers from existing ids (a transient over a body, pitch within 6%); a new take plays alone",function()
		local roll=function(lo,hi)return(lo+hi)/2 end
		local heap=Toys.layers("heap",roll)
		assert(#heap==2 and string.match(heap[1].cue,"^asmr_flake_[a-e]$")and heap[2].cue=="snack_crunch_feast")
		for _,name in ipairs({"heap","pop","creak","gravel","rattle"})do
			for _,layer in ipairs(Toys.layers(name,function(lo,hi)return hi end))do
				assert(string.match(layer.cue,"^asmr_")or layer.cue=="snack_crunch_feast",layer.cue)
				assert(layer.volume>0 and layer.volume<=1 and layer.delay>=0)
			end
		end
		local high=Toys.layers("gravel",function(_,hi)return hi end)
		assert(near(high[1].speed,1.35*1.06,1e-9),"pitch +6%")
		local takes=table.clone(Toys.NewTakes);takes.leaf_crunch_b=123
		local fresh=Toys.layers("heap",function(lo)return lo end,takes)
		assert(#fresh==1 and fresh[1].cue=="leaf_crunch_b","the new take alone")
		for cue,id in pairs(Toys.NewTakes)do assert(id==0 and string.match(cue,"^%a+_%a+_[a-d]$"),cue)end
		assert(#Toys.cues()>=15 and table.find(Toys.cues(),"snack_crunch_feast"))
		assert(Toys.gain("own",100)==1 and Toys.gain("ownPet",100)==.5)
		assert(Toys.gain("other",30)==.4 and Toys.gain("other",31)==0 and Toys.gain("otherPet",10)==.2 and Toys.gain("other",nil)==0)
	end)

	-- The client on fakes ---------------------------------------------------------------------------------------------
	local function rig(opts)
		opts=opts or {}
		local changed=signal()
		local on=opts.on~=false
		local now=100
		local r={played={},buzzed={},reacted={},moved=0,agents={},reduced=opts.reduced==true}
		r.camera=Vector3.new(-26,20,37)
		r.listener=Vector3.new(-26,6,37)
		local parent=Instance.new("Folder");parent.Name="CrunchSpec";parent.Parent=workspace
		r.parent=parent
		r.toys=require(client.CrunchToysClient).mount({
			alive={ceiling=function()return true end,on=function(name)return name=="crunch"and on end,changed=function()return changed end},
			parent=parent,heartbeat=false,now=function()return now end,
			ground=function(x,z)return World.groundY(x,z)end,
			agents=function()return r.agents end,listener=function()return r.listener end,camera=function()return r.camera end,
			mode=function()return opts.mode or "Room"end,reduced=function()return r.reduced end,phone=function()return false end,
			level=function()return 0 end,
			play=function(layer,position,gain)table.insert(r.played,{cue=layer.cue,gain=gain,volume=layer.volume,position=position});return true end,
			buzz=function(name)table.insert(r.buzzed,name)end,
			react=function(visual)table.insert(r.reacted,visual)end,
			delay=function(_,fn)fn()end,
			move=function(parts,frames)r.moved+=#parts;for i,p in ipairs(parts)do p.CFrame=frames[i]end end,
			worldVersion="v7"})
		function r.set(value)on=value;changed:Fire()end
		function r.tick(seconds)
			local steps=math.max(1,math.floor((seconds or .05)/.05+.5))
			for _=1,steps do now+=.05;r.toys:step(.05)end
		end
		function r.now()return now end
		-- Walk an agent along a line in `n` steps (one tick each).
		function r.walk(agent,from,to,n)
			for i=0,n do
				agent.position=from:Lerp(to,i/n)
				r.tick(.05)
			end
		end
		function r.count(prefix)
			local n=0
			for _,p in ipairs(r.played)do if string.sub(p.cue,1,#prefix)==prefix then n+=1 end end
			return n
		end
		function r.done()r.toys:destroy();parent:Destroy()end
		return r
	end
	local function ground(x,z,up)return Vector3.new(x,World.groundY(x,z)+(up or 0),z)end

	test("the client: nothing built with the switch off; built on the switch (every part counted); taken down off",function()
		local r=rig({on=false})
		local ok,err=pcall(function()
			assert(r.toys and r.toys.built==false and r.parent:FindFirstChild("CrunchToysLocal")==nil,"off: nothing built")
			r.set(true)
			local folder=r.parent:FindFirstChild("CrunchToysLocal")
			assert(folder and r.toys.built,"built on the switch")
			local parts=0
			for _,item in ipairs(folder:GetDescendants())do
				if item.ClassName=="Part"then
					parts+=1
					assert(item.Anchored==true and item.CanCollide==false and item.CanQuery==false and item.CanTouch==false,item.Name)
				end
			end
			assert(parts==Toys.partCount()and folder:GetAttribute("CrunchParts")==parts,"parts "..parts)
			assert(r.toys.awake==true,"awake beside a heap")
			r.camera=Vector3.new(300,40,300);r.tick(.05)
			assert(r.toys.awake==false and folder:GetAttribute("CrunchAwake")==false,"asleep with nothing near")
			r.camera=Vector3.new(-26,20,37);r.toys:wake()
			assert(r.toys.awake==true)
			r.set(false)
			assert(r.parent:FindFirstChild("CrunchToysLocal")==nil and r.toys.built==false,"taken down")
		end)
		r.done();assert(ok,err)
	end)

	test("a walk through a heap: one crunch (flake over the feast crunch), a creak buzz, 14 cards fly, it flattens and heaps back",function()
		local r=rig()
		local ok,err=pcall(function()
			local me={key=1,kind="own",position=ground(-33,37,2.6)}
			r.agents={me}
			r.walk(me,ground(-33,37,2.6),ground(-19,37,2.6),28)
			assert(r.count("asmr_flake")==1 and r.count("snack_crunch_feast")==1,"one crunch: "..#r.played)
			assert(r.buzzed[1]=="creak"and #r.buzzed==1)
			local heap=r.toys.heaps[1]
			assert(heap.level<.5,"flattened: "..heap.level)
			local flying=0
			for _,card in ipairs(r.toys.cards)do if card.heap==heap then flying+=1 end end
			assert(flying==Toys.Heap.burst,"cards "..flying)
			r.tick(Toys.cardLife()+.1)
			for _,card in ipairs(r.toys.cards)do assert(card.heap==nil and card.part.Transparency==1)end
			r.tick(Toys.Heap.reheap)
			assert(heap.level==1,"heaped back: "..tostring(heap.level).." "..tostring(heap.state.hitAt).." "..tostring(r.now()))
			-- A jump over it (8 studs up) is no crunch.
			r.played={}
			r.walk(me,ground(-33,37,8),ground(-19,37,8),28)
			assert(#r.played==0,"over it, not through")
		end)
		r.done();assert(ok,err)
	end)

	test("others: a player 40 studs off is not heard, one 20 off at 40% with no buzz; my pet pops a pod at half and startles",function()
		local r=rig()
		local ok,err=pcall(function()
			local other={key=2,kind="other",position=ground(-33,37,2.6)}
			r.agents={other}
			r.listener=Vector3.new(-26,6,77)
			r.walk(other,ground(-33,37,2.6),ground(-19,37,2.6),28)
			assert(#r.played==0 and #r.buzzed==0,"too far to hear")
			r.tick(Toys.Heap.reheap+1)
			r.listener=Vector3.new(-26,6,55)
			r.walk(other,ground(-19,37,2.6),ground(-33,37,2.6),28)
			assert(#r.played>0 and #r.buzzed==0,"heard, never buzzed")
			for _,p in ipairs(r.played)do assert(p.gain==.4)end
			-- My pet across the pods.
			r.played={};r.camera=Vector3.new(15,20,38.5);r.listener=Vector3.new(15,5,38.5)
			local pods=Toys.podSpots()
			local visual={}
			local pet={key=visual,kind="ownPet",visual=visual,position=ground(pods[1].X-3,pods[1].Y)}
			r.agents={pet}
			local a,b=pods[2],pods[3]
			local dir=(b-a).Unit
			r.walk(pet,ground(a.X-dir.Y*3,a.Y+dir.X*3),ground(a.X+dir.Y*3,a.Y-dir.X*3),12)
			assert(r.count("asmr_pop")>=1,"popped")
			for _,p in ipairs(r.played)do assert(p.gain==.5)end
			assert(#r.reacted==1 and r.reacted[1]==visual,"startled once")
			r.walk(pet,ground(b.X-dir.Y*3,b.Y+dir.X*3),ground(b.X+dir.Y*3,b.Y-dir.X*3),12)
			assert(#r.reacted==1,"not again within 3 s")
			assert(#r.buzzed==0,"a pet never buzzes")
			local popped=r.toys.pods[2]
			assert(popped.poppedAt and popped.scale<.5,"flat")
			-- The sepals stay put, so the squash reads against them.
			local folder=r.parent:FindFirstChild("CrunchToysLocal")
			local sepal=folder:FindFirstChild("pop_pod2_sepal1")
			assert(sepal and popped.body.CFrame.Position.Y<sepal.CFrame.Position.Y+popped.tall*.4,"the body sank, the sepal did not")
			assert(r.moved>0)
			r.played={}
			r.tick(Toys.Pod.reinflate)
			assert(r.count("asmr_creak")>=1,"creaks back")
			r.tick(Toys.Pod.inflate+.2)
			assert(popped.poppedAt==nil and popped.scale==1,"ready again")
		end)
		r.done();assert(ok,err)
	end)

	test("the tray crunches per step and a pebble hops; a gourd bump rattles and swings its neighbours; Reduced Motion stays still",function()
		local r=rig()
		local ok,err=pcall(function()
			local T=Toys.Places.tray
			r.camera=Vector3.new(T.x,20,T.z);r.listener=Vector3.new(T.x,5,T.z)
			local me={key=1,kind="own",position=ground(T.x-6,T.z,2.6)}
			r.agents={me}
			local frame=CFrame.new(T.x,0,T.z)*CFrame.Angles(0,T.yaw,0)
			local from,to=frame*Vector3.new(-5,0,0),frame*Vector3.new(5,0,0)
			r.walk(me,ground(from.X,from.Z,2.6),ground(to.X,to.Z,2.6),40)
			local steps=r.count("asmr_egg_set")
			assert(steps>=3 and steps<=5,"a crunch a step across 5.4 of gravel: "..steps)
			local settles=0;for _,b in ipairs(r.buzzed)do if b=="settle"then settles+=1 end end
			assert(settles>=1)
			-- The gourds.
			r.played={}
			local G=Toys.Places.gourds
			r.camera=Vector3.new(G.x,20,G.z);r.listener=Vector3.new(G.x,5,G.z)
			local gourds=Toys.gourdSpots()
			local arch=CFrame.new(G.x,0,G.z)*CFrame.Angles(0,G.yaw,0)
			local a,b=arch*Vector3.new(0,0,-3),arch*Vector3.new(0,0,3)
			me.position=ground(G.x+20,G.z-20,2.6);r.tick(.05)
			me.position=ground(a.X,a.Z,2.6);r.tick(Toys.Gourd.settle+.3)
			r.played={}
			local mid=r.toys.gourds[2]
			assert(mid.at==nil and mid.angle==0,"still before the bump")
			local first,most=nil,0
			for i=0,24 do
				me.position=ground(a.X,a.Z,2.6):Lerp(ground(b.X,b.Z,2.6),i/24)
				r.tick(.05)
				if mid.angle and math.abs(mid.angle)>.01 then
					most=math.max(most,math.abs(mid.angle))
					-- Walking toward +Z, it first swings toward +Z (away from the bump).
					first=first or arch:VectorToObjectSpace(mid.body.CFrame.Position-mid.pivot.Position).Z
				end
			end
			assert(r.count("asmr_flake")>=2,"a rattle")
			assert(most>math.rad(10),"it swings: "..math.deg(most))
			assert(first and first>0,"swings away from the bump: "..tostring(first))
			assert(r.toys.gourds[1].at and r.toys.gourds[3].at,"the neighbours sway")
			r.tick(Toys.Gourd.settle+.2)
			assert(mid.at==nil and mid.angle==0,"settled")
			assert(gourds[2])
			-- Reduced Motion: the heap crunches but stays put, and no card flies.
			r.reduced=true;r.played={}
			r.camera=Vector3.new(-26,20,37);r.listener=Vector3.new(-26,6,37)
			me.position=ground(-40,60,2.6);r.tick(.05)
			me.position=ground(-33,37,2.6);r.tick(.05)
			r.walk(me,ground(-33,37,2.6),ground(-19,37,2.6),28)
			assert(r.count("asmr_flake")==1,"still crunches")
			assert(r.toys.heaps[1].level==1,"still")
			for _,card in ipairs(r.toys.cards)do assert(card.heap==nil)end
		end)
		r.done();assert(ok,err)
	end)

	test("the deck up (Mode not Room): asleep and silent",function()
		local r=rig({mode="Deck"})
		local ok,err=pcall(function()
			assert(r.toys.built and r.toys.awake==false)
			local me={key=1,kind="own",position=ground(-33,37,2.6)}
			r.agents={me}
			r.walk(me,ground(-33,37,2.6),ground(-19,37,2.6),28)
			assert(#r.played==0)
		end)
		r.done();assert(ok,err)
	end)

	return{passed=#cases,cases=cases}
end
