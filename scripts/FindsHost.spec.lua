-- Garden finds host (V3-FINDS-BUILD-PLAN-2026-11-22, S9): the active-play timer, the waiting and daily caps, the claim
-- checks, one write at a time under one op id, the give-up reasons, the switch going off and leaving mid-write, with
-- fake players, remotes and clock over the real save transactions. Isolated adapters only; no DataStore or user writes.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.FindsHost)(ServerScriptService.Server)
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Finds=require(Shared.Finds)
	local Daily=require(Shared.DailyContracts)
	local Catalog=require(Shared.EggCatalog)
	local Host=require(server.FindsHost)
	local H=require(server.HatchProgress)
	local Close=require(server.CloseProgress)
	local Stat=require(server.StatState)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
	local function finds(env)env=env or {};env.flags=env.flags or {GardenFinds=true};env.studio=true;Finds.inject(env)end
	local function signal()
		local s={list={}}
		function s:Connect(fn)table.insert(s.list,fn);return{Disconnect=function()local at=table.find(s.list,fn);if at then table.remove(s.list,at)end end}end
		function s.fire(...)for _,fn in ipairs(table.clone(s.list))do fn(...)end end
		return s
	end
	local HOME=Vector3.new(0,5,0)
	local function rig(count)
		local c={now=1000,serial=0,players={},boards={},remotes={},parked={},beat=signal(),published=0,ops={}}
		local function player(id)
			local p={UserId=id,Parent=true}
			local root={Position=HOME}
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
			local board={player=p,mode="Room",closing=false,profileReady=true,profile={companionId="pip"},nursery=H.load(id,{rank=1},adapter)}
			assert(board.nursery.status=="Ready")
			p.board=board;c.boards[p]=board
			c.garden.actors[id]={petId="pip",mode="Room"}
			return p
		end
		c.player=player
		c.garden={actors={}}
		c.d={remotes={},garden=c.garden,boards=c.boards,players={GetPlayerByUserId=function(_,id)return c.players[id]end},nursery=H,
			canProgress=function(board)return board.profileReady and board.nursery.status=="Ready"and not board.nurseryBusy end,
			active=function(board)return not board.conflict end,
			publishNursery=function()c.published+=1 end,publishState=function()end,dayOf=Daily.dayOf,
			clock=function()return c.now end,guid=function()c.serial+=1;return "g"..c.serial end,random=Random.new(7),
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
		-- Eight steps a second (exact in binary); `walk` moves every character 3 studs each second (active play).
		function c.run(seconds,walk)
			for step=1,math.floor(seconds*8+.5)do
				c.now+=.125
				if walk~=false and step%8==1 then
					for _,p in pairs(c.players)do
						if c.boards[p]then p.root.Position=p.root.Position+Vector3.new(if p.root.Position.X>0 then -3 else 3,0,0)end
					end
				end
				c.beat.fire()
				for i=#c.parked,1,-1 do
					local parked=c.parked[i]
					if parked.due<=c.now then table.remove(c.parked,i);local ok,e=coroutine.resume(parked.co);assert(ok,e)end
				end
			end
		end
		function c.got(id,kind)
			local out={}
			for _,e in ipairs(c.remotes.FindsEvent and c.remotes.FindsEvent.sent or {})do
				if e.to==c.players[id]and(kind==nil or e.packet.kind==kind)then table.insert(out,e.packet)end
			end
			return out
		end
		function c.last(id,kind)local all=c.got(id,kind);return all[#all]end
		function c.spots(id)local last=c.last(id,"spots");return last and last.list or {}end
		function c.send(id,packet)c.remotes.FindsClaim.OnServerEvent.fire(c.players[id],packet)end
		-- Walk to a find (within reach) and claim it; the answer packet.
		function c.claim(id,find,from)
			local p=c.players[id]
			if find then p.root.Position=Vector3.new(find.x,find.y+3,find.z)+(from or Vector3.zero)end
			c.now+=.5
			local before=#c.got(id)
			c.send(id,{kind="claim",id=find and find.id or "nope"})
			local all=c.got(id)
			for i=before+1,#all do if all[i].kind~="spots"then return all[i]end end
		end
		function c.smarts(id)local p=c.players[id];return Stat.xp(p.db[p.key].hatching,"pip","smarts")end
		function c.saved(id)local p=c.players[id];return p.db[p.key].hatching.finds end
		-- A nursery that answers `reasons` (in order) before the real one, and records every op id it was asked.
		function c.answers(reasons)
			local list=table.clone(reasons)
			c.d.nursery=setmetatable({findClaim=function(h,op,pet)
				table.insert(c.ops,op)
				if #list>0 then return false,table.remove(list,1)end
				return H.findClaim(h,op,pet)
			end},{__index=H})
		end
		return c
	end
	-- Active play until `count` finds are waiting for player 1 (at most `limit` seconds).
	local function until_(c,count,limit)
		for _=1,limit or 2000 do if #c.spots(1)>=count then return true end;c.run(1)end
		return #c.spots(1)>=count
	end
	local ok,problem=pcall(function()
		test("the ceiling is off: mount makes nothing at all",function()
			finds({flags={}});local c=rig(1);assert(c.host==nil and next(c.remotes)==nil and #c.beat.list==0)
		end)
		test("the switch is off: no remotes, no finds; on makes the two remotes once and greets each player with the spots",function()
			finds({on=false});local c=rig(1);c.run(200);assert(c.host and next(c.remotes)==nil)
			finds();c.run(1.5);assert(c.remotes.FindsEvent and c.remotes.FindsClaim and #c.got(1,"spots")==1 and #c.spots(1)==0)
			local first=c.remotes.FindsClaim
			finds({on=false});c.run(1);finds();c.run(1);assert(c.remotes.FindsClaim==first)
		end)
		test("the timer: only while active; the first find after 60 active seconds, then one every 240",function()
			finds();local c=rig(1);c.run(1.5,false)
			c.run(200,false);assert(#c.spots(1)==0,"standing still is not play")
			c.run(57);assert(#c.spots(1)==0,"not before 60 active seconds")
			c.run(4);assert(#c.spots(1)==1,"the first at 60")
			local p=c.players[1]
			p.board.mode="Board";c.run(300);assert(#c.spots(1)==1,"a round is not garden play")
			p.board.mode="Room";p.board.conflict=true;c.run(300);assert(#c.spots(1)==1,"a hatch or race is not either")
			p.board.conflict=nil;p.humanoid.Health=0;c.run(300);assert(#c.spots(1)==1,"nor being dead")
			p.humanoid.Health=100;c.run(237);assert(#c.spots(1)==1);c.run(4);assert(#c.spots(1)==2,"240 more")
			local list=c.spots(1);assert(list[1].id~=list[2].id and type(list[1].x)=="number"and type(list[1].y)=="number"and type(list[1].z)=="number")
			local far=math.sqrt((list[1].x-list[2].x)^2+(list[1].z-list[2].z)^2);assert(far>=Finds.Spacing,far)
		end)
		test("at most three wait; the timer pauses at three and goes on after a claim",function()
			finds();local c=rig(1);c.run(1.5)
			assert(until_(c,3));c.run(1000);assert(#c.spots(1)==3)
			local r=c.claim(1,c.spots(1)[1]);assert(r.kind=="taken")
			c.run(5);assert(c.last(1,"claimed")and #c.spots(1)==2)
			c.run(230);assert(#c.spots(1)==2);c.run(10);assert(#c.spots(1)==3)
		end)
		test("the daily cap counts the save, the write in flight and the finds waiting",function()
			finds();local c=rig(1);local board=c.players[1].board
			local today=Daily.dayOf(board.nursery.adapter.now())
			board.nursery.state.finds={day=today,count=10};c.players[1].db.player_1.hatching.finds={day=today,count=10}
			c.run(1.5);assert(until_(c,2));c.run(2000);assert(#c.spots(1)==2,"two left today")
			board.payoutPending=true -- the write cannot go yet
			assert(c.claim(1,c.spots(1)[1]).kind=="taken");c.run(1000);assert(#c.spots(1)==1 and c.saved(1).count==10,"one in flight, one waiting, none more: "..#c.spots(1).." "..tostring(c.saved(1).count))
			board.payoutPending=nil;c.run(5);assert(c.last(1,"claimed"))
			assert(c.claim(1,c.spots(1)[1]).kind=="taken");c.run(5);assert(#c.got(1,"claimed")==2)
			c.run(2000);assert(#c.spots(1)==0 and board.nursery.state.finds.count==12,"twelve, then nothing")
		end)
		test("a claim: taken at once, saved once after a quiet moment, claimed with the XP the save paid",function()
			finds();local c=rig(1);c.run(1.5);assert(until_(c,1));local find=c.spots(1)[1];local board=c.players[1].board
			board.lastNurseryCommand=c.now
			local r=c.claim(1,find,Vector3.new(Finds.Reach-1,0,0));assert(r.kind=="taken"and r.id==find.id and #c.spots(1)==0)
			c.run(1);assert(c.saved(1)==nil,"waits out the quiet window")
			c.run(4);local done=c.last(1,"claimed");assert(done and done.id==find.id and done.xp==c.smarts(1)and done.xp>=Finds.XP and c.saved(1).count==1)
			assert(not board.nurseryBusy and c.published>0)
			c.run(30);assert(c.saved(1).count==1 and #c.got(1,"claimed")==1)
		end)
		test("refused, each with its reason, the find kept and nothing paid: far, stale, foreign, replay, taken twice, no pet, busy",function()
			finds();local c=rig(2);c.run(1.5);assert(until_(c,2))
			local mine,board,p=c.spots(1),c.players[1].board,c.players[1]
			local function refused(reason,r)assert(r and r.kind=="refused"and r.reason==reason,reason.." got "..tostring(r and r.reason))end
			refused("Far",c.claim(1,mine[1],Vector3.new(Finds.Reach+1,0,0)))
			refused("Far",c.claim(1,mine[1],Vector3.new(0,Finds.Reach+1,0)))
			refused("Unknown",c.claim(1,nil))
			-- player 2's own finds
			for _=1,400 do if #c.spots(2)>0 then break end;c.run(1)end
			refused("Unknown",c.claim(1,c.spots(2)[1]))
			board.profile.companionId=nil;refused("NoPet",c.claim(1,mine[1]));board.profile.companionId="pip"
			c.garden.actors[1]=nil;refused("NoPet",c.claim(1,mine[1]));c.garden.actors[1]={petId="blip",mode="Room"};refused("NoPet",c.claim(1,mine[1]))
			c.garden.actors[1]={petId="pip",mode="Room"}
			local mask=board.nursery.state.inventoryMask;board.nursery.state.inventoryMask=0;refused("NoPet",c.claim(1,mine[1]));board.nursery.state.inventoryMask=mask
			for _,set in ipairs({function(on)board.mode=if on then"Board"else"Room"end,function(on)c.garden.actors[1].mode=if on then"Carried"else"Room"end,
				function(on)board.petContact=if on then{lease={}}else nil end,function(on)board.dashHeld=if on then true else nil end,
				function(on)board.nurseryBusy=if on then true else nil end,function(on)board.nursery.state.lastHatch=if on then{}else nil end})do
				set(true);refused("Busy",c.claim(1,mine[1]));set(false)
			end
			p.humanoid.Health=0;refused("Far",c.claim(1,mine[1]));p.humanoid.Health=100
			assert(#c.spots(1)>=2 and c.saved(1)==nil and c.saved(2)==nil and c.smarts(1)==0)
			assert(c.claim(1,mine[1]).kind=="taken")
			refused("Unknown",c.claim(1,mine[1]))
			c.run(5);refused("Unknown",c.claim(1,mine[1]));c.run(5)
			assert(c.saved(1).count==1 and #c.got(1,"claimed")==1)
		end)
		test("strict packets: rubbish is ignored, a flood gets one Throttled a gap, sync answers with the spots",function()
			finds();local c=rig(1);c.run(1.5);assert(until_(c,1));local find=c.spots(1)[1]
			local before=#c.got(1)
			for _,odd in ipairs({nil,5,"claim",{},{kind="claim"},{kind="claim",id=5},{kind="claim",id=""},{kind="claim",id=string.rep("x",65)},{kind="buy",id=find.id},{kind=1}})do c.send(1,odd)end
			assert(#c.got(1)==before,"rubbish gets nothing")
			c.now+=1;c.send(1,{kind="sync"});local s=c.last(1);assert(s.kind=="spots"and #s.list==1 and s.list[1].id==find.id)
			c.send(1,{kind="sync"});assert(#c.got(1)==before+1,"a second sync inside the gap is dropped")
			c.players[1].root.Position=Vector3.new(find.x,find.y,find.z)
			c.now+=1;c.send(1,{kind="claim",id=find.id});assert(c.last(1,"taken"))
			local count=#c.got(1)
			for _=1,500 do c.send(1,{kind="claim",id=find.id})end
			local throttled=c.got(1,"refused");assert(#c.got(1)==count+1 and throttled[#throttled].reason=="Throttled")
			c.run(6);assert(#c.got(1,"claimed")==1)
		end)
		test("a refused write is retried under the same op id; the give-up reasons answer lost and pay nothing",function()
			finds();local c=rig(1);c.run(1.5);assert(until_(c,3))
			c.answers({"Busy","RevisionChanged","Pending","Retrying"})
			assert(c.claim(1,c.spots(1)[1]).kind=="taken");c.run(20)
			assert(#c.ops==5 and c.ops[1]==c.ops[5]and c.ops[2]==c.ops[1]and string.sub(c.ops[1],1,5)=="find-"and c.last(1,"claimed")and c.saved(1).count==1)
			local xp=c.smarts(1)
			for _,reason in ipairs({"DailyLimit","NoPet","OperationConflict"})do
				table.clear(c.ops);c.answers({reason})
				if #c.spots(1)==0 then assert(until_(c,1))end
				local find=c.spots(1)[1];assert(c.claim(1,find).kind=="taken");c.run(10)
				local lost=c.last(1,"lost");assert(lost and lost.id==find.id and #c.ops==1,reason)
				assert(c.smarts(1)==xp and c.saved(1).count==1 and c.players[1].board.nursery.pending==nil)
			end
		end)
		test("an ambiguous write waits for the save's own retry and pays once",function()
			finds();local c=rig(1);c.run(1.5);assert(until_(c,1));local p=c.players[1]
			p.ctl.failAfter=true;assert(c.claim(1,c.spots(1)[1]).kind=="taken");c.run(5)
			assert(p.board.nursery.pending and c.saved(1).count==1 and c.last(1,"claimed")==nil,"landed, unproven")
			c.run(10);assert(c.last(1,"claimed")==nil);H.retry(p.board.nursery);c.run(3)
			assert(c.last(1,"claimed")and c.saved(1).count==1 and p.board.nursery.pending==nil)
		end)
		test("the switch goes off: sparkles cleared, an unwritten claim lost; a write the save holds still finishes",function()
			finds();local c=rig(1);c.run(1.5);assert(until_(c,3));local p=c.players[1]
			p.board.payoutPending=true;local a=c.spots(1)[1];assert(c.claim(1,a).kind=="taken")
			finds({on=false});c.run(2)
			assert(#c.spots(1)==0 and c.last(1,"lost").id==a.id and c.saved(1)==nil)
			p.board.payoutPending=nil;c.run(600);assert(c.saved(1)==nil and #c.spots(1)==0)
			assert(c.claim(1,a).reason=="Off")
			finds();c.run(1.5);assert(until_(c,1));local b=c.spots(1)[1]
			p.ctl.failAfter=true;assert(c.claim(1,b).kind=="taken");c.run(5);assert(p.board.nursery.pending)
			finds({on=false});c.run(5);assert(c.last(1,"claimed")==nil)
			H.retry(p.board.nursery);c.run(3);local done=c.last(1,"claimed");assert(done and done.id==b.id and c.saved(1).count==1,"finished while off")
		end)
		test("leaving mid-write: the pending find is drained by CloseProgress and paid once; unsaved claims are dropped",function()
			finds();local c=rig(1);c.run(1.5);assert(until_(c,2));local p=c.players[1];local board=p.board
			p.ctl.failAfter=true;assert(c.claim(1,c.spots(1)[1]).kind=="taken");c.run(5);assert(board.nursery.pending)
			c.boards[p]=nil;board.closing=true;c.host:leave(board);assert(c.host.records[board]==nil)
			local clock=0
			assert(Close.drain(H,board.nursery,nil,{now=function()return clock end,wait=function(dt)clock+=dt end}))
			assert(c.saved(1).count==1 and p.db[p.key].hatching.lease.expiresAt==0)
			c.run(30);assert(c.saved(1).count==1)
		end)
		test("leaving mid-write: settle retries the held find so the Play date write is not skipped; nothing held returns at once",function()
			finds();local c=rig(1);c.run(1.5);assert(until_(c,2));local p=c.players[1];local board=p.board
			p.ctl.failAfter=true;assert(c.claim(1,c.spots(1)[1]).kind=="taken");c.run(5);assert(board.nursery.pending)
			c.boards[p]=nil;board.closing=true;c.host:leave(board)
			local waited=0
			c.host.wait=function(dt)waited+=dt;c.now+=dt end
			c.host:settle(board)
			assert(board.nursery.pending==nil and board.findsFlight==nil and c.saved(1).count==1,"settled and paid once")
			assert(waited<=c.host.SettleSeconds+.2)
			local before=c.now;c.host:settle(board);assert(c.now==before,"nothing held: at once")
			local other=c.players[1].board;other.findsFlight={op="nobody"};c.host:settle(other);assert(other.findsFlight==nil)
		end)
		test("the save moved to another server: the board's finds stop, nothing paid",function()
			finds();local c=rig(1);c.run(1.5);assert(until_(c,2));local p=c.players[1]
			c.answers({"SessionLost"});local find=c.spots(1)[1];assert(c.claim(1,find).kind=="taken");c.run(5)
			assert(c.last(1,"lost").id==find.id and #c.spots(1)==0 and c.saved(1)==nil)
			c.run(1000);assert(#c.spots(1)==0)
		end)
		test("a rejoin starts the timer again; the cap stays on the save",function()
			finds();local c=rig(1);c.run(1.5);assert(until_(c,1));local p=c.players[1];local board=p.board
			c.boards[p]=nil;board.closing=true;c.host:leave(board)
			local again={player=p,mode="Room",closing=false,profileReady=true,profile={companionId="pip"},nursery=board.nursery}
			board.nursery.status="Ready";c.boards[p]=again;p.board=again
			local seen=#c.got(1,"spots");c.run(2);assert(#c.got(1,"spots")==seen+1 and #c.spots(1)==0,"greeted, nothing carried over")
			c.run(50);assert(#c.spots(1)==0);c.run(15);assert(#c.spots(1)==1)
		end)
		test("an error in the host is contained; three and it closes itself, sparkles gone",function()
			finds();local c=rig(1);c.run(1.5);assert(until_(c,1))
			c.host.tick=function()error("boom")end
			for _=1,3 do c.now+=1.1;c.beat.fire()end
			assert(c.host.dead and #c.beat.list==0 and #c.spots(1)==0)
		end)
	end)
	Finds.inject(nil)
	assert(ok,problem)
	return{passed=#cases,cases=cases}
end
