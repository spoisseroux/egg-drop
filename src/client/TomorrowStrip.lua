-- The "See you tomorrow" strip (ONBOARDING-V3-PLAN-2026-11-23 slice E; NEST-LOOK section 7): one well-filled row on
-- the results screens (DeckResults, DeckResultsInPlace, the Dash results card) while Onboard.on("nest"): the nest's
-- clock (gold "Ready!" when it is), tomorrow's stamp and its Stars, and the new quests. Never a button, never focusable,
-- no loop, no sound. Nothing at all when the nest is off or there is no egg.
-- Presentation only: Strip.model is pure (spec-checked); Strip.new draws it with plain instances (the deck's colours).
local Shared=game:GetService("ReplicatedStorage").Shared
local Nest=require(Shared.Nest)
local UICopy=require(Shared.UICopy)
local Quests=require(Shared.QuestCatalog)
local Stamp=require(Shared.StampCard)
local Strip={};Strip.__index=Strip
Strip.Quests=#Quests.Pools -- one new daily quest a pool, every day
-- Phone v2 (beta 12 U7, DASH-DECK-UI-LOOK): 48 tall with the title row inside, held behind DeckLook.on() (the beta
-- and Studio); off, the strip is the one before, 36 tall with its title on a tab. options.v2 overrides (specs).
Strip.Height=table.freeze({desktop=44,phone=48,phoneOld=36})
function Strip.v2(options)
	if options and options.v2~=nil then return options.v2==true end
	local ok,on=pcall(function()return require(Shared.DeckLook).on()end)
	return ok and on==true
end
function Strip.phoneHeight(v2)return if v2 then Strip.Height.phone else Strip.Height.phoneOld end
Strip.PhoneMin=240    -- a phone strip narrower than this is not drawn
Strip.PhoneWhole=400  -- from this wide a phone strip has room for the whole words
Strip.TitleY=11       -- the title row's middle
Strip.ChipY=21
Strip.ChipH=22
Strip.Gap=table.freeze({desktop=8,phone=6})
Strip.TitleW=132
Strip.NarrowCard=420     -- a card narrower than this uses the short values at once
Strip.WaitMinScreen=400  -- the "Miss a day, lose nothing." line is left out below this screen height
Strip.Color=table.freeze({well=Color3.fromHex("#20234A"),ink=Color3.fromHex("#15143A"),stars=Color3.fromHex("#FFC14D"),
	gold=Color3.fromHex("#FFE08A"),text=Color3.fromHex("#FFFFFF"),soft=Color3.fromHex("#DCE5FF"),chip=Color3.fromHex("#2C3060")})
Strip.NestIcon="rbxassetid://114080030018596"

-- ── Pure ─────────────────────────────────────────────────────────────────────────────────────────────────────────
-- ctx = {on = Onboard.on("nest"), nest = NestClient:summary() ({left, view}) or nil, state = the owner snapshot}.
-- Answers nil (no strip) or {title, wait, chips = {nest, stamp, quests}}; each chip {id, text, short, gold, stars?}.
function Strip.model(ctx)
	if type(ctx)~="table"or ctx.on~=true or type(ctx.nest)~="table"or type(ctx.nest.left)~="number"then return nil end
	local kind,value=Nest.countdown(ctx.nest.left)
	local nest
	if kind=="hours"then
		nest={id="nest",text=UICopy.get("onb3.nest.hours",{hours=value}),short=UICopy.get("onb3.nest.chipHours",{hours=value})}
	elseif kind=="minutes"then
		nest={id="nest",text=UICopy.get("onb3.nest.minutes",{minutes=value}),short=UICopy.get("onb3.nest.chipMinutes",{minutes=value})}
	else
		local ready=UICopy.get("onb3.nest.ready")
		nest={id="nest",text=ready,short=ready,gold=true}
	end
	-- The next stamp: today's while it waits, tomorrow's once it is taken (and the first of a new card once full).
	local card=Strip.stamp(ctx.state)
	local stamp={id="stamp",text=UICopy.get("onb3.strip.stamp",{count=card.nextIndex,stars=card.reward}),short=tostring(card.reward),
		stars=card.reward,index=card.nextIndex}
	local quests={id="quests",text=UICopy.get("onb3.strip.quests"),short=tostring(Strip.Quests)}
	return{title=UICopy.get("onb3.strip.title"),wait=UICopy.get("onb3.strip.wait"),chips={nest,stamp,quests}}
end
-- The next stamp and its Stars, as the stamp card reads it (StampCardView.model): today's while it waits, tomorrow's
-- once taken, the first of the next card once the card is full.
function Strip.stamp(state)
	state=if type(state)=="table"then state else {}
	local card=if type(state.stampCard)=="table"then state.stampCard else {}
	local stamps=if type(state.stamps)=="number"and state.stamps==state.stamps and state.stamps>=0 then math.floor(state.stamps)else 0
	local rewards=if type(card.rewards)=="table"and #card.rewards==Stamp.Length then card.rewards else Stamp.Rewards
	local onCard=if type(card.onCard)=="number"then math.clamp(math.floor(card.onCard),0,Stamp.Length-1)else Stamp.onCard(stamps)
	local full=state.dailyAvailable~=true and stamps>0 and onCard==0
	local nextIndex=if full then 1 else onCard+1
	return{nextIndex=nextIndex,reward=rewards[nextIndex]}
end
-- Width of a chip: icon, gap, text, padding.
local function chipWidth(iconSize,textW)return 8+iconSize+6+textW+10 end
-- Pure: what each chip shows in a strip `width` px wide. Text never truncates: a chip shrinks to 11, then switches to
-- its short value. measure(text, size) -> px. options.phone (three equal columns), options.short (short at once).
-- Answers {phone, h, title={x,w}, chips={{x, w, text, size, icon}...}}.
function Strip.fit(model,width,measure,options)
	options=options or {}
	local phone=options.phone==true
	local iconSize=if phone then 16 else 20
	local big=if phone then 12 else 14
	local variants=function(chip)
		if options.short then return{{chip.short,big}}end
		return{{chip.text,big},{chip.text,11},{chip.short,big}}
	end
	local v2=Strip.v2(options)
	local out={phone=phone,v2=v2,h=if phone then Strip.phoneHeight(v2)else Strip.Height.desktop,chips={}}
	if phone and not v2 then
		-- Before v2 (DeckLook off): the title on a tab over the top edge, the chips left-aligned in three columns.
		local gap=Strip.Gap.phone
		local colW=math.floor((width-12-gap*2)/3)
		out.title={x=math.floor((width-Strip.TitleW)/2),w=Strip.TitleW}
		for index,chip in ipairs(model.chips)do
			local pick=nil
			for _,v in ipairs(variants(chip))do
				pick=v
				if chipWidth(iconSize,measure(v[1],v[2]))<=colW then break end
			end
			out.chips[index]={x=6+(index-1)*(colW+gap),w=colW,text=pick[1],size=pick[2],icon=iconSize}
		end
		return out
	end
	if phone then
		-- Beta 12 U7 (strip v2): the title on its own row inside the strip, the chips under it, the words and the icon
		-- centred in each chip. 400 wide or more: the whole words; less: the short values; under 240: no strip (nil).
		if width<Strip.PhoneMin then return nil end
		local short=options.short or width<Strip.PhoneWhole
		local gap=Strip.Gap.phone
		local colW=math.floor((width-12-gap*2)/3)
		out.title={x=25,w=width-25-10,y=Strip.TitleY}
		for index,chip in ipairs(model.chips)do
			local pick=nil
			for _,v in ipairs(if short then {{chip.short,big}}else variants(chip))do
				pick=v
				if chipWidth(iconSize,measure(v[1],v[2]))<=colW then break end
			end
			local inner=iconSize+5+measure(pick[1],pick[2])
			out.chips[index]={x=6+(index-1)*(colW+gap),w=colW,y=Strip.ChipY,h=Strip.ChipH,text=pick[1],size=pick[2],icon=iconSize,
				inset=math.max(4,math.floor((colW-inner)/2))}
		end
		return out
	end
	local gap=Strip.Gap.desktop
	local titleW=if width>=520 then Strip.TitleW else 0
	out.title={x=12,w=titleW}
	local avail=width-12-titleW-(if titleW>0 then 8 else 0)-gap*2-12
	local step,widths={},{}
	for index,chip in ipairs(model.chips)do
		step[index]=1
		local v=variants(chip)[1]
		widths[index]=chipWidth(iconSize,measure(v[1],v[2]))
	end
	local function total()return widths[1]+widths[2]+widths[3]end
	while total()>avail do
		local widest,far=nil,-1
		for index,chip in ipairs(model.chips)do
			if step[index]<#variants(chip)and widths[index]>far then widest,far=index,widths[index]end
		end
		if not widest then break end
		step[widest]+=1
		local v=variants(model.chips[widest])[step[widest]]
		widths[widest]=chipWidth(iconSize,measure(v[1],v[2]))
	end
	local x=12+titleW+(if titleW>0 then 8 else 0)
	for index,chip in ipairs(model.chips)do
		local v=variants(chip)[step[index]]
		out.chips[index]={x=x,w=widths[index],text=v[1],size=v[2],icon=iconSize}
		x+=widths[index]+gap
	end
	return out
end
function Strip.measure(text,size)
	local ok,bounds=pcall(function()
		return game:GetService("TextService"):GetTextSize(text,size,Enum.Font.FredokaOne,Vector2.new(1000,100))
	end)
	return if ok and typeof(bounds)=="Vector2"then math.ceil(bounds.X)+2 else #text*size*.6
end

-- ── Drawing ──────────────────────────────────────────────────────────────────────────────────────────────────────
local function make(class,parent,props)
	local object=Instance.new(class)
	for key,value in pairs(props or {})do object[key]=value end
	object.Parent=parent
	return object
end
local function kit()
	local ok,Kit=pcall(require,script.Parent.DeckKit)
	return if ok and type(Kit)=="table"and type(Kit.icon)=="function"then Kit else nil
end
-- An icon: the nest chip art, the Star, or the atlas quests icon (a glyph when the kit is not there).
local function icon(parent,id,size)
	if id=="nest"then
		return make("ImageLabel",parent,{Name="Icon",BackgroundTransparency=1,Image=Strip.NestIcon,Size=UDim2.fromOffset(size,size)})
	end
	local Kit=kit()
	if Kit then
		local ok,image=pcall(Kit.icon,parent,if id=="stamp"then "star"else "quests",size,if id=="stamp"then "stars"else "text")
		if ok and image then image.Name="Icon";return image end
	end
	local glyph=make("TextLabel",parent,{Name="Icon",BackgroundTransparency=1,Size=UDim2.fromOffset(size,size),Font=Enum.Font.FredokaOne,
		Text=if id=="stamp"then "★"else "!",TextSize=size,TextColor3=if id=="stamp"then Strip.Color.stars else Strip.Color.text})
	glyph.AutoLocalize=false
	return glyph
end
-- parent: the results screen frame. options.phone, options.short (a narrow card), options.wait (show the line under it),
-- options.measure (specs), options.z.
function Strip.new(parent,options)
	options=options or {}
	local self=setmetatable({options=options,chips={}},Strip)
	local phone=options.phone==true
	local v2=Strip.v2(options)
	self.v2=v2
	local h=if phone then Strip.phoneHeight(v2)else Strip.Height.desktop
	local z=options.z or((parent.ZIndex or 1)+2)
	local root=make("Frame",parent,{Name="TomorrowStrip",BackgroundColor3=Strip.Color.well,BackgroundTransparency=0,BorderSizePixel=0,
		Size=UDim2.fromOffset(200,h),ZIndex=z,Active=false,Selectable=false})
	make("UICorner",root,{CornerRadius=UDim.new(0,12)})
	make("UIStroke",root,{Color=Strip.Color.ink,Thickness=2})
	self.root,self.h,self.z=root,h,z
	-- The title: at the left (desktop), on its own row inside the strip with a small moon mark (phone, v2), or on a small
	-- tab centred on the top edge (phone, before v2).
	if phone and not v2 then
		self.tab=make("Frame",root,{Name="TitleTab",BackgroundColor3=Strip.Color.well,BorderSizePixel=0,AnchorPoint=Vector2.new(.5,0),
			Position=UDim2.new(.5,0,0,-7),Size=UDim2.fromOffset(Strip.TitleW,16),ZIndex=z+1})
		make("UICorner",self.tab,{CornerRadius=UDim.new(0,8)})
		self.title=make("TextLabel",self.tab,{Name="Title",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Font=Enum.Font.FredokaOne,
			TextSize=11,TextColor3=Strip.Color.soft,ZIndex=z+2})
	elseif phone then
		local moon=make("Frame",root,{Name="Moon",BackgroundColor3=Strip.Color.soft,BorderSizePixel=0,AnchorPoint=Vector2.new(0,.5),
			Position=UDim2.fromOffset(10,Strip.TitleY),Size=UDim2.fromOffset(10,10),ZIndex=z+1})
		make("UICorner",moon,{CornerRadius=UDim.new(.5,0)})
		local bite=make("Frame",moon,{Name="Bite",BackgroundColor3=Strip.Color.well,BorderSizePixel=0,Position=UDim2.fromOffset(4,-2),Size=UDim2.fromOffset(9,9),ZIndex=z+2})
		make("UICorner",bite,{CornerRadius=UDim.new(.5,0)})
		self.moon=moon
		self.title=make("TextLabel",root,{Name="Title",BackgroundTransparency=1,AnchorPoint=Vector2.new(0,.5),Position=UDim2.fromOffset(25,Strip.TitleY),
			Size=UDim2.new(1,-35,0,14),Font=Enum.Font.FredokaOne,TextSize=12,TextColor3=Strip.Color.soft,TextXAlignment=Enum.TextXAlignment.Left,
			TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=z+1})
	else
		self.title=make("TextLabel",root,{Name="Title",BackgroundTransparency=1,Position=UDim2.fromOffset(12,0),Size=UDim2.fromOffset(Strip.TitleW,h),
			Font=Enum.Font.FredokaOne,TextSize=12,TextColor3=Strip.Color.soft,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=z+1})
	end
	if options.wait then
		self.wait=make("TextLabel",root,{Name="Wait",BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,1,2),
			Size=UDim2.new(1,0,0,14),Font=Enum.Font.FredokaOne,TextSize=11,TextColor3=Strip.Color.soft,ZIndex=z+1})
	end
	return self
end
-- Draw `model` in a strip `width` px wide (the caller places root: Position; this sets its Size).
function Strip:set(model,width)
	self.model=model
	local root=self.root
	if not model then root.Visible=false;return end
	root.Visible=true
	root.Size=UDim2.fromOffset(width,self.h)
	local layout=Strip.fit(model,width,self.options.measure or Strip.measure,{phone=self.options.phone,short=self.options.short,v2=self.v2})
	self.layout=layout
	if not layout then root.Visible=false;return end -- a phone strip too narrow to read (v2): none at all
	self.title.Text=model.title
	self.title.Visible=layout.title.w>0
	if self.wait then self.wait.Text=model.wait end
	for index,spec in ipairs(model.chips)do
		local fit=layout.chips[index]
		local chip=self.chips[index]
		if not chip then
			local frame=make("Frame",root,{Name="Chip_"..spec.id,BackgroundColor3=Strip.Color.chip,BorderSizePixel=0,ZIndex=self.z+1,Active=false})
			make("UICorner",frame,{CornerRadius=UDim.new(1,0)})
			local stroke=make("UIStroke",frame,{Color=Strip.Color.ink,Thickness=1.5})
			local mark=icon(frame,spec.id,fit.icon)
			mark.AnchorPoint=Vector2.new(0,.5);mark.Position=UDim2.new(0,8,.5,0);mark.ZIndex=self.z+2
			local text=make("TextLabel",frame,{Name="Text",BackgroundTransparency=1,Font=Enum.Font.FredokaOne,TextColor3=Strip.Color.text,
				TextXAlignment=Enum.TextXAlignment.Left,ZIndex=self.z+2,TextWrapped=false})
			chip={frame=frame,stroke=stroke,icon=mark,text=text,id=spec.id}
			self.chips[index]=chip
		end
		local chipH=fit.h or self.h-(if self.options.phone then 10 else 12)
		chip.frame.Position=UDim2.fromOffset(fit.x,fit.y or math.floor((self.h-chipH)/2))
		chip.frame.Size=UDim2.fromOffset(fit.w,chipH)
		chip.text.Text=fit.text;chip.text.TextSize=fit.size
		-- The numbers alone (short values) are never sent for translation.
		chip.text.AutoLocalize=tonumber(fit.text)==nil
		-- Phone (v2): the icon and the words centred in the chip; desktop: from the left.
		local left=fit.inset or 8
		chip.icon.Position=UDim2.new(0,left,.5,0)
		local gap=if fit.inset then 5 else 6
		chip.text.Position=UDim2.fromOffset(left+fit.icon+gap,0);chip.text.Size=UDim2.new(1,-(left+fit.icon+gap),1,0)
		chip.frame.BackgroundColor3=if spec.gold then Strip.Color.stars else Strip.Color.chip
		chip.text.TextColor3=if spec.gold or spec.id=="stamp"then(if spec.gold then Strip.Color.ink else Strip.Color.stars)else Strip.Color.text
		chip.stroke.Color=if spec.gold then Strip.Color.gold else Strip.Color.ink
		chip.frame:SetAttribute("StripText",fit.text)
	end
end
-- Texts as shown, for specs and the evidence pass: {title, nest, stamp, quests}.
function Strip:texts()
	local out={title=self.title.Text}
	for _,chip in ipairs(self.chips)do out[chip.id]=chip.text.Text end
	return out
end
-- In: 12 px up and a fade (0.25 s) after `delay`, chips 60 ms apart. Reduced Motion: a fade only.
-- Call it after the strip is placed and set: it tweens back to where it is now. Answers false (and moves nothing)
-- before a set, or for a hidden strip.
function Strip:enter(delay,reduced)
	local root=self.root
	if not self.model or #self.chips==0 or root.Visible==false then return false end
	local home=root.Position
	self.home=home
	local ok=pcall(function()
		local TweenService=game:GetService("TweenService")
		root.BackgroundTransparency=1
		if not reduced then root.Position=home+UDim2.fromOffset(0,12)end
		local info=TweenInfo.new(.25,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,0,false,delay or 0)
		TweenService:Create(root,info,{Position=home,BackgroundTransparency=0}):Play()
		for index,chip in ipairs(self.chips)do
			chip.frame.BackgroundTransparency=1;chip.text.TextTransparency=1
			local at=TweenInfo.new(.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,0,false,(delay or 0)+.1+(index-1)*.06)
			TweenService:Create(chip.frame,at,{BackgroundTransparency=0}):Play()
			TweenService:Create(chip.text,at,{TextTransparency=0}):Play()
		end
	end)
	return ok
end
function Strip:destroy()self.root:Destroy()end
return Strip
