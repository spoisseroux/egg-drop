"""Offline real Luau state/queue specs; GUI rendering remains a Studio gate."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]

def module(path, replacements=()):
    source = (ROOT / path).read_text(encoding="utf-8")
    for old, new in replacements:
        source = source.replace(old, new)
    return "(function()\n" + source + "\nend)()"

chunks = ['local signal={Connect=function()return{Disconnect=function()end}end}',
          'local task={spawn=function(fn)fn()end,delay=function()return{}end,cancel=function()end}',
          'local Enum={AssetFetchStatus={Success="Success"}}',
          'local game={GetService=function(_,name)return{Heartbeat=signal,IsStudio=function()return true end}end}']
for name in ("NotificationQueue", "FocusRow", "PreviewFeedback"):
    chunks.append("local " + name + "=" + module("src/client/" + name + ".lua"))
chunks.append('local Copy={get=function(_,v)return tostring(v.count).." more Stars needed"end}')
chunks.append("local ShopPriceState=" + module("src/client/ShopPriceState.lua", [('require(game:GetService("ReplicatedStorage").Shared.UICopy)', "Copy")]))
chunks.append("local Readiness=" + module("src/client/PetAssetReadiness.lua"))
chunks.append("local UIAssetWarmup=" + module("src/client/UIAssetWarmup.lua", [('require(script.Parent.PetAssetReadiness)', "Readiness")]))
chunks.append("local client={NotificationQueue=NotificationQueue,FocusRow=FocusRow,PreviewFeedback=PreviewFeedback,ShopPriceState=ShopPriceState,UIAssetWarmup=UIAssetWarmup}")
for name in ("NotificationQueue", "QAUIState", "UIAssetWarmup"):
    spec = module("scripts/" + name + ".spec.lua", [("require(client." + dep + ")", "client." + dep) for dep in ("NotificationQueue", "FocusRow", "PreviewFeedback", "ShopPriceState", "UIAssetWarmup")])
    chunks.append('do local result=(' + spec + ')(client);print("' + name + ': "..result.passed.." passed")end')
target = ROOT / "build/qa-ui-offline.luau"
target.write_text("\n".join(chunks), encoding="utf-8")
subprocess.run([str(ROOT / "build/luau-cli/luau.exe"), str(target)], cwd=ROOT, check=True)
