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
  if part.Parent and not part.KeepOut and(part:GetAttribute("GardenWetRegion")==true or part:GetAttribute("GardenBlockedRegion")==true)then
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
-- A walk through `targets`: one smooth walk when every leg passes `allowed` (beta (34): round a detour's corners),
-- else a stop at each, as before.
local function walkThrough(from,targets,velocity,speed,yaw,allowed)
 if #targets>1 then
  local smooth,seconds=A.through(from,targets,velocity,speed,yaw,function(leg)return allowed({leg})end)
  if smooth then return smooth,seconds end
 end
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
local function boxPlan(from,to,velocity,speed,minimum,yaw,via,terminal,wet)
 local direct,duration=A.plan(from,to,velocity,speed,minimum,yaw,via,terminal)
 if Walk.pathAllowed(direct,wet)then return direct,duration end
 local function build(targets)
  return walkThrough(from,targets,velocity,speed,yaw,function(path)return Walk.pathAllowed(path,wet)end)
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

-- Solid props (GARDEN-PLAY-BRIEF-2 section 4: GardenKeepOut circles in the wet list, beta only). The parts are planned
-- as before; a walk that would pass through a prop goes round it instead, the way ParkRoute goes round the park toys:
-- a small visibility graph over a hexagon of corners round each prop near the walk (props further out, then the parts'
-- own graph too, only when that finds nothing), every edge clear of every prop and part. A pet already standing in a
-- keep-out (it was there before the prop was) walks out of it. With no circles in the list none of this runs.
Planner.CirclePush=.25      -- hexagon corners stand this far beyond a keep-out, so an edge between two never grazes it
Planner.Corridors=table.freeze({0,4,10}) -- props within this of the straight walk join the graph, widest last
local HEX_OUT=1/math.cos(math.pi/6)
local function circleNodes(c)
 local out={}
 local r=(c.R+Planner.CirclePush)*HEX_OUT
 for k=0,5 do
  local a=k*math.pi/3+math.pi/6
  table.insert(out,floorPoint(c.X+math.cos(a)*r,c.Z+math.sin(a)*r))
 end
 return out
end
local function circlesClear(a,b,circles)
 for _,c in ipairs(circles)do if Walk.toSegment(c.X,c.Z,a.X,a.Z,b.X,b.Z)<c.R then return false end end
 return true
end
-- Review B36: the work is bounded. A search holds at most MaxNodes prop corners (the nearest to the walk) and, in its
-- last try only, the parts' own graph nodes (a fixed few dozen whose edges among themselves are already known), so it
-- expands each node at most once and asks each edge at most once. Every corner and every corner-to-corner edge (the "static" ones)
-- is checked once per layout and remembered, the way ParkRoute.prepare builds its graph once a site; only the edges to
-- this walk's two ends are checked per call. Planner.Stats holds the last roundProps call's work (specs).
Planner.MaxNodes=48       -- prop corners a search may hold (eight props' worth), the nearest to the walk
Planner.Stats={searches=0,expanded=0,checks=0,nodes=0}
-- The layout of one scene's circle list (Walk.split caches the list per scene; keyed weakly by it): the props' corners
-- clear of every prop and part, then (once a fallback needs them) the parts' own graph nodes, and the static edges.
-- A pet's escape only drops circles from the list, so a static edge clear of every circle is clear of what is left.
local layouts=setmetatable({},{__mode="k"})
local function layout(boxes,circles)
 local cached=layouts[circles]
 if cached and cached.boxes==boxes and cached.count==#circles and cached.boxCount==#boxes then return cached end
 local nodes={}
 for index,c in ipairs(circles)do
  for _,p in ipairs(circleNodes(c))do
   if onFloor(p)and circlesClear(p,p,circles)and Walk.segmentAllowed(p,p,boxes)then table.insert(nodes,{p=p,circle=c,index=index})end
  end
 end
 cached={boxes=boxes,count=#circles,boxCount=#boxes,circles=circles,nodes=nodes,corners=#nodes,edges={}}
 layouts[circles]=cached
 return cached
end
-- The parts' graph nodes join the layout once (its decks reached only along their own landings).
local function withParts(L)
 if L.graph then return end
 local graph=staticGraph(L.boxes)
 L.graph=graph
 for index,entry in ipairs(graph.nodes)do
  if entry.deck or circlesClear(entry.p,entry.p,L.circles)then table.insert(L.nodes,{p=entry.p,graph=index,deck=entry.deck})end
 end
end
local staticEdge
-- Every corner-to-corner edge of a scene's layout checked now (once; a server may call it as a scene is built so no walk
-- pays for it). The layout, or nil with no keep-outs.
function Planner.prepare(wet)
 local boxes,circles=Walk.split(wet)
 if #circles==0 then return nil end
 local L=layout(boxes,circles)
 for u=1,L.corners do for v=u+1,L.corners do staticEdge(L,u,v)end end
 return L
end
Planner.layout=layout
function staticEdge(L,u,v)
 if u>v then u,v=v,u end
 local key=u*65536+v
 local known=L.edges[key]
 if known~=nil then return known end
 local a,b=L.nodes[u],L.nodes[v]
 if a.graph and b.graph then known=L.graph.visible[a.graph][b.graph]==true and circlesClear(a.p,b.p,L.circles)
 elseif a.deck or b.deck then known=false
 else known=circlesClear(a.p,b.p,L.circles)and Walk.segmentAllowed(a.p,b.p,L.boxes)end
 L.edges[key]=known
 Planner.Stats.checks+=1
 return known
end
-- A* from `from` to `to` over the layout nodes `ids`. The two ends' edges are checked against `live` (the circles that
-- still count for this pet) and the parts.
local function search(L,from,to,ids,live)
 local points,static={from,to},{}
 for _,id in ipairs(ids)do table.insert(points,L.nodes[id].p);static[#points]=id end
 local n=#points
 local memo={}
 local function open(i,j)
  local si,sj=static[i],static[j]
  if si and sj then return staticEdge(L,si,sj)end
  local key=if i<j then i*65536+j else j*65536+i
  local known=memo[key]
  if known==nil then
   local node=L.nodes[si or sj]
   known=not(node and node.deck)and circlesClear(points[i],points[j],live)and Walk.segmentAllowed(points[i],points[j],L.boxes)
   memo[key]=known
   Planner.Stats.checks+=1
  end
  return known
 end
 Planner.Stats.searches+=1
 Planner.Stats.nodes=math.max(Planner.Stats.nodes,n)
 local goal=points[2]
 local dist,prev,done={[1]=0},{},{}
 for _=1,n do
  local best,bestScore=nil,math.huge
  for i,d in pairs(dist)do
   if not done[i]then
    local score=d+(points[i]-goal).Magnitude
    if score<bestScore then best,bestScore=i,score end
   end
  end
  if not best or best==2 then break end
  done[best]=true
  Planner.Stats.expanded+=1
  for j=1,n do
   if not done[j]then
    local d=dist[best]+(points[j]-points[best]).Magnitude
    if d<(dist[j]or math.huge)and open(best,j)then dist[j],prev[j]=d,best end
   end
  end
 end
 if not dist[2]then return nil end
 local reversed,at={},2
 while at~=1 do table.insert(reversed,points[at]);at=prev[at] end
 local targets={};for i=#reversed,1,-1 do table.insert(targets,reversed[i])end
 return targets
end
-- The prop corners of `L` that `keep(node)` takes, the nearest to the walk first, at most MaxNodes; with `parts`, every
-- parts' graph node too.
local function nearest(L,from,to,keep,parts)
 local list,ids={},{}
 for id,node in ipairs(L.nodes)do
  if node.graph then
   if parts then table.insert(ids,id)end
  elseif keep(node)then table.insert(list,{id=id,d=Walk.toSegment(node.p.X,node.p.Z,from.X,from.Z,to.X,to.Z)})end
 end
 table.sort(list,function(a,b)return a.d<b.d or(a.d==b.d and a.id<b.id)end)
 for k=1,math.min(#list,Planner.MaxNodes)do table.insert(ids,list[k].id)end
 return ids
end
function Planner.partNodes(L)return if L.graph then #L.nodes-L.corners else 0 end
-- The waypoints round the keep-outs from `from` to `to` (the last is `to`), or nil. `live`: the circles that count for
-- this pet (its own escape dropped); `circles`: the scene's whole list (the layout's key; nil: live).
function Planner.roundProps(from,to,boxes,live,circles)
 local L=layout(boxes,circles or live)
 Planner.Stats={searches=0,expanded=0,checks=0,nodes=0}
 local counts={}
 for _,c in ipairs(live)do counts[c]=true end
 local tried=0
 for _,width in ipairs(Planner.Corridors)do
  local near,size={},0
  for _,c in ipairs(live)do
   if Walk.toSegment(c.X,c.Z,from.X,from.Z,to.X,to.Z)<c.R+width then near[c]=true;size+=1 end
  end
  if size>tried then
   tried=size
   local targets=search(L,from,to,nearest(L,from,to,function(node)return near[node.circle]==true end,false),live)
   if targets then return targets end
  end
 end
 -- Water or a blocked box in the way too: the props' corners and the parts' own graph round the walk.
 withParts(L)
 return search(L,from,to,nearest(L,from,to,function(node)return counts[node.circle]==true end,true),live)
end
local function propPlan(from,to,velocity,speed,minimum,yaw,via,terminal,boxes,circles)
 -- A pet inside a keep-out walks out of it.
 local live={}
 for _,c in ipairs(circles)do if Walk.toSegment(c.X,c.Z,from.X,from.Z,from.X,from.Z)>=c.R then table.insert(live,c)end end
 local function clear(path)return Walk.pathAllowed(path,boxes)and Walk.pathAllowed(path,live)end
 local direct,duration=A.plan(from,to,velocity,speed,minimum,yaw,via,terminal)
 local dry=Walk.pathAllowed(direct,boxes)
 if dry and Walk.pathAllowed(direct,live)then return direct,duration end
 if not dry then
  -- The parts' own detour (a bridge, round a pond) when it happens to miss every prop.
  local path,total=boxPlan(from,to,velocity,speed,minimum,yaw,via,terminal,boxes)
  local last=path[#path]
  if last and not last.safetyStop and clear(path)then return path,total end
 end
 local targets=Planner.roundProps(from,to,boxes,live,circles)
 if targets then
  local walk,seconds=walkThrough(from,targets,velocity,speed,yaw,clear)
  if #walk>0 and clear(walk)then return walk,seconds end
 end
 local stop,seconds=A.plan(from,from,velocity,speed,.5,yaw)
 if clear(stop)then return stop,seconds end
 local hold,holdSeconds=A.plan(from,from,Vector3.zero,speed,.5,yaw)
 for _,leg in ipairs(hold)do leg.safetyStop=true end
 return hold,holdSeconds
end
function Planner.plan(from,to,velocity,speed,minimum,yaw,via,terminal,wet)
 local boxes,circles=Walk.split(wet)
 if #circles==0 then return boxPlan(from,to,velocity,speed,minimum,yaw,via,terminal,wet)end
 return propPlan(from,to,velocity,speed,minimum,yaw,via,terminal,boxes,circles)
end
return Planner
