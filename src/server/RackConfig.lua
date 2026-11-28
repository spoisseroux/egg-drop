-- The daily rack's runtime switches (DailyRack; ROTATION-BRIEF 5, ARCH-REVIEW-ROTATION 7): AliveConfig's publisher on
-- three keys, the OnboardConfig pattern. ConfigService `daily_rack` / `look_daily` / `look_nopity`. All are off until
-- the config has loaded once (or an owner override), then follow it: missing or malformed = the part's shipped default
-- (daily_rack on; look_daily and look_nopity OFF until their before-live items are settled); a later failed or errored
-- snapshot keeps the last good values. With the build ceiling off (live) nothing starts: no attribute is written and
-- ConfigService is never asked. Owned items stay owned and wearable either way.
-- Owner chat on the beta and in Studio: /rack <rack|lookdaily|looknopity|all> <on|off|clear>, this server only.
local Rack=require(game:GetService("ReplicatedStorage").Shared.DailyRack)
local Publisher=require(script.Parent.AliveConfig)
local Config={}

-- Pure: {features, value} of a chat command (value true, false, or nil for clear); nil when it is not one.
function Config.parse(message)
	if type(message)~="string"then return nil end
	local name,verb=string.match(string.lower(message),"^%s*/rack%s+(%a+)%s+(%a+)%s*$")
	if verb~="on"and verb~="off"and verb~="clear"then return nil end
	local features=if name=="all"then Rack.Features elseif table.find(Rack.Features,name)then{name}else nil
	if not features then return nil end
	return{features=features,value=if verb=="clear"then nil else verb=="on"}
end
-- deps as AliveConfig.new (switch and label are filled in), plus hold(feature, value): the server's own value.
function Config.new(deps)
	deps=table.clone(deps)
	local self
	deps.label="DailyRack"
	deps.switch={Features=Rack.Features,attribute=Rack.attribute,key=Rack.key,
		resolve=function(feature,value,override,ceiling)
			if not self.loaded and type(override)~="boolean"then return false end
			return Rack.resolve(feature,value,override,ceiling)
		end}
	local set,hold=deps.set,deps.hold
	local features={}
	for _,feature in ipairs(Rack.Features)do features[Rack.attribute(feature)]=feature end
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
	hold=Rack.setSwitch,set=function(name,value)workspace:SetAttribute(name,value)end,
	wait=task.wait,spawn=task.spawn,now=os.clock,ceiling=function()return Rack.ceiling()end,warn=warn})
Config.start=shared.start
Config.command=shared.command
return Config
