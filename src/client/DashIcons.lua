-- Garden Dash drawn icons (DASH-DECK-UI-LOOK U4, G4): the one table of their asset ids. Fable's PNGs are in
-- artifacts/qa-2026-11-23-beta12/look/ui/icons/ (256 px, transparent, ink #15143A; the white copies tint with
-- ImageColor3). Until they are uploaded (Studio MCP upload_image) an id is nil, and every user of this table draws its
-- stand-in instead: the HUD keeps its frame-built bolt and spring, the Racing pill a flag glyph. Pure data.
local Icons={}
Icons.Ids={
	dash=nil,       -- icons/dash.png: a bolt with three speed lines (the Dash pad)
	jump=nil,       -- icons/jump.png: a fat arrow up over a hoop (the Jump pad)
	racingFlag=nil, -- icons/racing-flag.png: the chequered flag (the Racing pill, the progress strip's cap)
	dashWhite=nil,  -- icons/dash-white.png, if a tintable upload is wanted
	jumpWhite=nil,  -- icons/jump-white.png
}
-- "rbxassetid://n" for a name, or nil while it is not uploaded.
function Icons.image(name)
	local id=Icons.Ids[name]
	return if type(id)=="number"and id>0 then "rbxassetid://"..id else nil
end
return Icons
