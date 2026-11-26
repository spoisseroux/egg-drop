-- Onboarding v2 step 3: where the first Bear's egg cracks, as data (Spencer, beta 36: "can we make the cracking on the
-- egg not a 2d texture ... shrinkwrapped to the 3d egg mesh?"). Pure and seeded, so the specs can walk it and Fable's
-- cathartic crack (AERO-JUICE-BRIEF 4) can layer looks on it without touching the shapes: EggCrack3D draws these.
-- The shell is modelled as an egg-shaped ellipsoid in the Companion Egg's own units (EggModels: base at y 0, top at
-- 1.30, widest at 0.55); a surface point is (theta, v): theta round the egg (0 = +Z, pi = -Z), v from -1 (bottom pole)
-- to 1 (top). Three stages, one a tap:
--   1  a crack from the tap point, a few zig-zag teeth each way and a small spur down;
--   2  both ends run on round the egg and fork (one up, one down), with a cream light leak along the main line;
--   3  the line rings the whole egg at the shells' own seam (the meshes split there at the pop).
-- Each segment: {a = {theta, v}, b = {theta, v}, stage, order (0..1: when in its stage's 90 ms it starts), width, leak}.
local Paths={}
Paths.Shape=table.freeze({y0=.55,rx=.5,top=.75,bottom=.55,seamV=.27})
Paths.Width=table.freeze({.018,.022,.026}) -- egg units, per stage (the ring is thickest)
Paths.Teeth=table.freeze({tooth=.12,amp=.045,stage1=3,stage2=5,ring=28})

-- Pure: the surface point (egg units, the egg's own frame) and its outward normal at (theta, v).
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
-- A small seeded generator (an LCG): the same egg cracks the same way for the same seed.
local function rng(seed)
	local s=math.floor(math.abs(seed or 1))%2147483647+1
	return function()s=(s*16807)%2147483647;return s/2147483647 end
end
local function add(list,a,b,stage,order,extra)
	local seg={a=a,b=b,stage=stage,order=math.clamp(order,0,1),width=Paths.Width[stage]}
	for k,v in pairs(extra or {})do seg[k]=v end
	table.insert(list,seg)
	return seg
end
-- A zig-zag run from `from` going `dir` (+1 / -1 in theta) for `count` teeth. Returns its end and the points.
local function run(list,from,dir,count,stage,orderFrom,orderTo,rand,extra)
	local T=Paths.Teeth
	local at=from
	for i=1,count do
		local side=if i%2==0 then 1 else -1
		local nextAt={at[1]+dir*T.tooth*(.8+.4*rand()),math.clamp(at[2]+side*T.amp*(.6+.8*rand()),-.7,.7)}
		add(list,at,nextAt,stage,orderFrom+(orderTo-orderFrom)*(i-1)/math.max(1,count),extra)
		at=nextAt
	end
	return at
end
-- Pure: the whole crack for one egg. tap: {theta, v} where tap 1 landed (default: the front, at the seam). seed: any
-- number. Returns the segment list (stage 1, then 2, then 3).
function Paths.build(tap,seed)
	local S=Paths.Shape
	local T=Paths.Teeth
	local rand=rng(seed or 7)
	local start={(tap and tap[1])or math.pi,math.clamp((tap and tap[2])or S.seamV,-.45,.6)}
	local list={}
	-- 1: both ways from the tap point, a spur down
	local left=run(list,start,-1,T.stage1,1,0,.8,rand)
	local right=run(list,start,1,T.stage1,1,0,.8,rand)
	add(list,start,{start[1]+.03,start[2]-.16},1,.5)
	-- 2: on round, with a fork up and a fork down, the main runs leaking light
	local l2=run(list,left,-1,T.stage2,2,0,.9,rand,{leak=true})
	local r2=run(list,right,1,T.stage2,2,0,.9,rand,{leak=true})
	add(list,left,{left[1]-.08,left[2]+.2},2,.4)
	add(list,right,{right[1]+.1,right[2]-.22},2,.5)
	add(list,{l2[1],l2[2]},{l2[1]-.05,l2[2]+.14},2,1)
	-- 3: the ring at the seam, all the way round, joined to both stage-2 ends
	local n=T.ring
	local base=start[1]
	local prev={base,S.seamV}
	for i=1,n do
		local theta=base+math.pi*2*i/n
		local v=S.seamV+(if i%2==0 then 1 else -1)*T.amp
		local at={theta,v}
		add(list,prev,at,3,(i-1)/n)
		prev=at
	end
	add(list,l2,{l2[1]-.06,S.seamV},3,.1)
	add(list,r2,{r2[1]+.06,S.seamV},3,.1)
	return list
end
-- Pure: the segments of one stage.
function Paths.stage(list,stage)
	local out={}
	for _,seg in ipairs(list)do if seg.stage==stage then table.insert(out,seg)end end
	return out
end
-- Pure: a segment's middle, its direction along the shell and the outward normal (egg units), for the drawing.
function Paths.segment(seg)
	local a,b=Paths.point(seg.a[1],seg.a[2]),Paths.point(seg.b[1],seg.b[2])
	local mid=(a+b)/2
	local theta,v=(seg.a[1]+seg.b[1])/2,(seg.a[2]+seg.b[2])/2
	local n=Paths.normal(theta,v)
	local d=b-a
	local length=d.Magnitude
	local along=if length>1e-6 then d/length else Vector3.new(1,0,0)
	-- keep the direction on the surface (no part of it along the normal)
	along=along-n*along:Dot(n)
	along=along/math.max(1e-6,along.Magnitude)
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
