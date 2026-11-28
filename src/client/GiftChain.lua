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
-- the bubble's) shows as the ribbon on the machine, its "Free egg!" prompt and the Things to do row; a tap on the ribbon
-- or the row starts it. Veterans: no bubbles, only the ribbon, prompt and row. Off (no `gifts` in the snapshot): nothing.
-- The server decides what is ready (public.gifts); this only presents and asks. Pure rules first (spec-checked), then
-- the controller; init.client gives it the game as deps.
-- Onboarding part 2 (artifacts/qa-2026-11-27-beta40/ONBOARDING-P2-BRIEF.md section 1, ARCH-REVIEW-P2 2; Spencer's beta 40
-- note 5: "lets just click the machine and it says free egg"): the free eggs come out of the normal Hatch eggs screen.
-- The chip over the pet and "Turn it!" are gone. A tap on the bubble, the ribbon or the Things row only leads; at the
-- machine it opens the shop on the free egg (deps.openShop), whose "Hatch free!" sends the same ask (Chain:shopCrank).
-- An unseen gift skips the shop: the egg comes out again, then its card. With Onboard `teach` on, gift steps no longer
-- count toward the session's invites (three a session, 90 s clear of the last reveal) and the Dash invite drops its
-- "later session" condition.
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
Chain.Near=12        -- studs from the machine: the bubble says "Tap the machine!" (a tap opens the shop on the gift)
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
-- Pure (ARCH-REVIEW-P2 2): one key per gift record (its id, else kind and item).
function Chain.recordKey(record)
	if type(record)~="table"then return ""end
	if record.id~=nil then return tostring(record.id)end
	return tostring(record.kind)..":"..tostring(record.item)
end
-- Pure: does a giftEgg answer show the card? A Saved grant does; a Saved AlreadyGranted (a second ask, a replay) only
-- when its card was never shown this session and no gift card is up now, so a double press never shows a second card.
function Chain.showCard(packet,presented,open)
	if type(packet)~="table"or packet.status~="Saved"or type(packet.gift)~="table"then return false end
	if packet.reason~="AlreadyGranted"then return true end
	if open then return false end
	return not(type(presented)=="table"and presented[Chain.recordKey(packet.gift)]==true)
end
-- The daily rack (ROTATION-BRIEF 4, switch daily_rack): the server's order is then Outfit -> Paint -> Toy -> Snack. The
-- Outfit gift takes the Paint gift's place (the tuck, its words, its 1.5 s); the rest follows from `ready` as before.
Chain.Gifts=table.freeze({paint=true,toy=true,snack=true,outfit=true})
Chain.Steps=table.freeze({
	outfit=table.freeze({head="onbGift.paint",sub="onbGift.paintSub",target="Eggs",gift="outfit"}),
	paint=table.freeze({head="onbGift.paint",sub="onbGift.paintSub",target="Eggs",gift="paint"}),
	toy=table.freeze({head="onbGift.toy",sub="onbGift.toySub",target="Eggs",gift="toy"}),
	snack=table.freeze({head="onbGift.snack",sub="onbGift.snackSub",target="Eggs",gift="snack"}),
	unseen=table.freeze({head="onbGift.waiting",sub="onbGift.waitingSub",target="Eggs"}),
	pull=table.freeze({head="onbGift.pull",sub="onbGift.pullSub",target="Eggs"}),
	park=table.freeze({head="onbGift.park",sub="onbGift.parkSub",target="Park"}),
	dash=table.freeze({head="onbGift.dash",sub="onbGift.dashSub",target="Dash"}),
	nest=table.freeze({head="onbGift.nest",sub="onbGift.nestSub",target="Nest"}),
	-- Beta 44 notes 5 and 11 (ONBOARD-SIMPLIFY-BRIEF 1, ARCH-REVIEW-SIMPLIFY 8; Onboard `teach`): while the deck lesson is
	-- next, the pet's own bubble (head only) invites to the deck; a tap opens it (the dock's Deck button wears the
	-- lesson's ring meanwhile).
	deck=table.freeze({head="teach.deckInvite",target="Deck"}),
})
-- Exempt from the gap and the session count: the first gift, and a gift already given.
Chain.Exempt=table.freeze({paint=true,outfit=true,unseen=true})
-- Onboarding part 2 (Onboard `teach`, ONBOARDING-P2-BRIEF 2 rules): every gift step is exempt; the invites (pull, park,
-- dash, nest) count, three a session, 90 s clear of the last reveal. Beta 44: the deck invite is exempt too.
Chain.Teach=table.freeze({exempt=table.freeze({paint=true,toy=true,snack=true,outfit=true,unseen=true,deck=true}),perSession=3,gap=90})
Chain.MaxDt=1 -- s: one step never adds more than this to a bubble's own clock (focus lost, a hitch)
function Chain.rules(teach)
	if teach==true then return Chain.Teach end
	return {exempt=Chain.Exempt,perSession=Chain.PerSession,gap=Chain.Gap}
end

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
	-- Beta 44 (ARCH-REVIEW-SIMPLIFY 8): the course, from live latches (the save's teachMask with this session's): `teach`
	-- on, owed the chain, not graduated and the deck lesson not done (the tour, its ignored-three-sessions latch, a round)
	local teachMask=bit32.bor(tonumber(state.teachMask)or 0,tonumber(live.teachMask)or 0)
	local function latched(index)return bit32.band(teachMask,2^index)~=0 end
	local graduated=live.teach==true and latched(16)
	local deckDone=latched(1)or latched(5)or(tonumber(stats.rounds)or 0)>=1
	return{
		course=live.teach==true and g~=nil and g.owed==true and not graduated and not deckDone,
		deckNext=live.deckNext==true,
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
		teach=live.teach==true,
		-- The lessons remembered (ARCH-REVIEW-TEACH 5): graduated (teachMask `done`), read only with `teach` on.
		graduated=graduated,
	}
end
-- The step the chain is on now, or nil. A gift already given and unseen first; the nest first on a return.
function Chain.next(f)
	if not f.on then return nil end
	if f.unseen then return "unseen"end
	if f.nestReady and f.returned then return "nest"end
	if f.ready=="outfit"then return "outfit"end
	if f.ready=="paint"then return "paint"end
	-- the daily rack: the Outfit gift is the first step, so the deck lesson may follow it before the Paint gift (which
	-- now waits two rounds or a later day); off (no outfit record) exactly as before
	if not(f.granted.paint or f.granted.outfit)then return nil end
	-- beta 44: the deck lesson next (after the Paint gift and its lesson): the deck invite; "You can hatch one!" waits
	-- for the course to be over (the tour seen)
	if f.course and f.deckNext then return "deck"end
	if not f.paid and f.stars>=Chain.cheapest()and not f.course then return "pull"end
	if f.ready=="toy"then return "toy"end
	if f.ready=="snack"then return "snack"end
	local toyDone=f.granted.toy==true or f.toysLeft==0
	if toyDone and not f.fetched and f.parkOn then return "park"end
	if f.fetched and(f.returned or f.teach)and f.dashOn and not f.raced then return "dash"end
	if f.nestReady then return "nest"end
	return nil
end
-- The gift kind a step cranks (paint, toy, snack), or for `unseen` the unseen record's kind; nil for an invite.
function Chain.giftOf(step,f)
	if step=="unseen"then return f.unseen and f.unseen.kind or nil end
	local s=Chain.Steps[step]
	return s and s.gift or nil
end
-- May the bubble for `step` show now? session = {closed = {[step] = true}, count, lastReveal}. teach: part 2's rules.
-- Teach more (ARCH-REVIEW-TEACH 5, TEACH-MORE-BRIEF 0.1; `teach` on): a save owed the chain is never a veteran here; a
-- graduated one gets no invites (a gift's bubble stays: gifts are presents, not lessons); the next lesson's invite (the
-- park and the Dash) is not counted toward the session's three.
Chain.LessonInvites=table.freeze({park=true,dash=true})
function Chain.may(session,step,now,f,teach)
	if not step or session.closed[step]then return false end
	local owedTeach=teach==true and f~=nil and f.on==true
	-- beta 44 (ARCH-REVIEW-SIMPLIFY 7): graduation now comes at about minute 5, so it ends only the deck invite (a
	-- lesson); "You can hatch one!", the park, the Dash and the nest still invite after it
	if owedTeach and f.graduated==true and step=="deck"then return false end
	if f and f.veteran and not owedTeach then return false end
	local r=Chain.rules(teach)
	if r.exempt[step]then return true end
	if(session.count or 0)>=r.perSession and not(owedTeach and Chain.LessonInvites[step])then return false end
	return now-(session.lastReveal or -math.huge)>=r.gap
end
-- The gift that parks as the chip, ribbon and row: ready (or unseen) and not the one the bubble is showing.
function Chain.parked(f,active)
	if not f.on then return nil end
	local kind=if f.unseen then f.unseen.kind elseif Chain.Gifts[f.ready or ""]then f.ready else nil
	if not kind then return nil end
	if active and active.gift==kind then return nil end
	return kind
end
-- Pure (ARCH-REVIEW-P2 2): the gift the Hatch eggs screen offers now, or nil. Only the server's ready gift, never given
-- (granted false), no unseen card waiting (that one replays instead) and not while a gift cranks or shows its card.
function Chain.shopGift(f,active)
	if not f.on or f.unseen then return nil end
	local kind=f.ready
	if not Chain.Gifts[kind or ""]or f.granted[kind]then return nil end
	if active and(active.phase=="cranking"or active.phase=="reveal")then return nil end
	return kind
end

-- ── The controller ───────────────────────────────────────────────────────────────────────────────────────────────────
-- deps: state(), clock(), gate() -> nil when free (the garden's prompt gate, the gift excluded), busy() -> true while
--   another prompt is up (the need bubble, a reveal), bubble = {set(visible, head, sub), hop()}, ribbon(on),
--   row(kind or nil), near() -> at the machine, lead(target), openShop(kind) (Hatch eggs on the free egg),
--   crank(kind, done(status, reason)) (paint/toy: the giftEgg ask; snack: the Snack gift buy; both through the machine),
--   replay(record) (an unseen gift out of the machine again), revealOpen() (a gift card or the Snack's reveal is up),
--   inPark(), fetchCard(), throwTip(), event(name), mask(), park() -> false when this world has no Pet Park,
--   teach() -> Onboard `teach` on; beta 44 (all optional): teachMask() (this session's latches), deckNext() (the deck
--   lesson may light), focused() (the window has focus: the bubble clocks), shopOpen() (the Hatch eggs screen is up)
function Chain.new(deps)
	local self=setmetatable({d=deps,session={closed={},count=0,replayed={}},active=nil,lastFree=nil,returned=nil,fetchedBefore=nil},Chain)
	return self
end
function Chain:read()
	local state=self.d.state()
	if self.returned==nil and type(state)=="table"and type(state.gifts)=="table"then
		local granted=state.gifts.granted
		self.returned=type(granted)=="table"and(granted.paint==true or granted.outfit==true)or false
	end
	local d=self.d
	return Chain.facts(state,{returned=self.returned,mask=d.mask and d.mask(),park=d.park and d.park(),teach=self:teaching(),
		teachMask=d.teachMask and d.teachMask(),deckNext=d.deckNext~=nil and d.deckNext()==true})
end
-- The window has focus (deps.focused; none: always). Beta 44 (ARCH-REVIEW-SIMPLIFY 10): a bubble's nudge and park clocks
-- count only focused time.
function Chain:focused()return self.d.focused==nil or self.d.focused()~=false end
function Chain:teaching()return self.d.teach~=nil and self.d.teach()==true end
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
-- At the machine: an unseen gift comes out again (no shop); any other opens the Hatch eggs screen on it.
function Chain:atMachine()
	local a=self.active
	if not a or not a.gift then return false end
	if a.step=="unseen"then return self:crank()end
	self:hide()
	-- beta 44 note 3 (DIAGNOSIS 3): the shop is open on the gift; no bubble until it closes unpressed ("leading" again)
	a.phase="shop";a.at=self.d.clock();a.shopSeen=false
	if self.d.openShop then pcall(self.d.openShop,a.gift)end
	return true
end
-- A tap on the bubble: a gift at the machine opens the shop on it; otherwise the lead starts (the bubble stays).
function Chain:tap()
	local a=self.active
	if not a or a.phase=="cranking"or a.phase=="reveal"then return false end
	if a.gift and self.d.near()then return self:atMachine()end
	a.phase="leading";a.tapped=true;a.at=self.d.clock()
	self.d.lead(Chain.Steps[a.step].target)
	if not a.gift then
		-- an invite: the lead is the step; it closes for this session (done from the save when it happens)
		self.session.closed[a.step]=true
		self.active=nil;self:hide()
	end
	return true
end
-- A tap on the ribbon or the Things row: start the parked gift (a closed step may restart from these). It leads; at the
-- machine it opens the shop (an unseen gift comes out again).
function Chain:resume()
	local f=self:read()
	local kind=Chain.parked(f,self.active)
	if not kind then return false end
	local step=if f.unseen then "unseen"else kind
	self.session.closed[step]=nil
	self.active={step=step,gift=kind,phase="leading",at=self.d.clock(),tapped=true}
	if self.d.near()then return self:atMachine()end
	self.d.lead("Eggs")
	return true
end
-- The shop's "Hatch free!" (ARCH-REVIEW-P2 2): the parked gift without a lead, then the same crank the chip used. A shop
-- opened from the Menu has no active step: one is built first. False when that gift is not the shop's to give now.
function Chain:shopCrank(kind)
	self:hide() -- beta 44 note 3: the bubble goes the moment Hatch free! is pressed, whatever the answer
	if Chain.shopGift(self:read(),self.active)~=kind then return false end
	local a=self.active
	if not(a and a.gift==kind and a.step==kind)then
		self.session.closed[kind]=nil
		self.active={step=kind,gift=kind,phase="leading",at=self.d.clock(),tapped=true}
	end
	return self:crank()
end
-- The gift the shop offers now (gift mode), or nil.
function Chain:offer()return Chain.shopGift(self:read(),self.active)end
-- An unseen gift's card again, from anywhere (the shop opened from the Menu): true when it replays. Beta 41 review: once
-- per gift a session; a server that never records it seen (the client stopped retrying giftSeen) then lets the shop open
-- as usual, never a replay on every open with Hatch eggs out of reach.
function Chain:replayUnseen()
	local f=self:read()
	if not(f.on and f.unseen)then return false end
	if self.session.replayed[Chain.recordKey(f.unseen)]then return false end
	if self.active and(self.active.phase=="cranking"or self.active.phase=="reveal")then return false end
	self.session.closed.unseen=nil
	self.active={step="unseen",gift=f.unseen.kind,phase="leading",at=self.d.clock(),tapped=true}
	return self:crank()
end
function Chain:crank()
	local a=self.active
	if not a or not a.gift then return false end
	a.phase="cranking";a.at=self.d.clock()
	self:hide()
	self:event("GiftCranked")
	local f=self:read()
	-- suppressed (beta 41 review): a Saved answer whose card is not shown (Chain.showCard: AlreadyGranted, its card
	-- already seen or one up now) is the step's end at once, never a reveal phase held to the stuck timeout
	local done=function(status,reason,suppressed)
		if self.active~=a then return end
		if status=="Saved"and suppressed then
			a.phase="reveal";self:revealed()
		elseif status=="Saved"then
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
		-- once a session (beta 41 review): the bubble does not ask again, and the shop opens as usual after it
		self.session.replayed[Chain.recordKey(f.unseen)]=true
		self.session.closed.unseen=true
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
		self.d.ribbon(false);self.d.row(nil)
		return
	end
	local a=self.active
	-- A card that is not GiftReveal's (the Snack gift's Stat Egg reveal): once seen open, its close is the step's end.
	if a and a.phase=="reveal"and self.d.revealOpen then
		local ok,open=pcall(self.d.revealOpen)
		if ok and open==true then a.seenOpen=true elseif a.seenOpen then self:revealed();a=nil end
	end
	-- A phase that never ended (no answer, a card that never closed): never hold the garden for good.
	if a and Chain.Stuck[a.phase]and now-a.at>=Chain.Stuck[a.phase]then self.active=nil;self:hide();a=nil end
	-- The step's own facts changed under it (given elsewhere, done unprompted): it closes.
	if a and a.phase~="cranking"and a.phase~="reveal"then
		local still=Chain.next(f)==a.step or(a.tapped and a.gift~=nil and Chain.parked(f,nil)==a.gift)
		if not still then self.active=nil;self:hide();a=nil end
	end
	-- beta 44 (ARCH-REVIEW-SIMPLIFY 10): the bubble's own clock, focused time only, one step at most MaxDt
	local dt=math.clamp(now-(self.lastNow or now),0,Chain.MaxDt)
	self.lastNow=now
	local held=if self:focused()then dt else 0
	if a and a.phase=="shop"then
		-- beta 44 note 3: the shop is open on the gift; no bubble. Closed without Hatch free!: leading again.
		self.d.bubble.set(false)
		local open=self.d.shopOpen~=nil and self.d.shopOpen()==true
		if open then a.shopSeen=true
		elseif a.shopSeen or now-a.at>=3 then a.phase="leading";a.at=now;a.nearAt=nil;a.best=nil;a.bestAt=nil end
	end
	if a and(a.phase=="invited"or a.phase=="nudged")then
		local showing=false
		if self.d.gate()~=nil or self.d.busy()then self.d.bubble.set(false)
		else
			local s=Chain.Steps[a.step]
			local near=a.gift~=nil and self.d.near()
			self.d.bubble.set(true,if near then "onbGift.atMachine"else s.head,if near then "onbGift.atMachineSub"else s.sub)
			showing=true
		end
		-- only time the bubble is up counts (a menu, the deck or another prompt over it stops its clock)
		if showing then a.held=(a.held or 0)+held end
		if a.phase=="invited"and a.held>=Chain.NudgeAfter then a.phase="nudged";a.held=0;self.d.bubble.hop()
		elseif a.phase=="nudged"and a.held>=Chain.ParkAfter then self:park("ignored");a=nil end
	elseif a and a.phase=="leading"and a.gift then
		-- at the machine: the bubble says Tap the machine! (a tap opens the shop on the gift). Code review: a lead never holds the Bear's prompts for
		-- long. Standing at the machine untapped parks like an ignored bubble; away from it, LeadPark s with no step
		-- closer (Progress studs), or walking Away studs off from the closest point, parks it (the guide resumes).
		if self.d.near()then
			a.nearAt=a.nearAt or now
			if self.d.gate()==nil then self.d.bubble.set(true,"onbGift.atMachine","onbGift.atMachineSub")else self.d.bubble.set(false)end
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
		local wait=if step=="paint"or step=="outfit"then Chain.PaintDelay else Chain.Free
		if step and step~=self.waitingFor then self.waitingFor,self.waitingSince=step,now end
		if step and free and Chain.may(self.session,step,now,f,f.teach)and now-(self.waitingSince or now)>=wait and now-(self.lastFree or now)>=math.min(wait,Chain.Free)then
			if not Chain.rules(f.teach).exempt[step]then self.session.count+=1 end
			if step=="park"then self.session.parkLed=true end
			self.active={step=step,gift=Chain.giftOf(step,f),phase="invited",at=now}
			self:event("GiftShown")
		end
	end
	local parked=Chain.parked(f,self.active)
	self.d.ribbon(parked~=nil)
	self.d.row(parked)
end
return Chain
