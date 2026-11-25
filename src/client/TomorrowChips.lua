-- The TOMORROW strip (growth cuts 2026-11-25, GROWTH-CUTS-LOOK section 1; FeatureFlags.TomorrowStrip): what is on
-- its way, read from the owner snapshot only (the stamp card, the daily quests, Stat Eggs). Never a made-up number:
-- no snapshot, no strip. Pure (spec-checked): the chips, the PC row layout and the garden rail line. DeckResultsInPlace
-- draws it; CoachCards puts the rail line up once a session.
--   A "today" chip (today's stamp not taken, a daily quest ready to claim) comes BEFORE the eyebrow and takes a tap
--   (it opens Quests); the tomorrow chips after it are plain labels.
local Shared=game:GetService("ReplicatedStorage").Shared
local UICopy=require(Shared.UICopy)
local Stamp=require(Shared.StampCard)
local Quests=require(Shared.QuestCatalog)
local StatEggs=require(Shared.StatEggCatalog)
local Chips={}
-- PC row (`g.phone` false): 36 px at the LCD's foot, 6 px under the panes, which each give up 42 px.
Chips.Height=36
Chips.Gap=6
Chips.Shrink=Chips.Height+Chips.Gap
Chips.Pad=12      -- inside the row, each side
Chips.Spacing=20  -- between chips (and after the eyebrow)
Chips.Icon=18
Chips.IconGap=6
Chips.TextSize=14
Chips.EyebrowSize=12
Chips.Hit=44      -- a today chip's touch target, centred on it
-- Entry: fades up `Rise` px over `Fade` s, `Delay` s after the count-up ends (Reduced Motion: fade only).
Chips.Delay=1
Chips.Fade=.25
Chips.Rise=8
-- Phone block (in the Payout pane, in place of the TODAY line): eyebrow 11, a line each at 12 with a 14 px icon.
Chips.Phone=table.freeze({eyebrow=11,text=12,icon=14,line=20,todayLine=26,hit=44})
-- Garden rail: the first free moment after a results screen, or this long into the session.
Chips.RailAfter=240
Chips.RailSeconds=7
Chips.PetId="blip" -- the stamp card's earned pet (EarnedPets.Rules)

local function count(value)
	return if type(value)=="number"and value==value and value>=0 and value%1==0 then value else 0
end
local function earnedModule(options)
	if options and options.earned~=nil then return options.earned or nil end
	local module=Shared:FindFirstChild("EarnedPets")
	if not module then return nil end
	local ok,value=pcall(require,module)
	return if ok and type(value)=="table"then value else nil
end
local function owns(mask,petId)
	local ok,Eggs=pcall(require,Shared.EggCatalog)
	if not ok then return false end
	local okOwned,owned=pcall(Eggs.isOwned,count(mask),petId)
	return okOwned and owned==true
end
local function petName(petId)
	local ok,Pets=pcall(require,Shared.PetCatalog)
	local pet=ok and Pets.byId and Pets.byId[petId]
	return if pet then pet.name else nil
end

-- The stamp chip. Today's stamp not taken: today's reward, gold, tappable. Taken: the next stamp's position and
-- reward (a card just filled reads Stamp 1). Next is stamp 7 and it brings the earned pet: that pet's line, paw icon.
function Chips.stamp(state,options)
	local stamps=count(state.stamps)
	local reward=Stamp.reward(stamps)
	if state.dailyAvailable==true then
		return{id="stamp",today=true,icon="check",color="stars",text=UICopy.get("tomorrow.stampToday",{reward=reward})}
	end
	local position=Stamp.position(stamps)
	local earned=earnedModule(options)
	local rule=earned and type(earned.Rules)=="table"and earned.Rules[Chips.PetId]
	if position==Stamp.Length and rule and type(earned.enabled)=="function"and earned.enabled(Chips.PetId)
		and stamps+1>=count(rule.stamps)and not owns(state.inventoryMask,Chips.PetId)then
		local name=petName(Chips.PetId)
		if name then return{id="stamp",icon="paw",color="accent",text=UICopy.get("tomorrow.stampPet",{pet=name,reward=reward})}end
	end
	return{id="stamp",icon="check",color="accent",text=UICopy.get("tomorrow.stamp",{count=position,reward=reward})}
end
-- The quests chip: daily quests ready to claim now (accent, tappable), else tomorrow's new ones.
function Chips.quests(state)
	local q=type(state.quests)=="table"and state.quests or nil
	local ready=0
	for _,row in ipairs(q and type(q.daily)=="table"and q.daily or {})do
		if type(row)=="table"and row.ready==true then ready+=1 end
	end
	if ready>0 then
		return{id="quests",today=true,icon="quests",color="accent",
			text=if ready==1 then UICopy.get("tomorrow.claimOne")else UICopy.get("tomorrow.claim",{count=ready})}
	end
	return{id="quests",icon="quests",color="text",text=UICopy.get("tomorrow.quests",{count=#Quests.Pools})}
end
-- The Stat Egg chip: only with Stat Eggs on, a pet, and not on phones.
function Chips.statEggs(state,phone)
	if phone or StatEggs.Enabled~=true or count(state.inventoryMask)==0 then return nil end
	local egg=state.statEgg
	if type(egg)~="table"or egg.enabled==false then return nil end
	local buys=if count(egg.dailyBuys)>0 then egg.dailyBuys else StatEggs.DailyBuys
	return{id="statEggs",icon="egg",color="text",text=UICopy.get("tomorrow.statEggs",{count=buys})}
end
-- The strip: nil without a snapshot; else {before = today chips, after = tomorrow chips}.
-- options: {phone = bool, earned = EarnedPets stand-in (specs; false = none)}.
function Chips.model(state,options)
	if type(state)~="table"then return nil end
	options=options or {}
	local model={before={},after={}}
	for _,chip in ipairs({Chips.stamp(state,options),Chips.quests(state),Chips.statEggs(state,options.phone==true)})do
		table.insert(if chip.today then model.before else model.after,chip)
	end
	return model
end
-- PC row layout in `width` px. measure(text, size) -> px width. Returns {items = {{kind, chip, x, w}}, dropped}:
-- before chips, the eyebrow (only when a tomorrow chip follows), after chips. Too wide: the Stat Egg chip goes
-- first and nothing else is shortened. All three chips: from the left edge; fewer: centred.
function Chips.layout(model,width,measure)
	if not model then return{items={},dropped=false}end
	local function build(skipStat)
		local items={}
		local function add(kind,chip,w)table.insert(items,{kind=kind,chip=chip,w=w})end
		local chips=0
		for _,chip in ipairs(model.before)do add("chip",chip,Chips.Icon+Chips.IconGap+math.ceil(measure(chip.text,Chips.TextSize)));chips+=1 end
		local after={}
		for _,chip in ipairs(model.after)do if not(skipStat and chip.id=="statEggs")then table.insert(after,chip)end end
		if #after>0 then add("eyebrow",nil,math.ceil(measure(UICopy.get("tomorrow.label"),Chips.EyebrowSize)))end
		for _,chip in ipairs(after)do add("chip",chip,Chips.Icon+Chips.IconGap+math.ceil(measure(chip.text,Chips.TextSize)));chips+=1 end
		local total=0
		for i,item in ipairs(items)do total+=item.w+(if i>1 then Chips.Spacing else 0)end
		return items,total,chips
	end
	local items,total,chips=build(false)
	local dropped=false
	if total>width-2*Chips.Pad then
		local hasStat=false
		for _,chip in ipairs(model.after)do if chip.id=="statEggs"then hasStat=true end end
		if hasStat then items,total,chips=build(true);dropped=true end
	end
	local x=if chips>=3 then Chips.Pad else math.max(Chips.Pad,math.floor((width-total)/2))
	for _,item in ipairs(items)do item.x=x;x+=item.w+Chips.Spacing end
	return{items=items,dropped=dropped}
end
-- The garden rail line: today's stamp while it waits, else tomorrow's stamp and quests. nil without a snapshot.
function Chips.rail(state)
	if type(state)~="table"then return nil end
	local stamps=count(state.stamps)
	if state.dailyAvailable==true then return UICopy.get("tomorrow.railToday",{reward=Stamp.reward(stamps)})end
	return UICopy.get("tomorrow.rail",{count=Stamp.position(stamps),reward=Stamp.reward(stamps),quests=#Quests.Pools})
end
-- Is the garden line due? ctx: {sawResults, sessionFor (s), shown}. Once a session.
function Chips.railDue(ctx)
	if type(ctx)~="table"or ctx.shown then return false end
	return ctx.sawResults==true or(ctx.sessionFor or 0)>=Chips.RailAfter
end
-- Beta port (PORT-TO-BETA.md): does the live strip and its rail line apply? The switch on, and onboarding v3's Sleepy
-- Nest not owning the moment (Onboard.on("nest"): its Coming up strip on the results and its egg ticket on the rail).
-- env = {flags, nest} for specs; the game passes nothing. An Onboard that cannot be read counts as off (live).
function Chips.live(env)
	env=env or {}
	local flags=env.flags
	if flags==nil then
		local ok,value=pcall(require,Shared.FeatureFlags)
		flags=if ok and type(value)=="table"then value else {}
	end
	if flags.TomorrowStrip~=true then return false end
	local nest=env.nest
	if nest==nil then
		local ok,on=pcall(function()return require(Shared.Onboard).on("nest")end)
		nest=ok and on==true
	end
	return nest~=true
end
-- Entry progress (0..1) at `t` s since the count-up ended (nil = not ended).
function Chips.entry(t)
	if type(t)~="number"then return 0 end
	return math.clamp((t-Chips.Delay)/Chips.Fade,0,1)
end

return Chips
