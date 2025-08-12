@tool
extends BaseRoadPoint

#
# 交差点
#

class_name RoadIntersection

## 連結先
@export_node_path("RoadPoint") var connected_with:Array[NodePath] = []

# --------------------------------------------------------------------------------------------------

## 設定時の警告
func _get_configuration_warnings( ) -> PackedStringArray:
	if self._get_road_manager( ) == null:
		return ["Must be a child of a RoadManager"]

	for t in self.connected_with:
		var next:Node = self.get_node_or_null( t )
		if next and next is RoadIntersection:
			return ["Cannot connection between RoadIntersection(s)"]

	if self.connected_with.size( ) <= 2:
		return ["Must be connected with more than two RoadPoint(s)."]

	return []

func has_road_point( rp:RoadPoint ) -> bool:
	for t in self.connected_with:
		if self.get_node_or_null( t ) == rp:
			return true

	return false
