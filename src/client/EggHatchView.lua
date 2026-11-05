local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Art = require(script.Parent.DeckArt)
local Portrait = require(script.Parent.PetPortrait)
local HatchCinematic = require(script.Parent.HatchCinematic)
local Pets = require(ReplicatedStorage.Shared.PetCatalog)
local Catalog = require(ReplicatedStorage.Shared.EggCatalog)

local View = {}
View.__index = View

local function frame(parent, name, color, position, size, z)
	return Art.frame(parent, name, color, position, size, z or 23)
end

local function label(parent, name, content, position, size, color, maximum)
	local node = Art.text(parent, name, content, position, size, color or Art.Silver, maximum or 14,
		Enum.Font.GothamMedium)
	Art.fitText(node, maximum or 14, 10, 4, true)
	return node
end

local function button(parent, name, content, position, size, color, z)
	local node = Instance.new("TextButton")
	node.Name, node.Text, node.Position, node.Size = name, content, position, size
	node.BackgroundColor3 = color or Art.Raised
	node.TextColor3 = if color == Art.Amber or color == Art.Leaf then Art.Ink else Art.Silver
	node.Font, node.TextSize, node.ZIndex = Enum.Font.GothamBold, 14, z or 24
	node.BorderSizePixel, node.Parent = 0, parent
	Art.button(node, 10)
	Art.fitText(node, 14, 10, 8, true)
	return node
end

local function eggGraphic(parent, color, y)
	local scene = frame(parent, "EggStand", Art.Ink, UDim2.fromOffset(0, y), UDim2.new(1, -5, 0, 112))
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
	local egg = frame(scene, "Egg", color:Lerp(Art.Silver, 0.68), UDim2.new(0.5, -25, 0.5, -35), UDim2.fromOffset(50, 65))
	Art.corner(egg, 1000)
	Art.shade(egg, 1, 0.78)
	Art.stroke(egg, color, 0.12, 2)
	local glint = frame(egg, "Glint", Art.Silver, UDim2.fromScale(0.22, 0.18), UDim2.fromOffset(12, 5))
	glint.Rotation = -26
	Art.corner(glint, 3)
end

function View.new(parent, audio, reduceEffects, sendCommand)
	local shade = frame(parent, "EggHatchView", Art.Ink, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 20)
	shade.BackgroundTransparency, shade.Active, shade.Visible = 1, true, false
	local card = frame(shade, "Card", Art.Surface, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(560, 540), 21)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	Art.panel(card, 16, Art.Amber)
	local heading = label(card, "Heading", "EGG DROP • HATCH", UDim2.fromOffset(12, 6), UDim2.new(1, -148, 0, 24), Art.Silver, 20)
	heading.Font = Enum.Font.GothamBold
	local nectar = label(card, "Nectar", "0 nectar", UDim2.new(1, -134, 0, 7), UDim2.fromOffset(122, 23), Art.Amber, 16)
	local note = label(card, "Notice", "Earn nectar. Choose an egg. Meet a new friend.", UDim2.fromOffset(12, 29),
		UDim2.new(1, -24, 0, 16), Art.Muted, 11)
	local body = Instance.new("ScrollingFrame")
	body.Name, body.Position, body.Size = "Body", UDim2.fromOffset(12, 48), UDim2.new(1, -24, 1, -110)
	body.BackgroundTransparency, body.BorderSizePixel, body.ZIndex = 1, 0, 22
	body.ScrollBarThickness, body.ScrollBarImageColor3 = 4, Art.Leaf
	body.ScrollingDirection, body.ElasticBehavior = Enum.ScrollingDirection.Y, Enum.ElasticBehavior.Never
	body.Parent = card
	local close = button(card, "Close", "Close", UDim2.new(0, 12, 1, -56), UDim2.new(0.30, -18, 0, 44), Art.Raised, 60)
	local action = button(card, "Action", "Hatch", UDim2.new(0.30, 2, 1, -56), UDim2.new(0.70, -14, 0, 44), Art.Amber, 60)
	local revealHost = frame(card, "RevealHost", Art.Surface, UDim2.fromOffset(10, 10), UDim2.new(1, -20, 1, -80), 40)
	revealHost.Visible = false
	Art.corner(revealHost, 14)
	local self = setmetatable({
		shade = shade, card = card, body = body, heading = heading, nectar = nectar, note = note,
		closeButton = close, action = action, revealHost = revealHost, audio = audio,
		reduceEffects = reduceEffects, sendCommand = sendCommand, selected = Catalog.Order[1], state = {}, pending = false,
	}, View)
	self.cinematic = HatchCinematic.new(revealHost, audio, reduceEffects)
	local function layout()
		local size = shade.AbsoluteSize
		card.Size = UDim2.fromOffset(math.clamp(size.X - 32, 1, 560), math.clamp(size.Y - 32, 1, 580))
		if shade.Visible then self:renderBody() end
	end
	shade:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	body:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if shade.Visible then self:renderBody() end
	end)
	layout()
	close.Activated:Connect(function() self:close("close") end)
	action.Activated:Connect(function()
		if not shade.Visible or self.pending or not action.Interactable then return end
		local current = self.state
		if current.lastHatch then
			if not self.ackReady then return end
			self.ackRequested = current.lastHatch.id
			self:send("ack", current.lastHatch.id)
		elseif (current.nectar or 0) < Catalog.ById[self.selected].cost then
			self:close("earn")
		else
			self:send("hatch", self.selected)
		end
	end)
	return self
end

function View:send(command, value)
	if self.pending then return end
	self.pending = true
	self.errorMessage = nil
	self:refreshFooter()
	self.audio:play("menu", 1, 0.40)
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
		textValue, canAct = if self.ackReady then "Try another run" else "Hatching…", self.ackReady
	else
		local recipe = Catalog.ById[self.selected]
		local missing = math.max(0, recipe.cost - (state.nectar or 0))
		textValue = if missing > 0 then string.format("Play a run · need %d nectar", missing)
			else string.format("Hatch · %d nectar", recipe.cost)
		canAct = true
	end
	self.action.Text = if self.pending then "Saving…" else textValue
	self.action.Interactable = ready and not self.pending and canAct == true
	self.action.TextTransparency = if self.action.Interactable then 0 else 0.40
end

function View:renderBody()
	if self.state.lastHatch then return end
	self.revealHost.Visible = false
	self.body:ClearAllChildren()
	local size = self.body.AbsoluteSize
	local split = size.X >= 470
	local columnWidth = if split then (size.X - 18) / 2 else math.max(1, size.X - 6)
	local left = frame(self.body, "EggColumn", Art.Ink, UDim2.fromOffset(0, 0), UDim2.fromOffset(columnWidth, 0))
	left.BackgroundTransparency = 1
	local state = self.state
	local recipe = Catalog.ById[self.selected]
	for index, id in ipairs(Catalog.Order) do
		local option = Catalog.ById[id]
		local y = (index - 1) * 91 + 3
		local choice = button(left, "Recipe_" .. id, "", UDim2.fromOffset(2, y), UDim2.new(1, -7, 0, 83),
			if self.selected == id then Art.Raised else Art.Surface)
		if self.selected == id then Art.stroke(choice, Art.Amber, 0, 2) end
		local egg = frame(choice, "Egg", (option.color or Art.Leaf):Lerp(Art.Silver, 0.65), UDim2.fromOffset(13, 14), UDim2.fromOffset(37, 49))
		Art.corner(egg, 1000)
		Art.stroke(egg, option.color or Art.Leaf, 0.12, 2)
		label(choice, "RecipeName", option.name, UDim2.fromOffset(59, 7), UDim2.new(1, -65, 0, 33), Art.Silver, 16)
		label(choice, "Cost", string.format("%d nectar per hatch", option.cost), UDim2.fromOffset(59, 41),
			UDim2.new(1, -65, 0, 26), Art.Amber, 12)
		choice.Activated:Connect(function()
			if self.pending or self.state.lastHatch then return end
			self.selected = id
			self.body.CanvasPosition = Vector2.zero
			self:renderBody()
			self:refreshFooter()
			self.audio:play("aim", 1, 0.4)
		end)
	end
	local y = #Catalog.Order * 91 + 8
	label(left, "NectarProgress", string.format("%d / %d nectar", state.nectar or 0, recipe.cost),
		UDim2.fromOffset(3, y), UDim2.new(1, -9, 0, 21), Art.Leaf, 13)
	local track = frame(left, "NectarTrack", Art.Ink, UDim2.fromOffset(7, y + 24), UDim2.new(1, -18, 0, 6))
	Art.corner(track, 3)
	local fill = frame(track, "Fill", Art.Amber, UDim2.fromOffset(0, 0),
		UDim2.fromScale(math.clamp((state.nectar or 0) / recipe.cost, 0, 1), 1))
	Art.corner(fill, 3)
	local dailyTitle = if state.dailyAvailable then string.format("Daily nectar +%d", state.dailyBonus or 6)
		elseif state.dailyDay then "Daily nectar claimed" else "Daily nectar loading…"
	local daily = button(left, "DailyNectar", dailyTitle, UDim2.fromOffset(3, y + 41), UDim2.new(1, -9, 0, 44), Art.Raised)
	daily.Interactable = state.dailyAvailable == true and state.dailyDay ~= nil and not self.pending
		and (state.status == nil or state.status == "Ready")
	daily.TextTransparency = if daily.Interactable then 0 else 0.4
	daily.Activated:Connect(function()
		if daily.Interactable and self.shade.Visible then self:send("daily", self.state.dailyDay) end
	end)
	eggGraphic(left, recipe.color or Art.Leaf, y + 97)
	local leftHeight = y + 215
	left.Size = UDim2.fromOffset(columnWidth, leftHeight)
	local rightY = if split then 0 else leftHeight + 10
	local rightX = if split then columnWidth + 12 else 0
	local odds = frame(self.body, "OutcomeColumn", Art.Ink, UDim2.fromOffset(rightX, rightY), UDim2.fromOffset(columnWidth, 20))
	odds.BackgroundTransparency = 1
	label(odds, "OddsHeading", "POSSIBLE HATCHES", UDim2.fromOffset(0, 1), UDim2.new(1, -2, 0, 22), Art.Leaf, 12)
	local misses = state.misses or 0
	local rows = Catalog.odds(self.selected, misses)
	for index, outcome in ipairs(rows) do
		local pet = Pets.byId[outcome.id]
		if not pet then continue end
		local row = frame(odds, "Outcome_" .. outcome.id, Art.Raised, UDim2.fromOffset(2, 27 + (index - 1) * 29), UDim2.new(1, -7, 0, 26))
		Art.corner(row, 6)
		Portrait.create(row, pet, 1, UDim2.fromOffset(15, 13), 25)
		local name = label(row, "Name", pet.name, UDim2.fromOffset(29, 0), UDim2.new(1, -77, 1, 0),
			if pet.trial then Art.Amber else Art.Silver, 12)
		name.TextXAlignment = Enum.TextXAlignment.Left
		label(row, "Probability", string.format("%.0f%%", outcome.weight), UDim2.new(1, -47, 0, 0),
			UDim2.fromOffset(44, 26), Art.Silver, 12)
	end
	local protectionY = 31 + #rows * 29
	local protection = if misses >= 7 then "Your next hatch is guaranteed rare"
		else string.format("Rare protection  %d / 7\nAfter 7 non-rares, the next hatch is rare", misses)
	label(odds, "RareProtection", protection, UDim2.fromOffset(2, protectionY), UDim2.new(1, -7, 0, 43), Art.Muted, 11)
	label(odds, "Duplicates", "Already owned? Gain family mastery.", UDim2.fromOffset(2, protectionY + 48),
		UDim2.new(1, -7, 0, 31), Art.Muted, 11)
	local rightHeight = protectionY + 84
	odds.Size = UDim2.fromOffset(columnWidth, rightHeight)
	local canvasHeight = if split then math.max(leftHeight, rightHeight) else rightY + rightHeight
	self.body.CanvasSize = UDim2.fromOffset(0, canvasHeight + 6)
	self.body.ScrollingEnabled = canvasHeight + 6 > size.Y
end

function View:update(state)
	self.state = state or {}
	self.pending = self.state.status == "Busy"
	self.nectar.Text = string.format("%d nectar", self.state.nectar or 0)
	self.note.Text = self.errorMessage or self.state.message or "Earn nectar. Choose an egg. Meet a new friend."
	if self.state.status and self.state.status ~= "Ready" and self.state.status ~= "Busy" then
		self.note.Text = "Egg save unavailable · try again shortly"
	end
	if self.ackRequested and not self.state.lastHatch then
		self.ackRequested = nil
		self:close("afterHatch")
		return
	end
	if self.shade.Visible then
		local result = self.state.lastHatch
		if result then
			self.revealHost.Visible = true
			if self.playingId ~= result.id then
				self.playingId, self.ackReady = result.id, false
				self.cinematic:play(result, function()
					if self.shade.Visible and self.state.lastHatch and self.state.lastHatch.id == result.id then
						self.ackReady = true
						self:refreshFooter()
					end
				end)
			end
		else
			if self.playingId then self.cinematic:cancel() end
			self.playingId, self.ackReady = nil, false
			self:renderBody()
		end
	end
	self:refreshFooter()
end

function View:setError(message)
	self.pending = false
	if self.state.status ~= "Retrying" then self.ackRequested = nil end
	self.errorMessage = message
	self.note.Text = message or "Earn nectar. Choose an egg. Meet a new friend."
	self:refreshFooter()
end

function View:open(state)
	if not self.shade.Visible then
		self.previousSelection = GuiService.SelectedObject
		self.body.CanvasPosition = Vector2.zero
	end
	self.errorMessage = nil
	self.shade.Visible = true
	self:update(state or self.state)
	if self.shade.Visible and string.match(UserInputService:GetLastInputType().Name, "^Gamepad") then
		GuiService.SelectedObject = if self.state.lastHatch then self.closeButton else self.action
	end
end

function View:close(reason)
	if not self.shade.Visible then return end
	self.shade.Visible = false
	self.cinematic:cancel()
	self.revealHost.Visible = false
	self.playingId, self.ackReady, self.ackRequested = nil, false, nil
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.shade) then
		GuiService.SelectedObject = self.previousSelection
	end
	if self.onClosed then self.onClosed(reason or "close") end
end

return View
