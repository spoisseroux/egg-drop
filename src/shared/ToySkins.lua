-- STUB (rotation slice 2, lane C): the toy colours' rows only, written to ROTATION-2-BRIEF section 1 so the client lane
-- builds and its specs run. Lane A owns this module (the deal, the snapshot, the save); lane A's version wins at merge.
-- The client reads it only through src/client/ToySkinLook.lua (ById, Order, row fields id/toy/colour/name/hex/rarity/part).
--
-- 6 toys x 4 colours = 24 rows, ids "<toy>_<colour>". The original colour is never a row (the swatch row's first swatch).
-- `part` is the one named part a colour tints; every other part keeps its colours so the toy still reads as itself.
local Skins={Version=1}
local rows={
	{"ball","FeltBall",{{"sky","Sky","#5CBEF5","common"},{"bubblegum","Bubblegum","#FF86C8","uncommon"},{"midnight","Midnight","#2F2C7C","rare"},{"gold","Gold","#F0B429","epic"}}},
	{"bone","BoneBody",{{"mint","Mint","#7FE0CF","common"},{"grape","Grape","#9B7BE8","uncommon"},{"midnight","Midnight","#2F2C7C","rare"},{"gold","Gold","#F0B429","epic"}}},
	{"sparkler","IndigoGrip",{{"cherry","Cherry","#E9574C","common"},{"mint","Mint","#7FE0CF","uncommon"},{"grape","Grape","#9B7BE8","rare"},{"rose_gold","Rose Gold","#F2A0A8","epic"}}},
	{"wobble_top","TealBody",{{"cherry","Cherry","#E9574C","common"},{"grape","Grape","#9B7BE8","uncommon"},{"midnight","Midnight","#2F2C7C","rare"},{"gold","Gold","#F0B429","epic"}}},
	{"squeaky_carrot","CarrotBody",{{"butter","Butter","#FFD86B","common"},{"grape","Grape","#9B7BE8","uncommon"},{"snow","Snow","#F4F6FB","rare"},{"gold","Gold","#F0B429","epic"}}},
	{"pocket_deck","DeckShell",{{"sky","Sky","#5CBEF5","common"},{"bubblegum","Bubblegum","#FF86C8","uncommon"},{"midnight","Midnight","#2F2C7C","rare"},{"gold","Gold","#F0B429","epic"}}},
}
local toyNames={ball="Ball",bone="Bone",sparkler="Sparkler",wobble_top="Wobble Top",squeaky_carrot="Squeaky Carrot",pocket_deck="Pocket Deck"}
local names={squeaky_carrot_grape="Purple Carrot"}
local order,byId,parts={},{},{}
for _,toy in ipairs(rows)do
	local toyId,part,colours=toy[1],toy[2],toy[3]
	parts[toyId]=part
	for _,c in ipairs(colours)do
		local id=toyId.."_"..c[1]
		local row=table.freeze({id=id,toy=toyId,colour=c[2],name=names[id]or(c[2].." "..toyNames[toyId]),hex=c[3],rarity=c[4],part=part})
		table.insert(order,id);byId[id]=row
	end
end
Skins.Order=table.freeze(order)
Skins.ById=table.freeze(byId)
Skins.Parts=table.freeze(parts)
Skins.OwnedLimit=64
function Skins.get(id)return if type(id)=="string"then byId[id]else nil end
return table.freeze(Skins)
