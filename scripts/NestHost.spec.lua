-- The Sleepy Nest host (ONBOARDING-V3-PLAN-2026-11-23, slice C): the ceiling and the switch, the remotes made once on
-- the first on, the first land on the first garden arrival, claims and Tuck in (checks, throttle, the queue, one write
-- at a time under one op id, the quiet window, never while the save is busy, pending or paying), the switch going off,
-- leaving mid-write (settle), with fake players, remotes and clocks over the real save transactions.
-- Isolated adapters only; no DataStore or user writes.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.NestHost)(ServerScriptService.Server)
-- Offline: DASH_SPECS="NestHost" python scripts/run_dash_server_specs.py <luau.exe>
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Onboard=require(Shared.Onboard)
	local Nest=require(Shared.Nest)
	local Catalog=require(Shared.EggCatalog)
	local Host=require(server.NestHost)
	local H=require(server.HatchProgress)
	local Close=require(server.CloseProgress)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
	local function onboard(env)env=env or {};env.flags=env.flags or {OnboardingV3=true};env.studio=true;Onboard.inject(env)end
	local function signal()
		local s={list={}}
		function s:Connect(fn)table.insert(s.list,fn);return{Disconnect=function()local at=table.find(s.list,fn);if at then table.remove(s.list,at)end end}end
		function s.fire(...)for _,fn in ipairs(table.clone(s.list))do fn(...)end end
		return s
	end
	local function rig(count,mode)
		local c={now=1000,serial=0,players={},boards={},remotes={},parked={},beat=signal(),published=0,ops={},notes={},sources={}}
		local function player(id)
			local p={UserId=id,Parent=true}
			local root={Position=Vector3.new(0,5,0)}
			p.root=root;p.humanoid={Health=100}
			p.Character={FindFirstChild=function(_,name)return if name=="HumanoidRootPart"then root else nil end,
				FindFirstChildOfClass=function()return p.humanoid end,IsDescendantOf=function()return true end}
			c.players[id]=p
			local db,ctl={},{now=1700000000,serial=0,writes=0}
			local adapter={now=function()return ctl.now end,guid=function()ctl.serial+=1;return id.."-"..ctl.serial end,random=function()return .1 end,wait=function()end,
				update=function(key,transform)
					if ctl.down then error("down")end
					local value=transform(copy(db[key]))
					if value then db[key]=copy(value);ctl.writes+=1 end
					if ctl.failAfter then ctl.failAfter=false;error("after commit")end
					return copy(value)
				end}
			H.load(id,{rank=1},adapter)
			local key="player_"..id
			db[key].hatching.inventoryMask=Catalog.bit("pip");db[key].hatching.lease={token="",expiresAt=0}
			p.db,p.ctl,p.key=db,ctl,key
			local board={player=p,mode=mode or "Room",closing=false,profileReady=true,profile={companionId="pip"},nursery=H.load(id,{rank=1},adapter)}
			assert(board.nursery.status=="Ready")
			p.board=board;c.boards[p]=board
			-- The save clock moves on with the lease kept alive (Hatching.renew in the game).
			function p.age(seconds)ctl.now+=seconds;db[key].hatching.lease.expiresAt=ctl.now+H.LeaseSeconds end
			return p
		end
		c.player=player
		c.d={remotes={},boards=c.boards,nursery=H,
			canProgress=function(board)return board.profileReady and board.nursery.status=="Ready"and not board.nurseryBusy end,
			publishNursery=function()c.published+=1 end,publishState=function()end,
			economy={source=function(_,amount)table.insert(c.sources,amount)end},
			notify=function(board,name)table.insert(c.notes,name)end,
			clock=function()return c.now end,guid=function()c.serial+=1;return "g"..c.serial end,
			remote=function(_,name)
				local remote={sent={},OnServerEvent=signal()}
				function remote:FireClient(to,packet)table.insert(self.sent,{to=to,packet=packet})end
				c.remotes[name]=remote
				return remote
			end,heartbeat=c.beat,
			spawn=function(fn)local ok,e=coroutine.resume(coroutine.create(fn));assert(ok,e)end,
			wait=function(seconds)table.insert(c.parked,{due=c.now+seconds,co=coroutine.running()});coroutine.yield()end}
		for id=1,count or 1 do player(id)end
		c.host=Host.mount(c.d)
		function c.run(seconds)
			for _=1,math.floor(seconds*8+.5)do
				c.now+=.125
				c.beat.fire()
				for i=#c.parked,1,-1 do
					local parked=c.parked[i]
					if parked.due<=c.now then table.remove(c.parked,i);local ok,e=coroutine.resume(parked.co);assert(ok,e)end
				end
			end
		end
		function c.got(id,kind)
			local out={}
			for _,e in ipairs(c.remotes.NestEvent and c.remotes.NestEvent.sent or {})do
				if e.to==c.players[id]and(kind==nil or e.packet.kind==kind)then table.insert(out,e.packet)end
			end
			return out
		end
		function c.last(id,kind)local all=c.got(id,kind);return all[#all]end
		function c.send(id,packet)c.remotes.NestClaim.OnServerEvent.fire(c.players[id],packet)end
		-- A request after the throttle gap: the refusal it got, or {kind="state"} when it was accepted.
		function c.ask(id,kind)
			c.now+=.5
			local before=#c.got(id)
			c.send(id,{kind=kind})
			local all=c.got(id)
			for i=before+1,#all do if all[i].kind=="refused"then return all[i]end end
			return{kind="state"}
		end
		function c.saved(id)local p=c.players[id];return p.db[p.key].hatching.nest end
		function c.stars(id)local p=c.players[id];return p.db[p.key].hatching.nectar end
		function c.answers(reasons)
			local list=table.clone(reasons)
			c.d.nursery=setmetatable({nestClaim=function(h,op,pet,n)
				table.insert(c.ops,op)
				if #list>0 then return false,table.remove(list,1)end
				return H.nestClaim(h,op,pet,n)
			end},{__index=H})
		end
		return c
	end
	-- Landed and ready for player 1.
	local function grown(c)
		c.run(5);assert(c.saved(1),"landed");c.players[1].age(Nest.Seconds)
	end
	local ok,problem=pcall(function()
		test("the ceiling is off: mount makes nothing at all",function()
			onboard({flags={}});local c=rig(1);assert(c.host==nil and next(c.remotes)==nil and #c.beat.list==0)
		end)
		test("the switch is off: no remotes, no land; on makes the two remotes once, greets with the state and lands",function()
			onboard({nest=false});local c=rig(1);c.run(60);assert(c.host and next(c.remotes)==nil and c.saved(1)==nil)
			onboard();c.run(1.5);assert(c.remotes.NestEvent and c.remotes.NestClaim and c.got(1,"state")[1].public==nil,"greeted: no egg yet")
			c.run(4);local saved=c.saved(1);assert(saved and saved.n==0 and saved.pet=="pip"and saved.gift=="beanie")
			local state=c.last(1,"state").public;assert(state and state.n==0 and state.egg==1 and state.gift.item=="beanie"and not state.ready)
			local first=c.remotes.NestClaim
			onboard({nest=false});c.run(2);assert(c.last(1,"state").public==nil,"off: no nest")
			onboard();c.run(2);assert(c.remotes.NestClaim==first and c.last(1,"state").public.n==0)
		end)
		test("the first land waits for the garden: not in a round, not dead, not without a pet; once landed, never again",function()
			onboard();local c=rig(1,"Board");local p=c.players[1];local board=p.board
			c.run(30);assert(c.saved(1)==nil,"a round is not the garden")
			board.mode="Room";p.humanoid.Health=0;c.run(30);assert(c.saved(1)==nil,"nor being dead")
			p.humanoid.Health=100;board.profile.companionId=nil;c.run(30);assert(c.saved(1)==nil,"nor without a pet")
			board.profile.companionId="pip";board.nursery.state.lastHatch={};c.run(30);assert(c.saved(1)==nil,"nor while a hatch reveal holds the save")
			board.nursery.state.lastHatch=nil;board.lastNurseryCommand=c.now;c.run(1.5);assert(c.saved(1)==nil,"after the quiet window")
			c.run(4);local at=c.saved(1).at;assert(at)
			local writes=p.ctl.writes;c.run(60);assert(c.saved(1).at==at and p.ctl.writes==writes)
		end)
		test("a claim: refused until ready, then saved once after a quiet moment, claimed with the receipt and a fresh state",function()
			onboard();local c=rig(1);c.run(5)
			local r=c.ask(1,"claim");assert(r.kind=="refused"and r.reason=="NotReady"and r.of=="claim")
			c.players[1].age(Nest.Seconds);local stars=c.stars(1)
			c.players[1].board.lastNurseryCommand=c.now
			assert(c.ask(1,"claim").kind=="state","accepted: nothing yet")
			c.run(1);assert(c.saved(1).n==0,"waits out the quiet window")
			c.run(4);local done=c.last(1,"claimed");assert(done and done.receipt.egg==1 and done.receipt.kind=="hat"and done.receipt.item=="beanie"and done.receipt.stars==10)
			assert(c.saved(1).n==1 and c.stars(1)==stars+10 and c.sources[1]==10 and table.find(c.notes,"NestHatched"))
			local state=c.last(1,"state").public;assert(state.n==1 and state.egg==2 and state.gift.kind=="stars"and state.gift.stars==15)
			c.run(30);assert(#c.got(1,"claimed")==1)
		end)
		test("strict packets: rubbish ignored, a flood gets one Throttled a gap, a second claim is Queued, sync answers the state",function()
			onboard();local c=rig(1);grown(c)
			local before=#c.got(1)
			for _,odd in ipairs({nil,5,"claim",{},{kind="buy"},{kind=1},{kind="Claim"}})do c.send(1,odd)end
			assert(#c.got(1)==before,"rubbish gets nothing")
			c.now+=1;c.send(1,{kind="sync"});assert(c.last(1).kind=="state"and c.last(1).public.ready)
			c.send(1,{kind="sync"});assert(#c.got(1)==before+1,"a second sync inside the gap is dropped")
			c.players[1].board.payoutPending=true -- the write cannot go yet
			assert(c.ask(1,"claim").kind=="state")
			local count=#c.got(1)
			for _=1,200 do c.send(1,{kind="claim"})end
			assert(#c.got(1)==count+1 and c.last(1).reason=="Throttled")
			local r=c.ask(1,"claim");assert(r.reason=="Queued",r.reason)
			c.players[1].board.payoutPending=nil;c.run(5);assert(#c.got(1,"claimed")==1 and c.saved(1).n==1)
		end)
		test("never while the save is busy, pending or paying; refused Busy in a round, a hatch or a toy purchase",function()
			onboard();local c=rig(1);grown(c);local board=c.players[1].board
			for _,set in ipairs({function(on)board.mode=if on then"Board"else"Room"end,function(on)board.dashHeld=if on then true else nil end,
				function(on)board.nurseryBusy=if on then true else nil end,function(on)board.nursery.state.lastHatch=if on then{}else nil end,
				function(on)board.petContact=if on then{lease={}}else nil end})do
				set(true);local r=c.ask(1,"claim");assert(r.reason=="Busy",r.reason);set(false)
			end
			-- Egg 3 is the toy: refused Busy while a toy purchase is reserved or its result waits.
			for egg=1,2 do assert(c.ask(1,"claim").kind=="state");c.run(5);c.players[1].age(Nest.Seconds);assert(c.saved(1).n==egg)end
			assert(c.saved(1).gift=="ball")
			for _,field in ipairs({"toyReservation","pendingToyResult"})do
				board.nursery.state[field]={id="x"};local r=c.ask(1,"claim");assert(r.reason=="Busy",field);board.nursery.state[field]=nil
			end
			-- Pending: a write the save holds waits; the claim goes once it is settled.
			board.nursery.pending={id="other",signature="other"};assert(c.ask(1,"claim").kind=="state")
			c.run(10);assert(c.saved(1).n==2,"transact refuses while another write is pending: it waits")
			board.nursery.pending=nil;c.run(5);assert(c.saved(1).n==3 and c.last(1,"claimed").receipt.item=="ball")
		end)
		test("tuck: accepted once (the funnel hears it), saved; Tucked after; no egg is NoEgg",function()
			onboard();local c=rig(1,"Board");c.run(2)
			assert(c.ask(1,"tuck").reason=="NoEgg")
			local board=c.players[1].board
			board.mode="Room";c.run(5)
			board.payoutPending=true
			assert(c.ask(1,"tuck").kind=="state"and not table.find(c.notes,"NestTucked"),"accepted is not saved: no funnel step yet")
			board.payoutPending=nil
			c.run(5);assert(c.saved(1).tucked==true and c.last(1,"state").public.tucked and table.find(c.notes,"NestTucked"),"saved: step 8")
			assert(c.ask(1,"tuck").reason=="Tucked")
			assert(c.ask(1,"land").reason=="Growing")
			board.nursery.state.lastHatch={};assert(c.ask(1,"tuck").reason=="Busy","a hatch reveal holds the save: a quiet Busy");board.nursery.state.lastHatch=nil
		end)
		test("a refused write is retried under the same op id; the give-up reasons answer refused and pay nothing",function()
			onboard();local c=rig(1);grown(c)
			c.answers({"RevisionChanged","Pending","Retrying","Unavailable"})
			assert(c.ask(1,"claim").kind=="state");c.run(30)
			assert(#c.ops==5 and c.ops[1]==c.ops[5]and string.sub(c.ops[1],1,10)=="nestclaim-"and c.last(1,"claimed")and c.saved(1).n==1,#c.ops)
			for _,reason in ipairs({"NotReady","Changed","OperationConflict","Busy"})do
				table.clear(c.ops);c.answers({reason});c.players[1].age(Nest.Seconds)
				local stars=c.stars(1)
				c.ask(1,"claim");c.run(10)
				local r=c.last(1,"refused");assert(r and r.reason==reason and r.of=="claim"and #c.ops==1,reason)
				assert(c.stars(1)==stars and c.players[1].board.nursery.pending==nil)
			end
		end)
		test("an ambiguous write waits for the save's own retry and pays once",function()
			onboard();local c=rig(1);grown(c);local p=c.players[1]
			p.ctl.failAfter=true;assert(c.ask(1,"claim").kind=="state");c.run(5)
			assert(p.board.nursery.pending and c.saved(1).n==1 and c.last(1,"claimed")==nil,"landed, unproven")
			local stars=c.stars(1)
			c.run(10);assert(c.last(1,"claimed")==nil);H.retry(p.board.nursery);c.run(3)
			assert(c.last(1,"claimed")and c.saved(1).n==1 and c.stars(1)==stars and p.board.nursery.pending==nil)
		end)
		test("the switch goes off: an unwritten claim is refused Off and nothing paid; a write the save holds still finishes",function()
			onboard();local c=rig(1);grown(c);local p=c.players[1]
			p.board.payoutPending=true;assert(c.ask(1,"claim").kind=="state")
			onboard({nest=false});c.run(2)
			assert(c.last(1,"refused").reason=="Off"and c.last(1,"state").public==nil and c.saved(1).n==0)
			p.board.payoutPending=nil;c.run(60);assert(c.saved(1).n==0)
			assert(c.ask(1,"claim").reason=="Off")
			onboard();c.run(2)
			p.ctl.failAfter=true;assert(c.ask(1,"claim").kind=="state");c.run(5);assert(p.board.nursery.pending)
			onboard({nest=false});c.run(5);assert(c.last(1,"claimed")==nil)
			H.retry(p.board.nursery);c.run(3);assert(c.last(1,"claimed")and c.saved(1).n==1,"finished while off")
		end)
		test("leaving mid-write: settle retries the held claim; CloseProgress drains it otherwise; paid once",function()
			onboard();local c=rig(1);grown(c);local p=c.players[1];local board=p.board
			p.ctl.failAfter=true;assert(c.ask(1,"claim").kind=="state");c.run(5);assert(board.nursery.pending)
			local stars=c.stars(1)
			c.boards[p]=nil;board.closing=true;c.host:leave(board);assert(c.host.records[board]==nil and board.nestFlight)
			local waited=0
			c.host.wait=function(dt)waited+=dt;c.now+=dt end
			c.host:settle(board)
			assert(board.nursery.pending==nil and board.nestFlight==nil and c.saved(1).n==1 and c.stars(1)==stars,"settled, paid once")
			assert(waited<=Host.SettleSeconds+.2)
			local before=c.now;c.host:settle(board);assert(c.now==before,"nothing held: at once")
			local c2=rig(1);grown(c2);local p2=c2.players[1];local b2=p2.board
			p2.ctl.failAfter=true;assert(c2.ask(1,"claim").kind=="state");c2.run(5);assert(b2.nursery.pending)
			c2.boards[p2]=nil;b2.closing=true;c2.host:leave(b2)
			local clock=0
			assert(Close.drain(H,b2.nursery,nil,{now=function()return clock end,wait=function(dt)clock+=dt end}))
			assert(c2.saved(1).n==1);c2.run(30);assert(c2.saved(1).n==1)
		end)
		test("the save moved to another server: the board's nest writes stop, nothing paid",function()
			onboard();local c=rig(1);grown(c)
			c.answers({"SessionLost"});c.ask(1,"claim");c.run(5)
			assert(c.last(1,"refused").reason=="Lost"and c.saved(1).n==0)
			assert(c.ask(1,"claim").reason=="Unknown")
		end)
		test("an error in the host is contained; three and it closes itself",function()
			onboard();local c=rig(1);c.run(5)
			c.host.tick=function()error("boom")end
			for _=1,3 do c.now+=1.1;c.beat.fire()end
			assert(c.host.dead and #c.beat.list==0 and c.last(1,"state").public==nil)
			assert(H.public(c.players[1].board.nursery).nest==nil,"a dead host publishes no nest")
			local again=rig(1);again.run(5);assert(H.public(again.players[1].board.nursery).nest,"the next mount publishes it again")
		end)
	end)
	Onboard.inject(nil)
	assert(ok,problem)
	return{passed=#cases,cases=cases}
end
