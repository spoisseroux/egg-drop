-- Onboarding part 2: five small lessons on the real buttons (artifacts/qa-2026-11-27-beta40/ONBOARDING-P2-BRIEF.md
-- section 2, ARCH-REVIEW-P2 sections 1 and 4; Onboard "teach"; Spencer's beta 40 note 8: "the onboarding didnt teach
-- me how to use the menus, customize the bear, pocket deck, or play the minigame or park?"). The rule: teach the real
-- button. Every lesson is the normal screen with one thing lit (TeachPointer), and ends in something happening to the pet.
--   dress  after the Paint gift's card: "Dress up!" on the pet screen's Dress up, then "Tap Paint!" on the Colour tab's
--          Paint key (the won pot selected)          done: any pet holds paint (a pot was used, hueUse saved)
--   deck   after the wipe, or "Later" on the card: "Play!" on the dock's Deck button   done: stats.rounds >= 1 (the Welcome round is not counted)
--   menu   after "You're all set!" ("What's next?" lights the Menu button), or once the deck is done: "Open the Menu!",
--          then "All the games!" on the hub's Things to do tile               done: coach bit menuSeen (28)
--   park   the Toy gift given (or every toy owned) and no fetch yet, in the Pet Park: "Throw it!"   done: stats.fetches > 0
--   dash   fetch learned, no ribbon yet, at the Dash gate: "Go!" on its first race   done: a ribbon in public.dash
-- Teach more (artifacts/qa-2026-11-27-beta42/TEACH-MORE-BRIEF.md sections 0, 2 and 3; ARCH-REVIEW-TEACH; Spencer's beta 42
-- notes 6 to 8): five more lessons in the same voice, and "done for good".
--   reset     after lesson A's wipe, the pet screen still open: "One more thing!" on Dress up, then the Colour tab scrolled to
--             Back to white: "Change your mind? It's free!" (show-only: saved once the ringed card was on screen; it never
--             asks for the tap)
--   quests    the round-two opener, after the level step: "Quests pay extra ★" on the quest handle   done: the log opened
--   snacks    a snack in the pouch: "Snack time!" on the pet screen's Snacks, then "Feed {pet}!" on the snack   done: fed
--   stats     snacks done (or the Dash done with an empty pouch): "See {pet} grow!" on Stats   done: the panel opened
--   wardrobe  stats done, the next time the pet screen opens: "Dress up!", then "Outfits!" on the Outfit tab   done: opened
-- Every lesson is a latch (TeachMarks `teachMask`): done once its fact was true, even if the fact later turns false (Back
-- to white). This session's latches count at once (live.teachMask), before the save has them. A save owed the gift chain
-- is never a veteran here (section 0.1); a graduated save (`done`) gets nothing. A lesson whose feature is off on this
-- place (no Pet Park, no Garden Dash) counts as done. Ignored in a session (parked) is told to the server ("park:<id>");
-- the third such session latches it. Every lesson of the course done: the client asks "done:finished".
-- Rules: one pointer at a time; never beside a card or reveal; a lesson is done only by its saved fact, whoever caused
-- it, never by a timer. Ignored for Ignore s: the pointer fades and that lesson waits for the next session (parked).
-- Pure rules first (TeachLessons.spec), then the controller.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Coach=require(Shared:WaitForChild("CoachMarks"))
local Teach=require(Shared:WaitForChild("TeachMarks"))
local Toys=require(Shared:WaitForChild("ToyCatalog"))
local Lessons={};Lessons.__index=Lessons
Lessons.Order=table.freeze({"dress","reset","deck","menu","quests","park","dash","snacks","stats","wardrobe"})
Lessons.Ignore=12 -- s a pointer shows untouched before it fades (back once next session)
Lessons.ResetSeen=1.5 -- s the Back to white card is on screen, ringed, before the reset lesson is saved
Lessons.Words=table.freeze({dress="teach.dress",paint="teach.paint",deck="teach.deck",menu="teach.menu",things="teach.things",
	throw="teach.throw",go="teach.go",more="teach.more",reset="teach.reset",quests="teach.quests",snack="teach.snack",feed="teach.feed",
	stats="teach.stats",outfits="teach.outfits"})
-- Keyboard keys and gamepad glyphs the labels add (brief section 3; teach more: Stats Y, Snacks X).
Lessons.Keys=table.freeze({menu={key="M",glyph="Y"},things={glyph="A"},dress={glyph="R1"},paint={key="ENTER",glyph="A"},
	deck={glyph="A"},throw={key="F",glyph="R2"},go={key="ENTER",glyph="A"},more={glyph="R1"},snack={glyph="X"},feed={glyph="A"},
	stats={glyph="Y"},outfits={glyph="A"}})

-- ── Pure ────────────────────────────────────────────────────────────────────────────────────────────────────────────
local function painted(state)return Teach.painted(state)end
Lessons.painted=painted
-- The facts from the owner snapshot. live = {teach, mask (this session's coach bits), teachMask (this session's latches),
-- park (false: no Pet Park here), wipe (lesson A's wipe is playing), visit (the pet screen's opening number)}.
function Lessons.facts(state,live)
	state=if type(state)=="table"then state else {}
	live=live or {}
	local g=if type(state.gifts)=="table"then state.gifts else nil
	local granted=g and type(g.granted)=="table"and g.granted or {}
	local stats=if type(state.stats)=="table"then state.stats else {}
	local mask=Coach.merge(state.coachMask,live.mask)
	local teach=Teach.merge(state.teachMask,live.teachMask)
	local dash=if type(state.dash)=="table"then state.dash else nil
	local raced=false
	for _,n in pairs(dash and type(dash.ribbons)=="table"and dash.ribbons or {})do if type(n)=="number"and n>0 then raced=true end end
	local unseen=g and type(g.unseen)=="table"and g.unseen or nil
	local egg=if type(state.statEgg)=="table"then state.statEgg else {}
	local latched={}
	for id in pairs(Teach.Bits)do latched[id]=Teach.has(teach,id)end
	return{
		on=live.teach==true and g~=nil and g.owed==true,
		graduated=latched.done==true,
		latched=latched,teachMask=teach,
		paintSeen=granted.paint==true and not(unseen and unseen.kind=="paint"),
		painted=painted(state),
		rounds=tonumber(stats.rounds)or 0,
		menuSeen=Coach.has(mask,"menuSeen"),
		questsSeen=Coach.has(mask,"quests"),
		toyDone=granted.toy==true or #Toys.remaining(state.toyUnlocks)==0,
		fetched=(tonumber(stats.fetches)or 0)>0,
		dashOn=dash~=nil,raced=raced,
		parkOn=live.park~=false,
		pouch=if type(egg.pouch)=="table"then #egg.pouch else 0,
		wipe=live.wipe==true,visit=live.visit,
	}
end
-- Each lesson's latch or its fact (ARCH-REVIEW-P2 1, ARCH-REVIEW-TEACH 1 and 9). deckTour and level are DeckTour's.
function Lessons.done(id,f)
	local l=f.latched or {}
	if l[id]then return true end
	if id=="dress"then return f.painted==true end
	if id=="deck"or id=="deckTour"then return(f.rounds or 0)>=1 end -- a field round played; the Welcome round is not counted
	if id=="level"then return(f.rounds or 0)>=2 end
	if id=="menu"then return f.menuSeen==true end
	if id=="quests"then return f.questsSeen==true end
	if id=="park"then return f.fetched==true or f.parkOn==false end -- no Pet Park on this place: done
	if id=="dash"then return f.raced==true or f.dashOn==false end -- no Garden Dash: done
	if id=="reset"or id=="snacks"or id=="stats"or id=="wardrobe"then return false end -- latched only
	return true
end
-- Is the lesson's trigger true? session = {skipped = {[id] = true} ("Later"), asked = {[id] = true} (a card asked for it),
-- statsVisit (the pet screen opening in which Stats was learned)}.
function Lessons.ready(id,f,session)
	session=session or {}
	local skipped=session.skipped or {}
	local asked=session.asked or {}
	if id=="dress"then return f.paintSeen==true end
	if id=="reset"then return Lessons.done("dress",f)and f.wipe~=true end
	if id=="deck"then return Lessons.done("dress",f)or skipped.dress==true or asked.deck==true end
	if id=="menu"then return Lessons.done("deck",f)or asked.menu==true end
	if id=="quests"then return(f.rounds or 0)>=1 and Lessons.done("level",f)end
	if id=="park"then return f.parkOn~=false and f.toyDone==true end
	if id=="dash"then return f.fetched==true and f.dashOn==true end
	if id=="snacks"then return(f.pouch or 0)>0 end
	-- nothing dead-ends: with no snack to feed, Stats and the Wardrobe unlock off the Dash
	if id=="stats"then return Lessons.done("snacks",f)or(Lessons.done("dash",f)and(f.pouch or 0)==0)end
	if id=="wardrobe"then return Lessons.done("stats",f)and(session.statsVisit==nil or session.statsVisit~=f.visit)end
	return false
end
-- The lessons that may light now, in order: ready, not done, not parked this session. The controller lights the first
-- whose button is on screen (one pointer at a time); `next` is the first of them. Graduated: none.
function Lessons.candidates(f,session)
	local out={}
	if not f.on or f.graduated then return out end
	session=session or {}
	local parked=session.parked or {}
	for _,id in ipairs(Lessons.Order)do
		if not Lessons.done(id,f)and Lessons.ready(id,f,session)and not parked[id]then table.insert(out,id)end
	end
	return out
end
function Lessons.next(f,session)return Lessons.candidates(f,session)[1]end
-- Every lesson of the course done (graduation rule 1: this build's own list, TeachMarks.Course).
function Lessons.finished(f)
	for _,id in ipairs(Teach.Course)do if not Lessons.done(id,f)then return false end end
	return true
end
-- The ignore clock: has this pointer shown `shown` s on the same target untouched? (never for a lesson that is done)
function Lessons.ignored(shown)return(shown or 0)>=Lessons.Ignore end

-- ── The controller ─────────────────────────────────────────────────────────────────────────────────────────────────
-- deps: state(), mask(), teach() -> on, park() -> false without a Pet Park, clock(), pointer (TeachPointer),
--   text(key) -> words, target(id, f) -> GuiObject, step (the words key) or nil (where the lesson's button is now and
--   whether it may show: the gate, the screens), event(name), send(request) (the teachMark remote: "<id>", "park:<id>",
--   "done:finished", "done:skipped"), wipe() -> lesson A's wipe is playing, visit() -> the pet screen's opening number
function Lessons.new(deps)
	return setmetatable({d=deps,session={skipped={},asked={},parked={}},shown=nil,doneSent={},seenSent={},live=0,sent={}},Lessons)
end
function Lessons:teaching()return self.d.teach~=nil and self.d.teach()==true end
function Lessons:read()
	local d=self.d
	return Lessons.facts(d.state(),{teach=self:teaching(),mask=d.mask and d.mask(),park=d.park and d.park(),
		teachMask=self.live,wipe=d.wipe~=nil and d.wipe()==true,visit=d.visit and d.visit()})
end
function Lessons:current()return Lessons.next(self:read(),self.session)end
-- One request to the server, once a session (it ORs bits in, so a repeat would cost nothing anyway).
function Lessons:send(request)
	if self.sent[request]then return end
	self.sent[request]=true
	if self.d.send then pcall(self.d.send,request)end
end
-- Save a latch now: this session counts it at once, the server ORs it in. Teach off: nothing.
function Lessons:latch(id)
	if not self:teaching()or not Teach.validId(id)then return false end
	if Teach.has(self.live,id)then return false end
	self.live=Teach.with(self.live,id)
	self:send(id)
	return true
end
-- Settings > Skip the tips (graduation rule 2): the server saves `done`; this session stops at once.
function Lessons:skipAll()
	if not self:teaching()then return false end
	self.live=Teach.with(self.live,"done")
	self:send("done:skipped")
	self:hide()
	return true
end
function Lessons:graduated()return self:read().graduated==true end
-- "Later" on the Paint card: the pot is kept, the deck lesson comes next.
function Lessons:skip(id)self.session.skipped[id]=true end
-- A card asked for a lesson now ("What's next?" asks for the Menu). True when that lesson is not done (the card then
-- leaves the opening to the pointer).
function Lessons:ask(id)
	local f=self:read()
	if not f.on or f.graduated or Lessons.done(id,f)then return false end
	self.session.asked[id]=true
	self.session.parked[id]=nil
	return true
end
function Lessons:event(name,id)
	if self.d.event then pcall(self.d.event,name,id)end
end
function Lessons:hide()
	self.shown=nil
	if self.d.pointer then self.d.pointer:hide()end
end
function Lessons:step(now,dt)
	local f=self:read()
	-- the facts close lessons, whoever caused them
	for _,id in ipairs(Lessons.Order)do
		if f.on and Lessons.done(id,f)and self.seenSent[id]and not self.doneSent[id]then self.doneSent[id]=true;self:event("TeachDone",id)end
	end
	-- Stats learned in this pet screen visit: the Wardrobe waits for the next one.
	if f.on then
		local statsDone=Lessons.done("stats",f)
		if self.statsBefore==nil then self.statsBefore=statsDone
		elseif statsDone and not self.statsBefore and self.session.statsVisit==nil then self.session.statsVisit=f.visit end
	end
	-- graduation rule 1: every lesson of the course done
	if f.on and not f.graduated and Lessons.finished(f)then self:send("done:finished")end
	-- A save that saw its Paint card before this session: Dress up waits on the pet screen (it shows there whenever the
	-- screen opens) and the deck lesson may come first (brief: "Rejoins mid-lesson").
	if self.returned==nil and f.on then
		self.returned=f.paintSeen
		if self.returned then self.session.skipped.dress=true end
	end
	local id,target,words=nil,nil,nil
	for _,candidate in ipairs(Lessons.candidates(f,self.session))do
		local ok,t,w=pcall(self.d.target,candidate,f)
		if ok and t and w then id,target,words=candidate,t,w;break end
	end
	if not(id and target and words)then
		if self.shown then self:hide()end
		if self.d.pointer then self.d.pointer:step(dt or 0)end
		return nil
	end
	local s=self.shown
	if not s or s.id~=id or s.target~=target or s.words~=words then
		s={id=id,target=target,words=words,since=now}
		self.shown=s
		if not self.seenSent[id]then self.seenSent[id]=true;self:event("TeachShown",id)end
	end
	-- the reset lesson is show-only: saved once its ringed card has been on screen a moment (never asks for the tap)
	local showOnly=id=="reset"and words=="reset"
	if showOnly and now-s.since>=Lessons.ResetSeen then self:latch("reset")end
	if Lessons.ignored(now-s.since)and not showOnly then
		-- untouched: it fades, and this lesson waits for the next session (the third such session latches it)
		self.session.parked[id]=true
		if Teach.Parkable[id]~=nil then self:send("park:"..id)end
		self:hide()
		return nil
	end
	if self.d.pointer then
		local keys=Lessons.Keys[words]or {}
		self.d.pointer:show(target,self.d.text(Lessons.Words[words]or words),keys)
		self.d.pointer:step(dt or 0)
	end
	return id,words
end
return Lessons
