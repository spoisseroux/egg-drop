-- Bumble balls, one client's drawn ball (BumbleBallView) with fake clocks: my kick draws at once and keeps its timing
-- when the server accepts it; someone else's kick joins the arc part-way along and blends from where the ball is drawn
-- (never a snap); a refused or contested kick blends to the server's arc over .2 s; a newer record that lands while mine
-- is in flight waits for my answer; a gap over 12 studs shrinks, moves and grows; a late packet only starts later.
return function(client)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Balls=require(Shared.BumbleBalls)
	local Motion=require(Shared.BallMotion)
	local View=require(client.BumbleBallView)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local ME,OTHER=11,22
	local home=Motion.home("felt")
	local function still(n)return Motion.rest("felt",home,n or 0)end
	local function record(n,origin,velocity,start,by,seq)
		local r={id="felt",n=n,origin=origin,velocity=velocity,startTime=start,by=by,seq=seq}
		r.rest=Motion.plan(r).rest
		return Balls.unpack(Balls.pack(r,r.rest))
	end
	local function fresh(now)local v=View.new("felt");v:set(still(0),now,0,"instant");v:step(now,0);return v end
	-- Step a view from clock c0 to c1 at 60 Hz with server time = clock + skew; the largest jump between frames.
	local function run(view,c0,c1,skew)
		local worst=0
		local last=view.drawn
		for c=c0,c1,1/60 do
			local drawn=view:step(c+skew,c)
			if last then worst=math.max(worst,(drawn-last).Magnitude)end
			last=drawn
		end
		return worst,last
	end

	test("my kick: drawn from the same frame; the server's accept keeps my clock, takes n and the rest spot; no blend",function()
		local v=fresh(10)
		local mine={id="felt",n=0,origin=home,velocity=Balls.launch(Vector3.new(1,0,0),false),startTime=10,by=ME,seq=1}
		assert(v:predict(mine,10,0,1)=="keep")
		local drawn=v:step(10+1/60,1/60)
		assert((drawn-Motion.sample(mine,10+1/60)).Magnitude<1e-9,"on the predicted arc at once")
		run(v,2/60,.16,10)
		-- The server got it 80 ms later and stamped its own time.
		local accepted=record(1,mine.origin,mine.velocity,10.08,ME,1)
		assert(v:receive(accepted,ME,10.16,.16)==nil)
		assert(v.record==mine and mine.n==1 and mine.rest==accepted.rest and mine.startTime==10,"the prediction stands")
		assert(v.offset==Vector3.zero and not v.pending)
		local worst=run(v,.16+1/60,4,10)
		assert(worst<1,"smooth: "..worst)
		assert((v.drawn-accepted.rest).Magnitude<1e-9,"rests at the server's rest spot")
	end)

	test("someone else's kick: joins the arc part-way along, blends from the drawn ball over .15 s, never snaps",function()
		local v=fresh(10)
		local theirs=record(1,home,Balls.launch(Vector3.new(0,0,1),true),20,OTHER,4)
		-- It reaches me 120 ms after the server stamped it.
		local before=v.drawn
		assert(v:receive(theirs,ME,20.12,5)=="kick")
		local drawn=v:step(20.12,5)
		assert((drawn-before).Magnitude<1e-6,"the first frame is where it was drawn")
		local worst,last=run(v,5+1/60,5+Balls.Blend+.05,15.12)
		assert(worst<1.2,"no jump while blending: "..worst)
		assert((last-Motion.sample(theirs,5+Balls.Blend+.05+15.12)).Magnitude<1e-6,"on the server's arc after the blend")
		assert(v:receive(theirs,ME,21,6)==nil,"a repeat is ignored")
		assert(v:receive(record(0,home,Vector3.zero,1,OTHER,1),ME,21,6)==nil,"an older n is ignored")
	end)

	test("a late packet costs a later start, not a stutter: 300 ms late joins further along, still continuous",function()
		local v=fresh(10)
		local theirs=record(1,home,Balls.launch(Vector3.new(1,0,0),false),30,OTHER,1)
		v:receive(theirs,ME,30.3,1)
		assert(v.fadeAt==nil and v.offset.Magnitude>4,"a blend over the gap it is late by")
		local worst=run(v,1,1.4,29.3)
		-- The 7.5-stud catch-up spread over .15 s: under 2 studs a frame at its fastest (a snap would be all of it at once).
		assert(worst<2,"continuous: "..worst)
		assert((v.drawn-Motion.sample(theirs,30.7)).Magnitude<1e-6)
	end)

	test("refused: back to the server's record over .2 s",function()
		local v=fresh(10)
		local mine={id="felt",n=0,origin=home,velocity=Vector3.new(26,9,0),startTime=40,by=ME,seq=2}
		v:predict(mine,40,0,2)
		run(v,0,.3,40)
		local away=v.drawn
		assert((away-home).Magnitude>3)
		assert(not v:refuse(1,still(0),40.31,.31),"another seq is not mine")
		assert(v:refuse(2,still(0),40.31,.31))
		assert(v.blendFor==Balls.Correct and v.record.n==0)
		local first=v:step(40.31,.31)
		assert((first-away).Magnitude<1e-6,"starts where it was drawn")
		local worst=run(v,.31+1/60,.31+Balls.Correct,40)
		assert((v.drawn-home).Magnitude<1e-6,"at the server's spot after .2 s")
		assert(worst<3,"a blend, not a snap: "..worst)
	end)

	test("contested: a newer record while mine is in flight waits; my answer decides (accepted later: mine; refused: theirs)",function()
		local v=fresh(10)
		local mine={id="felt",n=0,origin=home,velocity=Vector3.new(26,9,0),startTime=50,by=ME,seq=3}
		v:predict(mine,50,0,3)
		local theirs=record(1,home,Vector3.new(-26,9,0),50.02,OTHER,9)
		assert(v:receive(theirs,ME,50.1,.1)==nil and v.deferred==theirs and v.record==mine,"held")
		-- The server took theirs first, then mine (n 2) from where theirs had it: contested, so mine differs: blend .2.
		local served=record(2,Motion.sample(theirs,50.06),mine.velocity,50.06,ME,3)
		v:receive(served,ME,50.14,.14)
		assert(v.record==served and v.blendFor==Balls.Correct and not v.pending and not v.deferred)
		-- Refused instead: the refuse carries their record.
		local w=fresh(10)
		w:predict({id="felt",n=0,origin=home,velocity=Vector3.new(26,9,0),startTime=60,by=ME,seq=4},60,0,4)
		w:receive(record(1,home,Vector3.new(-26,9,0),60.02,OTHER,1),ME,60.1,.1)
		assert(w:refuse(4,record(1,home,Vector3.new(-26,9,0),60.02,OTHER,1),60.12,.12)and w.record.n==1 and w.blendFor==Balls.Correct)
		-- No answer at all: whatever came meanwhile, after View.Pending.
		local x=fresh(10)
		x:predict({id="felt",n=0,origin=home,velocity=Vector3.new(26,9,0),startTime=70,by=ME,seq=5},70,0,5)
		local late=record(1,home,Vector3.new(0,9,26),70.05,OTHER,1)
		x:receive(late,ME,70.1,.1)
		assert(not x:expire(71,1)and x:expire(73,View.Pending+.01)and x.record==late)
	end)

	test("a gap over 12 studs: shrink at the old spot, move while small, grow at the new one",function()
		local v=fresh(10)
		local far=Motion.rest("felt",home+Vector3.new(15,0,0),1)
		far.rest=Motion.plan(far).rest
		assert(v:receive(far,ME,80,0)==nil)
		assert(v.fadeAt==0)
		local d,s=v:step(80,.05);assert((d-home).Magnitude<1e-6 and s<1,"shrinking where it was")
		d,s=v:step(80,.2);assert((d-far.rest).Magnitude<1e-6 and s<1,"growing where it is")
		d,s=v:step(80,.3);assert(s==1 and v.fadeAt==nil)
	end)

	test("events: the bounces after I join are played once; the ones before are not",function()
		local v=fresh(10)
		local theirs=record(1,home,Balls.launch(Vector3.new(1,0,0),true),90,OTHER,1)
		local plan=Motion.plan(theirs)
		local firstBounce
		for _,e in ipairs(plan.events)do if e.kind=="bounce"then firstBounce=e.t;break end end
		v:receive(theirs,ME,90+firstBounce+.01,0)
		local heard=0
		for c=0,3,1/60 do
			local _,_,_,events=v:step(90+firstBounce+.01+c,c)
			for _,e in ipairs(events)do if e.kind=="bounce"then heard+=1;assert(e.t>firstBounce)end end
		end
		local total=0;for _,e in ipairs(plan.events)do if e.kind=="bounce"then total+=1 end end
		assert(heard==total-1,"all but the one before I joined: "..heard.."/"..total)
	end)

	test("a device that rounds differently: the plan's end blends to the server's rest spot",function()
		local v=fresh(10)
		local theirs=record(1,home,Vector3.new(10,3,0),100,OTHER,1)
		theirs.rest=theirs.rest+Vector3.new(.4,0,0)
		v:receive(theirs,ME,100,0)
		assert(v.restFix)
		run(v,0,Motion.plan(theirs).duration+Balls.Correct+.1,100)
		assert((v.drawn-theirs.rest).Magnitude<1e-6)
	end)
	return{passed=#cases,cases=cases}
end
