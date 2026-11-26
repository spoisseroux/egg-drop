-- Bumble balls host (GARDEN-PLAY-BRIEF section 1), with a fake clock, roots and remotes: the server checks a kick
-- (reach, rate, clamp, origin, one per ball per BallGap), stamps startTime and n, plans the rest spot and broadcasts;
-- a refusal answers the kicker with the current record; joiners get rest spots; abandoned balls roll home; a free
-- pet at a resting ball noses it at 40%, once per 8 s per ball. Switch off: nothing.
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Balls=require(Shared.BumbleBalls)
	local Motion=require(Shared.BallMotion)
	local Host=require(server.BumbleBallHost)
	local Pets=require(server.BumbleBallPets)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function rig(options)
		options=options or {}
		local r={t=options.t or 100,on=true,roots={},sent={},cast={},pets={}}
		r.host=Host.new({now=function()return r.t end,on=function()return r.on end,root=function(player)return r.roots[player]end,
			roots=function()local out={};for _,p in pairs(r.roots)do table.insert(out,p)end;return out end,
			send=function(player,payload)table.insert(r.sent,{player=player,payload=payload})end,
			broadcast=function(payload)table.insert(r.cast,payload)end,
			pets=function()return r.pets end,random=options.random})
		return r
	end
	local A,B={UserId=11},{UserId=22}
	local function beside(id,dx)local h=Motion.home(id);return h+Vector3.new(dx or -2,1.8,0)end
	local function packet(id,seq,origin,velocity)return{kind="kick",id=id,seq=seq,origin=origin,velocity=velocity}end

	test("start: three still records at the homes; hello answers every rest spot, at most every 2 s",function()
		local r=rig()
		r.host:receive(A,{kind="hello"})
		assert(#r.sent==1 and r.sent[1].payload.kind=="state"and #r.sent[1].payload.balls==3)
		for _,packed in ipairs(r.sent[1].payload.balls)do
			local record=Balls.unpack(packed)
			assert(record and record.n==0 and record.rest==Motion.home(record.id)and record.velocity==Vector3.zero)
		end
		r.host:receive(A,{kind="hello"});assert(#r.sent==1,"too soon")
		r.t+=2;r.host:receive(A,{kind="hello"});assert(#r.sent==2)
	end)

	test("an accepted kick: the client's origin and velocity as sent, the server's time, n + 1, the planned rest, broadcast",function()
		local r=rig()
		r.roots[A]=beside("felt")
		local origin=Motion.home("felt")
		local v=Balls.launch(Vector3.new(1,0,0),false)
		local record=r.host:receive(A,packet("felt",1,origin,v))
		assert(record and #r.cast==1 and #r.sent==0)
		local wire=Balls.unpack(r.cast[1].record)
		assert(wire.n==1 and wire.startTime==100 and wire.origin==origin and wire.velocity==v and wire.by==11 and wire.seq==1)
		assert(wire.rest==Motion.plan(wire).rest,"everyone plans the server's rest spot")
		assert(r.host.balls.felt.rest==wire.rest and r.host.balls.felt.restAt==100+Motion.plan(wire).duration)
	end)

	test("refusals answer the kicker alone with the current record: reach, junk, busy; nothing is broadcast",function()
		local r=rig()
		r.roots[A]=Motion.home("felt")+Vector3.new(-6.5,1.8,0)
		r.host:receive(A,packet("felt",1,Motion.home("felt"),Vector3.new(26,9,0)))
		assert(#r.cast==0 and #r.sent==1 and r.sent[1].payload.kind=="refuse"and r.sent[1].payload.reason=="Reach"and r.sent[1].payload.seq==1)
		assert(Balls.unpack(r.sent[1].payload.record).n==0)
		r.roots[A]=beside("felt")
		r.host:receive(A,packet("felt",2,Motion.home("felt"),Vector3.new(0/0,0,0)))
		assert(#r.sent==1,"a second refusal within RefuseGap gets no answer (a flood gets silence)")
		r.t+=Host.RefuseGap
		r.host:receive(A,packet("felt",2,Motion.home("felt"),Vector3.new(0/0,0,0)))
		assert(r.sent[2].payload.reason=="Velocity")
		r.roots[B]=beside("felt",2)
		r.host:receive(A,packet("felt",3,Motion.home("felt"),Vector3.new(26,9,0)))
		r.host:receive(B,packet("felt",1,Motion.home("felt"),Vector3.new(-26,9,0)))
		assert(#r.cast==1 and r.sent[3].payload.reason=="Busy"and r.sent[3].player==B,"one kick per ball per BallGap")
		-- Junk packets are dropped without a word.
		for _,junk in ipairs({nil,5,{kind="kick"},{kind="kick",id="felt",seq=1.5},{kind="kick",id="nope",seq=1},{kind="kick",id={},seq=1}})do
			r.host:receive(A,junk)
		end
		assert(#r.sent==3 and #r.cast==1)
	end)

	test("rate: four kicks a second per player, the fifth refused, then the window slides",function()
		local r=rig()
		for i=1,4 do
			r.t+=.2
			r.roots[A]=Motion.sample(r.host.balls.felt.record,r.t)+Vector3.new(-1,1.8,0)
			assert(r.host:receive(A,packet("felt",i,Motion.sample(r.host.balls.felt.record,r.t),Vector3.new(2,0,0))),"kick "..i)
		end
		r.t+=.15
		r.roots[A]=Motion.sample(r.host.balls.felt.record,r.t)+Vector3.new(-1,1.8,0)
		r.host:receive(A,packet("felt",5,Motion.sample(r.host.balls.felt.record,r.t),Vector3.new(2,0,0)))
		assert(r.sent[#r.sent].payload.reason=="Rate")
		r.t+=.3
		r.roots[A]=Motion.sample(r.host.balls.felt.record,r.t)+Vector3.new(-1,1.8,0)
		assert(r.host:receive(A,packet("felt",6,Motion.sample(r.host.balls.felt.record,r.t),Vector3.new(2,0,0))))
	end)

	test("clamp and origin: a too-fast kick goes out at the envelope; a far claimed origin is replaced by the server's",function()
		local r=rig()
		r.roots[A]=beside("cork")
		local record=r.host:receive(A,packet("cork",1,Motion.home("cork"),Vector3.new(500,500,0)))
		assert(math.abs(Balls.flat(record.velocity).Magnitude-Balls.JumpFlat*Balls.SpeedSlack)<1e-6)
		r.t+=5
		local at=Motion.sample(r.host.balls.cork.record,r.t)
		r.roots[A]=at+Vector3.new(-2,1.8,0)
		record=r.host:receive(A,packet("cork",2,at+Vector3.new(Balls.OriginSlack+1,0,0),Vector3.new(10,4,0)))
		assert(record and record.origin==at,"contested: the server's own spot (the kicker blends to it)")
		r.t+=5
		at=Motion.sample(r.host.balls.cork.record,r.t)
		r.roots[A]=at+Vector3.new(-2,1.8,0)
		local claim=at+Vector3.new(1,0,0)
		record=r.host:receive(A,packet("cork",3,claim,Vector3.new(10,4,0)))
		assert(record.origin==claim,"close enough: the client's own (its prediction stands)")
	end)

	test("two kicks at once: both accepted in order (n 1 then 2), the second from where the first left it",function()
		local r=rig()
		local home=Motion.home("wicker")
		r.roots[A],r.roots[B]=home+Vector3.new(-2,1.8,0),home+Vector3.new(2,1.8,0)
		local first=r.host:receive(A,packet("wicker",1,home,Vector3.new(26,9,0)))
		r.t+=Balls.BallGap+.01
		local second=r.host:receive(B,packet("wicker",1,home,Vector3.new(-26,9,0)))
		assert(first.n==1 and second.n==2 and #r.cast==2)
		assert((second.origin-Motion.sample(first,r.t)).Magnitude<=Balls.OriginSlack)
	end)

	test("abandoned: a ball resting away from home with nobody within 30 for 20 s rolls home (straight, or a fade)",function()
		local r=rig()
		r.roots[A]=beside("felt")
		r.host:receive(A,packet("felt",1,Motion.home("felt"),Vector3.new(20,6,0)))
		local rest=r.host.balls.felt.rest
		assert(Balls.planDistance(rest,Motion.home("felt"))>Balls.HomeSlack)
		r.t=r.host.balls.felt.restAt+1;r.host:tick()
		r.t+=Balls.AbandonAfter-2;r.host:tick();assert(#r.cast==1,"still near A")
		r.roots[A]=rest+Vector3.new(Balls.AbandonRadius+5,0,0)
		r.t+=Balls.AbandonAfter-1;r.host:tick();assert(#r.cast==1,"not long enough alone")
		r.t+=2;r.host:tick()
		assert(#r.cast==2,"rolled home")
		local home=Balls.unpack(r.cast[2].record)
		assert(home.kind=="home"and home.n==2 and home.target==Motion.home("felt")and home.rest==Motion.home("felt"))
		local plan=Motion.plan(home)
		assert(math.abs(plan.duration-Balls.planDistance(rest,Motion.home("felt"))/Balls.HomeSpeed)<.05,"slowly")
		assert(home.fade==not Motion.lineClear("felt",rest,Motion.home("felt")))
		r.t+=plan.duration+60;r.host:tick();assert(#r.cast==2,"at home it stays")
	end)

	test("switch off: no kick, no hello, no tick",function()
		local r=rig();r.on=false
		r.roots[A]=beside("felt")
		r.host:receive(A,{kind="hello"});r.host:receive(A,packet("felt",1,Motion.home("felt"),Vector3.new(26,9,0)))
		r.t+=1000;r.host:tick()
		assert(#r.sent==0 and #r.cast==0)
	end)

	test("pets: a still pet at a settled ball, one in three, once per 8 s per ball; the bunt is a kick at 40%",function()
		local rolls={}
		local rng={NextNumber=function()return table.remove(rolls,1)or .9 end}
		local r=rig({random=rng})
		local home=Motion.home("felt")
		r.pets={{ownerId=11,position=home+Vector3.new(-(Balls.Radius+1),-.9,0)}}
		rolls={.9}
		r.host:tick();assert(#r.cast==0,"a failed roll")
		r.t+=Pets.Cooldown-.1;rolls={.1};r.host:tick();assert(#r.cast==0,"cooldown")
		r.t+=.2;rolls={.1};r.host:tick()
		assert(#r.cast==1,"bunted")
		local bunt=Balls.unpack(r.cast[1].record)
		assert(bunt.bunt and bunt.by==0)
		assert(math.abs(Balls.flat(bunt.velocity).Magnitude-Balls.KickFlat*Balls.BuntScale)<1e-6 and bunt.velocity.X>0,"away from the pet, at 40%")
		-- Moving balls and far pets are left alone.
		local balls={felt={rest=home,restAt=0,buntAt=-math.huge}}
		assert(#Pets.pick(balls,{{ownerId=1,position=home+Vector3.new(Balls.Radius+Pets.Range+.2,0,0)}},10,{NextNumber=function()return 0 end})==0,"far")
		balls.felt.restAt=9
		assert(#Pets.pick(balls,{{ownerId=1,position=home+Vector3.new(1.5,0,0)}},10,{NextNumber=function()return 0 end})==0,"not settled")
		-- free(): only still pets in the garden.
		local garden={actors={
			[1]={ownerId=1,mode="Room",startTime=0,endTime=0,from={0,0,0},to={0,0,0},path={}},
			[2]={ownerId=2,mode="Board"},[3]={ownerId=3,mode="Room",dash="race"},[4]={ownerId=4,mode="Room",pairId="p"},
		}}
		local free=Pets.free(garden,5)
		for _,pet in ipairs(free)do assert(pet.ownerId==1,"only the free one")end
	end)
	return{passed=#cases,cases=cases}
end
