import bpy
import os
from mathutils import Matrix

OUT = r"c:\Users\Administrator\Desktop\opencode\m-home-game-at-office\projects\last-light-3d\assets\models\towers\arc_cannon.glb"

def mat(name, color, emission=None):
    m = bpy.data.materials.new(name=name)
    m.use_nodes = True
    b = m.node_tree.nodes.get('Principled BSDF')
    b.inputs['Base Color'].default_value = (*color, 1)
    b.inputs['Metallic'].default_value = 0.55
    b.inputs['Roughness'].default_value = 0.4
    if emission:
        b.inputs['Emission Color'].default_value = (*emission, 1)
        b.inputs['Emission Strength'].default_value = 3.0
    return m

def cyl(name, r, depth, loc, material, parent):
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=r, depth=depth, location=(0,0,0))
    o=bpy.context.object; o.name=name; o.data.materials.append(material); o.parent=parent; o.matrix_parent_inverse=Matrix.Identity(4); o.location=loc; return o

def cube(name, size, loc, material, parent):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0,0,0))
    o=bpy.context.object; o.name=name; o.dimensions=size; bpy.ops.object.transform_apply(location=False, rotation=False, scale=True); o.data.materials.append(material); o.parent=parent; o.matrix_parent_inverse=Matrix.Identity(4); o.location=loc; return o

bpy.ops.wm.read_factory_settings(use_empty=True)
metal=mat('ArcMetal',(0.12,0.14,0.2)); violet=mat('ArcViolet',(0.25,0.12,0.55), (0.45,0.08,1.0)); cyan=mat('ArcCore',(0.08,0.45,0.8),(0.05,0.55,1.0))
root=bpy.data.objects.new('ArcCannon',None); bpy.context.collection.objects.link(root)
cyl('Base',0.8,0.42,(0,0,0.21),metal,root)
yaw=bpy.data.objects.new('YawPivot',None); bpy.context.collection.objects.link(yaw); yaw.parent=root; yaw.matrix_parent_inverse=Matrix.Identity(4); yaw.location=(0,0,0.45)
cube('Housing',(1.0,0.85,0.55),(0,0,0.35),violet,yaw)
cyl('Core',0.22,0.7,(0,0,0.72),cyan,yaw)
pitch=bpy.data.objects.new('PitchPivot',None); bpy.context.collection.objects.link(pitch); pitch.parent=yaw; pitch.matrix_parent_inverse=Matrix.Identity(4); pitch.location=(0,0.8,0.55)
for x in (-0.22,0.22):
    cyl('ArcEmitter',0.10,1.1,(x,0,0.55),cyan,pitch)
ring=cyl('EmitterRing',0.62,0.08,(0,0,0.55),violet,pitch)

bpy.ops.object.select_all(action='DESELECT'); root.select_set(True)
for o in root.children_recursive: o.select_set(True)
bpy.context.view_layer.objects.active=root
os.makedirs(os.path.dirname(OUT),exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT,export_format='GLB',use_selection=True,export_apply=True)
print('EXPORTED',OUT)
