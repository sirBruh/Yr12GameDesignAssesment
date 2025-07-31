@tool
extends Node3D

#
# 道マネージャ
#

class_name RoadManager

# --------------------------------------------------------------------------------------------------

## 通行方向
enum RoadTrafficSide {
	LEFT,			## 左側通行
	RIGHT,			## 右側通行
}

# --------------------------------------------------------------------------------------------------

@export_group( "General" )

## 通行方向
@export var traffic_side:RoadTrafficSide = RoadTrafficSide.LEFT:
	set( _traffic_side ):
		traffic_side = _traffic_side
		self._rebuild_roads( )

## 道定義
@export var road_class:RoadClass = null:
	set( _road_class ):
		road_class = _road_class
		self._rebuild_roads( )

@export_group( "Geometry" )

## 道レンダーレイヤー
@export_flags_3d_render var layers:int = 1:
	set( _layers ):
		layers = _layers
		self._rebuild_roads( )

## 道分割数 per meter
@export var road_loop_cut_per_meter:float = 1.0:
	set( _road_loop_cut_per_meter ):
		road_loop_cut_per_meter = _road_loop_cut_per_meter
		self._rebuild_roads( )

## 道分割数 per meter （編集中）
@export var edit_road_loop_cut_per_meter:float = 4.0:
	set( _edit_road_loop_cut_per_meter ):
		edit_road_loop_cut_per_meter = _edit_road_loop_cut_per_meter
		self._rebuild_roads( )

@export_group( "Visibility Range" )
@export var visibility_range_begin:float = 0.0
@export var visibility_range_begin_margin:float = 0.0
@export var visibility_range_end:float = 0.0
@export var visibility_range_end_margin:float = 0.0
@export var visibility_range_fade_mode:GeometryInstance3D.VisibilityRangeFadeMode = GeometryInstance3D.VisibilityRangeFadeMode.VISIBILITY_RANGE_FADE_DISABLED

# --------------------------------------------------------------------------------------------------

## 生成したノードを乗せるノード
var _generated_nodes:Node = null
## 道検索用AStar3D
var _astar3d:AStar3D = AStar3D.new( )
## 全ポイント
var _all_points:Array[BaseRoadPoint] = []
## 閉鎖空間
var _all_segments:Array[ProceduralRoadSegment] = []
## 交差点
var _all_intersections:Array[ProceduralRoadIntersection] = []

## 多重生成防止用：生成不許可フラグ
var deny_generate:bool = false

# --------------------------------------------------------------------------------------------------

## 道分割数取得
func get_road_loop_cut_per_meter( ) -> float:
	return self.edit_road_loop_cut_per_meter if Engine.is_editor_hint( ) else self.road_loop_cut_per_meter

## 全ての道を取得する
func get_all_road_points( ) -> Array[RoadPoint]:
	var result:Array[RoadPoint] = []

	var queue:Array[Node] = [self]
	while not queue.is_empty( ):
		var t:Node = queue.pop_front( )
		if t is RoadPoint:
			result.append( t )

		for c in t.get_children( ):
			queue.push_back( c )

	return result

# --------------------------------------------------------------------------------------------------

## 生成済み道を削除
func _clear_generated_roads( ) -> void:
	if self._generated_nodes:
		self._generated_nodes.queue_free( )
		self._generated_nodes = null

	self._generated_nodes = Node.new( )
	self.add_child( self._generated_nodes, false, Node.INTERNAL_MODE_FRONT )

	self._all_points.clear( )
	self._all_segments.clear( )
	self._astar3d.clear( )

## 道を生成する
func _rebuild_roads( ) -> void:
	if self.deny_generate:
		return

	if not self.is_inside_tree( ):
		return

	self._clear_generated_roads( )

	if self.road_class == null:
		return

	self._fetch_road_points( self )
	self._generate( )

## 再帰的にポイントに道ポイントIDを降る
## @param	node	走査中のノード
func _fetch_road_points( node:Node ) -> void:
	if node is RoadPoint:
		node.road_point_id = self._all_points.size( )
		node.close_segment_id = -1
		self._all_points.append( node )
	elif node is RoadIntersection:
		node.road_point_id = self._all_points.size( )
		self._all_points.append( node )

	for c in node.get_children( ):
		self._fetch_road_points( c )

## 生成開始
func _generate( ) -> void:
	for t in self._all_points:
		if t is RoadPoint:
			self._generate_road_segment( t )
		elif t is RoadIntersection:
			self._generate_road_intersection( t )

## 閉鎖空間道生成
## @param	start	探索開始ポイント
func _generate_road_segment( start:RoadPoint ) -> void:
	if start.close_segment_id != -1:
		return

	var close_segment_id:int = self._all_segments.size( )
	var has_error:bool = false
	var road_point_string:Array[RoadPoint] = [start]
	var queue:Array[RoadPoint] = [start]
	while not queue.is_empty( ):
		var rp:RoadPoint = queue.pop_front( )

		if rp.close_segment_id == -1:
			rp.close_segment_id = close_segment_id

			var next: = rp.get_next_point( )
			if next and next is RoadPoint:
				if next.close_segment_id == close_segment_id:
					pass
				elif not road_point_string.has( next ):
					queue.push_front( next )
					road_point_string.push_back( next )

			var prev: = rp.get_prev_point( )
			if prev and prev is RoadPoint:
				if prev.close_segment_id == close_segment_id:
					pass
				elif not road_point_string.has( prev ):
					queue.push_back( prev )
					road_point_string.push_front( prev )
		else:
			printerr( "An error occured while fetching the road segment. the connection is uncomfortable." )
			has_error = true

	var loop:bool = (
		road_point_string[0].get_prev_point( ) == road_point_string[-1]
	and road_point_string[-1].get_next_point( ) == road_point_string[0]
	)

	var prs: = ProceduralRoadSegment.new( self, road_point_string, loop )
	self._all_segments.append( prs )
	self._generated_nodes.add_child( prs )
	if not has_error:
		#var start_time: = Time.get_ticks_usec( )
		prs.generate_mesh( )
		#print( "Segment %d : %d usec" % [close_segment_id, Time.get_ticks_usec( ) - start_time] )

## 交差点の生成を行う
## @param	intersection	交差点
func _generate_road_intersection( intersection:RoadIntersection ) -> void:
	var has_error:bool = false
	var connected_with:Array[RoadPoint] = []

	for t in intersection.connected_with:
		var node:Node = intersection.get_node_or_null( t )
		if node is RoadPoint:
			connected_with.append( node )
		else:
			printerr( "An error occured while fetching the road intersection. the connection is null.")
			has_error = true

	var pri: = ProceduralRoadIntersection.new( self, intersection, connected_with )
	self._all_intersections.append( pri )
	self._generated_nodes.add_child( pri )
	if not has_error:
		#var start_time: = Time.get_ticks_usec( )
		pri.generate_mesh( )
		#print( "Intersection : %d usec" % [Time.get_ticks_usec( ) - start_time] )

# --------------------------------------------------------------------------------------------------

func _ready( ):
	self._rebuild_roads( )

# --------------------------------------------------------------------------------------------------

## 道がアップデートされたとき
func on_road_point_update( _road_point:BaseRoadPoint ) -> void:
	# TODO: 更新されたものだけアップデートする
	self._rebuild_roads( )
