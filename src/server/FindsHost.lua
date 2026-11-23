-- Garden finds host (V3-FINDS-BUILD-PLAN-2026-11-22, slice S9): each player's own sparkles, the active-play timer, the
-- claim checks and one save write at a time. mount() answers nil with the build ceiling off: no remotes, no
-- connections. With the runtime switch off nothing is spawned, accepted or written; the remotes are made the first
-- time it is on, and going off clears every sparkle and drops every claim not yet written (never paid).
-- Everything runs on its own protected connections: an error here never reaches the round, the garden or a save.
--
-- Per player, server memory only (a rejoin starts the timer again; the daily cap is on the save):
--   live    {id, spot}: finds waiting on the lawn, at most Finds.Waiting
--   recent  the last Finds.Recent spot indices used
--   queue   claims accepted and not yet written {id, petId}; flight: the one being written {id, petId, op}
-- The op id is kept across retries (Hatching.findClaim resumes its own pending candidate), so a find pays once.
-- Packets, server to that player only (FindsEvent):
--   {kind="spots", list={{id, x, y, z}...}}  every live find; on each change, once on join, and on sync
--   {kind="taken", id}                     a claim was accepted: pop it now
--   {kind="claimed", id, xp}               saved; xp is what the save paid (may be 0)
--   {kind="refused", id, reason}           not accepted (Far, NoPet, Busy, Unknown, Off, Throttled); the find stays
--   {kind="lost", id}                      accepted but never saved (daily limit, pet gone, switch off): no XP
-- Client to server (FindsClaim): {kind="sync"} and {kind="claim", id}.
local RunService=game:GetService("RunService")
local HttpService=game:GetService("HttpService")
local Shared=game:GetService("ReplicatedStorage").Shared
local Finds=require(Shared.Finds)
local Catalog=require(Shared.EggCatalog)
local FindsState=require(script.Parent.FindsState)
local Guard=require(script.Parent.HatchGuard)

local Host={};Host.__index=Host
Host.Remotes=table.freeze({event="FindsEvent",claim="FindsClaim"})
Host.RequestGap=.3   -- per player and kind
Host.TickEvery=1     -- the timer's step
Host.TickMax=2       -- the most one step may count (a stalled server never banks time)
Host.MoveStuds=2
Host.MoveWindow=60   -- active only if the character moved MoveStuds within this many seconds
Host.QuietSeconds=3  -- after the player's own command, as Dash
Host.FlushWait=1
Host.RetryBase=2     -- an unexpected refusal waits 2, 4, 8... s, at most RetryMax, and is given up after MaxTries
Host.RetryMax=30
Host.MaxTries=8
Host.MaxErrors=3
Host.IdMax=64
Host.Retry=table.freeze({Busy=true,Pending=true,Retrying=true,RevisionChanged=true})
Host.GiveUp=table.freeze({DailyLimit=true,NoPet=true,OperationConflict=true,InvalidFind=true})

-- d: remotes, garden, boards, players, nursery, canProgress(board), publishNursery(board), publishState(board),
-- dayOf(now), active(board) (optional: init's conflict check; mode, life and movement are checked here).
-- Specs may replace clock(), guid(), random, remote(class, name), heartbeat, spawn, wait.
function Host.mount(d)
	if not Finds.ceiling()then return nil end
	local self=setmetatable({d=d,records={},isOpen=false,errors=0},Host)
	self.clock=d.clock or os.clock
	self.spawn,self.wait=d.spawn or task.spawn,d.wait or task.wait
	self.guid=d.guid or function()return HttpService:GenerateGUID(false)end
	self.random=d.random or Random.new()
	self.tickAt=self.clock()
	local beat;beat=(d.heartbeat or RunService.Heartbeat):Connect(function()
		local ok,problem=pcall(self.step,self)
		if ok then return end
		self.errors+=1
		warn("[Finds] host: "..tostring(problem))
		if self.errors>=Host.MaxErrors then
			self.dead=true
			beat:Disconnect()
			pcall(self.close,self)
		end
	end)
	-- A flip gives every player a fresh snapshot (the finds block comes and goes).
	Finds.changed():Connect(function()
		for _,board in pairs(table.clone(d.boards))do
			if not board.closing then pcall(d.publishNursery,board)end
		end
	end)
	return self
end
function Host:on()return not self.dead and Finds.on()end
function Host:fire(player,packet)
	if not self.eventRemote then return end
	local ok,problem=pcall(self.eventRemote.FireClient,self.eventRemote,player,packet)
	if not ok then warn("[Finds] send: "..tostring(problem))end
end
local function loaded(board)
	local handle=board.nursery
	return board.profileReady==true and handle~=nil and handle.state~=nil and(handle.status=="Ready"or handle.status=="Retrying")
end
local function finite(at)
	return at.X==at.X and at.Y==at.Y and at.Z==at.Z and math.abs(at.X)<1e6 and math.abs(at.Y)<1e6 and math.abs(at.Z)<1e6
end
-- The character's root while it is alive and in the world, else nil.
local function root(board)
	local character=board.player.Character
	local part=character and character:FindFirstChild("HumanoidRootPart")
	local humanoid=character and character:FindFirstChildOfClass("Humanoid")
	if not part or not humanoid or humanoid.Health<=0 or not character:IsDescendantOf(workspace)then return nil end
	return part
end
function Host:record(board)
	local rec=self.records[board]
	if not rec then
		rec={live={},recent={},queue={},lanes={},active=0,due=Finds.FirstAfter,movedAt=-math.huge}
		self.records[board]=rec
	end
	return rec
end

-- On and off -------------------------------------------------------------------------------------------------
function Host:open()
	self.isOpen=true
	if self.eventRemote then return end
	local d=self.d
	local make=d.remote or function(class,name)
		local remote=Instance.new(class)
		remote.Name=name
		remote.Parent=d.remotes
		return remote
	end
	-- The event first: a client that binds when FindsClaim appears always finds FindsEvent.
	self.eventRemote=make("RemoteEvent",Host.Remotes.event)
	local claim=make("RemoteEvent",Host.Remotes.claim)
	claim.OnServerEvent:Connect(function(player,packet)
		local ok,problem=pcall(self.receive,self,player,packet)
		if not ok then warn("[Finds] claim: "..tostring(problem))end
	end)
end
-- Off: every sparkle goes and the timers stop; a claim not yet written is dropped (it was never paid). A write
-- already pending in the save is left to finish (flush, Nursery.retry or CloseProgress.drain).
function Host:close()
	self.isOpen=false
	for board,rec in pairs(self.records)do
		rec.live={}
		rec.active=0
		local dropped=rec.queue
		rec.queue={}
		for _,claim in ipairs(dropped)do self:fire(board.player,{kind="lost",id=claim.id})end
		self:fire(board.player,{kind="spots",list={}})
	end
end
function Host:step()
	local on=self:on()
	if on~=self.isOpen then
		if on then self:open()else self:close()end
	end
	local now=self.clock()
	if now-self.tickAt<Host.TickEvery then return end
	local dt=math.min(Host.TickMax,now-self.tickAt)
	self.tickAt=now
	local d=self.d
	for board in pairs(self.records)do
		if d.boards[board.player]~=board then self.records[board]=nil end
	end
	for player,board in pairs(d.boards)do
		if not board.closing then
			local rec=self.records[board]
			-- Even while off: a write the background retry finishes is still answered.
			if rec and(rec.flight or #rec.queue>0)then self:flush(player,board)end
			if on then self:tick(board,dt,now)end
		end
	end
end

-- The timer ----------------------------------------------------------------------------------------------------
-- How many more finds may appear today: the save's count, less those being written and those waiting.
function Host:left(board,rec)
	local handle=board.nursery
	local today=self.d.dayOf(handle.adapter.now())
	return FindsState.left(handle.state,today)-(if rec.flight then 1 else 0)-#rec.queue-#rec.live
end
function Host:active(board,rec,now)
	if board.closing or board.mode~="Room"then return false end
	if self.d.active and not self.d.active(board)then return false end
	if not root(board)then return false end
	return now-rec.movedAt<=Host.MoveWindow
end
function Host:tick(board,dt,now)
	if not loaded(board)then return end
	local rec=self:record(board)
	if rec.stopped then return end
	if not rec.greeted then
		rec.greeted=true
		self:sendSpots(board,rec)
	end
	local part=root(board)
	if part and typeof(part.Position)=="Vector3"and finite(part.Position)then
		local at=part.Position
		-- The first sighting (a spawn) is not a move; a respawn somewhere else is.
		if not rec.anchor then rec.anchor=at
		elseif(at-rec.anchor).Magnitude>Host.MoveStuds then rec.anchor,rec.movedAt=at,now end
	end
	if not self:active(board,rec,now)then return end
	if #rec.live>=Finds.Waiting or self:left(board,rec)<=0 then return end
	rec.active+=dt
	if rec.active<rec.due then return end
	if self:place(board,rec)then rec.active,rec.due=0,Finds.Every end
end
function Host:place(board,rec)
	local used={}
	for _,find in ipairs(rec.live)do table.insert(used,find.spot)end
	local spot=Finds.pick(self.random,used,rec.recent)
	if not spot then return false end
	table.insert(rec.live,{id=self.guid(),spot=spot})
	table.insert(rec.recent,spot)
	while #rec.recent>Finds.Recent do table.remove(rec.recent,1)end
	self:sendSpots(board,rec)
	return true
end
function Host:sendSpots(board,rec)
	local list={}
	if self:on()then
		for _,find in ipairs(rec.live)do
			local at=Finds.position(find.spot)
			table.insert(list,{id=find.id,x=at.X,y=at.Y,z=at.Z})
		end
	end
	self:fire(board.player,{kind="spots",list=list})
end

-- Claims -------------------------------------------------------------------------------------------------------
function Host:receive(player,packet)
	local board=self.d.boards[player]
	if not board or board.closing or not loaded(board)or type(packet)~="table"then return end
	local kind=packet.kind
	if kind~="sync"and kind~="claim"then return end
	local id=packet.id
	if kind=="claim"and(type(id)~="string"or #id<1 or #id>Host.IdMax)then return end
	local rec=self:record(board)
	local now=self.clock()
	local last=rec.lanes[kind]
	if last and now-last<Host.RequestGap then
		-- One answer per gap, however many packets came.
		if kind=="claim"and rec.told~=last then
			rec.told=last
			self:fire(player,{kind="refused",id=id,reason="Throttled"})
		end
		return
	end
	rec.lanes[kind]=now
	if kind=="sync"then self:sendSpots(board,rec);return end
	if not self:on()or not self.isOpen then self:fire(player,{kind="refused",id=id,reason="Off"});return end
	local ok,reason,index,petId=self:check(board,rec,id)
	if not ok then self:fire(player,{kind="refused",id=id,reason=reason});return end
	-- Accepted: the pet is captured now; the write only checks it is still owned.
	table.remove(rec.live,index)
	table.insert(rec.queue,{id=id,petId=petId})
	self:fire(player,{kind="taken",id=id})
	self:sendSpots(board,rec)
	self:flush(player,board)
end
-- As DashHost:check's join stage. Answers ok, reason or ok, nil, live index, petId.
function Host:check(board,rec,id)
	local index=nil
	for at,find in ipairs(rec.live)do if find.id==id then index=at;break end end
	if not index or rec.stopped then return false,"Unknown"end
	local d=self.d
	if not d.canProgress(board)then return false,"Busy"end
	local state=board.nursery.state
	local petId=board.profile.companionId
	if type(petId)~="string"or not Catalog.isOwned(state.inventoryMask or 0,petId)then return false,"NoPet"end
	local actor=d.garden.actors[board.player.UserId]
	if not actor or actor.petId~=petId then return false,"NoPet"end
	if board.mode~="Room"or actor.mode~="Room"or actor.care or actor.dash or actor.park or board.careEquip or board.careHeld
		or board.dashHeld or(board.petContact and board.petContact.lease)or Guard.other(state)then return false,"Busy"end
	local part=root(board)
	local at=part and part.Position
	if typeof(at)~="Vector3"or not finite(at)then return false,"Far"end
	if(at-Finds.position(rec.live[index].spot)).Magnitude>Finds.Reach then return false,"Far"end
	return true,nil,index,petId
end

-- Writes -------------------------------------------------------------------------------------------------------
-- The one place a flight is paid: the save holds its op. Works while off.
function Host:finish(board,rec)
	local flight=rec.flight
	if not flight or not self.d.nursery.findCommitted(board.nursery,flight.op)then return false end
	local receipt=self.d.nursery.findReceipt(board.nursery,flight.op)
	rec.flight,rec.tries,rec.retryAt=nil,nil,nil
	self:fire(board.player,{kind="claimed",id=flight.id,xp=if receipt then receipt.xp else 0})
	pcall(self.d.publishNursery,board)
	if self.d.publishState then pcall(self.d.publishState,board)end
	return true
end
function Host:lose(board,rec,claims)
	for _,claim in ipairs(claims)do self:fire(board.player,{kind="lost",id=claim.id})end
end
-- The save moved to another server: this board's finds stop for good.
function Host:stop(board,rec)
	rec.stopped=true
	local dropped=rec.queue
	if rec.flight then table.insert(dropped,1,rec.flight)end
	rec.flight,rec.queue,rec.live=nil,{},{}
	self:lose(board,rec,dropped)
	self:fire(board.player,{kind="spots",list={}})
end
-- One try. Answers true when the flight left (saved or given up), false to try again later.
function Host:send(board,rec)
	local flight=rec.flight
	if not flight then
		local claim=table.remove(rec.queue,1)
		if not claim then return true end
		flight={id=claim.id,petId=claim.petId,op="find-"..self.guid()}
		rec.flight=flight
	end
	local ok,reason=self.d.nursery.findClaim(board.nursery,flight.op,flight.petId)
	if self:finish(board,rec)then return true end
	if ok then -- saved, yet no proof to read: answer it, never pay it twice
		rec.flight=nil
		self:fire(board.player,{kind="claimed",id=flight.id,xp=0})
		return true
	end
	if reason=="SessionLost"or board.nursery.status=="SessionLost"then self:stop(board,rec);return true end
	if Host.GiveUp[reason]then
		if reason=="OperationConflict"or reason=="InvalidFind"then warn("[Finds] a find was not saved: "..tostring(reason).." ("..flight.op..")")end
		rec.flight,rec.tries,rec.retryAt=nil,nil,nil
		self:lose(board,rec,{flight})
		return true
	end
	if Host.Retry[reason]then return false end
	rec.tries=(rec.tries or 0)+1
	if rec.tries>=Host.MaxTries then
		warn("[Finds] a find was not saved after "..rec.tries.." tries: "..tostring(reason))
		rec.flight,rec.tries,rec.retryAt=nil,nil,nil
		self:lose(board,rec,{flight})
		return true
	end
	rec.retryAt=self.clock()+math.min(Host.RetryMax,Host.RetryBase*2^(rec.tries-1))
	return false
end
-- One loop a board, as DashHost:flush: never while the save is busy, pending or paying a round, and after a quiet
-- window. Off, nothing is sent: a flight the save is not holding is dropped; one it holds is waited for.
function Host:flush(player,board)
	local rec=self.records[board]
	if not rec or rec.flushing then return end
	rec.flushing=true
	local d=self.d
	self.spawn(function()
		local ok,problem=pcall(function()
			while d.boards[player]==board and not board.closing and self.records[board]==rec and(rec.flight or #rec.queue>0)do
				if self:finish(board,rec)then continue end
				local handle=board.nursery
				if handle.status=="SessionLost"then self:stop(board,rec);break end
				local flight=rec.flight
				local held=flight~=nil and handle.pending~=nil and handle.pending.id==flight.op -- ambiguous: Nursery.retry settles it
				if not held and not self:on()then
					local dropped=rec.queue
					if flight then table.insert(dropped,1,flight)end
					rec.flight,rec.queue,rec.tries,rec.retryAt=nil,{},nil,nil
					self:lose(board,rec,dropped)
					break
				end
				local now=self.clock()
				local quiet=(board.mode=="Room"or(board.round~=nil and board.round.over==true))
					and now-(board.lastNurseryCommand or-math.huge)>=Host.QuietSeconds and now>=(rec.retryAt or 0)
				if not held and quiet and d.canProgress(board)and not board.nurseryBusy and not handle.busy and not handle.pending and not board.payoutPending then
					board.nurseryBusy=true
					pcall(d.publishNursery,board)
					local sent,done=pcall(self.send,self,board,rec)
					board.nurseryBusy=false
					if not sent then warn("[Finds] save: "..tostring(done))end
					if d.boards[player]~=board then break end
					pcall(d.publishNursery,board)
					if sent and done then continue end
				end
				self.wait(Host.FlushWait)
			end
		end)
		rec.flushing=false
		if not ok then warn("[Finds] flush: "..tostring(problem))end
	end)
end
-- closeBoard: the player is leaving. Live finds go; a claim not yet written is dropped. A write the save holds as
-- pending is retried by CloseProgress.drain like any other, so no drain hook is needed.
function Host:leave(board)
	local rec=self.records[board]
	self.records[board]=nil
	if rec then rec.live,rec.queue={},{}end
end
return Host
