-- The first full Pocket Deck round (artifacts/qa-2026-11-27-beta42/TEACH-MORE-BRIEF.md section 1, ARCH-REVIEW-TEACH 6 to
-- 8; Onboard "teach"; Spencer's beta 42 note 6: "after the egg when were playing a full game for the first time we need
-- onboarding for the game too: how to read the ui, how to switch difficulty, quests, etc").
--   The tour   rounds == 0, a field round (not Welcome, not guided), nothing dropped yet (the Difficulty card is still the
--              control, so the tour costs nothing): three pointers on the deck's own cards, the others dimmed through the
--              deck's calm path (DeckScreen:teachDim). 1 Goals "Tick these to win!", 2 Balls left "Your balls. Use them
--              well!", 3 the level card "Tap to change level!" with "Harder pays more ★" on Win pays. Each label carries
--              "1/3".
--   Next       a tap on any HUD card (read from UserInputService.InputBegan by position, never an Active or Modal frame),
--              Enter, or R1. Skip: the Skip pill under the label (a tap) or L1. A, Space, B and touch on the board stay
--              the round's own (drop, items): this binds none of them. No long-press, no countdown; untouched, it stays.
--   Ends       on Skip, past step 3, or the first drop (on any step): saves `deckTour`. Stepping the level on step 3 saves
--              `level`; without it, the round-two opener shows step 3 alone once and saves `level` whatever they do.
--   Tips       during a round, one quiet rail pill each, saved the moment it shows, at least 8 s apart, never with
--              another pill on the rail (the fill line) and never after the round ends: tipNext (the first drop
--              landed), tipChain (a chain of x2 or more), tipGoal (the first goal ticked).
-- Graduated (`done`) or a save never owed the chain: nothing. Pure rules first (DeckTour.spec), then the controller.
local Tour={};Tour.__index=Tour
Tour.Steps=table.freeze({
	table.freeze({card="Goals",words="teach.tour1"}),
	table.freeze({card="EggsLeft",words="teach.tour2"}),
	table.freeze({card="Difficulty",words="teach.level",sub="WinPays",subWords="teach.levelSub"}),
})
Tour.LevelStep=3
-- Keys by name (KeyCode names), bound only while a step shows. Never the round's own (Forbidden).
Tour.KeyNames=table.freeze({next=table.freeze({"Return","KeypadEnter","ButtonR1"}),skip=table.freeze({"ButtonL1"})})
Tour.Forbidden=table.freeze({"A","Space","B","Backspace","ButtonA","ButtonB","ButtonX","Left","Right","Up","Down","M","ButtonY"})
Tour.Glyphs=table.freeze({key="ENTER",glyph="R1"})
Tour.TipGap=8 -- s between two tips at least
Tour.MissingGrace=1 -- s a step's card may be missing (the HUD rebuilding) before the tour moves past it
Tour.TipOrder=table.freeze({"tipNext","tipChain","tipGoal"})
Tour.TipWords=table.freeze({tipNext="teach.tipNext",tipChain="teach.tipChain",tipGoal="teach.tipGoal"})

-- ── Pure ────────────────────────────────────────────────────────────────────────────────────────────────────────────
-- The round can carry a tour step now: a field round on the deck, not guided, nothing dropped, not over, no deck layer up.
-- ctx: {mode, phase, guided, drops, over, overlay}
function Tour.opener(ctx)
	ctx=ctx or {}
	return ctx.mode=="Board"and ctx.phase~=nil and ctx.phase~="Welcome"and ctx.guided~=true and(ctx.drops or 0)==0
		and ctx.over~=true and ctx.overlay~=true
end
-- Which tour wants this opener: "tour" (the first field round), "level" (the round-two opener, step 3 alone) or nil.
-- f: TeachLessons facts (on, graduated, latched, rounds).
function Tour.mode(f,ctx)
	if type(f)~="table"or f.on~=true or f.graduated==true or not Tour.opener(ctx)then return nil end
	local l=f.latched or {}
	local rounds=f.rounds or 0
	if rounds==0 and not l.deckTour then return "tour"end
	if rounds==1 and not l.level then return "level"end
	return nil
end
function Tour.first(mode)return if mode=="level"then Tour.LevelStep elseif mode=="tour"then 1 else nil end
-- The step after `step` for an action ("next", "skip", "drop"); nil when the tour is over.
function Tour.after(mode,step,action)
	if action~="next"or mode~="tour"then return nil end
	if step<#Tour.Steps then return step+1 end
	return nil
end
-- What the tour saves when it ends: the tour always (mode "tour"); `level` when it was stepped on step 3, and always in
-- the round-two opener.
function Tour.saves(mode,stepped)
	local out={}
	if mode=="tour"then table.insert(out,"deckTour")end
	if mode=="level"or stepped==true then table.insert(out,"level")end
	return out
end
-- The label's words for a step: the line, then "1/3" (the tour only; the opener's step 3 alone has no count).
function Tour.label(line,mode,step,count)
	if mode=="tour"and type(count)=="string"and count~=""then return line.."  "..count end
	return line
end
-- The next tip due now, or nil. ctx: {mode, phase, over, drops, chain, goalsDone, now, lastTip, railEmpty, touring}; f as
-- for mode(). Only a field round, only while it runs.
function Tour.tip(f,ctx)
	if type(f)~="table"or f.on~=true or f.graduated==true then return nil end
	ctx=ctx or {}
	if ctx.mode~="Board"or ctx.phase==nil or ctx.phase=="Welcome"or ctx.over==true or ctx.touring==true then return nil end
	if ctx.railEmpty==false then return nil end
	if ctx.lastTip and(ctx.now or 0)-ctx.lastTip<Tour.TipGap then return nil end
	local l=f.latched or {}
	local facts={tipNext=(ctx.drops or 0)>=1,tipChain=(ctx.chain or 0)>=2,tipGoal=(ctx.goalsDone or 0)>=1}
	for _,id in ipairs(Tour.TipOrder)do
		if facts[id]and not l[id]then return id end
	end
	return nil
end
-- Never the round's own keys (ARCH-REVIEW-TEACH 6).
function Tour.keysSafe()
	for _,list in pairs(Tour.KeyNames)do
		for _,name in ipairs(list)do if table.find(Tour.Forbidden,name)then return false end end
	end
	return true
end

-- ── The controller ─────────────────────────────────────────────────────────────────────────────────────────────────
-- deps: facts() (TeachLessons facts), ctx() (the round: mode, phase, guided, drops, over, overlay, chain, goalsDone),
--   deck() (DeckScreen: hudRoot, teachDim), latch(id), text(key, vars), pointer (a TeachPointer of its own),
--   picked() (the level stepper's last pick: any value that changes when the level is stepped), rail(id, text) (a quiet
--   pill; true when queued), railEmpty(), event(name), playerGui(); listen = false (specs) binds no keys or taps
function Tour.new(deps)
	return setmetatable({d=deps,active=nil,lastTip=nil,tipping=nil},Tour)
end
local function cardOf(deck,name)
	local host=deck and deck.hudRoot
	local c=host and host:FindFirstChild(name)
	return if c and c:IsA("GuiObject")and c.Visible then c else nil
end
function Tour:dim(lit)
	local deck=self.d.deck()
	if deck and deck.teachDim then pcall(deck.teachDim,deck,lit)end
end
function Tour:bind(on)
	if self.d.listen==false then return end -- specs: no engine input
	local okCas,CAS=pcall(function()return game:GetService("ContextActionService")end)
	if not okCas then return end
	if on and not self.bound then
		self.bound=true
		local keys={}
		for _,list in pairs(Tour.KeyNames)do for _,name in ipairs(list)do table.insert(keys,Enum.KeyCode[name])end end
		pcall(CAS.BindActionAtPriority,CAS,"EggDropDeckTour",function(_,state,input)
			if not self.active then return Enum.ContextActionResult.Pass end
			if state==Enum.UserInputState.Begin then
				local skip=table.find(Tour.KeyNames.skip,input.KeyCode.Name)~=nil
				self:act(if skip then "skip"else "next")
			end
			return Enum.ContextActionResult.Sink
		end,false,Enum.ContextActionPriority.High.Value+900,table.unpack(keys))
	elseif not on and self.bound then
		self.bound=false
		pcall(CAS.UnbindAction,CAS,"EggDropDeckTour")
	end
end
function Tour:listen()
	if self.listening or self.d.listen==false then return end
	self.listening=game:GetService("UserInputService").InputBegan:Connect(function(input)
		local a=self.active
		if not a then return end
		local kind=input.UserInputType
		if kind~=Enum.UserInputType.MouseButton1 and kind~=Enum.UserInputType.Touch then return end
		local gui=self.d.playerGui and self.d.playerGui()
		if not gui then return end
		local ok,hits=pcall(gui.GetGuiObjectsAtPosition,gui,input.Position.X,input.Position.Y)
		if not ok then return end
		local deck=self.d.deck()
		local host=deck and deck.hudRoot
		for _,hit in ipairs(hits)do
			if self.skipPill and(hit==self.skipPill or hit:IsDescendantOf(self.skipPill))then self:act("skip");return end
		end
		for _,hit in ipairs(hits)do
			if host and hit:IsDescendantOf(host)then
				-- on the level step a tap on the level card is the stepper's own (its hit button steps the level on release;
				-- step() sees the pick and ends the tour with `level`); any other card goes on
				local card=hit
				while card.Parent and card.Parent~=host do card=card.Parent end
				if a.step==Tour.LevelStep and card.Name==Tour.Steps[Tour.LevelStep].card then return end
				self:act("next")
				return
			end
		end
	end)
end
function Tour:pill(parent,name,text,z)
	local p=self[name]
	if not(p and p.Parent==parent)then
		if p then p:Destroy()end
		p=Instance.new("TextLabel")
		p.Name="EggDropTour"..name;p.Active=false;p.Selectable=false;p.BackgroundColor3=Color3.fromHex("#FFFFFF");p.BorderSizePixel=0
		p.TextColor3=Color3.fromHex("#1B2A4A");p.Font=Enum.Font.BuilderSansBold;p.TextSize=14;p.AutomaticSize=Enum.AutomaticSize.X
		p.Size=UDim2.fromOffset(0,26);p.ZIndex=z or 996
		local c=Instance.new("UICorner");c.CornerRadius=UDim.new(.5,0);c.Parent=p
		local s=Instance.new("UIStroke");s.Color=Color3.fromHex("#1B2A4A");s.Thickness=1.5;s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;s.Parent=p
		local pad=Instance.new("UIPadding");pad.PaddingLeft=UDim.new(0,10);pad.PaddingRight=UDim.new(0,10);pad.Parent=p
		p.Parent=parent
		self[name]=p
	end
	p.Text=text
	return p
end
function Tour:clearPills()
	for _,name in ipairs({"skipPill","subPill"})do
		if self[name]then self[name]:Destroy();self[name]=nil end
	end
end
local function layerOf(node)
	while node and not node:IsA("LayerCollector")do node=node.Parent end
	return node
end
-- Place a pill under (or over) a card in its ScreenGui's coordinates.
local function placeUnder(p,card,gui,above)
	local origin=gui.AbsolutePosition
	local at,size=card.AbsolutePosition-origin,card.AbsoluteSize
	local w=math.max(48,p.AbsoluteSize.X)
	local x=math.clamp(at.X+size.X/2-w/2,4,math.max(4,gui.AbsoluteSize.X-w-4))
	local y=if above then at.Y-30 else at.Y+size.Y+8
	y=math.clamp(y,4,math.max(4,gui.AbsoluteSize.Y-30))
	p.Position=UDim2.fromOffset(x,y)
end
function Tour:act(action)
	local a=self.active
	if not a then return end
	local nextStep=Tour.after(a.mode,a.step,action)
	if nextStep then
		a.step=nextStep
		a.since=os.clock()
		return
	end
	self:finish(action)
end
function Tour:finish(how)
	local a=self.active
	if not a then return end
	self.active=nil
	for _,id in ipairs(Tour.saves(a.mode,a.stepped))do pcall(self.d.latch,id)end
	if self.d.event then pcall(self.d.event,"TourDone")end
	self:hide()
end
function Tour:hide()
	if self.d.pointer then self.d.pointer:hide()end
	self:clearPills()
	self:dim(nil)
	self:bind(false)
end
function Tour:touring()return self.active~=nil end
function Tour:step(now,dt)
	local d=self.d
	local f=d.facts()
	local ctx=d.ctx()
	local a=self.active
	if a then
		if(ctx.drops or 0)>0 then self:finish("drop");a=nil
		elseif not Tour.opener(ctx)or f.on~=true or f.graduated==true then
			-- the deck left (or a layer came up) before a drop: nothing saved, the tour waits for the next opener
			self.active=nil;self:hide();a=nil
		end
	end
	if not a then
		local mode=Tour.mode(f,ctx)
		if mode then
			a={mode=mode,step=Tour.first(mode),since=now,picked=d.picked and d.picked()}
			self.active=a
			if d.event then pcall(d.event,"TourShown")end
		end
	end
	if a then
		-- the level stepped while its step shows: `level` is learned (saved when the tour ends)
		local picked=d.picked and d.picked()
		if picked~=a.picked then
			a.picked=picked
			-- tried it: learned, and the tour is over (they are playing)
			if a.step==Tour.LevelStep then a.stepped=true;self:finish("stepped");a=nil end
		end
	end
	if a then
		local s=Tour.Steps[a.step]
		local deck=d.deck()
		local card=cardOf(deck,s.card)
		if not card then
			-- this layout has no such card now: on to the next step (never stuck on an invisible one)
			if d.pointer then d.pointer:hide()end
			self:clearPills()
			a.missing=a.missing or now
			if now-a.missing>=Tour.MissingGrace then a.missing=nil;self:act("next")end
		else
			a.missing=nil
			self:listen();self:bind(true)
			local count=d.text("teach.count",{n=a.step,of=#Tour.Steps})
			local line=Tour.label(d.text(s.words),a.mode,a.step,count)
			if d.pointer then d.pointer:show(card,line,Tour.Glyphs);d.pointer:step(dt or 0)end
			local lit={[s.card]=true}
			if s.sub then lit[s.sub]=true end
			self:dim(lit)
			local gui=layerOf(card)
			if gui then
				-- Skip under the label's side (under the card); the sub pill over Win pays
				local skip=self:pill(gui,"skipPill",d.text("coach.skip"),997)
				placeUnder(skip,card,gui,false)
				local subCard=s.sub and cardOf(deck,s.sub)
				if subCard then
					local sub=self:pill(gui,"subPill",d.text(s.subWords),996)
					placeUnder(sub,subCard,gui,false)
				elseif self.subPill then self.subPill:Destroy();self.subPill=nil end
			end
		end
	end
	-- the tips ----------------------------------------------------------------------------------------------------
	local tip=Tour.tip(f,{mode=ctx.mode,phase=ctx.phase,over=ctx.over,drops=ctx.drops,chain=ctx.chain,goalsDone=ctx.goalsDone,
		now=now,lastTip=self.lastTip,railEmpty=d.railEmpty and d.railEmpty(),touring=self.active~=nil})
	if tip and d.rail and d.rail(tip,d.text(Tour.TipWords[tip]))==true then
		self.lastTip=now
		pcall(d.latch,tip)
	end
end
function Tour:destroy()
	self.active=nil
	self:hide()
	if self.listening then self.listening:Disconnect();self.listening=nil end
end
return Tour
