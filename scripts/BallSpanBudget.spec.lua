-- Studio Client. Span budget with faces (BUILD-PLAN architect change 2, scope B4): before
-- painting, JellyLCD counts the spans a frame needs; over 1350 it re-rasters that frame
-- with simpler faces (eyes only on the two smallest sizes, ink only, kitten ears from
-- size 3); the sticky `failed` path is reserved for frames still over the 1536 cap.
-- Scenes are the scope's model boards on the real 64 x 107 grid (calm 12 balls, stress
-- 32 balls, every ball panicking: the worst case). Kittens is measured first.
-- The same scenes through the real rasterizer in the Luau CLI (2026-11-13) measured:
--   stress, last second: Smileys 1563 -> 1457 simplified, Kittens 1611 -> 1473,
--   Gems 1546 -> 1447, Planets 1536 -> 1473, Gumdrops 1551 -> 1411; today 1369.
-- Usage: require(PlayerScripts.Client.ZZSpecs.BallSpanBudget)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
	local LCD=require(client.JellyLCD);local Config=require(game.ReplicatedStorage.Shared.BoardConfig)
	local Themes=require(game.ReplicatedStorage.Shared.BallThemes)
	local RunService=game:GetService("RunService")
	local STRESS={{27.37,94.64,4},{45.93,94.09,3},{10.81,92.09,2},{53.93,80.80,3},{37.81,82.74,2},{17.07,84.88,1},{7.81,81.21,2},{25.07,80.73,1},{18.07,77.14,1},{32.81,72.62,2},{43.07,74.77,1},{11.07,72.24,1},{52.93,65.32,3},{21.81,68.35,2},{41.07,67.22,1},{8.07,65.03,1},{31.81,61.39,2},{15.07,61.57,1},{41.81,56.16,2},{22.07,58.10,1},{8.07,57.22,1},{54.81,52.06,2},{15.07,53.76,1},{28.07,52.60,1},{7.81,47.56,2},{35.07,49.14,1},{21.07,48.76,1},{45.07,47.19,1},{28.81,41.94,2},{52.07,42.91,1},{18.07,41.55,1},{39.07,42.19,1}}
	local cases,report={},{}
	local function test(name,run)run();table.insert(cases,name)end
	local root=Instance.new("Frame");root.Name="_BallSpanBudget";root.Size=UDim2.fromOffset(354,594);root.BackgroundTransparency=1;root.Parent=parent
	local function settle()for _=1,2 do RunService.Heartbeat:Wait()end end
	local function frame(lcd,count,expr,faces)
		lcd:beginFrame()
		for index=1,count do
			local b=STRESS[index];local r=Config.Tiers[b[3]].radius*LCD.Width/(Config.Width+.8)
			lcd:draw(Vector2.new(b[1],b[2]),r,r,0,Config.Tiers[b[3]].color,0,nil,if faces then {tier=b[3],expr=expr,dx=index%2}else nil)
		end
		local hr=Config.Tiers[1].radius*LCD.Width/(Config.Width+.8)
		lcd:draw(Vector2.new(37,9.3),hr,hr,0,Config.Tiers[1].color,0,nil,if faces then {tier=1,expr="idle",dx=0}else nil)
		return lcd:finishFrame()
	end
	local ok,problem=pcall(function()
		local order=table.clone(Themes.Order);table.remove(order,table.find(order,"kittens"));table.insert(order,1,"kittens")
		for _,id in ipairs(order)do
			test(id.." worst board never takes the sticky failure path; over 1350 it re-rasters simpler",function()
				local lcd=assert(LCD.new(root,{backend="span",maxSpans=1536}));settle();lcd:setBallTheme(id)
				for _,case in ipairs({{12,"idle"},{32,"danger"},{32,"last"}})do
					local before=lcd:getStats().simplifiedFrames or 0
					assert(frame(lcd,case[1],case[2],true),id.." "..case[2].." failed: "..tostring(lcd:getStats().failure))
					local s=lcd:getStats()
					local simplified=(s.simplifiedFrames or 0)>before
					-- Faceless themes (Marbles) never pre-count: nothing to simplify.
					local pre=s.preDemand or 0
					assert(simplified==(pre>LCD.SimplifyAbove),id.." re-raster rule")
					assert(s.spansUsed<=1536 and(not simplified or s.spansUsed<pre),id.." simplified frame did not shrink")
					report[id.."/"..case[1].."/"..case[2]]={pre=s.preDemand,painted=s.spansUsed,simplified=simplified}
				end
				lcd:destroy()
			end)
		end
		test("legacy draws (no face record) never pre-count or simplify",function()
			local lcd=assert(LCD.new(root,{backend="span",maxSpans=1536}));settle()
			assert(frame(lcd,32,"last",false))
			local s=lcd:getStats();assert((s.simplifiedFrames or 0)==0 and s.preDemand==nil)
			report.today=s.spansUsed;lcd:destroy()
		end)
		test("a frame still over the cap after simplifying is the only sticky failure",function()
			local lcd=assert(LCD.new(root,{backend="span",maxSpans=600}));settle();lcd:setBallTheme("kittens")
			assert(not frame(lcd,32,"last",true)and lcd.failed and lcd:getStats().failure=="span-cap")
			assert((lcd:getStats().simplifiedFrames or 0)==1,"it tried the simpler faces first")
			lcd:destroy()
		end)
	end)
	root:Destroy();assert(ok,problem)
	return{passed=#cases,cases=cases,spans=report}
end
