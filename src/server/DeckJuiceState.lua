-- Deck juice, server side (V3-LEVELS-BUILD-PLAN-2026-11-22, S3). The host's settings action
-- `deckJuice {kind, id}` calls choose and saves the returned map with Progress.setSetting; the board
-- attribute (DeckJuiceCatalog.Attribute) is publish. Levels come from the save, never an attribute.
-- Cosmetic only: nothing here touches the board, the sim or the wallet.
local Shared=game:GetService("ReplicatedStorage").Shared
local Catalog=require(Shared.DeckJuiceCatalog)
local Gate=require(Shared.LevelGate)
local Levels=require(Shared.Levels)
local Stats=require(script.Parent.StatState)

local State={Throttle=.25,FlushGap=5}
-- True (and noted on the board) when a choice may ask for a save now: at most one per FlushGap. The sweep
-- and the leave save take the rest, so the last choice is always kept.
function State.flushDue(board,now)
	if board.juiceFlushAt and now-board.juiceFlushAt<State.FlushGap then return false end
	board.juiceFlushAt=now
	return true
end
function State.levels(state)
	return Gate.levels(Stats.publicLevels(state).pets)
end
-- The map to save for this choice, or nil and why. `saved` is profile.deckJuice (nil = all classic).
function State.choose(saved,state,kind,id)
	if not Levels.on("juice")then return nil,"Off"end
	if not Catalog.known(kind,id)then return nil,"Unknown"end
	if not Catalog.unlocked(kind,id,State.levels(state))then return nil,"NeedsLevel"end
	local map=Catalog.decode(saved)or {}
	local value=if id==Catalog.Classic then nil else id
	if map[kind]==value then return nil,"NoChange"end
	map[kind]=value
	-- Catalog.decode keeps this build's kinds first, so the map stays inside its bound.
	return Catalog.decode(map)or {}
end
-- The public choice every client draws, or nil (no attribute) while the part is off.
function State.public(saved,state)
	if not Levels.on("juice")then return nil end
	return Catalog.resolve(saved,State.levels(state))
end
return State
