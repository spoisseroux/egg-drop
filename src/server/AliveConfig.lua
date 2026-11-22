-- The Alive off switch (ALIVE-BUILD-PLAN-2026-11-22 step 0). Writes one boolean workspace attribute per
-- feature before anything yields, then follows ConfigService. A missing or malformed key is the shipped
-- default (on); a failed or errored snapshot keeps the last good values. Nothing here reaches the caller.
-- Owner chat on the beta and in Studio: /alive <feature|all> <on|off|clear>, for this server only.
local Alive=require(game:GetService("ReplicatedStorage").Shared.Alive)
local Config={}
Config.Backoff=table.freeze({5,15,60})
Config.Retry=300
Config.RefreshGap=5

-- Values read from a snapshot, or nil and the problem when it is errored or throws.
function Config.read(snapshot)
 local ok,values=pcall(function()
  local problem=snapshot.Error
  if typeof(problem)=="EnumItem"then problem=problem.Name end
  if problem~=nil and problem~="None"then error(tostring(problem),0)end
  local out={}
  for _,feature in ipairs(Alive.Features)do
   local value=snapshot:GetValue(Alive.key(feature))
   if type(value)=="boolean"then out[feature]=value end
  end
  return out
 end)
 if ok then return values end
 return nil,values
end
-- Pure: {features, value} of a chat command; value is true, false or nil (clear). nil when it is not one.
function Config.parse(message)
 if type(message)~="string"then return nil end
 local name,verb=string.match(string.lower(message),"^%s*/alive%s+(%a+)%s+(%a+)%s*$")
 if verb~="on"and verb~="off"and verb~="clear"then return nil end
 local features=if name=="all"then Alive.Features elseif table.find(Alive.Features,name)then{name}else nil
 if not features then return nil end
 return{features=features,value=if verb=="clear"then nil else verb=="on"}
end

-- deps (specs replace them): service(), set(name, value), wait(s), spawn(fn), now(), ceiling(feature), warn(text).
function Config.new(deps)
 local self={values={},overrides={},loaded=false,started=false}
 local lastRefresh,queued,turn=-math.huge,false,0
 local warned={}
 local function once(kind,problem)
  if warned[kind]then return end
  warned[kind]=true
  pcall(deps.warn,"[Alive] config "..kind..": "..tostring(problem).." (keeping the last good values)")
 end
 function self.publish()
  for _,feature in ipairs(Alive.Features)do
   pcall(deps.set,Alive.attribute(feature),Alive.resolve(feature,self.values[feature],self.overrides[feature],deps.ceiling(feature)))
  end
 end
 local function adopt(snapshot)
  local values,problem=Config.read(snapshot)
  if not values then once("snapshot",problem);return false end
  self.values=values;self.loaded=true;self.publish()
  return true
 end
 -- A refresh that fails is tried again on the boot backoff; a newer update takes its turn.
 local function onUpdate(snapshot,try)
  if queued then return end
  queued=true;turn+=1
  local mine=turn
  deps.spawn(function()
   local left=lastRefresh+Config.RefreshGap-deps.now()
   if left>0 then deps.wait(left)end
   queued=false;lastRefresh=deps.now()
   local ok,problem=pcall(function()snapshot:Refresh()end)
   if not ok then once("refresh",problem)end
   if ok and adopt(snapshot)then return end
   try=(try or 0)+1
   deps.wait(Config.Backoff[try]or Config.Retry)
   if mine==turn then onUpdate(snapshot,try)end
  end)
 end
 local function load()
  local ok,snapshot=pcall(function()return deps.service():GetConfigAsync()end)
  if not ok or not snapshot then once("service",snapshot);return false end
  if not adopt(snapshot)then return false end
  local linked,problem=pcall(function()snapshot.UpdateAvailable:Connect(function()onUpdate(snapshot)end)end)
  if not linked then once("signal",problem)end
  -- An update may have landed between the load and the connection.
  local known,outdated=pcall(function()return snapshot.Outdated end)
  if known and outdated==true then onUpdate(snapshot)end
  return true
 end
 function self.start()
  if self.started then return end
  self.started=true
  self.publish()
  local wanted=false
  for _,feature in ipairs(Alive.Features)do wanted=wanted or deps.ceiling(feature)end
  if not wanted then return end
  deps.spawn(function()
   local try=0
   while not load()do
    try+=1
    deps.wait(Config.Backoff[try]or Config.Retry)
   end
  end)
 end
 function self.command(message)
  local command=Config.parse(message)
  if not command then return false end
  for _,feature in ipairs(command.features)do self.overrides[feature]=command.value end
  self.publish()
  return true
 end
 return self
end

local shared=Config.new({service=function()return game:GetService("ConfigService")end,
 set=function(name,value)workspace:SetAttribute(name,value)end,wait=task.wait,spawn=task.spawn,now=os.clock,
 ceiling=function(feature)return Alive.ceiling(feature)end,warn=warn})
Config.start=shared.start
Config.command=shared.command
return Config
