"""cliff_den_sculpt's path maths (path_samples, _nearest, over_tread, ground) in plain Python, without Blender.

    import path_offline; S = path_offline.sculpt()

The module's spline needs only mathutils.Vector's +, -, *, unary - and lerp; its bpy / bmesh imports are used only by
its carving and building functions, never by the path maths. Outside Blender this puts stand-ins in sys.modules for
those three before importing it (inside Blender, the real ones). Used by build_world_finish_pack.py (beta 42 E21: the
foot rocks' boxes kept off the tread) and check_world_finish_path.py --boxes.
"""
from __future__ import annotations

import sys
import types
from pathlib import Path


class Vector(tuple):
    def __new__(cls, v):
        return tuple.__new__(cls, (float(x) for x in v))

    def __add__(self, o):
        return Vector(a + b for a, b in zip(self, o))

    def __sub__(self, o):
        return Vector(a - b for a, b in zip(self, o))

    def __neg__(self):
        return Vector(-a for a in self)

    def __mul__(self, k):
        return Vector(a * k for a in self)

    __rmul__ = __mul__

    def lerp(self, o, f):
        return Vector(a + (b - a) * f for a, b in zip(self, o))


def sculpt():
    if "bpy" not in sys.modules:
        for name in ("bpy", "bmesh"):
            sys.modules.setdefault(name, types.ModuleType(name))
        sys.modules.setdefault("mathutils", types.ModuleType("mathutils")).Vector = Vector
    here = str(Path(__file__).resolve().parent)
    if here not in sys.path:
        sys.path.insert(0, here)
    import cliff_den_sculpt
    return cliff_den_sculpt
