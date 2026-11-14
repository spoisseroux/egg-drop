local Stars=require(script.Parent.StarText)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService=game:GetService("TextService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Art = require(script.Parent.DeckArt)
local Portrait = require(script.Parent.PetPortrait)
local HatchCinematic = require(script.Parent.HatchCinematic)
local RevealStage = require(script.Parent.RevealStage)
local Pets = require(ReplicatedStorage.Shared.PetCatalog)
local Catalog = require(ReplicatedStorage.Shared.EggCatalog)
local EggArt = require(script.Parent.EggArt)
local HueCatalog=require(ReplicatedStorage.Shared.HueCatalog)
local OddsText=require(ReplicatedStorage.Shared.OddsText)
local MaterialCatalog=require(ReplicatedStorage.Shared.MaterialCatalog)
local JarArt=require(script.Parent.HueJarArt)
local ToyCatalog=require(ReplicatedStorage.Shared.ToyCatalog);local FeatureCatalog=require(ReplicatedStorage.Shared.FeatureCatalog)
local ShelfEffects=require(script.Parent.EggShelfEffects)
local Kit=require(script.Parent.DeckKit)
local UICopy=require(ReplicatedStorage.Shared.UICopy)
local EggPreview=require(script.Parent.EggPreview3D)
local Peek=require(script.Parent.PetPeek)
local FeatureFlags=require(ReplicatedStorage.Shared.FeatureFlags)
local NextItem=require(script.Parent.NextItemText)
local C=require(script.Parent.CelebrationKit)
local HintGlyphs=require(script.Parent.HintGlyphs)
-- QA v2 (R1/R3 re-cut): the stamp card and the daily stamp button moved from Hatch eggs
-- to Quests (QuestLog, R3), where the daily things live together. Hatch eggs keeps no
-- daily state; `send("daily", day)` stays the server action the quest screen sends.
-- v1 sells item eggs only; the Companion Egg is retired (one pet, Zivvi). The Feature
-- Egg is hidden with the Features tab (Shared.FeatureFlags); a pending feature hatch
-- still opens through "Open saved feature".
local liveOrder={"toy","material","hue"}
if FeatureFlags.Features then table.insert(liveOrder,2,"feature")end
local function shopRecipe(id)
 if id=="hue"then return {id="hue",name="Hue Egg",cost=HueCatalog.Cost}end
 if id=="toy"then return {id="toy",name="Toy Egg",cost=ToyCatalog.Cost}end
 if id=="feature"then return {id="feature",name="Feature Egg",cost=FeatureCatalog.Cost}end
 if id=="material"then return {id="material",name="Material Egg",cost=MaterialCatalog.Cost}end
 local source=Catalog.ById[id]or Catalog.ById.meadow
 return {id=source.id,name=if id=="meadow"then "Companion Egg"else source.name,cost=source.cost}
end

local SaveNotice=require(script.Parent.SaveNotice)
local View = {}
View.__index = View

local function frame(parent, name, color, position, size, z)
	return Art.frame(parent, name, color, position, size, z or 23)
end

local function label(parent, name, content, position, size, color, maximum)
	local node = Art.text(parent, name, content, position,size,if color==Art.Amber then "reward"else color or "text",maximum or 14,
		Art.Font.Body)
	Art.fitText(node, maximum or 14, 10, 4, true)
	return node
end

local function button(parent, name, content, position, size, color, z)
	local node = Instance.new("TextButton")
	node.Name, node.Text, node.Position, node.Size = name, content, position, size
	node.BackgroundColor3 = if type(color)=="string"then Art.paletteColor(color)else color or Art.Raised
	node.TextColor3 = if color == Art.Amber or color == Art.Leaf then Art.Ink else Art.Silver
	node.Font, node.TextSize, node.ZIndex = Art.Font.Action, 14, z or 24
	node.BorderSizePixel, node.Parent = 0, parent
	if type(color)=="string"then Art.bind(node,{BackgroundColor3=color})elseif not color then Art.bind(node,{BackgroundColor3="raised"})end
 Art.bind(node,{TextColor3=if color==Art.Amber or color==Art.Leaf then "ink"else "text"})
 Art.button(node, 10)
	Art.fitText(node, 14, 10, 8, true)
	return node
end

local function eggGraphic(parent, recipeId, color, y)
	local scene = frame(parent, "EggStand", "ink", UDim2.fromOffset(0, y), UDim2.new(1, -5, 0, 112))
	Art.corner(scene, 14)
	Art.shade(scene, 1.1, 0.82)
	local halo = frame(scene, "WarmLight", color, UDim2.new(0.5, -42, 0.5, -42), UDim2.fromOffset(84, 84))
	halo.BackgroundTransparency = 0.91
	Art.corner(halo, 1000)
	Art.stroke(halo, color, 0.72, 2)
	local plinth = frame(scene, "Stand", Art.Canopy, UDim2.new(0.5, -54, 0.5, 25), UDim2.fromOffset(108, 19))
	Art.corner(plinth, 1000)
	Art.stroke(plinth, Art.Leaf, 0.48, 2)
	for side = -1, 1, 2 do
		Art.leaf(scene, "Leaf", UDim2.new(0.5, side * 35 - 8, 0.5, 9),
			UDim2.fromOffset(14, 31), Art.Leaf, side * 48)
	end
	EggArt.create(scene, recipeId, UDim2.new(0.5, -32, 0.5, -44), UDim2.fromOffset(64, 82), scene.ZIndex + 2)
end

function View.new(parent, audio, reduceEffects, sendCommand)
	local shade = frame(parent, "EggHatchView", "ink", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 20)
	shade.BackgroundTransparency, shade.Active, shade.Visible = 1, true, false
	local card = frame(shade, "Card", "panel", UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(560, 540), 21)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	Art.panel(card, 16, "accent")
	local heading = label(card, "Heading", "Hatch eggs", UDim2.fromOffset(12, 6), UDim2.new(1, -148, 0, 24), "text", 20)
	heading.Font = Art.Font.Heading
	-- QA v2: the card's old Stars chip is gone. The shared header's wallet (WalletStar) is
	-- the one Stars counter on Hatch eggs; the result card never showed it.
	local note = label(card, "Notice", "Earn Stars. Choose an egg for your pet.", UDim2.fromOffset(12, 29),
		UDim2.new(1, -24, 0, 16), "muted", 11)
	local body = Instance.new("ScrollingFrame")
	body.Name, body.Position, body.Size = "Body", UDim2.fromOffset(12, 48), UDim2.new(1, -24, 1, -110)
	body.BackgroundTransparency, body.BorderSizePixel, body.ZIndex = 1, 0, 22
	body.ClipsDescendants=true
	body.ScrollBarThickness=4;Art.bind(body,{ScrollBarImageColor3="accent"})
	body.ScrollingDirection, body.ElasticBehavior = Enum.ScrollingDirection.Y, Enum.ElasticBehavior.Never
	body.Parent = card
	local close = button(card, "Close", "×", UDim2.new(0, 12, 1, -56), UDim2.new(0.30, -18, 0, 44), "raised", 60)
	Art.bareClose(close)
	local action = button(card, "Action", "Hatch", UDim2.new(0.30, 2, 1, -56), UDim2.new(0.70, -14, 0, 44), "accent", 60)
	local meet = button(card, "Meet", "Meet friend", UDim2.new(0, 12, 1, -56), UDim2.new(0.50, -18, 0, 44), "accent", 60)
	meet.Visible = false
	-- Shown only once a Robux store page is attached; the header owns its place.
	local getStars = Instance.new("TextButton")
	getStars.Name, getStars.Text, getStars.Size, getStars.ZIndex, getStars.BorderSizePixel = "GetStars", "Get Stars", UDim2.fromOffset(100, 44), 60, 0
	getStars.BackgroundColor3, getStars.TextColor3, getStars.Visible = Art.Raised, Art.Silver, false
	getStars.Parent = card
	Art.bind(getStars, { BackgroundColor3 = "raised", TextColor3 = "text" })
	Art.button(getStars, 10)
	Art.type(getStars, "Action", true)
	local revealHost = frame(card, "RevealHost", "inset", UDim2.fromOffset(10, 10), UDim2.new(1, -20, 1, -80), 40)
	revealHost.Visible = false
	Art.corner(revealHost, 14)
	local self = setmetatable({
		shade = shade, card = card, body = body, heading = heading, note = note,
		closeButton = close, action = action, meetButton = meet, getStars = getStars, revealHost = revealHost, audio = audio,
		reduceEffects = reduceEffects, sendCommand = sendCommand, selected = liveOrder[1], state = {}, pending = false,
		intentToken = 0, presentationGeneration = 0,
	}, View)
 self.shelfEffects=ShelfEffects.new(shade,{audio=audio,reduceEffects=reduceEffects,owns=function()return shade.Visible and not self:isStoreOpen() and not self.state.lastHatch and (not audio or audio.deviceActive~=false)end})
	self.cinematic = HatchCinematic.new(revealHost, audio, reduceEffects, function()
		return shade.Visible and (not self.ownsPresentation or self.ownsPresentation())
	end)
	-- Full-screen reveal (UI-SPEC-REDESIGN-CELEBRATIONS 1): the egg beats play in
	-- the card, then RevealStage covers the card and owns Meet / Play again.
	-- `revealHost`, `meetButton` and `action` keep their roles underneath.
	self.stageLayer = frame(shade, "RevealLayer", "ink", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 70)
	self.stageLayer.BackgroundTransparency, self.stageLayer.Visible = 1, false
	-- QA v2 R1.2 / R1.5: the stage covers the whole screen, under the Roblox top bar too
	-- (the menu gui is inset, so a 1x1-scale layer stopped short of the edges).
	Kit.coverScreen(self.stageLayer)
	-- QA v2 R1.3: the egg beats before the hand-off play on the same full-screen black as
	-- the stage, so no card-sized rect shows between the deck and the reveal. In result
	-- mode the card and the cinematic draw no panel of their own.
	self.revealBackdrop = Kit.frame(shade, "RevealBackdrop", nil, UDim2.new(), UDim2.fromScale(1, 1))
	self.revealBackdrop.ZIndex = shade.ZIndex
	self.revealBackdrop.BackgroundColor3, self.revealBackdrop.BackgroundTransparency = C.Stage, 0
	self.revealBackdrop.Active, self.revealBackdrop.Visible = true, false
	Kit.coverScreen(self.revealBackdrop)
	self.cinematic:setBleed(true)
	-- QA v2 (R2.5 slice): the footer legend follows the last input.
	self.inputLink = UserInputService.LastInputTypeChanged:Connect(function()
		if self.shopRoot and self.hintRow and View.inputKind() ~= self.hintKind then self:paintHints() end
	end)
	shade.Destroying:Connect(function() if self.inputLink then self.inputLink:Disconnect(); self.inputLink = nil end end)
	self.cinematic.stageHandoff = function(info) return self:showRevealStage(info) end
	self.cinematic.stageClear = function() self:hideRevealStage() end
	Art.watchTextPreference(shade,function()return shade.Visible end,function()
		self:layout()
		if self.state.lastHatch and self.cinematic.result then
			-- Preferred text can change native leading without changing the stage size.
			self.cinematic:layout()
			self:layout()
		end
	end)
	shade:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:layout() end)
	body:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if shade.Visible then self:renderBody() end
	end)
	self:layout()
	close.Activated:Connect(function() self:close("close") end)
	getStars.Activated:Connect(function() self:openStore() end)
	meet.Activated:Connect(function() self:chooseResult("meet") end)
	action.Activated:Connect(function() self:actPrimary() end)
	return self
end

-- The one primary action: Hatch (or open a saved receipt) from the list, Play again on a result.
function View:actPrimary()
		if not self.shade.Visible or self.pending or not self.action.Interactable then return end
		local current = self.state
		if current.lastHatch then
			self:chooseResult(View.secondaryIntent(current.lastHatch))
		elseif current.pendingHueResult then
            if self.onOpenHue then self.onOpenHue(false)end
        elseif current.pendingToyResult then
            if self.onOpenToy then self.onOpenToy(false)end
        elseif current.pendingFeatureResult then
            if self.onOpenFeature then self.onOpenFeature(false)end
        elseif current.pendingMaterialResult then
            if self.onOpenMaterial then self.onOpenMaterial(false)end
        elseif (current.nectar or 0) < shopRecipe(self.selected).cost then
			self:close("earn")
		else
			if self.egg3D then self.egg3D:hatch()end
			-- QA v2 R1.8: the pet peeking into the egg preview gets excited (a hop and a cheer).
			Peek.hop()
			if self.selected=="toy"then if self.onOpenToy then self.onOpenToy(true)end elseif self.selected=="feature"then if self.onOpenFeature then self.onOpenFeature(true)end elseif self.selected=="material"then if self.onOpenMaterial then self.onOpenMaterial(true)end elseif self.selected=="hue"then if self.onOpenHue then self.onOpenHue(true)end else self:send("hatch",self.selected)end
		end
	end

-- Robux store page (StoreView). It replaces the egg card while open, so the egg
-- shop remains the one presentation, Back and controller-focus owner.
function View:isStoreOpen()
	return self.store ~= nil and self.store:isOpen()
end
function View:attachStore(store)
	self.store = store
	store.onOpened = function()
		self.card.Visible = false
		if self.shopRoot then self.shopRoot.Visible = false end
		self:syncShopShade()
		self:bumpControllerEpoch()
	end
	store.onClosed = function()
		self.card.Visible = self.state.lastHatch ~= nil or not self.shopRoot
		self:bumpControllerEpoch()
		if self.shade.Visible then
			self:layout()
			if self:ownsInput() and string.match(UserInputService:GetLastInputType().Name, "^Gamepad") then
				GuiService.SelectedObject = if self.getStars.Visible then self.getStars else self:openingFocusTarget()
			end
		end
	end
	if self.shade.Visible then self:layout() end
end
function View:openStore()
	if not self.store or not self.shade.Visible or self.state.lastHatch or self.pending or self:isStoreOpen() or not self:ownsInput() then return false end
	if self.onAccepted then self.onAccepted("confirm") end
	self.store:open(self.state.nectar or 0)
	return true
end
function View:getSaveNotice()
	return if self.noticeManaged then self.managedSaveNotice else SaveNotice.resolve(nil,self.state)
end
function View:setSaveNotice(notice)
	local previous=self:getSaveNotice()
	self.noticeManaged,self.managedSaveNotice=true,notice
	if SaveNotice.key(previous)==SaveNotice.key(notice)then return false end
	self:layout();return true
end
function View:restoreRevealParent()
	if self.revealHost.Parent~=self.card then
		-- Offset size survives reparenting without a cinematic resize/replay.
		local size=self.revealHost.AbsoluteSize
		self.revealHost.Size=UDim2.fromOffset(size.X,size.Y);self.revealHost.Parent=self.card
	end
	self.revealHost.Position,self.revealHost.Size=UDim2.fromOffset(10,10),UDim2.new(1,-20,1,-80)
	self.note.Parent=self.card
end
-- Reveal stage host. `info` comes from HatchCinematic:handoff.
function View:showRevealStage(info)
	self:hideRevealStage()
	if not self.shade.Visible or not info or not info.result then return false end
	local pet = info.pet or Pets.byId[info.result.petId] or Pets.byId.pip
	local name = info.displayName or pet.name or "friend"
	-- Visible before the stage starts, so its first cue sees an owned stage.
	self.stageLayer.Visible = true
	local ok, stage = pcall(RevealStage.show, self.stageLayer, {
		pet = pet, name = info.displayName, appearance = info.appearance,
		tag = RevealStage.tagKind(info.result, info.kind), description = pet.description,
		next = info.result.starterGoal, instant = info.instant, fresh = info.fresh, voice = false, audio = self.audio,
		reduced = function()
			return if type(self.reduceEffects) == "function" then self.reduceEffects() == true else self.reduceEffects == true
		end,
		owns = function() return self:ownsInput() end,
		-- QA v2 R1.5: the first Bear (the starter) is onboarding, so B leaves the reveal for
		-- the garden ("Back") instead of starting another round.
		buttons = { View.secondaryButton(info.result), { id = "meet", text = "Meet " .. name, glyph = "A", primary = true } },
		onButton = function(id) if id == "play" or id == "exit" then self:revealPlay() else self:chooseResult(id) end end,
		onSkip = function() if self.cinematic and self.cinematic.skip then self.cinematic:skip() end end,
	})
	if not ok then
		warn("Reveal stage could not open: " .. tostring(stage))
		self.stageLayer.Visible = false
		return false
	end
	self.reveal = stage
	-- The card stays underneath (its scene, receipts and footer keep working)
	-- but cannot take selection or clicks while the stage covers it.
	self.card.Interactable = false
	self:syncRevealButtons()
	return true
end
function View:hideRevealStage()
	local stage = self.reveal
	self.reveal = nil
	if stage then stage:destroy() end
	if self.stageLayer then self.stageLayer.Visible = false end
	if self.card then self.card.Interactable = true end
end
-- Footer state mirrored onto the stage buttons (labels, Saving…, enabled).
function View:syncRevealButtons()
	local stage = self.reveal
	if not stage or not self.state.lastHatch then return end
	local pet = Pets.byId[self.state.lastHatch.petId]
	local play = if self.pending then "Saving…" elseif not self.ackReady then "Hatching…" elseif self.retryAvailable then "Try again" else "Play again"
	local meet = if self.pending then "Saving…" else "Meet " .. (if pet then pet.name else "friend")
	local playEnabled = self.action.Interactable
	-- Touch exit: with Play again unavailable after the intro, the button becomes Close.
	if View.revealExit(self.ackReady, playEnabled) == "close" then play, playEnabled = "Close", true end
	local exit = if self.pending then "Saving…" else UICopy.get("r1.reveal.exit")
	stage:setButtons({ meet = { text = meet, enabled = self.meetButton.Interactable }, play = { text = play, enabled = playEnabled },
		exit = { text = exit, enabled = playEnabled } })
	if stage.exiting and not self.ackIntent and not self.pending then stage:restore() end
end
-- B / Esc on the stage means "Play again" (1.6). False when no stage is up.
-- When Play again is unavailable (a save is Busy / Pending / refused, or an error is
-- up) B falls through to close(), so the player is never stuck on the stage.
function View:revealBack()
	if not self.reveal or not self.shade.Visible or self:isStoreOpen() then return false end
	if View.revealExit(self.ackReady, self.action.Interactable) == "close" then return false end
	self.reveal:back()
	return true
end
function View:revealPlay()
	if View.revealExit(self.ackReady, self.action.Interactable) == "close" then self:close("close"); return end
	self:chooseResult(View.secondaryIntent(self.state.lastHatch))
end
-- Pure (QA v2 R1.5): what the secondary choice (B / Play again / Back) acknowledges a
-- result with. The starter Bear is onboarding: "exit" leaves the reveal for the garden.
function View.secondaryIntent(result)
	return if type(result) == "table" and result.starter == true then "exit" else "play"
end
-- Pure: the stage's B button for a result.
function View.secondaryButton(result)
	if View.secondaryIntent(result) == "exit" then return { id = "exit", text = UICopy.get("r1.reveal.exit"), glyph = "B" } end
	return { id = "play", text = "Play again", glyph = "B" }
end
-- Pure: the reason View:close gets once a choice is acknowledged. "exit" is neither a
-- meet nor a new round: the player stays in the garden with the pet following.
function View.closeReason(intent)
	if intent == "meet" then return "meet" end
	if intent == "exit" then return "exit" end
	return "afterHatch"
end
-- Reveal backdrop (QA v2 R1.3): on in result mode, a short fade in from the world.
function View:showRevealBackdrop(on)
	local backdrop = self.revealBackdrop
	if not backdrop then return end
	on = on == true and self.shade.Visible
	if backdrop.Visible == on then return end
	backdrop.Visible = on
	if on and not self:eggReduced() then
		backdrop.BackgroundTransparency = 1
		Kit.tween(backdrop, .15, { BackgroundTransparency = 0 })
	else
		backdrop.BackgroundTransparency = 0
	end
	if on then
		-- The card is a frame for the cinematic only; no glass panel or edge over the black.
		self.card.BackgroundTransparency, self.revealHost.BackgroundTransparency = 1, 1
		for _, child in ipairs(self.card:GetChildren()) do
			if child:IsA("UIStroke") then child.Enabled = false end
		end
	end
end
function View:headerKey()
	return table.concat({self.headerTitle or self.heading.Text,tostring(self.state.nectar or 0),self.statusText or "",self.selected,tostring(self.state.lastHatch~=nil)},"|")
end
function View:footerRowHeight(button,width)
	local tight=self.compactShop or self.card.Size.X.Offset<400 or self.shade.AbsoluteSize.Y<200
	return math.max(44,Art.textHeight(button,width,0)+(if tight then 8 else 12))
end
local function nativeHeight(content,size,font,width)
	return math.ceil(TextService:GetTextSize(content,size,font,Vector2.new(math.max(1,width),10000)).Y)+2
end
function View:recipeMetrics(columnWidth,compact,columns)
	columns=columns or (if compact then 2 else 1)
	local choiceW=(columnWidth-8-(columns-1)*8)/columns
	local textX=if compact then 38 else 76
	local textW=math.max(1,choiceW-textX-8)
	local nameH,costH=0,0
	for _,id in ipairs(liveOrder)do
		local option=shopRecipe(id)
		nameH=math.max(nameH,nativeHeight(option.name,if compact then 14 else 16,Art.Font.Body,textW))
		costH=math.max(costH,nativeHeight(string.format(if compact then "%d Stars"else "%d Stars per hatch",option.cost),12,Art.Font.Body,textW))
	end
	return{columns=columns,width=choiceW,textX=textX,textWidth=textW,nameH=nameH,costH=costH,height=math.max(if compact then 44 else 83,nameH+costH+3+8),artH=if compact then 32 else 66}
end
function View:queueSelectedRecipe()
	if self.bodyFocusFallback then return end
	self.selectionLayoutEpoch=(self.selectionLayoutEpoch or 0)+1
	local token,owner=self.selectionLayoutEpoch,self.shade:GetAttribute("ControllerEpoch")
	task.defer(function()
		game:GetService("RunService").Heartbeat:Wait()
		if self.shade.Parent and self.shade.Visible and not self.state.lastHatch and token==self.selectionLayoutEpoch and not self.bodyFocusFallback and self.shade:GetAttribute("ControllerEpoch")==owner then self:ensureSelectedRecipe()end
	end)
end
function View:ensureSelectedRecipe()
	if self.bodyFocusFallback then return end
	local column=self.body:FindFirstChild("EggColumn");local row=column and column:FindFirstChild("Recipe_"..self.selected)
	local focused=GuiService.SelectedObject
	if focused and column and focused.Parent==column and (focused.Name:match("^Recipe_")or focused.Name=="DailyNectar")and focused.Interactable and focused.Selectable then row=focused end
	if not row then return end
	local top,height=row.Position.Y.Offset,View.listWindow(self.body);local current=self.body.CanvasPosition.Y
	local wanted=if row.Size.Y.Offset>height then math.max(0,top-4)elseif top<current then math.max(0,top-4)elseif top+row.Size.Y.Offset>current+height then top+row.Size.Y.Offset-height else current
	self.body.CanvasPosition=Vector2.new(0,math.clamp(wanted,0,math.max(0,self.body.CanvasSize.Y.Offset-height)))
end
function View:layout()
	if not self.state.lastHatch then return self:layoutShop() end
	if self.layingOutResult then return end
	self.layingOutResult = true
	self:useShopChrome(false)
	local size = self.shade.AbsoluteSize
	local notice = self:getSaveNotice()
	self.compactShop, self.budgetCompact = false, false
	self.card.Size = UDim2.fromOffset(math.clamp(size.X-32,1,560), math.clamp(size.Y-(if size.Y<200 then 16 else 32),1,580))
	self.cinematic.compactLandscape=self.card.Size.X.Offset>=480 and self.card.Size.Y.Offset<400
	self.closeButton.Position, self.closeButton.Size = UDim2.new(1,-56,0,6), UDim2.fromOffset(44,44)
	self.heading.Visible, self.note.Visible = false, false
	self:showRevealBackdrop(true)
	self.getStars.Visible = false
	self.meetButton.Visible = true
	local width = (self.card.Size.X.Offset-36)/2
	local footerH = math.max(44,self:footerRowHeight(self.action,width),self:footerRowHeight(self.meetButton,width))
	self.footerHeight = footerH
	self.action.Size, self.action.Position = UDim2.new(.5,-18,0,footerH), UDim2.new(.5,6,1,-footerH-12)
	self.meetButton.Size, self.meetButton.Position = UDim2.new(.5,-18,0,footerH), UDim2.new(0,12,1,-footerH-12)
	local stageW, normalH = math.max(1,self.card.Size.X.Offset-20), math.max(1,self.card.Size.Y.Offset-80)
	local function minimumHeight(w,h)
		return if self.cinematic.minimumHeightForWidth then self.cinematic:minimumHeightForWidth(w,h) else self.cinematic.minimumHeight or 0
	end
	-- Choose the owner once from the normal candidate, independent of whichever
	-- typography was painted by an earlier direct or scrolling layout.
	local shortStage = minimumHeight(stageW,normalH)>normalH
	if shortStage then stageW = math.max(1,self.card.Size.X.Offset-76) end
	local stageH = normalH
	for _=1,3 do
		local nextHeight = math.max(stageH,minimumHeight(stageW,stageH))
		if nextHeight == stageH then break end
		stageH = nextHeight
	end
	self.resultScrollable = notice ~= nil or shortStage
	-- The stage rectangle is solved independently of save status, preserving its
	-- exact hero and epoch while the same result moves into the scrolling owner.
	self.note.Parent = self.card
	if self.resultScrollable then
		local top = if notice then 48 else 8
		local gap = if size.Y<200 then 4 else 12
		local bodyW = self.card.Size.X.Offset-(if shortStage and not notice then 72 else 24)
		self.body.Visible = true
		self.action.Position, self.meetButton.Position = UDim2.new(.5,6,1,-footerH-gap), UDim2.new(0,12,1,-footerH-gap)
		self.body.Position, self.body.Size = UDim2.fromOffset(12,top), UDim2.fromOffset(bodyW, math.max(1,self.card.Size.Y.Offset-top-footerH-gap-4))
		self.revealHost.Size = UDim2.fromOffset(stageW,stageH)
		self.revealHost.Parent, self.revealHost.Position = self.body, UDim2.fromOffset(0,0)
		for _,child in ipairs(self.body:GetChildren()) do if child~=self.revealHost then child:Destroy() end end
		local total = stageH+4
		if notice then
			self.heading.Visible = true; self.heading.Text = notice.short; Art.type(self.heading,"Body",true)
			self.heading.Position, self.heading.Size = UDim2.fromOffset(12,4), UDim2.new(1,-80,0,44)
			self.note.Parent, self.note.Visible, self.note.Text = self.body, true, notice.detail
			Art.type(self.note,"Body",true)
			local h = Art.textHeight(self.note,self.card.Size.X.Offset-32,24)
			self.note.Position, self.note.Size = UDim2.fromOffset(4,stageH+8), UDim2.fromOffset(self.card.Size.X.Offset-32,h)
			total = stageH+8+h+4
		end
		self.body.CanvasSize = UDim2.fromOffset(0,total)
		self.body.ScrollingEnabled = total>self.body.Size.Y.Offset
		self.body.CanvasPosition = Vector2.new(0,math.clamp(self.body.CanvasPosition.Y,0,math.max(0,total-self.body.Size.Y.Offset)))
	else
		-- Move the live scene before hiding its former scrolling ancestor.
		self:restoreRevealParent()
		self.body.Visible = false
	end
	self.layoutHeaderKey = self:headerKey()
	self.layingOutResult = false
	if not self.refreshingFooterLayout then self.refreshingFooterLayout=true;self:refreshFooter();self.refreshingFooterLayout=nil end
end

function View:refreshShopHeader()
	local notice=self:getSaveNotice()
	self.statusText=if notice then notice.detail elseif self.pending or self.state.status=="Busy"or self.state.status=="Pending"then "Finishing your last action…"else self.errorMessage or self.state.message
	self.headerTitle=if notice then notice.short elseif self.pending or self.state.status=="Busy"or self.state.status=="Pending"then "Saving…"elseif self.errorMessage then "Try again"else "Hatch eggs"
	self.headerShortTitle=if notice then notice.narrow elseif self.statusText then self.headerTitle else "Hatch eggs"
	if self.state.lastHatch then self.heading.Text=self.headerTitle end
	self.note.Text=self.statusText or "Earn Stars. Choose an egg for your pet."
end

function View:revokeIntent()
	self.intentToken += 1
	self.ackIntent = nil
	self.ackRetryScheduledToken = nil
	self.ackRetryNeededToken = nil
end

function View:chooseResult(intent)
 if not self:ownsInput()then return false end
 if self.cinematic:consumeSkipInput()or self.cinematic:skip()then return false end
	local result = self.state.lastHatch
	if (intent ~= "meet" and intent ~= "play" and intent ~= "exit") or not self.shade.Visible or not result
		or not self.ackReady or self.pending or self.ackIntent
		or (self.state.status ~= nil and self.state.status ~= "Ready") then return end
	self.intentToken += 1
	self.ackRetryCount, self.retryAvailable = 0, false
	-- Install this before send: a local transport can synchronously deliver Ready.
	self.ackIntent = table.freeze({ id = result.id, petId = result.petId, intent = intent, starter = result.starter == true,
		sourceRevision = self.state.revision or 0, token = self.intentToken })
	self:send("ack", result.id)
	if self.reveal then self.reveal:exit(intent) end
end

function View:ownsInput()
	if not self.shade.Visible or GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox()
		or (self.audio and self.audio.deviceActive == false)
		or (self.ownsPresentation and not self.ownsPresentation()) then return false end
	local ancestor = self.shade
	while ancestor do
		if ancestor:IsA("GuiObject") and (not ancestor.Visible or not ancestor.Interactable)
			or ancestor:IsA("ScreenGui") and not ancestor.Enabled then return false end
		ancestor = ancestor.Parent
	end
	return self.shade.Parent ~= nil
end

function View:selectResultAction()
	if not self:ownsInput() or not string.match(UserInputService:GetLastInputType().Name, "^Gamepad") then return end
	local selected = GuiService.SelectedObject
	if selected == self.closeButton then return end
	if self.meetButton.Interactable then GuiService.SelectedObject = if self.reveal then self.reveal:primaryButton() else self.meetButton end
end

function View:send(command, value)
	if self.pending then return end
	self.pending = true
	self.errorMessage = nil
	self:refreshFooter()
	if self.onAccepted then self.onAccepted("confirm")end
	self.sendCommand(command, value, self.state.revision)
end

function View:isOpen()
	return self.shade.Visible
end

function View:refreshFooter()
	local state = self.state
	local ready = state.status == nil or state.status == "Ready"
	local textValue, canAct
	if state.lastHatch then
		local secondary = if state.lastHatch.starter then UICopy.get("r1.reveal.exit") else "Play again"
		textValue = if self.ackReady then (if self.retryAvailable then "Try again" else secondary) else "Hatching…"
		canAct = self.ackReady
		local pet = Pets.byId[state.lastHatch.petId]
		self.meetButton.Text = if self.pending then "Saving…" elseif self.shade.AbsoluteSize.Y<200 or self.card.Size.X.Offset<400 then "Meet" else "Meet " .. (if pet then pet.name else "friend")
	else
		local planned = View.hatchAction(self.selected, state)
		textValue, canAct = planned.text, planned.enabled
	end
	Art.type(self.action,"Action",self.compactShop or self.card.Size.X.Offset<400)
	Art.type(self.meetButton,"Action",self.card.Size.X.Offset<400)
	self.action.Text = if self.pending then "Saving…" else textValue
	if state.lastHatch and (self.shade.AbsoluteSize.Y<200 or self.card.Size.X.Offset<400) then
		local width=(self.card.Size.X.Offset-36)/2
		-- Names and hatch progress already have their own hero; tight footer verbs stay one line.
		if self:footerRowHeight(self.action,width)>44 then
			self.action.Text=if self.pending then "Saving" elseif not self.ackReady then "Wait…" elseif self.retryAvailable then "Retry" else "Play"
		end
		if self:footerRowHeight(self.meetButton,width)>44 then self.meetButton.Text=if self.pending then "Saving" else "Meet" end
	end
	self.action.Interactable = ready and not self.pending and canAct == true
	self.action.TextTransparency=0
	Art.control(self.action,not state.lastHatch,self.action.Interactable)
	self.meetButton.Interactable = state.lastHatch ~= nil and self.action.Interactable
	self.meetButton.TextTransparency=0
	Art.control(self.meetButton,true,self.meetButton.Interactable)
	self:refreshShopHeader()
	if state.lastHatch then
		local width=(self.card.Size.X.Offset-36)/2
		local needed=math.max(self:footerRowHeight(self.action,width),self:footerRowHeight(self.meetButton,width))
		if self.footerHeight and (self.footerHeight~=needed or self.layoutHeaderKey~=self:headerKey()) then self:layout() end
	elseif self.shopPane and not self.renderingBody then
		self:paintEggPane()
	end
	self:syncRevealButtons()
end

local function liveShopTarget(node,shade)
	local playerGui=game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
	if not node or not node.Parent or not node:IsA("GuiObject")or not node.Selectable or not node.Interactable or not node:IsDescendantOf(shade)or not playerGui or not node:IsDescendantOf(playerGui)then return false end
	local ancestor=node
	while ancestor do
		if ancestor:IsA("GuiObject")and (not ancestor.Visible or not ancestor.Interactable) then return false end
		if ancestor:IsA("ScreenGui")and not ancestor.Enabled then return false end
		ancestor=ancestor.Parent
	end
	return true
end
function View:restoreBodyFocus(previous,action,epoch)
	if not action or not self.shade.Parent or not self.shade.Visible or self.state.lastHatch or self.shade:GetAttribute("ControllerEpoch")~=epoch
		or GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox()then return end
	local current=GuiService.SelectedObject
	local column=self.body:FindFirstChild("EggColumn")
	local target=column and column:FindFirstChild(action)
	-- Disabling the current gift may make Roblox choose its scrolling parent.
	-- Only this same-shop automatic fallback can be replaced by neutral X.
	local disabledDaily=action=="DailyNectar" and not liveShopTarget(target,self.shade)
	if current and current~=previous and current.Parent and not(current==self.body and disabledDaily)then return end
	if not liveShopTarget(target,self.shade)then
		target=self.shopBackButton or self.closeButton;self.bodyFocusFallback=true;self.selectionLayoutEpoch=(self.selectionLayoutEpoch or 0)+1
	end
	if liveShopTarget(target,self.shade)then GuiService.SelectedObject=target;if target.Parent==column then self:queueSelectedRecipe()end end
end
-- ── Hatch eggs list + preview pane (UI-SPEC-REDESIGN-MENUS-2026-11-12 section 3) ──
-- Pure: one line and a two-line description per egg.
-- The lines live in Shared.UICopy (hatch.egg.<id>), already frozen.
View.EggCopy=UICopy.section("hatch.egg")
-- Pure: the eggs on the list, in order. The Feature Egg joins only with Features on.
function View.liveOrder(flags)
 flags=flags or FeatureFlags
 local order={"toy","material","hue"}
 if flags.Features then table.insert(order,2,"feature")end
 return order
end
-- Pure: the odds block for one egg. Values always come from OddsText.list, so the
-- whole percentages of one egg add up to 100% (equal thirds read 34%, 33%, 33%).
-- Returns {rows = {{id, name, value}}, per = "1 toy per egg", empty = text or nil}.
-- Restricted players (snapshot `restricted`, F1 policy) never roll: the block is one
-- "Next: <item>" row (or "All collected") from `nextFixed`, and `restricted` is true.
function View.oddsRows(id,state)
 state=state or {}
 if NextItem.restricted(state)then
  local notReady=id=="material"and not state.materialAvailable and NextItem.itemId("material",state)~=nil
  return{rows={{id="next",name=NextItem.line(id,state),value=""}},per=(View.EggCopy[id]or {}).per or "",
   empty=if notReady then "Material Eggs are not ready yet."else nil,restricted=true}
 end
 local rows,chances={},{};local empty=nil
 local function add(rowId,name,probability)table.insert(rows,{id=rowId,name=name});table.insert(chances,probability)end
 if id=="toy"then
  for _,r in ipairs(ToyCatalog.odds(state.toyUnlocks))do add(r.id,ToyCatalog.ById[r.id].name,r.probability)end
  if #rows==0 then empty="All toys owned"end
 elseif id=="material"then
  for _,r in ipairs(MaterialCatalog.odds(state.materialUnlocks))do add(r.id,MaterialCatalog.ById[r.id].name,r.probability)end
  if #rows==0 then empty="All materials owned"elseif not state.materialAvailable then empty="Material Eggs are not ready yet."end
 elseif id=="hue"then
  for _,itemId in ipairs(HueCatalog.RollOrder)do local item=HueCatalog.Items[itemId];add(itemId,item.name,item.weight)end
 elseif id=="feature"then
  for _,r in ipairs(FeatureCatalog.odds())do add(r.id,FeatureCatalog.ById[r.id].name,r.probability)end
 end
 for index,text in ipairs(OddsText.list(chances))do rows[index].value=text end
 return{rows=rows,per=(View.EggCopy[id]or {}).per or "",empty=empty}
end
-- Pure: the primary button for the selected egg. With too few Stars it is disabled
-- and `need` says how many more ("N more Stars needed").
function View.hatchAction(id,state)
 state=state or {}
 if state.pendingHueResult then return{text="Open saved jar",enabled=true}end
 if state.pendingToyResult then return{text="Open saved toy",enabled=true}end
 if state.pendingFeatureResult then return{text="Open saved feature",enabled=true}end
 if state.pendingMaterialResult then return{text="Open saved material",enabled=true}end
 if id=="toy"and #ToyCatalog.remaining(state.toyUnlocks)==0 then return{text="All toys owned",enabled=false}end
 if id=="feature"and FeatureCatalog.full(state.featureStock or {})then return{text="All stacks full",enabled=false}end
 if id=="material"then
  if #MaterialCatalog.remaining(state.materialUnlocks)==0 then return{text="All materials owned",enabled=false}end
  if not state.materialAvailable then return{text="Materials not ready",enabled=false}end
 end
 local recipe=shopRecipe(id)
 local missing=math.max(0,recipe.cost-(state.nectar or 0))
 local text="★ Hatch "..recipe.cost
 if missing>0 then return{text=text,enabled=false,need=missing.." more "..Stars.name(missing).." needed"}end
 return{text=text,enabled=true}
end
-- Pure: the "something inside" beat, t seconds into a 0.35 s beat. A 6 to 9 degree
-- tilt (amp, side = +1 or -1), a quick counter-tilt, a 4% squash and a short hop.
-- Returns rotation (degrees), squash (Y scale; X takes the inverse share) and hop (px up).
View.BeatLength=.35
function View.eggBeat(t,amp,side)
 amp=amp or 7.5;side=side or 1
 if t<=0 or t>=View.BeatLength then return 0,1,0 end
 local u=t/View.BeatLength
 local rotation=side*amp*math.sin(u*math.pi*2)*(1-u*.6)
 local squash=1-.04*math.max(0,math.sin(u*math.pi*3))*(if u<.34 then 1 else 0)
 local hop=if u>.3 then 6*math.sin((u-.3)/.7*math.pi)else 0
 return rotation,squash,hop
end
-- Pure: the wait before the next beat, 2.4 to 3.6 s (r in [0, 1)).
function View.nextBeatGap(r)return 2.4+1.2*math.clamp(r or .5,0,1)end
-- Pure: what B / the stage's Play again does on a hatch result. "play" acknowledges,
-- "wait" settles the intro, "close" leaves the shop (play is unavailable: a save is
-- Busy / Pending / refused, or an error is up), so nobody is stuck on the stage.
function View.revealExit(ackReady,playEnabled)
 if not ackReady then return "wait"end
 if playEnabled then return "play"end
 return "close"
end
-- Pure: a scrolling window's height in its own offset units (AbsoluteSize carries every
-- ancestor UIScale; CanvasSize and CanvasPosition do not).
function View.listWindow(body)
 local size=body.Size
 if size.Y.Scale==0 and size.Y.Offset>0 then return size.Y.Offset end
 return body.AbsoluteSize.Y
end
-- Pure: shop chrome geometry (panel units on desktop, pixels on a phone sheet).
function View.shopGeometry(W,H,phone)
 if phone then
  return{phone=true,W=W,H=H,list={x=20,y=64,w=226,h=H-84},rowH=56,rowGap=8,pane={x=252,y=64,w=W-20-252,h=H-84},pad=12,actionH=44}
 end
 return{phone=false,W=848,H=608,list={x=24,y=84,w=334,h=452},rowH=72,rowGap=12,pane={x=368,y=84,w=456,h=452},pad=16,actionH=56}
end

function View:buildShopChrome(view)
 if self.egg3D then self.egg3D:destroy();self.egg3D=nil end
 if self.eggWell then Peek.hide(self.eggWell)end
 if self.shopRoot then
  if self.body.Parent~=self.card then self.body.Parent=self.card end
  self.shopRoot:Destroy()
 end
 local phone=view~=nil
 local g=View.shopGeometry(if phone then view.W else 848,if phone then view.H else 608,phone)
 self.shopGeom=g;self.shopKey=if phone then string.format("%dx%d",view.W,view.H)else "regular"
 local root=Kit.frame(self.shade,"HatchEggs",nil,UDim2.new(),UDim2.fromScale(1,1));root.ZIndex=self.shade.ZIndex+1;root.Visible=false
 self.shopRoot=root
 -- QA v2: the shared full-screen shade (Kit.modalShade + the shade stack), on every
 -- device. The old local dim stopped under the top bar and was clear on phones.
 local dim=Kit.modalShade(root,"Shade",root.ZIndex+1)
 self.shopDim=dim
 local panel=Kit.frame(root,"Panel","panel",UDim2.fromScale(.5,.5),UDim2.fromOffset(g.W,g.H),30);panel.Active=true
 panel.ZIndex=dim.ZIndex+1
 Kit.halftone(panel,"hatch",phone)
 self.shopPanel=panel;self.shopScale=Kit.node("UIScale",panel,{Scale=1})
 local body=panel
 if phone then
  panel.BackgroundTransparency=1
  local sheet=Kit.sheet(panel,g.W,g.H)
  body=Kit.frame(panel,"Body",nil,UDim2.new(),UDim2.fromScale(1,1));body.ZIndex=sheet.ZIndex+3
 else
  panel.AnchorPoint=Vector2.new(.5,.5);panel.ClipsDescendants=true;Kit.stroke(panel)
  local gradient=Kit.frame(panel,"Gradient",nil,UDim2.new(),UDim2.fromScale(1,1));gradient.BackgroundTransparency=0;gradient.BackgroundColor3=Color3.new(1,1,1)
  Kit.node("UIGradient",gradient,{Rotation=90,Color=ColorSequence.new(Color3.new(1,1,1),Color3.new(0,0,0)),Transparency=NumberSequence.new(.97,.88)})
 end
 self.shopBody=body
 self.shopHeader=Kit.header(body,{title="Hatch eggs",eyebrow="Garden",tint="hatch",compact=phone,width=g.W,left=24,onBack=function()self:close("close")end})
 self.shopBackButton=self.shopHeader.back.root;self.shopBackButton.Selectable=true
 -- Pane: egg well, name + price chip, description, odds, need line, primary button.
 local pane=Kit.card(body,"EggPane",nil,{pad=g.pad,seam=true});pane.Position=UDim2.fromOffset(g.pane.x,g.pane.y);pane.Size=UDim2.fromOffset(g.pane.w,g.pane.h)
 self.shopPane=pane
 local p=g.pad
 local wellR=if phone then {x=p,y=p,w=150,h=g.pane.h-p*2}else {x=p,y=p,w=g.pane.w-p*2,h=152}
 local well=Kit.frame(pane,"EggWell","well",UDim2.fromOffset(wellR.x,wellR.y),UDim2.fromOffset(wellR.w,wellR.h),12);Kit.stroke(well);well.ClipsDescendants=true
 Kit.dotGrid(well) -- T7 LCD dot grid under the egg (nothing until the asset id lands)
 self.eggWell=well
 -- T4: the pet peeks up into the egg preview from the well's bottom edge, right of the egg (desktop only).
 self.peekRect={x=wellR.w-140,y=0,w=128,h=wellR.h}
 local eggH=math.min(wellR.h-36,if phone then 120 else 112);local eggW=math.floor(eggH*.78)
 local floorY=if phone then wellR.h*.5+eggH*.5+8 else wellR.h-22
 local shadow=Kit.frame(well,"EggShadow",nil,UDim2.fromOffset(wellR.w/2,floorY),UDim2.fromOffset(eggW*1.1,10),999)
 shadow.AnchorPoint=Vector2.new(.5,.5);shadow.BackgroundTransparency=.55;shadow.BackgroundColor3=Color3.new(0,0,0)
 local turntable=Kit.frame(well,"Turntable",nil,UDim2.fromOffset(wellR.w/2,floorY+2),UDim2.fromOffset(eggW*1.9,14),999)
 turntable.AnchorPoint=Vector2.new(.5,.5);turntable.BackgroundTransparency=1
 -- No outlined turntable ring: it read as a stray green pill under the egg (Studio 2026-11-13).
 local holder=Kit.frame(well,"EggPreview",nil,UDim2.fromOffset(wellR.w/2,floorY),UDim2.fromOffset(eggW,eggH))
 holder.AnchorPoint=Vector2.new(.5,1)
 self.eggHolder,self.eggShadow,self.eggSize,self.eggFloor=holder,shadow,Vector2.new(eggW,eggH),floorY
 self.eggArtId=nil
 -- 3D egg (Shared.EggModels): the 2D shell above stays until the meshes load, and is the fallback.
 self.egg3D=EggPreview.new(well,{audio=self.audio,reduced=function()return self:eggReduced()end,onLoaded=function()self:sync3D()end})
 local tx=if phone then wellR.x+wellR.w+12 else p
 local tw=g.pane.w-tx-p
 local y=if phone then p else wellR.y+wellR.h+12
 self.eggName=Kit.text(pane,"Title","","text",{Name="EggName",Position=UDim2.fromOffset(tx,y),Size=UDim2.fromOffset(tw-80,if phone then 24 else 30),TextSize=if phone then 18 else 24,TextTruncate=Enum.TextTruncate.AtEnd})
 self.eggPrice=Kit.chip(pane,"★ 0","sticker",if phone then 22 else 26);self.eggPrice.root.AnchorPoint=Vector2.new(1,.5)
 self.eggPrice.root.Position=UDim2.fromOffset(tx+tw,y+(if phone then 12 else 15))
 y+=if phone then 26 else 32
 self.eggDescription=Kit.text(pane,"Body","","soft",{Name="EggDescription",Position=UDim2.fromOffset(tx,y),Size=UDim2.fromOffset(tw,if phone then 32 else 40),TextSize=if phone then 12 else 15,TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top})
 y+=if phone then 34 else 46
 self.oddsLabel=Kit.text(pane,"Label","Odds","dim",{Name="OddsLabel",Position=UDim2.fromOffset(tx,y),Size=UDim2.fromOffset(tw/2,16),TextSize=12})
 self.oddsPer=Kit.text(pane,"Label","","dim",{Name="OddsPer",Position=UDim2.fromOffset(tx+tw/2,y),Size=UDim2.fromOffset(tw/2,16),TextSize=12,TextXAlignment=Enum.TextXAlignment.Right})
 y+=if phone then 16 else 20
 self.oddsTop,self.oddsX,self.oddsW=y,tx,tw
 self.oddsHolder=Kit.frame(pane,"Odds",nil,UDim2.fromOffset(tx,y),UDim2.fromOffset(tw,10))
 self.needLine=Kit.text(pane,"Small","","dangerText",{Name="NeedLine",Size=UDim2.fromOffset(tw,18),TextSize=if phone then 12 else 14})
 local button,state=Kit.button(pane,"HatchButton",{variant="primary",text="Hatch",glyph="A",size=Vector2.new(tw,g.actionH),textSize=if phone then 16 else nil,selectable=true})
 button.Position=UDim2.fromOffset(tx,g.pane.h-p-g.actionH);self.hatchButton=button
 button.Activated:Connect(function()self:actPrimary()end)
 self.buttonY=g.pane.h-p-g.actionH
 self.hintRow,self.legendLine,self.hintKind=nil,nil,nil
 if not phone then
  self.hintRow=Kit.frame(body,"Hints",nil,UDim2.fromOffset(24,566),UDim2.fromOffset(560,24))
  -- QA v2 (R2.5 slice): one line, once a session, says what Browse / Hatch / Back do in
  -- the words of the last input; it sits in the gap between the pane and the hint row.
  self.legendLine=Kit.text(body,"Small","","soft",{Name="HintLegend",Position=UDim2.fromOffset(24,540),Size=UDim2.fromOffset(800,20),TextSize=13,Visible=false,TextTruncate=Enum.TextTruncate.AtEnd})
  Kit.text(body,"Small",UICopy.get("hatch.promise"),"dim",{Name="Promise",Position=UDim2.fromOffset(424,566),Size=UDim2.fromOffset(400,24),TextXAlignment=Enum.TextXAlignment.Right})
  self:paintHints()
 end
end
-- ── Footer hints (QA v2, R2.5 Hatch eggs slice) ─────────────────────────────
-- Chips and the legend come from R2's HintGlyphs (one map for every menu footer):
-- gamepad + / A / B, keyboard WASD / ENTER / BKSP, touch none (the legend line only).
-- Every chip is live: WASD/arrows (init) or the D-pad (native selection) browse, Enter /
-- A hatch the picked egg, Backspace / B leave (EggDropPickerBack).
-- Pure: "Keyboard" | "Gamepad" | "Touch" for an input type (default: the last input).
function View.inputKind(inputType)
 return HintGlyphs.kindOf(inputType or UserInputService:GetLastInputType())
end
-- Pure: the hint chips for an input, {glyph, label, action}.
function View.hintPairs(kind)
 return HintGlyphs.rows({{"browse",UICopy.get("input.action.browse")},{"confirm",UICopy.get("r1.hatchHints.hatch")},
  {"back",UICopy.get("input.action.back")}},kind)
end
-- Pure: the one-time legend line for an input.
function View.legendText(kind)
 return UICopy.get(HintGlyphs.legendKey(kind))
end
View.LegendSeconds=8
local legendShown=false -- once a session
function View.resetLegend()legendShown=false end
function View:paintHints()
 local row=self.hintRow;if not row then return end
 local kind=View.inputKind();self.hintKind=kind
 for _,child in ipairs(row:GetChildren())do if child:IsA("GuiObject")then child:Destroy()end end
 local x=0
 local list=View.hintPairs(kind)
 for _,pair in ipairs(list)do
  local chip=Kit.glyph(row,pair[1],false,22,true);chip.Position=UDim2.fromOffset(x,1)
  x+=chip.Size.X.Offset+6
  Kit.text(row,"Small",pair[2],"soft",{Name="Hint_"..pair[2],Position=UDim2.fromOffset(x,0),Size=UDim2.fromOffset(120,24),AutomaticSize=Enum.AutomaticSize.X})
  x+=math.ceil(Kit.measure(pair[2],"Small",14).X)+18
 end
 row:SetAttribute("HintInput",kind)
 if self.legendLine and self.legendLine.Visible then self.legendLine.Text=View.legendText(kind)end
end
-- The legend shows on the first Hatch eggs open of the session, then fades.
function View:showLegendOnce()
 local line=self.legendLine
 if legendShown or not line or not self.shade.Visible or self.state.lastHatch then return end
 legendShown=true
 line.Text=View.legendText(View.inputKind());line.Visible=true;line.TextTransparency=0
 local token={};self.legendToken=token
 task.delay(View.LegendSeconds,function()
  if self.legendToken~=token or not line.Parent then return end
  if self:eggReduced()then line.Visible=false;return end
  Kit.tween(line,.4,{TextTransparency=1})
  task.delay(.45,function()if self.legendToken==token and line.Parent then line.Visible=false end end)
 end)
end
-- Shop chrome shade on the shared stack (one dim at a time; a screen over it covers it).
function View:syncShopShade()
 local dim=self.shopDim
 local on=dim~=nil and dim.Parent~=nil and self.shade.Visible and self.shopRoot~=nil and self.shopRoot.Visible and not self.state.lastHatch
 if on then
  Kit.shadeOpen(self,dim,function(covered)if self.shopPanel then self.shopPanel.Interactable=not covered end end)
 elseif Kit.shadeIsOpen(self)then
  Kit.shadeClose(self)
 end
end
-- Shop chrome on (list + pane) or off (the result card keeps its old frame).
function View:useShopChrome(on)
 local store=self:isStoreOpen()
 if self.shopRoot then self.shopRoot.Visible=on and not store end
 self.card.Visible=not on and not store
 if on then
  if self.body.Parent~=self.shopBody then self.body.Parent=self.shopBody end
 elseif self.body.Parent~=self.card then self.body.Parent=self.card end
 if on then self:showRevealBackdrop(false)end
 self:syncEggClock()
 self:syncShopShade()
 if on and self.shopRoot and self.shopRoot.Visible then self:showLegendOnce()end
end
function View:layoutShop()
 if self.layingOut then return end;self.layingOut=true
 self.bodyFocusFallback=false;self:restoreRevealParent();self:refreshShopHeader()
 local size=self.shade.AbsoluteSize
 local phone=Kit.compactRule(size.X,size.Y)
 local view=nil
 if phone then local _,kh=Kit.keepOut();view={W=math.floor(size.X),H=math.floor(size.Y)-(kh+2),top=kh+2}end
 local key=if view then string.format("%dx%d",view.W,view.H)else "regular"
 if self.shopKey~=key or not self.shopRoot then self:buildShopChrome(view)end
 local panel=self.shopPanel
 if view then panel.AnchorPoint=Vector2.zero;panel.Position=UDim2.fromOffset(0,view.top);panel.Size=UDim2.fromOffset(view.W,view.H);self.shopScale.Scale=1
 else panel.AnchorPoint=Vector2.new(.5,.5);panel.Position=UDim2.fromScale(.5,.5);panel.Size=UDim2.fromOffset(848,608)
  self.shopScale.Scale=math.max(.1,math.min(1.2,(size.X-24)/848,(size.Y-24)/608))end
 self.compactShop=phone;self.budgetCompact=phone
 self:useShopChrome(true)
 local g=self.shopGeom
 self.meetButton.Visible,self.revealHost.Visible=false,false
 self.getStars.Visible=self.store~=nil
 self.body.Visible=true
 self.body.Position,self.body.Size=UDim2.fromOffset(g.list.x-3,g.list.y-3),UDim2.fromOffset(g.list.w,g.list.h+6)
 self.body.ScrollBarThickness=4
 self.footerHeight=g.actionH
 self.layoutHeaderKey=self:headerKey();self.layingOut=false
 if self.shade.Visible then self:renderBody();self:ensureSelectedRecipe()end
 if not self.refreshingFooterLayout then self.refreshingFooterLayout=true;self:refreshFooter();self.refreshingFooterLayout=nil end
end
-- The list: one text-only row per egg (name, what it gives, price), then the daily
-- gift and the Stars store.
function View:renderBody()
 if self.state.lastHatch or self.renderingBody or not self.shopGeom then return end;self.renderingBody=true
 local previous=GuiService.SelectedObject;local action=previous and previous:IsDescendantOf(self.body)and previous.Name or nil
 local owner=self.shade:GetAttribute("ControllerEpoch");local canvas=self.body.CanvasPosition
 self.revealHost.Visible=false;self:restoreRevealParent()
 local g=self.shopGeom;local phone=g.phone
 local left=self.body:FindFirstChild("EggColumn")
 for _,child in ipairs(self.body:GetChildren())do if child~=left then child:Destroy()end end
 left=left or Kit.frame(self.body,"EggColumn",nil,UDim2.fromOffset(0,0),UDim2.fromOffset(100,100))
 local keep={GetStars=true}
 for _,id in ipairs(liveOrder)do keep["Recipe_"..id]=true end
 for _,child in ipairs(left:GetChildren())do if not keep[child.Name]then child:Destroy()end end
 local w=g.list.w-10 -- 3 px inset each side plus the 4 px scrollbar
 left.Position=UDim2.fromOffset(0,0);left.Size=UDim2.fromOffset(g.list.w,1)
 left:SetAttribute("RecipeColumns",1)
 local y=3
 for _,id in ipairs(liveOrder)do
  local recipe=shopRecipe(id);local copy=View.EggCopy[id]or {}
  local n=left:FindFirstChild("Recipe_"..id)
  if not n then
   -- T2: a pressable tile with a lip (4 px, 3 on phones) inside the 12 / 8 px row gap.
   n=Kit.tile(left,"Recipe_"..id,{radius=12,compact=phone,selectable=true})
   n.Activated:Connect(function()
    if not liveShopTarget(n,self.shade)then return end
    if self.selected==id then self:actPrimary()else self:selectRecipe(id);Kit.boing(n)end
   end)
   n.SelectionGained:Connect(function()if self.selected~=id and liveShopTarget(n,self.shade)then self:selectRecipe(id)end end)
   local name=Kit.text(n,"Name",recipe.name,"text",{Name="RecipeName",TextTruncate=Enum.TextTruncate.AtEnd})
   local line=Kit.text(n,"Small",copy.line or "","soft",{Name="RecipeLine",TextTruncate=Enum.TextTruncate.AtEnd})
   local cost=Kit.text(n,"Counter","★ "..recipe.cost,"stars",{Name="Cost",TextXAlignment=Enum.TextXAlignment.Right})
   local _=name;_=line;_=cost
  end
  local h=g.rowH
  n.Position,n.Size=UDim2.fromOffset(3,y),UDim2.fromOffset(w,h)
  Kit.setTileLip(n,Kit.tileLip(phone))
  local name,line,cost=n.RecipeName,n.RecipeLine,n.Cost
  name.TextSize=if phone then 15 else 18;line.TextSize=if phone then 12 else 14;cost.TextSize=if phone then 15 else 18
  name.Position,name.Size=UDim2.fromOffset(16,h/2-(if phone then 20 else 24)),UDim2.fromOffset(w-100,if phone then 20 else 24)
  line.Position,line.Size=UDim2.fromOffset(16,h/2+(if phone then 2 else 2)),UDim2.fromOffset(w-100,18)
  cost.Position,cost.Size=UDim2.fromOffset(w-84,0),UDim2.fromOffset(68,h)
  local selected=self.selected==id
  Kit.paint(n,"BackgroundColor3",if selected then "selected"else "raised")
  local stroke=Kit.tileState(n).stroke;stroke.Thickness=if selected then 2 else 1;stroke.Transparency=if selected then 0 else .86
  Kit.paint(stroke,"Color",function()return if selected then Kit.color("accent")else Color3.new(1,1,1)end)
  n.Interactable,n.Selectable=not self.pending,not self.pending;n:SetAttribute("Selected",selected)
  n:SetAttribute("AccessibleLabel",recipe.name..", "..(copy.line or "")..", "..recipe.cost.." Stars")
  y+=h+g.rowGap
 end
 y+=if phone then 0 else 8
 local note=Kit.text(left,"Small",UICopy.get(if phone then "hatch.footer.phone"else "hatch.footer.desktop"),"soft",{Name="ListNote",Position=UDim2.fromOffset(8,y),Size=UDim2.fromOffset(w-8,20),TextSize=if phone then 12 else 14})
 local _=note
 y+=28
 -- QA v2: the stamp card and the daily stamp button live in Quests now (R3). Seam: this
 -- list ends with the eggs, the note and Get Stars; nothing here reads daily state.
 if self.store then
  self.getStars.Parent=left;Art.type(self.getStars,"Action",phone)
  local sh=math.max(44,Art.actionHeight(self.getStars,w));self.getStars.Position,self.getStars.Size=UDim2.fromOffset(3,y),UDim2.fromOffset(w,sh);y+=sh+8
 end
 -- QA v2 R1.9: the list always scrolls (wheel, drag, pad focus) once it outgrows its
 -- window, so more eggs fit later. The window is measured in offset units: AbsoluteSize
 -- carries the panel's UIScale and used to keep a slightly long list from scrolling.
 local window=View.listWindow(self.body)
 left.Size=UDim2.fromOffset(g.list.w,y);self.body.CanvasSize=UDim2.fromOffset(0,y+4);self.body.ScrollingEnabled=true
 self.body:SetAttribute("Scrolls",y+4>window)
 self.body.CanvasPosition=Vector2.new(0,math.clamp(canvas.Y,0,math.max(0,y+4-window)));self.renderingBody=false
 self:paintEggPane()
 self.shelfEffects:setEggs({self.eggArt})
 self:restoreBodyFocus(previous,action,owner)
 if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(left)then self:queueSelectedRecipe()end
end
-- The right pane for the selected egg. Preview swaps at once, then a 120 ms settle.
function View:paintEggPane()
 if not self.shopPane then return end
 local id=self.selected;local recipe=shopRecipe(id);local copy=View.EggCopy[id]or {}
 local g=self.shopGeom;local phone=g.phone
 if self.egg3D and self.egg3D.type~=id then self.egg3D:setType(id)end
 if self.eggArtId~=id then
  for _,child in ipairs(self.eggHolder:GetChildren())do child:Destroy()end
  self.eggArt=EggArt.create(self.eggHolder,id,UDim2.fromScale(0,0),UDim2.fromScale(1,1),self.eggHolder.ZIndex+1)
  self.eggArtId=id
  if not self:eggReduced()then
   local scale=self.eggHolder:FindFirstChildOfClass("UIScale")or Kit.node("UIScale",self.eggHolder,{Scale=1.04})
   scale.Scale=1.04;Kit.tween(scale,.12,{Scale=1})
  end
  self.nextBeat=os.clock()+.6
 end
 self.eggName.Text=recipe.name
 self.eggPrice.set("★ "..recipe.cost,"sticker") -- T6: the pane's one sticker
 self.eggDescription.Text=copy.description or ""
 local odds=View.oddsRows(id,self.state)
 self.oddsPer.Text=string.upper(odds.per)
 self.oddsLabel.Text=string.upper(if odds.restricted then UICopy.get("hatch.next.label")else "Odds")
 for _,child in ipairs(self.oddsHolder:GetChildren())do child:Destroy()end
 local a=View.hatchAction(id,self.state)
 local need=if self.statusText then self.statusText else a.need
 self.needLine.Text=need or "";self.needLine.Visible=need~=nil
 Kit.paint(self.needLine,"TextColor3",if a.need and not self.statusText then "dangerText"else "soft")
 local limit=self.buttonY-(if need then 22 else 6)
 local rows=odds.rows
 if odds.empty then rows={{id="empty",name=odds.empty,value=""}}end
 local cols=if #rows>3 then 2 else 1
 local perCol=math.ceil(#rows/cols)
 local pitch=math.min(if phone then 18 else 28,math.floor((limit-self.oddsTop)/math.max(1,perCol)))
 local rowH=math.max(14,pitch-(if phone then 2 else 4))
 local cw=(self.oddsW-(cols-1)*8)/cols
 for i,r in ipairs(rows)do
  local c,ri=math.floor((i-1)/perCol),(i-1)%perCol
  local row=Kit.frame(self.oddsHolder,"Odds_"..r.id,if phone then nil else "well",UDim2.fromOffset(c*(cw+8),ri*pitch),UDim2.fromOffset(cw,rowH),6)
  if not phone then row.BackgroundTransparency=0 end
  Kit.text(row,"Body",r.name,"text",{Name="Name",Position=UDim2.fromOffset(if phone then 0 else 12,0),Size=UDim2.fromOffset(if odds.restricted then cw-(if phone then 0 else 24)else cw-80,rowH),TextSize=if phone then 13 else 15,TextTruncate=Enum.TextTruncate.AtEnd})
  Kit.text(row,"Counter",r.value,"text",{Name="Value",Position=UDim2.fromOffset(cw-(if phone then 70 else 82),0),Size=UDim2.fromOffset(70,rowH),TextSize=if phone then 13 else 15,TextXAlignment=Enum.TextXAlignment.Right})
  row:SetAttribute("OddsText",r.value)
 end
 self.oddsHolder.Size=UDim2.fromOffset(self.oddsW,perCol*pitch)
 self.needLine.Position=UDim2.fromOffset(self.oddsX,self.buttonY-20)
 local text=if self.pending then "Saving…"else a.text
 Kit.setText(self.hatchButton,text)
 Kit.setEnabled(self.hatchButton,self.action.Interactable)
 Kit.setGlyphVisible(self.hatchButton,not phone or not Kit.lastInputTouch())
 self.shopHeader.setTitle(if self.headerTitle and self.headerTitle~="Hatch eggs"then self.headerTitle else "Hatch eggs")
 if self.shopHeader.wallet then self.shopHeader.wallet.set(self.state.nectar or 0)end
 self.shopPanel:SetAttribute("SelectedEgg",id);self.shopPanel:SetAttribute("OddsRows",#odds.rows);self.shopPanel:SetAttribute("OddsRestricted",odds.restricted==true)
end
function View:sync3D()
 local egg=self.egg3D;if not egg then return end
 local on=egg.loaded
 if self.eggHolder then self.eggHolder.Visible=not on end
 if self.eggShadow then self.eggShadow.Visible=not on end
 if on then egg:setType(self.selected,true)end
 self:syncEggClock()
end
function View:eggReduced()
 return GuiService.ReducedMotionEnabled or(if type(self.reduceEffects)=="function"then self.reduceEffects()==true else self.reduceEffects==true)
end
-- The egg sways gently and every 2.4 to 3.6 s does a "something inside" beat.
-- 2D shell fallback until the 3D egg shells are modelled (build plan).
function View:syncEggClock()
 local wanted=self.shade.Visible and self.shopRoot~=nil and self.shopRoot.Visible and not self.state.lastHatch
 if self.eggWell then
  if wanted then Peek.show(self.eggWell,{rect=self.peekRect,align="right",key="hatch",compact=self.shopGeom==nil or self.shopGeom.phone})
  else Peek.hide(self.eggWell)end
 end
 if self.egg3D then self.egg3D:setActive(wanted and self.egg3D.loaded)end
 if self.egg3D and self.egg3D.loaded then wanted=false end
 if not wanted then if self.eggClock then self.eggClock:Disconnect();self.eggClock=nil end;return end
 if self.eggClock then return end
 self.nextBeat=os.clock()+1;self.beatStart=nil
 self.eggClock=game:GetService("RunService").RenderStepped:Connect(function()
  local holder=self.eggHolder;if not holder or not holder.Parent then return end
  if self:eggReduced()or GuiService.MenuIsOpen then
   holder.Rotation=0;holder.Size=UDim2.fromOffset(self.eggSize.X,self.eggSize.Y);holder.Position=UDim2.new(0,holder.Position.X.Offset,0,self.eggFloor);return
  end
  local now=os.clock()
  if not self.beatStart and now>=(self.nextBeat or now)then
   self.beatStart=now;self.beatAmp=6+math.random()*3;self.beatSide=if math.random()<.5 then -1 else 1
   if self.audio and self.audio.play then pcall(function()self.audio:play("egg_wobble",1,.4)end)end
  end
  local rotation,squash,hop=0,1,0
  if self.beatStart then
   rotation,squash,hop=View.eggBeat(now-self.beatStart,self.beatAmp,self.beatSide)
   if now-self.beatStart>=View.BeatLength then self.beatStart=nil;self.nextBeat=now+View.nextBeatGap(math.random())end
  end
  local sway=2*math.sin(now*1.3)
  holder.Rotation=rotation+sway
  holder.Size=UDim2.fromOffset(self.eggSize.X*(2-squash),self.eggSize.Y*squash)
  holder.Position=UDim2.new(0,holder.Position.X.Offset,0,self.eggFloor-hop)
  if self.eggShadow then self.eggShadow.BackgroundTransparency=.55+hop*.04 end
 end)
end

-- Keyboard: W / S / Up / Down move the list selection (gamepad uses native selection).
function View:moveRecipe(delta)
	if not self.shade.Visible or self.state.lastHatch or self:isStoreOpen() then return false end
	local at=table.find(liveOrder,self.selected)or 1
	local nextIndex=math.clamp(at+delta,1,#liveOrder)
	if nextIndex==at then return false end
	local ok=self:selectRecipe(liveOrder[nextIndex])
	local column=self.body:FindFirstChild("EggColumn");local row=column and column:FindFirstChild("Recipe_"..self.selected)
	if ok and row and GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.shade)then GuiService.SelectedObject=row end
	return ok
end
function View:selectRecipe(id)
	if self.pending or self.state.lastHatch or not table.find(liveOrder,id) then return false end
 if id==self.selected then return true end
	self.bodyFocusFallback=false
	local focused=GuiService.SelectedObject
	if focused and focused:IsDescendantOf(self.body)and focused.Name:match("^Recipe_")then self.refocusRecipeId=id end
	self.selected = id
	self:renderBody()
	self:ensureSelectedRecipe()
	self:refreshFooter()
	self:queueSelectedRecipe()
	if self.onAccepted then self.onAccepted("tab")end
	return true
end

function View:update(state)
	local wasResult=self.state.lastHatch~=nil
	self.state = state or {}
	if self.store then
		self.store:setBalance(self.state.nectar or 0)
		if self.state.lastHatch and self.store:isOpen() then self.store:close("forced") end
	end
	if wasResult~=(self.state.lastHatch~=nil)then self:bumpControllerEpoch()end
	if self.errorMessage and self.errorRevision and self.state.status=="Ready" and (self.state.revision or 0)>self.errorRevision then self.errorMessage,self.errorRevision=nil,nil end
	local intent = self.ackIntent
	local result = self.state.lastHatch
    if result and self.appearanceFor then self.cinematic:setAppearance(self.appearanceFor(result.petId))end
	if result and self.shade.Visible and self.playingId ~= result.id then self.body.CanvasPosition = Vector2.zero end
	if intent and result and result.id ~= intent.id then
		self:revokeIntent()
		intent = nil
	end
	if intent and self.shade.Visible and self.state.status == "Ready" and not result
		and (self.state.revision or 0) > intent.sourceRevision and intent.token == self.intentToken then
		-- Dequeue before callbacks, which can synchronously reopen/update this view.
		self:revokeIntent()
		self.pending = false
		self:close(View.closeReason(intent.intent), intent)
		return
	end
	self.pending = self.ackIntent ~= nil or self.state.status == "Busy"
	self.note.Text = self.errorMessage or self.state.message or "Earn Stars. Choose an egg for your pet."
	self:layout()
	if self.shade.Visible then
		if result then
			self.revealHost.Visible = true
			if self.playingId ~= result.id then
				self.presentationGeneration += 1
				local generation = self.presentationGeneration
				local skipIntro = self.lastPresentedId == result.id
				self.playingId, self.ackReady = result.id, false
				local presentation = table.clone(result)
				local pet = Pets.byId[result.petId]
				local family = result.family or (pet and (pet.family or pet.id))

				if result.starter then
					local recipe = shopRecipe(self.selected)
					local balance = self.state.nectar or 0
					presentation.starterGoal = if balance >= recipe.cost then recipe.name .. " ready · choose it in Menu"
						else Stars.format("%s · %d/%d Stars · win quests", recipe.name, balance, recipe.cost)
				end
				local completed = false
				self.cinematic:play(presentation, function()
					-- A cancelled intro may finish after X and a same-ID reopen.
					if completed or self.presentationGeneration ~= generation or not self.shade.Visible
						or not self.state.lastHatch or self.state.lastHatch.id ~= result.id then return end
					completed = true
					self.ackReady = true
					self:refreshFooter()
					if self:ownsInput() then self:selectResultAction() end
				end, { appearance=self.appearanceFor and self.appearanceFor(result.petId),skipIntro = skipIntro, onPresented = function()
					if self.presentationGeneration == generation and self.shade.Visible
						and self.state.lastHatch and self.state.lastHatch.id == result.id then
						-- One bounded session marker survives X; it never acknowledges a result.
						self.lastPresentedId = result.id
					end
				end })
				self:layout()
			end
		else
			if self.playingId then
				self.presentationGeneration += 1
				self.cinematic:cancel()
			end
			self.playingId, self.ackReady = nil, false
			self:renderBody()
		end
	end
	self:refreshFooter()
	if self.ackRetryNeededToken then self:retryAcknowledgement() end
end

function View:setError(message)
	local status = self.state.status
	-- Feedback can precede its public snapshot. Only explicit acknowledgement
	-- rejection releases the choice; throttle, locks and unknown save/network
	-- failures cannot prove that this session's operation did not commit.
	local rejected = message == "HatchChanged" or message == "InvalidCommand" or message == "UnknownAction"
		or message == "RevisionChanged" or message == "Your hatch progress updated. Try again."
	if rejected then self:revokeIntent() end
	self.pending = self.ackIntent ~= nil or status == "Busy"
	self.errorMessage = message
	self.errorRevision=self.state.revision or 0
	self.note.Text = message or "Earn Stars. Choose an egg for your pet."
	if message == "One moment…" or message == "Finishing your last save…"
		or message == "Finishing your last hatch action…"
		or message == "Retry the previous action while it saves." then self:retryAcknowledgement() end
	self:refreshFooter()
end

function View:retryAcknowledgement()
	local intent = self.ackIntent
	local status = self.state.status
	if not intent or not self.shade.Visible then return end
	self.ackRetryNeededToken = intent.token
	if (status ~= nil and status ~= "Ready") or self.ackRetryScheduledToken == intent.token then return end
	if self.ackRetryCount >= 3 then
		self:revokeIntent()
		self.pending, self.retryAvailable = false, true
		return
	end
	self.ackRetryScheduledToken = intent.token
	task.delay(0.6, function()
		if self.ackRetryScheduledToken ~= intent.token then return end
		self.ackRetryScheduledToken = nil
		local result, currentStatus = self.state.lastHatch, self.state.status
		if not self.shade.Visible or self.ackIntent ~= intent or self.intentToken ~= intent.token
			or not result or result.id ~= intent.id or (currentStatus ~= nil and currentStatus ~= "Ready") then return end
		self.ackRetryCount += 1
		self.ackRetryNeededToken = nil
		-- Only explicit pre-dispatch throttle/lock feedback reaches this path.
		-- Reuse the captured ID/revision; never replay a purchase or roll an egg.
		self.sendCommand("ack", intent.id, intent.sourceRevision)
	end)
end

function View:bumpControllerEpoch()
	self.shade:SetAttribute("ControllerEpoch",(self.shade:GetAttribute("ControllerEpoch")or 0)+1)
end
function View:getControllerFocus()
	if self:isStoreOpen() then return self.store:getControllerFocus() end
	if not self.shade.Visible or self.state.lastHatch~=nil then return nil end
	local back=self.shopBackButton or self.closeButton
	return{root=self.shade,epoch=self.shade:GetAttribute("ControllerEpoch")or 0,
		target=function()
			local column=self.body:FindFirstChild("EggColumn");local row=column and column:FindFirstChild("Recipe_"..self.selected)
			return if row and row.Selectable then row else back
		end,fallback=back}
end
function View:openingFocusTarget()
	if self.state.lastHatch and not self.ackReady then return nil end
	if not self.state.lastHatch and self.shopRoot then
		local column=self.body:FindFirstChild("EggColumn");local row=column and column:FindFirstChild("Recipe_"..self.selected)
		return row or self.shopBackButton
	end
	local target = if self.state.lastHatch then self.meetButton else self.action
	return if target.Interactable then target else self.closeButton
end
function View:open(state)
	self:bumpControllerEpoch()
	if not self.shade.Visible then
		self.previousSelection = GuiService.SelectedObject
		self.body.CanvasPosition = Vector2.zero
	end
	self.errorMessage = nil
	self.shade.Visible = true
	self:update(state or self.state)
 if not self.state.lastHatch then self:queueSelectedRecipe()end
	if self:ownsInput() and string.match(UserInputService:GetLastInputType().Name, "^Gamepad") then
		GuiService.SelectedObject = self:openingFocusTarget()
	end
end

function View:close(reason, choice)
	if self:isStoreOpen() then
		-- Back or X leaves the store page first; every other reason closes both.
		if reason == nil or reason == "close" then self.store:close("back"); return end
		self.store:close("forced")
	end
	if self.shade.Visible then self:bumpControllerEpoch()end
	if not self.shade.Visible then return end
 if (reason==nil or reason=="close"or reason=="earn")and self.onAccepted then self.onAccepted(if reason=="earn"then "confirm"else "back")end
	self:revokeIntent()
	self.presentationGeneration += 1
	self.shade.Visible = false
	self:syncEggClock()
	self:syncShopShade()
	if self.revealBackdrop then self.revealBackdrop.Visible = false end
	self.legendToken = nil
	if self.legendLine then self.legendLine.Visible = false end
	self.cinematic:cancel()
	self:restoreRevealParent()
	self.revealHost.Visible = false
	self.playingId, self.ackReady, self.pending, self.retryAvailable = nil, false, false, false
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.shade) then
		GuiService.SelectedObject = self.previousSelection
	end
	if self.onClosed then self.onClosed(reason or "close", choice) end
end

return View
