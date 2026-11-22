-- Garden perks from levels (V3-LEVELS-BUILD-PLAN-2026-11-22, S1). Pure. Looks only, never the Pocket
-- Deck: the swing, slide, see-saw and catch looks are drawn by every client from the pet's public
-- levels (StatCatalog.PublicAttribute); the longer throw is decided by the server from the thrower's
-- saved Speed. Levels are append-only and may only be lowered. All off while the track part is off.
local Shared=script.Parent
local Stats=require(Shared.StatCatalog)
local Levels=require(Shared.Levels)
local Perks={}
Perks.Rows=table.freeze({
 table.freeze({id="swingCheer",stat="jump",level=5,area="park"}),   -- a wave at the top of the swing
 table.freeze({id="swingHigh",stat="jump",level=10,area="park"}),   -- a higher arc (drawing only)
 table.freeze({id="slideSpin",stat="jump",level=20,area="park"}),   -- one turn on the chute
 table.freeze({id="seesawHop",stat="jump",level=40,area="park"}),   -- a hop at the top of the see-saw
 table.freeze({id="longThrow",stat="speed",level=5,area="fetch"}),  -- server: the ball lands 5 studs out
 table.freeze({id="catchHop",stat="speed",level=20,area="fetch"}),  -- a hop as the pet gets the ball
})
Perks.SwingScale=1.25 -- swingHigh multiplies the drawn swing amplitude
Perks.Reach=table.freeze({normal=4,long=5}) -- studs from the park centre to where the ball lands

local function level(value)
 return if type(value)=="number"and value==value and value%1==0 and value>=1 and value<=Stats.MaxLevel then value else 0
end
-- {swingCheer=true, ...} for one pet's levels ({statId=level}); empty while the track is off.
function Perks.forLevels(levels)
 local out={}
 if type(levels)~="table"or not Levels.on("track")then return out end
 for _,row in ipairs(Perks.Rows)do if level(levels[row.stat])>=row.level then out[row.id]=true end end
 return out
end
-- The same from a decoded PublicStats attribute ({v, pets={[petId]={levels}}}).
function Perks.fromPublic(public,petId)
 local pets=type(public)=="table"and public.pets
 local row=type(pets)=="table"and type(petId)=="string"and pets[petId]
 return Perks.forLevels(type(row)=="table"and row.levels or nil)
end
-- How far a throw may reach for the thrower's saved Speed level.
function Perks.throwReach(speed)
 return if Perks.forLevels({speed=speed}).longThrow then Perks.Reach.long else Perks.Reach.normal
end
return table.freeze(Perks)
