local Art = require(script.Parent.DeckArt)

local Portrait = {}
local sprites = {
	pip = {
		".............", "....l...l....", "...lll.lll...", "....lllL.....", "....BBBBB....",
		"...BHHMMMB...", "..BHMMMMMMB..", "..BMFMMMFMB..", "..BMMMFMMMB..", "..BDMMMMMDB..",
		"...BDDDDDB...", "....BBBBB....", ".............",
	},
	puddle = {
		".............", ".........BB..", "........BHMB.", "........BDMB.", ".....BBBBMB..",
		"...BBHMMMMB..", "..BHMMMMMMMB.", ".BHMFMMMFMMB.", ".BMMMMFMMMMB.", ".BDMMMMMMMDB.",
		"..BBDDDDDBB..", "....BBBBB....", ".............",
	},
	wick = {
		".............", "......l......", ".....llL.....", "....lLlLL....", "....lLHHl....",
		"...BlllLLB...", "..BHHMMMMMB..", "..BHMMMMMMB..", "..BMFMMMFMB..", "..BDMMFMMDB..",
		"...BDDDDDB...", "....BBBBB....", ".............",
	},
	orbit = {
		"..........H..", ".........HLH.", "....BBBBB.H..", "...BHHMMMB...", "..BHMMMMMMB..",
		"..BMFMMMFMB..", "..BMMMFMMMB..", ".LBMMMMMMMBl.", "LHBMMMMMDlL..", ".LlLllLlLB...",
		"...BDDDDDB...", "....BBBBB....", ".............",
	},
}

function Portrait.create(parent, pet, unit, position, z, locked)
	local color = if locked then Art.Line else pet.color
	local accent = if locked then Art.Muted elseif pet.id == "pip" then Color3.fromHex("#A9E34B")
		elseif pet.id == "wick" then Art.Amber else Art.Cyan
	local sprite = Art.pixels(parent, "Portrait", sprites[pet.id], {
		B = Art.Ink, F = Art.Ink, M = color, H = color:Lerp(Art.Silver, 0.7),
		D = color:Lerp(Art.Ink, 0.38), L = accent:Lerp(Art.Ink, 0.25), l = accent,
	}, unit, position, z)
	sprite.AnchorPoint = Vector2.new(0.5, 0.5)
	return sprite
end

return Portrait
