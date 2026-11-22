-- Springs for paint (ALIVE-BUILD-PLAN-2026-11-22 step 1). State always changes first; a spring only
-- moves something toward a rest it can be cut to on any frame. One writer per property: anything else
-- writing it (a "foreign" write) cancels the spring and keeps that value.
-- Spring.to(object,property,goal,options): number, Vector2, UDim or UDim2. options:
--   frequency (Hz), damping (1 = no overshoot), velocity (added), epsilon, delay, limit (s, then rest),
--   feature (Alive switch, default "springs"), done(reason), called exactly once:
--   rest | snap | settle | drop | error (the goal was written), replaced | cancel | foreign (it was not).
--   get, set(value, velocity), mark: a virtual property made of several writes (get and mark read back).
local GuiService=game:GetService("GuiService")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local Alive=require(game:GetService("ReplicatedStorage").Shared.Alive)
local Spring={Instant=false,MaxDt=1/20,MaxTime=3,Caps={touch=24,desktop=48},profile=false,stepMs=0}
local live={} -- object -> {property -> spring}; emptied at rest
local count=0
local connection
function Spring.reduced()return GuiService.ReducedMotionEnabled end -- DeckKit points this at Kit.patternStill
function Spring.cap()return if UserInputService.TouchEnabled then Spring.Caps.touch else Spring.Caps.desktop end
function Spring.count()return count end
function Spring.busy(object,property)
 local set=live[object]
 return set~=nil and(property==nil or set[property]~=nil)
end

local function pack(value)
 local kind=typeof(value)
 if kind=="number"then return{value},kind
 elseif kind=="Vector2"then return{value.X,value.Y},kind
 elseif kind=="UDim"then return{value.Scale,value.Offset},kind
 elseif kind=="UDim2"then return{value.X.Scale,value.X.Offset,value.Y.Scale,value.Y.Offset},kind end
 error("KitSpring cannot move a "..kind)
end
local function build(kind,x)
 if kind=="number"then return x[1]
 elseif kind=="Vector2"then return Vector2.new(x[1],x[2])
 elseif kind=="UDim"then return UDim.new(x[1],x[2])end
 return UDim2.new(x[1],x[2],x[3],x[4])
end
local Epsilon={number={.0005},Vector2={.05,.05},UDim={.0005,.1},UDim2={.0005,.1,.0005,.1}}

local function read(s)if s.get then return s.get()end;return s.object[s.property]end
local function mark(s)if s.mark then return s.mark()end;return read(s)end
local function write(s,value,velocity)
 if s.set then s.set(value,velocity)else s.object[s.property]=value end
end
-- A foreign write is judged against the value read back after our own (Scale is float32, offsets whole px).
local function put(s)write(s,build(s.kind,s.x),s.v[1]);s.last=mark(s)end
local function foreign(s)return mark(s)~=s.last end

local function remove(s)
 local set=live[s.object]
 if not set or set[s.property]~=s then return false end
 set[s.property]=nil;count-=1
 if next(set)==nil then live[s.object]=nil end
 if count<=0 and connection then connection:Disconnect();connection=nil end
 return true
end
local function report(s,reason)
 local done=s.done;s.done=nil
 if not done then return end
 local ok,problem=pcall(done,reason)
 if not ok then warn("[KitSpring] done: "..tostring(problem))end
end
local function finish(s,reason,atGoal)
 if not remove(s)then return end
 if atGoal then
  local ok,problem=pcall(write,s,s.goal,0)
  if not ok then warn("[KitSpring] "..tostring(problem))end
 end
 report(s,reason)
end

-- "ok", "hidden" (an ancestor is not Visible or Enabled) or "out" (not in the game).
local seen={}
local function state(n)
 local known=seen[n];if known then return known end
 local result
 if n==game then result="ok"
 elseif n.Parent==nil then result="out"
 else
  result=state(n.Parent)
  if result=="ok"and((n:IsA("GuiObject")and not n.Visible)or(n:IsA("LayerCollector")and not n.Enabled))then result="hidden"end
 end
 seen[n]=result
 return result
end
local function stateOf(object)table.clear(seen);local result=state(object);table.clear(seen);return result end
Spring.stateOf=stateOf

local function integrate(s,dt)
 local w,z=s.w,s.z
 if z>=1 then
  local e=math.exp(-w*dt)
  for i,g in ipairs(s.g)do
   local d,v=s.x[i]-g,s.v[i];local k=v+w*d
   s.x[i]=g+e*(d+k*dt);s.v[i]=e*(v-w*dt*k)
  end
  return
 end
 local wd=w*math.sqrt(1-z*z);local e=math.exp(-z*w*dt);local c,n=math.cos(wd*dt),math.sin(wd*dt)
 for i,g in ipairs(s.g)do
  local d,v=s.x[i]-g,s.v[i]
  s.x[i]=g+e*(d*c+(v+z*w*d)/wd*n);s.v[i]=e*(v*c-(z*w*v+w*w*d)/wd*n)
 end
end
local function resting(s)
 for i,g in ipairs(s.g)do
  local eps=s.epsilon or Epsilon[s.kind][i]
  if math.abs(s.x[i]-g)>eps or math.abs(s.v[i])>eps*s.w then return false end
 end
 return true
end

local featureOn={}
local function enabled(feature)
 local known=featureOn[feature]
 if known==nil then known=Alive.on(feature);featureOn[feature]=known end
 return known
end
local function advance(s,dt,cut,real)
 if foreign(s)then finish(s,"foreign",false);return end
 local where=state(s.object)
 if where=="out"then finish(s,"drop",true);return end
 if cut or not enabled(s.feature)then finish(s,"snap",true);return end
 if where=="hidden"then finish(s,"settle",true);return end
 s.age+=real
 if s.age>=s.limit then finish(s,"rest",true);return end
 if s.delay>0 then s.delay-=real;return end
 integrate(s,dt)
 if resting(s)then finish(s,"rest",true)else put(s)end
end
function Spring.step(dt)
 local began=if Spring.profile then os.clock()else nil
 -- Motion steps are capped, but a limit or delay counts real time, so a slow phone lands just as soon.
 local real=math.clamp(dt,0,.25);dt=math.min(real,Spring.MaxDt)
 table.clear(seen);table.clear(featureOn)
 local cut=Spring.Instant or Spring.reduced()
 local list={}
 for _,set in pairs(live)do for _,s in pairs(set)do table.insert(list,s)end end
 for _,s in ipairs(list)do
  local set=live[s.object]
  if set and set[s.property]==s then
   local ok,problem=pcall(advance,s,dt,cut,real)
   if not ok then
    warn("[KitSpring] "..tostring(s.property)..": "..tostring(problem))
    if remove(s)then pcall(write,s,s.goal,0);report(s,"error")end
   end
  end
 end
 table.clear(seen);table.clear(featureOn) -- `seen` would hold destroyed instances
 if began then Spring.stepMs=(os.clock()-began)*1000 end
end

function Spring.to(object,property,goal,options)
 options=options or {}
 local g,kind=pack(goal)
 local s={object=object,property=property,goal=goal,g=g,kind=kind,get=options.get,set=options.set,mark=options.mark,
  w=2*math.pi*(options.frequency or 4),z=math.max(.05,options.damping or .5),epsilon=options.epsilon,done=options.done,
  feature=options.feature or "springs",delay=options.delay or 0,age=0,limit=options.limit or Spring.MaxTime}
 local old=live[object]and live[object][property]
 -- A retarget keeps its position and speed, unless something else wrote the property meanwhile.
 if old and old.kind==kind and not foreign(old)then s.x,s.v=old.x,old.v
 else
  local x,now=pack(read(s))
  assert(now==kind,"KitSpring: "..tostring(property).." is a "..now..", not a "..kind)
  s.x,s.v=x,table.create(#x,0)
 end
 if options.velocity~=nil then for i,v in ipairs((pack(options.velocity)))do s.v[i]+=v end end
 if old then remove(old)end
 if Spring.Instant or Spring.reduced()or not RunService:IsClient()or not Alive.on(s.feature)or count>=Spring.cap()or stateOf(object)~="ok"then
  write(s,goal,0)
  if old then report(old,"replaced")end
  report(s,"snap")
  return nil
 end
 live[object]=live[object]or {};live[object][property]=s;count+=1
 if s.set then put(s)else s.last=mark(s)end
 if not connection then connection=RunService.RenderStepped:Connect(Spring.step)end
 if old then report(old,"replaced")end
 if live[object]and live[object][property]==s and s.delay<=0 and resting(s)then finish(s,"rest",true);return nil end
 return s
end
-- Everything on or under `root` (nil: everything) goes to its goal now.
function Spring.settle(root,property)
 local list={}
 for object,set in pairs(live)do
  if root==nil or object==root or object:IsDescendantOf(root)then
   for name,s in pairs(set)do if property==nil or name==property then table.insert(list,s)end end
  end
 end
 for _,s in ipairs(list)do
  local ok,other=pcall(foreign,s)
  if ok and other then finish(s,"foreign",false)else finish(s,"settle",true)end
 end
 return #list
end
-- Stops one spring where it stands (the caller writes the property next).
function Spring.cancel(object,property)
 local s=live[object]and live[object][property]
 if not s then return false end
 finish(s,"cancel",false)
 return true
end
return Spring
