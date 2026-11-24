-- Garden life for beta (14) QA: the new textures in one table (GARDEN-LIFE-BUILD-PLAN section 9; look
-- artifacts/qa-2026-11-23-beta14/WORLD-AND-NEST-LOOK.md sections 1, 6, 7). Files are drawn by
-- scripts/draw_garden_life_r4_textures.py into artifacts/qa-2026-11-23-beta14/look/. Until a file is uploaded its id is
-- nil and Art.id answers the fallback (an asset already uploaded) or nil (nothing is drawn for it: the plate's Decal is
-- left empty); after the upload, write the id in the second argument of its row. `python scripts/check_life_art.py r4`
-- is the publish gate (files exist, match the draw script byte for byte, no id still nil). Pure data, shared.
local Art={}
Art.Folder="artifacts/qa-2026-11-23-beta14/look"

-- Fallbacks: round 3's uploads.
local LEAFA="rbxassetid://140368108993906"   -- leaf-a.png (one leaf; the sheet's grid is not set while pending)
local DEWDROP="rbxassetid://82054526707528"  -- assets/world/dewdrop.png (FRUIT-LOOK), no stem

-- f(file, uploaded id or nil, fallback or nil). One row a line: check_life_art.py reads them.
local function f(file,id,fallback)return table.freeze({file=file,id=id,fallback=fallback})end
Art.Files=table.freeze({
	leafSheet=f("leaf-sheet.png",nil,LEAFA),             -- 192x192, 2x2 cells: broad, willow, lime heart, dry curl
	leafSheetAC=f("leaf-sheet-ac.png",nil,LEAFA),        -- 192x96, the flipbook fallback (A + C)
	leafSheetBD=f("leaf-sheet-bd.png",nil,LEAFA),        -- 192x96, the flipbook fallback (B + D)
	dewdropStem=f("dewdrop-stem.png",nil,DEWDROP),       -- 192x262, the fruit with a 2 px stem to the top edge
	dapple=f("dapple.png",nil,nil),                       -- 256x256, soft leaf shade, alpha
	koiA=f("koi-a.png",nil,nil),                          -- 128x48, from above: orange and white
	koiB=f("koi-b.png",nil,nil),                          -- 128x48, pale gold
	koiC=f("koi-c.png",nil,nil),                          -- 128x48, slate
	litter=f("litter.png",nil,nil),                       -- 256x256, the four leaves at rest, alpha
	lawnPatchA=f("lawn-patch-a.png",nil,nil),             -- 256x256, mown, grey value, alpha (tinted by the Decal)
	lawnPatchB=f("lawn-patch-b.png",nil,nil),             -- 256x256, clover, grey value, alpha (tinted by the Decal)
	pathFray=f("path-fray.png",nil,nil),                  -- 256x96, dirt breaking into grass along the long side
})

-- The uploaded id, else the fallback (nil: nothing to draw yet).
function Art.id(key)
	local row=Art.Files[key]
	assert(row,"LifeArtR4: no "..tostring(key))
	return row.id or row.fallback
end
-- True once this row's own file is uploaded (the leaf sheet's grid and the stem's size wait for it).
function Art.uploaded(key)
	local row=Art.Files[key]
	return row~=nil and row.id~=nil
end
function Art.pending()
	local out={}
	for key,row in pairs(Art.Files)do if row.id==nil then table.insert(out,key)end end
	table.sort(out)
	return out
end
return table.freeze(Art)
