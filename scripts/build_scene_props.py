import bpy
import math
import os

BASE = r"c:\Users\Administrator\Desktop\opencode\m-home-game-at-office\projects\last-light-3d\assets\models\props"


def mat(name, color, metallic=0.0, roughness=0.7, emission=None):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1.0)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 2.0
    return m


def cube(name, size, loc, material, parent=None, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    o = bpy.context.object
    o.name = name
    o.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(material)
    if bevel:
        b = o.modifiers.new("Bevel", "BEVEL")
        b.width = bevel
        b.segments = 2
    if parent:
        o.parent = parent
    return o


def cyl(name, radius, depth, loc, material, parent=None, vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc)
    o = bpy.context.object
    o.name = name
    o.data.materials.append(material)
    if parent:
        o.parent = parent
    return o


def empty(name):
    o = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(o)
    return o


def export(root, filename):
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    bpy.context.view_layer.objects.active = root
    path = os.path.join(BASE, filename)
    os.makedirs(BASE, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True)
    print("EXPORTED", path)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def barricade():
    reset()
    metal = mat("BarricadeMetal", (0.16, 0.18, 0.16), 0.65, 0.48)
    warning = mat("WarningAmber", (0.75, 0.39, 0.10), 0.15, 0.48, (1.0, 0.18, 0.02))
    root = empty("Barricade")
    cube("Beam", (2.4, 0.18, 0.18), (0, 0, 0.85), warning, root, 0.03).rotation_euler[1] = math.radians(-8)
    for x in (-0.9, 0.9):
        leg = cube("Leg", (0.18, 0.55, 1.0), (x, 0, 0.45), metal, root, 0.03)
        leg.rotation_euler[1] = math.radians(-12 if x < 0 else 12)
    export(root, "barricade.glb")


def streetlight():
    reset()
    metal = mat("StreetMetal", (0.11, 0.14, 0.13), 0.7, 0.4)
    amber = mat("StreetLamp", (0.9, 0.48, 0.12), 0.05, 0.3, (1.0, 0.25, 0.03))
    root = empty("StreetLight")
    cyl("Pole", 0.08, 3.2, (0, 0, 1.6), metal, root)
    arm = cube("Arm", (0.85, 0.08, 0.08), (0.36, 0, 3.08), metal, root, 0.02)
    arm.rotation_euler[1] = math.radians(-12)
    cyl("Lamp", 0.18, 0.14, (0.72, 0, 2.94), amber, root, 12).rotation_euler[0] = math.radians(90)
    export(root, "street_light.glb")


def warning_sign():
    reset()
    metal = mat("SignMetal", (0.2, 0.22, 0.19), 0.5, 0.55)
    amber = mat("SignAmber", (0.82, 0.48, 0.14), 0.05, 0.45, (1.0, 0.2, 0.02))
    root = empty("Shelter09Sign")
    cyl("Post", 0.06, 1.8, (0, 0, 0.9), metal, root)
    board = cube("Shelter09", (1.4, 0.08, 0.62), (0, 0, 1.75), amber, root, 0.04)
    board.rotation_euler[1] = math.radians(-4)
    export(root, "shelter_09_sign.glb")


if __name__ == "__main__":
    barricade()
    streetlight()
    warning_sign()
