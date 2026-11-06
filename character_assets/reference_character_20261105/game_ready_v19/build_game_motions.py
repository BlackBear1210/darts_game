"""v18 캐릭터에 게임용 모션을 더해 game_ready_v19 를 만든다. v18 원본은 바꾸지 않는다.

실행: blender -b <v18 character_animated.blend> --python build_game_motions.py -- <출력 폴더> <게임 GLB 경로>
좌표: 앞 = +Y, 캐릭터 왼쪽 = -X, 위 = +Z. 게임 의자 높이에 맞게 앉기 모션의 다리를 다시 계산한다.
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Quaternion, Vector

args = sys.argv[sys.argv.index("--") + 1:]
out_dir, game_glb = Path(args[0]), Path(args[1])
out_dir.mkdir(parents=True, exist_ok=True)
game_glb.parent.mkdir(parents=True, exist_ok=True)

SEAT_LIFT = 0.17            # 게임 의자 윗면 0.6m - v18 앉기 기준 0.43m
HIP_REST_Z = 0.87
SEATED_DROP = 0.35
SEAT_BACK = 0.26            # v18 앉기에서 골반이 뒤로 가는 거리. 게임은 스툴 중심이 캐릭터 원점이다
WALK_FRAMES = 24
CROUCH_DROP = 0.42
SLEEVE_X = 0.2              # 셔츠에서 이보다 바깥(|x|)은 소매다
CROUCH_LEAN = 0.5
FINGERS = ("thumb", "index", "middle", "ring", "pinky")
KEEP_CLIPS = {"Idle", "Dart_Throw", "Card_Hold_L", "Look_Left", "Look_Right", "Look_Down"}

arm = bpy.data.objects["Character_Rig"]
scene = bpy.context.scene
pose = arm.pose.bones
if arm.animation_data is None:
    arm.animation_data_create()


def use_action(action):
    arm.animation_data.action = action
    if action is not None and getattr(arm.animation_data, "action_slot", None) is None and len(action.slots):
        arm.animation_data.action_slot = action.slots[0]


def read_pose(action, frame):
    """action 의 frame 자세를 뼈별 값으로 읽는다."""
    use_action(action)
    scene.frame_set(frame)
    bpy.context.view_layer.update()
    return {b.name: (b.location.copy(), b.rotation_quaternion.copy(), b.scale.copy()) for b in pose}


def set_pose(values):
    for name, (location, rotation, scale) in values.items():
        bone = pose[name]
        bone.location = location
        bone.rotation_quaternion = rotation
        bone.scale = scale
    bpy.context.view_layer.update()


def snapshot():
    return {b.name: (b.location.copy(), b.rotation_quaternion.copy(), b.scale.copy()) for b in pose}


def set_matrix(bone, matrix):
    bone.matrix = matrix
    bpy.context.view_layer.update()


def aim(bone, direction):
    """뼈 방향(머리 → 꼬리)을 direction 으로 돌린다. 시작점은 그대로다."""
    current = bone.matrix.col[1].xyz.normalized()
    turn = current.rotation_difference(direction.normalized()).to_matrix().to_4x4()
    matrix = bone.matrix.copy()
    head = matrix.translation.copy()
    matrix.translation = (0, 0, 0)
    matrix = turn @ matrix
    matrix.translation = head
    set_matrix(bone, matrix)


def turn(bone, axis, angle):
    """뼈를 시작점 기준으로 axis(아마추어 공간) 둘레로 돌린다."""
    matrix = bone.matrix.copy()
    head = matrix.translation.copy()
    matrix.translation = (0, 0, 0)
    matrix = Matrix.Rotation(angle, 4, axis) @ matrix
    matrix.translation = head
    set_matrix(bone, matrix)


def two_bone(upper, lower, target, pole):
    """upper·lower 두 뼈로 target 에 닿게 한다. pole 쪽으로 관절이 꺾인다."""
    start = upper.head.copy()
    first = (lower.head - upper.head).length
    second = (lower.tail - lower.head).length if lower.name.startswith("forearm") else None
    if second is None:
        second = (pose["foot" + lower.name[4:]].head - lower.head).length
    to_target = target - start
    distance = min(to_target.length, (first + second) * 0.999)
    forward = to_target.normalized()
    along = (first * first - second * second + distance * distance) / (2 * distance)
    height = math.sqrt(max(first * first - along * along, 0.0))
    bend = (pole - forward * pole.dot(forward)).normalized()
    joint = start + forward * along + bend * height
    aim(upper, joint - start)
    aim(lower, (start + forward * distance) - lower.head)


def add_root(offset):
    """root 를 아마추어 공간에서 옮긴다."""
    matrix = pose["root"].matrix.copy()
    matrix.translation += offset
    set_matrix(pose["root"], matrix)


def smooth(t):
    return t * t * (3 - 2 * t)


def write_clip(name, frames):
    """frames(자세 목록)를 새 동작으로 저장한다."""
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    use_action(None)
    arm.animation_data.action = action
    for index, values in enumerate(frames):
        for bone_name, (location, rotation, scale) in values.items():
            bone = pose[bone_name]
            bone.location = location
            bone.rotation_quaternion = rotation
            bone.scale = scale
            bone.keyframe_insert("location", frame=index, group=bone_name)
            bone.keyframe_insert("rotation_quaternion", frame=index, group=bone_name)
            bone.keyframe_insert("scale", frame=index, group=bone_name)
    action.use_frame_range = True
    action.frame_start = 0
    action.frame_end = len(frames) - 1
    use_action(None)
    return action


idle = bpy.data.actions["Idle"]
grip = bpy.data.actions["Hand_Grip"]
idle_pose = read_pose(idle, 0)
fist_pose = read_pose(grip, 12)
use_action(None)
set_pose(idle_pose)
FOOT_REST = {side: pose["foot." + side].head.copy() for side in "LR"}
FOOT_MATRIX = {side: pose["foot." + side].matrix.copy() for side in "LR"}
LEG_POLE = {"L": Vector((-0.12, 1, 0)), "R": Vector((0.12, 1, 0))}


def place_feet(targets, pitches):
    """두 발을 목표 위치로 옮긴다. 발 각도는 서 있는 자세에서 pitch 만큼 앞뒤로 기울인다."""
    for side in "LR":
        two_bone(pose["thigh." + side], pose["shin." + side], targets[side], LEG_POLE[side])
        matrix = Matrix.Rotation(pitches[side], 4, "X") @ FOOT_MATRIX[side]
        matrix.translation = pose["foot." + side].head.copy()
        set_matrix(pose["foot." + side], matrix)


def stride(t, reach, lift):
    """보행 한 주기(t 0~1)의 발 위치(앞뒤, 높이)와 기울기. 앞쪽 절반은 땅을 딛고 뒤로 민다."""
    if t < 0.5:
        return reach * (1 - 4 * t), 0.0, 0.18 - 0.75 * smooth(t * 2)
    u = (t - 0.5) * 2
    return -reach + 2 * reach * smooth(u), lift * math.sin(math.pi * u), -0.57 + 0.75 * smooth(u)


def walk_frames(reach, lift, drop, lean, width):
    frames = []
    for frame in range(WALK_FRAMES + 1):
        t = frame / WALK_FRAMES
        wave = 2 * math.pi * t
        set_pose(idle_pose)
        add_root(Vector((0, 0, -drop - 0.012 * math.cos(2 * wave))))
        turn(pose["hips"], "Z", 0.10 * math.cos(wave))
        turn(pose["spine"], "X", -lean)
        turn(pose["chest"], "Z", -0.18 * math.cos(wave))
        turn(pose["neck"], "Z", 0.05 * math.cos(wave))
        turn(pose["neck"], "X", lean * 0.7)
        targets, pitches = {}, {}
        for side, shift, sign in (("L", 0.0, -1), ("R", 0.5, 1)):
            y, z, pitch = stride((t + shift) % 1.0, reach, lift)
            targets[side] = Vector((sign * width, FOOT_REST[side].y + y, FOOT_REST[side].z + z))
            pitches[side] = pitch
        place_feet(targets, pitches)
        for side, sign in (("L", -1), ("R", 1)):
            swing = sign * 0.42 * math.cos(wave)
            turn(pose["upper_arm." + side], "X", swing)
            turn(pose["forearm." + side], "X", 0.28 + 0.2 * max(swing, 0.0))
        frames.append(snapshot())
    return frames


def crouch_frames():
    frames = []
    for frame in range(31):
        wave = 2 * math.pi * frame / 30
        set_pose(idle_pose)
        add_root(Vector((0, 0.02, -CROUCH_DROP - 0.006 * math.sin(wave))))
        turn(pose["spine"], "X", -CROUCH_LEAN)
        turn(pose["neck"], "X", CROUCH_LEAN * 0.85)
        place_feet({s: FOOT_REST[s] for s in "LR"}, {"L": 0.0, "R": 0.0})
        for side in "LR":
            turn(pose["upper_arm." + side], "X", 0.25)
            turn(pose["forearm." + side], "X", 0.45)
        frames.append(snapshot())
    return frames


def fingers_from(values, side, skip=()):
    for name, value in values.items():
        if name.endswith("." + side) and name.split("_")[0] in FINGERS and name.split("_")[0] not in skip:
            pose[name].rotation_quaternion = value[1]
    bpy.context.view_layer.update()


def cheer_frames():
    set_pose(idle_pose)
    for side, sign in (("L", -1), ("R", 1)):
        aim(pose["upper_arm." + side], Vector((sign * 0.8, 0.12, 0.58)))
        aim(pose["forearm." + side], Vector((sign * 0.28, 0.14, 0.95)))
        aim(pose["hand." + side], Vector((sign * 0.12, 0.1, 0.99)))
    return [snapshot(), snapshot()]


def point_frames():
    set_pose(idle_pose)
    aim(pose["upper_arm.R"], Vector((0.1, 0.97, 0.16)))
    aim(pose["forearm.R"], Vector((0.02, 0.99, 0.1)))
    aim(pose["hand.R"], Vector((0.0, 0.99, 0.08)))
    fingers_from(fist_pose, "R", skip=("index",))
    return [snapshot(), snapshot()]


def drink_frames():
    set_pose(idle_pose)
    two_bone(pose["upper_arm.R"], pose["forearm.R"], Vector((0.1, 0.27, 1.34)), Vector((0.8, -0.2, -0.6)))
    aim(pose["hand.R"], Vector((-0.75, 0.5, 0.25)))
    fingers_from(fist_pose, "R")
    return [snapshot(), snapshot()]


def wheel_frames():
    set_pose(idle_pose)
    for side, sign in (("L", -1), ("R", 1)):
        aim(pose["upper_arm." + side], Vector((sign * 0.85, 0.0, 0.52)))
        aim(pose["forearm." + side], Vector((sign * 0.72, 0.0, 0.7)))
        aim(pose["hand." + side], Vector((sign * 0.7, 0.0, 0.72)))
        aim(pose["thigh." + side], Vector((sign * 0.34, 0.0, -0.94)))
        aim(pose["shin." + side], Vector((sign * 0.34, 0.0, -0.94)))
    return [snapshot(), snapshot()]


def jump_frames():
    """Jump 에서 root 의 높이 이동만 뺀다. 높이는 게임 물리가 만든다."""
    action = bpy.data.actions["Jump"]
    frames = []
    for frame in range(int(action.frame_range[0]), int(action.frame_range[1]) + 1):
        values = read_pose(action, frame)
        location, rotation, scale = values["root"]
        values["root"] = (idle_pose["root"][0].copy(), rotation, scale)
        frames.append(values)
    use_action(None)
    return frames


def seat_frames(name):
    """앉기 모션의 골반을 의자 높이만큼 올리고 발이 바닥에 남도록 다리를 다시 푼다."""
    action = bpy.data.actions[name]
    source = []
    for frame in range(int(action.frame_range[0]), int(action.frame_range[1]) + 1):
        values = read_pose(action, frame)
        feet = {s: (pose["foot." + s].head.copy(), pose["foot." + s].matrix.copy()) for s in "LR"}
        source.append((values, feet, pose["hips"].head.z))
    use_action(None)
    frames = []
    for values, feet, hip_z in source:
        set_pose(values)
        amount = min(max((HIP_REST_Z - hip_z) / SEATED_DROP, 0.0), 1.0)
        forward = Vector((0, SEAT_BACK * amount, 0))
        add_root(forward + Vector((0, 0, SEAT_LIFT * amount)))
        for side in "LR":
            pole = LEG_POLE[side] + Vector((0, 0, 0.3))
            two_bone(pose["thigh." + side], pose["shin." + side], feet[side][0] + forward, pole)
            matrix = feet[side][1].copy()
            matrix.translation = pose["foot." + side].head.copy()
            set_matrix(pose["foot." + side], matrix)
        frames.append(snapshot())
    return frames


use_action(None)
clips = {
    "Walk": walk_frames(0.24, 0.11, 0.05, 0.08, 0.115),
    "Crouch_Walk": walk_frames(0.18, 0.06, CROUCH_DROP, CROUCH_LEAN, 0.16),
    "Crouch_Idle": crouch_frames(),
    "Cheer": cheer_frames(),
    "Point_R": point_frames(),
    "Drink_R": drink_frames(),
    "Wheel_Spread": wheel_frames(),
    "Jump_Air": jump_frames(),
    "Sit_Stool": seat_frames("Sit_Down"),
    "Seated_Stool": seat_frames("Seated_Idle"),
    "Stand_Stool": seat_frames("Stand_Up"),
}
for name, frames in clips.items():
    write_clip(name, frames)
    print("CLIP", name, len(frames))


def fix_sleeves():
    """소매 끝 꼭짓점 일부가 몸통 뼈를 따라가 팔을 들면 뾰족하게 남는다. 그 몫을 윗팔로 옮긴다."""
    top = bpy.data.objects["Top_Reference"]
    body = {top.vertex_groups[name].index: top.vertex_groups[name] for name in ("hips", "spine", "chest")}
    for side, sign in (("L", -1), ("R", 1)):
        arm_group = top.vertex_groups["upper_arm." + side]
        for vertex in top.data.vertices:
            if vertex.co.x * sign < SLEEVE_X:
                continue
            moved = 0.0
            for link in list(vertex.groups):
                if link.group in body:
                    moved += link.weight
                    body[link.group].remove([vertex.index])
            if moved > 0.0:
                arm_group.add([vertex.index], moved, "ADD")


fix_sleeves()
for action in list(bpy.data.actions):
    if action.name not in KEEP_CLIPS and action.name not in clips:
        bpy.data.actions.remove(action)
use_action(None)
set_pose(idle_pose)
for name in ("Card_Preview", "Dart_Preview"):
    obj = bpy.data.objects.get(name)
    if obj is not None:
        bpy.data.objects.remove(obj, do_unlink=True)

bpy.ops.wm.save_as_mainfile(filepath=str(out_dir / "character_game.blend"), copy=True)
for obj in bpy.data.objects:
    obj.hide_viewport = False
    obj.hide_set(False)
bpy.ops.export_scene.gltf(filepath=str(game_glb), export_format="GLB", export_animations=True, export_animation_mode="ACTIONS",
                          export_force_sampling=True, export_frame_step=1, export_skins=True, export_def_bones=False,
                          export_apply=False, export_yup=True, export_cameras=False, export_lights=False)
print("EXPORTED", game_glb, sorted(a.name for a in bpy.data.actions))
