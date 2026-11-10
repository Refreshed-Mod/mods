extends Node

var api: Variant

func _initialize_mod(context: Variant) -> Variant:
	api = context
	api.add_menu_action("Say hello", _hello)
	return OK

func _hello() -> void:
	var settings: Variant = api.get_settings()
	settings.greetings += 1
	var result: Variant = api.save_settings(settings)
	if result != OK:
		api.show_message("Could not save the greeting counter: " + error_string(result))
	else:
		api.show_message("Hello WEBFISHING! Greeting #%d" % settings.greetings)
