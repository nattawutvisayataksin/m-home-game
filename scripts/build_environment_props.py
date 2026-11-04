import bpy
import math
import os
from mathutils import Matrix

BASE = r"c:\Users\Administrator\Desktop\opencode\m-home-game-at-office\projects\last-light-3d\assets\models\props"


def material(name, color, metallic=0.0, roughness=0.75, emission=None):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 1.4
    return mat


def root_node(name):
    root = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(root)
    return root


def cube(name, size, location, mat, parent, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.0, 0.0))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    obj.parent = parent
    obj.matrix_parent_inverse = Matrix.Identity(4)
    obj.location = location
    if bevel:
        modifier = obj.modifiers.new("SoftEdges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
    return obj


def cylinder(name, radius, depth, location, mat, parent, vertices=10):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=(0.0, 0.0, 0.0))
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    obj.parent = parent
    obj.matrix_parent_inverse = Matrix.Identity(4)
    obj.location = location
    return obj


def cone(name, radius, depth, location, mat, parent, vertices=8):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius, radius2=0.04, depth=depth, location=(0.0, 0.0, 0.0))
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    obj.parent = parent
    obj.matrix_parent_inverse = Matrix.Identity(4)
    obj.location = location
    return obj


def export(root, filename):
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for child in root.children_recursive:
        child.select_set(True)
    bpy.context.view_layer.objects.active = root
    path = os.path.join(BASE, filename)
    os.makedirs(BASE, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True)
    print("EXPORTED", path)


def build_tree():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    trunk = material("DeadTrunk", (0.18, 0.13, 0.09), roughness=0.9)
    leaf = material("AshLeaves", (0.17, 0.25, 0.18), roughness=0.95)
    rust = material("RustBand", (0.42, 0.18, 0.10), metallic=0.25, roughness=0.75)
    root = root_node("AshTree")
    cylinder("Trunk", 0.28, 3.4, (0, 0, 1.7), trunk, root, 8)
    cylinder("RustBand", 0.31, 0.12, (0, 0, 1.05), rust, root, 8)
    for index, (x, y, z, scale) in enumerate([
        (-0.55, 0.0, 3.0, 0.72), (0.55, 0.0, 3.15, 0.62),
        (0.0, 0.2, 3.7, 0.68), (-0.2, -0.1, 4.25, 0.46),
    ]):
        crown = cone("AshCrown_%d" % index, 0.85 * scale, 1.55 * scale, (x, y, z), leaf, root, 7)
        crown.rotation_euler[1] = math.radians((-12 if index % 2 == 0 else 12))
    export(root, "ash_tree.glb")


def build_house():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    wall = material("HouseWall", (0.29, 0.28, 0.23), roughness=0.9)
    roof = material("HouseRoof", (0.12, 0.14, 0.13), metallic=0.2, roughness=0.95)
    wood = material("HouseWood", (0.22, 0.16, 0.11), roughness=0.9)
    glow = material("DeadWindow", (0.66, 0.3, 0.08), roughness=0.5, emission=(0.9, 0.18, 0.02))
    root = root_node("RuinedHouse")
    cube("HouseBody", (4.2, 3.2, 2.8), (0, 0, 1.4), wall, root, 0.08)
    roof_obj = cube("CollapsedRoof", (4.7, 3.7, 0.35), (0, 0, 3.0), roof, root, 0.06)
    roof_obj.rotation_euler[1] = math.radians(-7)
    cube("Door", (0.85, 0.12, 1.55), (0, -1.63, 0.78), wood, root, 0.02)
    for x in (-1.2, 1.2):
        cube("Window", (0.72, 0.10, 0.72), (x, -1.64, 1.65), glow, root, 0.02)
        cube("WindowBar", (0.08, 0.13, 0.82), (x, -1.71, 1.65), wood, root, 0.01)
        cube("WindowBar", (0.82, 0.13, 0.08), (x, -1.71, 1.65), wood, root, 0.01)
    cube("Rubble", (1.5, 1.0, 0.55), (2.0, -1.8, 0.28), roof, root, 0.08)
    export(root, "ruined_house.glb")


if __name__ == "__main__":
    build_tree()
    build_house()
