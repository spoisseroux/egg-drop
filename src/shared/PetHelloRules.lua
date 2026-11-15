-- Inspect and greet another player's pet (QA v685 R6; VISITOR-PET-SCOPE 2026-11-14).
-- Shared numbers and the one "is this pet free to wave" rule, so the server's answer and
-- the card's disabled button agree. Hello is reward-free: no Stars, no bond XP, no quest
-- or stamp credit, and nothing is saved.
local Rules={}
Rules.InspectRange=12   -- viewer to pet, to open or keep the card
Rules.InspectLeave=16   -- the card closes past this (hysteresis over InspectRange)
Rules.HelloRange=7      -- viewer to pet, for Say hello
Rules.HeightReach=6
-- The wave: glance 0.25 s, two waves over 0.8 s, back to idle in 0.25 s.
Rules.GlanceIn,Rules.Wave,Rules.GlanceOut=.25,.8,.25
Rules.Duration=Rules.GlanceIn+Rules.Wave+Rules.GlanceOut
-- Accepted hellos: one per viewer per 5 s, one per target pet per 10 s, one per
-- viewer and target pair per 30 s. Requests closer than MinGap are dropped unanswered.
Rules.ViewerCooldown,Rules.TargetCooldown,Rules.PairCooldown,Rules.MinGap=5,10,30,.25
Rules.Attribute="PetHello"          -- owner's board: JSON {id,from,at,petId,petGeneration}
Rules.OffAttribute="GreetingsOff"   -- owner's board: true when the owner turned greetings off
Rules.BondAttribute="PublicBond"    -- owner's board: the selected pet's bond level only

local quiet={wanderPause=true,nookRest=true,settle=true}
-- A garden actor (server actor or a client snapshot actor) that may wave right now:
-- in the garden, standing, and not reserved by its owner, care, the park or another pet.
function Rules.free(actor,now)
 if type(actor)~="table"or actor.mode~="Room"or actor.care~=nil then return false end
 if actor.pairId~=nil or actor.peerId~=nil or actor.toyActionId~=nil or actor.toyReservation~=nil or actor.toyRole~=nil then return false end
 if type(actor.park)=="table"and actor.park.state~="idle"then return false end
 if actor.behavior=="rest"then return actor.action==nil or quiet[actor.action]==true end
 if actor.behavior~="follow"or(actor.action~=nil and actor.action~="follow")then return false end
 -- Follow counts once the walk back to the owner has ended.
 return type(actor.endTime)~="number"or type(now)~="number"or now>=actor.endTime
end
local function whole(value,low,high)return type(value)=="number"and value==value and value%1==0 and value>=low and value<=high end
Rules.whole=whole
-- Structural check of a hello request; the server then resolves everything itself.
function Rules.validPacket(packet)
 return type(packet)=="table"and whole(packet.seq,1,2147483647)and whole(packet.ownerId,1,9007199254740991)
  and type(packet.petId)=="string"and #packet.petId>=1 and #packet.petId<=32
  and whole(packet.characterId,0,2147483647)and whole(packet.petGeneration,0,2147483647)
end
return Rules
