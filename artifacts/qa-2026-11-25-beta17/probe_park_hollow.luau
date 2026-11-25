-- Read-only Studio probe for the Hollow park (WORLD-ALIVE-LOOK section 2; ParkLayout.Specs.hollow). Run through Studio
-- MCP execute_luau (or the command bar) in Edit mode on either place: it builds the Hollow's layout from its spec, so it
-- works with the switch on or off. It changes nothing and saves nothing. Fable: "every position gets the Studio raycast
-- sweep (flat ground under each anchor, the rim and 2 studs outside). Nudge by up to 1.5 studs and tell me."
--
--   H1 ground: a ray down at every piece root, slot approach, seat/ladder/chute point, bench seat and end, gap, the palm,
--      every dressing item, 64 rim points and 64 points 2 studs outside. FLAG when it hits anything but lawn-like
--      ground, the hit is .3+ off HollowWorldLayout.groundY (what the layout used), or the normal tilts past 15 degrees.
--   H2 flat under pieces: under each piece's footprint (keepout radius), 16 rays; FLAG a spread over .35.
--   H3 obstacles: parts (not ground, not the park) whose box rises 1+ stud over the lawn within each piece's keepout,
--      the bench, the gaps and the slot approaches (trunks, rocks, lamp posts, roots).
--   H4 the cliff wall: from each toe toward the cliff, the first 2-stud step where the ground rises 1+ stud: distance
--      from the piece root (the phone camera check wants the wall 6+ studs behind toe 3).
--   H5 rim inside: every slot approach and the chute foot inside the circle less 1 stud (data, repeated for the record).
--   H6 north limit: the most southern point of everything (z); the cliff path bank is at z under -80, keep 15 clear.
-- Prints a report and returns it as a string. Paste the FLAG lines back into the build notes.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Park=require(Shared:WaitForChild("ParkLayout"))
local World=require(Shared:WaitForChild("HollowWorldLayout"))
local H=Park.build(Park.Specs.hollow)
local out,flags={},0
local function say(fmt,...)table.insert(out,string.format(fmt,...))end
local function flag(fmt,...)flags+=1;table.insert(out,"FLAG "..string.format(fmt,...))end

local params=RaycastParams.new()
params.FilterType=Enum.RaycastFilterType.Exclude
local skip={}
for _,child in ipairs(workspace:GetChildren())do
	if string.find(child.Name,"^PetPark")or child:IsA("Model")and game:GetService("Players"):GetPlayerFromCharacter(child)then table.insert(skip,child)end
end
for _,name in ipairs({"GardenDash","EggDropDashLine"})do local f=workspace:FindFirstChild(name,true);if f then table.insert(skip,f)end end
params.FilterDescendantsInstances=skip
local GROUNDISH={"lawn","ground","grass","terrain","island","w7c","walk","floor"}
local function groundish(instance)
	if instance:IsA("Terrain")then return true end
	local name=string.lower(instance:GetFullName())
	for _,word in ipairs(GROUNDISH)do if string.find(name,word,1,true)then return true end end
	return false
end
local function down(x,z)return workspace:Raycast(Vector3.new(x,60,z),Vector3.new(0,-120,0),params)end

-- H1 ---------------------------------------------------------------------------------------------------------------
local checked=0
local function probe(label,x,z)
	checked+=1
	local hit=down(x,z)
	local want=World.groundY(x,z)
	if not hit then flag("H1 %s (%.2f, %.2f): no ground",label,x,z);return nil end
	local dy=hit.Position.Y-want
	local tilt=math.deg(math.acos(math.clamp(hit.Normal.Y,-1,1)))
	if not groundish(hit.Instance)then flag("H1 %s (%.2f, %.2f): hit %s at y %.2f",label,x,z,hit.Instance:GetFullName(),hit.Position.Y)
	elseif math.abs(dy)>=.3 then flag("H1 %s (%.2f, %.2f): ground y %.2f, layout used %.2f (%+.2f)",label,x,z,hit.Position.Y,want,dy)
	elseif tilt>15 then flag("H1 %s (%.2f, %.2f): slope %.0f degrees",label,x,z,tilt)end
	return hit
end
local points={}
local function add(label,v)table.insert(points,{label,v.X,v.Z})end
for id,e in pairs(H.Equipment)do add("root "..id,e.position)end
for id,slot in pairs(H.Slots)do
	add("approach "..id,slot.approach)
	for _,key in ipairs({"seatGround","chuteEnd"})do if slot[key]then add(key.." "..id,slot[key])end end
end
local bench=H.Benches[1]
local along=Vector3.new(math.cos(bench.yaw),0,-math.sin(bench.yaw))
add("bench",bench.position)
for _,side in ipairs({-1,1})do add("bench end",bench.position+along*side*bench.length*.5)end
for _,gate in ipairs(H.Gateways)do add("gap "..gate.id,gate.position)end
local D=H.Dressing
add("palm",D.palm)
for _,row in ipairs(D.plates)do table.insert(points,{row.name,row.x,row.z})end
for _,row in ipairs(D.stones)do table.insert(points,{row.name,row.x,row.z})end
for _,row in ipairs(D.stumps)do table.insert(points,{"stump",row.x,row.z})end
for _,row in ipairs(D.flowers)do table.insert(points,{"flowers",row.x,row.z})end
for k=-2,2 do
	local s=k*D.log.length/4
	table.insert(points,{"log",D.log.x+s*math.sin(D.log.heading),D.log.z+s*math.cos(D.log.heading)})
end
table.insert(points,{"column",D.column.x,D.column.z})
for k=0,63 do
	local a=k*math.pi/32
	table.insert(points,{string.format("rim %d deg",k*360//64),H.Center.X+H.Radius.X*math.cos(a),H.Center.Z+H.Radius.Y*math.sin(a)})
	table.insert(points,{string.format("rim+2 %d deg",k*360//64),H.Center.X+(H.Radius.X+2)*math.cos(a),H.Center.Z+(H.Radius.Y+2)*math.sin(a)})
end
for _,p in ipairs(points)do probe(p[1],p[2],p[3])end
say("H1 %d ground rays",checked)

-- H2 ---------------------------------------------------------------------------------------------------------------
for id,e in pairs(H.Equipment)do
	local lo,hi=math.huge,-math.huge
	for k=0,15 do
		local a=k*math.pi/8
		for _,r in ipairs({e.keepout*.5,e.keepout})do
			local hit=down(e.position.X+r*math.cos(a),e.position.Z+r*math.sin(a))
			if hit then lo,hi=math.min(lo,hit.Position.Y),math.max(hi,hit.Position.Y)end
		end
	end
	if hi-lo>.35 then flag("H2 %s: ground spread %.2f under its footprint (%.2f to %.2f)",id,hi-lo,lo,hi)
	else say("H2 %s: flat (%.2f spread)",id,hi-lo)end
end

-- H3 ---------------------------------------------------------------------------------------------------------------
local overlap=OverlapParams.new()
overlap.FilterType=Enum.RaycastFilterType.Exclude
overlap.FilterDescendantsInstances=skip
local function obstacles(label,x,z,radius)
	local floor=World.groundY(x,z)
	for _,part in ipairs(workspace:GetPartBoundsInRadius(Vector3.new(x,floor+2,z),radius,overlap))do
		local top=part.Position.Y+part.Size.Y*.5
		local bottom=part.Position.Y-part.Size.Y*.5
		local huge=part.Size.X>60 or part.Size.Z>60 -- the merged world mesh: its box covers the island, H1 judges it
		if not huge and top>floor+1 and bottom<floor+4 and not groundish(part)then
			flag("H3 %s: %s within %.1f (top %.2f)",label,part:GetFullName(),radius,top)
		end
	end
end
for id,e in pairs(H.Equipment)do obstacles("piece "..id,e.position.X,e.position.Z,e.keepout)end
for id,slot in pairs(H.Slots)do obstacles("approach "..id,slot.approach.X,slot.approach.Z,1.2)end
obstacles("bench",bench.position.X,bench.position.Z,bench.length*.5+.5)
for _,gate in ipairs(H.Gateways)do obstacles("gap "..gate.id,gate.position.X,gate.position.Z,3)end
obstacles("log",D.log.x,D.log.z,D.log.length*.5+.5)
say("H3 done (the merged world mesh is left to H1)")

-- H4 ---------------------------------------------------------------------------------------------------------------
local cliff=Vector2.new(-48,-64) -- toward the cliff foot behind the fan
for _,id in ipairs({"seesaw","slide","sandbox","swing"})do
	local root=H.Equipment[id].position
	local dir=(cliff-Vector2.new(root.X,root.Z)).Unit
	local base=down(root.X,root.Z)
	local wall
	for step=1,12 do
		local x,z=root.X+dir.X*step*2,root.Z+dir.Y*step*2
		local hit=down(x,z)
		if hit and base and hit.Position.Y-base.Position.Y>=1 then wall=step*2;break end
	end
	say("H4 %s: the ground rises 1+ stud %s",id,wall and string.format("%d studs toward the cliff",wall)or "nowhere within 24 studs")
	if id=="sandbox"and wall and wall<6 then flag("H4 sandbox (toe 3): wall %d studs behind, phone camera wants 6+",wall)end
end

-- H5 / H6 ------------------------------------------------------------------------------------------------------------
for id,slot in pairs(H.Slots)do
	if not H.inside(slot.approach,-1)then flag("H5 %s approach within 1 stud of the rim",id)end
end
if not H.inside(H.Slots.slide.chuteEnd,-1)then flag("H5 chute foot within 1 stud of the rim")end
local south=math.huge
for _,p in ipairs(points)do south=math.min(south,p[3])end
say("H6 most southern point z %.2f (rim+2 included); the cliff path bank is at z under -80: %.1f studs clear",south,south+80)
if south<-67.01 then flag("H6 a point at z %.2f, south of the rim+2 ring",south)end

say("%d FLAG(s). Hollow centre (%.1f, %.1f) radius %.1f; switch on here: %s",flags,H.Center.X,H.Center.Z,H.Radius.X,tostring(Park.HollowOn))
local report=table.concat(out,"\n")
print(report)
return report
