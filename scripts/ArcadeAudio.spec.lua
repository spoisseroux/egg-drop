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
	test("all six SFX/music choices preserve semantic master behavior",function()
		for _,master in ipairs({1,.4,0})do for _,music in ipairs({true,false})do
			local a,v=fixture(master);a.musicEnabled=music
			assert(a:ui("confirm",1)==(master>0));assert(v.plays==(if master>0 then 1 else 0))
		end end
	end)
	test("chain contour is bounded to the approved zero third and fourth intervals",function()
		local a=fixture(1)
		assert(a:mergePitch(1,0)==1 and a:mergePitch(2,0)==2^(3/12)and a:mergePitch(3,0)==2^(5/12))
		for chain=1,100 do local pitch=a:mergePitch(chain,4);assert(pitch>=1 and pitch<=1.36)end
		assert(a:mergePitch(0/0,math.huge)==1)
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
