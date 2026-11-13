-- Ball themes (ROUND-ITEMS-AND-BALL-THEMES-SCOPE C, batch 2026-11-13 R1). Looks
-- only: a theme changes body / shade / light colours, face ink, face style,
-- texture and size names. Radii, odds, payouts and goal meaning never change.
-- Smileys is the default; Marbles is today's glossy look with motifs (free, no
-- faces). The server reads only `price` and `ById` (BallThemeState); the client
-- renderer (JellyLCD) and the UI colour circles read the rest.
-- Every theme keeps the hue family per size: blue, orange, green, pink, violet.
local Themes={Default="smileys",Limit=64}
Themes.Order={"smileys","marbles","gumdrops","gems","planets","kittens"}
-- Icon circles step in size inside a fixed slot so colour is never the only cue
-- (scope B5/B6: blue and violet look alike without red-green vision).
Themes.CircleScale=table.freeze({.52,.64,.76,.88,1})
Themes.Glyph="●"

local function ramp(body,deep,light)return table.freeze({body=body,deep=deep,light=light})end
local vivid={ramp("#2E8BFF","#0A3FD6","#8FE1FF"),ramp("#FF8A1A","#E0400A","#FFD45C"),ramp("#22E06A","#04963F","#B4FF7A"),
 ramp("#FF4DA6","#C4126F","#FFB0DC"),ramp("#A66BFF","#5B21D6","#E3C8FF")}
local colourWords={"blue","orange","green","pink","violet"}

-- face: smiley | none | happy | dots | sleepy | cat. texture: none | motif | sugar | facet | planet.
-- earsFrom: first tier that wears cat ears (nil = no ears).
Themes.ById={
 smileys={name="Smileys",tier="starter",price=0,face="smiley",texture="none",ink="#15102B",ramps=vivid,
  pitch="Crude little faces. The default.",names={"Blue","Orange","Green","Pink","Violet"}},
 marbles={name="Marbles",tier="starter",price=0,face="none",texture="motif",ink="#15102B",ramps=vivid,
  pitch="No faces. Glossy with a pattern each.",names={"Blue","Orange","Green","Pink","Violet"}},
 gumdrops={name="Gumdrops",tier="common",price=20,face="happy",texture="sugar",ink="#3A2350",
  ramps={ramp("#6FC2FF","#2F7FE0","#D4EEFF"),ramp("#FFB25E","#E8742A","#FFE6B8"),ramp("#6BE89C","#1FAE62","#D2FFD9"),
   ramp("#FF86BE","#DE3F8C","#FFD6EA"),ramp("#BE9BFF","#7C4BE6","#EBDDFF")},
  pitch="Pastel candy with a sugar skirt.",names={"Blueberry","Apricot","Mint","Rose","Lilac"}},
 gems={name="Gems",tier="rare",price=40,face="dots",texture="facet",ink="#0A0820",
  ramps={ramp("#2F7BFF","#0B2FB8","#A9E4FF"),ramp("#FFA21F","#C2500A","#FFE58A"),ramp("#3BE89A","#078A55","#C2FFD8"),
   ramp("#E8205F","#9A0A44","#FFB3CC"),ramp("#9A5BFF","#4A16C4","#E2CCFF")},
  pitch="Hard facets and a sparkle. Tiny eyes.",names={"Sapphire","Topaz","Emerald","Ruby","Amethyst"}},
 planets={name="Planets",tier="rare",price=40,face="sleepy",texture="planet",ink="#0F1022",
  ramps={ramp("#5F9BE8","#27509E","#C7E2FF"),ramp("#F2843A","#A83C14","#FFC98A"),ramp("#45E6B4","#0B8A72","#C6FFE8"),
   ramp("#E2508F","#96245F","#FFD0E4"),ramp("#9B6BFF","#48239E","#DCC8FF")},
  pitch="Craters, bands and a ring. They doze.",names={"Moon","Mars","Terra","Giant","Nebula"}},
 kittens={name="Kittens",tier="showcase",price=120,face="cat",texture="none",ink="#1A1228",earsFrom=2,
  ramps={ramp("#63A6F5","#2A5FC2","#CFE6FF"),ramp("#FF9A3C","#D1560F","#FFE0A8"),ramp("#4FD98A","#149A52","#CFFFD6"),
   ramp("#FF7FB6","#CC2F7C","#FFD8EA"),ramp("#A77BFF","#5A2BD0","#E6D6FF")},
  pitch="Pointed ears and a pink nose.",names={"Blue kitten","Ginger","Matcha","Sakura","Plum"}},
}
for index,id in ipairs(Themes.Order)do
 local entry=Themes.ById[id];entry.id=id;entry.order=index
 if not table.isfrozen(entry.ramps)then table.freeze(entry.ramps)end;table.freeze(entry.names)
 table.freeze(entry)
end
table.freeze(Themes.ById);table.freeze(Themes.Order)

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
-- family is the same in every theme, so the word is the same too.
function Themes.word(tier)return colourWords[clampTier(tier)]end
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
