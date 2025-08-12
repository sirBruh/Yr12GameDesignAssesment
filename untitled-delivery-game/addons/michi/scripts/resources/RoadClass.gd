extends Resource

#
# 道種類
#

class_name RoadClass

## 名前
@export var name:String = ""

@export_group("Road")

@export_subgroup("General")
## 道幅
@export var road_width:float = 3.25
## 道高さ
@export var road_height:float = 0.02
## 道マテリアル
@export var road_material:Material

@export_subgroup("Intersection")
## 交差点マテリアル
@export var intersection_material:Material
## 交差点接続マテリアル
@export var connection_intersection_material:Material

@export_subgroup("Collision")
## オフ
@export var road_disable_mode:CollisionObject3D.DisableMode = CollisionObject3D.DisableMode.DISABLE_MODE_REMOVE
## 道物理レイヤー
@export_flags_3d_physics var road_collision_layer:int = 1
## 道物理マスク
@export_flags_3d_physics var road_collision_mask:int = 1
## 当たり判定優先度
@export var road_collision_priority:float = 1.0

@export_group("Sidewalk")
@export_subgroup("General")
## 歩道あり？
@export var has_sidewalk:bool = false
## 歩道幅
@export var sidewalk_width:float = 0.8
## 道高さ
@export var sidewalk_height:float = 0.08
## 歩道マテリアル
@export var sidewalk_material:Material

@export_subgroup("Collision")
## 歩道オフ
@export var sidewalk_disable_mode:CollisionObject3D.DisableMode = CollisionObject3D.DisableMode.DISABLE_MODE_REMOVE
## 歩道物理レイヤー
@export_flags_3d_physics var sidewalk_collision_layer:int = 1
## 歩道物理マスク
@export_flags_3d_physics var sidewalk_collision_mask:int = 1
## 歩道当たり判定優先度
@export var sidewalk_collision_priority:float = 1.0
