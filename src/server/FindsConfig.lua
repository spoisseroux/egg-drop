-- The Garden finds runtime switch (V3-FINDS-BUILD-PLAN-2026-11-22, S9): AliveConfig's publisher on one key.
-- ConfigService `garden_finds` = false clears every sparkle and stops new ones without a publish. Off until the config
-- has loaded once (or an owner override), then follows it: missing or malformed = on; a later failed or errored
-- snapshot keeps the last good value. Saved finds are untouched either way.
-- With the build ceiling off nothing starts: no attribute is written and ConfigService is never asked.
-- Owner chat on the beta and in Studio: /finds <on|off|clear>, this server only.
local Finds=require(game:GetService("ReplicatedStorage").Shared.Finds)
local Publisher=require(script.Parent.AliveConfig)
local Config={}
Config.Features=table.freeze({"finds"})

-- Pure: {feature, value} of a chat command (value true, false, or nil for clear); nil when it is not one.
function Config.parse(message)
	if type(message)~="string"then return nil end
	local verb=string.match(string.lower(message),"^%s*/finds%s+(%a+)%s*$")
	if verb~="on"and verb~="off"and verb~="clear"then return nil end
	return{feature="finds",value=if verb=="clear"then nil else verb=="on"}
end
-- deps as AliveConfig.new (switch and label are filled in), plus hold(value): the server's own value.
function Config.new(deps)
	deps=table.clone(deps)
	local self
	deps.label="Finds"
	deps.switch={Features=Config.Features,attribute=function()return Finds.Attribute end,key=function()return Finds.Key end,
		resolve=function(_,value,override,ceiling)
			if not self.loaded and type(override)~="boolean"then return false end
			return Finds.resolve(value,override,ceiling)
		end}
	local set,hold=deps.set,deps.hold
	-- The server's own value first: an attribute that cannot be written never leaves the server on.
	deps.set=function(name,value)
		hold(value)
		set(name,value)
	end
	self=Publisher.new(deps)
	local start=self.start
	function self.start()
		if deps.ceiling()then start()end
	end
	function self.command(message)
		local command=Config.parse(message)
		if not command or not deps.ceiling()then return false end
		self.overrides[command.feature]=command.value
		self.publish()
		return true
	end
	return self
end

local shared=Config.new({service=function()return game:GetService("ConfigService")end,
	hold=Finds.setSwitch,set=function(name,value)workspace:SetAttribute(name,value)end,
	wait=task.wait,spawn=task.spawn,now=os.clock,ceiling=function()return Finds.ceiling()end,warn=warn})
Config.start=shared.start
Config.command=shared.command
return Config
