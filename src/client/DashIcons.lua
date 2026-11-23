-- Garden Dash drawn icons (DASH-DECK-UI-LOOK U4, G4): the one table of their asset ids. Fable's PNGs are in
-- artifacts/qa-2026-11-23-beta12/look/ui/icons/ (256 px, transparent, ink #15143A; the white copies tint with
-- ImageColor3). Uploaded 2026-11-23. A missing id (nil) still draws its stand-in instead: the HUD's frame-built bolt
-- and spring, the Racing pill's flag glyph. Pure data.
local Icons={}
Icons.Ids={
	dash=97429349017697,        -- icons/dash.png: a bolt with three speed lines (the Dash pad)
	jump=135761648509586,       -- icons/jump.png: a fat arrow up over a hoop (the Jump pad)
	racingFlag=97444903136843,  -- icons/racing-flag.png: the chequered flag (the Racing pill, the progress strip's cap)
	dashWhite=132239421086976,  -- icons/dash-white.png, tintable with ImageColor3
	jumpWhite=132916023122268,  -- icons/jump-white.png
}
-- "rbxassetid://n" for a name, or nil while it is not uploaded.
function Icons.image(name)
	local id=Icons.Ids[name]
	return if type(id)=="number"and id>0 then "rbxassetid://"..id else nil
end
return Icons
