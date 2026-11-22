-- The "Stars bought" sound (Spencer 2026-11-22: "can we make a cool sound play when we bought
-- stars"). It plays when the grant lands. Roblox's own purchase window may hold the focus then,
-- and Audio:play refuses while the device is inactive or a voice is still loading, so a refused
-- sound is tried again when that window closes or the game regains focus, for RetryFor seconds,
-- once. Sound effects turned off is the player's choice and is never retried.
--
-- deps: play() -> boolean, muted() -> boolean, now() -> seconds, defer(fn)
local Cue = {}
Cue.__index = Cue
Cue.Name = "stars_bought"
Cue.RetryFor = 10

function Cue.new(deps)
	return setmetatable({ deps = deps, deadline = nil }, Cue)
end
-- A grant landed. True when it sounded now.
function Cue:granted()
	self.deadline = nil
	if self.deps.muted() then return false end
	if self.deps.play() then return true end
	self.deadline = self.deps.now() + Cue.RetryFor
	return false
end
-- The purchase window closed, or the game has the focus again. Deferred: another listener of the
-- same event is what makes the device active.
function Cue:resume()
	if not self.deadline then return end
	self.deps.defer(function()
		local deadline = self.deadline
		if not deadline then return end
		if self.deps.now() > deadline or self.deps.muted() then self.deadline = nil; return end
		if self.deps.play() then self.deadline = nil end
	end)
end
function Cue:waiting() return self.deadline ~= nil end
return Cue
