-- Studio Client. Ball themes catalogue and readability (batch 2026-11-13 R1, scope C2-C3,
-- B5-B6): six themes with fixed prices, the same hue family per size in every theme,
-- neighbouring sizes clearly different in colour (CIE76 >= 20, full vision), face ink
-- >= 4.5:1 on every body, at most 8 tones a ball, five sizes that step in size; Kittens
-- with real pointed ears; the colour circles (rich text and Frames) that replace tier
-- numerals in goals, quests and results; and the faceplate tint scoped to the deck.
-- Usage: require(PlayerScripts.Client.ZZSpecs.BallThemes)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
	local Themes=require(game.ReplicatedStorage.Shared.BallThemes)
	local Config=require(game.ReplicatedStorage.Shared.BoardConfig)
	local LCD=require(client.JellyLCD)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function linear(v)return if v<=.04045 then v/12.92 else((v+.055)/1.055)^2.4 end
	local function luminance(c)return .2126*linear(c.R)+.7152*linear(c.G)+.0722*linear(c.B)end
	local function contrast(a,b)local x,y=luminance(a),luminance(b);return(math.max(x,y)+.05)/(math.min(x,y)+.05)end
	local function lab(c)
		local r,g,b=linear(c.R),linear(c.G),linear(c.B)
		local x,y,z=(r*.4124+g*.3576+b*.1805)/.95047,(r*.2126+g*.7152+b*.0722),(r*.0193+g*.1192+b*.9505)/1.08883
		local function f(t)return if t>.008856 then t^(1/3)else 7.787*t+16/116 end
		return 116*f(y)-16,500*(f(x)-f(y)),200*(f(y)-f(z))
	end
	local function distance(a,b)local l1,a1,b1=lab(a);local l2,a2,b2=lab(b);return math.sqrt((l1-l2)^2+(a1-a2)^2+(b1-b2)^2)end
	local hues={{.52,.68},{.0,.12},{.27,.45},{.83,.99},{.69,.80}} -- blue, orange, green, pink, violet
	local root=Instance.new("Frame");root.Name="_BallThemesSpec";root.Size=UDim2.fromOffset(300,200);root.BackgroundTransparency=1;root.Parent=parent
	local ok,problem=pcall(function()
		test("six themes in shop order with fixed prices; Smileys default; Kittens 120",function()
			assert(table.concat(Themes.Order,",")=="smileys,marbles,gumdrops,gems,planets,kittens")
			local expect={smileys=0,marbles=0,gumdrops=20,gems=40,planets=40,kittens=120}
			for id,price in pairs(expect)do assert(Themes.ById[id].price==price,id)end
			assert(Themes.get("unknown").id=="smileys"and Themes.Default=="smileys")
		end)
		test("every theme: same hue family per size, neighbours >= 20 apart, ink >= 4.5:1, lightness ramp",function()
			for _,id in ipairs(Themes.Order)do
				local theme=Themes.ById[id]
				for tier=1,5 do
					local r=theme.ramps[tier];local body=Color3.fromHex(r.body)
					local h,s=body:ToHSV();local band=hues[tier]
					assert(s>.3 and h>=band[1]and h<=band[2],id.." tier "..tier.." left its hue family ("..h..")")
					if tier>1 then assert(distance(body,Color3.fromHex(theme.ramps[tier-1].body))>=20,id.." tiers "..(tier-1).."/"..tier.." too close")end
					assert(contrast(Color3.fromHex(theme.ink),body)>=4.45,id.." tier "..tier.." ink contrast")
					assert(luminance(Color3.fromHex(r.deep))<luminance(body)and luminance(body)<luminance(Color3.fromHex(r.light)),id.." ramp order")
				end
			end
		end)
		test("sizes step: radii, preview grids and icon circles all grow with the tier",function()
			for tier=2,5 do
				assert(Config.Tiers[tier].radius>Config.Tiers[tier-1].radius)
				assert(Themes.CircleScale[tier]>Themes.CircleScale[tier-1])
				assert(Themes.circleSize(tier,14)>Themes.circleSize(tier-1,14),"rich circle "..tier)
				assert(LCD.ballRuns("smileys",tier,"idle",0,false).size>LCD.ballRuns("smileys",tier-1,"idle",0,false).size)
			end
			assert(Themes.CircleScale[1]==.52 and Themes.CircleScale[5]==1)
		end)
		test("at most 8 tones a ball (palette cache), faces only where the theme has them",function()
			for _,id in ipairs(Themes.Order)do
				for tier=1,5 do
					for _,expr in ipairs({"idle","last","merged"})do
						local seen,count={},0
						for _,run in ipairs(LCD.ballRuns(id,tier,expr,0,tier==3).runs)do if not seen[run[4]]then seen[run[4]]=true;count+=1 end end
						assert(count<=8,id.." tier "..tier.." "..expr.." uses "..count.." tones")
					end
				end
				local t=LCD.themeTones(Themes.get(id),3);local ink=0
				for _,run in ipairs(LCD.ballRuns(id,3,"idle",0,false).runs)do if run[4]==t[8]then ink+=1 end end
				assert((ink>0)==(Themes.ById[id].face~="none"),id.." face presence")
			end
		end)
		test("Kittens: pointed ears above the head on sizes 2-5, none on the smallest, within 30% of the radius",function()
			for tier=1,5 do
				local look=LCD.ballRuns("kittens",tier,"idle",0,false)
				local r=Config.Tiers[tier].radius*LCD.Width/(Config.Width+.8)
				local plain=LCD.ballRuns("smileys",tier,"idle",0,false)
				local top=math.huge;for _,run in ipairs(look.runs)do top=math.min(top,run[2])end
				-- Rows above the round head (head top = centre - r on the kitten grid).
				local margin=math.ceil(r*.3)+1;local cy=look.size/2+(if tier>=2 then margin*.5 else 0)
				local above={};for _,run in ipairs(look.runs)do if run[2]+.5<cy-r then above[run[2]]=(above[run[2]]or 0)+1 end end
				local rows=0;for _ in pairs(above)do rows+=1 end
				if tier==1 then assert(rows==0 and look.size==plain.size,"the smallest kitten has no ears")
				else
					assert(rows>=1,"tier "..tier.." ears missing")
					assert(cy-top<=r*1.3+1,"tier "..tier.." ears taller than budget")
					-- Pointed: the top row is two narrow tips (one per ear), never one wide band (pig ears).
					local tips=0;for _,run in ipairs(look.runs)do if run[2]==top then tips+=1;assert(run[3]<=math.max(2,math.ceil(r*.25)),"tier "..tier.." blunt ear tip")end end
					assert(tips==2,"tier "..tier.." top row has "..tips.." runs")
				end
			end
		end)
		test("colour circles: rich text in the theme colour with a lighter ring, plain words for screen readers",function()
			local markup=Themes.circle(4,14,"smileys")
			assert(markup:find(Themes.ById.smileys.ramps[4].body,1,true)and markup:find(Themes.ById.smileys.ramps[4].light,1,true)and markup:find("<stroke",1,true))
			assert(Themes.strip(markup)==Themes.Glyph and Themes.spoken(4)=="pink ball"and Themes.word(1)=="blue")
			local label=Instance.new("TextLabel");label.RichText=true;label.Size=UDim2.fromOffset(240,30);label.TextSize=14;label.Parent=root
			label.Text=Themes.questText("Make a tier IV on Hard",14);task.wait()
			assert(label.ContentText=="Make a "..Themes.Glyph.." on Hard","rendered "..label.ContentText)
			-- Goal icon circles in the HUD (phone icon rows): Frames that step in size.
			local Screen=require(client.DeckScreen)
			local slot={ball=Instance.new("Frame"),circle=Instance.new("Frame"),ring=Instance.new("UIStroke")}
			Screen.dotPaint(slot,2);local small=slot.circle.Size.X.Scale
			Screen.dotPaint(slot,5);assert(slot.circle.Size.X.Scale>small and slot.circle.BackgroundColor3==Themes.color(5))
			assert(slot.ball:GetAttribute("AccessibleLabel")=="violet ball")
			-- The equipped theme colours the circles (same hue family, theme's own shade).
			Themes.setCurrent("gems");Screen.dotPaint(slot,4);assert(slot.circle.BackgroundColor3==Color3.fromHex(Themes.ById.gems.ramps[4].body))
			Themes.setCurrent("smileys")
		end)
		test("faceplate tint is scoped: menus keep the house palette, the deck hardware follows the plate",function()
			local Art=require(client.DeckArt);local Kit=require(client.DeckKit)
			local Plates=require(game.ReplicatedStorage.Shared.DeckThemes)
			local old=Art.getTheme();local house=Plates.ById[Plates.Default].ui
			for _,id in ipairs({"brick","night_orb","sherbet"})do
				local plate=Plates.ById[id];Art.applyTheme(plate)
				assert(Art.getTheme()==plate,"hardware readers lost the plate")
				assert(Kit.color("accent")==house.accent and Kit.color("panel")==house.panel and Kit.color("well")==house.inset,id.." tinted the menus")
				assert(Art.paletteColor("raised")==house.raised and Art.paletteColor("accent")==house.accent)
			end
			Art.applyTheme(old or Plates.ById[Plates.Default])
		end)
	end)
	Themes.setCurrent("smileys");root:Destroy();assert(ok,problem)
	return{passed=#cases,cases=cases}
end
