local Themes={
	Default = "sherbet",
	Order = { "sherbet", "stone", "ice", "brick", "moss", "honey", "gloaming", "copperleaf" },
	ById = {
		sherbet = { name="Scout", highlight=Color3.fromHex("#69F4B3"), face=Color3.fromHex("#23BF89"), shell=Color3.fromHex("#147863"),
			trim=Color3.fromHex("#69F4B3"), buttons=Color3.fromHex("#76F6B0"), rocker=Color3.fromHex("#76F6B0"), backdrop=Color3.fromHex("#123C35"), band=Color3.fromHex("#147863") },
		stone = { name="Pebble", highlight=Color3.fromHex("#B8DD9D"), face=Color3.fromHex("#739877"), shell=Color3.fromHex("#48685E"),
			trim=Color3.fromHex("#B8DD9D"), buttons=Color3.fromHex("#C8EB9B"), rocker=Color3.fromHex("#C8EB9B"), backdrop=Color3.fromHex("#293D39"), band=Color3.fromHex("#48685E") },
		ice = { name="Creek", highlight=Color3.fromHex("#7FF7EE"), face=Color3.fromHex("#23B9D7"), shell=Color3.fromHex("#216892"),
			trim=Color3.fromHex("#7FF7EE"), buttons=Color3.fromHex("#70ECFF"), rocker=Color3.fromHex("#70ECFF"), backdrop=Color3.fromHex("#143B50"), band=Color3.fromHex("#216892") },
		brick = { name="Ember", highlight=Color3.fromHex("#FFB568"), face=Color3.fromHex("#F56444"), shell=Color3.fromHex("#AB3047"),
			trim=Color3.fromHex("#FFB568"), buttons=Color3.fromHex("#FF9B70"), rocker=Color3.fromHex("#FF9B70"), backdrop=Color3.fromHex("#49242D"), band=Color3.fromHex("#AB3047") },
		moss = { name="Canopy", highlight=Color3.fromHex("#BBF477"), face=Color3.fromHex("#61BD44"), shell=Color3.fromHex("#27734A"),
			trim=Color3.fromHex("#BBF477"), buttons=Color3.fromHex("#BCF57B"), rocker=Color3.fromHex("#BCF57B"), backdrop=Color3.fromHex("#193E31"), band=Color3.fromHex("#27734A") },
		honey = { name="Honey", rule="firstWin", highlight=Color3.fromHex("#FFE49A"), face=Color3.fromHex("#F2A73E"), shell=Color3.fromHex("#AF622F"),
			trim=Color3.fromHex("#FFE49A"), buttons=Color3.fromHex("#FFD77D"), rocker=Color3.fromHex("#FFD77D"), backdrop=Color3.fromHex("#443022"), band=Color3.fromHex("#AF622F") },
		gloaming = { name="Gloaming", rule="rankI", highlight=Color3.fromHex("#8FF5E5"), face=Color3.fromHex("#4A9FA7"), shell=Color3.fromHex("#465489"),
			trim=Color3.fromHex("#8FF5E5"), buttons=Color3.fromHex("#92ECE6"), rocker=Color3.fromHex("#92ECE6"), backdrop=Color3.fromHex("#25344A"), band=Color3.fromHex("#465489") },
		copperleaf = { name="Copperleaf", rule="rankII", highlight=Color3.fromHex("#FFBE83"), face=Color3.fromHex("#DB7351"), shell=Color3.fromHex("#8D4456"),
			trim=Color3.fromHex("#FFBE83"), buttons=Color3.fromHex("#FFBC90"), rocker=Color3.fromHex("#FFBC90"), backdrop=Color3.fromHex("#432735"), band=Color3.fromHex("#8D4456") },
	},
}
-- Explicit semantic palettes: no color-matching of existing GUI descendants.
local palettes={
	sherbet={lcd={"#223C2D","#C8D4A2","#A7BA84","#90A474","#344F36","#49653F"}},
	stone={lcd={"#333C2A","#D8D9AF","#BABC91","#A6AC7D","#455238","#5D6642"}},
	ice={lcd={"#1A3B42","#C2DED0","#9FC5B8","#84AA9D","#2E5353","#426A63"}},
	brick={lcd={"#503A24","#ECD8AC","#D1B985","#BDA272","#62462B","#796035"}},
	moss={lcd={"#193C28","#C4D8A0","#A0BF81","#85A367","#305237","#466841"}},
	honey={lcd={"#413D23","#DFE6A8","#C1CC87","#A7B46D","#505533","#687143"}},
	gloaming={lcd={"#23424A","#D0E5E6","#ACCBD0","#8FB0B9","#365B65","#4E7480"}},
	copperleaf={lcd={"#4D3528","#F0D8B5","#D5B88F","#BF9E75","#674A32","#7E6240"}},
}
local lcdKeys={"outside","base","dither","rail","rim","guide"}
local panels={sherbet="#123C35",stone="#293D39",ice="#143B50",brick="#49242D",moss="#193E31",honey="#443022",gloaming="#25344A",copperleaf="#432735"}
local dark=Color3.new(0,0,0)
for id,values in pairs(palettes)do
 local theme=Themes.ById[id];local panel=Color3.fromHex(panels[id]);theme.lcd={}
 local saturated={sherbet="#12644A",stone="#2E5B47",ice="#075C82",brick="#902B4B",moss="#1A5C35",honey="#694618",gloaming="#45458B",copperleaf="#743A4A"}
 local shell=Color3.fromHex(saturated[id]);local white=Color3.fromHex("#F8F8EA")
 theme.ui={panel=shell,raised=shell:Lerp(white,.07),inset=shell:Lerp(dark,.40),ink=Color3.fromHex("#062417"),text=white,muted=Color3.fromHex("#E2EEE3"),line=theme.highlight,selected=shell:Lerp(white,.09),focus=Color3.fromHex("#FFFFFF"),accent=theme.buttons}
 theme.ui.tab=({sherbet=Color3.fromHex("#38B84A"),stone=Color3.fromHex("#B8DD9D"),ice=Color3.fromHex("#069FC3"),brick=Color3.fromHex("#CB1E61"),moss=Color3.fromHex("#80CB32"),honey=Color3.fromHex("#F8C944"),gloaming=Color3.fromHex("#7543CF"),copperleaf=Color3.fromHex("#E59843")})[id]
 theme.ui.tabInk=if id=="brick"or id=="gloaming"then white else Color3.fromHex("#062417")
 theme.ui.contentPanel=Color3.fromHex("#F8F8EA")
 theme.ui.contentRaised=theme.highlight:Lerp(Color3.fromHex("#FFFFFF"),.77)
 theme.ui.contentInset=theme.face:Lerp(Color3.fromHex("#FFFFFF"),.86)
 theme.ui.contentText=Color3.fromHex("#10382E");theme.ui.contentMuted=Color3.fromHex("#36554B")
 theme.ui.contentLine=theme.shell:Lerp(Color3.fromHex("#10382E"),.35)
 theme.ui.contentSelected=theme.highlight:Lerp(Color3.fromHex("#FFFFFF"),.59)
 theme.ui.contentFocus=Color3.fromHex("#075F8A");theme.ui.contentReward=Color3.fromHex("#87500F")
 -- Three authored stops are reused by worn hardware and isolated Style previews.
 theme.shellGradient=ColorSequence.new({ColorSequenceKeypoint.new(0,theme.highlight),ColorSequenceKeypoint.new(.34,theme.face),ColorSequenceKeypoint.new(1,theme.shell)})
 theme.faceGradient=theme.shellGradient
 for i,key in ipairs(lcdKeys)do theme.lcd[key]=Color3.fromHex(values.lcd[i])end
end
return Themes
