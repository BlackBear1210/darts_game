extends RefCounted
## Contact frames are expressed in the approved skin's hand space.
const Grip = preload("res://art/characters/approved_dart_grip.gd")
const HANDLE := Vector3(0.108, 0.016, 0)
const PINCH := Vector3(0.042718, 0.100762, 0.070292)
static var meshes := {}
var rig: Skeleton3D
var body: MeshInstance3D
var left_palm: Basis
var hand_l: int
var chest: int
var hand_r: int
var card := 0.0
var dart := 0.0
var mug := 0.0
var mug_frame := Transform3D.IDENTITY
var fan: Node3D
var projectile: DartView
var large := false
var pitch := 0.0

func _init(skeleton: Skeleton3D, model: Node3D):
	rig = skeleton
	body = model.find_child("Body", true, false)
	chest = rig.find_bone("chest")
	hand_l = rig.find_bone("hand.L")
	hand_r = rig.find_bone("hand.R")
	var r := rig.get_bone_global_rest(hand_r)
	var l := rig.get_bone_global_rest(hand_l)
	left_palm = l.basis.inverse() * Basis.from_scale(Vector3(-1,1,1)) * r.basis * Grip.PALM
	var key := body.mesh.get_instance_id()
	if not meshes.has(key):
		var mesh := ArrayMesh.new()
		for shape in ["RightGrip","LeftPinch","RightLarge"]:
			mesh.add_blend_shape(shape)
		mesh.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
		for i in range(body.mesh.get_surface_count()):
			var a := body.mesh.surface_get_arrays(i)
			Grip.bind_thumb(a,body.skin,r)
			var shapes: Array[Array] = [Grip.surface_pose(a,body.skin,r,false),
				Grip.surface_pose(a,body.skin,l,false,&"hand.L",left_palm),Grip.surface_pose(a,body.skin,r,true)]
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a,shapes,{},body.mesh.surface_get_format(i) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
			mesh.surface_set_material(i,body.mesh.surface_get_material(i))
		meshes[key] = mesh
	body.mesh = meshes[key]

func enable_dart(model: Node3D, color: Color):
	projectile = preload("res://game/dart/dart.tscn").instantiate()
	model.add_child(projectile)
	projectile.paint(color)
	projectile.hide()

func apply(layer: SkeletonModifier3D):
	var left := rig.get_bone_parent(hand_l)
	if card > 0.001:
		var chest_turn := (rig.get_bone_global_pose(chest).basis * rig.get_bone_global_rest(chest).basis.inverse()).orthonormalized()
		layer._aim(rig,rig.get_bone_parent(left),left,chest_turn*Vector3(-0.41,-1,-0.34),card)
		layer._aim(rig,left,hand_l,chest_turn*Vector3(0.48,0.25,-0.66),card)
		_roll_palm(left,hand_l,left_palm,Vector3.UP,card)
		var hand := rig.get_bone_global_pose(hand_l)
		if is_instance_valid(fan):
			# A slight turn toward the holder keeps the tilted edge visible in profile.
			var basis := chest_turn * Basis(Vector3.UP, deg_to_rad(6.0)) * Basis(Vector3.RIGHT, deg_to_rad(-23.0))
			fan.global_transform = rig.global_transform * Transform3D(basis,hand*(left_palm*PINCH)-basis.y*0.066)
	var right := rig.get_bone_parent(hand_r)
	if mug > 0.001:
		var target := rig.global_transform.affine_inverse() * (mug_frame * HANDLE)
		var pinch := Grip.PALM * PINCH
		var wrist := rig.get_bone_global_pose(hand_r).origin
		var contact := rig.get_bone_global_pose(hand_r)*pinch
		# Blend the contact point once. Correct the residual after rolling the forearm.
		var goal := contact.lerp(target,mug)
		for i in range(10):
			wrist += (goal-contact)*0.75
			_reach(layer,right,wrist,mug)
			_roll_palm(right,hand_r,Grip.PALM,Vector3.UP,mug)
			contact = rig.get_bone_global_pose(hand_r)*pinch
			if goal.distance_squared_to(contact)<0.000001: break

	if dart > 0.001:
		var shaft := Basis(Vector3.RIGHT,pitch).z
		var grip := Grip.barrel(large)
		var dir := (rig.get_bone_global_pose(hand_r).origin-rig.get_bone_global_pose(right).origin).normalized()
		var axis := (shaft-dir*shaft.dot(dir)).normalized()
		var local_axis := grip.basis.z.slide(Vector3.UP).normalized()
		var turn := Basis(axis,dir,axis.cross(dir))*Basis(local_axis,Vector3.UP,local_axis.cross(Vector3.UP)).inverse()
		_orient(right,hand_r,turn,dart)
	if is_instance_valid(projectile):
		projectile.visible = dart > 0.01
		if projectile.visible:
			var grip := rig.get_bone_global_pose(hand_r)*Grip.barrel(large)
			var scale_factor := DartView.LARGE_SIZE if large else 1.0
			grip.basis = Basis(Vector3.RIGHT,pitch).scaled(Vector3.ONE*scale_factor)
			projectile.global_transform = rig.global_transform*grip.translated_local(Vector3(0,0,-0.045))
	body.set_blend_shape_value(0,maxf(mug,dart if not large else 0.0))
	body.set_blend_shape_value(1,card)
	body.set_blend_shape_value(2,dart if large else 0.0)

func _orient(fore: int, hand: int, target: Basis, amount: float):
	# Carry the roll on the forearm; preserve its longitudinal axis.
	var current := rig.get_bone_global_pose(fore).basis
	var twist := target * rig.get_bone_rest(hand).basis.inverse()
	var aligned := Basis(Quaternion(twist.y.normalized(),current.y.normalized()))*twist
	var parent := rig.get_bone_global_pose(rig.get_bone_parent(fore)).basis
	rig.set_bone_pose_rotation(fore,rig.get_bone_pose_rotation(fore).slerp((parent.inverse()*aligned).orthonormalized().get_rotation_quaternion(),amount))
	var local := rig.get_bone_global_pose(fore).basis.inverse()*target
	rig.set_bone_pose_rotation(hand,rig.get_bone_pose_rotation(hand).slerp(local.orthonormalized().get_rotation_quaternion(),amount))

func _roll_palm(fore: int, hand: int, palm: Basis, up: Vector3, amount: float):
	var dir := (rig.get_bone_global_pose(hand).origin-rig.get_bone_global_pose(fore).origin).normalized()
	var thumb := up.slide(dir).normalized()
	if thumb.length_squared()<0.1: return
	_orient(fore,hand,Basis(thumb,dir,thumb.cross(dir)*signf(palm.determinant()))*palm.inverse(),amount)

func _reach(layer: SkeletonModifier3D, fore: int, target: Vector3, amount: float):
	var upper := rig.get_bone_parent(fore)
	var shoulder := rig.get_bone_global_pose(upper).origin
	var elbow := rig.get_bone_global_pose(fore).origin
	var a := shoulder.distance_to(elbow)
	var b := elbow.distance_to(rig.get_bone_global_pose(hand_r).origin)
	var axis := shoulder.direction_to(target)
	var d := clampf(shoulder.distance_to(target),absf(a-b)+0.001,a+b-0.001)
	var along := (a*a-b*b+d*d)/(2*d)
	var pole := Vector3(0.40,-1,0.3).slide(axis).normalized()
	layer._aim(rig,upper,fore,axis*along+pole*sqrt(maxf(0,a*a-along*along)),amount)
	layer._aim(rig,fore,hand_r,target-rig.get_bone_global_pose(fore).origin,amount)
