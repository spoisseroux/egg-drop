local Themes={
	Default = "sherbet",
	Order = { "sherbet", "stone", "ice", "brick", "moss", "honey", "gloaming", "copperleaf",
		"aqua_pop", "lime_gel", "sorbet_sky", "liquid_chrome", "tidepool", "aurora_glass", "prism_flare", "night_orb",
		-- Overnight 2026-11-14 (slice C): palette variants, appended so the first 16 keep their places.
		"grape_soda", "rose_chrome" },
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
-- Pocket Deck faceplates (UI-SPEC-2026-11-12 section 8). The 8 starter ids are
-- the saved DeckThemes ids; the 8 Y2K plates are sold for fixed Star prices.
-- Generated from assets/deck/faceplates/faceplates.json (+ asset-ids.json).
local Plates={
 sherbet={name="Scout",order=1,tier="starter",priceStars=0,texture="rbxassetid://112897675123239",finish="gloss",accent="#76F6B0",ink="#0E0F12",deep="#147863",band="#FFFFFF",engrave="#0E0F12",engraveOpacity=0.42,
  ui={panel="#152525",raised="#213335",well="#0D1818",selected="#2D4E46",line="#8DBEAC"},overlay={image="rbxassetid://114031715260538",kind="gloss",min=0.0,max=0.35,period=6.0},held3d={material="SmoothPlastic",reflectance=0.08,transparency=0}},
 stone={name="Pebble",order=2,tier="starter",priceStars=0,texture="rbxassetid://70670641097836",finish="matte speckle",accent="#C8EB9B",ink="#0E0F12",deep="#48685E",band="#6F7480",engrave="#0E0F12",engraveOpacity=0.42,
  ui={panel="#1C2224",raised="#293134",well="#121618",selected="#3F4B42",line="#AABAA5"},overlay=nil,held3d={material="Plastic",reflectance=0.08,transparency=0}},
 ice={name="Creek",order=3,tier="starter",priceStars=0,texture="rbxassetid://119556542491955",finish="clear plastic",accent="#70ECFF",ink="#0E0F12",deep="#216892",band="#FFFFFF",engrave="#0E0F12",engraveOpacity=0.42,
  ui={panel="#17222C",raised="#23313C",well="#0E161D",selected="#2E4B57",line="#8BBBC8"},overlay={image="rbxassetid://105339906963951",kind="water",min=0.1,max=0.4,period=5.0},held3d={material="Glass",reflectance=0.08,transparency=0.25}},
 brick={name="Ember",order=4,tier="starter",priceStars=0,texture="rbxassetid://94183456721116",finish="brushed metal",accent="#FF9B70",ink="#0E0F12",deep="#AB3047",band="#6F7480",engrave="#0E0F12",engraveOpacity=0.42,
  ui={panel="#2A1A21",raised="#392830",well="#1C1016",selected="#553839",line="#BD9E96"},overlay=nil,held3d={material="Metal",reflectance=0.25,transparency=0}},
 moss={name="Canopy",order=5,tier="starter",priceStars=0,texture="rbxassetid://135606664666122",finish="leaf print gloss",accent="#BCF57B",ink="#0E0F12",deep="#27734A",band="#FFFFFF",engrave="#0E0F12",engraveOpacity=0.42,
  ui={panel="#182422",raised="#243231",well="#0F1716",selected="#394D3B",line="#A6BE9A"},overlay=nil,held3d={material="SmoothPlastic",reflectance=0.08,transparency=0}},
 honey={name="Honey",order=6,tier="starter",priceStars=0,texture="rbxassetid://139483187822198",finish="pearl",accent="#FFD77D",ink="#0E0F12",deep="#AF622F",band="#EBC978",engrave="#0E0F12",engraveOpacity=0.42,
  ui={panel="#2B221E",raised="#39302C",well="#1C1613",selected="#554737",line="#BDB39A"},overlay={image="rbxassetid://114031715260538",kind="gloss",min=0.0,max=0.3,period=7.0},held3d={material="SmoothPlastic",reflectance=0.08,transparency=0}},
 gloaming={name="Gloaming",order=7,tier="starter",priceStars=0,texture="rbxassetid://131585392712948",finish="two-tone gloss",accent="#92ECE6",ink="#0E0F12",deep="#465489",band="#FFFFFF",engrave="#0E0F12",engraveOpacity=0.42,
  ui={panel="#1C202A",raised="#292D3B",well="#12141C",selected="#384853",line="#97BBBF"},overlay={image="rbxassetid://94774890275610",kind="sparkle",min=0.0,max=0.55,period=3.2},held3d={material="SmoothPlastic",reflectance=0.08,transparency=0}},
 copperleaf={name="Copperleaf",order=8,tier="starter",priceStars=0,texture="rbxassetid://132092721259236",finish="brushed copper",accent="#FFBC90",ink="#0E0F12",deep="#8D4456",band="#F0B8B0",engrave="#0E0F12",engraveOpacity=0.42,
  ui={panel="#261D23",raised="#342B33",well="#191217",selected="#503F40",line="#BDAAA1"},overlay=nil,held3d={material="Metal",reflectance=0.25,transparency=0}},
 aqua_pop={name="Aqua Pop",order=9,tier="common",priceStars=20,texture="rbxassetid://79634182860528",finish="glossy bubbles",accent="#6FE3FF",ink="#0E0F12",deep="#1B6FA8",band="#FFFFFF",engrave="#0E0F12",engraveOpacity=0.42,
  ui={panel="#16232F",raised="#223240",well="#0E171F",selected="#2D4B5B",line="#8BB7C8"},overlay={image="rbxassetid://114031715260538",kind="gloss",min=0.0,max=0.4,period=5.0},held3d={material="SmoothPlastic",reflectance=0.08,transparency=0}},
 lime_gel={name="Lime Gel",order=10,tier="common",priceStars=20,texture="rbxassetid://120212176951748",finish="translucent gel",accent="#B6F24B",ink="#0E0F12",deep="#3E7D12",band="#FFFFFF",engrave="#0E0F12",engraveOpacity=0.42,
  ui={panel="#1B251A",raised="#273428",well="#111810",selected="#3B4F2D",line="#A4BD89"},overlay={image="rbxassetid://114031715260538",kind="gloss",min=0.0,max=0.35,period=5.5},held3d={material="Glass",reflectance=0.08,transparency=0.25}},
 sorbet_sky={name="Sorbet Sky",order=11,tier="common",priceStars=20,texture="rbxassetid://85539453492749",finish="glossy gradient",accent="#FFB37A",ink="#0E0F12",deep="#B8456B",band="#F0B8B0",engrave="#0E0F12",engraveOpacity=0.42,
  ui={panel="#2C1D26",raised="#3B2B36",well="#1D1319",selected="#563E40",line="#BDA799"},overlay={image="rbxassetid://114031715260538",kind="gloss",min=0.0,max=0.35,period=6.0},held3d={material="SmoothPlastic",reflectance=0.08,transparency=0}},
 liquid_chrome={name="Liquid Chrome",order=12,tier="rare",priceStars=40,texture="rbxassetid://89787687297986",finish="chrome",accent="#DCE6F5",ink="#0E0F12",deep="#4A5568",band="#FFFFFF",engrave="#0E0F12",engraveOpacity=0.42,
  ui={panel="#1C2026",raised="#292E36",well="#121419",selected="#424851",line="#B1B8C4"},overlay={image="rbxassetid://114031715260538",kind="gloss",min=0.0,max=0.5,period=4.0},held3d={material="Metal",reflectance=0.25,transparency=0}},
 tidepool={name="Tidepool",order=13,tier="rare",priceStars=40,texture="rbxassetid://128201905497104",finish="water overlay",accent="#5CD6E8",ink="#0E0F12",deep="#0E4A7A",band="#FFFFFF",engrave="#FFFFFF",engraveOpacity=0.78,
  ui={panel="#141E28",raised="#202C38",well="#0C131B",selected="#284451",line="#84B3C0"},overlay={image="rbxassetid://105339906963951",kind="water",min=0.15,max=0.7,period=4.5},held3d={material="Glass",reflectance=0.08,transparency=0.25}},
 aurora_glass={name="Aurora Glass",order=14,tier="rare",priceStars=40,texture="rbxassetid://93664804690525",finish="aurora overlay",accent="#7CF5C4",ink="#0E0F12",deep="#1B2A5E",band="#6F7480",engrave="#FFFFFF",engraveOpacity=0.78,
  ui={panel="#161A24",raised="#222734",well="#0E1018",selected="#2F4448",line="#90BEB3"},overlay={image="rbxassetid://104767690020788",kind="aurora",min=0.1,max=0.75,period=6.5},held3d={material="SmoothPlastic",reflectance=0.08,transparency=0}},
 prism_flare={name="Prism Flare",order=15,tier="showcase",priceStars=80,texture="rbxassetid://71935198179823",finish="holographic lens flare",accent="#F3B6FF",ink="#0E0F12",deep="#5B4BA8",band="#FFFFFF",engrave="#0E0F12",engraveOpacity=0.42,
  ui={panel="#1F1E2F",raised="#2C2C40",well="#14131F",selected="#483F5B",line="#B9A8C8"},overlay={image="rbxassetid://94774890275610",kind="sparkle",min=0.0,max=0.8,period=2.8},held3d={material="Foil",reflectance=0.25,transparency=0}},
 night_orb={name="Night Orb",order=16,tier="showcase",priceStars=80,texture="rbxassetid://85678618484391",finish="glass orbs and chrome rings",accent="#FF7AD9",ink="#0E0F12",deep="#1A1440",band="#6F7480",engrave="#FFFFFF",engraveOpacity=0.78,
  ui={panel="#161720",raised="#22232F",well="#0D0E15",selected="#412F47",line="#BD93BA"},overlay={image="rbxassetid://94774890275610",kind="sparkle",min=0.0,max=0.7,period=3.4},held3d={material="SmoothPlastic",reflectance=0.08,transparency=0}},
 -- Book-only plate (PLAY-FOREVER BUILD-PLAN F1): never sold (no price), granted by the
 -- collection book claim when any three pages reach 100%. Teal cloth-bound library book:
 -- linen weave, blind-stamped double rule with a gold line, gold corner protectors, a rust
 -- ribbon bookmark, paper band and a gold-stamped wordmark (Astra, build_faceplates.py bookworm).
 -- Not in Themes.Order (the shop grid's 16 sold/earned plates); listed in Themes.BookOnly.
  -- texture: assets/deck/faceplates/bookworm.png (uploaded 2026-11-13).
 bookworm={name="Bookworm",order=17,tier="book",priceStars=0,bookOnly=true,texture="rbxassetid://124980468376325",finish="cloth-bound",accent="#7FE0CF",ink="#0E0F12",deep="#1F5E5A",band="#F2E2C2",engrave="#F2CF7A",engraveOpacity=0.85,
  ui={panel="#162124",raised="#222F33",well="#0E1517",selected="#2F4849",line="#91B6B7"},overlay=nil,held3d={material="Fabric",reflectance=0.08,transparency=0}},
 -- Slice C (overnight 2026-11-14, VISUAL-BRIEF 2): palette variants of Aqua Pop and Liquid Chrome
 -- (build_faceplates.py grape_soda / rose_chrome). Orders 18 and 19: Bookworm keeps 17.
 grape_soda={name="Grape Soda",order=18,tier="common",priceStars=20,texture="rbxassetid://99091469418481",finish="glossy bubbles",accent="#C9A6FF",ink="#0E0F12",deep="#5A3FA8",band="#FFFFFF",engrave="#0E0F12",engraveOpacity=0.42,
  ui={panel="#1F1D2F",raised="#2C2A40",well="#14121F",selected="#423B5B",line="#AAA2C8"},overlay={image="rbxassetid://114031715260538",kind="gloss",min=0.0,max=0.4,period=5.0},held3d={material="SmoothPlastic",reflectance=0.08,transparency=0}},
 rose_chrome={name="Rose Chrome",order=19,tier="rare",priceStars=40,texture="rbxassetid://120581388184665",finish="rose chrome",accent="#FFC2D4",ink="#0E0F12",deep="#8A4660",band="#F0B8B0",engrave="#0E0F12",engraveOpacity=0.42,
  ui={panel="#251E25",raised="#332B34",well="#191318",selected="#50404A",line="#BDACB9"},overlay={image="rbxassetid://114031715260538",kind="gloss",min=0.0,max=0.5,period=4.0},held3d={material="Metal",reflectance=0.25,transparency=0}},
}
local hex=Color3.fromHex
for id,plate in pairs(Plates)do
 local theme=Themes.ById[id]
 if not theme then
  -- New plates derive the legacy hardware roles from accent and deep.
  local accent,deep=hex(plate.accent),hex(plate.deep)
  theme={name=plate.name,highlight=accent,face=accent:Lerp(deep,.45),shell=deep,trim=accent,buttons=accent,rocker=accent,
   backdrop=deep:Lerp(Color3.new(0,0,0),.55),band=deep}
  Themes.ById[id]=theme
 end
 theme.tier,theme.priceStars,theme.order,theme.finish=plate.tier,plate.priceStars,plate.order,plate.finish
 theme.texture,theme.overlay,theme.held3d=plate.texture,plate.overlay,plate.held3d
 theme.accent,theme.deep,theme.ink=hex(plate.accent),hex(plate.deep),hex(plate.ink)
 theme.bandTint,theme.engrave,theme.engraveOpacity=hex(plate.band),hex(plate.engrave),plate.engraveOpacity
 if plate.priceStars>0 then theme.rule="stars"end
 if plate.bookOnly then theme.rule="book";theme.bookOnly=true end
 -- Glass layers lean toward deep; accent marks selection, primary and progress.
 local ui=plate.ui
 local panel,raised,inset,selected,line=hex(ui.panel),hex(ui.raised),hex(ui.well),hex(ui.selected),hex(ui.line)
 local text,soft,ink=hex("#F3F4F6"),hex("#C3C8D0"),theme.ink
 theme.ui={panel=panel,raised=raised,inset=inset,ink=ink,text=text,muted=soft,line=line,selected=selected,focus=hex("#FFFFFF"),accent=theme.accent}
 theme.ui.tab=theme.accent;theme.ui.tabInk=ink
 theme.ui.contentPanel=panel;theme.ui.contentRaised=raised;theme.ui.contentInset=inset
 theme.ui.contentText=text;theme.ui.contentMuted=soft
 theme.ui.contentLine=line;theme.ui.contentSelected=selected
 theme.ui.contentFocus=hex("#FFFFFF");theme.ui.contentReward=hex("#FFC14D")
 theme.shellGradient=ColorSequence.new({ColorSequenceKeypoint.new(0,theme.highlight),ColorSequenceKeypoint.new(.34,theme.face),ColorSequenceKeypoint.new(1,theme.shell)})
 theme.faceGradient=theme.shellGradient
 -- Dark-well board (section 5.1): the board sits in the plate's `well` glass.
 -- Grain, rails and the threshold line are white mixes over the well so the
 -- bright PICO-8 jelly tiers keep their contrast on every plate.
 local white=Color3.new(1,1,1)
 theme.lcd={outside=inset:Lerp(Color3.new(0,0,0),.3),base=inset,dither=inset:Lerp(white,.035),
  rail=inset:Lerp(white,.16),rim=inset:Lerp(white,.26),guide=inset:Lerp(white,.42),
  -- The redesigned well lifts 7% toward the plate accent at the top (JellyLCD).
  accent=theme.accent}
end
Themes.Plates=Plates
-- Plates that only the collection book grants (never sold, not in the shop grid's Order).
Themes.BookOnly={"bookworm"}
-- Fixed Star price for a plate, or nil when it is not sold (book-only plates never are).
function Themes.price(id)
 local theme=Themes.ById[id]
 return if theme and not theme.bookOnly and (theme.priceStars or 0)>0 then theme.priceStars else nil
end
function Themes.isBookOnly(id)local theme=Themes.ById[id];return theme~=nil and theme.bookOnly==true end
return Themes
