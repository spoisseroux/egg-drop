-- Where Back from the Get Stars page goes (live fixes 2026-11-22, LIVE-FIXES-PLAN).
-- Spencer 2026-11-21: "when i click back or x it goes back to hatch eggs screen even if i
-- wasn't there before". The store route captures what was open before it closes every menu;
-- Back from the store reopens it, or leaves the player in the garden.
--
--   Route.capture(deps) -> true (the garden, or the machine hub through machineReturn)
--                       -> a function that reopens the screen (true when it opened)
--
-- deps (init.client.lua; specs pass fakes):
--   hubOpen()                     the machine hub (Pocket menu) is open: machineReturn handles it
--   canReopen()                   the store route's own gate, checked again on Back
--   getMachineReturn(), setMachineReturn(id)
--   screens[kind] = {isOpen(), capture() -> args | nil, open(args)}  kinds in Route.Order
--   wardrobe = {isOpen(), petId(), open(petId)}  opens over a base screen or alone
-- A screen whose capture() is nil cannot be reopened as it was: the garden.
local Route = {}
Route.Order = table.freeze({ "names", "stats", "hue", "hub", "book", "quests", "picker" })
-- The machine hub tile each screen belongs to: the way back it keeps.
Route.Machine = table.freeze({ names = "companions", stats = "companions", hue = "companions", hub = "companions", book = "book" })

function Route.capture(deps)
	if deps.hubOpen() then return true end
	local base, args
	for _, kind in ipairs(Route.Order) do
		if deps.screens[kind].isOpen() then
			base, args = kind, deps.screens[kind].capture()
			if args == nil then return true end
			break
		end
	end
	local overlayPet
	if deps.wardrobe.isOpen() then overlayPet = deps.wardrobe.petId() end
	if not base and not overlayPet then return true end
	local saved = deps.getMachineReturn()
	return function()
		if not deps.canReopen() then return false end
		if base then
			deps.screens[base].open(args)
			-- Asked of the screen itself: the open calls do not all return the same thing.
			if not deps.screens[base].isOpen() then return false end
			-- After the open: opens and closes clear it, and a stale one would misroute a later Back.
			if saved ~= nil and saved == Route.Machine[base] then deps.setMachineReturn(saved) end
		end
		if overlayPet then deps.wardrobe.open(overlayPet) end
		return true
	end
end

return Route
