@tool
extends EditorPlugin

#
# 道：エディタ上ツール
#

var _road_toolbar:RoadToolbar = null
var _selected_point_coord:Vector2 = Vector2.ZERO

# -------------------------------------------------------------------------------------------------

func _enter_tree() -> void:
	var es: = self.get_editor_interface( ).get_selection( )
	es.selection_changed.connect( self._on_selection_changed )
	self._road_toolbar = preload( "res://addons/michi/scripts/ui/RoadToolbar.tscn" ).instantiate( )
	self._road_toolbar.on_selected_road_fix.connect( self._on_selected_road_fix )

func _exit_tree() -> void:
	var es: = self.get_editor_interface( ).get_selection( )
	es.selection_changed.disconnect( self._on_selection_changed )

	self._road_toolbar.queue_free( )
	self._road_toolbar = null

# -------------------------------------------------------------------------------------------------

func _set_selection_node( node:Node ) -> void:
	var es: = self.get_editor_interface( ).get_selection( )
	es.clear( )
	es.add_node( node )

func _get_selected_road_point( ) -> RoadPoint:
	var es: = self.get_editor_interface( ).get_selection( )
	var nodes: = es.get_selected_nodes( )
	if nodes.size( ) == 0:
		return null

	var node:Node = nodes[0]
	if node is RoadPoint:
		return node

	return null

func _get_selected_road_manager( ) -> RoadManager:
	var es: = self.get_editor_interface( ).get_selection( )
	var nodes: = es.get_selected_nodes( )
	if nodes.size( ) == 0:
		return null

	var node:Node = nodes[0]

	while node != null:
		if node is RoadManager:
			return node
		node = node.get_parent( )

	return null

func _show_road_toolbar( ) -> void:
	var first_node:RoadManager = self._get_selected_road_manager( )

	if self._road_toolbar and self._road_toolbar.get_parent( ) == null:
		self.add_control_to_container( CONTAINER_SPATIAL_EDITOR_MENU, self._road_toolbar )

	self._road_toolbar.road_manager = first_node

func _hide_road_toolbar( ) -> void:
	if self._road_toolbar and self._road_toolbar.get_parent( ):
		self.remove_control_from_container( CONTAINER_SPATIAL_EDITOR_MENU, self._road_toolbar )

	self._road_toolbar.road_manager = null

# -------------------------------------------------------------------------------------------------

func _on_selection_changed( ) -> void:
	var first_node:RoadManager = self._get_selected_road_manager( )
	if first_node:
		self._show_road_toolbar( )
	else:
		self._hide_road_toolbar( )

# -------------------------------------------------------------------------------------------------

func _handles( object: Object ):
	return object is Node3D

## 3D GUI 入力
func _forward_3d_gui_input( camera:Camera3D, event:InputEvent ) -> int:
	var ret_code:int = 0

	match self._road_toolbar.mode:
		RoadToolbar.RoadToolMode.Select:
			ret_code = self._do_event_road_select( camera, event )
		RoadToolbar.RoadToolMode.Add:
			ret_code = self._do_event_road_add( camera, event )
		RoadToolbar.RoadToolMode.Remove:
			ret_code = self._do_event_road_remove( camera, event )

	return ret_code

## 3D描画
func _forward_3d_draw_over_viewport( overlay: Control ) -> void:
	match self._road_toolbar.mode:
		RoadToolbar.RoadToolMode.Add:
			pass
		RoadToolbar.RoadToolMode.Select, RoadToolbar.RoadToolMode.Remove:
			overlay.draw_circle( self._selected_point_coord, 8, Color.BLACK )
			overlay.draw_circle( self._selected_point_coord, 7, Color.AQUAMARINE )
			overlay.draw_line( self._selected_point_coord + Vector2( -12, -12 ), self._selected_point_coord + Vector2( -12, 12 ), Color.RED )
			overlay.draw_line( self._selected_point_coord + Vector2( -12, 12 ), self._selected_point_coord + Vector2( 12, 12 ), Color.RED )
			overlay.draw_line( self._selected_point_coord + Vector2( 12, 12 ), self._selected_point_coord + Vector2( 12, -12 ), Color.RED )
			overlay.draw_line( self._selected_point_coord + Vector2( 12, -12 ), self._selected_point_coord + Vector2( -12, -12 ), Color.RED )

## マウスに近いRoadPointを返す
func _get_closest_road_point_from_mouse( camera:Camera3D, event:InputEvent ) -> RoadPoint:
	self._selected_point_coord = Vector2( -100, -100 )

	# 一番近いものを選択
	var selected_road_manager: = self._get_selected_road_manager( )
	if selected_road_manager == null:
		return null

	var min_distance:float = 100.0
	var target:RoadPoint = null
	for c in selected_road_manager.get_all_road_points( ):
		if c is RoadPoint:
			var coord: = camera.unproject_position( c.global_transform.origin )
			var distance:float = event.position.distance_to( coord )
			if distance < min_distance:
				min_distance = distance
				target = c
				self._selected_point_coord = coord

	self.update_overlays( )

	return target

## 道選択
func _do_event_road_select( camera:Camera3D, event:InputEvent ) -> int:
	var target: = self._get_closest_road_point_from_mouse( camera, event )
	if target == null or not ( event is InputEventMouseButton ):
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	event as InputEventMouseButton
	if event.button_index != MOUSE_BUTTON_LEFT:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if not event.pressed:
		return EditorPlugin.AFTER_GUI_INPUT_STOP

	var selection: = EditorInterface.get_selection()
	selection.clear( )
	selection.add_node( target )

	return EditorPlugin.AFTER_GUI_INPUT_STOP

## 道追加
func _do_event_road_add( camera:Camera3D, event:InputEvent ) -> int:
	if not event is InputEventMouseButton:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	event as InputEventMouseButton
	if event.button_index != MOUSE_BUTTON_LEFT:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if not event.pressed:
		return EditorPlugin.AFTER_GUI_INPUT_STOP

	var selected_road_manager:RoadManager = self._get_selected_road_manager( )
	if selected_road_manager == null:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	var selected_road_point:RoadPoint = self._get_selected_road_point( )

	var detect_tf: = Transform3D.IDENTITY

	var origin: = camera.project_ray_origin( event.position )
	var normal: = camera.project_ray_normal( event.position )
	var dss: = self.get_viewport( ).world_3d.direct_space_state
	var prqp: = PhysicsRayQueryParameters3D.new( )
	prqp.from = origin
	prqp.to = origin + normal * camera.far
	prqp.collide_with_areas = false
	prqp.collide_with_bodies = true
	var result: = dss.intersect_ray( prqp )
	if not result.is_empty( ):
		detect_tf.origin = result.position
	else:
		var base_origin: = selected_road_point.global_transform.origin if selected_road_point else Vector3.ZERO
		var tf: = selected_road_point.global_transform if selected_road_point else camera.global_transform
		var plane: = Plane( base_origin, base_origin + tf.basis.z, base_origin + tf.basis.x )
		var hit_result = plane.intersects_ray( origin, normal ) as Vector3
		if hit_result != null:
			detect_tf.origin = hit_result

	if selected_road_point:
		detect_tf.basis.z = selected_road_point.global_transform.origin.direction_to( detect_tf.origin )
		detect_tf.basis.x = detect_tf.basis.z.cross( Vector3.UP )
		detect_tf.basis.y = Vector3.UP

	# 追加
	var undo_redo: = self.get_undo_redo( )
	var new_rp: = RoadPoint.new( )

	undo_redo.create_action( "RoadPointを追加" )

	undo_redo.add_do_property( selected_road_manager, "deny_generate", true )
	undo_redo.add_do_method( selected_road_manager, "add_child", new_rp, true )
	undo_redo.add_do_method( new_rp, "set_owner", self.get_tree( ).get_edited_scene_root( ) )
	undo_redo.add_do_property( new_rp, "global_transform", detect_tf )

	if selected_road_point:
		var next: = selected_road_point.get_next_point( )

		undo_redo.add_do_method( selected_road_point, "set_next_point", new_rp )
		undo_redo.add_do_method( new_rp, "set_prev_point", selected_road_point )

		if next and next is RoadPoint:
			undo_redo.add_do_method( new_rp, "set_next_point", next )
			undo_redo.add_do_method( next, "set_prev_point", new_rp )

	undo_redo.add_do_property( selected_road_manager, "deny_generate", false )
	undo_redo.add_do_method( selected_road_manager, "on_road_point_update", null )
	undo_redo.add_do_method( self, "_set_selection_node", new_rp )
	undo_redo.add_do_reference( new_rp )

	undo_redo.add_undo_method( selected_road_manager, "remove_child", new_rp )
	undo_redo.add_undo_method( selected_road_manager, "on_road_point_update", null )

	undo_redo.commit_action( )

	return EditorPlugin.AFTER_GUI_INPUT_STOP

## 道削除
## @param	camera	カメラ
## @param	event	イベント内容
## @return	
func _do_event_road_remove( camera:Camera3D, event:InputEvent ) -> int:
	self._selected_point_coord = Vector2( -100, -100 )

	# 一番近いものを選択
	var selected_road_manager: = self._get_selected_road_manager( )
	if selected_road_manager == null:
		self.update_overlays( )
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	var target: = self._get_closest_road_point_from_mouse( camera, event )
	if target == null or not ( event is InputEventMouseButton ):
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	event as InputEventMouseButton
	if event.button_index != MOUSE_BUTTON_LEFT:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if not event.pressed:
		return EditorPlugin.AFTER_GUI_INPUT_STOP

	var undo_redo: = self.get_undo_redo( )
	undo_redo.create_action( "RoadPointを削除" )

	undo_redo.add_do_property( selected_road_manager, "deny_generate", true )
	if target.get_prev_point( ):
		undo_redo.add_do_method( target.get_prev_point( ), "set_next_point", target.get_next_point( ) )
	if target.get_next_point( ):
		undo_redo.add_do_method( target.get_next_point( ), "set_prev_point", target.get_prev_point( ) )
	undo_redo.add_do_method( target.get_next_point( ), "set_prev_point", target.get_prev_point( ) )
	undo_redo.add_do_method( target.get_parent( ), "remove_child", target )
	undo_redo.add_do_property( selected_road_manager, "deny_generate", false )
	undo_redo.add_do_method( selected_road_manager, "on_road_point_update", null )

	undo_redo.add_undo_method( target.get_parent( ), "add_child", target )
	undo_redo.add_undo_method( target, "set_owner", self.get_tree( ).get_edited_scene_root( ) )
	if target.get_prev_point( ):
		undo_redo.add_undo_method( target.get_prev_point( ), "set_next_point", target )
	if target.get_next_point( ):
		undo_redo.add_undo_method( target.get_next_point( ), "set_prev_point", target )
	undo_redo.add_undo_method( selected_road_manager, "on_road_point_update", null )
	undo_redo.add_undo_reference( target )

	undo_redo.commit_action( )

	return EditorPlugin.AFTER_GUI_INPUT_STOP

## 選択中の区間を修正する
func _on_selected_road_fix( ) -> void:
	var base_road_point: = self._get_selected_road_point()
	if base_road_point == null:
		return

	


	#var undo_redo: = self.get_undo_redo( )
	#undo_redo.create_action( "RoadPointの接続を一方向に修正" )

	#undo_redo.commit_action( )
