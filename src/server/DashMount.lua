-- Garden Dash gate (V3-DASH-BUILD-PLAN-2026-11-22, slice S6): the static props, placed from DashCourse as ParkMount
-- places the park. Placeholder parts until the art lands (Fable): start arch, finish arch, eight lane pads, a sign
-- post and the three stepping stones. Everything is anchored and non-colliding, non-queryable and non-touching,
-- beside the lounge rather than inside it, so players, pets and every garden raycast pass straight through.
-- Hoops and clovers are the client's (layouts differ). Built while Dash is on; removed when it goes off.
local Course=require(game:GetService("ReplicatedStorage").Shared.DashCourse)
local Mount={}
Mount.ModelName="GardenDash"
Mount.Frame=Color3.fromHex("#C9C2D6")
Mount.Banner=Color3.fromHex("#FFE68A")
Mount.Stone=Color3.fromHex("#B9B4C4")

local function part(parent,name,size,cframe,color)
	local item=Instance.new("Part")
	item.Name=name;item.Size=size;item.CFrame=cframe;item.Color=color
	item.Anchored=true;item.CanCollide=false;item.CanQuery=false;item.CanTouch=false;item.CastShadow=false
	item.Material=Enum.Material.SmoothPlastic
	item:SetAttribute("DashPart",true)
	item.Parent=parent
	return item
end
local function frameAt(cs,lane)
	local x,y,z,yaw=Course.at(cs,false,lane)
	return CFrame.new(x,y,z)*CFrame.Angles(0,yaw,0)
end
local function arch(parent,name,at)
	part(parent,name.."Left",Vector3.new(.4,5,.4),at*CFrame.new(-2.8,2.5,0),Mount.Frame)
	part(parent,name.."Right",Vector3.new(.4,5,.4),at*CFrame.new(2.8,2.5,0),Mount.Frame)
	part(parent,name.."Banner",Vector3.new(6,.9,.3),at*CFrame.new(0,4.8,0),Mount.Banner)
end
-- The gate's spot on the ground: what the server measures joins from.
function Mount.gate()
	local x,y,z=Course.at(0)
	return Vector3.new(x,y,z)
end
function Mount.build(room)
	Mount.remove(room)
	local model=Instance.new("Model");model.Name=Mount.ModelName
	local start,finish=frameAt(0),frameAt(Course.Length)
	model:SetAttribute("DashVersion",Course.Version)
	model:SetAttribute("Start",start);model:SetAttribute("Finish",finish)
	arch(model,"Start",start);arch(model,"Finish",finish)
	for lane=1,Course.LaneCount do
		part(model,"Pad_"..lane,Vector3.new(.45,.08,.9),frameAt(0,lane)*CFrame.new(0,.04,-.8),Mount.Banner)
	end
	part(model,"SignPost",Vector3.new(.25,3,.25),start*CFrame.new(-4.2,1.5,-1),Mount.Frame)
	part(model,"Sign",Vector3.new(2.2,1.2,.2),start*CFrame.new(-4.2,3,-1),Mount.Banner)
	for index,stone in ipairs(Course.Stones)do
		part(model,"Stone_"..index,Vector3.new(2.2,.3,2.2),CFrame.new(stone.x/100,stone.y/100-.15,stone.z/100),Mount.Stone)
	end
	model.Parent=room
	return model
end
function Mount.remove(room)
	local existing=room:FindFirstChild(Mount.ModelName)
	if existing then existing:Destroy()end
end
return Mount
