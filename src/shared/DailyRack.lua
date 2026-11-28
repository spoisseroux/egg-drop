-- The daily rack: the Outfit Egg's picks (artifacts/qa-2026-11-28-rotation/ROTATION-BRIEF.md section 1, ARCH-REVIEW-ROTATION
-- changes 1-3, 5-7; Spencer: "items roll every day, one colour of an item at a time, rarer ones less likely, tap the odds
-- to preview today's items"). Pure and shared: the server grants (HatchProgress.rackEgg, RackState), the client draws
-- only the snapshot (`public.rack`) and may mirror the maths for display; it never picks from its own clock.
--
-- The day is DailyContracts.dayOf (05:00 UTC roll, the stamps' and daily quests' day), the server's clock only.
--   bases    every rig item of the pet (Bear and Bunny: 23). P = ceil(#bases / 8) days make one cycle (3).
--   today    in cycle c = floor(day / P), bases sorted by hash(c, baseId) (FNV-1a, WeeklyShelf.hash's recipe); day k of
--            the cycle deals sorted[k*8 + 1 .. k*8 + 8], the short last day wrapping to the cycle's start. Never a duplicate.
--   colour   each base's colours (the base itself, its ungated shipped recolours, its Outfit Egg rows) sorted by
--            hash(0, rowId); cycle c shows list[(c mod n) + 1]: one colour of a base at a time, the next colour next cycle.
--   sparkle  one legendary finish row a day, Sparkle[(day mod #Sparkle) + 1] (only those whose base the pet has).
--   Returns: a base deals once per cycle, so it is back within 2P - 1 = 5 days; a colour within (n + 1) P - 1 days
--   (n <= 8: 26 at worst, 23 for every base with 7 colours or fewer). The brief's "24" assumes a fixed deal position;
--   the per-cycle shuffle can move a base from a cycle's first day to its last (DailyRack.spec proves the real bound).
-- Odds (exact integers): weight common 18, uncommon 12, rare 6, epic 2 over today's picks the pet does not own (W).
--   The sparkle pick, unowned, is a flat 1%: units W of 100 W, each pick 99 w. Owned (or none today): the picks share
--   100%. Owned items leave the pool (no duplicates, ever); all picks owned = the egg rests (never a 100% sparkle).
--   That is also the daily cap: at most #picks + 1 eggs a pet a day (8 x 25 Stars + the sparkle).
-- Restricted players (PaidRandomPolicy) never roll: `next` is the first unowned pick, common first, then deal order. The
-- sparkle pick is not on the fixed path.
--
-- Switches (the ThisWeek / Onboard pattern): FeatureFlags.DailyRack is the build ceiling, open only on the beta place or
-- in Studio; each part also needs its runtime switch (ConfigService, server RackConfig; clients read the attribute):
--   DailyRack.on("rack")        daily_rack:  the Outfit Egg, `public.rack`, the Outfit gift first in the chain (missing = on)
--   DailyRack.on("lookdaily")   look_daily:  the Paint Egg's daily splash (LookEggCatalog.tables(day)) (missing = OFF)
--   DailyRack.on("looknopity")  look_nopity: no guaranteed charm (LookEggCatalog.pityDue false) (missing = OFF)
-- The two Paint switches default off: their before-live items are open (ARCH-REVIEW-ROTATION 8). Off is the game before.
-- Slice 2 (ROTATION-2-BRIEF 4, ARCH-REVIEW-ROTATION-2): three more parts, each needing daily_rack on too (missing = on):
--   DailyRack.on("toys")        rack_toys:   the Toy Colour Egg (ToySkins), toySkinWear, a pet's toy drawn in its colour
--   DailyRack.on("deck")        rack_deck:   the Deck Egg (DeckRack) and Deck style as a closet (FromDeckEgg)
--   DailyRack.on("wings")       rack_wings:  Angel Wings as the sparkle pick on days where day mod 9 == 4 (Rack.view)
-- Angel Wings (review 1, 2): an egg-only BASE (WearableCatalog.EggBases: under math.huge only, in `eggBases`, never in
-- `order`), so it is never one of the daily 8; on a wings day it replaces the sparkle pick until the pet owns it, at the
-- same flat 1%, never on the fixed path. With rack_wings off: the slice 1 schedule exactly.
local RunService=game:GetService("RunService")
local Shared=script.Parent
local Flags=require(Shared.FeatureFlags)
local Daily=require(Shared.DailyContracts)
local Wear=require(Shared.WearableCatalog)
local Variants=require(Shared.WearableVariants)
local Rack={Version=1}
local function wholeDay(day)return type(day)=="number"and day==day and day%1==0 and math.abs(day)<=1e9 end
Rack.PlaceId=107705084891479 -- Pocket Pals Beta
Rack.Eggs=table.freeze({"outfit","toycolour","deck"})
Rack.Price=25 -- [PLACEHOLDER] Stars an Outfit Egg
Rack.PerDay=8
Rack.Weights=table.freeze({common=18,uncommon=12,rare=6,epic=2}) -- [PLACEHOLDER] until played
Rack.SparkleShare=100 -- the sparkle pick is 1 / SparkleShare (a flat 1%)
Rack.RarityOrder=table.freeze({"common","uncommon","rare","epic","legendary"})
Rack.TierRarity=table.freeze({common="common",rare="rare",showcase="epic"})
Rack.Features=table.freeze({"rack","lookdaily","looknopity","toys","deck","wings"})
Rack.Attributes=table.freeze({rack="DailyRack_on",lookdaily="LookDaily_on",looknopity="LookNoPity_on",
	toys="RackToys_on",deck="RackDeck_on",wings="RackWings_on"})
Rack.Keys=table.freeze({rack="daily_rack",lookdaily="look_daily",looknopity="look_nopity",toys="rack_toys",deck="rack_deck",wings="rack_wings"})
Rack.Defaults=table.freeze({rack=true,lookdaily=false,looknopity=false,toys=true,deck=true,wings=true})
-- A part that also needs another part on (slice 2's three sit under daily_rack).
Rack.Needs=table.freeze({toys="rack",deck="rack",wings="rack"})
-- The egg each slice 2 part opens (Rack.on(Rack.EggSwitch[egg]) is the egg's switch).
Rack.EggSwitch=table.freeze({outfit="rack",toycolour="toys",deck="deck"})
-- Angel Wings' days (ROTATION-2-BRIEF 3): day mod 9 == 4, nine so it drifts through the weekdays.
Rack.WingsEvery=9
Rack.WingsDay=4
function Rack.wingsDay(day)return wholeDay(day)and day%Rack.WingsEvery==Rack.WingsDay end
local rank={};for i,r in ipairs(Rack.RarityOrder)do rank[r]=i end
Rack.rank=rank

-- FNV-1a over "salt:id" (WeeklyShelf.hash's exact-double recipe).
local function hash(salt,id)
	local text=tostring(salt)..":"..tostring(id)
	local h=2166136261
	for i=1,#text do
		h=bit32.bxor(h,string.byte(text,i))
		local low=bit32.band(h,0xFFFF)
		local high=bit32.rshift(h,16)
		h=(low*16777619+(high*16777619%65536)*65536)%4294967296
	end
	return h
end
Rack.hash=hash
Rack.wholeDay=wholeDay
-- The server day as a number (the snapshot's `rack.day`; `dailyDay` is the same day as a string).
function Rack.today(now)return tonumber(Daily.dayOf(if type(now)=="number"then now else os.time()))end
-- A request's day: a whole number or its canonical text ("20000"), else nil.
function Rack.dayArg(value)
	local n=if type(value)=="string"and tostring(tonumber(value))==value then tonumber(value)else value
	return if wholeDay(n)then n else nil
end

-- The pet's rack data, built once per pet (pure catalogue reads; every row ever, math.huge).
local cache={}
local function data(petId)
	if type(petId)~="string"then return nil end
	local found=cache[petId]
	if found~=nil then return found or nil end
	local items=Wear.forPet(petId,math.huge)
	local bases,colours,sparkle={},{},{}
	-- Egg-only bases (Angel Wings) are never one of the daily picks (architect review 1): `order` never holds them.
	local wings=nil
	for _,item in ipairs(items.eggBases or {})do
		if item.id==Wear.WingsId then wings=table.freeze({id=item.id,base=item.id,rarity="legendary",finish=item.finish,name=item.name,wings=true})end
	end
	for _,item in ipairs(items.order)do
		if not item.variant and item.egg~=true then
			table.insert(bases,item.id)
			colours[item.id]={{id=item.id,base=item.id,rarity=Rack.TierRarity[item.tier]or "common",name=item.name}}
		end
	end
	-- The sparkle picks in data order (WearableVariants.Rows), those whose base this pet has.
	for _,row in ipairs(Variants.Rows)do
		local item=items.byId[row.id]
		if row.egg==true and row.finish~=nil and item then
			table.insert(sparkle,{id=item.id,base=item.base,rarity="legendary",finish=item.finish,name=item.name})
		end
	end
	for _,item in ipairs(items.order)do
		if item.variant and colours[item.base]then
			if item.egg==true then
				-- A finish row is a sparkle pick (above), never one of a base's colours.
				if item.finish==nil then table.insert(colours[item.base],{id=item.id,base=item.base,rarity=item.rarity,name=item.name})end
			elseif item.gate==nil and item.weekly~=true then
				-- The ungated recolours already shipped join as common.
				table.insert(colours[item.base],{id=item.id,base=item.base,rarity="common",name=item.name})
			end
		end
	end
	for _,list in pairs(colours)do
		table.sort(list,function(a,b)
			local x,y=hash(0,a.id),hash(0,b.id)
			if x~=y then return x<y end
			return a.id<b.id
		end)
		for _,row in ipairs(list)do row.weight=Rack.Weights[row.rarity];table.freeze(row)end
		table.freeze(list)
	end
	for _,row in ipairs(sparkle)do table.freeze(row)end
	if #bases==0 then cache[petId]=false;return nil end
	found={bases=table.freeze(bases),colours=colours,sparkle=table.freeze(sparkle),period=math.ceil(#bases/Rack.PerDay),wings=wings}
	cache[petId]=found
	return found
end
-- Days in one deal cycle for the pet (nil for a pet with no wearables).
function Rack.period(petId)local d=data(petId);return d and d.period end
-- Every colour row of one base, in its cycle order (the base first only if it sorts first).
function Rack.colours(petId,baseId)local d=data(petId);return d and d.colours[baseId]end
function Rack.sparkles(petId)local d=data(petId);return d and d.sparkle or {}end
-- Angel Wings for this pet ({id, base, rarity="legendary", finish, name, wings=true}), or nil when its rig has no mount.
function Rack.wings(petId)local d=data(petId);return d and d.wings end
-- Every id the Outfit Egg can ever give this pet (picks and sparkle rows), for the specs and the cap check.
function Rack.pool(petId)
	local d=data(petId);local out={}
	if not d then return out end
	for _,base in ipairs(d.bases)do for _,row in ipairs(d.colours[base])do table.insert(out,row.id)end end
	for _,row in ipairs(d.sparkle)do table.insert(out,row.id)end
	if d.wings then table.insert(out,d.wings.id)end
	return out
end

-- Today's picks for the pet on `day`: rows {id, base, rarity, weight, name} in deal order (#bases < 8: every base).
function Rack.picks(petId,day)
	local d=data(petId)
	if not d or not wholeDay(day)then return {}end
	local n=#d.bases
	local cycle=day//d.period
	local k=day-cycle*d.period
	local sorted=table.clone(d.bases)
	table.sort(sorted,function(a,b)
		local x,y=hash(cycle,a),hash(cycle,b)
		if x~=y then return x<y end
		return a<b
	end)
	local out={}
	for j=0,math.min(Rack.PerDay,n)-1 do
		local base=sorted[(k*Rack.PerDay+j)%n+1]
		local list=d.colours[base]
		table.insert(out,list[cycle%#list+1])
	end
	return out
end
-- Today's sparkle pick (legendary finish row), or nil when the pet has none. The slice 1 schedule (no wings).
function Rack.sparkle(petId,day)
	local d=data(petId)
	if not d or not wholeDay(day)or #d.sparkle==0 then return nil end
	return d.sparkle[day%#d.sparkle+1]
end
-- The sparkle pick the egg deals (architect review 1): with `wings` (the rack_wings switch, frozen by the caller) on a
-- wings day, Angel Wings while the pet does not own it (`have`: an owned set); otherwise the slice 1 pick.
function Rack.sparkleFor(petId,day,have,wings)
	if wings==true and Rack.wingsDay(day)then
		local d=data(petId)
		if d and d.wings and not(type(have)=="table"and have[d.wings.id])then return d.wings end
	end
	return Rack.sparkle(petId,day)
end

-- The pool key the client sends back (architect review 2): today's unowned picks and the unowned sparkle pick.
function Rack.poolKey(unowned,sparkleId)
	return string.format("%08x",hash(table.concat(unowned,","),sparkleId or ""))
end
local function ownedSet(owned)
	local set={}
	if type(owned)=="table"then
		for key,value in pairs(owned)do
			if type(value)=="string"then set[value]=true elseif value==true and type(key)=="string"then set[key]=true end
		end
	end
	return set
end
Rack.ownedSet=ownedSet

-- The whole egg for one pet on one day. `owned`: the pet's owned list (or a set). `mode`: "random" | "fixed".
-- -> {pet, day, mode, rest, next?, total, poolKey, items = {{id, base, rarity, weight, units, percent, owned, name}},
--     sparkle = {id, base, rarity="legendary", finish, units, percent, owned, name} or nil}
-- units / total is the exact chance (integers); percent = units / total * 100 for OddsText.list. Owned rows: units 0.
-- Fixed mode: `next` alone has units 1 of total 1; the sparkle is 0 (never on the fixed path).
-- `wings` (slice 2: the rack_wings switch, frozen by the caller): Angel Wings may be the sparkle pick (Rack.sparkleFor);
-- the sparkle view then carries wings=true.
function Rack.view(petId,day,owned,mode,wings)
	mode=if mode=="fixed"then "fixed"else "random"
	local have=ownedSet(owned)
	local picks=Rack.picks(petId,day)
	local sparkle=Rack.sparkleFor(petId,day,have,wings)
	local W,unowned=0,{}
	for _,row in ipairs(picks)do if not have[row.id]then W+=row.weight;table.insert(unowned,row.id)end end
	local sparkleOpen=sparkle~=nil and not have[sparkle.id]and W>0
	local nextId=nil
	if W>0 then
		local best=nil
		for index,row in ipairs(picks)do
			if not have[row.id]and(best==nil or rank[row.rarity]<rank[picks[best].rarity])then best=index end
		end
		nextId=picks[best].id
	end
	local total
	if mode=="fixed"then total=if nextId then 1 else 0
	else total=if sparkleOpen then Rack.SparkleShare*W else W end
	local items={}
	for _,row in ipairs(picks)do
		local mine=have[row.id]==true
		local units=0
		if not mine then
			if mode=="fixed"then units=if row.id==nextId then 1 else 0
			else units=if sparkleOpen then(Rack.SparkleShare-1)*row.weight else row.weight end
		end
		table.insert(items,{id=row.id,base=row.base,rarity=row.rarity,weight=row.weight,name=row.name,owned=mine,units=units,
			percent=if total>0 then units/total*100 else 0})
	end
	local sparkleView=nil
	if sparkle then
		local units=if mode=="random"and sparkleOpen then W else 0
		sparkleView={id=sparkle.id,base=sparkle.base,rarity="legendary",finish=sparkle.finish,name=sparkle.name,owned=have[sparkle.id]==true,
			units=units,percent=if total>0 then units/total*100 else 0,wings=sparkle.wings}
	end
	return {pet=petId,day=day,mode=mode,rest=W==0,next=if mode=="fixed"then nextId else nil,total=total,
		poolKey=Rack.poolKey(unowned,if sparkleOpen then sparkle.id else nil),items=items,sparkle=sparkleView}
end
-- The roll on the exact integer units (architect review 3): `unit` in [0, 1). Fixed mode gives `next`. nil when resting.
function Rack.roll(view,unit)
	if type(view)~="table"or view.rest or view.total<=0 then return nil end
	if view.mode=="fixed"then return view.next end
	if type(unit)~="number"or unit~=unit or unit<0 or unit>=1 then return nil end
	local r=math.min(view.total-1,math.floor(unit*view.total))
	for _,row in ipairs(view.items)do
		if r<row.units then return row.id,row.rarity end
		r-=row.units
	end
	if view.sparkle and r<view.sparkle.units then return view.sparkle.id,"legendary"end
	return nil
end
-- The rarity of an id the egg gives this pet on `day` (nil when it is not on that day's egg). `wings` as Rack.view: on a
-- wings day both Angel Wings and the regular sparkle pick (dealt once the wings are owned) are that day's legendary.
function Rack.rarityOf(petId,day,id,wings)
	for _,row in ipairs(Rack.picks(petId,day))do if row.id==id then return row.rarity end end
	local s=Rack.sparkle(petId,day)
	if s and s.id==id then return "legendary"end
	local w=Rack.sparkleFor(petId,day,nil,wings)
	return if w and w.id==id then "legendary"else nil
end
-- The generic roll for any rack view (items, then an optional sparkle): Rack.roll. ToySkins and DeckRack views use it.

-- The switches.
function Rack.attribute(feature)return Rack.Attributes[feature]end
function Rack.key(feature)return Rack.Keys[feature]end
local injected=nil
local ownCeiling=nil
-- The build ceiling (flag and place): what RackConfig starts on. Worked out once per process (it never changes).
function Rack.ceiling(env)
	if env==nil and injected==nil and ownCeiling~=nil then return ownCeiling end
	local own=env==nil and injected==nil
	env=env or injected or {}
	local open=false
	if(env.flags or Flags).DailyRack==true then
		local studio=env.studio
		if studio==nil then studio=RunService:IsStudio()end
		open=(env.place or game.PlaceId)==Rack.PlaceId or studio==true
	end
	if own then ownCeiling=open end
	return open
end
-- Pure: a switch value. Anything but a boolean (missing, malformed) is the feature's shipped default.
function Rack.resolve(feature,configValue,override,ceiling)
	if Rack.Attributes[feature]==nil then return false end
	if ceiling==nil then ceiling=Rack.ceiling()end
	if not ceiling then return false end
	if type(override)=="boolean"then return override end
	if type(configValue)=="boolean"then return configValue end
	return Rack.Defaults[feature]==true
end
-- Server only (RackConfig): the resolved values every server check reads. Off until they are set.
local switches={rack=false,lookdaily=false,looknopity=false,toys=false,deck=false,wings=false}
function Rack.setSwitch(feature,value)
	if not RunService:IsServer()or switches[feature]==nil then return false end
	switches[feature]=value==true
	return true
end
function Rack.changed(feature)return workspace:GetAttributeChangedSignal(Rack.Attributes[feature or "rack"])end
-- Spec seam, refused outside Studio. env = {flags, studio, place, rack, lookdaily, looknopity, toys, deck, wings} (a part is on when its
-- key is true; missing = its default); nil clears it.
function Rack.inject(env)
	if not RunService:IsStudio()then return false end
	injected=if type(env)=="table"then table.clone(env)else nil
	return true
end
-- Is this part on right now? An unknown feature is off; a slice 2 part also needs daily_rack (Rack.Needs).
function Rack.on(feature)
	feature=feature or "rack"
	if Rack.Attributes[feature]==nil then return false end
	local needs=Rack.Needs[feature]
	if needs and not Rack.on(needs)then return false end
	if injected then
		local value=injected[feature]
		if type(value)~="boolean"then value=Rack.Defaults[feature]end
		return value==true and Rack.ceiling(injected)
	end
	if not Rack.ceiling()then return false end
	if RunService:IsServer()and switches[feature]~=true then return false end
	return workspace:GetAttribute(Rack.Attributes[feature])==true
end

return table.freeze(Rack)
