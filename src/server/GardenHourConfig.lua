-- The garden hour runtime switch (GARDEN-HOUR-BUILD-PLAN-2026-11-23, slice A): AliveConfig's publisher on one key, the
-- FindsConfig shape, but a missing or malformed `garden_hour` is OFF (true turns it on). Off until the config has loaded
-- once (or an owner override); a later failed or errored snapshot keeps the last good value. Off is the garden as it was.
-- With the build ceiling off nothing starts: no attribute is written and ConfigService is never asked.
-- Owner chat on the beta and in Studio, this server only: /hour <on|off|clear>, and /hour at <seconds 0-3599>, which
-- sets workspace Hour_offset so the hour's position becomes that second now (0 dawn, 360 day, 2400 golden, 2880 night).
-- /hour clear also clears Hour_offset: back to the config's value on the real clock.
local GardenHour=require(game:GetService("ReplicatedStorage").Shared.GardenHour)
local Publisher=require(script.Parent.AliveConfig)
local Config={Feature="hour"}

-- Pure: {value} (true, false, or nil for clear) or {at = whole seconds 0-3599} of a chat command; nil when it is not one.
function Config.parse(message)
	if type(message)~="string"then return nil end
	local text=string.lower(message)
	local at=string.match(text,"^%s*/hour%s+at%s+(%S+)%s*$")
	if at then
		local seconds=if string.match(at,"^%d+$")then tonumber(at)else nil
		if not seconds or seconds>=GardenHour.Period then return nil end
		return{at=seconds}
	end
	local verb=string.match(text,"^%s*/hour%s+(%a+)%s*$")
	if verb~="on"and verb~="off"and verb~="clear"then return nil end
	return{value=if verb=="clear"then nil else verb=="on"}
end
-- Pure: the Hour_offset that puts server time `now` at second `at` of the hour, in [0, 3600).
function Config.offsetFor(at,now)return(at-now%GardenHour.Period)%GardenHour.Period end

-- deps as AliveConfig.new (switch and label are filled in), plus hold(value): the server's own value; testing(): Studio
-- or the beta; clock(): server time; offset(value): writes Hour_offset.
function Config.new(deps)
	deps=table.clone(deps)
	local self
	deps.label="Hour"
	deps.switch={Features={Config.Feature},attribute=function()return GardenHour.Attribute end,key=function()return GardenHour.Key end,
		resolve=function(_,value,override,ceiling)
			if not self.loaded and type(override)~="boolean"then return false end
			return GardenHour.resolve(value,override,ceiling)
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
		if command.at then
			if not deps.testing()then return false end
			return(pcall(deps.offset,Config.offsetFor(command.at,deps.clock())))
		end
		self.overrides[Config.Feature]=command.value
		self.publish()
		if command.value==nil then pcall(deps.offset,nil)end
		return true
	end
	return self
end

local shared=Config.new({service=function()return game:GetService("ConfigService")end,
	hold=GardenHour.setSwitch,set=function(name,value)workspace:SetAttribute(name,value)end,
	wait=task.wait,spawn=task.spawn,now=os.clock,ceiling=function()return GardenHour.ceiling()end,warn=warn,
	testing=function()return GardenHour.testing()end,clock=function()return workspace:GetServerTimeNow()end,
	offset=function(value)workspace:SetAttribute(GardenHour.OffsetAttribute,value)end})
Config.start=shared.start
Config.command=shared.command
return Config
