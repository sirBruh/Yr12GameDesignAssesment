@tool
extends BaseRoadPoint

#
# 道地点
#

class_name RoadPoint

## 前の道ポイントへのパス
@export_node_path("BaseRoadPoint") var prev_road_point_path:NodePath:
	set( _prev_road_point_path ):
		prev_road_point_path = _prev_road_point_path
		self._emit_on_road_point_update( )
## 次の道ポイントへのパス
@export_node_path("BaseRoadPoint") var next_road_point_path:NodePath:
	set( _next_road_point_path ):
		next_road_point_path = _next_road_point_path
		self._emit_on_road_point_update( )

## 左車線
@export var left_lanes:int = 1:
	set( _left_lanes ):
		left_lanes = _left_lanes
		self._emit_on_road_point_update( )

## 右車線
@export var right_lanes:int = 1:
	set( _right_lanes ):
		right_lanes = _right_lanes
		self._emit_on_road_point_update( )

## 生成時に付与する閉鎖空間ID
var close_segment_id:int = -1

# --------------------------------------------------------------------------------------------------

## 前のポイントを設定
func set_prev_point( rp:BaseRoadPoint ) -> void:
	if rp == null:
		self.prev_road_point_path = NodePath( )
	else:
		self.prev_road_point_path = self.get_path_to( rp )

## 前のポイントを取得
func get_prev_point( ) -> BaseRoadPoint:
	return self.get_node_or_null( self.prev_road_point_path )

## 次のポイントを設定
func set_next_point( rp:BaseRoadPoint ) -> void:
	if rp == null:
		self.next_road_point_path = NodePath( )
	else:
		self.next_road_point_path = self.get_path_to( rp )

## 次のポイントを取得
func get_next_point( ) -> BaseRoadPoint:
	return self.get_node_or_null( self.next_road_point_path )

# --------------------------------------------------------------------------------------------------

## 設定時の警告
func _get_configuration_warnings( ) -> PackedStringArray:
	if self._get_road_manager( ) == null:
		return ["Must be a child of a RoadManager"]

	var next:Node = self.get_node_or_null( self.next_road_point_path )
	if next:
		if next is RoadPoint:
			next as BaseRoadPoint
			if next.get_node_or_null( next.prev_road_point_path ) != self:
				return ["Must be fixes next_road_point_path of this segment"]
		elif next is RoadIntersection:
			next as RoadIntersection
			if not next.has_road_point( self ):
				return ["Must be fixes next_road_point_path of this segment"]

	var prev:Node = self.get_node_or_null( self.prev_road_point_path )
	if prev:
		if prev is RoadPoint:
			prev as RoadPoint
			if prev.get_node_or_null( prev.next_road_point_path ) != self:
				return ["Must be fixes prev_road_point_path of this segment"]
		elif prev is RoadIntersection:
			prev as RoadIntersection
			if not prev.has_road_point( self ):
				return ["Must be fixes next_road_point_path of this segment"]

	return []
