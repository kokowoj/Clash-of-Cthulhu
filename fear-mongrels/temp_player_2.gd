extends "res://fighter_combat.gd"


func _init() -> void:
	# Preserve Blue Dagon's original sprite positioning
	idle_position_y = -145.0
	walk_position_y = -145.0


func _configure_controls() -> void:
	# Player 1 controls
	left_action = "p2_left"
	right_action = "p2_right"

	jump_action = "p2_jump"

	punch_action = "p2_light_punch"
	kick_action = "p2_light_kick"

	block_action = "p2_block"
