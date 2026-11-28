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
--   egg    true on the Outfit Egg rows (DailyRack, artifacts/qa-2026-11-28-rotation/ROTATION-BRIEF.md 1, architect review 6):
--          never listed for sale (listed only under math.huge, so a saved one renders and equips), never priced, never
--          gated, weekly or `from`. Only the Outfit Egg grants one. Each carries
--   rarity "common" | "uncommon" | "rare" | "epic" | "legendary" (egg rows only: rack weight, pill colour), and
--   finish optional animated finish on a legendary row ("rainbow" | "shimmer" | "sparkle"; WearableFinish draws it,
--          a still `color` everywhere else); finishHexes the two hexes a shimmer eases between.
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
-- The Outfit Egg (DailyRack; ROTATION-BRIEF 1 "Colours tonight"): four new colours on each of the 16 own-coloured bases
-- (one common, one uncommon, one rare, one epic), a colour an existing row of that base already uses skipped, then the
-- five legendary finish rows (the sparkle pick, in its daily order). [PLACEHOLDER] hexes and picks until Fable plays them.
-- Cap check (ARCH-REVIEW-ROTATION 5, corrected by ARCH-REVIEW-ROTATION-2 4): 23 bases + 24 shipped + 8 weekly + 64 + 5
-- sparkle rows + Angel Wings (WearableCatalog.EggBases) = 125 <= WearableCatalog.OwnedLimit (128), the write cap. Each new
-- This week row adds one (about 3 weeks of headroom). Loads accept up to WearableCatalog.LoadLimit (256) from this build
-- on, so a later build can raise the write cap; older builds still refuse a 129th on load (two releases to raise it).
Variants.EggColours=table.freeze({
 cherry={"Cherry","#E9574C"},sky={"Sky","#5CBEF5"},mint={"Mint","#7FE0CF"},butter={"Butter","#FFD86B"},
 grape={"Grape","#9B7BE8"},bubblegum={"Bubblegum","#FF86C8"},tangerine={"Tangerine","#F08A3C"},
 midnight={"Midnight","#2F2C7C"},snow={"Snow","#F4F6FB"},gold={"Gold","#F0B429"},rosegold={"Rose Gold","#F2A0A8"},
})
Variants.EggRarities=table.freeze({"common","uncommon","rare","epic"})
do
 -- {base, display name, common, uncommon, rare, epic, piece?}
 local bases={
  {"beanie","Pom Beanie","sky","tangerine","midnight","gold"},
  {"sunhat","Sun Hat","mint","grape","midnight","gold"},
  {"flowercrown","Flower Crown","sky","bubblegum","midnight","rosegold"}, -- Gold is the gated Golden Flower Crown
  {"partyhat","Party Hat","cherry","tangerine","midnight","gold"},
  {"tee","Stripy Tee","butter","bubblegum","snow","gold"}, -- dark base: Snow
  {"hoodie","Star Hoodie","cherry","bubblegum","snow","gold"}, -- Midnight is the gated Starbloom Hoodie
  {"beads","Pearl Beads","sky","bubblegum","midnight","gold"},
  -- [PLACEHOLDER] Fable: the bell is already gold and Rose Gold is the shipped Rose Bell Collar, so its epic is Snow.
  {"bellcollar","Bell Collar","sky","grape","midnight","snow","Neck_BellCollar_Bell"},
  {"ring","Little Hoops","sky","bubblegum","midnight","rosegold"},
  {"starstud","Star Studs","mint","grape","midnight","rosegold"},
  {"sparkle","Sparkle Eyes","sky","bubblegum","midnight","gold"},
  {"blush","Blush Stickers","cherry","grape","midnight","gold"},
  {"bowtail","Bow Tail","sky","tangerine","midnight","gold"},
  {"acorn","Acorn Pendant","cherry","grape","midnight","gold"},
  {"bands","Friendship Bands","cherry","grape","midnight","gold"},
  {"specs","Round Specs","cherry","bubblegum","midnight","rosegold"},
 }
 for _,b in ipairs(bases)do
  for index,rarity in ipairs(Variants.EggRarities)do
   local key=b[index+2];local colour=Variants.EggColours[key]
   table.insert(Variants.Rows,{id=b[1].."_"..key,base=b[1],name=colour[1].." "..b[2],color=colour[2],piece=b[7],egg=true,rarity=rarity})
  end
 end
 -- The sparkle picks (legendary, a flat 1%): `color` is the still mid colour (Reduced Motion, previews, older builds).
 for _,row in ipairs({
  {id="beanie_rainbow",base="beanie",name="Rainbow Pom Beanie",color="#F7A8D8",finish="rainbow"},
  {id="bowtail_rainbow",base="bowtail",name="Rainbow Bow Tail",color="#F7A8D8",finish="rainbow"},
  {id="hoodie_aurora",base="hoodie",name="Aurora Star Hoodie",color="#92AEF8",finish="shimmer",finishHexes={"#6FD0F0","#B58CFF"}},
  {id="partyhat_aurora",base="partyhat",name="Aurora Party Hat",color="#92AEF8",finish="shimmer",finishHexes={"#6FD0F0","#B58CFF"}},
  {id="flowercrown_stardust",base="flowercrown",name="Stardust Flower Crown",color="#F4F6FB",finish="sparkle"},
 })do
  row.egg=true;row.rarity="legendary"
  table.insert(Variants.Rows,row)
 end
end

local function hex(value)return type(value)=="string"and string.match(value,"^#%x%x%x%x%x%x$")~=nil end
Variants.Rarity=table.freeze({common=true,uncommon=true,rare=true,epic=true,legendary=true})
Variants.Finishes=table.freeze({rainbow=true,shimmer=true,sparkle=true})
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
  -- An Outfit Egg row is never sold (architect review 6): no price, `from`, gate or weekly; a rarity always, a finish
  -- only on a legendary row and every legendary row has one. Rarity and finish are egg-row fields only.
  if row.egg~=nil then
   if not(row.egg==true and row.price==nil and row.from==nil and row.gate==nil and row.weekly==nil)then return "egg "..row.id end
   if not Variants.Rarity[row.rarity]then return "rarity "..row.id end
   if(row.rarity=="legendary")~=(row.finish~=nil)then return "finish "..row.id end
   if row.finish~=nil and not Variants.Finishes[row.finish]then return "finish "..row.id end
   if row.finishHexes~=nil and not(row.finish=="shimmer"and type(row.finishHexes)=="table"and #row.finishHexes==2
    and hex(row.finishHexes[1])and hex(row.finishHexes[2]))then return "finishHexes "..row.id end
  elseif row.rarity~=nil or row.finish~=nil or row.finishHexes~=nil then return "egg fields "..row.id end
 end
 -- A variant never shadows another variant's base (no variant of a variant).
 for _,row in ipairs(rows)do if seen[row.base]then return "variant base "..row.id end end
 return nil
end
do
 local problem=Variants.problem(Variants.Rows)
 assert(problem==nil,"WearableVariants: bad row ("..tostring(problem)..")")
 for _,row in ipairs(Variants.Rows)do
  if row.gate then table.freeze(row.gate)end
  if row.finishHexes then table.freeze(row.finishHexes)end
  table.freeze(row)
 end
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
 -- An Outfit Egg row is never on sale: listed only in "every row ever" (render, equip, the Book's lookups).
 if row.egg==true then return week==math.huge end
 if row.weekly==true then return ThisWeek.listed(row.id,week)end
 if row.gate~=nil and week~=math.huge and not Gate.listed(row.gate)then return false end
 return row.from==nil or(type(week)=="number"and row.from<=week)
end
-- Rows listed in `week`, in data order, and a key naming the "This week" rows among them ("" none, "*" every one,
-- else the pick's id). The pick is asked for once per call (review B37), never once per weekly row.
function Variants.rows(week,rows)
 local result={}
 local all=week==math.huge
 local pick=if all then nil else ThisWeek.featured(week)
 local weekly=if all then "*"elseif pick then pick.id else ""
 for _,row in ipairs(rows or Variants.Rows)do
  local listed=if row.weekly==true then all or(pick~=nil and pick.id==row.id)else Variants.released(row,week)
  if listed then table.insert(result,row)end
 end
 return result,weekly
end
return table.freeze(Variants)
