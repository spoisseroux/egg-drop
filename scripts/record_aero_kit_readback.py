"""Record the Aero world kit's upload readback for scripts/build_world_aero_kit_assets.py.

    python scripts/record_aero_kit_readback.py ASSET_ID OPERATION_ID MODERATION PARTS_JSON

PARTS_JSON: the list Studio Edit printed with InsertService:LoadAsset(ASSET_ID) ([{name, meshId, meshSize}]), as a
string or a path. The FBX and manifest digests are taken now, so record straight after the upload, before any rebuild:
the gate binds the readback to these files, and a rebuild in between would bind new files to the old ids. To guard that,
pass --uploaded SHA256 (the FBX digest taken before the upload) and the recorder refuses a different file. The model loaded in Studio is destroyed unparented; the place is never saved.
"""
import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

KIT = Path(__file__).resolve().parents[1] / "assets" / "world" / "aero-kit"


def main(argv):
    uploaded = None
    if "--uploaded" in argv:
        at = argv.index("--uploaded")
        uploaded = argv[at + 1]
        argv = argv[:at] + argv[at + 2:]
    if len(argv) != 4:
        print(__doc__)
        return 2
    asset, operation, moderation, parts = argv
    if uploaded and hashlib.sha256((KIT / "aero-kit.fbx").read_bytes()).hexdigest() != uploaded:
        raise SystemExit("aero-kit.fbx changed since the upload; rebuild, upload and record again")
    source = Path(parts)
    parts = json.loads(source.read_text() if source.exists() else parts)
    readback = {
        "assetId": asset, "operationId": operation, "moderation": moderation,
        "fbxSha256": hashlib.sha256((KIT / "aero-kit.fbx").read_bytes()).hexdigest(),
        "manifestSha256": hashlib.sha256((KIT / "aero-kit-manifest.json").read_bytes()).hexdigest(),
        "parts": parts,
        "provenance": {"recordedUtc": datetime.now(timezone.utc).isoformat(),
                       "note": "Open Cloud POST /assets/v1/assets (Model) through Studio MCP, operation polled to done; "
                               "MeshId/MeshSize read with InsertService:LoadAsset in Studio Edit, model destroyed "
                               "unparented, place not saved."}}
    (KIT / "aero-kit-readback.json").write_text(json.dumps(readback, indent=1), encoding="utf-8", newline="\n")
    print("recorded", len(parts), "parts for asset", asset)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
