-- The garden understory, P1 (GARDEN-B38-BRIEF 4b, Fable 2026-11-27): 24 round bushes in eight clusters of three (two
-- sizes, one mesh), 8 flowering bushes (the same shape on the blossom part of the atlas) in pairs either side of the
-- hub's old bench spots and on the fountain lawn, and 14 reed clumps with cattails on both stream banks, the pool under
-- the falls and the fountain basin's lawn side. A middle layer for a small pet to walk behind; matte and textured, darker
-- than the lawn, so the pets stay the cutest thing on screen. Tall grass, flower clumps and ferns are P2.
--
-- Pure: the numbers, the placement rules, the frames and the motion maths. UnderstoryClient builds and moves them on each
-- client (nothing replicates, nothing collides: CanCollide, CanQuery and CanTouch off, CastShadow off, a blob decal
-- under each bush instead). Rows: UnderstoryData (scripts/build_understory_place.py); uploads: UnderstoryArt (nil ids
-- draw nothing). Gate: the Alive `scene` switch (beta and Studio only; the ground plates and the dapple are already
-- under it). Every number is a [PLACEHOLDER] to tune in Studio.
local Shared=script.Parent
local Data=require(Shared.UnderstoryData)
local Art=require(Shared.UnderstoryArt)
local U={}
U.Feature="scene"
U.Data=Data
U.Art=Art
-- The brief's counts; the budget after Fable's review round 1 (a bush up to 190 triangles, reeds up to 38): 46 instances,
-- 32 x 176 + 14 x 38 = 6,164 triangles, 32 blob decals.
U.Counts=table.freeze({bushes=24,flowering=8,reeds=14})
U.Budget=table.freeze({instances=46,blobs=32,triangles=6164,bushCap=190,reedsCap=38})
-- Sizes (studs): round bushes 2.5 and 4 across, 1.5 to 2.5 tall (see-over for a .8 player, 4.2 tall); flowering 2.5 to 3.
U.Sizes=table.freeze({bush=table.freeze({across={2.5,4},tall={1.5,2.5}}),flower=table.freeze({across={2.5,3},tall={1.5,2.5}}),
	reeds=table.freeze({scale={.8,1.15}})})
-- The FBX import turns every mesh by pi about Y (memory: fbx-import-pi-turn; AeroKit.Turn).
U.Turn=CFrame.Angles(0,math.pi,0)
U.Look=table.freeze({
	material="Plastic",                 -- matte; the colour is the atlas (TextureID), the part colour stays white
	blobColour=Color3.fromHex("#1E3A1E"),blobTransparency=.35,blobScale=1.3,blobLift=.07, -- over the ground plates (.04 to .06)
})
-- Keep-outs (the brief: reuse GroundDressing.Keep and the other keep lists). Margins past each list's own radius.
U.Keep=table.freeze({trunk=.2,solid=.3,ballHome=5,frond=2,reedWater=3.5,height=.6})

-- Motion (the existing Wind): reeds lean downwind with the sway (breeze, gusts, the big breath) and wobble on their own
-- period; bushes only shiver on a strong gust or the breath. Degrees. Within `range` of the camera only; budget level 1
-- steps slower and nearer; level 2 and Reduced Motion: everything at rest.
U.Motion=table.freeze({rate=1/20,slowRate=1/10,range=table.freeze({phone=60,desktop=120,slow=40}),
	reed=table.freeze({lean=9,sway=1.6,periodMin=1.6,periodMax=2.4}),
	bush=table.freeze({strong=.7,degrees=1.4,hz=5.5})})

function U.rows(kind)
	if kind=="bush"then return Data.Bushes elseif kind=="flower"then return Data.Flowering elseif kind=="reeds"then return Data.Reeds end
	error("Understory: no kind "..tostring(kind))
end
U.Kinds=table.freeze({"bush","flower","reeds"})

-- A row's footprint radius and its size scale against the mesh (Size = mesh size x scale).
function U.radius(kind,row)
	if kind=="reeds"then return Art.Meshes.reeds.size.X*row[4]/2 end
	return row[4]/2
end
function U.scale(kind,row,art)
	local mesh=(art or Art).Meshes[kind]
	if kind=="reeds"then return Vector3.new(row[4],row[4],row[4])end
	local across=row[4]/math.max(mesh.size.X,mesh.size.Z)
	return Vector3.new(across,row[5]/mesh.size.Y,across)
end
-- The foot on the ground, the part's rest CFrame and Size (UnderstoryArt's centre is from the foot, before the turn).
function U.frame(kind,row,art)
	local mesh=(art or Art).Meshes[kind]
	local scale=U.scale(kind,row,art)
	local yaw=if kind=="reeds"then row[5]else row[6]
	local foot=Vector3.new(row[1],row[2],row[3])
	local frame=CFrame.new(foot)*CFrame.Angles(0,yaw,0)*CFrame.new(mesh.centre*scale)*U.Turn
	return frame,mesh.size*scale,foot
end

-- Placement rules ---------------------------------------------------------------------------------------------------
local function lineDistance(x,z,list)
	local best=math.huge
	for i=1,#list//4-1 do
		local ax,az,bx,bz=list[i*4-2]/100,list[i*4]/100,list[(i+1)*4-2]/100,list[(i+1)*4]/100
		local dx,dz=bx-ax,bz-az
		local length=dx*dx+dz*dz
		local t=if length>0 then math.clamp(((x-ax)*dx+(z-az)*dz)/length,0,1)else 0
		best=math.min(best,math.sqrt((x-ax-dx*t)^2+(z-az-dz*t)^2))
	end
	return best
end
local function box(b)return Vector3.new(b.center[1],0,b.center[3]),Vector3.new(b.size[1],0,b.size[3]),b.yaw or 0 end

-- Is a plant of `kind` with footprint `r` at (x, z) clear of every keep list? -> ok, why. `fountain`: a reed clump at the
-- fountain basin (it stands against the basin's stone, so the basin's own keep-out is not its).
function U.check(kind,x,z,r,fountain)
	local Clear=require(Shared.GardenClearance)
	local Ground=require(Shared.GroundDressing)
	local KeepOut=require(Shared.GardenKeepOut)
	local Course=require(Shared.DashCourse)
	local World=require(Shared.HollowWorldLayout)
	local V7=require(Shared.WorldV7Data)
	local K=Ground.Keep
	if not Clear.groundKnown(x,z)then return false,"no ground"end
	if kind~="reeds"then
		-- GardenClearance whole: routes, the Dash, water, blocked ground, spans, parks, lamps, stations, rest, nest, egg corner.
		local ok,why=Clear.check(x,z,r,false)
		if not ok then return false,why end
		for _,b in ipairs(V7.wet or {})do
			local c,s,yaw=box(b)
			if Clear.inBox(x,z,c,s,yaw,K.water+r)then return false,"in the water "..tostring(b.name)end
		end
	else
		-- Reeds stand on the bank: near water, off the paths, the Dash, spans, blocked ground, parks, lamps and spots.
		local wet=false
		for _,b in ipairs(V7.wet or {})do
			local c,s,yaw=box(b)
			if Clear.inBox(x,z,c,s,yaw,U.Keep.reedWater)then wet=true end
		end
		for _,b in ipairs(World.Wet or {})do
			if Clear.inBox(x,z,b.center,b.size,b.yaw,U.Keep.reedWater)then wet=true end
		end
		if not wet then return false,"not by the water"end
		for name,route in pairs(World.Routes or {})do
			if Clear.toPolyline(x,z,route)<r+Clear.RouteHalf then return false,"on the path "..name end
		end
		if Clear.toDash(x,z)<r+Clear.DashHalf+Clear.DashMargin then return false,"on the Dash"end
		for _,b in ipairs(World.Blocked or {})do
			if Clear.inBox(x,z,b.center,b.size,b.yaw,r+Clear.BoxMargin)then return false,"on blocked ground "..b.name end
		end
		for name,span in pairs(World.WalkableSpans or {})do
			if Clear.inBox(x,z,span.center,span.size,0,r+Clear.BoxMargin)then return false,"on the span "..name end
		end
		for _,park in ipairs(Clear.parks())do
			local g=r+Clear.ParkMargin
			if((x-park.x)/(park.rx+g))^2+((z-park.z)/(park.rz+g))^2<=1 then return false,"in the park "..park.name end
		end
		for i,lamp in ipairs(World.Lamps or {})do
			if Vector2.new(x-lamp.X,z-lamp.Z).Magnitude<r+Clear.LampMargin then return false,"on lamp "..i end
		end
		for name,at in pairs(World.Rest or {})do
			if Vector2.new(x-at.X,z-at.Z).Magnitude<r+K.station then return false,"on the rest "..name end
		end
	end
	-- GroundDressing.Keep: the Dash line and its waiting pad, find spots, park kerbs, stations, the nest.
	if lineDistance(x,z,Course.Main)<K.course+r or lineDistance(x,z,Course.Branch)<K.course+r then return false,"on the course"end
	local pad=Course.Pad
	if Vector2.new(x-pad.x/100,z-pad.z/100).Magnitude<K.pad+r then return false,"on the pad"end
	for _,spot in ipairs(require(Shared.FindSpots))do
		if Vector2.new(x-spot.x/100,z-spot.z/100).Magnitude<K.find+r then return false,"on a find spot"end
	end
	for name,frame in pairs(World.Stations or {})do
		if Vector2.new(x-frame.Position.X,z-frame.Position.Z).Magnitude<K.station+r then return false,"on station "..name end
	end
	for _,module in ipairs({"Nest","EggCorner"})do
		local ok,m=pcall(function()return require(Shared[module])end)
		if ok and typeof(m.Spot)=="Vector3"and Vector2.new(x-m.Spot.X,z-m.Spot.Z).Magnitude<K.station+r then return false,"on the "..module end
	end
	-- GardenKeepOut: trunks, lamps, the fountain basin, the Wobble Egg, the crunchy toys (solid and soft).
	for _,entry in ipairs(KeepOut.all())do
		local margin=if string.sub(entry.id,1,6)=="trunk "then U.Keep.trunk else U.Keep.solid
		if not(fountain and entry.id=="fountain")and Vector2.new(x-entry.x,z-entry.z).Magnitude<entry.r+r+margin then
			return false,"on "..entry.id
		end
	end
	-- The Bumble balls' homes (a resting ball never vanishes into a bush) and the frond bushes already there.
	local okBalls,Balls=pcall(function()return require(Shared.BumbleBalls)end)
	for _,ball in ipairs(okBalls and Balls.List or {})do
		if Vector2.new(x-ball.home.X,z-ball.home.Y).Magnitude<U.Keep.ballHome+r then return false,"on the "..ball.id.." ball's home"end
	end
	local okDressing,Dressing=pcall(function()return require(Shared.WorldDressing)end)
	for _,b in ipairs(okDressing and Dressing.Bushes or {})do
		if Vector2.new(x-b[1],z-b[3]).Magnitude<U.Keep.frond+r then return false,"on a frond bush"end
	end
	return true,nil
end

-- Motion ------------------------------------------------------------------------------------------------------------
local function finite(v)return type(v)=="number"and v==v and v<math.huge and v>-math.huge end
-- Reeds: degrees downwind (positive = top downwind) for the sway `wind` (0 to 1), `t` seconds, the clump's phase and period.
function U.reedLean(wind,t,phase,period)
	if not finite(wind)or wind<=0 or not finite(t)then return 0 end
	local R=U.Motion.reed
	wind=math.min(wind,1)
	return R.lean*wind+R.sway*(.4+wind)*math.sin(2*math.pi*(t/(period or R.periodMin)+(phase or 0)))
end
-- Bushes: a shiver only on a strong blow (a gust or the breath, 0 to 1); 0 otherwise.
function U.bushShiver(blow,t,phase)
	local B=U.Motion.bush
	if not finite(blow)or blow<=B.strong or not finite(t)then return 0 end
	local amp=B.degrees*math.min(1,(blow-B.strong)/(1-B.strong))
	return amp*math.sin(2*math.pi*(B.hz*t+(phase or 0)))
end
-- A pose: the rest frame leaned `degrees` downwind about the plant's foot (Wind.Direction; Side is across it).
function U.pose(rest,foot,degrees,direction)
	if degrees==0 then return rest end
	local d=direction or Vector3.new(math.cos(math.rad(20)),0,-math.sin(math.rad(20)))
	local side=Vector3.new(-d.Z,0,d.X)
	-- a positive turn about Side tips the top up the wind (WindClient.pose), so downwind is negative
	return CFrame.new(foot)*CFrame.fromAxisAngle(side,-math.rad(degrees))*CFrame.new(-foot)*rest
end
-- Each plant's own phase and period, from its index (no Random: every client agrees and specs can pin it).
function U.phase(index)
	local p=(index*.618034)%1
	local R=U.Motion.reed
	return p,R.periodMin+(R.periodMax-R.periodMin)*((index*.381966)%1)
end

return table.freeze(U)
