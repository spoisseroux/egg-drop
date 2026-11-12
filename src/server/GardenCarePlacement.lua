local S=game:GetService("ReplicatedStorage").Shared
local Layout=require(S.GardenCareLayout);local World=require(S.HollowWorldLayout)
local Walk=require(S.GardenWalkability);local Planner=require(S.GardenPathPlanner)
local Placement={}
function Placement.clear(point,room,wet)
 local floor=room and room:FindFirstChild("Floor");if not floor then return nil end
 local localPoint=floor.CFrame:PointToObjectSpace(point)
 if math.abs(localPoint.X)>floor.Size.X*.5-1.1 or math.abs(localPoint.Z)>floor.Size.Z*.5-1.1 then return nil end
 local params=RaycastParams.new();params.RespectCanCollide=true;params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={room}
 local y
 for _,offset in ipairs({Vector3.zero,Vector3.new(-.9,0,-.9),Vector3.new(.9,0,-.9),Vector3.new(-.9,0,.9),Vector3.new(.9,0,.9)})do
  local hit=workspace:Raycast(point+offset+Vector3.new(0,5,0),Vector3.new(0,-12,0),params)
  if not hit or hit.Material==Enum.Material.Water then return nil end
  if y and math.abs(hit.Position.Y-y)>.12 then return nil end;y=y or hit.Position.Y
  local p=Vector3.new(point.X+offset.X,hit.Position.Y+.025,point.Z+offset.Z)
  local span,id=Walk.spanAt(p)
  if span and hit.Instance:GetAttribute("GardenWalkableSpan")~=id then return nil end
  if not Walk.segmentAllowed(p,p,wet)then return nil end
 end
 local grounded=Vector3.new(point.X,y+.025,point.Z)
 local overlap=OverlapParams.new();overlap.RespectCanCollide=true;overlap.FilterType=Enum.RaycastFilterType.Include;overlap.FilterDescendantsInstances={room}
 local box=Layout.Footprint
 -- Merged island meshes are skipped: their bounds cover the whole world; rays above checked the ground.
 for _,hit in ipairs(workspace:GetPartBoundsInBox(CFrame.new(grounded+Vector3.new(0,box.Y*.5+.06,0)),box,overlap))do
  if hit:GetAttribute("WorldMesh")~=true then return nil end
 end
 return grounded
end
function Placement.find(input,room,wet,solids)
 if not input.root then return nil end
 local cf=input.root.CFrame
 for _,offset in ipairs({Vector3.new(2.6,0,-2),Vector3.new(-2.6,0,-2),Vector3.new(0,0,-3),Vector3.new(3,0,0),Vector3.new(-3,0,0),Vector3.new(2,0,2),Vector3.new(-2,0,2),Vector3.new(0,0,3)})do
  local p=cf:PointToWorldSpace(offset);p=Vector3.new(p.X,input.anchor.Y,p.Z)
  local supported=Placement.clear(p,room,wet)
  if supported and math.abs(supported.Y-input.anchor.Y)<1 then
   local path=Planner.plan(input.anchor,supported,Vector3.zero,3,0,input.yaw,nil,Vector3.zero,wet)
   local last=path[#path]
   if last and not last.safetyStop and(Vector3.new(table.unpack(last.to))-supported).Magnitude<.05 and Walk.pathAllowed(path,wet)and Planner.restPathClear(path,solids)then return supported end
  end
 end
 return nil
end
return Placement
