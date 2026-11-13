-- One public evaluator for previews and server validation; no backwards imports.
local Themes=require(script.Parent.DeckThemes)
local Stickers=require(script.Parent.DeckStickers)
local Backgrounds=require(script.Parent.DeckBackgrounds)
local Mastery=require(script.Parent.FamilyMastery)
local Eggs=require(script.Parent.EggCatalog)
local Trials=require(script.Parent.PocketTrials)
local Catalog={}
function Catalog.facts(profile,hatch)
	profile,hatch=profile or {},hatch or {}
	local ranks=hatch.masteryRanks or {}
	if not hatch.masteryRanks and hatch.mastery then
		for _,family in ipairs(Eggs.Families)do ranks[family]=Mastery.rank(hatch.mastery[family]or 0,(hatch.masteryChallenges or {})[family]or 0)end
	end
	return {rank=profile.rank or 0,trials=profile.trials or 0,inventoryMask=hatch.inventoryMask,
		totalWins=hatch.totalWins or 0,masteryRanks=ranks,faceplates=hatch.faceplates}
end
local definitions={free={text="Available",target=1},firstWin={text="Win one saved field round",target=1},
	rankI={text="Win 3 saved field rounds",target=3},rankII={text="Win 10 saved field rounds",target=10},
	highRoller={text="Complete High Roller: score 250 in one round",target=1},chain3={text="Complete Triple Pop: chain 3 merges",target=1},
	trials={text="Complete all three Pocket Trials",target=3},stars={text="Buy with Stars",target=1},
	book={text="Fill any three collection book pages",target=1}}
-- Bought faceplates: a bounded list of ids saved in the hatching record.
function Catalog.ownsFaceplate(facts,id)
	local owned=facts and facts.faceplates
	return type(owned)=="table"and table.find(owned,id)~=nil
end
local function maximumRank(facts)
	local highest=0
	for _,family in ipairs(Eggs.Families)do
		if facts.inventoryMask~=nil and Mastery.ownsFamily(facts.inventoryMask,family)then
			local rank=(facts.masteryRanks or {})[family]
			if type(rank)=="number"and rank==rank and rank%1==0 and rank>=0 and rank<=3 then highest=math.max(highest,rank)end
		end
	end
	return highest -- Legacy finishes do not fabricate mastery for new cosmetics.
end
function Catalog.describeRequirement(slot,id,facts)
	facts=facts or {}
	local collection=if slot=="theme"then Themes elseif slot=="sticker"then Stickers elseif slot=="background"then Backgrounds else nil
	local item=collection and collection.ById[id]
	if not item then return {rule="invalid",text="Unknown appearance",progress=0,target=1,unlocked=false}end
	local rule=item.rule or "free"
	local definition=definitions[rule]
	if not definition then return {rule="invalid",text="Unknown requirement",progress=0,target=1,unlocked=false}end
	local trials=Trials.mask(facts.trials)
	local progress=1
	if rule=="firstWin"then
		local wins=facts.totalWins;progress=if type(wins)=="number"and wins==wins and wins>=0 and wins%1==0 then math.min(wins,1)else 0
	elseif rule=="rankI"or rule=="rankII"then
        local historical=maximumRank(facts)>=(if rule=="rankI"then 1 else 2)
        local wins=facts.totalWins
        progress=if historical then definition.target elseif type(wins)=="number"and wins==wins and wins>=0 and wins%1==0 then math.min(wins,definition.target)else 0
	elseif rule=="highRoller"then progress=if bit32.band(trials,Trials.HighRoller.bit)~=0 then 1 else 0
	elseif rule=="chain3"then progress=if bit32.band(trials,Trials.Goals[1].bit)~=0 then 1 else 0
	elseif rule=="stars"or rule=="book"then progress=if Catalog.ownsFaceplate(facts,id)then 1 else 0
	elseif rule=="trials"then progress=0;for _,goal in ipairs(Trials.Goals)do if bit32.band(trials,goal.bit)~=0 then progress+=1 end end end
	return {rule=rule,text=definition.text,progress=math.min(progress,definition.target),target=definition.target,unlocked=progress>=definition.target}
end
function Catalog.canEquip(slot,id,facts)return Catalog.describeRequirement(slot,id,facts).unlocked end
return Catalog
