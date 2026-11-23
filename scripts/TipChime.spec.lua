-- The new-tip chime (beta 12 QA S2): silent without a sound, never twice in 20 s, never in a round, a race or a hatch,
-- quiet and a little pitch-varied. Pure parts with a stand-in audio.
-- Usage (Client): require(ZZSpecs.TipChime)(StarterPlayerScripts.Client)
-- Offline: scripts/run_dash_server_specs.py
return function(client)
	local Chime=require(client.TipChime)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end

	test("no sound picked yet: the slot is empty and a ring is a quiet no-op",function()
		assert(Chime.SoundId==nil and Chime.Cue=="tip_chime")
		local audio={play=function()return false end}
		local chime=Chime.new({audio=audio,now=function()return 5 end,random=function()return .5 end})
		assert(chime.ring()==false and chime.last==nil,"nothing rang, so the gap has not started")
	end)
	test("once in 20 s; never in a round, a race or a hatch; quieter than the Stars; pitch within 3%",function()
		local clock,played,busy=0,{},{}
		local audio={play=function(_,cue,speed,volume)table.insert(played,{cue=cue,speed=speed,volume=volume});return true end}
		local chime=Chime.new({audio=audio,now=function()return clock end,random=function()return .99 end,busy=function()return busy end})
		assert(chime.ring()and #played==1 and played[1].cue=="tip_chime"and played[1].volume==.25)
		assert(math.abs(played[1].speed-1)<=Chime.Pitch+1e-9)
		clock=19;assert(not chime.ring()and #played==1)
		clock=20;assert(chime.ring()and #played==2)
		for _,what in ipairs({"round","race","hatch"})do
			clock+=30;busy={[what]=true};assert(not chime.ring(),what)
		end
		busy={};assert(chime.ring())
		assert(Chime.pitch(0)==1-Chime.Pitch and Chime.pitch(.5)==1)
	end)
	return{passed=#cases,cases=cases}
end
