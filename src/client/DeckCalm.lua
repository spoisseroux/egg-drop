-- G2 (G2-FIRST-SESSION-LOOK 2026-11-25 section 3, switch FeatureFlags.CalmFirstDeck): a calmer Welcome-round deck.
-- Pure: from the live HUD cards' rects, which cards hide and where the coach card and the egg go. DeckScreen applies
-- it in setWelcome (saved and restored per HUD instance); the board rect and the play hit areas never move.
--  * Hidden: Score, Chain, the Daily quests card or quest handle, Difficulty, Win pays, Controls (and, in DeckScreen,
--    the THEN balls and a chain counter that lives in another card's header).
--  * The coach card (Goals) grows down over the freed slots of its column, to the column foot.
--  * The egg (Eggs left) grows over the Difficulty and Win pays slots; the Controls slot stays empty.
--  * One column (layout "one"): the coach card and the egg share the column under the top row, egg under the words.
--  * The coach card's line reads at the spec's title size: 20 px on PC and tablet, 16 on a phone. (The card holds one
--    line, the step prompt, under the GOALS tab; the tab keeps its size.)
local Calm={}
Calm.Hidden=table.freeze({"Score","Chain","DailyQuests","QuestHandle","Difficulty","WinPays","Controls"})
Calm.Gap=8
Calm.NextCut=.4
Calm.TextPC=20;Calm.TextPhone=16

-- Is the Welcome round's calm screen wanted? Exactly the Welcome round on a save with no pet.
function Calm.wanted(snapshot,flags)
	return flags~=nil and flags.CalmFirstDeck==true and type(snapshot)=="table"and snapshot.phase=="Welcome"and(snapshot.owned or 0)==0
end
local function overlaps(a,b)return a.x<b.x+b.w and b.x<a.x+a.w end
local function bottom(r)return r.y+r.h end
-- cards: {name = {x, y, w, h}} for the cards this HUD built. Returns {hide = {names}, coach = rect, egg = rect} (a
-- rect is nil when that card is missing).
function Calm.plan(layout,cards)
	local hide={}
	for _,name in ipairs(Calm.Hidden)do if cards[name]then table.insert(hide,name)end end
	local coach,egg=cards.Goals,cards.EggsLeft
	if not coach or not egg then return{hide=hide}end
	if layout=="one"then
		local foot=bottom(coach)
		for _,name in ipairs({"EggsLeft","Difficulty","WinPays","QuestHandle","DailyQuests"})do
			local r=cards[name];if r and r.y>=coach.y then foot=math.max(foot,bottom(r))end
		end
		local room=foot-coach.y-Calm.Gap
		-- Too short to keep the coach card's own height and a 44 px egg under it: hide the panels, move nothing.
		if room<coach.h+44 then return{hide=hide}end
		local top=math.min(math.max(coach.h,math.floor(room*.5)),room-44)
		return{hide=hide,coach={x=coach.x,y=coach.y,w=coach.w,h=top},egg={x=coach.x,y=coach.y+top+Calm.Gap,w=coach.w,h=foot-(coach.y+top+Calm.Gap)}}
	end
	local coachFoot=bottom(coach)
	for _,name in ipairs({"DailyQuests","QuestHandle","Chain","Score"})do
		local r=cards[name];if r and r.y>=coach.y and overlaps(r,coach)then coachFoot=math.max(coachFoot,bottom(r))end
	end
	local eggFoot=bottom(egg)
	for _,name in ipairs({"Difficulty","WinPays"})do
		local r=cards[name];if r and r.y>=egg.y and overlaps(r,egg)then eggFoot=math.max(eggFoot,bottom(r))end
	end
	local plan={hide=hide,coach={x=coach.x,y=coach.y,w=coach.w,h=coachFoot-coach.y},egg={x=egg.x,y=egg.y,w=egg.w,h=eggFoot-egg.y}}
	-- The First Hatch (Fable MUST 4): the NEXT card right above the egg gives it 40% of its height (it shows one ball).
	local nextCard=cards.Next
	-- (up to 40%, never leaving its ball under 24 px: card height minus 16 of padding; code review)
	local cut=if nextCard then math.min(math.floor(nextCard.h*Calm.NextCut),nextCard.h-40)else 0
	if nextCard and overlaps(nextCard,egg)and bottom(nextCard)<=egg.y and cut>=8 then
		plan.next={x=nextCard.x,y=nextCard.y,w=nextCard.w,h=nextCard.h-cut}
		plan.egg.y-=cut;plan.egg.h+=cut
	end
	return plan
end
function Calm.textSize(phone)return if phone then Calm.TextPhone else Calm.TextPC end
return table.freeze(Calm)
