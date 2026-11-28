-- Garden Dash host (V3-DASH-BUILD-PLAN-2026-11-22, slice S6): the remotes, the board checks, the racing tags and the
-- prize queue around DashDirector. mount() answers nil with the build ceiling off: no remotes, no gate, no
-- attributes, no connections. With the runtime switch off nothing is handled, moved or published; the remotes
-- and the gate are made the first time it is on, and going off ends every race unpaid and frees every pet.
-- Everything runs on its own protected connections: an error here never reaches the round, the garden or a save.
--
-- Prizes: a finished race joins board.dashQueue; flush() writes up to 8 results in one Hatching.dashResults call
-- under one id kept across retries (board.dashFlight), by the park's rules: never while the save is busy, pending
-- or paying a round, and after a short quiet window so a player's own command never meets "RevisionChanged".
-- closeBoard drains what is left through CloseProgress. A race still running when anyone leaves pays nothing.
local RunService=game:GetService("RunService")
local HttpService=game:GetService("HttpService")
local Shared=game:GetService("ReplicatedStorage").Shared
local Dash=require(Shared.Dash)
local Wire=require(Shared.DashWire)
local DashStats=require(Shared.DashStats)
local StatCatalog=require(Shared.StatCatalog)
local Catalog=require(Shared.EggCatalog)
local Director=require(script.Parent.DashDirector)
local DashState=require(script.Parent.DashState)
local Guard=require(script.Parent.HatchGuard)
local Mount=require(script.Parent.DashMount)
local Ring=require(Shared.DashRing)
local StatState=require(script.Parent.StatState)
local Anchor=require(Shared.DashAnchor)
local NameCatalog=require(Shared.NameCatalog)
local NameState=require(script.Parent.NameState)

local Host={};Host.__index=Host
Host.JoinReach=12
Host.QueueReach=16
Host.HeightReach=10
Host.PacketsPerSecond=20
Host.RequestGap=.3
Host.QueueLimit=32
Host.QuietSeconds=3
Host.MarksEvery=1
Host.DrainTries=8
Host.SettleSeconds=5
Host.RetryBase=5 -- a batch the save refused is tried again after 5, 10, 20, 40, 60, 60... s
Host.RetryMax=60
Host.MaxErrors=3
-- Beta 44 note 22: "a Garden Dash starts soon" goes to the whole server at most once a SoonGap seconds, however often
-- a race opens and empties again; a winner goes once per race.
Host.SoonGap=60

-- d: remotes, shared (the GardenState folder), room (workspace), garden, boards, players, nursery, economy,
-- canProgress(board), gardenInput(board), publishNursery(board), publishState(board), dayOf(now), and optionally den() ->
-- the Play Den's layout while it is open (DenHost), else nil: a second place to wait (DashAnchor, PLAY-DEN-BUILD-PLAN).
-- Specs may replace clock (), now(), guid(), seed(), remote(class, name), heartbeat, spawn, wait.
function Host.mount(d)
	if not Dash.ceiling()then return nil end
	local self=setmetatable({d=d,clients={},lines={},isOpen=false,errors=0,marksAt=-math.huge},Host)
	local random=Random.new()
	self.clock=d.clock or os.clock
	self.spawn,self.wait=d.spawn or task.spawn,d.wait or task.wait
	self.guid=d.guid or function()return HttpService:GenerateGUID(false)end
	self.director=Director.new({now=d.now or function()return workspace:GetServerTimeNow()end,guid=self.guid,
		seed=d.seed or function()return math.floor(random:NextNumber()*4294967294)+1 end,
		day=function()return d.dayOf(os.time())end,
		prizes=Dash.prizes,warn=warn,
		check=function(userId,stage,anchor)return self:check(userId,stage,anchor)end,
		levels=function(userId)return self:levels(userId)end,
		pet=function(userId)local board=self:board(userId);return board and board.profile.companionId end,
		tag=function(userId,raceId)self:tag(userId,raceId)end,
		event=function(userId,packet)self:fire(userId,packet)end,
		state=function(userId,raceId,race)self:state(userId,raceId,race)end,
		finished=function(userId,result)self:finished(userId,result)end,
		announce=function(packet)self:announce(packet)end,
		publish=function(roster)d.shared:SetAttribute(Wire.RosterAttribute,HttpService:JSONEncode(roster))end})
	local beat;beat=(d.heartbeat or RunService.Heartbeat):Connect(function()
		local ok,problem=pcall(self.step,self)
		if ok then return end
		self.errors+=1
		warn("[Dash] host: "..tostring(problem))
		if self.errors>=Host.MaxErrors then
			self.dead=true
			beat:Disconnect()
			pcall(self.close,self)
		end
	end)
	-- A flip gives every player a fresh snapshot (the dash block comes and goes).
	Dash.changed("race"):Connect(function()
		for _,board in pairs(table.clone(d.boards))do
			if not board.closing then pcall(d.publishNursery,board)end
		end
	end)
	return self
end
function Host:on()return not self.dead and Dash.on()end
-- The den's layout while DenHost has it open, else nil (live: always nil).
function Host:den()
	local den=self.d.den
	if not den then return nil end
	local ok,layout=pcall(den)
	return if ok then layout else nil
end
function Host:player(userId)return self.d.players:GetPlayerByUserId(userId)end
function Host:board(userId)
	local player=self:player(userId)
	return player and self.d.boards[player]or nil
end
function Host:fire(userId,packet)
	local player=self:player(userId)
	if player and self.eventRemote then self.eventRemote:FireClient(player,packet)end
end
function Host:state(userId,raceId,race)
	if not self.stateRemote then return end
	local packed=Wire.encode(raceId,race,DashStats.UnitsPerCs)
	if userId==nil then self.stateRemote:FireAllClients(packed);return end
	local player=self:player(userId)
	if player then self.stateRemote:FireClient(player,packed)end
end

-- Server messages (beta 44 note 22) ------------------------------------------------------------------------------
-- The winner's packet: their DisplayName (Roblox filters it) and the pet's saved name pieces, authored NameCatalog
-- ids only (never typed text), kept only when every piece is known; else nil and the words say "pet".
function Host.wonPacket(player,state,petId)
	local name=player and player.DisplayName
	if type(name)~="string"or name==""then return nil end
	local ids=type(state)=="table"and type(petId)=="string"and NameState.petName(state,petId)or nil
	local pieces=if ids and NameCatalog.display(ids,nil)then table.clone(ids)else nil
	return{kind="won",userId=player.UserId,name=name,petId=petId,pieces=pieces}
end
-- Every message the director asks for goes to everyone here, once.
function Host:announce(packet)
	local remote=self.announceRemote
	if not remote or type(packet)~="table"then return end
	if packet.kind=="soon"then
		local now=self.clock()
		if now-(self.soonAt or-math.huge)<Host.SoonGap then return end
		self.soonAt=now
		remote:FireAllClients({kind="soon"})
	elseif packet.kind=="won"then
		if packet.raceId==nil or packet.raceId==self.wonRace then return end
		local board=self:board(packet.userId)
		if not board or board.closing then return end
		local out=Host.wonPacket(board.player,board.nursery and board.nursery.state,packet.petId)
		if not out then return end
		self.wonRace=packet.raceId
		remote:FireAllClients(out)
	end
end

-- On and off -------------------------------------------------------------------------------------------------
function Host:open()
	self.isOpen=true
	local d=self.d
	if not self.eventRemote then
		local make=d.remote or function(class,name)
			local remote=Instance.new(class)
			remote.Name=name
			remote.Parent=d.remotes
			return remote
		end
		local request,input=make("RemoteEvent",Wire.Remotes.request),make("RemoteEvent",Wire.Remotes.input)
		self.eventRemote=make("RemoteEvent",Wire.Remotes.event)
		self.stateRemote=make("UnreliableRemoteEvent",Wire.Remotes.state)
		self.announceRemote=make("RemoteEvent",Wire.Remotes.announce)
		request.OnServerEvent:Connect(function(player,packet)self:request(player,packet)end)
		input.OnServerEvent:Connect(function(player,packet)self:input(player,packet)end)
	end
	self:mountGate()
	self.director.dirty=true
end
-- The gate's props; built again when the Alive `scene` switch flips while Dash is open (the fete set, beta 17).
function Host:mountGate()
	local d=self.d
	if not d.room then return end
	local fete=if d.fete then d.fete()==true else Mount.fete()
	self.feteBuilt=fete
	local ok,problem=pcall(Mount.build,d.room,{fete=fete})
	if not ok then warn("[Dash] gate: "..tostring(problem))end
end
function Host:close()
	self.isOpen=false
	local d=self.d
	pcall(self.director.shutdown,self.director,"Off")
	-- Belt and braces: no pet stays tagged, whatever the director knew.
	for userId in pairs(table.clone(d.garden.racers or {}))do pcall(self.tag,self,userId,nil)end
	for _,board in pairs(d.boards)do
		board.dashHeld=nil
		if board.folder then board.folder:SetAttribute(Wire.MarksAttribute,nil)end
		board.dashMarks=nil
	end
	pcall(self.publishGarden,self)
	d.shared:SetAttribute(Wire.RosterAttribute,nil)
	self.director.dirty=false
	if d.room then pcall(Mount.remove,d.room)end
end
function Host:step()
	local on=self:on()
	if on~=self.isOpen then
		if on then self:open()else self:close()end
	end
	if not on then return end
	-- The fete set follows the `scene` switch, read at most once a second.
	local now=os.clock()
	if self.d.room and now>=(self.feteCheck or 0)then
		self.feteCheck=now+1
		local fete=if self.d.fete then self.d.fete()==true else Mount.fete()
		if fete~=self.feteBuilt then self:mountGate()end
	end
	-- The Deck, another pet or a lost character shows here at once (the rest is the director's half second).
	local director=self.director
	local heat=director.heat
	if heat and heat.phase~="results"then
		for _,record in ipairs(table.clone(heat.seats))do self:watch(record)end
	end
	if next(director.trials)then
		for _,trial in pairs(table.clone(director.trials))do self:watch(trial.seats[1])end
	end
	director:step()
	self:publishGarden()
	local now=self.clock()
	if now-self.marksAt>=Host.MarksEvery then
		self.marksAt=now
		for player,board in pairs(self.d.boards)do
			if not board.closing then self:marks(board)end
			if board.dashQueue and #board.dashQueue>0 or board.dashFlight then self:flush(player,board)end
		end
	end
end
function Host:watch(record)
	local board=self:board(record.userId)
	if not board or board.closing then self.director:leave(record.userId,"Left")
	elseif board.mode~="Room"then self.director:leave(record.userId,"Deck")
	elseif record.petId and board.profile.companionId~=record.petId then self.director:leave(record.userId,"PetChanged")end
end
-- What others may read on the pet's card: ribbons, cups, this week's title.
function Host:marks(board)
	local state=board.nursery and board.nursery.state
	if not state or not board.folder then return end
	local text=nil
	if state.dash~=nil then text=HttpService:JSONEncode(DashState.marks(state,self.d.dayOf(board.nursery.adapter.now())))end
	if board.dashMarks~=text then
		board.dashMarks=text
		board.folder:SetAttribute(Wire.MarksAttribute,text)
	end
end

-- Checks -----------------------------------------------------------------------------------------------------
local function finite(value)return value==value and math.abs(value)<1e6 end
-- anchor: "den" (waits in the Play Den) or nil (the meadow pad), from the director's record.
function Host:check(userId,stage,anchor)
	local d=self.d
	local board=self:board(userId)
	if not board or board.closing then return false,"Left"end
	if not self:on()then return false,"Off"end
	if board.mode~="Room"then return false,"Deck"end
	local petId=board.profile.companionId
	if stage=="seat"then
		return true
	end
	-- The Play Den closed: everyone waiting there leaves the line (character or not). Racers ("seat") race on.
	local den=nil
	if anchor==Anchor.Den then
		den=self:den()
		if not den then return false,"Closed"end
	end
	-- Beta 14 F2: a gather seat waits in the rope ring like the line. Only where the player stands counts here (no
	-- save, pet or character checks: those come at the countdown); no character just now keeps the seat.
	if stage=="gather"then
		local root=self:root(board)
		if not root then return true end
		return self:line(userId,root.Position,anchor)
	end
	local handle=board.nursery
	-- A save in flight must not cost a seat already taken or a place in line; a new join waits for it.
	if stage=="join"then
		if not d.canProgress(board)then return false,"Saving"end
	elseif not board.profileReady or(handle.status~="Ready"and handle.status~="Retrying")then return false,"Saving"end
	local state=handle.state
	if not petId or not Catalog.isOwned(state.inventoryMask,petId)then return false,"NoPet"end
	local character=board.player.Character
	local root=character and character:FindFirstChild("HumanoidRootPart")
	local humanoid=character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health<=0 or not character:IsDescendantOf(workspace)then return false,"NoCharacter"end
	local at,gate=root.Position,Mount.gate()
	if not(finite(at.X)and finite(at.Y)and finite(at.Z))then return false,"Far"end
	if stage=="queue"then return self:line(userId,at,anchor)end
	local far=0
	if den then
		local near,why=Anchor.reach(den,at)
		if not near then return false,why end
	else
		local reach=if stage=="promote"then Host.QueueReach else Host.JoinReach
		far=Vector2.new(at.X-gate.X,at.Z-gate.Z).Magnitude
		if far>reach or math.abs(at.Y-gate.Y)>Host.HeightReach then return false,"Far"end
	end
	local actor=d.garden.actors[userId]
	if not actor or actor.petId~=petId then return false,"NoPet"end
	if actor.care or board.careEquip or board.careHeld then return false,"Carried"end
	if actor.mode~="Room"then return false,"Busy"end
	if board.petContact and board.petContact.lease then return false,"Petting"end
	if Guard.other(state)then return false,"Hatching"end
	return true,if far>Host.JoinReach then"Closer"else nil
end
function Host:root(board)
	local character=board.player.Character
	local root=character and character:FindFirstChild("HumanoidRootPart")
	local humanoid=character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health<=0 or not character:IsDescendantOf(workspace)then return nil end
	return root
end
-- The rope ring's rule for a player waiting (in the line or a gather seat), DashRing.rule: once their root has been
-- inside Ring.Enter, more than Ring.Stray out for Ring.StraySeconds leaves the line ("Strayed"); before that the old
-- QueueReach holds. The latch starts fresh at every join (answer). In the Play Den: DashAnchor.rule (its waiting area).
function Host:line(userId,at,anchor)
	if not(finite(at.X)and finite(at.Y)and finite(at.Z))then return false,"Far"end
	local rec=self.lines[userId]
	if not rec then rec={};self.lines[userId]=rec end
	if anchor==Anchor.Den then return Anchor.rule(rec,self:den(),at,self.clock())end
	local gate=Mount.gate()
	return Ring.rule(rec,Vector2.new(at.X-gate.X,at.Z-gate.Z).Magnitude,math.abs(at.Y-gate.Y),self.clock(),Host.QueueReach,Host.HeightReach)
end
-- Saved XP of the pet that is out: never a public attribute, never a packet.
function Host:levels(userId)
	local board=self:board(userId)
	local state=board and board.nursery.state
	local petId=board and board.profile.companionId
	if not state or not petId then return nil end
	local out={}
	for _,id in ipairs(DashStats.Order)do out[id]=StatCatalog.levelFor(StatState.xp(state,petId,id))end
	return out
end
function Host:tag(userId,raceId)
	local board=self:board(userId)
	if board then board.dashHeld=if raceId then true else nil end
	self.d.garden:setRacer(userId,raceId)
	self.tagged=true
end
-- One garden snapshot however many tags changed (eight come off together at the results).
function Host:publishGarden()
	if not self.tagged then return end
	self.tagged=false
	self.d.garden:publish()
end

-- Packets ----------------------------------------------------------------------------------------------------
function Host:client(userId)
	local client=self.clients[userId]
	if not client then
		client={tokens=Host.PacketsPerSecond,at=self.clock(),lanes={}}
		self.clients[userId]=client
	end
	return client
end
-- 20 packets a second over both remotes, saved up to one second.
function Host:allow(client)
	local now=self.clock()
	client.tokens=math.min(Host.PacketsPerSecond,client.tokens+math.max(0,now-client.at)*Host.PacketsPerSecond)
	client.at=now
	if client.tokens<1 then return false end
	client.tokens-=1
	return true
end
function Host:request(player,packet)
	if not self:on()or not self.isOpen then return end
	local board=self.d.boards[player]
	if not board or board.closing then return end
	local userId=player.UserId
	local client=self:client(userId)
	if not self:allow(client)then return end
	local clean=Wire.request(packet)
	if not clean then return end
	local prior=client.reply
	local function reply(ok,reason,raceId,at)
		return{kind="reply",request=clean.kind,seq=clean.seq,ok=ok,reason=reason,raceId=raceId,at=at}
	end
	if prior and clean.seq<=prior.seq then
		self.eventRemote:FireClient(player,if clean.seq==prior.seq then prior else reply(false,"OldRequest"))
		return
	end
	-- Leaving and pings never wait behind a join.
	local lane=if clean.kind=="leave"or clean.kind=="ping"then clean.kind else "seat"
	local now=self.clock()
	local result
	if now-(client.lanes[lane]or-math.huge)<Host.RequestGap then result=reply(false,"Throttled")
	else
		client.lanes[lane]=now
		local ok,problem=pcall(function()result=self:answer(player,board,clean,reply)end)
		if not ok then
			warn("[Dash] request: "..tostring(problem))
			result=reply(false,"Error")
		end
	end
	client.reply=result
	self:publishGarden()
	self.eventRemote:FireClient(player,result)
end
function Host:answer(player,board,clean,reply)
	local director,userId=self.director,player.UserId
	if clean.kind=="ping"then return reply(true,nil,nil,director.options.now())end
	if clean.kind=="leave"then
		director:leave(userId)
		director:flush()
		return reply(true)
	end
	if clean.kind=="mode"then return reply(director:mode(userId,clean.mode))end
	if clean.petId~=board.profile.companionId or clean.petGeneration~=(board.companionGeneration or 0)
		or clean.characterId~=(board.characterGeneration or 0)then return reply(false,"StalePet")end
	-- A join may come before the garden's first 2 Hz actor (as focus does); refresh only this one.
	if board.mode=="Room"then self.d.garden:syncOne(userId,self.d.gardenInput(board))end
	-- Where this player waits, from where they stand now (never from the client): the Play Den while it is open and
	-- they are in its waiting area, else the meadow pad (nil). Kept on the director's record.
	local root=self:root(board)
	local anchor=if root and Anchor.pick(root.Position,self:den())==Anchor.Den then Anchor.Den else nil
	local function answered(ok,reason,raceId)
		local out=reply(ok,reason,raceId)
		if ok and anchor then out.anchor=anchor end
		return out
	end
	if clean.kind=="trial"then return answered(director:trial(userId,anchor))end
	self.lines[userId]=nil -- a new wait: the ring's latch starts again
	-- A hop is the meadow's "Join race", only while the den is open.
	local ok,reason,raceId=director:join(userId,clean.mode,clean.hop==true and self:den()~=nil,anchor)
	director:flush()
	return answered(ok,reason,raceId)
end

function Host:input(player,packet)
	if not self:on()or not self.isOpen then return end
	local board=self.d.boards[player]
	if not board or board.closing then return end
	local clean=nil
	if self:allow(self:client(player.UserId))then clean=Wire.input(packet)end
	local ok,refusal=pcall(self.director.input,self.director,player.UserId,clean)
	if not ok then warn("[Dash] input: "..tostring(refusal))
	elseif refusal then self.eventRemote:FireClient(player,refusal)end
end

-- Prizes -----------------------------------------------------------------------------------------------------
function Host:finished(userId,result)
	local board=self:board(userId)
	if not board or board.closing or not DashState.validResult(result)or DashState.pointless(board.nursery.state,result)then return end
	board.dashQueue=board.dashQueue or {}
	if #board.dashQueue>=Host.QueueLimit then warn("[Dash] results dropped: the save has not answered");return end
	table.insert(board.dashQueue,result)
	self:flush(board.player,board)
end
local function nextFlight(self,board)
	local queue=board.dashQueue
	if not queue or #queue==0 then return nil end
	local results={}
	for index=1,math.min(#queue,board.dashBatch or DashState.MaxBatch)do results[index]=queue[index]end
	return{id="dash-"..self.guid(),results=results}
end
-- The one place a flight ends: its results leave the queue, and analytics read the saved receipt.
function Host:finish(board,flight)
	if board.dashFlight~=flight or not self.d.nursery.dashCommitted(board.nursery,flight.id)then return false end
	local receipt=self.d.nursery.dashReceipt(board.nursery,flight.id)
	self:take(board,flight)
	board.dashTries,board.dashRetryAt=nil,nil
	if #board.dashQueue==0 then board.dashBatch=nil end
	if receipt and receipt.stars>0 then
		pcall(self.d.economy.source,board.player,receipt.stars,receipt.balance,"Gameplay","GardenDash")
	end
	local cups=DashState.read(board.nursery.state).cups
	local new=bit32.band(cups,bit32.bnot(flight.cups or 0))
	if new~=0 then
		local ids={}
		for _,id in ipairs(DashState.CupOrder)do if bit32.band(new,DashState.CupBits[id])~=0 then table.insert(ids,id)end end
		pcall(self.fire,self,board.player.UserId,{kind="cup",cups=ids,us=DashState.best(board.nursery.state)})
	end
	return true
end
-- The flight's results leave the queue: they are saved, or can never be.
function Host:take(board,flight)
	if board.dashFlight~=flight then return end
	for _=1,#flight.results do table.remove(board.dashQueue,1)end
	board.dashFlight=nil
end
-- A refused flight. Results are only ever given up for a malformed result (it can never be written) or an id the
-- save already holds with other content (it may have paid), and never without a warning. A batch the save itself
-- refuses is proven unwritten: its results stay, go one at a time, the refused one last, and wait longer each try.
function Host:refused(board,flight,reason)
	if board.dashFlight~=flight then return end
	if reason=="InvalidDash"then
		board.dashFlight=nil
		for index=#board.dashQueue,1,-1 do
			if not DashState.validResult(board.dashQueue[index])then
				table.remove(board.dashQueue,index)
				warn("[Dash] a malformed result was dropped")
			end
		end
	elseif reason=="OperationConflict"then
		warn("[Dash] "..#flight.results.." result(s) dropped: "..flight.id.." is already used")
		self:take(board,flight)
		return
	elseif reason~="InvalidData"then return end
	board.dashFlight=nil
	board.dashTries=(board.dashTries or 0)+1
	board.dashRetryAt=self.clock()+math.min(Host.RetryMax,Host.RetryBase*2^math.min(10,board.dashTries-1))
	if #flight.results==1 and #board.dashQueue>1 then table.insert(board.dashQueue,table.remove(board.dashQueue,1))end
	board.dashBatch=1
	warn("[Dash] save refused ("..reason.."), "..#board.dashQueue.." result(s) kept, try "..board.dashTries)
end
function Host:send(board)
	local flight=board.dashFlight
	if not flight then
		flight=nextFlight(self,board)
		board.dashFlight=flight
	end
	flight.cups=DashState.read(board.nursery.state).cups
	local ok,reason=self.d.nursery.dashResults(board.nursery,flight.id,flight.results)
	if self:finish(board,flight)then return true,"Saved"end
	if not ok then self:refused(board,flight,reason)end
	return false,reason
end
function Host:flush(player,board)
	if board.dashFlushing then return end
	board.dashFlushing=true
	local d=self.d
	self.spawn(function()
		local ok,problem=pcall(function()
			while d.boards[player]==board and not board.closing and((board.dashQueue and #board.dashQueue>0)or board.dashFlight)do
				local flight=board.dashFlight
				local handle=board.nursery
				if flight and self:finish(board,flight)then d.publishNursery(board);d.publishState(board);continue end
				local waiting=flight and handle.pending and handle.pending.id==flight.id -- ambiguous: Nursery.retry settles it
				-- Never under a live round (a write holds canProgress for a moment); closeBoard drains the rest.
				local quiet=(board.mode=="Room"or(board.round~=nil and board.round.over==true))
					and self.clock()-(board.lastNurseryCommand or-math.huge)>=Host.QuietSeconds and self.clock()>=(board.dashRetryAt or 0)
				if not waiting and quiet and d.canProgress(board)and not board.nurseryBusy and not handle.busy and not handle.pending and not board.payoutPending then
					board.nurseryBusy=true;d.publishNursery(board)
					local sent,trouble=pcall(self.send,self,board)
					board.nurseryBusy=false
					if not sent then warn("[Dash] save: "..tostring(trouble))end
					if d.boards[player]~=board then break end
					d.publishNursery(board);d.publishState(board)
					if sent and trouble=="Saved"then continue end
				end
				self.wait(2)
			end
		end)
		board.dashFlushing=false
		if not ok then warn("[Dash] flush: "..tostring(problem))end
	end)
end
-- closeBoard: the player is leaving. Whatever is still racing pays nothing; what had finished is drained.
function Host:leave(board)
	local userId=board.player.UserId
	self.director:leave(userId)
	self.director:flush()
	self.clients[userId]=nil;self.lines[userId]=nil
	board.dashHeld=nil
	self.d.garden:setRacer(userId,nil)
end
-- closeBoard, before its own last park write: a Dash write in flight (or ambiguous) is settled first, for at most
-- SettleSeconds, so that write is not refused as busy or pending. Nothing in flight: returns at once.
function Host:settle(board)
	local handle,deadline=board.nursery,self.clock()+Host.SettleSeconds
	while board.dashFlight and self.clock()<deadline do
		local flight=board.dashFlight
		if handle.busy then self.wait(.1)
		elseif handle.pending and handle.pending.id==flight.id then
			self.d.nursery.retry(handle)
			self.wait(.1)
		else
			self:finish(board,flight)
			return
		end
	end
end
-- For CloseProgress.drain (handle not busy, nothing pending, round already paid): one try a call, true once
-- there is nothing left to write or no use trying. It can never hold the lease past DrainTries.
function Host:drain(board)
	local tries=0
	return function()
		local ok,done=pcall(function()
			if board.dashFlight then self:finish(board,board.dashFlight)end
			if not board.dashFlight and not(board.dashQueue and #board.dashQueue>0)then return true end
			local status=board.nursery.status
			if status~="Ready"and status~="Retrying"then return true end
			tries+=1
			if tries>Host.DrainTries then
				warn("[Dash] closed with "..#board.dashQueue.." result(s) not saved")
				return true
			end
			self:send(board)
			return not board.dashFlight and #board.dashQueue==0 and not board.nursery.pending
		end)
		if not ok then warn("[Dash] close: "..tostring(done));return true end
		return done
	end
end
return Host
