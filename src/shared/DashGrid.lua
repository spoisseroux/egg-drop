-- Garden Dash start grid (DASH-DECK-UI-BUILD-PLAN, beta 12 QA U5). Where a lane is drawn: the racers stand 1.5 studs
-- apart at the start line, then ease onto the 0.5-stud race lanes between 3 and 11 studs past it (smoothstep), so
-- everyone is on the path before the first hoop (14 studs at the earliest). Lanes are centred on the racers present:
-- a racer's slot is its lane minus (count + 1) / 2 (DashSim deals lanes as a shuffle of 1..count), and an odd count
-- stands half a slot over at the line so every pet is on a Pad_ slab, easing back to the centre with the funnel.
-- Drawing only: the race counts the centre line (DashSim), so nothing here changes a result. Pure maths, no instances.
-- scripts/build_dash_course.py measures the waiting pad against the same numbers (DashCourse.spec checks they agree).
local Course=require(script.Parent.DashCourse)
local Grid={}
Grid.StartStep=150 -- cs between lanes at the line
Grid.RaceStep=50   -- cs between lanes from FunnelTo on (DashCourse.LaneStep)
Grid.FunnelFrom=300
Grid.FunnelTo=1100
Grid.Slabs=8       -- the start pad slabs, one per possible racer
Grid.PostOut=640   -- the start arch's posts, cs from the centre line
Grid.PostHalf=35   -- half a post's width

local function smooth(t)return t*t*(3-2*t)end
-- 0 at the line (and before it), 1 once the funnel is done.
function Grid.blend(cs,onStones)
	if onStones or cs>=Grid.FunnelTo then return 1 end
	if cs<=Grid.FunnelFrom then return 0 end
	return smooth((cs-Grid.FunnelFrom)/(Grid.FunnelTo-Grid.FunnelFrom))
end
-- The step between lanes at this point, in cs.
function Grid.step(cs,onStones)
	return Grid.StartStep+(Grid.RaceStep-Grid.StartStep)*Grid.blend(cs,onStones)
end
-- The racer's sideways offset in cs. lane: its dealt lane (1..count); count: the racers in the heat (missing = 8).
function Grid.offset(cs,onStones,lane,count)
	if type(lane)~="number"then return 0 end
	count=if type(count)=="number"and count>=1 then math.min(math.floor(count),Grid.Slabs)else Grid.Slabs
	local slot=lane-(count+1)/2
	local b=Grid.blend(cs,onStones)
	if count%2==1 then slot+=.5*(1-b)end
	return slot*(Grid.StartStep+(Grid.RaceStep-Grid.StartStep)*b)
end
-- Half the width the start takes at a distance along Main, in studs: the posts at the line, then the outer racer of
-- eight plus most of a pet. The waiting pad must stay this far plus its radius plus a stud from every point.
function Grid.halfWidth(cs)
	if cs<=0 then return(Grid.PostOut+Grid.PostHalf)/100 end
	return 3.5*Grid.step(cs,false)/100+.6
end
-- Where to draw a runner: DashCourse.at's centre line moved sideways along the same normal DashCourse uses.
function Grid.at(cs,onStones,lane,count)
	local x,y,z,yaw=Course.at(cs,onStones)
	local o=Grid.offset(cs,onStones,lane,count)/100
	if o~=0 then x-=math.cos(yaw)*o;z+=math.sin(yaw)*o end
	return x,y,z,yaw
end
return table.freeze(Grid)
