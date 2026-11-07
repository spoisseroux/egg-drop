local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage.Shared.BoardConfig)
local Pets = require(ReplicatedStorage.Shared.PetCatalog)
local Palette = require(ReplicatedStorage.Shared.DeckPalette)
local Themes = require(ReplicatedStorage.Shared.DeckThemes)
local Stickers = require(ReplicatedStorage.Shared.DeckStickers)
local Trials = require(ReplicatedStorage.Shared.PocketTrials)
local Settings = require(ReplicatedStorage.Shared.DeckSettings)
local EggCatalog = require(ReplicatedStorage.Shared.EggCatalog)
local Jelly = require(script.JellyVisual)
local Sprite = require(script.JellySprite)
local JellyLCD = require(script.JellyLCD)
local Audio = require(script.BoardAudio)
local DeckPicker = require(script.DeckPicker)
local PetJournal = require(script.PetJournal)
local RoomView = require(script.RoomView)
local HandheldScreens = require(script.HandheldScreens)
local HatchReveal = require(script.HatchReveal)
local RoundRecap = require(script.RoundRecap)
local FirstHatchGuide = require(script.FirstHatchGuide)
local Art = require(script.DeckArt)
local DeckLayout = require(script.DeckLayout)
local PresentationPolicy = require(script.PresentationPolicy)
local DropDispenser = require(script.DropDispenser)
local BoardQuestHUD = require(script.BoardQuestHUD)
local HollowClock = require(script.HollowClock)
local NurseryView = require(script.EggHatchView)
local HatchNavigation = require(script.HatchNavigation)
local RunReceipt = require(script.RunReceipt)
local Portrait = require(script.PetPortrait)
local DeckMenu = require(script.DeckMenu)
local audio = Audio.new()
HollowClock.start()
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local request = remotes:WaitForChild("BoardRequest")
local feedback = remotes:WaitForChild("BoardMerge")
local impacts = remotes:WaitForChild("BoardImpact")
local nurseryRequest = remotes:WaitForChild("HatchRequest")
local nurseryFeedback = remotes:WaitForChild("HatchFeedback")
local trays = ReplicatedStorage:WaitForChild("EggDropBoards")
local board = trays:WaitForChild(tostring(player.UserId))
HandheldScreens.start(trays, Config)

local function reduceEffects()
	return GuiService.ReducedMotionEnabled or board:GetAttribute("ReducedEffects") == true
end

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
do
	local notice = label("TextLabel", "SaveNotice", "", gui, Art.Ink)
	notice.AnchorPoint = Vector2.new(0.5, 1)
	notice.Position = UDim2.new(0.5, 0, 1, -2)
	notice.Size = UDim2.new(1, -16, 0, 21)
	notice.TextColor3 = Art.Amber
	notice.TextScaled = true
	notice.ZIndex = 21
	Art.corner(notice, 5)
	make("UISizeConstraint", "BannerSize", { MaxSize = Vector2.new(386, 21) }, notice)
	make("UITextSizeConstraint", "BannerText", { MinTextSize = 9, MaxTextSize = 12 }, notice)
	local function showSaveStatus()
		local state = board:GetAttribute("SaveStatus")
		local encoded = board:GetAttribute("HatchState")
		if type(encoded) == "string" then
			local ok, value = pcall(HttpService.JSONDecode, HttpService, encoded)
			if ok and value.status ~= "Ready" and value.status ~= "Busy" then state = value.status end
		end
		notice.Visible = state ~= nil and state ~= "Ready" and state ~= "Busy"
		notice.Text = if state == "Temporary" then "Loading saved progress · retrying safely"
			elseif state == "Retrying" then "Saving progress · retrying, please wait"
			elseif state == "Locked" then "Waiting for previous session to close…"
			elseif state then "Hatch save unavailable · rejoin to continue" else ""
	end
	board:GetAttributeChangedSignal("SaveStatus"):Connect(showSaveStatus)
	board:GetAttributeChangedSignal("HatchState"):Connect(showSaveStatus)
	showSaveStatus()
end
local bleed = make("ScreenGui", "EggDropBleed", {
	ResetOnSpawn = false, ScreenInsets = Enum.ScreenInsets.None, ClipToDeviceSafeArea = false, DisplayOrder = 9,
}, gui.Parent)
local backing = Art.frame(bleed, "BoardBacking", Art.Backdrop, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 1)
-- Full-screen visuals and safe interactive content need separate coordinate spaces.
local overlayGui = make("ScreenGui", "EggDropOverlays", {
	ResetOnSpawn = false, ScreenInsets = Enum.ScreenInsets.None, ClipToDeviceSafeArea = false, DisplayOrder = 11,
}, gui.Parent)
local modalShade = Art.frame(overlayGui, "ModalShade", Art.Backdrop, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 1)
modalShade.BackgroundTransparency = 0.40
modalShade.Active, modalShade.Visible = true, false
local safeOverlays = Art.frame(overlayGui, "SafeContent", Art.Ink, UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1), 2)
safeOverlays.BackgroundTransparency = 1
local backdrop = make("Frame", "Backdrop", {
	BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
}, gui)
local shell = make("Frame", "CartridgeShell", {
	BackgroundColor3 = Palette.Shell, BorderSizePixel = 0,
}, backdrop)
make("UICorner", "ShellCurve", { CornerRadius = UDim.new(0, 18) }, shell)
local rim = make("UIStroke", "ShellRim", { Color = Palette.Rim, Thickness = 3 }, shell)
do
	local plate = Art.frame(shell, "Faceplate", Palette.Shell, UDim2.fromOffset(5, 4), UDim2.new(1, -10, 1, -14))
	Art.corner(plate, 15)
	Art.stroke(plate, Art.Ink, 0.6)
	Art.shade(plate, 1, 0.84)
	local bevel = Art.frame(plate, "UpperBevel", Art.Silver, UDim2.fromOffset(20, 3), UDim2.new(1, -40, 0, 2))
	bevel.BackgroundTransparency = 0.38
	Art.corner(bevel, 1)
	for _, name in ipairs({ "AimSeat", "ActionSeat" }) do
		local seat = Art.frame(plate, name, Art.Ink, UDim2.fromOffset(0, 0), UDim2.fromOffset(0, 0))
		seat.BackgroundTransparency = 0.89
		Art.corner(seat, 22)
		Art.stroke(seat, Art.Ink, 0.9)
	end
	local bands = Art.frame(plate, "AccentBands", Art.Ink, UDim2.fromOffset(0, 0), UDim2.fromOffset(82, 26))
	bands.BackgroundTransparency = 1
	for index, tint in ipairs({ Art.Leaf, Art.Orange, Art.Ink }) do
		local band = Art.frame(bands, "Band", tint, UDim2.fromOffset((index - 1) * 18 + 7, 3),
			UDim2.fromOffset(9, 22))
		band.Rotation = 27
		Art.corner(band, 2)
	end
end
local bezel = make("Frame", "LCDBezel", { BackgroundColor3 = Art.Ink, BorderSizePixel = 0 }, backdrop)
make("UICorner", "LensCurve", { CornerRadius = UDim.new(0, 12) }, bezel)
local bezelRim = make("UIStroke", "InsetTrim", { Color = Palette.Rim, Thickness = 2 }, bezel)
Art.deck(backing, shell, bezel)
do
	local trim = Art.frame(shell, "MicroTrim", Art.Ink, UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1))
	trim.BackgroundTransparency = 1
	for _, side in ipairs({ 0, 1 }) do
		local shoulder = Art.frame(trim, "ShoulderTrim", Art.Silver,
			UDim2.new(side, if side == 0 then 47 else -113, 0, 2), UDim2.fromOffset(66, 2))
		shoulder.BackgroundTransparency = 0.64
		Art.corner(shoulder, 1)
	end
end
-- A viewport renders the board inside the HUD, using the same projection on desktop and phone.
local viewport = make("ViewportFrame", "Tray", {
	BackgroundColor3 = Art.LCD, BorderSizePixel = 0,
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
local fieldZones = {}
local zoneLayer=Art.frame(overlay,"TargetRegions",Art.Ink,UDim2.fromScale(0,0),UDim2.fromScale(1,1),6)
zoneLayer.BackgroundTransparency=1;zoneLayer.ClipsDescendants=true
for index,side in ipairs({-1,1})do
	local tint=if side==-1 then Color3.fromHex("#3069A5")else Color3.fromHex("#A84F3F")
	local zone=Art.frame(zoneLayer,if side==-1 then "LeftRootPatch"else"RightRootPatch",tint,UDim2.fromScale(0,0),UDim2.fromScale(.2,1),6)
	zone.BackgroundTransparency=.94
	local edge=Art.stroke(zone,tint,.1,2)
	local caption=Art.text(zone,"Target",if side==-1 then "LEFT"else"RIGHT",UDim2.fromOffset(0,2),UDim2.new(1,0,0,14),Art.Silver,10)
	caption.BackgroundColor3,caption.BackgroundTransparency=Art.Ink,.1
	Art.type(caption,"Supporting",true);caption.TextWrapped=false;caption.Size=UDim2.new(1,0,0,18)
	for stripe=1,8 do
		local dash=Art.frame(zone,"Hatch",Art.Ink,UDim2.new(if side==-1 then 1 else 0,if side==-1 then -3 else 0,stripe/9,0),UDim2.fromOffset(3,9),7)
		dash.BackgroundTransparency=.25
	end
	fieldZones[index]={node=zone,edge=edge,side=side}
end

local lcd = JellyLCD.new(overlay)
local lcdStep = 1 / 30
local lcdElapsed = lcdStep
local pixelMerges = {}

local function lcdEnabled()
	return lcd ~= nil and gui:GetAttribute("PixelLCD") ~= false and not gui:GetAttribute("MeshPreview")
end

local function pixelPoint(position)
	return Vector2.new(JellyLCD.Width * (0.5 + position.X / (Config.Width + 0.8)),
		JellyLCD.Height * (0.5 - (position.Y - Config.Height / 2) / (Config.Height + 0.8)))
end

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
title.Font = Enum.Font.GothamBold
title.TextSize = 17
title.TextColor3 = Art.Silver
Art.text(shell, "ModelStamp", "PD·01", UDim2.new(1, -68, 0, 7), UDim2.fromOffset(40, 20), Art.Ink, 10)
local power = make("Frame", "PowerLight", {
	Position = UDim2.new(1, -20, 0, 13), Size = UDim2.fromOffset(8, 8),
	BackgroundColor3 = Art.Cyan, BorderSizePixel = 0,
}, shell)
make("UICorner", "Round", { CornerRadius = UDim.new(0.5, 0) }, power)
Art.stroke(power, Art.Cyan, 0.65, 3)
local deckSticker = label("TextLabel", "DeckSticker", "", backdrop, Palette.Primary)
deckSticker.Size = UDim2.fromOffset(24, 24)
deckSticker.Rotation = -11
make("UICorner", "StickerCurve", { CornerRadius = UDim.new(0, 5) }, deckSticker)
local rail = label("TextButton", "AimRail", "", backdrop, Art.Ink)
rail.AutoButtonColor = false
rail.Font = Enum.Font.Code
rail.TextColor3 = Palette.Paper
rail.Selectable = false
make("UICorner", "RailCurve", { CornerRadius = UDim.new(0, 9) }, rail)
Art.frame(rail, "ReadoutDivider", Art.Line, UDim2.new(0, 6, 1, -2), UDim2.new(1, -12, 0, 1))
local readout = label("TextLabel", "GameReadout", "EGG DROP", rail)
readout.Font = Enum.Font.Code
make("UITextSizeConstraint", "CountSize", { MinTextSize = 9, MaxTextSize = 19 }, readout)
readout.TextColor3 = Art.Silver
readout.TextXAlignment = Enum.TextXAlignment.Left
local queueHost=Art.frame(backdrop,"PieceQueue",Art.Ink,UDim2.fromOffset(0,0),UDim2.fromOffset(180,64),4)
queueHost.ClipsDescendants=true;Art.corner(queueHost,9)
local queuePieces={}
for index,name in ipairs({"Dropping","Next"})do
	local slot=Art.frame(queueHost,name,Art.Ink,UDim2.fromScale((index-1)*.5,0),UDim2.fromScale(.5,1),5)
	local caption=Art.text(slot,"Caption",name,UDim2.fromOffset(2,0),UDim2.new(1,-4,0,14),Art.Muted,11);Art.fitText(caption,12,8,0)
	local ball=Art.frame(slot,"Piece",Config.Tiers[1].color,UDim2.new(.5,-14,0,19),UDim2.fromOffset(28,28),6)
	Art.corner(ball,30);Art.shade(ball,1,.7)
	local mark=Art.text(ball,"Mark","I",UDim2.fromScale(0,0),UDim2.fromScale(1,1),Art.Ink,12);Art.fitText(mark,12,8,0)
	queuePieces[index]=ball
end
local scoreCaption = Art.text(rail, "ScoreCaption", "SCORE", UDim2.new(0.5, -22, 0, 7),
	UDim2.fromOffset(40, 12), Art.Muted, 10)
local walletDrop=require(script.EggArt).nectar(backdrop,UDim2.fromOffset(0,0),UDim2.fromOffset(18,20),4)
local bestReadout = label("TextLabel", "BestReadout", "", rail)
bestReadout.Font = Enum.Font.Code
bestReadout.TextXAlignment = Enum.TextXAlignment.Left
bestReadout.TextColor3 = Art.Muted
bestReadout.TextTruncate = Enum.TextTruncate.AtEnd
local nextReadout = label("TextLabel", "NextReadout", "", rail)
nextReadout.Font = Enum.Font.Code
nextReadout.TextXAlignment = Enum.TextXAlignment.Right
local mascot = make("Frame", "PixelPip", {
	Position = UDim2.new(0, 10, 0.5, -10), Size = UDim2.fromOffset(21, 21), BackgroundTransparency = 1,
}, rail)
local mascotEyes = {}
local mascotInk = Art.Cyan
for row, pixels in ipairs({ "..+.+..", "...+...", "..###..", ".#####.", ".#o#o#.", ".#####.", "..###.." }) do
	for column = 1, #pixels do
		local symbol = pixels:sub(column, column)
		if symbol ~= "." then
			local pixel = make("Frame", "Pixel", {
				Position = UDim2.fromOffset((column - 1) * 3, (row - 1) * 3), Size = UDim2.fromOffset(3, 3),
				BorderSizePixel = 0, BackgroundColor3 = if symbol == "+" then Art.Silver else mascotInk,
			}, mascot)
			if symbol == "o" then
				table.insert(mascotEyes, pixel)
			end
		end
	end
end
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
status.TextColor3 = Art.Silver
status.TextScaled = false
status.BackgroundColor3 = Art.Ink
Art.corner(status, 6)
local meter = make("Frame", "HatchTrack", {
	BackgroundColor3 = Art.Ink, BorderSizePixel = 0,
}, backdrop)
Art.corner(meter, 3)
Art.stroke(meter, Art.Line)
local segments = {}
local maxCharge = 24
for index = 1, maxCharge do
	segments[index] = make("Frame", "Cell", {
		Position = UDim2.new((index - 1) / maxCharge, 1, 1, -6),
		Size = UDim2.new(1 / maxCharge, -2, 0, 4),
		BackgroundColor3 = Art.Line, BorderSizePixel = 0,
	}, meter)
end
local function layoutDropMeter()
	local usable = math.max(0,meter.AbsoluteSize.X-66)
	local gap = if usable>=maxCharge*3 then 2 elseif usable>=maxCharge*2 then 1 else 0
	local width = math.max(1,(usable-gap*(maxCharge-1))/maxCharge)
	for index,cell in ipairs(segments)do
		cell.Position=UDim2.new(0,(index-1)*(width+gap),.5,-3)
		cell.Size=UDim2.fromOffset(width,6)
	end
end
meter:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutDropMeter)
local meterText = label("TextLabel", "MeterText", "", meter)
meterText.Font = Enum.Font.Code
meterText.Size = UDim2.new(0, 62, 1, 0)
meterText.Position = UDim2.new(1, -64, 0, 0)
meterText.TextSize = 12
meterText.TextColor3 = Palette.Paper
meterText.TextStrokeColor3 = Palette.Ink
meterText.TextStrokeTransparency = 0
local rareGoal = Art.text(backdrop, "RareGoal", "", UDim2.fromOffset(0, 0),
	UDim2.fromOffset(0, 0), Art.Cyan, 12, Enum.Font.GothamMedium)
rareGoal.TextScaled = true
rareGoal.TextWrapped = true
rareGoal.ClipsDescendants = true
rareGoal.BackgroundColor3 = Art.Ink
Art.corner(rareGoal, 5)
make("UITextSizeConstraint", "ReadoutSize", { MinTextSize = 8, MaxTextSize = 12 }, rareGoal)
local eggGoal = Art.frame(backdrop, "EggGoal", Art.Ink, UDim2.fromOffset(0, 0), UDim2.fromOffset(120, 70), 2)
eggGoal.BackgroundTransparency = 1
local goalEgg = Art.frame(eggGoal, "Egg", Art.Leaf, UDim2.fromOffset(8, 6), UDim2.fromOffset(25, 34), 2)
Art.corner(goalEgg, 20); Art.stroke(goalEgg, Art.Silver, .3)
local eggGoalText = Art.text(eggGoal, "Caption", "MEADOW EGG", UDim2.fromOffset(40, 3), UDim2.new(1, -42, 0, 42), Art.Ink, 12)
eggGoalText.TextXAlignment = Enum.TextXAlignment.Left
Art.fitText(eggGoalText, 13, 9, 0, true)
local overflowLine = make("Frame", "OverflowLine", {
	BackgroundColor3 = Palette.Amber, BackgroundTransparency = 0.45,
	BorderSizePixel = 0, ZIndex = 2,
}, overlay)
local pressureTrack = Art.frame(overlay, "DangerTrack", Art.Ink, UDim2.new(1, -7, 0, 4), UDim2.new(0, 4, .22, 0), 7)
local pressureFill = Art.frame(pressureTrack, "Fill", Art.Amber, UDim2.new(0, 0, 1, 0), UDim2.fromScale(1, 0), 8)
pressureFill.AnchorPoint = Vector2.new(0, 1)
pressureTrack.Visible = false
local pressureText = Art.text(overlay, "DangerText", "CLEAR THE LINE", UDim2.new(0, 3, 0, 3), UDim2.new(1, -14, 0, 16), Art.Amber, 11)
pressureText.Visible = false
local targetRing = make("Frame", "MatchHint", {
	AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false, ZIndex = 4,
}, overlay)
make("UICorner", "Round", { CornerRadius = UDim.new(0.5, 0) }, targetRing)
make("UIStroke", "Outline", { Color = Palette.Amber, Thickness = 2, Transparency = 0.25 }, targetRing)
local function utilityButton(name, titleText)
	local button = label("TextButton", name, "", backdrop)
	local well = Art.frame(button, "KeyWell", Art.Ink, UDim2.fromOffset(4, 5), UDim2.new(1, -8, 1, -7))
	Art.corner(well, 12)
	local cap = make("Frame", "Cap", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 3),
		Size = UDim2.new(1, -10, 1, -10), BackgroundColor3 = Art.Raised, BorderSizePixel = 0,
	}, button)
	Art.corner(cap, 11)
	local edge = make("UIStroke", "Lip", { Color = Palette.Rim, Thickness = 1 }, cap)
	Art.shade(cap, 1, 0.6)
	local inlay = Art.frame(cap, "Inlay", Art.Line, UDim2.fromOffset(9, 4), UDim2.new(1, -18, 0, 2))
	Art.corner(inlay, 1)
	local caption = label("TextLabel", "Caption", titleText, cap)
	caption.Position = UDim2.fromOffset(0, 3)
	caption.Size = UDim2.new(1, 0, 1, -3)
	caption.Font = Enum.Font.GothamBold
	caption.TextSize = 12
	caption.TextColor3 = Art.Silver
	button.MouseButton1Down:Connect(function()
		cap.Position = UDim2.new(0.5, 0, 0, 9)
	end)
	button.MouseButton1Up:Connect(function()
		cap.Position = UDim2.new(0.5, 0, 0, 7)
	end)
	button.MouseLeave:Connect(function()
		cap.Position = UDim2.new(0.5, 0, 0, 7)
	end)
	return button, edge, caption
end
local customizeButton, customizeLip = utilityButton("Customize", "CUSTOMIZE")
local roomButton, roomLip, roomCaption = utilityButton("VisitRoom", "LOUNGE")
local eggButton = utilityButton("OpenEggs", "EGGS")
local hardware = make("Frame", "DeckControls", { BackgroundTransparency = 1 }, backdrop)
local function hardwareButton(name, text, parent, color, width)
	local button = label("TextButton", name, text, parent, color)
	button.Size = UDim2.fromOffset(width, width)
	button.Font = Enum.Font.Code
	button.TextSize = 24
	button.ZIndex = 3
	Art.button(button, if width == 44 then 7 else 24)
	return button
end
local dpad = make("Frame", "DPad", {
	Size = UDim2.fromOffset(94, 56), BackgroundTransparency = 1,
}, hardware)
Art.corner(Art.frame(dpad, "RockerWell", Art.Ink, UDim2.fromOffset(-3, 5), UDim2.fromOffset(100, 51)), 9)
local leftAim = hardwareButton("Left", "◀", dpad, Art.Raised, 44)
local rightAim = hardwareButton("Right", "▶", dpad, Art.Raised, 44)
leftAim.Position, rightAim.Position = UDim2.fromOffset(0, 8), UDim2.fromOffset(50, 8)
leftAim.TextColor3, rightAim.TextColor3 = Art.Silver, Art.Silver
leftAim.TextSize, rightAim.TextSize = 16, 16
Art.corner(Art.frame(hardware, "DropWell", Art.Ink, UDim2.new(1, -51, 0, 1), UDim2.fromOffset(54, 53)), 27)
local action = hardwareButton("Drop", "A", hardware, Art.Amber, 48)
action:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0.5, 0)
Art.stroke(action, Art.Ink, 0.14, 3)
local aGlint = Art.frame(action, "Glint", Art.Silver, UDim2.fromScale(0.3, 0.16), UDim2.new(0.4, 0, 0, 3))
aGlint.BackgroundTransparency = 0.50
Art.corner(aGlint, 1)
local dropCaption = label("TextLabel", "DropCaption", "DROP", hardware)
dropCaption.Size = UDim2.fromOffset(48, 16)
dropCaption.Font = Enum.Font.Code
dropCaption.TextColor3 = Art.Silver
dropCaption.TextSize = 11
local vents = make("Frame", "Speaker", { Size = UDim2.fromOffset(57, 28), BackgroundTransparency = 1 }, hardware)
for row = 0, 2 do
	for column = 0, 5 do
		local hole = Art.frame(vents, "Vent", Art.Ink,
			UDim2.fromOffset(2 + column * 9, 2 + row * 8), UDim2.fromOffset(4, 4))
		Art.corner(hole, 2)
	end
end
Art.text(hardware, "MakerMark", "EGG DROP", UDim2.fromOffset(0, 0), UDim2.fromOffset(96, 16), Art.Ink, 12)
hardware.MakerMark.Font = Enum.Font.GothamBold
local firstHatchGuide = FirstHatchGuide.new(rail, dpad.RockerWell, action, meter, status)
local questHUD = BoardQuestHUD.new(status)
local dispenser = DropDispenser.new(meter, reduceEffects)
local function isGamepad(inputType)
	return string.match(inputType.Name, "^Gamepad") ~= nil
end

local openPicker
local openJournal
local picker
local journal
local nurseryView
local nurseryState
local openNursery
local trackedRare
local gameMenu
local openMenu
local closeMenu
local updateHud
local layout
local hatchNavigation
local function cancelHatchNavigation()
	if hatchNavigation then hatchNavigation:cancel() end
end
local function isPickerOpen()
	return picker ~= nil and picker.shade.Visible
end
local roomView = RoomView.new(gui, backdrop, board, audio, function()
	cancelHatchNavigation()
	request:FireServer("mode", "Board")
end, function()
	openPicker()
end, function()
	openJournal()
end, function()
	return isPickerOpen() or (journal and journal.shade.Visible) or (nurseryView and nurseryView:isOpen()) or (gameMenu and gameMenu.shade.Visible)
end, reduceEffects, function() if openNursery then openNursery() end end)
do
	local handoff = gui.DeckHandoff
	handoff.Parent = safeOverlays
	local curtain = Art.frame(bleed, "HandoffBacking", Art.Backdrop, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 2)
	local function updateBacking()
		bleed.Enabled = gui.Enabled
		overlayGui.Enabled = gui.Enabled
		backing.Visible = backdrop.Visible
		curtain.Visible = handoff.Visible and not backdrop.Visible
		curtain.BackgroundTransparency = handoff.BackgroundTransparency
	end
	gui:GetPropertyChangedSignal("Enabled"):Connect(updateBacking)
	backdrop:GetPropertyChangedSignal("Visible"):Connect(updateBacking)
	handoff:GetPropertyChangedSignal("Visible"):Connect(updateBacking)
	handoff:GetPropertyChangedSignal("BackgroundTransparency"):Connect(updateBacking)
	updateBacking()
end
journal = PetJournal.new(safeOverlays, make, label, function(pet)
	cancelHatchNavigation()
	if board:GetAttribute("CompanionId") == pet.id then
		roomView:showPet(pet)
		audio:play(pet.cue)
	else
		request:FireServer("companion", pet.id)
	end
end, function(pet)
	roomView:requestSwitch(function()
		local trials = board:GetAttribute("TrialMask") or 0
		if board:GetAttribute("Mode") == "Room" and not Pets.isUnlocked(pet, 0, trials) then
			trackedRare = pet
			request:FireServer("mode", "Board")
		end
	end)
end, function()
	-- This route only opens the existing goal picker. Selecting/equipping stays explicit.
	openMenu()
	if gameMenu.shade.Visible then
		gameMenu:setPage("mastery")
		if isGamepad(UserInputService:GetLastInputType()) then GuiService.SelectedObject = gameMenu.tabs.mastery end
	end
end)
board:GetAttributeChangedSignal("CompanionId"):Connect(function()
	local pet = Pets.byId[board:GetAttribute("CompanionId")]
	if pet and board:GetAttribute("Mode") == "Room" then
		roomView:showPet(pet)
		audio:play(pet.cue)
	end
end)
roomButton.Activated:Connect(function()
	cancelHatchNavigation()
	if not isPickerOpen() then
		roomView:collapseControls()
		roomView:requestSwitch(function()
			if not isPickerOpen() then
				request:FireServer("mode", "Room")
			end
		end)
	end
end)
local modal = make("Frame", "RoundCard", {
	Active = true, Visible = false, BorderSizePixel = 0, ZIndex = 10,
	AnchorPoint = Vector2.new(0.5, 0.5),
}, safeOverlays)
Art.panel(modal, 12, Art.Amber)
local modalTag = Art.text(modal, "Channel", "", UDim2.fromOffset(12, 5),
	UDim2.new(1, -24, 0, 16), Art.Amber, 11)
local modalTitle = label("TextLabel", "Heading", "", modal)
modalTitle.Position = UDim2.fromOffset(0, 18)
modalTitle.Size = UDim2.new(1, 0, 0, 35)
modalTitle.Font = Enum.Font.GothamBold
modalTitle.TextSize = 20
modalTitle.TextColor3 = Art.Silver
modalTitle.ZIndex = 11
Art.fitText(modalTitle, 20, 12, 12)
local hatchStage = Art.frame(modal, "HatchStage", Art.Ink, UDim2.fromOffset(12, 55), UDim2.new(1, -24, 0, 108), 11)
Art.corner(hatchStage, 7)
Art.stroke(hatchStage, Art.Line)
for _, side in ipairs({ -1, 1 }) do
	for index = 1, 3 do
		local spark = Art.frame(hatchStage, "StarTick", Art.Cyan,
			UDim2.new(0.5, side * (48 + index * 9), 0, 24 + index * 14), UDim2.fromOffset(3 + index % 2, 2))
		spark.BackgroundTransparency = 0.46
	end
end
local pedestal = Art.frame(hatchStage, "Shadow", Art.Raised, UDim2.new(0.5, -34, 1, -15), UDim2.fromOffset(68, 6))
Art.corner(pedestal, 3)
local hatchIndex = Art.text(modal, "CollectionIndex", "", UDim2.fromOffset(12, 164),
	UDim2.new(1, -24, 0, 18), Art.Muted, 11)
local pet = label("TextButton", "Pet", "", modal)
pet.AnchorPoint = Vector2.new(0.5, 0.5)
pet.Position = UDim2.new(0.5, 0, 0, 108)
pet.Size = UDim2.fromOffset(88, 88)
pet.ZIndex = 14
pet.AutoButtonColor = false
local reveal = HatchReveal.new(modal, pet, audio)
local recap = RoundRecap.new(modal, audio, reduceEffects)
recap.onPreferredLayout=function()if layout then layout() end end
local modalAction = label("TextButton", "Continue", "", modal, Art.Amber)
modalAction.Position = UDim2.new(0.09, 0, 1, -52)
modalAction.Size = UDim2.new(0.82, 0, 0, 44)
modalAction.ZIndex = 11
local keepPlaying = label("TextButton", "KeepPlaying", "Keep playing", modal, Art.Raised)
keepPlaying.Position = UDim2.new(0.52, 0, 1, -52)
keepPlaying.Size = UDim2.new(0.43, 0, 0, 44)
keepPlaying.ZIndex = 11
keepPlaying.TextColor3 = Art.Silver
for _, button in ipairs({ modalAction, keepPlaying }) do
	Art.button(button, 7)
	Art.fitText(button, 15, 10, 9)
	button.TextWrapped = true
end
local knownPets = board:GetAttribute("OwnedPets") or 0
local hatchQueue = {}
local revealedPet
local lastPlop = -math.huge
local lastMerge = -math.huge
local mergeBurst = 0
local lastChainAccent = -math.huge
local mascotMood

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

local previewStickerId=Stickers.Default
local function paintDeck(id, stickerId)
	previewStickerId=stickerId
	local theme = Themes.ById[id]
	shell.BackgroundColor3 = theme.shell
	shell.Faceplate.BackgroundColor3 = theme.face or theme.shell:Lerp(theme.trim, 0.27)
	rim.Color = theme.trim
	bezelRim.Color = theme.trim
	customizeLip.Color = theme.buttons
	action.BackgroundColor3 = theme.buttons
	leftAim.BackgroundColor3 = theme.rocker or Art.Raised
	rightAim.BackgroundColor3 = leftAim.BackgroundColor3
	leftAim.TextColor3 = if theme.rocker then Art.Ink else Art.Silver
	rightAim.TextColor3 = leftAim.TextColor3
	title.TextColor3 = Art.Silver
	status.TextColor3 = if status.BackgroundTransparency < 1 then Art.Silver else title.TextColor3
	dropCaption.TextColor3 = title.TextColor3
	hardware.MakerMark.TextColor3 = title.TextColor3
	Art.tintBackdrop(backing,theme)
	modalShade.BackgroundColor3=Art.Ink
	Stickers.paint(deckSticker, stickerId)
	if backdrop:GetAttribute("StickerSlot")~=true then deckSticker.Visible=false end
end

local function canAim()
	return board:GetAttribute("Mode") == "Board" and not modal.Visible and not roomView.busy
		and not journal.shade.Visible and not (gameMenu and gameMenu.shade.Visible)
		and not (nurseryView and nurseryView:isOpen()) and board:GetAttribute("FieldPhase") ~= "Settling"
		and not board:GetAttribute("RoundOver")
end

local function canPlay()
	return canAim() and not isPickerOpen() and not roomView.busy and not GuiService.MenuIsOpen
		and board:GetAttribute("FieldReady") ~= false
end

picker = DeckPicker.new(safeOverlays, make, label, paintDeck, function()
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
end, function(actionName)
	request:FireServer(actionName)
end)

nurseryView = NurseryView.new(safeOverlays, audio, reduceEffects, function(actionName, value, revision)
	nurseryRequest:FireServer(actionName, value, revision)
end)
openNursery = function()
	if roomView.busy or board:GetAttribute("Mode") ~= "Room" then return end
	picker:close()
	journal:close()
	if nurseryState then nurseryView:open(nurseryState) end
end
hatchNavigation = HatchNavigation.new({
	get = function(name) return board:GetAttribute(name) end,
	send = function(actionName, value) request:FireServer(actionName, value) end,
	ready = function() return not roomView.busy end,
	blocked = function()
		return isPickerOpen() or journal.shade.Visible or nurseryView:isOpen()
			or (gameMenu and gameMenu.shade.Visible) or GuiService.MenuIsOpen
	end,
	present = function(petId)
		local pet = Pets.byId[petId]
		if not pet or not EggCatalog.isOwned(board:GetAttribute("InventoryMask") or 0, petId) then return end
		if not roomView.pet or roomView.shownPet.id ~= petId then roomView:showPet(pet) end
		roomView:collapseControls()
		roomView:focusPet()
	end,
	failure = function()
		if board:GetAttribute("Mode") == "Room" then openJournal() end
	end,
})
nurseryView.onClosed = function(reason, choice)
	cancelHatchNavigation()
	if reason == "meet" and choice and EggCatalog.isOwned(board:GetAttribute("InventoryMask") or 0, choice.petId) then
		hatchNavigation:meet(choice.petId)
	elseif reason == "earn" or reason == "afterHatch" then
		hatchNavigation:play()
	end
end
local function visitEggs()
	cancelHatchNavigation()
	local generation = hatchNavigation.generation
	if roomView.busy or not (board:GetAttribute("OwnedPets") > 0) then return end
	request:FireServer("mode", "Room")
	task.spawn(function()
		local deadline = os.clock() + 4
		repeat task.wait(.1) until (board:GetAttribute("Mode") == "Room" and not roomView.busy) or os.clock() > deadline
		if hatchNavigation.generation == generation then openNursery() end
	end)
end
eggButton.Visible = false
local shownNurseryHatch
local function refreshNursery()
	local encoded = board:GetAttribute("HatchState")
	if typeof(encoded) ~= "string" then return end
	local ok, state = pcall(HttpService.JSONDecode, HttpService, encoded)
	if not ok or type(state) ~= "table" then return end
	nurseryState = state
	roomView.transition:refresh()
	nurseryView:update(state)
	local result = state.lastHatch
	if result and result.id ~= shownNurseryHatch then
		cancelHatchNavigation()
		shownNurseryHatch = result.id
		-- Purchase already shows the committed result in the current view. Do not
		-- schedule a second open that could undo an immediate Close.
		if nurseryView:isOpen() then return end
		local generation = hatchNavigation.generation
		task.spawn(function()
			if hatchNavigation.generation ~= generation then return end
			if board:GetAttribute("Mode") ~= "Room" then request:FireServer("mode", "Room") end
			local deadline = os.clock() + 5
			repeat task.wait(.1) until (board:GetAttribute("Mode") == "Room" and not roomView.busy) or os.clock() > deadline
			if hatchNavigation.generation == generation and nurseryState and nurseryState.lastHatch
				and nurseryState.lastHatch.id == result.id then
				PresentationPolicy.presentCommittedHatch(result.id,generation,{generation=hatchNavigation.generation,
					id=nurseryState.lastHatch.id,mode=board:GetAttribute("Mode"),ready=not roomView.busy},
					function()if closeMenu then closeMenu()end end,openNursery)
			end
		end)
	end
end
board:GetAttributeChangedSignal("HatchState"):Connect(refreshNursery)
nurseryFeedback.OnClientEvent:Connect(function(kind, message)
	if kind == "open" then openNursery()
	elseif kind == "error" then nurseryView:setError(message) end
end)
refreshNursery()

gameMenu = DeckMenu.new(safeOverlays, {
	close = function() closeMenu() end,
	eggs = function() closeMenu(); visitEggs() end,
	pets = function()
		closeMenu(); cancelHatchNavigation()
		local generation = hatchNavigation.generation
		if board:GetAttribute("Mode") == "Room" and not roomView.busy then openJournal(); return end
		request:FireServer("mode", "Room")
		task.spawn(function()
			local deadline=os.clock()+5
			repeat task.wait(.1) until hatchNavigation.generation~=generation
				or (board:GetAttribute("Mode")=="Room" and not roomView.busy) or os.clock()>deadline
			if hatchNavigation.generation==generation and board:GetAttribute("Mode")=="Room" and not roomView.busy then openJournal() end
		end)
	end,
	style = function() closeMenu(); openPicker() end,
	play = function() closeMenu(); if board:GetAttribute("Mode") == "Room" then request:FireServer("mode", "Board") end end,
	daily = function() if nurseryState then nurseryRequest:FireServer("daily", nurseryState.dailyDay, nurseryState.revision) end end,
	family = function(family) request:FireServer("family", family) end,
})
closeMenu = function()
	gameMenu:close(); roomView:setMenuOpen(false)
	end
openMenu = function()
	cancelHatchNavigation()
	if roomView.busy or modal.Visible or nurseryView:isOpen() then return end
	clearPlayInputs(); picker:close(); journal:close(); roomView:setMenuOpen(true)
	gameMenu:update(nurseryState, board:GetAttribute("SelectedFamily"), board:GetAttribute("RunFamily"), board:GetAttribute("Score"), board:GetAttribute("PeakChain"), board:GetAttribute("BestScore"), nurseryView.selected)
	gameMenu:open(); audio:play("menu")
end
roomView.onOpenMenu = openMenu

do
	local handoff = safeOverlays.DeckHandoff
	local function alignSafeContent()
		local origin = backdrop.AbsolutePosition - overlayGui.AbsolutePosition
		local margin=if backdrop.AbsoluteSize.Y<280 then 0 else 8
		safeOverlays.Position = UDim2.fromOffset(origin.X+margin,origin.Y+margin)
		safeOverlays.Size = UDim2.fromOffset(math.max(1,backdrop.AbsoluteSize.X-margin*2),math.max(1,backdrop.AbsoluteSize.Y-margin*2))
	end
	local function updateShade()
		roomView.transition:refresh()
		modalShade.Visible = modal.Visible or picker.shade.Visible or journal.shade.Visible or nurseryView:isOpen() or gameMenu.shade.Visible
		request:FireServer("pause", modalShade.Visible)
	end
	for _, node in ipairs({ modal, picker.shade, journal.shade, nurseryView.shade, gameMenu.shade }) do
		node:GetPropertyChangedSignal("Visible"):Connect(function()
			updateShade()
			if node ~= modal and updateHud then task.defer(updateHud) end
		end)
	end
	-- Handoff must cover overlays as well as the board during a mode switch.
	handoff.ZIndex = 50
	backdrop:GetPropertyChangedSignal("AbsolutePosition"):Connect(alignSafeContent)
	backdrop:GetPropertyChangedSignal("AbsoluteSize"):Connect(alignSafeContent)
	overlayGui:GetPropertyChangedSignal("AbsolutePosition"):Connect(alignSafeContent)
	alignSafeContent()
	updateShade()
end

roomView.transition.presentationState = function()
	return { mode=board:GetAttribute("Mode"), ended=board:GetAttribute("RoundOver")==true,
		pendingHatch=hatchQueue[1]~=nil or (nurseryState and nurseryState.lastHatch~=nil),
		overlay=modal.Visible or isPickerOpen() or journal.shade.Visible or nurseryView:isOpen()
			or gameMenu.shade.Visible or GuiService.MenuIsOpen, reduced=reduceEffects() }
end
for _,name in ipairs({"RoundOver","ReducedEffects","Mode"}) do
	board:GetAttributeChangedSignal(name):Connect(function() roomView.transition:refresh() end)
end
GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function() roomView.transition:refresh() end)
GuiService.MenuOpened:Connect(function() roomView.transition:refresh() end)

local function updateClub()
	local sound = board:GetAttribute("SoundLevel") or Settings.DefaultSound
	picker:updateClub(board:GetAttribute("OwnedPets") or 0, board:GetAttribute("TrialMask") or 0,
		board:GetAttribute("PeakChain") or 0, board:GetAttribute("Score") or 0, sound,
		board:GetAttribute("ReducedEffects") == true, GuiService.ReducedMotionEnabled, board:GetAttribute("InventoryMask"))
end

openPicker = function()
	cancelHatchNavigation()
	if isPickerOpen() or roomView.busy or (board:GetAttribute("Mode") == "Board" and modal.Visible) then
		return
	end
	clearPlayInputs()
	rail.Interactable = false
	local themeId, stickerId = equippedAppearance()
	updateClub()
	picker:open(themeId, stickerId)
	if isGamepad(UserInputService:GetLastInputType()) then
		GuiService.SelectedObject = picker.tabs.Shell
	end
	audio:play("menu")
end
openJournal = function()
	cancelHatchNavigation()
	journal:open(board:GetAttribute("OwnedPets") or 0, board:GetAttribute("TrialMask") or 0, board:GetAttribute("CompanionId"),
		isGamepad(UserInputService:GetLastInputType()), trackedRare, board:GetAttribute("InventoryMask"),
		nurseryState and nurseryState.masteryRanks)
	audio:play("menu")
end
ProximityPromptService.PromptTriggered:Connect(function(prompt, playerWhoTriggered)
	if playerWhoTriggered ~= player or board:GetAttribute("Mode") ~= "Room" or roomView.busy
		or isPickerOpen() or journal.shade.Visible or nurseryView:isOpen() or gameMenu.shade.Visible or roomView.focusing then
		return
	end
	local station = prompt:GetAttribute("PocketClubStation")
	if station == "Customize" then
		openPicker()
	elseif station == "Journal" then
		openJournal()
	end
end)
task.spawn(function()
	local lounge = workspace:WaitForChild("EggDropLounge")
	local function updatePrompts()
		for _, object in ipairs(lounge:GetDescendants()) do
			if object:IsA("ProximityPrompt") and object:GetAttribute("PocketClubStation") then
				object.Enabled = board:GetAttribute("Mode") == "Room" and not roomView.busy and not roomView.focusing
					and not modal.Visible and not isPickerOpen() and not journal.shade.Visible and not nurseryView:isOpen() and not gameMenu.shade.Visible
			end
		end
	end
	board:GetAttributeChangedSignal("Mode"):Connect(updatePrompts)
	for _, overlay in ipairs({ picker.shade, journal.shade, nurseryView.shade, gameMenu.shade, roomView.controls }) do
		overlay:GetPropertyChangedSignal("Visible"):Connect(updatePrompts)
	end
	updatePrompts()
end)
customizeButton.Activated:Connect(function() if openMenu then openMenu() end end)
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
	nextReadout.Text = Config.Tiers[tier].mark .. " · " .. Config.Tiers[board:GetAttribute("PreviewTier1") or 1].mark
		.. " · " .. Config.Tiers[board:GetAttribute("PreviewTier2") or 1].mark
	nextReadout.TextColor3 = Config.Tiers[tier].color
	if queuePieces then
		for index,piece in ipairs(queuePieces)do local t=if index==1 then tier else (board:GetAttribute("PreviewTier1") or 1);piece.BackgroundColor3=Config.Tiers[t].color;piece.Mark.Text=Config.Tiers[t].mark
			if queueHost:GetAttribute("InlineTiers") then piece.Parent.Caption.Text=(if index==1 then "Now " else "Next ")..piece.Mark.Text;piece.Parent.Caption.TextColor3=Config.Tiers[t].color end
		end
		if queueHost:GetAttribute("CombinedTiers") then
			queuePieces[1].Parent.Caption.Text="Now "..queuePieces[1].Mark.Text.."/Next "..queuePieces[2].Mark.Text
			queuePieces[1].Parent.Caption.TextColor3=Art.Silver
		end
	end
	local overflow = project(Vector2.new(0, board:GetAttribute("DangerY") or Config.OverflowY))
	overflowLine.Position = UDim2.fromOffset(scale * 0.4, overflow.Y)
	overflowLine.Size = UDim2.fromOffset(scale * Config.Width, 2)
end

local lastTrialMask = board:GetAttribute("TrialMask") or 0
local trialNotice, trialNoticeUntil

local function shouldCoachField()
	return nurseryState and nurseryState.status == "Ready" and (board:GetAttribute("OwnedPets") or 0) > 0
		and board:GetAttribute("FieldPhase") == "Playing" and canAim() and not isPickerOpen() and not roomView.busy
end

updateHud = function()
	local drops = board:GetAttribute("Drops") or 0
	local merges = board:GetAttribute("Merges") or 0
	local chain = board:GetAttribute("Chain") or 0
	local peakChain = board:GetAttribute("PeakChain") or 0
	local maxClears = board:GetAttribute("MaxClears") or 0
	local score = board:GetAttribute("Score") or 0
	local best = board:GetAttribute("BestScore") or 0
	local charge = board:GetAttribute("HatchCharge") or 0
	local owned = board:GetAttribute("OwnedPets") or 0
	local mask = board:GetAttribute("TrialMask") or 0
	local newlyEarned = bit32.band(mask, bit32.bnot(lastTrialMask))
	if mask ~= lastTrialMask then
		local earnedClub = Trials.clubComplete(mask) and not Trials.clubComplete(lastTrialMask)
		lastTrialMask = mask
		if bit32.band(newlyEarned, Trials.ClubMask) ~= 0 then
			trialNotice = "Trial complete! Check the Club tab."
			if earnedClub then
				trialNotice = "Club sticker earned!"
			else
				for _, goal in ipairs(Trials.Goals) do
					if bit32.band(newlyEarned, goal.bit) ~= 0 then
						trialNotice = goal.name .. " trial complete!"
						break
					end
				end
			end
			trialNoticeUntil = os.clock() + 4
			task.delay(4, updateHud)
		end
	end
	if isPickerOpen() then
		updateClub()
	end
	local nurseryActive = board:GetAttribute("HatchActive") == true
	local nextPet = if nurseryActive and owned > 0 then nil else Pets[owned + 1]
	for index = knownPets + 1, (if nurseryActive then knownPets else owned) do
		table.insert(hatchQueue, Pets[index])
		if index == 1 then
			roomView.welcomeNext = true
		end
	end
	knownPets = owned
	if trackedRare and Pets.isUnlocked(trackedRare, owned, mask) then
		trackedRare = nil
	end
	local nextRare = trackedRare
	for _, rare in ipairs(Pets.rares) do
		if not nurseryActive and bit32.band(newlyEarned, rare.trial.bit) ~= 0 then
			table.insert(hatchQueue, rare)
		elseif not nextRare and not Pets.isUnlocked(rare, owned, mask) then
			nextRare = rare
		end
	end
	local hatchPet = hatchQueue[1]
	local hatchName = if hatchPet then hatchPet.name else nil
	local budget = board:GetAttribute("FieldBudget") or 24
	local remaining = math.max(0, budget - drops)
	for index, cell in ipairs(segments) do
		cell.Visible = owned > 0 and index <= budget
		cell.Position = UDim2.new((index - 1) / budget, 1, .5, -3)
		cell.Size = UDim2.new(1 / budget, -2, 0, 6)
		cell.BackgroundColor3 = if index <= remaining then Art.Leaf else Art.Line
	end
	layoutDropMeter()
	dispenser:update(board:GetAttribute("ResetId"),drops,budget,owned > 0 and board:GetAttribute("Mode")=="Board")
	for _,cell in ipairs(segments)do cell.Visible=false end
	meterText.Visible=owned==0
	meterText.Text = if owned > 0 then string.format("%d/%d", remaining, budget) else string.format("Pip %d/%d", charge, nextPet and nextPet.charge or 6)
	eggGoal.Visible = not backdrop:GetAttribute("CompactLandscape") and not backdrop:GetAttribute("SideGoalLayout") and owned > 0 and shell.AbsoluteSize.Y >= 260
	eggGoalText.Text = string.format("MEADOW EGG\n%d/18 nectar", nurseryState and nurseryState.nectar or 0)
	rareGoal.Visible = false
	local rareProgress = 0
	if nextRare then
		local goal = nextRare.trial
		rareProgress = math.min(if goal == Trials.HighRoller then score
			elseif goal == Trials.Fivefold then peakChain else maxClears, goal.target)
		rareGoal.Text = string.format("%s%s\n%s %d/%d", if trackedRare then "★ " else "",
			nextRare.name, goal.readout, rareProgress, goal.target)
	else
		rareGoal.Text = string.format("Beat your best\n%d pts", best)
	end
	if nurseryActive and owned > 0 then
		local stage = board:GetAttribute("FieldStage") or 0
		local phase = board:GetAttribute("FieldPhase")
		rareGoal.Text = if phase == "Settling" then "QUEST · settling…"
			elseif stage == 0 then "QUEST 1/2\nII + II on LEFT"
			elseif stage == 1 then "QUEST 2/2\nII + II on RIGHT"
			else "QUEST ✓\nKeep pile low"
	end
	local mode = board:GetAttribute("Mode")
	for index, item in ipairs(fieldZones) do
		local stage = board:GetAttribute("FieldStage") or 0
		item.node.Visible = nurseryActive and owned > 0
		item.node.BackgroundTransparency = if stage == index - 1 then .88 else .97
		item.node.Target.Text = if stage>=index then "✓" elseif item.side==-1 then "LEFT" else "RIGHT"
		item.node.Target.Visible=item.node.AbsoluteSize.X>=36 or stage>=index
		item.edge.Transparency = if stage == index - 1 then .1 else .7
	end
	local showHatch = hatchPet ~= nil and mode == "Board"
	local over = mode == "Board" and board:GetAttribute("RoundOver") == true and not showHatch
	local wasVisible = modal.Visible
	local wasRecap = recap.frame.Visible
	modal.Visible = (over or showHatch) and not (isPickerOpen() or journal.shade.Visible or nurseryView:isOpen() or gameMenu.shade.Visible)
	if modal.Visible then
		clearPlayInputs()
		picker:close()
	end
	local lesson = firstHatchGuide:step(drops, merges, charge, owned, UserInputService:GetLastInputType(),
		Config.Tiers[nextTier()].mark, canPlay(), backdrop:GetAttribute("CompactInstruction")==true)
	local fieldCoaching = false
	firstHatchGuide:fieldStep(0, 1, false)
	local fieldActive = nurseryActive and owned > 0
	questHUD:update(board:GetAttribute("FieldStage") or 0,board:GetAttribute("FieldPhase"),fieldActive,backdrop:GetAttribute("CompactInstruction")==true)
	status.ClipsDescendants = true
	status.BackgroundTransparency = if lesson or fieldCoaching then 0.08 else 1
	status.TextColor3 = if lesson or fieldCoaching then Art.Silver else title.TextColor3
	Art.type(status,"Body",false)
	status.TextSize=if backdrop:GetAttribute("CompactInstruction") then 12 else 16
	status.TextWrapped=backdrop:GetAttribute("CompactInstruction")~=true
	if lesson and status.AbsoluteSize.Y<60 and TextService:GetTextSize(lesson,12,Enum.Font.Gotham,Vector2.new(1000,100)).X>status.AbsoluteSize.X-8 then
		local input=UserInputService:GetLastInputType()
		lesson=if input==Enum.UserInputType.Touch then "Drag, lift" elseif isGamepad(input) then "Aim then A" else "←→ Space"
	end
	status.Text = if fieldActive then "" elseif fieldCoaching then "" elseif lesson then lesson elseif trialNoticeUntil and os.clock() < trialNoticeUntil
		then (if status.AbsoluteSize.Y<60 then "Trial complete!" else trialNotice) else (if status.AbsoluteSize.Y<60 then "Quest +6 nectar" else "Win quest +6 nectar\nLow pile +2 bonus")
	pet.Visible = showHatch == true and not over
	hatchStage.Visible = pet.Visible
	hatchIndex.Visible = pet.Visible and not modal:GetAttribute("CompactDialog")
	modalTag.Text = if over then "ROUND RECAP  ·  BEST " .. best
		elseif hatchPet and hatchPet.trial then "RARE HATCH" else "POCKET HATCHERY"
	recap.frame.Visible = over
	if wasRecap ~= over then
		if layout then task.defer(layout) end
		modalTitle.Size = UDim2.new(1, 0, 0, if over then 22 else 35)
	end
	local runReceipt = RunReceipt.select(nurseryState, board:GetAttribute("RunSequence"), board:GetAttribute("RewardStatus"), over)
	if over then
		recap:update(score, peakChain, maxClears, if trackedRare then nil else nextPet, charge, nextRare, rareProgress, best)
		if nurseryActive and owned > 0 then
			recap:updateField({ sequence = board:GetAttribute("RunSequence"), success = board:GetAttribute("FieldSuccess"), reason = board:GetAttribute("FieldReason"),
				stage = board:GetAttribute("FieldFinalStage") or 0, status = board:GetAttribute("RewardStatus"),
				award = board:GetAttribute("NectarAward") or 0, daily = board:GetAttribute("DailyAward") or 0,
				balance = nurseryState and nurseryState.nectar or 0,
				reward = runReceipt, receiptPending = board:GetAttribute("RewardStatus") == "Saved" and not runReceipt,
				mastery = runReceipt and nurseryState.masteryDetails and nurseryState.masteryDetails[runReceipt.family],
				recipe = EggCatalog.ById[nurseryView.selected] or EggCatalog.ById.meadow })
		end
	end
	modalTitle.Text = if over then (if board:GetAttribute("NewBest") then "New personal best!" else "Tray full")
		else "You hatched " .. (hatchName or "") .. "!"
	if over and nurseryActive and owned > 0 then
		modalTitle.Text = recap.fieldHeading or "Quest unfinished"
		local reward = runReceipt
		if reward and (reward.promotedTo or 0) > 0 and (board:GetAttribute("MasteryAward") or 0) > 0 then
			modalTag.Text = "FAMILY PROMOTION · " .. ({ "I", "II", "III" })[reward.promotedTo]
			modalTitle.Text = (reward.family or "Pet") .. " · " .. ({ "Sprout", "Grove", "Bloom" })[reward.promotedTo]
		end
	end
	readout.Text = if owned > 0 then tostring(nurseryState and nurseryState.nectar or 0) else tostring(score)
	scoreCaption.Text = if owned > 0 then "NECTAR" else "SCORE"
	scoreCaption.Visible=owned==0;walletDrop.Visible=owned>0
	bestReadout.Text = if owned > 0 then "NECTAR · eggs cost 18+" else "BEST " .. best
	if gameMenu then gameMenu:update(nurseryState, board:GetAttribute("SelectedFamily"), board:GetAttribute("RunFamily"), score, peakChain, best, nurseryView.selected) end
	local rewardPending = over and nurseryActive and owned > 0 and board:GetAttribute("RewardStatus") ~= "Saved"
	modalAction.Text = if rewardPending then "Saving…" elseif over then "Try again" else "Meet " .. (hatchName or "")
	modalAction.Interactable = not rewardPending
	keepPlaying.Interactable = not rewardPending
	local showEggChoice = over and nurseryActive and owned > 0
	modalAction.Position = UDim2.new(if over and not showEggChoice then 0.09 else 0.05, 0, 1, -52)
	modalAction.Size = UDim2.new(if over and not showEggChoice then 0.82 else 0.43, 0, 0, 44)
	keepPlaying.Visible = not over or showEggChoice
	keepPlaying.Text = if showEggChoice then "Hatch eggs" else "Keep playing"
	if showEggChoice then
		local affordable=runReceipt~=nil and (nurseryState and nurseryState.nectar or 0)>=(EggCatalog.ById[nurseryView.selected] or EggCatalog.ById.meadow).cost
		modalAction.BackgroundColor3=if affordable then Art.Raised else Art.Leaf
		modalAction.TextColor3=if affordable then Art.Silver else Art.Ink
		keepPlaying.BackgroundColor3=if affordable then Art.Leaf else Art.Raised
		keepPlaying.TextColor3=if affordable then Art.Ink else Art.Silver
		local shallow=modal.Size.Y.Offset<300
		local footerH=math.max(44,modalAction.Size.Y.Offset,keepPlaying.Size.Y.Offset)
		local footerY=-(if shallow then 8 else 16)-footerH
		modalAction.Position,modalAction.Size=UDim2.new(0,12,1,footerY),UDim2.new(.5,-18,0,footerH)
		keepPlaying.Position,keepPlaying.Size=UDim2.new(.5,6,1,footerY),UDim2.new(.5,-18,0,footerH)
		Art.type(modalAction,"Action",shallow);Art.type(keepPlaying,"Action",shallow)
	end
	if modal.Visible and (not wasVisible or (over and not wasRecap)) and isGamepad(UserInputService:GetLastInputType()) then
		GuiService.SelectedObject = modalAction
	elseif not modal.Visible and GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(modal) then
		GuiService.SelectedObject = nil
	end
	rail.Interactable = canAim() and not isPickerOpen()
	action.Interactable = canPlay()
	dropCaption.Text = if board:GetAttribute("FieldPhase") == "Settling" then "SETTLE"
		elseif nurseryState and nurseryState.status ~= "Ready" then "WAIT"
		elseif board:GetAttribute("FieldReady") == false then "FALLING" else "DROP"
	local unlocked = owned > 0
	roomButton.Interactable = unlocked and not modal.Visible
	eggButton.Interactable = unlocked and not modal.Visible
	roomLip.Color = if unlocked then Palette.Primary else Palette.Rim
	roomCaption.TextTransparency = if unlocked then 0 else 0.35
	drawAim()
	if showHatch and not over and revealedPet ~= hatchName then
		revealedPet = hatchName
		local oldPortrait = pet:FindFirstChild("Portrait")
		if oldPortrait then
			oldPortrait:Destroy()
		end
		local portrait = Portrait.create(pet, hatchPet, 7, UDim2.fromScale(0.5, 0.5), 15)
		make("UIScale", "StageFit", { Scale = math.min(1, pet.Size.Y.Offset / 91) }, portrait)
		hatchIndex.Text = if hatchPet.trial then hatchPet.trial.name .. " complete"
			elseif hatchPet == Pets[1] then "Sprout Hollow is open!"
			else string.format("PET %02d / %02d", hatchPet.index, #Pets)
		local resetId = board:GetAttribute("ResetId")
		if reduceEffects() or pet.Size.Y.Offset < 70 then
			reveal:cancel()
			audio:play("hatch")
		else
			reveal:start(function()
				return board:GetAttribute("ResetId") == resetId and board:GetAttribute("Mode") == "Board"
					and hatchQueue[1] == hatchPet
			end, hatchPet.cue, hatchPet.color)
		end
	end
end

layout = function()
	clearPlayInputs()
	local screen=backdrop.AbsoluteSize
	local ratio=(Config.Width+.8)/(Config.Height+.8)
	local short=screen.X>=350 and screen.X>=screen.Y*1.2 and screen.Y<280
	local capSize=if short then 12 else 14
	local utilityW=math.ceil(TextService:GetTextSize("Lounge",capSize,Enum.Font.GothamBold,Vector2.new(1000,100)).X)+14
	local queueCaptionH=math.ceil(TextService:GetTextSize("Next",12,Enum.Font.Gotham,Vector2.new(1000,100)).Y)
	local markBounds=TextService:GetTextSize("III",12,Enum.Font.GothamBold,Vector2.new(1000,100))
	local markD=math.max(18,math.ceil(math.max(markBounds.X,markBounds.Y))+6)
	local lineH=queueCaptionH+4
	local walletH=math.ceil(TextService:GetTextSize("0",18,Enum.Font.GothamBold,Vector2.new(1000,100)).Y)+4
	local l=DeckLayout.resolve(screen,ratio,{utilityWidth=utilityW,queueHeight=math.max(lineH+markD+2,lineH*2+4),lineHeight=lineH,walletLineHeight=walletH,countWidth=TextService:GetTextSize("24/24",12,Enum.Font.Gotham,Vector2.new(1000,100)).X+4})
	backdrop:SetAttribute("CompactLandscape",l.short)
	backdrop:SetAttribute("CompactInstruction",l.short or l.dense or l.quest.h<60)
	backdrop:SetAttribute("SideGoalLayout",true)
	local function place(node,r)node.Position,node.Size=UDim2.fromOffset(r.x,r.y),UDim2.fromOffset(r.w,r.h)end
	place(shell,l.shell);place(bezel,l.bezel);place(viewport,l.tray);overlay.Position,overlay.Size=viewport.Position,viewport.Size
	shell.MicroTrim.Visible=l.lateral and l.left.w>=160
	local showEtching=not l.lateral or (l.left.w>=160 and Art.textWidth(title)+40<=l.left.w)
	for _,name in ipairs({"SproutLeaf","DropMark","ModelStamp"}) do
		local etching=shell:FindFirstChild(name)
		if etching then etching.Visible=showEtching end
	end
	local radius=if l.lateral then math.clamp(math.floor(l.shell.h*.075),18,32)else 23
	shell.ShellCurve.CornerRadius=UDim.new(0,radius)
	shell.Faceplate:FindFirstChildOfClass("UICorner").CornerRadius=UDim.new(0,radius-4)
	shell.MoldSeam:FindFirstChildOfClass("UICorner").CornerRadius=UDim.new(0,radius-5)
	place(rail,l.tray);rail.BackgroundTransparency=1;rail.ReadoutDivider.Visible=false
	bestReadout.Visible,nextReadout.Visible,mascot.Visible=false,false,false
	local nectarWallet=(board:GetAttribute("OwnedPets") or 0)>0
	Art.type(scoreCaption,"Supporting",l.short or l.dense or not l.lateral)
	local captionW=if nectarWallet then 26 else math.min(l.wallet.w*.6,Art.textWidth(scoreCaption))
	scoreCaption.Visible=not nectarWallet
	scoreCaption.Position=UDim2.fromOffset(l.wallet.x-l.tray.x,l.wallet.y-l.tray.y)
	scoreCaption.Size=UDim2.fromOffset(captionW,l.wallet.h)
	scoreCaption.BackgroundColor3,scoreCaption.BackgroundTransparency=Art.Ink,.05
	walletDrop.Visible=nectarWallet;place(walletDrop,{x=l.wallet.x+3,y=l.wallet.y+1,w=17,h=math.min(22,l.wallet.h-2)})
	readout.Position=scoreCaption.Position+UDim2.fromOffset(captionW,0)
	readout.Size=UDim2.fromOffset(l.wallet.w-captionW,l.wallet.h)
	readout.BackgroundColor3,readout.BackgroundTransparency=Art.Ink,.05
	Art.type(readout,if l.short or l.dense or not l.lateral then "Supporting" else "Action",l.short or l.dense or not l.lateral)
	readout.TextTruncate=Enum.TextTruncate.None
	place(queueHost,l.queue)
	local nextWidth=TextService:GetTextSize("Next",12,Enum.Font.Gotham,Vector2.new(1000,100)).X+8
	local verticalQueue=l.lateral and not l.inlineQueue and l.queue.w/2-4<nextWidth
	local inlineQueue=l.inlineQueue==true or verticalQueue or (not l.lateral and lineH+markD+2>l.queue.h)
	local combinedQueue=inlineQueue and not verticalQueue and l.queue.h<lineH*2+4 and TextService:GetTextSize("Next III",12,Enum.Font.Gotham,Vector2.new(1000,100)).X+6>l.queue.w/2-4
	queueHost:SetAttribute("InlineTiers",inlineQueue or combinedQueue)
	queueHost:SetAttribute("CombinedTiers",combinedQueue)
	for index,piece in ipairs(queuePieces)do
		local caption=piece.Parent.Caption
		if verticalQueue then
			piece.Parent.Position,piece.Parent.Size=UDim2.fromOffset(0,(index-1)*(lineH+4)),UDim2.new(1,0,0,lineH)
		elseif combinedQueue then
			piece.Parent.Position,piece.Parent.Size=UDim2.fromOffset(0,0),UDim2.fromScale(1,1)
		else piece.Parent.Position,piece.Parent.Size=UDim2.fromScale((index-1)*.5,0),UDim2.fromScale(.5,1) end
		caption.Visible=not combinedQueue or index==1
		Art.type(caption,"Supporting",l.short or l.dense or not l.lateral)
		local inset=caption:FindFirstChildOfClass("UIPadding");if inset then inset:Destroy() end
		local captionH=math.ceil(TextService:GetTextSize("Next",caption.TextSize,caption.Font,Vector2.new(1000,100)).Y)+4
		piece.Visible=not inlineQueue and not combinedQueue
		Art.type(piece.Mark,"Supporting",true);piece.Mark.Font=Enum.Font.GothamBold
		local markInset=piece.Mark:FindFirstChildOfClass("UIPadding");if markInset then markInset:Destroy() end
		local d=markD
		piece.Position,piece.Size=UDim2.new(.5,-d/2,0,captionH+2),UDim2.fromOffset(d,d)
		caption.Size=UDim2.new(1,-4,0,captionH)
		local droppingWidth=TextService:GetTextSize("Dropping",caption.TextSize,caption.Font,Vector2.new(1000,100)).X
		local word=if index==1 then (if l.queue.w/2-8<droppingWidth then "Now" else "Dropping") else "Next"
		caption:SetAttribute("QueueWord",word)
		caption.Text=if inlineQueue then (if index==1 then "Now " else "Next ")..piece.Mark.Text else word
		caption.TextColor3=if inlineQueue then piece.BackgroundColor3 else Art.Muted
	end
	if combinedQueue then queuePieces[1].Parent.Caption.Text="Now "..queuePieces[1].Mark.Text.."/Next "..queuePieces[2].Mark.Text;queuePieces[1].Parent.Caption.TextColor3=Art.Silver end
	place(status,l.quest);status.ClipsDescendants=true
	place(meter,l.meter);rareGoal.Visible,eggGoal.Visible=false,false
	meterText.Position,meterText.Size=UDim2.fromOffset(2,0),UDim2.new(1,-4,1,0)
	Art.type(meterText,"Body",false)
	meterText.TextSize=if l.short then 12 else 16
	meterText.TextStrokeTransparency=1
	place(hardware,l.shell)
	dpad.Position,dpad.Size=UDim2.fromOffset(l.dpad.x-l.shell.x,l.dpad.y-l.shell.y),UDim2.fromOffset(l.dpad.w,l.dpad.h)
	dpad.RockerWell.Size=UDim2.fromOffset(l.dpad.w+6,l.aimSize+7)
	leftAim.Size,rightAim.Size=UDim2.fromOffset(l.aimSize,l.aimSize),UDim2.fromOffset(l.aimSize,l.aimSize)
	rightAim.Position=UDim2.fromOffset(l.aimSize+6,8)
	action.Position,action.Size=UDim2.fromOffset(l.drop.x-l.shell.x,l.drop.y-l.shell.y),UDim2.fromOffset(l.dropSize,l.dropSize)
	action.TextSize=math.floor(l.dropSize*.5)
	hardware.DropWell.Position,hardware.DropWell.Size=action.Position+UDim2.fromOffset(-3,1),UDim2.fromOffset(l.dropSize+6,l.dropSize+5)
	Art.type(dropCaption,"Supporting",l.short)
	dropCaption.Font=Enum.Font.GothamBold
	dropCaption.Visible=not l.short
	local dropW=l.right.w-8
	local dropH=Art.textHeight(dropCaption,dropW,16)
	local above=l.drop.y-l.meter.y-l.meter.h>=dropH+8
	dropCaption.Position=UDim2.fromOffset(l.right.x-l.shell.x+4,l.drop.y-l.shell.y+(if above then -dropH-4 else l.dropSize+4))
	dropCaption.Size=UDim2.fromOffset(dropW,dropH)
	for index,button in ipairs({customizeButton,roomButton})do
		place(button,if index==1 then l.menu else l.lounge)
		button.KeyWell.Visible=false
		button.Cap.Position,button.Cap.Size=UDim2.new(.5,0,0,7),UDim2.new(1,-6,0,DeckLayout.Settings.UtilityCapHeight)
		local icon=button.Cap:FindFirstChild("CompactIcon")
		if not icon then
			icon=Art.frame(button.Cap,"CompactIcon",Art.Ink,UDim2.new(.5,-10,.5,-10),UDim2.fromOffset(20,20),button.Cap.ZIndex+2)
			icon.BackgroundTransparency=1
			if index==1 then
				for row=0,2 do Art.frame(icon,"MenuBar",Art.Silver,UDim2.fromOffset(2,3+row*6),UDim2.fromOffset(16,2),icon.ZIndex+1) end
			else
				local left=Art.frame(icon,"Roof",Art.Silver,UDim2.fromOffset(1,4),UDim2.fromOffset(11,2),icon.ZIndex+1);left.Rotation=-38
				local right=Art.frame(icon,"Roof",Art.Silver,UDim2.fromOffset(8,4),UDim2.fromOffset(11,2),icon.ZIndex+1);right.Rotation=38
				Art.frame(icon,"House",Art.Silver,UDim2.fromOffset(4,8),UDim2.fromOffset(12,10),icon.ZIndex+1)
				Art.frame(icon,"Door",Art.Raised,UDim2.fromOffset(9,12),UDim2.fromOffset(4,6),icon.ZIndex+2)
			end
		end
		icon.Visible=l.compactUtilities==true
		button:SetAttribute("AccessibleLabel",if index==1 then "Menu" else "Lounge")
		button.Cap.Caption.Text=if l.compactUtilities then "" elseif index==1 then "Menu"else"Lounge"
		button.Cap.Caption.TextSize=if l.short then 12 else 14
	end
	eggButton.Visible=false
	title.Visible=l.lateral and l.shell.h>=280 and Art.textWidth(title)<=l.left.w
	title.Position,title.Size=UDim2.fromOffset(l.left.x,l.shell.y+6),UDim2.fromOffset(l.left.w,20)
	title.TextSize=18
	local free=l.drop.y-(l.meter.y+l.meter.h)
	vents.Visible=l.lateral and free>80
	vents.Position=UDim2.fromOffset(l.right.x-l.shell.x+(l.right.w-57)/2,l.meter.y+l.meter.h-l.shell.y+18)
	hardware.MakerMark.Visible=false
	shell.Faceplate.AimSeat.Visible,shell.Faceplate.ActionSeat.Visible=false,false
	shell.Faceplate.AccentBands.Visible=false
	local stickerRoom=l.lateral and l.menu.y-(l.quest.y+l.quest.h)>=34
	backdrop:SetAttribute("StickerSlot",stickerRoom)
	deckSticker.Position,deckSticker.Size=UDim2.fromOffset(l.left.x+l.left.w/2-12,l.quest.y+l.quest.h+6),UDim2.fromOffset(24,24)
	Stickers.paint(deckSticker,previewStickerId)
	deckSticker.Visible=deckSticker.Visible and stickerRoom
	local zoneWidth=math.max(0,(Config.Width/2-(board:GetAttribute("FieldZoneBound") or 2.6))/(Config.Width+.8))
	for _,item in ipairs(fieldZones)do
		item.node.Position=UDim2.fromScale(if item.side==-1 then .027 else 1-.027-zoneWidth,.025)
		item.node.Size=UDim2.fromScale(zoneWidth,.95)
	end
	modal.Position=UDim2.fromScale(.5,.5)
	local fieldRecap=recap.frame.Visible and (board:GetAttribute("OwnedPets") or 0)>0
	local dialogHeight=if fieldRecap then math.min(500,math.max(1,screen.Y-16)) else math.min(300,math.max(1,screen.Y-32))
	modal:SetAttribute("CompactDialog",dialogHeight<220)
	modal.Size=UDim2.fromOffset(math.min(if fieldRecap then 600 else 440,screen.X-(if fieldRecap then 16 else 32)),dialogHeight)
	if fieldRecap then
		local compact=dialogHeight<300
		modalTag.Visible=not compact
		Art.type(modalTitle,"Heading",compact)
		local titleH=Art.textHeight(modalTitle,modal.Size.X.Offset-24,if compact then 28 else 36)
		local titleY=2
		if not compact then
			Art.type(modalTag,"Supporting",true)
			local tagH=Art.textHeight(modalTag,modal.Size.X.Offset-24,18)
			modalTag.Size=UDim2.new(1,-24,0,tagH);titleY=tagH+9
		end
		modalTitle.Position,modalTitle.Size=UDim2.fromOffset(12,titleY),UDim2.new(1,-24,0,titleH)
		Art.type(modalAction,"Action",compact);Art.type(keepPlaying,"Action",compact)
		local bw=(modal.Size.X.Offset-36)/2
		local footerH=math.max(Art.actionHeight(modalAction,bw),Art.actionHeight(keepPlaying,bw))
		local bottomMargin=if compact then 8 else 16
		modalAction.Position,modalAction.Size=UDim2.new(0,12,1,-bottomMargin-footerH),UDim2.new(.5,-18,0,footerH)
		keepPlaying.Position,keepPlaying.Size=UDim2.new(.5,6,1,-bottomMargin-footerH),UDim2.new(.5,-18,0,footerH)
		recap.headerInset=titleY+titleH+8
		recap.footerInset=footerH+bottomMargin+8

	else
		modalTag.Visible=true
		modalTitle.Position=UDim2.fromOffset(0,18)
	end
	if recap.frame.Visible and (board:GetAttribute("OwnedPets") or 0)>0 then recap:layoutField(dialogHeight)end
	local stageHeight=math.max(24,dialogHeight-110-(if dialogHeight<220 then 0 else 18))
	hatchStage.Size=UDim2.new(1,-24,0,stageHeight);hatchIndex.Position=UDim2.fromOffset(12,55+stageHeight)
	hatchIndex.Visible=pet.Visible and dialogHeight>=220
	pet.Position=UDim2.new(.5,0,0,55+stageHeight/2);pet.Size=UDim2.fromOffset(math.min(88,stageHeight-4),math.min(88,stageHeight-4))
	local portrait=pet:FindFirstChild("Portrait");if portrait then portrait.StageFit.Scale=math.min(1,pet.Size.Y.Offset/91)end
	local distance=(Config.Height+.8)/(2*math.tan(math.rad(trayCamera.FieldOfView/2)))
	trayCamera.CFrame=CFrame.lookAt(Vector3.new(0,Config.Height/2,distance),Vector3.new(0,Config.Height/2,0))
end

local function aimFromScreen(x)
	local center = viewport.AbsolutePosition.X + viewport.AbsoluteSize.X / 2
	local span = viewport.AbsoluteSize.X * (Config.Width / 2 - Config.Tiers[nextTier()].radius) / (Config.Width + 0.8)
	aim = math.clamp(0.5 + (x - center) / math.max(1, 2 * span), 0, 1)
	drawAim()
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

local function startAim(key, direction)
	if canAim() and not isPickerOpen() and not drag and not heldAim[key] then
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

local function recapOwnsInput()
	return PresentationPolicy.ownsRecap({modal=modal.Visible,recap=recap.frame.Visible,busy=roomView.busy,
		overlay=isPickerOpen() or journal.shade.Visible or nurseryView:isOpen() or gameMenu.shade.Visible,
		coreMenu=GuiService.MenuIsOpen})
end

local function requestRetry()
	cancelHatchNavigation()
	if recapOwnsInput() and not UserInputService:GetFocusedTextBox() then
		request:FireServer("reset")
	end
end

local function handleControl(name, state, input)
	local key = input.KeyCode
	if state == Enum.UserInputState.Cancel then
		table.clear(heldAim)
	elseif state == Enum.UserInputState.End then
		heldAim[key] = nil
	end
	local gamepad = isGamepad(input.UserInputType)
	if key == Enum.KeyCode.ButtonA and recapOwnsInput() then
		if GuiService.SelectedObject and GuiService.SelectedObject.Visible and GuiService.SelectedObject:IsDescendantOf(modal) then return Enum.ContextActionResult.Pass end
		if state == Enum.UserInputState.Begin then
			requestRetry()
		end
		return Enum.ContextActionResult.Sink
	end
	if not canAim() or isPickerOpen() or roomView.busy or GuiService.MenuIsOpen
		or UserInputService:GetFocusedTextBox() or (gamepad and GuiService.SelectedObject) then
		return Enum.ContextActionResult.Pass
	end
	if state == Enum.UserInputState.Begin then
		if name == "EggDropDrop" then
			dropEgg()
		elseif name == "EggDropCustomize" then
			openMenu()
		else
			startAim(key, if name == "EggDropLeft" then -1 else 1)
		end
	end
	return Enum.ContextActionResult.Sink
end

local priority = Enum.ContextActionPriority.High.Value
-- Keep footer navigation explicit while up/down reads a long saved receipt.
ContextActionService:BindActionAtPriority("EggDropReceiptScroll", function(_, state, input)
	if not recapOwnsInput() or not recap.hasReceipt
		or UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
	if state == Enum.UserInputState.Begin then
		local key = input.KeyCode
		if key == Enum.KeyCode.DPadLeft or key == Enum.KeyCode.DPadRight then
			GuiService.SelectedObject = if key == Enum.KeyCode.DPadRight and keepPlaying.Visible and keepPlaying.Interactable
				then keepPlaying else modalAction
		else
			recap:scrollReceipt(if key == Enum.KeyCode.DPadUp or key == Enum.KeyCode.PageUp then -1 else 1)
		end
	end
	return Enum.ContextActionResult.Sink
end, false, priority, Enum.KeyCode.DPadUp, Enum.KeyCode.DPadDown, Enum.KeyCode.DPadLeft, Enum.KeyCode.DPadRight,
	Enum.KeyCode.PageUp, Enum.KeyCode.PageDown)
ContextActionService:BindActionAtPriority("EggDropLeft", handleControl, false, priority,
	Enum.KeyCode.Left, Enum.KeyCode.A, Enum.KeyCode.DPadLeft)
ContextActionService:BindActionAtPriority("EggDropRight", handleControl, false, priority,
	Enum.KeyCode.Right, Enum.KeyCode.D, Enum.KeyCode.DPadRight)
ContextActionService:BindActionAtPriority("EggDropDrop", handleControl, false, priority,
	Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
ContextActionService:BindActionAtPriority("EggDropPickerBack", function(_, state)
	if not PresentationPolicy.canSheetBack({coreMenu=GuiService.MenuIsOpen,textCapture=UserInputService:GetFocusedTextBox()~=nil,busy=roomView.busy}) then return Enum.ContextActionResult.Pass end
	if gameMenu and gameMenu.shade.Visible then
		if state == Enum.UserInputState.Begin then closeMenu() end
		return Enum.ContextActionResult.Sink
	end
	if nurseryView:isOpen() then
		if state == Enum.UserInputState.Begin then nurseryView:close() end
		return Enum.ContextActionResult.Sink
	end
	if journal.shade.Visible then
		if state == Enum.UserInputState.Begin then
			journal:close()
		end
		return Enum.ContextActionResult.Sink
	end
	if isPickerOpen() then
		if state == Enum.UserInputState.Begin then
			picker:close()
		end
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end, false, priority, Enum.KeyCode.ButtonB)
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
GuiService.MenuOpened:Connect(updateHud)
GuiService.MenuClosed:Connect(updateHud)
picker.shade:GetPropertyChangedSignal("Visible"):Connect(function()
	task.defer(updateHud)
end)
UserInputService.LastInputTypeChanged:Connect(function()
	if (board:GetAttribute("OwnedPets") or 0) == 0 then
		updateHud()
	end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.Return then
		requestRetry()
	end
end)
modalAction.Activated:Connect(function()
	if roomView.busy then
		return
	end
	if recap.frame.Visible then
		requestRetry()
	elseif hatchQueue[1] then
		roomView:requestSwitch(function()
			if hatchQueue[1] then
				roomView:choosePet(hatchQueue[1])
				request:FireServer("mode", "Room")
			end
		end)
	end
end)
keepPlaying.Activated:Connect(function()
	if roomView.busy then
		return
	end
	if recap.frame.Visible then visitEggs(); return end
	table.remove(hatchQueue, 1)
	reveal:cancel()
	audio:play("menu")
	updateHud()
end)
pet.Activated:Connect(function()
	if roomView.busy then
		return
	end
	local hatchPet = hatchQueue[1]
	if hatchPet then
		audio:play(hatchPet.cue)
	end
	if not reduceEffects() then
		pet.Rotation = -9
		TweenService:Create(pet, TweenInfo.new(0.24, Enum.EasingStyle.Back), { Rotation = 0 }):Play()
	end
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
			if not reduceEffects() then
				gel:impact(impact[2], impact[3])
			end
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

feedback.OnClientEvent:Connect(function(position, tier, chain, first, second, id, cleared)
	if board:GetAttribute("Mode") ~= "Board" then
		return
	end
	local now = os.clock()
	mergeBurst = if now - lastMerge < 0.08 then math.min(mergeBurst + 1, 2) else 0
	lastMerge = now
	local pitch = 0.98 + (id or 0) % 5 * 0.01
	audio:play(if tier == 2 then "merge_bubble" else "merge_jelly", pitch, 0.56 * 0.68 ^ mergeBurst)
	if (chain > 1 or cleared) and now - lastChainAccent >= 0.18 then
		lastChainAccent = now
		audio:play("merge_chain", 1 + math.min(chain - 2, 4) * 0.035, 0.34)
	end
	local reduced = reduceEffects()
	local pixelMerge = lcdEnabled() and not cleared and not reduced
	if pixelMerge then
		if #pixelMerges >= 6 then
			table.remove(pixelMerges, 1)
		end
		table.insert(pixelMerges, {
			first = pixelPoint(first), second = pixelPoint(second), point = pixelPoint(position),
			radius = Config.Tiers[tier - 1].radius * JellyLCD.Width / (Config.Width + 0.8),
			resultRadius = Config.Tiers[tier].radius * JellyLCD.Width / (Config.Width + 0.8),
			color = Config.Tiers[tier].color, start = now, id = id,
		})
	end
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
	if not reduced then
		if not pixelMerge then
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
		end
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
	end
	local pop = label("TextLabel", "MergePop", if cleared then "MAX CLEAR +100" elseif chain > 1 then "CHAIN x" .. chain else "POP!", effects)
	pop.TextColor3 = color
	pop.TextStrokeColor3 = Palette.Ink
	pop.TextStrokeTransparency = 0.05
	pop.TextSize = if chain > 1 then 23 else 18
	pop.AnchorPoint = Vector2.new(0.5, 0.5)
	pop.Size = UDim2.fromOffset(120, 27)
	pop.Position = UDim2.fromOffset(point.X, point.Y)
	pop.ZIndex = 5
	if reduced then
		task.delay(0.55, function()
			pop:Destroy()
		end)
		return
	end
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

local function applySound(preview)
	local sound = board:GetAttribute("SoundLevel") or Settings.DefaultSound
	audio:setVolume(Settings.Sound[sound])
	if preview and isPickerOpen() then
		audio:play("menu")
	end
end
applySound(false)
board:GetAttributeChangedSignal("SoundLevel"):Connect(function() applySound(true) end)
local function refreshMotion()
	if reduceEffects() then
		reveal:cancel()
		effects:ClearAllChildren()
		table.clear(pixelMerges)
	end
	if isPickerOpen() then
		updateClub()
	end
end
board:GetAttributeChangedSignal("ReducedEffects"):Connect(refreshMotion)
GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(refreshMotion)

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
	journal:close()
	local mode = board:GetAttribute("Mode")
	if nurseryView then nurseryView:close() end
	if closeMenu then closeMenu() end
	if mode == "Room" then
		if hatchQueue[1] then
			table.remove(hatchQueue, 1)
		end
		reveal:cancel()
		effects:ClearAllChildren()
		table.clear(pixelMerges)
	end
	roomView:setMode(mode)
end)
board:GetAttributeChangedSignal("ResetId"):Connect(function()
	if recap.feedback then recap.feedback:cancel() end
	clearPlayInputs()
	reveal:cancel()
	effects:ClearAllChildren()
	table.clear(pixelMerges)
	audio:stop()
	audio:play("retry")
	lastPlop = -math.huge
	lastMerge = -math.huge
	lastChainAccent = -math.huge
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
		audio:play(if board:GetAttribute("FieldSuccess") then "charge" else "overflow")
	end
end)
backdrop:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
Art.watchTextPreference(backdrop,function()return backdrop.Visible end,function()layout();updateHud()end)
backdrop:GetPropertyChangedSignal("Visible"):Connect(function()if backdrop.Visible and backdrop:GetAttribute("TextPreferenceDirty") then layout();updateHud();backdrop:SetAttribute("TextPreferenceDirty",false)end end)
status:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() task.defer(updateHud) end)
viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(drawAim)
RunService.RenderStepped:Connect(function(dt)
	if hatchNavigation and hatchNavigation.active then
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.MoveDirection.Magnitude > .05 then cancelHatchNavigation() end
	end
	-- Transition completion changes local busy state without a replicated attribute.
	-- Re-evaluate the button so returning from the lounge cannot leave A disabled.
	action.Interactable = canPlay() and not board:GetAttribute("RoundOver")
	firstHatchGuide:fieldStep(0, 1, false)
	rail.Interactable = canAim() and not isPickerOpen() and not roomView.busy
	local recipe = EggCatalog.ById[nurseryView.selected] or EggCatalog.ById.meadow
	eggGoalText.Text = string.format("%s\n%d/%d nectar", recipe.name, nurseryState and nurseryState.nectar or 0, recipe.cost)
	if canAim() and not isPickerOpen() and not drag and not UserInputService:GetFocusedTextBox() then
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
	if not backdrop.Visible then
		return
	end
	local now = os.clock()
	local pressure = board:GetAttribute("OverflowPressure") or 0
	pressureTrack.Visible = pressure > 0
	pressureText.Visible = pressure > 0
	pressureFill.Size = UDim2.fromScale(1, math.clamp(pressure, 0, 1))
	overflowLine.BackgroundTransparency = if pressure > 0 then .05 else .55
	local reduced = reduceEffects()
	local mood = if reduced then "idle" elseif now - lastMerge < 0.24 then "happy" elseif now % 3.8 < 0.13 then "blink" else "idle"
	if mood ~= mascotMood then
		mascotMood = mood
		for _, eye in ipairs(mascotEyes) do
			eye.BackgroundColor3 = if mood == "blink" then mascotInk
				elseif mood == "happy" then Art.Amber else Art.Ink
		end
	end
	local closest
	local distance = math.huge
	local tier = nextTier()
	local guide = (board:GetAttribute("OwnedPets") or 0) == 0 and canPlay()
	local aimX = Config.aimX(aim, tier)
	local drawLCD = false
	local useLCD = lcdEnabled() and viewport.AbsoluteSize.X > 1
	if useLCD then
		lcdElapsed += dt
		drawLCD = lcdElapsed >= lcdStep
		if drawLCD then
			lcdElapsed %= lcdStep
			lcd:beginFrame()
			for index = #pixelMerges, 1, -1 do
				if now - pixelMerges[index].start >= JellyLCD.MergeDuration then
					table.remove(pixelMerges, index)
				end
			end
			local radius = Config.Tiers[tier].radius * JellyLCD.Width / (Config.Width + 0.8)
			local color = Config.Tiers[tier].color:Lerp(Palette.Tray, 0.2)
			local center = pixelPoint(Vector2.new(aimX, Config.SpawnY))
			lcd:drawGuide(center)
			lcd:draw(center, radius, radius, 0, color, 0)
		end
	elseif lcd then
		lcd.label.Visible = false
		lcdElapsed = lcdStep
	end
	for source, view in pairs(eggViews) do
		local position, widthScale, heightScale, angle, ripple = view.gel:render(source.Position, dt, now, project, not useLCD, reduced)
		local point = project(Vector2.new(position.X, position.Y))
		if drawLCD or not useLCD then
			view.mark.Position = UDim2.fromOffset(point.X, point.Y)
		end
		if drawLCD and widthScale then
			local center = pixelPoint(position)
			local inMerge = false
			for _, merge in ipairs(pixelMerges) do
				if merge.id == view.id then
					merge.point = center
					inMerge = true
				end
			end
			if not inMerge then
				local radius = source.Size.X / 2 * JellyLCD.Width / (Config.Width + 0.8)
				lcd:draw(center, radius * widthScale, radius * heightScale, angle, source.Color, ripple)
			end
		end
		if guide and source:GetAttribute("Tier") == tier and position.Y < Config.OverflowY then
			local delta = math.abs(position.X - aimX)
			if delta < distance then
				distance = delta
				closest = point
			end
		end
	end
	if drawLCD then
		for _, merge in ipairs(pixelMerges) do
			lcd:merge(merge.first, merge.second, merge.point, merge.radius, merge.resultRadius,
				merge.color, now - merge.start)
		end
		if lcd:finishFrame() then
			lcd.label.Visible = true
		else
			lcd:destroy()
			lcd = nil
		end
	end
	local pixelVisible = lcd ~= nil and lcd.label.Visible
	sprites.Visible = not pixelVisible
	track.Visible = not pixelVisible
	overflowLine.Visible = true
	ghost.BackgroundTransparency = if pixelVisible then 1 else 0
	targetRing.Visible = closest ~= nil
	if closest then
		local diameter = Config.Tiers[tier].radius * 2 * viewport.AbsoluteSize.X / (Config.Width + 0.8) + 7
		targetRing.Position = UDim2.fromOffset(closest.X, closest.Y)
		targetRing.Size = UDim2.fromOffset(diameter, diameter)
	end
end)
layout()
updateHud()
roomView:startPresentation(board:GetAttribute("Mode"))
