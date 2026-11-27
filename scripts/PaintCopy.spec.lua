-- Paint, Shine, Dress: the words (PAINT-SHINE-DRESS-PLAN). No `paint.*` string and no override target holds a word
-- from the audit's list; every override maps an existing key to an existing key whose {placeholders} the caller
-- already fills; with the switch off UICopy.get is today's text for every mapped key, with it on the new text.
-- Offline: scripts/run_dash_server_specs.py. Studio (Play): require(ServerScriptService.Server.ZZSpecs.PaintCopy)(Server).
return function()
	local Shared=game:GetService("ReplicatedStorage").Shared
	local UICopy=require(Shared.UICopy)
	local Copy=require(Shared.PaintCopy)
	local Hue=require(Shared.HueCatalog)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function vars(text)local out={};for name in string.gmatch(text,"{(%w+)}")do out[name]=true end;return out end
	local function raw(key)UICopy.setOverride(nil);return UICopy.get(key)end

	test("the banned-word check: whole words and plurals, not parts of other words",function()
		assert(Copy.banned("Use a Gloss jar")=="jar"and Copy.banned("Your jars")=="jar"and Copy.banned("Main colour")=="Main")
		assert(Copy.banned("Customization Egg")=="Customization"and Copy.banned("A Hue Egg")=="Hue")
		assert(Copy.banned("Maintain the garden")==nil and Copy.banned("Rosemary bush")==nil and Copy.banned("Hues")=="Hue" and Copy.banned("Pink pot")==nil)
	end)

	test("every paint.* string is free of the audit's words",function()
		local n=0
		for _,key in ipairs(UICopy.keys())do
			if string.sub(key,1,6)=="paint."then
				n+=1
				local word=Copy.banned(raw(key));assert(word==nil,key.." holds '"..tostring(word).."': "..raw(key))
			end
		end
		assert(n>=60,"paint keys: "..n)
	end)

	test("every override: both keys exist, the new text is clean and needs no placeholder the old one lacked",function()
		local n=0
		for from,to in pairs(Copy.Overrides)do
			n+=1
			assert(UICopy.has(from),"source "..from);assert(UICopy.has(to),"target "..to)
			local word=Copy.banned(raw(to));assert(word==nil,to.." holds "..tostring(word))
			local have=vars(raw(from))
			for name in pairs(vars(raw(to)))do assert(have[name],from.." -> "..to.." needs {"..name.."}")end
		end
		assert(n>=50,"overrides: "..n)
	end)

	test("install: off is today's text for every mapped key, on is the new text; nil override is today",function()
		local on=false
		Copy.install(UICopy,function()return on end)
		for from,to in pairs(Copy.Overrides)do
			on=false;local a=UICopy.get(from)
			on=true;local b=UICopy.get(from)
			UICopy.setOverride(nil);local today=UICopy.get(from);local new=UICopy.get(to)
			Copy.install(UICopy,function()return on end)
			assert(a==today,from.." off")
			assert(b==new,from.." on")
		end
		on=true;assert(UICopy.get("hatch.egg.look.name")=="Paint Egg"and UICopy.get("hatch.egg.stat.name")=="Snack Egg")
		on=false;assert(UICopy.get("hatch.egg.look.name")=="Customization Egg"and UICopy.get("hatch.egg.stat.name")=="Stat Egg")
		UICopy.setOverride(nil)
		assert(UICopy.get("hatch.egg.look.name")=="Customization Egg","no override: today")
	end)

	test("ten swatches: the four pots then the six mixes, each named and coloured",function()
		local list=Copy.swatches(Hue);assert(#list==10)
		for i,id in ipairs({"rose","tide","citrus","iris"})do assert(list[i].id==id and #list[i].pots==1)end
		for i=5,10 do assert(#list[i].pots==2 and Hue.Mixes[list[i].id])end
		for _,s in ipairs(list)do assert(UICopy.has(s.nameKey),s.nameKey);assert(typeof(s.color)=="Color3"or type(s.color)=="table")end
	end)

	return {passed=#cases,cases=cases}
end
