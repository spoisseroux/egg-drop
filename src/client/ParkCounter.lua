-- Park counter (QA v735 W2): "Pets playing 3/9" above the Menu + Deck dock while the owner is
-- inside a park, and "Park full · 9/9" (plus a pointer to the other park when it has room) once
-- every play slot is spoken for. Pure census and layout; ParkThrowControl owns the gui.
-- The count is park membership from the garden snapshot (actor.parkId, set by ParkDirector);
-- capacity is the number of slots at the site, one pet per slot.
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Copy=require(ReplicatedStorage.Shared.UICopy)
local Counter={}
Counter.Pad=10        -- the pill sizes to its text (AutomaticSize X), so translations fit
Counter.LineHeight=26 -- one line; the other-park pointer adds Counter.LineExtra
Counter.LineExtra=18
Counter.Gap=8         -- between the dock, the Throw button and the counter
Counter.ThrowHeight=48
Counter.DockHeight=48 -- RoomView: Room.DockHeight

function Counter.capacity(site)
	local slots=0
	for _ in pairs(site and site.Slots or {})do slots+=1 end
	return slots
end

-- Pets whose park membership is `siteId`. actors: the garden snapshot actor table.
function Counter.members(actors,siteId)
	local count=0
	for _,actor in pairs(actors or {})do
		if type(actor)=="table"and actor.parkId==siteId then count+=1 end
	end
	return count
end

-- sites: ParkLayout.Sites. Returns {count, capacity, full, other = the first other site with
-- room (or nil), text, lines}. A crowd past capacity still reads capacity/capacity.
-- quiet (beta (17) U1, HudChips.on()): only "Park full" speaks; a park with room has no text (nil) and no pill.
function Counter.status(actors,site,sites,quiet)
	local capacity=Counter.capacity(site)
	local count=Counter.members(actors,site.Id)
	local full=capacity>0 and count>=capacity
	local status={count=math.min(count,capacity),capacity=capacity,full=full,lines=1}
	if not full then
		status.text=if quiet then nil else Copy.get("park.count",{count=status.count,capacity=capacity})
		return status
	end
	for _,candidate in ipairs(sites or {})do
		if candidate.Id~=site.Id and Counter.members(actors,candidate.Id)<Counter.capacity(candidate)then status.other=candidate;break end
	end
	status.text=Copy.get("park.full",{count=status.count,capacity=capacity})
	if status.other then status.text..="\n"..Copy.get("park.otherHasRoom");status.lines=2 end
	return status
end

-- Stacks above the dock, never beside it. dock: the dock Position (AnchorPoint 1,1). Returns the
-- Throw button Position, the counter Position (both AnchorPoint 1,1, right edges on the dock
-- right edge) and the counter height. The counter rests on the dock while Throw is hidden.
function Counter.layout(dock,throwShown,lines)
	local top=dock.Y.Offset-Counter.DockHeight-Counter.Gap
	local throw=UDim2.new(dock.X.Scale,dock.X.Offset,dock.Y.Scale,top)
	if throwShown then top-=Counter.ThrowHeight+Counter.Gap end
	local height=Counter.LineHeight+(if lines and lines>1 then Counter.LineExtra else 0)
	return throw,UDim2.new(dock.X.Scale,dock.X.Offset,dock.Y.Scale,top),height
end

return Counter
