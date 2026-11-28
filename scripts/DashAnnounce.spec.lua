-- Garden Dash server messages on the client (beta 44 note 22, DashAnnounce): the words and both name forms, the
-- translator and its fallback, the escaping for the chat window's rich text, chat first and the rail where there is
-- no chat, malformed packets dropped. (DashClient skipping "starts soon" for a player already in: DashClient.spec.)
-- Usage (Client): require(ZZSpecs.DashAnnounce)(StarterPlayerScripts.Client)
-- Offline: scripts/run_dash_server_specs.py
return function(client)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local UICopy=require(Shared.UICopy)
	local Names=require(Shared.NameCatalog)
	local Announce=require(client.DashAnnounce)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local piece=Names.starterIds()[1]
	local petName=Names.display({piece},nil)

	test("the words: soon; '<name>'s <pet> won' with a known name; '<name>'s pet won' with none or an unknown piece",function()
		assert(UICopy.get("dash.say.soon")=="A Garden Dash starts soon! Join at the starting line.")
		assert(Announce.text({kind="soon"})==UICopy.get("dash.say.soon"))
		assert(piece and petName)
		assert(Announce.text({kind="won",userId=1,name="Sky",petId="pip",pieces={piece}})=="Sky's "..petName.." won the Garden Dash!")
		assert(Announce.text({kind="won",userId=1,name="Sky",petId="pip"})=="Sky's pet won the Garden Dash!")
		assert(Announce.text({kind="won",userId=1,name="Sky",petId="pip",pieces={"nope-not-a-piece"}})=="Sky's pet won the Garden Dash!","never half a name")
		assert(Announce.text({kind="won",userId=1,name="Sky",pieces={piece,piece,piece}})=="Sky's pet won the Garden Dash!","over two pieces: the default")
	end)
	test("malformed packets say nothing",function()
		for _,bad in ipairs({nil,5,"won",{},{kind="hi"},{kind="won"},{kind="won",name=""},{kind="won",name=7},{kind="won",name=string.rep("a",41)}})do
			assert(Announce.text(bad)==nil and Announce.post(bad,{chat=function()error("never")end})==nil)
		end
	end)
	test("the translator's own entry (ui.<key>) when it has one; a missing key or a throw: UICopy",function()
		local asked
		local translator={FormatByKey=function(_,key,vars)asked=key;return "¡"..vars.player.." ganó!"end}
		assert(Announce.text({kind="won",name="Sky"},translator)=="¡Sky ganó!"and asked=="ui.dash.say.wonPet")
		local broken={FormatByKey=function()error("no such key")end}
		assert(Announce.text({kind="soon"},broken)==UICopy.get("dash.say.soon"))
		assert(Announce.text({kind="soon"},{FormatByKey=function()return ""end})==UICopy.get("dash.say.soon"))
	end)
	test("chat first, coloured and escaped; no chat (false or a throw): the rail with the plain words; neither: nil",function()
		local posted
		local function chat(text)posted=text;return true end
		assert(Announce.post({kind="won",name="<b>Sky&Co</b>"},{chat=chat})=="chat")
		assert(posted=="<b>Sky&Co</b>'s pet won the Garden Dash!","post hands the plain words to chat()")
		assert(Announce.escape("<b>Sky&Co</b>'s \"pet\"")=="&lt;b&gt;Sky&amp;Co&lt;/b&gt;&apos;s &quot;pet&quot;")
		local queued={}
		local rail={enqueue=function(owner,key,item)table.insert(queued,{owner=owner,key=key,item=item})end}
		local owner={}
		assert(Announce.post({kind="soon"},{chat=function()return false end,rail=rail,owner=owner})=="rail")
		assert(#queued==1 and queued[1].owner==owner and queued[1].key=="dash.say.soon"and queued[1].item.text==UICopy.get("dash.say.soon"))
		local warned=0
		local real=warn
		warn=function()warned+=1 end
		local ok,where=pcall(Announce.post,{kind="soon"},{chat=function()error("no chat")end,rail=rail,owner=owner})
		warn=real
		assert(ok and where=="rail"and #queued==2 and warned==1)
		assert(Announce.post({kind="soon"},{chat=function()return false end})==nil,"no rail: nothing, no error")
	end)
	return{passed=#cases,cases=cases}
end
