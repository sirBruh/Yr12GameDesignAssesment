extends Marker3D

#
# 基本クラス：道地点
#

class_name BaseRoadPoint

## 生成時に付与する道ポイントID
var road_point_id:int = -1

# --------------------------------------------------------------------------------------------------

## 道マネージャを取得
func _get_road_manager( ) -> RoadManager:
	if not self.is_inside_tree( ):
		return null

	var node:Node = self

	while node:
		if node is RoadManager:
			return node
		node = node.get_parent( )

	return null

# --------------------------------------------------------------------------------------------------

## 設定時の警告
func _get_configuration_warnings( ) -> PackedStringArray:
	return ["BaseRoadPoint can't be used standalone."]

# --------------------------------------------------------------------------------------------------

## 通知処理
## @param	what	事項
func _notification( what: int ) -> void:
	if not Engine.is_editor_hint( ):
		return

	match what:
		NOTIFICATION_TRANSFORM_CHANGED:
			_emit_on_road_point_update( )

## 道マネージャに対して変更を通知する
func _emit_on_road_point_update( ) -> void:
	var rm: = self._get_road_manager( )
	if rm:
		rm.on_road_point_update( self )
