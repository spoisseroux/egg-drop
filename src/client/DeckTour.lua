-- The deck tour (Onboard "teach"). Beta 44 redesign: artifacts/qa-2026-11-28-beta44/ONBOARD-SIMPLIFY-BRIEF.md section 2 and
-- ARCH-REVIEW-SIMPLIFY 2 to 4; Spencer's beta 44 notes 6, 8, 9 and 10 ("dont make the player finish a whole game then,
-- just go thru the onboarding things there and close the pocket deck automatically and continue to the next thing").
--   When      `deckTour` not latched, no field round played, a field round on the deck (not Welcome), nothing dropped,
--             no layer up, and the deck READY: a boot finished (or skipped) since this deck opened and the boot's screen
--             gone, then ReadyAfter s (a deck with no boot at all: NoBoot s after it opened). Nothing is drawn before.
--   Holds     while the tour runs (and until the deck has closed after it) every drop and item is held: deck.tourHold,
--             read where the drop and the item are sent (init.client). So a tap means Next everywhere.
--   Steps     six, one line each, on the deck's own cards, the rest dimmed (DeckScreen:teachDim); a step whose card this
--             layout does not have is left out when the tour starts (the "1/6" count is the real number):
--               1 Goals "Do these to win!"   2 Balls left "Win before they run out!"
--               3 Win pays, Difficulty lit with it "A win pays Stars ★" (+ "Harder pays more" on Difficulty, unguided)
--               4 Score "Your high score. Goals win Stars!"   5 Chain "Merge fast for a chain!"
--               6 the quest clipboard (or Daily quests) "Tap here for quests ★"
--   Next      a tap anywhere, Enter, Space, gamepad A or R1. Skip: the Skip pill, B or L1. No timer: untouched, it stays.
--   Ends      past step 6: latches deckTour, level, quests; the pointer goes and CloseAfter s later the deck closes by
--             itself (deps.close, the normal Back path, retried until the board is in the garden). Skip: the same latches,
--             the deck stays open with the round live (they chose to play); the hold lets go SkipGrace s later.
--   Left      the deck left before the end: nothing saved, the tour waits for the next ready opener.
-- The dealt round never gets a drop, so leaving it is the "fresh board" case (no award, no round counted:
-- TourRound.spec). Graduated (`done`) or a save never owed the chain: nothing. Pure rules first (DeckTour.spec).
local Tour={};Tour.__index=Tour
Tour.Steps=table.freeze({
	table.freeze({id="goals",cards=table.freeze({"Goals"}),words="teach.tour1"}),
	table.freeze({id="balls",cards=table.freeze({"EggsLeft"}),words="teach.tour2"}),
	table.freeze({id="pays",cards=table.freeze({"WinPays"}),also="Difficulty",words="teach.tourPays",sub="Difficulty",subWords="teach.tourHarder"}),
	table.freeze({id="score",cards=table.freeze({"Score"}),words="teach.tourScore"}),
	table.freeze({id="chain",cards=table.freeze({"Chain"}),words="teach.tourChain"}),
	table.freeze({id="quests",cards=table.freeze({"QuestHandle","DailyQuests"}),words="teach.tourQuests"}),
})
-- Keys by name (KeyCode names), bound at High+900 only while a step shows (they sink: no drop, no item, no Back).
Tour.KeyNames=table.freeze({next=table.freeze({"Return","KeypadEnter","Space","ButtonA","ButtonR1"}),skip=table.freeze({"ButtonB","ButtonL1"})})
-- Never the tour's: aiming, the menu, the items' own keyboard key, leaving.
Tour.Forbidden=table.freeze({"Left","Right","Up","Down","A","D","M","B","Backspace","Escape","ButtonX","ButtonY","ButtonSelect","ButtonStart","DPadLeft","DPadRight"})
Tour.Glyphs=table.freeze({key="ENTER",glyph="A"})
Tour.Saves=table.freeze({"deckTour","level","quests"})
Tour.ReadyAfter=.4   -- s after the boot is done before the first ring
Tour.NoBoot=4        -- s after the deck opened with no boot seen: ready anyway (never stuck waiting)
Tour.CloseAfter=.5   -- s after the last Next before the deck closes itself
Tour.CloseRetry=.25  -- s between two Back asks while the garden switch is busy
Tour.CloseGiveUp=10  -- s of asking before the tour lets go of the hold (the player can still leave by hand)
Tour.SkipGrace=.35   -- s the hold stays after Skip (the tap's own release never drops)
Tour.MissingGrace=1  -- s a step's card may be missing (the HUD rebuilding) before the tour moves past it
-- The Skip pill sinks its tap (a TextButton, Active); the Harder pays more line lets every tap through.
Tour.Pills=table.freeze({skipPill=table.freeze({class="TextButton",active=true}),subPill=table.freeze({class="TextLabel",active=false})})

-- ── Pure ────────────────────────────────────────────────────────────────────────────────────────────────────────────
-- The round can carry the tour now: a field round on the deck, nothing dropped, not over, no deck layer up.
-- ctx: {mode, phase, guided, drops, over, overlay, ready}
function Tour.opener(ctx)
	ctx=ctx or {}
	return ctx.mode=="Board"and ctx.phase~=nil and ctx.phase~="Welcome"and(ctx.drops or 0)==0
		and ctx.over~=true and ctx.overlay~=true
end
-- Should the tour start on this opener? f: TeachLessons facts (on, graduated, latched, rounds); ctx.ready: the deck gate.
function Tour.wants(f,ctx)
	if type(f)~="table"or f.on~=true or f.graduated==true then return false end
	if(f.rounds or 0)>=1 or(f.latched or {}).deckTour then return false end
	return Tour.opener(ctx)and(ctx or {}).ready==true
end
-- The ready gate (ARCH-REVIEW-SIMPLIFY 3). g: {openedAt (the deck became visible), mark (boot finishes then), finishes,
-- playing, showing (the boot's screen still up, its fade)}. `boot.playing == false` alone is also true before a boot starts.
function Tour.bootDone(g,now)
	if type(g)~="table"or g.openedAt==nil then return false end
	if g.playing==true or g.showing==true then return false end
	if(g.finishes or 0)>(g.mark or 0)then return true end
	return now-g.openedAt>=Tour.NoBoot
end
-- The steps this layout has, in order (indices into Tour.Steps). has(name) -> the card is there.
function Tour.plan(has)
	local out={}
	for index,s in ipairs(Tour.Steps)do
		for _,name in ipairs(s.cards)do
			if has(name)then table.insert(out,index);break end
		end
	end
	return out
end
-- The position after `at` (1-based into the plan) for an action: the next position, or nil when the tour is over.
function Tour.after(at,count,action)
	if action~="next"then return nil end
	if at<count then return at+1 end
	return nil
end
-- "Do these to win!  1/6"
function Tour.label(line,count)
	if type(count)=="string"and count~=""then return line.."  "..count end
	return line
end
-- The tour's keys never take the aim, the menu or leaving (ARCH-REVIEW-SIMPLIFY 2: it does take Space, A and B now:
-- drops are held while it runs).
function Tour.keysSafe()
	for _,list in pairs(Tour.KeyNames)do
		for _,name in ipairs(list)do if table.find(Tour.Forbidden,name)then return false end end
	end
	return true
end
-- What a key does in the tour: "next", "skip" or nil.
function Tour.keyAction(name)
	if table.find(Tour.KeyNames.next,name)then return "next"end
	if table.find(Tour.KeyNames.skip,name)then return "skip"end
	return nil
end
-- Is the Harder pays more line on this step? Only on step 3, only on an unguided round (a guided one has no level).
function Tour.subOn(step,guided)return step~=nil and step.sub~=nil and guided~=true end

-- ── The controller ─────────────────────────────────────────────────────────────────────────────────────────────────
-- deps: facts() (TeachLessons facts), ctx() (the round: mode, phase, guided, drops, over, overlay), deck() (DeckScreen:
--   hudRoot, teachDim, visible, boot, bootHost), latch(id), text(key, vars), pointer (a TeachPointer of its own),
--   hold(on) (deck.tourHold), close() (the deck's Back path; false while the garden switch is busy), event(name),
--   playerGui(); listen = false (specs) binds no keys or taps
function Tour.new(deps)
	return setmetatable({d=deps,active=nil,gate=nil,readyAt=nil,closing=nil,releaseAt=nil},Tour)
end
local function cardOf(deck,name)
	local host=deck and deck.hudRoot
	local c=host and host:FindFirstChild(name)
	return if c and c:IsA("GuiObject")and c.Visible then c else nil
end
local function stepCard(deck,s)
	for _,name in ipairs(s.cards)do
		local c=cardOf(deck,name)
		if c then return c,name end
	end
	return nil
end
function Tour:dim(lit)
	local deck=self.d.deck()
	if deck and deck.teachDim then pcall(deck.teachDim,deck,lit)end
end
function Tour:hold(on)
	self.holding=on==true
	if self.d.hold then pcall(self.d.hold,on==true)end
end
function Tour:bind(on)
	self.keysOn=on==true -- what the tour wants (specs read it); the binding below follows it
	if self.d.listen==false then return end -- specs: no engine input
	local okCas,CAS=pcall(function()return game:GetService("ContextActionService")end)
	if not okCas then return end
	if on and not self.bound then
		self.bound=true
		local keys={}
		for _,list in pairs(Tour.KeyNames)do for _,name in ipairs(list)do table.insert(keys,Enum.KeyCode[name])end end
		pcall(CAS.BindActionAtPriority,CAS,"EggDropDeckTour",function(_,state,input)
			if not self.active then return Enum.ContextActionResult.Pass end
			if state==Enum.UserInputState.Begin then self:act(Tour.keyAction(input.KeyCode.Name)or "next")end
			return Enum.ContextActionResult.Sink
		end,false,Enum.ContextActionPriority.High.Value+900,table.unpack(keys))
	elseif not on and self.bound then
		self.bound=false
		pcall(CAS.UnbindAction,CAS,"EggDropDeckTour")
	end
end
-- A tap anywhere (ARCH-REVIEW-SIMPLIFY 2: the whole deck, the board's well included) is Next; the Skip pill is Skip.
function Tour:listen()
	if self.listening or self.d.listen==false then return end
	self.listening=game:GetService("UserInputService").InputBegan:Connect(function(input)
		if not self.active or not self.keysOn then return end
		local kind=input.UserInputType
		if kind~=Enum.UserInputType.MouseButton1 and kind~=Enum.UserInputType.Touch then return end
		local gui=self.d.playerGui and self.d.playerGui()
		if gui and self.skipPill then
			local ok,hits=pcall(gui.GetGuiObjectsAtPosition,gui,input.Position.X,input.Position.Y)
			if ok then
				for _,hit in ipairs(hits)do
					if hit==self.skipPill or hit:IsDescendantOf(self.skipPill)then self:act("skip");return end
				end
			end
		end
		self:act("next")
	end)
end
function Tour:pill(parent,name,text,z)
	local p=self[name]
	if not(p and p.Parent==parent)then
		if p then p:Destroy()end
		local kind=Tour.Pills[name]or Tour.Pills.subPill
		p=Instance.new(kind.class)
		p.Name="EggDropTour"..name;p.Active=kind.active;p.Selectable=false;
		if p:IsA("GuiButton")then p.AutoButtonColor=false;p.Modal=false end
		p.BackgroundColor3=Color3.fromHex("#FFFFFF");p.BorderSizePixel=0
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
-- Place a pill under a card in its ScreenGui's coordinates.
local function placeUnder(p,card,gui,above)
	local origin=gui.AbsolutePosition
	local at,size=card.AbsolutePosition-origin,card.AbsoluteSize
	local w=math.max(48,p.AbsoluteSize.X)
	local x=math.clamp(at.X+size.X/2-w/2,4,math.max(4,gui.AbsoluteSize.X-w-4))
	local y=math.clamp(if above then at.Y-30 else at.Y+size.Y+8,4,math.max(4,gui.AbsoluteSize.Y-30))
	p.Position=UDim2.fromOffset(x,y)
end
function Tour:act(action)
	local a=self.active
	if not a or action==nil then return end
	local nextAt=Tour.after(a.at,#a.plan,action)
	if nextAt then
		a.at=nextAt
		a.missing=nil
		return
	end
	self:finish(if action=="skip"then "skip"else "done")
end
function Tour:finish(how)
	local a=self.active
	if not a then return end
	self.active=nil
	for _,id in ipairs(Tour.Saves)do pcall(self.d.latch,id)end
	if self.d.event then pcall(self.d.event,if how=="skip"then "TourSkipped"else "TourDone")end
	self:hide()
	local now=self.now or 0
	if how=="skip"then
		-- they chose to play: the deck stays open, the round live; the hold lets go once the tap is over
		self.releaseAt=now+Tour.SkipGrace
	else
		-- the deck closes by itself; drops stay held until it has
		self.closing={at=now+Tour.CloseAfter,from=now,lastAsk=nil}
	end
end
function Tour:hide()
	if self.d.pointer then self.d.pointer:hide()end
	self:clearPills()
	self:dim(nil)
	self:bind(false)
end
function Tour:touring()return self.active~=nil end
-- The tour's own work is still on (a step, or the deck closing after it): the all-set card waits.
function Tour:busy()return self.active~=nil or self.closing~=nil end
-- The overlay the tour's pointer draws in: one ScreenGui beside the card's own, same insets, DisplayOrder 11 (over the
-- play well's gui at 10; the tour hides whenever an overlay or modal is up).
Tour.OverlayOrder=11
function Tour:overlayFor(card)
	local host=card
	while host and not host:IsA("LayerCollector")do host=host.Parent end
	if not host or not host:IsA("ScreenGui")then return nil end
	local gui=self.overlay
	if not gui or gui.Parent~=host.Parent then
		if gui then gui:Destroy()end
		gui=Instance.new("ScreenGui")
		gui.Name="EggDropTourPointer";gui.ResetOnSpawn=false;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
		gui.DisplayOrder=Tour.OverlayOrder;gui.IgnoreGuiInset=host.IgnoreGuiInset;gui.ScreenInsets=host.ScreenInsets
		gui.Parent=host.Parent
		self.overlay=gui
	end
	return gui
end
-- The deck's boot as the ready gate reads it.
function Tour:bootFacts(deck)
	local boot=deck and deck.boot
	local host=deck and deck.bootHost
	return{playing=boot~=nil and boot.playing==true,finishes=boot and boot.finishes or 0,showing=host~=nil and host.Visible==true}
end
-- The ready gate, every frame: the deck's opening, its boot, then ReadyAfter s. -> ready now.
function Tour:stepGate(now,ctx)
	local deck=self.d.deck()
	local open=ctx.mode=="Board"and deck~=nil and deck.visible~=false
	if not open then self.gate=nil;self.readyAt=nil;return false end
	local b=self:bootFacts(deck)
	if not self.gate then self.gate={openedAt=now,mark=b.finishes}end
	local g=self.gate
	g.finishes,g.playing,g.showing=b.finishes,b.playing,b.showing
	if not Tour.bootDone(g,now)then self.readyAt=nil;return false end
	self.readyAt=self.readyAt or now
	return now-self.readyAt>=Tour.ReadyAfter
end
function Tour:step(now,dt)
	local d=self.d
	self.now=now
	local f=d.facts()
	local ctx=d.ctx()
	ctx.ready=self:stepGate(now,ctx)
	-- after the last Next: close the deck (the normal Back path), asking again while the garden switch is busy
	local closing=self.closing
	if closing then
		if ctx.mode~="Board"then
			self.closing=nil;self:hold(false)
			if d.event then pcall(d.event,"TourClosed")end
		elseif now>=closing.at and(closing.lastAsk==nil or now-closing.lastAsk>=Tour.CloseRetry)then
			closing.lastAsk=now
			if d.close then pcall(d.close)end
			if now-closing.from>=Tour.CloseGiveUp then self.closing=nil;self:hold(false)end
		end
	end
	if self.releaseAt and now>=self.releaseAt then self.releaseAt=nil;if not self.active and not self.closing then self:hold(false)end end
	local a=self.active
	if a then
		if f.on~=true or f.graduated==true or ctx.mode~="Board"or(ctx.drops or 0)>0 or ctx.over==true or ctx.phase==nil then
			-- the deck left (or the round changed) before the end: nothing saved, the tour waits for the next opener
			self.active=nil;self:hide();self:hold(false);a=nil
		elseif ctx.overlay==true then
			-- a layer is up (the Pocket menu): the tour waits under it, drawn again when it closes
			if d.pointer then d.pointer:hide()end
			self:clearPills();self:dim(nil);self:bind(false)
			return
		end
	end
	if not a and not self.closing and Tour.wants(f,ctx)then
		local deck=d.deck()
		local plan=Tour.plan(function(name)return cardOf(deck,name)~=nil end)
		if #plan>0 then
			a={plan=plan,at=1,since=now,guided=ctx.guided==true}
			self.active=a
			self.releaseAt=nil
			self:hold(true)
			if d.event then pcall(d.event,"TourShown")end
		end
	end
	if not a then return end
	local s=Tour.Steps[a.plan[a.at]]
	local deck=d.deck()
	local card,name=stepCard(deck,s)
	if not card then
		-- the HUD rebuilding: wait a moment, then on (never stuck on an invisible card); no pointer, no keys meanwhile
		if d.pointer then d.pointer:hide()end
		self:clearPills()
		self:bind(false)
		a.missing=a.missing or now
		if now-a.missing>=Tour.MissingGrace then a.missing=nil;self:act("next")end
		return
	end
	a.missing=nil
	self:listen();self:bind(true)
	local count=d.text("teach.count",{n=a.at,of=#a.plan})
	local line=Tour.label(d.text(s.words),count)
	if d.pointer then
		local opts=table.clone(Tour.Glyphs);opts.gui=self:overlayFor(card);opts.rect=true
		d.pointer:show(card,line,opts);d.pointer:step(dt or 0)
	end
	local lit={[name]=true}
	if s.also then lit[s.also]=true end
	self:dim(lit)
	local gui=card
	while gui and not gui:IsA("LayerCollector")do gui=gui.Parent end
	if gui then
		local skip=self:pill(gui,"skipPill",d.text("coach.skip"),997)
		placeUnder(skip,card,gui)
		local subCard=Tour.subOn(s,a.guided)and cardOf(deck,s.sub)or nil
		if subCard then
			local sub=self:pill(gui,"subPill",d.text(s.subWords),996)
			placeUnder(sub,subCard,gui,true) -- over Difficulty (Win pays, the lit card, sits under it)
		elseif self.subPill then self.subPill:Destroy();self.subPill=nil end
	end
end
function Tour:destroy()
	self.active=nil;self.closing=nil;self.releaseAt=nil
	self:hide()
	self:hold(false)
	if self.listening then self.listening:Disconnect();self.listening=nil end
	if self.overlay then self.overlay:Destroy();self.overlay=nil end
end
return Tour
