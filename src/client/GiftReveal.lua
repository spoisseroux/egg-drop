-- The gift chain's card (GiftChain; ONBOARDING-FUN-PASS section 2, Onboard "gifts"): what the free Paint or Toy Egg gave,
-- opened only by the egg machine's deliver once the egg is in the cup (the standing rule: every egg cranks and emerges
-- before any reveal). Its odds are the egg's own ("Each colour: 1 in 4"). One tap does the thing and closes into the
-- garden, never a menu: "Paint {pet}!" (the pot on the pet's body, the existing hueUse) or "Play!" (the toy equipped,
-- the existing toyEquip); "Later" keeps it. Either way the server is told it was seen (giftSeen), so it never replays.
-- Fable owns the final card and the paint wipe; this is the functional card in the deck palette.
-- show(parent, record, options): record = {kind, item, id}; options = {text(key, vars), pet (name), color (Color3 for a
--   pot), act(record) (Paint / Play), seen(record), closed(), play(name)}
local Reveal={}
Reveal.Ink=Color3.fromHex("#1B2A4A");Reveal.Card=Color3.fromHex("#FFF8E8");Reveal.Gold=Color3.fromHex("#FFD86B")
local open=nil
local function node(class,parent,props)
	local n=Instance.new(class)
	for k,v in pairs(props or {})do n[k]=v end
	n.Parent=parent
	return n
end
local function on(signal,fn)if typeof(signal)=="RBXScriptSignal"then return signal:Connect(fn)end;return nil end
-- Pure: the card's words for a record. -> {title, name, odds, primary, secondary}
function Reveal.words(record,options)
	local text=options.text
	local kind=record.kind
	local w={title=text("onbGift.card.title")}
	if kind=="paint"then
		w.name=text("onbGift.card.pot",{name=options.itemName or record.item})
		w.odds=text("onbGift.card.potOdds")
		w.primary=text("onbGift.card.paint",{pet=options.pet})
	else
		w.name=options.itemName or record.item
		w.odds=text("onbGift.card.toyOdds",{count=options.poolSize or 1})
		w.primary=text("onbGift.card.play")
	end
	w.secondary=text("onbGift.card.later")
	return w
end
function Reveal.isOpen()return open~=nil end
function Reveal.show(parent,record,options)
	if open then open:Destroy();open=nil end
	local words=Reveal.words(record,options)
	local gui=node("ScreenGui",parent,{Name="EggDropGiftCard",ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=40,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
	open=gui
	local card=node("Frame",gui,{Name="Card",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(340,300),
		BackgroundColor3=Reveal.Card,BorderSizePixel=0})
	node("UICorner",card,{CornerRadius=UDim.new(0,24)});node("UIStroke",card,{Color=Reveal.Ink,Thickness=3})
	node("UISizeConstraint",card,{MaxSize=Vector2.new(340,300)})
	node("TextLabel",card,{Name="Title",BackgroundTransparency=1,Position=UDim2.new(0,0,0,18),Size=UDim2.new(1,0,0,32),Text=words.title,
		Font=Enum.Font.FredokaOne,TextSize=28,TextColor3=Reveal.Ink})
	local swatch=node("Frame",card,{Name="Item",AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,62),Size=UDim2.fromOffset(84,84),
		BackgroundColor3=options.color or Reveal.Gold,BorderSizePixel=0})
	node("UICorner",swatch,{CornerRadius=UDim.new(.5,0)});node("UIStroke",swatch,{Color=Reveal.Ink,Thickness=3})
	if record.kind~="paint"then node("TextLabel",swatch,{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Text="🧸",TextScaled=true,Font=Enum.Font.FredokaOne})end
	node("TextLabel",card,{Name="Name",BackgroundTransparency=1,Position=UDim2.new(0,12,0,154),Size=UDim2.new(1,-24,0,28),Text=words.name,
		Font=Enum.Font.BuilderSansExtraBold,TextSize=22,TextColor3=Reveal.Ink})
	node("TextLabel",card,{Name="Odds",BackgroundTransparency=1,Position=UDim2.new(0,12,0,184),Size=UDim2.new(1,-24,0,18),Text=words.odds,
		Font=Enum.Font.BuilderSansBold,TextSize=14,TextColor3=Reveal.Ink,TextTransparency=.35})
	local function button(name,label,x,primary)
		local b=node("TextButton",card,{Name=name,Text=label,AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(x,0,1,-18),Size=UDim2.fromOffset(primary and 170 or 110,52),
			BackgroundColor3=if primary then Reveal.Gold else Reveal.Card,TextColor3=Reveal.Ink,Font=Enum.Font.BuilderSansExtraBold,TextSize=20,
			AutoButtonColor=true,BorderSizePixel=0,Selectable=true})
		node("UICorner",b,{CornerRadius=UDim.new(0,26)});node("UIStroke",b,{Color=Reveal.Ink,Thickness=2,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
		return b
	end
	local primary=button("Primary",words.primary,.64,true)
	local later=button("Later",words.secondary,.2,false)
	local done=false
	local function finish(act)
		if done then return end
		done=true
		if open==gui then open=nil end
		gui:Destroy()
		if act and options.act then pcall(options.act,record)end
		if options.seen then pcall(options.seen,record)end
		if options.closed then pcall(options.closed)end
	end
	on(primary.Activated,function()finish(true)end)
	on(later.Activated,function()finish(false)end)
	if options.play then pcall(options.play,"rarity_common")end
	pcall(function()game:GetService("GuiService").SelectedObject=primary end)
	return gui
end
return Reveal
