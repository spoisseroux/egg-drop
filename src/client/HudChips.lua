-- Beta (17) QA U1 (artifacts/qa-2026-11-25-beta17/CAPSULE-AND-HUD-LOOK.md section 2): the HUD chips. Pure rules shared
-- by ParkClient (the play date ticket), ParkThrowControl (the park counter) and NestClient (the egg ticket):
--  * The rail's status slot shows one thing at a time, by priority: "Hatch egg!" > the Play date (only while inside a
--    park, ParkClient's `active`) > the egg's clock. NotificationQueue picks the highest priority active provider, so
--    a ready egg takes the slot at once with the rail's normal entrance. The race line (2) and the first-spend guide
--    (1) stay above all three: a ready egg never covers a race.
--  * The play date ticket says "Play date 1/3 · +4 ★" (the Things page's name; 3 is the day's target, not a limit; the
--    reward is the snapshot's own `reward`, ParkActivities only as the fallback). A top bar under 600 px drops the reward.
--  * (beta 17) The park counter kept only "Park full"; beta (26) brings the always-on "Pets playing 3/9" back (Spencer).
-- Beta only: on() is Things to do on (the beta place or Studio, and its switch). Off, the live game is unchanged: "Games
-- 0/3" and "Pets playing 3/9". The egg ticket needs no gate of its own: the nest is only ever on where Things is.
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Shared=ReplicatedStorage:WaitForChild("Shared")
local Things=require(Shared:WaitForChild("Things"))
local UICopy=require(Shared:WaitForChild("UICopy"))
local Activities=require(Shared:WaitForChild("ParkActivities"))
local Chips={}
Chips.NarrowDate=600 -- px of free top bar: under this the play date drops "· +4 ★" (NotificationRail.NarrowBar)
Chips.NarrowEgg=360  -- px of free top bar: under this the egg ticket drops the word "Egg"
Chips.Priority=table.freeze({ready=.5,date=-100,clock=-200})
function Chips.on()return Things.on()end
-- Pure: is a top bar `width` px wide narrower than `limit`? (0 or unknown: not narrow.)
function Chips.narrow(width,limit)
	return type(width)=="number"and width>0 and width<limit
end
-- Pure: the play date's numbers, each clamped and defaulted.
function Chips.date(date)
	date=if type(date)=="table"then date else {}
	local target=if type(date.target)=="number"and date.target>0 then date.target else Activities.PlayDate.Target
	local reward=if type(date.reward)=="number"and date.reward>=0 then date.reward else Activities.PlayDate.Reward
	local count=if type(date.count)=="number"then math.clamp(math.floor(date.count),0,target)else 0
	return{count=count,target=target,reward=reward,done=date.done==true or count>=target}
end
-- Pure: which line. `pending`: park games still saving; `playing`: the owner's pet is in a park game now.
function Chips.dateState(date,pending,playing)
	if Chips.date(date).done then return "done"end
	if type(pending)=="number"and pending>0 then return "saving"end
	if playing then return "playing"end
	return "games"
end
-- Pure: the ticket's words for the state (dateState) on a top bar that is `narrow` (Chips.narrow(w, NarrowDate)).
function Chips.dateText(date,state,narrow)
	local vars=Chips.date(date)
	if state=="done"then return UICopy.get("park.date.done",vars)end
	if state=="saving"then return UICopy.get("park.date.saving",vars)end
	if state=="playing"then return UICopy.get("park.date.playing",vars)end
	return UICopy.get(if narrow then "park.playDate"else "park.date.games",vars)
end
-- Pure (Fable R13 5, captures 02c, 02e, 05b, 05c): the notification rail (the egg ticket with it) is off the screen
-- while a full-screen screen is up: a menu or the Hatch eggs screen with its reveal and result card (init's
-- anyModalOpen, the same test the cursor and the movement lock use) and the capsule shot. state = {on, modal, shot}.
-- Beta only: `on` is Chips.on(); off, the rail stays above game menus as on live.
-- Beta 18 (the Stat Egg rail): `reveal`, any hatch reveal stage is up wherever it opened (the Stat Egg, Names Egg and
-- medals over the garden, the arrival hatch, the toy and pet reveals; Chips.revealUp), a Hatch another handover too.
function Chips.hideRail(state)
	return type(state)=="table"and state.on==true and(state.modal==true or state.shot==true or state.reveal==true)
end
-- Pure: is any reveal stage up? `sets`: the stage modules' live sets (HatchItemStage.live, RevealStage.live: stage ->
-- true); a stage counts while it is not destroyed and shown(stage.root) says its root is on the screen (init passes
-- CelebrationKit.onScreen, so a stage a host keeps hidden never holds the rail off).
function Chips.revealUp(sets,shown)
	if type(sets)~="table"or type(shown)~="function"then return false end
	for _,set in ipairs(sets)do
		if type(set)=="table"then
			for stage in pairs(set)do
				if type(stage)=="table"and stage.destroyed~=true and stage.root~=nil then
					local ok,up=pcall(shown,stage.root)
					if ok and up==true then return true end
				end
			end
		end
	end
	return false
end
return table.freeze(Chips)
