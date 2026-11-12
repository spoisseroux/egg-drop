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
for id,values in pairs(palettes)do
 local theme=Themes.ById[id];theme.lcd={}
 -- Menus are dark graphite glass. The equipped deck only tints them: surfaces lean
 -- slightly toward its shell, and its bright button colour marks selection,
 -- tabs, primary actions and progress. Text stays neutral for contrast.
 local glass,raisedGlass,well=Color3.fromHex("#15171B"),Color3.fromHex("#23262C"),Color3.fromHex("#0C0D10")
 local text,soft,ink=Color3.fromHex("#F3F4F6"),Color3.fromHex("#C3C8D0"),Color3.fromHex("#0E0F12")
 local tint=theme.buttons
 local panel=glass:Lerp(theme.shell,.14);local raised=raisedGlass:Lerp(theme.shell,.16)
 local inset=well:Lerp(theme.shell,.10);local selected=raised:Lerp(tint,.14)
 local line=Color3.fromHex("#9AA0AA"):Lerp(tint,.35)
 theme.ui={panel=panel,raised=raised,inset=inset,ink=ink,text=text,muted=soft,line=line,selected=selected,focus=Color3.fromHex("#FFFFFF"),accent=tint}
 theme.ui.tab=tint;theme.ui.tabInk=ink
 -- Content inside a sheet uses the same glass; the scoped roles keep their names.
 theme.ui.contentPanel=panel;theme.ui.contentRaised=raised;theme.ui.contentInset=inset
 theme.ui.contentText=text;theme.ui.contentMuted=soft
 theme.ui.contentLine=line;theme.ui.contentSelected=selected
 theme.ui.contentFocus=Color3.fromHex("#FFFFFF");theme.ui.contentReward=Color3.fromHex("#FFC14D")
 -- Three authored stops are reused by worn hardware and isolated Style previews.
 theme.shellGradient=ColorSequence.new({ColorSequenceKeypoint.new(0,theme.highlight),ColorSequenceKeypoint.new(.34,theme.face),ColorSequenceKeypoint.new(1,theme.shell)})
 theme.faceGradient=theme.shellGradient
 for i,key in ipairs(lcdKeys)do theme.lcd[key]=Color3.fromHex(values.lcd[i])end
end
return Themes
