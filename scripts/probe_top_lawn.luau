-- Read-only Studio probe for the Top Lawn and the Paw Glade (WORLD-FINISH-LOOK section 1, slice B). Run through Studio
-- MCP execute_luau on the SERVER in Play mode on the beta place or in Studio, with the tier open (/tier on) and the
-- island's sculpt in (workspace CliffDen). It changes nothing. The Top Lawn's raycast sweep ("every anchor gets the
-- Studio raycast sweep; nudge up to 1.5 studs and tell me"): rays straight down onto the terrace at every equipment root,
-- slot approach and pose, the ladder, the chute's run, the bench's ends, both gaps, the rim (72 points) and a ring 2
-- outside it, each PASS when the floor under it is the terrace's top within .15 (Tier.FloorY) and nothing stands over
-- it within 6 (the greybox crates and outcrops). Then the models: PetPark_grove on the terrace, PawGlade by the cliff.
local RS=game:GetService("ReplicatedStorage")
local Shared=RS:WaitForChild("Shared")
local Park=require(Shared.ParkLayout)
local Tier=require(Shared.Tier)
local out={}
local function say(line)table.insert(out,line);print(line)end
local site=Park.ById.grove
if not site.Terrace then say("SKIP the second park is not the Top Lawn here (ParkTopLawn off, or live)");return table.concat(out,"\n")end
local room=workspace:FindFirstChild("EggDropLounge")
if not room or not room:FindFirstChild(Tier.Model)then say("FAIL the terrace greybox is not built (tier closed?): /tier on");return table.concat(out,"\n")end
local params=RaycastParams.new();params.RespectCanCollide=true
params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={room}
local bad,worst=0,0
local function probe(label,p)
	local top=Tier.FloorY+6
	local hit=workspace:Raycast(Vector3.new(p.X,top+20,p.Z),Vector3.new(0,-40,0),params)
	local y=hit and hit.Position.Y
	local over=hit and y>Tier.FloorY+.15
	local miss=not hit or math.abs(y-Tier.FloorY)>.15
	if hit then worst=math.max(worst,math.abs(y-Tier.FloorY))end
	if miss or over then
		bad+=1
		say(string.format("FAIL %s (%.2f, %.2f): %s",label,p.X,p.Z,if hit then string.format("floor %.2f on %s",y,hit.Instance:GetFullName())else "nothing under it"))
	end
end
for id,e in pairs(site.Equipment)do probe("equipment "..id,e.position)end
for id,slot in pairs(site.Slots)do
	probe("slot "..id.." approach",slot.approach);probe("slot "..id.." pose",slot.pose.position)
	for _,key in ipairs({"seatGround","ladderTop","chuteTop","chuteEnd","castle","ball"})do if slot[key]then probe("slot "..id.."."..key,slot[key])end end
end
local deck,foot=site.Equipment.slide.position,site.Slots.slide.chuteEnd
for k=0,6 do probe("chute run "..k,deck:Lerp(foot,k/6))end
local bench=site.Benches[1]
local along=Vector3.new(math.cos(bench.yaw),0,-math.sin(bench.yaw))
for _,side in ipairs({-1,0,1})do probe("bench "..side,bench.position+along*side*bench.length*.5)end
for _,gate in ipairs(site.Gateways)do probe("gap "..gate.id,gate.position)end
for k=0,71 do
	local a=k*math.pi/36
	probe("rim "..k,Vector3.new(site.Center.X+site.Radius.X*math.cos(a),0,site.Center.Z+site.Radius.Y*math.sin(a)))
	probe("rim+2 "..k,Vector3.new(site.Center.X+(site.Radius.X+2)*math.cos(a),0,site.Center.Z+(site.Radius.Y+2)*math.sin(a)))
end
say(string.format("%s Top Lawn sweep: %d failing points, the floor within %.3f of %d elsewhere",if bad==0 then "PASS"else "FAIL",bad,worst,Tier.FloorY))
local park=workspace:FindFirstChild("PetPark_grove")
say(string.format("%s PetPark_grove %s",if park then "PASS"else "FAIL",if park then "mounted ("..tostring(park:GetAttribute("ParkMeshesReady"))..")"else "missing (no CliffDen at server start?)"))
local glade=workspace:FindFirstChild("PawGlade")
say(string.format("%s PawGlade %s",if glade and glade:GetAttribute("GladeReady")then "PASS"else "FAIL",
	if glade then string.format("%d seats, %d colliders",#glade.Seats:GetChildren(),#glade.Colliders:GetChildren())else "missing"))
-- The Paw Glade's pieces sit on the lawn: each stone, stump and the bench on the ground within .3.
if glade and Park.Glade then
	local G=Park.Glade
	local lawnBad=0
	local function lawn(label,x,y,z)
		local hit=workspace:Raycast(Vector3.new(x,y+6,z),Vector3.new(0,-12,0),params)
		if not hit or math.abs(hit.Position.Y-y)>.3 then lawnBad+=1;say(string.format("FAIL glade %s (%.1f, %.1f): %s",label,x,z,if hit then string.format("ground %.2f, want %.2f",hit.Position.Y,y)else "no ground"))end
	end
	for _,s in ipairs(G.stones)do lawn(s.name,s.x,s.y,s.z)end
	for _,s in ipairs(G.stumps)do lawn("stump",s.x,s.y,s.z)end
	lawn("bench",G.bench.position.X,G.bench.position.Y,G.bench.position.Z)
	say(string.format("%s Paw Glade on the lawn (%d off)",if lawnBad==0 then "PASS"else "FAIL",lawnBad))
end
return table.concat(out,"\n")
