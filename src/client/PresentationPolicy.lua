-- Pure presentation ownership. A stale task can neither release nor mutate its successor.
local Policy = {}
Policy.__index = Policy
function Policy.canBoot(state, route)
	return (route == "initial" or route == "arrival") and state.mode == "Board"
		and not state.ended and not state.pendingHatch and not state.overlay and not state.reduced
end
function Policy.canSheetBack(state)
	return not state.coreMenu and not state.textCapture and not state.busy
end
function Policy.ownsRecap(state)
	return state.modal == true and state.recap == true and not state.busy and not state.overlay and not state.coreMenu
end
-- Navigation-only handoff for a late committed hatch; no acknowledgment or purchase.
function Policy.presentCommittedHatch(id,generation,current,closeMenu,open)
	if current.generation~=generation or current.id~=id or current.mode~="Room" or not current.ready then return false end
	closeMenu();open();return true
end
function Policy.new(read)
	return setmetatable({ read = read, epoch = 0 }, Policy)
end
function Policy:begin(toDeck, route)
	self:cancel()
	local state = self.read()
	if state.overlay or state.reduced or (toDeck and not Policy.canBoot(state, route)) then return nil end
	local token = { epoch = self.epoch, toDeck = toDeck, route = route }
	self.active = token
	return token
end
function Policy:owns(token)
	if not token or self.active ~= token or token.epoch ~= self.epoch then return false end
	local state = self.read()
	return not state.overlay and not state.reduced and (not token.toDeck or Policy.canBoot(state, token.route))
end
function Policy:finish(token)
	if not token or self.active ~= token then return false end
	self.active = nil
	return true
end
function Policy:cancel()
	self.epoch += 1
	self.active = nil
end
return Policy
