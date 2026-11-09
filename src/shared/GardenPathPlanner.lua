-- Finite authored crossing detour; preserves the existing bounded motion planner.
local A=require(script.Parent.GardenActivity)
local Walk=require(script.Parent.GardenWalkability)
local World=require(script.Parent.HollowWorldLayout)
local Planner={}
function Planner.restPathClear(path,solids)
 -- A cubic stays inside its control hull. Reject a conservative body-sized
 -- hull/solid overlap, including braking excursions missed by endpoint rays.
 for _,leg in ipairs(path)do
  local from,to=A.vector(leg.from),A.vector(leg.to)
  local points={from,from+A.vector(leg.v0)*leg.duration/3,to-A.vector(leg.v1)*leg.duration/3,to}
  for _,solid in ipairs(solids)do if solid.Parent and solid.CanCollide then
   local cf=solid.CFrame
   local function radius(axis)return math.abs(axis.X)*.8+math.abs(axis.Y)*.8+math.abs(axis.Z)*.8 end
   local extent=solid.Size*.5+Vector3.new(radius(cf.RightVector),radius(cf.UpVector),radius(cf.LookVector))
   local low,high=Vector3.new(math.huge,math.huge,math.huge),Vector3.new(-math.huge,-math.huge,-math.huge)
   for _,point in ipairs(points)do
    local p=cf:PointToObjectSpace(point+Vector3.new(0,.85,0))
    low=Vector3.new(math.min(low.X,p.X),math.min(low.Y,p.Y),math.min(low.Z,p.Z))
    high=Vector3.new(math.max(high.X,p.X),math.max(high.Y,p.Y),math.max(high.Z,p.Z))
   end
   if low.X<=extent.X and high.X>=-extent.X and low.Y<=extent.Y and high.Y>=-extent.Y and low.Z<=extent.Z and high.Z>=-extent.Z then return false end
  end end
 end
 return true
end
function Planner.plan(from,to,velocity,speed,minimum,yaw,via,terminal,wet)
 local direct,duration=A.plan(from,to,velocity,speed,minimum,yaw,via,terminal)
 if Walk.pathAllowed(direct,wet)then return direct,duration end
 local bridge=World.WalkableSpans.PrimaryBridge;local top=Walk.top(bridge)
 local left,right=bridge.center.X-bridge.size.X*.5+.30,bridge.center.X+bridge.size.X*.5-.30
 local z=bridge.center.Z
 local fromSpan,fromId=Walk.spanAt(from);local targetSpan,targetId=Walk.spanAt(to)
 local onDeck=fromId=="PrimaryBridge"and math.abs(from.Y-top)<.08
 local targetOnDeck=targetId=="PrimaryBridge"and math.abs(to.Y-top)<.08
 local fromEast,toEast=from.X>bridge.center.X,to.X>bridge.center.X
 local east=if onDeck then toEast else not fromEast
 local startX,endX=if east then left else right,if east then right else left
 local targets={}
 if not onDeck and not targetOnDeck and fromEast==toEast then
  -- Same-bank detours stay on that bank instead of unnecessarily crossing twice.
  table.insert(targets,Vector3.new((if fromEast then right+1 else left-1),World.FloorTop+.025,z))
 else
 if not onDeck then
  table.insert(targets,Vector3.new(startX+(if east then -1 else 1),World.FloorTop+.025,z))
  table.insert(targets,Vector3.new(startX,top,z))
 end
 if not targetOnDeck then
  -- An off-deck destination may have X just INSIDE the end of the bridge.
  -- Finish the supported crossing and landing before returning along its bank.
  table.insert(targets,Vector3.new(endX,top,z))
  table.insert(targets,Vector3.new(endX+(if east then 1 else -1),World.FloorTop+.025,z))
 end
 end
 table.insert(targets,to)
 local path,total={},0;local position,v,heading=from,velocity,yaw
 for _,target in ipairs(targets)do
  local part,seconds=A.plan(position,target,v,speed,0,heading)
  for _,leg in ipairs(part)do table.insert(path,leg)end
  total+=seconds
  local last=part[#part];heading=last.yaw+last.turn;position,v=target,Vector3.zero
 end
 if Walk.pathAllowed(path,wet)then return path,total end
 -- Unsupported water never becomes a shortcut. Brake/hold continuously on the
 -- last supported side; a subsequent owner update can select another route.
 local stop,seconds=A.plan(from,from,velocity,speed,.5,yaw)
 if Walk.pathAllowed(stop,wet)then return stop,seconds end
 -- Only this safety fence may discard velocity: there is physically no dry
 -- braking clearance. Hold the current root rather than enter forbidden water.
 local hold,holdSeconds=A.plan(from,from,Vector3.zero,speed,.5,yaw)
 for _,leg in ipairs(hold)do leg.safetyStop=true end
 return hold,holdSeconds
end
return Planner
