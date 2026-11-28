-- Toy colours and the Toy Colour Egg (rotation slice 2; artifacts/qa-2026-11-28-rotation/ROTATION-2-BRIEF.md 1,
-- ARCH-REVIEW-ROTATION-2 5, 8, 9). Pure and shared: the server deals, grants and validates (RackState, HatchProgress),
-- the client draws the snapshot (`public.rack.toy`) and the colour (Toys.create(parent, id, scale, skinId)).
--
-- A skin is one colour of one toy: only the named `part` changes (seams, leaves, brass, buttons and the mint screen keep
-- theirs). The original colour is always the first swatch and is never a row. Toys still come from the Toy Egg
-- (ToyCatalog.Pools, PoolVersion, PaidOrder untouched); the egg deals colours only.
--   bases    the 6 toys; 3 a day, a cycle of 2 days: in cycle c = floor(day / 2), toys sorted by hash(c, toyId), day k
--            deals sorted[k*3 + 1 .. k*3 + 3]. A toy returns within 3 days.
--   colour   each toy's 4 skins sorted by hash(0, skinId); cycle c shows list[(c mod 4) + 1]. A colour within 9 days.
--   pool     today's picks whose toy the player owns and whose skin they do not. A pick whose toy is not owned is drawn
--            locked ("Get this toy from the Toy Egg") with 0 units. Empty pool: the egg rests. No sparkle pick.
--   odds     DailyRack.Weights (common 18, uncommon 12, rare 6, epic 2) over the pool, exact integers (Rack.roll).
--   fixed    restricted players: `next` is the first unowned, unlocked pick, common first, then deal order.
-- Save (inside the tolerant `rack` field, never part of HatchProgress.valid): rack.toy = {owned = {skinId = true},
-- worn = {toyId = skinId}}. Account-wide like toy unlocks: a toy wears one colour for every pet. At most OwnedLimit owned
-- keys; ids up to 32 chars, ^[a-z][a-z0-9_]*$; unknown keys (and unknown skin ids: a later build's) are kept. A malformed
-- rack.toy refuses only the toy actions (review 9) and is never written over.
-- Rows are append-only. Never rename or reuse an id: saves hold them.
local Shared=script.Parent
local Rack=require(Shared.DailyRack)
local Toys=require(Shared.ToyCatalog)
local Skins={Version=1,Price=15,PerDay=3,Period=2,OwnedLimit=64,IdLimit=32,Egg="toycolour"} -- [PLACEHOLDER] price
Skins.Toys=table.freeze({"ball","bone","sparkler","wobble_top","squeaky_carrot","pocket_deck"})
-- The part each toy tints (PetToyGeometry part names).
Skins.Parts=table.freeze({ball="FeltBall",bone="BoneBody",sparkler="IndigoGrip",wobble_top="TealBody",
	squeaky_carrot="CarrotBody",pocket_deck="DeckShell"})
Skins.Colours=table.freeze({
	sky={"Sky","#5CBEF5"},bubblegum={"Bubblegum","#FF86C8"},midnight={"Midnight","#2F2C7C"},gold={"Gold","#F0B429"},
	mint={"Mint","#7FE0CF"},grape={"Grape","#9B7BE8"},cherry={"Cherry","#E9574C"},rosegold={"Rose Gold","#F2A0A8"},
	butter={"Butter","#FFD86B"},snow={"Snow","#F4F6FB"},
})
Skins.Rarities=table.freeze({"common","uncommon","rare","epic"})
-- Names that do not follow "<Colour> <Toy>".
Skins.Names=table.freeze({squeaky_carrot_grape="Purple Carrot"})
do
	-- {toy, common, uncommon, rare, epic} [PLACEHOLDER] until Fable plays them.
	local table_={
		{"ball","sky","bubblegum","midnight","gold"},
		{"bone","mint","grape","midnight","gold"},
		{"sparkler","cherry","mint","grape","rosegold"},
		{"wobble_top","cherry","grape","midnight","gold"},
		{"squeaky_carrot","butter","grape","snow","gold"},
		{"pocket_deck","sky","bubblegum","midnight","gold"},
	}
	local rows={}
	for _,t in ipairs(table_)do
		for index,rarity in ipairs(Skins.Rarities)do
			local key=t[index+1];local colour=Skins.Colours[key]
			local id=t[1].."_"..key
			table.insert(rows,table.freeze({id=id,toy=t[1],part=Skins.Parts[t[1]],rarity=rarity,colour=key,
				name=Skins.Names[id]or(colour[1].." "..Toys.ById[t[1]].name),hex=colour[2],
				-- The sparkler's sparks run from the skin hex lerped 60% to white, to the skin hex (the tip stays warm).
				sparks=if t[1]=="sparkler"then true else nil}))
		end
	end
	Skins.Rows=table.freeze(rows)
end
local byId,byToy={},{}
for _,row in ipairs(Skins.Rows)do
	assert(byId[row.id]==nil and #row.id<=Skins.IdLimit and string.match(row.id,"^[a-z][a-z0-9_]*$"),"ToySkins: bad id "..row.id)
	assert(Toys.known(row.toy)and row.toy~=Toys.Default,"ToySkins: unknown toy "..row.toy)
	byId[row.id]=row
	byToy[row.toy]=byToy[row.toy]or {}
	table.insert(byToy[row.toy],row)
end
Skins.ById=table.freeze(byId)
-- Every skin id in data order (the lane C contract: Order, ById, Parts, get).
local order={};for _,row in ipairs(Skins.Rows)do table.insert(order,row.id)end
Skins.Order=table.freeze(order)
function Skins.get(id)return if type(id)=="string"then byId[id]else nil end
local hash=Rack.hash
-- Each toy's colours in cycle order: sorted by hash(0, skinId).
local cycleOrder={}
for toy,list in pairs(byToy)do
	local sorted=table.clone(list)
	table.sort(sorted,function(a,b)
		local x,y=hash(0,a.id),hash(0,b.id)
		if x~=y then return x<y end
		return a.id<b.id
	end)
	cycleOrder[toy]=table.freeze(sorted)
	table.freeze(list)
end
Skins.ByToy=table.freeze(byToy)
function Skins.colours(toyId)return cycleOrder[toyId]or {}end
function Skins.known(id)return type(id)=="string"and byId[id]~=nil end
-- A stored id's shape (the frozen rule: any build keeps an id it does not know).
local function idShape(id)return type(id)=="string"and #id>=1 and #id<=Skins.IdLimit and string.match(id,"^[a-z][a-z0-9_]*$")~=nil end
Skins.idShape=idShape

-- Today's 3 picks: rows {id, toy, part, rarity, weight, name, hex} in deal order.
function Skins.picks(day)
	if not Rack.wholeDay(day)then return {}end
	local cycle=day//Skins.Period
	local k=day-cycle*Skins.Period
	local sorted=table.clone(Skins.Toys)
	table.sort(sorted,function(a,b)
		local x,y=hash(cycle,a),hash(cycle,b)
		if x~=y then return x<y end
		return a<b
	end)
	local out={}
	local n=#sorted
	for j=0,math.min(Skins.PerDay,n)-1 do
		local toy=sorted[(k*Skins.PerDay+j)%n+1]
		local list=cycleOrder[toy]
		local row=list[cycle%#list+1]
		table.insert(out,{id=row.id,toy=row.toy,part=row.part,rarity=row.rarity,weight=Rack.Weights[row.rarity],name=row.name,hex=row.hex})
	end
	return out
end

-- The tolerant read of rack.toy (review 9): {present, broken, owned (set), worn (map), count}. Fails closed: anything
-- malformed is broken (only toy actions refuse; the rest of the rack is untouched).
function Skins.read(field)
	if field==nil then return {present=false,broken=false,owned={},worn={},count=0}end
	local broken={present=true,broken=true,owned={},worn={},count=0}
	if type(field)~="table"then return broken end
	local owned,worn,count={},{},0
	if field.owned~=nil then
		if type(field.owned)~="table"then return broken end
		for id,value in pairs(field.owned)do
			if not idShape(id)or value~=true then return broken end
			owned[id]=true;count+=1
		end
		if count>Skins.OwnedLimit then return broken end
	end
	if field.worn~=nil then
		if type(field.worn)~="table"then return broken end
		local keys=0
		for toy,id in pairs(field.worn)do
			keys+=1
			if not idShape(toy)or not idShape(id)then return broken end
		end
		if keys>Skins.OwnedLimit then return broken end
		for toy,id in pairs(field.worn)do worn[toy]=id end
	end
	return {present=true,broken=false,owned=owned,worn=worn,count=count}
end
-- The skin a toy shows (the published `toySkin`): the worn skin when it is owned, known to this build and of that toy;
-- else nil (the original colour). Never a skin the save does not own.
function Skins.shown(field,toyId)
	local view=Skins.read(field)
	if view.broken or type(toyId)~="string"then return nil end
	local id=view.worn[toyId]
	local row=id and byId[id]
	return if row and row.toy==toyId and view.owned[id]then id else nil
end

local function poolKey(unowned)return string.format("%08x",hash("toy:"..table.concat(unowned,","),""))end
Skins.poolKey=poolKey
-- The egg on one day. `unlocks`: the save's toyUnlocks; `owned`: a set of owned skin ids; `mode`: "random" | "fixed".
-- -> {day, mode, rest, next?, total, poolKey, items = {{id, toy, rarity, weight, units, percent, owned, locked, name, hex}}}
-- units / total is the exact chance; owned and locked picks have 0 units. Rack.roll rolls it.
function Skins.view(day,unlocks,owned,mode)
	mode=if mode=="fixed"then "fixed"else "random"
	local have=type(owned)=="table"and owned or {}
	local picks=Skins.picks(day)
	local W,unowned=0,{}
	local open={}
	for index,row in ipairs(picks)do
		local locked=not Toys.owns(unlocks,row.toy)
		local mine=have[row.id]==true
		open[index]=not locked and not mine
		if open[index]then W+=row.weight;table.insert(unowned,row.id)end
	end
	local nextId=nil
	if W>0 then
		local best=nil
		for index,row in ipairs(picks)do
			if open[index]and(best==nil or Rack.rank[row.rarity]<Rack.rank[picks[best].rarity])then best=index end
		end
		nextId=picks[best].id
	end
	local total=if mode=="fixed"then(if nextId then 1 else 0)else W
	local items={}
	for index,row in ipairs(picks)do
		local units=0
		if open[index]then units=if mode=="fixed"then(if row.id==nextId then 1 else 0)else row.weight end
		table.insert(items,{id=row.id,toy=row.toy,rarity=row.rarity,weight=row.weight,name=row.name,hex=row.hex,
			owned=have[row.id]==true,locked=not Toys.owns(unlocks,row.toy),units=units,percent=if total>0 then units/total*100 else 0})
	end
	return {day=day,mode=mode,rest=W==0,next=if mode=="fixed"then nextId else nil,total=total,poolKey=poolKey(unowned),items=items}
end
-- The rarity of a skin on `day`'s egg (nil when it is not dealt that day).
function Skins.rarityOf(day,id)
	for _,row in ipairs(Skins.picks(day))do if row.id==id then return row.rarity end end
	return nil
end
return table.freeze(Skins)
