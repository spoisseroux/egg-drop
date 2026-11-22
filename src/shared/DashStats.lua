-- Garden Dash numbers (V3-SCOPE-2026-11-21 section 4.4, slice S5). Pure data and maths, whole numbers only:
-- each stat gives 25% from level 1 to level 99 in a straight line, value = base x (1 + 0.25 x (level-1)/98),
-- held here as exact integers so the server and every client get the same bits.
--
-- Units. One tick is 10 ms. A stud is 1,960,000 units, so a hundredth of a stud ("cs", DashCourse) is 19,600.
--   stride(level)  units a tick per percent of pace: 6.0 to 7.5 studs a second at 100%
--   bar(level)     dash bar; a tick of dash costs 392, so 3.0 to 3.75 s
--   perfect(level) / clear(level)  jump windows, +/- 1/98 microseconds: 0.12 to 0.15 s and 0.30 to 0.375 s
local Stats={}

Stats.Order=table.freeze({"speed","energy","jump"})
Stats.MaxLevel=99
Stats.FunLevel=50 -- Just for Fun and Time Trial run every pet at these numbers
Stats.TickMs=10
Stats.TicksPerSecond=100
Stats.UnitsPerStud=1960000
Stats.UnitsPerCs=19600
Stats.DashTick=392

function Stats.level(value)
	if type(value)~="number"or value~=value then return 1 end
	return math.clamp(math.floor(value),1,Stats.MaxLevel)
end
local function line(base,slope)return function(level)return base+slope*(Stats.level(level)-1)end end
Stats.stride=line(1176,3)
Stats.bar=line(117600,300)
Stats.perfect=line(11760000,30000)
Stats.clear=line(29400000,75000)

-- The same values for people: studs a second, seconds of dash, seconds of window.
function Stats.speed(level)return Stats.stride(level)*100*Stats.TicksPerSecond/Stats.UnitsPerStud end
function Stats.energy(level)return Stats.bar(level)/Stats.DashTick/Stats.TicksPerSecond end
function Stats.jump(level)return Stats.perfect(level)/98000000 end
function Stats.clearWindow(level)return Stats.clear(level)/98000000 end

-- Bands by Dash level = Speed + Energy + Jump (3 to 297), named with the tier words (StatCatalog). [P]
Stats.Bands=table.freeze({
	table.freeze({id="seedling",from=3,to=29}),table.freeze({id="sprout",from=30,to=74}),
	table.freeze({id="bloom",from=75,to=149}),table.freeze({id="fullBloom",from=150,to=224}),
	table.freeze({id="starbloom",from=225,to=297}),
})
function Stats.dashLevel(levels)
	levels=if type(levels)=="table"then levels else{}
	return Stats.level(levels.speed)+Stats.level(levels.energy)+Stats.level(levels.jump)
end
function Stats.band(levels)
	local total=Stats.dashLevel(levels)
	for index,band in ipairs(Stats.Bands)do if total<=band.to then return index end end
	return #Stats.Bands
end
-- A garden pal's level in each race stat for a band: the middle of the band, split evenly. [P]
function Stats.bandMiddle(index)
	local band=Stats.Bands[math.clamp(math.floor(index),1,#Stats.Bands)]
	return (band.from+band.to)//6
end

return table.freeze(Stats)
