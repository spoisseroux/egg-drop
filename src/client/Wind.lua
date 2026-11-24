-- One wind for the whole garden (ALIVE-BRIEF-2026-11-22 section 3). Pure: no instances, no state, no
-- network. A gust is a front that crosses the island at Speed; gust number N (its start, strength and
-- whether it is skipped) is a hash of N, so every client that agrees on the time sees the same gust at
-- the same place. The time is workspace:GetServerTimeNow() (the caller passes it in).
local Wind={}

-- The one dial (0 to 1.5). It scales the answer; nothing ever reads more than 1.
Wind.Strength=1
-- Fixed: from the hub out toward Tumble Falls. West to east, 20 degrees toward -Z (the falls are at
-- X 77, Z -77 and the hub is at X -30, Z 4).
Wind.Direction=Vector3.new(math.cos(math.rad(20)),0,-math.sin(math.rad(20)))
Wind.Speed=14
Wind.Rise,Wind.Fade=.8,2.7
-- One gust slot every 12.5 s, each start moved by up to 1.75 s: 9 to 16 s from one start to the next.
Wind.Slot,Wind.Jitter=12.5,1.75
Wind.PeakMin=.6
-- Slot N is skipped when its roll is under both neighbours' rolls and under SkipBelow: 3 in 10 (the
-- integral of (1-x)^2), and never two in a row, so a lull stays under half a minute.
Wind.SkipBelow=1-.1^(1/3)
Wind.Breeze,Wind.BreezeSwing,Wind.BreezePeriod=.2,.05,11

local TAU=math.pi*2
local TWO32=4294967296

-- The low 32 bits of a*b for 32-bit unsigned a and b, exact in doubles.
local function mul32(a,b)
	local low=bit32.band(a,0xFFFF)*b
	local high=(bit32.rshift(a,16)*b)%65536
	return(low+high*65536)%TWO32
end

-- Seeded roll in [0, 1) for gust number n.
function Wind.hash(n,salt)
	local h=(n+(salt or 0)*2654435761)%TWO32
	h=mul32(bit32.bxor(h,bit32.rshift(h,16)),0x7FEB352D)
	h=mul32(bit32.bxor(h,bit32.rshift(h,15)),0x846CA68B)
	return bit32.bxor(h,bit32.rshift(h,16))/TWO32
end

function Wind.skipped(n)
	local roll=Wind.hash(n,1)
	return roll<Wind.SkipBelow and roll<Wind.hash(n-1,1)and roll<Wind.hash(n+1,1)
end
-- Seconds at which gust n passes the world origin, and its strength (0 = a skipped slot).
function Wind.start(n)
	return n*Wind.Slot+(Wind.hash(n,2)*2-1)*Wind.Jitter
end
function Wind.peak(n)
	if Wind.skipped(n)then return 0 end
	return Wind.PeakMin+(1-Wind.PeakMin)*Wind.hash(n,3)
end

local function smooth(x)
	x=math.clamp(x,0,1)
	return x*x*(3-2*x)
end
-- 0 to 1 to 0 for a gust that reached this place `age` seconds ago.
function Wind.envelope(age)
	if age<=0 or age>=Wind.Rise+Wind.Fade then return 0 end
	if age<Wind.Rise then return smooth(age/Wind.Rise)end
	return 1-smooth((age-Wind.Rise)/Wind.Fade)
end

local function finite(x)return type(x)=="number"and x==x and x<math.huge and x>-math.huge end
local function strength()
	return if finite(Wind.Strength)then math.clamp(Wind.Strength,0,1.5)else 1
end

-- The wind's own clock at a place: the same gust arrives Speed studs downwind one second later.
-- nil for anything that is not a real place and time.
function Wind.localTime(position,time)
	if typeof(position)~="Vector3"or not finite(time)then return nil end
	local t=time-position:Dot(Wind.Direction)/Wind.Speed
	return if finite(t)then t else nil
end

local function rawGust(t)
	local base=math.floor(t/Wind.Slot)
	local best=0
	-- A gust lasts 3.5 s from its start, so only this slot and the next (moved early) can be blowing.
	for n=base,base+1 do
		local shape=Wind.envelope(t-Wind.start(n))
		if shape>0 then best=math.max(best,shape*Wind.peak(n))end
	end
	return best
end
local function rawBreeze(t)
	return Wind.Breeze+Wind.BreezeSwing*math.sin(TAU*((t%Wind.BreezePeriod)/Wind.BreezePeriod))
end

-- 0 at rest, up to 1 as a gust passes (no breeze): flags, chimes, rustle.
function Wind.gust(position,time)
	local t=Wind.localTime(position,time)
	return if t then math.clamp(rawGust(t)*strength(),0,1)else 0
end
-- 0 to 1, breeze and gust together: anything that sways. 0 when the place or time is not a number.
function Wind.at(position,time)
	local t=Wind.localTime(position,time)
	if not t then return 0 end
	local breeze=rawBreeze(t)
	return math.clamp((breeze+(1-breeze)*rawGust(t))*strength(),0,1)
end

-- The big breath (beta 14 QA W3 row 1, WORLD-AND-NEST-LOOK section 1; GARDEN-LIFE-BUILD-PLAN): a long, strong gust on
-- its own schedule on top of the normal gusts, the same on every client. Breath b starts at b * BreathSlot moved by up
-- to BreathJitter (so every gap is 240 to 360 s), eases up over BreathRise, holds BreathHold, eases out over BreathFade,
-- and crosses the island as a front like a gust. Opt in only (architect r1): Wind.gust and Wind.at never include it;
-- consumers read Wind.breath / Wind.blow / Wind.swayAt, and only while the Alive `scene` switch is on.
Wind.BreathSlot,Wind.BreathJitter=300,30
Wind.BreathRise,Wind.BreathHold,Wind.BreathFade=2.5,3,5
Wind.BreathLength=Wind.BreathRise+Wind.BreathHold+Wind.BreathFade

-- Seconds at which breath b passes the world origin.
function Wind.breathStart(b)
	return b*Wind.BreathSlot+(Wind.hash(b,21)*2-1)*Wind.BreathJitter
end
-- 0 to 1 to 0 for a breath that reached this place `age` seconds ago.
function Wind.breathEnvelope(age)
	if type(age)~="number"or age~=age or age<=0 or age>=Wind.BreathLength then return 0 end
	if age<Wind.BreathRise then return smooth(age/Wind.BreathRise)end
	if age<Wind.BreathRise+Wind.BreathHold then return 1 end
	return 1-smooth((age-Wind.BreathRise-Wind.BreathHold)/Wind.BreathFade)
end
-- The breath at the wind's local time t: its strength (0 to 1) and its number (nil when none is blowing).
local function rawBreath(t)
	local base=math.floor(t/Wind.BreathSlot)
	for b=base,base+1 do
		local shape=Wind.breathEnvelope(t-Wind.breathStart(b))
		if shape>0 then return shape,b end
	end
	return 0,nil
end
-- 0 at rest, up to 1 while the breath passes this place; and the breath's number.
function Wind.breath(position,time)
	local t=Wind.localTime(position,time)
	if not t then return 0,nil end
	local shape,b=rawBreath(t)
	return math.clamp(shape*strength(),0,1),b
end
-- The gust or the breath, whichever is stronger here (0 to 1): what leaves' spawn rate and the scud answer.
function Wind.blow(position,time)
	return math.max(Wind.gust(position,time),(Wind.breath(position,time)))
end
-- Wind.at with the breath in it: for swaying things whose owner has the `scene` switch on (crowns, chimes, flags,
-- hanging Dewdrops). Never used for what falls (LifeSim's drops read Wind.at).
function Wind.swayAt(position,time)
	local t=Wind.localTime(position,time)
	if not t then return 0 end
	local breeze=rawBreeze(t)
	return math.clamp((breeze+(1-breeze)*math.max(rawGust(t),(rawBreath(t))))*strength(),0,1)
end

return Wind
