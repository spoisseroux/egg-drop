-- Original readable poses; no authority, sound, or independent clock.
-- content (sitting), joy (owner back, greet after a while, a win) and dozy (the
-- first seconds of dropping off) were added by FEEL-ALIVE-DIRECTION-2026-11-13 B2.
local Expression={}
local poses={
 neutral={eye=1,mouth="smile",tilt=0,hand=0,head=0,blush=0},
 curious={eye=1.16,mouth="smile",tilt=.14,hand=.16,head=.025,blush=0},
 startled={eye=1.36,mouth="open",tilt=-.035,hand=-.34,head=.07,blush=0},
 pleased={eye=.58,mouth="smile",tilt=-.065,hand=.3,head=.035,blush=.3},
 sleepy={eye=.18,mouth="line",tilt=.11,hand=-.12,head=-.06,blush=.05},
 affectionate={eye=.12,mouth="soft",tilt=-.08,hand=.48,head=-.025,blush=.8},
 content={eye=.78,mouth="soft",tilt=.09,hand=.2,head=0,blush=.25},
 joy={eye=.5,mouth="open",tilt=-.04,hand=.45,head=.05,blush=.5},
 dozy={eye=.5,mouth="line",tilt=.06,hand=-.05,head=-.03,blush=.05},
}
function Expression.get(name)return poses[name]or poses.neutral end
function Expression.name(visual)
 -- Petting builds: pleased for the first second of a hold, then affectionate.
 -- Visuals without a hold clock (fixtures, captures) keep the old affectionate read.
 if visual.petting and type(visual.pettingHeld)=="number"then return if visual.pettingHeld>=1 then "affectionate"else "pleased"end
 if visual.petting or(visual.affection or 0)>.15 then return "affectionate"end
 -- Joy: the owner is back from a round (RoomView sets joyUntil on the visual clock).
 if visual.joyUntil and(visual.time or 0)<visual.joyUntil then return "joy"end
 return if poses[visual.expression]then visual.expression else "neutral"
end
-- Garden rest faces (B2): a rest is no longer sleepy from its first second.
-- Content while sitting through a rest under 20 s, dozy for the next 3 s, then
-- sleepy. At night (daylight under 0.3) or while the owner plays the deck: dozy
-- for 3 s, then sleepy. Not resting: the replicated face as is.
Expression.RestContent,Expression.RestDozy,Expression.Night=20,23,.3
function Expression.garden(face,resting,age,daylight,ownerOnDeck)
 if not resting then return face or "neutral"end
 age=if type(age)=="number"and age==age then math.max(0,age)else 0
 if(type(daylight)=="number"and daylight<Expression.Night)or ownerOnDeck then return if age<3 then "dozy"else "sleepy"end
 if age<Expression.RestContent then return "content"end
 if age<Expression.RestDozy then return "dozy"end
 return "sleepy"
end
Expression.poses=table.freeze(poses)
return Expression
