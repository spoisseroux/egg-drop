-- Presentation colors only. Tier radii, identities and game rules stay in BoardConfig.
local Config=require(script.Parent.BoardConfig)
local Palette={byTier={}}
Palette.Ink=Color3.fromHex("#201D32")
Palette.Cream=Color3.fromHex("#FFF5DA")
local colors={
 {"#123E83","#0870CF","#159CF4","#70D5FF"},
 {"#83312B","#E45017","#FF8A23","#FFC760"},
 {"#315B28","#65B616","#A9E72B","#DAFF70"},
 {"#6A235B","#BD1F6D","#F64A96","#FF9FC0"},
 {"#3E246E","#682BBA","#A86CF7","#D0AAFF"},
}
local function key(color)return math.round(color.R*255)+math.round(color.G*255)*256+math.round(color.B*255)*65536 end
local known,custom={},{}
local customCount=0
for tier,hex in ipairs(colors)do
 local entry=table.freeze({rim=Color3.fromHex(hex[1]),lower=Color3.fromHex(hex[2]),body=Color3.fromHex(hex[3]),upper=Color3.fromHex(hex[4]),glint=Palette.Cream,mark=Palette.Ink})
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
