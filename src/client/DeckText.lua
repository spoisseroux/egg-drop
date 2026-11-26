-- One knob for the Pocket Deck's text size on a computer (beta 34 QA, Spencer: "the font on the pocket deck could be
-- bigger on computer too"). The Regular deck (a computer window, DeckScreen.resolve mode "Regular") draws its HUD
-- authored at 848 x 608 and scaled with the shell, so on a laptop its 13-16 px roles came out at 11-13 px; the in-place
-- results on any computer are laid out in real LCD px. `Desktop` multiplies those labels' authored sizes once, when the
-- screen is built:
--  * a one-line label grows only up to its own box height, so it stays inside its card (never below its old size);
--  * a wrapped label grows by the whole factor; its owner lays the lines out from the label's TextSize (the Goals rows,
--    the results rows), so nothing overlaps.
-- Phones (mode "Compact") and the Small deck (already drawn up to 1.5x by its UIScale) keep 1. Labels inside chips,
-- hint caps and buttons size themselves and are left alone, as is anything marked DeckTextKeep.
local Text={}
Text.Desktop=1.2

-- The factor for a deck mode ("Regular" | "Small" | "Compact"), and for the in-place results (`phone` false: 1.2).
function Text.hud(mode)return if mode=="Regular"then Text.Desktop else 1 end
function Text.results(phone)return if phone then 1 else Text.Desktop end

-- Pure: the size for a label authored at `base` px in a box `boxH` px tall.
function Text.size(base,boost,boxH,wrapped)
	if type(base)~="number"or type(boost)~="number"or boost<=1 then return base end
	local want=math.floor(base*boost+.5)
	if not wrapped and type(boxH)=="number"and boxH>0 then want=math.min(want,math.max(base,math.floor(boxH)))end
	return math.max(base,want)
end

-- Pure: may `label` (a TextLabel-shaped table) be boosted? Not when kept, sized by a Scale, or inside a chip / cap.
local function kept(label,root)
	if label:GetAttribute("DeckTextKeep")or label.TextScaled then return true end
	if label.Size.Y.Scale~=0 then return true end
	local node=label.Parent
	while node and node~=root do
		if node:GetAttribute("ChipKind")~=nil or node:GetAttribute("DeckTextKeep")or node:IsA("GuiButton")then return true end
		node=node.Parent
	end
	return false
end
Text.kept=kept

-- Every TextLabel under `root`, once (DeckTextBase keeps the authored size, so a second call changes nothing).
function Text.apply(root,boost)
	if not root or type(boost)~="number"or boost<=1 then return 0 end
	local n=0
	for _,label in ipairs(root:GetDescendants())do
		if label:IsA("TextLabel")and label:GetAttribute("DeckTextBase")==nil and not kept(label,root)then
			local base=label.TextSize
			label:SetAttribute("DeckTextBase",base)
			local size=Text.size(base,boost,label.Size.Y.Offset,label.TextWrapped)
			if size~=base then label.TextSize=size;n+=1 end
		end
	end
	return n
end

return table.freeze(Text)
