-- Studio Client. Alive step 4: what the wind moves (WindClient), WorldMotion's gust gain, the greeting
-- blocker's rest pose and the rustle voice. Fixture parts and fake clocks: no live room, no sound plays.
-- Usage: require(PlayerScripts.Client.ZZSpecs.WindClient)(PlayerScripts.Client)
return function(client)
	local Wind=require(client.Wind)
	local WindClient=require(client.WindClient)
	local Motion=require(client.WorldMotion)
	local Ambient=require(client.AmbientAudio)
	local Room=require(client.RoomView)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local T0=1795300000
	local nan=0/0
	local holder=Instance.new("Folder");holder.Name="_WindSpec";holder.Parent=workspace
	local live={}
	local shared=Ambient.shared -- the game's own, put back at the end
	-- Signals may be deferred.
	local function events()task.wait();task.wait()end

	local function bush(folder,at,options)
		options=options or {}
		local rest=CFrame.new(at)*CFrame.Angles(0,at.X*.37,0)
		local p=Instance.new("Part");p.Name="W7D_FrondFan";p.Size=Vector3.new(3,1.2,3)
		p.Anchored,p.CanCollide,p.CanQuery,p.CanTouch,p.CastShadow=options.anchored~=false,false,false,false,false
		p.CFrame=rest
		if not options.noKind then p:SetAttribute("WorldDressing","bush")end
		if not options.noRest then p:SetAttribute("WorldRestCFrame",options.rest or p.CFrame)end
		if options.moved then p.CFrame=rest*CFrame.Angles(.4,0,.2)end
		p.Parent=folder
		return p
	end
	local function lounge(world,count,options)
		local room=Instance.new("Folder");room.Name="EggDropLounge"
		local folder=Instance.new("Folder");folder.Name="Dressing"
		local parts={}
		for i=1,count do parts[i]=bush(folder,Vector3.new(i*4,4,-i*2),options)end
		folder.Parent=room;room.Parent=world
		return room,folder,parts
	end
	local function rig(count,options)
		options=options or {}
		local r={time=T0,eye=Vector3.new(0,6,0),lvl=0,still=false,state="Room",hatch=false,on=true,moves=0,written=0}
		r.world=Instance.new("Folder");r.world.Parent=holder
		if count then r.room,r.folder,r.parts=lounge(r.world,count,options)end
		r.client=WindClient.new({world=r.world,motion=options.motion,auto=false,touch=options.touch==true,
			alive={on=function(feature)return feature~="scene"and r.on end},level=function()return r.lvl end,now=function()return r.time end,
			eye=function()return r.eye end,reduced=function()return r.still end,mode=function()return r.state end,hatching=function()return r.hatch end,
			warn=function(text)r.warned=(r.warned or 0)+1;r.problem=text end,
			move=if options.realMove then nil else function(parts,frames)if r.broken then error("move failed")end;r.moves+=1;r.written+=#parts;for i,p in ipairs(parts)do p.CFrame=frames[i]end end})
		function r.steps(n,dt)
			for _=1,n do r.time+=dt or 1/30;r.client:step(dt or 1/30)end
		end
		r.client:sync()
		table.insert(live,r.client)
		return r
	end
	local function tip(rest,cf)return math.deg(math.acos(math.clamp(rest.UpVector:Dot(cf.UpVector),-1,1)))end
	local function rests(parts)
		for i,p in ipairs(parts)do assert(p.CFrame==p:GetAttribute("WorldRestCFrame"),"bush "..i.." is not on its rest pose")end
	end
	local function leaning(parts)
		local n=0
		for _,p in ipairs(parts)do if p.CFrame~=p:GetAttribute("WorldRestCFrame")then n+=1 end end
		return n
	end

	local ok,err=pcall(function()

	test("binds only from WorldRestCFrame, and goes to rest before the first sway",function()
		local r=rig(3,{moved=true})
		assert(#r.client.entries==3,"bound "..#r.client.entries);rests(r.parts)
		bush(r.folder,Vector3.new(0,4,0),{noRest=true});bush(r.folder,Vector3.new(1,4,0),{noKind=true})
		bush(r.folder,Vector3.new(2,4,0),{anchored=false})
		local block=Instance.new("Folder");block.Parent=r.folder
		local bad=bush(r.folder,Vector3.new(3,4,0),{noRest=true});bad:SetAttribute("WorldRestCFrame","nope")
		local broken=bush(r.folder,Vector3.new(3,4,0),{noRest=true});broken:SetAttribute("WorldRestCFrame",CFrame.new(nan,0,0))
		local late=bush(r.folder,Vector3.new(5,4,0),{noRest=true})
		events();assert(#r.client.entries==3,"a part without a good rest pose was bound: "..#r.client.entries)
		late:SetAttribute("WorldRestCFrame",late.CFrame);events()
		assert(#r.client.entries==4,"late attribute not bound")
		r.steps(60);assert(leaning({late})==1,"a late bush never sways")
	end)

	test("sways about its base, at most 6 degrees, and touches nothing but CFrame",function()
		local r=rig(6)
		local most=0
		for _=1,3000 do
			r.steps(1)
			for i,p in ipairs(r.parts)do
				local rest=p:GetAttribute("WorldRestCFrame")
				most=math.max(most,tip(rest,p.CFrame))
				local foot=Vector3.new(0,-p.Size.Y*.5,0)
				assert((rest*foot-p.CFrame*foot).Magnitude<.002,"bush "..i.." left its base")
			end
		end
		assert(most>3 and most<6.05,"peak lean "..most)
		for _,p in ipairs(r.parts)do
			assert(p.Parent==r.folder and p.Size==Vector3.new(3,1.2,3)and p.Anchored and not p.CanCollide and not p.CanQuery and not p.CanTouch and not p.CastShadow)
		end
		assert(math.abs(WindClient.amplitude(Wind.Breeze)-WindClient.Rest)<1e-9 and WindClient.amplitude(1)==WindClient.Peak and WindClient.amplitude(5)==WindClient.Peak)
		assert(WindClient.amplitude(0)==0 and WindClient.amplitude(nan)==0 and WindClient.amplitude(nil)==0)
	end)

	test("no drift: 10,000 steps, then off is one write of the exact rest and nothing after",function()
		local r=rig(6);r.steps(10000)
		assert(leaning(r.parts)>0,"never moved")
		r.moves,r.on=0,false;r.client:sync()
		rests(r.parts);assert(r.moves==1,"off wrote "..r.moves.." times")
		assert(#r.client.links==0 and #r.client.roomLinks==0 and next(r.client.candidates)==nil and #r.client.entries==0,"off left something connected")
		r.steps(100);assert(r.moves==1);rests(r.parts)
		r.client:sync();assert(r.moves==1,"off twice")
		r.on=true;r.client:sync();r.steps(60);assert(leaning(r.parts)>0,"on again")
		local before=r.moves;r.client:destroy();rests(r.parts);assert(r.moves==before+1)
		r.client:destroy();r.client:step(1/30);r.client:sync();rests(r.parts)
	end)

	test("off before it ever moved writes nothing",function()
		local r=rig(4);r.on=false;r.client:sync();assert(r.moves==0);rests(r.parts)
	end)

	local function easesOut(name,park,back)
		test(name,function()
			local r=rig(4);r.steps(200);assert(leaning(r.parts)==4)
			local frames={};for i,p in ipairs(r.parts)do frames[i]=p.CFrame end
			park(r)
			local ticks=0
			repeat
				r.steps(1);ticks+=1
				for i,p in ipairs(r.parts)do
					assert(tip(frames[i],p.CFrame)<1.7,"popped "..tip(frames[i],p.CFrame));frames[i]=p.CFrame
				end
			until leaning(r.parts)==0 or ticks>90
			assert(ticks>5 and ticks<=40,"eased in "..ticks.." ticks");rests(r.parts)
			r.steps(10);local done=r.moves;r.steps(200);assert(r.moves==done,"still writing while at rest")
			back(r);r.steps(60);assert(leaning(r.parts)==4,"did not come back")
		end)
	end
	easesOut("deck round: eases to rest, then no writes, then back",function(r)r.state="Board"end,function(r)r.state="Room"end)
	easesOut("no board yet counts as parked",function(r)r.state=nil end,function(r)r.state="Room"end)
	easesOut("hatch: eases to rest and back",function(r)r.hatch=true end,function(r)r.hatch=false end)
	easesOut("out of range: eases to rest, never pops, and back",function(r)r.eye=Vector3.new(0,6,900)end,function(r)r.eye=Vector3.new(0,6,0)end)
	easesOut("no camera: eases to rest and back",function(r)r.eye=nil end,function(r)r.eye=Vector3.new(0,6,0)end)

	test("budget level 2 is still; level 1 is 15 Hz inside 60 studs",function()
		local r=rig(30);r.steps(60);r.lvl=2;r.steps(60,1/15);rests(r.parts)
		local done=r.moves;r.steps(100);assert(r.moves==done)
		r=rig(30);r.lvl=1;r.steps(90);r.moves=0;r.steps(60)
		assert(r.moves>=29 and r.moves<=31,"15 Hz wrote "..r.moves.." in 60 frames")
		for i,p in ipairs(r.parts)do
			local far=(p:GetAttribute("WorldRestCFrame").Position-r.eye).Magnitude>WindClient.SlowRange
			assert((leaning({p})==0)==far,"bush "..i)
		end
	end)

	test("caps: nearest 16 within 120 studs on touch, 44 within 200 on desktop",function()
		local r=rig(30,{touch=true});r.steps(200)
		assert(leaning(r.parts)==16,"touch "..leaning(r.parts))
		for i=1,16 do assert(leaning({r.parts[i]})==1,"nearest first: "..i)end
		r=rig(60);r.steps(200);assert(leaning(r.parts)==44,"desktop "..leaning(r.parts))
		for _,p in ipairs(r.parts)do
			if (p:GetAttribute("WorldRestCFrame").Position-r.eye).Magnitude>200 then assert(leaning({p})==0)end
		end
		assert(WindClient.Phone.range==120 and WindClient.Desktop.range==200)
	end)

	test("Reduced Motion is still at once, and comes back easing in",function()
		local r=rig(4);r.steps(200);r.moves,r.still=0,true
		r.steps(1);rests(r.parts);assert(r.moves==1);r.steps(100);assert(r.moves==1,"still writing")
		r.still=false;r.steps(2)
		for _,p in ipairs(r.parts)do assert(tip(p:GetAttribute("WorldRestCFrame"),p.CFrame)<.5,"popped back")end
		r.steps(60);assert(leaning(r.parts)==4)
	end)

	test("clock jumps, NaN, huge, negative and missing dt never throw, pop or leave a bad pose",function()
		local r=rig(4);r.steps(200)
		local frames={};for i,p in ipairs(r.parts)do frames[i]=p.CFrame end
		-- From a lull into the top of a gust and back, then anywhere.
		local at=r.parts[1]:GetAttribute("WorldRestCFrame").Position
		local top,lull=0,0
		for i=1,8000 do
			if Wind.gust(at,T0+i*.05)>.9 then top=T0+i*.05 elseif Wind.gust(at,T0+i*.05)==0 and Wind.gust(at,T0+i*.05+1)==0 then lull=T0+i*.05 end
		end
		assert(top>0 and lull>0)
		local jumps={3,-40,1000,-1e6,86400,.4}
		for _=1,12 do table.insert(jumps,"top");table.insert(jumps,"lull")end
		for _,jump in ipairs(jumps)do
			if jump=="top"then r.time=top elseif jump=="lull"then r.time=lull else r.time+=jump end
			for _=1,10 do
				r.steps(1)
				for i,p in ipairs(r.parts)do
					local d=tip(frames[i],p.CFrame);assert(d==d and d<1.7,"jump "..jump.." popped "..d);frames[i]=p.CFrame
				end
			end
		end
		for _,dt in ipairs({nan,-1,0,1e9,math.huge})do r.client:step(dt)end
		r.client:step(nil)
		for _,t in ipairs({nan,math.huge})do r.time=t;r.client:step(1/30);r.client:step(1/30)end
		for _,p in ipairs(r.parts)do
			local rest=p:GetAttribute("WorldRestCFrame")
			assert((p.CFrame.Position-rest.Position).Magnitude<.2 and tip(rest,p.CFrame)<6.05)
		end
		r.time=T0;r.steps(60);r.on=false;r.client:sync();rests(r.parts)
	end)

	test("streamed out mid-sway and back: rest first, then it sways",function()
		local r=rig(3);r.steps(100)
		local p=r.parts[2];assert(leaning({p})==1)
		p.Parent=nil;events();assert(#r.client.entries==2)
		r.steps(10);rests({p})
		p.CFrame*=CFrame.Angles(.5,0,0);p.Parent=r.folder;events()
		assert(#r.client.entries==3);rests({p})
		r.steps(60);assert(leaning({p})==1)
		p:Destroy();events();r.steps(10);assert(#r.client.entries==2)
	end)

	test("missing world, late Dressing, room replaced and removed",function()
		local r=rig(nil);r.steps(20);assert(r.moves==0)
		local room=Instance.new("Folder");room.Name="EggDropLounge";room.Parent=r.world;events();r.steps(5)
		local folder=Instance.new("Folder");folder.Name="Dressing";local first=bush(folder,Vector3.new(3,4,0));folder.Parent=room;events()
		assert(#r.client.entries==1,"late Dressing");r.steps(60);assert(leaning({first})==1)
		local newRoom,_,parts=lounge(r.world,2);events()
		assert(r.client.room==newRoom and #r.client.entries==2,"new room not bound");rests({first})
		room:Destroy();events();assert(r.client.room==newRoom,"the old room leaving unbound the new one")
		r.steps(60);assert(leaning(parts)==2)
		newRoom.Parent=nil;events();assert(r.client.room==nil and #r.client.entries==0);rests(parts);r.steps(10)
		newRoom.Parent=r.world;events();assert(#r.client.entries==2);r.steps(60);assert(leaning(parts)==2)
		newRoom.Dressing.Parent=nil;events();assert(#r.client.entries==0);rests(parts)
	end)

	local function empty(r)
		return not r.client.enabled and #r.client.links==0 and #r.client.roomLinks==0 and next(r.client.candidates)==nil
			and #r.client.entries==0 and r.client.room==nil and next(r.client.folders)==nil and next(r.client.folderLinks)==nil and next(r.client.owners)==nil
	end

	test("the real mover with a detached room: no throw, exact rest, nothing left connected",function()
		-- The room leaves.
		local r=rig(4,{realMove=true});r.steps(60);assert(leaning(r.parts)==4,"the real mover moved nothing")
		r.room.Parent=nil;events();rests(r.parts);assert(r.client.room==nil and #r.client.entries==0 and #r.client.roomLinks==0)
		r.room.Parent=r.world;events();r.steps(60);assert(leaning(r.parts)==4)
		-- Everything above the room leaves, so the room itself never signals; frames keep coming.
		r.world.Parent=nil;r.steps(30);r.state="Board";r.steps(60);rests(r.parts);r.state="Room"
		r.world.Parent=holder;r.steps(60);assert(leaning(r.parts)==4)
		r.world.Parent=nil;r.steps(5);assert(leaning(r.parts)==4)
		r.on=false;r.client:sync();rests(r.parts);assert(empty(r)and not r.warned,r.problem)
		-- Reduced Motion and destroy in the same state.
		r.world.Parent=holder;r.on=true;r.client:sync();r.steps(60);r.world.Parent=nil;r.still=true;r.steps(1);rests(r.parts)
		r.still=false;r.world.Parent=holder;r.steps(60);assert(leaning(r.parts)==4)
		r.world.Parent=nil;r.client:destroy();rests(r.parts);assert(empty(r)and not r.warned)
		-- A room destroyed outright.
		r=rig(3,{realMove=true});r.steps(60);r.room:Destroy();events();r.steps(10)
		assert(#r.client.entries==0 and next(r.client.candidates)==nil and not r.warned)
	end)

	test("a bulk move that fails: one report, exact rest, all disconnected, and back when switched again",function()
		local r=rig(4);r.steps(60);assert(leaning(r.parts)==4)
		r.broken=true
		for _=1,20 do r.time+=1/30;r.client:frame(1/30)end
		rests(r.parts);assert(empty(r)and r.warned==1,"reports "..tostring(r.warned))
		r.broken=false;r.client:sync();r.steps(60);assert(leaning(r.parts)==4)
		r.broken,r.on=true,false;r.client:sync();rests(r.parts);assert(empty(r)and r.warned==1)
		-- A start that fails half way is undone.
		r.on,r.broken=true,false
		r.client.bind=function(self,room)if room then error("bind failed")end;return WindClient.bind(self,room)end
		r.client:sync();assert(empty(r)and r.warned==2);r.client:step(1/30)
		r.client.bind=nil;r.client:sync();r.steps(60);assert(leaning(r.parts)==4)
	end)

	-- WorldMotion
	-- Motion.pose as it was at 6696339.
	local TAU=math.pi*2
	local function before(kind,rest,pivot,amp,period,phase,t)
		local wave=math.sin(TAU*(t/period+phase))
		if kind=="bob"then return rest+Vector3.new(0,amp*wave,0)end
		if kind=="flag"then
			local flap=(wave+.35*math.sin(TAU*(t/period*2.3+phase*1.7)))/1.35
			local at=pivot or rest.Position
			return CFrame.new(at)*CFrame.Angles(0,math.rad(amp)*flap,0)*CFrame.new(-at)*rest
		end
		if kind=="sway"or kind=="spin"then
			local angle=math.rad(amp)*wave
			local turn=if kind=="spin"then CFrame.Angles(0,angle,0)else CFrame.Angles(angle,0,angle*.35)
			local at=pivot or rest.Position
			return CFrame.new(at)*turn*CFrame.new(-at)*rest
		end
		return rest
	end
	local Movers={{"bob","DriftRocksA",1.4},{"flag","CastleFlag_1",16},{"sway","Chime_1",7},{"sway","Pennant_1",9},{"sway","Lantern",4},{"spin","CradleMobile",10},{"pulse","LampOrbs",.25}}
	local function island()
		local room=Instance.new("Folder");room.Name="EggDropLounge"
		local world=Instance.new("Folder");world.Name="World";world.Parent=room
		for i,m in ipairs(Movers)do
			local p=Instance.new("Part");p.Name="Mover"..i;p.Anchored,p.CanCollide=true,false;p.CFrame=CFrame.new(i*5,20,i)
			p:SetAttribute("WorldMotion",m[1]);p:SetAttribute("WorldRegion",m[2]);p:SetAttribute("WorldMotionAmp",m[3])
			p:SetAttribute("WorldMotionPeriod",2+i*.3);p:SetAttribute("WorldMotionPhase",i*.17);p:SetAttribute("WorldRestCFrame",p.CFrame)
			p:SetAttribute("WorldMotionFar",true);p:SetAttribute("WorldPivot",Vector3.new(i*5,21,i));p.Parent=world
		end
		room.Parent=holder
		local motion=Motion.new(holder);function motion:reduced()return false end
		motion:bind(room)
		return motion,room
	end

	test("WorldMotion with no wind, and with a gust of 0, is today's pose bit for bit for every kind",function()
		local plain,roomA=island();local windy,roomB=island();windy.gust=function()return 0 end
		for i=0,200 do
			local t=1000+i*.031
			for j,e in ipairs(plain.entries)do
				local old=before(e.kind,e.rest,e.pivot,e.amp,e.period,e.phase,t)
				assert(Motion.pose(e.kind,e.rest,e.pivot,e.amp,e.period,e.phase,t)==old,e.kind)
				for _,g in ipairs({0,-1,nan})do
					assert(Motion.pose(e.kind,e.rest,e.pivot,Motion.gusted(e.amp,e.gain or 1,g),e.period,e.phase,t)==old,e.kind.." gust "..g)
				end
				assert(j>0)
			end
			plain:apply(t);windy:apply(t)
			for j,e in ipairs(plain.entries)do
				local other=windy.entries[j].part
				assert(e.part.CFrame==other.CFrame and e.part.Transparency==other.Transparency,e.kind)
			end
		end
		assert(Motion.gusted(7,2.5,nil)==7 and Motion.gusted(7,2.5,"x")==7)
		roomA:Destroy();roomB:Destroy()
	end)

	test("a gust widens only flags and pennants x1.8 and chimes x2.5; the phase does not move",function()
		local motion,room=island();local gains={}
		for i,e in ipairs(motion.entries)do gains[Movers[i][2]]=e.gain or 1 end
		assert(gains.CastleFlag_1==1.8 and gains.Pennant_1==1.8 and gains.Chime_1==2.5)
		assert(gains.DriftRocksA==1 and gains.Lantern==1 and gains.CradleMobile==1 and gains.LampOrbs==1)
		assert(Motion.gusted(10,1.8,1)==18 and Motion.gusted(10,2.5,7)==25 and Motion.gusted(10,1.8,.5)==14)
		-- Where the wave crosses zero the pose is the rest pose whatever the gust.
		local rest=CFrame.new(3,4,5)
		assert(Motion.pose("sway",rest,nil,Motion.gusted(7,2.5,1),2,0,0)==Motion.pose("sway",rest,nil,7,2,0,0))
		room:Destroy()
	end)

	test("a gust hook that throws is dropped and the movers keep going",function()
		local motion,room=island();motion.gust=function()error("broken")end
		motion:apply(10.3);assert(motion.gust==nil)
		for _,e in ipairs(motion.entries)do if e.kind=="sway"then assert(e.part.CFrame~=e.rest)end end
		motion:apply(10.4);room:Destroy()
	end)

	test("the client drives the gain: eased in, 0 while parked, gone the moment it is off",function()
		local motion,room=island()
		local r=rig(1,{motion=motion})
		local chime;for _,e in ipairs(motion.entries)do if e.gain==2.5 then chime=e end end
		assert(type(motion.gust)=="function"and motion.gust(chime)==0)
		local most,last=0,0
		for _=1,3000 do
			r.steps(1);local g=motion.gust(chime)
			assert(g>=0 and g<=1 and math.abs(g-last)<=WindClient.Slew/30+1/15,"gain jumped");most,last=math.max(most,g),g
		end
		assert(most>.5,"no gust reached the chimes")
		-- Wait for a gust, then start a round in it.
		for _=1,3000 do r.steps(1);if motion.gust(chime)>.5 then break end end
		last=motion.gust(chime);assert(last>.5);r.state="Board"
		for _=1,30 do r.steps(1);local g=motion.gust(chime);assert(math.abs(g-last)<.2);last=g end
		assert(last==0,"parked is gain 1");r.steps(300);assert(motion.gust(chime)==0)
		r.state="Room";r.steps(30);r.still=true;r.steps(1);assert(motion.gust(chime)==0)
		r.still=false;r.steps(30)
		motion:bind(nil);r.steps(30);motion:bind(room);r.steps(30)
		r.on=false;r.client:sync();assert(motion.gust==nil and next(r.client.gusts)==nil)
		-- Someone else's hook is never removed.
		r.on=true;r.client:sync();local other=function()return 0 end;motion.gust=other;r.on=false;r.client:sync();assert(motion.gust==other)
		room:Destroy()
	end)

	test("a greeting plan sees a swaying bush at its rest pose, and other parts where they are",function()
		local room=Instance.new("Folder");room.Parent=holder
		local floor=Instance.new("Part");floor.Anchored=true;floor.Parent=room
		local swayed=bush(room,Vector3.new(3,4,0),{moved=true})
		local noRest=bush(room,Vector3.new(4,4,0),{noRest=true,moved=true})
		local plain=bush(room,Vector3.new(5,4,0),{noKind=true,moved=true})
		local seen={}
		for _,b in ipairs(Room.greetingVisualBlocks(room,floor,Vector3.new(0,4,0),30))do seen[b.source]=b.CFrame end
		assert(seen[swayed]==swayed:GetAttribute("WorldRestCFrame")and seen[swayed]~=swayed.CFrame)
		assert(seen[noRest]==noRest.CFrame and seen[plain]==plain.CFrame)
		room:Destroy()
	end)

	-- Rustle
	local function ambient(wind)
		local audio={master=1,deviceActive=true,ducks={}}
		function audio:isMusicEnabled()return true end
		function audio:duck()end
		local a=Ambient.new(audio,{auto=false,world=holder,wind=wind,data={beams={stream={},falls={}}},perches={},daylight=function()return 1 end,now=function()return 0 end,listener=function()return Vector3.zero end})
		table.insert(live,a)
		return a,audio
	end
	local function voice()
		local v={IsLoaded=true,IsPlaying=false,Volume=0,TimePosition=0,plays=0,stops=0}
		function v:Play()self.IsPlaying=true;self.plays+=1 end
		function v:Stop()self.IsPlaying=false;self.stops+=1 end
		function v:Destroy()self.gone=true end
		return v
	end
	local function run(a,n)for _=1,n do a:step(1/30)end end

	-- The shipped build has no rustle id (beta (12) QA S1); the voice cases run on a fixture id and put it back.
	local shipped=Ambient.RustleId
	local function withId(run)
		Ambient.RustleId=1
		local ok,problem=pcall(run)
		Ambient.RustleId=shipped
		assert(ok,problem)
	end
	test("rustle: the shipped build makes no voice, even in a full gust",function()
		assert(Ambient.RustleId==nil,"the rustle is off since beta (12) QA S1")
		local a=ambient({on=function()return true end,gust=function()return 1 end});a:setRound(false);run(a,60)
		assert(a.rustleVoice==nil,"a voice was made");a:destroy()
	end)

	test("rustle: 0 to .10 with the gust, one voice in the ambience group, stopped once it has been silent",function()withId(function()
		local w={is=true,level=0};local a=ambient({on=function()return w.is end,gust=function()return w.level end})
		a:setRound(false);run(a,30)
		local real=a.rustleVoice
		assert(real and real.SoundGroup==a.ambience and real.Looped and real.Volume==0 and not real.IsPlaying,"voice")
		local v=voice();a.rustleVoice=v;real:Destroy()
		run(a,60);assert(v.plays==0,"plays in a lull")
		w.level=1;local last=0
		for _=1,60 do run(a,1);assert(v.Volume>=last and v.Volume-last<=Ambient.RustleSlew/30+1e-9);last=v.Volume end
		assert(v.IsPlaying and v.plays==1 and math.abs(v.Volume-.1)<1e-9,"peak "..v.Volume)
		for _,bad in ipairs({7,0/0,"x"})do w.level=bad;run(a,5);assert(v.Volume<=.1 and v.Volume>=0)end
		w.level=1;run(a,60);w.level=0;run(a,10);assert(v.Volume==0 and v.IsPlaying,"it lingers a moment")
		run(a,math.ceil(Ambient.RustleHold*30)+2);assert(not v.IsPlaying and v.stops==1,"still playing silence")
		run(a,300);assert(v.stops==1 and v.plays==1)
		a:destroy();assert(v.gone,"destroyed with Ambient")
	end)end)

	test("rustle: rounds, the Ambience setting, the feature switch and an unloaded asset are silent",function()withId(function()
		local w={is=true,level=1};local a,audio=ambient({on=function()return w.is end,gust=function()return w.level end})
		a:setRound(false);run(a,10);local v=voice();a.rustleVoice:Destroy();a.rustleVoice=v;run(a,40);assert(v.IsPlaying)
		a:setRound(true);run(a,30);assert(not v.IsPlaying and v.Volume==0,"round");run(a,60);assert(not v.IsPlaying)
		a:setRound(false);run(a,60);assert(v.IsPlaying,"back after the round")
		a:setLevel(0);run(a,2);assert(not v.IsPlaying and v.Volume==0,"Ambience off")
		a:setLevel(.5);run(a,30);assert(v.IsPlaying and math.abs(a.ambience.Volume-.5)<1e-6,"Soft is the group's own level")
		audio.master=0;run(a,2);assert(not v.IsPlaying,"muted");audio.master=1;run(a,30);assert(v.IsPlaying)
		w.is=false;run(a,1);assert(not v.IsPlaying and v.Volume==0,"feature off");w.is=true
		v.IsLoaded=false;run(a,60);assert(not v.IsPlaying,"an unloaded asset played")
		a:destroy()
	end)end)

	test("rustle: no id, no wind, and a wind that throws make no voice and break nothing",function()
		local id=1
		local done,problem=pcall(function()
			Ambient.RustleId=nil
			local a=ambient({on=function()return true end,gust=function()return 1 end});a:setRound(false);run(a,60);assert(a.rustleVoice==nil);a:destroy()
			Ambient.RustleId=id
			a=ambient({on=function()return false end,gust=function()return 1 end});a:setRound(false);run(a,60);assert(a.rustleVoice==nil,"off made a voice");a:destroy()
			a=ambient(false);a:setRound(false);run(a,60);assert(a.rustleVoice==nil and a.wind==nil);a:destroy()
			a=ambient({on=function()return true end,gust=function()error("broken")end});a:setRound(false);run(a,60)
			assert(a.wind==nil and a.ambience.Volume>.99 and(a.rustleVoice==nil or not a.rustleVoice.IsPlaying));a:destroy()
		end)
		Ambient.RustleId=shipped;assert(done,problem)
		for _,known in pairs(Ambient.Ids)do assert(known~=Ambient.RustleId,"the rustle is never in the warm set")end
	end)

	end)
	for _,item in ipairs(live)do pcall(function()item:destroy()end)end
	holder:Destroy();Ambient.shared=shared
	assert(ok,err)
	return{passed=#cases,cases=cases}
end
