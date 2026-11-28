-- The v2 music (artifacts/qa-2026-11-28-music/MUSIC-BRIEF.md sections 3, 4 and 6; RACE-AND-MUSIC-LOOK 3.3 stays the
-- runtime spec). Behind Alive "music2" (AliveMusic2, beta and Studio, ConfigService `alive_music2`, owner chat
-- /alive music2 on|off|clear). Off, or while a pair's ids below are 0, the music is today's exactly.
--
-- The ids and the pure rules: which voices are in use, the night weight from the garden hour, the equal-power gains,
-- the deck <-> lite slew, and the sample sync (who leads, where the follower belongs, when it has drifted). The
-- voices live in BoardAudio (the garden pair, in the world music's own group) and AmbientAudio (the deck pair, in the
-- deck music's group), so the master, every duck, the music toggle and focus reach both voices of a pair.
local Tracks={}
Tracks.Feature="music2"

-- Upload ids (assets/audio/music/*-v2.ogg, MUSIC-BRIEF 6). 0 = not uploaded: that pair stays today's track.
--   garden_day    garden-day-v4         131.28 s (5,789,538 frames)
--   garden_night  garden-night-v4       the same frame count, so the pair can cross at any moment
--   deck          pocket-deck-v2        65.64 s (2,894,769 frames)
--   deck_lite     pocket-deck-lite-v2   32.82 s (16 bars: half the deck, so it follows the deck's grid modulo)
Tracks.Ids={garden_day=125877989254797,garden_night=88487379039156,deck=0,deck_lite=0}

-- The lengths the brief renders (s); the runtime reads each Sound's own TimeLength.
Tracks.Lengths=table.freeze({garden=5789538/44100,deck=2894769/44100,deck_lite=16*60/117*4})
-- Brief 3: if the render's midpoint (.707 day + .707 night) is over 1 LU above day, ship 1.5 on both curves
-- (report.json, mid-fade loudness). 1 = plain equal power.
Tracks.Exponent=1.5 -- build_music.py measured +1.04 LU at the midpoint with 1; 1.5 gives -0.46 LU (report.json)
-- The night file is mastered 3 LU under day (-20.6 LUFS against -17.6), so it plays at the same MusicVolume.
Tracks.NightLevel=1
-- The deck lite file is mastered 3 LU under the deck: the same DeckMusicVolume.
Tracks.LiteLevel=1
-- Re-align a follower that has drifted over Drift seconds (brief 3: 40 ms), checked every CheckEvery seconds and at
-- once after a start or a resume.
Tracks.Drift=.04
Tracks.CheckEvery=1
-- Two clips are one grid when their lengths agree (or one is a whole multiple of the other) within Slack seconds.
-- Otherwise they still cross, but are never re-aligned (a seek every loop would be worse than a drift).
Tracks.Slack=.05
-- The deck <-> lite crossfade, seconds end to end (equal power, both voices running in step).
Tracks.DeckFade=.8
-- How often the night weight is read from the hour (s): it moves over 90-120 s, so 10 Hz is smooth.
Tracks.WeightEvery=.1

local function finite(value)return type(value)=="number"and value==value and math.abs(value)<math.huge end
local function clamp01(value)return if finite(value)then math.clamp(value,0,1)else 0 end
local function uploaded(id)return finite(id)and id>0 and id==math.floor(id)end
Tracks.uploaded=uploaded

-- Which pairs play the v2 tracks: the switch on and the ids in. {garden, deck, lite} booleans.
function Tracks.active(on,ids)
	ids=ids or Tracks.Ids
	local deck=on==true and uploaded(ids.deck)
	return{garden=on==true and uploaded(ids.garden_day)and uploaded(ids.garden_night),deck=deck,lite=deck and uploaded(ids.deck_lite)}
end

-- The night weight w from a GardenHour.phase() table: the Hour's own smoothstepped blend, so the music turns with the
-- sky. 0 by day, 0 -> 1 over the 120 s that open night (2880-3000 s), 1 through night, 1 -> 0 over dawn's 90 s.
function Tracks.nightWeight(at)
	if type(at)~="table"then return 0 end
	if at.phase=="night"then return clamp01(at.k or 1)end
	if at.phase=="dawn"and at.from=="night"then return 1-clamp01(at.k or 1)end
	return 0
end

-- Equal power: day = cos(w pi/2), night = sin(w pi/2), each raised to `exponent` (Tracks.Exponent). Exact at the ends.
function Tracks.gains(w,exponent)
	w=clamp01(w)
	local p=if finite(exponent)and exponent>0 then exponent else 1
	if w<=0 then return 1,0 end
	if w>=1 then return 0,1 end
	return math.cos(w*math.pi/2)^p,math.sin(w*math.pi/2)^p
end

-- One step of a 0..1 weight toward `goal`, end to end in `seconds`.
function Tracks.slew(value,goal,dt,seconds)
	value,goal=clamp01(value),clamp01(goal)
	local most=if finite(seconds)and seconds>0 then math.max(dt or 0,0)/seconds else 1
	return value+math.clamp(goal-value,-most,most)
end

-- The deck's lite variant: the results card, a finished round, or a menu over the deck. Only inside the deck.
function Tracks.deckLite(scene)
	if type(scene)~="table"or scene.open~=true then return false end
	return scene.results==true or scene.over==true or scene.menu==true
end

-- Wrapped signed distance from `at` to `target` in a clip `length` long: (-length/2, length/2].
function Tracks.drift(at,target,length)
	if not(finite(at)and finite(target)and finite(length))or length<=0 then return 0 end
	local d=(target-at)%length
	if d>length/2 then d-=length end
	return d
end

-- Whole multiple k of the shorter clip in the longer, or nil when the two are not one grid.
function Tracks.ratio(a,b)
	if not(finite(a)and finite(b))or a<=0 or b<=0 then return nil end
	local long,short=math.max(a,b),math.min(a,b)
	local k=math.floor(long/short+.5)
	if k<1 or math.abs(long-k*short)>Tracks.Slack then return nil end
	return k
end

-- Where the follower belongs: the leader `lead` seconds into its clip (leadLength long), the follower now at `at` in a
-- clip `length` long. Same length: the same second. Shorter: the leader's second modulo its length. Longer: whichever of
-- the leader's k cycles inside it is nearest where the follower is. nil when the clips are not one grid.
function Tracks.target(lead,leadLength,at,length)
	local k=Tracks.ratio(leadLength,length)
	if not k or not(finite(lead)and finite(at))then return nil end
	lead%=leadLength
	if length<=leadLength+Tracks.Slack then return lead%length end
	local best,gap=nil,math.huge
	for cycle=0,k-1 do
		local spot=(cycle*leadLength+lead)%length
		local away=math.abs(Tracks.drift(at,spot,length))
		if away<gap then best,gap=spot,away end
	end
	return best
end

-- The sync decision for a pair. The louder voice leads (a on a tie), so the one heard never jumps; the follower moves
-- only past `limit` (Tracks.Drift). Answers "a" or "b" and the second to seek it to, or nil.
function Tracks.align(posA,posB,gainA,gainB,lengthA,lengthB,limit)
	limit=if finite(limit)then limit else Tracks.Drift
	local leadA=(tonumber(gainA)or 0)>=(tonumber(gainB)or 0)
	local lead,leadLength,at,length=posA,lengthA,posB,lengthB
	if not leadA then lead,leadLength,at,length=posB,lengthB,posA,lengthA end
	local target=Tracks.target(lead,leadLength,at,length)
	if not target or math.abs(Tracks.drift(at,target,length))<=limit then return nil end
	return if leadA then "b"else "a",target
end

-- A Sound's clip length once it holds audio, else nil.
function Tracks.length(voice)
	local seconds=if voice.IsLoaded==true then tonumber(voice.TimeLength)or 0 else 0
	return if seconds>0 then seconds else nil
end
-- The runtime half: two playing voices kept in step. lengthOf (specs) reads a clip's length. Answers the voice moved.
function Tracks.sync(a,b,gainA,gainB,limit,lengthOf)
	if not(a.IsPlaying and b.IsPlaying)then return nil end
	lengthOf=lengthOf or Tracks.length
	local lengthA,lengthB=lengthOf(a),lengthOf(b)
	if not lengthA or not lengthB then return nil end
	local move,to=Tracks.align(a.TimePosition,b.TimePosition,gainA,gainB,lengthA,lengthB,limit)
	if move=="a"then a.TimePosition=to;return a end
	if move=="b"then b.TimePosition=to;return b end
	return nil
end

return Tracks
