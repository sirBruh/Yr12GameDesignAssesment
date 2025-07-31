extends Node3D

#
# 生成：交差点用
#

class_name ProceduralRoadIntersection

## 道マネージャ
var road_manager:RoadManager

## 接続先
var connected_with:Array[RoadPoint] = []
## 交差点
var intersection:RoadIntersection

## 生成したノード一覧
var _generated_nodes:Node3D
## 道当たり判定
var _road_static_body:StaticBody3D
## 歩道当たり判定
var _sidewalk_static_body:StaticBody3D

# --------------------------------------------------------------------------------------------------

## 初期化
## @param	_road_manager	道マネージャ
## @param	_connected_with	接続先
func _init(
	_road_manager:RoadManager
,	_intersection:RoadIntersection
,	_connected_with:Array[RoadPoint]
) -> void:
	self.road_manager = _road_manager
	self.intersection = _intersection
	self.connected_with = _connected_with.duplicate( )

	var center: = self.intersection.global_transform.origin
	self.connected_with.sort_custom(
		func( a:RoadPoint, b:RoadPoint ) -> int:
			if a == b:
				return 0
			else:
				var va: = a.global_transform.origin - center
				var vb: = b.global_transform.origin - center
				var ra: = Vector3.LEFT.signed_angle_to( va, Vector3.UP )
				var rb: = Vector3.LEFT.signed_angle_to( vb, Vector3.UP )
				if ra < rb:
					return 1
				else:
					return -1
	)

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
	if self.intersection == null:
		return
	if self.connected_with.size( ) < 2:
		# 足りない
		return

	self._generated_nodes = Node3D.new( )
	self.add_child( self._generated_nodes )
	self._road_static_body = StaticBody3D.new( )
	self._generated_nodes.add_child( self._road_static_body )
	self._sidewalk_static_body = StaticBody3D.new( )
	self._generated_nodes.add_child( self._sidewalk_static_body )

	var road_class: = self.road_manager.road_class
	var road_height: = Vector3.UP * road_class.road_height
	var sidewalk_height: = Vector3.UP * road_class.sidewalk_height
	var center_circle_size: = 1.0
	for t in self.connected_with:
		center_circle_size = maxf( center_circle_size, ( t.left_lanes + t.right_lanes ) * ( 1.5 / 2.0 ) )

	var center_circle_st: = SurfaceTool.new( )
	center_circle_st.begin( Mesh.PRIMITIVE_TRIANGLES )
	center_circle_st.set_material( road_class.intersection_material )
	center_circle_st.set_normal( Vector3.UP )

	var center_circle_sidewalk_st: = SurfaceTool.new( )
	center_circle_sidewalk_st.begin( Mesh.PRIMITIVE_TRIANGLES )
	center_circle_sidewalk_st.set_material( road_class.sidewalk_material )
	center_circle_sidewalk_st.set_normal( Vector3.UP )

	var center_circle_vertices:Array[Vector3] = [self.intersection.global_transform.origin]
	var center_circle_uvs:Array[Vector2] = [Vector2(0.5,0.5)]

	for t in self.connected_with:
		var tf: = t.global_transform

		# 中心地
		var circle_to_origin: = center_circle_vertices[0] + center_circle_vertices[0].direction_to( tf.origin ) * road_class.road_width * center_circle_size
		var circle_left_origin: = circle_to_origin + tf.basis.x * ( road_class.road_width * t.left_lanes )
		var circle_right_origin: = circle_to_origin - tf.basis.x * ( road_class.road_width * t.right_lanes )
		for v in [circle_right_origin, circle_left_origin]:
			center_circle_vertices.push_back( v + road_height )
			var r:float = Vector3.LEFT.signed_angle_to( v - center_circle_vertices[0], Vector3.UP )
			center_circle_uvs.push_back( Vector2( cos( r ) * 0.5 + 0.5, sin( r ) * 0.5 + 0.5 ) )

		# 歩道
		var next_t: = self.connected_with[( self.connected_with.find( t ) + 1 ) % self.connected_with.size( )]
		var next_tf: = next_t.global_transform
		var circle_next_to_origin: = center_circle_vertices[0] + center_circle_vertices[0].direction_to( next_tf.origin ) * road_class.road_width * center_circle_size
		var circle_next_right_origin: = circle_next_to_origin - next_tf.basis.x * ( road_class.road_width * next_t.right_lanes )
		self._generate_helper_sidewalk(
			center_circle_sidewalk_st
		,	tf
		,	[
				circle_left_origin
			,	circle_left_origin + tf.basis.x * road_class.sidewalk_width
			,	circle_next_right_origin
			,	circle_next_right_origin - next_tf.basis.x * road_class.sidewalk_width
			]
		,	sidewalk_height
		)

		# 接続道
		self._generate_connection_road( t, circle_to_origin, circle_left_origin, circle_right_origin )

	# 中心地メッシュ生成
	center_circle_vertices.push_back( center_circle_vertices[1] )
	center_circle_uvs.push_back( center_circle_uvs[1] )
	center_circle_st.add_triangle_fan( center_circle_vertices, center_circle_uvs )
	var center_circle_mi: = self._new_mesh_instance_3d( )
	center_circle_mi.mesh = center_circle_st.commit( )
	self._generated_nodes.add_child( center_circle_mi )

	if not Engine.is_editor_hint( ):
		var center_circle_cs: = CollisionShape3D.new( )
		center_circle_cs.shape = center_circle_mi.mesh.create_trimesh_shape( )
		self._road_static_body.add_child( center_circle_cs )

	# 中心地メッシュ生成
	if road_class.has_sidewalk:
		var sidewalk_mi: = self._new_mesh_instance_3d( )
		sidewalk_mi.mesh = center_circle_sidewalk_st.commit( )
		self._generated_nodes.add_child( sidewalk_mi )

		if not Engine.is_editor_hint( ):
			var sidewalk_cs: = CollisionShape3D.new( )
			sidewalk_cs.shape = sidewalk_mi.mesh.create_trimesh_shape( )
			self._road_static_body.add_child( sidewalk_cs )

## 歩道作成ヘルパー
func _generate_helper_sidewalk( st:SurfaceTool, tf:Transform3D, vertices:Array[Vector3], sidewalk_height:Vector3 ) -> void:
	var sidewalk_length: = maxf( floorf( vertices[0].distance_to( vertices[2] ) ), 1.0 )

	# 歩く部分
	st.set_normal( tf.basis.y )
	st.set_uv( Vector2( 0, 0 ) )
	st.add_vertex( vertices[0] + sidewalk_height )
	st.set_uv( Vector2( 1, 0 ) )
	st.add_vertex( vertices[1] + sidewalk_height )
	st.set_uv( Vector2( 0, sidewalk_length ) )
	st.add_vertex( vertices[2] + sidewalk_height )
	st.set_uv( Vector2( 0, sidewalk_length ) )
	st.add_vertex( vertices[2] + sidewalk_height )
	st.set_uv( Vector2( 1, 0 ) )
	st.add_vertex( vertices[1] + sidewalk_height )
	st.set_uv( Vector2( 1, sidewalk_length ) )
	st.add_vertex( vertices[3] + sidewalk_height )

	# 内側
	st.set_normal( -tf.basis.x )
	st.set_uv( Vector2( 0, 0 ) )
	st.add_vertex( vertices[0] + sidewalk_height )
	st.set_uv( Vector2( 0, sidewalk_length ) )
	st.add_vertex( vertices[2] + sidewalk_height )
	st.set_uv( Vector2( 1, 0 ) )
	st.add_vertex( vertices[0] )
	st.set_uv( Vector2( 0, sidewalk_length ) )
	st.add_vertex( vertices[2] + sidewalk_height )
	st.set_uv( Vector2( 1, sidewalk_length ) )
	st.add_vertex( vertices[2] )
	st.set_uv( Vector2( 1, 0 ) )
	st.add_vertex( vertices[0] )

	# 外側
	st.set_normal( tf.basis.x )
	st.set_uv( Vector2( 0, 0 ) )
	st.add_vertex( vertices[1] + sidewalk_height )
	st.set_uv( Vector2( 1, 0 ) )
	st.add_vertex( vertices[1] )
	st.set_uv( Vector2( 0, sidewalk_length ) )
	st.add_vertex( vertices[3] + sidewalk_height )
	st.set_uv( Vector2( 0, sidewalk_length ) )
	st.add_vertex( vertices[3] + sidewalk_height )
	st.set_uv( Vector2( 1, 0 ) )
	st.add_vertex( vertices[1] )
	st.set_uv( Vector2( 1, sidewalk_length ) )
	st.add_vertex( vertices[3] )

## 交差点への接続道を生成
func _generate_connection_road( rp:RoadPoint, circle_to_origin:Vector3, circle_left_origin:Vector3, circle_right_origin:Vector3 ) -> void:
	var tf: = rp.global_transform
	var road_class: = self.road_manager.road_class
	var road_height: = Vector3.UP * road_class.road_height
	var sidewalk_height: = Vector3.UP * road_class.sidewalk_height

	var left_origin: = tf.origin + tf.basis.x * ( road_class.road_width * rp.left_lanes )
	var right_origin: = tf.origin - tf.basis.x * ( road_class.road_width * rp.right_lanes )
	var road_length: = circle_to_origin.distance_to( tf.origin )

	# 左車線
	if 0 < rp.left_lanes:
		var left_connection_st: = SurfaceTool.new( )
		left_connection_st.begin( Mesh.PRIMITIVE_TRIANGLE_STRIP )
		left_connection_st.set_material( road_class.connection_intersection_material if self.road_manager.traffic_side == RoadManager.RoadTrafficSide.LEFT else road_class.road_material )
		left_connection_st.set_normal( Vector3.UP )

		left_connection_st.set_uv( Vector2( 0, 0 ) )
		left_connection_st.add_vertex( circle_left_origin + road_height )
		left_connection_st.set_uv( Vector2( 1, 0 ) )
		left_connection_st.add_vertex( circle_to_origin + road_height )
		left_connection_st.set_uv( Vector2( 0, 1 ) )
		left_connection_st.add_vertex( left_origin + road_height )
		left_connection_st.set_uv( Vector2( 1, 1 ) )
		left_connection_st.add_vertex( tf.origin + road_height )

		var mi: = self._new_mesh_instance_3d( )
		mi.mesh = left_connection_st.commit( )
		mi.set_instance_shader_parameter( "from_lanes", rp.left_lanes )
		mi.set_instance_shader_parameter( "to_lanes", rp.left_lanes )
		mi.set_instance_shader_parameter( "road_length", road_length )
		mi.set_instance_shader_parameter( "has_opposite_lane", rp.right_lanes != 0 )
		self._generated_nodes.add_child( mi )

		if not Engine.is_editor_hint( ):
			var cs: = CollisionShape3D.new( )
			cs.shape = mi.mesh.create_trimesh_shape( )
			cs.shape.backface_collision = true			# XXX: PRIMITIVE_TRIANGLE_STRIPから生成すると半分逆面を向くGodotのバグ回避
			self._road_static_body.add_child( cs )

		if road_class.has_sidewalk:
			var outer: = tf.basis.x * road_class.sidewalk_width
			var left_sidewalk_st: = SurfaceTool.new( )
			left_sidewalk_st.begin( Mesh.PRIMITIVE_TRIANGLE_STRIP )
			left_sidewalk_st.set_material( road_class.sidewalk_material )
			left_sidewalk_st.set_normal( Vector3.UP )
			left_sidewalk_st.set_uv( Vector2( 0, 0 ) )
			left_sidewalk_st.add_vertex( circle_left_origin + sidewalk_height + outer )
			left_sidewalk_st.set_uv( Vector2( 1, 0 ) )
			left_sidewalk_st.add_vertex( circle_left_origin + sidewalk_height )
			left_sidewalk_st.set_uv( Vector2( 0, road_length ) )
			left_sidewalk_st.add_vertex( left_origin + sidewalk_height + outer )
			left_sidewalk_st.set_uv( Vector2( 1, road_length ) )
			left_sidewalk_st.add_vertex( left_origin + sidewalk_height )

			var left_sidewalk_mi: = self._new_mesh_instance_3d( )
			left_sidewalk_mi.mesh = left_sidewalk_st.commit( )
			self._generated_nodes.add_child( left_sidewalk_mi )

			var left_sidewalk_inner_st: = SurfaceTool.new( )
			left_sidewalk_inner_st.begin( Mesh.PRIMITIVE_TRIANGLE_STRIP )
			left_sidewalk_inner_st.set_material( road_class.sidewalk_material )
			left_sidewalk_inner_st.set_normal( tf.basis.x )
			left_sidewalk_inner_st.set_uv( Vector2( 0, 0 ) )
			left_sidewalk_inner_st.add_vertex( circle_left_origin + sidewalk_height )
			left_sidewalk_inner_st.set_uv( Vector2( 1, 0 ) )
			left_sidewalk_inner_st.add_vertex( circle_left_origin )
			left_sidewalk_inner_st.set_uv( Vector2( 0, road_length ) )
			left_sidewalk_inner_st.add_vertex( left_origin + sidewalk_height )
			left_sidewalk_inner_st.set_uv( Vector2( 1, road_length ) )
			left_sidewalk_inner_st.add_vertex( left_origin )

			var left_sidewalk_inner_mi: = self._new_mesh_instance_3d( )
			left_sidewalk_inner_mi.mesh = left_sidewalk_inner_st.commit( )
			self._generated_nodes.add_child( left_sidewalk_inner_mi )

			var left_sidewalk_outer_st: = SurfaceTool.new( )
			left_sidewalk_outer_st.begin( Mesh.PRIMITIVE_TRIANGLE_STRIP )
			left_sidewalk_outer_st.set_material( road_class.sidewalk_material )
			left_sidewalk_outer_st.set_normal( -tf.basis.x )
			left_sidewalk_outer_st.set_uv( Vector2( 0, 0 ) )
			left_sidewalk_outer_st.add_vertex( circle_left_origin + outer )
			left_sidewalk_outer_st.set_uv( Vector2( 1, 0 ) )
			left_sidewalk_outer_st.add_vertex( circle_left_origin + outer + sidewalk_height )
			left_sidewalk_outer_st.set_uv( Vector2( 0, road_length ) )
			left_sidewalk_outer_st.add_vertex( left_origin + outer )
			left_sidewalk_outer_st.set_uv( Vector2( 1, road_length ) )
			left_sidewalk_outer_st.add_vertex( left_origin + outer + sidewalk_height )

			var left_sidewalk_outer_mi: = self._new_mesh_instance_3d( )
			left_sidewalk_outer_mi.mesh = left_sidewalk_outer_st.commit( )
			self._generated_nodes.add_child( left_sidewalk_outer_mi )

			if not Engine.is_editor_hint( ):
				for t in [left_sidewalk_mi, left_sidewalk_inner_mi, left_sidewalk_outer_mi]:
					t as MeshInstance3D
					var sidewalk_cs: = CollisionShape3D.new( )
					sidewalk_cs.shape = t.mesh.create_trimesh_shape( )
					sidewalk_cs.shape.backface_collision = true			# XXX: PRIMITIVE_TRIANGLE_STRIPから生成すると半分逆面を向くGodotのバグ回避
					self._sidewalk_static_body.add_child( sidewalk_cs )

	# 右車線
	if 0 < rp.right_lanes:
		var right_connection_st: = SurfaceTool.new( )
		right_connection_st.begin( Mesh.PRIMITIVE_TRIANGLE_STRIP )
		right_connection_st.set_material( road_class.connection_intersection_material if self.road_manager.traffic_side == RoadManager.RoadTrafficSide.RIGHT else road_class.road_material )
		right_connection_st.set_normal( Vector3.UP )

		right_connection_st.set_uv( Vector2( 1, 0 ) )
		right_connection_st.add_vertex( circle_to_origin + road_height )
		right_connection_st.set_uv( Vector2( 0, 0 ) )
		right_connection_st.add_vertex( circle_right_origin + road_height )
		right_connection_st.set_uv( Vector2( 1, 1 ) )
		right_connection_st.add_vertex( tf.origin + road_height )
		right_connection_st.set_uv( Vector2( 0, 1 ) )
		right_connection_st.add_vertex( right_origin + road_height )

		var mi: = self._new_mesh_instance_3d( )
		mi.mesh = right_connection_st.commit( )
		mi.set_instance_shader_parameter( "from_lanes", rp.right_lanes )
		mi.set_instance_shader_parameter( "to_lanes", rp.right_lanes )
		mi.set_instance_shader_parameter( "road_length", road_length )
		mi.set_instance_shader_parameter( "has_opposite_lane", rp.left_lanes != 0 )
		self._generated_nodes.add_child( mi )

		if not Engine.is_editor_hint( ):
			var cs: = CollisionShape3D.new( )
			cs.shape = mi.mesh.create_trimesh_shape( )
			cs.shape.backface_collision = true			# XXX: PRIMITIVE_TRIANGLE_STRIPから生成すると半分逆面を向くGodotのバグ回避
			self._road_static_body.add_child( cs )

		if road_class.has_sidewalk:
			var outer: = - tf.basis.x * road_class.sidewalk_width
			var right_sidewalk_st: = SurfaceTool.new( )
			right_sidewalk_st.begin( Mesh.PRIMITIVE_TRIANGLE_STRIP )
			right_sidewalk_st.set_material( road_class.sidewalk_material )
			right_sidewalk_st.set_normal( Vector3.UP )
			right_sidewalk_st.set_uv( Vector2( 0, 0 ) )
			right_sidewalk_st.add_vertex( circle_right_origin + sidewalk_height )
			right_sidewalk_st.set_uv( Vector2( 1, 0 ) )
			right_sidewalk_st.add_vertex( circle_right_origin + sidewalk_height + outer )
			right_sidewalk_st.set_uv( Vector2( 0, road_length ) )
			right_sidewalk_st.add_vertex( right_origin + sidewalk_height )
			right_sidewalk_st.set_uv( Vector2( 1, road_length ) )
			right_sidewalk_st.add_vertex( right_origin + sidewalk_height + outer )

			var right_sidewalk_mi: = self._new_mesh_instance_3d( )
			right_sidewalk_mi.mesh = right_sidewalk_st.commit( )
			self._generated_nodes.add_child( right_sidewalk_mi )

			var right_sidewalk_inner_st: = SurfaceTool.new( )
			right_sidewalk_inner_st.begin( Mesh.PRIMITIVE_TRIANGLE_STRIP )
			right_sidewalk_inner_st.set_material( road_class.sidewalk_material )
			right_sidewalk_inner_st.set_normal( tf.basis.x )
			right_sidewalk_inner_st.set_uv( Vector2( 1, 0 ) )
			right_sidewalk_inner_st.add_vertex( circle_right_origin )
			right_sidewalk_inner_st.set_uv( Vector2( 0, 0 ) )
			right_sidewalk_inner_st.add_vertex( circle_right_origin + sidewalk_height )
			right_sidewalk_inner_st.set_uv( Vector2( 1, road_length ) )
			right_sidewalk_inner_st.add_vertex( right_origin )
			right_sidewalk_inner_st.set_uv( Vector2( 0, road_length ) )
			right_sidewalk_inner_st.add_vertex( right_origin + sidewalk_height )

			var right_sidewalk_inner_mi: = self._new_mesh_instance_3d( )
			right_sidewalk_inner_mi.mesh = right_sidewalk_inner_st.commit( )
			self._generated_nodes.add_child( right_sidewalk_inner_mi )

			var right_sidewalk_outer_st: = SurfaceTool.new( )
			right_sidewalk_outer_st.begin( Mesh.PRIMITIVE_TRIANGLE_STRIP )
			right_sidewalk_outer_st.set_material( road_class.sidewalk_material )
			right_sidewalk_outer_st.set_normal( -tf.basis.x )
			right_sidewalk_outer_st.set_uv( Vector2( 1, 0 ) )
			right_sidewalk_outer_st.add_vertex( circle_right_origin + outer + sidewalk_height )
			right_sidewalk_outer_st.set_uv( Vector2( 0, 0 ) )
			right_sidewalk_outer_st.add_vertex( circle_right_origin + outer )
			right_sidewalk_outer_st.set_uv( Vector2( 1, road_length ) )
			right_sidewalk_outer_st.add_vertex( right_origin + outer + sidewalk_height )
			right_sidewalk_outer_st.set_uv( Vector2( 0, road_length ) )
			right_sidewalk_outer_st.add_vertex( right_origin + outer )

			var right_sidewalk_outer_mi: = self._new_mesh_instance_3d( )
			right_sidewalk_outer_mi.mesh = right_sidewalk_outer_st.commit( )
			self._generated_nodes.add_child( right_sidewalk_outer_mi )

			if not Engine.is_editor_hint( ):
				for t in [right_sidewalk_mi, right_sidewalk_inner_mi, right_sidewalk_outer_mi]:
					t as MeshInstance3D
					var sidewalk_cs: = CollisionShape3D.new( )
					sidewalk_cs.shape = t.mesh.create_trimesh_shape( )
					sidewalk_cs.shape.backface_collision = true			# XXX: PRIMITIVE_TRIANGLE_STRIPから生成すると半分逆面を向くGodotのバグ回避
					self._sidewalk_static_body.add_child( sidewalk_cs )
