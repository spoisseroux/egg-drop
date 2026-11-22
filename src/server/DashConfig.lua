-- The Garden Dash runtime switches (V3-DASH-BUILD-PLAN-2026-11-22): AliveConfig's publisher on two keys.
-- ConfigService `garden_dash` = false ends every race and hides the gate without a publish; `garden_dash_prizes`
-- = false turns Stars, ribbons and cups off alone. Both are off until the config has loaded once (or an owner
-- override), then follow it: missing or malformed = the shipped default (on); a later failed or errored
-- snapshot keeps the last good values. Saved Dash fields are untouched either way: off only hides them.
-- With the build ceiling off nothing starts: no attribute is written and ConfigService is never asked.
-- Owner chat on the beta and in Studio: /dash <on|off|clear>, /dash prizes <on|off|clear>, this server only.
local Dash=require(game:GetService("ReplicatedStorage").Shared.Dash)
local Publisher=require(script.Parent.AliveConfig)
local Config={}

-- Pure: {feature, value} of a chat command (value true, false, or nil for clear); nil when it is not one.
function Config.parse(message)
	if type(message)~="string"then return nil end
	local text=string.lower(message)
	local feature,verb="race",string.match(text,"^%s*/dash%s+(%a+)%s*$")
	if not verb then feature,verb="prizes",string.match(text,"^%s*/dash%s+prizes%s+(%a+)%s*$")end
	if verb~="on"and verb~="off"and verb~="clear"then return nil end
	return{feature=feature,value=if verb=="clear"then nil else verb=="on"}
end
-- deps as AliveConfig.new (switch and label are filled in), plus hold(feature, value): the server's own value.
function Config.new(deps)
	deps=table.clone(deps)
	local self
	deps.label="Dash"
	deps.switch={Features=Dash.Features,attribute=Dash.attribute,key=Dash.key,
		resolve=function(_,value,override,ceiling)
			if not self.loaded and type(override)~="boolean"then return false end
			return Dash.resolve(value,override,ceiling)
		end}
	local set,hold=deps.set,deps.hold
	local features={}
	for _,feature in ipairs(Dash.Features)do features[Dash.attribute(feature)]=feature end
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
	hold=Dash.setSwitch,set=function(name,value)workspace:SetAttribute(name,value)end,
	wait=task.wait,spawn=task.spawn,now=os.clock,ceiling=function()return Dash.ceiling()end,warn=warn})
Config.start=shared.start
Config.command=shared.command
return Config
