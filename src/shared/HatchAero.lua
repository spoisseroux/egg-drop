-- Aero hatch screens (artifacts/qa-2026-11-26-beta36/AERO-JUICE-BRIEF.md section 3; Spencer: "i think the bear hatch
-- screen and other hatch screens need better frutiger aero colors"). Shared and pure: the Sky / Meadow / Aurora colour
-- system that replaces the orange sunburst and the warm lights on every hatch and reveal card (HatchItemStage's well, so
-- the Toy, Look, Material, Feature, Stat, Names and medal cards; RevealStage's pet card, so the Bear's "Meet Bear" card,
-- the Bunny's arrival and the Hatch eggs pet reveal), the egg-type accents (bubble rims and confetti only), the rising
-- bubbles, the Rare ray sweep, the dew glints and sparkles, and the grass horizon.
-- The switch is the Alive feature `aerohatch` (FeatureFlags.AliveAeroHatch; beta place and Studio only; a missing config
-- is on). Owner chat `/alive aerohatch off` puts the old look back from the next card, for comparing. Off is exactly
-- the old look: HatchRarityCue.Stage / Look are untouched and still drawn.
-- Fable's warning: Spencer rejected a "sad blue-ish" teal on v850. Every colour here is saturated midday sky, leaf and
-- aurora, never grey-teal (HatchAero.spec checks saturation and value, rarity distance and text contrast).
local Alive=require(script.Parent.Alive)
local A={}
A.Feature="aerohatch"
-- The live switch: the build ceiling (beta or Studio) and the server's attribute. Never throws.
function A.on()
 local ok,on=pcall(Alive.on,A.Feature)
 return ok and on==true
end
function A.changed()return Alive.changed(A.Feature)end

-- ── Palettes (brief 3 table) ───────────────────────────────────────────────────
-- core / edge: the well's radial fill; ray: the light shafts; floor: the light pool; deep: the edge vignette;
-- back -> backDeep: the lit backdrop top to bottom (Look.back / backDeep). look / lookSecond: the tier rim and sticker
-- (Common is white glass now; Uncommon and Rare keep their green and violet). shadow: the soft contact shadow (on grass,
-- a deep leaf; on Rare's glass floor, its own deep). art: the atlas pattern piece (the bubble field is the dots).
-- spin: ray turn (deg/s); sweep: Rare's aqua-to-pink ray tint (seconds one way); bubbles / glints / sparkles: counts.
local function palette(name,hex,more)
 local p={name=name,hex=table.freeze(hex)}
 for key,value in pairs(hex)do p[key]=Color3.fromHex(value)end
 for key,value in pairs(more)do p[key]=value end
 return table.freeze(p)
end
local Sky=palette("Sky",{core="#C9F1FF",edge="#2FA8F0",ray="#FFFFFF",floor="#F4FFFF",deep="#0E5FB8",back="#D9F4FF",backDeep="#58B8F2",
 look="#FFFFFF",lookSecond="#C9F1FF",shadow="#17803A",sweepFrom="#FFFFFF"},
 {pattern="bubbles",art="dots",patternAlpha=.06,spin=0,sweep=0,bubbles=6,glints=0,sparkles=0,horizon="grass"})
local Meadow=palette("Meadow",{core="#E4FF9E",edge="#2DBE4E",ray="#F6FFC8",floor="#FBFFDC",deep="#0B7A3A",back="#DFFFB0",backDeep="#2DBE4E",
 look="#57E08A",lookSecond="#C8FFD9",shadow="#17803A",sweepFrom="#F6FFC8"},
 {pattern="bubbles",art="dots",patternAlpha=.06,spin=18,sweep=0,bubbles=10,glints=5,sparkles=0,horizon="grass"})
local Aurora=palette("Aurora",{core="#C4F6FF",edge="#7D5CF0",ray="#FF9AE0",floor="#FFEAF9",deep="#2E1C9A",back="#D9CCFF",backDeep="#5340D8",
 look="#8E7CFF",lookSecond="#5CC8FF",shadow="#2E1C9A",sweepFrom="#6FE3FF"},
 {pattern="diamonds",art="diamonds",patternAlpha=.20,spin=12,sweep=4,bubbles=16,glints=0,sparkles=12,horizon="glass"})
A.Palettes=table.freeze({Common=Sky,Neutral=Sky,Uncommon=Meadow,Rare=Aurora})
A.Tiers=table.freeze({"Common","Uncommon","Rare"})
function A.palette(tier)return A.Palettes[tier or ""]or Sky end

-- Rays: soft white shafts from the top centre (sun through water), never a burst behind the pet. Two layers of the
-- atlas' twelve shafts, half a step apart; each 14% alpha (the brief's 10 to 18%). The image's centre sits a little above
-- the well (originY x the well's height) and it spans `span` x the height, so the shafts fill the middle and fade out
-- near the floor. One warm lens glint at the source keeps it sunny.
-- Fable B37 (studio-b37 capture 7): "rays to 14% alpha; they barely show". Each layer is 14%, and the source moves up
-- (originY -.25) so the shafts' bright band (40 to 70% of the image's radius) lands on the card, not its floor.
A.Rays=table.freeze({layers=2,step=15,alpha=.14,span=2.6,originY=-.25})
-- Fable B37: the screen round the card (the deck's navy checker before) is a vertical sky gradient with no checker and
-- six big, faint bubbles (12% alpha, white rims, twice the card bubbles' size), for every card that uses this backdrop.
A.Backdrop=table.freeze({top=Color3.fromHex("#58B8F2"),bottom=Color3.fromHex("#0E5FB8"),hexTop="#58B8F2",hexBottom="#0E5FB8",
 bubbles=6,alpha=.12,fill=.04,scale=2,rim=2})
-- Fable B37: the Bear read warm grey on the card. The pet's viewport light on an Aero card: a white key and a cool
-- #CFEFFF fill at half strength (the viewport's Ambient), so a white belly reads about #F4F8FF. Tune here in Studio.
local fill=Color3.fromHex("#CFEFFF")
A.PetLight=table.freeze({key=Color3.new(1,1,1),fill=fill,fillHex="#CFEFFF",strength=.5,
 ambient=Color3.new(fill.R*.5,fill.G*.5,fill.B*.5),belly="#F4F8FF"})
A.Glint=table.freeze({color=Color3.fromHex("#FFE58A"),hex="#FFE58A",size=24,alpha=.30,y=.05})
-- The glossy grass horizon (Common and Uncommon) and Rare's glass floor: the top of a circle 3 x the well's width, its
-- crest just above the floor the egg or pet stands on, a 1 px white highlight along it.
A.Grass=table.freeze({top=Color3.fromHex("#7BE04A"),bottom=Color3.fromHex("#2DBE4E"),hexTop="#7BE04A",hexBottom="#2DBE4E",
 highlight=.25,glassTop=.45,glassBottom=.80,glassHighlight=.10,diameter=3})
-- Bubbles: 8 to 28 px, about 35% alpha (a 12% white body, its 1 px rim in the egg type's accent at 45%, a 2 px white
-- spec at 85%), rising 20 px/s with a 6 px sway; they pop (0.15 s) at the burst and come back from the floor over the
-- next `respawn` seconds.
A.Bubble=table.freeze({min=8,max=28,alpha=.35,speed=20,sway=6,rim=1,spec=2,pop=.15,respawn=2.5,fill=.12,rimAlpha=.45,specAlpha=.85})
-- The name plate: white glass at 85% with ink. Gold is for Stars only, so no hatch screen paints with it.
A.Plate=table.freeze({glass=Color3.new(1,1,1),transparency=.15,ink=Color3.fromHex("#0E0F12"),inkHex="#0E0F12"})
A.Gold=Color3.fromHex("#FFC14D")

-- Egg-type accents (bubble rims and confetti only). Look Eggs (jars, finishes, charms) are a rainbow; an unknown kind is
-- nil, so the caller keeps its own accent (a medal's stat colour) or white.
A.AccentHex=table.freeze({companion="#FFE58A",stat="#FF9A5C",toy="#FF6FA8",material="#B9C6FF",feature="#7CF08A",name="#FFFFFF"})
A.RainbowKinds=table.freeze({hue=true,look=true,finish=true,charm=true})
A.RainbowHex=table.freeze({"#FF5A7A","#FFB13B","#FFE14D","#5CE27A","#4FC3FF","#8E7CFF"})
local accents={};for kind,value in pairs(A.AccentHex)do accents[kind]=Color3.fromHex(value)end
local rainbow={};for i,value in ipairs(A.RainbowHex)do rainbow[i]=Color3.fromHex(value)end
function A.accent(kind,index)
 if A.RainbowKinds[kind or ""]then return rainbow[((index or 1)-1)%#rainbow+1]end
 return accents[kind or ""]
end
-- Pure: confetti piece `index`'s colour on a pet card (the popper): the accent, white, the tier's edge and core.
function A.confetti(kind,tier,index)
 local p=A.palette(tier)
 local pick=(index-1)%4
 if pick==0 then return A.accent(kind,index)or Color3.new(1,1,1)end
 if pick==1 then return Color3.new(1,1,1)end
 if pick==2 then return p.edge end
 return A.accent(kind,index+1)or p.core
end

-- ── Colour maths (the specs and the painters) ──────────────────────────────────
-- (Per channel, not Color3:Lerp, so the offline mocks give the real answer.)
function A.mix(a,b,t)
 t=math.clamp(t,0,1)
 return Color3.new(a.R+(b.R-a.R)*t,a.G+(b.G-a.G)*t,a.B+(b.B-a.B)*t)
end
-- `top` at `alpha` (0..1) over `bottom`, in sRGB as Roblox blends.
function A.over(top,alpha,bottom)return A.mix(bottom,top,alpha)end
function A.luminance(c)
 local function lin(x)return if x<=.03928 then x/12.92 else((x+.055)/1.055)^2.4 end
 return .2126*lin(c.R)+.7152*lin(c.G)+.0722*lin(c.B)
end
function A.contrast(a,b)
 local la,lb=A.luminance(a),A.luminance(b)
 return(math.max(la,lb)+.05)/(math.min(la,lb)+.05)
end
-- HSV, for the "never sad teal" check (hue in degrees).
function A.hsv(c)
 local r,g,b=c.R,c.G,c.B
 local max,min=math.max(r,g,b),math.min(r,g,b)
 local d=max-min
 local h=0
 if d>0 then
  if max==r then h=60*(((g-b)/d)%6)elseif max==g then h=60*((b-r)/d+2)else h=60*((r-g)/d+4)end
 end
 return h,(if max>0 then d/max else 0),max
end

-- ── Motion (pure: one clock in, positions out) ─────────────────────────────────
local function hash(i,salt)local x=math.sin(i*12.9898+salt*78.233)*43758.5453;return x-math.floor(x)end
A.hash=hash
-- Bubble `i` of `n` in a well `w` x `h` px at `clock` (the stage's own seconds). `burstAge`: seconds since the burst
-- (nil: no burst on this card, so none pops, e.g. a reopen). Returns x, y (the centre, px from the well's top left),
-- size (px), alpha (0..1 of the bubble's own opacity) and pop (0..1 while it pops); nil while it is gone.
-- Reduced Motion: still bubbles where they stand, none pops.
function A.bubble(i,n,clock,burstAge,w,h,scale,reduced)
 if i<1 or i>n then return nil end
 local B=A.Bubble;scale=scale or 1
 local size=(B.min+(B.max-B.min)*hash(i,1))*scale
 local column=((i*7)%n+hash(i,4))/n
 local x=w*(.06+.88*column)
 if reduced then
  local y=size/2+(h-size)*(.12+.76*hash(i,3))
  return x,y,size,1,0
 end
 local span=h+size
 local speed=B.speed*scale*(.8+.4*hash(i,2))
 local sway=B.sway*scale*math.sin((clock or 0)*1.7+i*2.1)
 local rise,pop=0,0
 if burstAge==nil or burstAge<0 then
  rise=(clock or 0)*speed+hash(i,3)*span
 elseif burstAge<B.pop then
  -- It pops where it was at the burst.
  rise=((clock or 0)-burstAge)*speed+hash(i,3)*span;pop=burstAge/B.pop
 else
  local after=burstAge-B.pop-B.respawn*hash(i,5)
  if after<0 then return nil end
  rise=after*speed
 end
 local y=h+size/2-(rise%span)
 return x+sway,y,size*(1+.6*pop),1-pop,pop
end
-- Rare: the rays' tint sweeps aqua to pink in `sweep` seconds and back. Others (and Reduced Motion) keep `ray`.
function A.raySweep(tier,clock,reduced)
 local p=A.palette(tier)
 if reduced or p.sweep<=0 then return p.ray end
 local u=.5-.5*math.cos((clock or 0)*math.pi/p.sweep)
 return A.mix(p.sweepFrom,p.ray,u)
end
-- A twinkle level (0..1) for sparkle or glint `i`; Reduced Motion holds a steady .7.
function A.twinkle(i,clock,reduced)
 if reduced then return .7 end
 return .5+.5*math.sin((clock or 0)*(2.2+hash(i,7))+i*1.7)
end
-- Where sparkle / glint `i` of `n` sits, as shares of the well: Rare's sparkles in the upper two thirds, Uncommon's dew
-- glints on the grass just under the crest.
function A.spot(kind,i,n,crest)
 if kind=="glint"then
  return .12+.76*((i-1+hash(i,23))/math.max(1,n)),(crest or .76)+.025+.06*hash(i,24)
 end
 return .08+.84*hash(i,21),.08+.55*hash(i,22)
end
-- The horizon for a well `w` x `h` whose floor sits at `floorShare` of its height: the crest (share and px), the
-- circle's diameter, the dip at the well's side edges (px) and the share of the circle's height that shows (the grass
-- gradient ends there).
function A.horizon(floorShare,w,h)
 local crest=math.clamp((floorShare or .78)-.025,.62,.84)
 local d=A.Grass.diameter*math.max(1,w)
 local r=d/2;local x=math.max(1,w)/2
 local dip=r-math.sqrt(r*r-x*x)
 return{crest=crest,y=crest*h,diameter=d,dip=dip,shows=math.clamp((h-crest*h)/d,.01,1)}
end
return table.freeze(A)
