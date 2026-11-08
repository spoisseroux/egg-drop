-- Actual worn-device factory/update source; fresh shared palette instances.
return function(server,loungeSource)
	assert(type(loungeSource)=="string","Actual Lounge source required")
	local shared=game.ReplicatedStorage.Shared:Clone();shared.Name="_WornThemeShared";shared.Parent=server
	local actualRequire=require
	local realGame=game
	local fakeGame={}
	function fakeGame:GetService(name)if name=="ReplicatedStorage"then return{Shared=shared}end;return realGame:GetService(name)end
	local module=Instance.new("ModuleScript");module.Name="_WornThemeFactory"
	module.Source="return function(e) local game,script,require=e.game,e.script,e.require\n"..loungeSource.."\nend"
	module.Parent=server;local ok,run=pcall(actualRequire,module);module:Destroy();assert(ok,run)
	local lounge=run({game=fakeGame,script=server.Lounge,require=function(target)
		if target==server.LoungeArt then return{}end;return actualRequire(target)
	end})
	local themes=actualRequire(shared.DeckThemes)
	local character=Instance.new("Model");character.Name="_WornThemeCharacter";character.Parent=server
	for _,name in ipairs({"HumanoidRootPart","Torso"})do
		local part=Instance.new("Part");part.Name=name;part.Anchored=true;part.Parent=character
	end
	local cases={}
	local function test(name,check)check();table.insert(cases,name)end
	test("actual worn factory initializes the Screen with its selected LCD palette",function()
		lounge.setMode(character,900001,"Board","gloaming","none")
		assert(character.PocketDeck.Screen.Color==themes.ById.gloaming.lcd.base)
	end)
	test("all eight updates tint the same Screen without repainting independent overlay dots or geometry",function()
		local device=character.PocketDeck;local screen=device.Screen
		local size,cf=screen.Size,screen.CFrame
		-- An already-owned transparent live tray remains independent of casing paint.
		local surface=Instance.new("SurfaceGui");surface.Name="LiveTray";surface.Parent=screen
		local dot=Instance.new("Frame");dot.Name="EggDot";dot.BackgroundColor3=Color3.fromHex("#77BAE5")
		dot.Size,dot.Position=UDim2.fromOffset(8,7),UDim2.fromOffset(10,20);dot.Parent=surface
		local color,dotSize,dotPosition=dot.BackgroundColor3,dot.Size,dot.Position
		for _,id in ipairs(themes.Order)do
			lounge.setAppearance(character,id,"none")
			assert(device.Screen==screen and screen.Color==themes.ById[id].lcd.base)
			assert(screen.Size==size and screen.CFrame==cf and surface.Parent==screen)
			assert(dot.BackgroundColor3==color and dot.Size==dotSize and dot.Position==dotPosition)
		end
	end)
	character:Destroy();shared:Destroy()
	return{passed=#cases,cases=cases,persistentWrites=false,evidence="actual Lounge factory/update; overlay sentinel preservation, not a LiveTray rendering audition"}
end
