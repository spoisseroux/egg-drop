-- The "Levels matter" runtime switch (V3-LEVELS-BUILD-PLAN-2026-11-22): AliveConfig's publisher on one key.
-- ConfigService `levels_matter` = false turns the client surfaces, gated selling, medal credit and deck
-- juice off without a publish. Missing or malformed = the shipped default (on); a failed or errored
-- snapshot keeps the last good value. Owned items, medal credit and saved choices are untouched either
-- way: off only hides them. Purchases already frozen (HatchProgress) finish.
-- Levels.on on the server reads Levels.setSwitch's value; the workspace attribute is for clients.
-- Owner chat on the beta and in Studio: /levels <on|off|clear>, for this server only.
local Levels=require(game:GetService("ReplicatedStorage").Shared.Levels)
local Publisher=require(script.Parent.AliveConfig)
local Config={Feature="matter"}
local Switch=table.freeze({Features=table.freeze({Config.Feature}),
 attribute=function()return Levels.Attribute end,key=function()return Levels.Key end,
 resolve=function(_,value,override,ceiling)return Levels.resolve(value,override,ceiling)end})

-- Pure: {value} of a chat command (true, false, or nil for clear); nil when it is not one.
function Config.parse(message)
 if type(message)~="string"then return nil end
 local verb=string.match(string.lower(message),"^%s*/levels%s+(%a+)%s*$")
 if verb~="on"and verb~="off"and verb~="clear"then return nil end
 return{value=if verb=="clear"then nil else verb=="on"}
end
-- deps as AliveConfig.new (switch and label are filled in), plus hold(value): the server's own value.
function Config.new(deps)
 deps=table.clone(deps)
 deps.switch,deps.label=Switch,"Levels"
 local set,hold=deps.set,deps.hold
 -- The server's own value first: an attribute that cannot be written never leaves the server on.
 deps.set=function(name,value)
  hold(value)
  set(name,value)
 end
 local self=Publisher.new(deps)
 function self.command(message)
  local command=Config.parse(message)
  if not command then return false end
  self.overrides[Config.Feature]=command.value
  self.publish()
  return true
 end
 return self
end

local shared=Config.new({service=function()return game:GetService("ConfigService")end,
 hold=Levels.setSwitch,set=function(name,value)workspace:SetAttribute(name,value)end,
 wait=task.wait,spawn=task.spawn,now=os.clock,ceiling=function()return Levels.allowed()end,warn=warn})
Config.start=shared.start
Config.command=shared.command
return Config
