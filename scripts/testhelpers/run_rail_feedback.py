"""Offline actual care transport. RailFeedback now uses native GUI instances in Studio."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]

def module(path, replacements=()):
    source = (ROOT / path).read_text(encoding="utf-8")
    for old, new in replacements:
        assert old in source, (path, old)
        source = source.replace(old, new)
    return "(function()\n" + source + "\nend)()"

chunks = [
    'local Enum={KeyCode=setmetatable({},{__index=function(_,key)return key end})}',
    'local Color3={fromHex=function(value)return value end}',
    'local game={GetService=function()return{Shared={}}end}',
    'local Copy=' + module("src/shared/UICopy.lua", [('pcall(require,script.Parent.FeatureFlags)', 'true,{PseudoLocale=false}')]),
    'local Items=' + module("src/shared/RoundItems.lua"),
    'local Kit={reduced=function()return true end}',
    'local Carousel=' + module("src/client/ItemCarousel.lua", [
        ('require(script.Parent.DeckKit)', 'Kit'), ('require(Shared.UICopy)', 'Copy'),
        ('require(Shared.RoundItems)', 'Items'), ('require(script.Parent.ItemIcons)', '{}')]),
    'local Care=' + module("src/client/GardenCareClient.lua", [
        ('require(script.Parent.DeckArt)', '{}'), ('require(Replicated.Shared.GardenCareLayout)', '{}'),
        ('require(Replicated.Shared.UICopy)', 'Copy')]),
    'local Queue=' + module("src/client/NotificationQueue.lua"),
    'local client={ItemCarousel=Carousel,GardenCareClient=Care,NotificationQueue=Queue}',
]
for name in ("GardenCareClient",):
    spec = module("scripts/" + name + ".spec.lua", [
        ("require(client." + dep + ")", "client." + dep)
        for dep in (("GardenCareClient",) if name == "GardenCareClient" else ("ItemCarousel", "NotificationQueue"))])
    chunks.append('do local result=(' + spec + ')(client);print("' + name + ': "..result.passed.." passed")end')
target = ROOT / "build/rail-feedback-offline.luau"
target.write_text("\n".join(chunks), encoding="utf-8")
subprocess.run([str(ROOT / "build/luau-cli/luau.exe"), str(target)], cwd=ROOT, check=True)
