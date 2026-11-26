-- Bumble balls (GARDEN-PLAY-BRIEF section 1), pure: the sim (it lands, the bounces decay, it rests within ~3 s, it never
-- leaves its leash or the island's safe ground, never ends in water or a blocked box, and every observer gets the same
-- arc whenever it samples), the server's checks (reach, rate, clamp, origin) and the client's blend maths.
-- Offline: python scripts/run_dash_server_specs.py; Studio: require(ServerScriptService.Server.ZZSpecs.BumbleBalls)()
return function()
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Balls=require(Shared.BumbleBalls)
	local Motion=require(Shared.BallMotion)
	local Bounds=require(Shared.IslandBounds)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function near(a,b,e)return math.abs(a-b)<=(e or 1e-9)end
	local function kick(id,origin,velocity,start)return{id=id,n=1,origin=origin,velocity=velocity,startTime=start or 0}end
	local function dir(deg)return Vector3.new(math.cos(math.rad(deg)),0,math.sin(math.rad(deg)))end
	-- A flat test world (ground 0) around Felt's home.
	local fh=Balls.ById.felt.home
	local function flat(boxes)return Motion.world({groundY=function()return 0 end,boxes=boxes or {}})end
	local R=Balls.Radius

	test("homes: every ball rests clear of the leash, boxes, water and the island's edge, on safe ground",function()
		for _,entry in ipairs(Balls.List)do
			local home=Motion.home(entry.id)
			assert(Motion.blocked(entry.id,home)==nil,entry.id)
			assert(Bounds.safeCell(home.X,home.Z),entry.id.." on safe ground")
			local plan=Motion.plan(Motion.rest(entry.id,home,0))
			assert((plan.rest-home).Magnitude<1e-6 and plan.duration<=Motion.Step+1e-9,entry.id.." a still record stays put")
		end
	end)

	test("a kick lands: up, down, a bounce at the ground, then a roll to rest on the ground",function()
		local world=flat()
		local plan=Motion.plan(kick("felt",Vector3.new(fh.X,R,fh.Y),Balls.launch(dir(0),false)),world)
		local peak=0
		for i=1,#plan.ys do peak=math.max(peak,plan.ys[i])end
		assert(near(peak,R+Balls.KickUp^2/(2*Motion.Gravity),.1),"apex about v^2/2g over the ground: "..peak)
		assert(plan.events[1].kind=="bounce","the first event is the landing")
		local first=plan.events[1].t
		assert(near(first,2*Balls.KickUp/Motion.Gravity,2*Motion.Step),"lands after 2 v/g: "..first)
		assert(near(plan.rest.Y,R,1e-9),"rests on the ground")
		for i=1,#plan.ys do assert(plan.ys[i]>=R-1e-9,"never under the ground")end
	end)

	test("bounces decay: each bounce lower than the last, no more than the restitution list, then a roll",function()
		local world=flat()
		for _,jump in ipairs({false,true})do
			local plan=Motion.plan(kick("felt",Vector3.new(fh.X,R,fh.Y),Balls.launch(dir(45),jump)),world)
			local bounces={}
			for _,e in ipairs(plan.events)do if e.kind=="bounce"then table.insert(bounces,e)end end
			assert(#bounces>=2 and #bounces<=#Motion.Restitution,"bounces: "..#bounces)
			for i=2,#bounces do assert(bounces[i].strength<bounces[i-1].strength,"decays")end
			-- Apex between bounce k and k+1 shrinks too.
			local apexes={}
			for k=1,#bounces-1 do
				local hi=0
				for i=1,#plan.ys do local t=(i-1)*Motion.Step;if t>bounces[k].t and t<bounces[k+1].t then hi=math.max(hi,plan.ys[i])end end
				table.insert(apexes,hi)
			end
			for i=2,#apexes do assert(apexes[i]<apexes[i-1],"apex decays")end
		end
	end)

	test("rest within ~3 s: every ball, 24 headings, a walk kick and a running jump (the island itself)",function()
		local worst=0
		for _,entry in ipairs(Balls.List)do
			local home=Motion.home(entry.id)
			for deg=0,345,15 do
				for _,jump in ipairs({false,true})do
					local plan=Motion.plan(kick(entry.id,home,Balls.launch(dir(deg),jump,entry.id)))
					worst=math.max(worst,plan.duration)
					assert(plan.duration<=3.2,entry.id.." "..deg.." "..tostring(jump)..": "..plan.duration)
					assert(plan.duration>=1,"it does travel")
				end
			end
		end
		assert(worst>1.8,"about 2.5 s, not instant: "..worst)
	end)

	test("never leaves its leash or the safe ground, never ends in water or a box: 200 seeded kicks a ball on the island",function()
		local rng=Random.new(20261126)
		local count=0
		for _,entry in ipairs(Balls.List)do
			local home=Balls.ById[entry.id].home
			while count<200*(table.find(Balls.List,entry)or 1)do
				local a,r=rng:NextNumber(0,math.pi*2),rng:NextNumber(0,Balls.Leash-1)
				local x,z=home.X+math.cos(a)*r,home.Y+math.sin(a)*r
				local origin=Vector3.new(x,0,z)
				if Motion.blocked(entry.id,origin)then continue end
				count+=1
				local feel=Balls.feel(entry.id)
				local speed=rng:NextNumber(4,feel.jumpFlat*Balls.SpeedSlack)
				local v=dir(rng:NextNumber(0,360))*speed+Vector3.new(0,rng:NextNumber(0,feel.jumpUp),0)
				local plan=Motion.plan(kick(entry.id,origin,v))
				for i=1,#plan.xs,3 do
					local p=Vector3.new(plan.xs[i],0,plan.zs[i])
					assert(Motion.blocked(entry.id,p)==nil,entry.id.." point "..i.." blocked: "..tostring(Motion.blocked(entry.id,p)))
				end
				assert(Motion.blocked(entry.id,plan.rest)==nil,"rest clear")
				assert(Bounds.safeCell(plan.rest.X,plan.rest.Z),"rest on safe ground")
				assert(Balls.planDistance(plan.rest,Vector3.new(home.X,0,home.Y))<=Balls.Leash,"inside the leash")
				assert(plan.duration<=Motion.MaxTime+1e-9)
			end
		end
		assert(count==200*#Balls.List)
	end)

	test("brief 2: Patch and Stripe, lively (30 + 11, jump 36 + 15, .70 / .55 / .40, squash 18%), homes clear of the garden",function()
		assert(#Balls.List==5 and Balls.ById.patch and Balls.ById.stripe)
		local Clear=require(Shared.GardenClearance)
		for _,id in ipairs({"patch","stripe"})do
			local feel=Balls.feel(id)
			assert(feel==Balls.Feels.lively,id)
			local walk,jump=Balls.launch(Vector3.new(3,0,4),false,id),Balls.launch(Vector3.new(3,0,4),true,id)
			assert(near(Balls.flat(walk).Magnitude,30,1e-6)and walk.Y==11 and near(Balls.flat(jump).Magnitude,36,1e-6)and jump.Y==15)
			local fast=Balls.clamp(Vector3.new(300,90,0),1,id)
			assert(near(Balls.flat(fast).Magnitude,36*Balls.SpeedSlack,1e-6)and near(fast.Y,15*Balls.SpeedSlack,1e-6),"its own envelope")
			assert(Balls.clamp(jump,1,id)==jump,"its jump kick is inside")
			assert(near(Balls.squash(1,0,id),.18)and near(Balls.squash(1,0,"felt"),.12))
			local h=Balls.ById[id].home
			local ok,why=Clear.check(h.X,h.Y,Balls.Radius+1,false)
			assert(ok,id.." home: "..tostring(why))
		end
		-- The steady three keep their numbers (and a steady ball's clamp is unchanged by the lively ones).
		for _,id in ipairs({"felt","wicker","cork"})do assert(Balls.feel(id)==Balls.Feels.steady)end
		assert(near(Balls.flat(Balls.clamp(Vector3.new(300,90,0),1,"cork")).Magnitude,32*Balls.SpeedSlack,1e-6))
		assert(Balls.MaxJumpFlat>=Balls.Feels.lively.jumpFlat and Balls.MaxJumpUp>=Balls.Feels.lively.jumpUp)
		-- Livelier on flat ground: a higher first hop back, three bounces on the lively list, then a longer run.
		local world=flat()
		local function first(id)
			local plan=Motion.plan(kick(id,Vector3.new(fh.X,R,fh.Y),Balls.launch(dir(0),false,id)),world)
			local bounces,hi={},0
			for _,e in ipairs(plan.events)do if e.kind=="bounce"then table.insert(bounces,e)end end
			for i=1,#plan.ys do local t=(i-1)*Motion.Step;if t>bounces[1].t and t<bounces[2].t then hi=math.max(hi,plan.ys[i])end end
			return hi-R,#bounces,plan,bounces[1].strength*Balls.feel(id).jumpUp
		end
		local steadyHop=first("felt")
		local livelyHop,count,plan,impact=first("patch")
		assert(livelyHop>steadyHop*1.8,"its second hop is far higher: "..livelyHop.." vs "..steadyHop)
		assert(count==3,"three bounces on the lively list: "..count)
		-- The landing's speed times .70, less the fixed step's half-step loss.
		local e=.70
		assert(near(livelyHop,(impact*e)^2/(2*Motion.Gravity)-impact*e*Motion.Step/2,.03),"restitution .70: "..livelyHop)
		assert(plan.duration<=3.2,"rests in about 3.2 s on flat ground: "..plan.duration)
	end)

	test("reflections: a wall turns it back, the water's edge too (with its own event), the leash keeps it in",function()
		local wall=Motion.box(fh.X+6,fh.Y,1,20,0,"wall")
		local plan=Motion.plan(kick("felt",Vector3.new(fh.X,R,fh.Y),Balls.launch(dir(0),false)),flat({wall}))
		assert(plan.rest.X<fh.X+6-.5-Motion.Pad,"stays on the near side: "..plan.rest.X)
		local hits=0;for _,e in ipairs(plan.events)do if e.kind=="wall"then hits+=1 end end
		assert(hits>=1,"a wall event")
		local water=Motion.box(fh.X,fh.Y+6,20,1,0,"water")
		plan=Motion.plan(kick("felt",Vector3.new(fh.X,R,fh.Y),Balls.launch(dir(90),false)),flat({water}))
		assert(plan.rest.Z<fh.Y+6-.5-Motion.Pad,"stays dry: "..plan.rest.Z)
		local wet=false;for _,e in ipairs(plan.events)do wet=wet or e.kind=="water"end
		assert(wet,"a water event")
		-- A yawed box (the same CFrame.Angles(0, yaw, 0) the world uses) still blocks along its own axes.
		local yawed=Motion.box(fh.X+6,fh.Y,1,20,math.pi/4,"wall")
		local along=Vector3.new(fh.X+6,0,fh.Y)+Vector3.new(math.sin(math.pi/4),0,math.cos(math.pi/4))*9
		assert(flat({yawed}).hit(along.X,along.Z)=="wall","local Z axis is (sin, 0, cos)")
		-- The leash, on flat open ground: a full jump kick outward from near the edge.
		local edge=Vector3.new(fh.X+Balls.Leash-2,R,fh.Y)
		plan=Motion.plan(kick("felt",edge,Balls.launch(dir(10),true)),flat())
		for i=1,#plan.xs do
			assert(Vector2.new(plan.xs[i]-fh.X,plan.zs[i]-fh.Y).Magnitude<=Balls.Leash+1e-9,"inside the leash at "..i)
		end
	end)

	test("same arc everywhere: the server and a client (the record through the wire) agree at any time",function()
		local home=Motion.home("wicker")
		local server=kick("wicker",home,Balls.launch(dir(200),true),1000.25)
		local wire=Balls.unpack(Balls.pack(server,Motion.plan(server).rest))
		assert(wire~=server)
		local a,b=Motion.plan(server),Motion.plan(wire)
		assert(a~=b and #a.xs==#b.xs and a.rest==b.rest,"two plans, one path")
		for i=1,#a.xs do assert(a.xs[i]==b.xs[i]and a.ys[i]==b.ys[i]and a.zs[i]==b.zs[i])end
		-- The server samples at its times, the client at its own (later, jittery); where they overlap they are equal.
		for _,t in ipairs({0,.013,.25,.5001,1,1.7,2.2,3,10})do
			local s=Motion.sample(server,server.startTime+t)
			local c=Motion.sample(wire,wire.startTime+t)
			assert(s==c,"t "..t)
		end
		assert(Motion.sample(wire,wire.startTime+100)==a.rest,"after the plan: the rest spot")
		-- startTime only shifts the arc, never changes it (so the kicker's own clock gives the server's rest spot).
		local later=table.clone(server);later.startTime=2000
		assert(Motion.plan(later).rest==a.rest)
		assert(Motion.sample(later,2000.5)==Motion.sample(server,1000.75))
		assert(Motion.plan(server)==a,"planned once, cached")
	end)

	test("validation: the clamp (same value inside, envelope outside, junk nil), reach, the rate window, the origin",function()
		local inside=Vector3.new(20,9,-10)
		assert(Balls.clamp(inside)==inside)
		local fast=Balls.clamp(Vector3.new(300,90,0))
		assert(near(Balls.flat(fast).Magnitude,Balls.JumpFlat*Balls.SpeedSlack,1e-6)and near(fast.Y,Balls.JumpUp*Balls.SpeedSlack,1e-6))
		assert(Balls.clamp(Vector3.new(1,-40,1)).Y==0,"never downward")
		assert(Balls.clamp(Vector3.new(0/0,0,0))==nil and Balls.clamp(Vector3.new(math.huge,0,0))==nil and Balls.clamp("x")==nil and Balls.clamp(nil)==nil)
		local bunt=Balls.clamp(Vector3.new(30,12,0),Balls.BuntScale)
		assert(Balls.flat(bunt).Magnitude<=Balls.JumpFlat*Balls.SpeedSlack*Balls.BuntScale+1e-6,"a bunt's envelope")
		local ball=Vector3.new(0,1.2,0)
		assert(Balls.inReach(Vector3.new(6,3,0),ball)and not Balls.inReach(Vector3.new(6.01,3,0),ball))
		assert(not Balls.inReach(Vector3.new(1,1.2+Balls.ReachHeight+.1,0),ball),"height")
		assert(not Balls.inReach(nil,ball)and not Balls.inReach(Vector3.new(0/0,0,0),ball))
		local history={}
		for i=1,4 do assert(Balls.allow(history,10+i*.1),"kick "..i)end
		assert(not Balls.allow(history,10.45),"the fifth in a second")
		assert(#history==4,"a refused kick is not counted")
		assert(Balls.allow(history,11.15),"the window slides")
		local server,before=Vector3.new(10,1,10),Vector3.new(4,1,10)
		local used,own=Balls.origin(Vector3.new(13,1,10),server,before)
		assert(own and used==Vector3.new(13,1,10),"near now")
		used,own=Balls.origin(Vector3.new(1,1,10),server,before)
		assert(own,"near where it was Lag ago")
		used,own=Balls.origin(Vector3.new(30,1,10),server,before)
		assert(not own and used==server,"too far: the server's")
		used,own=Balls.origin(Vector3.new(0/0,1,1),server,before)
		assert(not own and used==server)
	end)

	test("kick trigger and launch: within 1.9 of the surface, faster than 4, heading at it; 26 + 9, a running jump 32 + 13",function()
		local ball=Vector3.new(0,R,0)
		local root=Vector3.new(-(R+1.8),3,0)
		assert(Balls.kicks(root,Vector3.new(10,0,0),ball))
		assert(not Balls.kicks(root,Vector3.new(3.9,0,0),ball),"too slow")
		assert(not Balls.kicks(root,Vector3.new(-10,0,0),ball),"walking away")
		assert(not Balls.kicks(Vector3.new(-(R+2),3,0),Vector3.new(10,0,0),ball),"too far")
		assert(not Balls.kicks(Vector3.new(-(R+1),R+Balls.KickHeight+.5,0),Vector3.new(10,0,0),ball),"over it")
		assert(not Balls.kicks(root,Vector3.new(0/0,0,0),ball))
		local walk,jump=Balls.launch(Vector3.new(3,5,4),false),Balls.launch(Vector3.new(3,5,4),true)
		assert(near(Balls.flat(walk).Magnitude,26,1e-6)and walk.Y==9 and near(Balls.flat(jump).Magnitude,32,1e-6)and jump.Y==13)
		assert(near(walk.X/walk.Z,.75,1e-6),"along the heading")
		assert(Balls.launch(Vector3.new(0,5,0),false)==nil,"no heading, no kick")
	end)

	test("blend maths: keep / blend / fade by the gap; the offset decays smoothly to zero; fade 1 -> 0 -> 1; squash",function()
		assert(Balls.blendMode(0)=="keep"and Balls.blendMode(.05)=="keep"and Balls.blendMode(.06)=="blend")
		assert(Balls.blendMode(12)=="blend"and Balls.blendMode(12.01)=="fade")
		local o=Vector3.new(2,0,-1)
		assert(Balls.offset(o,0,Balls.Blend)==o,"starts where it was drawn: no snap")
		local last=math.huge
		for k=0,15 do
			local m=Balls.offset(o,k*.01,Balls.Blend).Magnitude
			assert(m<=last+1e-12,"monotonic");last=m
		end
		assert(Balls.offset(o,Balls.Blend,Balls.Blend)==Vector3.zero and Balls.offset(o,1,Balls.Blend)==Vector3.zero)
		-- Smooth start: the first frame moves the drawn ball very little (no visible pop).
		assert(o.Magnitude-Balls.offset(o,1/60,Balls.Blend).Magnitude<.15*o.Magnitude)
		local s,arrived=Balls.fade(0,Balls.Fade);assert(s==1 and not arrived)
		s,arrived=Balls.fade(Balls.Fade*.5-1e-6,Balls.Fade);assert(s<1e-3 and not arrived,"shrunk at the old spot")
		s,arrived=Balls.fade(Balls.Fade*.5+1e-6,Balls.Fade);assert(s<1e-3 and arrived,"moved while small")
		s,arrived=Balls.fade(Balls.Fade,Balls.Fade);assert(s==1 and arrived,"grown at the new spot")
		assert(near(Balls.squash(1,0),Balls.Squash)and Balls.squash(1,Balls.SquashTime)==0 and Balls.squash(.5,0)<Balls.squash(1,0))
	end)

	test("wire: pack and unpack round-trip; junk is refused",function()
		local r={id="cork",n=4,origin=Vector3.new(1,2,3),velocity=Vector3.new(4,5,6),startTime=12.5,by=7,seq=3,bunt=true}
		local back=Balls.unpack(Balls.pack(r,Vector3.new(9,1,9)))
		assert(back.id=="cork"and back.n==4 and back.origin==r.origin and back.velocity==r.velocity and back.startTime==12.5)
		assert(back.by==7 and back.seq==3 and back.bunt==true and back.rest==Vector3.new(9,1,9))
		assert(Balls.unpack(nil)==nil and Balls.unpack({id="nope"})==nil)
		assert(Balls.unpack({id="cork",n=1,origin=Vector3.new(0/0,0,0),velocity=Vector3.zero,startTime=0})==nil)
		assert(Balls.unpack({id="cork",n=1,origin=Vector3.zero,velocity=Vector3.zero,startTime=0,kind="home"})==nil,"home needs a target")
	end)
	return{passed=#cases,cases=cases}
end
