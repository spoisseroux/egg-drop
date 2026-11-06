-- Existing lounge stations own E/X when close; explicit pet clicks stay available.
local Priority = {}
function Priority.stationInReach(position, prompts)
	for _, prompt in ipairs(prompts) do
		local part = prompt.Parent
		if part and part:IsA("BasePart") and prompt.Enabled
			and (position - part.Position).Magnitude <= prompt.MaxActivationDistance then return true end
	end
	return false
end
return Priority
