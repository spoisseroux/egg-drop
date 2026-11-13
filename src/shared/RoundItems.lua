-- Round items (ROUND-ITEMS-AND-BALL-THEMES-SCOPE A, BUILD-PLAN 2026-11-13 items 3-7).
-- Shared catalogue and pure rules: which queue slots carry a power-up (star) ball
-- and which item each one grants. The plan uses its own random stream (seed +
-- StarOffset), so a round's ball queue is identical with or without items.
-- Items live on a 3-slot belt for one round only; nothing here is saved.
local Items={}
Items.BeltSize=3
-- Fixed order: weighted picks walk it, so a seed always gives the same item.
Items.Order=table.freeze({"swap","pop","bomb","magnet"})
Items.ById=table.freeze({
	swap=table.freeze({id="swap",name="Swap",effect="Next and Then trade places.",short="Next and Then swap.",
		color=Color3.fromHex("#3DDCC4"),glyph="⇄",arms=false}),
	pop=table.freeze({id="pop",name="Pop",effect="Removes the highest ball. No points.",short="Removes the top ball.",
		color=Color3.fromHex("#F5D54A"),glyph="✦",arms=false}),
	bomb=table.freeze({id="bomb",name="Bomb",effect="Your next ball bursts on landing and clears a small circle.",short="Next ball clears a circle.",
		color=Color3.fromHex("#FF9A3D"),glyph="●",arms=true}),
	magnet=table.freeze({id="magnet",name="Magnet",effect="Your next ball pulls its matches in.",short="Next ball pulls matches.",
		color=Color3.fromHex("#FF6F8E"),glyph="∪",arms=true}),
})
-- Item icons (QA 2026-11-13): uploaded ids for assets/ui/items/<id>.png
-- (scripts/build_item_icons.py). Empty until uploaded: ItemIcons draws the same
-- icon with Frames. Put "rbxassetid://..." strings here after the upload.
Items.IconImages=table.freeze({swap="rbxassetid://88437337795835",pop="rbxassetid://79285689955133",bomb="rbxassetid://97237247094508",magnet="rbxassetid://128316412669129"}) -- assets/ui/items/*.png (QA 2026-11-13)
-- Scope A3: power-up balls per round, earliest drop and item odds per heat.
Items.Heat=table.freeze({
	easy=table.freeze({count=2,earliest=5,odds=table.freeze({pop=35,swap=30,bomb=20,magnet=15})}),
	medium=table.freeze({count=2,earliest=5,odds=table.freeze({swap=30,pop=30,magnet=25,bomb=15})}),
	hard=table.freeze({count=1,earliest=8,odds=table.freeze({swap=40,magnet=30,pop=20,bomb=10})}),
})
Items.Latest=20 -- No star on the last few drops: an item there could never be used.
Items.StarOffset=7919
-- Effects. Bomb: centres within the bomb's radius + `reach`, nearest first, at most `max`.
Items.Bomb=table.freeze({reach=2.2,max=4})
Items.Magnet=table.freeze({seconds=2,reach=3,pull=26})

function Items.valid(id)
	return type(id)=="string"and Items.ById[id]~=nil
end

-- Map of queue index (1-based, = drop number in a 24-drop field) to item id.
function Items.plan(seed,heat,budget)
	local spec=Items.Heat[heat]
	if type(seed)~="number"or seed~=seed or not spec then return {}end
	budget=budget or 24
	local random=Random.new((math.floor(seed)+Items.StarOffset)%2147483647)
	local open={}
	for index=spec.earliest,math.min(Items.Latest,budget)do table.insert(open,index)end
	local total=0
	for _,id in ipairs(Items.Order)do total+=spec.odds[id]or 0 end
	local plan={}
	for _=1,math.min(spec.count,#open)do
		local slot=table.remove(open,random:NextInteger(1,#open))
		local roll=random:NextInteger(1,total)
		for _,id in ipairs(Items.Order)do
			roll-=spec.odds[id]or 0
			if roll<=0 then plan[slot]=id;break end
		end
	end
	return plan
end

-- The belt travels as a comma list ("swap,pop"); unknown ids are dropped.
function Items.encodeBelt(belt)
	return table.concat(belt or {},",")
end
function Items.decodeBelt(text)
	local belt={}
	if type(text)~="string"then return belt end
	for id in string.gmatch(text,"[^,]+")do
		if Items.valid(id)and #belt<Items.BeltSize then table.insert(belt,id)end
	end
	return belt
end

return table.freeze(Items)
