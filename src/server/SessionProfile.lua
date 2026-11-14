local Shared = game:GetService("ReplicatedStorage").Shared
local Catalog = require(Shared.EggCatalog)
local Stickers = require(Shared.DeckStickers)
local Themes = require(Shared.DeckThemes)
local Backgrounds = require(Shared.DeckBackgrounds)
local Appearance = require(Shared.AppearanceCatalog)
local Progress = require(script.Parent.PlayerProgress)
local Pets = require(Shared.PetCatalog)
local Session = {}
-- Slice E (overnight 2026-11-14): "the companion" is any owned pet that is active in this
-- build, never a literal id. Order is Pets.active (the Bear first), so today's saves behave
-- exactly as before; an owned pet whose rig is gone (flag off, rollback) is never equipped.
function Session.firstOwnedActive(mask)
	for _, pet in ipairs(Pets.active) do
		if Catalog.isOwned(mask, pet.id) then return pet.id end
	end
	return nil
end
function Session.hasActivePet(mask)
	return Session.firstOwnedActive(mask) ~= nil
end
-- True when `petId` may be the companion: owned and renderable in this build. Retained
-- legacy pets (owned, no longer active) still have their rigs and stay usable, exactly as
-- before; only an earned pet whose gate is closed (EarnedPets.enabled false: flag off, or
-- its rig removed by a rollback) is refused, so an unrenderable companion is never equipped.
function Session.usable(mask, petId)
	local pet = if type(petId) == "string" then Pets.byId[petId] else nil
	return pet ~= nil and Catalog.isOwned(mask, petId) and (pet.earned ~= true or Pets.isActive(petId))
end
function Session.ready(handle, busy)
	return handle.status == "Ready" and not busy
end
function Session.hydrate(profile, handle)
	if not Session.ready(handle) or not handle.profileRecord
		or not Progress.hydrate(profile, handle.profileRecord) then return false end
	local mask = handle.state.inventoryMask
	local companion = handle.companionId or profile.companionId
	profile.companionId = if Session.usable(mask, companion) then companion
		else Session.firstOwnedActive(mask)
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
