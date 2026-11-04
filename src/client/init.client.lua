local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage.Shared.BoardConfig)
local Jelly = require(script.JellyVisual)
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local request = remotes:WaitForChild("BoardRequest")
local feedback = remotes:WaitForChild("BoardMerge")
local impacts = remotes:WaitForChild("BoardImpact")
local board = ReplicatedStorage:WaitForChild("EggDropBoards"):WaitForChild(tostring(player.UserId))

local ink = Color3.fromRGB(255, 241, 207)
local navy = Color3.fromRGB(25, 23, 46)
local panel = Color3.fromRGB(48, 39, 69)
local mint = Color3.fromRGB(168, 239, 181)
local rim = Color3.fromRGB(112, 83, 122)

local function make(class, name, properties, parent)
	local instance = Instance.new(class)
	instance.Name = name
	for key, value in pairs(properties) do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local function label(class, name, content, parent, background)
	return make(class, name, {
		Text = content, Font = Enum.Font.Code, TextSize = 15, TextColor3 = ink,
		BackgroundColor3 = background or panel, BackgroundTransparency = background and 0 or 1,
		BorderSizePixel = 0,
	}, parent)
end

local gui = make("ScreenGui", "EggDrop", {
	ResetOnSpawn = false, ScreenInsets = Enum.ScreenInsets.None, DisplayOrder = 10,
}, player:WaitForChild("PlayerGui"))
local backdrop = make("Frame", "Backdrop", {
	BackgroundColor3 = navy, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
}, gui)
-- A viewport renders the board inside the HUD, using the same projection on desktop and phone.
local viewport = make("ViewportFrame", "Tray", {
	BackgroundColor3 = Color3.fromRGB(40, 50, 67), BorderSizePixel = 0,
	Ambient = Color3.fromRGB(180, 175, 190), LightColor = Color3.fromRGB(255, 239, 217),
	LightDirection = Vector3.new(-1, -2, -3),
}, backdrop)
local scene = make("WorldModel", "Scene", {}, viewport)
local trayCamera = make("Camera", "TrayCamera", {
	FieldOfView = 35,
}, viewport)
viewport.CurrentCamera = trayCamera
local overlay = make("Frame", "TrayOverlay", {
	BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 2,
}, backdrop)
local effects = make("Frame", "MergeEffects", {
	BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3,
}, overlay)

local function surface(name, size, transform, color)
	return make("Part", name, {
		Anchored = true, Size = size, CFrame = transform, Color = color, Material = Enum.Material.SmoothPlastic,
	}, scene)
end

local halfWidth = Config.Width / 2
local railDepth = 0.65
surface("Floor", Vector3.new(Config.Width + 0.5, 0.32, railDepth), CFrame.new(0, -0.16, 0), rim)
for _, sign in ipairs({ -1, 1 }) do
	surface("Wall", Vector3.new(0.32, Config.Height, railDepth),
		CFrame.new(sign * (halfWidth + 0.16), Config.Height / 2, 0), rim)
	surface("Bank", Vector3.new(Config.Bank * math.sqrt(2), 0.31, railDepth),
		CFrame.new(sign * (halfWidth - Config.Bank / 2), Config.Bank / 2, 0)
			* CFrame.Angles(0, 0, sign * math.pi / 4), rim)
end

local title = label("TextLabel", "Title", "EGG DROP / BOARD LAB", backdrop)
title.TextSize = 18
local rail = label("TextButton", "AimRail", "", backdrop, Color3.fromRGB(60, 64, 90))
rail.AutoButtonColor = false
local track = make("Frame", "Guide", {
	BackgroundColor3 = mint, BackgroundTransparency = 0.4, BorderSizePixel = 0,
	Size = UDim2.new(0, 2, 1, 0), ZIndex = 3,
}, overlay)
local ghost = label("TextLabel", "NextEgg", "", overlay, mint)
ghost.AnchorPoint = Vector2.new(0.5, 0.5)
ghost.TextColor3 = navy
ghost.ZIndex = 4
make("UICorner", "Round", { CornerRadius = UDim.new(0.5, 0) }, ghost)

local status = label("TextLabel", "Status", "", backdrop)
local hint = label("TextLabel", "Hint", "Drag the rail and release to drop", backdrop)
hint.TextSize = 13
local gentle = label("TextButton", "Gentle", "Gentle", backdrop, panel)
local springy = label("TextButton", "Springy", "Springy", backdrop, panel)
local reset = label("TextButton", "Reset", "Reset", backdrop, panel)
local plop = make("Sound", "EggDropPlop", {
	SoundId = "rbxasset://sounds/impact_water.mp3", Volume = 0.25,
}, SoundService)
local chimes = {}
for i = 1, 3 do
	chimes[i] = make("Sound", "EggDropChime" .. i, {
		SoundId = "rbxasset://sounds/volume_slider.ogg", Volume = 0.37,
	}, SoundService)
end
local chimeIndex = 0
local lastPlop = -math.huge

local aim = 0.5
local drag
local eggViews = {}
local viewsById = {}

local function nextTier()
	return board:GetAttribute("NextTier") or 1
end

local function project(position)
	local size = viewport.AbsoluteSize
	local pixelsPerStud = size.X / (Config.Width + 0.8)
	return Vector2.new(size.X / 2 + position.X * pixelsPerStud,
		size.Y / 2 - (position.Y - Config.Height / 2) * pixelsPerStud), pixelsPerStud
end

local function drawAim()
	local tier = nextTier()
	local position, scale = project(Vector2.new(Config.aimX(aim, tier), Config.SpawnY))
	local diameter = Config.Tiers[tier].radius * 2 * scale
	track.Position = UDim2.fromOffset(position.X - 1, position.Y)
	track.Size = UDim2.fromOffset(2, math.max(0, viewport.AbsoluteSize.Y - position.Y))
	ghost.Position = UDim2.fromOffset(position.X, position.Y)
	ghost.Size = UDim2.fromOffset(diameter, diameter)
	ghost.Text = Config.Tiers[tier].mark
	ghost.BackgroundColor3 = Config.Tiers[tier].color
	rail.Text = "DRAG TO AIM   ·   NEXT " .. Config.Tiers[tier].mark
end

local function updateHud()
	local merges = board:GetAttribute("Merges") or 0
	local chain = board:GetAttribute("Chain") or 0
	status.Text = string.format("MERGES %d     LAST CHAIN x%d", merges, chain)
	for _, button in ipairs({ gentle, springy }) do
		local selected = board:GetAttribute("Preset") == button.Name
		button.BackgroundColor3 = if selected then mint else panel
		button.TextColor3 = if selected then navy else ink
	end
	drawAim()
end

local function layout()
	local screen = backdrop.AbsoluteSize
	local width = math.max(1, math.min(380, screen.X - 24, (screen.Y - 211) * (Config.Width + 0.8) / (Config.Height + 0.8)))
	local height = width * (Config.Height + 0.8) / (Config.Width + 0.8)
	local left = (screen.X - width) / 2
	local top = math.max(54, (screen.Y - height - 90) / 2)
	viewport.Position = UDim2.fromOffset(left, top + 50)
	viewport.Size = UDim2.fromOffset(width, height)
	overlay.Position = viewport.Position
	overlay.Size = viewport.Size
	title.Position = UDim2.fromOffset(left, top - 27)
	title.Size = UDim2.fromOffset(width, 24)
	rail.Position = UDim2.fromOffset(left, top)
	rail.Size = UDim2.fromOffset(width, 46)
	local foot = top + 50 + height
	status.Position = UDim2.fromOffset(left, foot + 3)
	status.Size = UDim2.fromOffset(width, 21)
	hint.Position = UDim2.fromOffset(left, foot + 26)
	hint.Size = UDim2.fromOffset(width, 20)
	for index, button in ipairs({ gentle, springy, reset }) do
		local buttonWidth = (width - 12) / 3
		button.Position = UDim2.fromOffset(left + (index - 1) * (buttonWidth + 6), foot + 51)
		button.Size = UDim2.fromOffset(buttonWidth, 44)
	end
	local distance = (Config.Height + 0.8) / (2 * math.tan(math.rad(trayCamera.FieldOfView / 2)))
	trayCamera.CFrame = CFrame.lookAt(Vector3.new(0, Config.Height / 2, distance), Vector3.new(0, Config.Height / 2, 0))
end

local function aimFromScreen(x)
	local center = viewport.AbsolutePosition.X + viewport.AbsoluteSize.X / 2
	local span = viewport.AbsoluteSize.X * (Config.Width / 2 - Config.Tiers[nextTier()].radius) / (Config.Width + 0.8)
	aim = math.clamp(0.5 + (x - center) / math.max(1, 2 * span), 0, 1)
	drawAim()
end

rail.InputBegan:Connect(function(input)
	local kind = input.UserInputType
	if not drag and (kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch) then
		drag = input
		aimFromScreen(input.Position.X)
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if drag and (input == drag or (drag.UserInputType == Enum.UserInputType.MouseButton1
		and input.UserInputType == Enum.UserInputType.MouseMovement)) then
		aimFromScreen(input.Position.X)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if drag and (input == drag or (drag.UserInputType == Enum.UserInputType.MouseButton1
		and input.UserInputType == Enum.UserInputType.MouseButton1)) then
		drag = nil
		if input.UserInputState == Enum.UserInputState.End then
			aimFromScreen(input.Position.X)
			request:FireServer("drop", aim)
		end
	end
end)
UserInputService.WindowFocusReleased:Connect(function()
	drag = nil
end)
for _, button in ipairs({ gentle, springy }) do
	button.Activated:Connect(function()
		request:FireServer("preset", button.Name)
	end)
end
reset.Activated:Connect(function()
	request:FireServer("reset")
end)

local function addView(source)
	local tier = source:GetAttribute("Tier")
	local id = source:GetAttribute("EggId")
	if not tier or not id then
		return
	end
	local gel = Jelly.new(scene, source)
	local mark = label("TextLabel", "Mark", Config.Tiers[tier].mark, overlay)
	mark.AnchorPoint = Vector2.new(0.5, 0.5)
	mark.TextColor3 = navy
	mark.Size = UDim2.fromOffset(30, 22)
	mark.ZIndex = 4
	eggViews[source] = { gel = gel, mark = mark, id = id }
	viewsById[id] = gel
end

board.ChildAdded:Connect(addView)
board.ChildRemoved:Connect(function(source)
	local view = eggViews[source]
	if view then
		view.gel:destroy()
		view.mark:Destroy()
		viewsById[view.id] = nil
		eggViews[source] = nil
	end
end)
for _, source in ipairs(board:GetChildren()) do
	addView(source)
end

impacts.OnClientEvent:Connect(function(batch)
	local strongest = 0
	for _, impact in ipairs(batch) do
		local gel = viewsById[impact[1]]
		if gel then
			gel:impact(impact[2], impact[3])
			strongest = math.max(strongest, impact[3])
		end
	end
	local now = os.clock()
	if strongest >= 9 and now - lastPlop >= 0.13 then
		lastPlop = now
		plop.PlaybackSpeed = math.clamp(0.82 + strongest / 100, 0.9, 1.2)
		plop.Volume = math.clamp(strongest / 90, 0.13, 0.35)
		plop.TimePosition = 0
		plop:Play()
	end
end)

local function gelDrop(from, to, diameter, color, duration, outward)
	local dot = make("Frame", "GelDrop", {
		AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = color, BorderSizePixel = 0,
		BackgroundTransparency = 0.18, ZIndex = 3,
		Position = UDim2.fromOffset(from.X, from.Y),
		Size = UDim2.fromOffset(diameter, diameter),
	}, effects)
	make("UICorner", "Round", { CornerRadius = UDim.new(0.5, 0) }, dot)
	local tween = TweenService:Create(dot, TweenInfo.new(duration, Enum.EasingStyle.Quad), {
		Position = UDim2.fromOffset(to.X, to.Y),
		Size = UDim2.fromOffset(diameter * 0.5, diameter * 0.5),
		BackgroundTransparency = if outward then 1 else 0.65,
	})
	tween.Completed:Once(function()
		dot:Destroy()
	end)
	tween:Play()
end

feedback.OnClientEvent:Connect(function(position, tier, chain, first, second)
	local point = project(position)
	local color = Config.Tiers[tier].color
	local scale = viewport.AbsoluteSize.X / (Config.Width + 0.8)
	local firstPoint, secondPoint = project(first), project(second)
	local diameter = scale * Config.Tiers[tier - 1].radius
	gelDrop(firstPoint, point, diameter, color, 0.12, false)
	gelDrop(secondPoint, point, diameter, color, 0.12, false)
	for i = 1, 5 do
		local angle = i * math.pi * 2 / 5 + chain * 0.5
		local delta = Vector2.new(math.cos(angle), math.sin(angle)) * scale * 2
		gelDrop(point, point + delta, math.max(3, scale * 0.27), color, 0.3, true)
	end
	local pop = label("TextLabel", "MergePop", if chain > 1 then "CHAIN x" .. chain else "POP!", effects)
	pop.TextColor3 = color
	pop.TextStrokeColor3 = navy
	pop.TextStrokeTransparency = 0.05
	pop.TextSize = if chain > 1 then 23 else 18
	pop.AnchorPoint = Vector2.new(0.5, 0.5)
	pop.Size = UDim2.fromOffset(120, 27)
	pop.Position = UDim2.fromOffset(point.X, point.Y)
	pop.ZIndex = 5
	if chain > 1 then
		point -= Vector2.new(0, 21)
		pop.Position = UDim2.fromOffset(point.X, point.Y)
	end
	local tween = TweenService:Create(pop, TweenInfo.new(0.62, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.fromOffset(point.X, point.Y - 44), TextTransparency = 1, TextStrokeTransparency = 1,
	})
	tween.Completed:Once(function()
		pop:Destroy()
	end)
	tween:Play()
	chimeIndex = chimeIndex % #chimes + 1
	local chime = chimes[chimeIndex]
	chime.PlaybackSpeed = 1 + (tier - 1) * 0.18 + math.min(chain, 5) * 0.05
	chime.TimePosition = 0
	chime:Play()
end)

board.AttributeChanged:Connect(updateHud)
board:GetAttributeChangedSignal("ResetId"):Connect(function()
	effects:ClearAllChildren()
	plop:Stop()
	for _, chime in ipairs(chimes) do
		chime:Stop()
	end
	lastPlop = -math.huge
end)
backdrop:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(drawAim)
RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	for source, view in pairs(eggViews) do
		local position = view.gel:render(source.Position, dt, now)
		local point = project(Vector2.new(position.X, position.Y))
		view.mark.Position = UDim2.fromOffset(point.X, point.Y)
	end
end)
layout()
updateHud()
