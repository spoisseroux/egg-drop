-- Read-only Studio probes P6 and P7 for the Dash pad's move to (64.5, -21) and its rope ring (beta 14 F2;
-- NEST-AND-RACE-LINE-BUILD-PLAN 4 and 6). Run through Studio MCP execute_luau in Edit mode on the beta place (Dash on,
-- so the GardenDash model is built). It changes nothing and saves nothing.
--   P6 the ring: 32 rays out from the pad's middle at .5, 1.5 and 2.5 studs up, to R + .5, and a ray down at every stake:
--      nothing hit, every stake on the lawn within .3 of the pad's height (the merged world mesh hides rocks and roots
--      the walk map blurs).
--   P7 the beta 12 camera line (build_dash_course.py's note): after Done the camera looks west along the course from
--      behind the avatar on the pad. The north start post stood 2.6 studs across that line at (67, -17) and 6.6 at
--      (66, -21). Here: the post's distance from the eye-to-avatar line, for an eye 12 studs east and 4 up (looking
--      west) and one 12 south and 4 up (looking north), with a ray from each eye. PASS = 5 or more, nothing hit first.
--      Then capture the Done shot in Play (avatar on the pad) for Fable.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Course=require(Shared:WaitForChild("DashCourse"))
local Ring=require(Shared:WaitForChild("DashRing"))
local Grid=require(Shared:WaitForChild("DashGrid"))
local params=RaycastParams.new()
params.FilterType=Enum.RaycastFilterType.Exclude
local skip={}
for _,name in ipairs({"GardenDash","EggDropDashLine"})do local f=workspace:FindFirstChild(name,true);if f then table.insert(skip,f)end end
params.FilterDescendantsInstances=skip
local centre=Ring.centre()
local out={}
local function say(fmt,...)table.insert(out,string.format(fmt,...))end
say("pad (%.2f, %.2f, %.2f), ring R %.1f",centre.X,centre.Y,centre.Z,Ring.Radius)
-- P6
local hits={}
for _,h in ipairs({.5,1.5,2.5})do
	for k=0,31 do
		local a=k/32*math.pi*2
		local hit=workspace:Raycast(centre+Vector3.new(0,h,0),Vector3.new(math.cos(a),0,math.sin(a))*(Ring.Radius+.5),params)
		if hit then table.insert(hits,string.format("%.1f up, %d deg: %s at %.2f",h,math.floor(k*360/32),hit.Instance:GetFullName(),hit.Distance))end
	end
end
say("P6 ring rays: %s%s",#hits==0 and "PASS"or "FAIL\n  ",table.concat(hits,"\n  "))
for k=1,Ring.Stakes do
	local _,foot=Ring.stake(k,centre)
	local hit=workspace:Raycast(foot+Vector3.new(0,6,0),Vector3.new(0,-12,0),params)
	local y=hit and hit.Position.Y
	if not y or math.abs(y-centre.Y)>.3 then say("P6 stake %d FAIL: %s",k,hit and(hit.Instance:GetFullName()..string.format(" y %.2f",y))or "no ground")end
end
-- P7
local x,y,z,yaw=Course.at(0,false,1)
local start=CFrame.new(x,y,z)*CFrame.Angles(0,yaw,0)
local post=(start*CFrame.new(-Grid.PostOut/100,0,0)).Position -- one post; the other is mirrored
local post2=(start*CFrame.new(Grid.PostOut/100,0,0)).Position
local avatar=centre+Vector3.new(0,2.5,0)
for _,eye in ipairs({{"east",avatar+Vector3.new(12,4,0)},{"south",avatar+Vector3.new(0,4,12)}})do
	for _,p in ipairs({post,post2})do
		local a,b=eye[2],avatar
		local ab=b-a
		local t=math.clamp((p-a):Dot(ab)/ab:Dot(ab),0,1)
		local across=(Vector3.new(p.X,0,p.Z)-Vector3.new(a.X+ab.X*t,0,a.Z+ab.Z*t)).Magnitude
		say("P7 eye %s, post (%.1f, %.1f): %.1f studs off the line %s",eye[1],p.X,p.Z,across,across>=5 and "PASS"or "FAIL")
	end
	local hit=workspace:Raycast(eye[2],avatar-eye[2],params)
	say("P7 eye %s to the avatar: %s",eye[1],hit and("FAIL, "..hit.Instance:GetFullName())or "PASS")
end
print(table.concat(out,"\n"))
