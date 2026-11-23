-- The pet catch-up runtime switch (beta (12) QA G1): AliveConfig's publisher on one key, as IslandBoundsConfig.
-- ConfigService `pet_catchup` = false stops the hops without a publish. Off until the config has loaded once (or an
-- owner override), then follows it: missing or malformed = on; a later failed or errored snapshot keeps the last good
-- value. With the build ceiling off nothing starts: no attribute is written and ConfigService is never asked.
-- Owner chat on the beta and in Studio: /catchup <on|off|clear>, this server only.
local Catchup=require(game:GetService("ReplicatedStorage").Shared.PetCatchup)
local Publisher=require(script.Parent.AliveConfig)
local Config={}
Config.Features=table.freeze({"catchup"})

-- Pure: {feature, value} of a chat command (value true, false, or nil for clear); nil when it is not one.
function Config.parse(message)
	if type(message)~="string"then return nil end
	local verb=string.match(string.lower(message),"^%s*/catchup%s+(%a+)%s*$")
	if verb~="on"and verb~="off"and verb~="clear"then return nil end
	return{feature="catchup",value=if verb=="clear"then nil else verb=="on"}
end
-- deps as AliveConfig.new (switch and label are filled in), plus hold(value): the server's own value.
function Config.new(deps)
	deps=table.clone(deps)
	local self
	deps.label="Catchup"
	deps.switch={Features=Config.Features,attribute=function()return Catchup.Attribute end,key=function()return Catchup.Key end,
		resolve=function(_,value,override,ceiling)
			if not self.loaded and type(override)~="boolean"then return false end
			return Catchup.resolve(value,override,ceiling)
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
	hold=Catchup.setSwitch,set=function(name,value)workspace:SetAttribute(name,value)end,
	wait=task.wait,spawn=task.spawn,now=os.clock,ceiling=function()return Catchup.ceiling()end,warn=warn})
Config.start=shared.start
Config.command=shared.command
return Config
