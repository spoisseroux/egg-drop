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
-- Rules: one pointer at a time; never beside a card or reveal; a lesson is done only by its saved fact, whoever caused
-- it, never by a timer. Ignored for Ignore s: the pointer fades and that lesson waits for the next session (parked).
-- Veterans and saves never owed the gift chain: nothing. Pure rules first (TeachLessons.spec), then the controller.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Coach=require(Shared:WaitForChild("CoachMarks"))
local Toys=require(Shared:WaitForChild("ToyCatalog"))
local Lessons={};Lessons.__index=Lessons
Lessons.Order=table.freeze({"dress","deck","menu","park","dash"})
Lessons.Ignore=12 -- s a pointer shows untouched before it fades (back once next session)
Lessons.Words=table.freeze({dress="teach.dress",paint="teach.paint",deck="teach.deck",menu="teach.menu",things="teach.things",
	throw="teach.throw",go="teach.go"})
-- Keyboard keys and gamepad glyphs the labels add (brief section 3).
Lessons.Keys=table.freeze({menu={key="M",glyph="Y"},things={glyph="A"},dress={glyph="R1"},paint={key="ENTER",glyph="A"},
	deck={glyph="A"},throw={key="F",glyph="R2"},go={key="ENTER",glyph="A"}})

-- ── Pure ────────────────────────────────────────────────────────────────────────────────────────────────────────────
local function painted(state)
	local hues=type(state.petHues)=="table"and state.petHues or {}
	for _,row in pairs(hues)do
		if type(row)=="table"then
			for _,channel in pairs(row)do
				if type(channel)=="table"then for _,n in pairs(channel)do if type(n)=="number"and n>0 then return true end end end
			end
		end
	end
	return false
end
Lessons.painted=painted
-- The facts from the owner snapshot. live = {teach, mask (this session's coach bits), park (false: no Pet Park here)}.
function Lessons.facts(state,live)
	state=if type(state)=="table"then state else {}
	live=live or {}
	local g=if type(state.gifts)=="table"then state.gifts else nil
	local granted=g and type(g.granted)=="table"and g.granted or {}
	local stats=if type(state.stats)=="table"then state.stats else {}
	local mask=Coach.merge(state.coachMask,live.mask)
	local dash=if type(state.dash)=="table"then state.dash else nil
	local raced=false
	for _,n in pairs(dash and type(dash.ribbons)=="table"and dash.ribbons or {})do if type(n)=="number"and n>0 then raced=true end end
	local unseen=g and type(g.unseen)=="table"and g.unseen or nil
	return{
		on=live.teach==true and g~=nil and g.owed==true,
		veteran=Coach.veteran(tonumber(state.totalWins)or 0),
		paintSeen=granted.paint==true and not(unseen and unseen.kind=="paint"),
		painted=painted(state),
		rounds=tonumber(stats.rounds)or 0,
		menuSeen=Coach.has(mask,"menuSeen"),
		toyDone=granted.toy==true or #Toys.remaining(state.toyUnlocks)==0,
		fetched=(tonumber(stats.fetches)or 0)>0,
		dashOn=dash~=nil,raced=raced,
		parkOn=live.park~=false,
	}
end
-- Each lesson's saved fact (ARCH-REVIEW-P2 1).
function Lessons.done(id,f)
	if id=="dress"then return f.painted==true end
	if id=="deck"then return(f.rounds or 0)>=1 end -- a field round played; the Welcome round is not counted
	if id=="menu"then return f.menuSeen==true end
	if id=="park"then return f.fetched==true end
	if id=="dash"then return f.raced==true end
	return true
end
-- Is the lesson's trigger true? session = {skipped = {[id] = true} ("Later"), asked = {[id] = true} (a card asked for it)}.
function Lessons.ready(id,f,session)
	session=session or {}
	local skipped=session.skipped or {}
	local asked=session.asked or {}
	if id=="dress"then return f.paintSeen==true end
	if id=="deck"then return Lessons.done("dress",f)or skipped.dress==true or asked.deck==true end
	if id=="menu"then return Lessons.done("deck",f)or asked.menu==true end
	if id=="park"then return f.parkOn~=false and f.toyDone==true end
	if id=="dash"then return f.fetched==true and f.dashOn==true end
	return false
end
-- The lessons that may light now, in order: ready, not done, not parked this session. The controller lights the first
-- whose button is on screen (one pointer at a time); `next` is the first of them.
function Lessons.candidates(f,session)
	local out={}
	if not f.on or f.veteran then return out end
	session=session or {}
	local parked=session.parked or {}
	for _,id in ipairs(Lessons.Order)do
		if not Lessons.done(id,f)and Lessons.ready(id,f,session)and not parked[id]then table.insert(out,id)end
	end
	return out
end
function Lessons.next(f,session)return Lessons.candidates(f,session)[1]end
-- The ignore clock: has this pointer shown `shown` s on the same target untouched? (never for a lesson that is done)
function Lessons.ignored(shown)return(shown or 0)>=Lessons.Ignore end

-- ── The controller ─────────────────────────────────────────────────────────────────────────────────────────────────
-- deps: state(), mask(), teach() -> on, park() -> false without a Pet Park, clock(), pointer (TeachPointer),
--   text(key) -> words, target(id) -> GuiObject, step (the words key) or nil (where the lesson's button is now and
--   whether it may show: the gate, the screens), event(name)
function Lessons.new(deps)
	return setmetatable({d=deps,session={skipped={},asked={},parked={}},shown=nil,doneSent={},seenSent={}},Lessons)
end
function Lessons:read()
	return Lessons.facts(self.d.state(),{teach=self.d.teach and self.d.teach()==true,mask=self.d.mask and self.d.mask(),park=self.d.park and self.d.park()})
end
function Lessons:current()return Lessons.next(self:read(),self.session)end
-- "Later" on the Paint card: the pot is kept, the deck lesson comes next.
function Lessons:skip(id)self.session.skipped[id]=true end
-- A card asked for a lesson now ("What's next?" asks for the Menu). True when that lesson is not done (the card then
-- leaves the opening to the pointer).
function Lessons:ask(id)
	local f=self:read()
	if not f.on or f.veteran or Lessons.done(id,f)then return false end
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
	if Lessons.ignored(now-s.since)then
		-- untouched: it fades, and this lesson waits for the next session
		self.session.parked[id]=true
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
