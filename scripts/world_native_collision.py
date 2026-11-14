"""Validate the deliberately promoted native world checkpoint; never sign one implicitly.

Run this preflight BEFORE rojo build. Rojo itself cannot execute this guard.
"""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import tempfile

NATIVE = "assets/world/WorldAssetsNative.rbxm"
PROOF = "assets/world/world-v7-native-collision.json"
XML = "assets/world/WorldAssets.rbxmx"
LUA = "src/shared/WorldV7Data.lua"
INPUTS = tuple("assets/world/" + name for name in (
    "world-v7-manifest.json", "world-v7-walk.json", "world-v7-studio-import.json",
    "world-v7-uploads.json", "world-v7-collision.json", "world-v7-collision-studio-import.json",
    "world-v7-pending.json", "world-v7-palette.json", "world-dressing-manifest.json",
    "world-dressing-import.json", "world-v7.fbx", "world-v7-declutter.fbx",
    "world-v7-collision.fbx", "world-dressing.fbx", "textures/palette-roblox.png",
))


def sha(data):
    return hashlib.sha256(data).hexdigest()


def input_hashes(root):
    return {name: sha((root / name).read_bytes()) if (root / name).is_file() else None for name in INPUTS}


def validate(root, xml=None, lua=None):
    """Refuse stale sources before any pending/proof/runtime output mutation."""
    root = Path(root).resolve()
    try:
        proof = json.loads((root / PROOF).read_text(encoding="utf-8"))
        if proof.get("schemaVersion") != 1 or proof.get("nativePath") != NATIVE:
            raise ValueError("unknown native proof schema/path")
        project = json.loads((root / "default.project.json").read_text(encoding="utf-8-sig"))
        mount = project["tree"]["ServerStorage"]["WorldAssets"]
        if mount != {"$path": NATIVE}:
            raise ValueError("default.project must mount the exact native model only")
        native = (root / NATIVE).read_bytes()
        if len(native) != proof.get("nativeBytes") or sha(native) != proof.get("nativeSha256"):
            raise ValueError("native export bytes changed")
        actual = input_hashes(root)
        if proof.get("inputs") != actual:
            changed = [name for name in INPUTS if proof.get("inputs", {}).get(name) != actual[name]]
            raise ValueError("native input bindings changed: " + ", ".join(changed or ["input path set"]))
        for name, candidate, key in ((XML, xml, "xmlSha256"), (LUA, lua, "luaSha256")):
            existing = (root / name).read_bytes()
            if sha(existing) != proof.get(key):
                raise ValueError(name + " canonical bytes changed")
            if candidate is not None:
                data = candidate.encode("utf-8") if isinstance(candidate, str) else candidate
                if sha(data) != proof.get(key):
                    raise ValueError(name + " generated candidate differs from approved native checkpoint")
        return proof
    except (OSError, ValueError, KeyError, TypeError) as exc:
        raise RuntimeError("Native collision checkpoint stale; no canonical outputs may be written: " + str(exc)) from exc


def stage_directory(root, value):
    """Resolve links first: an artifacts alias into watched assets is still watched."""
    root = Path(root).resolve()
    target = Path(value).resolve()
    for forbidden in (root / "assets", root / "src"):
        forbidden = forbidden.resolve()
        if target == forbidden or forbidden in target.parents or target in forbidden.parents:
            raise ValueError("Native rebuild staging directory must be outside watched src/assets: " + str(target))
    for name in ("WorldAssets.rbxmx", "WorldV7Data.lua", "world-v7-pending.json"):
        child = target / name
        if child.resolve() != child:
            raise ValueError("Staged output must not be a link/alias: " + str(child))
    return target


def write_staged(root, directory, name, text):
    directory = stage_directory(root, directory)
    if name not in ("WorldAssets.rbxmx", "WorldV7Data.lua", "world-v7-pending.json"):
        raise ValueError("Unknown staged world output")
    directory.mkdir(parents=True, exist_ok=True)
    # Atomic replacement also avoids following an existing hardlink's contents.
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", newline="\n", dir=directory, delete=False) as stream:
        temporary = stream.name
        stream.write(text)
    os.replace(temporary, directory / name)


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", required=True)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    result = validate(args.root)
    print("Native collision checkpoint PASS", result["nativeSha256"], result["nativeBytes"], "bytes")
