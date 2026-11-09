-- Pure support/path math against detached geometry; no world/profile mutation.
return function(shared)
 local W=require(shared.GardenWalkability);local P=require(shared.GardenPathPlanner);local A=require(shared.GardenActivity)
 local world=require(shared.HollowWorldLayout);local cases={};local function test(name,f)f();table.insert(cases,name)end
 local holder=Instance.new("Folder");local wet={}
 for _,bend in ipairs({{16.9,-16,5.6,9.6,-16},{17.8,-10,6.7,10.5,-9},{18.65,-3.6,6.35,10.8,3},{18.05,3.3,6.75,10.6,11},{16.9,9.8,6.2,10.4,8},{16.55,15,5.95,8.3,1}})do
  local part=Instance.new("Part");part.Size=Vector3.new(bend[3],.09,bend[4]);part.CFrame=CFrame.new(bend[1],4.038,bend[2])*CFrame.Angles(0,math.rad(bend[5]),0);part.Parent=holder;table.insert(wet,part)
 end
 local ok,problem=pcall(function()
  test("registered bridge gives4.5usable studs and an exact support top",function()
   local span,id=W.spanAt(Vector3.new(17.6,4.38,-9.4));assert(id=="PrimaryBridge"and span.size.Z==4.5 and math.abs(W.top(span)-4.38)<1e-6)
   assert(W.spanAt(Vector3.new(17.6,4.38,-6))==nil)
  end)
  test("open creek or bridge underside is never admitted as a crossing",function()
   assert(not W.segmentAllowed(Vector3.new(8,4.025,0),Vector3.new(27,4.025,0),wet))
   assert(not W.segmentAllowed(Vector3.new(12.9,3,-9.4),Vector3.new(22.3,3,-9.4),wet))
   assert(W.segmentAllowed(Vector3.new(12.9,4.38,-9.4),Vector3.new(22.3,4.38,-9.4),wet))
  end)
  test("both authored crossing directions reach their endpoint with safe full control hull",function()
   for _,points in ipairs({{Vector3.new(0,4.025,-9.4),Vector3.new(30,4.025,-9.4)},{Vector3.new(30,4.025,-9.4),Vector3.new(0,4.025,-9.4)}})do
    local path,seconds=P.plan(points[1],points[2],Vector3.zero,4,0,0,nil,Vector3.zero,wet)
    assert(W.pathAllowed(path,wet),"bridge hull unsafe")
    local actor={from=A.pack(points[1]),to=A.pack(points[2]),path=path,startTime=0,endTime=seconds,yaw=0}
    assert((A.sample(actor,seconds).position-points[2]).Magnitude<1e-5,"crossing never reached destination")
    local highest=0;for i=0,100 do highest=math.max(highest,A.sample(actor,seconds*i/100).position.Y)end
    assert(highest>=4.379 and highest<4.39)
   end
  end)
  test("control hull excursions reject even when the chord endpoints are supported",function()
   local from,to=Vector3.new(14,4.38,-9.4),Vector3.new(21,4.38,-9.4)
   local leg={from=A.pack(from),to=A.pack(to),v0={0,0,30},v1={0,0,-30},duration=2}
   assert(not W.pathAllowed({leg},wet))
  end)
  test("dry existing movement retains its exact planner path and continuous entry velocity",function()
   local from,to,velocity=Vector3.new(-10,4.025,0),Vector3.new(5,4.025,0),Vector3.new(2,0,0)
   local path,seconds=P.plan(from,to,velocity,9,0,math.pi/2,nil,Vector3.new(4,0,0),wet)
   local original,duration=A.plan(from,to,velocity,9,0,math.pi/2,nil,Vector3.new(4,0,0))
   assert(seconds==duration and #path==#original and W.pathAllowed(path,wet))
   assert((Vector3.new(table.unpack(path[1].v0))-velocity).Magnitude<1e-9)
  end)
  test("bridge landing and nook support do not admit a nearby unregistered strip",function()
   local nook=world.WalkableSpans.RestNook;assert(W.spanAt(nook.center)==nook)
   assert(not W.segmentAllowed(Vector3.new(12.9,4.38,-6.95),Vector3.new(22.3,4.38,-6.95),wet))
  end)
  test("inward near-bank velocity cannot escape the safety stop into unsupported water",function()
   local edge
   for x=10,17,.01 do local p=Vector3.new(x,4.025,0);if not W.segmentAllowed(p,p,wet)then edge=x;break end end
   assert(edge);local from=Vector3.new(edge-.02,4.025,0)
   local path,seconds=P.plan(from,from+Vector3.new(18,0,0),Vector3.new(18,0,0),18,0,math.pi/2,nil,Vector3.zero,wet)
   assert(path[1].safetyStop and W.pathAllowed(path,wet))
   local actor={from=A.pack(from),to=A.pack(from),path=path,startTime=0,endTime=seconds,yaw=0}
   for i=0,20 do assert((A.sample(actor,seconds*i/20).position-from).Magnitude<1e-8)end
  end)
  test("a rotated wet patch contained wholly inside a convex control hull rejects",function()
   local water=Instance.new("Part");water.Size=Vector3.new(.3,.1,.3);water.CFrame=CFrame.new(-4,4,2)*CFrame.Angles(0,.4,0);water.Parent=holder
   local leg={from={-8,4.025,-4},to={0,4.025,-4},v0={0,0,12},v1={0,0,-12},duration=2}
   local corners={Vector3.new(-8,4.025,-4),Vector3.new(-8,4.025,4),Vector3.new(0,4.025,4),Vector3.new(0,4.025,-4)}
   for i=1,4 do for j=i,4 do assert(W.segmentAllowed(corners[i],corners[j],{water}),"fixture must expose contained water missed by hull chords")end end
   assert(not W.pathAllowed({leg},{water}));water:Destroy()
  end)
  test("actual dry lateral endpoint still completes the full supported bridge exit",function()
   local from=Vector3.new(11.4395,4.025,-8.8929)
   local raw=Vector3.new(22.22798,4.025,-6.73222)
   assert(W.segmentAllowed(raw,raw,wet),"reported endpoint itself is dry; its direct route is unsafe")
   local goal,clamped=W.resolveAnchor(raw,wet)
   assert(not clamped and goal==raw)
   local path,seconds=P.plan(from,goal,Vector3.zero,4,0,math.pi/2,nil,Vector3.zero,wet)
   assert(W.pathAllowed(path,wet)and not path[1].safetyStop)
   local pose=A.sample({from=A.pack(from),to=A.pack(goal),path=path,startTime=0,endTime=seconds,yaw=0},seconds)
   assert((pose.position-goal).Magnitude<1e-6,"projected endpoint remained unreachable")
  end)
  test("a genuinely wet lateral follow goal projects onto the nearby deck",function()
   local raw=Vector3.new(17.6,4.025,-6.73222);assert(not W.segmentAllowed(raw,raw,wet))
   local goal,clamped=W.resolveAnchor(raw,wet)
   assert(clamped and goal and math.abs(goal.Y-4.38)<1e-6 and W.segmentAllowed(goal,goal,wet))
  end)
  test("far unsupported creek goals are not projected across the garden",function()
   assert(W.resolveAnchor(Vector3.new(18,4.025,3),wet)==nil)
  end)
 end)
 holder:Destroy();assert(ok,problem);return{passed=#cases,cases=cases}
end
