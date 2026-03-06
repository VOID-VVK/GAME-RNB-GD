class_name TurnPhaseConfig

var phase_name: String
var allow_actions: bool
var is_automatic: bool

func _init(p_name: String, p_allow_actions: bool, p_is_automatic: bool) -> void:
	phase_name = p_name
	allow_actions = p_allow_actions
	is_automatic = p_is_automatic
