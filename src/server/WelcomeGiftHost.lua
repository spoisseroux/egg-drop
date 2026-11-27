-- The `welcomeGift` request (ONBOARDING-V3-BRIEF section 3; Spencer OK'd it 2026-11-27): the client asks once when
-- "You're all set!" shows. Pure over its deps, so the order is a spec (WelcomeGift.spec); init.server supplies the board.
--   1. already paid on this save: Saved AlreadyGranted at once (a replay, a rejoin, another server paid it); before
--      the switch, so a gift already paid never reads NotReady
--   2. the switch (Onboard "allset2", beta and Studio only): NotReady
--   3. one loop per board (a second ask while one runs is dropped: the first answers)
--   4. up to WelcomeGift.Tries attempts, WelcomeGift.Gap s apart, while the board is free: grant() pays it or refuses.
--      NotDone, Busy, Pending, Retrying and RevisionChanged wait for the next try (the guide's facts or the save may
--      still be on their way); any other refusal (NotOwed, Veteran, BalanceLimit, ...) answers at once. The last
--      reason answers once the tries run out.
-- The money is HatchProgress.welcomeGift's: it re-checks every rule inside UpdateAsync, so this loop can never pay twice.
-- deps: paid(), on(), running() / setRunning(bool), alive(), free() (no other save in flight), grant() -> ok, reason,
--       wait(seconds), publish(), reply(status, reason, stars)
local Gift=require(game:GetService("ReplicatedStorage").Shared.WelcomeGift)
local Host={}
function Host.request(d)
	if d.paid()then d.reply("Saved","AlreadyGranted",Gift.Bonus);return "AlreadyGranted"end
	if not d.on()then d.reply("Rejected","NotReady");return "NotReady"end
	if d.running()then return "Running"end
	d.setRunning(true)
	local reason="Busy"
	for try=1,Gift.Tries do
		if not d.alive()then d.setRunning(false);return "Gone"end
		if d.free()then
			local ok,why=d.grant()
			if not d.alive()then d.setRunning(false);return "Gone"end
			if ok then
				d.publish();d.setRunning(false)
				d.reply("Saved",why or "Saved",Gift.Bonus)
				return why or "Saved"
			end
			reason=why or "Unavailable"
			if not Gift.Wait[reason]then d.publish();d.setRunning(false);d.reply("Rejected",reason);return reason end
		end
		if try<Gift.Tries then d.wait(Gift.Gap)end
	end
	d.setRunning(false)
	d.reply("Rejected",reason)
	return reason
end
return Host
