extends RefCounted
## 승인 몸의 긴 목·큰 손에 맞춘 자세 제약. 원본 메시/기본 자세는 바꾸지 않는다.
## 팔은 현재 팔꿈치가 굽는 평면을 유지하며 옷 바깥으로만 옮긴다.
var _rig: Skeleton3D
var _neck: int
var _head: int
var _arms: Array = []
var _capsules: Array = []
var _world_capsules: Array = []
var _legs:Array=[]
var _physical_fall:bool=false
static var _bounds_cache:Dictionary={}
const NECK_LIMIT: float = 0.18
const WRIST_LIMIT: float = 1.13

func _init(rig: Skeleton3D,model:Node3D,physical_fall:bool=false) -> void:
	_rig=rig
	_physical_fall=physical_fall
	_neck=rig.find_bone("neck")
	_head=rig.find_bone("head")
	for side:String in ["L","R"]:
		var bones:Array=[rig.find_bone("upper_arm."+side),rig.find_bone("forearm."+side),rig.find_bone("hand."+side)]
		var points:Array=[]
		for bone:int in bones:points.append(_bounds(model,bone))
		_arms.append({"bones":bones,"points":points})
	var limits:Array=[["hips","spine",0.145],["spine","chest",0.17],["chest","neck",0.17],["thigh.L","shin.L",0.115],["thigh.R","shin.R",0.115]]
	if physical_fall:
		for c:Array in limits:c[2]=float(c[2])+0.03
		limits.append_array([["shin.L","foot.L",0.13],["shin.R","foot.R",0.13],["foot.L","toe.L",0.13],["foot.R","toe.R",0.13]])
	for c:Array in limits:
		_capsules.append([rig.find_bone(c[0]),rig.find_bone(c[1]),c[2]])
	for side:String in ["L","R"]:
		var bones:Array=[rig.find_bone("thigh."+side),rig.find_bone("shin."+side),rig.find_bone("foot."+side),rig.find_bone("toe."+side)]
		_legs.append({"bones":bones,"points":_bounds(model,bones[2],"Shoes_01")})

func apply() -> void:
	# 다른 체형에서 옮겨온 70도 쇄골 회전을 그대로 쓰면 소매가 귀까지 올라간다.
	for arm:Dictionary in _arms:
		var upper:int=arm.bones[0]
		var clavicle:int=_rig.get_bone_parent(upper)
		var arm_turn:Quaternion=_rig.get_bone_global_pose(upper).basis.get_rotation_quaternion()
		var clavicle_rest:Quaternion=_rig.get_bone_rest(clavicle).basis.get_rotation_quaternion()
		var clavicle_pose:Quaternion=_rig.get_bone_pose_rotation(clavicle)
		var amount:float=clavicle_rest.angle_to(clavicle_pose)
		if amount>0.3:
			_rig.set_bone_pose_rotation(clavicle,clavicle_rest.slerp(clavicle_pose,0.3/amount))
			_rig.set_bone_pose_rotation(upper,_rig.get_bone_global_pose(clavicle).basis.get_rotation_quaternion().inverse()*arm_turn)
	var head_turn:Quaternion=_rig.get_bone_global_pose(_head).basis.get_rotation_quaternion()
	var rest:Quaternion=_rig.get_bone_rest(_neck).basis.get_rotation_quaternion()
	var pose:Quaternion=_rig.get_bone_pose_rotation(_neck)
	var angle:float=rest.angle_to(pose)
	if angle>NECK_LIMIT:
		_rig.set_bone_pose_rotation(_neck,rest.slerp(pose,NECK_LIMIT/angle))
		var parent:int=_rig.get_bone_parent(_head)
		_rig.set_bone_pose_rotation(_head,_rig.get_bone_global_pose(parent).basis.get_rotation_quaternion().inverse()*head_turn)
	# 큰 귀가 높은 어깨를 통과하는 고개 기울기만 제한한다. 기본 얼굴/거북목은 유지한다.
	var chest:int=_rig.find_bone("chest")
	var expected:Quaternion=_rig.get_bone_global_pose(chest).basis.get_rotation_quaternion()*_rig.get_bone_global_rest(chest).basis.get_rotation_quaternion().inverse()*_rig.get_bone_global_rest(_head).basis.get_rotation_quaternion()
	var delta:Quaternion=_rig.get_bone_global_pose(_head).basis.get_rotation_quaternion()*expected.inverse()
	var euler:Vector3=Basis(delta).get_euler()
	var limited:=Vector3(clampf(euler.x,-0.35,0.35),clampf(euler.y,-1.0,1.0),clampf(euler.z,-0.22,0.22))
	if not limited.is_equal_approx(euler):
		_rig.set_bone_pose_rotation(_head,_rig.get_bone_global_pose(_rig.get_bone_parent(_head)).basis.get_rotation_quaternion().inverse()*Basis.from_euler(limited).get_rotation_quaternion()*expected)
	if _physical_fall:
		for leg: Dictionary in _legs:
			# 옆으로 쓰러질 때 바닥에 닿은 발이 배 쪽으로 접혀 들어가지 않도록 한다.
			_limit_local_turn(leg.bones[0], 0.82)
			_limit_local_turn(leg.bones[1], 1.48)
			_limit_local_turn(leg.bones[2], 0.55)
	for side in range(_legs.size()):
		for pass_index in range(6 if _physical_fall else 4):
			if not _protect_foot(_legs[side], _legs[1 - side]):
				break
	if _physical_fall:
		_lift_shoes_to_floor()
	_world_capsules.clear()
	for cap:Array in _capsules:
		var a:Vector3=_rig.get_bone_global_pose(cap[0]).origin
		var axis:Vector3=_rig.get_bone_global_pose(cap[1]).origin-a
		_world_capsules.append([a,axis,maxf(axis.length_squared(),0.00001),cap[2]])
	for arm:Dictionary in _arms:
		_limit_wrist(arm.bones[1],arm.bones[2])
		for i in range(10 if _physical_fall else 6):
			var moved:bool=_protect_arm(arm)
			var wrist_moved:bool=_limit_wrist(arm.bones[1],arm.bones[2])
			if not moved and not wrist_moved: break

func _limit_local_turn(bone: int, limit: float) -> void:
	var rest := _rig.get_bone_rest(bone).basis.get_rotation_quaternion()
	var rotation := _rig.get_bone_pose_rotation(bone)
	var angle := rest.angle_to(rotation)
	if angle > limit:
		_rig.set_bone_pose_rotation(bone, rest.slerp(rotation, limit / angle))


func _lift_shoes_to_floor() -> void:
	var lowest := INF
	for leg: Dictionary in _legs:
		var pose := _rig.global_transform * _rig.get_bone_global_pose(leg.bones[2])
		for point: Vector3 in leg.points:
			lowest = minf(lowest, (pose * point).y)
	if lowest < 0.0:
		# 옆으로 누우면 골반의 좌우축이 수직에 가깝다. 발만 위로 밀면 무릎이 접혀 셔츠를 뚫는다.
		var hips := _rig.find_bone("hips")
		var pose := _rig.get_bone_global_pose(hips)
		pose.origin += _rig.global_transform.basis.inverse() * (Vector3.UP * -lowest)
		_rig.set_bone_global_pose(hips, pose)


func _limit_wrist(fore:int,hand:int) -> bool:
	var forearm:Vector3=(_rig.get_bone_global_pose(hand).origin-_rig.get_bone_global_pose(fore).origin).normalized()
	var hand_pose:Transform3D=_rig.get_bone_global_pose(hand)
	var along:Vector3=hand_pose.basis.y.normalized()
	var angle:float=forearm.angle_to(along)
	if angle>WRIST_LIMIT:
		var target:Vector3=forearm.slerp(along,WRIST_LIMIT/angle).normalized()
		var facing:Quaternion=Quaternion(along,target)*hand_pose.basis.get_rotation_quaternion()
		_rig.set_bone_pose_rotation(hand,_rig.get_bone_global_pose(fore).basis.get_rotation_quaternion().inverse()*facing)
		return true
	return false

func _bounds(model:Node3D,bone:int,part:String="Body") -> Array:
	var mesh:=model.find_child(part,true,false) as MeshInstance3D
	var key:String=str(mesh.mesh.get_instance_id())+":"+str(bone)
	if _bounds_cache.has(key):return _bounds_cache[key]
	var inverse:Transform3D=_rig.get_bone_global_rest(bone).affine_inverse()
	var lower:=Vector3.INF
	var upper:=Vector3(-INF,-INF,-INF)
	var matches := PackedByteArray()
	for i in range(mesh.skin.get_bind_count()):
		matches.append(int(_rig.find_bone(mesh.skin.get_bind_name(i)) == bone))
	for surface in range(mesh.mesh.get_surface_count()):
		var a:Array=mesh.mesh.surface_get_arrays(surface)
		var v:PackedVector3Array=a[Mesh.ARRAY_VERTEX]
		var ids:PackedInt32Array=a[Mesh.ARRAY_BONES]
		var weights:PackedFloat32Array=a[Mesh.ARRAY_WEIGHTS]
		var influences:int=ids.size()/v.size()
		for i in range(v.size()):
			for j in range(influences):
				var o:int=i*influences+j
				if weights[o]>0.5 and matches[ids[o]]:
					var p:Vector3=inverse*v[i]
					lower=lower.min(p)
					upper=upper.max(p)
	var points:Array=[]
	for x:float in [lower.x,upper.x]:
		for y:float in [lower.y,(lower.y+upper.y)*0.5,upper.y]:
			for z:float in [lower.z,upper.z]:points.append(Vector3(x,y,z))
	_bounds_cache[key]=points
	return points

func _protect_foot(leg:Dictionary,other:Dictionary) -> bool:
	var thigh:int=leg.bones[0]
	var shin:int=leg.bones[1]
	var foot:int=leg.bones[2]
	var hip:Vector3=_rig.get_bone_global_pose(thigh).origin
	var knee:Vector3=_rig.get_bone_global_pose(shin).origin
	var ankle:Vector3=_rig.get_bone_global_pose(foot).origin
	var foot_pose:Transform3D=_rig.get_bone_global_pose(foot)
	var target:Vector3=ankle
	var other_hip:Vector3=_rig.get_bone_global_pose(other.bones[0]).origin
	var middle:Vector3=(hip+other_hip)*0.5
	var outward:Vector3=(hip-other_hip).normalized()
	var minimum_side:float=INF
	for p:Vector3 in leg.points:minimum_side=minf(minimum_side,(foot_pose*p-middle).dot(outward))
	# 각 발을 골반의 자기 쪽에 유지한다. 밀어내는 방향이 반전되어 발이 순간 이동하는 현상을 막는다.
	if minimum_side<0.045:target+=outward*(0.045-minimum_side)
	if target.distance_to(ankle)<0.0001 and (knee-middle).dot(outward)>=0.09:return false
	var upper:float=hip.distance_to(knee)
	var lower:float=knee.distance_to(ankle)
	var axis:Vector3=(target-hip).normalized()
	var minimum:float=sqrt(maxf(0.0001,upper*upper+lower*lower+2.0*upper*lower*cos(2.53)))
	var distance:float=clampf(hip.distance_to(target),minimum,upper+lower-0.001)
	var bend:Vector3=knee-hip-axis*(knee-hip).dot(axis)
	if bend.length_squared()<0.000001:return false
	var cosine:float=(upper*upper+distance*distance-lower*lower)/(2.0*upper*distance)
	var height:float=upper*sqrt(maxf(0.0,1.0-cosine*cosine))
	var center:Vector3=hip+axis*(upper*cosine)
	var lateral:Vector3=outward-axis*outward.dot(axis)
	var direction:Vector3=bend.normalized()
	if lateral.length()>0.00001 and height>0.00001:
		var e:Vector3=lateral.normalized()
		var need:float=clampf((0.09-(center-middle).dot(outward))/(height*lateral.length()),-0.99,0.99)
		if direction.dot(e)<need:
			var remainder:Vector3=direction-e*direction.dot(e)
			if remainder.length_squared()<0.000001:remainder=axis.cross(e)
			direction=e*need+remainder.normalized()*sqrt(maxf(0.0,1.0-need*need))
	var new_knee:Vector3=center+direction*height
	_aim(thigh,shin,new_knee-hip)
	_aim(shin,foot,hip+axis*distance-_rig.get_bone_global_pose(shin).origin)
	_rig.set_bone_pose_rotation(foot,_rig.get_bone_global_pose(shin).basis.get_rotation_quaternion().inverse()*foot_pose.basis.get_rotation_quaternion())
	return true

func _outside(point:Vector3,radius:float) -> Vector3:
	var p:Vector3=point
	for cap:Array in _world_capsules:
		var a:Vector3=cap[0]
		var axis:Vector3=cap[1]
		var near:Vector3=a+axis*clampf((p-a).dot(axis)/float(cap[2]),0.0,1.0)
		var delta:Vector3=p-near
		var distance:float=delta.length()
		var minimum:float=float(cap[3])+radius
		if distance<minimum:
			p=near+(delta/distance if distance>0.00001 else Vector3.FORWARD)*minimum
	return p

func _protect_arm(arm:Dictionary) -> bool:
	var upper:int=arm.bones[0]
	var fore:int=arm.bones[1]
	var hand:int=arm.bones[2]
	var shoulder:Vector3=_rig.get_bone_global_pose(upper).origin
	var elbow:Vector3=_rig.get_bone_global_pose(fore).origin
	var wrist:Vector3=_rig.get_bone_global_pose(hand).origin
	var hand_pose := _rig.get_bone_global_pose(hand)
	var upper_pose := _rig.get_bone_global_pose(upper)
	var fore_pose := _rig.get_bone_global_pose(fore)
	var facing:Quaternion=hand_pose.basis.get_rotation_quaternion()
	var target:Vector3=wrist
	# 손끝과 손바닥도 검사해 손목만 옷 밖에 있고 손끝은 안으로 들어가는 경우를 막는다.
	for p:Vector3 in arm.points[2]:
		var sample:Vector3=hand_pose*p+target-wrist
		target+=_outside(sample,0.012)-sample
	var elbow_target:Vector3=_outside(elbow,0.04)
	for p:Vector3 in arm.points[0]:
		var sample:Vector3=upper_pose*p
		var push:Vector3=_outside(sample,0.006)-sample
		elbow_target+=push
		target+=push*0.5
	for p:Vector3 in arm.points[1]:
		var sample:Vector3=fore_pose*p
		var push:Vector3=_outside(sample,0.012)-sample
		elbow_target+=push*0.6
		target+=push*0.8
	for along:float in [0.25,0.5,0.75]:
		var sample:Vector3=elbow_target.lerp(target,along)
		var push:Vector3=_outside(sample,0.038)-sample
		elbow_target+=push*(1.0-along)
		target+=push*along
	if target.distance_to(wrist)<0.0001 and elbow_target.distance_to(elbow)<0.0001:return false
	var length_a:float=shoulder.distance_to(elbow)
	var length_b:float=elbow.distance_to(wrist)
	var axis:Vector3=(target-shoulder).normalized()
	var distance:float=clampf(shoulder.distance_to(target),absf(length_a-length_b)+0.001,length_a+length_b-0.001)
	var bend:Vector3=elbow_target-shoulder-axis*(elbow_target-shoulder).dot(axis)
	if bend.length_squared()<0.000001:return false
	var cosine:float=(length_a*length_a+distance*distance-length_b*length_b)/(2.0*length_a*distance)
	var new_elbow:Vector3=shoulder+axis*(length_a*cosine)+bend.normalized()*(length_a*sqrt(maxf(0.0,1.0-cosine*cosine)))
	_aim(upper,fore,new_elbow-shoulder)
	_aim(fore,hand,shoulder+axis*distance-_rig.get_bone_global_pose(fore).origin)
	_rig.set_bone_pose_rotation(hand,_rig.get_bone_global_pose(fore).basis.get_rotation_quaternion().inverse()*facing)
	return true

func _aim(bone:int,child:int,direction:Vector3) -> void:
	var from:Transform3D=_rig.get_bone_global_pose(bone)
	var current:Vector3=(_rig.get_bone_global_pose(child).origin-from.origin).normalized()
	var desired:Vector3=direction.normalized()
	if current.is_equal_approx(desired):return
	var facing:Quaternion=Quaternion(current,desired)*from.basis.get_rotation_quaternion()
	var parent:int=_rig.get_bone_parent(bone)
	_rig.set_bone_pose_rotation(bone,_rig.get_bone_global_pose(parent).basis.get_rotation_quaternion().inverse()*facing)
