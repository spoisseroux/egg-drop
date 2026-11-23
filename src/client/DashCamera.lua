-- Garden Dash camera (V3-DASH-BUILD-PLAN-2026-11-22, slice S7). Pure numbers: it rides the rail itself, behind and
-- above the pet, so it is always over the path and never inside a tree or the bridge. RoomView owns the camera
-- object (enterDash, dashCamera, leaveDash); this only says where it should be. No tables a frame.
-- Reduced Motion: no widening on a dash. There is no shake in any mode.
local Course=require(game:GetService("ReplicatedStorage").Shared.DashCourse)
local Grid=require(game:GetService("ReplicatedStorage").Shared.DashGrid)
local Camera={};Camera.__index=Camera
Camera.Back=1400 -- WORLD-PLAN section 2: about 14 back, 9 up, 25 degrees down
Camera.Ahead=250
Camera.EyeHeight=9 -- under the start arch's banner (10.4 up) and over the finish banner (5.25)
Camera.StartRoom=600 -- how far behind the start line the eye may stand: the cliff is at its back
Camera.LookHeight=1.3
Camera.Fov=58
Camera.DashFov=64
Camera.Follow=9 -- how quickly it closes in, per second
Camera.FovFollow=5
Camera.SnapStuds=24
-- Beta 12 U5, the line-up shot: from the lock to GO the eye stands behind and above the whole row, so eight racers 1.5
-- studs apart fill at most RowShare of the screen's width; at GO it eases to the rail camera over LineupBlend s.
Camera.RowShare=.7
Camera.RowHalf=3.5*Grid.StartStep/100+.6 -- the outer racer's centre and most of a pet
Camera.LineupPitch=math.rad(25)
-- TUNE HERE: the one number for how far behind the start line the line-up eye may stand, in studs. 6 puts it near x 78,
-- by the cliff rock east of the start; lower it if Studio shows the rock clipping at 16:9 or 4:3 (the eye then rises
-- instead, up to LineupHigh, and the row may pass RowShare on wide-but-short screens).
Camera.LineupBack=6
Camera.LineupLow=3
Camera.LineupHigh=10.2 -- under the start arch's banner
Camera.LineupBlend=.6

-- A point of the rail for a runner at `cs` (its own place on Main, or along Branch when onStones), `past` cs on
-- from it. viaStones: the runner came over the stones, so what is behind it is the branch. Runs straight on past
-- both ends.
function Camera.rail(cs,onStones,viaStones,past,lane,count)
	local at=cs+past
	if onStones then
		if at<0 then at+=Course.Fork;onStones=false
		elseif at>Course.StonesLength then at=at-Course.StonesLength+Course.Rejoin;onStones=false end
	elseif viaStones and past<0 and at<Course.Rejoin then
		at=Course.StonesLength-(Course.Rejoin-at)
		if at>=0 then onStones=true else at+=Course.Fork end
	end
	local x,y,z,yaw=Grid.at(at,onStones,lane,count)
	local extra=if onStones then 0 elseif at<0 then at elseif at>Course.Length then at-Course.Length else 0
	if extra~=0 then x+=math.sin(yaw)*extra/100;z+=math.cos(yaw)*extra/100 end
	return x,y,z,yaw
end
-- How far behind the pet the eye rides: closer by the start, where there is no room.
function Camera.back(cs,onStones,viaStones)
	if onStones or viaStones then return Camera.Back end
	return math.min(Camera.Back,math.max(0,cs)+Camera.StartRoom)
end
function Camera.new()
	return setmetatable({ready=false,ex=0,ey=0,ez=0,lx=0,ly=0,lz=0,fov=Camera.Fov},Camera)
end
function Camera:reset()self.ready=false;self.fov=Camera.Fov end
-- One frame. cs, onStones, lane as Sim.spot; viaStones = the runner took the stones; dashing widens the view; count: the
-- racers in the heat (DashGrid).
function Camera:step(dt,cs,onStones,lane,viaStones,dashing,reduced,count)
	local back=Camera.back(cs,onStones,viaStones)
	local ex,ey,ez=Camera.rail(cs,onStones,viaStones,-back,lane,count)
	local lx,ly,lz=Camera.rail(cs,onStones,viaStones,Camera.Ahead,lane,count)
	-- The same angle down wherever the eye is.
	ey+=Camera.LookHeight+(Camera.EyeHeight-Camera.LookHeight)*(back+Camera.Ahead)/(Camera.Back+Camera.Ahead)
	ly+=Camera.LookHeight
	local far=math.abs(ex-self.ex)+math.abs(ez-self.ez)>Camera.SnapStuds
	if not self.ready or far then
		self.ready=true
		self.ex,self.ey,self.ez,self.lx,self.ly,self.lz=ex,ey,ez,lx,ly,lz
	else
		local k=1-math.exp(-Camera.Follow*math.clamp(dt,0,.25))
		self.ex+=(ex-self.ex)*k;self.ey+=(ey-self.ey)*k;self.ez+=(ez-self.ez)*k
		self.lx+=(lx-self.lx)*k;self.ly+=(ly-self.ly)*k;self.lz+=(lz-self.lz)*k
	end
	local fov=if dashing and not reduced then Camera.DashFov else Camera.Fov
	if reduced then self.fov=fov else self.fov+=(fov-self.fov)*(1-math.exp(-Camera.FovFollow*math.clamp(dt,0,.25)))end
end
-- Pure: the line-up shot for a screen of this aspect (width / height): eye x, y, z, then the look point. The eye is
-- straight behind the middle of the line; how far is what makes the row RowShare of the width at Fov.
function Camera.lineupDistance(aspect)
	local half=math.tan(math.rad(Camera.Fov)/2)*math.max(.5,aspect or 16/9)
	return Camera.RowHalf/(Camera.RowShare*half)
end
-- FABLE-REVIEW-R1 6: the shot fits the racers present, not eight: its back distance and height scale by
-- max(.5, (span + 3) / 13.5), span = (count - 1) x 1.5 studs (eight: 1, as before; four: .56, so the row fills 55 to
-- 65% of the width and the gate posts leave the frame). A missing count is eight.
function Camera.lineupScale(count)
	local n=if type(count)=="number"and count>=1 then math.min(math.floor(count),Course.LaneCount)else Course.LaneCount
	return math.max(.5,((n-1)*Grid.StartStep/100+3)/13.5)
end
function Camera.lineup(aspect,count)
	local x,y,z,yaw=Course.at(0)
	local want=Camera.lineupDistance(aspect)
	local back=math.min(Camera.LineupBack,want*math.cos(Camera.LineupPitch))
	local up=math.clamp(math.sqrt(math.max(0,want*want-back*back)),math.max(Camera.LineupLow,back*math.tan(Camera.LineupPitch)),Camera.LineupHigh)
	local scale=Camera.lineupScale(count)
	back,up=back*scale,up*scale
	local fx,fz=math.sin(yaw),math.cos(yaw)
	return x-fx*back,y+Camera.LookHeight+up,z-fz*back,x+fx,y+Camera.LookHeight,z+fz
end
-- 0 before GO (the line-up), 1 once the rail camera has it; eased. Reduced Motion: a cut at GO.
function Camera.lineupBlend(since,reduced)
	if since<=0 then return 0 end
	if reduced or since>=Camera.LineupBlend then return 1 end
	local t=since/Camera.LineupBlend
	return t*t*(3-2*t)
end
return Camera
