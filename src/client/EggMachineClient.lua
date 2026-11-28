-- The egg machine, the client (EGG-CORNER-LOOK section 2; EGG-CORNER-BUILD-PLAN section 7). Presentation only: the
-- server placed the machine (EggCornerWorld) and never moves its parts again; this animates them locally from their
-- WorldRestCFrame attributes, plays the sounds and holds the hatch reveal for the buy crank. Nothing is sent or saved.
--   idle   the sprout sways 4 degrees at .35 Hz, six loose eggs rock 3 degrees about their base, one settles every 9 to
--          14 s with a soft knock (within 14 studs); the body never moves
--   hello  coming within 10 studs: the dial nudges 15 degrees and springs back (.4 s), one click; re-armed past 12, 20 s apart
--   open   `Turn`: a quarter turn (.28 s, overshoot 6), clicks at 0 / 90 / 180 ms, the loose eggs hop at .1; the screen
--          opens at .3 (init); a second press inside a running crank is ignored
--   buy    a press (before the remote) only arms the crank; it turns when the buy is confirmed: the reveal it started
--          begins (HatchCinematic.onPlay), or for the Stat Egg (its own reveal) its Saved answer (confirm()). A press
--          the server refuses (Studio check R8: Hatch another on a Toy result came back "This toy was not changed")
--          turns nothing and never counts toward a streak: it gets the hello nudge and one click (Fable R8), as soon
--          as the press is known refused (deps.rejected(action), or refuse() from the Stat Egg's answer). Then a full turn and 5 clicks (.6 s), clunk, the bought
--          colour's egg comes out of the belly under the leaf chute (beta 34: it never touches the leaf,
--          EggCorner.dropPoints) and lands in the cup .85 after the confirmation with the landing thud
--          (once). Hatch another within 20 s of the last landing: a half turn (.45 s, 3 clicks), then a quarter (.25 s,
--          1 click). A press while a buy crank runs merges into it; a retried send of the same action never arms another.
--   hold   HatchCinematic.gate holds the clock of the reveal that confirmed the buy until the egg lands, at most 1 s
--          after the confirmation (the hold starts with the crank); a skip is refused meanwhile. Beta (34): the Stat
--          Egg's reveal is held the same way (StatEggReveal.gate, owned by the reveal init passes to confirm).
--          Reduced Motion: the reveal shows its static card at once (the cinematic never asks the hold); the crank,
--          its sounds and the egg still play.
-- Sounds play flat with the screen (Fable R2 F6); the world motion only within Range of the camera. The old station's
-- Aero dome and lip go see-through (LocalTransparencyModifier) while the corner is on.
-- Beta (16) B1 (the crank never showed on the real server): the model is found by name in the lounge or by its tag
--   (EggCornerMachine), and a bind is only kept once it is whole (Body, Dial and the DialPivot attachment): a model seen
--   before its parts or attachments replicated (streaming, a late replication) used to be cached half empty forever, so
--   nothing moved. It retries every BindRetry seconds; after WarnAfter seconds on without a whole model it warns once with
--   the reason, and a Turn pressed meanwhile warns once too. A step error warns once per message, not every frame. The
--   range check measures from the Body, not the model's pivot.
-- The capsule shot (beta 17 U5; artifacts/qa-2026-11-25-beta17/CAPSULE-AND-HUD-LOOK.md 1), behind deps.capsule() (the
--   onboarding v3 part `capsule`): on the confirmation the Hatch eggs panel tucks away, the camera looks at the machine
--   (Shot A, then the cup, Shot B), the dial turns, the egg rolls .40 s into the cup with the landing thud, a .4 s beat,
--   and the panel rises with the reveal, whose clock starts only then (2.0 s; Hatch another 1.30 s then .95 s; a hard
--   cap .2 s after). Beta (34): the Stat Egg too (it used to cut straight to its hatch). Bought away from the machine
--   (not bound whole, more than 24 studs off, or both line checks blocked): the pocket version (the panel stays up, the
--   preview egg slips out and the bought egg drops in, the reveal at 1.0 s). Reduced Motion: no tuck, no camera; the 3rd-in-a-row sounds and the reveal's static card
--   on the thud (.62 s). A tap / click / A / Space / Enter during the shot jumps to the landing (never the first drop of
--   an egg type). The camera stays at Shot B while the reveal is up and is always given back (the screen closing,
--   respawn, the model unbinding, the corner or capsule off, destroy). Off: the crank and 1 s hold as before.
-- deps (capsule): capsule() -> bool, cameraObject() -> Camera, hud(visible), ghost(alpha) (this player's character
--   see-through), blocked(from, to) -> bool (world geometry between), pocket(kind) (the preview well's drop),
--   stageHold(amount) (Studio R15: every reveal stage slides by the panel's tuck, HatchItemStage.holdAll), againPending()
--   (Hatch another is waiting: the camera stays at Shot B through the gap).
-- deps: room() -> the lounge or nil, root() -> Vector3?, camera() -> Vector3?, reduced(), audio {play(name, speed,
--   volume)}, haptic(strength) (optional), corner() (the switch), clock (default os.clock), random (default Random.new()),
--   cinematic (the HatchCinematic module; default required), statReveal (the StatEggReveal module, optional: its
--   reveal's gate and skip), step=false (specs call :step).
-- Beta (35), the one path (Spencer: "we need all eggs to have the crank animation, even in the future for eggs"): every
--   egg's reveal is handed to Machine:deliver(kind, open, owner) (EggCorner.Eggs lists the types and how each reveal
--   waits). The crank turns, the egg comes out of the hole and lands in the cup, and only then does the reveal show:
--   a deferred reveal (the Stat Egg, its own module) is not opened at all until Machine.openTime (open() runs then);
--   a cinematic reveal (HatchCinematic.onPlay -> claim -> deliver) is held and kept off the screen until the same time
--   (the panel's tuck at the machine; covering stages slid away in the pocket and Reduced Motion versions). A grant or
--   a late answer with no armed press still plays the machine. The Stat Egg's own root cause (beta 35 1): its reveal's
--   ScreenGui is not under the tucked panel and its stage is not a covering one, so only its clock was held while its
--   UI showed over the whole shot.
-- Beta (35) 4: the egg that comes out is the real egg (EggModels TopShell and BottomShell in the bought type's
--   colorMap, deps.shells), the plain coloured DropEgg only while they load. Beta (35) 3: with the leafless Body the
--   egg comes out of a round hole (EggHole: a dark disc and a rim, EggCorner.hole) instead of from under the leaf.
--   After beta 36 the Body bakes that hole as a real mouth (data.mouth): the egg starts in its dark cavity and the
--   client draws nothing there.
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Corner=require(Shared:WaitForChild("EggCorner"))
local Models=require(Shared:WaitForChild("EggModels"))
local Machine={};Machine.__index=Machine
Machine.Range=60
Machine.Hello=table.freeze({near=10,rearm=12,every=20,angle=15,seconds=.4})
Machine.Settle=table.freeze({min=9,max=14,slip={.15,.3},seconds=.5,back=1,range=14})
Machine.Sway=table.freeze({angle=4,hz=.35})
Machine.Rock=table.freeze({angle=3,hz={.2,.3}})
Machine.Open=table.freeze({turn=90,seconds=.28,overshoot=6,clicks=table.freeze({0,.09,.18}),hopAt=.1,hop=.12,hopSeconds=.3,openAt=.3})
Machine.Turns=table.freeze({
	table.freeze({turn=360,seconds=.6,clicks=table.freeze({0,.11,.22,.33,.44})}),
	table.freeze({turn=180,seconds=.45,clicks=table.freeze({0,.15,.3})}),
	table.freeze({turn=90,seconds=.25,clicks=table.freeze({0})}),
})
Machine.RollDelay=.02   -- after the clunk
Machine.RollSeconds=.23 -- down the chute to the cup
Machine.SpringBack=8
Machine.Cap=1           -- the hold never outlasts this, from the first press
Machine.StreakWindow=20 -- Hatch another: a buy this soon after the last landing
Machine.FadeAfter=1.5   -- the egg in the cup fades this long after the reveal ends (or at Linger)
Machine.Linger=6
Machine.Tag="EggCornerMachine"
Machine.BindRetry=.5
Machine.WarnAfter=10
-- Reveals that are not the cinematic (EggCorner.Eggs reveal "deferred"): handed over by deliver with their answer.
Machine.Unclaimed=(function()
	local out={}
	for _,row in pairs(Corner.Eggs)do if row.reveal=="deferred"then out[row.drop]=true end end
	return table.freeze(out)
end)()
Machine.ConfirmWindow=3 -- an armed press with no confirmation this long after it lapses (no turn, no streak)
-- Volumes (from Fable's dB): -16 .16, -20 .1, -24 .063, -26 .05.
Machine.Volume=table.freeze({click=.1,clunk=.16,roll=.1,tok=.05,tokCrank=.063,hello=.063,land=.5,tuck=.08,rise=.063,shine=.08})
-- The capsule shot's schedules (LOOK 1), t = 0 at the confirmation. `start` is when the reveal's clock starts.
local function clicks(from,seconds,count)
	local out={}
	for i=0,count-1 do table.insert(out,from+seconds*i/count)end
	return table.freeze(out)
end
Machine.Shots=table.freeze({
	first=table.freeze({mode="shot",turn=360,turnFrom=.30,seconds=.6,clicks=clicks(.30,.6,5),clunk=.90,roll=.95,rollSeconds=.40,land=1.35,
		shine=1.50,start=2.00,tuck=.18,rise=1.75,riseSeconds=.25,camA=0,camASeconds=.30,camB=.90,camBSeconds=.40}),
	second=table.freeze({mode="shot",turn=180,turnFrom=.10,seconds=.45,clicks=clicks(.10,.45,3),clunk=.55,roll=.57,rollSeconds=.30,land=.87,
		start=1.30,tuck=.15,rise=1.07,riseSeconds=.23,camB=0,camBSeconds=.30}),
	third=table.freeze({mode="shot",turn=90,turnFrom=.10,seconds=.25,clicks=clicks(.10,.25,1),clunk=.35,roll=.37,rollSeconds=.25,land=.62,
		start=.95,tuck=.15,rise=.75,riseSeconds=.20,camB=0,camBSeconds=.30}),
	pocket=table.freeze({mode="pocket",turn=180,turnFrom=0,seconds=.45,clicks=table.freeze({0,.15,.30}),clunk=.45,roll=.47,rollSeconds=.28,
		land=.75,start=1.00}),
	reduced=table.freeze({mode="reduced",turn=90,turnFrom=.10,seconds=.25,clicks=clicks(.10,.25,1),clunk=.35,roll=.37,rollSeconds=.25,
		land=.62,start=.62}),
})
Machine.ShotCap=.2       -- the reveal starts at the latest this long after its schedule's start
-- Code review B35: a Stat Egg shot whose reveal never opened (a Saved answer without a receipt, a reveal that threw)
-- gives the camera back this long after its schedule's start, so nothing is left Scriptable at Shot B.
Machine.StatWatch=3
-- Pure (beta 40 note 4): is a shot's owner open? None (an owner-less shot): no. One with isOpen: its answer. Any other
-- owner (the item cinematic) owns its return through the hatch screen's close: counted open, never watched here; a
-- deferred reveal's owner (the Stat Egg's) that cannot say is not open (code review B35, as before).
function Machine.ownerOpen(owner,deferred)
	if owner==nil then return false end
	if type(owner)=="table"and type(owner.isOpen)=="function"then
		local ok,value=pcall(owner.isOpen,owner)
		return ok and value==true
	end
	return deferred~=true
end
-- Pure: does the watch give the camera back? Only when the owner is not open and never was, no hatch screen is up and
-- no Hatch another gap is waiting.
function Machine.watchReturns(w)
	return w.open~=true and w.seenOpen~=true and w.screen~=true and w.gap~=true
end
Machine.PocketRange=24   -- farther than this from the machine: the pocket version
Machine.ReturnSeconds=.30
-- The two shots in the machine's frame (+Z the front, +X the cup's side, up from the ground): camera at, looks at.
-- Fable R13 (FABLE-REVIEW-R13 3, 4): Shot A closer, lower and the dial left of centre (the machine about 62% of the
-- frame height); Shot B lower and closer, so the cup is about 17% of a 16:9 frame (14% on a 19.5:9 phone) and the
-- runner edge-on. The field of view stays the player's (the cup clears 14% on 16:9 without the FOV 58 fallback).
Machine.ShotA=table.freeze({at=Vector3.new(1.8,4.0,8.0),look=Vector3.new(-.4,3.4,1.9)})
Machine.ShotB=table.freeze({at=Vector3.new(2.3,1.8,4.4),look=Vector3.new(1.0,.9,1.7)})

-- ── Pure ─────────────────────────────────────────────────────────────────────────────────────────────────────────
-- The buy crank for a streak (1, 2, 3 or more): turn (degrees), seconds, clicks, clunk, roll and landing times.
function Machine.schedule(streak)
	local row=Machine.Turns[math.clamp(math.floor(tonumber(streak)or 1),1,3)]
	local clunk=row.seconds
	return{turn=row.turn,seconds=row.seconds,clicks=row.clicks,clunk=clunk,roll=clunk+Machine.RollDelay,
		land=clunk+Machine.RollDelay+Machine.RollSeconds}
end
-- The capsule schedule for a mode ("shot", "pocket", "reduced") and a streak (1, 2, 3+).
function Machine.shotSchedule(mode,streak)
	if mode=="pocket"then return Machine.Shots.pocket end
	if mode=="reduced"then return Machine.Shots.reduced end
	local n=math.clamp(math.floor(tonumber(streak)or 1),1,3)
	return if n==1 then Machine.Shots.first elseif n==2 then Machine.Shots.second else Machine.Shots.third
end
-- The hand-off (beta 35): seconds after the confirmation when an egg's reveal may show. Never before the egg is in the
-- cup (land); at the machine, when the panel rises (rise); else when the reveal's clock starts (start).
function Machine.openTime(sched)
	return math.max(sched.land,sched.rise or sched.start or sched.land)
end
-- The machine's name for an egg: "Stat" from "stat", "Stat" or "statEggBuy"; a type it does not know keeps its own
-- name with a capital (a future egg still comes out, in white until its colour is added).
function Machine.dropName(kind)
	if type(kind)~="string"or kind==""then return "Toy"end
	if Corner.BuyActions[kind]then return Corner.BuyActions[kind]end
	local row=Corner.eggRow(kind)
	if row then return row.drop end
	return string.upper(string.sub(kind,1,1))..string.sub(kind,2)
end
-- The real egg (beta 35 4): the two shell meshes' frames and sizes for an upright egg `height` tall centred at `at`
-- (EggModels.Egg: the egg stands on its origin; the core is never shown).
function Machine.shellPose(at,height)
	local E=Models.Egg
	local full=E.TopShell.center.Y+E.TopShell.size.Y/2
	local k=height/full
	local base=at*CFrame.new(0,-height/2,0)
	return{TopShell={cframe=base*CFrame.new(E.TopShell.center*k),size=E.TopShell.size*k},
		BottomShell={cframe=base*CFrame.new(E.BottomShell.center*k),size=E.BottomShell.size*k}},k
end
-- The hole's look (beta 35 3; Fable to tune): a dark disc just proud of the belly and a rim in the base's band colour
-- riding the opening's edge, in Segments pieces.
Machine.HoleLook=table.freeze({disc=Color3.fromHex("#2A211B"),rim=Color3.fromHex("#D2BE94"),segments=20,lift=.006,thick=.02})
-- Pure: the hole's pieces, machine-local: {name, size, cframe, color, cylinder}. A Cylinder's axis is its X.
function Machine.holeParts(hole)
	local look=Machine.HoleLook
	local n=hole.normal
	local u=n:Cross(Vector3.new(0,1,0)).Unit
	local v=u:Cross(n).Unit
	local ring=hole.radius+hole.rim
	local out={{name="Disc",cylinder=true,color=look.disc,size=Vector3.new(look.thick,ring*2,ring*2),
		cframe=CFrame.fromMatrix(hole.centre+n*look.lift,n,v)}}
	local count=look.segments
	for i=1,count do
		local a0,a1=(i-1)/count*2*math.pi,i/count*2*math.pi
		local p0=hole.centre+(u*math.cos(a0)+v*math.sin(a0))*ring+n*look.lift
		local p1=hole.centre+(u*math.cos(a1)+v*math.sin(a1))*ring+n*look.lift
		local along=(p1-p0)
		table.insert(out,{name="Rim"..i,cylinder=true,color=look.rim,size=Vector3.new(along.Magnitude+hole.rim*.6,hole.rim*2,hole.rim*2),
			cframe=CFrame.fromMatrix((p0+p1)/2,along.Unit,n)})
	end
	return out
end
-- The streak a press at `now` starts: one more than the last when the last egg landed within StreakWindow.
function Machine.streak(last,lastLand,now)
	if type(last)=="number"and type(lastLand)=="number"and now-lastLand<=Machine.StreakWindow then return last+1 end
	return 1
end
local function easeOut(x)return 1-(1-x)^3 end
-- The open crank's dial angle at t: ease-out to 90 with a 6 degree overshoot, settling back by .4 s.
function Machine.openAngle(t)
	local o=Machine.Open
	if t<=0 then return 0 end
	if t<o.seconds then return(o.turn+o.overshoot)*easeOut(t/o.seconds)end
	local back=math.clamp((t-o.seconds)/.12,0,1)
	return o.turn+o.overshoot*(1-back)
end
-- The buy crank's dial angle at t: even speed with a little resistance in the first 60 ms, then the 8 degree
-- spring-back after the clunk (out and home over .15 s).
function Machine.buyAngle(sched,t)
	if t<=0 then return 0 end
	if t<sched.seconds then
		local slow=.06
		local x=if t<slow then .5*t*t/slow else t-.5*slow
		return sched.turn*x/(sched.seconds-.5*slow)
	end
	local s=t-sched.seconds
	if s<.15 then return sched.turn-Machine.SpringBack*math.sin(s/.15*math.pi)end
	return sched.turn
end
-- Where the dropped egg is at t seconds into its roll (0 .. RollSeconds): a, b, c are the ChuteTop, ChuteEnd and CupSeat
-- attachments (beta 34: EggCorner.dropPoints, out of the belly under the leaf): out of the belly the first 60% of the
-- time, over the cup's back lip into its seat the rest. RollHop lifts that last part (it was .12 off the leaf's tip;
-- under the leaf there is no room: a hop of .12 put the egg .11 into the leaf).
Machine.RollHop=0
function Machine.rollAt(a,b,c,t,seconds)
	local p=math.clamp(t/(seconds or Machine.RollSeconds),0,1)
	if p<.6 then
		local q=p/.6
		return a:Lerp(b,q*q)
	end
	local q=(p-.6)/.4
	return b:Lerp(c,q)+Vector3.new(0,Machine.RollHop*math.sin(q*math.pi),0)
end

-- ── Instance ─────────────────────────────────────────────────────────────────────────────────────────────────────
function Machine.new(deps)
	local self=setmetatable({d=deps,clock=deps.clock or os.clock,random=deps.random or Random.new(),seen={},seenOrder={},t=0,
		parts=nil,settleAt=nil,helloArmed=true,helloAt=-math.huge,aeroAt=0},Machine)
	local cinematic=deps.cinematic
	if cinematic==nil then
		local ok,module=pcall(require,script.Parent:WaitForChild("HatchCinematic"))
		cinematic=if ok then module else false
	end
	self.cinematic=cinematic or nil
	if self.cinematic then
		self.cinematic.gate=function(c)return self:holds(c)end
		self.cinematic.onPlay=function(c)self:claim(c)end
		-- A skip pressed on the held reveal: the capsule shot jumps to the landing (LOOK 1, Skip).
		self.cinematic.onGateSkip=function()self:skipShot()end
	end
	-- Beta (34) "the stats egg cuts straight to the hatching": the Stat Egg's reveal (StatEggReveal, its own module) is
	-- held the same way, by its instance (init passes it to confirm with the Saved answer).
	self.statReveal=deps.statReveal or nil
	if self.statReveal then
		self.statReveal.gate=function(r)return self:holds(r)end
		self.statReveal.onGateSkip=function()self:skipShot()end
	end
	if deps.step~=false then
		self.heartbeat=RunService.Heartbeat:Connect(function(dt)
			local ok,problem=pcall(self.step,self,dt)
			if not ok then self:warnOnce("step: "..tostring(problem))end
		end)
	end
	return self
end
function Machine:on()return self.d.corner==nil or self.d.corner()==true end
function Machine:reduced()return self.d.reduced~=nil and self.d.reduced()==true end
function Machine:play(name,volume,speed)
	local audio=self.d.audio
	if audio then pcall(audio.play,audio,name,speed or 1,volume or .1)end
end
function Machine:buzz(strength)
	if self.d.haptic then pcall(self.d.haptic,strength or "light")end
end

-- The open crank (the `Turn` prompt). False only while an open crank runs or a buy crank has not landed yet (review
-- 1: a landed buy's egg lingering in the cup never blocks Turn; it goes when the new crank starts). init opens the
-- screen at once when this refuses, so a press is never eaten.
function Machine:busy()
	local crank=self.crank
	if not crank or crank.done then return false end
	if crank.kind=="open"then return true end
	return not crank.landed
end
function Machine:openCrank()
	if not self:on()or self:busy()then return false end
	pcall(self.bind,self)
	-- B1: a Turn with nothing to turn says why, once.
	local why=(self.parts==nil)and(self.bindReason or "not bound yet")or nil
	if why then self:warnOnce("Turn pressed, but the machine cannot move: "..why)end
	if self.crank and not self.crank.done then self:finish(self.crank)end
	self.crank={kind="open",at=self.clock(),fired={}}
	return true
end
-- A buy was pressed (`action` from EggCorner.BuyActions, `id` the action's own id, so a retried send is the same press).
-- True when it started a crank; false for a retry, a merge, an unknown action or the corner off.
function Machine:bought(action,id)
	local kind=Corner.BuyActions[action]
	if not kind or not self:on()then return false end
	if id~=nil then
		if self.seen[id]then return false end
		self.seen[id]=true
		table.insert(self.seenOrder,id)
		if #self.seenOrder>32 then self.seen[table.remove(self.seenOrder,1)]=nil end
	end
	local now=self.clock()
	local crank=self.crank
	if crank and crank.kind=="buy"and not crank.landed and now-crank.at<Machine.Cap then return false end -- merged
	if self:shotActive()then return false end -- a press during the capsule shot merges into it (never two cranks)
	-- A newer press replaces an armed one that was never confirmed (a refused buy leaves nothing behind).
	self.armed={at=now,type=kind,action=action,unclaimed=Machine.Unclaimed[kind]==true}
	return true
end
-- The armed press is confirmed (its reveal started, or the Stat Egg's Saved answer): the crank turns now. `cinematic`
-- (the reveal that confirmed it; for the Stat Egg its StatEggReveal, or nil) is the one the gate holds. False with
-- nothing armed, or an armed press that lapsed.
function Machine:confirm(cinematic)
	local armed=self.armed
	local now=self.clock()
	if not armed or now-armed.at>Machine.ConfirmWindow or not self:on()then self.armed=nil;return false end
	self.armed=nil
	-- Review R8: only a confirmed buy counts toward a streak (from the last landing, never from a press).
	self.streakCount=Machine.streak(self.streakCount,self.lastLand,now)
	local sched=Machine.schedule(self.streakCount)
	if self.crank and not self.crank.done then self:finish(self.crank)end
	if self:capsuleOn()then return self:startShot(cinematic,armed,now)end
	self.crank={kind="buy",at=now,pressed=armed.at,sched=sched,type=armed.type,fired={},claimed=true}
	-- Review 2: the Stat Egg's reveal is not the cinematic: its gate is owned by its own reveal (beta 34), so no other
	-- reveal is ever caught by it; confirmed with no owner, no gate.
	self.gate=if cinematic then {from=now,cap=now+Machine.Cap,owner=cinematic,crank=self.crank}else nil
	return true
end
-- GIFT-ART-BRIEF 1: the free egg's ribbon on the dial (GiftRibbon) while a gift waits here. on: tie it (once);
-- off: it fades (an untied one finishes falling). `options` (the first call): GiftRibbon's gui, text, onTap.
Machine.RibbonArm=30 -- s: a gift crank armed this long ago with no turn no longer unties it
function Machine:giftRibbon(on,options)
	if self.destroyed then return false end
	if options then self.ribbonOptions=options end
	local view=self.ribbonView
	if on and self:on()then
		if view and view.offAt and not view.untieAt then view:destroy();view=nil;self.ribbonView=nil end
		if not view then
			local ok,Module=pcall(require,script.Parent:WaitForChild("GiftRibbon"))
			if not ok then self:warnOnce("ribbon: "..tostring(Module));return false end
			local o=self.ribbonOptions or {}
			self.ribbonView=Module.new({gui=o.gui,text=o.text,onTap=o.onTap,clock=self.clock,
				play=function(name,speed,volume)self:play(name,volume,speed)end,buzz=function()self:buzz("light")end,
				reduced=function()return self:reduced()end})
		end
		self.ribbonWantOff=nil
		return true
	end
	-- The gift's crank is armed (GiftChain hides the ribbon the moment it cranks): it stays tied for its first tick.
	if view and self.ribbonArmed and self.clock()-self.ribbonArmed<=Machine.RibbonArm then self.ribbonWantOff=true;return false end
	if view and not view.untieAt then view:off()end
	return false
end
function Machine:ribbonLapse()
	if self.ribbonArmed and self.clock()-self.ribbonArmed>Machine.RibbonArm then
		self.ribbonArmed=nil
		if self.ribbonWantOff and self.ribbonView and not self.ribbonView.untieAt then self.ribbonView:off()end
		self.ribbonWantOff=nil
	end
end
-- The gift's crank is about to turn (GiftChain's crank or the replay of an unseen gift): its first tick unties the
-- ribbon. false disarms it (the ask was refused).
function Machine:giftCrank(armed)
	if armed==false then
		self.ribbonArmed=nil
		if self.ribbonWantOff and self.ribbonView and not self.ribbonView.untieAt then self.ribbonView:off()end
		self.ribbonWantOff=nil
		return
	end
	self.ribbonArmed=self.clock()
end
-- The armed press was refused (Fable R8): no crank, no streak step; the hello nudge and one click instead.
function Machine:refuse()
	if not self.armed then return false end
	self.armed=nil
	self.helloAt=self.clock()
	self:play("crank_click_1",Machine.Volume.hello)
	return true
end
-- ── The one path (beta 35, the standing rule) ──────────────────────────────────────────────────────────────────────
-- Every egg's reveal comes here: `kind` the egg (its drop name, EggModels type or buy action), `open` (optional) opens
-- its reveal, `owner` the reveal (the one the gate holds). The crank turns, the egg comes out and lands, and only then
-- does `open` run (Machine.openTime after the confirmation; a skip brings it to .12 s after the jump). A cinematic reveal
-- (open nil) is already built: it stays held and off the screen until the same time. A grant, a late answer or a press
-- that lapsed has no armed press: one is made, so the egg still comes out. True when the machine took the reveal; false
-- (the corner off, destroyed) and the caller opens it at once, as before the corner.
function Machine:deliver(kind,open,owner)
	if self.destroyed or not self:on()then return false end
	local drop=Machine.dropName(kind)
	self:flushOpen() -- an earlier egg's reveal still waiting opens now (never two waiting)
	local now=self.clock()
	local armed=self.armed
	if not(armed and armed.type==drop and now>=armed.at and now-armed.at<=Machine.ConfirmWindow)then
		self.armed={at=now,type=drop,unclaimed=Machine.Unclaimed[drop]==true}
	end
	if not self:confirm(owner)then return false end
	local crank=self.crank
	if open then
		local shot=self.shot
		local mine=shot~=nil and shot.crank==crank
		local at=if mine then shot.at+Machine.openTime(shot.sched)else crank.at+Machine.openTime(crank.sched)
		self.pending={open=open,at=at,owner=owner,crank=crank,kind=drop}
		-- Hatch another on a reveal of its own (the Stat Egg's result card still up): hidden while the shot plays.
		if mine and shot.mode=="shot"then self:veil(owner,true)end
	end
	return true
end
-- The waiting reveal opens now (its time came, the corner went off, a newer egg, destroy). Never twice.
function Machine:flushOpen()
	local pending=self.pending
	if not pending then return end
	self.pending=nil
	self:veil(pending.owner,false)
	local ok,problem=pcall(pending.open)
	if not ok then self:warnOnce("an egg's reveal failed to open: "..tostring(problem))end
end
-- Due at its time once its egg has landed (the crank without the shot lands on the frame it rolled), at the latest
-- ShotCap after its time; at once when the corner goes off.
function Machine:openStep()
	local pending=self.pending
	if not pending then return end
	local now=self.clock()
	local crank=pending.crank
	local landed=crank.landed or crank.done or self.crank~=crank
	if not self:on()or(now>=pending.at and landed)or now>=pending.at+Machine.ShotCap then self:flushOpen()end
end
-- The deferred reveal's own veil (StatEggReveal:veil): its old result card is hidden while the next egg's shot plays.
function Machine:veil(owner,on)
	if type(owner)=="table"and type(owner.veil)=="function"then pcall(owner.veil,owner,on)end
end
-- HatchCinematic.onPlay: the first reveal to start after an armed press is that buy's reveal: handed to deliver.
function Machine:claim(cinematic)
	local armed=self.armed
	if armed and not armed.unclaimed and self.clock()>=armed.at then self:deliver(armed.type,nil,cinematic);return end
	-- Code review of 071d8a6: another reveal starting while the capsule shot runs (a second buy merged into it) waits for
	-- the shot's own reveal to start, so it never plays inside the tucked panel.
	local shot=self.shot
	if shot and shot.mode=="shot"and cinematic~=shot.cinematic and self:shotActive()then
		local release=shot.at+shot.sched.start
		self.queued={owner=cinematic,shot=shot,release=release,cap=release+Machine.ShotCap}
	end
end
-- HatchCinematic.gate: hold this reveal? Only the claimed one, only until the egg lands, never past the cap.
function Machine:holds(cinematic)
	local queued=self.queued
	if queued and queued.owner==cinematic then
		local now=self.clock()
		-- Held until the shot's reveal starts (a skip moves that earlier), never past its cap.
		local release=if queued.shot.skipped and self.gate and self.gate.release then math.min(queued.release,self.gate.release)else queued.release
		if now>=release or now>=queued.cap or self.shot~=queued.shot then self.queued=nil;return false end
		return true
	end
	local gate=self.gate
	if not gate then return false end
	local now=self.clock()
	local crank=gate.crank
	local over=if gate.release then now>=gate.release else crank.landed
	if now>=gate.cap or over or self.crank~=crank then self.gate=nil;return false end
	return gate.owner~=nil and gate.owner==cinematic
end
-- Seconds into the running crank, or nil.
function Machine:age()return if self.crank then self.clock()-self.crank.at else nil end

-- The crank is over: the dial rests wherever it stopped (LOOK 2: it never turns back).
function Machine:finish(crank)
	if crank.done then return end
	crank.done=true
	local final=if crank.kind=="open"then Machine.Open.turn else crank.sched.turn
	self.dialRest=((self.dialRest or 0)+final)%360
end
-- When the egg in the cup starts to fade (clock time): FadeAfter after the reveal closed, else Linger after it landed.
function Machine:fadeStart(crank)
	if not crank.landedAt then return math.huge end
	local landed=crank.at+crank.landedAt
	if self.revealEndedAt and self.revealEndedAt>=crank.at then return math.max(landed,self.revealEndedAt+Machine.FadeAfter)end
	return landed+Machine.Linger-.5
end

-- ── Per frame ──────────────────────────────────────────────────────────────────────────────────────────────────
-- The sounds and beats of the running crank (always, flat), then the world motion (near only).
function Machine:beats()
	-- An armed press nobody confirmed (a refused buy) lapses quietly: no turn, no streak.
	if self.armed and self.clock()-self.armed.at>Machine.ConfirmWindow then self.armed=nil end
	-- Known refused (the intent said Rejected): the nudge now, not a silent lapse.
	if self.armed and self.d.rejected then
		local ok,no=pcall(self.d.rejected,self.armed.action)
		if ok and no==true then self:refuse()end
	end
	local crank=self.crank
	if not crank or crank.done then return end
	local t=self.clock()-crank.at
	local fired=crank.fired
	local function once(key,at,fn)if not fired[key]and t>=at then fired[key]=true;fn()end end
	if crank.kind=="open"then
		for index,at in ipairs(Machine.Open.clicks)do
			once("click"..index,at,function()self:play("crank_click_"..((index-1)%3+1),Machine.Volume.click);self:buzz("light")end)
		end
		once("tok",Machine.Open.hopAt,function()self:play("egg_tok_"..self.random:NextInteger(1,3),Machine.Volume.tokCrank)end)
		if t>=Machine.Open.seconds+.15 then self:finish(crank)end
		return
	end
	local sched=crank.sched
	for index,at in ipairs(sched.clicks)do
		once("click"..index,at,function()
			self:play("crank_click_"..((index-1)%3+1),Machine.Volume.click,1+.04*(index-1));self:buzz("light")
		end)
	end
	-- GIFT-ART-BRIEF 1: the gift's own crank unties the ribbon on its first tick (a paid crank leaves it tied).
	if fired.click1 and self.ribbonArmed and self.ribbonView and crank.at>=self.ribbonArmed then
		if self.clock()-self.ribbonArmed<=Machine.RibbonArm then pcall(self.ribbonView.untie,self.ribbonView)end
		self.ribbonArmed=nil
	end
	once("churn1",.1,function()self:play("egg_tok_1",Machine.Volume.tok)end)
	once("churn2",math.max(.1,sched.clunk-.2),function()self:play("egg_tok_2",Machine.Volume.tok)end)
	once("clunk",sched.clunk,function()self:play("crank_clunk",Machine.Volume.clunk);self:buzz("medium")end)
	-- The roll waits for the reveal to start (a refused buy drops nothing); at the cap without one, the crank ends.
	if not crank.rollAt then
		if crank.claimed and t>=sched.roll then
			-- The capsule shot keeps to its schedule (the landing is the reveal's hand-off), not to the frame it saw.
			crank.rollAt=if crank.shot then sched.roll else t
			self:play("egg_roll",Machine.Volume.roll)
		elseif t>=Machine.Cap then
			crank.landed=true;self.gate=nil;self:finish(crank)
			return
		end
	end
	if sched.shine then once("shine",sched.shine,function()self:play("cup_shine",Machine.Volume.shine)end)end
	if crank.rollAt and not crank.landed and t>=crank.rollAt+(sched.rollSeconds or Machine.RollSeconds)then
		crank.landed=true
		crank.landedAt=t
		self.lastLand=self.clock()
		self:play("land",Machine.Volume.land)
		self:buzz("medium")
		if self.gate and self.gate.crank==crank and not crank.shot then self.gate=nil end -- the shot holds to its own start
	end
	if crank.landed and self.clock()>=self:fadeStart(crank)+.5 then self:finish(crank)end
end
-- One warning per message (never a warning a frame).
function Machine:warnOnce(message)
	self.warned=self.warned or {}
	if self.warned[message]then return end
	self.warned[message]=true
	local say=self.d.warn or warn
	say("[EggMachine] "..message)
end
-- The machine's model: by name in the lounge, else by its tag (anywhere in the workspace). And why not, when not.
function Machine:findModel()
	local room=self.d.room and self.d.room()
	local model=room and room:FindFirstChild("EggMachine")
	if not model then
		local tagged=if self.d.tagged then self.d.tagged()else game:GetService("CollectionService"):GetTagged(Machine.Tag)
		for _,candidate in ipairs(tagged or {})do
			if candidate.Parent~=nil and(self.d.tagged~=nil or candidate:IsDescendantOf(workspace))then model=candidate;break end
		end
	end
	if model then return model,nil end
	return nil,if room then "no EggMachine in the lounge (the server parks it while the corner is off)"else "no EggDropLounge yet"
end
-- Is the model whole enough to animate? nil, or what is missing.
function Machine.missing(model)
	local body=model:FindFirstChild("Body")
	if not body then return "Body"end
	if not model:FindFirstChild("Dial")then return "Dial"end
	local pivot=body:FindFirstChild("DialPivot")
	if not(pivot and pivot:IsA("Attachment"))then return "Body.DialPivot"end
	return nil
end
-- Why the machine does not move right now (nil: bound and whole).
function Machine:status()
	if not self:on()then return "the corner is off on this client"end
	if self.parts then return nil end
	return self.bindReason or "not bound yet"
end
function Machine:bind()
	local now=self.clock()
	local cached=self.parts
	if cached and cached.model.Parent~=nil and(now<(self.nextBindCheck or 0))then return cached end
	local model,reason=self:findModel()
	if cached and model==cached.model then self.nextBindCheck=now+Machine.BindRetry;return cached end
	if not cached and now<(self.nextBindTry or 0)then return nil end
	self.parts=nil
	self.nextBindTry=now+Machine.BindRetry
	if not model then self.bindReason=reason;return nil end
	local lacking=Machine.missing(model)
	if lacking then
		-- Seen before its parts (streaming, or a late replication): never cache it half empty; look again soon.
		self.bindReason="EggMachine found but "..lacking.." is missing (still replicating?)"
		return nil
	end
	self.bindReason=nil
	self.nextBindCheck=now+Machine.BindRetry
	local body=model:FindFirstChild("Body")
	local function rest(name)
		local part=model:FindFirstChild(name)
		if not part then return nil end
		return{part=part,rest=part:GetAttribute("WorldRestCFrame")or part.CFrame}
	end
	local function point(name)
		local a=body and body:FindFirstChild(name)
		return if a and a:IsA("Attachment")then a.WorldCFrame else nil
	end
	local parts={model=model,body=body,dial=rest("Dial"),sprout=rest("Sprout"),pile=rest("EggPile"),drop=rest("DropEgg"),loose={},
		dialPivot=point("DialPivot"),sproutPivot=point("SproutPivot"),chuteTop=point("ChuteTop"),chuteEnd=point("ChuteEnd"),cup=point("CupSeat")}
	for index=1,6 do
		local loose=rest("Loose"..index)
		if loose then
			loose.base=loose.rest*CFrame.new(0,-loose.part.Size.Y/2,0)
			loose.hz=Machine.Rock.hz[1]+(Machine.Rock.hz[2]-Machine.Rock.hz[1])*(index-1)/5
			table.insert(parts.loose,loose)
		end
	end
	self.parts=parts
	self.atRest=false
	pcall(self.dressHole,self,parts)
	return parts
end
-- Beta (35) 3: the hole the egg comes out of (only on the leafless Body: EggCorner.hole), client-side pieces in the
-- machine's model, placed from the CupSeat attachment (the seat's machine-local point) so they follow the model.
-- After beta 36 the Body bakes a real mouth there (data.mouth, EggCorner.mouth): then nothing is drawn; the drawn disc
-- and rim stay only for an older leafless Body. `data` (specs) defaults to the machine's data.
function Machine:dressHole(parts,data)
	data=data or Corner.machineData()
	local hole=Corner.hole(data)
	if not hole or Corner.mouth(data)or not parts.cup or parts.model:FindFirstChild("EggHole")then return end
	local origin=parts.cup*CFrame.new(-Corner.dropPoints(data).seat)
	local folder=Instance.new("Model");folder.Name="EggHole"
	for _,piece in ipairs(Machine.holeParts(hole))do
		local part=Instance.new("Part")
		part.Name=piece.name;part.Anchored=true;part.CanCollide=false;part.CanQuery=false;part.CanTouch=false;part.CastShadow=false
		if piece.cylinder then part.Shape=Enum.PartType.Cylinder end
		part.Material=Enum.Material.SmoothPlastic;part.Color=piece.color;part.Size=piece.size;part.CFrame=origin*piece.cframe
		part.Parent=folder
	end
	folder.Parent=parts.model
end
-- Beta (35) 4: the dropped egg's real shell (deps.shells() -> {TopShell, BottomShell[, Core]} fresh MeshParts, or nil
-- while they load; asked at most once a second), in the bought type's colorMap. Nil (no shells yet, or a type with no
-- shell in EggModels): the plain coloured DropEgg stands in.
function Machine:shellFor(parts,kind)
	local typ=Models.Types[Corner.eggType(kind)or ""]
	if not typ or not typ.colorMap then return nil end
	local shell=parts.shell
	local kept=not shell and parts.model:FindFirstChild("DropShell")
	if kept and kept:FindFirstChild("TopShell")and kept:FindFirstChild("BottomShell")then
		-- A rebind of the same model keeps the shells it already has (never a second pair).
		shell={model=kept,TopShell=kept:FindFirstChild("TopShell"),BottomShell=kept:FindFirstChild("BottomShell")}
		parts.shell=shell
	end
	if not shell then
		local now=self.clock()
		if not self.d.shells or now<(parts.shellNext or 0)then return nil end
		parts.shellNext=now+1
		local ok,made=pcall(self.d.shells)
		if not(ok and type(made)=="table"and made.TopShell and made.BottomShell)then return nil end
		local folder=Instance.new("Model");folder.Name="DropShell"
		for _,name in ipairs({"BottomShell","TopShell"})do
			local part=made[name]
			part.Name=name;part.Anchored=true;part.CanCollide=false;part.CanQuery=false;part.CanTouch=false;part.CastShadow=true
			part.Material=Enum.Material.SmoothPlastic;part.Color=Color3.new(1,1,1);part.Transparency=1;part.Parent=folder
		end
		if made.Core then pcall(function()made.Core:Destroy()end)end
		folder.Parent=parts.model
		shell={model=folder,TopShell=made.TopShell,BottomShell=made.BottomShell}
		parts.shell=shell
	end
	if shell.type~=kind then
		shell.type=kind
		shell.TopShell.TextureID=typ.colorMap;shell.BottomShell.TextureID=typ.colorMap
	end
	return shell
end
function Machine.hideShell(parts)
	local shell=parts and parts.shell
	if not shell then return end
	for _,name in ipairs({"TopShell","BottomShell"})do
		if shell[name].Transparency~=1 then shell[name].Transparency=1 end
	end
end
-- Puts every moved part back (out of range, the corner off).
function Machine:rest()
	local parts=self.parts
	if not parts or self.atRest then return end
	self.atRest=true
	for _,item in ipairs({parts.dial,parts.sprout,parts.pile})do if item then item.part.CFrame=item.rest end end
	for _,loose in ipairs(parts.loose)do loose.part.CFrame=loose.rest end
	if parts.drop then parts.drop.part.CFrame=parts.drop.rest;parts.drop.part.Transparency=1 end
	Machine.hideShell(parts)
end
local function about(pivot,turn,rest)return pivot*turn*pivot:Inverse()*rest end
function Machine:aero()
	local now=self.clock()
	if now<self.aeroAt then return end
	self.aeroAt=now+.5
	local folder=workspace:FindFirstChild("EggDropAero")
	if not folder then return end
	local on=self:on()
	for _,name in ipairs(Corner.Aero)do
		local part=folder:FindFirstChild(name,true)
		if part and part:IsA("BasePart")then
			local want=if on then 1 else 0
			if part.LocalTransparencyModifier~=want then part.LocalTransparencyModifier=want end
		end
	end
end
function Machine:step(dt)
	if self.destroyed then return end
	-- First, on its own: a reveal waiting for its egg must never be lost to an error further down.
	local ok,problem=pcall(self.openStep,self)
	if not ok then self:warnOnce("open: "..tostring(problem));self:flushOpen()end
	self.t+=dt or 0
	self:aero()
	self:beats()
	self:shotStep()
	self:gapStep()
	if not self:on()then
		self:rest();self.unboundSince=nil
		if self.ribbonView then self.ribbonView:destroy();self.ribbonView=nil end
		return
	end
	local parts=self:bind()
	if not parts then
		self.unboundSince=self.unboundSince or self.clock()
		if self.clock()-self.unboundSince>=Machine.WarnAfter then self:warnOnce("no machine to animate after "..Machine.WarnAfter.." s: "..tostring(self.bindReason))end
		return
	end
	self.unboundSince=nil
	self:ribbonLapse()
	local eye=self.d.camera and self.d.camera()
	if self.ribbonView then
		-- its clock runs at any range; out of range it writes nothing (code review)
		local far=typeof(eye)=="Vector3"and(eye-parts.body.Position).Magnitude>Machine.Range
		local good,problem=pcall(self.ribbonView.step,self.ribbonView,dt or 0,parts,self.d.root and self.d.root(),far)
		if not good then self:warnOnce("ribbon: "..tostring(problem))end
		if self.ribbonView and self.ribbonView:gone()then self.ribbonView=nil end
	end
	local centre=parts.body.Position
	if typeof(eye)=="Vector3"and(eye-centre).Magnitude>Machine.Range then self:rest();return end
	self.atRest=false
	local reduced=self:reduced()
	local now=self.clock()
	local t=self.t
	local crank=self.crank
	local age=crank and now-crank.at or nil
	-- Hello.
	local root=self.d.root and self.d.root()
	if typeof(root)=="Vector3"then
		local flat=Vector2.new(root.X-centre.X,root.Z-centre.Z).Magnitude
		if flat>Machine.Hello.rearm then self.helloArmed=true end
		if self.helloArmed and flat<=Machine.Hello.near and now-self.helloAt>=Machine.Hello.every and not(crank and not crank.done)then
			self.helloArmed=false
			self.helloAt=now
			self:play("crank_click_1",Machine.Volume.hello)
		end
	end
	-- The dial.
	local angle=0
	if crank and not crank.done then
		angle=if crank.kind=="open"then Machine.openAngle(age)else Machine.buyAngle(crank.sched,age-(crank.sched.turnFrom or 0))
	end
	local hello=now-self.helloAt
	if hello<Machine.Hello.seconds then angle+=Machine.Hello.angle*math.sin(hello/Machine.Hello.seconds*math.pi)end
	if parts.dial and parts.dialPivot then
		parts.dial.part.CFrame=about(parts.dialPivot,CFrame.Angles(0,0,-math.rad((self.dialRest or 0)+angle)),parts.dial.rest)
	end
	-- The sprout.
	if parts.sprout and parts.sproutPivot then
		local sway=if reduced then 0 else math.rad(Machine.Sway.angle)*math.sin(t*Machine.Sway.hz*2*math.pi)
		parts.sprout.part.CFrame=about(parts.sproutPivot,CFrame.Angles(sway*.35,0,sway),parts.sprout.rest)
	end
	-- Hops: the open crank's (.12 at .1) and the buy's churn (.2 until the clunk).
	local hop=0
	if crank and not crank.done and age then
		if crank.kind=="open"then
			local h=(age-Machine.Open.hopAt)/Machine.Open.hopSeconds
			if h>0 and h<1 then hop=Machine.Open.hop*math.sin(h*math.pi)end
		elseif age>=(crank.sched.turnFrom or 0)+.1 and age<crank.sched.clunk then
			hop=.2*math.abs(math.sin((age-.1)*7*math.pi))
		end
	end
	-- Settle: one loose egg slips down the pile and back.
	if not self.settleAt then self.settleAt=now+self.random:NextNumber(Machine.Settle.min,Machine.Settle.max)end
	if now>=self.settleAt and #parts.loose>0 then
		self.settle={egg=self.random:NextInteger(1,#parts.loose),at=now,slip=self.random:NextNumber(Machine.Settle.slip[1],Machine.Settle.slip[2])}
		self.settleAt=now+self.random:NextNumber(Machine.Settle.min,Machine.Settle.max)
		if typeof(root)=="Vector3"and(root-centre).Magnitude<=Machine.Settle.range then
			self:play("egg_tok_"..self.random:NextInteger(1,3),Machine.Volume.tok)
		end
	end
	for index,loose in ipairs(parts.loose)do
		local rock=if reduced then 0 else math.rad(Machine.Rock.angle)*math.sin((t*loose.hz+index*.37)*2*math.pi)
		local down=0
		local s=self.settle
		if s and s.egg==index then
			local u=now-s.at
			if u<Machine.Settle.seconds then
				local p=u/Machine.Settle.seconds
				down=s.slip*easeOut(p)-(if p>.7 then .04*math.sin((p-.7)/.3*math.pi)else 0)
			elseif u<Machine.Settle.seconds+Machine.Settle.back then
				down=s.slip*(1-(u-Machine.Settle.seconds)/Machine.Settle.back)
			else self.settle=nil end
		end
		local lift=hop*(.7+.3*((index*.618)%1))-down
		loose.part.CFrame=loose.base*CFrame.new(0,lift,0)*CFrame.Angles(rock,0,rock*.5)*loose.base:Inverse()*loose.rest
	end
	if parts.pile then
		local shiver=if crank and crank.kind=="buy"and not crank.done and age and age>=.1 and age<crank.sched.clunk then .04*math.sin(age*40)else 0
		parts.pile.part.CFrame=parts.pile.rest*CFrame.new(shiver,0,0)
	end
	-- The dropped egg.
	local drop=parts.drop
	if drop then
		local shown=false
		if crank and crank.kind=="buy"and not crank.done and crank.rollAt and age and parts.chuteTop and parts.chuteEnd and parts.cup then
			local u=age-crank.rollAt
			local fade=math.clamp((now-self:fadeStart(crank))/.5,0,1)
			if fade<1 then
				shown=true
				local p=Machine.rollAt(parts.chuteTop.Position,parts.chuteEnd.Position,parts.cup.Position,u,crank.sched.rollSeconds)
				local rockLand=if crank.landedAt and age-crank.landedAt<.3 then math.rad(8)*math.sin((age-crank.landedAt)/.3*math.pi)else 0
				local at=CFrame.new(p)*(parts.cup-parts.cup.Position)*CFrame.Angles(rockLand,0,0)
				local shell=self:shellFor(parts,crank.type)
				drop.part.CFrame=at
				if shell then
					-- The real egg: the bought type's shell at the dropped egg's height (beta 35 4).
					local data=Corner.machineData()
					local pose=Machine.shellPose(at,data.egg.size[2]*Corner.dropScale(data))
					for _,name in ipairs({"BottomShell","TopShell"})do
						local part=shell[name]
						part.Size=pose[name].size;part.CFrame=pose[name].cframe;part.Transparency=fade
					end
					if drop.part.Transparency~=1 then drop.part.Transparency=1 end
				else
					drop.part.Color=Color3.fromHex((Corner.machineData().eggTypes or {})[crank.type]or "#FFFFFF")
					drop.part.Transparency=fade
				end
			end
		end
		if not shown then
			if drop.part.Transparency~=1 then drop.part.Transparency=1;drop.part.CFrame=drop.rest end
			Machine.hideShell(parts)
		end
	end
end
-- The reveal the buy started has ended: the egg in the cup fades FadeAfter later. `source` is "stat" for the Stat Egg's
-- own reveal, anything else for the hatch screens. Beta (34): each closes only its own buy: the Stat Egg's buy closes
-- the Hatch eggs screen under its reveal (SnackHost closeShop), which must not end its shot.
function Machine:revealClosed(source)
	local crank=self.crank
	local stat=crank~=nil and crank.kind=="buy"and Machine.Unclaimed[crank.type]==true
	if(source=="stat")~=stat then return end
	self.revealEndedAt=self.clock()
	-- Studio R15 (2): Hatch another closes the screen while it waits out the server's request spacing. The camera stays
	-- at Shot B through that gap, so the next buy chains (the 2nd / 3rd schedule) instead of a new first shot.
	if self:againWaiting()and self.shot and self.shot.camera then self.gap={at=self.revealEndedAt};return end
	-- The hatch screen closed: the camera goes back to the player (LOOK 1, "Coming back").
	self:returnCamera(false)
end
-- A Hatch another is waiting for its buy, or a buy is pressed and not yet confirmed.
function Machine:againWaiting()
	local armed=self.armed
	if armed and self.clock()-armed.at<=Machine.ConfirmWindow then return true end
	return self.d.againPending~=nil and self.d.againPending()==true
end
-- The gap ended with no buy (refused, timed out): the camera goes back GapGrace after it went quiet.
Machine.GapGrace=.5
function Machine:gapStep()
	local gap=self.gap
	if not gap then return end
	if not self.shot or not self.shot.camera then self.gap=nil;return end
	if self:againWaiting()then gap.quiet=nil;return end
	local now=self.clock()
	gap.quiet=gap.quiet or now
	if now-gap.quiet>=Machine.GapGrace then self.gap=nil;self:returnCamera(false)end
end
-- The camera is the machine's (a shot, the reveal behind it, or a Hatch another gap): the top rail stays hidden.
function Machine:cameraHeld()return self.shot~=nil and self.shot.camera~=nil end
-- How far every reveal stage is slid off the screen now (0 home, 1 gone): the panel's tuck during a shot.
-- Beta (35): the pocket and Reduced Motion versions hold every covering reveal stage away too (1 until the hand-off,
-- then 0 at once: no slide), so no reveal is on the screen before the egg is in the cup; their panel stays.
function Machine:stageAmount()
	local shot=self.shot
	if not shot or shot.panelBack then return 0 end
	return shot.amount or 0
end

-- ── The capsule shot ──────────────────────────────────────────────────────────────────────────────────────────────
function Machine:capsuleOn()return self.d.capsule~=nil and self.d.capsule()==true end
-- The machine's frame on its floor (+Z the front), from the Body (never the model's pivot: B1).
function Machine:frame()
	local parts=self.parts
	if not parts or not parts.body then return nil end
	local body=parts.body
	local bottom=body.Position.Y-body.Size.Y/2
	return Corner.frame(bottom)
end
-- The two shots in world space, mirrored to the other side when the first is blocked; nil when both are.
function Machine:shotFrames()
	local frame=self:frame()
	if not frame then return nil end
	local blocked=self.d.blocked or function()return false end
	local function shot(spec,side)
		local at=frame*Vector3.new(spec.at.X*side,spec.at.Y,spec.at.Z)
		local look=frame*spec.look
		if blocked(look,at)then return nil end
		return CFrame.lookAt(at,look)
	end
	for _,side in ipairs({1,-1})do
		local a,b=shot(Machine.ShotA,side),shot(Machine.ShotB,side)
		if a and b then return{A=a,B=b}end
	end
	return nil
end
-- Which version plays for this confirmation: "reduced", "pocket" or "shot" (with its frames).
function Machine:shotMode(kind)
	if self:reduced()then return "reduced"end
	-- Beta (34): the Stat Egg plays the same shot as every egg (LOOK 1 had left it to the pocket's sounds, "a later
	-- slice"); `kind` no longer changes the version.
	local parts=self:bind()
	if not parts then return "pocket"end
	local root=self.d.root and self.d.root()
	if typeof(root)~="Vector3"or(root-parts.body.Position).Magnitude>Machine.PocketRange then return "pocket"end
	local frames=self:shotFrames()
	if not frames then return "pocket"end
	return "shot",frames
end
-- The panel's top GuiObjects (the cinematic's host, and a borrowed full-screen stage): what the tuck slides away.
local function isGui(x)
	return x:IsA("GuiObject")or x.ClassName=="Frame"or x.ClassName=="CanvasGroup"or x.ClassName=="ImageLabel"or x.ClassName=="TextButton"
end
function Machine.panelRoots(cinematic)
	local out={}
	-- Code review of 071d8a6: the walk stops at the screen's own shade (the child of SafeContent, which holds every
	-- overlay and is positioned by init's alignSafeContent), so a resize mid-shot never leaves the overlays offset.
	local function top(node)
		local last=nil
		while node and node.Parent do
			if node.ClassName=="ScreenGui"or node:IsA("ScreenGui")then break end
			if isGui(node)then last=node end
			if node.Parent.Name=="SafeContent"then break end
			node=node.Parent
		end
		if last and not table.find(out,last)then table.insert(out,last)end
	end
	if type(cinematic)=="table"then
		if typeof(cinematic.frame)=="Instance"then top(cinematic.frame)end
		local stage=cinematic.borrowedStage
		if type(stage)=="table"and typeof(stage.root)=="Instance"then top(stage.root)end
	end
	return out
end
function Machine:startShot(cinematic,armed,now)
	local mode,frames=self:shotMode(armed.type)
	local streak=self.streakCount
	-- Hatch another starts from Shot B: a 2nd / 3rd in a row needs the camera still there; else a first shot.
	if mode=="shot"and streak>1 and not(self.shot and self.shot.camera)then streak=1 end
	local sched=Machine.shotSchedule(mode,streak)
	self.crank={kind="buy",at=now,pressed=armed.at,sched=sched,type=armed.type,fired={},claimed=true,shot=true}
	self.gap=nil
	self.gate=if cinematic then {from=now,cap=now+sched.start+Machine.ShotCap,release=now+sched.start,owner=cinematic,crank=self.crank}else nil
	local previous=self.shot
	local shot={mode=mode,at=now,sched=sched,cinematic=cinematic,kind=armed.type,frames=frames,crank=self.crank}
	if previous and previous.camera then
		if mode=="shot"then shot.camera=previous.camera
		-- Code review of 071d8a6: the next buy is a pocket or Reduced Motion one (walked off, streamed out, blocked,
		-- Reduced Motion turned on): the camera held at Shot B goes back now, never left Scriptable.
		else self:giveBack(previous)end
	end
	if previous and previous~=shot then self:restorePanel(previous)end
	self.shot=shot
	if mode=="shot"then
		-- The skip keys (Space, Enter, A) are bound only while the shot plays (init: ContextActionService).
		if self.d.skipInput then pcall(self.d.skipInput,true);shot.skipBound=true end
		shot.roots={}
		self:lateRoots(shot)
		self:play("screen_tuck",Machine.Volume.tuck)
		if self.d.hud then pcall(self.d.hud,false)end
		self:takeCamera(shot)
	elseif mode=="pocket"and self.d.pocket then
		pcall(self.d.pocket,string.lower(armed.type or "toy"),sched)
	end
	if mode~="shot"then self:placePanel(shot,1)end
	return true
end
-- The camera: Scriptable from where it is now (or Shot B, for Hatch another), and given back later.
function Machine:takeCamera(shot)
	local camera=self.d.cameraObject and self.d.cameraObject()
	if not camera then return end
	if not shot.camera then
		shot.camera={object=camera,savedType=camera.CameraType,savedCFrame=camera.CFrame}
		pcall(function()camera.CameraType=Enum.CameraType.Scriptable end)
		if self.d.ghost then pcall(self.d.ghost,1)end
	end
	shot.camera.from=camera.CFrame
end
local function easeInOut(x)return if x<.5 then 4*x*x*x else 1-(-2*x+2)^3/2 end
-- The panel slid away by `amount` (0 home, 1 off the bottom of the screen).
function Machine:placePanel(shot,amount)
	shot.amount=amount
	for _,entry in ipairs(shot.roots or {})do
		if entry.gui.Parent then
			entry.gui.Position=entry.position+UDim2.new(0,0,amount,math.floor(40*amount))
		end
	end
	-- Studio R15 (1): the reveal's stage keeps itself over the whole screen (DeckKit.coverScreen), so moving its parent
	-- never moved it and it hid the shot. Every stage slides by the same amount through its own cover (CoverShift).
	if self.d.stageHold then pcall(self.d.stageHold,amount)end
end
-- Fable R13 (4, 02a): the reveal's full-screen stage opens after the confirmation (when the result lands), so it was
-- never in the tucked set and its 2D waiting egg stood in front of the dial. Any panel root that appears mid-shot is
-- recorded at its own home and tucked with the rest (and comes back with them).
-- Studio R16: the screen the buy was pressed on (Hatch eggs) is not the reveal's host, so it stayed over the shot; the
-- hatch screens (deps.screens() -> {GuiObject}) slide away with it.
function Machine:lateRoots(shot)
	if not shot.roots then return end
	local list=Machine.panelRoots(shot.cinematic)
	if self.d.screens then
		local ok,screens=pcall(self.d.screens)
		if ok and type(screens)=="table"then for _,gui in ipairs(screens)do if typeof(gui)=="Instance"and not table.find(list,gui)then table.insert(list,gui)end end end
	end
	for _,gui in ipairs(list)do
		local known=false
		for _,entry in ipairs(shot.roots)do if entry.gui==gui then known=true;break end end
		if not known then table.insert(shot.roots,{gui=gui,position=gui.Position})end
	end
end
function Machine:restorePanel(shot)
	if not shot or shot.panelBack then return end
	shot.panelBack=true
	self:placePanel(shot,0)
	if shot.mode=="shot"and self.d.hud then pcall(self.d.hud,true)end
end
-- Per frame: the panel's tuck and rise, the camera's moves, the hand-off, the cap.
-- The skip keys go back to the game the moment the shot is over (or skipped).
function Machine:unbindSkip(shot)
	if shot and shot.skipBound then
		shot.skipBound=false
		if self.d.skipInput then pcall(self.d.skipInput,false)end
	end
end
function Machine:shotStep()
	local shot=self.shot
	if not shot then return end
	local now=self.clock()
	local s=shot.sched
	local t=now-shot.at
	if shot.skipBound and not self:shotActive()then self:unbindSkip(shot)end
	if shot.mode=="shot"and not shot.panelBack then
		self:lateRoots(shot)
		local amount
		if shot.forceRise then
			amount=1-math.clamp((now-shot.forceRise)/.12,0,1)
		elseif t<s.tuck then amount=t/s.tuck
		elseif t<s.rise then amount=1
		else amount=1-math.clamp((t-s.rise)/s.riseSeconds,0,1)end
		self:placePanel(shot,amount)
		if amount<=0 and t>=s.tuck then
			shot.panelBack=true
			if self.d.hud then pcall(self.d.hud,true)end
		end
		if t>=s.rise and not shot.rose then shot.rose=true;self:play("screen_rise",Machine.Volume.rise)end
	end
	-- Pocket and Reduced Motion: the covering stages come back at the hand-off.
	if shot.mode~="shot"and not shot.panelBack and t>=Machine.openTime(s)then self:restorePanel(shot)end
	-- The hard cap: the panel is always back by then.
	if t>=s.start+Machine.ShotCap and not shot.panelBack then self:restorePanel(shot)end
	local cam=shot.camera
	if cam and shot.frames and not cam.returning then
		local object=cam.object
		local target
		if s.camA and t<s.camB then
			local p=math.clamp((t-s.camA)/s.camASeconds,0,1)
			target=cam.from:Lerp(shot.frames.A,easeOut(p))
		else
			local from=if s.camA then shot.frames.A else cam.from
			local p=math.clamp((t-s.camB)/s.camBSeconds,0,1)
			target=from:Lerp(shot.frames.B,easeInOut(p))
		end
		object.CFrame=target
	end
	if cam and cam.returning then
		local p=math.clamp((now-cam.returning)/Machine.ReturnSeconds,0,1)
		cam.object.CFrame=cam.returnFrom:Lerp(cam.savedCFrame,easeInOut(p))
		if p>=1 then self:giveBack(shot)end
	end
	-- Code review B35: the Stat Egg's reveal owns the return (revealClosed "stat"); if it never opened, nobody would.
	-- Beta (40) note 4 (ARCH-REVIEW-P2 section 3): generalised to any shot. A shot whose owner is not open (none at all,
	-- or one that says isOpen false), with no hatch screen up and no Hatch another gap, gives the camera back StatWatch s
	-- after its start; once its owner was seen open, the owner's own close returns it. Machine.watchReturns is the rule.
	if cam and not cam.returning and t>=s.start+Machine.StatWatch then
		local open=Machine.ownerOpen(shot.cinematic,Machine.Unclaimed[shot.kind]==true)
		local screen=false
		if self.d.screens then
			local ok,list=pcall(self.d.screens)
			if ok and type(list)=="table"then for _,gui in ipairs(list)do if typeof(gui)=="Instance"and gui.Parent and gui.Visible then screen=true end end end
		end
		if Machine.watchReturns({open=open,seenOpen=shot.statSeenOpen==true,screen=screen,gap=self.gap~=nil})then self:returnCamera(false)
		elseif open then shot.statSeenOpen=true end
	end
	-- The model unbound, or the corner / capsule off, mid-shot: the camera goes back at once.
	if cam and(not self:on()or not self:capsuleOn()or(self.parts==nil and t>.05))then self:returnCamera(true)end
end
-- Eases the camera back (instant = at once) and ends the shot's hold on the screen.
function Machine:returnCamera(instant)
	local shot=self.shot
	if not shot then return end
	self:restorePanel(shot)
	local cam=shot.camera
	if not cam then self.shot=nil;return end
	if instant then self:giveBack(shot);return end
	if not cam.returning then cam.returning=self.clock();cam.returnFrom=cam.object.CFrame end
end
function Machine:giveBack(shot)
	self:unbindSkip(shot)
	local cam=shot.camera
	if cam then
		pcall(function()cam.object.CFrame=cam.savedCFrame end)
		pcall(function()cam.object.CameraType=cam.savedType end)
		if self.d.ghost then pcall(self.d.ghost,0)end
		shot.camera=nil
	end
	self:restorePanel(shot)
	if self.shot==shot then self.shot=nil end
end
-- Is a shot playing (the panel tucked or the egg not yet landed)?
function Machine:shotActive()
	local shot=self.shot
	return shot~=nil and shot.mode=="shot"and not shot.skipped and(self.clock()-shot.at)<shot.sched.start
end
-- A tap / click / A / Space / Enter during the shot: jump to the landing (never the first drop of a type). The thud
-- always plays; the panel rises .12 s later.
function Machine:skipShot()
	local shot=self.shot
	if not shot or shot.mode~="shot"or shot.skipped then return false end
	-- The first drop of each egg type cannot be skipped: the same canSkip the reveal itself asks (asked now, not at the
	-- confirmation: the stage sets it when it opens).
	local c=shot.cinematic
	local pending=self.pending
	if pending and pending.crank==shot.crank then
		-- Its reveal is not open yet (deferred): the stage's own rule, asked by type (deps.firstOfType).
		if self.d.firstOfType then
			local ok,first=pcall(self.d.firstOfType,Corner.eggType(pending.kind))
			if ok and first==true then return false end
		end
	elseif type(c)=="table"and type(c.canSkip)=="function"then
		local ok,allowed=pcall(c.canSkip)
		if ok and allowed==false then return false end
	end
	local crank=shot.crank
	local now=self.clock()
	if crank.landed or now-shot.at>=shot.sched.land then return false end
	shot.skipped=true
	local s=shot.sched
	-- Everything before the landing counts as played (no burst of clicks), the egg is in the cup.
	for index in ipairs(s.clicks)do crank.fired["click"..index]=true end
	crank.fired.churn1,crank.fired.churn2,crank.fired.clunk=true,true,true
	crank.at=now-s.land
	shot.at=crank.at
	crank.rollAt=crank.rollAt or s.roll
	shot.forceRise=now
	if self.gate and self.gate.crank==crank then
		self.gate.release=now+.12
		self.gate.cap=now+.12+Machine.ShotCap
	end
	if pending and pending.crank==crank then pending.at=math.min(pending.at,now+.12)end
	if shot.camera and shot.frames then shot.camera.from=shot.frames.B end
	return true
end
function Machine:destroy()
	if self.destroyed then return end
	self.destroyed=true
	if self.heartbeat then self.heartbeat:Disconnect();self.heartbeat=nil end
	pcall(self.flushOpen,self) -- a reveal waiting for its egg opens now, never lost
	pcall(self.returnCamera,self,true)
	if self.cinematic then
		if self.cinematic.gate then self.cinematic.gate=nil end
		if self.cinematic.onPlay then self.cinematic.onPlay=nil end
		if self.cinematic.onGateSkip then self.cinematic.onGateSkip=nil end
	end
	if self.statReveal then self.statReveal.gate=nil;self.statReveal.onGateSkip=nil end
	if self.ribbonView then pcall(self.ribbonView.destroy,self.ribbonView);self.ribbonView=nil end
	pcall(self.rest,self)
end
return Machine
