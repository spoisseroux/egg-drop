-- Presentation must never reuse a prior run's equal-value receipt or promotion.
local Receipt = {}
local QuestCopy=require(script.Parent.FieldQuestText)
local Shared=game:GetService("ReplicatedStorage").Shared
local Pets=require(Shared.PetCatalog)
local Mastery=require(Shared.FamilyMastery)
function Receipt.select(state, sequence, status, isOver)
	if not isOver or status ~= "Saved" or type(sequence) ~= "number" then return nil end
	local reward = state and state.lastRunReward
	if type(reward) ~= "table" or reward.sequence ~= sequence then return nil end
	return reward
end
-- A delayed presentation snapshot cannot lock deliberate sequence-bound replay.
-- The server still decides whether its durable payout/hatch owners permit it.
function Receipt.replaySequence(sequence,status,starter)
	if type(sequence)~="number"or sequence~=sequence or sequence<1 or sequence%1~=0 then return nil end
	return if starter or status=="Saved"then sequence else nil
end
function Receipt.outcome(result)
	if result.reason=="Overflow"then return "Overflow"end
	if result.success then return "Round complete"end
	return string.format("%d of 2 goals",math.clamp(result.stage or 0,0,2))
end
function Receipt.questHint(result)
 return QuestCopy.recap(if result.objective and result.objective.sequence==result.sequence then result.objective else nil,result.stage or 0,result.reason)
end
function Receipt.questDetails(result)
 if not result.objective or result.objective.sequence~=result.sequence then return nil end
 return QuestCopy.menu(result.objective,result.phase)
end
function Receipt.familyName(family)
	local pet=Pets.byId[family];return if pet then pet.name else "Family"
end
function Receipt.promotion(reward)
	local rank=reward and reward.promotedTo;local name=rank and Mastery.Names[rank]
	if not name then return nil end
	return string.format("%s reached %s · Rank %s",Receipt.familyName(reward.family),name,({"I","II","III"})[rank])
end
return Receipt
