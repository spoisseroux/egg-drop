-- Overnight 2026-11-14 (SYSTEMS-SCOPE §6): init.client.lua sits near Luau's 200 local-register
-- limit at the top level. New wiring goes in do-blocks or on clientUI, never new column-0 locals.
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.ClientLocalBudget)(PlayerScripts.Client)
return function(client)
	local source=client.Source
	local count=0
	for line in string.gmatch(source.."\n","([^\n]*)\n")do
		if string.sub(line,1,6)=="local "then count+=1 end
	end
	assert(count<=219,"init.client.lua has "..count.." column-0 locals (budget 219)")
	return {"column-0 locals "..count.." <= 219"}
end
