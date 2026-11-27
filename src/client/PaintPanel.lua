-- Paint, Shine, Dress (PAINT-SHINE-DRESS-PLAN): the Colour tab's cards while the `paint` switch is on. Pure model;
-- HueEggView draws them with its card grid, pane and one action, as it draws today's jar cards.
--   ten swatches: the four pots (Pink, Blue, Yellow, Purple), then the six mixes as their result colour
--   per swatch: pips (count of 5; a mix counts its lower pot), the pot it needs next, that pot's count
--   action: "paint" (one hueUse), "buy" (potBuy, then hueUse once saved: two saves), or "full" (5 of 5)
--   last: Back to white (the free hueClear on this target), with HueEggView's own confirm
-- Painting keeps today's data rule: pots on one target mix (architect review, answer 2). The card preview is one more
-- of the pot the swatch needs next (HueEggView.previewAppearance), so it shows what the save will hold.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Hue=require(Shared:WaitForChild("HueCatalog"))
local Pots=require(Shared:WaitForChild("PaintPotCatalog"))
local PaintCopy=require(Shared:WaitForChild("PaintCopy"))
local Copy=require(Shared:WaitForChild("UICopy"))
local Panel={}
Panel.White="original"
local swatches=PaintCopy.swatches(Hue)
local byId={};for _,s in ipairs(swatches)do byId[s.id]=s end
Panel.Swatches=swatches
function Panel.swatch(id)return byId[id]end
local function counts(state,petId,channel)
	local row=state.petHues and state.petHues[petId]
	local c=row and row[channel]
	local out=Hue.emptyCounts()
	if type(c)=="table"then for _,h in ipairs(Hue.Order)do out[h.id]=if type(c[h.id])=="number"then c[h.id]else 0 end end
	return out
end
Panel.counts=counts
-- Pure: the pot a swatch paints next on these counts (a mix: its lower pot, ties to the first).
function Panel.next(id,c)
	local s=byId[id];if not s then return nil end
	if #s.pots==1 then return s.pots[1]end
	local a,b=s.pots[1],s.pots[2]
	return if(c[b]or 0)<(c[a]or 0)then b else a
end
function Panel.pips(id,c)
	local s=byId[id];if not s then return 0 end
	local n=5;for _,pot in ipairs(s.pots)do n=math.min(n,c[pot]or 0)end
	return n
end
function Panel.name(id)local s=byId[id];return if s then Copy.get(s.nameKey)else ""end
function Panel.potName(pot)return Copy.get("paint.potName",{colour=Copy.get("paint.pot."..pot)})end
function Panel.target(channel)return Copy.get(if channel=="secondary"then "paint.target.secondary"else "paint.target.main")end
-- Pure: one card. `ready` = nothing saving (either intent) and the pet can be edited.
function Panel.card(id,state,petId,channel,ready)
	state=state or {}
	local c=counts(state,petId,channel)
	local s=byId[id]
	if not s then return nil end
	local pot=Panel.next(id,c)
	local stock=(state.hueInventory or {})[pot]or 0
	local pips=Panel.pips(id,c)
	local wallet=state.nectar or 0
	local name,target=Panel.name(id),Panel.target(channel)
	local card={id=id,swatch=s,name=name,color=s.color,pot=pot,stock=stock,pips=pips,mix=#s.pots>1}
	card.status=if card.mix then Copy.get("paint.statusMix",{count=pips})else Copy.get("paint.status",{count=pips,stock=stock})
	if(c[pot]or 0)>=Hue.MaxDose then
		card.action="full";card.button=Copy.get("paint.full");card.enabled=false
		card.line=Copy.get("paint.fullLine",{target=target,colour=name})
	elseif stock>0 then
		card.action="paint";card.button=Copy.get("paint.paint");card.enabled=ready==true
		card.line=if card.mix then Copy.get("paint.lineMix",{colour=name,a=Panel.potName(s.pots[1]),b=Panel.potName(s.pots[2]),pot=Panel.potName(pot)})
			else Copy.get("paint.line",{target=target,count=c[pot],next=c[pot]+1})
	else
		card.action="buy";card.button=Copy.get("paint.buy",{price=Pots.Price})
		card.enabled=ready==true and wallet>=Pots.Price
		card.line=if wallet<Pots.Price then Copy.get("paint.short",{count=Pots.Price-wallet})else Copy.get("paint.buyLine",{pot=Panel.potName(pot),price=Pots.Price})
	end
	return card
end
-- Pure: every card for a target, swatches first, then Back to white.
function Panel.cards(state,petId,channel,ready)
	local out={}
	for _,s in ipairs(swatches)do table.insert(out,Panel.card(s.id,state,petId,channel,ready))end
	return out
end
-- Pure: true when the target holds any paint (Back to white has something to clear, and asks first).
function Panel.painted(state,petId,channel)
	local c=counts(state or {},petId,channel)
	for _,h in ipairs(Hue.Order)do if c[h.id]>0 then return true end end
	return false
end
-- Act on a card: paint now, or buy its pot and paint once the pot is saved. `intents` = {hue, pot}. Returns true when
-- a request went out. `still()` is checked before the chained paint (same pet and target, screen open).
function Panel.act(card,intents,petId,channel,state,still)
	if not card or not card.enabled then return false end
	local hue,pot=intents.hue,intents.pot
	local function paint()
		local pending=(hue.state or state or {}).pendingHueResult
		return hue:use(petId,channel,card.pot,if pending and pending.itemId==card.pot then pending.id else nil)
	end
	if card.action=="paint"then return paint()end
	if card.action=="buy"and pot then
		return pot:buy(card.pot,function()
			if still and not still()then return end
			if hue.pending then return end
			local inv=((hue.state or {}).hueInventory or {})[card.pot]or 0
			if inv<1 then return end
			paint()
		end)
	end
	return false
end
return Panel
