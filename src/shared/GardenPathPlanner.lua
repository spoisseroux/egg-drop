-- Authored crossing detours (any bridge) and a small visibility graph around
-- wet/blocked regions; preserves the existing bounded motion planner.
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
-- Waypoints sit on the bare ground (flat FloorTop in the legacy world).
local function floorPoint(x,z)return Vector3.new(x,World.groundY(x,z)+.025,z)end
local function deckEnds(bridge)
 return bridge.center.X-bridge.size.X*.5+.30,bridge.center.X+bridge.size.X*.5-.30
end
-- The original single-bridge detour, unchanged, for any crossing bridge id.
local function detourTargets(id,from,to)
 local bridge=World.WalkableSpans[id];local top=Walk.top(bridge)
 local left,right=deckEnds(bridge)
 local z=bridge.center.Z
 local fromSpan,fromId=Walk.spanAt(from);local targetSpan,targetId=Walk.spanAt(to)
 local onDeck=fromId==id and math.abs(from.Y-top)<.08
 local targetOnDeck=targetId==id and math.abs(to.Y-top)<.08
 local fromEast,toEast=from.X>bridge.center.X,to.X>bridge.center.X
 local east=if onDeck then toEast else not fromEast
 local startX,endX=if east then left else right,if east then right else left
 local targets={}
 if not onDeck and not targetOnDeck and fromEast==toEast then
  -- Same-bank detours stay on that bank instead of unnecessarily crossing twice.
  table.insert(targets,floorPoint(if fromEast then right+1 else left-1,z))
 else
 if not onDeck then
  table.insert(targets,floorPoint(startX+(if east then -1 else 1),z))
  table.insert(targets,Vector3.new(startX,top,z))
 end
 if not targetOnDeck then
  -- An off-deck destination may have X just INSIDE the end of the bridge.
  -- Finish the supported crossing and landing before returning along its bank.
  table.insert(targets,Vector3.new(endX,top,z))
  table.insert(targets,floorPoint(endX+(if east then 1 else -1),z))
 end
 end
 table.insert(targets,to)
 return targets
end
local CROSSINGS=(function()
 local ids={}
 for id,span in pairs(World.WalkableSpans)do if span.crossing then table.insert(ids,id)end end
 table.sort(ids)
 return table.freeze(ids)
end)()
local function crossingIds()return CROSSINGS end
-- Graph waypoints must stand on the floor, clear of its edge walls and cliffs.
local FLOOR_MARGIN=1.5
local function onFloor(p)
 return math.abs(p.X-World.FloorCenterX)<=World.Width*.5-FLOOR_MARGIN and math.abs(p.Z-World.FloorCenterZ)<=World.Depth*.5-FLOOR_MARGIN
end
local function length(from,targets)
 local total,at=0,from
 for _,p in ipairs(targets)do total+=(p-at).Magnitude;at=p end
 return total
end
-- Static visibility graph: bridge landings/decks plus the corners of every
-- authored wet or blocked region, so a pet can go around a pond or terrace and
-- chain several bridges. Cached per wet list; endpoints are linked per call.
local CORNER_CLEARANCE=1.1
local graphCache=setmetatable({},{__mode="k"})
local function staticGraph(wet)
 local cached=graphCache[wet]
 if cached and cached.count==#wet then return cached end
 local nodes,trusted={},{}
 local function add(p,deck)table.insert(nodes,{p=p,deck=deck});return #nodes end
 local function link(a,b)trusted[a]=trusted[a]or{};trusted[b]=trusted[b]or{};trusted[a][b]=true;trusted[b][a]=true end
 local decks={}
 for _,id in ipairs(crossingIds())do
  local bridge=World.WalkableSpans[id];local top=Walk.top(bridge);local left,right=deckEnds(bridge);local z=bridge.center.Z
  local a,b=add(floorPoint(left-1,z),false),add(Vector3.new(left,top,z),true)
  local c,d=add(Vector3.new(right,top,z),true),add(floorPoint(right+1,z),false)
  link(a,b);link(b,c);link(c,d);decks[id]={b,c}
 end
 for _,part in ipairs(wet)do
  if part.Parent and(part:GetAttribute("GardenWetRegion")==true or part:GetAttribute("GardenBlockedRegion")==true)then
   for _,sx in ipairs({-1,1})do for _,sz in ipairs({-1,1})do
    local c=part.CFrame:PointToWorldSpace(Vector3.new(sx*(part.Size.X*.5+CORNER_CLEARANCE),0,sz*(part.Size.Z*.5+CORNER_CLEARANCE)))
    local p=floorPoint(c.X,c.Z)
    if onFloor(p)and Walk.segmentAllowed(p,p,wet)then add(p,false)end
   end end
  end
 end
 local visible={}
 for i=1,#nodes do visible[i]={} end
 for i=1,#nodes do for j=i+1,#nodes do
  local ok=(trusted[i]and trusted[i][j])or(not nodes[i].deck and not nodes[j].deck and Walk.segmentAllowed(nodes[i].p,nodes[j].p,wet))
  if ok then visible[i][j]=true;visible[j][i]=true end
 end end
 cached={count=#wet,nodes=nodes,visible=visible,decks=decks}
 graphCache[wet]=cached
 return cached
end
local function graphTargets(from,to,wet)
 local graph=staticGraph(wet);local nodes=graph.nodes;local n=#nodes
 local fromIndex,toIndex=n+1,n+2
 local points={};for i=1,n do points[i]=nodes[i].p end;points[fromIndex],points[toIndex]=from,to
 local function endpointEdges(p)
  local edges={}
  local _,id=Walk.spanAt(p);local deck=id and graph.decks[id]
  for i=1,n do
   if deck and(i==deck[1]or i==deck[2])then edges[i]=true
   elseif not nodes[i].deck and Walk.segmentAllowed(p,nodes[i].p,wet)then edges[i]=true end
  end
  return edges
 end
 local fromEdges,toEdges=endpointEdges(from),endpointEdges(to)
 local function neighbours(i)
  if i==fromIndex then return fromEdges end
  local result=table.clone(graph.visible[i]);if toEdges[i]then result[toIndex]=true end
  return result
 end
 local dist,prev,done={[fromIndex]=0},{},{}
 while true do
  local best,bestDist=nil,math.huge
  for i,d in pairs(dist)do if not done[i]and d<bestDist then best,bestDist=i,d end end
  if not best or best==toIndex then break end
  done[best]=true
  for j in pairs(neighbours(best))do
   local d=bestDist+(points[j]-points[best]).Magnitude
   if not done[j]and d<(dist[j]or math.huge)then dist[j],prev[j]=d,best end
  end
 end
 if not dist[toIndex]then return nil end
 local reversed,at={},toIndex
 while at~=fromIndex do table.insert(reversed,points[at]);at=prev[at] end
 local targets={};for i=#reversed,1,-1 do table.insert(targets,reversed[i])end
 return targets
end
function Planner.plan(from,to,velocity,speed,minimum,yaw,via,terminal,wet)
 local direct,duration=A.plan(from,to,velocity,speed,minimum,yaw,via,terminal)
 if Walk.pathAllowed(direct,wet)then return direct,duration end
 local function build(targets)
  local path,total={},0;local position,v,heading=from,velocity,yaw
  for _,target in ipairs(targets)do
   if (target-position).Magnitude<1e-4 then continue end
   local part,seconds=A.plan(position,target,v,speed,0,heading)
   for _,leg in ipairs(part)do table.insert(path,leg)end
   total+=seconds
   local last=part[#part];heading=last.yaw+last.turn;position,v=target,Vector3.zero
  end
  return path,total
 end
 -- Single-bridge detours (identical to the original planner for one bridge)
 -- and the multi-waypoint graph route; keep the shortest valid one. A graph
 -- route must be clearly shorter to replace a valid authored detour.
 local candidates={}
 for _,id in ipairs(crossingIds())do
  local targets=detourTargets(id,from,to)
  table.insert(candidates,{targets=targets,length=length(from,targets)})
 end
 table.sort(candidates,function(a,b)return a.length<b.length end)
 local best
 for _,candidate in ipairs(candidates)do
  local path,total=build(candidate.targets)
  if #path>0 and Walk.pathAllowed(path,wet)then best={path=path,total=total,length=candidate.length};break end
 end
 local targets=graphTargets(from,to,wet)
 if targets then
  local graphLength=length(from,targets)
  if not best or graphLength<best.length-1 then
   local path,total=build(targets)
   if #path>0 and Walk.pathAllowed(path,wet)then best={path=path,total=total,length=graphLength}end
  end
 end
 if best then return best.path,best.total end
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
