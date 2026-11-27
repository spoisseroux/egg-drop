-- The `giftEgg` request (the gift chain's Paint and Toy cranks; GiftEggs, Onboard "gifts"). The client asks when the
-- player turns the machine for a gift. Pure over its deps, so the order is a spec (GiftEggs.spec); init.server supplies
-- the board. The WelcomeGiftHost order:
--   1. the kind's record already saved: Saved AlreadyGranted with that record at once (a replay, a rejoin, another
--      server granted it; an unseen reveal still shows), before the switch
--   2. the switch (Onboard "gifts", beta and Studio only): NotReady
--   3. one loop per board (a second ask while one runs is answered Busy at once: the first loop answers the first)
--   4. up to GiftEggs.Tries attempts, GiftEggs.Gap s apart, while the board is free: grant() gives it or refuses.
--      RevealPending, Busy, Pending, Retrying and RevisionChanged wait for the next try; any other refusal (NotDue,
--      AllOwned, NotOwed, ...) answers at once. The last reason answers once the tries run out.
-- The item is HatchProgress.giftEgg's: it re-checks every rule inside UpdateAsync, so this loop can never give twice.
-- deps: saved() -> record or nil, on(), running() / setRunning(bool), alive(), free(), grant() -> ok, reason, record,
--       wait(seconds), publish(), reply(status, reason, record)
local Gifts=require(game:GetService("ReplicatedStorage").Shared.GiftEggs)
local Host={}
function Host.request(d)
	local saved=d.saved()
	if saved then d.reply("Saved","AlreadyGranted",saved);return "AlreadyGranted"end
	if not d.on()then d.reply("Rejected","NotReady");return "NotReady"end
	-- Code review: a second ask while one runs is answered Busy (its own op id), so the client asks again soon instead of
	-- waiting out its timeout; the first ask's loop still answers the first.
	if d.running()then d.reply("Rejected","Busy");return "Running"end
	d.setRunning(true)
	local reason="Busy"
	for try=1,Gifts.Tries do
		if not d.alive()then d.setRunning(false);return "Gone"end
		if d.free()then
			local ok,why,record=d.grant()
			if not d.alive()then d.setRunning(false);return "Gone"end
			if ok then
				d.publish();d.setRunning(false)
				d.reply("Saved",why or "Saved",record)
				return why or "Saved"
			end
			reason=why or "Unavailable"
			if not Gifts.Wait[reason]then d.publish();d.setRunning(false);d.reply("Rejected",reason);return reason end
		end
		if try<Gifts.Tries then d.wait(Gifts.Gap)end
	end
	d.setRunning(false)
	d.reply("Rejected",reason)
	return reason
end
return Host
