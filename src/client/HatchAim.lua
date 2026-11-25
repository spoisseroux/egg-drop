-- Where the hatch reveal's camera aims (HatchDisplayScene:layout), pure. Beta (16) B3 ("sometimes the hatching egg is
-- off centre in its square"): the aim was the middle of the whole swept envelope (the egg and the item's flight), so an
-- item that flies or lands to one side pulled the camera sideways and the egg sat off centre in the card. The egg stands
-- at the scene's origin: the aim keeps the envelope's height and is always over the egg (x 0, z 0). The fit that follows
-- still widens the shot so the whole envelope stays in frame.
local Aim={}
function Aim.target(envelopeCenter,height)
	if typeof(envelopeCenter)~="Vector3"then return Vector3.new(0,height*.60,0)end
	return Vector3.new(0,envelopeCenter.Y,0)
end
return table.freeze(Aim)
