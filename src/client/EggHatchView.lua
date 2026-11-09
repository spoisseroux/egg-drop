local Stars=require(script.Parent.StarText)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService=game:GetService("TextService")
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
	local node = Art.text(parent, name, content, position, size, color or "text", maximum or 14,
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
	local nectar = label(card, "Nectar", "0 Stars", UDim2.new(1, -134, 0, 7), UDim2.fromOffset(122, 23), Art.Amber, 16)
	local wallet = frame(card, "Wallet", Art.Canopy, UDim2.new(1, -156, 0, 4), UDim2.fromOffset(146, 29), 22)
	Art.corner(wallet, 10)
	local drop = EggArt.nectar(wallet, UDim2.fromOffset(3, 5), UDim2.fromOffset(19, 20), 23)
	nectar.Parent=wallet;nectar.ZIndex = 25
	local note = label(card, "Notice", "Earn Stars. Choose an egg. Meet a new friend.", UDim2.fromOffset(12, 29),
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
	local revealHost = frame(card, "RevealHost", "inset", UDim2.fromOffset(10, 10), UDim2.new(1, -20, 1, -80), 40)
	revealHost.Visible = false
	Art.corner(revealHost, 14)
	local self = setmetatable({
		shade = shade, card = card, body = body, heading = heading, nectar = nectar, note = note,
		closeButton = close, action = action, meetButton = meet, revealHost = revealHost, audio = audio, wallet = wallet, walletDrop = drop,
		reduceEffects = reduceEffects, sendCommand = sendCommand, selected = Catalog.Order[1], state = {}, pending = false,
		intentToken = 0, presentationGeneration = 0,
	}, View)
	self.cinematic = HatchCinematic.new(revealHost, audio, reduceEffects, function()
		return shade.Visible and (not self.ownsPresentation or self.ownsPresentation())
	end)
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
	return table.concat({self.headerTitle or self.heading.Text,self.nectar.Text,self.statusText or "",self.selected,tostring(self.state.lastHatch~=nil)},"|")
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
	for _,id in ipairs(Catalog.Order)do
		local option=Catalog.ById[id]
		nameH=math.max(nameH,nativeHeight(option.name,if compact then 14 else 16,Art.Font.Body,textW))
		costH=math.max(costH,nativeHeight(string.format(if compact then "%d Stars"else "%d Stars per hatch",option.cost),12,Art.Font.Body,textW))
	end
	return{columns=columns,width=choiceW,textX=textX,textWidth=textW,nameH=nameH,costH=costH,height=math.max(if compact then 44 else 83,nameH+costH+3+8),artH=if compact then 32 else 66}
end
function View:layoutShop()
	if self.layingOut then return end;self.layingOut=true
	self.bodyFocusFallback=false
	self:restoreRevealParent();self:refreshShopHeader()
	local size=self.shade.AbsoluteSize;local cardW=math.clamp(size.X-32,1,560)
	local short=size.Y<280
	local notice=self:getSaveNotice()
	self.wallet.Parent,self.nectar.Parent=self.card,self.wallet
	self.wallet.Visible,self.heading.Visible,self.nectar.Visible,self.body.Visible=true,true,true,true
	self.meetButton.Visible,self.revealHost.Visible=false,false
	self.headerPlan=Art.sheetHeader(cardW,self.heading,self.wallet,self.nectar,self.walletDrop,self.closeButton,{
		pad=10,top=0,amount=self.state.nectar or 0,title=self.headerTitle,shortTitle=self.headerShortTitle,
		accessibleTitle=if notice then notice.detail else self.statusText or "Companion eggs",status=self.statusText~=nil})
	local bodyW=cardW-24;local roomyColumn=if bodyW>=470 then (bodyW-18)/2 else bodyW-6
	local roomy=self:recipeMetrics(roomyColumn,false,1)
	local roomyFooter=44;local oldText=self.action.Text
	Art.type(self.action,"Action",cardW<400)
	for _,id in ipairs(Catalog.Order)do
		local recipe=Catalog.ById[id];local missing=math.max(0,recipe.cost-(self.state.nectar or 0))
		self.action.Text=if missing>0 then Stars.format("Play for %s · need %d Stars",recipe.name,missing)else Stars.format("Hatch %s · %d Stars",recipe.name,recipe.cost)
		roomyFooter=math.max(roomyFooter,Art.actionHeight(self.action,cardW-24))
	end
	self.action.Text=oldText
	local roomyBudget=math.min(580,size.Y-32)-self.headerPlan.height-8-roomyFooter-18
	self.compactShop=short or roomyBudget<roomy.height*2+16
	self.budgetCompact=self.compactShop and not short
	self.card.Size=UDim2.fromOffset(cardW,math.clamp(size.Y-(if self.compactShop then 16 else 32),1,580))
	Art.type(self.action,"Action",self.compactShop or cardW<400)
	local footerH=math.max(44,self:footerRowHeight(self.action,cardW-24));self.footerHeight=footerH
	local footerGap=if self.compactShop then 4 else 12
	self.action.Position,self.action.Size=UDim2.new(0,12,1,-footerH-footerGap),UDim2.new(1,-24,0,footerH)
	local top=self.headerPlan.height+(if short then 4 else 8)
	Art.type(self.note,"Supporting",true)
	self.note.Text=self.statusText or "Earn Stars. Choose an egg. Meet a new friend."
	local noteH=Art.textHeight(self.note,bodyW,0)
	self.notePinned=self.statusText~=nil and self.card.Size.Y.Offset-top-footerH-footerGap-noteH-12>=44
	self.note.Visible=self.notePinned
	if self.notePinned then
		self.note.Position,self.note.Size=UDim2.fromOffset(12,top),UDim2.fromOffset(bodyW,noteH)
		top+=noteH+6
	end
	local bodyH=math.max(44,self.card.Size.Y.Offset-top-footerH-footerGap-4)
	self.body.Position,self.body.Size=UDim2.fromOffset(12,top),UDim2.fromOffset(bodyW,bodyH)
	local metrics=self:recipeMetrics(if self.compactShop then bodyW-6 else roomyColumn,self.compactShop)
	if self.compactShop and metrics.height+8>bodyH then
		local single=self:recipeMetrics(bodyW-6,true,1)
		if single.height<metrics.height then metrics=single end
	end
	self.recipeLayout=metrics
	local arrangement=tostring(self.compactShop)..":"..metrics.columns..":"..cardW
	local changed=self.recipeArrangement~=arrangement;self.recipeArrangement=arrangement
	self.layoutHeaderKey=self:headerKey();self.layingOut=false
	if self.shade.Visible then
		self:renderBody()
		if changed and not self.bodyFocusFallback then self:ensureSelectedRecipe();self:queueSelectedRecipe()end
	end
	if not self.refreshingFooterLayout then self.refreshingFooterLayout=true;self:refreshFooter();self.refreshingFooterLayout=nil end
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
	local top,height=row.Position.Y.Offset,self.body.AbsoluteSize.Y;local current=self.body.CanvasPosition.Y
	local wanted=if row.Size.Y.Offset>height then math.max(0,top-4)elseif top<current then math.max(0,top-4)elseif top+row.Size.Y.Offset>current+height then top+row.Size.Y.Offset-height else current
	self.body.CanvasPosition=Vector2.new(0,math.clamp(wanted,0,math.max(0,self.body.CanvasSize.Y.Offset-height)))
end
function View:layout()
	if not self.state.lastHatch then return self:layoutShop() end
	if self.layingOutResult then return end
	self.layingOutResult = true
	local size = self.shade.AbsoluteSize
	local notice = self:getSaveNotice()
	self.compactShop, self.budgetCompact = false, false
	self.card.Size = UDim2.fromOffset(math.clamp(size.X-32,1,560), math.clamp(size.Y-(if size.Y<200 then 16 else 32),1,580))
	self.closeButton.Position, self.closeButton.Size = UDim2.new(1,-56,0,6), UDim2.fromOffset(44,44)
	self.wallet.Visible, self.heading.Visible, self.nectar.Visible, self.note.Visible = false, false, false, false
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
	self.nectar.Text=tostring(self.state.nectar or 0)
	self.statusText=if notice then notice.detail elseif self.pending or self.state.status=="Busy"or self.state.status=="Pending"then "Finishing your last action…"else self.errorMessage or self.state.message
	self.headerTitle=if notice then notice.short elseif self.pending or self.state.status=="Busy"or self.state.status=="Pending"then "Saving…"elseif self.errorMessage then "Try again"else "Hatch eggs"
	self.headerShortTitle=if notice then notice.narrow elseif self.statusText then self.headerTitle else "Hatch eggs"
	if self.state.lastHatch then self.heading.Text=self.headerTitle end
	self.note.Text=self.statusText or "Earn Stars. Choose an egg. Meet a new friend."
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
	if self.meetButton.Interactable then GuiService.SelectedObject = self.meetButton end
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
		textValue, canAct = if self.ackReady then (if self.retryAvailable then "Try again" else "Play again") else "Hatching…", self.ackReady
		local pet = Pets.byId[state.lastHatch.petId]
		self.meetButton.Text = if self.pending then "Saving…" elseif self.shade.AbsoluteSize.Y<200 or self.card.Size.X.Offset<400 then "Meet" else "Meet " .. (if pet then pet.name else "friend")
	else
		local recipe = Catalog.ById[self.selected]
		local missing = math.max(0, recipe.cost - (state.nectar or 0))
		textValue = if missing > 0 then Stars.format("Play for %s · need %d Stars", recipe.name, missing)
			else Stars.format("Hatch %s · %d Stars", recipe.name, recipe.cost)
		if self.compactShop then textValue=if missing>0 then string.format("Play · egg %d · need %d",recipe.cost,missing)else Stars.format("Hatch · %d Stars",recipe.cost)end
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
		local width=self.card.Size.X.Offset-24
		if self:footerRowHeight(self.action,width)>budget then
			local candidates=if missing>0 then {"Play · egg "..recipe.cost.." · need "..missing,"Play · egg "..recipe.cost.."\nNeed "..missing}
				else {"Hatch · "..recipe.cost.." Stars","Hatch"}
			for _,caption in ipairs(candidates) do
				self.action.Text=caption
				if self:footerRowHeight(self.action,width)<=budget then break end
			end
		end
	end
	self.action.Interactable = ready and not self.pending and canAct == true
	self.action.TextTransparency=0
	Art.control(self.action,not state.lastHatch,self.action.Interactable)
	self.meetButton.Interactable = state.lastHatch ~= nil and self.action.Interactable
	self.meetButton.TextTransparency=0
	Art.control(self.meetButton,true,self.meetButton.Interactable)
	local width=if state.lastHatch then (self.card.Size.X.Offset-36)/2 elseif self.compactShop then self.card.Size.X.Offset-24 else self.card.Size.X.Offset-24
	local needed=math.max(self:footerRowHeight(self.action,width),if state.lastHatch then self:footerRowHeight(self.meetButton,width) else 44)
	self:refreshShopHeader()
	if self.footerHeight and (self.footerHeight~=needed or self.layoutHeaderKey~=self:headerKey()) then self:layout() end
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
		target=self.closeButton;self.bodyFocusFallback=true;self.selectionLayoutEpoch=(self.selectionLayoutEpoch or 0)+1
	end
	if liveShopTarget(target,self.shade)then GuiService.SelectedObject=target;if target.Parent==column then self:queueSelectedRecipe()end end
end
function View:renderBody()
	if self.state.lastHatch or self.renderingBody then return end
	self.renderingBody = true
	local canvasPosition = self.body.CanvasPosition
	local previous=GuiService.SelectedObject;local action
	local owner=self.shade:GetAttribute("ControllerEpoch")
	if previous and previous:IsDescendantOf(self.body)then
		if previous.Name=="DailyNectar"or previous.Name=="HueEggs"then action=previous.Name
		elseif previous.Name:match("^Recipe_")then action=self.refocusRecipeId and "Recipe_"..self.refocusRecipeId or previous.Name end
	end
	self.refocusRecipeId=nil
	self.revealHost.Visible = false
	self:restoreRevealParent()
	-- Keep interactive identities and their parent alive: destroying a focused
	-- button makes native navigation move to Body before a replacement exists.
	local left=self.body:FindFirstChild("EggColumn")
	for _,child in ipairs(self.body:GetChildren())do if child~=left then child:Destroy()end end
	if left then
		for _,child in ipairs(left:GetChildren())do
			if not child:IsA("TextButton")or not(child.Name:match("^Recipe_")or child.Name=="DailyNectar"or child.Name=="HueEggs"or child.Name=="CompanionTab")then child:Destroy()end
		end
	end
	local size = self.body.AbsoluteSize
	local compact = self.compactShop == true
	local split = not compact and size.X >= 470
	local columnWidth = if split then (size.X - 18) / 2 else math.max(1, size.X - 6)
	left=left or frame(self.body,"EggColumn","ink",UDim2.fromOffset(0,0),UDim2.fromOffset(columnWidth,0))
	left.Size=UDim2.fromOffset(columnWidth,0);left.BackgroundTransparency=1
	local state = self.state
	local recipe = Catalog.ById[self.selected]
	local metrics=self:recipeMetrics(columnWidth,compact,self.recipeLayout and self.recipeLayout.columns)
	self.recipeLayout=metrics
    local startY=4
    if self.onOpenHue then
        local hueButton=left:FindFirstChild("HueEggs")
        if not hueButton then
            hueButton=button(left,"HueEggs","Hue Egg",UDim2.fromOffset(4,startY),UDim2.fromOffset(columnWidth-8,44),"raised")
            hueButton.Activated:Connect(function()
                if not self.shade.Visible or self.state.lastHatch or self.pending or not hueButton.Interactable then return end
                self:close("hue");self.onOpenHue()
            end)
        end
        Art.type(hueButton,"Action",compact)
        local h=math.max(44,Art.actionHeight(hueButton,columnWidth-8))
        local tabW=(columnWidth-16)/2
        local companion=left:FindFirstChild("CompanionTab")
        if not companion then companion=button(left,"CompanionTab","Companion eggs",UDim2.fromOffset(4,startY),UDim2.fromOffset(tabW,h),"raised")end
        Art.type(companion,"Action",compact)
        h=math.max(h,Art.actionHeight(companion,tabW),Art.actionHeight(hueButton,tabW))
        companion.Position,companion.Size=UDim2.fromOffset(4,startY),UDim2.fromOffset(tabW,h)
        companion:SetAttribute("SelectedTab",true);hueButton:SetAttribute("SelectedTab",false)
        Art.control(companion,true,not self.pending);Art.control(hueButton,false,not self.pending)
        local edge=companion:FindFirstChild("ActiveTabEdge")
        if not edge then edge=Art.frame(companion,"ActiveTabEdge","accent",UDim2.new(0,4,1,-4),UDim2.new(1,-8,0,3),companion.ZIndex+2)end
        hueButton.Position,hueButton.Size=UDim2.fromOffset(12+tabW,startY),UDim2.fromOffset(tabW,h)
        hueButton.Interactable=not self.pending and (Catalog.isOwned(state.inventoryMask or 0,"pip")or Catalog.isOwned(state.inventoryMask or 0,"puddle"))
        hueButton.Selectable=hueButton.Interactable;startY+=h+8
    end
	local notice=self:getSaveNotice()
	if self.statusText and not self.notePinned then
		local detail=Art.text(left,if notice then "SaveInstruction"else "ActionInstruction",self.statusText,UDim2.fromOffset(4,startY),UDim2.fromOffset(columnWidth-8,24),Art.Amber,14)
		Art.type(detail,"Body",true);local h=Art.textHeight(detail,columnWidth-8,24)
		detail.Size=UDim2.fromOffset(columnWidth-8,h);startY+=h+8
	end
	for index,id in ipairs(Catalog.Order)do
		local option=Catalog.ById[id]
		local y=startY+math.floor((index-1)/metrics.columns)*(metrics.height+8)
		local x=4+((index-1)%metrics.columns)*(metrics.width+8)
		local choice=left:FindFirstChild("Recipe_"..id)
		if not choice then
			choice=button(left,"Recipe_"..id,"",UDim2.fromOffset(x,y),UDim2.fromOffset(metrics.width,metrics.height),"panel")
			choice.Activated:Connect(function()
				if liveShopTarget(choice,self.shade)and not self.state.lastHatch then self:selectRecipe(id)end
			end)
			local outline=Art.stroke(choice,Art.Amber,0,2);outline.Name="SelectedOutline"
		end
		for _,child in ipairs(choice:GetChildren())do if child:IsA("GuiObject")then child:Destroy()end end
		choice.Position,choice.Size=UDim2.fromOffset(x,y),UDim2.fromOffset(metrics.width,metrics.height)
		Art.bind(choice,{BackgroundColor3=function()return if self.selected==id then Art.paletteColor("selected") else Art.paletteColor("panel") end})
		choice.Interactable,choice.Selectable=not self.pending,not self.pending
		choice.SelectedOutline.Enabled=self.selected==id
		local padding=choice:FindFirstChildOfClass("UIPadding");if padding then padding:Destroy()end
		EggArt.create(choice,id,UDim2.fromOffset(if compact then 6 else 12,(metrics.height-metrics.artH)/2),UDim2.fromOffset(if compact then 24 else 52,metrics.artH),choice.ZIndex+2)
		local groupH=metrics.nameH+3+metrics.costH;local ty=(metrics.height-groupH)/2
		local name=Art.text(choice,"RecipeName",option.name,UDim2.fromOffset(metrics.textX,ty),UDim2.fromOffset(metrics.textWidth,metrics.nameH),"text",if compact then 14 else 16,Art.Font.Body)
		local cost=Art.text(choice,"Cost",string.format(if compact then "%d Stars"else "%d Stars per hatch",option.cost),UDim2.fromOffset(metrics.textX,ty+metrics.nameH+3),UDim2.fromOffset(metrics.textWidth,metrics.costH),Art.Amber,12)
		name.TextXAlignment,cost.TextXAlignment=Enum.TextXAlignment.Left,Enum.TextXAlignment.Left
		name.TextWrapped,cost.TextWrapped=true,true
	end
	local y=startY+math.ceil(#Catalog.Order/metrics.columns)*(metrics.height+8)
	label(left, "NectarProgress", Stars.format("%d / %d Stars", state.nectar or 0, recipe.cost),
		UDim2.fromOffset(3, y), UDim2.new(1, -9, 0, 21), Art.Leaf, 13)
	local track = frame(left, "NectarTrack", "ink", UDim2.fromOffset(7, y + 24), UDim2.new(1, -18, 0, 6))
	Art.corner(track, 3)
	local fill = frame(track, "Fill", Art.Amber, UDim2.fromOffset(0, 0),
		UDim2.fromScale(math.clamp((state.nectar or 0) / recipe.cost, 0, 1), 1))
	Art.corner(fill, 3)
	local dailyTitle = if state.dailyAvailable then Stars.format("Daily Stars +%d", state.dailyBonus or 6)
		elseif state.dailyDay then "Daily Stars claimed" else "Daily Stars loading…"
	local daily=left:FindFirstChild("DailyNectar")
	if not daily then
		daily=button(left,"DailyNectar",dailyTitle,UDim2.fromOffset(3,y+41),UDim2.new(1,-9,0,44),"raised")
		daily.Activated:Connect(function()
			local current=self.state
			if liveShopTarget(daily,self.shade)and not current.lastHatch and not self.pending and current.dailyAvailable==true and current.dailyDay~=nil
				and(current.status==nil or current.status=="Ready")then self:send("daily",current.dailyDay)end
		end)
	end
	daily.Text,daily.Position,daily.Size=dailyTitle,UDim2.fromOffset(3,y+41),UDim2.new(1,-9,0,44)
	daily.Interactable = state.dailyAvailable == true and state.dailyDay ~= nil and not self.pending
		and (state.status == nil or state.status == "Ready")
	daily.Selectable=daily.Interactable
	daily.TextTransparency = if daily.Interactable then 0 else 0.4
	local leftHeight = y + 93
	left.Size = UDim2.fromOffset(columnWidth, leftHeight)
	local rightY = if split then 0 else leftHeight + 10
	local rightX = if split then columnWidth + 12 else 0
	local odds = frame(self.body, "OutcomeColumn", "ink", UDim2.fromOffset(rightX, rightY), UDim2.fromOffset(columnWidth, 20))
	odds.BackgroundTransparency = 1
	label(odds, "OddsHeading", "POSSIBLE HATCHES", UDim2.fromOffset(0, 1), UDim2.new(1, -2, 0, 22), Art.Leaf, 12)
	local misses = state.misses or 0
	local rows = Catalog.odds(self.selected, misses)
	for index, outcome in ipairs(rows) do
		local pet = Pets.byId[outcome.id]
		if not pet then continue end
		local row = frame(odds, "Outcome_" .. outcome.id, "raised", UDim2.fromOffset(2, 27 + (index - 1) * 29), UDim2.new(1, -7, 0, 26))
		Art.corner(row, 6)
		Portrait.create(row, pet, 1, UDim2.fromOffset(15, 13), 25,false,self.appearanceFor and self.appearanceFor(pet.id))
		local name = label(row, "Name", pet.name, UDim2.fromOffset(29, 0), UDim2.new(1, -77, 1, 0),
			if pet.trial then Art.Amber else Art.Silver, 12)
		name.TextXAlignment = Enum.TextXAlignment.Left
		label(row, "Probability", string.format("%.0f%%", outcome.weight), UDim2.new(1, -47, 0, 0),
			UDim2.fromOffset(44, 26), "text", 12)
	end
	local protectionY = 31 + #rows * 29
	local protection = if misses >= 7 then "Your next hatch is guaranteed rare"
		else string.format("Rare protection  %d / 7\nAfter 7 non-rares, the next hatch is rare", misses)
	label(odds, "RareProtection", protection, UDim2.fromOffset(2, protectionY), UDim2.new(1, -7, 0, 43), "muted", 11)
	label(odds, "Duplicates", "Already owned results grant nothing.", UDim2.fromOffset(2, protectionY + 48),
		UDim2.new(1, -7, 0, 31), "muted", 11)
	local rightHeight = protectionY + 84
	odds.Size = UDim2.fromOffset(columnWidth, rightHeight)
	local canvasHeight = if split then math.max(leftHeight, rightHeight) else rightY + rightHeight
	self.body.CanvasSize = UDim2.fromOffset(0, canvasHeight + 6)
	self.body.ScrollingEnabled = canvasHeight + 6 > size.Y
	self.body.CanvasPosition = Vector2.new(0, math.clamp(canvasPosition.Y, 0, math.max(0, canvasHeight + 6 - size.Y)))
	self.renderingBody = false
	self:restoreBodyFocus(previous,action,owner)
end

function View:selectRecipe(id)
	if self.pending or self.state.lastHatch or not Catalog.ById[id] then return false end
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
		self:close(if intent.intent == "meet" then "meet" else "afterHatch", intent)
		return
	end
	self.pending = self.ackIntent ~= nil or self.state.status == "Busy"
	self.nectar.Text = tostring(self.state.nectar or 0)
	self.note.Text = self.errorMessage or self.state.message or "Earn Stars. Choose an egg. Meet a new friend."
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
					local recipe = Catalog.ById[self.selected]
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
	self.note.Text = message or "Earn Stars. Choose an egg. Meet a new friend."
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
	if not self.shade.Visible or self.state.lastHatch~=nil then return nil end
	return{root=self.shade,epoch=self.shade:GetAttribute("ControllerEpoch")or 0,
		target=function()return self.closeButton end,fallback=self.closeButton}
end
function View:openingFocusTarget()
	if self.state.lastHatch and not self.ackReady then return nil end
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
	if self:ownsInput() and string.match(UserInputService:GetLastInputType().Name, "^Gamepad") then
		GuiService.SelectedObject = self:openingFocusTarget()
	end
end

function View:close(reason, choice)
	if self.shade.Visible then self:bumpControllerEpoch()end
	if not self.shade.Visible then return end
 if (reason==nil or reason=="close"or reason=="earn")and self.onAccepted then self.onAccepted(if reason=="earn"then "confirm"else "back")end
	self:revokeIntent()
	self.presentationGeneration += 1
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
