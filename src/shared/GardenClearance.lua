-- The garden's keep-outs for client-built accents (GARDEN-PLAY-BRIEF 2026-11-26: the crunchy toys, the drift lanterns;
-- the Bumble balls can ask the same). Pure: reads the v7 layout data, the Dash course and the park sites, no instances.
--   Clear.check(x, z, radius, air) -> ok, why
-- radius is the piece's footprint (for something that drifts, its body plus the drift). `air` is a piece that floats
-- (a lantern): it keeps off the same paths, water, blocked ground, parks and Dash, but not the lamps and stations
-- under it. Every number here is a [PLACEHOLDER] margin; Studio raycasts are still the truth.
local Shared=script.Parent
local World=require(Shared.HollowWorldLayout)
local Data=require(Shared.WorldV7Data)
local Course=require(Shared.DashCourse)
local Clear={}
Clear.RouteHalf=3      -- the dirt path's half width plus a step
Clear.DashHalf=2.5     -- the 4-stud Dash path, its hurdles and lane drawing
Clear.DashMargin=1
Clear.BoxMargin=.5     -- off water, blocked ground and the bridge deck
Clear.ParkMargin=2     -- off each park's kerb ellipse
Clear.LampMargin=1
Clear.SpotMargin=4     -- off stations, rest daises, the nest and the egg corner

local function segment(px,pz,ax,az,bx,bz)
	local dx,dz=bx-ax,bz-az
	local length=dx*dx+dz*dz
	local t=if length<1e-9 then 0 else math.clamp(((px-ax)*dx+(pz-az)*dz)/length,0,1)
	local ex,ez=px-(ax+t*dx),pz-(az+t*dz)
	return math.sqrt(ex*ex+ez*ez)
end
-- Distance from (x, z) to a polyline of Vector2 points.
function Clear.toPolyline(x,z,points)
	local best=math.huge
	for i=1,#points-1 do
		local a,b=points[i],points[i+1]
		best=math.min(best,segment(x,z,a.X,a.Y,b.X,b.Y))
	end
	return best
end
-- Distance from (x, z) to the Dash's centre line (Main and the stepping-stone Branch, stored in hundredths).
local function course(list)
	local out={}
	for i=1,#list,4 do table.insert(out,Vector2.new(list[i+1]/100,list[i+3]/100))end
	return out
end
local dashLines
function Clear.toDash(x,z)
	dashLines=dashLines or{course(Course.Main),course(Course.Branch)}
	local best=math.min(Clear.toPolyline(x,z,dashLines[1]),Clear.toPolyline(x,z,dashLines[2]))
	local pad=Course.Pad
	return math.min(best,math.max(0,Vector2.new(x-pad.x/100,z-pad.z/100).Magnitude-pad.r/100))
end
-- Is (x, z) within `grow` studs of a yawed box (centre Vector2 / Vector3, size Vector2 / Vector3 XZ)?
function Clear.inBox(x,z,centre,size,yaw,grow)
	local cx,cz=centre.X,if typeof(centre)=="Vector2"then centre.Y else centre.Z
	local sx,sz=size.X,if typeof(size)=="Vector2"then size.Y else size.Z
	local frame=CFrame.new(cx,0,cz)*CFrame.Angles(0,yaw or 0,0)
	local p=frame:PointToObjectSpace(Vector3.new(x,0,z))
	local qx,qz=math.max(0,math.abs(p.X)-sx/2),math.max(0,math.abs(p.Z)-sz/2)
	return math.sqrt(qx*qx+qz*qz)<=(grow or 0)
end
-- Is there island ground here (all four 4-stud grid corners measured)?
function Clear.groundKnown(x,z)
	local G=Data.ground
	local fx,fz=(x-G.x0)/G.step,(z-G.z0)/G.step
	local i,j=math.floor(fx),math.floor(fz)
	for _,c in ipairs({{i,j},{i+1,j},{i,j+1},{i+1,j+1}})do
		local a,b=c[1],c[2]
		if a<0 or b<0 or a>=G.nx or b>=G.nz then return false end
		local v=G.h[b*G.nx+a+1]
		if type(v)~="number"or v<=-900 then return false end
	end
	return true
end
local function vec(t)return if type(t)=="table"then Vector3.new(t[1],t[2],t[3])else t end
-- Every park site's ellipse (the arrival park, the old grove, the Hollow / Paw Glade, the Top Lawn).
local parks
function Clear.parks()
	if parks then return parks end
	parks={}
	local ok,Park=pcall(function()return require(Shared.ParkLayout)end)
	for name,spec in pairs(ok and Park.Specs or {})do
		if type(spec.x)=="number"and type(spec.z)=="number"then
			table.insert(parks,{name=name,x=spec.x,z=spec.z,rx=spec.rx or 16,rz=spec.rz or 11})
		end
	end
	table.sort(parks,function(a,b)return a.name<b.name end)
	return parks
end
-- Ground spots a toy keeps clear of: stations, rest daises, the nest and the egg corner.
local function spots()
	local out={}
	for name,frame in pairs(World.Stations or {})do table.insert(out,{name="station "..name,at=frame.Position})end
	for name,at in pairs(World.Rest or {})do table.insert(out,{name="rest "..name,at=at})end
	for _,module in ipairs({"Nest","EggCorner"})do
		local ok,m=pcall(function()return require(Shared[module])end)
		if ok and typeof(m.Spot)=="Vector3"then table.insert(out,{name=module,at=m.Spot})end
	end
	return out
end

function Clear.check(x,z,radius,air)
	radius=radius or 0
	if not Clear.groundKnown(x,z)then return false,"no ground under it"end
	for k=0,3 do
		local a=k*math.pi/2
		if not Clear.groundKnown(x+math.cos(a)*radius,z+math.sin(a)*radius)then return false,"no ground under its edge"end
	end
	for name,route in pairs(World.Routes or {})do
		local d=Clear.toPolyline(x,z,route)
		if d<radius+Clear.RouteHalf then return false,string.format("on the path %s (%.1f)",name,d)end
	end
	local dash=Clear.toDash(x,z)
	if dash<radius+Clear.DashHalf+Clear.DashMargin then return false,string.format("on the Dash (%.1f)",dash)end
	for _,box in ipairs(Data.wet or {})do
		if Clear.inBox(x,z,vec(box.center),vec(box.size),box.yaw,radius+Clear.BoxMargin)then return false,"in the water "..tostring(box.name)end
	end
	for _,box in ipairs(World.Wet or {})do
		if Clear.inBox(x,z,box.center,box.size,box.yaw,radius+Clear.BoxMargin)then return false,"in the water "..box.name end
	end
	for _,box in ipairs(World.Blocked or {})do
		if Clear.inBox(x,z,box.center,box.size,box.yaw,radius+Clear.BoxMargin)then return false,"on blocked ground "..box.name end
	end
	for name,span in pairs(World.WalkableSpans or {})do
		if Clear.inBox(x,z,span.center,span.size,0,radius+Clear.BoxMargin)then return false,"on the span "..name end
	end
	for _,park in ipairs(Clear.parks())do
		local grow=radius+Clear.ParkMargin
		local n=math.sqrt(((x-park.x)/(park.rx+grow))^2+((z-park.z)/(park.rz+grow))^2)
		if n<=1 then return false,"in the park "..park.name end
	end
	if not air then
		for i,lamp in ipairs(World.Lamps or {})do
			local d=Vector2.new(x-lamp.X,z-lamp.Z).Magnitude
			if d<radius+Clear.LampMargin then return false,string.format("on lamp %d (%.1f)",i,d)end
		end
		for _,spot in ipairs(spots())do
			local d=Vector2.new(x-spot.at.X,z-spot.at.Z).Magnitude
			if d<radius+Clear.SpotMargin then return false,string.format("on the %s (%.1f)",spot.name,d)end
		end
	end
	return true,nil
end
return table.freeze(Clear)
