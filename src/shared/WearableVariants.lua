-- Recolour variants of existing wearables (overnight 2026-11-14, slice B; SYSTEMS-SCOPE 2,
-- VISUAL-BRIEF 1 "Recolour variants"). A variant is its own item id: the save stores it like
-- any other item, and it renders the base item's meshes with one colour override.
--
-- Row: { id, base, name, color, price?, from?, piece?, gate? }
--   base   the base item id on a rig (a pet without that base sells no variant of it)
--   color  the new hex for the base's main own colour
--   price  optional; defaults to the base item's price
--   from   optional week number (WearableVariants.week): the row is listed from that week
--          on, so a later variant can ship ahead and unlock on its own with no server state
--   piece  optional attachment name: recolour only that piece. Without it, every piece
--          whose own colour equals the base's main own colour is recoloured (trim stays
--          secondary). Bell Collar's main piece is the secondary band, so its rows name the bell.
--   gate   optional level gate (LevelGate): {stat, level} or {total}. A gated row is listed only
--          while Levels.on("gates"); a saved id always renders (forPet with math.huge). It never
--          joins the weekly shelf. Append-only, and a gate may only be loosened.
--   weekly true on the "This week" rows (ThisWeek.Rows, appended below): listed only in the week ThisWeek
--          picks it while that switch is on (always under math.huge, so a saved one renders). Never on the shelf.
-- Rows are append-only. Never rename or reuse an id: saves hold them.
local Shared=script.Parent
local Daily=require(Shared.DailyContracts)
local Rotation=require(Shared.QuestRotation)
local Gate=require(Shared.LevelGate)
local ThisWeek=require(Shared.ThisWeek)
local Variants={Version=1,IdLimit=32}

Variants.Rows={
 {id="beanie_mint",base="beanie",name="Mint Pom Beanie",color="#7FE0CF"},
 {id="beanie_butter",base="beanie",name="Butter Pom Beanie",color="#FFD86B"},
 {id="beanie_grape",base="beanie",name="Grape Pom Beanie",color="#9B7BE8"},
 {id="tee_berry",base="tee",name="Berry Stripy Tee",color="#D94A7A"},
 {id="tee_forest",base="tee",name="Forest Stripy Tee",color="#3F8F6B"},
 {id="tee_tangerine",base="tee",name="Tangerine Stripy Tee",color="#F08A3C"},
 {id="bellcollar_silver",base="bellcollar",name="Silver Bell Collar",color="#DCE3EE",piece="Neck_BellCollar_Bell"},
 {id="bellcollar_rose",base="bellcollar",name="Rose Bell Collar",color="#F2A0A8",piece="Neck_BellCollar_Bell"},
 {id="sunhat_cocoa",base="sunhat",name="Cocoa Sun Hat",color="#A9764F"},
 {id="sunhat_peach",base="sunhat",name="Peach Sun Hat",color="#FFB38A"},
 -- Levels matter (V3-LEVELS-BUILD-PLAN-2026-11-22 S2): 14 gated recolours in the stat's colour family
 -- (hexes: Fable, artifacts/levels-2026-11-22/art.json).
 {id="specs_orchid",base="specs",name="Orchid Round Specs",color="#B45CE6",gate={stat="smarts",level=10}},
 {id="beanie_rose",base="beanie",name="Rose Pom Beanie",color="#EC4F8F",gate={stat="heart",level=15}},
 {id="tee_sky",base="tee",name="Sky Stripy Tee",color="#35B4F2",gate={stat="energy",level=15}},
 {id="partyhat_lime",base="partyhat",name="Lime Party Hat",color="#93D62E",gate={stat="jump",level=15}},
 {id="tee_periwinkle",base="tee",name="Periwinkle Stripy Tee",color="#8A82F0",gate={stat="speed",level=15}},
 {id="bands_tangerine",base="bands",name="Tangerine Friendship Bands",color="#FF8A2E",gate={stat="power",level=20}},
 {id="beads_orchid",base="beads",name="Orchid Pearl Beads",color="#CF8DF2",gate={stat="smarts",level=20}},
 {id="bellcollar_blossom",base="bellcollar",name="Blossom Bell Collar",color="#FF5C93",piece="Neck_BellCollar_Bell",gate={stat="heart",level=30}},
 {id="beanie_lime",base="beanie",name="Lime Pom Beanie",color="#A4D93A",gate={stat="jump",level=30}},
 {id="bowtail_periwinkle",base="bowtail",name="Periwinkle Bow Tail",color="#7F92F5",gate={stat="speed",level=30}},
 {id="blush_peach",base="blush",name="Peach Blush Stickers",color="#FF8748",gate={stat="power",level=35}},
 {id="sunhat_sky",base="sunhat",name="Sky Sun Hat",color="#5CBEF5",gate={stat="energy",level=35}},
 {id="hoodie_starbloom",base="hoodie",name="Starbloom Hoodie",color="#2F2C7C",gate={total=150}},
 {id="flowercrown_golden",base="flowercrown",name="Golden Flower Crown",color="#F0B429",gate={total=300}},
}
-- "This week" (ThisWeek): one featured recolour a week, in ThisWeek's cycle order, after every row above.
for _,row in ipairs(ThisWeek.Rows)do
 table.insert(Variants.Rows,{id=row.id,base=row.base,name=row.name,color=row.color,price=row.price,weekly=true})
end

local function hex(value)return type(value)=="string"and string.match(value,"^#%x%x%x%x%x%x$")~=nil end
-- Pure row check (the spec feeds it bad rows): nil when the list is fine, else the reason.
function Variants.problem(rows)
 local seen={}
 if type(rows)~="table"then return "rows"end
 for index,row in ipairs(rows)do
  if type(row)~="table"then return "row "..index end
  if type(row.id)~="string"or #row.id<1 or #row.id>Variants.IdLimit or not string.match(row.id,"^[a-z][a-z0-9_]*$")then return "id "..index end
  if seen[row.id]then return "duplicate "..row.id end;seen[row.id]=true
  if type(row.base)~="string"or #row.base<1 or row.base==row.id then return "base "..row.id end
  if type(row.name)~="string"or #row.name<1 then return "name "..row.id end
  if not hex(row.color)then return "color "..row.id end
  if row.price~=nil and not(type(row.price)=="number"and row.price%1==0 and row.price>0)then return "price "..row.id end
  if row.from~=nil and not(type(row.from)=="number"and row.from%1==0 and row.from>=0)then return "from "..row.id end
  if row.piece~=nil and(type(row.piece)~="string"or #row.piece<1)then return "piece "..row.id end
  if row.gate~=nil and not Gate.valid(row.gate)then return "gate "..row.id end
  -- A weekly row is sold at its own stated price, ungated and with no `from` (ThisWeek decides its weeks).
  if row.weekly~=nil and not(row.weekly==true and row.price~=nil and row.gate==nil and row.from==nil)then return "weekly "..row.id end
 end
 -- A variant never shadows another variant's base (no variant of a variant).
 for _,row in ipairs(rows)do if seen[row.base]then return "variant base "..row.id end end
 return nil
end
do
 local problem=Variants.problem(Variants.Rows)
 assert(problem==nil,"WearableVariants: bad row ("..tostring(problem)..")")
 for _,row in ipairs(Variants.Rows)do if row.gate then table.freeze(row.gate)end;table.freeze(row)end
 table.freeze(Variants.Rows)
end
local byId={};for _,row in ipairs(Variants.Rows)do byId[row.id]=row end
Variants.ById=table.freeze(byId)

-- The shared week number: Monday start, rolling at 05:00 UTC with the weekly quests.
function Variants.week(now)
 return Rotation.week(tonumber(Daily.dayOf(if type(now)=="number"then now else os.time())))
end
-- math.huge is "every row ever": rendering, saved items and the Book read it, gated or not.
function Variants.released(row,week)
 if row.weekly==true then return ThisWeek.listed(row.id,week)end
 if row.gate~=nil and week~=math.huge and not Gate.listed(row.gate)then return false end
 return row.from==nil or(type(week)=="number"and row.from<=week)
end
-- Rows listed in `week`, in data order.
function Variants.rows(week,rows)
 local result={}
 for _,row in ipairs(rows or Variants.Rows)do if Variants.released(row,week)then table.insert(result,row)end end
 return result
end
return table.freeze(Variants)
