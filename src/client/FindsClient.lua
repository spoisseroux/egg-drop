-- Garden finds, the client (V3-FINDS-BUILD-PLAN-2026-11-22, slice S9). mount() answers nil with the build ceiling off;
-- with the switch off it only watches for the switch: no instances, no remotes bound, no per-frame work.
-- On: each of my live finds (the server's `spots` packet, a full replace) is a small drawn four-point star over the
-- lawn, in one local folder of anchored parts nothing can touch, stand on, click or shade. It twinkles harder within
-- Finds.Notice of my character (Reduced Motion: a still sparkle). Within Finds.Sniff, with my pet out and the garden
-- free, the claim goes once; the server answers:
--   taken    accepted: the star pops (a burst and a shrink, Pop seconds) with a sniff and a sparkle sound
--   claimed  saved: "+N Smarts" floats up when xp > 0
--   refused  the find stays; that id is not asked again for Backoff seconds
--   lost     gone, no XP
-- Remotes (made by the server the first time its switch is on): FindsEvent (server to me), FindsClaim (me to server).
-- They are bound through remotes.ChildAdded, never waited for; {kind="sync"} asks for my spots once both are there,
-- again on each switch-on and on respawn.
-- deps: remotes, root() -> Vector3?, petOut() -> bool, free() -> bool (Room mode, no race seat, no close-up or
--   petting), busy() -> bool (a menu or card is up), reduced() -> bool, audio ({play(name, speed, volume)}),
--   plus world, player ({CharacterAdded}), now() and step=false (no Heartbeat; the spec calls :step) for specs.
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Finds=require(Shared:WaitForChild("Finds"))
local UICopy=require(Shared:WaitForChild("UICopy"))
local Client={};Client.__index=Client
Client.Folder="EggDropFinds"
Client.Event="FindsEvent"
Client.Claim="FindsClaim"
Client.Lift=1.4        -- the star floats this far over the ground
Client.Size=1.8        -- studs across
Client.Pop=.4          -- the star bursts and shrinks this long
Client.Hold=.8         -- the burst's part stays this long, so its sparks finish
Client.Backoff=2       -- a refused id waits this long
Client.Pending=6       -- a claim with no answer this long may go again
Client.Rise=1.4        -- "+N Smarts" floats this long
Client.MaxSpots=16     -- a packet never draws more than this
Client.Star=Color3.fromHex("#FFF4DC")
Client.Core=Color3.fromHex("#FFD66B")
Client.Texture="rbxasset://textures/particles/sparkles_main.dds" -- the built-in spark the Aero dew glints use
Client.SniffGain=.45   -- BoardAudio.SnackGain
Client.SparkleGain=.7

local function finite(n)return type(n)=="number"and n==n and math.abs(n)<1e6 end
local function key(id)
	if type(id)=="string"and #id>0 and #id<=64 then return id end
	if type(id)=="number"and id==id and id%1==0 then return tostring(id)end
	return nil
end
Client.key=key
-- Pure: a spots packet's list as {[key] = Vector3} (malformed entries dropped, at most MaxSpots).
function Client.parse(list)
	local out,n={},0
	if type(list)~="table"then return out,0 end
	for _,entry in ipairs(list)do
		if n>=Client.MaxSpots then break end
		local id=type(entry)=="table"and key(entry.id)
		if id and not out[id]and finite(entry.x)and finite(entry.y)and finite(entry.z)then
			out[id]=Vector3.new(entry.x,entry.y,entry.z);n+=1
		end
	end
	return out,n
end
-- Pure: the star's scale and turn (degrees) at time t. Reduced Motion: still.
function Client.twinkle(t,near,reduced,seed)
	if reduced then return 1,0 end
	seed=seed or 0
	if near then return 1.1+.3*math.abs(math.sin(t*6+seed)),(t*45+seed*20)%90 end
	return 1+.1*math.sin(t*2.2+seed),0
end
-- Pure: the star's scale while it pops, p in 0..1: a quick swell, then down to nothing.
function Client.popScale(p)
	if p<=.3 then return 1+p/.3*.6 end
	return math.max(0,1.6*(1-(p-.3)/.7))
end

local function part(folder,name,position)
	local p=Instance.new("Part")
	p.Name=name
	p.Anchored,p.CanCollide,p.CanQuery,p.CanTouch,p.CastShadow=true,false,false,false,false
	p.Massless=true
	p.Transparency=1
	p.Size=Vector3.new(.4,.4,.4)
	p.CFrame=CFrame.new(position)
	p.Parent=folder
	return p
end
local function bar(parent,name,size,rotation)
	local f=Instance.new("Frame")
	f.Name=name
	f.AnchorPoint=Vector2.new(.5,.5);f.Position=UDim2.fromScale(.5,.5);f.Size=size
	f.BackgroundColor3=Client.Star;f.BorderSizePixel=0
	local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(1,0);corner.Parent=f
	-- Bright in the middle, gone at the tips: a glint, not a plus sign.
	local fade=Instance.new("UIGradient")
	fade.Rotation=rotation
	fade.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.5,0),NumberSequenceKeypoint.new(1,1)})
	fade.Parent=f
	f.Parent=parent
	return f
end

function Client.mount(deps)
	if not Finds.ceiling()then return nil end
	local self=setmetatable({d=deps,isOpen=false,connections={},spots={},popping={},gains={},pending={},backoff={},clock=0},Client)
	self.world=deps.world or workspace
	self.now=deps.now or os.clock
	self.changed=Finds.changed():Connect(function()self:sync()end)
	if deps.step~=false then
		self.beat=RunService.Heartbeat:Connect(function(dt)
			local ok,problem=pcall(self.step,self,dt)
			if not ok then warn("[Finds] "..tostring(problem));self.dead=true;pcall(self.close,self);self.beat:Disconnect()end
		end)
	end
	self:sync()
	return self
end
function Client:sync()
	local on=not self.dead and Finds.on()
	if on==self.isOpen then return end
	if on then
		local ok,problem=pcall(self.open,self)
		if not ok then warn("[Finds] not opened: "..tostring(problem));self.dead=true;pcall(self.close,self)end
	else self:close()end
end
function Client:open()
	self.isOpen=true
	self.synced=false
	local d=self.d
	local function on(signal,fn)table.insert(self.connections,signal:Connect(fn))end
	local function guarded(fn)
		return function(...)
			local ok,problem=pcall(fn,self,...)
			if not ok then warn("[Finds] "..tostring(problem))end
		end
	end
	local receive=guarded(self.receive)
	local function bind(remote)
		if not self.isOpen then return end
		if remote.Name==Client.Event and not self.eventRemote then
			self.eventRemote=remote;on(remote.OnClientEvent,receive)
		elseif remote.Name==Client.Claim and not self.claimRemote then
			self.claimRemote=remote
		else return end
		self:ask()
	end
	for _,name in ipairs({Client.Event,Client.Claim})do
		local remote=d.remotes:FindFirstChild(name)
		if remote then bind(remote)end
	end
	on(d.remotes.ChildAdded,bind)
	local player=d.player
	if player==nil then player=game:GetService("Players").LocalPlayer end
	if player and player.CharacterAdded then on(player.CharacterAdded,function()self.synced=false;self:ask()end)end
end
-- {kind="sync"} once both remotes are bound (again after a switch-on or a respawn).
function Client:ask()
	if self.synced or not self.isOpen or not self.eventRemote or not self.claimRemote then return end
	self.synced=true
	self.claimRemote:FireServer({kind="sync"})
end
function Client:close()
	self.isOpen=false
	for _,connection in ipairs(self.connections)do connection:Disconnect()end
	table.clear(self.connections)
	if self.folder then self.folder:Destroy();self.folder=nil end
	table.clear(self.spots);table.clear(self.popping);table.clear(self.gains);table.clear(self.pending);table.clear(self.backoff);self.taken=nil
	self.eventRemote,self.claimRemote,self.synced=nil,nil,false
end
function Client:destroy()
	if self.destroyed then return end
	self.destroyed=true;self.dead=true
	self.changed:Disconnect()
	if self.beat then self.beat:Disconnect()end
	self:close()
end

-- Drawing -------------------------------------------------------------------------------------------------------
function Client:holder()
	if self.folder and self.folder.Parent then return self.folder end
	local folder=Instance.new("Folder");folder.Name=Client.Folder;folder.Parent=self.world
	self.folder=folder
	return folder
end
function Client:draw(id,position)
	local p=part(self:holder(),"Find",position+Vector3.new(0,Client.Lift,0))
	p:SetAttribute("FindId",id)
	local glint=Instance.new("BillboardGui")
	glint.Name="Glint";glint.Size=UDim2.fromScale(Client.Size,Client.Size)
	glint.LightInfluence=0;glint.AlwaysOnTop=false;glint.MaxDistance=140
	glint.Parent=p
	local long=bar(glint,"Long",UDim2.fromScale(.16,1),90)
	local wide=bar(glint,"Wide",UDim2.fromScale(1,.16),0)
	local core=Instance.new("Frame")
	core.Name="Core";core.AnchorPoint=Vector2.new(.5,.5);core.Position=UDim2.fromScale(.5,.5);core.Size=UDim2.fromScale(.26,.26)
	core.BackgroundColor3=Client.Core;core.BorderSizePixel=0;core.Rotation=45
	local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(.3,0);corner.Parent=core
	core.Parent=glint
	local seed=0
	for i=1,#id do seed+=string.byte(id,i)end
	return{id=id,position=position,part=p,glint=glint,long=long,wide=wide,core=core,seed=seed%7}
end
local function remove(spot)if spot.part then spot.part:Destroy();spot.part=nil end end
function Client:pose(spot,scale,turn)
	if spot.scale~=scale then spot.scale=scale;spot.glint.Size=UDim2.fromScale(Client.Size*scale,Client.Size*scale)end
	if spot.turn~=turn then spot.turn=turn;spot.long.Rotation=turn;spot.wide.Rotation=turn end
end

-- Packets ---------------------------------------------------------------------------------------------------------
function Client:receive(packet)
	if type(packet)~="table"or not self.isOpen then return end
	local kind=packet.kind
	if kind=="spots"then return self:replace(packet.list)end
	local id=key(packet.id)
	if not id then return end
	if kind=="taken"then self:pop(id)
	elseif kind=="claimed"then
		local at=self:pop(id)or self.taken and self.taken[id]
		local xp=tonumber(packet.xp)
		if at and xp and xp>0 and xp==xp then self:gain(at,math.floor(xp+.5))end
		if self.taken then self.taken[id]=nil end
	elseif kind=="refused"then
		self.pending[id]=nil
		self.backoff[id]=self.now()+Client.Backoff
	elseif kind=="lost"then
		self.pending[id]=nil;self.backoff[id]=nil
		local spot=self.spots[id]
		if spot then remove(spot);self.spots[id]=nil end
		if self.taken then self.taken[id]=nil end
	end
end
-- The full list of my live finds: new ones drawn, missing ones taken away (a popping one finishes its pop).
function Client:replace(list)
	local live=Client.parse(list)
	for id,spot in pairs(self.spots)do
		if not live[id]then remove(spot);self.spots[id]=nil;self.pending[id]=nil;self.backoff[id]=nil end
	end
	for id,position in pairs(live)do
		local spot=self.spots[id]
		if spot and spot.position~=position then remove(spot);spot=nil end
		if not spot and not self.popping[id]then self.spots[id]=self:draw(id,position)end
	end
end
-- Accepted: the star bursts and goes. Answers where it was (nil if it was never drawn).
function Client:pop(id)
	self.pending[id]=nil;self.backoff[id]=nil
	local spot=self.spots[id]
	if not spot then return nil end
	self.spots[id]=nil
	self.taken=self.taken or {}
	self.taken[id]=spot.position
	local audio=self.d.audio
	if audio then
		pcall(audio.play,audio,"snack_sniff",1.05,Client.SniffGain)
		pcall(audio.play,audio,"snack_boost_sparkle",1,Client.SparkleGain)
	end
	if self.d.reduced and self.d.reduced()==true then remove(spot);return spot.position end
	local burst=Instance.new("ParticleEmitter")
	burst.Name="Burst";burst.Texture=Client.Texture;burst.Rate=0
	burst.Lifetime=NumberRange.new(.3,.55);burst.Speed=NumberRange.new(4,7);burst.SpreadAngle=Vector2.new(180,180)
	burst.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.35),NumberSequenceKeypoint.new(1,0)})
	burst.Color=ColorSequence.new(Client.Star,Client.Core);burst.LightEmission,burst.LightInfluence=1,0
	burst.Parent=spot.part
	pcall(function()burst:Emit(14)end)
	spot.t=0
	self.popping[id]=spot
	return spot.position
end
function Client:gain(position,xp)
	local p=part(self:holder(),"Gain",position+Vector3.new(0,Client.Lift+.9,0))
	local board=Instance.new("BillboardGui")
	board.Name="Gain";board.Size=UDim2.fromOffset(180,40);board.LightInfluence=0;board.AlwaysOnTop=true;board.MaxDistance=80
	board.Parent=p
	local label=Instance.new("TextLabel")
	label.Name="Text";label.BackgroundTransparency=1;label.Size=UDim2.fromScale(1,1)
	label.Font=Enum.Font.FredokaOne;label.TextScaled=true;label.TextColor3=Client.Core
	label.TextStrokeColor3=Color3.fromHex("#5A3A12");label.TextStrokeTransparency=.35
	label.Text=UICopy.get("finds.gain",{count=xp})
	label.Parent=board
	table.insert(self.gains,{part=p,board=board,label=label,t=0})
end

-- Per frame -------------------------------------------------------------------------------------------------------
function Client:step(dt)
	if self.isOpen and not Finds.on()then self:close()end -- off: gone within the frame, whatever the signal does
	if not self.isOpen then return end
	self.clock+=dt
	local reduced=self.d.reduced and self.d.reduced()==true
	local root=self.d.root()
	-- Pops and gains run on.
	for id,spot in pairs(self.popping)do
		spot.t+=dt
		local p=spot.t/Client.Pop
		if spot.glint and p<1 then
			self:pose(spot,Client.popScale(p),spot.turn or 0)
		elseif spot.glint then spot.glint:Destroy();spot.glint=nil end
		if spot.t>=Client.Hold then remove(spot);self.popping[id]=nil end
	end
	for index=#self.gains,1,-1 do
		local g=self.gains[index]
		g.t+=dt
		if not reduced then g.board.StudsOffset=Vector3.new(0,math.min(1,g.t/Client.Rise)*1.6,0)end
		local fade=math.clamp((g.t-Client.Rise*.55)/(Client.Rise*.45),0,1)
		g.label.TextTransparency=fade;g.label.TextStrokeTransparency=.35+.65*fade
		if g.t>=Client.Rise then g.part:Destroy();table.remove(self.gains,index)end
	end
	-- The live stars twinkle; the nearest one within Sniff is claimed, once.
	local now=self.now()
	local claimable=root~=nil and self.claimRemote~=nil and self:canClaim()
	local best,far=nil,math.huge
	for id,spot in pairs(self.spots)do
		local distance=if root then(spot.position-root).Magnitude else math.huge
		self:pose(spot,Client.twinkle(self.clock,distance<=Finds.Notice,reduced,spot.seed))
		local waited=self.pending[id]
		if waited and now-waited>=Client.Pending then self.pending[id]=nil;waited=nil end
		if claimable and distance<=Finds.Sniff and distance<far and not waited and now>=(self.backoff[id]or -math.huge)then best,far=id,distance end
	end
	if best then
		self.pending[best]=now
		self.claimRemote:FireServer({kind="claim",id=best})
	end
end
function Client:canClaim()
	local d=self.d
	return d.petOut()==true and d.free()==true and d.busy()~=true
end

-- What the rest of the client asks ----------------------------------------------------------------------------------
-- {waiting = live finds not yet taken, nearest = Vector3 or nil (the nearest to my character), distance}.
function Client:summary()
	local root=self.isOpen and self.d.root()
	local n,best,far=0,nil,math.huge
	for _,spot in pairs(self.spots)do
		n+=1
		local distance=if root then(spot.position-root).Magnitude else 0
		if best==nil or distance<far then best,far=spot.position,distance end
	end
	return{waiting=n,nearest=best,distance=if best and root then far else nil}
end
return Client
