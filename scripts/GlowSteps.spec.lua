-- Glow steps, the client side (ONBOARDING-V3-BRIEF section 2, switch Onboard "trail2"): GlowSteps' prints (nothing can
-- touch them, LightInfluence 0, only moving prints are written each frame, far ones rest, the Reduced Motion breath),
-- the target ring, a leading pet's prints (laid, `pat` stand-in at gain .12, two sparkles from one emitter, at most 12
-- parts), and how the two trails take the switch: ThingsTrail (a guide trail outlives Seconds and hides for a menu,
-- leadBy, off is as before) and PetTrail (glowOn, ends). The Studio pass covers the drawn look.
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.GlowSteps)(PlayerScripts.Client)
-- Offline: python scripts/run_dash_server_specs.py
return function(client)
	local Steps=require(client.GlowSteps)
	local Things=require(client.ThingsTrail)
	local Pet=require(client.PetTrail)
	local Glow=Steps.Glow
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function near(a,b,e)return math.abs(a-b)<=(e or 1e-6)end
	-- Counts property writes on one print's UIScale (the per-frame cost).
	local function counted(slot)
		local real=slot.scale
		local writes={n=0}
		slot.scale=setmetatable({},{__newindex=function(_,k,v)writes.n+=1;real[k]=v end,__index=real})
		return writes
	end

	test("prints: flat parts nothing can touch, lit by nothing (LightInfluence 0), placed and shown by count",function()
		local box=Instance.new("Folder")
		local steps=Steps.new({parent=box})
		for i=1,6 do steps:place(i,CFrame.new(Vector3.new(i*2,0,0)))end
		steps:show(4)
		for i,slot in ipairs(steps.route)do
			local p=slot.part
			assert(p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery and not p.CastShadow,"still")
			assert(slot.surface.LightInfluence==0 and slot.surface.Enabled==(i<=4))
			assert(near(p.Size.X,Glow.Size*Glow.Canvas),"spans the widest ripple")
		end
		steps:target(Vector3.new(9,0,0));assert(steps.ring.surface.Enabled and steps.ring.surface.LightInfluence==0)
		steps:target(nil);assert(not steps.ring.surface.Enabled)
		steps:destroy();assert(#steps.route==0)
	end)

	test("the wave: only prints in their swell are written; far from the camera they rest; Reduced Motion breathes rarely",function()
		local steps=Steps.new({parent=Instance.new("Folder")})
		for i=1,12 do steps:place(i,CFrame.new(Vector3.new(i*2.2,0,0)))end
		steps:show(12)
		local writes={}
		for i=1,12 do writes[i]=counted(steps.route[i])end
		steps:animate(Glow.Pulse/2,false,nil)
		assert(near(steps.route[1].size,1.35),"print 1 at its peak")
		assert(writes[5].n==0,"print 5 waits for the wave: not written")
		local total=0
		for t=0,1.2,1/60 do steps:animate(t,false,nil)end
		for i=1,12 do total+=writes[i].n end
		assert(total<=12*math.ceil((Glow.Pulse+.05)*60)+12,"a print is written only around its swell: "..total)
		-- A camera far off: everything at rest, nothing written.
		for i=1,12 do writes[i].n=0 end
		local camera={CFrame=CFrame.new(Vector3.new(0,0,500))}
		for t=0,1.2,1/60 do steps:animate(t,false,camera)end
		local far=0;for i=1,12 do far+=writes[i].n end
		assert(far<=12,"resting far away (one write each to settle): "..far)
		-- Reduced Motion: no swell, see-through breathing in steps.
		for t=0,2,1/60 do steps:animate(t,true,nil)end
		for i=1,12 do assert(steps.route[i].size==1)end
		steps:destroy()
	end)

	test("a leading pet: its prints pop in with a pat (the stand-in, gain .12), the player's steps pop them with 2 sparkles, at most 12",function()
		local played={}
		local steps=Steps.new({parent=Instance.new("Folder"),play=function(name,speed,gain)table.insert(played,{name,speed,gain})end})
		steps:place(1,CFrame.new(Vector3.new(1,0,0)));steps:show(1)
		steps:lead(true)
		assert(not steps.route[1].surface.Enabled,"the route's prints hide while a pet leads")
		local x=0
		local player=Vector3.new(-5,0,0)
		steps:leadStep(0,Vector3.new(x,3,0),player,false,function()return 0 end)
		for i=1,40 do
			x+=2.3
			steps:leadStep(i*.1,Vector3.new(x,3,0),player,false,function()return 0 end)
		end
		assert(#steps.leads==Glow.LeadMax,"never more than 12 parts")
		assert(#played>=10 and played[1][1]==Glow.PatCue.name and played[1][3]==.12)
		for _,slot in ipairs(steps.leads)do assert(near(slot.at.Y,.04),"on the ground under the pet, not at its pivot")end
		-- The player steps on one.
		local state=steps.leadState
		local on=nil
		for i,slot in ipairs(state.slots)do if slot.on and slot.gone==nil then on=i;break end end
		local spot=Vector3.new(state.slots[on].x,0,state.slots[on].z)
		steps:leadStep(5,Vector3.new(x,3,0),spot,false,nil)
		assert(steps.spark and steps.spark.emitter.emitted==Glow.Sparkles,"two sparkles from the one emitter")
		steps:lead(false)
		for _,slot in ipairs(steps.leads)do assert(not slot.surface.Enabled)end
		assert(steps.route[1].surface.Enabled,"the route's prints come back")
		steps:destroy()
	end)

	-- ThingsTrail with the switch on (its own rig, as ThingsTrail.spec's).
	local function V(x,z)return Vector3.new(x+20,4.5,z+66)end
	local function rig(glow)
		local r={at=V(0,0),open=true,menu=false}
		local deps={world=workspace,step=false,root=function()return r.at end,free=function()return r.open end,busy=function()return r.menu end,
			compute=function(a,b)return{a,b}end,reduced=function()return false end,spawn=function(fn)task.spawn(fn)end,
			glow=function()return glow end,groundUnder=function()return 4.5 end,play=function()end}
		r.trail=Things.new(deps)
		return r
	end
	local far={position=V(60,0),name="Pet Park"}
	test("ThingsTrail: off is as before (no glow, leadBy refused); on, the glow prints and the ring, and Seconds still ends it",function()
		local r=rig(false)
		assert(r.trail:start(far)and not r.trail.glow and r.trail.steps==nil and not r.trail:leadBy(Instance.new("Model")))
		r.trail:destroy()
		r=rig(true)
		assert(r.trail:start(far)and r.trail.glow and r.trail.steps and r.trail.glowCount>3)
		assert(r.trail.points and #r.trail.points>=2,"the way, for a pet to run along")
		assert(r.trail.steps.ring.surface.Enabled,"the gold ring at the target")
		for _=1,21 do r.trail:step(1)end
		assert(not r.trail:active()and r.trail.reason=="time","not a guide: today's end")
		r.trail:destroy()
	end)

	test("beta 44 #17: the glow paws go round a keep-out and point along the way (toes ahead, never across it)",function()
		local Lead=require(game:GetService("ReplicatedStorage").Shared.PetLead)
		local r=rig(true)
		local bush={id="bush",x=V(30,0).X,z=V(30,0).Z,r=1.5,kind="plant"}
		r.trail.d.keepOut=function()return{bush}end
		assert(r.trail:start(far)and r.trail.glowCount>3)
		local points=r.trail.points
		for i=2,#points do assert(Lead.blocker(points[i-1],points[i],{bush},Lead.Body,i==2,i==#points)==nil,"leg "..i)end
		-- each paw's toes (its -Z, less TopFaceYaw: the LookVector) along the way ahead: within 50 degrees of the next paw
		for i=1,r.trail.glowCount-1 do
			local a,b=r.trail.steps.route[i],r.trail.steps.route[i+1]
			local frame=a.part.CFrame*CFrame.Angles(0,-Glow.TopFaceYaw,0)
			local toes=frame.LookVector
			local toward=Vector3.new(b.at.X-a.at.X,0,b.at.Z-a.at.Z)
			if toward.Magnitude>1 then
				local flatToes=Vector3.new(toes.X,0,toes.Z).Unit
				assert(flatToes:Dot(toward.Unit)>math.cos(math.rad(50)),"paw "..i.." faces off the way")
			end
		end
		r.trail:destroy()
	end)

	test("ThingsTrail guide: outlives Seconds, hides for a menu or a trip out and comes back; arrival ends it",function()
		local r=rig(true)
		assert(r.trail:start({position=far.position,name=far.name,guide=true})and r.trail.guide)
		for _=1,40 do r.trail:step(1)end
		assert(r.trail:active(),"no time end")
		r.menu=true;r.trail:step(.1);assert(r.trail:active()and r.trail.folder.Parent==nil,"hidden for a menu")
		r.menu=false;r.trail:step(.1);assert(r.trail.folder.Parent~=nil,"back")
		r.open=false;r.trail:step(.1);assert(r.trail:active()and r.trail.folder.Parent==nil,"hidden out of the garden")
		r.open=true;r.trail:step(.1);assert(r.trail.folder.Parent~=nil)
		r.at=V(55,0);r.trail:step(.1);assert(not r.trail:active()and r.trail.reason=="arrived")
		r.trail:destroy()
	end)

	test("ThingsTrail leadBy: the pet's own prints follow its pivot; nil ends it; stop clears it",function()
		local r=rig(true)
		assert(r.trail:start({position=far.position,name=far.name,guide=true}))
		local model=Instance.new("Model")
		local at=V(2,0)
		model.GetPivot=function()return CFrame.new(at)end
		model.Parent=workspace
		assert(r.trail:leadBy(model)and r.trail.steps.leading)
		for i=1,10 do at=V(2+i*2.3,0);r.trail:step(.1)end
		assert(r.trail.steps.leadState:count()>=5,"prints under the pet")
		r.trail:leadHold(true);local seq=r.trail.steps.leadState.seq
		for i=11,14 do at=V(2+i*2.3,0);r.trail:step(.1)end
		assert(r.trail.steps.leadState.seq==seq,"held")
		r.trail:leadHold(false)
		assert(r.trail:leadBy(nil)and not r.trail.steps.leading)
		assert(r.trail:leadBy(model));r.trail:stop("done")
		assert(not r.trail.steps.leading and r.trail.leader==nil and r.trail.points==nil)
		assert(not r.trail:leadBy(model),"no trail: refused")
		model.Parent=nil
		r.trail:destroy()
	end)

	test("LeadTrail on the real ThingsTrail: trail2 on, a guide trail the pet leads (hold, nil at stop); off, today's trail",function()
		local LeadTrail=require(client.LeadTrail)
		local model=Instance.new("Model")
		model.GetPivot=function()return CFrame.new(V(4,0))end
		model.Parent=workspace
		local r=rig(true)
		local lead=LeadTrail.new({things=r.trail})
		assert(lead:lead(model,{position=far.position,name=far.name})and lead.mode=="lead")
		assert(r.trail.guide and r.trail.leader==model and r.trail.steps.leading,"guide, the pet leads")
		lead:hold(true);assert(r.trail.steps.leadState.held==true,"held")
		lead:hold(false);assert(r.trail.steps.leadState.held==false)
		for _=1,30 do r.trail:step(1)end
		assert(lead:active(),"a guide outlives Seconds")
		lead:stop()
		assert(not r.trail:active()and r.trail.leader==nil and not r.trail.steps.leading)
		r.trail:destroy()
		r=rig(false)
		lead=LeadTrail.new({things=r.trail})
		assert(lead:lead(model,{position=far.position,name=far.name})and lead.mode=="show"and r.trail:active())
		assert(not r.trail.glow and r.trail.leader==nil,"off: no lead mode")
		lead:hold(true)
		for _=1,21 do r.trail:step(1)end
		assert(not lead:active()and r.trail.reason=="time","off: today's Seconds end")
		lead:stop()
		r.trail:destroy()
		model.Parent=nil
	end)

	test("PetTrail: the switch is read per trail; a glow trail has no 30 s end and hides for a menu or the deck",function()
		assert(Pet.glowOn({glow=true})and Pet.glowOn({glow=function()return true end}))
		assert(not Pet.glowOn({})and not Pet.glowOn(nil)and not Pet.glowOn({glow=function()error("x")end}))
		assert(Pet.endsFor(31,{},false)=="time"and Pet.endsFor(1,{menu=true},false)=="menu","off: endReason exactly")
		assert(Pet.endsFor(31,{},true)==nil and Pet.endsFor(1,{menu=true},true)=="hide"and Pet.endsFor(1,{deck=true},true)=="hide")
		assert(Pet.endsFor(90,{hello=true,menu=true},true)=="hello","the first hello still ends it")
	end)

	return{passed=#cases,cases=cases}
end
