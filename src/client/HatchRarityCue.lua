-- Fixed authored presentation tiers. Never reads conditional odds or saved ownership.
local Shared=game:GetService("ReplicatedStorage").Shared
local Features=require(Shared.FeatureCatalog);local Materials=require(Shared.MaterialCatalog)
local Toys=require(Shared.ToyCatalog);local Hues=require(Shared.HueCatalog);local Pets=require(Shared.PetCatalog)
local Policy={Cue="hatch_finish",AnswerEnd=.60,MaxLateness=.10}
local Cue={};Cue.__index=Cue
local valid={Common=true,Uncommon=true,Rare=true,Neutral=true}
local materialTier=table.freeze({standard="Common",gloss="Common",matte="Common",jelly="Rare"})
local rarePets={};for _,pet in ipairs(Pets.rares)do rarePets[pet.id]=true end
local basePets={};for _,pet in ipairs(Pets)do basePets[pet.id]=true end
local function tier(row)return if row and valid[row.rarity]then row.rarity else "Neutral"end
function Policy.tier(kind,result)
 result=result or {}
 if kind=="material"then return if Materials.known(result.finishId)then materialTier[result.finishId]or "Neutral"else "Neutral"end
 if kind=="feature"then return tier(Features.ById[result.featureId])end
 if kind=="toy"then return tier(Toys.ById[result.toyId])end
 if kind=="hue"then return tier(Hues.Items[result.itemId])end
 if kind=="companion"then return if rarePets[result.petId]then "Rare"elseif basePets[result.petId]then "Common"else "Neutral"end
 return "Neutral"
end
function Policy.new(kind,result,readyAt)
 local classification=Policy.tier(kind,result);local events={}
 if classification=="Uncommon"then events={{at=readyAt+.24,speed=2^(2/12),gain=.22}}
 elseif classification=="Rare"then events={{at=readyAt+.20,speed=2^(-2/12),gain=.35},{at=readyAt+.42,speed=2^(5/12),gain=.32}}end
 return setmetatable({tier=classification,events=events,cursor=1,lastAge=0,readyAt=readyAt},Cue)
end
function Cue:cancel()self.cancelled=true;self.cursor=#self.events+1 end
function Cue:step(age,disclosed,live)
 if self.cancelled then return nil end
 if not live or type(age)~="number"or age~=age or age<self.lastAge then self:cancel();return nil end
 local largeJump=age-self.lastAge>.25;self.lastAge=age;local selected
 while self.cursor<=#self.events and self.events[self.cursor].at<=age do
  local event=self.events[self.cursor];self.cursor+=1
  if not largeJump and disclosed and age-event.at<=Policy.MaxLateness then selected=event end
 end
 -- At most the newest due event is played. Crossed/expired events are consumed,
 -- never backfilled one per later frame after a pause, preload or skip.
 return selected
end
return table.freeze(Policy)
