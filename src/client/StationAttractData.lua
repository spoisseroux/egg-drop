-- Station attract tuning and art ids (FEEL-ALIVE-DIRECTION-2026-11-13 D).
-- IconIds are PLACEHOLDERS until the coordinator uploads
-- assets/ui/attract/attract_icon_{deck,eggs,care}.png (built by
-- scripts/build_attract_icons.py). With no id the icon draws a flat stand-in.
return table.freeze({
	IconIds = table.freeze({
		Customize = 125937977156864, -- assets/ui/attract/attract_icon_deck.png
		Eggs = 75481788921574, -- assets/ui/attract/attract_icon_eggs.png
		Journal = 77942657202363, -- assets/ui/attract/attract_icon_care.png
		Park = 108874072462773, -- assets/ui/attract/attract_icon_park.png
	}),
	-- id = the ProximityPrompt's PocketClubStation attribute.
	Stations = table.freeze({
		Customize = table.freeze({ hue = "#35C7F5", light = "#B8ECFF", glyph = "▣", pitch = 1.00, iconHeight = 9.5 }),
		Eggs = table.freeze({ hue = "#FFC83C", light = "#FFEEAA", glyph = "◒", pitch = 1.12, iconHeight = 5.6 }),
		Journal = table.freeze({ hue = "#FF6FAE", light = "#FFC9DC", glyph = "♥", pitch = 0.89, iconHeight = 9.5 }),
		-- Pet Park (QA Q4): over the east gateway; "used" once the player first walks in (no prompt).
		Park = table.freeze({ hue = "#3FB98A", light = "#C9F7E2", glyph = "★", pitch = 1.06, iconHeight = 6.2 }),
	}),
	Order = table.freeze({ "Customize", "Eggs", "Journal", "Park" }),
	BeckonRange = 40, InviteRange = 14,
	-- QA v2 R5.1/R5.2: a learned station is never fully silent. Within MarkerRange it shows the
	-- marker (icon + pointer, no shaft/ring/sparkles/ping); within LabelRange any station shows
	-- its name label. The first label per station (per session, until used/learned) also carries
	-- a one-line "what it is" for IntroSeconds of being shown.
	MarkerRange = 18, LabelRange = 14, IntroSeconds = 4,
	-- Glow breath: +-8 % learned, +-20 % beckon/invite, on a 3.2 s cycle.
	BreathLearned = .08, BreathActive = .20, BreathPeriod = 3.2, GlowBrightness = .45, GlowRange = 9,
	ShaftHeight = 12, RingRadius = 4.7, RippleEvery = 2.4,
	IconSize = 1.8, IconMaxDistance = 60, BobHeight = .25, BobPeriod = 1.6,
	-- QA v2 R5.1: one connected marker. The billboard is IconSize wide and MarkerAspect tall;
	-- the round icon fills the top square and the pointer (a diamond tucked under the disc, its
	-- side corners on the disc edge) reaches PointerTip icon-widths below the icon centre.
	MarkerAspect = 1.6, PointerHalf = .34, PointerTip = .70,
	-- Invite: the whole marker hops twice (0.5 s each) then rests 1 s.
	HopTime = .5, HopRest = 1, HopHeight = .35,
	-- Ping limits: one per station per 45 s, one of any kind per 20 s, none in the first 10 s.
	PingStation = 45, PingAny = 20, PingJoin = 10, PingVolume = .35,
	HideAfterUse = 2,
})
