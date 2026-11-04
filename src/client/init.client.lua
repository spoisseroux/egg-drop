local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage.Shared.BoardConfig)
local Pets = require(ReplicatedStorage.Shared.PetCatalog)
local Palette = require(ReplicatedStorage.Shared.DeckPalette)
local Themes = require(ReplicatedStorage.Shared.DeckThemes)
local Stickers = require(ReplicatedStorage.Shared.DeckStickers)
local Jelly = require(script.JellyVisual)
local Sprite = require(script.JellySprite)
local Audio = require(script.BoardAudio)
local DeckPicker = require(script.DeckPicker)
local RoomView = require(script.RoomView)
local HandheldScreens = require(script.HandheldScreens)
local HatchReveal = require(script.HatchReveal)
local audio = Audio.new()
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local request = remotes:WaitForChild("BoardRequest")
local feedback = remotes:WaitForChild("BoardMerge")
local impacts = remotes:WaitForChild("BoardImpact")
local trays = ReplicatedStorage:WaitForChild("EggDropBoards")
local board = trays:WaitForChild(tostring(player.UserId))
HandheldScreens.start(trays, Config)

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
		Text = content, Font = Enum.Font.GothamMedium, TextSize = 15,
		TextColor3 = if background then Palette.Ink else Palette.Paper,
		BackgroundColor3 = background or Palette.Panel, BackgroundTransparency = background and 0 or 1,
		BorderSizePixel = 0,
	}, parent)
end

local gui = make("ScreenGui", "EggDrop", {
	ResetOnSpawn = false, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, DisplayOrder = 10,
}, player:WaitForChild("PlayerGui"))
local backdrop = make("Frame", "Backdrop", {
	BackgroundColor3 = Palette.Backdrop, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
}, gui)
local shell = make("Frame", "CartridgeShell", {
	BackgroundColor3 = Palette.Shell, BorderSizePixel = 0,
}, backdrop)
make("UICorner", "ShellCurve", { CornerRadius = UDim.new(0, 18) }, shell)
local rim = make("UIStroke", "ShellRim", { Color = Palette.Rim, Thickness = 2 }, shell)
local bezel = make("Frame", "LCDBezel", { BackgroundColor3 = Palette.Ink, BorderSizePixel = 0 }, backdrop)
make("UICorner", "LensCurve", { CornerRadius = UDim.new(0, 12) }, bezel)
local bezelRim = make("UIStroke", "InsetTrim", { Color = Palette.Rim, Thickness = 2 }, bezel)
-- A viewport renders the board inside the HUD, using the same projection on desktop and phone.
local viewport = make("ViewportFrame", "Tray", {
	BackgroundColor3 = Color3.fromHex("#222A24"), BorderSizePixel = 0,
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
	BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4,
}, overlay)
local sprites = make("Frame", "Sprites", {
	BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3,
}, overlay)

local function surface(name, size, transform, color)
	return make("Part", name, {
		Anchored = true, Size = size, CFrame = transform, Color = color, Material = Enum.Material.SmoothPlastic,
	}, scene)
end

local halfWidth = Config.Width / 2
local railDepth = 0.65
surface("Floor", Vector3.new(Config.Width + 0.5, 0.32, railDepth), CFrame.new(0, -0.16, 0), Palette.Rim)
for _, sign in ipairs({ -1, 1 }) do
	surface("Wall", Vector3.new(0.32, Config.Height, railDepth),
		CFrame.new(sign * (halfWidth + 0.16), Config.Height / 2, 0), Palette.Rim)
	surface("Bank", Vector3.new(Config.Bank * math.sqrt(2), 0.31, railDepth),
		CFrame.new(sign * (halfWidth - Config.Bank / 2), Config.Bank / 2, 0)
			* CFrame.Angles(0, 0, sign * math.pi / 4), Palette.Rim)
end

local title = label("TextLabel", "Title", "POCKET DECK", backdrop)
title.Font = Enum.Font.Code
title.TextSize = 20
local power = make("Frame", "PowerLight", {
	Position = UDim2.new(1, -20, 0, 13), Size = UDim2.fromOffset(8, 8),
	BackgroundColor3 = Palette.Lime, BorderSizePixel = 0,
}, shell)
make("UICorner", "Round", { CornerRadius = UDim.new(0.5, 0) }, power)
local deckSticker = label("TextLabel", "DeckSticker", "", backdrop, Palette.Primary)
deckSticker.Size = UDim2.fromOffset(24, 24)
deckSticker.Rotation = -11
make("UICorner", "StickerCurve", { CornerRadius = UDim.new(0, 5) }, deckSticker)
local rail = label("TextButton", "AimRail", "", backdrop, Palette.Ink)
rail.AutoButtonColor = false
rail.Font = Enum.Font.Code
rail.TextColor3 = Palette.Paper
rail.Selectable = false
make("UICorner", "RailCurve", { CornerRadius = UDim.new(0, 9) }, rail)
local track = make("Frame", "Guide", {
	BackgroundColor3 = Palette.Primary, BackgroundTransparency = 0.45, BorderSizePixel = 0,
	Size = UDim2.new(0, 2, 1, 0), ZIndex = 3,
}, overlay)
local ghost = label("TextLabel", "NextEgg", "", overlay, Palette.Primary)
ghost.AnchorPoint = Vector2.new(0.5, 0.5)
ghost.ZIndex = 4
make("UICorner", "Round", { CornerRadius = UDim.new(0.5, 0) }, ghost)

local status = label("TextLabel", "Status", "", backdrop)
status.TextWrapped = true
local meter = make("Frame", "HatchTrack", {
	BackgroundColor3 = Palette.Ink, BorderSizePixel = 0,
}, backdrop)
local fill = make("Frame", "Charge", {
	BackgroundColor3 = Palette.Amber, BorderSizePixel = 0,
}, meter)
local meterText = label("TextLabel", "MeterText", "", meter)
meterText.Font = Enum.Font.Code
meterText.Size = UDim2.fromScale(1, 1)
meterText.TextSize = 13
meterText.TextColor3 = Palette.Paper
meterText.TextStrokeColor3 = Palette.Ink
meterText.TextStrokeTransparency = 0
local overflowLine = make("Frame", "OverflowLine", {
	BackgroundColor3 = Palette.Amber, BackgroundTransparency = 0.45,
	BorderSizePixel = 0, ZIndex = 2,
}, overlay)
local targetRing = make("Frame", "MatchHint", {
	AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false, ZIndex = 4,
}, overlay)
make("UICorner", "Round", { CornerRadius = UDim.new(0.5, 0) }, targetRing)
make("UIStroke", "Outline", { Color = Palette.Amber, Thickness = 2, Transparency = 0.25 }, targetRing)
local customizeButton = label("TextButton", "Customize", "Customize", backdrop, Palette.Primary)
local roomButton = label("TextButton", "VisitRoom", "Lounge", backdrop, Palette.Panel)
local reset = label("TextButton", "Reset", "Retry", backdrop, Palette.Panel)
for _, button in ipairs({ customizeButton, roomButton, reset }) do
	make("UICorner", "ButtonCurve", { CornerRadius = UDim.new(0, 8) }, button)
end
local hardware = make("Frame", "DeckControls", { BackgroundTransparency = 1 }, backdrop)
local function hardwareButton(name, text, parent, color, width)
	local button = label("TextButton", name, text, parent, color)
	button.Size = UDim2.fromOffset(width, width)
	button.Font = Enum.Font.Code
	button.TextSize = 24
	make("UICorner", "Cap", { CornerRadius = UDim.new(0, if width == 44 then 7 else 24) }, button)
	return button
end
local dpad = make("Frame", "DPad", {
	Size = UDim2.fromOffset(88, 62), BackgroundTransparency = 1,
}, hardware)
local stem = make("Frame", "Stem", {
	Size = UDim2.fromOffset(30, 60), Position = UDim2.fromOffset(29, 0),
	BackgroundColor3 = Palette.Ink, BorderSizePixel = 0,
}, dpad)
make("UICorner", "StemCurve", { CornerRadius = UDim.new(0, 6) }, stem)
local leftAim = hardwareButton("Left", "‹", dpad, Palette.Ink, 44)
local rightAim = hardwareButton("Right", "›", dpad, Palette.Ink, 44)
leftAim.Position, rightAim.Position = UDim2.fromOffset(0, 8), UDim2.fromOffset(44, 8)
leftAim.TextColor3, rightAim.TextColor3 = Palette.Paper, Palette.Paper
local action = hardwareButton("Drop", "A", hardware, Palette.Primary, 48)
local centerAim = hardwareButton("Center", "B", hardware, Palette.Primary, 48)
local dropCaption = label("TextLabel", "DropCaption", "DROP", hardware)
local centerCaption = label("TextLabel", "CenterCaption", "CENTER", hardware)
for _, caption in ipairs({ dropCaption, centerCaption }) do
	caption.Size = UDim2.fromOffset(48, 16)
	caption.Font = Enum.Font.Code
	caption.TextSize = 11
end
local vents = make("Frame", "Speaker", { Size = UDim2.fromOffset(31, 26), BackgroundTransparency = 1 }, hardware)
for index = 0, 3 do
	local slot = make("Frame", "Vent", {
		Size = UDim2.fromOffset(4, 23), Position = UDim2.fromOffset(index * 8, 2),
		Rotation = 16, BorderSizePixel = 0, BackgroundColor3 = Palette.Ink,
	}, vents)
	make("UICorner", "Round", { CornerRadius = UDim.new(1, 0) }, slot)
end
local openPicker
local picker
local function isPickerOpen()
	return picker.shade.Visible
end
local roomView = RoomView.new(gui, backdrop, board, audio, function()
	request:FireServer("mode", "Board")
end, function()
	openPicker()
end, isPickerOpen)
roomButton.Activated:Connect(function()
	if not isPickerOpen() then
		request:FireServer("mode", "Room")
	end
end)
local modal = make("Frame", "RoundCard", {
	Active = true, Visible = false, BackgroundColor3 = Palette.Paper, BorderSizePixel = 0, ZIndex = 10,
	AnchorPoint = Vector2.new(0.5, 0.5),
}, backdrop)
make("UICorner", "CardCurve", { CornerRadius = UDim.new(0, 18) }, modal)
make("UIStroke", "CardRim", { Color = Palette.Primary, Thickness = 3 }, modal)
local modalTitle = label("TextLabel", "Heading", "", modal)
modalTitle.Position = UDim2.fromOffset(0, 6)
modalTitle.Size = UDim2.new(1, 0, 0, 35)
modalTitle.Font = Enum.Font.GothamBold
modalTitle.TextSize = 20
modalTitle.TextColor3 = Palette.Ink
modalTitle.ZIndex = 11
local pet = label("TextButton", "Pet", "▪ ᴗ ▪", modal, Color3.fromRGB(255, 224, 170))
pet.AnchorPoint = Vector2.new(0.5, 0)
pet.Position = UDim2.new(0.5, 0, 0, 63)
pet.Size = UDim2.fromOffset(72, 67)
pet.TextSize = 18
pet.ZIndex = 14
pet.AutoButtonColor = false
make("UICorner", "Shell", { CornerRadius = UDim.new(0.45, 0) }, pet)
make("UIStroke", "Outline", { Color = Palette.Rim, Thickness = 2 }, pet)
local pipLeaves = {}
for _, side in ipairs({ -1, 1 }) do
	local leaf = make("Frame", "Leaf", {
		BackgroundColor3 = Palette.Lime, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, side * 7, 0, -1),
		Size = UDim2.fromOffset(17, 9), Rotation = -side * 32, ZIndex = 15,
	}, pet)
	make("UICorner", "Round", { CornerRadius = UDim.new(0.5, 0) }, leaf)
	table.insert(pipLeaves, leaf)
end
local shellHem = make("Frame", "ShellHem", {
	BackgroundColor3 = Palette.Shell, BorderSizePixel = 0, Position = UDim2.fromScale(0.10, 0.77),
	Size = UDim2.fromScale(0.80, 0.22), ZIndex = 15,
}, pet)
make("UICorner", "Round", { CornerRadius = UDim.new(0.5, 0) }, shellHem)
local puddleTail = make("Frame", "DropletTail", {
	BackgroundColor3 = Palette.JellyBlue, BorderSizePixel = 0,
	Position = UDim2.new(1, -10, 0, -6), Size = UDim2.fromOffset(17, 26), Rotation = 28,
	Visible = false, ZIndex = 15,
}, pet)
make("UICorner", "Round", { CornerRadius = UDim.new(0.5, 0) }, puddleTail)
local reveal = HatchReveal.new(modal, pet, audio)
local modalNote = label("TextLabel", "Detail", "", modal)
modalNote.Position = UDim2.new(0.06, 0, 0, 57)
modalNote.Size = UDim2.new(0.88, 0, 0, 66)
modalNote.TextWrapped = true
modalNote.TextColor3 = Palette.Ink
modalNote.ZIndex = 11
local modalAction = label("TextButton", "Continue", "", modal, Palette.Primary)
modalAction.Position = UDim2.new(0.09, 0, 1, -55)
modalAction.Size = UDim2.new(0.82, 0, 0, 44)
modalAction.ZIndex = 11
local keepPlaying = label("TextButton", "KeepPlaying", "Keep playing", modal, Palette.Panel)
keepPlaying.Position = UDim2.new(0.52, 0, 1, -55)
keepPlaying.Size = UDim2.new(0.43, 0, 0, 44)
keepPlaying.ZIndex = 11
for _, button in ipairs({ modalAction, keepPlaying }) do
	make("UICorner", "ButtonCurve", { CornerRadius = UDim.new(0, 9) }, button)
end
local dismissedHatch
local revealedPet
local lastPlop = -math.huge

local aim = 0.5
local drag
local heldAim = {}
local eggViews = {}
local viewsById = {}

local function clearPlayInputs()
	drag = nil
	table.clear(heldAim)
end

local function equippedAppearance()
	return board:GetAttribute("DeckThemeId") or Themes.Default,
		board:GetAttribute("DeckStickerId") or Stickers.Default
end

local function paintDeck(id, stickerId)
	local theme = Themes.ById[id]
	shell.BackgroundColor3 = theme.shell
	rim.Color = theme.trim
	bezelRim.Color = theme.trim
	customizeButton.BackgroundColor3 = theme.buttons
	action.BackgroundColor3 = theme.buttons
	centerAim.BackgroundColor3 = theme.buttons
	Stickers.paint(deckSticker, stickerId)
end

local function canAim()
	return board:GetAttribute("Mode") == "Board" and not modal.Visible
end

local function isGamepad(inputType)
	return string.match(inputType.Name, "^Gamepad") ~= nil
end

picker = DeckPicker.new(gui, make, label, paintDeck, function()
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(picker.shade) then
		local controls = gui.LoungeControls
		GuiService.SelectedObject = if board:GetAttribute("Mode") == "Room" and controls.Visible
			then controls.OpenHandheld else nil
	end
	paintDeck(equippedAppearance())
	rail.Interactable = canAim()
end, function(themeId, stickerId)
	request:FireServer("appearance", themeId, stickerId)
	audio:play("menu")
end)

openPicker = function()
	if isPickerOpen() or roomView.busy or (board:GetAttribute("Mode") == "Board" and modal.Visible) then
		return
	end
	clearPlayInputs()
	rail.Interactable = false
	picker:open(equippedAppearance())
	if isGamepad(UserInputService:GetLastInputType()) then
		GuiService.SelectedObject = picker.tabs.Shell
	end
	audio:play("menu")
end
customizeButton.Activated:Connect(openPicker)
local function repaintEquipped()
	task.defer(function()
		if not isPickerOpen() then
			paintDeck(equippedAppearance())
		end
	end)
end
board:GetAttributeChangedSignal("DeckThemeId"):Connect(repaintEquipped)
board:GetAttributeChangedSignal("DeckStickerId"):Connect(repaintEquipped)
paintDeck(equippedAppearance())

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
	rail.Text = "EGG DROP  ·  " .. Config.Tiers[tier].mark
	local overflow = project(Vector2.new(0, Config.OverflowY))
	overflowLine.Position = UDim2.fromOffset(scale * 0.4, overflow.Y)
	overflowLine.Size = UDim2.fromOffset(scale * Config.Width, 2)
end

local function updateHud()
	local drops = board:GetAttribute("Drops") or 0
	local merges = board:GetAttribute("Merges") or 0
	local chain = board:GetAttribute("Chain") or 0
	local charge = board:GetAttribute("HatchCharge") or 0
	local owned = board:GetAttribute("OwnedPets") or 0
	local nextPet = Pets[owned + 1]
	local hatchName = board:GetAttribute("HatchedPet")
	local hatchPet = Pets[owned]
	fill.Size = UDim2.fromScale(if nextPet then charge / nextPet.charge else 1, 1)
	if drops == 0 and board:GetAttribute("ProfileLoadFailed") then
		status.Text = "Save could not load. Playing a fresh tray."
	elseif owned > 0 then
		status.Text = string.format("%d merges   ·   Chain ×%d", merges, chain)
	elseif drops == 0 then
		status.Text = "Aim with ◀ ▶ or drag the screen bar."
	elseif merges == 0 then
		status.Text = "Match eggs with the same mark."
	else
		status.Text = "Keep matching to hatch Pip!"
	end
	meterText.Text = if nextPet then string.format("%s   %d / %d", nextPet.name, charge, nextPet.charge)
		else string.format("Collection   %d / %d", owned, #Pets)
	local mode = board:GetAttribute("Mode")
	local showHatch = hatchPet ~= nil and hatchName == hatchPet.name and hatchName ~= dismissedHatch and mode == "Board"
	local over = board:GetAttribute("RoundOver") and not showHatch
	local wasVisible = modal.Visible
	modal.Visible = mode == "Board" and (over == true or showHatch)
	if modal.Visible then
		clearPlayInputs()
		picker:close()
	end
	pet.Visible = showHatch == true and not over
	modalNote.Visible = over == true
	modalNote.Text = "Try to keep the eggs below the amber line."
	modalTitle.Text = if over then "Tray full" else "You hatched " .. (hatchName or "") .. "!"
	modalAction.Text = if over then "Try again" else "Meet " .. (hatchName or "")
	modalAction.Position = UDim2.new(if over then 0.09 else 0.05, 0, 1, -55)
	modalAction.Size = UDim2.new(if over then 0.82 else 0.43, 0, 0, 44)
	keepPlaying.Visible = not over
	if modal.Visible and not wasVisible and isGamepad(UserInputService:GetLastInputType()) then
		GuiService.SelectedObject = modalAction
	elseif not modal.Visible and GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(modal) then
		GuiService.SelectedObject = nil
	end
	rail.Interactable = canAim() and not isPickerOpen()
	local unlocked = owned > 0
	roomButton.Interactable = unlocked
	roomButton.BackgroundColor3 = if unlocked then Palette.Primary else Palette.Panel
	roomButton.TextTransparency = if unlocked then 0 else 0.28
	drawAim()
	if showHatch and not over and revealedPet ~= hatchName then
		revealedPet = hatchName
		local puddle = hatchName == "Puddle"
		pet.BackgroundColor3 = if puddle then Palette.JellyBlue else Color3.fromRGB(255, 224, 170)
		pet.Size = if puddle then UDim2.fromOffset(84, 50) else UDim2.fromOffset(72, 67)
		pet.Position = UDim2.new(0.5, 0, 0, if puddle then 75 else 63)
		puddleTail.Visible = puddle
		shellHem.Visible = not puddle
		for _, leaf in ipairs(pipLeaves) do
			leaf.Visible = not puddle
		end
		local resetId = board:GetAttribute("ResetId")
		reveal:start(function()
			return board:GetAttribute("ResetId") == resetId and board:GetAttribute("Mode") == "Board"
				and dismissedHatch ~= hatchName
				and board:GetAttribute("HatchedPet") == hatchName
		end, hatchPet.cue, if puddle then Palette.JellyBlue else Palette.Amber)
	end
end

local function layout()
	local screen = backdrop.AbsoluteSize
	local lateral = screen.Y < 530 and screen.X > screen.Y * 1.25
	local ratio = (Config.Width + 0.8) / (Config.Height + 0.8)
	local reserved = if lateral then 122 else 256
	local grip = 132
	local widthBudget = screen.X - (if lateral then grip * 2 + 56 else 48)
	local width = math.max(1, math.min(415, widthBudget, (screen.Y - reserved) * ratio))
	local height = width / ratio
	local totalWidth = if lateral then width + grip * 2 + 24 else math.min(screen.X - 32, math.max(width + 14, 228))
	local left = (screen.X - totalWidth) / 2
	local shellHeight = if lateral then math.max(236, height + 104) else height + 240
	local top = math.max(5, (screen.Y - shellHeight) / 2)
	local screenX = (screen.X - width) / 2
	local trayY = top + 70
	local trayBottom = trayY + height
	shell.Position = UDim2.fromOffset(left - 8, top)
	shell.Size = UDim2.fromOffset(totalWidth + 16, shellHeight)
	bezel.Position = UDim2.fromOffset(screenX - 5, top + 24)
	bezel.Size = UDim2.fromOffset(width + 10, height + (if lateral then 75 else 94))
	viewport.Position = UDim2.fromOffset(screenX, trayY)
	viewport.Size = UDim2.fromOffset(width, height)
	overlay.Position = viewport.Position
	overlay.Size = viewport.Size
	modal.Position = UDim2.fromScale(0.5, 0.49)
	modal.Size = UDim2.fromOffset(math.min(math.max(width * 0.9, 246), screen.X - 24), 209)
	title.Position = UDim2.fromOffset(left, top + 1)
	title.Size = UDim2.fromOffset(totalWidth, 23)
	deckSticker.Position = UDim2.fromOffset(left + (if lateral then 52 else totalWidth * 0.47 - 12),
		if lateral then top + 154 else trayBottom + 67)
	rail.Position = UDim2.fromOffset(screenX, top + 26)
	rail.Size = UDim2.fromOffset(width, 44)
	rail.TextSize = if width < 160 then 11 else 14
	local menuX = if lateral then left + grip + width + 24 else left
	local menuY = if lateral then top + 84 else trayBottom + 120
	status.Position = UDim2.fromOffset(left, if lateral then top + 37 else trayBottom + 5)
	status.Size = UDim2.fromOffset(if lateral then grip - 8 else totalWidth, if lateral then 38 else 22)
	status.TextSize = 13
	meter.Position = UDim2.fromOffset(screenX, trayBottom + (if lateral then 5 else 29))
	meter.Size = UDim2.fromOffset(width, 18)
	meterText.TextSize = if width < 135 then 11 else 13
	hardware.Position = UDim2.fromOffset(left, if lateral then top + 12 else trayBottom + 49)
	hardware.Size = UDim2.fromOffset(totalWidth, 64)
	dpad.Position = UDim2.fromOffset(if lateral then 20 else 0, if lateral then 77 else 0)
	action.Position = UDim2.fromOffset(totalWidth - 48, 0)
	centerAim.Position = UDim2.fromOffset(totalWidth - 103, 6)
	dropCaption.Position = UDim2.fromOffset(totalWidth - 48, 49)
	centerCaption.Position = UDim2.fromOffset(totalWidth - 103, 53)
	vents.Position = UDim2.fromOffset(if lateral then 49 else totalWidth * 0.47 + 25, if lateral then 174 else 15)
	vents.Visible = lateral or totalWidth >= 310
	for index, button in ipairs({ customizeButton, roomButton, reset }) do
		local buttonWidth = if lateral then grip else (totalWidth - 12) / 3
		button.Position = if lateral then UDim2.fromOffset(menuX, menuY + (index - 1) * 47)
			else UDim2.fromOffset(menuX + (index - 1) * (buttonWidth + 6), menuY)
		button.Size = UDim2.fromOffset(buttonWidth, 44)
		button.TextSize = 13
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

local function canPlay()
	return canAim() and not isPickerOpen() and not roomView.busy and not GuiService.MenuIsOpen
end

local function dropEgg()
	if canPlay() and not drag then
		request:FireServer("drop", aim)
	end
end

local function moveAim(delta)
	aim = math.clamp(aim + delta, 0, 1)
	drawAim()
end

local function center()
	if canPlay() and not drag then
		aim = 0.5
		drawAim()
		audio:play("aim")
	end
end

local function startAim(key, direction)
	if canPlay() and not drag and not heldAim[key] then
		heldAim[key] = direction
		moveAim(direction * 0.045)
		audio:play("aim")
	end
end

local function isPointer(input)
	local kind = input.UserInputType
	return kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch
end

for button, direction in pairs({ [leftAim] = -1, [rightAim] = 1 }) do
	button.InputBegan:Connect(function(input)
		if isPointer(input) then
			startAim(input, direction)
		end
	end)
	button.Activated:Connect(function(input)
		if input and not isPointer(input) and canPlay() and not drag then
			moveAim(direction * 0.08)
		end
	end)
end
action.Activated:Connect(dropEgg)
centerAim.Activated:Connect(center)

local function handleControl(name, state, input)
	local key = input.KeyCode
	if state == Enum.UserInputState.Cancel then
		table.clear(heldAim)
	elseif state == Enum.UserInputState.End then
		heldAim[key] = nil
	end
	local gamepad = isGamepad(input.UserInputType)
	if name == "EggDropCenter" and isPickerOpen() and gamepad and state == Enum.UserInputState.Begin then
		picker:close()
		return Enum.ContextActionResult.Sink
	end
	if not canPlay() or UserInputService:GetFocusedTextBox() or (gamepad and GuiService.SelectedObject) then
		return Enum.ContextActionResult.Pass
	end
	if state == Enum.UserInputState.Begin then
		if name == "EggDropDrop" then
			dropEgg()
		elseif name == "EggDropCustomize" then
			openPicker()
		elseif name == "EggDropCenter" then
			center()
		else
			startAim(key, if name == "EggDropLeft" then -1 else 1)
		end
	end
	return Enum.ContextActionResult.Sink
end

local priority = Enum.ContextActionPriority.High.Value
ContextActionService:BindActionAtPriority("EggDropLeft", handleControl, false, priority,
	Enum.KeyCode.Left, Enum.KeyCode.A, Enum.KeyCode.DPadLeft)
ContextActionService:BindActionAtPriority("EggDropRight", handleControl, false, priority,
	Enum.KeyCode.Right, Enum.KeyCode.D, Enum.KeyCode.DPadRight)
ContextActionService:BindActionAtPriority("EggDropDrop", handleControl, false, priority,
	Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
ContextActionService:BindActionAtPriority("EggDropCenter", handleControl, false, priority, Enum.KeyCode.ButtonB)
ContextActionService:BindActionAtPriority("EggDropCustomize", handleControl, false, priority,
	Enum.KeyCode.M, Enum.KeyCode.ButtonY)

rail.InputBegan:Connect(function(input)
	if not drag and canPlay() and isPointer(input) then
		table.clear(heldAim)
		drag = input
		aimFromScreen(input.Position.X)
		audio:play("aim")
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if drag and (input == drag or (drag.UserInputType == Enum.UserInputType.MouseButton1
		and input.UserInputType == Enum.UserInputType.MouseMovement)) then
		aimFromScreen(input.Position.X)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	heldAim[input] = nil
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		for key in pairs(heldAim) do
			if typeof(key) == "Instance" and key.UserInputType == Enum.UserInputType.MouseButton1 then
				heldAim[key] = nil
			end
		end
	end
	if drag and (input == drag or (drag.UserInputType == Enum.UserInputType.MouseButton1
		and input.UserInputType == Enum.UserInputType.MouseButton1)) then
		drag = nil
		if input.UserInputState == Enum.UserInputState.End and canPlay() then
			aimFromScreen(input.Position.X)
			dropEgg()
		end
	end
end)
UserInputService.WindowFocusReleased:Connect(clearPlayInputs)
GuiService.MenuOpened:Connect(clearPlayInputs)
reset.Activated:Connect(function()
	if not isPickerOpen() then
		request:FireServer("reset")
	end
end)
modalAction.Activated:Connect(function()
	if modalNote.Visible then
		request:FireServer("reset")
	else
		roomView:choosePet(board:GetAttribute("HatchedPet"))
		request:FireServer("mode", "Room")
	end
end)
keepPlaying.Activated:Connect(function()
	dismissedHatch = board:GetAttribute("HatchedPet")
	reveal:cancel()
	audio:play("menu")
	updateHud()
end)
pet.Activated:Connect(function()
	local hatchPet = Pets[board:GetAttribute("OwnedPets") or 0]
	if hatchPet then
		audio:play(hatchPet.cue)
	end
	pet.Rotation = -9
	TweenService:Create(pet, TweenInfo.new(0.24, Enum.EasingStyle.Back), { Rotation = 0 }):Play()
end)

local function addView(source)
	local tier = source:GetAttribute("Tier")
	local id = source:GetAttribute("EggId")
	if not tier or not id then
		return
	end
	local gel = if RunService:IsStudio() and gui:GetAttribute("MeshPreview")
		then Jelly.new(scene, source) else Sprite.new(sprites, source)
	local mark = label("TextLabel", "Mark", Config.Tiers[tier].mark, overlay)
	mark.AnchorPoint = Vector2.new(0.5, 0.5)
	mark.TextColor3 = Palette.Ink
	mark.Size = UDim2.fromOffset(30, 22)
	mark.ZIndex = 4
	eggViews[source] = { gel = gel, mark = mark, id = id }
	viewsById[id] = gel
end

local function removeView(source)
	local view = eggViews[source]
	if view then
		view.gel:destroy()
		view.mark:Destroy()
		viewsById[view.id] = nil
		eggViews[source] = nil
	end
end
board.ChildAdded:Connect(addView)
board.ChildRemoved:Connect(removeView)
if RunService:IsStudio() then
	gui:GetAttributeChangedSignal("MeshPreview"):Connect(function()
		for _, source in ipairs(board:GetChildren()) do
			removeView(source)
			addView(source)
		end
	end)
end
for _, source in ipairs(board:GetChildren()) do
	addView(source)
end

impacts.OnClientEvent:Connect(function(batch)
	local strongest = 0
	local bankHit = false
	for _, impact in ipairs(batch) do
		local gel = viewsById[impact[1]]
		if gel then
			gel:impact(impact[2], impact[3])
			if impact[3] > strongest then
				strongest = impact[3]
				bankHit = impact[2].Y < 0.78
			end
		end
	end
	local now = os.clock()
	if strongest >= 9 and now - lastPlop >= 0.13 then
		lastPlop = now
		audio:play(if bankHit then "bank" else "land", math.clamp(0.82 + strongest / 100, 0.9, 1.2),
			math.clamp(strongest / 70, 0.24, 0.55))
	end
end)

local function gelDrop(from, to, diameter, color, duration, outward)
	local movement = to - from
	local dot = make("Frame", "GelDrop", {
		AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = color, BorderSizePixel = 0,
		BackgroundTransparency = if outward then 0.05 else 0.14, ZIndex = 3,
		Position = UDim2.fromOffset(from.X, from.Y),
		Size = UDim2.fromOffset(diameter * 1.3, diameter * 0.8),
		Rotation = math.deg(math.atan2(movement.Y, movement.X)),
	}, effects)
	make("UICorner", "Round", { CornerRadius = UDim.new(0.5, 0) }, dot)
	local tween = TweenService:Create(dot, TweenInfo.new(duration, Enum.EasingStyle.Quad), {
		Position = UDim2.fromOffset(to.X, to.Y),
		Size = UDim2.fromOffset(diameter * 0.5, diameter * 0.5),
		BackgroundTransparency = 1,
	})
	tween.Completed:Once(function()
		dot:Destroy()
	end)
	tween:Play()
end

feedback.OnClientEvent:Connect(function(position, tier, chain, first, second)
	if board:GetAttribute("Mode") ~= "Board" then
		return
	end
	audio:play(if chain > 1 then "chain" else "merge", 1 + (tier - 2) * 0.07 + math.min(chain - 1, 5) * 0.04)
	local previous = effects:FindFirstChild("MergePop")
	if previous then
		previous:Destroy()
	end
	local count = #effects:GetChildren()
	local limit = if UserInputService.TouchEnabled then 24 else 48
	if count + 5 > limit then
		return
	end
	local point = project(position)
	local color = Config.Tiers[tier].color
	local scale = viewport.AbsoluteSize.X / (Config.Width + 0.8)
	local firstPoint, secondPoint = project(first), project(second)
	local diameter = scale * Config.Tiers[tier - 1].radius * 1.55
	gelDrop(firstPoint, point, diameter, color, 0.18, false)
	gelDrop(secondPoint, point, diameter, color, 0.18, false)
	local delta = secondPoint - firstPoint
	local bridge = make("Frame", "GelBridge", {
		AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, ZIndex = 3,
		BackgroundColor3 = color, BackgroundTransparency = 0.1,
		Position = UDim2.fromOffset(point.X, point.Y),
		Size = UDim2.fromOffset(delta.Magnitude + diameter * 0.8, diameter * 0.49),
		Rotation = math.deg(math.atan2(delta.Y, delta.X)),
	}, effects)
	make("UICorner", "Round", { CornerRadius = UDim.new(0.5, 0) }, bridge)
	local retract = TweenService:Create(bridge, TweenInfo.new(0.2, Enum.EasingStyle.Sine), {
		Size = UDim2.fromOffset(diameter * 0.74, diameter * 1.1), BackgroundTransparency = 1,
	})
	retract.Completed:Once(function() bridge:Destroy() end)
	retract:Play()
	local ring = make("Frame", "MergeRing", {
		AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, ZIndex = 3,
		BackgroundTransparency = 1, Position = UDim2.fromOffset(point.X, point.Y),
		Size = UDim2.fromOffset(diameter, diameter),
	}, effects)
	make("UICorner", "Round", { CornerRadius = UDim.new(0.5, 0) }, ring)
	local stroke = make("UIStroke", "Glow", { Color = color, Thickness = 2, Transparency = 0.25 }, ring)
	local wave = TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Quart), {
		Size = UDim2.fromOffset(diameter * 3.8, diameter * 3.8),
	})
	wave.Completed:Once(function() ring:Destroy() end)
	wave:Play()
	TweenService:Create(stroke, TweenInfo.new(0.32), { Transparency = 1 }):Play()
	local beads = math.min(if UserInputService.TouchEnabled then 4 else 8 + math.min(chain - 1, 4), limit - count - 5)
	for i = 1, beads do
		local angle = i * math.pi * 2 / beads + chain * 0.5
		local burst = Vector2.new(math.cos(angle), math.sin(angle)) * scale * (1.6 + i % 3 * 0.52)
		local tint = if i % 3 == 0 then Palette.Paper else color
		gelDrop(point, point + burst, math.max(4, scale * (0.21 + i % 3 * 0.08)), tint, 0.26 + i % 3 * 0.07, true)
	end
	local pop = label("TextLabel", "MergePop", if chain > 1 then "CHAIN x" .. chain else "POP!", effects)
	pop.TextColor3 = color
	pop.TextStrokeColor3 = Palette.Ink
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
	local tween = TweenService:Create(pop, TweenInfo.new(0.58, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.fromOffset(point.X, point.Y - 44), TextTransparency = 1, TextStrokeTransparency = 1,
	})
	tween.Completed:Once(function()
		pop:Destroy()
	end)
	tween:Play()
end)

local hudQueued = false
board.AttributeChanged:Connect(function()
	if not hudQueued then
		hudQueued = true
		task.defer(function()
			hudQueued = false
			updateHud()
		end)
	end
end)
board:GetAttributeChangedSignal("Mode"):Connect(function()
	clearPlayInputs()
	picker:close()
	local mode = board:GetAttribute("Mode")
	if mode == "Room" then
		dismissedHatch = board:GetAttribute("HatchedPet")
		reveal:cancel()
		effects:ClearAllChildren()
	end
	roomView:setMode(mode)
end)
board:GetAttributeChangedSignal("ResetId"):Connect(function()
	clearPlayInputs()
	reveal:cancel()
	effects:ClearAllChildren()
	audio:stop()
	audio:play("retry")
	dismissedHatch = nil
	lastPlop = -math.huge
end)
board:GetAttributeChangedSignal("Drops"):Connect(function()
	if board:GetAttribute("Drops") > 0 then
		audio:play("drop")
	end
end)
board:GetAttributeChangedSignal("HatchCharge"):Connect(function()
	local charge = board:GetAttribute("HatchCharge")
	if charge > 0 then
		audio:play("charge", 1 + charge * 0.03, 0.35)
	end
end)
board:GetAttributeChangedSignal("RoundOver"):Connect(function()
	if board:GetAttribute("RoundOver") then
		audio:play("overflow")
	end
end)
backdrop:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(drawAim)
RunService.RenderStepped:Connect(function(dt)
	if canPlay() and not drag and not UserInputService:GetFocusedTextBox() then
		local direction = 0
		for _, value in pairs(heldAim) do
			direction += value
		end
		if direction ~= 0 then
			moveAim(math.sign(direction) * 0.62 * dt)
		end
	else
		table.clear(heldAim)
	end
	local now = os.clock()
	local closest
	local distance = math.huge
	local tier = nextTier()
	local guide = (board:GetAttribute("OwnedPets") or 0) == 0 and not modal.Visible and not drag
	local aimX = Config.aimX(aim, tier)
	for source, view in pairs(eggViews) do
		local position = view.gel:render(source.Position, dt, now, project)
		local point = project(Vector2.new(position.X, position.Y))
		view.mark.Position = UDim2.fromOffset(point.X, point.Y)
		if guide and source:GetAttribute("Tier") == tier and position.Y < Config.OverflowY then
			local delta = math.abs(position.X - aimX)
			if delta < distance then
				distance = delta
				closest = point
			end
		end
	end
	targetRing.Visible = closest ~= nil
	if closest then
		local diameter = Config.Tiers[tier].radius * 2 * viewport.AbsoluteSize.X / (Config.Width + 0.8) + 7
		targetRing.Position = UDim2.fromOffset(closest.X, closest.Y)
		targetRing.Size = UDim2.fromOffset(diameter, diameter)
	end
end)
layout()
updateHud()
task.delay(1.5, function()
	if (board:GetAttribute("Drops") or 0) == 0 then
		TweenService:Create(rail, TweenInfo.new(0.38, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 1, true),
			{ BackgroundColor3 = Palette.Shell }):Play()
	end
end)
roomView:setMode(board:GetAttribute("Mode"))
