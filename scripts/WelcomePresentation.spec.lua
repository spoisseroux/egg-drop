-- Real GuiObject fixture in Studio; layout acceptance still needs device captures.
return function(client,gui,modules)
	modules=modules or {}
	local View=modules.View or require(client.WelcomePresentation)
	local hosts={}
	for _,name in ipairs({"meter","gesture","skip"})do
		local frame=Instance.new("Frame");frame.Name="WelcomeTest_"..name;frame.Size=UDim2.fromOffset(120,80);frame.Parent=gui;hosts[name]=frame
	end
	local cues,quiet,skips=0,0,0
	local view=View.new(hosts,{copy=function(key)return key end,cue=function()cues+=1 end,quietCue=function()quiet+=1 end,skip=function(generation)assert(generation==10);skips+=1 end})
	local s={generation=10,charge=0,threshold=6,owned=0,phase="Welcome",active=true,drops=0,skipReady=true,device="Touch",reduced=false}
	local function sync()return view:update(table.clone(s))end
	assert(View.fit(120,80)==64 and View.fit(12,12)==0,"8px inset on every side")
	assert(sync()=="onboarding.welcome.friend"and cues==0 and view.ghost.Visible)
	s.charge=2;assert(sync()=="onboarding.welcome.match"and cues==1 and view.cracks[1].Visible and not view.cracks[2].Visible)
	s.charge=4;assert(sync()=="onboarding.welcome.more"and cues==2 and view.cracks[2].Visible)
	for _=1,33 do view:step(.25)end
	assert(quiet==1);view:step(.25);assert(quiet==1,"idle replay is once")
	assert(view:requestSkip()and not view:requestSkip()and skips==1,"one local send while pending")
	local checkpoint=view:checkpoint();view:destroy()
	view=View.new(hosts,{copy=function(key)return key end,cue=function()cues+=1 end,quietCue=function()quiet+=1 end,skip=function()skips+=1 end})
	view:restore(checkpoint);view:update(table.clone(s))
	assert(view.pending and view.interacted and view.replayed and not view.ghost.Visible and not view:requestSkip(),"same-run HUD rebuild preserves pending/input/replay state")
	view:setSkipPending(false)
	view:input();assert(not view.ghost.Visible and not view.glyph.Visible)
	s.generation=11;s.reduced=true;s.charge=6;sync()
	assert(cues==2 and view.egg.Rotation==0 and view.glyph.Visible,"rejoin baseline silent and reduced motion static")
	s.active=false;sync();assert(not view.egg.Visible and not view.skip.Visible and not view.ghost.Visible)
	s.active=true;s.owned=1;sync();assert(not view.egg.Visible,"returning owners bypass")
	view:destroy();view:destroy();assert(not view:requestSkip(),"destroyed view is inert")
	for _,host in pairs(hosts)do host:Destroy()end
	return {passed=5}
end
