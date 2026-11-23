-- Read-only Studio probe for the leaves' covered places (GARDEN-LIFE-NEST-BUILD-PLAN section 3; LifeSim.LeafCover).
-- Run through Studio MCP execute_luau in Edit mode on the beta place (107705084891479). It changes nothing and saves
-- nothing: it casts straight up from the walk map's ground on a 2-stud grid over the island and lists every cell with
-- solid, non-foliage geometry less than 25 studs over the ground (a roof, an arch, a cave ceiling), then joins the cells
-- into circles (x, z, r) ready to paste into LifeSim.LeafCover. Tree crowns (foliage, bark) do not count.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Layout=require(Shared:WaitForChild("HollowWorldLayout"))
local Data=require(Shared:WaitForChild("WorldV7Data"))
local G=Data.ground
local params=RaycastParams.new()
params.FilterType=Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances={}
local skip={foliage=true,foliage_blossom=true,bark=true,glow_warm=true,glow_aqua=true,glow_pink=true,water_stream=true,water_pool=true}
local function material(part)
	local name=part.Name or ""
	return string.match(name,"__([%w_]+)$")or name
end
local cells={}
for j=0,G.nz-1 do
	for i=0,G.nx-1 do
		local h=G.h[j*G.nx+i+1]
		if type(h)=="number"and h>-900 then
			local x,z=G.x0+i*G.step,G.z0+j*G.step
			for _,dx in ipairs({0,G.step/2})do
				for _,dz in ipairs({0,G.step/2})do
					local px,pz=x+dx,z+dz
					local y=Layout.groundY(px,pz)
					local hit=workspace:Raycast(Vector3.new(px,y+1.5,pz),Vector3.new(0,25,0),params)
					if hit and hit.Instance and hit.Instance:IsA("BasePart")and not skip[material(hit.Instance)]then
						table.insert(cells,{x=px,z=pz,over=hit.Position.Y-y,what=hit.Instance:GetFullName()})
					end
				end
			end
		end
	end
end
-- Join cells within 4 studs of each other into clusters; each becomes a circle round its cells (+1 stud).
local groups={}
for _,cell in ipairs(cells)do
	local home
	for _,group in ipairs(groups)do
		for _,other in ipairs(group)do
			if math.abs(other.x-cell.x)<=4 and math.abs(other.z-cell.z)<=4 then home=group;break end
		end
		if home then break end
	end
	if not home then home={};table.insert(groups,home)end
	table.insert(home,cell)
end
local out={}
for _,group in ipairs(groups)do
	local sx,sz=0,0
	for _,cell in ipairs(group)do sx+=cell.x;sz+=cell.z end
	local cx,cz=sx/#group,sz/#group
	local r=0
	for _,cell in ipairs(group)do r=math.max(r,math.sqrt((cell.x-cx)^2+(cell.z-cz)^2))end
	table.insert(out,string.format('{name="%s",x=%.1f,z=%.1f,r=%.1f}, -- %d cells',group[1].what,cx,cz,r+1,#group))
end
print(#cells.." covered cells in "..#groups.." places:\n"..table.concat(out,"\n"))
