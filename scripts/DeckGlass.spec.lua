-- Deck Aero glass (artifacts/qa-2026-11-28-beta44/DECK-AERO-BRIEF.md). Pure parts only (Shared.DeckGlass):
--   switch    Alive "deckglass": the flag, beta and Studio only, never live; it needs "deckfeel" too; the override.
--   palette   the brief's 25-plate table, role for role, from each plate's toyShell row; every plate is in the table.
--   fallback  Bookworm and Stargazer (no toyShell row) solve one from deep and accent (mixed toward white or black to
--             the row's luminance) and land on the brief's rows; their menus (theme.toy) stay Classic Shell.
--   floors    section 3's contrast rules for every plate in DeckThemes.Plates: 4.5 text, 3.0 large text and fills.
--   surfaces  the track, the pill and fill tops, the gloss, the Welcome sky and egg cards.
--   recipe    the card, pill, track and well numbers; the shadow's gap rule; the pill states; gold text at 18 px.
--   motion    the sweep's 1.2 s gap, what Reduced Motion / Motion: Low / the budget / a compact deck keep.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.DeckGlass)(ServerScriptService.Server)
-- Offline: python scripts/run_dash_server_specs.py
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Glass=require(Shared.DeckGlass)
	local Themes=require(Shared.DeckThemes)
	local Alive=require(Shared.Alive)
	local Flags=require(Shared.FeatureFlags)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function near(a,b,e)return math.abs(a-b)<=(e or 1e-6)end
	-- Within one 8-bit step a channel (the table was rounded once per mix).
	local function sameHex(a,b,label)
		local x,y=Glass.rgb(a),Glass.rgb(b)
		for i=1,3 do assert(math.abs(x[i]-y[i])<=1,string.format("%s: %s vs %s",label,a,b))end
	end
	local ROLES={"glassTop","glassBottom","rim","accent","pill","ink","soft","wellTop"}
	-- The brief's table (section 3), by plate name.
	local TABLE={
		Scout={"#0E735B","#095946","#A5D4C9","#76F6B0","#A4F57C","#0A1B17","#CDEFE7","#1B3441"},
		Pebble={"#426F51","#32553E","#BCD1C2","#C8EB9B","#C9F08A","#0A1C10","#CEF0D9","#25333F"},
		Creek={"#186F84","#115566","#ABD1DB","#70ECFF","#70ECFF","#0B1A1E","#D1ECF3","#1B334B"},
		Ember={"#BE2E37","#942129","#F2BDC0","#FF9B70","#FF9B70","#2A1011","#FFE0E2","#4B201C"},
		Canopy={"#23752E","#1A5A22","#AFD4B4","#BCF57B","#BCF57B","#0A1C0D","#CEF0D2","#1E3919"},
		Honey={"#945709","#724305","#E0C7A8","#FFD77D","#FF9838","#1F170C","#F4E6D2","#3D3019"},
		Gloaming={"#5A5ABC","#454592","#C9C9EB","#92ECE6","#92ECE6","#141435","#E6E6FF","#232E57"},
		Copperleaf={"#A54B2B","#7F391F","#E6C4B7","#FFBC90","#FFBC90","#24140E","#FCE2D8","#44291D"},
		["Aqua Pop"]={"#0E69AB","#085184","#ACD0E8","#6FE3FF","#6FE3FF","#0D1A22","#D6EBF9","#183441"},
		["Lime Gel"]={"#37730E","#295909","#B8D4A5","#B6F24B","#B6F24B","#111B0A","#DAEECC","#253711"},
		["Sorbet Sky"]={"#B63363","#8D254B","#EEBDCF","#FFB37A","#FFB37A","#291019","#FEE0EB","#4A2326"},
		["Liquid Chrome"]={"#526689","#3E4E6A","#C4CCDB","#DCE6F5","#DCE6F5","#0F1827","#DDE8FB","#273348"},
		Tidepool={"#1C62C9","#134B9D","#B5CDF0","#5CD6E8","#5CD6E8","#0F1827","#DAE9FE","#173144"},
		["Aurora Glass"]={"#5246FB","#3E34C6","#C9C6FC","#7CF5C4","#A8F27A","#161433","#E6E5FE","#232F51"},
		["Prism Flare"]={"#96459C","#743478","#E1C1E4","#F3B6FF","#F3B6FF","#260F27","#FBDFFD","#442248"},
		["Night Orb"]={"#7A3CE7","#5E2CB5","#D6C2F8","#FF7AD9","#FF7AD9","#1D1230","#EDE3FD","#3C1E4D"},
		Bookworm={"#366E6B","#245653","#B5D2CF","#7FE0CF","#7FE0CF","#0A1E1D","#C3F0E8","#183632"},
		["Grape Soda"]={"#8A46B7","#6B348E","#DBC2EB","#C9A6FF","#C9A6FF","#21112C","#F1E2FB","#3A224D"},
		["Rose Chrome"]={"#994C72","#763A58","#E1C3D2","#FFC2D4","#FFC2D4","#29101C","#FEDFEE","#492435"},
		Stargazer={"#616381","#494C6E","#CACCDB","#B9C6FF","#B9C6FF","#151839","#E1E6FF","#282D51"},
		["Cloud Glass"]={"#2667AD","#1B4F86","#B5CEE8","#8FD2FF","#BFE6FF","#0E1924","#D8EAFC","#1D3244"},
		Lagoon={"#107171","#0A5757","#A5D3D3","#6FF0E0","#7CFFD2","#0A1B1B","#CCEEEE","#1B3447"},
		["Dewy Meadow"]={"#13753D","#0D5A2E","#A8D5BB","#8CF07A","#F6C9E6","#0A1C12","#CEEFDC","#1E343B"},
		["Sky Fizz"]={"#186D94","#105472","#AED0E1","#7FDCFF","#FFB3DA","#0C1A20","#D4EBF6","#1C314B"},
		["Storm Glass"]={"#4565A4","#344D7F","#C0CCE4","#A9C4F2","#C4B5FF","#0F1828","#DDE8FC","#212E47"},
	}

	test("switch: Alive deckglass (beta and Studio only, never live), registered like deckfeel; needs deckfeel; the override",function()
		assert(Glass.Feature=="deckglass"and table.find(Alive.Features,"deckglass")and Flags.AliveDeckGlass==true)
		assert(Alive.attribute("deckglass")=="Alive_deckglass"and Alive.key("deckglass")=="alive_deckglass")
		assert(Alive.ceiling("deckglass",{AliveDeckGlass=true},107705084891479,false),"the beta")
		assert(Alive.ceiling("deckglass",{AliveDeckGlass=true},96451847774961,true),"Studio")
		assert(not Alive.ceiling("deckglass",{AliveDeckGlass=true},96451847774961,false),"never on the live place")
		assert(not Alive.ceiling("deckglass",{},107705084891479,true),"not without its flag")
		assert(Alive.resolve("deckglass",nil,nil,true)==true,"missing = on")
		local saved={workspace:GetAttribute("Alive_deckglass"),workspace:GetAttribute("Alive_deckfeel")}
		local function with(glass,feel)
			workspace:SetAttribute("Alive_deckglass",glass);workspace:SetAttribute("Alive_deckfeel",feel)
			return Glass.switch()
		end
		local open=Alive.ceiling("deckglass")and Alive.ceiling("deckfeel")
		assert(with(nil,true)==false and with(false,true)==false,"a missing or false attribute is today's deck")
		assert(with(true,false)==false,"it dresses the deckfeel HUD: off without deckfeel")
		assert(with(true,true)==open,"both on: glass where the ceilings are open")
		workspace:SetAttribute("Alive_deckglass",saved[1]);workspace:SetAttribute("Alive_deckfeel",saved[2])
		Glass.setSwitch(true);assert(Glass.switch()==true)
		Glass.setSwitch(false);assert(Glass.switch()==false)
		Glass.setSwitch(nil)
	end)

	test("palette: the brief's 25-plate table, role for role; every plate in DeckThemes.Plates is in it",function()
		local seen=0
		for id,plate in pairs(Themes.Plates)do
			local row=TABLE[plate.name]
			assert(row,"a plate the brief's table does not cover: "..id)
			local p=Glass.paletteHex(plate)
			for index,role in ipairs(ROLES)do sameHex(p[role],row[index],plate.name.." "..role)end
			assert(p.text=="#FFFFFF","text is white")
			seen+=1
		end
		assert(seen==25,"25 plates, got "..seen)
		-- Exact where the table was not rounded twice: Cloud Glass (the default, what new players wear).
		local cloud=Glass.paletteHex(Themes.Plates.cloud_glass)
		assert(cloud.glassTop=="#2667AD"and cloud.glassBottom=="#1B4F86"and cloud.rim=="#B5CEE8"and cloud.pill=="#BFE6FF"and cloud.wellTop=="#1D3244")
		-- The state colours never follow the skin.
		for _,plate in pairs(Themes.Plates)do
			local p=Glass.paletteHex(plate)
			assert(p.good=="#43DB5F"and p.warn=="#FFC14D"and p.bad=="#FF5A4D"and p.gold=="#FFC14D")
		end
	end)

	test("palette(theme): Color3 roles for a DeckThemes theme, cached; nil is the default plate",function()
		local theme=Themes.ById.ice
		local p=Glass.palette(theme)
		assert(Glass.palette(theme)==p,"cached per theme")
		assert(near(p.glassTop.R*255,0x18,.01)and near(p.glassTop.G*255,0x6F,.01)and near(p.glassTop.B*255,0x84,.01),"Creek's glassTop")
		assert(p.hex.accent=="#70ECFF"and p.surface.track~=nil and p.track~=nil and p.pillTop~=nil and p.warnTop~=nil)
		local default=Glass.palette(nil)
		assert(default.hex.glassTop==Glass.paletteHex(Themes.Plates[Themes.Default]).glassTop,"nil: the default plate (Cloud Glass)")
	end)

	test("fallback: Bookworm and Stargazer have no toyShell row; the luminance rule lands on the brief's rows; menus unchanged",function()
		for _,id in ipairs({"bookworm","stargazer"})do
			local plate=Themes.Plates[id]
			assert(plate.toyShell==nil,id.." has no row (the menus keep Classic Shell while the switch is off)")
			assert(Themes.ById[id].toy==Themes.ToyClassic,id.." menus: Classic Shell, as today")
			local p=Glass.paletteHex(plate)
			assert(p.solved==true)
			local row=TABLE[plate.name]
			for index,role in ipairs(ROLES)do sameHex(p[role],row[index],id.." "..role)end
		end
		-- The rule: each role at its luminance (shell .131, lip .045, ink and well .011, hi .37, soft .80); pill = accent.
		local row=Glass.solveShell("#1F5E5A","#7FE0CF")
		assert(near(Glass.luminance(Glass.rgb(row.shell)),.131,.004)and near(Glass.luminance(Glass.rgb(row.shellLip)),.045,.003))
		assert(near(Glass.luminance(Glass.rgb(row.ink)),.011,.002)and row.well==row.ink)
		assert(near(Glass.luminance(Glass.rgb(row.shellHi)),.37,.006)and near(Glass.luminance(Glass.rgb(row.onShellSoft)),.80,.006))
		assert(row.tag=="#7FE0CF")
		-- toward(): lighter goes darker, darker goes lighter, never past the target by more than a step.
		local up=Glass.toward(Glass.rgb("#101010"),.2);local down=Glass.toward(Glass.rgb("#F0F0F0"),.2)
		assert(near(Glass.luminance(up),.2,.006)and near(Glass.luminance(down),.2,.006))
		-- A plate added later without a row is solved the same way and is still readable.
		local made=Glass.paletteHex({name="Test",accent="#FFB0C0",deep="#5A1030"})
		assert(made.solved and #Glass.failing(made)==0,"a solved plate passes the floors: "..table.concat(Glass.failing(made),", "))
	end)

	test("floors: section 3's contrast rules hold on every plate (4.5 text, 3.0 large text and fills)",function()
		local worst={}
		for id,plate in pairs(Themes.Plates)do
			local p=Glass.paletteHex(plate)
			local failing=Glass.failing(p)
			assert(#failing==0,id..": "..table.concat(failing,", "))
			for name,pair in pairs(Glass.contrasts(p))do worst[name]=math.min(worst[name]or 99,pair[1])end
		end
		-- The brief's worst cases across the 25 plates (rounded down a little).
		assert(worst.whiteOnBody>=5.7 and worst.whiteUnderGloss>=4.6 and worst.softOnBody>=4.6 and worst.softUnderGloss>=3.7)
		assert(worst.inkOnPill>=7.6 and worst.inkOnAccent>=7.6)
		assert(worst.accentOnTrack>=5.9 and worst.goodOnTrack>=7.2 and worst.warnOnTrack>=8.1 and worst.badOnTrack>=4.3)
		assert(worst.goldOnBody>=3.5 and worst.whiteOnSky>=3.0)
		-- What the rules exist for: accent bare on glass can fall far under 3:1 (rule 4 keeps it on a track).
		local low=99
		for _,plate in pairs(Themes.Plates)do
			local p=Glass.paletteHex(plate)
			low=math.min(low,Glass.contrast(Glass.rgb(p.accent),Glass.rgb(p.glassTop)))
		end
		assert(low<3,"accent on the body is under 3:1 somewhere ("..low..")")
		-- Rule 3: gold and state colours as text only at 18 px and up.
		assert(Glass.goldText(18)and Glass.goldText(26)and not Glass.goldText(17)and not Glass.goldText(nil))
	end)

	test("surfaces: the track, the pill and fill tops, the gloss, the Welcome sky and egg cards (Cloud Glass)",function()
		local p=Glass.paletteHex(Themes.Plates.cloud_glass)
		local s=Glass.surfacesHex(p)
		local function mixHex(a,b,t)return Glass.hex(Glass.mix(Glass.rgb(a),Glass.rgb(b),t))end
		assert(s.track==mixHex(p.glassBottom,p.ink,.60),"glassBottom mixed 60% to ink")
		assert(s.pillTop==mixHex(p.pill,"#FFFFFF",.55)and s.fillTop==mixHex(p.accent,"#FFFFFF",.35))
		assert(s.gloss==mixHex(p.glassTop,"#FFFFFF",.10))
		assert(s.skyTop==mixHex(p.glassTop,p.accent,.25),"the sky card: glassTop mixed 25% to accent")
		assert(s.eggTop==mixHex("#FFFFFF",p.accent,.35)and s.eggBottom==mixHex(p.accent,p.glassTop,.35),"the egg card")
		assert(s.goodTop==mixHex(p.good,"#FFFFFF",.55)and s.warnFillTop==mixHex(p.warn,"#FFFFFF",.35))
		assert(p.wellTop==mixHex(p.well,p.accent,.12),"the well lifts 12% to accent at its top")
	end)

	test("recipe: card, pill, track, well and check numbers; the shadow's gap rule",function()
		local C=Glass.Card
		assert(Glass.cardRadius(false)==16 and Glass.cardRadius(true)==12 and C.welcome==12 and C.rim==1.5)
		assert(C.rimAlpha[1]==.15 and C.rimAlpha[2]==.70)
		assert(C.gloss.inset==2 and C.gloss.height==.46 and C.gloss.top==.90 and C.gloss.bottom==.96,"rule 1: never stronger than 10%")
		assert(C.bounce.height==.35 and C.bounce.top==1 and C.bounce.bottom==.84)
		assert(C.streak.rotation==25)
		local keys={{0,1},{.30,1},{.33,.93},{.36,1},{.39,.96},{.42,1}}
		for index,k in ipairs(keys)do assert(C.streak.keys[index][1]==k[1]and C.streak.keys[index][2]==k[2])end
		assert(C.shadow.offset==3 and C.shadow.alpha==.70)
		assert(Glass.shadowWanted(8)and Glass.shadowWanted(nil)and not Glass.shadowWanted(6),"no shadow when the next card is under 8 px away")
		-- The regular left column: Score (12, 96), Chain (116, 80), Goals (204, 244); the right column beside it.
		local score,chain,goals={x=14,y=12,w=226,h=96},{x=14,y=116,w=226,h=80},{x=14,y=204,w=226,h=244}
		local right={x=600,y=12,w=226,h=140}
		local all={score,chain,goals,right}
		assert(Glass.gapBelow(score,all)==8 and Glass.gapBelow(chain,all)==8 and Glass.gapBelow(goals,all)==nil)
		assert(Glass.gapBelow(right,all)==nil,"another column is not below")
		assert(Glass.pillHeight(false)==22 and Glass.pillHeight(true)==20 and Glass.Pill.pad==10 and Glass.Pill.padCompact==8)
		assert(Glass.Pill.size==12 and Glass.Pill.stroke==.45)
		assert(Glass.Track.dot==2)
		assert(Glass.Well.rim==1.5 and Glass.Well.rimAlpha==.55 and Glass.Check.ring==.45)
	end)

	test("pill states: one pill colour per plate; good when every goal is done, bad at 3 balls or fewer, warn for a live chain",function()
		assert(Glass.pillState(nil)==nil and Glass.pillState({})==nil)
		assert(Glass.pillState({done=true})=="good"and Glass.pillState({low=true})=="bad")
		assert(Glass.pillState({live=true})=="warn"and Glass.pillState({status=true})=="warn")
		assert(Glass.pillState({done=true,status=true})=="good","done wins over a status line")
		assert(Glass.ballsLow(3)and Glass.ballsLow(0)and not Glass.ballsLow(4)and not Glass.ballsLow(nil))
		assert(Glass.allDone({{done=true},{done=true}})and not Glass.allDone({{done=true},{done=false}}))
		assert(not Glass.allDone({})and not Glass.allDone(nil),"no goals is not complete")
	end)

	test("motion: the sweep at most once a card per 1.2 s; bubbles on Goals and Next only, never compact; calm keeps none",function()
		local M=Glass.Motion
		assert(M.sweep==.35 and M.sweepGap==1.2)
		assert(Glass.sweepDue(nil,10)and Glass.sweepDue(10,11.25)and not Glass.sweepDue(10,11.1))
		assert(#M.bubbles==2 and M.bubbles[1].size==8 and M.bubbles[2].size==12 and M.bubbles[1].period==7 and M.bubbles[2].period==9)
		assert(M.bubbleAlpha==.90 and M.bubbleRim==.7)
		assert(M.bubbleCards.Goals and M.bubbleCards.Next and not M.bubbleCards.Score)
		local full=Glass.motion(false,0,false);assert(full.sweep and full.bubbles)
		local small=Glass.motion(false,0,true);assert(small.sweep and not small.bubbles,"none on a phone or the small deck")
		local reduced=Glass.motion(true,0,false);assert(not reduced.sweep and not reduced.bubbles,"Reduced Motion / Motion: Low")
		local budget=Glass.motion(false,1,false);assert(not budget.sweep and not budget.bubbles,"AliveBudget stepped down")
	end)

	return {passed=#cases,cases=cases}
end
