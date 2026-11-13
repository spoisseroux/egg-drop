-- Presentation colors only. Tier radii, identities and game rules stay in BoardConfig.
-- Vivid egg ramps (UI-SPEC-REDESIGN-MENUS 6.2): deep (lower-right shade), body,
-- light (upper-left, rim light and bloom), a white glint and a white 23% motif.
-- There is no outline role any more; `rim`, `lower` and `upper` stay as aliases
-- so older readers keep working (rim = deep, upper = light).
local Config=require(script.Parent.BoardConfig)
local Palette={byTier={}}
local Pico8=require(script.Parent.Pico8)
Palette.Ink=Pico8[0]
Palette.Cream=Pico8[7]
Palette.White=Color3.new(1,1,1)
-- Motif ids (white at 23% inside the body): a second tier cue besides colour.
Palette.Motifs=table.freeze({plain=1,bands=2,speckles=3,stars=4,dots=5})
Palette.MotifOpacity=.23
-- No tier numerals any more (batch 2026-11-13 R1): size, colour and the ball's
-- face carry the tier; the UI names a ball with a flat colour circle (BallThemes).
-- Motifs survive only in the free Marbles theme.
local function snap(c)return Color3.fromRGB(math.round(c.R*255),math.round(c.G*255),math.round(c.B*255))end
local function entry(deep,body,light,motif)
 return table.freeze({deep=deep,lower=snap(deep:Lerp(body,.55)),body=body,light=light,glint=Palette.White,
  motif=snap(body:Lerp(Palette.White,Palette.MotifOpacity)),motifKind=motif,
  rim=deep,upper=light})
end
local function key(color)return math.round(color.R*255)+math.round(color.G*255)*256+math.round(color.B*255)*65536 end
local known,custom={},{}
local customCount=0
for tier,ramp in ipairs(Pico8.TierRamps)do
 local hex=Color3.fromHex
 local roles=entry(hex(ramp.deep),hex(ramp.body),hex(ramp.light),Palette.Motifs[ramp.motif]or 1)
 Palette.byTier[tier]=roles
 -- The server still colours egg Parts with the legacy BoardConfig colour; both resolve here.
 known[key(Config.Tiers[tier].color)]=roles;known[key(roles.body)]=roles
end
table.freeze(Palette.byTier)
function Palette.resolve(value)
 if type(value)=="number"then return Palette.byTier[math.clamp(math.floor(value),1,#Palette.byTier)]end
 local packed=key(value);local roles=known[packed]or custom[packed]
 if roles then return roles end
 local h,s,v=value:ToHSV()
 roles=entry(snap(Color3.fromHSV(h,math.min(1,s+.12),v*.7)),value,snap(value:Lerp(Palette.White,.45)),1)
 if customCount<64 then custom[packed]=roles;customCount+=1 end
 return roles
end
-- Roles for one size in a ball theme (BallThemes ramps; Marbles is byTier).
local Themes=require(script.Parent.BallThemes)
local themed={}
function Palette.forTheme(themeId,tier)
 tier=math.clamp(math.floor(tonumber(tier)or 1),1,#Palette.byTier)
 local theme=Themes.get(themeId)
 if theme.texture=="motif"then return Palette.byTier[tier]end
 local key=theme.id..tier
 if not themed[key]then
  local r=theme.ramps[tier]
  themed[key]=entry(Color3.fromHex(r.deep),Color3.fromHex(r.body),Color3.fromHex(r.light),1)
 end
 return themed[key]
end
return table.freeze(Palette)
