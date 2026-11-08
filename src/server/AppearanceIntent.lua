-- Bounded session protocol. Persistence confirmation is independently supplied.
local Intent = {}
function Intent.new() return {revision=0,slots={},lastAt=-math.huge,lastMalformed=-math.huge} end
local function snapshot(state,profile,slot,seq,id,status,reason)
	return {slot=slot,seq=seq,id=id,status=status,reason=reason,revision=state.revision,
		themeId=profile.theme,stickerId=profile.sticker,lastSeq=state.slots[slot] and state.slots[slot].seq or 0}
end
function Intent.request(state,profile,packet,now,usable,validate,equip)
	if type(packet)~="table" or (packet.slot~="theme" and packet.slot~="sticker")
		or type(packet.id)~="string" or #packet.id>64 or type(packet.seq)~="number"
		or packet.seq~=packet.seq or packet.seq<1 or packet.seq>2147483647 or packet.seq%1~=0 then
		if now-state.lastMalformed<.25 then return nil,false end
		state.lastMalformed=now
		return snapshot(state,profile,"",0,"","Rejected","Malformed"),false
	end
	local slot,seq,id=packet.slot,packet.seq,packet.id
	local previous=state.slots[slot]
	if previous and seq<=previous.seq then
		if seq==previous.seq and id==previous.id then return previous.result,false end
		return snapshot(state,profile,slot,seq,id,"Rejected",if seq==previous.seq then "SeqConflict" else "Stale"),false
	end
	local reason=if usable~=true then (if type(usable)=="string" then usable else "Unavailable") else validate(slot,id)
	if not reason and now-state.lastAt<.25 then
		local result=snapshot(state,profile,slot,seq,id,"Rejected","Throttled")
		result.retryAfter=math.max(0,.25-(now-state.lastAt));return result,false
	end
	local changed=false
	if not reason then
		local saved=profile.appearanceSaved
		if profile[slot]~=id or (not profile.appearanceChange and (not saved or saved[slot]~=id)) then
			local theme=if slot=="theme" then id else profile.theme
			local sticker=if slot=="sticker" then id else profile.sticker
			equip(profile,theme,sticker);state.revision+=1;changed=true
		end
		state.lastAt=now
	end
	local status=if reason then "Rejected" elseif not profile.appearanceChange and profile.appearanceSaved
		and profile.appearanceSaved[slot]==id then "Saved" else "Applied"
	local entry={seq=seq,id=id,generation=profile.appearanceGeneration or 0}
	state.slots[slot]=entry
	entry.result=snapshot(state,profile,slot,seq,id,status,reason)
	return entry.result,changed
end
function Intent.saved(state,profile,candidate)
	local results={}
	for slot,entry in pairs(state.slots)do
		if entry.result.status=="Applied" and entry.generation<=candidate.generation
			and candidate[slot]==entry.id and profile[slot]==entry.id then
			entry.result=snapshot(state,profile,slot,entry.seq,entry.id,"Saved")
			table.insert(results,entry.result)
		end
	end
	return results
end
function Intent.superseded(state,profile,candidate)
	state.revision+=1
	local results={}
	for slot,entry in pairs(state.slots)do
		if entry.result.status=="Applied" and entry.generation<=candidate.generation then
			entry.result=snapshot(state,profile,slot,entry.seq,entry.id,"Rejected","Superseded")
			table.insert(results,entry.result)
		end
	end
	return results
end
return Intent
