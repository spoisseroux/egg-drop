-- What the wind moves (ALIVE-BUILD-PLAN-2026-11-22 step 4). Client only: CFrames of the frond bushes
-- (LoungeWorldV7Art.dressing) and the amplitude of WorldMotion's flags, pennants and chimes. No sizes,
-- parents, collisions or remotes. Wind.lua decides how windy it is; this only follows.
--
-- A bush is bound only from its WorldRestCFrame attribute (never from where it happens to be), is put
-- back on it before it first sways, and every pose is made from it, so nothing can drift. It leans
-- about its base. Out of range, parked (deck round, hatch) or stepped down it eases to rest; Reduced
-- Motion, the feature going off and destroy put it back at once. Off means nothing is connected but
-- the Alive signal.
local GuiService=game:GetService("GuiService")
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local Wind=require(script.Parent.Wind)

local Client={}
Client.__index=Client
Client.Rate=1/30
Client.SlowRate=1/15
Client.Select=.25 -- nearest bushes and hatch state, seconds
Client.Ease=.5 -- rest to swaying and back, seconds
Client.Slew=4 -- wind per second a follower may follow at: over a gust's own 1.9, so only a clock jump meets it
Client.MaxStep=.1 -- longest step, so a stall never jumps a pose
Client.Rest,Client.Peak=1.5,6 -- degrees, at the breeze and at full wind
Client.Cross=.35
Client.PeriodMin,Client.PeriodMax=1.8,2.4
Client.Phone={count=16,range=120}
Client.Desktop={count=44,range=200}
Client.SlowRange=60 -- budget level 1

local TAU=math.pi*2
local Side=Vector3.new(-Wind.Direction.Z,0,Wind.Direction.X)

-- Degrees for a wind of 0 to 1: nothing in still air, Rest at the breeze, Peak at full wind.
function Client.amplitude(wind)
	if type(wind)~="number"or wind~=wind or wind<=0 then return 0 end
	if wind<=Wind.Breeze then return Client.Rest*wind/Wind.Breeze end
	return Client.Rest+(Client.Peak-Client.Rest)*(math.min(wind,1)-Wind.Breeze)/(1-Wind.Breeze)
end

-- A bush leaning about its base: along the wind and a little across it, never past `degrees`.
function Client.pose(rest,base,degrees,turn)
	if degrees==0 then return rest end
	local angle=math.rad(degrees)
	return CFrame.new(base)*CFrame.fromAxisAngle(Side,angle*math.sin(TAU*turn))
		*CFrame.fromAxisAngle(Wind.Direction,angle*Client.Cross*math.cos(TAU*turn))*CFrame.new(-base)*rest
end

local function toward(value,goal,step)
	if value<goal then return math.min(goal,value+step)end
	return math.max(goal,value-step)
end

local function validRest(rest)
	if typeof(rest)~="CFrame"then return false end
	for _,n in ipairs({rest:GetComponents()})do
		if n~=n or n==math.huge or n==-math.huge then return false end
	end
	return true
end

-- True while a hatch owns the screen: the arrival hatch's own gui, or a reveal that ducks the sound.
local function hatching()
	local player=Players.LocalPlayer
	local gui=player and player:FindFirstChildOfClass("PlayerGui")
	local arrival=gui and gui:FindFirstChild("EggDropArrivalHatch")
	if arrival and arrival:IsA("ScreenGui")and arrival.Enabled then return true end
	local ambient=require(script.Parent.AmbientAudio).shared
	local audio=ambient and ambient.audio
	for _,entry in pairs(audio and audio.displayDucks or {})do
		if entry.active then return true end
	end
	return false
end
-- GardenLife parks on the same check.
Client.hatching=hatching

-- options (fixtures): world, motion, alive {on, changed}, level, now, eye, reduced, mode, hatching,
-- move(parts, frames), warn, touch, auto=false. The game passes only motion.
function Client.new(options)
	options=options or {}
	local self=setmetatable({world=options.world or workspace,motion=options.motion,auto=options.auto~=false,
		entries={},candidates={},gusts=setmetatable({},{__mode="k"}),connections={},links={},roomLinks={},
		elapsed=0,since=0,selectIn=0,clock=0,gain=0,enabled=false,busy=false},Client)
	local touch=options.touch
	if touch==nil then touch=UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled end
	self.caps=if touch then Client.Phone else Client.Desktop
	self.alive=options.alive or require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Alive"))
	self.level=options.level or require(script.Parent.AliveBudget).level
	self.now=options.now or function()return workspace:GetServerTimeNow()end
	self.eye=options.eye or function()local camera=workspace.CurrentCamera;return camera and camera.CFrame.Position end
	self.move=options.move or function(parts,frames)workspace:BulkMoveTo(parts,frames,Enum.BulkMoveMode.FireCFrameChanged)end
	self.hatching=options.hatching or hatching
	self.warn=options.warn or warn
	local board
	local function attribute(name)
		if not(board and board.Parent)then
			local boards=ReplicatedStorage:FindFirstChild("EggDropBoards")
			local player=Players.LocalPlayer
			board=boards and player and boards:FindFirstChild(tostring(player.UserId))
		end
		return board and board:GetAttribute(name)
	end
	self.mode=options.mode or function()return attribute("Mode")end
	self.reduced=options.reduced or function()return GuiService.ReducedMotionEnabled or attribute("ReducedEffects")==true end
	return self
end

-- The game's entry (WorldMotion.start): follows Alive.on("wind") for the rest of the session.
function Client.start(options)
	local self=Client.new(options)
	table.insert(self.connections,self.alive.changed("wind"):Connect(function()self:sync()end))
	self:sync()
	return self
end

function Client:sync()
	if self.destroyed then return end
	if self.alive.on("wind")~=true then self:disable();return end
	local ok,problem=pcall(self.enable,self)
	if not ok then self:fail(problem)end
end

local function clear(list)
	for _,connection in ipairs(list)do connection:Disconnect()end
	table.clear(list)
end

function Client:enable()
	if self.enabled or self.destroyed then return end
	self.enabled=true
	self.elapsed,self.since,self.selectIn,self.gain,self.hatch=0,0,0,0,false
	table.insert(self.links,self.world.ChildAdded:Connect(function(item)
		if item.Name=="EggDropLounge"and item.Parent==self.world then self:bind(item)end
	end))
	table.insert(self.links,self.world.ChildRemoved:Connect(function(item)
		if item==self.room then self:bind(self.world:FindFirstChild("EggDropLounge"))end
	end))
	self:bind(self.world:FindFirstChild("EggDropLounge"))
	if self.motion then
		self.hook=function(entry)return self:moverGust(entry)end
		self.motion.gust=self.hook
	end
	if self.auto then table.insert(self.links,RunService.Heartbeat:Connect(function(dt)self:frame(dt)end))end
end

-- Never a broken frame loop: rest, and off until the feature is switched again.
function Client:frame(dt)
	local ok,problem=pcall(self.step,self,dt)
	if not ok then self:fail(problem)end
end
function Client:fail(problem)
	self:disable()
	self.warn("[Wind] stopped: "..tostring(problem))
end

-- Off: exact rest in one write, then nothing left running. Everything is disconnected and forgotten
-- before that write, and the write itself cannot throw, so this always finishes and never comes back.
function Client:disable()
	if not self.enabled then return end
	self.enabled=false
	if self.motion and self.motion.gust==self.hook then self.motion.gust=nil end
	self.hook,self.gain=nil,0
	table.clear(self.gusts)
	clear(self.links)
	self:bind(nil)
end

-- Binding
function Client:forgetAll()
	local entries,candidates=self.entries,self.candidates
	self.entries,self.candidates,self.folder={},{},nil
	self.busy,self.selectIn=false,0
	for _,links in pairs(candidates)do clear(links)end
	self:restore(entries)
end

function Client:bind(room)
	clear(self.roomLinks)
	self.room=room
	self:forgetAll()
	if not room then return end
	local function dressing(folder)
		if folder.Name~="Dressing"or folder.Parent~=room or folder==self.folder then return end
		self:forgetAll()
		self.folder=folder
		table.insert(self.roomLinks,folder.ChildAdded:Connect(function(part)
			if folder==self.folder and part.Parent==folder then self:watch(part)end
		end))
		table.insert(self.roomLinks,folder.ChildRemoved:Connect(function(part)
			if folder==self.folder then self:forget(part)end
		end))
		for _,part in ipairs(folder:GetChildren())do self:watch(part)end
	end
	table.insert(self.roomLinks,room.ChildAdded:Connect(dressing))
	table.insert(self.roomLinks,room.ChildRemoved:Connect(function(item)if item==self.folder then self:forgetAll()end end))
	local folder=room:FindFirstChild("Dressing")
	if folder then dressing(folder)end
end

-- A bush whose attributes arrive late is bound when they do.
function Client:watch(part)
	if self.candidates[part]or not part:IsA("BasePart")then return end
	local links={}
	self.candidates[part]=links
	for _,name in ipairs({"WorldRestCFrame","WorldDressing"})do
		table.insert(links,part:GetAttributeChangedSignal(name):Connect(function()self:admit(part)end))
	end
	self:admit(part)
end

function Client:drop(part)
	for index,e in ipairs(self.entries)do
		if e.part==part then return table.remove(self.entries,index)end
	end
	return nil
end

function Client:forget(part)
	local links=self.candidates[part]
	if not links then return end
	clear(links)
	self.candidates[part]=nil
	-- It may come back (streaming, a rebuild): never leave it leaning.
	local e=self:drop(part)
	if e and not e.still then pcall(function()part.CFrame=e.rest end)end
end

function Client:admit(part)
	if not self.candidates[part]then return end
	local old=self:drop(part)
	local rest=part:GetAttribute("WorldRestCFrame")
	if part:GetAttribute("WorldDressing")~="bush"or not validRest(rest)or not part.Anchored then
		if old and not old.still then part.CFrame=old.rest end
		return
	end
	-- Stream-in or a rebuild may hand over a part mid-sway: rest first, always.
	if part.CFrame~=rest then part.CFrame=rest end
	local at=rest.Position
	local seed=math.floor(at.X*100+.5)*7+math.floor(at.Z*100+.5)*13
	table.insert(self.entries,{part=part,rest=rest,base=rest*Vector3.new(0,-part.Size.Y*.5,0),
		weight=0,wind=0,wanted=false,still=true,distance=0,
		period=Client.PeriodMin+(Client.PeriodMax-Client.PeriodMin)*Wind.hash(seed,4),phase=Wind.hash(seed,5)})
	self.selectIn=0
end

-- One bush, outside the bulk move (which only takes parts in the workspace). Never throws.
local function put(part,frame)
	pcall(function()part.CFrame=frame end)
end

-- These bushes back on their exact rest pose now, in one write (none when nothing had moved). Never
-- throws: a bush under a detached room, or a bulk move that fails, is written one part at a time.
function Client:restore(entries)
	local parts,frames={},{}
	for _,e in ipairs(entries)do
		local moved=not e.still
		e.weight,e.wind,e.wanted,e.still=0,0,false,true
		if not moved then continue end
		if e.part:IsDescendantOf(workspace)then table.insert(parts,e.part);table.insert(frames,e.rest)else put(e.part,e.rest)end
	end
	if #parts>0 and not pcall(self.move,parts,frames)then
		for index,part in ipairs(parts)do put(part,frames[index])end
	end
end

function Client:settle()
	self.busy,self.selectIn=false,0
	self:restore(self.entries)
end

-- Stepping
-- Which bushes may sway: the nearest `count` within `range` of the camera.
function Client:select(level)
	local eye=self.eye()
	local range=if level>=1 then math.min(self.caps.range,Client.SlowRange)else self.caps.range
	local near={}
	for _,e in ipairs(self.entries)do
		e.wanted=false
		e.distance=if typeof(eye)=="Vector3"then(e.rest.Position-eye).Magnitude else math.huge
		if e.distance<=range then table.insert(near,e)end
	end
	table.sort(near,function(a,b)return a.distance<b.distance end)
	for index=1,math.min(#near,self.caps.count)do near[index].wanted=true end
end

-- WorldMotion asks per flag, pennant or chime: the gust where it hangs, 0 while parked.
function Client:moverGust(entry)
	return if self.gain>0 then(self.gusts[entry]or 0)*self.gain else 0
end

function Client:stepMovers(tick,time,calm)
	self.gain=toward(self.gain,if calm then 0 else 1,tick/Client.Ease)
	local entries=self.motion and self.motion.entries
	if not entries or self.gain==0 then
		table.clear(self.gusts)
		return
	end
	for _,entry in ipairs(entries)do
		if entry.gain then
			self.gusts[entry]=toward(self.gusts[entry]or 0,Wind.gust(entry.rest.Position,time),Client.Slew*tick)
		end
	end
end

function Client:step(dt)
	if self.destroyed or not self.enabled then return end
	if type(dt)~="number"or dt~=dt or dt<=0 then return end
	dt=math.min(dt,Client.MaxStep)
	self.elapsed+=dt;self.since+=dt
	local level=self.level()
	local rate=if level>=1 then Client.SlowRate else Client.Rate
	if self.elapsed<rate then return end
	self.elapsed%=rate
	local tick=math.min(self.since,Client.MaxStep)
	self.since=0
	if self.reduced()then
		-- Still at once (the rustle is sound and stays: AmbientAudio).
		if self.busy then self:settle()end
		self.gain=0
		table.clear(self.gusts)
		return
	end
	self.selectIn-=tick
	local choose=self.selectIn<=0
	if choose then
		self.selectIn=Client.Select
		local ok,hatch=pcall(self.hatching)
		self.hatch=ok and hatch==true
	end
	local calm=level>=2 or self.hatch==true or self.mode()~="Room"
	local time=self.now()
	self:stepMovers(tick,time,calm)
	if calm and not self.busy then return end
	if choose and not calm then self:select(level)end
	self.clock+=tick
	local parts,frames={},{}
	local busy=false
	for _,e in ipairs(self.entries)do
		e.weight=toward(e.weight,if e.wanted and not calm then 1 else 0,tick/Client.Ease)
		if e.weight>0 then
			busy=true
			if e.part:IsDescendantOf(workspace)then
				e.wind=toward(e.wind,Wind.at(e.rest.Position,time),Client.Slew*tick)
				e.still=false
				local shown=e.weight*e.weight*(3-2*e.weight)
				table.insert(parts,e.part)
				table.insert(frames,Client.pose(e.rest,e.base,Client.amplitude(e.wind)*shown,self.clock/e.period+e.phase))
			end
		elseif not e.still then
			e.still,e.wind=true,0
			if e.part:IsDescendantOf(workspace)then table.insert(parts,e.part);table.insert(frames,e.rest)else put(e.part,e.rest)end
		end
	end
	self.busy=busy
	if #parts>0 then self.move(parts,frames)end
end

function Client:destroy()
	if self.destroyed then return end
	self.destroyed=true
	clear(self.connections)
	self:disable()
end

return Client
