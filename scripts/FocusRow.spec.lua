-- The pet focus row (FocusRow) and the pet tag's stat chip (beta 12 QA U2): the top stat (ties to Heart), the chip's
-- pieces with and without its word, the card hugging its words (120 to 220, the name giving way first), and the bond
-- card's 150 to 190 left exactly as it was (it is what the live place shows). Pure.
-- Usage (Client): require(ZZSpecs.FocusRow)(StarterPlayerScripts.Client)
-- Offline: scripts/run_dash_server_specs.py
return function(client)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Catalog=require(Shared.StatCatalog)
	local Row=require(client.FocusRow)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end

	test("the top stat: the highest level; all equal (or a tie with Heart) is Heart; no levels, none",function()
		local all={}
		for _,id in ipairs(Catalog.Order)do all[id]=3 end
		assert(Catalog.top(all).id=="heart"and Catalog.top(all).level==3)
		all.speed=9;assert(Catalog.top(all).id=="speed"and Catalog.top(all).level==9)
		all.power=9;assert(Catalog.top(all).id=="power","a tie goes to the first in the catalogue order")
		assert(Catalog.top(nil)==nil and Catalog.top({})==nil)
	end)
	test("the chip: icon, word, disc; a pill for two digits; the word dropped on a small phone",function()
		local g=Row.chip(36,nil)
		assert(g.iconX==6 and g.wordX==24 and g.discX==24+36+5 and g.discW==18 and g.w==g.discX+18+2)
		local two=Row.chip(36,14)
		assert(two.discW==24 and two.w==g.w+6,"two digits: a pill, 5 pt each side")
		local small=Row.chip(nil,nil)
		assert(small.wordX==nil and small.discX==6+14+5 and small.w==45,"6 | heart 14 | 5 | disc 18 | 2")
	end)
	test("the tag: one row hugging its words, 120 to 220, the name giving way first",function()
		local chip=Row.chip(36,nil).w
		local w,name=Row.tagWidth(40,chip)
		assert(w==12+40+10+chip+10 and name==40)
		w,name=Row.tagWidth(10,45);assert(w==120,"never under 120")
		w,name=Row.tagWidth(400,chip);assert(w==220 and name==220-12-10-chip-10,"the name truncates, the chip stays whole")
		-- The row keeps the card's right edge and grows it to the left.
		local a=Row.layout(874,150,false,true,true,402,{120,220})
		local b=Row.layout(874,210,false,true,true,402,{120,220})
		assert(a.bond.x+a.bond.w==b.bond.x+b.bond.w and b.bond.w==210)
	end)
	test("the bond card (live) keeps 150 to 190 on every width",function()
		for _,width in ipairs({320,568,667,874,1920})do
			for _,bond in ipairs({100,150,170,190,260})do
				local row=Row.layout(width,bond,true,true,true,400)
				assert(row.bond.w>=150 and row.bond.w<=190,width..":"..bond)
			end
		end
	end)
	return{passed=#cases,cases=cases}
end
