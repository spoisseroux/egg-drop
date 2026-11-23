-- The owner's fresh save for first-session testing (beta (12) QA T1). Connected only inside init's owner chat block
-- (the beta place or Studio, SimCheck.isOwner), and refused again here unless ProgressKey's gate is open (the
-- FreshSaveCommand flag, and the in-memory store or the beta place in the beta universe). So never on live.
--   /freshsave          the next join is a brand-new save (a new key, player_<id>_fs<N>); the old save is untouched
--   /freshsave restore  the next join is the old save again (the base key, player_<id>)
-- One pointer write (ProgressKey.point), then a kick with the reason: both need a rejoin. Nothing is copied or deleted.
local Key=require(script.Parent.ProgressKey)
local Fresh={}
Fresh.Gap=10 -- seconds between two commands, per player
Fresh.Kick=table.freeze({
	fresh="Fresh save on your next join. Rejoin the beta. Your old save is kept: /freshsave restore brings it back.",
	restore="Your old save comes back on your next join. Rejoin the beta.",
})
local last={}

-- Pure: "fresh", "restore" or nil.
function Fresh.parse(message)
	if type(message)~="string"then return nil end
	local text=string.lower(message)
	if string.match(text,"^%s*/freshsave%s*$")then return "fresh"end
	if string.match(text,"^%s*/freshsave%s+restore%s*$")then return "restore"end
	return nil
end
-- The gate, for specs and init.
function Fresh.ceiling(env)return Key.enabled(env)end

-- deps (specs): now(), point(userId, action) -> key?, why; kick(player, text); warn(text).
function Fresh.command(player,message,deps)
	deps=deps or {}
	local action=Fresh.parse(message)
	if not action or not Key.enabled()then return false end
	local now=(deps.now or os.clock)()
	local userId=player.UserId
	if last[userId]and now-last[userId]<Fresh.Gap then return false,"Throttled"end
	last[userId]=now
	local target,why=(deps.point or Key.point)(userId,action)
	local say=deps.warn or warn
	if not target then
		pcall(say,"[FreshSave] /freshsave "..action.." not done: "..tostring(why))
		return false,why
	end
	pcall(say,"[FreshSave] "..tostring(userId).." will join on "..target)
	local kick=deps.kick or function(who,text)who:Kick(text)end
	pcall(kick,player,Fresh.Kick[action])
	return true,target
end
function Fresh.forget(userId)last[userId]=nil end

return Fresh
