-- Join loading screen (v890 QA, Spencer 2026-11-17: "make all the world textures etc load
-- before the game loads"). Replaces Roblox's default screen, waits for the island to
-- replicate, then preloads every world mesh, texture and surface so the garden appears
-- whole instead of popping in. Never blocks for long: Skip shows after SkipAfter seconds and
-- the screen leaves on its own after MaxSeconds. Presentation only.
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")

local MaxSeconds, SkipAfter, WorldWait = 25, 10, 15
local started = os.clock()
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function node(class, parent, props)
	local o = Instance.new(class)
	for key, value in pairs(props or {}) do o[key] = value end
	o.Parent = parent
	return o
end
local display = Font.new("rbxasset://fonts/families/FredokaOne.json")
local body = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)

local gui = node("ScreenGui", nil, { Name = "EggDropLoading", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 1000,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
-- Dusk sky to match the island (WorldDusk): rose above, peach at the horizon.
local back = node("Frame", gui, { Name = "Back", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 })
node("UIGradient", back, { Rotation = 90, Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromHex("#F4A3BC")),
	ColorSequenceKeypoint.new(0.6, Color3.fromHex("#FFC2A6")),
	ColorSequenceKeypoint.new(1, Color3.fromHex("#FFE2B8")),
}) })
local column = node("Frame", back, { Name = "Column", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.8, 0.6), BackgroundTransparency = 1 })
node("UISizeConstraint", column, { MaxSize = Vector2.new(520, 320) })
node("UIListLayout", column, { FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder })

-- Three balls hopping in turn: the Pocket Deck's merge balls in their first three colours.
local hop = node("Frame", column, { Name = "Hop", LayoutOrder = 1, Size = UDim2.fromOffset(120, 44), BackgroundTransparency = 1 })
local balls = {}
for i, hex in ipairs({ "#7C9BFF", "#FFC14D", "#7BE495" }) do
	local ball = node("Frame", hop, { Name = "Ball" .. i, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0, 20 + (i - 1) * 40, 1, 0),
		Size = UDim2.fromOffset(26, 26), BackgroundColor3 = Color3.fromHex(hex), BorderSizePixel = 0 })
	node("UICorner", ball, { CornerRadius = UDim.new(0.5, 0) })
	node("UIStroke", ball, { Color = Color3.fromHex("#0E0F12"), Thickness = 2, Transparency = 0.55 })
	balls[i] = ball
end
node("TextLabel", column, { Name = "Title", LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 64), BackgroundTransparency = 1,
	Text = "Pocket Pals", FontFace = display, TextScaled = true, TextColor3 = Color3.fromHex("#FFFFFF") })
	:SetAttribute("Stroke", true)
node("UIStroke", column.Title, { Color = Color3.fromHex("#8A3F5C"), Thickness = 3, Transparency = 0.2 })
node("TextLabel", column, { Name = "Subtitle", LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1,
	Text = "Pet Garden", FontFace = body, TextScaled = true, TextColor3 = Color3.fromHex("#8A3F5C") })
local track = node("Frame", column, { Name = "Track", LayoutOrder = 4, Size = UDim2.new(0.8, 0, 0, 14),
	BackgroundColor3 = Color3.fromHex("#0E0F12"), BackgroundTransparency = 0.55, BorderSizePixel = 0 })
node("UICorner", track, { CornerRadius = UDim.new(0.5, 0) })
local fill = node("Frame", track, { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromHex("#76F6B0"), BorderSizePixel = 0 })
node("UICorner", fill, { CornerRadius = UDim.new(0.5, 0) })
local status = node("TextLabel", column, { Name = "Status", LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1,
	Text = "Waking the garden…", FontFace = body, TextScaled = true, TextColor3 = Color3.fromHex("#6B3049") })
local skip = node("TextButton", column, { Name = "Skip", LayoutOrder = 6, Size = UDim2.fromOffset(120, 36), Visible = false,
	BackgroundColor3 = Color3.fromHex("#0E0F12"), BackgroundTransparency = 0.35, BorderSizePixel = 0, AutoButtonColor = true,
	Text = "Skip", FontFace = body, TextSize = 18, TextColor3 = Color3.fromHex("#FFFFFF") })
node("UICorner", skip, { CornerRadius = UDim.new(0.5, 0) })
gui.Parent = playerGui
ReplicatedFirst:RemoveDefaultLoadingScreen()

local skipped = false
skip.Activated:Connect(function() skipped = true end)
local shown = 0
local hopConnection = RunService.RenderStepped:Connect(function()
	local now = os.clock() - started
	if not skip.Visible and now >= SkipAfter then skip.Visible = true end
	local reduced = GuiService.ReducedMotionEnabled
	for i, ball in ipairs(balls) do
		local t = (now * 1.6 - (i - 1) * 0.22) % 1
		local lift = if reduced then 0 else math.max(0, math.sin(t * math.pi * 2)) * 14
		ball.Position = UDim2.new(0, 20 + (i - 1) * 40, 1, -lift)
	end
end)
local function setProgress(value, text)
	value = math.clamp(value, 0, 1)
	if value > shown then
		shown = value
		TweenService:Create(fill, TweenInfo.new(0.2), { Size = UDim2.fromScale(value, 1) }):Play()
	end
	if text then status.Text = text end
end
local function overdue() return skipped or os.clock() - started >= MaxSeconds end

-- 1) The place's first replication, then the island the server builds at start.
if not game:IsLoaded() then game.Loaded:Wait() end
setProgress(0.1, "Building the island…")
local lounge, world
while not overdue() and os.clock() - started < WorldWait do
	lounge = workspace:FindFirstChild("EggDropLounge")
	world = lounge and lounge:FindFirstChild("World")
	local expected = world and world:GetAttribute("MeshParts")
	if world and (not expected or #world:GetChildren() >= expected) then break end
	task.wait(0.1)
end
setProgress(0.2, "Planting flowers…")

-- 2) Every mesh, texture and surface in the world (sounds stream on their own).
local wanted, seen = {}, {}
local function collect(root)
	if not root then return end
	for _, item in ipairs(root:GetDescendants()) do
		if item:IsA("MeshPart") or item:IsA("Decal") or item:IsA("Texture")
			or item:IsA("SpecialMesh") or item:IsA("ParticleEmitter") or item:IsA("Beam") then
			table.insert(wanted, item)
		elseif item:IsA("SurfaceAppearance") then
			-- Its maps as images: preloading the object asks for a texture pack these assets
			-- do not have ("No asset content representation found" in the console).
			for _, key in ipairs({ "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" }) do
				local ok, uri = pcall(function() return item[key] end)
				if ok and type(uri) == "string" and uri ~= "" and not seen[uri] then seen[uri] = true; table.insert(wanted, uri) end
			end
		end
	end
end
collect(workspace)
local total, done = #wanted, 0
local lines = { "Planting flowers…", "Fluffing the clouds…", "Filling the stream…", "Polishing the Pocket Decks…" }
if total > 0 and not overdue() then
	local finished = false
	task.spawn(function()
		pcall(ContentProvider.PreloadAsync, ContentProvider, wanted, function()
			done += 1
			setProgress(0.2 + 0.78 * done / total, lines[math.min(#lines, 1 + math.floor(done / total * #lines))])
		end)
		finished = true
	end)
	while not finished and not overdue() do task.wait(0.1) end
end
setProgress(1, if skipped then "Here we go!" else "Ready!")
-- On PlayerGui so QA can read it after the screen is gone.
playerGui:SetAttribute("LoadingPreloaded", done)
playerGui:SetAttribute("LoadingTotal", total)
playerGui:SetAttribute("LoadingSeconds", math.floor((os.clock() - started) * 10) / 10)
playerGui:SetAttribute("LoadingSkipped", skipped)

-- 3) Fade away.
task.wait(0.15)
local fade = TweenInfo.new(if GuiService.ReducedMotionEnabled then 0.01 else 0.45)
for _, item in ipairs(gui:GetDescendants()) do
	if item:IsA("Frame") or item:IsA("TextButton") then TweenService:Create(item, fade, { BackgroundTransparency = 1 }):Play() end
	if item:IsA("TextLabel") or item:IsA("TextButton") then TweenService:Create(item, fade, { TextTransparency = 1 }):Play() end
	if item:IsA("UIStroke") then TweenService:Create(item, fade, { Transparency = 1 }):Play() end
end
task.wait(fade.Time + 0.05)
hopConnection:Disconnect()
gui:Destroy()
