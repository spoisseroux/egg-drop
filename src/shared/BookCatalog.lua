-- Collection book (PLAY-FOREVER-SCOPE-2026-11-13 2.3 / 3.5 #4, BUILD-PLAN F1 + architect
-- changes 1, 3, 4). Six pages whose items come from the live catalogues; ownership is
-- read from lists the save already holds. Each page pays once at 25 / 50 / 75 / 100 %
-- (5 / 5 / 10 / 15 Stars, 35 a page, 210 in total). Milestone ids are "<page>.<pct>"
-- and are never reused. Finishing any three pages grants the book-only faceplate.
--
-- Counting rules:
--   * Only ids in the current catalogues count. Unknown or retired ids on a save are
--     ignored (a retired toy pool item or a later catalogue id never inflates a page).
--   * Free / starter items (free ball themes, starter faceplates) are not pages items:
--     everyone has them, so they would hand out milestones for nothing.
--   * The book-only faceplate is listed on the Faceplates page (`bookOnly`) but is not
--     part of its total, so finishing that page never depends on finishing three others.
--   * A catalogue that grows can drop a page below a claimed milestone; claims stay.
local Shared=script.Parent
local Balls=require(Shared.BallThemes)
local Plates=require(Shared.DeckThemes)
local Wear=require(Shared.WearableCatalog)
local Toys=require(Shared.ToyCatalog)
local Finishes=require(Shared.MaterialCatalog)
local Pets=require(Shared.PetCatalog)
local Eggs=require(Shared.EggCatalog)
local Daily=require(Shared.DailyContracts)
local Objectives=require(Shared.FieldObjectives)
local Park=require(Shared.ParkActivities)

local Book={Version=1}
Book.BookOnlyFaceplate="bookworm"
Book.StargazerPlate="stargazer"
Book.StargazerMilestone="discoveries.100"
Book.Steps=table.freeze({25,50,75,100})
Book.Rewards=table.freeze({[25]=5,[50]=5,[75]=10,[100]=15})
Book.PagesForFaceplate=3
Book.MaxBit=30 -- LifetimeState caps `found` at 2^31-1 (architect change 4).
-- The Pets page opens once a second pet exists (2026-11-13): with only the Bear it is
-- 100% for everyone past onboarding, a free 35 Stars and a free step toward Bookworm.
-- Its milestone ids ("pets.25" ...) are reserved for then and never reused.
Book.PetsPageMin=2
Book.PageOrder=table.freeze(if #Pets.active>=Book.PetsPageMin
	then {"balls","faceplates","wardrobe","toys","pets","discoveries"}
	else {"balls","faceplates","wardrobe","toys","discoveries"})
local names={balls="Balls",faceplates="Faceplates",wardrobe="Wardrobe",toys="Toys",pets="Pets",discoveries="Discoveries"}

-- Discoveries: fixed bit numbers, never renumbered. Set only inside the round award
-- (LifetimeState.recordRun). A field template is the round's goal type; its bit is
-- fixed here so adding a template later only adds a new bit.
local templateBits={bank_pair=2,creek_crossing=3,lantern_chain=4,ripple_relay=5,bank_bounce=6,mirror_marks=7}
local heatBits={easy=8,medium=9,hard=10}
local discoveries={
	{id="tier_five",bit=0,name="Make a tier V ball"},
	{id="chain_five",bit=1,name="Chain 5 merges"},
}
for _,template in ipairs(Objectives.Order)do
	local bit=templateBits[template]
	if bit then
		table.insert(discoveries,{id="win_"..template,bit=bit,template=template,
			name="Win a "..Objectives.create(template,1).title.." field"})
	end
end
for _,heat in ipairs({"easy","medium","hard"})do
	table.insert(discoveries,{id="win_"..heat,bit=heatBits[heat],heat=heat,
		name="Win on "..string.upper(string.sub(heat,1,1))..string.sub(heat,2)})
end
-- Slice D (overnight 2026-11-14): six more, bits 11..16 (ids from VISUAL-BRIEF 3). These are
-- derived from the save after any committed write (Book.stateBits), not from a round, so a
-- player who already qualifies earns them on the next save. `state=true` marks them.
Book.FullOutfitSlots=5
Book.TidyWins=25
Book.RoundsPlayed=100
Book.ItemKindsMask=15 -- swap, pop, bomb, magnet (RoundItems): stats.itemWinKinds
Book.NightFromHour,Book.NightUntilHour=20,6
for _,entry in ipairs({
	{id="pet_night",bit=11,name="Pet your pet at night"},
	{id="play_date",bit=12,name="Finish a Play date"},
	{id="full_outfit",bit=13,name="Wear a full outfit"},
	{id="win_each_item",bit=14,name="Win with each item type"},
	{id="tidy_25",bit=15,name="25 tidy wins"},
	{id="rounds_100",bit=16,name="Play 100 rounds"},
})do entry.state=true;table.insert(discoveries,entry)end
do
	local used={}
	for _,entry in ipairs(discoveries)do
		assert(entry.bit>=0 and entry.bit<=Book.MaxBit and not used[entry.bit],"BookCatalog: bad discovery bit "..entry.id)
		used[entry.bit]=true;table.freeze(entry)
	end
end
Book.Discoveries=table.freeze(discoveries)
Book.DiscoveryById={};for _,entry in ipairs(discoveries)do Book.DiscoveryById[entry.id]=entry end
table.freeze(Book.DiscoveryById)

local function bitOf(n)return bit32.lshift(1,n)end
local function has(mask,n)return type(mask)=="number"and mask==mask and mask>=0 and bit32.band(mask,bitOf(n))~=0 end
local function listHas(list,id)return type(list)=="table"and table.find(list,id)~=nil end

-- Bits a saved round earns (run = the validated award summary, heat = its stored heat).
function Book.runBits(run,heat)
	if type(run)~="table"then return 0 end
	local mask=0
	if run.maxTier==5 then mask=bit32.bor(mask,bitOf(0))end
	if type(run.chain)=="number"and run.chain>=5 then mask=bit32.bor(mask,bitOf(1))end
	if run.success==true then
		local t=type(run.templateId)=="string"and templateBits[run.templateId]
		if t then mask=bit32.bor(mask,bitOf(t))end
		local h=heatBits[heat or "medium"]
		if h then mask=bit32.bor(mask,bitOf(h))end
	end
	return bit32.band(mask,2^31-1)
end

-- The garden's real hour (0..24) at a unix time: the fixed world timezone the day clock
-- uses (EggCatalog.DayOffsetSeconds, UTC-5; the same formula as the client's HollowClock.cycle).
-- Real even while the DayNight flag locks the visuals to dusk (SYSTEMS-SCOPE 8 #9).
function Book.hour(unix)
	return ((if type(unix)=="number"and unix==unix then unix else 0)+Eggs.DayOffsetSeconds)/3600%24
end
function Book.isNight(unix)
	local hour=Book.hour(unix)
	return hour>=Book.NightFromHour or hour<Book.NightUntilHour
end
local function count(value)return if type(value)=="number"and value==value and value>=0 then value else 0 end
-- Distinct wardrobe slots a pet wears (a pair counts once; ids this build does not sell count 0).
function Book.outfitSlots(petId,equipped)
	if type(petId)~="string"or type(equipped)~="table"then return 0 end
	local byId=Wear.forPet(petId,math.huge).byId
	local seen,total={},0
	for _,itemId in pairs(equipped)do
		local item=type(itemId)=="string"and byId[itemId]
		if item and not seen[item.slot]then seen[item.slot]=true;total+=1 end
	end
	return total
end
-- Discovery bits the save itself has earned (slice D). Pure; call it on the state a write
-- is about to commit, with the same `now` the write reads:
--   Book.stateBits(state, now, signature?)
-- `signature` is the transaction signature (optional). pet_night needs the pet write itself:
-- with a signature it must start with "pet:"; without one the pet receipt must belong to
-- this write (lastPetAward.sequence is operationSeq or operationSeq+1).
function Book.stateBits(state,now,signature)
	if type(state)~="table"then return 0 end
	local mask=0
	local function set(n)mask=bit32.bor(mask,bitOf(n))end
	local receipt=state.lastPetAward
	if type(receipt)=="table"and type(now)=="number"and now==now then
		local fresh
		if type(signature)=="string"then fresh=string.sub(signature,1,4)=="pet:"
		else
			local seq=count(state.operationSeq)
			fresh=receipt.sequence==seq or receipt.sequence==seq+1
		end
		if fresh and receipt.day==Daily.dayOf(now)and Book.isNight(now)then set(11)end
	end
	local play=state.playDate
	if type(play)=="table"and count(play.count)>=Park.PlayDate.Target then set(12)end
	if type(state.petWearables)=="table"then
		for petId,row in pairs(state.petWearables)do
			if type(row)=="table"and Book.outfitSlots(petId,row.equipped)>=Book.FullOutfitSlots then set(13);break end
		end
	end
	local stats=state.stats
	if type(stats)=="table"then
		if bit32.band(math.floor(count(stats.itemWinKinds)),Book.ItemKindsMask)==Book.ItemKindsMask then set(14)end
		if count(stats.tidyWins)>=Book.TidyWins then set(15)end
		if count(stats.rounds)>=Book.RoundsPlayed then set(16)end
	end
	return mask
end

-- Pages: each item is { id, name, ... }; `owns(state, item)` reads the save.
local pages={}
local function page(id,items,owns,extra)
	local entry={id=id,name=names[id],items=items,owns=owns}
	for key,value in pairs(extra or {})do entry[key]=value end
	pages[id]=entry
end
do
	local items={}
	for _,id in ipairs(Balls.Order)do if Balls.price(id)then table.insert(items,{id=id,name=Balls.ById[id].name})end end
	page("balls",items,function(state,item)
		local row=state.ballThemes;return type(row)=="table"and listHas(row.owned,item.id)
	end)
end
do
	local items={}
	for _,id in ipairs(Plates.Order)do if Plates.price(id)then table.insert(items,{id=id,name=Plates.ById[id].name})end end
	-- Book-only plates that exist in this build's DeckThemes (Stargazer joins with its art).
	local bookOnly={}
	for _,id in ipairs({Book.BookOnlyFaceplate,Book.StargazerPlate})do
		if Plates.ById[id]~=nil and Plates.isBookOnly(id)then table.insert(bookOnly,id)end
	end
	page("faceplates",items,function(state,item)return listHas(state.faceplates,item.id)end,{bookOnly=bookOnly})
end
do
	local items={}
	for _,pet in ipairs(Pets.active)do
		-- Recolour variants never count (SYSTEMS-SCOPE 8 #4): each weekly variant would
		-- move 100% further away. Base items only. `math.huge` lists every released row, so
		-- the page never depends on the clock.
		for _,item in ipairs(Wear.forPet(pet.id,math.huge).order)do
			if not item.variant then
				table.insert(items,{id=pet.id..":"..item.id,name=item.name,petId=pet.id,itemId=item.id})
			end
		end
	end
	page("wardrobe",items,function(state,item)
		local row=type(state.petWearables)=="table"and state.petWearables[item.petId]
		return type(row)=="table"and listHas(row.owned,item.itemId)
	end)
end
do
	local items={}
	for _,id in ipairs(Toys.Pools[Toys.PoolVersion]or {})do table.insert(items,{id="toy:"..id,name=Toys.ById[id].name,kind="toy",itemId=id})end
	for _,id in ipairs(Finishes.Pools[Finishes.PoolVersion]or {})do table.insert(items,{id="finish:"..id,name=Finishes.ById[id].name,kind="finish",itemId=id})end
	page("toys",items,function(state,item)
		local unlocks=if item.kind=="toy"then state.toyUnlocks else state.materialUnlocks
		return type(unlocks)=="table"and unlocks[item.itemId]==true
	end)
end
do
	local items={}
	for _,pet in ipairs(Pets.active)do table.insert(items,{id=pet.id,name=pet.name})end
	page("pets",items,function(state,item)return Eggs.isOwned(state.inventoryMask or 0,item.id)end)
end
do
	local items={}
	for _,entry in ipairs(Book.Discoveries)do table.insert(items,{id=entry.id,name=entry.name,bit=entry.bit})end
	page("discoveries",items,function(state,item)
		return type(state.book)=="table"and has(state.book.found,item.bit)
	end)
end
for _,id in ipairs(Book.PageOrder)do
	local entry=pages[id]
	for _,item in ipairs(entry.items)do table.freeze(item)end
	table.freeze(entry.items);if entry.bookOnly then table.freeze(entry.bookOnly)end
	table.freeze(entry)
end
Book.Pages=table.freeze(pages)

-- Milestones: "<page>.<pct>" -> { id, page, percent, reward }.
local milestones,byId={}, {}
for _,pageId in ipairs(Book.PageOrder)do
	for _,step in ipairs(Book.Steps)do
		local entry=table.freeze({id=pageId.."."..step,page=pageId,percent=step,reward=Book.Rewards[step]})
		table.insert(milestones,entry);byId[entry.id]=entry
	end
end
Book.Milestones=table.freeze(milestones)
Book.MilestoneById=table.freeze(byId)
function Book.milestone(id)return if type(id)=="string"then byId[id]else nil end
function Book.totalReward()local n=0;for _,m in ipairs(milestones)do n+=m.reward end;return n end

-- One page's progress from a save-like state: owned / total / percent (floored, capped 100).
function Book.pageProgress(state,pageId)
	local entry=pages[pageId]
	if not entry or type(state)~="table"then return {id=pageId,owned=0,total=0,percent=0}end
	local owned,ownedIds=0,{}
	for _,item in ipairs(entry.items)do
		if entry.owns(state,item)then owned+=1;table.insert(ownedIds,item.id)end
	end
	local total=#entry.items
	local percent=if total>0 then math.min(100,math.floor(owned*100/total))else 0
	return {id=pageId,name=entry.name,owned=owned,total=total,percent=percent,ownedIds=ownedIds}
end
function Book.pagePercent(state,pageId)return Book.pageProgress(state,pageId).percent end

-- Every page, in order, plus a byId map.
function Book.progress(state)
	local list,map={}, {}
	for _,pageId in ipairs(Book.PageOrder)do local row=Book.pageProgress(state,pageId);table.insert(list,row);map[pageId]=row end
	return {pages=list,byId=map}
end

local function claimedSet(state)
	local set={}
	local claimed=type(state)=="table"and type(state.book)=="table"and state.book.claimed
	if type(claimed)=="table"then for _,id in ipairs(claimed)do set[id]=true end end
	return set
end
-- Milestone ids reached and not yet claimed, in book order.
function Book.claimable(state)
	local set,progress,result=claimedSet(state),Book.progress(state),{}
	for _,m in ipairs(milestones)do
		if not set[m.id]and progress.byId[m.page].percent>=m.percent then table.insert(result,m.id)end
	end
	return result
end
-- True once `claimed` holds at least three "<page>.100" ids of current pages.
function Book.faceplateEarned(claimed)
	local count=0
	if type(claimed)=="table"then
		for _,id in ipairs(claimed)do local m=byId[id];if m and m.percent==100 then count+=1 end end
	end
	return count>=Book.PagesForFaceplate
end

-- Book-only plates (slice C): each is granted by the book claim that earns it, and repaired
-- on any later claim. `earned(claimed)` reads only the claimed milestone list, which never
-- shrinks, so a plate once earned is always earned.
--   bookworm:  any three pages claimed at 100%
--   stargazer: the Discoveries page claimed at 100% (SYSTEMS-SCOPE 8 #8)
-- A plate is listed only when this build's DeckThemes has it as a book-only plate, so the
-- server never grants an id the faceplate catalogue does not know.
do
	local plates={}
	local rules={
		{id=Book.BookOnlyFaceplate,rule="pages3",earned=Book.faceplateEarned},
		{id=Book.StargazerPlate,rule=Book.StargazerMilestone,earned=function(claimed)
			return type(claimed)=="table"and table.find(claimed,Book.StargazerMilestone)~=nil
		end},
	}
	for _,plate in ipairs(rules)do
		if Plates.ById[plate.id]~=nil and Plates.isBookOnly(plate.id)then table.insert(plates,table.freeze(plate))end
	end
	Book.BookOnlyPlates=table.freeze(plates)
end
-- Plate ids the save has earned and does not hold yet, in BookOnlyPlates order.
function Book.platesOwed(state)
	local owed={}
	if type(state)~="table"then return owed end
	local claimed=type(state.book)=="table"and state.book.claimed or nil
	for _,plate in ipairs(Book.BookOnlyPlates)do
		if plate.earned(claimed)and not listHas(state.faceplates,plate.id)then table.insert(owed,plate.id)end
	end
	return owed
end

-- Snapshot block (owner-private, via HatchProgress.public).
function Book.public(state)
	local set,progress=claimedSet(state),Book.progress(state)
	local list={}
	for _,row in ipairs(progress.pages)do
		local steps={}
		for _,step in ipairs(Book.Steps)do
			local id=row.id.."."..step
			table.insert(steps,{id=id,percent=step,reward=Book.Rewards[step],claimed=set[id]==true,reached=row.percent>=step})
		end
		table.insert(list,{id=row.id,name=row.name,owned=row.owned,total=row.total,percent=row.percent,
			ownedIds=row.ownedIds,milestones=steps,bookOnly=if pages[row.id].bookOnly then table.clone(pages[row.id].bookOnly)else nil})
	end
	local claimed={}
	if type(state)=="table"and type(state.book)=="table"and type(state.book.claimed)=="table"then claimed=table.clone(state.book.claimed)end
	return {pages=list,claimed=claimed,claimable=Book.claimable(state),
		found=if type(state)=="table"and type(state.book)=="table"then state.book.found or 0 else 0,
		faceplate=Book.BookOnlyFaceplate,faceplateEarned=Book.faceplateEarned(claimed),
		plates=(function()
			local rows={}
			for _,plate in ipairs(Book.BookOnlyPlates)do
				table.insert(rows,{id=plate.id,rule=plate.rule,earned=plate.earned(claimed)==true,
					owned=type(state)=="table"and listHas(state.faceplates,plate.id)})
			end
			return rows
		end)()}
end

return table.freeze(Book)
