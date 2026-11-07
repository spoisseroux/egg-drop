-- Deterministic E/X ownership at overlapping native station radii.
local Priority={}
function Priority.nearest(position,prompts,valid,includeDisabled)
	local winner,distance,key
	for _,prompt in ipairs(prompts)do
		local part=prompt.Parent
		if part and part:IsA("BasePart") and (includeDisabled or prompt.Enabled) and (not valid or valid(prompt)) then
			local range=(position-part.Position).Magnitude
			local candidate=tostring(prompt:GetAttribute("PocketClubStation") or prompt.Name)
			if range<=prompt.MaxActivationDistance and (not distance or range<distance-1e-6 or (math.abs(range-distance)<=1e-6 and candidate<key)) then
				winner,distance,key=prompt,range,candidate
			end
		end
	end
	return winner
end
function Priority.stationInReach(position,prompts)
	return Priority.nearest(position,prompts)~=nil
end
return Priority
