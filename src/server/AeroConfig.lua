-- The Frutiger Aero runtime switch (WORLD-PLAN-2026-11-22 section 9): AliveConfig's publisher on one key.
-- ConfigService `aero_world` = false puts every client back in the garden as it was without a publish. Off until the
-- config has loaded once (or an owner override), then it follows it: missing or malformed = the shipped default (on);
-- a later failed or errored snapshot keeps the last good value. Nothing but the look depends on it.
-- With the build ceiling off nothing starts: no attribute is written and ConfigService is never asked.
-- Owner chat on the beta and in Studio: /aero <on|off|clear>, and /aero <lime|coral> for the crowns; this server only.
local Aero=require(game:GetService("ReplicatedStorage").Shared.Aero)
local Publisher=require(script.Parent.AliveConfig)
local Config={Feature="aero"}

-- Pure: {value} (true, false, or nil for clear) or {trees} of a chat command; nil when it is not one.
function Config.parse(message)
	if type(message)~="string"then return nil end
	local verb=string.match(string.lower(message),"^%s*/aero%s+(%a+)%s*$")
	if not verb then return nil end
	if table.find(Aero.Trees,verb)then return{trees=verb}end
	if verb~="on"and verb~="off"and verb~="clear"then return nil end
	return{value=if verb=="clear"then nil else verb=="on"}
end
-- deps as AliveConfig.new (switch and label are filled in).
function Config.new(deps)
	deps=table.clone(deps)
	local self
	deps.label="Aero"
	deps.switch={Features={Config.Feature},attribute=function()return Aero.Attribute end,key=function()return Aero.Key end,
		resolve=function(_,value,override,ceiling)
			if not self.loaded and type(override)~="boolean"then return false end
			return Aero.resolve(value,override,ceiling)
		end}
	self=Publisher.new(deps)
	local start=self.start
	function self.start()
		if deps.ceiling()then start()end
	end
	function self.command(message)
		local command=Config.parse(message)
		if not command or not deps.ceiling()then return false end
		if command.trees then
			pcall(deps.set,Aero.TreesAttribute,command.trees)
		else
			self.overrides[Config.Feature]=command.value
			self.publish()
		end
		return true
	end
	return self
end

-- The Aero world kit (assets/world/AeroKit.rbxmx: split crowns, falls sheets, lips, rocks) is mounted in ServerStorage and
-- copied to ReplicatedStorage only where the ceiling passes, so live clients never download it. Missing: nothing.
-- deps (specs): ceiling() -> bool, groveCeiling() -> bool, from (ServerStorage), to (ReplicatedStorage). Returns the
-- copy, or nil.
function Config.mountKit(deps)
	deps=deps or {}
	local ceiling=deps.ceiling or Aero.ceiling
	if not ceiling()then return nil end
	local from=deps.from or game:GetService("ServerStorage")
	local to=deps.to or game:GetService("ReplicatedStorage")
	-- The Hidden Grove's templates (assets/world/GroveKit.rbxmx, GROVE-BUILD-PLAN; an empty folder until its upload is
	-- confirmed): only where the grove's own ceiling (Alive `grove`) passes too, so no other client downloads them.
	local groveCeiling=deps.groveCeiling or function()
		return require(game:GetService("ReplicatedStorage").Shared.Alive).ceiling("grove")
	end
	local grove=from:FindFirstChild("GroveKit")
	if grove and groveCeiling()and not to:FindFirstChild("GroveKit")then grove:Clone().Parent=to end
	-- Beta 38: the tree grades' trunk pack (assets/world/AeroTrunks.rbxmx) goes with it, the same way (an empty
	-- placeholder folder until its upload is confirmed: the clients then keep today's trunks).
	local trunks=from:FindFirstChild("AeroTrunks")
	if trunks and not to:FindFirstChild("AeroTrunks")then trunks:Clone().Parent=to end
	local kit=from:FindFirstChild("AeroKit")
	if not kit or to:FindFirstChild("AeroKit")then return to:FindFirstChild("AeroKit")end
	local copy=kit:Clone()
	copy.Parent=to
	return copy
end

local shared=Config.new({service=function()return game:GetService("ConfigService")end,
	set=function(name,value)workspace:SetAttribute(name,value)end,
	wait=task.wait,spawn=task.spawn,now=os.clock,ceiling=function()return Aero.ceiling()end,warn=warn})
function Config.start()
	-- Before the switch is published, so a client that sees Aero on finds the kit already there.
	local ok,problem=pcall(Config.mountKit)
	if not ok then warn("[Aero] kit not mounted: "..tostring(problem))end
	shared.start()
end
Config.command=shared.command
return Config
