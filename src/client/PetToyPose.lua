-- Analytic hand beats from authoritative exchange time. No clock, path or reservation ownership.
local Pose={}
local function pulse(time,center,width)
 local u=math.clamp(1-math.abs(time-center)/width,0,1);return u*u*(3-2*u)
end
function Pose.sample(role,time,reduced)
 if type(time)~="number"or time~=time then return 0,nil end
 local push,catch=0,0
 if role=="starter"then push=pulse(time,.5,.32);catch=pulse(time,4.5,.30)
 elseif role=="receiver"then push=pulse(time,2.8,.27);catch=pulse(time,2.25,.30)end
 local expression=if catch>.35 then "pleased"elseif push>.35 then "curious"else nil
 return if reduced then 0 else math.max(push,catch*.85),expression
end
return Pose
