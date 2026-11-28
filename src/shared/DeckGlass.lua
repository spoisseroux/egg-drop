-- Deck Aero glass (Fable, artifacts/qa-2026-11-28-beta44/DECK-AERO-BRIEF.md; Spencer, beta 44: "make the ui on the pocket
-- deck game screen and first pocket onboarding deck game screen look less vibe codey, more frutiger aero, with reassigned
-- colors for everything depending on the faceplate"). Pure and shared: the palette every glass surface reads (section 3),
-- the recipe's numbers (section 2), the pill states, the contrast floors and the motion gates (section 5). The client half
-- (DeckGlassUI) builds the frames; nothing here touches an Instance.
--
-- Every role comes from the plate's `toyShell` row (its roles are already solved to one luminance on every deck, so the
-- contrast is the same everywhere). A plate without a row (Bookworm, Stargazer) solves one from its `deep` and `accent`
-- (DeckGlass.solveShell): `deep` mixed toward white or black until it reaches the row's luminance. The rows are not
-- written into DeckThemes, so the menus of those two plates (theme.toy, Classic Shell) stay as they are while the switch
-- is off.
--
-- Behind Alive "deckglass" (AliveDeckGlass, beta and Studio, ConfigService `alive_deckglass`, owner chat
-- /alive deckglass on|off|clear). It dresses the deck feel pass's HUD, so it needs "deckfeel" too (DeckGlass.switch).
-- Off is the deck exactly as before.
local Shared=script.Parent
local Alive=require(Shared.Alive)
local Themes=require(Shared.DeckThemes)

local Glass={}
Glass.Feature="deckglass"

-- ── The switch ──────────────────────────────────────────────────────────────────────────────────────────────────
-- Specs set an override (true / false / nil = the real switches).
local override=nil
function Glass.setSwitch(value)override=value end
function Glass.switch()
 if override~=nil then return override==true end
 local ok,on=pcall(function()return Alive.on(Glass.Feature)and Alive.on("deckfeel")end)
 return ok and on==true
end

-- ── Colour maths (0..255 channels, rounded to whole steps after every derivation, as the brief's table) ─────────
local function rgb(hex)
 hex=string.gsub(hex,"#","")
 return {tonumber(string.sub(hex,1,2),16),tonumber(string.sub(hex,3,4),16),tonumber(string.sub(hex,5,6),16)}
end
local function round(v)return math.clamp(math.floor(v+.5),0,255)end
local function mix(a,b,t)return {round(a[1]+(b[1]-a[1])*t),round(a[2]+(b[2]-a[2])*t),round(a[3]+(b[3]-a[3])*t)}end
local function hex(c)return string.format("#%02X%02X%02X",c[1],c[2],c[3])end
local function luminance(c)
 local function ch(v)v/=255;return if v<=.03928 then v/12.92 else((v+.055)/1.055)^2.4 end
 return .2126*ch(c[1])+.7152*ch(c[2])+.0722*ch(c[3])
end
local function contrast(a,b)
 local la,lb=luminance(a),luminance(b)
 return(math.max(la,lb)+.05)/(math.min(la,lb)+.05)
end
Glass.rgb,Glass.hex,Glass.mix,Glass.luminance,Glass.contrast=rgb,hex,mix,luminance,contrast
local WHITE,BLACK={255,255,255},{0,0,0}
-- `c` mixed toward white (or black, when it is already lighter) until its luminance reaches `target`.
function Glass.toward(c,target)
 local up=luminance(c)<target
 local goal=if up then WHITE else BLACK
 local lo,hi=0,1
 for _=1,30 do
  local m=(lo+hi)/2
  local v=luminance({c[1]+(goal[1]-c[1])*m,c[2]+(goal[2]-c[2])*m,c[3]+(goal[3]-c[3])*m})
  if(v<target)==up then lo=m else hi=m end
 end
 return mix(c,goal,hi)
end

-- ── Section 3: the palette ──────────────────────────────────────────────────────────────────────────────────────
Glass.Mix=table.freeze({bottom=.55,rim=.45,wellTop=.12,hi=.35})
-- The luminances a missing row is solved to (shell, lip, ink and well, hi, the soft text).
Glass.Solve=table.freeze({shell=.131,lip=.045,ink=.011,hi=.37,soft=.80})
-- State never changes with the skin.
Glass.StateHex=table.freeze({good="#43DB5F",warn="#FFC14D",bad="#FF5A4D"})
Glass.GoldHex="#FFC14D"
-- The brief's rule for a plate with no `toyShell` row: a row of hex strings (shell, shellHi, shellLip, ink, well,
-- onShellSoft, tag).
function Glass.solveShell(deepHex,accentHex)
 local deep,accent=rgb(deepHex),rgb(accentHex)
 local S=Glass.Solve
 local ink=Glass.toward(deep,S.ink)
 return table.freeze({shell=hex(Glass.toward(deep,S.shell)),shellLip=hex(Glass.toward(deep,S.lip)),ink=hex(ink),well=hex(ink),
  shellHi=hex(Glass.toward(mix(deep,accent,Glass.Mix.hi),S.hi)),onShellSoft=hex(Glass.toward(accent,S.soft)),tag=accentHex})
end
-- Pure: the roles as hex strings for a plate row (DeckThemes.Plates[id]).
function Glass.paletteHex(plate)
 local row=plate.toyShell or Glass.solveShell(plate.deep,plate.accent)
 local M=Glass.Mix
 local shell,lip,hi,well,accent=rgb(row.shell),rgb(row.shellLip),rgb(row.shellHi),rgb(row.well),rgb(plate.accent)
 return table.freeze({glassTop=hex(shell),glassBottom=hex(mix(shell,lip,M.bottom)),rim=hex(mix(hi,WHITE,M.rim)),accent=plate.accent,
  pill=row.tag,ink=row.ink,text="#FFFFFF",soft=row.onShellSoft,well=hex(well),wellTop=hex(mix(well,accent,M.wellTop)),
  good=Glass.StateHex.good,warn=Glass.StateHex.warn,bad=Glass.StateHex.bad,gold=Glass.GoldHex,solved=plate.toyShell==nil})
end

-- ── Derived surfaces (sections 2 and 4) ─────────────────────────────────────────────────────────────────────────
Glass.Surface=table.freeze({
 pillLight=.55,   -- a pill's top: its colour mixed 55% to white
 track=.60,       -- a track: glassBottom mixed 60% to ink
 fillLight=.35,   -- a fill's top: accent (or the state) mixed 35% to white
 gloss=.10,       -- the gloss at its strongest: 10% white over the body (rule 1)
 sky=.25,         -- WelcomeDeck2's sky card top: glassTop mixed 25% to accent
 eggTop=.35,      -- the egg card: white mixed 35% to accent ...
 eggBottom=.35,   -- ... over accent mixed 35% to glassTop
})
-- Pure: every derived surface as hex, from paletteHex's roles.
function Glass.surfacesHex(p)
 local S=Glass.Surface
 local top,bottom,ink,accent=rgb(p.glassTop),rgb(p.glassBottom),rgb(p.ink),rgb(p.accent)
 local out={track=hex(mix(bottom,ink,S.track)),fillTop=hex(mix(accent,WHITE,S.fillLight)),pillTop=hex(mix(rgb(p.pill),WHITE,S.pillLight)),
  gloss=hex(mix(top,WHITE,S.gloss)),skyTop=hex(mix(top,accent,S.sky)),eggTop=hex(mix(WHITE,accent,S.eggTop)),eggBottom=hex(mix(accent,top,S.eggBottom))}
 for _,state in ipairs({"good","warn","bad"})do
  local c=rgb(p[state])
  out[state.."Top"]=hex(mix(c,WHITE,S.pillLight))
  out[state.."FillTop"]=hex(mix(c,WHITE,S.fillLight))
 end
 return table.freeze(out)
end

-- The Color3 palette for a DeckThemes theme (the equipped plate), cached per theme. `hex` and `surface` keep the
-- strings; every other key is a Color3.
local cache=setmetatable({},{__mode="k"})
local function plateOf(theme)
 local id=type(theme)=="table"and theme.id or theme
 return Themes.Plates[id]or Themes.Plates[Themes.Default],id
end
function Glass.palette(theme)
 theme=theme or Themes.ById[Themes.Default]
 local hit=cache[theme]
 if hit then return hit end
 local plate=plateOf(theme)
 local p=Glass.paletteHex(plate)
 local s=Glass.surfacesHex(p)
 local out={hex=p,surface=s}
 for key,value in pairs(p)do if type(value)=="string"then out[key]=Color3.fromHex(value)end end
 for key,value in pairs(s)do out[key]=Color3.fromHex(value)end
 out=table.freeze(out)
 if type(theme)=="table"then cache[theme]=out end
 return out
end

-- ── Contrast floors (section 3, rules 1-5) ──────────────────────────────────────────────────────────────────────
-- 4.5 for text, 3.0 for large text (18 px bold and up, or 14 px bold for `soft`) and for fills on their track.
Glass.Floors=table.freeze({text=4.5,large=3,fill=3})
-- Pure: the contrasts the rules lean on, for paletteHex's roles. Each entry {ratio, floor}.
function Glass.contrasts(p)
 local s=Glass.surfacesHex(p)
 local F=Glass.Floors
 local top,gloss,track=rgb(p.glassTop),rgb(s.gloss),rgb(s.track)
 return {
  whiteOnBody={contrast(WHITE,top),F.text},           -- white copy on the card body (its lighter top is the worst)
  whiteUnderGloss={contrast(WHITE,gloss),F.text},     -- rule 1: the gloss never takes white text under 4.5
  softOnBody={contrast(rgb(p.soft),top),F.text},      -- rule 2: soft below the gloss line
  softUnderGloss={contrast(rgb(p.soft),gloss),F.large},-- rule 2: under the gloss only at 14 px bold and up
  inkOnPill={contrast(rgb(p.ink),rgb(p.pill)),F.text},
  inkOnPillTop={contrast(rgb(p.ink),rgb(s.pillTop)),F.text},
  inkOnAccent={contrast(rgb(p.ink),rgb(p.accent)),F.text},
  inkOnGood={contrast(rgb(p.ink),rgb(p.good)),F.text},
  inkOnWarn={contrast(rgb(p.ink),rgb(p.warn)),F.text},
  inkOnBad={contrast(rgb(p.ink),rgb(p.bad)),F.text},
  accentOnTrack={contrast(rgb(p.accent),track),F.fill},-- rule 4: fills always on a track
  goodOnTrack={contrast(rgb(p.good),track),F.fill},
  warnOnTrack={contrast(rgb(p.warn),track),F.fill},
  badOnTrack={contrast(rgb(p.bad),track),F.fill},
  goldOnBody={contrast(rgb(p.gold),top),F.large},     -- rule 3: gold text at 18 px bold and up
  whiteOnSky={contrast(WHITE,rgb(s.skyTop)),F.large}, -- WelcomeDeck2's 26 px line on the sky card's top
  inkOnEgg={contrast(rgb(p.ink),rgb(s.eggTop)),F.text},
 }
end
-- Pure: the names that fall under their floor (empty = readable).
function Glass.failing(p)
 local out={}
 for name,pair in pairs(Glass.contrasts(p))do if pair[1]<pair[2]then table.insert(out,name)end end
 table.sort(out)
 return out
end
-- Rule 3: gold and the state colours as text only at 18 px and up (bold); smaller, a pill carries the state.
Glass.GoldTextMin=18
function Glass.goldText(size)return(tonumber(size)or 0)>=Glass.GoldTextMin end

-- ── Section 2: the recipe's numbers ─────────────────────────────────────────────────────────────────────────────
Glass.Card=table.freeze({
 radius=16,compact=12,welcome=12,
 rim=1.5,rimAlpha=table.freeze({.15,.70}),            -- UIStroke 1.5, white with a 90-degree gradient in `rim`
 shadow=table.freeze({offset=3,alpha=.70,minGap=8}),   -- a sibling under the card; none when the next card is closer
 gloss=table.freeze({inset=2,height=.46,top=.90,bottom=.96}),
 bounce=table.freeze({height=.35,top=1,bottom=.84}),
 streak=table.freeze({rotation=25,keys=table.freeze({{0,1},{.30,1},{.33,.93},{.36,1},{.39,.96},{.42,1},{1,1}})}),
})
function Glass.cardRadius(compact)return if compact then Glass.Card.compact else Glass.Card.radius end
-- Pure: the shadow under a card whose next card down (same column) starts `gap` px under it (nil: none below).
function Glass.shadowWanted(gap)return gap==nil or gap>=Glass.Card.shadow.minGap end
-- Pure: the gap from `card` {x, y, w, h} to the nearest card below it that overlaps it sideways (nil: none).
function Glass.gapBelow(card,others)
 local best=nil
 for _,o in ipairs(others)do
  if o~=card and o.x<card.x+card.w and card.x<o.x+o.w and o.y>=card.y+card.h then
   local gap=o.y-(card.y+card.h)
   if best==nil or gap<best then best=gap end
  end
 end
 return best
end
Glass.Pill=table.freeze({height=22,compact=20,pad=10,padCompact=8,size=12,stroke=.45})
function Glass.pillHeight(compact)return if compact then Glass.Pill.compact else Glass.Pill.height end
-- Tracks keep the rects their screens give them (the brief's 8 / 6 px height waits on the geometry lane: the Goals
-- rows own their 6 px bars); `dot` is the lit chain dot's white highlight.
Glass.Track=table.freeze({dot=2})
Glass.Well=table.freeze({rim=1.5,rimAlpha=.55})
Glass.Check=table.freeze({ring=.45}) -- the open ring: white at 55%; done: a `good` disc with the ink check

-- ── Pill states (section 2) ─────────────────────────────────────────────────────────────────────────────────────
-- One pill colour per plate; a pill changes colour only for state. `s`: done (every goal complete), status (the Goals
-- card shows a status line), live (the chain is live), low (balls left <= 3). Returns nil (the plate's pill) or a state.
Glass.LowBalls=3
function Glass.pillState(s)
 if type(s)~="table"then return nil end
 if s.done then return "good"end
 if s.low then return "bad"end
 if s.live or s.status then return "warn"end
 return nil
end
function Glass.ballsLow(left)return type(left)=="number"and left<=Glass.LowBalls end
function Glass.allDone(goals)
 if type(goals)~="table"or #goals==0 then return false end
 for _,goal in ipairs(goals)do if not goal.done then return false end end
 return true
end

-- ── Section 5: motion ───────────────────────────────────────────────────────────────────────────────────────────
Glass.Motion=table.freeze({
 sweep=.35,sweepGap=1.2,                              -- the Streak's Offset -1 -> 1 in .35 s, once a card per 1.2 s at most
 bubbles=table.freeze({table.freeze({size=8,period=7,x=.24}),table.freeze({size=12,period=9,x=.7})}),
 bubbleAlpha=.90,bubbleRim=.7,                        -- white 10%, rim .7
 bubbleCards=table.freeze({Goals=true,Next=true}),
})
-- Pure: what moves. reduced (Reduced Motion or Motion: Low), budget (AliveBudget level), compact (a phone or the small
-- deck). The static glass never changes.
function Glass.motion(reduced,budget,compact)
 local calm=reduced==true or(tonumber(budget)or 0)>=1
 return {sweep=not calm,bubbles=not calm and compact~=true}
end
-- Pure: may a card sweep now, last swept at `last` (nil: never)?
function Glass.sweepDue(last,now)return last==nil or now-last>=Glass.Motion.sweepGap end

return Glass
