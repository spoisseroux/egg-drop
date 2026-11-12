-- Presentation colors only. Tier radii, identities and game rules stay in BoardConfig.
local Config=require(script.Parent.BoardConfig)
local Palette={byTier={}}
local Pico8=require(script.Parent.Pico8)
-- PICO-8 ink (0) and cream highlight (7). Tier ramps are PICO-8 rim/body/highlight
-- indices; the lower band sits between rim and body so the shading order holds.
Palette.Ink=Pico8[0]
Palette.Cream=Pico8[7]
local colors={}
for tier,ramp in ipairs(Pico8.TierRamps)do
 local rim,body=Pico8[ramp[1]],Pico8[ramp[2]]
 -- Snap blends to 8-bit so Part.Color and framebuffer writes round-trip exactly.
 local function snap(c)return Color3.fromRGB(math.round(c.R*255),math.round(c.G*255),math.round(c.B*255))end
 local upper=Pico8[ramp[3]]
 -- A cream (7) highlight IS the glint; the upper band then blends body toward
 -- it so the tight cream light stays a distinct, small spot.
 if upper==Pico8[7]then upper=snap(body:Lerp(upper,.5))end
 colors[tier]={rim,snap(rim:Lerp(body,.55)),body,upper}
end
local function key(color)return math.round(color.R*255)+math.round(color.G*255)*256+math.round(color.B*255)*65536 end
local known,custom={},{}
local customCount=0
for tier,hex in ipairs(colors)do
 local entry=table.freeze({rim=hex[1],lower=hex[2],body=hex[3],upper=hex[4],glint=Palette.Cream,mark=Palette.Ink})
 Palette.byTier[tier]=entry;known[key(Config.Tiers[tier].color)]=entry;known[key(entry.body)]=entry
end
table.freeze(Palette.byTier)
function Palette.resolve(value)
 if type(value)=="number"then return Palette.byTier[math.clamp(math.floor(value),1,#Palette.byTier)]end
 local packed=key(value);local entry=known[packed]or custom[packed]
 if entry then return entry end
 local h,s,v=value:ToHSV()
 entry=table.freeze({rim=Color3.fromHSV(h,math.min(1,s+.16),v*.34),lower=Color3.fromHSV(h,math.min(1,s+.12),v*.75),body=value,upper=value:Lerp(Palette.Cream,.38),glint=Palette.Cream,mark=Palette.Ink})
 if customCount<64 then custom[packed]=entry;customCount+=1 end
 return entry
end
return table.freeze(Palette)
