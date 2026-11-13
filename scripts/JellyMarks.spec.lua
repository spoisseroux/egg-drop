-- Studio Client. No tier numerals anywhere (batch 2026-11-13 R1, Spencer: "numerals AND
-- tier motifs go"). The old mark-glyph API is retired: size, colour and the ball's face
-- carry the tier on the board, and the UI names a ball with a flat colour circle.
-- Usage: require(PlayerScripts.Client.ZZSpecs.JellyMarks)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
	local Sprite=require(client.JellySprite);local Palette=require(game.ReplicatedStorage.Shared.JellyPalette)
	local Themes=require(game.ReplicatedStorage.Shared.BallThemes)
	local LCD=require(client.JellyLCD)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local root=Instance.new("Frame");root.Name="_JellyMarks";root.BackgroundTransparency=1;root.Size=UDim2.fromOffset(120,120);root.Parent=parent
	local ok,problem=pcall(function()
		test("the mark glyph API and mark roles are gone",function()
			assert(Sprite.markSize==nil and Sprite.MarkFont==nil and Sprite.invalidateMarkSizes==nil)
			assert(Palette.MarkMinRadius==nil)
			for tier,roles in ipairs(Palette.byTier)do assert(roles.mark==nil and roles.markShadow==nil,"tier "..tier)end
		end)
		test("a ball preview is pixel runs only: no TextLabel, every tier, every theme",function()
			for _,id in ipairs(Themes.Order)do
				for tier=1,5 do
					local holder=Instance.new("Frame");holder.Size=UDim2.fromOffset(40,40);holder.Parent=root
					local preview=Sprite.preview(holder);preview.set(id,tier,"idle",0,false)
					assert(#preview.root:GetChildren()>0,id.." "..tier.." drew nothing")
					for _,node in ipairs(holder:GetDescendants())do assert(not node:IsA("TextLabel"),id.." "..tier.." has a text label")end
					holder:Destroy()
				end
			end
		end)
		test("quest titles and goal words never show a numeral",function()
			for _,title in ipairs({"Make a tier IV","Make a tier IV on Hard","Make a tier V","Tier IV in 3 Hard rounds"})do
				local plain=Themes.questText(title,14,true);local rich=Themes.strip(Themes.questText(title,14))
				for _,text in ipairs({plain,rich})do
					assert(not text:find("[Tt]ier")and not text:find("%f[%a]I[IV]*%f[%A]")and not text:find("%f[%a]V%f[%A]"),"numeral left in "..text)
				end
			end
			local Copy=require(client.FieldQuestText)
			local goal={kind="merge",minTier=4,zone={kind="left"},target=1,id="x"}
			local full,short=Copy.goal(goal)
			assert(full=="Make a pink ball or bigger on LEFT","plain "..full)
			local richFull=Copy.goal(goal,nil,true,14)
			assert(Themes.strip(richFull)=="Make "..Themes.Glyph.." or bigger on LEFT","rich "..richFull)
			for _,caption in ipairs(short)do assert(not caption:find("IV"),caption)end
		end)
		test("faces are drawn inside the ball (no glyph overlay): span LCD draws a smiley",function()
			local lcd=assert(LCD.new(root,{backend="span",maxSpans=1536}));lcd:setBallTheme("smileys")
			local t=LCD.themeTones(Themes.get("smileys"),5)
			lcd:beginFrame();lcd:draw(Vector2.new(LCD.Width/2,LCD.Height*.5),12,12,0,Color3.new(1,1,1),0,nil,{tier=5,expr="idle",dx=0})
			local ink=0
			for i=0,LCD.Width*LCD.Height-1 do if buffer.readu32(lcd.pixels,i*4)==t[8]then ink+=1 end end
			assert(ink>=6,"face ink pixels "..ink);assert(lcd:finishFrame());lcd:destroy()
		end)
	end)
	root:Destroy();assert(ok,problem)
	return{passed=#cases,cases=cases}
end
