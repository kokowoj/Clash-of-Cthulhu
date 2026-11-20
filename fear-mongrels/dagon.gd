extends "res://fighter_combat.gd"


func _init() -> void:
	# Preserve Red Dagon's original sprite positioning
	idle_position_y = -240.0
	walk_position_y = -240.0


func _configure_controls() -> void:
	# Player 2 controls
	left_action = "p1_left"
	right_action = "p1_right"

	jump_action = "p1_jump"

	punch_action = "punch"
	kick_action = "kick"

	block_action = "block"
