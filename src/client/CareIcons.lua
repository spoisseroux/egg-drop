-- The pet screen's carry icons (beta 42 note 14, D14; POINTER-STORK-BRIEF section 3): the one table of their asset ids.
-- The PNGs are ours, drawn by scripts/render_care_icons.py into assets/ui/care/ (256 px, transparent, ink #15143A; the
-- white copies tint with ImageColor3). PLACEHOLDER: every id is 0 until uploaded; while an id is 0 GardenCareClient
-- keeps the old frame-built arrow (DeckArt.carryArrow). Pure data and rules.
local Icons={}
Icons.Ids={
	pickUp=0,       -- assets/ui/care/pick-up.png: a Pal head in a cupped hand, two lift marks (the Pick up key)
	setDown=0,      -- assets/ui/care/set-down.png: the head in a lower hand over a ground line (the Set down key)
	pickUpWhite=0,  -- assets/ui/care/pick-up-white.png, tintable with ImageColor3
	setDownWhite=0, -- assets/ui/care/set-down-white.png
}
-- The key's icon size (px) inside its 48 px round key.
Icons.Size=30
-- Which icon a carry key shows: "pickUp" (up) or "setDown" (down).
function Icons.nameFor(up)return if up then "pickUp"else "setDown"end
-- "rbxassetid://n" for a name, or nil while it is not uploaded (0, missing or not a whole positive number).
function Icons.image(name)
	local id=Icons.Ids[name]
	return if type(id)=="number"and id>0 and id%1==0 then "rbxassetid://"..string.format("%d",id)else nil
end
return Icons
