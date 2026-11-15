-- The visitor hello (QA v685 R6): the pet glances at whoever said hello and waves.
-- Glance 0.25 s, two waves over 0.8 s, back to idle in 0.25 s, all on server time so
-- every observer sees the same wave. Reduced Motion keeps the glance and one small wave.
-- The owner always wins: no wave while the pet is focused, petted, carried, cared for,
-- playing with a toy or walking.
--
-- The accepted hello rides on the owner's board (PetHelloRules.Attribute) as JSON
-- {id, from, at, petId, petGeneration}. Hello.read(board) decodes it once per change and
-- drops one that names another pet or an older pet generation.
local Players=game:GetService("Players")
local Http=game:GetService("HttpService")
local Rules=require(game:GetService("ReplicatedStorage").Shared.PetHelloRules)
local Hello={}
Hello.MaxYaw=math.rad(50)
local cache=setmetatable({},{__mode="k"})

function Hello.read(board)
 if not board then return nil end
 local raw=board:GetAttribute(Rules.Attribute)
 if type(raw)~="string"then return nil end
 local cached=cache[board]
 if not cached or cached.raw~=raw then
  local ok,value=pcall(Http.JSONDecode,Http,raw)
  local valid=ok and type(value)=="table"and type(value.id)=="number"and type(value.from)=="number"and type(value.at)=="number"
   and type(value.petId)=="string"and type(value.petGeneration)=="number"
  cached={raw=raw,value=if valid then value else nil}
  cache[board]=cached
 end
 local hello=cached.value
 if not hello or hello.petId~=board:GetAttribute("CompanionId")or hello.petGeneration~=board:GetAttribute("CompanionGeneration")then return nil end
 return hello
end

-- Pure: head yaw weight 0..1 and right-hand fold for a hello `age` seconds old.
function Hello.curve(age,reduced)
 if type(age)~="number"or age<0 or age>=Rules.Duration then return 0,0 end
 local glance=math.min(1,age/Rules.GlanceIn,(Rules.Duration-age)/Rules.GlanceOut)
 glance=glance*glance*(3-2*glance)
 local t=(age-Rules.GlanceIn)/Rules.Wave
 local hand=0
 if t>0 and t<1 then
  -- The hand goes up quickly, sweeps twice (peaks at 1/4 and 3/4) and comes down.
  -- Reduced Motion raises it once, a little.
  local env=math.min(1,t/.15,(1-t)/.15);env=env*env*(3-2*env)
  hand=if reduced then .7*env else(1.3-.45*math.cos(t*math.pi*4))*env
 end
 return glance,hand
end
local function relative(origin,yaw,target)
 local d=target-origin
 if d.X*d.X+d.Z*d.Z<.25 then return 0 end
 local delta=math.atan2(d.X,d.Z)-(yaw or 0)
 return math.atan2(math.sin(delta),math.cos(delta))
end
-- Head yaw offset, right-hand fold and an expression for the visual's current hello.
-- `blocked` is the visual's own "the owner has it" state.
function Hello.sample(visual,now,blocked)
 local hello=visual.hello
 if not hello or blocked then return 0,0,nil end
 local glance,hand=Hello.curve(now-hello.at,visual.reducedEffects==true)
 if glance<=0 then return 0,0,nil end
 local target=visual.helloTarget
 if typeof(target)~="Vector3"then
  local player=Players:GetPlayerByUserId(hello.from)
  local root=player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  target=root and root.Position or nil
 end
 local yaw=if target then math.clamp(relative(visual.origin,visual.yaw,target),-Hello.MaxYaw,Hello.MaxYaw)*glance else 0
 return yaw,hand,"pleased"
end
return Hello
