-- The Wardrobe's colour selector (ROTATION-BRIEF 2, ARCH-REVIEW-ROTATION 13; Spencer: "add a colour selector to the
-- clothes"): a swatch row in the pane, one round swatch per owned colour of the focused card's base. A tap wears that
-- colour through the existing equip call (wearableEquip), no server change. Each tap is a DataStore write, so one swatch
-- equip is in flight at a time and the last tap wins: taps while one is saving replace each other in one queued slot,
-- and the queued one is sent when the save in flight answers (dropped when it would change nothing).
-- Pure (no instances, no services): WardrobeShop owns the orders' display (replayEquips); the specs drive this alone.
local Swatches={}
Swatches.__index=Swatches
Swatches.Size=28 -- px, the brief's swatch
Swatches.Gap=8
Swatches.Ring=2 -- the worn swatch's ring

function Swatches.new()return setmetatable({inflight=nil,queued=nil},Swatches)end
-- A tap. Returns the order to send now, or nil when it waits (one already in flight: it takes the queued slot, and an
-- earlier queued tap is dropped, returned second so its display can be undone).
function Swatches:tap(order)
 if type(order)~="table"then return nil end
 if self.inflight==nil then self.inflight=order;return order,nil end
 local dropped=self.queued
 self.queued=order
 return nil,dropped
end
-- A result for order `id`. Returns (next order to send or nil, true) when it was the one in flight; (nil, false) for
-- any other id. `changes(order)` (optional): false drops the queued order (it would wear what is already worn).
function Swatches:settle(id,changes)
 if self.inflight==nil or self.inflight.id~=id then return nil,false end
 self.inflight=nil
 local nextOrder=self.queued;self.queued=nil
 if nextOrder and changes and changes(nextOrder)==false then nextOrder=nil end
 self.inflight=nextOrder
 return nextOrder,true
end
-- Every order not yet answered, oldest first (the one in flight, then the queued one): what the pet shows on top of
-- the last confirmed look.
function Swatches:open()
 local list={}
 if self.inflight then table.insert(list,self.inflight)end
 if self.queued then table.insert(list,self.queued)end
 return list
end
function Swatches:busy()return self.inflight~=nil end
function Swatches:clear()self.inflight,self.queued=nil,nil end

-- Pure layout: swatch x offsets (left edges) for `count` swatches in a row `width` px wide, centred when they fit.
-- Returns {x...}, canvas width (the row scrolls sideways when it is wider than `width`).
function Swatches.layout(count,width)
 local step=Swatches.Size+Swatches.Gap
 local need=math.max(0,count*step-Swatches.Gap)
 local left=if need<=width then math.floor((width-need)/2)else 0
 local xs={}
 for i=1,count do xs[i]=left+(i-1)*step end
 return xs,math.max(width,need)
end
-- Pure: the swatch's accessible label ("Mint Pom Beanie, wearing").
function Swatches.label(item,worn)
 local name=type(item)=="table"and item.name or ""
 return if worn then name..", wearing"else name
end
return Swatches
