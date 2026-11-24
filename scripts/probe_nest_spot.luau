-- Read-only Studio probe P1 for the nest at the Eggs station's foot (beta 14 D1; WORLD-AND-NEST-LOOK, Nest merge rulings
-- R2 section 1; NEST-AND-RACE-LINE-BUILD-PLAN 6). Run through Studio MCP execute_luau in Edit mode on the beta place. It
-- changes nothing and saves nothing. Benches, urns, pedestals and the station's base are merged into the world mesh,
-- so only rays can see them. It prints PASS / FAIL per check and the numbers to act on:
--   1. the 16-ray ring at r 2.6 round the root, at .5, 1.5 and 2.5 studs over the ground: nothing hit
--   2. rays down at the Bear spot and the sign post: plaza marble within .1 of the root's ground (not the dais, not trim)
--   3. the station's base edge: rays down from the root toward the station centre every .25; where the surface stops
--      being the root's floor. PASS = 2.6 or more from the root. Else slide the root along e by the shortfall (at most
--      1.5, to no further than (-23.79, -10.00)) and run again
--   4. sight lines to the sign board's centre from (2.5, 21), (-10, 12), (-20, 8), 5 studs over the ground: nothing first
--   5. 9 points on the hub-to-Eggs walk: clear of the nest box (Block / 2 + .35)
--   plus the prompt point's floor (open marble) as before.
-- If 2 or 4 fails for the sign, try root-local (-1.9, y, 1.2) (NestClient.SignAt), then tell Fable. If it all fails,
-- Nest.Spot back to spot A (-17.5, 4.07, -2.5) and keep only the marker and screen-row parts.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Nest=require(Shared:WaitForChild("Nest"))
local Layout=require(Shared:WaitForChild("HollowWorldLayout"))
local BearSpot,SignAt=Vector3.new(-2.2,0,-1.4),Vector3.new(-1.7,0,1.6) -- NestClient's (a client module: copied here)
local params=RaycastParams.new()
params.FilterType=Enum.RaycastFilterType.Exclude
local skip={}
for _,name in ipairs({"EggDropSleepyNest","EggDropShowMe","EggDropDashLine"})do local f=workspace:FindFirstChild(name,true);if f then table.insert(skip,f)end end
params.FilterDescendantsInstances=skip
local spot=Nest.Spot
local function down(x,z)
	local hit=workspace:Raycast(Vector3.new(x,spot.Y+6,z),Vector3.new(0,-12,0),params)
	return hit and hit.Position.Y,hit and hit.Instance:GetFullName()or "nothing"
end
local ground,floorName=down(spot.X,spot.Z)
ground=ground or spot.Y
local root=CFrame.lookAt(Vector3.new(spot.X,ground,spot.Z),Vector3.new(Nest.Facing.X,ground,Nest.Facing.Z))
local out={}
local function say(fmt,...)table.insert(out,string.format(fmt,...))end
say("root (%.2f, %.2f) ground %.2f on %s (walk map %.2f)",spot.X,spot.Z,ground,floorName,spot.Y)
-- 1
local blocked={}
for _,height in ipairs({.5,1.5,2.5})do
	local centre=Vector3.new(spot.X,ground+height,spot.Z)
	for k=0,15 do
		local a=k/16*math.pi*2
		local hit=workspace:Raycast(centre,Vector3.new(math.cos(a),0,math.sin(a))*2.6,params)
		if hit then table.insert(blocked,string.format("%.1f up, %d deg: %s at %.2f",height,k*360/16,hit.Instance:GetFullName(),hit.Distance))end
	end
end
say("1 ring r 2.6: %s%s",#blocked==0 and "PASS"or "FAIL\n  ",table.concat(blocked,"\n  "))
-- 2
for _,row in ipairs({{"Bear spot",BearSpot},{"sign post",SignAt},{"prompt point",Vector3.new(0,0,-Nest.Front)}})do
	local p=root*row[2]
	local y,name=down(p.X,p.Z)
	local ok=y~=nil and math.abs(y-ground)<=.1
	say("2 %s (%.2f, %.2f): %s, y %s on %s",row[1],p.X,p.Z,ok and "PASS"or "FAIL",y and string.format("%.2f",y)or "-",name)
end
-- 3
local S=Layout.Stations.Eggs.Position
local toward=Vector3.new(S.X-spot.X,0,S.Z-spot.Z)
local span=toward.Magnitude
toward=toward.Unit
local edge=nil
for d=0,span,.25 do
	local p=spot+toward*d
	local y,name=down(p.X,p.Z)
	if y==nil or math.abs(y-ground)>.1 then edge=d;say("3 base edge at %.2f from the root (%s, y %s): %s",d,name,y and string.format("%.2f",y)or "-",d>=2.6 and "PASS"or("FAIL, slide %.2f along e"):format(2.6-d));break end
end
if not edge then say("3 no edge found up to the station centre (%.2f): check the station mesh is in the probe's reach",span)end
-- 4
local board=root*Vector3.new(SignAt.X,1.45,SignAt.Z)
for _,from in ipairs({Vector2.new(2.5,21),Vector2.new(-10,12),Vector2.new(-20,8)})do
	local y=down(from.X,from.Y)or spot.Y
	local eye=Vector3.new(from.X,y+5,from.Y)
	local hit=workspace:Raycast(eye,board-eye,params)
	say("4 sight from (%.1f, %.1f): %s",from.X,from.Y,if hit==nil or(hit.Position-board).Magnitude<.6 then "PASS"else "FAIL, "..hit.Instance:GetFullName()..string.format(" at %.1f",hit.Distance))
end
-- 5
local Hub=Layout.Landmarks.Hub
local worst=math.huge
for k=0,8 do
	local t=k/8
	local p=Vector2.new(Hub.X+(S.X-Hub.X)*t,Hub.Y+(S.Z-Hub.Y)*t)
	local d=(root:PointToObjectSpace(Vector3.new(p.X,ground,p.Y))*Vector3.new(1,0,1))
	worst=math.min(worst,math.max(math.abs(d.X),math.abs(d.Z))-Nest.Block/2)
end
say("5 the hub-to-Eggs walk clears the nest box by %.2f: %s",worst,worst>=.35 and "PASS"or "FAIL")
print(table.concat(out,"\n"))
