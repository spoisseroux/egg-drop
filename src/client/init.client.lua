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
	for _,name in ipairs({"PetAssets","PetMaterials","PetMaterialsTwoTone","PetCharmAssets","PetToyAssets","SnackAssets"})do
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
require(script.HandheldScreens) -- here for the require order; used once below (ClientLocalBudget)
require(script.HatchReveal)
local DeckScreen = require(script.DeckScreen)
local FirstHatchGuide = require(script.FirstHatchGuide)
local Art = require(script.DeckArt)
local DeckLayout = require(script.DeckLayout)
local Stars=require(script.StarText)
local clientUI={HueIntent=require(script.HueIntent),HueEggView=require(script.HueEggView),PresentationPolicy=require(script.PresentationPolicy),SaveNotice=require(script.SaveNotice),ControllerFocus=require(script.ControllerFocus),AppearanceIntent=require(script.AppearanceIntent),FieldQuestText=require(script.FieldQuestText),fieldCache={},PetContactIntent=require(script.PetContactIntent)}
-- Client-run board B0: owner-only sim determinism check after the loading screen (FeatureFlags.SimCheck).
pcall(function()require(script.SimCheckClient).start()end)
-- B2 client-run board: a lockstep field round's taps, items and pauses go to the driver (nil = today's path).
pcall(function()clientUI.clientSim=require(script.ClientRoundDriver).start()end)
-- Ball themes + faces (batch 2026-11-13 R1): the equipped theme comes from the nursery snapshot.
clientUI.BallThemes=require(game:GetService("ReplicatedStorage").Shared.BallThemes)
clientUI.ballFaces=require(script.BallFaces).new();clientUI.faceList={};clientUI.heldFace={}
function clientUI.isHueOpen()return(clientUI.hueView~=nil and clientUI.hueView:isOpen())or(clientUI.hub~=nil and clientUI.hub:isOpen())
 or(clientUI.stats~=nil and(clientUI.stats.isOpen()or clientUI.stats.isBusy()))or(clientUI.names~=nil and clientUI.names.isOpen())end
require(script.DropDispenser)
require(script.BoardQuestHUD)
local HollowClock = require(script.HollowClock)
local NurseryView = require(script.EggHatchView)
require(script.HatchNavigation)
local RunReceipt = require(script.RunReceipt)
local Portrait = require(script.PetPortrait)
-- QA Q5: the garden "Pocket menu" is the machine hub (DeckMenu is retired).
local MachineHub = require(script.MachineHub)
local audio = Audio.new()
task.delay(1,function()require(script.EggPreview3D).prewarm()end)
-- W2 feel alive: garden ambience + Pocket Deck round music (before RoomView, whose coos use it).
clientUI.ambient=require(script.AmbientAudio).new(audio)
clientUI.JellyPalette=require(ReplicatedStorage.Shared.JellyPalette)
clientUI.ItemCarousel=require(script.ItemCarousel);clientUI.RoundItems=require(ReplicatedStorage.Shared.RoundItems)
clientUI.Pico8=require(ReplicatedStorage.Shared.Pico8)
-- QA v775 note 12: one shared click helper (UIClick) owns every button's sound: it binds
-- each GuiButton under PlayerGui and plays one cue per press (the owner's own kind wins).
clientUI.click=require(script.UIClick)
clientUI.accepted=clientUI.click.play
task.defer(function()clientUI.click.start(audio,player:WaitForChild("PlayerGui"))end)
clientUI.clock=HollowClock.start()
clientUI.worldMotion=require(script.WorldMotion).start()
-- Frutiger Aero (AeroWorld): not even loaded where the build ceiling is off (the live game).
pcall(function()if require(ReplicatedStorage.Shared.Aero).ceiling()then clientUI.aeroWorld=require(script.AeroWorld).start({clock=HollowClock})end end)
pcall(function()require(script.AliveBudget).level()end) -- Alive: starts the frame sampler (beta only)
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local request = remotes:WaitForChild("BoardRequest")
-- The First Hatch (architect review): two one-time events. "EggTapped" when the first tap cracks the Bear's egg
-- (CrackRitual), "DeckShown" when the loading screen has left (LoadingScreen sets LoadingSeconds on PlayerGui).
require(script.CrackRitual).onFirstTap=function()request:FireServer("eggTapped")end
task.spawn(function()
	local gui=player:WaitForChild("PlayerGui")
	if gui:GetAttribute("LoadingSeconds")==nil then gui:GetAttributeChangedSignal("LoadingSeconds"):Wait()end
	-- Code review of the First Hatch: the server drops it while the board or the save is still loading, and records
	-- it once; so it is sent again a little later (never more than three times).
	for _,later in ipairs({0,8,25})do task.wait(later);request:FireServer("deckShown")end
end)
local feedback = remotes:WaitForChild("BoardMerge")
local impacts = remotes:WaitForChild("BoardImpact")
local nurseryRequest = remotes:WaitForChild("HatchRequest")
local nurseryFeedback = remotes:WaitForChild("HatchFeedback")
local trays = ReplicatedStorage:WaitForChild("EggDropBoards")
local board = trays:WaitForChild(tostring(player.UserId))
require(script.HandheldScreens).start(trays, Config)

local function reduceEffects()
	return GuiService.ReducedMotionEnabled or board:GetAttribute("ReducedEffects") == true
end
-- B3 client-run board: on a lockstep round the deck reads the round's published values from its own
-- host (ClientBoardMirror, provisional until the server's round end); otherwise the folder's.
function clientUI.attr(name)
 local mirror=clientUI.mirror
 if mirror then local value,served=mirror:value(name);if served then return value end end
 return board:GetAttribute(name)
end
-- The same reader for modules that take the board folder only to read attributes.
clientUI.boardView={GetAttribute=function(_,name)return clientUI.attr(name)end}
-- True while the mirror draws this serial (the server's events for it were already played locally).
function clientUI.mirrorOwns(serial)return clientUI.mirror~=nil and clientUI.mirror:owns(serial)end

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
 ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
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
	-- QA v735 D4: the LEFT and RIGHT areas themselves are marked (a faint band from the wall
	-- to the threshold with its name at the top), not only their inner edge. The goal's
	-- own area is the brighter one (updateHud); the bands sit under the balls like the lines.
	local band=Art.frame(zoneLayer,if side==-1 then "LeftZone"else "RightZone",Color3.fromHex("#76F6B0"),UDim2.fromScale(0,.025),UDim2.fromScale(.2,.95),2)
	band.BackgroundTransparency=.94;band.Active=false;band.Selectable=false
	local tag=Art.text(band,"Tag",string.upper(if side==-1 then "left"else "right"),UDim2.fromOffset(0,4),UDim2.new(1,0,0,16),Color3.fromHex("#B8F5D0"),12,Art.Font.Heading)
	tag.TextXAlignment=Enum.TextXAlignment.Center;tag.TextTransparency=.45
	fieldZones[index]={node=zone,side=side,band=band,tag=tag}
end

clientUI.centerZone=Art.frame(zoneLayer,"CenterGoalRegion",Color3.fromHex("#466853"),UDim2.fromScale(.4,.025),UDim2.fromScale(.2,.95),2)
clientUI.centerZone.BackgroundTransparency=1;clientUI.centerZone.Active=false;clientUI.centerZone.Selectable=false;clientUI.centerZone.Visible=false
for _,side in ipairs({"Min","Max"})do
 local edge=Art.frame(clientUI.centerZone,side,Color3.fromHex("#466853"),UDim2.fromScale(if side=="Min"then 0 else 1,0),UDim2.new(0,2,1,0),2)
 edge.AnchorPoint=Vector2.new(.5,0);edge.BackgroundTransparency=.35;edge.Active=false;edge.Selectable=false
end
clientUI.lcdMask=Art.lcdCorners(overlay,bezel.BackgroundColor3)
-- QA v775 note 14: on the Pocket Deck the board's rounded corners match the deck screen.
clientUI.syncLcdMask=function()
 local deck=clientUI.deck
 Art.tintLcdCorners(clientUI.lcdMask,if deck and deck.visible and deck.lcd then deck.lcd.BackgroundColor3 else bezel.BackgroundColor3)
end
local lcd = JellyLCD.new(overlay)
-- The chosen deck background, drawn in the board well at 6% (UI-SPEC-REDESIGN-MENUS 5).
Art.boardPattern(overlay)
local lcdStep = 1 / 30
local lcdElapsed = lcdStep
local pixelMerges = {}
local rendererPresentation={visible=false,connections={}}
rendererPresentation.jolt=require(script.DeckMergeJolt).new({clientUI.deviceRoot})
rendererPresentation.fx=require(script.FieldEffects).new(effects)
rendererPresentation.fx:observeDrop(board:GetAttribute("ResetId"),clientUI.attr("Drops")or 0)
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
Art.text(shell, "ModelStamp", "PD·01", UDim2.new(1, -68, 0, 7), UDim2.fromOffset(40, 20), Art.Ink, 10).AutoLocalize = false -- model stamp
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
local readout = label("TextLabel", "GameReadout", "POCKET PALS", rail)
readout.AutoLocalize = false -- the game's name; later readouts are numbers
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
meter:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutDropMeter);layoutDropMeter()
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
Art.text(hardware, "MakerMark", "POCKET PALS", UDim2.fromOffset(0, 0), UDim2.fromOffset(112, 16), Art.Ink, 12)
hardware.MakerMark.Font = Art.Font.Action
hardware.MakerMark.AutoLocalize = false -- the game's name
local firstHatchGuide = FirstHatchGuide.new(rail, dpad.RockerWell, action, meter, status)
firstHatchGuide.meter.Position,firstHatchGuide.meter.Size=UDim2.fromOffset(1,1),UDim2.new(1,-2,1,-2)
local questHUD = require(script.BoardQuestHUD).new(status)
local dispenser = require(script.DropDispenser).new(meter, reduceEffects)
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
 -- v834 phone notes: follow the mode RoomView has shown, not the replicated attribute. The
 -- attribute flips to Room before the close animation, so the deck shrank to the Roblox UI
 -- insets first and then sank; now the insets change under the opaque shade, at the swap.
 -- Code review: a shown mode that has disagreed with the attribute for longer than any
 -- handoff (InsetGrace) is stale, and the attribute wins; a removed character clears it.
 local mode=board:GetAttribute("Mode");local shown=clientUI.shownMode
 if shown~=mode and os.clock()-(clientUI.modeChangedAt or 0)>clientUI.InsetGrace then shown=nil end
 local want=if(shown or mode)=="Board"and size.X>0 and require(script.DeckKit).compactRule(size.X,size.Y)
  then Enum.ScreenInsets.DeviceSafeInsets else Enum.ScreenInsets.CoreUISafeInsets
 if gui.ScreenInsets~=want then gui.ScreenInsets=want end
 if clientUI.deckGui.ScreenInsets~=want then clientUI.deckGui.ScreenInsets=want end
end
clientUI.insetProbe:GetPropertyChangedSignal("AbsoluteSize"):Connect(clientUI.refreshInsets)
clientUI.InsetGrace=2.5 -- s: a close is about 0.5 s to the swap, an open waits under the shade
board:GetAttributeChangedSignal("Mode"):Connect(function()
 clientUI.modeChangedAt=os.clock();clientUI.refreshInsets()
 task.delay(clientUI.InsetGrace+.1,clientUI.refreshInsets)
end)
player.CharacterRemoving:Connect(function()clientUI.shownMode=nil;clientUI.refreshInsets()end)
clientUI.refreshInsets()
clientUI.deck=DeckScreen.new({parent=clientUI.deckHost,overlayParent=clientUI.deviceRoot,viewRoot=backdrop,audio=audio})
clientUI.deck.lcd:GetPropertyChangedSignal("BackgroundColor3"):Connect(clientUI.syncLcdMask)
clientUI.deckResults=require(script.DeckResults).new(clientUI.deck.resultsContent,{audio=audio,reduce=reduceEffects})
-- Part 2b: difficulty picker, a full-LCD layer above the board.
clientUI.heatCallbacks,clientUI.questCallbacks={}, {}
clientUI.heatPicker=require(script.DifficultyPicker).new(clientUI.deck:addOverlay("DeckDifficulty",32),clientUI.heatCallbacks)
-- QA Q5: the quest log opens from the garden machine hub's Quests tile, in its own
-- ScreenGui (above the Wardrobe, under the Collection book), not on the deck.
do
 local Kit=require(script.DeckKit)
 local questGui=make("ScreenGui","EggDropQuests",{ResetOnSpawn=false,ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets,DisplayOrder=12,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,ClipToDeviceSafeArea=false},gui.Parent)
 local questRoot=make("Frame","QuestHost",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1)},questGui)
 clientUI.questHost=require(script.QuestLogHost).new(questRoot)
 local function syncInsets()
  local wanted=Kit.compactInsets(clientUI.insetProbe.AbsoluteSize)
  if questGui.ScreenInsets~=wanted then questGui.ScreenInsets=wanted end
 end
 clientUI.insetProbe:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncInsets);syncInsets()
 gui.Destroying:Connect(function()clientUI.questHost:destroy();questGui:Destroy()end)
end
clientUI.questLog=require(script.QuestLog).new(clientUI.questHost.overlay,clientUI.questCallbacks)
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
 -- QA Q2.4: a ball theme chosen in the shop shows at once (BallShop rolls it back on a refusal).
 local override=clientUI.ballThemeOverride
 if override and os.clock()-override.at<15 and clientUI.BallThemes.ById[override.id]then return override.id end
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
 if clientUI.cancelFirstSpend then clientUI.cancelFirstSpend()end
 if clientUI.welcomeInput then clientUI.welcomeInput()end
end
local function isPickerOpen()
	return picker ~= nil and picker.shade.Visible
end
-- The Deck button's own path (RoomView runs it through requestSwitch); the Play Den's table runs the same one.
function clientUI.playDeck()
	-- Garden Dash: opening the Deck gives up a seat, so it asks first (nil unless Dash is on).
	if clientUI.dash and clientUI.dash:askLeave(function()cancelHatchNavigation();request:FireServer("mode","Board");clientUI.accepted("confirm")end)then return end
	cancelHatchNavigation()
	request:FireServer("mode", "Board");clientUI.accepted("confirm")
end
-- An overlay over the garden (RoomView's overlayOpen; the Play Den's table asks it too).
function clientUI.roomOverlayOpen()
	return isPickerOpen() or (journal and journal.shade.Visible) or (nurseryView and nurseryView:isOpen()) or clientUI.isHueOpen() or (gameMenu and gameMenu.shade.Visible) or (modal and modal.Visible)
		or (clientUI.dash ~= nil and (clientUI.dash:held() or clientUI.dash:panelOpen()))
end
local roomView = RoomView.new(gui, backdrop, board, audio, function()
	clientUI.playDeck()
end, function()
	if openPicker()then clientUI.accepted("confirm")end
end, function()
	if openJournal()then clientUI.accepted("confirm")end
end, function()
	return clientUI.roomOverlayOpen()
end, reduceEffects, function() if openNursery then openNursery() end end)
roomView.onShowMode=function(mode)clientUI.shownMode=mode;clientUI.refreshInsets()end
clientUI.petContactRemote=remotes:WaitForChild("PetContact")
roomView.petContactIntent=clientUI.PetContactIntent.new({now=os.clock,
 send=function(actionName,payload)clientUI.petContactRemote:FireServer(actionName,payload)end,
 eligible=function(context)return roomView:contactEligible(context)end,
 saved=function(receipt)
  -- G2: any saved pet ends the paw prints; the first hello (FirstHelloBonus) shows the receipt's own total, and the
  -- garden pills wait out its moment (Nothing else speaks for HelloQuiet s).
  clientUI.petSavedAt=os.clock()
  local hello=type(receipt)=="table"and receipt.hello or nil
  local Hello=require(ReplicatedStorage.Shared.FirstHello)
  if require(ReplicatedStorage.Shared.FeatureFlags).FirstHelloBonus==true and Hello.integer(hello,Hello.Stored)and hello>0 then
   clientUI.helloQuietUntil=os.clock()+2.5
   if roomView.affection then roomView.affection:showHello(1+hello,roomView.pet and roomView.pet.secondaryColor,reduceEffects())end
   return
  end
  if roomView.affection then roomView.affection:showSaved(reduceEffects())end
 end,
 -- QA Q2.7: the day's five pets are used; say so on the pet (at most every 20 s).
 capped=function()
  local now=os.clock();if now-(clientUI.petCapToldAt or -math.huge)<20 or not roomView.affection then return end
  clientUI.petCapToldAt=now
  local UICopy=require(ReplicatedStorage.Shared.UICopy);local shown=roomView.shownPet;local pet=shown and Pets.byId[shown.id]
  roomView.affection:showCapped(if pet then UICopy.get("pet.capped",{pet=pet.name})else UICopy.get("pet.cappedSolo"),reduceEffects())
 end})
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
			or (nurseryView and nurseryView:isOpen()) or clientUI.isHueOpen() or (gameMenu and gameMenu.shade.Visible)
			or (clientUI.dash ~= nil and (clientUI.dash:held() or clientUI.dash:panelOpen())),
		coreMenu=GuiService.MenuIsOpen,textCapture=UserInputService:GetFocusedTextBox()~=nil,
		snapshot=nurseryState,rank=board:GetAttribute("OwnedPets") or 0,trials=board:GetAttribute("TrialMask") or 0}
end
roomView.canRoam=function()return LoungeStations.canRoam(stationContext())end
roomView.stations=LoungeStations.new({player=player,read=stationContext,
	lounge=function()return workspace:FindFirstChild("EggDropLounge")end,
	triggered=ProximityPromptService.PromptTriggered,routes={
		Customize=function()if openPicker("Shell",nil,"workbench")then clientUI.accepted("confirm")end end,Journal=function()if roomView.care and roomView.care:station()then clientUI.accepted("confirm")end end,Eggs=function()if clientUI.eggCornerTurn and clientUI.eggCornerTurn(visitEggs)then return end;if visitEggs()then clientUI.accepted("confirm")end end,
	}})
-- W2 station attract (icon, shaft, ring, ping); "used" is session memory on this client.
clientUI.attract=require(script.StationAttract).new({player=player,read=stationContext,triggered=ProximityPromptService.PromptTriggered,
	voice=clientUI.ambient,reduced=reduceEffects,cradleBusy=function()return roomView.care~=nil and roomView.care.artToken~=nil and roomView.care.artToken~=false end})
gui.Destroying:Connect(function()clientUI.attract:destroy();clientUI.ambient:destroy()end)

do
	local handoff = gui.DeckHandoff
	-- QA v735 D2: one shade, the whole screen. It used to sit in the inset SafeContent
	-- frame with a second full-screen curtain behind it, which read as two overlays.
	handoff.Parent = overlayGui
	local curtain = Art.frame(bleed, "HandoffBacking", Art.Backdrop, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 2)
	local function updateBacking()
		bleed.Enabled = gui.Enabled
		clientUI.deckGui.Enabled = gui.Enabled and backdrop.Visible
		overlayGui.Enabled = gui.Enabled
		backing.Visible = backdrop.Visible
		curtain.Visible = false
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
local reveal = require(script.HatchReveal).new(modal, pet, audio)
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
 do -- QA v760: the board's area bands, lines and names take the plate's accent (they were mint on every plate).
  local default=id==Themes.House -- round 6 (code review): the mint bands are Scout's, not the default plate's
  local accent=if default then Color3.fromHex("#76F6B0")else theme.accent or Color3.fromHex("#76F6B0")
  local line=if default then Color3.fromHex("#466853")else accent:Lerp(Color3.fromHex("#20242A"),.55)
  for _,item in ipairs(fieldZones)do
   item.band.BackgroundColor3=accent;item.node.BackgroundColor3=line
   item.tag.TextColor3=if default then Color3.fromHex("#B8F5D0")else accent:Lerp(Color3.new(1,1,1),.5)
  end
  clientUI.centerZone.BackgroundColor3=line
  for _,edge in ipairs(clientUI.centerZone:GetChildren())do if edge:IsA("Frame")then edge.BackgroundColor3=line end end
 end
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
		and not (nurseryView and nurseryView:isOpen()) and not clientUI.isHueOpen() and clientUI.attr("FieldPhase") ~= "Settling"
		and not board:GetAttribute("RoundOver") and not clientUI.deckOverlayOpen()
end

local function canPlay()
	return canAim() and not isPickerOpen() and not roomView.busy and not GuiService.MenuIsOpen
		and clientUI.attr("FieldReady") ~= false
end

-- ASMR-AND-SCALE-LOOK 1, 2: the one vibration module (beta only: Alive "asmr"); the hatch, the deck merges and the
-- egg machine buzz through it, and Settings shows its Vibration row where the device can buzz.
clientUI.haptics = require(script.Haptics)
picker = DeckPicker.new(safeOverlays, make, label, function()end, function(reason)
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(picker.shade) then
		local controls = gui.LoungeControls
		GuiService.SelectedObject = if board:GetAttribute("Mode") == "Room" and controls.Visible
			then controls.OpenHandheld else nil
	end
	rail.Interactable = canAim()
 -- QA Q5: Back from Deck style / Settings opened at the machine hub returns there
 -- (sliding in from the left); Back from Settings opened at the pause menu reopens it.
 local back=clientUI.pickerReturn;clientUI.pickerReturn=nil
 if reason=="back"and type(back)=="table"and back.hub and openMenu and not roomView.busy and not modal.Visible and not nurseryView:isOpen() and not clientUI.isHueOpen()then
  task.defer(function()openMenu({focus=back.hub,slideFrom=-require(script.DeckKit).SlideOffset})end)
 elseif reason=="back"and type(back)=="table"and back.pocket then
  task.defer(function()clientUI.openPocketMenu(back.pocket)end)
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
	if actionName == "vibration" then
		-- Turning it on plays one sample buzz, so the player feels what they chose (section 2 "The setting").
		local on = clientUI.haptics.setEnabled(not clientUI.haptics.isEnabled())
		if on then clientUI.haptics.play("sample") end
		picker:setVibration(clientUI.haptics.available(), on)
		return
	end
	request:FireServer(actionName)
end)

nurseryView = NurseryView.new(safeOverlays, audio, reduceEffects, function(actionName, value, revision)
	clientUI.lastNurseryRequestAt = os.clock() -- HatchFlow spaces its follow-up buys from this (beta 17 R13)
	nurseryRequest:FireServer(actionName, value, revision)
end)
-- The item eggs' sends (hue, look, material, toy, feature): the egg corner's buy crank hears each press first
-- (clientUI.eggPressed, set only where the corner is mounted; a retried send carries the same value.id).
function clientUI.sendNursery(action,value,revision)
 if clientUI.eggPressed then pcall(clientUI.eggPressed,action,value)end
 clientUI.lastNurseryRequestAt=os.clock() -- HatchFlow spaces its follow-up buys from this (beta 17 R13)
 nurseryRequest:FireServer(action,value,revision)
end
-- Robux store page inside the egg shop. Server-initiated prompts only.
clientUI.storeView=require(script.StoreView).new(nurseryView.shade,{reduceEffects=reduceEffects,
 request=function(actionName,key)if clientUI.storeRequest then clientUI.storeRequest:FireServer(actionName,key)end end})
clientUI.storeView.onAccepted=function(kind)clientUI.accepted(kind)end
nurseryView:attachStore(clientUI.storeView)
-- Stars bought with Robux (Spencer 2026-11-22): the cue plays when the grant lands, or once when
-- Roblox's purchase window closes or the game has the focus again (PurchaseCue).
clientUI.purchaseCue=require(script.PurchaseCue).new({now=os.clock,defer=task.defer,
 muted=function()return audio.group.Volume==0 end,
 play=function()return audio:play("stars_bought",1,Audio.StarsBoughtGain)==true end})
clientUI.storeView.onGranted=function()clientUI.purchaseCue:granted()end
do
 local Market=game:GetService("MarketplaceService")
 local links={
  Market.PromptProductPurchaseFinished:Connect(function(userId,productId,purchased)
   if userId~=player.UserId then return end
   clientUI.storeView:purchaseWindowClosed(productId,purchased==true);clientUI.purchaseCue:resume()
  end),
  Market.PromptGamePassPurchaseFinished:Connect(function(who,passId,purchased)
   if who~=player then return end
   clientUI.storeView:purchaseWindowClosed(passId,purchased==true);clientUI.purchaseCue:resume()
  end),
  UserInputService.WindowFocused:Connect(function()clientUI.purchaseCue:resume()end)}
 gui.Destroying:Connect(function()for _,link in ipairs(links)do link:Disconnect()end end)
end
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
 send=function(action,value,revision)clientUI.sendNursery(action,value,revision)end,
 changed=function()if clientUI.hueView then clientUI.hueView:refresh()end;if clientUI.syncDirectHatch then clientUI.syncDirectHatch()end end})
clientUI.materialIntent=require(script.MaterialIntent).new({id=function()return HttpService:GenerateGUID(false)end,
 available=function()return clientUI.itemAvailable("material")end,send=function(action,value,revision)clientUI.sendNursery(action,value,revision)end,
 changed=function()if clientUI.hueView then clientUI.hueView:refresh()end;if clientUI.syncDirectHatch then clientUI.syncDirectHatch()end end})
clientUI.toyIntent=require(script.ToyIntent).new({id=function()return HttpService:GenerateGUID(false)end,
 available=function()return clientUI.itemAvailable("toy")end,send=function(action,value,revision)clientUI.sendNursery(action,value,revision)end,
 changed=function()if clientUI.syncFirstSpend then clientUI.syncFirstSpend(clientUI.toyIntent.state)end;if clientUI.hueView then clientUI.hueView:refresh()end;if clientUI.syncDirectHatch then clientUI.syncDirectHatch()end end})
clientUI.featureIntent=require(script.FeatureIntent).new({id=function()return HttpService:GenerateGUID(false)end,
 available=function()return clientUI.itemAvailable("feature")end,send=function(action,value,revision)clientUI.sendNursery(action,value,revision)end,
 changed=function()if clientUI.hueView then clientUI.hueView:refresh()end;if clientUI.syncDirectHatch then clientUI.syncDirectHatch()end end})
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
 -- v2 Hatch another on the result card (HatchFlow:again).
 hatchAgain=function(kind)return clientUI.hatchFlow~=nil and clientUI.hatchFlow:again(kind)end,
 againPending=function()return clientUI.hatchFlow~=nil and clientUI.hatchFlow:againPending()end,
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
 shop=function()if openNursery then openNursery();nurseryView:selectRecipe("look")end end, -- v816: the Material tab's egg link (the Hue Egg is retired)
 eggs=function()if openNursery then openNursery();nurseryView:selectRecipe("toy")end end,
 materialShop=function()if openNursery then openNursery();nurseryView:selectRecipe("material")end end,
 toyShop=function()if openNursery then openNursery();nurseryView:selectRecipe("toy")end end,
 featureShop=function()if openNursery then openNursery();nurseryView:selectRecipe("feature")end end,
 whiteSecond=function(petId,on)request:FireServer("whiteSecond",{petId=petId,on=on})end,
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
   if back=="hub"and clientUI.openHub then clientUI.openHub({slideFrom=-require(script.DeckKit).SlideOffset})end
  end
  -- QA Q5: Customize left the Companions hub some other way, so its Back no longer
  -- leads to the machine hub.
  if back=="hub"and reason~="back"and clientUI.machineReturn=="companions"then clientUI.machineReturn=nil end
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
 -- QA v760: Customize never replays a hatch receipt; only the Hatch eggs pages do.
 clientUI.hueView.quietOpen=not purchasePage
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
do
 -- QA v685 H4 / v842: direct hatch from Hatch eggs (HatchFlow, shared with the hatch spec).
 local flow=require(script.HatchFlow).new({intents=clientUI,state=function()return nurseryState end,view=clientUI.hueView,openHue=function(...)return clientUI.openHue(...)end,
  lastRequest=function()return clientUI.lastNurseryRequestAt end})
 clientUI.hatchFlow=flow
 local function open(kind,purchase)flow:open(kind,purchase)end
 nurseryView.onOpenHue=function(purchase)open("hue",purchase)end
 nurseryView.onOpenLook=function(purchase)open("look",purchase)end
 nurseryView.onOpenMaterial=function(purchase)open("material",purchase)end
 nurseryView.onOpenToy=function(purchase)open("toy",purchase)end
 nurseryView.onOpenFeature=function(purchase)open("feature",purchase)end
 -- QA v685 R10: the Hatch eggs stamp chip opens Quests on the daily tab.
 nurseryView.onQuests=function()
  if not nurseryView:isOpen()then return end
  nurseryView:close("quests")
  task.defer(function()if not nurseryView:isOpen()then clientUI.openQuestLog("daily")end end)
 end
 clientUI.syncDirectHatch=function()flow:sync()end
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
  -- Slice E: the Wardrobe's own pet (no fallback pet here; WardrobeShop.open picks one).
  local shop=clientUI.wardrobe;local petId=shop and shop.petId or ""
  local row=(state and state.petWearables or {})[petId]
  local features=(state and state.petFeatures or {})[petId]or {}
  -- Slice C: the shelf week of this snapshot (its own dailyDay), so the price sent is the server's.
  return {wallet=state and state.nectar or 0,week=require(script.ShelfDeal).week(state or {}),
   row={owned=table.clone(row and row.owned or {}),equipped=table.clone(row and row.equipped or {})},
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
   -- Every row ever: an owned gated item still says so while gates are off.
   local item=WearableCatalog.item(order.petId,order.itemId)or WearableCatalog.forPet(order.petId,math.huge).byId[order.itemId]
   clientUI.wardrobeToaster=clientUI.wardrobeToaster or Kit.toaster(host)
   if item then clientUI.wardrobeToaster.show(if order.action=="wearableBuy"then item.name.." bought"elseif order.wear then item.name.." on"else item.name.." off")end
  end,
  back=function()clientUI.wardrobe:close();if clientUI.isHueOpen()then clientUI.hueView:refresh()end end,
  -- Levels matter: a locked item's button goes to the stats panel on the stat that unlocks it.
  train=function(route)clientUI.closeAllMenus("stats");clientUI.openStats({from="rail",stat=route.stat,petId=route.petId})end})
 clientUI.isWardrobeOpen=function()return clientUI.wardrobe:isOpen()end
 clientUI.syncWardrobe=function(state)if clientUI.wardrobe:isOpen()then clientUI.wardrobe:setContext(context(state))end end
 clientUI.openWardrobe=function(petId,itemId)
  if not nurseryState or roomView.busy or not WearableCatalog.hasItems(petId or "")then return false end
  if GuiService.SelectedObject then GuiService.SelectedObject=nil end
  syncInsets();clientUI.wardrobe.petId=petId
  clientUI.wardrobe:open(petId,context(nurseryState))
  if itemId then clientUI.wardrobe:showItem(itemId)end
  return true
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
   if rowId=="stats"then return clientUI.openStats~=nil and clientUI.openStats({from="hub",petId=petId,slideFrom=Kit.SlideOffset})==true end
   if rowId=="name"then return clientUI.openNames~=nil and clientUI.openNames({from="hub",petId=petId,slideFrom=Kit.SlideOffset})==true end
   -- UI-SPEC-v816 3: Toys is its own screen (the Customize view on its Toys page).
   if rowId=="customize"or rowId=="toys"then
    clientUI.hub:close("customize")
    -- QA Q2.2: Customize slides in from the right, as the Pets page does.
    clientUI.hueView.slideFrom=Kit.SlideOffset
    local opened=clientUI.openHue(if rowId=="toys"then "toys"else "palette",petId,"hub");clientUI.hueView.slideFrom=nil
    if opened then return true end
    clientUI.openHub();return false
   end
   return false
  end,
  follow=function(petId)request:FireServer("companion",petId);return true end,
  -- v2 Bunny: adopt an earned pet for its fixed Star price (server: HatchRequest "petAdopt").
  adopt=function(petId,price)
   local id=HttpService:GenerateGUID(false)
   nurseryRequest:FireServer("petAdopt",{id=id,petId=petId,price=price},nurseryState and nurseryState.revision or 0)
   return id
  end,
  -- QA Q5: opened from the machine hub's Companions tile, Back returns there; Customize
  -- keeps the way back (it reopens this hub), any other close forgets it.
  closed=function(reason)
   if clientUI.machineReturn~="companions"then return end
   if reason=="back"then clientUI.returnToMachineHub("companions")
   elseif reason~="customize"and reason~="stats"and reason~="names"then clientUI.machineReturn=nil end
  end})
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
  -- Get Stars page (restyle 2026-11-21): W / S / Up / Down pick an offer, Enter buys it.
  -- Back stays on the existing nurseryView:close path.
  if nurseryView:isOpen()and nurseryView:isStoreOpen()then
   local store=clientUI.storeView
   local delta=if key==Enum.KeyCode.Up or key==Enum.KeyCode.W then -1 elseif key==Enum.KeyCode.Down or key==Enum.KeyCode.S then 1 else 0
   if delta~=0 then if state==Enum.UserInputState.Begin then store:move(delta)end;return Enum.ContextActionResult.Sink end
   -- Enter only (code review: Space is the jump key, too easy to press by reflex).
   if key==Enum.KeyCode.Return or key==Enum.KeyCode.KeypadEnter then if state==Enum.UserInputState.Begin then store:buySelected()end;return Enum.ContextActionResult.Sink end
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
-- Companions hub (11). Opened from the garden machine hub's Collection book tile (QA Q5;
-- it left the Companions hub and the pause menu). Claims go out as
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
   if message.faceplate then do local plate=require(ReplicatedStorage.Shared.DeckThemes).ById[message.faceplate];clientUI.bookToaster.show(if plate and message.faceplate~="bookworm"then UICopy.get("book.toast.plate",{name=plate.name})else UICopy.get("book.toast.bookworm"))end end
  end,
  closed=function(reason)
   clientUI.syncPause();if updateHud then task.defer(updateHud)end
   -- QA Q5: opened from the machine hub's Collection book tile, Back returns there.
   if clientUI.machineReturn=="book"then
    if reason=="back"then clientUI.returnToMachineHub("book")else clientUI.machineReturn=nil end
   end
  end,
  back=function()clientUI.accepted("back")end})
 clientUI.openBook=function(options)
  if not nurseryState or roomView.busy or clientUI.book:isOpen()or(clientUI.stats~=nil and clientUI.stats.isBusy())then return false end
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
-- v2 S3: the pet stats panel and the level-up line (StatsHost owns the wiring). Opened
-- from the Companions hub's Stats button, pet focus and a tap on the level-up line.
do
 local Kit=require(script.DeckKit)
 clientUI.stats=require(script.StatsHost).mount({parent=gui.Parent,insetProbe=clientUI.insetProbe,
  state=function()return nurseryState end,activeId=function()return board:GetAttribute("CompanionId")end,
  -- v2 Stat Snacks: the panel's Snacks view feeds in place (SnackHost, mounted below).
  inRound=function()return board:GetAttribute("Mode")~="Room"end,
  feed=function(snackId,options)return clientUI.snacks~=nil and clientUI.snacks.feed(snackId,"panel",options)==true end,
  step=function(dt)if clientUI.snacks then clientUI.snacks.stepPanel(dt)end end,
  -- Closing the panel stops its pet's eating; cancel's onDone clears the host's busy state.
  cancelFeed=function()if clientUI.snacks then clientUI.snacks.panel:cancel()end end,
  openEggs=function()task.defer(function()if openNursery then openNursery();nurseryView:selectRecipe("stat")end end)end,
  -- Levels matter: the reward guide's "Go to shop", and the medal moment (only with nothing else on screen).
  openShop=function(area,ref)task.defer(function()
   if area=="wardrobe"then clientUI.openWardrobe(board:GetAttribute("CompanionId"),ref)
   else openPicker(if area=="balls"then "Balls"else "Shell",nil,"workbench")end
  end)end,
  audio=audio,playerGui=gui.Parent,
  quiet=function()return board:GetAttribute("Mode")=="Room"and not roomView.busy and not roomView.focusing and not nurseryView:isOpen()
   and not(nurseryState and nurseryState.lastHatch)and not(clientUI.snacks and clientUI.snacks.reveal and clientUI.snacks.reveal:isOpen())
   and not clientUI.isHueOpen()and not clientUI.book:isOpen()and not(clientUI.isWardrobeOpen and clientUI.isWardrobeOpen())
   and not modal.Visible and not isPickerOpen()and not journal.shade.Visible and not gameMenu.shade.Visible and not clientUI.questLog.visible
   and not GuiService.MenuIsOpen and not clientUI.deckResults.visible and not(clientUI.bugReport and clientUI.bugReport:isOpen())
   and not(clientUI.dash and clientUI.dash:held())end,
  appearance=function(petId)return nurseryView.appearanceFor(petId)end,
  canOpen=function()return not roomView.busy and board:GetAttribute("Mode")=="Room"and not(nurseryState and nurseryState.lastHatch)
   and not clientUI.book:isOpen()and not clientUI.hueView:isOpen()and not(clientUI.isWardrobeOpen and clientUI.isWardrobeOpen())
   and not modal.Visible and not clientUI.questLog.visible and not(clientUI.bugReport and clientUI.bugReport:isOpen())
   and not(clientUI.names and clientUI.names.isOpen())end,
  prepare=function()
   cancelHatchNavigation();clearPlayInputs();picker:close();journal:close();nurseryView:close("hue")
   if gameMenu and gameMenu.shade.Visible and closeMenu then closeMenu()end
   if clientUI.hub:isOpen()then clientUI.hub:close("stats")end
   if roomView.focusing then roomView:useRoomCamera(false)end
  end,
  held=function()return board:GetAttribute("Mode")~="Room"and not clientUI.deckResults.visible end,
  reopenHub=function()if clientUI.openHub then clientUI.openHub({slideFrom=-Kit.SlideOffset})end end,
  -- Back to the hub keeps the machine hub's way back; any other close forgets it.
  closed=function(reason,from)if clientUI.machineReturn=="companions"and not(reason=="back"and from=="hub")then clientUI.machineReturn=nil end end})
 clientUI.openStats=function(options)return clientUI.stats.open(options)end
 roomView.openStats=clientUI.openStats
 gui.Destroying:Connect(function()clientUI.stats.destroy()end)
end
-- v2 pet names: the naming screen (Companions → pet → Name), the Names Egg card and its reveal on
-- the Pop-Out Stage, and the name on the petting card (RoomView.shownName reads nameState).
do
 local Kit=require(script.DeckKit)
 local Rail=require(script.NotificationRail)
 local railOwner=Instance.new("Folder");railOwner.Name="NamesRailOwner";railOwner.Parent=gui.Parent
 clientUI.names=require(script.NameScreen).mount({parent=gui.Parent,insetProbe=clientUI.insetProbe,remotes=remotes,audio=audio,
  state=function()return nurseryState end,
  appearance=function(petId)return nurseryView.appearanceFor(petId)end,
  canOpen=function()return not roomView.busy and board:GetAttribute("Mode")=="Room"and not(nurseryState and nurseryState.lastHatch)
   and not clientUI.book:isOpen()and not clientUI.hueView:isOpen()and not(clientUI.isWardrobeOpen and clientUI.isWardrobeOpen())
   and not clientUI.stats.isOpen()and not clientUI.stats.isBusy()and not modal.Visible and not clientUI.questLog.visible and not(clientUI.bugReport and clientUI.bugReport:isOpen())end,
  prepare=function()
   cancelHatchNavigation();clearPlayInputs();picker:close();journal:close();nurseryView:close("hue")
   if gameMenu and gameMenu.shade.Visible and closeMenu then closeMenu()end
   if clientUI.hub:isOpen()then clientUI.hub:close("names")end
   if roomView.focusing then roomView:useRoomCamera(false)end
  end,
  reopenHub=function()if clientUI.openHub then clientUI.openHub({slideFrom=-Kit.SlideOffset})end end,
  closed=function(reason,from)if clientUI.machineReturn=="companions"and not(reason=="back"and from=="hub")then clientUI.machineReturn=nil end end,
  notify=function(text)Rail.enqueue(railOwner,"name:"..text,{text=text,icon="★",duration=4.5})end})
 clientUI.openNames=function(options)return clientUI.names.open(options)end
 roomView.nameState=function()return nurseryState end
 gui.Destroying:Connect(function()clientUI.names.destroy()end)
end
-- v2 Stat Eggs and Stat Snacks (SnackHost): the Stat Egg on Hatch eggs and its reveal, the pouch
-- in the stats panel and in pet focus, the eating sequence and other players' "ate a snack" beat.
do
 local function petName(petId)local pet=Pets.byId[petId or ""];return pet and pet.name or "Bear"end
 local function pouchModel()
  local state=nurseryState or {}
  local egg=type(state.statEgg)=="table"and state.statEgg or {}
  local petId=board:GetAttribute("CompanionId")
  local ps=state.petStats;local entry=type(ps)=="table"and type(ps.pets)=="table"and ps.pets[petId or ""]or nil
  return{pouch=egg.pouch or {},boosts=entry and entry.boosts or {},total=egg.pouchSize}
 end
 clientUI.snacks=require(script.SnackHost).mount({remotes=remotes,audio=audio,playerGui=gui.Parent,
  state=function()return nurseryState end,activeId=function()return board:GetAttribute("CompanionId")end,petName=petName,
  roomView=roomView,inRound=function()return board:GetAttribute("Mode")~="Room"end,
  closeShop=function()if nurseryView:isOpen()then nurseryView:close("stat");return true end;return false end,
  -- Round 3 (Spencer): Close on a Stat Egg result returns to Hatch eggs, on the Stat Egg.
  reopenEggs=function()task.defer(function()if openNursery and not nurseryView:isOpen()then openNursery();nurseryView:selectRecipe("stat")end end)end,
  openStats=function(options)return clientUI.openStats(options)end,
  ownPetVisual=function()return roomView.pet end,
  otherPetVisual=function(userId)
   local other=Players:GetPlayerByUserId(userId)
   local entry=other and roomView.companions and roomView.companions.active[other]
   return entry and entry.visual or nil
  end})
 nurseryView.statPet=function()return board:GetAttribute("CompanionId")end
 nurseryView.onOpenStat=function(free)clientUI.snacks.buy(free)end
 roomView.snackStep=function(dt)clientUI.snacks.stepGarden(dt)end
 roomView.snackModel=pouchModel
 roomView.snackFeed=function(snackId,onBusy)return clientUI.snacks.feed(snackId,"garden",{onBusy=onBusy})end
 -- The client-only carry feedback in pet focus: the first time a held snack enters the ring, a sniff.
 local sniffed=false
 roomView.snackCarry=function(kind)
  if kind=="lift"then sniffed=false
  elseif kind=="enter"and not sniffed then sniffed=true;pcall(function()audio:play("snack_sniff",1,.45)end)
  elseif kind=="close"then clientUI.snacks.garden:cancel()end
 end
 clientUI.snacks.onChanged=function()
  if roomView.focusUI and roomView.focusUI:snacksOpen()then roomView.focusUI:refreshSnacks()end
 end
 gui.Destroying:Connect(function()clientUI.snacks.destroy()end)
end
-- v1 track B: Settings > "Report a bug / Suggest something". Own ScreenGui above the
-- book; the sheet opens over Settings and Back returns there. Replies ride BugReport.
do
 local Kit=require(script.DeckKit)
 local reportGui=make("ScreenGui","EggDropReport",{ResetOnSpawn=false,ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets,DisplayOrder=14,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,ClipToDeviceSafeArea=false},gui.Parent)
 local host=make("Frame","ReportHost",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1)},reportGui)
 local reportRemote,replies=nil,nil -- found without blocking boot
 local function syncInsets()
  local wanted=Kit.compactInsets(clientUI.insetProbe.AbsoluteSize)
  if reportGui.ScreenInsets~=wanted then reportGui.ScreenInsets=wanted end
 end
 local function context()
  local last=UserInputService:GetLastInputType()
  local device=if last==Enum.UserInputType.Touch then "touch"elseif string.match(last.Name,"^Gamepad")then "gamepad"elseif UserInputService.VREnabled then "vr"else "keyboard"
  local camera=workspace.CurrentCamera;local size=if camera then camera.ViewportSize else Vector2.zero
  local back=clientUI.pickerReturn
  local from=if type(back)=="table"and back.pocket then "pocket"elseif type(back)=="table"and back.hub then "hub"else "settings"
  local okText,textSize=pcall(function()return GuiService.PreferredTextSize.Name end)
  return{device=device,width=size.X,height=size.Y,mode=board:GetAttribute("Mode"),screen="settings",from=from,
   textSize=if okText then textSize else nil,reducedMotion=GuiService.ReducedMotionEnabled}
 end
 clientUI.bugReport=require(script.BugReportSheet).new(host,{
  send=function(packet)if reportRemote then reportRemote:FireServer(packet)end end,
  context=context,accepted=function(kind)clientUI.accepted(kind)end,
  closed=function()if picker and picker.shade.Visible and picker.active=="Settings"and string.match(UserInputService:GetLastInputType().Name,"^Gamepad")then GuiService.SelectedObject=picker.reportButton end end,
 })
 picker.onReport=function()
  if roomView.busy or clientUI.bugReport:isOpen()then return false end
  syncInsets()
  return clientUI.bugReport:open(context())
 end
 local function hook(remote)
  if not remote or reportRemote then return end
  reportRemote=remote
  replies=remote.OnClientEvent:Connect(function(reply)if type(reply)=="table"then clientUI.bugReport:receive(reply)end end)
 end
 hook(remotes:FindFirstChild("BugReport"))
 if not reportRemote then task.spawn(function()hook(remotes:WaitForChild("BugReport",60))end)end
 clientUI.insetProbe:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncInsets)
 gui.Destroying:Connect(function()if replies then replies:Disconnect()end;clientUI.bugReport:destroy();reportGui:Destroy()end)
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
 if journal.shade.Visible then for i,p in pairs(journal.portraits)do if p.sprite then require(script.PetPortrait).apply(p.sprite,nurseryView.appearanceFor(Pets.collection[i].id))end end end
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
	-- Growth cuts: the results nudge's egg, picked once on this open if it is still on sale (never a later open:
	-- the walk from the deck opens Hatch eggs within 4 s or not at all, LoungeStations.visitEggs).
	local pick=clientUI.eggPick;clientUI.eggPick=nil
	if pick and nurseryView:isOpen()and os.clock()-pick.at<5 and(pick.id~="look"or require(ReplicatedStorage.Shared.LookEggCatalog).EnablePurchases==true and nurseryState.lookAvailable~=false)then
		nurseryView:selectRecipe(pick.id)
	end
end
hatchNavigation = require(script.HatchNavigation).new({
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
	elseif reason == "exit" then
		-- Code review: the first Bear's "Back" lands in the garden, as the button says.
		if board:GetAttribute("Mode") ~= "Room" then clientUI.leaveDeck() end
	elseif reason == "earn" or reason == "afterHatch" then
		hatchNavigation:play()
	end
	-- QA Q5: opened from the machine hub's Hatch eggs tile, Back (X / B) returns there.
	if clientUI.machineReturn == "hatch" then
		-- "storeBack": Back from the Get Stars page, opened from the machine hub.
		if reason == "close" or reason == "storeBack" then clientUI.returnToMachineHub("hatch") else clientUI.machineReturn = nil end
	end
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
    if clientUI.stats then clientUI.stats.sync(state)end
    if clientUI.names then clientUI.names.sync(state)end
    if roomView.focusUI and roomView.focusUI.snacksOpen and roomView.focusUI:snacksOpen()then roomView.focusUI:refreshSnacks()end
    clientUI.hueIntent:update(state)
    clientUI.materialIntent:update(state)
    clientUI.toyIntent:update(state)
    clientUI.featureIntent:update(state)
	currentSaveNotice=clientUI.SaveNotice.resolve(board:GetAttribute("SaveStatus"),state)
	if refreshSaveNotice then refreshSaveNotice()end
	roomView.stations:refresh()
	roomView.transition:refresh()
	nurseryView:update(state)
 if clientUI.syncDirectHatch then clientUI.syncDirectHatch()end
 if clientUI.syncFirstSpend then clientUI.syncFirstSpend(state)end
	local result = state.lastHatch
 if result and clientUI.isHueOpen()then clientUI.hueView:close("forced")end
 if result and clientUI.stats then clientUI.stats.close("forced")end -- the panel and the medal moment
 if result and clientUI.names then clientUI.names.close("forced")end
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

-- QA Q5 machine hub: the Pocket menu outside rounds. Its own ScreenGui (beside the
-- Companions hub, 11); a tile opens that machine's screen as its station does (the hub
-- closes first, so the station routes see a free garden) and Back from it reopens the
-- hub, sliding in from the left. `gameMenu` keeps its old callers: shade.Visible is
-- "open", activate("close") closes and update(snapshot) refreshes.
do
 local Kit=require(script.DeckKit)
 local UICopy=require(ReplicatedStorage.Shared.UICopy)
 local hubGui=make("ScreenGui","EggDropMachineHub",{ResetOnSpawn=false,ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets,DisplayOrder=11,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,ClipToDeviceSafeArea=false},gui.Parent)
 local host=make("Frame","MachineHubHost",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1)},hubGui)
 local function syncInsets()
  local wanted=Kit.compactInsets(clientUI.insetProbe.AbsoluteSize)
  if hubGui.ScreenInsets~=wanted then hubGui.ScreenInsets=wanted end
 end
 clientUI.insetProbe:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncInsets);syncInsets()
 gameMenu=MachineHub.new(host,{
  reduced=reduceEffects, -- QA v775 note 9: the tile art stands still under Reduced Effects
  open=function(id)return clientUI.openMachine(id)end,
  -- Before the first pet: the tile still takes the tap and says why (as the pause menu does).
  locked=function()
   clientUI.machineToaster=clientUI.machineToaster or Kit.toaster(host)
   clientUI.machineToaster.show(UICopy.get("menu.subtitle.locked"))
   audio:play("aim",.6,.3)
  end,
  closed=function(reason)
   if reason=="destroy"then return end
   roomView:setMenuOpen(false)
   if reason=="back"then clientUI.accepted("back")end
  end})
 -- Focus is the hub's own (as the Companions hub's is): above the sheet handoff and the game controls.
 ContextActionService:BindActionAtPriority("EggDropMachineHub",function(_,state,input)
  if not gameMenu:takesInput()or UserInputService:GetFocusedTextBox()or GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end
  local action=MachineHub.keyAction(input.KeyCode)
  if not action then return Enum.ContextActionResult.Pass end
  if state==Enum.UserInputState.Begin then
   local moved=gameMenu:input(input.KeyCode)
   if moved and action~="open"and action~="back"then audio:play("aim",1.1,.35)
   elseif moved and action=="open"then clientUI.accepted("confirm")end
  end
  return Enum.ContextActionResult.Sink
 end,false,Enum.ContextActionPriority.High.Value+785,table.unpack(MachineHub.Keys))
 gui.Destroying:Connect(function()ContextActionService:UnbindAction("EggDropMachineHub");gameMenu:destroy();hubGui:Destroy()end)
end
-- A tile: close the hub, then open the machine's screen the way its station does.
-- Back from it reopens the hub (clientUI.machineReturn, the picker's return marker,
-- the quest log's fromHub). Nothing opened (busy, a pending hatch took over): the hub stays.
function clientUI.openMachine(id)
 if not gameMenu:isOpen()or MachineHub.locked(id,board:GetAttribute("OwnedPets")or 0)then return false end
 if id=="things"then return gameMenu:openPage()==true end -- its page is in the hub itself
 local Kit=require(script.DeckKit)
 gameMenu:close("machine");roomView:setMenuOpen(false)
 clientUI.machineReturn=nil
 local opened=false
 if id=="hatch"then clientUI.machineReturn="hatch";opened=visitEggs()==true
 elseif id=="style"then opened=openPicker("Shell",{hub="style"},"workbench")==true
 elseif id=="settings"then opened=openPicker("Settings",{hub="settings"})==true
 elseif id=="companions"then clientUI.machineReturn="companions";opened=clientUI.openHub~=nil and clientUI.openHub({slideFrom=Kit.SlideOffset})==true
 elseif id=="quests"then opened=clientUI.openQuestLog("daily",{fromHub=true})==true
 elseif id=="book"then clientUI.machineReturn="book";opened=clientUI.openBook~=nil and clientUI.openBook()==true end
 if not opened then
  clientUI.machineReturn=nil
  if not(nurseryView:isOpen()or clientUI.isHueOpen())then openMenu({focus=id})end
  return false
 end
 return true
end
-- QA v735 H5: where a notice card's button leads ("quests" | "hatch" | "companions" |
-- "menu"). Only from the free garden with a pet (never mid-round or over another screen);
-- it goes through the hub, so Back from the machine returns there as from a tile.
function clientUI.noticeCanGo(target)
 return type(target)=="string"and target~="show"and(board:GetAttribute("OwnedPets")or 0)>0 and board:GetAttribute("Mode")=="Room"
  and roomView.canRoam()==true and not gameMenu:isOpen()
end
function clientUI.noticeGo(target)
 if not clientUI.noticeCanGo(target)then return false end
 if not openMenu({focus=if target=="menu"then nil else target})then return false end
 clientUI.accepted("confirm")
 if target=="menu"then return true end
 return clientUI.openMachine(target)
end
-- Back from a machine opened at the hub: the hub again, sliding in from the left.
function clientUI.returnToMachineHub(id)
 if clientUI.machineReturn~=id then return false end
 clientUI.machineReturn=nil
 task.defer(function()if openMenu then openMenu({focus=id,slideFrom=-require(script.DeckKit).SlideOffset})end end)
 return true
end
closeMenu = function()
	gameMenu:close("close"); roomView:setMenuOpen(false)
end
-- options: focus (a tile id), slideFrom (px).
openMenu = function(options)
	options=options or {}
	cancelHatchNavigation()
	if roomView.busy or modal.Visible or nurseryView:isOpen() or clientUI.isHueOpen() then return end
	if clientUI.dash and (clientUI.dash:held() or clientUI.dash:panelOpen()) then return end
	if (clientUI.hub and clientUI.hub:isOpen()) or (clientUI.book and clientUI.book:isOpen()) or clientUI.questLog.visible
		or (clientUI.stats and (clientUI.stats.isOpen() or clientUI.stats.isBusy()))
		or (clientUI.names and clientUI.names.isOpen())
		or (clientUI.isWardrobeOpen and clientUI.isWardrobeOpen()) then return end
	clientUI.machineReturn=nil
	clearPlayInputs(); picker:close(); journal:close(); roomView:setMenuOpen(true)
	if GuiService.SelectedObject then GuiService.SelectedObject=nil end
	return gameMenu:open({owned=board:GetAttribute("OwnedPets")or 0,wallet=nurseryState and nurseryState.nectar or 0,state=nurseryState},
		{focus=options.focus,slideFrom=options.slideFrom})
end
roomView.onOpenMenu=function()if openMenu()then clientUI.accepted("confirm")end end
-- The Play Den's notice board: the Pocket menu straight on its Things to do page.
function clientUI.openThings()
	if openMenu()then
		clientUI.accepted("confirm")
		pcall(function()gameMenu:openPage()end)
		return true
	end
	return false
end
-- Stars store access (STARS-STORE-ACCESS-PLAN-2026-11-21.md; Spencer: "clicking the stars icon
-- opens a store to buy stars?"). One route for the header wallet and the "need more Stars"
-- card: close whatever menu is up (never as "back", which would reopen the hub over the store),
-- open Hatch eggs, then its store page. Only in the free garden: never mid-round, over a hatch
-- result or a modal, or while any egg or jar purchase is still saving.
local function starsPurchasePending()
 if nurseryView.pending then return true end
 for _,kind in ipairs({"hue","material","toy","feature"})do local intent=clientUI[kind.."Intent"];if intent and intent.pending then return true end end
 return false
end
function clientUI.anyMenuOpen()
 return isPickerOpen()or journal.shade.Visible or clientUI.isHueOpen()or gameMenu:isOpen()
  or(clientUI.hub~=nil and clientUI.hub:isOpen())or(clientUI.book~=nil and clientUI.book:isOpen())
  or clientUI.questLog~=nil and clientUI.questLog.visible==true
  or(clientUI.stats~=nil and(clientUI.stats.isOpen()or clientUI.stats.isBusy()))or(clientUI.names~=nil and clientUI.names.isOpen())
  or(clientUI.isWardrobeOpen~=nil and clientUI.isWardrobeOpen())
end
-- Closes every menu screen with `reason` (not "back"). True when none is left open.
function clientUI.closeAllMenus(reason)
 reason=reason or "store"
 cancelHatchNavigation();clearPlayInputs()
 if clientUI.isWardrobeOpen and clientUI.isWardrobeOpen()then clientUI.wardrobe:close()end
 if clientUI.names and clientUI.names.isOpen()then clientUI.names.close(reason)end
 if clientUI.stats and(clientUI.stats.isOpen()or clientUI.stats.isBusy())then clientUI.stats.close(reason)end
 if clientUI.hub and clientUI.hub:isOpen()then clientUI.hub:close(reason)end
 if clientUI.book and clientUI.book:isOpen()then clientUI.book:close(reason)end
 if clientUI.questLog and clientUI.questLog.visible then clientUI.questFromHub=nil;clientUI.closeQuestLog()end
 if clientUI.isHueOpen()then clientUI.hueView:close("forced")end
 picker:close();journal:close()
 if gameMenu:isOpen()then gameMenu:close(reason);roomView:setMenuOpen(false)end
 clientUI.machineReturn=nil
 return not clientUI.anyMenuOpen()
end
local starsStoreOpening=false
-- What was open when the store opened, and how to reopen it (StarsRoute).
clientUI.starsRouteDeps={
 hubOpen=function()return gameMenu:isOpen()end,
 canReopen=function()return clientUI.starsStoreRefusal()==nil and not clientUI.anyMenuOpen()and not nurseryView:isOpen()end,
 getMachineReturn=function()return clientUI.machineReturn end,
 setMachineReturn=function(id)clientUI.machineReturn=id end,
 wardrobe={isOpen=function()return clientUI.isWardrobeOpen~=nil and clientUI.isWardrobeOpen()==true end,
  petId=function()return clientUI.wardrobe.petId end,open=function(petId)return clientUI.openWardrobe(petId)end},
 screens={
  names={isOpen=function()return clientUI.names~=nil and clientUI.names.isOpen()end,capture=function()return clientUI.names.current()end,
   open=function(args)return clientUI.openNames(args)end},
  stats={isOpen=function()return clientUI.stats~=nil and clientUI.stats.isOpen()end,capture=function()return clientUI.stats.current()end,
   open=function(args)return clientUI.openStats(args)end},
  -- Only the Companions routes reopen; the Care Cradle and the journal need their own station.
  hue={isOpen=function()return clientUI.hueView~=nil and clientUI.hueView:isOpen()end,
   capture=function()
    local back=clientUI.hueReturn
    if clientUI.hueView.page~="palette"or(back~="hub"and back~="companions")then return nil end
    return{page=if clientUI.hueView.tab=="toys"then "toys"else "palette",petId=clientUI.hueView.petId,back=back}
   end,open=function(args)return clientUI.openHue(args.page,args.petId,args.back)end},
  hub={isOpen=function()return clientUI.hub~=nil and clientUI.hub:isOpen()end,
   capture=function()return if clientUI.hub.assign then nil else{page=clientUI.hub.page}end,open=function(args)return clientUI.openHub(args)end},
  book={isOpen=function()return clientUI.book~=nil and clientUI.book:isOpen()end,
   capture=function()local entry=clientUI.book:entries()[clientUI.book.pageIndex];return{page=entry and entry.id or nil}end,
   open=function(args)return clientUI.openBook(args)end},
  quests={isOpen=function()return clientUI.questLog~=nil and clientUI.questLog.visible==true end,
   capture=function()return{tab=clientUI.questLog.tab or "daily",fromHub=clientUI.questFromHub==true}end,
   open=function(args)return clientUI.openQuestLog(args.tab,{fromHub=args.fromHub})end},
  picker={isOpen=isPickerOpen,
   capture=function()return{mode=picker.active,back=clientUI.pickerReturn,source=if picker.customizationEntry then "workbench"else nil}end,
   open=function(args)return openPicker(args.mode,args.back,args.source)end},
 }}
-- Why the store did not open (nil when it can): read by specs and the live check through the
-- PlayerGui attribute StarsStoreRefused.
function clientUI.starsStoreRefusal()
 if not nurseryState then return "noState"end
 if roomView.busy then return "busy"end
 if board:GetAttribute("Mode")~="Room"then return "notRoom"end
 if modal.Visible then return "modal"end
 if nurseryState.lastHatch then return "hatchResult"end
 if starsPurchasePending()then return "pending"end
 return nil
end
function clientUI.canOpenStarsStore()return clientUI.starsStoreRefusal()==nil end
local function refuseStore(reason)
 local playerGui=player:FindFirstChildOfClass("PlayerGui")
 if playerGui then playerGui:SetAttribute("StarsStoreRefused",reason)end
 return false
end
function clientUI.openStarsStore(from)
 if nurseryView:isStoreOpen()then return true end
 if starsStoreOpening then return refuseStore("opening")end
 local refusal=clientUI.starsStoreRefusal()
 if refusal then return refuseStore(refusal)end
 refuseStore(nil)
 -- Already on Hatch eggs: the store page opens in place (reopening would reset focus).
 if nurseryView:isOpen()then return nurseryView:openStore()==true or refuseStore("hatchView")end
 local fromHub=gameMenu:isOpen()
 -- Where Back from the store goes (Spencer 2026-11-21: not Hatch eggs, unless you were there):
 -- the screen that was open, else the garden. The hub goes through machineReturn.
 -- Captured before anything closes: closing clears the way-back markers.
 local back=require(script.StarsRoute).capture(clientUI.starsRouteDeps)
 starsStoreOpening=true
 local ok=false
 if clientUI.closeAllMenus("store")then
  openNursery()
  -- From the machine hub: Back from the store, then Hatch eggs, lands on the hub again.
  if fromHub and nurseryView:isOpen()then clientUI.machineReturn="hatch"end
  ok=nurseryView:isOpen()and nurseryView:openStore()==true
  if ok then nurseryView.storeReturn=back end
 end
 starsStoreOpening=false
 if not ok then refuseStore("didNotOpen")end
 return ok
end
-- "Play a round" on the card: the free way to earn the Stars.
function clientUI.playRoundForStars()
 -- Code review: same gate as the store (a hatch result that arrived under the card must be seen).
 if clientUI.starsStoreRefusal()then return false end
 if nurseryView:isOpen()then nurseryView:close("earn");return true end
 if not clientUI.closeAllMenus("store")then return false end
 hatchNavigation:play();return true
end
require(script.DeckKit).onWalletTap=function()
 local ok=clientUI.openStarsStore("wallet")
 if ok then clientUI.accepted("confirm")end
 return ok
end
require(script.StarsShort).setRoute(function(choice,request)
 local ok=if choice=="store"then clientUI.openStarsStore(request and request.from)else clientUI.playRoundForStars()
 if ok then clientUI.accepted("confirm")end
end)
picker.onAccepted=clientUI.accepted;journal.onAccepted=clientUI.accepted;gameMenu.onAccepted=clientUI.accepted;nurseryView.onAccepted=clientUI.accepted
-- Levels matter: a locked ball, plate or effect leads to where its stat is trained.
picker.shop.callbacks.train=function(route)picker:close("stats");clientUI.openStats({from="rail",stat=route.stat,petId=route.petId})end

do
	local handoff = overlayGui.DeckHandoff
	local function alignSafeContent()
		local origin = backdrop.AbsolutePosition - overlayGui.AbsolutePosition
		-- QA v760: no margin on a phone, so the sheets hosted here (Hatch eggs, Deck style,
		-- Customize) are the same rectangle as the Pocket menu, Companions and the Wardrobe.
		local margin=if backdrop.AbsoluteSize.Y<280 or require(script.DeckKit).compactRule(backdrop.AbsoluteSize.X,backdrop.AbsoluteSize.Y)then 0 else 8
		safeOverlays.Position = UDim2.fromOffset(origin.X+margin,origin.Y+margin)
		safeOverlays.Size = UDim2.fromOffset(math.max(1,backdrop.AbsoluteSize.X-margin*2),math.max(1,backdrop.AbsoluteSize.Y-margin*2))
	end
	local function updateShade()
		roomView.transition:refresh()
		-- The machine hub dims with its own full-screen shade (Q2 shade stack, QA Q5).
		modalShade.Visible = modal.Visible or picker.shade.Visible or journal.shade.Visible or nurseryView:isOpen() or clientUI.isHueOpen()
		-- QA v2 R3.1: the legacy overlay shade still blocks input and drives the pause for
		-- every sheet, but it dims only for the round modal; Deck style / Settings, the
		-- journal, Hatch eggs and Customize dim with their own Kit shade (one per screen).
		modalShade.BackgroundTransparency = if modal.Visible then 0.40 else 1
  if modalShade.Visible then rendererPresentation.setFieldOwner(false,board:GetAttribute("ResetId"),reduceEffects())end
		if clientUI.syncPause then clientUI.syncPause()else request:FireServer("pause",modalShade.Visible)end
	end
	-- QA v2 R3.8: the stamp card lives on the quest log's daily tab (daily things live
	-- together); it reads the nursery snapshot and stamps with the same `daily` action
	-- Hatch eggs used. HowItWorks is the ? cards' overlay (R1's "show tips again" can
	-- reach any machine's cards through clientUI.howItWorks.open(id) / .list()).
	clientUI.questCallbacks.stampState=function()return nurseryState end
	clientUI.questCallbacks.stamp=function(day)nurseryRequest:FireServer("daily",day,nurseryState and nurseryState.revision or 0)end
	clientUI.howItWorks=require(script.HowItWorks)
	-- "Show tips again" (R1's coach replay, defined further down) from the cards and Settings.
	clientUI.howItWorks.replayTips=function()if clientUI.replayCoachTips then clientUI.replayCoachTips()end end
	-- QA v735 H5: a notice card's button ("Open Quests", "Open Hatch eggs", ...).
	clientUI.howItWorks.canGo=function(target)return clientUI.noticeCanGo(target)end
	clientUI.howItWorks.go=function(target)return clientUI.noticeGo(target)end
	picker.onTips=function()
		if not clientUI.replayCoachTips then return false end
		picker:close("tips");task.defer(clientUI.replayCoachTips);return true
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
-- QA v735 D2: the handheld has settled after its rise; lay it out at rest once.
roomView.transition.onSettled=function() if layout then layout();updateHud() end end
for _,name in ipairs({"RoundOver","ReducedEffects","Mode"}) do
	board:GetAttributeChangedSignal(name):Connect(function() roomView.transition:refresh() end)
end
GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function() roomView.transition:refresh() end)
-- The resting pet answers the round's end: a double hop for a win, startled then
-- sleepy for a loss. Local presentation; the Welcome hatch round is left alone.
board:GetAttributeChangedSignal("RoundOver"):Connect(function()
 if board:GetAttribute("RoundOver")~=true or board:GetAttribute("Mode")~="Board"or clientUI.attr("FieldPhase")=="Welcome"then return end
 local serial=board:GetAttribute("ResetId")
 task.defer(function()
  if board:GetAttribute("ResetId")~=serial or board:GetAttribute("RoundOver")~=true then return end
  roomView:cheerPet(if board:GetAttribute("FieldSuccess")==true then "win"else "loss")
 end)
end)
GuiService.MenuOpened:Connect(function() roomView.transition:refresh() end)

local function updateClub()
	local sound = board:GetAttribute("SoundLevel") or Settings.DefaultSound
	picker:setGreetings(board:GetAttribute("GreetingsOff")~=true)
	picker:setMenuColours(board:GetAttribute("MenuColours"))
	-- The Vibration row: shown where the device can buzz and the ASMR switch is on (a pad may connect later).
	picker:setVibration(clientUI.haptics.available(), clientUI.haptics.isEnabled())
	picker:updateClub(board:GetAttribute("OwnedPets") or 0, board:GetAttribute("TrialMask") or 0,
		clientUI.attr("PeakChain") or 0, clientUI.attr("Score") or 0, sound,
		board:GetAttribute("ReducedEffects") == true, GuiService.ReducedMotionEnabled, board:GetAttribute("InventoryMask"),audio:isMusicEnabled(),nurseryState and nurseryState.totalWins,nurseryState and nurseryState.masteryRanks)
	if nurseryState then picker:setShopState(nurseryState.nectar,nurseryState.faceplates,nurseryState.ballThemes,nurseryState.revision)end
end

openPicker = function(mode,back,source)
	mode=mode or "Shell"
	-- Pocket Trials have no page any more (QA Q5): Settings, or Deck style at its workbench.
	if mode~="Settings"and source~="workbench"then return false end
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
  changed=function(state)
   -- QA Q2.4: optimistic. The deck wears a choice as soon as it is made; a refusal
   -- falls back to the confirmed look (AppearanceIntent.shown) with one toast.
   picker:setAppearance(state)
   local shown=clientUI.AppearanceIntent.shown
   paintDeck(shown(state,"theme")or state.confirmedTheme,shown(state,"sticker")or state.confirmedSticker,shown(state,"background")or state.confirmedBackground)
   clientUI.appearanceSeen=clientUI.appearanceSeen or {}
   for _,slot in ipairs({"theme","background"})do
    local s=state.slots and state.slots[slot];local status=s and s.status
    if status=="Rejected"and clientUI.appearanceSeen[slot]~="Rejected"and s.reason~="Superseded"then
     clientUI.styleToaster=clientUI.styleToaster or require(script.DeckKit).toaster(picker.shade)
     clientUI.styleToaster.show(require(ReplicatedStorage.Shared.UICopy).get("shop.rolledBack"))
    end
    clientUI.appearanceSeen[slot]=status
   end
  end})
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
	return clientUI.attr("NextTier") or 1
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
-- Levels matter S3: the chosen merge pop, drop trail and start flourish (FieldEffects owns them; classic costs nothing).
do
 local ok,problem=pcall(function()
  rendererPresentation.fx:attachJuice({board=board,views=eggViews,project=project,launchY=Config.SpawnY,
   ready=function()local boot=clientUI.deck and clientUI.deck.boot;return not(boot and boot.host and boot.host.Visible)end})
 end)
 if not ok then warn("[Levels] deck juice not mounted: "..tostring(problem))end
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
	nextReadout.Text = clientUI.BallThemes.word(tier) .. " · " .. clientUI.BallThemes.word(clientUI.attr("PreviewTier1") or 1)
		.. " · " .. clientUI.BallThemes.word(clientUI.attr("PreviewTier2") or 1)
	nextReadout.TextColor3 = clientUI.JellyPalette.byTier[tier].body
	if queuePieces then
		for index,piece in ipairs(queuePieces)do local t=if index==1 then tier else (clientUI.attr("PreviewTier1") or 1);Art.jellyPreview(piece,t,piece.Mark);piece.Mark.Text=clientUI.BallThemes.word(t)
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

local function shouldCoachField()
	return nurseryState and nurseryState.status == "Ready" and (board:GetAttribute("OwnedPets") or 0) > 0
		and clientUI.attr("FieldPhase") == "Playing" and canAim() and not isPickerOpen() and not roomView.busy
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
  -- v933 QA (narrow phone rows): a word label, same wording as the wide rows ("or bigger" is an up
  -- arrow; the zone is a word, not the mini tray that read as a toggle).
  local tier=goal.tier or goal.minTier or 1
  local tiny=if goal.kind=="count"then "Merges"elseif goal.kind=="chain"then "Chain"
   else clientUI.BallThemes.circle(tier,13)..(if goal.minTier then "↑"else "")..(({left=" LEFT",right=" RIGHT",center=" MID"})[zone]or "")
  goals[index]={text=full,short=candidates[1]or full,spoken=(clientUI.FieldQuestText.goal(goal)),done=done,progress=if current then view.progress or 0 else 0,target=goal.target or 1,
   tiny=tiny,icon={kind=goal.kind or "merge",tier=tier,plus=goal.minTier~=nil,zone=zone}}
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
 local wanted=clientUI.ItemCarousel.pauseWanted({modal=modalShade.Visible,questLog=clientUI.questLog.visible and board:GetAttribute("Mode")=="Board",
  pocketMenu=clientUI.pocketMenu.visible,carousel=clientUI.items~=nil and clientUI.items.isOpen,roundOver=board:GetAttribute("RoundOver")==true,
  book=clientUI.book~=nil and clientUI.book:isOpen()and board:GetAttribute("Mode")=="Board"})
 request:FireServer("pause",wanted)
 -- B2: a lockstep round pauses as a tick-stamped input on the client's own host.
 if clientUI.clientSim then clientUI.clientSim.pause(wanted)end
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
function clientUI.resultsHeatName()
 local choice=clientUI.resultsHeat
 local confirmed=board:GetAttribute("NextHeat")or Config.DefaultHeat
 if choice and(choice.sequence~=board:GetAttribute("RunSequence")or os.clock()-choice.at>2 or choice.key==confirmed)then clientUI.resultsHeat=nil;choice=nil end
 local key=if choice then choice.key else confirmed
 return(Config.Heat[key]or Config.Heat[Config.DefaultHeat]).name
end
function clientUI.cycleResultsHeat(delta,wrap)
 if not recap.visible or not recap.data or recap.data.pending then return false end
 local choice=clientUI.resultsHeat;local key=if choice and choice.sequence==board:GetAttribute("RunSequence")and os.clock()-choice.at<2 then choice.key else board:GetAttribute("NextHeat")or Config.DefaultHeat
 -- QA v751 P3: a tap cycles Easy, Medium, Hard, Easy (wrap); the d-pad still stops at the ends.
 local nextKey=require(script.DeckResults).nextDifficulty(Config.HeatOrder,key,delta,wrap)
 if nextKey==key then return false end
 clientUI.resultsHeat={key=nextKey,sequence=board:GetAttribute("RunSequence"),at=os.clock()}
 request:FireServer("heat",nextKey);clientUI.accepted("tab");if updateHud then task.defer(updateHud)end
 return true
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
  -- Growth cuts (StarterBonus): the Welcome bonus row first, in gold (flat: never in the 2x or Supporter rows).
  local starterRow=require(script.ResultsNudge).starterRow(reward)
  if starterRow then table.insert(rows,starterRow)end
  -- Onboarding v1: a missed round with a goal met pays a flat finish pay ("Goal met").
  local missPay=if type(reward.missPay)=="number"then reward.missPay else 0
  if missPay>0 then table.insert(rows,{name=require(ReplicatedStorage.Shared.UICopy).get(if missPay==1 then "coach.effortPay"else "coach.missPay"),amount=missPay})
  else
  table.insert(rows,{name="Round win",amount=win})
  if roundStars>win then table.insert(rows,{name="Tidy stack",amount=roundStars-win,signed=true})end
  end
  local doubled=(reward.total or roundStars)-roundStars-(reward.bonus or 0)-(if starterRow then starterRow.amount else 0)
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
 -- Growth cuts (GROWTH-CUTS-LOOK sections 1 and 3), each behind its own switch; off leaves these nil.
 local growth={}
 do
  local Flags=require(ReplicatedStorage.Shared.FeatureFlags)
  -- On the beta the v3 Coming up strip wins while the Sleepy Nest is on (TomorrowChips.live): no live model then.
  if Flags.TomorrowStrip==true and nurseryState and require(script.TomorrowChips).live()then
   growth.tomorrow={phone=require(script.TomorrowChips).model(nurseryState,{phone=true}),wide=require(script.TomorrowChips).model(nurseryState,{phone=false})}
  end
  if Flags.StarterBonus==true and nurseryState then
   local Nudge=require(script.ResultsNudge)
   growth.egg=Nudge.egg(nurseryState)
   growth.line=Nudge.line(growth.egg,balance)
   growth.hatchPrimary=not pending and Nudge.hatchPrimary(growth.line,reward)
  end
 end
 return{outcome=if success==true then "clear"elseif reason=="Overflow"then "overflow"else "missed",
  title=if objective and not objective.empty and objective.title then objective.title else "Round",difficulty=heat.name,nextDifficulty=clientUI.resultsHeatName(),multiplierLine=heat.name.." "..heatLabel,
  pending=pending,earned=reward and reward.total or 0,total=reward and reward.total or 0,rows=rows,balance=balance,
  -- QA Q5 results strip: Stars from rounds saved today (server snapshot; includes this
  -- round once its receipt is in the same snapshot).
  todayEarned=if nurseryState and type(nurseryState.todayEarned)=="number"then nurseryState.todayEarned else nil,
  loss=not pending and(reward==nil or(reward.total or 0)==0),goals=clientUI.deckGoals(objective,stage or 0),
  score=score,best=best,chain=peakChain,newBest=board:GetAttribute("NewBest")==true,
  strip=if #strip>0 then table.concat(strip,"   ")else(if field then "No quest finished this round"else "Win a round to earn Stars"),
  stripRight=if balance>=egg.cost then "You can hatch an egg"else clientUI.weeklyLine(),
  canLeave=owned>0,level=heat.index,questCount=clientUI.questCount(),canHatch=owned>0,
  questDone=clientUI.finishedQuest(reward),
  tidy=success==true and reward~=nil and(reward.base or 0)>=Payout.TidyWin,eggName=egg.name,eggCost=egg.cost,
  -- v2 S3: the round's stat gains (results Stats strip), levels from the pet's XP now.
  stats=require(script.StatToasts).resultsParts(reward and reward.stats,(function()
   local ps=nurseryState and nurseryState.petStats;local e=type(ps)=="table"and type(ps.pets)=="table"and ps.pets[board:GetAttribute("CompanionId")or ""]
   return type(e)=="table"and e.xp or nil end)()),
  quest=quest,nudge=nudge,petName=(Pets.byId[board:GetAttribute("CompanionId")or ""]or Pets.active[1]or Pets[1]).name,
  -- Growth cuts: the TOMORROW strip (live snapshot only; nil hides it) and the next-egg nudge under the Star.
  tomorrow=growth.tomorrow,nextLine=growth.line,nextEgg=growth.egg,hatchPrimary=growth.hatchPrimary,
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
 clientUI.fieldView=clientUI.FieldQuestText.read(clientUI.boardView,clientUI.fieldCache)
 if rendererPresentation.roundEnd then rendererPresentation.roundEnd:observe()end
 local final=rendererPresentation.roundEnd and rendererPresentation.roundEnd.frozen
	local drops = clientUI.attr("Drops") or 0
	local merges = clientUI.attr("Merges") or 0
	local chain = clientUI.attr("Chain") or 0
	local peakChain = clientUI.attr("PeakChain") or 0
	local maxClears = clientUI.attr("MaxClears") or 0
	local score = clientUI.attr("Score") or 0
	-- S2b: show what the drawn board has earned; merges still ahead of the clock wait.
	if clientUI.boardNet and clientUI.boardNet.active()and not clientUI.mirrorOwns(board:GetAttribute("ResetId"))then
		local held=clientUI.boardNet.pending("score")
		if held>0 then score=math.max(0,score-held);chain=clientUI.netChain or chain end
	end
	local best = board:GetAttribute("BestScore") or 0
	local charge = board:GetAttribute("HatchCharge") or 0
	local owned = board:GetAttribute("OwnedPets") or 0
	local mask = board:GetAttribute("TrialMask") or 0
	-- Pocket Trials are retired (QA Q5): the server still keeps TrialMask, but the HUD
	-- no longer announces trials or points at a trials page. (Newly earned bits still
	-- feed the legacy rare-pet queue below.)
	local newlyEarned = bit32.band(mask, bit32.bnot(lastTrialMask))
	lastTrialMask = mask
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
	-- Perf (v775): the old cell meter is always hidden (the dispenser shows the count).
	-- Keep its colours current, but never flip 24 cells visible and hidden again or
	-- re-lay them out (an AbsoluteSize read mid-refresh); the meter's own
	-- AbsoluteSize signal runs layoutDropMeter.
	for index, cell in ipairs(segments) do
		local color = if index <= remaining then Art.Leaf else Art.Line
		if cell.BackgroundColor3 ~= color then cell.BackgroundColor3 = color end
		if cell.Visible then cell.Visible = false end
	end
	dispenser:setTheme(Themes.ById[board:GetAttribute("DeckThemeId")]or Themes.ById[Themes.Default])
	dispenser:update(board:GetAttribute("ResetId"),if clientUI.dropIntent then clientUI.dropIntent:shownDrops(drops)else drops,budget,owned > 0 and board:GetAttribute("Mode")=="Board",rendererPresentation.canPresent(board:GetAttribute("ResetId")))
	meterText.Visible=owned==0
	local comboTarget=board:GetAttribute("WelcomeComboTarget")
	meterText.Text = if owned > 0 then string.format("%d/%d", remaining, budget)
		elseif type(comboTarget)=="number"and comboTarget>0 then string.format("%s %d/%d", Pets.byId.pip.name, board:GetAttribute("WelcomeCombos")or 0, comboTarget)
		else string.format("%s %d/%d", Pets.byId.pip.name, charge, nextPet and nextPet.charge or 6)
	eggGoal.Visible = not backdrop:GetAttribute("CompactLandscape") and not backdrop:GetAttribute("SideGoalLayout") and owned > 0 and shell.AbsoluteSize.Y >= 260
	-- Perf (v775): eggGoalText belongs to the render loop, which rewrote this before
	-- every paint; writing a different string here only re-fitted the label twice.
	rareGoal.Visible = false
	-- Perf (v775): one write of the final text (the field instruction wins), not two.
	if nurseryActive and owned>0 then
		rareGoal.Text=clientUI.FieldQuestText.describe(clientUI.fieldView,clientUI.attr("FieldPhase")).instruction
	elseif nextRare then
		local goal = nextRare.trial
		local rareProgress = math.min(if goal == Trials.HighRoller then score
			elseif goal == Trials.Fivefold then peakChain else maxClears, goal.target)
		rareGoal.Text = string.format("%s%s\n%s %d/%d", if trackedRare then "★ " else "",
			nextRare.name, goal.readout, rareProgress, goal.target)
	else
		rareGoal.Text = string.format("Beat your best\n%d pts", best)
	end
 local mode=board:GetAttribute("Mode")
 clientUI.fieldCopy=clientUI.FieldQuestText.describe(clientUI.fieldView,clientUI.attr("FieldPhase"))
 for _,item in ipairs(fieldZones)do
  item.node.Visible=nurseryActive and owned>0
  item.node.BackgroundTransparency=if clientUI.fieldCopy.zone==(if item.side==-1 then "left"else "right")then .15 else .45
  -- QA v735 D4: the area bands follow the lines; the current goal's area is lit.
  item.band.Visible=item.node.Visible
  item.band.BackgroundTransparency=if clientUI.fieldCopy.zone==(if item.side==-1 then "left"else "right")then .84 else .94
  item.tag.TextTransparency=if clientUI.fieldCopy.zone==(if item.side==-1 then "left"else "right")then 0 else .45
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
	-- S2b: the recap waits for the clock to reach the round's last tick (its last merge).
	if over and clientUI.boardNet and clientUI.boardNet.active()and not clientUI.mirrorOwns(board:GetAttribute("ResetId"))then
		local endTick=board:GetAttribute("RoundOverTick")
		local shown=clientUI.boardNet.renderTick()
		if type(endTick)=="number"and shown and shown<endTick then
			over=false
			if clientUI.netRoundWait~=endTick then
				clientUI.netRoundWait=endTick
				clientUI.boardNet.schedule(endTick,function()clientUI.netRoundWait=nil;clientUI.netHudKick()end)
			end
		end
	end
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
	-- The First Hatch: combos stand in for charge (same three stages)
	local guideCharge=charge
	local guideTarget=board:GetAttribute("WelcomeComboTarget")
	if type(guideTarget)=="number"and guideTarget>0 then guideCharge=(board:GetAttribute("WelcomeCombos")or 0)/guideTarget*Pets.byId.pip.charge end
	local lesson = firstHatchGuide:step(drops, merges, guideCharge, owned, UserInputService:GetLastInputType(),
		clientUI.BallThemes.word(nextTier()), canPlay(), backdrop:GetAttribute("CompactInstruction")==true)
	-- The First Hatch (Fable): the combo round keeps one goal in words, "Hatch a friend"; the egg's pips count combos.
	if type(guideTarget)=="number"and guideTarget>0 and lesson then
		local Copy=require(ReplicatedStorage.Shared.UICopy)
		if lesson==Copy.get("onboarding.welcome.match")or lesson==Copy.get("onboarding.welcome.more")then lesson=Copy.get("onboarding.welcome.friend")end
	end
	local fieldCoaching = false
	firstHatchGuide:fieldStep(0, 1, false)
	local fieldActive = nurseryActive and owned > 0
	questHUD:update(clientUI.attr("FieldStage") or 0,clientUI.attr("FieldPhase"),fieldActive,backdrop:GetAttribute("CompactInstruction")==true,clientUI.fieldView or false)
	status.ClipsDescendants = true
	status.BackgroundTransparency = if lesson or fieldCoaching or fieldActive then 0.08 else 1
	status.TextColor3 = if lesson or fieldCoaching then Art.Silver else title.TextColor3
	status.Text = if fieldActive then "" elseif fieldCoaching then "" elseif lesson then lesson
		else (if status.AbsoluteSize.Y<60 then "Quest +6 Stars" else "Win quest +6 Stars\nLow pile +2 bonus")
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
	-- Growth cuts (TomorrowStrip): the garden's Tomorrow line waits for the first free moment after a results screen.
	if resultsOpened and clientUI.coach then clientUI.coach.sawResults=true end
	modalTitle.Text = "You hatched " .. (hatchName or "") .. "!"
	readout.Text = if owned > 0 then tostring(nurseryState and nurseryState.nectar or 0) else tostring(score)
	scoreCaption.Text = if owned > 0 then "Stars" else "SCORE"
	scoreCaption.Visible=owned==0;walletDrop.Visible=owned>0
	layoutWallet(instrumentLayout)
	bestReadout.Text = if owned > 0 then "Stars · eggs from 8" else "BEST " .. best
	-- QA Q5: the machine hub's status lines and locks follow the snapshot and the pet count.
	if gameMenu then gameMenu:setContext({owned=owned,state=nurseryState,wallet=nurseryState and nurseryState.nectar or 0}) end
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
	dropCaption.Text = if clientUI.attr("FieldPhase") == "Settling" then "SETTLE"
		elseif nurseryState and nurseryState.status ~= "Ready" then
			(if nurseryState.status=="Busy" or nurseryState.status=="Retrying" or nurseryState.status=="Pending" then "SAVING"
				elseif nurseryState.status=="SessionLost" then "REJOIN" else "SAVE WAIT")
		elseif clientUI.attr("FieldReady") == false then "FALLING" else "DROP"
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
		welcome=owned==0 and clientUI.attr("FieldPhase")=="Welcome",
		message=if not fieldActive then status.Text else nil,statusLabel=if blocked then status.Text else nil,daily=clientUI.dailyRows(),
		next={nextTier(),clientUI.attr("PreviewTier1")or 1,clientUI.attr("PreviewTier2")or 1},
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
 clientUI.fieldView=clientUI.FieldQuestText.read(clientUI.boardView,clientUI.fieldCache)
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
  -- QA v735 D4: the band runs from the wall (0.4 units in, like the fill line) to the
  -- threshold. Its name reads across when it fits, else down the wall.
  local wallEdge=.4/(Config.Width+.8)
  local span=math.max(0,.5-zoneBound/(Config.Width+.8)-wallEdge)
  item.band.Position=UDim2.fromScale(if item.side==-1 then wallEdge else 1-wallEdge-span,.025)
  item.band.Size=UDim2.fromScale(span,.95)
  -- Both names turn together: the wider one decides.
  local tagWidth=math.max(Art.textWidth(fieldZones[1].tag),Art.textWidth(fieldZones[2].tag))
  if span*viewport.Size.X.Offset>=tagWidth then
   item.tag.Rotation=0;item.tag.AnchorPoint=Vector2.zero
   item.tag.Position=UDim2.fromOffset(0,4);item.tag.Size=UDim2.new(1,0,0,16)
  else
   item.tag.Rotation=if item.side==-1 then -90 else 90;item.tag.AnchorPoint=Vector2.new(.5,.5)
   item.tag.Position=UDim2.new(.5,0,0,6+tagWidth/2);item.tag.Size=UDim2.fromOffset(tagWidth,16)
  end
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
		clientUI.deckView=clientUI.deck:resultsView()
		place(viewport,g.board);overlay.Position,overlay.Size=viewport.Position,viewport.Size
		place(rail,g.board)
		local case=clientUI.deck:caseBounds()
		Art.setBackdropCase(backing,{x=case.x+backdrop.AbsolutePosition.X-backing.AbsolutePosition.X,y=case.y+backdrop.AbsolutePosition.Y-backing.AbsolutePosition.Y,w=case.w,h=case.h})
	else
		clientUI.deckCompact=true;clientUI.deckView=true
		clientUI.deck:placeResults(l.shell)
	end
	clientUI.deck.back.root.Visible=clientUI.deck.backVisible~=false and backdrop.Visible
	clientUI.syncLcdMask()
	if clientUI.items then clientUI.items:place(viewport.Position,viewport.Size,clientUI.deck.geometry~=nil and clientUI.deck.geometry.phone==true and wide)end
	if clientUI.boardHints then clientUI.boardHints:place(viewport.Position,viewport.Size)end
	if clientUI.coach then clientUI.coach:place(viewport.Position,viewport.Size)end
	if recap.visible and recap.key~=recap.viewKey(clientUI.deckView)then task.defer(updateHud)end
	local distance=(Config.Height+.8)/(2*math.tan(math.rad(trayCamera.FieldOfView/2)))
	trayCamera.CFrame=CFrame.lookAt(Vector3.new(0,Config.Height/2,distance),Vector3.new(0,Config.Height/2,0))
	if refreshSaveNotice then refreshSaveNotice()end
	if rendererPresentation.jolt then rendererPresentation.jolt:rebase()end
end

local function aimFromScreen(x)
 if clientUI.welcomeInput then clientUI.welcomeInput()end
 -- Hardware/hit targets recoil visibly; normalized launch aim uses the logical
 -- unjolted tray so motion under a stationary finger cannot steer the shot.
 aim=rendererPresentation.jolt:pointerAim(x,viewport.AbsolutePosition.X,viewport.AbsoluteSize.X)
 drawAim()
end

local function dropEgg()
 -- S5: with the ghost gate, a stale FieldReady=false right after our own drop is that
 -- drop's contact gate a round trip late; the ghost's touch-down (or the gate time) lets
 -- the next tap go. Budget, phase, round end and every other canPlay rule still hold.
 local intent=clientUI.dropIntent
 local ahead=intent~=nil and intent.ghostGate==true and not canPlay()and canAim()and not isPickerOpen()and not roomView.busy
  and not GuiService.MenuIsOpen and clientUI.attr("FieldReady")==false and clientUI.attr("FieldPhase")~="Settling"
  and board:GetAttribute("RoundOver")~=true and intent:shownDrops(clientUI.attr("Drops")or 0)<(board:GetAttribute("FieldBudget")or 24)
  and intent:readyAhead(os.clock())
	if (canPlay() or ahead) and not drag then
  if clientUI.welcomeInput then clientUI.welcomeInput()end
  if clientUI.clientSim then
   -- B3: the mirror plays the drop (sound, jolt) the frame it draws the ball; without one, here.
   local taken=clientUI.clientSim.drop(aim)
   if taken~=nil then if taken and not clientUI.mirror then audio:play("drop",1,.48)end;return end
  end
  -- Deck network S4: with DeckNetDrop the tap answers at once (drop sound, dispenser kick)
  -- under the client's own throttle and not-ready latch; the server's ack settles it.
  local intent=clientUI.dropIntent
  if not intent then request:FireServer("drop", aim);return end
  local now=os.clock()
  if not intent:allow(now)then return end
  local drops,budget=(clientUI.attr("Drops")or 0)+1,board:GetAttribute("FieldBudget")or 24
  local token=intent:send(now,drops)
  request:FireServer("drop", aim, token)
  audio:play("drop",1,.48)
  -- S5: the ball itself, this frame.
  if clientUI.ghosts then
   -- v890 QA: taps inside one round trip read stale NextTier / NextPowerUp / ItemArmed;
   -- an earlier drop still in flight moves this one down the queue (and took the item).
   local pending=clientUI.ghosts:pending()
   local tier=if pending==0 then nextTier()elseif pending==1 then clientUI.attr("PreviewTier1")or 1 else clientUI.attr("PreviewTier2")or 1
   local armed=if pending==0 then clientUI.attr("ItemArmed")else nil
   clientUI.ghosts:spawn(token,aim,tier,now,{star=pending==0 and clientUI.attr("NextPowerUp")==true,mark=if armed and armed~=""then armed else nil})
  end
  dispenser:update(board:GetAttribute("ResetId"),drops,budget,(board:GetAttribute("OwnedPets")or 0)>0 and board:GetAttribute("Mode")=="Board",rendererPresentation.canPresent(board:GetAttribute("ResetId")))
	end
end
-- Studio only (deck network harness): PlayerGui attribute DeckNetTestTap (a counter) taps
-- the real dropEgg at DeckNetTestAim; DeckNetTapSent counts the taps that sent a drop and
-- DeckNetTapAt / DeckNetBallShownAt time the tap and the first ball view after it.
if RunService:IsStudio()then
 local playerGui=player:WaitForChild("PlayerGui")
 playerGui:GetAttributeChangedSignal("DeckNetTestTap"):Connect(function()
  local wanted=playerGui:GetAttribute("DeckNetTestAim")
  if type(wanted)=="number"then aim=math.clamp(wanted,0,1)end
  local before=clientUI.dropIntent and clientUI.dropIntent.stats.sent
  local simBefore=clientUI.clientSim and clientUI.clientSim.sentCount and clientUI.clientSim.sentCount()
  local tapAt=os.clock()
  clientUI.netTapPending=true -- a ghost is drawn inside dropEgg itself
  dropEgg()
  if(clientUI.dropIntent and clientUI.dropIntent.stats.sent~=before)or(simBefore~=nil and clientUI.clientSim.sentCount()~=simBefore)then
   playerGui:SetAttribute("DeckNetTapAt",tapAt)
   playerGui:SetAttribute("DeckNetTapSent",(playerGui:GetAttribute("DeckNetTapSent")or 0)+1)
  elseif clientUI.netTapPending then clientUI.netTapPending=false end
 end)
 playerGui:GetAttributeChangedSignal("DeckNetQuery"):Connect(function()
  playerGui:SetAttribute("DeckNetReport",HttpService:JSONEncode({ghost=clientUI.ghosts and clientUI.ghosts.stats or false,
   intent=clientUI.dropIntent and clientUI.dropIntent.stats or false}))
 end)
 clientUI.netTapShown=function()
  if not clientUI.netTapPending then return end
  clientUI.netTapPending=false;playerGui:SetAttribute("DeckNetBallShownAt",os.clock())
 end
end
do
 -- S4 wiring: acks, FieldReady and run changes feed the drop intent (flag DeckNetDrop).
 if require(ReplicatedStorage.Shared.FeatureFlags).DeckNetDrop==true then
  clientUI.dropIntent=require(script.DropIntent).new()
  -- Never block init on the remote: without it the latch timeout keeps taps working.
  task.spawn(function()
   local ackRemote=remotes:WaitForChild("BoardDropAck",30)
   if not ackRemote then warn("DeckNet: BoardDropAck missing; drops fall back to the latch timeout");return end
   ackRemote.OnClientEvent:Connect(function(token,ok,eggId,tick)
    if clientUI.ghosts then clientUI.ghosts:ack(token,ok,eggId,tick)end
    local result=clientUI.dropIntent:ack(token,ok,clientUI.attr("FieldReady"))
    if result=="refused"then
     audio:play("aim",.6,.3) -- the soft "no" (the item belt's full note)
     if clientUI.netHudKick then clientUI.netHudKick()else task.defer(updateHud)end -- dispenser back to the real count
    end
   end)
  end)
  board:GetAttributeChangedSignal("FieldReady"):Connect(function()clientUI.dropIntent:fieldReady(clientUI.attr("FieldReady"))end)
  for _,name in ipairs({"ResetId","Mode","RoundOver"})do
   board:GetAttributeChangedSignal(name):Connect(function()clientUI.dropIntent:clear();if clientUI.ghosts then clientUI.ghosts:clear()end end)
  end
 end
end

local function moveAim(delta)
 if clientUI.welcomeInput then clientUI.welcomeInput()end
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
		if clientUI.stats and(clientUI.stats.isOpen()or clientUI.stats.isBusy())then return{blocked=true}end -- StatsHost owns its focus
		if clientUI.names and clientUI.names.isOpen()then return{blocked=true}end -- NameScreen owns its focus
		if clientUI.bugReport and clientUI.bugReport:isOpen()then return{blocked=true}end -- the report sheet owns its focus
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
		if key == Enum.KeyCode.Left or key == Enum.KeyCode.A or key == Enum.KeyCode.DPadLeft then recap:move2D(-1,0);clientUI.deck:flash("Left")
		elseif key == Enum.KeyCode.Right or key == Enum.KeyCode.D or key == Enum.KeyCode.DPadRight then recap:move2D(1,0);clientUI.deck:flash("Right")
		elseif key == Enum.KeyCode.ButtonB or key == Enum.KeyCode.Backspace then clientUI.deck:flash("B");recap:back()
		elseif key == Enum.KeyCode.Up or key == Enum.KeyCode.DPadUp then recap:move2D(0,-1);clientUI.deck:flash("Up")
  elseif key == Enum.KeyCode.Down or key == Enum.KeyCode.DPadDown then recap:move2D(0,1);clientUI.deck:flash("Down")
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
picker.onBallEquipped=function(id)clientUI.ballThemeOverride={id=id,at=os.clock()};task.defer(updateHud)end
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
	-- v2 Bunny adoption answers (CompanionsHub Pets page).
	if type(message)=="table"and message.kind=="adopt"then
		local line=clientUI.hub and clientUI.hub:adoptResult(message)
		if line and clientUI.hub:isOpen()then
			clientUI.adoptToaster=clientUI.adoptToaster or require(script.DeckKit).toaster(clientUI.hub.shade)
			clientUI.adoptToaster.show(line)
		end
		return
	end
	picker.shop:result(message)
end)
gui.Destroying:Connect(function()faceplateResultConnection:Disconnect();ContextActionService:UnbindAction("EggDropFaceplateShop")end)
-- Replay keeps the difficulty (no picker); Up on Replay picks again.
recap:on("replay",function()clientUI.keepHeatAfter=board:GetAttribute("RunSequence");requestRetry()end)
recap:on("leave",function()clientUI.leaveDeck()end)
-- Results Hatch button (celebrations 2.6): the same garden route as Menu > Eggs.
recap:on("hatch",function()
	if recap.data and recap.data.pending then return end
	-- Growth cuts (StarterBonus): Hatch eggs opens with the nudge's egg picked (one shot, on the next open).
	local egg=recap.data and recap.data.nextEgg
	clientUI.eggPick=if type(egg)=="table"then{id=egg.id,at=os.clock()}else nil
	if visitEggs()then recap:hide();clientUI.accepted("confirm")else clientUI.eggPick=nil end
end)
-- Growth cuts (TomorrowStrip): a "today" chip (today's stamp, a quest to claim) opens Quests over the results.
recap:on("quests",function()
	if recap.data and recap.data.pending then return end
	if clientUI.openQuestLog("daily")then clientUI.accepted("confirm")end
end)
-- Compact results: change difficulty (the touch route for "Up on Replay") and the quest shortcut.
recap:on("picker",function()
	if recap.data and recap.data.pending then return end
	if recap.inPlace then clientUI.cycleResultsHeat(1,true);return end
 clientUI.keepHeatAfter=nil;clientUI.heatStarted=false;requestRetry()
end)
recap:on("heatShift",function(delta)clientUI.cycleResultsHeat(delta)end)
-- The results quest cell is progress only (QA Q5): no route to the quest log here.
-- Beta 14 F1 (Spencer: tapping a "Coming up" chip closes the Pocket Deck and opens what it points at): egg -> the paw
-- trail to the nest, stamp -> the quest log on its stamp card, quests -> the quest log. From the deck it leaves first and
-- runs the garden step once the room is back (clientUI.afterGarden, 8 s at most); a latch keeps it to one route at a
-- time; nothing while a save is pending. Only where TomorrowStrip.tappable() gives the strip its onChip.
do
 local function gardenStep(id)
  if id=="nest"then return function()return clientUI.things~=nil and clientUI.things.show("nest")==true end end
  if id=="stamp"then return function()return clientUI.openQuestLog("daily",{focus="stamp"})==true end end
  if id=="quests"then return function()return clientUI.openQuestLog("daily")==true end end
  return nil
 end
 clientUI.stripStep=gardenStep -- the Dash results card routes through afterGarden with it (DashClient's onChip)
 local function roomFree()
  return board:GetAttribute("Mode")=="Room"and roomView.mode=="Room"and roomView.target=="Room"and not roomView.busy
 end
 -- fn once the garden is back and free, within `timeout` seconds; a newer call replaces an older one.
 function clientUI.afterGarden(fn,timeout)
  local token={};clientUI.gardenIntent=token
  local deadline=os.clock()+(timeout or 8)
  local link
  link=RunService.Heartbeat:Connect(function()
   if clientUI.gardenIntent~=token then link:Disconnect();return end
   if os.clock()>deadline then link:Disconnect();clientUI.gardenIntent=nil;clientUI.stripRouting=nil;return end
   if not roomFree()then return end
   link:Disconnect();clientUI.gardenIntent=nil;clientUI.stripRouting=nil
   local ok,problem=pcall(fn)
   if not ok then warn("[Strip] route: "..tostring(problem))end
  end)
 end
 function clientUI.stripRoute(id)
  local step=gardenStep(id)
  if not step or clientUI.stripRouting then return false end
  if recap.data and recap.data.pending then return false end
  if roomFree()and not recap.visible then return step()end -- already in the garden (the Dash results card)
  clientUI.stripRouting=true
  if not clientUI.leaveDeck()then clientUI.stripRouting=nil;return false end
  clientUI.afterGarden(step,8)
  return true
 end
 recap:on("chip",function(id)return clientUI.stripRoute(id)end)
end
-- ── Round items (BUILD-PLAN 2026-11-13, R2) ─────────────────────────────────
-- B (keyboard B, gamepad B or X, the deck's B, the phone item button) opens the
-- carousel in a live round; it freezes the round through syncPause. The server
-- owns the belt: the client asks with {resetId, seq, id} and shows what comes back.
clientUI.items=clientUI.ItemCarousel.new(clientUI.deviceRoot,{z=38})
clientUI.items:place(viewport.Position,viewport.Size,clientUI.deck.geometry~=nil and clientUI.deck.geometry.phone==true)
-- QA 2026-11-13 Q1: settle feedback and the first-drop idle hint over the board.
clientUI.boardHints=require(script.BoardHints).new(clientUI.deviceRoot,{z=37,audio=audio})
clientUI.boardHints:place(viewport.Position,viewport.Size)
gui.Destroying:Connect(function()clientUI.boardHints:destroy()end)
-- v1 track A onboarding: coach cards (Welcome card over the board, the guided garden step,
-- one-time cards saved in coachMask). Own frame step and snapshot listener; see CoachCards.lua.
do
 local CoachCards=require(script.CoachCards)
 local coachRemote=remotes:WaitForChild("HatchRequest")
 -- Round 3 (Spencer 2026-11-20: "the bunny should have an awesome hatch animation like the
 -- bear!"): the earned pet arrives as a hatch (PetArrivalHatch), played instead of the card.
 clientUI.arrivalHatch=require(script.PetArrivalHatch).new(gui.Parent,audio)
 clientUI.coach=CoachCards.new({gui=gui.Parent,boardParent=clientUI.deviceRoot,z=38,
  send=function(id)coachRemote:FireServer("coachMark",id)end,
  -- Slice E: "Say hi" on the arrival card makes the new friend the companion (the
  -- existing `companion` action; the server checks owned and active).
  sayHi=function(petId)request:FireServer("companion",petId)end,
  -- Round 3: its Meet does what Say hi did (CoachCards:startArrivalHatch).
  arrivalHatch=function(petId,done)return clientUI.arrivalHatch:play(petId,{appearance=nurseryView.appearanceFor(petId),onDone=done})end,
  learned=function(station)if clientUI.attract then clientUI.attract:learn(station)end end,
  -- QA v735 H5: the garden step is the "Your garden" tour (machines, Quests and dailies,
  -- customize, the Menu); closing it ends the step.
  tour=function(done)return require(script.HowItWorks).open("garden",{onClosed=done})end,
  -- Live growth cuts on the beta (PORT-TO-BETA.md): the Sleepy Nest on owns the "tomorrow" moment (no Tomorrow line).
  v3Tomorrow=function()return require(ReplicatedStorage.Shared.Onboard).on("nest")end})
 clientUI.coach:place(viewport.Position,viewport.Size)
 local stopCoachSnapshot=clientUI.ownerSnapshot.subscribe(function(state)clientUI.coach:sync(state);clientUI.coach:learned()end)
 local function beltCount()
  local ok,belt=pcall(clientUI.RoundItems.decodeBelt,clientUI.attr("ItemBelt"))
  clientUI.coachBelt=if ok and type(belt)=="table"then #belt else 0
 end
 board:GetAttributeChangedSignal("ItemBelt"):Connect(beltCount);beltCount()
 -- QA v2 R1.6: the garden tips again (for a "Show tips again" entry, e.g. How it works).
 function clientUI.replayCoachTips()return clientUI.coach:replayGarden()end
 -- QA v2 R1.6: the garden beats wait for a focused window, a still player and no menu,
 -- and pause while the player is away (no input).
 local cs={window=true,inputAt=os.clock(),stillSince=os.clock(),firstMeet=nil,shot=require(script.PetGreetingShot),closedBase=nurseryView.onClosed}
 cs.links={UserInputService.WindowFocused:Connect(function()cs.window=true;cs.inputAt=os.clock()end),
  UserInputService.WindowFocusReleased:Connect(function()cs.window=false end),
  UserInputService.InputBegan:Connect(function()cs.inputAt=os.clock()end),
  UserInputService.InputChanged:Connect(function(input)
   if input.UserInputType==Enum.UserInputType.MouseMovement or input.KeyCode==Enum.KeyCode.Thumbstick1 or input.KeyCode==Enum.KeyCode.Thumbstick2 then cs.inputAt=os.clock()end
  end)}
 -- QA v2 R1.4: the first Meet after the starter reveal stages the Bear in front of the
 -- player, facing the camera (PetGreetingShot front pass), until that greeting ends.
 nurseryView.onClosed=function(reason,choice)
  if reason=="meet"and type(choice)=="table"and choice.starter==true then
   cs.firstMeet={at=os.clock(),focused=false};cs.shot.setFrontFirst(true)
  end
  if cs.closedBase then cs.closedBase(reason,choice)end
 end
 local open={}
 local coachStep=RunService.RenderStepped:Connect(function()
  local mode=board:GetAttribute("Mode")
  local meet=cs.firstMeet
  if meet then
   if roomView.focusing then meet.focused=true
   elseif meet.focused or os.clock()-meet.at>20 then cs.firstMeet=nil;cs.shot.setFrontFirst(false)end
  end
  local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
  if humanoid and humanoid.MoveDirection.Magnitude>.1 then cs.stillSince=os.clock()end
  open.hatch=nurseryView:isOpen();open.style=isPickerOpen()and picker.active~="Settings"
  open.companions=clientUI.hub~=nil and clientUI.hub:isOpen();open.quests=clientUI.questLog.visible==true
  open.book=clientUI.book~=nil and clientUI.book:isOpen()
  open.arrival=clientUI.arrivalHatch:isOpen() -- Round 3: the arrival hatch holds the garden cards
  local companion=Pets.byId[board:GetAttribute("CompanionId")or ""]or Pets.byId.pip
  clientUI.coach:step(os.clock(),{mode=mode,canRoam=roomView.canRoam(),
   presented=backdrop.Visible and rendererPresentation.canPresent~=nil and rendererPresentation.canPresent(board:GetAttribute("ResetId")),
   phase=clientUI.attr("FieldPhase"),over=board:GetAttribute("RoundOver")==true,merges=clientUI.attr("Merges")or 0,
   pressure=clientUI.attr("OverflowPressure")or 0,belt=clientUI.coachBelt or 0,owned=board:GetAttribute("OwnedPets")or 0,
   input=clientUI.inputKind(),open=open,used=clientUI.attract and clientUI.attract.used or nil,pet=companion and companion.name or "Bear",
   companionId=board:GetAttribute("CompanionId"),
   -- Growth cuts: the say-hi line ends when the player says hi (the pet focus view).
   focusing=roomView.focusing==true,
   drops=clientUI.attr("Drops")or 0,windowActive=cs.window,idleFor=os.clock()-cs.stillSince,awayFor=os.clock()-cs.inputAt})
 end)
 gui.Destroying:Connect(function()coachStep:Disconnect();stopCoachSnapshot();clientUI.coach:destroy();clientUI.arrivalHatch:destroy();for _,link in ipairs(cs.links)do link:Disconnect()end end)
end
-- G2 (PetTrail, G2-FIRST-SESSION-LOOK 1a): the paw prints to the pet. CoachCards raises `trailDue` when the say-hi
-- line shows (or a first-visit tour closes); the trail then runs until the first saved pet, 30 s, a menu or machine,
-- or the deck. Hidden, not ended, while the garden is busy (the focus view, a transition). Contained in its own
-- function: the top-level chunk is at Luau's 200-register limit.
do
 (function()
 local Flags=require(ReplicatedStorage.Shared.FeatureFlags)
 if Flags.PetTrail==true then
  local Trail=require(script.PetTrail)
  local Kit=require(script.DeckKit)
  local trail=Trail.new({gui=overlayGui,ringColor=Kit.Tint.companions,chipColor=Kit.Tint.companions})
  local state={pet=nil}
  local function face(visual)
   if state.pet and state.pet~=visual then state.pet.faceOwner=nil;state.pet.poseDirty=true end
   state.pet=visual
   if visual then visual.faceOwner=true end
  end
  local function release()if state.pet then state.pet.faceOwner=nil;state.pet.poseDirty=true;state.pet=nil end end
  local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include
  local function ground(x,z,lineY)
   local room=workspace:FindFirstChild("EggDropLounge")
   if not room then return nil end
   params.FilterDescendantsInstances={room,workspace.Terrain}
   local result=workspace:Raycast(Vector3.new(x,lineY+Trail.RayUp,z),Vector3.new(0,-Trail.RayDown,0),params)
   if not result then return nil end
   local hit=result.Instance
   local regions=room:FindFirstChild("PetRegions")
   local function inside(point)
    for _,region in ipairs(regions and regions:GetChildren()or {})do
     if region:IsA("BasePart")and(region:GetAttribute("GardenWetRegion")==true or region:GetAttribute("GardenBlockedRegion")==true)
      and Trail.inFootprint(region.CFrame:PointToObjectSpace(point),region.Size)then return true end
    end
    return false
   end
   local info={position=result.Position,normal=result.Normal,
    ground=hit:IsA("Terrain")or hit:GetAttribute("WorldMesh")==true or hit:GetAttribute("GardenWalkableSpan")~=nil,
    water=result.Material==Enum.Material.Water or string.sub(hit.Name,1,8)=="W7_Water"}
   return if Trail.ground(info,lineY,inside)then info else nil
  end
  local link
  link=RunService.RenderStepped:Connect(function()
   local now=os.clock()
   -- Shown once a session: once it has drawn and gone, nothing here runs again.
   if state.started and not trail.active then link:Disconnect();return end
   local coach=clientUI.coach
   if coach and coach.trailDue then
    coach.trailDue=false
    if not trail.active and not state.started then state.started=true;state.savedBefore=clientUI.petSavedAt;trail:start(now)end
   end
   if not trail.active then return end
   local ctx=stationContext()
   local menu=ctx.overlay or ctx.menuOpen or ctx.coreMenu or(clientUI.hub~=nil and clientUI.hub:isOpen())or clientUI.questLog.visible==true
    or(clientUI.book~=nil and clientUI.book:isOpen())or clientUI.arrivalHatch:isOpen()
   -- On the beta the need bubbles' hello (a greeting counts there even when no pet is saved) and their own prints to
   -- the machine end it too: never two trails at once.
   local needs=clientUI.needs
   local greeted=needs~=nil and((needs.f~=nil and needs.f.saidHi==true)or(needs.autoTrail~=nil and needs.autoTrail~=false))
   local reason=Trail.endReason(now-trail.startedAt,{hello=clientUI.petSavedAt~=state.savedBefore or greeted,menu=menu,deck=board:GetAttribute("Mode")~="Room"})
   if reason then trail:stop(now);release()end
   local character=player.Character
   local root=character and character:FindFirstChild("HumanoidRootPart")
   local humanoid=character and character:FindFirstChildOfClass("Humanoid")
   local pet=roomView.pet
   local visible=not trail.leaving and roomView.canRoam()and root~=nil and humanoid~=nil and pet~=nil and pet.model and pet.model.Parent~=nil
   if visible and not trail.leaving then face(pet)elseif not trail.leaving then release()end
   local camera=workspace.CurrentCamera
   trail:step(now,{visible=visible,player=if visible then root.Position-Vector3.new(0,humanoid.HipHeight+root.Size.Y*.5,0)else nil,
    pet=if visible then pet.origin else nil,camera=camera,viewport=camera and camera.ViewportSize,
    reducedMotion=reduceEffects(),ground=ground})
  end)
  gui.Destroying:Connect(function()link:Disconnect();release();trail:destroy()end)
 end
 end)()
end
-- Remaining Welcome/first-spend work: contained ownership keeps the top-level
-- Luau local budget unchanged. Server owns timer/demo/grant and all toy writes.
do
 (function()
 local Kit=require(script.DeckKit)
 local Copy=require(ReplicatedStorage.Shared.UICopy)
 local Welcome=require(script.WelcomePresentation)
 local WelcomeProgress=require(ReplicatedStorage.Shared.WelcomeProgress)
 local welcomeReplies={}
 local Coach=require(ReplicatedStorage.Shared.CoachMarks)
 local focused=true
 local lastInput,lastActive,lastGeneration=-math.huge,nil,nil
 local internal=false
 local legacySkip=make("Frame","WelcomeLegacySkipWell",{BackgroundTransparency=1,Size=UDim2.fromOffset(0,0),Active=false,ZIndex=40},clientUI.deviceRoot)
 local legacyGesture=make("Frame","WelcomeLegacyGestureWell",{BackgroundTransparency=1,Size=UDim2.fromOffset(0,44),Active=false,ZIndex=40},clientUI.deviceRoot)
 local dependencies={copy=Copy.get,
  skip=function(sequence)request:FireServer("welcomeSkip",{sequence=sequence})end,
  cue=function(pitch,gain)audio:play("charge",pitch,gain)end,
  quietCue=function()audio:play("aim",1,.25)end,
  -- The First Hatch's merge sparks fly over the board (EggDrop, DisplayOrder 10) and the deck (9).
  sparkLayer=function()
   local gui=player.PlayerGui:FindFirstChild("EggDropWelcomeSparks")
   if not gui then gui=make("ScreenGui","EggDropWelcomeSparks",{ResetOnSpawn=false,DisplayOrder=11,IgnoreGuiInset=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},player.PlayerGui)end
   return gui
  end}
 -- Set before RoomView can start the initial deck boot, not on its first frame.
 clientUI.deck.boot.maxMs=if(board:GetAttribute("OwnedPets")or 0)==0 then 1200 else nil
 local legacy=Welcome.new({meter=meter,gesture=legacyGesture,skip=legacySkip},dependencies)
 -- The First Hatch (Onboard "opener"): a Welcome merge sends a spark in its tier's colour to the egg.
 clientUI.welcomeSpark=function(position,tier)
  if type(board:GetAttribute("WelcomeComboTarget"))~="number"or(board:GetAttribute("OwnedPets")or 0)>0 or clientUI.attr("FieldPhase")~="Welcome"then return end
  local at=viewport.AbsolutePosition+project(position)
  local palette=clientUI.JellyPalette.byTier[tier]
  local pitch=1.1+.1*(tonumber(tier)or 1)
  if clientUI.deck.welcomeView then clientUI.deck.welcomeView:spark(at,palette and palette.body,pitch)end
  legacy:spark(at,palette and palette.body,pitch)
 end
 local context={}
 clientUI.welcomeInput=function()
  clientUI.deck:welcomeInput();legacy:input()
  if(board:GetAttribute("OwnedPets")or 0)==0 and os.clock()-lastInput>=.1 then
   lastInput=os.clock();request:FireServer("welcomeInput",{sequence=board:GetAttribute("RunSequence")})
  end
 end
 clientUI.cancelFirstSpend=function(kind,reason)
  if not internal and clientUI.firstSpend then clientUI.firstSpend:routeChanged(kind,reason)end
 end
 clientUI.firstSpend=require(script.FirstSpendGuide).new({intent=clientUI.toyIntent,
  actorIdentity=function()
   local petId=board:GetAttribute("CompanionId")
   local actor=petId and roomView.garden:renderActor(player.UserId,petId,player.Character)
   return require(script.FirstSpendToyHost).identity(actor)
  end,
  openEggs=function(kind)if not openNursery then return false end;openNursery();return nurseryView:selectRecipe(kind)end,
  enterRoom=function()
   internal=true
   clientUI.hueView:close("first-toy");nurseryView:close("first-toy");clearPlayInputs()
   internal=false
   if board:GetAttribute("Mode")~="Room"then request:FireServer("mode","Room")end
  end,
  play=function(_,toyId)
   return require(script.FirstSpendToyHost).try(clientUI.firstSpend,roomView.pet,toyId,require(script.PetPlayVisual),workspace:GetServerTimeNow())
  end})
 clientUI.syncFirstSpend=function(state)
  return clientUI.firstSpend:update(state,{eligible=not Coach.veteran(state and state.totalWins)})
 end
 clientUI.syncFirstSpend(nurseryState or {})
 nurseryView.onRouteChanged=clientUI.cancelFirstSpend
 clientUI.hueView.options.routeChanged=clientUI.cancelFirstSpend
 clientUI.hueView.options.firstToyReady=function(result)
  return clientUI.firstSpend.stage=="receipt"and clientUI.firstSpend.proof~=nil and result~=nil and clientUI.firstSpend.proof.id==result.id
 end
 clientUI.hueView.options.firstToyGive=function()
  return clientUI.firstSpend:give(board:GetAttribute("CompanionId")or(Pets.active[1]or Pets[1]).id)
 end
 clientUI.hueView.toyPanel.options.storeFirst=function(result)
  if not clientUI.hueView.options.firstToyReady(result)then return false end
  if clientUI.toyIntent.status=="Retrying"then clientUI.toyIntent:retry()else clientUI.toyIntent:ack(result.id)end
  return true
 end
 local spendButton=Kit.button(clientUI.coach.host,"FirstSpendHatch",{variant="quiet",text=Copy.get("onboarding.spend.hatch"),size=Vector2.new(172,48),textSize=16})
 spendButton.Visible=false;spendButton.AnchorPoint=Vector2.new(.5,0);spendButton.ZIndex=42
 spendButton.Activated:Connect(function()clientUI.firstSpend:openEggs()end)
 local links={
  UserInputService.WindowFocused:Connect(function()focused=true end),
  UserInputService.WindowFocusReleased:Connect(function()focused=false;clientUI.welcomeInput();clientUI.cancelFirstSpend()end),
  GuiService.MenuOpened:Connect(function()clientUI.welcomeInput();clientUI.cancelFirstSpend()end),
 }
 local result=remotes:WaitForChild("WelcomeResult")
 table.insert(links,result.OnClientEvent:Connect(function(packet)
  if type(packet)~="table"or packet.sequence~=board:GetAttribute("RunSequence")then return end
  local pending=WelcomeProgress.reply(welcomeReplies,packet.sequence,packet.status)
  if pending~=nil then clientUI.deck:welcomeResult(pending);legacy:setSkipPending(pending)end
 end))
 local function updateWelcome()
  local welcome=(board:GetAttribute("OwnedPets")or 0)==0 and clientUI.attr("FieldPhase")=="Welcome"
  local active=welcome and canAim()and not isPickerOpen()and focused and audio.deviceActive~=false and not GuiService.MenuIsOpen
   and not UserInputService:GetFocusedTextBox()and not roomView.transition.shade.Visible
  local generation=board:GetAttribute("RunSequence")
  if welcome and(lastActive~=active or lastGeneration~=generation)then lastActive,lastGeneration=active,generation;request:FireServer("welcomeActive",active)
  elseif not welcome then lastActive,lastGeneration=nil,nil end
  context.generation=board:GetAttribute("RunSequence");context.charge=board:GetAttribute("HatchCharge")or 0
  context.threshold=Pets.byId.pip.charge;context.owned=board:GetAttribute("OwnedPets")or 0;context.phase=clientUI.attr("FieldPhase")
  -- The First Hatch (Onboard "opener"): the egg's three stages are the three combos
  local comboTarget=board:GetAttribute("WelcomeComboTarget")
  context.combo=nil
  if type(comboTarget)=="number"and comboTarget>0 then context.charge=board:GetAttribute("WelcomeCombos")or 0;context.threshold=comboTarget;context.combo=true end
  context.drops=clientUI.attr("Drops")or 0;context.skipReady=board:GetAttribute("WelcomeSkipReady")==true
  context.grantPending=board:GetAttribute("WelcomeGrantPending")==true;context.revealPending=nurseryState and nurseryState.lastHatch~=nil
  context.device=clientUI.inputKind();context.reduced=reduceEffects()
  context.active=active and clientUI.deck.visible==true
  clientUI.deck:setWelcome(context,dependencies)
  context.active=active and clientUI.legacyDeck.Visible
  legacy:update(context)
  -- Portrait fallback also uses existing wells, without changing any input rect.
  legacyGesture.Position=viewport.Position+UDim2.fromOffset(0,viewport.Size.Y.Offset*.72);legacyGesture.Size=UDim2.fromOffset(viewport.Size.X.Offset,44)
  legacySkip.Position=status.Position+UDim2.fromOffset(8,status.Size.Y.Offset-52)
  legacySkip.Size=UDim2.fromOffset(if status.Size.X.Offset>=88 and status.Size.Y.Offset>=80 then status.Size.X.Offset-16 else 0,if status.Size.Y.Offset>=80 then 48 else 0)
  if welcome then
   meterText.Visible=false;dispenser.host.Visible=false
   clientUI.deck.boot.maxMs=1200
  else clientUI.deck.boot.maxMs=nil end
  local stage=clientUI.firstSpend.stage
  local free=board:GetAttribute("Mode")=="Room"and roomView.canRoam()and focused
   and not clientUI.coach.gardenView.root.Visible and not roomView.focusing and not roomView.busy
  -- G2 (FirstHelloBonus): the first hello's moment is its own; the garden pills wait it out.
  local quiet=os.clock()<(clientUI.helloQuietUntil or 0)
  local canOffer=stage=="purchase"and free and not quiet
  local growthFlags=require(ReplicatedStorage.Shared.FeatureFlags)
  local Nudge=require(script.GrowthNudge)
  local petName=(Pets.byId[board:GetAttribute("CompanionId")or ""]or Pets.active[1]or Pets[1]).name
  spendButton.Visible=false
  if canOffer then
   -- G2 (ToyPillCopy): the pill and its card name the pet (refreshed if the name changes); off = today's words.
   local toy=Nudge.toyCopy(growthFlags)
   local vars=if toy.named then{pet=petName}else nil
   local run=function()clientUI.firstSpend:openEggs()end
   if not clientUI.firstSpendRail then
    clientUI.firstSpendRail=require(script.NotificationRail).status(clientUI.coach.host,"firstSpend",{text=Copy.get(toy.pill,vars),icon="★",priority=1,
     -- QA v735 H5: a tap explains it first; the card's button opens Hatch eggs on the Toy Egg.
     detail=require(script.NoticeCards).detail(toy.card,vars,run)})
    clientUI.firstSpendName=petName
   elseif toy.named and clientUI.firstSpendName~=petName then
    clientUI.firstSpendName=petName
    clientUI.firstSpendRail:update({text=Copy.get(toy.pill,vars),detail=require(script.NoticeCards).detail(toy.card,vars,run)})
   end
   clientUI.firstSpendRail:update({active=true})
  elseif clientUI.firstSpendRail then clientUI.firstSpendRail:update({active=false})end
  -- G2 (RoundTwoNudge): after the toy (or with no Stars for one), one pill that taps straight into round two. It waits
  -- Nudge.Delay s in a free garden, never shows with the toy pill (another stage) and never again once a field
  -- round has started this session (a new session brings it back until one is saved).
  -- "Started" = a ball dropped in a field round (not just the deck open, a menu or the hatch reveal).
  if(board:GetAttribute("OwnedPets")or 0)>0 and board:GetAttribute("Mode")=="Board"and clientUI.attr("FieldPhase")~="Welcome"
   and(clientUI.attr("Drops")or 0)>0 then clientUI.roundTwoStarted=true end
  -- On the beta the need bubbles own round two (the deck bubble): no pill while they run for this session (switch on,
  -- BearNeeds mounted and alive, not a returning save; not yet known = theirs). A returning save gets the pill, as live.
  local needs=clientUI.needs
  local bubbles=needs~=nil and not needs.dead and not(if needs.ready then needs.returning else needs.began==true)
   and require(ReplicatedStorage.Shared.Onboard).on("needs")
  local roundTwo=if bubbles then nil else Nudge.variant(stage,nurseryState,growthFlags,clientUI.roundTwoStarted)
  if roundTwo and free and not quiet then clientUI.roundTwoSince=clientUI.roundTwoSince or os.clock()else clientUI.roundTwoSince=nil end
  if clientUI.roundTwoSince and os.clock()-clientUI.roundTwoSince>=Nudge.Delay then
   local key,vars=Nudge.copy(roundTwo,petName)
   local text=Copy.get(key,vars)
   if not clientUI.roundTwoRail then
    clientUI.roundTwoRail=require(script.NotificationRail).status(clientUI.coach.host,"roundTwo",{text=text,kind="round",kitIcon="ball",priority=1,
     activate=function()if clientUI.playRoundForStars()then clientUI.accepted("confirm");return true end;return false end})
   elseif clientUI.roundTwoText~=text then clientUI.roundTwoRail:update({text=text})end
   clientUI.roundTwoText=text
   clientUI.roundTwoRail:update({active=true})
  elseif clientUI.roundTwoRail then clientUI.roundTwoRail:update({active=false})end
  local flight=clientUI.firstSpend.flight
  if flight then
   local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
   if humanoid and humanoid.MoveDirection.Magnitude>.05 then clientUI.cancelFirstSpend()
   else
    local pet=roomView.pet;local petId=board:GetAttribute("CompanionId")
    local actor=petId and roomView.garden:renderActor(player.UserId,petId,player.Character)
    local Host=require(script.FirstSpendToyHost)
    local identity=Host.identity(actor)
    local ready=Host.ready(pet,actor,flight)
    clientUI.firstSpend:step({mode=board:GetAttribute("Mode"),ready=not roomView.busy and not clientUI.isHueOpen()and not nurseryView:isOpen(),
     petId=petId,actorReady=ready,actorIdentity=identity})
   end
  end
 end
 table.insert(links,RunService.RenderStepped:Connect(function(dt)updateWelcome();clientUI.deck:stepWelcome(dt);legacy:step(dt)end))
 gui.Destroying:Connect(function()
  for _,link in ipairs(links)do link:Disconnect()end
  if clientUI.firstSpendRail then clientUI.firstSpendRail:cancel();clientUI.firstSpendRail=nil end
  if clientUI.roundTwoRail then clientUI.roundTwoRail:cancel();clientUI.roundTwoRail=nil end
  clientUI.firstSpend:destroy();clientUI.deck:destroyWelcome();legacy:destroy();legacySkip:Destroy();legacyGesture:Destroy();spendButton:Destroy()
 end)
 end)()
end
-- Overnight 2026-11-14 slice F: bond levels. The snapshot's `bond` ({petId = xp}) feeds the
-- garden pet (focus card pips, tricks 1-2) and the level-up moment: a toast under the coach
-- card and the flourish on the pet (RoomView.bondLevelUp). clientUI.bondSeen holds the last
-- level seen per pet, so a level shows once; the first snapshot only sets the baseline.
-- Without `bond` in the snapshot (or without Shared.BondCatalog) nothing here does anything.
do
 local BondPips=require(script.BondPips)
 clientUI.bondSeen={}
 local stopBondSnapshot=clientUI.ownerSnapshot.subscribe(function(state)
  local bond=type(state)=="table"and state.bond or nil
  roomView:setBond(bond)
  if type(bond)~="table"then return end
  local ups=BondPips.levelUps(clientUI.bondSeen,bond)
  -- Levels matter S1: Heart brings the tricks (bond XP still may); a Heart ticket names its own trick.
  local Toasts=require(script.StatToasts)
  if Toasts.tricksOn()then
   for _,event in ipairs(Toasts.trickUps(clientUI.bondSeen,state))do
    if Pets.isActive(event.petId)then
     if not event.heart then clientUI.coach.toaster.show(event.text)end
     roomView:bondLevelUp(event.petId,event.level)
    end
   end
   return
  end
  clientUI.bondSeen.tricks=nil -- off: today's toast, and a fresh trick baseline next time
  for _,event in ipairs(ups)do
   if Pets.isActive(event.petId)then
    roomView:bondLevelUp(event.petId,event.level)
    clientUI.coach.toaster.show(BondPips.toastText(event.level),nil,nil,require(script.NoticeCards).detail("bond"))
   end
  end
 end)
 gui.Destroying:Connect(stopBondSnapshot)
end
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
 if clientUI.clientSim then
  local taken,why=clientUI.clientSim.item(id)
  if taken~=nil then
   clientUI.closeItems(true);clientUI.accepted("confirm")
   -- B3: the round host refused it here: the same notes as the server's refusals.
   if taken==false then clientUI.items:showNote(({Budget="No ball left for that",Empty="Nothing to pop",Armed="An item is already armed",NotLive="Not right now"})[why]or "Not right now")end
   return true
  end
 end
 request:FireServer("item",{resetId=board:GetAttribute("ResetId"),seq=clientUI.attr("ItemSeq")or 0,id=id})
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
 local belt=clientUI.RoundItems.decodeBelt(clientUI.attr("ItemBelt"))
 clientUI.items:setBelt(belt)
 local front=clientUI.RoundItems.ById[belt[1]or ""]
 clientUI.deck:setItems(#belt,front and front.glyph,front and front.color,belt[1])
 clientUI.syncItemChip()
 if clientUI.items.isOpen and(#belt==0 or not clientUI.itemsInRound())then clientUI.closeItems(true)end
end
for _,name in ipairs({"ItemBelt","ItemsOn","Mode","RoundOver","ResetId"})do
 board:GetAttributeChangedSignal(name):Connect(clientUI.refreshItems)
end
board:GetAttributeChangedSignal("ItemEvent"):Connect(function()
 local ok,event=pcall(function()return HttpService:JSONDecode(board:GetAttribute("ItemEvent")or "")end)
 if not ok or type(event)~="table"or event.resetId~=board:GetAttribute("ResetId")then return end
 -- B3: the mirror showed this round's grants (and full notes) at the merge.
 if(event.kind=="granted"or event.kind=="full")and clientUI.mirror and clientUI.mirror:grantPlayed(event.resetId)then return end
 local item=clientUI.RoundItems.ById[event.id or ""]
 if event.kind=="full"then clientUI.items:showNote(clientUI.ItemCarousel.FullNote);audio:play("aim",.6,.3)
 elseif event.kind=="granted"and item then
  -- S2b: a power-up grant follows its merge on the snapshot clock.
  local function grant()clientUI.items:showGrant(event.id);audio:play("quest_complete",1.2,.5)end
  if clientUI.boardNet then clientUI.boardNet.schedule(event.tick,grant)else grant()end
 elseif event.kind=="refused"then
  clientUI.items:showNote(({Budget="No ball left for that",Empty="Nothing to pop",Armed="An item is already armed",NotLive="Not right now"})[event.reason]or "Not right now")
 end
end)
clientUI.refreshItems()
-- Deck hardware (mouse and touch). Results take the d-pad and A/B while open.
-- QA v2 R2.4: the phone B (the item button) is Items in a round and Back while a deck
-- menu (Pocket Menu, picker, quest log, results) is up; outside both it stays Items.
function clientUI.deckBack()
	if clientUI.closePocketMenu()then return end
	if clientUI.questLog.visible then clientUI.closeQuestLog()elseif recap.visible then recap:back() else clientUI.leaveDeck() end
end
clientUI.deck:on("quests",function()clientUI.openQuestLog("daily")end)
clientUI.deck:on("item",function()
	if not clientUI.items.isOpen and clientUI.deck:menuActive()then clientUI.deckBack()else clientUI.toggleItems()end end)
clientUI.deck:on("dpad",function(dir,input)
	if clientUI.items.isOpen then
		if dir=="Left"or dir=="Right"then clientUI.items:move(if dir=="Left"then -1 else 1)end
	elseif clientUI.pocketMenu.visible then
		clientUI.pocketMenu:move(if dir=="Left"then -1 elseif dir=="Right"then 1 else 0,if dir=="Up"then -1 elseif dir=="Down"then 1 else 0)
	elseif clientUI.questLog.visible then
		if dir=="Up"or dir=="Down"then clientUI.questLog:move(if dir=="Up"then -1 else 1)else clientUI.questLog:cycleTab(if dir=="Left"then -1 else 1)end
	elseif clientUI.heatPicker.visible then
		-- QA v2 R2.4: the phone d-pad's Up / Down rows select in menus too (Up = back a card).
		clientUI.heatPicker:move(if dir=="Left"or dir=="Up"then -1 else 1)
	elseif recap.visible then
		recap:move2D(if dir=="Left"then -1 elseif dir=="Right"then 1 else 0,if dir=="Up"then -1 elseif dir=="Down"then 1 else 0)
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
	clientUI.deckBack() end)
-- MENU: the Pocket Menu in a round; the quest log from results (UI-SPEC 5.4) or
-- when it is already open (closes it); the garden menu outside the deck.
-- QA Q5: MENU in a round is the pause menu; on the results screen it does nothing (the
-- quest log opens from the garden hub now); outside the deck it is the machine hub.
clientUI.deck:on("menu",function()
	if clientUI.items.isOpen then clientUI.closeItems(true)end
	if board:GetAttribute("Mode")=="Board"then
		if clientUI.pocketMenu.visible then clientUI.closePocketMenu()
		elseif recap.visible then return
		elseif clientUI.openPocketMenu()then clientUI.accepted("confirm")end
	elseif openMenu()then clientUI.accepted("confirm")end end)
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
  picker:hide() -- the quest log lives in the garden now (QA Q5) and stays open
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
clientUI.heatCallbacks.select=function(key)clientUI.pickedHeat=key;audio:play("aim",1.1,.35)end
clientUI.heatCallbacks.start=function(key)
 if board:GetAttribute("Heat")~=key or board:GetAttribute("NextHeat")~=key then request:FireServer("heat",key)end
 clientUI.pickedHeat=nil;clientUI.heatStarted=true;clientUI.heatPicker:hide()
 clientUI.accepted("confirm");if updateHud then task.defer(updateHud)end
end
-- QA Q5: the quest log's one entry point is the machine hub's Quests tile
-- (options.fromHub); Back from it returns to the hub, sliding in from the left.
function clientUI.openQuestLog(tab,options)
 options=options or {}
 if clientUI.pocketMenu.visible or clientUI.questLog.visible then return false end
 if clientUI.items.isOpen then clientUI.closeItems(true)end
 if roomView.busy or modal.Visible or isPickerOpen()or gameMenu.shade.Visible or nurseryView:isOpen()or clientUI.isHueOpen()then return false end
 clearPlayInputs()
 if GuiService.SelectedObject then GuiService.SelectedObject=nil end
 clientUI.questFromHub=options.fromHub==true
 clientUI.questLog:show(nurseryState and nurseryState.quests,nurseryState and nurseryState.nectar or 0,tab,{focus=options.focus})
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
 local fromHub=clientUI.questFromHub;clientUI.questFromHub=nil
 if fromHub then task.defer(function()if openMenu then openMenu({focus="quests",slideFrom=-require(script.DeckKit).SlideOffset})end end)end
 return true
end
-- Pocket Menu routes. Restart / Quit confirm in the menu itself (one more tap mid-round).
function clientUI.pocketState()
 local owned=(board:GetAttribute("OwnedPets")or 0)>0
 local over=board:GetAttribute("RoundOver")==true
 return{empty=(clientUI.attr("Drops")or 0)==0,locked=not owned,canRestart=owned and not over and(clientUI.attr("FieldPhase")or "Welcome")~="Welcome",
  canQuit=owned,canSettings=true}
end
-- focusId (optional): the row to focus (Back from Settings returns to "settings").
function clientUI.openPocketMenu(focusId)
 if clientUI.pocketMenu.visible then return false end
 if clientUI.items.isOpen then clientUI.closeItems(true)end
 if board:GetAttribute("Mode")~="Board"or roomView.busy or modal.Visible or recap.visible or isPickerOpen()or gameMenu.shade.Visible
  or nurseryView:isOpen()or clientUI.isHueOpen()or board:GetAttribute("RoundOver")==true then return false end
 if clientUI.questLog.visible then return false end
 clearPlayInputs()
 local state=clientUI.pocketState()
 -- One restart request per 3.5 s (the server's own cooldown is 3 s).
 if os.clock()-(clientUI.lastRestart or -math.huge)<3.5 then state.canRestart=false end
 clientUI.pocketMenu:open(state,focusId)
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
 local empty=(clientUI.attr("Drops")or 0)==0
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
-- QA Q5: Settings over the paused round. The picker opens before the menu closes (and
-- the overlay shade is raised at once) so the pause holds; Back returns to this row.
clientUI.pocketCallbacks.settings=function()
 local opened=openPicker("Settings",{pocket="settings"})==true
 if opened then modalShade.Visible=true end
 clientUI.closePocketMenu(true)
 if opened then clientUI.accepted("confirm")end
end
clientUI.pocketCallbacks.armed=function()audio:play("aim",.8,.4)end
clientUI.pocketCallbacks.locked=function(id,state)
 clientUI.deck.toaster.show(if state.locked then "Win this round to meet your first pet"
  elseif id=="restart"then(if state.empty then "The round has not started"elseif board:GetAttribute("RoundOver")==true then "The round is over"else "Restarting, one moment")else "Not available right now",
  nil,nil,if state.locked then require(script.NoticeCards).detail("locked")else nil)
 audio:play("aim",.6,.3)
end
clientUI.questCallbacks.claim=function(scope,slot,period)
 nurseryRequest:FireServer("questClaim",{scope=scope,slot=slot,period=period},nurseryState and nurseryState.revision or 0)
end
clientUI.questCallbacks.reroll=function(slot,day)
 nurseryRequest:FireServer("questReroll",{slot=slot,period=day},nurseryState and nurseryState.revision or 0)
end
clientUI.questCallbacks.back=function()clientUI.closeQuestLog()end
-- The log's "Menu" button: back to the machine hub (closeQuestLog reopens it when the
-- log came from there; otherwise open it here).
clientUI.questCallbacks.menu=function()
 local fromHub=clientUI.questFromHub
 clientUI.closeQuestLog()
 if not fromHub and openMenu()then clientUI.accepted("confirm")end
end
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
   -- QA v735 H5: a tap on the ticker says what it means and where to claim it.
   clientUI.deck.toaster.show("Quest done: "..row.title,row.reward,nil,require(script.NoticeCards).detail("questReady",{quest=row.title,reward=row.reward}));audio:play("quest_complete",1,.7)
  end
 end end
 clientUI.questReady=ready
 clientUI.questLog:update(q,state.nectar or 0)
end
clientUI.questResultConnection=remotes:WaitForChild("QuestResult").OnClientEvent:Connect(function(message)
 clientUI.questLog:result(message)
 if type(message)~="table"then return end
 if message.status=="Saved"and message.action=="questClaim"then
  clientUI.deck.toaster.show("Quest claimed",message.stars,nil,require(script.NoticeCards).detail("questClaimed",{reward=message.stars}));audio:play("quest_complete",1.1,.7)
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
  -- In a round Menu opens the Pocket Menu (pause). On the results screen it does nothing
  -- now (QA Q5: the quest log opens from the garden hub's Quests tile only).
  local k=input.KeyCode
  local menuKey=k==Enum.KeyCode.M or k==Enum.KeyCode.ButtonY or k==Enum.KeyCode.ButtonSelect or k==Enum.KeyCode.ButtonStart
  if recap.visible and menuKey then return Enum.ContextActionResult.Sink end
  local inRound=board:GetAttribute("Mode")=="Board"and backdrop.Visible and not modal.Visible and not isPickerOpen()and not board:GetAttribute("RoundOver")
  if menuKey and inRound then
   if state==Enum.UserInputState.Begin and clientUI.openPocketMenu()then clientUI.accepted("confirm")end
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
  elseif menu then if clientUI.openPocketMenu()then clientUI.accepted("confirm")end end -- QA Q5: Menu pauses
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
	if eggViews[source] then return end -- one view per ball (content gate, clock and handoff can all ask)
	-- v890 QA: a drawn ball a predicted merge took stays hidden until it is confirmed or undone.
	if clientUI.ghosts and clientUI.ghosts.predictedPartner[source] then return end
	-- B3: on a round the mirror draws, the server's Parts get no view (the mirror's do).
	if clientUI.mirror and clientUI.mirror:hides(source) then return end
	if clientUI.netTapShown and (source.Parent==board or source.Name:sub(1,6)=="Ghost_" or source.Name:sub(1,7)=="Mirror_") then clientUI.netTapShown() end
	local tier = source:GetAttribute("Tier")
	local id = source:GetAttribute("EggId")
	if not tier or not id or source:GetAttribute("BoardSerial")~=board:GetAttribute("ResetId")then
		return
	end
	local gel = if RunService:IsStudio() and gui:GetAttribute("MeshPreview")
		then Jelly.new(scene, source) else Sprite.new(sprites, source,{gridWidth=JellyLCD.Width,themeId=clientUI.equippedBallTheme(),lazy=lcd~=nil})
	-- No tier numerals (batch R1): size, colour and the ball's face carry the tier.
	eggViews[source] = { gel = gel, id = id, tier = tier, radius = Config.Tiers[tier].radius, faceInput = { id = id, tier = tier, x = 0, y = 0, radius = Config.Tiers[tier].radius }, face = { tier = tier, expr = "idle", dx = 0 } }
	viewsById[id] = gel
	if rendererPresentation.fx.trail then rendererPresentation.fx:ballAdded(source) end -- deck juice: nil while classic
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
 -- A server ball held for a ghost's handoff gets its view at the handoff, not here.
 for _,source in ipairs(board:GetChildren())do
  if not eggViews[source]and not(clientUI.ghosts and clientUI.ghosts:holding(source))then addView(source)end
 end
 return true
end
-- Deck network S2b (deck-network-plan.md): with the snapshot clock on, a ball's view
-- appears when the clock reaches its first sample and leaves when it passes its last,
-- not when the reliable Part happens to arrive or leave. Clock off: at once, as before.
clientUI.boardNet=require(script.BoardNetClient)
board:GetAttributeChangedSignal("ResetId"):Connect(function()clientUI.netChain=nil end)
-- Measured (v854 profile): a full updateHud per merge played on the clock was the top
-- per-event client cost (1.2-2.3 ms). A played merge changes only score and chain.
function clientUI.netScoreKick()
 if clientUI.netScoreQueued then return end
 clientUI.netScoreQueued=true
 task.defer(function()
  clientUI.netScoreQueued=false
  if(board:GetAttribute("OwnedPets")or 0)==0 or not clientUI.deck.setScore then updateHud();return end
  local score,chain=clientUI.attr("Score")or 0,clientUI.attr("Chain")or 0
  local held=if clientUI.mirrorOwns(board:GetAttribute("ResetId"))then 0 else clientUI.boardNet.pending("score")
  if held>0 then score=math.max(0,score-held);chain=clientUI.netChain or chain end
  if not clientUI.deck:setScore(score,chain)then updateHud()end
 end)
end
function clientUI.netHudKick()
 if clientUI.netHudQueued then return end
 clientUI.netHudQueued=true
 task.defer(function()clientUI.netHudQueued=false;updateHud()end)
end
table.insert(rendererPresentation.connections,board.ChildAdded:Connect(function(source)
 clientUI.boardNet.afterSpawn(source,function()
  if source.Parent~=board then return end
  -- S5: a ball this client predicted waits for its ghost's handoff.
  local show=function()if source.Parent==board then addView(source)end end
  if clientUI.ghosts and clientUI.ghosts:holdSpawn(source:GetAttribute("EggId"),source,show)then return end
  show()
 end)
end))
table.insert(rendererPresentation.connections,board.ChildRemoved:Connect(function(source)
 if clientUI.ghosts then clientUI.ghosts:partnerGone(source)end
 if source:GetAttribute("BoardSerial")~=board:GetAttribute("ResetId")then removeView(source);return end
 clientUI.boardNet.afterRemoval(source,function()
  if clientUI.ghosts then clientUI.ghosts:serverGone(source:GetAttribute("EggId"))end
  removeView(source)
 end)
end))
-- S5 ghost ball (FeatureFlags.DeckNetGhost, needs DeckNetDrop): drawn as one more view.
if clientUI.dropIntent and require(ReplicatedStorage.Shared.FeatureFlags).DeckNetGhost==true then
 local constants=setmetatable({},{__index=function(_,key)
  if key=="bounce"then return(Config.Presets[board:GetAttribute("Preset")or ""]or Config.Presets[Config.DefaultPreset]).bounce end
  return Config[key]
 end})
 clientUI.dropIntent.ghostGate=true
 clientUI.ghosts=require(script.GhostDrops).new({
  constants=constants,
  resetId=function()return board:GetAttribute("ResetId")end,
  canShow=function()return board:GetAttribute("Mode")=="Board"and backdrop.Visible and gui.Enabled and not GuiService.MenuIsOpen end,
  add=function(source)addView(source)end,
  remove=function(source)removeView(source)end,
  hasView=function(eggId)return viewsById[eggId]~=nil end,
  rebind=function(source,eggId)
   local view=eggViews[source];if not view then return end
   viewsById[view.id]=nil;view.id=eggId;view.faceInput.id=eggId;viewsById[eggId]=view.gel
  end,
  obstacles=function(out)
   -- Reused entries: no tables per frame (phone GC).
   local n=0
   for source,view in pairs(eggViews)do
    if view.id>=0 and not clientUI.ghosts:isGhost(source)then
     n+=1;local o=out[n];if not o then o={};out[n]=o end
     local p=source.Position
     o[1],o[2],o[3],o[4],o[5],o[6],o[7]=p.X,p.Y,source.Size.X/2,false,source,view.tier,view.id
    end
   end
   for i=#out,n+1,-1 do out[i]=nil end
  end,
  onContact=function(token)clientUI.dropIntent:contact(token)end,
  newestTick=function()return clientUI.boardNet.newestTick()end,
  -- v890 QA: a predicted merge plays now (blob, burst, jolt, sound); the score popup and the
  -- chain accent wait for the server's event (the chain is the server's).
  predictMerge=function(P)
   removeView(P.partner)
   local serial=board:GetAttribute("ResetId")
   if not rendererPresentation.canPresent(serial)then return end
   local now,id,reduced=os.clock(),-P.result.token,reduceEffects()
   audio:play(if P.tier==2 then "merge_bubble"else "merge_jelly",audio:mergePitch(1,id),.56)
   clientUI.haptics.merge(P.tier,1,false)
   if lcdEnabled()and not reduced then
    if #pixelMerges>=6 then table.remove(pixelMerges,1)end
    table.insert(pixelMerges,{first=pixelPoint(Vector2.new(P.fromX,P.fromY)),second=pixelPoint(Vector2.new(P.otherX,P.otherY)),point=pixelPoint(Vector2.new(P.x,P.y)),
     radius=Config.Tiers[P.tier-1].radius*JellyLCD.Width/(Config.Width+.8),resultRadius=Config.Tiers[P.tier].radius*JellyLCD.Width/(Config.Width+.8),
     color=clientUI.JellyPalette.byTier[P.tier].body,tier=P.tier,start=now,id=id})
   end
   rendererPresentation.setFieldOwner(true,serial,reduced)
   rendererPresentation.fx:emit("merge",project(Vector2.new(P.x,P.y)),Config.Tiers[P.tier].radius*viewport.AbsoluteSize.X/(Config.Width+.8),clientUI.JellyPalette.byTier[P.tier].body,P.tier,1,serial,now,nil,false,nil)
   rendererPresentation.jolt.scale=viewport.AbsoluteSize.Y/420
   rendererPresentation.jolt:emit(serial,id,P.tier,1,false,now)
  end,
  undoMerge=function(P)
   local id=-P.result.token
   for index=#pixelMerges,1,-1 do if pixelMerges[index].id==id then table.remove(pixelMerges,index)end end
   if P.partner.Parent==board then addView(P.partner)end
  end,
 })
 gui.Destroying:Connect(function()clientUI.ghosts:destroy()end)
end
-- B3 client-run board (B3-plan.md): on a lockstep round the deck draws the client's own round
-- host through ClientBoardMirror (local Parts into addView, local merges / impacts / drops /
-- grants through the same juice as the server's events, provisional HUD values via clientUI.attr).
-- Flag off it never owns a serial and every hook above falls through to today's path.
if clientUI.clientSim and clientUI.clientSim.attach then
 xpcall(function()
  clientUI.mirror=require(script.ClientBoardMirror).new({
   board=board,driver=clientUI.clientSim,
   add=function(source)addView(source)end,
   remove=function(source)removeView(source)end,
   hasView=function(source)return eggViews[source]~=nil end,
   -- Adoption: every other view leaves first (views are keyed by ball id in viewsById).
   hideServer=function()for source in pairs(eggViews)do if not clientUI.mirror:isMine(source)then removeView(source)end end end,
   released=function()for _,source in ipairs(board:GetChildren())do addView(source)end end,
   merge=function(m,serial,late)
    if late or not rendererPresentation.canPresent(serial)then clientUI.ballFaces:merged(m.id,os.clock());return end
    clientUI.playMerge(Vector2.new(m.x,m.y),m.tier,m.chain,Vector2.new(m.fromX,m.fromY),Vector2.new(m.otherX,m.otherY),m.id,m.cleared,serial)
   end,
   impacts=function(batch,serial)if rendererPresentation.canPresent(serial)then clientUI.playImpacts(batch,serial)end end,
   drop=function(count,serial)
    if count>0 and clientUI.boardHints then clientUI.boardHints:noteDrop()end
    rendererPresentation.fx:observeDrop(serial,count)
    if rendererPresentation.canPresent(serial)then
     audio:play("drop",1,.48)
     rendererPresentation.setFieldOwner(true,serial,reduceEffects())
     rendererPresentation.jolt:drop(serial,count,os.clock())
    end
   end,
   grant=function(kind,id,serial,late)
    if kind=="full"then clientUI.items:showNote(clientUI.ItemCarousel.FullNote);audio:play("aim",.6,.3)
    elseif kind=="granted"and clientUI.RoundItems.ById[id]then clientUI.items:showGrant(id);audio:play("quest_complete",1.2,.5)end
   end,
   changed=function(hud,score,belt,objective)
    if belt and clientUI.refreshItems then clientUI.refreshItems()end
    if objective then clientUI.fieldView=clientUI.FieldQuestText.read(clientUI.boardView,clientUI.fieldCache);if layout then layout()end end
    if hud or objective then clientUI.netHudKick()elseif score then clientUI.netScoreKick()end
   end,
  })
 end,function(problem)warn("[ClientBoardMirror] not started (the deck draws the server's Parts): "..tostring(problem))end)
 gui.Destroying:Connect(function()if clientUI.mirror then clientUI.mirror:destroy()end end)
end
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
-- B3: the impact juice (squash, plop, ring), shared by the server's BoardImpact batches on the
-- snapshot clock and the mirror's local impacts. batch = {{ballId, normal (Vector2), speed}, ...}.
function clientUI.playImpacts(batch,serial)
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
 -- A mirror Part is unparented: it counts as drawn (today's path keeps its Parent check).
 if strongest>=9 and now-lastPlop>=.13 and contactSource and(contactSource.Parent or(clientUI.mirror~=nil and clientUI.mirror:isMine(contactSource)))then
  lastPlop=now
  local radius=contactSource.Size.X/2
  contact=Vector2.new(contactSource.Position.X,contactSource.Position.Y)-normal*radius
  rendererPresentation.setFieldOwner(true,serial,reduceEffects())
  rendererPresentation.fx:emit("impact",project(contact),radius*viewport.AbsoluteSize.X/(Config.Width+.8),contactSource.Color,contactSource:GetAttribute("Tier"),1,serial,now,normal)
  audio:play(if normal.Y<.78 then "bank"else "land",math.clamp(.82+strongest/100,.9,1.2),math.clamp(strongest/70,.24,.55))
 end
end
table.insert(rendererPresentation.connections,impacts.OnClientEvent:Connect(function(batch,serial,tick)
 if clientUI.mirrorOwns(serial)then return end -- B3: the mirror plays its own impacts
 if not rendererPresentation.canPresent(serial)then return end
 -- S2b: squash and plop when the drawn balls touch (the snapshot clock), not on arrival.
 clientUI.boardNet.schedule(tick,function(late)
 if late>clientUI.boardNet.LateLimit or not rendererPresentation.canPresent(serial)then return end
 clientUI.playImpacts(batch,serial)
 end)
end))
-- B3: the merge juice (blob, burst, score popup, jolt, merge and chain sounds, faces, pet cheer),
-- shared by the server's BoardMerge events on the snapshot clock and the mirror's local merges.
function clientUI.playMerge(position,tier,chain,first,second,id,cleared,serial)
 local now=os.clock()
 mergeBurst=if now-lastMerge<.08 then math.min(mergeBurst+1,2)else 0;lastMerge=now
 clientUI.ballFaces:merged(id,now)
 audio:play(if tier==2 then "merge_bubble"else "merge_jelly",audio:mergePitch(chain,id),.56*.68^mergeBurst)
 clientUI.haptics.merge(tier,chain,cleared) -- a light tick that grows with the tier and the chain (beta only; capped)
 -- G1: every chain step pings (0.09 s guard, was 0.18), one note higher and a little louder.
 if(chain>1 or cleared)and now-lastChainAccent>=.09 then
  lastChainAccent=now;audio:play("merge_chain",audio:mergePitch(chain,id),Audio.chainAccentVolume(chain))
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
 -- G1: the kick is sized for a 420 px board and shrinks with a smaller (phone) one.
 rendererPresentation.jolt.scale=viewport.AbsoluteSize.Y/420
 rendererPresentation.jolt:emit(serial,id,tier,chain,cleared,now)
 -- G1: the new ball lands with a squash that grows with its tier. Under the LCD the
 -- merge blob plays first and hands over when it ends (render loop below).
 if not reduced and not cleared and not lcdEnabled()and viewsById[id]then viewsById[id]:impact(Vector2.yAxis,6+2*tier)end
 -- Big moments reach the resting pet behind the see-through deck.
 if tier>=3 or chain>=3 then roomView:cheerPet("cheer")end
end
table.insert(rendererPresentation.connections,feedback.OnClientEvent:Connect(function(position,tier,chain,first,second,id,cleared,serial,tick,firstId,secondId)
 -- B3: a round the mirror draws played this merge locally; the server's copy is only compared.
 if clientUI.mirrorOwns(serial)then clientUI.mirror:serverMerge(tier,chain,id,cleared,firstId,secondId);return end
 -- B3 code review: after a takeover the server replays merges the mirror already played.
 if clientUI.mirror and clientUI.mirror:alreadyPlayed(serial,firstId,secondId)then return end
 -- v890 QA: confirm (or undo) a predicted merge as soon as the event arrives, not on its tick.
 local predicted=clientUI.ghosts~=nil and serial==board:GetAttribute("ResetId")and clientUI.ghosts:confirm(firstId,secondId,id)
 if not rendererPresentation.canPresent(serial)then return end
 -- S2b: the merge (blob, jolt, sounds, faces, cheer) plays when the snapshot clock
 -- reaches its tick, where the balls visibly meet; the HUD holds its score until then.
 -- Too late (a retransmit): keep the face state, skip the juice.
 clientUI.boardNet.schedule(tick,function(late)
 if clientUI.ghosts then clientUI.ghosts:mergedAway(firstId,secondId)end
 clientUI.netChain=chain
 if clientUI.boardNet.active()then clientUI.netScoreKick()end
 if late>clientUI.boardNet.LateLimit or not rendererPresentation.canPresent(serial)then clientUI.ballFaces:merged(id,os.clock());return end
 local now=os.clock()
 if clientUI.welcomeSpark then clientUI.welcomeSpark(position,tier)end
 if predicted then
  -- The blob, burst, jolt and merge sound played at the prediction: only the score popup
  -- and the chain accent (the server's chain) remain.
  clientUI.ballFaces:merged(id,now)
  if(chain>1 or cleared)and now-lastChainAccent>=.09 then
   lastChainAccent=now;audio:play("merge_chain",audio:mergePitch(chain,id),Audio.chainAccentVolume(chain))
  end
  -- The predicted buzz was a plain merge: a chain climbs and a clear thumps now (the server's chain; capped).
  if chain>1 or cleared then clientUI.haptics.merge(tier,chain,cleared)end
  rendererPresentation.fx:pop(project(position),Config.Tiers[tier].radius*viewport.AbsoluteSize.X/(Config.Width+.8),clientUI.JellyPalette.byTier[tier].body,Config.mergeScore(tier,chain,cleared),now)
  return
 end
 clientUI.playMerge(position,tier,chain,first,second,id,cleared,serial)
 end,{score=Config.mergeScore(tier,chain,cleared)})
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
-- The Vibration row follows the ASMR switch when it arrives or flips (and a pad connecting).
pcall(function()
	local function vibrationRow() picker:setVibration(clientUI.haptics.available(), clientUI.haptics.isEnabled()) end
	require(ReplicatedStorage.Shared.Alive).changed("asmr"):Connect(vibrationRow)
	UserInputService.GamepadConnected:Connect(vibrationRow)
	UserInputService.GamepadDisconnected:Connect(vibrationRow)
end)
board:GetAttributeChangedSignal("GreetingsOff"):Connect(function()picker:setGreetings(board:GetAttribute("GreetingsOff")~=true)end)
-- Toy Shell R1.1: menus follow the equipped deck or the Classic Shell (Settings), and the
-- moving checker rests under the game's own Motion: Low as well as Reduced Motion.
local function syncToyShell()
	Art.setMenuColours(board:GetAttribute("MenuColours"))
	picker:setMenuColours(board:GetAttribute("MenuColours"))
	require(script.DeckKit).setReducedEffects(board:GetAttribute("ReducedEffects")==true)
end
board:GetAttributeChangedSignal("MenuColours"):Connect(syncToyShell)
board:GetAttributeChangedSignal("ReducedEffects"):Connect(syncToyShell)
syncToyShell()
GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(refreshMotion)

local hudQueued = false
-- Perf (v775): the server republishes the overflow pressure and grace (and Welcome
-- telemetry) up to 10 times a second while the pile is near the line. The HUD reads
-- none of them (the danger cues, faces and coach read them every frame), so they no
-- longer queue a full HUD refresh each.
clientUI.hudQuietAttributes={OverflowPressure=true,OverflowGraceLeft=true,WelcomeActiveSeconds=true,WelcomeInputEpoch=true}
board.AttributeChanged:Connect(function(name)
 if rendererPresentation.roundEnd then rendererPresentation.roundEnd:observe()end
 if clientUI.hudQuietAttributes[name] then return end
 -- B3: a lagged server write of a value the mirror serves changes nothing shown (it notifies its own).
 if clientUI.mirror and clientUI.mirror:serves(name)then return end
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
	if clientUI.stats then clientUI.stats.close("forced")end
	if clientUI.names then clientUI.names.close("forced")end
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
	-- QA v685 D2: every deck open lays the deck out again from the current screen size, safe
	-- insets and top-bar keep-out (deferred, so an inset switch made for the round has
	-- landed), and again once the frame after has settled. Nothing is kept from the last open.
	if mode=="Board"then
		task.defer(function()if board:GetAttribute("Mode")=="Board"then layout();updateHud()end end)
		task.delay(.25,function()
			-- Only if the screen or the keep-out moved after the first pass (a late safe-area inset).
			local g=clientUI.deck.geometry;local size=backdrop.AbsoluteSize;local kx,kh=require(script.DeckKit).keepOut()
			if board:GetAttribute("Mode")=="Board"and(not g or(g.phone and(g.W~=size.X or g.H~=size.Y or g.kx~=kx or g.kh~=kh)))then layout();updateHud()end
		end)
	end
end)
board:GetAttributeChangedSignal("ResetId"):Connect(function()
 for source in pairs(eggViews)do removeView(source)end
 for _,source in ipairs(board:GetChildren())do addView(source)end
 if clientUI.mirror then clientUI.mirror:reattach()end
 rendererPresentation.fx:observeDrop(board:GetAttribute("ResetId"),clientUI.attr("Drops")or 0)
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
 local count,serial=clientUI.attr("Drops")or 0,board:GetAttribute("ResetId")
 if clientUI.mirrorOwns(serial)then return end -- B3: the mirror plays its own drops
 if count>0 and clientUI.boardHints then clientUI.boardHints:noteDrop()end
 local accepted=rendererPresentation.fx:observeDrop(serial,count)
 if accepted and rendererPresentation.canPresent(serial)then
  -- S4: a tap already played this drop's sound.
  if not(clientUI.dropIntent and clientUI.dropIntent:consumeTapSound(os.clock()))then audio:play("drop",1,.48)end
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
  -- B3: the mirror lays out its own goal progress; the server's lagged copy changes nothing shown.
  if attribute=="FieldObjective"and clientUI.mirror and clientUI.mirror:serves(attribute)then return end
  clientUI.fieldView=clientUI.FieldQuestText.read(clientUI.boardView,clientUI.fieldCache)
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
	-- Perf (v775): format only when the egg, the wallet or the label text changed,
	-- not a new string every frame.
	local eggGoalCache,nectar=clientUI.eggGoalCache,nurseryState and nurseryState.nectar or 0
	if not eggGoalCache or eggGoalCache.recipe~=recipe or eggGoalCache.nectar~=nectar or eggGoalText.Text~=eggGoalCache.text then
		eggGoalCache={recipe=recipe,nectar=nectar,text=Stars.format("%s\n%d/%d Stars", recipe.name, nectar, recipe.cost)}
		clientUI.eggGoalCache=eggGoalCache;eggGoalText.Text=eggGoalCache.text
	end
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
	local pressure = clientUI.attr("OverflowPressure") or 0
	local graceLeft = clientUI.attr("OverflowGraceLeft") or 0
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
 -- QA 2026-11-13 Q1: the whole deck follows a merge jolt (visual only), and the
 -- board notes (settling, first-drop hint) step with the board.
 do
  local jolt=rendererPresentation.jolt
  clientUI.deck:setShake(if jolt.active and jolt.active.kind=="merge"then jolt.offset else nil,reduced)
  local phase=clientUI.attr("FieldPhase")
  local hintState=clientUI.hintState or {};clientUI.hintState=hintState -- reused, no table per frame
  hintState.presented,hintState.settling=presented,phase=="Settling"and board:GetAttribute("RoundOver")~=true
  hintState.live,hintState.firstRun=canPlay()and not isPickerOpen(),clientUI.boardHints.firstRun(phase,clientUI.attr("Drops"))
  hintState.input,hintState.reduced=clientUI.inputKind(),reduced
  clientUI.boardHints:step(now,hintState)
 end
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
	if clientUI.deck.stepNext then clientUI.deck:stepNext(now,faceMood,ballTheme,clientUI.boardView)end
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
					local born = viewsById[pixelMerges[index].id]
					if born and not reduced then born:impact(Vector2.yAxis, 6 + 2 * pixelMerges[index].tier) end
					table.remove(pixelMerges, index)
				end
			end
			local radius = Config.Tiers[tier].radius * JellyLCD.Width / (Config.Width + 0.8)
			local color = clientUI.JellyPalette.byTier[tier].body
			local center = pixelPoint(Config.launchPosition())
			lcd:drawGuide(aim)
			local held=clientUI.heldFace;held.tier=tier;held.expr,held.dx=clientUI.ballFaces.preview(0,now,faceMood);held.star=clientUI.attr("NextPowerUp")==true;held.mark=nil
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
-- QA Q2.5: alt-tab back with a menu screen open keeps the cursor free and the camera off the mouse.
-- `others`: every screen but the Garden Dash cards (DashClient asks). Where Dash is built (never live) the naming
-- screen and the snack reveal count too, so a race never takes the camera under them.
clientUI.anyModalOpen=function(others)
 return(not others and clientUI.dash~=nil and clientUI.dash:panelOpen())
  or(clientUI.dash~=nil and((clientUI.names~=nil and clientUI.names.isOpen())or(clientUI.snacks~=nil and clientUI.snacks.reveal~=nil and clientUI.snacks.reveal:isOpen())))
  or(clientUI.hub~=nil and clientUI.hub:isOpen())or(clientUI.wardrobe~=nil and clientUI.wardrobe:isOpen())or(clientUI.book~=nil and clientUI.book:isOpen())
  or(clientUI.stats~=nil and(clientUI.stats.isOpen()or clientUI.stats.isBusy()))
  or isPickerOpen()or(journal~=nil and journal.shade.Visible)or(nurseryView~=nil and nurseryView:isOpen())or clientUI.isHueOpen()
  or(gameMenu~=nil and(gameMenu:isOpen()or gameMenu.shade.Visible))or(modal~=nil and modal.Visible)
  or(clientUI.questLog~=nil and clientUI.questLog.visible)
  or(clientUI.bugReport~=nil and clientUI.bugReport:isOpen())
end
-- QA v2 R2.1/R2.2: the same edge takes the one movement lock ("modal"); the hatch reveal,
-- HatchCinematic and the Meet screen live in nurseryView.shade, so they count too. The
-- deck ("deck") and pet focus ("focus") hold it from RoomView.
clientUI.movementLock=require(script.MovementLock).shared()
clientUI.modalCursor=require(script.ModalCursor).new({isOpen=clientUI.anyModalOpen,input=UserInputService,run=RunService,actions=ContextActionService,parent=player:WaitForChild("PlayerGui"),movement=clientUI.movementLock,
 prompts=game:GetService("ProximityPromptService")}) -- not the top-level local: init.client is at the 200-register limit
gui.Destroying:Connect(function()clientUI.modalCursor:destroy()end)
-- Fable R13 (5): the notification rail (the egg ticket with it) is off the screen over any full screen and the capsule
-- shot, beta only (HudChips.hideRail; NotificationRail holds its notices meanwhile).
-- Beta 18: and over every hatch reveal wherever it opened (the Stat Egg over the garden was not a modal): any stage on
-- screen (HudChips.revealUp), or the Stat Egg / arrival hatch host while it is open.
do
 -- One local (init.client is at the 200-register limit): the chip rules, the live stage sets, the on-screen test.
 local R={chips=require(script.HudChips),stages={require(script.HatchItemStage).live,require(script.RevealStage).live},
  onScreen=require(script.CelebrationKit).onScreen}
 require(script.NotificationRail).hider=function()
  local Chips=R.chips
  if not Chips.on()then return false end
  local machine=clientUI.eggMachine
  local reveal=Chips.revealUp(R.stages,R.onScreen)
   or(clientUI.snacks~=nil and clientUI.snacks.reveal~=nil and clientUI.snacks.reveal:isOpen()==true)
   or(clientUI.arrivalHatch~=nil and clientUI.arrivalHatch:isOpen()==true)
  return Chips.hideRail({on=true,modal=clientUI.anyModalOpen()==true,shot=machine~=nil and(machine:shotActive()or machine:cameraHeld()),reveal=reveal})
 end
end
-- Beta 14 W4 world feel (WorldFeelClient): the zoom cap and the walk speed test; nil with the build ceiling off, and
-- with both switches off it writes nothing.
do
 local ok,problem=pcall(function()clientUI.feel=require(script.WorldFeelClient).mount({player=player})end)
 if ok and clientUI.feel then gui.Destroying:Connect(function()clientUI.feel:destroy()end)
 elseif not ok then warn("[Feel] not mounted: "..tostring(problem))end
end
-- Garden Dash (DashClient): nil with the build ceiling off; with the switch off it only watches for the switch.
do
 local ok,problem=pcall(function()
  clientUI.dash=require(script.DashClient).mount({remotes=remotes,roomView=roomView,playerGui=gui.Parent,audio=audio,ambient=clientUI.ambient,reduced=reduceEffects,
   strip=function()return if clientUI.tomorrow then clientUI.tomorrow()else nil end,
   -- Beta 14 F1: a Coming up chip on the Dash results card routes like the deck's (the Dash side wires it).
   -- The card is put away first (DashClient), so the garden step waits for the room through afterGarden.
   stripChip=function(id)
    local step=clientUI.stripStep and clientUI.stripStep(id)
    if not step or not clientUI.afterGarden or clientUI.stripRouting then return false end
    clientUI.afterGarden(step,8)
    return true
   end,
   state=function()return nurseryState end,canRoam=function()return roomView.canRoam()end,
   modalOpen=function()return clientUI.anyModalOpen(true)end,
   -- Beta 12 U5: a racer's pet name for the start-line tags. Names are catalogue piece ids (the board's PetNames
   -- attribute, the owner's own snapshot), never typed text; the species when unnamed.
   appearance=function(petId)return nurseryView.appearanceFor(petId)end, -- the sheets' stage pet (U3, U6)
   petName=function(userId,petId)
    local NameText=require(script.PetNameText)
    if userId==player.UserId then return(NameText.own(nurseryState,petId))end
    local boards=roomView.companions and roomView.companions.boards
    return(NameText.ofBoard(boards and boards:FindFirstChild(tostring(userId)),petId))
   end,
   closeMenus=function()
    clearPlayInputs();picker:close();journal:close();nurseryView:close("hue")
    if gameMenu and gameMenu.shade.Visible and closeMenu then closeMenu()end
    if clientUI.hub and clientUI.hub:isOpen()then clientUI.hub:close("dash")end
    roomView:setMenuOpen(false)
   end})
 end)
 if ok and clientUI.dash then gui.Destroying:Connect(function()clientUI.dash:destroy()end)
 elseif not ok then warn("[Dash] not mounted: "..tostring(problem))end
end
-- Garden finds (FindsClient): nil with the build ceiling off; with the switch off it only watches for the switch. The
-- claim goes only while my pet is out and the garden is free (Room mode, no menu or card, no race seat, no close-up,
-- no petting). clientUI.finds:summary() is what Things to do reads.
do
 local ok,problem=pcall(function()
  local How=require(script.HowItWorks)
  local Confirm=require(script.ConfirmDialog)
  clientUI.finds=require(script.FindsClient).mount({remotes=remotes,audio=audio,player=player,
   reduced=function()return reduceEffects()==true or GuiService.ReducedMotionEnabled end,
   root=function()
    local character=player.Character
    local root=character and character:FindFirstChild("HumanoidRootPart")
    local humanoid=character and character:FindFirstChildOfClass("Humanoid")
    return if root and humanoid and humanoid.Health>0 then root.Position else nil
   end,
   petOut=function()
    local id=board:GetAttribute("CompanionId")
    return roomView.pet~=nil and type(id)=="string"and id~=""
   end,
   free=function()
    return board:GetAttribute("Mode")=="Room"and roomView.mode=="Room"and roomView.target=="Room"and not roomView.busy
     and not roomView.dashHeld and roomView.focusing~=true and roomView.focusTransitioning~=true and roomView.petContactActive~=true
     and(roomView.pet==nil or roomView.pet.petting~=true)and(clientUI.dash==nil or clientUI.dash.seat==nil)
   end,
   busy=function()
    return clientUI.anyModalOpen()==true or How.isOpen()or Confirm.isOpen()or clientUI.arrivalHatch:isOpen()
   end})
 end)
 if ok and clientUI.finds then gui.Destroying:Connect(function()clientUI.finds:destroy()end)
 elseif not ok then warn("[Finds] not mounted: "..tostring(problem))end
end
-- The Hush (HushClient): nil with the build ceiling off. The cave passage's fade and the Hush's own music duck and grade;
-- a door asks only while the garden is free (Room mode, no menu or card, no race seat, no close-up).
do
 local ok,problem=pcall(function()
  clientUI.hush=require(script.HushClient).mount({remotes=remotes,player=player,audio=audio,
   lighting=game:GetService("Lighting"),gui=player:WaitForChild("PlayerGui"),
   character=function()return player.Character end,
   root=function()
    local character=player.Character
    local root=character and character:FindFirstChild("HumanoidRootPart")
    local humanoid=character and character:FindFirstChildOfClass("Humanoid")
    return if root and humanoid and humanoid.Health>0 then root else nil
   end,
   free=function()
    return board:GetAttribute("Mode")=="Room"and roomView.mode=="Room"and roomView.target=="Room"and not roomView.busy
     and not roomView.dashHeld and roomView.focusing~=true and roomView.focusTransitioning~=true
     and(clientUI.dash==nil or clientUI.dash.seat==nil)and clientUI.anyModalOpen()~=true
   end})
 end)
 if ok and clientUI.hush then gui.Destroying:Connect(function()clientUI.hush:destroy()end)
 elseif not ok then warn("[Hush] not mounted: "..tostring(problem))end
end
-- The Sleepy Nest in the garden (NestClient, Onboarding v3 slice D): nil with the build ceiling off; with the switch off
-- it only watches the switch. clientUI.nestPlace is where the Bear's prints end (BearNeeds' needNest reads it), and
-- clientUI.tomorrow is the See you tomorrow strip's model for the results screens (slice E; nil with the nest off).
do
 local ok,problem=pcall(function()
  local Onboard=require(ReplicatedStorage.Shared.Onboard)
  if not Onboard.ceiling()then return end
  local How=require(script.HowItWorks)
  local Confirm=require(script.ConfirmDialog)
  local Strip=require(script.TomorrowStrip)
  local Preview=require(script.EggPreview3D)
  local asked=false
  local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
  local toaster
  clientUI.nest=require(script.NestClient).mount({remotes=remotes,player=player,
   audio={play=function(_,name,speed,volume)
    if clientUI.ambient and clientUI.ambient:has(name)then return clientUI.ambient:play(name,speed,volume)end
    return audio:play(name,speed,volume)
   end},
   reduced=function()return reduceEffects()==true or GuiService.ReducedMotionEnabled end,
   root=function()
    local character=player.Character
    local root=character and character:FindFirstChild("HumanoidRootPart")
    local humanoid=character and character:FindFirstChildOfClass("Humanoid")
    return if root and humanoid and humanoid.Health>0 then root.Position else nil
   end,
   free=function()
    return board:GetAttribute("Mode")=="Room"and roomView.mode=="Room"and roomView.target=="Room"and not roomView.busy
     and not roomView.dashHeld and roomView.focusing~=true and(clientUI.dash==nil or clientUI.dash.seat==nil)
   end,
   busy=function()return clientUI.anyModalOpen()==true or How.isOpen()or Confirm.isOpen()or clientUI.arrivalHatch:isOpen()end,
   compact=function()local camera=workspace.CurrentCamera;return camera~=nil and math.min(camera.ViewportSize.X,camera.ViewportSize.Y)<500 end,
   -- Beta (17) U1: the egg's clock is the rail's status ticket (HudChips: ready > the play date > the clock), not a
   -- chip above the dock, so nothing stacks over "Park full" or Throw bottom right.
   status=function(data)return require(script.NotificationRail).status(script,require(script.NestClient).TicketKey,data)end,
   narrow=function()
    local Chips=require(script.HudChips)
    return Chips.narrow(GuiService.TopbarInset.Width,Chips.NarrowEgg)
   end,
   focus=function()
    return roomView.focusing==true or roomView.focusTransitioning==true or(roomView.greetingCamera~=nil and roomView.greetingCamera~=false)
   end,
   show=function()local things=clientUI.things;return things~=nil and things.show("nest")end,
   -- The egg corner (its own block below): the pill's board host, the "?" card and its first-time pulse.
   gui=function()return player:FindFirstChildOfClass("PlayerGui")end,
   help=function(nest)return clientUI.openNestHelp~=nil and clientUI.openNestHelp(nest)==true end,
   helpPulse=function()return clientUI.nestHelpDue~=nil and clientUI.nestHelpDue()==true end,
   helpPulsed=function()if clientUI.nestHelpSeen then clientUI.nestHelpSeen()end end,
   helpClose=function()if clientUI.closeNestHelp then clientUI.closeNestHelp()end end,
   -- Beta 14 Q2: the need bubble (BubbleHold's state and the pet), so the pill never shares the screen with it.
   bubble=function()
    local hold=clientUI.needBubble
    if not hold then return nil end
    local state=hold:state()
    local pet=roomView.pet
    state.pet=if pet and typeof(pet.origin)=="Vector3"then pet.origin else nil
    return state
   end,
   toast=function(text,stars)
    toaster=toaster or require(script.DeckKit).toaster(player:WaitForChild("PlayerGui"))
    toaster.show(text,stars,"nest:"..text)
   end,
   ground=function(at)
    local skip={}
    for _,other in ipairs(Players:GetPlayers())do if other.Character then table.insert(skip,other.Character)end end
    params.FilterDescendantsInstances=skip
    local hit=workspace:Raycast(at+Vector3.new(0,6,0),Vector3.new(0,-12,0),params)
    return hit and hit.Position.Y
   end,
   measure=function(text,size)return TextService:GetTextSize(text,size,Enum.Font.FredokaOne,Vector2.new(1000,100)).X end,
   meshes=function()
    local copies=Preview.cloneTemplates()
    if not copies and not asked then asked=true;Preview.loadTemplates(function()end)end
    return copies
   end})
  if not clientUI.nest then return end
  clientUI.nestPlace=function()return clientUI.nest:place3D()end
  -- Beta 14 D1: the Hatch eggs screen's quiet napping-egg row. In the garden a tap lays the trail; from the Deck it
  -- leaves first (F1's stripRoute("nest")).
  nurseryView.nest={
   -- The egg corner removes the row (EGG-CORNER-LOOK 4): the list starts at the first egg type.
   row=function()return if Onboard.on("nest")and not Onboard.on("corner")then require(script.NestClient).menuRow(clientUI.nest:summary())else nil end,
   garden=function()return board:GetAttribute("Mode")=="Room"end,
   show=function()
    if board:GetAttribute("Mode")=="Room"then local things=clientUI.things;return things~=nil and things.show("nest")==true end
    return clientUI.stripRoute~=nil and clientUI.stripRoute("nest")==true
   end}
  clientUI.tomorrow=function()
   return Strip.model({on=Onboard.on("nest"),nest=clientUI.nest:summary(),state=nurseryState})
  end
  clientUI.deckResults.tomorrow=clientUI.tomorrow
 end)
 if ok and clientUI.nest then gui.Destroying:Connect(function()clientUI.nest:destroy()end)
 elseif not ok then warn("[Nest] not mounted: "..tostring(problem))end
end
function clientUI.eggCornerMount(Onboard)
 local Corner=require(ReplicatedStorage.Shared.EggCorner)
 local Coach=require(ReplicatedStorage.Shared.CoachMarks)
 local How=require(script.HowItWorks)
 local Haptics=game:GetService("HapticService")
 local function on()return Onboard.on("corner")end
 local function lounge()return workspace:FindFirstChild("EggDropLounge")end
 local function haptic(strength)
  -- The ASMR switch on (beta): through the one vibration module (its cap and the Vibration setting; phones too).
  if clientUI.haptics.switch()then clientUI.haptics.play(if strength=="medium"then "machine_medium"else "machine_light");return end
  -- Gamepads only: Roblox has no phone haptics.
  local pad=Enum.UserInputType.Gamepad1
  if not Haptics:IsVibrationSupported(pad)or not Haptics:IsMotorSupported(pad,Enum.VibrationMotor.Small)then return end
  Haptics:SetMotor(pad,Enum.VibrationMotor.Small,if strength=="medium"then .6 else .3)
  task.delay(if strength=="medium"then .06 else .035,function()pcall(Haptics.SetMotor,Haptics,pad,Enum.VibrationMotor.Small,0)end)
 end
 local machine=require(script.EggMachineClient).new({room=lounge,corner=on,
  warn=function(text)warn(text)end,
  -- The capsule shot (beta 17 U5; CAPSULE-AND-HUD-LOOK 1): its switch, the camera, the HUD, this player's character,
  -- the line checks and the pocket drop in the Hatch eggs preview well.
  capsule=function()return Onboard.on("capsule")end,
  cameraObject=function()return workspace.CurrentCamera end,
  hud=function(visible)clientUI.capsuleHud(visible)end,
  ghost=function(alpha)
   local character=player.Character
   if not character then return end
   for _,part in ipairs(character:GetDescendants())do
    if part:IsA("BasePart")or part:IsA("Decal")then part.LocalTransparencyModifier=alpha end
   end
  end,
  blocked=function(from,to)
   local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
   local skip={}
   for _,other in ipairs(Players:GetPlayers())do if other.Character then table.insert(skip,other.Character)end end
   local room=lounge()
   local found=room and room:FindFirstChild("EggMachine")
   if found then table.insert(skip,found)end
   for _,name in ipairs({"EggDropSleepyNest","EggDropShowMe","EggDropStationAttract"})do local f=workspace:FindFirstChild(name);if f then table.insert(skip,f)end end
   params.FilterDescendantsInstances=skip
   return workspace:Raycast(from,to-from,params)~=nil
  end,
  -- Studio R15: every reveal stage slides with the tucked panel (its cover keeps it over the screen otherwise), and a
  -- Hatch another waiting out the request spacing keeps the camera at Shot B.
  stageHold=function(amount)require(script.HatchItemStage).holdAll(amount)end,
  screens=function()
   local out={}
   if nurseryView and nurseryView.shade then table.insert(out,nurseryView.shade)end
   if clientUI.hueView and clientUI.hueView.shade then table.insert(out,clientUI.hueView.shade)end
   return out
  end,
  againPending=function()return clientUI.hatchFlow~=nil and clientUI.hatchFlow:againPending()==true end,
  pocket=function(kind)
   local egg=nurseryView and nurseryView.egg3D
   if egg and nurseryView:isOpen()then egg:capsule(kind)end
  end,
  reduced=function()return reduceEffects()==true or GuiService.ReducedMotionEnabled end,
  root=function()
   local character=player.Character
   local root=character and character:FindFirstChild("HumanoidRootPart")
   return root and root.Position or nil
  end,
  camera=function()local camera=workspace.CurrentCamera;return camera and camera.CFrame.Position or nil end,
  audio={play=function(_,name,speed,volume)return audio:play(name,speed,volume)end},haptic=haptic,
  -- An armed buy the server refused (Fable R8: the hello nudge, no crank): its intent says Rejected.
  rejected=function(action)
   local intent=({toyBuy=clientUI.toyIntent,hueBuy=clientUI.hueIntent,lookBuy=clientUI.hueIntent,materialBuy=clientUI.materialIntent,
    featureBuy=clientUI.featureIntent})[action]
   return intent~=nil and intent.status=="Rejected"
  end})
 clientUI.eggMachine=machine
 require(script.HatchItemStage).hold=function()return machine:stageAmount()end
 -- The capsule shot: the dock hides while the camera looks at the machine (its own visibility is kept and put back).
 do
  local hidden=nil
  function clientUI.capsuleHud(visible)
   local dock=roomView.controls
   if not dock then return end
   if not visible and hidden==nil then hidden=dock.Visible;dock.Visible=false
   elseif visible and hidden~=nil then dock.Visible=hidden;hidden=nil end
  end
 end
 -- A tap, a click, A, Space or Enter during the shot jumps to the landing (never the first drop of an egg type).
 -- Code review of 071d8a6: the keys are a ContextActionService action bound only while the shot plays (the machine
 -- calls skipInput), sinking them only then, so Space never jumps and chat typing never skips. Taps and clicks the game
 -- or the touch controls already took (gameProcessed: the thumbstick, jump, chat) never skip either.
 local SkipAction="EggDropCapsuleSkip"
 machine.d.skipInput=function(on)
  if on then
   ContextActionService:BindActionAtPriority(SkipAction,function(_,state)
    if state~=Enum.UserInputState.Begin or not machine:shotActive()or UserInputService:GetFocusedTextBox()then
     return Enum.ContextActionResult.Pass
    end
    machine:skipShot()
    return Enum.ContextActionResult.Sink
   end,false,Enum.ContextActionPriority.High.Value+2100,Enum.KeyCode.Space,Enum.KeyCode.Return,Enum.KeyCode.ButtonA)
  else
   ContextActionService:UnbindAction(SkipAction)
  end
 end
 local skipInput=UserInputService.InputBegan:Connect(function(input,gameProcessed)
  if gameProcessed or not machine:shotActive()then return end
  if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then machine:skipShot()end
 end)
 -- The camera is always given back: on respawn too.
 local respawn=player.CharacterAdded:Connect(function()machine:returnCamera(true)end)
 gui.Destroying:Connect(function()skipInput:Disconnect();respawn:Disconnect()end)
 gui.Destroying:Connect(function()machine:destroy()end)
 -- The machine's model (the server's), or nil while the corner is off.
 local function model()local room=lounge();local found=room and room:FindFirstChild("EggMachine");return found end
 -- `Turn`: the open crank, then the screen at .3 (visitEggs checks again then); a second press inside a crank is ignored.
 function clientUI.eggCornerTurn(visit)
  if not on()then return false end
  if machine:openCrank()then
   task.delay(require(script.EggMachineClient).Open.openAt,function()if visit()then clientUI.accepted("confirm")end end)
  elseif visit()then
   -- Review 1: a crank is still turning: the screen opens at once, the press is never eaten.
   clientUI.accepted("confirm")
  end
  return true
 end
 -- A buy press (before the remote): the buy crank. value.id makes a retried send the same press.
 function clientUI.eggPressed(action,value)
  if not on()then return end
  machine:bought(action,type(value)=="table"and value.id or nil)
 end
 -- The egg in the cup fades FadeAfter after the hatch screen that showed its reveal closes (Hatch eggs or the egg page).
 local function watchClose(shade)
  if not shade then return end
  shade:GetPropertyChangedSignal("Visible"):Connect(function()if not shade.Visible then machine:revealClosed()end end)
 end
 watchClose(nurseryView and nurseryView.shade)
 watchClose(clientUI.hueView and clientUI.hueView.shade)
 local snacks=clientUI.snacks
 local intent=snacks and snacks.intent
 if intent and type(intent.send)=="function"then
  local send=intent.send
  intent.send=function(self,action,payload,...)
   if action=="statEggBuy"then
    pcall(clientUI.eggPressed,action,nil)
    -- Studio check R8: the crank turns only for a buy the server saved (its egg drops); a refusal turns nothing.
    local callback=select(1,...)
    if type(callback)=="function"then
     local rest={select(2,...)}
     return send(self,action,payload,function(message)
      if type(message)=="table"and message.status=="Saved"and on()then pcall(machine.confirm,machine,nil)
      elseif type(message)=="table"and message.status~="Retrying"then pcall(machine.refuse,machine)end
      return callback(message)
     end,table.unpack(rest))
    end
   end
   return send(self,action,payload,...)
  end
 end
 -- The Hatch eggs trail's end, in front of the machine.
 function clientUI.eggCornerPlace()
  if not on()then return nil end
  local found=model()
  local y=if found then found:GetPivot().Y else nil
  return Corner.trailEnd(y)
 end
 -- The "?" card: the nest's words, asked again once a second while open.
 function clientUI.openNestHelp(nest)
  if not on()or How.isOpen()then return false end
  return How.open("nest",{list=function()return nest:helpNow()end})
 end
 function clientUI.nestHelpDue()
  return on()and clientUI.coach~=nil and not Coach.has(clientUI.coach.mask,"nestHelp")and Coach.allows("nestHelp")
 end
 function clientUI.nestHelpSeen()if clientUI.coach then clientUI.coach:mark("nestHelp")end end
 -- The Eggs pin and ring: over the machine (top + 1.6, ring r 3.6) while on, back on the old station while off.
 local function attract()
  local entries=clientUI.attract
  if not entries then return end
  local found=on()and model()
  if found then
   local pivot=found:GetPivot()
   local _,size=found:GetBoundingBox()
   local top=(found:GetBoundingBox().Position.Y+size.Y/2)-pivot.Y
   entries:move("Eggs",pivot.Position,{iconHeight=Corner.pinHeight(top),ring=Corner.Ring,arc=Corner.RingArc,facing=Corner.facing()})
  else
   local World=require(ReplicatedStorage.Shared.HollowWorldLayout)
   local station=World.Stations and World.Stations.Eggs
   if station then entries:move("Eggs",station.Position,nil)end
  end
 end
 Onboard.changed("corner"):Connect(function()task.delay(.5,attract)end)
 -- Studio check R10: the empty Sleepy Nest landmark keeps its idle life (moon by the hour, sway, quilt, a "Sleepy Nest"
 -- sign) whenever this player's own nest is not animating it (no egg, or the nest off).
 do
  local NestClient=require(script.NestClient)
  local idle=NestClient.idleMount({reduced=function()return reduceEffects()==true or GuiService.ReducedMotionEnabled end})
  local beat
  beat=RunService.Heartbeat:Connect(function(dt)
   local ok,problem=pcall(function()
    local mine=clientUI.nest
    idle:idleStep(dt,not(mine and mine:animatesLandmark()))
   end)
   -- One warning, then it stops (code review of de31e8a: never a warning a frame).
   if not ok then
    warn("[Nest] idle landmark stopped: "..tostring(problem))
    beat:Disconnect()
    pcall(idle.idleClose,idle)
   end
  end)
  gui.Destroying:Connect(function()beat:Disconnect();pcall(idle.idleClose,idle)end)
 end
 -- Studio check R8: the "?" card goes when the corner turns off (NestClient asks, as it moves the nest).
 function clientUI.closeNestHelp()
  if How.isOpen()and How.openId()=="nest"then How.close("off")end
 end
 local room=lounge()
 if room then room.ChildAdded:Connect(function(child)if child.Name=="EggMachine"then task.defer(attract)end end)end
 attract()
end
-- The egg corner (EGG-CORNER-BUILD-PLAN; EggCorner, EggMachineClient): onboarding v3 places only (beta, Studio). The
-- egg machine's motion, its open and buy cranks and the reveal hold; the Eggs pin and ring follow the machine; the
-- nest's "?" card and its first-time pulse; the Hatch eggs trail's end. With the corner off every hook answers nil and
-- the garden is the one before. Live: the ceiling is false and none of this exists.
do
 local ok,problem=pcall(function()
  local Onboard=require(ReplicatedStorage.Shared.Onboard)
  if not Onboard.ceiling()then return end
  clientUI.eggCornerMount(Onboard)
 end)
 if not ok then warn("[EggCorner] not mounted: "..tostring(problem))end
end
-- Garden life (GardenLife, Alive step 5): nil with the build ceiling off; with the switch off it only watches the switch.
-- Petals, bubbles, birds on the perch AmbientAudio's chirp came from (it sets clientUI.ambient.onChirp while on) and
-- butterflies, and Dewdrops under the lime crowns (a pet this client draws within reach of a fallen one bats it).
-- Parked in a hatch, out of Room mode and in my own race; bubbles stop behind a menu.
do
 local ok,problem=pcall(function()
  local Alive=require(ReplicatedStorage.Shared.Alive)
  if not Alive.ceiling("life")then return end
  -- Beta 14 D2 (GARDEN-LIFE-BUILD-PLAN 2c): my pet's Dewdrop snack, its own Alive `snack` switch (beta and Studio only).
  -- A presentation layer on the server's path (RoomView calls drive after PetFollow.activity and pose after the pet's
  -- update); a throw drops the snack for the session and hands the pet back.
  if Alive.ceiling("snack")then
   local Wind=require(script.Wind)
   local pet=require(script.LifePet).new({
    -- The reason it is busy (SnackWhy), or false.
    busy=function()
     local dash=clientUI.dash
     if clientUI.anyModalOpen()==true then return "a menu"end
     if roomView.focusing==true then return "pet focus"end
     if clientUI.needs~=nil and clientUI.needs.shown==true then return "a need bubble"end
     if clientUI.snacks~=nil and clientUI.snacks.busy==true then return "a Stat snack"end
     if dash~=nil and dash:engaged()==true then return "the race"end
     if require(script.WindClient).hatching()==true then return "a hatch"end
     return false
    end,
    reduced=function()return reduceEffects()==true end,
    owner=function()
     local character=Players.LocalPlayer.Character
     local root=character and character:FindFirstChild("HumanoidRootPart")
     return root and root.Position
    end,
    ownerStill=function()return roomView.ownerStillSince~=nil and workspace:GetServerTimeNow()-roomView.ownerStillSince>=1 end,
    scene=function()return Alive.on("scene")end,
    breath=function(at,now)return Wind.breath(at,now)end,
    life=function()return clientUI.life~=nil and clientUI.life.enabled==true end,
    -- Never two pets on one fruit (Spencer, beta 15): the other owners' pets where the server has them.
    userId=function()return Players.LocalPlayer.UserId end,
    rivals=function()
     local out={}
     for player,entry in pairs(roomView.companions and roomView.companions.active or {})do
      local visual=entry.visual
      if typeof(player)=="Instance"and visual and typeof(visual.origin)=="Vector3"then
       table.insert(out,{ownerId=player.UserId,position=visual.origin})
      end
     end
     return out
    end})
   clientUI.lifePet=pet
   local function guard(method)
    return function(...)
     if clientUI.lifePet~=pet then return end
     local ok,problem=pcall(method,pet,...)
     if not ok then
      clientUI.lifePet=nil;roomView.lifePetDrive=nil;roomView.lifePetPose=nil
      pcall(pet.destroy,pet)
      warn("[LifePet] stopped: "..tostring(problem))
     end
    end
   end
   roomView.lifePetDrive=guard(pet.drive)
   roomView.lifePetPose=guard(pet.pose)
  end
  clientUI.life=require(script.GardenLife).mount({ambient=clientUI.ambient,
   notice=function(loose,now)
    local pet=clientUI.lifePet
    return pet~=nil and pet:notice(loose,now)==true
   end,
   dash=function()return clientUI.dash end,
   pets=function()
    local out={}
    local own=roomView.pet
    if own and typeof(own.origin)=="Vector3"then table.insert(out,own.origin)end
    for _,entry in pairs(roomView.companions and roomView.companions.active or {})do
     local visual=entry.visual
     if visual and typeof(visual.origin)=="Vector3"then table.insert(out,visual.origin)end
    end
    return out
   end,
   modalOpen=function()return clientUI.anyModalOpen()==true end,
   reduced=function()return reduceEffects()==true end,
   -- The Hush (its builder sets clientUI.hush): no leaves, bubbles, birds or fireflies follow the player in.
   quiet=function()
    local hush=clientUI.hush
    return hush~=nil and type(hush.inHush)=="function"and hush:inHush()==true
   end,
   mode=function()return board:GetAttribute("Mode")end})
 end)
 if ok and clientUI.life then gui.Destroying:Connect(function()clientUI.life:destroy()end)
 elseif not ok then warn("[Life] not mounted: "..tostring(problem))end
end
-- The hill at night (WORLD-FINISH-LOOK slice F, HillNightClient): the den's lanterns' night lift and the glow-caps. nil
-- (nothing made) where the `scene` ceiling is closed (live).
do
 local ok,hill=pcall(function()return require(script.HillNightClient).mount()end)
 if ok and hill then gui.Destroying:Connect(function()hill:destroy()end)
 elseif not ok then warn("[HillNight] not mounted: "..tostring(hill))end
end
-- Crunchy toys round the garden (GARDEN-PLAY-BRIEF 2026-11-26 section 2, CrunchToysClient): local only, nil (nothing
-- made) where the Alive `crunch` ceiling is closed (live).
do
 local ok,toys=pcall(function()return require(script.CrunchToysClient).mount({roomView=roomView,ambient=clientUI.ambient,
  mode=function()return board:GetAttribute("Mode")end,reduced=function()return reduceEffects()==true end})end)
 if ok and toys then gui.Destroying:Connect(function()toys:destroy()end)
 elseif not ok then warn("[CrunchToys] not mounted: "..tostring(toys))end
end
-- Drift lanterns over the garden (GARDEN-PLAY-BRIEF 2026-11-26 section 4, DriftLanternsClient): nil where the Alive `air`
-- ceiling is closed (live).
do
 local ok,air=pcall(function()return require(script.DriftLanternsClient).mount({mode=function()return board:GetAttribute("Mode")end,
  reduced=function()return reduceEffects()==true end})end)
 if ok and air then gui.Destroying:Connect(function()air:destroy()end)
 elseif not ok then warn("[DriftLanterns] not mounted: "..tostring(air))end
end
-- Things to do (Shared.Things): nothing at all with the build ceiling off; with the switch off only the switches are
-- watched. clientUI.things is what the Pocket menu's page (MachineHub), the coach's last line (ThingsTips) and the trail
-- (ThingsTrail) ask.
do
 (function()
 local Things=require(ReplicatedStorage.Shared.Things)
 if not Things.ceiling()then return end
 local ok,problem=pcall(function()
  local Dash=require(ReplicatedStorage.Shared.Dash)
  local Course=require(ReplicatedStorage.Shared.DashCourse)
  local Park=require(ReplicatedStorage.Shared.ParkLayout)
  local Coach=require(ReplicatedStorage.Shared.CoachMarks)
  local Copy=require(ReplicatedStorage.Shared.UICopy)
  local Attract=require(script.StationAttract)
  local Tips=require(script.ThingsTips)
  local Finds=require(ReplicatedStorage.Shared.Finds)
  local Guide=require(script.FirstSpendGuide)
  local How=require(script.HowItWorks)
  local Rail=require(script.NotificationRail)
  local Confirm=require(script.ConfirmDialog)
  local things={}
  local function rootPosition()
   local character=player.Character
   local root=character and character:FindFirstChild("HumanoidRootPart")
   local humanoid=character and character:FindFirstChildOfClass("Humanoid")
   return if root and humanoid and humanoid.Health>0 then root.Position else nil
  end
  local function dashNow()return if Dash.on()and clientUI.dash then clientUI.dash:summary()else nil end
  -- The Play Den while it is open (Den_open) and its layout resolved, else nil.
  local PlayDen=require(ReplicatedStorage.Shared.PlayDen)
  local DenLayout=require(ReplicatedStorage.Shared.DenLayout)
  local function denNow()return if PlayDen.isOpen()then DenLayout.current()else nil end
  local function findsNow()return if Finds.on()and clientUI.finds then clientUI.finds:summary()else nil end
  -- The waiting pad, where the race's prompt is: the same numbers the gate is built from.
  local function dashGate()
   local pad=Course.Pad
   return Vector3.new(pad.x/100,pad.y/100,pad.z/100)
  end
  local function parkGate(from)
   if not Attract.parkAnchor()then return nil end
   local best,far=nil,math.huge
   for _,site in ipairs(Park.Sites)do
    for _,gateway in ipairs(site.Gateways)do
     local distance=(gateway.position-from).Magnitude
     if distance<far then best,far=gateway.position,distance end
    end
   end
   return best
  end
  local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
  local trail=require(script.ThingsTrail).new({world=workspace,root=rootPosition,reduced=function()return reduceEffects()==true or GuiService.ReducedMotionEnabled end,
   free=function()
    return Things.on()and board:GetAttribute("Mode")=="Room"and roomView.mode=="Room"and roomView.target=="Room"and not roomView.busy
     and not roomView.dashHeld and(clientUI.dash==nil or clientUI.dash.seat==nil or clientUI.dash.seat.phase=="gather")
   end,
   busy=function()
    return clientUI.anyModalOpen()==true or How.isOpen()or Confirm.isOpen()or roomView.focusing==true or clientUI.arrivalHatch:isOpen()
   end,
   ground=function(at)
    local skip={}
    for _,other in ipairs(Players:GetPlayers())do if other.Character then table.insert(skip,other.Character)end end
    params.FilterDescendantsInstances=skip
    local hit=workspace:Raycast(at+Vector3.new(0,2.5,0),Vector3.new(0,-6,0),params)
    return hit and hit.Position.Y
   end})
  -- The page (MachineHub's callbacks.things) ---------------------------------------------------------------------
  things.on=Things.on
  function things.new()return dashNow()~=nil and not Coach.has(clientUI.coach.mask,"dashSeen")end
  function things.context()
   local state=nurseryState or {}
   local finds=findsNow()
   if finds then
    local saved=type(state.finds)=="table"and state.finds or {}
    finds={waiting=finds.waiting,count=tonumber(saved.count)or 0,limit=tonumber(saved.limit)or Finds.DailyLimit}
   end
   return{den=denNow()~=nil,park=Attract.parkAnchor()~=nil,playDate=state.playDate,finds=finds,dash=dashNow(),prizes=Dash.prizes(),saved=state.dash,new=things.new()}
  end
  function things.seen(id)
   if id=="dash"and Things.on()and not Coach.has(clientUI.coach.mask,"dashSeen")then clientUI.coach:mark("dashSeen")end
  end
  function things.help(id)return How.open(id)end
  function things.show(id)
   local from=Things.on()and rootPosition()
   if not from then return false end
   if id=="park"or id=="parkInvite"then return trail:start({position=parkGate(from),name=Copy.get("park.name")})end
   if id=="nest"then
    local at=clientUI.nestPlace and clientUI.nestPlace()
    -- Beta 14 Q1: the pin says Hatch! once the egg is ready (asked each step).
    local function name()
     local summary=clientUI.nest and clientUI.nest:summary()
     return Copy.get(if summary and summary.ready then "onb3.nest.pinReady"else "onb3.nest.title")
    end
    -- The Sleepy Nest landmark: its pin stands 8.2 over the bowl's centre (NEST-LANDMARK-LOOK 5); the prints still end at
    -- the prompt point.
    local pinAt=clientUI.nest and clientUI.nest:pinAt()
    return at~=nil and trail:start({position=at,name=name,pinAt=pinAt})
   end
   if id=="finds"or id=="findsIntro"then
    local finds=findsNow()
    if not(finds and finds.nearest)then return false end
    return trail:start({position=finds.nearest,name=Copy.get("finds.name")})
   end
   local den=denNow()
   if id=="den"then return den~=nil and trail:start({position=den.pin,name=Copy.get("things.den.name")})end
   local race=dashNow()
   if race==nil then return false end
   -- The Play Den open: the race is picked at its gate, so Show me leads there, or to the meadow pad while one gathers.
   if den and race.phase~="gather"then
    local at=DenLayout.prompts(den).gate
    if at then return trail:start({position=Vector3.new(at.X,den.floorY,at.Z),name=Copy.get("dash.title")})end
   end
   return trail:start({position=dashGate(),name=Copy.get("dash.title")})

  end
  function things.act(id)
   if not Things.on()or not closeMenu then return false end
   -- Nothing waiting: no trail to lay, so the page stays.
   if id=="finds"then local finds=findsNow();if not(finds and finds.nearest)then return false end end
   closeMenu()
   if id~="deck"then things.show(id);return true end
   -- The Deck: as its own button in the garden (a race seat is asked about first).
   local function play()roomView:requestSwitch(function()cancelHatchNavigation();request:FireServer("mode","Board")end)end
   if not(clientUI.dash and clientUI.dash:askLeave(play))then play()end
   return true
  end
  -- The tips (CoachCards options.things) -------------------------------------------------------------------------
  local function gate(roomFor)
   local ctx=clientUI.coach.stepCtx or {}
   local pet=roomView.shownPet
   local actor=if pet and roomView.garden then roomView.garden:renderActor(player.UserId,pet.id,player.Character)else nil
   return{on=Things.tips(),mode=board:GetAttribute("Mode"),canRoam=roomView.canRoam(),revealPending=clientUI.coach.revealPending==true,
    modal=clientUI.anyModalOpen()==true or(clientUI.names~=nil and clientUI.names.isOpen())or clientUI.deckResults.visible==true,
    hatch=clientUI.arrivalHatch:isOpen()or(clientUI.snacks~=nil and clientUI.snacks.reveal~=nil and clientUI.snacks.reveal:isOpen()),
    card=How.isOpen()or Confirm.isOpen(),tour=clientUI.coach.tourOpen==true or clientUI.coach.replaying==true,
    greeting=roomView.focusing==true or roomView.greetingCamera~=nil and roomView.greetingCamera~=false or roomView.focusTransitioning==true,
    engaged=clientUI.dash~=nil and clientUI.dash:engaged(),action=actor and actor.action,parkPending=board:GetAttribute("ParkGamesPending"),
    care=actor~=nil and(actor.care~=nil or actor.mode=="Carried"or actor.mode=="Docked"),
    petting=roomView.petContactActive==true or(roomView.pet~=nil and roomView.pet.petting==true),
    purchase=next(clientUI.storeView.prompted)~=nil or starsPurchasePending(),
    windowActive=ctx.windowActive,awayFor=ctx.awayFor,idleFor=ctx.idleFor,roomFor=roomFor,railEmpty=Rail.empty()}
  end
  local nextLook=0
  function things.due(ctx)
   -- Four looks a second, and none at all unless the tips are on.
   if os.clock()<nextLook then return nil end
   nextLook=os.clock()+.25
   local state=nurseryState
   if not Things.tips()or type(state)~="table"then return nil end
   local dash=dashNow()
   ctx.firstEgg=Guide.stage(state,{eligible=true})=="done"and clientUI.firstSpend.flight==nil
   ctx.dashOn,ctx.raced=dash~=nil,dash~=nil and dash.raced
   ctx.playDates=if type(state.playDate)=="table"then state.playDate.count else 0
   ctx.returning,ctx.gate=things.returning,gate(ctx.roomFor)
   local finds=findsNow()
   ctx.findsNear=finds~=nil and finds.distance~=nil and finds.distance<=Finds.Notice
   return Tips.due(ctx)
  end
  function things.blocked(roomFor,started)return Tips.blocked(gate(roomFor),started)end
  -- Beta 12 S2: the tip chime as a tip lands on the rail (silent until it has a sound; never in a round, race or hatch).
  local chime=require(script.TipChime).new({audio=audio,busy=function()
   return{round=board:GetAttribute("Mode")=="Board",race=clientUI.dash~=nil and clientUI.dash:held()==true,
    hatch=clientUI.arrivalHatch:isOpen()or(clientUI.snacks~=nil and clientUI.snacks.reveal~=nil and clientUI.snacks.reveal:isOpen())}
  end})
  function things.shown()chime.ring()end
  local function firstReady(state)
   if things.returning==nil and type(state)=="table"and state.status=="Ready"then things.returning=Tips.returning(state)end
  end
  firstReady(nurseryState)
  local stopSnapshot=clientUI.ownerSnapshot.subscribe(firstReady)
  clientUI.things=things
  gameMenu.callbacks.things=things
  clientUI.coach.options.things=things
  clientUI.attract.options.single=Things.on
  clientUI.attract.options.quiet=function()return clientUI.coach.garden~=nil end
  -- Onboarding v3 slices A and B (BearNeeds): follow the Bear and the need bubbles. Nothing with the build ceiling off;
  -- with both switches off a look twice a second and no bubble (the tour, the pill and the tips stay exactly as before).
  local okNeeds,needsProblem=pcall(function()
   local Onboard=require(ReplicatedStorage.Shared.Onboard)
   if not Onboard.ceiling()then return end
   local Needs=require(script.BearNeeds)
   local function petName()local shown=roomView.shownPet;local pet=shown and Pets.byId[shown.id];return pet and pet.name or "Bear"end
   local function petPart()
    local pet=roomView.pet;local model=pet and not pet.destroyed and pet.model
    if not(model and model.Parent)then return nil end
    return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart",true)
   end
   local function nestAt()local f=clientUI.nestPlace;local at=type(f)=="function"and f()or nil;return if typeof(at)=="Vector3"then at else nil end
   local needs
   -- The bubble's BillboardGui is made the first time a bubble shows.
   -- Beta 14 Q2 (BubbleHold): the napping egg's beat holds the bubble back; without a nest, exactly as before.
   local bubble=require(script.BubbleHold).new(function()
    return require(script.NeedBubble).new({parent=player:WaitForChild("PlayerGui"),adornee=petPart,
     reduced=function()return reduceEffects()==true or GuiService.ReducedMotionEnabled end,
     keyHint=function()return Needs.keyHint(clientUI.inputKind())end,
     onTap=function()if needs then needs:tap()end end})
   end,function()local nest=clientUI.nest;return nest~=nil and nest:holdsBubble()==true end)
   clientUI.needBubble=bubble
   -- Studio QA: a tap on the Bear does the open need's action too; its own key (E / ButtonX) keeps petting.
   local interact=roomView.interactPet
   local petKeyAt=-math.huge
   local petKeys=UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode==Enum.KeyCode.E or input.KeyCode==Enum.KeyCode.ButtonX then petKeyAt=os.clock()end
   end)
   needs=Needs.new({bubble=bubble,clock=os.clock,state=function()return nurseryState end,owned=function()return board:GetAttribute("OwnedPets")or 0 end,
    mask=function()return clientUI.coach.mask end,mark=function(id)clientUI.coach:mark(id)end,finishIntro=function()clientUI.coach:finishGarden()end,
    follow=function()return Onboard.sessionFollow()end,needs=function()return Onboard.on("needs")end,returning=function()return things.returning==true end,
    nestFirst=function()return Onboard.on("nestfirst")and Onboard.on("needs")and Onboard.on("nest")end, -- the First Hatch
    -- Things to do itself, not its tips switch (with tips off the Bear would never start, nor the garden step's clock).
    gate=function()local since=clientUI.coach.roomSince;return Needs.gate(gate(if since then os.clock()-since else 0),Things.on())end,
    greeting=function()return roomView.focusing==true end,inPark=function()return Attract.parkMember(rootPosition())end,
    nest=function()return nestAt()~=nil end,park=function()return Attract.parkAnchor()~=nil end,
    prompt=function()return roomView:stationInReach()==true end,
    place=function(where)
     if where=="Eggs"then
      local machine=clientUI.eggCornerPlace and clientUI.eggCornerPlace()
      if machine then return machine,Copy.get("r5.station.Eggs.name")end
      local entry=clientUI.attract.stations.Eggs;return entry and entry.base,Copy.get("r5.station.Eggs.name")
     end
     if where=="Park"then local from=rootPosition();return from and parkGate(from),Copy.get("park.name")end
     if where=="Nest"then return nestAt(),Copy.get("onb3.nest.title")end
     return nil
    end,
    trail=function(target)return trail:start(target)end,trailActive=function()return trail:active()end,trailTarget=function()return trail.target end,
    sayHi=function()return interact(roomView)end,playDeck=function()return things.act("deck")end,
    quiet=function(on)if clientUI.firstSpend then clientUI.firstSpend:setQuiet(on)end end,
    chirp=function()local shown=roomView.shownPet;if shown and shown.cue then audio:play(shown.cue,1.1,.3)end end,
    react=function(id)if id=="needHi"or id=="needPark"then roomView:cheerPet("cheer")end end})
   local due=things.due
   local intent=roomView.petContactIntent
   local saved=intent.d.saved
   local beat,nextLook=nil,0
   -- Gave up: the garden step is marked, the pill, the station glow and the park line are as before.
   local function abandon(why)
    warn("[Onboard] needs: "..tostring(why))
    if beat then beat:Disconnect()end
    needs:abandon();bubble:destroy()
    clientUI.attract.options.focus=nil;clientUI.attract.options.tip=nil;clientUI.attract.options.tipShown=nil
    things.due=due
    roomView.interactPet=interact;petKeys:Disconnect();ContextActionService:UnbindAction("EggDropNeedBubble")
   end
   beat=RunService.Heartbeat:Connect(function(dt)
    -- Both switches off and nothing started: look twice a second, nothing else.
    if not needs.ready then
     if os.clock()<nextLook then return end
     if not Onboard.on("follow")and not Onboard.on("needs")then nextLook=os.clock()+.5;return end
    end
    local good,why=pcall(needs.step,needs,os.clock(),dt)
    if not good then abandon(why)end
   end)
   gui.Destroying:Connect(function()beat:Disconnect();petKeys:Disconnect();bubble:destroy()end)
   -- Mounted: only now does the rest of the game lean on it.
   intent.d.saved=function(...)needs:saidHi();return saved(...)end
   -- The park line gives way to need 5 (a new player this session only); no rail line while the Bear's prints run.
   function things.due(ctx)
    if needs.follow and trail:active()then return nil end
    ctx.needs=needs:replacesParkLine()
    return due(ctx)
   end
   -- Station label tips: once each, their own bits, only for a session that follows the Bear.
   clientUI.attract.options.tip=function(id)
    local bit=Tips.stationTip(id,{follow=needs.follow,mask=clientUI.coach.mask,seen=clientUI.coach.seen,totalWins=clientUI.coach.totalWins,
     owned=board:GetAttribute("OwnedPets")or 0})
    if not bit or not Coach.allows(bit)then return nil end
    return Copy.get(Tips.TipCopy[bit],{pet=petName()})
   end
   clientUI.attract.options.tipShown=function(id)local bit=Tips.TipBits[id];if bit then clientUI.coach:mark(bit)end end
   clientUI.attract.options.focus=function()return needs:focus()end
   function roomView.interactPet(view,...)
    if os.clock()-petKeyAt>.3 and needs:petTap("tap")then return true end
    return interact(view,...)
   end
   -- The bubble's own key (Needs.Keys): G or L2, unused elsewhere in the garden; passed on while no bubble shows.
   ContextActionService:BindActionAtPriority("EggDropNeedBubble",function(_,state)
    if state~=Enum.UserInputState.Begin or not needs.shown then return Enum.ContextActionResult.Pass end
    return if needs:key()then Enum.ContextActionResult.Sink else Enum.ContextActionResult.Pass
   end,false,Enum.ContextActionPriority.Medium.Value,Enum.KeyCode.G,Enum.KeyCode.ButtonL2)
   clientUI.needs=needs
   clientUI.coach.options.follow=function()return Onboard.sessionFollow()end
   -- Live growth cuts on the beta: with the need bubbles on, the needHi bubble is the one hello prompt (no say-hi line)
   -- and the paw prints lead to the pet while it asks (the Bear's own prints to the machine start after it).
   clientUI.coach.options.bubbles=function()return Onboard.on("needs")end
  end)
  if not okNeeds then warn("[Onboard] not mounted: "..tostring(needsProblem))end
  -- Twice a second while on: the race's station follows the live gate, and a race joined clears the New dot.
  local running=0
  local function sync()
   running+=1
   local mine=running
   if not Things.on()then
    trail:stop("off")
    clientUI.attract:extra("Dash",nil)
    return
   end
   task.spawn(function()
    while mine==running and Things.on()do
     local good,why=pcall(function()
      local dash=dashNow()
      clientUI.attract:extra("Dash",if dash then dashGate()else nil,dash~=nil and(dash.raced or Coach.has(clientUI.coach.mask,"dashSeen")))
      if clientUI.dash and clientUI.dash.seat then things.seen("dash")end
     end)
     if not good then warn("[Things] "..tostring(why));return end
     task.wait(.5)
    end
   end)
  end
  local link=Things.changed("page"):Connect(sync)
  sync()
  gui.Destroying:Connect(function()running+=1;link:Disconnect();stopSnapshot();trail:destroy()end)
 end)
 if not ok then warn("[Things] not mounted: "..tostring(problem))end
 end)()
end
-- The Play Den (Shared.PlayDen, PLAY-DEN-BUILD-PLAN; the room, step B): nothing at all with the build ceiling off; it follows
-- Den_open (the room really open). The gate, the Deck table and the notice board's prompts.
do
 local ok,problem=pcall(function()
  local Things=require(ReplicatedStorage.Shared.Things)
  clientUI.den=require(script.DenClient).mount({
   dash=function()return clientUI.dash end,
   -- The table: exactly as the Deck button (RoomView runs it through requestSwitch, never mid-switch or under an overlay).
   deck=function()if not roomView.busy and not clientUI.roomOverlayOpen()then roomView:requestSwitch(clientUI.playDeck)end end,
   things=function()return clientUI.openThings()end,
   thingsOn=function()return Things.on()end,
   free=function()
    return board:GetAttribute("Mode")=="Room"and roomView.mode=="Room"and roomView.target=="Room"and not roomView.busy
     and roomView.canRoam()==true and clientUI.anyModalOpen()~=true
   end})
  if clientUI.den then gui.Destroying:Connect(function()clientUI.den:destroy()end)end
  roomView.den=clientUI.den -- its prompts count as a station in reach (the pet's E steps aside)
 end)
 if not ok then warn("[Den] not mounted: "..tostring(problem))end
end
layout()
updateHud()
roomView:startPresentation(board:GetAttribute("Mode"))
-- Launch candidate: warm the Deck style art and the 3D preview folders in the background,
-- once the garden has loaded (StylePreload waits for it; small batches, low priority).
require(script.StylePreload).start()
-- v890 QA: the first hatch has its egg meshes, split shells and egg textures ready.
task.defer(function()pcall(require(script.HatchDisplayScene).prewarm)end)
clientUI.ambient:setRound(board:GetAttribute("Mode")=="Board")
