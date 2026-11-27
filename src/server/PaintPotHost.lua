-- The `potBuy` request, in order (PAINT-SHINE-DRESS-PLAN; architect review item 1). Pure over its deps, so the order
-- is a spec (PaintPotState.spec), and init.server only supplies the board's closures:
--   1. the request's own shape (InvalidPot)
--   2. a saved receipt for its id FIRST: the same request replays as Saved/AlreadySaved (charged once, never again),
--      another request reusing the id is OperationConflict; before the switch, the rate limits and Busy, so a buy
--      that already committed never reads NotReady or Throttled
--   3. the same operation still pending and the board busy or too soon: Retrying (as the Material branch)
--   4. the switch (NotReady), the 0.3 s request gap and the per-minute cap (Throttled), Busy
--   5. the command; Retrying leaves the reply waiting for its proof (publishNursery / the retry loop)
-- deps: state(), on(), samePending(quote), busy(), recent(), mark(), allow(), command() -> ok, reason, receipt,
--       publish(), reply(quote, status, reason, receipt), waiting(quote), alive()
local Pots=require(script.Parent.PaintPotState)
local Host={}
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
	local samePending=d.samePending(quote)
	if samePending and(d.busy()or d.recent())then d.reply(tag,"Retrying","Busy");return "Busy"end
	-- A switch flipped off while the same operation is still pending lets it finish (it may already have charged).
	if not samePending and not d.on()then d.reply(tag,"Rejected","NotReady");return "NotReady"end
	if d.recent()then d.reply(tag,"Rejected","Throttled");return "Throttled"end
	d.mark()
	if not samePending and not d.allow()then d.reply(tag,"Rejected","Throttled");return "Throttled"end
	if d.busy()then d.reply(tag,"Rejected","Busy");return "Busy"end
	local ok,reason,saved=d.command()
	if reason=="Retrying"then d.waiting(tag)end
	if not d.alive()then return reason end
	d.publish()
	d.reply(tag,if ok then "Saved"elseif reason=="Retrying"then "Retrying"else "Rejected",reason,saved)
	return reason
end
return Host
