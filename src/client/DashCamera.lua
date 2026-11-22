-- Garden Dash camera (V3-DASH-BUILD-PLAN-2026-11-22, slice S7). Pure numbers: it rides the rail itself, behind and
-- above the pet, so it is always over the path and never inside a tree or the bridge. RoomView owns the camera
-- object (enterDash, dashCamera, leaveDash); this only says where it should be. No tables a frame.
-- Reduced Motion: no widening on a dash. There is no shake in any mode.
local Course=require(game:GetService("ReplicatedStorage").Shared.DashCourse)
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

-- A point of the rail for a runner at `cs` (its own place on Main, or along Branch when onStones), `past` cs on
-- from it. viaStones: the runner came over the stones, so what is behind it is the branch. Runs straight on past
-- both ends.
function Camera.rail(cs,onStones,viaStones,past,lane)
	local at=cs+past
	if onStones then
		if at<0 then at+=Course.Fork;onStones=false
		elseif at>Course.StonesLength then at=at-Course.StonesLength+Course.Rejoin;onStones=false end
	elseif viaStones and past<0 and at<Course.Rejoin then
		at=Course.StonesLength-(Course.Rejoin-at)
		if at>=0 then onStones=true else at+=Course.Fork end
	end
	local x,y,z,yaw=Course.at(at,onStones,lane)
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
-- One frame. cs, onStones, lane as Sim.spot; viaStones = the runner took the stones; dashing widens the view.
function Camera:step(dt,cs,onStones,lane,viaStones,dashing,reduced)
	local back=Camera.back(cs,onStones,viaStones)
	local ex,ey,ez=Camera.rail(cs,onStones,viaStones,-back,lane)
	local lx,ly,lz=Camera.rail(cs,onStones,viaStones,Camera.Ahead,lane)
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
return Camera
