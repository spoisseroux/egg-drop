-- Deterministic voice/clock/fade doubles. Audible playback is a separate gate.
return function(client)
	local Audio = require(client.BoardAudio)
	local cases = {}
	local function test(name, run) run(); table.insert(cases, name) end
	local function fixture()
		local now, jobs, fades = 0, {}, {}
		local function voice()
			local value = {Volume=0, IsPlaying=false, plays=0, stops=0}
			function value:Play() assert(not self.destroyed); self.IsPlaying=true; self.plays+=1 end
			function value:Stop() assert(not self.destroyed); self.IsPlaying=false; self.stops+=1 end
			function value:Destroy() self.destroyed=true end
			return value
		end
		local function group()
			local value={Volume=0,Parent=true}
			function value:Destroy() self.Parent=nil end
			return value
		end
		local music,purr={voice=voice(),group=group(),ready=true},{voice=voice(),group=group(),ready=true}
		local sfx=voice()
		local charge=voice()
		function charge:Clone() error("Stale boot cloned a disposed source") end
		local audio=setmetatable({music=music,purr=purr,group=group(),voices={menu={sfx},hatch={voice()},hatch_rise={voice()},charge={charge}},
			indices={},ducks={},connections={},musicEnabled=true,deviceActive=true,
			schedule=function(delay,run)table.insert(jobs,{at=now+delay,run=run})end,
			tween=function(target,volume,complete)table.insert(fades,{voice=target,volume=volume,complete=complete})end},Audio)
		local function advance(time)
			now=time
			for _,job in ipairs(jobs)do if not job.done and job.at<=now then job.done=true;job.run()end end
		end
		local function finish(index)
			local fade=fades[index or #fades]
			-- Tween cancellation is tested through the epoch-guarded callback.
			fade.complete()
		end
		return audio,advance,finish,sfx
	end
	test("unresolved master and fast ready assets are silent",function()
		local a=fixture();a:refreshLoops()
		assert(a.music.voice.plays==0 and a.music.group.Volume==0 and not a:setPurr(true))
		a:setVolume(0);a:refreshLoops();assert(a.music.voice.plays==0)
	end)
	for _,master in ipairs({1,0.4,0})do
		for _,enabled in ipairs({true,false})do
			test("master "..master.." music "..tostring(enabled),function()
				local a,_,_,sfx=fixture();a:setMusicEnabled(enabled);a:setVolume(master)
				assert(a.music.voice.IsPlaying==(master>0 and enabled))
				assert(a.music.group.Volume==master and a.group.Volume==master and a.purr.group.Volume==master)
				a:play("menu");assert(sfx.plays==(if master>0 then 1 else 0))
			end)
		end
	end
	test("independent ducks do not overwrite master or session choice",function()
		local a,advance=fixture();a:setVolume(1)
		a:duck("boot",.65,.22);a:duck("hatch",1.2,.22)
		a:cancelBoot();assert(a.music.group.Volume==.22)
		a:setVolume(.4);assert(math.abs(a.music.group.Volume-.088)<.000001)
		a:setMusicEnabled(false);advance(2);assert(not a.music.voice.IsPlaying)
		a:setMusicEnabled(true);assert(a.music.group.Volume==.4 and a.music.voice.IsPlaying)
	end)
	test("old same-name duck expiry cannot remove replacement",function()
		local a,advance=fixture();a:setVolume(1)
		a:duck("hatch",.5,.22);a:duck("hatch",1.2,.22)
		advance(.6);assert(a.music.group.Volume==.22)
		advance(1.3);assert(a.music.group.Volume==1)
	end)
	test("one purr owner and old fade cannot stop a new gesture",function()
		local a,_,finish=fixture();a:setVolume(1)
		assert(a:setPurr(true) and a:setPurr(true));assert(a.purr.voice.plays==1)
		a:setPurr(false);assert(a:setPurr(true));finish(2)
		assert(a.purr.voice.IsPlaying and a.purr.active and a.purr.voice.plays==2)
		a:setPurr(false);finish();assert(not a.purr.voice.IsPlaying)
	end)
	test("mute consumes purr without deferred unmute start",function()
		local a,_,finish=fixture();a:setVolume(1);a:setPurr(true)
		a:setVolume(0);assert(not a.purr.voice.IsPlaying and a.purr.voice.Volume==0)
		a:setVolume(1);finish(1);assert(not a.purr.voice.IsPlaying)
		assert(a:setPurr(true) and a.purr.voice.plays==2)
	end)
	test("asset readiness never queues purr and starts only one music",function()
		local a=fixture();a.purr.ready=false;a.music.ready=false;a:setVolume(1)
		assert(not a:setPurr(true));a.purr.ready=true;a.music.ready=true
		a:refreshLoops();a:refreshLoops()
		assert(a.music.voice.plays==1 and a.purr.voice.plays==0)
	end)
	test("inactive device never accepts purr",function()
		local a=fixture();a:setVolume(1);a:setDeviceActive(false)
		assert(not a:setPurr(true) and not a.music.voice.IsPlaying)
		a:setDeviceActive(true);assert(a.music.voice.IsPlaying and a.purr.voice.plays==0)
	end)
	test("retry stops effects but preserves independent music preference",function()
		local a,advance=fixture();a:setVolume(1);a:duck("hatch",1,.22);a:stop()
		assert(a:isMusicEnabled() and a.music.voice.IsPlaying and a.music.group.Volume==1)
		advance(2);assert(a.music.group.Volume==1)
		a:setMusicEnabled(false);a:stop();a:setVolume(.4)
		assert(not a:isMusicEnabled() and not a.music.voice.IsPlaying)
	end)
	test("destroy invalidates delayed ducks fades and future starts",function()
		local a,advance,finish=fixture();a:setVolume(1);a:setPurr(true);a:duck("hatch",1,.22)
		a.music.voice.IsPlaying=false -- Ready but stopped: cleanup must never re-admit it.
		local plays=a.music.voice.plays
		a:destroy();advance(2);finish(1);a:setMusicEnabled(true);a:setVolume(1)
		a:boot(function()return true end);a:silencePurr();a:stop();a:refreshLoops()
		a:setDeviceActive(false);a:setDeviceActive(true)
		assert(a.music.voice.plays==plays)
		assert(a.music.voice.destroyed and a.purr.voice.destroyed and not a:setPurr(true))
	end)
	return {passed=#cases,cases=cases,evidence="deterministic scheduler/voice doubles; not an audible audition"}
end
