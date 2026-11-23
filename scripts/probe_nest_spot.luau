-- Read-only Studio probe for the nest's plaza spot (GARDEN-LIFE-NEST-LOOK 4 [check]; GARDEN-LIFE-NEST-BUILD-PLAN 5).
-- Run through Studio MCP execute_luau in Edit mode on the beta place. It changes nothing and saves nothing. A ring of
-- 16 horizontal rays at r 2.6 round Nest.Spot, at .5, 1.5 and 2.5 studs over the ground, must hit nothing (benches,
-- urns and pedestals are merged into the world mesh, so only a ray can see them), and the prompt point (root-local
-- (0, 0, -2.6)) must land on open marble. If A is blocked: slide along the rim (12.6 from (-30, -4), z -7 to 1), else B
-- (-22.5, 4.07, 5.5); change Nest.Spot only, then rerun scripts/NestSpot.spec.lua.
local Nest=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Nest"))
local params=RaycastParams.new()
params.FilterType=Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances={}
local spot=Nest.Spot
local down=workspace:Raycast(spot+Vector3.new(0,6,0),Vector3.new(0,-12,0),params)
local ground=down and down.Position.Y or spot.Y
local blocked={}
for _,height in ipairs({.5,1.5,2.5})do
	local centre=Vector3.new(spot.X,ground+height,spot.Z)
	for k=0,15 do
		local a=k/16*math.pi*2
		local hit=workspace:Raycast(centre,Vector3.new(math.cos(a),0,math.sin(a))*2.6,params)
		if hit then table.insert(blocked,string.format("%.1f up, %d deg: %s at %.2f",height,k*360/16,hit.Instance:GetFullName(),hit.Distance))end
	end
end
local root=CFrame.lookAt(Vector3.new(spot.X,ground,spot.Z),Vector3.new(Nest.Facing.X,ground,Nest.Facing.Z))
local prompt=(root*CFrame.new(0,0,-2.6)).Position
local floor=workspace:Raycast(prompt+Vector3.new(0,6,0),Vector3.new(0,-12,0),params)
print(string.format("ground %.2f (walk map %.2f); prompt point (%.1f, %.1f) on %s at %.2f",ground,spot.Y,prompt.X,prompt.Z,
	floor and floor.Instance:GetFullName()or "nothing",floor and floor.Position.Y or 0/0))
print(#blocked==0 and "spot A is clear all round"or("blocked:\n"..table.concat(blocked,"\n")))
