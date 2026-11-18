-- v1 launch build (LISTING.md section 9): the flags and catalog switches the public build ships with.
-- A change to any of these is a launch decision, not a refactor: update LISTING.md with it.
return function(server)
	local Shared = game:GetService("ReplicatedStorage").Shared
	local Flags = require(Shared.FeatureFlags)
	local cases = {}
	local function test(name, run) run(); table.insert(cases, name) end
	test("launch flags: persistent saves, Park on, dusk, no Features / second pet / pseudo-locale", function()
		assert(Flags.TestFreshSaves == false, "TestFreshSaves must be false: every publish would wipe saves")
		assert(Flags.Park == true and Flags.DayNight == false and Flags.Features == false, "Park / DayNight / Features")
		assert(Flags.SecondPet == false and Flags.PseudoLocale == false, "SecondPet / PseudoLocale")
	end)
	test("launch catalogs: the Material Egg is not sold, the Customization Egg is", function()
		assert(require(Shared.MaterialCatalog).EnablePurchases == false, "MaterialCatalog.EnablePurchases")
		assert(require(Shared.LookEggCatalog).EnablePurchases == true, "LookEggCatalog.EnablePurchases")
	end)
	test("launch store: progress saves under EggDropLaunchV3", function()
		assert(require(server.ProgressStore).Name == "EggDropLaunchV3", "progress store name")
	end)
	return { passed = #cases, cases = cases }
end
