local Art = require(script.Parent.DeckArt)
local Config = require(game:GetService("ReplicatedStorage").Shared.BoardConfig)

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

function Guide.new(rail, rocker, drop, meter, status)
	local self = setmetatable({
		rail = outline(rail, 9, Art.Cyan),
		rocker = outline(rocker, 10, Art.Cyan),
		drop = outline(drop, 100, Art.Cyan),
		meter = outline(meter, 5, Art.Amber),
	}, Guide)
	if status then
		local host = Art.frame(status, "FieldLesson", Art.Ink, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), status.ZIndex + 1)
		host.BackgroundTransparency, host.Visible = 0, false
		Art.corner(host, 6)
		local heading = Art.text(host, "Direction", "MATCH ON LEFT", UDim2.fromOffset(2, 0), UDim2.new(1, -4, 0, 13), Art.Silver, 11)
		Art.fitText(heading, 11, 8, 0)
		local diagram = Art.frame(host, "MatchingDiagram", Art.Ink, UDim2.fromOffset(0, 14), UDim2.new(1, 0, 1, -14), host.ZIndex)
		diagram.BackgroundTransparency = 1
		local pieces = {}
		for i, data in ipairs({ { .14, "II", 2 }, { .49, "II", 2 }, { .86, "III", 3 } }) do
			local piece = Art.frame(diagram, "Jelly" .. i, Config.Tiers[data[3]].color, UDim2.fromScale(data[1], .5), UDim2.fromOffset(21, 21), host.ZIndex + 1)
			piece.AnchorPoint = Vector2.new(.5, .5); Art.corner(piece, 20)
			local mark = Art.text(piece, "Mark", data[2], UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), Art.Ink, 10)
			Art.fitText(mark, 11, 8, 0)
			table.insert(pieces, piece)
		end
		for _, data in ipairs({ { .315, "+" }, { .675, "→" } }) do
			local mark = Art.text(diagram, "Operator", data[2], UDim2.fromScale(data[1], .5), UDim2.fromOffset(20, 20), Art.Silver, 15)
			mark.AnchorPoint = Vector2.new(.5, .5)
		end
		local compact = Art.text(host, "CompactHint", "", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), Art.Silver, 11)
		Art.fitText(compact, 11, 8, 1, true)
		self.field = { host = host, heading = heading, diagram = diagram, compact = compact, pieces = pieces }
	end
	return self
end

-- Coaching is presentation-only; the authoritative field state determines
-- success. No tutorial flag, input blocker, sound, or reward lives here.
function Guide:fieldStep(stage, totalWins, active)
	local field = self.field
	if not field then return false end
	field.host.Visible = active == true and totalWins == 0
	if not field.host.Visible then return false end
	local compact = field.host.AbsoluteSize.Y < 34 or stage >= 2
	field.heading.Visible, field.diagram.Visible, field.compact.Visible = not compact, not compact, compact
	local side = if stage == 0 then "LEFT" else "RIGHT"
	field.heading.Text = "MATCH ON " .. side
	field.compact.Text = if stage >= 2 then "Both done · keep it low" else side .. ": II + II → III"
	return true
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
		return "1/3  AIM & DROP\n" .. (if touch then "Drag tray, release" elseif controller then "D-pad then A" else "←/→ then Space")
	elseif step == 2 then
		return string.format("2/3  MATCH MARKS\nDrop %s onto %s", mark, mark)
	elseif step == 3 then
		return "3/3  HATCH PIP\nMerge to fill charge"
	end
	return nil
end

return Guide
