-- Garden fruit host (GARDEN-PLAY-BRIEF-2 section 5): the server's half of the fruit snack. The fruit is drawn by each
-- client (the grove's gust drops, LifeSim, and a tree shake); when my own pet finishes one, my client claims it, and a
-- claim that passes every check here pays GardenFruit.XP Heart XP through the save (Hatching.fruitClaim -> FruitState
-- -> StatState.grant, no Bonus XP, no Stars). mount() answers nil with the Alive `fruit` ceiling closed (live): no
-- remote, nothing made. With the switch off every packet is ignored and nothing is written.
--
-- Client to server (GardenFruit, a RemoteEvent):
--   {kind = "shake", tree = i}           I walked into tree i's trunk (GardenFruit.trees order)
--   {kind = "eat", tree = i, x, z}       my pet ate a fruit of tree i lying at (x, z)
-- Server to that player only: {kind = "fed", xp} once a claim is saved (xp may be 0); {kind = "refused", reason}.
-- No counter anywhere: the client only notes it (SnackWhy).
--
-- Checks (all on the server's own state; the packet gives only an index and a spot):
--   shake  the root, at the server, within the trunk's reach (+ slack); at most once per tree per Shake.gap a player.
--          An accepted shake is that tree's fruit for Window seconds (used once).
--   eat    the switch on; the save loaded and free (canProgress); the pet out is owned, the garden actor is that pet,
--          in the garden and not in care, a race, a park or a greeting; at most one paid fruit per Gap (server memory)
--          and DailyLimit a day (the save); the spot within Reach of the tree's trunk; the tree really let a fruit go
--          within Window (a shake this server accepted from this player, or the shared wind: GardenFruit.dropped); the
--          server's own pet sample within PetReach of the spot and the player's root within OwnerReach.
-- A refused claim writes nothing; the pet still ate happily (the client never waits for an answer).
local HttpService=game:GetService("HttpService")
local Shared=game:GetService("ReplicatedStorage").Shared
local Fruit=require(Shared.GardenFruit)
local Activity=require(Shared.GardenActivity)
local Catalog=require(Shared.EggCatalog)
local Guard=require(script.Parent.HatchGuard)

local Host={};Host.__index=Host
Host.Remote="GardenFruit"
Host.RequestGap=.25  -- per player, any packet (a flood gets silence)
Host.FlushWait=1
Host.QuietSeconds=3  -- after the player's own command, as Finds
Host.RetryBase=2
Host.RetryMax=30
Host.MaxTries=6
Host.Retry=table.freeze({Busy=true,Pending=true,Retrying=true,RevisionChanged=true})
Host.GiveUp=table.freeze({DailyLimit=true,NoPet=true,OperationConflict=true,InvalidFruit=true})

local function whole(n)return type(n)=="number"and n==n and n%1==0 and n>=1 and n<=4096 end
local function finite(n)return type(n)=="number"and n==n and math.abs(n)<1e6 end
local function loaded(board)
	local handle=board.nursery
	return board.profileReady==true and handle~=nil and handle.state~=nil and(handle.status=="Ready"or handle.status=="Retrying")
end
-- The character's root while it is alive and in the world, else nil.
local function root(board)
	local character=board.player.Character
	local part=character and character:FindFirstChild("HumanoidRootPart")
	local humanoid=character and character:FindFirstChildOfClass("Humanoid")
	if not part or not humanoid or humanoid.Health<=0 or not character:IsDescendantOf(workspace)then return nil end
	local at=part.Position
	if typeof(at)~="Vector3"or not(finite(at.X)and finite(at.Y)and finite(at.Z))then return nil end
	return at
end

-- d: remotes, garden, boards, nursery (HatchProgress), canProgress(board), publishNursery(board), publishState(board)?.
-- Specs may replace clock() (os.clock), now() (server time), guid(), spawn, wait, on(), breath() (the `scene` switch:
-- the big breath's drops count), root(board), trees (GardenFruit.trees()), remote (an object with FireClient).
function Host.new(d)
	local self=setmetatable({d=d,records={},errors=0},Host)
	self.clock=d.clock or os.clock
	self.now=d.now or function()return workspace:GetServerTimeNow()end
	self.spawn,self.wait=d.spawn or task.spawn,d.wait or task.wait
	self.guid=d.guid or function()return HttpService:GenerateGUID(false)end
	self.on=d.on or Fruit.on
	self.breath=d.breath or function()
		local ok,on=pcall(function()return require(Shared.Alive).on("scene")end)
		return ok and on==true
	end
	self.rootOf=d.root or root
	-- Beta 38: read each time (GardenFruit.trees caches): the trees follow the tree grades' `scene` switch, as the
	-- clients' do. The rules on them are unchanged.
	self.trees=d.trees
	self.remote=d.remote
	return self
end
function Host.mount(d)
	local okCeiling,ceiling=pcall(function()return require(Shared.Alive).ceiling(Fruit.Feature)end)
	if not(okCeiling and ceiling)then return nil end
	local self=Host.new(d)
	local remote=Instance.new("RemoteEvent")
	remote.Name=Host.Remote
	self.remote=remote
	remote.OnServerEvent:Connect(function(player,packet)
		local ok,problem=pcall(self.receive,self,player,packet)
		if not ok then warn("[Fruit] packet: "..tostring(problem))end
	end)
	remote.Parent=d.remotes
	return self
end
function Host:fire(player,packet)
	if not self.remote then return end
	local ok,problem=pcall(self.remote.FireClient,self.remote,player,packet)
	if not ok then warn("[Fruit] send: "..tostring(problem))end
end
function Host:record(board)
	local rec=self.records[board]
	if not rec then
		rec={at=-math.huge,paidAt=-math.huge,shakeAt={},shaken={},queue={}}
		self.records[board]=rec
	end
	return rec
end

-- Packets --------------------------------------------------------------------------------------------------------
function Host:receive(player,packet)
	local board=self.d.boards[player]
	if not board or board.closing or not loaded(board)or type(packet)~="table"then return nil,"Board"end
	local kind=packet.kind
	if kind~="shake"and kind~="eat"then return nil,"Kind"end
	local rec=self:record(board)
	local clock=self.clock()
	if clock-rec.at<Host.RequestGap then return nil,"Throttled"end
	rec.at=clock
	if not self.on()then return nil,"Off"end
	if not whole(packet.tree)or not self:treesNow()[packet.tree]then return nil,"Tree"end
	if kind=="shake"then return self:shake(board,rec,packet.tree,clock,packet.drops)end
	if not finite(packet.x)or not finite(packet.z)then return nil,"Spot"end
	local ok,reason,petId=self:check(board,rec,packet.tree,packet.x,packet.z,clock)
	if not ok then
		self:fire(player,{kind="refused",reason=reason})
		return nil,reason
	end
	rec.paidAt=clock
	table.insert(rec.queue,{petId=petId})
	self:flush(player,board)
	return true
end
function Host:treesNow()return self.trees or Fruit.trees()end
-- A shake: the root at the server by the trunk; once per tree per Shake.gap. Its fruit is claimable for Window, one
-- claim per fruit it dropped (packet.drops, Fruit.shakeClaims: at most MaxDrops).
function Host:shake(board,rec,i,clock,drops)
	local tree=self:treesNow()[i]
	local at=self.rootOf(board)
	if not at or not Fruit.shakes(tree,at.X,at.Z,nil,Fruit.Shake.slack)then return nil,"Far"end
	if clock-(rec.shakeAt[i]or -math.huge)<Fruit.Shake.gap then return nil,"Rate"end
	rec.shakeAt[i]=clock
	rec.shaken[i]={at=clock,left=Fruit.shakeClaims(drops)}
	return true
end
-- An eat claim: ok, nil, petId or false, reason. Nothing is changed but the shake it uses.
function Host:check(board,rec,i,x,z,clock)
	local d=self.d
	if not d.canProgress(board)then return false,"Busy"end
	local handle=board.nursery
	local state=handle.state
	local petId=board.profile and board.profile.companionId
	if type(petId)~="string"or not Catalog.isOwned(state.inventoryMask or 0,petId)then return false,"NoPet"end
	local actor=d.garden and d.garden.actors and d.garden.actors[board.player.UserId]
	if not actor or actor.petId~=petId then return false,"NoPet"end
	if board.mode~="Room"or actor.mode~="Room"or actor.care or actor.dash or actor.park or actor.pairId
		or board.careEquip or board.careHeld or board.dashHeld or Guard.other(state)then return false,"Busy"end
	if clock-rec.paidAt<Fruit.Gap then return false,"Rate"end
	local left=d.nursery.fruitLeft(handle)-(if rec.flight then 1 else 0)-#rec.queue
	if left<=0 then return false,"DailyLimit"end
	local tree=self:treesNow()[i]
	if not Fruit.nearTree(tree,x,z)then return false,"Far"end
	local now=self.now()
	local shake=rec.shaken[i]
	local shook=shake~=nil and clock-shake.at<=Fruit.Window and shake.left>0
	if not shook and not Fruit.dropped(i,tree.centre,now,Fruit.Window,self.breath())then return false,"NoFruit"end
	local sample=Activity.sample(actor,now)
	local pet=sample and sample.position
	if typeof(pet)~="Vector3"or math.sqrt((pet.X-x)^2+(pet.Z-z)^2)>Fruit.PetReach then return false,"PetFar"end
	local at=self.rootOf(board)
	if not at or math.sqrt((at.X-x)^2+(at.Z-z)^2)>Fruit.OwnerReach then return false,"Far"end
	if shook then
		shake.left-=1
		if shake.left<=0 then rec.shaken[i]=nil end
	end
	return true,nil,petId
end

-- Writes (the FindsHost way) -------------------------------------------------------------------------------------
function Host:finish(board,rec)
	local flight=rec.flight
	if not flight or not self.d.nursery.fruitCommitted(board.nursery,flight.op)then return false end
	local receipt=self.d.nursery.fruitReceipt(board.nursery,flight.op)
	rec.flight,rec.tries,rec.retryAt=nil,nil,nil
	self:fire(board.player,{kind="fed",xp=if receipt then receipt.xp else 0})
	pcall(self.d.publishNursery,board)
	if self.d.publishState then pcall(self.d.publishState,board)end
	return true
end
-- One try. True when the flight left (saved or given up), false to try again later.
function Host:send(board,rec)
	local flight=rec.flight
	if not flight then
		local claim=table.remove(rec.queue,1)
		if not claim then return true end
		flight={petId=claim.petId,op="fruit-"..self.guid()}
		rec.flight=flight
	end
	local ok,reason=self.d.nursery.fruitClaim(board.nursery,flight.op,flight.petId)
	if self:finish(board,rec)then return true end
	if ok then rec.flight=nil;return true end -- saved, yet no proof to read: never pay it twice
	if reason=="SessionLost"or board.nursery.status=="SessionLost"then rec.flight,rec.queue=nil,{};return true end
	if Host.GiveUp[reason]then
		if reason=="OperationConflict"or reason=="InvalidFruit"then warn("[Fruit] not saved: "..tostring(reason).." ("..flight.op..")")end
		rec.flight,rec.tries,rec.retryAt=nil,nil,nil
		return true
	end
	if Host.Retry[reason]then return false end
	rec.tries=(rec.tries or 0)+1
	if rec.tries>=Host.MaxTries then
		warn("[Fruit] not saved after "..rec.tries.." tries: "..tostring(reason))
		rec.flight,rec.tries,rec.retryAt=nil,nil,nil
		return true
	end
	rec.retryAt=self.clock()+math.min(Host.RetryMax,Host.RetryBase*2^(rec.tries-1))
	return false
end
-- One loop a board: never while the save is busy, pending or paying a round, and after a quiet window. Off, a flight
-- the save is not holding is dropped (never paid); one it holds is waited for.
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
				if handle.status=="SessionLost"then rec.flight,rec.queue=nil,{};break end
				local flight=rec.flight
				local held=flight~=nil and handle.pending~=nil and handle.pending.id==flight.op
				if not held and not self.on()then rec.flight,rec.queue,rec.tries,rec.retryAt=nil,{},nil,nil;break end
				local now=self.clock()
				local quiet=board.mode=="Room"and now-(board.lastNurseryCommand or -math.huge)>=Host.QuietSeconds and now>=(rec.retryAt or 0)
				if not held and quiet and d.canProgress(board)and not board.nurseryBusy and not handle.busy and not handle.pending and not board.payoutPending then
					board.nurseryBusy=true
					pcall(d.publishNursery,board)
					local sent,done=pcall(self.send,self,board,rec)
					board.nurseryBusy=false
					if not sent then warn("[Fruit] save: "..tostring(done))end
					if d.boards[player]~=board then break end
					pcall(d.publishNursery,board)
					if sent and done then continue end
				end
				self.wait(Host.FlushWait)
			end
		end)
		rec.flushing=false
		if not ok then warn("[Fruit] flush: "..tostring(problem))end
	end)
end
-- closeBoard: the player is leaving. A claim not yet written is dropped; the flight stays on the board for settle().
function Host:leave(board)
	local rec=self.records[board]
	self.records[board]=nil
	if rec then
		board.fruitFlight=rec.flight
		rec.queue={}
	end
end
-- closeBoard, before its own last writes: a fruit write in flight or ambiguous is settled first, for at most
-- SettleSeconds (FindsHost:settle). Nothing in flight: returns at once.
Host.SettleSeconds=3
function Host:settle(board)
	local handle,deadline=board.nursery,self.clock()+Host.SettleSeconds
	while board.fruitFlight and handle and self.clock()<deadline do
		local flight=board.fruitFlight
		if handle.busy then self.wait(.1)
		elseif handle.pending and handle.pending.id==flight.op then
			self.d.nursery.retry(handle)
			self.wait(.1)
		else
			board.fruitFlight=nil
		end
	end
end
function Host:destroy()
	if self.remote then self.remote:Destroy();self.remote=nil end
end
return Host
