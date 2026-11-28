-- Join loading screen (v890 QA, Spencer 2026-11-17: "make all the world textures etc load
-- before the game loads"). Replaces Roblox's default screen, waits for the island to
-- replicate, then preloads every world mesh, texture and surface so the garden appears
-- whole instead of popping in. Never blocks for long: Skip shows after SkipAfter seconds and
-- the screen leaves on its own after MaxSeconds. Presentation only.
--
-- 2026-11-25 (Spencer: "Hatch a handheld pal ... add the checkerboard effect ... pets waving in
-- different colors and outfits"; layout by Fable): the title is "Hatch a Handheld Pal", the menu
-- shells' moving checker drifts over the dusk sky, and five pals (Blender renders of the game's
-- own Bear and Bunny in dyes and wardrobe pieces, scripts/render_loading_pals.py) wave in a row.
-- ReplicatedFirst runs before ReplicatedStorage replicates, so nothing here is required: the
-- checker constants are copied from DeckKit (Kit.Checker) and the strings live in Copy below
-- (scripts/export_localization_csv.py reads that table into the localization CSV).
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")

local MaxSeconds, SkipAfter, WorldWait, PalsFallback = 25, 10, 15, 3
local started = os.clock()
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Every player-facing string on this screen (Key = ui.loading.<name> in the localization CSV).
local Copy = {
	title = "Hatch a Handheld Pal",
	waking = "Waking your pals…",
	island = "Building the island…",
	flowers = "Planting flowers…",
	clouds = "Fluffing the clouds…",
	stream = "Filling the stream…",
	decks = "Polishing the Pocket Decks…",
	ready = "Ready!",
	go = "Here we go!",
	skip = "Skip",
}

-- The menu shells' moving checker (DeckKit Kit.Checker): one white-on-clear tile drifting down
-- and to the right, one tile every Period seconds. Stronger here (.82) than on the dark shells
-- (.91): the light sky swallows it otherwise.
local Checker = { image = "rbxassetid://71708936221007", period = 4, transparency = 0.82 }
-- The pals sheet (assets/ui/loading/loading-pals.png): 1024x512, 204x256 cells, column = pal (left to
-- right), row 0 = wave "out", row 1 = "in". A hatless Bear's feet-to-ear-tip height is `bear` of a cell's
-- height and its feet sit `feet` of it above the cell's bottom edge (render_loading_pals.py prints both).
local Sheet = { image = "rbxassetid://71645230987767", w = 204, h = 256, bear = 0.726, feet = 10 / 256 }
local PalCount, CentreScale = 5, 1.12
-- Wave: swap frames every Swap s for Swaps swaps (in, out, ... ending on "out"), then that last "out"
-- runs on for Hold s more (0.7 s in all); pal i starts Stagger s after pal i - 1.
local Swap, Swaps, Hold, Stagger = 0.26, 6, 0.44, 0.18
local BobPeriod, BobPixels = 1.3, 4

local function node(class, parent, props)
	local o = Instance.new(class)
	for key, value in pairs(props or {}) do o[key] = value end
	o.Parent = parent
	return o
end
local display = Font.new("rbxasset://fonts/families/FredokaOne.json")
local body = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local ink = Color3.fromHex("#8A3F5C")

local gui = node("ScreenGui", nil, { Name = "EggDropLoading", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 1000,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
-- Dusk sky to match the island (WorldDusk): rose above, peach at the horizon.
local sky = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromHex("#F4A3BC")),
	ColorSequenceKeypoint.new(0.6, Color3.fromHex("#FFC2A6")),
	ColorSequenceKeypoint.new(1, Color3.fromHex("#FFE2B8")),
})
local back = node("Frame", gui, { Name = "Back", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 })
node("UIGradient", back, { Rotation = 90, Color = sky })

-- The checker: a tiled image one tile bigger than the screen, slid by one tile and looped. A
-- static sky-coloured veil above it (as DeckKit's shell fade) takes it from full strength at the
-- top to 35% at the bottom without moving with the tiles.
local clip = node("Frame", back, { Name = "CheckerClip", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true })
local checker = node("ImageLabel", clip, { Name = "Checker", BackgroundTransparency = 1, Image = Checker.image,
	ImageTransparency = Checker.transparency, ScaleType = Enum.ScaleType.Tile })
local veil = node("Frame", back, { Name = "CheckerFade", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 })
node("UIGradient", veil, { Rotation = 90, Color = sky, Transparency = NumberSequence.new(1, 0.35) })

local column = node("Frame", back, { Name = "Column", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	BackgroundTransparency = 1 })
local columnList = node("UIListLayout", column, { FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder })
local title = node("TextLabel", column, { Name = "Title", LayoutOrder = 1, BackgroundTransparency = 1,
	Text = Copy.title, FontFace = display, TextScaled = true, TextColor3 = Color3.fromHex("#FFFFFF") })
local titleSize = node("UITextSizeConstraint", title)
local titleStroke = node("UIStroke", title, { Color = ink, Thickness = 3, Transparency = 0.2 })

-- Five pals on one baseline, the centre one a little bigger and drawn on top, each over a soft
-- 2D shadow that stays put while the pal bobs. They show once the sheet has loaded.
local row = node("Frame", column, { Name = "Pals", LayoutOrder = 2, BackgroundTransparency = 1 })
local pals = {}
for i = 1, PalCount do
	local depth = PalCount - math.abs(i - (PalCount + 1) / 2) * 2 -- centre 5, then 3, then 1
	local shadow = node("Frame", row, { Name = "Shadow" .. i, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = ink,
		BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 1 })
	node("UICorner", shadow, { CornerRadius = UDim.new(0.5, 0) })
	local sprite = node("ImageLabel", row, { Name = "Pal" .. i, AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1,
		Image = Sheet.image, ImageRectSize = Vector2.new(Sheet.w, Sheet.h),
		ImageRectOffset = Vector2.new((i - 1) * Sheet.w, 0), ImageTransparency = 1, ZIndex = depth + 1 })
	pals[i] = { sprite = sprite, shadow = shadow, x = 0, height = 0, frame = 0 }
end

local track = node("Frame", column, { Name = "Track", LayoutOrder = 3, BackgroundColor3 = Color3.fromHex("#0E0F12"),
	BackgroundTransparency = 0.55, BorderSizePixel = 0 })
node("UICorner", track, { CornerRadius = UDim.new(0.5, 0) })
local fill = node("Frame", track, { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromHex("#76F6B0"), BorderSizePixel = 0 })
node("UICorner", fill, { CornerRadius = UDim.new(0.5, 0) })
local status = node("TextLabel", column, { Name = "Status", LayoutOrder = 4, BackgroundTransparency = 1,
	Text = Copy.waking, FontFace = body, TextScaled = true, TextColor3 = Color3.fromHex("#6B3049") })
-- Skip sits in the bottom-right corner, clear of a phone's rounded corner and home bar, so
-- nothing in the column moves when it appears.
local skip = node("TextButton", back, { Name = "Skip", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -48, 1, -24),
	Size = UDim2.fromOffset(120, 36), Visible = false, BackgroundColor3 = Color3.fromHex("#0E0F12"), BackgroundTransparency = 0.35,
	BorderSizePixel = 0, AutoButtonColor = true, Text = Copy.skip, FontFace = body, TextSize = 18, TextColor3 = Color3.fromHex("#FFFFFF") })
node("UICorner", skip, { CornerRadius = UDim.new(0.5, 0) })

-- Sizes follow the screen height: a landscape phone (390 px) to 720p to 1080p and up.
local function by(height, phone, hd, full)
	if height <= 720 then
		local t = math.clamp((height - 390) / 330, 0, 1)
		return phone + (hd - phone) * t
	end
	return hd + (full - hd) * math.clamp((height - 720) / 360, 0, 1)
end
local reduced = GuiService.ReducedMotionEnabled
local checkerTween, tile = nil, 0
local function startChecker()
	if checkerTween then checkerTween:Cancel() end
	checker.Size = UDim2.new(1, tile, 1, tile)
	checker.TileSize = UDim2.fromOffset(tile, tile)
	checker.Position = UDim2.fromOffset(-tile, -tile)
	checkerTween = nil
	if reduced then return end
	checkerTween = TweenService:Create(checker, TweenInfo.new(Checker.period, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
		{ Position = UDim2.fromOffset(0, 0) })
	checkerTween:Play()
end
local function layout()
	local size = gui.AbsoluteSize
	if size.Y <= 1 then
		local camera = workspace.CurrentCamera
		size = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	end
	if size.Y <= 1 then size = Vector2.new(1280, 720) end
	local h = size.Y
	-- Fable: a Bear stands 112 px on a phone, 168 at 720p, 215 at 1080p; the centre pal is 12% bigger.
	local cellHeight = by(h, 112, 168, 215) / Sheet.bear
	local cellWidth = cellHeight * Sheet.w / Sheet.h
	local step = math.floor(cellWidth * 0.7) -- shoulder to shoulder
	local titleHeight = math.floor(by(h, 46, 84, 96))
	local gap = math.floor(by(h, 8, 10, 10))
	local rowHeight = math.floor(cellHeight * CentreScale)
	local width = math.floor(math.min(size.X * 0.92, 1000))
	columnList.Padding = UDim.new(0, gap)
	title.Size = UDim2.fromOffset(width, titleHeight)
	titleSize.MaxTextSize = titleHeight
	titleStroke.Thickness = if h < 600 then 3 else 4
	row.Size = UDim2.fromOffset(math.min(width, math.ceil(4 * step + cellWidth * CentreScale)), rowHeight)
	for i, pal in ipairs(pals) do
		local scale = if i == (PalCount + 1) / 2 then CentreScale else 1
		pal.height = cellHeight * scale
		pal.x = (i - (PalCount + 1) / 2) * step
		pal.sprite.Size = UDim2.fromOffset(math.floor(cellWidth * scale), math.floor(pal.height))
		pal.sprite.Position = UDim2.new(0.5, pal.x, 1, 0)
		-- An oval half the pal's width under its feet (Fable's review: neighbours never merge).
		pal.shadow.Size = UDim2.fromOffset(math.floor(cellWidth * scale * 0.34), math.max(6, math.floor(pal.height * 0.06)))
		pal.shadow.Position = UDim2.new(0.5, pal.x, 1, -math.floor(pal.height * Sheet.feet))
	end
	local barWidth = math.floor(by(h, 300, 420, 420))
	track.Size = UDim2.fromOffset(math.min(barWidth, width), 14)
	local statusHeight = math.floor(by(h, 18, 22, 24))
	status.Size = UDim2.fromOffset(width, statusHeight)
	column.Size = UDim2.fromOffset(width, titleHeight + rowHeight + 14 + statusHeight + 3 * gap)
	local newTile = math.floor(by(h, 32, 40, 48))
	if newTile ~= tile then
		tile = newTile
		startChecker()
	end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
layout()
gui.Parent = playerGui
ReplicatedFirst:RemoveDefaultLoadingScreen()
layout()

local skipped, leaving, palsShown = false, false, false
skip.Activated:Connect(function() skipped = true end)
local function showPals()
	if palsShown or leaving then return end
	palsShown = true
	playerGui:SetAttribute("LoadingPalsAt", math.floor((os.clock() - started) * 10) / 10)
	local info = TweenInfo.new(if reduced then 0.01 else 0.25)
	for _, pal in ipairs(pals) do
		TweenService:Create(pal.sprite, info, { ImageTransparency = 0 }):Play()
		TweenService:Create(pal.shadow, info, { BackgroundTransparency = 0.8 }):Play()
	end
end
-- The sheet goes to the head of the download queue; the pals show when it lands, or anyway after
-- PalsFallback seconds (an image still in moderation loads blank, so this never waits on it).
task.spawn(function()
	pcall(ContentProvider.PreloadAsync, ContentProvider, { pals[1].sprite, checker })
	showPals()
end)
task.delay(PalsFallback, showPals)

local shown = 0
local cycle = Swap * Swaps + Hold
local hopConnection = RunService.RenderStepped:Connect(function()
	local now = os.clock() - started
	if not leaving and not skip.Visible and now >= SkipAfter then skip.Visible = true end
	local still = GuiService.ReducedMotionEnabled
	if still ~= reduced then
		reduced = still
		startChecker()
	end
	for i, pal in ipairs(pals) do
		local frame, lift = 0, 0
		if not still then
			local phase = (now - (i - 1) * Stagger) % cycle
			if phase < Swap * Swaps then frame = 1 - math.floor(phase / Swap) % 2 end
			lift = (math.sin((now / BobPeriod + i * 0.17) * math.pi * 2) * 0.5 + 0.5) * BobPixels * pal.height / 230
		end
		if frame ~= pal.frame then
			pal.frame = frame
			pal.sprite.ImageRectOffset = Vector2.new((i - 1) * Sheet.w, frame * Sheet.h)
		end
		pal.sprite.Position = UDim2.new(0.5, pal.x, 1, -math.floor(lift + 0.5))
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
setProgress(0.1, Copy.island)
local lounge, world
while not overdue() and os.clock() - started < WorldWait do
	lounge = workspace:FindFirstChild("EggDropLounge")
	world = lounge and lounge:FindFirstChild("World")
	local expected = world and world:GetAttribute("MeshParts")
	if world and (not expected or #world:GetChildren() >= expected) then break end
	task.wait(0.1)
end
setProgress(0.2, Copy.flowers)

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
local lines = { Copy.flowers, Copy.clouds, Copy.stream, Copy.decks }
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
setProgress(1, if skipped then Copy.go else Copy.ready)
-- On PlayerGui so QA can read it after the screen is gone.
playerGui:SetAttribute("LoadingPreloaded", done)
playerGui:SetAttribute("LoadingTotal", total)
playerGui:SetAttribute("LoadingSeconds", math.floor((os.clock() - started) * 10) / 10)
playerGui:SetAttribute("LoadingSkipped", skipped)

-- 3) DECK-FEEL-BRIEF 1 (Alive deckfeel, read from its workspace attribute: nothing here can require Shared): when the
-- client's first presentation is the Pocket Deck, keep the sky up until the deck's content is ready, then cross-fade
-- the sky to the deck's shade colour (.30 s, Sine InOut) while the pals, title and bar fade (.20 s), and hand straight
-- to the handheld's rise (DeckHandoff's PlayerGui attributes). The garden never shows in between; no frame is fully
-- transparent. Reduced Motion, the switch off, a garden start or a client that never says: the fade below, as before.
leaving = true
local HandoffWait = 12
local handoff = workspace:GetAttribute("Alive_deckfeel") == true and not GuiService.ReducedMotionEnabled
if handoff then
	local asked = os.clock()
	while playerGui:GetAttribute("DeckFirstRoute") == nil and os.clock() - asked < HandoffWait do task.wait(0.05) end
	handoff = playerGui:GetAttribute("DeckFirstRoute") == "Board" and playerGui:GetAttribute("DeckFeelHandoff") == true
end
if handoff then
	local asked = os.clock()
	while playerGui:GetAttribute("DeckContentReady") ~= true and os.clock() - asked < HandoffWait do task.wait(0.05) end
	local shade = playerGui:GetAttribute("DeckShadeColor")
	if typeof(shade) ~= "Color3" then shade = Color3.fromHex("#2B2F3A") end
	local cover = node("Frame", gui, { Name = "ShadeHandoff", Size = UDim2.fromScale(1, 1), BackgroundColor3 = shade,
		BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 50 })
	local palFade = TweenInfo.new(0.20)
	for _, item in ipairs(column:GetDescendants()) do
		if item:IsA("Frame") then TweenService:Create(item, palFade, { BackgroundTransparency = 1 }):Play() end
		if item:IsA("TextLabel") then TweenService:Create(item, palFade, { TextTransparency = 1 }):Play() end
		if item:IsA("ImageLabel") then TweenService:Create(item, palFade, { ImageTransparency = 1 }):Play() end
		if item:IsA("UIStroke") then TweenService:Create(item, palFade, { Transparency = 1 }):Play() end
	end
	skip.Visible = false
	TweenService:Create(cover, TweenInfo.new(0.30, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { BackgroundTransparency = 0 }):Play()
	task.wait(0.32)
	playerGui:SetAttribute("LoadingHandedOff", true)
	hopConnection:Disconnect()
	if checkerTween then checkerTween:Cancel() end
	gui:Destroy()
	return
end
task.wait(0.15)
local fade = TweenInfo.new(if GuiService.ReducedMotionEnabled then 0.01 else 0.45)
for _, item in ipairs(gui:GetDescendants()) do
	if item:IsA("Frame") or item:IsA("TextButton") then TweenService:Create(item, fade, { BackgroundTransparency = 1 }):Play() end
	if item:IsA("TextLabel") or item:IsA("TextButton") then TweenService:Create(item, fade, { TextTransparency = 1 }):Play() end
	if item:IsA("ImageLabel") then TweenService:Create(item, fade, { ImageTransparency = 1 }):Play() end
	if item:IsA("UIStroke") then TweenService:Create(item, fade, { Transparency = 1 }):Play() end
end
task.wait(fade.Time + 0.05)
hopConnection:Disconnect()
if checkerTween then checkerTween:Cancel() end
gui:Destroy()
