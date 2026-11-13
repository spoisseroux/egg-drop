-- Round items, server side (BUILD-PLAN 2026-11-13 items 3, 5, 6, 7). Pure rules on
-- the host's board table so they are spec-checked without a live round:
--   board.belt     ids on the 3-slot belt (this round only, never saved)
--   board.itemSeq  accepted uses this round; an `item` request must carry it
--   board.sim.armed / board.sim.stars  live in the simulation (cleared with it)
-- The client never decides an outcome: it asks with {resetId, seq, id}.
local Items = require(game:GetService("ReplicatedStorage").Shared.RoundItems)
local Simulation = require(script.Parent.BoardSimulation)
local BoardItems = {}
BoardItems.Throttle = .1

-- Off in the Welcome round (no field), guided rounds and the player's first
-- field (no win yet; the guided rounds already cover it, kept explicit).
function BoardItems.enabled(state)
	return state.field == true and not state.guided and (state.totalWins or 0) > 0
end

function BoardItems.reset(board, enabled)
	board.belt = {}
	board.itemSeq = 0
	board.itemsOn = enabled == true
	board.lastItemAt = nil
	board.lastItemRequestAt = nil
	if board.sim then board.sim.armed = nil end
end

-- Merging a star ball: the item lands on the belt, or is lost when it is full.
function BoardItems.grant(board, id)
	if not board.itemsOn or not Items.valid(id) then return nil end
	if #board.belt >= Items.BeltSize then return "full" end
	table.insert(board.belt, id)
	return "granted"
end

function BoardItems.safeId(id)
	return if Items.valid(id) then id else nil
end

local function integer(n)
	return type(n) == "number" and n == n and n % 1 == 0 and n >= 0 and n <= 2147483647
end

-- context = { resetId = <published ResetId>, ready = <canProgress>, now = os.clock(), budget = <field budget> }
-- Returns true plus a result table, or false plus a refusal reason.
function BoardItems.request(board, packet, context)
	if type(packet) ~= "table" then return false, "Malformed" end
	-- Throttle every request, refused ones too, so a spamming client cannot drive a
	-- refusal event (and its replicated ItemEvent) every frame (code review 2026-11-13).
	if context.now then
		if board.lastItemRequestAt and context.now - board.lastItemRequestAt < BoardItems.Throttle then return false, "Throttled" end
		board.lastItemRequestAt = context.now
	end
	if not board.itemsOn then return false, "Off" end
	if board.closing or board.mode ~= "Board" or not context.ready then return false, "Unavailable" end
	if not board.round or board.round.over or board.payoutPending
		or not board.field or board.field.phase == "Complete" then return false, "NotLive" end
	if not integer(packet.resetId) or packet.resetId ~= context.resetId then return false, "Stale" end
	if not integer(packet.seq) or packet.seq ~= board.itemSeq then return false, "Stale" end
	if not Items.valid(packet.id) then return false, "Malformed" end
	local slot = table.find(board.belt, packet.id)
	if not slot then return false, "NotOnBelt" end
	if board.sim.armed then return false, "Armed" end
	local id, drops, budget = packet.id, board.sim.drops, context.budget or 24
	local result = { id = id }
	if id == "swap" then
		-- Next and Then must both be inside the 24-drop budget.
		if drops + 2 > budget or not Simulation.swapNext(board.sim) then return false, "Budget" end
	elseif id == "pop" then
		local target = Simulation.pop(board.sim)
		if not target then return false, "Empty" end
		result.position, result.eggId, result.lostStar = target.position, target.id, target.powerUp
	else
		-- Bomb and Magnet ride on the next ball, so one must still be coming.
		if drops + 1 > budget or board.field.phase ~= "Playing" then return false, "Budget" end
		board.sim.armed = id
	end
	table.remove(board.belt, slot)
	board.itemSeq += 1
	board.lastItemAt = context.now
	return true, result
end

-- Attributes the client reads. NextPowerUp / PreviewPowerUp1 / PreviewPowerUp2
-- mirror NextTier / PreviewTier1 / PreviewTier2.
function BoardItems.publish(board, folder)
	folder:SetAttribute("ItemsOn", board.itemsOn == true)
	folder:SetAttribute("ItemBelt", Items.encodeBelt(board.belt))
	folder:SetAttribute("ItemSeq", board.itemSeq or 0)
	folder:SetAttribute("ItemArmed", board.sim and board.sim.armed or "")
	for name, lookahead in pairs({ NextPowerUp = 0, PreviewPowerUp1 = 1, PreviewPowerUp2 = 2 }) do
		folder:SetAttribute(name, board.sim ~= nil and Simulation.powerUpAt(board.sim, lookahead))
	end
end

-- One presentation event at a time (granted, full, used, burst, refused); `n`
-- always changes so the client sees repeats.
function BoardItems.event(board, folder, packet)
	board.itemEventCount = (board.itemEventCount or 0) + 1
	packet.n = board.itemEventCount
	packet.resetId = folder:GetAttribute("ResetId")
	folder:SetAttribute("ItemEvent", game:GetService("HttpService"):JSONEncode(packet))
end

return BoardItems
