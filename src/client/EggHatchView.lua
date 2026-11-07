local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Art = require(script.Parent.DeckArt)
local Portrait = require(script.Parent.PetPortrait)
local HatchCinematic = require(script.Parent.HatchCinematic)
local Pets = require(ReplicatedStorage.Shared.PetCatalog)
local Catalog = require(ReplicatedStorage.Shared.EggCatalog)
local EggArt = require(script.Parent.EggArt)

local SaveNotice=require(script.Parent.SaveNotice)
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

local function eggGraphic(parent, recipeId, color, y)
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
	EggArt.create(scene, recipeId, UDim2.new(0.5, -32, 0.5, -44), UDim2.fromOffset(64, 82), scene.ZIndex + 2)
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
	local wallet = frame(card, "Wallet", Art.Canopy, UDim2.new(1, -156, 0, 4), UDim2.fromOffset(146, 29), 22)
	Art.corner(wallet, 10)
	local drop = EggArt.nectar(wallet, UDim2.fromOffset(3, 5), UDim2.fromOffset(19, 20), 23)
	nectar.ZIndex = 25
	local note = label(card, "Notice", "Earn nectar. Choose an egg. Meet a new friend.", UDim2.fromOffset(12, 29),
		UDim2.new(1, -24, 0, 16), Art.Muted, 11)
	local body = Instance.new("ScrollingFrame")
	body.Name, body.Position, body.Size = "Body", UDim2.fromOffset(12, 48), UDim2.new(1, -24, 1, -110)
	body.BackgroundTransparency, body.BorderSizePixel, body.ZIndex = 1, 0, 22
	body.ClipsDescendants=true
	body.ScrollBarThickness, body.ScrollBarImageColor3 = 4, Art.Leaf
	body.ScrollingDirection, body.ElasticBehavior = Enum.ScrollingDirection.Y, Enum.ElasticBehavior.Never
	body.Parent = card
	local close = button(card, "Close", "×", UDim2.new(0, 12, 1, -56), UDim2.new(0.30, -18, 0, 44), Art.Raised, 60)
	Art.close(close)
	local action = button(card, "Action", "Hatch", UDim2.new(0.30, 2, 1, -56), UDim2.new(0.70, -14, 0, 44), Art.Amber, 60)
	local meet = button(card, "Meet", "Meet friend", UDim2.new(0, 12, 1, -56), UDim2.new(0.50, -18, 0, 44), Art.Leaf, 60)
	meet.Visible = false
	local revealHost = frame(card, "RevealHost", Art.Surface, UDim2.fromOffset(10, 10), UDim2.new(1, -20, 1, -80), 40)
	revealHost.Visible = false
	Art.corner(revealHost, 14)
	local self = setmetatable({
		shade = shade, card = card, body = body, heading = heading, nectar = nectar, note = note,
		closeButton = close, action = action, meetButton = meet, revealHost = revealHost, audio = audio, wallet = wallet, walletDrop = drop,
		reduceEffects = reduceEffects, sendCommand = sendCommand, selected = Catalog.Order[1], state = {}, pending = false,
		intentToken = 0,
	}, View)
	self.cinematic = HatchCinematic.new(revealHost, audio, reduceEffects)
	Art.watchTextPreference(shade,function()return shade.Visible end,function()self:layout()end)
	shade:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:layout() end)
	body:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if shade.Visible then self:renderBody() end
	end)
	self:layout()
	close.Activated:Connect(function() self:close("close") end)
	meet.Activated:Connect(function() self:chooseResult("meet") end)
	action.Activated:Connect(function()
		if not shade.Visible or self.pending or not action.Interactable then return end
		local current = self.state
		if current.lastHatch then
			self:chooseResult("play")
		elseif (current.nectar or 0) < Catalog.ById[self.selected].cost then
			self:close("earn")
		else
			self:send("hatch", self.selected)
		end
	end)
	return self
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
function View:headerKey()
	return table.concat({self.heading.Text,self.nectar.Text,self.note.Text,self.selected,tostring(self.state.lastHatch~=nil)},"|")
end
function View:footerRowHeight(button,width)
	local tight=self.compactShop or self.card.Size.X.Offset<400 or self.shade.AbsoluteSize.Y<200
	return math.max(44,Art.textHeight(button,width,0)+(if tight then 8 else 12))
end
function View:layout()
	local size = self.shade.AbsoluteSize
	local result = self.state.lastHatch ~= nil
	local notice=self:getSaveNotice()
	if not (result and notice)then self:restoreRevealParent()else self.note.Parent=self.card end
	local previousBudgetCompact=self.budgetCompact
	local cardW=math.clamp(size.X-32,1,560)
	-- Measure the roomy header/footer first. A landscape safe area may be >280
	-- tall but still leave less than the two ordinary 83px recipe choices need.
	local roomyBody=math.huge
	if not result then
		self.compactShop=false;self:refreshShopHeader()
		Art.type(self.heading,if notice then "Body"else "Heading",false);Art.type(self.nectar,"Body",false);Art.type(self.note,"Supporting",false)
		Art.type(self.action,"Action",cardW<400)
		local titleH=Art.textHeight(self.heading,cardW-80,28)
		local chipW=math.min(math.max(1,cardW-24),math.max(146,Art.textWidth(self.nectar)+44))
		local walletH=Art.textHeight(self.nectar,math.max(1,chipW-36),20)
		local noteH=Art.textHeight(self.note,cardW-24,34)
		local bodyTop=6+math.max(titleH,44)+8+walletH+16+noteH+8
		local footerH=44;local caption=self.action.Text
		for _,id in ipairs(Catalog.Order)do
			local option=Catalog.ById[id];local missing=math.max(0,option.cost-(self.state.nectar or 0))
			self.action.Text=if self.pending then "Saving…" elseif missing>0 then string.format("Play for %s · need %d nectar",option.name,missing)
				else string.format("Hatch %s · %d nectar",option.name,option.cost)
			footerH=math.max(footerH,Art.textHeight(self.action,cardW-24,0)+(if cardW<400 then 8 else 12))
		end
		self.action.Text=caption
		roomyBody=math.clamp(size.Y-32,1,580)-bodyTop-footerH-18
	end
	local compactShop=not result and (size.Y<280 or roomyBody<177)
	self.compactShop=compactShop
	if not result then Art.type(self.action,"Action",compactShop or cardW<400) end
	self.budgetCompact=compactShop and size.Y>=280
	local resetRecipeScroll=self.budgetCompact and (not previousBudgetCompact or self.layoutSize~=size)
	self.layoutSize=size
	-- Keep the two 44px action rows separate even in a short landscape safe area.
	local verticalMargin = if compactShop or (result and size.Y < 200) then 16 else 32
	self.card.Size = UDim2.fromOffset(math.clamp(size.X - 32, 1, 560), math.clamp(size.Y - verticalMargin, 1, 580))
	self.closeButton.Position = UDim2.new(1, -56, 0, 6)
	self.closeButton.Size = UDim2.fromOffset(44, 44)
	self.action.Position = if result then UDim2.new(0.50, 6, 1, -56) else UDim2.new(0, 12, 1, -56)
	self.action.Size = if result then UDim2.new(0.50, -18, 0, 44) else UDim2.new(1, -24, 0, 44)
	self.heading.Position, self.heading.Size = UDim2.fromOffset(12, 6), UDim2.new(1, -80, 0, 28)
	self.nectar.Position, self.nectar.Size = UDim2.fromOffset(40, 40), UDim2.fromOffset(118, 24)
	self.wallet.Position, self.wallet.Size = UDim2.fromOffset(12, 38), UDim2.fromOffset(146, 28)
	self.body.Position, self.body.Size = UDim2.fromOffset(12, 112), UDim2.new(1, -24, 1, -174)
	if compactShop then
		self.closeButton.Position, self.closeButton.Size = UDim2.new(1, -56, 0, 4), UDim2.fromOffset(44, 44)
		self.action.Position, self.action.Size = UDim2.new(0, 8, 1, -48), UDim2.new(1, -16, 0, 44)
		self.heading.Position, self.heading.Size = UDim2.fromOffset(12, 2), UDim2.new(1, -80, 0, 20)
		self.nectar.Position, self.nectar.Size = UDim2.fromOffset(34, 22), UDim2.new(1, -102, 0, 20)
		self.wallet.Position, self.wallet.Size = UDim2.fromOffset(10, 22), UDim2.new(1, -76, 0, 22)
		self.walletDrop.Position, self.walletDrop.Size = UDim2.fromOffset(3, 1), UDim2.fromOffset(19, 20)
		self.body.Position,self.body.Size = UDim2.fromOffset(12,48),UDim2.new(1, -24, 1, -100)
	else
		self.walletDrop.Position, self.walletDrop.Size = UDim2.fromOffset(3, 5), UDim2.fromOffset(19, 20)
	end
	self.wallet.Visible = not result
	self.meetButton.Visible = result
	self.heading.Visible, self.nectar.Visible, self.note.Visible, self.body.Visible = not result, not result, not result and not compactShop, not result
	Art.type(self.heading,if notice then "Body"else "Heading",compactShop)
	Art.type(self.nectar,"Body",compactShop)
	if not compactShop then
		self.note.Position,self.note.Size=UDim2.fromOffset(12,70),UDim2.new(1,-24,0,34)
		Art.type(self.note,"Supporting",false)
	end
	self:refreshShopHeader()
	local cardW=self.card.Size.X.Offset
	local titleH=Art.textHeight(self.heading,cardW-80,if compactShop then 20 else 28)
	-- Measure the amount at its final label width, including the label's real gutters.
	local chipW=math.min(math.max(1,cardW-24),math.max(146,Art.textWidth(self.nectar)+44))
	local amountW=math.max(1,chipW-36)
	local walletH=Art.textHeight(self.nectar,if compactShop then cardW-102 else amountW,20)
	self.compactStatus=compactShop and titleH+walletH>44
	if self.compactStatus then
		self.heading.Position,self.heading.Size=UDim2.fromOffset(12,0),UDim2.new(1,-80,0,44)
		self.nectar.Visible,self.wallet.Visible=false,false
	elseif not compactShop and not result then
		local walletY=6+math.max(titleH,44)+8
		self.heading.Size=UDim2.new(1,-80,0,titleH)
		self.wallet.Position,self.wallet.Size=UDim2.fromOffset(12,walletY),UDim2.fromOffset(chipW,walletH+8)
		self.nectar.Position,self.nectar.Size=UDim2.fromOffset(40,walletY+4),UDim2.fromOffset(amountW,walletH)
		self.walletDrop.Position,self.walletDrop.Size=UDim2.fromOffset(3,(walletH-12)/2),UDim2.fromOffset(19,20)
		local noteY=walletY+walletH+16
		local noteH=Art.textHeight(self.note,cardW-24,34)
		self.note.Position,self.note.Size=UDim2.fromOffset(12,noteY),UDim2.new(1,-24,0,noteH)
		local bodyTop=noteY+noteH+8
		self.body.Position,self.body.Size=UDim2.fromOffset(12,bodyTop),UDim2.new(1,-24,1,-bodyTop-62)
	end
	local footerW=if result then (cardW-36)/2 elseif compactShop then cardW-16 else cardW-24
	local footerH=math.max(44,self:footerRowHeight(self.action,footerW),if result then self:footerRowHeight(self.meetButton,footerW) else 44)
	self.footerHeight=footerH
	self.action.Size=UDim2.new(if result then .5 else 1,if result then -18 else -24,0,footerH)
	self.action.Position=if result then UDim2.new(.5,6,1,-footerH-12) else UDim2.new(0,12,1,-footerH-12)
	self.meetButton.Size,self.meetButton.Position=UDim2.new(.5,-18,0,footerH),UDim2.new(0,12,1,-footerH-12)
	if compactShop then
		self.action.Position,self.action.Size=UDim2.new(0,8,1,-footerH-4),UDim2.new(1,-16,0,footerH)
		self.body.Size=UDim2.new(1,-24,1,-48-footerH-8)
	elseif not result then
		self.body.Size=UDim2.new(1,-24,1,-self.body.Position.Y.Offset-footerH-18)
	end
	if result and notice then
		-- Keep the cinematic's normal dimensions and identity; only its viewport
		-- joins the existing scroll owner when a persistent instruction needs room.
		self.heading.Visible=true;self.heading.Text=notice.short;Art.type(self.heading,"Body",true)
		self.heading.Position,self.heading.Size=UDim2.fromOffset(12,4),UDim2.new(1,-80,0,44)
		self.body.Visible=true
		local top=48;local gap=if self.shade.AbsoluteSize.Y<200 then 4 else 12
		self.action.Position,self.meetButton.Position=UDim2.new(.5,6,1,-footerH-gap),UDim2.new(0,12,1,-footerH-gap)
		self.body.Position,self.body.Size=UDim2.fromOffset(12,top),UDim2.new(1,-24,1,-top-footerH-gap-4)
		self.revealHost.Size=UDim2.fromOffset(math.max(1,cardW-20),math.max(1,self.card.Size.Y.Offset-80))
		self.revealHost.Parent=self.body;self.revealHost.Position=UDim2.fromOffset(0,0)
		for _,child in ipairs(self.body:GetChildren())do if child~=self.revealHost then child:Destroy()end end
		self.note.Parent=self.body;self.note.Visible=true;self.note.Text=notice.detail;Art.type(self.note,"Body",true)
		local heroH=self.revealHost.Size.Y.Offset
		local h=Art.textHeight(self.note,cardW-32,24)
		self.note.Position,self.note.Size=UDim2.fromOffset(4,heroH+8),UDim2.fromOffset(cardW-32,h)
		local total=heroH+8+h+4
		self.body.CanvasSize=UDim2.fromOffset(0,total);self.body.ScrollingEnabled=total>self.body.Size.Y.Offset
		self.body.CanvasPosition=Vector2.new(0,math.clamp(self.body.CanvasPosition.Y,0,math.max(0,total-self.body.Size.Y.Offset)))
	end
	self.layoutHeaderKey=self:headerKey()
	if self.shade.Visible then
		self:renderBody()
		if resetRecipeScroll then self.body.CanvasPosition=Vector2.zero end
	end
	if not result and not self.refreshingFooterLayout then
		self.refreshingFooterLayout=true;self:refreshFooter();self.refreshingFooterLayout=nil
	end
end

function View:refreshShopHeader()
	local notice=self:getSaveNotice()
	self.heading.Text=if notice then notice.short else "Hatch eggs"
	self.nectar.Text=string.format("%d nectar",self.state.nectar or 0)
	self.note.Visible=self.state.lastHatch==nil and not self.compactShop
	self.note.Text=if notice then notice.detail else self.errorMessage or self.state.message or "Earn nectar. Choose an egg. Meet a new friend."
	if notice or not self.compactShop then return end
	local status,message=self.state.status,self.errorMessage
	if self.pending or status=="Busy"or status=="Pending"then
		self.heading.Text="Saving…";self.nectar.Text="Finishing your last action…"
	elseif message then
		self.heading.Text="Try again"
		self.nectar.Text=if message=="One moment…"then "One moment · try again"
			elseif message=="Your hatch progress updated. Try again."or message=="RevisionChanged"then "Progress updated · try again"
			elseif message=="Earn more nectar in a field run."then "Need more nectar · play a run"
			elseif message=="Finishing your last save…"or message=="Finishing your last hatch action…"then "Finishing your last save…"
			else "Action unavailable · try again"
	end
end

function View:revokeIntent()
	self.intentToken += 1
	self.ackIntent = nil
	self.ackRetryScheduledToken = nil
	self.ackRetryNeededToken = nil
end

function View:chooseResult(intent)
	local result = self.state.lastHatch
	if (intent ~= "meet" and intent ~= "play") or not self.shade.Visible or not result
		or not self.ackReady or self.pending or self.ackIntent
		or (self.state.status ~= nil and self.state.status ~= "Ready") then return end
	self.intentToken += 1
	self.ackRetryCount, self.retryAvailable = 0, false
	-- Install this before send: a local transport can synchronously deliver Ready.
	self.ackIntent = table.freeze({ id = result.id, petId = result.petId, intent = intent,
		sourceRevision = self.state.revision or 0, token = self.intentToken })
	self:send("ack", result.id)
end

function View:selectResultAction()
	if not string.match(UserInputService:GetLastInputType().Name, "^Gamepad") then return end
	local selected = GuiService.SelectedObject
	if selected == self.closeButton then return end
	GuiService.SelectedObject = if self.meetButton.Interactable then self.meetButton else nil
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
		textValue, canAct = if self.ackReady then (if self.retryAvailable then "Try again" else "Play again") else "Hatching…", self.ackReady
		local pet = Pets.byId[state.lastHatch.petId]
		self.meetButton.Text = if self.pending then "Saving…" elseif self.shade.AbsoluteSize.Y<200 or self.card.Size.X.Offset<400 then "Meet" else "Meet " .. (if pet then pet.name else "friend")
	else
		local recipe = Catalog.ById[self.selected]
		local missing = math.max(0, recipe.cost - (state.nectar or 0))
		textValue = if missing > 0 then string.format("Play for %s · need %d nectar", recipe.name, missing)
			else string.format("Hatch %s · %d nectar", recipe.name, recipe.cost)
		canAct = true
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
	if self.compactShop and not state.lastHatch and not self.pending then
		local recipe=Catalog.ById[self.selected]
		local missing=math.max(0,recipe.cost-(state.nectar or 0))
		local budget=math.max(44,self.card.Size.Y.Offset-48-44-8)
		local width=self.card.Size.X.Offset-16
		if self:footerRowHeight(self.action,width)>budget then
			local candidates=if missing>0 then {"Play · need "..missing.." nectar","Play · need "..missing,"Play for nectar"}
				else {"Hatch · "..recipe.cost.." nectar","Hatch"}
			for _,caption in ipairs(candidates) do
				self.action.Text=caption
				if self:footerRowHeight(self.action,width)<=budget then break end
			end
		end
	end
	self.action.Interactable = ready and not self.pending and canAct == true
	self.action.TextTransparency=0
	self.action.BackgroundColor3=if state.lastHatch then Art.Raised else Art.Amber
	self.action.TextColor3=if not self.action.Interactable then Art.Muted elseif state.lastHatch then Art.Silver else Art.Ink
	self.meetButton.Interactable = state.lastHatch ~= nil and self.action.Interactable
	self.meetButton.TextTransparency=0
	self.meetButton.TextColor3=if self.meetButton.Interactable then Art.Ink else Art.Silver
	local width=if state.lastHatch then (self.card.Size.X.Offset-36)/2 elseif self.compactShop then self.card.Size.X.Offset-16 else self.card.Size.X.Offset-24
	local needed=math.max(self:footerRowHeight(self.action,width),if state.lastHatch then self:footerRowHeight(self.meetButton,width) else 44)
	self:refreshShopHeader()
	if self.footerHeight and (self.footerHeight~=needed or self.layoutHeaderKey~=self:headerKey()) then self:layout() end
end

function View:renderBody()
	if self.state.lastHatch or self.renderingBody then return end
	self.renderingBody = true
	local canvasPosition = self.body.CanvasPosition
	self.revealHost.Visible = false
	self:restoreRevealParent()
	self.body:ClearAllChildren()
	local size = self.body.AbsoluteSize
	local compact = self.compactShop == true
	local split = not compact and size.X >= 470
	local columnWidth = if split then (size.X - 18) / 2 else math.max(1, size.X - 6)
	local left = frame(self.body, "EggColumn", Art.Ink, UDim2.fromOffset(0, 0), UDim2.fromOffset(columnWidth, 0))
	left.BackgroundTransparency = 1
	local state = self.state
	local recipe = Catalog.ById[self.selected]
	local recipeStep = if compact then 52 else 91
	local compactTextX = 36
	local startY=0
	local notice=self:getSaveNotice()
	if compact and notice then
		local detail=Art.text(left,"SaveInstruction",notice.detail,UDim2.fromOffset(3,0),UDim2.fromOffset(columnWidth-9,24),Art.Amber,14)
		Art.type(detail,"Body",true);local h=Art.textHeight(detail,columnWidth-9,24)
		detail.Size=UDim2.fromOffset(columnWidth-9,h);startY=h+12
	end
	for index, id in ipairs(Catalog.Order) do
		local option = Catalog.ById[id]
		local y = startY+(if compact then math.floor((index - 1) / 2) else index - 1) * recipeStep + (if compact then 0 else 3)
		local position = if compact then UDim2.new((index - 1) % 2 * 0.5, 2, 0, y) else UDim2.fromOffset(2, y)
		local choice = button(left, "Recipe_" .. id, "", position, UDim2.new(if compact then 0.5 else 1, if compact then -6 else -7, 0, if compact then 44 else 83),
			if self.selected == id then Art.Raised else Art.Surface)
		if self.selected == id then Art.stroke(choice, Art.Amber, 0, 2) end
		EggArt.create(choice, id, if compact then UDim2.fromOffset(6, 6) else UDim2.fromOffset(12, 8),
			if compact then UDim2.fromOffset(24, 32) else UDim2.fromOffset(52, 66), choice.ZIndex + 2)
		local recipeName = label(choice, "RecipeName", option.name,
			if compact then UDim2.fromOffset(compactTextX, 1) else UDim2.fromOffset(76, 9),
			if compact then UDim2.new(1, -compactTextX - 5, 0, 25) else UDim2.new(1, -82, 0, 32), Art.Silver, if compact then 14 else 16)
		local costLabel = label(choice, "Cost", string.format(if compact then "%d nectar" else "%d nectar per hatch", option.cost),
			if compact then UDim2.fromOffset(compactTextX, 28) else UDim2.fromOffset(76, 45),
			if compact then UDim2.new(1, -compactTextX - 5, 0, 14) else UDim2.new(1, -82, 0, 26), Art.Amber, 12)
		if compact then
			Art.fitText(recipeName, 14, 9, 0, true)
			Art.fitText(costLabel, 12, 9, 0, false)
			for _, node in ipairs({ recipeName, costLabel }) do
				local inset = node:FindFirstChildOfClass("UIPadding")
				inset.PaddingTop, inset.PaddingBottom = UDim.new(0, 0), UDim.new(0, 0)
			end
		end
		choice.Activated:Connect(function() self:selectRecipe(id) end)
	end
	local y = startY+(if compact then math.ceil(#Catalog.Order / 2) * recipeStep else #Catalog.Order * recipeStep + 8)
	if compact and self.compactStatus then
		local status=Art.text(left,"CompactStatus",self.nectar.Text,UDim2.fromOffset(3,y),UDim2.new(1,-9,0,24),Art.Muted,12)
		Art.type(status,"Supporting",true)
		local h=Art.textHeight(status,columnWidth-9,24);status.Size=UDim2.new(1,-9,0,h);y+=h+8
	end
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
	eggGraphic(left, self.selected, recipe.color or Art.Leaf, y + 97)
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
	self.body.CanvasPosition = Vector2.new(0, math.clamp(canvasPosition.Y, 0, math.max(0, canvasHeight + 6 - size.Y)))
	self.renderingBody = false
end

function View:selectRecipe(id)
	if self.pending or self.state.lastHatch or not Catalog.ById[id] then return false end
	self.selected = id
	self:renderBody()
	local row = self.body.EggColumn:FindFirstChild("Recipe_" .. id)
	if row then
		local top, height = row.Position.Y.Offset, self.body.AbsoluteSize.Y
		local current = self.body.CanvasPosition.Y
		local wanted = if top < current then top elseif top + row.Size.Y.Offset > current + height then top + row.Size.Y.Offset - height else current
		self.body.CanvasPosition = Vector2.new(0, math.clamp(wanted, 0, math.max(0, self.body.CanvasSize.Y.Offset - height)))
	end
	self:refreshFooter()
	self.audio:play("aim", 1, 0.4)
	return true
end

function View:update(state)
	self.state = state or {}
	if self.errorMessage and self.errorRevision and self.state.status=="Ready" and (self.state.revision or 0)>self.errorRevision then self.errorMessage,self.errorRevision=nil,nil end
	local intent = self.ackIntent
	local result = self.state.lastHatch
	if intent and result and result.id ~= intent.id then
		self:revokeIntent()
		intent = nil
	end
	if intent and self.shade.Visible and self.state.status == "Ready" and not result
		and (self.state.revision or 0) > intent.sourceRevision and intent.token == self.intentToken then
		-- Dequeue before callbacks, which can synchronously reopen/update this view.
		self:revokeIntent()
		self.pending = false
		self:close(if intent.intent == "meet" then "meet" else "afterHatch", intent)
		return
	end
	self.pending = self.ackIntent ~= nil or self.state.status == "Busy"
	self.nectar.Text = string.format("%d nectar", self.state.nectar or 0)
	self.note.Text = self.errorMessage or self.state.message or "Earn nectar. Choose an egg. Meet a new friend."
	self:layout()
	if self.shade.Visible then
		if result then
			self.revealHost.Visible = true
			if self.playingId ~= result.id then
				self.playingId, self.ackReady = result.id, false
				local presentation = table.clone(result)
				local pet = Pets.byId[result.petId]
				local family = result.family or (pet and (pet.family or pet.id))
				local mastery = self.state.masteryDetails and self.state.masteryDetails[family]
				if result.duplicate and mastery then
					presentation.masteryHint = if mastery.rank >= 3 then "+1 mark · family mastered"
						elseif mastery.rank == 2 then string.format("+1 mark · %d/%d marks · %d/%d challenges for III",
							mastery.points, mastery.nextPoints, mastery.challenges, mastery.challengeGoal)
						else string.format("+1 mark · %d/%d marks for rank %s", mastery.points, mastery.nextPoints,
							({ "I", "II", "III" })[mastery.rank + 1])
				end
				if result.starter then
					local recipe = Catalog.ById[self.selected]
					local balance = self.state.nectar or 0
					presentation.starterGoal = if balance >= recipe.cost then recipe.name .. " ready · choose it in Menu"
						else string.format("%s · %d/%d nectar · win quests", recipe.name, balance, recipe.cost)
				end
				self.cinematic:play(presentation, function()
					if self.shade.Visible and self.state.lastHatch and self.state.lastHatch.id == result.id then
						self.ackReady = true
						self:refreshFooter()
						self:selectResultAction()
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
	self.note.Text = message or "Earn nectar. Choose an egg. Meet a new friend."
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

function View:open(state)
	if not self.shade.Visible then
		self.previousSelection = GuiService.SelectedObject
		self.body.CanvasPosition = Vector2.zero
	end
	self.errorMessage = nil
	self.shade.Visible = true
	self:update(state or self.state)
	if self.shade.Visible and string.match(UserInputService:GetLastInputType().Name, "^Gamepad") then
		GuiService.SelectedObject = if self.state.lastHatch then (if self.ackReady then self.meetButton else nil) else self.action
	end
end

function View:close(reason, choice)
	if not self.shade.Visible then return end
	self:revokeIntent()
	self.shade.Visible = false
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
