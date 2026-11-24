-- The egg machine, the client (EGG-CORNER-LOOK section 2; EGG-CORNER-BUILD-PLAN section 7). Presentation only: the
-- server placed the machine (EggCornerWorld) and never moves its parts again; this animates them locally from their
-- WorldRestCFrame attributes, plays the sounds and holds the hatch reveal for the buy crank. Nothing is sent or saved.
--   idle   the sprout sways 4 degrees at .35 Hz, six loose eggs rock 3 degrees about their base, one settles every 9 to
--          14 s with a soft knock (within 14 studs); the body never moves
--   hello  coming within 10 studs: the dial nudges 15 degrees and springs back (.4 s), one click; re-armed past 12, 20 s apart
--   open   `Turn`: a quarter turn (.28 s, overshoot 6), clicks at 0 / 90 / 180 ms, the loose eggs hop at .1; the screen
--          opens at .3 (init); a second press inside a running crank is ignored
--   buy    the press (before the remote): a full turn and 5 clicks (.6 s), clunk, the bought colour's egg rolls down the
--          chute and lands in the cup at .85 with the landing thud (once). Hatch another within 20 s: a half turn (.45 s,
--          3 clicks), then a quarter (.25 s, 1 click). A press while a buy crank runs merges into it (no second crank or
--          egg; the 1 s cap still counts from the first press); a retried send of the same action never starts another.
--   hold   HatchCinematic.gate holds the clock of the one reveal that started after the press until the egg lands, at
--          most 1 s after the first press; a skip is refused meanwhile. The egg rolls only once that reveal has started
--          (a refused buy drops nothing); the Stat Egg's reveal is not the cinematic, so its egg rolls on schedule.
--          Reduced Motion: the reveal shows its static card at once (the cinematic never asks the hold); the crank,
--          its sounds and the egg still play.
-- Sounds play flat with the screen (Fable R2 F6); the world motion only within Range of the camera. The old station's
-- Aero dome and lip go see-through (LocalTransparencyModifier) while the corner is on.
-- deps: room() -> the lounge or nil, root() -> Vector3?, camera() -> Vector3?, reduced(), audio {play(name, speed,
--   volume)}, haptic(strength) (optional), corner() (the switch), clock (default os.clock), random (default Random.new()),
--   cinematic (the HatchCinematic module; default required), step=false (specs call :step).
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Corner=require(Shared:WaitForChild("EggCorner"))
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
Machine.Unclaimed=table.freeze({Stat=true}) -- reveals that are not the cinematic: the egg rolls on schedule
-- Volumes (from Fable's dB): -16 .16, -20 .1, -24 .063, -26 .05.
Machine.Volume=table.freeze({click=.1,clunk=.16,roll=.1,tok=.05,tokCrank=.063,hello=.063,land=.5})

-- ── Pure ─────────────────────────────────────────────────────────────────────────────────────────────────────────
-- The buy crank for a streak (1, 2, 3 or more): turn (degrees), seconds, clicks, clunk, roll and landing times.
function Machine.schedule(streak)
	local row=Machine.Turns[math.clamp(math.floor(tonumber(streak)or 1),1,3)]
	local clunk=row.seconds
	return{turn=row.turn,seconds=row.seconds,clicks=row.clicks,clunk=clunk,roll=clunk+Machine.RollDelay,
		land=clunk+Machine.RollDelay+Machine.RollSeconds}
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
-- Where the dropped egg is along the chute at t seconds into its roll (0 .. RollSeconds): a, b, c are ChuteTop, ChuteEnd,
-- CupSeat; the leaf is the first 60% of the time, the drop into the cup the rest.
function Machine.rollAt(a,b,c,t)
	local p=math.clamp(t/Machine.RollSeconds,0,1)
	if p<.6 then
		local q=p/.6
		return a:Lerp(b,q*q)
	end
	local q=(p-.6)/.4
	return b:Lerp(c,q)+Vector3.new(0,.12*math.sin(q*math.pi),0)
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
	end
	if deps.step~=false then
		self.heartbeat=RunService.Heartbeat:Connect(function(dt)
			local ok,problem=pcall(self.step,self,dt)
			if not ok then warn("[EggMachine] "..tostring(problem))end
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
	self.streakCount=Machine.streak(self.streakCount,self.lastLand,now)
	local sched=Machine.schedule(self.streakCount)
	local unclaimed=Machine.Unclaimed[kind]==true
	self.crank={kind="buy",at=now,sched=sched,type=kind,fired={},claimed=unclaimed}
	-- Review 2: a reveal that is not the cinematic (the Stat Egg) gets no gate, so no other reveal is ever caught by it.
	self.gate=if unclaimed then nil else {from=now,cap=now+Machine.Cap,owner=nil,crank=self.crank}
	return true
end
-- HatchCinematic.onPlay: the first reveal to start after the press is the one the gate holds.
function Machine:claim(cinematic)
	local gate=self.gate
	if gate and gate.owner==nil and self.clock()>=gate.from and self.clock()<gate.cap then
		gate.owner=cinematic
		gate.crank.claimed=true
	end
end
-- HatchCinematic.gate: hold this reveal? Only the claimed one, only until the egg lands, never past the cap.
function Machine:holds(cinematic)
	local gate=self.gate
	if not gate then return false end
	local now=self.clock()
	local crank=gate.crank
	if now>=gate.cap or crank.landed or self.crank~=crank then self.gate=nil;return false end
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
	once("churn1",.1,function()self:play("egg_tok_1",Machine.Volume.tok)end)
	once("churn2",math.max(.1,sched.clunk-.2),function()self:play("egg_tok_2",Machine.Volume.tok)end)
	once("clunk",sched.clunk,function()self:play("crank_clunk",Machine.Volume.clunk);self:buzz("medium")end)
	-- The roll waits for the reveal to start (a refused buy drops nothing); at the cap without one, the crank ends.
	if not crank.rollAt then
		if crank.claimed and t>=sched.roll then
			crank.rollAt=t
			self:play("egg_roll",Machine.Volume.roll)
		elseif t>=Machine.Cap then
			crank.landed=true;self.gate=nil;self:finish(crank)
			return
		end
	end
	if crank.rollAt and not crank.landed and t>=crank.rollAt+Machine.RollSeconds then
		crank.landed=true
		crank.landedAt=t
		self.lastLand=self.clock()
		self:play("land",Machine.Volume.land)
		self:buzz("medium")
		if self.gate and self.gate.crank==crank then self.gate=nil end
	end
	if crank.landed and self.clock()>=self:fadeStart(crank)+.5 then self:finish(crank)end
end
function Machine:bind()
	local room=self.d.room and self.d.room()
	local model=room and room:FindFirstChild("EggMachine")
	if model==(self.parts and self.parts.model)then return self.parts end
	self.parts=nil
	if not model then return nil end
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
	local parts={model=model,dial=rest("Dial"),sprout=rest("Sprout"),pile=rest("EggPile"),drop=rest("DropEgg"),loose={},
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
	return parts
end
-- Puts every moved part back (out of range, the corner off).
function Machine:rest()
	local parts=self.parts
	if not parts or self.atRest then return end
	self.atRest=true
	for _,item in ipairs({parts.dial,parts.sprout,parts.pile})do if item then item.part.CFrame=item.rest end end
	for _,loose in ipairs(parts.loose)do loose.part.CFrame=loose.rest end
	if parts.drop then parts.drop.part.CFrame=parts.drop.rest;parts.drop.part.Transparency=1 end
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
	self.t+=dt or 0
	self:aero()
	self:beats()
	if not self:on()then self:rest();return end
	local parts=self:bind()
	if not parts then return end
	local eye=self.d.camera and self.d.camera()
	local centre=parts.model:GetPivot().Position
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
		angle=if crank.kind=="open"then Machine.openAngle(age)else Machine.buyAngle(crank.sched,age)
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
		elseif age>=.1 and age<crank.sched.clunk then
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
				local p=Machine.rollAt(parts.chuteTop.Position,parts.chuteEnd.Position,parts.cup.Position,u)
				local rockLand=if crank.landedAt and age-crank.landedAt<.3 then math.rad(8)*math.sin((age-crank.landedAt)/.3*math.pi)else 0
				drop.part.CFrame=CFrame.new(p)*(parts.cup-parts.cup.Position)*CFrame.Angles(rockLand,0,0)
				drop.part.Color=Color3.fromHex((Corner.machineData().eggTypes or {})[crank.type]or "#FFFFFF")
				drop.part.Transparency=fade
			end
		end
		if not shown and drop.part.Transparency~=1 then drop.part.Transparency=1;drop.part.CFrame=drop.rest end
	end
end
-- The reveal the buy started has ended: the egg in the cup fades FadeAfter later.
function Machine:revealClosed()
	self.revealEndedAt=self.clock()
end
function Machine:destroy()
	if self.destroyed then return end
	self.destroyed=true
	if self.heartbeat then self.heartbeat:Disconnect();self.heartbeat=nil end
	if self.cinematic then
		if self.cinematic.gate then self.cinematic.gate=nil end
		if self.cinematic.onPlay then self.cinematic.onPlay=nil end
	end
	pcall(self.rest,self)
end
return Machine
