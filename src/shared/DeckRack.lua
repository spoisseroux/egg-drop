-- The Deck Egg (rotation slice 2; artifacts/qa-2026-11-28-rotation/ROTATION-2-BRIEF.md 2, ARCH-REVIEW-ROTATION-2 5-7).
-- Pure and shared: the server deals and grants (RackState, HatchProgress.rackEgg "deck"), the client draws the snapshot
-- (`public.rack.deck`). It deals the plates and ball themes sold at fixed prices today: EXISTING catalogue ids, granted by
-- appending to the existing owned lists (state.faceplates, state.ballThemes.owned, 64 each), so every build accepts them.
-- No new deck field, no colour variants (a plate is a painted texture with a hand-solved palette; the plate is the colour).
--   lists    Plates (12) and Balls (11) below, in data order. Never in the egg: starters (free), the Book's plates,
--            level-goal rows (they stay at their fixed price) and backgrounds.
--   today    in cycle c = floor(day / 6), each list sorted by hash(c, id); day k deals sorted[(k*2 + j) mod n + 1],
--            j = 0, 1: 2 plates and 2 ball themes a day, the short last day wrapping. Everything returns within 11 days.
--   rarity   from the catalogue tier: common -> common, rare -> rare, showcase -> epic. No legendary (no plate moves).
--   odds     DailyRack.Weights over today's picks the player does not own, exact integers (Rack.roll). All owned: rests.
--   fixed    restricted players: `next` is the first unowned pick, common first, then deal order.
local Shared=script.Parent
local Rack=require(Shared.DailyRack)
local Plates=require(Shared.DeckThemes)
local Balls=require(Shared.BallThemes)
local Deck={Version=1,Price=60,PerDay=2,Period=6,Egg="deck"} -- [PLACEHOLDER] price
Deck.Plates=table.freeze({"aqua_pop","lime_gel","sorbet_sky","grape_soda","liquid_chrome","tidepool","aurora_glass",
	"rose_chrome","lagoon","dewy_meadow","prism_flare","night_orb"})
Deck.Balls=table.freeze({"gumdrops","pea_soup","pocket_grey","gems","planets","bubbles","amber","deep_sea","bubblegum",
	"kittens","midnight"})
Deck.TierRarity=table.freeze({common="common",rare="rare",showcase="epic"})
Deck.PlateLimit=64 -- FaceplateState.Limit (frozen)
Deck.BallLimit=Balls.Limit -- BallThemeState.Limit (frozen, 64)
local info={}
for _,id in ipairs(Deck.Plates)do
	local theme=Plates.ById[id]
	assert(theme and Plates.price(id)and theme.gate==nil and not theme.bookOnly,"DeckRack: "..id.." is not a sold plate")
	assert(Deck.TierRarity[theme.tier],"DeckRack: plate tier "..id)
	info[id]=table.freeze({id=id,kind="plate",rarity=Deck.TierRarity[theme.tier],name=theme.name,price=Plates.price(id)})
end
for _,id in ipairs(Deck.Balls)do
	local theme=Balls.ById[id]
	assert(theme and Balls.price(id)and theme.gate==nil,"DeckRack: "..id.." is not a sold ball theme")
	assert(info[id]==nil,"DeckRack: a ball theme id is a plate id: "..id)
	assert(Deck.TierRarity[theme.tier],"DeckRack: ball tier "..id)
	info[id]=table.freeze({id=id,kind="ball",rarity=Deck.TierRarity[theme.tier],name=theme.name,price=Balls.price(id)})
end
Deck.ById=table.freeze(info)
function Deck.kindOf(id)local row=type(id)=="string"and info[id];return row and row.kind or nil end
local hash=Rack.hash

local function deal(list,cycle,k)
	local sorted=table.clone(list)
	table.sort(sorted,function(a,b)
		local x,y=hash(cycle,a),hash(cycle,b)
		if x~=y then return x<y end
		return a<b
	end)
	local out={}
	for j=0,math.min(Deck.PerDay,#sorted)-1 do table.insert(out,sorted[(k*Deck.PerDay+j)%#sorted+1])end
	return out
end
-- Today's 4 picks (2 plates, then 2 ball themes): rows {id, kind, rarity, weight, name}.
function Deck.picks(day)
	if not Rack.wholeDay(day)then return {}end
	local cycle=day//Deck.Period
	local k=day-cycle*Deck.Period
	local out={}
	for _,list in ipairs({Deck.Plates,Deck.Balls})do
		for _,id in ipairs(deal(list,cycle,k))do
			local row=info[id]
			table.insert(out,{id=id,kind=row.kind,rarity=row.rarity,weight=Rack.Weights[row.rarity],name=row.name})
		end
	end
	return out
end

local function poolKey(unowned)return string.format("%08x",hash("deck:"..table.concat(unowned,","),""))end
Deck.poolKey=poolKey
-- Owned? `plates` the save's faceplates list, `balls` its ballThemes.owned list.
function Deck.owns(id,plates,balls)
	local kind=Deck.kindOf(id)
	if kind=="plate"then return type(plates)=="table"and table.find(plates,id)~=nil end
	if kind=="ball"then return Balls.owns(balls,id)end
	return false
end
-- The egg on one day. -> {day, mode, rest, next?, total, poolKey, full, items = {{id, kind, rarity, weight, units, percent,
-- owned, name}}}. `full`: either shelf is at its 64 limit (the egg refuses ShelfFull, no charge).
function Deck.view(day,plates,balls,mode)
	mode=if mode=="fixed"then "fixed"else "random"
	local picks=Deck.picks(day)
	local W,unowned,mine=0,{},{}
	for index,row in ipairs(picks)do
		mine[index]=Deck.owns(row.id,plates,balls)
		if not mine[index]then W+=row.weight;table.insert(unowned,row.id)end
	end
	local nextId=nil
	if W>0 then
		local best=nil
		for index,row in ipairs(picks)do
			if not mine[index]and(best==nil or Rack.rank[row.rarity]<Rack.rank[picks[best].rarity])then best=index end
		end
		nextId=picks[best].id
	end
	local total=if mode=="fixed"then(if nextId then 1 else 0)else W
	local items={}
	for index,row in ipairs(picks)do
		local units=0
		if not mine[index]then units=if mode=="fixed"then(if row.id==nextId then 1 else 0)else row.weight end
		table.insert(items,{id=row.id,kind=row.kind,rarity=row.rarity,weight=row.weight,name=row.name,owned=mine[index],
			units=units,percent=if total>0 then units/total*100 else 0})
	end
	local full=#(type(plates)=="table"and plates or {})>=Deck.PlateLimit or #(type(balls)=="table"and balls or {})>=Deck.BallLimit
	return {day=day,mode=mode,rest=W==0,next=if mode=="fixed"then nextId else nil,total=total,poolKey=poolKey(unowned),
		full=full,items=items}
end
function Deck.rarityOf(day,id)
	for _,row in ipairs(Deck.picks(day))do if row.id==id then return row.rarity end end
	return nil
end
return table.freeze(Deck)
