local Shared = game:GetService("ReplicatedStorage").Shared
local Catalog = require(Shared.EggCatalog)
local Stickers = require(Shared.DeckStickers)
local Progress = require(script.Parent.PlayerProgress)
local Session = {}
function Session.ready(handle, busy)
	return handle.status == "Ready" and not busy
end
function Session.hydrate(profile, handle)
	if not Session.ready(handle) or not handle.profileRecord
		or not Progress.hydrate(profile, handle.profileRecord) then return false end
	local mask = handle.state.inventoryMask
	local companion = handle.companionId or profile.companionId
	profile.companionId = if Catalog.isOwned(mask, companion) then companion
		elseif Catalog.isOwned(mask, "pip") then "pip" else nil
	if not Stickers.canEquip(profile.sticker, profile.rank, profile.trials, mask) then profile.sticker = Stickers.Default end
	return true
end
return Session
