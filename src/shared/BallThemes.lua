-- Ball themes (ROUND-ITEMS-AND-BALL-THEMES-SCOPE C, batch 2026-11-13 R1). Looks
-- only: a theme changes body / shade / light colours, face ink, face style,
-- texture and size names. Radii, odds, payouts and goal meaning never change.
-- Smileys is the default; Marbles is today's glossy look with motifs (free, no
-- faces). The server reads only `price` and `ById` (BallThemeState); the client
-- renderer (JellyLCD) and the UI colour circles read the rest.
-- The first seven themes keep the hue family per size: blue, orange, green, pink, violet.
-- The six monotone themes (DECK-LAYOUT-SPEC-v834 2, `mono = true`) are one hue stepped in
-- value, smallest darkest; with one of them equipped a ball's word is its size.
local Levels=require(script.Parent.Levels)
local Themes={Default="smileys",Limit=64}
-- Bubbles (slice C, overnight 2026-11-14) is appended so the saved order of the first six never moves.
-- The six monotone themes are appended after it for the same reason.
Themes.Order={"smileys","marbles","gumdrops","gems","planets","kittens","bubbles",
 "pea_soup","pocket_grey","amber","deep_sea","bubblegum","midnight"}
-- Themes with a level gate (Levels matter, 2026-11-22): `gate` is a LevelGate gate. They are kept out
-- of Order, so the shelf, the Book and the shop read exactly what they read before; shops list
-- Themes.listed(owned). Append-only, and a gate may only be loosened.
Themes.Gated={"tangerine_pop"}
-- Icon circles step in size inside a fixed slot so colour is never the only cue
-- (scope B5/B6: blue and violet look alike without red-green vision).
Themes.CircleScale=table.freeze({.52,.64,.76,.88,1})
Themes.Glyph="●"

-- `rim` (the bounce crescent) and `spec` (the two-part glint) are optional: a ramp with them is drawn with the Aero
-- Glass bubble shading (AeroShade); themes without them render exactly as before.
local function ramp(body,deep,light,rim,spec)return table.freeze({body=body,deep=deep,light=light,rim=rim,spec=spec})end
-- "Aero Glass" (AERO-JUICE-BRIEF 1, Fable 2026-11-26; Spencer: "more frutiger aero? more pleasing?"): the default
-- ramps for Smileys and Marbles, replacing `vivid` (blue #2E8BFF, orange #FF8A1A, green #22E06A, pink #FF4DA6, violet
-- #A66BFF). Aqua, sun-gold, leaf, lotus and a darker violet: L* 70, 79, 72, 66, 50, so blue and violet no longer sit
-- 5 dE apart under deuteranopia (worst pairs now 34 deutan, 22 protan, 14 tritan; Machado, CIELAB). Pico8.TierRamps
-- carries the same five so the legacy and ghost paths match. Ink #15102B is 4.1:1 on violet, 7:1 or more elsewhere.
local aero={ramp("#22B8F2","#0B74D1","#A6ECFF","#5FE3FF","#FFFFFF"),ramp("#FFB52A","#EC7A0E","#FFEFA3","#FFD866","#FFFFFF"),
 ramp("#2FCB5A","#0E8F45","#C4FF9A","#7CF08A","#FFFFFF"),ramp("#FF6FA8","#D8327E","#FFD3E6","#FFA3C8","#FFFFFF"),
 ramp("#7D5CF0","#4426C2","#D6CBFF","#A893FF","#FFFFFF")}
Themes.Aero=aero
local colourWords={"blue","orange","green","pink","violet"}
local sizeWords={"tiny","small","medium","large","huge"}

-- face: smiley | none | happy | dots | sleepy | cat. texture: none | motif | sugar | facet | planet.
-- earsFrom: first tier that wears cat ears (nil = no ears).
Themes.ById={
 smileys={name="Smileys",tier="starter",price=0,face="smiley",texture="none",ink="#15102B",ramps=aero,
  pitch="Crude little faces. The default.",names={"Blue","Orange","Green","Pink","Violet"}},
 marbles={name="Marbles",tier="starter",price=0,face="none",texture="motif",ink="#15102B",ramps=aero,
  pitch="No faces. Glossy with a pattern each.",names={"Blue","Orange","Green","Pink","Violet"}},
 gumdrops={name="Gumdrops",tier="common",price=40,face="happy",texture="sugar",ink="#3A2350",
  ramps={ramp("#6FC2FF","#2F7FE0","#D4EEFF"),ramp("#FFB25E","#E8742A","#FFE6B8"),ramp("#6BE89C","#1FAE62","#D2FFD9"),
   ramp("#FF86BE","#DE3F8C","#FFD6EA"),ramp("#BE9BFF","#7C4BE6","#EBDDFF")},
  pitch="Pastel candy with a sugar skirt.",names={"Blueberry","Apricot","Mint","Rose","Lilac"}},
 gems={name="Gems",tier="rare",price=100,face="dots",texture="facet",ink="#0A0820",
  ramps={ramp("#2F7BFF","#0B2FB8","#A9E4FF"),ramp("#FFA21F","#C2500A","#FFE58A"),ramp("#3BE89A","#078A55","#C2FFD8"),
   ramp("#E8205F","#9A0A44","#FFB3CC"),ramp("#9A5BFF","#4A16C4","#E2CCFF")},
  pitch="Hard facets and a sparkle. Tiny eyes.",names={"Sapphire","Topaz","Emerald","Ruby","Amethyst"}},
 planets={name="Planets",tier="rare",price=100,face="sleepy",texture="planet",ink="#0F1022",
  ramps={ramp("#5F9BE8","#27509E","#C7E2FF"),ramp("#F2843A","#A83C14","#FFC98A"),ramp("#45E6B4","#0B8A72","#C6FFE8"),
   ramp("#E2508F","#96245F","#FFD0E4"),ramp("#9B6BFF","#48239E","#DCC8FF")},
  pitch="Craters, bands and a ring. They doze.",names={"Moon","Mars","Terra","Giant","Nebula"}},
 kittens={name="Kittens",tier="showcase",price=250,face="cat",texture="none",ink="#1A1228",earsFrom=2,
  ramps={ramp("#63A6F5","#2A5FC2","#CFE6FF"),ramp("#FF9A3C","#D1560F","#FFE0A8"),ramp("#4FD98A","#149A52","#CFFFD6"),
   ramp("#FF7FB6","#CC2F7C","#FFD8EA"),ramp("#A77BFF","#5A2BD0","#E6D6FF")},
  pitch="Pointed ears and a pink nose.",names={"Blue kitten","Ginger","Matcha","Sakura","Plum"}},
 -- Pale bodies with near-white lights, so they read as soap bubbles next to Gumdrops' candy.
 bubbles={name="Bubbles",tier="rare",price=100,face="dots",texture="none",ink="#2A2450",
  ramps={ramp("#8FD0FF","#4A9BE8","#F0FAFF"),ramp("#FFC48A","#F08A4A","#FFF1DC"),ramp("#9FF0C0","#3FC486","#EFFFF2"),
   ramp("#FFA8D0","#E85FA0","#FFEAF4"),ramp("#CDB0FF","#8B5FE8","#F5ECFF")},
  pitch="Soft and shiny. Two little eyes.",names={"Sky","Peach","Melon","Blossom","Violet"}},
 -- Monotone themes (DECK-LAYOUT-SPEC-v834 2): tier I darkest to tier V lightest, about
 -- 10 L* a step; the radius steps too, so no size relies on hue.
 pea_soup={name="Pea Soup",tier="common",price=40,face="smiley",texture="none",ink="#0F1A08",mono=true,
  ramps={ramp("#5F7F2A","#3F5A1A","#A8C66A"),ramp("#7A9A34","#56741F","#C2DC78"),ramp("#97B63F","#6E8F28","#D9EE8E"),
   ramp("#B5D15A","#8BAA3A","#ECF9B0"),ramp("#D6EC8A","#AFCB5E","#F7FFD6")},
  pitch="Old handheld green, dark to bright.",names={"Pea","Sprout","Leaf","Lime","Glow"}},
 pocket_grey={name="Pocket Grey",tier="common",price=40,face="dots",texture="none",ink="#14161C",mono=true,
  ramps={ramp("#6B7280","#474D59","#A3AAB6"),ramp("#8A919E","#636A78","#BFC5CF"),ramp("#A9B0BB","#808795","#D8DDE4"),
   ramp("#C8CED6","#9EA5B1","#EDF0F4"),ramp("#E8ECF0","#C0C6CF","#FFFFFF")},
  pitch="Grey pebbles. Size is the tell.",names={"Pebble","Slate","Stone","Cloud","Pearl"}},
 amber={name="Amber",tier="rare",price=100,face="happy",texture="none",ink="#2A0E04",mono=true,
  ramps={ramp("#B5541A","#7E3410","#E89A5A"),ramp("#D4701F","#A04C14","#FFB866"),ramp("#EE8F2A","#C0661A","#FFD080"),
   ramp("#FFB347","#E08A2A","#FFE3A6"),ramp("#FFD98A","#F2B85C","#FFF4D6")},
  pitch="Warm embers that glow as they grow.",names={"Ember","Rust","Flame","Honey","Spark"}},
 deep_sea={name="Deep Sea",tier="rare",price=100,face="sleepy",texture="none",ink="#081430",mono=true,
  ramps={ramp("#2F6FD0","#1B4A9E","#7FB0F5"),ramp("#4A8CE6","#2C66BE","#9CC8FF"),ramp("#6BA9F5","#4283D6","#BFDDFF"),
   ramp("#96C6FF","#6AA2EC","#DCEEFF"),ramp("#C8E2FF","#9CC4F5","#F4FAFF")},
  pitch="From the trench up to the foam.",names={"Trench","Tide","Wave","Sky","Foam"}},
 bubblegum={name="Bubblegum",tier="rare",price=100,face="happy",texture="sugar",ink="#2B0A1C",mono=true,
  ramps={ramp("#C2357A","#8A1E55","#EE86B6"),ramp("#DE5596","#AE346F","#FFA6CC"),ramp("#F27BB0","#CC548C","#FFC4DD"),
   ramp("#FFA3CB","#E87BAC","#FFDDEB"),ramp("#FFD0E4","#F5A8C8","#FFF2F7")},
  pitch="One pink, five strengths.",names={"Berry","Rose","Candy","Blush","Puff"}},
 -- Render check (v834 spec): tier I (#3A2A78) sank into the dark LCD, so the ramp is lifted
 -- one step as the spec allows (old I dropped, #A894FA added as V). Ink is white, not
 -- #F6F2FF: 3:1 or better on tiers I-IV, 2.5:1 on the lifted V.
 midnight={name="Midnight",tier="showcase",price=250,face="dots",texture="none",ink="#FFFFFF",mono=true,
  ramps={ramp("#4E3A9A","#34266E","#9280E6"),ramp("#6650BE","#48388E","#AA98F5"),ramp("#8169DC","#5E4CAE","#C2B4FF"),
   ramp("#9480EE","#7462CC","#DCD2FF"),ramp("#A894FA","#8C78E6","#EEE8FF")},
  pitch="Dark balls with glowing eyes.",names={"Dusk","Plum","Iris","Lilac","Star"}},
 -- Level-gated (Levels matter S2; Fable, artifacts/levels-2026-11-22/art.json): steps of 7 L* or more.
 tangerine_pop={name="Tangerine Pop",tier="common",price=40,face="happy",texture="none",ink="#2B0F04",mono=true,gate={stat="power",level=10},
  ramps={ramp("#D9440F","#A32E08","#FF9360"),ramp("#F05E18","#BD4210","#FFAB74"),ramp("#FF7A26","#DB5814","#FFC08C"),
   ramp("#FF9C52","#EC772C","#FFD7B0"),ramp("#FFC394","#F59E5C","#FFF0E0")},
  pitch="Juicy orange, deep to bright.",names={"Pip","Zest","Juice","Peach","Fizz"}},
}
local function seal(id,order)
 local entry=Themes.ById[id];entry.id=id;entry.order=order
 if not table.isfrozen(entry.ramps)then table.freeze(entry.ramps)end;table.freeze(entry.names)
 if entry.gate then table.freeze(entry.gate)end
 table.freeze(entry)
end
for index,id in ipairs(Themes.Order)do seal(id,index)end
for index,id in ipairs(Themes.Gated)do assert(Themes.ById[id].gate,"BallThemes: gated "..id);seal(id,#Themes.Order+index)end
table.freeze(Themes.ById);table.freeze(Themes.Order);table.freeze(Themes.Gated)
-- The ids a shop lists: Order, then the gated themes while gates are on, or that are owned.
function Themes.listed(owned)
 local list=table.clone(Themes.Order)
 for _,id in ipairs(Themes.Gated)do
  if Levels.on("gates")or(type(owned)=="table"and table.find(owned,id)~=nil)then table.insert(list,id)end
 end
 return list
end

function Themes.get(id)return Themes.ById[id]or Themes.ById[Themes.Default]end
-- Fixed Star price for a theme that is sold; nil for free or unknown ids.
function Themes.price(id)
 local entry=Themes.ById[id]
 return if entry and entry.price>0 then entry.price else nil
end
function Themes.isFree(id)local entry=Themes.ById[id];return entry~=nil and entry.price==0 end
-- owned: the saved purchase list. Free themes are always owned.
function Themes.owns(owned,id)
 if Themes.isFree(id)then return true end
 return type(owned)=="table"and table.find(owned,id)~=nil
end

-- Client presentation: the equipped theme for colour circles and words.
Themes.current=Themes.Default
function Themes.setCurrent(id)Themes.current=if Themes.ById[id]then id else Themes.Default;return Themes.current end
local function clampTier(tier)return math.clamp(math.floor(tonumber(tier)or 1),1,5)end
function Themes.ramp(tier,id)return Themes.get(id or Themes.current).ramps[clampTier(tier)]end
function Themes.color(tier,id)return Color3.fromHex(Themes.ramp(tier,id).body)end
function Themes.lightColor(tier,id)return Color3.fromHex(Themes.ramp(tier,id).light)end
-- Plain words, for screen readers and labels that cannot draw a circle. The hue
-- family is the same in every colour theme, so the word is the same too; with a
-- monotone theme (`mono`) every ball is one hue, so the word is its size.
Themes.SizeWords=sizeWords
function Themes.isMono(id)return Themes.get(id or Themes.current).mono==true end
function Themes.word(tier,id)
 if Themes.isMono(id)then return sizeWords[clampTier(tier)]end
 return colourWords[clampTier(tier)]
end
function Themes.spoken(tier)return Themes.word(tier).." ball"end
-- "a blue ball", "an orange ball".
function Themes.aBall(tier)local word=Themes.word(tier);return(if string.find(word,"^[aeiou]")then "an "else "a ")..word.." ball"end
-- Rich-text circle: the size's colour, a thin lighter ring, stepped in size.
function Themes.circleSize(tier,textSize)
 return math.max(6,math.floor((textSize or 14)*1.3*Themes.CircleScale[clampTier(tier)]+.5))
end
function Themes.circle(tier,textSize,id)
 local r=Themes.ramp(tier,id)
 return string.format('<font color="%s" size="%d"><stroke color="%s" thickness="1" transparency="0.4">%s</stroke></font>',
  r.body,Themes.circleSize(tier,textSize),r.light,Themes.Glyph)
end
-- Rich markup -> the text a label would show without rich text (for measuring).
function Themes.strip(text)
 return(string.gsub(string.gsub(text,"<[^>]*>",""),"&lt;","<"))
end

-- Quest titles hold "tier IV" as text (QuestCatalog). Drawing a circle instead
-- changes how the title is drawn, never what the quest means: no CatalogVersion bump.
local roman={I=1,II=2,III=3,IV=4,V=5}
function Themes.questText(title,textSize,plain)
 if type(title)~="string"then return title end
 local function swap(prefix,numeral)
  local tier=roman[numeral];if not tier then return nil end
  if plain then return if prefix~=""then Themes.aBall(tier)else Themes.spoken(tier)end
  return prefix..Themes.circle(tier,textSize)
 end
 title=string.gsub(title,"([Aa] )[Tt]ier (%u+)%f[%A]",swap)
 title=string.gsub(title,"()[Tt]ier (%u+)%f[%A]",function(_,numeral)return swap("",numeral)end)
 return title
end
-- Not frozen: the client sets `current` (the equipped theme) through setCurrent.
return Themes
