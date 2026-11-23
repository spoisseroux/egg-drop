-- Which save key a player plays on (beta (12) QA T1, architect review of QUICK-FIX-PLAN). Every key builder goes
-- through ProgressKey.of(userId): PlayerProgress (load, fromRecord) and HatchProgress.load. By default that is the
-- base key `player_<id>`, as it has always been.
--
-- On the beta (or the in-memory store in Studio), with FeatureFlags.FreshSaveCommand, a pointer record in the same
-- store, `freshsave_<id>` = {version=1, suffix=N?, last=M}, can send the owner to `player_<id>_fs<N>`: a key nothing
-- has written, so the join is a brand-new save (Progress.load's newSave holds). /freshsave moves the pointer to the
-- next N; /freshsave restore clears the suffix, back to the base key. One write each; nothing is copied or deleted,
-- so a late write from the old session lands on the key that session loaded (profile.key, handle.key), never on the
-- new one.
--
-- resolve(userId) runs once per load (addPlayer, and the reload loop through Progress.load). With the gate closed it
-- reads nothing and answers the base key. With it open it reads the pointer; a failed read or a malformed pointer
-- answers nil, and the caller refuses the load like a lock (Progress.load: loadFailed, so nothing is saved) and tries
-- again later: it never falls back to the base key.
local Store=require(script.Parent.ProgressStore)
local Key={}
Key.BetaPlace=107705084891479   -- Pocket Pals Beta
Key.BetaUniverse=10777916361
Key.MaxSuffix=100000
local active={} -- userId -> the key resolved at its last load
local injected=nil

function Key.base(userId)return "player_"..tostring(userId)end
function Key.pointer(userId)return "freshsave_"..tostring(userId)end
function Key.fresh(userId,n)return Key.base(userId).."_fs"..tostring(n)end

-- The gate (architect): the flag, and either the in-memory store (Studio) or the beta place in the beta universe.
-- env (specs): {flags, persistent, place, game}.
function Key.enabled(env)
	env=env or injected or {}
	local flags=env.flags or require(game:GetService("ReplicatedStorage").Shared.FeatureFlags)
	if flags.FreshSaveCommand~=true then return false end
	local persistent=env.persistent
	if persistent==nil then persistent=Store.persistent end
	if not persistent then return true end
	return(env.place or game.PlaceId)==Key.BetaPlace and(env.game or game.GameId)==Key.BetaUniverse
end
-- Spec seam: env for enabled(), or nil. Refused on a persistent store (a real server).
function Key.inject(env)
	if Store.persistent then return false end
	injected=if type(env)=="table"then table.clone(env)else nil
	return true
end

-- Pure: the suffix a pointer record holds: a number, false (the base key), or nil (malformed).
function Key.suffix(record)
	if record==nil then return false end
	if type(record)~="table"or record.version~=1 then return nil end
	local n=record.suffix
	if n==nil then return false end
	if type(n)~="number"or n%1~=0 or n<1 or n>Key.MaxSuffix then return nil end
	return n
end
-- Pure: the key a pointer record sends userId to, or nil (malformed).
function Key.target(userId,record)
	local n=Key.suffix(record)
	if n==nil then return nil end
	return if n then Key.fresh(userId,n)else Key.base(userId)
end

-- The key this player loads on, or nil and "Locked" (pointer unreadable or malformed: refuse the load).
function Key.resolve(userId,store)
	store=store or Store
	if not Key.enabled()then
		active[userId]=nil
		return Key.base(userId)
	end
	local ok,record=pcall(store.GetAsync,store,Key.pointer(userId))
	local target=ok and Key.target(userId,record)or nil
	if not target then
		active[userId]=nil
		if not ok then warn("[FreshSave] pointer read failed for "..tostring(userId)..": "..tostring(record))
		else warn("[FreshSave] malformed pointer for "..tostring(userId)) end
		return nil,"Locked"
	end
	active[userId]=if target~=Key.base(userId)then target else nil
	return target
end
-- The key resolved at this player's last load (the base key before any resolve, or with the gate closed).
function Key.of(userId)
	return active[userId]or Key.base(userId)
end
function Key.isBase(userId)return Key.of(userId)==Key.base(userId)end
function Key.forget(userId)active[userId]=nil end

-- One pointer write: "fresh" moves to the next suffix, "restore" back to the base key. Returns the new target key,
-- or nil and why ("Closed", "NotFresh" for a restore already on the base key, or the store's error).
function Key.point(userId,action,store)
	store=store or Store
	if not Key.enabled()then return nil,"Closed"end
	if action~="fresh"and action~="restore"then return nil,"Unknown"end
	local why=nil
	local ok,result=pcall(store.UpdateAsync,store,Key.pointer(userId),function(previous)
		why=nil
		local last=0
		if type(previous)=="table"then
			last=if type(previous.last)=="number"and previous.last%1==0 and previous.last>=0 then previous.last else 0
			local n=Key.suffix(previous)
			if n then last=math.max(last,n)end
		end
		if action=="restore"then
			if Key.suffix(previous)==false then why="NotFresh";return nil end
			return{version=1,last=last}
		end
		local n=last+1
		if n>Key.MaxSuffix then why="Full";return nil end
		return{version=1,suffix=n,last=n}
	end)
	if not ok then return nil,tostring(result)end
	if why then return nil,why end
	return Key.target(userId,result)
end

return Key
