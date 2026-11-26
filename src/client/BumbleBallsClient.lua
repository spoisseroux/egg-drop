-- Bumble balls on this client (GARDEN-PLAY-BRIEF section 1). mount() answers nil with the Alive `balls` ceiling closed
-- (live): nothing made. With it open the switch is watched: on builds the five balls and says hello (the server answers
-- every ball's record), off destroys them.
--
-- Kick: my character's root within Balls.KickReach of a ball's surface, moving faster than Balls.KickSpeed at it, in
-- the garden (board Mode "Room"). The same frame: the predicted record is drawn, the kick sound plays, the ball
-- squashes and the `settle` buzz goes (Haptics, mine only); then one reliable packet goes to the server
-- (BumbleBallHost). Everyone else's kicks arrive as records and join the arc part-way along (BumbleBallView).
-- The loop draws every frame only while a ball moves, blends or fades, or my root is near one; otherwise it polls
-- every Poll seconds. Balls beyond the cull distance are unparented. Reduced Motion: no squash and no spin.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local GuiService=game:GetService("GuiService")
local UserInputService=game:GetService("UserInputService")
local SoundService=game:GetService("SoundService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Shared=ReplicatedStorage:WaitForChild("Shared")
local Balls=require(Shared:WaitForChild("BumbleBalls"))
local Motion=require(Shared:WaitForChild("BallMotion"))
local View=require(script.Parent.BumbleBallView)
local Look=require(script.Parent.BumbleBallLook)
local Client={};Client.__index=Client
Client.Poll=.2
Client.Near=16           -- my root this close to a ball: every frame
Client.Folder="BumbleBallsLocal"

-- Sound. Only existing ids (BoardAudio cues) until the new takes are uploaded: kick and bounce use `land` pitched per
-- ball, the water's edge `puddle`, a pet's bunt `bear_boop`.
Client.Cues=table.freeze({kick="land",bounce="land",wall="land",water="puddle",bunt="bear_boop"})
-- `pop`: a second layer on the kick and every bounce (brief 2: Patch and Stripe kick `land` at 1.25 with `asmr_pop_a`
-- at .3, a rubbery boing), its volume scaled like the main layer's.
Client.Voice=table.freeze({
	felt=table.freeze({pitch=.78,volume=.5}),     -- soft thud
	wicker=table.freeze({pitch=1.32,volume=.42}), -- dry rattle
	cork=table.freeze({pitch=1.06,volume=.48}),   -- knock
	patch=table.freeze({pitch=1.25,volume=.5,pop=table.freeze({cue="asmr_pop_a",volume=.3})}),
	stripe=table.freeze({pitch=1.25,volume=.5,pop=table.freeze({cue="asmr_pop_a",volume=.3})}),
})
-- New takes (scripts/synth_asmr.py, not uploaded yet): put rbxassetid numbers here, three per list; a list with ids
-- wins over the `land` cue (and the pop layer) for that ball. bounce plays at the bounce's strength.
local rubber={kick={},bounce={}}  -- ball_rubber: 3 kick and 3 bounce takes, shared by Patch and Stripe [empty slots]
Client.Takes={
	wicker={kick={},bounce={}},  -- ball_wicker
	felt={kick={},bounce={}},    -- ball_felt
	cork={kick={},bounce={}},    -- ball_cork
	patch=rubber,stripe=rubber,
}
Client.BounceVolume=.7         -- a bounce at full strength, of the ball's kick volume
Client.WallVolume=.45
Client.Pitch=.06               -- random spread

-- deps (all optional): reduced() -> bool, mode() -> board Mode, serverNow(), clock().
function Client.mount(deps)
	deps=deps or {}
	if not Balls.ceiling()then return nil end
	local self=setmetatable({deps=deps,views={},looks={},seq=0,history={},kickedAt={},connections={},pollAt=0},Client)
	self.reduced=deps.reduced or function()return GuiService.ReducedMotionEnabled end
	self.mode=deps.mode or function()return "Room"end
	self.serverNow=deps.serverNow or function()return workspace:GetServerTimeNow()end
	self.clock=deps.clock or os.clock
	self.me=Players.LocalPlayer and Players.LocalPlayer.UserId or 0
	self.phone=UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	local Alive=require(Shared:WaitForChild("Alive"))
	table.insert(self.connections,Alive.changed("balls"):Connect(function()self:refresh()end))
	task.spawn(function()
		local remotes=ReplicatedStorage:WaitForChild("Remotes",30)
		local remote=remotes and remotes:WaitForChild("BumbleBall",60)
		if not remote or self.dead then return end
		self.remote=remote
		table.insert(self.connections,remote.OnClientEvent:Connect(function(payload)
			local ok,problem=pcall(self.receive,self,payload)
			if not ok then warn("[Balls] packet: "..tostring(problem))end
		end))
		self:refresh()
	end)
	table.insert(self.connections,RunService.Heartbeat:Connect(function()
		local ok,problem=pcall(self.step,self)
		if not ok then
			self.errors=(self.errors or 0)+1
			warn("[Balls] step: "..tostring(problem))
			if self.errors>=3 then self:teardown();self.dead=true end
		end
	end))
	return self
end

function Client:refresh()
	if self.dead then return end
	local on=Balls.on()and self.remote~=nil
	if on and not self.folder then
		self:build()
		self.remote:FireServer({kind="hello"})
	elseif not on and self.folder then
		self:teardown()
	end
end
function Client:build()
	local folder=Instance.new("Folder");folder.Name=Client.Folder;folder.Parent=workspace
	self.folder=folder
	local now,clock=self.serverNow(),self.clock()
	for _,entry in ipairs(Balls.List)do
		local view=View.new(entry.id)
		view:set(Motion.rest(entry.id,Motion.home(entry.id),-1),now,clock,"instant")
		self.views[entry.id]=view
		self.looks[entry.id]=Look.build(entry.id,folder)
	end
end
function Client:teardown()
	if self.folder then self.folder:Destroy();self.folder=nil end
	self.views,self.looks={},{}
end

function Client:receive(payload)
	if type(payload)~="table"or not self.folder then return end
	local now,clock=self.serverNow(),self.clock()
	if payload.kind=="state"and type(payload.balls)=="table"then
		for _,packet in ipairs(payload.balls)do
			local record=Balls.unpack(packet)
			local view=record and self.views[record.id]
			if view then view:state(record,now,clock)end
		end
	elseif payload.kind=="kick"then
		local record=Balls.unpack(payload.record)
		local view=record and self.views[record.id]
		if not view then return end
		local cue=view:receive(record,self.me,now,clock)
		if cue then
			self:sound(record.id,cue,1)
			if cue=="kick"or cue=="bunt"then self:squash(record.id,if cue=="bunt"then .5 else 1)end
		end
	elseif payload.kind=="refuse"then
		local record=Balls.unpack(payload.record)
		local view=record and self.views[record.id]
		if view then view:refuse(payload.seq,record,now,clock)end
	end
end

-- My character: root position, its velocity, airborne.
function Client:character()
	local character=Players.LocalPlayer and Players.LocalPlayer.Character
	local root=character and character:FindFirstChild("HumanoidRootPart")
	local humanoid=character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health<=0 or humanoid.Sit then return nil end
	return root.Position,root.AssemblyLinearVelocity,humanoid.FloorMaterial==Enum.Material.Air
end

function Client:squash(id,strength)
	local look=self.looks[id]
	if look then look.squashAt,look.squashBy=self.clock(),strength end
end
function Client:sound(id,cue,strength)
	local look=self.looks[id]
	if not look or not look.model.Parent then return end
	local voice=Client.Voice[id]
	local takes=Client.Takes[id]
	local list=takes and takes[if cue=="kick"then "kick"elseif cue=="bounce"then "bounce"else ""]
	local uri
	local taken=list and #list>0
	if taken then uri="rbxassetid://"..tostring(list[math.random(1,#list)])
	else
		local ok,value=pcall(function()return require(script.Parent.BoardAudio).uri(Client.Cues[cue])end)
		uri=ok and value or nil
	end
	local volume=voice.volume*(if cue=="bounce"then Client.BounceVolume*math.clamp(strength,.2,1)elseif cue=="wall"then Client.WallVolume else 1)
	local speed=(if cue=="water"or cue=="bunt"then 1 else voice.pitch)*(1+(math.random()*2-1)*Client.Pitch)
	if uri then Client.emit(look.body,uri,volume,speed)end
	-- The rubber pop over a kick or bounce (until the ball's own takes arrive).
	if voice.pop and not taken and(cue=="kick"or cue=="bounce")then
		local ok,id=pcall(function()return require(script.Parent.BoardAudio).AsmrIds[voice.pop.cue]end)
		if ok and type(id)=="number"and id>0 then
			Client.emit(look.body,"rbxassetid://"..id,voice.pop.volume*volume/voice.volume,1+(math.random()*2-1)*Client.Pitch)
		end
	end
end
function Client.emit(parent,uri,volume,speed)
	local sound=Instance.new("Sound")
	sound.SoundId=uri;sound.Volume=volume;sound.PlaybackSpeed=speed
	sound.RollOffMinDistance=8;sound.RollOffMaxDistance=70
	sound.SoundGroup=SoundService:FindFirstChild("EggDropSFX")
	sound.Parent=parent
	sound.Ended:Once(function()sound:Destroy()end)
	task.delay(4,function()if sound.Parent then sound:Destroy()end end)
	sound:Play()
end

function Client:kick(view,velocity,airborne)
	local v=Balls.launch(velocity,airborne,view.id)
	if not v then return false end
	local now,clock=self.serverNow(),self.clock()
	local origin=view.drawn
	if Motion.blocked(view.id,origin)then origin=Motion.sample(view.record,now)end
	self.seq+=1
	local record={id=view.id,n=view.record.n,origin=origin,velocity=v,startTime=now,by=self.me,seq=self.seq}
	view:predict(record,now,clock,self.seq)
	self.kickedAt[view.id]=clock
	self:sound(view.id,"kick",1)
	self:squash(view.id,1)
	pcall(function()require(script.Parent.Haptics).play("settle")end)
	self.remote:FireServer({kind="kick",id=view.id,seq=self.seq,origin=origin,velocity=v})
	return true
end

function Client:step()
	if not self.folder then return end
	local clock=self.clock()
	local root,velocity,airborne=self:character()
	local busy=false
	for _,view in pairs(self.views)do
		if view.pending or view.fadeAt or view.offset~=Vector3.zero then busy=true;break end
		local plan=view.plan
		if plan and self.serverNow()-view.record.startTime<plan.duration+.1 then busy=true;break end
		if root and view.drawn and Balls.planDistance(root,view.drawn)<Client.Near then busy=true;break end
	end
	for _,look in pairs(self.looks)do if look.squashAt and clock-look.squashAt<Balls.SquashTime then busy=true end end
	if not busy and clock<self.pollAt then return end
	self.pollAt=clock+Client.Poll
	local now=self.serverNow()
	local reduced=self.reduced()==true
	local camera=workspace.CurrentCamera
	local eye=camera and camera.CFrame.Position
	local cull=if self.phone then Balls.CullPhone else Balls.CullDesktop
	for id,view in pairs(self.views)do
		view:expire(now,clock)
		local before=view.drawn
		local drawn,scale,_,events=view:step(now,clock)
		local look=self.looks[id]
		if not drawn or not look then continue end
		local shown=eye==nil or(drawn-eye).Magnitude<=cull
		look:show(shown)
		for _,event in ipairs(events)do
			if event.kind=="bounce"then
				self:squash(id,event.strength)
				if shown then self:sound(id,"bounce",event.strength)end
			elseif shown then
				self:sound(id,event.kind,event.strength)
			end
		end
		if not shown then continue end
		if before and not reduced then look:roll(drawn-before)end
		local squash=0
		if not reduced and look.squashAt then squash=Balls.squash(look.squashBy or 1,clock-look.squashAt,id)end
		look:draw(drawn,scale,squash,Motion.island().groundY(drawn.X,drawn.Z))
	end
	-- My kicks: in the garden, on my feet or a running jump.
	if root and self.remote and self.mode()=="Room"then
		for id,view in pairs(self.views)do
			if view.drawn and clock-(self.kickedAt[id]or -math.huge)>=Balls.KickGap and Balls.kicks(root,velocity,view.drawn)
				and Balls.allow(self.history,clock,Balls.ClientWindow)then
				self:kick(view,velocity,airborne)
			end
		end
	end
end

function Client:destroy()
	self.dead=true
	for _,connection in ipairs(self.connections)do connection:Disconnect()end
	self.connections={}
	self:teardown()
end
return Client
