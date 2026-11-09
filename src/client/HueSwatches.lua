-- Inspection only. Uses the production four-pigment resolver; never constructs spend intents.
local Shared=game:GetService("ReplicatedStorage").Shared
local Hue=require(Shared.HueCatalog)
local Palette=require(Shared.PetPalette)
local Swatches={}
function Swatches.at(petId,appearance,channel,hue,stage)
 if(channel~="main"and channel~="secondary")or not Hue.ById[hue]or type(stage)~="number"or stage%1~=0 or stage<1 or stage>5 then return nil end
 local token=table.clone(appearance or {})
 local key=if channel=="main"then "mainDoses"else "secondaryDoses"
 local counts=if Hue.validCounts(token[key])then table.clone(token[key])else Hue.emptyCounts()
 counts[hue]=stage;token[key]=counts
 local resolved=Palette.resolve(petId,token)
 return resolved and resolved[if channel=="main"then "body"else "secondary"]or nil
end
function Swatches.row(petId,appearance,channel,hue)
 local result={};for stage=1,5 do result[stage]=Swatches.at(petId,appearance,channel,hue,stage)end;return result
end
return Swatches
