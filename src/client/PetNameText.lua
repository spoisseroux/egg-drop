-- v2 pet names: the text of a pet's name on this client. The server sends piece ids only (the
-- owner's snapshot `names.petNames`, other players' board attribute NameCatalog.Attribute); the
-- text comes from NameCatalog. No name, or any piece this client does not know: the species.
-- Names are proper names: every viewer sees the same authored pieces (labels showing them set
-- AutoLocalize=false so they are never machine-translated).
local Shared=game:GetService("ReplicatedStorage").Shared
local HttpService=game:GetService("HttpService")
local Names=require(Shared.NameCatalog)
local Pets=require(Shared.PetCatalog)
local Text={}

function Text.species(petId)local pet=Pets.byId[petId or ""];return pet and pet.name or "Bear"end
-- The saved piece ids for one of the owner's pets (nil when unnamed).
function Text.ownIds(state,petId)
	local names=type(state)=="table"and state.names
	local map=type(names)=="table"and names.petNames
	local ids=type(map)=="table"and map[petId or ""]
	return if type(ids)=="table"and #ids>0 then ids else nil
end
-- The owner's pet: display text and whether it is a real name (not the species).
function Text.own(state,petId)
	local species=Text.species(petId)
	local ids=Text.ownIds(state,petId)
	local display=Names.display(ids,nil)
	return display or species,display~=nil
end

-- Another player's pet from their board folder (the JSON is parsed once per change).
local parsed=setmetatable({},{__mode="k"})
function Text.boardIds(board,petId)
	if not board then return nil end
	local raw=board:GetAttribute(Names.Attribute)
	if type(raw)~="string"or raw==""then return nil end
	local entry=parsed[board]
	if not entry or entry.raw~=raw then
		local ok,data=pcall(HttpService.JSONDecode,HttpService,raw)
		entry={raw=raw,data=if ok and type(data)=="table"then data else nil}
		parsed[board]=entry
	end
	-- An empty Lua table encodes as "[]": `pets` may be an array (no names) or an object.
	local pets=entry.data and entry.data.pets
	local ids=type(pets)=="table"and pets[petId or ""]
	return if type(ids)=="table"and #ids>0 then ids else nil
end
function Text.ofBoard(board,petId)
	local species=Text.species(petId)
	local display=Names.display(Text.boardIds(board,petId),nil)
	return display or species,display~=nil
end

return Text
