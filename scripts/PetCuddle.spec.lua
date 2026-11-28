-- The petting screen's rules (ONBOARDING-V3-BRIEF section 4, switch `pet2`): the Happy heart's fill, drain, stages and
-- burst, the purr pitch, the brush gain, the lean, the look, the mitten, the screen sizes, the spots and the favourite.
-- Pure (PetCuddle, Alive, FeatureFlags, UICopy).
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.PetCuddle)(ServerScriptService.Server); offline in
-- scripts/run_dash_server_specs.py.
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local C=require(Shared.PetCuddle)
	local Alive=require(Shared.Alive)
	local Flags=require(Shared.FeatureFlags)
	local UICopy=require(Shared.UICopy)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function near(a,b,eps)return math.abs(a-b)<=(eps or 1e-6)end
	local function run(state,seconds,rubbing,favourite,dt)
		dt=dt or 1/60
		local events={}
		local t=0
		while t<seconds-1e-9 do
			local e=C.step(state,dt,rubbing,favourite)
			if e.stage then table.insert(events,"stage"..e.stage)end
			if e.burst then table.insert(events,"burst")end
			t+=dt
		end
		return events
	end

	test("the switch: an Alive feature on the beta and in Studio, never live; its flag is in the build",function()
		assert(C.Feature=="pet2"and table.find(Alive.Features,"pet2")~=nil and Flags.AlivePet2==true)
		assert(Alive.attribute("pet2")=="Alive_pet2"and Alive.key("pet2")=="alive_pet2")
		assert(Alive.ceiling("pet2",{AlivePet2=true},107705084891479,false),"on the beta")
		assert(Alive.ceiling("pet2",{AlivePet2=true},96451847774961,true),"in Studio")
		assert(not Alive.ceiling("pet2",{AlivePet2=true},96451847774961,false),"never on live")
		assert(not Alive.ceiling("pet2",{},107705084891479,true),"not without its flag")
		assert(Alive.resolve("pet2",nil,nil,true)==true,"missing is on")
		assert(Alive.resolve("pet2",false,nil,true)==false and Alive.resolve("pet2",true,false,true)==false,"off and the override")
	end)

	test("the heart fills in 6 s of rubbing, twice as fast on the favourite spot, and starts empty every visit",function()
		local s=C.new()
		assert(s.fill==0 and s.stage==0 and s.bursts==0)
		run(s,3,true,false)
		assert(near(s.fill,.5,.02),"half in 3 s: "..s.fill)
		local f=C.new();run(f,1.5,true,true)
		assert(near(f.fill,.5,.02),"favourite: half in 1.5 s: "..f.fill)
		assert(C.Fill.seconds==6 and C.Fill.favourite==2)
	end)

	test("the first visit (the onboarding fun pass): the heart fills in 3 s and the burst closes the screen 0.8 s later",function()
		assert(C.First.seconds==3 and C.First.close==.8)
		local s=C.new(true)
		assert(s.first==true and s.fill==0)
		run(s,1.5,true,false)
		assert(near(s.fill,.5,.02),"half in 1.5 s: "..s.fill)
		local events=run(s,1.6,true,false)
		assert(table.find(events,"burst")~=nil and s.bursts==1,"the burst by 3.1 s: "..table.concat(events," "))
		assert(not C.closeDue(s,nil,10),"no burst yet: never")
		assert(not C.closeDue(s,10,10.79)and C.closeDue(s,10,10.8),"0.8 s after the burst")
		-- every later visit: 6 s and it never closes itself
		local later=C.new(false)
		assert(later.first==false and later.seconds==C.Fill.seconds and not C.closeDue(later,0,100))
		assert(not C.new().first,"no argument: a normal visit")
	end)

	test("stages at 33, 66 and 100%: the settle beats, then the burst drops the heart to 20%",function()
		assert(C.stageOf(0)==0 and C.stageOf(.329)==0 and C.stageOf(.33)==1 and C.stageOf(.659)==1)
		assert(C.stageOf(.66)==2 and C.stageOf(.999)==2 and C.stageOf(1)==3)
		local s=C.new()
		local events=run(s,6.1,true,false)
		assert(table.concat(events," ")=="stage1 stage2 burst",table.concat(events," "))
		assert(near(s.fill,.2,.02)and s.stage==0 and s.bursts==1,"after the burst: "..s.fill)
		-- Keep rubbing: the next burst comes 80% of a heart later (4.8 s), with both stages on the way.
		local again=run(s,4.85,true,false)
		assert(table.concat(again," ")=="stage1 stage2 burst",table.concat(again," "))
		assert(s.bursts==2)
	end)

	test("it drains 5% a second unrubbed, never under empty; no fail state, no timer",function()
		local s=C.new();s.fill=.5;s.stage=1
		local events=run(s,2,false,false)
		assert(near(s.fill,.4,.005),"drained: "..s.fill)
		assert(#events==0,"draining never fires a stage")
		run(s,20,false,false)
		assert(s.fill==0 and s.stage==0)
		-- A long idle visit is fine: nothing ever ends it.
		run(s,120,false,false,.25)
		assert(s.fill==0 and s.bursts==0)
		-- Dropping below a stage and climbing back fires it again.
		s.fill=.36;s.stage=1;run(s,1,false,false);assert(s.stage==0)
		local back=run(s,.5,true,false);assert(table.concat(back," ")=="stage1",table.concat(back," "))
	end)

	test("a rub is contact with the hand moving (or a held E / X); big steps are clamped",function()
		assert(C.rubbing(true,C.RubSpeed,false)and not C.rubbing(true,C.RubSpeed-1,false))
		assert(C.rubbing(true,0,true)and not C.rubbing(false,900,true))
		local s=C.new();C.step(s,5,true,false)
		assert(near(s.fill,.25/6,1e-6),"one step counts .25 s at most")
	end)

	test("hearts rise from stage 1 (small, every .5 s) and stage 2 (bigger, every .4 s)",function()
		assert(C.heartEvery(0)==nil)
		local e1,s1=C.heartEvery(1);local e2,s2=C.heartEvery(2)
		assert(e1==.5 and e2==.4 and s2>s1)
		assert(C.Hearts.burst==8 and C.Hearts.sparkles==10 and C.Hearts.colour=="#FF6FA8"and C.Hearts.sparkle=="#FFE58A")
	end)

	test("the purr pitch goes .9 to 1.15 with the heart (full from 66%); the brush gain follows the hand's speed",function()
		assert(near(C.purrPitch(0),.9)and near(C.purrPitch(.66),1.15)and near(C.purrPitch(1),1.15))
		assert(near(C.purrPitch(.33),1.025,1e-3))
		assert(C.brushGain(0)==0 and near(C.brushGain(450),.125)and near(C.brushGain(5000),.25))
	end)

	test("the lean: up to 12 degrees toward the hand, more sideways the further out, eased in .2 s",function()
		local function total(p,r)return math.sqrt(p*p+r*r)end
		for _,side in ipairs({-1,-.4,0,.4,1})do
			local p,r=C.lean(side,1)
			assert(near(total(p,r),math.rad(12),1e-6),"12 degrees at side "..side)
			assert(p>0,"a little toward the camera")
			if side>0 then assert(r<0,"its right: the top moves to +X (negative roll)")elseif side<0 then assert(r>0)else assert(r==0)end
		end
		local p,r=C.lean(1,.5);assert(near(total(p,r),math.rad(6),1e-6),"half the weight, half the lean")
		local p0,r0=C.lean(1,0);assert(p0==0 and r0==0)
		local _,rFar=C.lean(1,1);local _,rNear=C.lean(.3,1);assert(math.abs(rFar)>math.abs(rNear))
		local v=0;for _=1,12 do v=C.ease(v,1,1/60,C.Lean.ease)end
		assert(v>.9 and v<1,"about there after .2 s: "..v)
	end)

	test("the look: the head turns and the eyes shift toward the hand, clamped, scaled by the weight",function()
		local yaw,pitch,ex,ey=C.look(Vector3.new(1,0,2),1)
		assert(yaw>0 and ex>0 and math.abs(pitch)<1e-9 and math.abs(ey)<1e-9,"to its right")
		local _,up,_,eyUp=C.look(Vector3.new(0,1,2),1)
		assert(up<0 and eyUp>0,"up: the head pitches up (negative), the eyes go up")
		local y2,p2,ex2,ey2=C.look(Vector3.new(50,50,.1),1)
		assert(near(y2,C.Look.yaw)and near(p2,-C.Look.pitch),"the head clamped")
		local E=C.Look.eye
		assert(ex2>0 and ey2>0 and(ex2/E.aside)^2+(ey2/E.up)^2<=1+1e-6,"a diagonal stays on the ellipse")
		local y3=C.look(Vector3.new(1,0,2),.5);assert(near(y3,yaw*.5),"weighted")
		local a,b,c,d=C.look(nil,1);assert(a==0 and b==0 and c==0 and d==0)
	end)
	-- Beta (40), Spencer: "the eyes still clip into the head mesh when looking at extremes".
	test("beta 40: the eyes stay inside an ellipse (.02 aside, .012 up, .008 down); a diagonal never reaches the old .05",function()
		local E=C.Look.eye
		assert(near(E.aside,.02)and near(E.up,.012)and near(E.down,.008))
		-- straight extremes: each axis at its own limit
		local _,_,ex,ey=C.look(Vector3.new(50,0,.1),1);assert(near(ex,E.aside)and near(ey,0),"aside")
		_,_,ex,ey=C.look(Vector3.new(-50,0,.1),1);assert(near(ex,-E.aside),"the other side")
		_,_,ex,ey=C.look(Vector3.new(0,50,.1),1);assert(near(ex,0)and near(ey,E.up),"up")
		_,_,ex,ey=C.look(Vector3.new(0,-50,.1),1);assert(near(ey,-E.down),"down: less than up (the muzzle)")
		-- every direction at full stretch, and part way: inside, never past .02 (the old square's corner was .05)
		for i=0,71 do
			local a=i/72*math.pi*2
			for _,reach in ipairs({.3,1,50})do
				local _,_,x,y=C.look(Vector3.new(math.cos(a)*reach,math.sin(a)*reach,1),1)
				local r=(x/E.aside)^2+(y/(if y>=0 then E.up else E.down))^2
				assert(r<=1+1e-6,string.format("inside at %d deg x %.1f: %.4f",i*5,reach,r))
				assert(math.sqrt(x*x+y*y)<=E.aside+1e-9,"never past .02")
			end
		end
		-- a small look is unchanged (the ellipse only trims the extremes)
		local _,_,sx,sy=C.look(Vector3.new(.05,.02,1),1)
		local nx=math.atan2(.05,1)/C.Look.yaw;local ny=math.atan2(.02,math.sqrt(.05^2+1))/C.Look.pitch
		assert(near(sx,nx*E.aside)and near(sy,ny*E.up),"small looks as before")
		-- a rig's own ellipse
		local own={aside=.03,up=.02,down=.01}
		_,_,ex,ey=C.look(Vector3.new(50,0,.1),1,own);assert(near(ex,.03))
		_,_,ex,ey=C.look(Vector3.new(0,-50,.1),1,own);assert(near(ey,-.01))
		local x,y=C.eyeShift(1,1,nil);assert((x/E.aside)^2+(y/E.up)^2<=1+1e-6 and x>0 and y>0,"eyeShift alone")
		x,y=C.eyeShift(0,0);assert(x==0 and y==0)
	end)

	test("the mitten: 48 px as the cursor, 56 px 28 px above a finger; tilt 12 degrees, squash .92",function()
		local pc,off=C.hand("mouse");assert(pc==48 and off.X==0 and off.Y==0)
		local phone,lift=C.hand("touch");assert(phone==56 and lift.X==0 and lift.Y==-28)
		local pad=C.hand("gamepad");assert(pad==48)
		assert(C.handTilt(0)==0 and C.handTilt(600)==12 and C.handTilt(-6000)==-12 and near(C.handTilt(300),6))
		assert(C.handScale(true)==.92 and C.handScale(false)==1)
		assert(C.Hand.ink=="#1B2A4A"and C.Hand.fill=="#FFFFFF"and C.Hand.outline==2.5)
	end)

	test("sizes: the phone (812 x 354) gets the 56 px heart and 14 px text, a computer 72 and 16; Back is 48",function()
		local phone=C.layout(812,354);assert(phone.phone and phone.heart==56 and phone.text==14 and phone.back==48)
		local pc=C.layout(1920,1080);assert(not pc.phone and pc.heart==72 and pc.text==16 and pc.back==48)
		local portrait=C.layout(390,844);assert(portrait.phone)
	end)

	test("the favourite spot comes from the pet's id: stable, one of the spots, not the same for every pet",function()
		local seen={}
		for _,id in ipairs({"bear","bunny","zivvi","ovelle","pip","puddle","blip","kitty"})do
			local spot=C.favourite(id)
			assert(table.find(C.Spots,spot),id)
			assert(C.favourite(id)==spot,"stable")
			seen[spot]=true
		end
		local n=0;for _ in pairs(seen)do n+=1 end
		assert(n>=3,"spread over the spots: "..n)
		assert(table.find(C.Spots,C.favourite(nil))and table.find(C.Spots,C.favourite("")))
		assert(C.FavouriteHint==4)
	end)

	test("spots: the head on top, ears at the top, cheeks either side, chin under, belly, back and tail below",function()
		assert(C.spotAt(.5,.05)=="ears"and C.spotAt(.1,.25)=="ears"and C.spotAt(.5,.25)=="head")
		assert(C.spotAt(.25,.4)=="cheeks"and C.spotAt(.78,.5)=="cheeks"and C.spotAt(.5,.5)=="chin")
		assert(C.spotAt(.5,.7)=="belly"and C.spotAt(.1,.7)=="back"and C.spotAt(.5,.95)=="tail")
		for _,spot in ipairs(C.Spots)do
			local at=C.SpotCentre[spot];assert(at,spot)
			assert(C.spotAt(at.X,at.Y)==spot,"the sparkles sit on "..spot)
		end
	end)

	test("each spot answers (ticklish, never upset); Reduced Motion keeps the eyes, drops the wiggle",function()
		local head=C.spotPose("head",1,0,false);assert(head.eye<.3)
		local cheeks=C.spotPose("cheeks",.5,1,false);assert(cheeks.headRoll>0 and cheeks.stretch<0)
		assert(C.spotPose("cheeks",.5,-1,false).headRoll<0)
		assert(C.spotPose("chin",.5,0,false).headPitch<0,"the nose lifts")
		local belly=C.spotPose("belly",.3,0,false);assert(belly.sway~=0)
		assert(C.spotPose("back",1.2,0,false).stretch>.07)
		assert(C.spotPose("ears",.15,0,false).eye==0,"a blink")
		assert(C.spotPose("tail",.05,0,false).ear~=0,"a twitch")
		for _,spot in ipairs(C.Spots)do
			local still=C.spotPose(spot,.4,1,true)
			assert(still.sway==0 and still.stretch==0 and still.ear==0 and still.hop==0,spot.." still")
		end
		local none=C.spotPose(nil,1,0,false);assert(none.eye==1 and none.headPitch==0)
	end)

	test("the burst's wiggle-jump lasts .6 s; nothing under Reduced Motion",function()
		local hop,sway=C.burstPose(.3,false);assert(hop>.3 and math.abs(sway)<=.1)
		local h2=C.burstPose(.6,false);assert(h2==0)
		local h3,s3=C.burstPose(.3,true);assert(h3==0 and s3==0)
	end)

	test("the words: the hint and the favourite line name the pet",function()
		assert(UICopy.get("pet.cuddle.rub",{pet="Bear"})=="Rub Bear!")
		assert(UICopy.get("pet.cuddle.loves",{pet="Bear"})=="Bear loves this!")
		assert(UICopy.get("pet.cuddle.back")=="Back")
	end)

	test("beta 42 D13: a pet with no name yet reads Pet on its pill",function()
		assert(UICopy.get("pet.unnamed")=="Pet")
	end)

	test("beta 42 D17: the hand's aim over the resting box: centre 0, the face at 30% down, clamped, none without a hand",function()
		local x,y=C.handTarget(.5,.3);assert(x==0 and y==0)
		x,y=C.handTarget(1,1);assert(near(x,1)and near(y,1.4))
		x,y=C.handTarget(-3,9);assert(x==-1.5 and y==1.5)
		x,y=C.handTarget(nil,.4);assert(x==0 and y==0)
		x,y=C.handTarget(0/0,.4);assert(x==0 and y==0)
	end)

	test("beta 42 D17: the lean and look glide to the hand (no snap, no overshoot) and a hitch never jumps them",function()
		local s={}
		local x=C.easeHand(s,1,.3,1/60)
		assert(x>0 and x<.3,"one frame moves a little, not all the way: "..x)
		local last=x
		for _=1,120 do
			local now=C.easeHand(s,1,.3,1/60)
			assert(now>=last-1e-12 and now<=1+1e-9,"monotone, never past the target")
			last=now
		end
		assert(near(last,1,.01),"arrives")
		-- a 2 s hitch is one .1 s step
		local h={};local a=C.easeHand(h,1,.3,2);local b=C.easeHand({},1,.3,.1);assert(near(a,b))
		-- the hand leaves: back toward centre, smoothly
		local before=s.dx;C.easeHand(s,nil,nil,1/60);assert(s.dx<before and s.dx>before*.7)
	end)

	test("beta 42 D17: a jittering hand reading is calmed, not passed on frame to frame",function()
		local s={dx=0,dy=0};local high,low=-math.huge,math.huge
		for i=1,240 do
			local u=if i%2==0 then .56 else .44 -- the raw aim flips -.12 / +.12 each frame
			local x=C.easeHand(s,u,.3,1/60)
			if i>60 then high=math.max(high,x);low=math.min(low,x)end
		end
		assert(high-low<.05,"jitter passed through: "..(high-low))
	end)
	return{passed=#cases,cases=cases}
end
