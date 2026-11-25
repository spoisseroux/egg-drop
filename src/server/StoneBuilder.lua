-- The stone builder (WORLD-ALIVE-LOOK section 4, "Shape, tonight"): one faceted, flat-domed stone from a stone row
-- (RiverStones: x, z, length, width, turn, top, colour, seed). Server only.
--   Builder.stone(parent, stone, options) -> the fallback Model at once: two stacked Cylinders (the footprint's width,
--     then 80% of it), Slate. Then, unless options.carve is false, a carve on its own thread: a Ball Ball x the stone's
--     length, sunk so its top is the stone's top, with 5 to 7 big Blocks leaning out and a floor block cut away
--     (GeometryService:SubtractAsync, Studio R13); the result replaces the cylinders inside the same Model. A carve
--     that throws keeps the cylinders.
-- Everything is anchored with no collision, query or touch and no shadow; the walkable colliders are DashMount's.
-- options (specs): {carve = false | function(ball, blocks) -> PartOperation, spawn = fn, ball = multiplier}.
-- The Hollow park's rim and gap stones (section 2) use the same builder.
local Stones=require(game:GetService("ReplicatedStorage").Shared.RiverStones)
local Builder={}

local function still(item)
	item.Anchored=true;item.CanCollide=false;item.CanQuery=false;item.CanTouch=false;item.CastShadow=false
	return item
end
local function cylinder(parent,name,diameter,height,centre,colour)
	local part=still(Instance.new("Part"))
	part.Name=name;part.Shape=Enum.PartType.Cylinder
	part.Size=Vector3.new(height,diameter,diameter)
	part.CFrame=CFrame.new(centre)*CFrame.Angles(0,0,math.pi/2) -- the cylinder's axis (X) up
	part.Material=Enum.Material.Slate;part.Color=colour
	part.Parent=parent
	return part
end
-- The fallback cylinders' parts (the footprint's width, then Upper of it, .45 and .3 high, the upper's top the stone's).
function Builder.fallback(parent,stone)
	local F=Stones.Fallback
	local width=math.min(stone.length,stone.width)
	local at=Vector3.new(stone.x,stone.top,stone.z)
	local upper=cylinder(parent,"StoneTop",width*F.upperShare,F.upper,at-Vector3.new(0,F.upper/2,0),stone.colour)
	local lower=cylinder(parent,"StoneFoot",width,F.lower,at-Vector3.new(0,F.upper+F.lower/2,0),stone.colour)
	return{upper,lower}
end
-- The carve's inputs: the ball and the cutting blocks (unparented parts), from RiverStones.blocks: each block stands
-- OUTSIDE its face (the plane through the footprint at the base height, leaning out: its foot further out than its
-- top), and one floor block takes the ball away under the stone. The carve subtracts them all from the ball.
function Builder.inputs(stone,ballScale)
	local diameter=(ballScale or stone.ball or Stones.Ball)*stone.length
	local ball=Instance.new("Part")
	ball.Shape=Enum.PartType.Ball;ball.Size=Vector3.one*diameter
	ball.CFrame=CFrame.new(stone.x,stone.top-diameter/2,stone.z)
	local blocks={}
	local frames,size=Stones.blocks(stone)
	for _,frame in ipairs(frames)do
		local block=Instance.new("Part")
		block.Size=Vector3.one*size
		block.CFrame=frame
		table.insert(blocks,block)
	end
	return ball,blocks
end
-- Studio R13: never IntersectAsync here (it keeps the ball wherever it meets any block).
local function subtract(ball,blocks)
	local results=game:GetService("GeometryService"):SubtractAsync(ball,blocks,{
		CollisionFidelity=Enum.CollisionFidelity.Box,RenderFidelity=Enum.RenderFidelity.Precise,SplitApart=false})
	return results and results[1]
end

-- A Model holding the stone: the fallback now, the carved stone when (and if) the carve lands.
function Builder.stone(parent,stone,options)
	options=options or {}
	local model=Instance.new("Model")
	model.Name=stone.name
	model:SetAttribute("Stone",true)
	local fallback=Builder.fallback(model,stone)
	model.Parent=parent
	local carve=options.carve
	if carve==false then return model end
	carve=carve or subtract
	local spawn=options.spawn or task.spawn
	spawn(function()
		local ball,blocks=Builder.inputs(stone,options.ball)
		local ok,result=pcall(carve,ball,blocks)
		ball:Destroy();for _,block in ipairs(blocks)do block:Destroy()end
		if not ok or not result then
			if not ok then warn("[Stones] "..stone.name..": carve failed, cylinders kept: "..tostring(result))end
			return
		end
		-- The mount may be gone (Dash off, rebuilt) while the carve ran.
		if model.Parent==nil then pcall(function()result:Destroy()end);return end
		still(result)
		result.Name="Stone"
		result.Material=Enum.Material.Slate
		pcall(function()result.UsePartColor=true;result.SmoothingAngle=0 end)
		result.Color=stone.colour
		result.Parent=model
		for _,part in ipairs(fallback)do part:Destroy()end
		model:SetAttribute("Carved",true)
	end)
	return model
end

return Builder
