-- The new-tip chime (beta 12 QA S2, DASH-DECK-UI-LOOK): two soft mallet notes going up when a Things to do tip lands on
-- the notice rail, and nothing else. No sound until Spencer picks one: SoundId is nil, so BoardAudio makes no voice and
-- play() is a quiet no-op. Candidates (DASH-DECK-UI-BUILD-PLAN, S2): a wooden xylophone pair G5 then C6; a kalimba pair
-- E5 then B5; a felt-beater glockenspiel pair low-passed under 3 kHz. Record the licence beside the file when it lands.
-- Never more than once in Gap seconds; silent during a deck round, a race or a hatch, and when the sound setting is
-- off (the UI group's volume). Reduced Motion does not change it.
local Chime={}
Chime.SoundId=nil -- rbxassetid number, once Spencer has picked a candidate
Chime.Cue="tip_chime"
Chime.Volume=.25  -- under the Stars pickup
Chime.Gap=20
Chime.Pitch=.03   -- +/- 3% between plays

-- Pure: may it ring now? last = when it last rang (nil = never); busy = {round, race, hatch}.
function Chime.allowed(now,last,busy)
	busy=busy or {}
	if busy.round or busy.race or busy.hatch then return false end
	return last==nil or now-last>=Chime.Gap
end
-- Pure: the playback speed for a draw r in [0, 1).
function Chime.pitch(r)return 1+(r*2-1)*Chime.Pitch end
-- deps: audio (BoardAudio), busy() -> {round, race, hatch}, now() and random() for specs.
function Chime.new(deps)
	local self={deps=deps,last=nil}
	function self.ring()
		local now=(deps.now or os.clock)()
		local ok,busy=pcall(deps.busy or function()return {}end)
		if not Chime.allowed(now,self.last,if ok then busy else nil)then return false end
		local played=deps.audio and deps.audio:play(Chime.Cue,Chime.pitch((deps.random or math.random)()),Chime.Volume)
		if played then self.last=now end
		return played==true
	end
	return self
end
return Chime
