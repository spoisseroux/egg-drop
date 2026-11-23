-- The v3 Pocket Deck results look (beta 12 QA U7, DASH-DECK-UI-LOOK): the build ceiling for the in-place results'
-- compact action stack, the restyled payout pane and the See you tomorrow strip under the three panes. Held to the beta
-- place or Studio (architect review 2026-11-23: U7 waits for the v3 release); off, DeckResultsInPlace is the game
-- before this build, path for path. Pure: no instances, no connections.
local RunService=game:GetService("RunService")
local Look={}
Look.PlaceId=107705084891479 -- Pocket Pals Beta
Look.Ceiling=true           -- the build switch: false puts every place back on the old results
-- env = {place, studio, ceiling} for specs; the game passes nothing.
function Look.on(env)
	env=env or {}
	local ceiling=env.ceiling
	if ceiling==nil then ceiling=Look.Ceiling end
	if ceiling~=true then return false end
	local studio=env.studio
	if studio==nil then
		local ok,value=pcall(function()return RunService:IsStudio()end)
		studio=ok and value==true
	end
	return(env.place or game.PlaceId)==Look.PlaceId or studio==true
end
return table.freeze(Look)
