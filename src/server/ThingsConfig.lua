-- The Things to do runtime switches (V3-THINGS-TO-DO-PLAN-2026-11-22): AliveConfig's publisher on two keys.
-- ConfigService `things_to_do` = false puts the Pocket menu, the tips and the stations back as they were without a
-- publish; `things_tips` = false stops only the onboarding lines. Both are off until the config has loaded once (or an
-- owner override), then follow it: missing or malformed = on; a later failed or errored snapshot keeps the last good
-- values. Saved coach bits are untouched either way.
-- With the build ceiling off nothing starts: no attribute is written and ConfigService is never asked.
-- Owner chat on the beta and in Studio: /todo <on|off|clear>, /todo tips <on|off|clear>, this server only.
local Things=require(game:GetService("ReplicatedStorage").Shared.Things)
local Publisher=require(script.Parent.AliveConfig)
local Config={}

-- Pure: {feature, value} of a chat command (value true, false, or nil for clear); nil when it is not one.
function Config.parse(message)
	if type(message)~="string"then return nil end
	local text=string.lower(message)
	local feature,verb="page",string.match(text,"^%s*/todo%s+(%a+)%s*$")
	if not verb then feature,verb="tips",string.match(text,"^%s*/todo%s+tips%s+(%a+)%s*$")end
	if verb~="on"and verb~="off"and verb~="clear"then return nil end
	return{feature=feature,value=if verb=="clear"then nil else verb=="on"}
end
-- deps as AliveConfig.new (switch and label are filled in), plus hold(feature, value): the server's own value.
function Config.new(deps)
	deps=table.clone(deps)
	local self
	deps.label="Things"
	deps.switch={Features=Things.Features,attribute=Things.attribute,key=Things.key,
		resolve=function(_,value,override,ceiling)
			if not self.loaded and type(override)~="boolean"then return false end
			return Things.resolve(value,override,ceiling)
		end}
	local set,hold=deps.set,deps.hold
	local features={}
	for _,feature in ipairs(Things.Features)do features[Things.attribute(feature)]=feature end
	-- The server's own value first: an attribute that cannot be written never leaves the server on.
	deps.set=function(name,value)
		hold(features[name],value)
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
	hold=Things.setSwitch,set=function(name,value)workspace:SetAttribute(name,value)end,
	wait=task.wait,spawn=task.spawn,now=os.clock,ceiling=function()return Things.ceiling()end,warn=warn})
Config.start=shared.start
Config.command=shared.command
return Config
