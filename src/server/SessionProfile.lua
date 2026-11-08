local Shared = game:GetService("ReplicatedStorage").Shared
local Catalog = require(Shared.EggCatalog)
local Stickers = require(Shared.DeckStickers)
local Themes = require(Shared.DeckThemes)
local Backgrounds = require(Shared.DeckBackgrounds)
local Appearance = require(Shared.AppearanceCatalog)
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
	local facts=Appearance.facts(profile,handle.state)
	profile.appearanceFallbacks=profile.appearanceFallbacks or {}
	for slot,default in pairs({theme=Themes.Default,sticker=Stickers.Default,background=Backgrounds.Default})do
		if not Appearance.canEquip(slot,profile[slot],facts)then
			profile.appearanceFallbacks[slot]="Locked";profile[slot]=default
		end
	end
	return true
end
return Session
