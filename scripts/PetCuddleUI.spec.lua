-- The petting screen's pure rules that live in PetCuddleUI (beta 42 D13 and D15): what the hints call the pet, and the
-- vignette gui's order under the focus gui. The drawn screen itself is checked in Studio (PetFocusUI spec).
-- Usage (Client): require(<client>.ZZSpecs.PetCuddleUI)(<client>); offline in scripts/run_dash_server_specs.py.
return function(client)
	local Cuddle=require(client.PetCuddleUI)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end

	test("D13: the hints call a named pet by its name and an unnamed one (its pill reads Pet) by its species",function()
		assert(Cuddle.callName({name="Zivvi",named=true,species="Bear"})=="Zivvi")
		assert(Cuddle.callName({name="Pet",named=false,species="Bear"})=="Bear")
		assert(Cuddle.callName({name="Pet",named=false})=="Pet","no species: the pill's word")
		assert(Cuddle.callName({name="Bear"})=="Bear","an older card without the flag keeps its name")
		assert(Cuddle.callName(nil)=="your pet"and Cuddle.callName({name=""})=="your pet")
	end)

	test("D15: the vignette's own gui sits one below the focus gui (40 while it owns input, 9 otherwise), never negative",function()
		assert(Cuddle.underOrder(40)==39 and Cuddle.underOrder(9)==8 and Cuddle.underOrder(0)==0 and Cuddle.underOrder(nil)==0)
	end)

	return{passed=#cases,cases=cases}
end
