-- Deck style as a closet (rotation slice 2, lane D; ROTATION-2-BRIEF 2 "Deck style with the switch on", ARCH-REVIEW-
-- ROTATION-2 6 and 7). Pure rules the Shell (FaceplateShop) and Balls (BallShop) tabs share, so the specs can run them
-- offline (scripts/run_dash_server_specs.py, DeckCloset.spec).
--
-- The switch: DailyRack.on("rack") and DailyRack.on("deck") (rack_deck, attribute RackDeck_on; lane A adds the "deck"
-- part). An unknown part is off in DailyRack.on, so a build without lane A's switch sells exactly as today.
-- With it on:
--   from the egg  a plate or ball theme sold at a fixed price with no level gate (the Deck Egg's 12 plates and 11 themes).
--                 Owned: wearable as before. Not owned: "From the Deck Egg" and one button, "More at the Deck Egg"
--                 (the owner's deckEgg callback: init.client opens Hatch eggs on the Deck Egg tile). No price, no buy.
--   still earned  starters, Book plates, backgrounds: exactly as before.
--   still sold    the level-goal rows (Sky Fizz, Storm Glass, Tangerine Pop) at their full fixed price: no weekly-shelf
--                 deal while the closet is on (the server hides the plate and ball deals too).
--   copy          the footer's "Fixed prices. No random plates." becomes "Plates you own stay yours."; no clock anywhere.
-- Off: nil from every rule here, and the shops are exactly today's.
local Shared=game:GetService("ReplicatedStorage").Shared
local Plates=require(Shared.DeckThemes)
local Balls=require(Shared.BallThemes)
local UICopy=require(Shared.UICopy)
local Closet={}

-- The closet's words: UICopy keys (lane B owns UICopy; each falls back to its English until the key lands).
Closet.Copy=table.freeze({
	fromEgg={"rack.deck.fromEgg","From the Deck Egg"},
	go={"rack.deck.more","More at the Deck Egg"},
	tile={"rack.deck.title","Deck Egg"},
	promise={"rack.deck.promise","Plates you own stay yours."},
	reason={"rack.deck.reason","Plates and balls come from the Deck Egg now."},
})
function Closet.copy(name)
	local row=Closet.Copy[name];if not row then return ""end
	return if UICopy.has(row[1])then UICopy.get(row[1])else row[2]
end

-- Is the closet on right now? Both the rack and its deck part (a missing part is off).
function Closet.on()
	local ok,Rack=pcall(require,Shared.DailyRack)
	if not ok or type(Rack)~="table"or type(Rack.on)~="function"then return false end
	local fine,value=pcall(function()return Rack.on("rack")==true and Rack.on("deck")==true end)
	return fine and value==true
end
-- A ctx's closet flag: an explicit boolean wins (specs, or an owner that passes it), else the switch now.
function Closet.resolve(value)
	if type(value)=="boolean"then return value end
	return Closet.on()
end

local catalogs={plate=Plates,ball=Balls}
-- Does this row come from the Deck Egg while the closet is on? Sold at a fixed price, no level gate, not Book-only.
function Closet.fromEgg(kind,id)
	local catalog=catalogs[kind];if not catalog then return false end
	local entry=catalog.ById[id];if not entry then return false end
	if entry.gate~=nil or entry.bookOnly==true then return false end
	return catalog.price(id)~=nil
end
-- Every Deck Egg row of a kind, in catalogue order (the brief's 12 plates and 11 ball themes).
function Closet.eggIds(kind)
	local catalog=catalogs[kind];if not catalog then return {}end
	local out={}
	for _,id in ipairs(catalog.Order)do if Closet.fromEgg(kind,id)then table.insert(out,id)end end
	return out
end

-- Pure: the pane's status for a row the player does not own, or nil (the shop's own rules then apply).
-- `closet` true only: the switch is read by the shop object, never here.
function Closet.status(kind,id,owned,closet)
	if closet~=true or owned==true or not Closet.fromEgg(kind,id)then return nil end
	return {kind="egg",text=Closet.copy("fromEgg"),button=Closet.copy("go"),enabled=true}
end
-- Pure: the card's status line for an egg row.
function Closet.tileStatus()return Closet.copy("tile"),"soft"end
-- Pure: the shelf week a quote uses. The closet shows no weekly deal on plates or balls (false = no shelf).
function Closet.week(closet,week)
	if closet==true then return false end
	return week
end
-- Pure: the Shell tab's footer line.
function Closet.promise(closet,fallback)
	if closet==true then return Closet.copy("promise")end
	return fallback
end
-- Pure: words for a server refusal of a direct buy while the closet is on (lane A's reason), else nil.
function Closet.reason(reason)
	if reason=="FromDeckEgg"then return Closet.copy("reason")end
	return nil
end

return table.freeze(Closet)
