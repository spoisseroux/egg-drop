-- Onboarding v2 step 3: where the first Bear's egg cracks, as data (Spencer, beta 36: "can we make the cracking on the
-- egg not a 2d texture ... shrinkwrapped to the 3d egg mesh?"; Fable's review of the beta 37 captures, FABLE-REVIEW-B37
-- sections 4-5). Pure and seeded, so specs can walk it and the look (EggCrack3D) can change without touching it.
-- The shell is an egg-shaped ellipsoid in the Companion Egg's own units (EggModels: base at y 0, top at 1.30, widest
-- at 0.55); a surface point is (theta, v): theta round the egg (0 = +Z, pi = -Z, the side facing the camera), v from -1
-- (bottom pole) to 1 (top). Paths are walked on the surface in studs (the garden egg is Paths.Studs times the model):
--   * segments 0.06 to 0.15 studs (short chords hug the curve), each turn jittered up to 35 degrees, never a regular
--     zig-zag; a gentle pull keeps the main runs near the shells' seam height;
--   * width 0.035 studs at the tap point tapering to 0.008 at the tips; a branch starts at 60% of its parent's width,
--     leaves at 35 to 60 degrees and runs 40% of its parent's length; a junction chip marks each fork; no spurs at right
--     angles;
--   * tap 1: a run each way from the tap point; tap 2: both run on further, fork, and carry the cream leak; tap 3: they
--     run on round the egg and meet at the back, completing the ring (only tap 3 does).
-- Segment: {a = {theta, v}, b = {theta, v}, stage, order (0..1: distance from the tap, so growth runs outward), width
-- (studs), heading (radians in the surface's tangent plane: 0 = round the egg, pi/2 = up), run, branch, leak}.
-- Chip: {at = {theta, v}, stage, order, heading}.
local Paths={}
Paths.Shape=table.freeze({y0=.55,rx=.5,top=.75,bottom=.55,seamV=.27})
Paths.Studs=1.25 -- StorkModel.Egg.Scale: model units to studs
Paths.Walk=table.freeze({minStep=.06,maxStep=.15,jitter=math.rad(35),pull=.35,
	widthTap=.035,widthTip=.008,branchWidth=.6,branchMin=math.rad(35),branchMax=math.rad(60),branchLength=.4,
	-- studs each side per stage (tap 1, tap 2, and tap 3 runs on to meet at the back)
	run1=.38,run2=.55})

-- Pure: the surface point (model units, the egg's own frame) and its outward normal at (theta, v).
function Paths.point(theta,v)
	local S=Paths.Shape
	v=math.clamp(v,-.98,.98)
	local ry=if v>=0 then S.top else S.bottom
	local r=S.rx*math.sqrt(1-v*v)
	return Vector3.new(r*math.sin(theta),S.y0+v*ry,r*math.cos(theta))
end
function Paths.normal(theta,v)
	local S=Paths.Shape
	local p=Paths.point(theta,v)
	local ry=if v>=0 then S.top else S.bottom
	local n=Vector3.new(p.X/(S.rx*S.rx),(p.Y-S.y0)/(ry*ry),p.Z/(S.rx*S.rx))
	return n/math.max(1e-6,n.Magnitude)
end
-- Pure: the surface's local scale at v (model units of arc per radian of theta, per unit of v).
local function metric(v)
	local S=Paths.Shape
	v=math.clamp(v,-.98,.98)
	local ry=if v>=0 then S.top else S.bottom
	local r=S.rx*math.sqrt(1-v*v)
	-- d(point)/dv: the radius shrinks as well as the height grows
	local dr=S.rx*(-v)/math.sqrt(1-v*v)
	return math.max(.05,r),math.sqrt(ry*ry+dr*dr)
end
-- Pure: one step of `length` studs from `at` at `heading` (0 = round the egg toward larger theta, pi/2 = up).
function Paths.step(at,heading,length)
	local units=length/Paths.Studs
	local mr,mv=metric(at[2])
	local b={at[1]+units*math.cos(heading)/mr,at[2]+units*math.sin(heading)/mv}
	-- again with the surface's scale at the step's middle, so the step's own heading is the one asked for
	mr,mv=metric((at[2]+b[2])/2)
	return{at[1]+units*math.cos(heading)/mr,math.clamp(at[2]+units*math.sin(heading)/mv,-.7,.75)}
end
-- Pure: the chord between two surface points, in studs.
function Paths.chord(a,b)return(Paths.point(b[1],b[2])-Paths.point(a[1],a[2])).Magnitude*Paths.Studs end
-- Pure: the heading (radians, tangent plane) from a to b.
function Paths.heading(a,b)
	local mr,mv=metric((a[2]+b[2])/2)
	return math.atan2((b[2]-a[2])*mv,(b[1]-a[1])*mr)
end
-- A small seeded generator (an LCG): the same egg cracks the same way for the same seed.
local function rng(seed)
	local s=math.floor(math.abs(seed or 1))%2147483646+1
	return function()s=(s*16807)%2147483647;return s/2147483647 end
end
local function wrap(a)return((a+math.pi)%(math.pi*2))-math.pi end

-- Walk one run: from `from` along `heading` for `length` studs; widths from w0 to w1; distance d0 at the start (for
-- the outward order). target(theta) -> the v to drift toward, or nil. Appends segments; returns the end, its heading,
-- the distance there and the vertices walked ({at, heading, width, dist}).
local function walk(out,rand,from,heading,length,w0,w1,d0,stage,base,dmax,target,extra)
	local W=Paths.Walk
	local at,h,done=from,heading,0
	local verts={}
	local mainHeading=heading
	while done<length-1e-6 do
		-- 0.06 to 0.15 studs, the last ones split so none is shorter than 0.06 (unless the whole run is)
		local remaining=length-done
		local step
		if remaining<=W.maxStep then step=remaining
		elseif remaining<W.maxStep+W.minStep then step=remaining/2
		else
			step=W.minStep+rand()*(W.maxStep-W.minStep)
			if remaining-step<W.minStep then step=remaining-W.minStep end
		end
		-- jitter the turn, pulled back toward the run's own direction (and the target height), never past 35 degrees
		local want=mainHeading
		if target then
			local tv=target(at[1])
			if tv then want+=math.clamp((tv-at[2])*4,-.6,.6)*(if math.cos(mainHeading)>=0 then 1 else -1)end
		end
		local turn=(rand()*2-1)*W.jitter+wrap(want-h)*W.pull
		turn=math.clamp(turn,-W.jitter,W.jitter)
		h=h+turn
		local nextAt=Paths.step(at,h,step)
		h=Paths.heading(at,nextAt) -- turns are measured on the shell, from the step actually taken
		local u0,u1=done/length,(done+step)/length
		local seg={a=at,b=nextAt,stage=stage,order=math.clamp((base+d0+done)/dmax,0,1),
			width=w0+(w1-w0)*(u0+u1)/2,heading=Paths.heading(at,nextAt)}
		for k,v in pairs(extra or {})do seg[k]=v end
		table.insert(out,seg)
		table.insert(verts,{at=nextAt,heading=seg.heading,width=w0+(w1-w0)*u1,dist=d0+done+step})
		done+=step;at=nextAt
	end
	return at,h,d0+length,verts
end

-- Pure: the whole crack for one egg. tap: {theta, v} where tap 1 landed (default: the front, at the seam). seed: any
-- number. Returns segments, chips.
function Paths.build(tap,seed)
	local S,W=Paths.Shape,Paths.Walk
	local rand=rng(seed or 7)
	local start={(tap and tap[1])or math.pi,math.clamp((tap and tap[2])or S.seamV,-.45,.6)}
	local segs,chips={},{}
	local seam=function()return S.seamV end
	-- the ring: the circumference at the seam, in studs (both sides meet at the back)
	local mr=metric(S.seamV)
	local half=math.pi*mr*Paths.Studs
	local total=half -- the longest distance from the tap (the back)
	local width=function(d)return W.widthTap+(W.widthTip-W.widthTap)*math.clamp(d/(W.run1+W.run2),0,1)end
	local ends={}
	for side,dir in ipairs({0,math.pi})do
		local h=dir+(rand()*2-1)*.25
		-- tap 1
		local at1,h1,d1,v1=walk(segs,rand,start,h,W.run1,width(0),width(W.run1),0,1,0,total,nil,{run=side})
		-- tap 2: on, with the light leak
		local at2,h2,d2,v2=walk(segs,rand,at1,h1,W.run2,width(W.run1),W.widthTip,d1,2,0,total,seam,{run=side,leak=true})
		-- a fork on each of taps 1 and 2: 35 to 60 degrees off the parent, 40% of its length, 60% of its width
		for stage,verts in ipairs({v1,v2})do
			local pick=verts[math.max(1,math.floor(#verts*(.4+.3*rand())))]
			if pick then
				local sign=if rand()<.5 then -1 else 1
				local angle=W.branchMin+rand()*(W.branchMax-W.branchMin)
				local parentLength=if stage==1 then W.run1 else W.run2
				walk(segs,rand,pick.at,pick.heading+sign*angle,parentLength*W.branchLength,pick.width*W.branchWidth,W.widthTip,pick.dist,stage,0,total,nil,{run=side,branch=true,parent=pick.heading,angle=angle})
				table.insert(chips,{at=pick.at,stage=stage,order=math.clamp(pick.dist/total,0,1),heading=pick.heading})
			end
		end
		ends[side]={at=at2,heading=h2,dist=d2}
	end
	-- tap 3: both ends run on round the egg near the seam and meet at the back: the ring is complete only now. Each
	-- side walks (the same 0.06 to 0.15 steps, the same jitter) until it is within half a step of the back.
	local back=start[1]+math.pi
	for side,e in ipairs(ends)do
		local dir=if side==1 then 1 else -1
		local at,h,dist=e.at,(if dir>0 then 0 else math.pi),e.dist
		local function left()return wrap(back-at[1])*dir end -- radians still to go (positive)
		local guard=0
		while left()*metric(at[2])*Paths.Studs>W.maxStep*.5 and guard<80 do
			guard+=1
			local togo=left()*metric(at[2])*Paths.Studs
			local step=math.clamp(W.minStep+rand()*(W.maxStep-W.minStep),W.minStep,math.max(W.minStep,togo))
			-- steer for the meeting point at the back, at the seam, so the two sides join there
			local want=Paths.heading(at,{at[1]+left()*dir,S.seamV})
			local turn=math.clamp((rand()*2-1)*W.jitter*.7+wrap(want-h)*.6,-W.jitter,W.jitter)
			-- never walk away from the back: turn toward it instead (still within the 35 degrees)
			if math.cos(h+turn)*dir<.3 then turn=math.clamp(wrap((if dir>0 then 0 else math.pi)-h),-W.jitter,W.jitter)end
			h+=turn
			local nextAt=Paths.step(at,h,step)
			h=Paths.heading(at,nextAt)
			table.insert(segs,{a=at,b=nextAt,stage=3,order=math.clamp(dist/total,0,1),width=W.widthTip*1.5,
				heading=Paths.heading(at,nextAt),run=side,ring=true})
			dist+=step;at=nextAt
		end
		ends[side].finish=at
	end
	-- close the last gap at the back exactly (a short joining segment, as part of the ring)
	local a,b=ends[1].finish,ends[2].finish
	table.insert(segs,{a=a,b=b,stage=3,order=1,width=W.widthTip,heading=Paths.heading(a,b),ring=true,join=true})
	return segs,chips
end
-- Pure: the segments of one stage.
function Paths.stage(list,stage)
	local out={}
	for _,seg in ipairs(list)do if seg.stage==stage then table.insert(out,seg)end end
	return out
end
-- Pure: a segment's middle, its direction along the shell and the outward normal (model units), its length (model units).
function Paths.segment(seg)
	local a,b=Paths.point(seg.a[1],seg.a[2]),Paths.point(seg.b[1],seg.b[2])
	local mid=(a+b)/2
	local theta,v=(seg.a[1]+seg.b[1])/2,(seg.a[2]+seg.b[2])/2
	local n=Paths.normal(theta,v)
	local d=b-a
	local length=d.Magnitude
	local along=if length>1e-6 then d/length else Vector3.new(1,0,0)
	along=along-n*along:Dot(n)
	along=along/math.max(1e-6,along.Magnitude)
	-- the chord's middle sits a hair inside a curved shell: put it back on the surface
	mid=Paths.point(theta,v)
	return mid,along,n,length
end
-- Pure: where on the shell a screen tap lands. dx, dy: the tap from the egg's centre in egg half-widths (right, down);
-- front: theta facing the camera. Off the egg is clamped to its edge.
function Paths.tapPoint(dx,dy,front)
	local x=math.clamp(dx or 0,-.95,.95)
	-- the egg faces the camera with its -Z (theta pi): screen right is the egg's -X, a larger theta
	local theta=(front or math.pi)+math.asin(x)*.9
	local v=math.clamp(Paths.Shape.seamV-(dy or 0)*.5,-.45,.6)
	return{theta,v}
end
return table.freeze(Paths)
