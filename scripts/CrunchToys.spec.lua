-- Crunchy toys (GARDEN-PLAY-BRIEF 2026-11-26 section 2; GARDEN-PLAY-BRIEF-2 sections 2 and 3): every piece's spot
-- against the garden's keep-outs (GardenClearance: ground under it, off the paths, water, blocked ground, the parks and
-- the Dash), the part budget, the switch, the pure timings (the bigger moves: gather, overshoot, two wobbles), the
-- crackle slab's rules and sound layers, and CrunchToysClient mounted on fakes (built only with the switch on; a walk
-- through a heap, a pet on a pod, slab steps, a jump landing and healing, a gourd bump, with sound, buzz and pets).
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

	test("the budget: every part counted, under 175; the switch is AliveCrunch, beta and Studio only",function()
		assert(Toys.partCount()<=Toys.Budget and Toys.Budget==175,"parts "..Toys.partCount())
		-- Fable B35: pods 2 -> 5 parts each, gourds 12 -> 16. Brief 2: the burst pool 14 -> 24, the slab's 63 (4 boards,
		-- the bed, 10 tiles of 3 shards and 2 lines, 8 chips) for the tray's 11: 156 in all.
		assert(Toys.partCount()==156,"parts "..Toys.partCount())
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

	test("brief 2 heap: a .05 s gather, flat 12% in .08 s, springs to 45% and sags; 12 s back with a 10% puff; shudders 8 degrees twice",function()
		local H=Toys.Heap
		local s={}
		assert(Toys.heapLevel(s,0)==1)
		local burst,gain=Toys.heapHit(s,10)
		assert(burst==24 and H.burst==24 and near(gain,1),"a full heap: all 24 cards")
		assert(Toys.heapLevel(s,10+.05)>1.03,"it gathers first (lifts 4%)")
		assert(near(Toys.heapLevel(s,10+.05+.08),.12),"flat after .13 s: "..Toys.heapLevel(s,10.13))
		assert(near(Toys.heapLevel(s,10+Toys.heapRebound()+H.springTime),.45),"springs back to 45%")
		-- The sag: past 34% and back up (two wobbles), resting at 34% when the climb starts.
		local lo,hi=math.huge,-math.huge
		local sagAt=10+Toys.heapRebound()+H.springTime
		for t=0,H.sagTime,.01 do local v=Toys.heapLevel(s,sagAt+t);lo=math.min(lo,v);hi=math.max(hi,v)end
		assert(lo<.34 and lo>.3 and hi<=.45+1e-9,"sags with an overshoot: "..lo)
		assert(near(Toys.heapLevel(s,sagAt+H.sagTime),.34,1e-6))
		local top=0
		for t=H.reheap-H.puffTime,H.reheap,.01 do top=math.max(top,Toys.heapLevel(s,sagAt+H.sagTime+t))end
		assert(top>1.08 and top<=1.1+1e-9,"ends in a 10% puff past full: "..top)
		assert(near(Toys.heapTime(),.05+.08+.16+.6+12)and Toys.heapLevel(s,10+Toys.heapTime())==1,"full again")
		local again=Toys.heapHit(s,10+Toys.heapRebound()+.4)
		assert(again<=8,"a flattened heap bursts a few cards only: "..again)
		-- The shudder: 8 degrees, twice (two swings each way), done in .5 s.
		local sh={hitAt=0,before=1}
		local peak,flips,last=0,0,0
		for t=0,.6,.002 do
			local a=Toys.heapShudder(sh,t)
			peak=math.max(peak,math.abs(a))
			if a~=0 and last~=0 and(a>0)~=(last>0)then flips+=1 end
			if a~=0 then last=a end
		end
		assert(peak>math.rad(7)and peak<=math.rad(8),"8 degrees: "..math.deg(peak))
		assert(flips==3,"twice there and back: "..flips)
		assert(Toys.heapShudder(sh,.05+.5)==0)
		-- Burst cards: deterministic, 2.6 to 3.5 up and 2.8 to 4 out, two turns, on the ground by 2.2 s, gone by the end.
		local a=Toys.card(3,4,.5);local b=Toys.card(3,4,.5)
		assert(a==b,"the same card flies the same way")
		for _,seed in ipairs({3,9,101,202})do
			for i=1,H.burst do
				local start=Toys.card(seed,i,0)
				local up,far=0,0
				for t=0,H.burstTime,.02 do
					local at=Toys.card(seed,i,t)
					up=math.max(up,at.Y-start.Y)
					far=math.max(far,Vector2.new(at.X,at.Z).Magnitude-Vector2.new(start.X,start.Z).Magnitude)
				end
				assert(up>=2.6-.05 and up<=3.5+.05,"card "..i.." rises "..up)
				assert(far>=2.7 and far<=4.05,"card "..i.." flies out "..far)
				assert(Toys.cardLand(seed,i)<=H.burstTime,"card "..i.." down by 2.2 s: "..Toys.cardLand(seed,i))
				assert(near((Toys.card(seed,i,H.burstTime+.01)).Y,.04,1e-6))
				local _,_,ry0=Toys.card(seed,i,0)
				local _,_,ry1=Toys.card(seed,i,H.burstTime)
				assert(near(math.abs(ry1-ry0),math.pi*4,1e-6),"two turns")
				assert(select(5,Toys.card(seed,i,Toys.cardLife()+1e-3))==0)
			end
		end
	end)

	test("brief 2 pods and gourds: gather, flat .12 x 1.45, a 25% re-inflate overshoot in two wobbles, the nub's flight, the lean; the gourds' 55 swing, twist and bar",function()
		local P,G=Toys.Pod,Toys.Gourd
		assert(select(3,Toys.podScale(nil,0))=="ready")
		local y,w=Toys.podScale(0,.05)
		assert(near(y,1.06)and w<1,"gathers: "..y)
		local phase
		y,w,phase=Toys.podScale(0,.5)
		assert(near(y,.12)and near(w,1.45)and phase=="flat")
		assert(select(3,Toys.podScale(0,P.reinflate+.1))=="inflating")
		assert(select(3,Toys.podScale(0,P.reinflate+P.inflate+1e-3))=="ready")
		local peak,highs,prev,rising=0,0,0,true
		for t=P.reinflate,P.reinflate+P.inflate,.005 do
			local sy=Toys.podScale(0,t)
			peak=math.max(peak,sy)
			if sy<prev and rising and prev>1 then highs+=1 end
			rising=sy>=prev;prev=sy
		end
		assert(near(peak,1.25,.01),"25% past full: "..peak)
		assert(highs>=2,"and wobbles back: "..highs)
		-- The nub: 2.5 up, two turns, lands on the flat pod (well before it re-inflates), one small hop.
		local apex,landedAt=0,nil
		for t=0,2,.005 do
			local up,_,_,landed=Toys.podNub(0,t)
			apex=math.max(apex,up)
			if landed and not landedAt then landedAt=t end
		end
		assert(near(apex,2.5,.02)and landedAt and landedAt<1.2 and landedAt<P.reinflate,"pings up and lands: "..apex)
		local up,turn,drift,landed=Toys.podNub(0,3)
		assert(up==0 and turn==0 and drift==0 and landed,"sitting upright on the flat pod")
		local lean=0
		for t=0,1,.005 do lean=math.max(lean,Toys.podLean(0,t))end
		assert(near(lean,math.rad(12),1e-3)and Toys.podLean(0,P.leanTime)==0,"leans away 12 degrees")
		-- Gourds: pulls back first, swings toward its push, 55 degrees, settled by 3.5 s; it twists up to 20.
		assert(Toys.gourdAngle(0,1,.04)<0,"a pull back first")
		local most,sign=0,0
		for t=0,1,.005 do local a=Toys.gourdAngle(0,1,t);if math.abs(a)>math.abs(most)then most=a end end
		assert(most>math.rad(40)and most<=math.rad(55),"a big swing toward its push: "..math.deg(most))
		assert(Toys.gourdAngle(0,1,G.settle)==0 and math.abs(Toys.gourdAngle(0,1,G.settle-.1))<math.rad(1.2),"settled by 3.5 s")
		local twist=0
		for t=0,2,.005 do twist=math.max(twist,math.abs(Toys.gourdTwist(0,1,t)))end
		assert(twist>math.rad(10)and twist<=math.rad(20),"twists: "..math.deg(twist))
		local dip,flex=0,0
		for t=0,1.2,.005 do local d,f=Toys.barBend(0,1,t);dip=math.max(dip,d);flex=math.max(flex,math.abs(f))end
		assert(dip>.13 and dip<=.15+1e-9 and flex>math.rad(5)and flex<=math.rad(6)+1e-9,"the bar dips .15 and flexes 6")
		local _,middle=Toys.barBend(0,0,.2)
		assert(middle==0,"a middle bump only dips")
		assert(sign==0)
		-- The helpers: spring overshoots then lands on 1; wobble comes back to 0.
		assert(Toys.spring(0,.25)==0 and Toys.spring(1,.25)==1 and near(Toys.spring(.3,.25),1.25))
		assert(Toys.wobble(0)==0 and Toys.wobble(1)==0 and near(Toys.wobble(.3),1))
	end)

	test("brief 2 crackle slab: ten skewed tiles that fit their cells; a step cracks, lines run on, a landing shatters; the poses",function()
		local S=Toys.Slab
		local tiles=Toys.slabTiles()
		assert(#tiles==10 and S.cols*S.rows==10)
		local inner=Vector2.new(S.size.X-S.board.X*2,S.size.Y-S.board.X*2)
		local cell=Vector2.new(inner.X/S.cols,inner.Y/S.rows)
		for _,t in ipairs(tiles)do
			local deg=math.deg(math.abs(t.yaw))
			assert(deg>=3 and deg<=8,"tile "..t.i.." turned "..deg)
			local c,sn=math.abs(math.cos(t.yaw)),math.abs(math.sin(t.yaw))
			assert(t.size.X*c+t.size.Z*sn<=cell.X+1e-9 and t.size.X*sn+t.size.Z*c<=cell.Y+1e-9,"tile "..t.i.." inside its cell")
			assert(t.size.X>.8 and t.size.Z>1.3,"not shrunk to nothing")
			local total=0
			for _,shard in ipairs(t.shards)do total+=shard.length;local tilt=math.deg(math.abs(shard.tilt));assert(tilt>=8 and tilt<=15)end
			assert(#t.shards==3 and #t.lines==2 and near(total,t.size.Z,1e-9))
			for _,j in ipairs(Toys.slabNeighbours(t.i,false))do
				assert((tiles[j].yaw>0)~=(t.yaw>0),"side neighbours turn opposite ways (skew joints, not a grid)")
			end
			assert(Toys.slabTileAt(t.x,t.z)==t.i)
		end
		assert(Toys.slabTileAt(inner.X/2+.01,0)==nil,"off the tiles")
		assert(#Toys.slabNeighbours(1,false)==2 and #Toys.slabNeighbours(1,true)==3 and #Toys.slabNeighbours(3,true)==5)
		-- A step: +1; the line runs into one or two whole side neighbours; on a shattered tile: chips only.
		local levels={}
		for i=1,10 do levels[i]=0 end
		local what,runs=Toys.slabStep(levels,3,function(lo)return lo end)
		assert(what=="crack"and levels[3]==1 and #runs==1)
		for _,j in ipairs(runs)do assert(Toys.slabRun(levels,j)and levels[j]==1)end
		assert(not Toys.slabRun(levels,3),"a cracked tile is not cracked again by a line")
		what=Toys.slabStep(levels,3,function(_,hi)return hi-.5 end)
		assert(what=="shatter"and levels[3]==2)
		what,runs=Toys.slabStep(levels,3,function(lo)return lo end)
		assert(what=="chips"and #runs==0 and levels[3]==2)
		-- A landing: its tile shattered, every neighbour (corners too) at least hairline.
		levels={}
		for i=1,10 do levels[i]=0 end
		levels[2]=2
		local changes=Toys.slabLand(levels,7)
		assert(levels[7]==2,"shattered")
		for _,j in ipairs(Toys.slabNeighbours(7,true))do assert(levels[j]>=1,"neighbour "..j)end
		assert(levels[2]==2,"a shattered neighbour stays shattered")
		assert(#changes==1+#Toys.slabNeighbours(7,true)-1,"only the ones that changed")
		-- Poses: whole flat; hairline dips .03; shattered tilts 8 to 15, drops .08, parts .06.
		local t=tiles[1]
		local pose,lines=Toys.slabPose(t,0)
		for n,f in ipairs(pose)do assert((f.Position-Vector3.new(0,0,t.shards[n].z)).Magnitude<1e-9 and lines==0)end
		pose,lines=Toys.slabPose(t,1)
		for _,f in ipairs(pose)do assert(near(f.Position.Y,-.03))end
		assert(lines==1)
		pose=Toys.slabPose(t,2)
		assert(pose[1].Position.Z<t.shards[1].z-.05 and pose[3].Position.Z>t.shards[3].z+.05,"the outer shards part")
		for n,f in ipairs(pose)do
			assert(f.Position.Y<=-.03-.08+1e-9,"dropped")
			local up=f.UpVector
			local tilt=math.deg(math.acos(math.clamp(up.Y,-1,1)))
			assert(tilt>=7.9 and tilt<=16.5,"shard "..n.." tilts "..tilt)
		end
		-- Chips: hop .7 at most, skitter out, gone by their life.
		local top=0
		for k=1,8 do for tt=0,S.chipTime,.01 do top=math.max(top,(Toys.chip(5,k,tt)).Y)end end
		assert(top>.45 and top<=S.chipHop+1e-9)
		assert(select(3,Toys.chip(5,1,Toys.chipLife()))==0)
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
		local high=Toys.layers("heap",function(_,hi)return hi end)
		assert(near(high[1].speed,1*1.06,1e-9),"pitch +6%")
		local crack=Toys.layers("crack",function(_,hi)return hi end)
		assert(near(crack[1].speed,1.08,1e-9)and string.match(crack[1].cue,"^asmr_crack1_[a-c]$"),"the slab: +8%")
		local shatter=Toys.layers("shatter",function(lo)return lo end)
		assert(#shatter==2 and string.match(shatter[1].cue,"^asmr_crack2_[a-c]$")and string.match(shatter[2].cue,"^asmr_flake_"))
		assert(string.match(Toys.layers("heal",function(lo)return lo end)[1].cue,"^asmr_creak_"))
		assert(string.match(Toys.layers("nub",function(lo)return lo end)[1].cue,"^asmr_pop_")and Toys.layers("nub",function(lo)return lo end)[1].volume==.4)
		-- Never the same take twice running (the same roll every time still alternates).
		local memory={}
		local same=function()return 1 end
		local first=Toys.layers("crack",same,nil,memory)[1].cue
		local second=Toys.layers("crack",same,nil,memory)[1].cue
		assert(first~=second,"no repeat: "..first)
		local slab=table.clone(Toys.NewTakes);slab.glass_crackle_a,slab.glass_crackle_b=1,2
		memory={}
		assert(Toys.layers("crack",same,slab,memory)[1].cue~=Toys.layers("crack",same,slab,memory)[1].cue,"new takes too")
		local takes=table.clone(Toys.NewTakes);takes.leaf_crunch_b=123
		local fresh=Toys.layers("heap",function(lo)return lo end,takes)
		assert(#fresh==1 and fresh[1].cue=="leaf_crunch_b","the new take alone")
		for cue,id in pairs(Toys.NewTakes)do assert(id==0 and string.match(cue,"^%a+_%a+_[a-d]$"),cue)end
		assert(#Toys.cues()>=15 and table.find(Toys.cues(),"snack_crunch_feast")and table.find(Toys.cues(),"asmr_crack2_c"))
		assert(Toys.Buzz.crack=="crack1"and Toys.Buzz.shatter=="crack2"and Toys.Buzz.gravel==nil)
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

	test("a walk through a heap: one crunch (flake over the feast crunch) and a rebound flake, a creak buzz, 24 cards fly, it flattens and heaps back",function()
		local r=rig()
		local ok,err=pcall(function()
			local me={key=1,kind="own",position=ground(-33,37,2.6)}
			r.agents={me}
			r.walk(me,ground(-33,37,2.6),ground(-19,37,2.6),28)
			assert(r.count("asmr_flake")==2 and r.count("snack_crunch_feast")==1,"one crunch and its rebound: "..#r.played)
			assert(r.buzzed[1]=="creak"and #r.buzzed==1)
			local heap=r.toys.heaps[1]
			assert(heap.level<.5,"flattened: "..heap.level)
			local flying=0
			for _,card in ipairs(r.toys.cards)do if card.heap==heap then flying+=1 end end
			assert(flying==Toys.Heap.burst,"cards "..flying)
			local mound=r.toys.heaps[1].moundParts[1].part
			assert(mound.CFrame.UpVector.Y<.9999 or r.toys.heaps[1].shake==0,"shuddered (or done)")
			r.tick(Toys.cardLife()+.1)
			for _,card in ipairs(r.toys.cards)do assert(card.heap==nil and card.part.Transparency==1)end
			r.tick(Toys.Heap.reheap)
			assert(mound.CFrame.UpVector.Y>.99999,"the mound stands straight again")
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

	test("the slab cracks per step and its lines run on; back over it shatters and throws chips; it heals; a gourd bump knocks in a chain; Reduced Motion stays still",function()
		local r=rig()
		local ok,err=pcall(function()
			local T=Toys.Places.tray
			local S=Toys.Slab
			r.camera=Vector3.new(T.x,20,T.z);r.listener=Vector3.new(T.x,5,T.z)
			local me={key=1,kind="own",position=ground(T.x-6,T.z,2.6)}
			r.agents={me}
			local frame=CFrame.new(T.x,0,T.z)*CFrame.Angles(0,T.yaw,0)
			local row=-(S.size.Y-S.board.X*2)/4 -- along the first row
			local from,to=frame*Vector3.new(-5,0,row),frame*Vector3.new(5,0,row)
			r.walk(me,ground(from.X,from.Z,2.6),ground(to.X,to.Z,2.6),40)
			local slab=r.toys.slab
			local steps=r.count("asmr_crack1")
			assert(steps>=4 and steps<=9,"a crack a step across 5.4 of tiles (and the lines running on): "..steps)
			-- A buzz a step (crack1, or crack2 where a line had run ahead of the foot), none for the lines themselves.
			local cracks=0;for _,b in ipairs(r.buzzed)do if b=="crack1"or b=="crack2"then cracks+=1 end end
			assert(cracks>=4 and cracks<=6 and #r.buzzed==cracks,"a buzz a step: "..cracks)
			assert(table.find(r.buzzed,"crack1"),"hairlines buzz crack1")
			local cracked=0
			for i=1,5 do if slab.levels[i]>=1 then cracked+=1 end end
			assert(cracked>=4,"the row is cracked: "..cracked)
			local tile=slab.tiles[3]
			assert(slab.levels[3]>=1 and tile.lines[1].part.Transparency==0,"its lines show")
			-- Back along it: the cracked tiles shatter (crack2 buzz, the shatter layers, chips).
			r.played={};r.buzzed={}
			r.walk(me,ground(to.X,to.Z,2.6),ground(from.X,from.Z,2.6),40)
			assert(r.count("asmr_crack2")>=2,"shatters: "..r.count("asmr_crack2"))
			local shatters=0;for _,b in ipairs(r.buzzed)do if b=="crack2"then shatters+=1 end end
			assert(shatters>=2 and shatters==r.count("asmr_crack2"))
			for i=1,5 do assert(slab.levels[i]==2,"the row shattered "..i)end
			local flying=0;for _,chip in ipairs(slab.chips)do if chip.at then flying+=1 end end
			assert(flying>=3,"chips fly")
			assert(slab.levels[3]==2)
			local shard=tile.shards[1]
			assert(shard.CFrame.UpVector.Y<math.cos(math.rad(7)),"a shard tips over")
			-- Healing: untouched 8 s, a state every 4 s; shards flat and lines gone.
			r.played={}
			me.position=ground(T.x+20,T.z+20,2.6);r.tick(.05)
			r.tick(S.idle+S.healEvery*2+S.healTime+.5)
			for i=1,10 do assert(slab.levels[i]==0,"healed "..i)end
			assert(tile.lines[1].part.Transparency==1,"lines gone: "..tile.lines[1].part.Transparency)
			assert(tile.anim==nil,"at rest")
			local amber=Color3.fromHex(S.glass)
			assert(math.abs(shard.Color.R-amber.R)+math.abs(shard.Color.G-amber.G)+math.abs(shard.Color.B-amber.B)<1e-6,"its own amber after the gloss")
			assert(shard.CFrame.UpVector.Y>.99999,"flat again")
			assert(r.count("asmr_creak")>=1,"a creak as it heals")
			-- A jump landing on the middle of row 2: shattered, every neighbour cracked.
			r.played={};r.buzzed={}
			local mid=Toys.slabTiles()[8]
			local over=frame*Vector3.new(mid.x,0,mid.z)
			me.position=ground(over.X,over.Z,9);r.tick(.05)
			me.position=ground(over.X,over.Z,2.6);r.tick(.05)
			assert(slab.levels[8]==0,"not while it falls")
			r.tick(.05)
			assert(slab.levels[8]==2,"the landing shatters it")
			for _,j in ipairs(Toys.slabNeighbours(8,true))do assert(slab.levels[j]>=1,"neighbour "..j)end
			assert(r.buzzed[1]=="crack2"and r.count("asmr_crack2")==1)
			-- My pet's first shatter startles it; its second does not.
			local visual={}
			local pet={key=visual,kind="ownPet",visual=visual,position=ground(T.x+20,T.z+20)}
			r.agents={pet};r.tick(.05)
			local mine=frame*Vector3.new(Toys.slabTiles()[1].x,0,Toys.slabTiles()[1].z)
			pet.position=ground(mine.X,mine.Z,9);r.tick(.05)
			pet.position=ground(mine.X,mine.Z,1);r.tick(.05);r.tick(.05)
			assert(#r.reacted==1 and r.reacted[1]==visual,"startled")
			r.tick(1)
			local other=frame*Vector3.new(Toys.slabTiles()[5].x,0,Toys.slabTiles()[5].z)
			pet.position=ground(other.X,other.Z,9);r.tick(.05)
			pet.position=ground(other.X,other.Z,1);r.tick(.05);r.tick(.05)
			assert(slab.levels[5]==2 and #r.reacted==1,"only the first")
			r.agents={me}
			me.position=ground(T.x+20,T.z+20,2.6);r.tick(S.idle+S.healEvery*2+S.healTime+.5)
			r.played={}
			local gourds=Toys.gourdSpots()
			-- The gourds.
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
			local barLow=0
			local rest=r.toys.arch.rest.Position.Y
			for i=0,24 do
				me.position=ground(a.X,a.Z,2.6):Lerp(ground(b.X,b.Z,2.6),i/24)
				r.tick(.05)
				barLow=math.max(barLow,rest-r.toys.arch.bar.CFrame.Position.Y)
				if mid.angle and math.abs(mid.angle)>most then
					most=math.abs(mid.angle)
					-- Walking toward +Z, its big swing goes toward +Z (away from the bump), after the pull back.
					first=arch:VectorToObjectSpace(mid.body.CFrame.Position-mid.pivot.Position).Z
				end
			end
			assert(r.count("asmr_flake")>=2,"a rattle")
			assert(most>math.rad(35),"it swings big: "..math.deg(most))
			assert(first and first>0,"swings away from the bump: "..tostring(first))
			assert(r.toys.gourds[1].at and r.toys.gourds[3].at,"the neighbours knock on")
			assert(r.toys.gourds[1].at>r.toys.gourds[2].at,"a chain: later than the one bumped")
			assert(barLow>.1,"the bar dips: "..barLow)
			r.tick(Toys.Gourd.settle+.5)
			assert(mid.at==nil and mid.angle==0 and r.toys.arch.bumpAt==nil,"settled")
			assert(math.abs(r.toys.arch.bar.CFrame.Position.Y-rest)<1e-9,"the bar back on its posts")
			assert(gourds[2])
			-- Reduced Motion: the heap crunches but stays put, and no card flies.
			r.reduced=true;r.played={}
			r.camera=Vector3.new(-26,20,37);r.listener=Vector3.new(-26,6,37)
			me.position=ground(-40,60,2.6);r.tick(.05)
			me.position=ground(-33,37,2.6);r.tick(.05)
			r.walk(me,ground(-33,37,2.6),ground(-19,37,2.6),28)
			assert(r.count("asmr_flake")==2,"still crunches (and its rebound)")
			assert(r.toys.heaps[1].level==1 and r.toys.heaps[1].shake==0,"still")
			-- The slab with Reduced Motion: it cracks and sounds, nothing tips and no chip flies.
			r.played={}
			local T=Toys.Places.tray
			r.camera=Vector3.new(T.x,20,T.z);r.listener=Vector3.new(T.x,5,T.z)
			local frame=CFrame.new(T.x,0,T.z)*CFrame.Angles(0,T.yaw,0)
			local spot=frame*Vector3.new(Toys.slabTiles()[3].x,0,Toys.slabTiles()[3].z)
			me.position=ground(spot.X,spot.Z,9);r.tick(.05)
			me.position=ground(spot.X,spot.Z,2.6);r.tick(.05);r.tick(.5)
			local slab=r.toys.slab
			assert(slab.levels[3]==2 and r.count("asmr_crack2")==1,"it still shatters and sounds")
			for _,shard in ipairs(slab.tiles[3].shards)do assert(shard.CFrame.UpVector.Y>.99999,"no tip")end
			for _,chip in ipairs(slab.chips)do assert(chip.at==nil)end
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
