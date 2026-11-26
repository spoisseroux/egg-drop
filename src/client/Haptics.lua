-- The one module that vibrates (ASMR-AND-SCALE-LOOK.md sections 0, 1 "In the hand" and 2). Beta and Studio only:
-- Alive "asmr" (the AliveAsmr flag, the beta place or Studio, ConfigService `alive_asmr`, owner chat /alive asmr ...);
-- off, nothing here ever touches a motor. Vibration never carries meaning on its own: everything works the same with it
-- off (the Vibration row in Settings, or a device without a motor).
--
-- Two ways to buzz, chosen per play, both behind one pcall:
--   pad     the last input was a gamepad that answers HapticService:IsVibrationSupported: SetMotor on Gamepad1, each
--           waveform key stepped with task.delay (the path the egg machine already used).
--   effect  otherwise, a HapticEffect (Type Custom, SetWaveformKeys of FloatCurveKeys: time in ms, value 0 to 1) per
--           pattern, made once and parented to the workspace (a local instance). Not proven on a phone yet [check].
-- Every play is also stopped after its pattern's length (plus a margin), so a misread key unit can never leave a motor
-- running.
--
-- The cap (section 2 "The cap"), pure and in Haptics.Gate: at most 6 starts in any 1 s, 70 ms between starts, at most
-- 250 ms of motor-on time in any 1 s (exempt patterns outside it). A `major` pattern (the hatch pop, the deck clear)
-- always plays and cuts what is playing; otherwise a stronger pattern still playing drops a weaker one (never queued),
-- and a stronger one inside the 70 ms gap cuts a weaker one that is still playing.
-- Specs: scripts/HatchAsmr.spec.lua (offline: scripts/run_dash_server_specs.py).
local Haptics={}
Haptics.Window=1;Haptics.MaxStarts=6;Haptics.MinGap=.07;Haptics.Budget=.25
-- HapticEffect keys are in this many units per second (the reference page says milliseconds) [check on a phone].
Haptics.KeyUnits=1000
Haptics.StopMargin=.05

-- segments: {from, to, ms} in order; a gap is {0, 0, ms}. priority: higher wins (section 2, rule 3).
local function pattern(motor,priority,segments,flags)
	flags=flags or {}
	local length,on,peak=0,0,0
	for _,s in ipairs(segments)do
		length+=s[3]/1000
		if s[1]>0 or s[2]>0 then on+=s[3]/1000 end
		peak=math.max(peak,s[1],s[2])
	end
	return table.freeze({motor=motor,priority=priority,segments=table.freeze(segments),length=length,on=on,peak=peak,
		major=flags.major==true,exempt=flags.exempt==true or flags.major==true})
end
Haptics.pattern=pattern
Haptics.Patterns=table.freeze({
	-- The hatch (section 1 "In the hand"): the build is small and sharp, the release is the one big buzz.
	settle=pattern("Small",2,{{.20,.20,20}}),
	crack1=pattern("Small",5,{{.35,.35,25}}),
	crack2=pattern("Small",6,{{.50,.50,30},{0,0,40},{.25,.25,20}}),
	creak=pattern("Small",7,{{.10,.40,180}},{exempt=true}),
	creak_long=pattern("Small",7,{{.10,.50,350}},{exempt=true}),
	pop=pattern("Large",10,{{.90,.90,60},{.90,0,120}},{major=true}),
	jackpot=pattern("Large",10,{{1,1,80},{1,0,200}},{major=true}),
	skip=pattern("Small",4,{{.30,.30,25}}),
	-- Turning Vibration on plays this once, so the player feels what they chose.
	sample=pattern("Small",4,{{.45,.45,30}}),
	-- Pocket Deck merges (section 2 "What buzzes"): length grows with the tier, so on/off motors still tell them apart.
	merge2=pattern("Small",3,{{.30,.30,25}}),
	merge3=pattern("Small",4,{{.45,.45,35}}),
	merge4=pattern("Large",6,{{.55,.55,45}}),
	merge5=pattern("Large",7,{{.75,.75,60},{.75,0,80}}),
	clear=pattern("Large",9,{{1,1,80},{.40,.40,120}},{major=true}),
	-- Deck juice P1 (AERO-JUICE-BRIEF 2, AeroJuice; its switch and this one's): the release and the first contact of my
	-- own board's ball. The lowest priorities, so a merge always wins.
	drop=pattern("Small",1,{{.15,.15,12}}),
	land=pattern("Small",2,{{.25,.25,18}}),
	-- The egg machine's crank ticks (EggMachineClient's light / medium).
	machine_light=pattern("Small",2,{{.30,.30,35}}),
	machine_medium=pattern("Small",3,{{.60,.60,60}}),
})

-- Pure: the merge pattern for a tier and chain. A chain climbs: +0.08 strength per step past the first (up to +0.25),
-- +5 ms on the first segment per step (up to +20 ms), and half a priority step over the plain merge.
local chained={}
function Haptics.mergePattern(tier,chain,cleared)
	if cleared then return Haptics.Patterns.clear end
	tier=math.clamp(math.floor(tonumber(tier)or 2),2,5)
	local steps=math.clamp(math.floor(tonumber(chain)or 1)-1,0,4)
	local base=Haptics.Patterns["merge"..tier]
	if steps==0 then return base end
	local key=tier*10+steps
	if chained[key]then return chained[key]end
	local add,ms=math.min(.25,.08*steps),math.min(20,5*steps)
	local segments={}
	for i,s in ipairs(base.segments)do
		segments[i]={if s[1]>0 then math.min(1,s[1]+add)else 0,if s[2]>0 then math.min(1,s[2]+add)else 0,s[3]+(if i==1 then ms else 0)}
	end
	chained[key]=pattern(base.motor,base.priority+.5,segments)
	return chained[key]
end

-- Pure: the waveform as {ms, value} keys (linear). A step between segments gets its own key 0.5 ms later, so no two
-- keys share a time; the last key is always 0.
function Haptics.keys(p)
	local out,cursor={},0
	for i,s in ipairs(p.segments)do
		local last=out[#out]
		if i==1 then table.insert(out,{0,s[1]})
		elseif last[2]~=s[1]then table.insert(out,{cursor+.5,s[1]})end
		cursor+=s[3]
		table.insert(out,{cursor,s[2]})
	end
	if out[#out][2]~=0 then table.insert(out,{cursor+.5,0})end
	return out
end

-- The cap. Pure: a clock value goes in, a verdict comes out.
local Gate={};Gate.__index=Gate
Haptics.Gate=Gate
function Gate.new()return setmetatable({starts={},playing=nil},Gate)end
-- (true, cut) when `p` may start at `now` (cut: something weaker is still playing and stops); (false, why) when not.
function Gate:try(p,now)
	local starts={}
	for _,s in ipairs(self.starts)do if now-s.at<Haptics.Window then table.insert(starts,s)end end
	self.starts=starts
	local playing=self.playing
	if playing and now>=playing.at+playing.length then playing=nil;self.playing=nil end
	if not p.major then
		if playing and playing.priority>=p.priority then return false,"busy"end
		local last=starts[#starts]
		if last and now-last.at<Haptics.MinGap and not playing then return false,"gap"end
		if #starts>=Haptics.MaxStarts then return false,"count"end
		if not p.exempt then
			local on=0
			for _,s in ipairs(starts)do if not s.exempt then on+=s.on end end
			if on+p.on>Haptics.Budget+1e-9 then return false,"budget"end
		end
	end
	local record={at=now,on=p.on,length=p.length,priority=p.priority,exempt=p.exempt}
	table.insert(self.starts,record)
	self.playing=record
	return true,playing~=nil
end

-- ---------------------------------------------------------------- the device side (lazy: specs never reach it)

local gate=Gate.new()
local enabled=true
local focused=true
local clock=os.clock
local engine
local function services()
	if engine then return engine end
	engine={effects={},epoch=0}
	local ok=pcall(function()
		local input=game:GetService("UserInputService")
		engine.input=input
		engine.haptic=game:GetService("HapticService")
		input.WindowFocusReleased:Connect(function()focused=false;Haptics.stop()end)
		input.WindowFocused:Connect(function()focused=true end)
	end)
	engine.ready=ok
	return engine
end

-- The switch: Alive "asmr" (its ceiling and the server's attribute). Specs can replace it.
function Haptics.switch()
	local ok,on=pcall(function()
		return require(game:GetService("ReplicatedStorage").Shared.Alive).on("asmr")
	end)
	return ok and on==true
end
local function padType()
	local e=services()
	if not e.ready then return nil end
	local ok,pad=pcall(function()
		local last=e.input:GetLastInputType()
		if not string.match(last.Name,"^Gamepad")then return nil end
		local slot=Enum.UserInputType.Gamepad1
		if e.haptic:IsVibrationSupported(slot)then return slot end
		return nil
	end)
	return if ok then pad else nil
end
local function anyPad()
	local e=services()
	if not e.ready then return false end
	local ok,yes=pcall(function()return e.haptic:IsVibrationSupported(Enum.UserInputType.Gamepad1)end)
	return ok and yes==true
end
local function effectFor(name,p)
	local e=services()
	if e.effects[name]~=nil then return e.effects[name]or nil end
	local ok,effect=pcall(function()
		local effect=Instance.new("HapticEffect")
		effect.Type=Enum.HapticEffectType.Custom
		local keys={}
		for _,k in ipairs(Haptics.keys(p))do
			table.insert(keys,FloatCurveKey.new(k[1]/1000*Haptics.KeyUnits,k[2],Enum.KeyInterpolationMode.Linear))
		end
		effect:SetWaveformKeys(keys)
		effect.Parent=workspace
		return effect
	end)
	e.effects[name]=if ok then effect else false
	return if ok then effect else nil
end
-- Can this device buzz at all? A gamepad that vibrates, or a touch screen where a HapticEffect can be made (tablets
-- without a motor still say yes: there is no way to ask) [check].
function Haptics.supported()
	if anyPad()then return true end
	local e=services()
	if not e.ready then return false end
	local touch=false
	pcall(function()touch=e.input.TouchEnabled==true end)
	return touch and effectFor("sample",Haptics.Patterns.sample)~=nil
end
-- Show the Settings row? The switch is on and the device can buzz.
function Haptics.available()return Haptics.switch()and Haptics.supported()end
function Haptics.isEnabled()return enabled end
function Haptics.setEnabled(on)
	enabled=on==true
	if not enabled then Haptics.stop()end
	return enabled
end

local function stopPad(e,slot)
	pcall(function()
		e.haptic:SetMotor(slot,Enum.VibrationMotor.Small,0)
		e.haptic:SetMotor(slot,Enum.VibrationMotor.Large,0)
	end)
end
-- Stops whatever plays and bumps the epoch, so every delayed key and stop of an earlier play goes quiet. Every start
-- calls it first (one token per play: an earlier play's late stop can never cut, or re-arm, a later one). The last pad
-- used is always zeroed, even after its own final stop.
function Haptics.stop()
	local e=engine
	if not e then return end
	e.epoch+=1
	if e.current then pcall(function()e.current:Stop()end);e.current=nil end
	if e.lastSlot then stopPad(e,e.lastSlot)end
end

local function playPad(e,slot,p)
	local motor=Enum.VibrationMotor.Small
	if p.motor=="Large"then
		local ok,yes=pcall(function()return e.haptic:IsMotorSupported(slot,Enum.VibrationMotor.Large)end)
		if ok and yes then motor=Enum.VibrationMotor.Large end
	end
	local epoch=e.epoch
	e.lastSlot=slot
	for _,k in ipairs(Haptics.keys(p))do
		local function set()if e.epoch==epoch then pcall(function()e.haptic:SetMotor(slot,motor,k[2])end)end end
		if k[1]<=0 then set()else task.delay(k[1]/1000,set)end
	end
	task.delay(p.length+Haptics.StopMargin,function()if e.epoch==epoch then stopPad(e,slot)end end)
end
local function playEffect(e,name,p)
	local effect=effectFor(name,p)
	if not effect then return false end
	local epoch=e.epoch
	e.current=effect
	effect:Play()
	task.delay(p.length+Haptics.StopMargin,function()
		if e.epoch==epoch and e.current==effect then pcall(function()effect:Stop()end);e.current=nil end
	end)
	return true
end

-- Buzz a named pattern (or a pattern table with a name). False when off, unsupported or capped.
function Haptics.play(name,p)
	p=p or Haptics.Patterns[name]
	if not p or not enabled or not focused or not Haptics.switch()then return false end
	local e=services()
	if not e.ready then return false end
	local ok=gate:try(p,clock())
	if not ok then return false end
	Haptics.stop()
	local played=false
	pcall(function()
		local slot=padType()
		if slot then playPad(e,slot,p);played=true
		else played=playEffect(e,name,p)end
	end)
	return played
end
-- A Pocket Deck merge (only the local player's own board calls this).
function Haptics.merge(tier,chain,cleared)
	local p=Haptics.mergePattern(tier,chain,cleared)
	local name=if cleared then "clear"else "merge"..math.clamp(math.floor(tonumber(tier)or 2),2,5).."_"..math.clamp(math.floor(tonumber(chain)or 1),1,5)
	return Haptics.play(name,p)
end
return Haptics
