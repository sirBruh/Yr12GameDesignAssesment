@tool

extends HBoxContainer

#
# 道ポイント、交差点設定補助ツール
#

class_name RoadToolbar

enum RoadToolMode {
	Select,
	Add,
	Remove,
}

# --------------------------------------------------------------------------------------------------

var select_button:Button
var add_button:Button
var remove_button:Button
var menu_button:MenuButton

var mode:RoadToolMode = RoadToolMode.Add
var road_manager:RoadManager = null :
	set( _road_manager ):
		if road_manager == null:
			# 新たな設定であれば
			self.mode = RoadToolMode.Select
			if self.select_button:
				self.select_button.button_pressed = true
			if self.add_button:
				self.add_button.button_pressed = false
			if self.remove_button:
				self.remove_button.button_pressed = false

		road_manager = _road_manager

# --------------------------------------------------------------------------------------------------

signal on_selected_road_fix

# --------------------------------------------------------------------------------------------------

func _enter_tree( ) -> void:
	self._init_buttons( )
	self._init_menus( )

func _init_buttons( ) -> void:
	self.select_button = $Select
	self.add_button = $Add
	self.remove_button = $Remove
	self.menu_button = $Menu

	self.mode = RoadToolMode.Select
	self.select_button.button_pressed = true
	self.add_button.button_pressed = false
	self.remove_button.button_pressed = false

	var editor_theme: = EditorInterface.get_editor_theme( )
	self.select_button.icon = editor_theme.get_icon( "CurveEdit", "EditorIcons" )
	self.add_button.icon = editor_theme.get_icon( "CurveCreate", "EditorIcons" )
	self.remove_button.icon = editor_theme.get_icon( "CurveDelete", "EditorIcons" )

func _init_menus( ):
	var popup: = self.menu_button.get_popup( )
	popup.clear( )
	popup.add_item( "Fix road connection" )
	if not popup.id_pressed.is_connected( self._on_select_menu_id_pressed ):
		popup.id_pressed.connect( self._on_select_menu_id_pressed )

func _on_select_pressed() -> void:
	self.mode = RoadToolMode.Select
	self.select_button.button_pressed = true
	self.add_button.button_pressed = false
	self.remove_button.button_pressed = false

func _on_add_pressed( ) -> void:
	self.mode = RoadToolMode.Add
	self.select_button.button_pressed = false
	self.add_button.button_pressed = true
	self.remove_button.button_pressed = false

func _on_remove_pressed( ) -> void:
	self.mode = RoadToolMode.Remove
	self.select_button.button_pressed = false
	self.add_button.button_pressed = false
	self.remove_button.button_pressed = true

func _on_select_menu_id_pressed( id:int ) -> void:
	match id:
		0:
			self.on_selected_road_fix.emit( )
