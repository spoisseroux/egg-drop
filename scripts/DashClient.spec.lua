-- Garden Dash client (DashClient and RoomView's camera hooks, slice S7) with a fake room, screen and network: off is
-- nothing at all, and every way out of a race gives the camera, the controls and the pet back.
-- Offline only (scripts/run_dash_server_specs.py): it replaces DashHud, DashCard, DashInput.mount and the services.
return function(client,offline)
	local RS=game:GetService("ReplicatedStorage")
	local Shared=RS.Shared
	local Dash=require(Shared.Dash)
	local Sim=require(Shared.DashSim)
	local Wire=require(Shared.DashWire)
	local Stats=require(Shared.DashStats)
	local UICopy=require(Shared.UICopy)
	local HttpService=game:GetService("HttpService")
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	offline.services.Players={LocalPlayer={UserId=7,GetNetworkPing=function()return .04 end,RequestStreamAroundAsync=function()end}}
	offline.services.GuiService={MenuIsOpen=false}
	offline.services.UserInputService={GetFocusedTextBox=function()return nil end}
	local Hud,Card,Input,Rail,Confirm=require(client.DashHud),require(client.DashCard),require(client.DashInput),require(client.NotificationRail),require(client.ConfirmDialog)
	local Client=require(client.DashClient)
	local Props=require(client.DashProps)
	local ON={flags={GardenDash=true},studio=true}
	local function signal()return offline.signal()end
	local plain=Instance.new
	Instance.new=function(class,parent)
		local item=plain(class,parent)
		if class=="ProximityPrompt"then item.Triggered=signal()end
		return item
	end
	local function pet()return{origin=Vector3.zero,worldScale=.72,model={},update=function()end,destroy=function(self)self.gone=true end,applyGardenPose=function()end}end
	require(client.PetFactory).create=function()return pet()end
	-- The screen, the cards and the device.
	local screen,screenFails
	Hud.new=function()
		screen={on=false}
		return setmetatable({zones={},stones={},show=function()screen.on=true;screen.rest=false end,hide=function()screen.on=false end,rest=function()screen.rest=true end,destroy=function()screen.gone=true;screen.on=false end,
			say=function(_,text)screen.word=text end,setHint=function(_,text)screen.hint=text end,setDigits=function(_,text)screen.digits=text end},{__index=function()return function()end end})
	end
	local card
	local openCard=Card.open
	Card.open=function(options)
		if options.name==screenFails then return nil end
		card={options=options,lines=table.clone(options.lines),closed=false}
		function card:close()self.closed=true end
		function card:setLine(i,text)self.lines[i]=text end
		function card:update(model)self.model=model;self.updates=(self.updates or 0)+1 end
		card.model=options.model
		function card:pick(name)for _,b in ipairs(options.buttons)do if b.name==name then self.closed=true;b.act();return end end;error(name)end
		return card
	end
	local device
	Input.mount=function(options)
		device={core=options.core,bound=false}
		return{open=function()device.bound=true;options.core:setOpen(true)end,close=function()device.bound=false;options.core:setOpen(false)end,destroy=function()device.bound=false;device.gone=true end}
	end
	local asked
	Confirm.ask=function(options)asked=options;return{cancel=function()asked=nil end}end

	local now
	local function rig(env)
		now=1000
		Dash.inject(env or ON)
		local r={requests={},inputs={},notes={},modal=false,roam=true,menusClosed=0,saved=nil}
		local remotes=Instance.new("Folder")
		local function remote(name,sent)
			local item=Instance.new("RemoteEvent");item.Name=name;item.OnClientEvent=signal()
			item.FireServer=function(_,packet)table.insert(sent,packet)end
			item.Parent=remotes
			return item
		end
		remotes.ChildAdded=signal()
		r.remotes=remotes
		r.request=remote(Wire.Remotes.request,r.requests);r.input=remote(Wire.Remotes.input,r.inputs)
		r.event=remote(Wire.Remotes.event,{});r.state=remote(Wire.Remotes.state,{})
		local old=RS:FindFirstChild("GardenState");if old then old:Destroy()end
		r.folder=Instance.new("Folder");r.folder.Name="GardenState";r.folder.Parent=RS
		RS.ChildAdded=signal()
		r.gui=Instance.new("Folder")
		r.room={mode="Room",target="Room",held=false,locks=0,frames=0,pet=pet(),companions={active={}},shownPet={id="pip"},
			garden={petGeneration=function()return 1 end,characterId=function()return 2 end},
			enterDash=function(room,preview)
				if room.dashHeld then if not preview then room.hidden=true end;return true end
				if room.refuse then return false end
				room.held=true;room.dashHeld={};room.locks+=1;room.hidden=not preview
				return true
			end,
			leaveDash=function(room)if room.held then room.held=false;room.dashHeld=nil;room.locks-=1;room.hidden=false end end,
			dashCamera=function(room)assert(room.held,"the camera only while held");room.frames+=1 end}
		Rail.enqueue=function(_,key)table.insert(r.notes,key)end
		Rail.status=function(_,_,data)r.lineData=data;return{update=function(_,v)r.line=v.text;r.lineData=v end,cancel=function()r.line=nil end,pulse=function()r.pulses=(r.pulses or 0)+1 end}end
		Rail.holder=nil
		r.client=Client.mount({remotes=remotes,roomView=r.room,playerGui=r.gui,audio={play=function()end},reduced=function()return r.reduced==true end,
			state=function()return{dash=r.saved}end,canRoam=function()return r.roam end,modalOpen=function()return r.modal end,closeMenus=function()r.menusClosed+=1 end})
		function r.fire(packet)r.event.OnClientEvent:Fire(packet)end
		function r.frame(count,dt)
			for _=1,count or 1 do
				now+=dt or 1/60
				if r.room.dash then
					r.room.dash:step(dt or 1/60,now)
					if r.room.dash then r.drawn=r.room.dash:drive(r.room.pet,7,1/60,false)end
				else r.drawn=false end
			end
		end
		function r.lock(mode,count,trial)
			local runners={}
			for i=1,count or 4 do runners[i]=if i==1 then {}else{bot=true}end
			r.race=Sim.new({seed=9,mode=mode or"fun",runners=runners})
			r.id=if trial then "trial-1"else "race-1"
			r.fire({kind="joined",raceId=r.id,seat=1,mode=mode or"fun",trial=trial})
			r.goAt=now+3.5
			local seats={}
			for i=1,count or 4 do seats[i]=if i==1 then{seat=1,userId=7,petId="pip"}else{seat=i,pal=true,petId="blip",name={"noodle"},tint=1}end
			r.plan=Sim.publicPlan(r.race.plan)
			r.fire({kind="locked",raceId=r.id,seat=1,mode=mode or"fun",goAt=r.goAt,plan=r.plan,trial=trial})
			if not trial then r.roster({v=1,phase="countdown",raceId=r.id,mode=mode or"fun",goAt=r.goAt,plan=r.plan,seats=seats,queue={}})end
		end
		function r.roster(value)r.folder:SetAttribute(Wire.RosterAttribute,HttpService:JSONEncode(value))end
		function r.free(why)
			assert(not r.room.held and r.room.locks==0 and not r.room.hidden,why..": camera, controls and avatar")
			assert(not r.client.shot and(r.client.fade==nil or next(r.client.fade.records)==nil),why..": see-through")
			assert(r.client.seat==nil and not r.client:held(),why..": seat")
			assert(not(screen and screen.on)and not(device and device.bound),why..": screen and buttons")
			r.frame();assert(r.drawn==false and r.room.pet.dashState==nil and r.room.pet.parkPose~=true,why..": the pet")
		end
		function r.done()r.client:destroy();Dash.inject(nil)end
		return r
	end

	test("STUDIO-CHECK-R2: a rival already home is ahead of a tie at the line (the pill read 1st under a 4th sheet)",function()
		assert(Client.aheadOf(0,0,true)and not Client.aheadOf(0,0,false),"home first is ahead at the tie")
		assert(Client.aheadOf(3,5,false)and not Client.aheadOf(5,3,true)and not Client.aheadOf(5,0,true))
	end)
	test("the gate card: the course from the side, the avatar in view; every way the card goes gives the camera back",function()
		local r=rig()
		local eye,look=Client.gateView()
		local Course=require(Shared.DashCourse)
		local x,y,z=Course.at(0)
		assert((eye-Vector3.new(x,y,z)).Magnitude<18 and(look-Vector3.new(x,y,z)).Magnitude<4 and eye.Y>y+3)
		assert(math.sqrt((eye.X-Course.Pad.x/100)^2+(eye.Z-Course.Pad.z/100)^2)>Course.Pad.r/100+2,"not over the waiting players")
		-- Beta 12 U5: nor is the line-up shot's eye, on any screen shape.
		for _,aspect in ipairs({874/402,568/320,4/3,16/9})do
			local ex,_,ez=require(client.DashCamera).lineup(aspect)
			assert(math.sqrt((ex-Course.Pad.x/100)^2+(ez-Course.Pad.z/100)^2)>Course.Pad.r/100+2,"the line-up eye is not over the waiting players")
		end
		for name,out in pairs({
			back=function()card.closed=true end,
			race=function()card:pick("Fun");r.lock()end,
			deck=function()r.room.target="Board"end,
			other=function()r.modal=true end,
			off=function()r.client:close()end,
			error=function()r.client:fail("x")end,
			lost=function()r.room:leaveDash()end,
		})do
			r.done();r=rig()
			r.client:gate();assert(card.options.sheet=="gate"and card.options.gate and card.options.buttons[3].sub~=nil)
			r.frame(2);assert(r.room.held and not r.room.hidden and r.client.shot and r.room.frames>0,name)
			out();r.frame(40)
			if name=="race"then assert(r.room.held and r.room.hidden and r.room.locks==1);r.client:leave()end
			r.room.target="Room";r.modal=false
			if name=="lost"then assert(not r.room.held,"not taken again for the same card");card:close()end
			if name=="other"then assert(card.closed)end
			r.frame();if r.client.isOpen then r.free(name)else assert(not r.room.held and r.room.locks==0)end
		end
		r.done()
	end)
	test("Just for Fun is picked for a first race; later the gate remembers what was raced",function()
		local r=rig()
		r.client:gate();assert(card.options.selected==1 and card.options.buttons[1].name=="Fun"and card.options.buttons[1].primary);card:pick("Stats")
		r.client.pending=nil;r.client:gate();assert(card.options.selected==1,"still a first race");card:pick("Stats");r.client.pending=nil
		r.client.raced=true;r.client:gate();assert(card.options.selected==2 and card.options.buttons[2].primary and not card.options.buttons[1].primary);card:close()
		r.saved={best=1};r.client.raced=nil;r.client.last={kind="trial"};r.client:gate();assert(card.options.selected==3);card:close()
		r.done()
	end)
	test("the first-race helper shows on a first race only, and never after a clean jump",function()
		local r=rig()
		r.lock();assert(r.client.seat.hints);r.frame(235);assert(screen.hint=="Hold Dash!"or r.frame(20)==nil and screen.hint=="Hold Dash!")
		r.frame(170);r.client.seat.hints.done=true;r.frame(2);assert(r.client.seat.hints==nil and screen.hint==nil)
		r.client:leave();r.lock();assert(r.client.seat.hints==nil,"the second race of the session");r.client:leave();r.done()
		r=rig();r.saved={best=1};r.lock();assert(r.client.seat.hints==nil);r.client:leave();r.done()
	end)
	test("tags: only near the player's pet, and never over each other",function()
		local r=rig();r.lock("fun",8);r.frame(12)
		local props=r.client.props
		local function shown()local n=0;for _,tag in pairs(props.tags)do if tag.board.Enabled then n+=1 end end;return n end
		for slot,tag in pairs(props.tags)do tag.part.Position=Vector3.new(slot,0,0)end
		local function wide(p)return p.X*200,50 end
		props:untag(1) -- the player's own pet (its chevron), tagged by the last drive()
		-- After the names (no ctx): today's rule for the pals. Each frame the pets say where they are.
		local function place(anchor,project)
			for slot,tag in pairs(props.tags)do if tag.info and tag.info.pal then props:tagAt(slot,Vector3.new(slot,0,0))end end
			props:placeTags(anchor,project)
		end
		place(Vector3.zero,wide);assert(shown()==7)
		place(Vector3.zero,function(p)return p.X*20,50 end)
		local last=nil
		for slot=1,8 do local tag=props.tags[slot];if tag and tag.board.Enabled then if last then assert(math.abs(tag.x-last)>=Props.TagSize.X+Props.TagGap)end;last=tag.x end end
		assert(shown()>=1 and shown()<7 and props.tags[2].board.Enabled,"the nearest one wins")
		place(Vector3.new(-6,0,0),wide);assert(shown()==5,"12 studs")
		place(Vector3.zero,function()return nil end);assert(shown()==0)
		place(nil,wide);assert(shown()==0)
		place(Vector3.zero,wide);props:placeTags(Vector3.zero,wide);assert(shown()==0,"a tag nothing moved this frame hides")
		r.client:leave();r.done()
	end)
	test("start-line names (beta 12 U5): a racer sees every name from the lock to GO + 1.5 on top, none hidden; then they fade and a chevron stays",function()
		local r=rig();r.lock("fun",8);r.frame(2)
		local props=r.client.props
		assert(r.client.seat.tagText~=nil and props.tags[1]and props.tags[1].info.mine,"the player's own pet is tagged through drive()")
		local function frame(t,dt)
			for lane=1,8 do props:tag(lane,"Pet "..lane);props:tagAt(lane,Vector3.new(lane*1.5,0,0),{lane=lane,mine=lane==1,pal=lane~=1})end
			props:placeTags(Vector3.new(1.5,0,0),function(p)return p.X*12,100 end,{viewer="racer",now=t,dt=dt or 1/60,namesUntil=10})
		end
		frame(5)
		local boxes={}
		for lane=1,8 do
			local tag=props.tags[lane]
			assert(tag.board.Enabled and tag.mode=="name"and tag.board.AlwaysOnTop,lane)
			assert(tag.label.AutoLocalize==false and tag.label.Text=="Pet "..lane,"names are never translated")
			boxes[lane]={x=tag.x,top=tag.y-tag.tier*Props.TierPx,w=tag.width}
		end
		assert(props.tags[1].pill.BackgroundColor3==Props.Lemon and props.tags[2].pill.BackgroundColor3==Props.Cream,"yours is lemon")
		for a=1,8 do for b=a+1,8 do
			local A,B=boxes[a],boxes[b]
			assert(math.abs(A.x-B.x)>=(A.w+B.w)/2 or math.abs(A.top-B.top)>=Props.NameH,a..","..b)
		end end
		assert(props.tags[1].scale.Scale<1,"they pop in: "..tostring(props.tags[1].scale.Scale));frame(5.5);assert(props.tags[8].scale.Scale==1)
		frame(10.1,.1)
		assert(props.tags[1].mode=="chevron"and props.tags[1].chevron.Visible,"your pet keeps its chevron")
		assert(props.tags[5].board.Enabled and props.tags[5].alpha<1,"the others fade over 0.3 s")
		frame(10.5,.3);assert(not props.tags[6].board.Enabled)
		r.client:leave();r.done()
	end)
	test("onlookers (beta 12 G4): a Racing pill over each racing pet from GO until it is home; no names; no inspect prompt",function()
		local r=rig()
		r.client.seat=nil
		local props=r.client.props
		local function frame(t,running,finished)
			for lane=1,3 do props:tag(lane,"Pet "..lane);props:tagAt(lane,Vector3.new(lane*4,0,0),{lane=lane,finished=finished and lane==2})end
			props:placeTags(nil,function(p)return p.X*40,100 end,{viewer="onlooker",now=t,dt=.05,running=running})
		end
		frame(1,false);for lane=1,3 do assert(not props.tags[lane].board.Enabled,"not before GO")end
		frame(1.05,true);assert(props.tags[1].mode=="racing"and props.tags[1].alpha<1,"fades in")
		for i=1,6 do frame(1.05+i*.05,true)end
		local tag=props.tags[1]
		assert(tag.alpha==1 and tag.flag.Visible and tag.label.Text=="Racing"and not tag.board.AlwaysOnTop and tag.board.MaxDistance==Props.RacingReach)
		frame(2,true,true);for i=1,5 do frame(2+i*.05,true,true)end
		assert(not props.tags[2].board.Enabled and props.tags[1].board.Enabled,"out when that pet is home")
		r.done()
	end)
	test("Props.tiers: odd lanes low, even lanes a tier up, and two that touch push the farther one up; none is hidden",function()
		local tiers=Props.tiers({{lane=1,x=0,y=100,w=80,away=1},{lane=2,x=40,y=100,w=80,away=2},{lane=3,x=80,y=100,w=80,away=3}})
		assert(tiers[1]==0 and tiers[2]==1 and tiers[3]==1+1,"lane 3 meets lane 1 at tier 0 and is the farther: up past lane 2 too")
		tiers=Props.tiers({{lane=1,x=0,y=100,w=80,away=5},{lane=3,x=10,y=100,w=80,away=1}})
		assert(tiers[1]==1 and tiers[2]==0,"the farther goes up")
		tiers=Props.tiers({{lane=1,x=0,y=100,w=80},{lane=3,x=300,y=100,w=80}})
		assert(tiers[1]==0 and tiers[2]==0)
	end)
	test("ceiling off: nil; switch off: no instances, no hooks, nothing stepped",function()
		Dash.inject({flags={},studio=true});assert(Client.mount({})==nil)
		local r=rig({flags={GardenDash=true},studio=true,race=false})
		assert(r.client and not r.client.isOpen and r.room.dash==nil and r.room.companions.dash==nil and Rail.holder==nil)
		assert(#r.gui:GetChildren()==0 and workspace:FindFirstChild(Props.FolderName)==nil and #r.event.OnClientEvent.list==0)
		assert(not r.client:held()and not r.client:panelOpen()and not r.client:askLeave(function()error("no")end))
		r.done()
	end)
	test("on and off again leaves the same trees, hooks and connections",function()
		local r=rig()
		assert(r.room.dash==r.client and workspace:FindFirstChild(Props.FolderName)and #r.event.OnClientEvent.list==1)
		r.lock();r.frame(5);assert(r.room.held)
		Dash.inject({flags={GardenDash=true},studio=true,race=false});workspace:SetAttribute("Dash_race",not workspace:GetAttribute("Dash_race"))
		assert(r.room.dash==nil and r.room.companions.dash==nil and Rail.holder==nil and workspace:FindFirstChild(Props.FolderName)==nil)
		assert(#r.gui:GetChildren()==0 and #r.event.OnClientEvent.list==0 and #r.state.OnClientEvent.list==0)
		r.free("switch off")
		r.done()
	end)
	test("a race: held from the countdown, buttons from GO, a press goes out, the result and Done give everything back",function()
		local r=rig()
		assert(r.client.prompt)
		r.frame(20);assert(r.client.prompt.Enabled==true)
		r.client:gate();card:pick("Fun")
		local join=r.requests[#r.requests];assert(join.kind=="join"and join.mode=="fun"and join.petId=="pip"and join.petGeneration==1 and join.characterId==2 and Wire.request(join))
		r.fire({kind="reply",request="join",seq=join.seq,ok=true,raceId="race-1"})
		r.lock();assert(r.menusClosed==1 and r.client:held()and Rail.holder())
		r.frame();assert(r.room.held and screen.on and r.drawn and not device.bound and screen.digits=="3"or screen.digits==nil)
		assert(not device.core:begin("t","jump"),"not before GO")
		r.frame(230);assert(device.bound and screen.digits=="GO!")
		assert(device.core:begin("k","jump"));local packet=r.inputs[#r.inputs];assert(packet.k=="jump"and packet.r=="race-1"and Wire.input(packet))
		device.core:begin("s","dash");assert(r.inputs[#r.inputs].k=="dashDown")
		-- A refused dashDown is pressed again while held.
		r.fire({kind="refusedInput",r="race-1",n=r.inputs[#r.inputs].n,reason="late"});local count=#r.inputs
		r.frame();assert(#r.inputs==count+1 and r.inputs[#r.inputs].k=="dashDown")
		r.fire({kind="zoom",r="race-1",tick=40});assert(screen.word=="Zoomies!")
		r.fire({kind="zoom",r="old",tick=41})
		r.fire({kind="result",r="race-1",mode="fun",seats={},seat=1,place=2,us=41000000})
		assert(not device.bound and r.inputs[#r.inputs].k=="dashUp"and screen.rest and r.room.held,"the finish is still on screen")
		r.client.seat.cardAt=-1;r.frame(20)
		assert(card.options.name=="Results"and card.options.sheet=="results"and card.model.headline=="You finished 2nd!"and card.model.earned.state=="saving")
		assert(card.options.place==2 and card.options.buttons[1].name=="Again"and card.options.buttons[2].name=="Done"and card.options.back,"no close key: Done is the way out")
		r.saved={paid=1,limit=5,best=41000000,last={op="x",stars=2}};r.frame(20)
		assert(card.model.earned.state=="paid"and card.model.earned.stars==2 and card.model.earned.done==1 and card.model.best=="41.0"and card.updates==1)
		r.frame(20);assert(card.updates==1,"the same receipt is not sent twice")
		-- The roster says results (the race is over for everyone): Done sinks this player's hoops at once.
		r.roster({v=1,phase="results",raceId=r.id,mode="fun",goAt=r.goAt,plan=r.plan,seats={{seat=1,userId=7,petId="pip"}},queue={}})
		assert(r.client.props.want==1,"a racer's hoops stay up through their own results")
		card:pick("Done");r.free("done")
		assert(r.client.props.want==0,"Done: an onlooker now, so the hoops sink")
		r.done()
	end)
	test("beta 14 F1: a Coming up chip on the results card puts the card away first, then routes (afterGarden); none without a strip",function()
		local r=rig()
		local routed={}
		r.client.d.strip=function()return{chips={}}end
		r.client.d.stripChip=function(id)assert(card.closed and not r.room.held,"the card and the room are given back first");table.insert(routed,id);return true end
		r.lock();r.frame(5)
		r.fire({kind="result",r="race-1",mode="fun",seats={},seat=1,place=1,us=41000000});r.client.seat.cardAt=-1;r.frame(20)
		assert(card.options.onChip and card.options.strip)
		assert(card.options.onChip("nest")==true and routed[1]=="nest"and r.client.seat==nil)
		assert(card.options.onChip("stamp")==false and #routed==1,"once: the card is gone")
		r.done()
		r=rig();r.client.d.stripChip=function()error("no strip, no chips")end
		r.lock();r.frame(5)
		r.fire({kind="result",r="race-1",mode="fun",seats={},seat=1,place=1,us=41000000});r.client.seat.cardAt=-1;r.frame(20)
		assert(card.options.onChip==nil);card:pick("Done");r.done()
	end)
	test("Race again and back; the results close themselves",function()
		local r=rig()
		r.lock();r.frame(5)
		r.fire({kind="result",r="race-1",mode="fun",seats={},seat=1,place=1,us=41000000});r.client.seat.cardAt=-1;r.frame(20)
		local before=#r.requests;card:pick("Again");r.free("again");assert(#r.requests==before+1 and r.requests[#r.requests].kind=="join")
		r.lock("trial",1,true);r.frame(5);assert(r.room.held)
		r.fire({kind="result",r="trial-1",trial=true,mode="trial",seats={},seat=1,place=1,us=31000000,medal="silver"});r.client.seat.cardAt=-1;r.frame(20)
		assert(card.options.title=="31.0 s!");r.client.seat.closeAt=-1;r.frame(20);assert(card.closed);r.free("left alone")
		r.done()
	end)
	test("every other way out: abort, refused, an error, the Deck, a mode switch, leaving",function()
		for name,out in pairs({
			abort=function(r)r.fire({kind="aborted",r="race-1",reason="Error"})end,
			refused=function(r)r.fire({kind="refused",raceId="race-1",reason="Deck"})end,
			deck=function(r)r.room.target="Board";r.frame();assert(r.requests[#r.requests].kind=="leave")end,
			error=function(r)r.client.seat.predict.runner=nil;r.frame();assert(r.client.errors==1)end,
			drive=function(r)r.room.pet.dashState={};r.frame();assert(r.client.errors==1)end,
			leave=function(r)assert(r.client:askLeave(function()r.acted=true end));assert(r.room.held,"asked first");asked.onConfirm();assert(r.acted and r.requests[#r.requests].kind=="leave")end,
			stale=function(r)now+=200;r.frame();assert(r.requests[#r.requests].kind=="leave")end,
			newRace=function(r)r.fire({kind="joined",raceId="other",seat=1,mode="fun"});r.fire({kind="refused",raceId="other",reason="Far"})end,
		})do
			local r=rig();r.lock();r.frame(240)
			assert(r.room.held and device.bound,name)
			device.core:begin("s","dash")
			if name=="newRace"then r.fire({kind="result",r="race-1",mode="fun",seats={},seat=1,place=1,us=1})end
			out(r)
			r.free(name)
			assert(r.inputs[#r.inputs].k=="dashUp"or name=="error"or name=="stale",name..": dash let go")
			r.done()
		end
	end)
	test("three errors turn it off here, with everything given back",function()
		local r=rig()
		for _=1,3 do r.lock();r.frame(3);r.client.seat.predict.runner=nil;r.frame()end
		assert(r.client.dead and not r.client.isOpen and r.room.dash==nil)
		r.free("three errors")
		r.done()
	end)
	test("another screen over a race: camera and controls back while it is open, then the race again",function()
		local r=rig();r.lock();r.frame(240);device.core:begin("s","dash")
		r.modal=true;r.frame()
		assert(not r.room.held and r.room.locks==0 and not screen.on and not device.bound and r.inputs[#r.inputs].k=="dashUp"and r.client.seat and r.drawn)
		r.modal=false;r.frame();assert(r.room.held and screen.on);r.frame();assert(device.bound)
		r.client:leave();r.free("after")
		-- A room that cannot give its camera yet is asked again.
		r.room.refuse=true;r.lock();r.frame(3);assert(not r.room.held and r.drawn);r.room.refuse=false;r.frame();assert(r.room.held)
		r.client:leave();r.done()
	end)
	test("a dashUp refused after the buttons closed is sent again, with nobody holding",function()
		local r=rig();r.lock();r.frame(240);device.core:begin("s","dash")
		r.modal=true;r.frame();local up=r.inputs[#r.inputs];assert(up.k=="dashUp"and not device.core.open)
		r.fire({kind="refusedInput",r="race-1",n=up.n,reason="late"})
		local again=r.inputs[#r.inputs];assert(again~=up and again.k=="dashUp"and again.n>up.n and not device.core.down)
		r.frame(5);assert(not r.client.seat.predict.runner.dash)
		r.client:leave();r.done()
	end)
	test("a trial the server drops says why and gives everything back",function()
		local r=rig();r.lock("trial",1,true);r.frame(240);assert(r.room.held)
		r.fire({kind="aborted",r="trial-1",reason="PetChanged"});assert(r.notes[#r.notes]=="dash.reason.PetChanged");r.free("trial dropped");r.done()
	end)
	test("RoomView letting go by itself is noticed: the buttons close and the race takes the camera again",function()
		local r=rig();r.lock();r.frame(240);device.core:begin("s","dash")
		r.room:leaveDash();r.room.refuse=true;r.frame()
		assert(not r.client.holding and not device.bound and not screen.on and r.inputs[#r.inputs].k=="dashUp"and r.room.locks==0)
		r.room.refuse=false;r.frame(2);assert(r.room.held and r.room.locks==1 and screen.on and device.bound)
		r.client:leave();r.free("after");r.done()
	end)
	test("a card that cannot be drawn leaves no shade; the gate says so and the results still end",function()
		local Kit=require(client.DeckKit)
		local shades,plainWarn=0,0
		Kit.modalShade=function()return{}end
		Kit.shadeOpen=function()shades+=1 end
		Kit.shadeClose=function()shades-=1;return true end
		Kit.measure=function()plainWarn+=1;error("no font")end
		local gui=Instance.new("Folder")
		assert(openCard({playerGui=gui,name="Gate",title="T",lines={"a"},buttons={{name="A",text="a",act=function()end}}})==nil)
		assert(shades==0 and #gui:GetChildren()==0)
		local r=rig();screenFails="Gate";r.client:gate();assert(r.client.card==nil and not r.client:panelOpen()and r.notes[#r.notes]=="dash.reason.other")
		r.client.prompt.Triggered:Fire();assert(r.client.errors==0)
		screenFails="Results";r.lock();r.frame(5);r.fire({kind="result",r="race-1",mode="fun",seats={},seat=1,place=1,us=41000000})
		r.client.seat.cardAt=-1;r.frame(20);r.free("no results card")
		screenFails=nil;r.done()
	end)
	test("other screens: Names and the snack reveal hold a race back; without Dash built they change nothing",function()
		local open={}
		local function closed()return{isOpen=function()return false end}end
		local ui={isHueOpen=function()return false end,names={isOpen=function()return open.names==true end},snacks={reveal={isOpen=function()return open.snack==true end}}}
		local any=require(client.InitModal)(ui,function()return false end,nil,nil,nil,nil)
		open.names,open.snack=true,true;assert(not any()and not any(true),"live: as before")
		ui.dash={panelOpen=function()return open.card==true end}
		assert(any()and any(true));open.names=false;assert(any(true));open.snack=false;assert(not any()and not any(true))
		open.card=true;assert(any()and not any(true))
		ui.names,ui.snacks=nil,nil;open.card=false;assert(not any(true));ui.hub=closed();assert(not any(true))
	end)
	test("gather: the player walks and the garden is not held; the Deck asks; a queue is asked too (beta 14 F2)",function()
		local r=rig()
		r.fire({kind="joined",raceId="race-1",seat=1,mode="fun"})
		r.roster({v=1,phase="gather",raceId="race-1",mode="fun",endsAt=12,seats={{seat=1,userId=7,petId="pip"}},queue={}})
		r.frame(30);assert(not r.room.held and not r.client:held()and r.line and string.find(r.line,"Just for Fun",1,true))
		local pings=0;for _,p in ipairs(r.requests)do if p.kind=="ping"then pings+=1 end end;assert(pings>=1)
		assert(r.client:askLeave(function()end))
		r.fire({kind="refused",raceId="race-1",reason="Far"});r.frame(30);assert(r.line==""and r.notes[#r.notes]=="dash.reason.Far")
		r.fire({kind="joined",raceId="race-2",seat=1,mode="fun",promoted=true,closer=true});assert(#r.notes==2 and r.notes[2]=="dash.reason.Far")
		r.fire({kind="refused",raceId="race-2",reason="Far"})
		r.client:gate();card:pick("Stats");local join=r.requests[#r.requests]
		r.fire({kind="reply",request="join",seq=join.seq,ok=true,reason="WrongBand"});assert(r.client.queued)
		local played=false
		assert(r.client:askLeave(function()played=true end)and asked and asked.title==UICopy.get("dash.line.title")and r.requests[#r.requests].kind~="leave")
		asked.alt.onSelect();assert(played and r.requests[#r.requests].kind=="leave"and not r.client.queued and r.notes[#r.notes]=="dash.line.left")
		r.done()
	end)
	test("the line (beta 14 F2): a tappable rail line; Stay keeps the place; the gate prompt reads Leave line, held; promotion closes the question; Strayed reads as leaving",function()
		local r=rig();r.frame(2)
		r.client:gate();card:pick("Fun");local join=r.requests[#r.requests]
		r.fire({kind="reply",request="join",seq=join.seq,ok=true,reason="Queued"});r.frame(30)
		assert(r.client:waiting()=="line"and r.line==UICopy.get("dash.queue")and r.lineData.activate,"the line can be tapped")
		asked=nil;assert(r.lineData.activate()and asked)
		assert(asked.title==UICopy.get("dash.line.title")and asked.confirm==UICopy.get("dash.line.no")and asked.alt.text==UICopy.get("dash.line.yes")and asked.alt.after==Client.AltAfter)
		r.frame(30);assert(not r.client.prompt.Enabled,"the gate prompt is off while the question is up")
		asked.onConfirm();asked.onClosed(true);assert(r.client.queued and r.client.lineAsk==nil,"Stay in line keeps the place")
		r.frame(30);assert(r.client.prompt.Enabled and r.client.prompt.ActionText==UICopy.get("dash.line.prompt")and r.client.prompt.HoldDuration==Client.LeaveHold)
		-- Promotion from the line into a gather seat: the open question goes, and its Leave does nothing any more.
		asked=nil;r.lineData.activate();local stale=asked
		r.fire({kind="joined",raceId="race-1",seat=1,mode="fun",promoted=true});r.frame(30)
		assert(asked==nil and r.client:waiting()=="gather","closed by the promotion")
		local sent=#r.requests;stale.alt.onSelect();assert(#r.requests==sent and r.client.seat,"a stale Leave sends nothing")
		r.roster({v=1,phase="gather",raceId="race-1",mode="fun",endsAt=1e9,seats={{seat=1,userId=7,petId="pip"}},queue={}});r.frame(30)
		assert(r.lineData.activate and string.find(r.line,"Just for Fun",1,true),"the gather line can be tapped too")
		r.fire({kind="refused",raceId="race-1",reason="Strayed"});r.frame(30)
		assert(r.notes[#r.notes]=="dash.line.left"and r.client:waiting()==nil and r.line=="")
		r.frame(30);assert(r.client.prompt.ActionText==UICopy.get("dash.prompt")and r.client.prompt.HoldDuration==0)
		r.done()
	end)
	test("rivals and pals: drawn from the states, at most 400 ms on; parts stay under the cap; another race's state is ignored",function()
		local r=rig();r.lock("fun",8);r.frame(12)
		local heat=r.client.heat
		assert(heat and heat.byUser[7]and not r.client:racing(8)and r.client:racing(7))
		local pals=0;for _,track in pairs(heat.tracks)do if track.visual then pals+=1 end end;assert(pals==7,"one a frame")
		assert(r.client.props.count<=33 and r.client.props.count<=Props.MaxParts and #workspace:FindFirstChild(Props.FolderName):GetChildren()<=Props.MaxParts)
		now=r.goAt
		for _=1,200 do Sim.step(r.race)end
		r.state.OnClientEvent:Fire(Wire.encode("race-1",r.race,Stats.UnitsPerCs))
		r.frame(30)
		local track=heat.tracks[2];assert(track.tick==200 and track.draw>0)
		r.state.OnClientEvent:Fire(Wire.encode("older",r.race,Stats.UnitsPerCs));r.state.OnClientEvent:Fire("junk");r.state.OnClientEvent:Fire(nil)
		local unit=heat.unit
		local at={cs=1000,pace=100,tick=200,flags={}}
		assert(Client.ahead(at,200,unit)==1000 and Client.ahead(at,100000,unit)==1000+unit*40)
		at.flags={tumble=true};assert(Client.ahead(at,240,unit)==1000)
		at.flags={finished=true};assert(Client.ahead(at,240,unit)==1000)
		-- A level 50 pet at plain pace covers 6.75 studs a second.
		assert(math.abs(unit*100-675)<1)
		r.client:leave()
		local held={};for _,t in pairs(heat.tracks)do table.insert(held,t.visual)end
		r.room.mode="Board";r.frame();for _,v in ipairs(held)do assert(v.gone)end
		r.room.mode="Room";r.frame(10);r.roster({v=1,phase="idle",seats={},queue={}})
		assert(r.client.heat==nil);r.frame(60);assert(r.client.props.share==0)
		r.folder:SetAttribute(Wire.RosterAttribute,"{bad");r.folder:SetAttribute(Wire.RosterAttribute,nil)
		r.done()
	end)
	test("Reduced Motion: no hoop rise, no spin, no hop",function()
		local r=rig();r.reduced=true;r.lock();r.frame(2);assert(r.client.props.share==1)
		local Pose=require(client.DashPose)
		for _,reduced in ipairs({false,true})do
			local v,s=pet(),Pose.state();Pose.begin(v,s)
			local pitch,high=0,0
			for i=1,60 do
				Pose.step(v,s,1000,false,1,{tumble=true},true,1/60,reduced)
				pitch=math.max(pitch,math.abs(v.carePitch))
			end
			assert(reduced==(pitch==0)and v.activitySit==true,"a sit")
			local _,base=require(Shared.DashCourse).at(1000,false,1)
			Pose.step(v,s,1000,false,1,{air=true},true,1/60,reduced)
			for _=1,40 do Pose.step(v,s,1000,false,1,{},true,1/60,reduced);high=math.max(high,v.origin.Y-base)end
			assert(if reduced then high<.7 else high>.9)
			Pose.clear(v);assert(v.parkPose==false and v.carePitch==0 and v.activitySit==false)
		end
		r.client:leave();r.done()
	end)
	test("a server-drawn race: after two disagreements the own pet follows the states",function()
		local r=rig();r.lock();r.frame(240)
		r.client.seat.predict.serverRender=true
		for _=1,120 do Sim.step(r.race)end
		r.state.OnClientEvent:Fire(Wire.encode("race-1",r.race,Stats.UnitsPerCs));r.frame(20)
		assert(r.client.seat.track.tick==120 and r.client.seat.raw==r.client.seat.track.draw and r.drawn)
		r.fire({kind="judged",r="race-1",jump=1,result=1,tick=100});assert(screen.word=="Perfect!")
		r.client:leave();r.done()
	end)
	test("Things to do's readers: engaged from the gather seat on, held() only from the countdown; the summary follows the roster",function()
		local c=setmetatable({isOpen=true,d={state=function()return nil end}},Client)
		assert(not c:engaged()and c:summary().phase=="idle"and c:summary().count==0 and c:summary().raced==false)
		for _,state in ipairs({{seat={phase="gather"}},{queued=true},{pending={seq=1}},{card={closed=false}}})do
			local e=setmetatable(state,Client);assert(e:engaged()==true and not e:held())
		end
		assert(not setmetatable({card={closed=true}},Client):engaged())
		c.roster={phase="gather",seats={{},{},{pal=true},5}};assert(c:summary().phase=="gather"and c:summary().count==2)
		for _,phase in ipairs({"countdown","race","results"})do c.roster={phase=phase,seats={}};assert(c:summary().phase=="live",phase)end
		c.raced=true;assert(c:summary().raced==true)
		c.dead=true;assert(c:summary()==nil);c.dead=nil;c.isOpen=false;assert(c:summary()==nil)
	end)
	test("junk packets change nothing",function()
		local r=rig()
		for _,junk in ipairs({1,"x",{},{kind="locked"},{kind="locked",raceId="r",seat="1"},{kind="joined"},{kind="result",r="r"},{kind="zoom"},{kind="reply"},{kind="refusedInput",r="race-1",n=5}})do r.fire(junk)end
		assert(r.client.errors==0 and not r.room.held)
		r.fire({kind="locked",raceId="r",seat=1,plan={},goAt=5});assert(r.client.seat==nil and r.requests[#r.requests].kind=="leave")
		r.lock();r.frame(3);for _,odd in ipairs({{kind="zoom",r="race-1",tick="x"},{kind="refusedInput",r="race-1"},{kind="result",r="other"}})do r.fire(odd)end
		assert(r.client.errors==0 and r.client.seat.phase=="countdown")
		r.client:leave();r.done()
	end)
	test("RoomView: enterDash and leaveDash always pair, whatever the camera or character became",function()
		local Room=require(client.RoomViewDash) -- the hooks alone, cut from RoomView.lua by the runner
		local lock=Room.lock
		local function make()
			local camera={Parent=true,CFrame=CFrame.new(0,5,0),Focus=CFrame.new(0,0,0),FieldOfView=70,CameraType="Custom"}
			local room=setmetatable({mode="Room",target="Room",updateControls=function()end,cancelCameraTween=function()end},Room)
			workspace.CurrentCamera=camera
			local root={Position=Vector3.new(1,2,3),Parent={}}
			room.cameraIdentity=function()return workspace.CurrentCamera,room.root,room.humanoid end
			room.root,room.humanoid=root,{Health=100}
			return room,camera
		end
		local room,camera=make()
		assert(room:enterDash()and room:enterDash()and lock:holds("dash")and lock:count()==1 and camera.CameraType==Enum.CameraType.Scriptable)
		camera.CameraType="Custom";room:dashCamera(CFrame.new(9,9,9),58);assert(camera.FieldOfView==58 and camera.CameraType==Enum.CameraType.Scriptable,"a respawn's reset is undone")
		assert(room:leaveDash()and not room:leaveDash()and not lock:holds("dash")and camera.CameraType==Enum.CameraType.Custom and camera.FieldOfView==70 and camera.CFrame.Y==5)
		assert(camera.CameraSubject==room.humanoid)
		room,camera=make();room:enterDash();room.root={Position=Vector3.new(50,2,3),Parent={}};room:leaveDash()
		assert(camera.CFrame.X==55 and camera.FieldOfView==65 and lock:count()==0,"a new character: behind it")
		-- The avatar: hidden for a race, not for the gate card; a respawn hides the new one; always given back.
		assert(Room.hidden==0)
		room=make();room:enterDash(true);assert(Room.hidden==0);room:enterDash();assert(Room.hidden==1 and lock:count()==1)
		room.root={Position=Vector3.zero,Parent={}};room:dashCamera(CFrame.new(0,0,0),58);assert(Room.hidden==1 and room.dashHeld.visibility.character==room.root.Parent)
		room.root=nil;room:dashCamera(CFrame.new(0,0,0),58);assert(Room.hidden==0,"no avatar just now")
		room.root={Position=Vector3.zero,Parent={}};room:dashCamera(CFrame.new(0,0,0),58);assert(Room.hidden==1)
		room:leaveDash();assert(Room.hidden==0 and not room:leaveDash()and Room.hidden==0)
		room,camera=make();room:enterDash();workspace.CurrentCamera=nil;room:leaveDash();assert(lock:count()==0)
		-- The gamepad's selection: put away for the race, given back unless it cannot be or something else has it.
		local gui,button=Room.gui,{ok=true}
		for _,case in ipairs({{want=button},{ok=false},{taken=true},{board=true},{gone=true}})do
			room=make();button.ok=case.ok~=false;gui.SelectedObject=button;room:enterDash();assert(gui.SelectedObject==nil)
			local other={}
			if case.taken then gui.SelectedObject=other end
			if case.board then room.target="Board"end
			if case.gone then room.destroyed=true end
			room:leaveDash()
			assert(gui.SelectedObject==(if case.taken then other else case.want))
			gui.SelectedObject=nil
		end
		for _,odd in ipairs({{mode="Board"},{target="Board"},{busy=true},{destroyed=true},{arrivalPlacementPending=true}})do
			room=make();for k,v in pairs(odd)do room[k]=v end
			assert(not room:enterDash()and lock:count()==0)
		end
		local canceled=false
		room=make();room.focusing=true;room.focusTransition={destroyed=false,cancel=function()canceled=true end};room._useRoomCamera=function(self)self.focusing=false end
		assert(room:enterDash()and canceled and not room.focusing);room:leaveDash()
	end)
	Dash.inject(nil);Instance.new=plain
	return{passed=#cases,cases=cases}
end
