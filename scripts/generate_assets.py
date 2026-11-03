import bpy
import math
import os
import sys

def hex_to_rgb(hex_str):
    hex_str = hex_str.lstrip('#')
    lv = len(hex_str)
    rgb = tuple(int(hex_str[i:i + lv // 3], 16) / 255.0 for i in range(0, lv, lv // 3))
    return (rgb[0], rgb[1], rgb[2], 1.0)

def create_material(name, color_hex, metallic=0.2, roughness=0.7, emission_hex=None, emission_strength=1.0):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = hex_to_rgb(color_hex)
        bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = roughness
        if emission_hex:
            if "Emission Color" in bsdf.inputs:
                bsdf.inputs["Emission Color"].default_value = hex_to_rgb(emission_hex)
                bsdf.inputs["Emission Strength"].default_value = emission_strength
            elif "Emission" in bsdf.inputs:
                bsdf.inputs["Emission"].default_value = hex_to_rgb(emission_hex)
    return mat

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def export_glb(filepath):
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=filepath,
        export_format='GLB',
        use_selection=False,
        export_apply=True
    )
    print(f"Exported: {filepath}")

# 1. sonic_resonator.glb
# ฐานเดียวกัน (Ø1.6 h0.5) + ขดลวด 2 วงซ้อน (torus Ø0.9/0.6) + จานกว้าง หน้าตัด 1.2
def build_sonic_resonator(out_path):
    clear_scene()
    base_mat = create_material("BaseMat", "#3f463c")
    coil_mat = create_material("CoilMat", "#8ea0b4", metallic=0.5, roughness=0.4)
    core_mat = create_material("CoreMat", "#e8a95c", emission_hex="#e8a95c", emission_strength=2.0)

    # Base cylinder (r=0.8, h=0.5 -> bottom at Y=0, center Z=0.25)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.8, depth=0.5, location=(0, 0, 0.25))
    base = bpy.context.active_object
    base.data.materials.append(base_mat)

    # Core pillar
    bpy.ops.mesh.primitive_cylinder_add(radius=0.25, depth=0.7, location=(0, 0, 0.6))
    core = bpy.context.active_object
    core.data.materials.append(core_mat)

    # Dish / Cone resonator at top
    bpy.ops.mesh.primitive_cone_add(radius1=0.6, radius2=0.2, depth=0.3, location=(0, 0, 1.05))
    dish = bpy.context.active_object
    dish.data.materials.append(coil_mat)

    # Torus 1 (Ø0.9 -> major radius 0.45, minor 0.08)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.45, minor_radius=0.07, location=(0, 0, 0.55))
    torus1 = bpy.context.active_object
    torus1.data.materials.append(coil_mat)

    # Torus 2 (Ø0.6 -> major radius 0.30, minor 0.06)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.30, minor_radius=0.06, location=(0, 0, 0.75))
    torus2 = bpy.context.active_object
    torus2.data.materials.append(coil_mat)

    export_glb(out_path)

# 2. tangle_emitter.glb
# ฐานเดียวกัน + เสาสั้นมน + ยอดสปริงแผ่หนามรอบวง (spike ring Ø0.9)
def build_tangle_emitter(out_path):
    clear_scene()
    base_mat = create_material("BaseMat", "#3f463c")
    spike_mat = create_material("SpikeMat", "#75654a", metallic=0.3)
    glow_mat = create_material("GlowMat", "#5a4f8a", emission_hex="#7b68ee", emission_strength=2.5)

    # Base cylinder
    bpy.ops.mesh.primitive_cylinder_add(radius=0.8, depth=0.5, location=(0, 0, 0.25))
    base = bpy.context.active_object
    base.data.materials.append(base_mat)

    # Pillar
    bpy.ops.mesh.primitive_cylinder_add(radius=0.35, depth=0.6, location=(0, 0, 0.6))
    pillar = bpy.context.active_object
    pillar.data.materials.append(spike_mat)

    # Central emitter orb
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.3, location=(0, 0, 0.95))
    orb = bpy.context.active_object
    orb.data.materials.append(glow_mat)

    # 6 spikes around orb
    for i in range(6):
        angle = i * (2.0 * math.pi / 6.0)
        sx = math.cos(angle) * 0.42
        sy = math.sin(angle) * 0.42
        bpy.ops.mesh.primitive_cone_add(radius1=0.08, depth=0.35, location=(sx, sy, 0.95), rotation=(math.pi/2, 0, angle + math.pi/2))
        spike = bpy.context.active_object
        spike.data.materials.append(spike_mat)

    export_glb(out_path)

# 3. drifter.glb (1.0 x 1.6 x 1.0)
def build_drifter(out_path):
    clear_scene()
    mat = create_material("DrifterMat", "#9ea395", roughness=0.8)
    eye_mat = create_material("DrifterEye", "#2a2d27")
    
    # Body centered at Z=0.8 so bottom at Z=0
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.8))
    body = bpy.context.active_object
    body.scale = (1.0, 1.0, 1.6)
    bpy.ops.object.transform_apply(scale=True)
    body.data.materials.append(mat)

    # Head cowl
    bpy.ops.mesh.primitive_cube_add(size=0.6, location=(0, 0.25, 1.3))
    head = bpy.context.active_object
    head.scale = (0.7, 0.6, 0.5)
    bpy.ops.object.transform_apply(scale=True)
    head.data.materials.append(eye_mat)

    export_glb(out_path)

# 4. skitter.glb (capsule 0.7x0.9 + 4 tiny insect legs)
def build_skitter(out_path):
    clear_scene()
    mat = create_material("SkitterMat", "#c8b367", roughness=0.6)
    leg_mat = create_material("SkitterLegs", "#4a4226")

    # Body capsule approximation: cylinder with spheres or stretched sphere
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.35, location=(0, 0, 0.5))
    body = bpy.context.active_object
    body.scale = (0.9, 1.1, 0.8)
    bpy.ops.object.transform_apply(scale=True)
    body.data.materials.append(mat)

    # 4 legs
    leg_coords = [(-0.35, 0.25), (0.35, 0.25), (-0.35, -0.25), (0.35, -0.25)]
    for lx, ly in leg_coords:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.05, depth=0.5, location=(lx * 1.3, ly * 1.2, 0.25), rotation=(0.3 if ly > 0 else -0.3, 0.4 if lx > 0 else -0.4, 0))
        leg = bpy.context.active_object
        leg.data.materials.append(leg_mat)

    export_glb(out_path)

# 5. dasher.glb (wedge 0.6 x 1.4 x 1.4)
def build_dasher(out_path):
    clear_scene()
    mat = create_material("DasherMat", "#bf6b4d", roughness=0.5)
    fin_mat = create_material("DasherFin", "#dd8564")

    # Wedge cone
    bpy.ops.mesh.primitive_cone_add(radius1=0.5, depth=1.4, location=(0, 0, 0.7), rotation=(math.pi/2, 0, 0))
    body = bpy.context.active_object
    body.scale = (0.6, 1.0, 1.2)
    bpy.ops.object.transform_apply(scale=True)
    body.data.materials.append(mat)

    # Fin
    bpy.ops.mesh.primitive_cube_add(size=0.1, location=(0, -0.3, 1.0))
    fin = bpy.context.active_object
    fin.scale = (0.4, 4.0, 3.0)
    bpy.ops.object.transform_apply(scale=True)
    fin.data.materials.append(fin_mat)

    export_glb(out_path)

# 6. warden.glb (boss 2.4 x 3.2 x 2.4 + arms + rift spike)
def build_warden(out_path):
    clear_scene()
    mat = create_material("WardenMat", "#8c333d", roughness=0.6)
    rift_mat = create_material("RiftMat", "#5a4f8a", emission_hex="#9370db", emission_strength=3.0)

    # Torso (Z=1.6 center)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 1.6))
    body = bpy.context.active_object
    body.scale = (2.2, 1.8, 2.4)
    bpy.ops.object.transform_apply(scale=True)
    body.data.materials.append(mat)

    # Left Arm
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-1.5, 0, 1.4))
    larm = bpy.context.active_object
    larm.scale = (0.7, 0.9, 1.8)
    bpy.ops.object.transform_apply(scale=True)
    larm.data.materials.append(mat)

    # Right Arm
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(1.5, 0, 1.4))
    rarm = bpy.context.active_object
    rarm.scale = (0.7, 0.9, 1.8)
    bpy.ops.object.transform_apply(scale=True)
    rarm.data.materials.append(mat)

    # Rift Horn / Spike on head
    bpy.ops.mesh.primitive_cone_add(radius1=0.4, depth=1.2, location=(0, 0, 3.2))
    horn = bpy.context.active_object
    horn.data.materials.append(rift_mat)

    export_glb(out_path)

# 7. shelter.glb (3.0 x 2.2 x 2.2 silo + antenna + lantern)
def build_shelter(out_path):
    clear_scene()
    silo_mat = create_material("ShelterSilo", "#6e5c40", roughness=0.8)
    metal_mat = create_material("ShelterMetal", "#4b4a42", metallic=0.7)
    lantern_mat = create_material("ShelterLantern", "#e8a95c", emission_hex="#ffaa33", emission_strength=3.5)

    # Main silo body
    bpy.ops.mesh.primitive_cylinder_add(radius=1.3, depth=2.0, location=(0, 0, 1.0))
    silo = bpy.context.active_object
    silo.data.materials.append(silo_mat)

    # Dome roof
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.3, location=(0, 0, 2.0))
    dome = bpy.context.active_object
    dome.scale = (1.0, 1.0, 0.5)
    bpy.ops.object.transform_apply(scale=True)
    dome.data.materials.append(silo_mat)

    # Antenna
    bpy.ops.mesh.primitive_cylinder_add(radius=0.06, depth=1.2, location=(0.6, 0.4, 2.8))
    ant = bpy.context.active_object
    ant.data.materials.append(metal_mat)

    # Amber Lantern
    bpy.ops.mesh.primitive_cube_add(size=0.35, location=(0, 0, 2.6))
    lantern = bpy.context.active_object
    lantern.data.materials.append(lantern_mat)

    export_glb(out_path)

if __name__ == "__main__":
    base_dir = r"c:\Users\Administrator\Desktop\opencode\m-home-game-at-office\projects\last-light-3d\assets\models"
    build_sonic_resonator(os.path.join(base_dir, "towers", "sonic_resonator.glb"))
    build_tangle_emitter(os.path.join(base_dir, "towers", "tangle_emitter.glb"))
    build_drifter(os.path.join(base_dir, "enemies", "drifter.glb"))
    build_skitter(os.path.join(base_dir, "enemies", "skitter.glb"))
    build_dasher(os.path.join(base_dir, "enemies", "dasher.glb"))
    build_warden(os.path.join(base_dir, "enemies", "warden.glb"))
    build_shelter(os.path.join(base_dir, "props", "shelter.glb"))
    print("ALL ASSETS BUILT SUCCESSFULLY")

