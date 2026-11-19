-- One dispatch owner for immediate + recovered playground commits. The durable receipt
-- proves the original completion/payment; flight identity prevents local double dispatch.
-- Analytics remains best effort: this is not crash-proof exactly-once service delivery.
local Commit={}
function Commit.finish(board,flight,nursery,options)
	if not flight or board.parkInFlight~=flight or not nursery.parkCommitted(board.nursery,flight.id)then return false end
	local receipt=nursery.parkCompletion(board.nursery,flight.id)
	board.parkPending=math.max(0,(board.parkPending or 0)-flight.count)
	-- v2 S0: the fetches this flight carried (fixed when it was built); never more than parkPending.
	board.parkFetchPending=math.min(board.parkPending,math.max(0,(board.parkFetchPending or 0)-(flight.fetches or 0)))
	board.parkInFlight=nil
	if board.folder and board.folder.Parent then board.folder:SetAttribute("ParkGamesPending",board.parkPending)end
	board.parkSavedAt=options.now()
	if receipt then
		if receipt.amount>0 and options.source then pcall(options.source,receipt.amount,receipt.balance)end
		if options.event then pcall(options.event,1)end
	end
	return true
end
return Commit
