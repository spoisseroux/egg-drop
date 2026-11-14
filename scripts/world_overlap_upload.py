"""Fail-closed, no-delete verification of a world geometry upload checkpoint."""
import copy
import hashlib
import json
import math
import os
from pathlib import Path
import re
import tempfile


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def positive_id(value):
    text = str(value).removeprefix("rbxassetid://")
    if not re.fullmatch(r"[0-9]+", text) or int(text) <= 0:
        raise ValueError("Mesh/model ids must be positive decimal ids")
    return text


def import_row(value):
    if not isinstance(value, (list, tuple)) or len(value) != 4:
        raise ValueError("Import needs exactly id and three raw dimensions")
    result = [positive_id(value[0])]
    for size in value[1:]:
        if isinstance(size, bool) or not isinstance(size, (int, float)) or not math.isfinite(size) or size <= 0:
            raise ValueError("Mesh dimensions must be finite positive numbers")
        result.append(float(size))
    return result


def validate_proof(pending, manifest, canonical, proof, file_hashes):
    """Validate the complete receipt without mutating pending or any output file."""
    expected_list = pending["changed"] + pending.get("added", [])
    expected = set(expected_list)
    if len(expected_list) != len(expected):
        raise ValueError("Duplicate pending mesh names")
    parts = proof.get("parts")
    if not isinstance(parts, list) or any(not isinstance(row, dict) for row in parts):
        raise ValueError("Upload parts must be a list of rows")
    names = [row.get("name") for row in parts]
    if any(not isinstance(n, str) for n in names) or len(names) != len(set(names)) or set(names) != expected:
        raise ValueError("Upload names must exactly match pending, without duplicates, extras or omissions")
    asset = positive_id(proof.get("assetId"))
    operation = proof.get("operationId")
    if not isinstance(operation, str) or not re.fullmatch(r"[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}", operation):
        raise ValueError("Upload operation id must be a UUID")
    checkpoint = proof.get("checkpoint")
    if not isinstance(checkpoint, dict):
        raise ValueError("Upload needs an explicit FBX/manifest checkpoint")
    for key in ("fbxSha256", "manifestSha256"):
        value = checkpoint.get(key)
        if not isinstance(value, str) or not re.fullmatch("[0-9a-f]{64}", value) or value != file_hashes[key]:
            raise ValueError("Uploaded " + key + " does not match this geometry checkpoint")
    old_ids = checkpoint.get("previousMeshIds")
    if not isinstance(old_ids, dict) or set(old_ids) != set(pending["changed"]):
        raise ValueError("Checkpoint needs every previous changed MeshId")
    current = {part["name"]: part for part in manifest["parts"]}
    if len(current) != len(manifest["parts"]):
        raise ValueError("Manifest contains duplicate names")
    confirmed = {}
    for row in parts:
        name = row["name"]
        supplied = import_row([row.get("meshId")] + (row.get("meshSize") if isinstance(row.get("meshSize"), list) else []))
        target = import_row(canonical[name])
        # Raw sizes are checkpoint values, not tolerant authored dimensions.
        if supplied != target:
            raise ValueError(name + ": canonical id/raw size differs from upload proof")
        if name in pending["changed"] and supplied[0] == positive_id(old_ids[name]):
            raise ValueError(name + ": previous MeshId cannot confirm changed geometry")
        geom = current[name].get("hash")
        if not isinstance(geom, str) or not re.fullmatch(r"[0-9a-f]{16}", geom):
            raise ValueError(name + ": invalid current geometry hash")
        if name in pending["previous"] and geom == pending["previous"][name].get("hash"):
            raise ValueError(name + ": geometry has not changed from pending baseline")
        confirmed[name] = {"hash": geom, "import": target}
    result = copy.deepcopy(pending)
    result["note"] = "Verified world upload checkpoint; retain this file. Any changed geometry/import/file binding aborts runtime asset generation until a new upload is confirmed."
    result["confirmedImport"] = confirmed
    result["upload"] = dict(assetId=asset, operationId=operation, checkpoint=copy.deepcopy(checkpoint))
    return result


def is_confirmed(name, part, canonical, pending, file_hashes):
    """Recheck every binding; stale proof always falls back to the pending baseline."""
    try:
        upload = pending["upload"]
        positive_id(upload["assetId"])
        if not re.fullmatch(r"[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}", upload["operationId"]):
            return False
        checkpoint = upload["checkpoint"]
        if any(checkpoint.get(k) != file_hashes[k] for k in ("fbxSha256", "manifestSha256")):
            return False
        confirmation = pending["confirmedImport"][name]
        return (confirmation["hash"] == part.get("hash") and
                import_row(confirmation["import"]) == import_row(canonical[name]) and
                (name not in pending["changed"] or positive_id(canonical[name][0]) != positive_id(checkpoint["previousMeshIds"][name])))
    except (KeyError, TypeError, ValueError):
        return False


def atomic_write(path, pending):
    """One atomic replace after complete validation; never remove the pending file."""
    path = Path(path)
    payload = json.dumps(pending, indent=1)
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=path.parent, prefix=path.name + ".", suffix=".tmp", delete=False) as stream:
        stream.write(payload)
        stream.flush()
        os.fsync(stream.fileno())
        temporary = stream.name
    os.replace(temporary, path)
