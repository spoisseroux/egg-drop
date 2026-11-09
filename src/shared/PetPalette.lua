local Definitions=require(script.Parent.PetRigDefinitions)
local Hue=require(script.Parent.HueCatalog)
local Palette={}
local legacy={
 bloom_pip={body="#F6A786",secondary="#74B971"},wick={body="#F79860",secondary="#F6C557"},orbit={body="#C7AEF3",secondary="#806BBA"},
 foxfire_wick={body="#8EAEFF",secondary="#54EDDC"},eclipse_orbit={body="#7162C8",secondary="#FFD07E"},
}
function Palette.original(petId)
 local def=Definitions[petId];local source=if def then def.palette else legacy[petId]
 if not source then return nil end
 local result={};for role,hex in pairs(source)do result[role]=Color3.fromHex(hex)end
 if not def then result.face=Color3.fromHex("#392846");result.mouth=result.face;result.ivory=Color3.fromHex("#FFF6E9");result.blush=Color3.fromHex("#F4D2F5")end
 return result
end
local function linear(c)return if c<=.04045 then c/12.92 else ((c+.055)/1.055)^2.4 end
local function srgb(c)return if c<=.0031308 then c*12.92 else 1.055*c^(1/2.4)-.055 end
function Palette.tint(base,target,weight)
 local function channel(a,b)return srgb(linear(a)*(1-weight)+linear(b)*weight)end
 return Color3.new(channel(base.R,target.R),channel(base.G,target.G),channel(base.B,target.B))
end
function Palette.resolve(petId,appearance)
 local result=Palette.original(petId);if not result then return nil end
 local token=if type(appearance)=="table"then appearance else {}
 local hue=Hue.Mixes[token.bodyMix]or Hue.ById[token.body];local rank=token.bodyRank
 if hue and type(rank)=="number"and rank%1==0 and rank>=1 and rank<=3 then result.body=Palette.tint(result.body,hue.color,Hue.Weights[rank+1])end
 local secondary=Hue.ById[token.secondary];if secondary then result.secondary=secondary.color end
 for _,channel in ipairs({{"mainDoses","body"},{"secondaryDoses","secondary"}})do
  local counts=token[channel[1]]
  if Hue.validCounts(counts)then local original=Palette.original(petId)[channel[2]];local target=Hue.resolveTarget(counts);result[channel[2]]=if target then Palette.tint(original,target,Hue.doseStrength(counts))else original end
 end
 return table.freeze(result)
end
return Palette
