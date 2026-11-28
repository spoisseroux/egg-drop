-- Field goals as plain instructions (beta 34 QA, Spencer: "the goals need to be clearer"). One goal descriptor
-- (FieldObjectives) becomes three word lines, longest first: the full sentence, a short one and a tiny one. Every
-- line is words a kid can follow ("Make a green ● or bigger on the left"); no arrows, no plus signs, no caps zone
-- codes. The wording says what FieldRun:observe checks:
--   merge, minTier: a merge that makes that ball or a bigger one, with the merge point inside the zone
--   merge, tier:    a merge that makes exactly that ball inside the zone (center_ii: two of the ball below it)
--   count:          that many merges anywhere
--   chain:          that many merges in a row, each within the chain window of the one before (BoardRoundSim)
-- Pure: no instances. Words come from UICopy (deck.goal), ball names from BallThemes. `rich` draws the ball as its
-- colour circle after its colour word ("a green ●"); plain text says "a green ball" (spoken labels, the menu, recaps).
local UICopy=require(script.Parent.UICopy)
local BallThemes=require(script.Parent.BallThemes)
local Words={}
Words.Zones=table.freeze({left=true,right=true,center=true,any=true})

-- English first letter up or down (the lines are sentences; a template may start with a ball).
local function upper(text)return(string.gsub(text,"^%l",string.upper))end
function Words.lowerFirst(text)return(string.gsub(text,"^%u",string.lower))end

local function zoneOf(goal)
	local kind=type(goal.zone)=="table"and goal.zone.kind or "any"
	return if Words.Zones[kind]then kind else "any"
end
local function article(word)return if string.find(word,"^[aeiou]")then "an "else "a "end
-- The ball names a line uses. `rich`: "a green ●", "green ●", "●"; plain: "a green ball", "green ball", "green".
local function names(tier,rich,size)
	local word=BallThemes.word(tier)
	if rich then
		local circle=BallThemes.circle(tier,size)
		return{a=article(word)..word.." "..circle,bare=word.." "..circle,mark=circle,many=word.." "..circle}
	end
	return{a=article(word)..word.." ball",bare=word.." ball",mark=word,many=word.." balls"}
end

-- {full, short, tiny} for a goal. `count` (optional) is the "1/2" progress text the full line carries.
function Words.lines(goal,rich,size)
	local zone=zoneOf(goal)
	local where=UICopy.get("deck.goal.where."..zone)
	local whereTiny=UICopy.get("deck.goal.whereTiny."..zone)
	local target=goal.target or 1
	if goal.kind=="count"then
		return{UICopy.get("deck.goal.merges",{count=target,where=where}),UICopy.get("deck.goal.short.merges",{count=target,where=where}),
			UICopy.get("deck.goal.tiny.merges",{count=target})}
	elseif goal.kind=="chain"then
		return{UICopy.get("deck.goal.chain",{count=target}),UICopy.get("deck.goal.short.chain",{count=target}),
			UICopy.get("deck.goal.tiny.chain",{count=target})}
	end
	local tier=math.clamp(goal.tier or goal.minTier or 1,1,5)
	local ball=names(tier,rich,size)
	local tiny=upper(UICopy.get("deck.goal.tiny.make",{ball=ball.mark,where=whereTiny}))
	-- center_ii teaches the merge itself: two of the ball below make this one.
	if goal.tier and goal.id=="center_ii"and tier>1 then
		local small=names(tier-1,rich,size)
		return{UICopy.get("deck.goal.match",{small=small.many,where=where}),upper(UICopy.get("deck.goal.short.match",{small=small.many,where=where})),tiny}
	end
	local key=if goal.minTier then "deck.goal.makeUp"else "deck.goal.make"
	return{UICopy.get(key,{ball=ball.a,where=where}),upper(UICopy.get("deck.goal.short.make",{ball=ball.bare,where=where})),tiny}
end

-- Beta 44 note 7 (ONBOARD-SIMPLIFY-BRIEF 3): the Goals card draws the target ball itself, so its words drop the colour
-- word and the dot: "Green ● on the left" is [ball] "on the left", "Make a green ● or bigger on the left" is [ball]
-- "or bigger, on the left", center_ii's "Match two yellow ●" is [the smaller ball] "Match two, in the middle".
-- -> {tier, words = {line, short}} for a goal with a ball, or nil (merges and chains keep their lines). The spoken
-- label stays the full sentence (Words.lines, plain).
function Words.ball(goal)
	if type(goal)~="table"or(goal.kind~=nil and goal.kind~="merge")then return nil end
	if goal.tier==nil and goal.minTier==nil then return nil end
	local zone=zoneOf(goal)
	local where=UICopy.get("deck.goal.where."..zone)
	local whereTiny=UICopy.get("deck.goal.whereTiny."..zone)
	local tier=math.clamp(goal.tier or goal.minTier or 1,1,5)
	if goal.tier and goal.id=="center_ii"and tier>1 then
		return{tier=tier-1,words={UICopy.get("deck.goal.ball.match",{where=where}),UICopy.get("deck.goal.ball.match",{where=whereTiny})}}
	end
	local key=if goal.minTier then "deck.goal.ball.makeUp"else "deck.goal.ball.make"
	return{tier=tier,words={UICopy.get(key,{where=where}),UICopy.get(key,{where=whereTiny})}}
end

-- "Next, make a green ball or bigger in the middle" (FieldQuestText.nextGoalHint, plain).
function Words.next(goal)
	if not goal then return ""end
	return UICopy.get("deck.goal.next",{goal=Words.lowerFirst(Words.lines(goal,false)[1])})
end

-- The first line that `fits` (longest first); the last one when none does (it is the shortest).
function Words.pick(lines,fits)
	for _,line in ipairs(lines)do if fits(line)then return line end end
	return lines[#lines]
end
-- How many wrapped lines fit a box `h` px tall at `size` px text (Kit.LineHeight 1.25), at least 1.
function Words.linesIn(h,size,lineHeight)
	local line=math.ceil(size*(lineHeight or 1.25))
	return math.max(1,math.floor((h+1)/line))
end

return table.freeze(Words)
