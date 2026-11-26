-- Park walk routes (beta (34) QA: "the pet walks thru the slide meshes ... to walk back to the ladder"). Pets are server
-- actors moved along planned paths, never physics, so a toy has no collider for them: every park walk leg is planned
-- round the toys here instead. Pure (no instances, no clock); the server's ParkDirector and ParkFetch plan with it and
-- ParkRoute.spec walks every leg of every site.
--
-- Footprints: one rectangle per toy in its group frame (ParkPoseData's roots and mesh sizes, so the Top Lawn's x1.25
-- toys come out x1.25 too): the swing frame grown to the seats' arcs, the whole slide (ladder, deck and chute), the
-- see-saw's base and beam, the sand box frame, the ball mat. Benches are rectangles too and the dressing's keepout
-- circles (stones, stumps, the log) hexagons round them. A route keeps Margin studs (a pet's half-width) off every toy
-- and bench, DressingMargin off the dressing's circles (already a stone and .4 of air).
--
-- A route starts or ends inside a toy only at that toy's own play spot (a swing's waiting spot, the sand, the ball
-- mat, the ladder foot, the chute's end): it leaves or enters by the nearest point of that toy's edge, so the stretch
-- inside a footprint is the short step to or from the spot. Between, the shortest way round the footprints' corners
-- (a visibility graph, built once per site), kept inside the park.
local A=require(script.Parent.GardenActivity)
local Data=require(script.Parent.ParkPoseData)
local Route={}
Route.Margin=.7      -- studs kept between a pet's centre and a toy or bench (its half-width and a little air)
Route.DressingMargin=.15 -- the dressing's keepout circles already hold .4 of air round each stone
Route.Push=.15       -- graph corners stand this far beyond the margin, so a leg between two corners never grazes it
Route.RimInset=.3    -- corners stay this far inside the park's circle (then 1 stud outside it if nothing else fits)
Route.Near=.05
-- A turn on the spot, as long as the garden planner's.
function Route.turnSeconds(turn)return A.turnSeconds(turn)end

local function v2(p)return Vector2.new(p.X,p.Z)end
-- A rectangle (centre, unit axes, half sizes) as a convex polygon, counter-clockwise in (X, Z), grown by `grow`.
local function rectangle(center,right,forward,halfX,halfZ,grow)
	local hx,hz=halfX+grow,halfZ+grow
	local corners={center+right*hx+forward*hz,center-right*hx+forward*hz,center-right*hx-forward*hz,center+right*hx-forward*hz}
	-- Wind counter-clockwise whatever the frame's handedness in (X, Z).
	local area=0
	for i=1,4 do local a,b=corners[i],corners[i%4+1];area+=a.X*b.Y-b.X*a.Y end
	if area<0 then corners={corners[4],corners[3],corners[2],corners[1]}end
	return corners
end
local function hexagon(center,radius)
	local r=radius/math.cos(math.pi/6)
	local corners={}
	for k=0,5 do local a=k*math.pi/3;table.insert(corners,center+Vector2.new(math.cos(a),math.sin(a))*r)end
	return corners
end
-- Toy rectangles in a group frame: the union of the given local boxes {centre (Vector3), size (Vector3)}.
local function groupRect(root,boxes)
	local lo,hi=Vector2.new(math.huge,math.huge),Vector2.new(-math.huge,-math.huge)
	for _,box in ipairs(boxes)do
		local c,s=box[1],box[2]*.5
		lo=Vector2.new(math.min(lo.X,c.X-s.X),math.min(lo.Y,c.Z-s.Z))
		hi=Vector2.new(math.max(hi.X,c.X+s.X),math.max(hi.Y,c.Z+s.Z))
	end
	local mid=(lo+hi)*.5
	local center=root:PointToWorldSpace(Vector3.new(mid.X,0,mid.Y))
	local right,look=root.RightVector,-root.LookVector -- group +X and +Z on the ground (LookVector is -Z)
	return {center=v2(center),right=Vector2.new(right.X,right.Z).Unit,forward=Vector2.new(look.X,look.Z).Unit,half=(hi-lo)*.5}
end
-- A mesh's box in its group frame (Data.frame without the root).
local function meshBox(D,name,motion)
	local m=D.Meshes[name]
	local frame=CFrame.new(m.offset)*(motion or CFrame.identity)*CFrame.new(-m.pivot)
	return {frame.Position,m.size}
end

local cache=setmetatable({},{__mode="k"})
-- The site's footprints: {id, kind ("toy" | "bench" | "dressing"), equipment?, rect?, poly (raw), grown (+ Margin)}.
function Route.footprints(site)
	local built=cache[site]
	if built then return built.footprints end
	local D=Data.forSite(site)
	local R=D.Roots
	local K=site.ToyScale or 1
	local list={}
	local function toy(equipment,root,boxes)
		local rect=groupRect(root,boxes)
		table.insert(list,{id=equipment,kind="toy",equipment=equipment,rect=rect,
			poly=rectangle(rect.center,rect.right,rect.forward,rect.half.X,rect.half.Y,0),
			grown=rectangle(rect.center,rect.right,rect.forward,rect.half.X,rect.half.Y,Route.Margin)})
	end
	-- The swing frame, grown along the group's Z to the seats' arcs (the plain swing's: riders wait 1.25 in front).
	do
		local frame=meshBox(D,"Park_SwingFrame")
		local reach=0
		for _,id in ipairs({"swing1","swing2"})do
			local slot=site.Slots[id]
			reach=math.max(reach,slot.rope*math.sin(slot.amplitude or .5)+D.Meshes.Park_SwingA.size.Z*.5)
		end
		toy("swing",R.SwingSet,{frame,{Vector3.new(frame[1].X,0,0),Vector3.new(frame[2].X,1,reach*2)}})
	end
	toy("slide",R.Slide,{meshBox(D,"Park_Slide")})
	do
		local pivot=R.SeeSaw:ToObjectSpace(D.SeeSaw.pivot).Position
		toy("seesaw",R.SeeSaw,{meshBox(D,"Park_SeeSawBase"),{pivot,D.Meshes.Park_SeeSawBeam.size}})
	end
	toy("sandbox",R.Sandbox,{meshBox(D,"Park_SandboxFrame")})
	toy("ball",R.BallCorner,{meshBox(D,"Park_BallMat")})
	for _,bench in ipairs(site.Benches)do
		local root=site.cframe(bench.position,bench.yaw)
		local rect=groupRect(root,{{Vector3.zero,Vector3.new(bench.length or D.Meshes.Park_Bench.size.X,1,D.Meshes.Park_Bench.size.Z)}})
		table.insert(list,{id="bench:"..bench.id,kind="bench",rect=rect,
			poly=rectangle(rect.center,rect.right,rect.forward,rect.half.X,rect.half.Y,0),
			grown=rectangle(rect.center,rect.right,rect.forward,rect.half.X,rect.half.Y,Route.Margin)})
	end
	for index,zone in ipairs(site.Keepout)do
		if zone.dressing then
			table.insert(list,{id="dressing:"..index,kind="dressing",poly=hexagon(zone.center,zone.radius),
				grown=hexagon(zone.center,zone.radius+Route.DressingMargin)})
		end
	end
	-- A bounding circle round each grown footprint: most tests reject on it alone.
	for _,f in ipairs(list)do
		local centre=Vector2.zero
		for _,p in ipairs(f.grown)do centre+=p end
		centre/=#f.grown
		local radius=0
		for _,p in ipairs(f.grown)do radius=math.max(radius,(p-centre).Magnitude)end
		f.centre,f.reach=centre,radius+1e-4
	end
	cache[site]={footprints=list,K=K}
	return list
end

-- Whether a ground point (X, Z) lies inside a convex counter-clockwise polygon, `inset` studs in from its edges.
local function inside(poly,p,inset)
	inset=inset or 0
	for i=1,#poly do
		local a,b=poly[i],poly[i%#poly+1]
		local edge=b-a
		local cross=edge.X*(p.Y-a.Y)-edge.Y*(p.X-a.X)
		if cross<=inset*edge.Magnitude then return false end
	end
	return true
end
Route.insidePoly=inside
-- The footprints a point stands in (raw, or grown by the margin).
function Route.at(site,position,grown)
	local p=if typeof(position)=="Vector2"then position else v2(position)
	local hits={}
	for _,f in ipairs(Route.footprints(site))do
		if(p-f.centre).Magnitude<f.reach and inside(if grown then f.grown else f.poly,p,1e-6)then table.insert(hits,f)end
	end
	return hits
end
-- Whether the segment a-b passes through a polygon's interior (Cyrus-Beck; touching an edge or a corner does not).
local function crosses(poly,a,b)
	local enter,leave=0,1
	local d=b-a
	for i=1,#poly do
		local p,q=poly[i],poly[i%#poly+1]
		local edge=q-p
		local normal=Vector2.new(edge.Y,-edge.X) -- outward for a counter-clockwise polygon
		local numerator=normal:Dot(a-p)
		local denominator=normal:Dot(d)
		if math.abs(denominator)<1e-12 then
			if numerator>=-1e-9 then return false end
		else
			local t=-numerator/denominator
			if denominator<0 then enter=math.max(enter,t)else leave=math.min(leave,t)end
			if enter>leave then return false end
		end
	end
	return(leave-enter)*d.Magnitude>1e-4
end
Route.crosses=crosses
-- The share of a-b inside a convex polygon: enter, leave (0..1), or nil when it misses.
local function span(poly,a,b)
	local enter,leave=0,1
	local d=b-a
	for i=1,#poly do
		local p,q=poly[i],poly[i%#poly+1]
		local edge=q-p
		local normal=Vector2.new(edge.Y,-edge.X)
		local numerator=normal:Dot(a-p)
		local denominator=normal:Dot(d)
		if math.abs(denominator)<1e-12 then
			if numerator>=0 then return nil end
		else
			local t=-numerator/denominator
			if denominator<0 then enter=math.max(enter,t)else leave=math.min(leave,t)end
			if enter>leave then return nil end
		end
	end
	return enter,leave
end
-- Distance from a point to the segment a-b.
local function gap(p,a,b)
	local d=b-a
	local t=if d:Dot(d)>1e-12 then math.clamp((p-a):Dot(d)/d:Dot(d),0,1)else 0
	return(a+d*t-p).Magnitude
end
local function clear(list,a,b,skip)
	for _,f in ipairs(list)do
		if f~=skip and gap(f.centre,a,b)<f.reach and crosses(f.grown,a,b)then return false end
	end
	return true
end
-- Whether the straight walk a -> b keeps the margin off every footprint (the grown ones).
function Route.segmentClear(site,a,b)return clear(Route.footprints(site),v2(a),v2(b))end

-- The visibility graph of one site: the grown footprints' corners pushed out by Push, kept off every other footprint
-- and inside the park (strictly: RimInset in; loose: 1 stud outside the circle as well).
local function graph(site,loose)
	local built=cache[site]or(Route.footprints(site)and cache[site])
	local key=if loose then "loose"else "strict"
	if built[key]then return built[key]end
	local list=built.footprints
	local nodes={}
	for _,f in ipairs(list)do
		local poly=f.grown
		local centre=Vector2.zero
		for _,p in ipairs(poly)do centre+=p end
		centre/=#poly
		for _,p in ipairs(poly)do
			local out=p-centre
			local node=p+out.Unit*Route.Push
			local ok=site.inside(Vector3.new(node.X,0,node.Y),if loose then 1 else -Route.RimInset)
			if ok then for _,g in ipairs(list)do if inside(g.grown,node,0)then ok=false;break end end end
			if ok then table.insert(nodes,node)end
		end
	end
	local visible={}
	for i=1,#nodes do visible[i]={}end
	for i=1,#nodes do for j=i+1,#nodes do
		if clear(list,nodes[i],nodes[j])then visible[i][j]=true;visible[j][i]=true end
	end end
	built[key]={nodes=nodes,visible=visible}
	return built[key]
end
-- Build a site's footprints and both graphs now (review B35: the director does it when it is made, so no walk pays tens
-- of ms for them in one server frame). Returns whether they were built by this call.
function Route.prepare(site)
	local fresh=not(cache[site]and cache[site].strict and cache[site].loose)
	Route.footprints(site);graph(site,false);graph(site,true)
	return fresh
end
function Route.prepared(site)return cache[site]~=nil and cache[site].strict~=nil and cache[site].loose~=nil end

-- The nearest point off every grown footprint for a point inside some: on the edges of the ones it stands in (pushed
-- out by Push), else a graph corner. nil when none is clear.
local function release(site,p,list,hits)
	local candidates={}
	for _,f in ipairs(hits)do
		local poly=f.grown
		for i=1,#poly do
			local a,b=poly[i],poly[i%#poly+1]
			local edge=b-a
			local t=math.clamp((p-a):Dot(edge)/edge:Dot(edge),0,1)
			local foot=a+edge*t
			local normal=Vector2.new(edge.Y,-edge.X).Unit
			table.insert(candidates,foot+normal*Route.Push)
		end
	end
	table.sort(candidates,function(x,y)return(x-p).Magnitude<(y-p).Magnitude end)
	for _,c in ipairs(candidates)do
		local ok=site.inside(Vector3.new(c.X,0,c.Y),1)
		if ok then for _,g in ipairs(list)do if inside(g.grown,c,0)then ok=false;break end end end
		if ok then return c end
	end
	return nil
end

local function dijkstra(G,list,from,to)
	local nodes,visible=G.nodes,G.visible
	local n=#nodes
	local S,T=n+1,n+2
	local points=table.clone(nodes);points[S],points[T]=from,to
	local fromEdges={}
	for i=1,n do if clear(list,from,nodes[i])then fromEdges[i]=true end end
	-- A*: the straight distance to `to` as the estimate; a corner's line to `to` is tested only once it is reached.
	local dist,prev,done={[S]=0},{},{}
	while true do
		local best,bestScore=nil,math.huge
		for i,d in pairs(dist)do
			if not done[i]then
				local score=d+(to-points[i]).Magnitude
				if score<bestScore then best,bestScore=i,score end
			end
		end
		if not best or best==T then break end
		done[best]=true
		local bestDist=dist[best]
		local around=if best==S then fromEdges else visible[best]
		for j in pairs(around)do
			local d=bestDist+(points[j]-points[best]).Magnitude
			if not done[j]and d<(dist[j]or math.huge)then dist[j],prev[j]=d,best end
		end
		if best~=S and clear(list,points[best],to)then
			local d=bestDist+(to-points[best]).Magnitude
			if d<(dist[T]or math.huge)then dist[T],prev[T]=d,best end
		end
	end
	if not dist[T]then return nil end
	local reversed,at={},T
	while at~=S do table.insert(reversed,points[at]);at=prev[at]end
	local out={}
	for i=#reversed,1,-1 do table.insert(out,reversed[i])end
	return out
end

-- The ground waypoints from `from` to `to` (Vector3s; the last is `to` itself, `from` is not included), or nil when no
-- way round fits (the caller falls back to its straight walk). Second value: where the walk may stand in a footprint
-- ({from = {footprints, reach}, to = {footprints, reach}}: the ones each end stands in, and how far from that end).
function Route.waypoints(site,from,to)
	local list=Route.footprints(site)
	local a,b=v2(from),v2(to)
	local points={}
	local startHits,endHits=Route.at(site,a,true),Route.at(site,b,true)
	local start,finish=a,b
	if #startHits>0 then start=release(site,a,list,startHits);if not start then return nil end end
	if #endHits>0 then finish=release(site,b,list,endHits);if not finish then return nil end end
	if start~=a then table.insert(points,start)end
	if not clear(list,start,finish)then
		local middle=dijkstra(graph(site,false),list,start,finish)or dijkstra(graph(site,true),list,start,finish)
		if not middle then return nil end
		table.remove(middle) -- `finish` itself
		for _,p in ipairs(middle)do table.insert(points,p)end
	end
	if finish~=b then table.insert(points,finish)end
	-- Fewer legs (the snapshot carries each one): skip a release point when the straight line from the end itself to the
	-- next point leaves (or enters) its footprints no further from that end than the release point is.
	local function within(p,q,hits,reach,fromStart)
		for _,f in ipairs(list)do
			if gap(f.centre,p,q)<f.reach and crosses(f.grown,p,q)then
				if not table.find(hits,f)then return false end
				local t0,t1=span(f.grown,p,q)
				local length=(q-p).Magnitude
				if(if fromStart then t1*length else(1-t0)*length)>reach+1e-6 then return false end
			end
		end
		return true
	end
	if start~=a and #points>=2 and within(a,points[2],startHits,(start-a).Magnitude,true)then table.remove(points,1)end
	if finish~=b and #points>=2 and within(points[#points-1],b,endHits,(finish-b).Magnitude,false)then table.remove(points)
	elseif finish~=b and #points==1 and start==a and within(a,b,endHits,(finish-b).Magnitude,false)then table.remove(points)end
	local out={}
	local last=a
	for _,p in ipairs(points)do
		if(p-last).Magnitude>Route.Near and(p-b).Magnitude>Route.Near then
			table.insert(out,Vector3.new(p.X,site.ground(p.X,p.Y),p.Y));last=p
		end
	end
	table.insert(out,to)
	return out,{from={hits=startHits,reach=(start-a).Magnitude+.3},to={hits=endHits,reach=(finish-b).Magnitude+.3}}
end

-- Whether a leg keeps off every grown footprint (sampled along its curve), but for the stretch by an end standing in one.
local function legClear(site,leg,first,lastLeg,from,to,ends)
	local list=Route.footprints(site)
	-- The leg's curve in the ground plane (GardenActivity's cubic, unpacked once).
	local a=Vector2.new(leg.from[1],leg.from[3])
	local delta=Vector2.new(leg.to[1],leg.to[3])-a
	local d=leg.duration
	local w0,w1=Vector2.new(leg.v0[1],leg.v0[3])*d,Vector2.new(leg.v1[1],leg.v1[3])*d
	for k=1,12 do
		local t=k/12;local u=1-t
		local p=a+w0*(u*u*t)+(delta-w1/3)*(3*u*t*t)+delta*(t*t*t)
		for _,f in ipairs(list)do
			if(p-f.centre).Magnitude<f.reach and inside(f.grown,p,1e-6)then
				local ok=false
				if first and ends and table.find(ends.from.hits,f)and(p-v2(from)).Magnitude<=ends.from.reach then ok=true end
				if not ok and lastLeg and ends and table.find(ends.to.hits,f)and(p-v2(to)).Magnitude<=ends.to.reach then ok=true end
				if not ok then return false end
			end
		end
	end
	return true
end

-- A walk along waypoints: one smooth curve through the corners (GardenActivity.through) whose every leg keeps off the
-- footprints, else from rest at each corner (the bounded planner per stretch; the incoming velocity brakes in the first
-- one). Returns path, seconds.
function Route.build(site,from,points,velocity,speed,yaw,ends)
	local to=points[#points]
	-- A clear straight walk is the plain planner's, exactly as before.
	if #points==1 then return A.plan(from,to,velocity or Vector3.zero,speed,0,yaw or 0,nil,Vector3.zero)end
	local path,total=A.through(from,points,velocity,speed,yaw,function(leg,index,count)
		return legClear(site,leg,index==1,index==count,from,to,ends)
	end)
	if path then return path,total end
	path,total={},0
	local position,v,heading=from,velocity or Vector3.zero,yaw or 0
	for _,target in ipairs(points)do
		if(target-position).Magnitude<1e-4 then continue end
		local part,seconds=A.plan(position,target,v,speed,0,heading)
		for _,leg in ipairs(part)do table.insert(path,leg)end
		total+=seconds
		local last=part[#part]
		local tail,_,facing=A.legPose(last,last.duration)
		heading,position,v=facing,tail,Vector3.zero
	end
	return path,total
end
-- The heading a path ends on.
local function endYawOf(path,yaw)
	local last=path[#path]
	if not last then return yaw end
	local _,_,facing=A.legPose(last,last.duration)
	return facing
end
Route.endYaw=endYawOf

-- The routed walk from -> to: path, seconds, routed (false: no way round fitted, the straight walk instead).
function Route.plan(site,from,to,velocity,speed,yaw)
	local points,ends=Route.waypoints(site,from,to)
	if not points then
		local path,seconds=A.plan(from,to,velocity or Vector3.zero,speed,0,yaw or 0,nil,Vector3.zero)
		return path,seconds,false
	end
	local path,seconds=Route.build(site,from,points,velocity,speed,yaw,ends)
	return path,seconds,true
end

-- The same walk fitted into `duration` seconds (a play phase): faster when it must be (never under `speed`), then, with
-- `endYaw`, a turn on the spot to it, and a hold for whatever time is left. Returns path, seconds (= duration unless
-- even the cap cannot fit), routed.
function Route.timed(site,from,to,speed,duration,yaw,cap,endYaw)
	local points,ends=Route.waypoints(site,from,to)
	local routed=points~=nil
	points=points or {to}
	local pace=speed
	local path,total
	for _=1,12 do
		path,total=Route.build(site,from,points,Vector3.zero,pace,yaw,ends)
		-- Leave room for the turn to the ladder at the end.
		local turn=if endYaw then math.abs(math.atan2(math.sin(endYaw-endYawOf(path,yaw)),math.cos(endYaw-endYawOf(path,yaw))))else 0
		local need=total+(if turn>=.05 then Route.turnSeconds(turn)else 0)
		if need<=duration+1e-6 or pace>=(cap or math.huge)then break end
		pace=math.min(cap or math.huge,pace*math.max(1.05,need/duration*1.02))
	end
	local left=duration-total
	local last=path[#path]
	local stop=if last then A.vector(last.to)else from
	local facing=endYawOf(path,yaw)
	if endYaw and left>.05 then
		local turn=math.atan2(math.sin(endYaw-facing),math.cos(endYaw-facing))
		if math.abs(turn)>=.05 then
			local seconds=math.min(left,Route.turnSeconds(turn))
			table.insert(path,{from=A.pack(stop),to=A.pack(stop),v0={0,0,0},v1={0,0,0},duration=seconds,yaw=facing,turn=turn,turnDuration=seconds,pivot=true})
			left-=seconds;total+=seconds;facing=facing+turn
		end
	end
	if left>1e-4 then
		local hold=assert(A.leg(stop,stop,Vector3.zero,Vector3.zero,speed,left,facing))
		hold.duration=left;table.insert(path,hold);total=duration
	end
	return path,total,routed
end

return table.freeze(Route)
