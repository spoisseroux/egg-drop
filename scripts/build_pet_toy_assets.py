"""Writes assets/toys/PetToyAssets.rbxmx (ReplicatedStorage.PetToyAssets in default.project.json):
one template MeshPart per toy mesh, cloned by src/client/PetToyGeometry.lua. The mesh ids
and imported sizes come from assets/art-source/toys/pet-toys-meshids.json, written after
uploading pet-toys.fbx (scripts/build_pet_toys.py).

Usage (from the repo root): python scripts/build_pet_toy_assets.py
"""
import json
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SOURCE = os.path.join(ROOT, "assets", "art-source", "toys", "pet-toys-meshids.json")
OUT = os.path.join(ROOT, "assets", "toys", "PetToyAssets.rbxmx")

PART = """    <Item class="MeshPart" referent="{name}">
      <Properties>
        <string name="Name">{name}</string>
        <Content name="MeshId">
          <url>{mesh}</url>
        </Content>
        <Content name="TextureID">
          <url />
        </Content>
        <Vector3 name="Size">
          <X>{x}</X>
          <Y>{y}</Y>
          <Z>{z}</Z>
        </Vector3>
        <Vector3 name="InitialSize">
          <X>{x}</X>
          <Y>{y}</Y>
          <Z>{z}</Z>
        </Vector3>
        <CoordinateFrame name="CFrame">
          <X>0</X>
          <Y>0</Y>
          <Z>0</Z>
          <R00>1</R00>
          <R01>0</R01>
          <R02>0</R02>
          <R10>0</R10>
          <R11>1</R11>
          <R12>0</R12>
          <R20>0</R20>
          <R21>0</R21>
          <R22>1</R22>
        </CoordinateFrame>
        <bool name="Anchored">true</bool>
        <bool name="CanCollide">false</bool>
        <bool name="CanTouch">false</bool>
        <bool name="CanQuery">false</bool>
        <bool name="CastShadow">false</bool>
        <token name="CollisionFidelity">1</token>
      </Properties>
    </Item>
"""


def main():
    data = json.load(open(SOURCE, encoding="utf-8"))
    rows = ['<roblox version="4">\n  <Item class="Folder" referent="PetToyAssets">\n    <Properties>\n'
            '      <string name="Name">PetToyAssets</string>\n    </Properties>\n']
    for name in sorted(data["meshes"]):
        mesh, size = data["meshes"][name]
        rows.append(PART.format(name=name, mesh=mesh, x=size[0], y=size[1], z=size[2]))
    rows.append("  </Item>\n</roblox>\n")
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("".join(rows))
    print("wrote", OUT, len(data["meshes"]), "meshes")


if __name__ == "__main__":
    main()
