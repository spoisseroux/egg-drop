-- Studio Client. My pet's Dewdrop snack and the breath look-up (LifePet; beta 14 QA D2 / B5, GARDEN-LIFE-BUILD-PLAN 2c,
-- architect r1) with a fake pet visual, actor and clock: nothing at all on the live place or with `snack` off (drive and
-- pose write nothing; PetExpression's content face unreachable); notice within 8 studs of the drawn pet, free pets only,
-- once in 90 s; turn, pause, trot to .9, three nibbles (the fruit shrinking), a hop, the content face, one heart, back to
-- the live sample; any broken rule (the drawn pet 8+ studs from its server spot, a menu, the activity gone) eases back;
-- the breath look-up once a breath with `scene` on.
-- Usage: require(PlayerScripts.Client.ZZSpecs.LifePet)(PlayerScripts.Client); offline in
-- scripts/run_dash_server_specs.py (DASH_SPECS="LifePet").
return function(client)
	local Pet=require(client.LifePet)
	local Sim=require(client.LifeSim)
	local Expression=require(client.PetExpression)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function near(a,b,eps)return math.abs(a-b)<=(eps or 1e-6)end
	local S=Pet.Snack

	local function visual(at)
		local v={origin=at or Vector3.new(0,4.025,0),yaw=0,time=0,pieces={},updates=0}
		function v:update(dt)self.updates+=1;self.time+=dt or 0 end
		return v
	end
	local serial=0
	local function fruitAt(position)
		-- A resting drawn fruit (its pose is LifeSim's): t5 passed, t6 far. Each its own id (claims are per fruit).
		serial+=1
		local plan={id="k:"..serial,key=1,rest=position+Vector3.new(0,.5,0),t5=0,t6=1000,start=-2,lands={},r4=0,pose={},stem=position,
			sway=0,dot=1,release=position,p1=position,p2=position,p3=position,p4=position,length=1,heading=Vector3.new(1,0,0),
			t1=-1.9,t2=-1.3,t3=-1.1,t4=-.9,crownY=12,gone=1001}
		return plan
	end
	local function rig(options)
		options=options or {}
		local r={now=100,ceiling=options.ceiling~=false,on=options.on~=false,scene=options.scene==true,busy=false,still=true,
			breath={0,nil},owner=Vector3.new(0,4,-2)}
		r.pet=Pet.new({alive={ceiling=function(f)return f=="snack"and r.ceiling end,on=function(f)return f=="snack"and r.on end},
			now=function()return r.now end,busy=function()return r.busy end,reduced=function()return false end,
			owner=function()return r.owner end,ownerStill=function()return r.still end,scene=function()return r.scene end,
			breath=function()return r.breath[1],r.breath[2]end,world=workspace,life=function()return r.life~=false end,
			userId=function()return r.userId end,rivals=function()return r.rivals end,
			-- GARDEN-PLAY-BRIEF-2: the `fruit` switch, the sounds, the claim, a prop in the way.
			fruit=function()return options.fruit==true end,audio=function(cue)table.insert(r.sounds,cue)end,
			claim=function(loose)table.insert(r.claims,loose)end,blocked=options.blocked})
		r.sounds,r.claims={},{}
		r.userId,r.rivals=options.userId or 10,{}
		r.actor={mode="Room",behavior="rest",action="settle"}
		r.visual=visual()
		r.sample=r.visual.origin
		-- One frame: PetFollow.activity draws the server sample, then LifePet, then the update and the pose.
		function r.frame(dt)
			r.now+=dt
			r.visual.origin=r.sample
			r.visual.careHeadPitch=0
			r.pet:drive(r.visual,r.actor,r.now,dt)
			r.visual:update(dt)
			r.pet:pose(r.visual,dt)
		end
		function r.run(seconds)for _=1,math.floor(seconds*30+.5)do r.frame(1/30)end end
		return r
	end

	test("live safety: with the snack ceiling false (live) or the switch off, notice refuses and drive and pose write nothing",function()
		for _,options in ipairs({{ceiling=false},{on=false}})do
			local r=rig(options)
			r.run(.5)
			local loose=fruitAt(Vector3.new(4,4,0))
			assert(r.pet:notice(loose,r.now)==false and r.pet.active==nil)
			local v=r.visual
			local before={origin=v.origin,yaw=v.yaw,pitch=v.careHeadPitch}
			v.poseDirty=nil
			assert(r.pet:drive(v,r.actor,r.now,1/30)==false and r.pet:pose(v,1/30)==false)
			assert(v.origin==before.origin and v.yaw==before.yaw and v.careHeadPitch==before.pitch and v.contentUntil==nil and v.poseDirty==nil,
				"nothing written")
		end
		-- PetExpression: without contentUntil (never set on live) its answer is unchanged.
		local v={expression="curious",time=5}
		assert(Expression.name(v)=="curious")
		v.contentUntil=6;assert(Expression.name(v)=="content")
		v.time=7;assert(Expression.name(v)=="curious")
	end)

	test("notice: within 8 studs of the drawn pet, a free pet, not busy, the owner near; once in 90 s",function()
		local r=rig()
		r.run(.2)
		assert(r.pet:notice(fruitAt(Vector3.new(8.5,4,0)),r.now)==false,"8.5 studs: no")
		r.busy=true
		assert(r.pet:notice(fruitAt(Vector3.new(5,4,0)),r.now)==false,"busy: no");r.busy=false
		r.actor={mode="Room",behavior="follow"};r.still=false;r.run(.1)
		assert(r.pet:notice(fruitAt(Vector3.new(5,4,0)),r.now)==false,"following a moving owner: no")
		r.still=true;r.run(.1)
		r.actor={mode="Room",behavior="rest",dash={}};r.run(.1)
		assert(r.pet:notice(fruitAt(Vector3.new(5,4,0)),r.now)==false,"racing: no")
		r.actor={mode="Room",behavior="rest"};r.run(.1)
		r.owner=Vector3.new(40,4,0)
		assert(r.pet:notice(fruitAt(Vector3.new(5,4,0)),r.now)==false,"the fruit past the owner's leash: no")
		r.owner=Vector3.new(0,4,-2)
		assert(r.pet:notice(fruitAt(Vector3.new(7.5,4,0)),r.now)==true,"7.5 studs, free: yes")
		assert(r.pet:notice(fruitAt(Vector3.new(3,4,0)),r.now)==false,"one at a time")
		r.pet:release(r.visual)
		assert(r.pet:notice(fruitAt(Vector3.new(3,4,0)),r.now+80)==false,"90 s apart")
		assert(r.pet:notice(fruitAt(Vector3.new(3,4,0)),r.now+91)==true)
	end)

	test("the snack: turn, pause, trot to .9 studs, three nibbles (the fruit shrinks and goes), a .35 hop, content, one heart, back",function()
		local r=rig()
		r.run(.2)
		local loose=fruitAt(Vector3.new(6,4,0))
		assert(r.pet:notice(loose,r.now))
		local start=r.now
		r.run(S.turn+.05)
		assert(near(r.visual.yaw,math.atan2(6,0),.05)and r.visual.origin==r.sample,"turned in place")
		r.run(.2)
		assert(r.visual.careHeadPitch==S.pausePitch,"ears up")
		r.run(.25)
		local arrived
		for _=1,30*4 do
			r.frame(1/30)
			if r.pet.active.phase=="eat"then arrived=r.now;break end
			if r.pet.active.phase=="trot"then assert(r.visual.gaitWeight>.9,"a trot")end
		end
		assert(arrived,"arrived")
		local trot=(6-S.arrive)/S.trot
		assert(near(arrived-start,S.turn+S.pause+trot,.15),"at 3.5 a second: "..(arrived-start))
		assert(near((Vector3.new(6,0,0)-Vector3.new(r.visual.origin.X,0,r.visual.origin.Z)).Magnitude,S.arrive,.05),"within .9")
		assert(loose.eaten,"eating")
		local sizes={}
		for i=0,3 do local pose=Sim.fruitPose(loose,loose.eaten+i*S.nibble+.2);sizes[i]={w=pose.w,phase=pose.phase}end -- (the pose table is reused)
		assert(near(sizes[0].w,1)and near(sizes[1].w,.72)and near(sizes[2].w,.45)and sizes[3].phase=="gone","1, .72, .45, gone")
		local dipped=false
		local updates=r.visual.updates
		for _=1,30*1.1 do r.frame(1/30);if r.visual.updates>updates+1 then dipped=true end;updates=r.visual.updates end
		assert(r.pet.active.phase=="glad","glad after three nibbles")
		assert(r.visual.contentUntil and r.visual.contentUntil>r.visual.time,"the content face")
		assert(r.pet.mote,"one heart")
		local top=0
		for _=1,9 do r.frame(1/30);top=math.max(top,r.visual.origin.Y-r.sample.Y)end
		assert(top>S.hop*.9 and top<=S.hop+1e-6,"a .35 hop: "..top)
		r.run(S.heart)
		assert(r.pet.mote==nil,"the heart gone after .8 s")
		r.run(S.content)
		assert(r.pet.active and r.pet.active.phase=="back","back")
		r.run(3)
		assert(r.pet.active==nil and r.visual.origin==r.sample,"handed back to the server's sample")
	end)

	test("aborts: the drawn pet 8+ studs from its server spot, busy, or the activity gone: an ease back (or at once); the fruit is free again",function()
		local r=rig()
		r.run(.2)
		local loose=fruitAt(Vector3.new(7,4,0))
		assert(r.pet:notice(loose,r.now))
		r.run(1.5)
		assert(r.pet.active.phase=="trot")
		r.sample=Vector3.new(-6,4.025,0) -- the owner walked off: the server's pet with them
		r.frame(1/30)
		assert(r.pet.active.phase=="back"and r.pet.active.quick and loose.taken==nil,"aborted")
		r.run(.5)
		assert(r.pet.active==nil and r.visual.origin==r.sample,"back within .35 s or so")
		-- Busy (a menu) mid-snack.
		local b=rig()
		b.run(.2)
		assert(b.pet:notice(fruitAt(Vector3.new(5,4,0)),b.now))
		b.run(.5);b.busy=true;b.frame(1/30)
		assert(b.pet.active.phase=="back")
		-- The activity no longer draws the pet (focus, the park, a race): dropped at once.
		local c=rig()
		c.run(.2)
		assert(c.pet:notice(fruitAt(Vector3.new(5,4,0)),c.now))
		c.run(1)
		c.now+=1/30;c.visual.origin=c.sample
		c.pet:drive(c.visual,nil,c.now,1/30)
		assert(c.pet.active==nil and c.visual.origin==c.sample)
	end)

	test("code review r1: the walk back is checked too: the owner walks off or a care pickup turns it into the quick ease",function()
		local function toBack(r)
			r.run(.2)
			assert(r.pet:notice(fruitAt(Vector3.new(5,4,0)),r.now))
			for _=1,30*8 do r.frame(1/30);if r.pet.active and r.pet.active.phase=="back"then return end end
			error("never walked back")
		end
		for _,change in ipairs({
			function(r)r.actor={mode="Room",behavior="follow"};r.still=false end,
			function(r)r.actor={mode="Room",behavior="rest",care={state="Carried"}}end,
		})do
			local r=rig()
			toBack(r)
			assert(not r.pet.active.quick,"a plain walk back first")
			change(r)
			r.frame(1/30)
			assert(r.pet.active and r.pet.active.quick,"turned into the quick ease")
			r.run(.4)
			assert(r.pet.active==nil and r.visual.origin==r.sample,"handed back within .35 s")
		end
		-- The owner walks away during the walk back: the drawn pet 8+ studs from its server spot.
		local r=rig()
		toBack(r)
		r.sample=r.sample+Vector3.new(-12,0,0)
		r.frame(1/30)
		assert(r.pet.active.quick,"drift past 8 studs")
	end)

	test("code review r1: garden life torn down mid-snack (budget level 2, life off): the snack is released at once",function()
		local r=rig()
		r.run(.2)
		assert(r.pet:notice(fruitAt(Vector3.new(6,4,0)),r.now))
		r.run(1)
		assert(r.pet.active)
		r.life=false
		r.frame(1/30)
		assert(r.pet.active==nil and r.visual.origin==r.sample,"released")
	end)

	test("STUDIO-CHECK-R5 R6: the snapshot's spellings (parkId, peerId) refuse; a park pose aborts; SnackWhy says why",function()
		local free,why=Pet.free({mode="Room",behavior="rest",parkId="arrival"},true)
		assert(free==false and why=="park")
		free,why=Pet.free({mode="Room",behavior="rest",peerId=7},true)
		assert(free==false and why=="greeting")
		free,why=Pet.free(nil,true)
		assert(free==false and string.find(why,"no garden actor",1,true))
		free,why=Pet.free({mode="Room",behavior="investigate",action="wander"},true)
		assert(free==false and string.find(why,"investigate/wander",1,true))
		assert(Pet.free({mode="Room",behavior="rest",action="wanderPause"},false)==true,"a wander pause is free")
		-- SnackWhy on my pet's model: the last refusal, written only on change.
		local r=rig()
		local model=Instance.new("Model")
		r.visual.model=model
		r.run(.2)
		r.pet:notice(fruitAt(Vector3.new(9,4,0)),r.now)
		assert(string.find(model:GetAttribute("SnackWhy"),"9.0 studs off",1,true),tostring(model:GetAttribute("SnackWhy")))
		r.busy="a menu"
		r.pet:notice(fruitAt(Vector3.new(5,4,0)),r.now)
		assert(model:GetAttribute("SnackWhy")=="refused: a menu")
		r.busy=false
		assert(r.pet:notice(fruitAt(Vector3.new(5,4,0)),r.now))
		assert(string.find(model:GetAttribute("SnackWhy"),"snack: going",1,true))
		-- A park pose (ParkClient set parkPosedOrigin this frame): aborted.
		r.run(.5)
		r.visual.parkPosedOrigin=r.visual.origin
		r.now+=1/30;r.visual.origin=r.sample;r.pet:drive(r.visual,r.actor,r.now,1/30)
		assert(r.pet.active.quick and model:GetAttribute("SnackWhy")=="aborted: park pose")
		r.visual.parkPosedOrigin=nil
	end)

	test("never two pets on one fruit, on one client: one snack claims it; the other refuses until the claim is released",function()
		local a,b=rig(),rig()
		local modelB=Instance.new("Model");b.visual.model=modelB
		a.run(.2);b.run(.2)
		local loose=fruitAt(Vector3.new(5,4,0))
		assert(a.pet:notice(loose,a.now))
		assert(b.pet:notice(loose,b.now)==false and modelB:GetAttribute("SnackWhy")=="refused: fruit claimed by another snack")
		-- A's snack aborts (the owner walks off): the claim goes with it.
		a.sample=Vector3.new(-12,4.025,0);a.frame(1/30);a.run(.5)
		assert(a.pet.active==nil and Pet.Claims[loose.id]==nil,"released on abort")
		loose.taken=nil
		assert(b.pet:notice(loose,b.now),"B may now")
		b.pet:destroy()
		assert(Pet.Claims[loose.id]==nil,"released on teardown")
		-- Done: a whole snack releases it too.
		local c=rig();c.run(.2)
		local other=fruitAt(Vector3.new(4,4,0))
		assert(c.pet:notice(other,c.now))
		c.run(12)
		assert(c.pet.active==nil and Pet.Claims[other.id]==nil,"released when done")
	end)

	test("never two pets on one fruit, across clients: only the nearest pet (server positions; lowest UserId on a tie) goes; no stealing mid-snack",function()
		local r=rig()
		local model=Instance.new("Model");r.visual.model=model
		r.run(.2)
		-- Another owner's pet nearer the fruit: refused.
		r.rivals={{ownerId=20,position=Vector3.new(5.5,4,0)}}
		assert(r.pet:notice(fruitAt(Vector3.new(6,4,0)),r.now)==false)
		assert(model:GetAttribute("SnackWhy")=="refused: fruit claimed by a nearer pet")
		-- Farther: mine.
		r.rivals={{ownerId=20,position=Vector3.new(20,4,0)}}
		local fruit=fruitAt(Vector3.new(6,4,0))
		assert(r.pet:notice(fruit,r.now))
		-- Mid-snack the rival comes nearer: no stealing (only notice time decides).
		r.rivals={{ownerId=20,position=Vector3.new(6,4,0)}}
		r.run(1)
		assert(r.pet.active and not r.pet.active.quick,"still going")
		r.pet:release(r.visual)
		-- A tie (both 5 studs off): the lowest UserId goes.
		local t=rig();t.run(.2)
		t.rivals={{ownerId=5,position=Vector3.new(10,4,0)}}
		assert(t.pet:notice(fruitAt(Vector3.new(5,4,0)),t.now)==false,"5 < 10: theirs")
		t.userId=3
		assert(t.pet:notice(fruitAt(Vector3.new(5,4,0)),t.now),"3 < 5: mine")
		-- Both clients agree: from the other owner's side the same rule picks the same pet.
		local mine,theirs=Vector3.new(0,4,0),Vector3.new(10,4,0)
		local spot=Vector3.new(5,4,0)
		local x,y=rig(),rig()
		x.userId,y.userId=3,5
		x.rivals={{ownerId=5,position=theirs}};y.rivals={{ownerId=3,position=mine}}
		y.sample=theirs;y.visual.origin=theirs
		x.run(.2);y.run(.2)
		assert(x.pet:nearest(spot,mine)==true and y.pet:nearest(spot,theirs)==false,"one winner on every client")
	end)

	test("the breath look-up (scene on): the head lifts for 1.2 s once a breath; scene off or busy, none",function()
		local r=rig({scene=true})
		r.breath={.9,41}
		local most,frames=0,0
		for _=1,60 do
			r.frame(1/30)
			if(r.visual.careHeadPitch or 0)<0 then frames+=1;most=math.min(most,r.visual.careHeadPitch)end
		end
		assert(near(most,Pet.Look.pitch,1e-6)and frames>=33 and frames<=37,"1.2 s up: "..frames)
		r.run(1)
		assert(r.visual.careHeadPitch==0,"once a breath")
		r.breath={.9,42};r.run(.3)
		assert(r.visual.careHeadPitch<0,"the next breath")
		local off=rig({scene=false})
		off.breath={.9,41};off.run(.5)
		assert(off.visual.careHeadPitch==0,"scene off: none")
	end)

	-- GARDEN-PLAY-BRIEF-2 -----------------------------------------------------------------------------------------
	local Fruit=require(game:GetService("ReplicatedStorage").Shared.GardenFruit)
	test("five bites (`fruit` on): 3.2 s of eating, a nom a bite, a gulp at the last, a happy squeak; the claim once; cheeks puff",function()
		local r=rig({fruit=true})
		r.visual.pieces={{name="Head",part={Position=Vector3.new(0,5,0),CFrame=CFrame.new(0,5,0),Size=Vector3.one}},
			{name="CheekL",channel="Face",part={Position=Vector3.new(.3,5,.3),CFrame=CFrame.new(.3,5,.3),Size=Vector3.one*.2}}}
		r.run(.2)
		local loose=fruitAt(Vector3.new(4,4,0))
		assert(r.pet:notice(loose,r.now))
		local eating=nil
		local puffed=false
		for _=1,30*8 do
			r.frame(1/30)
			if r.pet.active and r.pet.active.phase=="eat"then
				eating=eating or r.now
				if r.visual.pieces[2].part.Size.X>.2+1e-6 then puffed=true end
				r.visual.pieces[2].part.Size=Vector3.one*.2
			end
			if eating and r.pet.active and r.pet.active.phase~="eat"then break end
		end
		assert(eating and loose.five==true and loose.eaten,"the fruit knows it is the five-bite one")
		assert(near(r.now-eating,Fruit.Bites.time,.1),"3.2 s: "..(r.now-eating))
		local noms,gulps,happy=0,0,0
		for _,cue in ipairs(r.sounds)do
			if string.sub(cue,1,9)=="snack_nom"then noms+=1 end
			if cue==Fruit.Sounds.gulp then gulps+=1 end
			if cue==Fruit.Sounds.happy then happy+=1 end
		end
		assert(noms==Fruit.Bites.count and gulps==1 and happy==1,noms.." "..gulps.." "..happy)
		assert(#r.claims==1 and r.claims[1]==loose,"told the server once")
		assert(puffed,"the cheeks puff on a bite")
		r.run(4)
		assert(#r.claims==1)
		-- Off: three nibbles, no claim, the old cue.
		local old=rig()
		old.run(.2)
		local plain=fruitAt(Vector3.new(4,4,0))
		assert(old.pet:notice(plain,old.now))
		old.run(6)
		assert(plain.five==nil and #old.claims==0 and old.sounds[1]=="dewdrop_nibble")
	end)
	test("a prop in the way (GardenKeepOut, `keepout`): the straight trot is refused; a clear one goes",function()
		local r=rig({blocked=function(from,to)return to.X>3 end})
		r.run(.2)
		assert(r.pet:notice(fruitAt(Vector3.new(6,4,0)),r.now)==false and r.pet.active==nil)
		assert(r.pet:notice(fruitAt(Vector3.new(0,4,3)),r.now)==true)
	end)

	return{passed=#cases,cases=cases}
end
