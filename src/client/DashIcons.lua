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
	-- FABLE-REVIEW-R1 4: look/ui/spot-wedge.png, the Dash stages' spotlight (256 px white trapezoid, top 18%, bottom
	-- 80%, 4 px feathered sides). PLACEHOLDER: 0 until it is uploaded; the stages draw no spotlight until then.
	spotWedge=0,
}
-- "rbxassetid://n" for a name, or nil while it is not uploaded.
function Icons.image(name)
	local id=Icons.Ids[name]
	return if type(id)=="number"and id>0 then "rbxassetid://"..id else nil
end
-- Every uploaded icon's "rbxassetid://n", in a fixed order (pure).
function Icons.list()
	local out={}
	for _,name in ipairs({"dash","jump","racingFlag","dashWhite","jumpWhite","spotWedge"})do
		local image=Icons.image(name)
		if image then table.insert(out,image)end
	end
	return out
end
-- Fetch them in the background when Dash mounts, so the first countdown's pads are not blank (FABLE-REVIEW-R1 5: the
-- icons were missing for the first seconds). `provider` is ContentProvider (a stand-in in specs). Never throws.
function Icons.preload(provider)
	local list=Icons.list()
	if #list==0 then return 0 end
	task.spawn(function()
		pcall(function()(provider or game:GetService("ContentProvider")):PreloadAsync(list)end)
	end)
	return #list
end
return Icons
