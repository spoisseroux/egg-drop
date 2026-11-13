"""Remap the painted sky faces (assets/art-source/environment/sky) to Roblox's Sky convention.

generate_sky.py paints Rt looking +X, Lf looking -X, Up with image-up +Z and Dn with image-up -Z.
Checked in Studio with labelled faces (2026-11-12): Roblox shows SkyboxRt looking -X and SkyboxLf
looking +X, SkyboxUp with image-up +X / image-right -Z, SkyboxDn with image-up -X / image-right -Z.
Ft and Bk already match. Writes assets/world/sky/{day,night,dusk}/Sky_*.png for upload
(dusk: the locked-dusk faces from scripts/build_world_v7_sky_dusk.py, batch 2026-11-13).
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "art-source" / "environment" / "sky"
OUT = ROOT / "assets" / "world" / "sky"

for mode in ("day", "night", "dusk"):
    if not (SRC / mode / "Sky_Ft.png").exists():
        continue
    (OUT / mode).mkdir(parents=True, exist_ok=True)
    face = {k: np.asarray(Image.open(SRC / mode / f"Sky_{k}.png").convert("RGB")) for k in ("Bk", "Dn", "Ft", "Lf", "Rt", "Up")}
    out = {
        "Ft": face["Ft"], "Bk": face["Bk"],
        "Rt": face["Lf"], "Lf": face["Rt"],
        "Up": np.ascontiguousarray(face["Up"][:, ::-1].transpose(1, 0, 2)),
        "Dn": np.ascontiguousarray(face["Dn"][::-1, :].transpose(1, 0, 2)),
    }
    for k, img in out.items():
        Image.fromarray(img).save(OUT / mode / f"Sky_{k}.png")
print("wrote", OUT)
