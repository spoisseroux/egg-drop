-- Beta 34 QA ("the font on the pocket deck could be bigger on computer too"): one knob (DeckText.Desktop) for the
-- Regular deck HUD and the in-place results on a computer. A one-line label grows only to its box height, a wrapped
-- one by the whole factor, never below its authored size; chips, buttons, kept and Scale-sized labels stay; a second
-- pass changes nothing; phones and the Small deck keep 1. Pure (plain tables stand in for labels).
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.DeckText)(PlayerScripts.Client); offline in
-- scripts/run_dash_server_specs.py.
return function(client)
	local Text=require(client.DeckText)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	-- A stand-in GuiObject: attributes, IsA, a Size with Y.Scale / Y.Offset, a parent chain, descendants.
	local function node(class,props,parent)
		local n={ClassName=class,attributes={},children={},Parent=parent}
		for k,v in pairs(props or {})do n[k]=v end
		n.Size=n.Size or {Y={Scale=0,Offset=20}}
		function n:GetAttribute(k)return self.attributes[k]end
		function n:SetAttribute(k,v)self.attributes[k]=v end
		function n:IsA(c)
			if c=="GuiButton"then return self.ClassName=="TextButton"or self.ClassName=="ImageButton"end
			return self.ClassName==c
		end
		function n:GetDescendants()
			local out={}
			local function walk(x)for _,child in ipairs(x.children)do table.insert(out,child);walk(child)end end
			walk(self);return out
		end
		if parent then table.insert(parent.children,n)end
		return n
	end

	test("the knob: Regular and computer results 1.2, phones and the Small deck 1",function()
		assert(Text.Desktop==1.2)
		assert(Text.hud("Regular")==1.2 and Text.hud("Small")==1 and Text.hud("Compact")==1)
		assert(Text.results(false)==1.2 and Text.results(true)==1)
	end)
	test("size: one line grows to its box at most, wrapped by the factor, never smaller",function()
		assert(Text.size(16,1.2,40,false)==19,"room: the whole factor")
		assert(Text.size(13,1.2,16,false)==16,"13 x 1.2 = 15.6 rounds to 16, the box height")
		assert(Text.size(22,1.2,24,false)==24,"capped at the box")
		assert(Text.size(26,1.2,22,false)==26,"already past its box: unchanged, never smaller")
		assert(Text.size(16,1.2,20,true)==19,"wrapped: the owner lays the lines out")
		assert(Text.size(14,1,40,false)==14 and Text.size(14,.8,40,false)==14,"no boost at 1 or below")
		assert(Text.size(12,1.2,nil,true)==14)
	end)
	test("apply: labels in the tree grow once; chips, buttons, kept and Scale-sized labels stay",function()
		local root=node("Frame")
		local card=node("Frame",{},root)
		local eyebrow=node("TextLabel",{TextSize=13,TextWrapped=false,Size={Y={Scale=0,Offset=16}}},card)
		local row=node("TextLabel",{TextSize=16,TextWrapped=true,Size={Y={Scale=0,Offset=40}}},card)
		local chip=node("Frame",{},card);chip:SetAttribute("ChipKind","sticker")
		local chipLabel=node("TextLabel",{TextSize=12,Size={Y={Scale=0,Offset=22}}},chip)
		local button=node("TextButton",{},card)
		local buttonLabel=node("TextLabel",{TextSize=15,Size={Y={Scale=0,Offset=44}}},button)
		local kept=node("TextLabel",{TextSize=14,Size={Y={Scale=0,Offset=40}}},card);kept:SetAttribute("DeckTextKeep",true)
		local scaled=node("TextLabel",{TextSize=14,Size={Y={Scale=1,Offset=0}}},card)
		local wallet=node("Frame",{},card);wallet:SetAttribute("DeckTextKeep",true)
		local digits=node("TextLabel",{TextSize=15,Size={Y={Scale=0,Offset=28}}},wallet)
		local n=Text.apply(root,1.2)
		assert(n==2 and eyebrow.TextSize==16 and row.TextSize==19,"eyebrow "..eyebrow.TextSize.." row "..row.TextSize)
		assert(chipLabel.TextSize==12 and buttonLabel.TextSize==15 and kept.TextSize==14 and scaled.TextSize==14 and digits.TextSize==15)
		assert(eyebrow:GetAttribute("DeckTextBase")==13)
		assert(Text.apply(root,1.2)==0 and row.TextSize==19,"a second pass changes nothing")
		assert(Text.apply(node("Frame"),1)==0 and Text.apply(nil,1.2)==0)
	end)

	return{passed=#cases,cases=cases}
end
