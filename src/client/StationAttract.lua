-- Station attract (FEEL-ALIVE-DIRECTION-2026-11-13 D): the three hub stations
-- (and the Pet Park gateway, QA Q4) invite a new player over and go quiet once learned.
--   learned / far  : glow breath only (+-8 %)
--   beckon (<=40)  : + icon, light shaft, ground ring, glow +-20 %
--   invite (<=14)  : + bouncing chevron, ring ripple, sparkles, one machine_attract ping
-- "Used" is remembered for the session on this client (a station stops beckoning
-- once its prompt was used); a later save flag (coachMask) makes it permanent.
-- Client presentation only: no remotes, no saves, never touches the prompts.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Data = require(script.Parent.StationAttractData)
local LoungeStations = require(script.Parent.LoungeStations)

local Attract = {}
Attract.__index = Attract
Attract.Data = Data

-- Pure state machine. visible=false (Board mode, menus, hatch, cradle docked,
-- just used) hides everything but the glow; distance nil = no listener.
function Attract.state(distance, used, visible)
	if not visible or type(distance) ~= "number" or distance ~= distance then return "hidden" end
	if used or distance > Data.BeckonRange then return "learned" end
	if distance > Data.InviteRange then return "beckon" end
	return "invite"
end

-- Ping gate: one per station per 45 s, one of any kind per 20 s, none in the first 10 s.
function Attract.canPing(now, startedAt, lastAny, lastStation)
	if now - startedAt < Data.PingJoin then return false end
	if lastAny and now - lastAny < Data.PingAny then return false end
	if lastStation and now - lastStation < Data.PingStation then return false end
	return true
end

-- Chevron: two 0.5 s hops then a 1 s rest; returns 0..1 height.
function Attract.hop(time)
	local cycle = Data.HopTime * 2 + Data.HopRest
	local t = time % cycle
	if t >= Data.HopTime * 2 then return 0 end
	return math.sin((t % Data.HopTime) / Data.HopTime * math.pi)
end

function Attract.breath(state, time)
	local amp = if state == "beckon" or state == "invite" then Data.BreathActive else Data.BreathLearned
	return 1 + amp * math.sin(time * math.pi * 2 / Data.BreathPeriod)
end

local function part(parent, name, size, cframe)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.Transparency, p.Size, p.CFrame = 1, size, cframe
	p.Parent = parent
	return p
end

local function round(frame)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(.5, 0)
	corner.Parent = frame
end

local function build(folder, id, base)
	local spec = Data.Stations[id]
	local hue, light = Color3.fromHex(spec.hue), Color3.fromHex(spec.light)
	local anchor = part(folder, id .. "Attract", Vector3.new(.2, .2, .2), CFrame.new(base))
	local glow = Instance.new("PointLight")
	glow.Name, glow.Color, glow.Range, glow.Shadows = "AttractGlow", light, Data.GlowRange, false
	glow.Brightness = Data.GlowBrightness
	local glowAt = Instance.new("Attachment")
	glowAt.Position = Vector3.new(0, 3, 0)
	glowAt.Parent = anchor
	glow.Parent = glowAt
	-- Light shaft: a camera-facing beam, 75 % to 100 % transparent.
	local foot, top = Instance.new("Attachment"), Instance.new("Attachment")
	foot.Position, top.Position = Vector3.new(0, .2, 0), Vector3.new(0, Data.ShaftHeight, 0)
	foot.Parent, top.Parent = anchor, anchor
	local shaft = Instance.new("Beam")
	shaft.Name, shaft.Attachment0, shaft.Attachment1 = "AttractShaft", foot, top
	shaft.FaceCamera, shaft.LightEmission, shaft.LightInfluence = true, 1, 0
	shaft.Width0, shaft.Width1, shaft.Segments = 2.4, 1.2, 1
	shaft.Color = ColorSequence.new(light)
	shaft.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, .75), NumberSequenceKeypoint.new(1, 1) })
	shaft.Enabled = false
	shaft.Parent = anchor
	-- Ground ring: a rounded frame's stroke on a flat surface (no texture upload).
	local span = Data.RingRadius * 2 + 1.2
	local ringPart = part(folder, id .. "AttractRing", Vector3.new(span, .05, span), CFrame.new(base + Vector3.new(0, .08, 0)))
	local surface = Instance.new("SurfaceGui")
	surface.Face, surface.LightInfluence, surface.AlwaysOnTop = Enum.NormalId.Top, 0, false
	surface.SizingMode, surface.PixelsPerStud = Enum.SurfaceGuiSizingMode.PixelsPerStud, 40
	surface.Enabled = false
	surface.Parent = ringPart
	local function circle(name, scale, thickness, transparency)
		local frame = Instance.new("Frame")
		frame.Name, frame.AnchorPoint, frame.Position = name, Vector2.new(.5, .5), UDim2.fromScale(.5, .5)
		frame.Size, frame.BackgroundTransparency = UDim2.fromScale(scale, scale), 1
		round(frame)
		local stroke = Instance.new("UIStroke")
		stroke.Color, stroke.Thickness, stroke.Transparency = hue, thickness, transparency
		stroke.Parent = frame
		frame.Parent = surface
		return frame, stroke
	end
	local ring = circle("Ring", Data.RingRadius * 2 / span, 6, .1)
	local ripple, rippleStroke = circle("Ripple", Data.RingRadius * 2 / span, 4, 1)
	-- Icon + chevron billboard.
	local billboard = Instance.new("BillboardGui")
	billboard.Name, billboard.Adornee = "AttractIcon", anchor
	billboard.Size = UDim2.fromScale(Data.IconSize, Data.IconSize * 1.6)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, spec.iconHeight, 0)
	billboard.MaxDistance, billboard.AlwaysOnTop, billboard.LightInfluence = Data.IconMaxDistance, false, 0
	billboard.ResetOnSpawn, billboard.Enabled = false, false
	billboard.Parent = anchor
	local iconId = Data.IconIds[id]
	local icon
	if iconId then
		icon = Instance.new("ImageLabel")
		icon.Image, icon.BackgroundTransparency = "rbxassetid://" .. iconId, 1
	else
		-- Stand-in until the icon upload: navy disc, hue band, white face, glyph.
		icon = Instance.new("Frame")
		icon.BackgroundColor3 = Color3.fromHex("#24304F")
		round(icon)
		local band = Instance.new("Frame")
		band.AnchorPoint, band.Position, band.Size = Vector2.new(.5, .5), UDim2.fromScale(.5, .5), UDim2.fromScale(.86, .86)
		band.BackgroundColor3 = hue
		round(band)
		band.Parent = icon
		local glyph = Instance.new("TextLabel")
		glyph.AnchorPoint, glyph.Position, glyph.Size = Vector2.new(.5, .5), UDim2.fromScale(.5, .5), UDim2.fromScale(.72, .72)
		glyph.BackgroundColor3, glyph.TextColor3, glyph.Text = Color3.new(1, 1, 1), hue, spec.glyph
		glyph.TextScaled, glyph.Font = true, Enum.Font.GothamBold
		round(glyph)
		glyph.Parent = band
	end
	icon.Name, icon.Size = "Icon", UDim2.fromScale(1, 1 / 1.6)
	icon.Parent = billboard
	local chevron = Instance.new("Frame")
	chevron.Name, chevron.BackgroundTransparency = "Chevron", 1
	chevron.AnchorPoint, chevron.Size = Vector2.new(.5, 0), UDim2.fromScale(.5, .25)
	chevron.Position = UDim2.fromScale(.5, .68)
	chevron.Visible = false
	chevron.Parent = billboard
	for side = -1, 1, 2 do
		local bar = Instance.new("Frame")
		bar.AnchorPoint, bar.BackgroundColor3, bar.BorderSizePixel = Vector2.new(.5, .5), hue, 0
		bar.Size, bar.Position = UDim2.fromScale(.62, .22), UDim2.fromScale(.5 + side * .19, .45)
		bar.Rotation = side * -38
		local stroke = Instance.new("UIStroke")
		stroke.Color, stroke.Thickness = Color3.fromHex("#24304F"), 2
		stroke.Parent = bar
		bar.Parent = chevron
	end
	local sparkAt = Instance.new("Attachment")
	sparkAt.Position = Vector3.new(0, 2.5, 0)
	sparkAt.Parent = anchor
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name, sparkles.Texture = "AttractSparkles", "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color, sparkles.LightEmission, sparkles.Rate = ColorSequence.new(light), 1, 2
	sparkles.Lifetime, sparkles.Speed = NumberRange.new(1.2, 1.8), NumberRange.new(.6, 1.1)
	sparkles.SpreadAngle, sparkles.Size = Vector2.new(60, 60), NumberSequence.new(.25, 0)
	sparkles.Transparency = NumberSequence.new(.2, 1)
	sparkles.Enabled = false
	sparkles.Parent = sparkAt
	return { id = id, base = base, spec = spec, anchor = anchor, ringPart = ringPart, glow = glow, shaft = shaft, surface = surface, ring = ring,
		ripple = ripple, rippleStroke = rippleStroke, billboard = billboard, chevron = chevron, sparkles = sparkles, state = "hidden" }
end

-- options: {read=stationContext, triggered=PromptTriggered, player, voice=AmbientAudio,
--   reduced=function, cradleBusy=function, now=function, world=Instance, positions={id=Vector3}, auto=false}
function Attract.new(options)
	options = options or {}
	local now = options.now or os.clock
	local self = setmetatable({ options = options, now = now, startedAt = now(), used = {}, hiddenUntil = 0,
		lastPing = {}, stations = {}, connections = {}, time = 0 }, Attract)
	local folder = Instance.new("Folder")
	folder.Name = "EggDropStationAttract"
	folder.Parent = options.world or workspace
	self.folder = folder
	local positions = options.positions
	if not positions then
		local World = require(Shared:WaitForChild("HollowWorldLayout"))
		positions = {}
		for _, id in ipairs(Data.Order) do
			local station = World.Stations and World.Stations[id]
			if station then positions[id] = station.Position end
		end
	end
	if not options.positions then positions.Park = Attract.parkAnchor() end
	for _, id in ipairs(Data.Order) do
		if positions[id] then self.stations[id] = build(folder, id, positions[id]) end
	end
	if options.triggered then
		table.insert(self.connections, options.triggered:Connect(function(prompt, who)
			if who ~= (options.player or Players.LocalPlayer) then return end
			self:markUsed(prompt:GetAttribute("PocketClubStation"))
		end))
	end
	if options.auto ~= false then
		table.insert(self.connections, RunService.Heartbeat:Connect(function(dt) self:step(dt) end))
	end
	return self
end

-- Pet Park (QA Q4): the icon hovers over the east gateway the arrival path leads to. nil when the
-- park flag is off or this world has no park.
local parkLayout = nil -- ParkLayout once the park flag is confirmed on (false = no park)
local function park()
	if parkLayout == nil then
		local ok, layout = pcall(function()
			local Flags = require(Shared:WaitForChild("FeatureFlags"))
			local Park = require(Shared:WaitForChild("ParkLayout"))
			return if Flags.Park == true and Park.Enabled then Park else false
		end)
		parkLayout = if ok then layout else false
	end
	return parkLayout or nil
end
function Attract.parkAnchor()
	local Park = park()
	local gate = Park and Park.Gateways[1]
	return gate and gate.position or nil
end

-- The park has no prompt: it is learned the first time the player stands inside the kerb.
function Attract.parkMember(position)
	local Park = park()
	return Park ~= nil and typeof(position) == "Vector3" and Park.member(position, false)
end

function Attract:markUsed(id)
	if not Data.Stations[id] then return false end
	self.used[id] = true
	self.hiddenUntil = self.now() + Data.HideAfterUse
	return true
end

-- Learned for good (onboarding v1: the machine's coachMask bit is saved): it stops beckoning
-- without the after-use hide that markUsed starts.
function Attract:learn(id)
	if not Data.Stations[id] then return false end
	self.used[id] = true
	return true
end

function Attract:visible(state)
	if self.now() < self.hiddenUntil then return false end
	return state ~= nil and LoungeStations.canRoam(state)
end

function Attract:ping(entry, now)
	local voice = self.options.voice
	if not Attract.canPing(now, self.startedAt, self.lastAny, self.lastPing[entry.id]) then return false end
	if not voice or not voice:play("machine_attract", entry.spec.pitch, Data.PingVolume) then return false end
	self.lastAny, self.lastPing[entry.id] = now, now
	return true
end

function Attract:step(dt)
	if self.destroyed then return end
	dt = math.clamp(dt or 0, 0, .25)
	self.time += dt
	local now = self.now()
	local state = self.options.read and self.options.read() or nil
	local reduced = self.options.reduced and self.options.reduced() == true
	local visible = self:visible(state)
	local position = state and state.position
	if self.stations.Park and not self.used.Park and Attract.parkMember(position) then self.used.Park = true end
	for id, entry in pairs(self.stations) do
		local shown = visible and not (id == "Journal" and self.options.cradleBusy and self.options.cradleBusy())
		local distance = position and (position - entry.base).Magnitude or nil
		local mode = Attract.state(distance, self.used[id] == true, shown)
		if mode == "invite" and entry.state ~= "invite" then self:ping(entry, now) end
		entry.state = mode
		local active = mode == "beckon" or mode == "invite"
		entry.glow.Brightness = Data.GlowBrightness * (if reduced then 1 else Attract.breath(mode, self.time))
		entry.shaft.Enabled = active
		entry.surface.Enabled = active
		entry.billboard.Enabled = active
		entry.chevron.Visible = mode == "invite"
		entry.sparkles.Enabled = mode == "invite" and not reduced
		local bob = if reduced then 0 else math.sin(self.time * math.pi * 2 / Data.BobPeriod) * Data.BobHeight
		entry.billboard.StudsOffsetWorldSpace = Vector3.new(0, entry.spec.iconHeight + bob, 0)
		local hop = if reduced then 0 else Attract.hop(self.time)
		entry.chevron.Position = UDim2.fromScale(.5, .68 - hop * .08)
		if mode == "invite" and not reduced then
			local t = (self.time % Data.RippleEvery) / Data.RippleEvery
			local base = Data.RingRadius * 2 / entry.ringPart.Size.X
			entry.ripple.Size = UDim2.fromScale(base * (1 + t * .12), base * (1 + t * .12))
			entry.rippleStroke.Transparency = .2 + .8 * t
		else
			entry.rippleStroke.Transparency = 1
		end
	end
end

function Attract:destroy()
	if self.destroyed then return end
	self.destroyed = true
	for _, connection in ipairs(self.connections) do connection:Disconnect() end
	table.clear(self.connections)
	self.folder:Destroy()
end

return Attract
