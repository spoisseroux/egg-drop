-- The Today's picks sheet (ROTATION-BRIEF 3, ARCH-REVIEW-ROTATION 12; switch daily_rack): over the Hatch eggs panel, a
-- card per pick with the pet wearing it (the Paint Egg's: the pet painted each pot), its rarity pill, owned marks and
-- the odds. The model is RackShop.sheet / RackShop.paintSheet (pure, spec-checked); this only draws it.
-- Previews reuse CardPreviewCache (lazy, one built per frame, at most model.live on cards: 8, 6 on a phone; posed once,
-- never animated). A sparkle pick's finish shows as its still colour plus 2D UISparks over its card (particles never
-- draw in a ViewportFrame; Reduced Motion: none). No clock anywhere: "New picks every day", "They come back".
-- open(host, model, options) -> sheet {root, button, close()}. options = {petId, phone, appearance() -> the pet's look,
-- reduced(), onClose()}. B / Esc / Backspace and the button close it.
-- Slice 2 (ROTATION-2-BRIEF 1, 2): the Toy Colour Egg's cards are the toy in that colour (a still viewport through the
-- cache, RackArt.toyEntry; a locked one dimmed with "Get this toy from the Toy Egg"); the Deck Egg's are a plate's
-- texture on the handheld (RackArt.plate) or a ball theme's five balls (RackArt.balls), flat, no viewport, each card
-- trimmed in its accent.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local GuiService=game:GetService("GuiService")
local UserInputService=game:GetService("UserInputService")
local ContextActionService=game:GetService("ContextActionService")
local Shared=game:GetService("ReplicatedStorage").Shared
local Kit=require(script.Parent.DeckKit)
local Cache=require(script.Parent.CardPreviewCache)
local RackShop=require(script.Parent.RackShop)
local Pets=require(Shared.PetCatalog)
local Picks={};Picks.__index=Picks
Picks.Action="EggDropTodaysPicks"
Picks.Gap=12

local function hex(value,fallback)
	local ok,color=pcall(Color3.fromHex,value or "")
	return if ok then color else fallback or Color3.new(1,1,1)
end
-- The look a card previews (nil: no preview, its colour swatch stays).
local function lookFor(card,petId,base)
	if card.wear then return RackShop.wearing(base,petId,card.wear)end
	local Hue=nil
	if card.paint or card.finishJar then Hue=require(script.Parent.HueEggView)end
	if card.paint then return Hue.previewAppearance(base,"hue",card.paint,"main")end
	if card.finishJar then return Hue.previewAppearance(base,"finish",card.finishJar,"main")end
	return nil
end

function Picks.open(host,model,options)
	options=options or {}
	local self=setmetatable({model=model,options=options,cards={},closed=false},Picks)
	local phone=options.phone==true
	local W=math.max(200,host.Size.X.Offset);local H=math.max(200,host.Size.Y.Offset)
	local root=Kit.frame(host,"TodaysPicks","panel",UDim2.new(),UDim2.fromScale(1,1),if phone then nil else 16)
	root.Active=true;root.ZIndex=host.ZIndex+60
	self.root=root
	local pad=if phone then 16 else 24
	Kit.text(root,"Title",model.title,"text",{Name="Title",Position=UDim2.fromOffset(pad,14),Size=UDim2.fromOffset(W-pad*2,30),TextSize=if phone then 20 else 26})
	Kit.text(root,"Body",model.line,"soft",{Name="Line",Position=UDim2.fromOffset(pad,46),Size=UDim2.fromOffset(W-pad*2,20),TextSize=if phone then 13 else 15})
	local top,bottom=74,if phone then 64 else 76
	local list=Instance.new("ScrollingFrame")
	list.Name="Cards";list.BackgroundTransparency=1;list.BorderSizePixel=0;list.ZIndex=root.ZIndex+1
	list.Position=UDim2.fromOffset(pad-4,top);list.Size=UDim2.fromOffset(W-pad*2+8,H-top-bottom)
	list.ScrollingDirection=Enum.ScrollingDirection.Y;list.ElasticBehavior=Enum.ElasticBehavior.Never;list.ScrollBarThickness=4
	Kit.paint(list,"ScrollBarImageColor3","accent")
	list.Parent=root
	self.list=list
	local cols=math.max(1,model.columns or 2)
	local gap=Picks.Gap
	local listW=list.Size.X.Offset-8
	local cw=math.floor((listW-gap*(cols-1))/cols)
	local wellH=math.floor(cw*(if phone then .78 else .82))
	local ch=wellH+(if phone then 54 else 62)
	self.cardH=ch
	for i,card in ipairs(model.cards)do
		local c,r=(i-1)%cols,math.floor((i-1)/cols)
		local frame=Kit.frame(list,"Card_"..card.id,"raised",UDim2.fromOffset(4+c*(cw+gap),4+r*(ch+gap)),UDim2.fromOffset(cw,ch),12)
		frame:SetAttribute("Owned",card.owned==true);frame:SetAttribute("Rarity",card.rarity);frame:SetAttribute("Gift",card.gift==true)
		frame:SetAttribute("AccessibleLabel",card.name.." "..(card.pill or "").." "..(card.value or ""))
		local well=Kit.frame(frame,"Well","well",UDim2.fromOffset(6,6),UDim2.fromOffset(cw-12,wellH),10)
		well.ClipsDescendants=true
		local swatch=Kit.frame(well,"Swatch",nil,UDim2.fromScale(.5,.5),UDim2.fromOffset(wellH*.4,wellH*.4),999)
		swatch.AnchorPoint=Vector2.new(.5,.5);swatch.BackgroundTransparency=0;swatch.BackgroundColor3=hex(card.color or card.pillColor)
		frame:SetAttribute("Kind",card.kind)
		-- the Deck Egg's cards: flat art over the swatch, the card trimmed in the plate's (or balls') accent
		if card.kind=="plate"or card.kind=="ball"then
			local Art=require(script.Parent.RackArt)
			local ok=pcall(function()
				if card.kind=="plate"then Art.plate(well,card.plate,UDim2.fromScale(.1,.06),UDim2.fromScale(.8,.88),well.ZIndex+2)
				else Art.balls(well,card.ball,UDim2.fromScale(.04,.1),UDim2.fromScale(.92,.8),well.ZIndex+2)end
			end)
			if ok then swatch.Visible=false end
			local trim=Instance.new("UIStroke");trim.Name="Trim";trim.Thickness=2;trim.Color=hex(card.accent or card.color,Color3.new(1,1,1))
			trim.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;trim.Parent=frame
		end
		if card.locked then frame:SetAttribute("Locked",true);well.BackgroundTransparency=math.max(well.BackgroundTransparency,.35)end
		local y=wellH+10
		Kit.text(frame,"Body",card.name,"text",{Name="Name",Position=UDim2.fromOffset(10,y),Size=UDim2.fromOffset(cw-20,18),
			TextSize=if phone then 13 else 15,TextTruncate=Enum.TextTruncate.AtEnd})
		y+=22
		if card.locked then
			-- a toy the player does not own yet: no pill, no odds, one kind line where they sit
			Kit.text(frame,"Small",card.value or "","soft",{Name="Value",Position=UDim2.fromOffset(10,y-2),Size=UDim2.fromOffset(cw-20,if phone then 26 else 30),
				TextSize=if phone then 11 else 12,TextWrapped=true})
		elseif card.pill then
			local size=if phone then 11 else 12
			local pw=math.ceil(Kit.measure(card.pill,"Small",size).X)+14
			local pill=Kit.frame(frame,"Pill",nil,UDim2.fromOffset(10,y),UDim2.fromOffset(pw,if phone then 18 else 20),999)
			pill.BackgroundTransparency=0;pill.BackgroundColor3=hex(card.pillColor,hex(RackShop.Pill.common))
			local word=Kit.text(pill,"Small",card.pill,"text",{Name="Word",Size=UDim2.fromScale(1,1),TextSize=size,TextXAlignment=Enum.TextXAlignment.Center})
			Kit.paint(word,"TextColor3",function()return Color3.new(1,1,1)end)
		end
		if not card.locked then
			local value=(if card.owned then "✓ " else "")..(card.value or "")
			local v=Kit.text(frame,"Counter",value,if card.owned then "soft"else "text",{Name="Value",Position=UDim2.fromOffset(cw/2,y),Size=UDim2.fromOffset(cw/2-10,20),
				TextSize=if phone then 13 else 15,TextXAlignment=Enum.TextXAlignment.Right})
			v.AutoLocalize=card.owned==true
		end
		local sparks=nil
		if card.sparkle then sparks=require(script.Parent.UISparks).new(well,well.ZIndex+8)end
		table.insert(self.cards,{card=card,frame=frame,well=well,swatch=swatch,sparks=sparks,y=4+r*(ch+gap)})
	end
	local rows=math.ceil(#model.cards/cols)
	list.CanvasSize=UDim2.fromOffset(0,8+rows*ch+math.max(0,rows-1)*gap)
	-- the tapped row's card first in view
	local focus=self.cards[model.focus or 1]
	if focus then list.CanvasPosition=Vector2.new(0,math.max(0,focus.y-4))end
	Kit.text(root,"Small",model.footer,"soft",{Name="Footer",Position=UDim2.fromOffset(pad,H-bottom+14),Size=UDim2.fromOffset(W-pad*2-180,24),
		TextSize=if phone then 13 else 15,TextWrapped=true})
	local button=Kit.button(root,"PicksButton",{variant="primary",text=model.button,glyph="B",size=Vector2.new(if phone then 140 else 168,44),selectable=true})
	button.AnchorPoint=Vector2.new(1,0);button.Position=UDim2.new(1,-pad,1,-bottom+10)
	button.Activated:Connect(function()self:close()end)
	self.button=button
	-- previews: lazy, one built a frame, at most `live` on cards
	self.cache=Cache.new({live=model.live or 8,size=16})
	local petId=options.petId or model.petId or "pip"
	local pet=Pets.byId[petId]or Pets.byId.pip
	local base=nil
	local function baseLook()
		if base==nil then base=(options.appearance and options.appearance())or {}end
		return base
	end
	local function reduced()return GuiService.ReducedMotionEnabled or(options.reduced~=nil and options.reduced()==true)end
	self.beat=RunService.Heartbeat:Connect(function(dt)
		if self.closed or not root.Parent then return end
		local window,at=list.Size.Y.Offset,list.CanvasPosition.Y
		local wanted={}
		for _,entry in ipairs(self.cards)do
			local look=entry.look
			if look==nil then look=lookFor(entry.card,petId,baseLook())or false;entry.look=look end
			if entry.card.kind=="toy"and entry.card.toy then
				-- the toy in that colour, still (no pet): RackArt.toyEntry, cached like a pet preview
				local card=entry.card
				table.insert(wanted,{holder=entry.well,key="toy:"..tostring(card.toy)..":"..tostring(card.skin),visible=Cache.visible(entry.y,self.cardH,at,window),
					build=function()return require(script.Parent.RackArt).toyEntry(card.toy,card.skin)end})
			elseif look then
				table.insert(wanted,{holder=entry.well,key=Cache.key(petId,entry.card.id,nil),visible=Cache.visible(entry.y,self.cardH,at,window),
					build=function()return Cache.buildPet(pet,look,.95)end})
			end
			if entry.sparks then
				local size=entry.well.AbsoluteSize
				entry.sparks:step(dt,Vector2.new(size.X*.5,size.Y*.3),math.max(1,size.X/120),not reduced()and Cache.visible(entry.y,self.cardH,at,window))
			end
		end
		self.cache:pump(wanted,function(holder)
			local swatch=holder:FindFirstChild("Swatch");if swatch then swatch.Visible=false end
		end)
	end)
	self.cache.onDetach=function(holder)
		local swatch=holder.Parent and holder:FindFirstChild("Swatch");if swatch then swatch.Visible=true end
	end
	ContextActionService:BindActionAtPriority(Picks.Action,function(_,state)
		if self.closed or GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end
		if state==Enum.UserInputState.Begin then self:close()end
		return Enum.ContextActionResult.Sink
	end,false,Enum.ContextActionPriority.High.Value+840,Enum.KeyCode.ButtonB,Enum.KeyCode.Escape,Enum.KeyCode.Backspace)
	if string.match(UserInputService:GetLastInputType().Name,"^Gamepad")and Players.LocalPlayer then GuiService.SelectedObject=button end
	root.Destroying:Connect(function()if not self.closed then self:close()end end)
	return self
end

function Picks:close()
	if self.closed then return end
	self.closed=true
	pcall(function()ContextActionService:UnbindAction(Picks.Action)end)
	if self.beat then self.beat:Disconnect();self.beat=nil end
	if self.cache then pcall(self.cache.clear,self.cache)end
	for _,entry in ipairs(self.cards)do if entry.sparks then pcall(entry.sparks.destroy,entry.sparks)end end
	if GuiService.SelectedObject and self.root and GuiService.SelectedObject:IsDescendantOf(self.root)then GuiService.SelectedObject=nil end
	if self.root and self.root.Parent then self.root:Destroy()end
	if self.options.onClose then pcall(self.options.onClose)end
end

return Picks
