local Themes={
	Default = "sherbet",
	Order = { "sherbet", "stone", "ice", "brick", "moss", "honey", "gloaming", "copperleaf" },
	ById = {
		honey={name="Honey",rule="firstWin",shell=Color3.fromHex("#98632B"),face=Color3.fromHex("#B37D37"),trim=Color3.fromHex("#E5C16A"),buttons=Color3.fromHex("#D3EB93"),rocker=Color3.fromHex("#D3EB93"),backdrop=Color3.fromHex("#30271D"),band=Color3.fromHex("#655132")},
		gloaming={name="Gloaming",rule="rankI",shell=Color3.fromHex("#234E50"),face=Color3.fromHex("#326366"),trim=Color3.fromHex("#AFE4D5"),buttons=Color3.fromHex("#D9D39C"),rocker=Color3.fromHex("#D9D39C"),backdrop=Color3.fromHex("#17292D"),band=Color3.fromHex("#314B50")},
		copperleaf={name="Copperleaf",rule="rankII",shell=Color3.fromHex("#874331"),face=Color3.fromHex("#A65A3F"),trim=Color3.fromHex("#DC8E54"),buttons=Color3.fromHex("#E5C490"),rocker=Color3.fromHex("#E5C490"),backdrop=Color3.fromHex("#30211E"),band=Color3.fromHex("#683E32")},
		-- Saved IDs remain stable; Scout replaces the original default finish.
		sherbet = { backdrop = Color3.fromHex("#232620"), band = Color3.fromHex("#303B31"), name = "Scout", shell = Color3.fromHex("#326855"), face = Color3.fromHex("#48866A"),
			trim = Color3.fromHex("#8EB49D"), buttons = Color3.fromHex("#FFBF50"), rocker = Color3.fromHex("#FFBF50") },
		stone = { backdrop = Color3.fromHex("#30392D"), band = Color3.fromHex("#626C50"), name = "Pebble", shell = Color3.fromHex("#515C43"), face = Color3.fromHex("#687454"),
			trim = Color3.fromHex("#C2CEA0"), buttons = Color3.fromHex("#FFB84A"), rocker = Color3.fromHex("#FFB84A") },
		ice = { backdrop = Color3.fromHex("#183D48"), band = Color3.fromHex("#34757D"), name = "Creek", shell = Color3.fromHex("#326B73"), face = Color3.fromHex("#4A8D92"),
			trim = Color3.fromHex("#B6DBCE"), buttons = Color3.fromHex("#FFC85A"), rocker = Color3.fromHex("#FFC85A") },
		brick = { backdrop = Color3.fromHex("#563125"), band = Color3.fromHex("#874A30"), name = "Ember", shell = Color3.fromHex("#A64C24"), face = Color3.fromHex("#C9682D"),
			trim = Color3.fromHex("#FFCC7A"), buttons = Color3.fromHex("#D6EB8E"), rocker = Color3.fromHex("#D6EB8E") },
		moss = { backdrop = Color3.fromHex("#153723"), band = Color3.fromHex("#2E5B3A"), name = "Canopy", shell = Color3.fromHex("#285738"), face = Color3.fromHex("#397548"),
			trim = Color3.fromHex("#A4D66B"), buttons = Color3.fromHex("#FFC85A"), rocker = Color3.fromHex("#FFC85A") },
	},
}
-- Explicit semantic palettes: no color-matching of existing GUI descendants.
local palettes={
	sherbet={ui={"#202E28","#2D4035","#17221D","#15201A","#F1F3E5","#C3D1C4","#6E8B74","#3C5D45","#C5E6AA","#FFBF50"},lcd={"#223C2D","#C8D4A2","#A7BA84","#90A474","#344F36","#49653F"}},
	stone={ui={"#2A3028","#3B4335","#20251E","#1A2018","#F1F1E1","#CFD3C0","#858E70","#505B40","#D6E4A9","#FFB84A"},lcd={"#333C2A","#D8D9AF","#BABC91","#A6AC7D","#455238","#5D6642"}},
	ice={ui={"#172F36","#22434C","#10232A","#102229","#ECF5EB","#B8D3D2","#618D92","#315B60","#B9E6D9","#FFC85A"},lcd={"#1A3B42","#C2DED0","#9FC5B8","#84AA9D","#2E5353","#426A63"}},
	brick={ui={"#38271F","#50362A","#291D18","#271B14","#FFF0D4","#DDC4A9","#AA7854","#6B4B32","#FFE1A5","#D6EB8E"},lcd={"#503A24","#ECD8AC","#D1B985","#BDA272","#62462B","#796035"}},
	moss={ui={"#173025","#234434","#10221A","#101F17","#F0F5DD","#B7D1B1","#628967","#335C3A","#D0EAA7","#FFC85A"},lcd={"#193C28","#C4D8A0","#A0BF81","#85A367","#305237","#466841"}},
	honey={ui={"#33291D","#4B3C27","#261F16","#251C12","#FFF1D0","#DACBA8","#A58D57","#65552E","#F2E6A1","#E8C86A"},lcd={"#413D23","#DFE6A8","#C1CC87","#A7B46D","#505533","#687143"}},
	gloaming={ui={"#192C31","#263F45","#112125","#102128","#E7F4EF","#B1CCCF","#60868D","#34575D","#B9E8DF","#B8DFD0"},lcd={"#23424A","#D0E5E6","#ACCBD0","#8FB0B9","#365B65","#4E7480"}},
	copperleaf={ui={"#35251F","#4C3429","#281B16","#271A13","#FFF0D6","#DEC3AC","#A67B5E","#694A36","#F4D5A1","#E99764"},lcd={"#4D3528","#F0D8B5","#D5B88F","#BF9E75","#674A32","#7E6240"}},
}
local uiKeys={"panel","raised","inset","ink","text","muted","line","selected","focus","accent"}
local lcdKeys={"outside","base","dither","rail","rim","guide"}
for id,values in pairs(palettes)do
	local theme=Themes.ById[id];theme.ui={};theme.lcd={}
	for i,key in ipairs(uiKeys)do theme.ui[key]=Color3.fromHex(values.ui[i])end
	for i,key in ipairs(lcdKeys)do theme.lcd[key]=Color3.fromHex(values.lcd[i])end
end
return Themes
