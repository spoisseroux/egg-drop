-- Retired live progression. Archived profile facts remain available to cosmetics.
local Prestige={}
function Prestige.read(_board,_pet)return 0,false end
function Prestige.attach(visual,_pet,_rank,_legacy)
    visual.model:SetAttribute("MasteryRank",0)
    visual.model:SetAttribute("LegacyMasteryFinish",false)
end
function Prestige.updateBadge(_visual,_camera)end
function Prestige.crestReserve(_visual)return 0 end
function Prestige.update(_visual,_dt,_reduced)end
return Prestige
