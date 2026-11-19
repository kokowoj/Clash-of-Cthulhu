extends Control

const MenuButtonStyle = preload(
	"res://menu_button_style.gd"
)

@export var button_frame_png: Texture2D = preload(
	"res://art/title/button.png"
)

@export var player_2_victory_texture: Texture2D

@onready var background: TextureRect = $Background
@onready var winner_artwork: TextureRect = $WinnerArtwork
@onready var winner_name: Label = $WinnerName
@onready var wins_label: Label = $WinsLabel
@onready var player_label: Label = $PlayerLabel

@onready var dialogue_name: Label = $DialogueName
@onready var dialogue_text: Label = $DialogueText

@onready var rematch_button: Button = $RematchButton
@onready var character_button: Button = $CharacterButton
@onready var main_menu_button: Button = $MainMenuButton

const PLAYER_1_GREEN = Color("#65DF7C")
const PLAYER_2_RED = Color("#DF6565")

var button_style = MenuButtonStyle.new()

var winning_player: int = 1
var changing_scene: bool = false

var hover_sound: AudioStreamPlayer

var hover_stream: AudioStream = preload(
	"res://audio/Menu Item Hover.wav"
)

var select_stream: AudioStream = preload(
	"res://audio/Menu Item Select.wav"
)


func _ready() -> void:
	# Receive the winner from the completed match
	winning_player = int(
		get_tree().get_meta("victory_winner", 1)
	)

	if get_tree().has_meta("victory_winner"):
		get_tree().remove_meta("victory_winner")

	# Configure the victory artwork and text
	_setup_winner()

	# Apply the existing menu button style
	_setup_buttons()

	# Prepare menu audio
	_setup_audio()


func _setup_winner() -> void:
	winner_name.text = "DAGON"
	wins_label.text = "WINS"

	dialogue_name.text = "DAGON"
	dialogue_text.text = "Raaargh!"

	if winning_player == 1:
		_setup_player_1()
	else:
		_setup_player_2()


func _setup_player_1() -> void:
	player_label.text = "PLAYER 1"

	player_label.add_theme_color_override(
		"font_color",
		PLAYER_1_GREEN
	)

	background.modulate = Color.WHITE

	# Preserve the original victory artwork and layout
	winner_artwork.show()


func _setup_player_2() -> void:
	player_label.text = "PLAYER 2"

	player_label.add_theme_color_override(
		"font_color",
		PLAYER_2_RED
	)

	# Give the existing background a darker alternate tint
	background.modulate = Color("#D9A5A5")

	if player_2_victory_texture != null:
		winner_artwork.texture = player_2_victory_texture

		# Position the temporary red Dagon splash
		winner_artwork.set_anchors_and_offsets_preset(
			Control.PRESET_TOP_LEFT
		)

		winner_artwork.position = Vector2(45, 80)
		winner_artwork.size = Vector2(1290, 620)

		winner_artwork.expand_mode = (
			TextureRect.EXPAND_IGNORE_SIZE
		)

		winner_artwork.stretch_mode = (
			TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		)

		winner_artwork.show()
	else:
		# Avoid showing the wrong character as the winner
		winner_artwork.hide()

		push_warning(
			"Player 2 victory texture has not been assigned"
		)


func _setup_buttons() -> void:
	button_style.prepare(button_frame_png)

	rematch_button.text = "REMATCH"
	character_button.text = "CHARACTER"
	main_menu_button.text = "MAIN MENU"

	for button in [
		rematch_button,
		character_button,
		main_menu_button
	]:
		button.disabled = false
		button.focus_mode = Control.FOCUS_NONE

		button_style.setup_button(button)

		button.mouse_entered.connect(
			_play_hover_sound
		)

	rematch_button.pressed.connect(
		_on_rematch_pressed
	)

	character_button.pressed.connect(
		_on_character_pressed
	)

	main_menu_button.pressed.connect(
		_on_main_menu_pressed
	)


func _setup_audio() -> void:
	hover_sound = AudioStreamPlayer.new()

	add_child(hover_sound)

	hover_sound.stream = hover_stream

	if AudioServer.get_bus_index("SFX") != -1:
		hover_sound.bus = "SFX"


func _play_hover_sound() -> void:
	if changing_scene:
		return

	if hover_sound != null:
		hover_sound.play()


func _play_select_sound() -> void:
	var player = AudioStreamPlayer.new()

	get_tree().root.add_child(player)

	player.stream = select_stream

	if AudioServer.get_bus_index("SFX") != -1:
		player.bus = "SFX"

	player.finished.connect(player.queue_free)

	player.play()


func _prepare_navigation(
	selected_button: Button
) -> void:
	changing_scene = true

	_play_select_sound()

	# Keep the selected button text white
	selected_button.add_theme_color_override(
		"font_disabled_color",
		Color.WHITE
	)

	for button in [
		rematch_button,
		character_button,
		main_menu_button
	]:
		button.disabled = true

		button_style.reset_button(button)


func _on_rematch_pressed() -> void:
	if changing_scene:
		return

	_prepare_navigation(rematch_button)

	AudioManager.stop_music()

	# Play the existing start match announcement
	await AudioManager.play_start_match()

	# Load a fresh match
	get_tree().change_scene_to_file(
		"res://dagon_testing.tscn"
	)


func _on_character_pressed() -> void:
	if changing_scene:
		return

	_prepare_navigation(character_button)

	AudioManager.stop_music()

	get_tree().change_scene_to_file(
		"res://player_select.tscn"
	)


func _on_main_menu_pressed() -> void:
	if changing_scene:
		return

	_prepare_navigation(main_menu_button)

	AudioManager.play_main_theme()

	get_tree().change_scene_to_file(
		"res://main_menu.tscn"
	)
