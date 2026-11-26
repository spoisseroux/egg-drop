-- "Aero Glass" bubble shading for one ball on the 64-wide LCD (AERO-JUICE-BRIEF 1). Pure: tones in, a packed colour
-- out. JellyLCD uses it for every ramp that has `rim` and `spec` (BallThemes: Smileys and Marbles); themes without
-- them keep their own shaders. No outline; bloom stays the body colour (JellyLCD).
--   1. Three vertical bands: body lifted halfway to `light` (LIGHTMID) in the top 35%, body, `deep` in the bottom 25%.
--      No dither (each row stays one or two runs, inside the span budget).
--   2. The two-part glint in `spec`: a bar upper left (2 x 1 px, 3 x 2 on tiers IV and V) and a separate 1 px dot
--      below-right of it (tiers II to V; tier I is all face). Pixel exact: placed in the face's own grid (JellyLCD
--      paintFace anchors at round(cx), round(cy)), each dot above the eyes, so the face never covers them.
--   3. The bounce crescent: a 1 px `rim` arc on the lower-right inner edge, tiers III to V.
--   4. Over SimplifyAbove (JellyLCD's replay): level 1 drops the crescent, level 2 the dot too.
-- `begin` is called once per ball (or merge blob) before its pixels: the centre, the light radii, the twinkle.
local Shade={}
-- Tone roles, the same indices as JellyLCD's (it asserts them).
Shade.DEEP,Shade.BODY,Shade.LIGHT,Shade.GLINT,Shade.MOTIF,Shade.KIND,Shade.LIGHTMID=1,2,3,4,5,6,7
Shade.RIM=12
local DEEP,BODY,GLINT,MOTIF,KIND,LIGHTMID,RIM=1,2,4,5,6,7,12
Shade.TopBand,Shade.BottomBand=-.3,.5 -- ly over the lit extents: above -0.3 is the top 35%, below 0.5 the bottom 25%
Shade.CrescentFrom=3
-- {bar left column, bar top row, bar width, bar height, dot column, dot row} in face-grid pixels from the centre.
-- Checked against every BallFaces face (scripts/AeroJuice.spec.lua): no glint pixel is under a face pixel, wide eyes
-- too, and every glint pixel is inside the ball wherever its centre falls between pixels.
Shade.Glint=table.freeze({
	table.freeze({-2,-3,2,1}),
	table.freeze({-3,-4,2,1,0,-3}),
	table.freeze({-5,-5,2,1,-2,-4}),
	table.freeze({-7,-7,3,2,-2,-5}),
	table.freeze({-8,-9,3,2,-4,-7}),
})
local simple=0
local ox,oy,rx,ry,twinkle=0,0,1,1,0
-- 0 full, 1 no crescent, 2 no crescent and no dot.
function Shade.setSimple(level)simple=level or 0 end
function Shade.simple()return simple end
-- cx, cy: the ball's centre in LCD pixels; lightX, lightY: what lx, ly were divided by; shift: the twinkle (0 or 1 px).
function Shade.begin(cx,cy,lightX,lightY,shift)
	ox,oy=cx-.5-math.round(cx),cy-.5-math.round(cy)
	rx,ry=lightX,lightY;twinkle=shift or 0
end
-- The face-grid pixel of a sample (lx, ly over the lit extents).
local function cell(lx,ly)return math.floor(lx*rx+ox+.5),math.floor(ly*ry+oy+.5)end
Shade.cell=cell
-- t: JellyLCD theme tones (t.tier, optional t.motifAt for Marbles' motifs).
function Shade.shade(t,lx,ly,q)
	local tier=t.tier
	local g=Shade.Glint[tier]
	local ix,iy=cell(lx,ly)
	local bx=g[1]+twinkle
	if ix>=bx and ix<bx+g[3]and iy>=g[2]and iy<g[2]+g[4]then return t[GLINT]end
	if g[5]and simple<2 and ix==g[5]and iy==g[6]then return t[GLINT]end
	if tier>=Shade.CrescentFrom and simple<1 and lx>.12 and ly>.12 then
		local r=math.min(rx,ry)
		local inner=(r-1)/r
		if q>inner*inner then return t[RIM]end
	end
	local motifAt=t.motifAt
	if motifAt and t[KIND]>1 and motifAt(t[KIND],lx,ly)then return t[MOTIF]end
	if ly<Shade.TopBand then return t[LIGHTMID]end
	if ly>Shade.BottomBand then return t[DEEP]end
	return t[BODY]
end
-- The merge's impact frame: the result drawn solid `light`, the glint kept.
function Shade.flash(t,lx,ly,q)
	local g=Shade.Glint[t.tier or 1]
	local ix,iy=cell(lx,ly)
	if ix>=g[1]and ix<g[1]+g[3]and iy>=g[2]and iy<g[2]+g[4]then return t[GLINT]end
	return t[3]
end
return Shade
