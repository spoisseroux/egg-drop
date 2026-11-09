local Art = require(script.Parent.DeckArt)

local GardenMaps=require(game:GetService("ReplicatedStorage").Shared.PetPortraitDefinitions)
local Definitions=require(game:GetService("ReplicatedStorage").Shared.PetRigDefinitions)
local Portrait = {}
local sprites = {
	pip = {
		".............", "....l...l....", "...lll.lll...", "....lllL.....", "....BBBBB....",
		"...BHHMMMB...", "..BHMMMMMMB..", "..BMFMMMFMB..", "..BMMMFMMMB..", "..BDMMMMMDB..",
		"...BDDDDDB...", "....BBBBB....", ".............",
	},
	bloom_pip = {
		"......o......", ".....oOo.....", "...l..o..l...", "....lllLl....", "....BBBBB....",
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
	foxfire_wick = {
		"...l.....l...", "...lL...Ll...", "...llL.Lll...", "....lHLHl....", "....lllll....",
		"...BLLLLLB...", "..BHHMMMMMB..", "..BHMMMMMMB..", "..BMFMMMFMB..", "..BDMMFMMDB..",
		"...BDDDDDB...", "....BBBBB....", ".............",
	},
	orbit = {
		"..........H..", ".........HLH.", "....BBBBB.H..", "...BHHMMMB...", "..BHMMMMMMB..",
		"..BMFMMMFMB..", "..BMMMFMMMB..", ".LBMMMMMMMBl.", "LHBMMMMMDlL..", ".LlLllLlLB...",
		"...BDDDDDB...", "....BBBBB....", ".............",
	},
	eclipse_orbit = {
		".........ll..", "........lBB..", "....BBBBBlB..", "...BHHMMMB...", "..BHMMMMMMB..",
		"..BMFMMMFMB..", "l.BMMMFMMMB.l", "llBMMMMMMMBlL", ".llMMMMMDlll.", "...lllllll...",
		"...BDDDDDB...", "....BBBBB....", ".............",
	},
}

sprites.pip=GardenMaps.zivvi;sprites.puddle=GardenMaps.ovelle

function Portrait.create(parent, pet, unit, position, z, locked)
	local color = if locked then Art.Line else pet.color
	local accent = if locked then Art.Muted elseif pet.id == "pip" then Color3.fromHex("#A9E34B")
		elseif pet.accent then pet.accent elseif pet.id == "wick" then Art.Amber else Art.Cyan
	local colors = {
		B = Art.Ink, F = Art.Ink, M = color, H = color:Lerp(Art.Silver, 0.7),
		D = color:Lerp(Art.Ink, 0.38), L = accent:Lerp(Art.Ink, 0.25), l = accent,
		o = color, O = if locked then Art.Line else Art.Amber,
	}
 local definition=Definitions[pet.id]
 if definition then
  local p=definition.palette;local secondary=Color3.fromHex(p.secondary)
  colors.M=color;colors.H=color:Lerp(Art.Silver,.45);colors.D=if locked then Art.Muted else Color3.fromHex(p.blush)
  colors.F=if locked then Art.Ink else Color3.fromHex(p.face);colors.I=if locked then Art.Line else Color3.fromHex(p.ivory)
  colors.S=if locked then Art.Muted else secondary;colors.L=colors.S:Lerp(Art.Ink,.25)
 end
 local sprite=Art.pixels(parent,"Portrait",sprites[pet.id],colors,unit,position,z)
	sprite.AnchorPoint = Vector2.new(0.5, 0.5)
	return sprite
end

return Portrait
