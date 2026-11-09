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
local HueCatalog=require(ReplicatedStorage.Shared.HueCatalog)
local MaterialCatalog=require(ReplicatedStorage.Shared.MaterialCatalog)
local JarArt=require(script.Parent.HueJarArt)
local liveOrder={"meadow","hue","material"}
local function shopRecipe(id)
 if id=="hue"then return {id="hue",name="Hue Egg",cost=HueCatalog.Cost}end
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
		elseif current.pendingHueResult then
            if self.onOpenHue then self.onOpenHue(false)end
        elseif current.pendingMaterialResult then
            if self.onOpenMaterial then self.onOpenMaterial(false)end
        elseif (current.nectar or 0) < shopRecipe(self.selected).cost then
			self:close("earn")
		else
			if self.selected=="material"then if self.onOpenMaterial then self.onOpenMaterial(true)end elseif self.selected=="hue"then if self.onOpenHue then self.onOpenHue(true)end else self:send("hatch",self.selected)end
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
	for _,id in ipairs(liveOrder)do
		local option=shopRecipe(id)
		nameH=math.max(nameH,nativeHeight(option.name,if compact then 14 else 16,Art.Font.Body,textW))
		costH=math.max(costH,nativeHeight(string.format(if compact then "%d Stars"else "%d Stars per hatch",option.cost),12,Art.Font.Body,textW))
	end
	return{columns=columns,width=choiceW,textX=textX,textWidth=textW,nameH=nameH,costH=costH,height=math.max(if compact then 44 else 83,nameH+costH+3+8),artH=if compact then 32 else 66}
end
function View:layoutShop()
 if self.layingOut then return end;self.layingOut=true
 self.bodyFocusFallback=false;self:restoreRevealParent();self:refreshShopHeader()
 local size=self.shade.AbsoluteSize;local width=math.max(1,math.min(640,size.X-16));local short=size.Y<280
 self.compactShop=short;self.budgetCompact=short;self.card.Size=UDim2.fromOffset(width,math.max(1,math.min(720,size.Y-16)))
 self.wallet.Parent,self.nectar.Parent=self.card,self.wallet
 self.wallet.Visible,self.heading.Visible,self.nectar.Visible,self.body.Visible=true,true,true,true
 self.meetButton.Visible,self.revealHost.Visible=false,false
 self.headerPlan=Art.sheetHeader(width,self.heading,self.wallet,self.nectar,self.walletDrop,self.closeButton,{pad=12,top=0,amount=self.state.nectar or 0,title=self.headerTitle or "Hatch eggs",shortTitle=self.headerShortTitle or "Hatch eggs",accessibleTitle=self.statusText or "Choose an egg",status=self.statusText~=nil})
 Art.type(self.action,"Action",short)
 local footerH=self:footerRowHeight(self.action,width-24);self.footerHeight=footerH
 local edgeGap=if short then 4 else 8
 self.action.Position,self.action.Size=UDim2.fromOffset(12,self.card.Size.Y.Offset-footerH-edgeGap),UDim2.fromOffset(width-24,footerH)
 local top=self.headerPlan.height+(if short then 0 else 4)
 self.note.Visible=false;self.notePinned=false
 self.body.Position,self.body.Size=UDim2.fromOffset(12,top),UDim2.fromOffset(width-24,math.max(1,self.card.Size.Y.Offset-top-footerH-edgeGap-4))
 local signature=width..":"..self.card.Size.Y.Offset..":"..GuiService.PreferredTextSize.Name
 local reflowed=self.shopReflowSignature~=signature;self.shopReflowSignature=signature
 self.layoutHeaderKey=self:headerKey();self.layingOut=false
 if self.shade.Visible then self:renderBody();if reflowed then self:ensureSelectedRecipe();self:queueSelectedRecipe()end end
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
	self.cinematic.compactLandscape=self.card.Size.X.Offset>=480 and self.card.Size.Y.Offset<400
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
		local recipe = shopRecipe(self.selected)
		local missing = math.max(0, recipe.cost - (state.nectar or 0))
		textValue = if state.pendingHueResult then "Open saved jar"elseif missing > 0 then Stars.format("Play for %s · need %d Stars", recipe.name, missing)
			else Stars.format("Hatch %s · %d Stars", recipe.name, recipe.cost)
		if self.compactShop and not state.pendingHueResult then textValue=if missing>0 then string.format("Play · egg %d · need %d",recipe.cost,missing)else Stars.format("Hatch · %d Stars",recipe.cost)end
		canAct = true
  if state.pendingMaterialResult then textValue="Open saved material"
  elseif self.selected=="material"then
   if #MaterialCatalog.remaining(state.materialUnlocks)==0 then textValue,canAct="All materials owned",false
   elseif not state.materialAvailable then textValue,canAct="Materials not ready",false end
  end
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
	if self.compactShop and not state.lastHatch and not self.pending and canAct and not state.pendingMaterialResult then
		local recipe=shopRecipe(self.selected)
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
 if self.state.lastHatch or self.renderingBody then return end;self.renderingBody=true
 local previous=GuiService.SelectedObject;local action=previous and previous:IsDescendantOf(self.body)and previous.Name or nil
 local owner=self.shade:GetAttribute("ControllerEpoch");local canvas=self.body.CanvasPosition
 self.revealHost.Visible=false;self:restoreRevealParent()
 local left=self.body:FindFirstChild("EggColumn")
 for _,child in ipairs(self.body:GetChildren())do if child~=left then child:Destroy()end end
 left=left or frame(self.body,"EggColumn","ink",UDim2.fromOffset(0,0),UDim2.fromOffset(100,100));left.BackgroundTransparency=1
 for _,child in ipairs(left:GetChildren())do if not child:IsA("TextButton")or not(child.Name=="Recipe_meadow"or child.Name=="Recipe_hue"or child.Name=="Recipe_material"or child.Name=="DailyNectar")then child:Destroy()end end
 local width=math.max(1,self.body.AbsoluteSize.X);local w=width-8;local short=self.shade.AbsoluteSize.Y<280
 left.Size=UDim2.fromOffset(width,1);local y=4;local cols=if width>=280 then 2 else 1;local cw=(w-(cols-1)*8)/cols
 local cardH=short and 116 or 160
 for _,id in ipairs(liveOrder)do
  local recipe=shopRecipe(id);local n=left:FindFirstChild("Recipe_"..id)
  if not n then
   n=button(left,"Recipe_"..id,"",UDim2.fromOffset(0,0),UDim2.fromOffset(cw,cardH),"raised")
   n.Activated:Connect(function()if liveShopTarget(n,self.shade)then self:selectRecipe(id)end end)
  end
  for _,child in ipairs(n:GetChildren())do if child:IsA("GuiObject")or child:IsA("UIPadding")then child:Destroy()end end
  local labelNode=Art.text(n,"RecipeName",recipe.name,UDim2.fromOffset(4,0),UDim2.fromOffset(cw-8,24),"text",16);Art.type(labelNode,"Action",short)
  local cost=Art.text(n,"Cost",recipe.cost.." Stars",UDim2.fromOffset(4,0),UDim2.fromOffset(cw-8,22),"text",14);Art.type(cost,"Body",short)
  local nh=Art.textHeight(labelNode,cw-8,22);local ph=Art.textHeight(cost,cw-8,20);cardH=math.max(cardH,nh+ph+64)
  labelNode.Position,labelNode.Size=UDim2.fromOffset(4,cardH-nh-ph-10),UDim2.fromOffset(cw-8,nh)
  cost.Position,cost.Size=UDim2.fromOffset(4,cardH-ph-6),UDim2.fromOffset(cw-8,ph)
  local eggH=math.max(52,cardH-nh-ph-18);EggArt.create(n,id,UDim2.fromOffset((cw-eggH*.78)/2,4),UDim2.fromOffset(eggH*.78,eggH),n.ZIndex+2)
  Art.control(n,self.selected==id,not self.pending);n.Interactable,n.Selectable=not self.pending,not self.pending;n:SetAttribute("Selected",self.selected==id)
 end
 for index,id in ipairs(liveOrder)do local n=left:FindFirstChild("Recipe_"..id);n.Position,n.Size=UDim2.fromOffset(4+((index-1)%cols)*(cw+8),y+math.floor((index-1)/cols)*(cardH+8)),UDim2.fromOffset(cw,cardH)end
 y+=math.ceil(#liveOrder/cols)*(cardH+8)
 local function copy(name,value,role,color)
  local n=Art.text(left,name,value,UDim2.fromOffset(4,y),UDim2.fromOffset(w,24),color or "text",16);Art.type(n,role or "Body",short);n.TextXAlignment=Enum.TextXAlignment.Left
  local h=Art.textHeight(n,w,24);n.Size=UDim2.fromOffset(w,h);y+=h+8;return n
 end
 local recipe=shopRecipe(self.selected)
 copy("SelectedRecipe",recipe.name.." · "..recipe.cost.." Stars","Action")
 if self.statusText then copy(if self:getSaveNotice()then "SaveInstruction"else "ActionInstruction",self.statusText,"Body")end
 local function outcomes(rows,itemPool)
  local columns=if w>=540 then 2 else 1;local rw=(w-(columns-1)*8)/columns;local heights={};local nodes={}
  for index,entry in ipairs(rows)do
   local name=if itemPool then HueCatalog.Items[entry.id].name else Pets.byId[entry.id].name
   local owned=not itemPool and Catalog.isOwned(self.state.inventoryMask or 0,entry.id)
   local row=frame(left,"Outcome_"..entry.id,"inset",UDim2.fromOffset(0,0),UDim2.fromOffset(rw,52));Art.corner(row,9)
   local label=Art.text(row,"Name",name,UDim2.fromOffset(48,6),UDim2.fromOffset(rw-112,24),"text",16);Art.type(label,"Body",short);label.TextXAlignment=Enum.TextXAlignment.Left
   local chance=Art.text(row,"Chance",string.format(if itemPool then "%.0f%%"else "%.1f%%",entry.weight),UDim2.fromOffset(rw-62,6),UDim2.fromOffset(54,24),"text",18);Art.type(chance,"Action",short);chance.TextXAlignment=Enum.TextXAlignment.Right
   local cw=math.max(54,Art.textWidth(chance)+4);local nw=math.max(1,rw-cw-64)
   local nh=Art.textHeight(label,nw,24);label.Size=UDim2.fromOffset(nw,nh)
   local ch=Art.textHeight(chance,cw,24);chance.Position,chance.Size=UDim2.fromOffset(rw-cw-8,6),UDim2.fromOffset(cw,ch)
   local h=math.max(52,math.max(nh,ch)+12)
   if owned then local ownedText=Art.text(row,"Owned","Already owned · no reward",UDim2.fromOffset(48,nh+8),UDim2.fromOffset(rw-56,20),"muted",14);Art.type(ownedText,"Supporting",short);ownedText.TextXAlignment=Enum.TextXAlignment.Left;local oh=Art.textHeight(ownedText,rw-56,20);ownedText.Size=UDim2.fromOffset(rw-56,oh);h+=oh+4 end
   if itemPool then JarArt.create(row,entry.id,UDim2.fromOffset(5,4),UDim2.fromOffset(34,42),row.ZIndex+2)else Portrait.create(row,Pets.byId[entry.id],2,UDim2.fromOffset(24,26),row.ZIndex+2,false,self.appearanceFor and self.appearanceFor(entry.id))end
   nodes[index]=row;local group=math.floor((index-1)/columns)+1;heights[group]=math.max(heights[group]or 0,h)
  end
  for index,row in ipairs(nodes)do local group=math.floor((index-1)/columns)+1;local ry=y;for n=1,group-1 do ry+=heights[n]+8 end;row.Position,row.Size=UDim2.fromOffset(4+((index-1)%columns)*(rw+8),ry),UDim2.fromOffset(rw,heights[group])end
  for _,h in ipairs(heights)do y+=h+8 end
 end
 if self.selected=="material"then
  copy("PoolHeading","New materials · no duplicates","Action")
  local odds=MaterialCatalog.odds(self.state.materialUnlocks)
  if #odds==0 then copy("MaterialCollection","All materials owned","Body")
  elseif not self.state.materialAvailable then copy("MaterialAvailability","Material Eggs are not ready yet.","Body")
  else for _,entry in ipairs(odds)do copy("MaterialOdds_"..entry.id,MaterialCatalog.ById[entry.id].name.." · "..string.format("%.2g%%",entry.probability*100),"Body")end end
  copy("MaterialRules","Unlock once for all your pets. Choose any owned material for free in Materials. Standard is always available.","Body")
 elseif self.selected=="hue"then
  copy("PoolHeading","One saved jar · all possible items","Action")
  local pool={};for _,id in ipairs(HueCatalog.ItemOrder)do table.insert(pool,{id=id,weight=20})end;outcomes(pool,true)
  copy("ItemRules","Fixed colors stack in your inventory. Use one jar for one dose on one pet and channel. Reset Hue clears that channel; an original channel uses nothing. Store any result.","Body")
 else
  copy("PoolHeading","Possible companions","Action");outcomes(Catalog.odds("meadow",self.state.misses or 0),false)
  copy("PoolNote","Four companions are currently available. Companions you already own remain yours. Duplicates grant no reward.","Supporting")
 end
 local daily=left:FindFirstChild("DailyNectar")
 if not daily then daily=button(left,"DailyNectar","",UDim2.fromOffset(4,y),UDim2.fromOffset(w,44),"raised");daily.Activated:Connect(function()local state=self.state;if liveShopTarget(daily,self.shade)and state.dailyAvailable and state.dailyDay and not self.pending then self:send("daily",state.dailyDay)end end)end
 daily.Text=if self.state.dailyAvailable then "Daily Stars +"..(self.state.dailyBonus or 6)else "Daily Stars claimed"
 Art.type(daily,"Action",short);local dh=math.max(44,Art.actionHeight(daily,w));daily.Position,daily.Size=UDim2.fromOffset(4,y),UDim2.fromOffset(w,dh);daily.Interactable,daily.Selectable=self.state.dailyAvailable==true and not self.pending,self.state.dailyAvailable==true and not self.pending;Art.control(daily,false,daily.Interactable);y+=dh+8
 left.Size=UDim2.fromOffset(width,y);self.body.CanvasSize=UDim2.fromOffset(0,y+4);self.body.ScrollingEnabled=y+4>self.body.AbsoluteSize.Y
 self.body.CanvasPosition=Vector2.new(0,math.clamp(canvas.Y,0,math.max(0,y+4-self.body.AbsoluteSize.Y)));self.renderingBody=false;self:restoreBodyFocus(previous,action,owner)
 if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(left)then self:queueSelectedRecipe()end
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
