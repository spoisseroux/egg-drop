-- The "Coming up" strip (ONBOARDING-V3-PLAN-2026-11-23 slice E; NEST-LOOK section 7; QA-R2-LOOK 5): one well-filled
-- row on the results screens (DeckResults, DeckResultsInPlace, the Dash results card) while Onboard.on("nest"): a small
-- live status of what is on its way while you play. The egg's clock (gold "Egg ready!" when it is), the next stamp and
-- the day's quests, each with a whole, a short and a tiny form; ready chips first. Never a button, never focusable, no
-- sound. Nothing at all when the nest is off or there is no egg. The module keeps its old file name.
-- Live: given a source (a function answering the model), the strip re-reads it once a second while it is shown and
-- writes only what changed (in practice once a minute). One connection per strip, gone on hide and on Destroying.
-- Presentation only: Strip.model is pure (spec-checked); Strip.new draws it with plain instances (the deck's colours).
local Shared=game:GetService("ReplicatedStorage").Shared
local UICopy=require(Shared.UICopy)
local Quests=require(Shared.QuestCatalog)
local Stamp=require(Shared.StampCard)
local Eggs=require(Shared.EggCatalog)
local Strip={};Strip.__index=Strip
Strip.Quests=#Quests.Pools -- one new daily quest a pool, every day
Strip.Name="ComingUpStrip"
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
Strip.PhoneWhole=400  -- from this wide a phone strip has room for the whole words (when they fit their column)
Strip.PhoneTiny=300   -- under this wide a phone strip uses the tiny forms
Strip.TitleY=11       -- the title row's middle
Strip.ChipY=21
Strip.ChipH=22
Strip.Gap=table.freeze({desktop=8,phone=6})
Strip.TitleW=132
Strip.NarrowCard=420     -- a card narrower than this uses the short values at once
Strip.WaitMinScreen=400  -- the "Miss a day, lose nothing." line is left out below this screen height
Strip.Refresh=1          -- seconds between live passes
Strip.Color=table.freeze({well=Color3.fromHex("#20234A"),ink=Color3.fromHex("#15143A"),stars=Color3.fromHex("#FFC14D"),
	gold=Color3.fromHex("#FFE08A"),text=Color3.fromHex("#FFFFFF"),soft=Color3.fromHex("#DCE5FF"),chip=Color3.fromHex("#2C3060")})
Strip.NestIcon="rbxassetid://114080030018596"

-- ── Pure ─────────────────────────────────────────────────────────────────────────────────────────────────────────
local function get(key,vars)return UICopy.get("onb3.strip."..key,vars)end
-- A countdown as words: kind "ready" | "soon" | "hm" | "h" | "m" with hours and minutes. Minutes are rounded up and
-- hours are what is left whole (7 h 52 m, never "8 h" with 7 h 10 m to go; 7 h 59 m 30 s reads 8 h).
function Strip.clock(left)
	if type(left)~="number"or left~=left or left<=0 then return "ready",0,0 end
	if left<60 then return "soon",0,1 end
	local m=math.ceil(left/60)
	local hours,minutes=m//60,m%60
	if hours==0 then return "m",0,minutes end
	if minutes==0 then return "h",hours,0 end
	return "hm",hours,minutes
end
-- A reset `left` seconds away in the egg's words (FABLE-REVIEW-R3 5.3: "Stamp 1 in 8 h" with 7 h 17 m left broke the
-- floor rule): whole, short and tiny for a `key` family ("stampIn" or "questsIn": key.."HM", key, key.."M").
function Strip.resetWords(left,key,vars)
	local kind,hours,minutes=Strip.clock(left)
	if kind=="ready"or kind=="soon"then kind,minutes="m",1 end
	vars=table.clone(vars or {});vars.hours,vars.minutes=hours,minutes
	local whole=if kind=="hm"then key.."HM"elseif kind=="h"then key else key.."M"
	return get(whole,vars),get("short."..kind,vars),get("tiny."..kind,vars)
end
-- Seconds to the next day boundary at server time `now` (QuestState.dayStart / DailyContracts.dayOf, never the garden
-- hour's offset clock).
function Strip.resetIn(now)
	local day=math.floor((now+Eggs.DayOffsetSeconds)/86400)
	return(day+1)*86400-Eggs.DayOffsetSeconds-now
end
function Strip.dayOf(now)return math.floor((now+Eggs.DayOffsetSeconds)/86400)end
-- The egg chip: whole, short and tiny words for `left` seconds.
function Strip.eggChip(left)
	local kind,hours,minutes=Strip.clock(left)
	local vars={hours=hours,minutes=minutes}
	if kind=="ready"then
		return{id="nest",text=get("eggReady"),short=get("short.ready"),tiny=get("tiny.ready"),gold=true,ready=true}
	end
	local whole=if kind=="hm"then "eggHM"elseif kind=="h"then "eggH"elseif kind=="m"then "eggM"else "eggSoon"
	return{id="nest",text=get(whole,vars),short=get("short."..kind,vars),tiny=get("tiny."..kind,vars)}
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
-- The day's quests from the owner snapshot: rows not yet claimed (claimable ones count as to go), claimable ones, and
-- the snapshot's own day. Weekly quests are left out. No snapshot: the day's full set.
function Strip.quests(state)
	local q=type(state)=="table"and type(state.quests)=="table"and state.quests or nil
	local rows=q and type(q.daily)=="table"and q.daily or nil
	if not rows then return{left=Strip.Quests,ready=0,day=nil}end
	local left,ready=0,0
	for _,row in ipairs(rows)do
		if type(row)=="table"and row.claimed~=true then left+=1;if row.ready==true then ready+=1 end end
	end
	return{left=left,ready=ready,day=tonumber(q.day)}
end
-- ctx = {on = Onboard.on("nest"), nest = NestClient:summary() ({left, view}) or nil, state = the owner snapshot,
-- now = server time (GetServerTimeNow; specs pass it)}. Answers nil (no strip) or {title, wait, chips}, the chips in
-- show order (ready first: egg, stamp, quests); each {id, text, short, tiny, gold?, ready?, outline?, soft?, icon}.
function Strip.model(ctx)
	if type(ctx)~="table"or ctx.on~=true or type(ctx.nest)~="table"or type(ctx.nest.left)~="number"then return nil end
	local now=ctx.now
	if type(now)~="number"then
		local ok,value=pcall(function()return workspace:GetServerTimeNow()end)
		now=if ok and type(value)=="number"then value else nil
	end
	local state=if type(ctx.state)=="table"then ctx.state else {}
	local nest=Strip.eggChip(ctx.nest.left)
	nest.icon="nest"
	-- The reset is known while the snapshot is of today; past the boundary the snapshot is stale until the next one.
	local quests=Strip.quests(state)
	local reset=if now then Strip.resetIn(now)else nil
	local today=now~=nil and(quests.day==nil or quests.day==Strip.dayOf(now))
	local card=Strip.stamp(state)
	local stamp
	if state.dailyAvailable==true then
		local words="+"..tostring(card.reward)
		stamp={id="stamp",text=get("stampReady",{count=card.nextIndex,stars=card.reward}),short=words,tiny=words,ready=true,outline=true}
	elseif reset and today then
		local text,short,tiny=Strip.resetWords(reset,"stampIn",{count=card.nextIndex})
		stamp={id="stamp",text=text,short=short,tiny=tiny}
	else
		local words="+"..tostring(card.reward)
		stamp={id="stamp",text=get("stampNext",{stars=card.reward}),short=words,tiny=words}
	end
	stamp.icon,stamp.stars,stamp.index="star",card.reward,card.nextIndex
	local chip
	if quests.ready>0 then
		-- FABLE-REVIEW-R3 5.1: gold means ready, and says so.
		chip={id="quests",text=get("questsReady",{count=quests.ready}),short=get("short.ready"),tiny=get("tiny.ready"),icon="quests",ready=true,outline=true}
	elseif quests.left>0 then
		chip={id="quests",text=if quests.left==1 then get("questsOne")else get("questsLeft",{left=quests.left}),
			short=get("short.left",{left=quests.left}),tiny=tostring(quests.left),icon="quests"}
	elseif reset and today then
		local text,short,tiny=Strip.resetWords(reset,"questsIn")
		chip={id="quests",text=text,short=short,tiny=tiny,icon="check",soft=true}
	else
		chip={id="quests",text=get("questsDone"),short=get("short.done"),tiny=get("tiny.done"),icon="check",soft=true}
	end
	local chips={}
	for _,c in ipairs({nest,stamp,chip})do if c.ready then table.insert(chips,c)end end
	for _,c in ipairs({nest,stamp,chip})do if not c.ready then table.insert(chips,c)end end
	return{title=get("title"),wait=get("wait"),chips=chips}
end
-- A model's words in one string (the live pass compares it).
function Strip.signature(model)
	if not model then return ""end
	local parts={}
	for _,c in ipairs(model.chips)do
		table.insert(parts,table.concat({c.id,c.text,c.short,c.tiny,c.icon or"",tostring(c.gold==true),tostring(c.outline==true)},"\1"))
	end
	return table.concat(parts,"\2")
end
-- Width of a chip: icon, gap, text, padding.
local function chipWidth(iconSize,textW)return 8+iconSize+6+textW+10 end
-- Pure: what each chip shows in a strip `width` px wide. Text never truncates: a chip shrinks to 11, then switches to
-- its short value, then its tiny one. measure(text, size) -> px. options.phone (three equal columns), options.short
-- (short at once). Answers {phone, h, title={x,w}, chips={{x, w, text, size, icon}...}}.
function Strip.fit(model,width,measure,options)
	options=options or {}
	local phone=options.phone==true
	local iconSize=if phone then 16 else 20
	local big=if phone then 12 else 14
	local function tinyOf(chip)return chip.tiny or chip.short end
	local variants=function(chip)
		if options.short then return{{chip.short,big},{tinyOf(chip),big}}end
		return{{chip.text,big},{chip.text,11},{chip.short,big},{tinyOf(chip),big}}
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
		-- centred in each chip. 400 wide or more: the whole words when they fit their column, else short; under 300:
		-- the tiny forms; under 240: no strip (nil).
		if width<Strip.PhoneMin then return nil end
		local gap=Strip.Gap.phone
		local colW=math.floor((width-12-gap*2)/3)
		out.title={x=25,w=width-25-10,y=Strip.TitleY}
		for index,chip in ipairs(model.chips)do
			local list
			if width<Strip.PhoneTiny then list={{tinyOf(chip),big}}
			elseif options.short or width<Strip.PhoneWhole then list={{chip.short,big},{tinyOf(chip),big}}
			else list={{chip.text,big},{chip.short,big},{tinyOf(chip),big}}end
			local pick=nil
			for _,v in ipairs(list)do
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
	local function total()local sum=0;for _,w in ipairs(widths)do sum+=w end;return sum end
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
-- A bare number ("+25", "2") is never sent for translation.
function Strip.numeric(text)return string.match(text,"^%+?%d+$")~=nil end

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
-- An icon: the nest chip art, the Star, the atlas quests icon or the tick (a glyph when the kit is not there).
local function icon(parent,name,size)
	if name=="nest"then
		return make("ImageLabel",parent,{Name="Icon",BackgroundTransparency=1,Image=Strip.NestIcon,Size=UDim2.fromOffset(size,size)})
	end
	local Kit=kit()
	if Kit then
		local ok,image=pcall(Kit.icon,parent,name,size,if name=="star"then "stars"else "text")
		if ok and image then image.Name="Icon";return image end
	end
	local glyph=make("TextLabel",parent,{Name="Icon",BackgroundTransparency=1,Size=UDim2.fromOffset(size,size),Font=Enum.Font.FredokaOne,
		Text=if name=="star"then "★"elseif name=="check"then "✓"else "!",TextSize=size,TextColor3=if name=="star"then Strip.Color.stars else Strip.Color.text})
	glyph.AutoLocalize=false
	return glyph
end
-- The title's mark on the phone (v2): a 10 px clock, a soft disc with two 1 px ink hands (4 px up, 3 px right).
local function clockMark(root)
	local disc=make("Frame",root,{Name="Clock",BackgroundColor3=Strip.Color.soft,BorderSizePixel=0,AnchorPoint=Vector2.new(0,.5),
		Position=UDim2.fromOffset(10,Strip.TitleY),Size=UDim2.fromOffset(10,10),ZIndex=root.ZIndex+1})
	make("UICorner",disc,{CornerRadius=UDim.new(.5,0)})
	make("Frame",disc,{Name="HandUp",BackgroundColor3=Strip.Color.ink,BorderSizePixel=0,Position=UDim2.fromOffset(4,1),Size=UDim2.fromOffset(1,4),ZIndex=root.ZIndex+2})
	make("Frame",disc,{Name="HandRight",BackgroundColor3=Strip.Color.ink,BorderSizePixel=0,Position=UDim2.fromOffset(5,4),Size=UDim2.fromOffset(3,1),ZIndex=root.ZIndex+2})
	return disc
end
-- parent: the results screen frame. options.phone, options.short (a narrow card), options.wait (show the line under it),
-- options.measure (specs), options.z, options.source (a function answering the model: the strip then lives, see
-- Strip:live), options.reduced (a function; Reduced Motion: no bounce), options.clock (specs: {connect(fn) -> handle}).
function Strip.new(parent,options)
	options=options or {}
	local self=setmetatable({options=options,chips={},byId={}},Strip)
	local phone=options.phone==true
	local v2=Strip.v2(options)
	self.v2=v2
	local h=if phone then Strip.phoneHeight(v2)else Strip.Height.desktop
	local z=options.z or((parent.ZIndex or 1)+2)
	local root=make("Frame",parent,{Name=Strip.Name,BackgroundColor3=Strip.Color.well,BackgroundTransparency=0,BorderSizePixel=0,
		Size=UDim2.fromOffset(200,h),ZIndex=z,Active=false,Selectable=false})
	make("UICorner",root,{CornerRadius=UDim.new(0,12)})
	make("UIStroke",root,{Color=Strip.Color.ink,Thickness=2})
	self.root,self.h,self.z=root,h,z
	-- The title: at the left (desktop), on its own row inside the strip with the clock mark (phone, v2), or on a small
	-- tab centred on the top edge (phone, before v2).
	if phone and not v2 then
		self.tab=make("Frame",root,{Name="TitleTab",BackgroundColor3=Strip.Color.well,BorderSizePixel=0,AnchorPoint=Vector2.new(.5,0),
			Position=UDim2.new(.5,0,0,-7),Size=UDim2.fromOffset(Strip.TitleW,16),ZIndex=z+1})
		make("UICorner",self.tab,{CornerRadius=UDim.new(0,8)})
		self.title=make("TextLabel",self.tab,{Name="Title",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Font=Enum.Font.FredokaOne,
			TextSize=11,TextColor3=Strip.Color.soft,ZIndex=z+2})
	elseif phone then
		self.mark=clockMark(root)
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
	local ok,link=pcall(function()return root.Destroying:Connect(function()self:stopLive()end)end)
	self.destroying=if ok then link else nil
	return self
end
local function chipFor(self,spec,size)
	local chip=self.byId[spec.id]
	if not chip then
		local frame=make("Frame",self.root,{Name="Chip_"..spec.id,BackgroundColor3=Strip.Color.chip,BorderSizePixel=0,ZIndex=self.z+1,Active=false})
		make("UICorner",frame,{CornerRadius=UDim.new(1,0)})
		local stroke=make("UIStroke",frame,{Color=Strip.Color.ink,Thickness=1.5})
		local text=make("TextLabel",frame,{Name="Text",BackgroundTransparency=1,Font=Enum.Font.FredokaOne,TextColor3=Strip.Color.text,
			TextXAlignment=Enum.TextXAlignment.Left,ZIndex=self.z+2,TextWrapped=false})
		chip={frame=frame,stroke=stroke,text=text,id=spec.id}
		self.byId[spec.id]=chip
	end
	local name=spec.icon or spec.id
	if chip.iconName~=name or chip.iconSize~=size then
		if chip.icon then chip.icon:Destroy()end
		local mark=icon(chip.frame,name,size)
		mark.AnchorPoint=Vector2.new(0,.5);mark.Position=UDim2.new(0,8,.5,0);mark.ZIndex=self.z+2
		chip.icon,chip.iconName,chip.iconSize=mark,name,size
	end
	return chip
end
-- Draw `model` in a strip `width` px wide (the caller places root: Position; this sets its Size).
function Strip:set(model,width)
	self.model,self.width=model,width
	self.signatureShown=Strip.signature(model)
	local root=self.root
	if not model then root.Visible=false;self:stopLive();return end
	root.Visible=true
	root.Size=UDim2.fromOffset(width,self.h)
	local layout=Strip.fit(model,width,self.options.measure or Strip.measure,{phone=self.options.phone,short=self.options.short,v2=self.v2})
	self.layout=layout
	if not layout then root.Visible=false;self:stopLive();return end -- a phone strip too narrow to read (v2): none at all
	if self.title.Text~=model.title then self.title.Text=model.title end
	self.title.Visible=layout.title.w>0
	if self.wait and self.wait.Text~=model.wait then self.wait.Text=model.wait end
	table.clear(self.chips)
	for index,spec in ipairs(model.chips)do
		local fit=layout.chips[index]
		local chip=chipFor(self,spec,fit.icon)
		self.chips[index]=chip
		local chipH=fit.h or self.h-(if self.options.phone then 10 else 12)
		chip.frame.Position=UDim2.fromOffset(fit.x,fit.y or math.floor((self.h-chipH)/2))
		chip.frame.Size=UDim2.fromOffset(fit.w,chipH)
		if chip.text.Text~=fit.text then chip.text.Text=fit.text end
		chip.text.TextSize=fit.size
		chip.text.AutoLocalize=not Strip.numeric(fit.text)
		-- Phone (v2): the icon and the words centred in the chip; desktop: from the left.
		local left=fit.inset or 8
		chip.icon.Position=UDim2.new(0,left,.5,0)
		local gap=if fit.inset then 5 else 6
		chip.text.Position=UDim2.fromOffset(left+fit.icon+gap,0);chip.text.Size=UDim2.new(1,-(left+fit.icon+gap),1,0)
		chip.frame.BackgroundColor3=if spec.gold then Strip.Color.stars else Strip.Color.chip
		-- FABLE-REVIEW-R3 5.2: gold text only on a ready stamp (the Star icon stays gold); a ready outline is #FFC14D, 2 px.
		chip.text.TextColor3=if spec.gold then Strip.Color.ink elseif spec.soft then Strip.Color.soft elseif spec.id=="stamp"and spec.ready then Strip.Color.stars else Strip.Color.text
		chip.stroke.Color=if spec.outline then Strip.Color.stars elseif spec.gold then Strip.Color.gold else Strip.Color.ink
		chip.stroke.Thickness=if spec.outline then 2 else 1.5
		chip.gold=spec.gold==true
		chip.frame:SetAttribute("StripText",fit.text)
	end
	if self.options.source then self:live()end
end
-- Texts as shown, for specs and the evidence pass: {title, nest, stamp, quests}.
function Strip:texts()
	local out={title=self.title.Text}
	for _,chip in ipairs(self.chips)do out[chip.id]=chip.text.Text end
	return out
end
-- Shown: parented and nothing above it hidden. Answers false and the node that hides it (and the property).
function Strip:shown()
	local node=self.root
	if not node.Parent then return false end
	while node and node~=game do
		if(node:IsA("GuiObject")or node:IsA("Frame"))and node.Visible==false then return false,node,"Visible" end
		if(node:IsA("LayerCollector")or node:IsA("ScreenGui"))and node.Enabled==false then return false,node,"Enabled" end
		node=node.Parent
	end
	return true
end
-- One live pass: re-read the source; a nil answer (the nest summary between packets) keeps the last model as it is.
-- Writes only when a word changed; the egg turning ready bounces its chip once (Reduced Motion: the colour only).
function Strip:refresh()
	local source=self.options.source
	if not source or not self.model then return false end
	local ok,model=pcall(source)
	if not ok or type(model)~="table"then return false end
	local signature=Strip.signature(model)
	if signature==self.signatureShown then return false end
	local wasGold=self.byId.nest and self.byId.nest.gold
	self:set(model,self.width)
	local egg=self.byId.nest
	if egg and egg.gold and wasGold==false then
		local reduced=self.options.reduced and self.options.reduced()==true
		local Kit=kit()
		if Kit and not reduced and type(Kit.boing)=="function"then pcall(Kit.boing,egg.frame)end
	end
	return true
end
-- The live pass, once a second while shown. Hidden (the strip or a screen above it): the pass is cut and one watch
-- waits on whatever hides it, bringing the pass back when it shows. Out of the game, destroyed or set to nothing: both go
-- (a later set brings it back). options.clock (specs): {connect(fn) -> handle, watch(node, property, fn) -> handle}.
function Strip:park(node,property)
	self:stopLive()
	local function wake()
		if self.wake then self.wake:Disconnect();self.wake=nil end
		self:live()
	end
	local ok,handle=pcall(function()
		if self.options.clock and self.options.clock.watch then return self.options.clock.watch(node,property,wake)end
		return node:GetPropertyChangedSignal(property):Connect(wake)
	end)
	if ok and handle then self.wake=handle;return true end
	return false
end
function Strip:live()
	if self.link or self.wake or not self.options.source or not self.model then return end
	local shown,node,property=self:shown()
	if not shown and node and self:park(node,property)then return end
	local elapsed=0
	local function tick(dt)
		elapsed+=dt
		if elapsed<Strip.Refresh then return end
		elapsed=0
		if not self.root.Parent then self:stopLive();return end -- removed or destroyed (Destroying also cuts it)
		local now,hider,which=self:shown()
		if not now then
			if hider then self:park(hider,which)end -- no watch to be had: keep the pass, skip it
			return
		end
		local ok,problem=pcall(self.refresh,self)
		if not ok then warn("[Strip] live: "..tostring(problem));self:stopLive()end
	end
	if self.options.clock then self.link=self.options.clock.connect(tick)
	else self.link=game:GetService("RunService").Heartbeat:Connect(tick)end
end
function Strip:stopLive()
	if self.link then self.link:Disconnect();self.link=nil end
	if self.wake then self.wake:Disconnect();self.wake=nil end
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
function Strip:destroy()
	self:stopLive()
	if self.destroying then self.destroying:Disconnect();self.destroying=nil end
	self.root:Destroy()
end
return Strip
