-- Explicit authored supports, never inferred from a water/rock ray hit.
-- The 'wet' list also carries GardenBlockedRegion footprints (terraces, ramps,
-- pillars): pets never cross those, even on a span.
local World=require(script.Parent.HollowWorldLayout)
local Walk={}
function Walk.spanAt(position,inset)
 inset=inset or .15
 for id,span in pairs(World.WalkableSpans)do
  if math.abs(position.X-span.center.X)<=span.size.X*.5-inset and math.abs(position.Z-span.center.Z)<=span.size.Z*.5-inset then return span,id end
 end
 return nil
end
function Walk.top(span)return span.center.Y+span.size.Y*.5+.025 end
local function interval(a,b,minimum,maximum,lo,hi)
 local delta=b-a
 if math.abs(delta)<1e-8 then if a<minimum or a>maximum then return nil end;return lo,hi end
 local x,y=(minimum-a)/delta,(maximum-a)/delta;if x>y then x,y=y,x end
 lo,hi=math.max(lo,x),math.min(hi,y);if lo>hi then return nil end;return lo,hi
end
function Walk.segmentAllowed(from,to,wet)
 for _,water in ipairs(wet)do
  if not water.Parent then continue end
  local a,b=water.CFrame:PointToObjectSpace(from),water.CFrame:PointToObjectSpace(to)
  local lo,hi=interval(a.X,b.X,-water.Size.X*.5-.35,water.Size.X*.5+.35,0,1)
  if lo then lo,hi=interval(a.Z,b.Z,-water.Size.Z*.5-.35,water.Size.Z*.5+.35,lo,hi)end
  if lo and water:GetAttribute("GardenBlockedRegion")==true then return false end
  if lo then
   local enter,leave=from:Lerp(to,lo),from:Lerp(to,hi)
   local span,id=Walk.spanAt(enter)
   local other,otherId=Walk.spanAt(leave)
   if not span or not other or id~=otherId or math.min(enter.Y,leave.Y)<Walk.top(span)-.05 then return false end
  end
 end
 return true
end
function Walk.resolveAnchor(position,wet)
 local span=Walk.spanAt(position)
 if span then
  local supported=Vector3.new(position.X,Walk.top(span),position.Z)
  if Walk.segmentAllowed(supported,supported,wet)then return supported,(supported-position).Magnitude>.001 end
 end
 if Walk.segmentAllowed(position,position,wet)then return position,false end
 local best,distance
 -- The ordinary lateral follow offset may fall beside a narrow deck. Project
 -- that goal onto a nearby registered support; never project the moving root.
 for _,candidate in pairs(World.WalkableSpans)do
  local x=math.clamp(position.X,candidate.center.X-candidate.size.X*.5+.30,candidate.center.X+candidate.size.X*.5-.30)
  local z=math.clamp(position.Z,candidate.center.Z-candidate.size.Z*.5+.30,candidate.center.Z+candidate.size.Z*.5-.30)
  local point=Vector3.new(x,Walk.top(candidate),z)
  local gap=Vector2.new(x-position.X,z-position.Z).Magnitude
  if gap<=3.25 and(not distance or gap<distance)and Walk.segmentAllowed(point,point,wet)then best,distance=point,gap end
 end
 return best,best~=nil
end
function Walk.pathAllowed(path,wet)
 for _,leg in ipairs(path)do
  local from,to=Vector3.new(table.unpack(leg.from)),Vector3.new(table.unpack(leg.to))
  local v0,v1=Vector3.new(table.unpack(leg.v0)),Vector3.new(table.unpack(leg.v1))
  local points={from,from+v0*leg.duration/3,to-v1*leg.duration/3,to}
  -- Every edge/diagonal of the Bézier hull must stay dry or on one support.
  for i=1,4 do for j=i,4 do if not Walk.segmentAllowed(points[i],points[j],wet)then return false end end end
  -- Chords alone miss a small wet rectangle enclosed by a noncollinear hull.
  local sorted=table.clone(points);table.sort(sorted,function(a,b)return a.X<b.X or(a.X==b.X and a.Z<b.Z)end)
  local function cross(a,b,c)return(b.X-a.X)*(c.Z-a.Z)-(b.Z-a.Z)*(c.X-a.X)end
  local lower,upper={},{}
  for _,p in ipairs(sorted)do while #lower>=2 and cross(lower[#lower-1],lower[#lower],p)<=1e-9 do table.remove(lower)end;table.insert(lower,p)end
  for i=#sorted,1,-1 do local p=sorted[i];while #upper>=2 and cross(upper[#upper-1],upper[#upper],p)<=1e-9 do table.remove(upper)end;table.insert(upper,p)end
  table.remove(lower);table.remove(upper);local hull=lower;for _,p in ipairs(upper)do table.insert(hull,p)end
  if #hull>=3 then
   local minimumY=math.min(points[1].Y,points[2].Y,points[3].Y,points[4].Y)
   for _,water in ipairs(wet)do if water.Parent then
    for _,x in ipairs({-1,1})do for _,z in ipairs({-1,1})do
     local corner=water.CFrame:PointToWorldSpace(Vector3.new(x*(water.Size.X*.5+.35),0,z*(water.Size.Z*.5+.35)))
     corner=Vector3.new(corner.X,minimumY,corner.Z)
     local inside=true;for i=1,#hull do if cross(hull[i],hull[i%#hull+1],corner)<-1e-8 then inside=false;break end end
     if inside and not Walk.segmentAllowed(corner,corner,{water})then return false end
    end end
   end end
  end
 end
 return true
end
return Walk
