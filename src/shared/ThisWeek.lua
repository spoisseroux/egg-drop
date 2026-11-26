-- "This week" (Spencer 2026-11-26: "maybe this week? they'll come back, just with different colors, and rotations";
-- GARDEN-PLAY-BRIEF-2 section 8 second slice, AERO-JUICE-BRIEF section 6). One featured wardrobe recolour a week at
-- its full price (no discount, so nobody waits for one): three weeks at 60 Stars, the fourth at 150. The rows loop on
-- a stated cycle, so nothing is ever gone for good: the same base comes back every BaseEvery weeks in another colour,
-- and the very same item every Every weeks. No countdown, no "last chance". A bought item stays owned and wearable in
-- every week after (WearableCatalog lists owned weekly items in their slot tab; the save holds it like any variant).
--
-- Pure and shared: the pick is a function of the shelf week alone (Monday start, 05:00 UTC roll, the weekly quests'
-- week), so server and client pick the same item from the same week. The rows are recolour variants of existing rig
-- items (no new art); WearableVariants appends them with weekly=true, and a weekly row is listed only in its own week
-- while the switch is on (always under math.huge, so a saved one renders). They never join the weekly shelf.
--
-- Switch (the Finds pattern): FeatureFlags.ThisWeek is the build ceiling, open only on the beta place or in Studio,
-- while the runtime switch is on (ConfigService key `this_week`, server ThisWeekConfig: off until the config has loaded
-- once, then missing or malformed = on). Clients read the workspace attribute the server writes; a missing one is off.
-- Off is the game before this build: no weekly row is listed or sold anywhere.
local RunService=game:GetService("RunService")
local Flags=require(script.Parent.FeatureFlags)
local Daily=require(script.Parent.DailyContracts)
local Rotation=require(script.Parent.QuestRotation)
local ThisWeek={Version=1}
ThisWeek.PlaceId=107705084891479 -- Pocket Pals Beta
ThisWeek.Attribute="ThisWeek_on"
ThisWeek.Key="this_week"
-- The shelf week that shows row 1: week 2969 starts Monday 23 November 2026, 05:00 UTC.
ThisWeek.Anchor=2969
-- Fable's prices (GARDEN-PLAY-BRIEF-2 section 8): three weeks at 60, the fourth at 150.
ThisWeek.Price=60
ThisWeek.BigPrice=150
ThisWeek.BigEvery=4
-- The cycle, in order. Rows are append-only once shipped (saves hold the ids); a new colourway goes on the end as a
-- whole BaseEvery block, which only lengthens the cycle. Hexes from Fable's week palettes (GARDEN-PLAY-BRIEF-2
-- section 8 fruit and balloons, AERO-JUICE-BRIEF section 5 world weeks).
-- Row: { id, base, name, color, price } (the WearableVariants row shape; base is a Bear rig item with an own colour).
ThisWeek.Rows={
 {id="partyhat_plum",base="partyhat",name="Plum Party Hat",color="#B58CFF",price=60},
 {id="bands_sherbet",base="bands",name="Sherbet Friendship Bands",color="#FFB3DA",price=60},
 {id="specs_bluebell",base="specs",name="Bluebell Round Specs",color="#8FCBF5",price=60},
 {id="hoodie_lantern",base="hoodie",name="Lantern Star Hoodie",color="#F2C14E",price=150},
 {id="partyhat_berry",base="partyhat",name="Berry Party Hat",color="#FF86A8",price=60},
 {id="bands_lime",base="bands",name="Lime Friendship Bands",color="#B9EE5A",price=60},
 {id="specs_lilac",base="specs",name="Lilac Round Specs",color="#C4B5FF",price=60},
 {id="hoodie_tide",base="hoodie",name="Tide Star Hoodie",color="#6FD0F0",price=150},
}
ThisWeek.Every=#ThisWeek.Rows
-- Each base's block: the same base returns this many weeks later, in its next colour.
ThisWeek.BaseEvery=4
do
 local byId={}
 for _,row in ipairs(ThisWeek.Rows)do
  assert(byId[row.id]==nil,"ThisWeek: duplicate "..row.id)
  byId[row.id]=row
  table.freeze(row)
 end
 table.freeze(ThisWeek.Rows)
 ThisWeek.ById=table.freeze(byId)
end

-- The shelf week of a unix time / of a day number (the snapshot's `dailyDay`): WeeklyShelf's week, the quests' week.
function ThisWeek.weekOfDay(day)return Rotation.week(tonumber(day)or 0)end
function ThisWeek.week(now)return ThisWeek.weekOfDay(Daily.dayOf(if type(now)=="number"then now else os.time()))end
local function wholeWeek(week)return type(week)=="number"and week==week and week%1==0 and math.abs(week)<=1e9 end
-- Pure: the row index (1..Every) a week shows, or nil for a week that is not a whole number.
function ThisWeek.index(week)
 if not wholeWeek(week)then return nil end
 return(week-ThisWeek.Anchor)%ThisWeek.Every+1
end
-- Pure: the row a week shows, switch or not (the specs and the rotation table read it).
function ThisWeek.pick(week)
 local index=ThisWeek.index(week)
 return if index then ThisWeek.Rows[index]else nil
end
function ThisWeek.isWeekly(id)return type(id)=="string"and ThisWeek.ById[id]~=nil end
-- Pure: weeks from `week` until `id` shows again (0 when it shows that week); nil for an unknown id or a bad week.
function ThisWeek.weeksUntil(id,week)
 local row=type(id)=="string"and ThisWeek.ById[id]
 local index=ThisWeek.index(week)
 if not row or not index then return nil end
 local at=table.find(ThisWeek.Rows,row)
 return(at-index)%ThisWeek.Every
end

-- The switch.
local injected=nil
-- The build's own ceiling never changes in a process (the flag, the place, Studio): worked out once (review B37: it
-- runs on every wardrobe list, live too).
local ownCeiling=nil
function ThisWeek.ceiling(env)
 if env==nil and injected==nil and ownCeiling~=nil then return ownCeiling end
 local own=env==nil and injected==nil
 env=env or injected or {}
 local open=false
 if(env.flags or Flags).ThisWeek==true then
  local studio=env.studio
  if studio==nil then studio=RunService:IsStudio()end
  open=(env.place or game.PlaceId)==ThisWeek.PlaceId or studio==true
 end
 if own then ownCeiling=open end
 return open
end
-- Pure: a switch value. Anything but a boolean (missing, malformed) is the shipped default, on.
function ThisWeek.resolve(configValue,override,ceiling)
 if ceiling==nil then ceiling=ThisWeek.ceiling()end
 if not ceiling then return false end
 if type(override)=="boolean"then return override end
 if type(configValue)=="boolean"then return configValue end
 return true
end
-- Server only (ThisWeekConfig): the resolved value every server check reads. Off until it is set.
local switch=false
function ThisWeek.setSwitch(value)
 if not RunService:IsServer()then return false end
 switch=value==true
 return true
end
-- The published attribute, read on change (review B37), not on every list. Before the listener is up: read it.
local attribute,listening=nil,false
local function published()
 if not listening then
  listening=true
  local ok=pcall(function()
   ThisWeek.changed():Connect(function()attribute=workspace:GetAttribute(ThisWeek.Attribute)==true end)
  end)
  if ok then attribute=workspace:GetAttribute(ThisWeek.Attribute)==true end
 end
 if attribute~=nil then return attribute end
 return workspace:GetAttribute(ThisWeek.Attribute)==true
end
function ThisWeek.on()
 if injected then return injected.on~=false and ThisWeek.ceiling(injected)end
 if not ThisWeek.ceiling()then return false end
 if RunService:IsServer()and not switch then return false end
 return published()
end
function ThisWeek.changed()return workspace:GetAttributeChangedSignal(ThisWeek.Attribute)end
-- Spec seam, refused outside Studio. env = {on, flags, studio, place}; nil clears it.
function ThisWeek.inject(env)
 if not RunService:IsStudio()then return false end
 injected=if type(env)=="table"then table.clone(env)else nil
 return true
end

-- The row on sale in `week`, or nil while the switch is off (or for a bad week).
function ThisWeek.featured(week)
 if not ThisWeek.on()then return nil end
 return ThisWeek.pick(week)
end
-- Is `id` on sale in `week`? (math.huge is "every week ever": rendering and saved ids.)
function ThisWeek.listed(id,week)
 if week==math.huge then return ThisWeek.isWeekly(id)end
 local row=ThisWeek.featured(week)
 return row~=nil and row.id==id
end
return table.freeze(ThisWeek)
