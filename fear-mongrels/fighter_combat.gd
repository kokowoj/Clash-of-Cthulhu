extends CharacterBody2D

signal health_changed(new_health: int)
signal defeated

@export var speed: float = 200.0
@export var jump_velocity: float = -550.0

# Sprite positioning
@export var idle_position_y: float = -145.0
@export var walk_position_y: float = -145.0

@export var block_offset_y: float = 0.0
@export var stun_offset_y: float = 0.0
@export var stun2_offset_y: float = 0.0

# Health and damage
@export var max_health: int = 1000
@export var punch_damage: int = 75
@export var kick_damage: int = 100

# Attack hitbox settings
@export var punch_hitbox_size: Vector2 = Vector2(300, 140)
@export var kick_hitbox_size: Vector2 = Vector2(380, 160)

@export var punch_reach: float = 210.0
@export var kick_reach: float = 250.0

@export var punch_vertical_offset: float = -15.0
@export var kick_vertical_offset: float = 20.0

# Blocking and stun settings
@export var max_block_duration: float = 2.0
@export var block_cooldown_duration: float = 1.5
@export var stun_duration: float = 1.0
@export var stun_recovery_duration: float = 0.5

# Brief visual reaction during stun recovery
@export var hit_reaction_duration: float = 0.25

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox

@onready var hitbox_shape: CollisionShape2D = \
	$Hitbox/CollisionShape2D

@onready var hurtbox: Area2D = $Hurtbox

@onready var hurtbox_shape: CollisionShape2D = \
	$Hurtbox/CollisionShape2D

# Audio files
const PUNCH_SOUND: AudioStream = preload(
	"res://audio/Dagon - Light Punch-2.wav"
)

const KICK_SOUND: AudioStream = preload(
	"res://audio/Dagon - Light Kick-2.wav"
)

const IMPACT_SOUND: AudioStream = preload(
	"res://audio/Block.wav"
)

# Individual player controls
var left_action: String = ""
var right_action: String = ""
var jump_action: String = ""
var punch_action: String = ""
var kick_action: String = ""
var block_action: String = ""

var attack_sound: AudioStreamPlayer
var impact_sound: AudioStreamPlayer

var gravity: float = 980.0
var health: int = 1000

# Attack state
var is_attacking: bool = false
var attack_has_hit: bool = false

var current_attack_damage: int = 0
var current_attack_type: String = ""

var attack_rectangle: RectangleShape2D

# Blocking state
var is_blocking: bool = false
var block_time_left: float = 0.0
var block_cooldown_left: float = 0.0
var block_requires_release: bool = false

# Stun state
var is_stunned: bool = false
var stun_time_left: float = 0.0
var stun_recovery_left: float = 0.0
var stun_animation: String = "stun"

# Visual hit reaction
var hit_reaction_left: float = 0.0


func _ready() -> void:
	_configure_controls()

	health = max_health

	_setup_audio()
	_setup_hitbox()

	animated_sprite.animation_finished.connect(
		_on_animation_finished
	)

	animated_sprite.play("idle")

	_update_sprite_position()
	_update_hitbox_direction()


func _configure_controls() -> void:
	# Individual fighter scripts provide their own controls
	pass


func _setup_audio() -> void:
	attack_sound = AudioStreamPlayer.new()
	attack_sound.name = "AttackSound"
	add_child(attack_sound)

	impact_sound = AudioStreamPlayer.new()
	impact_sound.name = "ImpactSound"
	impact_sound.stream = IMPACT_SOUND
	add_child(impact_sound)

	if AudioServer.get_bus_index("SFX") != -1:
		attack_sound.bus = "SFX"
		impact_sound.bus = "SFX"


func _setup_hitbox() -> void:
	# Give each fighter an independent attack shape
	attack_rectangle = RectangleShape2D.new()
	attack_rectangle.size = punch_hitbox_size

	hitbox_shape.shape = attack_rectangle
	hitbox_shape.position = Vector2.ZERO

	_update_hitbox_direction()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	# Stop controls when defeated
	if health <= 0:
		velocity.x = 0.0
		move_and_slide()
		return

	_update_combat_timers(delta)

	# Prevent movement and attacks during full stun
	if is_stunned:
		velocity.x = 0.0

		change_animation(stun_animation)

		_update_sprite_position()
		move_and_slide()
		return

	# Check blocking input
	_handle_block_input()

	# Prevent movement and attacks while blocking
	if is_blocking:
		velocity.x = 0.0

		change_animation("block")

		_update_sprite_position()
		move_and_slide()
		return

	# Normal movement
	var direction := Input.get_axis(
		left_action,
		right_action
	)

	velocity.x = direction * speed

	# Face the movement direction
	if direction != 0:
		animated_sprite.flip_h = direction < 0

	_update_hitbox_direction()

	# Jump
	if Input.is_action_just_pressed(jump_action) \
	and is_on_floor() \
	and not is_attacking:
		velocity.y = jump_velocity

	# Punch
	if Input.is_action_just_pressed(punch_action) \
	and not is_attacking:
		_start_attack(
			"light_punch",
			punch_damage,
			"punch"
		)

	# Kick
	elif Input.is_action_just_pressed(kick_action) \
	and not is_attacking:
		_start_attack(
			"light_kick",
			kick_damage,
			"kick"
		)

	# Choose the appropriate visual animation
	if not is_attacking:

		# Display brief hit reactions during recovery
		if hit_reaction_left > 0.0:
			change_animation(stun_animation)

		elif not is_on_floor():
			change_animation("jump")

		elif direction != 0:
			change_animation("walk")

		else:
			change_animation("idle")

	_update_sprite_position()

	move_and_slide()

	# Check for damage during active attack frames
	if is_attacking:
		_check_attack_hit()


# Combat timers

func _update_combat_timers(delta: float) -> void:
	block_cooldown_left = maxf(
		block_cooldown_left - delta,
		0.0
	)

	stun_recovery_left = maxf(
		stun_recovery_left - delta,
		0.0
	)

	hit_reaction_left = maxf(
		hit_reaction_left - delta,
		0.0
	)

	# Require the player to release the block key
	if not Input.is_action_pressed(block_action):
		block_requires_release = false

	if is_blocking:
		block_time_left = maxf(
			block_time_left - delta,
			0.0
		)

		if block_time_left <= 0.0:
			_end_block()

	if is_stunned:
		stun_time_left = maxf(
			stun_time_left - delta,
			0.0
		)

		if stun_time_left <= 0.0:
			is_stunned = false

			stun_recovery_left = (
				stun_recovery_duration
			)


# Blocking

func _handle_block_input() -> void:
	if is_blocking:
		if not Input.is_action_pressed(block_action):
			_end_block()

		elif not is_on_floor():
			_end_block()

		return

	if is_attacking or is_stunned:
		return

	if not is_on_floor():
		return

	if block_requires_release:
		return

	if block_cooldown_left > 0.0:
		return

	if Input.is_action_just_pressed(block_action):
		_start_block()


func _start_block() -> void:
	is_blocking = true
	block_requires_release = true

	block_time_left = max_block_duration
	hit_reaction_left = 0.0

	velocity.x = 0.0

	animated_sprite.play("block")

	_update_sprite_position()


func _end_block() -> void:
	if not is_blocking:
		return

	is_blocking = false
	block_time_left = 0.0

	block_cooldown_left = (
		block_cooldown_duration
	)

	# A held key cannot automatically start another block
	block_requires_release = Input.is_action_pressed(
		block_action
	)


# Attack management

func _start_attack(
	animation_name: String,
	damage: int,
	attack_type: String
) -> void:
	is_attacking = true
	attack_has_hit = false

	hit_reaction_left = 0.0

	current_attack_damage = damage
	current_attack_type = attack_type

	_update_hitbox_direction()

	animated_sprite.stop()
	animated_sprite.play(animation_name)
	animated_sprite.set_frame_and_progress(0, 0.0)

	_play_attack_sound(animation_name)


func _play_attack_sound(
	animation_name: String
) -> void:
	if attack_sound == null:
		return

	match animation_name:
		"light_punch":
			attack_sound.stream = PUNCH_SOUND

		"light_kick":
			attack_sound.stream = KICK_SOUND

		_:
			return

	attack_sound.play()


func _play_impact_sound() -> void:
	if impact_sound != null:
		impact_sound.stop()
		impact_sound.play()


func _update_hitbox_direction() -> void:
	if attack_rectangle == null:
		return

	var facing: float = (
		-1.0 if animated_sprite.flip_h else 1.0
	)

	# Align attacks with the fighter's existing hurtbox
	var hurtbox_center: Vector2 = to_local(
		hurtbox_shape.global_position
	)

	if current_attack_type == "kick":
		attack_rectangle.size = kick_hitbox_size

		hitbox.position = Vector2(
			kick_reach * facing,
			hurtbox_center.y + kick_vertical_offset
		)

	else:
		attack_rectangle.size = punch_hitbox_size

		hitbox.position = Vector2(
			punch_reach * facing,
			hurtbox_center.y + punch_vertical_offset
		)


func _check_attack_hit() -> void:
	if attack_has_hit:
		return

	if not is_attacking:
		return

	# Check the active attack animation frames
	var frame_count: int = (
		animated_sprite.sprite_frames.get_frame_count(
			animated_sprite.animation
		)
	)

	if frame_count <= 0:
		return

	var first_active_frame: int = mini(
		2,
		frame_count - 1
	)

	var last_active_frame: int = mini(
		4,
		frame_count - 1
	)

	if animated_sprite.frame < first_active_frame:
		return

	if animated_sprite.frame > last_active_frame:
		return

	# Query the attack shape at its current position
	var query = PhysicsShapeQueryParameters2D.new()

	query.shape = attack_rectangle
	query.transform = hitbox_shape.global_transform

	query.collision_mask = hitbox.collision_mask

	query.collide_with_areas = true
	query.collide_with_bodies = false

	query.exclude = [
		hurtbox.get_rid(),
		hitbox.get_rid()
	]

	var results = get_world_2d().direct_space_state.intersect_shape(
		query,
		16
	)

	for result in results:
		var area = result.get("collider")

		if not area is Area2D:
			continue

		if area.name != "Hurtbox":
			continue

		var target = area.get_parent()

		if target == self:
			continue

		if not target.has_method("take_damage"):
			continue

		if not target.is_physics_processing():
			continue

		# Only allow one successful contact per attack
		attack_has_hit = true

		target.take_damage(
			current_attack_damage,
			current_attack_type
		)

		break


func _cancel_attack() -> void:
	is_attacking = false
	attack_has_hit = false

	current_attack_damage = 0
	current_attack_type = ""

	if attack_sound != null:
		attack_sound.stop()

	_update_hitbox_direction()


# Damage and stun reactions

func take_damage(
	amount: int,
	attack_type: String = "punch"
) -> void:
	if health <= 0:
		return

	if not is_physics_processing():
		return

	_play_impact_sound()

	# Successful blocks prevent all damage
	if is_blocking:
		return

	health = maxi(
		health - amount,
		0
	)

	health_changed.emit(health)

	# Handle knockout
	if health == 0:
		_cancel_attack()

		is_blocking = false
		is_stunned = false
		hit_reaction_left = 0.0

		velocity = Vector2.ZERO

		_play_hit_reaction(attack_type)

		defeated.emit()
		return

	# Replay the reaction when hit during an existing stun
	if is_stunned:
		_play_hit_reaction(attack_type)

		# Do not restart the full stun timer
		return

	# Show a brief reaction during recovery
	if stun_recovery_left > 0.0:
		_cancel_attack()

		hit_reaction_left = hit_reaction_duration

		_play_hit_reaction(attack_type)

		# Do not disable movement or new attack inputs
		return

	# Apply a normal stun
	_enter_stun(attack_type)


func _set_stun_animation(
	attack_type: String
) -> void:
	if attack_type == "kick":
		stun_animation = "stun2"
	else:
		stun_animation = "stun"


func _play_hit_reaction(
	attack_type: String
) -> void:
	# Choose the correct punch or kick reaction
	_set_stun_animation(attack_type)

	# Restart the animation even if it is already selected
	animated_sprite.stop()

	animated_sprite.play(stun_animation)

	animated_sprite.set_frame_and_progress(
		0,
		0.0
	)

	_update_sprite_position()


func _enter_stun(
	attack_type: String
) -> void:
	_cancel_attack()

	is_stunned = true

	stun_time_left = stun_duration
	hit_reaction_left = 0.0

	velocity.x = 0.0

	_play_hit_reaction(attack_type)


# Reset all states between rounds

func reset_health() -> void:
	health = max_health

	is_attacking = false
	attack_has_hit = false

	current_attack_damage = 0
	current_attack_type = ""

	is_blocking = false

	block_time_left = 0.0
	block_cooldown_left = 0.0
	block_requires_release = false

	is_stunned = false

	stun_time_left = 0.0
	stun_recovery_left = 0.0
	hit_reaction_left = 0.0

	stun_animation = "stun"

	velocity = Vector2.ZERO

	if attack_sound != null:
		attack_sound.stop()

	if impact_sound != null:
		impact_sound.stop()

	animated_sprite.play("idle")

	_update_sprite_position()
	_update_hitbox_direction()

	health_changed.emit(health)


# Sprite animation and positioning

func change_animation(
	new_animation: String
) -> void:
	if animated_sprite.animation != new_animation:
		animated_sprite.play(new_animation)


func _update_sprite_position() -> void:
	match animated_sprite.animation:
		"walk":
			animated_sprite.position.y = walk_position_y

		"block":
			animated_sprite.position.y = (
				idle_position_y + block_offset_y
			)

		"stun":
			animated_sprite.position.y = (
				idle_position_y + stun_offset_y
			)

		"stun2":
			animated_sprite.position.y = (
				idle_position_y + stun2_offset_y
			)

		_:
			animated_sprite.position.y = idle_position_y


func _on_animation_finished() -> void:
	if not is_attacking:
		return

	if animated_sprite.animation == "light_punch" \
	or animated_sprite.animation == "light_kick":
		is_attacking = false
		attack_has_hit = false

		current_attack_damage = 0
		current_attack_type = ""

		_update_hitbox_direction()
