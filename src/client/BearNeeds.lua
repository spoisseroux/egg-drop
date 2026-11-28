-- Onboarding v3 slices A and B (ONBOARDING-V3-PLAN-2026-11-23 sections 3 and 4, the architect review wins).
--
--  A. Follow the Bear (Onboard.sessionFollow(), captured once when the garden is first ready): no five-card tour and no
--     beats (CoachCards options.follow), the paw prints lead to Hatch eggs by themselves (after Say hi with the bubbles
--     on, at once without them), one-line station tips on the station labels (StationAttract options.tip, their own
--     bits), an idle hint after ThingsTips.IdleHint seconds standing still, and the garden step (gardenIntro) is still
--     marked, so funnel step 5 and everything that waits for "the tour is over" still work.
--  B. Need bubbles (Onboard.on("needs")): one bubble over the Bear (NeedBubble), in Order, each one tap from starting,
--     each closed from saved facts (a later one done first is skipped, never replayed), 4 s of nothing between two,
--     hidden whenever ThingsTips.blocked says so and back after 2.5 s free. They replace the "Hatch your first egg" pill
--     (FirstSpendGuide:setQuiet). Returning and veteran saves (gardenIntro or the wins before this session) get none.
--     needNest waits for the nest: with no `nest` in the snapshot, or no nest in the garden yet, it is skipped.
--
-- Presentation only. The one write is deps.mark(id) (the coachMark remote, which the server ORs in and refuses for a part
-- that is off). Pure rules first (spec-checked), then the controller; init.client gives it the game as deps.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Coach=require(Shared:WaitForChild("CoachMarks"))
local Teach=require(Shared:WaitForChild("TeachMarks"))
local Toys=require(Shared:WaitForChild("ToyCatalog"))
local Tips=require(script.Parent.ThingsTips)
local V2=require(script.Parent.OnboardV2)
local Lead=require(Shared:WaitForChild("PetLead"))
local NestLead=require(script.Parent.NestLead)
local Needs={};Needs.__index=Needs
Needs.Order=table.freeze({"needHi","needToy","needDeck","needNest","needPark"})
-- The First Hatch (Onboard "nestfirst"): tomorrow's egg straight after the first hello. Read once when the garden is
-- ready; with it an open bubble is never replaced by an earlier one, and after Say hi the Bear waits up to NestWait
-- for the nest to be drawn (it is placed by a save write on the first garden stand) before the toy goes first.
Needs.NestFirstOrder=table.freeze({"needHi","needNest","needToy","needDeck","needPark"})
Needs.NestWait=6
Needs.Icon=table.freeze({needHi="hand",needToy="ball",needDeck="deck",needNest="moon",needPark="paws"})
-- The same words for readers (the Things to do top row), whole sentences with {pet}.
Needs.Copy=table.freeze({needHi="onb3.need.hi",needToy="onb3.need.toy",needDeck="onb3.need.deck",needNest="onb3.need.nest",needPark="onb3.need.park"})
-- Where a tap (or the idle hint) lays the prints. needHi and needDeck have no place: a tap does the thing.
Needs.Target=table.freeze({needToy="Eggs",needNest="Nest",needPark="Park",follow="Eggs"})
Needs.Rest=4      -- after a need closes, this long with no bubble
Needs.Return=2.5  -- after anything hides the bubble, free this long before it comes back
Needs.Rounds=1    -- saved `stats.rounds` at or above this: a round after the Bear (the Welcome round is not counted)
Needs.Retry=1     -- the first trail could not start (not free yet): try again after this long

-- ── Pure rules ───────────────────────────────────────────────────────────────────────────────────────────────────────
-- What the save (and this session) says. state = the owner snapshot; live = {mask (the coach's, with bits sent this
-- session), saidHi, deckDone, inPark, nest (the garden nest is drawn), park (false: this world has no Pet Park)}.
function Needs.facts(state,live)
	state=if type(state)=="table"then state else {}
	live=live or {}
	local stats=if type(state.stats)=="table"then state.stats else {}
	local toyGiven,toyBought=false,state.pendingToyResult~=nil
	for _,toy in pairs(if type(state.petToys)=="table"then state.petToys else {})do
		if type(toy)=="string"and toy~=""and toy~=Toys.Default then toyGiven=true end
	end
	for _,id in ipairs(Toys.PaidOrder or {})do if Toys.owns(state.toyUnlocks,id)then toyBought=true end end
	local nest=if type(state.nest)=="table"then state.nest else nil
	local playDate=if type(state.playDate)=="table"then state.playDate else {}
	return{mask=Coach.merge(state.coachMask,live.mask),totalWins=tonumber(state.totalWins)or 0,stars=tonumber(state.nectar)or 0,
		toyGiven=toyGiven,toyBought=toyBought,rounds=tonumber(stats.rounds)or 0,
		nest=nest,nestShown=nest~=nil and live.nest==true,nestTucked=nest~=nil and(nest.tucked==true or(tonumber(nest.n)or 0)>0),
		nestReady=nest~=nil and nest.ready==true,
		playDates=tonumber(playDate.count)or 0,parkOn=live.park~=false,saidHi=live.saidHi==true,deckDone=live.deckDone==true,inPark=live.inPark==true,
		-- Teach more (ARCH-REVIEW-TEACH 3): the need bubbles are over for good (TeachMarks `needs`: "You're all set!", or
		-- the server's load rules), read only with Onboard `teach` on (live.teach); a later build's new need never comes back.
		-- Beta 44 (ARCH-REVIEW-SIMPLIFY 5): graduation (`done`) ends them too (the server refuses every latch after it).
		needsOver=live.teach==true and(Teach.has(Teach.merge(state.teachMask,live.teachMask),"needs")or Teach.has(Teach.merge(state.teachMask,live.teachMask),"done")),
		-- Beta 44 (ARCH-REVIEW-SIMPLIFY 8): the deck tour closes "Play for Stars!" (no round is played in it), and while the
		-- course still owes the tour the pet's own bubble ("Let's try playing a game!", GiftChain) asks instead.
		deckTour=live.teach==true and Teach.has(Teach.merge(state.teachMask,live.teachMask),"deckTour"),
		course=live.teach==true and type(state.gifts)=="table"and state.gifts.owed==true
			and not Teach.has(Teach.merge(state.teachMask,live.teachMask),"done")}
end
-- Is this need done (its bit saved, or the thing itself already true)?
function Needs.closed(id,f)
	if Coach.has(f.mask,id)then return true end
	if id=="needHi"then return f.saidHi end
	if id=="needToy"then return f.toyGiven end
	if id=="needDeck"then return f.deckDone or f.rounds>=Needs.Rounds or f.deckTour==true end
	if id=="needNest"then return f.nestTucked end
	if id=="needPark"then return f.inPark or f.playDates>0 or Coach.has(f.mask,"park")end
	return true
end
-- Can it be asked for at all? needNest only once the nest is really there with an egg to tuck in (beta 37 note 3: an
-- egg already ready only hatches, its prompt says Hatch, so "Tuck the egg in!" could never be done), needPark only
-- with a park.
function Needs.available(id,f)
	if id=="needNest"then return f.nestShown==true and f.nestReady~=true end
	if id=="needPark"then return f.parkOn~=false end
	-- beta 44: with the course on, the deck is the gift chain's invite (never two bubbles asking for it)
	if id=="needDeck"and f.course==true then return false end
	return Needs.Icon[id]~=nil
end
-- The need open now, or nil. ctx: {on (the switch), returning, owned, order, skip (ids passed over this session)}.
function Needs.current(f,ctx)
	ctx=ctx or {}
	if ctx.on~=true or ctx.returning==true or(ctx.owned or 0)<=0 or Coach.veteran(f.totalWins)or f.needsOver==true then return nil end
	for _,id in ipairs(ctx.order or Needs.Order)do
		if Needs.available(id,f)and not Needs.closed(id,f)and not(ctx.skip and ctx.skip[id])then return id end
	end
	return nil
end
-- Onboarding v2 step 5 (Onboard "guide", ONBOARDING-V2.md; Spencer: "it didnt say anything after hatching the bear, just
-- to press g on it??"): three worded prompts, one at a time (Pet Bear!, Tuck the egg in!, Play for Stars!), no key caps
-- on a computer, a trail to anything far, and after the third the end card ("You're all set!"). Beta (37) note 3: a
-- prompt stays until it is done; shown Guide.ignore s it nudges (a hop and a soft chirp, at most every Guide.nudge s).
-- Never locked, never a soft block: each prompt shows only when it can be done (below) and the game is free
-- around it. The toy and the park are found through Things to do, as today. Off: today's bubbles exactly.
--   needHi    done by a greeting, petting, or a tap on the bubble or the Bear. No pet drawn (stowed, its rig loading):
--             no bubble and no clock.
--   needNest  done when the egg is tucked in, or once one has hatched. No nest drawn, no egg in it (none landed yet,
--             or between hatches) or the egg already ready (its prompt is Hatch): not asked; the next prompt shows
--             (after NestWait for the nest to be drawn).
--   needDeck  done when the deck opens (its button, the bubble or the Bear) or a round ends.
--   All: hidden, with the clock stopped, while ThingsTips.blocked says so (the deck or a menu open, a mini game, the
--   park, care, a card, the greeting shot) or a station prompt is in reach; back 2.5 s after.
Needs.GuideOrder=V2.Guide.order
-- Pure: is the guide finished (every prompt closed or passed over)? f: facts, skip: the passed-over ids.
function Needs.guideDone(f,skip)
	for _,id in ipairs(Needs.GuideOrder)do
		if not Needs.closed(id,f)and not(skip and skip[id])and Needs.available(id,f)then return false end
	end
	return true
end
-- Onboarding v3 brief section 1 (Onboard "lead", read once with the guide): the same three prompts in two lines, the
-- nest prompt led by the pet (NestLead: 2a "Follow {pet}!", then 2b "Tuck the egg in!" on the nest), 2 s between two,
-- and "Play for Stars!" done only by a round played (not by opening the deck). The guide is finished only when all
-- three are truly done (never passed over, never a park). A returning save whose guide is unfinished (Pet done in an
-- earlier session, Nest or Stars not yet) picks it up from its saved facts; a veteran gets none.
-- Pure: may a returning save pick its unfinished guide back up? state: the owner snapshot.
function Needs.resumable(state)
	if type(state)~="table"or Coach.veteran(state.totalWins)then return false end
	if not Coach.has(state.coachMask,"needHi")then return false end
	local f=Needs.facts(state,{})
	return not Needs.closed("needDeck",f)or(type(state.nest)=="table"and not Needs.closed("needNest",f)and state.nest.ready~=true)
end
-- Pure: why the bubble hides now (ThingsTips.blocked, "shown"), or nil. guide: the guide's worded prompts are on. The
-- guide's prompt is for a player who has not acted yet, so a still player keeps it: no input for Tips.Away s is not
-- "away" for it (beta 38: the first "Pet Bear!" hid 20 s after Meet, before its own nudge at Guide.ignore s could
-- ever fire). A window left behind still hides it.
function Needs.blocked(gate,guide)
	local why=Tips.blocked(gate,"shown")
	if why=="away"and guide==true and type(gate)=="table"and gate.windowActive~=false then return nil end
	return why
end
-- Pure: all three truly done. nestRequired false (the nest is off in this world): Pet and Stars.
function Needs.trulyDone(f,nestRequired)
	if not Needs.closed("needHi",f)or not Needs.closed("needDeck",f)then return false end
	return nestRequired==false or Needs.closed("needNest",f)
end
-- Pure: the v3 brief's words for a need (UICopy keys: headline, sub-line or nil), its icon and the sub-line's vars (the
-- tuck's countdown, beta 40; nil for the rest). view: NestLead's view for the nest prompt.
function Needs.leadWords(id,view)
	local P=Lead.Prompts
	if id=="needNest"then
		if type(view)=="table"and view.head then return view.head,view.sub,view.icon,view.subVars end
		local sub,vars=Lead.hatchWords("sub",nil)
		return P.tuck.head,sub,P.tuck.icon,vars
	end
	local entry=P[id]
	if entry then return entry.head,entry.sub,entry.icon end
	return nil
end
-- Pure: the guide's words for a need (UICopy key and vars), nil when it has none.
function Needs.guideWords(id,pet)
	local key=V2.GuideCopy[id]
	return key,{pet=pet or "Bear"}
end
-- The bubble's icon. Need 2 with fewer Stars than a Toy Egg and no toy yet: the deck first, then the ball.
function Needs.icon(id,f)
	if id=="needToy"and not f.toyBought and f.stars<Toys.Cost then return "deck"end
	return Needs.Icon[id]
end
-- Where this need (or "follow") points, as a place name for deps.place, or nil.
function Needs.target(key,f)
	if key=="needToy"and f and Needs.icon(key,f)~="ball"then return nil end
	return Needs.Target[key]
end

-- ── Controller ───────────────────────────────────────────────────────────────────────────────────────────────────────
-- deps: state() snapshot, owned() pets, mask() the coach mask, mark(id), finishIntro() (CoachCards:finishGarden),
--   follow() (Onboard.sessionFollow), needs() (Onboard.on "needs"), returning() (this session began as a returning
--   player), gate() the ThingsTips.blocked table (with roomFor, idleFor), greeting() (the Bear's greeting shot is up),
--   inPark(), nest() (the garden nest is drawn), park() (optional: false when there is no Pet Park), petShown() (optional:
--   the pet is drawn in the garden; the guide waits while it is not), place(name) -> position, label, trail(target, how) -> bool,
--   trailActive(), trailTarget() (optional: the target the live trail was started with), prompt() (optional: a
--   station prompt is in reach), sayHi(), playDeck(), quiet(on) (the pill), chirp(), react(id), bubble (NeedBubble:
--   set(icon, visible), hop(), step(dt)).
--   The v3 brief (all optional): lead() (Onboard.leadOn), allSet2() (Onboard "allset2"), nestOn() (Onboard "nest"),
--   copy(key) (UICopy with {pet}), leadDeps (NestLead's deps); the bubble's chip(on) and set's fourth argument (the
--   sub-line). Needs.bubbleOn says where the bubble hangs ("pet" or "nest"); Needs:chipTap() is the parked chip's tap.
function Needs.new(deps)
	return setmetatable({d=deps,live={},track={},restUntil=0,gardenFor=0,retryAt=0},Needs)
end
-- The ThingsTips gate as BearNeeds reads it: `on` is Things to do itself (Onboard.open already needs it), never the
-- Things tips switch, which would hold the Bear (and the garden step, funnel step 5) back for good with tips off.
function Needs.gate(g,thingsOn)
	local out=if type(g)=="table"then table.clone(g)else {}
	out.on=thingsOn==true
	return out
end
-- Does need 5 take the park line's place (ThingsTips ctx.needs)? Only for a new player this session, once ready.
function Needs:replacesParkLine()
	return self.ready==true and not self.returning and not self.dead and self.d.needs()==true
end
-- Gave up (an error in step): the tour is already off for this session, so the garden step is marked here (funnel step
-- 5), the pill comes back and the bubble goes. Safe to call twice.
function Needs:abandon()
	if self.dead then return end
	self.dead=true
	pcall(function()self:hide()end)
	pcall(self.d.quiet,false)
	if self.follow and not self.returning and not self.introDone then
		self.introDone=true
		self.d.finishIntro()
	end
end
function Needs:saidHi()self.live.saidHi=true end
-- The onboarding fun pass (PetCuddle.First): is the petting screen opening now the guide's first pet (the 3 s heart,
-- the burst closes the screen)? A session latch, not the open prompt: the greeting itself closes "Pet me!" (beta 39:
-- any frame of focus, a refused first try included, closed it before the screen read it, so the first visit never
-- closed). Owed from the guide's start while "Pet me!" was still open, until a first visit's burst (firstCuddleDone);
-- never for a returning save, a pet already said hi to, or once the guide is all set.
function Needs:firstCuddle()
	return self.guide==true and self.firstPetOwed==true and not self.dead and not self.allSet
end
function Needs:firstCuddleDone()self.firstPetOwed=false end
-- The v3 brief's parked chip was tapped: the lead again.
function Needs:chipTap()
	local lead=self.nestLead
	if not lead or not lead:unpark()then return false end
	self.forceNest=true
	return true
end
-- The station that beckons alone while a need (or the first trail) points at it.
function Needs:focus()
	local key=self.pointing
	local where=if key then Needs.target(key,self.f)else nil
	return if where=="Eggs"or where=="Park"then where else nil
end
-- A trail the player started (Things to do, Show me) is never replaced by the Bear's own (auto, idle); a tap may.
function Needs:trailFree()
	local d=self.d
	if d.trailActive()~=true then return true end
	return d.trailTarget~=nil and self.trail~=nil and d.trailTarget()==self.trail
end
function Needs:trailTo(where,how)
	if not where then return false end
	if how~="tap"and not self:trailFree()then return false end
	local position,label=self.d.place(where)
	if typeof(position)~="Vector3"then return false end
	local target={position=position,name=label}
	local ok=self.d.trail(target,how)==true
	if ok then self.trail=target end
	return ok
end
function Needs:hide()
	if self.shown then self.shown=false;self.d.bubble:set(nil,false)end
end
-- Beta 14 B3b: one physical tap can reach up to three handlers (the bubble's button, the Bear's click target and the
-- touch-in-world fallback): one action a step frame, and with deps.clock one every TapGap seconds. Every taken tap
-- squashes the bubble (bubble:press()); a tap that repeats a trail already on the ground also hops it and chirps.
Needs.TapGap=.3
function Needs:recentTap()
	local clock=self.d.clock and self.d.clock()or nil
	if self.tapFrame~=nil and self.tapFrame==self.stepAt then return true end
	return clock~=nil and self.tapClock~=nil and clock-self.tapClock<Needs.TapGap
end
function Needs:markTap()self.tapFrame,self.tapClock=self.stepAt,(self.d.clock and self.d.clock()or nil)end
function Needs:tap()
	local id=self.open
	if not id or not self.shown then return false end
	if self:recentTap()then return true end
	self:markTap()
	self.taps=(self.taps or 0)+1
	local bubble=self.d.bubble
	if bubble.press then pcall(bubble.press,bubble)end
	local icon=Needs.icon(id,self.f)
	if id=="needHi"then return self.d.sayHi()==true end
	if icon=="deck"then return self.d.playDeck()==true end
	-- the lead's 2a ("Follow {pet}!"): the pet's own prints are the way; a tap (or G) only hops the bubble and chirps,
	-- never today's Show me trail on top of the lead's (beta 38 review C6)
	if id=="needNest"and self.leadStage=="follow"then bubble:hop();self.d.chirp();return true end
	local where=Needs.target(id,self.f)
	local again=self.trail~=nil and self.d.trailActive()==true and self.d.trailTarget~=nil and self.d.trailTarget()==self.trail
		and self.trail.name~=nil and select(2,self.d.place(where))==self.trail.name
	local ok=self:trailTo(where,"tap")
	if ok and again then bubble:hop();self.d.chirp()end
	return ok
end
-- Studio QA 2026-11-23: two more ways to do what the bubble does, while it shows.
--  * A tap or click on the Bear itself (source "tap"): for needToy, needDeck and needPark it does the need's action
--    instead of the greeting. needHi keeps the greeting (that is its action). The pet's own key (E / ButtonX, the
--    "Say hi" prompt, source "key") always keeps the greeting and petting: it is never taken.
--  * Its own key, Needs.Keys (G on a keyboard, L2 on a gamepad; nothing else in the garden uses them): the need's
--    action, whichever need it is. The bubble's key cap shows it (Needs.keyHint).
Needs.Keys=table.freeze({Keyboard="G",Gamepad="L2"})
function Needs.keyHint(input)return Needs.Keys[input]end
function Needs:claimsPetTap(source)
	return source~="key"and self.shown==true and not self.dead and self.open~=nil and self.open~="needHi"
end
-- A tap on the Bear: true when the need took it (the caller then skips the greeting).
function Needs:petTap(source)
	-- The hand bubble: the greeting itself is the action; a tap already taken this frame (the bubble's own fallback)
	-- swallows the Bear's, so one physical tap is one greeting.
	if source~="key"and self.shown==true and not self.dead and self.open=="needHi"then
		if self:recentTap()then return true end
		self:markTap();return false
	end
	if not self:claimsPetTap(source)then return false end
	self:tap()
	return true
end
-- The bubble's own key: true when it was used (sink the input), false to pass it on.
function Needs:key()
	if not self.shown or self.dead then return false end
	self:tap()
	return true
end
function Needs:step(now,dt)
	local d=self.d
	dt=dt or 0
	local state=d.state()
	if self.dead then return end
	if type(state)~="table"or(state.status~=nil and state.status~="Ready")then self:hide();d.bubble:step(dt);return end
	-- "Returning" is what the save said before this session: a garden step the tour marks today does not count.
	if self.began==nil then self.began=Tips.returning(state)end
	local owned=d.owned()or 0
	local gate=d.gate()or {}
	local blocked=Needs.blocked(gate,self.guide==true)
	if blocked==nil then self.freeSince=self.freeSince or now else self.freeSince=nil end
	local freeFor=if self.freeSince then now-self.freeSince else 0
	self.stepAt=now
	-- Beta 14 B3a: with the bubbles on for this session, a greeting counts as "said hi" only once the hand bubble has
	-- shown (the first Meet's automatic greeting shot comes before it and used to close need 1 unseen). Bubbles off or a
	-- returning save: any greeting counts, as before. Petting (Needs:saidHi) and a tap on the bubble count any time.
	local asking=(d.needs()==true or(d.guide~=nil and d.guide()==true))and not(if self.ready then self.returning else(d.returning()==true or self.began==true))
	if owned>0 and d.greeting()==true and(self.hiShown or not asking)then self.live.saidHi=true end
	if d.inPark()==true then self.live.inPark=true end
	self.live.mask=d.mask()
	self.live.teach=d.teach~=nil and d.teach()==true
	self.live.teachMask=if d.teachMask then d.teachMask()else nil
	self.live.nest=d.nest()==true
	if d.park then self.live.park=d.park()~=false end
	local f=Needs.facts(state,self.live)
	self.f=f
	-- The garden is first ready: the follow switch for this session is read now, never before (the attribute may lag),
	-- and so is "returning" (the tour, or the wins, before this session).
	if not self.ready then
		local returning=d.returning()==true or self.began==true
		-- The pill stays away while the bubbles are on, from the first frame (the bubble takes its place).
		d.quiet(d.needs()==true and not returning)
		if owned>0 and not gate.revealPending and blocked==nil and(gate.roomFor or 0)>=Tips.Settle then
			self.ready=true
			self.follow=d.follow()==true
			self.returning=returning
			self.roundsAt=f.rounds
			self.order=if d.nestFirst and d.nestFirst()==true then Needs.NestFirstOrder else nil
			-- Onboarding v2 step 5: the guide's three prompts, read once here like the order
			-- the v3 brief: an unfinished guide is picked up again from the saved facts (a veteran still gets none)
			local leadOn=d.lead~=nil and d.lead()==true and d.guide~=nil and d.guide()==true
			if returning and leadOn and Needs.resumable(state)then returning=false;self.returning=false;self.resumed=true end
			self.guide=d.guide~=nil and d.guide()==true and not returning
			if self.guide then self.order=Needs.GuideOrder;self.skipped={};self.shownFor={};self.nudgedAt={}end
			-- the fun pass's first petting visit (PetCuddle.First) is owed from here until its burst (Needs:firstCuddle)
			self.firstPetOwed=self.guide==true and not Needs.closed("needHi",f)
			self.lead=self.guide and leadOn
			if self.lead and d.leadDeps then self.nestLead=NestLead.new(d.leadDeps)end
			self.allSet2=self.guide and d.allSet2~=nil and d.allSet2()==true
		else self:hide();d.bubble:step(dt);return end
	end
	if f.rounds>(self.roundsAt or f.rounds)then self.live.deckDone=true;f.deckDone=true end
	-- The guide's "Play for Stars!" is done when the deck opens (the v3 brief's lead: only when a round is played).
	if self.guide and not self.lead and gate.mode=="Board"then self.live.deckDone=true;f.deckDone=true end
	-- The v3 brief: a parked lead passes the nest prompt over for now; it comes back after the deck next closes.
	local nestLead=self.nestLead
	if nestLead then
		if nestLead.parked and gate.mode=="Board"then self.parkSawDeck=true end
		if nestLead.parked and self.parkSawDeck and gate.mode=="Room"then
			self.parkSawDeck=false
			if nestLead:unpark()then self.forceNest=true end
		end
		self.skipped.needNest=if nestLead.parked and not Needs.closed("needNest",f)then true else nil
	end
	local needsOn=(d.needs()==true or self.guide==true)and not self.returning
	d.quiet(needsOn)
	-- A: the garden step, the first trail, the idle hint's "follow" key ---------------------------------------------
	local new=self.follow and not self.returning
	if new and not self.introDone and not Coach.has(f.mask,"gardenIntro")then
		if blocked==nil and gate.mode=="Room"then self.gardenFor+=dt end
		if not needsOn and not self.autoTrail and blocked==nil and now>=self.retryAt and self:trailFree()then
			self.retryAt=now+Needs.Retry
			self.autoTrail=self:trailTo("Eggs","auto")
		end
		if self.autoTrail and not(d.trailActive()==true and self:trailFree())then self.trailOver=true end
		if Tips.followDone({saidHi=Needs.closed("needHi",f),trailOver=self.trailOver,gardenFor=self.gardenFor,needs=needsOn})then
			self.introDone=true
			d.finishIntro()
		end
	end
	-- The machine is learned (its first visit saved) or the toy is given: nothing left to follow.
	local following=new and not needsOn and not Coach.has(f.mask,"hatch")and not f.toyGiven
	-- B: the bubbles -------------------------------------------------------------------------------------------------
	local id=if needsOn then Needs.current(f,{on=true,owned=owned,order=self.order,skip=self.skipped})else nil
	-- the chip tapped (or the deck closed after a park): the nest prompt again, before anything open
	if self.forceNest then
		if nestLead and not nestLead.parked and Needs.available("needNest",f)and not Needs.closed("needNest",f)then id="needNest";self.open=id
		else self.forceNest=nil end
	end
	if needsOn and self.order then
		if self.open and self.open~=id and Needs.available(self.open,f)and not Needs.closed(self.open,f)
			and not(self.skipped and self.skipped[self.open])then
			id=self.open -- locked: the open need stays until it closes
		elseif id and id~="needNest"and Needs.closed("needHi",f)and not Needs.closed("needNest",f)
			and not Needs.available("needNest",f)then
			self.nestWaitFrom=self.nestWaitFrom or now
			if now-self.nestWaitFrom<Needs.NestWait then id=nil end
		end
	end
	if needsOn then
		for _,need in ipairs(Needs.Order)do
			if not Coach.has(f.mask,need)and Needs.available(need,f)and Needs.closed(need,f)then d.mark(need)end
		end
	end
	-- The v3 brief: the nest prompt closed: the celebration once (a tuck), and the lead is over.
	if nestLead and nestLead.begun and not nestLead.done and Needs.closed("needNest",f)then nestLead:finish(f.nestTucked==true)end
	-- parked, but the player walked to the nest anyway: its prompt again, on the nest
	if nestLead and nestLead.parked and nestLead.reached and nestLead:unpark()then self.forceNest=true end
	if id~=self.open then
		if self.open=="needNest"and nestLead and not nestLead.done and not nestLead.parked then nestLead:pause()end
		if self.open~=nil then
			-- the lead (onboarding fun pass): the first pet's close has no rest, and the next prompt asks once the garden
			-- has been free Lead.AfterPet.free s (not Needs.Return): the Bear runs out of the petting screen
			local afterPet=self.lead and self.open=="needHi"
			self.restUntil=now+(if afterPet then Lead.AfterPet.rest elseif self.lead then Lead.Rest else Needs.Rest);d.react(self.open)
			self.quickReturn=if afterPet then Lead.AfterPet.free else nil
			-- The guide's first pet: the hearts and purr are the petting's own; the settle buzz is the guide's.
			if self.guide and self.open=="needHi"and Needs.closed("needHi",f)and d.firstPet then pcall(d.firstPet)end
		end
		self.open=id
		-- The first trail starts by itself after Say hi (the ball bubble), once.
		if id=="needToy"and self.follow and not self.autoTrail then self.autoPending=true end
	end
	self.pointing=if id then id elseif following then "follow"else nil
	-- Never over a machine's prompt (the bubble is always on top).
	local promptNear=d.prompt~=nil and d.prompt()==true
	local leadNest=self.lead and id=="needNest"and nestLead~=nil
	local show=id~=nil and now>=self.restUntil and blocked==nil and freeFor>=(self.quickReturn or Needs.Return)and not promptNear
		-- the guide's bubble hangs over the pet: with none drawn (stowed, loading) it waits, its clock stopped (the v3
		-- brief's nest prompt sits on the nest instead)
		and not(self.guide and not leadNest and d.petShown~=nil and d.petShown()~=true)
	if show then self.quickReturn=nil end
	-- The v3 brief: the lead runs (or pauses) while the nest prompt is open; a prompt in reach only hides the bubble.
	local view=nil
	if leadNest then
		local leading=show or(promptNear and blocked==nil)
		view=nestLead:step(now,dt,{shown=leading,blocked=if leading then nil else(blocked or "rest")})
		if view and view.stage=="parked"then show=false end
	elseif nestLead and nestLead.parked then nestLead:step(now,dt,{shown=true})end
	self.leadStage=view and view.stage or nil
	self.bubbleOn=if view and view.on=="nest"then "nest"else "pet"
	if d.bubble.chip then d.bubble:chip(nestLead~=nil and nestLead.parked==true and not Needs.closed("needNest",f))end
	if show and self.guide then
		-- The guide: the prompt in words, until it is done. Shown Guide.ignore s it nudges (beta 37 note 3: never skips).
		self.shownFor[id]=(self.shownFor[id]or 0)+dt
		-- the lead's 2a has its own nudges (NestLead)
		local ownNudges=view~=nil and view.stage=="follow"
		if not ownNudges and V2.nudgeDue(self.shownFor[id],self.nudgedAt[id],now)then
			self.nudgedAt[id]=now
			self.nudges=(self.nudges or 0)+1
			d.bubble:hop();d.chirp()
			-- one hop and chirp at a time: the idle hint waits its own gap after a nudge
			if self.track.key~=id then self.track.key,self.track.count=id,0 end
			self.track.lastAt=now
		end
		local words,sub=nil,nil
		local icon=V2.GuideIcon[id]or Needs.icon(id,f)
		if self.lead then
			local head,second,leadIcon,vars=Needs.leadWords(id,view)
			local function say(key,with)if not key then return nil end;if d.copy then return d.copy(key,with)end;return key end
			words,sub,icon=say(head),say(second,vars),leadIcon or icon
		elseif d.words then words=d.words(id)end
		if not self.shown or self.shownIcon~=icon or self.shownWords~=words or self.shownSub~=sub then d.bubble:set(icon,true,words,sub)end
		self.shownWords,self.shownSub,self.shownIcon=words,sub,icon
		-- A prompt that points somewhere far gets the dotted trail once (the lead lays its own).
		if id=="needNest"and not self.lead and not self.nestTrail and d.far and d.far("Nest")==true then self.nestTrail=self:trailTo("Nest","auto")end
		self.guideShown=true
	end
	if d.pulseDeck and self.guide then pcall(d.pulseDeck,show and id=="needDeck")end
	-- The end card. The v3 brief (lead or allset2): only when all three are truly done, in the garden, nothing open.
	local strict=self.lead or self.allSet2
	local finished=if strict then Needs.trulyDone(f,d.nestOn==nil or d.nestOn()==true)else Needs.guideDone(f,self.skipped)
	if self.guide and self.guideShown and not self.allSet and finished and(not strict or(blocked==nil and gate.mode=="Room"and id==nil))then
		self.allSet=true
		if d.allSet then pcall(d.allSet)end
	end
	if show then
		local icon=if self.guide then(self.shownIcon or V2.GuideIcon[id]or Needs.icon(id,f))else Needs.icon(id,f)
		if not self.guide and(not self.shown or self.shownIcon~=icon)then d.bubble:set(icon,true,nil)end
		self.shown,self.shownIcon=true,icon
		if id=="needHi"then self.hiShown=true end
		if self.autoPending and icon=="ball"and self:trailFree()then
			self.autoPending=false
			self.autoTrail=self:trailTo("Eggs","auto")
		end
	else self:hide()end
	-- The idle hint: still this long with something open, at most IdleHints per need (the lead's nest prompt has its own).
	if self.pointing and blocked==nil and not leadNest and Tips.idleDue(self.track,self.pointing,gate.idleFor,now)then
		d.chirp()
		if self.shown then d.bubble:hop()end
		self:trailTo(Needs.target(self.pointing,f),"idle")
		self.hints=(self.hints or 0)+1
	end
	d.bubble:step(dt)
end
return Needs
