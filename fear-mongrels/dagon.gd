extends "res://fighter_combat.gd"


func _init() -> void:
	# Preserve Red Dagon's original sprite positioning
	idle_position_y = -240.0
	walk_position_y = -240.0


func _configure_controls() -> void:
	# Player 2 controls
	left_action = "ui_left"
	right_action = "ui_right"

	jump_action = "ui_accept"

	punch_action = "punch"
	kick_action = "kick"

	block_action = "block"
