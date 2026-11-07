-- Presentation only: no transport, timers, profile mutations or inferred recovery.
local Notice={}
local neutral={Ready=true,Busy=true,Pending=true,Released=true}
local copy={
	Loading={short="Loading progress",detail="Loading your saved progress.",narrow="Loading",tiny="Load"},
	Temporary={short="Retrying load",detail="Loading saved progress. We'll retry automatically.",narrow="Load retry",tiny="Retry"},
	Unavailable={short="Retrying load",detail="Your save is unavailable. We'll retry automatically.",narrow="Load retry",tiny="Retry"},
	Locked={short="Waiting for session",detail="Waiting for your previous session to close.",narrow="Session wait",tiny="Wait"},
	Retrying={short="Retrying save",detail="Saving progress. We'll retry automatically.",narrow="Save retry",tiny="Retry"},
	SessionLost={short="Rejoin to continue",detail="Your session moved. Rejoin to continue.",narrow="Rejoin",tiny="Rejoin",terminal=true},
	InvalidData={short="Save unreadable",detail="Your saved progress could not be read.",narrow="Unreadable",tiny="Error",terminal=true},
}
for _,value in pairs(copy)do table.freeze(value)end
table.freeze(copy)
local function blocking(status)
	return type(status)=="string" and status~="" and not neutral[status]
end
function Notice.resolve(profileStatus,hatchState)
	local hatchStatus=if type(hatchState)=="table"then hatchState.status else hatchState
	local status,origin
	if copy[hatchStatus]then status,origin=hatchStatus,"hatch"
	elseif copy[profileStatus]then status,origin=profileStatus,"profile"
	elseif blocking(hatchStatus)then status,origin=hatchStatus,"hatch"
	elseif blocking(profileStatus)then status,origin=profileStatus,"profile"else return nil end
	local value=copy[status]or{short="Save unavailable",detail="Your save is unavailable.",narrow="Save unavailable",tiny="Error"}
	return table.freeze({key=origin..":"..status,code=status,origin=origin,short=value.short,detail=value.detail,
		narrow=value.narrow,tiny=value.tiny,terminal=value.terminal==true})
end
function Notice.key(value)return if value then value.key else ""end
function Notice.caption(value,fits)
	for _,caption in ipairs({value.short,value.narrow,value.tiny})do if fits(caption)then return caption end end
	return value.tiny
end
function Notice.owner(state)
	if state.native then return nil end
	if state.eggs then return "eggs"elseif state.style then return "style"elseif state.journal then return "journal"
	elseif state.menu then return "menu"elseif state.modal then return if state.recap then "recap"else "welcome"
	elseif state.focusing then return "focus"elseif state.mode=="Room"then return "roam"else return "board"end
end
return Notice
