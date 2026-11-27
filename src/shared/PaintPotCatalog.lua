-- Paint pots (artifacts/qa-2026-11-27-beta37/PAINT-SHINE-DRESS-PLAN.md, Fable's CUSTOMIZE-AUDIT). Shared and pure.
-- A pot is a hue jar bought outright at one fixed price: the server adds it to `hueInventory` (the field an egg jar
-- fills) and painting is the existing `hueUse`. Its receipt lives in its own optional save field (PaintPotState),
-- never in the Customization Egg's receipt ring, so every older build still loads a save that holds one.
-- Tunable: Price, ReceiptLimit, PerMinute. Frozen stored bounds (never retuned down): Prices, StoredLimit, IdLimit,
-- DigestLimit. Prices only grows: a stored receipt keeps the price it was charged.
local Hue=require(script.Parent.HueCatalog)
local Catalog={
	Price=15, -- [PLACEHOLDER] Stars (Fable's suggestion, unconfirmed by Spencer): one constant
	Prices=table.freeze({[15]=true}),
	Items=table.freeze(table.clone(Hue.RollOrder)), -- rose, tide, citrus, iris
	ReceiptLimit=16, -- receipts this build keeps (oldest dropped)
	StoredLimit=64, -- frozen: the most receipts any build may store (a newer build may keep more than 16)
	IdLimit=100, -- frozen: an operation id's length
	DigestLimit=120, -- frozen: lastOperation.digest's bound in HatchProgress.validBase
	PerMinute=20, -- pot buys per player per minute (the DataStore write budget)
	Window=60,
}
local items={};for _,id in ipairs(Catalog.Items)do items[id]=true end
function Catalog.isItem(id)return type(id)=="string"and items[id]==true end
-- The digest that binds an operation id to its arguments (HatchProgress lastOperation.digest).
function Catalog.digest(itemId,price)return "pot:"..tostring(itemId)..":"..tostring(price)end
assert(#Catalog.digest("citrus",999999)<=Catalog.DigestLimit)
-- Pure rate rule: `times` (os.clock values, oldest first) is trimmed to the window; true when one more fits.
function Catalog.allow(times,now,limit,window)
	limit=limit or Catalog.PerMinute;window=window or Catalog.Window
	while #times>0 and now-times[1]>=window do table.remove(times,1)end
	if #times>=limit then return false end
	table.insert(times,now);return true
end
return table.freeze(Catalog)
