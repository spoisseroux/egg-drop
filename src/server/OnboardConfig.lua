-- The onboarding v3 runtime switches (ONBOARDING-V3-PLAN-2026-11-23): AliveConfig's publisher on three keys.
-- ConfigService `onboard_follow` / `onboard_needs` / `onboard_nest` = false puts that part back as it was without a
-- publish. All are off until the config has loaded once (or an owner override), then follow it: missing or malformed =
-- on; a later failed or errored snapshot keeps the last good values. Saved coach bits and nest fields are untouched.
-- Each published value is the part's own value AND Things.on(), and Things flips republish (deps.watch), so with Things
-- to do off every part is off. With the build ceiling off nothing starts: no attribute is written and ConfigService
-- is never asked. Owner chat on the beta and in Studio: /onboard <follow|needs|nest|all> <on|off|clear>, this server only.
local Shared=game:GetService("ReplicatedStorage").Shared
local Onboard=require(Shared.Onboard)
local Things=require(Shared.Things)
local Publisher=require(script.Parent.AliveConfig)
local Config={}

-- Pure: {features, value} of a chat command (value true, false, or nil for clear); nil when it is not one.
function Config.parse(message)
	if type(message)~="string"then return nil end
	local name,verb=string.match(string.lower(message),"^%s*/onboard%s+(%a+)%s+(%a+)%s*$")
	if verb~="on"and verb~="off"and verb~="clear"then return nil end
	local features=if name=="all"then Onboard.Features elseif table.find(Onboard.Features,name)then{name}else nil
	if not features then return nil end
	return{features=features,value=if verb=="clear"then nil else verb=="on"}
end
-- deps as AliveConfig.new (switch and label are filled in), plus hold(feature, value): the server's own value,
-- things(): Things to do is on, and watch(fn): call fn when Things changes (both default to the real Things).
function Config.new(deps)
	deps=table.clone(deps)
	local self
	deps.label="Onboard"
	local things=deps.things or function()return Things.on()end
	deps.switch={Features=Onboard.Features,attribute=Onboard.attribute,key=Onboard.key,
		resolve=function(_,value,override,ceiling)
			if not self.loaded and type(override)~="boolean"then return false end
			return Onboard.resolve(value,override,ceiling and things())
		end}
	local set,hold=deps.set,deps.hold
	local features={}
	for _,feature in ipairs(Onboard.Features)do features[Onboard.attribute(feature)]=feature end
	-- The server's own value first: an attribute that cannot be written never leaves the server on.
	deps.set=function(name,value)
		hold(features[name],value)
		set(name,value)
	end
	self=Publisher.new(deps)
	local start=self.start
	function self.start()
		if not deps.ceiling()then return end
		start()
		local watch=deps.watch or function(fn)Things.changed("page"):Connect(fn)end
		pcall(watch,function()self.publish()end)
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
	hold=Onboard.setSwitch,set=function(name,value)workspace:SetAttribute(name,value)end,
	wait=task.wait,spawn=task.spawn,now=os.clock,ceiling=function()return Onboard.ceiling()end,warn=warn})
Config.start=shared.start
Config.command=shared.command
-- Has the config loaded once (or an owner set a switch)? FirstSession waits for this before choosing its funnel table.
function Config.loaded()return shared.loaded==true or next(shared.overrides)~=nil end
return Config
