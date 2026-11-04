import bpy
import math
import os
from mathutils import Matrix

OUTPUT = r"c:\Users\Administrator\Desktop\opencode\m-home-game-at-office\projects\last-light-3d\assets\models\towers\field_turret.glb"


def material(name: str, color: tuple[float, float, float, float], metallic: float = 0.2, roughness: float = 0.65, emission: tuple[float, float, float, float] | None = None):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = roughness
        if emission is not None:
            bsdf.inputs["Emission Color"].default_value = emission
            bsdf.inputs["Emission Strength"].default_value = 2.2
    return mat


def cube(name: str, size: tuple[float, float, float], location: tuple[float, float, float], mat, parent=None, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel > 0.0:
        modifier = obj.modifiers.new("SoftEdges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
    if parent:
        obj.parent = parent
        obj.matrix_parent_inverse = Matrix.Identity(4)
        obj.location = location
    else:
        obj.location = location
    return obj


def cylinder(name: str, radius: float, depth: float, location: tuple[float, float, float], mat, parent=None, vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    if parent:
        obj.parent = parent
        obj.matrix_parent_inverse = Matrix.Identity(4)
        obj.location = location
    else:
        obj.location = location
    return obj


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)

    dark = material("ShelterMetal", (0.13, 0.16, 0.14, 1.0), metallic=0.65, roughness=0.48)
    olive = material("FieldOlive", (0.30, 0.36, 0.27, 1.0), metallic=0.25, roughness=0.68)
    khaki = material("RepairPlates", (0.58, 0.52, 0.36, 1.0), metallic=0.35, roughness=0.58)
    amber = material("ReadyAmber", (0.86, 0.47, 0.13, 1.0), metallic=0.1, roughness=0.35, emission=(1.0, 0.28, 0.04, 1.0))
    barrel_mat = material("BarrelSteel", (0.08, 0.10, 0.09, 1.0), metallic=0.8, roughness=0.34)

    root = bpy.data.objects.new("FieldTurret", None)
    bpy.context.collection.objects.link(root)

    base = cylinder("Base", 0.78, 0.42, (0.0, 0.0, 0.21), dark, root)
    ring = cylinder("RotationRing", 0.66, 0.12, (0.0, 0.0, 0.47), khaki, root)
    cube("FrontPlate", (0.72, 0.16, 0.22), (0.0, -0.64, 0.38), olive, root, 0.04)
    cube("SidePlateL", (0.16, 0.72, 0.30), (-0.62, 0.0, 0.48), olive, root, 0.035)
    cube("SidePlateR", (0.16, 0.72, 0.30), (0.62, 0.0, 0.48), olive, root, 0.035)

    yaw = bpy.data.objects.new("YawPivot", None)
    bpy.context.collection.objects.link(yaw)
    yaw.parent = root
    yaw.matrix_parent_inverse = Matrix.Identity(4)
    yaw.location = (0.0, 0.0, 0.48)

    body = cube("TurretHousing", (0.92, 0.80, 0.48), (0.0, 0.0, 0.32), olive, yaw, 0.08)
    body.rotation_euler[2] = math.radians(-4.0)
    cube("ArmorTop", (0.72, 0.62, 0.12), (0.0, 0.0, 0.62), khaki, yaw, 0.035)
    cylinder("StatusLight", 0.09, 0.035, (0.0, -0.33, 0.50), amber, yaw, 12).rotation_euler[0] = math.radians(90.0)

    pitch = bpy.data.objects.new("PitchPivot", None)
    bpy.context.collection.objects.link(pitch)
    pitch.parent = yaw
    pitch.matrix_parent_inverse = Matrix.Identity(4)
    pitch.location = (0.0, 0.28, 0.40)

    for x in (-0.18, 0.18):
        # Godot aims along local +Z. Keep the barrel's native cylinder axis
        # on Z so YawPivot rotates the rifle naturally toward the target.
        barrel = cylinder("Barrel_L" if x < 0 else "Barrel_R", 0.075, 0.92, (x, 0.0, 0.42), barrel_mat, pitch, 12)
        muzzle = cylinder("Muzzle_L" if x < 0 else "Muzzle_R", 0.105, 0.10, (x, 0.0, 0.88), khaki, pitch, 12)

    cube("CableBlock", (0.24, 0.42, 0.18), (0.38, -0.42, 0.18), dark, yaw, 0.025)

    # Keep the model's local origin at ground level for Godot placement.
    root.location = (0.0, 0.0, 0.0)

    bpy.ops.object.select_all(action="DESELECT")
    # GLB export with use_selection only includes selected mesh descendants.
    # Select the complete hierarchy, not just the empty root.
    for obj in root.children_recursive:
        obj.select_set(True)
    root.select_set(True)
    bpy.context.view_layer.objects.active = root
    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=OUTPUT, export_format="GLB", use_selection=True, export_apply=True)
    print(f"EXPORTED {OUTPUT}")


if __name__ == "__main__":
    build()
