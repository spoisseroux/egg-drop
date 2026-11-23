-- The Sleepy Nest host (ONBOARDING-V3-PLAN-2026-11-23, slice C): the first land on the first garden arrival, the claim
-- and Tuck in checks, and one save write at a time. mount() answers nil with the Onboarding v3 build ceiling off: no
-- remotes, no connections. With Onboard.on("nest") off nothing is landed, accepted or written; the remotes are made the
-- first time it is on, and going off drops every write not yet sent (never paid) and tells each player there is no nest.
-- Everything runs on its own protected connections: an error here never reaches the round, the garden or a save.
--
-- Per player, server memory only (the egg, its clock and its gift are on the save):
--   queue   writes accepted and not yet sent {kind = "land"|"claim"|"tuck", petId, n}; flight: the one being written (+ op)
-- The op id is kept across retries (Hatching.nestClaim resumes its own pending candidate), so an egg pays once.
-- Packets, server to that player only (NestEvent):
--   {kind="state", public=<Nest.PublicShape table, or nil = no nest>}  on join, on sync, after every saved write, on a flip
--   {kind="claimed", receipt={egg, kind, item, stars, pet}}            the egg hatched and was saved (then a state packet)
--   {kind="refused", reason, of="land"|"claim"|"tuck"}                  not accepted, or accepted and never saved
--     reasons: Off, Throttled, NotReady, NoEgg, Busy, NoPet, Queued, Tucked, Growing, Changed, Lost, Unknown
-- Client to server (NestClaim): {kind="sync"}, {kind="land"}, {kind="claim"}, {kind="tuck"}.
local RunService=game:GetService("RunService")
local HttpService=game:GetService("HttpService")
local Shared=game:GetService("ReplicatedStorage").Shared
local Onboard=require(Shared.Onboard)
local Nest=require(Shared.Nest)
local Catalog=require(Shared.EggCatalog)
local NestState=require(script.Parent.NestState)
local Guard=require(script.Parent.HatchGuard)

local Host={};Host.__index=Host
Host.Remotes=table.freeze({event="NestEvent",claim="NestClaim"})
Host.Kinds=table.freeze({sync=true,land=true,claim=true,tuck=true})
Host.RequestGap=.3   -- per player and kind
Host.TickEvery=1
Host.QuietSeconds=3  -- after the player's own command, as Finds and Dash
Host.FlushWait=1
Host.LandRetry=30    -- a land that was given up is tried again this many seconds later
Host.RetryBase=2     -- an unexpected refusal waits 2, 4, 8... s, at most RetryMax, and is given up after MaxTries
Host.RetryMax=30
Host.MaxTries=8
Host.MaxErrors=3
Host.Retry=table.freeze({Pending=true,Retrying=true,RevisionChanged=true})
Host.GiveUp=table.freeze({NotReady=true,NoEgg=true,Changed=true,NoPet=true,Growing=true,Tucked=true,Busy=true,
	InvalidNest=true,OperationConflict=true,InvalidData=true})

-- d: remotes, boards, nursery (HatchProgress), canProgress(board), publishNursery(board), publishState(board) (optional),
-- economy (optional: EconomyAnalytics), notify(board, name) (optional: the funnel; "NestTucked", "NestHatched").
-- Specs may replace clock(), now() (server unix time; default the save adapter's), guid(), remote(class, name),
-- heartbeat, spawn, wait.
function Host.mount(d)
	if not Onboard.ceiling()then return nil end
	local self=setmetatable({d=d,records={},isOpen=false,errors=0},Host)
	NestState.halted=false
	self.clock=d.clock or os.clock
	self.spawn,self.wait=d.spawn or task.spawn,d.wait or task.wait
	self.guid=d.guid or function()return HttpService:GenerateGUID(false)end
	self.tickAt=-math.huge
	local beat;beat=(d.heartbeat or RunService.Heartbeat):Connect(function()
		local ok,problem=pcall(self.step,self)
		if ok then self.errors=0;return end
		self.errors+=1
		warn("[Nest] host: "..tostring(problem))
		if self.errors>=Host.MaxErrors then
			self.dead=true
			NestState.halted=true
			beat:Disconnect()
			pcall(self.close,self)
		end
	end)
	return self
end
function Host:on()return not self.dead and Onboard.on("nest")end
function Host:fire(player,packet)
	if not self.eventRemote then return end
	local ok,problem=pcall(self.eventRemote.FireClient,self.eventRemote,player,packet)
	if not ok then warn("[Nest] send: "..tostring(problem))end
end
local function loaded(board)
	local handle=board.nursery
	return board.profileReady==true and handle~=nil and handle.state~=nil and(handle.status=="Ready"or handle.status=="Retrying")
end
local function alive(board)
	local character=board.player.Character
	local part=character and character:FindFirstChild("HumanoidRootPart")
	local humanoid=character and character:FindFirstChildOfClass("Humanoid")
	return part~=nil and humanoid~=nil and humanoid.Health>0 and character:IsDescendantOf(workspace)
end
function Host:now(board)
	if self.d.now then return self.d.now()end
	return board.nursery.adapter.now()
end
function Host:record(board)
	local rec=self.records[board]
	if not rec then
		rec={queue={},lanes={},landAfter=-math.huge}
		self.records[board]=rec
	end
	return rec
end
function Host:sendState(board)
	local public=nil
	if self:on()and loaded(board)then public=NestState.public(board.nursery.state,self:now(board))end
	self:fire(board.player,{kind="state",public=public})
end
function Host:refuse(board,reason,of)
	self:fire(board.player,{kind="refused",reason=reason,of=of})
end
local function publish(self,board)
	pcall(self.d.publishNursery,board)
	if self.d.publishState then pcall(self.d.publishState,board)end
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
	-- The event first: a client that binds when NestClaim appears always finds NestEvent.
	self.eventRemote=make("RemoteEvent",Host.Remotes.event)
	local claim=make("RemoteEvent",Host.Remotes.claim)
	claim.OnServerEvent:Connect(function(player,packet)
		local ok,problem=pcall(self.receive,self,player,packet)
		if not ok then warn("[Nest] claim: "..tostring(problem))end
	end)
end
-- Off: a write not yet sent is dropped (never paid); one the save holds as pending is left to finish (Nursery.retry or
-- CloseProgress.drain). Every player is told there is no nest, and the snapshot key goes with the next publish.
function Host:close()
	self.isOpen=false
	for board,rec in pairs(self.records)do
		local dropped=rec.queue
		rec.queue={}
		for _,item in ipairs(dropped)do if item.kind~="land"then self:refuse(board,"Off",item.kind)end end
		rec.greeted=false
		self:fire(board.player,{kind="state",public=nil})
	end
	for _,board in pairs(table.clone(self.d.boards))do
		if not board.closing then publish(self,board)end
	end
end
function Host:step()
	local on=self:on()
	if on~=self.isOpen then
		if on then
			self:open()
			for _,board in pairs(table.clone(self.d.boards))do
				if not board.closing then publish(self,board)end
			end
		else self:close()end
	end
	local now=self.clock()
	if now-self.tickAt<Host.TickEvery then return end
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
			if on then self:tick(board,now)end
		end
	end
end
-- The first land: the first time the player stands in the garden with no egg (a new save, or a malformed one).
function Host:queued(rec,kind)
	if rec.flight and rec.flight.kind==kind then return true end
	for _,item in ipairs(rec.queue)do if item.kind==kind then return true end end
	return false
end
function Host:tick(board,now)
	if not loaded(board)then return end
	local rec=self:record(board)
	if rec.stopped then return end
	if not rec.greeted then
		rec.greeted=true
		self:sendState(board)
	end
	if board.mode~="Room"or not alive(board)then return end
	if now<rec.landAfter or self:queued(rec,"land")then return end
	if NestState.landed(board.nursery.state,self:now(board))or Guard.other(board.nursery.state)then return end
	local petId=board.profile and board.profile.companionId
	if type(petId)~="string"or not Catalog.isOwned(board.nursery.state.inventoryMask or 0,petId)then return end
	table.insert(rec.queue,{kind="land",petId=petId})
	self:flush(board.player,board)
end

-- Requests -----------------------------------------------------------------------------------------------------
function Host:receive(player,packet)
	local board=self.d.boards[player]
	if not board or board.closing or not loaded(board)or type(packet)~="table"then return end
	local kind=packet.kind
	if type(kind)~="string"or not Host.Kinds[kind]then return end
	local rec=self:record(board)
	local now=self.clock()
	local last=rec.lanes[kind]
	if last and now-last<Host.RequestGap then
		-- One answer per gap, however many packets came.
		if kind~="sync"and rec.told~=last then
			rec.told=last
			self:refuse(board,"Throttled",kind)
		end
		return
	end
	rec.lanes[kind]=now
	if kind=="sync"then self:sendState(board);return end
	if not self:on()or not self.isOpen then self:refuse(board,"Off",kind);return end
	if rec.stopped then self:refuse(board,"Unknown",kind);return end
	local ok,reason,item=self:check(board,rec,kind)
	if not ok then
		self:refuse(board,reason,kind)
		if reason=="Growing"then self:sendState(board)end
		return
	end
	table.insert(rec.queue,item)
	self:flush(player,board)
end
-- Answers ok, reason or ok, nil, the queue item. The pet and the count are captured now; the write checks them again.
function Host:check(board,rec,kind)
	if self:queued(rec,kind)then return false,"Queued"end
	local d=self.d
	local state=board.nursery.state
	local entry=NestState.read(state,self:now(board))
	local petId=board.profile and board.profile.companionId
	local owned=type(petId)=="string"and Catalog.isOwned(state.inventoryMask or 0,petId)
	-- Another save operation holds the save (a hatch reveal, a reservation): a quiet Busy, never a write that fails.
	if kind~="claim"and Guard.other(state)then return false,"Busy"end
	if kind=="land"then
		if entry.at~=nil then return false,"Growing"end
		if not owned then return false,"NoPet"end
		return true,nil,{kind="land",petId=petId}
	end
	if entry.at==nil then return false,"NoEgg"end
	if kind=="tuck"then
		if entry.tucked then return false,"Tucked"end
		return true,nil,{kind="tuck",n=entry.n}
	end
	if not Nest.ready(entry,self:now(board))then return false,"NotReady"end
	if not owned then return false,"NoPet"end
	if board.mode~="Room"or not d.canProgress(board)or board.careEquip or board.careHeld or board.dashHeld
		or(board.petContact and board.petContact.lease)or Guard.other(state)then return false,"Busy"end
	-- A toy gift waits for a toy purchase in flight (never granted during one).
	if NestState.resolve(state,entry).kind=="toy"and(state.toyReservation~=nil or state.pendingToyResult~=nil)then return false,"Busy"end
	return true,nil,{kind="claim",petId=petId,n=entry.n}
end

-- Writes -------------------------------------------------------------------------------------------------------
-- Is the flight in the save? A claim by its op proof; a land when an egg is there; a tuck when that egg is tucked.
function Host:saved(board,flight)
	local state=board.nursery.state
	if flight.kind=="claim"then return NestState.committed(state,flight.op)end
	local entry=NestState.read(state,self:now(board))
	if flight.kind=="land"then return entry.at~=nil end
	return entry.at~=nil and entry.n==flight.n and entry.tucked
end
function Host:finish(board,rec)
	local flight=rec.flight
	if not flight or not self:saved(board,flight)then return false end
	rec.flight,rec.tries,rec.retryAt=nil,nil,nil
	self:answer(board,flight)
	return true
end
function Host:answer(board,flight)
	if flight.kind=="claim"then
		local receipt=NestState.receipt(board.nursery.state,flight.op)
		self:fire(board.player,{kind="claimed",receipt=NestState.publicReceipt(receipt)})
		local economy=self.d.economy
		if economy and receipt and receipt.stars>0 then
			pcall(economy.source,board.player,receipt.stars,board.nursery.state.nectar,"TimedReward","SleepyNest")
		end
		if self.d.notify then pcall(self.d.notify,board,"NestHatched")end
	elseif flight.kind=="tuck"and self.d.notify then
		-- Funnel step 8 (Nest tucked) when the tuck is saved, not when it is asked for.
		pcall(self.d.notify,board,"NestTucked")
	end
	self:sendState(board)
	publish(self,board)
end
function Host:lose(board,rec,items,reason)
	for _,item in ipairs(items)do
		if item.kind=="land"then rec.landAfter=self.clock()+Host.LandRetry
		else self:refuse(board,reason or"Lost",item.kind)end
	end
	self:sendState(board)
end
-- The save moved to another server: this board's nest writes stop for good.
function Host:stop(board,rec)
	rec.stopped=true
	local dropped=rec.queue
	if rec.flight then table.insert(dropped,1,rec.flight)end
	rec.flight,rec.queue=nil,{}
	self:lose(board,rec,dropped,"Lost")
end
function Host:call(board,flight)
	local nursery=self.d.nursery
	if flight.kind=="land"then return nursery.nestLand(board.nursery,flight.op,flight.petId)end
	if flight.kind=="tuck"then return nursery.nestTuck(board.nursery,flight.op,flight.n)end
	return nursery.nestClaim(board.nursery,flight.op,flight.petId,flight.n)
end
-- One try. Answers true when the flight left (saved or given up), false to try again later.
function Host:send(board,rec)
	local flight=rec.flight
	if not flight then
		local item=table.remove(rec.queue,1)
		if not item then return true end
		flight=table.clone(item)
		flight.op="nest"..item.kind.."-"..self.guid()
		rec.flight=flight
	end
	local ok,reason=self:call(board,flight)
	if self:finish(board,rec)then return true end
	if ok then -- saved, yet no proof to read: answer it, never pay it twice
		rec.flight,rec.tries,rec.retryAt=nil,nil,nil
		self:answer(board,flight)
		return true
	end
	if reason=="SessionLost"or board.nursery.status=="SessionLost"then self:stop(board,rec);return true end
	if reason=="Growing"and flight.kind=="land"then -- another session landed it first
		rec.flight,rec.tries,rec.retryAt=nil,nil,nil
		self:answer(board,flight)
		return true
	end
	if Host.GiveUp[reason]then
		if reason=="OperationConflict"or reason=="InvalidNest"or reason=="InvalidData"then
			warn("[Nest] a "..flight.kind.." was not saved: "..tostring(reason).." ("..flight.op..")")
		end
		rec.flight,rec.tries,rec.retryAt=nil,nil,nil
		self:lose(board,rec,{flight},reason)
		return true
	end
	if Host.Retry[reason]then return false end
	rec.tries=(rec.tries or 0)+1
	if rec.tries>=Host.MaxTries then
		warn("[Nest] a "..flight.kind.." was not saved after "..rec.tries.." tries: "..tostring(reason))
		rec.flight,rec.tries,rec.retryAt=nil,nil,nil
		self:lose(board,rec,{flight},"Lost")
		return true
	end
	rec.retryAt=self.clock()+math.min(Host.RetryMax,Host.RetryBase*2^(rec.tries-1))
	return false
end
-- One loop a board, as FindsHost:flush: never while the save is busy, pending or paying a round, and after a quiet
-- window (transact refuses while another write is pending, so land and claim wait their turn here). Off, nothing is
-- sent: a flight the save is not holding is dropped; one it holds is waited for.
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
					self:lose(board,rec,dropped,"Off")
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
					if not sent then warn("[Nest] save: "..tostring(done))end
					if d.boards[player]~=board then break end
					pcall(d.publishNursery,board)
					if sent and done then continue end
				end
				self.wait(Host.FlushWait)
			end
		end)
		rec.flushing=false
		if not ok then warn("[Nest] flush: "..tostring(problem))end
	end)
end
-- closeBoard: the player is leaving. A write not yet sent is dropped; the flight is kept on the board for settle().
-- A write the save holds as pending is retried by CloseProgress.drain like any other.
function Host:leave(board)
	local rec=self.records[board]
	self.records[board]=nil
	if rec then
		board.nestFlight=rec.flight
		rec.queue={}
	end
end
-- closeBoard, before its own last writes: a nest write in flight or ambiguous is settled first, for at most
-- SettleSeconds, so the Play date write is not skipped as pending. Nothing in flight: returns at once.
Host.SettleSeconds=3
function Host:settle(board)
	local handle,deadline=board.nursery,self.clock()+Host.SettleSeconds
	while board.nestFlight and handle and self.clock()<deadline do
		local flight=board.nestFlight
		if handle.busy then self.wait(.1)
		elseif handle.pending and handle.pending.id==flight.op then
			self.d.nursery.retry(handle)
			self.wait(.1)
		else
			board.nestFlight=nil
		end
	end
end
return Host
