extends MarginContainer

onready var language := $VBoxContainer/Language

onready var copyright := $Windows/Copyright
onready var software_tabs := copyright.get_node("MarginContainer/TabContainer/Software")
onready var licenses_tabs := copyright.get_node("MarginContainer/TabContainer/Licenses")

func _ready() -> void:
	### LOCALES ###
	
	var locales := TranslationServer.get_loaded_locales()
	locales.sort()
	locales.erase("en_US")
	locales.push_front("en_US")
	for code in locales:
		var id: int = language.get_item_count()
		language.add_item(TranslationServer.get_locale_name(code), id)
		language.set_item_metadata(id, code)
	
	### COPYRIGHT ###
	
	for item in Copyright.software:
		var label := RichTextLabel.new()
		label.text = Copyright.software[item]
		software_tabs.add_child(label)
		software_tabs.set_tab_title(label.get_index(), item)
	
	for item in Copyright.licenses:
		var label := RichTextLabel.new()
		label.text = Copyright.licenses[item]
		licenses_tabs.add_child(label)
		licenses_tabs.set_tab_title(label.get_index(), item)
	
	update_config()
	Global.ok(Global.profile.connect("changed", self, "update_config"))

func update_config() -> void:
	$VBoxContainer/Animations/VBoxContainer/AnimationsEnabled.pressed = Global.profile.animations_enabled
	$VBoxContainer/Animations/VBoxContainer/AnimationSpeed.visible = Global.profile.animations_enabled
	$VBoxContainer/Animations/VBoxContainer/AnimationSpeed/HSlider.value = Global.profile.animation_speed
	
	for i in language.get_item_count():
		if language.get_item_metadata(i) == Global.profile.language:
			language.selected = i
			language.text = tr("SETTINGS_LANGUAGE").format([TranslationServer.get_locale_name(Global.profile.language)])

func _on_AnimationsEnabled_toggled(button_pressed: bool) -> void:
	Global.profile.animations_enabled = button_pressed
	if not Global.profile.animations_enabled:
		Global.profile.animation_speed = 1.0

func _on_AnimationSpeed_value_changed(value: float) -> void:
	Global.profile.animation_speed = value

func _on_Language_item_selected(index: int) -> void:
	Global.profile.language = language.get_item_metadata(index)

func _on_ShowCopyright_pressed() -> void:
	copyright.popup_centered_clamped(Vector2(800.0, 480.0))
