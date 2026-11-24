-- Read-only Studio probe for the egg corner (beta 15; artifacts/qa-2026-11-24-beta15/EGG-CORNER-LOOK.md section 1 and
-- EGG-CORNER-BUILD-PLAN.md section 9). Run through Studio MCP execute_luau in PLAY on the beta place (in Edit the world
-- is not built and every ray misses). It changes nothing, creates no instance and saves nothing: rays only, because the
-- benches, statues, urns, station steps and plaza paving are merged into island-wide meshes (WorldV7Data `Stations__*`,
-- `Architecture__*`), so bounds queries cannot see them. Prints PASS / FAIL per check and the numbers to act on.
--
--   A  the machine spot, for each candidate M, M2, M3, M4 (front looks at Face):
--      A1 the centre and 16 rays down on a ring r 2.8: all on plaza marble or the inlay ring, within .25 (Fable R2 1)
--      A2 the footprint is clear: a .5-stud grid of rays down inside the 4.8 x 4.4 box (turned with the machine) meets
--         only the floor (nothing standing: bench slats, a statue, a step, a lamp post)
--      A3 no dirt path, lawn or meadow within 4.0 (rings r 3.0, 3.5, 4.0)
--      A4 sight lines 5 up from (2.5, 21), (-9, 21), (-20, 12) to the machine's middle (M + 5 up): nothing first
--      A5 sight lines from the same three points to the nest (-31, -11) + 2 up, with the machine's box (4.8 x 7.2 x 4.4)
--         in the way (worked out in the probe, nothing is placed): clear
--      A6 the plaza's 12-stud rule: flat distances to the nest, the Style deck kiosk, the care arch and the toy lawn
--   B  the nest at the old Eggs station (-31, -11), root -Z facing (-30, -4):
--      B1 the dais as it stands: rays down on rings r 0 to 4 (radius of each step, its top Y, the mesh that carries it);
--         the largest flat disc at one height (Fable's rule: 3.0 or more, else the whole station goes)
--      B2 which merged meshes carry the station's pieces: the egg (centre, 5.5 and 6.5 up), the halo, the nest cup, the
--         sign stele (station-local (2.75, 0, 1.0) at yaw -.35): the names the island re-export must split out
--      B3 with every Stations / NestHalo mesh left out of the rays (as on the beta once the station is hidden): the floor
--         under the whole r 3.6 disc (a hole means the re-export must fill it), the ring r 2.6 at .5 / 1.5 / 2.5 up clear,
--         and the Bear spot, sign post and prompt point on marble within .1 of the root's floor
--      B4 sight lines to the sign board and to the nest + 2 from the three walk-in points, the station left out
--      B5 the sign's Front against the walk-in points (Fable: within 40 degrees of (-20, 12))
--   C  everything standing on or over the plaza near the egg corner, for Fable's ruling: a 1-stud ray grid over
--      x -54..-10, z -26..18, up to five hits a column, grouped by mesh into blobs (centre, extent, top, count), then the
--      runtime parts (not world meshes) within 20 studs of the corner.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Players=game:GetService("Players")
local Layout=require(Shared:WaitForChild("HollowWorldLayout"))

-- NestClient's root-local numbers (a client module: copied here; keep in step with src/client/NestClient.lua).
local BearSpot,SignAt,SignYaw,Front=Vector3.new(-2.2,0,-1.4),Vector3.new(-1.7,0,1.6),50,2.6
local Face=Vector3.new(-26,0,7)                       -- the machine's front looks here (EGG-CORNER-LOOK 1)
local NestAt,NestFacing=Vector3.new(-31,0,-11),Vector3.new(-30,0,-4)
local Machine=Vector3.new(4.8,7.2,4.4)                -- the block box and the mesh's height
local Candidates={{"M5 (built)",-41,2},{"M4",-38.5,1.5},{"M",-44,4},{"M2",-41.5,2.5},{"M3",-17.5,-2.5}}
local Walkins={Vector2.new(2.5,21),Vector2.new(-9,21),Vector2.new(-20,12)}
local Neighbours={{"nest",-31,-11},{"Style deck",-46,-9},{"care arch",-17,-15},{"toy lawn",-30,18.5}}

local out={}
local function say(fmt,...)table.insert(out,string.format(fmt,...))end
local function flat(a,b)return Vector2.new(a.X-b.X,a.Z-b.Z).Magnitude end

-- Rays leave out characters, this game's local helper folders and the collision proxies (W7C_*, boxes, not surfaces).
local base={}
for _,player in ipairs(Players:GetPlayers())do if player.Character then table.insert(base,player.Character)end end
for _,name in ipairs({"EggDropSleepyNest","EggDropShowMe","EggDropDashLine","EggDropStationAttract","EggDropAero","AeroKit"})do
	local f=workspace:FindFirstChild(name,true);if f then table.insert(base,f)end
end
local room=workspace:FindFirstChild("EggDropLounge")
local world=room and room:FindFirstChild("World")
local proxies,station={},{}
if world then
	for _,part in ipairs(world:GetChildren())do
		if part:IsA("BasePart")then
			if string.sub(part.Name,1,4)=="W7C_"then table.insert(proxies,part)end
			if string.find(part.Name,"^W7_Stations__")or string.find(part.Name,"^W7_NestHalo__")then table.insert(station,part)end
		end
	end
end
local function params(extra)
	local p=RaycastParams.new()
	p.FilterType=Enum.RaycastFilterType.Exclude
	local list=table.clone(base)
	for _,x in ipairs(proxies)do table.insert(list,x)end
	for _,x in ipairs(extra or {})do table.insert(list,x)end
	p.FilterDescendantsInstances=list
	return p
end
local plain=params()
local noStation=params(station)
local function material(name)return string.match(name or "","__(.+)$")or name or "nothing"end
local function down(x,z,p,top)
	local hit=workspace:Raycast(Vector3.new(x,top or 30,z),Vector3.new(0,-(top or 30)+1,0),p or plain)
	if not hit then return nil,"nothing"end
	return hit.Position.Y,hit.Instance.Name
end
-- Ray against an oriented box (slabs); true when the segment from a to b passes through it.
local function throughBox(a,b,frame,size)
	local o=frame:PointToObjectSpace(a)
	local d=frame:VectorToObjectSpace(b-a)
	local lo,hi=0,1
	for _,axis in ipairs({"X","Y","Z"})do
		local half=size[axis]/2
		if math.abs(d[axis])<1e-9 then
			if math.abs(o[axis])>half then return false end
		else
			local t1,t2=(-half-o[axis])/d[axis],(half-o[axis])/d[axis]
			if t1>t2 then t1,t2=t2,t1 end
			lo,hi=math.max(lo,t1),math.min(hi,t2)
			if lo>hi then return false end
		end
	end
	return true
end
local function eyeAt(from)local y=down(from.X,from.Y)or 4;return Vector3.new(from.X,y+5,from.Y)end
local function sight(eye,target,p)
	local hit=workspace:Raycast(eye,target-eye,p or plain)
	if hit==nil or(hit.Position-target).Magnitude<.6 then return nil end
	return string.format("%s at %.1f",hit.Instance.Name,hit.Distance)
end

if not world then
	print("No EggDropLounge.World: run this in Play on the beta place (Edit has no world).")
	return
end

-- ── A: the machine spot ─────────────────────────────────────────────────────────────────────────────────────────
for _,c in ipairs(Candidates)do
	local name,x,z=c[1],c[2],c[3]
	local centreY,centreOn=down(x,z)
	centreY=centreY or 4
	local frame=CFrame.lookAt(Vector3.new(x,centreY,z),Vector3.new(Face.X,centreY,Face.Z))*CFrame.Angles(0,math.pi,0) -- +Z = front
	say("A %s (%.1f, %.1f): floor %.2f on %s; front yaw %.1f deg",name,x,z,centreY,centreOn,math.deg(math.atan2(frame.LookVector.X,frame.LookVector.Z)))
	-- A1
	local lowY,highY,bad=centreY,centreY,{}
	local function paving(m)return m=="marble"or m=="marble_smooth"or m=="trim"end -- R2 1: the inlay ring (trim) counts
	if not paving(material(centreOn))then table.insert(bad,"centre "..centreOn)end
	for k=0,15 do
		local a=k/16*math.pi*2
		local y,on=down(x+math.cos(a)*2.8,z+math.sin(a)*2.8)
		if not y then table.insert(bad,string.format("%d deg: no hit",k*360/16))
		else
			lowY,highY=math.min(lowY,y),math.max(highY,y)
			local m=material(on)
			if not paving(m)then table.insert(bad,string.format("%d deg: %s y %.2f",k*360/16,on,y))end
		end
	end
	local spread=highY-lowY
	say("  A1 ring r 2.8: %s (spread %.2f)%s",(#bad==0 and spread<=.25)and "PASS"or "FAIL",spread,#bad>0 and "\n     "..table.concat(bad,"\n     ")or "")
	-- A2
	local standing,worst={},0
	for i=-4.8/2,4.8/2+1e-6,.5 do
		for j=-4.4/2,4.4/2+1e-6,.5 do
			local p=frame*Vector3.new(i,0,j)
			local y,on=down(p.X,p.Z)
			if y and y-centreY>.15 then
				standing[on]=math.max(standing[on]or 0,y-centreY)
				worst=math.max(worst,y-centreY)
			end
		end
	end
	local list={}
	for on,h in pairs(standing)do table.insert(list,string.format("%s up to %.2f over the floor",on,h))end
	say("  A2 footprint 4.8 x 4.4: %s%s",#list==0 and "PASS"or "FAIL",#list>0 and "\n     "..table.concat(list,"\n     ")or "")
	-- A3
	local near=nil
	for _,r in ipairs({3,3.5,4})do
		for k=0,23 do
			local a=k/24*math.pi*2
			local y,on=down(x+math.cos(a)*r,z+math.sin(a)*r)
			local m=material(on)
			if m=="dirt_path"or m=="grass"or m=="meadow"or m=="ground"then
				if not near or r<near.r then near={r=r,on=on,deg=k*15}end
			end
		end
		if near then break end
	end
	say("  A3 no path / trim / lawn within 4.0: %s",near and string.format("FAIL, %s at r %.1f, %d deg",near.on,near.r,near.deg)or "PASS")
	-- A4 and A5
	local mid=Vector3.new(x,centreY+5,z)
	local box=frame*CFrame.new(0,Machine.Y/2,0)
	local nest=Vector3.new(NestAt.X,(down(NestAt.X,NestAt.Z,noStation)or 4.07)+2,NestAt.Z)
	for _,from in ipairs(Walkins)do
		local eye=eyeAt(from)
		local first=sight(eye,mid)
		local toNest=sight(eye,nest,noStation)
		local blocked=throughBox(eye,nest,box,Machine)
		say("  A4 (%.1f, %.1f) -> machine: %s; A5 -> nest: %s",from.X,from.Y,first and "FAIL, "..first or "PASS",
			(toNest or blocked)and("FAIL, "..(toNest or "the machine's box"))or "PASS")
	end
	-- A6
	local gaps={}
	for _,n in ipairs(Neighbours)do table.insert(gaps,string.format("%s %.1f",n[1],math.sqrt((x-n[2])^2+(z-n[3])^2)))end
	say("  A6 gaps (12 or more): %s; from the plaza middle %.1f",table.concat(gaps,", "),math.sqrt((x+30)^2+(z+4)^2))
end

-- ── B: the nest at the old station ─────────────────────────────────────────────────────────────────────────────
local S=Layout.Stations.Eggs
local floorY=down(NestAt.X,NestAt.Z,noStation)
say("B nest root (%.1f, %.1f): floor with the station left out %s",NestAt.X,NestAt.Z,floorY and string.format("%.2f",floorY)or "NONE (a hole: the re-export must fill it)")
-- B1
local steps={}
for _,r in ipairs({0,.5,1,1.5,2,2.2,2.4,2.6,2.8,3,3.2,3.4,3.6,4})do
	local ys,names={},{}
	for k=0,15 do
		local a=k/16*math.pi*2
		local y,on=down(NestAt.X+math.cos(a)*r,NestAt.Z+math.sin(a)*r,plain,12)
		if y then table.insert(ys,y);names[on]=true end
		if r==0 then break end
	end
	table.sort(ys)
	local n={};for on in pairs(names)do table.insert(n,on)end
	table.insert(steps,string.format("r %.1f: y %s..%s on %s",r,ys[1]and string.format("%.2f",ys[1])or "-",ys[#ys]and string.format("%.2f",ys[#ys])or "-",table.concat(n,", ")))
end
say("B1 the dais (rays down from 12):\n     %s",table.concat(steps,"\n     "))
local topY=down(NestAt.X,NestAt.Z+.6,plain,12)
local disc=0
if topY then
	for r=.2,5,.1 do
		local ok=true
		for k=0,15 do
			local a=k/16*math.pi*2
			local y=down(NestAt.X+math.cos(a)*r,NestAt.Z+math.sin(a)*r,plain,12)
			if not y or math.abs(y-topY)>.05 then ok=false;break end
		end
		if not ok then break end
		disc=r
	end
end
say("  B1 largest flat disc at the top (y %s): r %.1f -> %s",topY and string.format("%.2f",topY)or "-",disc,disc>=3 and "PASS (the dais can seat the nest)"or "FAIL (Fable's rule: the whole station goes)")
-- B2: the station frame is the station's CFrame (front local +Z); the stele sits at station-local (2.75, 0, 1.0) in
-- Blender (x, y) = Roblox (X, -Z), so Roblox local (2.75, 0, -1.0).
local function hitAt(p,dir,len)
	local hit=workspace:Raycast(p,dir*len,plain)
	return hit and string.format("%s (y %.2f)",hit.Instance.Name,hit.Position.Y)or "nothing"
end
local stele=S*Vector3.new(2.75,0,-1.0)
say("B2 the station's pieces (first hit):\n     egg, from above: %s\n     egg, across at 5.5 up: %s\n     egg, across at 6.5 up: %s\n     halo / cup ring r 1.2: %s\n     sign stele (%.2f, %.2f), from above: %s",
	hitAt(Vector3.new(S.X,12,S.Z),Vector3.new(0,-1,0),10),
	hitAt(Vector3.new(S.X-4,5.5,S.Z),Vector3.new(1,0,0),8),
	hitAt(Vector3.new(S.X-4,6.5,S.Z),Vector3.new(1,0,0),8),
	hitAt(Vector3.new(S.X+1.2,12,S.Z),Vector3.new(0,-1,0),10),
	stele.X,stele.Z,hitAt(Vector3.new(stele.X,12,stele.Z),Vector3.new(0,-1,0),10))
-- B3
local root=CFrame.lookAt(Vector3.new(NestAt.X,floorY or 4.07,NestAt.Z),Vector3.new(NestFacing.X,floorY or 4.07,NestFacing.Z))
local holes={}
for _,r in ipairs({.5,1.5,2.5,3,3.6})do
	for k=0,15 do
		local a=k/16*math.pi*2
		local y,on=down(NestAt.X+math.cos(a)*r,NestAt.Z+math.sin(a)*r,noStation)
		if not y or math.abs(y-(floorY or 4.07))>.1 then table.insert(holes,string.format("r %.1f, %d deg: %s",r,k*360/16,y and string.format("%s y %.2f",on,y)or "no floor"))end
	end
end
say("  B3 floor under r 3.6 with the station out: %s%s",#holes==0 and "PASS"or "FAIL",#holes>0 and "\n     "..table.concat(holes,"\n     ")or "")
local ring={}
for _,height in ipairs({.5,1.5,2.5})do
	local centre=Vector3.new(NestAt.X,(floorY or 4.07)+height,NestAt.Z)
	for k=0,15 do
		local a=k/16*math.pi*2
		local hit=workspace:Raycast(centre,Vector3.new(math.cos(a),0,math.sin(a))*2.6,noStation)
		if hit then table.insert(ring,string.format("%.1f up, %d deg: %s at %.2f",height,k*360/16,hit.Instance.Name,hit.Distance))end
	end
end
say("  B3 ring r 2.6, station out: %s%s",#ring==0 and "PASS"or "FAIL",#ring>0 and "\n     "..table.concat(ring,"\n     ")or "")
for _,row in ipairs({{"Bear spot",BearSpot},{"sign post",SignAt},{"prompt point",Vector3.new(0,0,-Front)}})do
	local p=root*row[2]
	local y,on=down(p.X,p.Z,noStation)
	local withStation=down(p.X,p.Z)
	say("  B3 %s (%.2f, %.2f): %s, y %s on %s (with the station still there: y %s)",row[1],p.X,p.Z,
		(y and math.abs(y-(floorY or 4.07))<=.1)and "PASS"or "FAIL",y and string.format("%.2f",y)or "-",on,withStation and string.format("%.2f",withStation)or "-")
end
-- B4
local board=root*Vector3.new(SignAt.X,1.45,SignAt.Z)
local egg=root.Position+Vector3.new(0,2,0)
for _,from in ipairs(Walkins)do
	local eye=eyeAt(from)
	local a,b=sight(eye,board,noStation),sight(eye,egg,noStation)
	say("  B4 (%.1f, %.1f) -> sign: %s; -> nest: %s",from.X,from.Y,a and "FAIL, "..a or "PASS",b and "FAIL, "..b or "PASS")
end
-- B5: the board's Front normal is root * Ry(SignYaw) local -Z.
local signFrame=root*CFrame.new(SignAt.X,1.45,SignAt.Z)*CFrame.Angles(0,math.rad(SignYaw),0)
local normal=signFrame.LookVector
for _,from in ipairs(Walkins)do
	local to=(Vector3.new(from.X,signFrame.Position.Y,from.Y)-signFrame.Position).Unit
	local deg=math.deg(math.acos(math.clamp(normal:Dot(to),-1,1)))
	local back=180-deg
	-- CFrame.Angles(0, Y, 0).LookVector is (-sin Y, 0, -cos Y): the yaw whose Front looks straight at this point.
	local d=root:VectorToObjectSpace(to)
	local facing=math.deg(math.atan2(-d.X,-d.Z))
	local verdict=""
	if from.X==-20 and from.Y==12 then
		verdict=if math.min(deg,back)<=40 then "  PASS"else string.format("  FAIL: SignYaw %.1f faces it",facing)
	end
	say("  B5 (%.1f, %.1f): Front %.1f deg, Back %.1f deg (SignYaw %.1f would face it)%s",from.X,from.Y,deg,back,facing,verdict)
end

-- ── C: what stands on the plaza near the corner ────────────────────────────────────────────────────────────────
local floorRef=4.25 -- the plaza marble is about 4.13, the lawn 4.0: anything higher stands on it
local cells={}
for x=-54,-10 do
	for z=-26,18 do
		local skip={}
		for _=1,5 do
			local hit=workspace:Raycast(Vector3.new(x,40,z),Vector3.new(0,-40,0),params(skip))
			if not hit then break end
			local y=hit.Position.Y
			if y<=floorRef then break end
			local key=hit.Instance.Name
			cells[key]=cells[key]or {}
			cells[key][x..","..z]={x=x,z=z,y=y}
			table.insert(skip,hit.Instance)
		end
	end
end
local blobs={}
for name,set in pairs(cells)do
	local seen={}
	for key,cell in pairs(set)do
		if not seen[key]then
			local blob={name=name,n=0,x0=cell.x,x1=cell.x,z0=cell.z,z1=cell.z,top=cell.y,low=cell.y,sx=0,sz=0}
			local stack={cell}
			seen[key]=true
			while #stack>0 do
				local c=table.remove(stack)
				blob.n+=1;blob.sx+=c.x;blob.sz+=c.z
				blob.x0,blob.x1=math.min(blob.x0,c.x),math.max(blob.x1,c.x)
				blob.z0,blob.z1=math.min(blob.z0,c.z),math.max(blob.z1,c.z)
				blob.top,blob.low=math.max(blob.top,c.y),math.min(blob.low,c.y)
				for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
					local k=(c.x+d[1])..","..(c.z+d[2])
					if set[k]and not seen[k]then seen[k]=true;table.insert(stack,set[k])end
				end
			end
			blob.cx,blob.cz=blob.sx/blob.n,blob.sz/blob.n
			table.insert(blobs,blob)
		end
	end
end
local corner=Vector2.new(-37,-3)
table.sort(blobs,function(a,b)return(Vector2.new(a.cx,a.cz)-corner).Magnitude<(Vector2.new(b.cx,b.cz)-corner).Magnitude end)
say("C world meshes standing over the plaza floor (1-stud grid x -54..-10, z -26..18; blobs of 2+ cells):")
for _,b in ipairs(blobs)do
	if b.n>=2 then
		say("  %-34s centre (%.1f, %.1f)  x %d..%d  z %d..%d  y %.2f..%.2f  %d cells  M %.1f  nest %.1f",b.name,b.cx,b.cz,b.x0,b.x1,b.z0,b.z1,b.low,b.top,b.n,
			math.sqrt((b.cx+44)^2+(b.cz-4)^2),math.sqrt((b.cx+31)^2+(b.cz+11)^2))
	end
end
say("C runtime parts (not world meshes) within 20 studs of (-37, -3):")
local seen=0
for _,part in ipairs(workspace:GetDescendants())do
	if part:IsA("BasePart")and part:GetAttribute("WorldMesh")~=true and not part:IsDescendantOf(world)then
		local p=part.Position
		if flat(p,Vector3.new(corner.X,0,corner.Y))<=20 and part.Size.Magnitude<40 then
			local character=false
			for _,player in ipairs(Players:GetPlayers())do if player.Character and part:IsDescendantOf(player.Character)then character=true end end
			if not character then
				seen+=1
				if seen<=80 then
					local full=(string.gsub(part:GetFullName(),"^Workspace%.",""))
					say("  %-40s (%.1f, %.2f, %.1f) size (%.1f, %.1f, %.1f) %s%s",full,p.X,p.Y,p.Z,part.Size.X,part.Size.Y,part.Size.Z,
						part.Transparency>=1 and "invisible"or "visible",part.CanCollide and ", collides"or "")
				end
			end
		end
	end
end
if seen>80 then say("  ... and %d more",seen-80)end
print(table.concat(out,"\n"))
