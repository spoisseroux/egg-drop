-- Drift balloons (GARDEN-PLAY-BRIEF-2 2026-11-26 section 6; the module keeps the lanterns' name): every balloon and
-- the seed fluff against the garden's keep-outs (GardenClearance, air: off the paths, water, blocked ground, parks and
-- Dash, its whole drift circle), 13 to 25 studs over the ground through its bob and a burn's lift at its own height
-- and at the mascots' 14, the basket never under 9.5; three groups of three, three of each accent; the switch; the
-- night look, the burn and the flicker; the session's mascots (one per group, an imp and a cherub at least, roster
-- pets only); and DriftLanternsClient on fakes (nothing built with the switch off; 13 parts a balloon that never
-- collide, query or touch; day and night; the burn and its sound; the mascots in their baskets, their looks, the wave,
-- turn, hop and squeak, the halo; Reduced Motion still; asleep when nothing is near).
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.DriftLanterns)(PlayerScripts.Client)
-- Offline: python scripts/run_dash_server_specs.py
return function(client,offline)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Lanterns=require(Shared.DriftLanterns)
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
	local M=Lanterns.Motion
	local B=Lanterns.Burn

	test("every balloon: off the hub paving and the hatch tree's crown; the low pair on island ground under its whole drift, off the paths, water, blocked ground, parks, Dash and tree crowns; each in its layer's band over the ground (the low pair at a mascot's 14 too)",function()
		local bad={}
		for _,p in ipairs(Lanterns.Places)do
			local _,bottom=Lanterns.extent(p)
			local L=Lanterns.motion(p)
			local clash=Lanterns.layerClash(p)
			if clash then table.insert(bad,string.format("%s (%.1f, %.1f): %s",p.id,p.x,p.z,clash))end
			if p.layer=="low"then
				local ok,why=Clear.check(p.x,p.z,Lanterns.reach(p),true)
				if not ok then table.insert(bad,string.format("%s (%.1f, %.1f): %s",p.id,p.x,p.z,why))end
				-- Fable B35: 20 studs off the hatch tree's crown, 9 off any other (its spot); B38: the low two only.
				local crown=Lanterns.crownClash(p.x,p.z)
				if crown then table.insert(bad,string.format("%s (%.1f, %.1f): near %s",p.id,p.x,p.z,crown))end
			end
			-- Its centre within its layer's band through its bob and a burn's lift (none for the high pair), anywhere on
			-- its drift, at its own height and (the low pair) at the mascots'; the basket's bottom never under 9.5.
			local lift=if Lanterns.far(p)then 0 else B.lift
			for _,mascot in ipairs(if p.mascot then {false,true}else {false})do
				local y=Lanterns.groundAt(p,World)+Lanterns.over(p,mascot)
				for k=0,15 do
					local a=k*math.pi/8
					local x,z=p.x+math.cos(a)*L.drift,p.z+math.sin(a)*L.drift
					local g=Lanterns.groundAt(p,World,x,z)
					local low,high=y-L.bob-g,y+L.bob+lift-g
					if low<L.minOver or high>L.maxOver or high>Lanterns.MaxOver or low-bottom<Lanterns.LowestOver then
						table.insert(bad,string.format("%s%s: centre %.1f to %.1f, basket %.1f over the ground at its drift",p.id,
							if mascot then " (mascot)"else "",low,high,low-bottom))
						break
					end
				end
			end
		end
		local f=Lanterns.Fluff
		local ok,why=Clear.check(f.x,f.z,f.radius,true)
		if not ok then table.insert(bad,"the fluff: "..why)end
		assert(#bad==0,table.concat(bad,"; "))
	end)

	test("seven in three depths (two low with the mascots, three mid, two high), every accent used and never the same on neighbours, ids unique; 13 parts each; the budget and the switch (AliveAir, beta and Studio)",function()
		local layers,accents,ids={}, {}, {}
		for _,p in ipairs(Lanterns.Places)do
			layers[p.layer]=(layers[p.layer]or 0)+1
			accents[p.accent]=(accents[p.accent]or 0)+1
			assert(not ids[p.id],p.id);ids[p.id]=true
			assert(Lanterns.Layers[p.layer],p.id)
			-- The mascots ride only the low pair; the high pair is skyline (greyer, far, scale 1.8).
			assert((p.mascot==true)==(p.layer=="low"),p.id.." mascot")
			assert(p.scale==({low=1,mid=1.25,high=1.8})[p.layer],p.id.." scale")
			assert(Lanterns.far(p)==(p.layer=="high"),p.id.." far")
		end
		assert(#Lanterns.Places==7 and layers.low==2 and layers.mid==3 and layers.high==2)
		assert(accents[1]>=2 and accents[2]>=2 and accents[3]>=2 and #Lanterns.Look.accents==3)
		-- Never the same accent on neighbours: each one's nearest, and every pair within 50 studs.
		for i,p in ipairs(Lanterns.Places)do
			local best,bestD=nil,math.huge
			for j,q in ipairs(Lanterns.Places)do
				if i~=j then
					local d=Vector2.new(p.x-q.x,p.z-q.z).Magnitude
					if d<bestD then best,bestD=q,d end
					assert(d>=50 or p.accent~=q.accent,p.id.." and "..q.id.." share an accent")
				end
			end
			assert(best.accent~=p.accent,p.id.." and its neighbour "..best.id)
		end
		-- The layers' drift speeds (Fable): .25, .45, .55 studs/s; far slower to the eye, further in studs.
		for name,speed in pairs({low=.25,mid=.45,high=.55})do
			local L=Lanterns.Layers[name]
			assert(math.abs(2*math.pi*L.drift/L.driftPeriod-speed)<.01,name.." speed")
		end
		assert(Lanterns.MaxOver==100 and Lanterns.envelopeColour(Lanterns.Places[7])=="#EDE6D6"
			and Lanterns.envelopeColour(Lanterns.Places[1])==Lanterns.Look.envelopeColour,"the haze")
		assert(Lanterns.cullFor(Lanterns.Places[7],true)==Lanterns.FarCull and Lanterns.cullFor(Lanterns.Places[1],true)==90
			and Lanterns.cullFor(Lanterns.Places[3],false)==150,"the high pair is exempt from the phone cull")
		assert(Lanterns.layerClash({id="x",layer="mid",scale=1.25,x=-30,z=12})~=nil,"over the paving")
		assert(Lanterns.layerClash({id="x",layer="high",scale=1.8,x=-36,z=-30})~=nil,"over the hatch tree")
		-- Fable section 6: envelope, 4 gores, skirt, 4 ropes, basket, rim, flame = 13; 91 in all, plus fluff and sound.
		assert(Lanterns.PartsEach==13 and Lanterns.Look.gores==4,"13 a balloon")
		assert(Lanterns.partCount()==7*13+2 and Lanterns.Lights.count==4 and Lanterns.Mascot.count==2)
		assert(near(Lanterns.SkirtBottom,-1.85)and near(Lanterns.BasketTop,-2.85)and near(Lanterns.BasketBottom,-3.55))
		assert(Lanterns.Look.flameY<Lanterns.SkirtBottom and Lanterns.Look.flameY>Lanterns.BasketTop,"the flame under the skirt")
		assert(Lanterns.crownClash(-36.1,-3)~=nil and Lanterns.crownClash(-37.6,7.8)==nil,"the hatch tree's 20")
		assert(Lanterns.crownClash(37.67,15)~=nil and Lanterns.crownClash(47,13)==nil,"another crown's 9")
		assert(table.find(Alive.Features,"air")and Flags.AliveAir==true)
		assert(Alive.ceiling("air",{AliveAir=true},Alive.PlaceId,false)==true)
		assert(Alive.ceiling("air",{AliveAir=true},96451847774961,false)==false,"never on live")
		assert(Alive.resolve("air",nil,nil,true)==true,"missing = on")
	end)

	test("the night follows the lamps' rule (under .3); the burn grows 1.6x and lifts .4; the flicker is 15%; fluff over .7; the nearest picks; the drift stays on its circle",function()
		assert(Lanterns.glow(1)==0 and Lanterns.glow(.3)==0 and Lanterns.glow(nil)==0)
		assert(Lanterns.glow(.29)>0 and Lanterns.glow(.05)==1 and Lanterns.glow(.1)<1 and Lanterns.lit(.29)and not Lanterns.lit(.3))
		local day,night=Lanterns.lookAt(0),Lanterns.lookAt(1)
		assert(near(day.flameClear,.55)and near(day.light,.5)and near(night.flameClear,0)and near(night.light,.8))
		local cream,warm=Color3.fromHex("#F6EBD2"),Color3.fromHex("#FFD98A")
		assert(near(day.envelope.B,cream.B,1e-6)and near(night.envelope.B,cream.B+(warm.B-cream.B)*.35,1e-6),"the envelope warms")
		-- The burn: nothing before, 1.6x in the middle of its .8 s, back to 1 after; the lift up .4 and settled by 2.4 s.
		local g0,l0=Lanterns.burn(-1)
		assert(g0==1 and l0==0)
		local gm=Lanterns.burn(.4)
		assert(near(gm,1.6,1e-6),"1.6x")
		local ge=Lanterns.burn(.85)
		assert(ge==1,"over")
		local _,lt=Lanterns.burn(1.2)
		assert(near(lt,.4,1e-6),"lifts .4")
		local ga,la=Lanterns.burn(3)
		assert(ga==1 and la==0,"settled")
		-- The flicker: within 15%, and it moves.
		local seen,lo,hi={},math.huge,-math.huge
		for k=0,200 do
			local f=Lanterns.flicker(k/97,.3)
			lo,hi=math.min(lo,f),math.max(hi,f)
			seen[math.floor(f*100)]=true
		end
		assert(lo>=1-.15-1e-9 and hi<=1+.15+1e-9 and hi-lo>.15,"15%")
		assert(Lanterns.fluff(.71)and not Lanterns.fluff(.7)and not Lanterns.fluff(nil))
		local pts={Vector3.new(10,0,0),Vector3.new(1,0,0),Vector3.new(5,0,0),Vector3.new(2,0,0)}
		local n=Lanterns.nearest(pts,Vector3.zero,3)
		assert(n[1]==2 and n[2]==4 and n[3]==3 and #n==3)
		for i,p in ipairs(Lanterns.Places)do
			for t=0,40,3.3 do assert(near(Lanterns.drift(i,t).Magnitude,Lanterns.motion(p).drift,1e-9))end
		end
		assert(Lanterns.drift(1,0)~=Lanterns.drift(2,0),"own phases")
		local random=Random.new(7)
		for _=1,50 do
			local g=Lanterns.burnGap(random);assert(g>=6 and g<=10)
			local l=Lanterns.lookGap(random);assert(l>=4 and l<=7)
		end
	end)

	test("the mascots: two a session, one in each low balloon, an imp and a cherub, roster pets only, horns or wings and a palette; the wave's rule and hop",function()
		local roster={"pip","blip"}
		local seenPlaces,firstKinds={}, {}
		for seed=1,40 do
			local picks=Lanterns.pickMascots(Random.new(seed),roster)
			assert(#picks==2,"two")
			local places,kinds={}, {}
			for _,pick in ipairs(picks)do
				local p=Lanterns.Places[pick.place]
				assert(p and p.layer=="low"and not places[pick.place],"one per low balloon")
				places[pick.place]=true
				kinds[pick.kind]=(kinds[pick.kind]or 0)+1
				assert(table.find(roster,pick.petId),"a roster pet")
				local a=pick.appearance
				assert(a.toyId=="none"and a.charmVisible==false and type(a.featureStages)=="table")
				if pick.kind=="imp"then
					assert(a.featureStages.horns>0 and a.featureStages.wings==0,"imp: horns")
					assert(a.body or a.bodyMix,"imp: a warm palette")
				else
					assert(pick.kind=="cherub"and a.featureStages.wings>0 and a.featureStages.horns==0,"cherub: wings")
				end
				seenPlaces[pick.place]=true
			end
			assert(kinds.imp==1 and kinds.cherub==1,"both kinds")
			firstKinds[picks[1].kind]=true
		end
		local n=0;for _ in pairs(seenPlaces)do n+=1 end
		assert(n==2,"the low pair carry them ("..n..")")
		assert(firstKinds.imp and firstKinds.cherub,"which carries which varies by session")
		assert(#Lanterns.pickMascots(Random.new(1),{})==0,"no roster: none")
		-- The same seed, the same session.
		local a,b=Lanterns.pickMascots(Random.new(5),roster),Lanterns.pickMascots(Random.new(5),roster)
		for i=1,2 do assert(a[i].place==b[i].place and a[i].kind==b[i].kind and a[i].petId==b[i].petId)end
		-- Beats: a look mostly, an emote now and then, never a sit or a wave.
		local random=Random.new(3)
		local looks,emotes=0,0
		for _=1,400 do
			local kind=Lanterns.pickBeat(random,1)
			assert(kind~="sit"and kind~="wave",kind)
			if kind=="look"then looks+=1 else emotes+=1;assert(Lanterns.Emotes.day[kind],kind)end
		end
		assert(looks>emotes and emotes>50,"mostly looks")
		for _=1,100 do local kind=Lanterns.pickBeat(random,.1);assert(kind=="look"or Lanterns.Emotes.night[kind],kind)end
		-- The wave: within 35, at most every 10 s.
		assert(Lanterns.shouldWave(30,100,nil)and not Lanterns.shouldWave(36,100,nil)and not Lanterns.shouldWave(nil,100,nil))
		assert(not Lanterns.shouldWave(10,105,100)and Lanterns.shouldWave(10,110,100))
		-- The hop after the 1.2 s wave.
		assert(Lanterns.hop(nil)==0 and Lanterns.hop(.5)==0 and Lanterns.hop(1.2+.5)==0)
		assert(near(Lanterns.hop(1.2+.225),.22,1e-6),"hops .22")
	end)

	-- The client on fakes ---------------------------------------------------------------------------------------------
	local function rig(opts)
		opts=opts or {}
		local changed=signal()
		local on=opts.on~=false
		local now=50
		local r={daylight=opts.daylight or 1,reduced=opts.reduced==true,visuals={},sounds={},cheers=0}
		local first=Lanterns.Places[1]
		r.camera=Vector3.new(first.x,10,first.z+12)
		r.listener=Vector3.new(400,0,400)
		local parent=Instance.new("Folder");parent.Name="BalloonSpec";parent.Parent=workspace
		r.parent=parent
		r.air=require(client.DriftLanternsClient).mount({
			alive={ceiling=function()return true end,on=function(name)return name=="air"and on end,changed=function()return changed end},
			parent=parent,heartbeat=false,now=function()return now end,seed=opts.seed or 11,
			daylight=function()return r.daylight end,camera=function()return r.camera end,listener=function()return r.listener end,
			mode=function()return "Room"end,reduced=function()return r.reduced end,phone=function()return false end,
			move=function(parts,frames)for i,p in ipairs(parts)do p.CFrame=frames[i]end end,
			roster=function()return{"pip","blip"}end,
			mascot=function(where,origin,petId,appearance)
				local model=Instance.new("Model");model.Name=petId;model.Parent=where
				local head=Instance.new("Part");head.Name="Head";head.Size=Vector3.new(.8,.6,.6);head.CanQuery=true;head.Parent=model
				local v={model=model,origin=origin,yaw=0,scale=.625,definition={anchors={HandR={.2,.655,.06}}},
					pieces={{name="Head",part=head}},greets=0,updates=0,petId=petId,appearance=appearance}
				function v:update()self.updates+=1;head.CFrame=CFrame.new(self.origin+Vector3.new(0,.8,0))end
				function v:greet()self.greets+=1 end
				function v:destroy()self.destroyed=true;model:Destroy()end
				table.insert(r.visuals,v)
				return v
			end,
			cheer=function()r.cheers+=1 end,
			play=function(cue,position,volume,speed)table.insert(r.sounds,{cue=cue,position=position,volume=volume,speed=speed,at=now})end,
			worldVersion="v7"})
		function r.set(value)on=value;changed:Fire()end
		function r.tick(seconds)
			local steps=math.max(1,math.floor((seconds or .05)/.05+.5))
			for _=1,steps do now+=.05;r.air:step(.05)end
		end
		function r.now()return now end
		function r.done()r.air:destroy();parent:Destroy()end
		return r
	end

	test("the client: nothing with the switch off; on: 13 parts a balloon (the mid and high drawn larger, the high greyer), two mascots in the low baskets, a halo a cherub, nothing collides, queries or touches; four lights, one emitter",function()
		local r=rig({on=false})
		local ok,err=pcall(function()
			assert(r.air and r.air.built==false and r.parent:FindFirstChild("DriftLanternsLocal")==nil,"off: nothing")
			r.set(true)
			local folder=r.parent:FindFirstChild("DriftLanternsLocal")
			assert(folder,"built")
			local cherubs=0
			for _,m in ipairs(r.air.mascots)do if m.kind=="cherub"then cherubs+=1;assert(m.halo,"a halo")else assert(m.halo==nil,"no halo")end end
			local parts,lights,emitters,sounds=0,0,0,0
			for _,item in ipairs(folder:GetDescendants())do
				if item.ClassName=="Part"then
					parts+=1
					assert(item.Anchored and not item.CanCollide and not item.CanQuery and not item.CanTouch,item.Name)
				elseif item.ClassName=="PointLight"then lights+=1
				elseif item.ClassName=="ParticleEmitter"then emitters+=1
				elseif item.ClassName=="Sound"then sounds+=1 end
			end
			assert(#r.visuals==2 and #r.air.mascots==2,"two mascots")
			assert(parts==Lanterns.partCount()+cherubs+2,"parts "..parts)
			assert(folder:GetAttribute("AirParts")==Lanterns.partCount()+cherubs and folder:GetAttribute("AirMascots")==2)
			assert(lights==4 and emitters==1 and sounds==3)
			for _,l in ipairs(r.air.lanterns)do
				assert(#l.pieces==13,l.place.id)
				assert(near(l.envelope.Size.X,Lanterns.Look.envelope*l.place.scale,1e-6),l.place.id.." scaled")
				assert((l.mascot~=nil)==(l.place.layer=="low"),l.place.id.." mascot")
				local basket=l.pieces[11]
				assert(near((l.rest:Inverse()*basket.CFrame).Position.Y,(Lanterns.BasketTop-Lanterns.Look.basket.Y/2)*l.place.scale,1e-4),l.place.id.." basket")
				if l.place.layer=="high"then
					assert(near(l.envelope.Color.G,Color3.fromHex("#EDE6D6").G,1e-6),"the haze")
					assert(l.nextBurn==math.huge,"no burn")
				end
				for _,p in ipairs(l.pieces)do assert(p.Material~=Enum.Material.Fabric,p.Name)end
				assert(l.flame.Material==Enum.Material.Neon and l.envelope.Material==Enum.Material.SmoothPlastic)
				-- A mascot's balloon hangs at 14.
				local over=l.rest.Position.Y-World.groundY(l.place.x,l.place.z)
				over=l.rest.Position.Y-Lanterns.groundAt(l.place,World)
				assert(near(over,if l.mascot then 14 else l.place.over,1e-6),l.place.id.." over "..over)
			end
			for _,m in ipairs(r.air.mascots)do
				local v=m.visual
				assert(v.model.Name=="mascot_"..m.lantern.place.id and v.model:GetAttribute("MascotKind")==m.kind)
				assert(v.parkPose==true and v.idleBeatsEnabled==true,"its feet ride the basket; beats from here")
				-- The paws (hand anchor) .08 over the rim, at rest.
				local rim=(m.lantern.rest*CFrame.new(0,Lanterns.BasketTop,0)).Position
				local paws=v.origin.Y+.655*.625
				assert(near(paws-rim.Y,Lanterns.Mascot.paws,1e-6),"paws over the rim")
				assert(near(v.origin.X,rim.X,1e-6)and near(v.origin.Z,rim.Z,1e-6),"in the basket")
			end
			r.set(false)
			assert(r.parent:FindFirstChild("DriftLanternsLocal")==nil,"taken down")
			for _,v in ipairs(r.visuals)do assert(v.destroyed,"mascot destroyed")end
		end)
		r.done();assert(ok,err)
	end)

	test("day: a pale flame, no lights, the fluff on; night: the flame up and flickering, the envelope warm, the four nearest lit and flickering",function()
		local r=rig({daylight=.9})
		local ok,err=pcall(function()
			r.tick(1)
			local l=r.air.lanterns[1]
			assert(near(r.air.lanterns[2].envelope.Color.B,Color3.fromHex("#F6EBD2").B,1e-6),"day cream")
			for _,light in ipairs(r.air.lights)do assert(light.Enabled==false)end
			assert(r.air.emitter.Enabled==true,"fluff by day")
			r.daylight=.5;r.tick(1)
			assert(r.air.emitter.Enabled==false,"dusk: no fluff")
			r.daylight=.02;r.tick(1)
			local warm=Color3.fromHex("#F6EBD2").B+(Color3.fromHex("#FFD98A").B-Color3.fromHex("#F6EBD2").B)*.35
			assert(near(l.envelope.Color.B,warm,1e-6),"warm")
			local hosts={}
			for _,light in ipairs(r.air.lights)do
				assert(light.Enabled==true and near(light.Range,12))
				assert(light.Brightness>=.8*.85-1e-6 and light.Brightness<=.8*1.15+1e-6,"flickering about .8")
				hosts[light.Parent]=true
			end
			local n=0;for _ in pairs(hosts)do n+=1 end
			assert(n==4,"four balloons")
			-- The two low and the nearest mid carry them; the skyline pair never does.
			for i=1,2 do assert(hosts[r.air.lanterns[i].flame],"low "..i)end
			for _,f in ipairs(r.air.lanterns)do if f.place.layer=="high"then assert(not hosts[f.flame],"no light far")end end
			-- The flicker moves the flame (outside a burn) and the lights.
			local sizes,brights={}, {}
			for _=1,30 do
				r.tick(.05)
				sizes[math.floor(l.flame.Size.X*1000)]=true
				brights[math.floor(r.air.lights[1].Brightness*1000)]=true
			end
			local a,b=0,0;for _ in pairs(sizes)do a+=1 end;for _ in pairs(brights)do b+=1 end
			assert(a>5 and b>5,"it flickers")
			-- Reduced Motion: a steady flame.
			r.reduced=true;r.tick(1)
			local steady=l.flame.Size.X
			r.tick(1)
			assert(l.flame.Size.X==steady and near(steady,Lanterns.Look.flame,1e-6),"steady")
			r.reduced=false
			r.daylight=.9;r.tick(1)
			assert(r.air.lights[1].Enabled==false,"back to day")
		end)
		r.done();assert(ok,err)
	end)

	test("motion: it bobs, drifts and sways inside its circle, burns every 6 to 10 s (grows, lifts, exhales within 30); Reduced Motion holds it still but it still sounds; nothing near: asleep",function()
		local r=rig()
		local ok,err=pcall(function()
			local l=r.air.lanterns[1]
			local p=Lanterns.Places[1]
			local rest=l.rest.Position
			r.listener=rest-Vector3.new(0,10,0)
			local seen,grew,burns={},0,0
			for _=1,240 do
				r.tick(.05)
				local at=l.envelope.CFrame.Position
				assert(Vector2.new(at.X-p.x,at.Z-p.z).Magnitude<=M.drift+.3,"inside its circle")
				assert(at.Y-rest.Y<=M.bob+B.lift+.2 and rest.Y-at.Y<=M.bob+.2,"its bob and lift")
				seen[math.floor(at.X*10)]=true
				grew=math.max(grew,l.flame.Size.X/Lanterns.Look.flame)
			end
			for _,s in ipairs(r.sounds)do
				if s.cue=="asmr_exhale_a"or s.cue=="asmr_exhale_b"then
					burns+=1
					assert(s.volume==.35 and s.speed>=.7*.94 and s.speed<=.7*1.06,"pitched .7")
					assert((s.position-r.listener).Magnitude<=30,"within 30")
				end
				assert(s.cue~="burner_whoosh_a"and s.cue~="burner_whoosh_b","no id yet: never played")
			end
			local n=0;for _ in pairs(seen)do n+=1 end
			assert(n>5,"it moves")
			assert(grew>1.5,"a burn grows the flame ("..grew..")")
			assert(burns>=1,"a burn exhales")
			-- Reduced Motion: still, no growth, but the burns still sound.
			r.reduced=true;r.tick(.1)
			local still=l.envelope.CFrame.Position
			local before=#r.sounds
			r.tick(12)
			assert(l.envelope.CFrame.Position==still,"still under Reduced Motion")
			assert(near(l.flame.Size.X,Lanterns.Look.flame,1e-6),"no growth")
			assert(#r.sounds>before,"sounds stay")
			assert(r.air.emitter.Enabled==false,"no fluff under Reduced Motion")
			r.reduced=false
			r.camera=Vector3.new(400,50,400);r.tick(.1)
			assert(r.air.awake==false,"asleep with nothing near")
		end)
		r.done();assert(ok,err)
	end)

	test("the skyline pair: past every other balloon's cull it still drifts (at 1/10 s) on its wide, slow circle, never burns or sounds",function()
		local r=rig()
		local ok,err=pcall(function()
			local far,low
			for _,l in ipairs(r.air.lanterns)do
				if l.place.id=="high_falls"then far=l elseif l.place.id=="low_fountain"then low=l end
			end
			r.camera=far.rest.Position+Vector3.new(0,0,250)
			r.listener=far.rest.Position
			r.tick(.2)
			assert(r.air.awake==true,"awake for the skyline")
			local farAt,lowAt=far.envelope.CFrame.Position,low.envelope.CFrame.Position
			local moves,before=0,#r.sounds
			for _=1,60 do
				local was=far.envelope.CFrame.Position
				r.tick(.05)
				if far.envelope.CFrame.Position~=was then moves+=1 end
			end
			assert(far.envelope.CFrame.Position~=farAt,"it drifts")
			assert(moves>=8 and moves<=40,"about ten steps a second ("..moves..")")
			assert(low.envelope.CFrame.Position==lowAt,"the low ones past their cull stay still")
			assert(#r.sounds==before and far.flame.Size.X>=Lanterns.Look.flame*1.8-1e-6,"no burn, no sound")
		end)
		r.done();assert(ok,err)
	end)

	test("mascots: ride the basket, look about every 4 to 7 s; the player within 35: turn, wave, hop, squeak within 25, again only after 10 s; cherub's halo over the head; Reduced Motion: still, the squeak stays",function()
		local r=rig()
		local ok,err=pcall(function()
			local m=r.air.mascots[1]
			local v=m.visual
			-- This mascot's squeaks (the others may squeak too when I am near them).
			local function squeaks()
				local n=0
				for _,s in ipairs(r.sounds)do
					if s.cue=="snack_happy_squeak"then
						local owner,best=nil,math.huge
						for _,o in ipairs(r.air.mascots)do
							local d=(s.position-o.visual.origin).Magnitude
							if d<best then owner,best=o,d end
						end
						if owner==m then n+=1;assert(s.volume==.3)end
					end
				end
				return n
			end
			local l=m.lantern
			r.camera=l.rest.Position+Vector3.new(0,-10,8)
			-- Looks: within 7 s a beat starts, and they keep coming; never a sit.
			local beats,kinds=0,{}
			local last=nil
			for _=1,400 do
				r.tick(.05)
				local s=v.idleBeat
				if s and s.kind and s.age==0 then beats+=1;kinds[s.kind]=true;assert(s.kind~="sit")end
				if s and s.kind then last=s.kind end
				-- Its feet ride the basket through the drift and bob.
				local base=l.base or l.rest
				local want=(base*CFrame.new(0,m.footY,0)).Position
				assert((v.origin-want).Magnitude<1e-6,"rides the basket")
			end
			assert(beats>=3 and kinds.look,"looks about ("..beats..")")
			assert(v.greets==0,"no player near: no wave")
			-- The player comes within 35 (and 25): a wave, a turn, a hop and a squeak.
			local offset=Vector3.new(9,-8,0)
			r.listener=v.origin+offset
			r.tick(.05)
			assert(v.greets==1,"waves")
			assert(squeaks()==1,"a squeak")
			local top=0
			for _=1,40 do
				r.listener=v.origin+offset
				r.tick(.05)
				local base=l.base or l.rest
				top=math.max(top,v.origin.Y-(base*CFrame.new(0,m.footY,0)).Position.Y)
			end
			assert(top>.15,"hops ("..top..")")
			assert(r.cheers==1,"the pleased face on the hop")
			assert(math.abs(math.atan2(math.sin(v.yaw-math.pi/2),math.cos(v.yaw-math.pi/2)))<.05,"turned to me ("..v.yaw..")")
			-- Not again inside 10 s; again after.
			for _=1,100 do r.listener=v.origin+offset;r.tick(.05)end
			assert(v.greets==1,"at most every 10 s")
			for _=1,120 do r.listener=v.origin+offset;r.tick(.05)end
			assert(v.greets==2,"again after 10 s")
			-- Out of 25 but within 35: a wave without the squeak.
			local before=squeaks()
			for _=1,220 do r.listener=v.origin+Vector3.new(30,0,0);r.tick(.05)end
			local after=squeaks()
			assert(v.greets==3 and after==before,"no squeak past 25 "..v.greets.." "..before.." "..after)
			-- The halo sits .25 (+/- .05) over a cherub's head.
			for _,c in ipairs(r.air.mascots)do
				if c.halo then
					local head=c.visual.pieces[1].part
					local gap=c.halo.CFrame.Position.Y-(head.CFrame.Position.Y+head.Size.Y/2)
					assert(gap>=.25-.05-1e-6 and gap<=.25+.05+1e-6,"halo .25 over ("..gap..")")
				end
			end
			-- Reduced Motion: no turn, no hop, no greet, no beats; the squeak stays.
			r.reduced=true
			r.listener=Vector3.new(400,0,400);r.tick(.5)
			local yaw,origin,updates=v.yaw,v.origin,v.updates
			local squeaksBefore=squeaks()
			for _=1,240 do r.listener=v.origin+offset;r.tick(.05)end
			local squeaksAfter=squeaks()
			assert(v.yaw==yaw and v.origin==origin and v.updates==updates,"still")
			assert(v.greets==3,"no wave pose under Reduced Motion")
			assert(squeaksAfter>squeaksBefore,"the squeak stays")
			assert(v.reducedEffects==true)
		end)
		r.done();assert(ok,err)
	end)

	return{passed=#cases,cases=cases}
end
