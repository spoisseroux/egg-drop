-- The world feel runtime switches (beta 14 QA W4): AliveConfig's publisher on two keys. ConfigService `world_feel` /
-- `world_walk` = false puts that part back as it was without a publish. Both are off until the config has loaded once
-- (or an owner override), then follow it: missing or malformed = on; a later failed snapshot keeps the last good
-- values. With the build ceiling off nothing starts: no attribute is written and ConfigService is never asked.
-- Owner chat on the beta and in Studio: /feel <feel|walk|all> <on|off|clear>, this server only.
local Feel=require(game:GetService("ReplicatedStorage").Shared.WorldFeel)
local Publisher=require(script.Parent.AliveConfig)
local Config={}

-- Pure: {features, value} of a chat command (value true, false, or nil for clear); nil when it is not one.
function Config.parse(message)
	if type(message)~="string"then return nil end
	local name,verb=string.match(string.lower(message),"^%s*/feel%s+(%a+)%s+(%a+)%s*$")
	if verb~="on"and verb~="off"and verb~="clear"then return nil end
	local features=if name=="all"then Feel.Features elseif table.find(Feel.Features,name)then{name}else nil
	if not features then return nil end
	return{features=features,value=if verb=="clear"then nil else verb=="on"}
end
function Config.new(deps)
	deps=table.clone(deps)
	local self
	deps.label="Feel"
	deps.switch={Features=Feel.Features,attribute=Feel.attribute,key=Feel.key,
		resolve=function(_,value,override,ceiling)
			if not self.loaded and type(override)~="boolean"then return false end
			return Feel.resolve(value,override,ceiling)
		end}
	local set,hold=deps.set,deps.hold
	local features={}
	for _,feature in ipairs(Feel.Features)do features[Feel.attribute(feature)]=feature end
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
		for _,feature in ipairs(command.features)do self.overrides[feature]=command.value end
		self.publish()
		return true
	end
	return self
end

local shared=Config.new({service=function()return game:GetService("ConfigService")end,
	hold=Feel.setSwitch,set=function(name,value)workspace:SetAttribute(name,value)end,
	wait=task.wait,spawn=task.spawn,now=os.clock,ceiling=function()return Feel.ceiling()end,warn=warn})
Config.start=shared.start
Config.command=shared.command
return Config
