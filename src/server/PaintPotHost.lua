-- The `potBuy` request, in order (PAINT-SHINE-DRESS-PLAN; architect review item 1). Pure over its deps, so the order
-- is a spec (PaintPotState.spec), and init.server only supplies the board's closures.
-- Spencer, beta (38), 2026-11-27 ("we want a gacha focused game"): pots come only from the Paint Egg, so a buy is
-- refused, always (PaintPotCatalog.Sold is false). Only an answer for a buy that already committed is kept:
--   1. the request's own shape (InvalidPot)
--   2. a saved receipt for its id FIRST: the same request replays as Saved/AlreadySaved (charged once, on beta (38),
--      never again), another request reusing the id is OperationConflict
--   3. everything else: Rejected NotSold. Nothing is charged, nothing is written, the command never runs.
-- The switch, rate limits, Busy and the command (deps on, recent, allow, busy, command, ...) are never read here now:
-- a refusal costs no store write, so there is nothing to throttle.
-- deps: state(), publish(), reply(quote, status, reason, receipt); the rest is ignored.
local Pots=require(script.Parent.PaintPotState)
local Host={}
Host.Refusal="NotSold"
function Host.request(d,action,value,revision)
	local quote=Pots.quote(action,value,revision)
	local tag=if quote then {id=quote.id,action=action}
		elseif type(value)=="table"and type(value.id)=="string"and #value.id<=100 then {id=value.id,action=action}else nil
	if not quote then d.reply(tag,"Rejected","InvalidPot");return "InvalidPot"end
	local receipt,same=Pots.find(d.state(),quote)
	if receipt then
		if same then d.publish();d.reply(tag,"Saved","AlreadySaved",Pots.publicReceipt(receipt));return "AlreadySaved"end
		d.reply(tag,"Rejected","OperationConflict");return "OperationConflict"
	end
	d.reply(tag,"Rejected",Host.Refusal);return Host.Refusal
end
return Host
