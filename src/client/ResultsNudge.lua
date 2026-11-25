-- The results nudge and the Welcome bonus row (growth cuts 2026-11-25, GROWTH-CUTS-LOOK section 3;
-- FeatureFlags.StarterBonus). Pure (spec-checked); init.client's resultsData fills the screen's data from it.
--   Which egg: the Toy Egg while the player owns no toy (and one is left), else the Customization Egg; when that is
--   not on sale here, the Toy Egg (if a toy is left), else no line.
--   The line: "{egg}: you have enough!" (gold) or "{egg}: N more Stars" after this round's payout.
local Shared=game:GetService("ReplicatedStorage").Shared
local UICopy=require(Shared.UICopy)
local Toys=require(Shared.ToyCatalog)
local LookEgg=require(Shared.LookEggCatalog)
local Nudge={}

local function toyName()
	local ok,Models=pcall(require,Shared.EggModels)
	return if ok and type(Models)=="table"and Models.toy and Models.toy.name then Models.toy.name else "Toy Egg"
end

-- Is the Customization Egg on sale to this snapshot? (Restricted players still buy it: their next item is fixed.)
function Nudge.lookOnSale(state)
	return LookEgg.EnablePurchases==true and type(state)=="table"and state.lookAvailable~=false
end
-- {id = "toy" | "look", name, cost} or nil.
function Nudge.egg(state)
	if type(state)~="table"then return nil end
	local unlocks=if type(state.toyUnlocks)=="table"then state.toyUnlocks else {}
	local ownsToy=next(unlocks)~=nil
	local ok,left=pcall(Toys.remaining,unlocks)
	local toyLeft=ok and type(left)=="table"and #left>0
	local toy={id="toy",name=toyName(),cost=Toys.Cost}
	if not ownsToy and toyLeft then return toy end
	if Nudge.lookOnSale(state)then return{id="look",name=UICopy.get("hatch.egg.look.name"),cost=LookEgg.Price}end
	if toyLeft then return toy end
	return nil
end
-- {text, ready, short} for `egg` and the wallet after this round's payout; nil without an egg.
function Nudge.line(egg,balance)
	if type(egg)~="table"or type(egg.cost)~="number"then return nil end
	balance=if type(balance)=="number"and balance==balance then math.floor(balance)else 0
	local short=egg.cost-balance
	if short<=0 then return{text=UICopy.get("results.next.ready",{egg=egg.name}),ready=true,short=0}end
	if short==1 then return{text=UICopy.get("results.next.shortOne",{egg=egg.name}),ready=false,short=1}end
	return{text=UICopy.get("results.next.short",{egg=egg.name,count=short}),ready=false,short=short}
end
-- The payout row for a saved receipt's Welcome bonus (nil when it paid none). Goes first, in gold.
function Nudge.starterRow(reward)
	local starter=type(reward)=="table"and reward.starter
	if type(starter)~="number"or starter~=starter or starter<=0 then return nil end
	return{name=UICopy.get("results.starter.row"),amount=math.floor(starter),gold=true,starter=true}
end
-- Hatch eggs becomes the primary button: the line says "enough" in a round that paid a Welcome bonus.
function Nudge.hatchPrimary(line,reward)
	return type(line)=="table"and line.ready==true and Nudge.starterRow(reward)~=nil
end

return Nudge
