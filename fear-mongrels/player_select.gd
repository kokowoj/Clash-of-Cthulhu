extends Control

const MenuButtonStyle = preload(
	"res://menu_button_style.gd"
)

@onready var dagon_portrait: TextureButton = $CharacterGrid/DagonPortrait
@onready var dagon_splash: TextureRect = $DagonSplash
@onready var dagon_name: Label = $DagonName

@onready var alt_portrait: TextureButton = $CharacterGrid/AltDagonPortrait
@onready var alt_splash: TextureRect = $AltDagonSplash
@onready var alt_name: Label = $AltDagonName

@onready var player_label: Label = $PlayerLabel
@onready var alt_player_label: Label = $AltPlayerLabel

@onready var character_grid: GridContainer = $CharacterGrid
@onready var confirm_button: Button = $ConfirmButton

@export var button_frame_png: Texture2D = preload(
	"res://art/title/button.png"
)

const HOVER_GREEN = Color("#65DF7C")
const ALT_RED = Color("#DF6565")

const HOVER_SPEED = 0.15
const GLOW_BLUR_RADIUS = 12

var button_style = MenuButtonStyle.new()

var dagon_selected: bool = false
var alt_selected: bool = false
var match_starting: bool = false

var portrait_glow: TextureRect
var alt_glow: TextureRect

var portrait_tween: Tween
var alt_tween: Tween

var hover_sound: AudioStreamPlayer

var select_stream: AudioStream = preload(
	"res://audio/Menu Item Select.wav"
)

var hover_stream: AudioStream = preload(
	"res://audio/Menu Item Hover.wav"
)


func _ready() -> void:
	AudioManager.play_select_fighter()

	# Preserve grid sizing and spacing from the Inspector
	for child in character_grid.get_children():
		if child is TextureButton:
			child.ignore_texture_size = true

			child.stretch_mode = (
				TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			)

			child.focus_mode = Control.FOCUS_NONE

			child.disabled = (
				child != dagon_portrait
				and child != alt_portrait
			)

			if child.disabled:
				if child.texture_disabled == null:
					child.texture_disabled = child.texture_normal

	# Use splash artwork for both selectable characters
	dagon_portrait.texture_normal = dagon_splash.texture
	alt_portrait.texture_normal = alt_splash.texture

	for button in [
		dagon_portrait,
		alt_portrait
	]:
		button.texture_hover = null
		button.texture_pressed = null
		button.texture_focused = null

	# Hide previews until hovered or selected
	for preview in [
		dagon_splash,
		alt_splash,
		dagon_name,
		alt_name
	]:
		preview.hide()
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Set character names and player labels
	dagon_name.text = "DAGON"
	alt_name.text = "DAGON"

	player_label.text = "PLAYER 1"
	alt_player_label.text = "PLAYER 2"

	dagon_name.add_theme_color_override(
		"font_color",
		HOVER_GREEN
	)

	alt_name.add_theme_color_override(
		"font_color",
		ALT_RED
	)

	player_label.add_theme_color_override(
		"font_color",
		HOVER_GREEN
	)

	alt_player_label.add_theme_color_override(
		"font_color",
		ALT_RED
	)

	player_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alt_player_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	player_label.show()
	alt_player_label.show()

	# Apply the shared menu button styling
	confirm_button.disabled = true

	button_style.prepare(button_frame_png)
	button_style.setup_button(confirm_button)

	# Prepare character selection glows
	portrait_glow = _setup_portrait_glow(
		dagon_portrait,
		HOVER_GREEN
	)

	alt_glow = _setup_portrait_glow(
		alt_portrait,
		ALT_RED
	)

	# Prepare hover audio
	hover_sound = AudioStreamPlayer.new()

	add_child(hover_sound)

	hover_sound.stream = hover_stream

	if AudioServer.get_bus_index("SFX") != -1:
		hover_sound.bus = "SFX"

	# Connect Dagon signals
	dagon_portrait.mouse_entered.connect(
		_on_dagon_hovered
	)

	dagon_portrait.mouse_exited.connect(
		_on_dagon_unhovered
	)

	dagon_portrait.pressed.connect(
		_on_dagon_selected
	)

	# Connect alternate Dagon signals
	alt_portrait.mouse_entered.connect(
		_on_alt_hovered
	)

	alt_portrait.mouse_exited.connect(
		_on_alt_unhovered
	)

	alt_portrait.pressed.connect(
		_on_alt_selected
	)

	# Connect Confirm button audio and selection
	confirm_button.mouse_entered.connect(
		_on_confirm_hovered
	)

	confirm_button.pressed.connect(
		_on_confirm_pressed
	)


func _setup_portrait_glow(
	button: TextureButton,
	color: Color
) -> TextureRect:
	var portrait_texture = button.texture_normal

	if portrait_texture == null:
		return null

	var image = portrait_texture.get_image()

	if image.is_compressed():
		image.decompress()

	image.convert(Image.FORMAT_RGBA8)

	var used_rect = image.get_used_rect()

	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		return null

	var cropped = image.get_region(used_rect)

	var padding = maxi(
		16,
		roundi(cropped.get_width() * 0.15)
	)

	var padded = Image.create_empty(
		cropped.get_width() + padding * 2,
		cropped.get_height() + padding * 2,
		false,
		Image.FORMAT_RGBA8
	)

	padded.fill(Color.TRANSPARENT)

	padded.blit_rect(
		cropped,
		Rect2i(
			Vector2i.ZERO,
			cropped.get_size()
		),
		Vector2i(padding, padding)
	)

	var small = padded.duplicate()

	small.resize(
		maxi(
			1,
			roundi(padded.get_width() * 0.20)
		),
		maxi(
			1,
			roundi(padded.get_height() * 0.20)
		),
		Image.INTERPOLATE_BILINEAR
	)

	var blurred = MenuButtonStyle.blur_alpha(
		small,
		GLOW_BLUR_RADIUS
	)

	blurred.resize(
		padded.get_width(),
		padded.get_height(),
		Image.INTERPOLATE_BILINEAR
	)

	var glow = TextureRect.new()

	glow.name = "CharacterGlow"

	glow.texture = ImageTexture.create_from_image(
		blurred
	)

	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.show_behind_parent = true

	glow.modulate = Color(
		color.r,
		color.g,
		color.b,
		0.0
	)

	button.add_child(glow)

	_position_slot_glow(
		button,
		glow
	)

	button.resized.connect(
		_position_slot_glow.bind(
			button,
			glow
		)
	)

	return glow


func _position_slot_glow(
	button: TextureButton,
	glow: TextureRect
) -> void:
	var padding = button.size * 0.12

	glow.position = -padding

	glow.size = (
		button.size + padding * 2.0
	)

	button.pivot_offset = button.size / 2.0


func _play_hover_sound() -> void:
	if hover_sound.stream != null:
		hover_sound.play()


func _play_select_sound() -> void:
	if select_stream == null:
		return

	var player = AudioStreamPlayer.new()

	get_tree().root.add_child(player)

	player.stream = select_stream

	if AudioServer.get_bus_index("SFX") != -1:
		player.bus = "SFX"

	player.finished.connect(
		player.queue_free
	)

	player.play()


# Player 1 character selection

func _on_dagon_hovered() -> void:
	if match_starting:
		return

	_play_hover_sound()

	dagon_splash.show()
	dagon_name.show()

	_update_slot_glow(false, true)


func _on_dagon_unhovered() -> void:
	if not dagon_selected:
		dagon_splash.hide()
		dagon_name.hide()

	_update_slot_glow(false, false)


func _on_dagon_selected() -> void:
	if match_starting:
		return

	dagon_selected = true

	_play_select_sound()

	dagon_splash.show()
	dagon_name.show()

	_update_slot_glow(false, true)
	_update_confirm_state()


# Player 2 character selection

func _on_alt_hovered() -> void:
	if match_starting:
		return

	_play_hover_sound()

	alt_splash.show()
	alt_name.show()

	_update_slot_glow(true, true)


func _on_alt_unhovered() -> void:
	if not alt_selected:
		alt_splash.hide()
		alt_name.hide()

	_update_slot_glow(true, false)


func _on_alt_selected() -> void:
	if match_starting:
		return

	alt_selected = true

	_play_select_sound()

	alt_splash.show()
	alt_name.show()

	_update_slot_glow(true, true)
	_update_confirm_state()


# Character glow management

func _update_slot_glow(
	is_alt: bool,
	hovered: bool
) -> void:
	var glow = (
		alt_glow if is_alt else portrait_glow
	)

	var selected = (
		alt_selected if is_alt else dagon_selected
	)

	var previous = (
		alt_tween if is_alt else portrait_tween
	)

	if previous and previous.is_valid():
		previous.kill()

	if glow == null:
		return

	var tween = create_tween()

	var alpha = 0.0

	if selected:
		alpha = 0.70
	elif hovered:
		alpha = 0.45

	tween.tween_property(
		glow,
		"modulate:a",
		alpha,
		HOVER_SPEED
	)

	if is_alt:
		alt_tween = tween
	else:
		portrait_tween = tween


# Confirm button management

func _update_confirm_state() -> void:
	confirm_button.disabled = not (
		dagon_selected and alt_selected
	)


func _on_confirm_hovered() -> void:
	if match_starting or confirm_button.disabled:
		return

	_play_hover_sound()


func _on_confirm_pressed() -> void:
	if match_starting or not (
		dagon_selected and alt_selected
	):
		return

	match_starting = true

	# Keep Confirm text white during the match announcement
	confirm_button.add_theme_color_override(
		"font_disabled_color",
		Color.WHITE
	)

	confirm_button.disabled = true

	button_style.reset_button(confirm_button)

	dagon_portrait.disabled = true
	alt_portrait.disabled = true

	_play_select_sound()

	# Play the Start Match announcement fully
	await AudioManager.play_start_match()

	# Enter the fighting arena
	get_tree().change_scene_to_file(
		"res://dagon_testing.tscn"
	)
