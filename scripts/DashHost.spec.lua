-- Garden Dash host (V3-DASH-BUILD-PLAN-2026-11-22, S6): remotes, board checks, tags, rate limits, the kill switches and
-- the prize queue, with fake players and remotes over the real director, garden and save transactions.
-- Isolated adapters only; no DataStore or user writes.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.DashHost)(ServerScriptService.Server)
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Dash=require(Shared.Dash)
	local Wire=require(Shared.DashWire)
	local Course=require(Shared.DashCourse)
	local Sim=require(Shared.DashSim)
	local Catalog=require(Shared.EggCatalog)
	local Stats=require(Shared.StatCatalog)
	local Host=require(server.DashHost)
	local Garden=require(server.GardenState)
	local H=require(server.HatchProgress)
	local Close=require(server.CloseProgress)
	local DEN=require(Shared.DenLayout).Pocket
	local IN_DEN=Vector3.new(-7,7,-106)
	local S=require(server.DashState)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
	local function dash(env)env=env or {};env.flags=env.flags or {GardenDash=true};env.studio=true;Dash.inject(env)end
	local gx,gy,gz=Course.Pad.x/100,Course.Pad.y/100,Course.Pad.z/100
	local function signal()
		local s={list={}}
		function s:Connect(fn)table.insert(s.list,fn);return{Disconnect=function()local at=table.find(s.list,fn);if at then table.remove(s.list,at)end end}end
		function s.fire(...)for _,fn in ipairs(table.clone(s.list))do fn(...)end end
		return s
	end
	local function attributes()
		local node={attrs={},Parent=true}
		function node:SetAttribute(name,value)self.attrs[name]=value end
		return node
	end
	local WIN={kind="race",mode="stats",band=5,place=8,us=46000000,inputs=1000000,seed=4294967295,prize=true}
	local function rig(count)
		local c={now=5000,serial=0,players={},boards={},remotes={},parked={},beat=signal(),shared=attributes(),sold={},published=0}
		local function player(id)
			local p={UserId=id,Parent=true,DisplayName="Racer"..id}
			local root={Position=Vector3.new(gx+1,gy+3,gz),CFrame=nil}
			p.root=root;p.humanoid={Health=100}
			p.Character={FindFirstChild=function(_,name)return if name=="HumanoidRootPart"then root else nil end,
				FindFirstChildOfClass=function()return p.humanoid end,IsDescendantOf=function()return true end}
			c.players[id]=p
			local db,ctl={},{now=1700000000,serial=0}
			local adapter={now=function()return ctl.now end,guid=function()ctl.serial+=1;return id.."-"..ctl.serial end,random=function()return .1 end,wait=function()end,
				update=function(key,transform)
					if ctl.down then error("down")end
					local value=transform(copy(db[key]))
					if value then db[key]=copy(value)end
					if ctl.failAfter then ctl.failAfter=false;error("after commit")end
					return copy(value)
				end}
			H.load(id,{rank=1},adapter)
			local key="player_"..id
			db[key].hatching.inventoryMask=Catalog.bit("pip");db[key].hatching.lease={token="",expiresAt=0}
			db[key].hatching.petStats={pip={speed=Stats.xpFor(20),energy=Stats.xpFor(20),jump=Stats.xpFor(20)}};db[key].hatching.statsSeed=1
			p.db,p.ctl,p.key=db,ctl,key
			local board={player=p,mode="Room",closing=false,profileReady=true,profile={companionId="pip"},nursery=H.load(id,{rank=1},adapter),
				folder=attributes(),characterGeneration=1,companionGeneration=1}
			assert(board.nursery.status=="Ready")
			p.board=board;c.boards[p]=board
			return p
		end
		c.player=player
		function c.input(board)
			local p=board.player
			return{petId=board.profile.companionId,owned=true,alive=p.humanoid.Health>0,characterId=board.characterGeneration,petGeneration=board.companionGeneration,
				position=p.root.Position,anchor=Vector3.new(p.root.Position.X,gy,p.root.Position.Z),mode=board.mode,yaw=0,charmVisible=true}
		end
		c.garden=Garden.new({sharedToyEnabled=false,now=function()return c.now end,publish=function(s)c.snapshot=s end})
		c.d={remotes={},shared=c.shared,garden=c.garden,boards=c.boards,players={GetPlayerByUserId=function(_,id)return c.players[id]end},nursery=H,
			economy={source=function(p,amount,balance,kind,sku)table.insert(c.sold,{id=p.UserId,amount=amount,balance=balance,sku=sku})end},
			canProgress=function(board)return board.profileReady and board.nursery.status=="Ready"and not board.nurseryBusy end,gardenInput=c.input,
			publishNursery=function()c.published+=1 end,publishState=function()end,dayOf=function(now)return tostring(math.floor(now/86400))end,
			now=function()return c.now end,clock=function()return c.now end,guid=function()c.serial+=1;return "id-"..c.serial end,seed=function()return 900+c.serial end,
			remote=function(_,name)
				local remote={sent={},OnServerEvent=signal()}
				function remote:FireClient(to,packet)table.insert(self.sent,{to=to,packet=packet})end
				function remote:FireAllClients(packet)table.insert(self.sent,{packet=packet})end
				c.remotes[name]=remote
				return remote
			end,heartbeat=c.beat,
			spawn=function(fn)local ok,e=coroutine.resume(coroutine.create(fn));assert(ok,e)end,
			wait=function(seconds)table.insert(c.parked,{due=c.now+seconds,co=coroutine.running()});coroutine.yield()end,
			-- The Play Den's layout while a case opens it (nil: every other case runs exactly as before).
			den=function()return c.den end}
		for id=1,count or 1 do player(id)end
		c.host=Host.mount(c.d)
		function c.run(seconds,each)
			for _=1,math.floor(seconds*30+.5)do
				c.now+=1/30
				if each then each()end
				c.garden:step(1/30,function()local out={};for p,board in pairs(c.boards)do out[p.UserId]=c.input(board)end;return out end)
				c.beat.fire()
				for i=#c.parked,1,-1 do
					local p=c.parked[i]
					if p.due<=c.now then table.remove(c.parked,i);local ok,e=coroutine.resume(p.co);assert(ok,e)end
				end
			end
		end
		function c.ask(id,kind,seq,more)
			local packet={kind=kind,seq=seq,petId="pip",petGeneration=1,characterId=c.players[id].board.characterGeneration}
			for key,value in pairs(more or {})do packet[key]=value end
			c.remotes.DashRequest.OnServerEvent.fire(c.players[id],packet)
			local sent=c.remotes.DashEvent.sent
			for i=#sent,1,-1 do if sent[i].to==c.players[id]and sent[i].packet.kind=="reply"then return sent[i].packet end end
		end
		function c.got(id,kind)local out={};for _,e in ipairs(c.remotes.DashEvent.sent)do if e.to==c.players[id]and e.packet.kind==kind then table.insert(out,e.packet)end end;return out end
		function c.pilot(id)
			local st={n=0,at=0}
			return function()
				local record,run=c.host.director:runner(id)
				if not record or run.phase~="race"then return end
				local r=run.race.runners[record.seat];local goal=r.list[r.next]
				if goal and not r.finishUs and st.at~=r.next and(Sim.takeoff(r,goal)-r.pos)/r.step<=10 then
					st.at=r.next;st.n+=1
					c.remotes.DashInput.OnServerEvent.fire(c.players[id],{r=run.id,n=st.n,t=run.race.tick+8,k="jump"})
				end
			end
		end
		return c
	end
	local ok,problem=pcall(function()
		test("the ceiling is off: mount makes nothing at all",function()
			dash({flags={}});local c=rig(1);assert(c.host==nil and next(c.remotes)==nil and #c.beat.list==0)
		end)
		test("the switch is off: no remotes, no roster, no tags, no writes; on makes them once; off again ends the race and frees the pet",function()
			dash({race=false});local c=rig(1);c.run(2);assert(c.host and next(c.remotes)==nil and next(c.shared.attrs)==nil)
			dash();c.run(1);assert(c.remotes.DashRequest and c.shared.attrs.Dash)
			local first=c.remotes.DashRequest
			assert(c.ask(1,"join",1).ok);c.run(25);assert(c.host.director.heat.phase=="race"and c.players[1].board.dashHeld and c.garden.actors[1].dash)
			dash({race=false});c.run(.1)
			assert(c.players[1].board.dashHeld==nil and c.garden.actors[1].dash==nil and c.shared.attrs.Dash==nil and c.got(1,"aborted")[1].reason=="Off")
			local before=#c.remotes.DashEvent.sent;c.remotes.DashRequest.OnServerEvent.fire(c.players[1],{kind="leave",seq=9});c.remotes.DashInput.OnServerEvent.fire(c.players[1],{})
			c.run(60);assert(#c.remotes.DashEvent.sent==before and c.players[1].board.dashQueue==nil and c.players[1].db.player_1.hatching.dash==nil)
			dash();c.run(1);assert(c.remotes.DashRequest==first and c.ask(1,"join",10).ok)
		end)
		test("a whole race: joined at the gate, inputs accepted, 2 Stars saved once, analytics from the receipt, pet free",function()
			dash();local c=rig(1);c.run(1);local p=c.players[1];local wallet=p.board.nursery.state.nectar
			assert(c.ask(1,"join",1).ok);c.run(24);c.run(60,c.pilot(1))
			assert(p.db.player_1.hatching.nectar==wallet+2 and p.db.player_1.hatching.dash.paid==1 and p.board.dashFlight==nil and #p.board.dashQueue==0)
			assert(#c.sold==1 and c.sold[1].amount==2 and c.sold[1].balance==wallet+2 and c.sold[1].sku=="GardenDash")
			assert(p.board.dashHeld==nil and c.garden.actors[1].dash==nil and #c.got(1,"result")==1 and not p.board.nurseryBusy)
			assert(string.find(p.board.folder.attrs.DashMarks,'"ribbons"',1,true)and #c.remotes.DashState.sent>100)
			for _,s in ipairs(c.remotes.DashState.sent)do assert(Wire.decode(s.packet)and buffer.len(s.packet)<=120)end
		end)
		test("prizes off alone: the race runs, nothing is saved but a best Time Trial",function()
			dash({prizes=false});local c=rig(1);c.run(1);c.ask(1,"join",1);c.run(24);c.run(60,c.pilot(1))
			local p=c.players[1];assert(#c.got(1,"result")==1 and p.db.player_1.hatching.dash==nil)
			c.ask(1,"trial",2);c.run(60,c.pilot(1));local saved=p.db.player_1.hatching.dash;assert(saved.best==nil and saved.trials[S.Course]and saved.cups==0 and saved.paid==0 and #c.got(1,"cup")==0)
			dash();c.ask(1,"trial",3);c.run(60,c.pilot(1));assert(p.db.player_1.hatching.dash.cups>0 and #c.got(1,"cup")==1)
		end)
		test("join checks, each with its reason; nothing is tagged by a refusal",function()
			dash();local c=rig(1);c.run(1);local p=c.players[1];local board=p.board;local seq=0
			local function refused(reason,set,clear)
				set();seq+=1;c.run(.4);local r=c.ask(1,"join",seq);clear();assert(not r.ok and r.reason==reason,reason.." got "..tostring(r.reason));assert(board.dashHeld==nil)
			end
			local home=p.root.Position
			refused("Far",function()p.root.Position=home+Vector3.new(14,0,0)end,function()p.root.Position=home end)
			refused("Far",function()p.root.Position=home+Vector3.new(0,40,0)end,function()p.root.Position=home end)
			refused("Far",function()p.root.Position=Vector3.new(0/0,0,0)end,function()p.root.Position=home end)
			refused("Saving",function()board.nurseryBusy=true end,function()board.nurseryBusy=nil end)
			refused("Saving",function()board.nursery.status="Temporary"end,function()board.nursery.status="Ready"end)
			refused("Deck",function()board.mode="Board"end,function()board.mode="Room"end)
			refused("NoCharacter",function()p.humanoid.Health=0 end,function()p.humanoid.Health=100 end)
			refused("Carried",function()board.careEquip={}end,function()board.careEquip=nil end)
			refused("Petting",function()board.petContact={lease={}}end,function()board.petContact=nil end)
			refused("Hatching",function()board.nursery.state.lastHatch={}end,function()board.nursery.state.lastHatch=nil end)
			local mask=board.nursery.state.inventoryMask
			refused("NoPet",function()board.nursery.state.inventoryMask=0 end,function()board.nursery.state.inventoryMask=mask end)
			for _,odd in ipairs({{petId="blip"},{petGeneration=9},{characterId=9}})do seq+=1;c.run(.4);local r=c.ask(1,"join",seq,odd);assert(r.reason=="StalePet")end
			seq+=1;c.run(.4);assert(c.ask(1,"join",seq).ok and board.dashHeld)
		end)
		test("the levels come from the saved XP, whatever a packet or the profile says",function()
			dash();local c=rig(1);c.run(1);c.players[1].board.folder:SetAttribute("PetStats",'{"pets":{"pip":{"speed":99}}}')
			local r=c.ask(1,"join",1,{mode="stats",levels={speed=99},band=5});assert(r.ok);c.run(24)
			local locked=c.got(1,"locked")[1];assert(locked.levels.speed==20 and c.host.director.heat.band==2)
		end)
		test("seq and throttle: a repeat gets the same answer and does nothing twice, an old one is refused, leaving never waits",function()
			dash();local c=rig(1);c.run(1)
			local a=c.ask(1,"join",5);local b=c.ask(1,"join",5);assert(a==b and #c.host.director.heat.seats==1)
			assert(c.ask(1,"join",4).reason=="OldRequest");assert(c.ask(1,"trial",6).reason=="Throttled")
			assert(c.ask(1,"leave",7).ok and c.host.director.heat==nil and c.players[1].board.dashHeld==nil)
			assert(c.ask(1,"ping",8).at==c.now)
		end)
		test("a hostile client: 2,000 packets of rubbish in a second change nothing, get few answers and stop nobody",function()
			dash();local c=rig(2);c.run(1);c.ask(1,"join",1);c.ask(2,"join",1);c.run(24)
			local director=c.host.director;local runner=director.heat.race.runners[1];local before=#c.remotes.DashEvent.sent
			local rubbish={nil,5,"x",{},{r=1},{r=director.heat.id,n=1},{r=director.heat.id,n=0/0,t=1,k="jump"},{r=director.heat.id,n=1,t=math.huge,k="jump"},{r="old",n=5,t=5,k="jump"},{kind="join"},{kind="join",seq=1e99}}
			for i=1,2000 do
				local packet=rubbish[i%12+1]
				c.remotes.DashInput.OnServerEvent.fire(c.players[1],packet);c.remotes.DashRequest.OnServerEvent.fire(c.players[1],packet)
			end
			assert(runner.inputs==0 and #c.remotes.DashEvent.sent-before<=20 and #director.heat.seats==2 and director.errors==0)
			c.run(60,c.pilot(2));assert(#c.got(2,"result")==1 and c.players[2].db.player_2.hatching.dash.paid==1)
			local one=c.players[1].db.player_1.hatching.dash;assert(one==nil or one.paid==0,"an ignored pet earns nothing")
		end)
		test("the Deck forfeits at once and is never blocked; another pet forfeits; the other racer races on",function()
			dash();local c=rig(3);c.run(1);for id=1,3 do c.ask(id,"join",1)end;c.run(25)
			c.players[1].board.mode="Board";c.run(.1);assert(c.players[1].board.dashHeld==nil and c.garden.actors[1].dash==nil and c.garden.actors[1].mode=="Board")
			c.players[2].board.profile.companionId="blip";c.run(.1);assert(c.players[2].board.dashHeld==nil)
			assert(#c.host.director.heat.seats==1);c.run(60,c.pilot(3));assert(#c.got(3,"result")==1 and #c.got(1,"result")==0 and c.players[1].board.dashQueue==nil)
		end)
		test("a respawn keeps the seat and the tag",function()
			dash();local c=rig(1);c.run(1);c.ask(1,"join",1);c.run(25);local p=c.players[1]
			p.humanoid.Health=0;c.run(1);p.humanoid.Health=100;p.board.characterGeneration=2;c.run(1)
			assert(c.garden.actors[1].dash and p.board.dashHeld and #c.host.director.heat.seats==1)
		end)
		test("a save that is busy or pending never loses a prize and never overlaps another write",function()
			dash();local c=rig(1);c.run(1);local p=c.players[1];local board=p.board;c.ask(1,"join",1);c.run(24)
			board.payoutPending=true;c.run(60,c.pilot(1));assert(#board.dashQueue==1 and p.db.player_1.hatching.dash==nil)
			board.payoutPending=nil;board.lastNurseryCommand=c.now;c.run(1);assert(#board.dashQueue==1,"a quiet moment after the player's own command")
			p.ctl.failAfter=true;c.run(6);assert(board.nursery.pending and p.db.player_1.hatching.dash.paid==1 and #c.sold==0,"landed, unproven")
			c.run(10);assert(p.db.player_1.hatching.dash.paid==1);H.retry(board.nursery);c.run(5)
			assert(#board.dashQueue==0 and board.dashFlight==nil and #c.sold==1 and p.db.player_1.hatching.dash.paid==1)
		end)
		test("a store that is down for a whole race pays once when it is back",function()
			dash();local c=rig(1);c.run(1);local p=c.players[1];local wallet=p.board.nursery.state.nectar;c.ask(1,"join",1);c.run(24);p.ctl.down=true
			c.run(60,c.pilot(1));assert(p.board.nursery.pending);c.run(30);p.ctl.down=false;H.retry(p.board.nursery);c.run(10)
			assert(p.db.player_1.hatching.nectar==wallet+2 and #p.board.dashQueue==0)
		end)
		test("eight results waiting are written together, none lost",function()
			dash();local c=rig(1);c.run(1);local p=c.players[1];local board=p.board;local wallet=board.nursery.state.nectar
			board.payoutPending=true;for _=1,11 do c.host:finished(1,table.clone(WIN))end;board.payoutPending=nil;c.run(8)
			local saved=p.db.player_1.hatching;assert(#board.dashQueue==0 and saved.dash.ribbons.green==11 and saved.nectar==wallet+10 and #c.sold==1)
		end)
		test("a batch the save refuses is never deleted: kept, one at a time, slower each try, warned; it saves when it can",function()
			dash();local c=rig(1);c.run(1);local p=c.players[1];local board=p.board
			local real,calls,refuse=H.dashResults,0,true
			c.d.nursery=setmetatable({dashResults=function(h,id,list)calls+=1;if refuse then return false,"InvalidData"end;return real(h,id,list)end},{__index=H})
			board.payoutPending=true;for i=1,4 do local r=table.clone(WIN);r.seed=i;c.host:finished(1,r)end;board.payoutPending=nil
			c.run(120);assert(#board.dashQueue==4 and calls>=4 and calls<=7 and board.dashBatch==1 and not board.nurseryBusy,calls)
			refuse=false;c.run(90);assert(#board.dashQueue==0 and p.db.player_1.hatching.dash.ribbons.green==4 and board.dashBatch==nil and board.dashTries==nil)
			-- only a malformed result is given up, and alone
			board.payoutPending=true;c.host:finished(1,table.clone(WIN));table.insert(board.dashQueue,1,{kind="race"});board.payoutPending=nil
			c.run(90);assert(#board.dashQueue==0 and p.db.player_1.hatching.dash.ribbons.green==5)
		end)
		test("nothing is written under a live round: in Room, or once the round is over",function()
			dash();local c=rig(1);c.run(1);local p=c.players[1];local board=p.board
			board.mode="Board";board.round={over=false};c.host:finished(1,table.clone(WIN));c.run(20);assert(#board.dashQueue==1 and p.db.player_1.hatching.dash==nil)
			board.round.over=true;c.run(4);assert(#board.dashQueue==0)
			board.round.over=false;c.host:finished(1,table.clone(WIN));c.run(5);board.mode="Room";c.run(4);assert(#board.dashQueue==0 and p.db.player_1.hatching.dash.ribbons.green==2)
		end)
		test("eight tags come off in one garden snapshot",function()
			dash();local c=rig(8);c.run(1);for id=1,8 do c.ask(id,"join",1)end;c.run(24)
			local writes=0;local publish=c.garden.publish;c.garden.publish=function(self)if self.dirty then writes+=1 end;return publish(self)end
			local director=c.host.director;local seen=false
			for _=1,3000 do
				writes=0;c.now+=1/30;c.beat.fire()
				if director.heat and director.heat.phase=="results"then seen=true;break end
			end
			assert(seen and writes==1,writes);for id=1,8 do assert(c.players[id].board.dashHeld==nil and c.garden.actors[id].dash==nil)end
		end)
		test("from the line: 12 to 16 studs is told to come closer and refused at the countdown; a pet being petted keeps its place",function()
			dash();local c=rig(11);c.run(1);for id=1,11 do c.ask(id,"join",1)end
			local home=c.players[9].root.Position;c.players[9].root.Position=home+Vector3.new(13,0,0);c.players[10].board.petContact={lease={}}
			c.run(.1);c.host.director:abort("Test");c.run(1)
			assert(c.got(9,"joined")[1].closer and c.got(11,"joined")[1].promoted and not c.got(11,"joined")[1].closer and c.players[10].board.dashHeld==nil and #c.got(10,"refused")==0)
			c.run(24);assert(c.got(9,"refused")[1].reason=="Far"and c.players[9].board.dashHeld==nil)
		end)
		-- Beta 14 F2: the rope ring (DashRing): Enter 3.4, Stray 6.5 for 1 s.
		test("the rope ring, a gather seat: walk in from 10 studs; once in, 6.4 stays, 6.6 for a second leaves as Strayed; a new join latches afresh",function()
			dash();local c=rig(1);c.run(1);local p=c.players[1];local function at(dx)p.root.Position=Vector3.new(gx+dx,gy+3,gz)end
			at(10);assert(c.ask(1,"join",1).ok);c.run(2);assert(#c.host.director.heat.seats==1,"walking in from the prompt is not straying")
			p.board.profileReady=false;c.run(1);assert(#c.host.director.heat.seats==1,"a gather seat is not removed for a save in flight");p.board.profileReady=true
			at(1);c.run(.6);at(6.4);c.run(3);assert(#c.host.director.heat.seats==1,"6.4 studs out is inside the stray reach")
			at(6.6);c.run(.6);at(1);c.run(.6);at(6.6);c.run(.6);assert(#c.host.director.heat.seats==1,"coming back clears the clock")
			c.run(1);assert(c.host.director.heat==nil or #c.host.director.heat.seats==0)
			assert(c.got(1,"refused")[1].reason=="Strayed"and p.board.dashHeld==nil)
			at(10);assert(c.ask(1,"join",2).ok);c.run(2);assert(#c.host.director.heat.seats==1,"the latch starts again")
		end)
		test("the rope ring, the line: a queued player who strays is refused as Strayed; one who never got in keeps the old reach",function()
			dash();local c=rig(10);c.run(1);for id=1,10 do c.ask(id,"join",1)end;c.run(1)
			assert(#c.host.director.queue==2)
			local function at(id,dx)c.players[id].root.Position=Vector3.new(gx+dx,gy+3,gz)end
			at(9,7);c.run(1.6);assert(c.got(9,"refused")[1].reason=="Strayed"and #c.host.director.queue==1)
			at(10,1);c.run(.1);c.host.lines[10]=nil;at(10,13);c.run(2);assert(#c.got(10,"refused")==0 and #c.host.director.queue==1,"never inside: 16 studs")
		end)
		test("closing with a Dash write in flight or ambiguous settles it first, so the last park write is not skipped",function()
			dash();local c=rig(1);c.run(1);local p=c.players[1];local board=p.board
			p.ctl.failAfter=true;c.host:finished(1,table.clone(WIN));c.run(1);assert(board.nursery.pending and select(2,H.parkPlay(board.nursery,"lost",1,"pip"))=="Pending")
			local waits=0;c.host.wait=function(s)waits+=1;c.now+=s end
			c.boards[p]=nil;board.closing=true;c.host:leave(board);c.host:settle(board)
			assert(board.nursery.pending==nil and board.dashFlight==nil and H.parkPlay(board.nursery,"kept",1,"pip")and p.db.player_1.hatching.dash.paid==1)
			c.host:settle(board);assert(waits==1,"nothing in flight: no wait")
			board.dashFlight={id="x",results={WIN}};board.nursery.busy=true;local from=c.now;c.host:settle(board);assert(c.now-from<=Host.SettleSeconds+.2)
		end)
		test("leaving: a race under way pays nothing; results not yet saved are drained before the lease goes",function()
			dash();local c=rig(2);c.run(1);c.ask(1,"join",1);c.ask(2,"join",1);c.run(25)
			local p=c.players[1];c.boards[p]=nil;p.board.closing=true;c.host:leave(p.board);c.garden:remove(1)
			assert(#c.host.director.heat.seats==1 and c.host.drain(c.host,p.board)()==true and p.db.player_1.hatching.dash==nil)
			p=c.players[2];p.board.payoutPending=true;c.run(60,c.pilot(2));assert(#p.board.dashQueue==1)
			c.boards[p]=nil;p.board.closing=true;c.host:leave(p.board);p.ctl.failAfter=true
			local clock=0
			assert(Close.drain(H,p.board.nursery,nil,{now=function()return clock end,wait=function(dt)clock+=dt end,dash=c.host:drain(p.board)}))
			assert(p.db.player_2.hatching.dash.paid==1 and p.db.player_2.hatching.lease.expiresAt==0 and #c.sold==1)
		end)
		test("shutdown: every board closes, nothing running is written, and a store that stays down never hangs the drain",function()
			dash();local c=rig(3);c.run(1);for id=1,3 do c.ask(id,"join",1)end;c.run(30)
			for _,p in pairs(c.players)do p.board.closing=true;c.host:leave(p.board)end
			assert(c.host.director.heat==nil);for id,p in pairs(c.players)do assert(p.db["player_"..id].hatching.dash==nil)end
			local p=c.players[1];p.board.dashQueue={{kind="race",mode="fun",place=1,us=35000000,inputs=9,seed=1,prize=true}};p.board.nursery.status="SessionLost"
			assert(c.host:drain(p.board)()==true)
			p.board.nursery.status="Ready";p.ctl.down=true;local clock=0
			local done,why=Close.drain(H,p.board.nursery,nil,{now=function()return clock end,wait=function(dt)clock+=dt end,dash=c.host:drain(p.board)})
			assert(not done and why=="CloseTimeout"and clock<=21)
		end)
		test("twelve players: eight race, four wait in line with nothing held, then race",function()
			dash();local c=rig(12);c.run(1);for id=1,12 do local r=c.ask(id,"join",1);assert(r.ok and(r.reason=="Queued")==(id>8))end
			for id=9,12 do assert(c.players[id].board.dashHeld==nil and c.garden.actors[id].dash==nil)end
			c.run(24);assert(#c.host.director.heat.lineup==8);c.run(60)
			local heat=c.host.director.heat;assert(heat and #heat.seats==4 and c.players[9].board.dashHeld)
		end)
		-- The Play Den (PLAY-DEN-BUILD-PLAN, architect verdict 2 to 4): a second place to wait.
		test("the den: a join from its waiting area waits there (anchor on the reply and the seat); out of it for 2 s is Strayed",function()
			dash();local c=rig(1);c.den=DEN;c.run(1);local p=c.players[1]
			p.root.Position=IN_DEN;c.run(.5)
			local r=c.ask(1,"join",1);assert(r.ok and r.anchor=="den",tostring(r.reason))
			assert(c.got(1,"joined")[1].anchor=="den"and c.host.director.heat.seats[1].anchor=="den")
			c.run(3);assert(#c.host.director.heat.seats==1,"waiting in the den, 60 studs from the pad, is fine")
			p.root.Position=Vector3.new(-6,7,-96);c.run(3);assert(#c.host.director.heat.seats==1,"the apron, within Stray")
			p.root.Position=Vector3.new(-6,7,-85);c.run(1.5);assert(#c.host.director.heat.seats==1)
			c.run(1);assert(c.host.director.heat==nil or #c.host.director.heat.seats==0)
			assert(c.got(1,"refused")[1].reason=="Strayed"and p.board.dashHeld==nil)
		end)
		test("the den: at the countdown its seats are checked in the den (never Far from the pad, never Closer); the race runs",function()
			dash();local c=rig(2);c.den=DEN;c.run(1)
			c.players[1].root.Position=IN_DEN;c.run(.5)
			assert(c.ask(1,"join",1).ok and c.ask(2,"join",1).ok)
			assert(c.host.director.heat.seats[1].anchor=="den"and c.host.director.heat.seats[2].anchor==nil)
			c.run(24);local heat=c.host.director.heat
			assert(heat and heat.phase~="gather"and #heat.seats==2,"both locked in")
			assert(#c.got(1,"refused")==0 and not c.got(1,"joined")[1].closer)
		end)
		test("the den closed: its waiters (a gather seat with no character, the line) leave as Closed; meadow waiters stay",function()
			dash();local c=rig(10);c.den=DEN;c.run(1)
			for id=1,10 do if id==1 or id==9 then c.players[id].root.Position=IN_DEN end end
			c.run(.5);for id=1,10 do assert(c.ask(id,"join",1).ok)end;c.run(1)
			assert(#c.host.director.queue==2 and c.host.director.queue[1].anchor=="den"and c.host.director.queue[2].anchor==nil)
			local p=c.players[1];local character=p.Character;p.Character=nil
			c.den=nil;c.run(1)
			assert(c.got(1,"refused")[1].reason=="Closed"and c.got(9,"refused")[1].reason=="Closed")
			assert(#c.host.director.heat.seats==7 and #c.host.director.queue==1 and #c.got(10,"refused")==0)
			p.Character=character
		end)
		test("the meadow hop: nothing gathering is Missed (no race started); it joins the gathering race in its own mode; den off is today's join",function()
			dash();local c=rig(3);c.den=DEN;c.run(1)
			local r=c.ask(1,"join",1,{hop=true,mode="stats"});assert(not r.ok and r.reason=="Missed"and c.host.director.heat==nil)
			assert(c.ask(2,"join",1,{mode="fun"}).ok and c.host.director.heat.mode=="fun")
			c.run(.5);r=c.ask(1,"join",2,{hop=true,mode="stats"});assert(r.ok and #c.host.director.heat.seats==2 and c.host.director.heat.mode=="fun")
			assert(c.host.director.heat.seats[2].anchor==nil,"a hop from the meadow waits at the meadow")
			c.run(24);r=c.ask(3,"join",1,{hop=true});assert(not r.ok and r.reason=="Missed"and #c.host.director.queue==0,"never queued")
			c.den=nil;c.run(60);r=c.ask(3,"join",2,{hop=true});assert(r.ok and c.host.director.heat and c.host.director.heat.phase=="gather","den closed: a plain join")
		end)
		-- Beta 44 note 22: the server's messages to everyone (DashAnnounce). Pals crawl so the winner is known.
		local function said(c,kind)
			local out={}
			for _,e in ipairs(c.remotes.DashAnnounce and c.remotes.DashAnnounce.sent or {})do
				assert(e.to==nil,"every message goes to everyone")
				if e.packet.kind==kind then table.insert(out,e.packet)end
			end
			return out
		end
		local function crawl(c,seats)for _,seat in ipairs(seats)do c.host.director.heat.race.runners[seat].stride=1 end end
		local function race(c,id,seq,slow)
			while c.host.director.heat do c.run(.5)end
			assert(c.ask(id,"join",seq).ok);c.run(24);crawl(c,slow or {2,3,4})
			local n=0;while c.host.director.heat and c.host.director.heat.phase~="results"do c.run(1,c.pilot(id));n+=1;assert(n<200)end
		end
		test("beta 44 note 22: 'starts soon' to everyone when a race opens, at most once a SoonGap; the remote only exists with Dash on",function()
			dash({race=false});local c=rig(2);c.run(1);assert(c.remotes.DashAnnounce==nil)
			dash();c.run(1);assert(c.remotes.DashAnnounce and #said(c,"soon")==0)
			assert(c.ask(1,"join",1).ok);local soon=said(c,"soon");assert(#soon==1 and next(soon[1],next(soon[1]))==nil,"just {kind='soon'}")
			assert(c.ask(2,"join",1).ok and #said(c,"soon")==1,"a second seat says nothing")
			-- Open, empty, open again: rate-limited, never spam.
			c.run(.4);c.ask(1,"leave",2);c.ask(2,"leave",2);assert(c.host.director.heat==nil)
			c.run(.4);assert(c.ask(1,"join",3).ok and #said(c,"soon")==1,"inside the gap: nothing")
			c.run(.4);c.ask(1,"leave",4);c.run(Host.SoonGap);assert(c.ask(1,"join",5).ok and #said(c,"soon")==2,"after the gap: again")
			-- A Time Trial never says soon.
			c.run(.4);c.ask(1,"leave",6);c.run(Host.SoonGap);c.run(.4);assert(c.ask(1,"trial",7).ok and #said(c,"soon")==2)
		end)
		test("beta 44 note 22: the winner's DisplayName and pet: the saved name pieces when every one is known, else none ('pet'); a pal's win says nothing; no DisplayName, nothing",function()
			local Names=require(Shared.NameCatalog)
			dash();local c=rig(1);c.run(1);race(c,1,1)
			local won=said(c,"won");assert(#won==1,"one winner message: "..#won)
			assert(won[1].userId==1 and won[1].name=="Racer1"and won[1].petId=="pip"and won[1].pieces==nil,"unnamed: no pieces")
			c.run(10);assert(#said(c,"won")==1,"once per race")
			-- Named: the pieces, copied.
			local state=c.players[1].board.nursery.state
			local ids={Names.starterIds()[1]};assert(ids[1]);state.petNames={pip=ids}
			c.run(.4);race(c,1,2);won=said(c,"won");assert(#won==2 and won[2].pieces and won[2].pieces[1]==ids[1]and won[2].pieces~=ids)
			-- A piece this build does not know: the default words, never half a name.
			state.petNames={pip={"nope-not-a-piece"}};c.run(.4);race(c,1,3);won=said(c,"won");assert(#won==3 and won[3].pieces==nil)
			state.petNames=nil
			-- A pal wins: nothing.
			while c.host.director.heat do c.run(.5)end
			assert(c.ask(1,"join",4).ok);c.run(24);c.host.director.heat.race.runners[1].stride=1
			while c.host.director.heat and c.host.director.heat.phase~="results"do c.run(1)end
			assert(#said(c,"won")==3,"a pal won")
			-- No DisplayName (never the user name instead): nothing.
			assert(Host.wonPacket({UserId=1,Name="x"},state,"pip")==nil and Host.wonPacket(nil,state,"pip")==nil)
			assert(Host.wonPacket({UserId=1,DisplayName="A"},nil,"pip").pieces==nil)
		end)
		test("an error in the host is contained; three and it closes itself, pets free",function()

			dash();local c=rig(1);c.run(1);c.ask(1,"join",1);c.run(1);c.host.watch=function()error("boom")end
			c.beat.fire();c.beat.fire();assert(c.players[1].board.dashHeld);c.beat.fire()
			assert(c.host.dead and c.players[1].board.dashHeld==nil and c.garden.actors[1].dash==nil and #c.beat.list==0)
			c.run(5);assert(c.ask(1,"join",3).seq~=3)
		end)
	end)
	Dash.inject(nil)
	assert(ok,problem)
	return{passed=#cases,cases=cases}
end
