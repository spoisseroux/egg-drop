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
-- Beta (17) U6 ("a weird shadow always off to the right after hatching"): the item's contact shadow stood at
-- HatchDisplayItem's `contact`, the single lowest corner of the lowest part's box, which for a flat or tilted toy is
-- an edge of the item, not its middle. The shadow goes under the middle of the item's ground footprint instead:
-- the centre of the world X/Z bounds of every part (each part's rotated box). parts: {{CFrame, Size}} (BaseParts
-- work). Returns x, z, or nil when there is nothing to measure.
function Aim.footprint(parts)
	local loX,hiX,loZ,hiZ=math.huge,-math.huge,math.huge,-math.huge
	for _,p in ipairs(parts or {})do
		local cf,size=p.CFrame,p.Size
		if cf and size then
			local h=size*.5;local r,u,l=cf.RightVector,cf.UpVector,cf.LookVector;local at=cf.Position
			local ex=math.abs(r.X)*h.X+math.abs(u.X)*h.Y+math.abs(l.X)*h.Z
			local ez=math.abs(r.Z)*h.X+math.abs(u.Z)*h.Y+math.abs(l.Z)*h.Z
			loX,hiX=math.min(loX,at.X-ex),math.max(hiX,at.X+ex);loZ,hiZ=math.min(loZ,at.Z-ez),math.max(hiZ,at.Z+ez)
		end
	end
	if loX==math.huge then return nil end
	return(loX+hiX)*.5,(loZ+hiZ)*.5
end
return table.freeze(Aim)
