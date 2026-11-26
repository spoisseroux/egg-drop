-- Drift lanterns (GARDEN-PLAY-BRIEF 2026-11-26 section 4): every lantern and the seed fluff against the garden's
-- keep-outs (GardenClearance, air: off the paths, water, blocked ground, parks and Dash, its whole drift circle), 14 to
-- 24 studs over the ground through its bob, three groups of three, three of each accent; the switch; the night glow;
-- and DriftLanternsClient on fakes (nothing built with the switch off; day matte, night warm with four lights on the
-- nearest; the fluff by day only; motion within its circle; Reduced Motion still; asleep when nothing is near).
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

	test("every lantern: island ground under its whole drift, off the paths, water, blocked ground, parks, Dash and tree crowns; 14 to 24 over the ground",function()
		local bad={}
		local _,bottom=Lanterns.extent()
		for _,p in ipairs(Lanterns.Places)do
			local ok,why=Clear.check(p.x,p.z,Lanterns.reach(),true)
			if not ok then table.insert(bad,string.format("%s (%.1f, %.1f): %s",p.id,p.x,p.z,why))end
			-- Fable B35: 20 studs off the hatch tree's crown, 9 off any other (its spot).
			local crown=Lanterns.crownClash(p.x,p.z)
			if crown then table.insert(bad,string.format("%s (%.1f, %.1f): near %s",p.id,p.x,p.z,crown))end
			-- Its centre 14 to 24 over the ground through its bob, anywhere on its drift; the tassel's tip never under 12.
			local y=World.groundY(p.x,p.z)+p.over
			for k=0,15 do
				local a=k*math.pi/8
				local x,z=p.x+math.cos(a)*M.drift,p.z+math.sin(a)*M.drift
				local g=World.groundY(x,z)
				if y-M.bob-g<Lanterns.MinOver or y+M.bob-g>Lanterns.MaxOver or y-M.bob-bottom-g<Lanterns.LowestOver then
					table.insert(bad,string.format("%s: centre %.1f to %.1f over the ground at its drift",p.id,y-M.bob-g,y+M.bob-g))
					break
				end
			end
		end
		local f=Lanterns.Fluff
		local ok,why=Clear.check(f.x,f.z,f.radius,true)
		if not ok then table.insert(bad,"the fluff: "..why)end
		assert(#bad==0,table.concat(bad,"; "))
	end)

	test("nine: three groups of three, three of each accent, ids unique; the budget and the switch (AliveAir, beta and Studio)",function()
		local groups,accents,ids={}, {}, {}
		for _,p in ipairs(Lanterns.Places)do
			groups[p.group]=(groups[p.group]or 0)+1
			accents[p.accent]=(accents[p.accent]or 0)+1
			assert(not ids[p.id],p.id);ids[p.id]=true
		end
		assert(#Lanterns.Places==9 and groups.hub==3 and groups.bridge==3 and groups.fountain==3)
		assert(accents[1]==3 and accents[2]==3 and accents[3]==3 and #Lanterns.Look.accents==3)
		assert(Lanterns.partCount()==9*8+1 and Lanterns.Lights.count==4)
		-- Fable B35: a globe, a core, three ribs, two caps, a tassel; full glow at daylight .05.
		assert(Lanterns.PartsEach==8 and #Lanterns.Look.ribs==3 and Lanterns.GlowSpan==.25)
		assert(Lanterns.crownClash(-36.1,-3)~=nil and Lanterns.crownClash(-37.6,7.8)==nil,"the hatch tree's 20")
		assert(Lanterns.crownClash(37.67,15)~=nil and Lanterns.crownClash(47,13)==nil,"another crown's 9")
		assert(table.find(Alive.Features,"air")and Flags.AliveAir==true)
		assert(Alive.ceiling("air",{AliveAir=true},Alive.PlaceId,false)==true)
		assert(Alive.ceiling("air",{AliveAir=true},96451847774961,false)==false,"never on live")
		assert(Alive.resolve("air",nil,nil,true)==true,"missing = on")
	end)

	test("the glow follows the lamps' rule (under .3); fluff over .7; the nearest picks; the drift stays on its circle",function()
		assert(Lanterns.glow(1)==0 and Lanterns.glow(.3)==0 and Lanterns.glow(nil)==0)
		assert(Lanterns.glow(.29)>0 and Lanterns.glow(.05)==1 and Lanterns.glow(.1)<1 and Lanterns.lit(.29)and not Lanterns.lit(.3))
		local day,night=Lanterns.lookAt(0),Lanterns.lookAt(1)
		assert(near(day.coreClear,.6)and near(day.paperClear,.25)and near(day.light,.5))
		assert(near(night.coreClear,0)and near(night.paperClear,.4)and near(night.light,.8))
		assert(near(night.paper.G,Color3.fromHex("#FFE6B0").G,1e-6)and near(day.core.G,Color3.fromHex("#F2C98A").G,1e-6))
		assert(Lanterns.fluff(.71)and not Lanterns.fluff(.7)and not Lanterns.fluff(nil))
		local pts={Vector3.new(10,0,0),Vector3.new(1,0,0),Vector3.new(5,0,0),Vector3.new(2,0,0)}
		local n=Lanterns.nearest(pts,Vector3.zero,3)
		assert(n[1]==2 and n[2]==4 and n[3]==3 and #n==3)
		for i=1,9 do
			for t=0,40,3.3 do assert(near(Lanterns.drift(i,t).Magnitude,M.drift,1e-9))end
		end
		assert(Lanterns.drift(1,0)~=Lanterns.drift(2,0),"own phases")
	end)

	-- The client on fakes ---------------------------------------------------------------------------------------------
	local function rig(opts)
		opts=opts or {}
		local changed=signal()
		local on=opts.on~=false
		local now=50
		local r={daylight=opts.daylight or 1,reduced=opts.reduced==true}
		local first=Lanterns.Places[1]
		r.camera=Vector3.new(first.x,10,first.z+12)
		local parent=Instance.new("Folder");parent.Name="LanternSpec";parent.Parent=workspace
		r.parent=parent
		r.air=require(client.DriftLanternsClient).mount({
			alive={ceiling=function()return true end,on=function(name)return name=="air"and on end,changed=function()return changed end},
			parent=parent,heartbeat=false,now=function()return now end,
			daylight=function()return r.daylight end,camera=function()return r.camera end,
			mode=function()return "Room"end,reduced=function()return r.reduced end,phone=function()return false end,
			move=function(parts,frames)for i,p in ipairs(parts)do p.CFrame=frames[i]end end,
			worldVersion="v7"})
		function r.set(value)on=value;changed:Fire()end
		function r.tick(seconds)
			local steps=math.max(1,math.floor((seconds or .05)/.05+.5))
			for _=1,steps do now+=.05;r.air:step(.05)end
		end
		function r.done()r.air:destroy();parent:Destroy()end
		return r
	end

	test("the client: nothing with the switch off; on: 73 parts that never collide, query or touch; four lights, one emitter",function()
		local r=rig({on=false})
		local ok,err=pcall(function()
			assert(r.air and r.air.built==false and r.parent:FindFirstChild("DriftLanternsLocal")==nil,"off: nothing")
			r.set(true)
			local folder=r.parent:FindFirstChild("DriftLanternsLocal")
			assert(folder,"built")
			local parts,lights,emitters=0,0,0
			for _,item in ipairs(folder:GetDescendants())do
				if item.ClassName=="Part"then
					parts+=1
					assert(item.Anchored and not item.CanCollide and not item.CanQuery and not item.CanTouch,item.Name)
				elseif item.ClassName=="PointLight"then lights+=1
				elseif item.ClassName=="ParticleEmitter"then emitters+=1 end
			end
			assert(parts==Lanterns.partCount(),"parts "..parts)
			assert(lights==4 and emitters==1)
			r.set(false)
			assert(r.parent:FindFirstChild("DriftLanternsLocal")==nil,"taken down")
		end)
		r.done();assert(ok,err)
	end)

	test("day: a warm heart, no lights, the fluff on; dusk: fluff off; night: core and paper warm, the four nearest lit",function()
		local r=rig({daylight=.9})
		local ok,err=pcall(function()
			r.tick(1)
			local l=r.air.lanterns[1]
			assert(l.globe.Material==Enum.Material.Cardboard and l.core.Material==Enum.Material.Neon,"no Fabric")
			for _,p in ipairs(l.pieces)do assert(p.Material~=Enum.Material.Fabric,p.Name)end
			assert(near(l.core.Transparency,.6)and near(l.globe.Transparency,.25),"day")
			assert(near(l.core.Color.G,Color3.fromHex("#F2C98A").G,1e-6))
			for _,light in ipairs(r.air.lights)do assert(light.Enabled==false)end
			assert(r.air.emitter.Enabled==true,"fluff by day")
			r.daylight=.5;r.tick(1)
			assert(r.air.emitter.Enabled==false and near(l.core.Transparency,.6),"dusk: no fluff, still day")
			r.daylight=.02;r.tick(1)
			assert(near(l.core.Transparency,0)and near(l.globe.Transparency,.4),"night")
			assert(near(l.core.Color.G,Color3.fromHex("#FFD98A").G,1e-6)and near(l.globe.Color.G,Color3.fromHex("#FFE6B0").G,1e-6),"warm")
			local hosts={}
			for _,light in ipairs(r.air.lights)do
				assert(light.Enabled==true and near(light.Range,12)and near(light.Brightness,.8))
				hosts[light.Parent]=true
			end
			-- The four nearest the camera (it is beside hub_1): every hub lantern's core carries one.
			local n=0;for _ in pairs(hosts)do n+=1 end
			assert(n==4,"four lanterns")
			for i=1,3 do assert(hosts[r.air.lanterns[i].core],"hub "..i)end
			r.daylight=.25;r.tick(1)
			assert(near(r.air.lights[1].Brightness,.5+.3*.2,1e-6),"ramping in")
			r.daylight=.9;r.tick(1)
			assert(near(l.core.Transparency,.6)and r.air.lights[1].Enabled==false,"back to day")
		end)
		r.done();assert(ok,err)
	end)

	test("motion: it bobs, drifts and sways inside its circle; Reduced Motion holds it still; nothing near: asleep",function()
		local r=rig()
		local ok,err=pcall(function()
			local l=r.air.lanterns[1]
			local p=Lanterns.Places[1]
			local rest=l.rest.Position
			local seen={}
			for _=1,40 do
				r.tick(.5)
				local at=l.core.CFrame.Position
				assert(Vector2.new(at.X-p.x,at.Z-p.z).Magnitude<=M.drift+.3,"inside its circle")
				assert(math.abs(at.Y-rest.Y)<=M.bob+.2,"its bob")
				seen[math.floor(at.X*10)]=true
			end
			local n=0;for _ in pairs(seen)do n+=1 end
			assert(n>5,"it moves")
			r.reduced=true;r.tick(.1)
			local still=l.core.CFrame.Position
			r.tick(3)
			assert(l.core.CFrame.Position==still,"still under Reduced Motion")
			assert(r.air.emitter.Enabled==false,"no fluff under Reduced Motion")
			r.reduced=false
			r.camera=Vector3.new(400,50,400);r.tick(.1)
			assert(r.air.awake==false,"asleep with nothing near")
		end)
		r.done();assert(ok,err)
	end)

	return{passed=#cases,cases=cases}
end
