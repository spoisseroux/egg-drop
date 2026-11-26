-- Bumble balls host (GARDEN-PLAY-BRIEF section 1). mount() answers nil with the Alive `balls` ceiling closed (live):
-- no remote, nothing made. With it open, while the switch is off every packet and tick is ignored.
--
-- The server owns one record per ball (BumbleBalls/BallMotion). A kick packet from a client:
--   {kind = "kick", id, seq, origin: Vector3, velocity: Vector3}
-- is checked (the velocity finite and clamped to that ball's jump kick envelope; the root at the server within Reach of the
-- ball; at most RateCount kicks per RateWindow per player; one accepted kick per ball per BallGap), stamped with the
-- server's startTime and the next n, planned once for its rest spot, and broadcast to everyone:
--   {kind = "kick", record = {id, n, origin, velocity, startTime, rest, by, seq, bunt?}}
-- A refused kick answers its sender alone: {kind = "refuse", id, seq, reason, record = the ball's current record}.
-- {kind = "hello"} (a client starting, at most every 2 s) answers {kind = "state", balls = {record, ...}}: joiners get
-- the rest spots, or the arc a ball is on. No per-frame work: a Tick timer rolls long-abandoned balls home and lets a
-- free pet nose one (BumbleBallPets).
local Shared=game:GetService("ReplicatedStorage").Shared
local Balls=require(Shared.BumbleBalls)
local Motion=require(Shared.BallMotion)
local Pets=require(script.Parent.BumbleBallPets)

local Host={};Host.__index=Host
Host.Tick=1
Host.HelloGap=2
Host.RefuseGap=.2   -- at most one refusal answer per player this often (a flood gets silence; the client gives up after 2.5 s)
Host.Remote="BumbleBall"

-- d (specs replace any): now(), on(), root(player) -> Vector3?, roots() -> {Vector3}, send(player, payload),
-- broadcast(payload), pets(now) -> {{ownerId, position}}, world (BallMotion.world; nil = the island), random.
function Host.new(d)
	d=d or {}
	local self=setmetatable({d=d,balls={},history={},hello={},refused={}},Host)
	self.now=d.now or function()return workspace:GetServerTimeNow()end
	self.on=d.on or Balls.on
	self.root=d.root or Host.root
	self.roots=d.roots or function()return{}end
	self.send=d.send or function()end
	self.broadcast=d.broadcast or function()end
	self.pets=d.pets
	self.world=d.world
	self.random=d.random or Random.new()
	local now=self.now()
	for _,entry in ipairs(Balls.List)do
		local home=Motion.home(entry.id,self.world)
		self.balls[entry.id]={record=Motion.rest(entry.id,home,0),rest=home,restAt=-math.huge,nearAt=now,buntAt=-math.huge,kickAt=-math.huge}
	end
	return self
end

-- The character's root at the server, or nil when there is none (or it is dead).
function Host.root(player)
	local character=player and player.Character
	local root=character and character:FindFirstChild("HumanoidRootPart")
	local humanoid=character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health<=0 then return nil end
	return root.Position
end

function Host.mount(d)
	if not Balls.ceiling()then return nil end
	local remote=Instance.new("RemoteEvent")
	remote.Name=Host.Remote
	local players=d.players or game:GetService("Players")
	local self=Host.new({
		send=function(player,payload)remote:FireClient(player,payload)end,
		broadcast=function(payload)remote:FireAllClients(payload)end,
		roots=function()
			local out={}
			for _,player in ipairs(players:GetPlayers())do local p=Host.root(player);if p then table.insert(out,p)end end
			return out
		end,
		pets=if d.garden then function(now)return Pets.free(d.garden,now)end else nil,
	})
	self.remote=remote
	remote.OnServerEvent:Connect(function(player,packet)
		local ok,problem=pcall(self.receive,self,player,packet)
		if not ok then warn("[Balls] packet: "..tostring(problem))end
	end)
	players.PlayerRemoving:Connect(function(player)self.history[player]=nil;self.hello[player]=nil;self.refused[player]=nil end)
	remote.Parent=d.remotes
	task.spawn(function()
		local errors=0
		while not self.dead do
			task.wait(Host.Tick)
			local ok,problem=pcall(self.tick,self)
			if ok then errors=0 else
				errors+=1;warn("[Balls] tick: "..tostring(problem))
				if errors>=3 then self.dead=true end
			end
		end
	end)
	return self
end

-- Every ball as it goes to a joiner: the arc it is on, or a still record at its rest spot.
function Host:records()
	local now=self.now()
	local out={}
	for _,entry in ipairs(Balls.List)do
		local ball=self.balls[entry.id]
		if now<ball.restAt then table.insert(out,Balls.pack(ball.record,ball.rest))
		else table.insert(out,Balls.pack(Motion.rest(entry.id,ball.rest,ball.record.n),ball.rest))end
	end
	return out
end

local function whole(n)return type(n)=="number"and n==n and n%1==0 and n>=1 and n<=2147483647 end
function Host:receive(player,packet)
	if type(packet)~="table"or not self.on()then return end
	if packet.kind=="hello"then
		local now=self.now()
		local at=self.hello[player]
		if at and now-at<Host.HelloGap then return end
		self.hello[player]=now
		self.send(player,{kind="state",balls=self:records()})
		return
	end
	if packet.kind~="kick"or not whole(packet.seq)or type(packet.id)~="string"or not self.balls[packet.id]then return end
	local record,reason=self:kick(player,packet.id,packet.origin,packet.velocity,{seq=packet.seq})
	if not record then
		local now=self.now()
		if now-(self.refused[player]or -math.huge)<Host.RefuseGap then return nil,reason end
		self.refused[player]=now
		local ball=self.balls[packet.id]
		self.send(player,{kind="refuse",id=packet.id,seq=packet.seq,reason=reason,
			record=Balls.pack(if now<ball.restAt then ball.record else Motion.rest(packet.id,ball.rest,ball.record.n),ball.rest)})
	end
	return record,reason
end

-- A kick by `player` (nil: a pet). The accepted record, or nil and the reason.
function Host:kick(player,id,origin,velocity,options)
	options=options or {}
	local ball=self.balls[id]
	if not ball then return nil,"Ball"end
	local now=self.now()
	if now-ball.kickAt<Balls.BallGap then return nil,"Busy"end
	local v=Balls.clamp(velocity,options.scale,id) -- the ball's own feel (Patch and Stripe kick harder)
	if not v then return nil,"Velocity"end
	local current=Motion.sample(ball.record,now,self.world)
	local before=Motion.sample(ball.record,now-Balls.Lag,self.world)
	local from=Balls.origin(origin,current,before)
	if Motion.blocked(id,from,self.world)then from=current end
	if player~=nil then
		-- Code review B35: reach is measured to the server's own ball, not the client's claimed origin (which could
		-- stretch reach by the origin slack and nudge a far ball).
		if not Balls.inReach(self.root(player),current)then return nil,"Reach"end
		local history=self.history[player]
		if not history then history={};self.history[player]=history end
		if not Balls.allow(history,now)then return nil,"Rate"end
	end
	local record={id=id,n=ball.record.n+1,origin=from,velocity=v,startTime=now,
		by=if player then player.UserId else 0,seq=options.seq,bunt=if options.bunt then true else nil}
	local plan=Motion.plan(record,self.world)
	ball.record,ball.rest,ball.restAt,ball.kickAt,ball.nearAt=record,plan.rest,now+plan.duration,now,now
	self.broadcast({kind="kick",record=Balls.pack(record,plan.rest)})
	return record
end

-- A slow roll home: straight when the line is clear, else a fade (shrink, move, grow).
function Host:sendHome(id)
	local ball=self.balls[id]
	local now=self.now()
	local home=Motion.home(id,self.world)
	local record={id=id,n=ball.record.n+1,origin=ball.rest,velocity=Vector3.zero,startTime=now,kind="home",target=home,
		fade=not Motion.lineClear(id,ball.rest,home,self.world)}
	local plan=Motion.plan(record,self.world)
	ball.record,ball.rest,ball.restAt,ball.nearAt=record,plan.rest,now+plan.duration,now
	self.broadcast({kind="kick",record=Balls.pack(record,plan.rest)})
	return record
end

-- The timer: abandoned balls roll home, and a free pet may nose one. Never per frame.
function Host:tick()
	if self.dead or not self.on()then return end
	local now=self.now()
	local roots=self.roots()
	for _,entry in ipairs(Balls.List)do
		local ball=self.balls[entry.id]
		if now<ball.restAt then continue end
		for _,root in ipairs(roots)do
			if Balls.planDistance(root,ball.rest)<=Balls.AbandonRadius then ball.nearAt=now;break end
		end
		if Balls.planDistance(ball.rest,Motion.home(entry.id,self.world))>Balls.HomeSlack and now-ball.nearAt>=Balls.AbandonAfter then
			self:sendHome(entry.id)
		end
	end
	if self.pets then
		local pets=self.pets(now)
		if #pets>0 then
			for _,bunt in ipairs(Pets.pick(self.balls,pets,now,self.random))do
				self:kick(nil,bunt.id,bunt.origin,bunt.velocity,{scale=Balls.BuntScale,bunt=true})
			end
		end
	end
end
function Host:destroy()
	self.dead=true
	if self.remote then self.remote:Destroy();self.remote=nil end
end
return Host
