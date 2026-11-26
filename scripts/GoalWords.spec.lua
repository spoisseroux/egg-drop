-- Beta 34 QA (Spencer: "the goals need to be clearer"): every field goal reads as a plain instruction that says what
-- FieldRun checks, in three lengths (full, short, tiny), with no arrow or plus shorthand; the ball is its colour word
-- plus its circle on the deck and "a green ball" in plain text. Pure (GoalWords, UICopy deck.goal, BallThemes).
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.GoalWords)(ServerScriptService.Server); offline in
-- scripts/run_dash_server_specs.py.
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Words=require(Shared.GoalWords)
	local Objectives=require(Shared.FieldObjectives)
	local BallThemes=require(Shared.BallThemes)
	local UICopy=require(Shared.UICopy)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function goal(id,index,seed)return Objectives.create(id,seed or 17).goals[index]end

	test("plain lines for every template say the ball, the size rule and the side in words",function()
		local left=Words.lines(goal("bank_pair",1),false)
		assert(left[1]=="Make a green ball or bigger on the left","bank pair 1: "..left[1])
		assert(left[2]=="Green ball on the left"and left[3]=="Green left",left[2].." / "..left[3])
		assert(Words.lines(goal("bank_pair",2),false)[1]=="Make a green ball or bigger on the right")
		local match=Words.lines(goal("creek_crossing",1),false)
		assert(match[1]=="Match two blue balls in the middle"and match[2]=="Two blue balls in the middle"and match[3]=="Orange middle",
			table.concat(match," / "))
		assert(Words.lines(goal("lantern_chain",1),false)[1]=="Make 2 merges anywhere")
		local chain=Words.lines(goal("lantern_chain",2),false)
		assert(chain[1]=="Make 2 quick merges in a row"and chain[2]=="2 quick merges"and chain[3]=="2 in a row",table.concat(chain," / "))
		assert(Words.lines(goal("ripple_relay",2),false)[1]=="Make a green ball or bigger in the middle")
		-- Exact tier: no "or bigger" (an orange merge only, on the seeded side).
		for _,seed in ipairs({16,17})do
			local g=goal("bank_bounce",1,seed)
			local side=if g.zone.kind=="left"then "left"else "right"
			assert(Words.lines(g,false)[1]=="Make an orange ball on the "..side,Words.lines(g,false)[1])
		end
		-- Hard's third goal: tier IV anywhere, or a chain of 3.
		assert(Words.lines(Objectives.thirdGoal("lantern_chain"),false)[1]=="Make a pink ball or bigger anywhere")
		assert(Words.lines(Objectives.thirdGoal("bank_pair"),false)[1]=="Make 3 quick merges in a row")
	end)
	test("no shorthand survives in any line of any template, rich or plain",function()
		for _,id in ipairs(Objectives.Order)do
			for _,heat in ipairs({"easy","medium","hard"})do
				local ok,descriptor=pcall(Objectives.create,id,17,heat)
				if ok then
					for _,g in ipairs(descriptor.goals)do
						for _,rich in ipairs({false,true})do
							for _,line in ipairs(Words.lines(g,rich,14))do
								local plain=BallThemes.strip(line)
								assert(not plain:find("↑",1,true)and not plain:find("→",1,true)and not plain:find("←",1,true),id.." arrow: "..plain)
								assert(not plain:find("+",1,true),id.." plus: "..plain)
								assert(not plain:find("LEFT",1,true)and not plain:find("RIGHT",1,true)and not plain:find("CENTER",1,true),id.." caps zone: "..plain)
								assert(not plain:find("{",1,true),id.." unfilled: "..plain)
							end
						end
					end
				end
			end
		end
	end)
	test("rich lines keep the colour word and add the circle; the lines get shorter",function()
		local lines=Words.lines(goal("bank_pair",1),true,14)
		assert(lines[1]:find("Make a green <font",1,true),lines[1])
		assert(BallThemes.strip(lines[1])=="Make a green "..BallThemes.Glyph.." or bigger on the left",BallThemes.strip(lines[1]))
		assert(BallThemes.strip(lines[2])=="Green "..BallThemes.Glyph.." on the left"and BallThemes.strip(lines[3])==BallThemes.Glyph.." left")
		for _,id in ipairs(Objectives.Order)do
			for index=1,2 do
				local l=Words.lines(goal(id,index),true,14)
				assert(#BallThemes.strip(l[1])>=#BallThemes.strip(l[2])and #BallThemes.strip(l[2])>=#BallThemes.strip(l[3]),id.." longest first")
			end
		end
	end)
	test("the next-goal hint is the full plain line after Next",function()
		assert(Words.next(goal("ripple_relay",2))=="Next, make a green ball or bigger in the middle")
		assert(Words.next(goal("lantern_chain",2))=="Next, make 2 quick merges in a row")
		assert(Words.next(nil)=="")
	end)
	test("pick: the longest line that fits, else the shortest; lines in a box",function()
		local lines={"a long line here","short one","tiny"}
		assert(Words.pick(lines,function(t)return #t<=10 end)=="short one")
		assert(Words.pick(lines,function()return false end)=="tiny")
		assert(Words.pick(lines,function()return true end)=="a long line here")
		assert(Words.linesIn(40,16)==2 and Words.linesIn(19,16)==1 and Words.linesIn(5,16)==1 and Words.linesIn(60,16)==3)
	end)
	test("every deck.goal word is a UICopy key (translations pick them up)",function()
		for _,key in ipairs({"make","makeUp","match","merges","chain","short.make","short.match","short.merges","short.chain",
			"tiny.make","tiny.merges","tiny.chain","where.left","where.right","where.center","where.any","whereTiny.left",
			"whereTiny.right","whereTiny.center","whereTiny.any","next","done"})do
			assert(UICopy.has("deck.goal."..key),key)
		end
		for _,key in ipairs({"deck.chain.line","deck.chain.short","deck.chain.tiny","deck.chain.toast","deck.quests.open","deck.quests.button"})do assert(UICopy.has(key),key)end
		assert(UICopy.get("deck.chain.toast",{count=2})=="Chain ×2! Quick merges in a row score more")
	end)

	return{passed=#cases,cases=cases}
end
