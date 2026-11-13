-- Paid random items policy (PLAY-FOREVER BUILD-PLAN F1, architect change 6). One cached
-- read of PolicyService per player. Fails CLOSED: until the policy says
-- ArePaidRandomItemsRestricted == false, the player is treated as restricted (no Star
-- packs, and every Star-priced egg gives the fixed next item instead of a roll).
local Policy={Attempts=3}
local cache={} -- [userId] = true (restricted) | false (allowed)
local inflight={}

local function defaultGet(player)
	local PolicyService=game:GetService("PolicyService")
	return PolicyService:GetPolicyInfoForPlayerAsync(player)
end

-- Pure-ish read with injectable getter and wait (specs). Returns restricted (boolean)
-- and whether PolicyService actually answered.
function Policy.read(player,getInfo,wait)
	getInfo=getInfo or defaultGet
	wait=wait or task.wait
	for attempt=1,Policy.Attempts do
		local ok,info=pcall(getInfo,player)
		if ok and type(info)=="table"then return info.ArePaidRandomItemsRestricted~=false,true end
		if attempt<Policy.Attempts then wait(attempt)end
	end
	return true,false
end

-- Cached value, never yields. Unknown (not read yet, or the read failed) = restricted.
function Policy.cached(player)
	local key=player and player.UserId
	if key==nil or cache[key]==nil then return true end
	return cache[key]
end

-- Reads once per player (yields); concurrent callers wait for the same read.
function Policy.resolve(player,getInfo,wait)
	local key=player.UserId
	if cache[key]~=nil then return cache[key]end
	if inflight[key]then
		local waiting=inflight[key]
		while inflight[key]==waiting and cache[key]==nil do task.wait(.1)end
		return Policy.cached(player)
	end
	local token={}
	inflight[key]=token
	local ok,restricted,answered=pcall(Policy.read,player,getInfo,wait)
	local result=if ok then restricted==true else true
	-- Code review 2026-11-13: cache only a real answer (an outage stays restricted for
	-- now but is asked again next time), and never after the player left (forget ran).
	if inflight[key]==token then
		if ok and answered then cache[key]=result end
		inflight[key]=nil
	end
	return result
end

-- Resolve on its own thread and call back (keeps the host's worker set unchanged).
function Policy.resolveAsync(player,callback)
	task.spawn(function()
		local restricted=Policy.resolve(player)
		callback(restricted)
	end)
end
function Policy.forget(player)
	if player then cache[player.UserId]=nil;inflight[player.UserId]=nil end
end

return Policy
