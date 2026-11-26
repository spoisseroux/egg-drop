-- The Wobble Egg (artifacts/qa-2026-11-26-beta34/GARDEN-PLAY-BRIEF.md section 3; Spencer, beta 34: "make the egg
-- decoration on the rock more interesting/animated/a bit textured"). The big egg on the crag at the rock spur's tip
-- (the beta world's W7_CD_Landmarks__palette, about (17, -45)) is redrawn as the game's own Companion Egg (cream, blue
-- spots, the green band: the egg every player hatches first) in a twig-and-moss collar. It rocks gently, and now and
-- then gives a big wobble; walking up to it sets one off. At night its spots glow faintly. It never hatches.
-- Shared and pure: the motion and the timetable. WobbleEggClient builds it behind the Alive switch `wobble`.
local Egg={}

Egg.LandmarkName="W7_CD_Landmarks__palette"
-- The landmark's measured bounds (Studio, beta 34): centre about (17, 17.2, -45), 4.7 x 5.5 x 4.7. The client takes the
-- live part's own CFrame and size; these are only for the sanity check that it found the egg, not some other piece.
Egg.Expected=table.freeze({centre=Vector3.new(17,17.2,-45),size=Vector3.new(4.7,5.53,4.7),slack=3})
-- The Companion Egg's mesh pair is 1.3 studs tall at scale 1 (EggModels: bottom 0..0.82, top to 1.30).
Egg.MeshHeight=1.3

-- Motion (degrees, seconds).
Egg.Idle=table.freeze({degrees=2,period=5})
Egg.Big=table.freeze({degrees=7,swings=2,settle=1.6})
Egg.Gap=table.freeze({min=35,max=50})  -- between big wobbles on its own
Egg.Near=8                             -- a player this close sets one off
Egg.Cooldown=4                         -- between set-off wobbles
Egg.Hear=40                            -- the wobble's sound reaches this far
-- Night: the glow fades in below this daylight (the lamps' rule) and is full at Night.full.
Egg.Night=table.freeze({start=.3,full=.1,colour=Color3.fromHex("#9FD8FF"),range=10,brightness=.4})

-- Pure: is this part the landmark egg? (name, size and place close to the measured ones)
function Egg.isLandmark(name,position,size)
	if name~=Egg.LandmarkName then return false end
	local E=Egg.Expected
	if typeof(position)~="Vector3"or typeof(size)~="Vector3"then return false end
	return(position-E.centre).Magnitude<=E.slack and math.abs(size.Y-E.size.Y)<=1.5 and math.abs(size.X-E.size.X)<=1.5
end

-- Pure: the scale that makes the Companion Egg as tall as the landmark.
function Egg.scaleFor(height)
	if type(height)~="number"or height~=height or height<=0 then return 1 end
	return height/Egg.MeshHeight
end

-- Pure: the next big wobble's time after `now`, from a number in [0, 1).
function Egg.nextBig(now,roll)
	roll=math.clamp(tonumber(roll)or .5,0,1)
	return now+Egg.Gap.min+(Egg.Gap.max-Egg.Gap.min)*roll
end

-- Pure: the big wobble's angle (degrees) `t` seconds after it began; nil once it has settled. Two full swings that
-- shrink, then a soft settle, so it reads as an egg that nearly tipped and caught itself.
function Egg.bigAngle(t)
	local B=Egg.Big
	if t<0 or t>=B.settle then return nil end
	local u=t/B.settle
	return B.degrees*math.sin(u*math.pi*2*B.swings)*(1-u)^1.5
end

-- Pure: the idle rock (degrees) at time `t`, with a phase so it never starts in step with anything else.
function Egg.idleAngle(t,phase)
	return Egg.Idle.degrees*math.sin((t/Egg.Idle.period+(phase or 0))*math.pi*2)
end

-- Pure: the tilt at `t`: the big wobble if one is running (it replaces the idle rock), else the idle rock.
-- `bigAt` is when the current big wobble began (nil for none); reduced motion keeps it still.
function Egg.angle(t,bigAt,phase,reduced)
	if reduced then return 0 end
	if bigAt then
		local big=Egg.bigAngle(t-bigAt)
		if big then return big end
	end
	return Egg.idleAngle(t,phase)
end

-- Pure: may a player at `distance` set off a wobble now? (in reach, and the cooldown since the last one has passed)
function Egg.setOff(distance,now,lastBig)
	if type(distance)~="number"or distance>Egg.Near then return false end
	return lastBig==nil or now-lastBig>=Egg.Cooldown+Egg.Big.settle
end

-- Pure: how much the night glow shows (0 day .. 1 night) for a daylight in [0, 1].
function Egg.glow(daylight)
	local N=Egg.Night
	daylight=tonumber(daylight)or 1
	if daylight>=N.start then return 0 end
	if daylight<=N.full then return 1 end
	return(N.start-daylight)/(N.start-N.full)
end

return table.freeze(Egg)
