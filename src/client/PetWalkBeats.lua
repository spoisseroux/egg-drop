-- The pause after a stroll (beta (34) QA: "primitive ai ... walking needs to be more natural"). When a garden or park pet
-- stops for its wanderPause (the server's rest between strolls), its head does one small thing so the stop reads as a
-- choice: a look round (left, then right, then back), a sniff at the grass (head down, three little nods), or nothing.
-- Pure and shared-clock: the beat is chosen from the server's actionId and timed from the action's start, so every
-- screen sees the same look. Head offsets only (GardenPetVisual adds them); the body and the path are the server's.
-- Reduced Motion: nothing.
local Beats={}
Beats.Delay=.35       -- seconds into the pause before the head moves (the settle squash plays first)
Beats.LookYaw=.55     -- radians either way for a look round
Beats.LookSeconds=1.6
Beats.SniffPitch=.32  -- radians down for a sniff (+ is nose down in GardenPetVisual's head pitch)
Beats.SniffSeconds=1.4
Beats.Nods=3
Beats.Actions=table.freeze({wanderPause=true})

local function ease(u)u=math.clamp(u,0,1);return u*u*(3-2*u)end
-- Which beat an action id gets: 0 a look round, 1 a sniff, 2 nothing (about a third each).
function Beats.kind(actionId)
	if type(actionId)~="number"then return 2 end
	return math.floor(actionId*7919+13)%3
end
-- Head yaw, head pitch (radians) `age` seconds into an action.
function Beats.sample(action,actionId,age,reduced)
	if reduced or not Beats.Actions[action]or type(age)~="number"then return 0,0 end
	local kind=Beats.kind(actionId)
	local u=age-Beats.Delay
	if kind==0 then
		if u<=0 or u>=Beats.LookSeconds then return 0,0 end
		local p=u/Beats.LookSeconds
		-- 0 -> left (a third), -> right (two thirds), -> centre: a smooth S through both sides.
		local yaw
		if p<.3 then yaw=-Beats.LookYaw*ease(p/.3)
		elseif p<.7 then yaw=-Beats.LookYaw+2*Beats.LookYaw*ease((p-.3)/.4)
		else yaw=Beats.LookYaw*(1-ease((p-.7)/.3))end
		return yaw,-.06*math.sin(math.pi*p) -- a slight lift of the chin while looking
	elseif kind==1 then
		if u<=0 or u>=Beats.SniffSeconds then return 0,0 end
		local p=u/Beats.SniffSeconds
		local down=math.sin(math.pi*p)
		local nod=.25*math.max(0,math.sin(p*math.pi*2*Beats.Nods))
		return 0,Beats.SniffPitch*down*(1-nod*.6)+.04*nod*down
	end
	return 0,0
end

return table.freeze(Beats)
