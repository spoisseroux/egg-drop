-- Station attract (FEEL-ALIVE-DIRECTION-2026-11-13 D): the three hub stations
-- (and the Pet Park gateway, QA Q4) invite a new player over and stay findable once learned.
--   learned / far  : glow breath only (+-8 %)
--   marker (<=18)  : learned station: the marker (icon + pointer) and its name label, nothing loud
--   beckon (<=40)  : + marker, light shaft, ground ring, glow +-20 %
--   invite (<=14)  : + the marker hops, ring ripple, sparkles, one machine_attract ping, name label
-- QA v2 R5.1: the icon and its pointer are ONE connected marker (a map pin: the pointer is a
-- diamond tucked under the round icon), and it hops as one piece. The first time the player
-- comes near a station the label says what it is (name + one line); after that, the name only.
-- QA v2 R5.2: a used or coach-learned station used to go fully silent (only the glow), which read
-- as "the Hatch eggs station lost its indicator": learned stations now keep the marker on approach.
-- "Used" is remembered for the session on this client (a station stops beckoning
-- once its prompt was used); the saved coachMask bits make it permanent (learn).
-- Client presentation only: no remotes, no saves, never touches the prompts.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Data = require(script.Parent.StationAttractData)
local LoungeStations = require(script.Parent.LoungeStations)
local UICopy = require(Shared:WaitForChild("UICopy"))

local Attract = {}
Attract.__index = Attract
Attract.Data = Data

local Navy = Color3.fromHex("#24304F")

-- Pure state machine. visible=false (Board mode, menus, hatch, cradle docked,
-- just used) hides everything but the glow; distance nil = no listener.
function Attract.state(distance, used, visible)
	if not visible or type(distance) ~= "number" or distance ~= distance then return "hidden" end
	if used then return if distance <= Data.MarkerRange then "marker" else "learned" end
	if distance > Data.BeckonRange then return "learned" end
	if distance > Data.InviteRange then return "beckon" end
	return "invite"
end

-- Does this state show the marker (icon + pointer)? The name label?
function Attract.showsMarker(state)
	return state == "beckon" or state == "invite" or state == "marker"
end
function Attract.showsLabel(state, distance)
	return (state == "invite" or state == "marker") and type(distance) == "number" and distance <= Data.LabelRange
end

-- The label copy: name + line the first time (intro), the name alone after.
function Attract.labelText(id, intro)
	local name = UICopy.get("r5.station." .. id .. ".name")
	return name, if intro then UICopy.get("r5.station." .. id .. ".line") else nil
end

-- Ping gate: one per station per 45 s, one of any kind per 20 s, none in the first 10 s.
function Attract.canPing(now, startedAt, lastAny, lastStation)
	if now - startedAt < Data.PingJoin then return false end
	if lastAny and now - lastAny < Data.PingAny then return false end
	if lastStation and now - lastStation < Data.PingStation then return false end
	return true
end

-- Marker hop: two 0.5 s hops then a 1 s rest; returns 0..1 height.
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

-- Marker geometry in billboard scale (width 1, height MarkerAspect): the pointer diamond's
-- size, centre and tip. Its side corners sit on the icon disc's edge, so disc + pointer read as
-- one pin with no gap; the upper half hides behind the disc.
function Attract.pointerGeometry()
	local aspect, half, tip = Data.MarkerAspect, Data.PointerHalf, Data.PointerTip
	local side = half * math.sqrt(2)
	local centreY = (.5 + tip - half) / aspect
	return {
		size = UDim2.fromScale(side, side / aspect),
		position = UDim2.fromScale(.5, centreY),
		tipY = (.5 + tip) / aspect, -- fraction of the billboard height
		cornerRadius = math.sqrt(half * half + (tip - half) * (tip - half)), -- in icon widths (<= .5)
	}
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

local function buildLabel(anchor, id, spec, hue)
	local label = Instance.new("BillboardGui")
	label.Name, label.Adornee = "AttractLabel", anchor
	label.Size = UDim2.fromOffset(320, 84)
	-- Bottom edge on the anchor point: the pill sits just above the marker's icon.
	label.SizeOffset = Vector2.new(0, .5)
	-- MaxDistance is from the camera (well behind the player); Enabled does the range gating.
	label.MaxDistance, label.AlwaysOnTop, label.LightInfluence = Data.IconMaxDistance, false, 0
	label.ResetOnSpawn, label.Enabled = false, false
	label.Parent = anchor
	local pill = Instance.new("Frame")
	pill.Name, pill.AnchorPoint, pill.Position = "Pill", Vector2.new(.5, 1), UDim2.fromScale(.5, 1)
	pill.AutomaticSize, pill.Size = Enum.AutomaticSize.XY, UDim2.fromOffset(0, 0)
	pill.BackgroundColor3, pill.BackgroundTransparency = Navy, .08
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = pill
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness, stroke.ApplyStrokeMode = hue, 2, Enum.ApplyStrokeMode.Border
	stroke.Parent = pill
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 5), UDim.new(0, 6)
	pad.Parent = pill
	local list = Instance.new("UIListLayout")
	list.FillDirection, list.HorizontalAlignment = Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Center
	list.SortOrder, list.Padding = Enum.SortOrder.LayoutOrder, UDim.new(0, 1)
	list.Parent = pill
	local function text(name, order, size, font, color)
		local t = Instance.new("TextLabel")
		t.Name, t.LayoutOrder, t.BackgroundTransparency = name, order, 1
		t.AutomaticSize, t.Size = Enum.AutomaticSize.XY, UDim2.fromOffset(0, 0)
		t.Font, t.TextSize, t.TextColor3 = font, size, color
		t.TextWrapped = false
		t.Parent = pill
		return t
	end
	local name, line = Attract.labelText(id, true)
	local title = text("Name", 1, 20, Enum.Font.GothamBold, Color3.new(1, 1, 1))
	title.Text = name
	local sub = text("Line", 2, 15, Enum.Font.GothamMedium, Color3.fromHex(spec.light))
	sub.Text = line
	return label, title, sub
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
	-- The marker: one billboard holding the round icon and its pointer as one pin shape.
	local billboard = Instance.new("BillboardGui")
	billboard.Name, billboard.Adornee = "AttractIcon", anchor
	billboard.Size = UDim2.fromScale(Data.IconSize, Data.IconSize * Data.MarkerAspect)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, spec.iconHeight, 0)
	billboard.MaxDistance, billboard.AlwaysOnTop, billboard.LightInfluence = Data.IconMaxDistance, false, 0
	billboard.ResetOnSpawn, billboard.Enabled = false, false
	billboard.Parent = anchor
	local geometry = Attract.pointerGeometry()
	-- Pointer first (ZIndex 1): navy-edged diamond in the station hue; its top half sits behind the disc.
	local pointer = Instance.new("Frame")
	pointer.Name, pointer.AnchorPoint, pointer.BorderSizePixel = "Pointer", Vector2.new(.5, .5), 0
	pointer.Size, pointer.Position, pointer.Rotation = geometry.size, geometry.position, 45
	pointer.BackgroundColor3, pointer.ZIndex = hue, 1
	local edge = Instance.new("UIStroke")
	edge.Color, edge.Thickness = Navy, 3
	edge.Parent = pointer
	pointer.Parent = billboard
	local iconId = Data.IconIds[id]
	local icon
	if iconId then
		icon = Instance.new("ImageLabel")
		icon.Image, icon.BackgroundTransparency = "rbxassetid://" .. iconId, 1
	else
		-- Stand-in until the icon upload: navy disc, hue band, white face, glyph.
		icon = Instance.new("Frame")
		icon.BackgroundColor3 = Navy
		round(icon)
		local band = Instance.new("Frame")
		band.AnchorPoint, band.Position, band.Size = Vector2.new(.5, .5), UDim2.fromScale(.5, .5), UDim2.fromScale(.86, .86)
		band.BackgroundColor3, band.ZIndex = hue, 3
		round(band)
		band.Parent = icon
		local glyph = Instance.new("TextLabel")
		glyph.AnchorPoint, glyph.Position, glyph.Size = Vector2.new(.5, .5), UDim2.fromScale(.5, .5), UDim2.fromScale(.72, .72)
		glyph.BackgroundColor3, glyph.TextColor3, glyph.Text = Color3.new(1, 1, 1), hue, spec.glyph
		glyph.TextScaled, glyph.Font, glyph.ZIndex = true, Enum.Font.GothamBold, 4
		round(glyph)
		glyph.Parent = band
	end
	icon.Name, icon.ZIndex = "Icon", 2
	icon.Size = UDim2.fromScale(1, 1 / Data.MarkerAspect)
	icon.Parent = billboard
	local label, labelName, labelLine = buildLabel(anchor, id, spec, hue)
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
		ripple = ripple, rippleStroke = rippleStroke, billboard = billboard, icon = icon, pointer = pointer, sparkles = sparkles,
		label = label, labelName = labelName, labelLine = labelLine, intro = true, state = "hidden" }
end

-- options: {read=stationContext, triggered=PromptTriggered, player, voice=AmbientAudio,
--   reduced=function, cradleBusy=function, now=function, world=Instance, positions={id=Vector3}, auto=false}
function Attract.new(options)
	options = options or {}
	local now = options.now or os.clock
	local self = setmetatable({ options = options, now = now, startedAt = now(), used = {}, introduced = {}, introShown = {},
		hiddenUntil = 0, lastPing = {}, stations = {}, connections = {}, time = 0 }, Attract)
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
	self.introduced[id] = true
	self.hiddenUntil = self.now() + Data.HideAfterUse
	return true
end

-- Learned for good (onboarding v1: the machine's coachMask bit is saved): it stops beckoning
-- without the after-use hide that markUsed starts. It keeps its marker and short label.
function Attract:learn(id)
	if not Data.Stations[id] then return false end
	self.used[id] = true
	self.introduced[id] = true
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

-- Name label: intro (name + line) until the station is introduced, then the name alone.
function Attract:paintLabel(entry, shown, dt)
	local id = entry.id
	local intro = not self.introduced[id]
	if shown and intro then
		self.introShown[id] = (self.introShown[id] or 0) + dt
		if self.introShown[id] >= Data.IntroSeconds then self.introduced[id] = true; intro = false end
	end
	if entry.intro ~= intro then
		entry.intro = intro
		entry.labelLine.Visible = intro
	end
	entry.label.Enabled = shown
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
	if self.stations.Park and not self.used.Park and Attract.parkMember(position) then self.used.Park = true; self.introduced.Park = true end
	local bob = if reduced then 0 else math.sin(self.time * math.pi * 2 / Data.BobPeriod) * Data.BobHeight
	local hop = if reduced then 0 else Attract.hop(self.time) * Data.HopHeight
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
		entry.billboard.Enabled = Attract.showsMarker(mode)
		entry.sparkles.Enabled = mode == "invite" and not reduced
		-- The marker bobs while it beckons and hops (as one piece) while it invites; a learned marker holds still.
		local lift = if mode == "invite" then hop elseif mode == "beckon" then bob else 0
		local height = entry.spec.iconHeight + lift
		entry.billboard.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
		-- The label's bottom sits just above the icon disc (the billboard is centred on `height`).
		entry.label.StudsOffsetWorldSpace = Vector3.new(0, height + Data.IconSize * Data.MarkerAspect / 2 + .15, 0)
		self:paintLabel(entry, Attract.showsLabel(mode, distance), dt)
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
