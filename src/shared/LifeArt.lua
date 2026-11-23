-- Garden life round 3 and the nest remodel: every new texture in one table (GARDEN-LIFE-NEST-BUILD-PLAN section 1;
-- look artifacts/qa-2026-11-23-beta12/GARDEN-LIFE-NEST-LOOK.md section 0). Files are drawn by
-- scripts/draw_garden_life_r3_textures.py into artifacts/qa-2026-11-23-beta12/look/. Until a file is uploaded its id
-- is nil and LifeArt.id answers the fallback (an asset already uploaded, so every build draws something); after the
-- upload, write the id in the second argument of its row. All 21 uploaded 2026-11-23 (Studio MCP upload_image;
-- artifacts/qa-2026-11-23-beta12/look/UPLOADED-IDS.md). `python scripts/check_life_art.py` is the publish gate: the
-- files exist, match the draw script's output byte for byte, and no row is still nil. Pure data, shared, no services.
local Art={}
Art.Folder="artifacts/qa-2026-11-23-beta12/look"

-- Fallbacks: the round 2 textures these replace.
local WING="rbxassetid://108754043011076"   -- LOOK-R2 butterfly wing
local WINGM="rbxassetid://95949019207820"   -- its mirror
local BIRD="rbxassetid://81512459364906"    -- LOOK-R2 bird wing
local PETAL="rbxassetid://112974880714881"  -- petal.png (kept: the petal leaves still use it)
local SPARK="rbxasset://textures/particles/sparkles_main.dds"
local WEAVE="rbxassetid://118690234276511"  -- NEST-LOOK nest-weave
local LEAVES="rbxassetid://130921787854357" -- NEST-LOOK nest-leaves
local FLAG="rbxassetid://96303130180036"    -- NEST-LOOK nest-flag

-- f(file, uploaded id or nil, fallback or nil). One row a line: check_life_art.py reads them.
local function f(file,id,fallback)return table.freeze({file=file,id=id,fallback=fallback})end
Art.Files=table.freeze({
	butterflyAmber=f("butterfly-amber.png","rbxassetid://74783484307475",WING),
	butterflyAmberM=f("butterfly-amber-m.png","rbxassetid://129309332650822",WINGM),
	butterflyChalk=f("butterfly-chalk.png","rbxassetid://108103787837203",WING),
	butterflyChalkM=f("butterfly-chalk-m.png","rbxassetid://133655004070442",WINGM),
	butterflyDusk=f("butterfly-dusk.png","rbxassetid://89264657038084",WING),
	butterflyDuskM=f("butterfly-dusk-m.png","rbxassetid://108877398850794",WINGM),
	butterflyMeadow=f("butterfly-meadow.png","rbxassetid://97012836929609",WING),
	butterflyMeadowM=f("butterfly-meadow-m.png","rbxassetid://93666115933637",WINGM),
	fireflyDot=f("firefly-dot.png","rbxassetid://132656608030953",SPARK),
	leafA=f("leaf-a.png","rbxassetid://140368108993906",PETAL),
	leafB=f("leaf-b.png","rbxassetid://72030778503926",PETAL),
	birdWingEmber=f("bird-wing-ember.png","rbxassetid://127995636660272",BIRD),
	birdWingSlate=f("bird-wing-slate.png","rbxassetid://100209288786680",BIRD),
	birdWingMoss=f("bird-wing-moss.png","rbxassetid://121336291472645",BIRD),
	birdTail=f("bird-tail.png","rbxassetid://133808257711794",BIRD),
	birdBreast=f("bird-breast.png","rbxassetid://133640796586694",nil), -- no stand-in: the decal is not made while pending (the plain body colour)
	nestTwigs=f("nest-twigs.png","rbxassetid://107570749391882",WEAVE),
	nestFringe=f("nest-fringe.png","rbxassetid://105548698351715",LEAVES),
	strawBed=f("straw-bed.png","rbxassetid://117260148385157",nil),       -- no stand-in: the bed disc's own colour
	strawWisps=f("straw-wisps.png","rbxassetid://90480864928418",LEAVES),
	nestSign=f("nest-sign.png","rbxassetid://102082089670183",FLAG),
})
Art.Petal=PETAL

-- The uploaded id, else the fallback; nil only for a pending row with no stand-in (birdBreast, strawBed).
function Art.id(key)
	local row=Art.Files[key]
	assert(row,"LifeArt: no "..tostring(key))
	return row.id or row.fallback
end
-- Keys still waiting for their upload, sorted.
function Art.pending()
	local out={}
	for key,row in pairs(Art.Files)do if row.id==nil then table.insert(out,key)end end
	table.sort(out)
	return out
end
return table.freeze(Art)
