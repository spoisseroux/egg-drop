-- Deterministic scheduler/sound doubles; no Instances, playback, waits or profile writes.
return function(client)
	local Audio=require(client.BoardAudio)
	local Policy=require(client.PresentationPolicy)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function fixture()
		local voices={}
		local source={}
		function source:Clone()
			local voice={plays=0}
			function voice:Play()assert(not self.destroyed);self.plays+=1 end
			function voice:Stop()self.stopped=true end
			function voice:Destroy()self.destroyed=true end
			table.insert(voices,voice);return voice
		end
		local queued={}
		local audio=setmetatable({voices={charge={source}},group={Parent=true,Volume=1},
			schedule=function(seconds,run)table.insert(queued,{seconds=seconds,run=run})end},Audio)
		local function advance(time)
			for _,job in ipairs(queued) do
				if not job.done and job.seconds<=time then job.done=true;job.run() end
			end
		end
		return audio,voices,advance
	end
	test("mid boot overlay cancels queued pitches and only its own voice",function()
		local state={mode="Board"};local p=Policy.new(function()return state end)
		local token=p:begin(true,"initial");local audio,voices,advance=fixture()
		audio:boot(function()return p:owns(token)end);advance(0)
		local count=voices[1].plays;assert(count==1)
		state.overlay=true;p:cancel();audio:cancelBoot();advance(1)
		assert(voices[1].plays==count and voices[1].destroyed and voices[1].stopped)
	end)
	test("muted and reduced motion suppress every queued chime note",function()
		local audio,voices,advance=fixture();audio.group.Volume=0;audio:boot(function()return true end)
		advance(1);assert(voices[1].plays==0);audio:cancelBoot()
		audio,voices=fixture();local owns=false;audio:boot(function()return owns end)
		assert(#voices==0)
	end)
	test("new owner cannot receive the old boot's queued pitches",function()
		local p=Policy.new(function()return{mode="Board"}end)
		local audio,voices,advance=fixture();local old=p:begin(true,"initial")
		audio:boot(function()return p:owns(old)end)
		local nextToken=p:begin(true,"arrival")
		audio:boot(function()return p:owns(nextToken)end);advance(1)
		assert(voices[1].destroyed and voices[1].plays==0 and voices[2].plays==3)
		audio:cancelBoot()
	end)
	test("inactive or unloaded boot admission never clones or queues a voice",function()
		local audio,voices,advance=fixture();audio.deviceActive=false
		audio:boot(function()return true end);advance(1);assert(#voices==0)
		audio.deviceActive=true;audio.voices.charge[1].IsLoaded=false
		audio:boot(function()return true end);advance(2);assert(#voices==0)
		audio.voices.charge[1].IsLoaded=true;assert(#voices==0)
	end)
	test("window loss cancels boot epochs and field voices; refocus cannot replay missed notes",function()
		local audio,voices,advance=fixture()
		local field={stops=0};function field:Stop()self.stops+=1 end;audio.voices.drop={field}
		audio:boot(function()return true end);advance(0);assert(voices[1].plays==1)
		audio:setDeviceActive(false);assert(voices[1].destroyed and field.stops==1)
		audio:setDeviceActive(true);advance(1);assert(voices[1].plays==1)
		audio:boot(function()return true end);advance(2);assert(voices[2].plays==3)
	end)
	test("unready cloned boot notes are dropped without playback when readiness later returns",function()
		local audio,voices,advance=fixture();audio:boot(function()return true end)
		voices[1].IsLoaded=false;advance(1);assert(voices[1].plays==0)
		voices[1].IsLoaded=true;advance(2);assert(voices[1].plays==0)
		audio:cancelBoot()
	end)
	return{passed=#cases,cases=cases}
end
