-- Overnight 2026-11-14, slice E (SYSTEMS-SCOPE 1.2 / 1.7), the server half of
-- PetGeneralization.spec: "one pet" is generalized on the server.
--   * Every "pip" string literal left in src/server sits on an allowlisted line (the legacy L
--     rows of the scope table: the onboarding starter, retired hatch recipes, the frozen
--     four families). A new one fails here.
--   * The companion rules never name a pet: the first owned active pet, and "usable" = owned
--     and renderable in this build.
-- Module Sources need the Studio command context (as ClientLocalBudget does).
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.PetGeneralizationServer)(ServerScriptService.Server)
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Pets=require(Shared.PetCatalog)
	local Eggs=require(Shared.EggCatalog)
	local Hue=require(Shared.HueCatalog)
	local Session=require(server.SessionProfile)
	local Appearance=require(server.PetAppearance)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	-- Allowlist: module name -> substrings; a line with a "pip" literal must contain one.
	-- Numbers are the scope's site rows (all class L: legacy / onboarding, left on purpose).
	local allowed={
		Server={
			'board.runFamily or "pip"',                                    -- #6: families are frozen at four
			'board.selectedFamily or "pip"',                               -- #6
			'NurseryCatalog.family(board.profile.companionId) or "pip"',   -- #7, #11: an earned pet has no family
			'then selected else "pip"',                                    -- #7: rounds report an owned family
			'board.profile.companionId = "pip"',                           -- #10: after the starter grant
		},
		HatchProgress={
			'"MeetPipFirst"',                                              -- #2: retired hatch recipes
			'Catalog.isOwned(handle.state.inventoryMask, "pip") then return true, "AlreadyOwned"', -- #3: grantStarter (the onboarding Bear)
			'Catalog.isOwned(state.inventoryMask, "pip") then return true end', -- #3
			'Catalog.bit("pip")',                                          -- #3
			'petId = "pip", duplicate = false',                            -- #3: the starter reveal receipt
			'family = "pip", mastery = state.mastery.pip',                 -- #3
		},
		PetAppearance={'Ids={"pip"'},                                      -- #14: the saved id list (data)
	}

	test("every \"pip\" literal in the server is on an allowlisted line",function()
		local scripts={server}
		for _,d in ipairs(server:GetDescendants())do
			if d:IsA("LuaSourceContainer")and not d:FindFirstAncestor("ZZSpecs")then table.insert(scripts,d)end
		end
		local found=0
		for _,module in ipairs(scripts)do
			local number=0
			for line in string.gmatch(module.Source.."\n","([^\n]*)\n")do
				number+=1
				if string.find(line,'"pip"',1,true)or string.find(line,"'pip'",1,true)then
					found+=1
					local fine=false
					for _,piece in ipairs(allowed[module.Name]or {})do if string.find(line,piece,1,true)then fine=true end end
					assert(fine,module.Name..":"..number.." names the Bear: "..string.sub(line,1,120))
				end
			end
		end
		assert(found>=10,"the scan read the sources ("..found..")")
	end)

	test("the companion rules follow Pets.active, not a pet id",function()
		local every=bit32.lshift(1,#Pets.collection)-1
		assert(Session.firstOwnedActive(every)==Pets.active[1].id and Session.firstOwnedActive(0)==nil)
		for _,pet in ipairs(Pets.active)do
			local only=Eggs.bit(pet.id)
			assert(Session.firstOwnedActive(only)==pet.id and Session.hasActivePet(only)and Session.usable(only,pet.id),pet.id)
		end
		for _,pet in ipairs(Pets.collection)do
			local only=Eggs.bit(pet.id)
			if not Pets.isActive(pet)then
				assert(not Session.hasActivePet(only),"an inactive pet alone is not 'has a pet': "..pet.id)
				-- Retained legacy pets stay usable as companions; an earned pet without its rig is not.
				assert(Session.usable(only,pet.id)==(pet.earned~=true),pet.id)
			end
			assert(not Session.usable(0,pet.id),"never usable when not owned: "..pet.id)
		end
		assert(not Session.usable(every,"nope")and not Session.usable(every,nil)and not Session.usable(every,7))
	end)

	test("per-pet data sites list every collection pet, the earned one included",function()
		assert(#Appearance.Ids==#Pets.collection)
		for index,pet in ipairs(Pets.collection)do
			assert(Appearance.Ids[index]==pet.id,"PetAppearance.Ids follows the collection order at "..index)
			assert(Hue.Supported[pet.id]==true and Appearance.supported[pet.id]==true,pet.id.." can be dyed and wear a charm once owned")
		end
		-- An unlisted id would silently drop a saved charm preference: decode keeps the earned pet's.
		local decoded=Appearance.decode({blip={charmVisible=true,at=1,writer="spec"},nope={charmVisible=true,at=1,writer="spec"}})
		assert(decoded.blip and decoded.blip.charmVisible==true and decoded.nope==nil)
	end)

	return cases
end
