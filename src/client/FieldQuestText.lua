local Stars=require(script.Parent.StarText)
-- Public, sequence-bound presentation only. Never creates/chooses a field.
local HttpService=game:GetService("HttpService")
local Objectives=require(game:GetService("ReplicatedStorage").Shared.FieldObjectives)
local Words=require(game:GetService("ReplicatedStorage").Shared.GoalWords)
local Text={}
Text.NoField=table.freeze({empty=true,key="no-field"})
function Text.valid(value,sequence)
 if not Objectives.validatePublic(value,sequence)then return false end
 if #value.title>80 or #value.dynamics.label>60 then return false end
 for _,goal in ipairs(value.goals)do
  if goal.kind=="merge"and goal.tier==nil and goal.minTier==nil then return false end
 end
 return true
end
function Text.legacy(stage,sequence)
 stage=math.clamp(tonumber(stage)or 0,0,2)
 return{sequence=sequence,templateId="bank_pair",title="Bank pair",dynamics={id="normal",label=""},legacy=true,
  goals={{id="left",kind="merge",minTier=3,zone={kind="left",max=-2.6},target=1},{id="right",kind="merge",minTier=3,zone={kind="right",min=2.6},target=1}},
  step=stage+1,progress=0,target=if stage>=2 then 0 else 1,complete=stage>=2,key="legacy:"..stage}
end
function Text.read(board,cache)
 local raw,sequence,stage=board:GetAttribute("FieldObjective"),board:GetAttribute("RunSequence"),board:GetAttribute("FieldStage")or 0
 if cache.raw==raw and cache.sequence==sequence and(raw~=nil or cache.stage==stage)and cache.read then return cache.value end
 cache.raw,cache.sequence,cache.stage,cache.read=raw,sequence,stage,true
 if raw==nil then cache.value=Text.legacy(stage,sequence);return cache.value end
 if raw==""then cache.value=Text.NoField;return cache.value end
 local ok,value=pcall(cache.decode or function(input)return HttpService:JSONDecode(input)end,raw)
 cache.value=if ok and Text.valid(value,sequence)then value else nil
 if cache.value then cache.value.key=raw end
 return cache.value
end
-- No tier numerals (batch 2026-11-13 R1). `rich` (deck labels with RichText) names a
-- ball with its colour word and a flat colour circle; plain text says "a green ball".
-- Beta 34 QA (Spencer: "the goals need to be clearer"): every line is words (GoalWords,
-- UICopy deck.goal), never the old arrow and plus shorthands ("●↑ LEFT", "●+● RIGHT").
-- Returns the full line and the shorter lines; a merges or chain goal's lines carry " · 1/2" when `progress` is given.
function Text.goal(goal,progress,rich,size)
 if not goal then return "Field loading…",{"Loading…"}end
 local lines=Words.lines(goal,rich,size)
 if progress==nil or(goal.kind~="count"and goal.kind~="chain")then return lines[1],{lines[2],lines[3]}end
 local count=string.format("%d/%d",progress,goal.target or 1)
 return lines[1].." · "..count,{lines[2].." · "..count,lines[3].." · "..count}
end
-- Reserve the same descriptor-derived hint footprint through both stages.
function Text.nextGoalHint(nextGoal)
 return Words.next(nextGoal)
end
function Text.describe(view,phase)
 if not view then return{instruction="Field loading…",candidates={"Field loading…","Loading…"},ticker="",dynamics="",title="Field",zone="any",key="loading"}end
 if view.empty then return{instruction="Field rounds earn Stars",candidates={"Field rounds earn Stars","Earn Stars"},ticker="",dynamics="",title="Field rounds",zone="any",key="no-field"}end
 local full,candidates
 if phase=="Settling"then full="Settling · keep it low";candidates={"Settling…","Settling"}
 elseif view.complete then full=(if #view.goals==3 then "All goals done"else "Both goals done").." · keep it low";candidates={"Goals done ✓","Done ✓","Done"}
 else full,candidates=Text.goal(view.goals[view.step],view.progress)end
 local all={full};for _,caption in ipairs(candidates)do table.insert(all,caption)end
 local dynamics=if view.templateId=="bank_pair"then ""else view.dynamics.label
 local teaser=if view.step==1 and not view.complete then Text.nextGoalHint(view.goals[2])else ""
 return{instruction=full,candidates=all,ticker=(if view.step>1 then "1 ✓"else "1 ○").."   "..(if view.complete then "2 ✓"else "2 ○"),
  nextHint=teaser,dynamics=dynamics,title=view.title,step=view.step,complete=view.complete,zone=if view.complete then "any"else view.goals[view.step].zone.kind,
  goal=if not view.complete then view.goals[view.step]else nil,key=view.key or tostring(view)}
end
function Text.menu(view,phase)
 local copy=Text.describe(view,phase)
 if not view then return copy.instruction end
 if view.empty then return "Complete both goals and 24 drops to earn Stars for eggs."end
 local first=Text.goal(view.goals[1]);local second=Text.goal(view.goals[2])
 return view.title..(if copy.dynamics~=""then " · "..copy.dynamics else "").."\n"..copy.instruction..(if copy.nextHint~=""then "\n"..copy.nextHint else "").."\n"..copy.ticker.."\n1. "..first.."\n2. "..second
end
-- Results use frozen descriptor goals, never scenario/dynamics nicknames.
function Text.results(view,stage)
 if not view or view.empty then return nil end
 local lines={"Goals"}
 for index,goal in ipairs(view.goals)do
  local instruction=Text.goal(goal)
  table.insert(lines,(if index<=(stage or 0)then "✓ "else "○ ")..instruction)
 end
 return table.concat(lines,"\n")
end
function Text.recap(view,stage,reason)
 if view and not view.empty then
  local count=#view.goals
  if stage>=count then return (if count==3 then "All goals done · "else "Both goals done · ")..(if reason=="Overflow"then "clear the overflow line"else "survive all 24 drops")end
  local step=math.clamp(stage+1,1,count)
  local instruction=Text.goal(view.goals[step],if view.step==step then view.progress else nil)
  return "Goal "..step.." unfinished: "..instruction
 end
 return if stage>=2 then "Both goals done · "..(if reason=="Overflow"then "clear the overflow line"else "survive all 24 drops")else "Complete both goals in your next round"
end
return Text
