local Stars=require(script.Parent.StarText)
-- Public, sequence-bound presentation only. Never creates/chooses a field.
local HttpService=game:GetService("HttpService")
local Objectives=require(game:GetService("ReplicatedStorage").Shared.FieldObjectives)
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
local marks={"I","II","III","IV","V"}
function Text.goal(goal,progress)
 if not goal then return "Field loading…",{"Loading…"}end
 local zone=goal.zone.kind;local place=if zone=="center"then "in CENTER"elseif zone=="any"then "anywhere"else "on "..zone:upper()
 if goal.kind=="count"then
  if progress==nil then return "Make "..goal.target.." merges anywhere",{}end
  local count=string.format("%d/%d",progress,goal.target)
  return "Make "..goal.target.." merges anywhere · "..count,{"Merge "..count,"Merges "..count}
 elseif goal.kind=="chain"then
  if progress==nil then return "Connect "..goal.target.." new merges in one chain",{}end
  local count=string.format("%d/%d",progress,goal.target)
  return "Connect "..goal.target.." new merges in one chain · "..count,{"Link "..count,"Chain "..count}
 end
 local tier=goal.tier or goal.minTier;local mark=marks[tier]
 local full=if goal.tier==2 and goal.id=="center_ii"then "Match I + I "..place else "Make "..mark..(if goal.minTier then " or higher "else " ")..place
 local pair=if tier>1 then marks[tier-1].."+"..marks[tier-1]else mark
 local candidates={}
 if goal.minTier then
  table.insert(candidates,mark.."+ "..zone:upper())
  if zone=="left"then table.insert(candidates,"←"..mark.."+")elseif zone=="right"then table.insert(candidates,mark.."+→")end
 end
 table.insert(candidates,pair.." "..zone:upper())
 if zone=="left"then table.insert(candidates,"←"..pair)elseif zone=="right"then table.insert(candidates,pair.."→")elseif zone=="center"then table.insert(candidates,pair.." mid")end
 return full,candidates
end
-- Reserve the same descriptor-derived hint footprint through both stages.
function Text.nextGoalHint(nextGoal)
 if not nextGoal then return ""end
 if nextGoal.kind=="chain"then return "Next, link two new merges in one chain"end
 if nextGoal.kind=="count"then return "Next, make two merges anywhere"end
 local tier=nextGoal.tier or nextGoal.minTier
 return "Next, make "..marks[tier]..(if nextGoal.minTier then "+"else "")..(if nextGoal.zone.kind=="center"then " in CENTER"else " on "..nextGoal.zone.kind:upper())
end
function Text.describe(view,phase)
 if not view then return{instruction="Field loading…",candidates={"Field loading…","Loading…"},ticker="",dynamics="",title="Field",zone="any",key="loading"}end
 if view.empty then return{instruction="Field rounds earn Stars",candidates={"Field rounds earn Stars","Earn Stars"},ticker="",dynamics="",title="Field rounds",zone="any",key="no-field"}end
 local full,candidates
 if phase=="Settling"then full="Settling · keep it low";candidates={"Settling…","Settling"}
 elseif view.complete then full="Both goals done · keep it low";candidates={"Goals done ✓","Done ✓","Done"}
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
function Text.recap(view,stage,reason)
 if view and not view.empty then
  if stage>=2 then return "Both goals done · "..(if reason=="Overflow"then "clear the overflow line"else "survive all 24 drops")end
  local step=math.clamp(stage+1,1,2)
  local instruction=Text.goal(view.goals[step],if view.step==step then view.progress else nil)
  return view.title.." · goal "..step.." unfinished: "..instruction
 end
 return if stage>=2 then "Both goals done · "..(if reason=="Overflow"then "clear the overflow line"else "survive all 24 drops")else "Complete both goals in your next round"
end
return Text
