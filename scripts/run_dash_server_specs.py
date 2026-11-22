"""Run the Garden Dash server and client specs (slices S6, S7) in the Luau command line tool, with Roblox mocks (no Studio).

    python scripts/run_dash_server_specs.py [path to luau.exe] [base commit] [live commit]
    DASH_SPECS="ParkDirector MedalEggs" ...   other specs by name (some need engine parts the mocks do not have)

Bundles src/shared and src/server of this tree, plus the same folders of two commits read with git: `base` (the
commit this slice starts from, for the off-parity JSON) and `live` (the published build, for the cross-version
save check). Each tree has its own module cache and its own `game`; the mocks (offline_roblox.luau) are shared.
The specs are the same files Studio runs from ZZSpecs; DashCrossVersion.spec needs the two old trees, so it is
offline only.
"""
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LUAU = sys.argv[1] if len(sys.argv) > 1 else str(ROOT / "build/luau-cli/luau.exe")
BASE = sys.argv[2] if len(sys.argv) > 2 else "46ab954"
LIVE = sys.argv[3] if len(sys.argv) > 3 else "aeae2d9"
ONLY = os.environ.get("DASH_SPECS", "").split()
SPECS = ["Dash", "DashConfig", "DashWire", "DashDirector", "DashState", "DashPrize", "DashGating", "DashHost",
         "DashOffParity", "DashCrossVersion", "CloseProgress"]
# Client specs: the Dash modules as they are, small stand-ins for the screens they borrow, and RoomView's hooks cut
# out of RoomView.lua (the rest of it needs an engine). One realm: the mocks answer IsServer and IsStudio true.
CLIENT = ["DashPredict", "DashCamera", "DashInput", "DashHud", "DashClient"]
SPECS += CLIENT
STUBS = {
    "PetFollow": "return{CadenceCap=3,stride=function()return 2 end,bob=function()return 0 end,rest=function(v)v.gaitWeight=0 end}",
    "PetFactory": "return{}", "DeckKit": "return{focusable=function(object)return object.ok==true end}", "NotificationRail": "return{}",
    "ConfirmDialog": "return{isOpen=function()return false end}",
}


def client_modules():
    out = {f"client/{name}": source for name, source in STUBS.items()}
    for path in sorted((ROOT / "src/client").glob("Dash*.lua")):
        out[f"client/{path.stem}"] = path.read_text(encoding="utf-8")
    room = (ROOT / "src/client/RoomView.lua").read_text(encoding="utf-8")
    hooks = room[room.index("function Room:enterDash()"):room.index("function Room:retryArrivalPlacement()")]
    out["client/RoomViewDash"] = (
        "local Room={};Room.__index=Room\nRoom.lock=require(script.Parent.MovementLock).new({})\nlocal MovementLock={shared=function()return Room.lock end}\n"
        "local GuiService={}\nRoom.gui=GuiService\nlocal PetGreetingShot={capture=function(camera,root)return{camera=camera,root=root,position=root and root.Position,"
        "transform=camera.CFrame,focus=camera.Focus,fov=camera.FieldOfView}end,\nrestore=function(saved,camera,root)if not saved or saved.camera~=camera or "
        "saved.root~=root or not root then return false end;camera.CFrame,camera.Focus,camera.FieldOfView=saved.transform,saved.focus,saved.fov;return true end}\n"
        + hooks + "\nreturn Room")
    init = (ROOT / "src/client/init.client.lua").read_text(encoding="utf-8")
    modal = init[init.index("clientUI.anyModalOpen=function(others)"):init.index("-- QA v2 R2.1/R2.2: the same edge")]
    out["client/InitModal"] = "return function(clientUI,isPickerOpen,journal,nurseryView,gameMenu,modal)\n" + modal + "\nreturn clientUI.anyModalOpen\nend"
    out["client/MovementLock"] = (ROOT / "src/client/MovementLock.lua").read_text(encoding="utf-8")
    return out


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, check=True, capture_output=True).stdout.decode("utf-8")


def files(commit):
    """{"shared/X": source} for every plain module (no init scripts, no nested folders)."""
    out = {}
    for side in ("shared", "server"):
        if commit is None:
            for path in sorted((ROOT / "src" / side).glob("*.lua")):
                if not path.name.startswith("init."):
                    out[f"{side}/{path.stem}"] = path.read_text(encoding="utf-8")
        else:
            for name in git("ls-tree", "--name-only", f"{commit}:src/{side}").split():
                if name.endswith(".lua") and not name.startswith("init."):
                    out[f"{side}/{name[:-4]}"] = git("show", f"{commit}:src/{side}/{name}")
    return out


def tree(name, commit):
    sources = files(commit)
    if commit is None:
        sources.update(client_modules())
    body = "\n".join(
        f'trees.{name}["{path}"]=function(script,require,game)\n{source}\nend' for path, source in sources.items())
    return f"trees.{name}={{}}\n{body}"


specs = ONLY or SPECS
for name in specs:
    assert (ROOT / f"scripts/{name}.spec.lua").exists(), name
bundle = "\n".join([
    "local trees={}",
    tree("new", None), tree("base", BASE), tree("live", LIVE),
    "local specs={}",
    "\n".join(f"specs.{name}=function(game,require)\n{(ROOT / f'scripts/{name}.spec.lua').read_text(encoding='utf-8')}\nend"
              for name in specs),
    f"local ORDER={{{','.join(repr(name) for name in specs)}}}",
    f"local CLIENT={{{','.join(name + '=true' for name in CLIENT)}}}",
    (ROOT / "scripts/offline_roblox.luau").read_text(encoding="utf-8"),
])
lines = bundle.splitlines()


def where(match):
    """A bundle line as file:line."""
    number = int(match.group(1))
    for at in range(min(number, len(lines)) - 1, -1, -1):
        start = re.match(r'(?:specs\.(\w+)|trees\.(\w+)\["([\w/]+)"\])=function\(', lines[at])
        if start:
            spec, which, path = start.groups()
            name = f"scripts/{spec}.spec.lua" if spec else f"{which}:src/{path}.lua"
            return f"{name}:{number - at - 1}"
    return match.group(0)


with tempfile.TemporaryDirectory() as folder:
    path = os.path.join(folder, "dash_server_specs.luau")
    Path(path).write_text(bundle, encoding="utf-8")
    run = subprocess.run([LUAU, "-O1", path], capture_output=True)
    text = (run.stdout + run.stderr).decode("utf-8", "replace")
    print(re.sub(r"\S*dash_server_specs\.luau:(\d+)", where, text))
    sys.exit(run.returncode)
