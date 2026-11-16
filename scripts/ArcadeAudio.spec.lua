-- Semantic cue ownership and pitch contours with the real BoardAudio methods.
return function(client)
	local fresh=client.BoardAudio:Clone();fresh.Parent=client
	local Audio=require(fresh);fresh:Destroy()
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function fixture(master)
		local voice={plays=0,IsLoaded=true}
		function voice:Play()self.plays+=1 end
		local audio=setmetatable({group={Volume=master},deviceActive=true,indices={},voices={menu={voice}}},Audio)
		return audio,voice
	end
	test("one semantic action token emits one cue even across a second widget",function()
		local a,v=fixture(1)
		assert(a:ui("confirm","shop:1")and not a:ui("tab","shop:1")and v.plays==1)
		assert(a:ui("tab","settings:2")and v.plays==2 and v.PlaybackSpeed==1.12)
		assert(a:ui("back","menu:3")and v.Volume==.35 and v.PlaybackSpeed==.84)
	end)
	test("ring remains bounded after many unique accepted actions",function()
		local a,v=fixture(1);for n=1,200 do assert(a:ui("tab",n))end
		local count=0;for _ in pairs(a.uiTokens)do count+=1 end
		assert(count==64 and #a.uiRing==64 and v.plays==200 and not a:ui("confirm",200))
	end)
	test("mute consumes an action without replay on unmute",function()
		local a,v=fixture(0);assert(not a:ui("confirm",1));a.group.Volume=1
		assert(not a:ui("confirm",1)and v.plays==0);assert(a:ui("confirm",2))
	end)
	test("unloaded or inactive cues drop without a delayed echo",function()
		local a,v=fixture(1);v.IsLoaded=false;assert(not a:ui("confirm",1));v.IsLoaded=true
		assert(not a:ui("confirm",1));a.deviceActive=false;assert(not a:ui("back",2))
		a.deviceActive=true;assert(not a:ui("back",2)and v.plays==0)
	end)
	test("invalid and teardown calls emit no cue",function()
		local a,v=fixture(1)
		assert(not a:ui("hover",1)and not a:ui("confirm",nil)and not a:ui("tab",0/0))
		a.destroyed=true;assert(not a:ui("back",2)and v.plays==0)
	end)
	test("QA v775: equip and unequip are their own sounds, with a repitched click as the fallback",function()
		local function voice()local x={plays=0,IsLoaded=true};function x:Play()self.plays+=1 end;return x end
		local a,v=fixture(1)
		local pop,tick,flip=voice(),voice(),voice()
		a.voices.egg_select={pop};a.voices.goal_tick={tick};a.voices.row_flip={flip}
		local later={};a.schedule=function(delay,run)table.insert(later,{delay,run})end
		assert(a:ui("equip",1)and pop.plays==1 and v.plays==0 and #later==1 and later[1][1]==.07,"equip is the pop, then a tick")
		later[1][2]();assert(tick.plays==1 and tick.PlaybackSpeed==1.26)
		assert(a:ui("unequip",2)and flip.plays==1 and flip.PlaybackSpeed==.84 and pop.plays==1 and #later==1,"unequip is the lower flip, no tick")
		assert(not a:ui("equip",2),"one token, one sound")
		local b,w=fixture(1)
		assert(b:ui("equip",1)and w.plays==1 and w.PlaybackSpeed==1.3,"no pop loaded: a high click")
		assert(b:ui("unequip",2)and w.plays==2 and w.PlaybackSpeed==.72,"no flip loaded: a low click")
	end)
	test("all six SFX/music choices preserve semantic master behavior",function()
		for _,master in ipairs({1,.4,0})do for _,music in ipairs({true,false})do
			local a,v=fixture(master);a.musicEnabled=music
			assert(a:ui("confirm",1)==(master>0));assert(v.plays==(if master>0 then 1 else 0))
		end end
	end)
	test("G1 chain contour: one major-scale note per chain step, an octave at chain 8, bounded",function()
		local a=fixture(1)
		assert(a:mergePitch(1,0)==1 and a:mergePitch(2,0)==2^(2/12)and a:mergePitch(3,0)==2^(4/12)and a:mergePitch(8,0)==2)
		local last=0
		for chain=1,8 do local pitch=a:mergePitch(chain,0);assert(pitch>last,"chain "..chain.." does not rise");last=pitch end
		for chain=1,100 do local pitch=a:mergePitch(chain,4);assert(pitch>=1 and pitch<=2.03)end
		assert(a:mergePitch(0/0,math.huge)==1)
		assert(Audio.chainAccentVolume(2)==.30 and Audio.chainAccentVolume(1)==.30 and math.abs(Audio.chainAccentVolume(4)-.38)<1e-9 and Audio.chainAccentVolume(40)==.50)
	end)
	test("unloaded merge and drop are discarded before playback state and never replay on readiness",function()
		local a,v=fixture(1);v.IsLoaded=false
		a.voices.drop={v};a.voices.merge_bubble={v};a.voices.hatch={v}
		a.duck=function()error("unloaded hatch must not change duck state")end
		assert(not a:play("drop")and not a:play("merge_bubble")and not a:play("hatch"))
		assert(v.plays==0 and a.indices.drop==nil and v.TimePosition==nil)
		v.IsLoaded=true;assert(v.plays==0)
		assert(a:play("drop")and v.plays==1)
		v.IsLoaded=nil;assert(a:play("merge_bubble")and v.plays==2,"legacy nil doubles remain supported")
	end)
	test("inactive device discards one-shot before changing voice state",function()
		local a,v=fixture(1);a.voices.land={v};a.deviceActive=false
		assert(not a:play("land")and v.plays==0 and a.indices.land==nil)
		a.deviceActive=true;assert(v.plays==0)
		assert(a:play("land")and v.plays==1)
	end)
	test("field owner loss stops exactly field pools while UI hatch purr and music remain independent",function()
		local a=fixture(1)
		local function sound()local v={stops=0};function v:Stop()self.stops+=1 end;return v end
		for _,name in ipairs({"aim","drop","land","bank","merge_bubble","merge_jelly","merge_chain","menu","hatch","charge"})do
			a.voices[name]={sound(),sound()}
		end
		a.music={voice=sound()};a.purr={voice=sound()}
		a:stopField()
		for _,name in ipairs({"aim","drop","land","bank","merge_bubble","merge_jelly","merge_chain"})do
			assert(a.voices[name][1].stops==1 and a.voices[name][2].stops==1)
		end
		assert(a.voices.menu[1].stops==0 and a.voices.hatch[1].stops==0 and a.voices.charge[1].stops==0)
		assert(a.music.voice.stops==0 and a.purr.voice.stops==0)
		a.destroyed=true;a:stopField();assert(a.voices.drop[1].stops==1)
	end)
	return{passed=#cases,cases=cases,evidence="actual semantic/pitch methods; voice doubles, not an audible mix audition"}
end
