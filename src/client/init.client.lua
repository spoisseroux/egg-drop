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
-- Warm the pet meshes and textures in the background (QA 2026-11-12: the first hatch
-- reveal drew the Bear as stretched boxes, then untextured, while they downloaded).
task.delay(3,function()
	local assets={}
	for _,name in ipairs({"PetAssets","PetMaterials","PetMaterialsTwoTone","PetCharmAssets"})do
		local folder=ReplicatedStorage:FindFirstChild(name)
		if folder then table.insert(assets,folder)end
	end
	pcall(function()game:GetService("ContentProvider"):PreloadAsync(assets)end)
end)

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
local LoungeStations = require(script.LoungeStations)
local HandheldScreens = require(script.HandheldScreens)
local HatchReveal = require(script.HatchReveal)
local DeckScreen = require(script.DeckScreen)
local FirstHatchGuide = require(script.FirstHatchGuide)
local Art = require(script.DeckArt)
local DeckLayout = require(script.DeckLayout)
local Stars=require(script.StarText)
local clientUI={HueIntent=require(script.HueIntent),HueEggView=require(script.HueEggView),PresentationPolicy=require(script.PresentationPolicy),SaveNotice=require(script.SaveNotice),ControllerFocus=require(script.ControllerFocus),AppearanceIntent=require(script.AppearanceIntent),FieldQuestText=require(script.FieldQuestText),fieldCache={},PetContactIntent=require(script.PetContactIntent)}
-- Ball themes + faces (batch 2026-11-13 R1): the equipped theme comes from the nursery snapshot.
clientUI.BallThemes=require(game:GetService("ReplicatedStorage").Shared.BallThemes)
clientUI.ballFaces=require(script.BallFaces).new();clientUI.faceList={};clientUI.heldFace={}
function clientUI.isHueOpen()return(clientUI.hueView~=nil and clientUI.hueView:isOpen())or(clientUI.hub~=nil and clientUI.hub:isOpen())end
local DropDispenser = require(script.DropDispenser)
local BoardQuestHUD = require(script.BoardQuestHUD)
local HollowClock = require(script.HollowClock)
local NurseryView = require(script.EggHatchView)
local HatchNavigation = require(script.HatchNavigation)
local RunReceipt = require(script.RunReceipt)
local Portrait = require(script.PetPortrait)
local DeckMenu = require(script.DeckMenu)
local audio = Audio.new()
-- W2 feel alive: garden ambience + Pocket Deck round music (before RoomView, whose coos use it).
clientUI.ambient=require(script.AmbientAudio).new(audio)
clientUI.JellyPalette=require(ReplicatedStorage.Shared.JellyPalette)
clientUI.ItemCarousel=require(script.ItemCarousel);clientUI.RoundItems=require(ReplicatedStorage.Shared.RoundItems)
clientUI.Pico8=require(ReplicatedStorage.Shared.Pico8)
clientUI.uiSequence=0
clientUI.accepted=function(kind)
 if GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox()then return end
 clientUI.uiSequence+=1;audio:ui(kind,clientUI.uiSequence)
end
clientUI.clock=HollowClock.start()
clientUI.worldMotion=require(script.WorldMotion).start()
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
		Text = content, Font = Art.Font.Body, TextSize = 15,
		TextColor3 = if background then Palette.Ink else Palette.Paper,
		BackgroundColor3 = background or Palette.Panel, BackgroundTransparency = background and 0 or 1,
		BorderSizePixel = 0,
	}, parent)
end

local gui = make("ScreenGui", "EggDrop", {
	ResetOnSpawn = false, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, DisplayOrder = 10,
}, player:WaitForChild("PlayerGui"))
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
clientUI.deviceRoot=make("Frame","DevicePresentation",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1)},backdrop)
local shell = make("Frame", "CartridgeShell", {
	BackgroundColor3 = Palette.Shell, BorderSizePixel = 0,
}, clientUI.deviceRoot)
make("UICorner", "ShellCurve", { CornerRadius = UDim.new(0, 18) }, shell)
local rim = make("UIStroke", "ShellRim", { Color = Palette.Rim, Thickness = 3 }, shell)
do
	local plate = Art.frame(shell, "Faceplate", Palette.Shell, UDim2.fromOffset(5, 4), UDim2.new(1, -10, 1, -14))
	Art.corner(plate, 15)
	Art.stroke(plate, Art.Ink, 0.6)
	Art.shade(plate, 1, 0.84)
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
local bezel = make("Frame", "LCDBezel", { BackgroundColor3 = Art.Ink, BorderSizePixel = 0 }, clientUI.deviceRoot)
make("UICorner", "LensCurve", { CornerRadius = UDim.new(0, 12) }, bezel)
local bezelRim = make("UIStroke", "InsetTrim", { Color = Palette.Rim, Thickness = 2 }, bezel)
Art.deck(backing, shell, bezel)
-- A viewport renders the board inside the HUD, using the same projection on desktop and phone.
local viewport = make("ViewportFrame", "Tray", {
	BackgroundColor3 = Art.LCD, BorderSizePixel = 0,
	Ambient = Color3.fromRGB(180, 175, 190), LightColor = Color3.fromRGB(255, 239, 217),
	LightDirection = Vector3.new(-1, -2, -3),
}, clientUI.deviceRoot)
local scene = make("WorldModel", "Scene", {}, viewport)
local trayCamera = make("Camera", "TrayCamera", {
	FieldOfView = 35,
}, viewport)
viewport.CurrentCamera = trayCamera
local overlay = make("Frame", "TrayOverlay", {
	BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 2,
}, clientUI.deviceRoot)
local effects = make("Frame", "MergeEffects", {
	BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4,
}, overlay)
local sprites = make("Frame", "Sprites", {
	BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3,
}, overlay)
Sprite.texture(sprites)
local fieldZones = {}
local zoneLayer=Art.frame(overlay,"TargetRegions",Art.Ink,UDim2.fromScale(0,0),UDim2.fromScale(1,1),2)
zoneLayer.BackgroundTransparency=1;zoneLayer.ClipsDescendants=true
for index,side in ipairs({-1,1})do
	local tint=Color3.fromHex("#466853")
	local zone=Art.frame(zoneLayer,if side==-1 then "LeftThreshold"else"RightThreshold",tint,UDim2.fromScale(0,0),UDim2.new(0,2,1,-8),2)
	zone.BackgroundTransparency=.35;zone.Active=false;zone.Selectable=false
	fieldZones[index]={node=zone,side=side}
end

clientUI.centerZone=Art.frame(zoneLayer,"CenterGoalRegion",Color3.fromHex("#466853"),UDim2.fromScale(.4,.025),UDim2.fromScale(.2,.95),2)
clientUI.centerZone.BackgroundTransparency=1;clientUI.centerZone.Active=false;clientUI.centerZone.Selectable=false;clientUI.centerZone.Visible=false
for _,side in ipairs({"Min","Max"})do
 local edge=Art.frame(clientUI.centerZone,side,Color3.fromHex("#466853"),UDim2.fromScale(if side=="Min"then 0 else 1,0),UDim2.new(0,2,1,0),2)
 edge.AnchorPoint=Vector2.new(.5,0);edge.BackgroundTransparency=.35;edge.Active=false;edge.Selectable=false
end
Art.lcdCorners(overlay,bezel.BackgroundColor3)
local lcd = JellyLCD.new(overlay)
-- The chosen deck background, drawn in the board well at 6% (UI-SPEC-REDESIGN-MENUS 5).
Art.boardPattern(overlay)
local lcdStep = 1 / 30
local lcdElapsed = lcdStep
local pixelMerges = {}
local rendererPresentation={visible=false,connections={}}
rendererPresentation.jolt=require(script.DeckMergeJolt).new({clientUI.deviceRoot})
rendererPresentation.fx=require(script.FieldEffects).new(effects)
rendererPresentation.fx:observeDrop(board:GetAttribute("ResetId"),board:GetAttribute("Drops")or 0)
rendererPresentation.setFieldOwner=function(visible,serial,reduced)
 rendererPresentation.jolt:setOwner(visible,serial,reduced)
 if rendererPresentation.fx:setOwner(visible,serial,reduced)then audio:stopField();if rendererPresentation.dispenser then rendererPresentation.dispenser:cancel()end end
end

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

local title = label("TextLabel", "Title", "", clientUI.deviceRoot)
title.Font = Art.Font.Heading
title.TextSize = 17
title.TextColor3 = Art.Ink
title.BackgroundTransparency=1
clientUI.wordmark=Art.wordmark(clientUI.deviceRoot,3)
Art.text(shell, "ModelStamp", "PD·01", UDim2.new(1, -68, 0, 7), UDim2.fromOffset(40, 20), Art.Ink, 10)
local power = make("Frame", "PowerLight", {
	Position = UDim2.new(1, -20, 0, 13), Size = UDim2.fromOffset(8, 8),
	BackgroundColor3 = Art.Cyan, BorderSizePixel = 0,
}, shell)
make("UICorner", "Round", { CornerRadius = UDim.new(0.5, 0) }, power)
Art.stroke(power, Art.Cyan, 0.65, 3)
shell.Faceplate.ClipsDescendants=true
local rail = label("TextButton", "AimRail", "", clientUI.deviceRoot, Art.Ink)
rail.AutoButtonColor = false
rail.Font = Art.Font.Counter
rail.TextColor3 = Palette.Paper
rail.Selectable = false
make("UICorner", "RailCurve", { CornerRadius = UDim.new(0, 9) }, rail)
-- An early passive child of the transparent rail draws above casing, below its data.
local walletFace=Art.instrument(Art.frame(rail,"WalletInstrument",Art.Ink,UDim2.fromOffset(0,0),UDim2.fromOffset(180,32),rail.ZIndex))
Art.frame(rail, "ReadoutDivider", Art.Line, UDim2.new(0, 6, 1, -2), UDim2.new(1, -12, 0, 1))
local readout = label("TextLabel", "GameReadout", "EGG DROP", rail)
readout.Font = Art.Font.Counter
readout:SetAttribute("TypeRole","Counter")
make("UITextSizeConstraint", "CountSize", { MinTextSize = 9, MaxTextSize = 19 }, readout)
readout.TextColor3 = Art.Silver
readout.TextXAlignment = Enum.TextXAlignment.Left
local queueHost=Art.frame(clientUI.deviceRoot,"PieceQueue",Art.Ink,UDim2.fromOffset(0,0),UDim2.fromOffset(180,64),4)
Art.instrument(queueHost)
local queuePieces={}
for index,name in ipairs({"Dropping","Next"})do
	local slot=Art.frame(queueHost,name,Art.Ink,UDim2.fromScale((index-1)*.5,0),UDim2.fromScale(.5,1),5)
	slot.BackgroundTransparency=1
	local caption=Art.text(slot,"Caption",name,UDim2.fromOffset(2,0),UDim2.new(1,-4,0,14),Art.Muted,11);Art.fitText(caption,12,8,0)
	local ball=Art.frame(slot,"Piece",Config.Tiers[1].color,UDim2.new(.5,-14,0,19),UDim2.fromOffset(28,28),6)
	Art.corner(ball,30);Art.shade(ball,1,.7)
	local mark=Art.text(ball,"Mark","I",UDim2.fromScale(0,0),UDim2.fromScale(1,1),Art.Ink,12,Art.Font.Counter);mark:SetAttribute("TypeRole","Counter");Art.fitText(mark,12,8,0);Art.jellyPreview(ball,1,mark)
	queuePieces[index]=ball
end
local scoreCaption = Art.text(rail, "ScoreCaption", "SCORE", UDim2.new(0.5, -22, 0, 7),
	UDim2.fromOffset(40, 12), Art.Muted, 10)
local walletDrop=require(script.EggArt).nectar(clientUI.deviceRoot,UDim2.fromOffset(0,0),UDim2.fromOffset(18,20),4)
readout.ZIndex,scoreCaption.ZIndex=4,4
local instrumentLayout,walletLayoutKey,walletCaptionKey,walletCaptionWidth,walletGeometry
local function layoutWallet(l)
	if not l then return end
	local r=l.wallet;local nectar=(board:GetAttribute("OwnedPets")or 0)>0
	local captionKey=scoreCaption.Text..scoreCaption.TextSize..scoreCaption.Font.Name..GuiService.PreferredTextSize.Name
	if walletCaptionKey~=captionKey then walletCaptionKey=captionKey;walletCaptionWidth=Art.textWidth(scoreCaption)end
	local key=table.concat({readout.Text,r.x,r.y,r.w,r.h,tostring(nectar),tostring(l.short),tostring(l.dense),tostring(l.lateral),GuiService.PreferredTextSize.Name},"|")
	if walletLayoutKey~=key then
		local pad=if l.short or l.dense then 3 else 7
		local glyphW=if nectar then 20 else math.min(r.w*.55,walletCaptionWidth)
		local gap,faceW=3,r.w
		Art.type(readout,"Counter",l.short or l.dense or not l.lateral);if l.roomy then readout.TextSize=20 end
		local function digitsWidth()return math.ceil(TextService:GetTextSize(readout.Text,readout.TextSize,readout.Font,Vector2.new(10000,10000)).X)+2 end
		local digits=digitsWidth()
		if digits>faceW-pad*2-glyphW-gap then Art.type(readout,"Counter",true);digits=digitsWidth()end
		if digits>faceW-pad*2-glyphW-gap then
			pad,glyphW,gap=2,if nectar then 10 else 0,if nectar then 2 else 0
			local maximum=if l.dense then l.drop.x-r.x-2 elseif l.lateral then l.bezel.x-r.x-2 else l.queue.x-r.x-4
			faceW=math.max(r.w,math.min(maximum,digits+glyphW+gap+pad*2))
			if digits>faceW-pad*2-glyphW-gap then glyphW,gap=0,0 end
		end
		walletGeometry={pad=pad,glyphW=glyphW,gap=gap,w=faceW}
		readout.TextWrapped=false;walletLayoutKey=key
	end
	local g=walletGeometry
	walletFace.Position,walletFace.Size=UDim2.fromOffset(r.x-l.tray.x,r.y-l.tray.y),UDim2.fromOffset(g.w,r.h)
	local visual=l.walletVisual or {};visual.x,visual.y,visual.w,visual.h=r.x,r.y,g.w,r.h;l.walletVisual=visual
	local iconW=if g.glyphW>=20 then 17 else g.glyphW
	local iconH=if g.glyphW>=20 then 20 else 12
	walletDrop.Visible=nectar and iconW>0
	walletDrop.Position,walletDrop.Size=UDim2.fromOffset(r.x+g.pad,r.y+(r.h-iconH)/2),UDim2.fromOffset(iconW,iconH)
	scoreCaption.Visible=not nectar and g.glyphW>0
	scoreCaption.Position,scoreCaption.Size=UDim2.fromOffset(r.x-l.tray.x+g.pad,r.y-l.tray.y),UDim2.fromOffset(g.glyphW,r.h)
	scoreCaption.BackgroundTransparency=1
	readout.Position,readout.Size=UDim2.fromOffset(r.x-l.tray.x+g.pad+g.glyphW+g.gap,r.y-l.tray.y),UDim2.fromOffset(math.max(1,g.w-g.pad*2-g.glyphW-g.gap),r.h)
	readout.BackgroundTransparency=1;readout.TextXAlignment=Enum.TextXAlignment.Right;readout.TextTruncate=Enum.TextTruncate.None
	readout:SetAttribute("AccessibleLabel",readout.Text..(if nectar then " "..Stars.name(tonumber(readout.Text))else " score"))
end
local bestReadout = label("TextLabel", "BestReadout", "", rail)
bestReadout.Font = Art.Font.Counter
bestReadout.TextXAlignment = Enum.TextXAlignment.Left
bestReadout.TextColor3 = Art.Muted
bestReadout.TextTruncate = Enum.TextTruncate.AtEnd
local nextReadout = label("TextLabel", "NextReadout", "", rail)
nextReadout.Font = Art.Font.Counter
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
	BackgroundTransparency = 1, BorderSizePixel = 0,
	Size = UDim2.fromOffset(0,0), AnchorPoint=Vector2.new(.5,.5), ZIndex = 3,
}, overlay)
make("Frame","Tangent",{BackgroundColor3=Palette.Primary,BackgroundTransparency=.45,BorderSizePixel=0,AnchorPoint=Vector2.new(.5,0),Size=UDim2.fromOffset(2,1),ZIndex=3,Active=false,Selectable=false},track)
local aimDots={}
for index=1,Config.PreviewCount do
 local dot=make("Frame","FlightDot"..index,{BackgroundColor3=Palette.Primary,BackgroundTransparency=.45,BorderSizePixel=0,AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(2,2),ZIndex=3,Active=false,Selectable=false},overlay)
 aimDots[index]=dot
end
local ghost = label("TextLabel", "NextEgg", "", overlay, Palette.Primary)
ghost.AnchorPoint = Vector2.new(0.5, 0.5)
ghost.ZIndex = 4
make("UICorner", "Round", { CornerRadius = UDim.new(0.5, 0) }, ghost)

local status = label("TextLabel", "Status", "", clientUI.deviceRoot)
status.TextWrapped = true
status.TextColor3 = Art.Silver
status.TextScaled = false
status.BackgroundColor3 = Art.Ink
Art.instrument(status)
local meter = make("Frame", "HatchTrack", {
	BackgroundColor3 = Art.Ink, BorderSizePixel = 0,
}, clientUI.deviceRoot)
Art.instrument(meter)
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
meterText.Font = Art.Font.Counter
meterText:SetAttribute("TypeRole","Counter")
meterText.Size = UDim2.new(0, 62, 1, 0)
meterText.Position = UDim2.new(1, -64, 0, 0)
meterText.TextSize = 12
meterText.TextColor3 = Palette.Paper
meterText.TextStrokeColor3 = Palette.Ink
meterText.TextStrokeTransparency = 0
local rareGoal = Art.text(clientUI.deviceRoot, "RareGoal", "", UDim2.fromOffset(0, 0),
	UDim2.fromOffset(0, 0), Art.Cyan, 12, Art.Font.Body)
rareGoal.TextScaled = true
rareGoal.TextWrapped = true
rareGoal.ClipsDescendants = true
rareGoal.BackgroundColor3 = Art.Ink
Art.corner(rareGoal, 5)
make("UITextSizeConstraint", "ReadoutSize", { MinTextSize = 8, MaxTextSize = 12 }, rareGoal)
local eggGoal = Art.frame(clientUI.deviceRoot, "EggGoal", Art.Ink, UDim2.fromOffset(0, 0), UDim2.fromOffset(120, 70), 2)
eggGoal.BackgroundTransparency = 1
local goalEgg = Art.frame(eggGoal, "Egg", Art.Leaf, UDim2.fromOffset(8, 6), UDim2.fromOffset(25, 34), 2)
Art.corner(goalEgg, 20); Art.stroke(goalEgg, Art.Silver, .3)
local eggGoalText = Art.text(eggGoal, "Caption", "MEADOW EGG", UDim2.fromOffset(40, 3), UDim2.new(1, -42, 0, 42), Art.Ink, 12)
eggGoalText.TextXAlignment = Enum.TextXAlignment.Left
Art.fitText(eggGoalText, 13, 9, 0, true)
-- Round danger state (UI-SPEC-REDESIGN-MENUS 6.3): calm / near / over fill line,
-- haze and chip in BoardDanger; one entry cue and a cleared chime, no blip.
clientUI.danger=require(script.BoardDanger).new(overlay,{audio=audio})
-- Match hint without a ring (6.2): the LCD gives the matching egg a stronger
-- bloom; two small white sparkles twinkle beside it (steady under Reduced Motion).
clientUI.matchSparkles={}
for index=1,2 do
	local sparkle=make("Frame","MatchSparkle"..index,{AnchorPoint=Vector2.new(.5,.5),BackgroundTransparency=1,Size=UDim2.fromOffset(9,9),Visible=false,ZIndex=7},overlay)
	local rays={}
	for _,size in ipairs({UDim2.new(1,0,0,2),UDim2.new(0,2,1,0)})do
		table.insert(rays,make("Frame","Ray",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=size,BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,ZIndex=7},sparkle))
	end
	clientUI.matchSparkles[index]={node=sparkle,rays=rays}
end
local function utilityButton(name, titleText)
	local button = label("TextButton", name, "", clientUI.deviceRoot)
	local well = Art.frame(button, "KeyWell", Art.Ink, UDim2.fromOffset(4, 5), UDim2.new(1, -8, 1, -7))
	Art.corner(well, 12)
	local cap = make("Frame", "Cap", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 3),
		Size = UDim2.new(1, -10, 1, -10), BackgroundColor3 = Art.Raised, BorderSizePixel = 0,
	}, button)
	Art.corner(cap, 11)
	local edge = make("UIStroke", "Lip", { Color = Palette.Rim, Thickness = 1 }, cap)
	Art.bind(cap,{BackgroundColor3="raised"});Art.surfaceGradient(cap,"raised");Art.bind(edge,{Color="accent"})
	local caption = label("TextLabel", "Caption", titleText, cap)
	caption.Position = UDim2.fromOffset(0, 3)
	caption.Size = UDim2.new(1, 0, 1, -3)
	caption.Font = Art.Font.Action
	caption.TextSize = 12
	Art.bind(caption,{TextColor3="text"})
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
local hardware = make("Frame", "DeckControls", { BackgroundTransparency = 1 }, clientUI.deviceRoot)
local function hardwareButton(name, text, parent, color, width)
	local button = label("TextButton", name, text, parent, color)
	button.Size = UDim2.fromOffset(width, width)
	button.Font = Art.Font.Action
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
Art.corner(Art.frame(hardware, "DropWell", Art.Ink, UDim2.new(1, -51, 0, 1), UDim2.fromOffset(54, 53)), 27).CornerRadius=UDim.new(.5,0)
local action = hardwareButton("Drop", "A", hardware, Art.Amber, 48)
action:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0.5, 0)
Art.stroke(action, Art.Ink, 0.14, 3)
local dropCaption = label("TextLabel", "DropCaption", "DROP", hardware)
dropCaption.Size = UDim2.fromOffset(48, 16)
dropCaption.Visible=false
dropCaption.Font = Art.Font.Action
dropCaption.TextColor3 = Art.Silver
dropCaption.TextSize = 11
dropCaption.BackgroundTransparency=0;Art.bind(dropCaption,{BackgroundColor3="panel",TextColor3="text"});Art.corner(dropCaption,4)
local dropCaptionLayout,captionStatusQueued
local function layoutDropCaption(l)
	if not l then return end
	dropCaptionLayout=l
    dropCaption.Visible=false
    local blocked=if dropCaption.Text~="DROP"then dropCaption.Text else nil
    dropCaption:SetAttribute("BlockedCaption",blocked)
    action:SetAttribute("AccessibleLabel",if blocked then "Drop jelly · "..string.lower(blocked)else "Drop jelly")
end
local vents = make("Frame", "Speaker", { Size = UDim2.fromOffset(57, 28), BackgroundTransparency = 1 }, hardware)
for row = 0, 2 do
	for column = 0, 5 do
		local hole = Art.frame(vents, "Vent", Art.Ink,
			UDim2.fromOffset(2 + column * 9, 2 + row * 8), UDim2.fromOffset(4, 4))
		Art.corner(hole, 2)
	end
end
Art.text(hardware, "MakerMark", "EGG DROP", UDim2.fromOffset(0, 0), UDim2.fromOffset(96, 16), Art.Ink, 12)
hardware.MakerMark.Font = Art.Font.Action
local firstHatchGuide = FirstHatchGuide.new(rail, dpad.RockerWell, action, meter, status)
firstHatchGuide.meter.Position,firstHatchGuide.meter.Size=UDim2.fromOffset(1,1),UDim2.new(1,-2,1,-2)
local questHUD = BoardQuestHUD.new(status)
local dispenser = DropDispenser.new(meter, reduceEffects)
rendererPresentation.dispenser=dispenser
-- Pocket Deck Slim (UI-SPEC-2026-11-12). The wide layout draws the sprite shell and
-- the in-LCD HUD; the stacked portrait case keeps the legacy hardware below. Both
-- keep their offset coordinates because the containers fill deviceRoot.
clientUI.legacyDeck=make("Frame","LegacyCase",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=0},clientUI.deviceRoot)
for _,node in ipairs({shell,bezel,queueHost,status,meter,hardware,customizeButton,roomButton,eggButton,walletDrop,rareGoal,eggGoal,title,clientUI.wordmark.root})do node.Parent=clientUI.legacyDeck end
clientUI.railReadouts=make("Frame","Readouts",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=rail.ZIndex},rail)
for _,node in ipairs({walletFace,readout,scoreCaption,rail.ReadoutDivider})do node.Parent=clientUI.railReadouts end
-- The sprite shell and HUD sit in their own Sibling-ordered gui just under the
-- board gui (DisplayOrder 10), so the board renderer draws over the LCD well.
clientUI.deckGui=make("ScreenGui","EggDropDeck",{ResetOnSpawn=false,ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets,DisplayOrder=9,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,ClipToDeviceSafeArea=false},gui.Parent)
bleed.DisplayOrder=8
-- The deck host mirrors the backdrop so the deck, board and overlays share one
-- root (also when a fixture forces the backdrop's size).
clientUI.deckHost=make("Frame","DeckHost",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1)},clientUI.deckGui)
do
 local function mirror()
  local origin=backdrop.AbsolutePosition-clientUI.deckGui.AbsolutePosition
  clientUI.deckHost.Position=UDim2.fromOffset(origin.X,origin.Y);clientUI.deckHost.Size=UDim2.fromOffset(backdrop.AbsoluteSize.X,backdrop.AbsoluteSize.Y)
 end
 backdrop:GetPropertyChangedSignal("AbsolutePosition"):Connect(mirror);backdrop:GetPropertyChangedSignal("AbsoluteSize"):Connect(mirror)
 clientUI.deckGui:GetPropertyChangedSignal("AbsolutePosition"):Connect(mirror);mirror()
end
-- Compact (UI-SPEC-COMPACT 1.1): on a phone-sized device root the board, deck
-- and overlay guis move to DeviceSafeInsets while the deck is up, so the band
-- beside the Roblox controls is ours. A DeviceSafeInsets probe measures that root.
clientUI.insetProbe=make("ScreenGui","EggDropInsetProbe",{ResetOnSpawn=false,ScreenInsets=Enum.ScreenInsets.DeviceSafeInsets,Enabled=true,DisplayOrder=0},gui.Parent)
function clientUI.refreshInsets()
 local size=clientUI.insetProbe.AbsoluteSize
 local want=if board:GetAttribute("Mode")=="Board"and size.X>0 and require(script.DeckKit).compactRule(size.X,size.Y)
  then Enum.ScreenInsets.DeviceSafeInsets else Enum.ScreenInsets.CoreUISafeInsets
 if gui.ScreenInsets~=want then gui.ScreenInsets=want end
 if clientUI.deckGui.ScreenInsets~=want then clientUI.deckGui.ScreenInsets=want end
end
clientUI.insetProbe:GetPropertyChangedSignal("AbsoluteSize"):Connect(clientUI.refreshInsets)
board:GetAttributeChangedSignal("Mode"):Connect(clientUI.refreshInsets)
clientUI.refreshInsets()
clientUI.deck=DeckScreen.new({parent=clientUI.deckHost,overlayParent=clientUI.deviceRoot,viewRoot=backdrop,audio=audio})
clientUI.deckResults=require(script.DeckResults).new(clientUI.deck.resultsContent,{audio=audio,reduce=reduceEffects})
-- Part 2b: difficulty picker and quest log, full-LCD layers above the board.
clientUI.heatCallbacks,clientUI.questCallbacks={}, {}
clientUI.heatPicker=require(script.DifficultyPicker).new(clientUI.deck:addOverlay("DeckDifficulty",32),clientUI.heatCallbacks)
clientUI.questLog=require(script.QuestLog).new(clientUI.deck:addOverlay("DeckQuestLog",34),clientUI.questCallbacks)
-- Pocket Menu (UI-SPEC-COMPACT-FRAME 9, decision 6): on the deck screen, above the log.
clientUI.pocketCallbacks={}
clientUI.pocketMenu=require(script.PocketMenu).new(clientUI.deck:addOverlay("DeckPocketMenu",36,{lcd=true}),clientUI.pocketCallbacks)
function clientUI.deckOverlayOpen()return clientUI.heatPicker.visible or clientUI.questLog.visible or clientUI.pocketMenu.visible or(clientUI.items~=nil and clientUI.items.isOpen)
 or(clientUI.book~=nil and clientUI.book:isOpen())end
local function isGamepad(inputType)
	return string.match(inputType.Name, "^Gamepad") ~= nil
end

local openPicker
local openJournal
local picker
local journal
local nurseryView
local nurseryState
function clientUI.equippedBallTheme()
 local row=nurseryState and nurseryState.ballThemes
 return if row and clientUI.BallThemes.ById[row.equipped]then row.equipped else clientUI.BallThemes.Default
end
local currentSaveNotice=clientUI.SaveNotice.resolve(board:GetAttribute("SaveStatus"),nil)
local saveNoticeOwner
local refreshSaveNotice
local saveNoticeLayoutQueued=false
local boardSaveCaptionKey,boardSaveCaption
local openNursery
local visitEggs
local modal
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
	request:FireServer("mode", "Board");clientUI.accepted("confirm")
end, function()
	if openPicker()then clientUI.accepted("confirm")end
end, function()
	if openJournal()then clientUI.accepted("confirm")end
end, function()
	return isPickerOpen() or (journal and journal.shade.Visible) or (nurseryView and nurseryView:isOpen()) or clientUI.isHueOpen() or (gameMenu and gameMenu.shade.Visible) or (modal and modal.Visible)
end, reduceEffects, function() if openNursery then openNursery() end end)
clientUI.petContactRemote=remotes:WaitForChild("PetContact")
roomView.petContactIntent=clientUI.PetContactIntent.new({now=os.clock,
 send=function(actionName,payload)clientUI.petContactRemote:FireServer(actionName,payload)end,
 eligible=function(context)return roomView:contactEligible(context)end,
 saved=function()if roomView.affection then roomView.affection:showSaved(reduceEffects())end end})
clientUI.petContactConnection=clientUI.petContactRemote.OnClientEvent:Connect(function(packet)roomView.petContactIntent:receive(packet)end)
gui.Destroying:Connect(function()clientUI.petContactConnection:Disconnect();roomView.petContactIntent:destroy()end)
local function stationContext()
	local character=player.Character
	local root=character and character:FindFirstChild("HumanoidRootPart")
	local humanoid=character and character:FindFirstChildOfClass("Humanoid")
	local alive=character~=nil and character~=roomView.removingCharacter and character:IsDescendantOf(workspace)
		and root~=nil and root.Parent==character and humanoid~=nil and humanoid.Health>0
	return{uiReady=LoungeStations.uiLive(roomView,player:FindFirstChild("PlayerGui"),gui,overlayGui,
			roomView.controls,roomView.transition.shade,modal,gameMenu and gameMenu.shade,
			nurseryView and nurseryView.shade,journal and journal.shade,picker and picker.shade,clientUI.hueView and clientUI.hueView.shade),
		mode=board:GetAttribute("Mode"),viewMode=roomView.mode,alive=alive,
		position=if alive then root.Position else nil,busy=roomView.busy or roomView.transition.shade.Visible,
		switchQueued=roomView.switchQueued,focusing=roomView.focusing,menuOpen=roomView.menuOpen,
		overlay=(modal and modal.Visible) or isPickerOpen() or (journal and journal.shade.Visible)
			or (nurseryView and nurseryView:isOpen()) or clientUI.isHueOpen() or (gameMenu and gameMenu.shade.Visible),
		coreMenu=GuiService.MenuIsOpen,textCapture=UserInputService:GetFocusedTextBox()~=nil,
		snapshot=nurseryState,rank=board:GetAttribute("OwnedPets") or 0,trials=board:GetAttribute("TrialMask") or 0}
end
roomView.canRoam=function()return LoungeStations.canRoam(stationContext())end
roomView.stations=LoungeStations.new({player=player,read=stationContext,
	lounge=function()return workspace:FindFirstChild("EggDropLounge")end,
	triggered=ProximityPromptService.PromptTriggered,routes={
		Customize=function()if openPicker("Shell",nil,"workbench")then clientUI.accepted("confirm")end end,Journal=function()if roomView.care and roomView.care:station()then clientUI.accepted("confirm")end end,Eggs=function()if visitEggs()then clientUI.accepted("confirm")end end,
	}})
-- W2 station attract (icon, shaft, ring, ping); "used" is session memory on this client.
clientUI.attract=require(script.StationAttract).new({player=player,read=stationContext,triggered=ProximityPromptService.PromptTriggered,
	voice=clientUI.ambient,reduced=reduceEffects,cradleBusy=function()return roomView.care~=nil and roomView.care.artToken~=nil and roomView.care.artToken~=false end})
gui.Destroying:Connect(function()clientUI.attract:destroy();clientUI.ambient:destroy()end)

do
	local handoff = gui.DeckHandoff
	handoff.Parent = safeOverlays
	local curtain = Art.frame(bleed, "HandoffBacking", Art.Backdrop, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 2)
	local function updateBacking()
		bleed.Enabled = gui.Enabled
		clientUI.deckGui.Enabled = gui.Enabled and backdrop.Visible
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
end)
board:GetAttributeChangedSignal("CompanionId"):Connect(function()
	local pet = Pets.byId[board:GetAttribute("CompanionId")]
	if pet and board:GetAttribute("Mode") == "Room" then
		roomView:showPet(pet)
		audio:play(pet.cue)
	end
 if clientUI.hueView then clientUI.hueView:syncActive();if clientUI.hueView:isOpen()then clientUI.hueView:refresh()end end
 if clientUI.syncHub then clientUI.syncHub(nurseryState)end
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
modal = make("Frame", "RoundCard", {
	Active = true, Visible = false, BorderSizePixel = 0, ZIndex = 10,
	AnchorPoint = Vector2.new(0.5, 0.5),
}, safeOverlays)
Art.panel(modal, 12, Art.Amber)
local modalTag = Art.text(modal, "Channel", "", UDim2.fromOffset(12, 5),
	UDim2.new(1, -24, 0, 16), Art.Amber, 11)
local modalTitle = label("TextLabel", "Heading", "", modal)
modalTitle.Position = UDim2.fromOffset(0, 18)
modalTitle.Size = UDim2.new(1, 0, 0, 35)
modalTitle.Font = Art.Font.Heading
modalTitle.TextSize = 20
Art.bind(modalTitle,{TextColor3="text"})
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
-- The round results render inside the deck LCD (DeckResults); the floating
-- recap card is gone. `recap` keeps the old name for the owner checks below.
local recap = clientUI.deckResults
local modalAction = label("TextButton", "Continue", "", modal, Art.Amber)
modalAction.Position = UDim2.new(0.09, 0, 1, -52)
modalAction.Size = UDim2.new(0.82, 0, 0, 44)
modalAction.ZIndex = 11
local keepPlaying = label("TextButton", "KeepPlaying", "Keep playing", modal, Art.Raised)
keepPlaying.Position = UDim2.new(0.52, 0, 1, -52)
keepPlaying.Size = UDim2.new(0.43, 0, 0, 44)
keepPlaying.ZIndex = 11
Art.bind(keepPlaying,{BackgroundColor3="raised",TextColor3="text"})
Art.bind(modalAction,{TextColor3="ink"})
for _, button in ipairs({ modalAction, keepPlaying }) do
	Art.button(button, 7)
	Art.fitText(button, 15, 10, 9)
	button.TextWrapped = true
end
local legacySaveScroll=make("ScrollingFrame","SaveBody",{Visible=false,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=11,
	ScrollingDirection=Enum.ScrollingDirection.Y,ElasticBehavior=Enum.ElasticBehavior.Never,ScrollBarThickness=4,ScrollBarImageColor3=Art.Leaf},modal)
local legacySaveContent=Art.frame(legacySaveScroll,"WelcomeContent",Art.Ink,UDim2.fromOffset(0,0),UDim2.fromOffset(100,220),11)
legacySaveContent.BackgroundTransparency=1
local legacySaveDetail=Art.text(legacySaveScroll,"SaveInstruction","",UDim2.fromOffset(4,228),UDim2.fromOffset(100,24),Art.Amber,14)
legacySaveDetail.TextXAlignment=Enum.TextXAlignment.Left
local function restoreLegacySaveParents()
	local wasApplied=legacySaveScroll.Visible
	legacySaveScroll.Visible=false
	if wasApplied then
		modalTag.Position,modalTag.Size=UDim2.fromOffset(12,5),UDim2.new(1,-24,0,16)
		modalTag.Font,modalTag.TextSize,modalTag.TextScaled,modalTag.TextWrapped=Art.Font.Body,11,false,false
		for _,button in ipairs({modalAction,keepPlaying})do button.Font=Art.Font.Body;Art.fitText(button,15,10,9,true)end
	end
	for _,node in ipairs({modalTitle,hatchStage,hatchIndex,pet,reveal.layer})do if node.Parent~=modal then node.Parent=modal end end
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
		board:GetAttribute("DeckStickerId") or Stickers.Default,board:GetAttribute("DeckBackgroundId")or"canopy"
end

local previewStickerId=Stickers.Default
local function paintDeck(id, stickerId,backgroundId)
 local key=id.."|"..stickerId.."|"..(backgroundId or "canopy")
 if rendererPresentation.physicalAppearanceKey==key then return end;rendererPresentation.physicalAppearanceKey=key
	previewStickerId=stickerId
	local theme = Themes.ById[id]
 if Art.applyTheme(theme)then
  viewport.BackgroundColor3=theme.lcd.base;track.Tangent.BackgroundColor3=theme.lcd.guide
  for _,dot in ipairs(aimDots)do dot.BackgroundColor3=theme.lcd.guide end
  Sprite.setSurfacePalette(sprites,theme.lcd)
  if lcd and not lcd:setPalette(theme.lcd)then
   lcd:destroy();lcd=nil;sprites.Visible=rendererPresentation.visible
   if rendererPresentation.restoreCheap then rendererPresentation.restoreCheap(os.clock(),reduceEffects())end
  end
 end
 Art.setBackground(backing,backgroundId or "canopy",theme)
	clientUI.deck:setTheme(id,theme)
	Art.finish(shell,theme,"shell")
	Art.finish(shell.Faceplate,theme,"face")
	rim.Color = theme.trim
	bezelRim.Color = theme.trim
	customizeLip.Color = theme.buttons
 roomLip.Color=theme.buttons
	Art.control(action,true,action.Interactable)
 Art.surfaceGradient(leftAim,"primary");Art.surfaceGradient(rightAim,"primary")
	leftAim.BackgroundColor3 = theme.rocker or Art.Raised
	rightAim.BackgroundColor3 = leftAim.BackgroundColor3
	leftAim.TextColor3 = if theme.rocker then Art.Ink else Art.Silver
	rightAim.TextColor3 = leftAim.TextColor3
	title.TextColor3 = Art.Ink
 title.BackgroundColor3=theme.highlight
	status.TextColor3 = if status.BackgroundTransparency < 1 then Art.Silver else title.TextColor3
	-- A transient blocked-action caption needs a calm surface on every shell.
 Art.bind(dropCaption,{BackgroundColor3="panel",TextColor3="text"})
	hardware.MakerMark.TextColor3 = title.TextColor3
	Art.tintBackdrop(backing,theme)
	for _,instrument in ipairs({walletFace,queueHost,status,meter})do instrument.InsetLip.BackgroundColor3=theme.trim end
	modalShade.BackgroundColor3=Art.Ink
 if dropCaptionLayout then layoutDropCaption(dropCaptionLayout)end

end

local function canAim()
	return board:GetAttribute("Mode") == "Board" and not modal.Visible and not roomView.busy
		and not journal.shade.Visible and not (gameMenu and gameMenu.shade.Visible)
		and not (nurseryView and nurseryView:isOpen()) and not clientUI.isHueOpen() and board:GetAttribute("FieldPhase") ~= "Settling"
		and not board:GetAttribute("RoundOver") and not clientUI.deckOverlayOpen()
end

local function canPlay()
	return canAim() and not isPickerOpen() and not roomView.busy and not GuiService.MenuIsOpen
		and board:GetAttribute("FieldReady") ~= false
end

picker = DeckPicker.new(safeOverlays, make, label, function()end, function(reason)
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(picker.shade) then
		local controls = gui.LoungeControls
		GuiService.SelectedObject = if board:GetAttribute("Mode") == "Room" and controls.Visible
			then controls.OpenHandheld else nil
	end
	rail.Interactable = canAim()
 local back=clientUI.pickerReturn;clientUI.pickerReturn=nil
 if reason=="back"and back and openMenu and not roomView.busy and not modal.Visible and not nurseryView:isOpen() and not clientUI.isHueOpen()then
  openMenu();gameMenu:setPage(back.page);gameMenu.body.CanvasPosition=back.scroll
  if isGamepad(UserInputService:GetLastInputType())and not GuiService.MenuIsOpen and not UserInputService:GetFocusedTextBox()and clientUI.ControllerFocus.live(back.target,gameMenu.shade,player:FindFirstChild("PlayerGui"),true)then
   local y=back.target.AbsolutePosition.Y-gameMenu.body.AbsolutePosition.Y+gameMenu.body.CanvasPosition.Y
   local viewport=gameMenu.body.AbsoluteSize.Y;local desired=gameMenu.body.CanvasPosition.Y
   if y<desired then desired=y elseif y+back.target.AbsoluteSize.Y>desired+viewport then desired=y+back.target.AbsoluteSize.Y-viewport end
   gameMenu.body.CanvasPosition=Vector2.new(0,math.clamp(desired,0,math.max(0,gameMenu.body.CanvasSize.Y.Offset-viewport)))
   GuiService.SelectedObject=back.target
  end
 end
end, function(slot,id)
 return if clientUI.appearanceIntent then clientUI.appearanceIntent:choose(slot,id)else false
end, function(actionName)
	if actionName == "music" then
		audio:setMusicEnabled(not audio:isMusicEnabled())
		picker.music.Text = if audio:isMusicEnabled() then "Music: On" else "Music: Off"
		picker:layout()
		return
	end
	request:FireServer(actionName)
end)

nurseryView = NurseryView.new(safeOverlays, audio, reduceEffects, function(actionName, value, revision)
	nurseryRequest:FireServer(actionName, value, revision)
end)
-- Robux store page inside the egg shop. Server-initiated prompts only.
clientUI.storeView=require(script.StoreView).new(nurseryView.shade,{reduceEffects=reduceEffects,
 request=function(actionName,key)if clientUI.storeRequest then clientUI.storeRequest:FireServer(actionName,key)end end})
clientUI.storeView.onAccepted=function(kind)clientUI.accepted(kind)end
nurseryView:attachStore(clientUI.storeView)
task.spawn(function()
 clientUI.storeRequest=remotes:WaitForChild("StoreRequest")
 local stateConnection=remotes:WaitForChild("StoreState").OnClientEvent:Connect(function(snapshot)clientUI.storeView:setState(snapshot)end)
 local resultConnection=remotes:WaitForChild("StoreResult").OnClientEvent:Connect(function(result)clientUI.storeView:handleResult(result)end)
 gui.Destroying:Connect(function()stateConnection:Disconnect();resultConnection:Disconnect()end)
 clientUI.storeRequest:FireServer("open")
end)
nurseryView.appearanceFor=function(petId)
 local a=roomView.garden:appearance(board,petId)
 local state=nurseryState
 if state and EggCatalog.isOwned(state.inventoryMask or 0,petId)then
  a.toyId=(state.petToys or {})[petId]or "none"
  local row=(state.petFeatures or {})[petId]or {}
  a.featureStages={horns=row.horns and row.horns.visible or 0,claws=row.claws and row.claws.visible or 0,wings=row.wings and row.wings.visible or 0}
  local worn=(state.petWearables or {})[petId]
  a.wearables=if worn and type(worn.equipped)=="table"then table.clone(worn.equipped)else {}
  a.appearanceGeneration=state.revision or a.appearanceGeneration
 end
 return a
end
clientUI.itemAvailable=function(own)
 if currentSaveNotice~=nil then return false end
 for _,kind in ipairs({"hue","material","toy","feature"})do local intent=clientUI[kind.."Intent"];if kind~=own and intent and intent.pending then return false end end
 return true
end
journal.appearanceFor=nurseryView.appearanceFor
-- UI personality T4: the pet peek shows the equipped, owned pet (none on a fresh save).
do
 local PetPeek=require(script.PetPeek)
 PetPeek.setSource(function()
  local petId=board:GetAttribute("CompanionId")
  if type(petId)~="string"or not Pets.byId[petId]then return nil end
  if not nurseryState or not EggCatalog.isOwned(nurseryState.inventoryMask or 0,petId)then return nil end
  return petId,nurseryView.appearanceFor(petId)
 end)
 gui.Destroying:Connect(PetPeek.destroy)
end
clientUI.hueIntent=clientUI.HueIntent.new({
 id=function()return HttpService:GenerateGUID(false)end,
 available=function()return clientUI.itemAvailable("hue")end,
 send=function(action,value,revision)nurseryRequest:FireServer(action,value,revision)end,
 changed=function()if clientUI.hueView then clientUI.hueView:refresh()end end})
clientUI.materialIntent=require(script.MaterialIntent).new({id=function()return HttpService:GenerateGUID(false)end,
 available=function()return clientUI.itemAvailable("material")end,send=function(action,value,revision)nurseryRequest:FireServer(action,value,revision)end,
 changed=function()if clientUI.hueView then clientUI.hueView:refresh()end end})
clientUI.toyIntent=require(script.ToyIntent).new({id=function()return HttpService:GenerateGUID(false)end,
 available=function()return clientUI.itemAvailable("toy")end,send=function(action,value,revision)nurseryRequest:FireServer(action,value,revision)end,
 changed=function()if clientUI.hueView then clientUI.hueView:refresh()end end})
clientUI.featureIntent=require(script.FeatureIntent).new({id=function()return HttpService:GenerateGUID(false)end,
 available=function()return clientUI.itemAvailable("feature")end,send=function(action,value,revision)nurseryRequest:FireServer(action,value,revision)end,
 changed=function()if clientUI.hueView then clientUI.hueView:refresh()end end})
clientUI.hueView=clientUI.HueEggView.new(safeOverlays,clientUI.hueIntent,{
 materialIntent=clientUI.materialIntent,toyIntent=clientUI.toyIntent,featureIntent=clientUI.featureIntent,
 wardrobe=function(petId)return clientUI.openWardrobe and clientUI.openWardrobe(petId)end,
 canCustomize=function(petId)
  local actor=roomView.care and roomView.care:actor()
  petId=petId or(clientUI.hueView and clientUI.hueView.petId)
  -- Opened from the cradle with free hands: edit the pet without docking it.
  if(clientUI.hueReturn=="companions"or clientUI.hueReturn=="hub")and roomView.mode=="Room"and not roomView.busy and petId~=nil then return true end
  return roomView.mode=="Room"and roomView.target=="Room"and not roomView.busy and actor~=nil and actor.care~=nil and actor.care.state=="Docked"and actor.petId==petId
 end,
 appearance=nurseryView.appearanceFor,
 activePet=function()return board:GetAttribute("CompanionId")end,
 audio=audio,reduceEffects=reduceEffects,
 careAction=function(kind)if roomView.care then roomView.care:request(kind)end end,
 equipPet=function(id)
  if not clientUI.hueView.machine then
   request:FireServer("companion",id)
   local view=clientUI.hueView;local decision=view.confirmation
   task.delay(3,function()
    if view.shade.Visible and view.confirmation==decision and view.machineSwitching and not view.machine then
     view:syncActive()
     if view.machineSwitching then view.machineSwitching=nil;view.exitMessage="Pet save is still pending. Try Make active again.";view:refresh()end
    end
   end)
   return true
  end
  local binding=clientUI.hueView:machineBinding()
  return roomView.care and roomView.care:request("careEquip",id,function(packet)clientUI.hueView:machineEquipFinished(packet.status,binding)end)or false
 end,
 dismissMachine=function(binding,done)
  local care=roomView.care;local actor=care and care:actor()
  if not actor or not actor.care or actor.petId~=binding.petId or actor.characterId~=binding.characterId or actor.petGeneration~=binding.petGeneration then return false end
  if actor.care.state=="Carried"and actor.generation==binding.actorGeneration+1 then done({status="Accepted"});return true end
  if actor.care.claimId~=binding.claimId then return false end
  if actor.care.state~="Docked"then return false end
  return care:request("carePickup",nil,done)
 end,
 shop=function()if openNursery then openNursery();nurseryView:selectRecipe("hue")end end,
 eggs=function()if openNursery then openNursery();nurseryView:selectRecipe("toy")end end,
 materialShop=function()if openNursery then openNursery();nurseryView:selectRecipe("material")end end,
 toyShop=function()if openNursery then openNursery();nurseryView:selectRecipe("toy")end end,
 featureShop=function()if openNursery then openNursery();nurseryView:selectRecipe("feature")end end,
 charm=function(petId,visible,shape,seq,shapeVersion)
  if not seq then clientUI.charmSeq=(clientUI.charmSeq or 0)+1;seq=clientUI.charmSeq end
  request:FireServer("petAppearance",{petId=petId,visible=visible,shape=shape,shapeVersion=shapeVersion,seq=seq})
  return {petId=petId,visible=visible,shape=shape,shapeVersion=shapeVersion,seq=seq}
 end,
 earn=function()if hatchNavigation then hatchNavigation:play()end end,
 petsSelector=function(assign)return clientUI.openHub and clientUI.openHub({page="pets",assign=assign})or false end,
 pendingHatch=function()if openNursery then openNursery()end end,
 closed=function(reason)
  local back=clientUI.hueReturn;clientUI.hueReturn=nil
  if back=="machine"then
   clientUI.hueView:setMachineSession(nil)
   if reason~="picked-up"and roomView.care then roomView.care:release()end
  end
  if reason=="back"and not roomView.busy and not(nurseryState and nurseryState.lastHatch)then
   if back=="eggs"and openNursery then openNursery()end
   if back=="hub"and clientUI.openHub then clientUI.openHub()end
  end
 end})
clientUI.openHue=function(page,petId,back)
 local purchasePage=page=="buy"or page=="materialBuy"or page=="toyBuy"or page=="featureBuy"
 if not purchasePage and back~="companions"and back~="hub"then
  local actor=roomView.care and roomView.care:actor()
  if back~="machine"or not actor or not actor.care or actor.care.state~="Docked"or actor.petId~=petId then return false end
 end
 if roomView.busy or not nurseryState then return false end
 if nurseryState.lastHatch then if openNursery then openNursery()end;return false end
 cancelHatchNavigation();clearPlayInputs();picker:close();journal:close();nurseryView:close("hue")
 if closeMenu then closeMenu()end
 clientUI.hueReturn=back or "eggs"
 if back~="machine"then clientUI.hueView:setMachineSession(nil)end
 return clientUI.hueView:open(nurseryState,page,petId or board:GetAttribute("CompanionId"))
end
roomView.care.revision=function()return nurseryState and nurseryState.revision end
roomView.care.openFree=function()
 local petId=board:GetAttribute("CompanionId")
 if not petId or not nurseryState or not EggCatalog.isOwned(nurseryState.inventoryMask or 0,petId)then return false end
 if clientUI.openHub then return clientUI.openHub()end
 return clientUI.openHue("palette",petId,"companions")
end
roomView.care.isMachineOpen=function(claimId)return clientUI.hueReturn=="machine"and clientUI.hueView.shade.Visible and clientUI.hueView.machine and clientUI.hueView.machine.claimId==claimId end
roomView.care.openMachine=function(actor)
 if clientUI.hueView.shade.Visible and clientUI.hueReturn~="machine"then return end
 if not clientUI.hueView.shade.Visible then clientUI.openHue("palette",actor.petId,"machine")end
 clientUI.hueView:setMachineSession({claimId=actor.care.claimId,petId=actor.petId,characterId=actor.characterId,petGeneration=actor.petGeneration,actorGeneration=actor.generation})
end
roomView.care.closeMachine=function()
 if clientUI.hueReturn=="machine"then clientUI.hueView:close("care");clientUI.hueView:setMachineSession(nil)end
end
nurseryView.onOpenHue=function(purchase)
 if clientUI.openHue("buy",nil,"eggs")and purchase and not nurseryState.pendingHueResult then clientUI.hueIntent:hatch()end
end
nurseryView.onOpenMaterial=function(purchase)
 if clientUI.openHue("materialBuy",nil,"eggs")and purchase and not nurseryState.pendingMaterialResult then clientUI.materialIntent:buy()end
end
nurseryView.onOpenToy=function(purchase)
 if clientUI.openHue("toyBuy",nil,"eggs")and purchase and not nurseryState.pendingToyResult then clientUI.toyIntent:buy()end
end
nurseryView.onOpenFeature=function(purchase)
 if clientUI.openHue("featureBuy",nil,"eggs")and purchase and not nurseryState.pendingFeatureResult then clientUI.featureIntent:buy()end
end
journal:setColors(function(petId)clientUI.openHue("palette",petId,"journal")end)
-- Wardrobe (pet wearables for Stars), opened from the Companions editor at the Care Cradle.
-- Its own ScreenGui above the overlays; the editor (and any docked session) stays open under it.
do
 local WardrobeShop=require(script.WardrobeShop)
 local Kit=require(script.DeckKit)
 local WearableCatalog=require(ReplicatedStorage.Shared.WearableCatalog)
 local wardrobeGui=make("ScreenGui","EggDropWardrobe",{ResetOnSpawn=false,ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets,DisplayOrder=12,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,ClipToDeviceSafeArea=false},gui.Parent)
 local host=make("Frame","WardrobeHost",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1)},wardrobeGui)
 local function context(state)
  local shop=clientUI.wardrobe;local petId=shop and shop.petId or "pip"
  local row=(state and state.petWearables or {})[petId]
  local features=(state and state.petFeatures or {})[petId]or {}
  return {wallet=state and state.nectar or 0,row={owned=table.clone(row and row.owned or {}),equipped=table.clone(row and row.equipped or {})},
   stages={horns=features.horns and features.horns.visible or 0,wings=features.wings and features.wings.visible or 0}}
 end
 local function syncInsets()
  -- Compact phones use the device root (UI-SPEC-COMPACT 1.1), like the deck guis,
  -- measured from the stable DeviceSafeInsets probe (not this gui, whose size moves with its insets).
  local wanted=Kit.compactInsets(clientUI.insetProbe.AbsoluteSize)
  if wardrobeGui.ScreenInsets~=wanted then wardrobeGui.ScreenInsets=wanted end
 end
 clientUI.wardrobe=WardrobeShop.new(host,{
  appearance=function(petId)return nurseryView.appearanceFor(petId)end,
  buy=function(order)nurseryRequest:FireServer("wearableBuy",{id=order.id,petId=order.petId,itemId=order.itemId,price=order.price,equip=true},nurseryState and nurseryState.revision or 0)end,
  equip=function(order)nurseryRequest:FireServer("wearableEquip",{id=order.id,petId=order.petId,slot=order.slot,itemId=order.wear},nurseryState and nurseryState.revision or 0)end,
  done=function(order)
   local item=WearableCatalog.item(order.petId,order.itemId)
   clientUI.wardrobeToaster=clientUI.wardrobeToaster or Kit.toaster(host)
   if item then clientUI.wardrobeToaster.show(if order.action=="wearableBuy"then item.name.." bought"elseif order.wear then item.name.." on"else item.name.." off")end
  end,
  back=function()clientUI.wardrobe:close();if clientUI.isHueOpen()then clientUI.hueView:refresh()end end})
 clientUI.isWardrobeOpen=function()return clientUI.wardrobe:isOpen()end
 clientUI.syncWardrobe=function(state)if clientUI.wardrobe:isOpen()then clientUI.wardrobe:setContext(context(state))end end
 clientUI.openWardrobe=function(petId)
  if not nurseryState or roomView.busy or not WearableCatalog.hasItems(petId or "")then return false end
  if GuiService.SelectedObject then GuiService.SelectedObject=nil end
  syncInsets();clientUI.wardrobe.petId=petId
  clientUI.wardrobe:open(petId,context(nurseryState));return true
 end
 clientUI.insetProbe:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncInsets)
 local wearableResultConnection=remotes:WaitForChild("WearableResult").OnClientEvent:Connect(function(message)
  clientUI.wardrobe:result(message)
  nurseryRequest:FireServer("snapshot")
 end)
 ContextActionService:BindActionAtPriority("EggDropWardrobe",function(_,state,input)
  if not clientUI.wardrobe:isOpen()or UserInputService:GetFocusedTextBox()or GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end
  if state~=Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
  local key=input.KeyCode;local shop=clientUI.wardrobe
  if key==Enum.KeyCode.Left or key==Enum.KeyCode.A or key==Enum.KeyCode.DPadLeft then shop:move(-1,0)
  elseif key==Enum.KeyCode.Right or key==Enum.KeyCode.D or key==Enum.KeyCode.DPadRight then shop:move(1,0)
  elseif key==Enum.KeyCode.Up or key==Enum.KeyCode.W or key==Enum.KeyCode.DPadUp then shop:move(0,-1)
  elseif key==Enum.KeyCode.Down or key==Enum.KeyCode.S or key==Enum.KeyCode.DPadDown then shop:move(0,1)
  elseif key==Enum.KeyCode.Q or key==Enum.KeyCode.ButtonL1 then shop:shiftTab(-1)
  elseif key==Enum.KeyCode.E or key==Enum.KeyCode.ButtonR1 then shop:shiftTab(1)
  elseif key==Enum.KeyCode.ButtonB or key==Enum.KeyCode.Backspace then shop:back()
  else shop:act()end
  return Enum.ContextActionResult.Sink
 end,false,Enum.ContextActionPriority.High.Value+800,Enum.KeyCode.Left,Enum.KeyCode.Right,Enum.KeyCode.Up,Enum.KeyCode.Down,Enum.KeyCode.A,Enum.KeyCode.D,
  Enum.KeyCode.W,Enum.KeyCode.S,Enum.KeyCode.Q,Enum.KeyCode.E,Enum.KeyCode.ButtonL1,Enum.KeyCode.ButtonR1,Enum.KeyCode.DPadLeft,Enum.KeyCode.DPadRight,
  Enum.KeyCode.DPadUp,Enum.KeyCode.DPadDown,Enum.KeyCode.Space,Enum.KeyCode.Return,Enum.KeyCode.KeypadEnter,Enum.KeyCode.ButtonA,Enum.KeyCode.ButtonB,Enum.KeyCode.Backspace)
 gui.Destroying:Connect(function()wearableResultConnection:Disconnect();ContextActionService:UnbindAction("EggDropWardrobe");clientUI.wardrobe:destroy();wardrobeGui:Destroy()end)
end
-- Companions hub (redesign menus 1): its own ScreenGui under the Wardrobe (12), so the
-- Wardrobe opens over it and Back returns to it. Customize closes the hub and returns
-- to it on Back. Receipts open it on the Pets selector in assign mode.
do
 local CompanionsHub=require(script.CompanionsHub)
 local Kit=require(script.DeckKit)
 local hubGui=make("ScreenGui","EggDropCompanions",{ResetOnSpawn=false,ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets,DisplayOrder=11,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,ClipToDeviceSafeArea=false},gui.Parent)
 local host=make("Frame","CompanionsHost",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1)},hubGui)
 local function context(state)return{wallet=state and state.nectar or 0,state=state or {},activeId=board:GetAttribute("CompanionId")}end
 local function syncInsets()
  local wanted=Kit.compactInsets(clientUI.insetProbe.AbsoluteSize)
  if hubGui.ScreenInsets~=wanted then hubGui.ScreenInsets=wanted end
 end
 clientUI.hub=CompanionsHub.new(host,{
  appearance=function(petId)return nurseryView.appearanceFor(petId)end,
  open=function(rowId,petId)
   petId=petId or board:GetAttribute("CompanionId")
   if rowId=="wardrobe"then return clientUI.openWardrobe and clientUI.openWardrobe(petId)or false end
   if rowId=="book"then return clientUI.openBook and clientUI.openBook()or false end
   if rowId=="customize"then
    clientUI.hub:close("customize")
    if clientUI.openHue("palette",petId,"hub")then return true end
    clientUI.openHub();return false
   end
   return false
  end,
  follow=function(petId)request:FireServer("companion",petId);return true end})
 clientUI.openHub=function(options)
  if not nurseryState or roomView.busy then return false end
  options=options or {}
  if not options.assign and(nurseryState.lastHatch)then if openNursery then openNursery()end;return false end
  if not options.assign then cancelHatchNavigation();clearPlayInputs();picker:close();journal:close();nurseryView:close("hue")end
  if GuiService.SelectedObject then GuiService.SelectedObject=nil end
  syncInsets()
  return clientUI.hub:open(context(nurseryState),options)
 end
 clientUI.syncHub=function(state)if clientUI.hub:isOpen()then clientUI.hub:setContext(context(state))end end
 clientUI.insetProbe:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncInsets)
 local keys={Enum.KeyCode.Left,Enum.KeyCode.Right,Enum.KeyCode.Up,Enum.KeyCode.Down,Enum.KeyCode.A,Enum.KeyCode.D,Enum.KeyCode.W,Enum.KeyCode.S,
  Enum.KeyCode.Q,Enum.KeyCode.E,Enum.KeyCode.X,Enum.KeyCode.ButtonX,Enum.KeyCode.ButtonL1,Enum.KeyCode.ButtonR1,Enum.KeyCode.DPadLeft,Enum.KeyCode.DPadRight,
  Enum.KeyCode.DPadUp,Enum.KeyCode.DPadDown,Enum.KeyCode.Space,Enum.KeyCode.Return,Enum.KeyCode.KeypadEnter,Enum.KeyCode.ButtonA,Enum.KeyCode.ButtonB,Enum.KeyCode.Backspace,Enum.KeyCode.Escape}
 -- Below the Wardrobe (High+800), above the sheet handoff and the game controls.
 ContextActionService:BindActionAtPriority("EggDropCompanions",function(_,state,input)
  if UserInputService:GetFocusedTextBox()or GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end
  if clientUI.isWardrobeOpen and clientUI.isWardrobeOpen()then return Enum.ContextActionResult.Pass end
  local key=input.KeyCode
  if clientUI.hub:isOpen()then
   if key==Enum.KeyCode.Q or key==Enum.KeyCode.E or key==Enum.KeyCode.X or key==Enum.KeyCode.ButtonX or key==Enum.KeyCode.ButtonL1 or key==Enum.KeyCode.ButtonR1 then return Enum.ContextActionResult.Sink end
   if state==Enum.UserInputState.Begin then clientUI.hub:input(key)end
   return Enum.ContextActionResult.Sink
  end
  local view=clientUI.hueView
  if view and view:chromeActive()then
   if key==Enum.KeyCode.Escape then return Enum.ContextActionResult.Pass end
   if state==Enum.UserInputState.Begin then view:chromeInput(key)end
   return Enum.ContextActionResult.Sink
  end
  -- Hatch eggs list: keyboard W / S / Up / Down move the selection, Enter hatches.
  if nurseryView:isOpen()and not(nurseryView.state and nurseryView.state.lastHatch)and not nurseryView:isStoreOpen()then
   local delta=if key==Enum.KeyCode.Up or key==Enum.KeyCode.W then -1 elseif key==Enum.KeyCode.Down or key==Enum.KeyCode.S then 1 else 0
   if delta~=0 then if state==Enum.UserInputState.Begin then nurseryView:moveRecipe(delta)end;return Enum.ContextActionResult.Sink end
   if key==Enum.KeyCode.Return or key==Enum.KeyCode.KeypadEnter then if state==Enum.UserInputState.Begin then nurseryView:actPrimary()end;return Enum.ContextActionResult.Sink end
  end
  return Enum.ContextActionResult.Pass
 end,false,Enum.ContextActionPriority.High.Value+790,table.unpack(keys))
 gui.Destroying:Connect(function()ContextActionService:UnbindAction("EggDropCompanions");clientUI.hub:destroy();hubGui:Destroy()end)
end
-- Collection book (play-forever F2): its own ScreenGui above the Wardrobe (12) and the
-- Companions hub (11), so it opens over the hub and Back returns there. Opened from the
-- hub's Collection book row and the Pocket Menu (over a paused round). Claims go out as
-- HatchRequest "bookClaim"; replies ride FaceplateResult with kind = "book".
do
 local BookView=require(script.BookView)
 local Kit=require(script.DeckKit)
 local UICopy=require(ReplicatedStorage.Shared.UICopy)
 local bookGui=make("ScreenGui","EggDropBook",{ResetOnSpawn=false,ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets,DisplayOrder=13,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,ClipToDeviceSafeArea=false},gui.Parent)
 local host=make("Frame","BookHost",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1)},bookGui)
 local function context(state)
  state=state or {}
  return{book=state.book,stats=state.stats,stamps=state.stamps,wallet=state.nectar or 0,revision=state.revision or 0}
 end
 local function syncInsets()
  local wanted=Kit.compactInsets(clientUI.insetProbe.AbsoluteSize)
  if bookGui.ScreenInsets~=wanted then bookGui.ScreenInsets=wanted end
 end
 clientUI.book=BookView.new(host,{
  send=function(action,payload)nurseryRequest:FireServer(action,payload,nurseryState and nurseryState.revision or 0)end,
  claimed=function(message)
   clientUI.bookToaster=clientUI.bookToaster or Kit.toaster(host)
   clientUI.bookToaster.show(UICopy.get("book.toast.claimed"),if type(message.reward)=="number"and message.reward>0 then message.reward else nil)
   if message.faceplate then clientUI.bookToaster.show(UICopy.get("book.toast.bookworm"))end
  end,
  closed=function()clientUI.syncPause();if updateHud then task.defer(updateHud)end end,
  back=function()clientUI.accepted("back")end})
 clientUI.openBook=function(options)
  if not nurseryState or roomView.busy or clientUI.book:isOpen()then return false end
  if GuiService.SelectedObject then GuiService.SelectedObject=nil end
  clearPlayInputs();syncInsets()
  local ok=clientUI.book:open(context(nurseryState),options)
  clientUI.syncPause()
  return ok
 end
 clientUI.syncBook=function(state)if clientUI.book:isOpen()then clientUI.book:setContext(context(state))end end
 clientUI.insetProbe:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncInsets)
 local keys={Enum.KeyCode.Left,Enum.KeyCode.Right,Enum.KeyCode.Up,Enum.KeyCode.Down,Enum.KeyCode.A,Enum.KeyCode.D,Enum.KeyCode.W,Enum.KeyCode.S,
  Enum.KeyCode.Q,Enum.KeyCode.E,Enum.KeyCode.ButtonL1,Enum.KeyCode.ButtonR1,Enum.KeyCode.DPadLeft,Enum.KeyCode.DPadRight,Enum.KeyCode.DPadUp,Enum.KeyCode.DPadDown,
  Enum.KeyCode.Space,Enum.KeyCode.Return,Enum.KeyCode.KeypadEnter,Enum.KeyCode.ButtonA,Enum.KeyCode.ButtonB,Enum.KeyCode.Backspace,Enum.KeyCode.Escape,
  Enum.KeyCode.M,Enum.KeyCode.ButtonY,Enum.KeyCode.ButtonStart,Enum.KeyCode.ButtonX,Enum.KeyCode.X}
 -- Above the Wardrobe (High+800) and the hub (High+790): the book owns input while open.
 ContextActionService:BindActionAtPriority("EggDropBook",function(_,state,input)
  if not clientUI.book:isOpen()or UserInputService:GetFocusedTextBox()or GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end
  if state==Enum.UserInputState.Begin then clientUI.book:input(input.KeyCode)end
  return Enum.ContextActionResult.Sink
 end,false,Enum.ContextActionPriority.High.Value+810,table.unpack(keys))
 gui.Destroying:Connect(function()ContextActionService:UnbindAction("EggDropBook");clientUI.book:destroy();bookGui:Destroy()end)
end
clientUI.hueResult=remotes:WaitForChild("HueResult").OnClientEvent:Connect(function(packet)clientUI.hueIntent:receive(packet)end)
clientUI.charmResult=remotes:WaitForChild("PetAppearanceResult").OnClientEvent:Connect(function(packet)clientUI.hueView:charmResult(packet)end)
clientUI.materialResult=remotes:WaitForChild("MaterialResult").OnClientEvent:Connect(function(packet)clientUI.materialIntent:receive(packet)end)
clientUI.toyResult=remotes:WaitForChild("ToyResult").OnClientEvent:Connect(function(packet)clientUI.toyIntent:receive(packet)end)
clientUI.featureResult=remotes:WaitForChild("FeatureResult").OnClientEvent:Connect(function(packet)clientUI.featureIntent:receive(packet)end)
gui.Destroying:Connect(function()clientUI.hueResult:Disconnect();clientUI.charmResult:Disconnect();clientUI.materialResult:Disconnect();clientUI.toyResult:Disconnect();clientUI.featureResult:Disconnect();clientUI.materialIntent:destroy();clientUI.toyIntent:destroy();clientUI.featureIntent:destroy();clientUI.hueView:destroy()end)
board:GetAttributeChangedSignal("PetAppearance"):Connect(function()
 if nurseryView.state.lastHatch then nurseryView.cinematic:setAppearance(nurseryView.appearanceFor(nurseryView.state.lastHatch.petId))elseif nurseryView:isOpen()then nurseryView:renderBody()end
 if clientUI.isHueOpen()then clientUI.hueView:refresh()end
 if journal.shade.Visible then for i,p in ipairs(journal.portraits)do if p.sprite then require(script.PetPortrait).apply(p.sprite,nurseryView.appearanceFor(Pets.collection[i].id))end end end
end)
nurseryView.ownsPresentation = function()
	return not roomView.busy and not roomView.transition.shade.Visible and not modal.Visible
		and not isPickerOpen() and not journal.shade.Visible and not clientUI.isHueOpen() and not (gameMenu and gameMenu.shade.Visible)
end
nurseryView.cinematic.ownerState=function()
 return{roomBusy=roomView.busy==true,transition=roomView.transition.shade.Visible,modal=modal.Visible,picker=isPickerOpen(),journal=journal.shade.Visible,hue=clientUI.isHueOpen(),menu=gameMenu and gameMenu.shade.Visible or false,shade=nurseryView.shade.Visible,revealHost=nurseryView.revealHost.Visible,body=nurseryView.body.Visible,ackReady=nurseryView.ackReady==true,viewOwnsInput=nurseryView:ownsInput()}
end
roomView.onPresentationOwnerChanged = function()
	nurseryView.cinematic:refreshOwner()
end
openNursery = function()
	if roomView.busy or board:GetAttribute("Mode") ~= "Room" then return end
	picker:close()
	journal:close()
    if clientUI.hueView then clientUI.hueView:close("forced")end
	if nurseryState then nurseryView:open(nurseryState) end
end
hatchNavigation = HatchNavigation.new({
	get = function(name) return board:GetAttribute(name) end,
	send = function(actionName, value) request:FireServer(actionName, value) end,
	ready = function() return not roomView.busy end,
	blocked = function()
		return isPickerOpen() or journal.shade.Visible or nurseryView:isOpen() or clientUI.isHueOpen()
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
-- Customize from the deck: the same board-to-garden route as the egg shop, then
-- the companion editor the Care Cradle opens with free hands.
function clientUI.visitCompanions()
	return LoungeStations.visitEggs({cancel=cancelHatchNavigation,read=stationContext,
		generation=function()return hatchNavigation.generation end,
		identity=function()return player.Character,workspace.CurrentCamera end,
		canEnterFromBoard=function()
			return not isPickerOpen() and not journal.shade.Visible and not nurseryView:isOpen() and not clientUI.isHueOpen()
				and not gameMenu.shade.Visible and not modal.Visible
		end,
		sendMode=function(mode)request:FireServer("mode",mode)end,
		open=function()if roomView.care and roomView.care.openFree then roomView.care.openFree()end end})
end
visitEggs = function()
	return LoungeStations.visitEggs({cancel=cancelHatchNavigation,read=stationContext,
		generation=function()return hatchNavigation.generation end,
		identity=function()return player.Character,workspace.CurrentCamera end,
		canEnterFromBoard=function()
			return not isPickerOpen() and not journal.shade.Visible and not nurseryView:isOpen() and not clientUI.isHueOpen()
				and not gameMenu.shade.Visible and not modal.Visible
		end,
		sendMode=function(mode)request:FireServer("mode",mode)end,open=openNursery})
end

eggButton.Visible = false
local shownNurseryHatch
local function refreshNursery(state)
 if type(state)~="table"then return end
 if nurseryState and type(state.revision)=="number"and type(nurseryState.revision)=="number"and state.revision<nurseryState.revision then return end
 nurseryState = state
    if clientUI.onQuests then clientUI.onQuests(state)end
    if picker then picker:setShopState(state.nectar,state.faceplates,state.ballThemes,state.revision)end
    if clientUI.syncWardrobe then clientUI.syncWardrobe(state)end
    if clientUI.syncHub then clientUI.syncHub(state)end
    if clientUI.syncBook then clientUI.syncBook(state)end
    clientUI.hueIntent:update(state)
    clientUI.materialIntent:update(state)
    clientUI.toyIntent:update(state)
    clientUI.featureIntent:update(state)
	currentSaveNotice=clientUI.SaveNotice.resolve(board:GetAttribute("SaveStatus"),state)
	if refreshSaveNotice then refreshSaveNotice()end
	roomView.stations:refresh()
	roomView.transition:refresh()
	nurseryView:update(state)
	local result = state.lastHatch
 if result and clientUI.isHueOpen()then clientUI.hueView:close("forced")end
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
				clientUI.PresentationPolicy.presentCommittedHatch(result.id,generation,{generation=hatchNavigation.generation,
					id=nurseryState.lastHatch.id,mode=board:GetAttribute("Mode"),ready=not roomView.busy},
					function()if closeMenu then closeMenu()end end,openNursery)
			end
		end)
	end
end
clientUI.ownerSnapshot=require(script.OwnerSnapshot)
clientUI.stopSnapshot=clientUI.ownerSnapshot.subscribe(refreshNursery)
clientUI.nurserySnapshot=remotes:WaitForChild("NurserySnapshot").OnClientEvent:Connect(clientUI.ownerSnapshot.receive)
gui.Destroying:Connect(function()clientUI.nurserySnapshot:Disconnect();clientUI.stopSnapshot()end)
nurseryFeedback.OnClientEvent:Connect(function(kind, message)
	if kind == "open" then openNursery()
	elseif kind == "error" then nurseryView:setError(message) end
end)
nurseryRequest:FireServer("snapshot")

gameMenu = DeckMenu.new(safeOverlays, {
	close = function() closeMenu() end,
	eggs = function() closeMenu(); visitEggs() end,
	pets = function() end,
	style = function() end,
 trials=function()closeMenu();openPicker("Trials")end,
 settings=function()closeMenu();openPicker("Settings")end,
	play = function() closeMenu(); if board:GetAttribute("Mode") == "Room" then request:FireServer("mode", "Board") end end,
	daily = function() if nurseryState then nurseryRequest:FireServer("daily", nurseryState.dailyDay, nurseryState.revision) end end,
})
closeMenu = function()
	gameMenu:close(); roomView:setMenuOpen(false)
	end
openMenu = function()
	cancelHatchNavigation()
	if roomView.busy or modal.Visible or nurseryView:isOpen() or clientUI.isHueOpen() then return end
	clearPlayInputs(); picker:close(); journal:close(); roomView:setMenuOpen(true)
 clientUI.fieldView=clientUI.FieldQuestText.read(board,clientUI.fieldCache)
 gameMenu:setFieldObjective(clientUI.fieldView or false,board:GetAttribute("FieldPhase"))
	gameMenu:update(nurseryState, nil, nil, board:GetAttribute("Score"), board:GetAttribute("PeakChain"), board:GetAttribute("BestScore"), nurseryView.selected)
	gameMenu:open();return true
end
roomView.onOpenMenu=function()if openMenu()then clientUI.accepted("confirm")end end
picker.onAccepted=clientUI.accepted;journal.onAccepted=clientUI.accepted;gameMenu.onAccepted=clientUI.accepted;nurseryView.onAccepted=clientUI.accepted

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
		modalShade.Visible = modal.Visible or picker.shade.Visible or journal.shade.Visible or nurseryView:isOpen() or clientUI.isHueOpen() or gameMenu.shade.Visible
  if modalShade.Visible then rendererPresentation.setFieldOwner(false,board:GetAttribute("ResetId"),reduceEffects())end
		if clientUI.syncPause then clientUI.syncPause()else request:FireServer("pause",modalShade.Visible)end
	end
	for _, node in ipairs({ modal, picker.shade, journal.shade, nurseryView.shade, gameMenu.shade, clientUI.hueView.shade }) do
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
		overlay=modal.Visible or isPickerOpen() or journal.shade.Visible or nurseryView:isOpen() or clientUI.isHueOpen()
			or gameMenu.shade.Visible or GuiService.MenuIsOpen, reduced=reduceEffects() }
end
-- The Pocket Deck boot plays in the deck LCD on a real arrival (UI-SPEC section 6).
roomView.transition.deckBoot=clientUI.deck.boot
roomView.transition.deckVisible=function() return clientUI.deck.visible==true end
for _,name in ipairs({"RoundOver","ReducedEffects","Mode"}) do
	board:GetAttributeChangedSignal(name):Connect(function() roomView.transition:refresh() end)
end
GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function() roomView.transition:refresh() end)
-- The resting pet answers the round's end: a double hop for a win, startled then
-- sleepy for a loss. Local presentation; the Welcome hatch round is left alone.
board:GetAttributeChangedSignal("RoundOver"):Connect(function()
 if board:GetAttribute("RoundOver")~=true or board:GetAttribute("Mode")~="Board"or board:GetAttribute("FieldPhase")=="Welcome"then return end
 local serial=board:GetAttribute("ResetId")
 task.defer(function()
  if board:GetAttribute("ResetId")~=serial or board:GetAttribute("RoundOver")~=true then return end
  roomView:cheerPet(if board:GetAttribute("FieldSuccess")==true then "win"else "loss")
 end)
end)
GuiService.MenuOpened:Connect(function() roomView.transition:refresh() end)

local function updateClub()
	local sound = board:GetAttribute("SoundLevel") or Settings.DefaultSound
	picker:updateClub(board:GetAttribute("OwnedPets") or 0, board:GetAttribute("TrialMask") or 0,
		board:GetAttribute("PeakChain") or 0, board:GetAttribute("Score") or 0, sound,
		board:GetAttribute("ReducedEffects") == true, GuiService.ReducedMotionEnabled, board:GetAttribute("InventoryMask"),audio:isMusicEnabled(),nurseryState and nurseryState.totalWins,nurseryState and nurseryState.masteryRanks)
	if nurseryState then picker:setShopState(nurseryState.nectar,nurseryState.faceplates,nurseryState.ballThemes,nurseryState.revision)end
end

openPicker = function(mode,back,source)
	mode=mode or "Shell"
	if mode~="Settings"and mode~="Trials"and source~="workbench"then return false end
	cancelHatchNavigation()
	if isPickerOpen() or roomView.busy or clientUI.isHueOpen() or (board:GetAttribute("Mode") == "Board" and modal.Visible) then
		return
	end
	clearPlayInputs()
	rail.Interactable = false
	local themeId, stickerId = equippedAppearance()
	updateClub()
	clientUI.pickerReturn=back
 picker.customizationEntry=source=="workbench"
	picker:open(themeId, stickerId,mode)
	if picker:shopOpen() then GuiService.SelectedObject=nil
	elseif isGamepad(UserInputService:GetLastInputType()) then
		GuiService.SelectedObject = picker.tabs[picker.active]or (if picker.active=="Settings"then picker.sound else picker.cancel)
	end
 return true
end
openJournal = function()
	cancelHatchNavigation()
 return roomView.care and roomView.care:station()or false
end
-- The shared cache owns both native station visibility and final activation validation.
for _,overlay in ipairs({modal,picker.shade,journal.shade,nurseryView.shade,gameMenu.shade,clientUI.hueView.shade})do
	roomView.stations:watch(overlay:GetPropertyChangedSignal("Visible"))
end
roomView.stations:watch(GuiService.MenuOpened)
roomView.stations:watch(GuiService.MenuClosed)
roomView.stations:watch(UserInputService.TextBoxFocused)
roomView.stations:watch(UserInputService.TextBoxFocusReleased)
roomView.stations:refresh()

local lastSavePresentation
refreshSaveNotice=function()
	if not gui.Parent or roomView.destroyed then return end
	local owner=if currentSaveNotice then clientUI.SaveNotice.owner({
		native=GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox()~=nil or roomView.busy or roomView.transition.shade.Visible,
		eggs=nurseryView:isOpen() or clientUI.isHueOpen(),style=isPickerOpen(),journal=journal.shade.Visible,menu=gameMenu.shade.Visible,
		modal=modal.Visible,recap=recap.visible,focusing=roomView.focusing,
		mode=if board:GetAttribute("Mode")=="Room"and roomView.mode=="Room"then "Room"else "Board"})else nil
	saveNoticeOwner=owner
	nurseryView:setSaveNotice(if owner=="eggs"and not clientUI.isHueOpen()then currentSaveNotice else nil)
    clientUI.hueView:setSaveNotice(if clientUI.isHueOpen()then currentSaveNotice else nil)
	picker:setSaveNotice(if owner=="style"then currentSaveNotice else nil)
	journal:setSaveNotice(if owner=="journal"then currentSaveNotice else nil)
	gameMenu:setSaveNotice(if owner=="menu"then currentSaveNotice else nil)
	roomView.focusUI:setSaveNotice(if owner=="roam"or owner=="focus"then currentSaveNotice else nil)
	nurseryView.cinematic:refreshOwner()
	status.Visible=not (currentSaveNotice~=nil and owner~="board")
	if owner~="board"then status:SetAttribute("AccessibleLabel",nil)end
	if owner=="board"then
		Art.type(status,"Body",backdrop:GetAttribute("CompactInstruction")==true)
		if backdrop:GetAttribute("CompactInstruction")then status.TextSize=12 end
		local captionKey=currentSaveNotice.key..tostring(status.AbsoluteSize)..tostring(status.TextSize)..status.Font.Name..GuiService.PreferredTextSize.Name
		if boardSaveCaptionKey~=captionKey then
			boardSaveCaption=clientUI.SaveNotice.caption(currentSaveNotice,function(value)return Art.textWidth(status,value)<=status.AbsoluteSize.X-8 end)
			boardSaveCaptionKey=captionKey
		end
		status.Text=boardSaveCaption
		status:SetAttribute("AccessibleLabel",currentSaveNotice.detail)
		status.BackgroundTransparency,status.TextColor3=.08,Art.Amber;questHUD.host.Visible=false
		-- The persistent save state owns this same status well over transient drop copy.
		if dropCaption.Text~="DROP"then dropCaption.Visible=false end
	elseif owner=="recap"or owner=="welcome"then modalTag.Text=currentSaveNotice.short end
	gui:SetAttribute("SaveNoticeOwner",owner or "");gui:SetAttribute("SaveNoticeCode",if currentSaveNotice then currentSaveNotice.code else "")
	local key=(owner or "")..clientUI.SaveNotice.key(currentSaveNotice)
	if key~=lastSavePresentation then
		lastSavePresentation=key
		if layout and not saveNoticeLayoutQueued then
			saveNoticeLayoutQueued=true;task.defer(function()saveNoticeLayoutQueued=false;if gui.Parent then layout()end end)
		end
	end
end
local saveNoticeConnections={}
local function watchSaveNotice(signal)
	table.insert(saveNoticeConnections,signal:Connect(function()refreshSaveNotice()end))
end
for _,node in ipairs({modal,picker.shade,journal.shade,nurseryView.shade,gameMenu.shade,clientUI.hueView.shade,roomView.controls,roomView.focusUI.panel,roomView.transition.shade})do
	watchSaveNotice(node:GetPropertyChangedSignal("Visible"))
end
watchSaveNotice(GuiService.MenuOpened);watchSaveNotice(GuiService.MenuClosed)
watchSaveNotice(UserInputService.TextBoxFocused);watchSaveNotice(UserInputService.TextBoxFocusReleased)
table.insert(saveNoticeConnections,board:GetAttributeChangedSignal("SaveStatus"):Connect(function()
	currentSaveNotice=clientUI.SaveNotice.resolve(board:GetAttribute("SaveStatus"),nurseryState);refreshSaveNotice()
end))
gui.Destroying:Connect(function()for _,connection in ipairs(saveNoticeConnections)do connection:Disconnect()end;table.clear(saveNoticeConnections)end)
refreshSaveNotice()

customizeButton.Activated:Connect(function() if openMenu and openMenu()then clientUI.accepted("confirm")end end)
do
 local theme,sticker,background=equippedAppearance()
 clientUI.appearanceIntent=clientUI.AppearanceIntent.new({themeId=theme,stickerId=sticker,revision=board:GetAttribute("AppearanceRevision")or 0,backgroundId=board:GetAttribute("DeckBackgroundId")or"canopy",
  send=function(payload)request:FireServer("appearanceSlot",payload)end,
  changed=function(state)picker:setAppearance(state);paintDeck(state.confirmedTheme,state.confirmedSticker,state.confirmedBackground)end})
 picker.onRetry=function(slot)return clientUI.appearanceIntent:retry(slot)end
 local function refreshFallbacks()
  if not gui.Parent then return end
  local raw=board:GetAttribute("AppearanceFallbacks");local ok,values=pcall(function()return if type(raw)=="string"then HttpService:JSONDecode(raw)else {}end)
  clientUI.appearanceIntent:setFallbacks(if ok then values else {})
 end
 refreshFallbacks()
 local fallbackConnection=board:GetAttributeChangedSignal("AppearanceFallbacks"):Connect(function()task.defer(refreshFallbacks)end)
 picker:setAppearance(clientUI.appearanceIntent:view());paintDeck(theme,sticker,background)
 local result=remotes:WaitForChild("AppearanceResult")
 local resultConnection=result.OnClientEvent:Connect(function(message)clientUI.appearanceIntent:receive(message)end)
 local revisionConnection=board:GetAttributeChangedSignal("AppearanceRevision"):Connect(function()
  task.defer(function()if gui.Parent then local t,s,b=equippedAppearance();clientUI.appearanceIntent:snapshot(t,s,board:GetAttribute("AppearanceRevision")or 0,b)end end)
 end)
 gui.Destroying:Connect(function()resultConnection:Disconnect();revisionConnection:Disconnect();fallbackConnection:Disconnect();clientUI.appearanceIntent:destroy()end)
end

local function nextTier()
	return board:GetAttribute("NextTier") or 1
end

local function project(position)
	local size = viewport.AbsoluteSize
	local pixelsPerStud = size.X / (Config.Width + 0.8)
	return Vector2.new(size.X / 2 + position.X * pixelsPerStud,
		size.Y / 2 - (position.Y - Config.Height / 2) * pixelsPerStud), pixelsPerStud
end
rendererPresentation.restoreCheap=function(now,reduced)
 for source,view in pairs(eggViews)do view.gel:render(source.Position,0,now,project,true,reduced)end
end


local function drawAim()
	local tier = nextTier()
	local position, scale = project(Config.launchPosition())
	local diameter = Config.Tiers[tier].radius * 2 * scale
	track.Position = UDim2.fromOffset(position.X, position.Y)
 track.Tangent.Size = UDim2.fromOffset(2,Config.GuideLength*scale)
 track.Rotation=-math.deg(Config.aimAngle(aim))
 for index,dot in ipairs(aimDots)do
  local point=project(Config.flightPoint(aim,index*Config.PreviewStep));dot.Position=UDim2.fromOffset(point.X,point.Y)
 end
	ghost.Position = UDim2.fromOffset(position.X, position.Y)
	ghost.Size = UDim2.fromOffset(diameter, diameter)
	ghost.Text = ""
	ghost.BackgroundColor3 = clientUI.JellyPalette.byTier[tier].body
	-- No numerals (batch R1): the size's colour word.
	nextReadout.Text = clientUI.BallThemes.word(tier) .. " · " .. clientUI.BallThemes.word(board:GetAttribute("PreviewTier1") or 1)
		.. " · " .. clientUI.BallThemes.word(board:GetAttribute("PreviewTier2") or 1)
	nextReadout.TextColor3 = clientUI.JellyPalette.byTier[tier].body
	if queuePieces then
		for index,piece in ipairs(queuePieces)do local t=if index==1 then tier else (board:GetAttribute("PreviewTier1") or 1);Art.jellyPreview(piece,t,piece.Mark);piece.Mark.Text=clientUI.BallThemes.word(t)
			if queueHost:GetAttribute("InlineTiers") then piece.Parent.Caption.Text=(if index==1 then "Now " else "Next ")..piece.Mark.Text;piece.Parent.Caption.TextColor3=clientUI.JellyPalette.byTier[t].body end
		end
		if queueHost:GetAttribute("CombinedTiers") then
			queuePieces[1].Parent.Caption.Text="Now "..queuePieces[1].Mark.Text.."/Next "..queuePieces[2].Mark.Text
			queuePieces[1].Parent.Caption.TextColor3=Art.Silver
		end
	end
	local overflow = project(Vector2.new(0, board:GetAttribute("DangerY") or Config.OverflowY))
	clientUI.danger:place(scale * 0.4, scale * Config.Width, overflow.Y)
end

local lastTrialMask = board:GetAttribute("TrialMask") or 0
local trialNotice, trialNoticeUntil

local function shouldCoachField()
	return nurseryState and nurseryState.status == "Ready" and (board:GetAttribute("OwnedPets") or 0) > 0
		and board:GetAttribute("FieldPhase") == "Playing" and canAim() and not isPickerOpen() and not roomView.busy
end

-- Deck HUD/results data. Presentation only: every number is a replicated board
-- attribute or the saved receipt.
function clientUI.inputKind()
 local kind=UserInputService:GetLastInputType()
 if isGamepad(kind)then return "Gamepad"elseif kind==Enum.UserInputType.Touch then return "Touch"end
 return "Keyboard"
end
function clientUI.deckGoals(view,stage)
 local goals={}
 if not view or view.empty or type(view.goals)~="table"then return goals end
 for index,goal in ipairs(view.goals)do
  local full,candidates=clientUI.FieldQuestText.goal(goal,nil,true,14)
  local done=if stage then index<=stage else(view.complete==true or index<(view.step or 1))
  local current=not stage and index==view.step and not view.complete
  local zone=type(goal.zone)=="table"and goal.zone.kind or "any"
  goals[index]={text=full,short=candidates[1]or full,spoken=(clientUI.FieldQuestText.goal(goal)),done=done,progress=if current then view.progress or 0 else 0,target=goal.target or 1,
   icon={kind=goal.kind or "merge",tier=goal.tier or goal.minTier or 1,plus=goal.minTier~=nil,zone=zone}}
 end
 return goals
end
function clientUI.dailyRows()
 local rows={}
 local quests=nurseryState and nurseryState.quests
 for index,row in ipairs(quests and quests.daily or {})do
  if index>3 then break end
  rows[index]={title=row.title,progress=row.progress or 0,target=row.target or 1,done=row.claimed==true or row.ready==true,ready=row.ready==true}
 end
 return rows
end
-- Difficulty shown on the HUD and results: the server's run heat and payouts.
function clientUI.heatInfo(key)
 local Config=require(game:GetService("ReplicatedStorage").Shared.BoardConfig)
 local Payout=require(game:GetService("ReplicatedStorage").Shared.HeatPayout)
 key=if Config.validHeat(key)then key else Config.DefaultHeat
 return Config.Heat[key],Payout.label(key)
end
function clientUI.questTitle(id)
 local def=require(game:GetService("ReplicatedStorage").Shared.QuestCatalog).ById[id]
 return def and def.title
end
-- Compact shortcuts: "1/3" daily claimed count, any quest ready, and the first
-- quest this round finished (title) for the results shortcut.
function clientUI.questCount()
 local q=nurseryState and nurseryState.quests
 local daily=q and q.daily or {}
 local done=0;for _,r in ipairs(daily)do if r.claimed then done+=1 end end
 return string.format("%d/%d",done,#daily)
end
function clientUI.anyQuestReady()
 local q=nurseryState and nurseryState.quests;if not q then return false end
 for _,scope in ipairs({"daily","weekly"})do for _,r in ipairs(q[scope]or {})do if r.ready then return true end end end
 return q.bonusReady==true
end
function clientUI.finishedQuest(reward)
 local q=nurseryState and nurseryState.quests
 local function claimed(scope,id)
  for _,r in ipairs(q and q[scope]or {})do if r.id==id then return r.claimed==true end end
  return false
 end
 for _,moved in ipairs(reward and reward.quests or {})do
  if moved.done and not claimed(moved.scope or "daily",moved.id)then return(if moved.scope=="weekly"then "Weekly: "else "")..(clientUI.questTitle(moved.id)or moved.id),moved.scope end
 end
 return nil
end
-- The round is paused while a modal, the quest log or the Pocket Menu is up
-- (the server keeps one flag, so every owner goes through here).
function clientUI.syncPause()
 if clientUI.syncItemChip then clientUI.syncItemChip()end
 -- The item carousel is the third deck owner (BUILD-PLAN 2026-11-13 item 6).
 request:FireServer("pause",clientUI.ItemCarousel.pauseWanted({modal=modalShade.Visible,questLog=clientUI.questLog.visible,
  pocketMenu=clientUI.pocketMenu.visible,carousel=clientUI.items~=nil and clientUI.items.isOpen,roundOver=board:GetAttribute("RoundOver")==true,
  book=clientUI.book~=nil and clientUI.book:isOpen()and board:GetAttribute("Mode")=="Board"}))
end
function clientUI.pocketShouldClose()
 return recap.visible or modalShade.Visible or board:GetAttribute("Mode")~="Board"or board:GetAttribute("RoundOver")==true or roomView.busy
end
function clientUI.weeklyLine()
 local q=nurseryState and nurseryState.quests
 if not q then return ""end
 local done=0;for _,r in ipairs(q.weekly or {})do if r.claimed or r.ready then done+=1 end end
 return "Weekly "..done.."/"..#(q.weekly or {})
end
function clientUI.resultsData(final,runReceipt,score,best,peakChain)
 local owned=board:GetAttribute("OwnedPets")or 0
 local field=board:GetAttribute("HatchActive")==true and owned>0
 local success=if final then final.success else board:GetAttribute("FieldSuccess")
 local reason=if final then final.reason else board:GetAttribute("FieldReason")
 local stage=if final then final.stage else board:GetAttribute("FieldFinalStage")or 0
 local objective=if final and final.objective then final.objective else clientUI.fieldView
 local status=board:GetAttribute("RewardStatus")
 local pending=field and status~="Refused"and(status~="Saved"or runReceipt==nil)
 local rows,reward={},runReceipt
 local heat,heatLabel=clientUI.heatInfo(reward and reward.heat or board:GetAttribute("Heat"))
 local Payout=require(ReplicatedStorage.Shared.HeatPayout)
 if reward then
  -- Payout rows (celebrations 2.6): "Round win" is a plain win at this
  -- difficulty, "Tidy stack" the tidy share on top, then 2x Stars and
  -- Supporter. Same total as the receipt and never a minus row.
  local base=reward.base or 0
  local roundStars=reward.roundStars or base
  local ok,win=pcall(Payout.roundStars,math.min(base,Payout.Win),heat.key)
  win=if ok then math.min(win,roundStars)else roundStars
  table.insert(rows,{name="Round win",amount=win})
  if roundStars>win then table.insert(rows,{name="Tidy stack",amount=roundStars-win,signed=true})end
  local doubled=(reward.total or roundStars)-roundStars-(reward.bonus or 0)
  if doubled>0 then table.insert(rows,{name="2× Stars",amount=doubled,signed=true})end
  if(reward.bonus or 0)>0 then table.insert(rows,{name="Supporter",amount=reward.bonus,signed=true})end
 end
 -- The quest this round moved (come-back strip), first daily then weekly.
 local quest
 for _,moved in ipairs(reward and reward.quests or {})do
  if not quest or(quest.scope=="weekly"and moved.scope~="weekly")then
   quest={scope=moved.scope or "daily",title=clientUI.questTitle(moved.id)or moved.id,count=moved.count or 0,target=moved.target or 1,moved=1,done=moved.done==true}
  end
 end
 -- Cheapest egg on sale (Toy Egg until every toy is owned, then Hue Egg).
 local egg={name="Toy Egg",cost=require(ReplicatedStorage.Shared.ToyCatalog).Cost}
 local okToys,toysLeft=pcall(require(ReplicatedStorage.Shared.ToyCatalog).remaining,nurseryState and nurseryState.toyUnlocks)
 if okToys and type(toysLeft)=="table"and #toysLeft==0 then egg={name="Hue Egg",cost=require(ReplicatedStorage.Shared.HueCatalog).Cost}end
 -- Difficulty nudge: the next step up after a win, this difficulty after a miss.
 local nudge
 pcall(function()
  local Config=require(ReplicatedStorage.Shared.BoardConfig)
  local UICopy=require(ReplicatedStorage.Shared.UICopy)
  if success==true then
   local up=({easy="medium",medium="hard"})[heat.key]
   if up then local low,high=Payout.range(up);nudge=UICopy.get("results.nudge.up",{heat=Config.Heat[up].name,low=low,high=high})end
  else
   local low,high=Payout.range(heat.key);nudge=UICopy.get("results.nudge.again",{heat=heat.name,low=low,high=high})
  end
 end)
 local strip={}
 for _,moved in ipairs(reward and reward.quests or {})do
  if #strip>=2 then break end
  table.insert(strip,(if moved.scope=="weekly"then "Weekly: "else "")..(clientUI.questTitle(moved.id)or moved.id).." "..moved.count.."/"..moved.target..(if moved.done then "  · CLAIM IN LOG"else ""))
 end
 local balance=nurseryState and nurseryState.nectar or 0
 return{outcome=if success==true then "clear"elseif reason=="Overflow"then "overflow"else "missed",
  title=if objective and not objective.empty and objective.title then objective.title else "Round",difficulty=heat.name,multiplierLine=heat.name.." "..heatLabel,
  pending=pending,earned=reward and reward.total or 0,total=reward and reward.total or 0,rows=rows,balance=balance,
  loss=not pending and(reward==nil or(reward.total or 0)==0),goals=clientUI.deckGoals(objective,stage or 0),
  score=score,best=best,chain=peakChain,newBest=board:GetAttribute("NewBest")==true,
  strip=if #strip>0 then table.concat(strip,"   ")else(if field then "No quest finished this round"else "Win a round to earn Stars"),
  stripRight=if balance>=egg.cost then "You can hatch an egg"else clientUI.weeklyLine(),
  canLeave=owned>0,level=heat.index,questCount=clientUI.questCount(),canHatch=owned>0 and balance>=egg.cost,
  questDone=clientUI.finishedQuest(reward),
  tidy=success==true and reward~=nil and(reward.base or 0)>=Payout.TidyWin,eggName=egg.name,eggCost=egg.cost,
  quest=quest,nudge=nudge,petName=(Pets.byId.pip and Pets.byId.pip.name)or "Bear",
  result={status=status,receiptPending=status=="Saved"and runReceipt==nil,reward=runReceipt,sequence=board:GetAttribute("RunSequence")}}
end
-- The view's back arrow: shown on every deck screen, hidden under sheets and the
-- hatch card (they own their own close), disabled until the first pet exists.
function clientUI.refreshBack()
 local visible=board:GetAttribute("Mode")=="Board"and not modalShade.Visible and backdrop.Visible
 local enabled=(board:GetAttribute("OwnedPets")or 0)>0 and not roomView.busy
 clientUI.deck.backVisible=visible
 local arrow=clientUI.deck.back
 if arrow.root.Visible~=visible then arrow.root.Visible=visible end
 if arrow.enabled~=enabled then arrow.setEnabled(enabled)end
end
-- Leave the deck for the garden (the old Lounge cap path).
function clientUI.leaveDeck()
 if roomView.busy or(board:GetAttribute("OwnedPets")or 0)==0 or board:GetAttribute("Mode")~="Board"then return false end
 if clientUI.pocketMenu.visible then clientUI.closePocketMenu(true)end
 cancelHatchNavigation();clearPlayInputs();recap:hide()
 roomView:collapseControls()
 roomView:requestSwitch(function()if not isPickerOpen()then request:FireServer("mode","Room")end end)
 clientUI.accepted("back");return true
end

updateHud = function()
 clientUI.fieldView=clientUI.FieldQuestText.read(board,clientUI.fieldCache)
 if rendererPresentation.roundEnd then rendererPresentation.roundEnd:observe()end
 local final=rendererPresentation.roundEnd and rendererPresentation.roundEnd.frozen
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
				trialNotice = "All Pocket Trials complete!"
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
	if knownPets~=owned and layout then task.defer(layout)end
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
	dispenser:setTheme(Themes.ById[board:GetAttribute("DeckThemeId")]or Themes.ById[Themes.Default])
	dispenser:update(board:GetAttribute("ResetId"),drops,budget,owned > 0 and board:GetAttribute("Mode")=="Board",rendererPresentation.canPresent(board:GetAttribute("ResetId")))
	for _,cell in ipairs(segments)do cell.Visible=false end
	meterText.Visible=owned==0
	meterText.Text = if owned > 0 then string.format("%d/%d", remaining, budget) else string.format("%s %d/%d", Pets.byId.pip.name, charge, nextPet and nextPet.charge or 6)
	eggGoal.Visible = not backdrop:GetAttribute("CompactLandscape") and not backdrop:GetAttribute("SideGoalLayout") and owned > 0 and shell.AbsoluteSize.Y >= 260
	eggGoalText.Text = Stars.format("MEADOW EGG\n%d/18 Stars", nurseryState and nurseryState.nectar or 0)
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
 if nurseryActive and owned>0 then
  rareGoal.Text=clientUI.FieldQuestText.describe(clientUI.fieldView,board:GetAttribute("FieldPhase")).instruction
 end
 local mode=board:GetAttribute("Mode")
 clientUI.fieldCopy=clientUI.FieldQuestText.describe(clientUI.fieldView,board:GetAttribute("FieldPhase"))
 for _,item in ipairs(fieldZones)do
  item.node.Visible=nurseryActive and owned>0
  item.node.BackgroundTransparency=if clientUI.fieldCopy.zone==(if item.side==-1 then "left"else "right")then .15 else .45
 end
 clientUI.centerZone.Visible=nurseryActive and owned>0 and clientUI.fieldCopy.zone=="center"
 if clientUI.centerZone.Visible then
  clientUI.centerZone.Position=UDim2.fromScale(.5+clientUI.fieldCopy.goal.zone.min/(Config.Width+.8),.025)
  clientUI.centerZone.Size=UDim2.fromScale((clientUI.fieldCopy.goal.zone.max-clientUI.fieldCopy.goal.zone.min)/(Config.Width+.8),.95)
 end
    if lcd then
        local region=clientUI.fieldCopy.goal and clientUI.fieldCopy.goal.zone
        lcd:setRegions(nurseryActive and owned>0,clientUI.fieldCopy.zone,board:GetAttribute("FieldZoneBound")or 2.6,region and region.min,region and region.max)
    end
	local showHatch = hatchPet ~= nil and mode == "Board"
	local over = mode == "Board" and board:GetAttribute("RoundOver") == true and not showHatch
	local wasVisible = modal.Visible
	local sheetOpen=isPickerOpen() or journal.shade.Visible or nurseryView:isOpen() or clientUI.isHueOpen() or gameMenu.shade.Visible
	modal.Visible = showHatch and not over and not sheetOpen
	if modal.Visible or(over and not sheetOpen)then
		clearPlayInputs()
		picker:close()
	end
	Art.type(status,"Body",false)
	status.TextSize=if instrumentLayout and instrumentLayout.roomy then 20 elseif backdrop:GetAttribute("CompactInstruction") then 12 else 16
	status.TextWrapped=true
	local lesson = firstHatchGuide:step(drops, merges, charge, owned, UserInputService:GetLastInputType(),
		clientUI.BallThemes.word(nextTier()), canPlay(), backdrop:GetAttribute("CompactInstruction")==true)
	local fieldCoaching = false
	firstHatchGuide:fieldStep(0, 1, false)
	local fieldActive = nurseryActive and owned > 0
	questHUD:update(board:GetAttribute("FieldStage") or 0,board:GetAttribute("FieldPhase"),fieldActive,backdrop:GetAttribute("CompactInstruction")==true,clientUI.fieldView or false)
	status.ClipsDescendants = true
	status.BackgroundTransparency = if lesson or fieldCoaching or fieldActive then 0.08 else 1
	status.TextColor3 = if lesson or fieldCoaching then Art.Silver else title.TextColor3
	status.Text = if fieldActive then "" elseif fieldCoaching then "" elseif lesson then lesson elseif trialNoticeUntil and os.clock() < trialNoticeUntil
		then (if status.AbsoluteSize.Y<60 then "Trial complete!" else trialNotice) else (if status.AbsoluteSize.Y<60 then "Quest +6 Stars" else "Win quest +6 Stars\nLow pile +2 bonus")
	pet.Visible = showHatch == true and not over
	hatchStage.Visible = pet.Visible
	hatchIndex.Visible = pet.Visible and not modal:GetAttribute("CompactDialog")
	modalTag.Text = if hatchPet and hatchPet.trial then "RARE HATCH" else "POCKET HATCHERY"
	local runReceipt = RunReceipt.select(nurseryState, board:GetAttribute("RunSequence"), board:GetAttribute("RewardStatus"), over)
	-- Results live inside the deck LCD and hand the board back on Replay or Leave.
	local resultsOpen=over and not sheetOpen and not roomView.busy and not clientUI.questLog.visible
	local resultsOpened=resultsOpen and not recap.visible
	if resultsOpen then
		recap:show(clientUI.resultsData(final,runReceipt,score,best,peakChain),if clientUI.deckView~=nil then clientUI.deckView else clientUI.deckCompact==true)
	else recap:hide() end
	if resultsOpened then GuiService.SelectedObject=nil;if layout then task.defer(layout)end end
	modalTitle.Text = "You hatched " .. (hatchName or "") .. "!"
	readout.Text = if owned > 0 then tostring(nurseryState and nurseryState.nectar or 0) else tostring(score)
	scoreCaption.Text = if owned > 0 then "Stars" else "SCORE"
	scoreCaption.Visible=owned==0;walletDrop.Visible=owned>0
	layoutWallet(instrumentLayout)
	bestReadout.Text = if owned > 0 then "Stars · eggs from 8" else "BEST " .. best
	if gameMenu then gameMenu:setFieldObjective(clientUI.fieldView or false,board:GetAttribute("FieldPhase"));gameMenu:update(nurseryState, nil, nil, score, peakChain, best, nurseryView.selected) end
	-- The modal is now only the hatch card.
	modalAction.Text = "Meet " .. (hatchName or "")
	modalAction.Interactable,keepPlaying.Interactable = true,true
	modalAction.Position = UDim2.new(0.05, 0, 1, -52)
	modalAction.Size = UDim2.new(0.43, 0, 0, 44)
	keepPlaying.Visible = true
	keepPlaying.Text = "Keep playing"
	Art.control(modalAction,true,true);Art.control(keepPlaying,false,true)
	if modal.Visible and not wasVisible and isGamepad(UserInputService:GetLastInputType()) then
		GuiService.SelectedObject = modalAction
	elseif not modal.Visible and GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(modal) then
		GuiService.SelectedObject = nil
	end
	rail.Interactable = canAim() and not isPickerOpen()
	action.Interactable = canPlay()
	dropCaption.Text = if board:GetAttribute("FieldPhase") == "Settling" then "SETTLE"
		elseif nurseryState and nurseryState.status ~= "Ready" then
			(if nurseryState.status=="Busy" or nurseryState.status=="Retrying" or nurseryState.status=="Pending" then "SAVING"
				elseif nurseryState.status=="SessionLost" then "REJOIN" else "SAVE WAIT")
		elseif board:GetAttribute("FieldReady") == false then "FALLING" else "DROP"
	layoutDropCaption(dropCaptionLayout)
	if dropCaption:GetAttribute("BlockedCaption") then
		local candidates=if dropCaption.Text=="SETTLE" then {"Settling…","Settling","Wait"}
			elseif dropCaption.Text=="FALLING" then {"Falling…","Falling","Wait"}
			elseif dropCaption.Text=="SAVING" then {"Saving…","Saving","Wait"}
			elseif dropCaption.Text=="REJOIN" then {"Rejoin"} else {"Save wait","Wait"}
		for _,caption in ipairs(candidates)do
			status.Text=caption
			if Art.textWidth(status)<=status.AbsoluteSize.X-8 then break end
		end
		questHUD.host.Visible=false;status.BackgroundTransparency=.08;status.TextColor3=Art.Silver
	end
	local unlocked = owned > 0
	roomButton.Interactable = unlocked and not modal.Visible
	eggButton.Interactable = unlocked and not modal.Visible
	roomLip.Color = if unlocked then Palette.Primary else Palette.Rim
	roomCaption.TextTransparency = if unlocked then 0 else 0.35
	-- In-LCD HUD (wide deck) and the view's back arrow.
	local blocked=dropCaption:GetAttribute("BlockedCaption")
	clientUI.deck:setHud({score=score,best=best,chain=chain,goals=if fieldActive then clientUI.deckGoals(clientUI.fieldView)else {},
		message=if not fieldActive then status.Text else nil,statusLabel=if blocked then status.Text else nil,daily=clientUI.dailyRows(),
		next={nextTier(),board:GetAttribute("PreviewTier1")or 1,board:GetAttribute("PreviewTier2")or 1},
		eggsLeft=remaining,budget=budget,difficulty=clientUI.heatInfo(board:GetAttribute("Heat")).name,multiplier=select(2,clientUI.heatInfo(board:GetAttribute("Heat"))),
		winPays=board:GetAttribute("WinPays")or "…",input=clientUI.inputKind()})
	if clientUI.refreshDeckOverlays then clientUI.refreshDeckOverlays(over,sheetOpen,fieldActive,drops)end
	if clientUI.pocketMenu.visible and clientUI.pocketShouldClose()then clientUI.closePocketMenu(true)end
	clientUI.refreshBack()
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
	if refreshSaveNotice then refreshSaveNotice()end
end

layout = function()
	if rendererPresentation.jolt then rendererPresentation.jolt:reset()end
	clearPlayInputs()
	local screen=backdrop.AbsoluteSize
	local ratio=(Config.Width+.8)/(Config.Height+.8)
	local short=screen.X>=350 and screen.X>=screen.Y*1.2 and screen.Y<280
	local capSize=if screen.X>=1000 and screen.Y>=650 then 20 elseif short then 12 else 14
	local utilityW=math.ceil(TextService:GetTextSize("Lounge",capSize,Art.Font.Action,Vector2.new(1000,100)).X)+14
	local queueCaptionH=math.ceil(TextService:GetTextSize("Next",if screen.X>=1000 and screen.Y>=650 then 20 else 12,Art.Font.Body,Vector2.new(1000,100)).Y)
	local markBounds=TextService:GetTextSize("III",if screen.X>=1000 and screen.Y>=650 then 20 else 12,Art.Font.Counter,Vector2.new(1000,100))
	local markD=math.max(18,math.ceil(math.max(markBounds.X,markBounds.Y))+6)
	local lineH=queueCaptionH+4
	local roomyQueueCaptionH=math.ceil(TextService:GetTextSize("Next",if screen.X>=1000 and screen.Y>=650 then 20 else 14,Art.Font.Body,Vector2.new(1000,100)).Y)+4
	local walletH=math.ceil(TextService:GetTextSize("0",if screen.X>=1000 and screen.Y>=650 then 20 else 18,Art.Font.Counter,Vector2.new(1000,100)).Y)+4
	local l=DeckLayout.resolve(screen,ratio,{utilityWidth=utilityW,utilityHeight=math.max(44,math.ceil(TextService:GetTextSize("Lounge",capSize,Art.Font.Action,Vector2.new(1000,100)).Y)+8),queueHeight=math.max((if short then lineH else roomyQueueCaptionH)+markD+10,lineH*2+8),lineHeight=lineH,walletLineHeight=walletH,countWidth=TextService:GetTextSize("24/24",12,Art.Font.Counter,Vector2.new(1000,100)).X+4})
 questHUD.roomy=l.roomy;dispenser.roomy=l.roomy
 clientUI.fieldView=clientUI.FieldQuestText.read(board,clientUI.fieldCache)
	local instructionCompact=l.short or l.dense or l.quest.h<60
	if (board:GetAttribute("OwnedPets")or 0)>0 then
		-- Field content only; welcome retains the exact pre-existing coaching band.
		if l.lateral and not l.dense and not l.short then l.quest.y=l.wallet.y+l.wallet.h+6 end
		DeckLayout.fitFieldQuest(l,questHUD:preferredHeight(l.quest.w,l.quest.h,instructionCompact,clientUI.fieldView or false))
	end
	DeckLayout.fitInstruments(l,dispenser:preferredHeight(l.meter.w,l.meter.h))
	instrumentLayout=l
 Art.setBackdropCase(backing,{x=l.shell.x+backdrop.AbsolutePosition.X-backing.AbsolutePosition.X,y=l.shell.y+backdrop.AbsolutePosition.Y-backing.AbsolutePosition.Y,w=l.shell.w,h=l.shell.h})
	backdrop:SetAttribute("CompactLandscape",l.short)
	backdrop:SetAttribute("CompactInstruction",instructionCompact)
	backdrop:SetAttribute("SideGoalLayout",true)
	local function place(node,r)node.Position,node.Size=UDim2.fromOffset(r.x,r.y),UDim2.fromOffset(r.w,r.h)end
	place(shell,l.shell);place(bezel,l.bezel);place(viewport,l.tray);overlay.Position,overlay.Size=viewport.Position,viewport.Size
	local showEtching=not l.lateral or (l.left.w>=160 and Art.textWidth(title)+40<=l.left.w)
	for _,name in ipairs({"SproutLeaf","DropMark","ModelStamp"}) do
		local etching=shell:FindFirstChild(name)
		if etching then etching.Visible=showEtching end
	end
	local radius=if l.lateral then math.clamp(math.floor(l.shell.h*.075),18,32)else 23
	shell.ShellCurve.CornerRadius=UDim.new(0,radius)
	shell.Faceplate:FindFirstChildOfClass("UICorner").CornerRadius=UDim.new(0,radius-4)
	shell.MoldSeam:FindFirstChildOfClass("UICorner").CornerRadius=UDim.new(0,radius-5)
	place(rail,l.tray);rail.BackgroundTransparency=1;clientUI.railReadouts.ReadoutDivider.Visible=false
	bestReadout.Visible,nextReadout.Visible,mascot.Visible=false,false,false
	Art.type(scoreCaption,"Supporting",l.short or l.dense or not l.lateral);if l.roomy then scoreCaption.TextSize=20 end
	layoutWallet(l)
	place(queueHost,l.queue)
	local nextWidth=TextService:GetTextSize("Next",12,Art.Font.Body,Vector2.new(1000,100)).X+8
	local verticalQueue=l.lateral and not l.inlineQueue and l.queue.w/2-4<nextWidth
	local inlineQueue=l.inlineQueue==true or verticalQueue or (not l.lateral and lineH+markD+2>l.queue.h)
	local combinedQueue=inlineQueue and not verticalQueue and l.queue.h<lineH*2+4 and TextService:GetTextSize("Next III",12,Art.Font.Body,Vector2.new(1000,100)).X+6>l.queue.w/2-4
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
		Art.type(caption,"Supporting",l.short or l.dense or not l.lateral);if l.roomy then caption.TextSize=20 end
		local inset=caption:FindFirstChildOfClass("UIPadding");if inset then inset:Destroy() end
		local captionH=math.ceil(TextService:GetTextSize("Next",caption.TextSize,caption.Font,Vector2.new(1000,100)).Y)+4
		piece.Visible=not inlineQueue and not combinedQueue
		Art.type(piece.Mark,"Counter",true);if l.roomy then piece.Mark.TextSize=20 end
		local markInset=piece.Mark:FindFirstChildOfClass("UIPadding");if markInset then markInset:Destroy() end
		local d=markD
		piece.Position,piece.Size=UDim2.new(.5,-d/2,0,captionH+6),UDim2.fromOffset(d,d)
		caption.Position=UDim2.fromOffset(2,if inlineQueue then 0 else 4)
		caption.Size=UDim2.new(1,-4,0,captionH)
		local word=if index==1 then "Now"else "Next"
		caption:SetAttribute("QueueWord",word)
		caption.Text=if inlineQueue then (if index==1 then "Now " else "Next ")..piece.Mark.Text else word
		caption.TextColor3=if inlineQueue then clientUI.JellyPalette.byTier[piece:GetAttribute("JellyTier")or 1].body else Art.Muted
	end
	if combinedQueue then queuePieces[1].Parent.Caption.Text="Now "..queuePieces[1].Mark.Text.."/Next "..queuePieces[2].Mark.Text;queuePieces[1].Parent.Caption.TextColor3=Art.Silver end
	place(status,l.quest);status.ClipsDescendants=true
	place(meter,l.meter);rareGoal.Visible,eggGoal.Visible=false,false
	meterText.Position,meterText.Size=UDim2.fromOffset(2,0),UDim2.new(1,-4,1,0)
	Art.type(meterText,if l.roomy then "Counter"else "Body",false)
	meterText.TextSize=if l.roomy then 20 elseif l.short then 12 else 16
	meterText.TextStrokeTransparency=1
	place(hardware,l.shell)
	dpad.Position,dpad.Size=UDim2.fromOffset(l.dpad.x-l.shell.x,l.dpad.y-l.shell.y),UDim2.fromOffset(l.dpad.w,l.dpad.h)
	dpad.RockerWell.Size=UDim2.fromOffset(l.dpad.w+6,l.aimSize+7)
	leftAim.Size,rightAim.Size=UDim2.fromOffset(l.aimSize,l.aimSize),UDim2.fromOffset(l.aimSize,l.aimSize)
	rightAim.Position=UDim2.fromOffset(l.aimSize+6,8)
	action.Position,action.Size=UDim2.fromOffset(l.drop.x-l.shell.x,l.drop.y-l.shell.y),UDim2.fromOffset(l.dropSize,l.dropSize)
	action.TextSize=math.floor(l.dropSize*.5)
	hardware.DropWell.Position,hardware.DropWell.Size=action.Position+UDim2.fromOffset(-3,1),UDim2.fromOffset(l.dropSize+6,l.dropSize+5)
	local previousBlocked=dropCaption:GetAttribute("BlockedCaption")
	layoutDropCaption(l)
	if previousBlocked~=dropCaption:GetAttribute("BlockedCaption") and not captionStatusQueued then
		captionStatusQueued=true;task.defer(function()captionStatusQueued=false;updateHud()end)
	end
	for index,button in ipairs({customizeButton,roomButton})do
		place(button,if index==1 then l.menu else l.lounge)
		button.KeyWell.Visible=false
		button.Cap.Position,button.Cap.Size=UDim2.new(.5,0,0,if l.roomy then 4 else 7),UDim2.new(1,-6,0,if l.roomy then math.max(44,button.Size.Y.Offset-8) else DeckLayout.Settings.UtilityCapHeight)
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
				Art.frame(icon,"Door","raised",UDim2.fromOffset(9,12),UDim2.fromOffset(4,6),icon.ZIndex+2)
			end
		end
		icon.Visible=l.compactUtilities==true
		button:SetAttribute("AccessibleLabel",if index==1 then "Menu" else "Lounge")
		button.Cap.Caption.Text=if l.compactUtilities then "" elseif index==1 then "Menu"else"Lounge"
		button.Cap.Caption.TextSize=if l.roomy then 20 elseif l.short then 12 else 14
	end
	eggButton.Visible=false
 title.Visible=false
 local markY=l.shell.y+(if l.roomy then 10 else 4)+(l.instrumentShiftLeft or 0)
 local markW,markH=clientUI.wordmark:layout(l.left.w-8,math.max(1,l.wallet.y-markY-8),if l.roomy then 30 else 24)
 clientUI.wordmark.root.Position=UDim2.fromOffset(l.left.x+(l.left.w-markW)/2,markY)
 clientUI.wordmark.root.Visible=clientUI.wordmark.root.Visible and l.lateral and not l.short and not l.dense
	vents.Visible=l.speakerVisible
	vents.Position=UDim2.fromOffset(l.speaker.x-l.shell.x,l.speaker.y-l.shell.y)
	hardware.MakerMark.Visible=false
	shell.Faceplate.AimSeat.Visible,shell.Faceplate.ActionSeat.Visible=false,false
	shell.Faceplate.AccentBands.Visible=false
 local zoneBound=board:GetAttribute("FieldZoneBound")or 2.6
 for _,item in ipairs(fieldZones)do
  item.node.AnchorPoint=Vector2.new(.5,0)
  item.node.Position=UDim2.fromScale(.5+item.side*zoneBound/(Config.Width+.8),.025)
  item.node.Size=UDim2.new(0,2,.95,0)
 end
	modal.Position=UDim2.fromScale(.5,.5)
	restoreLegacySaveParents()
	local modalSave=if saveNoticeOwner=="recap"or saveNoticeOwner=="welcome"then currentSaveNotice else nil
	local dialogHeight=math.min(300,math.max(1,screen.Y-(if modalSave then 16 else 32)))
	modal:SetAttribute("CompactDialog",dialogHeight<220)
	modal.Size=UDim2.fromOffset(math.min(440,screen.X-32),dialogHeight)
	modalTag.Visible=true;modalTitle.Visible=true
	modalTitle.Position=UDim2.fromOffset(0,18)
	local stageHeight=math.max(24,dialogHeight-110-(if dialogHeight<220 then 0 else 18))
	hatchStage.Size=UDim2.new(1,-24,0,stageHeight);hatchIndex.Position=UDim2.fromOffset(12,55+stageHeight)
	hatchIndex.Visible=pet.Visible and dialogHeight>=220
	pet.Position=UDim2.new(.5,0,0,55+stageHeight/2);pet.Size=UDim2.fromOffset(math.min(88,stageHeight-4),math.min(88,stageHeight-4))
	local portrait=pet:FindFirstChild("Portrait");if portrait then portrait.StageFit.Scale=math.min(1,pet.Size.Y.Offset/91)end
	if modalSave and not fieldRecap then
		Art.type(modalTag,"Supporting",true);modalTag.Text=modalSave.short
		local tagH=Art.textHeight(modalTag,modal.Size.X.Offset-24,22)
		modalTag.Position,modalTag.Size=UDim2.fromOffset(12,2),UDim2.new(1,-24,0,tagH)
		local bw=(modal.Size.X.Offset-36)/2
		Art.type(modalAction,"Body",true);Art.type(keepPlaying,"Body",true)
		if Art.textHeight(modalAction,bw,0)+8>44 then modalAction.Text="Meet"end
		if Art.textHeight(keepPlaying,bw,0)+8>44 then keepPlaying.Text="Play"end
		local footerH=math.max(44,Art.textHeight(modalAction,bw,0)+8,Art.textHeight(keepPlaying,bw,0)+8)
		modalAction.Position,modalAction.Size=UDim2.new(0,12,1,-footerH-4),UDim2.new(.5,-18,0,footerH)
		keepPlaying.Position,keepPlaying.Size=UDim2.new(.5,6,1,-footerH-4),UDim2.new(.5,-18,0,footerH)
		local top=tagH+8;local height=math.max(1,dialogHeight-top-footerH-8)
		legacySaveScroll.Position,legacySaveScroll.Size=UDim2.fromOffset(12,top),UDim2.new(1,-24,0,height)
		legacySaveContent.Size=UDim2.fromOffset(modal.Size.X.Offset-24,220)
		for _,node in ipairs({modalTitle,hatchStage,hatchIndex,pet,reveal.layer})do node.Parent=legacySaveContent end
		Art.type(legacySaveDetail,"Body",true);legacySaveDetail.Text=modalSave.detail
		local h=Art.textHeight(legacySaveDetail,modal.Size.X.Offset-32,24)
		legacySaveDetail.Position,legacySaveDetail.Size=UDim2.fromOffset(4,228),UDim2.fromOffset(modal.Size.X.Offset-32,h)
		local total=228+h+4;legacySaveScroll.CanvasSize=UDim2.fromOffset(0,total)
		legacySaveScroll.ScrollingEnabled=total>height;legacySaveScroll.Visible=true
		legacySaveScroll.CanvasPosition=Vector2.new(0,math.clamp(legacySaveScroll.CanvasPosition.Y,0,math.max(0,total-height)))
	end
	-- Wide screens use the Pocket Deck Slim: the board sits in the LCD's centre well
	-- and the HUD moves into the side panels. Portrait keeps the stacked case.
	local wide=l.lateral==true
	clientUI.legacyDeck.Visible=not wide;clientUI.railReadouts.Visible=not wide
	clientUI.deck:setVisible(wide)
	if wide then
		local kx,kh=require(script.DeckKit).keepOut()
		local g=clientUI.deck:layout(screen,ratio,{kx=kx,kh=kh})
		clientUI.deckCompact=g.compact
		clientUI.deckView=clientUI.deck:view() or g.compact
		place(viewport,g.board);overlay.Position,overlay.Size=viewport.Position,viewport.Size
		place(rail,g.board)
		Art.setBackdropCase(backing,{x=g.deck.x+backdrop.AbsolutePosition.X-backing.AbsolutePosition.X,y=g.deck.y+backdrop.AbsolutePosition.Y-backing.AbsolutePosition.Y,w=g.deck.w,h=g.deck.h})
	else
		clientUI.deckCompact=true;clientUI.deckView=true
		clientUI.deck:placeResults(l.shell)
	end
	clientUI.deck.back.root.Visible=clientUI.deck.backVisible~=false and backdrop.Visible
	if clientUI.items then clientUI.items:place(viewport.Position,viewport.Size,clientUI.deck.geometry~=nil and clientUI.deck.geometry.phone==true and wide)end
	if recap.visible and recap.key~=recap.viewKey(clientUI.deckView)then task.defer(updateHud)end
	local distance=(Config.Height+.8)/(2*math.tan(math.rad(trayCamera.FieldOfView/2)))
	trayCamera.CFrame=CFrame.lookAt(Vector3.new(0,Config.Height/2,distance),Vector3.new(0,Config.Height/2,0))
	if refreshSaveNotice then refreshSaveNotice()end
	if rendererPresentation.jolt then rendererPresentation.jolt:rebase()end
end

local function aimFromScreen(x)
 -- Hardware/hit targets recoil visibly; normalized launch aim uses the logical
 -- unjolted tray so motion under a stationary finger cannot steer the shot.
 aim=rendererPresentation.jolt:pointerAim(x,viewport.AbsolutePosition.X,viewport.AbsoluteSize.X)
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
	return clientUI.PresentationPolicy.ownsRecap({modal=recap.visible,recap=recap.visible,busy=roomView.busy,
		overlay=isPickerOpen() or journal.shade.Visible or nurseryView:isOpen() or clientUI.isHueOpen() or gameMenu.shade.Visible,
		coreMenu=GuiService.MenuIsOpen})
end

rendererPresentation.roundEnd=require(script.RoundEndPresentation).new(board,{
 readView=function()return clientUI.FieldQuestText.read(board,clientUI.fieldCache)end,
 reduced=reduceEffects,
 owns=function()
  return not rendererPresentation.destroyed and gui.Parent~=nil and gui.Enabled and backdrop.Visible
   and board:GetAttribute("Mode")=="Board"and audio.deviceActive~=false and not GuiService.MenuIsOpen
   and not UserInputService:GetFocusedTextBox()and not isPickerOpen()and not journal.shade.Visible
   and not nurseryView:isOpen()and not clientUI.isHueOpen()and not gameMenu.shade.Visible
   and not roomView.busy and not roomView.transition.shade.Visible and not modal.Visible
 end,
 target=function()return effects end,
})
rendererPresentation.roundEnd:observe()

local function requestRetry()
	cancelHatchNavigation()
	local sequence=RunReceipt.replaySequence(board:GetAttribute("RunSequence"),board:GetAttribute("RewardStatus"),(board:GetAttribute("OwnedPets")or 0)==0)
	if sequence and recapOwnsInput() and not UserInputService:GetFocusedTextBox() then
  clientUI.accepted("confirm")
		request:FireServer("reset",sequence)
  if not GuiService.MenuIsOpen then audio:play("retry",1,.6)end
  return true
	end
 return false
end

local function handleControl(name, state, input)
	local key = input.KeyCode
	if state == Enum.UserInputState.Cancel then
		table.clear(heldAim)
	elseif state == Enum.UserInputState.End then
		heldAim[key] = nil
	end
	local gamepad = isGamepad(input.UserInputType)
	if not canAim() or isPickerOpen() or roomView.busy or GuiService.MenuIsOpen
		or UserInputService:GetFocusedTextBox() or (gamepad and GuiService.SelectedObject) then
		return Enum.ContextActionResult.Pass
	end
	if state == Enum.UserInputState.Begin then
		if name == "EggDropDrop" then
			clientUI.deck:flash("A")
			dropEgg()
		elseif name == "EggDropCustomize" then
			if clientUI.openPocketMenu()then clientUI.accepted("confirm")end
		else
			startAim(key, if name == "EggDropLeft" then -1 else 1)
			clientUI.deck:flash(if name == "EggDropLeft" then "Left" else "Right")
		end
	end
	return Enum.ContextActionResult.Sink
end

local priority = Enum.ContextActionPriority.High.Value
-- Four ordinary sheets can acquire focus once after pointer use. Native focus and
-- activation remain the dispatchers; this coordinator only writes SelectedObject.
local controllerFocus=clientUI.ControllerFocus.new({
	read=function()
		local native=GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox()~=nil
		if native then return{native=true,blocked=true}end
		if roomView.destroyed or roomView.busy or roomView.switchQueued or roomView.transition.shade.Visible
			or roomView.focusing or (hatchNavigation and hatchNavigation.active)then return{blocked=true}end
		local owner
		-- The Wardrobe owns its own focus (ContextAction "EggDropWardrobe").
		if clientUI.isWardrobeOpen and clientUI.isWardrobeOpen()then return{blocked=true}end
		if clientUI.hub and clientUI.hub:isOpen()then return{blocked=true}end
		if clientUI.isHueOpen()then owner=clientUI.hueView:getControllerFocus()
        elseif nurseryView:isOpen()then owner=nurseryView:getControllerFocus()
		elseif isPickerOpen()then owner=picker:getControllerFocus()
		elseif journal.shade.Visible then owner=journal:getControllerFocus()
		elseif gameMenu.shade.Visible then owner=gameMenu:getControllerFocus()end
		return{owner=owner,blocked=owner==nil}
	end,
	playerGui=function()return player:FindFirstChild("PlayerGui")end,
	input=function()return UserInputService:GetLastInputType()end,
	aDown=function(kind)return UserInputService:IsGamepadButtonDown(kind,Enum.KeyCode.ButtonA)end,
	selected=function()return GuiService.SelectedObject end,
	select=function(target)GuiService.SelectedObject=target end,
	afterInput=function(callback)task.defer(function()RunService.Heartbeat:Wait();callback()end)end,
})
local controllerAction="EggDropSheetHandoffA"
ContextActionService:BindActionAtPriority(controllerAction,function(_,state,input)return controllerFocus:handleA(state,input)end,
	false,priority+500,Enum.KeyCode.ButtonA)
controllerFocus:watch(UserInputService.LastInputTypeChanged,function(kind)controllerFocus:onInputTypeChanged(kind)end)
controllerFocus:watch(UserInputService.GamepadDisconnected,function(device)controllerFocus:onGamepadDisconnected(device)end)
controllerFocus:watch(UserInputService.InputBegan,function(input)
	local key=input.KeyCode
	if key==Enum.KeyCode.DPadUp or key==Enum.KeyCode.DPadDown or key==Enum.KeyCode.DPadLeft or key==Enum.KeyCode.DPadRight then controllerFocus:onNavigation(input)end
end)
for _,root in ipairs({gameMenu.shade,picker.shade,journal.shade,nurseryView.shade,clientUI.hueView.shade})do
	controllerFocus:watch(root:GetPropertyChangedSignal("Visible"))
	controllerFocus:watch(root:GetAttributeChangedSignal("ControllerEpoch"))
end
for _,root in ipairs({modal,roomView.controls,roomView.focusUI.panel,roomView.transition.shade})do controllerFocus:watch(root:GetPropertyChangedSignal("Visible"))end
controllerFocus:watch(GuiService.MenuOpened);controllerFocus:watch(GuiService.MenuClosed)
controllerFocus:watch(UserInputService.TextBoxFocused);controllerFocus:watch(UserInputService.TextBoxFocusReleased)
controllerFocus:watch(UserInputService.WindowFocusReleased,function()controllerFocus:invalidate(true);controllerFocus.inputKind=nil end)
controllerFocus:watch(gui.Destroying,function()controllerFocus:destroy();ContextActionService:UnbindAction(controllerAction)end)

-- In-deck results: two targets (Replay, Leave). D-pad/arrows/A-D move, A/Enter/
-- Space confirm, B/Backspace leave. Keyboard, gamepad and the deck hardware share it.
ContextActionService:BindActionAtPriority("EggDropResults", function(_, state, input)
	if not recap.visible or not recapOwnsInput() or UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
	if state == Enum.UserInputState.Begin then
		local key = input.KeyCode
		if key == Enum.KeyCode.Left or key == Enum.KeyCode.A or key == Enum.KeyCode.DPadLeft then recap:move(-1);clientUI.deck:flash("Left")
		elseif key == Enum.KeyCode.Right or key == Enum.KeyCode.D or key == Enum.KeyCode.DPadRight then recap:move(1);clientUI.deck:flash("Right")
		elseif key == Enum.KeyCode.ButtonB or key == Enum.KeyCode.Backspace then clientUI.deck:flash("B");recap:back()
			elseif key == Enum.KeyCode.Up or key == Enum.KeyCode.DPadUp or key == Enum.KeyCode.Down or key == Enum.KeyCode.DPadDown then
				-- Up on Replay starts the next round on the difficulty picker.
				if (key == Enum.KeyCode.Up or key == Enum.KeyCode.DPadUp) and recap.focus == 1 and recap.data and not recap.data.pending then
					clientUI.keepHeatAfter=nil;clientUI.heatStarted=false;clientUI.deck:flash("Up");requestRetry()
				end
		else clientUI.deck:flash("A");recap:confirm() end
	end
	return Enum.ContextActionResult.Sink
end, false, priority + 1, Enum.KeyCode.Left, Enum.KeyCode.Right, Enum.KeyCode.A, Enum.KeyCode.D, Enum.KeyCode.Up, Enum.KeyCode.Down,
	Enum.KeyCode.DPadLeft, Enum.KeyCode.DPadRight, Enum.KeyCode.DPadUp, Enum.KeyCode.DPadDown, Enum.KeyCode.Space, Enum.KeyCode.Return,
	Enum.KeyCode.KeypadEnter, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonB, Enum.KeyCode.Backspace)
-- Deck style (redesign 4): Faceplates and Backgrounds own focus while open. D-pad /
-- arrows / WASD browse the grid, Q / E and LB / RB switch tabs, A / Enter / Space buy,
-- equip or use, B / Backspace back out.
ContextActionService:BindActionAtPriority("EggDropFaceplateShop", function(_, state, input)
	if not picker:shopOpen() or UserInputService:GetFocusedTextBox() or GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end
	if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
	local key=input.KeyCode;local shop=picker.shop
	if key==Enum.KeyCode.Left or key==Enum.KeyCode.A or key==Enum.KeyCode.DPadLeft then shop:move(-1,0)
	elseif key==Enum.KeyCode.Right or key==Enum.KeyCode.D or key==Enum.KeyCode.DPadRight then shop:move(1,0)
	elseif key==Enum.KeyCode.Up or key==Enum.KeyCode.W or key==Enum.KeyCode.DPadUp then shop:move(0,-1)
	elseif key==Enum.KeyCode.Down or key==Enum.KeyCode.S or key==Enum.KeyCode.DPadDown then shop:move(0,1)
	elseif key==Enum.KeyCode.Q or key==Enum.KeyCode.ButtonL1 then picker:shiftStyleTab(-1)
	elseif key==Enum.KeyCode.E or key==Enum.KeyCode.ButtonR1 then picker:shiftStyleTab(1)
	elseif key==Enum.KeyCode.ButtonB or key==Enum.KeyCode.Backspace then picker:back()
	else shop:act(false)end
	return Enum.ContextActionResult.Sink
end, false, priority + 600, Enum.KeyCode.Left, Enum.KeyCode.Right, Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.A, Enum.KeyCode.D,
	Enum.KeyCode.W, Enum.KeyCode.S, Enum.KeyCode.Q, Enum.KeyCode.E, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1,
	Enum.KeyCode.DPadLeft, Enum.KeyCode.DPadRight, Enum.KeyCode.DPadUp, Enum.KeyCode.DPadDown,
	Enum.KeyCode.Space, Enum.KeyCode.Return, Enum.KeyCode.KeypadEnter, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonB, Enum.KeyCode.Backspace)
picker.onBuy=function(order)
	nurseryRequest:FireServer("faceplateBuy",{id=order.id,plateId=order.plateId,price=order.price},nurseryState and nurseryState.revision or 0)
end
picker.onBallBought=function(id)
	local theme=clientUI.BallThemes.ById[id]
	clientUI.shopToaster=clientUI.shopToaster or require(script.DeckKit).toaster(picker.shade)
	clientUI.shopToaster.show((theme and theme.name or "Balls").." in use")
end
picker.onBought=function(id)
	local theme=Themes.ById[id]
	-- The toast lives on the picker overlay so it shows in the garden too.
	clientUI.shopToaster=clientUI.shopToaster or require(script.DeckKit).toaster(picker.shade)
	clientUI.shopToaster.show((theme and theme.name or "Faceplate").." equipped")
end
local faceplateResultConnection=remotes:WaitForChild("FaceplateResult").OnClientEvent:Connect(function(message)
	-- Collection book claims share the remote (play-forever F1/F2).
	if type(message)=="table"and message.kind=="book"then if clientUI.book then clientUI.book:result(message)end;return end
	picker.shop:result(message)
end)
gui.Destroying:Connect(function()faceplateResultConnection:Disconnect();ContextActionService:UnbindAction("EggDropFaceplateShop")end)
-- Replay keeps the difficulty (no picker); Up on Replay picks again.
recap:on("replay",function()clientUI.keepHeatAfter=board:GetAttribute("RunSequence");requestRetry()end)
recap:on("leave",function()clientUI.leaveDeck()end)
-- Results Hatch button (celebrations 2.6): the same garden route as Menu > Eggs.
recap:on("hatch",function()
	if recap.data and recap.data.pending then return end
	if visitEggs()then recap:hide();clientUI.accepted("confirm")end
end)
-- Compact results: change difficulty (the touch route for "Up on Replay") and the quest shortcut.
recap:on("picker",function()
	if recap.data and recap.data.pending then return end
	clientUI.keepHeatAfter=nil;clientUI.heatStarted=false;requestRetry()
end)
recap:on("quests",function(kind)
	local scope=recap.data and recap.data.questDone and select(2,clientUI.finishedQuest(RunReceipt.select(nurseryState,board:GetAttribute("RunSequence"),board:GetAttribute("RewardStatus"),true)))
	if clientUI.openQuestLog(if kind=="claim"and scope=="weekly"then "weekly"else "daily")then clientUI.accepted("confirm")end
end)
-- ── Round items (BUILD-PLAN 2026-11-13, R2) ─────────────────────────────────
-- B (keyboard B, gamepad B or X, the deck's B, the phone item button) opens the
-- carousel in a live round; it freezes the round through syncPause. The server
-- owns the belt: the client asks with {resetId, seq, id} and shows what comes back.
clientUI.items=clientUI.ItemCarousel.new(clientUI.deviceRoot,{z=38})
clientUI.items:place(viewport.Position,viewport.Size,clientUI.deck.geometry~=nil and clientUI.deck.geometry.phone==true)
function clientUI.itemsInRound()
 return board:GetAttribute("Mode")=="Board"and backdrop.Visible and not modal.Visible and not roomView.busy and not recap.visible
  and not isPickerOpen()and not journal.shade.Visible and not gameMenu.shade.Visible and not nurseryView:isOpen()and not clientUI.isHueOpen()
  and board:GetAttribute("RoundOver")~=true and not clientUI.heatPicker.visible and not clientUI.questLog.visible
  and not clientUI.pocketMenu.visible and not GuiService.MenuIsOpen
end
function clientUI.openItems()
 if clientUI.items.isOpen or not clientUI.itemsInRound()then return false end
 -- An empty belt shows "You have no items" and leaves the round running.
 if not clientUI.items:open()then audio:play("aim",.6,.3);return false end
 clearPlayInputs();clientUI.syncPause();clientUI.accepted("confirm")
 if updateHud then task.defer(updateHud)end
 return true
end
function clientUI.closeItems(instant)
 if not clientUI.items:close(instant)then return false end
 clientUI.syncPause()
 if not instant then clientUI.accepted("back")end
 if updateHud then task.defer(updateHud)end
 return true
end
function clientUI.toggleItems()
 if clientUI.items.isOpen then return clientUI.closeItems()end
 return clientUI.openItems()
end
function clientUI.useItem()
 local id=clientUI.items:selected()
 if not id then return false end
 request:FireServer("item",{resetId=board:GetAttribute("ResetId"),seq=board:GetAttribute("ItemSeq")or 0,id=id})
 clientUI.closeItems(true);clientUI.accepted("confirm")
 return true
end
clientUI.items:on("use",function()clientUI.useItem()end)
clientUI.items:on("close",function()clientUI.closeItems()end)
clientUI.items:on("moved",function()audio:play("aim",1.05,.35)end)
-- The desktop belt chip shows only while items are usable: hidden under the
-- Pocket menu, quest log, pickers and every other cover (QA 2026-11-13).
function clientUI.syncItemChip()
 if not clientUI.items then return end
 clientUI.items:setChipVisible(board:GetAttribute("ItemsOn")==true and clientUI.itemsInRound())
end
function clientUI.refreshItems()
 local belt=clientUI.RoundItems.decodeBelt(board:GetAttribute("ItemBelt"))
 clientUI.items:setBelt(belt)
 local front=clientUI.RoundItems.ById[belt[1]or ""]
 clientUI.deck:setItems(#belt,front and front.glyph,front and front.color)
 clientUI.syncItemChip()
 if clientUI.items.isOpen and(#belt==0 or not clientUI.itemsInRound())then clientUI.closeItems(true)end
end
for _,name in ipairs({"ItemBelt","ItemsOn","Mode","RoundOver","ResetId"})do
 board:GetAttributeChangedSignal(name):Connect(clientUI.refreshItems)
end
board:GetAttributeChangedSignal("ItemEvent"):Connect(function()
 local ok,event=pcall(function()return HttpService:JSONDecode(board:GetAttribute("ItemEvent")or "")end)
 if not ok or type(event)~="table"or event.resetId~=board:GetAttribute("ResetId")then return end
 local item=clientUI.RoundItems.ById[event.id or ""]
 if event.kind=="full"then clientUI.items:showNote(clientUI.ItemCarousel.FullNote);audio:play("aim",.6,.3)
 elseif event.kind=="granted"and item then clientUI.items:showNote(item.name.."!");audio:play("quest_complete",1.2,.5)
 elseif event.kind=="refused"then
  clientUI.items:showNote(({Budget="No ball left for that",Empty="Nothing to pop",Armed="An item is already armed",NotLive="Not right now"})[event.reason]or "Not right now")
 end
end)
clientUI.refreshItems()
-- Deck hardware (mouse and touch). Results take the d-pad and A/B while open.
clientUI.deck:on("item",function()clientUI.toggleItems()end)
clientUI.deck:on("dpad",function(dir,input)
	if clientUI.items.isOpen then
		if dir=="Left"or dir=="Right"then clientUI.items:move(if dir=="Left"then -1 else 1)end
	elseif clientUI.pocketMenu.visible then
		clientUI.pocketMenu:move(if dir=="Left"then -1 elseif dir=="Right"then 1 else 0,if dir=="Up"then -1 elseif dir=="Down"then 1 else 0)
	elseif clientUI.questLog.visible then
		if dir=="Up"or dir=="Down"then clientUI.questLog:move(if dir=="Up"then -1 else 1)else clientUI.questLog:cycleTab(if dir=="Left"then -1 else 1)end
	elseif clientUI.heatPicker.visible then
		if dir=="Left"or dir=="Right"then clientUI.heatPicker:move(if dir=="Left"then -1 else 1)end
	elseif recap.visible then
		if dir=="Left" or dir=="Right" then recap:move(if dir=="Left" then -1 else 1) end
	elseif dir=="Left" or dir=="Right" then startAim(input,if dir=="Left" then -1 else 1) end
end)
clientUI.deck:on("A",function()
	if clientUI.items.isOpen then clientUI.useItem()
	elseif clientUI.pocketMenu.visible then clientUI.pocketMenu:confirm()
	elseif clientUI.questLog.visible then clientUI.questLog:act()elseif clientUI.heatPicker.visible then clientUI.heatPicker:confirm()
	elseif recap.visible then recap:confirm() else dropEgg() end end)
clientUI.deck:on("B",function()
	-- In a live round B is Items (leaving is MENU or the back arrow).
	if clientUI.items.isOpen then clientUI.closeItems();return end
	if clientUI.itemsInRound()then clientUI.openItems();return end
	if clientUI.closePocketMenu()then return end
	if clientUI.questLog.visible then clientUI.closeQuestLog()elseif recap.visible then recap:back() else clientUI.leaveDeck() end end)
-- MENU: the Pocket Menu in a round; the quest log from results (UI-SPEC 5.4) or
-- when it is already open (closes it); the garden menu outside the deck.
clientUI.deck:on("menu",function()
	if clientUI.items.isOpen then clientUI.closeItems(true)end
	if board:GetAttribute("Mode")=="Board"then
		if clientUI.pocketMenu.visible then clientUI.closePocketMenu()
		elseif clientUI.questLog.visible or recap.visible then if clientUI.toggleQuestLog()then clientUI.accepted("confirm")end
		elseif clientUI.openPocketMenu()then clientUI.accepted("confirm")end
	elseif openMenu()then clientUI.accepted("confirm")end end)
clientUI.deck:on("quests",function()if clientUI.openQuestLog()then clientUI.accepted("confirm")end end)
clientUI.deck:on("back",function()
	if clientUI.closeItems()then return end
	if clientUI.closePocketMenu()then return end
	if clientUI.questLog.visible then clientUI.closeQuestLog()elseif recap.visible then recap:back() else clientUI.leaveDeck() end end)

-- ── Part 2b: difficulty picker and quest log ────────────────────────────────
-- The picker shows before a fresh round (no drops yet) unless the server marks
-- the run guided, the player already pressed Start, or Replay kept the heat.
clientUI.heatStarted=false
function clientUI.questLine()
 local q=nurseryState and nurseryState.quests
 for _,row in ipairs(q and q.daily or {})do
  if not row.claimed and not row.ready then return row.title.." "..row.progress.."/"..row.target end
 end
 return nil
end
function clientUI.refreshDeckOverlays(over,sheetOpen,fieldActive,drops)
 local picker,log=clientUI.heatPicker,clientUI.questLog
 if board:GetAttribute("Mode")~="Board"then
  clientUI.heatStarted=false;clientUI.keepHeatAfter=nil
  picker:hide();if log.visible then clientUI.closeQuestLog()end
  return
 end
 local sequence=board:GetAttribute("RunSequence")
 if over then clientUI.heatStarted=false
 elseif clientUI.keepHeatAfter and sequence~=clientUI.keepHeatAfter then clientUI.heatStarted=true;clientUI.keepHeatAfter=nil end
 if log.visible then log:update(nurseryState and nurseryState.quests,nurseryState and nurseryState.nectar or 0)end
 local want=fieldActive and drops==0 and not over and not sheetOpen and not modal.Visible and not roomView.busy
  and board:GetAttribute("HeatGuided")~=true and not clientUI.heatStarted
 if want then
  local ok,pays=pcall(function()return HttpService:JSONDecode(board:GetAttribute("HeatPays")or "{}")end)
  picker:show({selected=clientUI.pickedHeat or board:GetAttribute("NextHeat"),pays=if ok then pays else nil,
   wallet=nurseryState and nurseryState.nectar or 0,goal=clientUI.fieldView and not clientUI.fieldView.empty and clientUI.fieldView.title or nil,
   quest=clientUI.questLine(),questCount=clientUI.questCount(),questReady=clientUI.anyQuestReady()})
  -- An open quest log covers the picker (both are translucent LCD layers).
  if log.visible then picker.overlay.layer.Visible=false end
 else picker:hide()end
end
clientUI.heatCallbacks.quests=function()if clientUI.openQuestLog()then clientUI.accepted("confirm")end end
clientUI.heatCallbacks.select=function(key)clientUI.pickedHeat=key;audio:play("aim",1.1,.35)end
clientUI.heatCallbacks.start=function(key)
 if board:GetAttribute("Heat")~=key or board:GetAttribute("NextHeat")~=key then request:FireServer("heat",key)end
 clientUI.pickedHeat=nil;clientUI.heatStarted=true;clientUI.heatPicker:hide()
 clientUI.accepted("confirm");if updateHud then task.defer(updateHud)end
end
function clientUI.openQuestLog(tab)
 if clientUI.pocketMenu.visible then return false end
 if clientUI.items.isOpen then clientUI.closeItems(true)end
 if board:GetAttribute("Mode")~="Board"or roomView.busy or modal.Visible or isPickerOpen()or gameMenu.shade.Visible or nurseryView:isOpen()or clientUI.isHueOpen()then return false end
 clearPlayInputs()
 clientUI.questLog:show(nurseryState and nurseryState.quests,nurseryState and nurseryState.nectar or 0,tab)
 -- Both are translucent LCD layers: the log hides the picker under it until it closes.
 if clientUI.heatPicker.visible then clientUI.heatPicker.overlay.layer.Visible=false end
 clientUI.syncPause()
 if updateHud then task.defer(updateHud)end
 return true
end
function clientUI.closeQuestLog()
 if not clientUI.questLog.visible then return false end
 clientUI.questLog:hide();clientUI.syncPause()
 if clientUI.heatPicker.visible then clientUI.heatPicker.overlay.layer.Visible=true end
 clientUI.accepted("back");if updateHud then task.defer(updateHud)end
 return true
end
-- Pocket Menu routes. Restart / Quit confirm in the menu itself (one more tap mid-round).
function clientUI.pocketState()
 local owned=(board:GetAttribute("OwnedPets")or 0)>0
 local over=board:GetAttribute("RoundOver")==true
 return{empty=(board:GetAttribute("Drops")or 0)==0,locked=not owned,canRestart=owned and not over and(board:GetAttribute("FieldPhase")or "Welcome")~="Welcome",
  canQuit=owned,canHatch=owned,canCustomize=owned,canBook=owned,
  bookClaimable=nurseryState and type(nurseryState.book)=="table"and type(nurseryState.book.claimable)=="table"and #nurseryState.book.claimable or 0}
end
function clientUI.openPocketMenu()
 if clientUI.pocketMenu.visible then return false end
 if clientUI.items.isOpen then clientUI.closeItems(true)end
 if board:GetAttribute("Mode")~="Board"or roomView.busy or modal.Visible or recap.visible or isPickerOpen()or gameMenu.shade.Visible
  or nurseryView:isOpen()or clientUI.isHueOpen()or board:GetAttribute("RoundOver")==true then return false end
 if clientUI.questLog.visible then return false end
 clearPlayInputs()
 local state=clientUI.pocketState()
 -- One restart request per 3.5 s (the server's own cooldown is 3 s).
 if os.clock()-(clientUI.lastRestart or -math.huge)<3.5 then state.canRestart=false end
 clientUI.pocketMenu:open(state)
 -- Both are translucent LCD layers on desktop: hide the picker under the menu until it closes.
 if clientUI.heatPicker.visible then clientUI.heatPicker.overlay.layer.Visible=false end
 clientUI.syncPause()
 if updateHud then task.defer(updateHud)end
 return true
end
function clientUI.closePocketMenu(instant)
 if not clientUI.pocketMenu:close(instant)then return false end
 if clientUI.heatPicker.visible and not clientUI.questLog.visible then clientUI.heatPicker.overlay.layer.Visible=true end
 clientUI.syncPause()
 if not instant then clientUI.accepted("back")end
 if updateHud then task.defer(updateHud)end
 return true
end
clientUI.pocketCallbacks.resume=function()clientUI.closePocketMenu()end
clientUI.pocketCallbacks.restart=function()
 local sequence=board:GetAttribute("RunSequence")
 local empty=(board:GetAttribute("Drops")or 0)==0
 clientUI.closePocketMenu(true);clientUI.accepted("confirm")
 -- An empty board is already a fresh round: Restart just resumes it.
 if type(sequence)=="number"and not empty then
  clientUI.keepHeatAfter=sequence;clientUI.lastRestart=os.clock()
  request:FireServer("restart",sequence)
  -- A refused restart (cooldown, save in flight) leaves the round as it was: drop the keep-heat marker.
  task.delay(2.5,function()if clientUI.keepHeatAfter==sequence and board:GetAttribute("RunSequence")==sequence then clientUI.keepHeatAfter=nil end end)
  if not GuiService.MenuIsOpen then audio:play("retry",1,.6)end
 end
end
clientUI.pocketCallbacks.quit=function()clientUI.closePocketMenu(true);clientUI.leaveDeck()end
clientUI.pocketCallbacks.hatch=function()
 clientUI.closePocketMenu(true)
 if visitEggs()then clientUI.accepted("confirm")end
end
clientUI.pocketCallbacks.customize=function()
 clientUI.closePocketMenu(true)
 if clientUI.visitCompanions()then clientUI.accepted("confirm")end
end
-- Collection book over the paused round: opened before the menu closes so the pause holds.
clientUI.pocketCallbacks.book=function()
 local opened=clientUI.openBook~=nil and clientUI.openBook()
 clientUI.closePocketMenu(true)
 if opened then clientUI.accepted("confirm")end
end
clientUI.pocketCallbacks.armed=function()audio:play("aim",.8,.4)end
clientUI.pocketCallbacks.locked=function(id,state)
 clientUI.deck.toaster.show(if state.locked then "Win this round to meet your first pet"
  elseif id=="restart"then(if state.empty then "The round has not started"elseif board:GetAttribute("RoundOver")==true then "The round is over"else "Restarting, one moment")else "Not available right now")
 audio:play("aim",.6,.3)
end
function clientUI.toggleQuestLog()
 if clientUI.questLog.visible then return clientUI.closeQuestLog()end
 return clientUI.openQuestLog()
end
clientUI.questCallbacks.claim=function(scope,slot,period)
 nurseryRequest:FireServer("questClaim",{scope=scope,slot=slot,period=period},nurseryState and nurseryState.revision or 0)
end
clientUI.questCallbacks.reroll=function(slot,day)
 nurseryRequest:FireServer("questReroll",{slot=slot,period=day},nurseryState and nurseryState.revision or 0)
end
clientUI.questCallbacks.back=function()clientUI.closeQuestLog()end
clientUI.questCallbacks.menu=function()clientUI.closeQuestLog();if openMenu()then clientUI.accepted("confirm")end end
clientUI.questCallbacks.tab=function()clientUI.accepted("tab")end
-- Feedback: a toast and the quest_complete cue (a quiet no-op until the sound
-- file arrives) when a quest becomes claimable, and again on a saved claim.
clientUI.questReady=nil
clientUI.onQuests=function(state)
 local q=state.quests;if type(q)~="table"then return end
 local ready={}
 for _,scope in ipairs({"daily","weekly"})do for _,row in ipairs(q[scope]or {})do
  local key=scope..":"..row.id
  ready[key]=row.ready==true or row.claimed==true
  if clientUI.questReady and row.ready and not clientUI.questReady[key]then
   clientUI.deck.toaster.show("Quest done: "..row.title,row.reward);audio:play("quest_complete",1,.7)
  end
 end end
 clientUI.questReady=ready
 clientUI.questLog:update(q,state.nectar or 0)
end
clientUI.questResultConnection=remotes:WaitForChild("QuestResult").OnClientEvent:Connect(function(message)
 clientUI.questLog:result(message)
 if type(message)~="table"then return end
 if message.status=="Saved"and message.action=="questClaim"then
  clientUI.deck.toaster.show("Quest claimed",message.stars);audio:play("quest_complete",1.1,.7)
 elseif message.status=="Saved"and message.action=="questReroll"then audio:play("retry",1.2,.5)
 elseif message.status=="Rejected"and message.reason~="AlreadyClaimed"then
  clientUI.deck.toaster.show(({NoReroll="No reroll left today",Started="Only unstarted quests can be rerolled",Busy="Saving, try again",Throttled="One moment…",NotComplete="Not finished yet",PeriodChanged="New quests arrived"})[message.reason]or "Try again")
 end
end)
gui.Destroying:Connect(function()clientUI.questResultConnection:Disconnect();ContextActionService:UnbindAction("EggDropDeckOverlay")end)
-- Keyboard and gamepad for both layers (UI-SPEC 3 "Gamepad and keyboard map").
ContextActionService:BindActionAtPriority("EggDropDeckOverlay",function(_,state,input)
 local log,heat=clientUI.questLog,clientUI.heatPicker
 if UserInputService:GetFocusedTextBox()or GuiService.MenuIsOpen or roomView.busy then return Enum.ContextActionResult.Pass end
 local pocket=clientUI.pocketMenu
 if pocket.visible then
  if state~=Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
  local K=Enum.KeyCode;local key=input.KeyCode
  local dx=if key==K.Left or key==K.A or key==K.DPadLeft then -1 elseif key==K.Right or key==K.D or key==K.DPadRight then 1 else 0
  local dy=if key==K.Up or key==K.W or key==K.DPadUp then -1 elseif key==K.Down or key==K.S or key==K.DPadDown then 1 else 0
  if dx~=0 or dy~=0 then pocket:move(dx,dy);clientUI.deck:flash(if dx<0 then "Left"elseif dx>0 then "Right"elseif dy<0 then "Up"else "Down")
  elseif key==K.Space or key==K.Return or key==K.KeypadEnter or key==K.ButtonA then clientUI.deck:flash("A");pocket:confirm()
  elseif key==K.ButtonB or key==K.Backspace or key==K.M or key==K.ButtonY or key==K.ButtonSelect or key==K.ButtonStart then clientUI.deck:flash("B");clientUI.closePocketMenu()end
  return Enum.ContextActionResult.Sink
 end
 if not(log.visible or heat.visible)then
  -- Menu from the results screen opens the quest log too (UI-SPEC 5.4); in a round it opens the Pocket Menu.
  local k=input.KeyCode
  local menuKey=k==Enum.KeyCode.M or k==Enum.KeyCode.ButtonY or k==Enum.KeyCode.ButtonSelect or k==Enum.KeyCode.ButtonStart
  if recap.visible and menuKey then
   if state==Enum.UserInputState.Begin then clientUI.openQuestLog()end
   return Enum.ContextActionResult.Sink
  end
  local inRound=board:GetAttribute("Mode")=="Board"and backdrop.Visible and not modal.Visible and not isPickerOpen()and not board:GetAttribute("RoundOver")
  if menuKey and inRound then
   if state==Enum.UserInputState.Begin and clientUI.openPocketMenu()then clientUI.accepted("confirm")end
   return Enum.ContextActionResult.Sink
  end
  -- MENU opens the Pocket Menu now, so Q / LB keep a keyboard and gamepad route to the quest log mid-round.
  if inRound and(k==Enum.KeyCode.Q or k==Enum.KeyCode.ButtonL1)then
   if state==Enum.UserInputState.Begin and clientUI.openQuestLog()then clientUI.accepted("confirm")end
   return Enum.ContextActionResult.Sink
  end
  return Enum.ContextActionResult.Pass
 end
 if state~=Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
 local K=Enum.KeyCode;local key=input.KeyCode
 local left=key==K.Left or key==K.A or key==K.DPadLeft
 local right=key==K.Right or key==K.D or key==K.DPadRight
 local up=key==K.Up or key==K.W or key==K.DPadUp
 local down=key==K.Down or key==K.S or key==K.DPadDown
 local confirm=key==K.Space or key==K.Return or key==K.KeypadEnter or key==K.ButtonA
 local back=key==K.ButtonB or key==K.Backspace
 local menu=key==K.M or key==K.ButtonY or key==K.ButtonSelect or key==K.ButtonStart
 if log.visible then
  if up or down then log:move(if up then -1 else 1);clientUI.deck:flash(if up then "Up"else "Down")
  elseif key==K.Q or key==K.ButtonL1 then log:cycleTab(-1)
  elseif key==K.E or key==K.ButtonR1 then log:cycleTab(1)
  elseif confirm then clientUI.deck:flash("A");log:act()
  elseif back or menu then clientUI.deck:flash("B");clientUI.closeQuestLog()end
 else
  if left or right then heat:move(if left then -1 else 1);clientUI.deck:flash(if left then "Left"else "Right")
  elseif confirm then clientUI.deck:flash("A");heat:confirm()
  elseif back then clientUI.deck:flash("B");clientUI.leaveDeck()
  elseif menu then clientUI.openQuestLog()end
 end
 return Enum.ContextActionResult.Sink
end,false,priority+700,Enum.KeyCode.Left,Enum.KeyCode.Right,Enum.KeyCode.Up,Enum.KeyCode.Down,Enum.KeyCode.A,Enum.KeyCode.D,Enum.KeyCode.W,Enum.KeyCode.S,
 Enum.KeyCode.Q,Enum.KeyCode.E,Enum.KeyCode.DPadLeft,Enum.KeyCode.DPadRight,Enum.KeyCode.DPadUp,Enum.KeyCode.DPadDown,Enum.KeyCode.ButtonL1,Enum.KeyCode.ButtonR1,
 Enum.KeyCode.Space,Enum.KeyCode.Return,Enum.KeyCode.KeypadEnter,Enum.KeyCode.ButtonA,Enum.KeyCode.ButtonB,Enum.KeyCode.Backspace,
 Enum.KeyCode.M,Enum.KeyCode.ButtonY,Enum.KeyCode.ButtonSelect,Enum.KeyCode.ButtonStart)
-- Round items: below the deck overlays (+700) so the Pocket Menu, quest log and
-- picker keep their keys; above aim/drop/back so B is Items in a live round.
ContextActionService:BindActionAtPriority("EggDropItems",function(_,state,input)
 if UserInputService:GetFocusedTextBox()or GuiService.MenuIsOpen or roomView.busy then return Enum.ContextActionResult.Pass end
 local items=clientUI.items
 if items.isOpen and not clientUI.itemsInRound()then clientUI.closeItems(true);return Enum.ContextActionResult.Pass end
 local act=clientUI.ItemCarousel.keyAction(input.KeyCode,items.isOpen)
 if not act or(act=="open"and not clientUI.itemsInRound())then return Enum.ContextActionResult.Pass end
 if state~=Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
 if act=="open"then clientUI.deck:flash("B");clientUI.openItems()
 elseif act=="left"or act=="right"then
  if items:move(if act=="left"then -1 else 1)then clientUI.deck:flash(if act=="left"then "Left"else "Right")end
 elseif act=="use"then clientUI.deck:flash("A");clientUI.useItem()
 elseif act=="close"then clientUI.deck:flash("B");clientUI.closeItems()end
 return Enum.ContextActionResult.Sink
end,false,priority+650,table.unpack(clientUI.ItemCarousel.Keys))
gui.Destroying:Connect(function()ContextActionService:UnbindAction("EggDropItems");clientUI.items:destroy()end)
ContextActionService:BindActionAtPriority("EggDropLeft", handleControl, false, priority,
	Enum.KeyCode.Left, Enum.KeyCode.A, Enum.KeyCode.DPadLeft)
ContextActionService:BindActionAtPriority("EggDropRight", handleControl, false, priority,
	Enum.KeyCode.Right, Enum.KeyCode.D, Enum.KeyCode.DPadRight)
ContextActionService:BindActionAtPriority("EggDropDrop", handleControl, false, priority,
	Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
ContextActionService:BindActionAtPriority("EggDropPickerBack", function(_, state)
	if not clientUI.PresentationPolicy.canSheetBack({coreMenu=GuiService.MenuIsOpen,textCapture=UserInputService:GetFocusedTextBox()~=nil,busy=roomView.busy}) then return Enum.ContextActionResult.Pass end
    if clientUI.isHueOpen()then
        if state==Enum.UserInputState.Begin then clientUI.hueView:close("back")end
        return Enum.ContextActionResult.Sink
    end
	if gameMenu and gameMenu.shade.Visible then
		if state == Enum.UserInputState.Begin then gameMenu:activate("close") end
		return Enum.ContextActionResult.Sink
	end
	if nurseryView:isOpen() then
		-- On the hatch reveal stage, B / Esc is "Play again" (celebrations 1.6).
		if state == Enum.UserInputState.Begin and not nurseryView:revealBack() then nurseryView:close() end
		return Enum.ContextActionResult.Sink
	end
	if journal.shade.Visible then
		if state == Enum.UserInputState.Begin then
			journal:close("back")
		end
		return Enum.ContextActionResult.Sink
	end
	if isPickerOpen() then
		if state == Enum.UserInputState.Begin then
			picker:back()
		end
		return Enum.ContextActionResult.Sink
	end
	if board:GetAttribute("Mode") == "Board" and backdrop.Visible and not modal.Visible and clientUI.deck.back.root.Visible then
		if state == Enum.UserInputState.Begin and clientUI.deck.back.enabled then clientUI.deck:flash("B");if not clientUI.closePocketMenu() then clientUI.leaveDeck() end end
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end, false, priority, Enum.KeyCode.ButtonB, Enum.KeyCode.Backspace)
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
UserInputService.WindowFocused:Connect(updateHud)
GuiService.MenuOpened:Connect(clearPlayInputs)
GuiService.MenuOpened:Connect(updateHud)
GuiService.MenuClosed:Connect(updateHud)
picker.shade:GetPropertyChangedSignal("Visible"):Connect(function()
	task.defer(updateHud)
end)
UserInputService.LastInputTypeChanged:Connect(function()
	-- The deck's Controls card follows the last input type.
	task.defer(updateHud)
end)
modalAction.Activated:Connect(function()
	if roomView.busy then
		return
	end
	if hatchQueue[1] then
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
	table.remove(hatchQueue, 1)
	reveal:cancel()
 clientUI.accepted("back")
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

clientUI.boardContentGate=require(script.BoardContentGate)

local function addView(source)
	if rendererPresentation.destroyed then return end
	local tier = source:GetAttribute("Tier")
	local id = source:GetAttribute("EggId")
	if not tier or not id or source:GetAttribute("BoardSerial")~=board:GetAttribute("ResetId")then
		return
	end
	local gel = if RunService:IsStudio() and gui:GetAttribute("MeshPreview")
		then Jelly.new(scene, source) else Sprite.new(sprites, source,{gridWidth=JellyLCD.Width,themeId=clientUI.equippedBallTheme()})
	-- No tier numerals (batch R1): size, colour and the ball's face carry the tier.
	eggViews[source] = { gel = gel, id = id, tier = tier, radius = Config.Tiers[tier].radius, faceInput = { id = id, tier = tier, x = 0, y = 0, radius = Config.Tiers[tier].radius }, face = { tier = tier, expr = "idle", dx = 0 } }
	viewsById[id] = gel
end

local function removeView(source)
	if rendererPresentation.destroyed then return end
	local view = eggViews[source]
	if view then
		view.gel:destroy()
		viewsById[view.id] = nil
		eggViews[source] = nil
	end
end
roomView.boardContentReady=function(previousSerial)
 if not clientUI.boardContentGate.ready(board,previousSerial)then return false end
 for _,source in ipairs(board:GetChildren())do if not eggViews[source]then addView(source)end end
 return true
end
table.insert(rendererPresentation.connections,board.ChildAdded:Connect(addView))
table.insert(rendererPresentation.connections,board.ChildRemoved:Connect(removeView))
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

rendererPresentation.canPresent=function(serial)
 return type(serial)=="number"and not rendererPresentation.destroyed and serial==board:GetAttribute("ResetId") and gui.Parent~=nil and gui.Enabled
  and board:GetAttribute("Mode")=="Board" and backdrop.Visible and not GuiService.MenuIsOpen
  and not UserInputService:GetFocusedTextBox() and not modal.Visible and not modalShade.Visible
  and not isPickerOpen() and not journal.shade.Visible and not nurseryView:isOpen() and not clientUI.isHueOpen() and not gameMenu.shade.Visible
  and not roomView.busy and not roomView.transition.shade.Visible
end
table.insert(rendererPresentation.connections,overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()rendererPresentation.fx:clear()end))
table.insert(rendererPresentation.connections,impacts.OnClientEvent:Connect(function(batch,serial)
 if not rendererPresentation.canPresent(serial)then return end
 local strongest,contact,normal,contactSource=0,nil,nil,nil
 for _,impact in ipairs(batch)do
  local gel=viewsById[impact[1]]
  if gel then
   if not reduceEffects()then gel:impact(impact[2],impact[3])end
   if impact[3]>strongest then
    strongest=impact[3];normal=impact[2]
    for source,view in pairs(eggViews)do if view.id==impact[1]then contactSource=source;break end end
   end
  end
 end
 local now=os.clock()
 if strongest>=9 and now-lastPlop>=.13 and contactSource and contactSource.Parent then
  lastPlop=now
  local radius=contactSource.Size.X/2
  contact=Vector2.new(contactSource.Position.X,contactSource.Position.Y)-normal*radius
  rendererPresentation.setFieldOwner(true,serial,reduceEffects())
  rendererPresentation.fx:emit("impact",project(contact),radius*viewport.AbsoluteSize.X/(Config.Width+.8),contactSource.Color,contactSource:GetAttribute("Tier"),1,serial,now,normal)
  audio:play(if normal.Y<.78 then "bank"else "land",math.clamp(.82+strongest/100,.9,1.2),math.clamp(strongest/70,.24,.55))
 end
end))
table.insert(rendererPresentation.connections,feedback.OnClientEvent:Connect(function(position,tier,chain,first,second,id,cleared,serial)
 if not rendererPresentation.canPresent(serial)then return end
 local now=os.clock()
 mergeBurst=if now-lastMerge<.08 then math.min(mergeBurst+1,2)else 0;lastMerge=now
 clientUI.ballFaces:merged(id,now)
 audio:play(if tier==2 then "merge_bubble"else "merge_jelly",audio:mergePitch(chain,id),.56*.68^mergeBurst)
 if(chain>1 or cleared)and now-lastChainAccent>=.18 then
  lastChainAccent=now;audio:play("merge_chain",audio:mergePitch(chain,id),.30)
 end
 local reduced=reduceEffects()
 if lcdEnabled()and not cleared and not reduced then
  if #pixelMerges>=6 then table.remove(pixelMerges,1)end
  table.insert(pixelMerges,{first=pixelPoint(first),second=pixelPoint(second),point=pixelPoint(position),
   radius=Config.Tiers[tier-1].radius*JellyLCD.Width/(Config.Width+.8),resultRadius=Config.Tiers[tier].radius*JellyLCD.Width/(Config.Width+.8),
   color=clientUI.JellyPalette.byTier[tier].body,tier=tier,start=now,id=id})
 end
 rendererPresentation.setFieldOwner(true,serial,reduced)
 rendererPresentation.fx:emit("merge",project(position),Config.Tiers[tier].radius*viewport.AbsoluteSize.X/(Config.Width+.8),clientUI.JellyPalette.byTier[tier].body,tier,chain,serial,now,nil,cleared,Config.mergeScore(tier,chain,cleared))
 rendererPresentation.jolt:emit(serial,id,tier,chain,cleared,now)
 -- Big moments reach the resting pet behind the see-through deck.
 if tier>=3 or chain>=3 then roomView:cheerPet("cheer")end
end))

local function applySound()
	local sound = board:GetAttribute("SoundLevel")
	audio:setVolume(if Settings.validSound(sound) then Settings.Sound[sound] else 0)
end
applySound()
board:GetAttributeChangedSignal("SoundLevel"):Connect(applySound)
gui.Destroying:Connect(function() audio:destroy() end)
local function refreshMotion()
 if rendererPresentation.jolt then rendererPresentation.jolt:setOwner(rendererPresentation.visible,board:GetAttribute("ResetId"),reduceEffects())end
	nurseryView.cinematic:refreshOwner()
	if reduceEffects() then
        if clientUI.hueView then clientUI.hueView.itemReveal:cancel()end
		reveal:cancel()
		rendererPresentation.fx:clear()
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
 if rendererPresentation.roundEnd then rendererPresentation.roundEnd:observe()end
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
	if nurseryView then nurseryView:close("forced") end
    if clientUI.hueView then clientUI.hueView:close("forced")end
	if closeMenu then closeMenu() end
	if mode == "Room" then
  rendererPresentation.setFieldOwner(false,board:GetAttribute("ResetId"),reduceEffects())
		if hatchQueue[1] then
			table.remove(hatchQueue, 1)
		end
		reveal:cancel()
		rendererPresentation.fx:clear()
		table.clear(pixelMerges)
	end
	roomView:setMode(mode)
	clientUI.ambient:setRound(mode=="Board") -- W2: world ambience off, deck music on, during a round
end)
board:GetAttributeChangedSignal("ResetId"):Connect(function()
 for source in pairs(eggViews)do removeView(source)end
 for _,source in ipairs(board:GetChildren())do addView(source)end
 rendererPresentation.fx:observeDrop(board:GetAttribute("ResetId"),board:GetAttribute("Drops")or 0)
 rendererPresentation.setFieldOwner(false,board:GetAttribute("ResetId"),reduceEffects())
	recap.feedback:cancel()
	clearPlayInputs()
	reveal:cancel()
	rendererPresentation.fx:clear()
	table.clear(pixelMerges)
	lastPlop = -math.huge
	lastMerge = -math.huge
	lastChainAccent = -math.huge
end)
board:GetAttributeChangedSignal("Drops"):Connect(function()
 local count,serial=board:GetAttribute("Drops")or 0,board:GetAttribute("ResetId")
 local accepted=rendererPresentation.fx:observeDrop(serial,count)
 if accepted and rendererPresentation.canPresent(serial)then
  audio:play("drop",1,.48)
  rendererPresentation.setFieldOwner(true,serial,reduceEffects())
  rendererPresentation.jolt:drop(serial,count,os.clock())
  -- The neutral physical dispenser owns compression; NextTier may already be advanced.
 end
end)
board:GetAttributeChangedSignal("HatchCharge"):Connect(function()
	local charge = board:GetAttribute("HatchCharge")
	if charge > 0 then
		audio:play("charge", 1 + charge * 0.03, 0.35)
	end
end)
-- Terminal sounds belong to matching Saved RecapFeedback only.
for _,attribute in ipairs({"FieldObjective","RunSequence"})do
 board:GetAttributeChangedSignal(attribute):Connect(function()
  clientUI.fieldView=clientUI.FieldQuestText.read(board,clientUI.fieldCache)
  layout();updateHud()
 end)
end
backdrop:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(function()task.defer(layout)end)
Art.watchTextPreference(backdrop,function()return backdrop.Visible end,function()layout();updateHud()end)
backdrop:GetPropertyChangedSignal("Visible"):Connect(function()if backdrop.Visible and backdrop:GetAttribute("TextPreferenceDirty") then layout();updateHud();backdrop:SetAttribute("TextPreferenceDirty",false)end end)
status:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() task.defer(updateHud) end)
viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(drawAim)
local previousSaveBusy,previousSaveFocus,previousSaveMode
local rendererConnection
rendererConnection=RunService.RenderStepped:Connect(function(dt)
	-- Completion is local and may leave every Visible property unchanged. Poll only
	-- these scalars, then run the owner handoff once; never decode/walk UI per frame.
	if previousSaveBusy~=roomView.busy or previousSaveFocus~=roomView.focusing or previousSaveMode~=roomView.mode then
		previousSaveBusy,previousSaveFocus,previousSaveMode=roomView.busy,roomView.focusing,roomView.mode
		refreshSaveNotice()
	end
	if hatchNavigation and hatchNavigation.active then
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.MoveDirection.Magnitude > .05 then cancelHatchNavigation() end
	end
	-- Transition completion changes local busy state without a replicated attribute.
	-- Re-evaluate the button so returning from the lounge cannot leave A disabled.
	action.Interactable = canPlay() and not board:GetAttribute("RoundOver")
	clientUI.refreshBack()
	firstHatchGuide:fieldStep(0, 1, false)
	rail.Interactable = canAim() and not isPickerOpen() and not roomView.busy
	local recipe = EggCatalog.ById[nurseryView.selected] or EggCatalog.ById.meadow
	eggGoalText.Text = Stars.format("%s\n%d/%d Stars", recipe.name, nurseryState and nurseryState.nectar or 0, recipe.cost)
	if canAim() and not isPickerOpen() and not drag and not UserInputService:GetFocusedTextBox() then
		local direction = 0
		for _, value in pairs(heldAim) do
			direction += value
		end
		if direction ~= 0 then
			moveAim(math.sign(direction) * 1.0 * dt)
		end
	else
		table.clear(heldAim)
	end
	local now,reduced=os.clock(),reduceEffects()
 if rendererPresentation.roundEnd then rendererPresentation.roundEnd:step(dt)end
	Art.updateBackdrop(backing,now,gui.Enabled and bleed.Enabled and backdrop.Visible and backing.Visible and not modalShade.Visible and not GuiService.MenuIsOpen,reduced,gui.Enabled and bleed.Enabled and not GuiService.MenuIsOpen)
	if not backdrop.Visible then
  rendererPresentation.setFieldOwner(false,board:GetAttribute("ResetId"),reduced)
		rendererPresentation.visible=false;lcdElapsed=lcdStep
		return
	end
	local pressure = board:GetAttribute("OverflowPressure") or 0
	local graceLeft = board:GetAttribute("OverflowGraceLeft") or 0
	local mood = if reduced then "idle" elseif now - lastMerge < 0.24 then "happy" elseif now % 3.8 < 0.13 then "blink" else "idle"
	if mood ~= mascotMood then
		mascotMood = mood
		for _, eye in ipairs(mascotEyes) do
			eye.BackgroundColor3 = if mood == "blink" then mascotInk
				elseif mood == "happy" then Art.Amber else Art.Ink
		end
	end
	local presented=rendererPresentation.canPresent(board:GetAttribute("ResetId"))
 rendererPresentation.setFieldOwner(presented,board:GetAttribute("ResetId"),reduced)
 if audio.deviceActive==false then rendererPresentation.jolt:reset()else rendererPresentation.jolt:update(now)end
 -- The danger cues only play on a presented board, never under a menu, modal or hidden deck.
 clientUI.danger:update(pressure, graceLeft, now, reduced, presented, board:GetAttribute("RoundOver") == true)
 if not presented then rendererPresentation.visible=false;lcdElapsed=lcdStep;return end
 rendererPresentation.fx:update(now)
	if not rendererPresentation.visible then
		-- Resume at the current authoritative locations, never interpolate an old
		-- frozen pile through a newly uncovered board.
		for source,view in pairs(eggViews)do view.gel.position=source.Position;view.gel.age=math.max(view.gel.age or 0,1.5)end
		lcdElapsed=lcdStep
	end
	rendererPresentation.visible=true
	local closest, closestId
	local distance = math.huge
	local markScale = viewport.AbsoluteSize.X / (Config.Width + 0.8)
	local tier = nextTier()
	-- Ball faces (batch R1): one mood for the tick, expressions per ball, Next / Then too.
	local ballTheme=clientUI.equippedBallTheme()
	if clientUI.BallThemes.current~=ballTheme then clientUI.BallThemes.setCurrent(ballTheme);task.defer(updateHud)end
	if lcd then lcd:setBallTheme(ballTheme)end
	local faceMood=clientUI.faceMood or {};clientUI.faceMood=faceMood
	faceMood.dangerY,faceMood.pressure,faceMood.graceLeft=board:GetAttribute("DangerY")or Config.OverflowY,pressure,graceLeft
	faceMood.itemsOpen,faceMood.reduced=clientUI.items~=nil and clientUI.items.isOpen==true,reduced
	table.clear(clientUI.faceList)
	for source,view in pairs(eggViews)do local input=view.faceInput;input.x,input.y=source.Position.X,source.Position.Y;table.insert(clientUI.faceList,input)end
	clientUI.ballFaces:update(now,clientUI.faceList,faceMood)
	if clientUI.deck.stepNext then clientUI.deck:stepNext(now,faceMood,ballTheme,board)end
	local guide = (board:GetAttribute("OwnedPets") or 0) == 0 and canPlay()
	local flightTarget = Config.flightPoint(aim,.8)
	local drawLCD = false
	local useLCD = lcdEnabled() and viewport.AbsoluteSize.X > 1
    local zoneBackend=if useLCD then lcd.backend else "sprite"
    if rendererPresentation.zoneBackend~=zoneBackend then
        rendererPresentation.zoneBackend=zoneBackend
        -- Global ZIndex: above the well, below the gel (span rows 4, image label 3, sprites 3).
        Art.setBoardPatternDepth(overlay,if zoneBackend=="span"then 3 elseif zoneBackend=="image"then 4 else 2)
        if useLCD and lcd.surface then lcd:attachRegions(zoneLayer)
        else
            zoneLayer.Parent=overlay;zoneLayer.ZIndex=2
            for _,node in ipairs(zoneLayer:GetDescendants())do if node:IsA("GuiObject")then node.ZIndex=2 end end
        end
    end
    local zonesVisible=not(useLCD and lcd.backend=="image")and gui:GetAttribute("MeshPreview")~=true
    if zoneLayer.Visible~=zonesVisible then zoneLayer.Visible=zonesVisible end
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
			local color = clientUI.JellyPalette.byTier[tier].body
			local center = pixelPoint(Config.launchPosition())
			lcd:drawGuide(aim)
			local held=clientUI.heldFace;held.tier=tier;held.expr,held.dx=clientUI.ballFaces.preview(0,now,faceMood);held.star=board:GetAttribute("NextPowerUp")==true;held.mark=nil
			lcd:draw(center, radius, radius, 0, color, 0, nil, held)
		end
	elseif lcd then
		lcd.label.Visible = false
		lcdElapsed = lcdStep
	end
	for source, view in pairs(eggViews) do
		local position, widthScale, heightScale, angle, ripple = view.gel:render(source.Position, dt, now, project, not useLCD, reduced)
		local point = project(Vector2.new(position.X, position.Y))
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
				local face=view.face;face.expr,face.dx=clientUI.ballFaces:get(view.id)
				face.star=source:GetAttribute("PowerUp")==true;face.mark=source:GetAttribute("ItemMark")
				lcd:draw(center, radius * widthScale, radius * heightScale, angle, source.Color, ripple, view.id == rendererPresentation.matchId, face)
			end
		end
		if guide and source:GetAttribute("Tier") == tier and position.Y < Config.OverflowY then
			local delta = math.abs(position.X - flightTarget.X)
			if delta < distance then
				distance = delta
				closest = point
				closestId = view.id
			end
		end
	end
	if drawLCD then
		for _, merge in ipairs(pixelMerges) do
			lcd:merge(merge.first, merge.second, merge.point, merge.radius, merge.resultRadius,
				merge.color, now - merge.start, merge.tier)
		end
		if lcd:finishFrame() then
			lcd.label.Visible = true
		else
			lcd:destroy()
			lcd = nil
			-- Preallocated cheap pieces take over in this same frame, including a
			-- first-paint failure; never expose zero-size or stale cached children.
			for source,view in pairs(eggViews)do view.gel:render(source.Position,0,now,project,true,reduced)end
		end
	end
	local pixelVisible = lcd ~= nil and lcd.label.Visible
	sprites.Visible = not pixelVisible
	track.Visible = not pixelVisible
 for _,dot in ipairs(aimDots)do dot.Visible=not pixelVisible end
	ghost.BackgroundTransparency = if pixelVisible then 1 else 0
	rendererPresentation.matchId = closestId
	for index, hint in ipairs(clientUI.matchSparkles) do
		local sparkle = hint.node
		if sparkle.Visible ~= (closest ~= nil) then sparkle.Visible = closest ~= nil end
		if closest then
			local r = Config.Tiers[tier].radius * markScale
			sparkle.Position = UDim2.fromOffset(closest.X + (if index == 1 then r * 0.85 else -r * 0.95), closest.Y + (if index == 1 then -r * 0.75 else r * 0.2))
			-- 1.2 Hz twinkle, opposite phases; steady under Reduced Motion.
			local twinkle = if reduced then 0.15 else 0.15 + 0.7 * (0.5 + 0.5 * math.sin(now * math.pi * 2.4 + index * math.pi))
			for _, ray in ipairs(hint.rays) do ray.BackgroundTransparency = twinkle end
		end
	end
end)
gui.Destroying:Connect(function()
	if rendererPresentation.destroyed then return end
 rendererPresentation.setFieldOwner(false,board:GetAttribute("ResetId"),reduceEffects())
	rendererPresentation.destroyed=true;rendererPresentation.visible=false
 rendererPresentation.fx:destroy()
 if rendererPresentation.roundEnd then rendererPresentation.roundEnd:destroy()end
 rendererPresentation.jolt:destroy()
 if clientUI.clock then clientUI.clock:destroy();clientUI.clock=nil end
	for _,connection in ipairs(rendererPresentation.connections)do connection:Disconnect()end
	table.clear(rendererPresentation.connections)
	if rendererConnection then rendererConnection:Disconnect();rendererConnection=nil end
	if lcd then lcd:destroy();lcd=nil end
	for _,view in pairs(eggViews)do view.gel:destroy()end
	table.clear(eggViews);table.clear(viewsById);table.clear(pixelMerges)
end)
layout()
updateHud()
roomView:startPresentation(board:GetAttribute("Mode"))
clientUI.ambient:setRound(board:GetAttribute("Mode")=="Board")
