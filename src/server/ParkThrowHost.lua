-- Narrow shared-fetch intent boundary. Replayed acknowledgements never start a second game.
local Host={}
local function whole(n)return type(n)=="number"and n==n and n%1==0 and n>=1 and n<=2147483647 end
function Host.request(board,garden,ownerId,packet,now,refresh)
	local function reply(ok,reason,id)return {kind="parkThrow",seq=packet.seq,status=if ok then "Applied"else "Rejected",reason=reason,actionId=id}end
	if not whole(packet.seq)or packet.kind~="parkThrow"then return nil end
	if board.closing or board.mode~="Room"or not board.profile or packet.petId~=board.profile.companionId
		or packet.characterId~=(board.characterGeneration or 0)or packet.petGeneration~=(board.companionGeneration or 0)then return reply(false,"StalePet")end
	local prior=board.parkThrowReply
	if prior and packet.seq<=prior.seq then return if packet.seq==prior.seq then table.clone(prior)else reply(false,"OldRequest")end
	if now-(board.parkThrowAt or -math.huge)<3 then
		local result=reply(false,"Cooldown");board.parkThrowReply=result;return result
	end
	board.parkThrowAt=now
	if not garden.park then local result=reply(false,"Unavailable");board.parkThrowReply=result;return result end
	if refresh then refresh()end
	local actor=garden.actors[ownerId];local site=actor and actor.park and actor.park.parkId
	local members=0
	for _,pet in pairs(garden.actors)do if site and pet.park and pet.park.parkId==site then members+=1 end end
	local result
	if members>1 and now-(board.parkThrowSuccessAt or -math.huge)<6 then result=reply(false,"Cooldown")
	else
		local ok,reason=garden.park:throw(ownerId)
		result=reply(ok,if ok then nil else reason,if ok then reason else nil)
		if ok then board.parkThrowSuccessAt=now end
	end
	board.parkThrowReply=result
	return result
end
return Host
