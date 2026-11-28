-- The lead to the nest, the client's half (onboarding v3 brief section 1, Onboard "lead"; BearNeeds runs it while the
-- nest prompt is open). The server moves the pet (GardenState:lead, so every player sees it lead); this decides when to
-- ask, the words, the nudges, the park and the celebration. Rules in Shared.PetLead (spec-checked offline).
--   2a "Follow {pet}!"  the pet leads; the player within PetLead.Reach of the nest's prompt closes it at once
--   2b "Tuck the egg in!"  the bubble sits on the nest; the egg tucked in closes it (BearNeeds' saved fact)
-- Edge cases, none of which blocks or ever closes a prompt by itself:
--   still 8 s or over 30 studs away  a nudge: the pet runs back ("back"), "This way!" for 2 s; the 4th parks it
--   parked        the pet follows again; a moon chip over it (tap: lead again); the trail stays lit; BearNeeds shows
--                 the next prompt and brings this one back after the deck next closes
--   paused        anything ThingsTips.blocked names (the deck, a menu, leaving the garden): the lead stops; it starts
--                 again when the prompt shows (BearNeeds waits 2.5 s free)
--   no pet out    no leader: 2b's bubble on the nest, today's trail from the player
--   refused       a start the server never took (no route, a fence on it, a swap): asked again with a backoff; after
--                 Restart.tries the nest prompt goes on without a leader (2b on the nest, the trail from the player)
--   lost          the server poofed the pet to the player off the route: a new route from where it stands
-- deps: send(kind, payload) (the petLead remote), plan(from, to, done(points)) (the trail route; may yield), actor() (my
--   garden actor snapshot), serverNow(), pet() -> position, model (the drawn pet, or nil), root(), nest() (the prompt
--   point), trail (LeadTrail), targetName(), beckon() (chirp and paw wave), hop() (the bubble), chirp(), event(name),
--   celebrate() (hearts and the settle buzz), toast(key, vars), hatchLeft() -> seconds to the hatch or nil (the tuck's
--   countdown words, PetLead.hatchWords), keepOut() -> the lead's keep-out circles (GardenKeepOut.lead; nil: none),
--   segmentOk(a, b) (optional: a detour's legs stay dry), solidOk(a, b) (optional, beta 41 review: nothing solid on a
--   detour's legs: the server's own sweep, Lead.Cast).
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Lead=require(Shared:WaitForChild("PetLead"))
local NestLead={};NestLead.__index=NestLead
NestLead.TrailEvery=3 -- s between two looks at a trail that went out

function NestLead.new(deps)
	return setmetatable({d=deps,w=Lead.watcher(),gen=0,failures=0,retryAt=-math.huge,seenSeq=0,trailAt=-math.huge},NestLead)
end
local function call(fn,...)if fn then local ok,a,b=pcall(fn,...);if ok then return a,b end end;return nil end

-- The lead the server holds for this pet now, or nil.
function NestLead:serverLead()
	local actor=call(self.d.actor)
	local lead=type(actor)=="table"and actor.lead or nil
	if type(lead)=="table"and type(lead.seq)=="number"then
		if lead.seq>self.seenSeq then self.seenSeq=lead.seq end
		return lead,actor
	end
	return nil,actor
end
function NestLead:send(kind,payload)
	local body=payload or {}
	body.kind=kind
	call(self.d.send,kind,body)
end
-- Ask the server to lead: the route first (it may yield), then the start.
function NestLead:start(now,from,nest)
	self.gen+=1
	local mine=self.gen
	self.planning=true
	self.paused=false
	local function done(points)
		if self.gen~=mine then return end
		self.planning=false
		-- the trail's raw route thinned and re-spaced to the server's caps (Lead.fit: bridge ends kept)
		local raw=if type(points)=="table"then points else nil
		if raw then points=Lead.fit(raw)end
		if type(points)~="table"or #points<2 then self:failed(self.now or now);return end
		-- beta (40) ("the pet runs thru meshes"): round the bushes, reeds and props the navmesh cannot see; a route
		-- that cannot be cleared goes as it is (the server checks it and refuses one through a keep-out)
		local keepOut=call(self.d.keepOut)
		if type(keepOut)=="table"and #keepOut>0 then
			-- beta 41 review: a detour keeps dry and clear of solids (another side, a larger push, then fit's cut corners)
			local cleared=Lead.around(points,keepOut,NestLead.legOk(self.d.segmentOk,self.d.solidOk),raw)
			if cleared then points=cleared end
		end
		self.askedAbove=self.seenSeq
		self:send("start",{route=points})
		self.leading,self.acked,self.sentAt=true,false,self.now or now
		self.trailAt=-math.huge
	end
	if self.d.plan then
		local ok=pcall(self.d.plan,from,nest,done)
		if not ok then done(nil)end
	else done({from,nest})end
end
-- Pure: one leg check from the dry check and the solid check (either may be missing; neither: nil, no check).
function NestLead.legOk(dry,solid)
	if dry==nil and solid==nil then return nil end
	return function(a,b)
		if dry and not dry(a,b)then return false end
		if solid and not solid(a,b)then return false end
		return true
	end
end
function NestLead:failed(now)
	-- whatever the server still holds (a lost lead waiting by the player) ends: it follows meanwhile
	if self.leading then self:send("stop")end
	self.leading,self.acked,self.planning=false,false,false
	self.failures+=1
	self.retryAt=now+math.min(Lead.Restart.max,Lead.Restart.backoff*self.failures)
	if self.failures>=Lead.Restart.tries then self.leaderless=true end
end
function NestLead:stopLead()
	self.gen+=1
	self.planning=false
	if self.leading then self:send("stop")end
	self.leading,self.acked=false,false
	self.holdAt,self.sawBack=nil,nil
	if self.d.trail then self.d.trail:stop()end
	self.trailAt=-math.huge
end
-- A nudge's run back (glow steps, trail:leadHold): no new prints from the send until the server's "back" is over
-- (or never came, after Restart.wait).
function NestLead:holdTrail(on,now)
	local trail=self.d.trail
	if on then self.holdAt,self.sawBack=now,false else self.holdAt,self.sawBack=nil,nil end
	if trail and trail.hold then trail:hold(on)end
end
function NestLead:stepHold(now,phase)
	if not self.holdAt then return end
	if phase=="back"then self.sawBack=true;return end
	if self.sawBack or now-self.holdAt>=Lead.Restart.wait then self:holdTrail(false,now)end
end
-- Hidden by something that pauses it (the deck, a menu, leaving the garden): the lead stops; it starts again when shown.
function NestLead:pause()
	if self.reached or self.done then return end
	if self.leading or self.planning then self:stopLead()end
	self.paused=true
	self.w.still=0
	self.retryAt=-math.huge
end
function NestLead:park(now)
	self:stopLead()
	self.parked=true
	call(self.d.event,"LeadParked")
	self.trailAt=-math.huge
end
-- The chip was tapped (or the deck closed after a park): it leads again from the start.
function NestLead:unpark()
	if not self.parked then return false end
	self.parked=false
	self.w=Lead.watcher()
	self.failures,self.leaderless,self.retryAt=0,false,-math.huge
	return true
end
-- The prompt closed: tucked (the celebration) or done another way.
function NestLead:finish(tucked)
	if self.done then return end
	self.done=true
	self.parked=false
	self.gen+=1
	local wasLeading=self.leading
	self.leading,self.planning=false,false
	self.holdAt,self.sawBack=nil,nil
	if self.d.trail then self.d.trail:stop()end
	if tucked then
		self:send("cheer")
		call(self.d.celebrate)
		call(self.d.toast,Lead.hatchWords("toast",call(self.d.hatchLeft)))
	elseif wasLeading then self:send("stop")end
end
-- The parked prints: today's trail from the player to the nest, laid again when it goes out.
function NestLead:keepTrail(now,nest)
	local trail=self.d.trail
	if not trail or not nest or now<self.trailAt then return end
	if not trail:active()then
		self.trailAt=now+NestLead.TrailEvery
		trail:show({position=nest,name=call(self.d.targetName)})
	end
end
-- One frame while the nest prompt is open. ctx: {shown (the bubble shows now), blocked (ThingsTips' reason, or nil)}.
-- Returns the view: {stage = "follow" | "tuck" | "parked", on = "pet" | "nest", head, sub (UICopy keys), icon}.
function NestLead:step(now,dt,ctx)
	ctx=ctx or {}
	local d=self.d
	self.now=now
	self.begun=true -- the prompt has been open this session (its close is celebrated)
	local root,nest=call(d.root),call(d.nest)
	local petAt,model=call(d.pet)
	if typeof(petAt)~="Vector3"then petAt,model=nil,nil end
	-- 2a closes the moment the player is near the nest, whoever got there first
	if not self.reached and typeof(root)=="Vector3"and typeof(nest)=="Vector3"and Lead.flat(root,nest)<=Lead.Reach then
		self.reached=true
		call(d.event,"NestReached")
		-- arrived: the pet's prints end with the trail (trail:leadBy(nil) and stop); 2b shows on the nest
		self.holdAt,self.sawBack=nil,nil
		if d.trail then d.trail:stop()end
		-- a lead the server has not taken (planning, or sent and unanswered) or one lost by the player (waiting there
		-- for a route that never comes now) ends: the pet follows. One that runs or waits on its route arrives by itself.
		local held=self:serverLead()
		if self.planning or(self.leading and(not self.acked or(held and held.lost)))then
			self.gen+=1;self.planning=false
			if self.leading then self:send("stop")end
			self.leading,self.acked=false,false
		end
	end
	local speed=0
	if typeof(root)=="Vector3"and typeof(self.lastRoot)=="Vector3"and(dt or 0)>0 then speed=Lead.flat(root,self.lastRoot)/dt end
	self.lastRoot=root
	if ctx.blocked~=nil then self:pause();return nil end
	if self.parked then
		self:keepTrail(now,nest)
		return {stage="parked",on="pet",icon="moon"}
	end
	local P=Lead.Prompts
	if self.reached or not petAt or self.leaderless then
		-- 2b on the nest; no leader (stowed, refused): today's trail from the player
		if self.leading and not petAt then self:stopLead()end
		if not self.reached and not self.leading then self:keepTrail(now,nest)end
		-- beta (40): the sub-line counts down to the hatch ("It hatches in 7 h"), never "tomorrow"
		local sub,subVars=Lead.hatchWords("sub",call(d.hatchLeft))
		return {stage="tuck",on="nest",head=P.tuck.head,sub=sub,subVars=subVars,icon=P.tuck.icon}
	end
	-- 2a: the pet leads
	local lead,actor=self:serverLead()
	if self.leading then
		if lead and lead.seq>(self.askedAbove or 0)then
			-- taken: the chirp, as it hops twice and turns to the nest (every screen draws the hops)
			if not self.acked then self.acked=true;self.failures=0;call(d.chirp)end
			-- poofed to the player off its route: a new route from where it stands
			if lead.lost and not self.planning then self:start(now,petAt,nest)end
		elseif self.acked or(self.sentAt and now-self.sentAt>=Lead.Restart.wait)then
			-- the server never took it, or ended it (care, a race, a swap, the owner far): ask again after a backoff
			self:failed(now)
		end
	end
	if not self.leading and not self.planning and now>=self.retryAt and typeof(nest)=="Vector3"then self:start(now,petAt,nest)end
	if self.leading and self.acked and lead then
		self:stepHold(now,lead.phase)
		local trail=d.trail
		if trail and now>=self.trailAt and not trail:active()then
			self.trailAt=now+NestLead.TrailEvery
			trail:lead(model,{position=nest,name=call(d.targetName)})
		end
		-- the look back: a chirp, the paw wave and the bubble's hop every Beckon.every s, in step with every screen's hop
		local waiting=lead.phase=="wait"and type(actor)=="table"and actor.action=="leadWait"
		if waiting then
			local serverNow=call(d.serverNow)or now
			local age=if type(actor.startTime)=="number"then serverNow-actor.startTime else 0
			if self.beckonFor~=actor.actionId then self.beckonFor,self.beckonBeat=actor.actionId,nil end
			local due,beat=Lead.beckonDue(age,self.beckonBeat)
			if due then self.beckonBeat=beat;call(d.beckon);call(d.hop)end
		end
		local event=Lead.watch(self.w,{now=now,dt=dt,active=lead.phase=="run"or lead.phase=="pace"or lead.phase=="wait",speed=speed,
			gap=if typeof(root)=="Vector3"then Lead.flat(root,petAt)else 0,toNest=if typeof(root)=="Vector3"then Lead.flat(root,nest)else nil})
		if event=="nudge"then
			self:send("back")
			self:holdTrail(true,now)
			call(d.hop);call(d.chirp)
		elseif event=="park"then
			self:park(now)
			return {stage="parked",on="pet",icon="moon"}
		end
	end
	local head=if Lead.thisWay(self.w,now)then Lead.ThisWayCopy else P.follow.head
	return {stage="follow",on="pet",head=head,sub=P.follow.sub,icon=P.follow.icon}
end
return NestLead
