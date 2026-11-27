-- The gift chain on the client (ONBOARDING-FUN-PASS section 2, Onboard "gifts"; GIFT-CHAIN-PLAN). After the Bear, the
-- pet has one idea at a time and every step ends in a hatch:
--   paint   1.5 s after the tuck: "A gift for you!" the free Paint Egg, cranked at the machine, the Bear painted
--   pull    Stars first cover an egg: "You can hatch one!" (their own Stars, their own egg; done on a paid pull)
--   toy     the free Toy Egg (two rounds after the Bear, or a later day): the Bear plays with it
--   park    "Let's go play!" to the Pet Park, "Throw it!" there, then "{pet} learned Fetch!" on the first fetch
--   dash    a later session, the park visited: "Race time!"; the first finish makes the Snack gift ready
--   snack   the free Snack Egg ("A snack for the racer!")
--   nest    the nest egg ready: "It's hatching!" (first on a return); it hatches by the built path
--   unseen  a gift given whose card was never closed (a rejoin): it comes out of the machine again, then its card
-- Rules (the brief): one at a time; never beside another prompt (the gate, the need bubble); after step 1, 3 minutes
-- clear of the last reveal and at most two a session; no timers, nothing expires. Ignored: one nudge (a hop, "For
-- you!"), then it parks. "x": parks at once, not asked again this session. A parked gift (and any gift ready that is not
-- the bubble's) shows as the chip over the pet, the ribbon on the machine and the Things to do row; a tap on any of the
-- three starts it. Veterans: no bubbles, only the chip, ribbon and row. Off (no `gifts` in the snapshot): nothing.
-- The server decides what is ready (public.gifts); this only presents and asks. Pure rules first (spec-checked), then
-- the controller; init.client gives it the game as deps.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Coach=require(Shared:WaitForChild("CoachMarks"))
local Toys=require(Shared:WaitForChild("ToyCatalog"))
local LookEgg=require(Shared:WaitForChild("LookEggCatalog"))
local StatEgg=require(Shared:WaitForChild("StatEggCatalog"))
local Chain={};Chain.__index=Chain
Chain.PaintDelay=1.5 -- s after the Paint gift turns ready (the tuck toast)
Chain.NudgeAfter=8   -- s a bubble waits untapped before its one nudge
Chain.ParkAfter=8    -- s after the nudge: parked
Chain.Gap=180        -- s clear of the last reveal before the next invite (after step 1)
Chain.PerSession=2   -- invites a session after step 1
Chain.Near=12        -- studs from the machine: the bubble says "Turn it!"
Chain.Free=1         -- s free of every other prompt before a bubble shows
Chain.Stuck=table.freeze({cranking=45,reveal=180}) -- s: a phase that never ended lets the garden go
Chain.LeadPark=20    -- s of a gift's lead with no step closer to the machine: parked (code review: the guide resumes)
Chain.Progress=2     -- studs closer that count as heading there
Chain.Away=15        -- studs further than the closest point so far: walking away, parked
-- Pure (code review): ask again after this reply? A giftEgg ask: a busy save, a throttle or a second ask while one
-- runs, a few times. A giftSeen: also Pending and RevealPending (another write or reveal first), so the card never
-- replays on the next join for want of a retry.
Chain.AskTries=4
Chain.SeenTries=6
function Chain.retryAsk(status,reason,tries)
	if status=="Saved"or(tries or 0)>=Chain.AskTries then return false end
	return status=="Retrying"or reason=="Busy"or reason=="Throttled"
end
function Chain.retrySeen(status,reason,tries)
	if status=="Saved"or(tries or 0)>=Chain.SeenTries then return false end
	return status=="Retrying"or reason=="Busy"or reason=="Throttled"or reason=="Pending"or reason=="RevealPending"or reason=="Retrying"
end
Chain.Gifts=table.freeze({paint=true,toy=true,snack=true})
Chain.Steps=table.freeze({
	paint=table.freeze({head="onbGift.paint",sub="onbGift.paintSub",target="Eggs",gift="paint"}),
	toy=table.freeze({head="onbGift.toy",sub="onbGift.toySub",target="Eggs",gift="toy"}),
	snack=table.freeze({head="onbGift.snack",sub="onbGift.snackSub",target="Eggs",gift="snack"}),
	unseen=table.freeze({head="onbGift.waiting",sub="onbGift.waitingSub",target="Eggs"}),
	pull=table.freeze({head="onbGift.pull",sub="onbGift.pullSub",target="Eggs"}),
	park=table.freeze({head="onbGift.park",sub="onbGift.parkSub",target="Park"}),
	dash=table.freeze({head="onbGift.dash",sub="onbGift.dashSub",target="Dash"}),
	nest=table.freeze({head="onbGift.nest",sub="onbGift.nestSub",target="Nest"}),
})
-- Exempt from the gap and the session count: the first gift, and a gift already given.
Chain.Exempt=table.freeze({paint=true,unseen=true})

-- ── Pure rules ───────────────────────────────────────────────────────────────────────────────────────────────────────
function Chain.cheapest()return math.min(LookEgg.Price,Toys.Cost,StatEgg.Price)end
-- The facts from the owner snapshot. live = {returned (Paint was already given when this session began), mask}.
function Chain.facts(state,live)
	state=if type(state)=="table"then state else {}
	live=live or {}
	local g=if type(state.gifts)=="table"then state.gifts else nil
	local stats=if type(state.stats)=="table"then state.stats else {}
	local mask=Coach.merge(state.coachMask,live.mask)
	local dash=if type(state.dash)=="table"then state.dash else nil
	local raced=false
	for _,n in pairs(dash and type(dash.ribbons)=="table"and dash.ribbons or {})do if type(n)=="number"and n>0 then raced=true end end
	local playDate=if type(state.playDate)=="table"then state.playDate else {}
	local fetched=(tonumber(stats.fetches)or 0)>0
	return{
		on=g~=nil and g.owed==true,
		ready=g and g.ready or nil,
		unseen=g and type(g.unseen)=="table"and g.unseen or nil,
		granted=g and type(g.granted)=="table"and g.granted or {},
		stars=tonumber(state.nectar)or 0,
		paid=(tonumber(stats.starsSpent)or 0)>0,
		fetched=fetched,
		parkVisited=fetched or Coach.has(mask,"park")or Coach.has(mask,"needPark")or(tonumber(playDate.count)or 0)>0,
		toysLeft=#Toys.remaining(state.toyUnlocks),
		nestReady=type(state.nest)=="table"and state.nest.ready==true,
		dashOn=dash~=nil,raced=raced,
		veteran=Coach.veteran(tonumber(state.totalWins)or 0),
		returned=live.returned==true,
		parkOn=live.park~=false,
	}
end
-- The step the chain is on now, or nil. A gift already given and unseen first; the nest first on a return.
function Chain.next(f)
	if not f.on then return nil end
	if f.unseen then return "unseen"end
	if f.nestReady and f.returned then return "nest"end
	if f.ready=="paint"then return "paint"end
	if not f.granted.paint then return nil end
	if not f.paid and f.stars>=Chain.cheapest()then return "pull"end
	if f.ready=="toy"then return "toy"end
	if f.ready=="snack"then return "snack"end
	local toyDone=f.granted.toy==true or f.toysLeft==0
	if toyDone and not f.fetched and f.parkOn then return "park"end
	if f.fetched and f.returned and f.dashOn and not f.raced then return "dash"end
	if f.nestReady then return "nest"end
	return nil
end
-- The gift kind a step cranks (paint, toy, snack), or for `unseen` the unseen record's kind; nil for an invite.
function Chain.giftOf(step,f)
	if step=="unseen"then return f.unseen and f.unseen.kind or nil end
	local s=Chain.Steps[step]
	return s and s.gift or nil
end
-- May the bubble for `step` show now? session = {closed = {[step] = true}, count, lastReveal}.
function Chain.may(session,step,now,f)
	if not step or session.closed[step]then return false end
	if f and f.veteran then return false end
	if Chain.Exempt[step]then return true end
	if(session.count or 0)>=Chain.PerSession then return false end
	return now-(session.lastReveal or -math.huge)>=Chain.Gap
end
-- The gift that parks as the chip, ribbon and row: ready (or unseen) and not the one the bubble is showing.
function Chain.parked(f,active)
	if not f.on then return nil end
	local kind=if f.unseen then f.unseen.kind elseif Chain.Gifts[f.ready or ""]then f.ready else nil
	if not kind then return nil end
	if active and active.gift==kind then return nil end
	return kind
end

-- ── The controller ───────────────────────────────────────────────────────────────────────────────────────────────────
-- deps: state(), clock(), gate() -> nil when free (the garden's prompt gate, the gift excluded), busy() -> true while
--   another prompt is up (the need bubble, a reveal), bubble = {set(visible, head, sub), hop(), chip(on)}, ribbon(on),
--   row(kind or nil), near() -> at the machine, lead(target), crank(kind, done(status, reason)) (paint/toy: the giftEgg
--   ask; snack: the Snack gift buy; both through the machine), replay(record) (an unseen gift out of the machine again),
--   inPark(), fetchCard(), throwTip(), event(name), mask(), park() -> false when this world has no Pet Park
function Chain.new(deps)
	local self=setmetatable({d=deps,session={closed={},count=0},active=nil,lastFree=nil,returned=nil,fetchedBefore=nil},Chain)
	return self
end
function Chain:read()
	local state=self.d.state()
	if self.returned==nil and type(state)=="table"and type(state.gifts)=="table"then
		self.returned=state.gifts.granted and state.gifts.granted.paint==true or false
	end
	return Chain.facts(state,{returned=self.returned,mask=self.d.mask and self.d.mask(),park=self.d.park and self.d.park()})
end
-- True while the chain holds the garden's prompts back (BearNeeds and the tips read it through the gate).
function Chain:holds()
	local a=self.active
	return a~=nil and a.phase~="parked"
end
function Chain:event(name)if self.d.event then pcall(self.d.event,name)end end
function Chain:hide()self.d.bubble.set(false)end
-- Park the active step: its bubble goes; a gift shows as the chip, ribbon and row (step()).
function Chain:park(why)
	local a=self.active
	if not a then return end
	self.session.closed[a.step]=true
	self.active=nil
	self:hide()
	self:event("GiftParked")
	return why
end
-- "x" on the bubble.
function Chain:close()if self.active then self:park("x")end end
-- A tap on the bubble: a gift at the machine cranks; otherwise the lead starts (the bubble stays as the prompt).
function Chain:tap()
	local a=self.active
	if not a or a.phase=="cranking"or a.phase=="reveal"then return false end
	if a.gift and self.d.near()then return self:crank()end
	a.phase="leading";a.tapped=true;a.at=self.d.clock()
	self.d.lead(Chain.Steps[a.step].target)
	if not a.gift then
		-- an invite: the lead is the step; it closes for this session (done from the save when it happens)
		self.session.closed[a.step]=true
		self.active=nil;self:hide()
	end
	return true
end
-- A tap on the chip, the ribbon or the Things row: start the parked gift (a closed step may restart from these).
function Chain:resume()
	local f=self:read()
	local kind=Chain.parked(f,self.active)
	if not kind then return false end
	local step=if f.unseen then "unseen"else kind
	self.session.closed[step]=nil
	self.active={step=step,gift=kind,phase="leading",at=self.d.clock(),tapped=true}
	if self.d.near()then return self:crank()end
	self.d.lead("Eggs")
	return true
end
function Chain:crank()
	local a=self.active
	if not a or not a.gift then return false end
	a.phase="cranking";a.at=self.d.clock()
	self:hide()
	self:event("GiftCranked")
	local f=self:read()
	local done=function(status,reason)
		if self.active~=a then return end
		if status=="Saved"then
			a.phase="reveal";a.at=self.d.clock()
		else
			-- refused: back to parked (the chip, ribbon and row stay while the gift is ready; no bubble again this session)
			self.session.closed[a.step]=true
			self.active=nil
			if self.d.refused then pcall(self.d.refused,reason)end
		end
	end
	if a.step=="unseen"and f.unseen then
		a.phase="reveal"
		self.d.replay(f.unseen)
	else
		self.d.crank(a.gift,done)
	end
	return true
end
-- The gift card closed (GiftReveal): the step is done; the gap starts now.
function Chain:revealed()
	self.session.lastReveal=self.d.clock()
	if self.active and(self.active.phase=="reveal"or self.active.phase=="cranking")then self.active=nil end
	self:event("GiftDone")
end
function Chain:step(now)
	local f=self:read()
	-- The first fetch this session (the park's "Throw it!"): "{pet} learned Fetch!", once.
	if self.fetchedBefore==nil then self.fetchedBefore=f.fetched
	elseif f.fetched and not self.fetchedBefore then
		self.fetchedBefore=true
		if f.on and self.d.fetchCard then pcall(self.d.fetchCard)end
	end
	if not f.on then
		if self.active then self.active=nil;self:hide()end
		self.d.bubble.chip(false);self.d.ribbon(false);self.d.row(nil)
		return
	end
	local a=self.active
	-- A phase that never ended (no answer, a card that never closed): never hold the garden for good.
	if a and Chain.Stuck[a.phase]and now-a.at>=Chain.Stuck[a.phase]then self.active=nil;self:hide();a=nil end
	-- The step's own facts changed under it (given elsewhere, done unprompted): it closes.
	if a and a.phase~="cranking"and a.phase~="reveal"then
		local still=Chain.next(f)==a.step or(a.tapped and a.gift~=nil and Chain.parked(f,nil)==a.gift)
		if not still then self.active=nil;self:hide();a=nil end
	end
	if a and(a.phase=="invited"or a.phase=="nudged")then
		if self.d.gate()~=nil or self.d.busy()then self.d.bubble.set(false)
		else
			local s=Chain.Steps[a.step]
			local near=a.gift~=nil and self.d.near()
			self.d.bubble.set(true,if near then "onbGift.turn"else s.head,if near then "onbGift.turnSub"else s.sub)
		end
		if a.phase=="invited"and now-a.at>=Chain.NudgeAfter then a.phase="nudged";a.at=now;self.d.bubble.hop()
		elseif a.phase=="nudged"and now-a.at>=Chain.ParkAfter then self:park("ignored");a=nil end
	elseif a and a.phase=="leading"and a.gift then
		-- at the machine: the bubble says Turn it! (a tap cranks). Code review: a lead never holds the Bear's prompts for
		-- long. Standing at the machine untapped parks like an ignored bubble; away from it, LeadPark s with no step
		-- closer (Progress studs), or walking Away studs off from the closest point, parks it (the guide resumes).
		if self.d.near()then
			a.nearAt=a.nearAt or now
			if self.d.gate()==nil then self.d.bubble.set(true,"onbGift.turn","onbGift.turnSub")else self.d.bubble.set(false)end
			if now-a.nearAt>=Chain.NudgeAfter+Chain.ParkAfter then self:park("ignored");a=nil end
		else
			a.nearAt=nil
			self.d.bubble.set(false)
			local distance=self.d.distance and self.d.distance()or nil
			if type(distance)=="number"then
				if a.best==nil or distance<=a.best-Chain.Progress then a.best,a.bestAt=distance,now end
				if distance>=a.best+Chain.Away then self:park("away");a=nil end
			end
			if a and now-(a.bestAt or a.at)>=Chain.LeadPark then self:park("away");a=nil end
		end
	end
	-- The park's one tip there.
	if f.on and not f.fetched and self.d.inPark and self.d.inPark()and not self.throwShown and self.session.parkLed then
		self.throwShown=true
		if self.d.throwTip then pcall(self.d.throwTip)end
	end
	-- A new invite, one at a time.
	if not self.active then
		local step=Chain.next(f)
		local free=self.d.gate()==nil and not self.d.busy()
		if free then self.lastFree=self.lastFree or now else self.lastFree=nil end
		local wait=if step=="paint"then Chain.PaintDelay else Chain.Free
		if step and step~=self.waitingFor then self.waitingFor,self.waitingSince=step,now end
		if step and free and Chain.may(self.session,step,now,f)and now-(self.waitingSince or now)>=wait and now-(self.lastFree or now)>=math.min(wait,Chain.Free)then
			if not Chain.Exempt[step]then self.session.count+=1 end
			if step=="park"then self.session.parkLed=true end
			self.active={step=step,gift=Chain.giftOf(step,f),phase="invited",at=now}
			self:event("GiftShown")
		end
	end
	local parked=Chain.parked(f,self.active)
	self.d.bubble.chip(parked~=nil)
	self.d.ribbon(parked~=nil)
	self.d.row(parked)
end
return Chain
