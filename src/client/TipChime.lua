-- The new-tip chime (beta 12 QA S2; beta 14 QA Q6, RACE-AND-MUSIC-LOOK 4): a short kalimba chime when a Things to do
-- tip lands on the notice rail, and nothing else. Spencer picked the kalimba family (2026-11-23). Six variants, two or
-- three notes in C pentatonic, all ending upward (scripts/synth_tip_chime_set.py; files in assets/audio/custom/
-- egg_drop_tip_chime_1..6.wav, original synthesis). A slot without an id has no voice: BoardAudio makes none, and the
-- pick skips it; with no ids at all play() is a quiet no-op.
-- Pick: a shuffle bag, all six once before any repeats, and a refilled bag never opens on the one just played.
-- Pitch: one of three steps (a whole tone down, as written, a whole tone up), never the same step twice running, plus
-- a fine drift of up to 1.5%. The low step is .944 (not .891) so the kalimba stays under about .47 s.
-- Never more than once in Gap seconds; silent during a deck round, a race or a hatch, and when the sound setting is
-- off (the UI group's volume). Reduced Motion does not change it.
local Chime={}
Chime.SoundIds={nil,nil,nil,nil,nil,nil} -- rbxassetid numbers, filled after upload (index = variant)
Chime.Count=6
Chime.Volume=.25  -- under the Stars pickup
Chime.Gap=20
Chime.Steps={.944,1,1.122}
Chime.Drift=.015

function Chime.cue(index)return "tip_chime_"..tostring(index)end
-- The variants that have a sound.
function Chime.ready(ids)
	ids=ids or Chime.SoundIds
	local out={}
	for i=1,Chime.Count do if ids[i]then table.insert(out,i)end end
	return out
end
-- Pure: may it ring now? last = when it last rang (nil = never); busy = {round, race, hatch}.
function Chime.allowed(now,last,busy)
	busy=busy or {}
	if busy.round or busy.race or busy.hatch then return false end
	return last==nil or now-last>=Chime.Gap
end
-- Pure: the next chime. state = {bag = {variant...}, last = variant?, step = step index?}; ready = the variants with a
-- sound; r1, r2, r3 in [0, 1) choose the bag order, the pitch step and the drift. Answers (variant, speed, newState),
-- or nil when nothing is ready.
function Chime.pick(state,ready,r1,r2,r3)
	state=state or {}
	if #ready==0 then return nil,nil,state end
	local bag={}
	for _,v in ipairs(state.bag or {})do if table.find(ready,v)then table.insert(bag,v)end end
	if #bag==0 then
		-- Refill: a shuffle drawn from r1 (a small LCG so one number orders the whole bag), never opening on the last one.
		local pool=table.clone(ready)
		local seed=math.floor((r1 or 0)*2147483647)
		for i=#pool,2,-1 do
			seed=(seed*1103515245+12345)%2147483648
			local j=seed%i+1
			pool[i],pool[j]=pool[j],pool[i]
		end
		if #pool>1 and pool[1]==state.last then pool[1],pool[2]=pool[2],pool[1]end
		bag=pool
	end
	local variant=table.remove(bag,1)
	-- Pitch step: any of the three except the last one used.
	local choices={}
	for i=1,#Chime.Steps do if i~=state.step then table.insert(choices,i)end end
	local step=choices[math.clamp(math.floor((r2 or 0)*#choices)+1,1,#choices)]
	local speed=Chime.Steps[step]*(1+((r3 or .5)*2-1)*Chime.Drift)
	return variant,speed,{bag=bag,last=variant,step=step}
end
-- deps: audio (BoardAudio), busy() -> {round, race, hatch}, now() and random() for specs, ids for specs.
function Chime.new(deps)
	local self={deps=deps,last=nil,state={}}
	function self.ring()
		local now=(deps.now or os.clock)()
		local ok,busy=pcall(deps.busy or function()return {}end)
		if not Chime.allowed(now,self.last,if ok then busy else nil)then return false end
		local random=deps.random or math.random
		local variant,speed,state=Chime.pick(self.state,Chime.ready(deps.ids),random(),random(),random())
		if not variant then return false end
		local played=deps.audio and deps.audio:play(Chime.cue(variant),speed,Chime.Volume)
		if played then self.last,self.state=now,state end
		return played==true
	end
	return self
end
return Chime
