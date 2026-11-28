-- The Hatch eggs screen's gift mode, pure (ONBOARDING-P2-BRIEF section 1, ARCH-REVIEW-P2 section 2; Onboard "gifts").
-- EggHatchView draws it; this decides it, so the rules are a spec (GiftShop.spec) without the screen.
--   mode(kind, state, order)  the gift the screen offers on this snapshot: the chain's offer, still ready in the snapshot,
--                             never given, no unseen card waiting, its tile on the list; else nil
--   route(ctx)                what the one primary press does: "latched" (an ask is out: nothing), "gift" (the gift's
--                             tile is selected: the gift ask, never a send or a buy page) or "normal" (today's press)
--   held(latch, state, now)   does an ask's latch still hold? Until the chain's done; the switch going off (no `gifts`)
--                             or Latch s with no answer lets it go
local Shop={}
Shop.Tile=table.freeze({paint="look",toy="toy",snack="stat"})
Shop.Latch=45 -- s: a latch whose done never came lets go (the chain's own ask times out at 30)
function Shop.mode(kind,state,order)
	if type(kind)~="string"or not Shop.Tile[kind]then return nil end
	local g=type(state)=="table"and state.gifts or nil
	if type(g)~="table"or g.ready~=kind or type(g.unseen)=="table"then return nil end
	if type(g.granted)=="table"and g.granted[kind]==true then return nil end
	if type(order)=="table"and not table.find(order,Shop.Tile[kind])then return nil end
	return kind
end
function Shop.route(ctx)
	if ctx.latch then return "latched"end
	if ctx.gift and not ctx.lastHatch and ctx.selected==Shop.Tile[ctx.gift]then return "gift"end
	return "normal"
end
function Shop.held(latch,state,now)
	if not latch then return false end
	if type(state)~="table"or type(state.gifts)~="table"then return false end
	return(now or 0)-(latch.at or 0)<=Shop.Latch
end
return table.freeze(Shop)
