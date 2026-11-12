-- Six original readable poses; no authority, sound, or independent clock.
local Expression={}
local poses={
 neutral={eye=1,mouth="smile",tilt=0,hand=0,head=0,blush=0},
 curious={eye=1.16,mouth="smile",tilt=.14,hand=.16,head=.025,blush=0},
 startled={eye=1.36,mouth="open",tilt=-.035,hand=-.34,head=.07,blush=0},
 pleased={eye=.58,mouth="smile",tilt=-.065,hand=.3,head=.035,blush=.3},
 sleepy={eye=.18,mouth="line",tilt=.11,hand=-.12,head=-.06,blush=.05},
 affectionate={eye=.12,mouth="soft",tilt=-.08,hand=.48,head=-.025,blush=.8},
}
function Expression.get(name)return poses[name]or poses.neutral end
function Expression.name(visual)
 -- Petting builds: pleased for the first second of a hold, then affectionate.
 -- Visuals without a hold clock (fixtures, captures) keep the old affectionate read.
 if visual.petting and type(visual.pettingHeld)=="number"then return if visual.pettingHeld>=1 then "affectionate"else "pleased"end
 if visual.petting or(visual.affection or 0)>.15 then return "affectionate"end
 return if poses[visual.expression]then visual.expression else "neutral"
end
Expression.poses=table.freeze(poses)
return Expression
