extends Node3D

#
# 道：閉鎖空間
#

class_name ProceduralRoadSegment

## 道マネージャ
var road_manager:RoadManager

## 道ポイントリスト
var road_point_string:Array[RoadPoint] = []
## ループしているか？
var is_looped:bool = false

## 道から生成したCurve
var curve:Curve3D

## 生成したノード一覧
var _generated_nodes:Node3D
## 道当たり判定
var _road_static_body:StaticBody3D
## 歩道当たり判定
var _sidewalk_static_body:StaticBody3D

# --------------------------------------------------------------------------------------------------

class TempRoadSegment:
	var t:float
	var transform:Transform3D
	var road_height:Vector3
	var sidewalk_height:Vector3
	var left_origin:Vector3
	var right_origin:Vector3

	func _init(
		_t:float
	,	_transform:Transform3D
	,	_road_height:Vector3
	,	_sidewalk_height:Vector3
	,	_left_origin:Vector3
	,	_right_origin:Vector3 ):
		self.t = _t
		self.transform = _transform
		self.road_height = _road_height
		self.sidewalk_height = _sidewalk_height
		self.left_origin = _left_origin
		self.right_origin = _right_origin

# --------------------------------------------------------------------------------------------------

## 初期化
## @param	_road_manager	道マネージャ
## @param	_road_point_string	閉鎖空間のポイントリスト
## @param	_is_looped	ループしているか
func _init(
	_road_manager:RoadManager
,	_road_point_string:Array[RoadPoint]
,	_is_looped:bool
) -> void:
	self.road_manager = _road_manager
	self.road_point_string = _road_point_string
	self.is_looped = _is_looped

## 道用のCurveを生成
func _generate_curve( ) -> void:
	self.curve = Curve3D.new( )
	self.curve.up_vector_enabled = false
	for i in self.road_point_string.size( ):
		var cur:RoadPoint = self.road_point_string[i]
		var tf:Transform3D = cur.global_transform

		var prev:RoadPoint = self.road_point_string[i-1]
		var prev_length:float = prev.global_transform.origin.distance_to( tf.origin )

		var next:RoadPoint = self.road_point_string[(i+1) % self.road_point_string.size( )]
		var next_length:float = next.global_transform.origin.distance_to( tf.origin )

		self.curve.add_point(
			tf.origin
		,	-tf.basis.z * ( prev_length * 0.5 )
		,	tf.basis.z * ( next_length * 0.5 )
		)
		# TODO: tiltの計算を変える？ X軸の回転の影響も受ける
		self.curve.set_point_tilt( i, Vector3.UP.signed_angle_to( tf.basis.y, tf.basis.z ) )
		#printt( self.road_point_string[0].name, i, Vector3.UP.signed_angle_to( tf.basis.y, tf.basis.z ) )

	self.curve.closed = self.is_looped

## MeshInstance3Dをセットアップして返す
func _new_mesh_instance_3d( ) -> MeshInstance3D:
	var mi: = MeshInstance3D.new( )
	mi.layers = self.road_manager.layers
	mi.visibility_range_begin = self.road_manager.visibility_range_begin
	mi.visibility_range_begin_margin = self.road_manager.visibility_range_begin_margin
	mi.visibility_range_end = self.road_manager.visibility_range_end
	mi.visibility_range_end_margin = self.road_manager.visibility_range_end_margin
	mi.visibility_range_fade_mode = self.road_manager.visibility_range_fade_mode
	return mi

# --------------------------------------------------------------------------------------------------

## メッシュ生成
func generate_mesh( ) -> void:
	if not self.is_inside_tree( ):
		return
	if self._generated_nodes != null:
		return
	if self.road_point_string.size( ) < 2:
		# 足りない
		return

	self._generate_curve( )
	self._generated_nodes = Node3D.new( )
	self.add_child( self._generated_nodes )
	self._road_static_body = StaticBody3D.new( )
	self._generated_nodes.add_child( self._road_static_body )
	self._sidewalk_static_body = StaticBody3D.new( )
	self._generated_nodes.add_child( self._sidewalk_static_body )

	var accumulate_road_length:float = 0.0
	var road_class: = self.road_manager.road_class

	self._sidewalk_static_body.disable_mode = road_class.sidewalk_disable_mode
	self._sidewalk_static_body.collision_layer = road_class.sidewalk_collision_layer
	self._sidewalk_static_body.collision_mask = road_class.sidewalk_collision_mask
	self._sidewalk_static_body.collision_priority = road_class.sidewalk_collision_priority

	# 各区間を作成する
	for point_counter in self.road_point_string.size( ) - ( 0 if self.is_looped else 1 ):
		var start:RoadPoint = self.road_point_string[point_counter]
		var end:RoadPoint = self.road_point_string[(point_counter+1) % self.road_point_string.size( )]

		# 区間距離計算
		var road_length:float = 0.0
		if point_counter == self.road_point_string.size( ) - 1:
			# ループ部
			road_length = self.curve.get_baked_length( ) - accumulate_road_length
		else:
			# 直線部
			# TODO: 高速に正確に距離を計算する方法に変える
			var cur:Vector3 = self.curve.sample( point_counter, 0.0 )
			const temp_loop_cut:int = 256
			for i in temp_loop_cut:
				var next:Vector3 = self.curve.sample( point_counter, float(i+1) / temp_loop_cut )
				road_length += cur.distance_to( next )
				cur = next

		var road_loop_cut:int = clampi( 2 + floori( road_length / self.road_manager.get_road_loop_cut_per_meter( ) ), 3, 1024 )

		# メッシュを生成
		var left_st: = SurfaceTool.new( )
		left_st.begin( Mesh.PRIMITIVE_TRIANGLE_STRIP )
		left_st.set_material( road_class.road_material )
		var right_st: = SurfaceTool.new( )
		right_st.begin( Mesh.PRIMITIVE_TRIANGLE_STRIP )
		right_st.set_material( road_class.road_material )

		var left_sidewalk_st: = SurfaceTool.new( )
		left_sidewalk_st.begin( Mesh.PRIMITIVE_TRIANGLE_STRIP )
		left_sidewalk_st.set_material( road_class.sidewalk_material )
		var left_sidewalk_inner_st: = SurfaceTool.new( )
		left_sidewalk_inner_st.begin( Mesh.PRIMITIVE_TRIANGLE_STRIP )
		left_sidewalk_inner_st.set_material( road_class.sidewalk_material )
		var left_sidewalk_outer_st: = SurfaceTool.new( )
		left_sidewalk_outer_st.begin( Mesh.PRIMITIVE_TRIANGLE_STRIP )
		left_sidewalk_outer_st.set_material( road_class.sidewalk_material )

		var right_sidewalk_st: = SurfaceTool.new( )
		right_sidewalk_st.begin( Mesh.PRIMITIVE_TRIANGLE_STRIP )
		right_sidewalk_st.set_material( road_class.sidewalk_material )
		var right_sidewalk_inner_st: = SurfaceTool.new( )
		right_sidewalk_inner_st.begin( Mesh.PRIMITIVE_TRIANGLE_STRIP )
		right_sidewalk_inner_st.set_material( road_class.sidewalk_material )
		var right_sidewalk_outer_st: = SurfaceTool.new( )
		right_sidewalk_outer_st.begin( Mesh.PRIMITIVE_TRIANGLE_STRIP )
		right_sidewalk_outer_st.set_material( road_class.sidewalk_material )

		for i in road_loop_cut:
			var s:float = float(i) / ( road_loop_cut - 1 )
			var cur_transform: = self.curve.sample_baked_with_rotation( s * road_length + accumulate_road_length, true, true )
			var cur_basis: = cur_transform.basis
			var cur_origin: = cur_transform.origin
			var road_height: = cur_basis.y * road_class.road_height
			var sidewalk_height: = cur_basis.y * road_class.sidewalk_height
			var left_origin: = cur_origin - cur_basis.x * lerpf(
					road_class.road_width * start.left_lanes
				,	road_class.road_width * end.left_lanes
				,	s
				)
			var right_origin: = cur_origin + cur_basis.x * lerpf(
					road_class.road_width * start.right_lanes
				,	road_class.road_width * end.right_lanes
				,	s
				)

			# 車道用
			left_st.set_normal( cur_basis.y )
			left_st.set_uv( Vector2( 1, s ) )
			left_st.add_vertex( cur_origin + road_height )
			left_st.set_uv( Vector2( 0, s ) )
			left_st.add_vertex( left_origin + road_height )
			right_st.set_normal( cur_basis.y )
			right_st.set_uv( Vector2( 0, s ) )
			right_st.add_vertex( right_origin + road_height )
			right_st.set_uv( Vector2( 1, s ) )
			right_st.add_vertex( cur_origin + road_height )

			# 歩道用
			left_sidewalk_st.set_normal( cur_basis.y )
			left_sidewalk_st.set_uv( Vector2( 0, s * road_length ) )
			left_sidewalk_st.add_vertex( left_origin + sidewalk_height )
			left_sidewalk_st.set_uv( Vector2( 1, s * road_length ) )
			left_sidewalk_st.add_vertex( left_origin + sidewalk_height - cur_basis.x * road_class.sidewalk_width )
			left_sidewalk_inner_st.set_normal( -cur_basis.x )
			left_sidewalk_inner_st.set_uv( Vector2( 1, s * road_length ) )
			left_sidewalk_inner_st.add_vertex( left_origin )
			left_sidewalk_inner_st.set_uv( Vector2( 0, s * road_length ) )
			left_sidewalk_inner_st.add_vertex( left_origin + sidewalk_height )
			left_sidewalk_outer_st.set_normal( cur_basis.x )
			left_sidewalk_outer_st.set_uv( Vector2( 1, s * road_length ) )
			left_sidewalk_outer_st.add_vertex( left_origin + sidewalk_height - cur_basis.x * road_class.sidewalk_width )
			left_sidewalk_outer_st.set_uv( Vector2( 0, s * road_length ) )
			left_sidewalk_outer_st.add_vertex( left_origin - cur_basis.x * road_class.sidewalk_width )

			right_sidewalk_st.set_normal( cur_basis.y )
			right_sidewalk_st.set_uv( Vector2( 1, s * road_length ) )
			right_sidewalk_st.add_vertex( right_origin + sidewalk_height + cur_basis.x * road_class.sidewalk_width )
			right_sidewalk_st.set_uv( Vector2( 0, s * road_length ) )
			right_sidewalk_st.add_vertex( right_origin + sidewalk_height )
			right_sidewalk_inner_st.set_normal( cur_basis.x )
			right_sidewalk_inner_st.set_uv( Vector2( 0, s * road_length ) )
			right_sidewalk_inner_st.add_vertex( right_origin + sidewalk_height )
			right_sidewalk_inner_st.set_uv( Vector2( 1, s * road_length ) )
			right_sidewalk_inner_st.add_vertex( right_origin )
			right_sidewalk_outer_st.set_normal( -cur_basis.x )
			right_sidewalk_outer_st.set_uv( Vector2( 0, s * road_length ) )
			right_sidewalk_outer_st.add_vertex( right_origin + cur_basis.x * road_class.sidewalk_width )
			right_sidewalk_outer_st.set_uv( Vector2( 1, s * road_length ) )
			right_sidewalk_outer_st.add_vertex( right_origin + sidewalk_height + cur_basis.x * road_class.sidewalk_width )

		# 左車線
		var left_road:MeshInstance3D = null
		if 0 < start.left_lanes and 0 < end.left_lanes:
			left_road = self._new_mesh_instance_3d( )
			left_road.mesh = left_st.commit( )
			left_road.set_instance_shader_parameter( "from_lanes", start.left_lanes )
			left_road.set_instance_shader_parameter( "to_lanes", end.left_lanes )
			left_road.set_instance_shader_parameter( "road_length", road_length )
			left_road.set_instance_shader_parameter( "has_opposite_lane", start.right_lanes != 0 )
			self._generated_nodes.add_child( left_road )

		# 右車線
		var right_road:MeshInstance3D = null
		if 0 < start.right_lanes and 0 < end.right_lanes:
			right_road = self._new_mesh_instance_3d( )
			right_road.mesh = right_st.commit( )
			right_road.set_instance_shader_parameter( "from_lanes", start.right_lanes )
			right_road.set_instance_shader_parameter( "to_lanes", end.right_lanes )
			right_road.set_instance_shader_parameter( "road_length", road_length )
			right_road.set_instance_shader_parameter( "has_opposite_lane", start.left_lanes != 0 )
			self._generated_nodes.add_child( right_road )

		# 左歩道
		var left_sidewalk:MeshInstance3D = null
		var left_inner_sidewalk:MeshInstance3D = null
		var left_outer_sidewalk:MeshInstance3D = null
		if road_class.has_sidewalk:
			left_sidewalk = self._new_mesh_instance_3d( )
			left_sidewalk.mesh = left_sidewalk_st.commit( )
			self._generated_nodes.add_child( left_sidewalk )

			left_inner_sidewalk = self._new_mesh_instance_3d( )
			left_inner_sidewalk.mesh = left_sidewalk_inner_st.commit( )
			self._generated_nodes.add_child( left_inner_sidewalk )

			left_outer_sidewalk = self._new_mesh_instance_3d( )
			left_outer_sidewalk.mesh = left_sidewalk_outer_st.commit( )
			self._generated_nodes.add_child( left_outer_sidewalk )

		# 右歩道
		var right_sidewalk:MeshInstance3D = null
		var right_inner_sidewalk:MeshInstance3D = null
		var right_outer_sidewalk:MeshInstance3D = null
		if road_class.has_sidewalk:
			right_sidewalk = self._new_mesh_instance_3d( )
			right_sidewalk.mesh = right_sidewalk_st.commit( )
			self._generated_nodes.add_child( right_sidewalk )

			right_inner_sidewalk = self._new_mesh_instance_3d( )
			right_inner_sidewalk.mesh = right_sidewalk_inner_st.commit( )
			self._generated_nodes.add_child( right_inner_sidewalk )

			right_outer_sidewalk = self._new_mesh_instance_3d( )
			right_outer_sidewalk.mesh = right_sidewalk_outer_st.commit( )
			self._generated_nodes.add_child( right_outer_sidewalk )

		accumulate_road_length += road_length

		if not Engine.is_editor_hint( ):
			# 道当たり判定
			if left_road:
				var left_road_collision: = CollisionShape3D.new( )
				left_road_collision.shape = left_road.mesh.create_trimesh_shape( )
				left_road_collision.shape.backface_collision = true			# XXX: PRIMITIVE_TRIANGLE_STRIPから生成すると半分逆面を向くGodotのバグ回避
				self._road_static_body.add_child( left_road_collision )
			if right_road:
				var right_road_collision: = CollisionShape3D.new( )
				right_road_collision.shape = right_road.mesh.create_trimesh_shape( )
				right_road_collision.shape.backface_collision = true			# XXX: PRIMITIVE_TRIANGLE_STRIPから生成すると半分逆面を向くGodotのバグ回避
				self._road_static_body.add_child( right_road_collision )
			self._road_static_body.disable_mode = road_class.road_disable_mode
			self._road_static_body.collision_layer = road_class.road_collision_layer
			self._road_static_body.collision_mask = road_class.road_collision_mask
			self._road_static_body.collision_priority = road_class.road_collision_priority

			# 歩道当たり判定
			for t in [left_sidewalk, left_inner_sidewalk, left_outer_sidewalk, right_sidewalk, right_inner_sidewalk, right_outer_sidewalk]:
				t as MeshInstance3D
				if t:
					var cs3d: = CollisionShape3D.new( )
					cs3d.shape = t.mesh.create_trimesh_shape( )
					cs3d.shape.backface_collision = true			# XXX: PRIMITIVE_TRIANGLE_STRIPから生成すると半分逆面を向くGodotのバグ回避
					self._sidewalk_static_body.add_child( cs3d )
