-- Customization Egg (plan 2026-11-16, artifacts/qa-2026-11-16c-v775/CUSTOMIZATION-EGG-PLAN.md).
-- Pure data and rules; the server rolls, the client only displays.
--
-- Pool: four hue jars, three finish jars and the egg charm shapes the player does not own yet.
-- Odds are integer percentages per M (egg charm shapes still missing): every column sums to
-- exactly 100, so the displayed odds are the real odds (no rounding, unlike OddsText.list).
--
-- Saved-data rules (rollback floor, plan R1/R6):
--  * ItemOrder bit numbers (`lookFound`) are frozen: never renumber, only append.
--  * Stored bounds are frozen constants (MissesLimit, FoundLimit, SheenLimit, JellyLimit, Prices,
--    PoolVersions). Tunable values (PityAt, RestrictedCharmEvery, SheenStops, JellyStops, Tables,
--    Price) are never used to validate a save, so retuning them can never reject an old save.
--  * Retuning Tables or PityAt is a new PoolVersion (append it to PoolVersions). Two exceptions (ARCH-REVIEW-ROTATION
--    7, beta and Studio only): the daily splash (Catalog.tables(day), switch DailyRack "lookdaily") and no pity
--    (switch "looknopity") stay PoolVersion 1 with no new quote key. The day is a separate lookBuy request argument
--    (`lookDay`, stripped before the quote: HueState.quote) that HatchProgress checks is today (PoolChanged otherwise)
--    and rolls with. A saved quote is never checked against Tables or PityAt, so no save shape changes.
--    BEFORE LIVE (review 8, Spencer decides): how to keep the promise to players partway to a guaranteed charm (e.g.
--    grandfather them through a tolerant top-level `lookPityHold`); remove the "charm in N" (pityLeft) copy while
--    no-pity is on; review the odds text; restricted players keep RestrictedCharmEvery (fixed, not random).
--  * Prices only grows: a stored receipt keeps the price it was charged.
-- EnablePurchases=true (slice 4): on sale, but only while every finish template is NativeVerified
-- (Catalog.available); otherwise the whole egg is "Not ready" (plan R7).
local Shared=script.Parent
local Hue=require(Shared.HueCatalog)
local Charms=require(Shared.PetCharmCatalog)

local Catalog={
	PoolVersion=1,
	PoolVersions=table.freeze({[1]=true}),
	Price=12, -- [PLACEHOLDER] Stars
	Prices=table.freeze({[12]=true}),
	EnablePurchases=true,
	PityAt=15, -- [PLACEHOLDER] while charms are missing, the 15th egg after 14 misses is a charm
	RestrictedCharmEvery=12, -- [PLACEHOLDER] restricted accounts: every 12th egg is the next charm
	MissesLimit=63, -- frozen stored bound for lookCharmMisses and quote.charmMisses
	FoundLimit=1023, -- frozen stored bound for lookFound (10 item bits)
	SheenLimit=3, -- frozen stored bound: petFinish.sheen is -3..3
	JellyLimit=3, -- frozen stored bound: petFinish.jelly is 0..3
	SheenStops=3, -- [PLACEHOLDER] display and use cap (Fable's phone renders may drop it to 2)
	JellyStops=3, -- [PLACEHOLDER] display and use cap
	StackLimit=Hue.StackLimit,
	HueItems=table.freeze({"rose","tide","citrus","iris"}),
	FinishItems=table.freeze({"gloss","matte","jelly"}),
	JarOrder=table.freeze({"rose","tide","citrus","iris","gloss","matte","jelly"}),
	EggShapes=Charms.EggShapes,
	-- Published order. The index minus one is the item's frozen `lookFound` bit.
	ItemOrder=table.freeze({"rose","tide","citrus","iris","gloss","matte","jelly","charm_dot","charm_ring","charm_pebble"}),
	-- [PLACEHOLDER] percentages; keys are item ids, "charm" is each missing charm's share.
	Tables=table.freeze({
		[3]=table.freeze({rose=17,tide=17,citrus=17,iris=17,gloss=10,matte=10,jelly=6,charm=2}),
		[2]=table.freeze({rose=17,tide=17,citrus=17,iris=17,gloss=11,matte=11,jelly=6,charm=2}),
		[1]=table.freeze({rose=17,tide=17,citrus=17,iris=17,gloss=12,matte=12,jelly=6,charm=2}),
		[0]=table.freeze({rose=17,tide=17,citrus=17,iris=17,gloss=13,matte=13,jelly=6,charm=0}),
	}),
	-- Finish render templates per sheen stop (slice 3 names and verifies them with Fable).
	-- [PLACEHOLDER] names. Stop 0 is the existing Body; Jelly uses the existing Jelly pair.
	SheenProfiles=table.freeze({[-3]="BodySheenM3",[-2]="BodySheenM2",[-1]="BodySheenM1",[0]="Body",[1]="BodySheenP1",[2]="BodySheenP2",[3]="BodySheenP3"}),
	JellyProfile="BodyJelly",
	JellyTwoToneProfile="BodyTwoToneJelly",
}

local kinds,bits,shapeOf,itemOfShape={},{},{},{}
for _,id in ipairs(Catalog.HueItems)do kinds[id]="hue"end
for _,id in ipairs(Catalog.FinishItems)do kinds[id]="finish"end
for _,shape in ipairs(Catalog.EggShapes)do local id="charm_"..shape;kinds[id]="charm";shapeOf[id]=shape;itemOfShape[shape]=id end
for index,id in ipairs(Catalog.ItemOrder)do assert(kinds[id]~=nil,"LookEggCatalog: unknown item "..id);bits[id]=bit32.lshift(1,index-1)end
for id in pairs(kinds)do assert(bits[id]~=nil,"LookEggCatalog: item without a bit "..id)end
assert(#Catalog.ItemOrder<=10,"LookEggCatalog: FoundLimit covers 10 bits")
for m,row in pairs(Catalog.Tables)do
	local total=0
	for _,id in ipairs(Catalog.JarOrder)do local n=row[id];assert(type(n)=="number"and n%1==0 and n>=0,"LookEggCatalog: table "..m);total+=n end
	total+=row.charm*m
	assert(total==100,"LookEggCatalog: table "..m.." sums to "..total)
end
assert(#Catalog.EggShapes==3,"LookEggCatalog: one table per M")

local function integer(n,maximum)return type(n)=="number"and n==n and n%1==0 and n>=0 and n<=maximum end

function Catalog.kind(itemId)return if type(itemId)=="string"then kinds[itemId]else nil end
function Catalog.bit(itemId)return if type(itemId)=="string"then bits[itemId]else nil end
function Catalog.shape(itemId)return if type(itemId)=="string"then shapeOf[itemId]else nil end
function Catalog.charmItem(shape)return if type(shape)=="string"then itemOfShape[shape]else nil end
function Catalog.selectionMode(restricted)return if restricted==false then "random"else "fixed"end

-- The egg shapes not in `unlocks`, in published order (the canonical quote form).
function Catalog.missing(unlocks)
	local result={}
	for _,shape in ipairs(Catalog.EggShapes)do
		if not(type(unlocks)=="table"and unlocks[shape]==true)then table.insert(result,shape)end
	end
	return result
end
-- A list of distinct egg shapes in published order (possibly empty).
function Catalog.validMissing(list)
	if type(list)~="table"or #list>#Catalog.EggShapes then return false end
	local last=0
	for _,shape in ipairs(list)do
		local position=table.find(Catalog.EggShapes,shape)
		if not position or position<=last then return false end
		last=position
	end
	for key in pairs(list)do if type(key)~="number"or key%1~=0 or key<1 or key>#list then return false end end
	return true
end
function Catalog.validMisses(n)return integer(n,Catalog.MissesLimit)end

-- The daily splash (ROTATION-BRIEF "Paint Egg daily odds shift", switch DailyRack "lookdaily"): the four pots always
-- total their Tables share (68%); day `day` the pot Hue.RollOrder[(day mod 4) + 1] takes Splash of it and the other
-- three share the rest equally (23 / 15 / 15 / 15). Shine and charm rows never move. `day` nil: Tables exactly.
Catalog.Splash=23 -- [PLACEHOLDER] percent; the rest of the pots' share splits evenly (15 each)
local daily={}
function Catalog.splashOf(day)
	if type(day)~="number"or day~=day or day%1~=0 then return nil end
	return Hue.RollOrder[day%#Hue.RollOrder+1]
end
function Catalog.tables(day)
	local splash=Catalog.splashOf(day)
	if not splash then return Catalog.Tables end
	local found=daily[splash]
	if found then return found end
	found={}
	for m,row in pairs(Catalog.Tables)do
		local pots=0
		for _,id in ipairs(Catalog.HueItems)do pots+=row[id]end
		local rest=(pots-Catalog.Splash)/(#Catalog.HueItems-1)
		assert(rest%1==0 and rest>=0,"LookEggCatalog: the splash leaves whole percents")
		local shifted=table.clone(row)
		for _,id in ipairs(Catalog.HueItems)do shifted[id]=if id==splash then Catalog.Splash else rest end
		found[m]=table.freeze(shifted)
	end
	found=table.freeze(found)
	daily[splash]=found
	return found
end
for _,splash in ipairs(Hue.RollOrder)do
	for m,row in pairs(Catalog.tables(table.find(Hue.RollOrder,splash)-1))do
		local total=row.charm*m
		for _,id in ipairs(Catalog.JarOrder)do total+=row[id]end
		assert(total==100,"LookEggCatalog: daily table "..splash.." "..m.." sums to "..total)
	end
end

-- Odds rows in published order: {id, percent}. Charm rows only for missing shapes. `day` (optional, the lookdaily
-- switch on): that day's splash table.
function Catalog.odds(missing,day)
	if not Catalog.validMissing(missing)then return nil end
	local row=Catalog.tables(day)[#missing];local result={}
	for _,id in ipairs(Catalog.JarOrder)do table.insert(result,{id=id,percent=row[id]})end
	for _,shape in ipairs(missing)do table.insert(result,{id=itemOfShape[shape],percent=row.charm})end
	return result
end
-- True when the next random egg is a guaranteed charm (pity). `noPity` (switch DailyRack "looknopity"): never.
function Catalog.pityDue(missing,misses,noPity)
	if noPity==true then return false end
	return type(missing)=="table"and #missing>0 and type(misses)=="number"and misses>=Catalog.PityAt-1
end
-- Eggs until a charm is guaranteed (1 = the next egg), or nil when every egg charm is owned (or with `noPity`).
function Catalog.pityLeft(missing,misses,noPity)
	if noPity==true or type(missing)~="table"or #missing==0 then return nil end
	return math.max(1,Catalog.PityAt-(if Catalog.validMisses(misses)then misses else 0))
end
-- Server roll: `unit` in [0,1). Uses only the values bound into the quote, plus `options` = {day, noPity} the request
-- bound outside it (the two DailyRack Paint switches; nil = today's egg exactly). Misses still stop at MissesLimit.
function Catalog.roll(unit,missing,misses,options)
	if type(unit)~="number"or unit~=unit or unit<0 or unit>=1 or not Catalog.validMissing(missing)or not Catalog.validMisses(misses)then return nil end
	options=if type(options)=="table"then options else {}
	if Catalog.pityDue(missing,misses,options.noPity)then
		return itemOfShape[missing[math.min(#missing,math.floor(unit*#missing)+1)]]
	end
	local rows=Catalog.odds(missing,options.day);local target,cumulative=unit*100,0
	for _,row in ipairs(rows)do
		cumulative+=row.percent
		if target<cumulative then return row.id end
	end
	return rows[#rows].id -- floating-point endpoint
end
-- Restricted accounts (no roll): every RestrictedCharmEvery-th egg is the first missing shape;
-- otherwise the jar held fewest of, ties in JarOrder (as Hue.fixedNext).
function Catalog.fixedNext(missing,misses,hueInventory,finishInventory)
	if not Catalog.validMissing(missing)then return nil end
	if #missing>0 and Catalog.validMisses(misses)and misses>=Catalog.RestrictedCharmEvery-1 then return itemOfShape[missing[1]]end
	local best,count=nil,math.huge
	for _,id in ipairs(Catalog.JarOrder)do
		local stock=if kinds[id]=="hue"then hueInventory else finishInventory
		local n=if type(stock)=="table"and type(stock[id])=="number"then stock[id]else 0
		if n<Catalog.StackLimit and n<count then best,count=id,n end
	end
	return best or(if #missing>0 then itemOfShape[missing[1]]else nil)
end

-- Finish rows: {sheen=-3..3, jelly=0..3} (frozen stored bounds).
function Catalog.validFinish(row)
	if type(row)~="table"then return false end
	for key in pairs(row)do if key~="sheen"and key~="jelly"then return false end end
	local s,j=row.sheen,row.jelly
	return type(s)=="number"and s==s and s%1==0 and s>=-Catalog.SheenLimit and s<=Catalog.SheenLimit and integer(j,Catalog.JellyLimit)
end
-- One jar on a finish row with the use caps `sheenCap`/`jellyCap` (default: the current
-- stops). Out-of-cap stored values clamp first. Returns the new row, or nil and the refusal.
function Catalog.step(row,itemId,sheenCap,jellyCap)
	if not Catalog.validFinish(row)then return nil,"FinishChanged"end
	sheenCap=sheenCap or Catalog.SheenStops;jellyCap=jellyCap or Catalog.JellyStops
	local sheen=math.clamp(row.sheen,-sheenCap,sheenCap);local jelly=math.min(row.jelly,jellyCap)
	if itemId=="gloss"then
		if sheen>=sheenCap then return nil,"MaxSheen"end
		return {sheen=sheen+1,jelly=row.jelly}
	elseif itemId=="matte"then
		if sheen<=-sheenCap then return nil,"MaxSheen"end
		return {sheen=sheen-1,jelly=row.jelly}
	elseif itemId=="jelly"then
		if jelly>=jellyCap then return nil,"MaxJelly"end
		return {sheen=row.sheen,jelly=jelly+1}
	end
	return nil,"InvalidItem"
end
-- True when `after` is one jar of `itemId` on `before` under any cap a build may have used.
function Catalog.stepValid(before,after,itemId)
	if not Catalog.validFinish(before)or not Catalog.validFinish(after)then return false end
	for sheenCap=1,Catalog.SheenLimit do
		for jellyCap=1,Catalog.JellyLimit do
			local expected=Catalog.step(before,itemId,sheenCap,jellyCap)
			if expected and expected.sheen==after.sheen and expected.jelly==after.jelly then return true end
		end
	end
	return false
end

-- Template capability (as MaterialCatalog.capable): every sheen stop within the display cap and
-- the Jelly pair is a NativeVerified SurfaceAppearance, one-tone and two-tone.
local function verified(pack,name)
	if not pack then return false end
	for _,entry in ipairs(pack:GetChildren())do
		if entry.Name==name and entry:IsA("SurfaceAppearance")and entry:GetAttribute("NativeVerified")==true and entry:GetAttribute("MaterialVersion")==1 and entry:GetAttribute("MaterialProfile")==name then return true end
	end
	return false
end
function Catalog.capable(pack,twoTonePack)
	if not pack or not twoTonePack then return false end
	for stop=-Catalog.SheenStops,Catalog.SheenStops do
		local profile=Catalog.SheenProfiles[stop]
		if stop~=0 then
			if not verified(pack,profile)or not verified(twoTonePack,"BodyTwoTone"..string.sub(profile,5))then return false end
		end
	end
	return verified(pack,Catalog.JellyProfile)and verified(twoTonePack,Catalog.JellyTwoToneProfile)
end
-- The whole egg sells only when switched on and every template is verified (plan R7): finishes
-- are never silently dropped from the pool, which would change the disclosed odds.
function Catalog.available(pack,twoTonePack)
	return Catalog.EnablePurchases==true and Catalog.capable(pack,twoTonePack)
end

return table.freeze(Catalog)
