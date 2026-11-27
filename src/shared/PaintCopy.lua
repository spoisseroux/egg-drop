-- Paint, Shine, Dress (PAINT-SHINE-DRESS-PLAN): the words. Shared and pure.
-- `Overrides` maps today's UICopy key to its `paint.*` key. The client installs it into UICopy.get (install) behind
-- the Alive `paint` switch, so every caller of a mapped key shows the new word with no call-site change, and off is
-- today's text exactly. `Banned` is the audit's word list: no string a player meets in Dress up, the Hatch eggs list
-- or the hub may hold one while the switch is on (PaintCopy.spec walks every `paint.*` leaf and every override).
local Copy={}
Copy.Overrides=table.freeze({
	-- Eggs.
	["hatch.egg.look.name"]="paint.egg.look",["hatch.egg.look.line"]="paint.egg.lookLine",["hatch.egg.look.description"]="paint.egg.lookDescription",
	["hatch.egg.look.per"]="paint.egg.lookPer",["hatch.egg.stat.name"]="paint.egg.stat",["hatch.egg.stat.description"]="paint.egg.statDescription",
	["hatch.look.notReady"]="paint.egg.notReady",["hatch.look.reason.NotReady"]="paint.egg.notReady",
	["hatch.stat.notReady"]="paint.egg.statNotReady",["hatch.stat.reason.Disabled"]="paint.egg.statNotReady",
	["stats.snacks.empty"]="paint.egg.snacksEmpty",["tomorrow.statEggs"]="paint.egg.statEggs",["medal.earned"]="paint.egg.medal",
	["hatch.look.jar.gloss"]="paint.shine.shiny",["hatch.look.jar.matte"]="paint.shine.soft",["hatch.look.jar.jelly"]="paint.shine.clear",
	["hatch.look.openSaved.finish"]="paint.shine.openSaved",["hatch.look.charmOwned"]="paint.charmOwned",
	["hatch.reveal.kind.hue"]="paint.egg.kindPot",["hatch.reveal.describe.hue.tide"]="paint.describe.tide",["hatch.reveal.describe.hue.iris"]="paint.describe.iris",["hatch.reveal.kind.finish"]="paint.egg.kindShine",["hatch.display.material"]="paint.egg.shineFor",
	-- Charms.
	["pool3.charm.dot.rule"]="paint.egg.charm",["pool3.charm.ring.rule"]="paint.egg.charm",["pool3.charm.pebble.rule"]="paint.egg.charm",
	["pool3.charm.egg.rule"]="paint.egg.charm",["pool3.charm.none"]="paint.egg.charmNone",
	["book.where.charmEgg"]="paint.egg.where",["book.where.finishJar"]="paint.egg.where",
	-- Shine (the Material tab, FinishPanel).
	["r4.customize.finish.title"]="paint.tab.shine",["r4.customize.finish.shine"]="paint.shine.title",["r4.customize.finish.sheenAxis"]="paint.shine.title",
	["r4.customize.finish.jellyAxis"]="paint.shine.clear",["r4.customize.finish.helper"]="paint.shine.helper",
	["r4.customize.finish.eggLink"]="paint.shine.eggLink",["r4.customize.finish.empty"]="paint.shine.empty",
	["r4.customize.finish.noJars"]="paint.shine.none",["r4.customize.finish.useJar"]="paint.shine.use",
	["r4.customize.finish.reset"]="paint.shine.reset",["r4.customize.finish.already"]="paint.shine.already",
	["r4.customize.finish.clearLine"]="paint.shine.clearLine",["r4.customize.finish.maxSheen"]="paint.shine.max",["r4.customize.finish.maxJelly"]="paint.shine.max",
	["r4.customize.finish.jar.gloss"]="paint.shine.shiny",["r4.customize.finish.jar.matte"]="paint.shine.soft",["r4.customize.finish.jar.jelly"]="paint.shine.clear",
	["r4.customize.finish.sheen.m3"]="paint.shine.soft",["r4.customize.finish.sheen.m2"]="paint.shine.soft",["r4.customize.finish.sheen.m1"]="paint.shine.soft",
	["r4.customize.finish.sheen.zero"]="paint.shine.normal",["r4.customize.finish.sheen.p1"]="paint.shine.shiny",
	["r4.customize.finish.sheen.p2"]="paint.shine.shiny",["r4.customize.finish.sheen.p3"]="paint.shine.shiny",
	["r4.customize.finish.jelly.s1"]="paint.shine.clear1",["r4.customize.finish.jelly.s2"]="paint.shine.clear2",["r4.customize.finish.jelly.s3"]="paint.shine.clear3",
	["r4.customize.moreFinishes"]="paint.shine.more",["r4.customize.moreMaterials"]="paint.shine.more",["r4.customize.moreHues"]="paint.more.hues",
	-- Colour (the Hue tab).
	["r4.hue.original"]="paint.white",["r4.hue.reset"]="paint.white",["r4.hue.confirmReset"]="paint.whiteConfirm",["r4.hue.confirmLine"]="paint.whiteConfirmLine",
	["r4.hue.current"]="paint.whiteCurrent",["r4.hue.originalMain"]="paint.whiteLine",["r4.hue.originalSecondary"]="paint.whiteLine",
	-- The hub, help and notices.
	["r4.customize.subtitle"]="paint.hub.line",["hub.tile.companions.line"]="paint.hub.tile",["coach.companions.line"]="paint.coach",["r3.help.companions.c.title"]="paint.help.title",["r3.help.companions.c.line"]="paint.help.line",
	["r3.help.garden.c.title"]="paint.help.title",["r3.help.companions.d.line"]="paint.help.line",
	["notice.customize.title"]="paint.notice.title",["notice.customize.next"]="paint.notice.next",["notice.customize.what"]="paint.notice.what",
})
Copy.Banned=table.freeze({"Hue","jar","Jar","dose","Dose","Main","Secondary","Rose","Tide","Citrus","Iris","Chalky","Satin","Glassy","Misty",
	"Customization","Customize","Material","Stat Egg"})
-- The first banned word in `text` (as a whole word or its plural), or nil.
function Copy.banned(text)
	if type(text)~="string"then return nil end
	for _,word in ipairs(Copy.Banned)do
		local s=1
		while true do
			local a,b=string.find(text,word,s,true)
			if not a then break end
			local before,after=string.sub(text,a-1,a-1),string.sub(text,b+1,b+1)
			-- A whole word, or its plural ("jars", "doses").
			if(before==""or not string.match(before,"%a"))and(after==""or after=="s"or not string.match(after,"%a"))then return word end
			s=b+1
		end
	end
	return nil
end
-- The override for `key` while `on` (nil: today's key).
function Copy.key(key,on)
	if on~=true then return nil end
	return Copy.Overrides[key]
end
-- Install into UICopy.get: `on()` is read on every call (the Alive switch), so flipping it changes the next string.
function Copy.install(UICopy,on)
	UICopy.setOverride(function(key)return Copy.key(key,on()==true)end)
end
-- The ten swatches: four pots, then the six mixes (HueCatalog.MixOrder). `mix` names the two pots; the name key is
-- paint.pot.<id> or paint.mix.<a_b>.
function Copy.swatches(Hue)
	local out={}
	for _,id in ipairs({"rose","tide","citrus","iris"})do table.insert(out,{id=id,pots={id},color=Hue.ById[id].color,nameKey="paint.pot."..id})end
	for _,key in ipairs(Hue.MixOrder)do
		local m=Hue.Mixes[key]
		table.insert(out,{id=key,pots={m.a,m.b},color=m.color,nameKey="paint.mix."..string.gsub(key,":","_")})
	end
	return out
end
return table.freeze(Copy)
