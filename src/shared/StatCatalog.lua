-- Pet stats (v2, V2-SCOPE-2026-11-19 sections 2 and 3). Pure data and maths; the server
-- (StatState) stores XP per pet, never levels. Shared so the client can show levels.
--
-- Frozen at ship (saved data depends on them): the stat ids and their order (append only),
-- the XP formula, MaxLevel and MaxXP. Tunable without touching saves: every XP amount, the
-- Bonus XP size and bank, tier names.
local Catalog={}

Catalog.Order=table.freeze({"heart","power","energy","jump","speed","smarts"})
-- v2 S4: the public, read-only board attribute other players' inspect cards read (JSON from
-- StatState.publicLevels: per owned pet, the six levels, the total and the Keeper tier word).
-- Levels only: never XP, Bonus XP, Stars or anything else from the save.
Catalog.PublicAttribute="PublicStats"
Catalog.MaxLevel=99
Catalog.MaxXP=2000000
-- Display data. Names go through UICopy (stats.<id>) when shown; these are the English
-- fallbacks. Colours are fixed (the faceplate never tints them).
Catalog.ById=table.freeze({
	heart={id="heart",name="Heart",color=Color3.fromHex("#FF86A8"),icon="heart"},
	power={id="power",name="Power",color=Color3.fromHex("#FF9D4D"),icon="paw"},
	energy={id="energy",name="Energy",color=Color3.fromHex("#6CCBFF"),icon="bolt"},
	jump={id="jump",name="Jump",color=Color3.fromHex("#B9EE5A"),icon="spring"},
	speed={id="speed",name="Speed",color=Color3.fromHex("#8FA8FF"),icon="sneaker"},
	smarts={id="smarts",name="Smarts",color=Color3.fromHex("#E58CFF"),icon="bulb"},
})

-- xp(L) = floor(n^3/40 + 2n^2 + 12n), n = L-1, in exact integer form.
function Catalog.xpFor(level)
	if type(level)~="number"or level~=level then return 0 end
	level=math.clamp(math.floor(level),1,Catalog.MaxLevel)
	local n=level-1
	return (n*n*n+80*n*n+480*n)//40
end
local thresholds={}
for level=1,Catalog.MaxLevel do thresholds[level]=Catalog.xpFor(level)end
Catalog.Thresholds=table.freeze(thresholds)

-- The level an XP total has reached (1..99). Binary search over the 99 thresholds.
function Catalog.levelFor(xp)
	if type(xp)~="number"or xp~=xp or xp<=0 then return 1 end
	local lo,hi=1,Catalog.MaxLevel
	while lo<hi do
		local mid=(lo+hi+1)//2
		if thresholds[mid]<=xp then lo=mid else hi=mid-1 end
	end
	return lo
end

-- {level, xp, into = XP past this level, need = XP for the next level (0 at 99)}.
function Catalog.progress(xp)
	xp=if type(xp)=="number"and xp==xp and xp>0 then math.floor(xp)else 0
	local level=Catalog.levelFor(xp)
	if level>=Catalog.MaxLevel then return {level=level,xp=xp,into=0,need=0}end
	return {level=level,xp=xp,into=xp-thresholds[level],need=thresholds[level+1]-thresholds[level]}
end

-- Total level: the six levels added (6..594). `stats` maps stat id -> XP.
function Catalog.totalLevel(stats)
	local total=0
	for _,id in ipairs(Catalog.Order)do total+=Catalog.levelFor(type(stats)=="table"and stats[id]or 0)end
	return total
end

-- Beta 12 QA U2: a pet's top stat from its level table ({id = level}): the highest level, ties to the first in Order
-- (Heart first, so all equal is Heart). {id, level}, or nil without levels.
function Catalog.top(levels)
	if type(levels)~="table"then return nil end
	local best=nil
	for _,id in ipairs(Catalog.Order)do
		local level=levels[id]
		if type(level)=="number"and(best==nil or level>best.level)then best={id=id,level=level}end
	end
	return best
end

-- Tiers (section 3.6): per stat level, and the Keeper tier from the total level.
Catalog.Tiers=table.freeze({
	{level=1,name="Seedling",total=6},{level=25,name="Sprout",total=60},{level=50,name="Bloom",total=150},
	{level=75,name="Full Bloom",total=300},{level=99,name="Starbloom",total=450},
})
Catalog.GardenStarTotal=594
function Catalog.tier(level)
	local name=Catalog.Tiers[1].name
	for _,tier in ipairs(Catalog.Tiers)do if level>=tier.level then name=tier.name end end
	return name
end
function Catalog.keeperTier(total)
	if total>=Catalog.GardenStarTotal then return "Garden Star"end
	local name=Catalog.Tiers[1].name
	for _,tier in ipairs(Catalog.Tiers)do if total>=tier.total then name=tier.name end end
	return name.." Keeper"
end

-- Bonus XP (section 3.3): the first Daily XP in each stat each day counts double; unused
-- bonus banks for BankDays (so at most Daily*BankDays waiting).
Catalog.Bonus=table.freeze({Daily=100,BankDays=3})
Catalog.BonusMax=Catalog.Bonus.Daily*Catalog.Bonus.BankDays

-- XP per source [PLACEHOLDER numbers, section 3.3]. Wired in slice S2.
Catalog.XP=table.freeze({
	merge=1,chainLink=2,topTier=5,topClear=8,          -- Power
	round=6,winEasy=10,winMedium=15,winHard=24,tidy=6,goal=3, -- Energy
	pet=2,care=6,hello=10,roundWithPet=1,              -- Heart
	park=6,parkWithOther=3,playDate=20,                -- Jump
	fetch=5,toyBeat=3,                                 -- Speed
	questDaily=30,questWeekly=100,questAllWeekly=50,stamp=20,discovery=25,milestone=60,find=8, -- Smarts
})
-- Macro caps (section 3.3): Power per round; per-minute caps for the pet-time stats.
Catalog.Caps=table.freeze({powerPerRound=150,perMinute={heart=20,jump=20,speed=20}})

return table.freeze(Catalog)
