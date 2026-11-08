local Trials = require(script.Parent.PocketTrials)
local StickerArt=require(script.Parent.DeckStickerArt)

local Stickers = {
	Default = "none",
	Order = { "none", "star", "glitch", "seed", "wick", "club", "lantern" },
	ById = {
		none = { name = "Blank" },
		star = { name = "Star", mark = "★", color = Color3.fromHex("#F5CD74"), ink = Color3.fromHex("#493313") },
		glitch = { name = "Glitch", mark = "+", color = Color3.fromHex("#A4D4C1"), ink = Color3.fromHex("#203A35") },
		seed = { name = "Seed", mark = "◆", color = Color3.fromHex("#EAA48C"), ink = Color3.fromHex("#462824") },
		wick = { name = "Wick", mark = "▲", color = Color3.fromHex("#F9AB63"), ink = Color3.fromHex("#532C2B"), rank = 3 },
		club = { name = "Trial crest", mark = "✦", color = Color3.fromHex("#81D6C4"), ink = Color3.fromHex("#163D38"), trials = true },
		lantern = {name="Lantern stamp",mark="✧",color=Color3.fromHex("#FFD47D"),ink=Color3.fromHex("#563A28"),rule="chain3"},
	},
}

function Stickers.canEquip(id, rank, trials, inventoryMask)
	if id=="lantern"then return bit32.band(Trials.mask(trials),Trials.Goals[1].bit)~=0 end
	local sticker = Stickers.ById[id]
	local rankAllowed = sticker and (sticker.rank or 0) <= rank
	if id == "wick" and inventoryMask ~= nil then rankAllowed = bit32.band(inventoryMask, 4) ~= 0 end
	return sticker ~= nil and rankAllowed and (not sticker.trials or Trials.clubComplete(trials))
end

Stickers.printSeat=StickerArt.printSeat
Stickers.layoutPrint=StickerArt.layoutPrint

function Stickers.paint(host,id)
	StickerArt.paint(host,if Stickers.ById[id]then id else Stickers.Default)
end


return Stickers
