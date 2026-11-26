-- The 16 standard PICO-8 colours as shared presentation tokens.
-- Index by the PICO-8 number (Pico8[0] .. Pico8[15]) or by role name below.
-- Presentation only: nothing on the server's authority reads these.
local hex = {
	[0] = "#000000", "#1D2B53", "#7E2553", "#008751", "#AB5236", "#5F574F", "#C2C3C7", "#FFF1E8",
	"#FF004D", "#FFA300", "#FFEC27", "#00E436", "#29ADFF", "#83769C", "#FF77A8", "#FFCCAA",
}

local Pico8 = { hex = table.freeze(table.clone(hex)), count = 16 }
for index = 0, 15 do
	Pico8[index] = Color3.fromHex(hex[index])
end

-- Named roles from OVERNIGHT-2026-11-12.md section 2D.
Pico8.Black, Pico8.DarkBlue, Pico8.DarkPurple, Pico8.DarkGreen = Pico8[0], Pico8[1], Pico8[2], Pico8[3]
Pico8.Brown, Pico8.DarkGrey, Pico8.LightGrey, Pico8.White = Pico8[4], Pico8[5], Pico8[6], Pico8[7]
Pico8.Red, Pico8.Orange, Pico8.Yellow, Pico8.Green = Pico8[8], Pico8[9], Pico8[10], Pico8[11]
Pico8.Blue, Pico8.Lavender, Pico8.Pink, Pico8.Peach = Pico8[12], Pico8[13], Pico8[14], Pico8[15]

Pico8.Ink = Pico8[0]
Pico8.Danger = Pico8[8]
Pico8.Star, Pico8.StarShadow = Pico8[10], Pico8[9]
Pico8.Focus = Pico8[12]
Pico8.Primary = Pico8[11]
Pico8.Heart, Pico8.Sleepy = Pico8[14], Pico8[13]

-- Jelly tier ramps (UI-SPEC-REDESIGN-MENUS 6.2): vivid deep / body / light hex
-- triples plus a motif per tier, so colour is never the only tier cue. These
-- replace the PICO-8 rim ramps for eggs; tier V is violet, not yellow.
-- Batch 2026-11-13 R1: these are the Smileys / Marbles ramps (BallThemes `vivid`);
-- the motifs now draw only in the free Marbles theme, and no theme draws numerals.
-- AERO-JUICE-BRIEF 1 (2026-11-26): the "Aero Glass" ramps (BallThemes.Aero), so the ghost, the merge burst colours
-- and Marbles' motifs match the new default balls. Was vivid #2E8BFF / #FF8A1A / #22E06A / #FF4DA6 / #A66BFF.
Pico8.TierRamps = table.freeze({
	table.freeze({ deep = "#0B74D1", body = "#22B8F2", light = "#A6ECFF", motif = "plain" }),
	table.freeze({ deep = "#EC7A0E", body = "#FFB52A", light = "#FFEFA3", motif = "bands" }),
	table.freeze({ deep = "#0E8F45", body = "#2FCB5A", light = "#C4FF9A", motif = "speckles" }),
	table.freeze({ deep = "#D8327E", body = "#FF6FA8", light = "#FFD3E6", motif = "stars" }),
	table.freeze({ deep = "#4426C2", body = "#7D5CF0", light = "#D6CBFF", motif = "dots" }),
})

-- Chain caption colours as a chain grows: 9 -> 10 -> 8.
Pico8.ChainRamp = table.freeze({ Pico8[9], Pico8[10], Pico8[8] })

return table.freeze(Pico8)
