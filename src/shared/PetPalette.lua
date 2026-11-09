local Definitions=require(script.Parent.PetRigDefinitions)
local Hue=require(script.Parent.HueCatalog)
local Palette={}
local function linear(c)return if c<=.04045 then c/12.92 else ((c+.055)/1.055)^2.4 end
local function srgb(c)return if c<=.0031308 then c*12.92 else 1.055*c^(1/2.4)-.055 end
function Palette.tint(base,target,weight)
 local function channel(a,b)return srgb(linear(a)*(1-weight)+linear(b)*weight)end
 return Color3.new(channel(base.R,target.R),channel(base.G,target.G),channel(base.B,target.B))
end
function Palette.resolve(petId,appearance)
 local def=Definitions[petId];if not def then return nil end
 local result={};for role,hex in pairs(def.palette)do result[role]=Color3.fromHex(hex)end
 local token=if type(appearance)=="table"then appearance else {}
 local hue=Hue.ById[token.body];local rank=token.bodyRank
 if hue and type(rank)=="number"and rank%1==0 and rank>=1 and rank<=3 then result.body=Palette.tint(result.body,hue.color,Hue.Weights[rank+1])end
 local secondary=Hue.ById[token.secondary];if secondary then result.secondary=secondary.color end
 return table.freeze(result)
end
return Palette
