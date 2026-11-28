-- The Bear leads you to the nest (artifacts/qa-2026-11-27-beta37/ONBOARDING-V3-BRIEF.md section 1, Onboard "lead"):
-- the shared rules (Shared.PetLead) and the server's half (GardenState:lead, leadBack, leadEnd, leadCheer). The route
-- check, the trim and the corners, where along the route a pet is, the run / wait / arrive / poof decisions, the poses
-- every screen draws, the client's nudges and park, and the garden pet that runs, stops 12 ahead, runs on, comes back
-- on a nudge, arrives facing the nest, never wanders, catches up or greets while it leads, and follows once it ends.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.PetLead)(ServerScriptService.Server)
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Lead=require(Shared.PetLead)
	local UICopy=require(Shared.UICopy)
	local Onboard=require(Shared.Onboard)
	local Garden=require(server.GardenState)
	local Activity=require(Shared.GardenActivity)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function near(a,b,eps)return math.abs(a-b)<=(eps or 1e-6)end
	local function v(x,z,y)return Vector3.new(x,y or 4.025,z)end

	test("two switches appended (lead, allset2), their attributes and keys; the lead rides the guide; the lead's events",function()
		for _,name in ipairs({"lead","allset2"})do
			assert(table.find(Onboard.Features,name),name)
			assert(Onboard.attribute(name)=="Onboard_"..name and Onboard.key(name)=="onboard_"..name,name)
		end
		assert(Onboard.Features[13]=="guide"and table.find(Onboard.Features,"lead")>13 and table.find(Onboard.Features,"allset2")>13,"appended, nothing renumbered")
		assert(Onboard.Events.LeadStarted and Onboard.Events.LeadParked and Onboard.Events.NestReached)
		Onboard.inject({flags={OnboardingV3=true},studio=true,guide=false})
		assert(Onboard.on("lead")and not Onboard.leadOn(),"the lead needs the guide")
		Onboard.inject({flags={OnboardingV3=true},studio=true})
		assert(Onboard.leadOn()and Onboard.on("allset2"))
		Onboard.inject({flags={},studio=true})
		assert(not Onboard.on("lead")and not Onboard.on("allset2"),"the build ceiling")
		Onboard.inject(nil)
	end)
	test("the brief's numbers",function()
		-- the onboarding fun pass: a chase (18, faster than the player's 16), one hop, no rest after the pet, nudge at 6 s
		-- beta (40): it runs further before it looks back (22, was 12) and runs on sooner (14, was 7)
		assert(Lead.Run==18 and Lead.Ahead==22 and Lead.Resume==14 and Lead.Closing==4 and Lead.Pace<16 and Lead.AheadMax<Lead.Far
			and Lead.Arrive==3 and Lead.Reach==8 and Lead.Rest==2)
		assert(Lead.AfterPet.rest==0 and Lead.AfterPet.free<=.25)
		assert(Lead.Hops.count==1 and Lead.Hops.height==.6 and Lead.Hops.time==.35 and Lead.Beckon.every==2.5 and Lead.Beckon.wave==.5)
		assert(Lead.Still==6 and Lead.Far==30 and Lead.Back==5 and Lead.ThisWay==2 and Lead.Nudges==3 and Lead.Chip==36)
		assert(Lead.StuckMove==2 and Lead.StuckTime==2 and Lead.Return==2.5 and Lead.Toast==3)
	end)
	test("the words: headlines 16 characters or fewer, sub-lines 28 or fewer, {pet} filled, no key names",function()
		for name,entry in pairs(Lead.Prompts)do
			local head=UICopy.get(entry.head,{pet="Bear"})
			assert(head~=entry.head and #head<=16 and not string.find(head,"{",1,true),name..": "..head)
			if entry.sub then
				local sub=UICopy.get(entry.sub,{pet="Bear"})
				assert(sub~=entry.sub and #sub<=28,name..": "..sub)
			end
		end
		-- the onboarding fun pass: the pet's own voice (it asks, we do not order)
		assert(UICopy.get(Lead.Prompts.needHi.head,{pet="Bear"})=="Pet me!"and UICopy.get(Lead.Prompts.follow.head,{pet="Bear"})=="This way!")
		assert(UICopy.get(Lead.Prompts.tuck.head)=="Tuck it in!")
		assert(UICopy.get(Lead.Prompts.needDeck.head)=="Let's win Stars!"and UICopy.get(Lead.Prompts.needDeck.sub)=="Stars turn the crank!")
		-- the nudge's word still changes the headline
		assert(UICopy.get(Lead.ThisWayCopy)~=UICopy.get(Lead.Prompts.follow.head),"the nudge reads differently")
		assert(#UICopy.get(Lead.ThisWayCopy)<=16)
		-- beta (40), Spencer: "Hatches in X h / X min" always: the tuck's sub-line and the toast count down
		local function say(key,vars)return UICopy.get(key,vars)end
		assert(say(Lead.hatchWords("toast",7*3600-5))=="Sweet dreams! It hatches in 7 h.",say(Lead.hatchWords("toast",7*3600-5)))
		assert(say(Lead.hatchWords("toast",1800))=="Sweet dreams! It hatches in 30 min.")
		assert(say(Lead.hatchWords("sub",3*3600+1))=="It hatches in 4 h"and say(Lead.hatchWords("sub",59))=="It hatches in 1 min")
		local Nest=require(game:GetService("ReplicatedStorage").Shared.Nest)
		assert(say(Lead.hatchWords("sub",nil))==say(Lead.hatchWords("sub",Nest.Seconds)),"no clock yet: a fresh egg's nap")
		assert(say(Lead.hatchWords("sub",0))==say(Lead.hatchWords("sub",Nest.Seconds)),"never 'ready' in the tuck's words")
		for _,which in ipairs({"sub","toast"})do
			for _,left in ipairs({0,59,1800,3601,Nest.Seconds})do
				local text=say(Lead.hatchWords(which,left))
				assert(not string.find(string.lower(text),"tomorrow",1,true)and not string.find(text,"{",1,true),text)
				if which=="sub"then assert(#text<=28,text)end
			end
		end
	end)
	test("routes: the trim stops 3 studs short along the route; corners kept, the straight bits dropped",function()
		local route={v(0,0),v(0,10),v(10,10)}
		local cut=Lead.trim(route,3)
		assert(#cut==3 and (cut[3]-v(7,10)).Magnitude<1e-4,"3 back along the last stretch")
		local long=Lead.trim(route,12)
		assert(#long==2 and (long[2]-v(0,8)).Magnitude<1e-4,"round the corner")
		assert(#Lead.trim({v(0,0),v(0,1)},3)==1,"shorter than 3: where it starts")
		local straight={}
		for i=0,10 do table.insert(straight,v(0,i*4))end
		table.insert(straight,v(20,40))
		local s=Lead.simplify(straight)
		assert(s[1]==straight[1]and s[#s]==straight[#straight],"the ends")
		assert(#s<#straight and table.find(s,straight[11]),"the corner kept, the line thinned: "..#s)
		assert(near(Lead.length(route),20))
	end)
	test("the server's route check: grounded, near the pet and the nest, short steps, nothing solid between",function()
		local ground=function(p)return 4 end
		local clear=function()return true end
		local route={v(0,0),v(0,10),v(10,10)}
		local ctx={pet=v(1,0),nest=v(12,12),ground=ground,clear=clear}
		local points=Lead.clean(route,ctx)
		assert(points and #points==3 and near(points[2].Y,4.025),"grounded")
		local function why(raw,over)
			local c=table.clone(ctx);for k,x in pairs(over or {})do c[k]=x end
			return select(2,Lead.clean(raw,c))
		end
		assert(why({v(0,0)})=="count"and why({})=="count"and why("x")=="count")
		local many={};for i=1,Lead.Route.max+1 do many[i]=v(0,i*.1)end
		assert(why(many)=="count")
		assert(why({v(0,0),"x"})=="point"and why({v(0,0),Vector3.new(0/0,0,0)})=="point")
		assert(why(route,{ground=function()return nil end})=="ground"and why(route,{ground=function()return 40 end})=="ground")
		assert(why(route,{pet=v(30,0)})=="start","it starts at the pet")
		assert(why(route,{nest=v(60,60)})=="goal","it ends at the nest")
		assert(why({v(0,0),v(0,30),v(10,30)},{nest=v(10,30)})=="step","no long jumps")
		assert(why(route,{clear=function(a,b)return not(a.Z>5 and b.X>5)end})=="blocked","a fence on the way")
		local far={v(0,0)};for i=1,15 do far[i+1]=v(0,i*23)end
		assert(why(far,{nest=far[#far]})=="length")
	end)
	test("where along the route: the progress, the points ahead (the goal last), the way back to about 5 studs from the player",function()
		local route={v(0,0),v(0,10),v(0,20),v(0,30)}
		local along,next=Lead.progress(route,v(1,12))
		assert(near(along,12)and next==3,tostring(along).." "..tostring(next))
		local ahead=Lead.ahead(route,v(0,12),v(0,33))
		assert(#ahead==3 and ahead[1]==route[3]and ahead[3]==v(0,33),"the rest, then the goal")
		assert(#Lead.ahead({},v(0,0),v(5,5))==1,"no route: the goal alone")
		local way=Lead.backWay(route,v(0,28),v(0,4))
		assert(way and way[#way]==route[2],"back to the point nearest 5 studs from the player")
		assert(way[1]==route[3],"nearest the Bear first")
		assert(Lead.backWay(route,v(0,28),v(40,0))==nil,"no route point near the player: a poof instead")
	end)
	test("the decisions: start then run; 22 ahead it waits; within 14 (or passed) it runs on; at the goal it arrives; stuck it poofs",function()
		local goal=v(0,40)
		local lead={phase="start"}
		assert(Lead.decide(lead,{now=0,pet=v(0,0),owner=v(0,-1),goal=goal,moving=true})==nil)
		assert(Lead.decide(lead,{now=1,pet=v(0,0),owner=v(0,-1),goal=goal,moving=false})=="run")
		lead.phase="run"
		assert(Lead.decide(lead,{now=1,pet=v(0,5),owner=v(0,0),goal=goal,moving=true})==nil)
		assert(Lead.decide(lead,{now=1.5,pet=v(0,12.5),owner=v(0,0),goal=goal,moving=true})==nil,"12 ahead: on (beta 40)")
		assert(Lead.decide(lead,{now=1.5,pet=v(0,22.5),owner=v(0,0),goal=goal,moving=true})=="wait","22 ahead")
		assert(Lead.decide({phase="run"},{now=1,pet=v(0,20),owner=v(0,30),goal=goal,moving=true})==nil,"the player ahead: it keeps running")
		lead.phase="wait"
		assert(Lead.decide(lead,{now=2,pet=v(0,22),owner=v(0,0),goal=goal})==nil,"waits")
		assert(Lead.decide(lead,{now=2,pet=v(0,22),owner=v(0,7),goal=goal})==nil,"15 away: still waits")
		assert(Lead.decide(lead,{now=3,pet=v(0,22),owner=v(0,9),goal=goal})=="run","within 14")
		assert(Lead.decide(lead,{now=3,pet=v(0,22),owner=v(9,39),goal=goal})=="run","the player went past it")
		assert(Lead.decide({phase="run"},{now=4,pet=v(0,39.7),owner=v(0,35),goal=goal,moving=true})=="arrive")
		assert(Lead.decide({phase="arrive"},{now=4,pet=goal,owner=v(0,0),goal=goal})==nil,"stays")
		assert(Lead.decide({phase="back"},{now=4,pet=v(0,8),owner=v(0,0),goal=goal,moving=true})==nil)
		assert(Lead.decide({phase="back"},{now=4,pet=v(0,8),owner=v(0,0),goal=goal,moving=false})=="wait")
		local stuck={phase="run"}
		assert(Lead.decide(stuck,{now=10,pet=v(0,5),owner=v(0,0),goal=goal,moving=true})==nil)
		assert(Lead.decide(stuck,{now=11,pet=v(0,5.5),owner=v(0,0),goal=goal,moving=true})==nil)
		assert(Lead.decide(stuck,{now=12.1,pet=v(0,6),owner=v(0,0),goal=goal,moving=true})=="poof","under 2 studs in 2 s")
		assert(Lead.decide(stuck,{now=14.2,pet=v(0,9),owner=v(0,0),goal=goal,moving=true})==nil,"moving again")
	end)
	test("the poses every screen draws: one hop, the beckon each 2.5 s, the arrival bounce, the jump-spin; none under Reduced Motion",function()
		local H=Lead.Hops
		assert(near(Lead.pose("leadStart",H.time*.5,false),H.height),"one hop")
		assert(Lead.pose("leadStart",H.time*1.5,false)==0 and Lead.pose("leadStart",H.time+.01,false)==0,"then still")
		assert(near(Lead.pose("leadWait",Lead.Beckon.time*.5,false),Lead.Beckon.height)and Lead.pose("leadWait",1,false)==0)
		assert(near(Lead.pose("leadWait",Lead.Beckon.every+Lead.Beckon.time*.5,false),Lead.Beckon.height),"again 2.5 s later")
		assert(Lead.pose("leadArrive",Lead.Bounce.time*.5,false)>0)
		local lift,spin=Lead.pose("leadCheer",Lead.Cheer.time*.5,false)
		assert(lift>0 and near(spin,math.pi),"half way round")
		assert(select(2,Lead.pose("leadCheer",Lead.Cheer.time+.01,false))==0,"once")
		for _,action in ipairs({"leadStart","leadWait","leadArrive","leadCheer"})do
			local a,b=Lead.pose(action,.15,true);assert(a==0 and b==0,action)
		end
		assert(Lead.pose("follow",.1,false)==0 and Lead.pose("leadRun",.1,false)==0)
		assert(Lead.beckonDue(.1,nil)and not Lead.beckonDue(.2,0)and Lead.beckonDue(2.6,0)and not Lead.beckonDue(-1,nil))
	end)
	test("the nudges and the park: still 6 s, or over 30 studs away, is a nudge; answered it starts over; the 4th parks",function()
		local w=Lead.watcher()
		local t=0
		local function look(speed,gap,toNest,active)
			t+=.5
			return Lead.watch(w,{now=t,dt=.5,active=active~=false,speed=speed,gap=gap,toNest=toNest})
		end
		for _=1,Lead.Still*2-1 do assert(look(0,12,40)==nil)end
		assert(look(0,12,40)=="nudge"and w.count==1 and Lead.thisWay(w,t),"6 s still")
		assert(not Lead.thisWay(w,t+Lead.ThisWay+.01),"This way! for 2 s")
		-- walking the other way: counted at once (after the cool-down)
		for _=1,5 do look(10,20,45)end
		assert(look(10,31,50)=="nudge"and w.count==2,"over 30 studs away")
		-- answered: they walk Progress studs nearer the nest
		for _=1,6 do look(10,8,50-Lead.Progress-1)end
		assert(w.count==0,"not ignored: the count starts over")
		-- three ignored, then the park
		local events={}
		for _=1,4*(Lead.Still*2+1)do local e=look(0,12,44);if e then table.insert(events,e)end end
		assert(table.concat(events,",")=="nudge,nudge,nudge,park","three nudges, then the park: "..table.concat(events,","))
		-- paused (the deck, a menu): the clock stands still
		local p=Lead.watcher()
		for i=1,40 do assert(Lead.watch(p,{now=i,dt=1,active=false,speed=0,gap=40,toNest=40})==nil)end
		assert(p.still==0 and p.count==0)
	end)

	-- The garden pet (GardenState), with the game as fakes.
	local function fixture(over)
		local c={now=0,inputs={}}
		local at=v(0,0)
		c.inputs[1]={petId="pip",owned=true,alive=true,characterId=1,mode="Room",position=Vector3.new(at.X,7,at.Z),anchor=at,yaw=0,charmVisible=true}
		local options={now=function()return c.now end,publish=function(snapshot)c.snapshot=snapshot end,validFocus=function()return true end,
			sharedToyEnabled=false,landing=function(input)return input.anchor+Vector3.new(2,0,-2)end}
		for k,x in pairs(over or {})do options[k]=x end
		c.garden=Garden.new(options)
		function c:step(dt)self.now+=dt;self.garden:step(dt,self.inputs)end
		function c:walk(to)self.inputs[1].position=Vector3.new(to.X,7,to.Z);self.inputs[1].anchor=to end
		function c:pet()return self.garden:position(self.garden.actors[1],self.now)end
		function c:actor()return self.garden.actors[1]end
		c:step(.5);c:step(.5)
		return c
	end
	local ROUTE={v(0,2),v(0,10),v(0,20),v(0,30),v(0,40)}
	local GOAL,NEST=v(0,37),v(0,42)
	test("lead: the start hops once in place as it turns, then it runs within 0.6 s at about 18 studs a second along the route",function()
		local c=fixture()
		assert(c.garden:lead(1,ROUTE,GOAL,NEST))
		local a=c:actor()
		assert(a.lead and a.lead.phase=="start"and a.action=="leadStart"and a.behavior=="investigate","never a sit or a doze")
		assert(a.endTime-c.now<=.6+1e-6 and a.endTime-c.now>=Lead.startHops(),"the hop and the turn together: "..(a.endTime-c.now))
		local from=c:pet()
		c:step(.25);assert((c:pet()-from).Magnitude<1e-3,"hopping where it stands")
		c:step(.25)
		local held=c.snapshot.actors["1"].lead
		assert(held and(held.phase=="start"or held.phase=="run")and held.seq==1,"the snapshot carries it")
		c:step(.25)
		assert(c:actor().action=="leadRun","then it runs: "..tostring(c:actor().action))
		local t0,p0=c.now,c:pet()
		c:step(.5)
		local speed=Lead.flat(c:pet(),p0)/(c.now-t0)
		assert(speed>6 and speed<=Lead.Run*1.6,"a run: "..speed)
	end)
	test("lead: 12 studs ahead of a still player it stops, faces them and waits; the player coming within 7 runs it on",function()
		local c=fixture()
		c.garden:lead(1,ROUTE,GOAL,NEST)
		for _=1,8 do c:step(.5)end
		local a=c:actor()
		assert(a.lead.phase=="wait"and a.action=="leadWait","waiting: "..tostring(a.lead.phase))
		local gap=Lead.flat(c:pet(),c.inputs[1].position)
		assert(gap>=Lead.Ahead-.5 and gap<Lead.Ahead+8,"about 12 ahead: "..gap)
		local yaw=Activity.sample(a,c.now+1).yaw
		local want=math.atan2(c.inputs[1].position.X-c:pet().X,c.inputs[1].position.Z-c:pet().Z)
		assert(math.abs(math.atan2(math.sin(yaw-want),math.cos(yaw-want)))<.2,"facing the player")
		-- the player shuffles a little: still waiting, no follow
		c:walk(v(1,1));c:step(.5);c:step(.5)
		assert(c:actor().lead.phase=="wait","a shuffle does not pull it back")
		local pet=c:pet()
		c:walk(pet-Vector3.new(0,0,5));c:step(.5);c:step(.5)
		assert(c:actor().lead.phase=="run","runs on")
	end)
	test("lead: followed all the way it arrives 3 short of the prompt, faces the nest and bounces until the lead ends; then it follows",function()
		local c=fixture()
		c.garden:lead(1,ROUTE,GOAL,NEST)
		for _=1,80 do
			local pet=c:pet()
			c:walk(Vector3.new(pet.X,4.025,pet.Z-4))
			c:step(.5)
			if c:actor().lead and c:actor().lead.phase=="arrive"then break end
		end
		local a=c:actor()
		assert(a.lead and a.lead.phase=="arrive"and a.action=="leadArrive","arrived: "..tostring(a.lead and a.lead.phase))
		assert(Lead.flat(c:pet(),GOAL)<1.6,"at the goal")
		local yaw=Activity.sample(a,c.now+1).yaw
		assert(math.abs(math.atan2(math.sin(yaw-0),math.cos(yaw-0)))<.2,"facing the nest (+Z)")
		for _=1,10 do c:step(.5)end
		assert(c:actor().lead.phase=="arrive","stays while the player tucks")
		assert(c.garden:leadEnd(1))
		assert(c:actor().lead==nil and c:actor().behavior=="follow","then it follows")
		assert(not c.garden:leadEnd(1),"once")
	end)
	test("lead: a nudge runs it back along its route to about 5 studs from the player; then it waits and runs on",function()
		local c=fixture()
		c.garden:lead(1,ROUTE,GOAL,NEST)
		for _=1,8 do c:step(.5)end
		assert(c:actor().lead.phase=="wait")
		assert(c.garden:leadBack(1))
		assert(c:actor().lead.phase=="back"and c:actor().action=="leadBack")
		for _=1,12 do c:step(.5)end
		local gap=Lead.flat(c:pet(),c.inputs[1].position)
		assert(gap<Lead.Ahead,"came back: "..gap)
		assert(c:actor().lead.phase=="run"or c:actor().lead.phase=="wait","on again: "..c:actor().lead.phase)
	end)
	test("lead: a nudge far off the route poofs it to the player (lost: the client sends a new route)",function()
		local c=fixture()
		c.garden:lead(1,ROUTE,GOAL,NEST)
		for _=1,8 do c:step(.5)end
		c:walk(v(35,0))
		c:step(.5)
		local hops=c:actor().hop and c:actor().hop.seq or 0
		assert(c.garden:leadBack(1))
		assert(c:actor().lead.lost==true and c:actor().hop.seq==hops+1,"a poof")
		assert(Lead.flat(c:pet(),c.inputs[1].anchor)<4,"by the player")
		assert(c.snapshot==nil or true)
		c:step(.5)
		assert(c.snapshot.actors["1"].lead.lost==true)
	end)
	test("lead: arrived, or lost by the player, it ends once the owner is over Far away and the pet follows (review C2)",function()
		local c=fixture()
		c.garden:lead(1,ROUTE,GOAL,NEST)
		for _=1,80 do
			local pet=c:pet()
			c:walk(Vector3.new(pet.X,4.025,pet.Z-4))
			c:step(.5)
			if c:actor().lead and c:actor().lead.phase=="arrive"then break end
		end
		assert(c:actor().lead and c:actor().lead.phase=="arrive")
		c:walk(Vector3.new(c:pet().X,4.025,c:pet().Z-Lead.Far+2));c:step(.5)
		assert(c:actor().lead~=nil,"inside Far: still there")
		c:walk(Vector3.new(c:pet().X,4.025,c:pet().Z-Lead.Far-3));c:step(.5)
		assert(c:actor().lead==nil and c:actor().behavior=="follow","past Far: the lead ends, it follows")
		-- lost (poofed to the player) and the player walks off
		local l=fixture()
		l.garden:lead(1,ROUTE,GOAL,NEST)
		for _=1,8 do l:step(.5)end
		l:walk(v(35,0));l:step(.5)
		assert(l.garden:leadBack(1)and l:actor().lead.lost)
		l:walk(v(35+Lead.Far+3,0));l:step(.5)
		assert(l:actor().lead==nil and l:actor().behavior=="follow","lost and left: it follows")
	end)
	test("lead: never the catch-up, the leash, a wander or a greeting while it leads; care, a race, the deck or a far owner end it",function()
		local c=fixture({catchup=function()return true end})
		c.inputs[2]={petId="puddle",owned=true,alive=true,characterId=1,mode="Room",position=Vector3.new(2,7,0),anchor=v(2,0),yaw=0,charmVisible=true}
		c:step(.5)
		assert(c.garden:lead(1,ROUTE,GOAL,NEST),"a greeting gives way to the lead")
		for _=1,30 do
			c:step(.5)
			local a=c:actor()
			assert(a.lead~=nil,"still leading: "..tostring(a.action).." "..tostring(a.behavior).." pet "..tostring(c:pet()).." at ".._)
			assert(a.pairId==nil and a.action~="catchup"and a.action~="wander","its own rules: "..tostring(a.action))
		end
		-- the deck
		c.inputs[1].mode="Board";c:step(.5)
		assert(c:actor().lead==nil,"the deck ends it")
		-- a far owner
		local d=fixture()
		d.garden:lead(1,ROUTE,GOAL,NEST)
		d:walk(v(-80,0));d:step(.5)
		assert(d:actor().lead==nil and d:actor().behavior=="follow","too far: it follows")
		-- care or a race
		for _,busy in ipairs({"care","dash","park"})do
			local e=fixture()
			e.garden:lead(1,ROUTE,GOAL,NEST)
			e:actor()[busy]=if busy=="park"then {parkId="p"}else 1
			e.garden:decide()
			assert(e:actor().lead==nil,busy)
		end
	end)
	test("lead: refused for a busy pet, a bad goal or a bad route; leadBack and leadEnd refuse with no lead",function()
		local c=fixture()
		assert(not c.garden:lead(2,ROUTE,GOAL,NEST)and not c.garden:lead(1,ROUTE,"x",NEST)and not c.garden:lead(1,{1,2},GOAL,NEST))
		assert(not c.garden:leadBack(1)and not c.garden:leadEnd(1))
		for _,busy in ipairs({"care","dash","toyReservation"})do
			local d=fixture();d:actor()[busy]=1
			assert(not d.garden:lead(1,ROUTE,GOAL,NEST),busy)
		end
		local b=fixture();b.inputs[1].mode="Board";b:step(.5)
		assert(not b.garden:lead(1,ROUTE,GOAL,NEST),"Board")
		-- no route at all: the server's own planner straight to the goal
		local e=fixture()
		assert(e.garden:lead(1,{},GOAL,NEST))
		-- the start is over within 0.6 s now (one hop while it turns), so it is running by 1 s
		for _=1,2 do e:step(.5)end
		assert(e:actor().action=="leadRun",tostring(e:actor().action))
	end)
	test("cheer: the jump-spin where it stands, held through the owner moving, then it follows; it ends a lead",function()
		local c=fixture()
		c.garden:lead(1,ROUTE,GOAL,NEST)
		for _=1,3 do c:step(.5)end
		assert(c.garden:leadCheer(1))
		local a=c:actor()
		assert(a.lead==nil and a.action=="leadCheer","spinning, the lead over")
		c:walk(v(3,3));c:step(.5)
		assert(c:actor().action=="leadCheer","held while the owner moves")
		for _=1,4 do c:step(.5)end
		assert(c:actor().action~="leadCheer","then it follows: "..tostring(c:actor().action))
		local d=fixture();d:actor().care=1
		assert(not d.garden:leadCheer(1),"a pet in care")
	end)
	test("stuck while running: it poofs to the next route point and runs on",function()
		local c=fixture({planPath=function(from,to,velocity,speed,minimum,yaw)
			local path,seconds=Activity.plan(from,from,Vector3.zero,speed,.5,yaw);for _,leg in ipairs(path)do leg.safetyStop=true end;return path,seconds end,
			validToyPath=function()return false end})
		c.garden:lead(1,ROUTE,GOAL,NEST)
		local hops=0
		for _=1,12 do c:step(.5);hops=c:actor().hop and c:actor().hop.seq or hops end
		assert(hops>=1,"poofed on")
		assert(c:actor().lead~=nil)
	end)
	test("fit: a long pathfinding route with a bridge crossing is thinned under Route.max, no leg over Route.step, the bridge's ends kept; the server's clean takes it",function()
		local R=Lead.Route
		-- 3-stud pathfinding points along a winding 300-stud way, a 30-stud bridge in the middle (its two ends 30 apart)
		local raw={}
		local x,z=0,0
		for i=1,35 do x+=3;z+=math.sin(i*.4)*.8;table.insert(raw,Vector3.new(x,4,z))end
		local near=Vector3.new(x+2,5,z);local far=Vector3.new(x+32,5,z)
		table.insert(raw,near);table.insert(raw,far)
		x=far.X
		for i=1,35 do x+=3;z+=math.cos(i*.3)*.8;table.insert(raw,Vector3.new(x,4,z))end
		for i=1,20 do z+=3;table.insert(raw,Vector3.new(x,4,z))end
		assert(#raw>R.max,"raw: "..#raw.." points (over the cap)")
		local out=Lead.fit(raw)
		assert(out and #out<=R.max and #out>=2,"fits: "..tostring(out and #out))
		local hasNear,hasFar=false,false
		for i,p in ipairs(out)do
			if p==near then hasNear=true end
			if p==far then hasFar=true end
			if i>1 then assert(Lead.flat(out[i-1],p)<=R.step,"leg "..i..": "..Lead.flat(out[i-1],p))end
		end
		assert(hasNear and hasFar,"the bridge's two ends")
		assert(out[1]==raw[1]and out[#out]==raw[#raw])
		local cleaned,why=Lead.clean(out,{pet=raw[1],nest=raw[#raw],ground=function(p)return p.Y end,clear=function()return true end})
		assert(cleaned,"the server's caps: "..tostring(why))
		-- the raw route alone is refused (the bug)
		assert(Lead.clean(raw,{pet=raw[1],nest=raw[#raw],ground=function(p)return p.Y end,clear=function()return true end})==nil)
		-- a short straight route stays short; nonsense is nil
		local short=Lead.fit({Vector3.new(0,4,0),Vector3.new(4,4,0),Vector3.new(8,4,0)})
		assert(#short==2,"straight: the two ends")
		assert(Lead.fit({Vector3.new(0,4,0)})==nil and Lead.fit(nil)==nil and Lead.fit({Vector3.new(0,4,0),"x"})==nil)
		-- a very twisty route still fits by the coarser passes
		local zig={}
		for i=1,200 do table.insert(zig,Vector3.new(i*1.5,4,if i%2==0 then 1.2 else 0))end
		local z2=Lead.fit(zig)
		assert(z2 and #z2<=R.max)
	end)

	-- Beta (40), Spencer: "the pet runs thru meshes when showing you to something, and the distance it runs before turning
	-- around is too short, and it takes too long to turn back around and run again, needs to be smoother".
	test("beta 40: a following player never makes it stop: it trots on at Pace looking back; a waiting pet runs on as they come",function()
		local goal=v(0,200)
		local run={phase="run"}
		assert(Lead.decide(run,{now=1,pet=v(0,22.5),owner=v(0,0),goal=goal,moving=true,closing=16})=="pace","followed: on, at Pace")
		assert(Lead.decide({phase="run"},{now=1,pet=v(0,22.5),owner=v(0,0),goal=goal,moving=true,closing=2})=="wait","a dawdle: it waits")
		assert(Lead.decide({phase="run"},{now=1,pet=v(0,27.5),owner=v(0,0),goal=goal,moving=true,closing=16})=="wait","AheadMax: even followed it waits")
		local pace={phase="pace"}
		assert(Lead.decide(pace,{now=1,pet=v(0,20),owner=v(0,0),goal=goal,moving=true,closing=16})==nil,"trots on")
		assert(Lead.decide({phase="pace"},{now=1,pet=v(0,13),owner=v(0,0),goal=goal,moving=true,closing=16})=="run","they caught up: it runs")
		assert(Lead.decide({phase="pace"},{now=1,pet=v(0,23),owner=v(0,0),goal=goal,moving=true,closing=0})=="wait","they stopped: it waits")
		assert(Lead.decide({phase="pace"},{now=1,pet=v(0,27.5),owner=v(0,0),goal=goal,moving=true,closing=16})=="wait","AheadMax")
		assert(Lead.decide({phase="pace"},{now=1,pet=v(0,199.7),owner=v(0,190),goal=goal,moving=true,closing=16})=="arrive")
		local wait={phase="wait"}
		assert(Lead.decide(wait,{now=1,pet=v(0,22),owner=v(0,0),goal=goal,closing=Lead.Closing+.5})=="run","coming on fast: at once")
		assert(Lead.decide(wait,{now=1,pet=v(0,22),owner=v(0,0),goal=goal,closing=Lead.Closing-.5})==nil,"a shuffle is not following")
		-- after a nudge brought it back it waits for them to come to it, as before
		local nudged={phase="wait",nudged=true}
		assert(Lead.decide(nudged,{now=1,pet=v(0,10),owner=v(0,0),goal=goal})==nil,"10 away: waits for them")
		assert(Lead.decide(nudged,{now=1,pet=v(0,10),owner=v(0,3.5),goal=goal})=="run","they came")
		-- the look back every screen draws: over the shoulder the owner is on, none under Reduced Motion
		local L=Lead.LookBack
		local lift,spin,look=Lead.pose("leadPace",L.time*.5,false)
		assert(lift==0 and spin==0 and near(look,1),"a full look half way through")
		assert(select(3,Lead.pose("leadPace",L.time+.1,false))==0 and near(select(3,Lead.pose("leadPace",L.every+L.time*.5,false)),1),"each 2.5 s")
		assert(select(3,Lead.pose("leadPace",L.time*.5,true))==nil,"Reduced Motion: none")
		assert(near(Lead.lookYaw(1,v(-3,-10)),-L.yaw)and near(Lead.lookYaw(1,v(3,-10)),L.yaw)and Lead.lookYaw(0,v(1,1))==0)
		assert(near(Lead.lookYaw(.5,nil),L.yaw*.5),"no owner drawn: a look all the same")
	end)
	test("beta 40: the stop is an arc (40% of the speed through a small curve), never a brake and a pivot on the spot",function()
		local from,velocity=v(0,20),Vector3.new(0,0,Lead.Run)
		local face=v(0,-2)
		local path,seconds,at,yaw=Garden.leadArc(from,velocity,0,face,Lead.Hold)
		assert(path,"an arc")
		local old=Garden.leadSettle(from,velocity,0,face,Lead.Hold)
		local oldPivot=0;for _,leg in ipairs(old)do if leg.pivot then oldPivot+=leg.duration end end
		assert(oldPivot>=.5,"the old about-turn stood and pivoted "..oldPivot.." s")
		-- it moves through the turn: no pivot of any size until it has turned, the speed never under a third of the keep
		local moving,turned=0,0
		local keep=Lead.Run*Lead.Arc.keep
		local lastYaw,lastP=0,from
		local t=0
		local actor={from=Activity.pack(from),to=Activity.pack(at),startTime=0,endTime=seconds,path=path,action="leadWait",behavior="investigate"}
		while t<seconds-Lead.Hold do
			t+=1/60
			local s=Activity.sample(actor,t)
			local d=math.atan2(math.sin(s.yaw-lastYaw),math.cos(s.yaw-lastYaw))
			assert(math.abs(d)<.4,"the heading turns smoothly (no snap): "..d.." at "..t)
			turned+=d;lastYaw=s.yaw
			local speed=Lead.flat(s.position,lastP)*60;lastP=s.position
			if t<Lead.Arc.slow+.3 then assert(speed>keep*.3,"moving through the curve: "..speed.." at "..t)end
			if s.pivot then assert(math.abs(s.pivotTurn)<.6,"only a small trim on the spot")end
		end
		assert(math.abs(math.abs(turned)-math.pi)<.3,"about-turned: "..turned)
		local want=math.atan2(face.X-at.X,face.Z-at.Z)
		assert(math.abs(math.atan2(math.sin(yaw-want),math.cos(yaw-want)))<1e-6,"facing the player")
		assert(Lead.flat(at,from)<6,"a small curve: "..Lead.flat(at,from))
		local moveTime=seconds-Lead.Hold
		assert(moveTime<=1.1,"turned round within about a second: "..moveTime)
		-- too slow to arc: nil (the caller settles as before)
		assert(Garden.leadArc(from,Vector3.new(0,0,1),0,face,1)==nil)
		local keepS,radius,arcSeconds=Lead.arcFor(math.pi,Lead.Run)
		assert(near(keepS,keep)and radius<=Lead.Arc.radius and near(arcSeconds,Lead.Arc.time),"an about-turn in .35 s")
		local _,r2,s2=Lead.arcFor(math.pi/2,Lead.Run)
		assert(r2<=Lead.Arc.radius+1e-9 and s2>=Lead.Arc.leg-1e-9)
		-- the arc's own maths: a quarter circle to the right
		local p,h=Lead.arcPoint(v(0,0),0,1,2,math.pi/2)
		assert(near(p.X,2)and near(p.Z,2)and near(h,math.pi/2))
	end)
	local LONG={};for i=0,20 do table.insert(LONG,v(0,i*10))end
	test("beta 40 garden pet: a player who keeps following is never stopped for; it paces and looks back, then runs on",function()
		local c=fixture()
		-- the player starts 15 behind and walks after it at 16 studs a second
		c:walk(v(0,-15));c:step(.25);c:step(.25)
		assert(c.garden:lead(1,LONG,v(0,197),v(0,202)))
		local saw,waits,maxGap={},0,0
		for _=1,4*20 do
			local owner=c.inputs[1].position
			local pet=c:pet()
			local toward=Vector3.new(pet.X-owner.X,0,pet.Z-owner.Z)
			local step=if toward.Magnitude>4 then toward.Unit*4 else Vector3.zero -- 16 studs a second at .25 s
			c:walk(Vector3.new(owner.X+step.X,4.025,owner.Z+step.Z))
			c:step(.25)
			local a=c:actor()
			if not a.lead or a.lead.phase=="arrive"then break end
			saw[a.action]=true
			if a.lead.phase=="wait"then waits+=1 end
			maxGap=math.max(maxGap,Lead.flat(c:pet(),c.inputs[1].position))
		end
		assert(saw.leadPace,"it paced for them")
		assert(saw.leadRun,"and ran")
		assert(waits==0,"never a stop for a following player: "..waits)
		assert(maxGap<Lead.AheadMax+4.5,"never far ahead: "..maxGap)
	end)
	test("beta 40 garden pet: 22 ahead of a still player it arcs round to wait; as they come on it arcs back and runs",function()
		local c=fixture()
		c.garden:lead(1,LONG,v(0,197),v(0,202))
		for _=1,4*3 do c:step(.25)if c:actor().lead.phase=="wait"then break end end
		local a=c:actor()
		assert(a.lead.phase=="wait","waiting: "..a.lead.phase)
		local gap=Lead.flat(c:pet(),c.inputs[1].position)
		assert(gap>=Lead.Ahead-.5,"22 ahead, not 12: "..gap)
		local pivots=0;for _,leg in ipairs(a.path)do if leg.pivot and math.abs(leg.turn)>.6 then pivots+=1 end end
		assert(pivots==0,"an arc, no about-turn on the spot")
		for _=1,4 do c:step(.25)end
		-- the player sets off toward it at 16 studs a second: within a step or two it runs on, before they are within 14
		local resumedAt=nil
		for i=1,8 do
			local owner=c.inputs[1].position
			c:walk(Vector3.new(owner.X,4.025,owner.Z+4));c:step(.25)
			if c:actor().lead.phase=="run"then resumedAt=i;break end
		end
		assert(resumedAt and resumedAt<=3,"runs on as they come: "..tostring(resumedAt))
		assert(Lead.flat(c:pet(),c.inputs[1].position)>Lead.Resume,"before they are within 14")
		local run=c:actor()
		assert(run.action=="leadRun"and not run.path[1].pivot,"it sets off moving, no pivot first")
		local first=Activity.legPose(run.path[1],run.path[1].duration)
		assert(first,"a launch leg")
	end)
	test("beta 40: the route goes round the keep-outs the navmesh cannot see; the server refuses one through them",function()
		local bush={id="bush 1",x=0,z=20,r=1.5,kind="plant"}
		local trunk={id="trunk",x=1.5,z=40,r=.6,kind="solid"}
		local list={bush,trunk}
		local straight={v(0,0),v(0,12),v(0,24),v(0,36),v(0,48),v(0,60)}
		assert(Lead.blocker(straight[2],straight[3],list,Lead.Body)==bush,"through the bush")
		local out=Lead.around(straight,list)
		assert(out and out[1]==straight[1]and out[#out]==straight[#straight],"the same ends")
		for i=2,#out do
			assert(Lead.blocker(out[i-1],out[i],list,Lead.Body,i==2)==nil,"leg "..i.." clear")
			assert(Lead.flat(out[i-1],out[i])<=Lead.Route.step,"no leg over the step")
		end
		assert(#out>#straight and #out<=Lead.Route.max,"a detour or two: "..#out)
		-- a refused side (water there): the other side
		local left=Lead.around(straight,{bush},function(a,b)return a.X>=-.01 and b.X>=-.01 end)
		for _,p in ipairs(left)do assert(p.X>=-.01,"kept off the refused side")end
		assert(Lead.around(straight,{bush},function()return false end)==nil,"no side: nil (the caller sends it as it was)")
		-- nothing to go round: unchanged; the pet standing in a bush walks out
		assert(#Lead.around(straight,{})==#straight)
		local inBush=Lead.around({v(0,20),v(0,40)},{bush})
		assert(inBush and #inBush==2,"from inside: straight out")
		-- the server's check: the straight route is refused, the detour taken
		local ctx={pet=v(0,0),nest=v(0,62),ground=function()return 4 end,clear=function()return true end,keepOut=list}
		local refused,why=Lead.clean(straight,ctx)
		assert(refused==nil and why=="keepout",tostring(why))
		local taken,why2=Lead.clean(out,ctx)
		assert(taken,"the detour: "..tostring(why2))
		ctx.keepOut=nil
		assert(Lead.clean(straight,ctx),"no list: as before")
	end)
	return{passed=#cases,cases=cases}
end
