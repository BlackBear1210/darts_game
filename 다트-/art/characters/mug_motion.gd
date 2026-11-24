extends RefCounted
## Table contact, handle location and mouth height are shared by the lounge and seated guests.
const HEIGHT := 0.075

static func table_spot(actor: Node3D) -> Vector3:
	var at := actor.to_global(Vector3(0.10,0,-0.43))
	for table in [[TableView.TABLE_CENTER, TableView.TABLE_SIZE.x*0.5, TableView.TABLE_HEIGHT],
			[TableView.NPC_TABLE_BOX.get_center(),0.72,TableView.NPC_TABLE_BOX.end.y]]:
		var center: Vector3 = table[0]
		var radial := Vector3(at.x-center.x,0,at.z-center.z)
		radial = radial.limit_length(float(table[1])-0.08)
		var point := Vector3(center.x,float(table[2])+HEIGHT,center.z)+radial
		if Vector2(point.x-actor.global_position.x,point.z-actor.global_position.z).length()<0.60:
			return point
	var bar := TableView.BAR_BOX
	var counter := Vector3(clampf(at.x,bar.position.x+0.09,bar.end.x-0.09),TableView.BAR_TOP_Y+HEIGHT,clampf(at.z,bar.position.z+0.09,bar.end.z-0.09))
	if Vector2(counter.x-actor.global_position.x,counter.z-actor.global_position.z).length()<0.58:
		return counter
	return Vector3.INF

static func place(actor: Node3D, motion: CharacterMotion, base: Vector3, progress: float, weight: float) -> Transform3D:
	var curve := smoothstep(0.08,0.38,progress)*(1.0-smoothstep(0.61,0.91,progress))
	var tip := smoothstep(0.27,0.47,progress)*(1.0-smoothstep(0.55,0.76,progress))
	var model := motion._model
	var layer := motion._layer
	var rig := layer.get_skeleton()
	var head := rig.get_bone_global_pose(layer._head)
	var mouth := rig.to_global(head*(rig.get_bone_global_rest(layer._head).affine_inverse()*Vector3(0,1.475,-0.186)))
	var end := mouth+model.global_basis*Vector3(0.005,-0.045,-0.063)
	var frame := Transform3D(model.global_basis.orthonormalized()*Basis(Vector3.RIGHT,0.65*tip),base.lerp(end,curve)+Vector3.UP*0.035*sin(PI*curve))
	motion.mug_frame = frame
	motion.mug_weight = weight
	return frame
