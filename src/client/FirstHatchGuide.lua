local Art = require(script.Parent.DeckArt)

local Guide = {}
Guide.__index = Guide

local function outline(target, radius, tint)
	local frame = Art.frame(target, "GuideOutline", Art.Ink, UDim2.fromOffset(-2, -2), UDim2.new(1, 4, 1, 4),
		target.ZIndex + 1)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	Art.corner(frame, radius)
	Art.stroke(frame, tint, 0, 2)
	return frame
end

function Guide.new(rail, rocker, drop, meter)
	return setmetatable({
		rail = outline(rail, 9, Art.Cyan),
		rocker = outline(rocker, 10, Art.Cyan),
		drop = outline(drop, 100, Art.Cyan),
		meter = outline(meter, 5, Art.Amber),
	}, Guide)
end

function Guide:step(drops, merges, charge, owned, inputType, mark, active)
	local touch = inputType == Enum.UserInputType.Touch
	local controller = string.match(inputType.Name, "^Gamepad") ~= nil
	local step = if owned > 0 then 0 elseif merges > 0 or charge > 0 then 3 elseif drops > 0 then 2 else 1
	self.rail.Visible = active and touch and step == 1
	self.rocker.Visible = active and not touch and step == 1
	self.drop.Visible = active and not touch and (step == 1 or step == 2)
	self.meter.Visible = active and step == 3
	if step == 1 then
		return "1/3  AIM & DROP\n" .. (if touch then "Drag bar, release" elseif controller then "D-pad then A" else "←/→ then Space")
	elseif step == 2 then
		return string.format("2/3  MATCH MARKS\nDrop %s onto %s", mark, mark)
	elseif step == 3 then
		return "3/3  HATCH PIP\nMerge to fill charge"
	end
	return nil
end

return Guide
